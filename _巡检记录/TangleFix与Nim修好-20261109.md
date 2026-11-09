# `Tangle Fix`（解缠）与 `Nim`（尼姆博弈）修好

## 结果

| 游戏 | 修前 | 修后 | 判定 |
|---|---|---|---|
| **`Tangle Fix`** | **`1592`（底部彩条被切一整行）** | **`1545`** | **六行彩条全部可见**（`TIGHT`，最后一贴边但完整）|
| **`Nim`** | **`1600`（第 3 堆按钮被切）** | **`1351`** | **`OK`** ✓ |

截图：`截图-Tangle_Fix-121734.jpeg` / `截图-Nim-121748.jpeg`

## `Tangle Fix`：又是「`layoutWeight(1) + aspectRatio(1)` 的乘法」

**原来**：6 个圆各 `.layoutWeight(1).aspectRatio(1)` ⇒ **直径 = 行宽 / 6 ≈ `139vp`**（判据 1822 乘法形态）
**⇒ 一行圆吃掉 `139vp`**，把下方「彩色横条」面板整行挤出屏。

**改成**：`.width(Cell.of(56)).height(Cell.of(56))` + 行 `.justifyContent(SpaceAround)`
**⇒ 省 `~83vp`（`249px`）**。

## `Nim`：统计卡竖排 → 横排 + 根间隙降档

**三张卡（剩余石子 / 你的步数 / 轮到）竖排两行 → 横排一行**（判据 1857）+ 根 `space md→xs`
**⇒ 三堆石子按钮第一次「全在屏内」**。

## 今晚「横屏」已修 10 款

`Fibonacci Merge` / `Double Trouble` / `Algebraic Inequality Solver` / `FreeCell` /
`Go 9x9` / `Compound Connect` / `Vector Dot Product` / `Sokoban` / `Tetris` / **`Tangle Fix`** / **`Nim`**

（**其中 4 款的根因都是「`layoutWeight(1)+aspectRatio(1)` 的乘法」，2 款的根因是「统计卡竖排两行」**）

**⇒ 这两个模式已能「看扫描结果就预判修法」**：`lowest` 是「底部按钮/说明」+ `max_bottom=1600` ⇒ 先查这两条。
