#!/bin/bash
# 验指定游戏（按名字，拾海 2026-10-14）
# 用法：bash 工具-验指定游戏.sh "中文名1" "中文名2" ...
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
dump() { timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/z.json" >/dev/null 2>&1
         timeout 60 $HDC file recv /data/local/tmp/z.json "$1" >/dev/null 2>&1; }
texts() { /usr/bin/python3 -c "
import json
try:
    d=json.load(open('$1')); ts=[]
    def w(o):
        a=o.get('attributes',{})
        if a.get('text',''): ts.append(a['text'])
        for c in o.get('children',[]): w(c)
    w(d); print(len(ts))
except: print(0)"; }
# 找某个名字的控件坐标
findone() { /usr/bin/python3 -c "
import json,re,sys
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
    tgt='$2'
    c=[r for r in rows if tgt in r[0]]
    print('%d %d %s'%(c[0][1],c[0][2],c[0][0][:16])) if c else print('')
except: print('')"; }
for NAME in "$@"; do
  FOUND=0
  for ATT in 1 2 3 4 5 6; do
    dump /tmp/s.json
    R=$(findone /tmp/s.json "$NAME")
    if [ -n "$R" ]; then
      CX=$(echo $R | cut -d' ' -f1); CY=$(echo $R | cut -d' ' -f2)
      timeout 40 $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1; sleep 4
      dump /tmp/g.json; N=$(texts /tmp/g.json)
      for t in 1 2 3; do timeout 40 $HDC shell "uitest uiInput click 660 1100" >/dev/null 2>&1; sleep 1; done
      dump /tmp/g2.json; N2=$(texts /tmp/g2.json)
      if [ "${N2:-0}" -ge 8 ]; then echo "  ✅ ${NAME}：进游戏 ${N2} 个文本（点击后）"
      else echo "  ⚠️ ${NAME}：只有 ${N2} 个文本"; fi
      FOUND=1
      timeout 40 $HDC shell "uitest uiInput keyEvent Back" >/dev/null 2>&1; sleep 3
      break
    fi
    timeout 40 $HDC shell "uitest uiInput swipe 660 1500 660 500 300" >/dev/null 2>&1; sleep 2
  done
  [ "$FOUND" = "0" ] && echo "  ❓ ${NAME}：滑了 6 屏没找到"
done
