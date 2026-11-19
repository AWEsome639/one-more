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

---

## 七、★★ 重大更正：`3055` §二 的机制判断**是错的**（`18:2x`）

### 错在哪

`3055` §二 说「`Simon Says` 的 pad 是 `.height('100%')` 撑满父行 ⇒ 高度驱动 ⇒ 限行高有效」。
**这个读错了行。**

### 实际代码（`GSimonSays.ets:440-455`）

```typescript
          Stack({ alignContent: Alignment.TopEnd }) {   // ← 内层：色盲辅助字母 A~D
          Text(A11y.glyph((0)))
          .fontSize(FontSize.lg)
          …
          }
          .width('100%')      // :447  ← 这是**辅助 Stack** 的宽
          .height('100%')     // :448  ← ★ 这是**辅助 Stack** 的高，不是 pad 的
          .padding(Space.sm)
          .hitTestBehavior(HitTestMode.None)
          }
          .layoutWeight(1)    // :453  ← ★★ pad 自己是这个
          .aspectRatio(1)     // :454
          .backgroundColor(this.lit === (0) ? …)
```

⇒ **pad 的真实写法是 `.layoutWeight(1).aspectRatio(1)`** —— 和我之前判定的
「宽驱动、`constraintSize` 被忽略」那一类**完全相同**，不是高度驱动。

### 所以

| 项 | `3055` 原判断 | **更正** |
|---|---|---|
| `Simon Says` 的机制 | 高度驱动（`.height('100%')`）| ❌ **错** —— 是 `layoutWeight(1)` 宽驱动 |
| `constraintSize(maxHeight)` 打在行上 | 「应该有效」| ❌ **应该无效**（同 `Shadow Pivot`）|
| `3055` §六 的「三档」判据 | 「父定高 ⇒ 限高有效」有 `Simon Says` 作例 | ❌ **这一档没有实例** |

⇒ `3055` §六 的三档**只剩两档有实证**：
1. **父定宽** ⇒ 限 `maxHeight`（`Gravity Sort`）/ 限 `maxWidth`（`Perspective Shift View`）✅
2. **`layoutWeight` 分配宽** ⇒ 限高被忽略（`Shadow Pivot` `5` 次）✅
3. ~~父定高 ⇒ 限行高有效~~ ⇒ **无实例，撤回**

### 下一步（改法回到 `Shadow Pivot` 那一类）

⇒ 要修 `Simon Says`，得**动「分配宽度的那一层」**：
它外面是 `Row({ space: Space.sm })` 且 `.width('100%')`（`:447` 附近那层是辅助 Stack，
真正的 pad 行 `Row` 在 `:436` / `:505`，它们的 `.width('100%')` 才是要限的那层）。

⇒ 但 `3053` 说过：`layoutWeight` 类的改动**要同时考虑兄弟会不会重叠**。
   而 `Simon Says` 只是 `2.8%` 的轻微切边 ⇒ **优先级最低**。

## 八、判据（更正后）

> **判断「这一行属于哪个元素」，必须从属性链的**收尾 `}` **往上读，不能从属性名往下猜。**
> `.width('100%').height('100%')` 挨在一起时，它们属于**最近的那个 `{`**，很可能不是你正在看的那个元素。

⇒ 三条：
1. **读 `layoutWeight`/`aspectRatio` 在哪** —— 那才是「这个元素怎么定尺寸」的真凭据
2. **`.height('100%')` 单独出现时格外小心** —— 它常属于内层画布/遮罩，不属于外层容器
3. **纠错要写进同一个判据文件**（本节就是这样）—— 别让错规则在别处继续被引用
