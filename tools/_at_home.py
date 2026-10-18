#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""判断 `uitest dumpLayout` 的结果是不是「首页壳」（拾海 2026-10-13）

用法: python3 tools/_at_home.py <dump.json>   → 打印 yes / no

判据（两个都要满足，缺一不可）：
  ① 顶部有「一局」（首页标题）
  ② 底部有三个 tab 文字「游戏 / 统计 / 设置」

★ 为什么要单独一个脚本：在 shell 里用 `python3 - <<'PY'` 内嵌判定，外层再用引号包，
  很容易把 heredoc 截断（我为此吃过一次 SyntaxError）⇒ 独立文件最稳，也方便复用到别的巡检脚本。
"""
import json
import sys

def main() -> int:
    if len(sys.argv) < 2:
        print('no')
        return 0
    try:
        d = json.load(open(sys.argv[1], encoding='utf-8'))
    except Exception:
        print('no')
        return 0
    texts = set()

    def walk(n):
        if not isinstance(n, dict):
            return
        t = (n.get('attributes', {}).get('text') or '').strip()
        if t:
            texts.add(t)
        for c in n.get('children', []) or []:
            walk(c)

    walk(d)
    ok = ('一局' in texts) and ('统计' in texts) and ('设置' in texts)
    print('yes' if ok else 'no')
    return 0

if __name__ == '__main__':
    sys.exit(main())
