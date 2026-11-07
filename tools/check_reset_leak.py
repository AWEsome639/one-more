#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「状态字段复位遗漏」检查器（第四把尺子 · 2-hop 守卫链分析）

★ 为什么要它（2026-11-08）：
  · 上一轮「内容当状态」改完后，剩下的一族是**跨局残留**：某个状态字段只在答题时写、
    `reset()` 不碰它，而界面又直接显示它 ⇒ 重开一局第一帧还挂着上一局的绿/红/旧文案。
  · 实例：`GWordLadderStep.msg` —— `reset()` 只清 picked/计数，`msg` 只在 tap/next 里写，
    `Text(this.msg)` 没有任何守卫 ⇒ 重开时先看到上一局的「❌ 生命耗尽…」。
  · 与判据 1762（结算弹窗跨游戏残留）同族。

★ 判据（两跳，都成立才报）
  **第 1 跳**：字段 X 是 `@State` 原始类型（boolean/number/string），且在 **reset 面**里从未被赋值。
     · reset 面 = `reset / restart / onRestart / aboutToAppear / newGame / clearAll / again …`
       **加上它们直接/间接调用的函数**（最多 3 层，如 `reset() → newRound()`）。
     · 排除：动画/物理量（pulse/winK/shake/…）与只被 tick/step 每帧覆盖的字段。
  **第 2 跳**：看 X 的**每一处显示点**，提取它的**守卫条件**：
     · 行内三元：`cond ? (X ? A : B) : C` 里的 `cond`
     · 外层 `if (cond) { … Text(X) … }`
     若守卫里**至少有一个字段 Y 在 reset 面被赋值** ⇒ 该显示点无害（reset 后守卫为假）。
     **只有当 X 的所有显示点都无守卫（或守卫字段都不在 reset 面）才报。**

★ 自检（`--self-test`）
  1. 正例：`reset()` 不碰 msg、tap 写 msg、`Text(this.msg)` ⇒ 必须命中
  2. 负例：`this.answered ? (this.lastOk ? …)`，answered 在 reset 清零 ⇒ 必须不报
  3. 负例：`reset()` 自己写 msg ⇒ 必须不报
  4. 负例：动画字段（pulse）⇒ 必须不报

