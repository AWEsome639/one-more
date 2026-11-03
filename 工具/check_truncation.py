#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_truncation.py —— 元素"贴边/被切"检测器
================================================================
来历（第 897 轮）：
  判据 189 说「缩略图里看起来完整不是证据」——
  我在 420px 缩略图上判断「7 个分类都完整」，实际第 7 个已被切掉大半。
  ⇒ 目视在缩略图上不可靠。这件事应该交给一个能跑的检查器。

做什么：
  读 `uitest dumpLayout` 的 JSON，找出**右/左边界紧贴屏幕边缘**的文本节点。
  贴边 ⇒ 99% 是"被容器裁掉了"（真正的完整布局会留 padding）。

用法：
  # ① 从设备现抓
  python3 工具/check_truncation.py --device

  # ② 读已有 JSON
  python3 工具/check_truncation.py 工具/dump/xxx.json

  # ③ 指定容差（px，默认 8）
  python3 工具/check_truncation.py --tol 4 工具/dump/xxx.json

退出码（照判据 159：区分"被测对象坏了"和"尺子坏了"）：
  0 = 没有贴边元素（干净）
  1 = 发现贴边元素（真问题）
  2 = 环境不可用（读不到 dump / 设备不在）

判据：
  · 只检查**文本**节点（图片/容器贴边是正常的，比如全屏背景）
  · 贴边定义：|bounds.right - screenWidth| <= tol  或  bounds.left <= tol
  · 并且元素**确实有内容**（text 非空）—— 空容器贴边不算
