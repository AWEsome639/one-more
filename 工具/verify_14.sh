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
      echo "· 设备不在 ⇒ 起 onemore3（onemore 疑似损坏）" >> "$LOG"
      (nohup "$EMU" -start onemore3 -noWindow > /tmp/emu_verify.log 2>&1 &)
      sleep 300
      t=$(target);;
  esac
  printf '%s' "$t"
}

T=$(ensure)
case "$T" in *Empty*|"") echo "❌ 设备起不来" | tee -a "$LOG"; exit 1;; esac
echo "设备: $T" | tee -a "$LOG"

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

for g in \
  "Spatial Conflict" "Stroop Number Size" "Temporal Order Judgment" \
  "Blink Detector" "Choice Reaction Time" "Stop Signal" "Topology" \
  "Ab Reversal Oddball" "Action Sequence Recall" "Card Counting Memory" "Venn Numbers" \
  "Cube Net Fold" "Spotlight Track" "Geometric Vision" ; do
  r=$(timeout 300 python3 工具/shot_game.py "$g" 2>&1 | tail -1 | cut -f1-4,6 | cut -c1-110)
  echo "$r" | tee -a "$LOG"
  sleep 2
done
echo "DONE" | tee -a "$LOG"
