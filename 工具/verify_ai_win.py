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

★ 2026-11-06（第 1431 轮）：355 款跑出 344 WIN，剩下 11 款 TIMEOUT 里有一类**不是游戏坏了**：
  实时对打（乒乓：页面上只有「你 0 / 电脑 3」的比分）、长局（蜘蛛纸牌步数 10→290、
  2048 得分 5976→6012）、多回合制（路径交叉「已接通 0/4」、描路径「已描 3/7」）——
  这类游戏**根本没有「结算」可等**。旧判据只认结算 ⇒ 一律 TIMEOUT，
  看上去像「AI 不会玩」，其实 AI 一直在动。⇒ 补 A~C 三条，判据从两级变三级：

    WIN     ：结算出现（原判据，最强）
    ACTIVE  ：**读数在动**但没结算 —— 实时游戏 / 长局（新增；统计单列，绝不混进 WIN）
    TIMEOUT ：读数完全不动（**这才是「AI 没在工作」**）

  判据 1712 读数指纹 `readout_sig()`：把页面文本抽成 `label=value` 对，三个来源
            ① 标签+取值是两棵树（「步数」「290」）：标签 ≤10 字、不含数字、含进度词
               ⇒ 取紧邻的下一节点（必须含数字，且不是时钟）
            ② 读数被写成**一整句话**（「已补 1/12 格　步数 1」「路线 1/3 · 已描 3/7 · 失误 3/4」）
               ⇒ 按「词+数字」正则拆成多对，旧 read_readouts 这类全抓不到
            ③ 时钟（`3:21`）**一律排除** —— 计时器每秒都动，会把「卡死的游戏」误判成 ACTIVE
            同一对标签前后两次取值不同 ⇒ 记一次「读数变化」。
            分类：进度类（步数/得分/接通/已描…）= AI 在推进；失误类（配错/错手/失误）= AI 在错。
            **只涨失误计数不算 ACTIVE** —— 那是「AI 在动但每次都错」，仍报 TIMEOUT，
            并在 detail 里写明「只有失误计数在动」（正好能一眼看出立方体展开那类的病）。
  ★ 判据 1810（2026-11-08）**ACTIVE = 通过**（新增口径，默认关）：
            `--active-pass` 打开时，**ACTIVE 视为「通过」**（实时/无尽/长局的正确判据）。
            为什么：这 10 款**根本没有结算**，旧统计把它们算成「未通过」⇒ 覆盖率被低估。
            「通过」的条件比 ACTIVE 更严：**只认进度类读数在动**（步数/得分/接通…），
            **失误类的加不加分** —— 只涨失误的仍判 TIMEOUT（见 §判据 1712 分类）。
            JSONL 里始终写 `active_ok`（与开关无关，便于复核）与 `pass`（受开关影响）。
            退出码：开关打开时 ACTIVE 不再算失败；默认关闭 ⇒ 344 WIN 基线不变。
  判据 1713 ACTIVE 早退（**默认关**）：`--active-window N`（秒）>0 时，累计 ≥2 次进度类变化
            且已跑满 N 秒 ⇒ 直接判 ACTIVE 收工，不再干等 120s。
            默认 0 = 不早退：**结算该等的还照等**，免得把「40 秒才结算」的款
            从 WIN 降级成 ACTIVE（会砸掉 344 WIN 的基线）。批量扫实时游戏时才开。
  判据 1714 输赢措辞分开：`电脑赢了 / 你输了 / 挑战失败` ⇒ **FAIL**。
            旧版只看 WIN 正则，而输局弹窗的按钮就写着「再来一局」⇒ **输局被记成 WIN**
            （乒乓的输局文案「😵 电脑赢了，再来一局」就是这样）。页面另有 🎉/通关 时仍按 WIN。
  判据 1716 「点了没反应」当场认：点完 AI 代打后，如果按钮**还写着「AI 代打」**
            （不是「停代打」）⇒ `askAuto()` 根本没执行到 —— 多半是演示期 HintBar 被
            `disabled` 吞掉了点击、或布局刚变过而点在旧 bounds 上（判据 1708/1711 同一类）。
            ⇒ **重新取最新 bounds 再点**，最多 3 次；3 次都没启动且最终 TIMEOUT
            ⇒ 判 **FAIL**「代打按钮点了 3 次都没启动」，而不是白等 120s 记成 TIMEOUT。
            由来：11 款 TIMEOUT 里「路径交叉」「补全盒子」的现场页面上按钮还是「AI 代打」，
            说明代打从头到尾没启动，却记成 TIMEOUT 看上去像「游戏打不动」。
  判据 1717 「起来就走」也认：启动后 1.2s 那次会看到「AI 开始代打…」toast，容易被当成
            已启动，可 autoStep 可能**第一拍就 return false**（算不出可动的一步）⇒ autoRun 立刻收工。
            ⇒ 启动后再等 1.5s 看一眼：按钮又变回「AI 代打」且页面没结算 ⇒ 记 `quit_early`；
            最终 TIMEOUT 时判 **FAIL**「代打启动后 1.5s 内自己就停了」。
            （补全盒子 TIMEOUT 的现场：按钮「AI 代打」+ 步数 2 + 读数不动，正是这个形状。）

