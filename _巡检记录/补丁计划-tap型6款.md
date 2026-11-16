# 补丁计划：塌屏 6 款（tap 型 / 盘面溢出）—— 只读分析，未改任何 .ets

> 执行：verifier-eng2 ｜ 只读（不编译、不装包、不碰模拟器、不 commit）
> 依据：`pages/GameHost.ets` 游戏区高度上限（约 3456 行）
> 数据：`853×533` 时游戏区可用高 **343vp**（`Bp.height − 190`），注释实测 **352vp**（533−66 状态栏−45 顶栏−20 padding−38 HintBar）

---

## 0. ⚠️ 先纠一个前提（影响 5/6 款的修法）

你说「这 6 款的盘面都用 `Cell.tap`」——**逐行核对后只有 1 款是**：

| 文件 | 盘面格子实际写法 | 缩尺寸有效？ |
|---|---|---|
| `GColorMazeNav.ets:403` | `.layoutWeight(1).height(Cell.tap(32))` → 实高 **44** | ❌ 无效（`Cell.tap` 下限 44）|
| `GMazeNav3d.ets:485-502` | `.layoutWeight(1).aspectRatio(1)` + 容器 `maxHeight:'70%'` | ✅ **有效** |
| `GBlockStackingPhysics.ets:314` | `.height(Cell.of(34))` | ✅ **有效** |
| `GBoxCompletion.ets:369` | `.layoutWeight(1).height(Cell.of(62))` | ✅ **有效** |
| `GTennerGrid.ets:609-638` | `.layoutWeight(1).aspectRatio(1)` + 宽度上限 `Bp.height-360` | ✅ **有效** |
| `GTentsAndTrees.ets:638-652,683` | `.layoutWeight(1).aspectRatio(1)`，容器**无上限** | ✅ **有效（缺上限）** |

⇒ **只有 GColorMazeNav 必须「删块/改难度」；其余 5 款「缩尺寸/加上限」就够**（本来就没做，不是不能做）。

**另一个共用事实**：6 款的 build 都是 `Column(...).height('100%').justifyContent(FlexAlign.Start)` ⇒
**内容超高时从底部被切**（不是整体压缩），所以症状永远是「底部那一行没了」。

---

## 1. GColorMazeNav.ets（唯一真 `Cell.tap`）

**① 盘面容器有 `layoutWeight(1)` 吗？**
**没有。** 盘面是 `Column({ space: Space.xs })`（约 387 行），无 width/height 上限；
格子 `Stack{}.layoutWeight(1).height(Cell.tap(32))`（403 行）⇒ 实高 44，**缩不动**。

**② 最底下那块是什么？**
**方向键行 `Row({ space: Space.xs })`**（422 行起：`↑ ↓ ← →` 四个 Button，各 `.height(Cell.of(32))`；行内 `重开` 已按判据 1880 隐藏）。

**③ 高度账（6×6）**
| 块 | 高度 |
|---|---|
| HintBar | 38 |
| 状态行 `步数/脚下/终点` | ~20 |
| 棋盘 6 行 × 44 | **264** |
| `Text(this.note)` | ~20 |
| 方向键行 | 32 |
| Column 间距 5×~6 | ~30 |
| **合计** | **~404 vs 343 ⇒ 超 61**（方向键被切 ✓ 与你说的一致）|

**8×8（困难档）**：棋盘 352 ⇒ 合计 ~492 ⇒ **超 149，删块也救不回**。

