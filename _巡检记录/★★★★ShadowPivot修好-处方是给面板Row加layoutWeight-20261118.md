# `Shadow Pivot` 底行被切 —— **修好了**（处方：给包住面板的 `Row` 加 `.layoutWeight(1)`）

> `2026-11-18 09:10`。**六款模板缺陷里的第一款，也是第一次真正修好 —— 关键是找到了对的杠杆。**

## 一、⇒ 缺陷

**⇒ 两块 5×5 网格的最底一行被屏沿切掉（截图：裁 `y=1300–1600` 能看到下一行刚开始）。**

## 二、⇒ 试错过程（两个假设，一错一对）

### ❌ 假设 ①：给外层 `Row` 加 `.constraintSize({ maxHeight: Bp.height - 300 })`
**⇒ 编译通过、装机、裁图：**没变**。**

### ✅ 假设 ②：给同一个 `Row` 加 `.layoutWeight(1)`
**⇒ 一次就成了。**

## 三、⇒ 为什么是 `.layoutWeight(1)`（这条最重要）

**⇒ 根容器是：**
```ts
}).width('100%').height('100%').justifyContent(FlexAlign.Start)
```

**⇒ 而包住两块面板的 `Row` 只有 `.width('100%')`、**没有高度** ⇒ 在 `FlexAlign.Start` 下它会**按内容撑高** ⇒ 面板（内部 `layoutWeight(1)` + `aspectRatio(1)`）就把内容高算到超出屏幕。**
**⇒ 加 `.layoutWeight(1)` 后，这个 `Row` 改为**取剩余空间** ⇒ 面板在其中被压缩 ⇒ 全部行都进屏。**

**⇒ 判据 `2901`：`height('100%')` + `FlexAlign.Start` 的根列里，**没有高度的中间容器必须给 `layoutWeight(1)`** —— 否则它按内容撑高、把子项顶出屏。**
**⇒ 而且 `constraintSize` 在这种结构里**无效**（`2900` 已记）—— 它会被「内容撑高」覆盖。两个判据是同一个现象的两面。**

## 四、⇒ 证据

**⇒ 修前（`截图-Shadow_Pivot-085032.jpeg` 裁底部）：最底一行只露上半截、下一行刚开始。**
**⇒ 修后（`截图-ShadowPivot-修好-0910.jpeg`）：两块网格**所有行完整**、以圆角结束；下面正常接选项面板。**

**⚠️ 注意：`blk` 从 `3/72px` 变成了 `3/72px`（没变）—— 它对这款本来就是噪音（`2899`）⇒ **验收只能看图**。**

## ⇒ 剩下五款

**⇒ `Silhouette Match` / `Silhouette Match Ortho` / `Triple Sequence` / `Trace Path` / `Perspective Taking`。**
**⇒ 它们**没有**与 `GShadowPivot` 相同的 `Row` 结构（`grep` 同一模式零命中）⇒ **要各自找「包住网格、却没有高度」的那层容器**，然后同样加 `.layoutWeight(1)`。**
**⇒ 每款的步骤：① 找网格的父容器 ② 看它有没有高度 ③ 没有就加 `layoutWeight(1)` ④ 编译+裁图。**
