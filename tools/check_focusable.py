#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""可点组件焦点检查器 —— 「有 onClick 就必须能被遥控器选中」

★ 为什么要它（2026-11-07 交互死角审计）：
  本项目要跑 6 类设备（手机 / 平板 / PC / 电视 / 手表 / 圆屏），其中**电视与 PC 靠方向键**。
  但 ArkUI 里只有 `Button/Toggle/Checkbox…` 这些**交互组件**默认可聚焦；
  `Text` / `Row` / `Column` / `Stack` 上挂 `.onClick` 是合法写法，**默认却不可聚焦**
  ⇒ 触屏/鼠标能点，遥控器/键盘**选不中** ⇒ 电视上那些入口等于不存在
  （实测：联机页的「重扫」「连接」、设置页 12 个控件全是这种）。

★ 判据：`components/` + `pages/` 里凡是宿主是**非交互组件**的 `.onClick`，
  必须能在同一条属性链上找到 `.focusable(`。有 → 通过；没有 → 报。
  （`.focusable(Tv.on())` 只在电视/PC/大屏为真，但**声明存在**就算合规 ——
    这里查的是"有没有做这个声明"，不是"当前设备是否要聚焦"。）

★ 白名单（只放行两类，都写清理由）：
  ① **透明遮罩**：`backgroundColor('#00000000')` 之类，点空白关菜单/关弹层。
     它本来就不该被聚焦（聚焦到一个看不见的东西反而是 bug）。
  ② **纯 dismiss**：onClick 体只有 `this.x = '' / false`（没有 Haptics、没有别的动作），
     且宿主是 `Row/Column/Stack` —— 同样是"点外面收起"，无可见动作可聚焦。

用法：
  python3 tools/check_focusable.py            # 全仓扫，有命中退出码 1
  python3 tools/check_focusable.py --verbose  # 同时打印白名单放行明细
  python3 tools/check_focusable.py --self-test  # 先验尺子（反证用例）
退出码：0 = 无命中 ｜ 1 = 有命中 ｜ 2 = 解析失败/自检失败
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')
SCAN_DIRS = ['components', 'pages']

# ArkUI 里**默认可聚焦**的交互组件：它们不需要手写 .focusable
INTERACTIVE = {
    'Button', 'Toggle', 'Checkbox', 'Radio', 'Slider', 'TextInput', 'TextArea',
    'Search', 'Select', 'Rating', 'MenuItem', 'ListItem', 'GridItem',
    'TabContent', 'Span', 'SymbolGlyph', 'Counter', 'Marquee', 'Progress',
}
# 允许作为"容器型可点"的组件（报出来时要带 focusable 建议，但仍然算命中）
CONTAINERS = {'Row', 'Column', 'Stack', 'Flex', 'RelativeContainer', 'Scroll', 'List', 'Grid'}

# 纯 dismiss：`() => { this.x = '' }` / `() => { this.x = false; }` / 带 return 的等价写法
DISMISS_RE = re.compile(
    r"^\(\)\s*=>\s*\{?\s*this\.[A-Za-z_]\w*\s*=\s*(?:''|\"\"|false)\s*;?\s*\}?$")


def read(p):
    return io.open(p, encoding='utf-8').read()


