#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""台账名字规范化（判据 2964）。

为什么要它：
  台账里游戏名有**三种写法**混在一起 ——
    ① 注册表 id 风格（`TripleSequence`）
    ② 展示名（`2048` / `Akari (Light Up)` / `Go (9x9)` / `N-Back` / `Schulte Table` ...）
    ③ 垃圾（`1966` / `267` / `Nothing` / `meter Match` / `☀️` / `__nope__`）
  后果：覆盖率少算 8 款；triage/晨报可能把同一款当两款；「出现过多少款」算成 367（真实 355）。

用法：
  from ledger_names import canon, is_junk
  key = canon(raw_name)      # 统一成注册表 id；认不出就返回去掉空格的原名
  if is_junk(raw_name): ...  # 丢掉畸形名
"""
import re

# 展示名 → 注册表 id（只收「真游戏」；见 2026-11-19 那次统计）
ALIAS = {
    '2048': 'g2048',
    'akari (light up)': 'akari',
    'go (9x9)': 'go9',
    'go / no-go': 'go_no_go',
    'n-back': 'n_back',
    'schulte table': 'schulte',
    'tic-tac-toe': 'tic_tac_toe',
    'word snake': 'word_snake_trail',
}

# 2026-11-19 实测观察到的垃圾名（标题被截断/误捕）；新增时追加到这里
KNOWN_JUNK = {
    '1966', '267', 'nothing', 'matcher', 'meter match',
    '__nope__', '__selftest__', '\u2600\ufe0f', '\u2600',
}

def is_junk(name: str) -> bool:
    """畸形名：已知垃圾 / 太短 / 含 selftest 标记 / 无字母。

    ★ 判据 2964：**输入法先查 ALIAS** —— `2048` 是纯数字但它是真游戏（`g2048`），
      上一版把它误判成垃圾了。
    """
    n = (name or '').strip()
    if n.lower() in ALIAS:
        return False                    # 别名表里的都是真游戏，永不判垃圾
    if n.lower() in KNOWN_JUNK:
        return True
    if len(n) < 3:
        return True
    if '__' in n:                       # __nope__ / __selftest__
        return True
    if not any(c.isalpha() for c in n):  # ☀️ 之类
        return True
    return False

def canon(name: str) -> str:
    """规范化成注册表 id（能对上就用 id，否则去空格原样返回）。"""
    n = (name or '').strip()
    key = n.lower()
    if key in ALIAS:
        return ALIAS[key]
    # 驼峰 → 下划线；再吃掉空格
    s = re.sub(r'(?<!^)(?=[A-Z])', '_', n).replace(' ', '').lower()
    return s
