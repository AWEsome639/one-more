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
WARN=0   # 只提示、不影响退出码与基线（当前用于读屏缺口趋势）
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

# ══════════════════════════════════════════════════════════════════════════
#  tools/check_hud_consistency.py —— 同一个 HUD 容器内，标签 maxLines 必须一致
#
#  来历（2026-11-08）：三块统计 HUD（Row { Column{ 标签 + 数值 } × N }）是**逐文件
#        复制粘贴**的（games/ 里 295 份副本，没有任何共享 @Builder）。其中 24 款手写时
#        把某一块标签改成 maxLines(2)、邻块留 1 行或干脆不写 ⇒ 长语言标签一换行，
#        那一块的数值就比邻块**低一整行（xxs 行盒 14vp）**⇒ 三块数值不在一条水平线上
#        （中文 2~4 字看不出来，德语/俄语很容易）。
#  ★ 纯闸门：只 FAIL += 新增数，不动 TOT（理由同上：不产生通过计数）。
#  ★ rc=2（解析/自检失败）也算失败 —— 检查器坏了不能显示成绿
#    （check_dup_symbol 曾因写死阈值长期"死绿"，教训）。
#  ★ 基线 0：2026-11-08 凌晨把 102 处存量全部清完（15 批 · 约 130 处标签），现已锁死为 0。
#    从现在起任何新增分歧都会当场变红。
#    想一次清完：`python3 tools/check_hud_consistency.py` 列出全部，按 7 款一批修。
HUD_OUT=$(python3 "$(dirname "$0")/../tools/check_hud_consistency.py" 2>&1)
HUD_RC=$?
HUD_N=$(printf '%s' "${HUD_OUT}" | grep -oE "HUD不一致：[0-9]+ 处" | grep -oE "[0-9]+" | tail -1)
HUD_BASE=0
if [ "${HUD_RC}" -eq 2 ] || [ -z "${HUD_N}" ]; then
  HUD_NEW=1
  echo "     ⚠️ check_hud_consistency.py 无法给出结论（rc=${HUD_RC}）⇒ 按 1 处失败计，别当绿"
else
  HUD_NEW=$((HUD_N - HUD_BASE))
  [ "${HUD_NEW}" -lt 0 ] && HUD_NEW=0
fi
FAIL=$((FAIL + HUD_NEW))
printf "     %-42s %6s / %d\n" "check_hud_consistency.py（HUD 一致）" "${HUD_N:-?}/${HUD_BASE}" "${HUD_NEW}"

# ── 判据 1782 家族（2026-11-08 新增）：译文内容被当状态用 ──
#   来历：`this.tip.startsWith('✓')` 决定颜色、`this.msg.indexOf('❌') === 0` 决定锁输入 ——
#     只要某个语言的译文删掉 emoji，判断就静默失效（比颜色更隐蔽的是行为差异）。
#   试点：改前精准 4 处、改后 0 处、367 个 .ets 零误报。
#   ★ 同样**纯闸门**：只 FAIL += N、不动 TOT（基线 200359 不用改）；rc=2 也算失败。
JUDGE_OUT=$(python3 "$(dirname "$0")/../tools/check_state_from_text.py" 2>&1)
JUDGE_RC=$?
JUDGE_N=$(printf '%s' "${JUDGE_OUT}" | grep -oE "内容当状态：[0-9]+ 处" | grep -oE "[0-9]+" | tail -1)
if [ "${JUDGE_RC}" -eq 2 ] || [ -z "${JUDGE_N}" ]; then
  JUDGE_N=1
  echo "     ⚠️ check_state_from_text.py 无法给出结论（rc=${JUDGE_RC}）⇒ 按 1 处失败计，别当绿"
fi
FAIL=$((FAIL + JUDGE_N))
printf "     %-42s %6s / %d\n" "check_state_from_text.py（内容当状态）" "-" "${JUDGE_N}"

# ── 判据 1782 家族（2026-11-08 新增）：跨局状态残留（复位遗漏）──
#   2-hop 守卫链：字段在 reset 面没赋值 + 显示点没有「reset 面会清零的守卫」⇒ 报。
#   自检：上一轮 4 个 A 类候选 0 命中（全被守卫消掉）；GWordLadderStep 精准命中 1 处。
#   ★ 纯闸门：只 FAIL += N、不动 TOT（基线 200359 不用改）；rc=2 也算失败。
LEAK_OUT=$(python3 "$(dirname "$0")/../tools/check_reset_leak.py" 2>&1)
LEAK_RC=$?
LEAK_N=$(printf '%s' "${LEAK_OUT}" | grep -oE "复位遗漏：[0-9]+ 处" | grep -oE "[0-9]+" | tail -1)
if [ "${LEAK_RC}" -eq 2 ] || [ -z "${LEAK_N}" ]; then
  LEAK_N=1
  echo "     ⚠️ check_reset_leak.py 无法给出结论（rc=${LEAK_RC}）⇒ 按 1 处失败计，别当绿"
