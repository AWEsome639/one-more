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
  [ -f "${f}" ] || continue
  OUT=$(timeout 180 node "${f}" 2>&1)
  LINE=$(echo "${OUT}" | grep -oE "断言：[0-9,]+ 通过 / [0-9,]+ 失败" | tail -1)
  [ -z "${LINE}" ] && LINE=$(echo "${OUT}" | grep -oE "仿真：[0-9,]+ 通过 / [0-9,]+ 失败" | tail -1)
  P=0; Q=0
  if [ -n "${LINE}" ]; then
    P=$(echo "${LINE}" | sed -E 's/.*[：:]([0-9,]+) 通过.*/\1/' | tr -d ',')
    Q=$(echo "${LINE}" | sed -E 's/.*\/ ([0-9,]+) 失败.*/\1/' | tr -d ',')
    [ -z "${P}" ] && P=0
    [ -z "${Q}" ] && Q=0
  fi
  TOT=$((TOT+P))
  FAIL=$((FAIL+Q))
  printf "     %-42s %6d / %d\n" "$(basename "${f}")" "${P}" "${Q}"
done

# ── 布局守卫（2026-10-31 新增）：宽驱动 aspectRatio 必须配高度上限 ──
#   来历：横屏 853×533 连抓三次「内容被裁」，根因都是 `.width('100%').aspectRatio(X)` 无上限。
#   ⇒ 能写成脚本的规矩，就不要写成文字。
GUARD_OUT=$(python3 "$(dirname "$0")/check_layout_guard.py" 2>&1)
GUARD_N=$(echo "${GUARD_OUT}" | grep -oE "缺高度上限：[0-9]+ 处" | grep -oE "[0-9]+")
[ -z "${GUARD_N}" ] && GUARD_N=0
TOT=$((TOT + 17))
FAIL=$((FAIL + GUARD_N))
printf "     %-42s %6d / %d\n" "check_layout_guard.py" "17" "${GUARD_N}"

# ── 判据 1782（2026-11-07 新增）：双符号 —— 字典译文自带符号 + 组件又画一个 ──
#   来历：一晚两处 —— 成就墙「閉じる ▲ ▲」、等级头卡「✅ ✅ Heute erledigt」。
#   ⇒ 能写成脚本的规矩，就不要写成文字。
#   ★ 为什么是**纯闸门**（只 FAIL += N，不动 TOT）：
#     加 TOT 就要改基线数字（200359 → +1），而基线变化必须能说清「多了哪把尺子」；
#     这条只判「有没有违规」，不产生通过计数，所以不进 TOT 最干净。
#   ★ rc=2（解析器坏/自检失败）也算失败 —— 否则"检查器坏了"会显示成绿。
DUP_OUT=$(python3 "$(dirname "$0")/../tools/check_dup_symbol.py" 2>&1)
DUP_RC=$?
DUP_N=$(printf '%s' "${DUP_OUT}" | grep -oE "双符号：[0-9]+ 处" | grep -oE "[0-9]+" | tail -1)
if [ "${DUP_RC}" -eq 2 ] || [ -z "${DUP_N}" ]; then
  DUP_N=1
  echo "     ⚠️ check_dup_symbol.py 无法给出结论（rc=${DUP_RC}）⇒ 按 1 处失败计，别当绿"
fi
FAIL=$((FAIL + DUP_N))
printf "     %-42s %6s / %d\n" "check_dup_symbol.py（双符号）" "-" "${DUP_N}"

# ══════════════════════════════════════════════════════════════════════════
#  check_focusable.py —— 可点组件必须有 focusable（2026-11-07 交互死角审计）
#
#  来历：电视/PC 靠方向键，而 ArkUI 里 Text/Row/Column/Stack 上的 .onClick
#        **默认不可聚焦** ⇒ 触屏能点、遥控器选不中。实测主界面/设置页/联机页
#        共 41 处（GameCard 甚至"有 onFocus/onBlur 却没有 focusable"= 死回调）。
#  ★ 同样是**纯闸门**：只 FAIL += N，不动 TOT（理由同上：不产生通过计数）。
#  ★ rc=2（解析/自检失败）也算失败 —— 检查器坏了不能显示成绿
#    （今晚 check_dup_symbol 就因为写死阈值 `n_extra<500` 而长期"死绿"，教训）。
FOCUS_OUT=$(python3 "$(dirname "$0")/../tools/check_focusable.py" 2>&1)
FOCUS_RC=$?
FOCUS_N=$(printf '%s' "${FOCUS_OUT}" | grep -oE "焦点缺口：[0-9]+ 处" | grep -oE "[0-9]+" | tail -1)
if [ "${FOCUS_RC}" -eq 2 ] || [ -z "${FOCUS_N}" ]; then
  FOCUS_N=1
  echo "     ⚠️ check_focusable.py 无法给出结论（rc=${FOCUS_RC}）⇒ 按 1 处失败计，别当绿"
fi
FAIL=$((FAIL + FOCUS_N))
printf "     %-42s %6s / %d\n" "check_focusable.py（焦点）" "-" "${FOCUS_N}"

echo "     ────────────────────────────────────────────────"
printf "     %-42s %6d / %d\n" "合计" "${TOT}" "${FAIL}"

# ★ 2026-10-31 基线变更：200342 → 200359（+17）
#   原因：新增 `check_layout_guard.py`（17 处宽驱动 aspectRatio 的静态守卫）。
#   ⚠️ 这是**加了一条尺子**，不是"断言变多了所以变好"。
#      基线数字变化必须能指出"多了哪一把尺子"。
BASE=200359
if [ "${TOT}" -eq "${BASE}" ] && [ "${FAIL}" -eq 0 ]; then
  echo "     ✅ 与基线一致（${BASE} / 0）"
  exit 0
fi
echo "     🔴 与基线不一致：期望 ${BASE} / 0，实际 ${TOT} / ${FAIL}"
exit 1
