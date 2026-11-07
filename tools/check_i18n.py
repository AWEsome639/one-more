#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""多语言 / 主题色 静态自检（拾海 2026-10-11 建，2026-10-13 扩）

为什么需要它：
  字典缺一条 ⇒ 那条在 10 种语言下**静默退成英文** —— 不报错、界面看不出。
  繁体被短路、主题色当 id 用、@Builder 记忆化……全是**静默失效**，
  只能靠脚本抓。和「ArkUI 依赖陷阱」「批量改动静默失效」是同一类问题。

八项核对：
  ① 完整性  每条中文原文都有全部 10 语言译文（不许缺、不许空串）
  ② 重复键  ArkTS 会报 multiple properties with the same name
  ③ 覆盖率  代码里 L()/this.t() 的中文原文有多少进了字典
  ④ 繁体路径 `L()` 不许把 zh-Hant 短路成简体（P4 的根因，硬失败）
  ⑤ 裸中文  components/pages 里没走 t()/L()/TZ() 的中文字面量（警告 + 清单）
  ⑥ Builder 陷阱  @Builder 收算好的字符串（语言变了不重建）（警告）
  ⑦ 主题色  `this.accent` 被当颜色用（它是 id，可能是 'system'）（硬失败）
  ⑧ 结构    受管文件的括号/花括号/引号是否配平（硬失败）\n  ⑫ enum 成员持 TG()（硬失败，判据 1745）\n  ⑥ 已按判据 1776 收窄：实参里直接 this.t(...) 不算陷阱

