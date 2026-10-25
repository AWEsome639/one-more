#!/bin/bash
# ★ 装包守卫（2026-10-14 建立）
# 起因：会话里手动 `hdc install ... >/dev/null 2>&1` 吞掉报错
#   ⇒ 5 轮"修复无效"其实是【设备跑旧包】
# 规矩：先卸再装，★ 必看输出，判据是 "install bundle successfully"
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
PKG=com.andrewoscar.onemore
HAP="${1:-entry/build/default/outputs/default/entry-default-signed.hap}"

[ -f "$HAP" ] || { echo "  ❌ HAP 不存在: $HAP"; exit 1; }
printf "  HAP: %s (%s)\n" "$HAP" "$(stat -f '%Sm' -t '%H:%M:%S' "$HAP")"

# ① 先卸
OUT_U=$(timeout 120 "$HDC" uninstall "$PKG" 2>&1 | tr -d '\r')
if echo "$OUT_U" | grep -q "uninstall bundle successfully"; then
  echo "  ✅ 卸载成功"
else
  echo "  ⚠️ 卸载输出: $(echo "$OUT_U" | tail -1 | cut -c1-90)"
  case "$OUT_U" in *"not installed"*|*"does not exist"*) echo "     （本来就没装，继续）";; esac
fi
sleep 2

# ② 再装（★ 不吞输出）
OUT_I=$(timeout 600 "$HDC" install "$HAP" 2>&1 | tr -d '\r')
if echo "$OUT_I" | grep -q "install bundle successfully"; then
  echo "  ✅✅ 装包成功（install bundle successfully）"
  exit 0
fi
echo "  ❌❌ 装包失败！原始输出:"
echo "$OUT_I" | tail -4 | sed 's/^/     /'
case "$OUT_I" in
  *9568332*|*"sign info inconsistent"*)
    echo "     ★ 诊断：签名不一致（通常是旧包签名残留）"
    echo "     ★ 处置：已尝试先卸后装；若仍失败 ⇒ hdc shell bm uninstall -n $PKG 再试" ;;
esac
exit 1
