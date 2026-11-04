#!/usr/bin/env bash
# start_app_on_device.sh —— 在模拟器上「先把界面弄到真的可用」再启动 app
#
# ★ 为什么需要（第 1320 轮，三十轮换来的）
#   之前 20+ 轮都失败，症状都是「亮度起来了，但 aa start 后 pidof 空」。
#   真因：**锁屏**。而**锁屏的亮度也是 160** ⇒ 「亮度 > 20」分不出锁屏与桌面。
#   ⇒ 必须**显式 swipe 解锁**（判据 742/754），不能指望 aa start 顶开锁屏。
#
# 四步流程（实测 115s 后屏幕亮，解锁后立刻可用）：
#   ① 启动实例
#   ② 等「亮度 > 20」（实测 ~115s；最多等 240s）
#   ③ **swipe 解锁**（从底部指示条往上划；坐标按屏高现算）
#   ④ 校验「已到桌面」（dumpLayout 有内容且无锁屏特征）
#   ⑤ 启动 app（判据 831：亮度 + pidof 都通过才算就绪）
#
# 用法:
#   bash 工具/start_app_on_device.sh [实例名] [期望WxH]
#     默认 onemore6 / 585x585（195×195 vp）
#
# 退出码:
#   0 = app 已起来（并打印 PID）
#   1 = 屏幕没亮
#   2 = 解锁失败（仍在锁屏）
#   3 = app 启动失败
#   4 = 环境问题（hdc 不可用）

set -u

INST="${1:-onemore6}"
EXPECT="${2:-}"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET="127.0.0.1:5555"
PKG="com.andrewoscar.onemore"
MAX_WAIT="${MAX_WAIT:-240}"

log() { printf '  %s\n' "$*"; }
A() { timeout 20 "$HC" -t "$TARGET" shell "$@" 2>&1 | tr -d '\r'; }

[ -x "$EMU" ] || { log "🔴 找不到模拟器: $EMU"; exit 4; }
[ -x "$HC" ] || { log "🔴 找不到 hdc: $HC"; exit 4; }

# ── ① 启动实例 ──
for P in $(ps aux | grep '[E]mulator' | grep -v grep | awk '{print $2}'); do
  kill -TERM "$P" 2>/dev/null
done
sleep 4
timeout 8 "$HC" kill -r >/dev/null 2>&1
sleep 2
log "① 启动实例: $INST"
nohup "$EMU" -start "$INST" > "/tmp/_saod_${INST}.log" 2>&1 &

# ── ② 等亮度 > 20 ──
lum() {
  rm -f /tmp/_saod.png
  A "snapshot_display -t png -f /data/local/tmp/_saod.png" >/dev/null 2>&1
  timeout 15 "$HC" -t "$TARGET" file recv /data/local/tmp/_saod.png /tmp/_saod.png >/dev/null 2>&1
  python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/_saod.png'
print('%.0f' % float(np.array(Image.open(p).convert('RGB')).mean()) if (os.path.exists(p) and os.path.getsize(p)>2000) else '-1')
" 2>/dev/null | tr -d '\r\n'
}
T0=$(date +%s)
ON=0
log "② 等屏幕亮（最多 ${MAX_WAIT}s）"
while :; do
  EL=$(( $(date +%s) - T0 ))
  [ "$EL" -gt "$MAX_WAIT" ] && break
  sleep 10
  timeout 3 "$HC" tconn "$TARGET" >/dev/null 2>&1
  L=$(lum)
  if python3 -c "import sys; sys.exit(0 if float('${L:--1}') > 20 else 1)" 2>/dev/null; then
    log "   屏幕亮（${EL}s，亮度 ${L}）"
    ON=1
    break
  fi
done
[ "$ON" = "0" ] && { log "🔴 ${MAX_WAIT}s 内屏幕未亮"; exit 1; }

