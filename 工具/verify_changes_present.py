#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2026-11-14：**改动在位核对** —— 确认这批改动没有被后续编辑吃掉

为什么需要它：
    今天有 `37` 处改动，每处都用「整行替换」手工定位行号改的。
    而今天**已经发生过一次**「脚本把行首 `}` 吃掉」的事故 ⇒ 同理也可能把改动本身改丢。
    `preflight.sh` 只查语法对不对，**不查改动还在不在**。

判据：
    每处改动有一个「特征串」。特征串在 ⇒ 改动在位；不在 ⇒ 被吃掉了。

用法：
    python3 工具/verify_changes_present.py

注意：
    这是**本批改动**的清单（`2026-11-14`）。改完之后记得更新这里的 `checks`，
    或者把它当成「一次性的交付核对」用。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games')

# (类名, 特征串, 说明)
CHECKS = [
    ('GFractionMatcher', "padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg)", '题卡 padding md→sm（配 2×2 收 36px）'),
    ('GShikaku', 'Math.max(200, Bp.height - 360)', '白天·下限 240→200（blk 72→0）'),
    ('GMagnets', 'Bp.height - 375', 'A①盘面 173→158vp'),
    ('GPythagoreanTripleBuilder', '? Space.xs : Space.md', 'A③外层间距 sm→xs（省 72px）'),
    # ⛔⛔ 2026-11-14 作废：`GWordle` 套 `Scroll` 后**中间全黑、棋盘与键盘都没渲染**
    #   （`.height('100%')` 被注释掉之后，`Scroll` 里的内容没有内在高度 ⇒ 高度 0）。
    #   已在 `68bc832a` 回滚到 `b2cacc75` 那个「十四次收敛」的修好版本。
    #   ⇒ **不要再给 `GWordle` 套 `Scroll`**；它原本的修法是「键盘给 `120vp`」。
    ('GWordle', 'KEY_H', '键盘行高常量 KEY_H（勿改回 Scroll）'),
    ('G2048', 'Bp.height - 360', '限宽'),
    ('GBlockCount3d', 'Bp.isShort() ? 76 : 112', '题面格高降档（88→76，blk 31→0）'),
    ('GCalculationSprint', 'Bp.isShort() ? FontSize.xl : FontSize.hero', '题卡降档'),
    ('GCollatz', 'Bp.isShort() ? FontSize.xxl : FontSize.hero', '题卡降档'),
    ('GCrown', 'Bp.height - 360', '限宽'),
    ('GDominosa', 'Bp.height - 360', '限宽'),
    ('GFractionMatcher', 'Bp.isShort() ? FontSize.xxl', '题卡降档'),
    ('GGokigenNaname', 'Bp.height - 360', '限宽'),
    ('GGomoku', 'Bp.height - 360', '限宽'),
    ('GHeyawake', 'Bp.height - 360', '限宽'),
    ('GHitori', 'Bp.height - 360', '限宽'),
    ('GHitoriAll', 'Bp.height - 360', '限宽'),
    ('GMastermind', 'Math.max(200, Bp.height - 260)', '三行圆点限宽'),
    ('GMatrixReasoning', 'Bp.height - 388', '限宽'),
    ('GMemory', 'Bp.height - 360', '限宽'),
    ('GModuloClock', 'Bp.isShort() ? FontSize.xl : FontSize.hero', '题卡降档'),
    ('GModuloPath', 'Bp.height - 360', '限宽'),
    ('GNoriNori', 'Bp.height - 360', '限宽'),
    ('GPathIntersect', 'Bp.height - 360', '限宽'),
    ('GPatternSequenceDraw', 'Bp.isShort() ? 32 : 0', '盘面底部留白'),
    ('GPercentagePeak', 'Bp.isShort() ? FontSize.lg', '题卡降档'),
    ('GPipes', 'Bp.height - 360', '限宽'),
    ('GPythagoreanTripleBuilder', 'Bp.isShort() ? FontSize.xxl : FontSize.hero', '题卡降档'),
    ('GShikaku', 'Bp.height - 360', '限宽'),
    ('GSimonSays', '2 * Math.max(140, Bp.height - 200)', '限行宽'),   # ★ 2026-11-14：原特征串落在注释上，改成**代码行**
    ('GSkyscrapers', 'Bp.height - 360', '限宽'),
    ('GSnake3D', 'Bp.height - 180', '限整行宽'),
    ('GTargetNumber', 'Bp.isShort() ? FontSize.xl : FontSize.xxxl', '题卡降档'),
    ('GVisualSearchAll', 'Bp.height - 220', '限宽'),
    ('GWordLadder', 'Bp.isShort() ? 48 : 60', '词格降档'),
    ('GNumberBondsAll', 'Bp.height - 300', '限宽'),
    ('GKakuroMini', 'maxWidth: Bp.height < 600', '盘面再收'),   # ★ 同上：原来会匹配注释
    ('GKakuro', 'Bp.isShort() && !this.over', '提示行隐藏'),
    ('GSchulte', 'Bp.height - 360', '限宽'),
    ('GCountdownMath', 'Bp.height - 360', '限宽'),
    ('GFactorFinder', 'Bp.height - 360', '限宽'),
    ('GPercentageShopping', 'Bp.isShort() ? FontSize.xxl : FontSize.hero', '题卡降档'),
    ('GBinaryMatrixRank', 'Cell.of(28)', '矩阵格降档'),
]


