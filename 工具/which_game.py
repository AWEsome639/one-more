#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
which_game.py —— 「我改的到底是屏幕上这一款吗？」

★★★ 起因（2026-10-30，第 540 轮）：我在 GCryptogram.ets 上改了六轮布局，
    屏幕上那一款其实是 GCryptogramAll.ets（`密文进阶` = id `cryptogram_all`）。
    六轮十几次 build 全部「完全无效」，因为改的组件根本没被渲染。
    ⇒ 这个脚本就是那次事故的产物：**动手前先查清楚文件是哪个。**

用法：
    python3 工具/which_game.py 密文进阶
    python3 工具/which_game.py 数独
    python3 工具/which_game.py --list          # 列出全部 id → 组件 → 文件
    python3 工具/which_game.py --fuzzy 密文     # 模糊搜索（找不到时用）

输出四件事：
    ① 注册表里的 id / 中文名 / 英文名
    ② 对应的组件类名（GameHost.ets 里 `if (gameId === 'x') { GX(...) }`）
    ③ 组件所在的 .ets 文件（**这才是你该改的文件**）
    ④ 同名近似文件（提醒你别改错 —— 比如 GCryptogram vs GCryptogramAll）
"""
import io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
HOST = os.path.join(ROOT, 'entry/src/main/ets/pages/GameHost.ets')
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')


def load_registry():
    """从 GameRegistry 抓 id / name / enName"""
    src = io.open(REG, encoding='utf-8').read()
    out = []
    # ⚠️ 不要要求 enName 必须存在 —— 有一条没有它就整体少一条（实测 355 → 354）
    # 分两步：先按 id 切块，再在块里找 name / enName（找不到给空串）
    blocks = re.split(r"\{\s*id:\s*'", src)[1:]
    for b in blocks:
        mid = re.match(r"([^']+)'", b)
        if not mid:
            continue
        chunk = b[:1200]
        mn = re.search(r"name:\s*'([^']*)'", chunk)
        me = re.search(r"enName:\s*'([^']*)'", chunk)
        out.append({
            'id': mid.group(1),
            'name': mn.group(1) if mn else '',
            'en': me.group(1) if me else '',
        })
    return out


def load_host_map():
    """从 GameHost 抓 id → 组件类名"""
    src = io.open(HOST, encoding='utf-8').read()
    out = {}
    for m in re.finditer(
            r"gameId\s*===\s*'([^']+)'\s*\)\s*\{[\s\S]{0,400}?\n\s*(G\w+)\(",
            src):
        out.setdefault(m.group(1), m.group(2))
    return out


def component_file(cls):
    """组件类名 → 文件路径（在 games/ 下按文件名匹配）"""
    cands = []
    if not os.path.isdir(GAMES):
        return cands
    for f in os.listdir(GAMES):
        if not f.endswith('.ets'):
            continue
        p = os.path.join(GAMES, f)
        try:
            s = io.open(p, encoding='utf-8').read()
        except Exception:
            continue
        if re.search(r'(struct|class)\s+' + re.escape(cls) + r'\b', s):
            cands.append(f)
    return cands


def similar_files(cls):
    """名字相近的文件（提醒别改错）"""
    if not os.path.isdir(GAMES):
        return []
    base = cls
    return [f for f in os.listdir(GAMES)
            if f.endswith('.ets') and f[:-4] != base
            and (f[:-4].startswith(base) or base.startswith(f[:-4]))]


def show_changed():
    """--changed：列出工作区里改过的游戏文件，并反查它属于哪款游戏
    ★ 这就是「改错文件」的直接解药：
      改完先跑一次，确认「我改的文件 → 确实是我以为的那款游戏」。"""
    import subprocess
    try:
        out = subprocess.run(['git', 'status', '--porcelain'],
                             cwd=ROOT, capture_output=True, text=True).stdout
    except Exception as e:
        print('git 调用失败：%s' % e)
        return
    files = [l[3:].strip() for l in out.splitlines() if l.strip()]
    games = [f for f in files if '/games/' in f and f.endswith('.ets')]
    if not games:
        print('✅ 工作区没有改动的游戏文件')
        return

    reg = load_registry()
    host = load_host_map()
    # 组件类 → id
    cls_to_ids = {}
    for r in reg:
        cls = host.get(r['id'])
        if cls:
            cls_to_ids.setdefault(cls, []).append(r)
    # id → 组件类
    id_to_cls = host

    print('══ 工作区里改过的游戏文件 → 属于哪款游戏 ══')
    for f in games:
        base = os.path.basename(f)[:-4]
        owners = cls_to_ids.get(base, [])
        print()
        print('  %s' % f)
        if owners:
            for r in owners:
                print('    → %s（id=%s, en=%s）' % (r['name'], r['id'], r['en']))
            print('    ✅ 组件类 %s 在注册表里，会被渲染' % base)
        else:
            print('    ⚠️ 组件类 `%s` 在 GameHost 的 id 映射里没找到' % base)
            print('       ⇒ 可能：(a) 这类是共享组件不是游戏 (b) 名字拼错 (c) 需要新注册')
    print()
    print('  ★ 提醒：改完先跑 `python3 工具/which_game.py <游戏名>` 核对一遍，')
    print('    确认「我改的文件」=「屏幕上那一款」。第 540 轮的六轮白工就是这么来的。')


def main():
    args = [a for a in sys.argv[1:] if a]
    if not args or args[0] in ('-h', '--help'):
        print(__doc__)
        return

    reg = load_registry()
    host = load_host_map()

    if args[0] == '--changed':
        show_changed()
        return

    if args[0] == '--list':
        print('%-22s %-14s %-24s %s' % ('id', '中文名', '组件', '文件'))
        print('-' * 92)
        for r in reg:
            cls = host.get(r['id'], '?')
            fs = component_file(cls) if cls != '?' else []
            print('%-22s %-14s %-24s %s' % (r['id'], r['name'], cls, ', '.join(fs) or '?'))
        print('\n共 %d 款' % len(reg))
        return

    q = args[-1]
    fuzzy = '--fuzzy' in args
    hits = [r for r in reg
            if (q in r['name'] or q == r['id'] or q.lower() == r['en'].lower())
            or (fuzzy and q in r['name'])]

    if not hits:
        print('❌ 没找到「%s」' % q)
        near = [r for r in reg if any(c in r['name'] for c in q)]
        if near:
            print('   相近的：' + '、'.join('%s(%s)' % (r['name'], r['id']) for r in near[:8]))
        print('   试试：python3 工具/which_game.py --fuzzy %s' % q)
        return

    for r in hits:
        cls = host.get(r['id'], '?')
        files = component_file(cls) if cls != '?' else []
        print('═' * 62)
        print('  id      : %s' % r['id'])
        print('  中文名  : %s' % r['name'])
        print('  英文名  : %s' % r['en'])
        print('  组件类  : %s' % cls)
        print('  ★ 文件  : %s' % (', '.join(files) if files else '⚠️ 没找到（检查组件名）'))
        sib = similar_files(cls)
        if sib:
            print('  ⚠️ 近似 : %s' % ', '.join(sib))
            print('           ⇒ 别改错！`%s` 才是上面那个 id 对应的。' % (files[0] if files else cls))
        print()


if __name__ == '__main__':
    main()
