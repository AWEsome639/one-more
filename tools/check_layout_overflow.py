#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""布局溢出静态检查器（四类）

★ 背景（2026-11-08）：ai-fixer-b 发现 **165 款横屏棋盘溢出** ——
  根因是 `width('100%') + aspectRatio(1)` 假设「宽 ≤ 高」，横屏（853×533）下
  高度 = 宽度 ⇒ 必然超。lead 已用 `constraintSize({ maxHeight: Bp.height - 190 })` 止血，
  但这类写法会再长出来，所以做成静态闸门。

★ 三类判据
  ① **宽驱动的棋盘无上限**：`.width('100%').aspectRatio(X)`，且**本元素的修饰链**上没有
     `constraintSize` / `maxHeight` / `maxWidth`。
     · `.layoutWeight(1).aspectRatio(X)` 的**格子**形态不算：那是 tile/cell/cellView 这类
       `@Builder` 的惯用法，高度由父级棋盘行分配、父级已限高（实测 39 处全属此类，计入即假阳）。
     · 假阳性过滤（与已有 `工具/check_layout_guard.py` 一致）：注释里的伪代码、Grid/GridItem 里的格子、
       **Row/Flex 里的格子**（高度由行分配，不是「宽驱动整块」）。
     · 白名单：`tinyWatch()` 分支（小屏单独处理）。
  ② **固定高元素堆叠**：同一个 build 里 `Cell.of(40..59)`（固定高按钮/键盘）≥4 个，
     且**竖排估算高度** > `参考高 - 190`。
     · 竖排估算：按「最近的 Row」归组，同一行取最大高度（横向一排不算累加），
       再把各行高度加起来 —— 不这样归组会把横向按钮行误判成竖排。
  ③ **`position({ y: 字面量 })` 超出屏高**：y 是字面量且 > 500 ⇒ 报（有 constraintSize 或 tinyWatch 分支的放过）。
  ④ **「提示按钮」在正方形棋盘之后 + 文件无限高**（2026-11-08，判据 1819 同族）：
     `Button(TG('提示'))` 的行号 > 某处 `aspectRatio(1)` 的行号（棋盘在按钮前、按宽撑满），
     且**整个文件**没有限高/限宽（`constraintSize` / `maxHeight` / `Bp.height±` / `boardPx` /
     `width(Math.min(...))`）、也没有 `Scroll` ⇒ 报「按钮可能被挤出」候选。
     · 这是**候选**（很多 `aspectRatio(1)` 是小格子/图标，不是整块棋盘）——真机复核后收敛；
     · tinyWatch 分支放过。

★ 输出：机读行 `布局溢出：N 处`（**闸门 = ①+③**）；`布局提示：M 处`（**②④ 只提示，不进闸门** ——
  判据 1819 同族：静态估算与真机差异大，perf-hunter 真机 6/6 证明 ④ 候选全是误报）；
  退出码 0 = 闸门无命中 ｜ 1 = 闸门有命中 ｜ 2 = 解析/自检失败。
用法：
  python3 tools/check_layout_overflow.py [--verbose] [--self-test] [--ref-height 533]
