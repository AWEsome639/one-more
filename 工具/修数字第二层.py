#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 游戏数字本地化【第二层】修复器（2026-10-16）

第一层（已做，203 文件 / 269 处）：游戏 HUD 的 `Text((String(this.X)))` 包 Digits
第二层（本脚本）：
  ① HUD 面板里的【数字常量】：`Text((String(TARGET)))` → `Text(Digits(String(TARGET), this.langCode))`
  ② 规则/进度文案的 TG2 数字参数：
     `TG2('每消一颗 +{0}，{1} 步内拿到 {2} 分算通关', PER_GEM, MOVE_LIMIT, TARGET)`
     → 每个【数字型】实参包 `Digits(String(x), this.langCode)`

★ 只改【界面语境】（模板含 步/分/秒/次/关/局/颗 等 UI 量词）
★ 数学题面/答案反馈【不改】（如「等差数列，公差 {0}」）—— 那是谜题内容

★★★ 护栏（第一层摔两次换来的）：
  ① 用【平衡括号扫描】取完整 TG2(...) 实参区，绝不靠正则截断
  ② 写盘前做括号配平检查，不配平就拒绝该文件
  ③ 只包【能证明是数字】的实参（String(this.X) / this.X 且 X 声明为 number / 大写数字常量）

用法：
    python3 工具/修数字第二层.py --dry
    python3 工具/修数字第二层.py
