# 设备 vp 真值表（权威，从模拟器 `config.ini` 直接读出）

> ⚠️ **不要再用「px ÷ 3」推 vp** —— 三台模拟器的 `density` 不都是 `480`。
> 折屏是 `500`，按 `÷3` 推就会得到错的 `741×832`。

## 一、真值

| 设备 | `hw.lcd.density` | 密度（density/160）| px | **vp（真值）** | `Bp.isShort()` |
|---|---|---|---|---|---|
| `onemore7`（横屏手机）| `480` | `3.0` | `2560 × 1600` | **`853.3 × 533.3`** | **`true`**（533 < 690）|
| `onemore_fold`（折叠屏竖）| **`500`** | **`3.125`** | `2224 × 2496` | **`711.7 × 798.7`** | `false`（798.7 ≥ 690）|
| `onemore_tv`（智慧屏）| `480` | `3.0` | `3840 × 2160` | **`1280 × 720`** | `false`（`isTv()` ⇒ 恒 false）|

## 二、来源

```bash
grep -E "hw\.lcd\.(density|single\.(width|height))" \
     ~/.Huawei/Emulator/deployed/<名字>/config.ini
```
`Bp.update()` 里用的是 `px2vp(窗口 px)` ⇒ 就是 `px ÷ (density/160)`。

## 三、这条错在哪、影响多大

- 记录里写 `onemore_fold = 741×832vp` —— 是按 `÷3` 推的，**错了**，真值是 `711.7×798.7`。
- 影响：所有「`832 − 常数`」的算式都偏高 `33vp`。
  这正是 `Simon Says` 我盲拟 `561`/`577` 都不对的**部分原因**
  （另一部分原因是构建被 jetsam 杀，见判据 `3092`）。
- `onemore7` 与 `onemore_tv` 的数字是**对的**（密度确实是 `480`）。

## 四、测量脚本里的环境变量用**像素**，不受此影响

```bash
# onemore7（横屏）
DSH_EMU_INST=onemore7
# onemore_fold（竖屏）
DSH_EMU_INST=onemore_fold SHOT_SCREEN_W=2224 SHOT_SCREEN_H=2496 \
  SHOT_GAME_BOTTOM=2412 SHOT_GESTURE=2480
```
⇒ 这些是 `px`，与 `vp` 无关。**只有「按 vp 推布局」时才需要本表。**

## 五、判据

> **密度不同的设备，vp 必须逐台查，不能套同一个除数。**
> 三台里两台是 `480`、一台是 `500` —— 只要有一台不同，「统一除以 3」就是错的。
