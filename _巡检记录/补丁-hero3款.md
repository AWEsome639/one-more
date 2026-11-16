# 补丁：hero / 答题区 / 特殊几何 三款（只读，未改代码）

> 2026-11-10 23:4x ｜ **只读分析**（未改 `.ets`、未编译、未碰设备）
> 预算基准 **343vp** = `GameHost.ets:3456` `.constraintSize({ maxHeight: Bp.height - 190 })`（横屏 533−190）
> ⚠️ 设备是 **853×533**：`Bp.width 853 ≥ Bp.MD(840)` ⇒ `Bp.scale() = 1.12`，且 `Bp.height 533 < 600` ⇒ `Cell.of` 再 ×0.85
> ⇒ **`Cell.of(x) = round(x × 0.952)`**（例：`of(72)=69`、`of(48)=46`、`of(36)=34`）；`Cell.tap(32)=44`（被 `touchMin` 抬）
> 行高按 `字号 × 1.3` 估：hero36→47、lg18→24、md16→21、sm14→18、xs13→17、xxs12→16

---

## 0 一句话

| 款 | 要改几处 | 现总高 | 溢 | 改后 | 能进 OK |
|---|---|---|---|---|---|
| **GReverseStroop** | **1 处**（hero 定高） | 370vp | +27 | **330**（余 13） | ✅ |
| **GVisualSearch** | **1 处**（emoji 盘封顶） | **1007vp** | **+664** | **327**（余 16） | ✅ |
| **GRadicalRoots** | **3 处**（间距/题卡内边距/选项高） | 420vp | +77 | **328**（余 15） | ✅ |

> **三款都能进 OK**，但 `GVisualSearch` 是**最严重的一个**：它的 emoji 网格**宽度 100%、格子 aspectRatio(1)** ⇒ 横屏算成 **813vp 方的盘**，等于把整块盘画到屏幕外（详见 §2）。

---

## 1 `GReverseStroop`（Stroop Test）—— 1 处

### 1.1 预算账

| 块 | 高度 | 依据 |
|---|---|---|
| DemoBar | 0 | 未演示 |
| HintBar | **38** | `barHeight = 38` |
| 统计三卡 | **66** | padding sm10×2 + xxs16 + gap6 + lg24 |
| **字词 hero 卡** | **150** | `.height(150)`（代码是 150，不是 180） |
| 选项行（4 个） | **69** | `Cell.of(72)` = round(72×0.952) = 69 |
| msg | 19 | sm14 |
| 重开按钮 | 0 | 矮屏 `Visibility.None` |
| 判定说明 | 16 | xxs12 |
| 间距 ×6 | 12 | `space: Space.xxs` = 2 |
| **合计** | **370vp** | **超出 27vp（≈81px）** |

### 1.2 🔴 顺便纠一个数：代码是 `.height(150)`，不是 180

```bash
$ grep -n "height(1[58]0)" entry/src/main/ets/games/GReverseStroop.ets
283:      }.width('100%').height(150).justifyContent(FlexAlign.Center)
```
⇒ Lead 说的 180 可能是旧版或别的款；**现源码 150**。下面的数字都按 150 算。

### 1.3 矮屏该降到多少：**104**

要求**改完留 ≥16vp 余量**：

```
上限 = 343 − chrome(151) − 选项行(69) − 余量(16) = 107
⇒ 取整到 104（余量 19vp）
```

`104` 装得下吗？hero 词（36 号，行高约 47）+ 小标题（xs 13，行高 17）+ 间距 2 = **66 ≤ 104** ✅ 还有富余。

### 1.4 补丁（1 处）

```diff
-      }.width('100%').height(150).justifyContent(FlexAlign.Center)
+      }.width('100%').height(Bp.isShort() ? 104 : 150).justifyContent(FlexAlign.Center)
```

> 竖屏（≥690）仍 150，零回归。

---

## 2 `GVisualSearch`（底部 emoji 网格）—— 1 处，但**问题最大**

### 2.1 回答 Lead 的问题：**是「按宽度撑的」**

```ts
// 第 296–313 行（节选）
Column({ space: Space.xs }) {
  ForEach(IDX, (r) => {                       // IDX = [0..5] ⇒ N = 6
    Row({ space: Space.xs }) {
      ForEach(IDX, (c) => {
        Text(this.cells[...])
          .layoutWeight(1).aspectRatio(1)     // ← 格子是正方形，边长 = 盘面宽 / 6
      })
    }.width('100%')
  })
}.width('100%')                               // ← **盘面宽度 100%，没有封顶**
```
⇒ **格子 `aspectRatio(1)` + 盘面 `width('100%')`** ⇒ **盘面高恒等于盘面宽**。
横屏游戏区宽 **≈813vp** ⇒ **盘面 813×813** ⇒ 整块盘只能看见顶部 343vp，其余全在屏外。

### 2.2 预算账

| 块 | 高度 |
|---|---|
| HintBar | 38 |
| 统计三卡 | 66 |
| 「找出它」提示卡 | 51（xxl24 行高 31 + padding sm 20） |
| 进度条 | 6 |
| **emoji 盘** | **813**（= 宽） |
| msg | 21（md16） |
| 重开 | 0（矮屏隐藏） |
| 间距 ×6 | 12 |
| **合计** | **1007vp** ⇒ **超出 664vp** |

