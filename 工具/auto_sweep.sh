#!/bin/bash
# auto_sweep.sh —— 全功率竖屏抽样：模拟器能复用就复用，内存紧就等，直到测完
# 用法：bash 工具/auto_sweep.sh [轮数=999] [每轮款数=12] [swap阈值%=96]
set -u
cd "/Users/a0000/dev/One More" || exit 1
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
ROUNDS=${1:-999}
PER=${2:-12}
SWAP_MAX=${3:-96}
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk

swap_pct() {
  u=$(sysctl vm.swapusage 2>/dev/null | sed -nE 's/.*used = ([0-9.]+)M.*/\1/p' | awk '{printf "%d", $1}')
  t=$(sysctl vm.swapusage 2>/dev/null | sed -nE 's/.*total = ([0-9.]+)M.*/\1/p' | awk '{printf "%d", $1}')
  [ -z "${u:-}" ] || [ -z "${t:-}" ] || [ "$t" -eq 0 ] && { echo 0; return; }
  echo $((u * 100 / t))
}

clean_orphans() { pkill -9 -f "verify_layout" 2>/dev/null; pkill -9 -f "shot_game" 2>/dev/null; sleep 1; }

alive() { "$HDC" shell "echo ok" 2>/dev/null | grep -q ok; }

ensure_emu() {
  "$HDC" tconn 127.0.0.1:5555 >/dev/null 2>&1
  alive && return 0
  echo "  模拟器不在，重启…"
  for p in $(pgrep -f "mulator -start"); do kill -9 "$p" 2>/dev/null; done
  sleep 2
  nohup "$EMU" -start onemore_fold -noWindow > /tmp/sweep_emu.log 2>&1 &
  for i in $(seq 1 20); do
    sleep 6
    "$HDC" tconn 127.0.0.1:5555 >/dev/null 2>&1
    alive && { echo "  ✅ 模拟器就绪(+$((i*6))s)"; return 0; }
  done
  return 1
}

for r in $(seq 1 "$ROUNDS"); do
  left=$(python3 工具/pick_untested.py 1 2>/dev/null | grep -oE '剩 [0-9]+' | awk '{print $2}')
  [ -z "$left" ] && left=9999
  echo "=== 第 $r 轮（剩 $left 款）$(date '+%H:%M:%S') ==="
  [ "$left" -eq 0 ] && { echo "✅ 全部测完"; break; }

  # 内存闸：等，不跳过
  for w in 1 2 3 4 5 6; do
    pct=$(swap_pct)
    echo "  swap ${pct}%"
    [ "$pct" -lt "$SWAP_MAX" ] && break
    echo "  ⛔ 太紧，等 120 秒（第 $w 次）"; sleep 120
  done

  clean_orphans
  if ! ensure_emu; then echo "  ⛔ 模拟器起不来，等 90 秒重试"; sleep 90; ensure_emu || { echo "  跳过本轮"; continue; }; fi
  "$HDC" shell "power-shell wakeup" >/dev/null 2>&1
  sleep 1
  "$HDC" shell "uitest uiInput swipe 1112 2000 1112 600 300" >/dev/null 2>&1
  sleep 1

  python3 工具/pick_untested.py "$PER" 2>/dev/null | tail -1
  DSH_EMU_INST=onemore_fold SHOT_SCREEN_W=2224 SHOT_SCREEN_H=2496 \
  SHOT_GAME_BOTTOM=2412 SHOT_GESTURE=2480 \
    timeout 1500 python3 工具/verify_layout.py --names-file /tmp/todo.txt > "/tmp/sweep_$r.log" 2>&1
  echo "  本轮跑完 $(grep -cE '^\[' "/tmp/sweep_$r.log" 2>/dev/null) 款"
  python3 工具/detect_bottom_clip.py --today 2>/dev/null | tail -3
  clean_orphans
done
echo "=== 结束 $(date '+%H:%M:%S') ==="
python3 工具/pick_untested.py 1 2>/dev/null | head -1
