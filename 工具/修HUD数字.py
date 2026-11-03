#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 游戏 HUD 数字本地化（BUG #24）批量修复器 v2（2026-10-16）

背景：232 个游戏的 HUD 数字走 `Text(String(this.score))` —— 没走 Digits
      ⇒ 阿语下【游戏内西文数字、App 界面 ٠-٩】⇒ 一屏两种数字

做法（每个文件）：
  ① 补 import Digits（已有 '../core/I18n' 导入则【合并】）
  ② 补 @StorageProp('lang') langCode（插在 export struct 后）
  ③ Text(...) 里的数字 → Text(Digits(String(this.X), this.langCode))
     ★ 只改【字段声明是 number】的
     ★ 用精确 (start,end) 偏移

★★★ 三重护栏（我跳过它们摔了两次，铁律⑥）：
  ① 匹配段【紧后字符】必须是表达式边界（空白 , ; ) ] } 或行尾）
     —— 若是 `+` `.` `[` 等 ⇒ 复合表达式 ⇒ 跳过（手改）
  ② 匹配段【内部】不能含运算符（+ ?）
  ③ 写盘前做【括号配平检查】，不配平就拒绝该文件

用法：
    python3 工具/修HUD数字.py --dry      # 空跑
    python3 工具/修HUD数字.py            # 真改
"""
import io
import json
import os
import re
import shutil
import sys

BASE = os.path.expanduser('~/dev/yiju/entry/src/main/ets/games/')
BAK = os.path.expanduser('~/dev/yiju/.animbak21/')
GAP = '/tmp/digits_gap.json'
DRY = '--dry' in sys.argv

TEXTNUM = re.compile(
    r'Text\(\s*\(?\s*(?:String\(\s*this\.([A-Za-z_]\w*)\s*\)'
    r'|this\.([A-Za-z_]\w*)\s*\.toString\(\)'
    r'|this\.([A-Za-z_]\w*))'
    r'\s*\)+')


def balanced(t: str) -> bool:
    """★ 护栏③：括号配平（忽略字符串内的括号）"""
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


def ensure_import(s):
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
    if "@StorageProp('lang')" in s or '@StorageProp("lang")' in s:
        return s, False
    m = re.search(r'^(export\s+struct\s+\w+\s*\{)\s*$', s, re.M)
    if not m:
        return s, False
    ins = ("\n  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ "
           "必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */\n"
           "  @StorageProp('lang') langCode: string = 'zh';")
    return s[:m.end()] + ins + s[m.end():], True


def wrap_numbers(s, fields):
    edits = []
    for m in TEXTNUM.finditer(s):
        fld = m.group(1) or m.group(2) or m.group(3)
        if fld not in fields:
            continue
        le = s.find('\n', m.start())
        line = s[m.start():le if le > 0 else m.start() + 200]
        if 'Digits(' in line:
            continue
        # ★ 护栏①：紧跟字符必须是表达式边界
        #   ★★ 注意 `.` 也算边界 —— 因为 `Text(...).fontSize()` 是 ArkUI 的正常链式写法
        #   （第一版把它排除掉 ⇒ 只剩 29 个文件，等于没修）
        after = s[m.end():m.end() + 1]
        if after and after not in ' \t\r\n,;)]}.':
            continue
        # ★ 护栏②：匹配段内不能有运算符
        if '+' in m.group(0) or '?' in m.group(0):
            continue
        edits.append((m.start(), m.end(), fld))
    if not edits:
        return s, 0
    for st, en, fld in sorted(edits, key=lambda x: -x[0]):
        s = s[:st] + 'Text(Digits(String(this.%s), this.langCode))' % fld + s[en:]
    return s, len(edits)


def main():
    gap = json.load(io.open(GAP, encoding='utf-8'))
    os.makedirs(BAK, exist_ok=True)
    st = {'files': 0, 'nums': 0, 'imp': 0, 'lang': 0, 'skip': [], 'reject': []}
    for f in sorted(gap):
        fp = BASE + f
        s0 = io.open(fp, encoding='utf-8').read()
        fields = set(re.findall(r'@State\s+(?:private\s+)?([A-Za-z_]\w*)\s*:\s*number', s0))
        fields |= set(re.findall(r'@(?:Prop|Link)\s+(?:private\s+)?([A-Za-z_]\w*)\s*:\s*number', s0))
        s = s0
        s, c_imp = ensure_import(s)
        s, c_lang = ensure_lang(s)
        s, c_num = wrap_numbers(s, fields)
        if c_num == 0:
            st['skip'].append(f)
            continue
        if DRY:
            st['files'] += 1
            st['nums'] += c_num
            st['imp'] += 1 if c_imp else 0
            st['lang'] += 1 if c_lang else 0
            continue
        if not balanced(s):
            st['reject'].append(f)
            continue
        shutil.copy(fp, BAK + f)
        io.open(fp, 'w', encoding='utf-8').write(s)
        back = io.open(fp, encoding='utf-8').read()
        if 'Digits(' not in back:
            print('     回读失败: %s' % f)
            continue
        st['files'] += 1
        st['nums'] += c_num
        st['imp'] += 1 if c_imp else 0
        st['lang'] += 1 if c_lang else 0
    tag = '[空跑]' if DRY else '[已改]'
    print('  %s 文件 %d | 包装数字 %d | 补 import %d | 补 lang %d | 跳过 %d'
          % (tag, st['files'], st['nums'], st['imp'], st['lang'], len(st['skip'])))
    if st['reject']:
        print('  括号不配平被拒: %d 个 %s' % (len(st['reject']), st['reject'][:8]))
    if st['skip']:
        print('  跳过（复合表达式或无可改处）: %d 个 %s' % (len(st['skip']), st['skip'][:8]))


if __name__ == '__main__':
    main()
