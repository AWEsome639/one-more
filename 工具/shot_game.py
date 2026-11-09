# -*- coding: utf-8 -*-
"""对某一款游戏「拍照存证」——给「PUSHED_OUT 候选」做人工核对用（判据 1819 第五类）

用法：python3 工具/shot_game.py "FreeCell"
输出：_巡检记录/截图-<安全名>-<时间戳>.jpeg + 控制台打印 max_bottom
"""
import io, os, re, subprocess, sys, time, json

HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
DEV = '127.0.0.1:5557'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def sh(cmd, timeout=30):
    try:
        r = subprocess.run([HC, '-t', DEV, 'shell', cmd], capture_output=True, text=True, timeout=timeout)
        return r.stdout or ''
    except Exception:
        return ''

def dump(p='/data/local/tmp/shot.json'):
    sh(f'uitest dumpLayout -p {p}')
    try:
        return json.loads(sh(f'cat {p}'))
    except Exception:
        return None

def texts(tree, pred=lambda t: True):
    out = []
    def w(n):
        a = n.get('attributes', {})
        t = (a.get('text') or ''); b = (a.get('bounds') or '')
        m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b or '')
        if m and t and pred(t):
            out.append((t, tuple(int(x) for x in m.groups())))
        for c in (n.get('children') or []):
            w(c)
    w(tree)
    return out

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
    d = dump('/data/local/tmp/shot_home.json')
    if not d:
        return False
    j = ''.join(t for t, _ in texts(d))
    return 'One More' in j and ('全部' in j or '355 款' in j)

def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    name = sys.argv[1]
    for _ in range(3):
        if is_home(): break
        sh('uitest uiInput keyEvent Back'); time.sleep(1.2)
    if not is_home():
        print('NOT_HOME'); return
    # ⚠️ 2026-11-09：**搜索词只取第一个词会搜不到**（如 "Set Theory Venn" 只打 "Set"）
    #   ⇒ 依次试「最长词 / 首词 / 全名」；每次重开搜索页（不靠清空输入框）
    want_zh = game_title_map().get(name, '')
    tokens = []
    for t in sorted(set(name.split()), key=lambda w: -len(w)):
        if t.lower() not in ('all', 'the'):
            tokens.append(t)
    tokens = tokens[:3] + [name]
    d = None
    for tok in tokens:
        sh('uitest uiInput click 2276 264'); time.sleep(1.2)
        sh('uitest uiInput click 1280 435'); time.sleep(0.8)
        sh(f"uinput -K -t '{tok}'"); time.sleep(2.4)
        d = dump('/data/local/tmp/shot_r.json')
        if not d:
            continue
        hit = any(((want_zh and want_zh in (t or '')) or (name in (t or ''))) for t, _ in texts(d))
        if hit:
            break
        sh('uitest uiInput keyEvent Back'); time.sleep(0.8)
    if not d:
        print('DUMP_FAIL'); return
    # ⚠️ 判据 1861：**按名字挑卡片**，不能「点第一张」（搜索没过滤时会点到「宝石迷阵」）
    m = game_title_map()
    want = m.get(name, '')
    card = None; fallback = None
    for t, (x1, y1, x2, y2) in texts(d):
        if 560 < y1 < 1000 and x2 > x1 + 100:
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            if fallback is None:
                fallback = (cx, cy)
            if (want and want in t) or (name in t):
                card = (cx, cy); break
    if card is None:
        print(f'NO_CARD  {name}（搜索结果里没有「{want or name}」的卡片；不盲点第一张）')
        return
    if not card:
        print('NO_CARD'); return
    sh(f'uitest uiInput click {card[0]} {card[1]}'); time.sleep(3.0)
    d2 = dump('/data/local/tmp/shot_g.json')
    if d2 and isinstance(d2, dict):
        ok, want = verify_title(d2, name)
        if not ok:
            seen = []
            def _w(n):
                a = n.get('attributes', {}); t = (a.get('text') or '')
                if t and len(t) < 20: seen.append(t)
                for c in (n.get('children') or []): _w(c)
            _w(d2)
            print(f'WRONG_GAME  {name}（找不到标题「{want}」；页面首几个文本={seen[:6]}）')
            return
    mb = 0; lo = ''
    if d2:
        for t, (_, _, _, y2) in texts(d2):
            if y2 > mb:
                mb = y2; lo = t[:26]
    safe = re.sub(r'[^A-Za-z0-9_]', '_', name)
    ts = time.strftime('%H%M%S')
    out = os.path.join(ROOT, '_巡检记录', f'截图-{safe}-{ts}.jpeg')
    sh(f'snapshot_display -f /data/local/tmp/shot_{safe}.jpeg')
    subprocess.run([HC, '-t', DEV, 'file', 'recv', f'/data/local/tmp/shot_{safe}.jpeg', out],
                   capture_output=True, text=True, timeout=90)
    print(f'{name}: max_bottom={mb} lowest={lo!r} -> {out}')

if __name__ == '__main__':
    main()
