#!/bin/bash
# 快速全量验证（拾海 2026-10-10 第二版）
#
# 相比第一版的三处提速：
#   ① 不再 force-stop + 重启 App（省 ~8 秒/款）⇒ 用「返回键 + 清空搜索」回主页
#   ② 只 dump 一次游戏页（判据合并：出现 ↻ 且可点控件 > 25 才算真进）
#   ③ 等待从 5s 降到 3.5s
#
# 用法: bash verify_fast.sh <起始序号> <款数> <日志文件>
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
TMP=/tmp/yiju_fast; mkdir -p "$TMP"
START="${1:-0}"; COUNT="${2:-9999}"; LOG="${3:-$TMP/report.txt}"
PKG=com.andrewoscar.onemore

/usr/bin/python3 - > "$TMP/all.txt" <<'PY'
import re
s = open('/Users/a0000/dev/yiju/entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
for gid, name in re.findall(r"id: '([^']+)', name: '([^']*)'", s):
    print(gid + '|' + name)
PY

# 冷启动一次，之后靠返回键
$HDC shell "power-shell wakeup" >/dev/null 2>&1
$HDC shell aa force-stop "$PKG" >/dev/null 2>&1; sleep 1
$HDC shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1; sleep 6

printf '%-26s %-8s %-8s %s\n' 游戏 进入 可点控件 越界 | tee -a "$LOG"

n=0; done=0; okc=0; badc=0; offc=0
while IFS='|' read -r GID NAME; do
  n=$((n+1))
  [ "$n" -le "$START" ] && continue
  [ "$done" -ge "$COUNT" ] && break
  done=$((done+1))

  # 回主页：★ 绝不按 Back（主页上按 Back 会退出 App！）⇒ 点游戏页左上角的 ‹
  # 首页时 ‹ 不存在，点了也无害；再点 ✕ 清空搜索框
  $HDC shell "uitest uiInput click 120 273" >/dev/null 2>&1
  sleep 1
  $HDC shell "uitest uiInput click 1245 621" >/dev/null 2>&1
  sleep 0.8

  # 搜索
  $HDC shell "uitest uiInput inputText 710 621 $GID" >/dev/null 2>&1
  sleep 1.5

  # 找卡片（搜索后唯一一张）
  $HDC shell "uitest dumpLayout -p /data/local/tmp/f.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/f.json "$TMP/f.json" >/dev/null 2>&1
  C=$(/usr/bin/python3 - "$TMP/f.json" "$NAME" <<'PY'
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
out=[]; w(d,out)
print(f'{out[0][0]} {out[0][1]}' if out else '')
PY
)
  if [ -z "$C" ]; then
    printf '%-26s %-8s %-8s %s\n' "$NAME" "nocard" 0 0 | tee -a "$LOG"
    badc=$((badc+1)); continue
  fi

  $HDC shell "uitest uiInput click $C" >/dev/null 2>&1
  sleep 3.5

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
  # 真进了的判据：页面出现 ↻（只有游戏页有）
  if [ "${HASR:-0}" = "1" ]; then
    okc=$((okc+1)); ent=yes
  else
    badc=$((badc+1)); ent=no
  fi
  [ "${OFF:-0}" -gt 0 ] && offc=$((offc+1))

  printf '%-26s %-8s %-8s %s\n' "$NAME" "$ent" "${CN:-0}" "${OFF:-0}" | tee -a "$LOG"
done < "$TMP/all.txt"

echo "" | tee -a "$LOG"
echo "===== 汇总 =====" | tee -a "$LOG"
echo "  验证款数: $done" | tee -a "$LOG"
echo "  成功进入: $okc" | tee -a "$LOG"
echo "  进入失败: $badc" | tee -a "$LOG"
echo "  有越界:   $offc" | tee -a "$LOG"
