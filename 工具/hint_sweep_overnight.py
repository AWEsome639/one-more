"""提示全量复查（夜间任务）。

★ 为什么慢：模拟器单次输入要 5 秒，且**从游戏返回后列表位置不保持**
  ⇒ 每个游戏都要重新导航 ⇒ 约 7 分钟/款 ⇒ 134 款 ≈ 15 小时
★ 用法：nohup python3 -u 工具/hint_sweep_overnight.py &
  ⇒ 边跑边写 /tmp/hint_sweep2.jsonl，中断可续（已完成会跳过）
"""
import sys, io, json, importlib.util, os, re
spec = importlib.util.spec_from_file_location('vb', '工具/verify_batch.py')
vb = importlib.util.module_from_spec(spec); spec.loader.exec_module(vb)

G = 'entry/src/main/ets/games'
reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
id2name = {m.group(1): m.group(2) for m in re.finditer(r"id: '([^']+)', name: '([^']+)'", reg)}
names = []
for fn in sorted(os.listdir(G)):
    if not fn.endswith('.ets') or '.bak' in fn:
        continue
    if 'private askHint' not in io.open(os.path.join(G, fn), encoding='utf-8').read():
        continue
    gid = re.sub(r'([a-z])([A-Z])', r'\1_\2', fn[1:-4]).lower()
    nm = id2name.get(gid)
    if nm:
        names.append(nm)

done = {}
try:
    for l in io.open('/tmp/hint_sweep2.jsonl', encoding='utf-8'):
        r = json.loads(l); done[r['name']] = r
except Exception:
    pass

f = io.open('/tmp/hint_sweep2.jsonl', 'a', encoding='utf-8')
for i, name in enumerate(names):
    if name in done:
        continue
    if not vb.ensure_app():
        import time; time.sleep(30)
        if not vb.ensure_app():
            print('  App 掉了，停', flush=True); break
    try:
        ok, ev = vb.check_hint(name)
    except Exception as e:
        ok, ev = False, 'err:' + str(e)[:16]
    rec = {'name': name, 'ok': ok, 'ev': ev}
    f.write(json.dumps(rec, ensure_ascii=False) + '\n'); f.flush()
    print('%3d/%d %-12s %s %s' % (i + 1, len(names), name, '✅' if ok else '🔴', ev), flush=True)
f.close()
print('  DONE', flush=True)
