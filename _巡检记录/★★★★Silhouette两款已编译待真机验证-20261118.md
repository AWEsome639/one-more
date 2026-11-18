# `Silhouette Match` / `Silhouette Match Ortho`：**补丁已应用 + 编译通过，待真机验证**

> `2026-11-18 14:46`。奥森：「都可以做呀～就先别开模拟器就行」⇒ **能编译、不开设备。**
> **⇒ 所以这两款现在的状态是「代码改了、编译过了、**没在真机上看过**」—— 不许当成修好。**

## 一、⇒ 改了什么（两款同一处方，判据 `2907`）

```ts
/** 格子边长（vp）：按可用高与当前格数算；格数随难度变（diffTotal，最大 7）。 */
private gs(): number {
  return Math.max(18, Math.floor((Bp.height - 400) / Math.max(2, this.diffTotal)));
}
```

- **`GSilhouetteMatch.ets`**：5 处格子 `.layoutWeight(1).aspectRatio(1)` → `.width(this.gs()).height(this.gs())`；另加 5 处行内 `.justifyContent(FlexAlign.Center)`；
- **`GSilhouetteMatchOrtho.ets`**：5 处格子同样替换（其网格由 `ForEach(LAYER_IDX)` 生成，居中已由原有 `alignItems` 承担）。

**⇒ 编译：`BUILD SUCCESSFUL in 19m 37s`（两款一起，一次构建）。**
**⇒ `Bp.height=533`、`diffTotal=5` ⇒ `(533-400)/5 = 26vp = 78px` ⇒ 一行选项网格 `5×78+4×6 = 414px` ⇒ 两行 `828px` + 目标网格 + 头部 ≈ `1490px` ⇒ 装得下。**

## 二、⇒ 明天要做的（一步）

1. `bash 工具/emu_up.sh`（**确认无编译在跑**，判据 `2908`）；
2. `hdc install -r …` ⇒ **确认输出 `AppMod finish`**（判据 `2909`）；
3. 测 `Silhouette Match`：看 `blk`；**裁图必须看到「目标网格 + 4 个选项」全部完整**（不只是底行 —— 这次的病是第二行选项整个在屏外）；
4. 通过后同样测 `Silhouette Match Ortho`；
5. 两款都过后，把 `_巡检记录/今日修复对照-四款修前修后-20261118.png` 扩成六款。

## 三、⇒ 如果解码偏小（待验证时留意）

**⇒ `(Bp.height - 400)` 的 `400` 是我按「头部 ≈ 400px」估的；实测若发现网格过小（留白过多），把这个数调小到 `340–360` 再试一次即可（每次只改这一个数）。**

## ⇒ 顺带：今天还发现 `3` 款新缺陷（静态筛查坐实，未修）

**⇒ 用「`layoutWeight(1).aspectRatio(1)`」反查全库：`74` 个文件、`98` 处用了这个写法 —— 写法本身没问题（多数 `blk=0`），**没给上限**才有问题。**

**⇒ 按台账 `blk` 排序，除了已知六款，还有三款我裁图看过的**新缺陷**：**

| 款 | `blk` | 裁图所见 |
|---|---|---|
| **`Perspective Shift View`** | **`96px`（全库最高）** | A/B/C 三个面板的**底行都被切** |
| `Countdown Math` | `48px` | `+ − × /` 按钮下**还有一行被切** |
| `Chimp Test` | `48px` | 大数字面板**底部被切** |

**⇒ 这三款明天一并按 `2907` 处理（`Perspective Shift View` 尤其反常：它**已有** `constraintSize` 却仍溢出 `96px`，要单独查）。**
