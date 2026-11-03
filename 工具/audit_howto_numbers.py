#!/usr/bin/env python3
"""交叉核对：howTo 文案里写的每个「数字」，是否在该游戏的源码里出现过。

★ 2026-11-02（判据 132/161）：
   「显示得出来」已真机验证 8 次；剩下真正的风险是**内容写错**
   （比如源码是 6 轮、我写成 8 轮）。这一类错误**不需要真机**就能查：
   把它文案里的数字，回源码里找一遍 —— 找不到的就是可疑项。

局限性（必须诚实）：
   · 源码里的数字可能以 `const TOTAL = 8` 形式出现 ⇒ 文案写 8 会命中
   · 也可能以 `8` 直接写在表达式里 ⇒ 也能命中
   · 但如果源码用变量名（`TOTAL`）而文案写 8，**源码里找不到字面 8** ⇒ 假阳性
   ⇒ 所以这个工具**只输出"待人工确认"清单**，不直接判错。

用法：
  python3 工具/audit_howto_numbers.py            # 全部
  python3 工具/audit_howto_numbers.py --limit 20 # 只看前 20 条可疑
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOWTO = os.path.join(ROOT, 'entry/src/main/ets/core/GameHowTo.ets')
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')


def load_howto():
    src = io.open(HOWTO, encoding='utf-8').read()
    out = []
    for m in re.finditer(r"^  '([a-z0-9_]+)': \{\n    zh: \[(.*?)\],\n    en: \[", src, re.S | re.M):
        gid = m.group(1)
        items = re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(2))
        out.append((gid, [x.replace("\\'", "'") for x in items]))
    return out


def find_source(gid):
    """在 games/ 里找哪个文件含 'id: gid' 或 "'gid'"，返回文件全文"""
    for fn in os.listdir(GAMES):
        if not fn.endswith('.ets') or '.bak' in fn:
            continue
        p = os.path.join(GAMES, fn)
        try:
            txt = io.open(p, encoding='utf-8').read()
        except Exception:
            continue
        if ("'%s'" % gid) in txt or ('"%s"' % gid) in txt:
            return fn, txt
    return None, ''


def main():
    args = sys.argv[1:]
    limit = None
    if '--limit' in args:
        limit = int(args[args.index('--limit') + 1])
    howto = load_howto()
    print('howTo 条目：%d' % len(howto))
    print()
    suspicious = []
    missing_src = []
    for gid, zh_items in howto:
        fn, txt = find_source(gid)
        if not txt:
            missing_src.append(gid)
            continue
        # 提取文案里的数字（≥2 的数字才查，1 太常见）
        nums = set()
        for it in zh_items:
            for n in re.findall(r'\d+', it):
                if len(n) >= 1 and int(n) >= 2:
                    nums.add(n)
        if not nums:
            continue
        absent = sorted([n for n in nums if not re.search(r'(?<!\d)%s(?!\d)' % re.escape(n), txt)])
        if absent:
            suspicious.append((gid, fn, absent, zh_items[0][:40]))
    print('✅ 找到源码：%d' % (len(howto) - len(missing_src)))
    if missing_src:
        print('⚠️ 找不到源码（%d）：%s' % (len(missing_src), ', '.join(missing_src[:10])))
    print()
    print('可疑项（文案里的数字在源码中找不到字面）：%d' % len(suspicious))
    show = suspicious[:limit] if limit else suspicious
    for gid, fn, absent, first in show:
        print('  %-28s %-26s 缺：%s' % (gid, fn, ','.join(absent)))
        print('      「%s…」' % first)
    print()
    print('⚠️ 这是"待人工确认"清单，不是错误清单 ——')
    print('   源码可能用常量名（如 TOTAL），此时字面数字本来就不出现。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
