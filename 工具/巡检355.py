#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★【一局】355 款全量巡检器（2026-10-16 夜建，判据②）

目标：把 355 款【每一款都真的点开一次】并截图存证。
     （旧记录 731 条 ≈ 只覆盖"名称级能显示文字"，不是"真的点开过"）

思路（沉淀了全部工具教训）：
  ① 用【A-Z 视图】+【右侧字母索引】分区 ⇒ 点字母直接跳转，不用盲滚
  ② 行坐标【每次 dump 实测】（铁律 #52：绝不目测）
  ③ 每款：点开 → 截图 → 返回 → 下一款
  ④ 每款立刻落盘（防中断丢进度）+ 支持断点续跑

用法：
    python3 -u 工具/巡检355.py            # 全量
    python3 -u 工具/巡检355.py A B C      # 只跑指定字母
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
OUT = os.environ.get('INSPECT_OUT') or os.path.expanduser('~/dev/yiju/巡检-355-20261016')
LEDGER = os.environ.get('INSPECT_LEDGER') or os.path.expanduser('~/dev/yiju/巡检-355-20261016.json')
# ★★★ 判据③：INSPECT_INTERACT=1 时，每款进游戏后真的点两下，验证还响应
INTERACT = os.environ.get('INSPECT_INTERACT', '0') == '1'
INTERACT_FAIL = os.environ.get('INSPECT_INTERACT_FAIL') or '/tmp/interact-fail.txt'
INSPECT_LIMIT = int(os.environ.get('INSPECT_LIMIT', '0'))
TMP = '/tmp/x355.json'

# ★ 右侧字母索引的两列坐标（dump 实测，铁律 #52）
#   A-L 在左列 x=1215，N-Z 在右列 x=1269；每格 33px，从 y=1593 起
LETTERS_LEFT = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L']
LETTERS_RIGHT = ['N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']
LETTER_X_LEFT = 1215
LETTER_X_RIGHT = 1269
LETTER_Y0 = 1593
LETTER_DY = 33

# ★ A-Z 列表的行区（dump 实测）
ROW_X = 660            # 行中心 x
ROW_Y_TOP = 1600       # 第一行顶部
ROW_PITCH = 156        # 行距（实测：游戏1中心 y≈1697，游戏2≈1853）


def sh(cmd, t=25):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def dump():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/x3.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/x3.json {TMP}', 30)
    try:
        return json.load(open(TMP, encoding='utf-8'))
    except Exception:
        return None


def walk(n, out):
    """★ children 挂在 node 上（铁律 #51 的坑）"""
    if not isinstance(n, dict):
        return
    a = n.get('attributes', n)
    t = (a.get('text') or '') + (a.get('originalText') or '')
    b = a.get('bounds') or ''
    if t and b:
        out.append((t, b))
    for k in ('children', 'nodes'):
        for c in (n.get(k) or []):
            walk(c, out)
        for c in (a.get(k) or []):
            walk(c, out)


def parse_b(b):
    m = re.findall(r'-?\d+', b)
    if len(m) < 4:
        return None
    return int(m[0]), int(m[1]), int(m[2]), int(m[3])


def on_list_page():
    """★★★ 2026-10-17 血泪：原来只靠 rows_now() 判断在不在列表页 ⇒ 纸牌游戏界面
       也有"整行"元素 ⇒ 守卫被骗 ⇒ 卡在「蜘蛛纸牌」10 分钟没动
       ⇒ 改用【强判据】：游戏列表页一定有「全部 · N 款」这行（或 A-Z 胶囊）
    """
    d = dump()
    if not d:
        return False
    els = []
    walk(d, els)
    for t, b in els:
        if '款' in t and ('全部' in t or 'All' in t or 'Tutti' in t or 'Todas' in t):
            return True
        if 'A-Z' in t:
            return True
    return False


