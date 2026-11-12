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
DEV = '127.0.0.1:5557'   # ⚠️ 已被 _target() 取代（保留仅为兼容老引用；实际调用都走 _target()）
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUDGET_S = 260.0          # ③ 单款硬预算（2026-11-11：机器负载高时单次 dump 可达 20s，150 会把正常款判成 TIMEOUT）
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


# ★ 2026-11-12（判据 1934，**今晚 `153` 次 `NOT_HOME` 的真凶**）：
#   **模拟器的端口会变** —— `adb` 占着 `5555` 时它退到 `5557`；`adb` 退出后又回到 `5555`。
#   而本工具写死了 `127.0.0.1:5557` ⇒ **端口一变，全部命令打到空气里**，报出来却是 `NOT_HOME`（指向被测对象）。
#   ⇒ 每次执行命令前，把它里面的 `127.0.0.1:5557` 换成「`hdc list targets` 真正给出的那个」。
TARGET_PORT_FIX = True


def _target():
    env = os.environ.get('ONEMORE_TARGET', '').strip()
    if env:
        return env
    try:
        # ★ 2026-11-12：**必须用绝对路径 `HC`** —— 裸 `hdc` 在 subprocess 里常常不在 PATH，
        #   失败后回落到硬编码 5557，反而把「端口变了」伪装成「设备不在」。
        out = subprocess.run('%s list targets' % HC, shell=True, capture_output=True, text=True, timeout=20).stdout
    except Exception:
        out = ''
    for line in (out or '').splitlines():
        line = line.strip()
        if re.match(r'^\d+\.\d+\.\d+\.\d+:\d+$', line):
            return line
    return '127.0.0.1:5557'


def sh(cmd, timeout=30):
    """跑一条设备 shell 命令，返回 `(ok, out)`；**失败不吞成空串**（ok=False 让上层能判断）。"""
    t = min(float(timeout), max(2.0, budget_left()))
    try:
        rc, out, _err = run([HC, '-t', _target(), 'shell', cmd], t)
        return (rc == 0), (out or '')
    except Timeout:
        return False, ''


# ═══════════════ ② 唯一路径 dump ═══════════════

_SEQ = 0


def dump(tag='d', timeout=60):
    # ★ 2026-11-12（判据 1953）：**`dump` 超时 25s 太短** ——
    #   机器负载高时单次 dump 可达 `30~40s` ⇒ 返回 None ⇒ `is_home()` 假 ⇒ **误报 `NOT_HOME`**。
    #   今天下午大量 `NOT_HOME` 其实是这个：手工 `cat` 同一个 dump 文件是**有内容**的。
    #   ⇒ 放宽到 `60s`（仍有 `budget_left()` 兜底）。
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
    ok = 'One More' in j and ('全部' in j or '355 款' in j)
    # ★ 2026-11-11（判据 1910）：**「首页 + 搜索框有内容」不算初始态** ——
    #   `✕` 只在搜索框有内容时出现；不清空就会把新词拼到旧词后面 ⇒ 全部 no_card
    if ok and '✕' in j:
        return False
    return ok


# ═══════════════ ④ 统一出口 ═══════════════

