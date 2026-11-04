#!/usr/bin/env bash
# wait_device_ready.sh —— 等到「真的可以验证」为止（判据 797~802）
#
# ★ 为什么需要（第 1305 轮，来自第 1296~1304 轮的血）
#   我在这台机器上花了十几轮，每次都以为「设备就绪」：
#     · `hdc shell echo READY` 能答  ⇒ 只是 **hdc 守护进程**起来了
#     · 截图亮度 > 20               ⇒ 可能只是 **锁屏界面**
#     · 上次 200s 亮了              ⇒ **这次不一定**（窗口是概率性的）
#   ⇒ 所以「就绪」必须**四道门全过**，且每道门都要有**可测的量**。
#
# 用法:
#   bash 工具/wait_device_ready.sh            # 默认 420s 超时
#   bash 工具/wait_device_ready.sh 600        # 自定义超时秒数
#
# 退出码:
#   0 = 四道门全过（可以开始验证）
#   1 = 超时
#   2 = 输入/环境问题（hdc 找不到等）
#
# 通过后建议只做**一件事**（判据 800：有效窗口约 100 秒）
#
# ⚠️ **调用本脚本时不要用管道吞掉退出码**（判据 803）：
#   ✗ `bash 工具/wait_device_ready.sh 480 | sed 's/^/  /'; RC=$?`   ← RC 是 sed 的
#   ✓ `OUT=$(bash 工具/wait_device_ready.sh 480); RC=$?; echo "$OUT" | sed 's/^/  /'`

set -u

TIMEOUT="${1:-420}"
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET="127.0.0.1:5555"

# 门 ①：host swap 余量
#   ★ 判据 805（第 1305 轮）：**模拟器自身会吃掉 200~400 MB swap**
#     实证：启动前 1569 MB → 启动后 1293 MB（-276 MB）
#   ⇒ 本脚本应在**模拟器启动之后**运行；
#     若在启动前跑，阈值要再加 ~400 MB（建议 1900）
#   ★ 判据 797：实测 1276 MB 也可能不够
MIN_SWAP_MB="${MIN_SWAP_MB:-1500}"
# 门 ②：截图亮度下限
MIN_LUM="${MIN_LUM:-20}"
# 门 ③：dumpLayout 字节下限
MIN_DUMP="${MIN_DUMP:-500}"

log() { printf '  %s\n' "$*"; }

# ★ 判据 747 / 804（第 1305 轮）：`pidof` 失败时会返回**非空的错误串**
#   （如 `[Fail]Notmatchtargetfounded,checkconnect-keyplease`）
#   ⇒ 必须用**正则校验纯数字**，⛔ 不能用 `[ -n "$P" ]`
pid_of() {
  local p
  p=$(timeout 15 "$HDC" -t "$TARGET" shell "pidof $1" 2>&1 | tr -d '\r' | head -1)
  if printf '%s' "$p" | grep -qE '^[0-9]+$'; then
    printf '%s' "$p"
  else
    printf 'NOT_RUNNING(%s)' "$(printf '%s' "$p" | cut -c1-40)"
  fi
}

# ── 前置：hdc 存在 ──
if [ ! -x "$HDC" ]; then
  log "🔴 找不到 hdc: $HDC"
  exit 2
fi

# ── 门 ①：swap 余量 ──
swap_free_mb() {
  sysctl -n vm.swapusage 2>/dev/null \
    | grep -oE 'free = [0-9.]+' | grep -oE '[0-9.]+' | head -1 \
    | awk '{printf "%d", $1}'
}
SF=$(swap_free_mb)
SF=${SF:-0}
log "门① host swap free = ${SF} MB（要 > ${MIN_SWAP_MB}）"
if [ "$SF" -lt "$MIN_SWAP_MB" ]; then
  log "🔴 swap 余量不足 ⇒ **不要启动模拟器**（判据 774/797）"
  log "   实测：976 / 858 / 1054 / 1276 MB 都失败过"
  exit 1
fi

# ── 轮询剩余三道门 ──
A() { timeout 30 "$HDC" -t "$TARGET" shell "$@" 2>&1 | tr -d '\r'; }

