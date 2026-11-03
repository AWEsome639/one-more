#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
多语言静态自检 · 可靠版（2026-10-23 重建）

为什么重写：
  仓库里原来的 tools/check_i18n.py 用 json.loads 解析 EXTRA，
  遇到带注释的条目就崩 —— 而且**在我动手之前就崩了**（核过备份）。
  我自己又写了几版临时脚本，全都有同一个毛病：
    用正则判「这个字符串在不在 TG() 里」⇒ 会跨字符串边界误判，报出几千个假阳性。

  所以按「先修尺子再量东西」重做一把：**真的做词法扫描**
  （区分字符串 / 注释 / 代码），再用括号栈判断某个字符串属于哪个调用。

四项检查：
  ① I18n.ets 的 EXTRA：9 种语言（en / zh-Hant 由 L() 短路，不需要）
  ② GameI18n.ets 的 DICT：10 种语言
  ③ TG()/TG2() 里出现的中文，必须都在 DICT 里（否则英文模式显示中文原文）
  ④ Text()/Button()/accessibilityText() 里**没包 TG** 的中文（最危险的一类）
     —— 这一类只报**行号 + 片段**，交给人判断，不自动改

用法：
  python3 工具/verify_i18n.py            # 全部四项
  python3 工具/verify_i18n.py --fix-hint # 只列 ④（不改文件）
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
I18N = os.path.join(ROOT, 'entry/src/main/ets/core/I18n.ets')
GAME_I18N = os.path.join(ROOT, 'entry/src/main/ets/core/GameI18n.ets')
GAMES_DIR = os.path.join(ROOT, 'entry/src/main/ets/games')

# ★★★ 2026-11-03（第 1080 轮）**修一个让 ③ 项形同虚设的盲区**
#   原来只扫 `games/` 一个目录 ⇒ 而 `DemoBar.ets` 在 `components/`，
#   它里面的 `TG('碰一下就停')` / `TG('（演示不计分）')` **两个都没被扫到**
#   ⇒ 真机上英文界面漏出中文（已由第 1078/1079 轮回溯修复）
#   ⇒ 现在扫**所有** ets 目录（判断标准：含 TG(/TG2( 的文件）
SCAN_DIRS = [
    os.path.join(ROOT, 'entry/src/main/ets/games'),
    os.path.join(ROOT, 'entry/src/main/ets/components'),
    os.path.join(ROOT, 'entry/src/main/ets/pages'),
    os.path.join(ROOT, 'entry/src/main/ets/core'),
]

CJK = re.compile(r'[\u4e00-\u9fff]')

EXTRA_REQ = ["ja", "ko", "fr", "de", "es", "ru", "ar", "pt", "it"]
DICT_REQ = ["en", "ja", "ko", "es", "fr", "de", "pt", "ru", "it", "ar"]


# ───────────────────────── 词法扫描 ─────────────────────────
def scan(src):
    """
    yield (kind, start, end, value)
      kind: 'str' | 'line_comment' | 'block_comment' | 'code'
    字符串支持 ' " ` 三种引号，处理反斜杠转义。
    注释里的内容一律跳过 —— 这是之前所有误判的根源。
    """
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        # 行注释
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            if j < 0:
                j = n
            yield ('line_comment', i, j, src[i:j])
            i = j
            continue
        # 块注释
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            yield ('block_comment', i, j, src[i:j])
            i = j
            continue
        # 字符串
        if c in ('"', "'", '`'):
            q = c
            j = i + 1
            buf = []
            while j < n:
                if src[j] == '\\' and j + 1 < n:
                    buf.append(src[j + 1])
                    j += 2
                    continue
                if src[j] == q:
                    j += 1
                    break
                buf.append(src[j])
                j += 1
            yield ('str', i, j, ''.join(buf))
            i = j
            continue
        # 代码段（到下一个可能的特殊字符）
        j = i
        while j < n and src[j] not in ('/', '"', "'", '`'):
            j += 1
        if j == i:
            j = i + 1
        yield ('code', i, j, src[i:j])
        i = j


