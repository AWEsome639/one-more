#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""离线夹具：ledger_names 的别名与垃圾判定（判据 2964）。

跑法：python3 工具/test_ledger_names.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ledger_names import canon, is_junk

CASES = [
    # (输入, 期望 canon, 期望 is_junk)
    ('2048',              'g2048',            False),   # ★ 纯数字但真游戏
    ('Akari (Light Up)',  'akari',            False),
    ('Go (9x9)',          'go9',              False),
    ('Go / No-Go',        'go_no_go',         False),
    ('N-Back',            'n_back',           False),
    ('Schulte Table',     'schulte',          False),
    ('Tic-Tac-Toe',       'tic_tac_toe',      False),
    ('Word Snake',        'word_snake_trail', False),
    ('TripleSequence',    'triple_sequence',  False),
    ('Kakuro',            'kakuro',           False),
    ('1966',              '1966',             True),
    ('267',               '267',              True),
    ('Nothing',           'nothing',          True),
    ('meter Match',       'meter_match',      True),
    ('__nope__',          '__nope__',         True),
    ('__selftest__',      '__selftest__',     True),
]

def main():
    bad = 0
    for raw, want_c, want_j in CASES:
        c, j = canon(raw), is_junk(raw)
        ok = (c == want_c and j == want_j)
        if not ok:
            bad += 1
            print('  ❌ %-20s canon=%s(期望 %s) junk=%s(期望 %s)' % (raw, c, want_c, j, want_j))
    print('%d/%d 通过' % (len(CASES) - bad, len(CASES)))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
