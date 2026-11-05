#!/usr/bin/env bash
# ============================================================================
#  工具/shoot_a11y_nine.sh —— **色盲 9 款逐款截图**（一次起机跑完）
#
#  ★ 为什么（判据 1273/1275/1277，第 1389 轮）
#    goal 待办：「色盲 9 款逐款截图」—— 而实测 9 款里 **8 款无截图**
#    · `A11y.glyph` 是**常驻设计**（无开关，见 `core/A11y.ets`）
#      ⇒ 不需要开设置，进游戏就能看见「颜色之外的字形」
#    · 而 `ai_play/hint_verified.jsonl` 已是 **355/355 = 100%**
#      ⇒ 「未逐款留图」= **缺 PNG**，不是缺验证
#
#  ★ 判据 1278：一次起机能验多款 —— 导航链 =「搜索 → 进入 → 截图 → Back」
#  ★ 判据 1246：**每步 `pidof` 校验**，⛔ 不假设 app 在前台
#  ★ 判据 1253/1254：搜索用**中文名**，⛔ 不用 ASCII 前缀
#
#  用法：bash 工具/shoot_a11y_nine.sh [设备名，默认 onemore3]
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
INST="${1:-onemore3}"
TAG="$(date +%Y%m%d)"
OUT="验收截图-v1.0.1"
YF="/tmp/yes_emu.txt"

# 9 款：(中文名, 英文 id) —— ★ 判据 1198：中文不经过参数，直接内联
GAMES=$(python3 - <<'PY'
import io, re
reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
pairs = dict(re.findall(r"\{ id: '([a-z0-9_]+)', name: '([^']+)'", reg))
targets = ['water_sort','bubble_shooter','visual_search_conjunction','simon_says',
           'color_maze_nav','mastermind','color_flood','color_match','wisconsin_card_sorting']
for t in targets:
    print('%s\t%s' % (t, pairs.get(t, '?')))
PY
)

