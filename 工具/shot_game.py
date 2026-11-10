import re
# -*- coding: utf-8 -*-
"""对某一款游戏「拍照存证」——给「PUSHED_OUT 候选」做人工核对用（判据 1819 第五类）

用法：python3 工具/shot_game.py "FreeCell"
输出：
  · 一行机器可读结果：  name \t outcome \t max_bottom \t elapsed_s [额外说明]
  · _巡检记录/截图-<安全名>-<时间戳>.jpeg（成功时）

★ 2026-11-10 加固（见 `_巡检记录/工具加固-shot_game.md`）四条：
  ① **真超时**：Popen(start_new_session=True) + 超时 `killpg(SIGKILL)` + 二次 `communicate(5)`
     —— 不再用 `subprocess.run(timeout=)`（它超时只 kill 自己，`communicate()` 仍等管道 EOF ⇒ 挂死）
  ② **dump 唯一路径**：`/data/local/tmp/shot_<pid>_<seq>_<tag>.json`，先 `rm -f` ⇒ 不会读到上一款的旧文件
  ③ **单款硬预算 150s**：超预算立刻收尾并记 `TIMEOUT`（所有外部调用都按剩余预算封顶）
  ④ **所有出口都打一行**：`finish()` 统一出口，永不静默
"""
import io, os, re, signal, subprocess, sys, time, json, traceback

HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
DEV = '127.0.0.1:5557'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUDGET_S = 150.0          # ③ 单款硬预算
DEADLINE = 0.0            # main() 里初始化


class Timeout(Exception):
    """**硬超时**（进程组已被 SIGKILL），与普通异常区分开。"""


def budget_left():
    """剩余预算秒数（未初始化时返回一个大数，方便单独 import 测试）。"""
    if DEADLINE <= 0:
        return 9999.0
    return DEADLINE - time.monotonic()


# ═══════════════ ① 硬超时执行器 ═══════════════

def run(argv, timeout):
    """执行 argv，**超时杀整个进程组**，绝不挂住。

    为什么不用 `subprocess.run(timeout=)`：
      它超时只 `kill()` 子进程本身，随后 `communicate()` 仍要等 stdout/stderr 的 EOF
      —— 只要 hdc 留下一个握着管道的子进程，`run()` 就**永不返回**
      （这就是批处理「跑到 56/68 无声结束」的主因）。
    这里：`start_new_session=True` 让子进程自成进程组 ⇒ 超时用 `killpg` 连子进程一起杀，
    再 `communicate(timeout=5)` 收尸；收不到也照抛 `Timeout`，调用方一定拿到控制权。
    """
    try:
        p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, start_new_session=True)
    except Exception as e:                       # hdc 不存在 / 权限等
        raise Timeout('spawn-failed: %r' % (e,))
    try:
        out, err = p.communicate(timeout=timeout)
        return p.returncode, (out or ''), (err or '')
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGKILL)   # ← 连子进程一起杀
        except Exception:
            pass
        try:
            p.communicate(timeout=5)                       # ← 收尸，最多再等 5s
        except Exception:
            pass
        raise Timeout('timeout %ss: %s' % (timeout, argv[-1:][0][:60] if argv else ''))


def sh(cmd, timeout=30):
    """跑一条设备 shell 命令，返回 `(ok, out)`；**失败不吞成空串**（ok=False 让上层能判断）。"""
    t = min(float(timeout), max(2.0, budget_left()))
    try:
        rc, out, _err = run([HC, '-t', DEV, 'shell', cmd], t)
        return (rc == 0), (out or '')
    except Timeout:
        return False, ''


# ═══════════════ ② 唯一路径 dump ═══════════════

_SEQ = 0


