#!/bin/bash
# 把模拟器带到"能装能跑"的状态 —— 一条命令，不用再靠运气。
#
# ★★★ 2026-11-02（判据 145）：
#   "设备不可达"有两个根因，症状相同：
#     ① 模拟器崩溃      ⇒ 重启（~2 分钟）
#     ② **屏幕锁定**    ⇒ `power-shell wakeup` + **上滑解锁**（~3 秒）
#   前 9 次我都按 ① 处理，第 10 次拿到错误码
#     `Error 10106102: The device screen is locked during the application launch`
#   才发现有 ②。这个脚本把 ② 固定成标准步骤。
#
# 用法：
#   bash 工具/device_ready.sh              # 只唤醒解锁，检查设备
#   bash 工具/device_ready.sh --restart    # 先重启模拟器再看
#   bash 工具/device_ready.sh --install    # 顺带装最新包并启动
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
# ★ 用函数而不是变量：`$A` 含空格，直接当命令会报 "No such file or directory"
sh_dev() { "${HC}" -t 127.0.0.1:5555 shell "$@"; }
PKG="com.andrewoscar.onemore"

# ── 可选：重启模拟器 ──
if [ "${1:-}" = "--restart" ]; then
  echo "  重启模拟器…"
  "${EMU}" -stop onemore2 >/dev/null 2>&1; sleep 5
  for pid in $(ps aux | grep -iE "qemu|emulator" | grep -v grep | awk '{print $2}'); do
    kill "${pid}" 2>/dev/null
  done
  sleep 12
  nohup "${EMU}" -start onemore2 -instancePath "${HOME}/.Huawei/Emulator/deployed" \
    > /tmp/emu_ready.log 2>&1 &
  sleep 128
fi

# ── 连设备 ──
"${HC}" kill >/dev/null 2>&1; sleep 3
"${HC}" start -p 8710 >/dev/null 2>&1; sleep 10
# ★★★ 判据 1584：**`list targets` ≠ 可用** —— 必须 `shell echo ok` 真的返回 ok
#   而本脚本后面 `sh_dev` 全是 `>/dev/null 2>&1` ⇒ 通道未通会**静默失败**
#   ⇒ 这是三处里**最危险**的（判据 1595）
ok=0
for i in $(seq 1 40); do
  "${HC}" tconn 127.0.0.1:5555 >/dev/null 2>&1
  if "${HC}" -t 127.0.0.1:5555 shell 'echo ok' 2>/dev/null | grep -qx 'ok'; then
    echo "  ✅ 设备已连接且可用（第 ${i} 次，shell 已探活）"; ok=1; break
  fi
  sleep 5
done
[ "${ok}" = 1 ] || { echo "  ❌ 设备通道未建立（判据 1584）"; exit 1; }

# ── ★ 唤醒 + 上滑解锁（这一步以前一直漏） ──
sh_dev "power-shell wakeup" >/dev/null 2>&1; sleep 4
# ★★★ swipe **速度 1200** 是关键：慢速（600）在锁屏上不触发解锁，快速才识别为"上滑解锁"
sh_dev "uitest uiInput swipe 660 1900 660 500 1200" >/dev/null 2>&1; sleep 4
echo "  ✅ 已唤醒并解锁"

# ── 可选：装包并启动 ──
if [ "${1:-}" = "--install" ] || [ "${2:-}" = "--install" ]; then
  HAP="entry/build/default/outputs/default/entry-default-signed.hap"
  [ -f "${HAP}" ] || { echo "  ❌ 找不到 ${HAP}"; exit 1; }
  timeout 900 "${HC}" -t 127.0.0.1:5555 install -r "${HAP}" 2>&1 | tr -d '\r' \
    | grep -oE "install bundle successfully" | head -1 | sed 's/^/  装: /'
  sh_dev "aa force-stop ${PKG}" >/dev/null 2>&1; sleep 3
  sh_dev "aa start -b ${PKG} -a EntryAbility" 2>&1 | tr -d '\r' | head -1 | sed 's/^/  start: /'
  sleep 16
  # ★ 2026-11-02 判据 145：启动失败必须看错误码，不要盲目重启
  pid=$(sh_dev "pidof ${PKG}" 2>&1 | tr -d '\r')
  if [ -z "${pid}" ]; then
    echo "  ⚠️ 启动失败，重试一次（已知：首次常失败）"
    sh_dev "power-shell wakeup" >/dev/null 2>&1; sleep 3
    # ★★★ swipe **速度 1200** 是关键：慢速（600）在锁屏上不触发解锁，快速才识别为"上滑解锁"
sh_dev "uitest uiInput swipe 660 1900 660 500 1200" >/dev/null 2>&1; sleep 3
    sh_dev "aa start -b ${PKG} -a EntryAbility" 2>&1 | tr -d '\r' | head -1 | sed 's/^/  start2: /'
    sleep 14
    pid=$(sh_dev "pidof ${PKG}" 2>&1 | tr -d '\r')
  fi
  echo "  pid: ${pid:-（空）}"
  [ -n "${pid}" ] || { echo "  ❌ 仍未起来 —— 看上面的错误码"; exit 1; }
fi

echo "  ✅ 设备就绪"
