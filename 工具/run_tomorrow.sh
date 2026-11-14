#!/bin/bash
# 明晚的**编排脚本**：五处改动 → 编译 → 断言 → 补断言条目 → 再断言。
# 用法：bash 工具/run_tomorrow.sh --dry   # 只跑两个补丁的 dry，不改文件
#       bash 工具/run_tomorrow.sh         # 全流程
#
# 依据：_巡检记录/★★★★★★★功能级修复计划…md（五处改点带数值与跨设备验证）
set -u
cd "/Users/a0000/dev/One More" || exit 1
WITHB=''
for a in "$@"; do [ "$a" = '--with-b' ] && WITHB='--with-b'; done
step() { echo; echo "════ 第 $1 步：$2 ════"; }
fail() { echo "❌ 卡在第 $1 步：$2"; exit 1; }

if [ "${1:-}" = '--dry' ]; then
  step 1 '补丁 dry（四处数字 + 一处结构）'
  bash 工具/apply_fixes.sh --dry $WITHB || fail 1 'A 档 apply_fixes --dry 有未命中'
  python3 工具/apply_wordle_scroll.py --dry || fail 1 'wordle scroll --dry 失败'
  echo; echo '✅ dry 全过 ⇒ 可以真改'; exit 0
fi

step 0 '改前先记基线（干净工作树）'
N=$(git status --porcelain | wc -l | tr -d ' ')
[ "$N" = 0 ] || fail 0 "工作树不干净（$N 项）⇒ 先提交或复原"
echo '✅ 工作树干净'

step 1 '应用 A 档数字修复（Magnets / FractionMatcher）'
bash 工具/apply_fixes.sh $WITHB || fail 1 'apply_fixes 有未命中'
# ⚠️ B 档（PercentageShopping / KakuroMini）测的是旧代码、可能已修好 ⇒ 默认不改；
#    只有今晚数据显示它们仍不达标时，才手动加 --with-b 再跑。

step 2 '应用 Wordle 套 Scroll'
python3 工具/apply_wordle_scroll.py || fail 2 'wordle scroll 失败'

step 3 '看 diff（人眼确认只动了预期行）'
git --no-pager diff --stat
git --no-pager diff -U1 entry/src/main/ets/games/ | grep -E "^[+-]" | grep -vE "^(\+\+\+|---)" | head -20

step 4 '编译（约 7 分钟）'
BUILD_STRICT=1 bash build.sh assembleHap > /tmp/tomorrow_build.log 2>&1 || fail 4 '编译失败（看 /tmp/tomorrow_build.log）'
grep -iE 'BUILD SUCCESSFUL|成功' /tmp/tomorrow_build.log | tail -2 || true
echo '✅ 编译通过'

step 5 '跑断言（必须 200359 / 0）'
A=$(bash 工具/check_assertions.sh 2>/dev/null | grep '合计')
echo "$A"
echo "$A" | grep -q '200359 / 0' || fail 5 '断言不是 200359 / 0'
echo '✅ 断言一致'

step 6 '补断言条目（A 档 2 条 + Wordle 1 条；B 档若改了再加）'
python3 工具/add_check_entries.py $WITHB || fail 6 'add_check_entries 失败'

step 7 '再跑断言（条目加了之后仍须 0）'
A2=$(bash 工具/check_assertions.sh 2>/dev/null | grep '合计')
echo "$A2"
echo "$A2" | grep -q '200359 / 0' || fail 7 '补条目后断言变了'
echo '✅ 仍一致'

step 8 '收尾'
HAP=entry/build/default/outputs/default/entry-default-signed.hap
[ -f "$HAP" ] && echo "HAP: $(ls -l "$HAP" | awk '{print $5}') 字节（与改前比应变化）"
echo
echo "⚠️ Pythagorean Triple Builder 现在**已自动化**（apply_fixes.sh 的 A③：L313 外层间距 sm→xs，省 72px）"
echo "   ⇒ 若 A③ 不够（确认仍被切）⇒ 叠加 L344 题干卡 padding md→sm（见 apply_fixes.sh 里注释掉的那行，+36px）"
echo "   ⇒ 改完后单测：python3 工具/shot_game.py \"Pythagorean Triple Builder\" ⇒ 看 lowest 里 确认 是否完整"
echo
echo '⇒ 接下来：git add + commit + push（push 后 ls-remote 验真同步）'
echo '⇒ 然后装包、只测 Magnets 一处、看图确认机制通 → 再测其余四款'
