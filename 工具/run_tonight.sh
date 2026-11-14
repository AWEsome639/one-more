#!/bin/bash
# 今晚开窗的**编排脚本**：把六步串起来，每步打检查点。
# 用法：bash 工具/run_tonight.sh            # 全流程
#       bash 工具/run_tonight.sh --check    # 只做前四步（不启跑批）
#
# ⚠️ 每步失败即停、并打印「卡在哪一步」，不静默继续。
#
# ⚠️⚠️ 必须**后台跑**：第 5 步 sweep_all 要 6.75 小时，同步调用会被超时杀掉。
#   ⇒ 用 `run_in_background`，或 `nohup bash 工具/run_tonight.sh > /tmp/tonight.log 2>&1 &`
#   ⇒ 起来后 5 分钟内 `tail -5 /tmp/tonight.log` 确认已过第 1–2 步（十项 + 停 Colima）
#   ⇒ 之后每 30–60 分钟 `tail -3` 看进度；`/tmp/sweep_all.log` 是跑批自己的日志

set -u
cd "/Users/a0000/dev/One More" || exit 1
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
HAP='entry/build/default/outputs/default/entry-default-signed.hap'
step() { echo; echo "════ 第 $1 步：$2 ════"; }
fail() { echo "❌ 卡在第 $1 步：$2"; echo "⇒ 停。不要跳过、不要盲改脚本。"; exit 1; }

step 1 'final_check（十项）'
bash 工具/final_check.sh > /tmp/tonight_final.log 2>&1 || fail 1 'final_check 未过（看 /tmp/tonight_final.log）'
grep -E '全部就绪' /tmp/tonight_final.log || fail 1 'final_check 没打「全部就绪」'
echo '✅ 十项通过'

step 2 '停 Colima（它抢 CPU/内存/磁盘）'
if pgrep -x limactl >/dev/null 2>&1; then
  colima stop 2>&1 | tail -2 || true
fi
echo "✅ Colima 状态：$(pgrep -x limactl >/dev/null 2>&1 && echo '仍在' || echo '已停')"

step 3 '起模拟器 onemore7'
"$EMU" -a onemore7 > /tmp/tonight_emu.log 2>&1 &
echo '⇒ 等满 180 秒（判据 1949：模拟器启动要等满，不是等看到界面）'
sleep 180

step 4 '装包（必须见 install bundle successful）'
[ -f "$HAP" ] || fail 4 "HAP 不存在：$HAP ⇒ 先编译"
INS=$("$HC" install -r "$HAP" 2>&1)
echo "$INS" | tail -3
echo "$INS" | grep -qi 'successful' || fail 4 '没看到 install bundle successful'
echo '✅ 装包成功'
bash 工具/preflight_install.sh || fail 4 'preflight_install 未过（设备上的包不是这个 HAP）'
echo '✅ 设备上是新包'

if [ "${1:-}" = '--check' ]; then
  echo; echo '==== --check 模式：前四步全过，不启跑批 ===='; exit 0
fi

step 5 '跑批（06:45 自停）'
echo '⇒ 若中途崩了要重启：cp /tmp/sweep_all.log "/tmp/sweep_all-$(date +%H%M)-崩前.log"'
bash 工具/sweep_all.sh

step 6 '跑完出报告'
_T=$(date +%Y-%m-%d); _Y=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
NEW=$(grep -cE "^($_T|$_Y)" _巡检记录/layout-canonical.tsv 2>/dev/null || echo 0)
echo "⇒ 本次新增行数（含跨零点）：$NEW（期望 215–221；若为 0 先查 HAP 与 BASELINE，别先查模拟器）"
python3 工具/morning_report.py
