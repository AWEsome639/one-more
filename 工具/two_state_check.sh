#!/bin/bash
# 判据 2873：同一款连测两局，看 lowest 盒子差多少 ⇒ 判断它是「状态相关」还是「稳定」
#
# 用法：bash 工具/two_state_check.sh "Gear Train Direction" [第三款...]
# 前置：设备已起、包已装（本脚本不负责启动模拟器，避免和跑批抢设备）
# 输出：每款两行（state1 / state2）+ 一行结论：STABLE / STATE_DEP(<差值>px)
set -u
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
[ -z "${1:-}" ] && { echo "用法：bash 工具/two_state_check.sh \"游戏名\" [...]"; exit 2; }
if [ -z "$("$HC" list targets 2>/dev/null | head -1)" ]; then
  echo "❌ 没有在线设备（先起模拟器；跑批期间别用本脚本，会抢设备）"; exit 1
fi
box_of() {  # 从一行结果里取 lowest 盒子的 y1/y2
  python3 -c "
import sys,re
ln=open('/tmp/ts_line.txt',encoding='utf-8',errors='replace').read()
m=re.search(r'lowest=.*?\[(\d+),(\d+)\]\[(\d+),(\d+)\]', ln)
print('%s %s' % (m.group(2), m.group(4)) if m else '- -')
"
}
fail=0
for g in "$@"; do
  echo "───── $g ─────"
  for pass in 1 2; do
    SHOT_BUDGET_S=${SHOT_BUDGET_S:-260} timeout 300 python3 工具/shot_game.py "$g" 2>&1 | tail -1 > /tmp/ts_line.txt
    read -r y1 y2 < <(box_of)
    st=$(awk -F'\t' '{print $2}' /tmp/ts_line.txt)
    echo "  state$pass: $st  y1=${y1:-?} y2=${y2:-?}"
    eval "Y${pass}1=$y1; Y${pass}2=$y2"
  done
  if [ "${Y11:--}" != "-" ] && [ "${Y21:--}" != "-" ]; then
    d1=$((Y21 - Y11)); d1=${d1#-}
    d2=$((Y22 - Y12)); d2=${d2#-}
    d=$d1; [ "$d2" -gt "$d1" ] && d=$d2
    if [ "$d" -gt 50 ]; then
      echo "  ⇒ ⚠️ STATE_DEP（两局差 ${d}px > 50px）⇒ 布局随题面变，必须按最坏情况留余量"
      fail=$((fail+1))
    else
      echo "  ⇒ ✅ STABLE（两局差 ${d}px ≤ 50px）"
    fi
  else
    echo "  ⇒ ⚠️ 两局里有一次没测到（看上面的状态码）"
    fail=$((fail+1))
  fi
done
echo "───── 汇总：$# 款里 $fail 款需要按「状态相关」处理 ─────"
exit 0
