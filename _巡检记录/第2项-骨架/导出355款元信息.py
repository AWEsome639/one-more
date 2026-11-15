#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 GameRegistry 导出 355 款的元信息，供生成 tone-pack 用。

用法：python3 导出355款元信息.py > games.json
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # .../One More
REG = ROOT / 'entry/src/main/ets/core/GameRegistry.ets'
GAMES = ROOT / 'entry/src/main/ets/games'


def main() -> int:
    if not REG.exists():
        print(f'❌ 找不到 {REG}', file=sys.stderr)
        return 1
    src = REG.read_text(encoding='utf-8')

    # 注册项形如：{ id: 'go9', title: '五子棋', ... }  —— 字段名可能不同，
    # 所以先打印出现过的键名，再按真实结构解析（判据 2580：查不到先 grep -i，别硬猜）。
    keys = sorted(set(re.findall(r'(\w+)\s*:', src)))
    print('// 注册表出现过的键名: ' + ', '.join(keys), file=sys.stderr)

    rows = []
    # 抓 id 与中文标题（title 或 name，按实际键名调整）
    for m in re.finditer(r"\{\s*id:\s*'([^']+)'[^}]*?\}", src):
        block = m.group(0)
        title = ''
        for pat in (r"title:\s*'([^']+)'", r"name:\s*'([^']+)'", r"cn:\s*'([^']+)'"):
            hit = re.search(pat, block)
            if hit:
                title = hit.group(1)
                break
        rows.append({'id': m.group(1), 'title': title})

    out = {'n': len(rows), 'games': rows}
    json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
    print('', file=sys.stderr)
    print(f'// 导出 {len(rows)} 款', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