def dump(tag='d', timeout=25):
    """dump 当前布局。**唯一路径 + 先 rm** ⇒ 绝不清到上一款的旧文件。"""
    global _SEQ
    _SEQ += 1
    p = '/data/local/tmp/shot_%d_%d_%s.json' % (os.getpid(), _SEQ, tag)
    sh('rm -f ' + p, 10)                          # 先清，确保"读到的不是旧的"
    ok, _ = sh('uitest dumpLayout -p ' + p, timeout)
    if not ok:
        return None                               # dump 本身失败 ⇒ 本次无效
    ok2, txt = sh('cat ' + p, 15)
    if not ok2 or not txt.strip():
        return None                               # 文件不存在/空 ⇒ 本次无效
    try:
        return json.loads(txt)
    except Exception:
        return None                               # 解析失败 = 本次无效（不会拿旧文件）


def texts(tree, pred=lambda t: True):
    out = []

    def w(n):
        a = n.get('attributes', {})
        t = (a.get('text') or '')
        b = (a.get('bounds') or '')
        m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b or '')
        if m and t and pred(t):
            out.append((t, tuple(int(x) for x in m.groups())))
        for c in (n.get('children') or []):
            w(c)

    if not isinstance(tree, dict):
        return out
    w(tree)
    return out


# ═══════════════ ⑦ 标题表缓存（顺手，每款至少 3 次调用） ═══════════════

_TITLE_CACHE = None


