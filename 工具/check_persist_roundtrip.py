#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_persist_roundtrip.py —— 检查「写入的状态有没有在启动时读回」

★ 为什么需要（判据 878/879，第 1338 轮）
  实测：`favorites` 写盘了（`putSync` + `flush`），
        但 `init()` 里**没有** `AppStorage.setOrCreate(Keys.favorites, …)`
        ⇒ `favorites()` 只读 `AppStorage` ⇒ **重启后永远返回空**
        ⇒ 「收藏」这个功能**当次会话可用，重启即失**
  而同类 key 还有 12 个（achievements / cleared / perGameBest / …）

★ 判据 879：**写入 key 集合 − init 恢复 key 集合 = 「重启即失」清单**

用法:
  python3 工具/check_persist_roundtrip.py            # 扫 core/ProgressStore.ets
  python3 工具/check_persist_roundtrip.py --selftest
退出码: 0 = 全部配对 ｜ 1 = 有缺口 ｜ 2 = 输入/自检失败
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'entry/src/main/ets/core/ProgressStore.ets')


def analyze(src):
    """返回 (writes, restores, getsonly)"""
    writes = set()
    # ① putString(Keys.X, …)  ② putSync(Keys.X, …)  ③ pr.putSync('X', …)
    for m in re.finditer(r'putString\(\s*Keys\.([A-Za-z][A-Za-z0-9]*)', src):
        writes.add(m.group(1))
    for m in re.finditer(r'putSync\(\s*Keys\.([A-Za-z][A-Za-z0-9]*)', src):
        writes.add(m.group(1))
    for m in re.finditer(r"putSync\(\s*'([A-Za-z][A-Za-z0-9]*)'", src):
        writes.add(m.group(1))
    # ★★★ 2026-11-05（第 1348 轮，判据 919）：**裸字符串 key 也要算写入**
    #   实证：`ProgressStore.putString('dailyPick', gid)` 是裸字符串 key
    #     ⇒ 第一版检查器只认 `Keys.X` ⇒ **漏了它**
    #     ⇒ 而它正是「今日挑战永远无法完成」的根因（判据 918）
    for m in re.finditer(r"putString\(\s*'([A-Za-z][A-Za-z0-9]*)'", src):
        writes.add(m.group(1))
    for m in re.finditer(r"setOrCreate\(\s*Keys\.([A-Za-z][A-Za-z0-9]*)", src):
        pass  # setOrCreate 也是写内存，但不是「写盘」

    # 找 init() 段（从 `static async init` 到 `ready = true`）
    mi = re.search(r'static\s+(?:async\s+)?init\s*\(', src)
    if not mi:
        return writes, set(), set(), False
    end = src.find('ready = true', mi.start())
    seg = src[mi.start(): (end + 20) if end > 0 else len(src)]

    restores = set(re.findall(r'setOrCreate\(\s*Keys\.([A-Za-z][A-Za-z0-9]*)', seg))
    restores |= set(re.findall(r"setOrCreate\(\s*'([A-Za-z][A-Za-z0-9]*)'", seg))
    getsonly = set(re.findall(r"getSync\(\s*Keys\.([A-Za-z][A-Za-z0-9]*)", seg))
    getsonly |= set(re.findall(r"getSync\(\s*'([A-Za-z][A-Za-z0-9]*)'", seg))
    # ★★★ 2026-11-05（第 1348 轮，判据 921）：**收集「直读 pref」的 key**
    #   这类 key（`privacyAgreed` / `onboarded`）**每次调用都 `pr.getSync`**，
    #   根本不经过 AppStorage ⇒ **不需要 `setOrCreate` 恢复**
    direct_pref = set()
    for km in re.finditer(r'static\s+(?:async\s+)?(\w+)\s*\(', src):
        if km.group(1) == 'init':
            continue
        bi = src[:km.start()].count('\n')
        blines = src.split('\n')
        d = 0; bg = False; body = []
        for q in range(bi, min(len(blines), bi + 45)):
            d += blines[q].count('{') - blines[q].count('}')
            if '{' in blines[q]: bg = True
            body.append(blines[q])
            if bg and d <= 0: break
        btext = '\n'.join(body)
        for gm in re.finditer(r"getSync\(\s*'([A-Za-z][A-Za-z0-9]*)'", btext):
            direct_pref.add(gm.group(1))
        for gm in re.finditer(r'getSync\(\s*Keys\.([A-Za-z][A-Za-z0-9]*)', btext):
            direct_pref.add(gm.group(1))
    restores = restores | direct_pref          # 视作「已处理」
    getsonly = getsonly | direct_pref
    return writes, restores, getsonly, True