**④ 补丁 A（6×6 可用；纯删块，两条）**
```diff
--- a/entry/src/main/ets/games/GColorMazeNav.ets
+++ b/entry/src/main/ets/games/GColorMazeNav.ets
@@ -418,1 +418,2 @@
- Text(this.note).fontSize(FontSize.sm)
+ Text(this.note).fontSize(FontSize.sm)
+   .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
@@ -422,1 +422,2 @@
- Row({ space: Space.xs }) {
+ Row({ space: Space.xs }) {
+   // （Row 的修饰符在链尾，见下面第二处）
@@ -468,1 +468,2 @@
-    }).width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
+    }).width('100%')
+      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
+  }.width('100%').height('100%').justifyContent(FlexAlign.Start)
```
> ⚠️ 第二处（方向键 Row 的隐藏）要加在该 Row 的**链尾**：目前它的 `}` 与 `.onTouch(...)` 之间没有修饰符，
> 最稳的写法是给 Row 的第一个 Button 前插入一行 ``.visibility(...)` 不行（修饰符不能前置），
> **建议改法**：把方向键 Row 用 `if (!Bp.isShort()) { ... }` 包起来（大括号配对风险最低的另一条路）。

**④ 补丁 A'（更稳，不碰大括号：整行 hide）**
```diff
--- a/entry/src/main/ets/games/GColorMazeNav.ets
+++ b/entry/src/main/ets/games/GColorMazeNav.ets
@@ -422,1 +422,1 @@
- Row({ space: Space.xs }) {
+ Row({ space: Space.xs }) {
+   // 在 Row 的最后一个 Button 之后、Row 的 `}` 之前无修饰符可加 ⇒ 改在链尾加：
```
（实测项目里同类改法都走「链尾加 `.visibility(...)`」；本文件该 Row 的链尾在 468 行 `}` 之后，
但那一行同时收了外层 `Column` 的 `}`，**建议由能编译的人来做这一步**，我只标注位置。）

**⑤ 8×8 的补丁 B（必须改难度或改格子判据）**
```diff
--- a/entry/src/main/ets/games/GColorMazeNav.ets
+++ b/entry/src/main/ets/games/GColorMazeNav.ets
@@ -117,1 +117,1 @@
-  @State private diffTotal: number = GameDiff.sizeNow(6);
+  @State private diffTotal: number = Bp.isShort() ? Math.min(6, GameDiff.sizeNow(6)) : GameDiff.sizeNow(6);
@@ -147,1 +147,1 @@
-    this.diffTotal = GameDiff.sizeNow(6);
+    this.diffTotal = Bp.isShort() ? Math.min(6, GameDiff.sizeNow(6)) : GameDiff.sizeNow(6);
```
> 代价：矮屏上困难档只有 6×6（棋力降一点，但**盘面完整可见**）。
> 备选：把 `Cell.tap(32)` 改成 `Cell.of(36)`（放弃 44 触控下限）→ 8×8 只需 288，但**这是产品决策**，我没写进补丁。

---

## 2. GMazeNav3d.ets

**① 盘面容器有 `layoutWeight(1)` 吗？** **没有**（横向的 `layoutWeight(1)` 在状态行三个 Column 上）。
盘面：`Column{...}.width('100%').aspectRatio(1).constraintSize({ maxHeight: '70%' })`（**502 行**）。

**② 最底下那块是什么？**
方向键 `Row`（`← ↑ ↓ →`，`tryMove`），其上是「层切换」Row（`▼ 下层 / ▲ 上层`），再上才是盘面；
`Button(重开)` 已按判据 1880 隐藏。

**③ 高度账**：HintBar 38 + 状态行 44 + 说明 20 + 盘面 **0.7×343=240** + 层切换 32 + 方向键 32 + 间距 ~28 = **434 vs 343 ⇒ 超 91**。

**④ 补丁（一行，效果最大）**
```diff
--- a/entry/src/main/ets/games/GMazeNav3d.ets
+++ b/entry/src/main/ets/games/GMazeNav3d.ets
@@ -502,1 +502,1 @@
-      .constraintSize({ maxHeight: '70%' })
+      .constraintSize({ maxHeight: Bp.isShort() ? '46%' : '70%' })
```
⇒ 盘面 240 → 158，合计 **352 ≈ 343**（差 9vp，靠 Column `space: Space.xxs` 已含，实测接近）。

---

## 3. GBlockStackingPhysics.ets

**① 盘面容器有 `layoutWeight(1)` 吗？**
**横向有、纵向没有**：三个塔各自 `Column{...}.layoutWeight(1)`（327-328 行，横向均分），
纵向高度由内容撑开：塔内 5 格 `.height(Cell.of(34))`（**314 行**）。

**② 最底下那块是什么？**
`Row{ Button(重开)[已隐藏] + Button(换一关) }`（353-372 行）——**「换一关」是真入口，不能删**。

**③ 高度账**：HintBar 38 + 状态 20 + 塔(5×34+内宽 16+高度 16=202) + 清单框(2 行 ≈60) + note 20 + 按钮 44 + 间距 30 = **414 ⇒ 超 71**。

**④ 补丁（两条：塔矮一点 + 清单只留一行）**
```diff
--- a/entry/src/main/ets/games/GBlockStackingPhysics.ets
+++ b/entry/src/main/ets/games/GBlockStackingPhysics.ets
@@ -314,1 +314,1 @@
-.fontSize(FontSize.lg).textAlign(TextAlign.Center).width('100%').height(Cell.of(34))
+.fontSize(FontSize.lg).textAlign(TextAlign.Center).width('100%').height(Cell.of(Bp.isShort() ? 26 : 34))
@@ -340,1 +340,2 @@
-        Text(this.queue.length > 0 ? TG2('{0} 宽 {1}', EMJ[this.queue[0]], this.queue[0]) : '🏁')
+        Text(this.queue.length > 0 ? TG2('{0} 宽 {1}', EMJ[this.queue[0]], this.queue[0]) : '🏁')
+          .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```
⇒ 414 − 40 − 34 = **340** ✓（26 是「塔格」，不是左右方向键，触控影响可接受）

---

## 4. GBoxCompletion.ets

**① 盘面容器有 `layoutWeight(1)` 吗？** **没有**（`Column({ space: Space.xs })`）。
格子 `.layoutWeight(1).height(Cell.of(62))`（**369 行**）⇒ 62/行。

**② 最底下那块是什么？**
`Row{ Button(清空点亮) + Button(重开)[已隐藏] }`（379-395 行）。

**③ 高度账**（4×4）：HintBar 38 + 状态 20 + 盘 4×62=248 + note 20 + 按钮 44 + 间距 24 = **394 ⇒ 超 51**。

**④ 补丁（一行）**
```diff
--- a/entry/src/main/ets/games/GBoxCompletion.ets
+++ b/entry/src/main/ets/games/GBoxCompletion.ets
@@ -369,1 +369,1 @@
-}.layoutWeight(1).height(Cell.of(62)).backgroundColor(this.lit[r * this.diffTotal + c] ? Palette.amber : this.theme.surface)
+}.layoutWeight(1).height(Cell.of(Bp.isShort() ? 46 : 62)).backgroundColor(this.lit[r * this.diffTotal + c] ? Palette.amber : this.theme.surface)
```
（原串那行很长，**只改 `height(Cell.of(62))` 这一小段**即可，其余保持原样。）
⇒ 248 → 184，合计 **330** ✓；46 ≥ 44 触控下限 ✓

---

## 5. GTennerGrid.ets

**① 盘面容器有 `layoutWeight(1)` 吗？** **没有**；但它**已有宽度上限**：
```ts
.width(Math.min(Bp.width - 2 * Space.lg, Math.max(200, Bp.height - 360)))   // 638 行
```
⇒ 533 时盘面 = 200（正方形）。

**② 最底下那块是什么？**
**规则句 `Text('每行每列都要有 0~9 各一次；灰底是题目给的数')`（746 行，你加的 `visibility(Bp.isShort() ? None)` 写法正确 ✓）**。
但它**在键盘与按钮行之后**，所以 533 上真正被切的是**按钮行**（提示/AI 代打/重开），不是规则句。

**③ 高度账**：HintBar 38 + 状态 20 + 盘 200 + 键盘 2×38+间距 6=**82** + tip(692) 34 + 按钮行 44 + 间距 30 = **448 ⇒ 超 105**。

**④ 补丁（三条：键盘并一行 + tip 矮屏隐藏 + 盘面地板下调）**
```diff
--- a/entry/src/main/ets/games/GTennerGrid.ets
+++ b/entry/src/main/ets/games/GTennerGrid.ets
@@ -641,6 +641,9 @@
-        Row({ space: Space.xs }) {
-          ForEach([0, 1, 2, 3, 4], (d: number) => {
+        Row({ space: Space.xs }) {
+          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (d: number) => {
@@ -665,7 +668,4 @@
-        Row({ space: Space.xs }) {
-          ForEach([5, 6, 7, 8, 9], (d: number) => {
-          ...
-        }
-        .width('100%')
+        // ★ 2026-11-08：第二行键盘已并入第一行（矮屏省 44vp）——原地删除整个 Row
@@ -692,1 +692,2 @@
-      Text(this.tip())
+      Text(this.tip())
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
@@ -638,1 +638,1 @@
-      .width(Math.min(Bp.width - 2 * Space.lg, Math.max(200, Bp.height - 360)))
+      .width(Math.min(Bp.width - 2 * Space.lg, Math.max(160, Bp.height - 360)))
```
⇒ 448 − 44(并键) − 34(tip) − 40(盘 200→160) = **330** ✓
> ⚠️ 并键那条要**删掉第二个 Row 整块**（666-690 行），大括号配对容易错 —— 建议先只做后两条（−74 ⇒ 374，仍超 31），
> 或把 tip 与规则句**一起**在矮屏隐藏（再 −0，tip 已算）⇒ 374 仍不够 ⇒ **并键是必要项**。

---

## 6. GTentsAndTrees.ets

**① 盘面容器有 `layoutWeight(1)` 吗？** **没有，而且连宽度上限都没有**：
```ts
Column({ space: Space.xs }){ ... }.width('100%')      // 683 行
```
格子 `.layoutWeight(1).aspectRatio(1)`（638-652 行）⇒ **盘高 = 屏宽 ≈ 813vp**（533 屏高根本装不下）。

**② 最底下那块是什么？**
**规则长句** `Text('🌳 树固定不动；…')`（**716 行，无 visibility**）；其上是 `Button(重开)`（已隐藏）与 `Text(this.tip())`。

**③ 高度账**：盘面 813 + 其余 ≈120 ⇒ **>900 vs 343 ⇒ 底部全部被切**（最严重的一款）。

**④ 补丁（两条，照抄 TennerGrid 的现成范式）**
```diff
--- a/entry/src/main/ets/games/GTentsAndTrees.ets
+++ b/entry/src/main/ets/games/GTentsAndTrees.ets
@@ -683,1 +683,2 @@
-      .width('100%')
+      .width(Math.min(Bp.width - 2 * Space.lg, Math.max(160, Bp.height - 360)))
@@ -716,1 +716,2 @@
-      Text(TG('🌳 树固定不动；每棵树上下左右恰好一顶 ⛺；行列数字 = 该行/列的帐篷数'))
+      Text(TG('🌳 树固定不动；每棵树上下左右恰好一顶 ⛺；行列数字 = 该行/列的帐篷数'))
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```
⇒ 盘面 813 → 173→**160**（`Math.max(160, …)`）⇒ 总 ≈ **322** ✓

---

## 7. 汇总与建议顺序

| 款 | 可修？ | 手段 | 补丁条数 | 省下 |
|---|---|---|---|---|
| `GTentsAndTrees` | ✅ 能修 | 加宽度上限 + 规则句隐藏 | 2 | **~880** |
| `GMazeNav3d` | ✅ 能修 | 盘面 maxHeight 70%→46% | 1 | 82 |
| `GBoxCompletion` | ✅ 能修 | 格子 62→46 | 1 | 64 |
| `GBlockStackingPhysics` | ✅ 能修 | 格子 34→26 + 清单第二行隐藏 | 2 | 74 |
| `GTennerGrid` | 🟡 需重排 | 键盘并一行 + tip 隐藏 + 盘面地板 160 | 4（含删块） | 118 |
| `GColorMazeNav` | 🔴 6×6 可删块救；**8×8 必须降难度或改 `Cell.of`** | 删方向键行 + note / 封顶 6×6 | 2~4 | 58（6×6） |

**我推荐先动 `GTentsAndTrees`**：一行 `.width(...)` 就是「盘面 813 → 160」，是 6 款里**修复幅度最大、风险最小**的（照抄同项目 `GTennerGrid:638` 已验证的范式）。

**顺序建议**：`GTentsAndTrees` → `GMazeNav3d` → `GBoxCompletion` → `GBlockStackingPhysics` → `GTennerGrid`（需动大括号） → `GColorMazeNav`（需产品决策）

## 边界

- 只读分析：**未改任何 .ets**、未编译、未碰模拟器、未 commit。
- 高度账是**按代码行高累加**（Cell.of/tap 实值、FontSize 近似），**不是真机实测**；
  343vp 来自 `GameHost` 的 `Bp.height - 190`，352vp 来自该处注释的实测值 —— 两者差 9，报告里按 343 保守算。
- `GColorMazeNav` 的方向键 Row 隐藏**我没给可直接照抄的链尾写法**：那行同时收了外层 Column 的 `}`，
  硬写容易破坏大括号配对；建议由能编译的人按「Row 链尾加 `.visibility(...)`」或 `if (!Bp.isShort()) {…}` 落地。
