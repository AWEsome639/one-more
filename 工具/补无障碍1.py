#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 无障碍补丁 ①：给【壳层导航】的纯图标按钮加读屏标签

背景（2026-10-17 08:5x 实测）：
  · 全 app accessibilityText = 0 处
  · 纯图标按钮 96 处，其中可点击 45 处
  · 游戏内的棋子读屏本来也玩不了 ⇒ 本轮只补【壳层导航】+【明确的工具键】

补的 8 处：
  GameHost.ets  L612  ‹   → 返回
  GameHost.ets  L659  ?   → 玩法说明
  GameHost.ets  L696  ↻   → 重新开始
  GuidePage.ets L144  ‹   → 返回
  LanLobby.ets  L91   ‹   → 返回
  GKakuro/GKakuroMini/GKenken  ⌫ → 删除

同时给 EXTRA 补 4 条 × 12 语言（返回/重新开始/玩法说明/删除）
"""
import io
import os
import re
import shutil
import sys

ROOT = os.path.expanduser('~/dev/yiju/entry/src/main/ets')
BAK = os.path.expanduser('~/dev/yiju/.a11ybak')
os.makedirs(BAK, exist_ok=True)

# ══════════════════════════════════════════════
# ① 先补 EXTRA 的 4 条（12 语言）
# ══════════════════════════════════════════════
NEW_KEYS = {
    '返回':     {'ja': '戻る', 'ko': '뒤로', 'es': 'Volver', 'fr': 'Retour', 'de': 'Zurück',
                 'pt': 'Voltar', 'ru': 'Назад', 'it': 'Indietro', 'ar': 'رجوع', 'zh-Hant': '返回'},
    '重新开始': {'ja': 'やり直す', 'ko': '다시 시작', 'es': 'Reiniciar', 'fr': 'Recommencer',
                 'de': 'Neu starten', 'pt': 'Reiniciar', 'ru': 'Заново', 'it': 'Ricomincia',
                 'ar': 'إعادة', 'zh-Hant': '重新開始'},
    '玩法说明': {'ja': '遊び方', 'ko': '게임 방법', 'es': 'Cómo jugar', 'fr': 'Comment jouer',
                 'de': 'Spielanleitung', 'pt': 'Como jogar', 'ru': 'Как играть',
                 'it': 'Come giocare', 'ar': 'طريقة اللعب', 'zh-Hant': '玩法說明'},
    '删除':     {'ja': '削除', 'ko': '삭제', 'es': 'Borrar', 'fr': 'Supprimer', 'de': 'Löschen',
                 'pt': 'Apagar', 'ru': 'Удалить', 'it': 'Elimina', 'ar': 'حذف', 'zh-Hant': '刪除'},
}
ORDER = ['ja', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'it', 'ar', 'zh-Hant']

i18n = os.path.join(ROOT, 'core/I18n.ets')
shutil.copy(i18n, os.path.join(BAK, 'I18n.ets'))
s = io.open(i18n, encoding='utf-8').read()
added = 0
for zh, d in NEW_KEYS.items():
    if re.search(r'^  "%s":\s*\{' % zh, s, re.M):
        print('  · EXTRA 已有「%s」⇒ 跳过' % zh)
        continue
    body = ', '.join('"%s": "%s"' % (k, d[k]) for k in ORDER)
    line = '  "%s": { %s },\n' % (zh, body)
    # ★ 插在「首通」那条之前（难度名那批的前面，位置安全）
    anchor = re.search(r'^  "首通":\s*\{', s, re.M)
    if not anchor:
        print('  🔴 找不到锚点「首通」⇒ 停'); sys.exit(1)
    s = s[:anchor.start()] + line + s[anchor.start():]
    added += 1
io.open(i18n, 'w', encoding='utf-8').write(s)
back = io.open(i18n, encoding='utf-8').read()
ok = sum(1 for zh in NEW_KEYS if re.search(r'^  "%s":\s*\{' % zh, back, re.M))
print('  ✅ EXTRA 补了 %d 条（回读确认 %d/%d）' % (added, ok, len(NEW_KEYS)))

# ══════════════════════════════════════════════
# ② 给图标加 accessibilityText
# ══════════════════════════════════════════════
# (相对路径, 行号(1基), 双语键, 原文行必须精确等于)
TARGETS = [
    ('pages/GameHost.ets',      612,  "Text('‹')",  '返回'),
    ('pages/GameHost.ets',      659,  "Text('?')",  '玩法说明'),
    ('pages/GameHost.ets',      696,  "Text('↻')",  '重新开始'),
    ('pages/GuidePage.ets',     144,  "Text('‹')",  '返回'),
    ('games/GKakuro.ets',       434,  "Text('⌫')",  '删除'),
    ('games/GKakuroMini.ets',   425,  "Text('⌫')",  '删除'),
    ('games/GKenken.ets',       517,  "Text('⌫')",  '删除'),
]
EN = {'返回': 'Back', '玩法说明': 'How to play', '重新开始': 'Restart', '删除': 'Delete'}

# ★ 按文件分组，从后往前插（行号不漂移）
by_file = {}
for rel, ln, expect, key in TARGETS:
    by_file.setdefault(rel, []).append((ln, expect, key))

total = 0
for rel, items in by_file.items():
    fp = os.path.join(ROOT, rel)
    shutil.copy(fp, os.path.join(BAK, os.path.basename(rel)))
    L = io.open(fp, encoding='utf-8').read().split('\n')
    for ln, expect, key in sorted(items, reverse=True):
        cur = L[ln - 1]
        if cur.strip() != expect:
            print('  🔴 %s L%d 不是 %r（实际 %r）⇒ 停' % (rel, ln, expect, cur.strip()))
            sys.exit(1)
        indent = cur[:len(cur) - len(cur.lstrip())]
        L.insert(ln, '%s  .accessibilityText(this.t(\'%s\', \'%s\'))' % (indent, key, EN[key]))
        total += 1
    io.open(fp, 'w', encoding='utf-8').write('\n'.join(L))
    print('  ✅ %-24s 补了 %d 处' % (rel, len(items)))

# LanLobby L91 是单行链式（属性在同一行）⇒ 单独追加
fp = os.path.join(ROOT, 'pages/LanLobby.ets')
shutil.copy(fp, os.path.join(BAK, 'LanLobby.ets'))
s = io.open(fp, encoding='utf-8').read()
old91 = "        Text('‹').fontSize(FontSize.xl).fontColor(this.theme().ink)"
new91 = "        Text('‹').fontSize(FontSize.xl).fontColor(this.theme().ink)\n          .accessibilityText(this.t('返回', 'Back'))"
if old91 in s:
    s = s.replace(old91, new91, 1)
    io.open(fp, 'w', encoding='utf-8').write(s)
    total += 1
    print('  ✅ %-24s 补了 1 处' % 'pages/LanLobby.ets')
else:
    print('  ⚠️ LanLobby L91 锚点没中（可能已改）')

print()
print('  ★★ 本次共补 %d 处 accessibilityText' % total)

# ══════════════════════════════════════════════
# ③ 回读验证 + 括号校验
# ══════════════════════════════════════════════
n = 0
for rel in list(by_file.keys()) + ['pages/LanLobby.ets']:
    t = io.open(os.path.join(ROOT, rel), encoding='utf-8').read()
    c = t.count('.accessibilityText(')
    n += c
    d = 0; ins = None; i = 0
    while i < len(t):
        ch = t[i]
        if ins:
            if ch == '\\':
                i += 2; continue
            if ch == ins:
                ins = None
        elif ch in ('"', "'"):
            ins = ch
        elif ch == '(':
            d += 1
        elif ch == ')':
            d -= 1
        i += 1
    print('  %-24s accessibilityText %d 处 ｜ 括号差 %d %s' % (rel, c, d, '✅' if d == 0 else '🔴'))

whole = io.open(os.path.join(ROOT, 'pages/GameHost.ets'), encoding='utf-8').read()
print()
print('  ★ 回读：GameHost 里 accessibilityText = %d 处（期望 3）' % whole.count('.accessibilityText('))