def main():
    if '--selftest' in sys.argv:
        # ★ 判据 759：先在已知真实案例上验证
        # 正例 = 本轮真 bug 的最小复刻
        POS = '''
static async init(ctx) {
  AppStorage.setOrCreate(Keys.xp, 1);
  ProgressStore.ready = true;
}
static toggleFavorite(id) {
  AppStorage.setOrCreate(Keys.favorites, id);
  ProgressStore.putString(Keys.favorites, id);
}
'''
        # 反例 = 修好之后（init 里也有 favorites）
        NEG = '''
static async init(ctx) {
  AppStorage.setOrCreate(Keys.xp, 1);
  AppStorage.setOrCreate(Keys.favorites, p.getSync(Keys.favorites, ''));
  ProgressStore.ready = true;
}
static toggleFavorite(id) {
  ProgressStore.putString(Keys.favorites, id);
}
'''
        w1, r1, g1, ok1 = analyze(POS)
        w2, r2, g2, ok2 = analyze(NEG)
        miss1 = w1 - r1 - g1
        miss2 = w2 - r2 - g2
        good = ok1 and ok2 and ('favorites' in miss1) and (not miss2)
        print('=' * 72)
        print('  自检（判据 759 + 855：正例必须报、反例必须不报）')
        print('=' * 72)
        print('  正例：favorites 在缺口里 ⇒ %s' % ('✅' if 'favorites' in miss1 else '🔴 漏'))
        print('  反例：favorites **不**在缺口里 ⇒ %s' % ('✅' if 'favorites' not in miss2 else '🔴 误报'))
        print()
        print('  ⇒ %s' % ('✅ 自检通过' if good else '🔴 自检失败'))
        return 0 if good else 2

    if not os.path.exists(TARGET):
        print('  找不到 %s' % TARGET)
        return 2
    src = io.open(TARGET, encoding='utf-8').read()
    writes, restores, getsonly, found = analyze(src)
    if not found:
        print('  ⚠️ 找不到 init()')
        return 2

    print('=' * 76)
    print('  持久化往返检查（写入 key vs init 恢复 key）')
    print('=' * 76)
    print('  写入 key（putString / putSync）: **%d** 个' % len(writes))
    print('  init 里 setOrCreate 恢复:       **%d** 个' % len(restores))
    print('  init 里 getSync 读过:           **%d** 个' % len(getsonly))
    print()

    missing = sorted(writes - restores - getsonly)
    readonly = sorted((writes & getsonly) - restores)

    if missing:
        print('  🔴 **写了但 init 完全没碰（重启即失）: %d 个**' % len(missing))
        for k in missing:
            print('      %-16s ⇒ 重启后 AppStorage 里没有它' % k)
        print()
    if readonly:
        print('  ⚠️ **getSync 读了但没 setOrCreate（读进局部变量，没进内存）: %d 个**' % len(readonly))
        for k in readonly:
            print('      %-16s ⇒ 需要补 setOrCreate' % k)
        print()

    if not missing and not readonly:
        print('  ✅ 全部配对（写入的都在 init 里恢复了）')
        return 0

    print('  ⇒ 判据 878/879：**只写不读 = 数据永久丢失，而写入看起来成功**')
    print('  ⇒ 修法：在 init() 里对每个 key 补一行')
    print('       AppStorage.setOrCreate(Keys.X, p.getSync(Keys.X, <默认值>));')
    return 1


if __name__ == '__main__':
    sys.exit(main())
