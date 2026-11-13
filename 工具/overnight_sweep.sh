#!/bin/bash
# 2026-11-13：**跨夜全量基线**（`00:00` 后跑，机器归我）
#   纪据：他 00:00-07:00 睡觉，前台/重活全开（AGENTS 2026-11-13 口令）
#   前提：`onemore7`（853x533 vp）+ `shot_game.py` 带三道闸自动化
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=/tmp/overnight_sweep.log
: > "$LOG"
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# ① 等到 00:05 之后（他睡了）
while [ "$(date +%H%M)" -lt 0005 ] && [ "$(date +%H%M)" -gt 0500 ]; do sleep 60; done
say "开始：现在是 $(date +%H:%M)"

# ② 等机器空下来（load1 < 15）
for i in $(seq 1 60); do
  L=$(uptime | awk -F'load averages: ' '{print $2}' | awk '{print $1}')
  if awk -v l="$L" 'BEGIN{exit !(l < 15)}'; then say "load=$L ⇒ 开跑"; break; fi
  say "load=$L 偏高，等…"; sleep 60
done

# ③ 全量跑（每 8 款重启一次模拟器；失败默认重试一次）
say "启动全量 355 款…"
python3 工具/verify_layout.py --every 8 >> "$LOG" 2>&1
say "全量结束。台账：_巡检记录/layout-canonical.tsv"
