#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
工具/scan_early_return.py —— 扫「初始化完成判断型早退」（判据 1173/1177/1182）

★ 干嘛的：
  找 `ensure* / init* / migrate* / sync* / restore* / bootstrap*` 函数里
  **既有早退、又有持久化写入** 的地方 —— 那是「半初始化永久固化」的高危形态。

★ 为什么需要（第 1376 轮的 bug）：
  `ensureDaily` 原来：
      if (day === today) { return; }        // 只查 dailyGame
  而 `dailyPick` 可能为空（`dailyGameId()` 在 allIds 为空时返回 ''）
  ⇒ 半初始化状态**永久固化** ⇒ `dailyMeta()` 永远 undefined
  ⇒ 日卡**静默消失**，没有提示、没有报错、**永不自愈**

★ 关键区分（判据 1182）：
  27 处早退里只有 **1 处**是「**初始化完成判断**」（`day === today`）
  其余 26 处是「**值域判断**」（`xp <= 0` / `level >= 100` / `raw.length === 0`）
  ⇒ **只有前者有固化风险**；后者只是「这次不需要做」

★ 用法：
  python3 工具/scan_early_return.py [--selftest]
  exit 0 = 无高危；1 = 有高危；2 = selftest 失败
"""
import glob
import io
import os
import re
import subprocess
import sys

# 「初始化完成判断」常见字段（不是值域判断）
INIT_FIELDS = {
    'day', 'today', 'ready', 'inited', 'initialized', 'done', 'loaded',
    'dailyGame', 'dailyPick', 'onboarded', 'privacyAgreed', 'version', 'v',
}

# 值域判断里常见的标识符（不算「字段」）
NOISE = {
    'length', 'true', 'false', 'undefined', 'null', 'this', 'AppStorage', 'get',
    'string', 'number', 'boolean', 'keys', 'Object', 'cur', 'raw', 'pr', 'p', 'a',
    'b', 'xp', 'level', 'hi', 'lo', 'l', 'allIds', 'mode', 'dark', 'light',
    'pa', 'pb', 'i', 'n', 'arr', 'ids', 'count', 'total', 'index', 'idx',
}

FUNC = re.compile(r'(static\s+|private\s+|public\s+)?(\w+)\s*\([^)]*\)\s*(?::\s*[^{]*)?\{\s*$')
WRITE = re.compile(r'setOrCreate|putString|putNumber|putBoolean')
PREFIXES = ('ensure', 'init', 'migrate', 'sync', 'restore', 'bootstrap')


def scan_early_returns(src):
    """行级扫描：`if (...) {` 后 3 行内有 `return;`"""
    lines = src.split('\n')
    out = []
    for i, l in enumerate(lines):
        if not re.search(r'\bif\s*\(.*\)\s*\{\s*$', l):
            continue
        nxt = '\n'.join(lines[i + 1:i + 4])
        if not re.search(r'^\s*return[^;]*;', nxt, re.M):
            continue
        m = re.search(r'\bif\s*\((.*)\)\s*\{\s*$', l)
        if not m:
            continue
        out.append((i + 1, m.group(1).strip()))
    return out


def scan_source(src, fname):
    """返回 [(行号, 函数名, 条件, 是否高危)]"""
    lines = src.split('\n')
    out = []
    for i, l in enumerate(lines):
        mm = FUNC.search(l)
        if not mm:
            continue
        name = mm.group(2)
        if not any(name.lower().startswith(t) for t in PREFIXES):
            continue
        depth = 0
        began = False
        body = []
        for q in range(i, min(len(lines), i + 34)):
            depth += lines[q].count('{') - lines[q].count('}')
            if '{' in lines[q]:
                began = True
            body.append(lines[q])
            if began and depth <= 0:
                break
        body_s = '\n'.join(body)
        if not WRITE.search(body_s):
            continue
        for ln, cond in scan_early_returns(body_s):
            ids = set(re.findall(r'\b([a-zA-Z_]\w*)\b', cond))
            fields = {x for x in ids if x not in NOISE and not x.isdigit()}
            risky = bool(fields & INIT_FIELDS) and len(fields) <= 2
            out.append((i + ln, name, cond, risky))
    return out


def selftest():
    """★ 判据 1048：扫描器必须先在**已知案例**上验证"""
    print('  ── selftest：扫描器必须命中已知案例 ──')
    try:
        src = subprocess.check_output(
            ['git', 'show', 'dd51901:entry/src/main/ets/core/ProgressStore.ets'],
            text=True, stderr=subprocess.DEVNULL)
    except Exception as e:
        print('    🔴 取不到 dd51901 的 ProgressStore: %s' % e)
        return 2
    hits = scan_source(src, 'ProgressStore.ets')
    known = [h for h in hits if 'day === today' in h[2] and h[3]]
    print('    修复前版本命中 %d 处，其中 `day === today` %d 处'
          % (len(hits), len(known)))
    if known:
        print('    ✅ **已知案例命中** ⇒ 扫描器可用')
        return 0
    print('    🔴 **已知案例漏了** ⇒ 结果不可信')
    return 2


def main():
    if '--selftest' in sys.argv:
        return selftest()

    files = glob.glob('entry/src/main/ets/**/*.ets', recursive=True)
    hits = []
    for f in files:
        try:
            src = io.open(f, encoding='utf-8').read()
        except Exception:
            continue
        for ln, name, cond, risky in scan_source(src, os.path.basename(f)):
            hits.append((os.path.basename(f), ln, name, cond, risky))

    print('=' * 78)
    print('  初始化函数早退扫描：%d 个文件 ｜ 命中 %d 处' % (len(files), len(hits)))
    print('=' * 78)
    risky = [h for h in hits if h[4]]
    for f, ln, name, cond, r in hits:
        print('  %s %-20s L%-5d %-20s `%s`'
              % ('⚠️' if r else '  ', f, ln, name, cond[:52]))
    print()
    if risky:
        print('  ⚠️ **%d 处高危**（初始化完成判断 + 字段少 ⇒ 可能半初始化固化）' % len(risky))
        return 1
    print('  ✅ 未发现高危（初始化完成判断型的早退都不缺字段）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
