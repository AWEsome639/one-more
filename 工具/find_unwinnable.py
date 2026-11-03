#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
「这一档能不能赢」扫描（2026-10-23）
=====================================

来历：
  多米诺拼盘的 diffTotal = sizeNow(10)（7/10/13），
  但棋盘固定 4×5 = 20 格，永远只能配 10 对。
  胜利条件 `paired() === diffTotal` 在简单档与困难档**永远不成立**
  ⇒ 两种难度根本不可通关，而"看起来"只是数字怪。

  前 19 个尺寸 bug 我都只问了"看起来对不对"；
  这一个逼我多问一句：**胜利条件里的那个量，在当前棋盘上取得到吗？**

判据（三选一即报）：
  ① 胜利条件里直接出现 diffTotal
  ② 胜利条件里出现「由 diffTotal 派生的计数」与一个固定数字比较
  ③ diffTotal 同时被用作「棋盘边长」与「目标数量」（量纲不同）
"""
import io, os, re

GAMES = '/Users/a0000/dev/yiju/entry/src/main/ets/games'

def strip(s):
    out, i, n = [], 0, len(s)
    while i < n:
        if s.startswith('//', i):
            j = s.find('\n', i); i = n if j < 0 else j
        elif s.startswith('/*', i):
            j = s.find('*/', i + 2); i = n if j < 0 else j + 2
        elif s[i] in ('"', "'", '`'):
            q = s[i]; i += 1
            while i < n:
                if s[i] == '\\': i += 2; continue
                if s[i] == q: i += 1; break
                i += 1
        else:
            out.append(s[i]); i += 1
    return ''.join(out)

def main():
    print('  ══ 「这一档能不能赢」扫描\n')
    hits_total = 0
    for fn in sorted(os.listdir(GAMES)):
        if not fn.endswith('.ets'):
            continue
        src = io.open(os.path.join(GAMES, fn), encoding='utf-8').read()
        code = strip(src)
        m = re.search(r'diffTotal: number = GameDiff\.(sizeNow|livesNow)\((\d+)\)', code)
        if not m:
            continue
        kind, base = m.group(1), int(m.group(2))
        # 找胜利判定函数里的 diffTotal 比较
        win = []
        for mm in re.finditer(r'(?:isWin|solved|check|win\w*)\s*\([^)]*\)[^{]*\{', code):
            start = mm.end()
            depth, i = 1, start
            while i < len(code) and depth > 0:
                if code[i] == '{': depth += 1
                elif code[i] == '}': depth -= 1
                i += 1
            body = code[start:i]
            if 'diffTotal' in body:
                cmp = re.findall(r'diffTotal[^;\n]{0,40}', body)
                win.extend(cmp[:2])
        if win:
            hits_total += 1
            print('  %-28s %s(%d)' % (fn, kind, base))
            for c in win:
                print('     胜利条件里用到: %s' % c.strip()[:70])
    print('\n  共 %d 个文件的胜利条件里出现 diffTotal ⇒ 逐个判断"取得到吗"' % hits_total)

if __name__ == '__main__':
    main()
