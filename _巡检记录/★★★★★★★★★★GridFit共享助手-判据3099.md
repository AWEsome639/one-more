# 判据 `3099`：把「纵向正方形网格按高度反推宽度」抽成共享纯函数 `GridFit`

## 一、为什么

一晚修了**四款**同一类缺陷：
`Simon Command`(`3089`) / `Simon Says`(`3097`) / `Odd Rotation`(`3098`) / `Silhouette Match`(`3084`)。
每款都是手算一个常数（`−424` / `−536` / `−288` / `104` 容器），
**过程一样、错误也一样**（第一次都算错，因为 chrome 估小了）。

⇒ 抽成一个纯函数，把几何关系写死，只留「chrome 必须逐款实测」这一件人做的事。

## 二、几何关系（可复算）

```
n 行、c 列、块间距 g、上方 chrome = above、下方 = below、可用总高 = H
块边长  s = (W − (c−1)·g) / c
网格高  H_grid = n·s + (n−1)·g
要求    H_grid + above + below ≤ H
⇒ W ≤ c·(H − above − below − (n−1)·g)/n + (c−1)·g
```

⇒ 实现：`entry/src/main/ets/core/GridFit.ets` 的 `GridFit.width(cols, rows, gap, above, below, avail, floor)`
附带 `GridFit.check(...)` 做**数学自检**（把结果代回式子看总高）。

## 三、验证：与两款已修好的实测值对照

| 游戏 | 实测拟合出的行宽 | `GridFit.width` | 差 |
|---|---|---|---|
| `Simon Says` 2×2, above=`272` | `525.4`（`Bp.height − 536`）| **`526`** | `+0.6` |
| `Odd Rotation` 3×3, above=`201.6`, below=`86` | `510.7`（`Bp.height − 288`）| **`511`** | `+0.3` |

⇒ **两次独立实测被同一个式子复现** ⇒ 几何式是对的。

## 四、顺带发现：`Simon Command` 的 `−424` 偏小

助手给它 `W = 592`（above=`206`），而我拟合的 `−424` 对应行宽 `749.4`。
⇒ 我那个值**太宽松**，这也解释了为什么它修完还留着 `blk=1/24px`。

⇒ 留着不改（它现在四块可见、只差 `24px` 贴屏沿），但**下次动它应该用 `592`**。

## 五、怎么用

```typescript
import { GridFit } from '../core/GridFit';

// 竖屏才用；横屏瓶颈是宽度、直接 '100%'
.width(Bp.isShort()
  ? '100%'
  : Math.min(Bp.width, GridFit.width(3, 3, Space.sm, 201.6, 86, Bp.height)))
```

⚠️ **`above` / `below` 必须从截图实测**，不能估 —— `Simon Says` 我估 `201.6`、实测 `272`，差 `70vp`，第一次常数完全错。

## 六、判据

> **同一个几何关系被手算第三遍时，就该写成函数；写到函数里，错误只可能剩「输入不含」这一种。**

⇒ 四条：
1. **`GridFit.width` 只解决「算」，不解决「量」** —— chrome 还得逐款从截图取
2. **数学自检（`GridFit.check`）不能替代真机截图**（判据 `2605`）
3. **新助手要拿「已经用别的方法修好的款」做回归** —— 这次用 `Simon Says` / `Odd Rotation` 校准，差 `0.6vp` 以内
4. **助手输出与手工拟合不一致时，先信助手** —— 手工拟合容易把 chrome 估小（`Simon Command` 就是）
