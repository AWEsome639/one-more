#!/usr/bin/env python3
"""检查所有 `t(zh, en)` / `L(zh, en)` / `L2(zh, en, n)` 调用点的中文键是否在 EXTRA 字典里。

★ 2026-11-01（判据 123）：
  `L(zh, en)` **永远能返回一个字符串**（英文兜底），
  所以"漏翻"不会报错、不会崩溃、不会有占位符 —— 它只会**静静显示英文**。
  ⇒ 这类问题在任何现有检查里都看不见，只能专门扫"zh 键在不在 EXTRA 里"。

用法：
  python3 工具/check_t_keys.py           # 只报告缺失
  python3 工具/check_t_keys.py --all     # 也列出命中的
"""
import io
import os
import re
import sys

ROOT = 'entry/src/main/ets'
DICT = os.path.join(ROOT, 'core', 'I18n.ets')


def load_extra_keys():
    src = io.open(DICT, encoding='utf-8').read()
    # EXTRA 的键形如：  "中文文案": { "ja": ...
    keys = set()
    # ★ 2026-11-01（第 827 轮）：原来要求 `"ja":` 开头 ——
    #   但字典里有些条目以 `"zh-Hant":` 开头（历史遗留的写法），会被漏判。
    #   ⇒ 改成"冒号后跟任意语言键"即可。漏判的后果很严重：
    #     同一句文案被当成"缺失"→ 手工补一条 → **重复键 ⇒ 编译报错**。
    for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)+)"\s*:\s*\{\s*"[a-zA-Z-]+"\s*:', src, re.M):
        # ★ 2026-11-01（第 828 轮）：字典键里含 `\"` 时要还原成 `"`，
        #   否则与代码里 `'看"实际"一列'` 这种单引号字符串永远对不上。
        keys.add(m.group(1).replace('\\"', '"'))
    return keys


# ★ 2026-11-01（第 828 轮）：原来只扫 `L()/L2()` 顶层函数调用，
#   但组件里的 `this.t('中文', 'English')` **同样走 L()**（见各 Tab 的 t() 实现），
#   那些调用点一条都没被检查到。
CALL = re.compile(
    r'\b(?:L|L2|L3|L4|t)\s*\(\s*\'((?:[^\'\\]|\\.)*)\'\s*,\s*\'',
)
# 但要排除 `this.t(` 之外的同名函数误伤 —— 本项目里没有别的 t()，先直接收。


def scan_calls(extra):
    missing = []
    hit = []
    for dirpath, _, files in os.walk(ROOT):
        if 'build' in dirpath:
            continue
        for fn in files:
            if not fn.endswith('.ets'):
                continue
            path = os.path.join(dirpath, fn)
            src = io.open(path, encoding='utf-8').read()
            for m in CALL.finditer(src):
                zh = m.group(1).replace('\\"', '"')
                line = src[:m.start()].count('\n') + 1
                if zh in extra:
                    hit.append((path, line, zh))
                else:
                    missing.append((path, line, zh))
    return missing, hit


def main():
    if not os.path.exists(DICT):
        print('找不到 %s' % DICT)
        return 2
    extra = load_extra_keys()
    missing, hit = scan_calls(extra)
    show_all = '--all' in sys.argv
    print('EXTRA 字典：%d 条' % len(extra))
    print('L()/L2() 调用点：%d 处，其中 %d 处键在字典里，**%d 处缺失**'
          % (len(hit) + len(missing), len(hit), len(missing)))
    if missing:
        print()
        print('缺失的中文键（这些在日/韩/法/德/西/葡/俄/意/阿 会退成英文）：')
        seen = {}
        for path, line, zh in missing:
            seen.setdefault(zh, []).append('%s:%d' % (path.replace(ROOT + '/', ''), line))
        for zh in sorted(seen):
            print('  「%s」  %d 处：%s' % (zh, len(seen[zh]), '，'.join(seen[zh][:3])))
        return 1
    if show_all:
        print()
        for path, line, zh in hit:
            print('  ✅ 「%s」 %s:%d' % (zh, path.replace(ROOT + '/', ''), line))
    print()
    print('✅ 全部调用点的中文键都在 EXTRA 字典里')
    return 0


if __name__ == '__main__':
    sys.exit(main())
