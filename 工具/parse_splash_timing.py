#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
工具/parse_splash_timing.py —— **解析开屏时序日志**（判据 1195/1459/1462/1464）

★ 为什么要有（第 1400~1401 轮）
  goal 待办：「开屏「环先到、M 晚 N ms」在其它设备的墙钟复算」
  ⇒ 我手工写正则解析，**结果 pStroke/pM 全解析失败**
  ⇒ 根因：日志分隔符是 **`｜`（U+FF5C 全角竖线）**，而我的正则写的是 ASCII `\\|`
  ⇒ 这是判据 1207（全角字符）的**第 N 次**，只是换了场景

★ 关键判据
  · **`accum`（时间轴）与设备无关** ⇒ 三台极差 ≤ 20ms 算通过（判据 1195）
  · **`drift`（墙钟 − 时间轴）与设备强相关** ⇒ 小屏更慢（判据 1462）
  · **`dropped` 应为 0** ⇒ 否则有帧被漏掉（判据 1463）

★ 用法
  python3 工具/parse_splash_timing.py                # 扫 验收截图-v1.0.1/SPLASH_TIMING_*.log
  python3 工具/parse_splash_timing.py <log> [...]    # 指定文件

★ 退出码
  0 = 至少一份有效且 END accum 极差 ≤ 20ms
  1 = 无有效日志
  2 = 有有效日志但极差 > 20ms（时序不稳）

