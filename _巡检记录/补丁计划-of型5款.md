# 横屏溢出剩余 5 款 · 补丁计划（of 型）

> **只读分析**：未编译、未装包、未碰设备、未改 `.ets`、未 commit。
> 目标：`max_bottom > 1584`（1584 = 533vp × 3px/vp 的屏底）。

---

## 结论速览

| # | 游戏 | 最底块 | 溢出主因 | **判定** |
|---|---|---|---|---|
| 1 | `GRoomInspector` | `Text(this.msg)`（重开已隐藏）| 两条**静态说明行** + 两个 3×4 网格 | ✅ **能修**（手段①）|
| 2 | `GSymbolDigitAssoc` | 长提示句 | **hero 写死 `.height(120)`** | ✅ **能修**（①+固定高降档）|
| 3 | `GVocabularyBuilder` | 长提示句 | 题干卡 padding + 4 选项 | ✅ **能修**（①+②）|
| 4 | `GWordGridConnection` | 长提示句（但**盘面才是罪魁**）| **4×4 盘面 `.aspectRatio(1)` 按宽度撑高 ≈ 800vp** | ❌ **只能重排**（限宽）|
| 5 | `GWordSnakeTrail` | 长提示句（同上）| **8×8 盘面 ≈ 810vp** | ❌ **只能重排**（限宽）|

**⇒ 3 款能靠「删重复说明 + 压固定高」修好；2 款必须给盘面加宽度上限。**

---

## 共用前提

**短屏预算 = 343vp**（判据 1826：`Bp.height − 190` = 533 − 190）

**常量**（`core/Design.ets`）

| 项 | 值 |
|---|---|
| `Space.xxs / xs / sm / md` | 2 / 6 / 10 / 16 |
| `FontSize.xxs / xs / sm / md / lg / xl / hero` | 12 / 13 / 14 / 16 / 18 / 20 / 36 |
| `HintBar.barHeight` | 38 |
| `Bp.isShort()` | 高度 < 690（横向 533 **必为 true**）✓ |
| `Cell.of(N)` @533 横向 | ≈ **N × 0.95**（1.12 平板缩放 × 0.85 矮屏压缩）|

> ⚠️ **下文的 vp 数字是估算**（行高按 `fontSize × 1.2`，`Cell.of` 按 0.95 折算）。
> 我没有编译也没有真机，**不能给实测值**。但结论不依赖精确值 ——
> 因为每款的**结构性主因**（固定 120vp / 盘面按宽度撑高）是代码里直接看得见的。

---

## ① `GRoomInspector.ets`（397 行 · COLS=4 ROWS=3）

### 现状：竖向块清单（估算 vp）

| 块 | 行 | 高 | 备注 |
|---|---|---:|---|
| DemoBar | 296 | 0 | 未演示时 0 |
| HintBar | 297 | 38 | |
| 统计行（找到/失误/剩余）| 305 | 47 | padding 12 + 两行文字 33 + space 2 |
| **`Text('🔍 原样')`** | **325** | **14** | ⬅ **静态说明** |
| 上盘 3×4 | 326 | 117 | padding 12 + 3×31 + 2×6 间距 |
| **`Text('❗ 找不同 · 点下面这间')`** | **349** | **14** | ⬅ **静态说明** |
| 下盘 3×4 | 350 | 117 | 同 |
| `Text(this.msg)` | 372 | 17 | |
| Button 重开 | 375 | 0 | **已 `isShort` 隐藏** ✓ |
| Column `space: xxs` × 6 | — | 12 | |
| **合计** | | **≈376** | **超 343 约 33** |

### 最底块

**`Text(this.msg)`（第 372 行）** —— 是**控件文案**（本局提示），不能删。
重开按钮已经隐藏了，所以再往上就是那两条**静态说明行**。

### 建议

**手段① 隐藏两条静态说明**（它们的价值是「第一次玩的人看一眼」，矮屏上玩家已经在玩了）：

- L325 `🔍 原样` → 说明「上图是原样」
- L349 `❗ 找不同 · 点下面这间` → 说明「下图是改过的」

两条都是**纯说明**，隐藏不影响任何操作。

