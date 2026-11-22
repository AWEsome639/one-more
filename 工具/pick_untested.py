# -*- coding: utf-8 -*-
"""选出「还没测过」的款。

规则：
  ① 已有截图且在**滚动窗口**内（默认 36 小时，见 SCREENSHOT_WINDOW_H）⇒ 算测过
     ★ 判据 3112：原来按「今天」筛，跨零点后昨天拍的 210 张全不算数、进度被清零（实测剩 353 款）。
  ② 文件名里的 enName 带下划线，注册表里的 enName 带空格 ⇒ 必须归一化后比对
     ★ 判据 3108：不归一会导致每批都在重测同一批游戏。
  ③ 排除「今天失败 ≥2 次且从未成功」的慢性失败款（白烧预算）。

用法：python3 工具/pick_untested.py [本批款数=10]
"""
import io
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
reg = io.open(os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets'),
              encoding='utf-8', errors='replace').read()
pairs = [(m.group(1), m.group(2)) for m in
         re.finditer(r"\{[^}]*?name: '([^']+)'[^}]*?enName: '([^']+)'", reg)]

def sanitize(s):
    # ★ 判据 3117：文件名的真实规则是「**非字母数字一律变下划线**」，不是「空格→下划线」。
    #   原来只替换空格 ⇒ `Go No Go` 变成 `Go_No_Go` 而实际文件是 `Go___No_Go`
    #   ⇒ 52 款被误判成「从未测过」，我据此反复重测了它们（全部 NOT_HOME）。
    return re.sub(r'[^0-9A-Za-z]', '_', s)


D = os.path.join(ROOT, '_巡检记录')
WINDOW_H = int(os.environ.get('SCREENSHOT_WINDOW_H', '36'))
cutoff = time.time() - WINDOW_H * 3600

done = set()
for n in os.listdir(D):
    if not (n.startswith('截图-') and n.endswith('.jpeg')):
        continue
    p = os.path.join(D, n)
    try:
        if os.path.getmtime(p) < cutoff:
            continue
    except OSError:
        continue
    m = re.match(r'截图-(.+)-(\d{6})\.jpeg$', n)
    if m:
        done.add(m.group(1))

# 慢性失败排除（只看窗口内的记录）
fail_cnt, ok_seen = {}, set()
ledger = os.path.join(D, 'layout-canonical.tsv')
if os.path.exists(ledger):
    for line in io.open(ledger, encoding='utf-8', errors='replace'):
        p = line.rstrip('\n').split('\t')
        if len(p) < 4:
            continue
        try:
            ts = time.mktime(time.strptime(p[0][:19], '%Y-%m-%dT%H:%M:%S'))
        except Exception:
            continue
        if ts < cutoff:
            continue
        name, status = p[1], p[2]
        if status == 'OK':
            ok_seen.add(name)
        else:
            fail_cnt[name] = fail_cnt.get(name, 0) + 1
chronic = {n for n, c in fail_cnt.items() if c >= 2 and n not in ok_seen}

todo = [(zh, en) for zh, en in pairs
        if sanitize(en) not in done and zh not in chronic]
print('  窗口 %dh 内已测 %d 款，慢性失败 %d 款，剩 %d 款 / 共 %d'
      % (WINDOW_H, len(done), len(chronic), len(todo), len(pairs)))
n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
pick = todo[:n]
io.open('/tmp/todo.txt', 'w', encoding='utf-8').write('\n'.join(zh for zh, _ in pick) + '\n')
print('  本批:', ' / '.join(zh for zh, _ in pick))
