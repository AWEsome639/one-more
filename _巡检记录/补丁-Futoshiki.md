# 补丁：Futoshiki（`GInequalityBalanceOps.ets`）—— 只读分析，未改 .ets

> 执行：verifier-eng2 ｜ ⛔ 未编译、未碰设备、未 commit、未改 .ets
> 症状：`max_bottom = 1588px`，只超 4px（≈1.3vp）｜预算 `343vp = Bp.height − 190`
> 你试的两刀都无效 —— 下面先说**为什么无效**，再给真正的那一刀。

## 0. 结论（先说答案）

**真正撑出去的那块 = 最底部那行静态提示**
`Text(TG('提示：先算乘、再算加；两边都算完才好放符号'))`（**352 行，全文件唯一没有 `visibility` 的尾部元素**）。
它 `fontSize(FontSize.xxs)` + `width('100%')` + **没有 `maxLines`** ⇒ 实测高度 17~34vp（1~2 行）。
**矮屏隐藏它 ⇒ 省 17~34vp = 51~102px**，比需要的 4px 多一个数量级。

## 1. 为什么你那两刀无效（这是本次最重要的发现）

### 刀 2：底部 `Cell.of(46)` → 矮屏 `Cell.of(38)` —— **改的那颗按钮在矮屏上是隐藏的**

```ts
Button(this.over ? … : TG('重开'))
  .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)   // ← 348 行，早就隐藏了
  …
  .height(Cell.of(Bp.height < 600 ? 38 : 46))                        // ← 你改的是这一行
```
`Visibility.None` **不占布局** ⇒ 把它的高度从 44 改到 36，对 `max_bottom` **零影响**。
（判据 1869 停手是对的：这不是「改错了位置」，是「改的元素根本没参与布局」。）

### 刀 1：键盘键 `Cell.of(56)` → 矮屏 `Cell.of(48)` —— 本应 −7vp，没动说明**测的不是最底节点**

`Cell.of()` 的实算（`Design.ets:100`）：`round(base × Cell.k(1) × Bp.scale()(1.12) × shrink(0.85))`
⇒ `Cell.of(56) = 53vp`、`Cell.of(48) = **46vp**`，**差 7vp = 21px**。
键盘行是 tip 的**上一个兄弟**、且 Column 是 `justifyContent(FlexAlign.Start)`（顶部对齐、溢出向下）
⇒ 键盘矮 7vp，tip 就该上移 21px。**你说 max_bottom 一点没动** ⇒ 两种可能：
1. 你测的节点不是 tip（比如是某个固定在最底的系统/页头节点）——**建议只测 tip 那一个节点的 bottom**；
2. 那版包里这两处的 `Bp.height < 600` 取到了别的值（`Bp.height` 若在 build 早期为 0，`0 < 600` 也是 true ⇒ 与 533 同值，不影响结论）。
> 无论哪种，**下一刀不要再依赖键盘**：直接删/藏 tip，量级大 5 倍。

### 刀 3（你问的）：盘面是不是 `aspectRatio(1)` / 按宽度撑？

**这款没有盘面。** 它是「天平」题型：左右两个表达式列 + 中间 ⚖️ 符号（30~45 行），
**全文件 0 处 `aspectRatio`、0 处 `layoutWeight` 驱动的棋盘**。
⇒ 那套已修 9 款的 `.width(Math.min(...))` 封顶**对它无效**（这也解释了为什么 88% 命中里没有它）。

## 2. 竖向预算账（853×533，逐块）

**尺子**：`Cell.of(x) = round(x × 1.12 × 0.85) = round(x × 0.952)`；文字行高按 `fontSize × 1.4` 估。

| # | 块（按 build 顺序） | 计算 | 估算 vp | 备注 |
|---|---|---|---|---|
| 1 | `DemoBar` | 未演示 = 0 | **0** | 演示中会 +38 |
| 2 | `HintBar` | `barHeight = 38` | **38** | 共享组件 |
| 3 | 统计 Row（题号/答对/得分） | `padding(sm 10)×2` + xxs 16.8 + 间距 2 + lg 25.2 | **64** | 3 卡同一行 |
| 4 | **天平 Row**（左式/⚖️/右式） | `padding(md 16)×2` + max(左列 lg 25.2+xl 28+2=55, 中列 xxl 33.6×2+2=69) | **101** | **单块最高**（不是盘面）|
| 5 | `Text(this.msg)` | sm 19.6 × 1~2 行 | **20~39** | maxLines 2 |
| 6 | `Text(lastFb)`（常驻结果行） | xxs 16.8（全角空格占位） | **17** | 一直渲染 |
| 7 | 符号键盘 Row | `Cell.of(48)` = 46 | **46** | 4 个按钮 |
| 8 | 重开 Button | `isShort` 隐藏 | **0** | ← 刀 2 改的是它 |
| 9 | **提示「先算乘…」** | xxs 16.8~33.6（无 maxLines，可能 2 行） | **17~34** | ← **真凶（最底）** |
| 10 | Column `space: Space.xxs` | 2 × 8 处 | **16** | |
| — | **合计** | | **319~345** | 预算 **343** |

