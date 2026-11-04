#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mutation_test.py —— 验证「检查器本身有没有效」（判据 643/645 的落地）

★ 为什么需要（第 1243 轮）
  判据 643 说：**断言的效力 = 它能区分「合法」与「非法」的那条边界**。
  而本项目已有的检查器（check_splash / check_outline_owner / check_text_fit）
  **从来没被这样测过** —— 它们一直报 0，但「报 0」有两种可能：
    ① 代码真的干净
    ② **检查器根本查不出来**（阈值太松 / 匹配式写错 / 早退）

⇒ 本工具做「变异测试」：给每个检查器喂一个**已知坏输入**，
   看它是否**真的报错**。报错 = 检查器有效；仍报 0 = 检查器是摆设。

★ 做法（安全）
  ① 备份原文件 → ② 注入变异（一处最小改动）→ ③ 跑检查器 →
  ④ **无论成败都恢复原文件**（try/finally）→ ⑤ 报告

用法：
  python3 工具/mutation_test.py            # 跑全部
  python3 工具/mutation_test.py text_fit   # 只跑一个

退出码：0 = 所有检查器都能抓到自己那条变异（有效）
        1 = 有检查器抓不到（失效）
"""
import io
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(p):
    return io.open(p, encoding='utf-8', errors='ignore').read()


def write(p, s):
    io.open(p, 'w', encoding='utf-8').write(s)


def run_check(cmd):
    """跑检查器，返回 (exit_code, stdout)"""
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=600)
    return r.returncode, (r.stdout or '') + (r.stderr or '')


class Mutation:
    def __init__(self, name, tool, path, old, new, expect_desc):
        self.name = name
        self.tool = tool            # 检查器命令（list）
        self.path = path            # 被变异的文件（相对 ROOT）
        self.old = old
        self.new = new
        self.expect_desc = expect_desc


MUTATIONS = [
    Mutation(
        name='text_fit',
        tool=['python3', '工具/check_text_fit.py'],
        path='entry/src/main/ets/games/GTopology.ets',
        old="Button(Bp.tinyScreen() || Bp.isWatch()\n          ? TG('等价')\n          : TG('等价（洞数相同）'))",
        new="Button(TG('这是一个故意写得特别特别长的按钮标签用来测试检查器能不能发现它放不下'))",
        expect_desc='超长 Button 标签 ⇒ check_text_fit 应报 🔴 会截',
    ),
    Mutation(
        name='outline_owner',
        tool=['python3', '工具/check_outline_owner.py'],
        path='entry/src/main/ets/games/GTopology.ets',
        old=".borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54))",
        new=".borderRadius(Radius.full).layoutWeight(1).height(Cell.of(54))",
        expect_desc='描边圆角(full) ≠ 元素圆角 ⇒ check_outline_owner 应报 SUSPECT',
    ),
    Mutation(
        name='splash_hash',
        tool=['python3', '工具/check_splash.py'],
        path='entry/src/main/ets/pages/Splash.ets',
        old="@Entry",
        new="@Entry  /* mutation-test-injected */",
        expect_desc='改 Splash.ets ⇒ check_splash 应报证据 hash 失效',
    ),
]


def apply_and_test(m: Mutation) -> tuple:
    """返回 (有效?, 说明)"""
    full = os.path.join(ROOT, m.path)
    if not os.path.exists(full):
        return None, '文件不存在：%s' % m.path
    orig = read(full)
    if m.old not in orig:
        return None, '变异锚点未匹配（跳过）：%s' % m.old[:40]

    # ① 先跑一次基线（应通过）
    rc0, _ = run_check(m.tool)

    tmp = full + '.mutation_backup'
    shutil.copy2(full, tmp)
    try:
        # ② 注入变异
        write(full, orig.replace(m.old, m.new, 1))
        # ③ 跑检查器
        rc1, out1 = run_check(m.tool)
        # ④ 判定：注入后必须**报错**（exit != 0）
        if rc1 == 0:
            return False, '注入变异后检查器**仍返回 0** ⇒ 失效！\n    基线 rc=%d ｜变异后 rc=%d' % (rc0, rc1)
        # 抓一行证据
        ev = ''
        for line in out1.split('\n'):
            if any(k in line for k in ('🔴', 'SUSPECT', '失效', '不一致', 'FAIL')):
                ev = line.strip()[:88]
                break
        return True, '基线 rc=%d → 变异后 rc=%d ✅\n    证据行：%s' % (rc0, rc1, ev or '（无关键行）')
    finally:
        # ⑤ **无论如何都恢复**
        shutil.copy2(tmp, full)
        os.remove(tmp)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    print('=' * 68)
    print('  变异测试 · 检查器有效性（判据 643：断言要能区分合法/非法）')
    print('=' * 68)
    print()

    bad = 0
    skip = 0
    for m in MUTATIONS:
        if only and m.name != only:
            continue
        print('  ── %s ──' % m.name)
        print('     变异：%s' % m.expect_desc)
        ok, why = apply_and_test(m)
        if ok is None:
            print('     ⚪ 跳过：%s' % why)
            skip += 1
        elif ok:
            print('     ✅ **检查器有效**：%s' % why)
        else:
            print('     🔴 **检查器失效**：%s' % why)
            bad += 1
        print()

    total = len(MUTATIONS) if not only else 1
    good = total - bad - skip
    print('=' * 68)
    print('  汇总：%d 个变异 · 有效 %d ｜ 失效 %d ｜ **跳过 %d**'
          % (total, good, bad, skip))
    print('=' * 68)
    if skip:
        print('  ⚠️ 跳过 %d 个 = **这 %d 个检查器未经验证**（判据 649）' % (skip, skip))
    # 恢复后必须干净
    if subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT,
                      capture_output=True, text=True).stdout.strip():
        print('  🔴 恢复后工作区不干净，请检查')
        return 3
    print('  ✅ 恢复后工作区干净（git status 为空）')

    # ★ 判据 649：退出码三态 —— 跳过不能算通过
    if bad:
        print('  ⇒ 退出码 1（有检查器失效）')
        return 1
    if skip:
        print('  ⇒ 退出码 2（有检查器**未验证**，不能算通过）')
        return 2
    print('  ⇒ 退出码 0（全部检查器都验到能抓到自己那条变异）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
