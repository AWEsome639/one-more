#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量真机验证「AI 代打」是否真的能通关。

用法：
  python3 工具/verify_batch.py 计算冲刺 考拉兹 数字键
  python3 工具/verify_batch.py --all-pending      # 验台账里所有"待验"的

为什么要这个脚本：
  · 每款验证都要「回列表 → 点分类 chip → 扫 → 进游戏 → 点代打 → 等」
    以前每轮都现写一遍，写错一次就白等十分钟
  · 结果落到 工具/verify_results.json，多轮可以累积，不会重复验

约定：
  · 分类 chip 的固定坐标（右上角筛选面板展开时）：
      全部(228,1310)  经典(612,1310)  逻辑(996,1310)  数字(1266,1310)
  · 扫描：每步滑 1 屏，**连续 3 屏没有新名字就判定到底**（这条今天救了很多次）
"""
import sys, os, io, json, re, time, subprocess

HDC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV = "127.0.0.1:5555"
HERE = os.path.dirname(os.path.abspath(__file__))
RESULT = os.path.join(HERE, "verify_results.json")

CHIP_ALL, CHIP_CLASSIC, CHIP_LOGIC, CHIP_MATH = 228, 612, 996, 1266

WIN_PAT = re.compile(r'🎉|通关|再来一局|拿下|全部配对|搞定|完成')
# ★ 2026-10-26：WIN_PAT 会误伤"提示文案"
#   实例：「提示：每轮清单更长，答对 75% 即通关」← 这是提示，不是通关
#   ⇒ 这些条件句式一律不算赢
FALSE_WIN = re.compile(r'^提示|即通关|就通关|可通关|才能通关|答对\s*\d+\s*%\s*即|^通关线|⇒|样例|规则：|玩法|：.*通关$|：.*通关\s*$')

_DEAD = [False]


def sh(c):
    """跑一条设备命令。

    ★★★ 2026-10-27 加：**必须检查输出里的 [Fail]**
      —— 之前模拟器掉线时 hdc 返回码仍是 0、输出里写着
         `[Fail][E001005] Device not found or connected`
      ⇒ 脚本一句都不喊，滑了几十次全白滑
      ⇒ 我因此浪费了几小时，把所有"没找到游戏"都归错了因
    """
    r = subprocess.run([HDC, "-t", DEV, "shell", c], capture_output=True, timeout=120)
    out = (r.stdout or b'') + (r.stderr or b'')
    if b'[Fail]' in out or b'Device not found' in out:
        _DEAD[0] = True
    return out


def device_ok():
    """设备还连着吗。"""
    r = subprocess.run([HDC, "-t", DEV, "shell", "echo ok"], capture_output=True, timeout=60)
    out = (r.stdout or b'') + (r.stderr or b'')
    return b'ok' in out and b'[Fail]' not in out

def device_alive():
    """★ 2026-11-01（判据 98）：先确认"设备在线"，再谈"页面长什么样"。

    起因：一次回归跑出 2/7，我以为是首页代码被重构弄坏了。
    真因是设备断连，而 `dump()` 读的是持久文件 `/tmp/vb.json` ——
    `hdc file recv` 失败时文件**保持上一次的内容**，于是返回了
    15 分钟前、另一个尺寸（195×195）的界面。整屏"完整、自洽、格式正确"，
    每一条断言都基于它 —— 这是最难识破的一类假失败。
    """
    try:
        r = subprocess.run([HDC, "-t", DEV, "shell", "echo __OK__"],
                           capture_output=True, timeout=20)
        return b"__OK__" in r.stdout
    except Exception:
        return False


def dump():
    # ★ 先删本地文件：recv 失败时不能留下上一次的内容（判据 98）
    try:
        os.remove('/tmp/vb.json')
    except OSError:
        pass
    sh("uitest dumpLayout -p /data/local/tmp/vb.json")
    r = subprocess.run([HDC, "-t", DEV, "file", "recv",
                        "/data/local/tmp/vb.json", "/tmp/vb.json"],
                       capture_output=True, timeout=90)
    if not os.path.exists('/tmp/vb.json'):
        return []
    try:
        d = json.load(io.open('/tmp/vb.json', encoding='utf-8'))
    except Exception:
        return []
    rows = []
    def walk(n):
        if isinstance(n, dict):
            a = n.get('attributes') or {}
            t = (a.get('text') or '').strip()
            b = a.get('bounds') or ''
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
            if m and t:
                x1, y1, x2, y2 = [int(g) for g in m.groups()]
                rows.append((t, (x1 + x2) // 2, (y1 + y2) // 2, y1, y2))
            for c in n.get('children') or []:
                walk(c)
    walk(d)
    return rows

def _reset_filter():
    """把分类筛选重置到「全部」。

    ★ 2026-10-27 第二次修：原来看 chip 的 `selected` 属性判断——
      **但「全部」的 selected 永远是 false**（它只是筛选标签，不是可选中控件）
      ⇒ 判断永远为假 ⇒ 每次 to_top 都重启 App ⇒ 慢 + 列表位置乱
    现在改成：按文字找到「全部」就点一下（已是全部时点了也无害）。
    """
    for r in dump():
        if r[0] == '全部' and r[3] < 260:
            sh("uitest uiInput click %d %d" % (r[1], r[2]))
            time.sleep(1.2)
            return True
    return False


def restart_app():
    """★ App 会卡在"列表滑不动 / 内容错乱"的状态 ⇒ 直接重启最省时间。
    （2026-10-27 教训：跟它较劲 30 分钟，不如重启 3 秒）
    重启后**轮询等首页出现**（固定 22 秒有时不够）。"""
    subprocess.run([HDC, "-t", DEV, "shell", "aa force-stop com.andrewoscar.onemore"],
                   capture_output=True, timeout=120)
    time.sleep(2)
    subprocess.run([HDC, "-t", DEV, "shell",
                    "aa start -b com.andrewoscar.onemore -a EntryAbility"],
                   capture_output=True, timeout=180)
    for _ in range(12):          # 最多等 60 秒
        time.sleep(5)
        try:
            rows = dump()
        except Exception:
            continue
        if any(r[0] == 'One More' for r in rows):
            time.sleep(2)
            return


def _scroll_test():
    """滚一下看列表动不动（判定 App 是否卡住）"""
    before = [r[0] for r in dump() if 250 < r[3] < 1950][:3]
    sh("uitest uiInput swipe 660 1800 660 1300 700")
    time.sleep(0.8)
    after = [r[0] for r in dump() if 250 < r[3] < 1950][:3]
    return before != after


def _at_list():
    """当前是不是游戏列表。

    ★ 判据必须**两条同时成立**（2026-10-27 第五次修）：
      ① 顶部（y < 260）有「全部」chip —— 首页没有
      ② 可视区（250 < y < 1950）有 ≥6 个长度 2–14 的短名字 —— 列表有
    ⇒ 只满足①可能是别的页面；只满足②**首页也满足**（LV / 5 / 44% / 1 天 …）
    """
    rows = dump()
    has_chip = any(r[0] == '全部' and r[3] < 260 for r in rows)
    names = [r for r in rows if 250 < r[3] < 1950 and 2 <= len(r[0]) <= 14]
    return has_chip and len(names) >= 6


def to_top():
    """回到**游戏列表**顶部。

    ★★★★★ 2026-10-27 第六次、也是最终版 —— 放弃"猜位置"，改成**固定动作**：
      前五版都在改进判据（有没有行 / 有没有「全部」/ selected / ≥6 短名字），
      每一版都被下一个页面形态骗过去，累计浪费数小时。

      **实测唯一 100% 可靠的路 = 手动做过的那个动作：**
        重启 App → 等首页出现 → 往下滑 8 次（每次停 0.7 秒）
      ⇒ 不判断、不猜测、不提前退出。慢（约 25 秒）但**不会错**。
    """
    restart_app()
    for _ in range(8):
        sh("uitest uiInput swipe 660 1900 660 700 500")
        time.sleep(0.7)
    _reset_filter()
    # 回到列表顶
    for _ in range(3):
        for _ in range(5):
            sh("uitest uiInput swipe 660 1000 660 1950 500")
            time.sleep(0.15)


def back_to_list():
    for _ in range(4):
        rows = dump()
        b = [r for r in rows if r[0] == '‹']
        if not b:
            return
        sh("uitest uiInput click %d %d" % (b[0][1], b[0][2]))
        time.sleep(2.5)

# ★ 2026-10-26 App 内部任意页面都算"在 App 里"
#   原来只认首页标题「One More」⇒ App 停在列表/游戏页时被误判为"不在"
APP_MARKS = ('One More', '全部', '展开', '提示', 'AI 代打', '重开', '再来一局', '再试一次')


def in_app():
    rows = dump()
    texts = [r[0] for r in rows]
    return any(m in texts for m in APP_MARKS)

def ensure_app():
    """模拟器待久了会把 App 切到后台 ⇒ 每款验证前先确认，不在就重进。"""
    if in_app():
        return True
    subprocess.run([HDC, "-t", DEV, "shell",
                    "aa force-stop com.andrewoscar.onemore"],
                   capture_output=True, timeout=120)
    time.sleep(2)
    subprocess.run([HDC, "-t", DEV, "shell",
                    "aa start -b com.andrewoscar.onemore -a EntryAbility"],
                   capture_output=True, timeout=120)
    time.sleep(22)
    return in_app()

def pick_chip(x):
    """选分类。★ 2026-10-25 修：筛选面板默认是收起的（只显示「全部」和「展开」），
    固定坐标点 (x,1310) 在收起状态下会点到空白 ⇒ 必须：
      ① 先看 chips 在不在，不在就点「展开」
      ② **按文字找 chip 再点**（不要靠坐标）
      ③ 点完确认标签变了
    """
    lab = {CHIP_ALL: '全部', CHIP_CLASSIC: '经典', CHIP_LOGIC: '逻辑', CHIP_MATH: '数字'}[x]
    to_top()
    rows = dump()
    has_chips = any(re.match(r'^(全部|经典|逻辑|数字)\s', r[0]) for r in rows)
    if not has_chips:
        ex = [r for r in rows if r[0] == '展开']
        if ex:
            sh("uitest uiInput click %d %d" % (ex[0][1], ex[0][2]))
            time.sleep(3)
            to_top()
            rows = dump()
    chips = [r for r in rows if re.match(r'^' + lab + r'\s', r[0])]
    if chips:
        sh("uitest uiInput click %d %d" % (chips[0][1], chips[0][2]))
        time.sleep(5)

CENSUS_PATH = os.path.join(HERE, 'list_census.json')

def load_census():
    try:
        return json.load(io.open(CENSUS_PATH, encoding='utf-8'))
    except Exception:
        return {}

def find_game(name, maxstep=90, use_census=True):
    """回列表顶 → 逐屏扫 → 找到返回 (x,y)。
    ★ 2026-10-25：先用 工具/list_census.json 里记的"第几步"快进，
      再开始逐屏扫。否则在第 92–118 步的游戏扫不到（实测）。"""
    to_top()
    census = load_census()
    skip = census.get(name, 0) if use_census else 0
    if skip > 4:
        for _ in range(max(0, skip - 4)):
            sh("uitest uiInput swipe 660 1800 660 1400 600")
            time.sleep(0.55)
    seen, stall = set(), 0
    for step in range(maxstep):
        rows = dump()
        # ★ 2026-10-27 修：原来只看 y 1400–1950 那一窄条判"有没有新名字"，
        #   滑动位移小于一个卡片高度时就判"没进展" ⇒ stall 3 次就放弃
        #   （实测：数字华容道就在第 1 屏，却返回 None）
        nm = [r[0] for r in rows if 250 < r[3] < 2200 and 2 <= len(r[0]) <= 14]
        new = [n for n in nm if n not in seen]
        for n in nm:
            seen.add(n)
        for r in rows:
            if r[0] == name and 250 < r[3] < 2200:
                return (r[1], r[2])
        stall = stall + 1 if not new else 0
        if stall >= 8:      # 连续 8 屏都没有新名字才算到底（原来 3 太早）
            return None
        sh("uitest uiInput swipe 660 1800 660 1450 600")
        time.sleep(0.7)
    return None

def verify_one(name, chip):
    """返回 (结果, 证据文字)。结果：pass / fail / notfound / nobutton / wronggame"""
    if not ensure_app():
        return 'noapp', ''
    back_to_list()
    pick_chip(chip)
    pos = find_game(name, use_census=(chip == CHIP_ALL))
    if not pos:
        return 'notfound', ''
    sh("uitest uiInput click %d %d" % pos)
    time.sleep(8)
    rows = dump()
    if name not in [r[0] for r in rows[:4]]:
        return 'wronggame', ' '.join(r[0][:8] for r in rows[:3])
    btns = {r[0]: (r[1], r[2]) for r in rows if '代打' in r[0]}
    if not btns:
        return 'nobutton', ''
    k = list(btns.keys())[0]
    sh("uitest uiInput click %d %d" % btns[k])
    time.sleep(1.5)
    evidence = ''
    saw_end = False
    for _ in range(4):
        time.sleep(14)
        rows = dump()
        hit = [x[0] for x in rows
               if WIN_PAT.search(x[0]) and len(x[0]) > 4
               and not FALSE_WIN.search(x[0])]
        if hit:
            evidence = hit[0][:44]
            return 'pass', evidence
        # ★ 2026-10-25 教训：「本局已结束」是中性结算文案，输赢都用它；
        #   🎉 才是赢，而且结算动画会晚一点才出来 ⇒ 看到"结束"再多看两眼
        if any(('结束' in x[0] or '时间到' in x[0]) for x in rows):
            saw_end = True
            for _ in range(2):
                time.sleep(2)
                r2 = dump()
                h2 = [x[0] for x in r2 if '🎉' in x[0]]
                if h2:
                    return 'pass', h2[0][:44]
            break
    return ('fail', '已结算但没看到 🎉') if saw_end else ('fail', evidence)

def load():
    try:
        return json.load(io.open(RESULT, encoding='utf-8'))
    except Exception:
        return {}

def save(d):
    io.open(RESULT, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=1))

def top_list():
    """回到游戏列表顶部（看见 One More 标题就停）"""
    for _ in range(30):
        subprocess.run([HDC, "-t", DEV, "shell",
                        "uitest uiInput swipe 660 1000 660 1950 600"],
                       capture_output=True, timeout=120)
        time.sleep(0.22)
    time.sleep(1.2)


def check_hint(name):
    """★ 2026-10-26 验提示：进游戏 → 点「提示」→ 看有没有弹出答案文案
    返回 (ok, evidence)
    """
    # ★ 先回列表顶部，否则"在当前位置之上"的游戏永远扫不到
    top_list()
    pos = find_game(name)
    if not pos:
        return False, '没找到游戏'
    sh("uitest uiInput click %d %d" % pos)
    time.sleep(7)
    rows = dump()
    btn = [r for r in rows if r[0] == '提示']
    if not btn:
        return False, '没有提示按钮'
    before = set(x[0] for x in rows)
    sh("uitest uiInput click %d %d" % (btn[0][1], btn[0][2]))
    time.sleep(1.6)
    rows = dump()
    # ★ 2026-10-26 用「点击前后文字做差」判断 —— 比认关键词可靠
    #   提示文案有好几种：报答案 / 报是-否 / 还没出题 / 这一步算不出来
    # ★ 2026-10-27：长度门槛从 4 降到 2 —— 「顺时针」只有 3 个字，
    #   被 len>=4 过滤掉 ⇒ 齿轮转向被误判成"点了没有任何新文字"
    after = [x[0] for x in rows if x[0] not in before and len(x[0]) >= 2]
    # ★★ 2026-10-27 加：**排除时钟**（假阳性来源）
    #   顶栏的时间每秒在变，做差时会出现 "08, :, 13" 这种文本
    #   ⇒ 实测「网格位移」「镜像描线」都因此被误判成"提示有内容"
    import re as _re
    CLOCK = _re.compile(r'^[\d\s,、:：]+$')
    after = [x for x in after if not CLOCK.match(x)]
    if not after:
        return False, '点了没有任何新文字'
    # ★★ 2026-10-28 加：**优先挑"像提示"的那条**
    #   起因：延迟匹配报「样例亮 1.4 秒 ⇒ … 通关」—— 那是**规则文案**
    #        它碰巧在点击后重排出现，被当成"新文字"
    #   提示的特征词：答案 / 点第 / 选 / 应该 / 下一步 / 一共 / 墨色 / 第 N 行…
    GOOD = ('答案', '点第', '选「', '应该', '下一步', '一共', '墨色', '第',
            '顺时针', '逆时针', '一样', '旧的', '新的', '同一个', '搭档', '是「')
    pick = [x for x in after if any(g in x for g in GOOD)]
    return True, (pick[-1] if pick else after[-1])[:40]


def main():
    args = sys.argv[1:]
    if not args:
        print("用法: python3 工具/verify_batch.py <游戏名> [chip] ...")
        print("      chip 省略 = 全部(228)；也可写 classic/logic/math")
        return
    chips = {'classic': CHIP_CLASSIC, 'logic': CHIP_LOGIC, 'math': CHIP_MATH, 'all': CHIP_ALL}
    results = load()
    # 解析参数：名字在前，chip 词跟在它后面
    jobs, cur = [], CHIP_ALL
    for a in args:
        if a in chips:
            cur = chips[a]
        else:
            jobs.append((a, cur))
            cur = CHIP_ALL
    if not ensure_app():
        print("🔴 调不起 App，先手动确认模拟器状态")
        return
    # ★ 2026-10-26 --hint 模式：验提示（进游戏 → 点提示 → 看弹不弹答案）
    hint_mode = ('--hint' in args)
    hint_jobs = [n for n, c in jobs if n != '--hint']
    if hint_mode:
        for name in hint_jobs:
            print("\n══ %s ══" % name)
            ok, ev = check_hint(name)
            print("     %s %s" % ('✅' if ok else '🔴', ev))
        return
    for name, chip in jobs:
        print("\n══ %s ══" % name)
        status, ev = verify_one(name, chip)
        mark = {'pass': '✅', 'fail': '🔴 没通关', 'notfound': '🔴 列表里没找到',
                'nobutton': '🔴 没有代打按钮', 'wronggame': '🔴 进错游戏',
                'noapp': '🔴 App 调不起来'}[status]
        print("   %s %s" % (mark, ev))
        results[name] = {'status': status, 'evidence': ev, 'at': time.strftime('%Y-%m-%d %H:%M')}
        save(results)
    ok = sum(1 for v in results.values() if v['status'] == 'pass')
    print("\n  ══ 累计：验过 %d 款 / 共试过 %d 款" % (ok, len(results)))
    return len(results) - ok

if __name__ == '__main__':
    # ★★★ 2026-11-03（第 1123 轮）**真机验证器必须有失败退出码**（判据 423）
    #   原来 main() 跑完就结束 ⇒ 即使「失败 N 款」也退 0
    #   ⇒ 而这是**目标里点名的验证器**（'代打/提示真机验 355 款' 靠它出证据）
    #   ⇒ 它永远退 0 ⇒ 那份证据在自动化里无法复现、失败不会报警
    # ★★★ 2026-11-03（第 1124 轮）**崩溃与判定失败用不同退出码**（判据 428）
    #   0 = 合格 ｜ 1 = 检测到不合格 ｜ 2 = 脚本异常
    try:
        rc = main()
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
    if '--lenient' in sys.argv:
        sys.exit(0)
    sys.exit(1 if (rc or 0) > 0 else 0)
