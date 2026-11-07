#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「译文内容被当状态用」检查器（判据 1782 家族 · 第三把尺子）

★ 为什么需要它（2026-11-07 一晚踩两次 + 一次真 bug）：
  · `this.t(zh, en)` / `TG(...)` 的返回值有**三条渲染路径**：zh 原词 / en 入参 / 其余 10 查字典。
  · 有人拿它当状态用：`this.tip.startsWith('✓')` 决定颜色、`this.msg.indexOf('❌') === 0` 决定锁输入。
    只要某个语言的译文删掉 emoji（或加个空格/换个叉号），判断就**静默失效**。
  · 更极端的：`GAlgebraicBalance` 的 `this.tip = ...` 曾被写成裸 `TG2(...)`（值被丢弃）
    ⇒ `startsWith('✓')` **永远为假** —— 答对答错都没反馈，不崩不报错。
  ⇒ 判据：**状态判定不许读译文内容**，要用状态字段（`lastRight` / `lastWrong`）。

★ 检查什么（语句级，不做跨语句猜测）
  ① 直接式：`t(...)` / `TG(...)` 的返回值**同一行**紧跟
     `.startsWith/.endsWith/.includes/.indexOf/.lastIndexOf/.charAt` 或 `=== '字面量'`
  ② 字段式：某个 `this.X = <翻译调用>`（**这条语句本身**的右值是翻译调用），
     之后出现 `this.X.<上面那些内容算子>` / `this.X === '非空字面量'`
  ❌ 不算：`.length`（长度/presence）、`=== ''` / `!== ''`（空串判断）、数组字段（`this.picked.indexOf`）。

★ 白名单：见 WHITELIST（按「文件 + 字段」放行，必须写理由）。当前为空。
★ 机器行：`内容当状态：N 处`（供 check_assertions.sh grep）。
用法：
  python3 tools/check_state_from_text.py             # 全仓扫，有命中退出码 1
  python3 tools/check_state_from_text.py --self-test # 先验尺子（反证用例）
  python3 tools/check_state_from_text.py --verbose   # 打印覆盖统计与被排除的 presence 判断
退出码：0 = 无命中 ｜ 1 = 有命中 ｜ 2 = 解析/自检失败
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
    from check_dup_symbol import mask_comments      # 同一套「只抹注释、保留字符串」的掩码
except Exception:                                    # pragma: no cover
    print('  🔴 无法复用 tools/check_dup_symbol.py 的掩码器')
    sys.exit(2)

# 翻译调用（**必须真的是本地化取值**：允许 this.t / this.tn / TG2 / TG4 / L / displayName / displayTagline…）
TEXT_CALL = r'(?:this\.tn|this\.t|TG\d*|L|displayName|displayTagline|taglineText)\s*\('
# 内容类判断算子（读字符串**内容**才进入这里；长度/空串判断刻意不算）
JUDGE = r'\.\s*(?:startsWith|endsWith|includes|indexOf|lastIndexOf|charAt)\s*\('
EQ_NE = r'\s*(?:===|!==)\s*[\'"]'

# 白名单：按 (文件 glob, 字段名)；字段名 'direct' 表示直接式。每条必须写理由。
WHITELIST = [
    # 目前为空 —— 先把现状跑成 0，再按真实需要逐条加（每条都要能在报告里讲清为什么不是状态判断）
]

SCAN_DIRS = ['entry/src/main/ets/components', 'entry/src/main/ets/pages', 'entry/src/main/ets/games']
STATS = {'files': 0, 'text_fields': 0, 'decisions_seen': 0, 'presence_skipped': 0}


def split_stmts(line):
    """按顶层 `;` 切语句（括号/花括号内不切）—— 避免把同一行里别的 `TG(...)` 算成来源。"""
    out, cur, depth = [], '', 0
    for ch in line:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ';' and depth <= 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return [s for s in out if s.strip()]


def scan_file(path):
    rel = os.path.relpath(path, ROOT)
    src = io.open(path, encoding='utf-8').read()
    masked = mask_comments(src)
    lines = masked.split('\n')
    raw_lines = src.split('\n')
    STATS['files'] += 1

    # ① 收集「右值是翻译调用」的成员字段
    text_fields = set()
    for l in lines:
        for st in split_stmts(l):
            m = re.match(r'\s*this\.([\w$]+)\s*=\s*(.*)$', st)
            if m and re.search(TEXT_CALL, m.group(2)):
                text_fields.add(m.group(1))
    STATS['text_fields'] += len(text_fields)

    hits = []
    for ln, l in enumerate(lines, 1):
        # ② 直接式
        if re.search(TEXT_CALL + r'[^;()]*\)\s*(?:' + JUDGE + r'|' + EQ_NE + r')', l):
            STATS['decisions_seen'] += 1
            if not _whitelisted(rel, 'direct'):
                hits.append({'file': rel, 'line': ln, 'kind': 'direct',
                             'code': raw_lines[ln - 1].strip()[:120]})
            continue
        # ③ 字段式
        for f in text_fields:
            if re.search(r'this\.' + re.escape(f) + r'\s*' + JUDGE, l) or \
               re.search(r'this\.' + re.escape(f) + r'\s*(?:===|!==)\s*[\'"][^\'"]+[\'"]', l):
                STATS['decisions_seen'] += 1
                if not _whitelisted(rel, f):
                    hits.append({'file': rel, 'line': ln, 'kind': 'field:' + f,
                                 'code': raw_lines[ln - 1].strip()[:120]})
                break
        # ④ 统计被刻意排除的 presence 判断（让「0 处」可解释）
        for f in text_fields:
            if re.search(r'this\.' + re.escape(f) + r'\.\s*(?:length)\b', l) or \
               re.search(r'this\.' + re.escape(f) + r'\s*(?:===|!==)\s*[\'"]{2}', l):
                STATS['presence_skipped'] += 1
                break
    return hits


