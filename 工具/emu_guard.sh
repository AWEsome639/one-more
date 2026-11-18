#!/bin/bash
# 判据 2905 的守卫：**退出码 0 = 已有实例（调用方不要再启动）**；1 = 无实例、可以启动。
# 用法（放在任何 `-start` 之前）：
#   if bash 工具/emu_guard.sh; then echo "复用已有实例"; else <启动命令>; fi
n=$(ps axo comm 2>/dev/null | grep -i '/emulator/Emulator' | grep -v grep | grep -vc crash)
if [ "${n:-0}" -ge 1 ]; then
  echo "⇒ 已有 ${n} 个模拟器实例，复用、不再启动（判据 2905）"
  exit 0
fi
exit 1
