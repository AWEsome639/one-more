#!/usr/bin/env bash
# ============================================================================
#  工具/measure_splash_fps.sh —— **开屏帧率 n≥3 复测**（判据 1507/1509/1510/1512）
#
#  ★ 为什么要有（第 1404 轮）
#    goal 待办涉及「开屏帧率」，而我上一轮从 **n=1** 推出了
#      「960×540 最慢，54.1% 的帧 > 20ms」
#    而实测：三份日志的 `frames` 行数 11/10/1 —— **去重后都是 1 条**
#      ⇒ 那是 `hilog -x` **重复 dump 同一条**，不是多次采样
#    ⇒ 判据 1507/1509：**n=1 不能立「谁最慢」的结论**
#
#  ★ 判据 1510：帧率结论需要 **n≥3 且极差 ≤ 3fps**
#
#  ★ 判据 1490（上一轮 A/B 失败的真因）：
#    **`aa start` 失败后必须重新 `aa start`**，而不是只查 `pidof`
#    ⇒ 本脚本的 START_APP() 显式重试
#
#  ★ 用法：bash 工具/measure_splash_fps.sh <设备名> [次数，默认 3]
#  输出：每轮的帧直方图 + fps 列表 + 极差
#  退出码：0 = n 次都拿到且极差 ≤ 3fps ｜ 1 = 有采样失败 ｜ 2 = 极差 > 3fps
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
DEV="${1:?用法: measure_splash_fps.sh <设备名> [次数]}"
N="${2:-3}"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
OUT="验收截图-v1.0.1/splash_fps_${DEV}_$(date +%Y%m%d)"
mkdir -p "$OUT"

ONLINE() { [ "$(timeout 6 "$HC" list targets 2>/dev/null | grep -c '127.0.0.1:5555')" -ge 1 ]; }
A() { ONLINE || return 1; timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }

# ★★★ 判据 1490：`aa start` 必须**本身**重试（不是只查 pidof）
START_APP() {
  local ok=0
  for TRY in 1 2 3 4 5; do
    A 'aa force-stop com.andrewoscar.onemore' >/dev/null 2>&1
    A 'power-shell wakeup' >/dev/null 2>&1
    sleep 3
    local out
    out="$(A 'aa start -b com.andrewoscar.onemore -a EntryAbility' 2>&1 | head -1)"
    # 每轮都查 pid（不早退）
    local pv=""
    for t in 4 5 7 9; do
      sleep "$t"
      pv="$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}')"
      printf '%s' "$pv" | grep -qE '^[0-9]+$' && break
    done
    if printf '%s' "$pv" | grep -qE '^[0-9]+$'; then
      echo "      第 $TRY 次 ⇒ pid [$pv] ✅" >&2
      ok=1
      return 0
    fi
    echo "      第 ${TRY} 次 ⇒ 未起来（${out}）" >&2
  done
  return 1
}

echo "════════ $DEV · 开屏帧率 n=$N 复测 ════════"
# ── 起机 ──
for X in onemore onemore2 onemore3 onemore4 onemore5 onemore6; do timeout 20 "$EMU" -stop "$X" >/dev/null 2>&1; done
sleep 20
printf 'y\ny\ny\ny\ny\ny\n' > /tmp/yes_fps.txt
nohup bash -c "\"$EMU\" -start \"$DEV\" < /tmp/yes_fps.txt" > /tmp/fps_boot.log 2>&1 &
ON=0
for i in $(seq 1 60); do
  sleep 10
  ONLINE && { echo "  在线 @ $((i*10))s"; ON=1; break; }
done
[ "$ON" != "1" ] && { echo "  🔴 未在线"; exit 1; }
timeout 6 "$HC" tconn 127.0.0.1:5555 >/dev/null 2>&1
# 等屏亮
for k in $(seq 1 12); do
  sleep 10
  rm -f /tmp/fpsb.png
  A "snapshot_display -w 200 -h 200 -t png -f /data/local/tmp/_fb.png" >/dev/null 2>&1
  timeout 12 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_fb.png /tmp/fpsb.png >/dev/null 2>&1
  L=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/fpsb.png'
print('%.0f' % np.array(Image.open(p).convert('RGB')).mean() if (os.path.exists(p) and os.path.getsize(p)>800) else '-1')
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${L:--1}')>20 else 1)" 2>/dev/null && { echo "  亮度 ${L}"; break; }
  A 'power-shell wakeup' >/dev/null 2>&1
done

echo "  装包…"
timeout 1200 "$HC" -t 127.0.0.1:5555 install -r "$HAP" > /tmp/fps_inst.log 2>&1
echo "  $(grep -oE 'msg:[^,]*' /tmp/fps_inst.log | head -1)"

echo
echo "  ── n=$N 轮冷启 ──"
for R in $(seq 1 "$N"); do
  echo "    第 $R 轮："
  # ★ 每次冷启前清 hilog（否则读到上一条）
  A 'hilog -r' >/dev/null 2>&1
  sleep 2
  START_APP || { echo "      🔴 起不来"; continue; }
  sleep 8   # 等开屏播完
  A 'hilog -x 2>/dev/null | grep -a "SplashDiag" | grep -a "frames"' > "$OUT/round_${R}.log" 2>&1
  A 'hilog -x 2>/dev/null | grep -a "SplashTiming"' > "$OUT/round_${R}_timing.log" 2>&1
  # 去重：同一行只留一条
  python3 - "$OUT/round_${R}.log" <<'PY' > "$OUT/round_${R}_uniq.txt" 2>/dev/null
import sys, re
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
seen = set()
for l in lines:
    m = re.search(r'frames\s+fast=\d+.*', l)
    if m and m.group(0) not in seen:
        seen.add(m.group(0))
        print(m.group(0))
PY
  NU=$(wc -l < "$OUT/round_${R}_uniq.txt" 2>/dev/null | tr -d ' ')
  echo "      去重后直方图: $NU 条"
  sed 's/^/        /' "$OUT/round_${R}_uniq.txt"
done

timeout 30 "$EMU" -stop "$DEV" >/dev/null 2>&1
echo
echo "  已 stop ｜ 产物: $OUT"