fi
FAIL=$((FAIL + LEAK_N))
printf "     %-42s %6s / %d\n" "check_reset_leak.py（复位遗漏）" "-" "${LEAK_N}"

# ── 判据 1790（2026-11-08 新增）：代码里的 key 在不在字典 ──
#   来历：a11y 批量补的 `this.t('中文','English')` 只写了 zh/en ⇒ 10 语言退英文；
#     而 check_i18n.py 只查字典条目完不完整，查不到「代码引用了字典里没有的 key」。
#   实测：用 c388365d^ 的旧字典跑 ⇒ 28 处（11 个 a11y key 的 13 个调用点 + 15 处存量缺口）；
#         现网 ⇒ 15 处（a11y 已全补，存量缺口仍在）。
#   ★ 纯闸门：只 FAIL += N、不动 TOT（基线 200359 不用改）；rc=2 也算失败。
KEY_OUT=$(python3 "$(dirname "$0")/../tools/check_key_coverage.py" 2>&1)
KEY_RC=$?
KEY_N=$(printf '%s' "${KEY_OUT}" | grep -oE "缺字典：[0-9]+ 处" | grep -oE "[0-9]+" | tail -1)
if [ "${KEY_RC}" -eq 2 ] || [ -z "${KEY_N}" ]; then
  KEY_N=1
  echo "     ⚠️ check_key_coverage.py 无法给出结论（rc=${KEY_RC}）⇒ 按 1 处失败计，别当绿"
fi
FAIL=$((FAIL + KEY_N))
printf "     %-42s %6s / %d\n" "check_key_coverage.py（key 覆盖）" "-" "${KEY_N}"

echo "     ────────────────────────────────────────────────"
printf "     %-42s %6d / %d\n" "合计" "${TOT}" "${FAIL}"

# ══════════════════════════════════════════════════════════════════════════
#  读屏缺口（accessibilityText）—— **只算 warning，不进 FAIL**
#
#  为什么不当闸门：读屏不是「必须 0」，而是「应该越来越少」。
#    纯图标按钮没有 a11y ⇒ 盲人听到「按钮」却不知道功能（该修）；
#    带文字标签的按钮子 Text 往往能被念出来（语义/顺序不一定对）。
#  ⇒ 每次跑都打印这两档数字，趋势往下是好事、往上要解释。
A11Y_OUT=$(python3 "$(dirname "$0")/../tools/check_focusable.py" --a11y 2>&1)
A11Y_RED=$(printf '%s' "${A11Y_OUT}" | grep -oE "🔴 [0-9]+" | grep -oE "[0-9]+" | head -1)
A11Y_YEL=$(printf '%s' "${A11Y_OUT}" | grep -oE "🟡 [0-9]+" | grep -oE "[0-9]+" | head -1)
# ★ 数字与显示分开：显示可以是 "?"，但算术必须拿到数字 ——
#   否则检查器一坏，`$(( ))` 会直接让脚本报错退出（比"静默变绿"更糟的是"整条断言挂掉"）。
A11Y_RED_S="${A11Y_RED}"; A11Y_YEL_S="${A11Y_YEL}"
case "${A11Y_RED}" in ''|*[!0-9]*) A11Y_RED=1; A11Y_RED_S="?" ;; esac
case "${A11Y_YEL}" in ''|*[!0-9]*) A11Y_YEL=1; A11Y_YEL_S="?" ;; esac
WARN=$((WARN + A11Y_RED + A11Y_YEL))
printf "     %-42s %6s / %s\n" "读屏缺口（🔴纯图标 / 🟡有文字）" "${A11Y_RED_S}" "${A11Y_YEL_S}"

# ★ 2026-10-31 基线变更：200342 → 200359（+17）
#   原因：新增 `check_layout_guard.py`（17 处宽驱动 aspectRatio 的静态守卫）。
#   ⚠️ 这是**加了一条尺子**，不是"断言变多了所以变好"。
#      基线数字变化必须能指出"多了哪一把尺子"。
BASE=200359
if [ "${TOT}" -eq "${BASE}" ] && [ "${FAIL}" -eq 0 ]; then
  echo "     ✅ 与基线一致（${BASE} / 0）　｜ 读屏缺口合计 ${WARN} 处（warning，不影响基线）"
  exit 0
fi
echo "     🔴 与基线不一致：期望 ${BASE} / 0，实际 ${TOT} / ${FAIL}"
exit 1