class Frame(object):
    __slots__ = ('name', 'depth')

    def __init__(self, name, depth):
        self.name = name
        self.depth = depth


def analyze(src):
    """
    返回:
      wrapped:  [('字符串内容', 行号)]  在 TG/TG2 里的中文串
      raw:      [('字符串内容', 行号)]  不在 TG/TG2 里的中文串
      raw_ui:   [('字符串内容', 行号)]  上面那些里，出现在 Text/Button/accessibilityText 里的
    """
    # 先把注释抠掉换成等长空白，但保留换行（这样位置/行号不变）
    masked = list(src)
    for kind, s, e, _ in scan(src):
        if kind in ('line_comment', 'block_comment'):
            for k in range(s, e):
                if masked[k] != '\n':
                    masked[k] = ' '
    masked = ''.join(masked)

    wrapped = []
    raw = []
    raw_ui = []

    # 括号栈：记录每层 '(' 前面那个标识符
    stack = []
    # 最近一个标识符（用于识别 `TG(` 这种）
    last_ident = ''
    last_ident_end = -1

    def line_of(pos):
        return masked.count('\n', 0, pos) + 1

    for kind, s, e, val in scan(masked):
        if kind == 'str':
            if not CJK.search(val):
                continue
            ln = line_of(s)
            # 当前是否在 TG/TG2 里
            # ★ 2026-10-23：加入 TG4（数方的提示用了四个占位符，为此新增了这个函数）。
            #   不加的话，用 TG4 包的中文会被误判为"没包 TG"或干脆漏检。
            in_tg = any(f.name in ('TG', 'TG2', 'TG4') for f in stack)
            if in_tg:
                wrapped.append((val, ln))
            else:
                raw.append((val, ln))
                # 判断是不是 UI 文案位
                # 往回看最近的标识符：Text / Button / accessibilityText / label
                # 2026-11-01 fix ruler (judgment 67): the old check required the Chinese
                # to come IMMEDIATELY after `Text(` (regex anchored with $) => every
                # ternary like `Text(a ? 'x' : 'y')` was skipped, so this item reported
                # 0 while there were really 145. Now: is the string still inside the
                # parentheses of a UI call?
                win = masked[max(0, s - 500):s]
                k = None
                for mm in re.finditer(r'\b(Text|Button|accessibilityText|label)\s*\(', win):
                    k = mm
                if k is not None:
                    tail = win[k.end():]
                    depth = 1 + tail.count('(') - tail.count(')')
                    if depth > 0:
                        # ★★★ 2026-11-03（第 1081 轮）**排掉双语形式**
                        #   项目里有**三套** i18n：
                        #     ① TG(...) / TG2(...) —— games/ 用（字典查表）
                        #     ② L('中文', 'English') —— core/I18n.ets 两参数版
                        #     ③ this.t('中文', 'English') —— components/ pages/ 用
                        #   ②③ 的中文后面紧跟英文 ⇒ 本来就已本地化
                        #   ⚠️ 之前没排除 ⇒ 一次报出 **142 个假阳性**
                        #      比漏报更糟：让人以为真有 142 个 bug。
                        pre = masked[max(0, s - 10):s]
                        if re.search(r'(\.t|\bL|\.tn|\bTN)\s*\(\s*$', pre):
                            pass   # 已是双语形式，跳过
                        else:
                            raw_ui.append((val, ln))
        elif kind == 'code':
            # ★★★ 2026-10-23 修：原来 `for ch in val` 逐字符看，但 '('[ 是在
            #   同一个 code chunk 里的（扫描器不把 ( 当特殊字符切开）
            #   ⇒ last_ident 还没来得及更新就 push 了 ⇒ in_tg 永远为 False
            #   ⇒ ③ 永远报"0 处"，工具形同失效。改成在这里就地取 `(` 前面的标识符。
            pos = 0
            for ch in val:
                if ch == '(':
                    # 看这个 '(' 前面紧邻的标识符（就在同一个 chunk 里）
                    m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*$', val[:pos])
                    name = m.group(1) if m else last_ident
                    stack.append(Frame(name, len(stack)))
                elif ch == ')':
                    if stack:
                        stack.pop()
                pos += 1
            # 记录本块最后一个标识符，供跨块的 `xxx\n(` 兜底
            m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*$', val)
            if m:
                last_ident = m.group(1)
            elif val.strip() == '':
                pass
            else:
                last_ident = ''
    return wrapped, raw, raw_ui


