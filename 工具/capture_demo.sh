#!/usr/bin/env bash
# capture_demo.sh —— 拍某款游戏的「演示动画」逐帧推进（含 5 个断言）
#
# ★ 这个脚本把 7 条判据固化在一起（每条都在实测中付过代价）：
#   602  AppStorage 是进程级 ⇒ 必须 aa force-stop 才有演示
#   604  采样间隔必须 ≤ 单步时长 1.2 倍 ⇒ **只拍截图**（~0.54s/帧），不 dump
#   607  采样窗口 = 延时×1.5+2s ⇒ 默认 8 秒（3000×1.5+2000≈6.5）
#   608  「画面变了」弱证据 ⇒ 脚本会另外 dump 一次取状态量
#   627  取值必须**白名单式**守卫（用 工具/ui_get_xy.py，检查退出码）
#   628  每个阶段边界都要断言「我在正确页面吗」
#
# 用法： bash 工具/capture_demo.sh "<游戏中文名>" <card-id> [帧数] [总秒数]
set -u
NAME="${1:?用法: capture_demo.sh <游戏中文名> <card-id> [帧数] [总秒数]}"
CID="${2:?需要 card-id}"
FRAMES="${3:-14}"
DURATION="${4:-9}"

HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
T="${HC} -t 127.0.0.1:5555"
OUT="/tmp/demo_${CID}"
XYTOOL="工具/ui_get_xy.py"

die() { echo "  🔴 $*"; exit 1; }

# ★ 判据 813（第 1311 轮）：**空 dump 会在下游伪装成「元素不存在」**
#   实证：`dump /tmp/_res.json` 之后取 card 坐标失败
#     ⇒ 原来的 die 写「搜索结果里没有 card-xxx」
#     ⇒ 但若 dump 本身是空的（设备刚亮屏/还没画完），真实原因是「**dump 抓空了**」
#     ⇒ 两条完全不同的修法，被一条消息混在一起
#   ⇒ 本函数：**先断言 dump 非空**，失败时直接报「dump 空」，并删掉空文件（判据 812）
DUMP_MIN_BYTES="${DUMP_MIN_BYTES:-500}"
dump_safe() {  # $1=本地路径 $2=阶段名
  local f="$1" stage="${2:-dump}"
  if [ ! -f "$f" ]; then
    echo "  🔴 [$stage] dump 文件不存在：$f"
    echo "     ⇒ 判据 813：这是「抓取失败」，不是「元素不存在」"
    exit 1
  fi
  local sz
  sz=$(stat -f%z "$f" 2>/dev/null || echo 0)
  if [ "${sz}" -lt "${DUMP_MIN_BYTES}" ]; then
    echo "  🔴 [$stage] **dump 是空的**（${sz} 字节 < ${DUMP_MIN_BYTES}）：$f"
    echo "     ⇒ 判据 813：这是「抓取失败/界面没画完」，不是「元素不存在」"
    echo "     ⇒ 判据 812：删除空文件，避免后续误用"
    rm -f "$f"
    exit 1
  fi
  echo "    dump ${stage}: ${sz} 字节 ✅"
}
A() { timeout 30 ${T} shell "$@" 2>&1 | tr -d '\r'; }
dump() { A "uitest dumpLayout -p /data/local/tmp/_d.json" >/dev/null 2>&1; sleep 1; timeout 25 ${T} file recv /data/local/tmp/_d.json "$1" >/dev/null 2>&1; }