"""
import json
import os
import re
import subprocess
import sys

HC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET = "127.0.0.1:5555"
TMP = "/data/local/tmp/trunc_probe.json"
LOCAL = "/tmp/trunc_probe.json"


def sh(args, timeout=40):
    try:
        r = subprocess.run(args, capture_output=True, timeout=timeout)
        return r.returncode, r.stdout.decode("utf-8", "replace")
    except Exception as e:
        return -1, str(e)


def grab_dump():
    """从设备抓一份 dumpLayout。返回 (ok, path_or_reason)"""
    rc, out = sh([HC, "-t", TARGET, "shell", "uitest dumpLayout -p " + TMP])
    if rc != 0 or "Fail" in out:
        return False, "dumpLayout 失败: " + out.strip()[:120]
    rc2, out2 = sh([HC, "-t", TARGET, "shell", "cat " + TMP])
    if rc2 != 0 or not out2.strip().startswith("{"):
        return False, "cat dump 失败（可能没生成）"
    with open(LOCAL, "w", encoding="utf-8") as f:
        f.write(out2.replace("\r", ""))
    return True, LOCAL


# ★ 194 条：清数据后会弹这些窗口，它们挡住真实界面 ⇒ 测量前必须先关掉
DIALOG_TEXTS = (
    "同意并继续", "同意", "查看全文", "隐私说明",
    "开始玩", "欢迎来到", "知道了", "跳过",
)


def find_dialog(texts):
    """返回当前页上第一个疑似弹窗按钮名；没有就返回 None。

    ★ 第 902 轮（判据 194）：`bm clean` 之后会弹「隐私说明」和欢迎卡。
      第一次在 440 上检查时，dump 到的是**弹窗下方**的元素
      ⇒ 报了"干净"，但量的是错的层 ⇒ **绿的也要怀疑**。
      所以测量前先查一遍。
    """
    for t in DIALOG_TEXTS:
        for x in texts:
            if x == t:
                return t
    return None


def parse_bounds(b):
    """'[60,831][195,922]' -> (60,831,195,922)"""
    m = re.findall(r"-?\d+", b or "")
    if len(m) < 4:
        return None
    return int(m[0]), int(m[1]), int(m[2]), int(m[3])


def collect(node, out, depth=0, in_scroll=False):
    """递归收集文本节点，并记录祖先里是否有可滚动容器。

    ★ 第 897 轮第二版：第一版把「滚动容器内的贴边」也报成裁切 ⇒ 一次误报两个。
      ⇒ 贴边 + 祖先不可滚动 = 真被切；贴边 + 有滚动祖先 = 正常滚动边界。
    ★ 注意：dump 里 `scrollable` 是**字符串** 'true'/'false'，不是布尔
      ⇒ 必须显式比较 `== 'true'`（`bool('false')` 是 True，会漏判）。
    """
    if isinstance(node, dict):
        a = node.get("attributes", {}) or {}
        t = (a.get("text") or "").strip()
        b = a.get("bounds") or ""
        # ★ 字符串比较
        sc_here = (a.get("scrollable") == "true")
        if t and b:
            r = parse_bounds(b)
            if r:
                out.append((t, r, depth, in_scroll))
        for v in node.values():
            if isinstance(v, (dict, list)):
                collect(v, out, depth + 1, in_scroll or sc_here)
    elif isinstance(node, list):
        for v in node:
            collect(v, out, depth, in_scroll)




def main():
    tol = 8
    args = sys.argv[1:]
    use_device = False
    path = None
    i = 0
    while i < len(args):
        if args[i] == "--device":
            use_device = True
        elif args[i] == "--tol" and i + 1 < len(args):
            tol = int(args[i + 1])
            i += 1
        elif not args[i].startswith("-"):
            path = args[i]
        i += 1

    if use_device:
        ok, res = grab_dump()
        if not ok:
            print("  ❌ 环境不可用：%s" % res)
            return 2
        path = res

    if not path:
        print("  用法: check_truncation.py [--device] [--tol 8] [<dump.json>]")
        return 2

    if not os.path.exists(path):
        print("  ❌ 环境不可用：文件不存在 %s" % path)
        return 2

    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except Exception as e:
        print("  ❌ 环境不可用：JSON 解析失败 %s" % e)
        return 2

    # 屏幕宽：取根节点 bounds 的右边
    root_b = parse_bounds(d.get("attributes", {}).get("bounds", ""))
    if not root_b:
        print("  ❌ 环境不可用：读不到根节点 bounds")
        return 2
    sw = root_b[2]
    sh_ = root_b[3]

    texts = []
    collect(d, texts)

    # ── 194 条守卫：当前是不是被弹窗挡着？ ──
    all_texts = [t for t, _r, _d, _s in texts]
    dlg = find_dialog(all_texts)
    if dlg is not None:
        print("  ⚠️ 当前页有弹窗（找到「%s」）⇒ **本帧不可用于判断**" % dlg)
        print("     先关掉弹窗（隐私说明 → 同意并继续；欢迎卡 → 开始玩），再重测。")
        return 2


    # 只看"中部之上、底部之上"的文本（去掉状态栏时钟那种本来就在边缘的）
    hits = []
    for t, (l, top, r, bot), dep, in_scroll in texts:
        if sw <= 0:
            continue
        # 跳过状态栏时间/电量（y < 6% 高度）
        if top < sh_ * 0.06:
            continue
        near_right = (sw - r) <= tol
        near_left = l <= tol
        if near_right or near_left:
            side = "右" if near_right else "左"
            hits.append((t, side, sw - r if near_right else l, (l, top, r, bot), dep, in_scroll))

    print("  dump: %s" % path)
    print("  屏幕: %d × %d px ｜ 容差 %d px ｜ 文本节点 %d 个" % (sw, sh_, tol, len(texts)))
    print()

    if not hits:
        print("  ✅ 没有贴边的文本节点（全部留有余量）")
        return 0

    true_hits = [h for h in hits if not h[5]]
    scroll_hits = [h for h in hits if h[5]]

    if scroll_hits:
        print("  ℹ️ %d 个贴边在**可滚动容器**内（正常，滚动边界）:" % len(scroll_hits))
        for t, side, gap, b, dep, _ in scroll_hits:
            print("     %s缘 %3dpx ｜ %-24s" % (side, gap, t[:24]))
        print()

    if not true_hits:
        print("  ✅ 没有**非滚动容器**内的贴边文本 ⇒ 干净")
        return 0

    print("  ⚠️ 发现 %d 个**非滚动容器**内的贴边文本（真被裁）:" % len(true_hits))
    true_hits.sort(key=lambda x: x[2])
    for t, side, gap, b, dep, _ in true_hits:
        print("     %s缘 %3dpx ｜ %-24s ｜ bounds=%s ｜ depth=%d"
              % (side, gap, t[:24], b, dep))
    print()
    print("  ⇒ 这些元素所在容器不滚动 ⇒ 贴边就是被裁，需要修布局。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
