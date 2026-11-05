#!/usr/bin/env bash
# ============================================================================
#  工具/find_card.sh —— **滚动查找游戏卡片**（不依赖搜索框）
#
#  ★ 为什么要有（判据 1203/1204，第 1382 轮）
#    · `uitest dumpLayout` **只含可见节点** ⇒ 首屏只有 2~8 张卡
#      ⇒ 深处那款 `blink_detector` **根本不在 dump 里**（不是 bug）
#    · 搜索按钮是 `Text('🔍')`，**不是 `TextInput`**
#      ⇒ 必须先点它、再 dump，才知道输入框在哪
#    ⇒ 最稳的路径：**滚动 + 每步 dump，直到卡片出现**
#
#  ★ 用法：bash 工具/find_card.sh <game_id> [最大滚动次数]
#  输出：成功时打印「x y」，失败时 exit 1
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
GID="${1:?用法: find_card.sh <game_id> [max_scroll]}"
MAXS="${2:-14}"
WANT="card-${GID}"

A() { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
DUMP_TO() { rm -f "$1"; A "uitest dumpLayout -p /data/local/tmp/_fc.json" >/dev/null 2>&1; timeout 20 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_fc.json "$1" >/dev/null 2>&1; }
FIND() { python3 - "$1" "$WANT" <<'PY' 2>/dev/null
import json, re, sys
p, want = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception:
    print(''); raise SystemExit
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if (at.get('id') or '') == want:
        bb=b(at)
        if bb: r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}

TMP="/tmp/find_card.json"
for step in $(seq 0 "$MAXS"); do
  DUMP_TO "$TMP"
  XY="$(FIND "$TMP")"
  if [ -n "$XY" ]; then
    printf '%s\n' "$XY"
    exit 0
  fi
  if [ "$step" -ge "$MAXS" ]; then break; fi
  # 向下滚半屏（判据：一次滚太多会跳过目标）
  A "uitest uiInput swipe 660 1500 660 700 300" >/dev/null 2>&1
  sleep 1
done
exit 1
