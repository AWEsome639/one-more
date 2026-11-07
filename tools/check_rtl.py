#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""RTL 静态陷阱检查器（三类硬编码）

★ 背景（2026-11-08，code-hunter 在加 RTL 布局、verifier-eng2 在扫运行时陷阱）：
  RTL（阿拉伯语）下有几类写法**一定坏**，而且都是「看着正常、只有阿语用户看到反的」：

  ① 方向性字符硬编码：`Text('›')` / `Text('‹')` / `Text('→')` / `Text('←')`
     —— 阿语下「返回」箭头该朝右、列表「更多」该朝左，写死就反了。
     白名单：`games/` 里的玩法箭头（物理/规则方向，不镜像）；整句说明里的方向词不算（本检查只认**纯符号**）。
  ② 绝对对齐：`TextAlign.Left` / `TextAlign.Right`
     —— ArkUI 的 Start/End 才会随布局方向翻；Left/Right 是绝对方向。
     白名单：确实要绝对的数字列（本仓库当前 0 处）。
  ③ 单边绝对边距：`margin({ left: N })` / `padding({ right: N })`
     —— 只有一边时，阿语下应该出现在另一侧；`{ left, right }` **成对**出现即对称安全（不算）。

★ 输出：机读行 `RTL陷阱：N 处`；退出码 0 = 无陷阱 ｜ 1 = 有 ｜ 2 = 解析/自检失败。
用法：
  python3 tools/check_rtl.py             # 全仓扫
  python3 tools/check_rtl.py --verbose   # 打印每处上下文 + 白名单放行
  python3 tools/check_rtl.py --self-test # 反证自检
