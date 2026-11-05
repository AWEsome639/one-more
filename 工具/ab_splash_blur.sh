#!/usr/bin/env bash
# ============================================================================
#  工具/ab_splash_blur.sh —— **开屏 blur A/B**（判据 1490 修复版 + 1501）
#
#  ★ 为什么要有（第 1405 轮）
#    上一轮 A/B 失败的真因（判据 1490）：
#      我的重试循环**只查 `pidof`，没有重新 `aa start`**
#      ⇒ 第一次失败后永远不会成功
#    ⇒ 本脚本把 START_APP 抽成一个**显式重试 5 次**的函数
#
#  ★ 做什么
#    ① 备份 Splash.ets
#    ② 插入 `AB_PROBE`：星尘 blur → 0（24 个离屏消失）
#    ③ 编译 + 装 + 冷启 ×2 ⇒ 取帧直方图
#    ④ **恢复** Splash.ets（`cp` 备份）→ 编译 + 装 + 冷启 ×2 ⇒ 取帧直方图
#    ⑤ 对比两组 fps
#    ⚠️ **无论成败都会恢复**（trap EXIT）—— 判据 1491
#
#  ★ 用法：bash 工具/ab_splash_blur.sh <设备名>
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
DEV="${1:?用法: ab_splash_blur.sh <设备名>}"
SPL="entry/src/main/ets/pages/Splash.ets"
BAK="/tmp/ab_splash_backup_$$.ets"
OUT="验收截图-v1.0.1/ab_blur_${DEV}_$(date +%Y%m%d_%H%M)"
mkdir -p "$OUT"

# ★★★ 判据 1491：**无论成败都必须恢复**
cleanup() {
  if [ -s "$BAK" ]; then
    cp "$BAK" "$SPL"
    echo ""
    echo "  ⚠️ [trap] 已恢复 ${SPL}（探针数: "$(grep -c 'AB_PROBE' "$SPL" 2>/dev/null || true)"）"
  fi
}
trap cleanup EXIT INT TERM

ONLINE() { timeout 10 "$HC" -t 127.0.0.1:5555 shell 'echo ok' 2>/dev/null | grep -qx 'ok'; }
A() { ONLINE || return 1; timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }

# ★★★ 判据 1490：**每次重试都重发 `aa start`**
START_APP() {
  local TRY out pv t
  for TRY in 1 2 3 4 5; do
    A 'aa force-stop com.andrewoscar.onemore' >/dev/null 2>&1
    A 'power-shell wakeup' >/dev/null 2>&1
    sleep 3
    out="$(A 'aa start -b com.andrewoscar.onemore -a EntryAbility' 2>&1 | head -1)"
    pv=""
    for t in 4 5 7 9; do
      sleep "$t"
      pv="$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}')"
      printf '%s' "$pv" | grep -qE '^[0-9]+$' && break
    done
    if printf '%s' "$pv" | grep -qE '^[0-9]+$'; then
      echo "      pid [${pv}] ✅（第 ${TRY} 次）" >&2
      return 0
    fi
    echo "      第 ${TRY} 次失败：$(printf '%s' "$out" | cut -c1-40)" >&2
  done
  return 1
}

MEASURE() {   # $1 = 标签
  local TAG="$1" R
  for R in 1 2; do
    A 'hilog -r' >/dev/null 2>&1
    sleep 2
    START_APP || return 1
    sleep 8
    A 'hilog -x 2>/dev/null | grep -a "SplashDiag" | grep -a "frames"' > "${OUT}/${TAG}_r${R}.raw" 2>&1
    python3 - "${OUT}/${TAG}_r${R}.raw" "${OUT}/${TAG}_r${R}.txt" <<'PY' 2>/dev/null
import sys, re
seen = set()
out = []
for l in open(sys.argv[1], encoding='utf-8', errors='replace'):
    m = re.search(r'frames\s+fast=\d+.*', l)
    if m and m.group(0) not in seen:
        seen.add(m.group(0)); out.append(m.group(0))
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
    echo "      ${TAG} r${R}: $(head -1 "${OUT}/${TAG}_r${R}.txt" 2>/dev/null | cut -c1-70)"
  done
}

echo "════════ 开屏 blur A/B · $DEV ════════"
cp "$SPL" "$BAK"
echo "  备份: ${BAK}（$(wc -c < "$BAK" | tr -d ' ') 字节）"