**收益**：−14 −14 −2×2(间距) = **−32** ⇒ ≈**344**，**刚好卡线**。
**⇒ 建议顺手再压一点**：两个盘面的内部行距 `Space.xxs`（2）已经很小；把 `Cell.of(32)` 降到 `Cell.of(30)` ⇒ 每格 −2，6 行 ⇒ **−12** ⇒ ≈332 ✓ 稳妥。

### 精确 diff

**补丁 1-A**（L325）
```diff
-      Text(TG('🔍 原样')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
+      Text(TG('🔍 原样')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```

**补丁 1-B**（L349）
```diff
-      Text(TG('❗ 找不同 · 点下面这间')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
+      Text(TG('❗ 找不同 · 点下面这间')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```

**补丁 1-C**（L331 / L355，两处同串，需分别改）
```diff
-      }.layoutWeight(1).height(Cell.of(32))
+      }.layoutWeight(1).height(Cell.of(30))
```
> ⚠️ 这个串在文件里出现 **2 次**（331 / 355），`edit` 要么带上下文锚点、要么用 `replace_all`。

---

## ② `GSymbolDigitAssoc.ets`（356 行）

### 现状（估算 vp）

| 块 | 行 | 高 | 备注 |
|---|---|---:|---|
| HintBar | 276 | 38 | |
| 符号对照表 6 格 | 284 | 29 | `Cell.of(30)` |
| 统计行（题号/答对/用时）| 290 | 58 | padding `sm`×2=20 + 两行 |
| **hero 符号** | **306-307** | **120** | ⬅ **写死 `.height(120)`** |
| `Text(this.msg)` | 309 | 17 | |
| 选项盘 3×3 | 311 | 113 | 3×31 + 2×10 间距 |
| Button 重开 | 335 | 0 | 已隐藏 ✓ |
| **`Text('提示：先扫一眼对照表…')`** | **344** | **14** | ⬅ 静态长句 |
| Column `space: xxs` × 6 | — | 12 | |
| **合计** | | **≈401** | **超 343 约 58** |

### 最底块

**`Text(TG('提示：先扫一眼对照表再点；同一个符号不会连着出现'))`（L344）** —— 纯静态说明。
但**只删它不够**（−16 只到 385）。

### 建议

**主因是 hero 的 `.height(120)`** —— 一个 36 号的大符号占了 120vp（预算的 35%）。

1. **hero 矮屏降档**：`120 → 76` ⇒ **−44**
2. **隐藏 L344 提示** ⇒ **−16**
3. 合计 **−60** ⇒ ≈**341** ✓

> 为什么 76：36 号字本身约 43vp 高，76 仍留 33vp 余量（视觉不挤），且比 120 省 44。
> 若真机上还差一点，可再降到 `64`。

### 精确 diff

**补丁 2-A**（L307）
```diff
-        .textAlign(TextAlign.Center).width('100%').height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
+        .textAlign(TextAlign.Center).width('100%').height(Bp.isShort() ? 76 : 120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
```

**补丁 2-B**（L344）
```diff
       Text(TG('提示：先扫一眼对照表再点；同一个符号不会连着出现'))
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```
> 这行原本没有链式属性，直接新增一行即可。

---

## ③ `GVocabularyBuilder.ets`（360 行）

### 现状（估算 vp）

| 块 | 行 | 高 | 备注 |
|---|---|---:|---|
| HintBar | 318 起 | 38 | |
| 顶部行（❤×生命 / 题号 / 得分）| 314 | 29 | |
| 题干卡（gloss + 词根）| 315-317 | 79 | padding `md`×2 = 32 + 两行 41 + space 6 |
| 选项列（4 个）| 318-321 | 154 | 4×31 + 3×10 间距 |
| Row(msg…) | 328 | 17 | Button 已隐藏 ✓ |
| **`Text('提示：un- 表否定…')`** | **336** | **14** | ⬅ 静态长句 |
| Column `space: xxs` × 5 | — | 10 | |
| **合计** | | **≈341** | **贴线，任何换行就溢出** |

### 最底块

**`Text(TG('提示：un- 表否定，-ness 变名词，-ly 变副词'))`（L336）** —— 纯静态说明。

### 建议

1. **隐藏 L336** ⇒ −16
2. **选项列间距 `Space.sm` → `Space.xs`**（L318 的 `Column({ space: Space.sm })`）⇒ 3 个间隙 −12
3. 合计 **−28** ⇒ ≈**313** ✓ 有 30vp 余量

