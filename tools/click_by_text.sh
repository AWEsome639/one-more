#!/bin/bash
# 按屏幕上的文字点击（拾海 2026-10-10）
# 用法: bash click_by_text.sh "文字前缀" [等待秒数]
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
TXT="$1"; WAIT="${2:-3}"
$HDC shell "uitest dumpLayout -p /data/local/tmp/cbt.json" >/dev/null 2>&1
$HDC file recv /data/local/tmp/cbt.json /tmp/cbt.json >/dev/null 2>&1
C=$(/usr/bin/python3 - "$TXT" <<'PY'
import json, re, sys
pre = sys.argv[1]
try:
    d = json.load(open('/tmp/cbt.json'))
except Exception:
    print(''); raise SystemExit
out = []
def w(o):
    a = o.get('attributes', {})
    t = a.get('text', '')
    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', a.get('bounds', '') or '')
    if m and pre in t:
        x1, y1, x2, y2 = map(int, m.groups())
        if y2 <= 2232:
            out.append(((x1 + x2) // 2, (y1 + y2) // 2))
    for c in o.get('children', []):
        w(c)
w(d)
print(f'{out[0][0]} {out[0][1]}' if out else '')
PY
)
if [ -z "$C" ]; then echo "  ❌ 没找到「${TXT}」"; exit 1; fi
echo "  点「${TXT}」@(${C})"
set -- $C
$HDC shell "uitest uiInput click $1 $2" >/dev/null 2>&1
sleep "$WAIT"
