# ★★★★★★ dump 定死根因：`layoutWeight` 覆盖了父容器 `.width()` 与 `aspectRatio()`

> `2026-11-15 07:37` 用新的 `ONEMORE_DUMP=1` 抓到 `Magnets` 与 `Divided Attention` 的**全部节点**。

## 一、⇒ `Magnets` 的 dump（HAP `46553200`，作者原文 + `maxWidth:50`）

```
y2=1600  d=6  Column  x=60-2500    h=880      ← 棋盘区（可用高 293vp，与作者注释一致）
y2=1600  d=7  Row     x=90-2470    h=288      ← 棋盘 Row，宽 2380px = 793vp
y2=1600  d=8  Stack   x=90-634     h=288      ← 格子1：544 宽 × 288 高
y2=1600  d=8  Stack   x=652-1196   h=288      ← 格子2
y2=1600  d=8  Stack   x=1214-1758  h=288
y2=1600  d=8  Stack   x=1776-2320  h=288
```

**⇒ 三条硬事实：**

1. **棋盘 `Row` 宽 `2380px` = `793vp`** —— 而代码里 `.width(Math.min(..., 142vp))` 应得 `426px` ⇒ **父容器的 `.width()` 完全没生效**。
2. **每个格子 `544px` 宽** —— 应 `(142-44-间隔)/4 ≈ 23vp = 69px` ⇒ **`maxWidth: 50` 也没生效**。
3. **格子 `544 × 288` 不是正方形** ⇒ **`aspectRatio(1)` 也没生效**。

**⇒ 三者同时失效，唯一共同解释：这些子元素都带 `.layoutWeight(1)`，而 **`layoutWeight` 会覆盖父容器给的固定尺寸与 `aspectRatio`**。**

**⇒ 所以「加 `maxWidth`」这条路（作者试过、我今天又试过）在这个结构里**注定无效** —— 它被 `layoutWeight` 压过。**

## 二、⇒ `Divided Attention` 的 dump

```
y2=1600  d=6  Row     x=60-2500    h=875
y2=1600  d=7  Column  x=60-1256    h=1085   ← 左游戏区：高 1085 > 父 Row 的 875
y2=1600  d=7  Column  x=1304-2500  h=1085   ← 右游戏区：同上
```

**⇒ 两个 `Column` 各 `1085px` 高、却在 `875px` 的 `Row` 里 ⇒ 溢出 `210px`、被裁剪。**
**⇒ 同样是因为它们带 `.layoutWeight(1).aspectRatio(0.86)` ⇒ 宽度被父容器撑满、高度跟 `aspectRatio` 越界。**

## 三、⇒ 正解方向（下一步做，要一次编译）

**去掉棋盘/列/格子上的 `.layoutWeight(1)`，改成**显式尺寸**：**

```typescript
// 不要这样：layoutWeight 会覆盖一切外部约束
.layoutWeight(1).aspectRatio(1).constraintSize({ maxWidth: 50 })

// 而要这样：由外层算出格子边长，直接给死尺寸
const CELL = Math.floor((Bp.height - 375 - CLUE_W) / 4)   // 例如 ~45vp
.width(CELL).height(CELL)
```

**⇒ 棋盘 `Row` 的宽度则改为 `4*CELL + CLUE_W + 间隔`，**不再依赖 `min()` 猜测**。**

## ⇒ 判据（`2674`）

**`layoutWeight(1)` 会**覆盖**父容器的 `.width()`、子元素的 `aspectRatio()` 与 `constraintSize()` —— 三者实测同时失效（`Magnets` dump：`Row` 793vp、格子 544×288）。**
**⇒ 判据：只要看到「父容器设了尺寸但子元素不遵守」，先查子元素有没有 `layoutWeight`；有 ⇒ 外部约束全部作废，
    必须改成显式尺寸（`.width(x).height(y)`）或换 `Flex` 布局。**

## ⇒ 判据（`2675`）

**作者注释里写的「加 maxWidth 就能收住」**在他的环境下可能成立、在现在不成立** —— 今天实测 `maxWidth:50` 完全无效。**
**⇒ 判据：注释是「作者当时观察到的行为」，不是永恒规格；**改之前先用 dump 确认那个机制现在还在不在**。**
