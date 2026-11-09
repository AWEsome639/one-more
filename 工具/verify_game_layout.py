# -*- coding: utf-8 -*-
"""逐款验「游戏内布局是否在屏内」（用 uinput 搜索进游戏，判据 1846）

为什么写它：判据 1846 发现 `uinput -K -t <ASCII>` 能搜索进游戏。
  而「165 款横屏棋盘溢出」这个 goal 条目，之前因为 `inputText` 不生效而验不了。

用法：
  python3 工具/verify_game_layout.py GNonogram GNurikabe GMasyu   # 指定游戏类名
  python3 工具/verify_game_layout.py --list 5                     # 从清单取前 5 款

判据：
  ✅ 屏内：内容底 ≤ 1516（内容区底）
  ⚠️ 贴底：内容底 1516–1584（真机手势条会压）
  ❌ 越界：内容底 > 1584
"""
import io, os, re, subprocess, sys, json, time

HAP_PKG = 'com.andrewoscar.onemore'
HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
DEV = '127.0.0.1:5557'
CONTENT_BOTTOM = 1516      # 内容区底（dump 实测）
GESTURE_LIMIT = 1584       # 屏底 - 16

def sh(cmd, timeout=25):
    """执行 hdc shell；加日志区分「超时」和「其它异常」（v7，2026-11-09）"""
    try:
        r = subprocess.run([HC, '-t', DEV, 'shell', cmd], capture_output=True, text=True, timeout=timeout)
        out = r.stdout or ''
        if len(out) < 200:
            print(f'    [sh] {cmd[:50]} → len={len(out)} rc={r.returncode} out={out.strip()[:80]!r}')
        else:
            print(f'    [sh] {cmd[:50]} → len={len(out)} rc={r.returncode}')
        return out
    except subprocess.TimeoutExpired:
        print(f'    [sh] {cmd[:50]} → ❌ TIMEOUT ({timeout}s)')
        return ''
    except Exception as e:
        print(f'    [sh] {cmd[:50]} → ❌ ERR {type(e).__name__}: {e}')
        return ''

def dump(path='/data/local/tmp/layout.json'):
    sh(f'uitest dumpLayout -p {path}')
    raw = sh(f'cat {path}')
    try:
        return json.loads(raw)
    except Exception:
        return None

def clipped_text(tree, tol=4):
    """⚠️ v12：「真被裁」的机器判据。
    节点底边 > 父容器底边 + tol ⇒ 这个节点溢出了父盒子（会被裁/压）。
    返回 (被裁节点数, 最深的那个节点的 y2, 文本)。
    ⚠️ 为什么不用「max_bottom >= 1584」：按钮「贴屏底」是设计（Sudoku 就是），不算裁。
    """
    hits = []
    def walk(n, parent_bottom):
        a = n.get('attributes', {})
        t = (a.get('text') or ''); b = (a.get('bounds') or '')
        y2 = None
        m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b or '')
        if m:
            y2 = int(m.group(4))
            if y2 is not None and parent_bottom is not None and y2 > parent_bottom + tol:
                hits.append((y2, t))
        nb = y2 if y2 is not None else parent_bottom
        for c in (n.get('children') or []):
            walk(c, nb)
    walk(tree, None)
    if not hits:
        return (0, 0, '')
    hits.sort(reverse=True)
    return (len(hits), hits[0][0], hits[0][1][:30])

def collect(d, pred):
    out = []
    def w(n):
        a = n.get('attributes', {})
        t = (a.get('text') or '')
        b = (a.get('bounds') or '')
        if b:
            m = re.match(r'\[(\-?\d+),(\-?\d+)\]\[(\-?\d+),(\-?\d+)\]', b)
            if m and pred(t):
                out.append((t, tuple(int(x) for x in m.groups())))
        for c in (n.get('children') or []):
            w(c)
    w(d)
    return out

def in_search_mode():
    """搜索态的标志：「搜索框内的小 🔍」([108,407][165,464] 附近)。
    ⚠️ 这是 2026-11-09 04:48 修的 bug：初版「无条件点 🔍」，
       如果「已经是搜索态」，再点会「关掉它」⇒ 后面 uinput 输到「无处的输入框」。
    """
    d = dump('/data/local/tmp/probe.json')
    if not d:
        return False
    for t, (x1, y1, x2, y2) in collect(d, lambda t: True):
        if t.strip() == '🔍' and 400 <= y1 <= 470 and x1 < 200:
            return True
    return False

def search_game(en_name):
    """uinput 搜索（判据 1846：只能 ASCII）。① 先确认「是搜索态」 ② 再聚焦 ③ 再输入"""
    if not in_search_mode():
        sh('uitest uiInput click 2276 264')   # 打开搜索
        time.sleep(0.9)
    # 先点 ✕ 清空残留（如果有）
    d0 = dump('/data/local/tmp/probe2.json')
    if d0:
        for t, (x1, y1, x2, y2) in collect(d0, lambda t: True):
            if t.strip() == '✕' and 380 <= y1 <= 490:
                sh(f'uitest uiInput click {(x1+x2)//2} {(y1+y2)//2}')
                time.sleep(0.5)
                break
    sh('uitest uiInput click 1280 435')       # 聚焦搜索框
    time.sleep(0.6)
    # ⚠️ v5：uinput 对「带空格的字符串」不可靠（v4 实测 8/10 失败）
    #   ⇒ 只输「第一个词」（如 'Snake 3D' → 'Snake'），多搜几款没关系，点第一个
    kw = en_name.split()[0] if en_name.split() else en_name
    sh(f"uinput -K -t '{kw}'")
    time.sleep(2.6)   # ⚠️ v6：1.6 不够（手动 debug 2026-11-09 06:32）