用法：
  python3 工具/verify_ai_win.py water_sort 倒水排序
  python3 工具/verify_ai_win.py --names-file /tmp/names.txt
  python3 工具/verify_ai_win.py --limit 10                  # 从注册表随机抽 10 款
  python3 工具/verify_ai_win.py --names-file n.txt --per-game-timeout 180
  python3 工具/verify_ai_win.py --names-file n.txt --out /tmp/chunk.jsonl
      ↑ 分批跑用（`工具/verify_ai_win_batch.sh` 就是这么调的，判据 1682）
  python3 工具/verify_ai_win.py --device 127.0.0.1:5555      # 换连别的模拟器
  python3 工具/verify_ai_win.py 乒乓 --active-window 20      # 实时游戏：读数动 20s 就收工（判据 1713）

退出码：0 = 全部 WIN ｜ 1 = 有 FAIL/TIMEOUT/ACTIVE ｜ 2 = 脚本异常 ｜ 3 = 设备不可用
        （ACTIVE ≠ WIN ⇒ 退出码 1；批量脚本 SKIP=win 下次会重验它，这是有意的）
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
# ── 判据 1712/1713 的旋钮 ──
ACTIVE_WINDOW = 0.0    # 判据 1713：>0 才启用「读数动够就收工」；默认 0 = 不早退（保住 WIN 基线）
ACTIVE_MIN_MOVES = 2   # 判据 1713：早退要求的最少**进度类**变化次数
ACTIVE_COUNTS_PASS = False  # 判据 1810：--active-pass 打开时 ACTIVE 计入通过
DUMP_REMOTE = '/data/local/tmp/_vaw.json'
DUMP_LOCAL = '/tmp/_vaw.json'

# ★ 判据 1718（ai-fixer-a 发现）：GameHost 的**失败结算标题是「再来一局？」**，
#   成功标题是「这一局拿下！」；而「再来一局」/「返回列表」两种弹窗都有（是按钮）
#   ⇒ 旧 WIN_PAT 会把「失败结算」判成 WIN
#   现口径：WIN 只认**成功标题的特征**；失败标题（带问号的「再来一局？」）进 FAIL_PAT
WIN_PAT = re.compile(r'这一局拿下|🎉|全部单色|已通关|通关了')
FAIL_PAT = re.compile(r'没找到解法|倒不动了|本局失败|无解|再来一局？')
FAIL_PAT = re.compile(r'没找到解法|倒不动了|本局失败|无解')
# 判据 1714：**明确的输局措辞**（收窄到没有歧义的几种，宁可漏也不误伤）
#   「电脑赢了 / 你输了」实测出现在 5 处游戏；「挑战失败 / 输给」是同类写法。
LOSE_PAT = re.compile(r'电脑赢了|你输了|AI 赢了|挑战失败|输给')
# 判据 1714：真·通关标记 —— 页面上同时有这些时，即使出现输局措辞也仍按 WIN
STRONG_WIN = ('🎉', '通关', '这一局拿下', '全部单色')
# 判据 1712：读数指纹用的词表
#   进度类 = 「AI 在推进」（这些变了 ⇒ 至少 AI 在干活）
PROGRESS_WORDS = ('步数', '得分', '分数', '归位', '最大', '过关', '过局', '接通', '覆盖',
                  '已补', '已描', '已用', '回合', '轮次', '层数', '关卡', '关数', '剩余',
                  '连击', '进度', '目标', '生命', '金币', '净胜', '比分', '路线')
#   失误类 = 「AI 在错」（只有这些在动 ⇒ 不许判 ACTIVE）
ERROR_WORDS = ('配错', '错手', '失误', '错误', '撞墙', '判错')
#   比分标签：乒乓是「你」「电脑」两个纯字节点，不放进 PROGRESS_WORDS（单字太泛）
SCORE_LABELS = ('你', '电脑', '我')
# 判据 1712 ③：时钟/计时 —— 每秒都在动，必须排除，否则卡死的游戏会被误判成 ACTIVE
CLOCK_PAT = re.compile(r'\d{1,3}\s*[:：]\s*\d{2}')
# 判据 1712 ②：从一整句话里拆「词 + 数字（可带 /分母）」
PAIR_PAT = re.compile(r'([\u4e00-\u9fa5A-Za-z]{1,6})\s*[:：]?\s*(\d+(?:\s*/\s*\d+)?)')

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
  --active-window <秒>      读数动够就判 ACTIVE 收工（默认 0 = 不早退，判据 1713）
  --active-pass             **ACTIVE 视为通过**（判据 1810：实时/无尽/长局没有结算可等）
