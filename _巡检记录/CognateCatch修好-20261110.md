# `Cognate Catch` 修好（`1600 → 1481`，`OK`）

## 为什么它在上一批里被漏掉

**上一批（`visibility` 42 款）的过滤条件是**：
```python
if '.visibility(Bp.isShort()' in s: break   # 「这个文件已经处理过」→ 跳过
```
**⇒ `Cognate Catch` 文件里确实已有 `.visibility(` —— 但那是在「说明行」上，不在「重开」按钮上**。
**⇒ 整文件被跳过，「重开」一直没处理。**

## 这一刀

```ts
Button(TG('重开'))
  .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```

**⇒ `1600 → 1481`（`OK`）**，`lowest` 变成「同源 ✅」（判定结果文字，正常）

## 判据 1880（立）

> **批量的「跳过条件」必须按「元素」判断，不能按「文件」。**
> **一个文件里可能已经处理了 A 元素、但 B 元素还没处理** ——
> **按文件跳过 = 永远漏掉 B。**

**依据**：`Cognate Catch` 的说明行已加 `visibility`（所以文件被跳过），
**而「重开」按钮一直裸着** ⇒ **今晚至少有一批同类被漏**（凡「文件里先加了说明行 `visibility`」的款）。

**⇒ 修复方法**：跳过条件改成「该元素的插入点相邻是否有 `visibility`」，或干脆**幂等检查（看插入点上下文）**。
