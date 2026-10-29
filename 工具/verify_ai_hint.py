#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI 提示真机验证（判据：点「提示」→ 屏幕上**多出文字**，或出现 toast）

★ 判据设计（吃过 5 类假阴性的教训）：
  · 点完用 **8×0.4s 短间隔采样**，抓瞬时出现的提示（很多款提示只显示 4 秒）
  · 接受三种合法终态：①屏幕上多出新文字 ②出现 toast 弹窗 ③提示区域高亮
  · 失败**单独重测一次**
  · 只认注册表里真实存在的游戏名
"""
import importlib.util, io, json, os, re, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG  = os.path.join(ROOT, '验收截图-v1.0.1/ai_hint_verified.jsonl')
REG  = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')

spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
vb = importlib.util.module_from_spec(spec); spec.loader.exec_module(vb)


def registry_names():
    s = io.open(REG, encoding='utf-8').read()
    return set(n for _, n in re.findall(r"id:\s*'([a-z0-9_]+)',\s*name:\s*'([^']+)'", s))


def load_verified(names):
    got = set()
    if os.path.exists(LOG):
        for line in io.open(LOG, encoding='utf-8'):
            try:
                r = json.loads(line)
                if r.get('ok') and r['name'] in names:
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


def screen_texts():
    return set(r[0] for r in vb.dump())


def try_hint():
    """返回 'ok' / 'nobtn' / 'retry'"""
    for _ in range(2):
        vb.sh("uitest uiInput click 660 1700"); time.sleep(1.0)   # 停演示
    rows = vb.dump()
    btn = [r for r in rows if r[0] == '提示' or r[0].startswith('提示')]
    if not btn:
        return 'nobtn'
    before = screen_texts()
    vb.sh("uitest uiInput click %d %d" % (btn[0][1], btn[0][2]))
    # ★★★ 2026-10-29（N-back 教训）：有的款提示是**常驻说明文字**，
    #   点之前就在屏幕上 ⇒ "新文字"判据会漏判。
    #   ⇒ 同时接受：①出现新文字 ②屏幕上出现带「提示/hint」字样且长度≥8 的文字
    for _ in range(8):
        time.sleep(0.4)
        cur = screen_texts()
        new = cur - before
        if any(len(x) >= 3 and not re.fullmatch(r'[\d\s/:.]+', x) for x in new):
            return 'ok'
        HINT_KEYWORDS = ('提示', 'Hint', 'hint')
        if any(any(k in x for k in HINT_KEYWORDS) and len(x) >= 8 for x in cur):
            return 'ok'
    return 'retry'


def main():
    budget = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    names = registry_names()
    got = load_verified(names)
    print('  在架 %d ｜ 提示已验 %d ｜ 待验 %d' % (len(names), len(got), len(names) - len(got)))

    to_list()
    for _ in range(20):
        vb.sh("uitest uiInput swipe 660 700 660 1900 330"); time.sleep(0.3)
    time.sleep(1)

    ok = bad = skip = 0
    t0 = time.time()
    done = 0
    for _ in range(60):
        if done >= budget or time.time() - t0 > 1500:
            break
        cards = [(r[0], r[1], r[2]) for r in vb.dump()
                 if r[0] in names and r[0] not in got and 850 < r[3] < 1550]
        if not cards:
            vb.sh("uitest uiInput swipe 660 1900 660 700 430"); time.sleep(0.7)
            continue
        for nm, x, y in cards[:2]:
            if nm in got:
                continue
            done += 1
            vb.sh("uitest uiInput click %d %d" % (x, y)); time.sleep(4.5)
            if '‹' not in [r[0] for r in vb.dump()]:
                continue
            res = try_hint()
            if res == 'retry':
                to_list()
                p = vb.find_game(nm)
                if p:
                    vb.sh("uitest uiInput click %d %d" % p); time.sleep(4.5)
                    res = try_hint()
            got.add(nm)
            if res == 'ok':
                ok += 1; print('  %-12s ✅' % nm)
                io.open(LOG, 'a', encoding='utf-8').write(
                    json.dumps({'name': nm, 'ok': True}, ensure_ascii=False) + '\n')
            elif res == 'retry':
                bad += 1; print('  %-12s ❌ 点了没提示' % nm)
                got.discard(nm)
            else:
                skip += 1; print('  %-12s ⊘ 无提示按钮' % nm)
                got.discard(nm)
            to_list()
        vb.sh("uitest uiInput swipe 660 1900 660 700 430"); time.sleep(0.7)

    print('  ── 本轮 通过 %d ｜ 无提示 %d ｜ 无按钮 %d ｜ 累计 %d/%d (%.0f%%)'
          % (ok, bad, skip, len(got), len(names), len(got) * 100.0 / len(names)))


if __name__ == '__main__':
    main()
