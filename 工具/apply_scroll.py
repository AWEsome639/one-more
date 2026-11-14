#!/usr/bin/env python3
"""通用：把指定游戏 build() 的外层 Column 包进 Scroll()，并注释掉 .height('100%')
（依据：GBejeweled.ets:584 的 Scroll 模板 —— 它的外层 Column 没有 height('100%')；
 在 Scroll 里给子元素 height('100%') 会让「内容高=视口高」⇒ 滚不动）

用法：python3 工具/apply_scroll.py G<Game>.ets --dry   # 只打印
      python3 工具/apply_scroll.py G<Game>.ets         # 真改（先 git diff 检查再提交）
"""
import io, sys, re

args = [a for a in sys.argv[1:] if not a.startswith('--')]
if not args:
    sys.exit('用法：python3 工具/apply_scroll.py G<Game>.ets [--dry]\n' +
             '  ⇒ 把该游戏 build() 的外层 Column 包进 Scroll()（模板见 GBejeweled.ets:584）')
P = 'entry/src/main/ets/games/' + args[0]
DRY = '--dry' in sys.argv

src = io.open(P, encoding='utf-8').read()
L = src.split('\n')

# ① 定位 build() 与它的外层 Column
i_build = next(i for i, x in enumerate(L) if x.rstrip() == '  build() {')
i_col   = i_build + 1
if not re.search(r'Column\(\{ space: Bp\.isShort\(\) \? Space\.\w+ : Space\.\w+ \}\) \{', L[i_col]):
    sys.exit('❌ L%d 不是预期的 Column 行：%r' % (i_col+1, L[i_col][:80]))
if 'Scroll()' in L[i_col-1]:
    sys.exit('✅ 已经套过 Scroll，无需重复')

# ② 找 build() 的结尾（下一个只含两个空格的 }）
i_end = next(i for i in range(i_col, len(L)) if L[i] == '  }')

# ③ 找 .height('100%')（在 i_col..i_end 之间，且属于外层 Column 的修饰符）
i_h = [i for i in range(i_col, i_end) if L[i].strip() == ".height('100%')"]
if len(i_h) != 1:
    sys.exit('⚠️ .height(100%%) 找到 %d 处（预期 1）⇒ 手工确认' % len(i_h))
i_h = i_h[0]

print('定位：build() 在 L%d、Column 在 L%d、build 结尾 L%d、height(100%%) 在 L%d'
      % (i_build+1, i_col+1, i_end+1, i_h+1))

# ④ 改动：注释 height、插 Scroll 开头与结尾
new = list(L)
new[i_h] = new[i_h].replace(".height('100%')",
    "// .height('100%')  ← 2026-11-14：套 Scroll 后不能用 100%（内容高=视口高⇒滚不动），判据见 _巡检记录")
# 插入前先把块内每行 +2 空格（否则 Scroll 里那层缩进比外面还浅，格式不对）
for k in range(i_col, i_end):
    if new[k].strip():                  # 空行不加空格
        new[k] = '  ' + new[k]

new.insert(i_col, '    Scroll() {')
i_end2 = i_end + 1                      # 插入一行后结尾下标 +1
new.insert(i_end2, '    }')

import difflib
dl = list(difflib.unified_diff(L, new, 'before', 'after', lineterm='', n=1))
chg = [x for x in dl if x.startswith(('+', '-')) and not x.startswith(('+++', '---'))]
print('实际改动 %d 行（+/- 合计）：' % len(chg))
for x in dl:
    if x.startswith(('---', '+++')): continue
    if x.startswith('+'): print('  + %s' % x[1:].strip()[:70])
    elif x.startswith('-'): print('  - %s' % x[1:].strip()[:70])

if DRY:
    print('\n（--dry：未写文件）'); sys.exit(0)

io.open(P, 'w', encoding='utf-8').write('\n'.join(new))
print('\n✅ 已写入 %s ⇒ 先 git diff 检查、再编译' % P)
