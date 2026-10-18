#!/bin/bash
# 一局 · 12 个游戏批量上机体检（拾海 2026-10-10）
#
# 判据（都是可量化的，不靠肉眼）：
#   ① 能否从主页进入（dumpLayout 里出现该游戏标题）
#   ② 所有可点控件的 bounds 是否在屏幕内（x∈[0,1320], y∈[0,2232]）
#      —— 这是今天真踩到的 bug 类型：内容溢出 ⇒ 控件画得出来但点不到
#   ③ 可点控件数量（少于 3 个说明交互元素太少，可能没做成可玩）
#
# 用法: bash verify_games.sh
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
W=1320; H=2232
TMP=/tmp/yiju_verify; mkdir -p "$TMP"
OUT="$TMP/report.txt"; : > "$OUT"

# 游戏清单：id|主页卡片上的字|期望进页后标题
GAMES=(
  "g2048|2048|2048"
  "minesweeper|扫雷|扫雷"
  "sudoku|数独|数独"
  "memory|记忆翻牌|记忆翻牌"
  "slide15|数字华容道|数字华容道"
  "sokoban|推箱子|推箱子"
  "hanoi|汉诺塔|汉诺塔"
  "schulte|舒尔特|舒尔特"
  "game24|24 点|24 点"
  "snake|贪吃蛇|贪吃蛇"
  "breakout|打砖块|打砖块"
  "gomoku|五子棋|五子棋"
)

dump() {  # dump 到 $TMP/$1.json
  $HDC shell "uitest dumpLayout -p /data/local/tmp/$1.json" >/dev/null 2>&1
  $HDC file recv "/data/local/tmp/$1.json" "$TMP/$1.json" >/dev/null 2>&1
}

home() {
  $HDC shell "power-shell wakeup" >/dev/null 2>&1
  $HDC shell aa force-stop com.andrewoscar.onemore >/dev/null 2>&1
  sleep 1
  $HDC shell aa start -a EntryAbility -b com.andrewoscar.onemore >/dev/null 2>&1
  sleep 6
}

printf '%-14s %-6s %-8s %-8s %s\n' 游戏 进入 可点控件 越界控件 结论 | tee -a "$OUT"
printf '%s\n' "--------------------------------------------------------------------------" | tee -a "$OUT"

for row in "${GAMES[@]}"; do
  IFS='|' read -r ID CARD TITLE <<< "$row"
  home
  ok=no;  tries=0
  while [ $tries -lt 4 ]; do
    dump "s_${ID}"
    C=$(/usr/bin/python3 - "$TMP/s_${ID}.json" "$CARD" <<'PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit()
name=sys.argv[2]; res=[]
def w(o):
    a=o.get('attributes',{})
    if name in a.get('text',''): res.append(a.get('bounds'))
    for c in o.get('children',[]): w(c)
w(d)
for b in res:
    m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',b or '')
    if m:
        x1,y1,x2,y2=map(int,m.groups())
        if y2<=2232: print((x1+x2)//2,(y1+y2)//2); break
PY
)
    if [ -n "$C" ]; then
      $HDC shell "uitest uiInput click $C" >/dev/null 2>&1
      sleep 4
      ok=yes; break
    fi
    # 没找到 ⇒ 往下滚一屏再试
    $HDC shell "uitest uiInput fling 660 1500 660 700 1200 60" >/dev/null 2>&1
    sleep 2; tries=$((tries+1))
  done

  dump "g_${ID}"
  read -r N OFF <<< "$(/usr/bin/python3 - "$TMP/g_${ID}.json" "$W" "$H" <<'PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print(0,0); sys.exit()
W,H=int(sys.argv[2]),int(sys.argv[3]); n=off=0
def w(o):
    global n,off
    a=o.get('attributes',{})
    # 可点控件：Button/Text 且带 clickable 或就是按钮类
    t=a.get('type',''); clk=a.get('clickable','')
    if t in ('Button',) or (clk=='true'):
        m=re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]',a.get('bounds','') or '')
        if m:
            x1,y1,x2,y2=map(int,m.groups()); n+=1
            if x1<0 or y1<0 or x2>W or y2>H: off+=1
    for c in o.get('children',[]): w(c)
w(d); print(n,off)
PY
)"
  verdict="✅ 可玩"
  [ "$ok" = "no" ] && verdict="❌ 进不去"
  [ "${OFF:-0}" -gt 0 ] && verdict="⚠️ ${OFF} 个控件越界"
  [ "${N:-0}" -lt 3 ] && [ "$ok" = "yes" ] && verdict="⚠️ 可点控件仅 ${N} 个"
  printf '%-14s %-6s %-8s %-8s %s\n' "$ID" "$ok" "${N:-0}" "${OFF:-0}" "$verdict" | tee -a "$OUT"
done

echo
echo "完整报告: $OUT"
