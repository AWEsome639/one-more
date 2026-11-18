#!/bin/bash
# 跑批看门狗：每 15 分钟确认 sweep_all.sh 活着；死了就记一笔并尝试续跑一次。
# ★ 2026-11-19（判据 2954）：跑批中途崩了没人管 ⇒ 整夜的活白费。
#   判据：进程在 ≠ 在干活（我自己的 AGENTS 就写着），但这里只防「进程没了」这最粗暴的一种。
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=/tmp/sweep_watchdog.log
MAX_RESTART=2
restarts=0
while :; do
  ts=$(date '+%m-%d %H:%M')
  if [ -f /tmp/onemore_sweep_done ]; then
    echo "[$ts] 跑批已正常结束（done 标记）⇒ 看门狗退出" >> "$LOG"; exit 0
  fi
  if pgrep -f 'sweep_all.sh' >/dev/null 2>&1; then
    echo "[$ts] ✅ 跑批活着" >> "$LOG"
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
