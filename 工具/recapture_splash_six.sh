#!/usr/bin/env bash
# ============================================================================
#  工具/recapture_splash_six.sh —— 六尺寸开屏证据一键重拍
#
#  为什么要有它（判据 953）：
#    改 `Splash.ets` 一行 ⇒ **24 条开屏证据的 hash 全部失效**
#    ⇒ 必须重拍六个尺寸并重新盖章
#    ⇒ 而这是「六轮设备启动 + 六次装机 + 六次连拍」——
#      手工做必然漏步骤 ⇒ 固化成脚本
#
#  用法：bash 工具/recapture_splash_six.sh [延时秒]
#  输出：验收截图-v1.0.1/SPLASH_TERMINAL_<W>x<H>.png（六个）
#        并调用 stamp_splash_evidence.py 盖章
# ============================================================================
set -u
DELAY="${1:-2}"
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
OUT="验收截图-v1.0.1"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"

SIZES=("onemore:853x533" "onemore2:800x1280" "onemore3:440x744" \
       "onemore4:233x233" "onemore5:960x540" "onemore6:195x195")

mkdir -p /tmp/splash_recap
echo "════════════════════════════════════════════════════════════"
echo "  六尺寸开屏重拍（改 Splash.ets 后必须做，判据 953）"
echo "════════════════════════════════════════════════════════════"

for pair in "${SIZES[@]}"; do
  INST="${pair%%:*}"
  SIZE="${pair##*:}"
  echo ""
  echo "── ${INST}（${SIZE}）──────────────────────────────────────────"

  # ① 启动（复用现成脚本，它负责解锁 + 验证桌面 + 启动 app）
  OUT_S=$(bash 工具/start_app_on_device.sh "$INST" 2>&1)
  RC=$?
  if [ "$RC" != "0" ]; then
    echo "  ⚠️ 第一次启动失败，重试：$(echo "$OUT_S" | tail -1)"
    sleep 15
    OUT_S=$(bash 工具/start_app_on_device.sh "$INST" 2>&1); RC=$?
  fi
  if [ "$RC" != "0" ]; then
    echo "  🔴 $INST 启动失败，跳过"
    for X in $(ps aux | grep '[E]mulator' | grep -v grep | awk '{print $2}'); do
      kill -TERM "$X" 2>/dev/null
    done
    sleep 5
    continue
  fi
  echo "  ✅ 启动（"$(echo "$OUT_S" | tail -1 | tr -d '\r')"）"

  # ② 装机
  timeout 900 $HC -t 127.0.0.1:5555 install -r "$HAP" > /tmp/splash_recap/i_$INST.log 2>&1
  echo "  $(grep -oE 'msg:[^,]*' /tmp/splash_recap/i_$INST.log 2>/dev/null | head -1 | cut -c1-40)"

  # ③ 连拍（capture_splash.sh 自带 force-stop + 解锁 + 连拍 + 选帧）
  bash 工具/capture_splash.sh "$SIZE" 20 "$DELAY" > /tmp/splash_recap/c_$INST.log 2>&1
  echo "  $(tail -3 /tmp/splash_recap/c_$INST.log | tr '\n' ' ' | cut -c1-150)"

  # ④ 收产物
  if [ -f "/tmp/splash_${SIZE}_final.png" ]; then
    cp "/tmp/splash_${SIZE}_final.png" "$OUT/SPLASH_TERMINAL_${SIZE}.png"
    echo "  ✅ ⇒ $OUT/SPLASH_TERMINAL_${SIZE}.png（$(stat -f%z "$OUT/SPLASH_TERMINAL_${SIZE}.png" 2>/dev/null) 字节）"
  else
    echo "  🔴 没拿到 /tmp/splash_${SIZE}_final.png"
    ls /tmp/_c${SIZE}_*.png 2>/dev/null | head -3 | sed 's/^/      候选: /'
  fi

  # ⑤ 停设备（只能 kill -TERM，绝不 pkill -9）
  for X in $(ps aux | grep '[E]mulator' | grep -v grep | awk '{print $2}'); do
    kill -TERM "$X" 2>/dev/null
  done
  sleep 6
  timeout 8 $HC kill -r >/dev/null 2>&1
  echo "  （设备已停）"
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  六张是否都拿到"
echo "════════════════════════════════════════════════════════════"
OK=0
FILES=()
for pair in "${SIZES[@]}"; do
  SIZE="${pair##*:}"
  F="$OUT/SPLASH_TERMINAL_${SIZE}.png"
  if [ -f "$F" ]; then
    echo "  ✅ $SIZE"
    OK=$((OK+1))
    FILES+=("$F")
  else
    echo "  🔴 $SIZE 缺失"
  fi
done
echo "  ⇒ $OK / 6"

if [ "$OK" -ge 1 ]; then
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  盖章（绑到当前 Splash.ets 哈希）"
  echo "════════════════════════════════════════════════════════════"
  python3 工具/stamp_splash_evidence.py "${FILES[@]}" 2>&1 | tail -12 | sed 's/^/  /'
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  复查"
echo "════════════════════════════════════════════════════════════"
python3 工具/check_splash.py > /tmp/splash_recap/check.log 2>&1
echo "  check_splash 退出码: $?"
tail -14 /tmp/splash_recap/check.log | sed 's/^/  /'
