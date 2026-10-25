#!/bin/bash
# 抽样上机验证（拾海 2026-10-10）：从 354 款里均匀抽 N 款，逐个进入并检查控件越界
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
TMP=/tmp/onemore_sample; mkdir -p "$TMP"
N="${1:-24}"

# 从注册表均匀抽样
/usr/bin/python3 - "$N" > "$TMP/sample.txt" <<'PY'
import re, sys
n = int(sys.argv[1])
s = open('/Users/a0000/dev/One More/entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
rows = re.findall(r"id: '([^']+)', name: '([^']*)'", s)
step = max(1, len(rows)//n)
for i in range(0, len(rows), step):
    print(rows[i][0] + '|' + rows[i][1])
PY

printf '%-26s %-8s %-8s %s\n' 游戏 进入 可点控件 越界
while IFS='|' read -r GID NAME; do
  $HDC shell "power-shell wakeup" >/dev/null 2>&1
  $HDC shell aa force-stop com.andrewoscar.onemore >/dev/null 2>&1
  sleep 1
  $HDC shell aa start -a EntryAbility -b com.andrewoscar.onemore >/dev/null 2>&1
  sleep 5
  # 滚到该卡片（最多 12 屏）
  ok=no
  for try in $(seq 1 12); do
    $HDC shell "uitest dumpLayout -p /data/local/tmp/s.json" >/dev/null 2>&1
    $HDC file recv /data/local/tmp/s.json "$TMP/s.json" >/dev/null 2>&1
    C=$(/usr/bin/python3 - "$TMP/s.json" "$NAME" <<'PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: raise SystemExit
nm=sys.argv[2]
def w(o,out):
    a=o.get('attributes',{})
    if a.get('text','')==nm:
        m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',a.get('bounds','') or '')
        if m:
            x1,y1,x2,y2=map(int,m.groups())
            if y2<=2232: out.append(((x1+x2)//2,(y1+y2)//2))
    for c in o.get('children',[]): w(c,out)
out=[]; w(d,out)
print(f'{out[0][0]} {out[0][1]}' if out else '')
PY
)
    if [ -n "$C" ]; then
      $HDC shell "uitest uiInput click $C" >/dev/null 2>&1; sleep 5; ok=yes; break
    fi
    $HDC shell "uitest uiInput fling 660 1500 660 700 1500 80" >/dev/null 2>&1; sleep 1
  done
  $HDC shell "uitest dumpLayout -p /data/local/tmp/g.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/g.json "$TMP/g.json" >/dev/null 2>&1
  read -r CN OFF <<< "$(/usr/bin/python3 - "$TMP/g.json" <<'PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print(0,0); raise SystemExit
n=off=0
def w(o):
    global n,off
    a=o.get('attributes',{})
    if a.get('type','')=='Button' or a.get('clickable','')=='true':
        m=re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]',a.get('bounds','') or '')
        if m:
            x1,y1,x2,y2=map(int,m.groups()); n+=1
            if x1<0 or y1<0 or x2>1320 or y2>2232: off+=1
    for c in o.get('children',[]): w(c)
w(d); print(n,off)
PY
)"
  printf '%-26s %-8s %-8s %s\n' "$NAME" "$ok" "${CN:-0}" "${OFF:-0}"
done < "$TMP/sample.txt"
