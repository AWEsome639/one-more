#!/bin/bash
# 带「设备就绪」前置检查与「静默卡死」检测的扫描包装器 —— 判据 3067
#
# 为什么需要它：`sweep_all.sh` 在模拟器起不来时会**静默卡死**
#   （2026-11-19 实测：40 分钟零产出、进程还活着、日志只有 2 行）。
#   它在拿到空画面后卡在 `pin_theme`，既不超时也不退出。
#
# 用法：
#   bash 工具/sweep_guarded.sh             # 守护式跑 sweep_all.sh
#   bash 工具/sweep_guarded.sh --nonshort  # 守护式跑 sweep_nonshort.sh
#
# ⚠️ 不要在扫描正在跑的时候编辑被它调用的脚本（bash 会按偏移继续读，会读坏）。

set -u
cd "$(dirname "$0")/.." || exit 1

HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
TARGET_SCRIPT='工具/sweep_all.sh'
INST='onemore7'
LOG='/tmp/sweep_guarded.log'
STALL_MIN=12          # 超过这么久没有新台账行 ⇒ 判静默挂起

if [ "${1:-}" = '--nonshort' ]; then
  TARGET_SCRIPT='工具/sweep_nonshort.sh'
  INST='onemore_fold'
fi

say() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── ① 设备就绪（三态检查：targets 有、shell 通、能起 ability）───────────────
device_ready() {
  ${HC} list targets 2>/dev/null | grep -q ':' || return 1
  ${HC} shell 'echo ok' 2>/dev/null | grep -q ok || return 1
  return 0
}

if ! device_ready; then
  say "❌ 设备不可用（hdc list targets 空或 shell 不通）⇒ 拒绝开跑"
  say "   排查：模拟器进程 $(pgrep -f 'mulator -start' | wc -l | tr -d ' ') 个；"
  say "        磁盘 $(df -h / | tail -1 | awk '{print $4}') 可用；"
  say "        内存 $(memory_pressure 2>/dev/null | tail -1 | grep -oE '[0-9]+%') 空闲"
  say "   重起：$EMU -stop $INST; $EMU -start $INST -noWindow"
  say "   ⚠️ 模拟器可能因**内存**不足而起不来（日志里 Host Current Free Memory 是关键行）"
  exit 2
fi
say "✅ 设备就绪"

# ── ② 台账行数（用它做「产出增量」判据，不看进程数）──────────────────────────
LEDGER='_巡检记录/layout-canonical.tsv'
[ "$TARGET_SCRIPT" = '工具/sweep_nonshort.sh' ] && LEDGER='_巡检记录/layout-nonshort.tsv'

ledger_lines() { wc -l < "$LEDGER" 2>/dev/null | tr -d ' '; }

BEFORE=$(ledger_lines)
say "台账基线 $BEFORE 行 ⇒ 启动 $TARGET_SCRIPT"

bash "$TARGET_SCRIPT" "$@" >> "$LOG" 2>&1 &
SWEEP_PID=$!
say "扫描 PID $SWEEP_PID，日志 $LOG"

# ── ③ 静默卡死检测：每 60s 看台账有没有新增 ───────────────────────────────────
STALL=0
while kill -0 "$SWEEP_PID" 2>/dev/null; do
  sleep 60
  NOW=$(ledger_lines)
  if [ "$NOW" -eq "$BEFORE" ]; then
    STALL=$((STALL + 1))
    if [ "$STALL" -ge "$STALL_MIN" ]; then
      say "⚠️ 静默挂起 ${STALL} 分钟（台账一直 $NOW 行）⇒ 杀掉并诊断"
      kill "$SWEEP_PID" 2>/dev/null; sleep 3; kill -9 "$SWEEP_PID" 2>/dev/null
      say "   模拟器进程 $(pgrep -f 'mulator -start' | wc -l | tr -d ' ') 个；设备就绪：$(device_ready && echo 是 || echo 否)"
      tail -5 "$LOG" | cut -c1-110
      exit 3
    fi
  else
    say "进度 $BEFORE → $NOW 行（+$((NOW - BEFORE))）"
    BEFORE=$NOW
    STALL=0
  fi
done

wait "$SWEEP_PID" 2>/dev/null
say "扫描结束，台账 $BEFORE → $(ledger_lines) 行"
