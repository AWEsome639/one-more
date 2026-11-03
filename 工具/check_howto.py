#!/usr/bin/env python3
"""统计 `core/GameHowTo.ets` 的覆盖率，并校验每条的格式与 gameId 有效性。

★ 2026-11-02（判据 129）：说明页的「玩法要点」是**增量填充**的 ——
  没填的款会诚实降级到「通用玩法」。
  所以需要一个工具回答两个问题：
    ① 现在填了多少 / 总共多少（可数进度）
    ② 已填的 gameId 是否真的存在于 GAMES（防拼错）

用法：
  python3 工具/check_howto.py           # 覆盖率
  python3 工具/check_howto.py --list    # 也列出已填的 id
"""
import io
import os
import re
import sys

HOWTO = 'entry/src/main/ets/core/GameHowTo.ets'
REG = 'entry/src/main/ets/core/GameRegistry.ets'


def load_ids():
    src = io.open(REG, encoding='utf-8').read()
    return set(re.findall(r"id: '([a-z0-9_]+)'", src))


def load_howto():
    if not os.path.exists(HOWTO):
        return {}, []
    src = io.open(HOWTO, encoding='utf-8').read()
    ids = re.findall(r"^  '([a-z0-9_]+)': \{", src, re.M)
    # 逐条检查 zh / en 各几条
    out = {}
    for m in re.finditer(r"^  '([a-z0-9_]+)': \{\n    zh: \[(.*?)\],\n    en: \[(.*?)\]\n  \}", src, re.S | re.M):
        gid = m.group(1)
        zh = len(re.findall(r"'[^']+'", m.group(2)))
        en = len(re.findall(r"'[^']+'", m.group(3)))
        out[gid] = (zh, en)
    return out, ids


def src_of_howto():
    return io.open(HOWTO, encoding='utf-8').read()


def main():
    games = load_ids()
    howto, listed = load_howto()
    print('GAMES 总数：%d' % len(games))
    print('HOW_TO 已填：%d 款（覆盖率 %.1f%%）' % (len(listed), len(listed) * 100.0 / max(1, len(games))))
    bad_id = [g for g in listed if g not in games]
    bad_len = [(g, v) for g, v in howto.items() if v[0] != v[1] or v[0] < 2]
    if bad_id:
        print()
        print('❌ gameId 不存在于 GAMES（拼错了）：%s' % bad_id)
    if bad_len:
        print()
        print('❌ zh/en 条数不一致或过少（应 ≥2 且相等）：%s' % bad_len)
    if '--list' in sys.argv:
        print()
        for g in listed:
            v = howto.get(g, (0, 0))
            print('  %-24s zh=%d en=%d' % (g, v[0], v[1]))
    # ★ 2026-11-02（判据 133）：**检测规则文案里的 markdown 残留**。
    #   ArkUI 的 `Text()` **不渲染 markdown** ⇒ 写 `**墨色**` 会在屏幕上原样显示星号。
    #   （这个坑我踩过一次，还顺手把注释的 /** 也删了 ⇒ 225 个编译错。）
    md = []
    for m in re.finditer(r"^\s+'([^']*(?:\*\*|__|##|`)[^']*)'", src_of_howto(), re.M):
        md.append(m.group(1)[:40])
    if md:
        print()
        print('❌ 规则文案里含 markdown 标记（Text() 不渲染，会原样显示）：')
        for t in md[:8]:
            print('    %s' % t)
    if not bad_id and not bad_len and not md:
        print()
        print('✅ gameId 全部有效，zh/en 条数全部对齐，文案无 markdown 残留')
    return 1 if (bad_id or bad_len or md) else 0


if __name__ == '__main__':
    sys.exit(main())
