#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
355 款「聪明度」审计（2026-10-23 第二期）

问题：奥森说「让 355 款游戏都变得聪明」。
      但哪几款真的"不聪明"？凭我逐个猜会漏，也容易重复造。
⇒ 先扫一遍，用数据决定先做什么。

四个维度（只判有/无，不吹质量）：
  A 有 AI 对手    aiPick / aiTurn / chooseMove / minimax / MCTS
  B 有提示        import ai/Hint  或  一个「提示」按钮
  C 难度真的作用到玩法   GameDiff 不是只取一处（sizeNow/livesNow/pick 里挑玩法参数）
  D 会自己出题     shuffle / gen / randomBoard（有出题器说明不是死题）

为什么这四个：
  A 管对抗类 —— 没有 AI 的对抗游戏 = 只能单人/联机
  B 管解谜类 —— 没有提示的谜题 = 卡住只能干瞪眼
  C 管所有类 —— 难度只改尺寸/时间不算"聪明"，要改玩法参数
  D 管耐玩   —— 死题玩两次就记住
"""
import io, os, re, sys, json

ROOT = '/Users/a0000/dev/yiju'
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')

def scan():
    s = io.open(REG, encoding='utf-8').read()
    # id → (name, category)
    recs = re.findall(r"id:\s*'([^']+)',\s*name:\s*'([^']+)',[^\n]*?category:\s*GameCategory\.([A-Z]+)", s)
    out = {}
    for gid, name, cat in recs:
        out[gid] = {'name': name, 'cat': cat}
    return out

# id → 文件名的映射靠约定：id 的驼峰形式；直接按内容匹配搜索
def find_file(gid, game_files):
    # 先试直接拼
    cands = [gid.replace('-', '').replace('_', '')]
    for f in game_files:
        pass
    return None

# ⚠️ 第一版漏了 aiBest / search —— 结果把已经加了 AI 的跳棋报成"没有 AI"。
#    教训：用关键词判断"有没有某功能"时，必须先去代码里核一遍真实函数名，
#    否则量出来的是我的词表，不是代码。
AI_PAT = re.compile(r'\b(aiPick|aiTurn|aiMove|aiBest|chooseMove|bestMove|minimax|mcts|MCTS|computerMove|pickAi|search\()')
# ⚠️ 第一版只认 askHint / computeHint / ai\/Hint，漏掉了大量"自己的提示"：
#    比如 24 点用的是 hint()，还有 useTip / showTip / tipBtn 这类命名。
#    ⇒ 结果把"MATH 59 款 0 提示"报了出来，实际 24 点早就做得不错。
#    ⇒ 教训：用关键词判断"有没有某功能"时，关键词表要覆盖多种命名习惯。
HINT_PAT = re.compile(
    r"(ai/Hint|TG\('提示'\)|'提示'|askHint|computeHint|\bhint\s*\(|useHint|showHint|"
    r"hintTap|tipBtn|\btip\s*=)"
)
DIFF_PAT = re.compile(r'GameDiff\.(sizeNow|livesNow|pick|now|of)')
GEN_PAT = re.compile(r'\b(shuffle|shuffled|newPuzzle|generate|genPuzzle|randomBoard|makePuzzle)\b')

def main():
    regs = scan()
    files = sorted(f for f in os.listdir(GAMES) if f.endswith('.ets') and '.bak' not in f)
    # 建立「文件名 → 内容」
    contents = {}
    for f in files:
        contents[f] = io.open(os.path.join(GAMES, f), encoding='utf-8', errors='ignore').read()

    # 为每个注册项找对应文件：拿游戏名去内容里找
    rows = []
    used = set()
    for gid, info in regs.items():
        name = info['name']
        hit = None
        for f, txt in contents.items():
            if f in used:
                continue
            if ("'" + name + "'") in txt or ('"' + name + '"') in txt:
                hit = f
                break
        if hit is None:
            # 退回：按 id 猜文件名，外加几条已知特例
            SPECIAL = {'g2048': 'GGame2048.ets', 'game24': 'GGame24.ets',
                       'life_game': 'GLifeGame.ets', 'slide15': 'GSlide15.ets'}
            guess = SPECIAL.get(gid)
            if guess is None:
                guess = 'G' + ''.join(w.capitalize() for w in re.split(r'[-_]', gid)) + '.ets'
            hit = guess if guess in contents else None
        if hit:
            used.add(hit)
        txt = contents.get(hit, '') if hit else ''
        rows.append({
            'id': gid, 'name': name, 'cat': info['cat'], 'file': hit or '-',
            'ai': bool(AI_PAT.search(txt)),
            'hint': bool(HINT_PAT.search(txt)),
            'diff': bool(DIFF_PAT.search(txt)),
            'gen': bool(GEN_PAT.search(txt)),
            'lines': txt.count('\n') + 1 if txt else 0,
        })

    print('  ══ 共审计 %d 款（注册表 %d 项，匹配到文件 %d 个）'
          % (len(rows), len(regs), len([r for r in rows if r['file'] != '-'])))
    print()
    # 按类别汇总
    from collections import Counter, defaultdict
    bycat = defaultdict(list)
    for r in rows:
        bycat[r['cat']].append(r)
    print('  %-9s %4s %6s %6s %6s %6s' % ('类别', '数量', '有AI', '有提示', '难度入玩法', '有出题'))
    for cat in ('CLASSIC', 'LOGIC', 'MATH', 'MEMORY', 'WORD', 'SPATIAL'):
        rs = bycat.get(cat, [])
        if not rs:
            continue
        n = len(rs)
        print('  %-9s %4d %6d %6d %6d %6d' % (
            cat, n,
            sum(1 for r in rs if r['ai']),
            sum(1 for r in rs if r['hint']),
            sum(1 for r in rs if r['diff']),
            sum(1 for r in rs if r['gen']),
        ))
    print()
    # 具体缺口
    print('  ══ 对抗类里没有 AI 的（真缺口）：')
    miss_ai = [r for r in rows if r['cat'] == 'CLASSIC' and not r['ai']]
    for r in miss_ai[:20]:
        print('     %-14s %-20s %s 行' % (r['id'][:14], r['name'][:20], r['lines']))
    print('     共 %d 款' % len(miss_ai))
    print()
    print('  ══ 解谜类（LOGIC）里没有提示的：')
    miss_hint = [r for r in rows if r['cat'] == 'LOGIC' and not r['hint']]
    for r in miss_hint[:25]:
        print('     %-16s %-20s %s 行' % (r['id'][:16], r['name'][:20], r['lines']))
    print('     共 %d 款（LOGIC 共 %d）' % (len(miss_hint), len(bycat.get('LOGIC', []))))
    print()
    print('  ══ 难度没用进玩法的（所有类别）：')
    miss_diff = [r for r in rows if not r['diff']]
    print('     共 %d 款' % len(miss_diff))
    for r in miss_diff[:15]:
        print('     %-16s %-20s %s' % (r['id'][:16], r['name'][:20], r['cat']))
    print()
    print('  ══ 没有出题器（死题，玩两次就记住）的：')
    miss_gen = [r for r in rows if not r['gen']]
    print('     共 %d 款' % len(miss_gen))

    json.dump(rows, io.open('/tmp/audit_smartness.json','w',encoding='utf-8'), ensure_ascii=False, indent=1)
    print('\n  明细已存 /tmp/audit_smartness.json')

if __name__ == '__main__':
    main()
