#!/usr/bin/env bash
# 「一局」真机抽验（Mate 70）—— 2026-10-13 备好，明晚一条命令
# 用法: bash ~/dev/yiju/明晚真机抽验.sh
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
HAP=~/dev/yiju/entry/build/default/outputs/default/entry-default-signed.hap
OUT=~/dev/yiju/真机抽验-$(date +%m%d-%H%M)
mkdir -p "$OUT"

echo "═══ ① 设备 ═══"
$HDC list targets | tr -d '\r' | tee "$OUT/00-设备.txt"
T=$($HDC list targets 2>/dev/null | head -1 | tr -d '\r')
[ -z "$T" ] || [ "$T" = "[Empty]" ] && { echo "  ❌ 没有设备 —— 请插上 Mate 70 并开 USB 调试"; exit 1; }
echo "  ✅ $T"

echo "═══ ② 卸载旧包（签名冲突必须先卸）═══"
$HDC -t "$T" uninstall com.andrewoscar.onemore 2>&1 | tr -d '\r' | tail -1

echo "═══ ③ 装最终版（21.2 MB @ 01:55）═══"
$HDC -t "$T" install "$HAP" 2>&1 | tr -d '\r' | tail -2 | tee "$OUT/01-安装.txt"

echo "═══ ④ 启动 + 逐屏 dump ═══"
for i in 1 2 3; do
  $HDC -t "$T" shell aa start -a EntryAbility -b com.andrewoscar.onemore >/dev/null 2>&1
  sleep 8
done
dump () {
  $HDC -t "$T" shell "uitest dumpLayout -p /data/local/tmp/$1.json" >/dev/null 2>&1
  $HDC -t "$T" file recv "/data/local/tmp/$1.json" "$OUT/$1.json" >/dev/null 2>&1
  $HDC -t "$T" shell "snapshot_display -f /data/local/tmp/$1.jpeg" >/dev/null 2>&1
  $HDC -t "$T" file recv "/data/local/tmp/$1.jpeg" "$OUT/$1.jpeg" >/dev/null 2>&1
  echo "  $1: $(stat -f%z "$OUT/$1.json" 2>/dev/null || echo 0) 字节"
}
dump 首页

echo "═══ ⑤ appfreeze ═══"
$HDC -t "$T" shell "ls /data/log/faultlog/faultlogger/ 2>/dev/null | grep -c onemore" 2>&1 | tr -d '\r' | tee "$OUT/02-appfreeze.txt"

echo
echo "═══ 完成 ═══"
echo "  证据目录: $OUT"
echo
echo "★ 下一步（人工）：在真机上依次玩 5 款并截图——"
echo "   ① 2048（拖动/方向键，看分数是否变）"
echo "   ② 打砖块（看场地是否正方、边框在屏内、球卡不卡）"
echo "   ③ 蜘蛛纸牌（选中后能否取消）"
echo "   ④ 像素鸟 / 跳一跳（有没有动画）"
echo "   ⑤ 麻将连连看（消牌后剩余对数是否变）"
echo
echo "★ 5 款都正常 ⇒ 才允许放量 260 文件："
echo "   python3 ~/.dsh/storages/games-input-20261013/inline_fix.py --apply --risky ~/dev/yiju/entry/src/main/ets/games/*.ets"