def _whitelisted(rel, field):
    for pat, fld, why in WHITELIST:
        if fld == field and fnmatch.fnmatch(rel, pat):
            return why
    return None


# ──────────────────────────── 反证自检 ────────────────────────────
SELF_POS = '''
@Component
struct Demo {
  @State private tip: string = '';
  private answer(ok: boolean) {
    this.tip = TG2('✓ 对了，连击 {0}', 1);
  }
  build() { Text(this.tip).fontColor(this.tip.startsWith('✓') ? 1 : 0) }
}
'''
SELF_NEG = '''
@Component
struct Demo {
  @State private tip: string = '';
  @State private picked: number[] = [];
  private answer() { this.tip = TG2('✓ 对了 {0}', 1); this.picked = []; }
  build() {
    Text(this.tip)                       // 没有对 tip 做内容判断 ⇒ 不算
    if (this.picked.indexOf(1) >= 0) { } // 数组字段：赋值不是翻译调用 ⇒ 不算
    if (this.tip.length > 0) { }         // presence ⇒ 不算
    if (this.tip === '') { }             // presence ⇒ 不算
  }
}
'''


def self_test():
    import tempfile
    ok = []
    d = tempfile.mkdtemp(prefix='statefromtext_')
    try:
        p1 = os.path.join(d, 'pos.ets')
        io.open(p1, 'w', encoding='utf-8').write(SELF_POS)
        h1 = scan_file(p1)
        ok.append(('正例必须命中（tip.startsWith）', len(h1) == 1 and h1[0]['kind'] == 'field:tip',
                   '%d 处 %s' % (len(h1), [x['kind'] for x in h1])))
        p2 = os.path.join(d, 'neg.ets')
        io.open(p2, 'w', encoding='utf-8').write(SELF_NEG)
        h2 = scan_file(p2)
        ok.append(('负例必须 0 命中（数组/presence/无判断）', len(h2) == 0,
                   '%d 处 %s' % (len(h2), [x['kind'] for x in h2])))
        # 直接式反证：`TG('x').startsWith(...)` 必须命中
        p3 = os.path.join(d, 'direct.ets')
        io.open(p3, 'w', encoding='utf-8').write("\nconst a = TG('✓ ok').startsWith('✓');\n")
        h3 = scan_file(p3)
        ok.append(('直接式必须命中', len(h3) == 1 and h3[0]['kind'] == 'direct', '%d 处' % len(h3)))
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
        files += sorted(glob.glob(os.path.join(ROOT, d, '*.ets')))
    if not files:
        print('  🔴 没找到 .ets 文件')
        return 2
    all_hits = []
    for p in files:
        all_hits += scan_file(p)

    print('  ═══ 译文内容当状态检查（判据 1782 家族）═══')
    print('  扫描 .ets：%d 个' % STATS['files'])
    print('  覆盖：来自翻译调用的状态字段 %d 个 ｜ 内容类判断 %d 处 ｜ 刻意排除的 presence 判断 %d 处'
          % (STATS['text_fields'], STATS['decisions_seen'], STATS['presence_skipped']))
    if STATS['decisions_seen'] == 0 and STATS['text_fields'] == 0:
        print('  🔴 一个翻译字段都没识别到 ⇒ 解析器有问题，这次「0 处」不可信')
        return 2
    if all_hits:
        print('\n  ❌ 把译文内容当状态 %d 处：' % len(all_hits))
        for h in all_hits:
            print('     · %s:%d  [%s]  %s' % (h['file'], h['line'], h['kind'], h['code']))
        print('\n  修法：加状态字段（如 lastRight / lastWrong）记判定结果，颜色/锁输入只读状态；')
        print('        或换「剥掉符号后的原文」作比较（更绕，不推荐）。')
        print('  内容当状态：%d 处' % len(all_hits))
        return 1
    print('\n  ✅ 没有把译文内容当状态的地方')
    print('  内容当状态：0 处')
    if verbose:
        print('     （presence 类 %d 处是刻意排除的：`.length` / `=== \'\'` 只判空、不读内容）'
              % STATS['presence_skipped'])
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
