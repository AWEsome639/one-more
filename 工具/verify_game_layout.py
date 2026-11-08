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
    try:
        r = subprocess.run([HC, '-t', DEV, 'shell', cmd], capture_output=True, text=True, timeout=timeout)
        return r.stdout or ''
    except Exception:
        return ''

def dump(path='/data/local/tmp/layout.json'):
    sh(f'uitest dumpLayout -p {path}')
    raw = sh(f'cat {path}')
    try:
        return json.loads(raw)
    except Exception:
        return None

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
    sh(f"uinput -K -t '{en_name}'")
    time.sleep(1.6)

def close_search():
    if in_search_mode():
        sh('uitest uiInput click 2276 264')
        time.sleep(0.7)

def verify_one(en_name):
    """返回 (状态, 关键数据)"""
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
    target = None
    for t, (x1, y1, x2, y2) in cards:
        if 560 < y1 < 1000 and x2 > x1 + 100:
            target = ((x1 + x2) // 2, (y1 + y2) // 2); break
    if not target:
        close_search()
        return ('NO_CARD', {})
    sh(f'uitest uiInput click {target[0]} {target[1]}')
    time.sleep(2.2)
    d2 = dump()
    if not d2:
        sh('uitest uiInput keyEvent Back'); close_search()
        return ('GAME_DUMP_FAIL', {})
    # ⭐ 进游戏判据：dump 里必须出现「游戏内元素」（提示 / AI 代打 / 重开）
    texts2 = [t for t, _ in collect(d2, lambda t: True)]
    in_game = any(k in ''.join(texts2) for k in ('提示', 'AI 代打', '重开', '换一题', '放弃'))
    if not in_game:
        sh('uitest uiInput keyEvent Back'); close_search()
        return ('NOT_IN_GAME', {'texts': texts2[:5]})
    # 内容区：找「最底部有内容的节点」
    nodes = collect(d2, lambda t: True)
    max_bottom = max((y2 for _, (_, _, _, y2) in nodes), default=0)
    if max_bottom <= CONTENT_BOTTOM:
        status = 'OK'
    elif max_bottom <= GESTURE_LIMIT:
        status = 'TIGHT'
    else:
        status = 'PUSHED_OUT'
    sh('uitest uiInput keyEvent Back')
    time.sleep(0.8)
    close_search()
    return (status, {'max_bottom': max_bottom, 'count': cnt})

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
