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


# ═══════════════════════════════════════════════════════════════════════
# ★★★ 2026-11-08 perf-hunter（判据 1827）：**编译缓存体检**（`BUILD_STRICT=1` 时启用）
#
# 背景：今天 `pages/GameHost.ets` 的改动**从没被编进包** —— `modules.abc` 比源码老 1.5 小时，
#       清 `intermediates` 重建才生效。根因（见 `_巡检记录/编译缓存排查-20261108.md`）：
#         ① `.hvigor/cache/file-cache.json` **不按 .ets 逐文件记哈希**（111 条里没有源码），
#            `CompileArkTS` 只按**目录快照**判 up-to-date；
#         ② `/Users/a0000/dev/yiju` 是 `One More` 的**符号链接** ⇒ 同一任务在缓存里有两套键
#            （`:yiju:…` / `:One More:…`），换路径构建会错配；
#         ③ 只比 mtime 会漏（重打包没重编译时 mtime 会变新）。
#
# 用法：`BUILD_STRICT=1 bash build.sh assembleHap`
#   · **默认（不设该变量）行为与以前完全一致**，日常构建不受影响
#   · 构建前：源码比 `modules.abc` 新 ⇒ **先 clean**（代价：全量重建实测 **约 10 分 48 秒**）
#   · 构建后：三道闸 —— ①`abc` 比所有 `.ets` 新 ②`hap` 比 `abc` 新 ③设备上装的包不早于本地 `hap`
#   · 任一道不过 ⇒ 打印原因并 **exit 4**（不要拿这种包去验证）
# ═══════════════════════════════════════════════════════════════════════
BUILD_STRICT_MODE="${BUILD_STRICT:-0}"
ABC_PATH="entry/build/default/intermediates/loader_out/default/ets/modules.abc"
HAP_PATH="entry/build/default/outputs/default/entry-default-signed.hap"

_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

# 构建前闸：源码比产物新 ⇒ 先 clean（否则很可能白编）
_strict_pre() {
  if [ ! -f "$ABC_PATH" ]; then
    echo "── BUILD_STRICT：还没有 modules.abc（首次构建，跳过 clean）──"
    return 0
  fi
  local newer
  newer=$(find entry/src/main/ets -name '*.ets' -newer "$ABC_PATH" -print -quit 2>/dev/null)
  if [ -n "$newer" ]; then
    echo "── BUILD_STRICT：源码比产物新（$newer）──"
    echo "   ⇒ 先 clean 再全量构建；**代价：全量重建实测约 10 分 48 秒**"
    "$DEVECO_CLI_CLT_PATH/hvigor/bin/hvigorw" --no-daemon clean >/dev/null 2>&1 || true
  fi
  return 0
}

# 构建后闸：三道，任一不过 ⇒ exit 4
_strict_post() {
  local fail=0
  # 闸① abc 必须比所有 .ets 新
  if [ -f "$ABC_PATH" ]; then
    local newer
    newer=$(find entry/src/main/ets -name '*.ets' -newer "$ABC_PATH" -print -quit 2>/dev/null)
    if [ -n "$newer" ]; then
      echo "❌ [闸①] 源码比 modules.abc 新：$newer" >&2
      echo "   ⇒ 缓存过期，执行：bash build.sh clean && BUILD_STRICT=1 bash build.sh assembleHap" >&2
      fail=1
    fi
  else
    echo "❌ [闸①] 没有 modules.abc（构建没产出？）" >&2; fail=1
  fi
  # 闸② hap 必须比 abc 新（防"只编了没打包"）
  if [ -f "$HAP_PATH" ] && [ -f "$ABC_PATH" ]; then
    if [ ! "$HAP_PATH" -nt "$ABC_PATH" ]; then
      echo "❌ [闸②] hap 比 modules.abc 旧 ⇒ 包是旧的（只编了没重打包）" >&2; fail=1
    fi
  else
    echo "❌ [闸②] 缺 hap 或 abc" >&2; fail=1
  fi
  # 闸③ 设备上装的包必须不早于本地 hap（需要 hdc + 设备；拿不到就只提示，不判失败）
  local hdc_bin="${HDC_BIN:-}"
  if [ -z "$hdc_bin" ] && command -v hdc >/dev/null 2>&1; then hdc_bin=$(command -v hdc); fi
  if [ -z "$hdc_bin" ] && [ -x "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc" ]; then
    hdc_bin="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
  fi
  if [ -n "$hdc_bin" ] && [ -f "$HAP_PATH" ]; then
    local dev_ut hap_ms
    dev_ut=$("$hdc_bin" shell "bm dump -n com.andrewoscar.onemore 2>/dev/null | grep '\\\"updateTime\\\"' | head -1" 2>/dev/null | grep -o '[0-9]\{13\}' | head -1)
    hap_ms=$(_mtime "$HAP_PATH")
    hap_ms=$((hap_ms * 1000))
    if [ -n "$dev_ut" ]; then
      if [ "$dev_ut" -lt "$hap_ms" ]; then
        echo "❌ [闸③] 设备上装的包比本地 hap 旧（设备 updateTime=${dev_ut} < hap=${hap_ms} ）⇒ 装的是旧包" >&2
        fail=1
      fi
    else
      echo "   [闸③] 设备未连接/读不到 updateTime ⇒ 跳过（不影响判定）"
    fi
  else
    echo "   [闸③] 没有 hdc ⇒ 跳过（不影响判定）"
  fi
  if [ "$fail" -ne 0 ]; then
    echo "❌ BUILD_STRICT：产物校验没过 ⇒ 这个包不能用来验证（判据 1827）" >&2
    exit 4
  fi
  echo "✅ BUILD_STRICT：三道闸全过（abc 比源码新 / hap 比 abc 新 / 设备包不早于本地包）"
}

if [ "$BUILD_STRICT_MODE" = "1" ] && [ "$TASK" = "assembleHap" ]; then
  _strict_pre
fi

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
  if [ "$RC" -eq 0 ] && [ "$BUILD_STRICT_MODE" = "1" ] && [ "$TASK" = "assembleHap" ]; then
    _strict_post
  fi
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
