#!/bin/bash
# 读取当前页面所有文字（拾海 2026-10-10）
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
$HDC shell "uitest dumpLayout -p /data/local/tmp/rp.json" >/dev/null 2>&1
$HDC file recv /data/local/tmp/rp.json /tmp/rp.json >/dev/null 2>&1
/usr/bin/python3 "${1:--}" <<'PY'
import json, sys
try:
    d = json.load(open('/tmp/rp.json'))
except Exception:
    print('  （读不到页面）'); raise SystemExit
ts = []
def w(o):
    a = o.get('attributes', {})
    if a.get('text', ''):
        ts.append(a['text'])
    for c in o.get('children', []):
        w(c)
w(d)
print('  ' + ' | '.join(ts))
PY
