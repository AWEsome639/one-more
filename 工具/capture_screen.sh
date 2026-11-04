#!/usr/bin/env bash
# capture_screen.sh —— 抓「某个界面」在「当前设备」上的真机截图（一条命令做对全部步骤）
#
# ★ 为什么要有这个（第 1251 轮）
#   第 1250 轮我为了补一张「195×195 统计页」，连续踩了 6 个坑，**一张真数据都没拿到**：
#     664 `timeout` 把 `Emulator -start` 杀了（SIGTERM）
#     665 hdc 间歇掉线，`Device not found` 被误当成"设备不在"
#     666 `ui_get_xy` 返回越界坐标（y=2089 而屏幕 585）
#     667 `/tmp/*.json` 是上一台设备的残留 dump
#     668 `hdc -t 127.0.0.1:5555` 连的未必是你启动的那台
#     669 `file recv` 失败时本地旧文件还在（读到 2880×1620 的幽灵截图）
#   ⇒ 本脚本把这 6 条全部内置，**每次调用都自己验证前置条件**
#
# 用法：
#   bash 工具/capture_screen.sh <tab文字> <输出文件名> [期望分辨率,如 1320x2232]
# 例：
#   bash 工具/capture_screen.sh 统计 STATS_440x744 1320x2232
#   bash 工具/capture_screen.sh Stats STATS_195x195 585x585
#
# 退出码：0 = 成功并有截图 ｜ 1 = 参数错 ｜ 2 = 设备身份不符
#         3 = 设备不可用 ｜ 4 = 找不到目标页签 ｜ 5 = 截图失败
set -u
TAB="${1:-}"
OUT="${2:-}"
EXPECT="${3:-}"

[ -z "${TAB}" ] || [ -z "${OUT}" ] && { echo "用法: bash 工具/capture_screen.sh <tab文字> <输出名> [期望WxH]"; exit 1; }

HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV="127.0.0.1:5555"
T="${HC} -t ${DEV}"
DST="验收截图-v1.0.1/${OUT}.png"

A() { timeout 30 ${T} shell "$@" 2>&1 | tr -d '\r'; }

# ── 判据 665：每条命令前重连；失败输出不传递 ──
sh_retry() {
  local cmd="$1" i out
  for i in 1 2 3 4; do
    timeout 12 ${HC} tconn "${DEV}" >/dev/null 2>&1
    out=$(timeout 40 ${T} shell "${cmd}" 2>&1 | tr -d '\r')
    case "${out}" in
      *"Device not found"*|*"need connect-key"*) sleep 1; continue ;;
      *) printf '%s' "${out}"; return 0 ;;
    esac
  done
  return 1
}

# ── 判据 669：先删本地再 recv ──
recv_fresh() {
  local remote="$1" local_f="$2" i sz
  # ★ 判据 674（第 1252 轮）：**重试必须对称**
  #   `sh_retry`（设备端命令）有 4 次重试，但 `recv_fresh`（取回文件）原来一次都不重试
  #   ⇒ 表现：dumpLayout 在设备端成功，file recv 那一下掉线
  #          ⇒ recv_fresh 返回假 ⇒ 调用方 continue ⇒ **看起来"只跑了一轮"**
  for i in 1 2 3 4; do
    rm -f "${local_f}"                                  # 判据 669：先删
    timeout 12 ${HC} tconn "${DEV}" >/dev/null 2>&1
    timeout 25 ${T} file recv "${remote}" "${local_f}" >/dev/null 2>&1
    if [ -f "${local_f}" ]; then
      sz=$(stat -f%z "${local_f}" 2>/dev/null || echo 0)
      [ "${sz}" -gt 0 ] && return 0
    fi
    sleep 1
  done
  return 1
}

snap() {  # 抓图到 $1（本地）
  sh_retry "snapshot_display -t png -f /data/local/tmp/_cs.png" >/dev/null
  recv_fresh /data/local/tmp/_cs.png "$1"
}

lum() {
  python3 - "$1" <<'PY' 2>/dev/null || echo 0
import sys, os
p = sys.argv[1]
try:
    from PIL import Image
    import numpy as np
    if not os.path.exists(p) or os.path.getsize(p) < 2000:
        print(0); raise SystemExit
    print('%.1f' % float(np.array(Image.open(p).convert('RGB')).mean()))
except Exception:
    print(0)
PY
}

