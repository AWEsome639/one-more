# `Kakuro Mini`（迷你数谜）：**棋盘修好了，键盘还差一步**（模拟器在验证时挂了）

## 已确认的进展（有截图）

| 项 | 改前 | 改后 |
|---|---|---|
| 棋盘 | **一大片黑，只看得到列线索** | **`3×3` 完整渲染**（`↓10 ↓17 ↓20` / `12→ 22→ 13→` / 九个格子）|
| `max_bottom` | `1600` | `1600`（键盘仍在底部）|
| `lowest` | `点下面数字填入选中格…`（说明行）| **`1`（键盘数字）** ⇒ **键盘已经上来了** |

**⇒ 关键一刀：`.constraintSize({ maxHeight: Bp.height - 280 })` → `.constraintSize({ maxWidth: … Bp.height - 320 })`**
**⇒ 再次验证判据 1928：`aspectRatio(1)` 的板子，`maxHeight` 只裁不缩，必须用 `maxWidth`。**

## 还差的一步

**截图里键盘（`1~9` 两行）只露出最上面一条边** ⇒ 还差 `~60~80px`。
**已加（未验证）**：矮屏隐藏「空闲那句长说明」（两行，约 `40px`），**保留胜负与报错**：
```ts
.visibility(Bp.isShort() && !this.over && this.hint.length === 0 ? Visibility.None : Visibility.Visible)
```

## 为什么没验完

**装完那一刻 `hdc list targets` 变成 `[Empty]`** —— 模拟器又挂了（这次是 `19` 分钟的长编译 + 高峰负载）。
**⇒ 按红线（他醒着，不许卡到不能用），我先把模拟器停掉，把这一刀留到下次验证。**

## 下次三分钟就能验

```bash
python3 工具/shot_game.py "Kakuro Mini"    # 期望 < 1584，且 lowest 是键盘数字
```
**再看截图确认键盘两行完整。**
