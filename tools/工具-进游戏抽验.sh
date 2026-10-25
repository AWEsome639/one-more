#!/bin/bash
# 进游戏抽验（拾海 2026-10-14）
# ★ 教训：不要用目测的像素坐标点 —— 从 uitest 的 bounds 里读！
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
D=$(timeout 10 $HDC list targets 2>/dev/null | grep -v Empty | head -1 | tr -d '\r')
[ -z "$D" ] && { echo "  ❌ 没有设备"; exit 1; }
[ $# -ge 1 ] && GAME="$1" || GAME=""

echo "  设备: $D"
# ① 抓当前布局
timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/p.json" >/dev/null 2>&1
timeout 60 $HDC file recv /data/local/tmp/p.json /tmp/p.json >/dev/null 2>&1

# ② 用 python 从 bounds 里找目标控件（默认找第一个游戏卡/含"全部"的标签）
/usr/bin/python3 - "$GAME" <<'PY'
import json, sys, re
target = sys.argv[1] if len(sys.argv) > 1 else ''
try:
    d = json.load(open('/tmp/p.json'))
except Exception:
    print('  ⚠️ dump 读不到'); raise SystemExit(1)

hits = []
def walk(o):
    a = o.get('attributes', {})
    t = a.get('text', '') or a.get('content', '')
    b = a.get('bounds', '')
    if t and b:
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
        if m:
            x1,y1,x2,y2 = map(int, m.groups())
            hits.append((t, (x1+x2)//2, (y1+y2)//2, x2-x1, y2-y1))
    for c in o.get('children', []):
        walk(c)
walk(d)

if target:
    cand = [h for h in hits if target in h[0]]
else:
    # 默认：找又宽又高、文本像游戏名的（排除顶栏/底栏）
    cand = [h for h in hits if h[3] > 300 and h[4] > 60]

if not cand:
    print('  ⚠️ 没找到可点的控件；屏幕上这些文本：')
    for t,_,_,w,h in hits[:25]:
        print('     %-30s %sx%s' % (t[:30], w, h))
    raise SystemExit(2)

t, cx, cy, w, h = cand[0]
print('  ★ 目标控件: %s  (中心 %s,%s  尺寸 %sx%s)' % (t[:40], cx, cy, w, h))
open('/tmp/click_xy.txt','w').write('%d %d' % (cx, cy))
PY
if [ -f /tmp/click_xy.txt ]; then
  read CX CY < /tmp/click_xy.txt
  echo "  → 点击 ($CX, $CY)"
  timeout 40 $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1
  sleep 6
  timeout 60 $HDC shell "uitest dumpLayout -p /data/local/tmp/q.json" >/dev/null 2>&1
  timeout 60 $HDC file recv /data/local/tmp/q.json /tmp/q.json >/dev/null 2>&1
  /usr/bin/python3 -c "
import json
d=json.load(open('/tmp/q.json')); ts=[]
def w(o):
    a=o.get('attributes',{})
    if a.get('text',''): ts.append(a['text'])
    for c in o.get('children',[]): w(c)
w(d)
print('  进游戏后: ' + ' | '.join(ts[:12]))"
fi
rm -f /tmp/click_xy.txt
