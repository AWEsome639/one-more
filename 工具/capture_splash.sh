#!/bin/bash
# 开屏真机取证（一条命令做对全部步骤）
#
# ★ 为什么要有这个（第 1146 轮）：
#   我连续几轮踩同样的坑：
#     ① 漏 `aa force-stop` ⇒ App 已在运行 ⇒ resume 到首页 ⇒ **没有开屏可拍**
#     ② 解锁只试一次 ⇒ 锁屏时 `aa start` 报 10106102 而我不知道
#     ③ 后台 job 被 `job_kill` ⇒ **hdc 连接断掉**
#   本脚本把"解锁→验证→force-stop→启动→连拍→分析"固化，避免再犯。
#
# 用法：bash 工具/capture_splash.sh [标签] [帧数]
#   标签：如 853 / 440 / 233（只用于输出文件名）
#   帧数：默认 20
#   延迟：启动后等几秒再拍（默认 2；
#         ★ 第 1146 轮实测：`aa start` 到真正显示开屏有 2~3s 启动延迟，
#           若不等就会拍到"启动白屏"和"动画结束后的空白"两头，正好错过中间）
set -u
TAG="${1:-x}"
N="${2:-20}"
DELAY="${3:-2}"   # ★ 启动后延迟（秒）—— 让采样窗罩住 2.27s 的动画
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
OUT="验收截图-v1.0.1"

# ★ 探针：设备必须在
timeout 10 ${HC} tconn 127.0.0.1:5555 >/dev/null 2>&1
if ! timeout 10 ${HC} list targets 2>&1 | grep -q "127.0.0.1:5555"; then
  echo "🔴 设备不可用（先确认模拟器已启动）"; exit 1
fi
echo "  设备 OK"

# ★ 按屏幕尺寸算解锁滑动坐标（★ 第 1147 轮：写死坐标在 2880×1620 上无效）
timeout 20 ${HC} -t 127.0.0.1:5555 shell "snapshot_display -t png -f /data/local/tmp/_sz.png" >/dev/null 2>&1
sleep 1
timeout 20 ${HC} -t 127.0.0.1:5555 file recv /data/local/tmp/_sz.png /tmp/_sz.png >/dev/null 2>&1
SZ=$(python3 -c "
import sys
try:
    from PIL import Image
    im = Image.open('/tmp/_sz.png')
    print('%d %d' % (im.width, im.height))
except Exception:
    print('1320 2232')
" 2>/dev/null)
SW=$(echo "${SZ}" | awk '{print $1}')
SH=$(echo "${SZ}" | awk '{print $2}')
SX=$((SW / 2))
SY1=$((SH * 88 / 100))
SY2=$((SH * 10 / 100))
echo "  屏幕 ${SW}×${SH} px ⇒ 滑动 (${SX},${SY1}) → (${SX},${SY2})"

# ★ 解锁：最多试 4 次，每次都验证屏幕内容
UNLOCKED=0
for k in 1 2 3 4; do
  timeout 20 ${HC} -t 127.0.0.1:5555 shell "power-shell wakeup" >/dev/null 2>&1
  sleep 3
  timeout 20 ${HC} -t 127.0.0.1:5555 shell "uitest uiInput swipe ${SX} ${SY1} ${SX} ${SY2} 1200" >/dev/null 2>&1
  sleep 4
  timeout 20 ${HC} -t 127.0.0.1:5555 shell "snapshot_display -t png -f /data/local/tmp/_lk.png" >/dev/null 2>&1
  sleep 1
  timeout 20 ${HC} -t 127.0.0.1:5555 file recv /data/local/tmp/_lk.png /tmp/_lk.png >/dev/null 2>&1
  R=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/_lk.png'
if not os.path.exists(p) or os.path.getsize(p)<800: print('NOFILE'); raise SystemExit
A=np.array(Image.open(p).convert('RGB'),dtype=np.int32)
blue=((A[:,:,2]-A[:,:,0]>40)&(A[:,:,2]>120)).mean()*100
white=(A.mean(axis=2)>235).mean()*100
print('DESKTOP' if blue>15 else ('APP' if white>25 else 'OTHER'))
" 2>/dev/null)
  echo "  解锁试 ${k}: ${R}"
  [ "${R}" = "DESKTOP" ] && { UNLOCKED=1; break; }
done
[ "${UNLOCKED}" = "1" ] || echo "  ⚠️ 未确认桌面，继续尝试启动"

# ★ 装包（失败就停）
INST=$(timeout 900 ${HC} -t 127.0.0.1:5555 install -r "${HAP}" 2>&1 | tr -d '\r' | grep -c "successfully")
[ "${INST}" = "0" ] && { echo "🔴 装包失败"; exit 1; }
echo "  装包 OK"


# ★★★ 2026-11-05（第 1361 轮，判据 1002/1003）：**先跑「按层就绪」再抓帧**
#
#   实证：`onemore3` 曾被 `bm clean -d` 清过数据
#     ⇒ 每次启动都要过**隐私卡 + 引导页**
#     ⇒ 若只做「解锁」不做「关弹窗」⇒ **弹窗盖住 ⇒ 点击全被吃掉**
#     ⇒ 而这已经是**第四次**同类失败（第 1350/1351/1352/1353 轮）
#
#   ⇒ 修法：把 `ensure_ready.sh` **内建**进本脚本
#     它负责：开屏 boost → 关隐私卡 → 关引导页 → 确认到桌面/首页
#     ⚠️ 若 ensure_ready 不可用（文件缺失），退化为「跳过」而不是报错
case "${TAG}" in
  853x533)  ER_INST=onemore  ;;
  800x1280) ER_INST=onemore2 ;;
  440x744)  ER_INST=onemore3 ;;
  233x233)  ER_INST=onemore4 ;;
  960x540)  ER_INST=onemore5 ;;
  195x195)  ER_INST=onemore6 ;;
  *)        ER_INST=""       ;;
