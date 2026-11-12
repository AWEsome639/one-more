#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""对一款游戏做「静态体检」：不碰设备，只读源码，列出所有可调的高度/约束/说明行。

为什么：判据 1932 说「先拿 `bounds` 再改」，但设备不在时拿不到 `bounds`。
       那就先拿到「**候选刀口清单**」——等设备回来直接照单验证。

用法：python3 工具/静态体检.py GTapa GKurodoko
输出：每款一节，分四类
  ① 棋盘/容器：`aspectRatio(1)`、`width('100%')`、`constraintSize`
  ② 固定高度：`Cell.of(N)` / `Cell.tap(N)` / `.height(N)`
  ③ 说明行候选：`Text(...)` 里含「；」「，」超过 12 字的（多半是静态说明）
  ④ 已有矮屏门控：`Bp.isShort()` 出现次数
"""
import io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GDIR = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games')


def scan(cls):
    p = os.path.join(GDIR, cls + '.ets')
    if not os.path.exists(p):
        return None
    lines = io.open(p, encoding='utf-8').read().split('\n')
    out = {'file': p, 'aspect': [], 'width100': [], 'constraint': [],
           'heights': [], 'tips': [], 'short': 0}
    for i, ln in enumerate(lines, 1):
        if 'aspectRatio(1)' in ln:
            out['aspect'].append((i, ln.strip()[:80]))
        if ".width('100%')" in ln:
            out['width100'].append(i)
        if 'constraintSize' in ln:
            out['constraint'].append((i, ln.strip()[:90]))
        m = re.search(r'\.height\((Cell\.(?:of|tap)\(\s*(Bp\.isShort\(\) \? )?(\d+)[^)]*\)|\d+)\)', ln)
        if m:
            out['heights'].append((i, m.group(0)[:60]))
        t = re.search(r"Text\((?:TG\()?'([^']{12,})'", ln)
        if t and ('；' in t.group(1) or '，' in t.group(1)):
            out['tips'].append((i, t.group(1)[:46]))
        out['short'] += ln.count('Bp.isShort()')
    return out


def main():
    names = sys.argv[1:]
    if not names:
        print(__doc__)
        return 2
    for cls in names:
        r = scan(cls)
        if not r:
            print('\n### %s —— 文件不存在' % cls)
            continue
        print('\n### %s' % cls)
        print('  ④ 已有矮屏门控 `Bp.isShort()`: %d 处' % r['short'])
        print('  ① 棋盘/容器：aspectRatio×%d  width100×%d  constraintSize×%d'
              % (len(r['aspect']), len(r['width100']), len(r['constraint'])))
        for i, ln in r['constraint']:
            print('     L%-5d %s' % (i, ln))
        print('  ② 固定高度 %d 处：' % len(r['heights']))
        for i, ln in r['heights'][:6]:
            print('     L%-5d %s' % (i, ln))
        print('  ③ 说明行候选 %d 处：' % len(r['tips']))
        for i, tx in r['tips'][:4]:
            print('     L%-5d %s' % (i, tx))
    return 0


if __name__ == '__main__':
    sys.exit(main())
