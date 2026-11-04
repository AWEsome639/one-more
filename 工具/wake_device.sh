#!/usr/bin/env bash
# wake_device.sh —— 确保模拟器屏幕亮着且 App 在跑（幂等，可反复调用）
#
# ★ 为什么需要（第 1236 轮，判据 635/636/637）
#   本机的 HarmonyOS 模拟器**闲置会自动息屏**：
#     · 截图字节数正常（5 万+）但平均亮度 ≈ 0
#     · `pidof` 空（App 被挂起）｜ `dumpLayout` **0 字节**
#   而且它是**反复发生**的（1235、1236 两轮都遇到）
#   ⇒ 只在流程开头唤醒一次**不够**，每个阶段前都可能已息屏
#   ⇒ 正确做法：把"唤醒 + 三件套验证"做成幂等工具，**每步都调**
#
# 用法： bash 工具/wake_device.sh [bundle] [ability]
#   成功 ⇒ 退出码 0，打印 `OK <pid>`
#   失败 ⇒ 非 0，打印 `FAIL <原因>`
set -u
BUNDLE="${1:-com.andrewoscar.onemore}"
ABILITY="${2:-EntryAbility}"

HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
T="$HC -t 127.0.0.1:5555"

A() { timeout 30 $T shell "$@" 2>&1 | tr -d '\r'; }
lum() {
  timeout 30 $T shell "snapshot_display -t png -f /data/local/tmp/_wk.png" >/dev/null 2>&1
  timeout 30 $T file recv /data/local/tmp/_wk.png /tmp/_wk.png >/dev/null 2>&1
  python3 - <<'PY'
import os
try:
    from PIL import Image
    import numpy as np
    p='/tmp/_wk.png'
    if not os.path.exists(p) or os.path.getsize(p) < 2000:
        print('0'); raise SystemExit
    print('%.1f' % float(np.array(Image.open(p).convert('RGB')).mean()))
except Exception:
    print('0')
PY
}

timeout 15 $T shell "echo t" >/dev/null 2>&1 || timeout 15 $HC tconn 127.0.0.1:5555 >/dev/null 2>&1

# ── ① 唤醒 + 解锁（多手段，幂等）──
for attempt in 1 2 3; do
  A "power-shell wakeup" >/dev/null 2>&1
  sleep 1
  A "uitest uiInput swipe 660 1900 660 300 500" >/dev/null 2>&1
  sleep 1
  L=$(lum)
  # ── ② 屏幕亮了（mean > 20）才继续 ──
  if python3 -c "import sys; sys.exit(0 if float('$L') > 20 else 1)" 2>/dev/null; then
    # ── ③ App 必须在跑 ──
    P=$(A "pidof $BUNDLE" | head -1 | tr -d ' \r')
    if ! echo "$P" | grep -qE '^[0-9]+$'; then
      A "aa start -b $BUNDLE -a $ABILITY" >/dev/null 2>&1
      sleep 8
      P=$(A "pidof $BUNDLE" | head -1 | tr -d ' \r')
    fi
    if ! echo "$P" | grep -qE '^[0-9]+$'; then
      echo "FAIL:app_not_running(lum=$L)"; exit 2
    fi
    # ── ④ UI 树必须可读（判据 636：这是"目标正常"而不是"仪表正常"）──
    #   ⚠️ 判据 638：刚唤醒时 dump 可能只返回 **几百字节**（还没就绪），
    #     所以这里要**重试几次**，不能一次 420 字节就判"设备不可用"。
    SZ=0
    for dt in 1 2 3 4; do
      A "uitest dumpLayout -p /data/local/tmp/_wk.json" >/dev/null 2>&1
      sleep 1
      timeout 25 $T file recv /data/local/tmp/_wk.json /tmp/_wk.json >/dev/null 2>&1
      SZ=$(stat -f%z /tmp/_wk.json 2>/dev/null || stat -c%s /tmp/_wk.json 2>/dev/null || echo 0)
      [ "$SZ" -ge 500 ] && break
      sleep 1
    done
    if [ "$SZ" -lt 500 ]; then
      echo "FAIL:dump_empty(lum=$L,size=$SZ,attempt=$attempt)"; exit 3
    fi
    echo "OK $P"
    exit 0
  fi
  sleep 1
done

echo "FAIL:screen_still_black(lum=$L)"
exit 4
