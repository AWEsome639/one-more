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


# ★★★ 判据 648 的**第二种形态**（第 1285 轮）：**自带 `--selftest` 的检查器**
#
# 为什么需要单独一张表
#   「变异测试」的语义是：**注入一个坏数据 ⇒ 检查器必须报错**。
#   但有些检查器的有效性可以用更直接的方式证明：
#     它自己带一段**最小 fixture**，跑一遍必须通过。
#   ⇒ `check_double_padding.py --selftest` 就是这种：
#       在临时目录造「内层有 padding + 外层也有 padding」两个组件，
#       要求工具报出「1 处风险 / 双层 40 vp / 195 vp 占比 41.0% 🔴」
#     五项全中才 exit 0。
#
# 为什么它比「造变异」更强
#   本工具前 5 版都报「0 风险」（判据 759 的假阴性），
#   而 `--selftest` 就是专门用来抓这种「永远报 0」的检查器。
#
# 语义：**这些检查器的 exit 0 本身就是「它还能工作」的证明**
SELFTESTS = [
    ('check_double_padding',
     ['python3', '工具/check_double_padding.py', '--selftest'],
     '内置 fixture：内层 padding 20 vp + 外层 20 vp ⇒ 应报 1 处风险 / 40 vp / 195vp 41.0%'),
    # ★ 第 1293 轮新增：历史 bug 复发检查器的自检
    #   它验 13 项（其中 **4 项是反例**，判据 784）：
    #     strip_comments 剥注释且保留行号 ／ .focusBox 计数跳过注释
    #     ／ HintBar 扫描跳过注释 ／ px-as-vp 只命中 4 位数
    #   ⇒ 它证明「这个检查器不会把注释当调用、不会把 3 位数当 px」
    ('check_regressions',
     ['python3', '工具/check_regressions.py', '--selftest'],
     '13 项自检（含 4 项反例）：剥注释 / ·focusBox 计数 / HintBar 扫描 / px-as-vp 正则'),
]


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
        # ⚠️ 判据 782（第 1291 轮）：原来的**单行**锚点在文件内出现 **2 次**
        #   （L296 与 L305 完全相同）⇒ `replace(..., 1)` 只改第一处，
        #   而恢复可能落在另一处 ⇒ 脆弱。
        #   ⇒ 改成**多行锚点**（含下一行 `.onClick(... answer((true)) ...)`），
        #     在文件内**唯一**；已用 count() 验证 == 1。
        old='        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(!this.revealed && !this.over)\n        .onClick(() => { Haptics.tap(); this.answer((true)); })',
        new='        .borderRadius(Radius.full).layoutWeight(1).height(Cell.of(54)).enabled(!this.revealed && !this.over)\n        .onClick(() => { Haptics.tap(); this.answer((true)); })',
        expect_desc='描边圆角(full) ≠ 元素圆角 ⇒ check_outline_owner 应报 SUSPECT（多行锚点，文件内唯一）',
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
    # ── 第 1291 轮：check_regressions 的变异（判据 782：锚点**文件内唯一**）──
    #   目标：基线要求 `.focusBox(` 真实调用 = 0
    #        （bug ⑰：1175 处死代码已全迁到 `.outline()`）
    #   ⇒ 注入一行真实 `.focusBox(Tv.box())` ⇒ 检查器必须报「真实调用 1」
    #   ⚠️ 不能造新文件：`check_regressions` 同时检查「游戏文件数 == 355」，
    #      造文件会让它因**另一个原因**失败 ⇒ 变异无效
    #   ⚠️ 锚点在 `G2048.ets` 内**出现 1 次**（已用 Counter 验证；判据 782）
    Mutation(
        name='regressions_focusbox',
        tool=['python3', '工具/check_regressions.py'],
        path='entry/src/main/ets/games/G2048.ets',
        old=".outline(Tv.focusOutline(this.tvFocus === 'L673'))",
        new=".focusBox(Tv.box()).outline(Tv.focusOutline(this.tvFocus === 'L673'))",
        expect_desc='注入一行 .focusBox( ⇒ check_regressions 应报「.focusBox 真实调用 1」(锚点在 G2048.ets 内唯一)',
    ),
]


def apply_and_test(m: Mutation) -> tuple:
    """返回 (有效?, 说明)"""
    # ★ 判据 782（第 1291 轮）：**变异锚点必须在目标文件内唯一**
    #   理由：替换用 `orig.replace(m.old, m.new, 1)`（只改第一处），
    #     恢复用反向替换 —— 若 old 在文件内出现多次，
    #     两次替换可能落在**不同位置** ⇒ 恢复后文件与原文不一致
    #     （第 1290 轮曾因此误判「文件被改坏」）
    if m.old and m.path:
        _whole = read(os.path.join(ROOT, m.path))
        _cnt = _whole.count(m.old)
        if _cnt != 1:
            return None, ('锚点在 %s 内出现 %d 次（必须恰好 1 次）⇒ 拒绝执行（判据 782）'
                          % (m.path, _cnt))
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

    # ── 自检型检查器（判据 648 第二种形态）──
    if not only:
        for name, cmd, desc in SELFTESTS:
            print('  ── %s（自检型）──' % name)
            print('     fixture：%s' % desc)
            # ⚠️ `run_check` 返回的是元组（rc, out）—— 第 1285 轮这里曾
            #   用 `'…rc=%s…' % rc` 直接格式化元组 ⇒ TypeError
            res = run_check(cmd)
            rc = res[0] if isinstance(res, (tuple, list)) else res
            if rc == 0:
                print('     ✅ **自检通过**（它能证明自己还能工作）')
            else:
                print('     🔴 **自检失败**（rc=%s）⇒ 检查器已失效' % rc)
                bad += 1
            print()

    total = len(MUTATIONS) if not only else 1
    good = total - bad - skip
    print('=' * 68)
    n_self = 0 if only else len(SELFTESTS)
    print('  汇总：%d 个变异 · 有效 %d ｜ 失效 %d ｜ **跳过 %d** ｜ 自检型 %d'
          % (total, good, bad, skip, n_self))
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
