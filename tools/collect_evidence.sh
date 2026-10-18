#!/bin/bash
# 一局 · 一次装包出全部证据（拾海 2026-10-13）
#
# 奥森的老规矩：**动效必须抽帧**，单帧不算。这个脚本把 UI 截图 + 动效抽帧一次做完，
# 装包只做一次（⚠️ 模拟器装包要先 uninstall，会清 App 数据 ⇒ 别分两轮）。
#
# 用法: bash tools/collect_evidence.sh
#
# 关键做法（都是踩出来的）：
#   ① **坐标不猜** —— 全部从 `uitest dumpLayout` 里按**文字**反查中心点再点
#      （我手写坐标点错过两次：点「统计」结果停在「游戏」）
#   ② **整串连拍在设备端一条命令里跑完** —— 每帧一次 hdc 往返要 200ms+，会把动效抽成静止
#   ③ 每步都报**不同帧数**（≥3 才算真拍到运动）
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
PKG=com.andrewoscar.onemore
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HAP="$ROOT/entry/build/default/outputs/default/entry-default-signed.hap"
OUT="$ROOT/验收-全部证据-20261013"
TMP=/tmp/yiju_ev
mkdir -p "$OUT" "$TMP"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ── 从 dumpLayout 里按文字找中心点 ──
# 回首页壳（底部导航所在的那一页）
# ★ 不能"盲按两次返回" —— 我第一版就是这么写的，结果停在了 A-Z 列表（底部导航都不在 dump 里）。
#   正确做法：**按到确认在首页为止**（判据 = 顶部出现「一局」且底部出现三个 tab 文字）
# ★ 判定逻辑放在单独的小脚本里（`tools/_at_home.py`）——
#   往 shell 里嵌 heredoc 太容易把外层引号截断（我为此吃过一次 SyntaxError）。
app_alive() {
  "$HDC" shell "pidof $PKG" 2>/dev/null | tr -d '\r' | grep -q '[0-9]'
}

at_home() {
  # ★ 先确认 App 真的在跑 —— Back 按多了会退出到桌面，那时 dump 里只剩系统状态栏
  if ! app_alive; then
    echo no
    return 0
  fi
  "$HDC" shell "uitest dumpLayout -p /data/local/tmp/h.json" >/dev/null 2>&1
  "$HDC" file recv /data/local/tmp/h.json "$TMP/h.json" >/dev/null 2>&1
  python3 "$ROOT/tools/_at_home.py" "$TMP/h.json"
}

back_home() {
  for i in 1 2 3 4; do
    if [ "$(at_home)" = "yes" ]; then
      return 0
    fi
    # App 被杀/退回桌面 ⇒ 重新拉起（比继续按 Back 有效）
    if ! app_alive; then
      "$HDC" shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1
      sleep 6
      continue
    fi
    "$HDC" shell "uitest uiInput keyEvent Back" >/dev/null 2>&1
    sleep 1.0
  done
  echo "  ⚠️ 4 次返回仍不在首页"
  return 1
}

