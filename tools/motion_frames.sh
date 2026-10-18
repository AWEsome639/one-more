#!/bin/bash
# 一局 · 动效录屏抽帧（拾海 2026-10-13）—— 「动画拉满」专项的证据工具
#
# 奥森的老规矩：**动效必须录屏抽帧**，单帧截图不算（单帧证不了"移开后回到初始"）。
#
# 用法: bash tools/motion_frames.sh <场景>
#   场景 = transition | stagger | rolling | all
#
# 产物落 ~/dev/yiju/验收-动效-20261013/<场景>/
#   每帧单独存 + 一张"帧序列"横向拼图（一眼看出运动轨迹）
set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
PKG=com.andrewoscar.onemore
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/验收-动效-20261013"
TMP=/tmp/yiju_motion
mkdir -p "$OUT" "$TMP"

SCENE="${1:-all}"
N=14                     # 连拍帧数
GAP=0.10                 # 帧间隔（秒）

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
shot() {  # shot <名字前缀>
  local pre="$1"
  "$HDC" shell "rm -f /data/local/tmp/f*.jpeg" >/dev/null 2>&1
  # ★ 关键：整串连拍在**设备端**一条命令里跑完，避免每帧一次 hdc 往返（往返本身就要 200ms+，
  #   会把"动效"抽成"静止"）。这是本仓 tools/续跑-手感验收.sh 里验证过的写法。
  local cmd="for i in \$(seq 1 $N); do snapshot_display -f /data/local/tmp/f\$i.jpeg; sleep $GAP; done"
  "$HDC" shell "$cmd" >/dev/null 2>&1
  mkdir -p "$OUT/$SCENE"
  for i in $(seq 1 $N); do
    "$HDC" file recv "/data/local/tmp/f$i.jpeg" "$OUT/$SCENE/${pre}_$(printf '%02d' $i).jpeg" >/dev/null 2>&1
  done
  local n
  n=$(ls "$OUT/$SCENE/${pre}_"*.jpeg 2>/dev/null | wc -l | tr -d ' ')
  local uniq
  uniq=$(md5 -q "$OUT/$SCENE/${pre}_"*.jpeg 2>/dev/null | sort -u | wc -l | tr -d ' ')
  echo "  $pre: 收到 $n 帧，其中**不同** $uniq 帧 $([ "$uniq" -ge 3 ] && echo '✅ 拍到了运动' || echo '⚠️ 几乎静止 —— 动效可能没生效或太短')"
}

need_build() {
  local hap="$ROOT/entry/build/default/outputs/default/entry-default-signed.hap"
  [ -f "$hap" ] || { echo "❌ 没有 HAP"; exit 1; }
  local newer
  newer=$(find "$ROOT/entry/src/main/ets" -type f -newermt "@$(stat -f %m "$hap")" 2>/dev/null | head -3)
  if [ -n "$newer" ]; then
    echo "⚠️ HAP 比源码旧，装了也拍不到新动效："; echo "$newer" | sed 's/^/     /'
    echo "     ⇒ 先让 lead 重新构建"; exit 2
  fi
  echo "  HAP 新鲜度 ✓"
}

ensure_app() {
  "$HDC" shell aa force-stop "$PKG" >/dev/null 2>&1
  sleep 1
  "$HDC" shell aa start -a EntryAbility -b "$PKG" >/dev/null 2>&1
  sleep 7
}

TARGET=$("$HDC" list targets 2>/dev/null | head -1 | tr -d '\r')
[ -z "$TARGET" ] && { echo "❌ 没有设备"; exit 1; }
echo "  设备: $TARGET"

