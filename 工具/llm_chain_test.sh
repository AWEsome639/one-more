#!/bin/bash
# 2026-11-13：端侧推理链路验证（MindSpore Lite）
#   目标：证明「rawfile → loadModelFromBuffer → predict → getData」这条链通。
#   通过判据：hilog 出现 `LLMTEST ok outputs=1 bytes=…`
set -u
cd "$(dirname "$0")/.." || exit 1
HC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
HAP=entry/build/default/outputs/default/entry-default-signed.hap
RAW=entry/src/main/resources/rawfile
MODEL=工具/models/mobilenetv2.ms
LOG=/tmp/llm_chain.log
: > "$LOG"

say() { echo "$*" | tee -a "$LOG"; }

# ① 模型就位
[ -f "$MODEL" ] || { say "❌ 缺模型：$MODEL（重下命令见 _巡检记录/端侧LLM换路线-20261113.md）"; exit 1; }
mkdir -p "$RAW"
cp -f "$MODEL" "$RAW/mobilenetv2.ms"
say "✅ 模型已放进 rawfile（$(du -h "$MODEL" | cut -f1)）"

# ② 编译
say "· 编译中（约 6~15 分钟）"
BUILD_STRICT=1 bash build.sh assembleHap >> "$LOG" 2>&1
if ! grep -q "BUILD SUCCESSFUL" "$LOG"; then say "❌ 编译失败，见 $LOG"; exit 1; fi
say "✅ 编译成功"

# ③ 设备
target() { "$HC" list targets 2>/dev/null | head -1 | tr -d '[:space:]'; }
T=$(target)
if [ -z "$T" ] || echo "$T" | grep -q Empty; then
  for inst in onemore3 onemore4 onemore5 onemore6; do
    say "· 起 $inst"
    (nohup "$EMU" -start "$inst" -noWindow > "/tmp/emu_$inst.log" 2>&1 &)
    sleep 300
    T=$(target)
    if [ -n "$T" ] && ! echo "$T" | grep -q Empty; then break; fi
  done
fi
echo "$T" | grep -q Empty && { say "❌ 设备起不来"; exit 1; }
say "设备: $T"

# ④ 装包（判据 1989：必须看到 successfully）
OUT=$("$HC" -t "$T" install -r "$HAP" 2>&1)
echo "$OUT" | grep -q "install bundle successfully" || OUT=$("$HC" -t "$T" install "$HAP" 2>&1)
if ! echo "$OUT" | grep -q "install bundle successfully"; then
  say "❌ 安装失败："; echo "$OUT" | tail -3 | tee -a "$LOG"; exit 1
fi
say "✅ 安装成功"

# ⑤ 触发自检
"$HC" -t "$T" shell "hilog -r" >/dev/null 2>&1
"$HC" -t "$T" shell "aa force-stop com.andrewoscar.onemore" >/dev/null 2>&1
sleep 3
"$HC" -t "$T" shell "aa start -a EntryAbility -b com.andrewoscar.onemore --ps selfTest true" >> "$LOG" 2>&1
sleep 25
say "── LLMTEST 日志 ──"
"$HC" -t "$T" shell "hilog -x | grep LLMTEST" 2>&1 | tee -a "$LOG" | tail -12

# ⑥ 清理：模型别留在包里（11MB，会撑大 HAP）
rm -f "$RAW/mobilenetv2.ms"
say "（已从 rawfile 移除模型；下次要测再跑本脚本）"
