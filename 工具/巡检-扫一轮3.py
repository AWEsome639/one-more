# -*- coding: utf-8 -*-
"""★ 巡检 v3（2026-10-16）
   为什么有 v3：v2 靠 uitest dumpLayout 找游戏名，
   但 dumpLayout 对【A-Z 视图】返回的还是首页节点树（实测铁证）=> v2 会"卡住"。

   v3 的思路：完全不依赖 dumpLayout 找名字
     ① 进 A-Z 视图（用截图确认 A-Z 标签高亮，或用固定点）
     ② 用【位置缓存】里的 st（序号）盲滚 st 次
     ③ 直接点缓存里的 (x, y)
     ④ dump 一次判断有没有进游戏（这时页面是游戏页，dump 正常）

   用法：python3 -u 工具/巡检-扫一轮3.py <字母> <数量>
"""
import io, json, os, re, subprocess, sys, time

LETTER = sys.argv[1] if len(sys.argv) > 1 else 'A'
LIMIT  = int(sys.argv[2]) if len(sys.argv) > 2 else 5
os.chdir(os.path.dirname(os.path.abspath(__file__)) + '/..')

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
CACHE = '巡检位置缓存-%s.json' % LETTER
CUM   = '已巡检v2-累计.txt'
SWIPE = 'uitest uiInput swipe 660 1780 660 1150 200'   # ★ 必须与缓存口径一致（630px/步）
# ★ 2026-10-16 加：swipe 每次要 10 秒，fling 只要 2 秒（快 5 倍）
#   但 fling 是惯性滑动 => 距离不固定 => 需先标定【一次 fling ≈ 几次 swipe】
FLING = 'uitest uiInput fling 660 1700 660 900 3'
FLING_PER_SWIPE = 0.0      # 由标定填入；0 = 不用 fling


# ★ 载入状态机（拿它的 nodes()）
import importlib.util as _ilu
_spec = _ilu.spec_from_file_location('_sm', os.path.join(os.path.dirname(os.path.abspath(__file__)), '模拟器-状态机.py'))
M = _ilu.module_from_spec(_spec)
try:
    _spec.loader.exec_module(M)
except SystemExit:
    pass


def sh(cmd, t=30):
    try:
        return subprocess.run([HDC, 'shell', cmd], capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def dump_nodes():
    """★ 2026-10-16 修：改用状态机里已验证的 M.nodes()
       （我原来自己解析 bounds，但 HarmonyOS 的格式是 "[x,y][x2,y2]"，不是逗号分隔 => 全失败）"""
    try:
        return [(t, x, y) for t, x, y, _, _ in M.nodes(1.1)]
    except Exception:
        return []


def alive():
    try:
        return 'ok' in (sh('echo ok', t=8) or '')
    except Exception:
        return False


def tap(x, y, wait=2.0):
    sh('uitest uiInput click %d %d' % (x, y), t=15)
    time.sleep(wait)


def go_home():
    """★ 2026-10-16 修：只要看不到首页标题，就【直接重新拉起 App】
       （原来靠"桌面特征"判断，会把桌面上的「一局」图标误判成主页）"""
    for i in range(3):
        ts = [t for t, _, _ in dump_nodes()]
        if any('355 款小游戏' in t for t in ts):
            return True
        try:
            M.ensure_home()          # ★ 无条件重新拉起
        except Exception:
            pass
        time.sleep(1.2)
    return False


def enter_az():
    """★ 2026-10-16 定案：dumpLayout 对首页只返回【局部树】（实测 34 条，缺页头/A-Z切换/字母索引）
       => 无法用节点验证，只能【固定坐标点 + 靠最后的结果检查兜底】
       实测：「🔤 A-Z」在 (755, 1459)"""
    go_home()
    tap(755, 1459, 2.6)
    return True          # ★ 不再验证（验证本身依赖 dumpLayout，而它看不到）


def game_page_ok():
    """判断"点进去了"：有返回键/标题，且不是首页"""
    ts = [t for t, _, _ in dump_nodes()]
    if not ts:
        return False, 'dump 空'
    if any('355 款小游戏' in t for t in ts):
        return False, '还在首页'
    bad = [t for t in ts if 'undefined' in t.lower() or 'NaN' in t]
    if bad:
        return False, '★%s' % bad[0][:20]
    if len(ts) < 4:
        return False, '文本仅 %d 条' % len(ts)
    return True, '正常(%d 条)' % len(ts)


def main():
    seen = set()
    if os.path.exists(CUM):
        for ln in io.open(CUM, encoding='utf-8'):
            if ln.strip():
                seen.add(ln.strip())
    if not os.path.exists(CACHE):
        print('  ❌ 没有位置缓存 %s（先跑 v2 枚举一次）' % CACHE); return
    pos = json.load(io.open(CACHE, encoding='utf-8'))
    targets = [(n, v) for n, v in pos.items() if n not in seen]
    skip = [x.strip() for x in os.environ.get('SKIP', '').split(',') if x.strip()]
    targets = [(n, v) for n, v in targets if n not in skip]
    targets.sort(key=lambda kv: kv[1][0])
    print('  基线 %d 条 ｜ 目标 %d 个 ｜ 从位置最靠前的开始' % (len(seen), len(targets)), flush=True)

    ok = tested = 0; passed = []
    if not enter_az():
        print('  ❌ 进不去 A-Z 视图'); return
    print('  ✅ 已进 A-Z 视图', flush=True)

    for i, (name, (st, gx, gy)) in enumerate(targets[:LIMIT], 1):
        if not alive():
            print('  ❌❌ 设备无响应 => 停止（已测 %d）' % tested, flush=True); break
        print('  ── [%d/%d] %-22s 位置%d' % (i, min(LIMIT, len(targets)), name[:22], st), flush=True)
        # ① 回到 A-Z 顶部（点 A 字母索引）
        for t, x, y in dump_nodes():
            if t.strip() == 'A' and x > 1150:
                tap(x, y, 1.5); break
        # ② ★ 盲滚 st 次
        #    fling 快 5 倍（2s vs 10s），但距离不固定 => 用标定系数换算
        n_fling = int(st * FLING_PER_SWIPE) if FLING_PER_SWIPE > 0 else 0
        n_swipe = st - int(round(n_fling / FLING_PER_SWIPE)) if n_fling else st
        if n_fling > 0:
            sh('; '.join([FLING] * n_fling), t=max(30, n_fling * 3))
        if n_swipe > 0:
            sh('; '.join([SWIPE] * n_swipe), t=max(30, n_swipe * 2))
        # ③ 点缓存坐标
        tap(gx, gy, 3.0)
        good, why = game_page_ok()
        tested += 1
        if good:
            ok += 1; passed.append(name)
            print('     ✅ %s' % why, flush=True)
            # ★ 2026-10-16 改：每款【立刻落盘】（原来只在结尾写，中途被杀就白跑）
            with io.open(CUM, 'a', encoding='utf-8') as _f:
                _f.write(name + '\n')
        else:
            print('     ❌ %s' % why, flush=True)
        sh('uitest uiInput keyEvent Back', t=12); time.sleep(1.2)

    print()
    print('  ★ 本轮 %d/%d 正常' % (ok, tested), flush=True)
    if passed:
        with io.open(CUM, 'a', encoding='utf-8') as f:
            for n in passed:
                f.write(n + '\n')
        print('  ✅ 新增 %d 款（累计 %d）' % (len(passed), len(seen) + len(passed)), flush=True)
        print('     %s' % passed, flush=True)


main()
