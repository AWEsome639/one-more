#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sweep_truncation.py —— 批量扫游戏的"贴边/被裁"检测
================================================================
来历（第 899 轮）：
  `check_truncation.py` 单次只能测当前页面。
  要覆盖多款游戏，需要"进游戏 → 测 → 退出 → 下一款"的循环。
  手动做 20 款要 7 分钟且容易漏，所以写成脚本。

做什么：
  按给定的游戏名列表，依次：
    ① 回列表（必要时 force-stop 重开）
    ② 点卡片进游戏
    ③ 跑 check_truncation（只看游戏页）
    ④ 返回列表
  每款输出一行，最后给汇总。结果同时写 JSONL。

用法：
  python3 工具/sweep_truncation.py                      # 用内置样本
  python3 工具/sweep_truncation.py --games 宝石迷阵 2048
  python3 工具/sweep_truncation.py --list 工具/sweep_sample.txt
  python3 工具/sweep_truncation.py --out /tmp/sweep.jsonl

退出码：
  0 = 全部干净
  1 = 有款报贴边（真问题）
  2 = 环境不可用（设备不在 / 起不来）
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
HC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET = "127.0.0.1:5555"
PKG = "com.andrewoscar.onemore"

# 跨 6 分类的默认样本（每类 3 款 = 18 款）
DEFAULT_SAMPLE = [
    # 经典
    "宝石迷阵", "打砖块", "跳棋",
    # 逻辑
    "数独", "数桥", "明灯",
    # 数字
    "2048", "24 点", "数回",
    # 记忆
    "连续配对", "图案锁", "数蛇",
    # 文字
    "单词接龙", "字母换位", "猜词",
    # 空间
    "经典迷宫", "七巧板", "汉诺塔",
]


def sh(args, timeout=45):
    try:
        r = subprocess.run(args, capture_output=True, timeout=timeout)
        return r.returncode, r.stdout.decode("utf-8", "replace")
    except Exception as e:
        return -1, str(e)


def dev(cmd, timeout=45):
    return sh([HC, "-t", TARGET, "shell", cmd], timeout)


def device_ok():
    rc, out = dev("echo OK")
    return rc == 0 and "OK" in out


def dump_rows():
    """返回 [(text, x, y)] —— 复用项目里已有的解析器"""
    sys.path.insert(0, HERE)
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "vb", os.path.join(HERE, "verify_batch.py"))
        vb = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(vb)
        return vb.dump()
    except Exception:
        return []


# 已知卡片名（用来判"是否在列表页"）
KNOWN_CARDS = (
    "宝石迷阵", "打砖块", "弹珠消", "跳棋", "复合连线", "四子棋",
    "2048", "24 点", "9 路围棋", "五子棋", "汉诺塔", "迷你数谜",
    "生命游戏", "图案锁", "双重麻烦", "双镜像", "穿云", "空当接龙",
)


def on_list_page():
    """在列表页的判据。

    ★ 第 899 轮踩了两次：
      ① 一开始用 `"款小游戏" in texts` 判 —— 那个文本在顶部、
         **不在 dump 里**（被 Grid 滚动位置推走）⇒ 永远判"不在列表页"。
      ② 再改成「有『全部』+ 有卡片名」—— 但**滚到第二屏就没有「全部」了**
         （分类条被滚出去）⇒ 又误判。
      ⇒ 最终判据：**只要 dump 里出现任一已知卡片名，就是在列表页。**
         （游戏页不会有这些卡片名，所以不会误判成"在列表页"。）
    """
    rows = dump_rows()
    texts = [str(r[0]) for r in rows]
    return any(t in KNOWN_CARDS for t in texts)


def ensure_list_page():
    """确保停在游戏列表页。不是就启动 app + 关欢迎卡 + 切到「游戏」页。"""
    if on_list_page():
        print("  （已在列表页）")
        return True

    # ★ 可能 app 没运行（被 Back 退了）⇒ 先无条件启动一次
    rc, pid = dev("pidof " + PKG)
    if not pid.strip():
        dev("aa start -b " + PKG + " -a EntryAbility")
        time.sleep(18)
        click_text("开始玩")
        time.sleep(2.5)
        if on_list_page():
            print("  （重开后已在列表页）")
            return True
    # 没在列表页 ⇒ 启动
    dev("power-shell wakeup")
    time.sleep(1.2)
    dev("aa start -b " + PKG + " -a EntryAbility")
    time.sleep(18)
    click_text("开始玩")          # 关欢迎卡（有就关）
    time.sleep(2.5)
    # 切到「游戏」标签（找不到就说明已经在列表页）
    if not on_list_page():
        if click_text("游戏", exact=True):
            time.sleep(2.5)
    return on_list_page()


