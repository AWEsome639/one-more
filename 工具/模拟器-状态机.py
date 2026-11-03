#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 一局模拟器【状态机】驱动（2026-10-15 立）
   起因：连续两次验证脚本跑偏（全新安装后弹隐私窗 / 页面切换后状态错乱）
   ⇒ 这个模块每步先 dump 确认"我在哪一页"，不在预期页就纠正，再往下走

用法：
   from importlib.machinery import SourceFileLoader
   M = SourceFileLoader('M', '/Users/a0000/dev/yiju/工具/模拟器-状态机.py').load_module()
   M.ensure_home()        # 保证在主页（自动关弹窗、自动切回游戏标签）
   M.to_settings()        # 进设置页
   M.to_modes()           # 滚到"界面模式"三个按钮可见
   M.pick_mode('大字模式')
   M.grid_count()         # (GridItem 个数, 高度集合)
"""
import subprocess, json, re, time, os

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')

def sh(cmd, t=60):
    try:
        return subprocess.run([HDC, 'shell', cmd], capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''

def dump():
    sh('uitest dumpLayout -p /data/local/tmp/p.json')
    subprocess.run([HDC, 'file', 'recv', '/data/local/tmp/p.json', '/tmp/p.json'],
                   capture_output=True, timeout=60)
    try:
        return json.load(open('/tmp/p.json'))
    except Exception:
        return None

def nodes(settle=0.9):
    """返回 [(text, cx, cy, w, h)]"""
    time.sleep(settle)
    d = dump()
    out = []
    def w(o):
        a = o.get('attributes', {})
        t = a.get('text', ''); b = a.get('bounds', '')
        if b and t:
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
            if m:
                x1, y1, x2, y2 = map(int, m.groups())
                out.append((t, (x1+x2)//2, (y1+y2)//2, x2-x1, y2-y1))
        for c in o.get('children', []):
            w(c)
    if d:
        w(d)
    return out

def types(settle=0.9):
    """返回 {type: count}"""
    time.sleep(settle)
    d = dump()
    res = {}
    def w(o):
        a = o.get('attributes', {})
        ty = a.get('type', '')
        if ty:
            res[ty] = res.get(ty, 0) + 1
        for c in o.get('children', []):
            w(c)
    if d:
        w(d)
    return res

def tap(x, y, wait=2.4):
    sh('uitest uiInput click %d %d' % (x, y))
    time.sleep(wait)

def back(wait=1.8):
    sh('uitest uiInput keyEvent Back')
    time.sleep(wait)

def on_home(settle=0.8):
    """主页判据：有"随机来一局"或"全部 · N 款"这类主页特征"""
    tx = [t for t, _, _, _, _ in nodes(settle)]
    s = ' '.join(tx)
    has_tab = any(t.strip() in ('游戏', 'ゲーム', 'Games') for t in tx)
    has_home = ('随机来一局' in s) or ('款小游戏' in s) or ('ミニゲーム' in s) or ('لعبة' in s) or ('games' in s.lower())
    return has_tab and has_home

def dismiss_privacy():
    """关掉隐私弹窗（返回是否关过）"""
    for t, x, y, _, _ in nodes(0.7):
        if '同意并继续' in t or '同意' == t.strip():
            tap(x, y, 2.8)
            return True
    return False

def ensure_home(max_tries=6):
    """★ 核心：把 app 弄到主页（关弹窗 → 必要时重启 → 点游戏标签）"""
    for i in range(max_tries):
        if dismiss_privacy():
            continue
        if on_home(0.7):
            return True
        # 点底部第一个标签（游戏）；坐标固定
        tap(219, 2034, 2.2)
        if on_home(0.7):
            return True
        # 再试：返回键
        back()
        if on_home(0.7):
            return True
        # 最后手段：重启 app
        sh('aa start -a EntryAbility -b com.andrewoscar.onemore', 60)
        time.sleep(9)
        dismiss_privacy()
    return on_home(0.8)

def to_settings(max_scroll=8):
    """进设置页并滚到"界面模式"可见"""
    ensure_home()
    tap(1100, 2034, 2.5)          # 底部第三个标签 = 设置
    for i in range(max_scroll):
        tx = [t for t, _, _, _, _ in nodes(0.7)]
        if any('大字模式' in t for t in tx):
            return True
        sh('uitest uiInput swipe 660 1850 660 1250 280')
        time.sleep(0.55)
    return False

def pick_mode(name='大字模式'):
    """点某个模式按钮（默认/大字模式/简约模式）"""
    for i in range(10):
        for t, x, y, _, _ in nodes(0.7):
            if t.strip() == name:
                tap(x, y, 4.2)
                return True
        sh('uitest uiInput swipe 660 1850 660 1250 280')
        time.sleep(0.55)
    return False

def grid_count(settle=1.1):
    """返回 (GridItem 个数, 高度集合)"""
    d = dump()
    hs = []
    def w(o):
        a = o.get('attributes', {})
        b = a.get('bounds', ''); ty = a.get('type', '')
        if b and ty == 'GridItem':
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
            if m:
                hs.append(int(m.group(4)) - int(m.group(2)))
        for c in o.get('children', []):
            w(c)
    time.sleep(settle)
    d = dump()
    if d:
        w(d)
    return len(hs), sorted(set(hs))

def screenshot(tag):
    sh('snapshot_display -f /data/local/tmp/%s.jpeg' % tag)
    subprocess.run([HDC, 'file', 'recv', '/data/local/tmp/%s.jpeg' % tag, '/tmp/%s.jpeg' % tag],
                   capture_output=True, timeout=60)
    return '/tmp/%s.jpeg' % tag


# ─────────────────────────────────────────────────────────────
# ★★★ 2026-10-15 新增：自适应扇翅膀（Flappy/穿云 专用）
#   起因：要测帧率真值，必须先让游戏【持续存活】——
#         固定间隔点击（0.26s 一次）鸟死得比采样快，ticks 永远是 0
#   做法：从 dump 里读【鸟的 y 位置】（它是游戏区里那个小方块/emoji）
#         ⇒ 低于安全线就点一下 ⇒ 鸟一直活着 ⇒ 才能测到帧计数增长
# ─────────────────────────────────────────────────────────────

def flappy_bird_y():
    """
    ★★★ 2026-10-15 修正（终于搞清了）：
       穿云的【鸟】= Circle（尺寸约 84x72，在游戏区内）
       而【管道】= Row（尺寸约 156x564）—— 我之前的宽过滤器把它误当鸟了
       ⇒ 现在只认 Circle，且宽高在 40~140 之间
    返回鸟的 y 中心；找不到返回 None
    """
    d = dump()
    if not d:
        return None
    best = [None]
    def w(o):
        a = o.get('attributes', {})
        ty = a.get('type', '')
        b = a.get('bounds', '')
        if b and ty == 'Circle':
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
            if m:
                x1, y1, x2, y2 = map(int, m.groups())
                ww, hh = x2 - x1, y2 - y1
                # 鸟的身体：84x72 左右；排除 15x15 的眼睛
                if 40 <= ww <= 140 and 40 <= hh <= 140 and 600 < y1 < 1900:
                    best[0] = (y1 + y2) // 2
        for c in o.get('children', []):
            w(c)
    w(d)
    return best[0]

def flappy_pipe_xs():
    """读管道（宽 ~156、高 ~564 的 Row）的水平位置，用于量速度"""
    d = dump()
    if not d:
        return []
    out = []
    def w(o):
        a = o.get('attributes', {})
        ty = a.get('type', '')
        b = a.get('bounds', '')
        if b and ty == 'Row':
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
            if m:
                x1, y1, x2, y2 = map(int, m.groups())
                ww, hh = x2 - x1, y2 - y1
                if 100 <= ww <= 220 and hh >= 300:
                    out.append(x1)
        for c in o.get('children', []):
            w(c)
    w(d)
    return sorted(out)

def flappy_survive(flap_xy, seconds=8.0, safe_y=1150, tap_wait=0.35):
    """自适应扇翅膀保命：鸟低于 safe_y 就点一下。返回 (是否活到结束, 见到的最小/最大 y)"""
    t0 = time.time()
    ys = []
    alive = True
    while time.time() - t0 < seconds:
        y = flappy_bird_y()
        if y is not None:
            ys.append(y)
            if y > safe_y:
                sh('uitest uiInput click %d %d' % flap_xy)
        else:
            alive = False   # 读不到鸟 ⇒ 多半已结束
        time.sleep(tap_wait)
    return alive, (min(ys) if ys else None), (max(ys) if ys else None)


def flappy_restart_then_survive(seconds=8.0, safe_y=1150):
    """
    ★★★ 2026-10-15 关键修正（读源码得出）：
       flap() 第一行是 `if (this.over) { return; }`
       ⇒ 游戏一旦结束（鸟撞了），点场地/点「扇翅膀」【全都没反应】
       ⇒ 所以自动化必须先点「重开」(reset) ⇒ 再点「扇翅膀」(flap，首次点击触发起飞)
    返回 (是否成功起飞, 鸟 y 的最小/最大值)
    """
    # ① 先找「重开」
    rb = None
    for t, x, y, _, _ in nodes(0.8):
        if '重开' in t:
            rb = (x, y); break
    if rb:
        sh('uitest uiInput click %d %d' % rb)
        time.sleep(0.8)
    # ② 再找「扇翅膀」
    fb = None
    for t, x, y, _, _ in nodes(0.8):
        if '扇翅膀' in t:
            fb = (x, y); break
    if fb is None:
        return False, None, None
    # ③ 首次点击 ⇒ 起飞
    sh('uitest uiInput click %d %d' % fb)
    time.sleep(0.4)
    # ④ 自适应保命
    t0 = time.time(); ys = []
    while time.time() - t0 < seconds:
        y = flappy_bird_y()
        if y is not None:
            ys.append(y)
            if y > safe_y:
                sh('uitest uiInput click %d %d' % fb)
        time.sleep(0.35)
    return True, (min(ys) if ys else None), (max(ys) if ys else None)