esac
ER_SH="$(dirname "$0")/ensure_ready.sh"
if [ -n "$ER_INST" ] && [ -f "$ER_SH" ]; then
  echo "  ①' 按层就绪（ensure_ready.sh $ER_INST）—— 判据 1002/1003"
  bash "$ER_SH" "$ER_INST" 2>&1 | tail -3 | sed 's/^/     /' || true
fi

# ★ force-stop 并确认进程死透（★ 关键：这是之前反复漏的一步）
timeout 20 ${HC} -t 127.0.0.1:5555 shell "aa force-stop com.andrewoscar.onemore" >/dev/null 2>&1
DEAD=0
for i in $(seq 1 15); do
  P=$(timeout 10 ${HC} -t 127.0.0.1:5555 shell "pidof com.andrewoscar.onemore" 2>&1 | tr -d ' \r' | head -1)
  [ -z "${P}" ] && { DEAD=1; break; }
  sleep 1
done
[ "${DEAD}" = "1" ] && echo "  进程已死" || echo "  ⚠️ 进程仍在"
sleep 4

# ★ 启动（★ 关键三条：
#   ① 打印错误不重定向
#   ② **启动前重新 wakeup+解锁** —— 装包那 10 秒里屏幕会重新上锁
#      （第 1146 轮实测：解锁后直接装包+启动 ⇒ 报 10106102 locked）
#   ③ 失败则重试最多 3 次，每次前都重新解锁）
STARTED=0
for attempt in 1 2 3; do
  timeout 20 ${HC} -t 127.0.0.1:5555 shell "power-shell wakeup" >/dev/null 2>&1
  sleep 2
  timeout 20 ${HC} -t 127.0.0.1:5555 shell "uitest uiInput swipe ${SX} ${SY1} ${SX} ${SY2} 1200" >/dev/null 2>&1
  sleep 3
  ST=$(timeout 30 ${HC} -t 127.0.0.1:5555 shell "aa start -b com.andrewoscar.onemore -a EntryAbility" 2>&1 | tr -d '\r' | head -2)
  echo "  aa start（第 ${attempt} 次）: ${ST}"
  if echo "${ST}" | grep -q "successfully"; then STARTED=1; break; fi
  [ "${attempt}" -lt 3 ] && sleep 3
done
[ "${STARTED}" = "1" ] || { echo "🔴 启动失败（3 次都锁屏）"; exit 1; }

# ★ 延迟后再连拍（★ 关键：不给延迟就会错过动画）
echo "  等 ${DELAY}s 再拍"
sleep "${DELAY}"
for i in $(seq -w 1 "${N}"); do
  (
    timeout 20 ${HC} -t 127.0.0.1:5555 shell "snapshot_display -t png -f /data/local/tmp/_c${i}.png" >/dev/null 2>&1
    timeout 20 ${HC} -t 127.0.0.1:5555 file recv /data/local/tmp/_c${i}.png "/tmp/_c${TAG}_${i}.png" >/dev/null 2>&1
  ) &
  sleep 0.35
done
wait
echo "  连拍完成"

# ★ 分析
python3 - "${TAG}" <<'PY'
import sys, glob, os, shutil
import numpy as np
from PIL import Image
tag = sys.argv[1]
files = sorted(glob.glob('/tmp/_c%s_*.png' % tag))
best = None; states = {}
for p in files:
    if os.path.getsize(p) < 800: continue
    A = np.array(Image.open(p).convert('RGB'), dtype=np.int32)
    ink = ((A[:,:,0] < 60) & (A[:,:,1] < 60) & (A[:,:,2] < 80)).mean() * 100
    gold = ((A[:,:,0] > 140) & (A[:,:,1] > 100) & (A[:,:,2] < 130) & (A[:,:,0]-A[:,:,2] > 50)).mean() * 100
    cream = ((A[:,:,0] > 200) & (A[:,:,1] > 195) & (A[:,:,2] > 180)).mean() * 100
    if ink > 40:
        states.setdefault((round(ink,1), round(gold,2), round(cream,2)), []).append(os.path.basename(p))
        if gold > 0.1 and cream > 1.0 and (best is None or gold+cream > best[1]):
            best = (p, gold+cream)
print('  帧 %d ｜ 开屏帧 %d ｜ **去重 %d 个状态**' % (len(files), sum(len(v) for v in states.values()), len(states)))
if best:
    dst = '/tmp/splash_%s_final.png' % tag
    shutil.copy(best[0], dst)
    A = np.array(Image.open(best[0]).convert('RGB'), dtype=np.int32)
    print('  ⇒ 峰值 %s（%.0fx%.0f）→ %s' % (os.path.basename(best[0]), A.shape[1], A.shape[0], dst))
else:
    print('  ⚠️ 无同时有 logo 与文字的帧')
PY
