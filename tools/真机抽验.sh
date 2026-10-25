#!/usr/bin/env bash
# 「一局」真机抽验（Mate 70）—— 2026-10-13 12:0x 更新
# ★ 本轮新增：隐私合规三项（首启弹窗 / 应用内入口 / 假话已修）
# ★ 抽验通过 ⇒ 放量 260 文件；晚上回来把结果告诉我
# 用法: bash ~/dev/yiju/真机抽验.sh
#
# ★ 2026-10-13 新增 4 项（都要人眼）：界面模式 · A-Z 列表 · 反馈与关于 · 数字滚动
# ★ 装包必须【先 uninstall】—— `install -r` 会报 sign info inconsistent 9568332
set -u
HDC=~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc
HAP=~/dev/yiju/entry/build/default/outputs/default/entry-default-signed.hap
OUT=~/dev/yiju/真机抽验-$(date +%m%d-%H%M)
mkdir -p "$OUT"
say () { echo ""; echo "────────────────────────────────────────"; echo "$1"; echo "────────────────────────────────────────"; }

say "① 设备"
$HDC list targets | tr -d '\r' | tee "$OUT/00-设备.txt"
T=$($HDC list targets 2>/dev/null | grep -v Empty | head -1 | tr -d '\r')
if [ -z "$T" ]; then echo "  ❌ 没有设备 —— 插上 Mate 70 并开 USB 调试"; exit 1; fi
echo "  ✅ $T"

say "② 卸载旧包（签名冲突必须先卸；会清 App 数据）"
$HDC -t "$T" uninstall com.andrewoscar.onemore 2>&1 | tr -d '\r' | tail -1

say "③ 装最终版"
ls -la "$HAP" | awk '{printf "  HAP %.2f MB @ %s %s\n",$5/1048576,$7,$8}'
$HDC -t "$T" install "$HAP" 2>&1 | tr -d '\r' | tail -2 | tee "$OUT/01-安装.txt"

say "④ 冷启动 + 抓开屏（动画③ 错峰进场）"
$HDC -t "$T" shell aa start -a EntryAbility -b com.andrewoscar.onemore >/dev/null 2>&1
sleep 3
for i in 1 2 3 4 5 6; do $HDC -t "$T" shell "snapshot_display -f /data/local/tmp/boot$i.jpeg" >/dev/null 2>&1; done
for i in 1 2 3 4 5 6; do $HDC -t "$T" file recv "/data/local/tmp/boot$i.jpeg" "$OUT/02-开屏-帧$i.jpeg" >/dev/null 2>&1; done
sleep 12
echo "  ✅ 6 帧存到 $OUT/02-开屏-帧*.jpeg（看四块砖是否依次落位）"

say "⑤ appfreeze 检查（必须 0）"
$HDC -t "$T" shell "ls /data/log/faultlog/faultlogger/ 2>/dev/null | grep -c onemore" 2>/dev/null | tr -d '\r' | sed 's/^/  onemore 崩溃数: /'

