#!/bin/bash
# 在游戏列表里滚动查找并点击某个游戏（拾海 2026-10-11 v2）
#
# v1 的两个教训：
#   ① 滚动的手势**必须全程留在 Grid 内** —— 游戏 Grid 的可滚动区实测只有
#      y 1368–1968（600px 高，约 2 行）。从 1700 拖到 700 的话终点在 Grid 外，
#      手势被上层容器抢走 ⇒ 滚不动。
#   ② 回顶部不能只滚固定次数 —— 上次退出时可能停在中间，6 次不够。
#      v2 改成"滚到看见『全部 · N 款』为止"（最多 30 次）。
#   ③ 点完要**确认**（页面标题变了才算成功）—— v1 是"点了就报成功"。
#
# 用法: bash find_and_click.sh "游戏名" [最大下滚次数]
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
TXT="$1"; MAX="${2:-45}"
TMP=/tmp/fac; mkdir -p "$TMP"

dump() {
  $HDC shell "uitest dumpLayout -p /data/local/tmp/fac.json" >/dev/null 2>&1
  $HDC file recv /data/local/tmp/fac.json "$TMP/fac.json" >/dev/null 2>&1
}

# 在网格区（y 1368–1968）找目标文字；顺带报告是否在列表顶部
probe() {
  dump
  /usr/bin/python3 - "$TXT" <<'PY'
import json, re, sys
want = sys.argv[1]
try:
    d = json.load(open('/tmp/fac/fac.json'))
except Exception:
    print('|0'); raise SystemExit
hit = []
top = 0
def w(o):
    global top
    a = o.get('attributes', {})
    t = a.get('text', '')
    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', a.get('bounds', '') or '')
    if m and t:
        x1, y1, x2, y2 = map(int, m.groups())
        if t == want and y2 <= 2232:
            hit.append(((x1 + x2) // 2, (y1 + y2) // 2))
        # 列表顶部的标志：计数行「全部 · N 款」
        if t.startswith('全部 · ') or t.startswith('数字 · ') or t.startswith('逻辑 · ') \
           or t.startswith('经典 · ') or t.startswith('记忆 · ') or t.startswith('文字 · ') \
           or t.startswith('空间 · '):
            top = 1
    for c in o.get('children', []):
        w(c)
w(d)
# 输出: "x y|top"
if hit:
    print(f'{hit[0][0]} {hit[0][1]}|{top}')
else:
    print(f'|{top}')
PY
}

# ── ① 回顶部：**无条件**上滚 25 次 ──
#   ⚠️ 不能用"看见计数行"当判据 —— 计数行（如「数字 · 59 款」）在 Grid **外面**，
#      永远可见 ⇒ 判断立刻通过、列表根本没回顶（v2 就栽在这儿，白滚 45 屏）
for i in $(seq 1 25); do
  $HDC shell "uitest uiInput fling 660 1450 660 1930 3000" >/dev/null 2>&1
  sleep 0.25
done

# ── ② 向下找目标 ──
for i in $(seq 1 "$MAX"); do
  R=$(probe)
  XY="${R%%|*}"
  if [ -n "$XY" ]; then
    set -- $XY
    $HDC shell "uitest uiInput click $1 $2" >/dev/null 2>&1
    sleep 3
    # ── ③ 确认：点完标题应变成该游戏名（且出现 ↻）──
    dump
    if grep -q "↻" "$TMP/fac.json" 2>/dev/null; then
      echo "  ✅ 已进入「${TXT}」（第 ${i} 屏）"
      exit 0
    fi
    echo "  ⚠️ 点到了「${TXT}」但没进游戏（第 ${i} 屏），继续找"
  fi
  $HDC shell "uitest uiInput fling 660 1930 660 1450 3000" >/dev/null 2>&1
  sleep 0.45
done
echo "  ❌ 滚了 ${MAX} 屏没找到「${TXT}」"
exit 1
