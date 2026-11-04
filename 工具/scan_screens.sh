#!/usr/bin/env bash
# scan_screens.sh —— 在**当前设备**上依次打开各页签，用 check_text_squeeze 检查挤压
#
# ★ 为什么要有这个（第 1260 轮）
#   第 1259 轮做出了 `check_text_squeeze.py`（判据 680 工具化），
#   但只手工跑了 233 一台。要覆盖六尺寸，必须自动化：
#   「切设备 → 逐个页签 dump → 跑挤压检查 → 落盘证据」一条命令。
#
# 用法：bash 工具/scan_screens.sh <期望分辨率如 585x585> [标签前缀]
# 退出码：0 = 全部无挤压 ｜ 1 = 有挤压 ｜ 2 = 设备不可用
set -u
EXPECT="${1:-}"
TAG="${2:-scan}"

HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV="127.0.0.1:5555"
T="${HC} -t ${DEV}"

A() { timeout 30 ${T} shell "$@" 2>&1 | tr -d '\r'; }

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

recv_fresh() {
  local remote="$1" local_f="$2" i sz
  for i in 1 2 3; do
    rm -f "${local_f}"
    timeout 12 ${HC} tconn "${DEV}" >/dev/null 2>&1
    timeout 25 ${T} file recv "${remote}" "${local_f}" >/dev/null 2>&1
    [ -f "${local_f}" ] && { sz=$(stat -f%z "${local_f}" 2>/dev/null || echo 0); [ "${sz}" -gt 0 ] && return 0; }
    sleep 1
  done
  return 1
}

# ① 设备身份
sh_retry "echo PING" >/dev/null || { echo "FAIL:no_device"; exit 2; }
sh_retry "snapshot_display -t png -f /data/local/tmp/_scan.png" >/dev/null
recv_fresh /data/local/tmp/_scan.png /tmp/_scan.png || { echo "FAIL:probe"; exit 2; }
read -r PW PH <<<"$(python3 -c "
from PIL import Image
im=Image.open('/tmp/_scan.png'); print(im.width, im.height)" 2>/dev/null || echo '0 0')"
echo "  设备分辨率: ${PW}x${PH}"
if [ -n "${EXPECT}" ] && [ "${PW}x${PH}" != "${EXPECT}" ]; then
  echo "FAIL:wrong_device(got ${PW}x${PH}, expect ${EXPECT})"; exit 2
fi

# ② 唤醒（判据 637/672：多手段连打 + 零间隔截图）
CX=$((PW/2)); CY=$((PH/2)); UP1=$((PH*88/100)); UP2=$((PH*12/100))
OKL=0
for i in 1 2 3 4 5 6; do
  sh_retry "power-shell wakeup" >/dev/null
  sh_retry "uitest uiInput swipe ${CX} ${UP1} ${CX} ${UP2} 300" >/dev/null
  sh_retry "uitest uiInput keyEvent 2047" >/dev/null
  sh_retry "power-shell wakeup" >/dev/null
  sh_retry "uitest uiInput swipe ${CX} ${UP1} ${CX} ${UP2} 300" >/dev/null
  rm -f /tmp/_scan_w.png
  sh_retry "snapshot_display -t png -f /data/local/tmp/_scanw.png" >/dev/null
  recv_fresh /data/local/tmp/_scanw.png /tmp/_scan_w.png
  L=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/_scan_w.png'
print('%.1f' % float(np.array(Image.open(p).convert('RGB')).mean()) if os.path.exists(p) and os.path.getsize(p)>2000 else 0)
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${L}')>20 else 1)" 2>/dev/null && { OKL=1; break; }
done
[ "${OKL}" = "0" ] && { echo "FAIL:screen_black"; exit 2; }

# ③ App 在前台（判据 639/642/670/678：否定 + 正面下限 + 锁屏排除）
LAUNCHER_RE='图库|文件管理|日历|相机|应用市场|备忘录'
LOCK_RE='星期三|无服务|廿'
FG=0
for i in 1 2 3 4 5; do
  rm -f /tmp/_scan_d.json
  sh_retry "uitest dumpLayout -p /data/local/tmp/_scand.json" >/dev/null
  recv_fresh /data/local/tmp/_scand.json /tmp/_scan_d.json || { sleep 1; continue; }
  N=$(python3 -c "
import json
try: d=json.load(open('/tmp/_scan_d.json',encoding='utf-8'))
except Exception: print(0); raise SystemExit
n=0
def f(x):
    global n
    if not isinstance(x,dict): return
    if (x.get('attributes',{}).get('text') or '').strip(): n+=1
    for c in x.get('children',[]) or []: f(c)
f(d); print(n)
" 2>/dev/null || echo 0)
  NOTL=1; grep -qE "${LAUNCHER_RE}" /tmp/_scan_d.json 2>/dev/null && NOTL=0
  NOTLOCK=1; grep -qE "${LOCK_RE}" /tmp/_scan_d.json 2>/dev/null && NOTLOCK=0
  echo "  前台检查 ${i}: 节点=${N} 非桌面=${NOTL} 非锁屏=${NOTLOCK}"
  if [ "${N:-0}" -ge 8 ] && [ "${NOTL}" = "1" ] && [ "${NOTLOCK}" = "1" ]; then FG=1; break; fi
  # 锁屏 ⇒ 上滑解锁；否则拉起 App
  if [ "${NOTLOCK}" = "0" ]; then
    sh_retry "uitest uiInput swipe ${CX} $((PH*85/100)) ${CX} $((PH*15/100)) 400" >/dev/null
  else
    sh_retry "aa start -b com.andrewoscar.onemore -a EntryAbility" >/dev/null
  fi
  sleep 6
done
[ "${FG}" = "0" ] && { echo "FAIL:not_foreground"; exit 2; }

# ④ 关弹窗
for i in 1 2 3; do
  B=$(python3 工具/ui_get_xy.py /tmp/_scan_d.json "" --text 开始玩 2>/dev/null) \
    || B=$(python3 工具/ui_get_xy.py /tmp/_scan_d.json "" --text 同意 2>/dev/null) || B=""
  case "${B}" in
    [0-9]*" "[0-9]*) sh_retry "uitest uiInput click ${B}" >/dev/null; sleep 3
      rm -f /tmp/_scan_d.json
      sh_retry "uitest dumpLayout -p /data/local/tmp/_scand.json" >/dev/null
      recv_fresh /data/local/tmp/_scand.json /tmp/_scan_d.json ;;
    *) break ;;
  esac
