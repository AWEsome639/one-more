# 第 ⑤ 项（电视）：短板在代码里**已证实**，且定位到具体一行

> `2026-11-19 00:30`。objective 里那句「`Cell` 有 `Bp.scale()×1.45` 而 `FontSize/Space/Radius` 完全不放大」——**我把它核实了**。

## 一、⇒ 核实结果：**属实**

**⇒ `core/Design.ets:24` 的 `FontSize` 是**纯固定常量**：**
```ts
class FontSize {
  static hero = 36;  static xxl = 24;  static xl = 20;  static lg = 18;
  static md = 16;    static sm = 14;   static xs = 13;  static xxs = 12;
}
```
**⇒ `Space`（`xs 6 / sm 10 / md 16 …`）与 `Radius` 同样**没有任何 `Bp.scale()` 乘法**。**

**⇒ 而 `core/Bp.ets:97`：`if (Bp.dev === BpDev.TV) { return 1.45; }`**

**⇒ ⇒ 电视上：格子/按钮/触控区 ×`1.45`，文字 ×`1.00` ⇒ **文字相对小 `1 − 1/1.45 = 31%`**。**
**⇒ 若再算上 3 米视距（手机 ~0.3 m），**实际观感差距远大于 31%** —— 这正是 objective 说的「3 米外短板是文字」。**

## 二、⇒ 项目里已有的 TV 支持（比想象的多，但都绕开了字号）

| 位置 | 内容 |
|---|---|
| `module.json5` | `deviceTypes` **已含 `"tv"`** ⇒ 不用改清单 |
| `core/Tv.ets` | 焦点框 / 方向键导航（`Tv.on()` / `Tv.focusOutline()`）|
| `Tv.on()` 的条件 | `Bp.isTv() \|\| Bp.isDesktop() \|\| Bp.isLg()` ⇒ 大屏与桌面也走 TV 交互 |
| `core/Design.ets:114` | `Bp.height < 600 && !Bp.isTv()` ⇒ **矮屏降档明确排除了 TV** |
| `components/GamesTab.ets:738` | TV 上 4 列（手机 2 列）|

**⇒ 全库只有 `5` 个文件提到 `isTv()` ⇒ **TV 适配集中在布局与焦点，**从未处理过字号**。**

## 三、⇒ 修法（不能全局改，会伤手机）

**⇒ ⛔ 直接把 `FontSize` 常量乘 `1.45` ⇒ **手机/平板全部变大** ⇒ 绝对不行。**
**⇒ 正确做法有两种：**

**A. 初始化时按设备算一次（推荐）**
```ts
// Design.ets 的 FontSize 改成运行时算：
private static k(): number { return Bp.isTv() ? 1.45 : 1.0; }
static md: number = Math.round(16 * FontSize.k());
```
**⇒ 注意：`static` 字段**初始化一次** ⇒ 必须在 `Bp.dev` 定下来之后才求值 ⇒ 要确认 `Bp.dev` 在模块加载前已赋值（否则取到默认 `phone`）。**

**B. 用 `Tv.fs(base)` 包装（更安全）**
**⇒ 在 `core/Tv.ets` 加 `static fs(base: number): number { return Bp.isTv() ? Math.round(base * 1.45) : base; }`，各处改用 `Tv.fs(FontSize.md)`。**
**⇒ 优点：**显式、可控、可逐处验证**；缺点：要改 `355` 款里的字号引用点（量大）。**

**⇒ 折中：先只改「游戏内的关键文字」（题面/线索/目标），不改全局 `FontSize`。**

## 四、⇒ 为什么今晚不动

**⇒ 字号是**全屏可见**的改动，`355` 款 + `200,359` 条断言 ⇒ **任何一处手滑都会让手机端文字错位**。**
**⇒ 而验证它必须**真的在电视上跑**（`1280×720vp` 的模拟器镜像，几 GB 下载）。**

## ⇒ 判据 `2960`

**⇒ 「大屏适配」最容易被漏掉的**不是尺寸，是**比例**：布局会跟着缩放系数走，**字号/间距/圆角常常是写死的常量** ⇒ 结果是「东西变大了，字没变大」。**
**⇒ ⇒ 检查方法：`grep` 设计令牌的定义体，看**哪些乘过缩放系数、哪些没有** —— 今天就是这一个 grep 把 ⑤ 的短板从「听说」变成「证实」。**
