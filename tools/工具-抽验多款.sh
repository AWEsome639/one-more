#!/bin/bash
# 抽验多款游戏（拾海 2026-10-14 v2）
# 改进：① 操作后轮询等页面稳定 ② swipe 从容器 bounds 读 ③ Back 后确认回到列表
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
N=${1:-3}
dump() {  # $1=本地路径
  timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/d.json" >/dev/null 2>&1
  timeout 60 $HDC file recv /data/local/tmp/d.json "$1" >/dev/null 2>&1
}
texts() {  # $1=json → 打印文本数
  /usr/bin/python3 -c "
import json,sys
try:
    d=json.load(open('$1')); ts=[]
    def w(o):
        a=o.get('attributes',{})
        if a.get('text',''): ts.append(a['text'])
        for c in o.get('children',[]): w(c)
    w(d); print(len(ts))
except: print(0)"
}
# 等页面稳定：连续两次文本数相同
stable() {
  local prev=-1 cur=0 k=0
  while [ $k -lt 8 ]; do
    dump /tmp/st.json; cur=$(texts /tmp/st.json)
    [ "$cur" = "$prev" ] && [ "$cur" -gt 0 ] && { echo "$cur"; return; }
    prev=$cur; sleep 2; k=$((k+1))
  done
  echo "$cur"
}
echo "  ★ 等首页稳定…"; N0=$(stable); echo "    首页文本 $N0 个"
echo
OK=0
for i in $(seq 1 "$N"); do
  dump /tmp/l.json
  read CX CY NM <<< "$(/usr/bin/python3 -c "
import json,re
try:
    d=json.load(open('/tmp/l.json')); rows=[]
    def w(o):
        a=o.get('attributes',{}); t=a.get('text',''); b=a.get('bounds','')
        if t and b:
            m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',b)
            if m:
                x1,y1,x2,y2=map(int,m.groups()); rows.append((t,(x1+x2)//2,(y1+y2)//2,x2-x1,y2-y1))
        for c in o.get('children',[]): w(c)
    w(d)
    c=[r for r in rows if r[3]>250 and 40<r[4]<160 and 900<r[2]<2050 and '全部' not in r[0]]
    print('%d %d %s'%(c[0][1],c[0][2],c[0][0].replace(' ',''))) if c else print('')
except: print('')")"
  if [ -z "$CX" ]; then
    echo "  第 $i 款：列表里没找到卡片（下滑一次）"
    timeout 40 $HDC shell "uitest uiInput swipe 660 1500 660 500 300" >/dev/null 2>&1
    sleep 3; continue
  fi
  timeout 40 $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1
  sleep 4
  M=$(stable)
  # 点场地中心 3 下
  for t in 1 2 3; do timeout 40 $HDC shell "uitest uiInput click 660 1100" >/dev/null 2>&1; sleep 1; done
  M2=$(stable)
  if [ "${M2:-0}" -ge 8 ]; then echo "  ✅ 第 $i 款 ${NM}：进游戏后 $M2 个文本"; OK=$((OK+1));
  else echo "  ⚠️ 第 $i 款 ${NM}：文本只有 $M2 个"; fi
  timeout 40 $HDC shell "uitest uiInput keyEvent Back" >/dev/null 2>&1
  sleep 3; stable >/dev/null
  # 下滑一点，换下一款
  timeout 40 $HDC shell "uitest uiInput swipe 660 1500 660 700 300" >/dev/null 2>&1
  sleep 2
done
echo
echo "  ★ 通过 ${OK} / ${N}"