if [ "$SCENE" = "transition" ] || [ "$SCENE" = "all" ]; then
  say "② 页面转场：点第 1 张卡片 → 进游戏（期望：上浮 + 淡入，而不是硬切）"
  need_build; ensure_app
  # 卡片区域（实测：第 1 张卡图标中心约 195,1490）
  "$HDC" shell "rm -f /data/local/tmp/f*.jpeg; for i in \$(seq 1 $N); do snapshot_display -f /data/local/tmp/f\$i.jpeg; sleep $GAP; done; uitest uiInput click 195 1490" >/dev/null 2>&1 &
  sleep 1.2
  shot "进游戏"
  sleep 4
  say "② 反向：点返回键 → 回首页"
  "$HDC" shell "rm -f /data/local/tmp/g*.jpeg; for i in \$(seq 1 $N); do snapshot_display -f /data/local/tmp/g\$i.jpeg; sleep $GAP; done; uitest uiInput click 130 300" >/dev/null 2>&1 &
  sleep 1.2
  shot "返回首页"
fi

if [ "$SCENE" = "stagger" ] || [ "$SCENE" = "all" ]; then
  say "③ 首屏错峰进场：冷启动后立刻连拍（期望：卡片依次淡入上移）"
  need_build
  "$HDC" shell aa force-stop "$PKG" >/dev/null 2>&1
  sleep 1
  "$HDC" shell "rm -f /data/local/tmp/f*.jpeg; aa start -a EntryAbility -b $PKG; for i in \$(seq 1 $N); do snapshot_display -f /data/local/tmp/f\$i.jpeg; sleep $GAP; done" >/dev/null 2>&1
  mkdir -p "$OUT/$SCENE"
  for i in $(seq 1 $N); do
    "$HDC" file recv "/data/local/tmp/f$i.jpeg" "$OUT/$SCENE/冷启动_$(printf '%02d' $i).jpeg" >/dev/null 2>&1
  done
  uniq=$(md5 -q "$OUT/$SCENE/冷启动_"*.jpeg 2>/dev/null | sort -u | wc -l | tr -d ' ')
  echo "  冷启动: 不同帧 $uniq $([ "$uniq" -ge 3 ] && echo '✅' || echo '⚠️')"
fi

if [ "$SCENE" = "rolling" ] || [ "$SCENE" = "all" ]; then
  say "④ 数字滚动：切到统计页连拍（期望：数字从 0 滚上去）"
  need_build; ensure_app
  # 底部导航「统计」实测中心约 (660,2060)
  "$HDC" shell "rm -f /data/local/tmp/f*.jpeg; for i in \$(seq 1 $N); do snapshot_display -f /data/local/tmp/f\$i.jpeg; sleep $GAP; done; uitest uiInput click 660 2060" >/dev/null 2>&1 &
  sleep 1.0
  shot "统计页"
fi

say "拼帧序列图（横向，一眼看轨迹）"
python3 - "$OUT" "$SCENE" <<'PY'
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont
out, scene = sys.argv[1], sys.argv[2]
try:
    f = ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', 18)
except Exception:
    f = ImageFont.load_default()
for d in sorted(glob.glob(os.path.join(out, scene, '*'))):
    pass
groups = {}
for p in sorted(glob.glob(os.path.join(out, scene, '*.jpeg'))):
    pre = os.path.basename(p).rsplit('_', 1)[0]
    groups.setdefault(pre, []).append(p)
for pre, paths in groups.items():
    paths = sorted(paths)[:14]
    if len(paths) < 3:
        continue
    H = 420
    ims = []
    for p in paths:
        im = Image.open(p).convert('RGB')
        w = int(im.width * H / im.height)
        ims.append(im.resize((w, H), Image.LANCZOS))
    W = sum(i.width for i in ims) + 8 * (len(ims) + 1)
    sheet = Image.new('RGB', (W, H + 34), (245, 247, 250))
    x = 8
    for i, im in enumerate(ims):
        sheet.paste(im, (x, 28))
        ImageDraw.Draw(sheet).text((x + 4, 6), f'#{i+1}', fill=(20, 30, 50), font=f)
        x += im.width + 8
    dst = os.path.join(out, scene, f'{pre}_帧序列.png')
    sheet.save(dst)
    print('  →', dst)
PY

say "完成：$OUT/$SCENE"
