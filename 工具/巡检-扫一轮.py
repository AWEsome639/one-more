#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 一局：A-Z 巡检【一轮】（2026-10-15 定型）
   为什么这样写（踩了十几轮才定）：
     · A-Z 列表每款游戏占【两行】：行1=名字(高~49px,宽~912) ｜ 行2=英文名(高~42px)
     · 屏幕边缘的行会被裁成 9px 高 ⇒ 宽泛的高度过滤会把它们当候选，取到"已测过的"
     · ⇒ 只认【宽 850~980 且高 38~58】的行 = 名字行
   用法：python3 工具/巡检-扫一轮.py [最多测几款，默认 26]
   产出：已巡检游戏<N>.txt + 控制台摘要
"""
import importlib.util, time, io, os, sys

spec = importlib.util.spec_from_file_location('M', os.path.expanduser('~/dev/yiju/工具/模拟器-状态机.py'))
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 26
# ★★★ 2026-10-15 修正：A-Z 列表有 710 行（355×2），滚 59 步只覆盖前 1/3
#   ⇒ 加两个参数：起始字母（用右侧索引跳过去）+ 滚动深度
START_LETTER = sys.argv[2] if len(sys.argv) > 2 else ''
DEPTH = int(sys.argv[3]) if len(sys.argv) > 3 else 60
os.chdir(os.path.expanduser('~/dev/yiju'))

# 已测集合（含历史记录）
seen = set()
for fn in os.listdir('.'):
    if fn.startswith('已巡检'):
        for ln in io.open(fn, encoding='utf-8').read().split('\n'):
            if ln.strip():
                seen.add(ln.strip().replace(' ', ''))
print('  基线 %d 条记录' % len(seen))

def enterAZ():
    M.ensure_home()
    for t, x, y, _, _ in M.nodes(0.7):
        if 'A-Z' in t and len(t) < 10:
            M.tap(x, y, 1.3); return True
    return False

def name_rows():
    """★ 只取"名字行"：宽 850~980、高 38~58"""
    out = []
    for t, x, y, w, h in M.nodes(0.40):
        n = t.replace(' ', '')
        if 850 < w < 980 and 38 <= h <= 58 and 1450 < y < 2040 and 2 <= len(n) <= 14:
            out.append((n, x, y))
    return out

enterAZ()

def jump_letter(L):
    """★ 用右侧字母索引跳到某字母（绝对定位，不受"返回后列表重置"影响）"""
    if not L: return True
    enterAZ()
    # ★ 2026-10-15 修正：字母索引在【右侧竖条】(x≈1188, y≈1544~2100)
    #   我之前写成 y<320（那是顶部栏）⇒ 永远找不到
    for t, x, y, w, h in M.nodes(0.6):
        if t.strip() == L and x > 1150 and 1400 < y < 2120 and w < 90:
            M.tap(x, y, 1.0); return True
    return False

if START_LETTER:
    print('  跳到字母 %s: %s' % (START_LETTER, '✅' if jump_letter(START_LETTER) else '❌'))

ok = tested = 0; passed = []; sus = []; step = 0
for step in range(DEPTH):
    cands = [c for c in name_rows() if c[0] not in seen]
    if cands and tested < LIMIT:
        nm, x, y = cands[0]
        M.tap(x, y, 2.7)
        tx = [t for t, _, _, _, _ in M.nodes(0.65)]
        bad = [t for t in tx if 'undefined' in t.lower() or 'NaN' in t]
        stuck = any('联系人' in t for t in tx)
        good = (not bad) and (not stuck) and len(tx) >= 4
        tested += 1
        if good: ok += 1; passed.append(nm)
        elif stuck: sus.append(nm)
        seen.add(nm)
        M.sh('uitest uiInput keyEvent Back'); time.sleep(1.4)
        if not enterAZ(): break
        if START_LETTER: jump_letter(START_LETTER)
        for s in range(step):
            M.sh('uitest uiInput swipe 660 1780 660 1420 200'); time.sleep(0.22)
    else:
        M.sh('uitest uiInput swipe 660 1780 660 1420 200'); time.sleep(0.28)
    if tested >= LIMIT: break

print()
print('  ★ 本轮: %d/%d 正常 ｜ 可疑: %s ｜ 步数 %d' % (ok, tested, sus or '无', step))
if passed:
    n = 1
    while os.path.exists('已巡检游戏%d.txt' % (38 + n)): n += 1
    fn = '已巡检游戏%d.txt' % (38 + n)
    io.open(fn, 'w', encoding='utf-8').write('\n'.join(sorted(set(passed))))
    print('  ✅ 新增 %d 款 ⇒ %s' % (len(set(passed)), fn))
    print('     %s' % sorted(set(passed)))
