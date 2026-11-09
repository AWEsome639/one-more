# `Number Bonds All` 修好（`1600 → 1514`，`OK`）—— 又是判据 1851

## 为什么上一轮「删重开」没用

**它的格子区是 `layoutWeight(1)`** —— **删掉下面的「重开」后，格子区把腾出的空间吃回去，总高不变**。

**⇒ 判据 1851 的第三次现场**（`FreeCell` 的槽位、`Tetris` 的棋盘、现在 `Number Bonds All` 的格子区）。

## 这一轮两刀

| 刀 | 改动 | 效果 |
|---|---|---|
| ① | **格子区加 `.constraintSize({ maxHeight: Math.max(120, Bp.height − 380) })`** | **给它「上限」，腾出的高度才真的留在下面** |
| ② | **矮屏不渲染「重开」**（页头 ↻ 同动作，判据 1859）| 再省 `46vp` |

**⇒ `1600 → 1514`（`OK`）**

## 判据 1851 的三次现场（值得记住）

| 游戏 | 那个 `layoutWeight(1)` 是谁 | 修法 |
|---|---|---|
| **`FreeCell`** | 4 列牌堆 | 牌高 `30 → 24` + 列 `clip` |
| **`Tetris`** | 棋盘（宽驱动 + `maxHeight`）| `maxHeight` 逐次收紧 |
| **`Number Bonds All`** | **格子区** | **`constraintSize(maxHeight)`** |

**⇒ 「删东西没用」时，先找 `layoutWeight(1)`。**