def rows_now():
    """★ 读出当前屏【列表区】的游戏行（按 y 排序，去重）
       判据：x 左边界 ≈210 且宽 >800（整行）且 y 在 1560-1990"""
    d = dump()
    if not d:
        return []
    els = []
    walk(d, els)
    rows = []
    for t, b in els:
        pb = parse_b(b)
        if not pb:
            continue
        x1, y1, x2, y2 = pb
        if x1 < 200 or x1 > 260:
            continue
        if (x2 - x1) < 800:
            continue
        if y1 < 1560 or y1 > 1995:
            continue
        rows.append((y1, t.strip()))
    rows.sort()
    # 去重（同名同 y 区间的合并）
    out = []
    for y, t in rows:
        if out and abs(out[-1][0] - y) < 30:
            continue
        out.append((y, t))
    return out


def tap(x, y, wait=1.8):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 20)
    time.sleep(wait)


def shot(name):
    p = os.path.join(OUT, name)
    sh(f'{HDC} shell "snapshot_display -f /data/local/tmp/s.jpeg"', 30)
    sh(f'{HDC} file recv /data/local/tmp/s.jpeg {p}', 30)
    return os.path.exists(p) and os.path.getsize(p) > 20000


def load_ledger():
    try:
        return json.load(open(LEDGER, encoding='utf-8'))
    except Exception:
        return {'done': [], 'fail': [], 'started': time.strftime('%F %T')}