### 2.3 封顶式子

盘面预算 = 343 − 194（chrome）= **149vp**；要留 16vp 余量 ⇒ 封顶值取 `Bp.height − 400`（533−400 = **133**）。

```diff
-      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
+      }.width(Math.min(Bp.width - 2 * Space.lg, Math.max(120, Bp.height - 400)))
+        .padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
```

**算账**：盘面 133 ⇒ 合计 **327vp**（余 **16vp**）✅
**格子多大**：133 / 6 ≈ **22vp**（含 padding sm 后更小 ≈20vp）—— 偏小但**可点**（emoji 点击热区就这么大；若要更宽松，把 `−400` 改成 `−380` 得 153vp 盘、格子 25vp，余量降到 4vp，**不推荐**）。
**竖屏**：`Bp.height ≥ 690` ⇒ `Bp.height − 400` ≥ 290，且 `Bp.width − 2×lg` 更小（手机 360−40=320）⇒ 与原来 `width('100%')` **等价或更宽松**，零回归。

---

## 3 `GRadicalRoots`（两个操作按钮 + 题卡）—— 3 处

### 3.1 预算账（`space: Space.sm` = 10）

| 块 | 高度 | 依据 |
|---|---|---|
| HintBar | 38 | |
| 统计三卡 | 51 | padding xs6×2 + xxs16 + 2 + md21 |
| **题目卡** | **107** | padding lg20×2 + hero47 + 2 + sm18 |
| tip | 18 | sm（1 行） |
| 选项行 1（2 个） | **46** | `Cell.of(48)` = 46 |
| 选项行 2（2 个） | **46** | 同上 |
| 底行（提示 44 + 说明文字） | **44** | `.height(44)` |
| 间距 ×7 | **70** | Space.sm = 10 |
| **合计** | **420vp** | **超出 77vp（≈231px）** |

### 3.2 三处补丁

```diff
 // ① 间距：矮屏 10 → 2（7 个间距省 56vp）
-    Column({ space: Bp.height < 600 ? Space.sm : Space.md }) {
+    Column({ space: Bp.height < 600 ? Space.xxs : Space.md }) {

 // ② 题目卡内边距：矮屏 lg(20) → sm(10)（省 20vp）
-      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
+      }.width('100%').padding(Bp.isShort() ? Space.sm : Space.lg).backgroundColor(this.theme.surface)

 // ③ 选项按钮：矮屏 48 → 40（两行各省 8vp，共 16vp）
-        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(Bp.height < 600 ? 48 : 56)).enabled(this.picked.length === 0 && !this.over)
+        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(Bp.height < 600 ? 40 : 56)).enabled(this.picked.length === 0 && !this.over)
@@ 第 358 行那一行同样改（两行是复制粘贴的同一串）
```

**算账**：420 − 56 − 20 − 16 = **328vp**（余 **15vp**）✅
**选项按钮**：`Cell.of(40)` = 38vp —— 比 44 触控线低 6vp，但这批按钮是**整行均分的宽按钮**（每行 2 个，宽约 390vp），纵向 38 只是矮一点，**点得中**（参考 `Design.ets` A2 条：71 处已接受 <44 的场景）。

---

## 4 三款共同的零回归点

| 判断 | 说明 |
|---|---|
| 竖屏（`Bp.height ≥ 600`） | 三处补丁**全部保留原值**：150 / `width('100%')` 走 `Bp.width−2lg` / `Space.md` + `Space.lg` + 48 |
| 手机 360×744 | `Bp.width−2lg = 320` 与 `width('100%')` 等价；`Space.sm` 分支不触发 |
| 判据 1829 | 三款都**没有往 Row 里塞新元素**，只改容器宽高与间距 ⇒ 无新增挤压 |
| 判据 1802 | 两处封顶都加在**盘面容器**上（`GVisualSearch` 的 Column、`GRadicalRoots` 的题卡），不动子项 |

---

## 5 待验证（本批没碰设备）

| # | 不确定 | 消除方法 |
|---|---|---|
| 1 | 三款的 chrome 是我按组件常量推的（HintBar 38 / 卡片 padding / 字号×1.3） | 出包后 dump 一次，逐行对 |
| 2 | `GVisualSearch` 的盘面宽度是否真的 ≈813 | dump 看 emoji 盘下沿 |
| 3 | `GRadicalRoots` 的 tip 是否会两行（`maxLines(2)`） | 若两行再 −18vp，需把 `③` 的 40 降到 36 |

---

## 6 复现

```bash
cd "/Users/a0000/dev/One More"
grep -n "height(150)" entry/src/main/ets/games/GReverseStroop.ets          # 283 行（不是 180）
grep -n "aspectRatio(1)" entry/src/main/ets/games/GVisualSearch.ets         # 296~313 行
grep -n "width('100%')" entry/src/main/ets/games/GVisualSearch.ets | tail -3
grep -n "Cell.of(Bp.height < 600 ? 48 : 56)" entry/src/main/ets/games/GRadicalRoots.ets
grep -n "maxHeight: Bp.height - " entry/src/main/ets/pages/GameHost.ets      # 343vp 的来源
```