退出码：0 全通过 ｜ 1 有失败/TIMEOUT/（未开 --active-pass 时的）ACTIVE ｜ 2 脚本异常 ｜ 3 设备不可用
        （开 --active-pass 时 ACTIVE 计入通过 ⇒ 全 ACTIVE 也返回 0）
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


def _close_chat_panel():
    """★ 判据 1772（2026-11-07）：`💬` 和 `🔍` 相邻，验证器点搜索时偶尔会点到 `💬`
    \n    ⇒ 对话面板 `.zIndex(10)` 打开，挡住所有点击（表现为一串「回不到列表」）。
    \n    做法：dump 里如果看到「找」按钮 + 「想玩点什么样的」占位，就点一次 💬 把它关掉。
    """
    d = dump()
    if not d:
        return
    ns = nodes(d)
    txt = '|'.join([x['text'] for x in ns if x['text']])
    if '想玩点什么样的' in txt or ('按「' in txt and '找：' in txt):
        chat = next((x for x in ns if x.get('text') == '💬'), None)
        if chat:
            tap(chat, 1.2)
            time.sleep(0.8)


def _open_search():
    """确保搜索面板打开；返回 TextInput 节点或 None"""
    _close_chat_panel()   # ★ 判据 1772：先关对话面板（它和搜索按钮相邻，容易被误点开）
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
    # ★ 判据 1763（2026-11-07）：点一次 + dump 一次不够 —— 面板有时要 3~5 秒才出来
    #   （跨游戏返回后首页还在动画/搜索按钮刚重绘）⇒ 连点最多 3 次、每次等 1.5s 再 dump。
    for attempt in range(3):
        tap(sb, 1.5)
        d = dump()
        ti = _text_input(nodes(d)) if d else None
        if ti:
            return ti
        # 再拿一次按钮（可能位置变了）
        ns = nodes(d) if d else []
        sb = _search_btn(ns)
        if not sb:
            time.sleep(1.0)
            d = dump()
            ns = nodes(d) if d else []
            sb = _search_btn(ns)
            if not sb:
                return None
    return None


def _clear_input(name):
    """清空搜索框：2055 = 删除键（判据 1678 用 len+6 次，旧版固定 16 次）。

    ★ 为什么按 len+6 而不是死数 16：名字长度不一，短名字多按几次无害、
      长名字按不够会残留前缀 ⇒ 搜出来一堆不相干的卡。
    """
    n = max(16, len(name) + 6)
    for _ in range(n):
        sh("uitest uiInput keyEvent 2055")
    time.sleep(0.3)


def _input_one(ti, q):
    """把 q 输进搜索框并回读校验；成功返回 True。"""
    tap(ti, 1.0)
    _clear_input(q)
    cx, cy = center(ti)
    sh("uitest uiInput inputText %d %d %s" % (cx, cy, q))
    time.sleep(0.6)
    d = dump()
    got = ''
    if d:
        ti2 = _text_input(nodes(d))
        got = ti2['text'] if ti2 else ''
    return bool(_norm(q)) and _norm(q) in _norm(got)

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


def canonical_name(name):
    """★ 判据 1725：用户传的名字可能没空格（「3D迷宫」），而注册表是「3D 迷宫」——
    先把名字映射到注册表标准写法，否则 `' ' in name` 不成立、变体只剩 1 个。"""
    try:
        nm = _norm(name)
        for gid, rname in registry_names():
            if _norm(rname) == nm:
                return rname, gid
    except Exception:
        pass
    return name, gid_for(name)


def _restart_app():
    """★ 判据 1770（2026-11-07）：**跑验证前重启 app，清掉上一轮留下的浮层**。
    \n    血教训：对话面板 `chatOpen=true` 留着，`.zIndex(10)` 盖住所有点击
    \n    ⇒ 17 个 FAIL 全是「回不到列表」（假警报，不是功能坏了）。
    """
    sh("aa force-stop com.andrewoscar.onemore; sleep 1; aa start -a EntryAbility -b com.andrewoscar.onemore")
    # ★ 判据 1777（2026-11-07 18:35）：**8 秒不够** —— 开屏 2.27s + 加载 + 首页首帧，
    #   实测 8 秒时还在开屏/首页未就绪 ⇒ `open_game` 点搜索点不到 ⇒ 一串「进错游戏」。
    time.sleep(15)


