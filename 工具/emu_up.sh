#!/bin/bash
# 模拟器唯一启动入口（判据 2905）—— **已有一个在跑就复用，绝不再起第二个**。
#
# 背景（2026-11-18 奥森："怎么同时开两个模拟器呀……电脑真吃不消" / "模拟器又崩溃啦"）：
#   项目里曾有 5 个脚本各自 `Emulator -start`，都不先检查 ⇒ 重复启动 ⇒
#   `Failed to start emulator: this emulator instance is already running` ⇒
#   内存挤爆、跑批中途设备消失（NOT_HOME）。
#   ⇒ 以后**只准**通过本脚本起模拟器。
#
# 用法：
#   bash 工具/emu_up.sh            # 需要时起（已有一个在跑就复用）
#   bash 工具/emu_up.sh --status   # 只看状态、不起
# 退出码：0 = 设备就绪可测；1 = 起不来
set -u
MODE="up"
if [ "${1:-}" = "--status" ]; then MODE="status"; fi
DEV="onemore7"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"

count_emu() { ps axo comm 2>/dev/null | grep -i '/emulator/Emulator' | grep -v grep | grep -vc crash; }
device_ok() { "$HC" list targets 2>/dev/null | grep -qE '^[0-9A-Za-z]'; }

N=$(count_emu)
if [ "$MODE" = "status" ]; then
  echo "emulator 进程 $N 个 / 设备 $([ "$(device_ok && echo 1 || echo 0)" = 1 ] && echo 在线 || echo 不在)"
  exit 0
fi

if [ "$N" -ge 1 ]; then
  echo "⇒ 已有 $N 个模拟器进程，**不再启动新的**"
  if device_ok; then echo "⇒ 设备在线，复用"; else echo "⚠️ 进程在但设备不应答 ⇒ 建议先 bash 工具/emu_down.sh"; exit 1; fi
else
  echo "⇒ 无实例，启动 $DEV"
  echo y > /tmp/emu_yes.txt
  ( nohup "$EMU" -start "$DEV" < /tmp/emu_yes.txt > "/tmp/emu_$DEV.log" 2>&1 & )
  for i in $(seq 1 18); do
    sleep 10
    device_ok && { echo "⇒ 设备就绪（$((i*10))s）"; break; }
  done
  device_ok || { echo "❌ ${i}0s 内设备未就绪，看 /tmp/emu_$DEV.log"; exit 1; }
  sleep 20
fi

# 唤醒 + 解锁（判据 2888：唤醒 ≠ 解锁）
"$HC" shell "power-shell wakeup" >/dev/null 2>&1
sleep 2
"$HC" shell "uitest uiInput swipe 1280 1400 1280 600 300" >/dev/null 2>&1
sleep 2
echo "✅ 可测"
