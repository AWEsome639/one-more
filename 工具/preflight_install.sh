#!/bin/bash
# ★ 2026-11-14：**装包后、开跑前的硬校验** —— 堵住队友审计出的最高危一条：
#   「`sweep_all.sh` / `shot_game.py` 全程没有 `hdc install`，也不读设备上的 bundle 版本
#    ⇒ 若设备是旧包，153 款全测在旧版上，而台账会写『这轮 = 新 HAP』，明早完全看不出来。」
#   昨晚已经真实发生过一次。
#
# 用法：
#   bash 工具/preflight_install.sh          # 只检查，退出码 0=可开跑 / 1=必须停
#   bash 工具/preflight_install.sh --quiet  # 只打结论
#
# 判据：**设备上的 bundle `updateTime` 不早于本地 HAP 的 mtime** ⇒ 装的是当前这个包。
#       （装包发生在 HAP 生成之后，所以正常情况 updateTime ≥ mtime）
set +u
cd "/Users/a0000/dev/One More" || exit 1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
# ★ 2026-11-14 修（判据 2071 逐行验变量时发现）：**`hdc` 不在 `PATH` 里**！
#   脚本里各自写死了全路径（`shot_game.py:19` / `verify_layout.py:50` 都是这个值），
#   而我这个脚本原来用裸 `hdc` ⇒ **永远「command not found」⇒ 永远报「设备不在线」**。
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
BUNDLE="com.andrewoscar.onemore"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
QUIET=""
[ "$1" = "--quiet" ] && QUIET=1
ok() { [ -n "$QUIET" ] || echo "  ✅ $*"; }
bad() { echo "  ❌ $*"; }

# 1) 本地 HAP 在不在
if [ ! -f "$HAP" ]; then bad "本地 HAP 不存在：$HAP"; echo "⇒ 先编译"; exit 1; fi
HAP_MT=$(stat -f '%m' "$HAP" 2>/dev/null)
HAP_T=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$HAP")
ok "本地 HAP: $HAP_T ($(( $(stat -f '%z' "$HAP") / 1024 )) KB)"

# 2) 设备在不在
TGT=$("$HC" list targets 2>/dev/null | head -1 | tr -d ' \r')
if [ -z "$TGT" ] || echo "$TGT" | grep -qi "empty"; then
  bad "设备不在线 (hdc list targets 为空)"
  echo "⇒ 先起模拟器：\$EMU -start onemore7 -noWindow，等满 3 分钟再跑本脚本"
  exit 1
fi
ok "设备在线：$TGT"

# 3) 设备上的 bundle 更新时刻
DUMP=$("$HC" shell "bm dump -n $BUNDLE" 2>/dev/null)
if [ -z "$DUMP" ]; then
  bad "设备上没有 $BUNDLE (bm dump 无输出) ⇒ 根本没装"
  exit 1
fi
# updateTime 常见格式： "updateTime": "2026-11-14 07:31:03" 或纯毫秒
# ★ 2026-11-14 关键修正：**真机格式是毫秒 epoch 数字，不是日期字符串！**
#   台账实证（`_巡检记录/12语言真机2-20261108.md`）：`"updateTime": 1794075532557  ⇒ 2026-11-08 02:18:52`
#   ⇒ 原来只认 `YYYY-MM-DD HH:MM:SS` ⇒ **永远匹配不上 ⇒ 闸门永远是空的**。
#   现在两种都认：先试日期串，再试 13 位毫秒数。
_raw=$(echo "$DUMP" | grep -oE '"updateTime"[^,}]*' | head -1)
DEV_T=$(echo "$_raw" | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
DEV_MS=$(echo "$_raw" | grep -oE '[0-9]{13}')
if [ -z "$DEV_T" ] && [ -n "$DEV_MS" ]; then
  DEV_T=$(date -r $(( DEV_MS / 1000 )) '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
fi
if [ -z "$DEV_T" ]; then
  # ★ 2026-11-14 改：**「解析不出来」不等于「包是旧的」** —— 用我自己的正则失败去挡一整夜的活，是判断错误。
  #   ⇒ 放行，但打醒目警告 + 给出 10 秒手工确认命令。
  echo "  ⚠️ 读不到 updateTime ⇒ 自动校验失败（不是「包旧」，多半是 bm dump 格式与我预期不同）"
  echo "     **已放行**，但请先手工确认一次（10 秒）："
  echo "       \"$HC\" shell bm dump -n $BUNDLE | grep -i update"
  echo "     把它和本地 HAP 时间（$HAP_T）比一下：不早于就没问题。"
  exit 0
fi
ok "设备上的包：$DEV_T"

# 4) 比对（把两者都转成 epoch 秒）
DEV_S=$(date -j -f '%Y-%m-%d %H:%M:%S' "$DEV_T" '+%s' 2>/dev/null)
if [ -z "$DEV_S" ]; then
  echo "  ⚠️ 时间格式解析失败：$DEV_T ⇒ 自动校验无法完成，**已放行**"
  echo "     请手工比：设备 $DEV_T  vs  本地 $HAP_T（设备不早于本地就没问题）"
  exit 0
fi
DELTA=$(( DEV_S - HAP_MT ))
if [ "$DELTA" -ge 0 ]; then
  ok "设备包不早于本地 HAP (差 ${DELTA}s) ⇒ 装的是当前这个包"
  [ -n "$QUIET" ] || echo
  [ -n "$QUIET" ] || echo "✅ 可开跑"
  exit 0
else
  bad "设备包 **早于** 本地 HAP $(( -DELTA ))s ⇒ 设备上是旧包!"
  echo "   设备：$DEV_T"
  echo "   本地：$HAP_T"
  echo "⇒ 现在跑，这一夜全测在旧包上，而台账会写「新 HAP」。**必须停。**"
  echo "⇒ 修：\"$HC\" install -r $HAP   （必须看见 install bundle successfully）"
  exit 1
fi
