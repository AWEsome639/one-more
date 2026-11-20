# `Double N Back` 横屏：**由预测器 A 找出的新候选** —— 结构已读清、补丁待验

## 一、它是怎么被找出来的

判据 `3072` 的预测器 A：「有 `layoutWeight(1)+aspectRatio` 但**通篇没有 `Bp.height − N`**」的
`15` 款里，`4` 款横屏溢出：`Double N Back` · `Odd Rotation` · `Magnets` · `Mandelbrot`。

- `Magnets` / `Mandelbrot` = **已知假阳性**（主画布贴底）
- `Odd Rotation` = **已知缺陷**（`3041` 清单里）
- **`Double N Back` = 唯一的新候选**（此前从未被标过）

台账当前值：`blk=48px`（横屏 `2560×1600`）。

## 二、结构（`entry/src/main/ets/games/GDoubleNBack.ets`，`383` 行）

```
:284  Column({ space: Bp.isShort() ? Space.sm : Space.md })
:295    Row  → 4 张统计卡，各 .layoutWeight(1)
:316    Row({ space: Space.md })
:317      Column({ space: Space.xs })          ← 网格容器
:319        Row({ space: Space.xs })           ← ★ 一行的 3 个格子
:323          格子 .layoutWeight(1).aspectRatio(1)
:326        }.width('100%')                    ← ★ 要限的就是这一行
:328      }.layoutWeight(2)
:330        （另一个 .layoutWeight(...) 的兄弟 —— 字母面板）
:332    }.width('100%')
:333    Text(this.msg)
:334    Row  → 按钮
```

**机制**：格子是 `.layoutWeight(1).aspectRatio(1)` ⇒ **宽由行分配、高 = 宽**。
而这一行的宽是 `.width('100%')`（内容宽 `~813vp`）⇒ 每格 `~264vp`、`3` 行网格 `~792vp`
≫ 横屏可用的 `~377vp` ⇒ 溢出。**全文件没有任何「按可用高度反推」的约束**，所以压不下去。

## 三、补丁（一行，`isShort()` 门控）

`GDoubleNBack.ets:326`：
```diff
-      }.width('100%')
+      }.width(Bp.isShort()
+        ? Math.min(Bp.width, Math.max(200, 1.4 * 3 * (Bp.height - CHROME) / 3 + 10))
+        : '100%')
```

⚠️ `CHROME` 待定：需要用实测确定「网格上方那几行占多少 vp」。

### 更稳的等效写法（用已测的缺口反推，不需要 `CHROME`）

台账实测 `blk=48px = 16vp`。`3` 行网格 ⇒ 每格要窄 `16/3 ≈ 5.3vp` ⇒
行宽要窄 `3 × 5.3 = 16vp`：

```diff
-      }.width('100%')
+      }.width(Bp.isShort() ? Bp.width - 56 : '100%')   // 853 − 56 = 797vp
```

⇒ `16vp` 是从**实测缺口**反推的，不是猜的；但**仍需一次实测确认**。

## 四、为什么现在不改

- 按 `3030` 的教训：盲改版面平均要 `5` 次才成（`Shadow Pivot` 前 `5` 次全废）
- 现在**没有可用的设备**（本机模拟器交互层已坏：`keyEvent Power` 会阻塞 `400s`）
- 改完**无法验证** ⇒ 违反「改完必须看截图」

⇒ **写清补丁、不动代码。** 设备一好（或走云调试/云测试），这是一次 `10` 分钟就能收的活：
改 → 编译 → 测 → 看截图（期望 `blk=0` 且网格 `3` 行完整）。

## 五、验收要求（比数值更严）

1. `blk` 应为 `0`
2. **截图必须看到 `3` 行格子全部完整**（这是 `2605`：`blk=0` 可能是重叠或没渲染）
3. 竖屏必须不变（改动在 `isShort()` 分支）
4. 统计卡与按钮仍完整

## 六、判据

> **预测器能告诉你「该看哪一款」，但补丁仍然要实测定常量。**
> `16vp` 这个数是**从实测缺口反推**的（不是猜），可它只保证「这次够」，
> 不保证「以后也对」—— 所以最后仍要一次实测。

⇒ 两条：
1. **静态能定「改哪一行」**（结构 + 特征）**，不能定「改多少」**（常量要实测）
2. **没设备时把补丁写成 diff 存档** —— 比改完不验强，也比只写「这里有问题」强
