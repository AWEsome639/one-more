#!/bin/bash
# 按名单重测（拾海 2026-10-10）
# 用法: bash verify_list.sh <id列表文件，每行一个 id|中文名> <日志>
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
TMP=/tmp/yiju_list; mkdir -p "$TMP"
LIST="$1"; LOG="${2:-$TMP/report.txt}"
PKG=com.andrewoscar.onemore

$HDC shell "power-shell wakeup" >/dev/null 2>&1
$HDC shell aa force-stop "$PKG" >/dev/null 2>&1; sleep 1
$HDC shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1; sleep 8

printf '%-26s %-8s %-8s %s\n' 游戏 进入 可点控件 越界 | tee -a "$LOG"
ok=0; bad=0; off=0; n=0
while IFS='|' read -r GID NAME; do
  [ -z "$GID" ] && continue
  n=$((n+1))
  # ★ 先确认 App 在前台：不在就重启（曾因点在桌面上误开通讯录，全批作废）
  $HDC shell "uitest dumpLayout -p /data/local/tmp/chk.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/chk.json "$TMP/chk.json" >/dev/null 2>&1
  UP=$(/usr/bin/python3 -c "
import json
try: d=json.load(open('$TMP/chk.json'))
except Exception: print('no'); raise SystemExit
found=[0]
def w(o):
    a=o.get('attributes',{})
    if a.get('text','')=='一局': found[0]=1
    for c in o.get('children',[]): w(c)
w(d); print('yes' if found[0] else 'no')" 2>/dev/null)
  if [ "$UP" != "yes" ]; then
    $HDC shell aa force-stop "$PKG" >/dev/null 2>&1; sleep 1
    $HDC shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1; sleep 7
  fi
  $HDC shell "uitest uiInput click 120 273" >/dev/null 2>&1; sleep 1
  $HDC shell "uitest uiInput click 1245 621" >/dev/null 2>&1; sleep 0.8
  $HDC shell "uitest uiInput inputText 710 621 $GID" >/dev/null 2>&1; sleep 2.5
  $HDC shell "uitest dumpLayout -p /data/local/tmp/r.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/r.json "$TMP/r.json" >/dev/null 2>&1
  C=$(/usr/bin/python3 - "$TMP/r.json" "$NAME" <<'PY'
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
            if y1 > 700 and y2 <= 2232: out.append(((x1+x2)//2,(y1+y2)//2))
    for c in o.get('children',[]): w(c,out)
out=[]; w(d,out); print(f'{out[0][0]} {out[0][1]}' if out else '')
PY
)
  if [ -z "$C" ]; then
    printf '%-26s %-8s %-8s %s\n' "$NAME" "nocard" 0 0 | tee -a "$LOG"; bad=$((bad+1)); continue
  fi
  $HDC shell "uitest uiInput click $C" >/dev/null 2>&1; sleep 3.5
  $HDC shell "uitest dumpLayout -p /data/local/tmp/g.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/g.json "$TMP/g.json" >/dev/null 2>&1
  read -r CN OFF HASR <<< "$(/usr/bin/python3 - "$TMP/g.json" <<'PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print(0,0,0); raise SystemExit
n=off=0; hasr=0
def w(o):
    global n,off,hasr
    a=o.get('attributes',{})
    if a.get('text','')=='↻': hasr=1
    if a.get('type','')=='Button' or a.get('clickable','')=='true':
        m=re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]',a.get('bounds','') or '')
        if m:
            x1,y1,x2,y2=map(int,m.groups()); n+=1
            if x1<0 or y1<0 or x2>1320 or y2>2232: off+=1
    for c in o.get('children',[]): w(c)
w(d); print(n,off,hasr)
PY
)"
  if [ "${HASR:-0}" = "1" ]; then ent=yes; ok=$((ok+1)); else ent=no; bad=$((bad+1)); fi
  [ "${OFF:-0}" -gt 0 ] && off=$((off+1))
  printf '%-26s %-8s %-8s %s\n' "$NAME" "$ent" "${CN:-0}" "${OFF:-0}" | tee -a "$LOG"
done < "$LIST"
echo | tee -a "$LOG"
echo "  重测 $n 款 · 成功 $ok · 失败 $bad · 有越界 $off" | tee -a "$LOG"
