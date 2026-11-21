# 判据 `3110`：**`layoutWeight` 只对 Row/Column/Flex 的「直接子节点」生效** —— 套一层 Stack 就静默失效

## 一、缺陷

`Cube_Net_Fold`（立方体展开）竖屏：立方体展开图**渲染成几个 `·` 小点**，几乎完全不可见。

`blk=0/0px`、`cov=0.00` —— **两个机器指标都判「干净」**。是视觉模型看截图发现的。

## 二、根因（由 `deepseek-v4-pro` 子代理静态诊断，置信度高）

```typescript
@Builder cubeCell(i: number) {
  Stack() { Text(...) }
  .layoutWeight(1).aspectRatio(1)        // ★ :317 —— 这里是死的
  ...
}

// 调用处
Stack() {
  if (LAYOUT[r * 3 + c] > 0) { this.cubeCell(LAYOUT[r * 3 + c] - 1) }
}
.layoutWeight(1).aspectRatio(1)          // 外层才真正吃到 Row 的 flex
```

⇒ `layoutWeight` **只对 Row / Column / Flex 的直接子节点生效**。
内层 Stack 的父是 **Stack**（不是 flex 容器）⇒ `.layoutWeight(1)` **完全失效**；
没有显式宽高、`aspectRatio(1)` 又不强制撑满父容器 ⇒ 内层**按内容收缩**
（内容是一个 `·`，`FontSize.lg = 18`）⇒ 约 `24×24vp`。

⇒ 外层透明 Stack 仍被撑成 `128.9×128.9` ⇒ 视觉上就是「一格大的空白里有个小点」。

### 对照证据（同库两个渲染正常的游戏，都是单层）

| 文件 | 格子写法 |
|---|---|
| `GMemoryMatrix.ets:413` | **单个** Stack 直接挂 Row，`.layoutWeight(1).aspectRatio(1)` |
| `GMagicSquares.ets:444` | **单个** Text 直接挂 Row，`.layoutWeight(1).aspectRatio(1)` |
| `GCubeNetFold.ets:317` | **双**层都写 `.layoutWeight(1).aspectRatio(1)` ← 唯一一个 |

## 三、修法

```diff
-    .layoutWeight(1).aspectRatio(1)
+    .width('100%').height('100%')
```

⇒ 外层已负责「占位 + 正方形」，内层只需**填满父容器**（全库填充 Stack 父容器的惯用写法，249 处同款）。

### 验收

| | 改前 | 改后 |
|---|---|---|
| 格子尺寸 | `~24vp`（按内容收缩）| `128.9vp`（填满父容器）|
| 截图 | 6 个 `·` 小点散在空白里 | **6 个完整格子，十字形展开图成型** |
| `lowest` | `1628`（提示文字在屏中）| `2449`（正常到底部）|

## 四、判据

> **`layoutWeight` 是「相对父容器分配剩余空间」——父容器不是 flex 时，它不报错、不警告，只是静默失效。**
> 而失效的后果是「按内容收缩」，在 AI 眼里很容易被当成「渲染不出来」。

⇒ 五条：
1. **`.layoutWeight(1)` 用之前先确认父容器是 Row/Column/Flex**；父是 Stack/Grid 时要用 `.width('100%').height('100%')`
2. **「外层占满 + 内层收缩」这个组合，视觉上等于「整格空白 + 一个小点」** —— 特别容易被判成「没画出来」
3. **诊断这类问题要看「对照写法」**：同库两个正常游戏都是单层，只有它套了两层 ⇒ 一眼定位
4. **机器指标 `blk`/`cov` 对这类问题结构性失明**（它们只量底边溢出，不看元素尺寸）
5. **卡住时换更强的模型是对的** —— 这个根因我读了两遍没看出来，`deepseek-v4-pro` 一次给出对照证据

## 五、遗留（次要）

底部提示行 `lowest [62,2449][2162,2496]` —— **完整但贴屏底**（同 `Match 3` 的情形，`blkh` 够）。
网格无高度封顶（`:366` 只有 `.width('100%')`），将来若要留边距，可按 `GridFit` 补 `.constraintSize`。
