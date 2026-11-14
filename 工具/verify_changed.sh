#!/bin/bash
# 2026-11-14：**今晚攒下的 38 款改动，一条命令复核**
#   用法：bash 工具/verify_changed.sh
#   前置：先 build 并装包（见文件末尾）
#   判据：blk 必须比改动前小；没降 ⇒ 单独回退那一款
set +u
cd "/Users/a0000/dev/One More" || exit 1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
TSV=_巡检记录/layout-canonical.tsv

# 游戏名 | 改动摘要 | 改动前状态
CASES=(
  "2048|盘面限宽（去掉假 maxHeight）|72px"
  "Block Count 3D|格高 112→88|48px"
  "Calculation Sprint|题卡 hero→xl|48px"
  "Collatz|题卡 hero→xxl|48px"
  "Crown|盘面限宽|48px"
  "Dominosa|盘面限宽|48px"
  "Fraction Matcher|题卡字号降档|48px"
  "Gokigen Naname|盘面限宽|48px"
  "Gomoku|盘面限宽|48px"
  "Heyawake|盘面限宽|48px"
  "Hitori|盘面限宽|62px"
  "Hitori All|盘面限宽|48px"
  "Mastermind|三行圆点限宽（预防性，改前已合规）|1px(噪声级)"
  "Matrix Reasoning|盘面限宽|72px"
  "Memory|盘面限宽|24px"
  "Modulo Clock|题卡 hero→xl|—"
  "Modulo Path|盘面限宽|24px"
  "Norinori|盘面限宽|48px"
  "Path Intersect|盘面限宽|48px"
  "Pattern Sequence Draw|盘面底部留 32|24px"
  "Percentage Peak|题卡 xxl→lg|48px"
  "Pipes|盘面限宽|48px"
  "Pythagorean Triple Builder|? hero→xxl|48px"
  "Shikaku|盘面限宽|72px"
  "Simon Says|限行宽|48px"
  "Skyscrapers|盘面限宽|48px"
  "Snake 3D|限整行宽|96px"
  "Target Number|题卡 xxxl→xl|—"
  "Visual Search All|盘面限宽|—"
  "Word Ladder|词格 60→48|键盘末行被切"
  # ★ 2026-11-14 补漏：以下 8 款之前漏登记（改动在位核对里有，本脚本没登记）
  "Number Bonds All|行容器限宽 233vp|22px（统计行被盖住）"
  "Kakuro Mini|题卡/盘面再收 40vp|24px（盘末行+键被切）"
  "Kakuro|提示行矮屏隐藏|13px（6-9 键被切）"
  "Schulte Table|盘面限宽|24px（5×5 只见 2 行）"
  "Countdown Math|四张数字卡限宽|24px（卡底部被切）"
  "Factor Finder|限宽 + ➗ 降档|24px（底部按钮被切）"
  "Percentage Shopping|题卡降档|48px（选项 4 不见）"
  "Binary Matrix Rank|矩阵格 34→28|32px（选项 D 不见）"
)

echo "=== 今晚 ${#CASES[@]} 处改动复核 ==="
printf "%-30s %-28s %-10s %s\n" "游戏" "改动" "改前" "最新（看 blk）"
echo "-----------------------------------------------------------------------------------------------"
FAIL=0
for c in "${CASES[@]}"; do
  IFS='|' read -r name chg before <<< "$c"
  line=$(grep -F "$name	" "$TSV" 2>/dev/null | tail -1)
  [ -z "$line" ] && line=$(grep -F "$name" "$TSV" 2>/dev/null | tail -1)
  if [ -z "$line" ]; then
    printf "%-30s %-28s %-10s %s\n" "$name" "$chg" "$before" "❌ 台账里没有"
    FAIL=$((FAIL+1)); continue
  fi
  blk=$(echo "$line" | grep -oE 'blk=[0-9]+/[0-9]+px' | head -1)
  outc=$(echo "$line" | cut -f3)
  ts=$(echo "$line" | cut -f1)
  printf "%-30s %-28s %-10s %s %s (%s)\n" "$name" "$chg" "$before" "${blk:-无blk}" "$outc" "$ts"
done

echo
echo "=== 判据 ==="
echo "· blk 归零或变小 ⇒ 有效"
echo "· blk 没变 ⇒ 单独回退（git revert <commit> 或 git checkout -- <file>）"
echo "· NOT_HOME/NO_CARD/DUMP_FAIL ⇒ 环境问题，重测后再判"
echo "· 仍要看截图（判据 1998）：blk=0 也可能有横向裁切/整行不见"
echo
echo "=== 前置（今晚先跑这三步）==="
echo "  1) BUILD_STRICT=1 bash build.sh assembleHap"
echo "  2) /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc install -r entry/build/default/outputs/default/entry-default-signed.hap   # 必须见 successfully"
echo "  3) python3 工具/shot_game.py \"<游戏名>\"   # 或 bash 工具/verify_changed.sh 只看台账"