# ═══ ① 判据 665/668：连上 + **确认是哪台设备** ═══
timeout 15 ${HC} tconn "${DEV}" >/dev/null 2>&1
PING=$(sh_retry "echo PING") || PING=""
if ! printf '%s' "${PING}" | grep -q PING; then
  echo "FAIL:no_device"; exit 3
fi

snap /tmp/_cs_probe.png || { echo "FAIL:probe_snapshot"; exit 3; }
read -r PW PH <<<"$(python3 -c "
from PIL import Image
im=Image.open('/tmp/_cs_probe.png')
print(im.width, im.height)
" 2>/dev/null || echo '0 0')"
echo "  设备实际分辨率: ${PW}x${PH}"

if [ -n "${EXPECT}" ] && [ "${PW}x${PH}" != "${EXPECT}" ]; then
  echo "FAIL:wrong_device(got ${PW}x${PH}, expect ${EXPECT})"
  echo "     判据 668：hdc 连的未必是你启动的那台 —— 先切对设备再跑"
  exit 2
fi

# ═══ ② 唤醒 + 亮度 ═══
# ★ 判据 637 实测（第 1235 轮）：**单一手段唤不醒**，
#   必须「多手段连打」才有效 —— 当时的有效序列是 6 步：
#     power-shell wakeup → 上滑 → 点中心 → keyEvent 2047(POWER) → 再 wakeup → 再上滑
#   ⇒ 本段照抄该序列；每轮都验亮度，任一轮过即停
CX=$((PW/2)); CY=$((PH/2))
UP1=$((PH*88/100)); UP2=$((PH*12/100))
# ★★ 判据 672（第 1251 轮）：**这台模拟器息屏极快**
#   实测：手动唤醒后亮度 157.8，但**下一次 bash 调用时已降到 2.9**
#   ⇒ "唤醒"与"截图"必须在**同一条命令、零间隔**内完成
#   ⇒ 本段**不留任何 sleep**：唤醒命令 → 立刻 snapshot_display → 立刻 recv
#   ⇒ 而且**每轮都重试**（因为可能还没醒）
#
#   ★ 这也是为什么 "先睡 1 秒再判断" 的老写法必然失败：
#     它把"亮着的那 1 秒"睡掉了
OKL=0
for i in 1 2 3 4 5 6 7 8; do
  # ① 一串唤醒命令，**中间不 sleep**
  sh_retry "power-shell wakeup" >/dev/null
  sh_retry "uitest uiInput swipe ${CX} ${UP1} ${CX} ${UP2} 300" >/dev/null
  sh_retry "uitest uiInput click ${CX} ${CY}" >/dev/null
  sh_retry "uitest uiInput keyEvent 2047" >/dev/null
  sh_retry "power-shell wakeup" >/dev/null
  sh_retry "uitest uiInput swipe ${CX} ${UP1} ${CX} ${UP2} 300" >/dev/null
  # ② 立刻截图（零间隔）
  snap /tmp/_cs_wake.png
  L=$(lum /tmp/_cs_wake.png)
  echo "  唤醒第 ${i} 轮: 亮度 ${L}"
  python3 -c "import sys; sys.exit(0 if float('${L}')>20 else 1)" 2>/dev/null && { OKL=1; break; }
done
[ "${OKL}" = "0" ] && { echo "FAIL:screen_black"; exit 3; }

