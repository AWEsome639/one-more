# ★★★★★ `GSkyscrapers` 改法到行号：**调用点包裹 `HintBar` + 统计卡**（省 `~90vp`）

> `2026-11-14 13:0x`。判据 `2214`（行号 + 先例 + 可证伪预测）的执行。

## 一、两个大件的实际代码

```
669|  build() {
670|    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
671|      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
672|      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
673|      HintBar({                              ← 「AI 代打」按钮在它里面
674|        showHint: false,
675|        onAutoTap: () => { this.askAuto(); },
676|        demoOn: false,
677|        disabled: this.demoId >= 0,
678|        autoOn: this.autoId >= 0
679|      })
680|      Row({ space: Space.sm }) {             ← 三统计卡
681|        Column({ space: 2 }) {               ← 「已填」
...
```

## 二、⇒ 量化

| 元素 | 高度 | 依据 |
|---|---:|---|
| `HintBar` | **`38vp`** | `components/HintBar.ets:40 barHeight = 38` |
| `Column` 的 `space` | `8vp` | `Space.sm` |
| 统计卡 `Row` | **`~36vp`** | `label(xxs ~10) + value(md ~16) + space 2 + padding(Space.xs)=8` |
| `Column` 的 `space` | `8vp` | |
| **合计** | **`~90vp`** | |

**⇒ 而缩盘面（`240 → 140`）只腾 `67vp`，且把 `6×6` 格子从 `40` 压到 `28.8vp`。**

## 三、⚠️ 绝不能改 `HintBar` 组件本身

**实测：`339` 款游戏用 `HintBar`。**
**而组件自己的注释（`HintBar.ets:38-39`）就记着：**
> 「共享组件改全局、证据却是混合的 ⇒ **不发布**。要动它必须先在 5 款上取到一致收益。」

**⇒ 项目早就判断过不能改全局 ⇒ ⇒ 只能在**调用点**包裹。**

## 四、⇒ 改法（三处，全是条件包裹）

```ts
// 673 行：整块不渲染
if (!Bp.isShort()) {
  HintBar({ showHint: false, onAutoTap: () => { this.askAuto(); }, demoOn: false,
            disabled: this.demoId >= 0, autoOn: this.autoId >= 0 })
}

// 680 行起：统计卡整块不渲染
if (!Bp.isShort()) {
  Row({ space: Space.sm }) { … }
}

// 670 行：Column 的 space 已经是 isShort ? sm : md（不用改）
```

**⚠️ `DemoBar` 不用动**（未演示时高度 `0`）。**

## 五、⇒ 先例

**`if (!Bp.isShort())` 在项目里有 `5` 处：**
```
GCompoundConnect:698  GCryptoArithmetic:518  GNumberBonds:423
GNumberBondsAll:413   GPeripheralFocus:338
```

## 六、⇒ 可证伪预测（改完看图，不是看 `blk`）

| 观测 | 现在（旧包） | 应变成 |
|---|---|---|
| `HintBar` 那行 | 有（`AI 代打`）| **消失** |
| 三统计卡 | 有（已填/错手/选中）| **消失** |
| **盘面第 `1` 行位置** | `~239vp` | **`~150vp`**（上移 `~90vp`）|
| **可见行数** | `1` 行 | **`2`–`3` 行**（+`90/40 ≈ 2.2` 行）|
| 格子尺寸 | `240/6 = 40vp` | **不变 `40vp`** ✅ |

**⇒ 若格子变得比 `40vp` 小 ⇒ 说明我改的不是这个变量（错了）。
⇒ 若可见行数没增加 ⇒ 说明 `90vp` 被别的东西吃了。**

**⚠️ 而这只能看图验（`blk`/`lowest` 看不见盘面），所以改完必须截图。**

## ⇒ 判据（`2258`）

**改一个**共享组件**之前，先 `grep` 它的引用数。**
**⇒ 这次 `HintBar` 有 `339` 个引用 ⇒ 改它等于改 `339` 款的行为；而调用点包裹只影响 `1` 款。**

**⇒ 判据：引用数 `> 10` 的组件，一律在调用点改，不动组件。
⇒ 而组件注释里若已写着「不发布/证据混合」，那是前人试过的结论，直接沿用。**

## ⇒ 判据（`2259`）

**「隐藏整块」省得多、但会让功能消失；「压紧」省得少、但信息保留。**
**⇒ 这次统计卡三张压成一行只省 `~20vp`，而整块藏省 `44vp`；但「已填 x/16」对玩家有用。**

**⇒ 判据：先算「隐藏」与「压紧」各省多少，再按「需要的量」选。
⇒ 若只差几 vp，选压紧（保留信息）；差得多才考虑隐藏。**