### 精确 diff

**补丁 3-A**（L336）
```diff
       Text(TG('提示：un- 表否定，-ness 变名词，-ly 变副词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```
> 原文该行还有后续属性（`width('100%')` 等），**追加一行 `.visibility` 即可**，不必改原行。

**补丁 3-B**（L318）
```diff
-      Column({ space: Space.sm }) {
+      Column({ space: Bp.isShort() ? Space.xs : Space.sm }) {
```
> ⚠️ `Column({ space: Space.sm })` 在文件里可能不止一处，**改前先确认唯一性**（我数到 1 处，但建议 `edit` 报错时再补上下文）。

---

## ④ `GWordGridConnection.ets`（383 行）—— **只能重排**

### 现状（估算 vp）

| 块 | 行 | 高 | 备注 |
|---|---|---:|---|
| HintBar | ~340 | 38 | |
| 统计行（词数/得分）| ~343 | 47 | |
| **盘面 `diffTotal × diffTotal`** | **349-360** | **≈800** | ⬅ **罪魁** |
| `Text(this.msg)` | 361 | 17 | |
| Button 重开 | 365 | 0 | 已隐藏 ✓ |
| `Text('提示：8 对同义词…')` | 374 | 14 | |

### 最底块（渲染上）

`Text('提示：8 对同义词混在 16 格里；连错扣分，错满 0 次结束')`（L374）

### 🔴 但它不是主因

**盘面格子是：**
```ts
.layoutWeight(1).aspectRatio(1)
```
**⇒ 每格是正方形，边长 = 盘宽 / diffTotal，8 行/4 行叠起来就是 800vp 量级。**

按 813vp 可用宽、4×4：每格 ≈ `(813 − 3×6)/4 ≈ 199` ⇒ 盘面 **≈ 4×199 + 3×6 ≈ 814vp**。
**光这一块就是预算（343）的 2.4 倍。删提示行（−16）毫无意义。**

### 建议：**给盘面加宽度上限**（唯一有效手段）

盘面是「宽度驱动高度」⇒ **限宽就是限高**。这是项目里已有的成熟做法
（`GGo9.boardMax()` 用 `constraintSize({ maxWidth: ... })`，`GBreakout` 用 `aspectRatio(1)`）。

**取 300vp**：`(300−18)/4 ≈ 70`/格 ⇒ 盘面 ≈ **4×70 + 18 ≈ 298vp**（预算 343，留 45 给其余块）✓

### 精确 diff

**补丁 4-A**（L360，加宽度上限）
```diff
         }, (r: number) => 'r' + r)
-      }.width('100%')
+      }.width('100%').constraintSize({ maxWidth: Bp.isShort() ? 300 : 9999 })
       Text(this.msg).fontSize(FontSize.sm)
```

**补丁 4-B**（L374，顺手隐藏提示）
```diff
       Text(TG2('提示：8 对同义词混在 16 格里；连错扣分，错满 {0} 次结束', MAX_MISS))
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```

---

## ⑤ `GWordSnakeTrail.ets`（417 行）—— **只能重排**

### 现状（估算 vp）

| 块 | 行 | 高 | 备注 |
|---|---|---:|---|
| HintBar | ~348 | 38 | |
| 三张状态卡 | 346-354 | 55 | |
| 目标/得分行 | 356 | 18 | |
| **盘面 8×8** | **357-363** | **≈810** | ⬅ **罪魁** |
| `Text(this.msg)` | 364 | 17 | |
| 方向键区（↑←↓→ + 重开）| 367-395 | ≈46 | 重开已隐藏，方向键仍在 |
| `Text('提示：吃错字母…')` | 407 | 14 | |

### 最底块（渲染上）

`Text(TG('提示：吃错字母、撞墙、咬自己都扣一条命'))`（L407）

### 🔴 同上，主因是盘面

```ts
.layoutWeight(1).aspectRatio(1)
```
**8×8**，每格 ≈ `(813 − 7×6)/8 ≈ 96` ⇒ 盘面 **≈ 8×96 + 7×6 ≈ 810vp**。

### 建议：**限宽到 280**

