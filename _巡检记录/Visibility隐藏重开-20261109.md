# 用 `.visibility(Visibility.None)` 在矮屏隐藏「重开」：**12 款里 6 款达标**

## 为什么用 `Visibility.None` 而不是 `if`

**`if (!Bp.isShort()) { ... }` 要「找到这个 `Button` 链的结尾去补 `}`」** ——
**在我这里是「正则找链尾」= 判据 1863 那个坑（批量改布局编译失败）。**

**`.visibility(Visibility.None)` 只加一行、插在 `Button(...)` 后面即可**（链式修饰符顺序无关），
**且 `None` 会把它从布局里完全摘掉（`Hidden` 才会占位）。**

## 结果（12 款，各 1 行）

### 达标 / 接近达标

| 游戏 | 改前 | 改后 |
|---|---|---|
| **`d2 Attention`** | `1600` | **`1489`（`OK`）** |
| **`Counting Span`** | `1600` | **`1523`** |
| **`Mental Calendar`** | `1600` | **`1543`** |
| **`Binary Scale Balance`** | `1600` | **`1543`** |
| **`Sequence Stack`** | `1600` | **`1549`** |
| **`Unit Converter Pro`** | `1600` | **`1558`** |

### 没动（仍 `1600`，6 款）

`Mahjong Solitaire`（`lowest='提示'`）/ `Binary Puzzle`（`'清空'`）/ `Algebraic Balance`（`'提示'`）/
`Binary Code`（`'8'`）/ `Target Number`（`'8 × (3 + 9)'`）/ `Tents And Trees`（`'1'`）

**⇒ 这 6 款的最底部不是「重开」**，是**另一行控件/文字**（提示条、数字键盘、算式）。

## 判据 1867（立）

> **「矮屏隐藏某个按钮」优先用 `.visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)`，不要用 `if (...)` 包块。**
> **理由：① 只加一行，不用找链尾（`if` 包块要配对 `}`，正是批量改布局翻车的原因）**
> **② `None` 不占布局（`Hidden` 会占位，等于没省）**
> **③ 可逆：删一行即可**

**依据**：12 款各 1 行、一次编译通过、6 款实测改善（`d2 Attention` 直接 `OK`）。