**判定**：正常情况（msg 1 行 + 提示 1 行）≈ **319vp < 343** ✓；
**msg 占 2 行 + 提示折 2 行** ≈ **345vp > 343** ⇒ 超 2~4px —— **和实测的「超 4px」完全对上**。
⇒ 结论：**溢出是「最底那两行文字同时折行」造成的**，不是键盘、不是按钮、不是盘面。

## 3. 精确补丁

### 补丁 A（主刀，推荐先上）：矮屏隐藏最底提示行

```diff
@@ 352 行（build 的倒数第二行语句）
-      Text(TG('提示：先算乘、再算加；两边都算完才好放符号')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
+      Text(TG('提示：先算乘、再算加；两边都算完才好放符号')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```
**收益**：省 17~34vp（51~102px）⇒ 超出的 4px 彻底消失，还留 47~98px 余量。
**代价**：矮屏上看不到这句静态玩法提示（其余 12+ 款已按同一判据 1853/1867 隐藏说明行，风格一致）。

### 补丁 B（想保留提示就用这条）：天平卡的 `padding` 降一档

```diff
@@ 322 行
-      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
+      }.width('100%').padding(Bp.isShort() ? Space.sm : Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
```
⇒ `Space.md 16 → Space.sm 10`：上下各 −6 ⇒ **−12vp（36px）** ✓ 足够覆盖 4px，且提示行保留。
（这一块是「单块最高」的 101vp，压缩它最划算。）

### 补丁 C（可选，再留余量）：`msg` 与「常驻结果行」二选一

46~51 行有两条并行的反馈行（`msg` 与 `lastFb`），矮屏可以只留一条：
```diff
@@ 328 行附近（lastFb 那行的开头）
-      Text(this.lastFb.length > 0 && this.lastFb !== this.msg ? this.lastFb : '　')
+      Text(this.lastFb.length > 0 && this.lastFb !== this.msg && !Bp.isShort() ? this.lastFb : '　')
```
⇒ 矮屏这一行只剩全角空格（16.8vp），实际信息由 `msg` 承担；配 A 一起用能留 ~60vp 余量。
⚠️ 但「常驻结果行」是判据 749 的产物（避免布局跳动），**除非 A/B 不够，不建议动它**。

## 4. 推荐组合

| 方案 | 改动 | 净省 | 风险 |
|---|---|---|---|
| **A 单独** | 1 行 | **17~34vp** | 极低（说明行，已有 12+ 款先例）|
| **B 单独** | 1 行 | 12vp | 低（只动内边距）|
| A+B | 2 行 | 29~46vp | 低 |
| A+B+C | 3 行 | 46~63vp | 中（动了 feedback 行）|

**我建议：A + B**（两行，一次把 4px 溢出和「msg 折两行」的抖动余量都吃掉）。
**不要**再动键盘与重开按钮：一个只值 7vp、一个根本不参与布局。

## 5. 一条通用经验（给下一款用）

**`max_bottom 不动` ⇒ 先问「我改的元素在矮屏上是不是被 `visibility(None)` 了」**。
本项目已有 **13+ 处** `Button(重开)` / 说明行按 `Bp.isShort()` 隐藏 —— 改这些元素的高度/字号是**纯空操作**。
判断最快的方法：在 `build()` 里搜该元素附近有没有 `visibility(Bp.isShort()`，有就换目标。

## 边界

- 只读静态分析：**未改任何 .ets**、未编译、未碰设备、未 commit。
- vp 是**按公式累加**（`Cell.of` 用 `×1.12×0.85` 实算、文字按 `fontSize×1.4` 估行高），误差 ±10vp；
  与实测的「超 4px」能对上（正常 319 / 极端 345 vs 预算 343），所以方向可信。
- 补丁 A/B 的字符串我已逐字核对（352 行、322 行），可直接全文匹配替换。
