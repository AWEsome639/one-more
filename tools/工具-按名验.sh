#!/bin/bash
# 按名字验游戏（拾海 2026-10-14 v6）—— 用已摸清的列表坐标 + 名字匹配
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
dump() { timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/w.json" >/dev/null 2>&1
         timeout 60 $HDC file recv /data/local/tmp/w.json "$1" >/dev/null 2>&1; }
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
findone() { /usr/bin/python3 -c "
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
    c=[r for r in rows if '$1' in r[0].replace(' ','') and 1400<r[2]<1800]
    print('%d %d %s'%(c[0][1],c[0][2],c[0][0].replace(' ',''))) if c else print('')
except: print('')"; }
for NAME in "$@"; do
  GOT=0
  for ATT in 1 2 3 4 5 6 7 8; do
    dump /tmp/n.json
    R=$(findone /tmp/n.json "$NAME")
    if [ -n "$R" ]; then
      CX=$(echo "$R" | cut -d' ' -f1); CY=$(echo "$R" | cut -d' ' -f2)
      timeout 40 $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1; sleep 5
      dump /tmp/ng.json; M=$(ntext /tmp/ng.json)
      for t in 1 2 3; do timeout 40 $HDC shell "uitest uiInput click 640 1000" >/dev/null 2>&1; sleep 1; done
      dump /tmp/ng2.json; M2=$(ntext /tmp/ng2.json)
      if [ "${M2:-0}" -ge 8 ]; then echo "  ✅ ${NAME}：${M2} 个文本"
      else echo "  ⚠️ ${NAME}：只有 ${M2} 个文本"; fi
      GOT=1
      timeout 40 $HDC shell "uitest uiInput keyEvent Back" >/dev/null 2>&1; sleep 3
      break
    fi
    timeout 40 $HDC shell "uitest uiInput swipe 660 1500 660 800 300" >/dev/null 2>&1; sleep 3
  done
  [ "$GOT" = "0" ] && echo "  ❓ ${NAME}：滑 8 屏没找到"
done
