#!/bin/bash
# 跑批看门狗：每 15 分钟确认 sweep_all.sh 活着；死了就记一笔并尝试续跑一次。
# ★ 2026-11-19（判据 2954）：跑批中途崩了没人管 ⇒ 整夜的活白费。
#   判据：进程在 ≠ 在干活（我自己的 AGENTS 就写着），但这里只防「进程没了」这最粗暴的一种。
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=/tmp/sweep_watchdog.log
MAX_RESTART=2
restarts=0
# ★ 2026-11-19（判据 2998）：**「进程在」≠「在干活」** —— 今晚 01:53~02:04
#   跑批进程活着但**卡在模拟器重启上，25 分钟零产出**，而本看门狗每 15 分钟
#   照报「✅ 跑批活着」（01:28/01:43/01:58 三条），整夜的活差点白费。
#   ⇒ 加**产出检查**：用台账行数当进度尺子；进程活着但台账 ≥15 分钟没新增
#     ⇒ 判「空转」，杀掉并续跑（计入 MAX_RESTART）。
#   15 分钟的口径：单款最坏 SHOT_BUDGET_S=360s（6 分钟）⇒ 15 分钟 = 2.5 倍上限，
#   足以区分「这一款特别慢」与「真的卡死」。
LEDGER="_巡检记录/layout-canonical.tsv"
PROG=/tmp/sweep_wd_progress
progress_count() { wc -l < "$LEDGER" 2>/dev/null | tr -d ' ' || echo 0; }
LAST=$(progress_count); echo "$LAST" > "$PROG"
while :; do
  ts=$(date '+%m-%d %H:%M')
  if [ -f /tmp/onemore_sweep_done ]; then
    echo "[$ts] 跑批已正常结束（done 标记）⇒ 看门狗退出" >> "$LOG"; exit 0
  fi
  if pgrep -f 'sweep_all.sh' >/dev/null 2>&1; then
    NOW=$(progress_count)
    if [ "$NOW" != "$LAST" ]; then
      LAST=$NOW; echo "$NOW" > "$PROG"
      rm -f "$PROG.ts"          # ★ 有产出就清掉空转计时，否则下次卡住会立刻误判超时
      echo "[$ts] ✅ 跑批活着且有产出（台账 $NOW 行）" >> "$LOG"
    else
      # 台账没动 —— 看上次有产出是哪一刻
      idle=0
      [ -f "$PROG.ts" ] && idle=$(( $(date +%s) - $(cat "$PROG.ts") ))
      if [ "$idle" -eq 0 ]; then
        echo "[$ts] ⏳ 台账无新增，开始计时（$NOW 行）" >> "$LOG"
        date +%s > "$PROG.ts"
      elif [ "$idle" -ge 900 ]; then
        echo "[$ts] ❌ 空转 ${idle}s（台账停在 $NOW 行）⇒ 杀掉续跑" >> "$LOG"
        pkill -f 'sweep_all.sh' 2>/dev/null
        sleep 3
        rm -f "$PROG.ts"
        if [ "$restarts" -lt "$MAX_RESTART" ]; then
          restarts=$((restarts+1))
          echo "[$ts] ⚠️ 第 $restarts 次续跑（空转触发）" >> "$LOG"
          nohup bash 工具/sweep_all.sh >> /tmp/sweep_all2.log 2>&1 &
        else
          echo "[$ts] ❌ 已重启 $restarts 次仍空转 ⇒ 放弃并留记录" >> "$LOG"; exit 1
        fi
      else
        echo "[$ts] ⏳ 跑批活着但台账无新增（已 ${idle}s，阈值 900s）" >> "$LOG"
      fi
    fi
  else
    # 时间窗内才重启（00:00–06:40），避免早上把人吵醒
    h=$(date +%H)
    if [ "$h" -ge 7 ] || [ "$h" -eq 6 ] && [ "$(date +%M)" -ge 45 ]; then
      echo "[$ts] ⏹ 已过运行窗口（h=$h）⇒ 不重启" >> "$LOG"; exit 0
    fi
    if [ "$restarts" -ge "$MAX_RESTART" ]; then
      echo "[$ts] ❌ 已重启 $restarts 次仍死 ⇒ 放弃并留记录" >> "$LOG"; exit 1
    fi
    restarts=$((restarts+1))
    echo "[$ts] ⚠️ 跑批不在了 ⇒ 第 $restarts 次尝试续跑" >> "$LOG"
    nohup bash 工具/run_tonight.sh >> /tmp/tonight.log 2>&1 &
  fi
  sleep 900
done