def close_search():
    if in_search_mode():
        sh('uitest uiInput click 2276 264')
        time.sleep(0.7)

def save_shot(safe_name):
    """⚠️ v11：非 OK 的结果「自动存一张截图」——判据 1854「max_bottom 只有配截图才算数」
    返回本地路径（失败返回空串）。"""
    ts = time.strftime('%H%M%S')
    remote = f'/data/local/tmp/shot_{safe_name}.jpeg'
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       '_巡检记录', f'截图-{safe_name}-{ts}.jpeg')
    sh(f'snapshot_display -f {remote}')
    try:
        r = subprocess.run([HC, '-t', DEV, 'file', 'recv', remote, out],
                           capture_output=True, text=True, timeout=90)
        if os.path.exists(out) and os.path.getsize(out) > 1000:
            return out
    except Exception:
        pass
    return ''

def game_title_map():
    """enName → 中文名（从 GameRegistry 解析，判据 1861 用：确认点进去的是「目标那一款」）"""
    import re as _re
    try:
        s = io.open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                 'entry/src/main/ets/core/GameRegistry.ets'), encoding='utf-8').read()
    except Exception:
        return {}
    m = {}
    for mm in _re.finditer(r"id:\s*'([^']+)'.*?name:\s*'([^']+)'.*?enName:\s*'([^']+)'", s, _re.S):
        m[mm.group(3)] = mm.group(2)
    return m

def verify_title(tree, en_name):
    """返回 (ok, 实际标题)。用「中文名是否出现在 dump 里」判「点对了没」"""
    m = game_title_map()
    want = m.get(en_name, '')
    texts = []
    def w(n):
        a = n.get('attributes', {})
        t = (a.get('text') or '')
        if t: texts.append(t)
        for c in (n.get('children') or []): w(c)
    w(tree)
    joined = '\n'.join(texts)
    if not want:
        return True, ''
    # ⚠️ 2026-11-09：**光「包含标题」不够** —— 首页的卡片上也写着「文氏图, 集合运算」
    #   ⇒ 必须同时「没有首页标记」（底部 tab「今天这一局 / 全部」与搜索框）
    on_home = ('今天这一局' in joined) or ('全部' in joined and '🎯' in joined)
    if on_home:
        return False, want
    return (want in joined), want

def is_home():
    """首页判据：有「355 款」或「🔍/💬」顶栏 + 有分类标签「全部」"""
    d = dump('/data/local/tmp/home.json')
    if not d:
        return False
    texts = [t for t, _ in collect(d, lambda t: True)]
    joined = ''.join(texts)
    return ('One More' in joined) and ('全部' in joined or '355 款' in joined)

def ensure_home():
    """⚠️ v13：回首页（全量扫描里 28 款 `NOT_HOME` ⇒ 三次 Back 不够）
    ① Back 最多 4 次，每次 1.2s
    ② 兜底：重开 Ability（首页必然干净）
    """
    for _ in range(4):
        if is_home():
            return True
        sh('uitest uiInput keyEvent Back')
        time.sleep(1.2)
    if is_home():
        return True
    # 兜底：直接重启 Ability（比「猜 Back 几次」可靠）
    sh('aa force-stop com.andrewoscar.onemore')
    time.sleep(1.0)
    sh('aa start -a EntryAbility -b com.andrewoscar.onemore')
    time.sleep(6.0)
    return is_home()