def _find_text_node(tree, want):
    """在 dump 树里找 text==want 的节点，返回其中心 (x, y)；找不到返回 None。"""
    hit = []

    def walk(n):
        if isinstance(n, dict):
            a = n.get('attributes', {}) or {}
            if a.get('text') == want:
                b = (a.get('bounds') or '').strip()
                nums = [int(x) for x in re.findall(r'-?\d+', b)] if b else []
                if len(nums) == 4:
                    hit.append(((nums[0] + nums[2]) // 2, (nums[1] + nums[3]) // 2))
            for c in (n.get('children') or []):
                walk(c)
    walk(tree)
    return hit[0] if hit else None


def game_title_map():
    """enName → 中文名（从 GameRegistry 解析；**带缓存**，不只因慢，也避免中途文件变化）"""
    global _TITLE_CACHE
    if _TITLE_CACHE is not None:
        return _TITLE_CACHE
    try:
        s = io.open(os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets'),
                    encoding='utf-8').read()
    except Exception:
        _TITLE_CACHE = {}
        return _TITLE_CACHE
    m = {}
    for mm in re.finditer(r"id:\s*'([^']+)'.*?name:\s*'([^']+)'.*?enName:\s*'([^']+)'", s, re.S):
        m[mm.group(3)] = mm.group(2)
    _TITLE_CACHE = m
    return m


def verify_title(tree, en_name):
    """返回 (ok, 实际标题)。用「中文名是否出现在 dump 里」判「点对了没」"""
    m = game_title_map()
    want = m.get(en_name, '')
    tt = []

    def w(n):
        a = n.get('attributes', {})
        t = (a.get('text') or '')
        if t:
            tt.append(t)
        for c in (n.get('children') or []):
            w(c)

    if not isinstance(tree, dict):
        return False, want
    w(tree)
    joined = '\n'.join(tt)
    if not want:
        return True, ''
    # ⚠️ 2026-11-09：**光「包含标题」不够** —— 首页的卡片上也写着「文氏图, 集合运算」
    #   ⇒ 必须同时「没有首页标记」（底部 tab「今天这一局 / 全部」与搜索框）
    # ★ 2026-11-10：**首页标记不可靠**（换 tab 就没有「今天这一局」）⇒ 改成「必须有游戏内元素」
    on_home = ('今天这一局' in joined) or ('全部' in joined and '🎯' in joined)
    in_game = ('AI 代打' in joined) or ('提示' in joined)
    if on_home or not in_game:
        return False, want
    return (want in joined), want


def is_home():
    d = dump('home')
    if not d:
        return False
    j = ''.join(t for t, _ in texts(d))
    return 'One More' in j and ('全部' in j or '355 款' in j)


# ═══════════════ ④ 统一出口 ═══════════════

def finish(name, outcome, t0, mb=None, extra=''):
    """**所有 return 都走这里**：一款一行，带 outcome / max_bottom / 耗时，永不静默。"""
    el = time.monotonic() - t0
    head = '%s\t%s\t%s\t%.1fs' % (name, outcome, '-' if mb is None else str(mb), el)
    print(head + ((' ' + extra) if extra else ''), flush=True)


def _need_budget(name, t0, where):
    """预算检查：不够了就打 TIMEOUT 并返回 False。"""
    if budget_left() <= 0:
        finish(name, 'TIMEOUT', t0, None, 'budget exhausted at %s' % where)
        return False
    return True


# ═══════════════ 主流程 ═══════════════

def _body(name, t0):
    # ★ 2026-11-09：回首页兜底（复测里 40 款 `NOT_HOME` 就是这里只有「Back 三次」）
    for _ in range(4):
        if not _need_budget(name, t0, 'home-loop'):
            return
        if is_home():
            break
        sh('uitest uiInput keyEvent Back')
        time.sleep(1.2)
    if not is_home():
        sh('aa force-stop com.andrewoscar.onemore')
        time.sleep(1.0)
        sh('aa start -a EntryAbility -b com.andrewoscar.onemore')
        time.sleep(6.0)
    if not is_home():
        finish(name, 'NOT_HOME', t0, None, 'could not reach home')
        return

    # ⚠️ 2026-11-09：**搜索词只取第一个词会搜不到**（如 "Set Theory Venn" 只打 "Set"）
    #   ⇒ 依次试「最长词 / 首词 / 全名」；每次重开搜索页（不靠清空输入框）
    want_zh = game_title_map().get(name, '')
    tokens = []
    # ★ 2026-11-11：**中文名优先** —— 搜英文名对一批游戏（`Go (9x9)` / `Bubble Shooter` …）`NO_CARD`；
    #   中文名才是搜索框真正认的词。另外**去掉括号里的限定词**（`Go (9x9)` → `Go`）。
    _base = name.split('(')[0].strip()
    if want_zh:
        tokens.append(want_zh)
    for t in sorted(set(_base.split()), key=lambda w: -len(w)):
        if t.lower() not in ('all', 'the') and t not in tokens:
            tokens.append(t)
    tokens = tokens[:4] + [_base, name]
    d = None
    for tok in tokens:
        if not _need_budget(name, t0, 'search:%s' % tok):
            return
        # ⚠️ 2026-11-09：**每次尝试都必须「先回到首页」** —— 否则 Back 会把 App 退掉，
        #   后续 click 落到系统界面（真机实测：点进了「设置」）⇒ 全部 FAIL
        for _b in range(4):
            if not _need_budget(name, t0, 'search-home:%s' % tok):
                return
            if is_home():
                break
            sh('uitest uiInput keyEvent Back')
            time.sleep(1.0)
        if not is_home():
            sh('aa start -a EntryAbility -b com.andrewoscar.onemore')
            time.sleep(6.0)
        # ★ 2026-11-11（真机抓到的 bug）：**首页「搜索框里还留着上一次的词」也算 home**
        #   ⇒ 新词会拼到旧词后面 ⇒ 搜不到任何卡片（今晚 27 款回归全 no_card 就是这个）
        #   ⇒ 搜之前先点 `✕` 清空（`✕` 只在搜索框有内容时出现）
        _d0 = dump()
        _hit = _find_text_node(_d0, '✕') if _d0 else None
        if _hit:
            sh('uitest uiInput click %d %d' % (_hit[0], _hit[1]))
            time.sleep(0.6)
        sh('uitest uiInput click 2276 264')
        time.sleep(1.2)
        sh('uitest uiInput click 1280 435')
        time.sleep(0.8)
        sh("uinput -K -t '%s'" % tok)
        time.sleep(2.4)
        d = dump('r')
        if not d:
            continue
        hit = any(((want_zh and want_zh in (t or '')) or (name in (t or ''))) for t, _ in texts(d))
        if hit:
            break
        sh('uitest uiInput keyEvent Back')
        time.sleep(0.8)
    if not d:
        finish(name, 'DUMP_FAIL', t0, None, 'no search dump')
        return

    # ⚠️ 判据 1861：**按名字挑卡片**，不能「点第一张」（搜索没过滤时会点到「宝石迷阵」）
    want = game_title_map().get(name, '')
    card = None
    fallback = None
    for t, (x1, y1, x2, y2) in texts(d):
        if 560 < y1 < 1000 and x2 > x1 + 100:
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            if fallback is None:
                fallback = (cx, cy)
            if (want and want in t) or (name in t):
                card = (cx, cy)
                break
    if card is None:
        finish(name, 'NO_CARD', t0, None,
               'no card for %r (fallback=%r)' % (want or name, fallback))
        return
    if not _need_budget(name, t0, 'enter-game'):
        return
    sh('uitest uiInput click %d %d' % (card[0], card[1]))
    time.sleep(3.0)

    # ★ 2026-11-09（判据 1865）：**先等演示结束再量** —— 演示条 `DemoBar` 占 `~24vp(72px)`，
    #   不固定这个状态，两次测量能差 80px（`Nim` 1351 vs 1600 就是它）
    d2 = None
    for _dw in range(6):
        if not _need_budget(name, t0, 'demo-wait'):
            return
        d2 = dump('g')
        _jt = '\n'.join(t for t, _ in texts(d2)) if d2 else ''
        if '演示中' not in _jt:
            break
        time.sleep(3.0)
    if not d2:
        finish(name, 'DUMP_FAIL', t0, None, 'no in-game dump')
        return
    if isinstance(d2, dict):
        ok, want2 = verify_title(d2, name)
        if not ok:
            seen = []

            def _w(n):
                a = n.get('attributes', {})
                t = (a.get('text') or '')
                if t and len(t) < 20:
                    seen.append(t)
                for c in (n.get('children') or []):
                    _w(c)

            _w(d2)
            finish(name, 'WRONG_GAME', t0, None,
                   'title %r not found; first texts=%r' % (want2, seen[:6]))
            return

    mb = 0
    lo = ''
    for t, (_, _, _, y2) in texts(d2):
        if y2 > mb:
            mb = y2
            lo = t[:26]

    safe = re.sub(r'[^A-Za-z0-9_]', '_', name)
    ts = time.strftime('%H%M%S')
    out = os.path.join(ROOT, '_巡检记录', '截图-%s-%s.jpeg' % (safe, ts))
    remote = '/data/local/tmp/shot_%s_%s.jpeg' % (safe, ts)
    sh('snapshot_display -f ' + remote)

    recv_ok = False
    try:
        rc, _o, _e = run([HC, '-t', DEV, 'file', 'recv', remote, out], 60)
        recv_ok = (rc == 0 and os.path.exists(out))
    except Timeout:
        recv_ok = False

    # ★ 2026-11-10（判据 1889）：结果行带测量时间戳，否则「按文件 mtime 取最新」会被拷贝污染
    import datetime as _dt
    _ts = _dt.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
    if recv_ok:
        finish(name, 'OK', t0, mb,
               'lowest=%r -> %s @%s' % (lo, out, _ts))
    else:
        finish(name, 'OK_NOSHOT', t0, mb,
               'lowest=%r recv failed @%s' % (lo, _ts))


def main():
    global DEADLINE
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help', 'help'):
        print(__doc__)
        return
    name = sys.argv[1]
    t0 = time.monotonic()
    DEADLINE = t0 + BUDGET_S              # ③ 单款硬预算
    try:
        _body(name, t0)
    except Timeout as e:
        finish(name, 'TIMEOUT', t0, None, str(e))
    except Exception as e:                # ④ 任何异常都留一行，不静默
        finish(name, 'CRASH', t0, None, repr(e)[:120])
        traceback.print_exc(limit=2, file=sys.stderr)


if __name__ == '__main__':
    main()
