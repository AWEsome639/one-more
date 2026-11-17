# `Word Association Recall` 两列改法：**可直接照抄的方案**（明天 10 分钟能落地）

> `2026-11-18 02:16`。**今晚已把 `padding` 缩到 `xs`（多一行完整），但 `6` 行内容仍放不进一屏 ⇒ 唯一解是两列。**

## 一、⇒ 现状（代码位置）

**⇒ `entry/src/main/ets/games/GWordAssociationRecall.ets`**

```ts
// L336（记忆阶段渲染 6 组配对）
Column({ space: Space.sm }) {
  ForEach(this.study, (p: number) => { this.pairRow(p) }, (p: number) => 's' + p)
}.width('100%')

// L366（每行）
@Builder
pairRow(p: number) {
  Row({ space: Space.sm }) {
    Text(PAIRS[p].cue)...layoutWeight(1)
    Text('→')...
    Text(PAIRS[p].mate)...layoutWeight(1)
  }.width('100%').padding(Bp.isShort() ? Space.xs : Space.sm)   // ← 今晚已改
    .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
}
```

**⇒ `pairRow` 的根 `.width('100%')` ⇒ **直接塞进 `Row` 会各占满整宽、互相重叠** ⇒ 必须加一个「半宽版」。**

## 二、⇒ 方案（三步，每步都小）

### ① 给 `pairRow` 加一个可选宽度参数（默认整宽）

```ts
@Builder
pairRow(p: number, half: boolean = false) {
  Row({ space: Space.sm }) {
    Text(PAIRS[p].cue).fontSize(FontSize.md).layoutWeight(1).fontColor(this.theme.ink)
    Text('→')...
    Text(PAIRS[p].mate).fontSize(FontSize.md).layoutWeight(1)...
  }
  .width(half ? '48%' : '100%')      // ★ 唯一改动
  .padding(Bp.isShort() ? Space.xs : Space.sm)
  ...
}
```

**⚠️ ArkTS 的 `@Builder` 支持带默认参数；若编译器不接受，改成两个 Builder（`pairRow` 与 `pairRowHalf`）共用内部逻辑。**

### ② 记忆阶段改成两列（矮屏）

```ts
if (Bp.isShort()) {
  Column({ space: Space.xs }) {
    ForEach([0, 1, 2], (r: number) => {
      Row({ space: Space.xs }) {
        if (r < this.study.length) { this.pairRow(this.study[r], true) }
        if (r + 3 < this.study.length) { this.pairRow(this.study[r + 3], true) }
      }.width('100%')
    }, (r: number) => 'row' + r)
  }.width('100%')
} else {
  Column({ space: Space.sm }) {
    ForEach(this.study, (p: number) => { this.pairRow(p) }, (p: number) => 's' + p)
  }.width('100%')
}
```

**⇒ `6` 行 → `3` 行 ⇒ 高度砍半（约 `-380px`）⇒ 一屏轻松放下。**

### ③ 保留今晚的 `padding` 改动（两列时更紧凑，无副作用）

## 三、⇒ 验收怎么算过（判据 `2873`/`2875`）

1. `shot_game` 连测**两次**，期望两次 `blk=0`；
2. **裁图确认 `6` 组全部完整可见**（这是关键 —— `y2` 不能证明「6 组都在」，必须看图数）；
3. 切到答题阶段截一张，确认四个选项没被两列布局影响（`option()` 是另一个 Builder，理论上不受影响，但要看一眼）。

## 四、⇒ 风险

| 风险 | 处置 |
|---|---|
| `@Builder` 默认参数不被 ArkTS 接受 | 改成两个 Builder 共用内部 `@Builder pairInner(p)` |
| 两列后文字被压缩换行 | `pairRowInner` 的 `Text` 已是 `layoutWeight(1)`，半宽后可能换行 ⇒ 若换行就把 `FontSize.md` 降到 `sm`（电视/平板不走这条分支）|
| 答题阶段被连带影响 | 两列只在 `phase === 记忆` 分支里，`option()` 不动 |

**⇒ 判据 `2880`：把「内容比一屏多两行」这类问题，按**列数**重排（`6×1 → 3×2`），而不是继续压 `padding`/字号 —— 后者只在小差距时有用（`2879`）。**
