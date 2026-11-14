# ★★ 改 `44 × N` 不会破那八把断言（已核对 `layout_guard`）

> `2026-11-14 14:4x`。明晚要改代码，先确认不撞断言。

## 一、八把断言各查什么

```
check_dup_symbol.py     双符号
check_focusable.py      焦点
check_hud_consistency.py HUD 一致
check_key_coverage.py   key 覆盖
check_layout_guard.py   **布局守卫**（唯一与宽高相关）
check_plural_forms.py   复数
check_reset_leak.py     复位遗漏
check_rtl.py            RTL 陷阱
check_state_from_text.py 内容当状态
```

**⇒ 只有 `layout_guard` 与我的改法相关。**

## 二、⇒ `layout_guard` 的规则

```python
"""静态守卫：`width('100%') + aspectRatio(X)` 必须配高度上限。
来历（2026-10-31）：真机在 853×533 横屏上连抓三次「内容被裁」…
判据：**宽驱动必须配高度上限**（maxHeight 或 maxWidth）。
```

**⇒ 它查的正是我今天诊断的那一类问题：宽度驱动高度 ⇒ 矮屏溢出。**
**⇒ 而它要求的解法就是「配一个上限」。**

## 三、⇒ 我的改法为什么安全

**`GSkyscrapers` 现状：**
```ts
723|  ForEach([0..5], (gc) => {
724|    Stack() { … }
730|      .layoutWeight(1)          ← 宽度由父容器分配
731|      .aspectRatio(1)           ← 高度 = 宽度
749|  .width(Math.min(Bp.width - 2*Space.lg, Math.max(240, Bp.height - 360)))  ← **有上限**
```

**⇒ 那个 `.width(Math.min(...))` **就是 `layout_guard` 要的上限** ⇒ 现状通过（断言 `0` ✅）。**

**⇒ 我的改动只把 `Math.max(240, …)` 换成 `Math.max(44*(4+2), …)` ⇒ **上限仍在** ⇒ 仍通过。**

**✅ 所以明晚的改动不会破断言。**

## ⇒ 判据（`2273`）

**改代码前，先看断言**查的是不是同一件事** —— 若查的正是你要修的那类，你的改法很可能天然合规。**
**⇒ 这次 `layout_guard` 的 docstring 里三次真机案例（围棋 `maxWidth 300`、华容道撑到 `813vp`、四子棋）
与我今天诊断的「盘面撑高把下面挤出去」是**同一个病**。**

**⇒ 判据：断言脚本的 docstring 往往写着「这条规则是为了防哪次事故」——
⇒ 读它，就能知道你的改法是在**顺着**那条规则还是在**绕过**它。**

## ⇒ 判据（`2274`）

**`all 0` 的断言不等于「代码没问题」，只等于「这 8 类问题都没有」。**
**⇒ 今天我查的「盘面被挤出行」不在那 8 类里（`layout_guard` 只查「有没有上限」，不查「上限值对不对」）
⇒ 所以 `200359 / 0` 与「盘面只露 1 行」可以**同时成立**。**

**⇒ 判据：绿色断言只覆盖它那 8 类；不要用它证明「没问题」。
⇒ 而它的 `docstring` 会告诉你它的**边界**在哪。**
