#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""budget.py —— 布局预算计算器（判据 2040 / 2109 的可执行版）

为什么要有这个工具
------------------
`2026-11-14` 我在同一个病根上连错三次：**把 `Cell.of(base)` 的 base 当成实际 vp**。
- 上午算 `BoardMax`：用 raw 值
- 下午算 `BlockCount3D`：`3 × 88 = 264vp`，实际 `3 × Cell.of(88) = 3 × 75 = 225vp`（多算 39vp）
- 同一天还差点推荐 `88→82`（省 15vp），而实际需要 16vp ⇒ **差 1vp 不达标**

⇒ 把公式写成代码，让「手算」这一步消失。

用法
----
  python3 工具/budget.py                  # 打印模型与常数（含自检）
  python3 工具/budget.py 88 88 88         # 三个 base ⇒ 每个渲染值、合计、剩余
  python3 工具/budget.py --need 16 88     # 已知要省 16vp，求 base 要降到多少
  python3 工具/budget.py --selftest       # 只跑自检
"""
import sys

# ── 常量（口径写死在这里，不要在调用处重算）──────────────────────────
H_VP   = 533.0   # 手机 onemore7：2560×1600 @480 ⇒ 853×533 vp（判据已验证多次）
HEADER = 104.0   # 头部：状态栏 39 + 顶栏 45 + padding 20
K      = 1.0     # Cell.k 默认值（Design.ets:93 `static k: number = 1`）
SCALE  = 1.0     # 手机 Bp.scale() = 1.0
SHRINK = 0.85    # Design.ets:100-112：Bp.height < 600 且非电视时 ×0.85


def cell_of(base, k=K, scale=SCALE, shrink=SHRINK):
    """复刻 Design.ets:100 的 Cell.of —— round(base × k × scale × shrink)"""
    return int(round(base * k * scale * shrink))


def content_vp():
    return H_VP - HEADER


def report(bases, need_save=0.0):
    c = content_vp()
    total = 0
    print('预算：屏幕 %.0f − 头部 %.0f = **内容区 %.0f vp**（shrink=%.2f）' % (H_VP, HEADER, c, SHRINK))
    print()
    print('  %-8s %-10s %s' % ('base', 'Cell.of', '累计'))
    for b in bases:
        v = cell_of(b)
        total += v
        print('  %-8s %-10s %d' % (b, '%d vp' % v, total))
    print()
    print('合计 %.0f vp ｜ 剩余 %.0f vp' % (total, c - total))
    if need_save > 0:
        print('\n需要再省 %.0f vp（按实测溢出）' % need_save)
        print('  %-8s %-10s %-10s %s' % ('base', 'Cell.of', '相对当前省', '够不够'))
        cur = cell_of(bases[0]) if bases else 0
        n = len(bases) or 1
        for cand in range(int(bases[0]) if bases else 88, 60, -1):
            saved = (cur - cell_of(cand)) * n
            mark = '✅ 够' if saved >= need_save else '❌ 差 %.0f' % (need_save - saved)
            if cand % 2 == 0 or saved >= need_save:
                print('  %-8d %-10s %-10d %s' % (cand, '%d vp' % cell_of(cand), saved, mark))
            if saved >= need_save + 12:
                break
    return total


def selftest():
    """自检：用代码注释里**已知的实测值**校验本工具"""
    ok = True
    # ① Design.ets:105 注释「4 行按钮 192 → 163」
    got = cell_of(48) * 4
    exp_lo, exp_hi = 160, 166
    print('① Sokoban 四行按钮：Cell.of(48)×4 = %d vp（注释写 192→163）' % got)
    if not (exp_lo <= got <= exp_hi):
        print('   ❌ 应在 %d–%d' % (exp_lo, exp_hi)); ok = False
    else:
        print('   ✅ 落在预期区间')
    # ② 88 的三个档（我今天算错的那些）
    cases = {88: 75, 84: 71, 82: 70, 80: 68, 112: 95}
    print('\n② Cell.of 关键值：')
    for b, exp in cases.items():
        v = cell_of(b)
        mark = '✅' if v == exp else '❌ 应为 %d' % exp
        print('   Cell.of(%3d) = %2d vp  %s' % (b, v, mark))
        if v != exp:
            ok = False
    # ③ 预算
    print('\n③ 内容区 = %.0f vp（应 429）' % content_vp())
    if content_vp() != 429:
        print('   ❌'); ok = False
    else:
        print('   ✅')
    print('\n=> 自检 %s' % ('全部通过' if ok else '有失败项'))
    return 0 if ok else 1


def main():
    a = sys.argv[1:]
    if not a or a[0] in ('-h', '--help'):
        print(__doc__)
        return 0
    if a[0] == '--selftest':
        return selftest()
    if a[0] == '--need':
        # ⚠️ 必须给 --count！`2026-11-14` 这个模式第一版忘了乘数量，
        #    对「三行」的情形给出 `88→69`，而正确答案是 `88→80`（省 3×7=21vp）。
        #    ⇒ 与判据 2109 同源：漏一个乘数就错一整档。
        if len(a) < 4:
            print('用法: budget.py --need <要省的vp> <当前base> <有几个>')
            print('  例: budget.py --need 16 88 3     # 三行，每行 base=88')
            return 1
        need = float(a[1]); base = float(a[2]); cnt = int(a[3])
        print('目标：再省 %.0f vp（当前 base=%g ⇒ Cell.of=%d，共 %d 个，合计 %dvp）'
              % (need, base, cell_of(base), cnt, cell_of(base) * cnt))
        print()
        for cand in range(int(base), 40, -1):
            saved = (cell_of(base) - cell_of(cand)) * cnt
            if saved >= need:
                print('⇒ **最小可行 base = %d**（Cell.of=%d，省 %dvp = %d×%d，余量 %.0f）'
                      % (cand, cell_of(cand), saved, cell_of(base) - cell_of(cand), cnt, saved - need))
                break
        else:
            print('⇒ 降到底也不够')
        return 0
    try:
        bases = [float(x) for x in a]
    except ValueError:
        print('参数必须是数字或 --selftest / --need'); return 1
    report(bases)
    return 0


if __name__ == '__main__':
    sys.exit(main() or 0)
