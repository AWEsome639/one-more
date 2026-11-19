# `Simon Says` 判定：**真缺陷（`2.8%`）· 高度驱动 · 改法明确但我没敢盲插**

## 一、判定：真缺陷

台账 `2026-11-19T17:37:24 OK`：
```
lowest='🐸' [720,1192][825,1291]   blk=2/48px   blkh=844px
```
⇒ `blkh=844px` 与 `Magnets`(`880`)/`Mandelbrot`(`844`) 同签名，我**先按假阳性怀疑**。
但底部裁图**否掉了**这个怀疑：

> 两块大 pad（绿 / 红）的**底边越过红线、一直画到屏幕底** ⇒ **圆角被切**

⇒ 严重度 `24 / 844 =` **`2.8%`** ⇒ **真缺陷**，只是轻微。**不是画布通栏**（`Wireframe 3D` 那种底部是空的）。

## 二、★ 但它和前面几款**机制相反**

| 款 | 定尺寸的方式 | `constraintSize(maxHeight)` 有用吗 |
|---|---|---|
| `Shadow Pivot` / `Memory` | `.layoutWeight(1)` 分配宽 ⇒ `aspectRatio` 定高 | ❌ 被忽略（`3030` 实证 `5` 次）|
| **`Simon Says`** | **`.height('100%')` 撑满父行** ⇒ `aspectRatio` 定宽 | ✅ **应该有效** |

`GSimonSays.ets` 里 pad 是：
```typescript
Stack() { … }.height('100%').aspectRatio(1)   // ← 高先定、宽随之
```
⇒ 所以**限住「行」的高度**就能把 pad 压小（宽度跟着缩）。
⇒ 与 `Gravity Sort`（父定宽 ⇒ 限高有效）**同侧**，与 `Shadow Pivot`（`layoutWeight` 定宽）**反侧**。

## 三、版面树（已量）

```
d6 Column  y=756..1600  h=844   x= 60..2500  w=2440
d7 Row     y=756..1600  h=844   x=280..2280  w=2000
d8 Stack   y=749..1600  h=851   x=280..1265  w= 985   ← pad 1（985×851）
d8 Stack   y=749..1600  h=851   x=1295..2280 w= 985   ← pad 2
```
⇒ pad 行 `h=844px`（`281vp`）；要到 `820px`（`273vp`）⇒ 省 `25px`。
⇒ 上限取 `Bp.height − 260 = 273vp` ⇒ 横屏有效、竖屏用 `9999`（不设限）。

## 四、为什么我没应用（如实）

我写了个自动插入脚本，它匹配 `Row` 后的 `.width('100%')` 并插入 `constraintSize`，
但**插到了 `4` 处**（`:452` / `:488` / `:531` / `:567`），其中 `:488` 与 `:567`
很可能落在**pad 自己**（`.height('100%')` 那行之后）而不是「行」上。

⇒ **打在 pad 上会截断 pad 自己**（`aspectRatio` 与 `maxHeight` 冲突）⇒ 可能把版面弄坏。
⇒ 而 `Simon Says` 只是 `2.8%` 的轻微切边 ⇒ **不值得拿它冒这个险** ⇒ **已还原、编译通过（`0` 改动）**。

## 五、下一步（精确到行）

只改**两处**：`GSimonSays.ets` 里 pad 行的 `.width('100%')` 收尾 —— 即
- 第一组 pad 行：`:447` 的 `.width('100%')`
- 第二组 pad 行：`:516` 的 `.width('100%')`

各追加：
```typescript
.constraintSize({ maxHeight: Bp.isShort() ? Math.max(200, Bp.height - 260) : 9999 })
```

验证五步（同 `3049`）：编译 → 装机 → 横屏测（期望 `blk=0`、pad 圆角完整）→
**竖屏测**（`9999` 不设限 ⇒ 应完全不变：`blk=72px`、`1.5%`）→ 两张截图都看。

## 六、判据

> **同样是 `aspectRatio`，`constraintSize` 打哪一层取决于「谁先定尺寸」：
> `.height('100%')` 撑满的（高度驱动）⇒ 限行高有效；`layoutWeight` 分配宽的（宽度驱动）⇒ 限高被忽略。**

⇒ 三档已经齐了：
1. **父定宽（`.width('100%')`）** ⇒ 限 `maxHeight` 有效（`Gravity Sort`）或限 `maxWidth`（`Perspective Shift View`）
2. **父定高（`.height('100%')`）** ⇒ **限行高 `maxHeight` 有效**（`Simon Says` 理论上）
3. **`layoutWeight` 分配宽** ⇒ **限高被忽略**（`Shadow Pivot` 实证）

⇒ 推论：**看 pad 那一行写的是 `.width('100%')` 还是 `.height('100%')`，就能判 `constraintSize` 该打在哪**。
