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
  ⑧ 结构    受管文件的括号/花括号/引号是否配平（硬失败）

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


def parse_extra(s):
    """
    把 EXTRA 字典整块解析出来（**不是正则**）

    ⚠️ 2026-10-13 修过一把"坏尺子"：原来用 `^\\s*"k":\\s*\\{([^}]*)\\}` 逐行匹配，
       而译文里带 `{n}` 的条目（如 `"{n} 局": {"ja": "{n}局"}`）会在 `{n}` 的 `}` 处断掉
       ⇒ 这类条目**被静默跳过**，旧脚本报 248 条、真实是 281 条，10 条从没被校验过。
    """
    i = s.index('const EXTRA:')
    j = s.index('{', i)
    depth = 0
    k = j
    while k < len(s):
        if s[k] == '{':
            depth += 1
        elif s[k] == '}':
            depth -= 1
            if depth == 0:
                break
        k += 1
    block = s[j:k + 1]
    data = json.loads(re.sub(r',(\s*})$', r'\1', block))
    # 重复键（JSON 解析会吞掉重复，得单独数）
    raw = re.findall(r'^\s*("(?:[^"\\]|\\.)*")\s*:', block, re.M)
    keys = [json.loads(x) for x in raw]
    dup = sorted({x for x in keys if keys.count(x) > 1})
    return data, dup, len(keys)


def check_dict():
    s = read(I18N)
    data, dup, nkeys = parse_extra(s)
    bad = []
    for key, got in data.items():
        miss = [l for l in LANGS if l not in got]
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
    print('  ═══ ① 字典 ═══')
    print('  条数          %d 条中文原文 × %d 语言 = %d 条译文' % (nkeys, len(LANGS), nkeys * len(LANGS)))
    if bad:
        fatal.append('字典有缺项 %d 条' % len(bad))
        print('  完整性        ⚠️ %d 条有缺' % len(bad))
        for k, m, e in bad[:10]:
            print('                  %-30s 缺 %s 空 %s' % (k[:30], m, e))
    else:
        print('  完整性        ✅ %d/%d 条 %d 语言齐全（含 {n} 模板条）' % (nkeys, nkeys, len(LANGS)))
    if dup:
        fatal.append('字典重复键 %s' % dup)
        print('  重复键        ⚠️ %s' % dup)
    else:
        print('  重复键        ✅ 无')
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
    FUNCS = [r'this\.t', r'this\.tn', r'\bL2?', r'\bTN', r'\bTZ', r'this\.sec', r'this\.kv',
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
    """⑥ @Builder 参数里出现 this.t(...)：语言变了 Builder 不重建"""
    print('\n  ═══ ⑥ @Builder 记忆化陷阱 ═══')
    hits = []
    for p in sorted(glob.glob(os.path.join(ETS, '**/*.ets'), recursive=True)):
        txt = read(p)
        # 调用点 this.xxx( ... )：按括号配平取实参文本，再看里面有没有先算好的文案
        for m in re.finditer(r"this\.([A-Za-z]+)\(", txt):
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
            if re.search(r"this\.t\(|this\.tn\(", args):
                ln = txt[:m.start()].count('\n') + 1
                hits.append((os.path.relpath(p, ROOT), ln, m.group(1)))
    if hits:
        warn.append('Builder 传算好的值 %d 处' % len(hits))
        print('  ⚠️ %d 处把算好的文案传进 @Builder（换语言可能不重建）：' % len(hits))
        for f, ln, name in hits[:20]:
            print('     %s:%d  this.%s(...)' % (f, ln, name))
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
    i = src.index('{', src.index('const DICT:'))
    d = 0
    j = i
    while j < len(src):
        if src[j] == '{':
            d += 1
        elif src[j] == '}':
            d -= 1
            if d == 0:
                break
        j += 1
    try:
        data = json.loads(re.sub(r',(\s*})$', r'\1', src[i:j + 1]))
    except Exception as e:
        fatal.append('GameI18n 字典解析失败: %s' % e)
        print('  ⚠️ 解析失败: %s' % e)
        return
    LANGS10 = ['en', 'ja', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'it', 'ar']
    miss = [k for k, row in data.items() if [l for l in LANGS10 if l not in row]]
    print('  条数            %d 条 × %d 语言' % (len(data), len(LANGS10)))
    if miss:
        fatal.append('GameI18n 缺列 %d 条' % len(miss))
        print('  缺列            ⚠️ %d 条：%s' % (len(miss), miss[:5]))
    else:
        print('  十语言列齐全    ✅ %d/%d' % (len(data), len(data)))
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
    entries = check_dict()
    check_hant_path()
    naked = check_naked_chinese()
    check_builder_trap()
    check_accent_id_as_color()
    check_binary_t()
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
