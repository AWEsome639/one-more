#!/usr/bin/env bash
# ============================================================================
#  工具/capture_splash_terminal.sh —— **两阶段抓帧**：找「满亮终态」那一瞬间
#
#  为什么需要它（判据 996/1007/1008）：
#    `snapshot_display` 在全分辨率（2400×3840）上约 **1s/帧**
#    而开屏的「全亮窗口」在**动画时间**上只有 ~580ms（t ∈ [1370, 1950] / 2270）
#    帧率低时 ≈ **1s 墙钟** ⇒ **正好落在两帧之间，抓不到**
#
#    而 `snapshot_display -w N -h N` 支持**降分辨率** ⇒ 传输快得多
#    ⇒ 两阶段：
#      ① **快速扫**：低分辨率连拍，找「8 段亮度都 ≥ 阈值」的那一帧的**序号/时刻**
#      ② **单拍**：用同样的 delay + 序号偏移，在那一刻**全分辨率拍一张**
#
#  用法：bash 工具/capture_splash_terminal.sh <WxH标签> [扫描分辨率宽]
#    例：bash 工具/capture_splash_terminal.sh 800x1280 800
# ============================================================================
set -u
TAG="${1:?用法: capture_splash_terminal.sh <WxH> [扫描宽]}"
SCANW="${2:-800}"
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
OUT="验收截图-v1.0.1"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
TMP="/tmp/splash_term_${TAG}"
mkdir -p "$TMP"

A() { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }

case "$TAG" in
  853x533)  INST=onemore  ;;
  800x1280) INST=onemore2 ;;
  440x744)  INST=onemore3 ;;
  233x233)  INST=onemore4 ;;
  960x540)  INST=onemore5 ;;
  195x195)  INST=onemore6 ;;
  *) echo "🔴 未知尺寸 $TAG"; exit 2 ;;
esac

echo "════════════════════════════════════════════════════════════════"
echo "  两阶段抓帧：${TAG}（实例 ${INST}，扫描宽 ${SCANW}）"
echo "════════════════════════════════════════════════════════════════"

# ── ⓪' 等设备可用（判据 1012：别相信 install 的空输出）──
echo "  ⓪' 等设备可用"
for k in $(seq 1 24); do
  timeout 5 "$HC" tconn 127.0.0.1:5555 >/dev/null 2>&1
  rm -f /tmp/_tw.png
  A "snapshot_display -w 400 -h 267 -t png -f /data/local/tmp/_tw.png" >/dev/null 2>&1
  timeout 10 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_tw.png /tmp/_tw.png >/dev/null 2>&1
  L=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/_tw.png'
print('%.0f' % np.array(Image.open(p).convert('RGB')).mean() if (os.path.exists(p) and os.path.getsize(p)>1500) else '-1')
" 2>/dev/null)
  if python3 -c "import sys; sys.exit(0 if float('${L:--1}')>20 else 1)" 2>/dev/null; then
    echo "     屏幕亮（亮度 ${L}，第 $((k*8))s）"
    break
  fi
  sleep 8
done

# ── ⓪'' 装 app 并**校验**（判据 1012：install 输出可能为空）──
if [ -f "$HAP" ]; then
  echo "  ⓪'' 装 app"
  timeout 900 "$HC" -t 127.0.0.1:5555 install -r "$HAP" >/tmp/_term_install.log 2>&1 || true
  CNT=$(A 'bm dump -a 2>/dev/null | grep -c "com.andrewoscar.onemore"')
  echo "     已装匹配行数: ${CNT:-0}"
  if [ "${CNT:-0}" -lt 1 ]; then
    echo "     🔴 装机失败（校验未通过）"
  fi
fi

# ── ⓪ 按层就绪（判据 1003）──
ER_SH="$(dirname "$0")/ensure_ready.sh"
if [ -s "$ER_SH" ]; then   # ★ 判据 812：用 -s（非空）不用 -f
  echo "  ⓪ 按层就绪"
  bash "$ER_SH" "$INST" 2>&1 | tail -2 | sed 's/^/     /' || true
fi

