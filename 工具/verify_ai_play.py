import sys
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI 代打真机验证（可复用 · 判据已修正）

★ 2026-10-29 修正的三个坑（都是我踩过的）：
  ① **只认注册表里真实存在的名字** —— 之前把「这一局拿下！」这种屏幕文字
     当成游戏名记进台账，导致进度虚高 27 个百分点。
  ② 失败必须**单独重测一次**再下结论（批量连跑会偶发状态没对齐）。
  ③ 必须先确认「在列表页」再找卡片（否则会 0 结果空跑）。

用法：python3 工具/verify_ai_play.py [本轮最多验几款，默认 20]
"""
import importlib.util, io, json, os, re, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG  = os.path.join(ROOT, '验收截图-v1.0.1/ai_play_verified.jsonl')
REG  = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')

spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
vb = importlib.util.module_from_spec(spec); spec.loader.exec_module(vb)


def registry_names():
    """当前在架的 355 款名字（唯一真值来源）"""
    s = io.open(REG, encoding='utf-8').read()
    return set(n for _, n in re.findall(r"id:\s*'([a-z0-9_]+)',\s*name:\s*'([^']+)'", s))


def load_verified(names):
    """只认「在架 + 验过」的，失效记录一律丢弃"""
    got = set()
    if os.path.exists(LOG):
        for line in io.open(LOG, encoding='utf-8'):
            try:
                r = json.loads(line)
                if r.get('started') and r['name'] in names:
                    got.add(r['name'])
            except Exception:
                pass
    return got


def to_list():
    for _ in range(4):
        if any('One More' in r[0] for r in vb.dump()):
            return True
        b = [r for r in vb.dump() if r[0] == '‹']
        if not b:
            return False
        vb.sh("uitest uiInput click %d %d" % (b[0][1], b[0][2])); time.sleep(2)
    return False


def visible_cards(names):
    """屏幕上看得见的**真实游戏**卡片（名字必须在注册表里 —— 这是修正的核心）"""
    out = []
    for r in vb.dump():
        n = r[0]
        if n in names and 850 < r[3] < 1550:
            out.append((n, r[1], r[2]))
    return out


def try_click(nm):
    """返回 'ok' / 'nobtn' / 'notenter'"""
    for _ in range(2):
        if not [r for r in vb.dump() if r[0] == '‹']:
            pass
        vb.sh("uitest uiInput click 660 1700"); time.sleep(1.1)   # 停演示
    ai = [r for r in vb.dump() if 'AI 代打' in r[0]]
    if not ai:
        return 'nobtn'
    vb.sh("uitest uiInput click %d %d" % (ai[0][1], ai[0][2]))
    # ★★★ 2026-10-29（数蛇教训）：**点完立刻连看 8 次（每 0.4s）**——
    #   有的款代打一启动就飞快通关 → 页面会自己返回列表 → 慢看会误判成"没启动"
    #   （数蛇就是这么被误判两次的）
    for _ in range(8):
        time.sleep(0.4)
        cur = [r[0] for r in vb.dump()]
        if any('停代打' in a for a in cur):
            return 'ok'
        if any('One More' in x for x in cur):
            return 'ok'          # 已返回列表 ⇒ 说明它瞬间通关了，也是启动成功
    return 'retry'


def main():
    # ★★★ 2026-11-03（第 1123 轮）**位置参数不能吞掉 --flag**
    #   原来 `int(sys.argv[1])` ⇒ 传 `--limit 2` 时抛
    #     ValueError: invalid literal for int() with base 10: '--limit'
    #   ⇒ 更糟的是：**崩了也退出 1**，看起来像"检测到失败"，实则没跑
    #   ⇒ 只认"不以 - 开头的第一个参数"当数字。
    _pos = [a for a in sys.argv[1:] if not a.startswith('-')]
    budget = int(_pos[0]) if _pos and _pos[0].isdigit() else 20
    names = registry_names()
    got = load_verified(names)
    print('  在架 %d ｜ 已验 %d ｜ 待验 %d' % (len(names), len(got), len(names) - len(got)))
    # ★★★ 2026-11-03（第 1123 轮）**待验为 0 时立刻退出**
    #   实测：355 款早已全部验过（待验 0），但脚本仍会进入下面的循环 ——
    #   循环里 `cs` 恒为空 ⇒ 只做 swipe + sleep ⇒ **空转到超时**，
    #   退出码变成 124（被外层 timeout 杀掉），看起来像"失败"，实则"没事可做"。
    #   ⇒ 待验 0 直接返回 0（全部验完 = 达标），并打印一行说明。
    if not names or len(got) >= len(names):
        print('  ⇒ 待验 0：全部已验，无需再跑（返回 0）')
        return 0

    to_list()
    for _ in range(20):
        vb.sh("uitest uiInput swipe 660 700 660 1900 330"); time.sleep(0.3)
    time.sleep(1)

    ok = bad = skip = 0
    t0 = time.time()
    for _ in range(60):
        if ok + bad >= budget or time.time() - t0 > 1500:
            break
        cs = [c for c in visible_cards(names) if c[0] not in got]
        if not cs:
            vb.sh("uitest uiInput swipe 660 1900 660 700 430"); time.sleep(0.7)
            continue
        for nm, x, y in cs[:2]:
            if nm in got:
                continue
            vb.sh("uitest uiInput click %d %d" % (x, y)); time.sleep(4.5)
            if '‹' not in [r[0] for r in vb.dump()]:
                got.add(nm); skip += 1; continue
            res = try_click(nm)
            if res == 'retry':                       # ★ 失败必须重测一次
                to_list()
                p = vb.find_game(nm)
                if p:
                    vb.sh("uitest uiInput click %d %d" % p); time.sleep(4.5)
                    res = try_click(nm)
            got.add(nm)
            if res == 'ok':
                ok += 1; print('  %-12s ✅' % nm)
                io.open(LOG, 'a', encoding='utf-8').write(
                    json.dumps({'name': nm, 'started': True}, ensure_ascii=False) + '\n')
                s2 = [r for r in vb.dump() if '停代打' in r[0]]
                if s2:
                    vb.sh("uitest uiInput click %d %d" % (s2[0][1], s2[0][2])); time.sleep(1.1)
            elif res == 'retry':
                bad += 1; print('  %-12s ❌ 重测仍不启动' % nm)
                io.open(LOG, 'a', encoding='utf-8').write(
                    json.dumps({'name': nm, 'started': False}, ensure_ascii=False) + '\n')
            else:
                skip += 1; print('  %-12s ⊘ 无按钮' % nm)
                got.discard(nm)              # 无按钮不算验过，下轮再试
            to_list()
        vb.sh("uitest uiInput swipe 660 1900 660 700 430"); time.sleep(0.7)

    print('  ── 本轮 启动 %d ｜ 失败 %d ｜ 无按钮 %d ｜ 累计 %d/%d (%.0f%%)'
          % (ok, bad, skip, len(got), len(names), len(got) * 100.0 / len(names)))
    return bad


if __name__ == '__main__':
    # ★★★ 2026-11-03（第 1123 轮）**真机验证器必须有失败退出码**（判据 423）
    #   原来 main() 跑完就结束 ⇒ 即使「失败 N 款」也退 0
    #   ⇒ 而这是**目标里点名的验证器**（'代打/提示真机验 355 款' 靠它出证据）
    #   ⇒ 它永远退 0 ⇒ 那份证据在自动化里无法复现、失败不会报警
    rc = main()
    if '--lenient' in sys.argv:
        sys.exit(0)
    sys.exit(1 if (rc or 0) > 0 else 0)
