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

# ★ 2026-11-20（判据 3085）：版本号只在这一处维护，升版本时改这里就行。
EXPECT_VER: str = '2.0.1'

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERBOSE = '-v' in sys.argv or '--verbose' in sys.argv

# (标签, 文件, 必须出现的特征串, 判据)
CHECKS = [
    # ── 2026-11-19 修好的 9 款 ──────────────────────────────────────────────
    ('Simon Command 横屏限宽', 'entry/src/main/ets/games/GSimonCommand.ets',
     '1.15 * (Bp.height - 400) + 10', '3052'),
    # ★ 2026-11-20（判据 3089）：竖屏分支**不再逐字不变**了 —— 原来 `'100%'` 会让
    #   两行四色面板竖向超屏（底部绿/黄各切一半）。改成与横屏同一套高度反推、扣 424。
    # ★ 2026-11-24 更新：424 在 fold 2224x2496 上仍让「不做动作」压手势条（bottom=2496），
    #   实测 476 后 bottom 2496→2477、blk=0、按钮与提示行完整（截图-Simon_Command-185601.jpeg）
    #   ⇒ 期望值改为 476（原 424 的历史见 3089）。
    ('Simon Command 竖屏高度反推', 'entry/src/main/ets/games/GSimonCommand.ets',
     'Bp.height - 476', '3089'),
    ('Shadow Pivot 竖屏容器', 'entry/src/main/ets/games/GShadowPivot.ets',
     'Bp.height - 643', '3048/3053'),
    ('Shadow Pivot 横屏 32%', 'entry/src/main/ets/games/GShadowPivot.ets',
     "? '28%'", '3060'),
    ('Simon Says 两行都限宽', 'entry/src/main/ets/games/GSimonSays.ets',
     # ★ 2026-11-21（判据 3097）：竖屏常数从 230 改成 536（四块全完整），横屏 410 不动。
     'Bp.height - (Bp.isShort() ? 410 : 536)', '3097'),
    # ★ 2026-11-25：fold 上第 4 行卡片被「重新开始」压住 ⇒ 网格宽上限改 420（仅高屏），
    #   实测 bottom 2374→2173、4 行全见（截图-Memory-050336.jpeg）。
    ('Memory 下限 160 / 高屏 420', 'entry/src/main/ets/games/GMemory.ets',
     'Math.max(160, Bp.height - (Bp.isShort() ? 360 : 420))', '3058'),
    ('Memory 矮屏隐藏重复控件', 'entry/src/main/ets/games/GMemory.ets',
     'Visibility.None', '3058'),
    ('Crossword 下限 130 / N 400', 'entry/src/main/ets/games/GCrossword.ets',
     'Bp.height - (Bp.isShort() ? 400 : 500)', '3054'),
    ('Collatz 按钮 34→24', 'entry/src/main/ets/games/GCollatz.ets',
     'Bp.isShort() ? 24 : 46', '3059'),
    # ★ 2026-11-25：fold 2224x2496 上 bottom=2481 压手势线 ⇒ 496 实测 2456 / blk=0。
    ('Kakuro 棋盘 -496', 'entry/src/main/ets/games/GKakuro.ets',
     'Bp.height - 496', '3065'),
    ('Word Mastermind 键盘间距', 'entry/src/main/ets/games/GWordMastermind.ets',
     'Column({ space: 2 })', '3065'),
    ('Silhouette Match Ortho gs -494', 'entry/src/main/ets/games/GSilhouetteMatchOrtho.ets',
     'Bp.height - 494', '3066'),
    # ── 迁移与版本 ─────────────────────────────────────────────────────────
    ('API 20 下限（debug 配置）', 'build-profile.json5', '6.0.0(20)', '3051'),
    # ★ 2026-11-20（判据 3077）：**出包用的那份配置也要查** ——
    #   它当时还是 `5.0.0(12)`，导致第一个 release 包 `minAPIVersion=50000012`。
    ('API 20 下限（release 配置）', 'build-profile.json5.release-signed', '6.0.0(20)', '3077'),
    ('版本 %s（About）' % EXPECT_VER, 'entry/src/main/ets/core/About.ets', "'%s'" % EXPECT_VER, '3051'),
    ('版本 %s（app.json5）' % EXPECT_VER, 'AppScope/app.json5', '"versionName": "%s"' % EXPECT_VER, '3051'),
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

def check_release_hap():
    """★ 2026-11-20（判据 3077）：**检查已构建的 release 包声明与实际一致**。

    为什么单列一个函数：特征串检查只能看源码，看不出「出包时用的配置对不对」。
    今天真的出过一个 `minAPIVersion=50000012` 的错包（release-signed 配置停在 API 12），
    而源码里 `build-profile.json5` 是对的 —— 光查源码永远发现不了。

    返回 (ok, 说明)。没有包时返回 None（跳过，不算失败）。
    """
    import glob, json, zipfile
    # ★ 2026-11-20：**应用市场要的是 `.app`，不是 `.hap`**（判据 3081）。
    #   `.hap` 是模块包；上架/邀请测试的「软件版本」只吃 `.app`（应用包）。
    haps = sorted(glob.glob(os.path.join(ROOT, 'release', 'onemore-*-release-signed-*.hap'))
                  + glob.glob(os.path.join(ROOT, 'release', 'onemore-*-release-signed-*.app')))
    if not haps:
        return None, '没有 release 包（跳过）'
    hap = haps[-1]
    try:
        with zipfile.ZipFile(hap) as z:
            names = z.namelist()
            if 'module.json' in names:          # .hap
                with z.open('module.json') as f:
                    app = json.load(f).get('app', {})
            elif 'pack.info' in names:          # .app
                info = json.loads(z.open('pack.info').read().decode('utf-8'))
                a0 = (info.get('summary') or {}).get('app') or {}
                v = a0.get('version') or {}
                app = {'versionName': v.get('name'), 'versionCode': v.get('code'),
                       'minAPIVersion': None}
                # ★ 2026-11-20（判据 3081）：`.app` 的 minAPIVersion 不在 pack.info 里，
                #   必须把内层 hap 抽出来再读 module.json —— 否则这个字段永远是 None、等于没查。
                inner = [n for n in names if n.endswith('.hap')]
                if inner:
                    import tempfile, os as _os
                    with tempfile.TemporaryDirectory() as td:
                        hap_path = z.extract(inner[0], td)
                        with zipfile.ZipFile(hap_path) as z2:
                            if 'module.json' in z2.namelist():
                                app['minAPIVersion'] = json.load(
                                    z2.open('module.json')).get('app', {}).get('minAPIVersion')
            else:
                return False, '%s 里既没有 module.json 也没有 pack.info' % os.path.basename(hap)
    except Exception as e:
        return False, '读 %s 失败：%s' % (os.path.basename(hap), str(e)[:50])
    api = app.get('minAPIVersion')
    ver = app.get('versionName')
    name = os.path.basename(hap)
    if api is not None and api != 60000020:
        return False, '%s 的 minAPIVersion=%s（期望 %s）' % (name, api, 60000020)
    if ver != EXPECT_VER:
        return False, '%s 的 versionName=%s（期望 %s）' % (name, ver, EXPECT_VER)
    return True, '%s · minAPIVersion %s · %s' % (name[-32:], api, ver)


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
    # ── release 包校验（判据 3077）────────────────────────────────────────
    hap_ok, hap_msg = check_release_hap()
    if hap_ok is False:
        bad.append(('release 包声明', 'release/*.hap', hap_msg, '3077'))
        print('  ❌ release 包：%s' % hap_msg)
    elif VERBOSE:
        print('  %s release 包：%s' % ('✅' if hap_ok else '⏭ ', hap_msg))

    print()
    if bad:
        print('❌ 交付完整性：%d/%d 项缺失 —— 有改动被回滚或替换掉了' % (len(bad), len(CHECKS)))
        return 1
    print('✅ 交付完整性：%d 项全部在位' % len(CHECKS))
    return 0

if __name__ == '__main__':
    sys.exit(main())
