#!/bin/bash
# 「一局」手感优化 —— 一键续跑（奥森 2026-10-12 20:42 叫停后，凌晨 1 点继续）
#
# 用法：  bash ~/dev/yiju/tools/续跑-手感验收.sh
#
# 做完三件事：
#   ① 建「热区修正版」（上次构建被叫停）
#   ② 用好的镜像 yiju2 起模拟器（yiju 那个坏了：dumpLayout 出 0 字节）
#   ③ 上机复量难度胶囊热区 + 抓弹簧动画抽帧
#
# ⚠️ 机器很卡就停下 —— 奥森今天已经因为卡叫停过一次

set -u
HDC="$HOME/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc"
YJ="$HOME/dev/yiju"
SHOT="$HOME/Desktop/学业规划/鸿蒙小游戏合集 20261010/验收截图/动效抽帧 20261012"
mkdir -p "$SHOT"

say() { printf '\n\033[1m══ %s ══\033[0m\n' "$1"; }

say "0. 先看机器还卡不卡"
echo "  load $(uptime | grep -oE 'load averages: [0-9.]+' | cut -d' ' -f3)"
echo "  空闲 $(memory_pressure 2>/dev/null | grep -oE '[0-9]+%' | head -1)"
echo "  swap $(sysctl -n vm.swapusage 2>/dev/null | grep -oE 'used = [0-9.]+M')"
echo "  ⚠️ swap 仍 >6G 就先跟奥森说一声「建议重启」"

say "1. 构建（热区修正版）"
cd "$YJ" || exit 1
grep -n "Layout.touchMin" entry/src/main/ets/pages/GameHost.ets | head -2
bash build.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "BUILD|Error Message" | head -4
ls -la entry/build/default/outputs/default/*.hap | awk '{printf "  HAP %.1f MB  %s %s\n",$5/1048576,$7,$8}'

say "2. 起模拟器（用 yiju2）"
pkill -9 -f Emulator 2>/dev/null; sleep 5
cd /tmp && nohup "$HOME/Library/Huawei/command-line-tools/emulator/Emulator" -start yiju2 \
  > /tmp/emu_resume.log 2>&1 < /dev/null & disown
for i in $(seq 1 16); do
  sleep 35
  T=$(timeout 12 "$HDC" list targets 2>/dev/null | tr '\n' ' ')
  case "$T" in *555*) echo "  ✅ 上线: $T（$((i*35)) 秒）"; break;; esac
  printf '  %d) %s\n' "$i" "${T:-（空）}"
done

say "3. 装包"
"$HDC" install -r "$YJ/entry/build/default/outputs/default/entry-default-unsigned.hap" 2>&1 | tail -1
"$HDC" shell aa start -a EntryAbility -b com.andrewoscar.onemore >/dev/null 2>&1; sleep 12
"$HDC" shell aa start -a EntryAbility -b com.andrewoscar.onemore >/dev/null 2>&1; sleep 9

say "4. 进第一款游戏"
"$HDC" shell "uitest uiInput click 346 1500" >/dev/null 2>&1; sleep 8

say "5. ★ 复量热区（难度胶囊应为 44×44 vp）"
"$HDC" shell "rm -f /data/local/tmp/V.json; uitest dumpLayout -p /data/local/tmp/V.json" >/dev/null 2>&1
sleep 2
"$HDC" file recv /data/local/tmp/V.json /tmp/V.json >/dev/null 2>&1
/usr/bin/python3 - <<'PY'
import json, re, os
if not os.path.exists('/tmp/V.json') or os.path.getsize('/tmp/V.json') == 0:
    print('  ⚠️ dump 为空 —— 镜像可能又坏了，换 yiju 冷启动试试'); raise SystemExit
d = json.load(open('/tmp/V.json')); D = 3.0; hits = []
def w(o):
    a = o.get('attributes', {}); b = a.get('bounds', '')
    if b and a.get('clickable') == 'true':
        m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b)
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            hits.append((x2 - x1, y2 - y1, a.get('text', '')[:14] or a.get('type', '')))
    for c in o.get('children', []): w(c)
w(d)
print('  可点击元素 %d 个 · 高度小→大前 6:' % len(hits))
for wd, ht, t in sorted(hits, key=lambda z: z[1])[:6]:
    print('    %5.1f×%5.1f vp  %-14s %s' % (wd / D, ht / D, t, '⚠️' if ht / D < 44 else '✅'))
for wd, ht, t in hits:
    if t in ('简单', '普通', '困难'):
        print('  ★ 难度胶囊「%s」: %.1f×%.1f vp  %s' % (t, wd / D, ht / D, '✅ 达标' if ht / D >= 44 else '⚠️ 仍不足'))
PY

say "6. 抓弹簧动画抽帧（点击+连拍同一条设备端命令，零 hdc 往返）"
"$HDC" shell "rm -f /data/local/tmp/z*.jpeg; uitest uiInput click 153 675; uitest uiInput click 322 675; for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do snapshot_display -f /data/local/tmp/z\$i.jpeg; done" >/dev/null 2>&1
rm -f /tmp/z_*.jpeg
for i in $(seq 1 16); do "$HDC" file recv /data/local/tmp/z$i.jpeg /tmp/z_$i.jpeg >/dev/null 2>&1; done
echo "  ★ 不同帧数: $(md5 -q /tmp/z_*.jpeg 2>/dev/null | sort -u | wc -l | tr -d ' ') / 16"
for f in /tmp/z_*.jpeg; do
  cp "$f" "$SHOT/07 弹簧-$(basename "$f" .jpeg).jpeg" 2>/dev/null
done
ls "$SHOT" | tail -6

say "7. appfreeze 与收尾"
echo "  appfreeze: $("$HDC" shell 'ls /data/log/faultlog/faultlogger/ 2>/dev/null | grep -c onemore' 2>/dev/null | tr -d '\r')"
echo "  证据目录：$SHOT"
echo
echo "  ⇒ 记得把结论写进 ~/Desktop/学业规划/_跨会话公告板.md"
