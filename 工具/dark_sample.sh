#!/bin/bash
# 深色模式抽样：切换 → 测指定款 → 切回。全流程自动、可恢复。
#
# 为什么需要它：`234/355` 款从未在深色下看过（判据 2799），而手动切主题
# + 逐款测量容易漏掉「切回浅色」这一步，把后续测量全污染。
#
# 用法：
#   bash 工具/dark_sample.sh                 # 只切换 + 验证（不测款）
#   bash 工具/dark_sample.sh "Story Builder" "Color Match" ...
#
# 安全设计：trap 保证退出时**一定切回浅色**；切换用「找图标 bounds 再点中心」而不是写死坐标。

set -u
cd "$(dirname "$0")/.." || exit 1
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
# ★ 2026-11-17（判据 2839）：**先把款名存起来**。
#   原来直接 `for g in "$@"`，而 `restore_light()` 里的 `set -- $c`
#   会把 $@ 覆盖成日月图标的坐标 ⇒ 实测把「1966 / 267 / ☀️」当成款名去测。
GAMES=("$@")

dump() {
  "$HC" shell "uitest dumpLayout -p /data/local/tmp/ds.json" >/dev/null 2>&1
  "$HC" shell "cat /data/local/tmp/ds.json" 2>/dev/null
}

# 找 🌙/☀️ 图标的中心坐标
icon_center() {
  dump | python3 -c "
import sys, json, re
raw = sys.stdin.read()
try: d = json.loads(raw)
except Exception: raise SystemExit(1)
def walk(n):
    if not isinstance(n, dict): return None
    a = n.get('attributes', {}) or {}
    if (a.get('text') or '').strip() in ('☀️','🌙'):
        b = (a.get('bounds') or '').strip()
        m = re.findall(r'-?\d+', b)
        if len(m) == 4:
            return (int(m[0])+int(m[2]))//2, (int(m[1])+int(m[3]))//2, (a.get('text') or '').strip()
    for c in (n.get('children') or []):
        r = walk(c)
        if r: return r
    return None
r = walk(d)
print('%d %d %s' % r if r else '')
" 2>/dev/null
}

state() { icon_center | awk '{print $3}'; }

echo "════ 深色抽样 $(date '+%H:%M') ════"

# 确保在首页
# ★ 2026-11-16（判据 2817）：原来只 `aa start` + `sleep 6`，而 App 已在运行时
#   `aa start` 不会回首页（可能停在游戏里）⇒ 找不到日月图标。改成强制重启 + 验证 + 重试。
for _try in 1 2 3; do
  "$HC" shell "aa force-stop com.andrewoscar.onemore" >/dev/null 2>&1
  sleep 2
  "$HC" shell "aa start -a EntryAbility -b com.andrewoscar.onemore" >/dev/null 2>&1
  sleep 9
  dump | grep -q "355 款小游戏" && { echo "→ 已回首页（第 $_try 次）"; break; }
  echo "→ 第 $_try 次没回首页，重试"
done

CUR=$(state)
if [ -z "$CUR" ]; then
  echo "❌ 首页找不到 ☀️/🌙 图标（可能不在首页）"; exit 1
fi
echo "当前图标: $CUR"

restore_light() {
  # 无论怎么退出，都确保回到 ☀️（浅色）
  for _ in 1 2 3; do
    s=$(state)
    [ "$s" = "☀️" ] && { echo "→ 已是浅色"; return; }
    c=$(icon_center); [ -z "$c" ] && return
    set -- $c
    "$HC" shell "uitest uiInput click $1 $2" >/dev/null 2>&1
    sleep 2
  done
  echo "→ 尝试切回浅色，当前图标: $(state)"
}
trap restore_light EXIT INT TERM

# 切到深色
if [ "$CUR" != "🌙" ]; then
  c=$(icon_center); set -- $c
  "$HC" shell "uitest uiInput click $1 $2" >/dev/null 2>&1
  sleep 3
fi
echo "切换后图标: $(state)（🌙 = 深色）"

if [ "${#GAMES[@]}" -gt 0 ]; then
  echo
  echo "── 逐款测量（深色）──"
  for g in "${GAMES[@]}"; do
    echo "→ $g"
    timeout 240 python3 工具/shot_game.py "$g" 2>&1 | tail -1 | cut -c1-118
    sleep 3
  done
else
  echo "（未指定款 ⇒ 只验证切换；退出时自动切回浅色）"
fi

echo
echo "════ 完（退出时自动切回浅色）════"