def verify_one(en_name):
    """返回 (状态, 关键数据)"""
    if not ensure_home():
        return ('NOT_HOME', {})
    search_game(en_name)
    d = dump()
    if not d:
        close_search()
        return ('DUMP_FAIL', {})
    # 找卡片（text 含 en_name 或中文名的第一个可点节点）
    cards = collect(d, lambda t: len(t) > 0 and len(t) < 80)
    # 结果计数
    cnt = None
    for t, (x1, y1, x2, y2) in cards:
        if re.match(r'^\d+ 款$', t.strip()):
            cnt = int(t.replace('款', '').strip()); break
    if cnt == 0:
        close_search()
        return ('NOT_FOUND', {})
    # 点第一个「结果卡片」（卡片区 y≈627-934 的第一列）
    # ⚠️ v15（判据 1861）：**按名字挑卡片**，不盲点第一张（搜索没过滤时会点到首页卡）
    want = game_title_map().get(en_name, '')
    target = None
    for t, (x1, y1, x2, y2) in cards:
        if 560 < y1 < 1000 and x2 > x1 + 100:
            if (want and want in t) or (en_name in t):
                target = ((x1 + x2) // 2, (y1 + y2) // 2); break
    if not target:
        close_search()
        return ('NO_CARD', {'want': want})
    sh(f'uitest uiInput click {target[0]} {target[1]}')
    time.sleep(3.0)   # ⚠️ v6：2.2 不够
    # ⚠️ v8：路径不能有空格（hdc shell 会按空格切参数）
    #   v7 日志实测：`-p /data/local/tmp/game_Snake 3D` 被切成「game_Snake」+「3D」
    #   ⇒ dumpLayout 写到「game_Snake」、cat 读「game_Snake 3D.json」⇒ 读不到 ⇒ None
    safe = re.sub(r'[^A-Za-z0-9_]', '_', en_name)
    # ⚠️ v9：两次采样。真机实测「2048 一次量 1600、另一次 1557」——
    #   游戏内容会随状态变化（msg 行/演示条/棋盘缩放），单次采样会误报。
    #   ⇒ 取「两次里的最小值」当 best-case：最小值都贴底才算真出屏。
    # ⚠️ v10：三次采样（实测两次还不够 —— `Compound Connect` 两次都给 1600、单独再测 1351）
    #   原因：进游戏瞬间「演示条 / 进场动画」还没收敛，会把 max_bottom 顶到屏底。
    time.sleep(1.2)
    d2 = dump(f'/data/local/tmp/game_{safe}.json')
    time.sleep(1.4)
    d2b = dump(f'/data/local/tmp/game_{safe}_b.json')
    time.sleep(1.4)
    d2c = dump(f'/data/local/tmp/game_{safe}_c.json')
    if not d2:
        sh('uitest uiInput keyEvent Back'); close_search()
        return ('GAME_DUMP_FAIL', {})
    # ⭐ 进游戏判据：dump 里必须出现「游戏内元素」（提示 / AI 代打 / 重开）
    texts2 = [t for t, _ in collect(d2, lambda t: True)]
    in_game = any(k in ''.join(texts2) for k in ('提示', 'AI 代打', '重开', '换一题', '放弃'))
    if not in_game:
        sh('uitest uiInput keyEvent Back'); close_search()
        return ('NOT_IN_GAME', {'texts': texts2[:5]})
    # ⚠️ v4：max_bottom 只看「有文本」的节点（排除根容器/装饰背景）
    def bottom_of(tree):
        ns = collect(tree, lambda t: len(t.strip()) > 0)
        mb = max((y2 for _, (_, _, _, y2) in ns), default=0)
        lo = ''
        for t, (_, _, _, y2) in ns:
            if y2 == mb:
                lo = t[:30]; break
        return mb, lo
    if d2 and isinstance(d2, dict):
        ok_t, want_t = verify_title(d2, en_name)
        if not ok_t:
            sh('uitest uiInput keyEvent Back'); close_search()
            return ('WRONG_GAME', {'want': want_t})
    clip_n, clip_y, clip_t = clipped_text(d2 if d2 else {})
    cands = []
    for tree in (d2, d2b, d2c):
        if tree:
            cands.append(bottom_of(tree))
    if not cands:
        cands = [(0, '')]
    max_bottom, lowest = min(cands, key=lambda x: x[0])   # 取 best-case（三次里的最小值）

    # ⚠️ v12 尝试：「用『有没有节点被父盒子裁掉』判真/假」——**失败，已回退**
    #   实测 `Sudoku`（看图完全正常）也被判 clip=2：因为「底部按钮行」整个在
    #   「游戏区盒子（底 1516）」之外，属设计，不是裁。
    #   ⇒ **结论：自动分级不可靠，一律给截图（v11），由人看图判**（判据 1854）。
    if max_bottom <= CONTENT_BOTTOM:
        status = 'OK'
    elif max_bottom <= GESTURE_LIMIT:
        status = 'TIGHT'
    else:
        status = 'PUSHED_OUT'
    shot = ''
    if status != 'OK':
        shot = save_shot(safe)          # ⚠️ v11：非 OK 自动存截图
    sh('uitest uiInput keyEvent Back')
    time.sleep(0.8)
    close_search()
    return (status, {'max_bottom': max_bottom, 'lowest': lowest, 'count': cnt, 'shot': shot, 'clip': clip_n, 'clip_at': f'{clip_t}@{clip_y}'})

def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    if sys.argv[1] == '--list':
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        # 从全量清单里挑「有 enName」的前 n 款
        reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
        pat = re.compile(r"id:\s*'([^']+)'.*?enName:\s*'([^']+)'", re.S)
        targets = [m.group(2) for m in pat.finditer(reg)][:n]
    else:
        targets = sys.argv[1:]
    results = []
    for t in targets:
        st, info = verify_one(t)
        results.append({'game': t, 'status': st, **info})
        print(f"{st:12s} {t:24s} {info}")
    out = '_巡检记录/layout-verify-result.json'
    io.open(out, 'w', encoding='utf-8').write(json.dumps(results, ensure_ascii=False, indent=1))
    print(f"\n汇总：{out}")

if __name__ == '__main__':
    main()