def struct_view(src):
    """注释与字符串内容 -> 等长空格（位置不变）。

    ★ 必须做：本项目注释极密，`onClick` 前面常隔着一行注释；
      直接对原文回溯会把 25/62 个 onClick 的宿主认错（实测）。
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
        elif c in "'\"`":
            q = c
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == q:
                    break
                j += 1
            for k in range(i + 1, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j + 1
        else:
            i += 1
    return ''.join(out)


def _rparen(S, i):
    d = 0
    k = i
    while k >= 0:
        if S[k] == ')':
            d += 1
        elif S[k] == '(':
            d -= 1
            if d == 0:
                return k
        k -= 1
    return -1


def _rbrace(S, i):
    d = 0
    k = i
    while k >= 0:
        if S[k] == '}':
            d += 1
        elif S[k] == '{':
            d -= 1
            if d == 0:
                return k
        k -= 1
    return -1


def _skip_ws(S, k):
    while k >= 0 and S[k] in ' \t\r\n':
        k -= 1
    return k


def _ident_before(S, k):
    e = k + 1
    while k >= 0 and (S[k].isalnum() or S[k] == '_'):
        k -= 1
    return S[k + 1:e], k


def owner_of(S, click_dot):
    """从 `.onClick` 的句点往回找宿主组件名，返回 (name, expr_start, expr_end)。

    要处理两种写法：
      · `Text(...).fontSize(...).onClick(...)`      → 属性链回溯
      · `Row() { … }.width(...).onClick(...)`       → 先配平花括号，再回溯到 `Row(…)`
    """
    k = click_dot - 1
    for _ in range(64):
        k = _skip_ws(S, k)
        if k < 0:
            return None, None, None
        if S[k] == ')':
            op = _rparen(S, k)
            if op < 0:
                return None, None, None
            name, before = _ident_before(S, _skip_ws(S, op - 1))
            if before >= 0 and S[before] == '.':
                k = before - 1          # 跳过 '.'，继续往前（属性链）
                continue
            return name, before + 1, k
        if S[k] == '}':
            ob = _rbrace(S, k)
            if ob < 0:
                return None, None, None
            j = _skip_ws(S, ob - 1)
            if j >= 0 and S[j] == ')':
                op = _rparen(S, j)
                name, before = _ident_before(S, _skip_ws(S, op - 1))
                return name, before + 1, k
            return None, None, None
        return None, None, None
    return None, None, None


def chain_of(S, expr_end, click_dot):
    return S[expr_end:click_dot]


def is_global_mask(S, expr_start, expr_end, chain, body, host=None, rel=''):
    """透明遮罩 / 纯 dismiss ⇒ 放行"""
    if re.search(r"backgroundColor\s*\(\s*'#0{0,2}[0-9a-fA-F]{0,6}00'\s*\)", chain):
        return '透明遮罩（点空白关闭）'
    if re.search(r"backgroundColor\s*\(\s*Color\.Transparent\s*\)", chain):
        return '透明遮罩（Transparent）'
    if DISMISS_RE.match(body.strip()):
        return '纯 dismiss（只重置一个状态）'
    # ③ 整屏可点：`Stack/Column/Row` 且链上是 100%×100%（点屏幕任意处触发，如开屏加速）
    #    —— 给它加焦点环会框住整个屏幕，属于"不该聚焦"的一类。
    #   ★ 只认 **pages/ 里的整屏 tap 区**，且**不得带 onFocus/onBlur**：
    #     带焦点回调说明它本该有焦点概念（如 GameCard），那就不是"整屏随便点"，
    #     而是"漏了 focusable"—— 这条收紧是自测抓出来的：GameCard 因为
    #     `.width('100%').height('100%')` 一度被误放行，而它正是主列表卡片。
    has_focus_cb = ('onFocus' in chain) or ('onBlur' in chain)
    if (host in CONTAINERS and rel.startswith('entry/src/main/ets/pages/')
            and not has_focus_cb
            and re.search(r"\.width\(\s*'100%'\s*\)", chain)
            and re.search(r"\.height\(\s*'100%'\s*\)", chain)):
        return '整屏可点（pages/ 的 100%×100% 容器，如开屏点击加速）'
    return None


def scan_file(path):
    rel = os.path.relpath(path, ROOT)
    src = read(path)
    S = struct_view(src)
    hits, allowed = [], []
    for m in re.finditer(r'\.onClick\s*\(', S):
        ln = S.count('\n', 0, m.start()) + 1
        name, st, en = owner_of(S, m.start())
        if name is None or name in INTERACTIVE:
            continue
        op = S.find('(', m.start())
        d = 0
        k = op
        while k < len(S):
            if S[k] == '(':
                d += 1
            elif S[k] == ')':
                d -= 1
                if d == 0:
                    break
            k += 1
        body = S[op + 1:k]
        chain = chain_of(S, en, m.start())
        # ★ 结构视图把字符串内容抹成空格 ⇒ `'100%'`/`'#00000000'` 这类**内容**判断
        #   必须回原文取同区间（struct_view 是等长替换，偏移可直接复用）。
        chain_raw = src[en:m.start()] if (en is not None) else ''
        why = is_global_mask(S, st, en, chain_raw, body, name, rel)
        item = {'file': rel, 'line': ln, 'comp': name}
        if why:
            item['why'] = why
            allowed.append(item)
            continue
        if 'focusable' in chain:
            continue
        hits.append(item)
    return hits, allowed


def self_test():
    """反证尺子：三种写法必须认对宿主，遮罩必须放行、真按钮必须命中"""
    cases = [
        ("Text('a').fontSize(1).onClick(() => { Haptics.tap(); })\n", 'Text', True),
        ("Row() { Text('x') }.width(1).onClick(() => { Haptics.tap(); })\n", 'Row', True),
        ("Button('ok').onClick(() => { x(); })\n", 'Button', False),
        ("Row() { }\n  .backgroundColor('#00000000')\n  .onClick(() => { this.m = ''; })\n", 'Row', False),
        ("Text('a')\n  // 注释挡在中间\n  .focusable(Tv.on())\n  .onClick(() => { y(); })\n", 'Text', False),
    ]
    bad = []
    for src, want_comp, want_hit in cases:
        S = struct_view(src)
        m = list(re.finditer(r'\.onClick\s*\(', S))
        if not m:
            bad.append('找不到 onClick: %r' % src[:30])
            continue
        name, st, en = owner_of(S, m[0].start())
        ok_name = (name == want_comp)
        hits, allowed = scan_file.__wrapped__ if False else (None, None)
        # 直接调用单文件扫描逻辑（写成临时串不方便），改为复算：
        op = S.find('(', m[0].start())
        d = 0
        k = op
        while k < len(S):
            if S[k] == '(':
                d += 1
            elif S[k] == ')':
                d -= 1
                if d == 0:
                    break
            k += 1
        body = S[op + 1:k]
        chain = chain_of(S, en, m[0].start())
        chain_raw = src[en:m[0].start()] if en is not None else ''
        why = is_global_mask(S, st, en, chain_raw, body, name, 'entry/src/main/ets/components/x.ets')
        got_hit = (name not in INTERACTIVE) and (why is None) and ('focusable' not in chain)
        if not ok_name or got_hit != want_hit:
            bad.append('want %s/%s got %s/%s :: %r' % (want_comp, want_hit, name, got_hit, src[:40]))
    for b in bad:
        print('     ⚠️ ' + b)
    return len(bad) == 0, len(cases)


def main():
    verbose = '--verbose' in sys.argv
    if '--self-test' in sys.argv:
        print('  ═══ 自检（反证尺子）═══')
        ok, n = self_test()
        print('  %s（%d 条反证）' % ('✅ 通过' if ok else '❌ 失败', n))
        return 0 if ok else 2

    files = []
    for d in SCAN_DIRS:
        p = os.path.join(ETS, d)
        if not os.path.isdir(p):
            print('  🔴 目录不存在：%s' % p)
            return 2
        files += sorted(f for f in glob_ets(p))
    if not files:
        print('  🔴 没找到 .ets 文件')
        return 2

    all_hits, all_allowed = [], []
    for p in files:
        h, a = scan_file(p)
        all_hits += h
        all_allowed += a

    print('  ═══ 可点组件焦点检查 ═══')
    print('  扫描 .ets：%d 个（components + pages）' % len(files))
    if all_hits:
        print('  ❌ %d 处可点但没有 .focusable（电视/键盘选不中）：' % len(all_hits))
        for h in all_hits:
            print('     %s:%d  <%s>' % (h['file'], h['line'], h['comp']))
        print('\n  修法：在 .onClick 前补三件套（照 Tools 里 GamesTab:1674-1688 的写法）')
        print('        .focusable(Tv.on())')
        print("        .onFocus(() => { this.tvFocus = '<id>'; })")
        print("        .onBlur(() => { if (this.tvFocus === '<id>') { this.tvFocus = ''; } })")
        print("        .outline(Tv.focusOutline(this.tvFocus === '<id>'))")
        print('        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { 原 onClick 动作 }); })')
    else:
        print('  ✅ 所有可点组件都声明了 focusable')
    if verbose and all_allowed:
        print('\n  白名单放行 %d 处：' % len(all_allowed))
        for a in all_allowed:
            print('     %s:%d <%s> — %s' % (a['file'], a['line'], a['comp'], a['why']))
    elif all_allowed:
        print('     白名单放行 %d 处（--verbose 看明细）' % len(all_allowed))
    # ★ 机读收尾行（供 工具/check_assertions.sh 当闸门用，照 check_dup_symbol 的写法）
    print('  焦点缺口：%d 处' % len(all_hits))
    return 1 if all_hits else 0


def glob_ets(d):
    for name in os.listdir(d):
        if name.endswith('.ets'):
            yield os.path.join(d, name)


if __name__ == '__main__':
    sys.exit(main())
