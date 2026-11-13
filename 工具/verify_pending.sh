#!/bin/bash
# 2026-11-13：**今晚攒下的 6 处未验证改动，一条命令复核**
#   用法：bash 工具/verify_pending.sh
#   判据：`blk` 必须比「改动前」小（或归零）；没降 ⇒ 单独回退那一款
set -u
cd "$(dirname "$0")/.." || exit 1
TSV=_巡检记录/layout-canonical.tsv

# 游戏名 | 改动 | 改动前 blk
CASES=(
  "Block Count 3D|格子 112→88|2/48px"
  "Pattern Sequence Draw|盘面底部留 32|1/24px"
  "Fraction Matcher|题卡字号降档|0（lowest=B 在 1600）"
  "Pythagorean Triple Builder|? hero→xxl|0（lowest=⌫ 在 1600）"
  "Visual Search All|盘面限宽|0（第三行整行被切）"
  "Hitori|盘面限宽|0（6×6 只见 2 行）"
)

echo "=== 今晚 6 处待验证改动 ==="
printf "%-30s %-22s %-12s %s\n" "游戏" "改动" "改前" "最新一行（看 blk）"
echo "--------------------------------------------------------------------------------"
for c in "${CASES[@]}"; do
  IFS='|' read -r name chg before <<< "$c"
  # 取台账里该款最后一行
  line=$(grep -F "$name" "$TSV" 2>/dev/null | tail -1)
  if [ -z "$line" ]; then
    printf "%-30s %-22s %-12s %s\n" "$name" "$chg" "$before" "❌ 台账里没有"
    continue
  fi
  blk=$(echo "$line" | grep -oE 'blk=[0-9]+/[0-9]+px' | head -1)
  outc=$(echo "$line" | cut -f3)
  ts=$(echo "$line" | cut -f1)
  printf "%-30s %-22s %-12s %s %s (%s)\n" "$name" "$chg" "$before" "${blk:-无blk}" "$outc" "$ts"
done

echo
echo "=== 判据 ==="
echo "· blk 归零或变小 ⇒ ✅ 有效"
echo "· blk 没变 ⇒ ❌ **单独回退**：git checkout -- entry/src/main/ets/games/G<某款>.ets（或 git revert <commit>）"
echo "· 结果是 NOT_HOME/NO_CARD/DUMP_FAIL ⇒ 环境问题，重测后再判"
echo "· ⚠️ 别忘了看截图（判据 1998）：blk=0 也可能有横向裁切/整行不见"