"""
import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')

SCAN_DIRS = ['games', 'components', 'pages']
# ② 的参考高：横屏手机（lead 修 165 款时用的 853×533）⇒ 可用高 = 533 - 190 = 343
REF_HEIGHT = 533
CHROME_H = 190

KEYWORDS = {'if', 'for', 'while', 'switch', 'catch', 'return', 'else', 'do', 'function', 'new',
            'typeof', 'delete', 'void', 'in', 'of', 'try', 'finally'}
FUNC_RE = re.compile(r'(?:^|\n)[ \t]*(?:(?:private|public|protected|async|static|override)\s+)*'
                     r'([A-Za-z_$][\w$]*)\s*\([^;{}]*\)\s*(?::\s*[^{;]+)?\s*\{', re.M)
CONTAINER = re.compile(r'\b(Column|Row|Flex|Grid|GridItem|List|ListItem|Scroll|Stack|'
                       r'RelativeContainer|Swiper|Tabs|TabContent|WaterFlow|Navigation)\s*\(')
ASPECT = re.compile(r'\.aspectRatio\(\s*([^)]*)\)')
CELLOF = re.compile(r'Cell\.of\(\s*(\d+)\s*\)')
POSITION = re.compile(r'\.position\(\s*\{')
CAP_RE = re.compile(r'constraintSize|maxHeight|maxWidth')
# ④ 判据 1819：自绘「提示」按钮（HintBar 的按钮不是这个写法，不在此类）
HINT_BTN_RE = re.compile(r"Button\(\s*TG\(\s*['\"]提示['\"]\s*\)\s*\)")
# ④（判据 1819 同族）：祖先链上有这些容器 ⇒ 高度会被压缩/滚动吸收，**不可能是「按钮被挤出」**
#   （perf-hunter 真机 6/6：皇冠/数织/数墙/灭灯/数字华容道/找因数 —— 按钮实际 y2=657）
PROTECTIVE = ('Scroll', 'List', 'ListItem', 'Grid', 'GridItem', 'WaterFlow', 'Tabs', 'TabContent')


def mask(src, strings_too=False):
    """注释抹空；strings_too=True 时字符串也抹空（结构分析用）。两者与原文字符长度一致。

    ★ 2026-11-08 自检抓到的坑：初版把「字符串保留」也走成「抹空」分支 ⇒
      `.width('100%')` 变成 `.width('    ')`，① 永远不命中。字符串必须**保留原文**，
      只是要识别出来、避免把字符串里的 `//`、`{` 当注释/结构。
    """
    out = list(src)
    i, n = 0, len(src)
    st = None          # 'l' 行注释 ｜ 'b' 块注释 ｜ 'q' 字符串
    quote = ''
    while i < n:
        c = src[i]
        nx = src[i + 1] if i + 1 < n else ''
        if st is None:
            if c == '/' and nx == '/':
                out[i] = ' '; out[i + 1] = ' '; st = 'l'; i += 2; continue
            if c == '/' and nx == '*':
                out[i] = ' '; out[i + 1] = ' '; st = 'b'; i += 2; continue
            if c in '"\'`':
                st = 'q'; quote = c
                if strings_too:
                    out[i] = ' '
                i += 1; continue
            i += 1; continue
        if st == 'l':
            if c == '\n':
                st = None
            else:
                out[i] = ' '
            i += 1; continue
        if st == 'b':
            if c == '*' and nx == '/':
                out[i] = ' '; out[i + 1] = ' '; st = None; i += 2; continue
            if c != '\n':
                out[i] = ' '
            i += 1; continue
        # st == 'q'：字符串
        if c == '\\':
            if strings_too:
                out[i] = ' '
                if i + 1 < n and src[i + 1] != '\n':
                    out[i + 1] = ' '
            i += 2; continue
        if c == quote:
            if strings_too:
                out[i] = ' '
            st = None; i += 1; continue
        if strings_too and c != '\n':
            out[i] = ' '
        i += 1
    return ''.join(out)


def match_brace(ms, open_idx):
    depth = 0
    for i in range(open_idx, len(ms)):
        c = ms[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
    return -1


def containers(ms):
    """元素容器区间：[(start, end, kind)]（用抹掉字符串的结构文本算括号）。"""
    out = []
    for m in CONTAINER.finditer(ms):
        kind = m.group(1)
        # 找元素体的 `{`：从 `(` 起配对括号后再找 `{`（跳过 { space: ... } 这类参数对象）
        op = m.end() - 1
        depth = 0
        close = -1
        for i in range(op, len(ms)):
            if ms[i] == '(':
                depth += 1
            elif ms[i] == ')':
                depth -= 1
                if depth == 0:
                    close = i
                    break
        if close < 0:
            continue
        b = ms.find('{', close)
        if b < 0 or b - close > 200:
            continue
        e = match_brace(ms, b)
        if e < 0:
            continue
        out.append((b, e, kind))
    return out


def function_spans(ms):
    out = []
    for m in FUNC_RE.finditer(ms):
        name = m.group(1)
        if name in KEYWORDS:
            continue
        # ArkUI 组件（Column/Row/Stack…）也是 `名字(...) {`，但它们不是函数：
        # 不排除会把每个容器当函数、同一段 Cell.of 被重复计数（自检第 2 项因此 1→3）。
        if name[:1].isupper():
            continue
        b = ms.find('{', m.start(), m.end())
        e = match_brace(ms, b)
        if e > 0:
            out.append((b, e, name))
    return out


def ancestors(spans, pos):
    return [s for s in spans if s[0] <= pos <= s[1]]


def protective_ancestor(conts, mk, pos):
    """祖先链上有 Scroll/List/... 或 layoutWeight ⇒ 高度被压缩/滚动吸收（判据 1819 同族）。

    返回 (True, 原因) 表示被保护 —— 这类节点**不会**把按钮顶出屏幕（perf-hunter 真机 6/6 证实）。
    """
    for (cb, ce, kind) in sorted(ancestors(conts, pos), key=lambda x: x[0], reverse=True):
        if kind in PROTECTIVE:
            return True, 'ancestor:%s' % kind
        if '.layoutWeight(' in mk[ce:ce + 300]:
            return True, 'ancestor:%s+layoutWeight' % kind
    return False, ''


def innermost(spans, pos):
    best = None
    for (b, e, kind) in spans:
        if b <= pos <= e:
            if best is None or b > best[0]:
                best = (b, e, kind)
    return best


def line_of(text, pos):
    return text.count('\n', 0, pos) + 1


def scan_file(path, ref_h=REF_HEIGHT):
    rel = os.path.relpath(path, ROOT)
    src = io.open(path, encoding='utf-8').read()
    mk = mask(src)                 # 注释空、字符串留（读 width('100%')）
    ms = mask(src, True)           # 字符串也空（结构）
    raw_lines = src.split('\n')
    found = {'wide': [], 'stack': [], 'pos': [], 'pushout': []}
    allowed = {'wide': [], 'stack': [], 'pos': [], 'pushout': []}
    conts = containers(ms)
    funcs = function_spans(ms)

    def chain_has_cap(pos):
        """上限只看**本元素的修饰链**（同一行 + 以 `.` 开头的续行 + 前一以 `.` 开头的续行）。

        ★ 不能往后看 N 行：fixture 里下一个元素的 `.constraintSize` 会被误算成本元素的上限
          （自检第 1 项因此报 0，实测踩过）。
        """
        ln = line_of(mk, pos)
        lines = mk.split('\n')

        def chainish(t):
            # 修饰链允许被**注释/空行**隔开（真实写法：.aspectRatio 之后夹 2~3 行注释再 .constraintSize）
            st = t.strip()
            return st == '' or st.startswith('.')

        i = ln - 1
        win = [lines[i]]
        k = i + 1
        while k < len(lines) and chainish(lines[k]):
            if lines[k].strip():
                win.append(lines[k])
            k += 1
        k = i - 1
        while k >= 0 and chainish(lines[k]):
            if lines[k].strip():
                win.append(lines[k])
            k -= 1
        return bool(CAP_RE.search('\n'.join(win)))

    def near_tiny(pos, back=3, fwd=15):
        ln = line_of(ms, pos)
        seg = '\n'.join(raw_lines[max(0, ln - 1 - back): ln + fwd])
        return 'tinyWatch' in seg

    # ── ① 宽驱动 aspectRatio 无上限 ──
    for m in ASPECT.finditer(mk):
        pos = m.start()
        ln = line_of(mk, pos)
        # 元素链：从本行往上 2 行的最后一个 { } ; 之后
        lo = max(0, ln - 3)
        chain = '\n'.join(mk.split('\n')[lo:ln])
        cut = max(chain.rfind('{'), chain.rfind('}'), chain.rfind(';'))
        chain = chain[cut + 1:] if cut >= 0 else chain
        # ★ 2026-11-08 收敛：只认 `width('100%').aspectRatio`（「宽驱动整块」= 165 款溢出的形态）。
        #   `.layoutWeight(1).aspectRatio(1)` 几乎全是 `@Builder` 里的**格子**（tile/cell/cellView…），
        #   高度由父级棋盘行分配、父级已限高；把它算进来会得 39 处假阳（实测核过）。
        #   格子类的竖排溢出由 ② 的「按 Row 归组累加高度」负责。
        if "width('100%')" not in chain:
            continue
        # ★ 2026-11-08 真机（GPong）：链上有 `.layoutWeight(` ⇒ **主轴权重接管高度**，
        #   aspectRatio 不生效（实测 field：宽 2440、按 0.7 应为 3486 高，实际被 clamp 到 730）。
        #   这种形态不是「宽驱动 → 高度被锁死」，不算 ① 类（GPong 是最后一个 ① 假阳性）。
        if '.layoutWeight(' in chain:
            continue
        host = innermost(conts, pos)
        kind = host[2] if host else ''
        # 格子高度由行分配 ⇒ 不是「宽驱动整块」
        if kind in ('Grid', 'GridItem', 'Row', 'Flex'):
            continue
        if chain_has_cap(pos) or CAP_RE.search(chain):
            continue
        item = {'file': rel, 'line': ln, 'code': raw_lines[ln - 1].strip()[:110],
                'kind': 'chain:' + ('layoutWeight' if '.layoutWeight(' in chain else "width100")}
        (allowed['wide'].append((item, 'tinyWatch 分支')) if near_tiny(pos) else found['wide'].append(item))

    # ── ② 固定高堆叠（按最近 Row 归组取行高，再累加） ──
    for (fb, fe, fname) in funcs:
        body = ms[fb:fe]
        cells = []
        for m in CELLOF.finditer(body):
            v = int(m.group(1))
            if not (40 <= v <= 59):
                continue
            pos = fb + m.start()
            # 只看作为高度用的 Cell.of（同一行/前一行有 .height(）
            ln = line_of(mk, pos)
            line_txt = mk.split('\n')[ln - 1]
            if '.height(' not in line_txt and '.height(' not in mk.split('\n')[max(0, ln - 2)]:
                continue
            row = innermost(conts, pos)
            row_id = row[0] if row and row[2] in ('Row', 'Flex') else ('_col', ln)
            cells.append((v, row_id, pos))
        if len(cells) < 4:
            continue
        # 行内取最大，行间累加（同一 Row 只算一次）
        groups = {}
        for v, row_id, pos in cells:
            groups[row_id] = max(groups.get(row_id, 0), v)
        total = sum(groups.values())
        if total <= ref_h - CHROME_H:
            continue
        sample = cells[0]
        ln = line_of(mk, sample[2])
        item = {'file': rel, 'line': ln, 'code': '%s(): %d 个固定高，竖排估算 %d > %d'
                % (fname, len(cells), total, ref_h - CHROME_H),
                'kind': 'stack-%d' % total}
        (allowed['stack'].append((item, 'tinyWatch 分支')) if near_tiny(sample[2]) else found['stack'].append(item))

    # ── ③ position y 字面量超屏 ──
    for m in POSITION.finditer(ms):
        op = m.end() - 1
        depth = 0
        close = -1
        for i in range(op, len(ms)):
            if ms[i] == '{':
                depth += 1
            elif ms[i] == '}':
                depth -= 1
                if depth == 0:
                    close = i
                    break
        if close < 0:
            continue
        inner = ms[op + 1:close]
        ym = re.search(r'\by\s*:\s*(-?\d+(?:\.\d+)?)\s*(?:[,}]|$)', inner)
        if not ym:
            continue
        val = float(ym.group(1))
        if val <= 500:
            continue
        pos = m.start()
        ln = line_of(ms, pos)
        if chain_has_cap(pos) or near_tiny(pos):
            allowed['pos'].append(({'file': rel, 'line': ln, 'sym': 'y=%s' % ym.group(1),
                                    'code': raw_lines[ln - 1].strip()[:110]}, 'cap/tinyWatch'))
            continue
        found['pos'].append({'file': rel, 'line': ln, 'sym': 'y=%s' % ym.group(1),
                             'code': raw_lines[ln - 1].strip()[:110], 'kind': 'y>500'})

    # ── ④ 提示按钮在正方形棋盘之后 + 文件无限高（判据 1819 同族） ──
    #   只在「棋盘按宽撑满 + 按钮在棋盘之后」时才会把按钮顶出去；
    #   文件级上限（constraintSize/Bp.height±/boardPx/width(Math.min)）或 Scroll 都算已处理。
    file_cap = (bool(CAP_RE.search(mk)) or bool(re.search(r'Bp\.height\s*[-*]', mk))
                or ('boardPx' in mk) or bool(re.search(r'width\(Math\.min\(', mk)))
    has_scroll = ('Scroll()' in mk) or ('Scroll{' in mk)
    if not file_cap and not has_scroll:
        # ★ 只认「宽驱动整块棋盘」：修饰链上同时有 `width('100%')`（与 ① 同口径）；
        #   格子级的 `layoutWeight(1)+aspectRatio(1)` **不算** —— perf-hunter 真机 6/6 的
        #   皇冠/数织/数墙/灭灯/数字华容道/找因数，全是这种「小格子」被误当成棋盘。
        board_asp = []
        for am in ASPECT.finditer(mk):
            ap = am.start()
            aln = line_of(mk, ap)
            lo = max(0, aln - 3)
            chain = '\n'.join(mk.split('\n')[lo:aln])
            cut = max(chain.rfind('{'), chain.rfind('}'), chain.rfind(';'))
            chain = chain[cut + 1:] if cut >= 0 else chain
            if "width('100%')" not in chain:
                continue
            host = innermost(conts, ap)
            if host and host[2] in ('Grid', 'GridItem', 'Row', 'Flex'):
                continue
            board_asp.append((aln, ap))
        asp_lines = [aln for aln, _ in board_asp]
        for bm in HINT_BTN_RE.finditer(mk):
            bl = line_of(mk, bm.start())
            before = [al for al in asp_lines if al < bl]
            if not before:
                continue
            item = {'file': rel, 'line': bl,
                    'code': raw_lines[bl - 1].strip()[:110],
                    'kind': 'hint-after-square-board'}
            # ★ perf-hunter 真机 6/6：按钮/棋盘在 Scroll/List/layoutWeight 的祖先里 ⇒
            #   高度会被压缩或滚动吸收，**不是「按钮被挤出」** ⇒ 放过（否则系统性假阳性）。
            prot_btn, why_btn = protective_ancestor(conts, mk, bm.start())
            aim = None
            last_al = max(before)
            for aln, ap in board_asp:
                if aln == last_al:
                    aim = ap
                    break
            prot_board, why_board = (False, '')
            if aim is not None:
                prot_board, why_board = protective_ancestor(conts, mk, aim)
            if prot_btn or prot_board:
                allowed['pushout'].append((item, why_btn or why_board))
                continue
            if near_tiny(bm.start()):
                allowed['pushout'].append((item, 'tinyWatch 分支'))
            else:
                found['pushout'].append(item)

    return found, allowed


# ──────────────────────────── 自检 ────────────────────────────
SELF_SRC = '''
@Component
struct Demo {
  build() {
    Column() {
      // ① 违规：宽驱动 + aspectRatio，无上限
      Stack() { Text('x') }.width('100%').aspectRatio(1)
      // ① 安全：有 constraintSize
      Stack() { Text('x') }.width('100%').aspectRatio(1).constraintSize({ maxHeight: 300 })
      // ① 安全：Row 里的格子（高度由行分配）
      Row() { Text('a').layoutWeight(1).aspectRatio(1) }
      // ① 安全：width100 + layoutWeight（主轴权重接管高度，aspectRatio 不生效；真机 GPong 实测）
      Stack() { Text('b') }.width('100%').layoutWeight(1).aspectRatio(0.7)
      // ② 违规：竖排 6 个 56 高 = 336 ≤ 343？再叠一行 ⇒ 392 > 343
      Column() {
        Row() { Text('1').height(Cell.of(56)) }
        Row() { Text('2').height(Cell.of(56)) }
        Row() { Text('3').height(Cell.of(56)) }
        Row() { Text('4').height(Cell.of(56)) }
        Row() { Text('5').height(Cell.of(56)) }
        Row() { Text('6').height(Cell.of(56)) }
        Row() { Text('7').height(Cell.of(56)) }
      }
      // ③ 违规：position y 字面量 620
      Text('bad').position({ x: 10, y: 620 })
      // ③ 安全：y 小
      Text('ok').position({ x: 10, y: 20 })
    }
  }
}
'''


SELF4_BAD = '''
@Component
struct Demo4Bad {
  build() {
    Column() {
      Stack() { Text('board') }.width('100%').aspectRatio(1)
      Button(TG('提示')) { Text('hint') }
    }
  }
}
'''
SELF4_CELL = '''
@Component
struct Demo4Cell {
  build() {
    Column() {
      Row() {
        Text('a').layoutWeight(1).aspectRatio(1)
      }
      Button(TG('提示')) { Text('hint') }
    }
  }
}
'''
SELF4_OK = '''
@Component
struct Demo4Ok {
  build() {
    Column() {
      Stack() { Text('board') }.width('100%').aspectRatio(1)
        .constraintSize({ maxHeight: 300 })
      Button(TG('提示')) { Text('hint') }
    }
  }
}
'''


def self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix='overflow_')
    try:
        p = os.path.join(d, 'demo.ets')
        io.open(p, 'w', encoding='utf-8').write(SELF_SRC)
        found, allowed = scan_file(p)
        p4b = os.path.join(d, 'demo4_bad.ets')
        p4o = os.path.join(d, 'demo4_ok.ets')
        io.open(p4b, 'w', encoding='utf-8').write(SELF4_BAD)
        io.open(p4o, 'w', encoding='utf-8').write(SELF4_OK)
        p4c = os.path.join(d, 'demo4_cell.ets')
        io.open(p4c, 'w', encoding='utf-8').write(SELF4_CELL)
        f4b, _ = scan_file(p4b)
        f4o, _ = scan_file(p4o)
        f4c, _ = scan_file(p4c)
        ok = [
            ('① 宽驱动无上限：应命中 1 处', len(found['wide']) == 1, '%d 处' % len(found['wide'])),
            ('② 固定高堆叠：应命中 1 处', len(found['stack']) == 1, '%d 处' % len(found['stack'])),
            ('③ position y>500：应命中 1 处', len(found['pos']) == 1, '%d 处' % len(found['pos'])),
            ('④ 提示在棋盘后+无限高：应命中 1 处', len(f4b['pushout']) == 1, '%d 处' % len(f4b['pushout'])),
            ('④ 有 constraintSize 时：应 0 处', len(f4o['pushout']) == 0, '%d 处' % len(f4o['pushout'])),
            ('④ 格子级 aspectRatio 不算棋盘：应 0 处', len(f4c['pushout']) == 0, '%d 处' % len(f4c['pushout'])),
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
    ref_h = REF_HEIGHT
    for i, a in enumerate(sys.argv):
        if a == '--ref-height' and i + 1 < len(sys.argv):
            ref_h = int(sys.argv[i + 1])
    files = []
    for d in SCAN_DIRS:
        files += sorted(glob.glob(os.path.join(ETS, d, '*.ets')))
    if not files:
        print('  🔴 没找到 .ets 文件')
        return 2

    totals = {'wide': 0, 'stack': 0, 'pos': 0, 'pushout': 0}
    found_all = {'wide': [], 'stack': [], 'pos': [], 'pushout': []}
    allowed_all = {'wide': [], 'stack': [], 'pos': [], 'pushout': []}
    for p in files:
        found, allowed = scan_file(p, ref_h)
        for k in totals:
            totals[k] += len(found[k])
            found_all[k] += found[k]
            allowed_all[k] += allowed[k]

    names = {'wide': "① 宽驱动棋盘无上限（width('100%') + aspectRatio，链上无 constraintSize）",
             'stack': '② 固定高元素堆叠（Cell.of(40..59) ≥4 且竖排估算 > %d）｜提示，不进闸门'
                      % (ref_h - CHROME_H),
             'pos': '③ position y 字面量 > 500（可能超出屏高）',
             'pushout': '④ 提示按钮在 width(100%) 的 aspectRatio 棋盘之后 + 文件无限高（提示，不进闸门）'}
    print('  ═══ 布局溢出静态检查 ═══')
    print('  扫描 .ets：%d 个（games/components/pages）｜ 参考高 %d，可用高 %d'
          '（② 仅提示：竖屏/手表请用 --ref-height 另算）'
          % (len(files), ref_h, ref_h - CHROME_H))
    for k in ('wide', 'stack', 'pos', 'pushout'):
        print('\n  %s：%d 处' % (names[k], totals[k]))
        for h in found_all[k][: (100 if verbose else 8)]:
            print('     · %s:%d  %s' % (h['file'], h['line'], h['code']))
        if totals[k] > 8 and not verbose:
            print('     …（共 %d 处，--verbose 看全部）' % totals[k])
        if verbose:
            for h, why in allowed_all[k]:
                print('     ✓ 白名单：%s:%d（%s）' % (h['file'], h['line'], why))
    # ★ 判据 1819 同族（lead 2026-11-08 决定）：②④ 是**提示**，不进闸门 ——
    #   静态估算与真机差异大（perf-hunter 真机 6/6 证明 ④ 候选全是误报）。
    gate = totals['wide'] + totals['pos']
    hint = totals['stack'] + totals['pushout']
    print('\n  布局溢出：%d 处（闸门 = ①+③）' % gate)
    print('  布局提示：%d 处（②④ 不进闸门，参考用）' % hint)
    return 0 if gate == 0 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
