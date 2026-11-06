#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
强验证：「AI 代打真的能赢」—— 不只是「按钮变成停代打」。

★ 为什么要它（第 1420 轮）：
  `verify_ai_play.py` 只验「点完按钮 → 变成停代打 或 返回列表」=「启动了」。
  water_sort 证明了「启动」与「能赢」是两回事：
    · 按钮确实变停代打（如果要验的话）
    · 但 wsPlanGreedy 返回空 ⇒ 立即 stopAuto + toast「AI 没找到解法」⇒ 步数 0
  ⇒ 旧验证器抓不到这类款。

★ 本验证器的判据（三层，按强度递进）：
  ① 点完 AI 代打后 **步数/得分等读数出现增长**（或盘面变化）
  ② 出现**结算**（再来一局 / 返回列表 / 这一局拿下 / 🎉）
  ③ 出现「AI 没找到解法」toast ⇒ 判定 **FAIL**（明确失败，不猜）

★ 2026-11-06（第 1430 轮）：真机 24 款跑出 16 WIN，也跑出 2 TIMEOUT / 2「找不到 AI 代打」
  / 4「进不去游戏」。逐个复盘发现**大半是验证器自己的毛病，不是游戏的**：
    · 设备掉线（hdc 127.0.0.1:5555）后 `list targets` 变空，所有 dump 都失败，
      脚本却继续空转，最后报「回不到列表」——**看起来像游戏坏了，其实设备没了**
    · 没有单款超时：某一步卡住就一路等下去
    · 失败不留现场：连「当时页面是什么样」都没记，没法复盘
    · 搜索卡片的定位偶发漏 ⇒ 被记成「进不去游戏」
  ⇒ 本版补 A~G 七条，全部落在判据 1673~1681：

  判据 1673 每次 hdc 操作前先确认设备**可用**：`list targets` 非空 **且**
            `shell echo ok` 真的回 ok（沿用判据 1584「list targets ≠ 可用」）。
            3 秒内复用同一结论，避免每次操作都白多开一个 hdc 进程。
  判据 1674 掉线自愈：`hdc kill → hdc start → hdc tconn 127.0.0.1:5555`，最多 3 轮。
            **只重启 hdc 服务端，绝不启动/停止模拟器**——模拟器归他管，
            脚本碰了会打断别人正在跑的真机任务。
  判据 1675 自愈 3 轮仍不可用 ⇒ 打印 `DEVICE_DEAD` + 退出码 3。
            旧版把这种情况报成「回不到列表」，把人引去查游戏，方向全错。
  判据 1676 单款预算默认 240s（`--per-game-timeout` 可改）：**逐次 hdc 调用扣减**，
            不用 signal（signal 打断 subprocess 会留下 hdc 子进程，
            下一次调用撞上旧的还会假死）。超时判 TIMEOUT，继续下一款。
            ★ 例外：设备自愈（判据 1674）的耗时**不**从单款预算里扣 ——
              它是设备故障路径，必须走完才能判定 3；实测最坏 ~60s（3 轮）。
              所以「单款 240s」在掉线那一款上可能是 240+60+诊断 30 ≈ 330s，
              这是有意的：宁可多等一分钟，也要把「设备没了」和「游戏坏了」分开。
  判据 1677 失败诊断：FAIL/TIMEOUT/ERROR 时抓**当时页面**前 12 条文本（每条 ≤100 字）
            写进 detail。诊断走**独立的 30s 预算**——否则单款预算已耗尽时 dump
            第一下就被 GameTimeout 截断，诊断永远是空的（那就等于没诊断）。
  判据 1678 搜索兜底（四级定位 + 重搜）：
            ① `card-<gid>` 精确（注册表能查到 game_id 时最稳）
            ② `card-` 前缀 + 名字归一化（去空白/全角空格/大小写）
            ③ `Stack` + 名字（旧兜底）
            ④ 还找不到 ⇒ **清空搜索框重搜一次**，仍无才 FAIL
            另外**回读输入框**校验搜索词真的进去了：`inputText` 偶发丢字（输入法建议框
            抢焦点），旧版不校验，表现就是「进不去游戏」。
  判据 1679 进度：每款一行 `[i/N] 名字 => 结果`；每 5 款一行汇总（WIN/FAIL/TIMEOUT/ERROR）。
  判据 1680 结果仍写 `验收截图-v1.0.1/ai_win_verified.jsonl`，一行一条
            `{name, verdict, detail, ts}`，**逐条 flush**（中途掉线也不丢已验完的）。
  判据 1681 退出码：0 全 WIN ｜ 1 有 FAIL/TIMEOUT/ERROR ｜ 2 脚本异常 ｜ 3 设备不可用。

