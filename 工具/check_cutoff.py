#!/usr/bin/env python3
"""检查每款游戏在「当前屏幕尺寸」下，关键操作是否都在（内容没被裁）。
判据：进入游戏后，dump 里必须能找到「‹」+ 至少一个操作按钮（重开/停一手/放弃/提交…）。
若有游戏缺「重开」这类按钮 ⇒ 内容被裁，用户点不到。
"""
import importlib.util, io, json, os, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
vb = importlib.util.module_from_spec(spec); spec.loader.exec_module(vb)

OUT = os.path.join(ROOT, '验收截图-v1.0.1/cutoff_check.jsonl')
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')

def games():
    s = io.open(REG, encoding='utf-8').read()
    out = []
    import re
    for m in re.finditer(r"\{ id: '([a-z0-9_]+)', name: '([^']+)'", s):
        out.append((m.group(1), m.group(2)))
    return out

def done():
    seen = set()
    if os.path.exists(OUT):
        for line in io.open(OUT, encoding='utf-8'):
            try: seen.add(json.loads(line)['name'])
            except: pass
    return seen

ACTS = ['重开', '停一手', '放弃', '提交', '完成', '结束', '交卷', '下一步', '确认', '开始', '▶']

def main():
    seen = done()
    all_g = games()
    todo = [(i, n) for i, n in all_g if n not in seen]
    print('  总 %d 款，已完成 %d，待查 %d' % (len(all_g), len(seen), len(todo)), flush=True)
    for idx, (gid, name) in enumerate(todo):
        try:
            vb.sh('uitest uiInput keyEvent Back'); time.sleep(0.3)
            rows = vb.dump()
            if '‹' in [str(r[0]) for r in rows]:
                b = [r for r in rows if str(r[0]) == '‹']
                if b: vb.sh("uitest uiInput click %d %d" % (int(b[0][1]), int(b[0][2]))); time.sleep(0.4)
            # 列表页直接点击（首屏+滑动找）
            hit = None
            for _ in range(8):
                c = [r for r in vb.dump() if str(r[0]) == name]
                if c: hit = c[0]; break
                vb.sh("uitest uiInput swipe 1280 1200 1280 500 350"); time.sleep(0.4)
            if not hit:
                io.open(OUT, 'a', encoding='utf-8').write(
                    json.dumps({'name': name, 'id': gid, 'found': False}, ensure_ascii=False) + '\n')
                continue
            vb.sh("uitest uiInput click %d %d" % (int(hit[1]), int(hit[2])))
            time.sleep(4.5)
            rows = vb.dump()
            names = [str(r[0]) for r in rows]
            has_back = '‹' in names
            acts = [a for a in ACTS if any(a in n for n in names)]
            io.open(OUT, 'a', encoding='utf-8').write(
                json.dumps({'name': name, 'id': gid, 'found': True, 'back': has_back,
                            'acts': acts, 'n': len(rows)}, ensure_ascii=False) + '\n')
            if idx % 20 == 0:
                print('  [%d/%d] %s' % (idx+1, len(todo), name), flush=True)
        except Exception as e:
            io.open(OUT, 'a', encoding='utf-8').write(
                json.dumps({'name': name, 'id': gid, 'err': str(e)[:60]}, ensure_ascii=False) + '\n')
    print('  ✅ 完成', flush=True)

if __name__ == '__main__':
    main()
