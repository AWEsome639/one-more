#!/bin/bash
# ★ 2026-11-14：**`NO_CARD` 定因实验**（一条命令跑完，出结论表）
#
# 目的：一次性回答三个问题
#   ① 搜索框是否把输入词回显成 text 节点？（若是 ⇒ `shot_game.py:602` 的 `hit` 会误判）
#   ② 结果卡标题的 `y1` 落在哪？（若 ≤560 ⇒ `L620` 的 y 窗口把它滤掉了）
#   ③ 标题是否被 dump 拆成多个节点？（若是 ⇒ 整串匹配永远失败）
#   ④ 顺带：首页有没有大面积遮罩（`is_home()` 假阴性的来源）
#
# 用法：bash 工具/probe_no_card.sh ["游戏中文名"]     默认「时序判断」
set +u
cd "/Users/a0000/dev/One More" || exit 1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
WORD="${1:-时序判断}"
OUT=/tmp/probe_nocard.json

# ① 设备与端口（不写死：5555 新实例 / 5557 旧实例）
TGT=$("$HC" list targets 2>/dev/null | head -1 | tr -d ' \r')
if [ -z "$TGT" ] || echo "$TGT" | grep -qi empty; then
  for p in 5555 5557; do
    "$HC" tconn 127.0.0.1:$p >/dev/null 2>&1
    TGT=$("$HC" list targets 2>/dev/null | head -1 | tr -d ' \r')
    [ -n "$TGT" ] && ! echo "$TGT" | grep -qi empty && break
  done
fi
if [ -z "$TGT" ] || echo "$TGT" | grep -qi empty; then
  echo "❌ 设备不在线。先起模拟器等满 3 分钟。"; exit 1
fi
echo "设备：$TGT"

S() { "$HC" -t "$TGT" shell "$1" >/dev/null 2>&1; }

# ② 先在首页（Back 几次，别按太多以免退出 App）
for i in 1 2; do S "uitest uiInput keyEvent Back"; sleep 1; done
sleep 1

# ③ 点搜索框 → 点输入区 → 打字（坐标取自 shot_game.py:592-593）
S "uitest uiInput click 2276 264"; sleep 1
S "uitest uiInput click 1280 435"; sleep 1
S "uinput -K -t '$WORD'"; sleep 3

# ④ dump 回来
"$HC" -t "$TGT" shell "uitest dumpLayout -p /data/local/tmp/probe.json" >/dev/null 2>&1
"$HC" -t "$TGT" file recv /data/local/tmp/probe.json "$OUT" >/dev/null 2>&1
if [ ! -s "$OUT" ]; then echo "❌ dump 没拿到"; exit 1; fi
echo "dump: $OUT（$(wc -c < "$OUT" | tr -d ' ') 字节）"

# ⑤ 分析
WORD="$WORD" python3 - "$OUT" <<'PY'
import json, sys, os, re
word = os.environ.get('WORD', '')
d = json.load(open(sys.argv[1], encoding='utf-8'))

hits, biggest = [], []
def parse_b(b):
    m = re.findall(r'-?\d+', b or '')
    return tuple(int(x) for x in m[:4]) if len(m) >= 4 else None

def walk(n, dep=0):
    a = n.get('attributes', {}) or {}
    t = (a.get('text') or '').strip()
    bb = parse_b(a.get('bounds'))
    if bb:
        w, h = bb[2]-bb[0], bb[3]-bb[1]
        if w > 800 and h > 300: biggest.append((w*h, dep, t[:24], a.get('bounds')))
    if t and (word in t or any(ch in t for ch in word[:2] if ch.strip())):
        hits.append((dep, t, a.get('bounds'), bb))
    for c in (n.get('children') or []):
        walk(c, dep+1)
walk(d)

print('\n=== ① 含词的节点 ===')
if not hits: print('  （一个都没有 ⇒ uinput 没打进去，或 dump 里输入框不带 text）')
for dep, t, b, bb in hits:
    y1 = bb[1] if bb else '?'
    print('  dep=%d text=%r bounds=%s  y1=%s' % (dep, t, b, y1))

print('\n=== ② 判读 ===')
exact = [h for h in hits if h[1] == word]
if exact:
    for dep, t, b, bb in exact:
        y1 = bb[1]
        w = bb[2]-bb[0]
        if y1 <= 560: print("  ⚠️ 整串命中但 y1=%d ≤ 560 ⇒ **L620 的 y 窗口把它滤掉了**（主因）" % y1)
        elif w <= 100: print("  ⚠️ 整串命中、y1=%d > 560，但宽只有 %d ≤ 100 ⇒ **被 L620 的宽过滤跳过**" % (y1, w))
        else: print("  ✅ 整串命中、y1=%d > 560、宽=%d ⇒ **定位环节没问题**，问题在时序（sleep 2.4s 不够）" % (y1, w))
elif hits:
    print("  ⚠️ 只有**部分**字符命中（标题被拆成多个节点）⇒ `L602` 的子串匹配也会失败，需要改成拼段匹配")
else:
    print("  ❓ 没有任何命中 ⇒ 先确认 uinput 是否真打进去了（看输入框有没有回显）")

print('\n=== ③ 大面积节点（可能是遮罩 ⇒ is_home() 假阴性）===')
if not biggest: print('  ✅ 没有 >800x300 的节点')
for area, dep, t, b in sorted(biggest, reverse=True)[:5]:
    print('  dep=%d 面积=%d text=%r bounds=%s' % (dep, area, t, b))
PY
echo
echo "⇒ 结论填进 _巡检记录/NO_CARD根因-词表截断假设-20261114.md 的判读表"