lum_of() {
  rm -f /tmp/_wdr.png
  A "snapshot_display -t png -f /data/local/tmp/_wdr.png" >/dev/null 2>&1
  timeout 20 "$HDC" -t "$TARGET" file recv /data/local/tmp/_wdr.png /tmp/_wdr.png >/dev/null 2>&1
  python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/_wdr.png'
print('%.0f' % float(np.array(Image.open(p).convert('RGB')).mean()) if (os.path.exists(p) and os.path.getsize(p)>2000) else '-1')
" 2>/dev/null | tr -d '\r\n'
}

T0=$(date +%s)
LAST_REASON=""
while :; do
  EL=$(( $(date +%s) - T0 ))
  if [ "$EL" -gt "$TIMEOUT" ]; then
    log "🔴 超时 ${EL}s ｜ 最后原因: ${LAST_REASON}"
    exit 1
  fi

  # ── 门 ②：hdc 能答 ──
  timeout 4 "$HDC" tconn "$TARGET" >/dev/null 2>&1
  if ! A "echo OK" | grep -q OK; then
    LAST_REASON="门② hdc 无响应"
    sleep 8; continue
  fi

  # ── 门 ③：屏幕有内容（判据 799：hdc 就绪 ≠ 界面就绪，实测差 163s） ──
  L=$(lum_of)
  if ! python3 -c "import sys; sys.exit(0 if float('${L:--1}') > $MIN_LUM else 1)" 2>/dev/null; then
    LAST_REASON="门③ 亮度=${L}（要 > ${MIN_LUM}）"
    sleep 8; continue
  fi

  # ── 门 ④：界面有内容 且 **不是锁屏**（判据 801） ──
  rm -f /tmp/_wdr.json
  A "uitest dumpLayout -p /data/local/tmp/_wdr.json" >/dev/null 2>&1
  timeout 20 "$HDC" -t "$TARGET" file recv /data/local/tmp/_wdr.json /tmp/_wdr.json >/dev/null 2>&1
  VERDICT=$(python3 - "${MIN_DUMP}" <<'PY' 2>/dev/null
import json, os, sys
min_dump = int(sys.argv[1])
p = '/tmp/_wdr.json'
n = os.path.getsize(p) if os.path.exists(p) else -1
if n < min_dump:
    print('SIZE:%d' % n); raise SystemExit
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception:
    print('PARSE'); raise SystemExit
texts = []
def w(x):
    if not isinstance(x, dict): return
    s = (x.get('attributes', {}).get('text') or '').strip()
    if s: texts.append(s)
    for c in x.get('children', []) or []: w(c)
w(d)
joined = ' '.join(texts)
# 锁屏特征（判据 801）
LOCK = ('无服务', '未插卡', '解锁', '滑动解锁', '输入密码', '面容', '屏保')
if any(k in joined for k in LOCK):
    print('LOCK'); raise SystemExit
if len(texts) < 3:
    print('SPARSE:%d' % len(texts)); raise SystemExit
print('OK:%d' % len(texts))
PY
)
  case "$VERDICT" in
    OK:*)
      log "✅ 四门全过（${EL}s）"
      log "   门① swap ${SF} MB ｜ 门③ 亮度 ${L} ｜ 门④ ${VERDICT#OK:} 条文本"
      log ""
      log "⚠️ 判据 800：**有效窗口约 100 秒** ⇒ 现在只做**一件事**"
      log "   不要：装包 / 点导航 / 三页签扫描"
      log "   应该：只 dump 一次，或只截一张图"
      exit 0
      ;;
    LOCK)
      LAST_REASON="门④ **锁屏中**（亮度起来了但没解锁，判据 801）"
      ;;
    SIZE:*)
      LAST_REASON="门④ dump=${VERDICT#SIZE:} 字节（要 > ${MIN_DUMP}）"
      ;;
    SPARSE:*)
      LAST_REASON="门④ 只有 ${VERDICT#SPARSE:} 条文本（界面还没画完）"
      ;;
    *)
      LAST_REASON="门④ dump 解析失败"
      ;;
  esac
  sleep 8
done
