#!/bin/bash
# 在「isShort == false」那条路上跑一次（判据 2807 / 2812 / 2814）。
#
# ✅ 现在用**折叠屏实例**（foldable 镜像已下载，不用下平板镜像）：
#     onemore_fold = Mate X5, 2224x2496 @500dpi ≈ 711x798vp ⇒ Bp.height ≈ 798 > 690 ⇒ isShort() == false
# ❌ 「hdc shell wm size」在鸿蒙上不存在（实测 /bin/sh: wm: inaccessible）——这条路已废。
#
# ⚠️ 收尾只用 `Emulator -stop <name>`，**绝不 pkill**（判据 2814：强杀会触发 QEMU 断言崩溃）。
#
# 用法:
#   bash 工具/test_nonshort.sh              # 启动 + 装包 + 验首页渲染 + 截图 + 优雅停止
#   bash 工具/test_nonshort.sh "Mental Mapping" ...   # 额外逐款测（需先解决导航坐标问题）

set -u
cd "$(dirname "$0")/.." || exit 1
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
INST='onemore_fold'
SCREEN='2224x2496'
# ★ 2026-11-16（判据 2824）：**溢出阈值必须跟屏幕走**。
#   工具默认 GAME_BOTTOM=1516/SLACK=60（=1576）是手机口径；折叠屏屏高 2496 ⇒
#   若不传，1600–2496 之间的正常节点全被算成溢出（实测三款都报 blk=10~±5000-7000px，手工 dump 却是 0）。
export SHOT_SCREEN_H=2496
export SHOT_GAME_BOTTOM=2412   # 2496 - 84（手机上 1600-84=1516）
export SHOT_PX_PER_VP=3.125    # 500dpi / 160（手机 480/160=3）

echo "════ isShort==false 测试 $(date '+%H:%M') ════"

cleanup() {
  echo "→ 优雅停止 $INST"
  "$EMU" -stop "$INST" >/dev/null 2>&1
  sleep 4
  # ★ 自排除：`pgrep -f "…"` 的子 shell 命令行里也带这个字符串
  # ★ 判据 2818：**按进程名统计不可靠**（子 shell 自身也含该串；
  #   而折叠屏那种实例又不叫 qemu-system）⇒ 改用**设备连接状态**做结论。
  echo "→ 设备状态: $("$HC" list targets 2>/dev/null | head -1 | cut -c1-40)"
}
trap cleanup EXIT INT TERM

# 一次只开一台（判据 2814：上次两台并存就是崩溃的起点）
if pgrep -f "Emulator -start" >/dev/null 2>&1; then
  echo "⚠️ 已有模拟器在跑，先优雅停掉："
  pgrep -fl "Emulator -start" | sed 's/^/     /'
  for n in $(pgrep -fl "Emulator -start" | sed -n 's/.*-start \([A-Za-z0-9_]*\).*/\1/p' | sort -u); do
    echo "   stop $n"; "$EMU" -stop "$n" >/dev/null 2>&1
  done
  sleep 5
fi

echo y > /tmp/yes.txt
echo "→ 启动 ${INST} (${SCREEN})"
(nohup "$EMU" -start "$INST" < /tmp/yes.txt > /tmp/test_nonshort.log 2>&1 &)
for i in $(seq 1 40); do
  n=$("$HC" list targets 2>/dev/null | grep -cE '^[0-9A-Za-z]')
  [ "$n" -ge 1 ] && { echo "   设备就绪 $((i*10))s"; break; }
  sleep 10
done
sleep 22

echo "→ 屏幕信息"
"$HC" shell "hidumper -s RenderService -a screen" 2>/dev/null | grep -oE "render resolution=[0-9]+x[0-9]+" | head -1 | sed 's/^/   /'

echo "→ 装包"
timeout 300 "$HC" install -r entry/build/default/outputs/default/entry-default-signed.hap 2>&1 | tail -1 | sed 's/^/   /'

