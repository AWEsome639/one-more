#!/bin/bash
# 验游戏 v2（拾海 2026-10-14）—— 用 dump 出来的真实卡片坐标
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
dump() { timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/v.json" >/dev/null 2>&1
         timeout 60 $HDC file recv /data/local/tmp/v.json "$1" >/dev/null 2>&1; }
ntext() { /usr/bin/python3 -c "
import json
try:
    d=json.load(open('$1')); ts=[]
    def w(o):
        a=o.get('attributes',{})
        if a.get('text',''): ts.append(a['text'])
        for c in o.get('children',[]): w(c)
    w(d); print(len(ts))
except: print(0)"; }
# 找出所有【游戏名】的坐标（y∈[1400,1770]、宽 250~420）
cards() { /usr/bin/python3 -c "
import json,re
try:
    d=json.load(open('$1')); rows=[]
    def w(o):
        a=o.get('attributes',{}); t=a.get('text',''); b=a.get('bounds','')
        if t and b:
            m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',b)
            if m:
                x1,y1,x2,y2=map(int,m.groups()); rows.append((t,(x1+x2)//2,(y1+y2)//2,x2-x1,y2-y1))
        for c in o.get('children',[]): w(c)
    w(d)
    skip=('全部 ','经典 ','逻辑 ','数字 ','文字 ','空间 ','记忆 ','反应 ','策略 ','概率 ')
    c=[r for r in rows if 1400<r[2]<1770 and 250<r[3]<420 and 30<r[4]<80
       and not any(r[0].startswith(s) for s in skip)]
    for t,cx,cy,_,_ in sorted(c,key=lambda r:(r[2],r[1])): print('%d %d %s'%(cx,cy,t.replace(' ','')))
except: pass"; }
N=${1:-4}
OK=0; TOT=0
for ROUND in 1 2 3; do
  dump /tmp/vl.json
  while read -r CX CY NAME; do
    [ -z "${CX:-}" ] && continue
    [ "$TOT" -ge "$N" ] && break
    TOT=$((TOT+1))
    timeout 40 $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1; sleep 5
    dump /tmp/vg.json; M=$(ntext /tmp/vg.json)
    # 点场地 3 下
    for t in 1 2 3; do timeout 40 $HDC shell "uitest uiInput click 640 1000" >/dev/null 2>&1; sleep 1; done
    dump /tmp/vg2.json; M2=$(ntext /tmp/vg2.json)
    if [ "${M2:-0}" -ge 8 ]; then echo "  ✅ ${NAME}：${M2} 个文本"; OK=$((OK+1))
    else echo "  ⚠️ ${NAME}：只有 ${M2} 个文本（进入时 $M）"; fi
    timeout 40 $HDC shell "uitest uiInput keyEvent Back" >/dev/null 2>&1; sleep 3
  done < <(cards /tmp/vl.json)
  [ "$TOT" -ge "$N" ] && break
  timeout 40 $HDC shell "uitest uiInput swipe 660 1500 660 700 300" >/dev/null 2>&1; sleep 3
done
echo  "  ★ 通过 ${OK} / ${TOT}"
