#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""双符号检查器（判据 1782）—— 字典译文自带符号 + 组件又画一个

★ 为什么要它（2026-11-07 一晚踩了两次）：
  · C-1 成就墙：`this.t('收起')` 的 10 语言译文全自带 ▲（「閉じる ▲」「Weniger ▲」…），
    而组件右边又画了一个 `Text('▲')` ⇒ 11 种语言显示「閉じる ▲ ▲」。
  · C-2 等级头卡：`this.t(TG('今日已打卡'))` 的译文自带 ✅，组件左边又画 `Text('✅')`
    ⇒ 11 种语言显示「✅ ✅ Heute erledigt」。
  两次都是同一个机理：**组件把符号当视觉锚** + **译者顺手把符号带进译文**。
  ⇒ 判据 1782：字典键/译文里已有符号时，组件不得再画同一个符号。
  ⇒ 本脚本就是这条判据的**可执行形式**（能写成脚本的规矩，不要只写成文字）。

★ 检查什么（只认「相邻兄弟节点」，不做跨容器猜测）
  ① 一个 `Text('✅'/'⭕'/'▲'/'▼'/'›'/'‹'/'▶'/'…')`（**纯符号**，含三元 `this.x ? '▲' : '▼'`）
  ② 同缩进、±8 行内，有另一个 `Text(this.t(TG('xxx')) / this.t('xxx', 'en') / TG('xxx') / L('xxx'))`
  ③ 把 `xxx` 在 **I18n.EXTRA + GameI18n.DICT** 里所有语言的译文取出来，
     只要有**任一语言以该符号开头或结尾** ⇒ 报「可能的双符号」
  ⚠️ 只查「开头/结尾」：符号出现在句子中间（如「大→小は掛け算」）是正文，不算。

★ 白名单（写清理由，宁可窄不要宽）
  见 WHITELIST；只按「文件 glob + 符号」放行，放行的每一类都写明为什么不是重复。

用法：
  python3 tools/check_dup_symbol.py            # 全仓扫，有命中退出码 1
  python3 tools/check_dup_symbol.py --verbose  # 同时打印白名单放行明细
  python3 tools/check_dup_symbol.py --self-test  # 先验证尺子自己（反证用例）
退出码：0 = 无命中 ｜ 1 = 有命中 ｜ 2 = 解析失败/自检失败
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

# ════════════════════════════════════════════════════════════════════════════
#  字典解析：优先复用 check_i18n.py（判据 1741 修过的那个解析器），
#  但它正在被队友频繁改动（2026-11-07 22:39 才改过一次）⇒ 留一份**自包含兜底**，
#  避免「队友改名/重构 ⇒ 本检查器直接罢工」。两条实现都按「括号栈 + 跳过字符串」写，
#  字典条数必须对得上（自检里会比）。
# ════════════════════════════════════════════════════════════════════════════
QUOTE_START = ('"', "'", '`')


def _skip_str(t, i):
    q = t[i]
    i += 1
    n = len(t)
    while i < n:
        if t[i] == '\\':
            i += 2
            continue
        if t[i] == q:
            return i + 1
        i += 1
    return n


def _obj_end(t, i):
    depth = 0
    n = len(t)
    while i < n:
        c = t[i]
        if c in QUOTE_START:
            i = _skip_str(t, i)
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def _blank(s):
    """去掉 // 与 /* */ 注释（保留字符串与偏移长度）"""
    out = list(s)
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c in QUOTE_START:
            i = _skip_str(s, i)
            continue
        if c == '/' and i + 1 < n and s[i + 1] == '/':
            j = s.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
            continue
        if c == '/' and i + 1 < n and s[i + 1] == '*':
            j = s.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        i += 1
    return ''.join(out)


_ENTRY_OBJ = re.compile(r'\s*"((?:[^"\\]|\\.)*)"\s*:\s*\{')
_PAIR2 = re.compile(r'"([A-Za-z][A-Za-z-]{0,9})"\s*:\s*"((?:[^"\\]|\\.)*)"')


