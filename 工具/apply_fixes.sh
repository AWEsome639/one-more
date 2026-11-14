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
fix "$G/GMagnets.ets"            701 'Math.max(140, Bp.height - 360)' 'Math.max(140, Bp.height - 375)' '①Magnets 盘面 -375'
fix "$G/GFractionMatcher.ets"    335 '.padding(Space.lg)'              '.padding(Space.md)'               '②FractionMatcher 题卡 padding'
fix "$G/GPercentageShopping.ets" 402 '.padding(Space.lg)'              '.padding(Space.md)'               '③PercentageShopping 题卡 padding'
fix "$G/GKakuroMini.ets"         562 'Math.max(120, Bp.height - 360)' 'Math.max(120, Bp.height - 390)' '④KakuroMini 盘面 -390'

echo
echo "==== 结果：成功 ${ok}、失败 $bad ===="
echo '⚠️ ⑤Wordle 套 Scroll 是结构改动、不在本脚本内（需手工加 Scroll() { … }，见补丁规格）'
[ "$bad" = 0 ] || exit 1
