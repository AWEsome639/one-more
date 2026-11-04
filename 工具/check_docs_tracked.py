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
    # ★★★ 2026-11-04（第 1244 轮）**真 bug：看见了却不判失败**
    #   变异测试注入一个未跟踪的根级 .md 时，本工具的输出是：
    #     `其它未跟踪的根级 .md（需判断是否要进仓库）：`
    #     `  · 变异测试-未跟踪.md`                 ← **它明明看见了**
    #     `✅ 全部已跟踪`  rc=0                    ← **结论却说全部已跟踪**
    #   ⇒ 摘要行与上方列表**自相矛盾**
    #   ⇒ 更严重的是：任何"新增了一份文档却忘了 add"的情况，
    #     都会被这个 ✅ 掩盖 ⇒ **这正是「假成功」家族的第 7 个成员**
    #   修法：
    #     ① 摘要行必须**准确描述三态**（必进未跟踪 / 待判断 / 全部已跟踪）
    #     ② **待判断也返回非 0**（退出码 2）——
    #        因为「有文件待判断」本身就是需要人去处理的状态，
    #        不能算「通过」（判据 649 同一精神）
    if missing:
        print('🔴 %d 份必进文档未被跟踪' % len(missing))
        print('   修复：git add -f %s' % ' '.join(missing))
        print('   （`.gitignore` 第 4 行 `/*` 会忽略根级新文件，必须 -f）')
        if others:
            print('   ⚠️ 另有 %d 个其它未跟踪 .md 待判断（见上）' % len(others))
        print('=' * 60)
        return 1
    if others:
        print('⚠️ MUST_TRACK 全部已跟踪，但**另有 %d 个未跟踪的根级 .md 待判断**' % len(others))
        print('   它们可能是故意不进库的，也可能是漏了 add —— 必须人工确认：')
        for f in others:
            print('     · %s' % f)
        print('   确认要进库的：git add -f <文件>')
        print('=' * 60)
        return 2
    print('✅ 全部已跟踪（MUST_TRACK %d 份 + 无其它未跟踪 .md）' % len(MUST_TRACK))
    print('=' * 60)
    return 0


if __name__ == '__main__':
    # ★★★ 2026-11-03（第 1124 轮）**崩溃与判定失败用不同退出码**（判据 428）
    #   原来 `sys.exit(main())`：main 里抛异常就变成非 0 的 traceback 退出（也是 1）
    #   ⇒ **"检测到不合格"和"脚本自己崩了"退出码一样**
    #   ⇒ 看到 1 时无法判断该去改代码还是该去查环境
    #   ⇒ 约定：**0 = 合格 ｜ 1 = 判定不合格 ｜ 2 = 脚本异常**
    try:
        _rc = main()
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
    sys.exit(_rc if isinstance(_rc, int) else 0)
