#!/bin/bash
# auto_sweep.sh —— 自动跑竖屏抽样：每轮「查内存 → 清孤儿 → 起模拟器 → 测 N 款 → 扫 cov」
#
# 判据 3107（这次加的）：
#   ① 起模拟器前先查 swap，太紧就等（这台机器 swap 用完时 jetsam 直接 Killed: 9）
#   ② 每轮开始先杀孤儿 verify_layout/shot_game（"杀父不杀子"，判据 3013）
#   ③ 每轮结束再清一次，避免上一轮的子进程拖累下一轮
#
# 用法：bash 工具/auto_sweep.sh [轮数=8] [每轮款数=12] [swap 阈值% =92]
set -u
cd "/Users/a0000/dev/One More" || exit 1
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
ROUNDS=${1:-8}
PER=${2:-12}
SWAP_MAX=${3:-92}
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk

swap_pct() {
  sysctl vm.swapusage 2>/dev/null | sed -nE 's/.*used = ([0-9.]+)M.*/\1/p' | awk '{printf "%d", $1}'
}
swap_total() {
  sysctl vm.swapusage 2>/dev/null | sed -nE 's/.*total = ([0-9.]+)M.*/\1/p' | awk '{printf "%d", $1}'
}

clean_orphans() {
  pkill -9 -f "verify_layout" 2>/dev/null
  pkill -9 -f "shot_game" 2>/dev/null
  sleep 1
}

for r in $(seq 1 "$ROUNDS"); do
  left=$(python3 工具/pick_untested.py 1 2>/dev/null | grep -oE '剩 [0-9]+' | awk '{print $2}')
  [ -z "$left" ] && left=9999
  echo "=== 第 $r 轮（剩 $left 款）$(date '+%H:%M:%S') ==="
  [ "$left" -eq 0 ] && { echo "全部测完"; break; }

  # ① 内存闸
  used=$(swap_pct); total=$(swap_total)
  if [ -n "$used" ] && [ -n "$total" ] && [ "$total" -gt 0 ]; then
    pct=$((used * 100 / total))
    echo "  swap ${used}M/${total}M = ${pct}%"
    if [ "$pct" -ge "$SWAP_MAX" ]; then
      echo "  ⛔ 超过 ${SWAP_MAX}%，等 120 秒再试"
      sleep 120
      used=$(swap_pct); pct=$((used * 100 / total))
      if [ "$pct" -ge "$SWAP_MAX" ]; then echo "  仍然太紧，跳过本轮"; continue; fi
    fi
  fi

  # ② 清孤儿
  clean_orphans

  python3 工具/pick_untested.py "$PER" 2>/dev/null | tail -1

  "$EMU" -stop onemore_fold >/dev/null 2>&1
  sleep 2
  for p in $(pgrep -f "mulator -start"); do kill -9 "$p" 2>/dev/null; done
  sleep 2
  nohup "$EMU" -start onemore_fold -noWindow > /tmp/sweep_emu.log 2>&1 &
  ok=0
  for i in $(seq 1 16); do
    sleep 6
    "$HDC" tconn 127.0.0.1:5555 >/dev/null 2>&1
    if "$HDC" shell "echo ok" 2>/dev/null | grep -q ok; then ok=1; break; fi
  done
  if [ "$ok" -ne 1 ]; then echo "  模拟器起不来，跳过本轮"; clean_orphans; continue; fi
  "$HDC" shell "power-shell wakeup" >/dev/null 2>&1
  sleep 1
  "$HDC" shell "uitest uiInput swipe 1112 2000 1112 600 300" >/dev/null 2>&1
  sleep 1

  DSH_EMU_INST=onemore_fold SHOT_SCREEN_W=2224 SHOT_SCREEN_H=2496 \
  SHOT_GAME_BOTTOM=2412 SHOT_GESTURE=2480 \
    timeout 1200 python3 工具/verify_layout.py --names-file /tmp/todo.txt > "/tmp/sweep_$r.log" 2>&1
  echo "  本轮跑完 $(grep -cE '^\[' "/tmp/sweep_$r.log" 2>/dev/null) 款"
  python3 工具/detect_bottom_clip.py --today 2>/dev/null | tail -3

  # ③ 轮末清孤儿
  clean_orphans
done
echo "=== 结束 $(date '+%H:%M:%S') ==="
python3 工具/pick_untested.py 1 2>/dev/null | head -1