def _ensure_home():
    """★ 判据 1763（2026-11-07）：进游戏前**先确保在首页**。
    \n    原来 `open_game` 假设"每次都在首页"，可上一款可能停在结算页/隐私页/设置页
    \n    （真机实测：验证器在「One More — Privacy Policy」页上点搜索键 ⇒ 必然 FAIL）。
    \n    做法：按 `‹` 最多 5 次，直到页面出现「One More」且没有 `‹`（首页没有返回键）。
    """
    for _ in range(5):
        d = dump()
        ns = nodes(d) if d else []
        txt = [x['text'] for x in ns if x['text']]
        joined = '|'.join(txt)
        # ★ 判据 1764：隐私政策是**用系统浏览器打开的网页**（`awesome639.github.io`）
        #   ⇒ 检测到浏览器地址栏就直接 `aa start` 把 app 拉回来（网页里没有 `‹` 可点）
        if 'awesome639.github.io' in joined or ('Privacy Policy' in joined and 'Developer' in joined):
            sh("aa force-stop com.andrewoscar.onemore; sleep 1; aa start -a EntryAbility -b com.andrewoscar.onemore")
            time.sleep(6)
            continue
        on_home = ('One More' in joined) and ('355' in joined) and not any(t == '‹' for t in txt)
        if on_home:
            return True
        back = next((x for x in ns if x.get('text') == '‹'), None)
        if back is None:
            # 没有返回键又不在首页 ⇒ 可能是游戏内（关掉）或未知页
            time.sleep(1.0)
            continue
        tap(back, 1.2)
    return False


def open_game(name):
    """搜索并进入游戏；返回 (ok, why)。

    ★ 判据 1678：第一次搜不到 ⇒ **清空搜索框重搜一次**（第 ④ 级兜底），仍无才 FAIL。
      实测「进不去游戏」多数是搜索词没吃进去 / 卡片匹配过严，不是游戏打不开。
    ★ 判据 1763：**先回首页**（否则在隐私页/结算页上点什么都没用）。
    """
    _restart_app()          # ★ 判据 1770：每次进游戏前重启，清掉浮层状态
    _ensure_home()
    name, gid = canonical_name(name)
    for attempt in (1, 2):
        _BUDGET.check()
        ti = _open_search()
        if not ti:
            # 面板本身也可能被过渡动画/输入法挡住 ⇒ 和卡片一样给一次重试（判据 1678）
            if attempt == 1:
                print('   ⚠️ 点不开搜索面板，重试…', flush=True)
                continue
            return False, '🔍 点不开搜索面板（重试后仍无）'
        # ★ 判据 1719：**所有变体都要试** ——
        #   「AB 反转」完整名被空格截断 ⇒ 要尾词；「3D 迷宫」尾词「迷宫」搜出的是别的迷宫 ⇒ 要完整名
        #   只试「输入成功的第一个变体」会漏（3D 迷宫就是这么被判 FAIL 的）
        variants = [name]
        if ' ' in name:
            variants.append(name.replace(' ', ''))
            variants.append(name.split()[-1])
            variants.append(name.split()[0])   # ★ 判据 1724：首词也要试（「3D 迷宫」→「3D」能搜到）
        any_input = False
        for q in variants:
            ok_in = _input_one(ti, q)
            print('     [variant] %r input=%s' % (q, ok_in), flush=True)
            if not ok_in:
                continue
            any_input = True
            card = _wait_card(name, gid)
            print('     [variant] %r card=%s' % (q, card['id'] if card else None), flush=True)
            if card:
                tap(card, 6.0)
                time.sleep(1.5)
                return True, ''
        if not any_input:
            if attempt == 1:
                continue
            return False, '搜索词输不进去'
        if attempt == 1:
            print('   ⚠️ 所有变体都没找到卡片，清空重搜…', flush=True)
    return False, '搜不到卡片（所有变体 + 重搜后仍无）'


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
    # ★ 判据 1778/1780（2026-11-07 20:00）：**固定 sleep 不可靠** ——
    #   演示最长 3+6.5≈9.5 秒，但打砖块的演示**会反复播**（实测 12 秒后 dump 仍只有 12 个节点、
    #   AI 按钮完全不渲染 = 判据 1689 的演示期）。手动等到 13 秒就正常。
    #   ⇒ 改成**轮询等「AI 代打」出现**（最多 25 秒），出现即返回，不出现再走点击流程。
    deadline = time.time() + 25
    while time.time() < deadline:
        d0 = dump()
        ns0 = nodes(d0) if d0 else []
        if find(ns0, 'AI 代打'):
            return
        time.sleep(2.0)
    return
    # ★ 判据 1697：坐标必须按**实际屏幕尺寸**算 —— 2560×1600 上写死的
    #   (1280,800)/(1280,220) 在 440×744(1320×2232) 上会点到屏幕边缘/误触
    # ★ 判据 1697：不依赖屏幕尺寸 —— 在几个「安全空白点」各点一次（屏幕外点击会被忽略）
    # ★ 判据 1721：别点**底部/边缘**（打砖块的「暂停」、其它游戏的重开都在那）——
    #   只点屏幕中心与标题区；小屏用 300/300 覆盖
    for (px, py) in [(1280, 800), (660, 800), (660, 220), (1280, 220), (300, 300)]:
        sh("uitest uiInput click %d %d" % (px, py))
        time.sleep(0.4)
    time.sleep(1.2)


