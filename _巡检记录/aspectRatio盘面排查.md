# `aspectRatio(1)` 盘面排查（全库只读，2026-11-09）

> 只读：**未改任何 `.ets`**、未编译、未碰设备。复跑口径见 §5。

## 0. 一句话结论

`aspectRatio(1)` 全库 **324 处 / 160 文件**；真正当**盘面**用的 **44 处 / 44 文件**（判据：同一 `.链` 上同时有 `.width('100%')` + `.aspectRatio(1)`，且容器内有 `ForEach`/`Grid`）。

| 档 | 数量 | 含义 |
|---|---|---|
| **C 已确认无有效上限** | 1 | `maxHeight: '100%'` ＝父级满高，宽度仍是 813vp |
| **B1 待核实（可能超）** | 10 | `'70%'`：父级=游戏区(343) ⇒ 240vp 安全；父级=整屏(533) ⇒ **373vp 超 30vp** |
| **B2 不会超（但父级依赖）** | 2 | `'50%'`/`'46%'`：即使按整屏 533 算也 ≤267vp ⇒ 安全 |
| **A 已有限制（确定值）** | 31 | `maxHeight: Math.max(…, Bp.height−360/380/420)`（100~173vp）或 `maxWidth`（GGo9） |

⇒ **「完全没有任何上限」：0 处**；**唯一确认会爆的是 `GBreakout`**；**10 处 `'70%'` 需要上机量 rect 才能定论**。

## 1. 预算口径（横屏 853×533）

| 项 | 值 | 来源 |
|---|---|---|
| 屏宽 `Bp.width` | 853.33vp | 设备日志 `Bp 初始化: 853.33 × 533.33 scale=1.12` |
| 游戏区左右 padding | 40vp | `Space.lg(20)×2`（`GameHost`） |
| **盘面可用宽** | **≈813vp** | 853.33−40（与 code-hunter 实测 813 一致） |
| **游戏区高度预算** | **343.33vp** | `Bp.height − 190` |
| 宽驱动盘面高 | **≈813vp** | `width('100%')`+`aspectRatio(1)` ⇒ 高=宽 |
| **膨胀倍数** | **2.37×** | 813/343 |

⚠️ 口径：216 处 `layoutWeight(1)+aspectRatio(1)` **绝大多数是格子**（Row 等分+正方形），正确写法、**不在本表**。

## 2. 盘面清单（44 处，C→B1→B2→A）

| # | 文件 | 行号 | 宽度上限 | 当前上限（横屏换算） | 盘面估算（列 → 格宽） | 撑爆 343vp？ | 建议 |
|---|---|---|---|---|---|---|---|
| 1 | `GBreakout` | 604 | ❌ 无宽限（仅 maxHeight） | '100%' ⇒ **343vp** | 8 列 → 42.9vp/格 | **会**（宽度 813 不受限） | `maxWidth: Math.min(Bp.width−40, Math.max(200, Bp.height−360))` = **173vp** |
| 2 | `GSnake` | 591 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | 20 列 → 12.0vp/格 | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 3 | `GMatch3` | 539 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | 8 列 → 30.0vp/格 | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 4 | `GMirrorMaze` | 463 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | 6 列 → 40.1vp/格 | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 5 | `GTapa` | 704 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | 5 列 → 48.1vp/格 | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 6 | `GSumSnake` | 519 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | 4 列 → 60.1vp/格 | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 7 | `GLifeGame` | 442 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | ? 列 → — | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 8 | `GLockPattern` | 409 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | ? 列 → — | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 9 | `GMahjongSolitaire` | 535 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | ? 列 → — | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 10 | `GMazeNav3d` | 499 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | ? 列 → — | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 11 | `GMentalMapping` | 424 | ❌ 无宽限（仅 maxHeight） | '70%' ⇒ **240vp** | ? 列 → — | **待核实**：游戏区父级 240vp ⇒ 安全；整屏父级 **373vp ⇒ 超** | 改 `maxWidth` **173vp**（去掉父级依赖） |
| 12 | `GPegSolitaire` | 564 | ❌ 无宽限（仅 maxHeight） | '50%' ⇒ **172vp** | 7 列 → 24.5vp/格 | 不会（最坏 267vp） | 可留；建议统一 `maxWidth` |
| 13 | `G2048` | 813 | ❌ 无宽限（仅 maxHeight） | '46%' ⇒ **158vp** | 4 列 → 39.5vp/格 | 不会（最坏 245vp） | 可留；建议统一 `maxWidth` |
| 14 | `GGo9` | 1043 | ✅ maxWidth | 173vp（boardMax） | 9 列 → 19.2vp/格 | 不会 | 保持（范式） |
| 15 | `GConjunctionSearch` | 319 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 5 列 → 34.7vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 16 | `GGravitySort` | 322 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 5 列 → 34.7vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 17 | `GNegativeSpaceDetection` | 317 | ❌ 无宽限（仅 maxHeight） | max(140, h−420) ⇒ **140vp** | 5 列 → 28.0vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 18 | `GVectorGridAlignment` | 323 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 5 列 → 34.7vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 19 | `GFeatureMatrixRecall` | 381 | ❌ 无宽限（仅 maxHeight） | max(120, h−420) ⇒ **120vp** | 4 列 → 30.0vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 20 | `GFeatureMatrixRecallAll` | 366 | ❌ 无宽限（仅 maxHeight） | max(120, h−420) ⇒ **120vp** | 4 列 → 30.0vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 21 | `GGhostTap` | 335 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 4 列 → 43.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 22 | `GGridDisplacement` | 309 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 4 列 → 43.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 23 | `GHueSort` | 344 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 4 列 → 43.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 24 | `GMultipleObjectTracking` | 366 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 4 列 → 43.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 25 | `GSymmetry` | 364 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 4 列 → 43.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 26 | `GSymmetrySpan` | 342 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 4 列 → 43.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 27 | `GTangram` | 407 | ❌ 无宽限（仅 maxHeight） | max(140, h−420) ⇒ **140vp** | 4 列 → 35.0vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 28 | `GYajilin` | 449 | ❌ 无宽限（仅 maxHeight） | max(120, h−380) ⇒ **153vp** | 4 列 → 38.3vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 29 | `GMandalaRecall` | 328 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 3 列 → 57.8vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 30 | `GMemoryMatrix` | 368 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 3 列 → 57.8vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 31 | `GMemoryPalace` | 337 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 3 列 → 57.8vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 32 | `GPerspectiveShiftView` | 390 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 3 列 → 57.8vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 33 | `GSopt` | 322 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 3 列 → 57.8vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 34 | `GSubitizingRush` | 319 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | 3 列 → 57.8vp/格 | 不会 | 可留；建议统一 `maxWidth` |
| 35 | `GCorsiBlocks` | 362 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 36 | `GCountingSpan` | 372 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 37 | `GDynamicSalience` | 302 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 38 | `GInterlockPuzzle` | 310 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 39 | `GLaserLink` | 391 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 40 | `GLaserReflect` | 385 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 41 | `GMagicSquares` | 456 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 42 | `GMatrixReasoning` | 394 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 43 | `GPaperFolding` | 327 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |
| 44 | `GReflexTap` | 299 | ❌ 无宽限（仅 maxHeight） | max(140, h−360) ⇒ **173vp** | ? 列 → — | 不会 | 可留；建议统一 `maxWidth` |