"""
import fnmatch
import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from check_dup_symbol import mask_comments
except Exception:                                    # pragma: no cover
    print('  🔴 无法复用 tools/check_dup_symbol.py 的掩码器')
    sys.exit(2)

SCAN_DIRS = ['components', 'pages', 'games', 'core']
DIR_CHARS = '›‹→←'

# ① 白名单：玩法箭头（物理/规则方向，阿语里也不镜像）
DIR_WHITELIST = [
    ('entry/src/main/ets/games/*.ets', '玩法方向符号：规则/物理方向，不随语言镜像'),
]
# ② 白名单：确实需要绝对对齐的数字列（按「文件 + 行」或「文件 + 片段」）
ABS_WHITELIST = [
    # 例：('entry/src/main/ets/components/StatsTab.ets', '数字列向右对齐'),  # 当前没有
]
# ③ 白名单：确实要单边的（例如紧贴屏幕左缘的抽屉）；每条必须写理由
EDGE_WHITELIST = [
    # ★ 2026-11-08（lead 确认）：游戏内布局不参与镜像 —— 这些间距是**题目坐标系**的一部分
    #   （棋盘/选项网格按行列摆放），不随界面方向翻转，所以单边是刻意的。
    ('entry/src/main/ets/games/GGrammarPolice.ets', 'right: Space.xs',
     '游戏内选项网格：按题目坐标摆放，不随语言镜像（lead 2026-11-08 确认）'),
    ('entry/src/main/ets/games/GVisualSearchConjunction.ets', 'right: Space.xs',
     '游戏内选项网格：按题目坐标摆放，不随语言镜像（lead 2026-11-08 确认）'),
]


def match_paren(masked, open_idx):
    depth = 0
    for i in range(open_idx, len(masked)):
        c = masked[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def match_brace(masked, open_idx):
    depth = 0
    for i in range(open_idx, len(masked)):
        c = masked[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
    return -1


def top_keys(obj_inner):
    """对象字面量的顶层 key 集合（跳过嵌套对象/字符串/括号里的逗号）。"""
    keys, depth, cur = set(), 0, ''
    i, n = 0, len(obj_inner)
    parts = []
    while i < n:
        c = obj_inner[i]
        if c in '\'"`':
            q = c
            cur += c
            i += 1
            while i < n:
                cur += obj_inner[i]
                if obj_inner[i] == '\\':
                    i += 1
                    if i < n:
                        cur += obj_inner[i]
                    i += 1
                    continue
                if obj_inner[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        if c == ',' and depth <= 0:
            parts.append(cur)
            cur = ''
        else:
            cur += c
        i += 1
    parts.append(cur)
    for p in parts:
        m = re.match(r'\s*([A-Za-z_$][\w$]*)\s*:', p)
        if m:
            keys.add(m.group(1))
    return keys, parts


def scan_file(path):
    rel = os.path.relpath(path, ROOT)
    src = io.open(path, encoding='utf-8').read()
    mk = mask_comments(src)          # 只抹注释、保留字符串（①需要读字面量）
    lines = mk.split('\n')
    raw_lines = src.split('\n')
    found = {'dir': [], 'align': [], 'edge': []}
    allowed = {'dir': [], 'align': [], 'edge': []}

    # ① 纯方向符号 Text('›') 等
    pat1 = re.compile(r'\bText\(\s*([\'"])([' + DIR_CHARS + r'])\1\s*\)')
    for m in pat1.finditer(mk):
        ln = mk.count('\n', 0, m.start()) + 1
        if 'isRTL' in lines[ln - 1]:
            continue
        why = None
        for glob_pat, reason in DIR_WHITELIST:
            if fnmatch.fnmatch(rel, glob_pat):
                why = reason
        item = {'file': rel, 'line': ln, 'sym': m.group(2),
                'code': raw_lines[ln - 1].strip()[:100]}
        (allowed['dir'].append((item, why)) if why else found['dir'].append(item))

    # ② 绝对对齐
    pat2 = re.compile(r'\bTextAlign\.(Left|Right)\b')
    for m in pat2.finditer(mk):
        ln = mk.count('\n', 0, m.start()) + 1
        item = {'file': rel, 'line': ln, 'sym': m.group(1),
                'code': raw_lines[ln - 1].strip()[:100]}
        why = None
        for f, reason in ABS_WHITELIST:
            if f == rel:
                why = reason
        (allowed['align'].append((item, why)) if why else found['align'].append(item))

    # ③ 单边 margin/padding（成对 left+right 不算）
    pat3 = re.compile(r'\.(margin|padding)\s*\(')
    for m in pat3.finditer(mk):
        op = m.end() - 1
        cl = match_paren(mk, op)
        if cl < 0:
            continue
        arg = mk[op + 1:cl]
        s = arg.lstrip()
        if not s.startswith('{'):
            continue                       # 变量/主题对象：不是字面量边距
        b = op + 1 + (len(arg) - len(s))
        e = match_brace(mk, b)
        if e < 0:
            continue
        inner = mk[b + 1:e]
        keys, parts = top_keys(inner)
        sides = [k for k in ('left', 'right') if k in keys]
        if not sides:
            continue                       # 上下边距 / start-end：RTL 安全
        if len(sides) == 2:
            continue                       # 成对 = 对称安全（按要求）
        if 'start' in keys or 'end' in keys:
            continue
        side = sides[0]
        # 值为 0 的没有实际偏移，安全
        val = ''
        for p in parts:
            pm = re.match(r'\s*' + side + r'\s*:', p)
            if pm:
                val = p[pm.end():].strip()
                break
        if val in ('0', "'0'", '"0"', '0.0'):
            continue
        if 'isRTL' in arg:
            continue
        ln = mk.count('\n', 0, m.start()) + 1
        snippet = re.sub(r'\s+', ' ', ('%s({ %s })' % (m.group(1), re.sub(r'\s+', ' ', inner.strip()))))[:80]
        item = {'file': rel, 'line': ln, 'sym': side, 'code': raw_lines[ln - 1].strip()[:100],
                'snippet': snippet}
        why = None
        for f, frag, reason in EDGE_WHITELIST:
            if f == rel and frag in inner:
                why = reason
        (allowed['edge'].append((item, why)) if why else found['edge'].append(item))

    return found, allowed


# ──────────────────────────── 自检 ────────────────────────────
SELF_SRC = '''
@Component
struct Demo {
  build() {
    Row() {
      Text('›')                                   // ① 违规：纯符号无 isRTL
      Text('‹')                                   // ① 违规
      Text(I18n.isRTL() ? '‹' : '›')              // ① 安全：有 isRTL
      Text('说明：点 ‹ 返回')                      // ① 安全：不是纯符号
      Text('数字').textAlign(TextAlign.Left)       // ② 违规
      Text('数字').textAlign(TextAlign.Right)      // ② 违规
      Text('数字').textAlign(TextAlign.Start)      // ② 安全
      Row().margin({ left: 8 })                    // ③ 违规：单边
      Row().margin({ right: 8 })                   // ③ 违规：单边
      Row().margin({ left: 8, right: 8 })          // ③ 安全：成对
      Row().padding({ left: 0 })                   // ③ 安全：0 无偏移
      Row().padding({ top: 4, bottom: 4 })         // ③ 安全：上下
      Row().margin({\n        left: 12,\n      })                                    // ③ 违规：多行单边\n      Row().margin({\n        left: 12,\n        right: 12,\n      })                       // ③ 安全：多行成对\n      Row().margin({ left: I18n.isRTL() ? 0 : 8 }) // ③ 安全：已按 RTL 处理
    }
  }
}
'''


def self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix='rtl_')
    try:
        p = os.path.join(d, 'demo.ets')
        io.open(p, 'w', encoding='utf-8').write(SELF_SRC)
        found, allowed = scan_file(p)
        ok = [
            ('① 方向符号：应命中 2 处', len(found['dir']) == 2, '%d 处' % len(found['dir'])),
            ('② 绝对对齐：应命中 2 处', len(found['align']) == 2, '%d 处' % len(found['align'])),
            ('③ 单边边距：应命中 3 处（含多行单边）', len(found['edge']) == 3, '%d 处' % len(found['edge'])),
        ]
    finally:
        try:
            for f in os.listdir(d):
                os.remove(os.path.join(d, f))
            os.rmdir(d)
        except OSError:
            pass
    for name, passed, got in ok:
        print('     %s %s（实际 %s）' % ('✅' if passed else '❌', name, got))
    return all(p for _, p, _ in ok)


def main():
    if '--self-test' in sys.argv:
        print('  ═══ 自检（反证尺子）═══')
        return 0 if self_test() else 2
    verbose = '--verbose' in sys.argv
    files = []
    for d in SCAN_DIRS:
        files += sorted(glob.glob(os.path.join(ETS, d, '*.ets')))
    if not files:
        print('  🔴 没找到 .ets 文件')
        return 2

    total = {'dir': 0, 'align': 0, 'edge': 0}
    all_found = {'dir': [], 'align': [], 'edge': []}
    all_allowed = {'dir': [], 'align': [], 'edge': []}
    for p in files:
        found, allowed = scan_file(p)
        for k in total:
            total[k] += len(found[k])
            all_found[k] += found[k]
            all_allowed[k] += allowed[k]

    print('  ═══ RTL 静态陷阱检查 ═══')
    print('  扫描 .ets：%d 个（components/pages/games/core）' % len(files))
    names = {'dir': '① 方向符号硬编码（Text(›/‹/→/←) 无 isRTL）',
             'align': '② 绝对对齐（TextAlign.Left/Right）',
             'edge': '③ 单边绝对边距（margin/padding 只有 left 或 right）'}
    for k in ('dir', 'align', 'edge'):
        print('\n  %s：%d 处' % (names[k], total[k]))
        for h in all_found[k][: (100 if verbose else 8)]:
            print('     · %s:%d  [%s]  %s' % (h['file'], h['line'], h['sym'], h['code']))
        if total[k] > 8 and not verbose:
            print('     …（共 %d 处，--verbose 看全部）' % total[k])
        for h, why in all_allowed[k]:
            if verbose:
                print('     ✓ 白名单：%s:%d「%s」—— %s' % (h['file'], h['line'], h['sym'], why))
    n = sum(total.values())
    print('\n  RTL陷阱：%d 处' % n)
    return 0 if n == 0 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
