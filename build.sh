#!/bin/bash
# 一局 · 鸿蒙构建脚本（拾海 2026-10-10）
#
# 用法:  bash build.sh [assembleHap|clean|...]      默认 assembleHap
# 并发安全：多人同时构建时自动排队，并清理"上一次失败留下的僵尸锁"
set -u

export DEVECO_CLI_CLT_PATH="$HOME/Library/Huawei/command-line-tools"
export DEVECO_SDK_HOME="$DEVECO_CLI_CLT_PATH/sdk"
JDK=$(ls -d "$HOME"/Library/Java/JavaVirtualMachines/jdk-21* 2>/dev/null | head -1)
if [ -n "$JDK" ]; then
  export JAVA_HOME="$JDK/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

cd "$(dirname "$0")" || exit 1

# ── 僵尸锁：hvigor 已经不在跑，但 .build-lock 还在 ⇒ 上次崩了留的，清掉 ──
if [ -d .hvigor/.build-lock ]; then
  if ! pgrep -f "hvigorw" >/dev/null 2>&1; then
    rm -rf .hvigor/.build-lock
  fi
fi

TASK="${1:-assembleHap}"

# ── 最多重试 3 次（应对 "Another build is already running"）──
for try in 1 2 3; do
  OUT=$("$DEVECO_CLI_CLT_PATH/hvigor/bin/hvigorw" --no-daemon "$TASK" 2>&1)
  RC=$?
  echo "$OUT"
  if echo "$OUT" | grep -q "Another build is already running"; then
    echo "── 有别的构建在跑，等 45 秒重试（第 $try 次）──"
    sleep 45
    if ! pgrep -f "hvigorw" >/dev/null 2>&1; then
      rm -rf .hvigor/.build-lock
    fi
    continue
  fi
  exit $RC
done
echo "── 三次都撞上别的构建，放弃 ──"
exit 1
