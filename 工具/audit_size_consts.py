#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
尺寸陷阱扫描（2026-10-23 第二期）

背景：
  在「二进制（Takuzu）」里一次找到三个同源的 bug，全是
  **「难度作用到棋盘尺寸」改造后，校验/生成/显示三处还写着写死的常量**：
    · lineOk 循环用 N=6（实际 4 或 8）⇒ 校验错
    · GIVENS=18 写死 ⇒ 4×4 时 need 负数 ⇒ 一格都不挖 ⇒ 游戏不可玩
    · 进度分母写死 CELLS=36 ⇒ 显示 8/36（实际 8/16）

⇒ 既然能在一个文件里撞见三个，就该怀疑别的游戏也有。
  这个脚本不是"判断有没有 bug"，而是**把可疑点排出来给人看**：
  凡是同时满足下面两条的，都列出来：

    ① 这个文件用了 GameDiff.sizeNow / livesNow（说明尺寸/次数会变）
    ② 里面有**模块级常量**被用在 for 循环上界、或拼进显示字符串当分母

  第 ② 条只是"可疑"，不一定错（有些常量的语义就是固定值）。
  所以输出是**待人工核的清单**，不是结论。
"""
import io, os, re

ROOT = '/Users/a0000/dev/yiju'
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')

SIZE_USE = re.compile(r'GameDiff\.(sizeNow|livesNow)')
# 模块级常量：const NAME: number = <数字>
CONST_DEF = re.compile(r'^const\s+([A-Z][A-Z0-9_]*):\s*number\s*=\s*([^;]+);', re.M)
# for 循环里用常量作上界
LOOP_USE = r'for\s*\([^;]*;\s*[^;<]*<\s*%s\s*;'
# 显示里用常量作分母/比值
DISPLAY_USE = r"[+]\s*'/'|'/'"

def main():
    rows = []
    for f in sorted(os.listdir(GAMES)):
        if not f.endswith('.ets') or '.bak' in f:
            continue
        txt = io.open(os.path.join(GAMES, f), encoding='utf-8', errors='ignore').read()
        if not SIZE_USE.search(txt):
            continue
        consts = CONST_DEF.findall(txt)
        if not consts:
            continue
        flags = []
        for name, val in consts:
            # 只关心数值常量
            if not re.match(r'^\s*\d+\s*$', val):
                continue
            n = int(val.strip())
            if n < 2:
                continue
            # ① 用在 for 循环上界
            in_loop = bool(re.search(LOOP_USE % re.escape(name), txt))
            # ② 用在字符串拼接里（粗略：出现在 '/' 附近）
            near_div = False
            for m in re.finditer(r'\b' + re.escape(name) + r'\b', txt):
                seg = txt[max(0, m.start() - 24): m.end() + 24]
                if "'/'" in seg or '+ \'/\'' in seg:
                    near_div = True
                    break
            if in_loop or near_div:
                flags.append((name, n, in_loop, near_div))
        if flags:
            rows.append((f, flags))

    print('  ══ 同时满足「尺寸会变」+「有常量用于循环/显示」的文件：%d 个\\n' % len(rows))
    for f, flags in rows:
        print('  %s' % f)
        for name, n, in_loop, near_div in flags:
            tag = []
            if in_loop:
                tag.append('循环上界')
            if near_div:
                tag.append('显示分母')
            print('     %-14s = %-4d  %s' % (name, n, ' + '.join(tag)))
        print()
    print('  ⚠️ 这是**待人工核**的清单，不是结论。')
    print('     有些常量的语义就该是固定值（例如固定的格子数上限），不算 bug。')
    print('     核法：看它是不是"本该跟着棋盘尺寸变"的那个量。')

if __name__ == '__main__':
    main()