# ── ① 快速扫（低分辨率）──
echo ""
echo "  ① 快速扫时间轴（低分辨率 ${SCANW}px 宽，每帧 ~0.3s）"
rm -f "$TMP"/scan_*.png
A "aa force-stop com.andrewoscar.onemore" >/dev/null 2>&1
sleep 1
A "aa start -b com.andrewoscar.onemore -a EntryAbility" >/dev/null 2>&1
# ★ 判据 1018：**紧贴 `aa start` 开始扫**（原来有 `sleep 1`，会错过前 1 秒）
#   且**总时长 ≤ 8s**（26 帧 × 0.3s），而不是 18s
SCAN_N=26
for i in $(seq -w 1 $SCAN_N); do
  # ★ 判据 1016：`-h 0` 非法（`error: width W height 0 invalid!`）⇒ **显式算高度**
  #   按 TAG 的宽高比算：SCANH = SCANW × (H/W)
  case "$TAG" in
    853x533)  RATIO_H=533;  RATIO_W=853  ;;
    800x1280) RATIO_H=1280; RATIO_W=800  ;;
    440x744)  RATIO_H=744;  RATIO_W=440  ;;
    233x233)  RATIO_H=233;  RATIO_W=233  ;;
    960x540)  RATIO_H=540;  RATIO_W=960  ;;
    195x195)  RATIO_H=195;  RATIO_W=195  ;;
    *)        RATIO_H=0;    RATIO_W=1    ;;
  esac
  SCANH=$(( SCANW * RATIO_H / RATIO_W ))
  A "snapshot_display -w ${SCANW} -h ${SCANH} -t png -f /data/local/tmp/_s.png" >/dev/null 2>&1
  timeout 8 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_s.png "$TMP/scan_${i}.png" >/dev/null 2>&1
done
echo "     参数 ${SCANW}x${SCANH} ｜ 抓了 $(ls "$TMP"/scan_*.png 2>/dev/null | wc -l | tr -d ' ') 帧"

# ── ② 分析：找「开屏 + 有金 + 标题 8 段全亮」的第一帧与最后一帧 ──
echo ""
echo "  ② 分析（找 8 段亮度都 ≥ 阈值的第一帧）"
python3 - "$TMP" <<'PY'
import glob, os, sys
import numpy as np
from PIL import Image

tmp = sys.argv[1]
files = sorted(glob.glob(os.path.join(tmp, 'scan_*.png')))
good = []
info = []
for p in files:
    try:
        A = np.array(Image.open(p).convert('RGB'), dtype=np.int32)
    except Exception:
        continue
    H, W = A.shape[0], A.shape[1]
    top = float(A[:max(4, int(H*0.08))].mean())
    gold = ((A[:,:,0]>150)&(A[:,:,1]>100)&(A[:,:,2]<110)&(A[:,:,0]-A[:,:,2]>70))
    g = float(gold.mean()*100)
    if top >= 90 or g < 0.5:
        continue
    lum = A.mean(axis=2); bg = float(np.percentile(lum, 5)); fg = (lum-bg).clip(0)
    ghist = gold.sum(axis=1)
    gb, cur = [], None
    for y in range(H):
        if ghist[y] > W*0.004:
            if cur is None: cur = y
        else:
            if cur is not None:
                if y-cur > 3: gb.append((cur,y-1))
                cur = None
    if cur is not None: gb.append((cur,H-1))
    if not gb: continue
    g0,g1 = gb[0]
    rm = fg.sum(axis=1)/W; rpk = max(1e-6, rm.max())
    y = g1+3; tb=None
    while y < H:
        if rm[y] > rpk*0.06:
            y0=y
            while y < H and rm[y] > rpk*0.03: y+=1
            if y-y0 > 6: tb=(y0,y-1); break
        else: y+=1
    if tb is None: continue
    t0,t1 = tb
    tcol = fg[t0:t1+1].sum(axis=0); tpk = max(1e-6, tcol.max())
    on = np.where(tcol > tpk*0.20)[0]
    if len(on)==0: continue
    l, r = int(on.min()), int(on.max())
    if r-l < W*0.25: continue
    segs = [float(fg[t0:t1+1, l+(r-l)*k//8:l+(r-l)*(k+1)//8].max()) for k in range(8)]
    mn = min(segs) if segs else 0
    info.append((os.path.basename(p), round(top,0), round(g,2), r-l+1, round(mn,0)))
    if mn >= 150:
        good.append((os.path.basename(p), mn, r-l+1))

print('     合格开屏帧 %d 个' % len(info))
print('     %-16s %5s %6s %7s %7s' % ('帧', '顶部', '金%', '标题宽', '最小段'))
for n, tp, g, tw, mn in info:
    mark = ' ← **全亮**' if mn >= 150 else ''
    print('     %-16s %5.0f %6.2f %7d %7.0f%s' % (n, tp, g, tw, mn, mark))
print()
if good:
    print('     => **全亮帧**: %s' % [g[0] for g in good])
    print('     => 第一帧 %s（最小段 %.0f，标题宽 %d）' % good[0])
else:
    print('     => 本次扫描没有「8 段全亮」的帧')
PY

echo ""
echo "  ⚠️ 阶段②（全分辨率单拍）需要知道「全亮帧」对应的**墙钟时刻**"
echo "     而扫描是顺序连拍 ⇒ 帧序号 ≈ 时刻 × 扫描帧率"
echo "     ⇒ 若上一步有「全亮帧」，取其序号 N，再用"
echo "        delay = 启动延迟 + N × 单帧扫描耗时"
echo "     单拍一次全分辨率（见台账里手动的做法）"
echo ""
echo "  产物: $TMP"
