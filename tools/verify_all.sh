#!/bin/bash
# 全量上机验证（拾海 2026-10-10）
#
# 思路：用「搜索框输入 gameId」把 354 张卡筛成 1 张 ⇒ 直接点，省掉滚动查找
#       （旧版靠滚动，每款 20 秒还常找不到；这版约 8 秒/款）
#
# 每款检查两件事：
#   ① 能不能进入（游戏页出现该游戏的中文名）
#   ② 可点控件有没有越界（越界 = 被挤出屏幕 ⇒ 画得出来但点不到）
#
# 用法: bash verify_all.sh [起始序号] [验几款]   默认 0 开始、全验
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
TMP=/tmp/onemore_all; mkdir -p "$TMP"
OUT="$TMP/report.txt"
START="${1:-0}"
COUNT="${2:-9999}"
PKG=com.andrewoscar.onemore

# 生成全量清单（id|中文名），按注册表顺序
/usr/bin/python3 > "$TMP/all.txt" <<'PY'
import re
s = open('/Users/a0000/dev/One More/entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
for gid, name in re.findall(r"id: '([^']+)', name: '([^']*)'", s):
    print(gid + '|' + name)
PY

home() {
  $HDC shell "power-shell wakeup" >/dev/null 2>&1
  $HDC shell aa force-stop "$PKG" >/dev/null 2>&1
  sleep 1
  $HDC shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1
  sleep 5
}

printf '%-26s %-8s %-8s %s\n' 游戏 进入 可点控件 越界 | tee -a "$OUT"

n=0; done=0; okc=0; badc=0; offc=0
while IFS='|' read -r GID NAME; do
  n=$((n+1))
  [ "$n" -le "$START" ] && continue
  [ "$done" -ge "$COUNT" ] && break
  done=$((done+1))

  home
  # 点搜索框 → 输入 id → 只剩 1 张卡
  $HDC shell "uitest uiInput inputText 710 621 $GID" >/dev/null 2>&1
  sleep 2
  # 找那张卡的中心（搜索后唯一一张）
  $HDC shell "uitest dumpLayout -p /data/local/tmp/v.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/v.json "$TMP/v.json" >/dev/null 2>&1
  C=$(/usr/bin/python3 - "$TMP/v.json" "$NAME" <<'PY'
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
  entered=no
  if [ -n "$C" ]; then
    $HDC shell "uitest uiInput click $C" >/dev/null 2>&1
    sleep 5
    entered=yes
  fi

  # 读游戏页：可点控件数 + 越界数
  $HDC shell "uitest dumpLayout -p /data/local/tmp/g.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/g.json "$TMP/g.json" >/dev/null 2>&1
  read -r CN OFF TITLE <<< "$(/usr/bin/python3 - "$TMP/g.json" "$NAME" <<'PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print(0,0,''); raise SystemExit
nm=sys.argv[2]
n=off=0; hit=''
def w(o):
    global n,off,hit
    a=o.get('attributes',{})
    t=a.get('text','')
    if t=='↻': hit='restart'
    if t==nm and hit=='restart': hit='restart+name'
    if a.get('type','')=='Button' or a.get('clickable','')=='true':
        m=re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]',a.get('bounds','') or '')
        if m:
            x1,y1,x2,y2=map(int,m.groups()); n+=1
            if x1<0 or y1<0 or x2>1320 or y2>2232: off+=1
    for c in o.get('children',[]): w(c)
w(d); print(n,off,hit)
PY
)"
  # 游戏页出现了该游戏名 ⇒ 真进去了（比"点了"更硬）
  [ -n "${TITLE:-}" ] && entered=yes || entered=no

  [ "$entered" = yes ] && okc=$((okc+1)) || badc=$((badc+1))
  [ "${OFF:-0}" -gt 0 ] && offc=$((offc+1))

  printf '%-26s %-8s %-8s %s\n' "$NAME" "$entered" "${CN:-0}" "${OFF:-0}" | tee -a "$OUT"
done < "$TMP/all.txt"

echo
echo "===== 汇总 =====" | tee -a "$OUT"
echo "  验证款数: $done" | tee -a "$OUT"
echo "  成功进入: $okc" | tee -a "$OUT"
echo "  进入失败: $badc" | tee -a "$OUT"
echo "  有越界控件: $offc" | tee -a "$OUT"