用法：python3 tools/check_reset_leak.py [--self-test] [--verbose]
退出码：0 = 无残留 ｜ 1 = 有残留 ｜ 2 = 解析/自检失败
"""
import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')

KEYWORDS = {'if', 'for', 'while', 'switch', 'catch', 'return', 'else', 'do', 'function', 'new',
            'typeof', 'delete', 'void', 'in', 'of', 'try', 'finally'}
FUNC_RE = re.compile(r'(?:^|\n)[ \t]*(?:(?:private|public|protected|async|static|override)\s+)*'
                     r'([A-Za-z_$][\w$]*)\s*\([^;{}]*\)\s*(?::\s*[^{;]+)?\s*\{', re.M)
# reset 面的**根**函数（真正表示“重开一局”的那些）
ROOT_RESET = re.compile(
    r'^(reset|restart|onRestart|aboutToAppear|onPageShow|newGame|initGame|startGame|openGame|enterGame|'
    r'loadGame|clearAll|startLevel|beginLevel|gotoNext|nextGame|resetAll|clearResult|again|retry|fresh|replay)$', re.I)
# 事件函数：会写“上一手/上一答”的状态
EVENT_FN = re.compile(r'(answer|pick|tap|choose|submit|judge|select|press|place|fire|toggle|check|guess|mark|'
                      r'hit|miss|tryMatch|tryBind|put|arm|next|finish|end|win|lose|settle|resolve|handle|onTap)', re.I)
# 连续量函数：每帧覆盖 ⇒ 不算残留来源
CONT_FN = re.compile(r'(tick|step|update|loop|frame|animate|draw|move|fall|glue|physics|timer|interval|pulse|shrink|grow)', re.I)
ANIM = re.compile(r'(pulse|shake|winK|fade|alpha|scale|rotate|offset|flash|anim|ball|paddle|vel|vx|vy|endless)', re.I)
PRIM = re.compile(r'^\s*(boolean|number|string)\s*$')
CALL_RE = re.compile(r'this\.([A-Za-z_$][\w$]*)\s*\(')
ASSIGN = re.compile(r'this\.([A-Za-z_$][\w$]*)\s*(?:\+\+|--|\+=|-=|=)')
DISPLAY = re.compile(r'(Text\s*\(|Button\s*\(|fontColor|backgroundColor|Palette\.|\.opacity)')
FIELD_REF = re.compile(r'this\.([A-Za-z_$][\w$]*)')


def mask(src):
    """把注释与字符串抹成空格（保留长度与换行），供结构分析。"""
    out = list(src)
    i, n = 0, len(src)
    st = None
    while i < n:
        c = src[i]
        nx = src[i + 1] if i + 1 < n else ''
        if st is None:
            if c == '/' and nx == '/':
                st = 'l'; i += 2; continue
            if c == '/' and nx == '*':
                st = 'b'; i += 2; continue
            if c in '"\'`':
                st = c; i += 1; continue
            i += 1; continue
        if st == 'l':
            if c == '\n':
                st = None
            else:
                out[i] = ' '
            i += 1; continue
        if st == 'b':
            if c == '*' and nx == '/':
                st = None; i += 2; continue
            if c != '\n':
                out[i] = ' '
            i += 1; continue
        if c == '\\':
            out[i] = ' '; i += 2; continue
        if c == st:
            st = None
        elif c != '\n':
            out[i] = ' '
        i += 1
    return ''.join(out)


def match_brace(m, o):
    d = 0
    for i in range(o, len(m)):
        if m[i] == '{':
            d += 1
        elif m[i] == '}':
            d -= 1
            if d == 0:
                return i
    return -1


def funcs(m):
    """⇒ {name: [(body_start, body_end, signature_start)]}"""
    res = {}
    for mt in FUNC_RE.finditer(m):
        name = mt.group(1)
        if name in KEYWORDS:
            continue
        b = m.find('{', mt.start(), mt.end())
        e = match_brace(m, b)
        if e < 0:
            continue
        res.setdefault(name, []).append((b, e, mt.start()))
    return res


def reset_surface(fs, m):
    """reset 根函数 + 它们（最多 3 层）调用的函数名集合。"""
    roots = {fn for fn in fs if ROOT_RESET.match(fn)}
    surface = set(roots)
    frontier = set(roots)
    for _ in range(3):
        nxt = set()
        for fn in frontier:
            for (b, e, _s) in fs.get(fn, []):
                for cm in CALL_RE.finditer(m[b:e]):
                    callee = cm.group(1)
                    if callee in fs and callee not in surface:
                        nxt.add(callee)
        if not nxt:
            break
        surface |= nxt
        frontier = nxt
    return surface


def enclosing_if(m, line_start, line_end):
    """找包住当前行的最内层 `if (...)`，返回条件文本（找不到 None）。"""
    head = m[:line_start]
    lines = head.split('\n')
    depth = 0
    for k in range(len(lines) - 1, max(-1, len(lines) - 31), -1):
        l = lines[k]
        depth += l.count('}') - l.count('{')
        if depth <= 0:
            st = l.strip()
            mt = re.match(r'^(?:if|else if)\s*\((.*)\)\s*\{\s*$', st)
            if mt:
                return mt.group(1)
            if st.startswith('}') and depth < 0:
                return None
    return None


def guard_fields(cond):
    return set(FIELD_REF.findall(cond or ''))


def scan_file(path, verbose=False):
    rel = os.path.relpath(path, ROOT)
    src = io.open(path, encoding='utf-8').read()
    m = mask(src)
    lines = m.split('\n')
    line_offsets = []
    off = 0
    for l in lines:
        line_offsets.append(off)
        off += len(l) + 1

    fs = funcs(m)
    if not fs:
        return []
    surface = reset_surface(fs, m)
    # 各字段在哪被赋值、在 reset 面被赋值（含清零/任何赋值）
    wrote, wrote_reset = {}, set()
    for fn, spans in fs.items():
        for (b, e, _s) in spans:
            for am in ASSIGN.finditer(m[b:e]):
                f = am.group(1)
                wrote.setdefault(f, set()).add(fn)
                if fn in surface:
                    wrote_reset.add(f)
    # 原始类型 @State 字段
    fields = []
    for mt in re.finditer(r'@State\s+(?:private\s+|public\s+)?([A-Za-z_$][\w$]*)\s*:\s*([^=;\n]+)', m):
        name, typ = mt.group(1), mt.group(2).strip()
        if PRIM.match(typ) and name not in fields:
            fields.append(name)

    hits = []
    for f in fields:
        if f in wrote_reset or f not in wrote or ANIM.search(f):
            continue
        # 只算「事件函数」写入的字段（连续量每帧覆盖，不算残留来源）
        event_fns = [fn for fn in wrote[f] if EVENT_FN.search(fn) and not CONT_FN.search(fn)]
        if not event_fns:
            continue
        # 找显示点
        sites = []
        for li, l in enumerate(lines):
            if not re.search(r'this\.' + re.escape(f) + r'\b', l):
                continue
            if not DISPLAY.search(l):
                continue
            pos = l.find('this.' + f)
            # ★ 守卫 = X **之前**出现的所有 this.Y（含三元条件里的），
            #   不用「按括号裁条件」——那样会在 `this.tapped === (d) ? ...` 上裁错（实测踩过）。
            before = l[:pos]
            outer = enclosing_if(m, line_offsets[li], line_offsets[li] + len(l))
            sites.append({'line': li + 1, 'cond': before.strip()[:80], 'outer': outer or '',
                          'guards': guard_fields(before) | guard_fields(outer),
                          'text': src.split('\n')[li].strip()[:110]})
        if not sites:
            continue
        # 第 2 跳：任一显示点「有守卫且守卫在 reset 面被赋值」⇒ 该点无害
        unguarded = []
        for s in sites:
            g = {x for x in s['guards'] if x != f}
            if any(x in wrote_reset for x in g):
                continue
            unguarded.append(s)
        if not unguarded:
            continue
        hits.append({'file': rel, 'field': f, 'event_fns': sorted(event_fns)[:4],
                     'sites': unguarded[:2]})
    return hits


# ──────────────────────────── 自检 ────────────────────────────
SELF_POS = '''
@Component
struct Demo {
  @State msg: string = '';
  private reset(): void { this.round = 1; this.buildRound(); }
  private buildRound(): void { this.opts = ['a']; }
  private tap(i: number): void { this.msg = TG2('❌ {0} 不对', i); }
  build() {
    Column() { Text(this.msg) }
  }
}
'''
SELF_GUARDED = '''
@Component
struct Demo {
  @State lastOk: boolean = false;
  @State answered: boolean = false;
  private reset(): void { this.answered = false; this.lastOk = false; }
  private answer(ok: boolean): void { this.answered = true; this.lastOk = ok; }
  build() {
    Column() {
      Text('x').fontColor(this.answered ? (this.lastOk ? Palette.emerald : Palette.rose) : Palette.ink)
    }
  }
}
'''
SELF_RESET = '''
@Component
struct Demo {
  @State msg: string = '';
  private reset(): void { this.msg = TG('新局'); }
  private tap(): void { this.msg = TG('答对了'); }
  build() { Column() { Text(this.msg) } }
}
'''
SELF_ANIM = '''
@Component
struct Demo {
  @State scorePulse: number = 1;
  private answer(): void { this.scorePulse = 1.3; }
  build() { Column() { Text('x').opacity(this.scorePulse) } }
}
'''


def self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix='resetleak_')
    ok = []
    try:
        def run(name, code):
            p = os.path.join(d, name + '.ets')
            io.open(p, 'w', encoding='utf-8').write(code)
            return scan_file(p)
        h = run('pos', SELF_POS)
        ok.append(('正例必须命中（msg 无守卫）', len(h) == 1 and h[0]['field'] == 'msg',
                   '%d 处 %s' % (len(h), [x['field'] for x in h])))
        h = run('guarded', SELF_GUARDED)
        ok.append(('负例必须不报（answered 守卫在 reset 清零）', len(h) == 0, '%d 处' % len(h)))
        h = run('reset', SELF_RESET)
        ok.append(('负例必须不报（reset 自己写 msg）', len(h) == 0, '%d 处' % len(h)))
        h = run('anim', SELF_ANIM)
        ok.append(('负例必须不报（动画脉冲字段）', len(h) == 0, '%d 处' % len(h)))
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
    for d in ('games', 'components', 'pages'):
        files += sorted(glob.glob(os.path.join(ETS, d, '*.ets')))
    if not files:
        print('  🔴 没找到 .ets 文件')
        return 2
    all_hits = []
    for p in files:
        all_hits += scan_file(p, verbose)

    print('  ═══ 状态复位遗漏检查（第四把尺子 · 2-hop 守卫链）═══')
    print('  扫描 .ets：%d 个' % len(files))
    if all_hits:
        print('\n  ❌ 跨局状态残留 %d 处：' % len(all_hits))
        for h in all_hits:
            print('     · %s  [%s]  写入: %s' % (h['file'], h['field'], ','.join(h['event_fns'])))
            for s in h['sites']:
                print('        L%d 无有效守卫：%s' % (s['line'], s['text']))
        print('\n  修法：在 reset()/restart() 里把该字段清回初始值（或给显示点加一个 reset 会清的守卫）。')
        print('  复位遗漏：%d 处' % len(all_hits))
        return 1
    print('\n  ✅ 没有跨局状态残留（每个显示点都有 reset 面清零的守卫，或 reset 自己会重置）')
    print('  复位遗漏：0 处')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
