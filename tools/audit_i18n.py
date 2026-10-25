#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
A7 · I18n key 一致性扫描（拾海 2026-10-19）

为什么要有它：
  `this.t('中文', 'English')` 的第一参数是 **I18n 表的 key**。
  一旦调用处的字面量和表里的 key 有一个字不同 ⇒ 查不到 ⇒ 回退（显示英文或原文）。
  这是"看起来没 bug，实际上多语言全废"的隐形故障。

  2026-10-19 实测抓到：I18n 表已把「一局」改成「One More」，
  但 GuidePage 还传「一局」⇒ 俄语用户会看到中文。

判据：
  ① 源码里 t()/tn()/L()/tt() 的第一参数字面量
  ② I18n.ets 里所有 key（行首 "xxx": {）
  ③ 差集 = 查不到的 key（回退风险）
"""
import os
import re
import io
import sys

ROOT = '/Users/a0000/dev/One More'
ETS = os.path.join(ROOT, 'entry/src/main/ets')
I18N = os.path.join(ETS, 'core/I18n.ets')
GAME_I18N = os.path.join(ETS, 'core/GameI18n.ets')


def read(p):
    try:
        return io.open(p, encoding='utf-8').read()
    except Exception:
        return ''


def unescape(s):
    """把源码里的 \n / \\ 还原成真实字符，才能和 I18n 表里的 key 对齐"""
    return (s.replace('\\n', '\n')
             .replace('\\t', '\t')
             .replace('\\"', '"')
             .replace("\\'", "'")
             .replace('\\\\', '\\'))


def keys_in_i18n():
    """从 I18n.ets / GameI18n.ets 抽所有 key"""
    keys = set()
    for p in (I18N, GAME_I18N):
        t = read(p)
        if not t:
            continue
        # 行首（可有缩进）的双引号 key，后跟 :
        for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*\{', t, re.M):
            keys.add(unescape(m.group(1)))
        # 单行形式：  "xxx": { "ja": ... }
        for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*\{', t):
            keys.add(unescape(m.group(1)))
    return keys


def calls_in_source():
    """从所有 .ets 里抽 t('...', ...) 的第一参数字面量（支持跨行）"""
    out = []
    for dp, _, fs in os.walk(ETS):
        for fn in fs:
            if not fn.endswith('.ets'):
                continue
            p = os.path.join(dp, fn)
            if os.path.basename(p) in ('I18n.ets', 'GameI18n.ets'):
                continue
            t = read(p)
            # 匹配 this.t( / t( / tn( / L( / tt( ，然后把后面连续的
            #      '字面量' + '字面量' + ...
            #   ★ 2026-10-19 修：原来只抓第一段 ⇒ 多行拼接的 key 全被误判为"查不到"
            #   静态拼接在运行时是一条字符串，必须折叠起来再查
            # ★ 2026-10-19 补盲区：this.sec(titleZh, titleEn, bodyZh, bodyEn)
            #   其中第 1 和第 3 个参数都会进 t() ⇒ 也是 key
            for m in re.finditer(r"this\.sec\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*'(?:[^'\\]|\\.)*'\s*,\s*'((?:[^'\\]|\\.)*)'", t):
                for g in (m.group(1), m.group(2)):
                    key = unescape(g)
                    if key.strip():
                        line = t.count('\n', 0, m.start()) + 1
                        out.append((os.path.relpath(p, ROOT), line, key))

            for m in re.finditer(r"(?:this\.)?\b(?:t|tn|tt|L)\s*\(", t):
                pos = m.end()
                parts = []
                while True:
                    mm = re.match(r"\s*'((?:[^'\\]|\\.)*)'\s*", t[pos:], re.S)
                    if not mm:
                        break
                    parts.append(mm.group(1))
                    pos += mm.end()
                    # 后面是不是 '+'（继续拼）
                    m2 = re.match(r"\+\s*", t[pos:], re.S)
                    if not m2:
                        break
                    pos += m2.end()
                if not parts:
                    continue
                key = unescape(''.join(parts))
                if not key.strip():
                    continue
                line = t.count('\n', 0, m.start()) + 1
                out.append((os.path.relpath(p, ROOT), line, key))
    return out


def main():
    keys = keys_in_i18n()
    calls = calls_in_source()
    print('=' * 64)
    print('A7 · I18n key 一致性')
    print('  表里 key 数：%d   源码 t() 调用数：%d' % (len(keys), len(calls)))
    print('=' * 64)

    # 同一 key 可能被调用多次 ⇒ 按 key 去重，只报第一次出现
    seen = {}
    for f, ln, key in calls:
        if key in keys:
            continue
        if key in seen:
            seen[key][2] += 1
            continue
        seen[key] = [f, ln, 1]

    if not seen:
        print('\n✅ 所有 t() 的第一参数都能在 I18n 表里找到')
        return

    print('\n🔴 %d 个 key 查不到（会回退，多语言失效）：\n' % len(seen))
    for key, (f, ln, cnt) in sorted(seen.items(), key=lambda kv: kv[1][0]):
        disp = key.replace('\n', '\\n')
        if len(disp) > 46:
            disp = disp[:46] + '…'
        print('   %-46s %s:%d  (×%d)' % (disp, f.split('/ets/')[-1], ln, cnt))

    print('\n合计 %d 个 key 需要修' % len(seen))


if __name__ == '__main__':
    main()
