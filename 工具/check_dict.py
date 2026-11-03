#!/usr/bin/env python3
"""字典自检：查重 / 转义 / 逐行 JSON 解析。

用法：
  python3 工具/check_dict.py            # 全量自检
  python3 工具/check_dict.py --keys a b # 只查这几个键是否重复

★ 2026-11-01 加（判据 63）：往 1.5MB 手写字面量里加条目，
  一个裸引号会变成两万条编译错误 ⇒ 加之前先跑这个。
"""
import io, re, sys, json

PATH = 'entry/src/main/ets/core/GameI18n.ets'
LANGS = {'en','ja','ko','es','fr','de','pt','ru','it','ar'}

def main():
    argv = sys.argv[1:]
    keys = []
    if '--keys' in argv:
        i = argv.index('--keys')
        keys = argv[i+1:]
    s = io.open(PATH, encoding='utf-8').read()
    lines = s.split('\n')
    bad_parse, bad_quote, seen, dup = [], [], {}, []

    for n, line in enumerate(lines, 1):
        st = line.strip()
        m = re.match(r'^"(.+?)"\s*:\s*\{\s*(.+?)\s*\},?$', st)
        if not m:
            continue
        key, inner = m.group(1), m.group(2)
        seen[key] = seen.get(key, 0) + 1
        if seen[key] == 2:
            dup.append((key, n))
        # ① JSON 解析（能同时抓裸引号）
        try:
            obj = json.loads('{' + inner + '}')
            langs = set(obj.keys())
            extra = langs - LANGS
            missing = LANGS - langs
            if extra or missing:
                bad_quote.append((n, 'langs=%s extra=%s missing=%s' % (sorted(langs), sorted(extra), sorted(missing))))
        except Exception as e:
            bad_parse.append((n, str(e)[:70], st[:90]))

    ok = True
    if keys:
        for k in keys:
            c = seen.get(k, 0)
            mark = '✅' if c <= 1 else '⚠️ 重复×%d' % c
            print('  %s 「%s」' % (mark, k))
            if c > 1:
                ok = False
    print('  ── 全量 ──')
    print('  条目数: %d ｜ 重复键: %d' % (len(seen), len(dup)))
    for k, n in dup[:5]:
        print('    ⚠️ 重复「%s」首次出现行 %d' % (k[:40], n)); ok = False
    print('  逐行 JSON 解析失败: %d' % len(bad_parse))
    for n, err, t in bad_parse[:5]:
        print('    ⚠️ 行 %d: %s' % (n, err))
        print('        %s' % t); ok = False
    print('  语言列异常: %d' % len(bad_quote))
    for n, msg in bad_quote[:5]:
        print('    ⚠️ 行 %d: %s' % (n, msg)); ok = False
    print('  ⇒ %s' % ('✅ 全部通过，可以编译' if ok else '🔴 有问题，先修再编译'))
    return 0 if ok else 1

if __name__ == '__main__':
    sys.exit(main())
