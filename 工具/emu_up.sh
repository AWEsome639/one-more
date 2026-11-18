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

# ★★★ 2026-11-18（判据 2908）：**有编译在跑就不启模拟器**。
#   实证：`~/.Huawei/Emulator/deployed/onemore7/Log/crash_server.log` 在崩前写的是
#   `[Warning] memory is low, freeMem: 791 / 691 / 524 / 424 ...`；
#   今天两个崩溃包（`10:37`、`11:36`）正是「边编译边跑设备」那两次。
#   ⇒ **建编译/构建进程在跑时，拒绝启动模拟器**（宁可不跑，不要崩）。
#   注：不能用「空闲内存」做闸门 —— macOS 平时就把内存拿去做缓存，
#   本机空闲页常年只有百多 MB，按它判会永远拒绝。
# ★ 实测：**hvigor 守护进程常驻不退（跑了 3h+ 、RSS 仅 0.01G）** ⇒ 用 pgrep 判会永远误判。
#   ⇒ 改用「占 CPU 的真编译」判据：任一 hvigor/java/node 子进程 CPU > 20% 即视为在编译。
building() {
  ps axo pcpu,command 2>/dev/null \
    | grep -E "hvigor|ArkTSCompile|ets-loader" | grep -v grep \
    | awk '{ if ($1 > 20) { found=1 } } END { exit(found ? 0 : 1) }'
}
if building && [ "$MODE" != "status" ]; then
  echo "❌ 有编译/构建进程在跑 ⇒ 不启动模拟器（判据 2908）"
  echo "   原因：实证崩前 freeMem 降到 424–800MB；今天两次崩溃都是边编译边跑设备。"
  exit 1
fi

if [ "$MODE" = "status" ]; then
  if building; then BS="有编译在跑（启动会被拒）"; else BS="无编译"; fi
  echo "emulator 进程 $N 个 / 设备 $([ "$(device_ok && echo 1 || echo 0)" = 1 ] && echo 在线 || echo 不在) / $BS"
  exit 0
fi

if [ "$N" -ge 1 ]; then
  echo "⇒ 已有 $N 个模拟器进程，**不再启动新的**"
  if device_ok; then echo "⇒ 设备在线，复用"; else echo "⚠️ 进程在但设备不应答 ⇒ 建议先 bash 工具/emu_down.sh"; exit 1; fi
else
  echo "⇒ 无实例，启动 $DEV"
  echo y > /tmp/emu_yes.txt
  ( nohup "$EMU" -start "$DEV" < /tmp/emu_yes.txt > "/tmp/emu_$DEV.log" 2>&1 & )
  for i in $(seq 1 30); do   # 判据 2905 补：冷启动实测可超 180s，放宽到 300s
    sleep 10
    device_ok && { echo "⇒ 设备就绪（$((i*10))s）"; break; }
  done
  device_ok || { echo "❌ 300s 内设备未就绪，看 /tmp/emu_$DEV.log"; exit 1; }
  sleep 20
fi

# 唤醒 + 解锁（判据 2888：唤醒 ≠ 解锁）
"$HC" shell "power-shell wakeup" >/dev/null 2>&1
sleep 2
"$HC" shell "uitest uiInput swipe 1280 1400 1280 600 300" >/dev/null 2>&1
sleep 2
echo "✅ 可测"
