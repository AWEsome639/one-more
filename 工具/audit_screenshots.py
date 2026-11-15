#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
截图新鲜度审计（判据 2800）：「我验证过了」要能被一条命令证实或证伪。

对每款比较：源码 mtime vs 该款最新截图 mtime。
  截图晚于源码 ⇒ 那张图看到的是改动之后的样子，可当证据
  截图早于源码 ⇒ 旧图，必须重拍

用法：
    python3 工具/audit_screenshots.py                # 审计台账里全部款
    python3 工具/audit_screenshots.py --games "Story Builder" "Orbit Tap"
    python3 工具/audit_screenshots.py --quiet        # 只打印有问题的
"""
import argparse
import glob
import io
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES_DIR = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games')
SHOT_DIR = os.path.join(ROOT, '_巡检记录')
LEDGER = os.path.join(SHOT_DIR, 'layout-canonical.tsv')


def source_mtime(name: str) -> float:
    """按款名找到源文件（G 前缀 + 去空格，或用宽松 glob）"""
    cand = os.path.join(GAMES_DIR, 'G' + name.replace(' ', '') + '.ets')
    if os.path.exists(cand):
        return os.path.getmtime(cand)
    # ★ 同样宽松：括号也要变成 *（否则 `Akari (Light Up)` 匹不到 `GAkariLightUp.ets`）
    hits = glob.glob(os.path.join(GAMES_DIR, 'G' + re.sub(r'[^0-9A-Za-z]+', '*', name) + '*.ets'))
    if len(hits) == 1:
        return os.path.getmtime(hits[0])
    return 0.0


def _sanitize_glob(name: str) -> str:
    """把非字母数字换成 * 做宽松匹配。

    ⚠️ 不能用「合并成一个 _」的规则：shot_game.py 生成的 `Akari__Light_Up_`
    有**两个**下划线（空格与左括号各自变成了 _），合并规则就匹配不上（判据 2580 的变体：
    先宽松匹配，别硬猜清洗规则）。
    """
    return re.sub(r'[^0-9A-Za-z]+', '*', name)


def newest_shot(name: str):
    snaps = glob.glob(os.path.join(SHOT_DIR, '截图-%s-*.jpeg' % _sanitize_glob(name)))
    if not snaps:
        return None, 0.0
    best = max(snaps, key=os.path.getmtime)
    return best, os.path.getmtime(best)


def ledger_names():
    names = []
    try:
        for ln in io.open(LEDGER, encoding='utf-8', errors='replace'):
            p = ln.rstrip('\n').split('\t')
            if len(p) >= 2 and p[1] and p[1] != 'game' and not p[1].startswith('__'):
                names.append(p[1])
    except OSError:
        pass
    return sorted(set(names))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--games', nargs='*')
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()

    names = args.games if args.games else ledger_names()
    if not names:
        print('没有款名可审计（台账缺？）', file=sys.stderr)
        return 1

    stale, missing, fresh = [], [], 0
    for n in names:
        st = source_mtime(n)
        path, nt = newest_shot(n)
        if path is None:
            missing.append(n)
        elif st and nt >= st:
            fresh += 1
        elif st == 0:
            missing.append(n)          # 找不到源文件，等同无证据
        else:
            stale.append((n, st, nt))

    print('=== 截图新鲜度审计（%d 款）===' % len(names))
    print('  ✅ 截图晚于改动   %d' % fresh)
    print('  ⛔ 截图早于改动   %d' % len(stale))
    print('  ❓ 无截图/无源文件 %d' % len(missing))
    if stale and not args.quiet:
        print('\n需要重拍的款（截图早于最近改动）：')
        for n, st, nt in stale[:30]:
            print('  %-28s 源 %s  图 %s'
                  % (n, time.strftime('%m-%d %H:%M', time.localtime(st)),
                     time.strftime('%m-%d %H:%M', time.localtime(nt))))
    if missing and not args.quiet:
        print('\n没有截图的款（前 20）：')
        for n in missing[:20]:
            print('  ' + n)
    return 0 if (not stale and not missing) else 0   # 审计不阻断流程，只报告


if __name__ == '__main__':
    sys.exit(main())
