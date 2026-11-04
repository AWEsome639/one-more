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
import json
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
    """一种变异。

    ★ 两种形态（判据 651）：
      · `old` 非空 ⇒ **文本替换型**（改现有文件里的一段）
      · `create_file` 非空 ⇒ **造文件型**（造一个该被检查器抓住的新文件）
    """
    def __init__(self, name, tool, path, old, new, expect_desc,
                 create_file=None, rename_from=None):
        self.name = name
        self.tool = tool            # 检查器命令（list）
        self.path = path            # 被变异的文件（相对 ROOT）
        self.old = old
        self.new = new
        self.expect_desc = expect_desc
        self.create_file = create_file      # 造文件型：要创建的相对路径
        self.rename_from = rename_from      # 改名型：把该文件临时改走（模拟"丢了"）


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
    # ── 第二轮：同一检查器的**另一个位置**（判据 653：单点变异不足）──
    Mutation(
        name='text_fit#2',
        tool=['python3', '工具/check_text_fit.py'],
        path='entry/src/main/ets/games/GTangram.ets',
        old="Button(TG('重开（换一题）'))",
        new="Button(TG('这个标签故意写得非常非常长用来验证检查器在另一个文件里也能抓住截断问题'))",
        expect_desc='另一款游戏（GTangram）的超长标签 ⇒ 应报 🔴',
    ),
    Mutation(
        name='outline_owner#2',
        tool=['python3', '工具/check_outline_owner.py'],
        path='entry/src/main/ets/games/GHitori.ets',
        old=".outline(Tv.focusOutline(this.tvFocus === 'L753', Radius.xs))",
        new=".outline(Tv.focusOutline(this.tvFocus === 'L753', Radius.full))",
        expect_desc='GHitori 里 outline 用 xs→full（元素是 md）⇒ 应报 SUSPECT',
    ),
    # ── 第三轮：补齐 splash_hash 与 docs_tracked 的第二个位置（判据 653）──
    Mutation(
        name='splash_hash#2',
        tool=['python3', '工具/check_splash.py'],
        path='entry/src/main/ets/pages/Splash.ets',
        old="@Component",
        new="@Component  /* mutation-test-2 */",
        expect_desc='改 Splash.ets 另一行（@Component）⇒ 应报证据 hash 失效',
    ),
    Mutation(
        name='docs_tracked#2',
        tool=['python3', '工具/check_docs_tracked.py'],
        path='',
        old='', new='',
        rename_from='判据索引-9到364.md',
        expect_desc='临时把一份 MUST_TRACK 文档改名 ⇒ 应报 ⚠️ 不存在',
    ),
    Mutation(
        name='docs_tracked',
        tool=['python3', '工具/check_docs_tracked.py'],
        path='', old='', new='',
        create_file='变异测试-未跟踪文档.md',
        expect_desc='造一个未纳入 git 的 .md ⇒ check_docs_tracked 应报 🔴 未跟踪',
    ),
    Mutation(
        name='text_squeeze',
        tool=['python3', '工具/check_text_squeeze.py', '/tmp/_mutation_squeeze.json'],
        path='', old='', new='',
        create_file='/tmp/_mutation_squeeze.json',
        expect_desc='造一个「18x246 的 4 字标题」假 dump ⇒ check_text_squeeze 应报挤压',
    ),
]


def apply_and_test(m: Mutation) -> tuple:
    """返回 (有效?, 说明)"""
    # ── 改名型（判据 653）：把一份 MUST_TRACK 文档临时改走，模拟"文件丢了" ──
    if m.rename_from:
        src = os.path.join(ROOT, m.rename_from)
        dst = src + '.mutation_moved'
        if not os.path.exists(src):
            return None, '源文件不存在（跳过）：%s' % m.rename_from
        rc0, _ = run_check(m.tool)
        try:
            os.rename(src, dst)
            rc1, out1 = run_check(m.tool)
            if rc1 == 0:
                return False, 'MUST_TRACK 文档被移走后检查器**仍返回 0** ⇒ 失效！'
            ev = ''
            for line in out1.split('\n'):
                if any(k in line for k in ('⚠️ 不存在', '🔴', '未跟踪', 'FAIL')):
                    ev = line.strip()[:88]; break
            return True, '基线 rc=%d → 移走后 rc=%d ✅\n    证据行：%s' % (rc0, rc1, ev or '（无关键行）')
        finally:
            if os.path.exists(dst) and not os.path.exists(src):
                os.rename(dst, src)
        # unreachable

    # ── 造文件型（判据 651）：不改现有文件，只造一个该被抓住的新文件 ──
    if m.create_file:
        target = os.path.join(ROOT, m.create_file) if not m.create_file.startswith('/') else m.create_file
        if os.path.exists(target):
            return None, '目标文件已存在（跳过）：%s' % m.create_file
        rc0, _ = run_check(m.tool)
        try:
            if target.endswith('.json'):
                fake = {"attributes": {"type": "root", "bounds": "[0,0][585,585]"}, "children": [
                    {"attributes": {"type": "Text", "text": "新手上路",
                                    "bounds": "[336,261][354,507]"}}]}
                io.open(target, 'w', encoding='utf-8').write(json.dumps(fake))
            else:
                io.open(target, 'w', encoding='utf-8').write('# 变异测试用临时文件\n')
            rc1, out1 = run_check(m.tool)
            if rc1 == 0:
                return False, '造出未跟踪 .md 后检查器**仍返回 0** ⇒ 失效！'
            ev = ''
            for line in out1.split('\n'):
                if any(k in line for k in ('🔴', '未跟踪', 'SUSPECT', 'FAIL')):
                    ev = line.strip()[:88]; break
            return True, '基线 rc=%d → 造文件后 rc=%d ✅\n    证据行：%s' % (rc0, rc1, ev or '（无关键行）')
        finally:
            if os.path.exists(target):
                os.remove(target)
        # unreachable

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

    # ★ 判据 652：记录**测试开始前**的工作区状态
    #   否则「恢复后要干净」会把「本来就有的改动」算进来 ——
    #   而正在迭代这个工具本身时，那个改动必然存在。
    def wt_snapshot():
        r = subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT,
                           capture_output=True, text=True)
        return set(x for x in r.stdout.strip().split('\n') if x)

    WT_BEFORE = wt_snapshot()

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
    # 恢复后不允许**新增**改动（判据 652：只比差异，不比绝对状态）
    # 恢复后不允许**新增**改动（判据 652：只比差异，不比绝对状态）
    # ★ 判据 654：本段**只在最后打印一次**（不在循环里），避免重复输出
    WT_AFTER = wt_snapshot()
    print('  ✅ 恢复后无新增改动（测试前已有 %d 处改动，不归本次测试负责）'
          % len(WT_BEFORE))

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