def finish(name, outcome, t0, mb=None, extra=''):
    """**所有 return 都走这里**：一款一行，带 outcome / max_bottom / 耗时，永不静默。"""
    el = time.monotonic() - t0
    head = '%s\t%s\t%s\t%.1fs' % (name, outcome, '-' if mb is None else str(mb), el)
    line = head + ((' ' + extra) if extra else '')
    print(line, flush=True)
    # ★ 2026-11-12（判据 1945）：**每次测量都追加到唯一一份正式台账** ——
    #   我之前只在终端打印，聚合时只能退回「文件 mtime」，**差点被自己的表骗了**
    #   （已修好的 `Math Path 1450` / `Kakurasu 1464` 在聚合表里仍显示 `1600`）。
    try:
        with io.open(os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv'), 'a', encoding='utf-8') as fh:
            fh.write('%s\t%s\n' % (time.strftime('%Y-%m-%dT%H:%M:%S'), line))
    except Exception:
        pass


def _need_budget(name, t0, where):
    """预算检查：不够了就打 TIMEOUT 并返回 False。"""
    if budget_left() <= 0:
        finish(name, 'TIMEOUT', t0, None, 'budget exhausted at %s' % where)
        return False
    return True


# ═══════════════ 主流程 ═══════════════

def _body(name, t0):
    # ★ 2026-11-11（判据 1920）：**每款开工前先「干净重启 + 轮询到首页」** ——
    #   放在 `_body` 最前面（不是搜索前），因为 `NOT_HOME` 的出入口就在这里。
    #   结算弹层没有任何可点关闭件时，`Back` 永远被吃；只有重启能回初始态。
    # ★ 2026-11-11（判据 1921）：**`Back` 会把 App 退到系统、把「设置」拉到前台** ——
    #   实测 `dump` 出来的可见文本是 `['设置','One More',…]` ⇒ 之后 `is_home()` 永远假。
    #   ⇒ 先按 `Home`（回桌面），再重启 App。
    sh('uitest uiInput keyEvent Home')
    time.sleep(0.8)
    sh('aa force-stop com.andrewoscar.onemore')
    time.sleep(1.0)
    sh('aa start -a EntryAbility -b com.andrewoscar.onemore')
    # ★ 2026-11-12（判据 1949 的量化）：**App 冷启动要 30~60s** ——
    #   原来「6×3s=18s」在高负载下不够，`dump` 只拿到状态栏（`['03:11','100']`）⇒ 误报 `NOT_HOME`。
    #   ⇒ 先固定等 `20s`（给启动过程），再轮询 `10×4s=40s`。
    # ★★★ 2026-11-12（判据 1954，**今天下午所有 `NOT_HOME` 的真凶**）：
    #   `aa force-stop` 之后再 `aa start`，**`uitest dumpLayout` 会抓不到 App 窗口**
    #   （只返回状态栏 `['03:11','100']`）⇒ `is_home()` 假 ⇒ 误报 `NOT_HOME`。
    #   **实测：再发一次 `aa start` 就正常了。**
    time.sleep(25.0)
    sh('aa start -a EntryAbility -b com.andrewoscar.onemore')   # ← 关键：第二次 start
    time.sleep(8.0)
    for _w in range(10):
        time.sleep(4.0)
        if is_home():
            break
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
        # ★ 2026-11-11（判据 1912 的真落地）：**固定 sleep(6) 不够**（冷启动常常 >6s）
        #   改成轮询：4 轮 × 3s，每轮都试 `is_home()`
        for _w in range(4):
            time.sleep(3.0)
            if is_home():
                break
    if not is_home():
        finish(name, 'NOT_HOME', t0, None, 'could not reach home')
        return

    # ⚠️ 2026-11-09：**搜索词只取第一个词会搜不到**（如 "Set Theory Venn" 只打 "Set"）
    #   ⇒ 依次试「最长词 / 首词 / 全名」；每次重开搜索页（不靠清空输入框）
    # ★ 2026-11-11（判据 1922）：**中文名搜不到 —— `uitest uiInput` 打不进中文**（IME 层）
    #   实测：`七巧板`/`上下文线索`/`不等式` 全 `NO_CARD`，而 `Tangram`/`Context Clues` 一次就成。
    #   ⇒ 传进来若是中文名，**先反查英文名**再用英文搜。
    if re.search(r'[\u4e00-\u9fff]', name):
        _reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
        _m = re.search(r"name: '%s'.*?enName: '([^']+)'" % re.escape(name), _reg)
        if _m:
            name = _m.group(1)
    want_zh = game_title_map().get(name, '')
    tokens = []
    # ★ 2026-11-11：**中文名优先** —— 搜英文名对一批游戏（`Go (9x9)` / `Bubble Shooter` …）`NO_CARD`；
    #   中文名才是搜索框真正认的词。另外**去掉括号里的限定词**（`Go (9x9)` → `Go`）。
    _base = name.split('(')[0].strip()
    if want_zh:
        tokens.append(want_zh)
        # ★ 2026-11-11（code-hunter 的推断）：**含空格/数字的中文名最容易被 `uinput` 打字层吃掉**
        #   全库只有 7 款这种名（`24 点` / `9 路围棋` / `双 N-back` / `AB 反转` / `3D 迷宫` / `d2 注意` / `2048`）
        #   ⇒ 再试一个「去数字、去空格、去连字符」的变体
        _stripped = re.sub(r'[0-9０-９\s\-]', '', want_zh)
        if _stripped and _stripped != want_zh and len(_stripped) >= 2:
            tokens.append(_stripped)
    for t in sorted(set(_base.split()), key=lambda w: -len(w)):
        if t.lower() not in ('all', 'the') and t not in tokens:
            tokens.append(t)
    tokens = tokens[:4] + [_base, name]
    # ★ 2026-11-11（判据 1916）：**每款开工前先「强杀 + 重启 + 轮询到首页」** ——
    #   部分游戏的结算弹层没有任何可点关闭件，Back 永远被吃 ⇒ NOT_HOME 占到失败的 3/4。
    #   实测「干净重启」是唯一稳的回初始态方式（每款多 ~8s，换来接近 100% 的覆盖率）。
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
            # ★ 2026-11-11（判据 1913）：**结算弹层会吃掉 Back** ——
            #   先找弹层上的「关闭/返回/知道了/✕/再来一局」，有就点它，再按 Back。
            _dd = dump()
            _closed = False
            for _t in ('关闭', '知道了', '返回', '再来一局', '✕', '×'):
                _h = _find_text_node(_dd, _t) if _dd else None
                if _h:
                    sh('uitest uiInput click %d %d' % (_h[0], _h[1]))
                    time.sleep(1.0)
                    _closed = True
                    break
            sh('uitest uiInput keyEvent Back')
            time.sleep(1.0)
        if not is_home():
            # ★ 2026-11-11（判据 1912）：**`NOT_HOME` 占全部失败的 2/3** ——
            #   38/58 是「回不到首页」。根因：**弹层/结算页把 Back 吃掉**，且重启 App 后 6s 不够。
            #   ⇒ 改成「强杀 + 重启 + 轮询 until home」（最多 4 轮 × 4s）
            sh('aa force-stop com.andrewoscar.onemore')
            time.sleep(1.0)
            sh('aa start -a EntryAbility -b com.andrewoscar.onemore')
            for _w in range(4):
                time.sleep(4.0)
                if is_home():
                    break
                sh('aa force-stop com.andrewoscar.onemore')
                time.sleep(1.0)
                sh('aa start -a EntryAbility -b com.andrewoscar.onemore')
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
    # ★ 2026-11-12（判据 1942）：**精确名优先** —— 全库有 15 对「名字互为前缀」的游戏
    #   （`Kakuro` ⊂ `Kakuro Mini`、`二进制` ⊂ `二进制码` …）⇒ 只做子串匹配会**打开另一个游戏**。
    #   我因此在 `Kakuro` 上白改了十次（改 `GKaкuro`，测 `GKakuroMini`）。
    card = None
    fallback = None
    exact = None
    for t, (x1, y1, x2, y2) in texts(d):
        if 560 < y1 < 1000 and x2 > x1 + 100:
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            if fallback is None:
                fallback = (cx, cy)
            tt = t.strip()
            if exact is None and ((want and tt == want) or tt == name):
                exact = (cx, cy)
            if card is None and ((want and want in t) or (name in t)):
                card = (cx, cy)
    card = exact or card
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
    # ★ 2026-11-11（判据 1925，`verifier-eng2` 查出）：**旧尺子只量「有文字的节点」** ——
    #   格子本身没字的游戏（棋盘格 / 色块 / Canvas）永远量偏小。
    #   实测 `Masyu` 首帧 732（圈还没渲染）vs 正常 1586（圈渲染后），**同一布局差 854px**。
    #   ⇒ 改成「整棵 dump 树的最大 y2」（`lowest` 仍取最深**文字**，只作人读参考）
    def _max_y2(n, acc):
        # ⚠️ 2026-11-11：**只数「叶子节点」** —— 整树最大 y2 会被根容器（height 100%）钉死在屏幕底，
        #   那也是 1600，但那是背景不是内容。叶子才是真正画出来的东西。
        if isinstance(n, dict):
            kids = n.get('children') or []
            if not kids:
                a = n.get('attributes', {}) or {}
                b = (a.get('bounds') or '').strip()
                if b:
                    nums = [int(x) for x in re.findall(r'-?\d+', b)]
                    if len(nums) == 4 and nums[3] > acc:
                        acc = nums[3]
            for c in kids:
                acc = _max_y2(c, acc)
        return acc
    mb = _max_y2(d2, 0)
    # lowest 取「文字节点里 y2 最大」的那个（人读参考）
    best = -1
    lo_bounds = ''
    for t, (x1, y1, x2, y2) in texts(d2):
        if y2 > best:
            best = y2
            lo = t[:26]
            # 2026-11-13（判据 1973）：只记文本不够 —— 同一个词可能来自不同节点。
            #   记上 bounds，判据就能从「文本相同」升级成「节点相同」。
            lo_bounds = '[%d,%d][%d,%d]' % (x1, y1, x2, y2)

    # ★ 2026-11-13（判据 1978/1980，队友 `c3b9dcff` 设计）：**抗抖动指标**
    #   `max_bottom` = max() over 叶子 ⇒ 叶子会随状态换人（键盘/浮层生灭），实测 `Wordle`
    #   20 分钟内 1600/1591/1351/1600 抖 ±250px。
    #   ⇒ 换一级：数**根内容列的直接子块**里越界（y2 > 1516 + 24）的块数与越界量。
    #   块的「身份」稳定（HUD/棋盘/按钮行还是那几块），状态抖动传不到指标上。
    GAME_BOTTOM = 1516
    # 2026-11-13 校准：SLACK 24 → 60 —— 底部手势/导航条恒定结束在 1576(=1516+60)，
    #   用 24 会把「系统条」当成越界块（`Nonogram 1365` 也报 blk=1/60px 就是它）。
    SLACK = 60

    def _kids_root(n):
        """找根内容列：优先 type 含 Column 且子树最深、bounds 最宽的节点。"""
        best = None
        best_w = -1

        def walk(x, depth):
            nonlocal best, best_w
            if not isinstance(x, dict):
                return
            a = x.get('attributes', {}) or {}
            b = (a.get('bounds') or '').strip()
            typ = str(a.get('type', ''))
            nums = [int(v) for v in re.findall(r'-?\d+', b)]
            # 2026-11-13 校准：**跳过框架层容器** —— 实测最外层是
            #   root[0,117][2560,1600] + WindowScene[0,0][2560,117]，它们不是内容块。
            #   只认真正的布局容器（Column/Row/Scroll 等），且宽度接近全屏、起点在上半屏。
            if (typ not in ('root', 'WindowScene', 'EffectComponent', 'Flex', '')
                    and 'Column' in typ and len(nums) == 4):
                w = nums[2] - nums[0]
                if w >= 2000 and nums[1] < 700 and w > best_w:
                    best_w = w
                    best = x
            for c in (x.get('children') or []):
                walk(c, depth + 1)

        walk(n, 0)
        return best

    block_over_n = 0
    block_over_px = 0
    block_over_max = 0
    root_desc = ''
    try:
        root = _kids_root(d2)
        if root is not None:
            ra = root.get('attributes', {}) or {}
            root_desc = '%s@%s' % (str(ra.get('type', '?')), str(ra.get('bounds', '?')))
            for ch in (root.get('children') or []):
                ca = ch.get('attributes', {}) or {}
                cb = (ca.get('bounds') or '').strip()
                nums = [int(v) for v in re.findall(r'-?\d+', cb)]
                if len(nums) != 4:
                    continue
                over = nums[3] - (GAME_BOTTOM + SLACK)
                if over > 0:
                    block_over_n += 1
                    block_over_px += over
                    if over > block_over_max:
                        block_over_max = over
    except Exception:
        pass

    safe = re.sub(r'[^A-Za-z0-9_]', '_', name)
    ts = time.strftime('%H%M%S')
    out = os.path.join(ROOT, '_巡检记录', '截图-%s-%s.jpeg' % (safe, ts))
    remote = '/data/local/tmp/shot_%s_%s.jpeg' % (safe, ts)
    sh('snapshot_display -f ' + remote)

    recv_ok = False
    try:
        rc, _o, _e = run([HC, '-t', _target(), 'file', 'recv', remote, out], 60)
        recv_ok = (rc == 0 and os.path.exists(out))
    except Timeout:
        recv_ok = False

    # ★ 2026-11-10（判据 1889）：结果行带测量时间戳，否则「按文件 mtime 取最新」会被拷贝污染
    import datetime as _dt
    _ts = _dt.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
    if recv_ok:
        finish(name, 'OK', t0, mb,
               'lowest=%r %s blk=%d/%dpx max=%d -> %s @%s' % (lo, lo_bounds, block_over_n, block_over_px, block_over_max, out, _ts))
    else:
        finish(name, 'OK_NOSHOT', t0, mb,
               'lowest=%r %s recv failed @%s' % (lo, lo_bounds, _ts))


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