def read_readouts(ns):
    """抓读数：步数 / 得分 / 归位 的下一个节点（原判据，保留：detail 里给人看）"""
    txt = [x['text'] for x in ns if x['text']]
    out = {}
    for i, t in enumerate(txt):
        if t in ('步数', '得分', '归位') and i + 1 < len(txt):
            out[t] = txt[i + 1]
    return out


def _word_kind(t):
    """这段文字是「进度读数」还是「失误读数」？（判据 1712 的分类依据）"""
    for w in ERROR_WORDS:
        if w in t:
            return 'e'
    for w in PROGRESS_WORDS:
        if w in t:
            return 'p'
    return ''


def readout_sig(ns):
    """页面读数指纹（判据 1712）：{'L:标签': 值, 'C:词': 值}。

    ★ 为什么不能只盯「步数/得分/归位」：乒乓的比分是「你」「0」两棵树，
      蜘蛛纸牌是「步数」+「290」，补全盒子和描路径干脆把读数写成一整句话
      （「已补 1/12 格　步数 1」「路线 1/3 · 已描 3/7 · 失误 3/4」）
      ⇒ 旧 `read_readouts` 这三种全抓不到（实测 TIMEOUT 记录的「读数={}」就是它）。
    """
    sig = {}
    txt = [x['text'] for x in ns if x['text']]
    for i, t in enumerate(txt):
        if CLOCK_PAT.search(t):
            continue                     # 判据 1712 ③：时钟不算读数
        # ① 标签 + 紧邻取值：「步数」→「290」/「电脑」→「3」/「配错」→「38」
        #   ★ 失误类标签也要收（判据 1712）：不收就分不出「只有失误在涨」的假活动
        kind = _word_kind(t)
        if (len(t) <= 10 and not re.search(r'\d', t)
                and (t in SCORE_LABELS or kind in ('p', 'e'))):
            if i + 1 < len(txt):
                v = txt[i + 1]
                if len(v) <= 16 and re.search(r'\d', v) and not CLOCK_PAT.search(v):
                    sig['L:' + t] = v.strip()
        # ② 一整句话里的读数：「已补 1/12 格　步数 1」⇒ 已补=1/12 · 步数=1
        if len(t) > 40 or not re.search(r'\d', t):
            continue
        if not _word_kind(t) and not re.search(r'\d+\s*/\s*\d+', t):
            continue
        for m in PAIR_PAT.finditer(t):
            w = m.group(1)
            if len(w) < 2 and w not in SCORE_LABELS:
                continue                 # 单个字母/符号（'v'、'x'）不算读数标签
            sig['C:' + w] = re.sub(r'\s+', '', m.group(2))
    return sig


def sig_moves(prev, cur):
    """两次指纹的差异 ⇒ (进度类变化, 失误类变化)，元素形如「步数 10→105」（判据 1712）。"""
    prog, err = [], []
    for k, v in cur.items():
        old = prev.get(k)
        if old == v:
            continue
        kind = _word_kind(k.split(':', 1)[1])
        item = '%s %s→%s' % (k.split(':', 1)[1], '—' if old is None else old, v)
        (err if kind == 'e' else prog).append(item)
    for k, v in prev.items():
        if k in cur:
            continue
        kind = _word_kind(k.split(':', 1)[1])
        item = '%s %s→—' % (k.split(':', 1)[1], v)
        (err if kind == 'e' else prog).append(item)
    return prog, err


