#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HUD 标签一致性检查器 —— 同一个 HUD 容器里，标签的 maxLines/minFontSize 必须一致

★ 为什么要它（2026-11-08 凌晨，从「行盒错位」追下来的）：
  三块统计 HUD（`Row { Column{ 标签 + 数值 } × 3 }`）是**逐文件复制粘贴**的
  （`games/` 里 295 份副本，没有任何共享 @Builder）。
  其中 24 款手写时把**某一块**的标签改成 `maxLines(2)`、另外两块留 1 行或干脆不写：
    → 某语言标签一换行，那一块的数值就比邻块**低一整行（xxs 行盒 14vp）**
    → 三块数值不在一条水平线上（德语/俄语最容易触发，中文 2~4 字看不出来）
  ⇒ 判据：**同一 HUD 容器内的标签，maxLines 与 minFontSize 必须完全一致**。
  ⇒ 本脚本就是这条判据的可执行形式。

★ 认什么（两种 HUD 形状都认）
  ① 块状：`Row { Column{ 小字标签, 粗体数值 } … }` —— 两个以上这样的 Column 同一个 Row
  ② 行内：`Row { 小字标签, 粗体数值, … }` —— 直接作为 Row 的 Text 子节点
  「标签」= 小字（`fontSize(FontSize.xxs)` 或 `(FontSize.xs)`）+ 淡色（`fontColor(…inkFaint)`），
  且**紧邻的下一个兄弟是粗体数值**（`FontWeight.Bold`）。这是本项目 HUD 的固定写法。
  「提示语」= 同样是淡色小字，但**后面没有粗体数值**（例如「选出对应的英文单词」）
  ⇒ 提示语**允许** 2 行，不进判据（白名单）。

★ 输出
  人读：逐条 `文件:行 <块标签> maxLines=… minFontSize=…`
  机读：收尾行 `HUD不一致：N 处`（供 `工具/check_assertions.sh` 当闸门）
  退出码：0 = 全一致 ｜ 1 = 有 N 处不一致 ｜ 2 = 解析失败/自检失败

用法：
  python3 tools/check_hud_consistency.py                # 全仓（games + components）
  python3 tools/check_hud_consistency.py --verbose      # 连"提示语放行"明细一起打
  python3 tools/check_hud_consistency.py --paths /tmp/hud_before   # 扫别的目录（自检用）
  python3 tools/check_hud_consistency.py --self-test    # 先验证尺子自己
