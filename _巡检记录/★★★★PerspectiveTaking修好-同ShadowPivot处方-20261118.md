# `Perspective Taking` 底行被切 —— **修好了**（同 `Shadow Pivot` 的处方，一次成功）

> `2026-11-18 09:27`。**判据 `2901` 的第二次验证：同型结构、同一处方、一次成功。**

## 一、⇒ 判断依据（判据 `2902` 的分支）

**⇒ 它的面板 `Row`（`L337 Row({ space: Space.md })`）里是**两个 `Column`、都带 `layoutWeight(1)`**（网格 + 问题面板）⇒ **与 `GShadowPivot` 同型**（分支 1）。**
**⇒ 而没有 `Silhouette Match` 那种「行里还有带 `layoutWeight` 的 `Text`」的情况。**

## 二、⇒ 改动

**⇒ `L356` 的收尾：**
```diff
- }.width('100%').alignItems(VerticalAlign.Center)
+ }.width('100%').alignItems(VerticalAlign.Center).layoutWeight(1)
```

**⇒ 编译：`BUILD SUCCESSFUL in 3m 53s`。**

## 三、⇒ 证据（两类）

| 指标 | 修前 | 修后 |
|---|---|---|
| `blk` | `3/48px` | **`0/0px`** |
| `lowest` | — | `🏀` `[864,1441][932,1504]` ⇒ 离屏底 **`96px`** |

**⇒ 裁图（`截图-PerspectiveTaking-修好-0926.jpeg` 裁 `y=1280–1600`）：格子底部完整结束、下面留出 `96px` 空间，手势条在更下方。**

## ⇒ 判据 `2901` 现在有两次验证

| 款 | 面板行结构 | 处方 | 结果 |
|---|---|---|---|
| `GShadowPivot` | 两个 `Column`（各 `layoutWeight(1)`）| 行加 `layoutWeight(1)` | ✅ |
| **`Perspective Taking`** | 同上 | 同上 | ✅ |
| `Silhouette Match` | 一个网格 `Column` + 一个带 `layoutWeight` 的 `Text` | 同上 | ❌ |

**⇒ 所以 `2902` 的分支判据成立：**行里只有「都带 `layoutWeight` 的块」时才加得动；混了文字就失效。****
