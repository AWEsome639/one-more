import json, subprocess, re
HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
def sh(c, t=60):
    try: return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception: return ''
out = sh("%s -t 127.0.0.1:5557 shell 'cat /data/local/tmp/p.json'" % HC, 60)
try: d = json.loads(out)
except Exception: print('dump 读失败'); raise SystemExit
target = None
def find(n, path):
    global target
    if isinstance(n, dict):
        a = n.get('attributes', {}) or {}
        t = a.get('text', '')
        if t.startswith('↓'):
            target = path + [(a.get('type'), a.get('bounds'), t)]
            return True
        for c in (n.get('children') or []):
            if find(c, path + [(a.get('type'), a.get('bounds'), t)]): return True
    return False
find(d, [])
if not target:
    print('未找到 ↓ 文本'); raise SystemExit
print('↓ 节点的祖先链（从根到它）:')
for ty, b, t in target:
    print('  %-12s %-28s %r' % (ty, b, (t or '')[:14]))
