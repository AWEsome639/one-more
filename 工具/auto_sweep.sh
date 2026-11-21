#!/bin/bash
# auto_sweep.sh —— 自动跑竖屏抽样：每轮「重启模拟器 → 测 N 款 → 扫 cov」，直到剩余为 0 或达到轮数上限
# 用法：bash 工具/auto_sweep.sh [轮数=8] [每轮款数=12]
set -u
cd "/Users/a0000/dev/One More" || exit 1
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
ROUNDS=${1:-8}
PER=${2:-12}
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk

for r in $(seq 1 "$ROUNDS"); do
  left=$(python3 工具/pick_untested.py 1 2>/dev/null | grep -oE '剩 [0-9]+' | awk '{print $2}')
  [ -z "$left" ] && left=9999
  echo "=== 第 $r 轮（剩 $left 款）$(date '+%H:%M:%S') ==="
  [ "$left" -eq 0 ] && { echo "全部测完"; break; }

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
  if [ "$ok" -ne 1 ]; then echo "  模拟器起不来，跳过本轮"; continue; fi
  "$HDC" shell "power-shell wakeup" >/dev/null 2>&1
  sleep 1
  "$HDC" shell "uitest uiInput swipe 1112 2000 1112 600 300" >/dev/null 2>&1
  sleep 1

  DSH_EMU_INST=onemore_fold SHOT_SCREEN_W=2224 SHOT_SCREEN_H=2496 \
  SHOT_GAME_BOTTOM=2412 SHOT_GESTURE=2480 \
    timeout 1200 python3 工具/verify_layout.py --names-file /tmp/todo.txt > "/tmp/sweep_$r.log" 2>&1
  echo "  本轮跑完 $(grep -cE '^\[' "/tmp/sweep_$r.log" 2>/dev/null) 款"
  python3 工具/detect_bottom_clip.py --today 2>/dev/null | tail -3
done
echo "=== 结束 $(date '+%H:%M:%S') ==="
python3 工具/pick_untested.py 1 2>/dev/null | head -1
