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
# ── ★ 上架包必须 release 模式：debug 构建的包 AGC 会报 993（Profile 非法）──
HVIGOR_ARGS=""
# ★★★ 2026-11-08 perf-hunter：`assembleHap` 也能出 **release** 包（此前只有 `assembleApp*` 会传 buildMode=release，
#   ⇒ `bash build.sh assembleHap` 出来的**永远是 debug 包**，实测包体 46.06 MB vs release 22.27 MB）。
#   用法：`BUILD_RELEASE=1 bash build.sh assembleHap`
#   ⚠️ **默认（不设该变量）仍然走 debug** —— 日常验证要 debug（能看日志/符号），这个默认绝不能动。
if [ "${BUILD_RELEASE:-0}" = "1" ]; then
  HVIGOR_ARGS="-p buildMode=release"
fi
case "$TASK" in
  assembleApp*)
    HVIGOR_ARGS="-p buildMode=release"
    ;;
esac
# ── 签名路径自检（**凡是 release 构建都要查**：hvigor 找不到签名文件会静默回退 debug 签名）──
if [ -n "$HVIGOR_ARGS" ] && [ -f build-profile.json5 ]; then
  for _k in certpath profile storeFile; do
    _p=$(sed -n 's/.*"'"$_k"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' build-profile.json5 | head -1)
    if [ -n "$_p" ] && [ ! -e "$_p" ]; then
      echo "❌ 签名配置里的 $_k 路径不存在：$_p" >&2
      echo "   hvigor 会静默回退 debug 签名 ⇒ AGC 报 993" >&2
      exit 2
    fi
  done
fi
# 提示当前构建模式（避免"以为出了 release、其实是 debug"）
if [ -n "$HVIGOR_ARGS" ]; then
  echo "── 构建模式: release   参数: ${HVIGOR_ARGS} ──"
else
  echo "── 构建模式: debug（默认；要 release 用 BUILD_RELEASE=1）──"
fi

for try in 1 2 3; do
  OUT=$("$DEVECO_CLI_CLT_PATH/hvigor/bin/hvigorw" --no-daemon "$TASK" $HVIGOR_ARGS 2>&1)
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
