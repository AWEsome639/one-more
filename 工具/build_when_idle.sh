#!/bin/bash
# 2026-11-13：机器负载在 3~323 之间反复跳（`coreduetd`/`WindowServer`/索引，不是我的活）。
# 手工盯不现实 ⇒ 这个脚本**等到机器真的空下来**再编译一次，然后退出。
#
# 判据：连续 3 次采样（间隔 60s）load1 < 15 才动手 —— 避免「刚好在低谷」误判。
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=/tmp/build_when_idle.log
: > "$LOG"
ok=0
for i in $(seq 1 40); do
  L=$(uptime | awk -F'load averages: ' '{print $2}' | awk '{print $1}')
  echo "[$(date +%H:%M:%S)] 采样 $i: load1=$L" | tee -a "$LOG"
  if awk -v l="$L" 'BEGIN{exit !(l < 15)}'; then
    ok=$((ok+1))
    if [ "$ok" -ge 3 ]; then
      echo "[$(date +%H:%M:%S)] 连续 3 次 < 15 ⇒ 开始编译" | tee -a "$LOG"
      BUILD_STRICT=1 bash build.sh assembleHap >> "$LOG" 2>&1
      grep -E "BUILD SUCCESSFUL|BUILD FAILED" "$LOG" | tail -1 | tee -a "$LOG"
      ls -l entry/build/default/outputs/default/entry-default-signed.hap 2>/dev/null | tee -a "$LOG"
      exit 0
    fi
  else
    ok=0
  fi
  sleep 60
done
echo "❌ 40 次采样内没等到空闲窗口" | tee -a "$LOG"
exit 1