done

# ⑤ 逐个页签 dump + 挤压检查
# ★★★ 判据 697（第 1262 轮）：**「跳过」不能算「通过」**
#   踩坑：853×533 上「游戏」页签未找到 ⇒ 脚本仍报 `OK: 全部页签 0 挤压`
#     ⇒ 与判据 651（"有列表却报全部通过"）**一模一样的病**
#   修：单独统计 SKIP，且 SKIP > 0 ⇒ 退出码 2（未验 ≠ 通过）
BAD=0
SKIP=0
for TAB in 游戏 统计 设置; do
  rm -f /tmp/_scan_d.json
  sh_retry "uitest dumpLayout -p /data/local/tmp/_scand.json" >/dev/null
  recv_fresh /data/local/tmp/_scand.json /tmp/_scan_d.json || { echo "  ⚠️ ${TAB}: dump 失败"; continue; }
  XY=$(python3 - "${PW}" "${PH}" "${TAB}" <<'PY' 2>/dev/null
import json, re, sys
W, H, want = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
try: d = json.load(open('/tmp/_scan_d.json', encoding='utf-8'))
except Exception: print('NO'); raise SystemExit
hits = []
def walk(n):
    if not isinstance(n, dict): return
    a = n.get('attributes', {})
    if want in (a.get('text') or ''):
        m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds') or '')
        if m:
            b = [int(v) for v in m[0]]
            cx, cy = (b[0]+b[2])//2, (b[1]+b[3])//2
            if 0 <= cx < W and 0 <= cy < H: hits.append((cy, cx))
    for c in n.get('children', []) or []: walk(c)
walk(d)
# ★ 判据 700（第 1263 轮）：**页签取「最靠下」的那个**，不是最靠上的
#   踩坑：800×1280 平板上按 y 升序取第一个「统计」
#     ⇒ 点到页面别处的同名文字 ⇒ **三个页签 dump 完全相同（md5 一致）**
#     ⇒ 脚本仍报「检查 3/3 ｜ 0 挤压」= 假通过
#   理由：本项目的页签栏固定在**底部**，所以同名文字中「y 最大」的才是页签
hits.sort()
print('%d %d' % (hits[-1][1], hits[-1][0]) if hits else 'NO')
PY
)
  case "${XY}" in
    [0-9]*" "[0-9]*) sh_retry "uitest uiInput click ${XY}" >/dev/null; sleep 3 ;;
    *) echo "  ⚠️ ${TAB}: 页签未找到（**未检查**）"; SKIP=$((SKIP+1)); continue ;;
  esac
  rm -f /tmp/dump_${TAG}_${TAB}.json
  sh_retry "uitest dumpLayout -p /data/local/tmp/_scanx.json" >/dev/null
  recv_fresh /data/local/tmp/_scanx.json "/tmp/dump_${TAG}_${TAB}.json" || { echo "  ⚠️ ${TAB}: dump 失败（未检查）"; SKIP=$((SKIP+1)); continue; }
  OUT=$(python3 工具/check_text_squeeze.py "/tmp/dump_${TAG}_${TAB}.json" 2>&1)
  S=$(printf '%s' "${OUT}" | grep -oE '挤压 [0-9]+' | head -1 | grep -oE '[0-9]+')
  echo "  ${TAB}: 挤压 ${S:-?}"
  [ "${S:-0}" != "0" ] && { BAD=$((BAD+1)); printf '%s\n' "${OUT}" | grep '「' | head -3 | sed 's/^/      /'; }
  # 顺手存一张该页截图作证据
  rm -f "/tmp/shot_${TAG}_${TAB}.png"
  sh_retry "snapshot_display -t png -f /data/local/tmp/_scans.png" >/dev/null
  recv_fresh /data/local/tmp/_scans.png "/tmp/shot_${TAG}_${TAB}.png" >/dev/null 2>&1 || true
done

echo
CHECKED=$((3 - SKIP))
echo "  检查 ${CHECKED}/3 ｜ 跳过 ${SKIP} ｜ 有挤压 ${BAD}"
if [ "${SKIP}" != "0" ]; then
  echo "FAIL: ${SKIP} 个页签**未检查**（未验 ≠ 通过，判据 697/634）⇒ 退出码 2"
  exit 2
fi
if [ "${BAD}" = "0" ]; then echo "OK: 全部 3 个页签 0 挤压（${TAG}）"; exit 0; fi
echo "FAIL: ${BAD} 个页签有挤压（${TAG}）"; exit 1
