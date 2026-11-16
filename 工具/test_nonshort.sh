#!/bin/bash
# 测「isShort == false」那条从未被跑过的分支（判据 2807）。
#
# 原理：Bp.height 取自 display.getDefaultDisplaySync()，而 `hdc shell wm size`
#       能在运行时改显示尺寸 ⇒ 把屏幕改成「更高」，isShort() 就会变 false。
#
# 安全设计（三条硬要求）：
#   ① 先存原尺寸，**任何退出路径**都恢复（trap）
#   ② 改完先只 dump 一次，确认 board 尺寸真的变了，才继续测量
#   ③ 全程不写台账 —— 用 `--no-ledger` 或事后人工核对（避免污染唯一台账）
#
# 用法：
#   bash 工具/test_nonshort.sh                 # 只做第 ① 步：改尺寸 + dump 一次看通不通
#   bash 工具/test_nonshort.sh "Mental Mapping" "Color Maze Nav"   # 通了再测指定款

set -u
cd "$(dirname "$0")/.." || exit 1

HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
TARGET="${1:-}"
[ -z "$TARGET" ] && TARGET=""

echo "════ isShort==false 分支测试 $(date '+%H:%M') ════"

# ① 存原尺寸
ORIG=$("$HC" shell "wm size" 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+x[0-9]+' | head -1)
if [ -z "$ORIG" ]; then
  echo "❌ 读不到当前 wm size（设备没连？）"; exit 1
fi
echo "原尺寸: $ORIG"

restore() {
  echo "→ 恢复尺寸 $ORIG"
  "$HC" shell "wm size reset" >/dev/null 2>&1 || "$HC" shell "wm size $ORIG" >/dev/null 2>&1
  echo "→ 已恢复：$("$HC" shell 'wm size' 2>/dev/null | tr -d '\r' | tail -1)"
}
trap restore EXIT INT TERM

# ② 改成竖高的尺寸（让 Bp.height > 690）
NEW="1600x2560"
echo "改成: $NEW（目的：让 Bp.height > 690 ⇒ isShort() == false）"
"$HC" shell "wm size $NEW" >/dev/null 2>&1
sleep 3

echo
echo "── 第 ① 步：dump 一次，看 board 尺寸是否变化 ──"
python3 - <<'PY'
import os, subprocess, sys, re, time
HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
subprocess.run([HC, 'shell', 'aa', 'force-stop', 'com.andrewoscar.onemore'],
               capture_output=True, timeout=60)
subprocess.run([HC, 'shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.andrewoscar.onemore'],
               capture_output=True, timeout=60)
time.sleep(8)
p = '/data/local/tmp/ns.json'
subprocess.run([HC, 'shell', 'uitest', 'dumpLayout', '-p', p], capture_output=True, timeout=60)
out = subprocess.run([HC, 'shell', 'cat', p], capture_output=True, text=True, timeout=60).stdout
nums = re.findall(r'"bounds":\s*"\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', out)
if not nums:
    print('❌ dump 里没有 bounds'); sys.exit(1)
xs = [int(a[2]) for a in nums]; ys = [int(a[3]) for a in nums]
print('屏幕最大右边界: %d、最大下边界: %d' % (max(xs), max(ys)))
if max(ys) > 2000:
    print('✅ 尺寸已生效（下边界 > 2000）⇒ 可以用这个办法测 else 分支')
else:
    print('⚠️ 尺寸似乎没生效（下边界仍 ≈ %d）⇒ 换别的办法（建平板模拟器）' % max(ys))
PY

echo
if [ -n "$TARGET" ]; then
  echo "── 第 ② 步：测指定款（⚠️ shot_game 的搜索框坐标按 2560x1600 写死，可能进不去）──"
  for g in "$@"; do
    echo "→ $g"
    timeout 240 python3 工具/shot_game.py "$g" 2>&1 | tail -1 | cut -c1-120
  done
else
  echo "（未指定款 ⇒ 只验第 ① 步。通了再加款名重跑。）"
fi

echo
echo "════ 完（退出时自动恢复尺寸）════"
