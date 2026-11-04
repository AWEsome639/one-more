#!/usr/bin/env bash
# capture_splash_timing.sh —— 抓开屏时序（**带非空断言**，判据 810）
#
# ★ 为什么需要（第 1310 轮）
#   历史上「SPLASH_TIMING_hilog_800x1280_20261104.log」只有 **1 字节**（一个换行），
#   却被提交说明写成「#8 开屏时序 → ✅ 已完成」
#   ⇒ 因为抓取脚本**没有断言「至少抓到一条」**
#   ⇒ 本脚本最后一步必须验证：`grep -c SplashTiming >= 1`，否则 exit 1
#
# 用法:
#   bash 工具/capture_splash_timing.sh [设备标签]
#     设备标签用于文件名，如 800x1280（缺省用 screen size 现算）
#
# 退出码:
#   0 = 抓到了（并打印实测行数）
#   1 = **一行都没抓到**（并说明可能原因）
#   2 = 环境问题（hdc / 设备不可用）

set -u

TAG="${1:-auto}"
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET="127.0.0.1:5555"
PKG="com.andrewoscar.onemore"
OUTDIR="验收截图-v1.0.1"
PATTERN="SplashTiming"

log() { printf '  %s\n' "$*"; }
A() { timeout 30 "$HDC" -t "$TARGET" shell "$@" 2>&1 | tr -d '\r'; }

if [ ! -x "$HDC" ]; then
  log "🔴 找不到 hdc: $HDC"
  exit 2
fi

timeout 4 "$HDC" tconn "$TARGET" >/dev/null 2>&1
if ! A "echo OK" | grep -q OK; then
  log "🔴 设备不可用（hdc 无响应）"
  log "   ⇒ 先跑 工具/wait_device_ready.sh（四道门）"
  exit 2
fi

# ── 设备标签：自动从屏幕尺寸现算 ──
if [ "$TAG" = "auto" ]; then
  rm -f /tmp/_cst.png
  A "snapshot_display -t png -f /data/local/tmp/_cst.png" >/dev/null 2>&1
  timeout 20 "$HDC" -t "$TARGET" file recv /data/local/tmp/_cst.png /tmp/_cst.png >/dev/null 2>&1
  TAG=$(python3 -c "
from PIL import Image
import os
p='/tmp/_cst.png'
if os.path.exists(p) and os.path.getsize(p)>2000:
    w,h=Image.open(p).size
    print('%dx%d' % (int(round(w/3)), int(round(h/3))))
else: print('unknown')
" 2>/dev/null | tr -d '\r\n')
  [ -z "$TAG" ] && TAG="unknown"
fi
log "设备标签: ${TAG}"

mkdir -p "$OUTDIR"
OUT="${OUTDIR}/SPLASH_TIMING_hilog_${TAG}_$(date +%Y%m%d).log"

# ── 抓取：清缓冲 → 冷启 → 等 → 取 ──
log "① 强制停止 + 清 hilog 缓冲"
A "aa force-stop $PKG" >/dev/null 2>&1
A "hilog -r" >/dev/null 2>&1
sleep 1

log "② 冷启动 app"
A "aa start -b $PKG -a EntryAbility" >/dev/null 2>&1
PID=""
for t in 3 4 5 6; do
  sleep $t
  PID=$(A "pidof $PKG" | head -1)
  printf '%s' "$PID" | grep -qE '^[0-9]+$' && break
done
if ! printf '%s' "$PID" | grep -qE '^[0-9]+$'; then
  log "🔴 app 没起来（pidof 返回: $(printf '%s' "$PID" | cut -c1-40)）"
  log "   ⇒ 判据 804：失败时显示 NOT_RUNNING，不是把错误串当 PID"
  exit 2
fi
log "   PID = $PID"

log "③ 等开屏播完（判据 800：窗口很短，但开屏本身约 2.5s）"
sleep 6

log "④ 抓 SplashTiming"
A "hilog -x" 2>/dev/null | grep -E "$PATTERN" > "$OUT" 2>/dev/null || true

# ── ★ 判据 810：非空断言 ──
# ── ★★ 判据 848（第 1325 轮）：**`grep -c` 匹配 0 行时退出码是 1，不是 0**
#     实证：`LINES=$(grep -c ... || echo 0)` ⇒ grep 输出 "0" 且退出 1
#           ⇒ `|| echo 0` **也执行** ⇒ LINES = "0\n0"（两行）
#           ⇒ `[ "$LINES" -lt 1 ]` 报 "integer expression expected"
#           ⇒ **非空断言被跳过** ⇒ 打印「✅ 抓到 0 行」（假成功）
#     ⇒ 正确写法：只取 grep 的输出，**不要 `|| echo 0`**
BYTES=$(stat -f%z "$OUT" 2>/dev/null || echo 0)
LINES=$(grep -c "$PATTERN" "$OUT" 2>/dev/null || true)
LINES=$(printf '%s' "${LINES:-0}" | head -1 | tr -d ' \r')
case "$LINES" in ''|*[!0-9]*) LINES=0 ;; esac

log "⑤ 校验"
log "   文件: $OUT"
log "   字节: $BYTES ｜ 匹配行: $LINES"

if [ "${LINES:-0}" -lt 1 ]; then
  log "🔴 **抓到 0 行**（判据 810）"
  log "   ⇒ 这份日志**不能**当作「已验」，删掉以免误用"
  rm -f "$OUT"
  log "   可能原因："
  log "     · app 没真正冷启（判据 530：aa start 成功 ≠ 起来了）"
  log "     · 抓取窗口错过了开屏（开屏约 2.2~2.5s）"
  log "     · 该构建未开 `Diag.splashTiming`（core/Diag.ets）"
  log "     · hilog 缓冲被别的进程刷掉（试 `hilog -r` 后再抓）"
  exit 1
fi

log "   ✅ 抓到 ${LINES} 行"
log ""
log "   实测内容："
grep -E "accum=|drift=|dropped=" "$OUT" | sed 's/^/     /' | head -6
exit 0