# ── ③ swipe 解锁（坐标按屏高现算，判据 742/754）──
W=$(python3 -c "
from PIL import Image; import os
p='/tmp/_saod.png'
print(Image.open(p).width if (os.path.exists(p) and os.path.getsize(p)>2000) else 585)
" 2>/dev/null | tr -d '\r\n')
H=$(python3 -c "
from PIL import Image; import os
p='/tmp/_saod.png'
print(Image.open(p).height if (os.path.exists(p) and os.path.getsize(p)>2000) else 585)
" 2>/dev/null | tr -d '\r\n')
CX=$((W/2))
Y0=$(( H * 95 / 100 ))
Y1=$(( H * 30 / 100 ))
log "③ swipe 解锁（${W}x${H}）：${CX} ${Y0} → ${CX} ${Y1}"
for k in 1 2 3; do
  A "power-shell wakeup" >/dev/null 2>&1
  A "uitest uiInput swipe ${CX} ${Y0} ${CX} ${Y1} 120" >/dev/null 2>&1
  sleep 1
done

# ── ④ 校验「已到桌面」──
rm -f /tmp/_saod.json
A "uitest dumpLayout -p /data/local/tmp/_saod.json" >/dev/null 2>&1
timeout 15 "$HC" -t "$TARGET" file recv /data/local/tmp/_saod.json /tmp/_saod.json >/dev/null 2>&1
VERDICT=$(python3 - <<'PY' 2>/dev/null
import json, os
p = '/tmp/_saod.json'
n = os.path.getsize(p) if os.path.exists(p) else -1
if n < 400:
    print('EMPTY:%d' % n); raise SystemExit
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
LOCK = ('无服务', '未插卡', '解锁', '输入密码', '面容', '屏保')
if any(k in joined for k in LOCK):
    print('LOCK'); raise SystemExit
print('OK:%d' % len(texts))
PY
)
case "$VERDICT" in
  OK:*)
    NTEXTS="${VERDICT#OK:}"
    # ★ 判据 839（第 1321 轮）：**桌面的 dumpLayout 可能**不含文本节点**
    #   实证：解锁后 dump 有效但 0 条文本 ⇒ 若用「文本数 ≥ 3」会**假失败**
    #   ⇒ 正确判据：**dump ≥ 400 字节** + **`pidof com.ohos.sceneboard` 非空**
    # ★ 判据 876（第 1336 轮）：**`pidof <系统进程>` 可能返回多个 PID**
    #   实证：`pidof com.ohos.sceneboard` ⇒ **"1463 1566"**（空格分隔）
    #   ⇒ 原来的 `^[0-9]+$` 不匹配 ⇒ **误报「桌面进程不在」**
    #   ⇒ 改成「取出第一个 PID，再校验它是纯数字」
    SB=$(A "pidof com.ohos.sceneboard" | head -1 | awk '{print $1}')
    if ! printf '%s' "$SB" | grep -qE '^[0-9]+$'; then
      log "🔴 桌面进程不在（com.ohos.sceneboard pidof 首个: $(printf '%s' "$SB" | cut -c1-30)）"
      exit 2
    fi
    log "   已到桌面（sceneboard PID=${SB}，dump 文本 ${NTEXTS} 条）"
    ;;
  LOCK)
    log "🔴 仍在锁屏（判据 833：可能是 swipe 起点/终点不对）"
    exit 2
    ;;
  *)
    log "🔴 桌面校验失败: $VERDICT"
    exit 2
    ;;
esac

# ── ⑤ 启动 app（判据 831：亮度 + pidof 都要过）──
log "④ 启动 app"
A "aa start -b $PKG -a EntryAbility" >/dev/null 2>&1
PID=""
for t in 2 3 3 4 5 6; do
  sleep "$t"
  PID=$(A "pidof $PKG" | head -1 | awk '{print $1}')
  printf '%s' "$PID" | grep -qE '^[0-9]+$' && break
done
if ! printf '%s' "$PID" | grep -qE '^[0-9]+$'; then
  log "🔴 app 启动失败（pidof: $(printf '%s' "$PID" | cut -c1-40)）"
  log "   ⇒ 判据 804：失败时显示 NOT_RUNNING，不是把错误串当 PID"
  exit 3
fi
log "   ✅ **PID=$PID**（判据 831 三级阶梯全部通过）"
printf '%s' "$PID"
exit 0