say "⑥ ★ 抽验 5 款（人眼看：点得动、显示会变、不冻结）"
cat <<'GAMES'
  ┌──────────────────────────────────────────────────────┐
  │ 1. 2048        —— 滑动方块要合并、分数要涨            │
  │ 2. 打砖块      —— 球在动、挡板跟手                    │
  │ 3. 蜘蛛纸牌    —— 拖牌能落位、发牌能翻                │
  │ 4. 像素鸟/跳一跳 —— 点击/长按要有反应、不冻结          │
  │ 5. 麻将        —— 点牌能选中/消除                     │
  │                                                      │
  │ ✅ 全过 ⇒ 放量 260 文件：                             │
  │   python3 ~/.dsh/storages/games-input-20261013/inline_fix.py \
  │       --apply --risky ~/dev/yiju/entry/src/main/ets/games/*.ets
  └──────────────────────────────────────────────────────┘
GAMES

say "⑦ ★ 今天新增的 4 项（人眼终审）"
cat <<'NEW'
  ┌──────────────────────────────────────────────────────┐
  │ A. 界面模式   设置 → 界面模式 → 大字模式               │
  │               ⇒ 全 App 字要变大（实测 145×84 → 180×105）│
  │               再切回「默认」⇒ 要变回去                  │
  │                                                      │
  │ B. A-Z 列表   首页 → 计数行右侧 [abc A-Z]              │
  │               ⇒ 按拼音 A-Z 分组 + 右侧索引条            │
  │               点字母 G/S 要能跳（S 组最大，65 款）      │
  │               空组 I/O/U/V 应【变淡】                  │
  │                                                      │
  │ C. 反馈与关于 设置 → 滚到底                            │
  │               ⇒ andrew680701@outlook.com + [复制]      │
  │               点复制应出「已复制 ✓」                    │
  │                                                      │
  │ D. 数字滚动   随便打完一局 → 进「统计」                 │
  │               ⇒ 数字应从 0 滚上去（不是"啪"一下出现）   │
  │               ⚠️ 这一项必须【打完】才有非 0 数字         │
  └──────────────────────────────────────────────────────┘
NEW

say "⑦-b ★ 隐私合规（本轮新增，提审硬要求）"
cat <<'PRIV'
  ┌──────────────────────────────────────────────────────┐
  │ A. 首启弹窗   全新安装后第一次启动                     │
  │               ⇒ 应弹「隐私说明」，【两个按钮】：        │
  │                 [查看全文]  [同意并继续]               │
  │               ⇒ 点「查看全文」应跳系统浏览器            │
  │               ⚠️ URL 现在是占位 example.com（待托管）   │
  │               ⇒ 点「同意并继续」后不应再弹（重启验一次）│
  │                                                      │
  │ B. 应用内入口 设置 → 滚到底 → 🔒 隐私政策              │
  │               ⇒ 应能点开（同上，占位地址）              │
  │                                                      │
  │ C. 文案真话   设置 → 游戏偏好 → 「无需联网」            │
  │               ⇒ 下面说明应写「飞行模式照样玩；网络权限  │
  │                 只给局域网对战用，不连公网、不上传数据」│
  │               ⛔ 不该再出现「连网络权限都没申请」        │
  └──────────────────────────────────────────────────────┘
PRIV

say "⑧ 局域网 / 竞速（需要 ≥2 台设备）"
cat <<'LAN'
  ┌──────────────────────────────────────────────────────┐
  │ 1. 两台设备连【同一个 Wi-Fi】（热点最稳）              │
  │    ⚠️ 校园网若开了客户端隔离 ⇒ 不通 ⇒ 换热点            │
  │ 2. 设置 → 局域网对战 → 一台建房、一台加入              │
  │ 3. 回合制 8 款：井字棋/四子棋/黑白棋/取石子/           │
  │    播棋/五子棋/跳棋/9路围棋                           │
  │ 4. ★ 竞速模式：打开开关 ⇒ 355 款任选 ⇒ 谁先完成谁赢    │
  │    ⇒ 排名榜要显示 🥇🥈🥉 + 用时                        │
  └──────────────────────────────────────────────────────┘
LAN

say "⑨ 收尾"
$HDC -t "$T" shell "snapshot_display -f /data/local/tmp/final.jpeg" >/dev/null 2>&1
$HDC -t "$T" file recv /data/local/tmp/final.jpeg "$OUT/99-收尾.jpeg" >/dev/null 2>&1
$HDC -t "$T" shell "uitest dumpLayout -p /data/local/tmp/final.json" >/dev/null 2>&1
$HDC -t "$T" file recv /data/local/tmp/final.json "$OUT/99-收尾.json" >/dev/null 2>&1

echo ""
echo "════════════════════════════════════════"
echo "  证据目录: $OUT"
ls -la "$OUT" | tail -n +2 | awk '{printf "    %-28s %s\n",$9,$5}'
echo "════════════════════════════════════════"
