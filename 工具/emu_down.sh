#!/bin/bash
# 模拟器唯一关闭入口（判据 2905）—— 先 `-stop`，再核真实进程数，最后按需 SIGKILL。
set -u
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
count_emu() { ps axo comm 2>/dev/null | grep -i '/emulator/Emulator' | grep -v grep | grep -vc crash; }
echo "关前 $(count_emu) 个"
timeout 150 "$EMU" -stop onemore7 >/dev/null 2>&1
sleep 6
for _ in 1 2; do
  P=$(ps axo pid,comm 2>/dev/null | grep -i "/emulator/Emulator" | grep -v grep | grep -v crash | awk '{print $1}')
  [ -n "$P" ] && { kill $P 2>/dev/null; sleep 4; }
done
Q=$(ps axo pid,comm 2>/dev/null | grep -i "/emulator/Emulator" | grep -v grep | grep -v crash | awk '{print $1}')
[ -n "$Q" ] && { kill -9 $Q 2>/dev/null; sleep 3; }
echo "关后 $(count_emu) 个"
