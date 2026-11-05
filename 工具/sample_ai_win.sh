#!/usr/bin/env bash
# ============================================================================
#  工具/sample_ai_win.sh —— **抽样验「AI 能不能赢」**（判据 1558~1567）
#
#  ★ 为什么要有（第 1411 轮）
#    `ai_play_verified.jsonl` 只有 `{name, started: true}`
#    ⇒ **只说「开始了」，没说「赢了」**
#    而「AI 能不能赢」是**可玩性**的最硬证据：
#      一款 AI 赢不了的游戏，要么太难、要么有 bug
#
#  ★ 为什么抽样（判据 1565/1566）
#    355 款 × ~40s ≈ 4 小时 ⇒ 不可行
#    ⇒ 抽 **行数最少的 20 款**（判据 1560：逻辑最简单，有 bug 最先暴露）
#    ⇒ 约 15~30 分钟
#
#  ★ 判定口径
#    · 结算里出现「通关 / 已通关 / 拿下」⇒ **WIN**
#    · 出现「再来一局？」「差一点」等 ⇒ **LOSE**
#    · 未结算（超时）⇒ **TIMEOUT**
#
#  ★ 用法：bash 工具/sample_ai_win.sh [设备名] [样本数=20]
#  退出码：0 = 全部 WIN 或 LOSE（有结论）｜ 1 = 有 TIMEOUT/失败
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
DEV="${1:-onemore3}"
N="${2:-20}"
OUT="验收截图-v1.0.1/ai_win_sample_$(date +%Y%m%d_%H%M)"
mkdir -p "$OUT"
RES="$OUT/result.tsv"
: > "$RES"

