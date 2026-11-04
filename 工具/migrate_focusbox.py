#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
`focusBox(Tv.box())` → `outline` 自绘迁移

★ 为什么
  `.focusBox()` 按 SDK 文档「只改样式、不负责让框出现」（common.d.ts:18880）
  ⇒ 全项目 1175 处**从来没渲染过**
  第 1160 轮 A/B 对照证明 `.outline(Tv.focusOutline(...))` **真的能渲染**
  （960×540 上卡片区差异 15,942 像素、肉眼可见 4vp 描边）

★ 迁移规则（每处 3 行 + 1 行 @State）
      .focusable(Tv.on())          ← 保留
  -   .focusBox(Tv.box())          ← 删
  +   .onFocus(() => { this.tvFocus = 'L<行号>'; })
  +   .onBlur(() => { if (this.tvFocus === 'L<行号>') { this.tvFocus = ''; } })
  +   .outline(Tv.focusOutline(this.tvFocus === 'L<行号>'))
  文件另需 `@State private tvFocus: string = '';`

★ 为什么用「行号」当 id（Tv.ets 注释曾说"不能批量"）
  Tv.ets 注释的理由是「每款的"本格唯一 id"表达式都不一样」
  ⇒ 但**行号本身就是编译期唯一常量**，不需要业务表达式
  ⇒ 实测：1166 行里每行只有 1 个 `.focusable(Tv.on())`（多元素同行 = 0）
  ⇒ 行号在文件内唯一 ✅

用法：
  python3 工具/migrate_focusbox.py --one entry/src/main/ets/games/GXxx.ets   只改一款
  python3 工具/migrate_focusbox.py --all                                     改全部
  python3 工具/migrate_focusbox.py --check                                   只统计

退出码：0 = 成功/无待改 ｜ 1 = 有失败 ｜ 2 = 参数问题
"""
import io
import os
import re
import sys

STATE_LINE = "@State private tvFocus: string = '';"
STATE_NOTE = ("  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id\n"
              "   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/\n")


def migrate_one(path):
    src = io.open(path, encoding='utf-8').read()
    if '.focusBox(Tv.box())' not in src:
        return (0, 0, 'no focusBox')
    if 'Tv.focusOutline' in src:
        return (0, 0, 'already migrated')

    lines = src.split('\n')
    n_done = 0
    # ★ 只替换 `.focusBox(Tv.box())` 这一处，**不动 `.focusable(Tv.on())`**
    for i, ln in enumerate(lines):
        if '.focusBox(Tv.box())' not in ln:
            continue
        lid = 'L%d' % (i + 1)
        indent = re.match(r'\s*', ln).group(0)
        head, _, tail = ln.partition('.focusBox(Tv.box())')
        # ★★★ 第 1161 轮 bug 修复：
        #   原来有 `if not head.strip(): continue` 这个"防御"，
        #   而 `.focusBox(Tv.box())` **独占一行**是最常见的写法（983 处）
        #   ⇒ head 只有缩进 ⇒ 被全部跳过 ⇒ 只改了 80 个文件 189 处
        #   ⇒ 「防御」错杀了主路径
        three = (
            indent + ".onFocus(() => { this.tvFocus = '" + lid + "'; })\n"
            + indent + ".onBlur(() => { if (this.tvFocus === '" + lid + "') { this.tvFocus = ''; } })\n"
            + indent + ".outline(Tv.focusOutline(this.tvFocus === '" + lid + "'))" + tail
        )
        if head.strip():
            lines[i] = head + '\n' + three      # 紧凑写法：head 有内容
        else:
            lines[i] = three                     # 独占一行：整行替换
        n_done += 1

    if n_done == 0:
        return (0, 0, 'no match')

    newsrc = '\n'.join(lines)
    # ★★★ bug 修复：判据必须是「有没有 @State 声明」，
    #    不能是「字符串里有没有 tvFocus」（刚插入的 onFocus 里就有）
    if not re.search(r'@State\s+private\s+tvFocus\s*:', newsrc):
        m = re.search(r'^(\s*)@State\s+private\s+autoId', newsrc, re.M)
        if not m:
            m = re.search(r'^(\s*)@State\b', newsrc, re.M)
        if not m:
            return (0, n_done, '@State 定位失败（已跳过写盘）')
        newsrc = (newsrc[:m.start()] + STATE_NOTE + m.group(1) + STATE_LINE + '\n'
                  + newsrc[m.start():])

    io.open(path, 'w', encoding='utf-8').write(newsrc)
    return (1, n_done, 'ok')


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    if '--check' in args:
        n_files = n_places = 0
        for root, _, fs in os.walk('entry/src/main/ets'):
            for f in fs:
                if not f.endswith('.ets'):
                    continue
                s = io.open(os.path.join(root, f), encoding='utf-8', errors='ignore').read()
                c = s.count('.focusBox(Tv.box())')
                if c:
                    n_files += 1
                    n_places += c
        print('  仍有 focusBox 的文件 %d 个 ｜ 共 %d 处' % (n_files, n_places))
        return 0
    if '--one' in args:
        idx = args.index('--one')
        if idx + 1 >= len(args):
            print('🔴 --one 需要文件路径'); return 2
        ok, n, msg = migrate_one(args[idx + 1])
        print('  %s ｜ 迁移 %d 处 ｜ %s' % (args[idx + 1], n, msg))
        return 0 if msg != '@State 定位失败（已跳过写盘）' else 1
    if '--all' in args:
        changed = total = fail = 0
        for root, _, fs in os.walk('entry/src/main/ets'):
            for f in sorted(fs):
                if not f.endswith('.ets'):
                    continue
                p = os.path.join(root, f)
                ok, n, msg = migrate_one(p)
                if ok:
                    changed += 1
                    total += n
                if msg.startswith('@State'):
                    fail += 1
                    print('  🔴 %s: %s' % (p, msg))
        print('  改了 %d 个文件 ｜ 共 %d 处 ｜ 失败 %d' % (changed, total, fail))
        return 1 if fail else 0
    print('🔴 未知参数'); return 2


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
