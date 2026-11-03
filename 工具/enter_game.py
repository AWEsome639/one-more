#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把「进入某个游戏」这件反复出错的事封成一条命令。

来历（真机实测，两个晚上踩了两次）：
  · 点完分类 chip 立刻 dump ⇒ 列表还在加载，dump 里全是空的
  · 点完分类后向下连滚 6 屏 ⇒ 目标常在列表靠前，一滚就越过去

所以这里的顺序是固定写死的：
  ① 点分类 chip
  ② 等 3 秒
  ③ 向上滚回顶部（别假设已经在顶部）
  ④ dump 找目标；找不到就向下滚一小步（400px）再找
  ⑤ 找到就点，等 8 秒
  ⑥ 打印进入后的页面文字，并给出「提示」按钮坐标

用法：
  python3 工具/enter_game.py 整除冲刺 数字
  python3 工具/enter_game.py 数回 逻辑
  python3 工具/enter_game.py 数列堆叠 数字 --tap-hint

分类 chip 坐标（实测 1320×2232）：
  全部 228,1310 ｜ 经典 612,1310 ｜ 逻辑 996,1310 ｜ 数字 1266,1310
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV = "127.0.0.1:5555"
CHIPS = {"全部": (228, 1310), "经典": (612, 1310), "逻辑": (996, 1310), "数字": (1266, 1310)}
BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")
TMP = "/data/local/tmp/eg.json"
LOCAL = "/tmp/eg.json"


def shell(cmd, wait=True):
    r = subprocess.run([HDC, "-t", DEV, "shell", cmd], capture_output=True, text=True, timeout=90)
    return r.stdout


def dump():
    """dump 一次布局并拉回本地，返回 [(text, cx, cy, y1, y2)]"""
    shell(f"uitest dumpLayout -p {TMP}")
    subprocess.run([HDC, "-t", DEV, "file", "recv", TMP, LOCAL],
                   capture_output=True, text=True, timeout=90)
    if not os.path.exists(LOCAL):
        return []
    with open(LOCAL, encoding="utf-8") as f:
        data = json.load(f)
    rows = []

    def walk(node):
        if isinstance(node, dict):
            a = node.get("attributes") or {}
            t = (a.get("text") or "").strip()
            m = BOUNDS.match(a.get("bounds") or "")
            if m and t:
                x1, y1, x2, y2 = (int(g) for g in m.groups())
                rows.append((t, (x1 + x2) // 2, (y1 + y2) // 2, y1, y2))
            for c in node.get("children") or []:
                walk(c)

    walk(data)
    return rows


def find(rows, text, ymin=250, ymax=2290):   # ★ 边界放宽：有的游戏按钮在 y=2180 附近
    for t, cx, cy, y1, y2 in rows:
        if t == text and ymin < y1 < ymax:
            return cx, cy
    return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print("用法: enter_game.py <游戏名> [分类] [--tap-hint]")
        return 2
    name = args[0]
    chip = args[1] if len(args) > 1 else "全部"
    tap_hint = "--tap-hint" in sys.argv

    if chip not in CHIPS:
        print(f"  🔴 未知分类「{chip}」，可选：{list(CHIPS)}")
        return 2

    cx, cy = CHIPS[chip]
    print(f"  ══ 进入「{name}」（分类 {chip}）")
    shell(f"uitest uiInput click {cx} {cy}")
    time.sleep(3)                       # ② 列表要渲染

    for _ in range(4):                  # ③ 先滚回顶部
        shell("uitest uiInput swipe 660 1000 660 1900 400")
        time.sleep(0.5)
    time.sleep(1.5)

    pos = None
    for step in range(20):              # ④ 找目标（列表靠后的游戏要滚很多屏）
        rows = dump()
        pos = find(rows, name)
        if pos:
            print(f"     找到（第 {step} 屏）：{pos}")
            break
        shell("uitest uiInput swipe 660 1750 660 1350 400")   # 只滚一小步
        time.sleep(1.2)

    if not pos:
        print(f"  🔴 20 屏内没找到「{name}」")
        return 1

    shell(f"uitest uiInput click {pos[0]} {pos[1]}")
    time.sleep(8)

    rows = dump()
    titles = [r[0] for r in rows[:8]]
    print("     进入后界面：" + " / ".join(t[:14] for t in titles))

    hit = find(rows, "提示")
    if hit:
        print(f"     提示按钮：{hit}")
        if tap_hint:
            before = {t for t, *_ in rows}
            shell(f"uitest uiInput click {hit[0]} {hit[1]}")
            time.sleep(0.6)          # ★ toast 生命很短，2 秒就没了（踩过）
            after = dump()
            # ★ 用「点击前后的差集」找 toast，不要靠关键词猜 —— 我在这上面错过四次
            # ★ 但状态栏时钟每分钟变化也会混进来，用正则排掉
            clock = re.compile(r"^[\d,\s:]+$")
            fresh = [t for t, *_ in after
                     if t not in before and len(t) >= 6 and not clock.match(t)]
            print("     点提示后：" + (fresh[-1][:90] if fresh else "（没有新文字）"))
    else:
        print("     🔴 没找到「提示」按钮")

    return 0


if __name__ == "__main__":
    sys.exit(main())
