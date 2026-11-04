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
T="${HC} -t 127.0.0.1:5555"

A() { timeout 30 ${T} shell "$@" 2>&1 | tr -d '\r'; }
lum() {
  timeout 30 ${T} shell "snapshot_display -t png -f /data/local/tmp/_wk.png" >/dev/null 2>&1
  # ★ 判据 669：**先删本地再 recv** —— 否则 hdc 失败时会读到上一次的旧截图
  rm -f /tmp/_wk.png
  timeout 30 ${T} file recv /data/local/tmp/_wk.png /tmp/_wk.png >/dev/null 2>&1
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

timeout 15 ${T} shell "echo t" >/dev/null 2>&1 || timeout 15 ${HC} tconn 127.0.0.1:5555 >/dev/null 2>&1

# ── ① 唤醒 + 解锁（多手段，幂等）──
# ★ 判据 637：单一手段唤不醒 ⇒ **多手段连打**
for attempt in 1 2 3 4; do
  A "power-shell wakeup" >/dev/null 2>&1;                       sleep 1
  A "uitest uiInput swipe 660 1900 660 300 500" >/dev/null 2>&1; sleep 1
  A "uitest uiInput click 660 1116" >/dev/null 2>&1;             sleep 1
  A "uitest uiInput keyEvent 2047" >/dev/null 2>&1;              sleep 2
  A "power-shell wakeup" >/dev/null 2>&1;                       sleep 1
  A "uitest uiInput swipe 660 1900 660 300 500" >/dev/null 2>&1; sleep 2
  L=$(lum)
  # ── ② 屏幕亮了（mean > 20）才继续 ──
  if python3 -c "import sys; sys.exit(0 if float('${L}') > 20 else 1)" 2>/dev/null; then
    # ── ③ App 必须在跑 ──
    P=$(A "pidof ${BUNDLE}" | head -1 | tr -d ' \r')
    if ! echo "${P}" | grep -qE '^[0-9]+$'; then
      A "aa start -b ${BUNDLE} -a ${ABILITY}" >/dev/null 2>&1
      sleep 8
      P=$(A "pidof ${BUNDLE}" | head -1 | tr -d ' \r')
    fi
    if ! echo "${P}" | grep -qE '^[0-9]+$'; then
      echo "FAIL:app_not_running(lum=${L})"; exit 2
    fi
    # ── ④ UI 树必须可读（判据 636：这是"目标正常"而不是"仪表正常"）──
    #   ⚠️ 判据 638：刚唤醒时 dump 可能只返回 **几百字节**（还没就绪），
    #     所以这里要**重试几次**，不能一次 420 字节就判"设备不可用"。
    #
    #   ⚠️⚠️ 判据 644（第 1240 轮纠正）：**不能用「dump 字节数」判"页面就绪"**
    #     实测：`aa start` 之后立刻 dump ⇒ **25366 字节**（远超任何合理阈值）
    #     但文字只有 **5 条**：['07:29', '07', ':', '29', '100'] = **纯状态栏**
    #     ⇒ App 还没渲染完，而字节数断言已经"通过"
    #     ⇒ 之后去取 🔍 当然取不到，还以为是"App 坏了"
    #
    #   ⇒ 正确判据：**「有内容的文字节点数」≥ 8**
    #     （状态栏单独就有 5 条：时间 3 段 + 电量 2 段 ⇒ 必须明显多于它）
    NTXT=0
    for dt in 1 2 3 4 5 6; do
      A "uitest dumpLayout -p /data/local/tmp/_wk.json" >/dev/null 2>&1
      sleep 1
      rm -f /tmp/_wk.json            # 判据 669：先删再收
      timeout 25 ${T} file recv /data/local/tmp/_wk.json /tmp/_wk.json >/dev/null 2>&1
      SZ=$(stat -f%z /tmp/_wk.json 2>/dev/null || stat -c%s /tmp/_wk.json 2>/dev/null || echo 0)
      if [ "${SZ}" -ge 500 ]; then
        NTXT=$(python3 - <<'PY2' 2>/dev/null || echo 0
import json, os
p = '/tmp/_wk.json'
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception:
    print(0); raise SystemExit
n = 0
def f(node):
    global n
    if not isinstance(node, dict): return
    if (node.get('attributes', {}).get('text') or '').strip():
        n += 1
    for c in node.get('children', []) or []:
        f(c)
f(d)
print(n)
PY2
)
        [ "${NTXT:-0}" -ge 8 ] && break
      fi
      sleep 1
    done
    if [ "${NTXT:-0}" -lt 8 ]; then
      echo "FAIL:page_not_rendered(lum=${L},size=${SZ:-0},texts=${NTXT:-0},attempt=${attempt})"; exit 3
    fi

    # ── ⑤ ⚠️⚠️ 判据 639 + 642：**PID 有值 ≠ App 在前台**
    #   判据 639（第 1237 轮）：`pidof` = 3472 但 dump 全是
    #     「设置 / 图库 / 文件管理 / 日历」= 桌面 ⇒ 每步操作都打到桌面。
    #
    #   ⚠️ 判据 642（第 1239 轮纠正）：**不能用「主页标题」当特征文字**
    #     一开始我写的是 `grep -q "One More"`（主页顶栏文字）
    #     ⇒ 但 App **进到游戏内页后**，标题变成游戏名（如「字谜定义」），
    #       「One More」**不再出现** ⇒ 断言必然误判为"不在前台"
    #     实测：`FAIL:app_not_foreground(lum=239.4, pid=3472)` 而屏幕明明亮着、
    #            App 明明在跑，只是停在游戏内页。
    #
    #   ⇒ 正确做法：断言「**不是桌面**」，而不是「是主页」：
    #     · 桌面（启动器）有稳定的图标名：「图库 / 文件管理 / 日历 / 设置」
    #     · App 的任何页面都**不会有**这些
    #     ⇒ 用「桌面特征文字」做**否定**判断，才在全 App 范围内成立。
    FG=0
    LAUNCHER_RE='图库|文件管理|日历|相机|应用市场|备忘录'
    for ft in 1 2 3; do
      if [ -f /tmp/_wk.json ] && ! grep -qE "${LAUNCHER_RE}" /tmp/_wk.json 2>/dev/null; then
        FG=1; break
      fi
      # 在桌面 ⇒ 拉起来
      A "aa start -b ${BUNDLE} -a ${ABILITY}" >/dev/null 2>&1
      sleep 6
      A "uitest dumpLayout -p /data/local/tmp/_wk.json" >/dev/null 2>&1
      sleep 1
      timeout 25 ${T} file recv /data/local/tmp/_wk.json /tmp/_wk.json >/dev/null 2>&1
      if [ -f /tmp/_wk.json ] && ! grep -qE "${LAUNCHER_RE}" /tmp/_wk.json 2>/dev/null; then
        FG=1; break
      fi
    done
    if [ "${FG}" != "1" ]; then
      echo "FAIL:app_not_foreground(lum=${L},pid=${P})"; exit 5
    fi

    echo "OK ${P}"
    exit 0
  fi
  sleep 1
done

echo "FAIL:screen_still_black(lum=${L})"
exit 4
