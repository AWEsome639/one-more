#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
One More 交付完整性核查 —— 判据 `3076`

**为什么需要它**：版面修复是一行两行的常量改动，很容易被后来的「回滚 / 批量替换 /
cherry-pick」静默抹掉，而台账不会告诉你（台账只记「量过什么」，不记「代码里还有什么」）。

⇒ 这个脚本把「已交付的每一处改动」写成**可搜索的特征串**，一条命令验证它们在不在。

用法：
    python3 工具/check_deliverables.py          # 全查（缺失则退出码 1）
    python3 工具/check_deliverables.py -v       # 连通过项也打印
"""
import io, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERBOSE = '-v' in sys.argv or '--verbose' in sys.argv

# (标签, 文件, 必须出现的特征串, 判据)
CHECKS = [
    # ── 2026-11-19 修好的 9 款 ──────────────────────────────────────────────
    ('Simon Command 横屏限宽', 'entry/src/main/ets/games/GSimonCommand.ets',
     '1.4 * (Bp.height - 400) + 10', '3052'),
    ('Simon Command 竖屏逐字不变', 'entry/src/main/ets/games/GSimonCommand.ets',
     ": '100%')", '3052'),
    ('Shadow Pivot 竖屏容器', 'entry/src/main/ets/games/GShadowPivot.ets',
     'Bp.height - 643', '3048/3053'),
    ('Shadow Pivot 横屏 32%', 'entry/src/main/ets/games/GShadowPivot.ets',
     "? '32%'", '3060'),
    ('Simon Says 两行都限宽', 'entry/src/main/ets/games/GSimonSays.ets',
     'Bp.height - (Bp.isShort() ? 410 : 230)', '3057'),
    ('Memory 下限 160', 'entry/src/main/ets/games/GMemory.ets',
     'Math.max(160, Bp.height - 360)', '3058'),
    ('Memory 矮屏隐藏重复控件', 'entry/src/main/ets/games/GMemory.ets',
     'Visibility.None', '3058'),
    ('Crossword 下限 130 / N 400', 'entry/src/main/ets/games/GCrossword.ets',
     'Bp.height - (Bp.isShort() ? 400 : 500)', '3054'),
    ('Collatz 按钮 34→24', 'entry/src/main/ets/games/GCollatz.ets',
     'Bp.isShort() ? 24 : 46', '3059'),
    ('Kakuro 棋盘 -488', 'entry/src/main/ets/games/GKakuro.ets',
     'Bp.height - 488', '3065'),
    ('Word Mastermind 键盘间距', 'entry/src/main/ets/games/GWordMastermind.ets',
     'Column({ space: 2 })', '3065'),
    ('Silhouette Match Ortho gs -494', 'entry/src/main/ets/games/GSilhouetteMatchOrtho.ets',
     'Bp.height - 494', '3066'),
    # ── 迁移与版本 ─────────────────────────────────────────────────────────
    ('API 20 下限', 'build-profile.json5', '6.0.0(20)', '3051'),
    ('版本 2.0.0（About）', 'entry/src/main/ets/core/About.ets', "'2.0.0'", '3051'),
    ('版本 2.0.0（app.json5）', 'AppScope/app.json5', '"versionName": "2.0.0"', '3051'),
    # ── 端侧 AI ────────────────────────────────────────────────────────────
    ('LocalLLM 运行时存在性检查', 'entry/src/main/ets/core/LocalLLM.ets',
     'localChatModel.init === undefined', '3062'),
    ('RAG schema 文件', 'entry/src/main/resources/rawfile/arkdata/knowledge/knowledge_schema.json',
     'onemore_kb.db', '3061'),
    ('RAG 自检类', 'entry/src/main/ets/core/LocalKRagSelfTest.ets',
     'getKnowledgeProcessor', '3062'),
    ('RAG 自检入口（ragTest）', 'entry/src/main/ets/entryability/EntryAbility.ets',
     'ragTest', '3062'),
    # ── 不联网条款 ─────────────────────────────────────────────────────────
    ('局域网 socket 仍是唯一网络用法', 'entry/src/main/ets/core/Lan.ets',
     "@kit.NetworkKit", '3051'),
]

def main():
    bad = []
    for label, rel, needle, judge in CHECKS:
        path = os.path.join(ROOT, rel)
        try:
            s = io.open(path, encoding='utf-8', errors='replace').read()
            ok = needle in s
        except FileNotFoundError:
            ok = False
        if not ok:
            bad.append((label, rel, needle, judge))
            print('  ❌ %-28s 缺失 <%s>  (判据 %s)' % (label, needle[:28], judge))
        elif VERBOSE:
            print('  ✅ %-28s (判据 %s)' % (label, judge))
    print()
    if bad:
        print('❌ 交付完整性：%d/%d 项缺失 —— 有改动被回滚或替换掉了' % (len(bad), len(CHECKS)))
        return 1
    print('✅ 交付完整性：%d 项全部在位' % len(CHECKS))
    return 0

if __name__ == '__main__':
    sys.exit(main())