"""
import io
import json
import os
import re
import shutil
import sys

BASE = os.path.expanduser('~/dev/yiju/entry/src/main/ets/games/')
BAK = os.path.expanduser('~/dev/yiju/.animbak22/')
DRY = '--dry' in sys.argv
UI_WORD = re.compile(r'[步分秒次关局颗条命]')


def balanced(t):
    d = 0
    in_s = None
    i = 0
    while i < len(t):
        c = t[i]
        if in_s:
            if c == '\\':
                i += 2
                continue
            if c == in_s:
                in_s = None
        elif c in ('"', "'"):
            in_s = c
        elif c == '(':
            d += 1
        elif c == ')':
            d -= 1
            if d < 0:
                return False
        i += 1
    return d == 0


def scan_call(s, start):
    """★ 从 `TG2(` 的 `(` 开始，用括号平衡扫出实参区，返回 (args_str, end_idx)"""
    i = s.index('(', start)
    d = 0
    in_s = None
    j = i
    while j < len(s):
        c = s[j]
        if in_s:
            if c == '\\':
                j += 2
                continue
            if c == in_s:
                in_s = None
        elif c in ('"', "'"):
            in_s = c
        elif c == '(':
            d += 1
        elif c == ')':
            d -= 1
            if d == 0:
                return s[i + 1:j], j + 1
        j += 1
    return None, None


def split_args(a):
    """★ 顶层逗号切分"""
    out, cur, d, in_s = [], '', 0, None
    i = 0
    while i < len(a):
        c = a[i]
        if in_s:
            cur += c
            if c == '\\':
                cur += a[i + 1] if i + 1 < len(a) else ''
                i += 2
                continue
            if c == in_s:
                in_s = None
        elif c in ('"', "'"):
            in_s = c
            cur += c
        elif c in '([{':
            d += 1
            cur += c
        elif c in ')]}':
            d -= 1
            cur += c
        elif c == ',' and d == 0:
            out.append(cur)
            cur = ''
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur)
    return out


def fix_const(s, numconsts):
    """① HUD 面板里的数字常量"""
    n = 0
    for m in list(re.finditer(r'Text\(\s*\(?\s*String\(\s*([A-Za-z_]\w*)\s*\)\s*\)*', s)):
        c = m.group(1)
        if c not in numconsts:
            continue
        if 'Digits(' in s[max(0, m.start() - 40):m.end()]:
            continue
        s = s[:m.start()] + 'Text(Digits(String(%s), this.langCode))' % c + s[m.end():]
        n += 1
    return s, n


def fix_rules(s, numfields, numconsts):
    """② 规则文案的 TG2 数字参数"""
    n = 0
    pos = 0
    while True:
        i = s.find('TG2(', pos)
        if i < 0:
            break
        args, end = scan_call(s, i)
        if args is None:
            pos = i + 4
            continue
        parts = split_args(args)
        if not parts:
            pos = end
            continue
        tpl = parts[0]
        # ★ 只在【界面语境】模板上动手
        if not UI_WORD.search(tpl) or '{0}' not in tpl or 'Digits(' in args:
            pos = end
            continue
        newparts = [parts[0]]
        changed = False
        for a in parts[1:]:
            t = a.strip()
            wrap = None
            m1 = re.match(r'^String\(\s*this\.([A-Za-z_]\w*)\s*(\(\))?\s*\)$', t)
            m2 = re.match(r'^this\.([A-Za-z_]\w*)(\(\))?$', t)
            m3 = re.match(r'^([A-Z][A-Z_0-9]*)$', t)
            m4 = re.match(r'^String\(\s*([A-Za-z_]\w*)\s*(\(\))?\s*\)$', t)
            if m1 and m1.group(1) in numfields:
                wrap = 'String(this.%s)' % m1.group(1)
            elif m2 and m2.group(1) in numfields:
                wrap = 'String(this.%s)' % m2.group(1)
            elif m3 and m3.group(1) in numconsts:
                wrap = 'String(%s)' % m3.group(1)
            elif m4 and m4.group(1) in numconsts:
                wrap = 'String(%s)' % m4.group(1)
            if wrap:
                newparts.append('Digits(%s, this.langCode)' % wrap)
                changed = True
            else:
                newparts.append(a)
        if changed:
            s = s[:i] + 'TG2(' + ','.join(newparts) + ')' + s[end:]
            n += 1
            pos = i + len('TG2(') + len(','.join(newparts)) + 1
        else:
            pos = end
    return s, n




def ensure_import(s):
    """★ 补 import Digits（已有 I18n 导入则合并）"""
    m = re.search(r"import\s*\{([^}]*)\}\s*from\s*'\.\./core/I18n';", s)
    if m:
        names = [x.strip() for x in m.group(1).split(',') if x.strip()]
        if 'Digits' in names:
            return s, False
        names = sorted(set(names + ['Digits']))
        new = "import { %s } from '../core/I18n';" % ', '.join(names)
        return s[:m.start()] + new + s[m.end():], True
    last = None
    for mm in re.finditer(r"^import .*;$", s, re.M):
        last = mm
    if last is None:
        return s, False
    ins = "\nimport { Digits } from '../core/I18n';"
    return s[:last.end()] + ins + s[last.end():], True


def ensure_lang(s):
    """★ 补 @StorageProp('lang') langCode"""
    if "@StorageProp('lang')" in s or '@StorageProp("lang")' in s:
        return s, False
    m = re.search(r'^(export\s+struct\s+\w+\s*\{)\s*$', s, re.M)
    if not m:
        return s, False
    ins = ("\n  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ "
           "必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */\n"
           "  @StorageProp('lang') langCode: string = 'zh';")
    return s[:m.end()] + ins + s[m.end():], True


def main():
    os.makedirs(BAK, exist_ok=True)
    import glob
    st = {'files': 0, 'c1': 0, 'c2': 0, 'reject': []}
    for fp in sorted(glob.glob(BASE + 'G*.ets')):
        s0 = io.open(fp, encoding='utf-8').read()
        fields = set(re.findall(r'@State\s+(?:private\s+)?([A-Za-z_]\w*)\s*:\s*number', s0))
        fields |= set(re.findall(r'@(?:Prop|Link)\s+(?:private\s+)?([A-Za-z_]\w*)\s*:\s*number', s0))
        consts = set(re.findall(r'^const\s+([A-Za-z_]\w*)\s*:\s*number\s*=', s0, re.M))
        consts |= set(re.findall(r'^const\s+([A-Z][A-Z_0-9]*)\s*=\s*\d', s0, re.M))
        s = s0
        s, _ = ensure_import(s)
        s, _ = ensure_lang(s)
        s, a = fix_const(s, consts)
        s, b = fix_rules(s, fields, consts)
        if a + b == 0:
            continue
        if DRY:
            st['files'] += 1
            st['c1'] += a
            st['c2'] += b
            continue
        if not balanced(s):
            st['reject'].append(os.path.basename(fp))
            continue
        shutil.copy(fp, BAK + os.path.basename(fp))
        io.open(fp, 'w', encoding='utf-8').write(s)
        st['files'] += 1
        st['c1'] += a
        st['c2'] += b
    tag = '[空跑]' if DRY else '[已改]'
    print('  %s 文件 %d | 常量 %d 处 | 规则参数 %d 处' % (tag, st['files'], st['c1'], st['c2']))
    if st['reject']:
        print('  括号不配平被拒: %d 个 %s' % (len(st['reject']), st['reject'][:8]))


if __name__ == '__main__':
    main()