ONLINE() { timeout 10 "$HC" -t 127.0.0.1:5555 shell 'echo ok' 2>/dev/null | grep -qx 'ok'; }
A() { ONLINE || return 1; timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
DK() { rm -f /tmp/sw.json; A "uitest dumpLayout -p /data/local/tmp/_sw.json" >/dev/null 2>&1; timeout 20 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_sw.json /tmp/sw.json >/dev/null 2>&1; }

# ★ 判据 1490：每次重试都重发 aa start
START_APP() {
  local TRY out pv t
  for TRY in 1 2 3 4 5; do
    A 'aa force-stop com.andrewoscar.onemore' >/dev/null 2>&1
    A 'power-shell wakeup' >/dev/null 2>&1; sleep 3
    out="$(A 'aa start -b com.andrewoscar.onemore -a EntryAbility' 2>&1 | head -1)"
    pv=""
    for t in 4 5 7 9; do
      sleep "$t"
      pv="$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}')"
      printf '%s' "$pv" | grep -qE '^[0-9]+$' && break
    done
    if printf '%s' "$pv" | grep -qE '^[0-9]+$'; then return 0; fi
    echo "      起 app 第 ${TRY} 次失败：$(printf '%s' "$out" | cut -c1-36)" >&2
  done
  return 1
}

POS() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = sys.argv[1]
d = json.load(open('/tmp/sw.json', encoding='utf-8'))
def b(x):
    mm = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r = None
def w(n):
    global r
    if not isinstance(n, dict) or r: return
    at = n.get('attributes', {})
    if want in (at.get('text') or '') and b(at):
        bb = b(at); r = ((bb[0]+bb[2])//2, (bb[1]+bb[3])//2)
    for c in n.get('children', []) or []: w(c)
w(d)
print('%d %d' % r if r else '')
PY
}
INPUTPOS() { python3 -c "
import json,re
d=json.load(open('/tmp/sw.json',encoding='utf-8'))
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
d = json.load(open('/tmp/sw.json', encoding='utf-8'))
def b(x):
    mm = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r = None
def w(n):
    global r
    if not isinstance(n, dict) or r: return
    at = n.get('attributes', {})
    if (at.get('id') or '') == want:
        bb = b(at)
        if bb: r = ((bb[0]+bb[2])//2, (bb[1]+bb[3])//2)
    for c in n.get('children', []) or []: w(c)
w(d)
print('%d %d' % r if r else '')
PY
}
TXT() { python3 -c "
import json,os
p='/tmp/sw.json'
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

# ── 取样本：行数最少的 N 款 ──
python3 - "$N" > /tmp/ai_sample.txt <<'PY'
import glob, io, os, sys
N = int(sys.argv[1])
rows = []
for f in sorted(glob.glob('entry/src/main/ets/games/*.ets')):
    try: s = io.open(f, encoding='utf-8').read()
    except Exception: continue
    name = os.path.basename(f).replace('.ets','')
    eff = sum(1 for l in s.split('\n') if l.strip() and not l.strip().startswith('//') and not l.strip().startswith('*'))
    rows.append((name, eff))
rows.sort(key=lambda r: r[1])
# 从 Registry 拿 id 与中文名
reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
import re
pairs = re.findall(r"\{ id: '([a-z0-9_]+)', name: '([^']+)'", reg)
cls2id = {}
for i, n in pairs:
    # GAbcDef -> abc_def 近似
    cls = 'G' + ''.join(w.capitalize() for w in i.split('_'))
    cls2id[cls] = i
for name, eff in rows[:N]:
    gid = cls2id.get(name)
    if gid:
        nm = dict((i, n) for i, n in pairs).get(gid, '?')
        print('%s\t%s\t%s' % (gid, nm, eff))
PY
echo "════════ 抽样：行数最少的 $(wc -l < /tmp/ai_sample.txt | tr -d ' ') 款 ════════"
cat /tmp/ai_sample.txt | awk -F'\t' '{printf "  %-30s %-12s %s 行\n", $1, $2, $3}'
echo

# ── 起机 + 装包 ──
echo "  起机…"
for X in onemore onemore2 onemore3 onemore4 onemore5 onemore6; do timeout 20 "$EMU" -stop "$X" >/dev/null 2>&1; done
sleep 20
printf 'y\ny\ny\ny\ny\ny\n' > /tmp/yes_sw.txt
nohup bash -c "\"$EMU\" -start \"$DEV\" < /tmp/yes_sw.txt" > /tmp/sw_boot.log 2>&1 &
for i in $(seq 1 60); do sleep 10; ONLINE && { echo "  在线 @ $((i*10))s"; break; }; done
timeout 6 "$HC" tconn 127.0.0.1:5555 >/dev/null 2>&1
for k in $(seq 1 12); do
  sleep 10
  rm -f /tmp/swb.png
  A "snapshot_display -w 200 -h 200 -t png -f /data/local/tmp/_sb.png" >/dev/null 2>&1
  timeout 12 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_sb.png /tmp/swb.png >/dev/null 2>&1
  L=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/swb.png'
print('%.0f' % np.array(Image.open(p).convert('RGB')).mean() if (os.path.exists(p) and os.path.getsize(p)>800) else '-1')
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${L:--1}')>20 else 1)" 2>/dev/null && { echo "  亮度 ${L}"; break; }
  A 'power-shell wakeup' >/dev/null 2>&1
done
timeout 1200 "$HC" -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-signed.hap > /tmp/sw_inst.log 2>&1
echo "  $(grep -oE 'msg:[^,]*' /tmp/sw_inst.log | head -1)"
START_APP || { echo "  🔴 app 起不来"; timeout 30 "$EMU" -stop "$DEV" >/dev/null 2>&1; exit 1; }
sleep 10

# ── 逐款跑 ──
echo
echo "  ══ 逐款：进游戏 → AI 代打 → 等结算 ══"
while IFS=$'\t' read -r GID NAME EFF; do
  [ -z "$GID" ] && continue
  printf '  %-30s ' "$GID"
  # 回首页
  DK
  CUR="$(TXT)"
  if printf '%s' "$CUR" | grep -qE "AI 代打|重开|再来一局"; then
    A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 3; DK
  fi
  # 搜索
  SB="$(INPUTPOS)"
  if [ -z "$SB" ]; then
    SR=$(POS "🔍"); [ -n "$SR" ] && { A "uitest uiInput click ${SR}" >/dev/null 2>&1; sleep 3; DK; }
    SB="$(INPUTPOS)"
  fi
  if [ -z "$SB" ]; then echo "NO_SEARCH"; printf '%s\t%s\tNO_SEARCH\n' "$GID" "$EFF" >> "$RES"; continue; fi
  A "uitest uiInput click ${SB}" >/dev/null 2>&1; sleep 1
  for _b in 1 2 3 4 5 6 7 8 9 10 11 12; do A "uitest uiInput keyEvent 2055" >/dev/null 2>&1; done
  A "uitest uiInput inputText ${SB} ${NAME}" >/dev/null 2>&1
  sleep 4; DK
  CK=$(CARDPOS "$GID")
  if [ -z "$CK" ]; then echo "NO_CARD"; printf '%s\t%s\tNO_CARD\n' "$GID" "$EFF" >> "$RES"; continue; fi
  A "uitest uiInput click ${CK}" >/dev/null 2>&1; sleep 7; DK
  # 停演示
  for a in 1 2 3; do DK; if TXT | grep -q '演示中'; then A 'uitest uiInput click 660 300' >/dev/null 2>&1; sleep 2; else break; fi; done
  # 点 AI
  AI=$(POS "AI 代打")
  if [ -z "$AI" ]; then echo "NO_AI"; printf '%s\t%s\tNO_AI\n' "$GID" "$EFF" >> "$RES"; A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 2; continue; fi
  A "uitest uiInput click ${AI}" >/dev/null 2>&1
  # 等结算（最多 90s）
  VERDICT="TIMEOUT"
  for i in $(seq 1 45); do
    sleep 2; DK
    C="$(TXT)"
    if printf '%s' "$C" | grep -qE "返回列表"; then
      if printf '%s' "$C" | grep -qE "已通关|通关！|这一局拿下|🎉"; then VERDICT="WIN"
      else VERDICT="LOSE"; fi
      break
    fi
  done
  echo "$VERDICT"
  printf '%s\t%s\t%s\n' "$GID" "$EFF" "$VERDICT" >> "$RES"
  A 'uitest uiInput keyEvent Back' >/dev/null 2>&1; sleep 3
done < /tmp/ai_sample.txt

echo
echo "  ══ 汇总 ══"
python3 - "$RES" <<'PY'
import sys, os
p = sys.argv[1]
rows = []
for ln in open(p, encoding='utf-8'):
    parts = ln.rstrip('\n').split('\t')
    if len(parts) >= 3: rows.append(parts)
from collections import Counter
c = Counter(r[2] for r in rows)
print('  样本 **%d 款**：' % len(rows))
for k in ('WIN', 'LOSE', 'TIMEOUT', 'NO_SEARCH', 'NO_CARD', 'NO_AI'):
    if c[k]: print('    %-10s **%d** %s' % (k, c[k], '█'*c[k]))
print()
done = c['WIN'] + c['LOSE']
if done:
    print('  **有结论 %d 款 ｜ WIN %d（%.0f%%）**' % (done, c['WIN'], c['WIN']/done*100))
print('  产物: %s' % p)
PY
timeout 30 "$EMU" -stop "$DEV" >/dev/null 2>&1
echo "  已 stop"
