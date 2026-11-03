#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
355 款游戏全量真机冒烟测试
------------------------------------------------------------------
设计原则（都是从这 40 轮踩的坑里总结的）：
  1. 每步先 dump 确认在哪页，绝不靠固定坐标硬点
  2. 结果写 JSONL，随时可续跑（已有的跳过）
  3. 每款记录：进入耗时 / 节点数 / 首屏文本 / 是否崩溃 / 是否空白
  4. 不调 pkill，不碰模拟器生命周期（启动/关闭由外面那层管）

用法：
  python3 smoke_355.py [--limit N] [--from-id xxx] [--list-only]
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
DEV = '127.0.0.1:5555'
OUT = '/Users/a0000/dev/yiju/验收截图-v1.0.1/smoke355.jsonl'
OUT2 = OUT  # 可被 --out 覆盖
NAMES = '/tmp/gamenames.json'
PKG = 'com.andrewoscar.onemore'


def sh(cmd, timeout=25):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return (r.stdout or '').strip()
    except subprocess.TimeoutExpired:
        return ''


def shell(cmd, timeout=25):
    return sh('%s -t %s shell %s' % (HDC, DEV, json.dumps(cmd)), timeout)


def dump(tmp='/data/local/tmp/smoke.json'):
    """dump 布局并拉回来，返回 (节点列表, 是否成功)"""
    shell('uitest dumpLayout -p %s' % tmp)
    local = '/tmp/smoke_local.json'
    if os.path.exists(local):
        try:
            os.remove(local)
        except OSError:
            pass
    sh('%s -t %s file recv %s %s' % (HDC, DEV, tmp, local), timeout=30)
    if not os.path.exists(local):
        return [], False
    try:
        with open(local, encoding='utf-8') as f:
            d = json.load(f)
    except Exception:
        return [], False
    out = []

    def w(n):
        if isinstance(n, dict):
            a = n.get('attributes') or {}
            t = a.get('text') or ''
            b = a.get('bounds') or ''
            if t:
                m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
                if m:
                    x1, y1, x2, y2 = [int(g) for g in m.groups()]
                    out.append((t, (x1 + x2) // 2, (y1 + y2) // 2, x1, y1, x2, y2))
            for c in (n.get('children') or []):
                w(c)
    w(d)
    return out, True


def tap(x, y):
    shell('uitest uiInput click %d %d' % (x, y))


def swipe(x1, y1, x2, y2, ms=600):
    shell('uitest uiInput swipe %d %d %d %d %d' % (x1, y1, x2, y2, ms))


def app_alive():
    o = shell('ps -ef | grep onemore | grep -v grep')
    return len([l for l in o.split('\n') if l.strip()]) > 0


def restart_app():
    shell('aa force-stop %s' % PKG)
    time.sleep(1)
    shell('aa start -b %s -a EntryAbility' % PKG)
    time.sleep(6)


def texts(nodes):
    return [t for (t, *_rest) in nodes]


def on_games_list(nodes):
    t = texts(nodes)
    return ('游戏' in t or 'Games' in t) and ('统计' in t or 'Stats' in t)


def on_game_page(nodes, name):
    t = texts(nodes)
    if name in t:
        return True
    # 有些游戏标题和注册名不完全一致，退而求其次看有没有返回箭头 + 难度
    return ('‹' in t) and ('重开' in t or '重新开始' in t or 'Restart' in t)


def main():
    args = sys.argv[1:]
    limit = None
    start_from = None
    enter_only = False
    want_text = None
    pre_click = None
    list_only = False
    i = 0
    while i < len(args):
        if args[i] == '--limit':
            limit = int(args[i + 1]); i += 2
        elif args[i] == '--from-id':
            start_from = args[i + 1]; i += 2
        elif args[i] == '--enter-only':
            enter_only = True; i += 1
        elif args[i] == '--want-text':
            want_text = args[i + 1]; i += 2
        elif args[i] == '--pre-click':
            # ★ 2026-10-23：进列表后先点一下这个坐标（通常是分类 chip）
            #   重名游戏（数字华容道共有两款）靠分类区分：
            #   3×3 在「逻辑」，4×4 在「经典」。
            parts = args[i + 1].split(',')
            pre_click = (int(parts[0]), int(parts[1])); i += 2
        elif args[i] == '--list-only':
            list_only = True; i += 1
        else:
            i += 1

    # ★★★ 2026-10-23 修：原来直接读 /tmp/gamenames.json，
    #   但那是临时产物（重启/清理就没了），一缺就 FileNotFoundError。
    #   ⇒ 缺了就当场从 GameRegistry 重建，不让脚本依赖一个临时文件。
    #   ⚠️ 格式必须是 [[gid, name], ...] 列表 —— 字典会报
    #      "too many values to unpack"（踩过）
    if not os.path.exists(NAMES):
        import re
        reg = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           'entry/src/main/ets/core/GameRegistry.ets')
        src = open(reg, encoding='utf-8').read()
        pairs = re.findall(r"id:\s*'([^']+)',\s*name:\s*'([^']+)'", src)
        json.dump([[g, n] for g, n in pairs], open(NAMES, 'w', encoding='utf-8'), ensure_ascii=False)
        print('  （gamenames.json 缺失，已从 GameRegistry 重建 %d 条）' % len(pairs))
    games = json.load(open(NAMES, encoding='utf-8'))
    if start_from:
        idx = [n[0] for n in games].index(start_from)
        games = games[idx:]
    # ★ 注意：--limit 不是"取前 N 个"，是"测满 N 个就停"
    #   因为列表显示顺序 ≠ 源码顺序（实测列表头是「数学迷宫」，而源码第一个是「宝石迷阵」）

    global OUT
    for _i, a in enumerate(args):
        if a == '--out':
            OUT = args[_i + 1]
            break

    done = {}
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8') as f:
            for line in f:
                try:
                    r = json.loads(line)
                    done[r['id']] = r
                except Exception:
                    pass
    todo = [(gid, nm) for gid, nm in games if gid not in done]
    # ★ --enter-only 时只跑指定的那一款（--from-id 原本只决定从哪个位置开始找，
    #   实际还是会点屏幕上任意可见的游戏 ⇒ 会进错款）
    if enter_only and start_from:
        todo = [(gid, nm) for gid, nm in todo if gid == start_from]
    print('  总 %d 款 ｜ 已测 %d ｜ 待测 %d' % (len(games), len(done), len(todo)))
    if list_only:
        return

    fout = open(OUT, 'a', encoding='utf-8')
    ok = fail = 0

    print('  [1] 重置分类', flush=True)
    # 先把分类筛成「全部」—— 上次退出时可能停在某个分类里
    for _ in range(3):
        nodes0, ok0 = dump()
        if not ok0:
            restart_app(); continue
        if on_games_list(nodes0):
            hit = [n for n in nodes0 if ('全部' in n[0]) and n[2] < 400]
            if hit:
                tap(hit[0][1], hit[0][2]); time.sleep(1.2)
            break
        shell('uitest uiInput keyEvent Back'); time.sleep(1.2)

    print('  [2] 回列表', flush=True)
    # 回到游戏列表并滚到顶
    for _ in range(8):
        nodes, okd = dump()
        if not okd:
            restart_app(); continue
        if on_games_list(nodes):
            break
        shell('uitest uiInput keyEvent Back')
        time.sleep(1.5)
    else:
        restart_app()
    print('  [3] 滚到顶（看见 One More 标题就停）', flush=True)
    # ★ 别硬滚固定次数：hdc 每次调用约 3 秒，30 下就是 90 秒（实测卡在这里）
    #   ⇒ 改成边滚边判断，到顶就停
    for _i in range(14):
        nd, k = dump()
        if not k:
            continue
        if any('One More' == t.strip() for (t, *_r) in nd):
            break
        swipe(660, 650, 660, 1950, 250)
    if pre_click:
        print('  [3.5] 先点一下 (%d,%d) —— 通常是分类 chip' % pre_click, flush=True)
        tap(pre_click[0], pre_click[1])
        time.sleep(1.5)
    print('  [4] 开始主循环', flush=True)

    # ★ 关键：待测集合必须用【名字】当 key —— 屏幕上认的是名字，不是 gameId
    #   （之前写成 {gid: nm} 然后拿名字去查，永远查不到，白跑两轮）
    remaining = {}            # name -> gid
    for gid, nm in todo:
        remaining[nm] = gid

    processed = set()
    stuck = 0
    # ★★★ 2026-10-29（lead）：**停滞护栏**
    #   症状：回归报「剩 355 ｜ stuck 一路涨」，一款都没找到 —— 实测查出来是
    #         App 被切到后台（或卡在开屏），而脚本只是在原地重启，没强复位。
    #   ⇒ 只数「剩余数连续 N 轮没变」：一旦超过 6 轮，强制 restart + 回列表。
    #   不靠 stuck（stuck 每轮都可能涨，分辨不出「在动」和「没动」）。
    stall_guard = 0
    last_remaining = -1
    loop_n = 0
    while remaining and stuck < 200:
        loop_n += 1
        print('  [loop %d] 剩 %d ｜ stuck %d' % (loop_n, len(remaining), stuck), flush=True)
        # ★★★ 停滞护栏（2026-10-29 第二版）
        #   ⚠️ 第一版是「剩余数连续 6 轮不变就重启 App」——
        #      **那是错的**：滚动列表找卡片时，剩余数本来就不会变！
        #      重启又把滚动位置归零 ⇒ 永远滚不到卡片区 ⇒ 死循环（我亲手造的）
        #   ⇒ 正解：**只在「不在游戏列表」或「App 不在前台」时才重启**，
        #      「在列表里滚动」是正常行为，不能当停滞。
        if len(remaining) == last_remaining and not on_list:
            stall_guard += 1
            if stall_guard >= 6:
                print('  ⚠️ 连续 %d 轮既没进展又不在列表 ⇒ 强制重启 App' % stall_guard, flush=True)
                restart_app()
                time.sleep(6)
                stall_guard = 0
        else:
            stall_guard = 0
            last_remaining = len(remaining)
        nodes, okd = dump()
        on_list = okd and on_games_list(nodes)
        if not okd:
            print('     dump 失败，重启 app')
            restart_app()
            stuck += 1
            continue
        if not app_alive():
            print('     app 崩了，重启')
            restart_app()
            stuck += 1
            continue
        if not on_games_list(nodes):
            shell('uitest uiInput keyEvent Back')
            time.sleep(1.2)
            stuck += 1
            continue

        visible = []
        # ★★★ 2026-10-29（lead）：诊断打印 —— 不再猜，直接看脚本看到了什么
        if os.environ.get('SMOKE_DEBUG'):
            allt = texts(nodes)
            print('     [SEE] 屏幕 %d 条文字 ｜ remaining 样例 %s' %
                  (len(allt), list(remaining.keys())[:4]), flush=True)
            print('     [SEE] 前 12 条: %s' % allt[:12], flush=True)
        for (t, cx, cy, x1, y1, x2, y2) in nodes:
            if t in remaining and 300 < cy < 1980:   # 列表区（顶栏下方、底栏上方）
                visible.append((t, cx, cy))

        if not visible:
            print('       本屏无目标款，滚一屏', flush=True)
            # ★ 2026-10-29 修：原来 (660,1750)→(660,800) 600ms **滚不动**；
            #   实测 (660,1900)→(660,600) 500ms 有效（起止更靠边、时间更短）
            swipe(660, 1900, 660, 600, 500)
            time.sleep(1.0)
            stuck += 1
            if stuck > 190:
                # 真的滚到头了（200 屏都找不到）⇒ 剩下的确实不在列表里
                print('     滚了 190 屏仍找不到，剩 %d 款' % len(remaining))
                break
            continue

        stuck = 0
        if limit and (ok + fail) >= limit:
            break
        for (nm, cx, cy) in visible:
            gid = remaining.pop(nm, None)
            if gid is None:
                continue
            t0 = time.time()
            tap(cx, cy)
            time.sleep(0.9)
            info = {'id': gid, 'name': nm}
            # 轮询直到进入或超时
            entered = False
            for _ in range(8):
                nd, k = dump()
                if not k:
                    continue
                if on_game_page(nd, nm):
                    entered = True
                    info['nodes'] = len(nd)
                    info['first'] = texts(nd)[:8]
                    break
                time.sleep(0.5)
            info['enter_s'] = round(time.time() - t0, 1)
            info['entered'] = entered
            if not entered:
                info['nodes'] = 0
                info['first'] = []
                info['error'] = 'enter_timeout'
                fail += 1
                print('     🔴 %-22s 进不去（%.1fs）' % (nm[:22], info['enter_s']))
                restart_app()
            else:
                ok += 1
                print('     ✅ %-22s %d 节点（%.1fs）' % (nm[:22], info['nodes'], info['enter_s']))
                if enter_only:
                    # ★ 2026-10-23：重名游戏（如「数字华容道」有两款）按名字会选错。
                    #   加 --want-text：进入后校验页面里有没有这段文字，
                    #   没有就退回、把这张卡跳过，继续找下一张同名的。
                    if want_text and not any(want_text in t for t in texts(nd)):
                        print('     ↪ 「%s」页面里没有「%s」，不是要验的那款，退回再找' % (nm, want_text))
                        shell('uitest uiInput keyEvent Back')
                        time.sleep(1.0)
                        processed.add(gid)
                        ok -= 1
                        continue
                    print('     ⏸ --enter-only：已进入「%s」，停在这里（不退出来）' % nm)
                    fout.write(json.dumps(info, ensure_ascii=False) + '\n')
                    fout.flush()
                    return
            fout.write(json.dumps(info, ensure_ascii=False) + '\n')
            fout.flush()
            processed.add(gid)
            if limit and (ok + fail) >= limit:
                print('     已达 --limit %d，停' % limit)
                break
            shell('uitest uiInput keyEvent Back')
            time.sleep(1.0)
            # 确认回到列表
            nd2, k2 = dump()
            if not k2 or not on_games_list(nd2):
                restart_app()
                for _ in range(12):
                    swipe(660, 700, 660, 1900, 400)
                    time.sleep(0.3)
                # 滚回去难，直接退出本屏继续
                break

    fout.close()
    print('\n  本轮：成功 %d ｜ 失败 %d ｜ 总已测 %d' % (ok, fail, len(done) + ok + fail))
    # ★ 判据 423：把失败数返回给 __main__，让退出码能反映结果
    return fail


if __name__ == '__main__':
    # ★★★ 2026-11-03（第 1122 轮）**冒烟测试必须有失败退出码**（判据 423）
    #   原来 main() 跑完就结束 ⇒ 即使「失败 N 款」也返回 0
    #   ⇒ 在自动化里它永远不会报警，只是"打印了一行失败数"
    rc = main()
    if '--lenient' in sys.argv:
        sys.exit(0)
    sys.exit(1 if (rc or 0) > 0 else 0)
