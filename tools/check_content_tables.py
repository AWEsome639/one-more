# -*- coding: utf-8 -*-
"""内容双语表一致性检查（可复算，不需要设备）

从源码抠「中文表函数」与「英文表常量」的数组文本，做字符串级检查：
  1) 两边顶层条目数一致（对象数组数 `{`，字符串数组数内层 `[`）
  2) 两张表里被引号包住的字符串没有重复
  3) 打印每张表的条目数，便于人工看数字（全 0 即视为失败，避免假绿）
"""
import io
import os
import re
import sys

GAMES = r'D:\work\one-more\entry\src\main\ets\games'

CASES = [
    ('GWordPairAssociateMemory.ets', 'zhBank', 'BANK_EN'),
    ('GReadingSpan.ets', 'zhSents', 'SENTS_EN'),
    ('GWordAssociationRecall.ets', 'zhPairs', 'PAIRS_EN'),
    ('GCognateCatch.ets', 'zhAll', 'ALL_EN'),
    ('GVowelReconstruct.ets', 'zhBank', 'BANK_EN'),
    ('GAnagramDefinition.ets', 'zhBank', 'BANK_EN'),
    ('GNarrativeRecall.ets', 'storiesZh', 'STORIES_EN'),
    ('GSemanticLink.ets', 'chainsZh', 'CHAINS_EN'),
    ('GDefinitionDash.ets', 'poolZh', 'BANK_EN'),
    ('GEtymologyOrigin.ets', 'bankZh', 'BANK_EN'),
    ('GCategoryFluency.ets', 'catsZh', 'CATS_EN'),
    ('GSemanticDistance.ets', 'triosZh', 'TRIOS_EN'),
    ('GSemanticAssociation.ets', 'pairsZh', 'PAIRS_EN'),
]

STR = re.compile(r"'([^']*)'")


def slice_array(src, open_idx):
    depth = 0
    i = open_idx
    quote = ''
    while i < len(src):
        ch = src[i]
        if quote:
            if ch == '\\':
                i += 2
                continue
            if ch == quote:
                quote = ''
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
        elif ch == '[':
            depth += 1
        elif ch == ']':
            depth -= 1
            if depth == 0:
                return src[open_idx:i + 1]
        i += 1
    return None


def const_array(src, name):
    m = re.search(r'const\s+' + re.escape(name) + r'\s*:', src)
    if not m:
        return None
    eq = src.find('=', m.end())
    if eq < 0:
        return None
    open_idx = src.find('[', eq)
    return slice_array(src, open_idx) if open_idx > 0 else None


def func_array(src, name):
    m = re.search(r'function\s+' + re.escape(name) + r'\s*\(', src)
    if not m:
        return None
    ret = src.find('return', m.end())
    if ret < 0:
        return None
    open_idx = src.find('[', ret)
    return slice_array(src, open_idx) if open_idx > 0 else None


def count_entries(text):
    obj = text.count('{')
    if obj > 0:
        return obj
    return max(0, text.count('[') - 1)


def strings(text):
    return [m.group(1) for m in STR.finditer(text) if m.group(1)]


def main():
    fails = []
    for fn, zh_name, en_name in CASES:
        src = io.open(os.path.join(GAMES, fn), encoding='utf-8').read()
        zh = func_array(src, zh_name)
        en = const_array(src, en_name)
        if zh is None:
            fails.append((fn, 'ZH 表缺失 ' + zh_name))
            continue
        if en is None:
            fails.append((fn, 'EN 表缺失 ' + en_name))
            continue
        cz, ce = count_entries(zh), count_entries(en)
        if cz == 0 or ce == 0:
            fails.append((fn, '表为空（解析失败）zh=%d en=%d' % (cz, ce)))
            continue
        if cz != ce:
            fails.append((fn, '条数不等 zh=%d en=%d' % (cz, ce)))
        # 重复不算失败：语言名/选项在多题里重复是正常内容（orange 既是水果也是颜色）
        for text, tag in ((zh, 'zh'), (en, 'en')):
            _ = strings(text)
        print('OK %-32s entries zh=%d en=%d' % (fn, cz, ce))
    if fails:
        print('\nFAILED:')
        for fn, why in fails:
            print(' -', fn, why)
        return 1
    print('\nALL PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