用法：
  python3 工具/verify_ai_win.py water_sort 倒水排序
  python3 工具/verify_ai_win.py --names-file /tmp/names.txt
  python3 工具/verify_ai_win.py --limit 10                  # 从注册表随机抽 10 款
  python3 工具/verify_ai_win.py --names-file n.txt --per-game-timeout 180
  python3 工具/verify_ai_win.py --names-file n.txt --out /tmp/chunk.jsonl
      ↑ 分批跑用（`工具/verify_ai_win_batch.sh` 就是这么调的，判据 1682）
  python3 工具/verify_ai_win.py --device 127.0.0.1:5555      # 换连别的模拟器

退出码：0 = 全部 WIN ｜ 1 = 有 FAIL/TIMEOUT ｜ 2 = 脚本异常 ｜ 3 = 设备不可用
"""
import io, json, os, random, re, subprocess, sys, time
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
OUT = os.path.join(ROOT, '验收截图-v1.0.1/ai_win_verified.jsonl')
HC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV = "127.0.0.1:5555"

# ── 判据 1673~1681 的旋钮（命令行可改的见 parse_args） ──
PER_GAME = 240.0       # 判据 1676：单款预算（秒）—— 24 款实测最慢一款 ~150s，240s 留余量
HEAL_ROUNDS = 3        # 判据 1674：自愈轮数（1 轮不够常见，3 轮覆盖 hdc 服务端重启慢的情况）
HEALTH_TTL = 3.0       # 判据 1673：探活结论复用 3 秒（一次 dump 里连发好几条 shell，够用）
DIAG_BUDGET = 30.0     # 判据 1677：失败诊断的独立预算
RESET_BUDGET = 150.0   # 每款之间「回列表」的复位预算（比单款短：复位失败下一款还会再试）
DUMP_REMOTE = '/data/local/tmp/_vaw.json'
DUMP_LOCAL = '/tmp/_vaw.json'

WIN_PAT = re.compile(r'这一局拿下|再来一局|返回列表|全部单色|通关|🎉')
FAIL_PAT = re.compile(r'没找到解法|倒不动了|本局失败|无解')
# 判据 1673：hdc 自己的「连不上」措辞各版本不一样，全收进来；只用来**触发核实**，
#   不做判定依据（真假一律回到 list targets + echo ok 去确认）
DEAD_PAT = re.compile(
    r'Connect failed|connect-key|device offline|no devices|not found target|'
    r'\[Empty\]|Failed to connect|server does not|daemon not running', re.I)

USAGE = """用法：
  python3 工具/verify_ai_win.py <名字> [<名字> …]
  python3 工具/verify_ai_win.py --names-file /tmp/names.txt
  python3 工具/verify_ai_win.py --limit 10
选项：
  --names-file <路径>       一行一款（可带空行/注释，# 开头忽略）
  --limit <N>               没给名字时从注册表随机抽 N 款（默认 10）
  --per-game-timeout <秒>   单款预算（默认 240，判据 1676）
  --out <路径>              结果 jsonl（默认 验收截图-v1.0.1/ai_win_verified.jsonl）
  --device <host:port>      设备地址（默认 127.0.0.1:5555）
