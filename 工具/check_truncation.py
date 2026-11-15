#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文本截断检测（**新轴**：`blk`/`lowh` 都测不到的那一类）。

原理：`uitest dumpLayout` 给出**实际渲染的文本**。若某款源码里有长度 N 的中文字面量，
      而 dump 里同时出现「该字符串的前缀、但更短」的文本 ⇒ 极可能被 maxLines/ellipsis 截断。

用法：
    python3 工具/check_truncation.py            # 扫 /tmp/nodes-*.tsv（已有的 dump）
    python3 工具/check_truncation.py --all      # 同时扫 _巡检记录 下存档的 dump

⚠️ 判据（2603/2782）：前缀匹配只是**线索**，必须人眼确认那条 dump 文本确实是同一元素的渲染结果。
"""
import argparse
import glob
import io
import os
import re
import sys

CJK = re.compile(r'[\u4e00-\u9fff]')
LIT = re.compile(r"'([^'\\\n]{8,120})'")
GAMES = 'entry/src/main/ets/games'


def source_strings(game_file: str) -> set:
    """该款源码里所有含中文的字面量（长度 >= 8）"""
    try:
        src = io.open(game_file, encoding='utf-8').read()
    except OSError:
        return set()
    return {m.group(1) for m in LIT.finditer(src) if CJK.search(m.group(1))}


def dump_texts(path: str) -> list:
    """dump TSV 里所有非空 text 字段（第 8 列）"""
    out = []
    try:
        for ln in io.open(path, encoding='utf-8', errors='replace'):
            parts = ln.rstrip('\n').split('\t')
            if len(parts) >= 8 and parts[0] != 'y2' and parts[7].strip():
                out.append(parts[7].strip())
    except OSError:
        pass
    return out


def static_capacity_scan() -> int:
    """
    静态档：**不需要 dump**。依据实测容量界（判据 2026-11-16：40 字装得下、44 字装不下），
    把「整行 Text 配 > 40 字中文串」列为嫌疑。高精度来源是两个实测锚点，不是估算。
    """
    hits = []
    for f in sorted(glob.glob(os.path.join(GAMES, '*.ets'))):
        src = io.open(f, encoding='utf-8').read()
        for m in re.finditer(r"Text\(\s*(?:TG\()?'([^'\\\n]{41,200})'", src):
            s = m.group(1)
            if not CJK.search(s):
                continue
            line = src[:m.start()].count('\n') + 1
            hits.append((os.path.basename(f)[:-4], line, len(s), s))
    hits.sort(key=lambda x: -x[2])
    if not hits:
        print('✅ 静态档：没有 >40 字的整行 Text 中文串')
        return 0
    # ★ 2026-11-16（判据 2797）：阈值 40 来自 dump 的报数上限，不是屏幕容量 ⇒ 只能当提示
    print('ℹ️ 静态档（提示，非报警）：%d 处 >40 字整行 Text。阈值 40 来自 dump 报数上限、不是屏幕容量；判截断只能看截图（判据 2797）' % len(hits))
    for g, ln, n, s in hits:
        print('  %-26s L%-5d %2d 字  %s' % (g, ln, n, s[:38]))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--static', action='store_true', help='静态档：不看 dump，按容量界报警')
    args = ap.parse_args()

    if args.static:
        return static_capacity_scan()

    patterns = ['/tmp/nodes-*.tsv']
    if args.all:
        patterns.append('_巡检记录/**/nodes-*.tsv')

    paths = []
    for pat in patterns:
        paths.extend(glob.glob(pat, recursive=True))
    if not paths:
        print('没有找到 dump 文件（先跑 shot_game.py 生成 /tmp/nodes-*.tsv）', file=sys.stderr)
        return 1

    findings = []
    for p in sorted(set(paths)):
        # 文件名约定：nodes-<Game>.tsv
        base = os.path.basename(p)
        m = re.match(r'nodes-(.+)\.tsv$', base)
        if not m:
            continue
        game = m.group(1)
        src_file = os.path.join(GAMES, game + '.ets')
        if not os.path.exists(src_file):
            # 名字里可能是空格换成下划线，做一次宽松匹配
            cand = glob.glob(os.path.join(GAMES, '*' + game.replace('_', '*') + '*.ets'))
            if len(cand) != 1:
                continue
            src_file = cand[0]
        # ★ 2026-11-16（判据 2797）：dump 的 text 约 40 字封顶 ⇒ 只对 <40 字可信
        longs = [s for s in source_strings(src_file) if 20 <= len(s) < 40]
        if not longs:
            continue
        texts = dump_texts(p)
        if not texts:
            continue
        for s in longs:
            for t in texts:
                # dump 文本是源串的真前缀、且明显更短 ⇒ 截断嫌疑
                if len(t) >= 6 and len(t) < len(s) and s.startswith(t):
                    findings.append((game, s, t))
                    break

    if not findings:
        print('✅ 已扫 %d 个 dump，未发现截断嫌疑' % len(set(paths)))
        return 0

    # ★ 2026-11-16：同一份 dump 可能同时在 /tmp 与 _巡检记录/dumps/（--all）⇒ 去重
    uniq = []
    seen = set()
    for item in findings:
        key = (item[0], item[1], item[2])
        if key in seen:
            continue
        seen.add(key)
        uniq.append(item)
    findings = uniq
    print('⚠️ 发现 %d 条截断嫌疑（需人眼确认）:' % len(findings))
    for game, s, t in findings[:40]:
        print('  %-26s 源 %2d 字「%s…」 → 屏上 %2d 字「%s」'
              % (game, len(s), s[:16], len(t), t))
    return 0


if __name__ == '__main__':
    sys.exit(main())
