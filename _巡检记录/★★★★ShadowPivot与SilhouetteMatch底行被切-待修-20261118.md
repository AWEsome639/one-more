# `Shadow Pivot` / `Silhouette Match`：**棋盘底行被切**（待修，处方已定）

> `2026-11-18 08:41`。**今晚第九维（按 `board` 语义分组后重扫）挖出来的真缺陷。**

## 一、⇒ 缺陷（裁图证据）

**⇒ `Shadow Pivot`（`blk=72px`）与 `Silhouette Match`（`blk=72px`）：两个网格的**最底一行都被屏沿切掉**（能看到格子上半截、下半截没了）。**
**⇒ 因此最下排格子**看不全也点不准** —— 与 `Sokoban` 那类同源。**

**⇒ 截图：`截图-Shadow_Pivot-*.jpeg`、`截图-Silhouette_Match-*.jpeg`（裁 `y=900–1600` 一看就明白）。**

## 二、⇒ 为什么之前没发现

**⇒ 这两款在「26 款贴边」名单里，但我当时按 `lowest` **高度**判的（`2875`）；它们的 `lowest` 是**提示行/按钮**（高度正常）⇒ 高度判据看不出**棋盘**被切。**
**⇒ ⇒ 教训：`lowest` 只代表「最下面那个元素」，**棋盘底行被切时 `lowest` 可能是别的元素**（如提示行在棋盘上方）。**

## 三、⇒ 落点与处方

**⇒ 两个文件结构几乎一样（复制关系，`grep -rln "}.width(104)"` 只命中 `2` 个文件）：**
- `entry/src/main/ets/games/GShadowPivot.ets`
- `entry/src/main/ets/games/GSilhouetteMatch.ets`

**⇒ 结构（`GShadowPivot.ets` `L284–302`）：**
```
L284 Column({ space: 2 }) {           ← 左「原形」网格
L286   Column() { Column({ space: 2 }) {
L287     ForEach(ROWS) { Row { ForEach(ROWS) { Stack().layoutWeight(1).aspectRatio(1) ... } } }
L295   }.width('100%') }.width(104)   ← ★ 固定 104vp
L296 }.layoutWeight(1)
L297 Column({ space: 2 }) { ... }.layoutWeight(1)   ← 右「光线」区
L302 }.width('100%')
```

**⇒ 处方（照抄同项目已收敛的写法 —— `GPerspectiveShiftView.ets` `L392`）：**
```ts
.constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
```
**⇒ 加在**承载网格的容器**上（`L284` 那个 `Column` 或它的父 `Row`），让 `layoutWeight` 撑开的网格**有上限**。**
**⇒ 注意（判据 `2859`）：这是 `layoutWeight` 分支 ⇒ **单纯缩上面无效**，必须给容器加 `constraintSize`。**

## 四、⇒ 验收（三条，缺一不可）

1. `shot_game` **连测两次**（`2873`）：`blk` 两次都 `0`；
2. **裁图**数底行：两个网格的最底一行格子**完整可见**；
3. `lowest` 的高度仍是设计值（不要为了塞下而把底行压扁）。

## 五、⇒ 同族的其它款（一并复核，可能同病）

**⇒ `blk=72px` 且我看过但当时判「装饰」的：`Wireframe 3D Rotation`（面板底部圆角可见、确实没事）。**
**⇒ 还没单独看过的 `blk=48px` 款：`Triple Sequence` / `Trace Path` / `Perspective Taking` / `Odd Rotation` —— 明天一起裁图确认。**
