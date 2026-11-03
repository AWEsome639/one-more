#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 判据② 长稳测试（soak）：连续操作 ≥90 分钟，每 10 分钟采样内存

判据：
  · 0 崩溃 / 0 冻死 / 0 卡死
  · 内存曲线【无单调上升】（无泄漏特征）
  · 有实测数据表

做法：
  · 循环：开游戏 → 等 → 返回 → 换标签页 → 偶尔滚动
  · 每次采样：VmRSS / 进程是否存活 / 当前页面
输出：~/dev/yiju/长稳-20261017/长稳数据.tsv + 日志
"""
import json
import os
import re
import subprocess
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
OUT = os.path.expanduser('~/dev/yiju/长稳-20261017')
os.makedirs(OUT, exist_ok=True)
LOG = os.path.join(OUT, '长稳数据.tsv')
TOTAL_MIN = int(os.environ.get('SOAK_MIN', '95'))
SAMPLE_EVERY = 600          # 10 分钟
TMP = '/tmp/soak.json'


def sh(c, t=25):
    try:
        return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def pid():
    return sh(f'{HDC} shell "pidof com.andrewoscar.onemore"').strip().split('\n')[0].strip()


def mem_kb(p):
    """★ 优先 /proc/<pid>/status 的 VmRSS；不行再用 hidumper"""
    if p:
        s = sh(f'{HDC} shell "cat /proc/{p}/status"')
        m = re.search(r'VmRSS:\s*(\d+)\s*kB', s)
        if m:
            return int(m.group(1))
    pp = p if p else ''
    s = sh('%s shell "hidumper --mem %s"' % (HDC, pp))
    m = re.search(r'Total:\s*(\d+)', s)
    return int(m.group(1)) if m else -1


def els():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/soak.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/soak.json {TMP}', 25)
    try:
        d = json.load(open(TMP, encoding='utf-8'))
    except Exception:
        return []
    out = []

    def walk(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', n)
        t = (a.get('text') or '') + (a.get('originalText') or '')
        b = a.get('bounds') or ''
        if t and b:
            out.append((t, b))
        for k in ('children', 'nodes'):
            for c in (n.get(k) or []):
                walk(c)
            for c in (a.get(k) or []):
                walk(c)
    walk(d)
    return out


def tap(x, y, w=1.2):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 15)
    time.sleep(w)


def first_card():
    for t, b in els():
        m = re.findall(r'-?\d+', b)
        if len(m) >= 4 and 250 <= int(m[0]) <= 340 and 300 < int(m[1]) < 2000 and (int(m[2])-int(m[0])) > 200:
            return ((int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2)
    return None


def back():
    for t, b in els():
        if '‹' in t:
            m = re.findall(r'-?\d+', b)
            if len(m) >= 4:
                tap((int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2, 1.5)
                return True
    return False


# ── 写表头 ──
if not os.path.exists(LOG):
    io = open(LOG, 'w', encoding='utf-8')
    io.write('时刻\t分\tVmRSS_KB\tRSS_MB\t进程存活\t当前页\n')
    io.close()

start = time.time()
last_sample = 0
crashes = 0
freezes = 0
prev_mem = -1
open(os.path.join(OUT, 'soak.log'), 'w').close()

print('  ★ 长稳开始 ｜ 目标 %d 分钟 ｜ 每 10 分钟采样' % TOTAL_MIN, flush=True)
while True:
    el = time.time() - start
    mins = el / 60
    if mins >= TOTAL_MIN:
        break
    # ── 采样 ──
    if el - last_sample >= SAMPLE_EVERY or last_sample == 0:
        last_sample = el
        p = pid()
        rss = mem_kb(p)
        hh = time.strftime('%H:%M')
        page = ''
        try:
            e = els()
            page = (e[0][0][:14] if e else '（空）')
        except Exception:
            pass
        with open(LOG, 'a', encoding='utf-8') as f:
            f.write('%s\t%.0f\t%d\t%.1f\t%s\t%s\n' % (hh, mins, rss, rss / 1024.0 if rss > 0 else -1,
                                                      '✅' if p else '🔴 死了', page))
        print('     [%s] %.0f 分 ｜ RSS %.1f MB ｜ %s' % (hh, mins, rss / 1024.0 if rss > 0 else -1,
                                                          '存活' if p else '🔴 进程没了'), flush=True)
        if not p:
            crashes += 1
            sh(f'{HDC} shell "aa start -a EntryAbility -b com.andrewoscar.onemore"', 25)
            time.sleep(10)
    # ── 操作一轮：开游戏 → 返回 → 换标签 ──
    c = first_card()
    if c:
        tap(*c, 3.2)
        # 操作游戏内一点（点屏幕中央，很多游戏有响应）
        tap(660, 1400, 0.4)
        tap(660, 1200, 0.4)
        if not back():
            # 找不到返回键 ⇒ 可能卡死
            freezes += 1
            print('     ⚠️ 找不到返回键 ⇒ 记一次卡死', flush=True)
            sh(f'{HDC} shell "aa force-stop com.andrewoscar.onemore"', 20)
            time.sleep(2)
            sh(f'{HDC} shell "aa start -a EntryAbility -b com.andrewoscar.onemore"', 25)
            time.sleep(10)
        else:
            time.sleep(0.4)
    else:
        # 不在游戏页 ⇒ 回游戏页
        tap(220, 2100, 2.5)
    # 每 5 轮换一次标签页（统计/设置）
    if int(el) % 60 < 20:
        tap(660, 2100, 2.0)     # 统计
        tap(1098, 2102, 2.0)    # 设置
        tap(220, 2100, 2.0)     # 回游戏

# ── 收尾 ──
p = pid()
rss = mem_kb(p)
with open(LOG, 'a', encoding='utf-8') as f:
    f.write('%s\t%.0f\t%d\t%.1f\t%s\t%s\n' % (time.strftime('%H:%M'), (time.time() - start) / 60, rss,
                                              rss / 1024.0 if rss > 0 else -1,
                                              '✅' if p else '🔴', '收尾'))
print('  ★ 长稳结束 ｜ 崩 %d 次 ｜ 卡死 %d 次' % (crashes, freezes), flush=True)
print('  数据表: %s' % LOG, flush=True)
