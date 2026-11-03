#!/usr/bin/env python3
"""验证 30 款「宽驱动加限高」的游戏：按钮是否在屏幕内。"""
import importlib.util, io, json, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
vb = importlib.util.module_from_spec(spec); spec.loader.exec_module(vb)
HC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
OUT = os.path.join(ROOT, '验收截图-v1.0.1/cap30_verified.jsonl')

ITEMS = [["联合特征", "记忆"], ["计数广度", "记忆"], ["动态凸显", "记忆"], ["特征矩阵", "记忆"], ["特征回忆", "记忆"], ["幽灵点击", "记忆"], ["重力排序", "空间"], ["网格位移", "空间"], ["色相排序", "空间"], ["互锁拼图", "空间"], ["激光连线", "空间"], ["镜面反射", "空间"], ["幻方", "数字"], ["曼陀罗回忆", "记忆"], ["矩阵推理", "数字"], ["记忆矩阵", "记忆"], ["记忆宫殿", "记忆"], ["多目标追踪", "记忆"], ["负空间", "记忆"], ["反应点击", "记忆"], ["自定顺序", "记忆"], ["数量直觉", "记忆"], ["对称", "空间"], ["对称广度", "空间"], ["七巧板", "空间"], ["矢印", "逻辑"], ["向量对齐", "数字"], ["折纸", "空间"], ["空间广度", "记忆"], ["视角切换", "空间"]]

def sh(c): subprocess.run([HC,'-t','127.0.0.1:5555','shell',c], capture_output=True, timeout=40)
def done():
    s = set()
    if os.path.exists(OUT):
        for l in io.open(OUT, encoding='utf-8'):
            try: s.add(json.loads(l)['name'])
            except: pass
    return s

def to_top():
    for _ in range(14):
        sh('uitest uiInput fling 1280 500 1280 1300 900'); time.sleep(0.12)

seen = done()
print('  待验 %d 款' % (len(ITEMS) - len(seen)), flush=True)
n = 0
for name, cat in ITEMS:
    if name in seen: continue
    n += 1
    try:
        to_top(); time.sleep(0.5)
        # ★ 用分类筛选把列表从 355 缩到 44-79，再滚就快且准
        chip = [r for r in vb.dump() if str(r[0]).startswith(cat) and ' ' in str(r[0])]
        if chip:
            vb.sh('uitest uiInput click %d %d' % (int(chip[0][1]), int(chip[0][2])))
            time.sleep(1.5)
        hit = None
        for _ in range(14):
            c = [r for r in vb.dump() if str(r[0]) == name]
            if c: hit = c[0]; break
            sh('uitest uiInput fling 1280 1200 1280 500 800'); time.sleep(0.6)
        if not hit:
            io.open(OUT,'a',encoding='utf-8').write(json.dumps(
                {'name': name, 'found': False}, ensure_ascii=False)+'\n')
            print('  [%d] %-10s 未找到' % (n, name), flush=True); continue
        vb.sh('uitest uiInput click %d %d' % (int(hit[1]), int(hit[2])))
        time.sleep(5.5)
        vb.sh('uitest uiInput click 1280 560')   # 打断演示
        time.sleep(1.2)
        rows = vb.dump()
        acts = [k for k in ['重开','再来一局','提交','确认','完成'] if any(k in str(r[0]) for r in rows)]
        ys = [int(r[2]) for r in rows if int(r[2]) < 1560]
        low = max(ys) if ys else 0
        sh('snapshot_display -f /data/local/tmp/c.jpeg')
        subprocess.run([HC,'-t','127.0.0.1:5555','file','recv','/data/local/tmp/c.jpeg',
                        os.path.join(ROOT,'验收截图-v1.0.1/cap30_%s.jpeg'%name)],
                       capture_output=True, timeout=60)
        rec = {'name': name, 'acts': acts, 'low': low, 'ok': bool(acts) and low < 1560}
        io.open(OUT,'a',encoding='utf-8').write(json.dumps(rec, ensure_ascii=False)+'\n')
        print('  [%d] %-10s %s 动作=%-12s 最低y=%d' % (n, name, '✅' if rec['ok'] else '⚠️', ','.join(acts) or '无', low), flush=True)
        b = [r for r in vb.dump() if str(r[0]) == '‹']
        if b: vb.sh('uitest uiInput click %d %d' % (int(b[0][1]), int(b[0][2]))); time.sleep(1.5)
    except Exception as e:
        io.open(OUT,'a',encoding='utf-8').write(json.dumps({'name': name, 'err': str(e)[:50]}, ensure_ascii=False)+'\n')
        print('  [%d] %-10s 异常 %s' % (n, name, str(e)[:40]), flush=True)
print('  ✅ 完成', flush=True)