# ───────────────────────── 字典解析 ─────────────────────────
def parse_record(src, marker):
    """解析 `const X: Record<string, Record<string, string>> = { ... }`，返回 {键: {语言: 译文}}"""
    i = src.index(marker)
    brace = src.index('{', i)
    d = 0
    k = brace
    end = -1
    while k < len(src):
        c = src[k]
        if c == '{':
            d += 1
        elif c == '}':
            d -= 1
            if d == 0:
                end = k
                break
        k += 1
    body = src[brace + 1:end]

    out = {}
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"\s*:\s*\{', body):
        key = m.group(1).replace('\\"', '"').replace('\\\\', '\\')
        b2 = m.end() - 1
        d2 = 0
        e2 = -1
        while b2 < len(body):
            if body[b2] == '{':
                d2 += 1
            elif body[b2] == '}':
                d2 -= 1
                if d2 == 0:
                    e2 = b2
                    break
            b2 += 1
        if e2 < 0:
            continue
        inner = body[m.end():e2]
        langs = {}
        for m2 in re.finditer(r'"(en|ja|ko|es|fr|de|pt|ru|it|ar|zh-Hant)"\s*:\s*"((?:[^"\\]|\\.)*)"', inner):
            langs[m2.group(1)] = m2.group(2)
        out[key] = langs
    return out


def self_test():
    """★ 2026-11-01（判据 72）：反证尺子。

    临时造一个"已知未包 TG 的中文"文件，看 ④ 是否报得出来。
    报不出来 ⇒ 尺子失效，退出码 2。
    这是"报告 0 之前必须先证明尺子能报非 0"的落地实现。
    """
    probe = '_selftest_probe.ets'
    path = os.path.join(GAMES_DIR, probe)
    src = ('@Component\nstruct Probe {\n'
           '  build() {\n'
           '    Column() {\n'
           "      Text('这个中文故意没包 TG 用来试尺子')\n"
           '    }\n'
           '  }\n'
           '}\n')
    io.open(path, 'w', encoding='utf-8').write(src)
    ok = False
    try:
        wrapped, raw, ui = analyze(src)
        ok = any('这个中文故意没包 TG 用来试尺子' == v for v, _ in ui)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass
    if ok:
        print('  ✅ self-test：尺子能抓到人为埋的未包中文')
        return 0
    print('  🔴 self-test 失败：尺子抓不到人为埋的未包中文 ⇒ ④ 项的 0 不可信')
    return 2


