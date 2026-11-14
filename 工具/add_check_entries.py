#!/usr/bin/env python3
"""明晚改完五处后，往 verify_changes_present.py 的 CHECKS 与 verify_changed.sh 的 CASES 里
补 5 条「断言片段还在」的条目 —— 否则改动被后来的提交悄悄覆盖也没人知道。

用法：python3 工具/add_check_entries.py --dry   # 只打印
      python3 工具/add_check_entries.py         # 真写（幂等：已存在的跳过）

⚠️ 必须在「改完代码 + 编译通过 + 断言 200359/0」之后运行，早跑会让中间那次提交断言失败。
"""
import io, sys, re

DRY = '--dry' in sys.argv
PRESENT = '工具/verify_changes_present.py'
CHANGED = '工具/verify_changed.sh'

# (文件, 断言片段, 说明) —— 第一项.ets 文件名不带扩展名
NEW = [
    ('GMagnets',            'Bp.height - 375',                                            '①盘面 173→158vp'),
    ('GFractionMatcher',    ".width('100%').padding(Space.md).backgroundColor(this.theme.surface)", '②题卡 padding lg→md'),
    ('GPercentageShopping', ".width('100%').padding(Space.md).backgroundColor(this.theme.surface)", '③题卡 padding lg→md'),
    ('GKakuroMini',         'Bp.height - 390',                                            '④盘面 173→143vp'),
    ('GWordle',             'Scroll()',                                                   '⑤套 Scroll 兜底'),
]
# CASES 用「游戏显示名|描述|改前」
NEW_CASES = [
    ('Magnets',              '盘面 173→158vp（线索格露出 6%→74%）',      '15vp'),
    ('Fraction Matcher',     '题卡 padding lg→md（选项行露出 37%→76%）', '16vp'),
    ('Percentage Shopping',  '题卡 padding lg→md（选项行露出 30%→68%）', '16vp'),
    ('Kakuro Mini',          '盘面 173→143vp（键盘行露出 9%→77%）',      '30vp'),
    ('Wordle',               '套 Scroll 兜底（按钮露出 23%→可滚达）',    '—'),
]

sp = io.open(PRESENT, encoding='utf-8').read()
sc = io.open(CHANGED, encoding='utf-8').read()
add_p, add_c = [], []

for f, snip, desc in NEW:
    if "'%s'" % snip in sp:
        print('⏭  %s：断言片段已在，跳过' % desc); continue
    add_p.append("    ('%s', %r, '%s')," % (f, snip, desc))

for name, desc, before in NEW_CASES:
    if '"%s|' % name in sc:
        print('⏭  %s：CASES 已有，跳过' % name); continue
    add_c.append('  "%s|%s|%s"' % (name, desc, before))

print('CHECKS 待加 %d 条、CASES 待加 %d 条' % (len(add_p), len(add_c)))
for x in add_p: print('  + %s' % x.strip()[:100])
for x in add_c: print('  + %s' % x.strip()[:100])

if DRY:
    print('（--dry：未写）'); sys.exit(0)
if not add_p and not add_c:
    print('无需改动'); sys.exit(0)

# 插到 CHECKS = [ 之后（保持列表开头，便于看）
i = sp.index('CHECKS = [') + len('CHECKS = [')
sp = sp[:i] + '\n' + '\n'.join(add_p) + sp[i:]
# 插到 CASES=( 之后
j = sc.index('CASES=(') + len('CASES=(')
sc = sc[:j] + '\n' + '\n'.join(add_c) + sc[j:]

io.open(PRESENT, 'w', encoding='utf-8').write(sp)
io.open(CHANGED, 'w', encoding='utf-8').write(sc)
print('✅ 已写入两个文件 ⇒ 立刻重跑断言确认 200359/0')
