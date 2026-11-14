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
# ★ 单实例锁：launchd 定时与手工执行可能撞车 ⇒ 只允许一个实例
LOCK=/tmp/onemore_nightrun.lock
if [ -e "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  echo "❌ 已有实例在跑（PID $(cat "$LOCK")）⇒ 退出，避免两个跑批同时动设备"
  exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
HAP='entry/build/default/outputs/default/entry-default-signed.hap'
step() { echo; echo "════ [$(date '+%H:%M:%S')] 第 $1 步：$2 ════"; }
fail() { echo "❌ 卡在第 $1 步：$2"; echo "⇒ 停。不要跳过、不要盲改脚本。"; exit 1; }

# ★ 记台账基线：明早 morning_check.sh 用它算「今晚新增多少行」
#   ⚠️ 不能用 `wc … | tr > f || echo 0 > f`：管道退出码取最后一条命令（tr 成功）⇒ 台账缺失时
#      会写出**空文件**而不是 0（2026-11-14 实测）。改用 if 判断。
if [ -f _巡检记录/layout-canonical.tsv ]; then
  wc -l < _巡检记录/layout-canonical.tsv | tr -d ' ' > /tmp/onemore_ledger_baseline
else
  echo 0 > /tmp/onemore_ledger_baseline
fi

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
# ★ 幂等：若设备已在线，就不要重复 `-a`（可能报错或起第二个实例）
if "$HC" list targets 2>/dev/null | grep -qiE 'onemore|emulator'; then
  echo '✅ 已有设备在线 ⇒ 跳过启动'
else
  "$EMU" -start onemore7 > /tmp/tonight_emu.log 2>&1 &   # ★ 2026-11-14 修：原为 `-a`（非法选项，Emulator 只认 `-start <name>`）
  # ★ 2026-11-14 改：原来死等 180 秒，冷启动若更慢就整晚中止 ⇒ 改成轮询
  echo '⇒ 起模拟器后轮询等待上线（最多 300 秒，每 15 秒查一次）'
  WAITED=0
  while [ "$WAITED" -lt 300 ]; do
    sleep 15; WAITED=$((WAITED + 15))
    if "$HC" list targets 2>/dev/null | grep -qiE 'onemore|emulator'; then
      echo "   ✅ 第 $WAITED 秒上线"
      break
    fi
    [ $((WAITED % 60)) -eq 0 ] && echo "   …已等 $WAITED 秒"
  done
  [ "$WAITED" -lt 300 ] || echo '   ⚠️ 等满 300 秒仍未上线'
fi
# 无论如何，装包前确认设备真的在
"$HC" list targets 2>/dev/null | grep -qiE 'onemore|emulator' \
  || fail 3 '设备不在线（模拟器没起来）⇒ 看 /tmp/tonight_emu.log' 

# ★★ 设备唯一性守卫（2026-11-14）：
#   shot_game.py 硬编码 2560x1600 做坐标计算，而设备选择取 `hdc list targets` 的第一个。
#   ⇒ 若电视模拟器（onemore_tv，1280x720）也在线，命令会打到电视、却按手机分辨率算 ⇒ 数据全错且不报错。
#   ⇒ 所以：多于一台在线就中止；并把串号打进日志，让每行数据可归因。
NDEV=$("$HC" list targets 2>/dev/null | grep -vciE '^\[Empty\]|^[[:space:]]*$')
if [ "$NDEV" -ne 1 ]; then
  echo "❌ 在线设备 $NDEV 台（应为 1）⇒ 中止，避免测错设备："
  "$HC" list targets 2>/dev/null | sed 's/^/     /'
  fail 3 "在线设备 $NDEV 台，不是 1 台"
fi
DEV=$(  "$HC" list targets 2>/dev/null | head -1 | tr -d ' \r')
echo "✅ 唯一在线设备：$DEV"
echo "   设备 $DEV ｜ $(date '+%F %T')" >> /tmp/tonight_device.log

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

# ★ 2026-11-14：**sweep_all.sh 用「HAP 构建日」当基线**；HAP 不在时它的 BASELINE 会是空串，
#   而空基线会让「所有行都算已测」⇒ 待测 0 款、脚本正常退出（静默跑 0 款，比崩溃危险）。
#   ⇒ 在调用之前拦一道：HAP 不在就不进跑批。
[ -f "$HAP" ] || fail 5 "HAP 不见了（$HAP）⇒ sweep_all 会空基线、静默跑 0 款 ⇒ 拒绝进入跑批"

step 5 '跑批（06:45 自停）'
echo '⇒ 若中途崩了要重启：cp /tmp/sweep_all.log "/tmp/sweep_all-$(date +%H%M)-崩前.log"'
bash 工具/sweep_all.sh

step 6 '跑完出报告'
_T=$(date +%Y-%m-%d); _Y=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
NEW=$(grep -cE "^($_T|$_Y)" _巡检记录/layout-canonical.tsv 2>/dev/null || echo 0)
echo "⇒ 本次新增行数（含跨零点）：$NEW（期望 215–221；若为 0 先查 HAP 与 BASELINE，别先查模拟器）"
python3 工具/morning_report.py