def main():
    if '--self-test' in sys.argv:
        return self_test()

    fails = 0
    print('  ══════════════════════════════════════════════════════')

    # ① EXTRA
    s1 = io.open(I18N, encoding='utf-8').read()
    extra = parse_record(s1, 'const EXTRA: Record<string, Record<string, string>> = {')
    bad1 = [(k, [l for l in EXTRA_REQ if l not in v or not v[l].strip()]) for k, v in extra.items()]
    bad1 = [(k, ms) for k, ms in bad1 if ms]
    print('  ① I18n EXTRA：%d 条，缺 %d 条 %s' % (len(extra), len(bad1), '✅' if not bad1 else '🔴'))
    for k, ms in bad1[:6]:
        print('       %-28s 缺 %s' % (k[:28], ','.join(ms)))
    fails += len(bad1)

    # ② DICT
    #   ⚠️ 这里必须区分「缺键」与「空串」：
    #     GameI18n 的 TG() 源码注释写明「空串合法（片段在目标语言里就该消失）」
    #     ⇒ 空串是**设计**，不是缺陷。真正的缺陷只有"键根本不存在"。
    #     （我第一版把空串也判成缺 ⇒ 报出 7 条假阳性，白折腾一轮）
    s2 = io.open(GAME_I18N, encoding='utf-8').read()
    dic = parse_record(s2, 'const DICT: Record<string, Record<string, string>> = {')
    really_missing = []
    empty_ok = 0
    for k, v in dic.items():
        miss = [l for l in DICT_REQ if l not in v]
        if miss:
            really_missing.append((k, miss))
        elif any(not v[l].strip() for l in DICT_REQ):
            empty_ok += 1
    print('  ② 游戏 DICT：%d 条，缺键 %d 条 %s（另有 %d 条含合法空串，按设计放行）'
          % (len(dic), len(really_missing), '✅' if not really_missing else '🔴', empty_ok))
    for k, ms in really_missing[:6]:
        print('       %r 缺 %s' % (k[:28], ','.join(ms)))
    fails += len(really_missing)

    # ③ + ④ 扫描游戏文件
    total_wrapped = 0
    miss = {}
    raw_ui = {}
    # ★ 扫所有 SCAN_DIRS（不只是 games/）—— 见文件头 GAMES_DIR 处的说明
    files = []
    for d in SCAN_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith('.ets') and '.bak' not in f:
                files.append((d, f))
    for d, f in files:
        src = io.open(os.path.join(d, f), encoding='utf-8', errors='ignore').read()
        wrapped, raw, ui = analyze(src)
        total_wrapped += len(wrapped)
        for val, ln in wrapped:
            if val not in dic:
                miss.setdefault(val, []).append((f, ln))
        for val, ln in ui:
            raw_ui.setdefault(val, []).append((f, ln))

    uniq_wrapped = len(set([v for v, _ in [(x[0], x[1]) for x in []]]) ) if False else None
    print('  ③ TG 包裹的中文：%d 处（扫 %d 个文件，覆盖 %d 个目录），其中 %d 种不在字典里 %s'
          % (total_wrapped, len(files), len([d for d in SCAN_DIRS if os.path.isdir(d)]),
             len(miss), '✅' if not miss else '🔴'))
    for k in list(miss)[:8]:
        f, ln = miss[k][0]
        print('       %-30s %s:%d' % (k[:30], f, ln))
    fails += len(miss)

    # ★★★ 2026-11-03（第 1082 轮）**自动识别「自定义函数的双语参数」**
    #   项目里有很多 `this.chip('🔥', '连胜 {n} 天', 'Streak {n} days', ...)` 这种
    #   自定义组件方法的**双参数**写法（中文 + 英文），它们已经本地化了。
    #   ⇒ 判据：**同一行里若还有另一个含 ASCII 字母的字符串字面量**，
    #     就当作「双语参数」放行（不算漏译）。
    #   ⚠️ 这个规则可能漏掉「中文里恰好夹英文单词」的极少数情况，
    #     所以输出里会把"放行"的数量也打出来，便于人工抽查。
    import os as _os
    _DIRS = ['games', 'components', 'pages', 'core']
    _bilingual = {}
    _real = {}
    for _k, _locs in raw_ui.items():
        _f, _ln = _locs[0]
        _path = None
        for _d in _DIRS:
            _p2 = _os.path.join(ROOT, 'entry/src/main/ets', _d, _f)
            if _os.path.exists(_p2):
                _path = _p2; break
        _line = ''
        if _path:
            try:
                _ls = io.open(_path, encoding='utf-8', errors='ignore').read().split('\n')
                if 0 <= _ln - 1 < len(_ls):
                    _line = _ls[_ln - 1]
            except Exception:
                pass
        # 该行是否还有第二个含英文字母的字符串
        _en = re.search(r"'[^']*[A-Za-z]{3}[^']*'", _line)
        if _en:
            _bilingual[_k] = _locs
        else:
            _real[_k] = _locs

    print('  ④ 没包 TG 的 UI 中文：%d 种（其中 **%d 种是双语参数**已放行，剩 **%d 种**需人工核）%s'
          % (len(raw_ui), len(_bilingual), len(_real),
             '✅' if not _real else '⚠️'))
    raw_ui = _real
    for k in list(raw_ui)[:12]:
        f, ln = raw_ui[k][0]
        print('       %-28s %s:%d' % (k[:28], f, ln))

    # ── ⑤ accessibilityText / accessibilityDescription 的硬编码中文 ──
    #   ★★★ 2026-11-03（第 1084 轮）新增（判据 358）
    #   来历：`Common.ets` 的 `.accessibilityText(...)` 里硬编码了「，今日已玩」，
    #         英文界面下**读屏会用英文语音念中文** ⇒ 乱码。
    #         这类字符串**不在任何截图上**，视觉走查永远发现不了。
    #   ⇒ 单独作为第 ⑤ 项检查。
    CJK5 = re.compile(r'[\u4e00-\u9fff]')
    a11y_bad = {}
    a11y_total = 0
    for d in SCAN_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not f.endswith('.ets') or '.bak' in f:
                continue
            fp = os.path.join(d, f)
            try:
                ls5 = io.open(fp, encoding='utf-8', errors='ignore').read().split('\n')
            except Exception:
                continue
            for idx, line5 in enumerate(ls5):
                if 'accessibilityText' not in line5 and 'accessibilityDescription' not in line5:
                    continue
                if line5.strip().startswith('//') or line5.strip().startswith('*'):
                    continue
                a11y_total += 1
                block = '\n'.join(ls5[idx:idx + 4])
                if CJK5.search(block):
                    # 已本地化形式：同一 block 里有 ASCII 英文串，或调用了 TG(/L(/t(
                    has_en = re.search(r"'[^']*[A-Za-z]{3}[^']*'", block)
                    has_fn = re.search(r'(TG|TG2|TG4|L|TN)\s*\(|\.t\s*\(|\.tn\s*\(', block)
                    if not (has_en or has_fn):
                        a11y_bad.setdefault(block.strip()[:60], []).append((f, idx + 1))

    print('  ⑤ accessibility 文本：%d 处（扫 %d 个目录），其中 **%d 处**含未本地化中文 %s'
          % (a11y_total, len([d for d in SCAN_DIRS if os.path.isdir(d)]),
             len(a11y_bad), '✅' if not a11y_bad else '🔴'))
    for k in list(a11y_bad)[:6]:
        f5, ln5 = a11y_bad[k][0]
        print('       %-46s %s:%d' % (k[:46], f5, ln5))
    fails += len(a11y_bad)

    print('  ══════════════════════════════════════════════════════')
    print('  结论：%s' % ('✅ ①②③⑤ 全通过' if fails == 0 else '🔴 %d 处必须修' % fails))
    fails += len(raw_ui)
    return 0 if fails == 0 else 1


if __name__ == '__main__':
    # ★★★ 2026-11-03（第 1124 轮）**崩溃与判定失败用不同退出码**（判据 428）
    #   原来 `sys.exit(main())`：main 里抛异常就变成非 0 的 traceback 退出（也是 1）
    #   ⇒ **"检测到不合格"和"脚本自己崩了"退出码一样**
    #   ⇒ 看到 1 时无法判断该去改代码还是该去查环境
    #   ⇒ 约定：**0 = 合格 ｜ 1 = 判定不合格 ｜ 2 = 脚本异常**
    try:
        _rc = main()
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
    sys.exit(_rc if isinstance(_rc, int) else 0)
