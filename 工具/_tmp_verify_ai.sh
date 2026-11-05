#!/usr/bin/env bash
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
A() { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
D() { rm -f /tmp/av.json; A "uitest dumpLayout -p /data/local/tmp/_av.json" >/dev/null 2>&1; timeout 15 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_av.json /tmp/av.json >/dev/null 2>&1; }
T() { python3 -c "
import json,os
p='/tmp/av.json'
if not os.path.exists(p) or os.path.getsize(p)<500: print(''); raise SystemExit
d=json.load(open(p,encoding='utf-8')); t=[]
def w(x):
    if not isinstance(x,dict): return
    s=(x.get('attributes',{}).get('text') or '').strip()
    if s: t.append(s)
    for c in x.get('children',[]) or []: w(c)
w(d)
print('\u0001'.join(t))
" 2>/dev/null; }
XY() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = sys.argv[1]
d = json.load(open('/tmp/av.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    t=(at.get('text') or '').strip()
    if want in t and t and b(at):
        bb=b(at); r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
CARD() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = 'card-' + sys.argv[1]
d = json.load(open('/tmp/av.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if (at.get('id') or '') == want:
        bb=b(at)
        if bb: r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
NAME_OF() { case "$1" in blink_detector) printf '\u7728\u773c\u68c0\u6d4b';; ab_reversal_oddball) printf 'AB \u53cd\u8f6c';; *) printf '?';; esac; }

GID="${1:?用法: verify_ai_two.sh <game_id>}"
NAME="$(NAME_OF "$GID")"
# ★ 判据 1199/1200：全角括号**必须**用 ${VAR}
echo "════════ ${NAME}（${GID}）════════"

A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 2
A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 2
bash 工具/ensure_ready.sh onemore3 > /dev/null 2>&1
D
C="$(CARD "$GID")"
if [ -z "$C" ]; then
  echo "  卡片不在首屏 ⇒ 搜索"
  SR="$(XY "🔍")"
  if [ -n "$SR" ]; then A "uitest uiInput click ${SR}" >/dev/null 2>&1; sleep 2; D; fi
  SB="$(python3 -c "
import json,re
d=json.load(open('/tmp/av.json',encoding='utf-8'))
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
" 2>/dev/null | tr -d '\r\n')"
  echo "  搜索框 @ (${SB:-无})"
  if [ -n "$SB" ]; then
    A "uitest uiInput inputText ${SB} ${NAME}" >/dev/null 2>&1
    sleep 3; D
    C="$(CARD "$GID")"
  fi
fi
echo "  卡片 @ (${C:-无})"
if [ -z "$C" ]; then
  echo "  ── 当前页面前 20 条 ──"
  T | tr '\001' '\n' | head -20 | sed 's/^/    /'
  exit 1
fi
A "uitest uiInput click ${C}" >/dev/null 2>&1
sleep 6
D
GOT="$(T | tr '\001' '|')"
if printf '%s' "$GOT" | grep -q "$NAME"; then
  echo "  ✅ 已进入（核对游戏名）"
else
  echo "  🔴 **进错游戏**：$(printf '%s' "$GOT" | cut -c1-80)"
  exit 1
fi
for a in 1 2 3; do
  D
  if T | grep -q "演示中"; then A "uitest uiInput click 660 300" >/dev/null 2>&1; sleep 2; else break; fi
done
D
S="$(XY "开始")"
if [ -n "$S" ]; then A "uitest uiInput click ${S}" >/dev/null 2>&1; sleep 2; fi
D
AI="$(XY "AI 代打")"
echo "  AI 代打 @ (${AI:-无})"
if [ -n "$AI" ]; then A "uitest uiInput click ${AI}" >/dev/null 2>&1; fi
for i in $(seq 1 20); do
  sleep 2
  D
  CUR="$(T | tr '\001' '|')"
  if printf '%s' "$CUR" | grep -qE "再来一局"; then
    echo "  第 ${i}×2s ⇒ **结算**"
    echo "  $(printf '%s' "$CUR" | cut -c1-180)"
    A "snapshot_display -t png -f /data/local/tmp/_g.png" >/dev/null 2>&1
    timeout 25 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_g.png "/tmp/ai_${GID}.png" >/dev/null 2>&1
    if [ -s "/tmp/ai_${GID}.png" ] && [ "$(wc -c < "/tmp/ai_${GID}.png" | tr -d ' ')" -gt 2000 ]; then
      cp "/tmp/ai_${GID}.png" "验收截图-v1.0.1/AI_PLAY_${GID}_440x744_20261105.png"
      echo "  📸 ⇒ AI_PLAY_${GID}_440x744_20261105.png"
    fi
    exit 0
  fi
done
echo "  ⚠️ 未结算"
exit 1
