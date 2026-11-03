#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按名字在游戏列表里找并进一次（用于补测漏掉的款）"""
import json, os, re, subprocess, sys, time

HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
DEV = '127.0.0.1:5555'


def sh(c, t=25):
    try:
        r = subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t)
        return (r.stdout or '').strip()
    except subprocess.TimeoutExpired:
        return ''


def shell(cmd, t=25):
    return sh('%s -t %s shell %s' % (HDC, DEV, json.dumps(cmd)), t)


def dump():
    shell('uitest dumpLayout -p /data/local/tmp/fd.json')
    p = '/tmp/fd.json'
    if os.path.exists(p):
        try:
            os.remove(p)
        except OSError:
            pass
    sh('%s -t %s file recv /data/local/tmp/fd.json %s' % (HDC, DEV, p), 30)
    if not os.path.exists(p):
        return []
    try:
        d = json.load(open(p, encoding='utf-8'))
    except Exception:
        return []
    out = []

    def w(n):
        if isinstance(n, dict):
            a = n.get('attributes') or {}
            t = (a.get('text') or '').strip()
            b = a.get('bounds') or ''
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
            if m and t:
                x1, y1, x2, y2 = [int(g) for g in m.groups()]
                out.append((t, (x1 + x2) // 2, (y1 + y2) // 2, y1))
            for c in (n.get('children') or []):
                w(c)
    w(d)
    return out


def main():
    wants = set(sys.argv[1:]) or {'弹珠消', '跳棋', '复合连线', '四子棋'}
    found = {}
    for _ in range(70):
        rows = dump()
        if not rows:
            time.sleep(1)
            continue
        for (t, cx, cy, y1) in rows:
            if t in wants and t not in found and 250 < y1 < 1900:
                found[t] = (cx, cy)
        if len(found) >= len(wants):
            break
        # 看到底部导航说明在列表里，否则先回列表
        if not any(t in ('游戏', 'Games') for (t, *_r) in rows):
            shell('uitest uiInput keyEvent Back')
            time.sleep(1.2)
            continue
        shell('uitest uiInput swipe 660 1750 660 700 600')
        time.sleep(1.1)

    print('  找到 %d/%d：%s' % (len(found), len(wants), list(found.keys())))
    if not found:
        return
    for nm, (cx, cy) in found.items():
        shell('uitest uiInput click %d %d' % (cx, cy))
        time.sleep(2.5)
        nd = dump()
        names = [t for (t, *_r) in nd]
        entered = (nm in names) or ('‹' in names)
        print('     %s → %s（%d 节点）%s' % (
            nm, '✅ 进入' if entered else '🔴 没进入', len(nd),
            ' / '.join(names[:5])))
        rec = {'id': 'manual_' + nm, 'name': nm, 'entered': entered,
               'nodes': len(nd), 'enter_s': 0, 'first': names[:8], 'note': '手动补测'}
        with open('/Users/a0000/dev/yiju/验收截图-v1.0.1/smoke355.jsonl', 'a', encoding='utf-8') as f:
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
        shell('uitest uiInput keyEvent Back')
        time.sleep(1.5)


if __name__ == '__main__':
    main()