def find_card(name, max_screens=12):
    """在列表里找卡片。

    ★ 第 900 轮修正两个错：
      ① **`uitest uiInput` 没有 `inputText` 子命令**
         （官方帮助只有 dircFling / click / doubleClick / longClick /
           swipe / drag / fling / keyEvent）
         ⇒ 第 899 轮写的"用搜索框定位"整条路是**死的**，
           那行 `inputText` 只是静默失败，白白浪费 4 秒。
      ② 兜底只滚 4 次 ≈ 2000px，而 355 款 = 30 屏 ⇒ 第二屏之后就找不到。
         ⇒ 改成最多滚 `max_screens` 屏，并在找不到时先回顶再扫一遍。

    ★ 用 `dircFling down` 而不是 `swipe`：fling 是惯性翻页，
      一屏一次更接近用户操作，也比长距离 swipe 更稳。
    """
    if click_text(name):
        return True

    # ① 回顶部（列表可能停在中途）
    dev("uitest uiInput dircFling 2 3000")
    time.sleep(1.0)
    dev("uitest uiInput dircFling 2 3000")
    time.sleep(1.2)
    if click_text(name):
        return True

    # ② 一屏一屏往下翻
    for _ in range(max_screens):
        dev("uitest uiInput dircFling 3 2500")     # 3 = down
        time.sleep(1.0)
        if click_text(name):
            return True
    return False


def click_text(name, exact=True):
    rows = dump_rows()
    for r in rows:
        t = str(r[0])
        if (t == name) if exact else (name in t):
            dev("uitest uiInput click %d %d" % (int(r[1]), int(r[2])))
            return True
    return False


def back_to_list():
    """从游戏页回到列表：优先「返回列表」按钮，否则 Back 键，再不行重开"""
    for attempt in range(3):
        if click_text("返回列表"):
            time.sleep(2.0)
            return True
        dev("uitest uiInput keyEvent 2")   # Back
        time.sleep(2.2)
        if on_list_page():
            return True
    # 兜底：重开 app
    dev("aa force-stop " + PKG)
    time.sleep(1.5)
    dev("aa start -b " + PKG + " -a EntryAbility")
    time.sleep(16)
    # 关欢迎卡
    click_text("开始玩")
    time.sleep(2)
    return True


def check_current():
    """对当前页跑 check_truncation，返回 (code, brief)"""
    rc, out = sh([sys.executable,
                  os.path.join(HERE, "check_truncation.py"), "--device"], timeout=60)
    brief = ""
    for line in out.splitlines():
        if "⚠️ 发现" in line or "非滚动容器" in line:
            brief = line.strip()
            break
    if not brief:
        for line in out.splitlines():
            if "缘" in line and "px" in line:
                brief = line.strip()
                break
    return rc, brief


def main():
    games = list(DEFAULT_SAMPLE)
    out_path = "/tmp/sweep_truncation.jsonl"
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--games":
            games = []
            i += 1
            while i < len(args) and not args[i].startswith("-"):
                games.append(args[i])
                i += 1
            continue
        elif args[i] == "--list" and i + 1 < len(args):
            with open(args[i + 1], encoding="utf-8") as f:
                games = [l.strip() for l in f if l.strip() and not l.startswith("#")]
            i += 1
        elif args[i] == "--out" and i + 1 < len(args):
            out_path = args[i + 1]
            i += 1
        i += 1

    if not device_ok():
        print("  ❌ 环境不可用：设备不在线")
        return 2

    if not ensure_list_page():
        print("  ❌ 环境不可用：起不来 / 停不到列表页")
        return 2

    print("  批量扫描 %d 款" % len(games))
    print("  输出: %s" % out_path)
    print()

    results = []
    fh = open(out_path, "w", encoding="utf-8")
    for idx, g in enumerate(games, 1):
        rec = {"seq": idx, "game": g, "entered": False, "code": None, "brief": ""}
        if not find_card(g):
            rec["brief"] = "卡片未找到"
            print("  %2d/%d  %-10s  ⚠️ 卡片未找到" % (idx, len(games), g))
        else:
            rec["entered"] = True
            time.sleep(6.5)                      # 等演示/首帧稳定
            code, brief = check_current()
            rec["code"] = code
            rec["brief"] = brief
            mark = "✅" if code == 0 else ("⚠️" if code == 1 else "❓")
            print("  %2d/%d  %-10s  %s exit=%d  %s"
                  % (idx, len(games), g, mark, code, brief[:60]))
        results.append(rec)
        fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
        fh.flush()
        back_to_list()
        time.sleep(1.2)
    fh.close()

    bad = [r for r in results if r["code"] == 1]
    env = [r for r in results if r["code"] == 2]
    ok = [r for r in results if r["code"] == 0]
    miss = [r for r in results if not r["entered"]]

    print()
    print("  ─────────────────────────────────────")
    print("  干净 %d ｜ 贴边 %d ｜ 环境失败 %d ｜ 未进入 %d ｜ 共 %d"
          % (len(ok), len(bad), len(env), len(miss), len(games)))
    if bad:
        print("  ⚠️ 报贴边的款:")
        for r in bad:
            print("     %s  %s" % (r["game"], r["brief"][:70]))
    if env:
        print("  ❓ 环境不可用（不计入结论）:")
        for r in env:
            print("     %s" % r["game"])

    if miss and len(miss) == len(games):
        print("  ❌ 全部未找到卡片 ⇒ 可能不在列表页")
        return 2
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