def local_parse_dict(src, marker):
    """兜底解析：`const XXX = { "键": { "en": "…" } }` ⇒ (entries, stray)。

    与 check_i18n.parse_dict_literal 同构（多行/单行/注释/`{n}` 模板都能吃）。
    """
    try:
        i = src.index(marker)
        b = src.index('{', i)
    except ValueError:
        return None, 0
    end = _obj_end(src, b)
    inner = _blank(src[b + 1:end - 1])
    entries, stray, k, n = [], 0, 0, len(inner)
    while k < n:
        m = _ENTRY_OBJ.match(inner, k)
        if m:
            j = m.end() - 1
            e = _obj_end(inner, j)
            row = {}
            for pm in _PAIR2.finditer(inner[j + 1:e - 1]):
                row[pm.group(1)] = pm.group(2)
            entries.append(('"' + m.group(1) + '"', row))
            k = e
            continue
        if inner[k] in ' \t\r\n,':
            k += 1
            continue
        k += 1
    return entries, stray


def local_parse_extra(src):
    entries, stray = local_parse_dict(src, 'const EXTRA:')
    data, keys = {}, []
    if entries is None:
        return {}, [], 0, 0
    for raw, row in entries:
        key = raw[1:-1]
        keys.append(key)
        data.setdefault(key, {}).update(row)
    return data, [], len(keys), stray


PARSER_SRC = 'check_i18n'
parse_extra, parse_dict_literal, _key_text = local_parse_extra, local_parse_dict, (lambda raw: raw[1:-1])
if '--no-import' not in sys.argv:
    try:
        from check_i18n import parse_extra as _pe, parse_dict_literal as _pd, _key_text as _kt
        parse_extra, parse_dict_literal, _key_text = _pe, _pd, _kt
        PARSER_SRC = 'check_i18n'
    except Exception:                                    # 队友重构/改名时走兜底，不罢工
        PARSER_SRC = 'local-fallback'

# ── 符号表：组件会拿来做「视觉锚」的那些 ──
#   箭头/尖括号 + 状态 emoji（✅⭕❌✓）+ 游戏常用的 ▲▼▶◀
SYMBOLS = '✅⭕❌✓★☆▲▼◀▶◄►▸▾›‹→←↑↓«»⌄⌃…🔍🔒'

# ── 白名单：只放行「明确不是重复」的组合，每条必须写理由 ──
#   key: (文件 glob, 符号集合) ；value: 理由（打印时带上，便于审计白名单是否过期）
WHITELIST = [
    ('entry/src/main/ets/games/*.ets', '↑↓←→▲▼◀▶◄►▸▾',
     '玩法方向键/棋子符号：这些 Text 就是方向控件本身（padBtn/dirBtn/moveBtn 的图标），'
     '旁边的标签是「动作名」而不是同一符号；符号属于玩法语义，不随语言变'),
    ('entry/src/main/ets/pages/*.ets', '‹›',
     '返回箭头纯图标按钮：标签只通过 accessibilityText 给读屏，屏幕上看不到第二个符号'),
    ('entry/src/main/ets/components/*.ets', '‹›',
     '同上：纯图标按钮/列表右箭头，可见标签是功能行文字，译文不含 ‹ ›'),
]

# 运行时**剥符号**的写法：出现在标签参数里 ⇒ 该处不会重复（如 StatsTab.stripArrow）
# ★★★ 2026-11-07 修：原来后顾是 `(?<![\w$.])` —— **把 `.` 也排除了**，
#   而真实写法就是 `this.stripArrow(this.t('收起','Less'))`（方法调用必带点）
#   ⇒ 这条豁免一次都没命中过，已修的 C-1 会被永远报成「疑似双符号」。
#   ⇒ 后顾只排「标识符字符」，不再排 `.`；`stripArrowX(` 这类仍不会误命中（名字后必须紧跟 `(`）。
SANITIZE_RE = re.compile(
    r"(?<![\w$])(?:stripArrow|stripArrows|trimArrow|stripMark|stripMarks|stripLeadingMark|stripEdgeMark|stripSymbols?|stripEmoji)\s*\("
    r"|\.replace\s*\(\s*'[^']*[" + SYMBOLS + r"][^']*'"
)

# 覆盖统计：0 命中必须能证明「真的看过了」，而不是解析器瞎了
STATS = {'files': 0, 'sym_nodes': 0, 'label_nodes': 0, 'pairs': 0}

SCAN_DIRS = ['entry/src/main/ets/components', 'entry/src/main/ets/pages', 'entry/src/main/ets/games']