# 断言：dump 里必须出现某段文字（判据 628）
assert_text() {  # $1=json $2=期望文字 $3=阶段名
  local got
  got=$(python3 - "$1" "$2" <<'PY'
import json,os,sys,re
p,want=sys.argv[1],sys.argv[2]
if not os.path.exists(p) or os.path.getsize(p)<500:
    print('ERR:dump'); raise SystemExit
try: d=json.load(open(p,encoding='utf-8'))
except Exception as e: print('ERR:json'); raise SystemExit
hit=[]
def f(n):
    if not isinstance(n,dict): return
    t=(n.get('attributes',{}).get('text') or '')
    if want in t: hit.append(t[:30])
    for c in n.get('children',[]) or []: f(c)
f(d)
print('OK:'+hit[0] if hit else 'NO')
PY
)
  case "${got}" in
    OK:*) echo "    ✅ [$3] 见到「$2」" ;;
    *)    die "[$3] 断言失败：期望出现「$2」，实际 ${got}" ;;
  esac
}

echo "══ ① force-stop（判据 602）══"
A "aa force-stop com.andrewoscar.onemore" >/dev/null 2>&1; sleep 3
for a in 1 2 3; do
  A "power-shell wakeup" >/dev/null 2>&1; sleep 3
  A "uitest uiInput swipe 660 1100 660 200 900" >/dev/null 2>&1; sleep 2
  A "aa start -b com.andrewoscar.onemore -a EntryAbility" >/dev/null 2>&1
  sleep 15
  P=$(A "pidof com.andrewoscar.onemore" | head -1 | tr -d ' \r')
  echo "${P}" | grep -qE '^[0-9]+$' && { echo "    ✅ 启动（PID=${P}）"; break; }
  [ "${a}" = "3" ] && die "启动失败"
done
sleep 2

echo "══ ② 断言在首页 + 关弹窗（判据 628）══"
for r in 1 2 3; do
  dump /tmp/_home.json
  # 循环内**不 die**（可能还没画完，允许重试）；但要把「空」与「没有按钮」分开报
  if [ -f /tmp/_home.json ] && [ "$(stat -f%z /tmp/_home.json 2>/dev/null || echo 0)" -lt "${DUMP_MIN_BYTES:-500}" ]; then
    echo "    ⚠️ [首页] dump 空（第 ${r} 次），重试（判据 813：不是「没有开始玩按钮」）"
    sleep 2; continue
  fi
  B=$(python3 ${XYTOOL} /tmp/_home.json "" --text 开始玩 2>/dev/null) || B=$(python3 ${XYTOOL} /tmp/_home.json "" --text 同意并继续 2>/dev/null) || B=""
  case "${B}" in
    [0-9]*" "[0-9]*) A "uitest uiInput click ${B}" >/dev/null 2>&1; sleep 4 ;;
    *) break ;;
  esac
done
dump /tmp/_home.json
assert_text /tmp/_home.json "款小游戏" "首页"

echo "══ ③ 搜索（判据 627：白名单守卫）══"
SR=$(python3 ${XYTOOL} /tmp/_home.json "" --text 🔍) || die "取不到搜索图标"
A "uitest uiInput click ${SR}" >/dev/null 2>&1; sleep 3
dump /tmp/_srch.json
IB=$(python3 ${XYTOOL} /tmp/_srch.json "" --text "" 2>/dev/null) || true
IB=$(python3 - /tmp/_srch.json <<'PY'
import json,os,re,sys
p=sys.argv[1]
if not os.path.exists(p) or os.path.getsize(p)<500: print('ERR'); raise SystemExit
d=json.load(open(p,encoding='utf-8')); out=[]
def f(n):
    if not isinstance(n,dict): return
    a=n.get('attributes',{})
    if 'Input' in (a.get('type') or ''):
        m=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds',''))
        if m:
            b=[int(v) for v in m[0]]; out.append(((b[0]+b[2])//2,(b[1]+b[3])//2))
    for c in n.get('children',[]) or []: f(c)
f(d); print('%d %d'%out[0] if out else 'MISS')
PY
)
case "${IB}" in [0-9]*" "[0-9]*) : ;; *) die "取不到搜索框（${IB}）" ;; esac
A "uitest uiInput inputText ${IB} ${NAME}" >/dev/null 2>&1; sleep 4
dump /tmp/_res.json
dump_safe /tmp/_res.json "搜索结果"
CARD=$(python3 ${XYTOOL} /tmp/_res.json "card-${CID}") || die "dump 非空但没找到 card-${CID}（判据 813：这次才是真的没有）"
echo "    ✅ 找到卡片：${CARD}"

