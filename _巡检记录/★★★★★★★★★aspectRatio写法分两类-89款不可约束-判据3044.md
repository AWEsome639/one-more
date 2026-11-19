# 判据 3044：`aspectRatio` 的写法分两类 —— **`89/355` 款在「不可约束」那一类**

## 一、怎么来的

今天 `Shadow Pivot` 上 `5` 次尝试全败，机制查明后我想知道：
**「`layoutWeight` 定宽 + `aspectRatio` 定高 ⇒ `constraintSize` 无效」这是那款特殊，还是一个普遍写法？**

⇒ 扫了全部 `355` 个游戏文件 + `7` 个组件文件，按「`aspectRatio` 所在的**那一行**还写了什么」分类：

| 项 | 数量 | 占比 |
|---|---|---|
| 游戏文件 | **`355`** | — |
| 用 `aspectRatio` | **`160`** | `45%` |
| **同一行 `layoutWeight` + `aspectRatio`** | **`89`** | **`25%`（不可约束类）** |
| **同一行 `width('100%')` + `aspectRatio`** | **`43`** | `12%`（**可约束类**）|
| 用 `constraintSize` 的 | `80` | `23%` |
| **两种写法都有** | **`34`** | 混合，需逐个读 |

## 二、这意味着什么

### ① 我今天的失败不是个案

`Shadow Pivot` 那 `5` 次（`padding` / `margin` / `constraintSize` ×2 / `layoutWeight`）全败 ——
不是因为那款代码写得怪，而是因为**它用的是全库四分之一的写法**：

```typescript
Stack().layoutWeight(1).aspectRatio(1)
//     ↑ 宽由 Row 分配        ↑ 高 = 那个宽 ⇒ constraintSize 拦不住
```

⇒ 任何「缩小这个棋盘」的修法，在这 `89` 款上都会撞同一堵墙。

### ② 能「改常量」修的只有 `43` 款

今天修好的两款（`Gravity Sort`、`Perspective Shift View`）都属可约束类：

```typescript
.width('100%').aspectRatio(1).constraintSize({ maxHeight: ... })   // 能反推宽度 ✅
```

⇒ **`43/355 = 12%`** 的游戏可以用「改一个常量」修版面，其余要么不可约束、要么混合。

### ③ 「混合」那 `34` 款最麻烦

它们**同时**有 `layoutWeight + aspectRatio` 和 `width('100%') + aspectRatio` 的行 ——
「哪一行是那个出问题的元素」必须**逐个读**，不能用统一规则。

## 三、对后面工作的意义

**下次遇到「棋盘太大、放不下」的问题，第一件事不是改，而是先看它属于哪一类：**

| 类 | 判据 | 修法 | 款数 |
|---|---|---|---|
| **A. 可约束** | `aspectRatio` 那行的宽是 `.width('100%')` / 固定值 | 改 `constraintSize` 常量 或 加 `maxWidth` | **`43`** |
| **B. 不可约束** | 宽是 `layoutWeight(n)` 分配的 | **必须动分配宽度那一层**（换固定宽/缩短上下行）⇒ 版面重排 + 人眼 | **`89`** |
| **C. 混合** | 两种行都有 | 先定位出问题的元素属于哪一行 | **`34`** |

⇒ **一个 `grep` 就能分完类，成本约 `10` 秒；不分类就动手，代价是 `Shadow Pivot` 那样的 `5` 次失败。**

## 四、判据

> **一个「修改无效」的结论，先问「它是个例还是这个代码库的普遍写法」。
> 个例说明我读错了那处；普遍写法说明**修法本身选错了**。**

⇒ 四条：
1. **`layoutWeight(n)` + `aspectRatio(x)` 同行 ⇒ 该元素的尺寸不可被 `constraintSize` 约束**
2. **`.width('100%')` + `aspectRatio(x)` 同行 ⇒ 可约束**（`maxHeight`/`maxWidth` 都能反推）
3. **动手前先 `grep` 分类**，`10` 秒的事，能省掉几次全败的尝试
4. **失败三次以上就该怀疑「修法选错了」，而不是「还没试到对的那次」** ——
   今天前 `3` 次失败我归因成「位置不对」，第 `4` 次才想到查机制

## 五、附：本次扫描的可用明细

```
不可约束类 89 个文件（前若干）：
  GSimonCommand.ets · GShadowPivot.ets · GMemory.ets · …
可约束类 43 个文件：
  GGravitySort.ets · GPerspectiveShiftView.ets · …
```
⇒ 需要完整名单时重跑那条扫描（`grep` 三行，不依赖任何状态）。