def watch(seconds=120):
    """轮询直到结算/失败/超时；返回 (verdict, detail)。

    ★ 判据 1712/1713：判据分三级 —— 结算出现 = **WIN**；读数在动但没结算 = **ACTIVE**；
      读数完全不动 = **TIMEOUT**。ACTIVE 让「实时对打/长局」这类**没有结算可等**的款
      不再被误记成 TIMEOUT（乒乓：只有「你 0 / 电脑 3」在走）。
    ★ 判据 1676：seconds 被单款剩余预算夹住 —— 否则「watch 等 120s」会把 240s 预算
      整个吃掉，AI 启动前的那几步全白等。
    """
    left = _BUDGET.remaining()
    if left < float('inf'):
        seconds = max(5.0, min(float(seconds), left - 3))
    t0 = time.time()
    steps_seen = []
    prev_sig = None
    prog_moves = []        # [(t, [变化…])] 进度类
    err_moves = []         # [(t, [变化…])] 失误类
    paused_seen = False
    while time.time() - t0 < seconds:
        d = dump()
        if not d:
            time.sleep(2)
            continue
        ns = nodes(d)
        txt = [x['text'] for x in ns if x['text']]
        joined = '|'.join(txt)
        ro = read_readouts(ns)
        st = ro.get('步数', '')
        if st and (not steps_seen or steps_seen[-1] != st):
            steps_seen.append(st)      # 只留变化序列（旧版用 set，detail 里排不出先后）
        if '已暂停' in joined or '暂停中' in joined:
            paused_seen = True         # 只记录，不擅自点「继续」（未在真机验证过，不乱动）
        if FAIL_PAT.search(joined) and ('没找到' in joined or '倒不动' in joined):
            return 'FAIL', 'toast: ' + ','.join(t for t in txt if FAIL_PAT.search(t))[:80]
        # ★ 判据 1714：输局必须排在 WIN 之前 —— 输局弹窗的按钮就写着「再来一局」，
        #   旧版会把它记成 WIN（乒乓的「😵 电脑赢了，再来一局」正是这种）。
        if LOSE_PAT.search(joined) and not any(w in joined for w in STRONG_WIN):
            return 'FAIL', '结算=输：' + ','.join(t for t in txt if LOSE_PAT.search(t))[:60]
        if WIN_PAT.search(joined):
            return 'WIN', '结算出现 · 读数=%s' % (readout_sig(ns) or ro)
        # ★ 判据 1671：部分游戏「通关即自动返回列表」⇒ 返回列表页本身要算完成，
        #   否则会一直等到 TIMEOUT（「方向回忆」就栽在这）
        if ('One More' in joined) and ('AI 代打' not in joined) and ('One More' in '|'.join(txt[:3])):
            return 'WIN', '已返回列表（视作完成）'
        # ── 判据 1712：读数指纹对比 ──
        sig = readout_sig(ns)
        if prev_sig is not None:
            pg, er = sig_moves(prev_sig, sig)
            if pg:
                prog_moves.append((round(time.time() - t0, 1), pg))
            if er:
                err_moves.append((round(time.time() - t0, 1), er))
        prev_sig = sig
        # ── 判据 1713：进度类读数动够 N 次且过窗口 ⇒ ACTIVE 收工（默认关） ──
        n_prog = sum(len(p[1]) for p in prog_moves)
        if (ACTIVE_WINDOW > 0 and n_prog >= ACTIVE_MIN_MOVES
                and (time.time() - t0) >= ACTIVE_WINDOW):
            return 'ACTIVE', '读数在动但没结算（%.0fs 内 %d 次：%s）' % (
                time.time() - t0, n_prog,
                '；'.join(x for p in prog_moves for x in p[1])[:120])
        time.sleep(1.6)
    d = dump()
    ns = nodes(d) if d else []
    # ── 窗口结束：读数动过 ⇒ ACTIVE（实时/长局），完全不动 ⇒ TIMEOUT ──
    if prog_moves:
        return 'ACTIVE', '读数在动但没结算（%d 次：%s）' % (
            sum(len(p[1]) for p in prog_moves),
            '；'.join(x for p in prog_moves for x in p[1])[:120])
    tail = ''
    if err_moves:
        # 判据 1712：只有失误计数在动 ⇒ **不是** ACTIVE，是「AI 在动但每次都错」
        tail += '；只有失误计数在动：%s（AI 有动作但每次都不对）' % (
            '；'.join(x for p in err_moves for x in p[1])[:80])
    if paused_seen:
        tail += '；页面出现过暂停态（AI 再强也不会得分）'
    return 'TIMEOUT', '读数=%s 步数历史=%s%s' % (
        read_readouts(ns), steps_seen[-8:], tail)


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