printf 'y\ny\ny\ny\ny\ny\n' > "$YF"
A() { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
DK() { rm -f /tmp/s9.json; A "uitest dumpLayout -p /data/local/tmp/_s9.json" >/dev/null 2>&1; timeout 20 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_s9.json /tmp/s9.json >/dev/null 2>&1; }
PIDOK() { local P; P=$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}'); printf '%s' "$P" | grep -qE '^[0-9]+$'; }
POS() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = sys.argv[1]
d = json.load(open('/tmp/s9.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if want in (at.get('text') or '') and b(at):
        bb=b(at); r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
INPUTPOS() { python3 -c "
import json,re
d=json.load(open('/tmp/s9.json',encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if (at.get('type') or '')=='TextInput' and b(at):
        bb=b(at); r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
" 2>/dev/null | tr -d '\r\n'; }
CARDPOS() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = 'card-' + sys.argv[1]
d = json.load(open('/tmp/s9.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if (at.get('id') or '')==want:
        bb=b(at)
        if bb: r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
TXT() { python3 -c "
import json,os
p='/tmp/s9.json'
if not os.path.exists(p) or os.path.getsize(p)<1000: print(''); raise SystemExit
d=json.load(open(p,encoding='utf-8')); t=[]
def w(x):
    if not isinstance(x,dict): return
    s=(x.get('attributes',{}).get('text') or '').strip()
    if s: t.append(s)
    for c in x.get('children',[]) or []: w(c)
w(d)
print('|'.join(t))
" 2>/dev/null; }

echo '──────────────── 起机 ────────────────'
for N in onemore onemore2 onemore3 onemore4 onemore5 onemore6; do timeout 20 "$EMU" -stop "$N" >/dev/null 2>&1; done
sleep 6
nohup bash -c "\"$EMU\" -start \"$INST\" < \"$YF\"" > /tmp/s9_boot.log 2>&1 &
ON=0
for i in $(seq 1 45); do
  sleep 10
  T=$(timeout 6 "$HC" list targets 2>/dev/null | grep -c '127.0.0.1:5555')
  [ "${T:-0}" -ge 1 ] && { echo "  在线 @ $((i*10))s"; ON=1; break; }
done
[ "$ON" != "1" ] && { echo '🔴 未在线'; exit 1; }
timeout 6 "$HC" tconn 127.0.0.1:5555 >/dev/null 2>&1
for k in $(seq 1 15); do
  sleep 10
  rm -f /tmp/s9b.png
  A "snapshot_display -w 200 -h 338 -t png -f /data/local/tmp/_s9b.png" >/dev/null 2>&1
  timeout 12 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_s9b.png /tmp/s9b.png >/dev/null 2>&1
  L=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/s9b.png'
print('%.0f' % np.array(Image.open(p).convert('RGB')).mean() if (os.path.exists(p) and os.path.getsize(p)>800) else '-1')
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${L:--1}')>20 else 1)" 2>/dev/null && { echo "  亮度 ${L}"; break; }
  A 'power-shell wakeup' >/dev/null 2>&1
done
timeout 1200 "$HC" -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-signed.hap > /tmp/s9i.log 2>&1
CNT=$(A 'bm dump -a 2>/dev/null | grep -c "com.andrewoscar.onemore"' | tr -d ' ')
echo "  装机回执: $(grep -oE 'msg:[^,]*' /tmp/s9i.log | head -1) ｜ bm=$CNT"
[ "${CNT:-0}" -lt 1 ] && { echo '🔴 未装上'; exit 1; }

echo
echo '──────────────── 9 款逐款截图 ────────────────'
PASS=0; FAIL=0; FAILED=""
echo "$GAMES" | while IFS=$'\t' read -r GID NAME; do
  [ -z "$GID" ] && continue
  echo "  ══ ${NAME}（${GID}）══"
  # 判据 1246：每款开始前校验 app 在前台
  if ! PIDOK; then
    A 'aa start -b com.andrewoscar.onemore -a EntryAbility' >/dev/null 2>&1
    for t in 4 5 7; do sleep $t; PIDOK && break; done
  fi
  # 回首页（一次 Back；若已在首页则无副作用）
  DK
  if TXT | grep -q 'AI 代打\|重开'; then
    A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 3
  fi
  DK
  # ★★★ 判据 1279/1280：**先检测搜索框是否已开着**
  #   `searchOpen` 是**切换**不是「打开」⇒ 背靠背跑多款时，
  #   上一款留下的 `searchOpen = true` 会让「再点 🔍」变成**关闭**
  #   ⇒ 每轮先 `INPUTPOS`：有输入框就不点 🔍，没有才点
  SB="$(INPUTPOS)"
  if [ -n "$SB" ]; then
    echo "    （搜索框已开着 ⇒ 不点 🔍，判据 1279）"
  else
    SR=$(POS "🔍")
    [ -n "$SR" ] && { A "uitest uiInput click ${SR}" >/dev/null 2>&1; sleep 3; DK; }
    SB=$(INPUTPOS)
  fi
  [ -z "$SB" ] && { echo "    🔴 无搜索框"; continue; }
  # 清空 + 输入中文名（判据 1232）
  A "uitest uiInput click ${SB}" >/dev/null 2>&1; sleep 1
  for _b in 1 2 3 4 5 6 7 8 9 10 11 12; do A "uitest uiInput keyEvent 2055" >/dev/null 2>&1; done
  A "uitest uiInput inputText ${SB} ${NAME}" >/dev/null 2>&1
  sleep 4; DK
  CK=$(CARDPOS "$GID")
  if [ -z "$CK" ]; then echo "    🔴 搜索无结果（$(TXT | cut -c1-40)）"; continue; fi
  A "uitest uiInput click ${CK}" >/dev/null 2>&1
  sleep 6; DK
  GOT=$(TXT)
  if ! printf '%s' "$GOT" | grep -q "$NAME"; then echo "    🔴 进错（$(printf '%s' "$GOT" | cut -c1-40)）"; continue; fi
  # 停演示（若有）
  for a in 1 2 3; do DK; if TXT | grep -q '演示中'; then A 'uitest uiInput click 660 300' >/dev/null 2>&1; sleep 2; else break; fi; done
  sleep 2
  # 截图
  A "snapshot_display -t png -f /data/local/tmp/_s9s.png" >/dev/null 2>&1
  timeout 25 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_s9s.png "/tmp/a11y_${GID}.png" >/dev/null 2>&1
  if [ -s "/tmp/a11y_${GID}.png" ] && [ "$(wc -c < "/tmp/a11y_${GID}.png" | tr -d ' ')" -gt 2000 ]; then
    cp "/tmp/a11y_${GID}.png" "${OUT}/A11Y_${GID}_${TAG}.png"
    echo "    ✅ 截图 ⇒ A11Y_${GID}_${TAG}.png"
  else
    echo "    🔴 截图失败"
  fi
  # 回首页
  A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 3
done
echo
echo '──────────────── 完成 ────────────────'
ls -la ${OUT}/A11Y_*_${TAG}.png 2>/dev/null | awk '{printf "  %s（%s 字节）\n", $9, $5}'
echo "  共 $(ls ${OUT}/A11Y_*_${TAG}.png 2>/dev/null | wc -l | tr -d ' ') 张"
timeout 30 "$EMU" -stop "$INST" >/dev/null 2>&1
echo '  已 stop'