echo "→ 启动 App（尝试最多 3 次，每次验证）"
for _try in 1 2 3; do
  "$HC" shell "aa start -a EntryAbility -b com.andrewoscar.onemore" >/dev/null 2>&1
  sleep 9
  "$HC" shell "uitest dumpLayout -p /data/local/tmp/ns0.json" >/dev/null 2>&1
  if "$HC" shell "cat /data/local/tmp/ns0.json" 2>/dev/null | grep -q "355 款小游戏"; then
    echo "   第 $_try 次启动成功"
    break
  fi
  echo "   第 $_try 次没起来，重试"
done

# ⚠️ 新实例第一次有「隐私说明」弹窗（判据 2812）：不点掉会吃掉所有点击
echo "→ 检查隐私弹窗"
"$HC" shell "uitest dumpLayout -p /data/local/tmp/ns.json" >/dev/null 2>&1
"$HC" shell "cat /data/local/tmp/ns.json" 2>/dev/null | python3 -c "
import sys, json, re
try: d = json.loads(sys.stdin.read())
except Exception: raise SystemExit
hit = []
def walk(n):
    if not isinstance(n, dict): return
    a = n.get('attributes', {}) or {}
    if (a.get('text') or '').strip() == '同意并继续':
        m = re.findall(r'-?\d+', (a.get('bounds') or ''))
        if len(m) == 4:
            hit.append(((int(m[0])+int(m[2]))//2, (int(m[1])+int(m[3]))//2))
    for c in (n.get('children') or []): walk(c)
walk(d)
print('%d %d' % hit[0] if hit else '')
" > /tmp/ns_xy.txt 2>/dev/null
read -r PX PY < /tmp/ns_xy.txt 2>/dev/null || true
if [ -n "${PX:-}" ]; then
  echo "   发现隐私弹窗，点 ($PX,$PY)"
  "$HC" shell "uitest uiInput click $PX $PY" >/dev/null 2>&1
  sleep 3
else
  echo "   没有隐私弹窗"
fi

echo "→ 首页渲染检查"
"$HC" shell "uitest dumpLayout -p /data/local/tmp/ns2.json" >/dev/null 2>&1
"$HC" shell "cat /data/local/tmp/ns2.json" 2>/dev/null | python3 -c "
import sys, json
try: d = json.loads(sys.stdin.read())
except Exception:
    print('   ❌ dump 解析失败'); raise SystemExit
out, ys = [], []
def walk(n):
    if not isinstance(n, dict): return
    a = n.get('attributes', {}) or {}
    t = (a.get('text') or '').strip()
    if t: out.append(t)
    import re as _r
    m = _r.findall(r'-?\d+', (a.get('bounds') or ''))
    if len(m) == 4: ys.append(int(m[3]))
    for c in (n.get('children') or []): walk(c)
walk(d)
ok = any('355' in t or 'One More' in t for t in out)
print('   文本 %d 个、最大下边界 y2=%d' % (len(out), max(ys) if ys else 0))
print('   %s' % ('✅ App 首页已渲染' if ok else '❌ 没看到首页文本'))
print('   前 6: %s' % (out[:6],))
"

echo "→ 截图"
"$HC" shell "snapshot_display -f /data/local/tmp/ns.jpeg" >/dev/null 2>&1
"$HC" file recv /data/local/tmp/ns.jpeg "_巡检记录/截图-折叠屏-$(date +%H%M).jpeg" >/dev/null 2>&1
ls -1 _巡检记录/截图-折叠屏-*.jpeg 2>/dev/null | tail -1 | sed 's/^/   /'

if [ "$#" -gt 0 ]; then
  echo
  echo "── 逐款测量（⚠️ 导航坐标问题未解决，可能 NO_CARD）──"
  for g in "$@"; do
    ONEMORE_SCREEN="$SCREEN" timeout 260 python3 工具/shot_game.py "$g" 2>&1 | tail -1 | cut -c1-118
    sleep 4
  done
else
  echo
  echo "（未指定款 ⇒ 只验「大屏上 App 能否正常渲染」。逐款测量等导航改造。）"
fi

echo "════ 完 ════"