`(280 − 42)/8 ≈ 30`/格 ⇒ 盘面 ≈ **8×30 + 42 ≈ 282vp** ✓
（格子 30vp 对 8×8 的字母盘还算可点；项目里 `Cell.tap` 底线是 44，但**这是棋盘不是按钮**，
且全库已有大量 30 左右的格子 —— 与「可点格 44」的规矩不冲突，因为棋盘本身是整体触控面）

### 精确 diff

**补丁 5-A**（L363）
```diff
         }, (r: number) => 'r' + r)
-      }.width('100%')
+      }.width('100%').constraintSize({ maxWidth: Bp.isShort() ? 280 : 9999 })
       Text(this.msg).fontSize(FontSize.sm)
```

**补丁 5-B**（L407）
```diff
       Text(TG('提示：吃错字母、撞墙、咬自己都扣一条命'))
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```

---

## 汇总：7 个补丁，按文件

| 文件 | 补丁 | 行 | 手段 | 预计省 |
|---|---|---|---:|---:|
| `GRoomInspector` | 1-A / 1-B | 325 / 349 | ① 隐藏静态说明 | −32 |
| `GRoomInspector` | 1-C | 331 / 355 | ② 格子 32→30 | −12 |
| `GSymbolDigitAssoc` | 2-A | 307 | **固定高降档** 120→76 | −44 |
| `GSymbolDigitAssoc` | 2-B | 344 | ① 隐藏提示 | −16 |
| `GVocabularyBuilder` | 3-A | 336 | ① 隐藏提示 | −16 |
| `GVocabularyBuilder` | 3-B | 318 | ③ 间距 sm→xs | −12 |
| `GWordGridConnection` | 4-A | 360 | **④ 限宽 300** | **−516** |
| `GWordGridConnection` | 4-B | 374 | ① 隐藏提示 | −16 |
| `GWordSnakeTrail` | 5-A | 363 | **④ 限宽 280** | **−528** |
| `GWordSnakeTrail` | 5-B | 407 | ① 隐藏提示 | −16 |

**9 处改动，5 个文件。**

### 锚点唯一性（我已逐个验证 = 1 次）

| 文件 | 锚点 | 命中 |
|---|---|---:|
| `GWordGridConnection.ets` | `}, (r: number) => 'r' + r)\n      }.width('100%')\n      Text(this.msg)` | **1** ✅ |
| `GWordSnakeTrail.ets` | 同上 | **1** ✅ |
| `GRoomInspector.ets` | `Text(TG('🔍 原样'))…` 整行 | **1** ✅ |
| `GRoomInspector.ets` | `Text(TG('❗ 找不同 · 点下面这间')).fontSize…` | **1** ✅ |
| `GSymbolDigitAssoc.ets` | `.textAlign(TextAlign.Center).width('100%').height(120).backgroundColor(…` | **1** ✅ |
| `GSymbolDigitAssoc.ets` | `Text(TG('提示：先扫一眼…'))` | **1** ✅ |
| `GVocabularyBuilder.ets` | `Text(TG('提示：un- 表否定…')).fontSize…` | **1** ✅ |
| `GWordGridConnection.ets` | `Text(TG2('提示：8 对同义词…', MAX_MISS))` | **1** ✅ |
| `GWordSnakeTrail.ets` | `Text(TG('提示：吃错字母…'))` | **1** ✅ |

> ⚠️ 补丁 1-C 的 `}.layoutWeight(1).height(Cell.of(32))` 出现 **2 次**，需 `replace_all` 或带行号上下文。

---

## 风险与注意

| 项 | 说明 |
|---|---|
| **估算误差** | 我的 vp 是算的（`fontSize×1.2`、`Cell.of×0.95`），**没编译没真机**。留的余量按 20~30vp 设计 |
| **`Bp.isShort()` 在横屏为 true** | 已验证（阈值 690，横向 533）✓ |
| **`Bp` 已导入** | 5 个文件全部 `import { Bp }` ✓（我逐个查过）|
| **限宽后盘面会居中还是靠左** | 外层是 `Column` 默认水平居中 ⇒ 居中 ✓ |
| **8×8 盘限到 280 后格子 30vp** | 对字母盘可接受；若嫌小可放到 320（盘面 ≈322vp，仍 < 343）|
| **④ 限宽是最后手段** | 但这两款**没有别的办法** —— 盘面由宽度驱动高度，不让它缩就必然溢出 |