def main():
    ok = 0
    miss = []
    pending = []
    for cls, pat, desc in CHECKS:
        p = os.path.join(GAMES, '%s.ets' % cls)
        if not os.path.exists(p):
            miss.append((cls, '文件不存在', desc))
            continue
        s = io.open(p, encoding='utf-8').read()
        if pat in s:
            ok += 1
        elif desc[:2] in ('A①', 'A②', 'A③', 'A④'):
            # ★ 2026-11-14：A 档四项是**明天才应用**的改动（今晚装的是改之前的 HAP）
            #   ⇒ 它们不在位是**预期状态**，不是「被后编辑吃掉」⇒ 记为待应用、不计失败。
            #   ⚠️ 按 desc 前缀区分而不是按类名：GFractionMatcher 同时有「A②题卡 padding」（待应用）
            #      和「Bp.isShort() ? FontSize.xxl」（已应用），按类名豁免会连已应用的也放过。
            #   ⚠️ A 档应用完之后，这些条目的 desc 应去掉 A 前缀（或出现即算 ok，本条自动不再触发）。
            pending.append((cls, desc))
        else:
            miss.append((cls, '缺「%s」' % pat, desc))

    # ★ 2026-11-14（判据 2005）：**先断言「清单本身没缩水」**
    #   否则有人删掉几条 CHECKS，脚本会在更少的条目上照样报 ✅。
    if len(CHECKS) < 37:
        print('❌ 清单只有 %d 条（预期 ≥37）⇒ 有人在删条目，结论不可信' % len(CHECKS))
        return 2
    print('== 改动在位核对：%d 处 ==' % len(CHECKS))
    if pending:
        print('⏸ %d 处待明天应用（A 档，今晚装的是改之前的 HAP）：' % len(pending))
        for cls, desc in pending:
            print('  %-30s %s' % (cls, desc))
    if miss:
        print('❌ %d 处不在位：' % len(miss))
        for cls, why, desc in miss:
            print('  %-30s %s（%s）' % (cls, why, desc))
        print('\n⇒ 说明这批改动里有被后续编辑吃掉的，**先修这个再 build**。')
        return 1
    print('✅ %d 处全部在位（改动没被吃掉）' % ok)
    print('⇒ 可以 build。build 之后跑 `bash 工具/verify_changed.sh` 看台账。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