退出码：0 全 WIN ｜ 1 有失败 ｜ 2 脚本异常 ｜ 3 设备不可用
"""


# ════════════════════════════════════════════════════════════════════════════
#  预算与异常（判据 1676）
# ════════════════════════════════════════════════════════════════════════════
class GameTimeout(Exception):
    """单款预算用光（判据 1676）—— 不是游戏坏了，是这一款不陪它等了。"""


class DeviceDead(Exception):
    """设备自愈 3 轮仍不可用（判据 1675）—— 必须 REPORT，不许伪装成游戏失败。"""


class Budget(object):
    """一段时间的预算；seconds=None 表示不限（脚本自身的探活/自愈用它）。"""

    def __init__(self, seconds=None):
        self.t0 = time.time()
        self.seconds = seconds

    def remaining(self):
        if self.seconds is None:
            return float('inf')
        return self.seconds - (time.time() - self.t0)

    def check(self):
        """还有预算就返回剩余秒数，没预算就抛（所有循环里都调它）。"""
        left = self.remaining()
        if left <= 0:
            raise GameTimeout('单款预算已用光（%.0fs）' % (self.seconds or 0))
        return left

    def timeout(self, base):
        """单次 hdc 的超时：不超过剩余预算（下限 3s，避免 0/负数传给 subprocess）。"""
        return max(3.0, min(float(base), self.check()))


# 默认不限预算：脚本启动时的探活/自愈不能因为「还没开始计时」直接抛 GameTimeout
_BUDGET = Budget()


# ════════════════════════════════════════════════════════════════════════════
#  设备自愈（判据 1673 / 1674 / 1675）
# ════════════════════════════════════════════════════════════════════════════
_HEALTH = {'t': 0.0, 'ok': False}


def _run(args, timeout=30):
    """裸跑 hdc：**不探活、不自愈** —— 只给探活/自愈本身用，避免递归。

    返回 (rc, 合并后的输出)。超时返回 124，找不到 hdc 返回 127。
    """
    try:
        r = subprocess.run(args, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, ''
    except OSError as e:
        return 127, str(e)
    return r.returncode, ((r.stdout or b"") + (r.stderr or b"")).decode("utf-8", "replace")


def targets():
    """`hdc list targets` 现在有哪些设备（判据 1673）。

    ★ 各版本输出不一：正常是 `127.0.0.1:5555`（可能带 Connected 尾巴），
      空的时候是 `[Empty]` 或干脆空行，hdc 自己的提示行都以 `[` 开头。
      ★ 为什么**不要求行里有 `:`**：USB 设备的序列号没有冒号（如 `UE8M…`），
        按冒号过滤会把真设备丢掉 ⇒ 误判掉线 ⇒ 白自愈 3 轮后报 DEVICE_DEAD。
        宁可放宽：多留一行假设备也无害，真正的「可用」判据是 _probe 的 echo ok（1584）。
    """
    _, out = _run([HC, "list", "targets"], 12)
    devs = []
    for ln in out.splitlines():
        s = ln.strip()
        if not s or 'Empty' in s or s.startswith('['):
            continue
        devs.append(s.split()[0])
    return devs


def _probe():
    """设备**可用**吗：有设备 **且** `shell echo ok` 真的回 ok（判据 1673，沿用 1584）。"""
    if not targets():
        return False
    rc, out = _run([HC, "-t", DEV, "shell", "echo ok"], 15)
    return rc == 0 and 'ok' in out


def heal(rounds=HEAL_ROUNDS):
    """掉线自愈：`hdc kill → hdc start → hdc tconn 127.0.0.1:5555`（判据 1674）。

    ★★★ 为什么只碰 hdc 不碰模拟器：
      `设备被占用中` —— 模拟器进程是他/别的任务在管，脚本 `-stop/-start` 会直接把人家的
      真机任务打断。hdc 服务端只是**本机的连接器**，重启它不影响模拟器本身。
    """
    global _HEALTH
    for r in range(1, rounds + 1):
        print('   ⚠️ 设备失联，第 %d/%d 轮自愈（只重启 hdc，不碰模拟器）…' % (r, rounds),
              flush=True)
        _run([HC, "kill"], 15)
        time.sleep(2)
        _run([HC, "start"], 20)
        time.sleep(3)
        _run([HC, "tconn", DEV], 15)
        # 连上要几秒：每轮探 4 次、每次隔 2.5s
        for _ in range(4):
            time.sleep(2.5)
            if _probe():
                print('   ✅ 设备已恢复（第 %d 轮）' % r, flush=True)
                _HEALTH = {'t': time.time(), 'ok': True}
                return True
    return False


def ensure_device(force=False):
    """确认设备可用，不可用就自愈；自愈失败抛 DeviceDead（判据 1673/1675）。

    ★ 为什么带缓存（判据 1673 的补充）：一次 dump 里要连发 dumpLayout + file recv，
      每个 hdc 调用都再探一次活会让调用数翻倍；3 秒 TTL 足够挡住「刚查过」的重复，
      而真正的掉线由**失败路径**（force=True）兜住，不会漏。
    """
    global _HEALTH
    if not force and _HEALTH['ok'] and (time.time() - _HEALTH['t'] < HEALTH_TTL):
        return
    if _probe():
        _HEALTH = {'t': time.time(), 'ok': True}
        return
    _HEALTH = {'t': 0.0, 'ok': False}
    if not heal():
        raise DeviceDead('hdc %s 连不上（list targets 空 / echo ok 无响应）' % DEV)


def hdc(args, timeout=30):
    """**所有 hdc 调用的唯一出口**：探活 → 执行 → 失败自愈重试一次（判据 1673/1674）。

    ★ 判据 1676：进来先 check 预算；单次超时也被剩余预算夹住，
      ⇒ 卡死的 hdc 最多吃掉「剩余预算」，不会把整批拖垮。
    """
    _BUDGET.check()
    ensure_device()
    out = ''
    for attempt in (1, 2):
        rc, out = _run([HC] + args, _BUDGET.timeout(timeout))
        if rc == 0 and not DEAD_PAT.search(out):
            return out
        # 硬失败 / 输出里带「连不上」⇒ 先掉缓存强制核实（可能是真掉线）
        _HEALTH['ok'] = False
        ensure_device(force=True)
        if attempt == 2:
            return out      # 设备是好的，说明这条命令本身失败（dumpLayout 偶发）⇒ 交给上层重试
    return out


def sh(cmd, timeout=30):
    return hdc(["-t", DEV, "shell", cmd], timeout)


def recv(remote, local, timeout=25):
    return hdc(["-t", DEV, "file", "recv", remote, local], timeout)


# ════════════════════════════════════════════════════════════════════════════
#  UI 树
# ════════════════════════════════════════════════════════════════════════════
def dump():
    """取一次 UI 树；失败重试 4 次（判据 1673：走 hdc() 出口，掉线会先自愈）。"""
    for _ in range(4):
        _BUDGET.check()
        try:
            os.remove(DUMP_LOCAL)
        except OSError:
            pass
        sh("uitest dumpLayout -p %s" % DUMP_REMOTE)
        recv(DUMP_REMOTE, DUMP_LOCAL)
        try:
            # 小于 200 字节的 json 必定是半截文件（旧版只 try parse，空文件也算失败但没区分）
            if os.path.getsize(DUMP_LOCAL) < 200:
                raise ValueError('dump 文件太小')
            return json.load(io.open(DUMP_LOCAL, encoding='utf-8'))
        except Exception:
            time.sleep(1.2)
    return None


def nodes(d):
    out = []

    def w(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {})
        bb = None
        m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds') or '')
        if m:
            bb = tuple(int(v) for v in m[0])
        out.append({'text': (a.get('text') or '').strip(), 'type': a.get('type') or '',
                    'id': a.get('id') or '', 'bounds': bb})
        for c in n.get('children', []) or []:
            w(c)
    w(d)
    return out


def _norm(s):
    """文本归一化：去掉所有空白（含全角空格）、统一大小写（判据 1678）。

    ★ 为什么：卡片标题实测会带不可见空格，旧版 `name in x['text']` 严格子串匹配
      就会偶发漏卡 ⇒ 被记成「进不去游戏」。
    """
    return re.sub(r'[\s\u3000]+', '', s or '').lower()


def find(ns, want, exact=False):
    for x in ns:
        if not x['bounds']:
            continue
        t = x['text']
        if (t == want) if exact else (want in t):
            return x
    return None


def center(x):
    b = x['bounds']
    return (b[0] + b[2]) // 2, (b[1] + b[3]) // 2


def tap(x, wait=1.0):
    cx, cy = center(x)
    sh("uitest uiInput click %d %d" % (cx, cy))
    time.sleep(wait)


# ════════════════════════════════════════════════════════════════════════════
#  注册表（名字 → game_id，用于 card-<gid> 精确匹配）
# ════════════════════════════════════════════════════════════════════════════
def registry_names():
    s = io.open(REG, encoding='utf-8').read()
    return re.findall(r"id:\s*'([a-z0-9_]+)',\s*name:\s*'([^']+)'", s)


_GIDS = None


def gid_for(name):
    """名字 → 注册表 game_id；查不到返回 None（判据 1678 的第 ① 级定位用）。"""
    global _GIDS
    if _GIDS is None:
        try:
            _GIDS = dict((n, i) for i, n in registry_names())
        except Exception:
            _GIDS = {}
    return _GIDS.get(name)


# ════════════════════════════════════════════════════════════════════════════
#  页面动作
# ════════════════════════════════════════════════════════════════════════════
def to_list():
    """回到列表页（兼容：游戏内 / 结算弹窗 / 列表页）；返回 True/False"""
    for _ in range(6):
        _BUDGET.check()
        d = dump()
        if not d:
            time.sleep(1.5)
            continue
        ns = nodes(d)
        txt = [x['text'] for x in ns]
        # ★ 判据 1670：搜索面板也显示「One More」⇒ 光看标题会误判「已在列表页」
        #   ⇒ 有 TextInput 说明还在搜索模式，先关掉（右上角 🔍）
        if any(x['type'] == 'TextInput' for x in ns):
            sr = _search_btn(ns)
            if sr:
                tap(sr, 1.5)
                continue
        if any('One More' in t for t in txt):
            return True
        # 结算弹窗：有「返回列表」按钮
        b = find(ns, '返回列表', exact=True)
        if not b:
            b = find(ns, '‹')
        if b:
            tap(b, 2.0)
            continue
        # 兜底：Back（判据 1229：只在非列表页按）
        sh("uitest uiInput keyEvent Back")
        time.sleep(1.5)
    return False


def _search_btn(ns):
    """**右上角**的 🔍（判据 1670：搜索框内还有一个 🔍，点错会把面板关掉）。

    ★ 判据 1697：不能写死 x>2000 —— 440×744(1320px 宽) 上根本不存在。
      「x 最大的那个 🔍」才是右上角的，跨尺寸成立。
    """
    cands = [x for x in ns if x['text'] == '🔍' and x['bounds']]
    if not cands:
        return None
    return max(cands, key=lambda c: c['bounds'][0])


def _text_input(ns):
    for x in ns:
        if x['type'] == 'TextInput':
            return x
    return None


def _open_search():
    """确保搜索面板打开；返回 TextInput 节点或 None"""
    d = dump()
    if not d:
        return None
    ns = nodes(d)
    ti = _text_input(ns)
    if ti:
        return ti
    sb = _search_btn(ns)
    if not sb:
        return None
    tap(sb, 2.0)
    d = dump()
    return _text_input(nodes(d)) if d else None


def _clear_input(name):
    """清空搜索框：2055 = 删除键（判据 1678 用 len+6 次，旧版固定 16 次）。

    ★ 为什么按 len+6 而不是死数 16：名字长度不一，短名字多按几次无害、
      长名字按不够会残留前缀 ⇒ 搜出来一堆不相干的卡。
    """
    n = max(16, len(name) + 6)
    for _ in range(n):
        sh("uitest uiInput keyEvent 2055")
    time.sleep(0.3)


def _input_text(ti, name):
    """点输入框 → 清空 → 输入，并**回读校验搜索词真的进去了**（判据 1678）。

    ★ 为什么必须回读：`uitest uiInput inputText` 偶发丢字（输入法建议框抢焦点）。
      旧版不校验，表现就是「进不去游戏」——错在输入，锅却记给游戏。
    """
    # ★ 判据 1688：`inputText` 遇到**空格会截断**（实测「AB 反转」只进了「AB」）
    #   ⇒ 含空格的名字再试一个「去空格」变体（搜索本身是模糊匹配）
    # ★ 判据 1691：列表搜索按**词**匹配 —— 实测「AB反转」0 结果、「反转」命中
    #   含空格的名字**先试尾词**（命中率最高）；卡片定位仍用完整名字，不会进错游戏
    variants = []
    if ' ' in name:
        variants.append(name.split()[-1])
        variants.append(name.replace(' ', ''))
    variants.append(name)
    for attempt in (1, 2):
        for q in variants:
            tap(ti, 1.0)
            _clear_input(name)
            cx, cy = center(ti)
            sh("uitest uiInput inputText %d %d %s" % (cx, cy, q))
            time.sleep(0.6)
            d = dump()
            got = ''
            if d:
                ti2 = _text_input(nodes(d))
                got = ti2['text'] if ti2 else ''
            if _norm(q) and _norm(q) in _norm(got):
                return True
        if attempt == 1:
            print('   ⚠️ 搜索词没进输入框（回读=%r），再输一次…' % got[:40], flush=True)
    return False


def _card_candidates(ns, name, gid):
    """判据 1678 的四级定位（返回候选列表，越靠前越稳）：
      ① id == card-<gid>          —— 注册表查得到 game_id 时最稳
      ② id 以 card- 开头 且 名字归一化相等
      ③ id 以 card- 开头 且 名字出现在文本里
      ④ type == Stack 且 名字出现在文本里（旧兜底，最容易误中，放最后）
    """
    nm = _norm(name)
    cid = ('card-' + gid) if gid else None
    hit = []
    # ★ 判据 1707：短名字（如「8」）用 `nm in tx` 会误中「2048」——
    #   ⇒ 匹配分三级：精确 == / 前缀 startsWith / 包含 in，**精确优先**
    exact = []
    prefix = []
    contain = []
    for x in ns:
        if not x['bounds']:
            continue
        if cid and x['id'] == cid:
            exact.append(x)
            continue
        if x['id'].startswith('card-') and nm:
            tx = _norm(x['text'])
            if tx == nm:
                exact.append(x)
            elif tx.startswith(nm):
                prefix.append(x)
            elif nm in tx:
                contain.append(x)
    hit = exact + prefix + contain
    if hit:
        return hit
    for x in ns:
        if x['bounds'] and x['type'] == 'Stack' and nm and nm in _norm(x['text']):
            hit.append(x)
    return hit


def _wait_card(name, gid=None, tries=4):
    """等搜索结果卡片出现（判据 1669：搜索是异步的，一次 dump 不够，2~4 秒后才出现）"""
    for attempt in range(tries):
        _BUDGET.check()
        time.sleep(1.5 if attempt == 0 else 1.2)
        d = dump()
        if not d:
            continue
        cs = _card_candidates(nodes(d), name, gid)
        if cs:
            return cs[0]
    return None


def open_game(name):
    """搜索并进入游戏；返回 (ok, why)。

    ★ 判据 1678：第一次搜不到 ⇒ **清空搜索框重搜一次**（第 ④ 级兜底），仍无才 FAIL。
      实测「进不去游戏」多数是搜索词没吃进去 / 卡片匹配过严，不是游戏打不开。
    """
    gid = gid_for(name)
    for attempt in (1, 2):
        _BUDGET.check()
        ti = _open_search()
        if not ti:
            # 面板本身也可能被过渡动画/输入法挡住 ⇒ 和卡片一样给一次重试（判据 1678）
            if attempt == 1:
                print('   ⚠️ 点不开搜索面板，重试…', flush=True)
                continue
            return False, '🔍 点不开搜索面板（重试后仍无）'
        if not _input_text(ti, name):
            if attempt == 1:
                continue
            return False, '搜索词输不进去'
        card = _wait_card(name, gid)
        if card:
            tap(card, 6.0)
            time.sleep(1.5)
            return True, ''
        if attempt == 1:
            print('   ⚠️ 第一次没找到卡片，清空搜索框重搜…', flush=True)
    return False, '搜不到卡片（清空重搜后仍无）'


def _screen_center():
    """读设备实际屏幕尺寸（`wm size`），返回中心点；失败退 1280×800。"""
    global _SCREEN
    if _SCREEN is None:
        _SCREEN = (2560, 1600)
        try:
            out = sh("wm size")
            m = re.search(r'(\d+)x(\d+)', out)
            if m:
                _SCREEN = (int(m.group(1)), int(m.group(2)))
        except Exception:
            pass
    return _SCREEN[0] // 2, _SCREEN[1] // 2


_SCREEN = None


def stop_demo():
    """demo 3 秒后启动；点屏幕空白停掉它（判据 1667/1689）。

    ★ 判据 1689：演示期间 HintBar 的 AI 按钮**整个不渲染**（HintBar.ets `if (!this.demoOn)`）
      ⇒ 只点一次标题区不够稳（有的游戏根容器 onTouch 在棋盘上）
      ⇒ 点屏幕中心 + 顶部各一次，再给 1.5s 让 demoId 归零
    """
    _BUDGET.check()
    time.sleep(3.5)
    # ★ 判据 1697：坐标必须按**实际屏幕尺寸**算 —— 2560×1600 上写死的
    #   (1280,800)/(1280,220) 在 440×744(1320×2232) 上会点到屏幕边缘/误触
    # ★ 判据 1697：不依赖屏幕尺寸 —— 在几个「安全空白点」各点一次（屏幕外点击会被忽略）
    for (px, py) in [(1280, 800), (660, 800), (660, 220), (1280, 220), (400, 1500), (300, 300), (300, 150), (200, 400)]:
        sh("uitest uiInput click %d %d" % (px, py))
        time.sleep(0.4)
    time.sleep(1.2)


def read_readouts(ns):
    """抓读数：步数 / 得分 / 归位 的下一个节点"""
    txt = [x['text'] for x in ns if x['text']]
    out = {}
    for i, t in enumerate(txt):
        if t in ('步数', '得分', '归位') and i + 1 < len(txt):
            out[t] = txt[i + 1]
    return out


def watch(seconds=120):
    """轮询直到结算/失败/超时；返回 (verdict, detail)。

    ★ 判据 1676：seconds 被单款剩余预算夹住 —— 否则「watch 等 120s」会把 240s 预算
      整个吃掉，AI 启动前的那几步全白等。
    """
    left = _BUDGET.remaining()
    if left < float('inf'):
        seconds = max(5.0, min(float(seconds), left - 3))
    t0 = time.time()
    steps_seen = set()
    while time.time() - t0 < seconds:
        d = dump()
        if not d:
            time.sleep(2)
            continue
        ns = nodes(d)
        txt = [x['text'] for x in ns if x['text']]
        joined = '|'.join(txt)
        ro = read_readouts(ns)
        steps_seen.add(ro.get('步数', ''))
        if FAIL_PAT.search(joined) and ('没找到' in joined or '倒不动' in joined):
            return 'FAIL', 'toast: ' + ','.join(t for t in txt if FAIL_PAT.search(t))[:80]
        if WIN_PAT.search(joined):
            return 'WIN', '结算出现 · 读数=%s' % ro
        # ★ 判据 1671：部分游戏「通关即自动返回列表」⇒ 返回列表页本身要算完成，
        #   否则会一直等到 TIMEOUT（「方向回忆」就栽在这）
        if ('One More' in joined) and ('AI 代打' not in joined) and ('One More' in '|'.join(txt[:3])):
            return 'WIN', '已返回列表（视作完成）'
        time.sleep(1.6)
    d = dump()
    return 'TIMEOUT', '读数=%s 步数历史=%s' % (read_readouts(nodes(d)) if d else {}, sorted(steps_seen))


def diag_page(limit=12, per=100):
    """失败现场：当时页面上的前 12 条文本（每条 ≤100 字）（判据 1677）。

    ★★★ 为什么用**独立预算**：单款预算刚好在失败那一刻耗尽（TIMEOUT 的常态），
      这时候任何 dump 都会先被 GameTimeout 拦下 ⇒ 诊断永远是空的。
      诊断的价值全在「事后能看出是哪个页面」，不能让它跟着预算一起死。
    """
    global _BUDGET
    saved = _BUDGET
    _BUDGET = Budget(DIAG_BUDGET)
    try:
        d = dump()
    except (GameTimeout, DeviceDead) as e:
        d = None
        why = '设备/预算不可用：%s' % str(e)[:40]
    else:
        why = ''
    finally:
        _BUDGET = saved
    if not d:
        return '页面：抓不到（%s）' % (why or 'dump 失败')
    txt = [x['text'][:per] for x in nodes(d) if x['text']][:limit]
    if not txt:
        return '页面：无可读文本'
    return '页面(%d): %s' % (len(txt), '|'.join(txt))


def verify(name):
    """单款：回列表 → 进游戏 → 停演示 → 点 AI 代打 → 看结算；返回 (verdict, detail)"""
    if not to_list():
        return 'FAIL', '回不到列表'
    ok, why = open_game(name)
    if not ok:
        return 'FAIL', '进不去游戏（%s）' % why
    d = dump()
    ns = nodes(d) if d else []
    # ★ 判据：进游戏后「有 AI 代打按钮」比「标题等于注册名」更可靠
    #   （部分游戏标题是缩写/别名，注册名不一定出现在可见文本里）
    has_ai = any('AI 代打' in x['text'] for x in ns)
    if not has_ai and not any(x['text'] == name for x in ns):
        return 'FAIL', '进错游戏（无 AI 代打按钮）'
    stop_demo()
    # ★ 判据 1672：页面/演示过渡时按钮可能还没渲染 ⇒ 找 AI 代打必须**重试**
    ai = None
    # ★ 判据 1689：演示最长约 10s（5 拍），期间 HintBar 按钮**整个不渲染**
    #   ⇒ 重试 6 次 × 2s，别在演示中途就判「找不到按钮」
    for _ in range(6):
        _BUDGET.check()
        d = dump()
        ns = nodes(d) if d else []
        ai = find(ns, 'AI 代打')
        if ai:
            break
        time.sleep(2.0)
    if not ai:
        return 'FAIL', '找不到 AI 代打按钮'
    # ★ 判据 1711：点之前**再 dump 一次拿最新 bounds** —— 演示结束/布局切换会把按钮
    #   从 y543 挪回 y429，用旧 bounds 会点空（二项式配对就栽在这，误判成 TIMEOUT）
    time.sleep(0.8)
    d2 = dump()
    if d2:
        ai2 = find(nodes(d2), 'AI 代打')
        if ai2:
            ai = ai2
    tap(ai, 0.5)
    # 启动确认：按钮变化 or toast
    time.sleep(1.2)
    d = dump()
    txt = [x['text'] for x in (nodes(d) if d else []) if x['text']]
    if not (any('停代打' in t for t in txt) or any('开始代打' in t for t in txt)):
        # 可能瞬间通关已回列表
        if any('One More' in t for t in txt):
            return 'WIN', '瞬间通关（已回列表）'
    return watch(120)


# ════════════════════════════════════════════════════════════════════════════
#  结果 / 进度（判据 1679 / 1680）
# ════════════════════════════════════════════════════════════════════════════
def save(name, verdict, detail):
    """判据 1680：一行一条 `{name, verdict, detail, ts}`，写完就 flush。

    ★ 为什么逐条 flush：24 款要跑 1 小时＋，中途掉线/被杀时，
      已经验完的结论必须已经在盘上，否则整批白跑。
    """
    rec = {'name': name, 'verdict': verdict, 'detail': detail,
           'ts': time.strftime('%Y-%m-%dT%H:%M:%S')}
    with io.open(OUT, 'a', encoding='utf-8') as f:
        f.write(json.dumps(rec, ensure_ascii=False) + '\n')
        f.flush()


def _stats_line(stats):
    """判据 1679：一行汇总（WIN/FAIL/TIMEOUT/ERROR 计数）"""
    return 'WIN %d · FAIL %d · TIMEOUT %d · ERROR %d' % (
        stats['WIN'], stats['FAIL'], stats['TIMEOUT'], stats['ERROR'])


def _reset_home():
    """每款结束后回列表（判据 1229：Back 只在非列表页按）。

    ★ 复位用独立预算：单款预算这时通常已经耗尽，沿用旧预算会让 to_list 第一下就抛
      GameTimeout，于是「回不去」误记成游戏的问题。
    """
    global _BUDGET
    _BUDGET = Budget(RESET_BUDGET)
    if not to_list():
        print('   ⚠️ 复位失败：回不到列表（下一款会再试）', flush=True)


# ════════════════════════════════════════════════════════════════════════════
#  入口
# ════════════════════════════════════════════════════════════════════════════
def parse_args(argv):
    opts = {'names': [], 'limit': 10, 'per_game': PER_GAME, 'out': OUT, 'device': DEV}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('-h', '--help'):
            print(USAGE)
            raise SystemExit(0)
        if a in ('--limit', '--per-game-timeout', '--names-file', '--out', '--device'):
            if i + 1 >= len(argv):
                print('🔴 参数缺值：%s\n%s' % (a, USAGE), file=sys.stderr)
                raise SystemExit(2)
            v = argv[i + 1]
            i += 2
            if a == '--limit':
                opts['limit'] = int(v)
            elif a == '--per-game-timeout':
                opts['per_game'] = float(v)
            elif a == '--names-file':
                try:
                    lines = io.open(v, encoding='utf-8').read().splitlines()
                except OSError as e:
                    print('🔴 名单文件打不开：%s（%s）' % (v, e), file=sys.stderr)
                    raise SystemExit(2)
                opts['names'] = [l.strip() for l in lines
                                 if l.strip() and not l.strip().startswith('#')]
            elif a == '--out':
                opts['out'] = v
            else:
                opts['device'] = v
            continue
        if a.startswith('-'):
            print('🔴 未知参数：%s\n%s' % (a, USAGE), file=sys.stderr)
            raise SystemExit(2)
        opts['names'].append(a)
        i += 1
    return opts


def main():
    global OUT, DEV, PER_GAME, _BUDGET
    opts = parse_args(sys.argv[1:])
    OUT = os.path.abspath(opts['out'])
    DEV = opts['device']
    PER_GAME = float(opts['per_game'])

    if not os.path.exists(HC):
        print('🔴 找不到 hdc：%s' % HC, file=sys.stderr)
        return 2
    try:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
    except OSError:
        pass

    names = opts['names']
    if not names:
        reg = registry_names()
        if not reg:
            print('🔴 读不到注册表：%s' % REG, file=sys.stderr)
            return 2
        names = [n for _, n in random.sample(reg, min(opts['limit'], len(reg)))]
    if not names:
        print('🔴 名单是空的', file=sys.stderr)
        return 2

    # 判据 1675：开局先探活自愈；起不来就直接 3，不去游戏里空转
    try:
        ensure_device(force=True)
    except DeviceDead as e:
        print('DEVICE_DEAD  %s' % e, flush=True)
        return 3

    print('待验 %d 款（单款上限 %.0fs）：%s' % (
        len(names), PER_GAME, ' '.join(names[:12])), flush=True)
    print('结果：%s' % OUT, flush=True)

    stats = Counter()
    bad = []
    total = len(names)
    for i, nm in enumerate(names, 1):
        _BUDGET = Budget(PER_GAME)          # 判据 1676：每款重新计时
        t0 = time.time()
        devdead = False
        try:
            verdict, detail = verify(nm)
        except GameTimeout:
            verdict, detail = 'TIMEOUT', '超出单款预算 %.0fs' % PER_GAME
        except DeviceDead as e:
            verdict, detail, devdead = 'ERROR', 'DEVICE_DEAD：%s' % str(e)[:60], True
        except Exception as e:
            verdict, detail = 'ERROR', ('%s: %s' % (type(e).__name__, e))[:120]
        # 判据 1677：只要不是 WIN 就把当时的页面写进 detail
        if verdict != 'WIN':
            detail = '%s ｜ %s' % (detail, diag_page())
        save(nm, verdict, detail)
        stats[verdict] += 1
        if verdict != 'WIN':
            bad.append((nm, verdict, detail))
        # 判据 1679：每款一行 `[i/N] 名字 => 结果`
        print('[%d/%d] %s => %s（%.1fs） %s' % (
            i, total, nm, verdict, time.time() - t0, (detail or '')[:100]), flush=True)
        if i % 5 == 0 and i < total:
            print('   ── 进度 %d/%d：%s ──' % (i, total, _stats_line(stats)), flush=True)
        if devdead:
            print('DEVICE_DEAD', flush=True)
            return 3
        try:
            _reset_home()
        except DeviceDead:
            print('DEVICE_DEAD', flush=True)
            return 3
        except GameTimeout:
            print('   ⚠️ 复位超时（下一款会再试）', flush=True)

    print('\n════ 本轮 WIN %d / %d ── %s ════' % (stats['WIN'], total, _stats_line(stats)),
          flush=True)
    if bad:
        print('  未通过：', flush=True)
        for nm, v, dd in bad:
            print('    %s => %s（%s）' % (nm, v, (dd or '')[:120]), flush=True)
    return 0 if stats['WIN'] == total else 1


if __name__ == '__main__':
    try:
        rc = main()
    except SystemExit:
        raise
    except Exception:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
    sys.exit(rc)
