#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 一局 A-Z 巡检 v2（2026-10-15 重写）
为什么重写：v1 靠"Back 后滚回同样步数"定位 ⇒ 落点漂移 ⇒ 反复扫到同一批已测过的。
v2 改成【按名字定位】：
  ① 跳字母 → 记录该字母下【每个名字出现在第几步】
  ② 对每个未测名字：跳到它的字母 → 滚到它出现的那一屏 → 点它 → 验证 → Back
  ⇒ 不依赖"滚回去"，只依赖"滚到看见这个名字"
用法：python3 -u 工具/巡检-扫一轮2.py <字母> <最多测几款>
产出：已巡检游戏v2-<字母>.txt
"""
import importlib.util, time, io, os, sys

spec = importlib.util.spec_from_file_location('M', os.path.expanduser('~/dev/yiju/工具/模拟器-状态机.py'))
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)

LETTER = sys.argv[1] if len(sys.argv) > 1 else 'S'
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 else 20
os.chdir(os.path.expanduser('~/dev/yiju'))

seen = set()
for fn in os.listdir('.'):
    if fn.startswith('已巡检'):
        for ln in io.open(fn, encoding='utf-8').read().split('\n'):
            if ln.strip():
                seen.add(ln.strip().replace(' ', ''))
print('  基线 %d 条' % len(seen))

def enterAZ():
    """★ 2026-10-16 改：点完要【等到 A-Z 视图真的出现】才算成功（原来只等 1.3s）"""
    M.ensure_home()
    hit = None
    for t, x, y, _, _ in M.nodes(0.7):
        if 'A-Z' in t and len(t) < 10:
            hit = (x, y); break
    if hit is None:
        return False
    for attempt in range(3):
        M.tap(hit[0], hit[1], 2.0 + attempt * 1.0)   # ★ 2s / 3s / 4s 递增
        # 验证：A-Z 视图里右侧会出现字母索引（x>1150 的单个字母节点）
        for t2, x2, y2, w2, _ in M.nodes(0.6):
            if len(t2.strip()) == 1 and t2.strip().isalpha() and x2 > 1150 and w2 < 90:
                return True
        print('     （A-Z 视图没出现，重试 %d/3）' % (attempt + 1), flush=True)
    return False

def jump_letter(L):
    enterAZ()
    for t, x, y, w, h in M.nodes(0.6):
        if t.strip() == L and x > 1150 and 1400 < y < 2120 and w < 90:
            M.tap(x, y, 1.0); return True
    return False

def device_alive():
    """★ 2026-10-16 加：卡住时先查设备（模拟器崩了会让 dump 无响应，看起来像脚本卡）"""
    try:
        out = M.sh('echo ok', t=8)
        return 'ok' in (out or '')
    except Exception:
        return False

def names_now():
    out = []
    for t, x, y, w, h in M.nodes(0.32):
        if 850 < w < 980 and 38 <= h <= 58 and 1450 < y < 2040:
            out.append((t.replace(' ', ''), x, y))
    return out

# ① 枚举：该字母下每个名字 → 第几步出现
# ★★★ 2026-10-15 修：枚举结果【存文件复用】
#   原因：枚举慢（要滚到底，200 步），测试也慢 ⇒ 拆开，枚举一次可复用多轮
CACHE = '巡检位置缓存-%s.json' % LETTER
import json
pos = {}
if os.path.exists(CACHE) and '--refresh' not in sys.argv:
    try:
        pos = {k: tuple(v) for k, v in json.load(io.open(CACHE, encoding='utf-8')).items()}
        print('  ★ 复用位置缓存 %s（%d 个名字）' % (CACHE, len(pos)))
    except Exception as e:
        print('  ⚠️ 缓存读失败: %s' % e); pos = {}
if not pos:
    print('  枚举字母 %s 的名单（要滚到底，较慢）…' % LETTER)
    if not jump_letter(LETTER):
        print('  ❌ 跳不到字母 %s' % LETTER); sys.exit(1)
    step = 0
    for step in range(120):
        for n, x, y in names_now():
            if n not in pos:
                pos[n] = (step, x, y)
        M.sh('uitest uiInput swipe 660 1900 660 400 150'); time.sleep(0.15)
    json.dump({k: list(v) for k, v in pos.items()}, io.open(CACHE, 'w', encoding='utf-8'))
    print('  ★ 枚举到 %d 个名字（滚了 %d 步）⇒ 已存 %s' % (len(pos), step, CACHE))

targets = [(n, v) for n, v in pos.items() if n not in seen]
# ★ 2026-10-16 加：SKIP="名字1,名字2" 可跳过会卡住的款（先用它绕开 GearTrainDirection）
_skip = [x.strip() for x in os.environ.get('SKIP', '').split(',') if x.strip()]
if _skip:
    before = len(targets)
    targets = [(n, v) for n, v in targets if n not in _skip]
    print('  ★ SKIP 跳过 %d 个: %s' % (before - len(targets), _skip), flush=True)
print('  ★ 其中未测过: %d 个' % len(targets))

# ② 定点测试
ok = tested = 0; passed = []
for _idx, (n, (st, _, _)) in enumerate(targets[:LIMIT], 1):
    print('  ── [%d/%d] %s' % (_idx, min(LIMIT, len(targets)), n[:16]), flush=True)
    # ★ 单款 90 秒硬超时（防止某个页面 dump 卡死拖住整轮）
    def _to(sig, frm):
        raise TimeoutError('单款超时')
    try:
        signal.signal(signal.SIGALRM, _to); signal.alarm(90)
    except Exception:
        pass
    if not device_alive():
        print('  ❌❌ 设备无响应（模拟器可能崩了）=> 停止本轮，已测 %d 个' % tested, flush=True)
        break
    if not jump_letter(LETTER):
        print('  ❌ 跳不到字母 %s => 本轮提前结束（已测 %d 个）' % (LETTER, tested), flush=True)
        break
    found = False
    for i in range(st + 3):
        for nn, x, y in names_now():
            if nn == n:
                M.tap(x, y, 2.6); found = True; break
        if found: break
        M.sh('uitest uiInput swipe 660 1900 660 400 150'); time.sleep(0.15)
    if not found:
        print('     ⚠️ %s 滚不到（跳过）' % n[:14], flush=True); continue
    tx = [t for t, _, _, _, _ in M.nodes(0.6)]
    bad = [t for t in tx if 'undefined' in t.lower() or 'NaN' in t]
    stuck = any('联系人' in t for t in tx)
    inHome = any('355 款小游戏' in t for t in tx)
    good = (not bad) and (not stuck) and (not inHome) and len(tx) >= 4
    tested += 1
    if good: ok += 1; passed.append(n)
    else: print('     ❌ %s ｜ 文本 %d ｜ %s' % (n[:14], len(tx), '落到主页' if inHome else ('★'+str(bad[:1]) if bad else '?')), flush=True)
    if good: print('     ✅ %s 正常（文本 %d 条）' % (n[:14], len(tx)), flush=True)
    try: signal.alarm(0)
    except Exception: pass
    M.sh('uitest uiInput keyEvent Back'); time.sleep(1.3)

print()
print('  ★ 本轮: %d/%d 正常' % (ok, tested))
if passed:
    # ★★★ 2026-10-15 修：原来用 'w' 覆盖同名文件 ⇒ 每轮战果互相覆盖！
    #   ⇒ 改成【一个总文件 + 追加】，跑多少轮都不会丢
    fn = '已巡检v2-累计.txt'
    old_set = set()
    if os.path.exists(fn):
        old_set = set(l.strip() for l in io.open(fn, encoding='utf-8').read().split('\n') if l.strip())
    allset = old_set | set(passed)
    io.open(fn, 'w', encoding='utf-8').write('\n'.join(sorted(allset)))
    print('  ✅ 新增 %d 款（累计 %d）⇒ %s' % (len(set(passed)), len(allset), fn))
    print('     %s' % sorted(set(passed)))
