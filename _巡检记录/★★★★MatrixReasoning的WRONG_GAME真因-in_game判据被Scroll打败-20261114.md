# ★★★★ `Matrix Reasoning` 的 `WRONG_GAME` 真因：`in_game` 判据被 `Scroll` 打败

> `2026-11-14 18:0x`。追了一下午的「`Scroll` 会破坏某些游戏」，结论是**游戏没坏、测量判据坏了**。

## 一、⇒ `verify_title` 的判据

**`工具/shot_game.py:373` `verify_title()`：**

```python
on_home = ('今天这一局' in joined or 'Today' in joined) or \
          (('全部' in joined or 'All' in joined) and '🎯' in joined)
in_game = ('AI 代打' in joined or 'AI Play' in joined) or ('提示' in joined or 'Hint' in joined)
if on_home or not in_game:
    return False, want          # ← 这里返回 False 就记 WRONG_GAME
return (want in joined), want
```

**⇒ 要判「在游戏内」，必须 dump 里出现 `AI 代打`/`AI Play`（`DemoBar`）**或** `提示`/`Hint`（`HintBar`）。**

## 二、⇒ 而 `Scroll` 会把它们滚出视野

**`uitest dumpLayout` **只报当前可见的节点**（首页 `355` 款只有 `8` 张进树，就是这个原因）。**
**⇒ 套了 `Scroll` 之后，`HintBar`/`DemoBar` 位于内容底部、**被滚出视野** ⇒ 不在 dump 里 ⇒ `in_game=False` ⇒ **误判 `WRONG_GAME`**。

**⚠️ 证据：`Matrix Reasoning` 的 `WRONG_GAME` 备注是**
```
title '矩阵推理' not found; first texts=['‹', '矩阵推理', '找规律填矩阵', '☆', '?', '普通']
```
**⇒ `矩阵推理` 就在前 6 个文本里！标题明明对了，判的却是 `in_game`。**

## 三、⇒ 所以

| 结论 | 说明 |
|---|---|
| **`Matrix Reasoning` 游戏本身** | **没有坏** —— 标题正常渲染 |
| **`Scroll`** | **没有破坏它** —— 破坏的是**测量判据** |
| **我回滚它的决定** | **仍然正确**（当时无法验证 ≠ 可以合并），但**原因要改**：不是「`Scroll` 会破坏游戏」，而是「`Scroll` 会让测量工具报 `WRONG_GAME`」 |
| **其余 `7` 款 `Scroll` 为何没事** | 它们的 `HintBar`/`DemoBar` 仍在可见区内（内容没滚那么远）|

## 四、⇒ 这条对后续的意义

**`Scroll` 越好用，这个坑越常见** —— 因为 `Scroll` 会让底部元素滚出视野，而 `in_game` 判据恰好依赖底部元素。

**⇒ 修法（明天做）：把 `in_game` 放宽为「标题出现 **且** 不是首页」，或增加游戏内的稳定标记（如 `‹` 返回箭头 —— `Matrix Reasoning` 那条备注里就有）。**
**⚠️ 但 `verify_title` 是防「点错游戏」的闸门，放宽它有风险 ⇒ 要配一条单测（构造「只有首页标记」的 dump，确认仍判 False）。**

## ⇒ 判据（`2603`）

**「某个模板（`Scroll`）让某款游戏测失败」时，要先分清是**游戏坏**还是**测量坏**。**
**⇒ 判据：若失败备注里含有本该匹配的标题，那就是测量判据的问题，不是游戏的问题。**

**⇒ 我今天差点把它记成「`Scroll` 不是万能」——实际是「测量工具的 `in_game` 依赖可见性」。**

## ⇒ 判据（`2604`）

**而 `verify_title` 这种「用某个 UI 元素存在与否来判状态」的启发式，天然与 `Scroll`/懒加载冲突**（因为它们的可见性随滚动变化）。
**⇒ 判据：任何依赖「某元素在 dump 里」的判据，都要在引入 `Scroll`/懒加载后重新验证一遍。**
