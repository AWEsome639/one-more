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

---

## 【`09:40`】`Silhouette Match Ortho` 同处方**变差**（已回滚）

**⇒ 给它 `L289` 的面板 `Row` 加 `.layoutWeight(1)`：**

**⇒ 结果：**面板被推到 `y≈1360` 才开始、大半在屏外** ⇒ **比修前更糟**（修前面板从 `y≈1150` 开始）。**
**⇒ 已回滚。**

### ⇒ 为什么这款会变差（与 `ShadowPivot` 结构差别）

**⇒ `GShadowPivot` 的面板行 = **固定两个** `Column`；
**⇒ `Silhouette Match Ortho` 的面板行 = **`ForEach` 生成的 N 个 `Column`**（每个 `.layoutWeight(1)` 且内含网格 + 下层名 `Text`）。**
**⇒ 给 `ForEach` 外层行加 `layoutWeight` 后，N 个面板先按「行拿到的剩余空间」分配，而**每个面板内部还有 `Text` 要占高** ⇒ 网格被挤到下面、行本身反而缩了。**

**⇒ 判据 `2903`：`layoutWeight(1)` 处方只对**「行内是固定个数、纯 `layoutWeight` 块」**的行有效；行内是 **`ForEach` 生成**（块数随数据变）时要另想办法 —— 因为「行拿多少高」和「每块内部还要分多少高」会打架。**

---

## 【`10:01`】`Trace Path`：收窄宽度**不是杠杆**（已回滚）

**⇒ 它的格子是宽度驱动（`layoutWeight + aspectRatio(1)`）⇒ 试了「收窄网格宽度让高度按比例下降」：**

| 网格宽度 | `blk` | 内容最低点 |
|---|---|---|
| `100%`（原）| `3/48px` | 到屏底 |
| `92%` | **`2/36px`** | 到屏底 |
| `84%` | **`2/48px`** | 到屏底 |

**⇒ **非单调**（`48 → 36 → 48`）⇒ 宽度不是决定性变量，有别的因素在主导（大概率是 `layoutWeight(1)` 的再分配，判据 `2599` 第四次）。**
**⇒ 已 `git checkout` 回滚 `GTracePath`。**

## ⇒ 判据 `2904`

**⇒ 「宽度驱动」的网格，**收窄宽度不等于收窄高度** —— 高度会被父级的 `layoutWeight` 重新分配掉，而且过程非单调。**
**⇒ 遇到这种，**别调百分比**；要么改「谁在 `layoutWeight`」（像 `GShadowPivot` 那样给容器定权），要么接受现状并标注。**

## ⇒ 六款的最终账（`10:01`）

| 款 | 结果 |
|---|---|
| `Shadow Pivot` | ✅ 修好（给面板行加 `layoutWeight(1)`）|
| `Perspective Taking` | ✅ 修好（同上）|
| `Silhouette Match` | ❌ 无效（行内有 `layoutWeight` 文字，`2902`）|
| `Silhouette Match Ortho` | ❌ 变差（`ForEach` 生成的行，`2903`）|
| `Trace Path` | ❌ 宽度不是杠杆（非单调，`2904`）|
| `Triple Sequence` | ⏸ 未动（同为宽度驱动 ⇒ 按 `2904` 不必再试调宽度）|

**⇒ 净结果：`2` 修好 / `4` 待换思路。四条判据（`2901`–`2904`）把「为什么行/不行」说清了。**
