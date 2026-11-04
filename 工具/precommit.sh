#!/bin/bash
# 提交前依次跑三项；任何一项红就停。
#
# ⚠️ 2026-11-05（第 1330 轮）**读到这里的人请注意**：
#   本文件是**旧版**（三项，且引用的 verify_*.mjs 在 ~/.dsh/storages/ 下）。
#   **One More 现在的提交前检查是七项**，请用：
#       bash 工具/precommit_onemore.sh
#   七项 = 断言基线 / check_splash / check_docs_tracked /
#          check_outline_owner / check_text_fit / mutation_test /
#          check_shell_pitfalls（第 1329 轮新增）
#   本文件保留不动（可能被其它脚本引用）。
#   ★ 另注：`~/dev/yiju` 是 `~/dev/One More` 的**符号链接**（同一目录），
#     所以下面 `cd ~/dev/yiju` 与 `cd ~/dev/One More` 等价。
set -e
cd ~/dev/yiju
echo "  ① 占位符:"
python3 工具/check_placeholders.py
echo "  ② i18n:"
python3 工具/verify_i18n.py 2>&1 | tail -3
echo "  ③ 断言:"
TOT=0; FAIL=0
for f in ~/.dsh/storages/games-input-20261013/verify_*.mjs ~/.dsh/storages/race-lead-20261013/verify_*.mjs; do
  [ -f "${f}" ] || continue
  LINE=$(timeout 180 node "${f}" 2>&1 | grep -oE "断言：[0-9,]+ 通过 / [0-9,]+ 失败|仿真：[0-9,]+ 通过 / [0-9,]+ 失败" | tail -1)
  [ -n "${LINE}" ] && {
    P=$(echo "${LINE}" | grep -oE "[0-9,]+ 通过" | tr -d ' 通过' | tr -d ',')
    Q=$(echo "${LINE}" | grep -oE "[0-9,]+ 失败" | tr -d ' 失败' | tr -d ',')
    TOT=$((TOT+P)); FAIL=$((FAIL+Q))
  }
done
printf "     %d / %d\n" "${TOT}" "${FAIL}"
[ "${FAIL}" -eq 0 ] || { echo "  🔴 断言有失败"; exit 1; }
echo "  ✅ 三项都过"
