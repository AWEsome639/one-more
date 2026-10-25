#!/bin/bash
# 批量验证"难度是否作用到玩法"（拾海 2026-10-11）
#
# 对每款已接入难度的游戏：进游戏 → 读难度与时限 → 与"源码里的基础值 × 倍率"比对
# 依赖 tools/find_and_click.sh（v3，回顶部已改为无条件上滚）
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
ROOT="$HOME/dev/One More"
OUT="${1:-/tmp/diff_verify.txt}"
LIST="${2:-/tmp/diff_targets.txt}"

# 从源码读出每款的 gameId / 中文名 / 基础值
/usr/bin/python3 - > /tmp/diff_targets.txt <<'PY'
import re, glob, io, os
reg = dict(re.findall(r"id: '([^']+)', name: '([^']*)'",
                      io.open('/Users/a0000/dev/One More/entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()))
for p in sorted(glob.glob('/Users/a0000/dev/One More/entry/src/main/ets/games/*.ets')):
    s = io.open(p, encoding='utf-8').read()
    if 'GameDiff.timeNow' not in s:
        continue
    m = re.search(r"private total: number = GameDiff\.timeNow\((\w+)\);", s)
    if not m:
        continue
    base = re.search(r"const " + m.group(1) + r": number = (\d+)", s)
    gid = re.search(r"gameId: '([^']+)'", s)
    if base and gid and gid.group(1) in reg:
        cat = re.search(r"category: GameCategory\.(\w+)", s)
        print(f'{reg[gid.group(1)]}|{base.group(1)}|{cat.group(1) if cat else "ALL"}')
PY

# 分类芯片坐标（实测）
cat_xy() {
  case "$1" in
    ALL) echo "193 1247";; CLASSIC) echo "477 1247";; LOGIC) echo "747 1247";;
    MATH) echo "1017 1247";; MEMORY) echo "1243 1247";;
    *) echo "193 1247";;   # WORD / SPATIAL 的芯片在折叠区，先用全部
  esac
}

echo "游戏|基础|读到的难度|读到的时限|期望|判定" > "$OUT"
N=0
while IFS='|' read -r NAME BASE CAT; do
  [ -z "$NAME" ] && continue
  N=$((N+1))
  # ★ 先点分类条缩小范围 —— 直接在 354 款全表里滚 45 屏够不到排在后面的款
  read -r CX CY <<< "$(cat_xy "$CAT")"
  $HDC shell "uitest uiInput click $CX $CY" >/dev/null 2>&1
  sleep 2
  bash "$ROOT/tools/find_and_click.sh" "$NAME" 45 >/dev/null 2>&1
  sleep 1
  P=$(bash "$ROOT/tools/read_page.sh" 2>/dev/null | grep -oE "简单|普通|困难" | head -1)
  T=$(bash "$ROOT/tools/read_page.sh" 2>/dev/null | grep -oE "[0-9]+s" | head -1 | tr -d 's')
  case "$P" in
    简单) SCALE=1.5;; 困难) SCALE=0.7;; *) SCALE=1.0;;
  esac
  WANT=$(/usr/bin/python3 -c "print(max(10, round($BASE * $SCALE)))")
  # ★ 判定要带容差：读的时候计时器**已经开始倒数**，所以实读通常比期望小几秒
  #   （实测：基础 60s 的游戏，读完一次 dump 后读到 54s —— 这是对的，不是 bug）
  V=$(/usr/bin/python3 -c "
t='${T:-}'
if not t or not t.isdigit(): print('⚠️读不到'); raise SystemExit
t=int(t); w=$WANT
if t > w: print('⚠️超过期望')
elif w - t <= max(3, w*0.15): print('✅')
else: print('⚠️差 %d 秒' % (w-t))")
  echo "$NAME|$BASE|${P:-?}|${T:-?}|$WANT|$V" >> "$OUT"
  echo "  [$N] $NAME  基础$BASE ×$SCALE → 期望$WANT  实读 ${T:-?}s   $V"
  # 返回列表
  $HDC shell "uitest uiInput click 126 267" >/dev/null 2>&1
  sleep 2
done < "${LIST:-/tmp/diff_targets.txt}"
echo
echo "  ✅ 完成，结果在 $OUT"
grep -c "✅" "$OUT" | sed 's/^/  通过: /'
grep -c "⚠️" "$OUT" | sed 's/^/  异常: /'
