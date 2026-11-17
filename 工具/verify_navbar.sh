#!/usr/bin/env bash
# verify_navbar.sh —— 验收「导航条跟随主题」这一修（判据 2851）
#
# 用法：bash 工具/verify_navbar.sh ["Affix Factory"]
# 前提：没有别的模拟器在跑（判据 2852：先用 ps 查真实 comm，不要用 pgrep -f qemu-system）
# 产出：_巡检记录/截图-<款>-<时间>.jpeg（深色）+ /tmp/navbar_bottom.png（裁好的底部，直接看图）
set -u
cd "$(dirname "$0")/.." || exit 1
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
GAME="${1:-Affix Factory}"

# ① 磁盘闸（判据 2198）
FREE=$(df -k / | tail -1 | awk '{print int($4/1024/1024)}')
[ "$FREE" -lt 14 ] && { echo "❌ 可用仅 ${FREE}GiB（<14 闸），模拟器会拒启动" >&2; exit 1; }

# ② 已经有一个在跑就别再开（判据 2852）
RUNNING=$(ps axo comm 2>/dev/null | grep -ci "/emulator/Emulator")
if [ "$RUNNING" -gt 0 ]; then
  echo "❌ 已有 $RUNNING 个模拟器进程在跑 —— 先 \$EMU -stop <实例>，别再开第二个" >&2
  ps axo pid,pcpu,comm 2>/dev/null | grep -i "/emulator/Emulator" | head -3 >&2
  exit 1
fi

# ③ 起实例 + 等上线
echo y > /tmp/yn_yes.txt
( nohup "$EMU" -start onemore7 < /tmp/yn_yes.txt > /tmp/yn_emu.log 2>&1 & )
for i in $(seq 1 40); do
  n=$("$HC" list targets 2>/dev/null | grep -cE '^[0-9A-Za-z]')
  [ "$n" -ge 1 ] && { echo "设备 $((i*10))s"; break; }
  sleep 10
done
sleep 20

# ④ 装包 + 起 App
timeout 420 "$HC" install -r entry/build/default/outputs/default/entry-default-signed.hap 2>&1 | tail -1 | cut -c1-20
"$HC" shell "aa force-stop com.andrewoscar.onemore" >/dev/null 2>&1
sleep 2
"$HC" shell "aa start -a EntryAbility -b com.andrewoscar.onemore" >/dev/null 2>&1
sleep 10

# ⑤ 切深色测这一款（脚本退出时会自动切回浅色）
timeout 400 bash 工具/dark_sample.sh "$GAME" 2>&1 | grep -E "OK|WRONG|切换后|已是浅色|❌" | head -4

# ⑥ 裁底部（验收的核心：白条还在不在）
SHOT=$(ls -t "_巡检记录/截图-${GAME// /_}-"*.jpeg 2>/dev/null | head -1)
if [ -n "$SHOT" ]; then
  python3 -c "
from PIL import Image
im = Image.open('$SHOT'); w, h = im.size
im.crop((0, h-200, w, h)).resize((w, 400), Image.LANCZOS).save('/tmp/navbar_bottom.png')
print('深色截图:', '$SHOT')
print('底部裁图: /tmp/navbar_bottom.png  ← 看图判断白条是否消失')
" 2>&1 | tail -2
else
  echo "⚠️ 没找到 $GAME 的新截图"
fi

# ⑦ 收工（务必确认真的停了）
timeout 120 "$EMU" -stop onemore7 2>&1 | tail -1 | cut -c1-40
sleep 4
LEFT=$(ps axo comm 2>/dev/null | grep -ci "/emulator/Emulator")
echo "收工后模拟器进程: $LEFT"
[ "$LEFT" -gt 0 ] && echo "⚠️ 还有残留，手动确认后再收"
