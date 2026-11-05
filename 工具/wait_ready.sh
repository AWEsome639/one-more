#!/usr/bin/env bash
# ============================================================================
#  工具/wait_ready.sh —— **真正的设备就绪判定**（判据 1583/1584/1586）
#
#  ★ 为什么要有（第 1412 轮）
#    我原来的在线判定是：
#        ONLINE() { [ "$(hdc list targets | grep -c 127.0.0.1:5555)" -ge 1 ]; }
#    而实测：`list targets` **已经返回设备**，但 `hdc shell` 仍报
#        [Fail][E000004]:The communication channel is being established.
#    ⇒ **`list targets` 通过 ≠ 设备可用**
#    ⇒ 而 `uitest dumpLayout` 会**静默失败**（返回空文件）⇒ 我读到空 ⇒
#      误判成「游戏卡住」/「页面上没元素」
#
#  ★ 判据 1584：**`list targets` 返回设备 ≠ 设备可用**
#    ⇒ 必须等 `hdc shell echo ok` 真的返回 `ok`
#
#  ★ 判据 1586：这解释了好几轮里的「TIMEOUT / 空 dump」
#    —— **不是游戏的问题，是设备没通**
#
#  ★ 用法：bash 工具/wait_ready.sh [设备名或端口] [超时秒=600]
#  退出码：0 = 真的可用 ｜ 1 = 超时
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
PORT="${1:-127.0.0.1:5555}"
LIMIT="${2:-600}"

echo "  等设备真正可用（不是「list targets 有」）…"
T0=$(date +%s)
LISTED=0
while :; do
  NOW=$(date +%s)
  EL=$((NOW - T0))
  [ "$EL" -ge "$LIMIT" ] && { echo "  🔴 ${LIMIT}s 超时（阶段："$([ "$LISTED" = 1 ] && echo '已列出但 shell 不通' || echo '未列出')"）"; return 1 2>/dev/null || exit 1; }

  # 阶段 1：先确认列在 targets 里
  if [ "$LISTED" = 0 ]; then
    if timeout 6 "$HC" list targets 2>/dev/null | grep -q "$PORT"; then
      LISTED=1
      timeout 6 "$HC" tconn "$PORT" >/dev/null 2>&1 || true
      echo "    ${EL}s：已列出，开始探 shell…"
    else
      [ $((EL % 30)) -eq 0 ] && echo "    ${EL}s：未列出…"
      sleep 5
      continue
    fi
  fi

  # 阶段 2：探 shell（这是判据 1584 的核心）
  OUT=$(timeout 12 "$HC" -t "$PORT" shell 'echo ok' 2>&1 | tr -d '\r' | head -1)
  case "$OUT" in
    ok)
      echo "  ✅ ${EL}s：**真的可用**（shell 返回 ok）"
      exit 0
      ;;
    *E000004*)
      [ $((EL % 20)) -eq 0 ] && echo "    ${EL}s：通道建立中（E000004）…"
      ;;
    *)
      [ $((EL % 20)) -eq 0 ] && echo "    ${EL}s：shell 返回 [${OUT:0:40}] …"
      ;;
  esac
  sleep 5
done