用法: python3 tools/check_i18n.py [--scan]
退出码 0 = 全过；1 = 有硬失败
"""
import re, io, json, glob, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')
I18N = os.path.join(ETS, 'core/I18n.ets')
DESIGN = os.path.join(ETS, 'core/Design.ets')
SETTINGS = os.path.join(ETS, 'components/SettingsTab.ets')
LANGS = ['ja', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'it', 'ar', 'zh-Hant']
# ★ 判据 1741：**zh-Hant 允许缺** —— I18n.ets 的 L() 里明写
#   `if (cur === Lang.ZHTW) { return Digits(toTrad(zh), cur); // 繁体缺项：转换`，
#   所以「没写 zh-Hant 列」是设计，不是洞（48 条这样，旧版当缺项 ⇒ 假红）。
#   缺这 9 种才是真洞。
LANGS_REQ = ['ja', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'it', 'ar']
# 受本专项管辖（改了要自检）的三个文件
MANAGED = [I18N, DESIGN, SETTINGS]
# 2026-10-13 i18n-theme 专项扩围后经手的文件（都做括号配平自检）
MANAGED += [os.path.join(ETS, x) for x in [
    'core/GameI18n.ets', 'core/GameRegistry.ets', 'core/ProgressStore.ets',
    'components/GamesTab.ets', 'components/Common.ets', 'components/StatsTab.ets',
    'pages/Index.ets', 'pages/Splash.ets', 'pages/GameHost.ets', 'pages/GuidePage.ets', 'pages/LanLobby.ets',
]]

fatal = []
warn = []


def read(p):
    return io.open(p, encoding='utf-8').read()


def strip_code(txt):
    """
    去掉注释与字符串（**单遍词法扫描**，别用正则挨个替）

    ⚠️ 2026-10-13 修：原来用「先 // 注释 → 再 '...' → 再 "..."」的顺序做法，
       遇到 `this.t(' 的房间', "'s room")`（双引号串里带撇号）就会**错配**，
       把后面的代码吞掉 ⇒ 结构检查误报"括号不配平"（GameRegistry / LanLobby 各误报一次）。
    """
    out = []
    i = 0
    n = len(txt)
    while i < n:
        c = txt[i]
        if c == '/' and i + 1 < n and txt[i + 1] == '/':
            j = txt.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and i + 1 < n and txt[i + 1] == '*':
            j = txt.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == "'" or c == '"' or c == '`':
            q = c
            i += 1
            while i < n:
                if txt[i] == '\\':
                    i += 2
                    continue
                if txt[i] == q:
                    i += 1
                    break
                i += 1
            out.append(' ')
            continue
        out.append(c)
        i += 1
    return ''.join(out)


# ════════════════════════════════════════════════════════════════════════════
#  判据 1741：字典必须**按结构**解析（括号栈 + 跳过字符串），不能按行、不能 json.loads
#
#  ⚠️ 2026-11-07 修三处误报 —— 根因是同一把坏尺子（**按行 / 按 JSON 解析 TS 对象字面量**）：
#    ① 「重复键 ['"ar"', '"de"', '"en"', …]」：旧版用 `^\s*"…"\s*:` 抓**所有**行首键，
#       把嵌套的**语言列名**也算成顶层键 ⇒ 语言列名当然每条都重复。语言列不是键。
#    ② 「GameI18n 字典解析失败：Expecting property name」：DICT 里夹着 // 注释
#       （GameI18n.ets 第 1325 行起就是），json.loads 读到注释当场崩。
#    ③ 附带修掉的第三个误报：「完整性 398 条有缺」—— EXTRA 是**混排**的
#       （31 条多行 + 389 条单行：单行条目的语言列和键挤在同一行），
#       旧版只认行首的 `"键": {`，单行条目整片漏掉 ⇒ 全被记成「缺 10 语言」。
#  ⇒ 现在：先按字符扫（字符串 / 注释分开），再用**括号栈**切出每个顶层条目，
#     最后在条目体内正则取语言列。多行、单行、带注释、带尾逗号、含 `{n}` 模板都能吃。
# ════════════════════════════════════════════════════════════════════════════
QUOTES = ('"', "'", '`')
_KEY_OBJ = re.compile(r'\s*("(?:[^"\\]|\\.)*")\s*:\s*\{')
# 非对象型条目（`"k": "v"`）也整条吃掉，免得它的值里出现 `": {"` 把后面搅乱
_KEY_STR = re.compile(r'\s*("(?:[^"\\]|\\.)*")\s*:\s*"(?:[^"\\]|\\.)*"')
_PAIR = re.compile(r'"([A-Za-z][A-Za-z-]{0,9})"\s*:\s*"((?:[^"\\]|\\.)*)"')


def _skip_string(txt, i):
    """i 指向引号；返回**配对引号之后**的下标（认反斜杠转义）"""
    q = txt[i]
    i += 1
    n = len(txt)
    while i < n:
        if txt[i] == '\\':
            i += 2
            continue
        if txt[i] == q:
            return i + 1
        i += 1
    return n


def _object_end(txt, i):
    """i 指向 '{'；返回配对 '}' **之后**的下标。

    ★ 必须跳过字符串：译文里的 `{n}` / `{s}` 模板就是花括号，
      不认识字符串的话层数会被模板搅乱（判据 1740 踩过同一个坑）。
    """
    depth = 0
    n = len(txt)
    while i < n:
        c = txt[i]
        if c in QUOTES:
            i = _skip_string(txt, i)
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def blank_comments(txt):
    """注释 ⇒ 等长空白（**字符串里的内容一个字符都不动**，换行保留 ⇒ 行号不变）。

    ★ 为什么不能 `re.sub(r'//[^\n]*')`：译文里一出现 `https://…`，
      整个行尾都会被当成注释删掉（值被截断），随后括号配平也会跟着错位。
    """
    out = list(txt)
    i = 0
    n = len(txt)
    while i < n:
        c = txt[i]
        if c in QUOTES:
            i = _skip_string(txt, i)
            continue
        if c == '/' and i + 1 < n and txt[i + 1] == '/':
            j = txt.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
            continue
        if c == '/' and i + 1 < n and txt[i + 1] == '*':
            j = txt.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, min(j, n)):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        i += 1
    return ''.join(out)


def _key_text(raw):
    """源码里的键字面量（自带引号）⇒ 真实字符串（`\\n` 之类的转义要还原）"""
    try:
        return json.loads(raw)
    except Exception:
        return raw[1:-1] if len(raw) >= 2 else raw


def parse_dict_literal(src, marker):
    """解析 `const XXX: Record<…> = { … }` ⇒ (entries, stray)。

    entries = [(键字面量, {语言: 译文}), …]，**保持出现顺序、重复键各自保留**
              （判重交给调用方，合并会掩盖重复）
    stray   = 值不是对象的条目数（这个字典的类型不该有 ⇒ 出现就是类型错误）
    找不到 marker 时返回 (None, 0)，让调用方报「解析失败」而不是抛异常。
    """
    try:
        i = src.index(marker)
        b = src.index('{', i)
    except ValueError:
        return None, 0
    end = _object_end(src, b)
    inner = blank_comments(src[b + 1:end - 1])
    entries = []
    stray = 0
    k = 0
    n = len(inner)
    while k < n:
        m = _KEY_OBJ.match(inner, k)
        if m:
            j = m.end() - 1                      # 指向条目对象的 '{'
            e = _object_end(inner, j)
            row = {}
            for pm in _PAIR.finditer(inner[j + 1:e - 1]):
                row[pm.group(1)] = pm.group(2)
            entries.append((m.group(1), row))
            k = e
            continue
        if inner[k] in ' \t\r\n,':
            k += 1
            continue
        m2 = _KEY_STR.match(inner, k)
        if m2:
            stray += 1
            k = m2.end()
            continue
        k += 1
    return entries, stray


def parse_extra(s):
    """I18n.ets 的 EXTRA ⇒ (data, dup, nkeys, stray)（判据 1741）。

    dup 只算**顶层键**（中文原文）；语言列名在条目体里，从头到尾不当键。
    """
    entries, stray = parse_dict_literal(s, 'const EXTRA:')
    if entries is None:
        return {}, [], 0, 0
    data = {}
    keys = []
    for raw, row in entries:
        key = _key_text(raw)
        keys.append(key)
        data.setdefault(key, {}).update(row)
    cnt = {}
    for key in keys:
        cnt[key] = cnt.get(key, 0) + 1
    dup = sorted([key for key, c in cnt.items() if c > 1])
    return data, dup, len(keys), stray


# ── 反证尺子（判据 1741）：这几种排版和坑，解析器必须扛住 ──
SELF_TEST_SRC = '''const EXTRA: Record<string, Record<string, string>> = {
  /** 注释里带 "引号" 和 { 花括号 } 都不算数 */
  "多行条目": {
    "en": "Multi line",
    "ja": "複数行",   // 行尾注释
    "zh-Hant": "多行條目",
  },
  "单行条目": { "en": "One line", "ja": "一行", "zh-Hant": "單行條目" },
  "{n} 局": { "en": "{n} rounds", "ja": "{n}局", "zh-Hant": "{n} 局" },
  "网址": { "en": "see https://example.com/a{b}", "ja": "https://example.com", "zh-Hant": "網址" },
  "带撇号": { "en": "it's the host's room", "ja": "ホストの部屋", "zh-Hant": "房主的房間" },
  "重复的键": { "en": "dup A", "ja": "重複", "zh-Hant": "重複的鍵" },
  "重复的键": { "en": "dup B", "ja": "重複2", "zh-Hant": "重複的鍵2" },
};
'''


def self_test():
    """反证尺子：解析器自己先过一遍坑，再拿它量真实字典。

    断言的都是**这轮修掉的误报**：
      · 顶层键 7 条 / 去重 6 条 / 重复只报「重复的键」（**不许报语言列名**）
      · 单行条目要有 3 个语言列（旧版这里是空 dict ⇒ 假「缺项」）
      · `{n} 局`、注释、尾逗号、`https://`、`it's` 全部不许把解析搅坏
    """
    entries, stray = parse_dict_literal(SELF_TEST_SRC, 'const EXTRA:')
    data, dup, nkeys, stray2 = parse_extra(SELF_TEST_SRC)
    checks = [
        ('条目数 = 7', nkeys == 7),
        ('去重后 = 6', len(data) == 6),
        ('重复键只报顶层「重复的键」', dup == ['重复的键']),
        ('语言列名不算重复键', not (set(dup) & set(['en', 'ja', 'zh-Hant']))),
        ('单行条目解析出 3 列', len(data.get('单行条目', {})) == 3),
        ('多行条目解析出 3 列', len(data.get('多行条目', {})) == 3),
        ('{n} 模板键解析', data.get('{n} 局', {}).get('en') == '{n} rounds'),
        ('https:// 没被当注释吃掉',
         data.get('网址', {}).get('en') == 'see https://example.com/a{b}'),
        ('撇号没截断', data.get('带撇号', {}).get('en') == "it's the host's room"),
        ('重复键内容合并（后值覆盖）', data.get('重复的键', {}).get('en') == 'dup B'),
        ('stray = 0', stray == 0 and stray2 == 0),
    ]
    bad = [name for name, ok in checks if not ok]
    for name, ok in checks:
        if not ok:
            print('     ⚠️ 自检失败：%s' % name)
    return len(bad) == 0, len(checks)


def check_dict():
    s = read(I18N)
    data, dup, nkeys, stray = parse_extra(s)      # ★ 判据 1741：dup 只算顶层键
    bad = []
    for key, got in data.items():
        miss = [l for l in LANGS_REQ if l not in got]      # ★ zh-Hant 不在硬要求里（见 LANGS_REQ）
        empty = [l for l, v in got.items() if not v.strip()]
        if miss or empty:
            bad.append((key, miss, empty))
    # 覆盖率
    pairs = set()
    for p in glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True):
        txt = read(p)
        for pat in [r"\bL\('((?:[^'\\]|\\.)*)',\s*'((?:[^'\\]|\\.)*)'\)",
                    r"this\.t[n]?\('((?:[^'\\]|\\.)*)',\s*\n?\s*'((?:[^'\\]|\\.)*)'"]:
            for m in re.finditer(pat, txt):
                pairs.add(m.group(1).replace('\\n', '\n'))   # 源码 \n 转义 ⇒ 归一化比较
    covered = len(pairs & set(data.keys()))
    hant_missing = [k for k, got in data.items() if 'zh-Hant' not in got]
    print('  ═══ ① 字典 ═══')
    print('  条数          %d 条中文原文 × %d 语言 = %d 条译文'
          % (nkeys, len(LANGS_REQ), nkeys * len(LANGS_REQ)))
    if bad:
        fatal.append('字典有缺项 %d 条' % len(bad))
        print('  完整性        ⚠️ %d 条有缺' % len(bad))
        for k, m, e in bad[:10]:
            print('                  %-30s 缺 %s 空 %s' % (k[:30], m, e))
    else:
        print('  完整性        ✅ %d/%d 条 %d 语言齐全（含 {n} 模板条）'
              % (nkeys, nkeys, len(LANGS_REQ)))
    if hant_missing:
        print('  zh-Hant 未写   %d 条 —— 不算缺：L() 里明写「繁体缺项走 toTrad 转换，'
              '不退英文/简体」，判据 ④ 就在保这条路径' % len(hant_missing))
    else:
        print('  zh-Hant 未写   ✅ 0 条')
    if stray:
        fatal.append('EXTRA 有 %d 条值不是对象（类型错误）' % stray)
        print('  非对象条目    ⚠️ %d 条（Record<string, Record<string,string>> 不该有）' % stray)
    if dup:
        fatal.append('字典重复键 %s' % dup)
        print('  重复键        ⚠️ %s' % dup)
    else:
        print('  重复键        ✅ 无（只查顶层中文原文，语言列名不算键）')
    print('  代码覆盖率    %d/%d = %d%%  ← 未覆盖的 %d 条在 10 语言下退英文'
          % (covered, len(pairs), covered * 100 // max(1, len(pairs)), len(pairs) - covered))
    return data


def check_hant_path():
    """④ 繁体路径：L() 里不许出现 `cur === Lang.ZH || cur === Lang.ZHTW` 这种短路"""
    s = read(I18N)
    m = re.search(r'export function L\(zh: string, en: string\): string \{(.*?)\n\}', s, re.S)
    print('\n  ═══ ④ 繁体（zh-Hant）路径 ═══')
    if not m:
        fatal.append('找不到 L()')
        print('  ⚠️ 找不到 L()')
        return
    body = m.group(1)
    if re.search(r'Lang\.ZH\s*\|\|\s*cur\s*===\s*Lang\.ZHTW', body) or \
       re.search(r'cur\s*===\s*Lang\.ZHTW\s*\|\|', body):
        fatal.append('L() 仍把 zh-Hant 短路成简体')
        print('  ⚠️ L() 仍把 zh-Hant 短路成简体 —— 奥森报的「繁體無效」就是这个')
        return
    has_hant = 'Lang.ZHTW' in body
    has_conv = 'toTrad(' in body
    print('  zh-Hant 单独分支  %s' % ('✅' if has_hant else '⚠️ 没有'))
    print('  缺项走简→繁转换  %s（toTrad：%d 单字 + %d 词）'
          % ('✅' if has_conv else '⚠️ 没有', len(_s2t_from(s)), len(re.findall(r"', '", s[s.index('const S2T_WORDS'):s.index('];', s.index('const S2T_WORDS'))]))))
    if not (has_hant and has_conv):
        fatal.append('繁体路径不完整')


def _s2t_from(s):
    m = re.search(r"const S2T_FROM: string =\s*'([^']*)';", s)
    return m.group(1) if m else ''


def check_naked_chinese():
    """
    ⑤ 裸中文：中文串**不在任何取词调用里**才算裸（警告）

    ★ 2026-10-13 换判据：原来按"这一行有没有 this.t("整行跳过 ——
      于是混合行漏网（真案例：`this.t('看全部 ') + n + ' 个'` 的 `' 个'`
      在繁體下一直显示「个」，模拟器上被 `看全部 53 个` 抓个正着）。
      现在按**字符位置**判：中文串必须落在 t()/tn()/L()/… 的括号里。
    """
    print('\n  ═══ ⑤ 裸中文扫描（components / pages）═══')
    FUNCS = [r'\bTG[0-9]?', r'this\.t', r'this\.tn', r'\bL2?', r'\bTN', r'\bTZ', r'this\.sec', r'this\.kv',
             r'this\.chip', r'this\.statCell', r'this\.statBox', r'this\.switchRow', r'this\.navRow',
             r'this\.infoRow', r'this\.langChip', r'this\.segBtn', r'this\.sectionHeader',
             r'this\.sectionTitle', r'this\.modeChip', r'this\.barItem']
    call_re = re.compile('(?:' + '|'.join(FUNCS) + r')\s*\(')

    def spans_of(txt, rx):
        """平衡括号取调用区间（认字符串，别被引号里的括号骗）"""
        out = []
        for m in rx.finditer(txt):
            i = m.end() - 1
            d = 0
            j = i
            while j < len(txt):
                c = txt[j]
                if c == "'":
                    j += 1
                    while j < len(txt):
                        if txt[j] == '\\':
                            j += 2
                            continue
                        if txt[j] == "'":
                            break
                        j += 1
                elif c == '(':
                    d += 1
                elif c == ')':
                    d -= 1
                    if d == 0:
                        break
                j += 1
            out.append((i, j + 1))
        return out

    def comment_spans(txt):
        out = []
        for m in re.finditer(r'/\*.*?\*/', txt, re.S):
            out.append((m.start(), m.end()))
        for m in re.finditer(r'//[^\n]*', txt):
            out.append((m.start(), m.end()))
        return out

    hits = []
    for p in sorted(glob.glob(os.path.join(ETS, 'components/*.ets')) + glob.glob(os.path.join(ETS, 'pages/*.ets'))):
        txt = read(p)
        spans = spans_of(txt, call_re)
        cspans = comment_spans(txt)
        for m in re.finditer(r"'((?:[^'\\\n]|\\.)*)'", txt):
            lit = m.group(1)
            if not re.search(r'[\u4e00-\u9fff]', lit):
                continue
            if lit.strip() in ('一局', '中', '繁'):        # 品牌名 / 语言徽标，故意不翻
                continue
            if any(a <= m.start() < b for a, b in cspans):
                continue
            if any(a <= m.start() < b for a, b in spans):
                continue
            ln = txt[:m.start()].count('\n') + 1
            hits.append((os.path.relpath(p, ROOT), ln, lit[:40]))
    if hits:
        warn.append('裸中文 %d 处' % len(hits))
        print('  ⚠️ %d 处未走取词（这些在 10 语言下仍是中文）：' % len(hits))
        for f, i, lit in hits[:25]:
            print('     %s:%d  %s' % (f, i, lit))
        if len(hits) > 25:
            print('     … 还有 %d 处' % (len(hits) - 25))
    else:
        print('  ✅ 没有')
    return hits


def check_builder_trap():
    """
    ⑥ @Builder 记忆化陷阱（判据 1776 收窄版）

    ★ 旧版把**所有** `this.xxx( … this.t( … ) … )` 都报成"传算好的值"，
      结果是 3 条**误报**（`GamesTab.menuItem(...)` 那批）。
    ★ 判据 1776（2026-11-07 定案）：`@Builder` 每次渲染都会重新求值调用点，
      直接把 `this.t('中文','en')` 写在实参里**不是**陷阱 —— 闭包是新的。
    ★ 真正的陷阱只剩一种：**文案先在别处被算成变量/字段，再作为参数传进去**
      （那时 Builder 拿到的是一个已经定型的字符串，语言变了也不会变）。
      ⇒ 本检查只报这一种：
        · 实参是裸标识符/`this.xxx`（不是调用表达式），且
        · 该名字在本文件里被 `this.t(` / `this.tn(` / `TG(` 赋过值
      并且在**同一文件里真的声明为 `@Builder`** 的宿主上才检查（不再乱抓 this.xxx）。
    """
    print('\n  ═══ ⑥ @Builder 记忆化陷阱（判据 1776）═══')
    hits = []
    for p in sorted(glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True)):
        txt = read(p)
        # 本文件里的 @Builder 名字
        builders = set(re.findall(r'@Builder\s*\n\s*([A-Za-z_]\w*)\s*\(', txt))
        if not builders:
            continue
        # 被"先算好"的变量名：const x = this.t(...) / this.x = this.t(...)
        pre = set(re.findall(r'(?:const|let|var)\s+([A-Za-z_]\w*)\s*[:=][^;\n]*?(?:this\.t[n]?\(|TG\(|L\()', txt))
        pre |= set(re.findall(r'this\.([A-Za-z_]\w*)\s*=[^;\n]*?(?:this\.t[n]?\(|TG\(|L\()', txt))
        for m in re.finditer(r'this\.([A-Za-z_]\w*)\(', txt):
            name = m.group(1)
            if name not in builders:
                continue
            i = m.end() - 1
            depth = 0
            j = i
            while j < len(txt):
                if txt[j] == '(':
                    depth += 1
                elif txt[j] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            args = txt[i + 1:j]
            if len(args) > 600:
                continue
            # 直接内联 this.t(...) ⇒ 判据 1776 明确不算，跳过
            if re.search(r'this\.t[n]?\(|TG\(|L\(', args):
                continue
            for ident in re.findall(r'^\s*(?:this\.)?([A-Za-z_]\w*)\s*$', args, re.M):
                if ident in pre:
                    ln = txt[:m.start()].count('\n') + 1
                    hits.append((os.path.relpath(p, ROOT), ln, name, ident))
    if hits:
        warn.append('@Builder 传"已算好的变量" %d 处' % len(hits))
        print('  ⚠️ %d 处：文案先算成变量再传进 @Builder（换语言不会重建）：' % len(hits))
        for f, ln, name, ident in hits[:20]:
            print('     %s:%d  this.%s(%s)' % (f, ln, name, ident))
    else:
        print('  ✅ 没有')
        print('     （判据 1776：实参里直接写 this.t(...) 不算陷阱 —— 闭包每次新，已排除）')


def check_enum_tg():
    """
    ⑫ enum 成员不能持 `TG()`（判据 1745）

    ★ 为什么：`enum` 是**模块加载时**求值的，那时 `I18n.current()` 还没初始化
      （语言要等 ProgressStore.init 从盘里读回来）⇒ 枚举值会被永久钉在首启语言上，
      切语言也不变。合法例外是**中文字面量**（`Seg.ALL = '全部'`），它不是 TG 调用。
    """
    print('\n  ═══ ⑫ enum 持 TG()（判据 1745）═══')
    bad = []
    for p in sorted(glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True)):
        txt = read(p)
        for m in re.finditer(r'enum\s+([A-Za-z_]\w*)\s*\{', txt):
            # 取枚举体
            i = m.end() - 1
            depth = 0
            j = i
            while j < len(txt):
                if txt[j] == '{':
                    depth += 1
                elif txt[j] == '}':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body = txt[i + 1:j]
            if re.search(r'=\s*(?:TG[24]?|L|this\.t)\s*\(', body):
                ln = txt[:m.start()].count('\n') + 1
                bad.append('%s:%d enum %s' % (os.path.relpath(p, ROOT), ln, m.group(1)))
    if bad:
        fatal.append('enum 成员持 TG() %d 处' % len(bad))
        print('  ❌ %d 处（模块加载时求值 ⇒ 永远钉在首启语言）：' % len(bad))
        for b in bad[:15]:
            print('     ' + b)
        print('     修法：枚举存**中文原文**，在用的时候再 TG(枚举值)')
    else:
        print('  ✅ 没有')


def check_accent_id_as_color():
    """⑦ 主题色：this.accent（id）不能直接当颜色"""
    print('\n  ═══ ⑦ 主题色 id 当颜色用 ═══')
    bad = []
    for p in glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True):
        txt = read(p)
        for m in re.finditer(r'\.(backgroundColor|fontColor|selectedColor|borderColor)\(\s*this\.accent\s*\)', txt):
            ln = txt[:m.start()].count('\n') + 1
            bad.append('%s:%d %s(this.accent)' % (os.path.relpath(p, ROOT), ln, m.group(1)))
    if bad:
        fatal.append('主题色 id 被当颜色用 %d 处' % len(bad))
        print('  ⚠️ %d 处把 id 当颜色（system 会渲染成非法色）：' % len(bad))
        for b in bad[:15]:
            print('     ' + b)
    else:
        print('  ✅ 没有')
    # Design 里 Palette.primary 必须是可变的（否则选了不变）
    d = read(DESIGN)
    mutable = re.search(r'static primary: string', d) is not None
    print('  Palette.primary 可变  %s' % ('✅' if mutable else '⚠️ 仍是 readonly ⇒ 主题色改了也不生效'))
    print('  Accent 档位           %d 档' % len(re.findall(r'\{ id: ', d)))
    if not mutable:
        fatal.append('Palette.primary 仍不可变')


def check_binary_t():
    """
    ⑨ 中英二元式的 `t()` 实现（硬失败）

    ★ 本轮（2026-10-13）抓到的**第二类根因**：组件里的 `t(zh, en)` 自己写成
      `return observed === 'en' ? en : zh;` ⇒ **整个文件的文案在 10 种语言下全退中文**
      （繁体也一并被吞）。它比裸中文更隐蔽：调用点写得规规矩矩，坏在 helper 里。
      实锤过的文件：StatsTab / GuidePage / GameHost / LanLobby（4 个，2026-10-13 已修）。
    """
    print('\n  ═══ ⑨ 中英二元 t() 陷阱 ═══')
    bad = []
    for p in glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True):
        if '/games/' in p:
            continue          # 354 个游戏文件由 games-input 负责
        txt = read(p)
        for m in re.finditer(r'private\s+t\s*\(\s*zh\s*:\s*string\s*,\s*en\s*:\s*string\s*\)[^{]*\{', txt):
            i = m.end() - 1
            d = 0
            j = i
            while j < len(txt):
                if txt[j] == '{':
                    d += 1
                elif txt[j] == '}':
                    d -= 1
                    if d == 0:
                        break
                j += 1
            body = strip_code(txt[i + 1:j])   # ★ 先去注释：我修的时候在注释里写了旧代码，别自证其罪
            if re.search(r"\?\s*en\s*:\s*zh", body) or re.search(r"isEN\(\)\s*\?", body):
                ln = txt[:m.start()].count('\n') + 1
                bad.append('%s:%d' % (os.path.relpath(p, ROOT), ln))
        for m in re.finditer(r"return\s+[^;\n]*===\s*'en'\s*\?\s*en\s*:\s*zh", txt):
            ln = txt[:m.start()].count('\n') + 1
            bad.append('%s:%d' % (os.path.relpath(p, ROOT), ln))
    if bad:
        fatal.append('中英二元 t() %d 处' % len(set(bad)))
        print('  ⚠️ %d 处（这些文件在 10 语言下全退中文）：' % len(set(bad)))
        for b in sorted(set(bad))[:15]:
            print('     ' + b)
    else:
        print('  ✅ 没有（components/ + pages/ + core/ 的 t() 都走 L()）')


def check_ingame_dict():
    """
    ⑩ 游戏内字典（GameI18n）—— 120 条游戏文案必须十条语言列齐全

    为什么单独查：这批文案是 354 个游戏文件里 `TG('…')` 的落点（2,284 处调用），
    缺一列 ⇒ 那种语言在游戏内退英文/中文。空串是**合法值**（片段在该语言里本就该消失），
    所以这里只查"列在不在"，不查空不空。
    """
    print('\n  ═══ ⑩ 游戏内字典（GameI18n）═══')
    p = os.path.join(ETS, 'core/GameI18n.ets')
    src = read(p)
    # ★ 判据 1741：DICT 不是严格 JSON（夹着 // 注释、尾逗号）⇒ 不再 json.loads，
    #   改用与 EXTRA 同一把**结构化**解析器（括号栈 + 跳字符串），
    #   否则永远停在「Expecting property name enclosed in double quotes: line 1325」。
    entries, stray = parse_dict_literal(src, 'const DICT:')
    if entries is None:
        fatal.append('GameI18n 字典解析失败（找不到 const DICT: 的对象体）')
        print('  ⚠️ 解析失败：找不到 const DICT: 的对象体')
        return
    data = {}
    nkeys = 0
    for raw, row in entries:
        key = _key_text(raw)
        nkeys += 1
        data.setdefault(key, {}).update(row)
    LANGS10 = ['en', 'ja', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'it', 'ar']
    miss = [k for k, row in data.items() if [l for l in LANGS10 if l not in row]]
    print('  条数            %d 条 × %d 语言' % (nkeys, len(LANGS10)))
    if miss:
        fatal.append('GameI18n 缺列 %d 条' % len(miss))
        print('  缺列            ⚠️ %d 条：%s' % (len(miss), miss[:5]))
    else:
        print('  十语言列齐全    ✅ %d/%d（解析器自检过的排版：单行 + 注释 + 尾逗号）'
              % (nkeys, nkeys))
    if stray:
        print('  非对象条目      ⚠️ %d 条' % stray)
    if 'toTrad(zh)' in src:
        print('  繁体走转换      ✅')
    else:
        fatal.append('GameI18n 繁体没走 toTrad')
        print('  繁体走转换      ⚠️ 没有')


def check_core_imports():
    """
    ⑪ core 导出符号的导入完整性（硬失败）

    ★ 2026-10-13 血教训：`Common.ets` 用了 `displayName/displayTagline` 却忘了 import
      ⇒ **真机构建直接 FAILED**（ArkTS: Cannot find name 'displayName'），
      而 codelinter 报的是 "No defects"（它不做名字解析）⇒ 只能靠这条脚本兜。
    """
    print('\n  ═══ ⑪ core 导出符号的导入完整性 ═══')
    # 所有本地模块的导出（不只 core —— 组件之间互相 import 也会漏）
    exported = {}
    own = {}
    for p in glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True):
        txt = read(p)
        names = set(re.findall(r'export\s+(?:function|class|const|interface|enum)\s+([A-Za-z_][A-Za-z0-9_]*)', txt))
        own[os.path.relpath(p, ROOT)] = names
        for n in names:
            exported.setdefault(n, os.path.relpath(p, ROOT))
    bad = []
    for p in glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True):
        rel = os.path.relpath(p, ROOT)
        txt = read(p)
        imported = set()
        for m in re.finditer(r"import\s*\{([^}]*)\}\s*from", txt):
            for name in m.group(1).split(','):
                imported.add(name.strip().split(' as ')[0].strip())
        defined = set(re.findall(r'(?:function|class|const|interface|enum)\s+([A-Za-z_][A-Za-z0-9_]*)', txt))
        defined |= own.get(rel, set())   # 本文件自己的导出/定义不算缺 import
        masked = strip_code(txt)   # 去注释 + 去字符串，只留代码（避免注释里提到名字就误报）
        for name in exported:
            if name in imported or name in defined:
                continue
            # 本文件里"声明过"就不算缺 import：参数/字段（name: Type）、方法（name(...): / name(...) {）
            if re.search(r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\s*:\s*[A-Za-z_]', masked):
                continue
            if re.search(r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\s*\([^)]*\)\s*[:{]', masked):
                continue
            # 只认"像调用/类型注解"的用法：前面不是 . 或字母数字，后面紧跟 ( < : [ 或空格
            m = re.search(r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\s*[(<:\[]', masked)
            if not m:
                continue
            ln = masked[:m.start()].count('\n') + 1
            bad.append('%s:%d 用了 %s（定义在 core/%s）却没 import' % (os.path.relpath(p, ROOT), ln, name, exported[name]))
    if bad:
        fatal.append('core 导出符号没 import %d 处' % len(bad))
        print('  ⚠️ %d 处（真机构建会 FAILED，codelinter 抓不到）：' % len(bad))
        for b in bad[:15]:
            print('     ' + b)
    else:
        print('  ✅ 没有（用到的 core 导出符号都 import 了）')


def check_balance():
    """⑧ 三个受管文件的结构配平"""
    print('\n  ═══ ⑧ 结构配平 ═══')
    for p in MANAGED:
        txt = strip_code(read(p))   # 注释和字符串都已经换成空白
        pairs = {'{': '}', '(': ')', '[': ']'}
        stack = []
        ok = True
        for ch in txt:
            if ch in pairs:
                stack.append(ch)
            elif ch in pairs.values():
                if not stack or pairs[stack.pop()] != ch:
                    ok = False
                    break
        if stack:
            ok = False
        rel = os.path.relpath(p, ROOT)
        print('  %-50s %s' % (rel, '✅' if ok else '⚠️ 括号不配平'))
        if not ok:
            fatal.append('%s 括号不配平' % rel)


def main():
    # ★ 判据 1741：先修尺子再量东西 —— 解析器先过反证自检，失败就别信后面的数字
    ok, n = self_test()
    print('  ═══ ⓪ 解析器自检（%d 条反证）═══' % n)
    print('  %s' % ('✅ 通过（多行/单行/注释/尾逗号/{n}模板/https:// 都能吃）' if ok else '⚠️ 失败'))
    if not ok:
        print('\n  ❌ 解析器自检没过，后面的字典数字不可信 ⇒ 先修解析器')
        return 1
    entries = check_dict()
    check_hant_path()
    naked = check_naked_chinese()
    check_builder_trap()
    check_accent_id_as_color()
    check_binary_t()
    check_enum_tg()
    check_ingame_dict()
    check_core_imports()
    check_balance()
    print('\n  ═══ 结论 ═══')
    if fatal:
        print('  ❌ 硬失败 %d 项：' % len(fatal))
        for f in fatal:
            print('     · ' + f)
    if warn:
        print('  ⚠️ 警告 %d 项：%s' % (len(warn), '、'.join(warn)))
    if not fatal:
        print('  ✅ 无硬失败（警告项是"同类全扫"清单，见上）')
    return 1 if fatal else 0


if __name__ == '__main__':
    sys.exit(main())