# ═══ ③ App 必须在**前台**（判据 639/642 + 670）══
#   ★★ 判据 670（第 1251 轮）：**否定式断言在「空/未渲染」内容上会空转通过**
#     第 1250 轮实测：`/tmp/_cs.json` 只有 **5 条文字**（纯状态栏，25366 字节）
#       ⇒ 它没有桌面文字（图库/文件管理…）⇒ `! grep` 为真 ⇒ **判据 642 的否定式通过了**
#       ⇒ 工具以为"在 App 前台"，实际是"什么都没渲染"
#     ⇒ 修法：**否定式必须配一个正面的最小内容量**（判据 644 的文字节点数 ≥ 8）
LAUNCHER_RE='图库|文件管理|日历|相机|应用市场|备忘录'
FG=0
NODES=0
for i in 1 2 3 4 5 6; do
  sh_retry "uitest dumpLayout -p /data/local/tmp/_cs.json" >/dev/null
  sleep 1
  recv_fresh /data/local/tmp/_cs.json /tmp/_cs.json || { sleep 1; continue; }
  # 正面检查：文字节点数（判据 644：未就绪=5 / 就绪≈48 ⇒ 阈值 8）
  NODES=$(python3 -c "
import json
try:
    d=json.load(open('/tmp/_cs.json',encoding='utf-8'))
except Exception:
    print(0); raise SystemExit
n=0
def f(x):
    global n
    if not isinstance(x,dict): return
    if (x.get('attributes',{}).get('text') or '').strip(): n+=1
    for c in x.get('children',[]) or []: f(c)
f(d); print(n)
" 2>/dev/null || echo 0)
  # 否定检查：不是桌面
  NOTL=1
  grep -qE "${LAUNCHER_RE}" /tmp/_cs.json 2>/dev/null && NOTL=0
  # ★ 判据 676（第 1252 轮）：**节点数阈值只是「不是纯状态栏」的门，不是「就绪」的门**
  #   实测：纯状态栏=5 ｜ 部分渲染=15 ｜ 加载完成=48
  #   ⇒ 用 8 当阈值会让「部分渲染」通过 ⇒ 之后找页签必然 NOT_FOUND
  #   ⇒ 正确做法：**直接等目标文字出现**（这才是"就绪"的定义）
  HAS_TAB=0
  grep -q "${TAB}" /tmp/_cs.json 2>/dev/null && HAS_TAB=1
  echo "     前台检查第 ${i} 轮: 文字节点=${NODES}｜ 非桌面=${NOTL}｜ 已见目标页签=${HAS_TAB}"
  if [ "${NOTL}" = "1" ] && [ "${HAS_TAB}" = "1" ]; then FG=1; break; fi
  # 兜底：节点数 ≥ 30 且非桌面（应对"目标文字在多语言下不同"的情况）
  if [ "${NOTL}" = "1" ] && [ "${NODES:-0}" -ge 30 ]; then FG=1; break; fi
  sh_retry "aa start -b com.andrewoscar.onemore -a EntryAbility" >/dev/null
  sleep 6
done
[ "${FG}" = "0" ] && { echo "FAIL:app_not_foreground(nodes=${NODES})"; exit 3; }

# ═══ ④ 关弹窗（开始玩/同意并继续）══
for i in 1 2 3; do
  B=$(python3 工具/ui_get_xy.py /tmp/_cs.json "" --text 开始玩 2>/dev/null) \
    || B=$(python3 工具/ui_get_xy.py /tmp/_cs.json "" --text 同意并继续 2>/dev/null) || B=""
  case "${B}" in
    [0-9]*" "[0-9]*) sh_retry "uitest uiInput click ${B}" >/dev/null; sleep 4
      sh_retry "uitest dumpLayout -p /data/local/tmp/_cs.json" >/dev/null; sleep 1
      recv_fresh /data/local/tmp/_cs.json /tmp/_cs.json ;;
    *) break ;;
  esac
done

# ═══ ⑤ 判据 666：找页签并**校验坐标在屏内** ═══
XY=$(python3 - "${PW}" "${PH}" "${TAB}" <<'PY' 2>/dev/null
import json, re, sys
W, H, want = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
try:
    d = json.load(open('/tmp/_cs.json', encoding='utf-8'))
except Exception:
    print('NO_DUMP'); raise SystemExit
hits = []
def walk(n):
    if not isinstance(n, dict): return
    a = n.get('attributes', {})
    if want in (a.get('text') or ''):
        m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds') or '')
        if m:
            b = [int(v) for v in m[0]]
            cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
            if 0 <= cx < W and 0 <= cy < H:
                hits.append((cy, cx))
    for c in n.get('children', []) or []: walk(c)
walk(d)
if not hits:
    print('NOT_FOUND'); raise SystemExit
hits.sort()
print('%d %d' % (hits[0][1], hits[0][0]))
PY
)
case "${XY}" in
  [0-9]*" "[0-9]*) ;;
  *) echo "FAIL:tab_not_found(${TAB} → ${XY})"; exit 4 ;;
esac
echo "  页签「${TAB}」在 (${XY}) ⇒ 点击"
sh_retry "uitest uiInput click ${XY}" >/dev/null
sleep 3

# ═══ ⑥ 抓图 + 验亮度 ═══
snap "/tmp/_cs_final.png" || { echo "FAIL:final_snapshot"; exit 5; }
FL=$(lum /tmp/_cs_final.png)
python3 -c "import sys; sys.exit(0 if float('${FL}')>20 else 1)" 2>/dev/null \
  || { echo "FAIL:final_black(lum=${FL})"; exit 5; }

cp /tmp/_cs_final.png "${DST}"
echo "OK ${DST}  ${PW}x${PH}  lum=${FL}"
exit 0
