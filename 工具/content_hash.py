#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""content_hash.py —— 对 dump 取「剔除时间后的文字集合哈希」（判据 732）

★ 为什么需要（第 1274 轮）
  拿整份 dump 的 `md5` 判「页面是否切换」会**被时钟污染**：
    状态栏的 `01:06` 每秒/每分都在变 ⇒ dump 字节变 ⇒ md5 变
    ⇒ 于是「md5 变了」既可能是「切了页」，也可能是「时钟走了一格」
  实证：800×1280 上三次点页签（游戏/统计/设置）的 dump md5 **完全相同**
        （因为三次都在同一分钟内），而先前一次「md5 变了」只是时钟跨了一分钟。

★ 做法
  只取所有 `text` 属性，做这些归一化后排序，再哈希：
    · 去掉纯数字/冒号组合（时间 01:06、`01`、`:`、`06`）
    · 去掉单独的状态栏数字（100 = 电量）
  这样「页面内容不变 ⇒ 哈希不变」，与时钟无关。

用法：
  python3 工具/content_hash.py <dump.json> [<dump2.json> ...]
  输出：每个文件一行 `<哈希前 12 位>  <文字条数>  <文件名>`
  末尾：`去重 N / M`
退出码：0 = 全部不同（或只有 1 个输入）｜ 1 = 有重复 ｜ 2 = 输入问题
"""
import hashlib
import io
import json
import os
import re
import sys

# 时间/电量这类「与页面内容无关」的文本
NOISE = re.compile(r'^(\d{1,2}|:|\d{1,2}, :, \d{1,2}|100|0)$')


def texts_of(path):
    d = json.load(io.open(path, encoding='utf-8'))
    out = []

    def walk(n):
        if not isinstance(n, dict):
            return
        t = (n.get('attributes', {}).get('text') or '').strip()
        if t:
            out.append(t)
        for c in n.get('children', []) or []:
            walk(c)

    walk(d)
    return out


def content_hash(path):
    ts = [t for t in texts_of(path) if not NOISE.match(t)]
    key = '\n'.join(sorted(ts))
    return hashlib.md5(key.encode('utf-8')).hexdigest(), len(ts)


def main():
    paths = sys.argv[1:]
    if not paths:
        print('用法: python3 工具/content_hash.py <dump.json> ...'); return 2
    seen = {}
    for p in paths:
        if not os.path.exists(p):
            print('  ⚠️ 不存在: %s' % p); continue
        try:
            h, n = content_hash(p)
        except Exception as e:
            print('  ⚠️ 解析失败 %s: %s' % (os.path.basename(p), e)); continue
        print('  %s  %3d 条  %s' % (h[:12], n, os.path.basename(p)))
        seen.setdefault(h, []).append(os.path.basename(p))
    print()
    uniq = len(seen)
    total = sum(len(v) for v in seen.values())
    print('  去重 %d / %d  %s' % (uniq, total, '✅' if uniq == total else '🔴 有重复'))
    return 0 if uniq == total else 1


if __name__ == '__main__':
    sys.exit(main())