center_of() {   # center_of <文字> → 打印 "x y"；找不到打印空
  "$HDC" shell "uitest dumpLayout -p /data/local/tmp/d.json" >/dev/null 2>&1
  "$HDC" file recv /data/local/tmp/d.json "$TMP/d.json" >/dev/null 2>&1
  python3 - "$TMP/d.json" "$1" <<'PY'
import json, re, sys
p, want = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception:
    print(''); raise SystemExit
hit = []
def w(n):
    if not isinstance(n, dict): return
    a = n.get('attributes', {}); t = (a.get('text') or '').strip()
    b = a.get('bounds') or ''
    m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b or '')
    if m and t:
        x1,y1,x2,y2 = map(int, m.groups())
        if want in t and len(t) <= 16:
            hit.append(((x1+x2)//2, (y1+y2)//2, x2-x1, y2-y1))
    for c in n.get('children', []) or []: w(c)
w(d)
if hit:
    # 取面积最小的（最具体的那一个）
    hit.sort(key=lambda h: h[2]*h[3])
    print(f'{hit[0][0]} {hit[0][1]}')
else:
    print('')
PY
}

# ── 设备端连拍 ──
burst() {   # burst <前缀> [点击 x y]   连拍 14 帧，每帧间隔 0.1s
  local pre="$1"; local click="${2:-}"
  "$HDC" shell "rm -f /data/local/tmp/f*.jpeg" >/dev/null 2>&1
  # ★ 先点、**再**连拍（写反了就会拍到"点之前的静止画面" —— 我第一版就写反了，14 帧全一样）
  local cmd=""
  if [ -n "$click" ]; then
    cmd="uitest uiInput click $click; "
  fi
  cmd="$cmd for i in \$(seq 1 14); do snapshot_display -f /data/local/tmp/f\$i.jpeg; sleep 0.10; done"
  "$HDC" shell "$cmd" >/dev/null 2>&1
  mkdir -p "$OUT"
  for i in $(seq 1 14); do
    "$HDC" file recv "/data/local/tmp/f$i.jpeg" "$OUT/${pre}_$(printf '%02d' $i).jpeg" >/dev/null 2>&1
  done
  local n uniq
  n=$(ls "$OUT/${pre}_"*.jpeg 2>/dev/null | wc -l | tr -d ' ')
  uniq=$(md5 -q "$OUT/${pre}_"*.jpeg 2>/dev/null | sort -u | wc -l | tr -d ' ')
  echo "  $pre: $n 帧，**不同 $uniq 帧** $([ "$uniq" -ge 4 ] && echo '✅ 拍到运动' || echo '⚠️ 几乎静止')"
}

shot() {    # shot <名字>
  "$HDC" shell "snapshot_display -f /data/local/tmp/one.jpeg" >/dev/null 2>&1
  "$HDC" file recv /data/local/tmp/one.jpeg "$OUT/$1.jpeg" >/dev/null 2>&1
  echo "  → $1.jpeg"
}

# ── 0. 装包（`--no-install` 可跳过：重跑取证时不必再清一次数据）──
if [ "${1:-}" = "--no-install" ]; then
  say "0. 跳过装包（--no-install）"
  "$HDC" shell aa force-stop "$PKG" >/dev/null 2>&1
  sleep 1
  "$HDC" shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1
  sleep 7
else
  say "0. 装包（先 uninstall —— 模拟器旧包签名不同，不清装不上）"
  [ -f "$HAP" ] || { echo "❌ 没有 HAP"; exit 1; }
  "$HDC" uninstall "$PKG" >/dev/null 2>&1; sleep 1
  "$HDC" install "$HAP" 2>&1 | tail -1
fi

# ── 1. 首屏错峰进场（冷启动连拍）──
say "1. ③ 首屏错峰进场（冷启动后连拍）"
"$HDC" shell aa force-stop "$PKG" >/dev/null 2>&1; sleep 1
"$HDC" shell "rm -f /data/local/tmp/f*.jpeg; aa start -a EntryAbility -b $PKG; for i in \$(seq 1 14); do snapshot_display -f /data/local/tmp/f\$i.jpeg; sleep 0.10; done" >/dev/null 2>&1
for i in $(seq 1 14); do "$HDC" file recv "/data/local/tmp/f$i.jpeg" "$OUT/③-冷启动进场_$(printf '%02d' $i).jpeg" >/dev/null 2>&1; done
u=$(md5 -q "$OUT/③-冷启动进场_"*.jpeg 2>/dev/null | sort -u | wc -l | tr -d ' ')
echo "  ③-冷启动进场: 不同 $u 帧 $([ "$u" -ge 4 ] && echo ✅ || echo ⚠️)"
sleep 6

# ── 2. ① 共享元素转场：点第 1 张卡 ──
say "2. ① 共享元素转场（点第 1 张游戏卡 → 进游戏）"
back_home
C=$(center_of '宝石迷阵')
if [ -n "$C" ]; then
  echo "  第 1 张卡中心 = ($C)"
  burst "①-进游戏转场" "$C"
  sleep 5
  say "2b. ① 反向（点返回键 → 回首页）"
  B=$(center_of '‹')
  [ -z "$B" ] && B="130 300"
  echo "  返回键中心 = ($B)"
  burst "①-返回转场" "$B"
else
  echo "  ⚠️ 没在首页找到「宝石迷阵」，跳过转场抽帧"
fi
sleep 4

# ── 3. ④ 数字滚动：切到统计页 ──
say "3. ④ 数字滚动 + ③ 统计页推荐区（切到统计页连拍）"
back_home
S=$(center_of '统计')
if [ -n "$S" ]; then
  echo "  统计 tab = ($S)"
  burst "④-统计页数字滚动" "$S"
else
  echo "  ⚠️ 找不到「统计」tab"
fi
sleep 4
shot "③-统计页-首屏"

# ── 4. ① 设置页主题色 ──
say "4. ① 设置页（滚到底看主题色）"
back_home
T=$(center_of '设置')
if [ -n "$T" ]; then
  "$HDC" shell "uitest uiInput click $T" >/dev/null 2>&1; sleep 2
  for i in 1 2 3 4 5 6 7 8; do "$HDC" shell "uitest uiInput swipe 660 1700 660 400 200" >/dev/null 2>&1; sleep 0.3; done
  sleep 1
  shot "①-设置页-滚到底"
fi

# ── 5. 拼帧序列图 ──
say "5. 拼帧序列图（横向，一眼看轨迹）"
python3 - "$OUT" <<'PY'
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]
try:
    f = ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', 20)
except Exception:
    f = ImageFont.load_default()
groups = {}
for p in sorted(glob.glob(os.path.join(out, '*.jpeg'))):
    base = os.path.basename(p)
    if '_' not in base: continue
    pre = base.rsplit('_', 1)[0]
    groups.setdefault(pre, []).append(p)
for pre, paths in groups.items():
    paths = sorted(paths)
    if len(paths) < 4: continue
    H = 380
    ims = []
    for p in paths:
        im = Image.open(p).convert('RGB')
        ims.append(im.resize((int(im.width * H / im.height), H), Image.LANCZOS))
    W = sum(i.width for i in ims) + 8 * (len(ims) + 1)
    sheet = Image.new('RGB', (W, H + 36), (245, 247, 250))
    d = ImageDraw.Draw(sheet)
    x = 8
    for i, im in enumerate(ims):
        sheet.paste(im, (x, 30))
        d.text((x + 4, 6), f'#{i+1}', fill=(20, 30, 50), font=f)
        x += im.width + 8
    dst = os.path.join(out, f'{pre}_帧序列.png')
    sheet.save(dst)
    print('  →', os.path.basename(dst))
PY
say "完成：$OUT"
