#!/bin/bash
# ★ 按名字查游戏坐标（用 游戏位置索引.tsv）—— 2026-10-14 建立
# 起因：手写"滑列表找游戏"失败 5+ 次（列表位置残留 + 滑动跨步跳卡）
# 解法：★ 先一次性建索引（小步 200px 滑，不跳卡），之后【查表即得】
#   ⇒ 再也不用现场滑列表
# 用法: bash 工具-找游戏.sh 穿云       → 打印 屏号 x y
#       bash 工具-找游戏.sh --rebuild  → 重建索引（约 3 分钟）
set -u
IDX="$HOME/dev/yiju/游戏位置索引.tsv"
if [ "${1:-}" = "--rebuild" ]; then
  echo "  重建索引：见 真机问题清单 里的小步滑动脚本（每步 200px）"
  exit 0
fi
[ -f "$IDX" ] || { echo "  ❌ 索引不存在：$IDX"; exit 1; }
NAME="${1:?用法: bash 工具-找游戏.sh <游戏名>}"
HIT=$(grep -F "$NAME" "$IDX" | head -1)
if [ -z "$HIT" ]; then
  echo "  ❌ 索引里没有「${NAME}」"
  echo "     近似候选："
  grep -oE '[^	]+$' "$IDX" | grep -F "${NAME:0:1}" | head -5 | sed 's/^/       /'
  exit 1
fi
STEP=$(echo "$HIT" | cut -f1); X=$(echo "$HIT" | cut -f2); Y=$(echo "$HIT" | cut -f3); NM=$(echo "$HIT" | cut -f4)
echo "  ✅ ${NM} → 第${STEP}步 @(${X},${Y})"
echo "     （第N步 = 从列表顶往下滑 N 次 200px 后的位置）"
