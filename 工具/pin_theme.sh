#!/bin/bash
# 锁定主题：bash 工具/pin_theme.sh light|dark
#
# 为什么需要（判据 2809）：2026-11-16 实测同一批 4 次测量里，主题从浅漂到深
#   （截图亮度 95→46→52），而台账没有主题列 ⇒ 事后分不清哪些数是在哪个主题下量的。
#   跑批前锁一次，至少保证「一批之内同一主题」。
set -u
cd "$(dirname "$0")/.." || exit 1
WANT="${1:-light}"
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
TARGET=$([ "$WANT" = "dark" ] && echo "🌙" || echo "☀️")

dump() {
  "$HC" shell "uitest dumpLayout -p /data/local/tmp/pt.json" >/dev/null 2>&1
  "$HC" shell "cat /data/local/tmp/pt.json" 2>/dev/null
}

icon() {  # 输出: "x y 图标"
  dump | python3 -c "
import sys, json, re
try: d = json.loads(sys.stdin.read())
except Exception: raise SystemExit
def walk(n):
    if not isinstance(n, dict): return None
    a = n.get('attributes', {}) or {}
    t = (a.get('text') or '').strip()
    if t in ('☀️','🌙','☀','🌙'):
        m = re.findall(r'-?\d+', (a.get('bounds') or ''))
        if len(m) == 4:
            return (int(m[0])+int(m[2]))//2, (int(m[1])+int(m[3]))//2, t
    for c in (n.get('children') or []):
        r = walk(c)
        if r: return r
    return None
r = walk(d)
print('%d %d %s' % r if r else '')
" 2>/dev/null
}

"$HC" shell "aa start -a EntryAbility -b com.andrewoscar.onemore" >/dev/null 2>&1
sleep 5
for _ in 1 2 3; do
  I=$(icon)
  if [ -z "$I" ]; then echo "pin_theme: 找不到日月图标（可能不在首页）"; exit 0; fi
  set -- $I
  CUR="$3"
  if [ "$CUR" = "$TARGET" ]; then echo "pin_theme: 已是 $WANT（$CUR）"; exit 0; fi
  "$HC" shell "uitest uiInput click $1 $2" >/dev/null 2>&1
  sleep 2
done
echo "pin_theme: 尝试 3 次后仍不是 $WANT（当前 $(icon | awk '{print $3}'))"
