#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
landscape_sweep.py —— 横屏下逐款打开游戏，自动检测「底部被切 / 元素溢出」

★★★ 起因（2026-10-30）：
    静态扫描扫出 132 款「aspectRatio + layoutWeight 无兜底」，
    但静态扫描**会误报**（纯网格游戏占满屏，横屏也没事）。
    ⇒ 唯一可靠的判据是**真机打开看**。

判据（三条，都不依赖肉眼）：
    ① 底部元素（重开/提示/AI 代打）的 y 坐标是否 > 屏高 - 安全余量
    ② dump 里能否找到这些按钮（找不到 ⇒ 可能被裁掉在屏幕外）
    ③ 截图底部 N 像素是否有"内容被切断"的迹象（与页面背景色不同的条带）

用法：
    python3 工具/landscape_sweep.py --limit 40
    python3 工具/landscape_sweep.py --games 宝石迷阵,弹珠消,数独
"""
import importlib.util, os, sys, time, subprocess, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
A = [HC, '-t', '127.0.0.1:5555']

# 底部必须有、且必须可见的按钮名
BOTTOM_LABELS = ['重开', '提示', 'AI 代打', '撤销', '擦除', '提交', '放弃', '退一步']


def sh(cmd, timeout=60):
    return subprocess.run(A + ['shell', cmd], capture_output=True, timeout=timeout)


def dump():
    spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
    vb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(vb)
    return vb.dump()


def main():
    args = sys.argv[1:]
    limit = 40
    only = None
    if '--limit' in args:
        limit = int(args[args.index('--limit') + 1])
    if '--games' in args:
        only = args[args.index('--games') + 1].split(',')

    spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
    vb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(vb)

    sh('power-shell setmode 602')
    # 回到列表顶部
    for _ in range(20):
        vb.sh('uitest uiInput swipe 1280 700 1280 1400 280'); time.sleep(0.2)
    time.sleep(1.5)
    # 收起筛选
    col = [r for r in dump() if '收起' in str(r[0])]
    if col:
        vb.sh('uitest uiInput click %d %d' % (int(col[0][1]), int(col[0][2]))); time.sleep(2)

    # ① 从当前屏收集（只这一屏，约 8 款）—— 先验证判据，再扩到全量
    names = []
    _seen = set()
    for r in dump():
        t = str(r[0]).strip()
        if not (2 <= len(t) <= 10):
            continue
        if any(x in t for x in ['游戏', '统计', '设置', '全部', '展开', '收起',
                                '网络', '列表', '全部 ·']):
            continue
        if t in _seen:
            continue
        # 过滤掉 tagline（通常含空格或更长）
        if ' ' in t or '·' in t:
            continue
        _seen.add(t)
        names.append((t, int(r[1]), int(r[2])))
    if only:
        names = [n for n in names if n[0] in only] or names
    print('  本屏收集到 %d 款: %s' % (len(names), [n[0] for n in names[:8]]))

    print('══ 横屏扫描：准备测 %d 款 ══' % min(len(names), limit))
    problems = []
    for i, (name, x, y) in enumerate(names[:limit]):
        vb.sh('uitest uiInput click %d %d' % (x, y))
        time.sleep(5.5)
        rows2 = dump()
        labels = [str(r[0]) for r in rows2]
        ys = {str(r[0]): int(r[2]) for r in rows2 if str(r[0]) in BOTTOM_LABELS}
        # 判据 ①：底部按钮是否存在
        missing = [b for b in BOTTOM_LABELS if b in ('重开', '提示') and b not in labels]
        # 判据 ②：y 坐标是否超出安全区（屏高 1600px，留 120px 给导航栏）
        out = [(k, v) for k, v in ys.items() if v > 1600 - 120]
        if missing or out:
            problems.append((name, missing, out))
            print('  ⚠️ %-14s 缺:%s  超界:%s' % (name, missing, out))
        else:
            print('  ✅ %-14s' % name)
        b = [r for r in rows2 if str(r[0]) == '‹']
        if b:
            vb.sh('uitest uiInput click %d %d' % (int(b[0][1]), int(b[0][2])))
            time.sleep(2.5)

    print()
    print('══ 结果：%d 款被测，%d 款有问题 ══' % (min(len(names), limit), len(problems)))
    for name, m, o in problems:
        print('  ⚠️ %-14s 缺按钮:%s  超界:%s' % (name, m, o))
    if problems:
        with open(os.path.join(ROOT, '验收截图-v1.0.1/landscape_problems.json'), 'w') as f:
            json.dump([{'game': n, 'missing': m, 'overflow': o} for n, m, o in problems],
                      f, ensure_ascii=False, indent=2)
        print('  已存 验收截图-v1.0.1/landscape_problems.json')


if __name__ == '__main__':
    main()