# ── 起机 ──
for X in onemore onemore2 onemore3 onemore4 onemore5 onemore6; do timeout 20 "$EMU" -stop "$X" >/dev/null 2>&1; done
sleep 20
printf 'y\ny\ny\ny\ny\ny\n' > /tmp/yes_ab.txt
nohup bash -c "\"$EMU\" -start \"$DEV\" < /tmp/yes_ab.txt" > /tmp/ab_boot.log 2>&1 &
for i in $(seq 1 60); do sleep 10; ONLINE && { echo "  在线 @ $((i*10))s"; break; }; done
timeout 6 "$HC" tconn 127.0.0.1:5555 >/dev/null 2>&1
for k in $(seq 1 12); do
  sleep 10
  rm -f /tmp/ab.png
  A "snapshot_display -w 200 -h 200 -t png -f /data/local/tmp/_ab.png" >/dev/null 2>&1
  timeout 12 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_ab.png /tmp/ab.png >/dev/null 2>&1
  L=$(python3 -c "
from PIL import Image
import numpy as np, os
p='/tmp/ab.png'
print('%.0f' % np.array(Image.open(p).convert('RGB')).mean() if (os.path.exists(p) and os.path.getsize(p)>800) else '-1')
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${L:--1}')>20 else 1)" 2>/dev/null && { echo "  亮度 ${L}"; break; }
  A 'power-shell wakeup' >/dev/null 2>&1
done

echo
echo "  ── 【A 组】原版（有 blur）──"
timeout 2400 bash build.sh assembleHap > /tmp/ab_buildA.log 2>&1
echo "      编译: $(grep -cE 'BUILD SUCCESSFUL' /tmp/ab_buildA.log) 成功"
timeout 1200 "$HC" -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-signed.hap > /dev/null 2>&1
MEASURE "A_orig"

echo
echo "  ── 【B 组】探针：星尘 blur → 0 ──"
python3 - "$SPL" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
a = '.blur(this.starBlur(i))'
if a in s:
    s = s.replace(a, '.blur(0) /* AB_PROBE */', 1)
    io.open(p, 'w', encoding='utf-8').write(s)
    print('      ✅ 已插入 AB_PROBE（星尘 blur → 0）')
else:
    print('      🔴 找不到 starBlur 调用点')
PY
timeout 2400 bash build.sh assembleHap > /tmp/ab_buildB.log 2>&1
echo "      编译: $(grep -cE 'BUILD SUCCESSFUL' /tmp/ab_buildB.log) 成功"
cp "$BAK" "$SPL"    # 立刻恢复源码（编译已过）
echo "      源码已恢复（探针 $(grep -c 'AB_PROBE' "$SPL" 2>/dev/null || true) 处）"
timeout 1200 "$HC" -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-signed.hap > /dev/null 2>&1
MEASURE "B_noblur"

echo
echo "  ── 恢复正式版 ──"
timeout 2400 bash build.sh assembleHap > /tmp/ab_buildC.log 2>&1
timeout 1200 "$HC" -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-signed.hap > /dev/null 2>&1
echo "      恢复版已装"

echo
echo "  ══ 结果对比 ══"
python3 - "$OUT" <<'PY'
import sys, glob, os, re
out = sys.argv[1]
def fps_of(path):
    try:
        t = open(path, encoding='utf-8').read()
    except Exception:
        return None
    m = re.search(r'fast=(\d+)\s+mid=(\d+)\s+slow=(\d+)\s+vslow=(\d+)\s+drop=(\d+)', t)
    if not m: return None
    v = [int(x) for x in m.groups()]
    tot = sum(v)
    return (tot, 2245.0/tot, 1000.0/(2245.0/tot), (v[1]+v[2]+v[3]+v[4])/tot*100)
print('  组      轮  总帧  平均ms    fps    >20ms%')
res = {}
for tag in ('A_orig', 'B_noblur'):
    for f in sorted(glob.glob(os.path.join(out, tag + '_r*.txt'))):
        r = fps_of(f)
        if r:
            print('  %-7s %s  %4d  %6.1f  %5.1f  %6.1f%%'
                  % (tag, f.split('_r')[-1].split('.')[0], r[0], r[1], r[2], r[3]))
            res.setdefault(tag, []).append(r[2])
print()
for tag, arr in res.items():
    if arr:
        print('  %-9s fps 平均 **%.1f**（%s）' % (tag, sum(arr)/len(arr), ['%.0f' % x for x in arr]))
if 'A_orig' in res and 'B_noblur' in res and res['A_orig'] and res['B_noblur']:
    a = sum(res['A_orig'])/len(res['A_orig'])
    b = sum(res['B_noblur'])/len(res['B_noblur'])
    d = b - a
    print()
    print('  ══ 判定 ══')
    if d >= 3:
        print('  ✅ **blur 是主因** ⇒ 去掉 24 个离屏后 +%.1f fps' % d)
    elif d <= -3:
        print('  ⚠️ **反而变慢 %.1f fps** ⇒ 说明测量噪声 > 效应，或 bob 理论错' % (-d))
    else:
        print('  🔴 **blur 不是主因**（变化 %.1f fps，阈值 ±3）' % d)
        print('     ⇒ 瓶颈在别处（模拟器上限 / 15 个 @State / 其他）')
PY
timeout 30 "$EMU" -stop "$DEV" >/dev/null 2>&1
echo "  已 stop ｜ 产物: $OUT"