"""
import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '工具'))
from ets_parse import match_paren, strip_comments   # noqa: E402  项目自带的真括号配平

SCAN_DIRS = ['entry/src/main/ets/games', 'entry/src/main/ets/components']
CONTAINERS = ('Row', 'Column', 'Flex')
CALL = re.compile(r'\b(Row|Column|Flex|Stack|Text)\s*\(')
BLOCK = re.compile(r'\b(Row|Column|Flex|Stack|Text)\s*\(')
SMALL = ('FontSize.xxs', 'FontSize.xs')
VALUE_HINT = 'FontWeight.Bold'


def _chain(src, start, stop):
    """取一个 Text( 语句的属性链（含续行）：从 start 到第一个「不以 . 开头」的行尾"""
    out = []
    depth = 0
    i = start
    while i < min(stop, len(src)):
        line_end = src.find('\n', i)
        if line_end < 0:
            line_end = len(src)
        seg = src[i:line_end]
        depth += seg.count('(') - seg.count(')')
        out.append(seg)
        i = line_end + 1
        if depth <= 0:
            break
        # 下一行不以 . / 注释开头 ⇒ 链结束
        j = i
        while j < len(src) and src[j] in ' \t':
            j += 1
        if j < len(src) and src[j] not in '.':
            break
    return '\n'.join(out)


def _label_key(chain):
    """标签的判据键 (maxLines, minFontSize)；不是标签返回 None"""
    if 'inkFaint' not in chain:
        return None
    if not any(s in chain for s in SMALL):
        return None
    ml = re.search(r'\.maxLines\(\s*(\d+)\s*\)', chain)
    mf = re.search(r'\.minFontSize\(\s*(\d+)\s*\)', chain)
    return (int(ml.group(1)) if ml else None, int(mf.group(1)) if mf else None)


def _parse(src, a, b):
    """把 [a,b) 解析成块树：[(type, start, children)]，Text 为叶子

    只认 Row/Column/Flex/Stack/Text —— HUD 结构就这五种。
    """
    nodes = []
    i = a
    while i < b:
        m = BLOCK.search(src, i, b)
        if not m:
            break
        try:
            pend = match_paren(src, m.end() - 1)
        except Exception:
            i = m.end()
            continue
        # 找紧跟的 { ... }
        k = pend + 1
        while k < b and src[k] in ' \t\r\n':
            k += 1
        if k < b and src[k] == '{':
            try:
                bend = match_paren(src, k)
            except Exception:
                i = pend + 1
                continue
            nodes.append((m.group(1), m.start(), _parse(src, k + 1, bend)))
            i = bend + 1
        else:
            chain = _chain(src, m.start(), min(b, pend + 400))
            nodes.append((m.group(1), m.start(), None, chain))
            i = pend + 1
    return nodes


def _texts(node):
    """把树摊平成 [(pos, chain)]，只留 Text 叶子"""
    out = []
    for n in node[2] or []:
        if n[2] is None and n[3] is not None:
            out.append((n[1], n[3]))
        elif n[2]:
            out.extend(_texts(n))
    return out


def _stat_blocks(node):
    """返回 [(标签链, 数值链)]：Column 里「标签 + 粗体数值」的成对结构"""
    pairs = []
    kids = node[2] or []
    leaf = [k for k in kids if k[2] is None and k[3] is not None]
    for idx in range(len(leaf) - 1):
        a, b = leaf[idx], leaf[idx + 1]
        if _label_key(a[3]) is not None and VALUE_HINT in b[3]:
            pairs.append((a, b))
    return pairs


def scan_file(path):
    raw = io.open(path, encoding='utf-8').read()
    src = strip_comments(raw)
    hits, allowed = [], 0

    def line_of(pos):
        return src.count('\n', 0, pos) + 1

    def walk(node):
        nonlocal allowed
        # 形①：若干个「标签+数值」的 Column 挂在同一个 Row 下
        if node[0] == 'Row':
            blocks = []
            for kid in node[2] or []:
                if kid[2] is None:
                    continue
                blocks.extend(_stat_blocks(kid))
            if len(blocks) >= 2:
                keys = [_label_key(a[3]) for a, _ in blocks]
                if len(set(keys)) > 1:
                    hits.append((line_of(blocks[0][0][1]), node[0], keys))
        # 形②：标签/数值直接作为同一容器的 Text 子节点
        pairs = _stat_blocks(node) if node[0] == 'Column' else []
        leaf = [k for k in (node[2] or []) if k[2] is None and k[3] is not None]
        direct = []
        for idx in range(len(leaf) - 1):
            a, b = leaf[idx], leaf[idx + 1]
            if _label_key(a[3]) is not None and VALUE_HINT in b[3]:
                direct.append(a)
        if node[0] == 'Row' and len(direct) >= 2:
            keys = [_label_key(x[3]) for x in direct]
            if len(set(keys)) > 1:
                hits.append((line_of(direct[0][1]), node[0], keys))
        # 提示语（淡色小字但没有紧跟粗体数值）⇒ 白名单，只计数
        for idx, x in enumerate(leaf):
            if _label_key(x[3]) is None:
                continue
            nxt = leaf[idx + 1] if idx + 1 < len(leaf) else None
            if nxt is None or VALUE_HINT not in nxt[3]:
                allowed += 1
        for kid in node[2] or []:
            if kid[2]:
                walk(kid)

    for top in _parse(src, 0, len(src)):
        if top[2]:
            walk(top)
    return hits, allowed


def main(argv):
    verbose = '--verbose' in argv
    self_test = '--self-test' in argv
    roots = SCAN_DIRS
    if '--paths' in argv:
        i = argv.index('--paths')
        roots = [a for a in argv[i + 1:] if not a.startswith('--')]

    if self_test:
        ok = _self_test()
        print('  自检：%s' % ('✅ 通过' if ok else '🔴 失败'))
        print('  HUD不一致：%d 处' % (0 if ok else 1))
        return 0 if ok else 2

    files = []
    for r in roots:
        d = r if os.path.isabs(r) else os.path.join(ROOT, r)
        files.extend(sorted(glob.glob(os.path.join(d, '*.ets'))))
    if not files:
        print('  🔴 一个 .ets 都没找到（--paths 对吗？）')
        print('  HUD不一致：0 处')
        return 2

    all_hits, all_allowed = [], 0
    for f in files:
        try:
            hits, allowed = scan_file(f)
        except Exception as e:                     # 解析失败必须显形，不能当绿
            print('  🔴 解析失败：%s（%s）' % (os.path.relpath(f, ROOT), e))
            print('  HUD不一致：0 处')
            return 2
        all_allowed += allowed
        for ln, typ, keys in hits:
            all_hits.append((os.path.relpath(f, ROOT), ln, typ, keys))

    print('  扫描 .ets：%d 个' % len(files))
    if all_hits:
        print('  ❌ %d 处 HUD 标签 maxLines/minFontSize 不一致（换行时数值会错位）：' % len(all_hits))
        for rel, ln, typ, keys in all_hits:
            print('     %s:%d <%s> 各块键=%s' % (rel, ln, typ, keys))
        print('\n  修法：同一 HUD 容器内的标签统一成')
        print('        .maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)')
        print('        （提示语另有 2 行权限，本检查器已白名单放行）')
    else:
        print('  ✅ 所有 HUD 容器的标签一致')
    if verbose:
        print('  白名单放行（提示语）：%d 处' % all_allowed)
    print('  HUD不一致：%d 处' % len(all_hits))
    return 1 if all_hits else 0


def _self_test():
    """反证尺子：喂 3 段人造代码，必须得 1 不一致 + 2 白名单"""
    bad = '''
    Row({ space: 10 }) {
      Column() { Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold) }
      Column() { Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(2)
        Text(String(this.left)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold) }
    }
'''
    good = '''
    Row({ space: 10 }) {
      Column() { Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8)
        Text(Digits(String(this.right))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold) }
      Column() { Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8)
        Text(String(this.left)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold) }
    }
'''
    prompt = '''
    Column() { Text(TG('选出对应的英文单词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(2) }
'''
    tmp = os.path.join(ROOT, 'tools', '_hud_selftest.ets')
    try:
        res = []
        for body in (bad, good, prompt):
            io.open(tmp, 'w', encoding='utf-8').write(body)
            hits, allowed = scan_file(tmp)
            res.append((len(hits), allowed))
        # bad ⇒ 1 处不一致、0 提示语；good ⇒ 0/0；prompt ⇒ 0/1
        return res[0][0] == 1 and res[1][0] == 0 and res[2][0] == 0 and res[2][1] >= 1
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