def ai_state(ns):
    """代打到底跑起来没有（判据 1716）：返回 (已启动, 仍在待机)。

    · 已启动 = 按钮变成「停代打」，或刚弹出的「AI 开始代打…」toast 还在
    · 仍在待机 = 按钮**还写着**「AI 代打」——这说明 `askAuto()` 压根没执行到
      （按钮被 disabled 吞掉 / 点在旧 bounds 上点空了），与 1708/1711 同一类
    """
    txt = [x['text'] for x in ns if x['text']]
    started = any('停代打' in t for t in txt) or any('开始代打' in t for t in txt)
    idle = any(t.strip() == 'AI 代打' for t in txt)
    return started, (idle and not started)


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
    # ★ 判据 1722：演示最长约 6.5s —— stop_demo 的点击不一定能停掉（有的游戏根容器不接触碰），
    #   再等 2.5s 让演示自然结束；否则按钮仍 disabled（enabled(false)），点了没反应
    time.sleep(2.5)
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
    # ★ 判据 1720：回合制游戏（井井棋）AI 走完一步就停是正常的 ——
    #   记下点之前的读数指纹，1717 判「算不出」时要求「读数也没变」才算
    _sig_before = readout_sig(ns)
    tap(ai, 0.5)
    # ★ 判据 1716：**「点了没反应」必须当场认出来，不许一口气空等 120s**。
    #   由来：11 款 TIMEOUT 里，路径交叉 / 补全盒子的现场页面上按钮还写着「AI 代打」
    #   （不是「停代打」）—— 说明代打从头到尾**没启动**，却白等了 120s 记成 TIMEOUT，
    #   看上去像「游戏打不动」，实际上跟游戏内容无关。
    #   机制正好是判据 1708/1711 那一类：演示期间 HintBar 是 `disabled`（点了被吞掉）、
    #   或者布局刚变过（旧 bounds 点空）。
    #   ⇒ 按钮还写着「AI 代打」就**重新取最新 bounds 再点**，最多 3 次；
    #     仍然没启动且最终 TIMEOUT ⇒ 判 FAIL 并写明原因（比 TIMEOUT 有用得多）。
    started = False
    idle_end = False
    quit_early = False
    tries = 0
    for attempt in (1, 2, 3):
        time.sleep(1.2 if attempt == 1 else 1.5)
        d = dump()
        ns = nodes(d) if d else []
        ok_start, idle = ai_state(ns)
        if ok_start:
            started = True
            # ★ 判据 1717：**代打起来就走**（autoStep 第一拍就 return false）也认出来。
            #   1.2s 那次会看到「AI 开始代打…」toast ⇒ 判成已启动；可它 320ms 就自己停了。
            #   真机例：补全盒子 TIMEOUT 现场按钮仍是「AI 代打」+ 步数 2 + 读数不动 ——
            #   `boxHoles()` 一上来就是空 ⇒ autoStep 首次返回 false ⇒ autoRun 立刻收工。
            time.sleep(1.5)
            d3 = dump()
            ns3 = nodes(d3) if d3 else []
            _, idle3 = ai_state(ns3)      # 只关心它是不是又回到待机
            j3 = '|'.join(x['text'] for x in ns3 if x['text'])
            if idle3 and not WIN_PAT.search(j3) and not LOSE_PAT.search(j3):
                # ★ 判据 1720：读数变了 ⇒ 它其实走过一步（回合制），不算「算不出」
                sig3 = readout_sig(ns3)
                if sig3 == _sig_before:
                    quit_early = True
            break
        if not idle:
            break                       # 按钮不在页面上（可能瞬间通关回列表）⇒ 交给 watch 判
        idle_end = True
        ai2 = find(ns, 'AI 代打')       # 判据 1711：用**这次** dump 的 bounds
        if ai2 and attempt < 3:
            tries = attempt
            print('   ⚠️ AI 代打点了没启动（第 %d 次），重新取 bounds 再点…' % attempt, flush=True)
            # ★ 判据 1779（2026-11-07 20:05）：**0.5 秒太短** —— 打砖块/穿云/西蒙说
            #   手动点（等 2 秒）都正常启动，验证器 0.5 秒就判「没启动」⇒ 误报。
            tap(ai2, 2.0)
    verdict, detail = watch(120)
    if (not started) and idle_end and verdict == 'TIMEOUT':
        return 'FAIL', ('代打按钮点了 %d 次都没启动（页面始终写着「AI 代打」，'
                        '多半是演示期 disabled / 布局变了点到空处）｜ %s'
                        % (tries + 1, detail))
    if quit_early and verdict == 'TIMEOUT':
        return 'FAIL', ('代打启动后 1.5s 内自己就停了（autoStep 第一拍返回 false：'
                        '多半是它算不出可动的一步）｜ %s' % detail)
    return verdict, detail


