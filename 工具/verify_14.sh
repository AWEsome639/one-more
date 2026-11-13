#!/bin/bash
# 2026-11-13：今晚待验收的 14 款（11 大卡降档 + 3 盘面限宽）
# 纪律（判据 1989）：装包前先看 `install bundle successfully`，看不到就停。
set -u
cd "$(dirname "$0")/.." || exit 1
HC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
HAP=entry/build/default/outputs/default/entry-default-signed.hap
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
LOG=/tmp/verify14.log
: > "$LOG"

target() {
  "$HC" list targets 2>/dev/null | head -1 | tr -d '[:space:]'
}

ensure() {
  # 2026-11-13 修 bug：原来 `ensure()` 把提示文字也 echo 出来了
  #   ⇒ `T=$(ensure)` 拿到的是「· 设备不在…\n127.0.0.1:5555」⇒ `install -t "$T"` 直接失败。
  #   ⇒ 现在提示只进 LOG，**stdout 只输出设备名**。
  local t; t=$(target)
  case "$t" in
    *Empty*|"")
      # 2026-11-13：`onemore` 今天冷启动失败多次（疑似损坏）⇒ 依次试 onemore3/4/5/6
      for inst in onemore3 onemore4 onemore5 onemore6; do
        echo "· 设备不在 ⇒ 起 $inst" >> "$LOG"
        (nohup "$EMU" -start "$inst" -noWindow > "/tmp/emu_$inst.log" 2>&1 &)
        sleep 300
        t=$(target)
        case "$t" in *Empty*|"") ;; *) break;; esac
        for p in $(ps aux | grep "[E]mulator -start" | awk '{print $2}'); do kill -9 $p 2>/dev/null; done
        sleep 5
      done;;
  esac
  printf '%s' "$t"
}

T=$(ensure)
case "$T" in *Empty*|"") echo "❌ 设备起不来" | tee -a "$LOG"; exit 1;; esac
echo "设备: $T" | tee -a "$LOG"

# ★ 判据 1996：**先确认实例是横屏** —— `onemore3` 是 1320x2232 竖屏，
#   在它上面测出来全是 NOT_HOME/DUMP_FAIL，白烧一小时。
RES=$(timeout 60 "$HC" -t "$T" shell "snapshot_display -f /data/local/tmp/_pre.jpeg" 2>&1 | grep -o 'width: [0-9]*, height: [0-9]*')
W=$(echo "$RES" | sed 's/.*width: \([0-9]*\).*/\1/')
H=$(echo "$RES" | sed 's/.*height: \([0-9]*\).*/\2/')
echo "屏幕: ${W}x${H}" | tee -a "$LOG"
if [ -n "$W" ] && [ -n "$H" ] && [ "$W" -lt "$H" ]; then
  echo "❌ [闸] 这个实例是**竖屏**（${W}x${H}），测量全部基于横屏 853x533 ⇒ 停。" | tee -a "$LOG"
  echo "   ⇒ 换 onemore / onemore4~6，或改实例配置。见 判据 1996。" | tee -a "$LOG"
  exit 1
fi

# 装包 —— 必须看到 successfully（判据 1989）
# 2026-11-13：`onemore3` 上可能没装过 App ⇒ `install -r` 会失败
#   ⇒ 先试 `-r`（替换），失败再试不带 `-r`（全新安装）
OUT=$("$HC" -t "$T" install -r "$HAP" 2>&1)
if ! echo "$OUT" | grep -q "install bundle successfully"; then
  echo "· -r 失败，改试全新安装" | tee -a "$LOG"
  OUT=$("$HC" -t "$T" install "$HAP" 2>&1)
fi
if ! echo "$OUT" | grep -q "install bundle successfully"; then
  echo "❌ [闸] 安装失败，停。输出：" | tee -a "$LOG"
  echo "$OUT" | tail -3 | tee -a "$LOG"
  exit 1
fi
echo "✅ 安装成功" | tee -a "$LOG"

BAD=0
for g in \
  "Spatial Conflict" "Stroop Number Size" "Temporal Order Judgment" \
  "Blink Detector" "Choice Reaction Time" "Stop Signal" "Topology" \
  "Ab Reversal Oddball" "Action Sequence Recall" "Card Counting Memory" "Venn Numbers" \
  "Cube Net Fold" "Spotlight Track" "Geometric Vision" ; do
  r=$(timeout 300 python3 工具/shot_game.py "$g" 2>&1 | tail -1 | cut -f1-4,6 | cut -c1-110)
  echo "$r" | tee -a "$LOG"
  # ★ 快速失败：NOT_HOME/DUMP_FAIL 是**环境问题**（设备不稳/方向错），不是某款的问题
  #   ⇒ 连续 2 次就整批停，别把 14 款 × 210s = 49 分钟全烧在同一个环境故障上
  case "$r" in
    *NOT_HOME*|*DUMP_FAIL*)
      BAD=$((BAD+1))
      if [ "$BAD" -ge 2 ]; then
        echo "❌ 连续 $BAD 款 NOT_HOME/DUMP_FAIL ⇒ 环境有问题，整批停（不是布局问题）" | tee -a "$LOG"
        exit 2
      fi;;
    *) BAD=0;;
  esac
  sleep 2
done
echo "DONE" | tee -a "$LOG"
