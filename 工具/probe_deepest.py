import sys, json, subprocess, time, re
HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
def sh(c, t=60):
    try: return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception: return ''
def dump():
    sh("%s -t 127.0.0.1:5557 shell 'uitest dumpLayout -p /data/local/tmp/p.json >/dev/null 2>&1; cat /data/local/tmp/p.json'" % HC, 90)
    out = sh("%s -t 127.0.0.1:5557 shell 'cat /data/local/tmp/p.json'" % HC, 60)
    try: return json.loads(out)
    except Exception: return None
leaves = []
def walk(n, path=''):
    if isinstance(n, dict):
        a = n.get('attributes', {}) or {}
        kids = n.get('children') or []
        b = (a.get('bounds') or '').strip()
        if not kids and b:
            nums = [int(x) for x in re.findall(r'-?\d+', b)]
            if len(nums) == 4:
                leaves.append((nums[3], nums[1], a.get('text', '')[:20], a.get('type', '')))
        for c in kids: walk(c, path)
    return
d = dump()
if not d:
    print('dump 失败'); sys.exit(1)
walk(d)
leaves.sort(reverse=True)
print('最深 6 个叶子:')
for y2, y1, t, ty in leaves[:6]:
    print('  y2=%4d  y1=%4d  type=%-10s text=%r' % (y2, y1, ty, t))
