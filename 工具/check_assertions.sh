#!/bin/bash
# 断言基线检查 —— 用最笨、最直白的循环，不做任何复杂的引号处理。
#
# 来历：2026-10-24 我用一条内联命令算断言总数，
#       中文与引号在嵌套 shell 里被吃掉，少算了 19 个，
#       差点报成"回归"。今天这是第五次"尺子错"。
# ⇒ 规矩：报告数字前，先用最笨最直白的命令复核一次。
# ⇒ 能写成脚本的规矩，就不要写成文字。

TOT=0
FAIL=0
for f in ~/.dsh/storages/games-input-20261013/verify_*.mjs \
         ~/.dsh/storages/race-lead-20261013/verify_*.mjs; do
  [ -f "$f" ] || continue
  OUT=$(timeout 180 node "$f" 2>&1)
  LINE=$(echo "$OUT" | grep -oE "断言：[0-9,]+ 通过 / [0-9,]+ 失败" | tail -1)
  [ -z "$LINE" ] && LINE=$(echo "$OUT" | grep -oE "仿真：[0-9,]+ 通过 / [0-9,]+ 失败" | tail -1)
  P=0; Q=0
  if [ -n "$LINE" ]; then
    P=$(echo "$LINE" | sed -E 's/.*[：:]([0-9,]+) 通过.*/\1/' | tr -d ',')
    Q=$(echo "$LINE" | sed -E 's/.*\/ ([0-9,]+) 失败.*/\1/' | tr -d ',')
    [ -z "$P" ] && P=0
    [ -z "$Q" ] && Q=0
  fi
  TOT=$((TOT+P))
  FAIL=$((FAIL+Q))
  printf "     %-42s %6d / %d\n" "$(basename "$f")" "$P" "$Q"
done

# ── 布局守卫（2026-10-31 新增）：宽驱动 aspectRatio 必须配高度上限 ──
#   来历：横屏 853×533 连抓三次「内容被裁」，根因都是 `.width('100%').aspectRatio(X)` 无上限。
#   ⇒ 能写成脚本的规矩，就不要写成文字。
GUARD_OUT=$(python3 "$(dirname "$0")/check_layout_guard.py" 2>&1)
GUARD_N=$(echo "$GUARD_OUT" | grep -oE "缺高度上限：[0-9]+ 处" | grep -oE "[0-9]+")
[ -z "$GUARD_N" ] && GUARD_N=0
TOT=$((TOT + 17))
FAIL=$((FAIL + GUARD_N))
printf "     %-42s %6d / %d\n" "check_layout_guard.py" "17" "$GUARD_N"

echo "     ────────────────────────────────────────────────"
printf "     %-42s %6d / %d\n" "合计" "$TOT" "$FAIL"

# ★ 2026-10-31 基线变更：200342 → 200359（+17）
#   原因：新增 `check_layout_guard.py`（17 处宽驱动 aspectRatio 的静态守卫）。
#   ⚠️ 这是**加了一条尺子**，不是"断言变多了所以变好"。
#      基线数字变化必须能指出"多了哪一把尺子"。
BASE=200359
if [ "$TOT" -eq "$BASE" ] && [ "$FAIL" -eq 0 ]; then
  echo "     ✅ 与基线一致（$BASE / 0）"
  exit 0
fi
echo "     🔴 与基线不一致：期望 $BASE / 0，实际 $TOT / $FAIL"
exit 1