## 3. 最该先改的 3 款

1. **`GBreakout` L604｜8 列｜`maxHeight: '100%'`** —— 唯一确认**会爆**：百分比=父高，宽仍 813vp。改 `maxWidth`=173vp（8 列 → 21.6vp/格，需同批压 HUD 或允许滚动）。
2. **`GSnake` L591｜20 列｜`'70%'`** —— 10 处 `'70%'` 里列数最多；父级=整屏时 373vp 会超。改 `maxWidth`=173vp ⇒ 8.6vp/格（蛇靠手势，可接受）。
3. **`GMatch3` L539｜8 列｜`'70%'`** 与 **`GPegSolitaire` L564｜7 列｜`'50%'`** —— 换 173vp 后 21~25vp/格，**低于 44vp 触摸目标** ⇒ 压 HUD 或盘面 `Scroll`。

## 4. 附带发现（供下轮）

- **`maxHeight` 有 5 种历史变体**：`max(140,h−360)`×26 / `max(140,h−420)`×3 / `max(120,h−420)`×2 / `max(120,h−380)`×2 / `max(100,h−420)`×1 ⇒ 横屏 100~173vp；建议收敛成一个 `boardMax()`（GGo9 现成）。
- **百分比 12 处**：父链若同时有 `layoutWeight(1)`，百分比基准会漂移；静态审查证明不了安全。
- **`maxWidth` 全库仅 1 处**，而 GGo9 注释写着「保留 `.width('100%').aspectRatio(1)` 宽驱动（有源码级断言要求）」⇒ **限宽不违反那套断言**，可推广。
- **列数≥5 的盘面共 10 处**，若统一压到 173vp，格宽会落到 **8.6~48.1vp**（只有 4 列及以下能保住 ≥44vp 触摸目标）。

## 5. 复跑口径（判据 1844）

```text
1) grep -rn "aspectRatio(1)" entry/src/main/ets/games/          # 324 处 / 160 文件
2) 只留宽驱动盘面：同一 .链 有 .width('100%') 且该节点块内含 ForEach( 或 Grid(
3) 在该链里（跳过 // 与 * 注释，继续收集后续 .修饰符）找 maxWidth / maxHeight
4) 分档：A=maxWidth 或 maxHeight=Math.max(下限,533−N)；B1='70%'（533×70%=373>343）；B2='50%'/'46%'；C='100%'
```

## 6. 局限

- **B1 类 10 处无真机 rect 证据**：`'70%'` 的百分比基数是父级高度，**必须上机量 `boardRect`**；本表给的是「父级=游戏区 / 父级=整屏」两个边界。
- 盘面宽按 `Bp.width − 40` 估；有嵌套 padding 的游戏实际更小。
- 44 处靠「容器内有 `ForEach(`/`Grid(`」识别；自绘行式盘面可能漏。已人工抽查 6 处（GSnake/GMatch3/GPegSolitaire/GMirrorMaze/GBreakout/GGo9）均为真盘面。