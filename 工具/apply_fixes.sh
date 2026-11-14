#!/bin/bash
# 明晚的五处功能级修复 —— 逐条「先验证字符串在该行、再替换」，任何一条不匹配就停。
# 用法：bash 工具/apply_fixes.sh --dry   # 只检查（不写文件）
#       bash 工具/apply_fixes.sh         # 真改
#
# 依据：_巡检记录/★★★★★★★功能级修复计划-五处改点带行号带数值-20261114.md
# ⚠️ 每次只应跑一次；跑完编译 + 断言 200359/0 + 装包 + 看图。
set -u
cd "/Users/a0000/dev/One More" || exit 1
DRY=0; [ "${1:-}" = '--dry' ] && DRY=1
ok=0; bad=0

fix() {   # fix <文件> <行号> <旧串> <新串> <说明>
  local f="$1" n="$2" old="$3" new="$4" desc="$5"
  local actual; actual=$(sed -n "${n}p" "$f")
  if ! printf '%s' "$actual" | grep -qF "$old"; then
    echo "❌ ${desc}：第 ${n} 行里找不到「${old}」"
    echo "   实际：$(printf '%s' "$actual" | cut -c1-90)"
    bad=$((bad+1)); return
  fi
  if [ "$DRY" = 1 ]; then echo "✅ ${desc}：命中（dry，不写）"; ok=$((ok+1)); return; fi
  python3 - "$f" "$n" "$old" "$new" <<'PY'
import io,sys
f,n,old,new=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4]
L=io.open(f,encoding='utf-8').read().split('\n')
assert old in L[n-1], 'line mismatch'
L[n-1]=L[n-1].replace(old,new,1)
io.open(f,'w',encoding='utf-8').write('\n'.join(L))
PY
  if sed -n "${n}p" "$f" | grep -qF "$new"; then echo "✅ ${desc}：已改"; ok=$((ok+1))
  else echo "❌ ${desc}：改后校验失败"; bad=$((bad+1)); fi
}

G=entry/src/main/ets/games
# ★ 2026-11-14 取证时效审计后的分档：
#   A 档（测的是当前代码 ⇒ 确认要改）：Magnets / FractionMatcher
#   B 档（测的是旧代码 ⇒ 可能已修好，**需显式 --with-b 才改**）：PercentageShopping / KakuroMini
#   Wordle 的 Scroll 在另一个脚本（apply_wordle_scroll.py）
WITH_B=0
for a in "$@"; do [ "$a" = '--with-b' ] && WITH_B=1; done

fix "$G/GMagnets.ets"            701 'Math.max(140, Bp.height - 360)' 'Math.max(140, Bp.height - 375)' 'A①Magnets 盘面 -375'
fix "$G/GFractionMatcher.ets"    335 '.padding(Space.lg)'              '.padding(Space.md)'               'A②FractionMatcher 题卡 padding'

# A③ Pythagorean Triple Builder：底部行（⌫/0/确认）被屏底截断
#     外层 Column 间距 Space.sm(10vp) → Space.xs(6vp)，6 处 ⇒ 省 24vp = 72px
#     ⚠️ 只影响矮屏（Bp.height < 600），桌面/TV 保持 Space.md 不变
fix "$G/GPythagoreanTripleBuilder.ets" 313 '? Space.sm : Space.md' '? Space.xs : Space.md' 'A③PTB 外层间距 sm→xs（省 72px）'
#     若 A③ 不够（确认 仍被切）⇒ 再叠加这行：
# fix "$G/GPythagoreanTripleBuilder.ets" 344 ".padding(Space.md)" ".padding(Space.sm)" 'A③b PTB 题干卡 padding md→sm（+36px）'

if [ "$WITH_B" = 1 ]; then
  echo '⚠️ 已显式开启 B 档（那两款测的是旧代码、可能已修好）'
  fix "$G/GPercentageShopping.ets" 402 '.padding(Space.lg)'              '.padding(Space.md)'               'B③PercentageShopping 题卡 padding'
  # ⛔ B④ 已停用（2026-11-14）：它要在 L562 把 `- 360` 改成 `- 390`，而 `-360` 是 07:06 刚调上来的
  #    （`-320 → -360`，值 40vp）。若今晚数据显示键盘已完整 ⇒ 这一改就是**过度修正**。
  #    ⇒ 所以不自动改；等今晚数据说「仍被切」再决定数值（候选 -375：再收 15vp=45px）。
  echo '⏸  B④ KakuroMini 未应用（-360 是 07:06 刚调的；先看今晚数据，若键盘仍被切再改 -375/-390）'
  # fix "$G/GKakuroMini.ets" 562 'Math.max(120, Bp.height - 360)' 'Math.max(120, Bp.height - 375)' 'B④KakuroMini 盘面 -375（需数据确认）'
else
  echo '⏭  B 档（PercentageShopping / KakuroMini）跳过 —— 它们测的是旧代码，先用今晚数据确认；确定要改再跑 --with-b'
fi

echo
echo "==== 结果：成功 ${ok}、失败 $bad ===="
echo '⚠️ ⑤Wordle 套 Scroll 是结构改动、不在本脚本内（需手工加 Scroll() { … }，见补丁规格）'
[ "$bad" = 0 ] || exit 1
