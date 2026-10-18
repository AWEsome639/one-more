#!/bin/bash
# 一局 · P1/P10/P11 图标与布局的模拟器验收（拾海 2026-10-13）
#
# 用法: bash tools/verify_icons_layout.sh [HAP路径]
#
# 它做四件事，缺一不可：
#   ① 装包（HAP 必须比源码新 —— 旧包验不出新代码，这个坑我踩过）
#   ② 冷启动 → 截首页（P1 看图标与标题是否还"挤"、P10 看是否款款不同）
#   ③ 下拉到第二屏再截一张（第一屏只能看到 4 款，354 款要滚着抽）
#   ④ 用 uitest dump 量出**每张卡里图标与文字的矩形**，算实际间距（不靠肉眼）
#
# 产物落 ~/dev/yiju/验收-图标与布局-20261013/
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
PKG=com.andrewoscar.onemore
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HAP="${1:-$ROOT/entry/build/default/outputs/default/entry-default-signed.hap}"
SHOT="$ROOT/验收-图标与布局-20261013"
TMP=/tmp/yiju_icon_verify
mkdir -p "$SHOT" "$TMP"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ① 设备
TARGET=$("$HDC" list targets 2>/dev/null | head -1 | tr -d '\r')
if [ -z "$TARGET" ]; then
  echo "❌ 没有设备。真机或模拟器起一个再跑（hdc list targets 为空）"; exit 1
fi
echo "  设备: $TARGET"

# ② 新鲜度闸门 —— ★ 血泪：构建在 00:19 开始、图标 00:22 才写盘 ⇒ 那轮完全没打包新资源
if [ ! -f "$HAP" ]; then echo "❌ 找不到 HAP: $HAP"; exit 1; fi
HAP_T=$(stat -f %m "$HAP")
NEWEST_SRC=$(find "$ROOT/entry/src/main/ets" "$ROOT/entry/src/main/resources/base/media" \
             -type f -newermt "@$HAP_T" 2>/dev/null | head -3)
if [ -n "$NEWEST_SRC" ]; then
  echo "⚠️  HAP 比源码旧！下面这些文件比 HAP 新，装了也验不出新代码："
  echo "$NEWEST_SRC" | sed 's/^/     /'
  echo "     ⇒ 先重跑 bash build.sh assembleHap 再验"
  exit 2
fi
echo "  HAP 新鲜度 ✓（$(date -r "$HAP_T" '+%H:%M:%S')，无更新的源码）"

say "① 装包"
"$HDC" install -r "$HAP" 2>&1 | tail -2

say "② 冷启动 + 抓首页"
"$HDC" shell aa force-stop "$PKG" >/dev/null 2>&1
sleep 1
"$HDC" shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1
sleep 7
"$HDC" shell "snapshot_display -f /data/local/tmp/home1.jpeg" >/dev/null 2>&1
"$HDC" file recv /data/local/tmp/home1.jpeg "$SHOT/首页-第1屏.jpeg" >/dev/null 2>&1
echo "  → $SHOT/首页-第1屏.jpeg"

say "③ 下拉看后面的款（P10：354 款款款不同，一屏看不完）"
"$HDC" shell "uitest uiInput swipe 660 1700 660 500 400" >/dev/null 2>&1
sleep 2
"$HDC" shell "snapshot_display -f /data/local/tmp/home2.jpeg" >/dev/null 2>&1
"$HDC" file recv /data/local/tmp/home2.jpeg "$SHOT/首页-第2屏.jpeg" >/dev/null 2>&1
"$HDC" shell "uitest uiInput swipe 660 1700 660 500 400" >/dev/null 2>&1
sleep 2
"$HDC" shell "snapshot_display -f /data/local/tmp/home3.jpeg" >/dev/null 2>&1
"$HDC" file recv /data/local/tmp/home3.jpeg "$SHOT/首页-第3屏.jpeg" >/dev/null 2>&1
echo "  → 首页-第2屏.jpeg / 首页-第3屏.jpeg"

say "④ 量间距（不靠肉眼：从 uitest dump 里读每张卡的矩形）"
"$HDC" shell "uitest dumpLayout -p /data/local/tmp/layout.json" >/dev/null 2>&1
"$HDC" file recv /data/local/tmp/layout.json "$TMP/layout.json" >/dev/null 2>&1
python3 - "$TMP/layout.json" <<'PY'
import json, sys, re
p = sys.argv[1]
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception as e:
    print('  ⚠️ dump 读不了:', e); raise SystemExit(0)

rows = []
def walk(n):
    if not isinstance(n, dict): return
    a = n.get('attributes', {})
    t = (a.get('text') or '')
    b = a.get('bounds') or ''
    m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b or '')
    if m:
        x1,y1,x2,y2 = map(int, m.groups())
        rows.append((t, x1,y1,x2,y2, a.get('type','')))
    for c in n.get('children', []) or []:
        walk(c)
walk(d)

imgs = [r for r in rows if r[5] == 'Image' and abs((r[3]-r[1]) - (r[4]-r[2])) < 8 and 100 < (r[3]-r[1]) < 220]
txts = [r for r in rows if r[0] and r[5] in ('Text', '')]
print(f'  可点/可见节点 {len(rows)} 个 · 疑似游戏图标(方形 Image) {len(imgs)} 个')
if imgs:
    print('  ★ 图标尺寸:', ' / '.join(f'{r[3]-r[1]}×{r[4]-r[2]}px' for r in imgs[:6]))
    bad = [r for r in imgs if abs((r[3]-r[1]) - (r[4]-r[2])) > 4]
    print('  ★ 长宽不一致的图标:', len(bad), '（应为 0 —— 图标要严格正方）')
    # 与右侧文字的最近距离
    mind = 999
    for im in imgs:
        for t in txts:
            if t[1] >= im[3] - 4 and t[2] < im[5] + 4 and t[4] > im[2] - 4:
                mind = min(mind, t[1] - im[3])
    if mind < 900:
        print(f'  ★ 图标右缘 → 同行文字左缘 最小水平间距: {mind}px（3x 屏 ⇒ {mind/3:.1f}vp；'
              f'设计值 Space.sm=10vp ⇒ 期望 ~30px）')
        print('     ', '✅ 不挤' if mind >= 20 else '❌ 仍然挤')
PY

say "⑤ 崩溃检查"
echo "  appfreeze: $("$HDC" shell 'ls /data/log/faultlog/faultlogger/ 2>/dev/null | grep -c onemore' 2>/dev/null | tr -d '\r')"
echo "  ⇒ 证据目录：$SHOT"
