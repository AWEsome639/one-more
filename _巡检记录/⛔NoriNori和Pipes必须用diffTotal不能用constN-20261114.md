# ⛔ `Norinori` / `Pipes` 必须用 `diffTotal`，**不能用 `const N`**

> `2026-11-14 16:5x`。查上一轮留下的待确认项，**发现一个会写错的陷阱**。

## 一、证据

```ts
GNoriNori:23   const N: number = 5;                      ← 基准
GNoriNori:74   *  原来 diffTotal = sizeNow(5)（4/5/7）   ← **会变！**
GNoriNori:96   @State private diffTotal: number = 5;
GNoriNori:113  const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
                ↑ rowIdx() 用 diffTotal

GPipes:25      const N: number = 5;
GPipes:72      *  PIPE_LIB 是手工画的 5×5 = 25 格，但 diffTotal = sizeNow(5)（4/5/7）
GPipes:106     const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
```

**⇒ `const N` 恒为 `5`，但 `diffTotal` 是 **`4` / `5` / `7`**（随难度）。**
**⇒ 而渲染用的 `rowIdx()` 长度 = `diffTotal`。**

## 二、⇒ 若写 `44 * N` 会怎样

| 难度 | `diffTotal` | 写 `44 * N`（`220vp`）时每格 | 写 `44 * diffTotal` |
|---|---:|---:|---|
| 简单 | `4` | `55vp` ✅（但盘面偏大）| `176vp` ⇒ `44vp` ✅ |
| 普通 | `5` | `44vp` ✅ | `220vp` ⇒ `44vp` ✅ |
| **困难** | **`7`** | **`31.4vp` ❌ 远低于 44** | **`308vp` ⇒ `44vp` ✅** |

**⇒ ⇒ 写 `const N` 只在「普通」难度对，**简单和困难都错**（一个偏大、一个按不准）。**

## 三、⇒ 正确写法

```ts
.width(Math.min(Bp.width - 2 * Space.lg,
                Math.max(44 * (this.diffTotal > 1 ? this.diffTotal : 2), Bp.height - 360)))
```

**⚠️ 那个 `> 1 ? … : 2` 是防 `diffTotal = 0/1` 的退化（与 `rowIdx()` 里的守卫一致）。**

## ⇒ 判据（`2292`）

**一个文件里同时有「常量 `N`」和「可变 `diffTotal`」时，**先查渲染用的是哪个**。**
**⇒ 这次 `const N = 5` 是「库的基准尺寸」，而棋盘按 `diffTotal`（`4/5/7`）开
⇒ 用常量会在极端难度下错。**

**⇒ 判据：看到 `const N`，不要假设它就是渲染尺寸 —— `grep` 一下渲染循环用的是 `N` 还是别的变量。
⇒ 两者不同时，用渲染那个。**

## ⇒ 判据（`2293`）

**这个陷阱只在「非默认难度」下暴露 —— 普通难度下写 `44*N` 完全正确。**
**⇒ 所以它不会被默认路径的测试发现。**

**⇒ 判据：改一个「随难度变化的尺寸」时，要**逐个难度**验算，不能只验默认难度。
⇒ 这次若只看默认（`diffTotal=5`），`44*N` 与 `44*diffTotal` 完全相同 ⇒ 看不出来。**
