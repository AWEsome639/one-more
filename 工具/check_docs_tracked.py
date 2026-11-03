#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查「应该进仓库的根级文档」是否真的被 git 跟踪（判据 409）

★ 为什么要有这个（2026-11-03 第 1114 轮）
  我在第 1088 / 1090 / 1108 轮分别「提交」了三份文档：
    · 判据索引-9到364.md
    · 项目状态快照-20261103.md
    · 开屏动画-最终验收-20261103.md
  ⇒ 三次 commit 都成功了、都有 message
  ⇒ 但本轮发现：**三份文件全部未被跟踪**
  ⇒ 根因：`.gitignore` 第 4 行是 `/*`（白名单策略）
          根级新文件默认被忽略，必须 `git add -f`
  ⇒ 而我当时用了 `git add -A <file>`，对忽略的文件**静默无效**
    ⇒ commit 变成了 `--allow-empty` 的空提交
    ⇒ **"提交成功"和"文件进库"是两件事**

★ 检查什么
  项目根目录下所有 `*.md`（除 .gitignore 里明确放行的），
  逐一 `git ls-files --error-unmatch` 验证是否被跟踪。
  未跟踪的 ⇒ 报警 + 给出修复命令。

用法：python3 工具/check_docs_tracked.py
退出码：0 = 全部已跟踪 ｜ 1 = 有未跟踪的
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 根目录下必须进仓库的文档
MUST_TRACK = [
    '真机问题清单-20261013.md',
    '判据索引-9到364.md',
    '项目状态快照-20261103.md',
    '开屏动画-最终验收-20261103.md',
]


def tracked(rel):
    r = subprocess.run(['git', '-C', ROOT, 'ls-files', '--error-unmatch', rel],
                       capture_output=True, text=True)
    return r.returncode == 0


def main():
    print('=' * 60)
    print('根级文档跟踪检查（判据 409）')
    print('=' * 60)
    missing = []
    for f in MUST_TRACK:
        p = os.path.join(ROOT, f)
        exists = os.path.exists(p)
        if not exists:
            print('  ⚠️ 不存在      %s' % f)
            continue
        ok = tracked(f)
        lines = sum(1 for _ in open(p, encoding='utf-8', errors='ignore'))
        print('  %s %-40s %5d 行' % ('✅ 已跟踪' if ok else '🔴 **未跟踪**', f, lines))
        if not ok:
            missing.append(f)

    # 额外：扫所有根级 .md，报告未跟踪的
    others = []
    for f in sorted(os.listdir(ROOT)):
        if not f.endswith('.md') or f in MUST_TRACK:
            continue
        if os.path.isfile(os.path.join(ROOT, f)) and not tracked(f):
            others.append(f)
    if others:
        print()
        print('  其它未跟踪的根级 .md（需判断是否要进仓库）：')
        for f in others:
            print('    · %s' % f)

    print()
    print('=' * 60)
    if missing:
        print('🔴 %d 份必进文档未被跟踪' % len(missing))
        print('   修复：git add -f %s' % ' '.join(missing))
        print('   （`.gitignore` 第 4 行 `/*` 会忽略根级新文件，必须 -f）')
        print('=' * 60)
        return 1
    print('✅ 全部已跟踪')
    print('=' * 60)
    return 0


if __name__ == '__main__':
    sys.exit(main())