# ════════════════════════════════════════════════════════════════════════════
#  源码处理：只把**注释**抹成空格（字符串**必须保留**，要读里面的符号与键）
# ════════════════════════════════════════════════════════════════════════════
def mask_comments(src):
    """把 // 与 /* */ 注释替换成空格（保留换行与全部偏移），字符串原样保留。

    与 check_i18n.strip_code() 的差别：那个把字符串也抹掉（它只做结构检查）。
    本检查器要**读**字符串内容（'✅'、'收起'），所以只能抹注释。
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in '"\'`':                                  # 字符串：整段跳过
            q = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        i += 1
    return ''.join(out)


def match_paren(masked, open_idx):
    """open_idx 指向 '('，返回配对 ')' 的下标（失败 -1）"""
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


def call_sites(masked, name):
    """找 `name(` 调用 ⇒ [(起始, 结束, 参数文本, 行号, 行缩进)]"""
    out = []
    for m in re.finditer(r'(?<![\w$.])' + re.escape(name) + r'\(', masked):
        op = m.end() - 1
        cl = match_paren(masked, op)
        if cl < 0:
            continue
        arg = masked[op + 1:cl]
        line = masked.count('\n', 0, m.start()) + 1
        ls = masked.rfind('\n', 0, m.start()) + 1
        indent = len(masked[ls:m.start()]) - len(masked[ls:m.start()].lstrip(' '))
        out.append((m.start(), cl, arg, line, indent))
    return out


LITERAL_RE = re.compile(r"'([^'\\]*(?:\\.[^'\\]*)*)'")


def literals(arg):
    return [m.group(1) for m in LITERAL_RE.finditer(arg)]


def only_symbols(arg):
    """参数是不是「纯符号」：所有字符串字面量都是 1~2 个符号、且没有其它裸标识符。

    允许两种形态：
      Text('✅')
      Text(this.x ? '✅' : '⭕')
    """
    lits = literals(arg)
    if not lits:
        return []
    syms = []
    for s in lits:
        if not s or len(s) > 2 or any(ch not in SYMBOLS for ch in s):
            return []
        syms.extend(list(s))
    # 去掉字符串后剩下的部分只能是三元/取反这类骨架（不含字母，除 this/true/false 外）
    rest = LITERAL_RE.sub('', arg)
    if re.search(r'[A-Za-z_][\w$]*', rest):
        # 允许 this.xxx / true / false 参与判断；出现别的函数调用就不算纯符号
        if re.search(r'(?<![\w$.])(?!this\b|true\b|false\b)[A-Za-z_][\w$]*\s*\(', rest):
            return []
    uniq = []
    for s in syms:
        if s not in uniq:
            uniq.append(s)
    return uniq


LABEL_CALL = re.compile(r'(?:this\.t|this\.tn|L)\s*\(')
LABEL_KEY = re.compile(r"(?:this\.t|this\.tn|L|TG)\s*\(\s*(?:TG\s*\(\s*)?'([^'\\]*(?:\\.[^'\\]*)*)'")


def label_keys(arg):
    """参数里的**全部**字典键（三元的两个分支都要查）。

    为什么必须取全部：C-2 的写法是
      `Text(this.solvedToday ? this.t(TG('今日已打卡')) : this.t(TG('还没玩 · 来一局就打卡')))`
    而**只有第二支**的译文带 ⭕ —— 只取第一个键会漏掉未打卡状态的双符号。
    """
    if not (LABEL_CALL.search(arg) or re.search(r'(?<![\w$.])TG\s*\(', arg)):
        return []
    keys = []
    for m in LABEL_KEY.finditer(arg):
        key = m.group(1)
        if key and '\n' not in key and key not in keys:
            keys.append(key)
    return keys


# ════════════════════════════════════════════════════════════════════════════
#  字典：全部译文（I18n.EXTRA + GameI18n.DICT）
# ════════════════════════════════════════════════════════════════════════════
def load_translations():
    i18n_src = io.open(os.path.join(ETS, 'core/I18n.ets'), encoding='utf-8').read()
    extra, _dup, n_extra, _stray = parse_extra(i18n_src)
    gi_src = io.open(os.path.join(ETS, 'core/GameI18n.ets'), encoding='utf-8').read()
    entries, _stray2 = parse_dict_literal(gi_src, 'const DICT:')
    if entries is None:
        print('  🔴 GameI18n DICT 解析失败')
        sys.exit(2)
    in_game = {}
    for raw, row in entries:
        in_game.setdefault(_key_text(raw), {}).update(row)
    return extra, in_game, n_extra, len(in_game)


def boundary_symbols(key, extra, in_game, symbols):
    """key 的任一语言译文是否以 symbols 里的符号**开头或结尾**"""
    row = {}
    row.update(in_game.get(key, {}))
    row.update(extra.get(key, {}))
    hits = []
    for lang, v in row.items():
        if not isinstance(v, str):
            continue
        t = v.strip()
        if not t:
            continue
        for s in symbols:
            if t.startswith(s) or t.endswith(s):
                hits.append((lang, s, t))
                break
    return hits, row


# ════════════════════════════════════════════════════════════════════════════
#  相邻兄弟判定
# ════════════════════════════════════════════════════════════════════════════
def container_break(masked_lines, a, b, base_ind):
    """a..b 行之间有没有「比**标签**缩进更浅的 }」——有就说明跨了容器。

    ★ 阈值必须用**标签的缩进**，不能用符号那行的缩进：
      C-2 的符号被 `if (!solvedToday) { Text('⭕') }` 包了一层（缩进 +2），
      它自己的闭合 `}` 缩进等于标签缩进 —— 若拿符号缩进当阈值，会把「同一个兄弟」误判成跨容器（漏报）。
    """
    lo, hi = min(a, b), max(a, b)
    for k in range(lo, hi - 1):
        line = masked_lines[k]
        st = line.lstrip(' ')
        if st.startswith('}') and (len(line) - len(st)) < base_ind:
            return True
    return False


def sibling_ok(lines, sym_ln, sym_ind, lab_ln, lab_ind):
    """两个 Text 是不是**同一容器里的兄弟**。

    ★ 除了「同缩进」，还要认一种常见写法：符号被 `if (...) { Text('⭕') }` 包一层
      （缩进 +2），而条件块本身和标签同缩进 —— 渲染出来仍是并排的两个兄弟。
      2026-11-07 的 C-2 残案（未打卡分支）就栽在这：符号 Text 在 `if` 里、标签在 `if` 外，
      只看缩进会**漏报**。
    """
    if lab_ln < 1 or lab_ln > len(lines) or sym_ln < 1 or sym_ln > len(lines):
        return False
    if container_break(lines, sym_ln, lab_ln, lab_ind):
        return False
    if sym_ind == lab_ind:
        return True
    if sym_ind > lab_ind:
        # 往上看两层，找「与标签同缩进的 if/else if 开块」
        for k in (sym_ln - 1, sym_ln - 2):
            if k < 1 or k > len(lines):
                continue
            raw = lines[k - 1]
            ind = len(raw) - len(raw.lstrip(' '))
            st = raw.strip()
            if ind == lab_ind and re.match(r'^(if|else if)\b.*\{\s*$', st):
                return True
    return False


def scan_file(path, extra, in_game, verbose):
    rel = os.path.relpath(path, ROOT)
    src = io.open(path, encoding='utf-8').read()
    masked = mask_comments(src)
    lines = masked.split('\n')

    texts = call_sites(masked, 'Text')
    sym_nodes, label_nodes = [], []
    for (st, en, arg, ln, ind) in texts:
        syms = only_symbols(arg)
        if syms:
            sym_nodes.append((st, en, arg, ln, ind, syms))
            continue
        keys = label_keys(arg)
        if keys:
            label_nodes.append((st, en, arg, ln, ind, keys))

    STATS['files'] += 1
    STATS['sym_nodes'] += len(sym_nodes)
    STATS['label_nodes'] += len(label_nodes)

    hits, allowed, sanitized = [], [], []
    for (st, en, arg, ln, ind, syms) in sym_nodes:
        for (lst, len_, larg, lln, lind, keys) in label_nodes:
            if abs(lln - ln) > 8 or lln == ln:
                continue
            if not sibling_ok(lines, ln, ind, lln, lind):
                continue
            STATS['pairs'] += 1
            # 标签在运行时已剥掉符号（stripArrow 等）⇒ 可见效果不重复，不算问题
            if SANITIZE_RE.search(larg):
                sanitized.append({'file': rel, 'line': ln, 'label_line': lln,
                                  'symbols': syms, 'key': keys[0] if keys else '',
                                  'src': lines[ln - 1].strip()[:110]})
                break
            found, key = [], ''
            for k in keys:
                found, _row = boundary_symbols(k, extra, in_game, syms)
                if found:
                    key = k
                    break
            if not found:
                continue
            item = {
                'file': rel, 'line': ln, 'label_line': lln, 'symbols': syms,
                'key': key, 'langs': found, 'src': lines[ln - 1].strip()[:110],
            }
            rule = whitelisted(rel, syms)
            if rule:
                item['why'] = rule
                allowed.append(item)
            else:
                hits.append(item)
            break                      # 一个符号节点只配一个最近标签
    return hits, allowed, sanitized


def whitelisted(rel, syms):
    for glob_pat, sym_set, why in WHITELIST:
        if fnmatch.fnmatch(rel, glob_pat) and all(s in sym_set for s in syms):
            return why
    return None


# ════════════════════════════════════════════════════════════════════════════
#  自检（反证尺子）：判据「先修尺子再量」
# ════════════════════════════════════════════════════════════════════════════
SELF_POSITIVE = '''
@Component
struct Demo {
  build() {
    Row() {
      Text(this.solvedToday ? '✅' : '⭕')
      Text(this.solvedToday ? this.t(TG('今日已打卡'), 'Checked in today') : this.t('别的', 'Other'))
    }
  }
}
'''
SELF_NEGATIVE = '''
@Component
struct Demo {
  build() {
    Row() {
      Text(this.solvedToday ? '✅' : '⭕')
      Text(this.t('随便一句', 'Some line'))
    }
    Row() {
      Text('▲')
    }
    Row() {
      Text(this.t('收起', 'Less'))
    }
  }
}
'''
SELF_SANITIZED = '''
@Component
struct Demo {
  private stripArrow(s: string): string { return s; }
  build() {
    Row() {
      Text(this.stripArrow(this.t('收起', 'Less')))
      Text(this.achvExpanded ? '▲' : '▼')
    }
  }
}
'''
SELF_FACTS = {
    '今日已打卡': {'ja': '✅ 今日チェックイン済み', 'de': '✅ Heute erledigt'},
    '别的': {'de': 'Anderes'},
    '随便一句': {'de': 'Eine Zeile'},
    '收起': {'ja': '閉じる ▲', 'de': 'Weniger ▲'},
}


def self_test():
    """两块反证：① 真重复必须报 ② 跨容器/无符号的必须不报"""
    ok = []
    extra = dict(SELF_FACTS)
    in_game = {}
    tmp = os.path.join(ROOT, 'tools', '_self_test_dup.ets')
    try:
        io.open(tmp, 'w', encoding='utf-8').write(SELF_POSITIVE)
        h, a, _s = scan_file(tmp, extra, in_game, False)
        ok.append(('正例必须命中（✅ 双符号）', len(h) == 1 and '✅' in h[0]['symbols'],
                   '%d 处 %s' % (len(h), [x['symbols'] for x in h])))
        io.open(tmp, 'w', encoding='utf-8').write(SELF_NEGATIVE)
        h2, a2, _s2 = scan_file(tmp, extra, in_game, False)
        # 负例里「随便一句」译文不含 ✅ ⇒ 不该报；「收起」在 Column 里跨了容器 ⇒ 不该报
        ok.append(('负例必须 0 命中（无符号 / 跨容器）', len(h2) == 0, '%d 处' % len(h2)))
        # 反证 3：标签在运行时剥符号（stripArrow）⇒ 不算重复，但要记进 sanitized
        io.open(tmp, 'w', encoding='utf-8').write(SELF_SANITIZED)
        h3, a3, s3 = scan_file(tmp, extra, in_game, False)
        ok.append(('stripArrow 净化写法不报，且记入 sanitized',
                   len(h3) == 0 and len(s3) == 1, '命中 %d / 净化 %d' % (len(h3), len(s3))))
        # 反证 4：白名单只对写明的目录+符号生效
        ok.append(('白名单：games 方向键放行',
                   whitelisted('entry/src/main/ets/games/GDemo.ets', ['↑']) is not None, ''))
        ok.append(('白名单：components 的 ▲ 不放行（正是 C-1 的符号）',
                   whitelisted('entry/src/main/ets/components/X.ets', ['▲']) is None, ''))
        ok.append(('白名单：pages 的 ✅ 不放行',
                   whitelisted('entry/src/main/ets/pages/Index.ets', ['✅']) is None, ''))
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass
    for name, passed, got in ok:
        print('     %s %s（实际 %s）' % ('✅' if passed else '❌', name, got))
    return all(p for _, p, _ in ok)


# ════════════════════════════════════════════════════════════════════════════
def main():
    verbose = '--verbose' in sys.argv
    if '--self-test' in sys.argv:
        print('  ═══ 自检（反证尺子）═══')
        return 0 if self_test() else 2

    files = []
    for d in SCAN_DIRS:
        files += sorted(glob.glob(os.path.join(ROOT, d, '*.ets')))
    if not files:
        print('  🔴 没找到 .ets 文件（检查路径）')
        return 2
    extra, in_game, n_extra, n_game = load_translations()
    # ★ 解析器体检：I18n.ets 里有**三个**字典（GAME_NAME / GAME_TAGLINE / EXTRA），
    #   L() 只查 EXTRA（427 条）；GameI18n 的 DICT 是 TG 用的（4563 条）。
    #   所以按「条数量级 + 已知键抽查」双保险，别拿拍脑袋的总数当门槛。
    probe = [k for k in ('收起', '今日已打卡', '开始 ›') if (extra.get(k) or in_game.get(k))]
    if n_extra < 300 or n_game < 3000 or len(probe) < 2:
        print('  🔴 字典解析异常（EXTRA %d / DICT %d / 抽查命中 %d）⇒ 先修解析器再量'
              % (n_extra, n_game, len(probe)))
        return 2

    all_hits, all_allowed, all_sanitized = [], [], []
    for p in files:
        h, a, san = scan_file(p, extra, in_game, verbose)
        all_hits += h
        all_allowed += a
        all_sanitized += san

    print('  ═══ 双符号检查（判据 1782）═══')
    print('  扫描 .ets：%d 个（components/pages/games）' % len(files))
    print('  字典：EXTRA %d 条 ｜ GameI18n %d 条' % (n_extra, n_game))
    print('  覆盖：纯符号 Text %d 个 ｜ 带字典键的标签 Text %d 个 ｜ 相邻配对 %d 对'
          % (STATS['sym_nodes'], STATS['label_nodes'], STATS['pairs']))
    if STATS['sym_nodes'] == 0:
        print('  🔴 一个纯符号 Text 都没找到 ⇒ 解析器有问题，这次「0 处」不可信')
        return 2
    if verbose and all_allowed:
        print('\n  白名单放行 %d 处：' % len(all_allowed))
        for it in all_allowed:
            print('     · %s:%d %s ← 「%s」' % (it['file'], it['line'],
                                              ''.join(it['symbols']), it['key']))
            print('       理由：%s' % it['why'])
    if all_hits:
        print('\n  ❌ 疑似双符号 %d 处：' % len(all_hits))
        for it in all_hits:
            print('     · %s:%d  %s  +  %s:%d 的「%s」' % (
                it['file'], it['line'], ''.join(it['symbols']),
                it['file'], it['label_line'], it['key']))
            for (lang, sym, val) in it['langs'][:4]:
                print('         %s: %s' % (lang, val[:60]))
            print('         代码：%s' % it['src'])
        print('\n  修法：删组件画的符号（用译文自带的那个），或把字典里的符号从译文剥掉 —— 二者只留一处。')
        print('  双符号：%d 处' % len(all_hits))      # ★ 机读行，供 shell 侧 grep（同 check_layout_guard 的风格）
        return 1
    if verbose and all_sanitized:
        print('\n  运行时已剥符号 %d 处（不算问题）：' % len(all_sanitized))
        for it in all_sanitized:
            print('     · %s:%d %s ← 「%s」（标签经 stripArrow/替换处理）'
                  % (it['file'], it['line'], ''.join(it['symbols']), it['key']))
    print('\n  ✅ 无双符号（组件画的符号与译文里的符号没有重叠）')
    print('  双符号：0 处')                        # ★ 机读行
    print('     白名单放行 %d 处 ｜ 运行时已剥符号 %d 处（详见 --verbose）'
          % (len(all_allowed), len(all_sanitized)))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