echo "══ ④ 进游戏 + 断言（判据 628）══"
A "uitest uiInput click ${CARD}" >/dev/null 2>&1
sleep 1
dump /tmp/_ingame.json
assert_text /tmp/_ingame.json "${NAME}" "已进游戏"

echo "══ ⑤ 密集截图（判据 604/607：只拍截图，${FRAMES} 帧 / ~${DURATION}s）══"
rm -f ${OUT}_*.png
python3 - "${FRAMES}" "${DURATION}" "${OUT}" <<'PY'
import subprocess, sys, time
frames, dur, out = int(sys.argv[1]), float(sys.argv[2]), sys.argv[3]
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
gap = dur / frames
t0 = time.time()
for i in range(1, frames+1):
    target = t0 + (i-1)*gap
    while time.time() < target: time.sleep(0.02)
    subprocess.run([HC,'-t','127.0.0.1:5555','shell',
                    'snapshot_display -t png -f /data/local/tmp/_cap%d.png' % i],
                   capture_output=True, timeout=30)
    subprocess.run([HC,'-t','127.0.0.1:5555','file','recv',
                    '/data/local/tmp/_cap%d.png' % i, '%s_%02d.png' % (out, i)],
                   capture_output=True, timeout=30)
print('    ✅ 采完（实际 %.2fs）' % (time.time()-t0))
PY

echo "══ ⑥ 帧分析（判据 608：另外取状态量）══"
python3 - "${OUT}" "${FRAMES}" <<'PY'
import os, sys, hashlib
import numpy as np
from PIL import Image
out, n = sys.argv[1], int(sys.argv[2])
rows=[]; prev=None
for i in range(1, n+1):
    p='%s_%02d.png' % (out, i)
    if not os.path.exists(p) or os.path.getsize(p)<2000:
        rows.append((i,'—',None,None)); continue
    h=hashlib.sha256(open(p,'rb').read()).hexdigest()[:10]
    sm=np.array(Image.open(p).convert('RGB').resize((160,270)),dtype=np.int32)
    d=int(np.abs(sm-prev).sum()) if prev is not None else None
    rows.append((i,h,float(sm.mean()),d)); prev=sm
print('     帧   hash         亮度    与前帧差')
for i,h,lum,d in rows:
    print('     %-4d %-12s %-7s %s' % (i,h,'%.1f'%lum if lum else '—','—' if d is None else d))
hs=[r[1] for r in rows if r[1]!='—']
ds=[r[3] for r in rows if r[3] is not None]
print()
print('     唯一 hash: %d / %d ｜ 显著变化帧间: %d / %d'
      % (len(set(hs)), len(hs), sum(1 for d in ds if d>3000), len(ds)))
if len(set(hs)) > 1:
    print('     ⇒ ✅ 画面在变（演示/动效在跑）')
else:
    print('     ⇒ 🟡 全部相同（按判据 603 三步排查：文件新鲜度 / 内容状态 / 采样率）')
PY

echo "══ ⑦ 状态量（判据 608：强证据）══"
sleep 2
dump /tmp/_after.json
python3 - /tmp/_after.json <<'PY'
import json,os,sys
p=sys.argv[1]
if not os.path.exists(p) or os.path.getsize(p)<500:
    print('     （dump 失败）'); raise SystemExit
d=json.load(open(p,encoding='utf-8')); txt=[]
def f(n):
    if not isinstance(n,dict): return
    t=(n.get('attributes',{}).get('text') or '').strip()
    if t: txt.append(t[:30])
    for c in n.get('children',[]) or []: f(c)
f(d)
print('     全部文字：')
for t in txt: print('       %s' % t)
PY