def save_ledger(L):
    L['updated'] = time.strftime('%F %T')
    json.dump(L, open(LEDGER, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


def go_back():
    """★★★ 2026-10-17 修：原来硬编码 tap(104,260)，但游戏页的 ‹ 实测在 (126,279)，
       且有些游戏点过之后页面会变（‹ 位置不同）⇒ 改成【用 dump 找 ‹ 的真实坐标】
       找不到再退回 (126, 279)"""
    d = dump()
    if d:
        out = []
        walk(d, out)
        for t, b in out:
            if '‹' in t:
                m = re.findall(r'-?\d+', b)
                if len(m) >= 4:
                    tap((int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2, wait=2.0)
                    return True
    tap(126, 279, wait=2.0)
    return False


def dismiss_privacy():
    """★★★ 铁律 68：装包后隐私弹窗会吃掉所有点击 ⇒ 开工前先关掉它"""
    d = dump()
    if not d:
        return False
    out = []
    walk(d, out)
    for t, b in out:
        if '同意并继续' in t:
            m = re.findall(r'-?\d+', b)
            if len(m) >= 4:
                tap((int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2, wait=2.5)
                print('  ★ 关掉隐私弹窗', flush=True)
                return True
    return False


def goto_az():
    """确保在 A-Z 视图 + 列表顶部"""
    time.sleep(0.8)


def scan_letter(letter, L):
    """扫描一个字母区：反复『读行 → 点第一款 → 截图 → 返回』直到本区扫完"""
    x = LETTER_X_LEFT if letter in LETTERS_LEFT else LETTER_X_RIGHT
    idx = (LETTERS_LEFT if letter in LETTERS_LEFT else LETTERS_RIGHT).index(letter)
    y = LETTER_Y0 + idx * LETTER_DY
    tap(757, 1459, wait=2.0)      # ★ 先确保在 A-Z 视图
    tap(x, y, wait=2.5)
    n = 0
    stall = 0
    empty = 0
    # ★★★ 2026-10-17 实测：字母跳转不可靠（A 区扫到 B/P/C 混合）
    #   但『读行→点第一款→返回→滚一行』这个【连续走列表】的机制是有效的
    #   ⇒ 把 stall 阈值提到 60：一直往前走直到列表真正走完（重复的靠 done 跳过）
    while stall < 60:
        rows = rows_now()
        if not rows:
            # ★★★ 2026-10-17 血泪：游戏里点返回【有时不生效】⇒ 脚本会卡在游戏里死循环
            #   （实测卡在「变形者」那款，50 秒没动静）
            #   ⇒ 守卫：读不到列表行就【强制重启 App】回到游戏页，再重试；连失 3 次才放弃
            empty += 1
            if empty >= 3 or not on_list_page():
                print('     ⚠️ 连续读不到列表 ⇒ 强制重启 App', flush=True)
                sh(f'{HDC} shell "aa force-stop com.andrewoscar.onemore"', 25)
                time.sleep(2.5)
                sh(f'{HDC} shell "aa start -a EntryAbility -b com.andrewoscar.onemore"', 25)
                time.sleep(8)
                tap(220, 2100, wait=3.0)          # 游戏 tab
                tap(757, 1459, wait=2.5)          # A-Z 视图
                empty = 0
                continue
            if empty >= 6:
                break
            go_back()               # 试着返回
            continue
        y0, name = rows[0]
        # ★ 跳过字母标题行（形如 "BB" 或 "##"）和计数行（"11 款"）
        if re.fullmatch(r'[A-Z#]{1,2}', name) or name.endswith('款'):
            if len(rows) > 1:
                y0, name = rows[1]
            else:
                sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1400 400"', 20)
                time.sleep(1.2)
                continue
        key = name
        if key in L['done']:
            # 已扫过 ⇒ 滚一行
            sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1600 350"', 20)
            time.sleep(1.2)
            empty = 0
            continue
        # 点开这一款（点行中心 x=660）
        tap(ROW_X, y0 + 55, wait=3.0)
        nm = 'X-%03d.jpeg' % (len(L['done']) + len(L['fail']) + 1)
        ok = shot(nm)
        # ★★★ 判据③：真的玩一下 —— 点屏幕中央两下，再验证还能 dump 出节点
        if INTERACT:
            tap(660, 1400, wait=1.4)
            tap(660, 1150, wait=1.0)
            d2 = dump()
            alive = d2 is not None
            if not alive:
                try:
                    with open(INTERACT_FAIL, 'a', encoding='utf-8') as ff:
                        ff.write('%s\n' % key)
                except Exception:
                    pass
                print('     ⚠️ %s（交互后无响应）' % key[:24], flush=True)
        # 返回
        go_back()
        if ok:
            L['done'].append(key)
            print('     ✅ %s → %s' % (key[:26], nm), flush=True)
        else:
            L['fail'].append(key)
            print('     ✗ %s（截图失败）' % key[:26], flush=True)
        n += 1
        stall = 0
        empty = 0
        save_ledger(L)
        # 滚一行（行距 156）
        sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1600 350"', 20)
        time.sleep(1.2)
    return n


def main():
    os.makedirs(OUT, exist_ok=True)
    L = load_ledger()
    # ★★★ 铁律 68：先确认隐私弹窗已关（否则所有点击都被吃掉）
    sh(f'{HDC} shell "aa start -a EntryAbility -b com.andrewoscar.onemore"', 25)
    time.sleep(8)
    for _ in range(3):
        if not dismiss_privacy():
            break
        time.sleep(2)
    want = sys.argv[1:] if len(sys.argv) > 1 else (LETTERS_LEFT + LETTERS_RIGHT)
    # ★★★ 2026-10-17：加 TOP 模式 —— 走「全部字母索引区之前」的部分
    #   （## 数字区 + 最前面几款；点字母索引会跳过它们 ⇒ 实测漏了 8 款）
    if want == ['TOP']:
        print('  ★ TOP 模式：滚到最顶后一路走', flush=True)
        for _ in range(14):
            sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
            time.sleep(0.35)
        time.sleep(1.5)
        n = scan_letter('A', L)
        print('  ★ TOP 模式扫了 %d 款 ｜ 累计 %d' % (n, len(L['done'])))
        save_ledger(L)
        return
    print('  ★ 巡检开始 ｜ 已完成 %d ｜ 目标字母 %s' % (len(L['done']), ' '.join(want)), flush=True)
    tot = 0
    for lt in want:
        print('  ══ 字母 %s' % lt, flush=True)
        tot += scan_letter(lt, L)
        print('     （本区扫了 %d 款 ｜ 累计 %d）' % (tot, len(L['done'])), flush=True)
    print()
    print('  ★ 完成 %d 款 ｜ 失败 %d 款' % (len(L['done']), len(L['fail'])))
    save_ledger(L)


if __name__ == '__main__':
    main()
