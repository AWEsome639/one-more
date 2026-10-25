#!/bin/bash
# 分类验游戏（拾海 2026-10-14 v7）
# 用法：bash 工具-分类验.sh <分类X> <名字1> [名字2] ...
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
dump() { timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/y.json" >/dev/null 2>&1
         timeout 60 $HDC file recv /data/local/tmp/y.json "$1" >/dev/null 2>&1; }
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
CATX=$1; shift
# 点分类标签
timeout 40 $HDC shell "uitest uiInput click $CATX 1310" >/dev/null 2>&1; sleep 4
for NAME in "$@"; do
  GOT=0
  for ATT in 1 2 3 4 5 6; do
    dump /tmp/k.json
    R=$(/usr/bin/python3 -c "
import json,re
try:
    d=json.load(open('/tmp/k.json')); rows=[]
    def w(o):
        a=o.get('attributes',{}); t=a.get('text',''); b=a.get('bounds','')
        if t and b:
            m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',b)
            if m:
                x1,y1,x2,y2=map(int,m.groups()); rows.append((t,(x1+x2)//2,(y1+y2)//2,x2-x1,y2-y1))
        for c in o.get('children',[]): w(c)
    w(d)
    c=[r for r in rows if '$NAME' in r[0].replace(' ','') and 250<r[3]<430 and 30<r[4]<95 and r[2]>1350]
    print('%d %d %s'%(c[0][1],c[0][2],c[0][0].replace(' ',''))) if c else print('')
except: print('')")
    if [ -n "$R" ]; then
      CX=$(echo "$R" | cut -d' ' -f1); CY=$(echo "$R" | cut -d' ' -f2)
      timeout 40 $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1; sleep 5
      dump /tmp/kg.json; M=$(ntext /tmp/kg.json)
      for t in 1 2 3; do timeout 40 $HDC shell "uitest uiInput click 640 1000" >/dev/null 2>&1; sleep 1; done
      dump /tmp/kg2.json; M2=$(ntext /tmp/kg2.json)
      if [ "${M2:-0}" -ge 8 ]; then echo "  ✅ ${NAME}：${M2} 个文本"; else echo "  ⚠️ ${NAME}：只有 ${M2} 个"; fi
      GOT=1
      timeout 40 $HDC shell "uitest uiInput keyEvent Back" >/dev/null 2>&1; sleep 3
      break
    fi
    timeout 40 $HDC shell "uitest uiInput swipe 660 1600 660 900 300" >/dev/null 2>&1; sleep 3
  done
  [ "$GOT" = "0" ] && echo "  ❓ ${NAME}：该分类下没找到"
done
