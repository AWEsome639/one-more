# 电视（第 ⑤ 项）执行手册 —— 从「没镜像」到「能测」

> 现状（`2026-11-17 23:15` 实测）：`tv` 镜像只有 `6.1.1(24)` 与 `5.1.1(19)`、**都没下载** ⇒ 实例建不出来。
> 本手册把每一步写成可复制的命令，**先验「能装能进能测」，再谈改字号**。

## 0. 前置检查（每次开工都先跑）

```bash
date "+%H:%M %a"
df -h / | tail -1            # 磁盘 ≥ 20 GiB（镜像几 GB + userdata 2~4 GB）
ps axo comm | grep -ci "/emulator/Emulator"   # 必须是 0（一次只开一台）
"$EMU" -imageList | python3 -c "import sys,json;[print(x['deviceType'],x['osVersion'],x['downloaded']) for x in json.load(sys.stdin)]" | grep ^tv
```

## 1. 下镜像 + 建实例（需他点头：几 GB 流量）

```bash
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
# ① 建实例（CLI 会在缺镜像时拉取；osVersion 用 imageList 里 tv 那一条的完整串）
"$EMU" -create onemore_tv -deviceType tv -osVersion "HarmonyOS 6.1.1(24)"
ls -d ~/.Huawei/Emulator/deployed/onemore_tv      # 出现实例目录 = 成功
```

## 2. 启动 + 量屏（**必须量，别猜**）

```bash
echo y > /tmp/yes.txt
(nohup "$EMU" -start onemore_tv < /tmp/yes.txt > /tmp/tv_boot.log 2>&1 &)
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
for i in $(seq 1 45); do n=$("$HC" list targets 2>/dev/null | grep -cE '^[0-9A-Za-z]'); [ "$n" -ge 1 ] && break; sleep 10; done
sleep 22
"$HC" shell "hidumper -s RenderService -a screen" | grep -oE "render resolution= [0-9x]+"
"$HC" shell "power-shell wakeup"            # 判据 2869：锁屏会让测量静默失败
```

**⇒ 把分辨率记下来：`SHOT_SCREEN_H` = 高（px）、`SHOT_PX_PER_VP` = **量出来的** px/vp**
（手机 `1600px / 533vp = 3.0`；电视 `1280x720vp` ⇒ 若分辨率 `1280x720px` 则 `1.0`，若 `1920x1080px` 则 `1.5` —— **必须实测**）。

## 3. 先验「能装能进能测」（**这一步不改任何代码**）

```bash
"$HC" install -r entry/build/default/outputs/default/entry-default-signed.hap
"$HC" shell "aa force-stop com.andrewoscar.onemore"; sleep 2
"$HC" shell "aa start -a EntryAbility -b com.andrewoscar.onemore"; sleep 10
export SHOT_SCREEN_H=<量到的高> SHOT_GAME_BOTTOM=<高-84> SHOT_PX_PER_VP=<量到> SHOT_NO_LEDGER=1 SHOT_BUDGET_S=420
python3 工具/shot_game.py "Snake 3D"    # 用今天修过的款当探针
```

**⇒ 判据：拿到 `OK` 且 `lowest` 是「开始」这类按钮 ⇒ 电视链路通。**
**⇒ 若报 `NO_CARD`：先查 `aa dump -l | grep -i locked`（判据 `2869`），再查卡片 band（判据 `2865`：`0.35H..0.625H` 是否覆盖到实际位置）。**

## 4. 只有第 3 步过了，才谈字号

```bash
# 抽 3–5 款（要覆盖：棋盘类 / 列表类 / 长文案类），记录每款的 lowest 高度与字号观感
# 再决定 FontSize 是否乘 Bp.scale()（预计 TV 需 ×1.35–1.45，判据见「电视端文字比例-离线量化」）
```

## 5. 收尾（**必须做**）

```bash
"$EMU" -stop onemore_tv
ps axo comm | grep -ci "/emulator/Emulator"    # 必须是 0
```

## 已知风险（写在这里，免得到时候慌）

1. **TV 镜像只有 `6.1.1` / `5.1.1`，而全库基线是 API 12** ⇒ 可能遇到 API 行为差异，**别急着当自己的 bug**。
2. **`FontSize` 乘 `1.45` 会影响 355 款** ⇒ 电视上可能换行/溢出，**必须抽查后再决定**。
3. **`Cell.of` 在电视上已是 `1.45×`，大字号的 `Cell.tap(44)` 会更大** ⇒ 触控底线不紧张，但布局会更挤。