# ════════════════════════════════════════════════════════════════════════════
#  结果 / 进度（判据 1679 / 1680）
# ════════════════════════════════════════════════════════════════════════════
def save(name, verdict, detail):
    """判据 1680：一行一条 `{name, verdict, detail, ts}`，写完就 flush。

    ★ 为什么逐条 flush：24 款要跑 1 小时＋，中途掉线/被杀时，
      已经验完的结论必须已经在盘上，否则整批白跑。
    """
    # ★ 判据 1810：`active_ok` 与开关无关（ACTIVE 本身就是「有进度、无失败」）；
    #   `pass` 受 `--active-pass` 影响，供统计与下游脚本直接读，不用再自己判 verdict。
    active_ok = (verdict == 'ACTIVE')
    passed = (verdict == 'WIN') or (active_ok and ACTIVE_COUNTS_PASS)
    rec = {'name': name, 'verdict': verdict, 'detail': detail,
           'active_ok': active_ok, 'pass': passed,
           'ts': time.strftime('%Y-%m-%dT%H:%M:%S')}
    with io.open(OUT, 'a', encoding='utf-8') as f:
        f.write(json.dumps(rec, ensure_ascii=False) + '\n')
        f.flush()


def _stats_line(stats):
    """判据 1679 + 1712：一行汇总（ACTIVE 单列，绝不并进 WIN）"""
    base = 'WIN %d · ACTIVE %d · FAIL %d · TIMEOUT %d · ERROR %d' % (
        stats['WIN'], stats['ACTIVE'], stats['FAIL'], stats['TIMEOUT'], stats['ERROR'])
    if ACTIVE_COUNTS_PASS:
        # 判据 1810：把「ACTIVE 计入通过」这件事显式打出来，避免看统计的人误以为 WIN 变多了
        base += ' ｜ ACTIVE 计入通过 ⇒ 通过 %d/%d' % (
            stats['WIN'] + stats['ACTIVE'], stats['WIN'] + stats['ACTIVE']
            + stats['FAIL'] + stats['TIMEOUT'] + stats['ERROR'])
    return base


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
    opts = {'names': [], 'limit': 10, 'per_game': PER_GAME, 'out': OUT, 'device': DEV,
            'active_window': ACTIVE_WINDOW, 'active_pass': False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('-h', '--help'):
            print(USAGE)
            raise SystemExit(0)
        if a == '--active-pass':
            opts['active_pass'] = True
            i += 1
            continue
        if a in ('--limit', '--per-game-timeout', '--names-file', '--out', '--device',
                 '--active-window'):
            if i + 1 >= len(argv):
                print('🔴 参数缺值：%s\n%s' % (a, USAGE), file=sys.stderr)
                raise SystemExit(2)
            v = argv[i + 1]
            i += 2
            if a == '--limit':
                opts['limit'] = int(v)
            elif a == '--per-game-timeout':
                opts['per_game'] = float(v)
            elif a == '--active-window':
                opts['active_window'] = float(v)
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
    global OUT, DEV, PER_GAME, _BUDGET, ACTIVE_WINDOW, ACTIVE_COUNTS_PASS
    opts = parse_args(sys.argv[1:])
    OUT = os.path.abspath(opts['out'])
    DEV = opts['device']
    PER_GAME = float(opts['per_game'])
    ACTIVE_WINDOW = float(opts['active_window'])
    ACTIVE_COUNTS_PASS = bool(opts.get('active_pass', False))

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

    print('待验 %d 款（单款上限 %.0fs%s）：%s' % (
        len(names), PER_GAME,
        '' if ACTIVE_WINDOW <= 0 else '，ACTIVE 窗口 %.0fs' % ACTIVE_WINDOW,
        ' '.join(names[:12])), flush=True)
    print('结果：%s' % OUT, flush=True)

    stats = Counter()
    bad = []
    active = []                            # 判据 1712：ACTIVE 单列，不混进「未通过」也不混进 WIN
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
        # 判据 1677：只要不是 WIN 就把当时的页面写进 detail（ACTIVE 也写：好复盘）
        if verdict != 'WIN':
            detail = '%s ｜ %s' % (detail, diag_page())
        save(nm, verdict, detail)
        stats[verdict] += 1
        if verdict == 'ACTIVE':
            active.append((nm, detail))
        elif verdict != 'WIN':
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
    if active:
        print('  ACTIVE（读数在动·没等到结算，判据 1712）：', flush=True)
        for nm, dd in active:
            print('    %s => %s' % (nm, (dd or '')[:110]), flush=True)
    if bad:
        print('  未通过：', flush=True)
        for nm, v, dd in bad:
            print('    %s => %s（%s）' % (nm, v, (dd or '')[:120]), flush=True)
    # ★ 判据 1810：开了 --active-pass ⇒ ACTIVE（有进度、无失败）也算通过
    passed_n = stats['WIN'] + (stats['ACTIVE'] if ACTIVE_COUNTS_PASS else 0)
    return 0 if passed_n == total else 1


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
