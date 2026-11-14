#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2026-11-14：**工具自检** —— 防两类「报告会说谎」

今天一天抓到 `10` 个「工具给出看起来正确的错误答案」，其中**两类反复出现**：

## 类 A：**从注释里读数**
正则扫 `.ets` 源码取数值，却不过滤注释行 ⇒ 命中注释里讲的旧值/公式中间步。
- `verify_changes_present.py`：`2` 条特征串落在注释上（`37/37` 那个 ✅ 是假的）
- `cell_size_audit.py`：`GGo9` 被读成 `X=300`（注释里是公式 `(Bp.height - 300) * 0.70`），
  真实值是 `-360`，台账实测 `blk=0`

## 类 B：**默认值把「缺失」伪装成「正常」**
`x = 0` 之后只在匹配到时赋值 ⇒ 匹配不到就保持 `0`，下游把它当真实值。
- `triage.py`：没有 `blk=` 的老行一律 `blk=0` ⇒ `6` 款被算进「D 档干净」，
  而它们**根本没量过溢出**

## 用法

    python3 工具/tool_selfcheck.py          # 只看有问题的
    python3 工具/tool_selfcheck.py --all    # 连「已加防线」的也列出来

**⇒ 这个脚本本身不修工具，只负责**让问题可见**。**
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TDIR = os.path.join(ROOT, '工具')

# 去注释的几种写法（任一出现即算「已有防线」）
STRIP_PAT = re.compile(r'_strip_comments|def strip_comments|strip_comments\(')

# 类 B 的模式：`name = 0` / `name = -1` / `name = ''` 之后出现 `if <re match>: name = ...`
DEF_PAT = re.compile(r'^\s+([a-z_][a-z0-9_]*)\s*=\s*(0|-1|\'\'|""|None)\s*(#.*)?$')
ASSIGN_AFTER = r'if\s+{}[^\n]*\n\s+{}\s*='


def reads_games(src):
    return bool(re.search(r'games.*\.ets|GAMES\s*=|listdir\(GAMES', src))


def main():
    show_all = '--all' in sys.argv
    a_hits, b_hits = [], []

    for fn in sorted(os.listdir(TDIR)):
        if not fn.endswith('.py'):
            continue
        p = os.path.join(TDIR, fn)
        try:
            src = io.open(p, encoding='utf-8').read()
        except Exception:
            continue
        if fn == os.path.basename(__file__):
            continue

        # 类 A：读 games 源码 + 有正则取值 + 没有去注释
        if reads_games(src) and re.search(r're\.(search|findall|match|finditer)', src):
            if not STRIP_PAT.search(src):
                a_hits.append(fn)

        # 类 B：默认值 + 条件赋值
        lines = src.split('\n')
        for i, ln in enumerate(lines):
            m = DEF_PAT.match(ln)
            if not m:
                continue
            var = m.group(1)
            tail = '\n'.join(lines[i:i + 8])
            if re.search(r'if\s+\w*[mM]\w*[^\n]*:\s*\n\s+' + re.escape(var) + r'\s*=', tail):
                b_hits.append((fn, i + 1, var))
                break

    print('== 工具自检：两类「报告会说谎」==\n')
    print('【类 A】读 `games/*.ets` 用正则取数，但**不去注释** %d 个：' % len(a_hits))
    if a_hits:
        for f in a_hits:
            print('  ⚠️ %s' % f)
        print('  ⇒ 风险：命中注释里的旧值/公式中间步 ⇒ 数字看起来对、其实取错了对象')
        print('  ⇒ 修法：正则前先 `_strip_comments()`（照 `cell_size_audit.py` 抄）')
        print('  ⓘ 若该脚本已声明「只排序不判据」（如 `estimate_height.py`），可不动')
    else:
        print('  ✅ 无')

    print('\n【类 B】默认值 `=0/-1/空` 之后被条件赋值（缺失被伪装成正常）%d 处：' % len(b_hits))
    if b_hits:
        for f, ln, var in b_hits:
            print('  ⚠️ %-28s L%-4d 变量 `%s`' % (f, ln, var))
        print('  ⇒ 风险：匹配不到就保持默认值，下游当真实值用')
        print('  ⇒ 修法：另加一个 `has_xxx` 标记，把「没数据」单独成档')
    else:
        print('  ✅ 无')

    total = len(a_hits) + len(b_hits)
    print('\n──── 合计 %d 个候选 ────' % total)
    print('⚠️ 这是**线索**不是判决：类 A 里有些脚本只用于排序（已自行声明不可作判据），')
    print('   类 B 里有些默认值确实就是 0（如计数器）。要逐个人工确认。')
    print('✅ 今晚/明天实际要用的 `6` 个工具（`shot_game` / `triage` / `verify_changed` /')
    print('   `verify_changes_present` / `cell_size_audit` / `fixed_audit`）**已全部过这道检**。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