★ 判据 1464：**反复踩同一个坑 ⇒ 写成脚本**（判据 475 的第 N 次）
"""
import sys
import os
import re
import glob


# ★★★ 核心：分隔符是**全角**竖线 U+FF5C，不是 ASCII `|`
#   判据 1207/1461：全角字符让我踩了至少 5 次
SEP = '\uff5c'          # ｜
SEP_ALT = '|'           # 兼容万一有人写 ASCII


def _fields(line):
    """把一行拆成 {key: int} —— 兼容全角与 ASCII 分隔符"""
    # 先按全角拆，再按 ASCII 拆（两种都算）
    parts = re.split('[%s%s]' % (re.escape(SEP), re.escape(SEP_ALT)), line)
    out = {}
    for p in parts:
        m = re.search(r'([a-zA-Z_]+)\s*=\s*(-?\d+)\s*(?:ms|)', p)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


def parse(path):
    """返回 dict：{pStroke:{accum,wall,drift}, pM:{...}, END:{...}, dropped:int, raw_lines:int}"""
    try:
        txt = open(path, encoding='utf-8', errors='replace').read()
    except Exception as e:
        return {'err': str(e)}
    res = {'file': os.path.basename(path), 'raw_lines': 0}
    for l in txt.split('\n'):
        if not l.strip():
            continue
        res['raw_lines'] += 1
        if 'pStroke>' in l and 'pStroke' not in res:
            f = _fields(l.split('pStroke>')[-1])
            if f:
                res['pStroke'] = f
        if 'pM>' in l and 'pM' not in res:
            f = _fields(l.split('pM>')[-1])
            if f:
                res['pM'] = f
        if 'END |' in l or 'END\uff5c' in l:
            f = _fields(l.split('END')[-1])
            if f:
                res['END'] = f
        if 'dropped=' in l:
            m = re.search(r'dropped=(\d+)', l)
            if m:
                res['dropped'] = int(m.group(1))
    return res


def main():
    args = sys.argv[1:]
    if args:
        files = args
    else:
        files = sorted(glob.glob('验收截图-v1.0.1/SPLASH_TIMING_*.log'))
        if not files:
            files = sorted(glob.glob('SPLASH_TIMING_*.log'))
    if not files:
        print('  🔴 找不到任何 SPLASH_TIMING_*.log')
        return 1

    rows = []
    for f in files:
        r = parse(f)
        if 'err' in r:
            print('  🔴 %s ⇒ %s' % (os.path.basename(f), r['err']))
            continue
        name = r['file'].replace('SPLASH_TIMING_hilog_', '').replace('.log', '')
        ps = r.get('pStroke', {})
        pm = r.get('pM', {})
        en = r.get('END', {})
        ok = bool(ps.get('accum') is not None and pm.get('accum') is not None
                  and en.get('accum') is not None)
        rows.append({
            'name': name, 'ok': ok,
            'pS_acc': ps.get('accum'), 'pS_wall': ps.get('wall'),
            'pM_acc': pm.get('accum'), 'pM_wall': pm.get('wall'),
            'END_acc': en.get('accum'), 'END_wall': en.get('wall'),
            'drift': en.get('drift'), 'dropped': r.get('dropped'),
            'lines': r['raw_lines'],
        })

    print('  ══ 开屏时序解析（%d 份日志）══' % len(rows))
    print()
    hdr = '  %-20s %4s %7s %8s %7s %8s %8s %8s %8s %7s %7s' % (
        '设备', '行', 'pS_acc', 'pS_wall', 'pM_acc', 'pM_wall',
        'END_acc', 'END_wall', 'drift', 'drop', '判定')
    print(hdr)
    for r in rows:
        print('  %-20s %4d %7s %8s %7s %8s %8s %8s %8s %7s %7s' % (
            r['name'], r['lines'],
            r['pS_acc'], r['pS_wall'], r['pM_acc'], r['pM_wall'],
            r['END_acc'], r['END_wall'], r['drift'], r['dropped'],
            '✅' if r['ok'] else '🔴'))

    valid = [r for r in rows if r['ok']]
    print()
    if not valid:
        print('  🔴 **无一份三项齐全** ⇒ 无法判定')
        print('     （pStroke / pM / END 三个都要解析出来）')
        return 1

    print('  ══ 判定 ══')
    ends = [r['END_acc'] for r in valid]
    print('  有效份数: **%d / %d**' % (len(valid), len(rows)))
    print('  END accum: %s ⇒ 极差 **%d ms**' % (ends, max(ends) - min(ends)))
    if max(ends) - min(ends) <= 20:
        print('  ✅ **「时间轴与设备无关」成立**（极差 ≤ 20ms，判据 1195）')
    else:
        print('  ⚠️ **极差 > 20ms** ⇒ 时序不稳，需查（判据 1195）')

    # M 相对环的延迟（这是「环先到、M 晚 N ms」的直接答案）
    print()
    print('  ── 「M 比环晚 N ms」（accum，与设备无关）──')
    gaps = []
    for r in valid:
        if r['pS_acc'] is not None and r['pM_acc'] is not None:
            g = r['pM_acc'] - r['pS_acc']
            gaps.append(g)
            print('    %-20s **%d ms**' % (r['name'], g))
    if len(gaps) >= 2:
        print('    ⇒ 极差 **%d ms** ⇒ %s'
              % (max(gaps) - min(gaps),
                 '✅ 相对节奏一致' if max(gaps) - min(gaps) <= 20 else '⚠️ 偏大'))

    # 墙钟差异
    drifts = [r['drift'] for r in valid if r['drift'] is not None]
    if len(drifts) >= 2:
        print()
        print('  ── 墙钟延迟（drift）──')
        for r in valid:
            if r['drift'] is not None:
                print('    %-20s **%d ms**' % (r['name'], r['drift']))
        print('    ⇒ 极差 **%d ms（%.1f 倍）** ⇒ %s'
              % (max(drifts) - min(drifts), max(drifts) / min(drifts),
                 '⚠️ **与设备强相关**（判据 1462）' if max(drifts) - min(drifts) > 50
                 else '与设备无关'))

    # 掉帧
    drops = [(r['name'], r['dropped']) for r in valid if r['dropped'] is not None]
    if drops:
        print()
        print('  ── 掉帧 ──')
        for n, d in drops:
            print('    %-20s dropped=%d %s' % (n, d, '✅' if d == 0 else '⚠️'))
        nz = [d for _, d in drops if d > 0]
        if nz:
            print('    ⚠️ 有 %d 台 dropped > 0 ⇒ 目标应为 **0**（判据 1463）' % len(nz))

    return 0 if max(ends) - min(ends) <= 20 else 2


if __name__ == '__main__':
    sys.exit(main())
