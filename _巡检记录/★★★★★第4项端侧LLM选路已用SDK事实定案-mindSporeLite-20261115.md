# 第 ④ 项（端侧 LLM）：**用 SDK 事实定案 —— 选 `mindSporeLite`**

> `2026-11-15 19:03`。**之前一直「待奥森选路」，其实查两行 `@since` 就能定。**

## 一、⇒ 两个候选的硬事实（从已装 SDK 的 `.d.ts` 读出）

| API | 声明文件 | `@since` | 与当前 `compatibleSdkVersion = 12` |
|---|---|---:|---|
| **`mindSporeLite`** | `@ohos.ai.mindSporeLite.d.ts` | **`10`** | ✅ **已支持，零改动** |
| **`AgentFramework`** | `@ohos.app.agent.AgentExtensionAbility.d.ts` | **`24`** | ⛔ 需把 `compatibleSdkVersion` 抬到 `24` |

**⇒ 顺带纠正我旧笔记：「`AgentFramework` 需 target `12→20`」—— 实际是 **API `24`**（不是 `20`）。**

## 二、⇒ 为什么选 `mindSporeLite`

**1. **零版本改动**：`@since 10` ≤ 当前 `12` ⇒ 不需要动 `compatibleSdkVersion`、不动 `targetSdkVersion`（已是 `26.0.0`）。**
**2. **不动基线**：`200,359` 条断言、`17` 款修复的全部测量前提都不受影响。**
**3. **反观 `AgentFramework`**：要抬到 API `24` ⇒
   - 全部 `200,359` 条断言的运行环境改变
   - 今天 `17` 款修复的测量值全部作废（判据 `2613` 的极端情形）
   - 放弃对 API `12`–`23` 设备的支持
   **⇒ 成本极高、而收益（Agent 能力）在当前「只做一个提示/代打」的需求下并不需要。**

## 三、⇒ 唯一的门槛：模型格式

**`mindSporeLite` 需要 **`.ms`** 格式模型；我之前删掉的那个 `gemma-3n-E4B-it-Q4_K_M.gguf` 是 `.gguf`（**格式不对**，本来也用不上）。**

**⇒ 所以要做第 ④ 项，需要：① 找一个可商用的小 `.ms` 模型（如 MindSpore 官方示例的 MobileNet/TinyLlama 转换版）② 放进 `resources/rawfile` ③ 用 `mindSporeLite` 加载。**

**⚠️ 这一步**没有现成资产**，需要下载并确认许可证 —— 属于「新工作」，不是「改个开关」。**

## ⇒ 判据（`2747`）

**「某个能力该不该上」这类决策，先去 **SDK 的 `.d.ts` 里读 `@since`**，不要在笔记或二手推断里绕。**
**⇒ 今天这条：我一直把第 ④ 项写成「待奥森选路（API 10 vs 20）」—— 事实是 `10` vs `24`，
   而「`24`」这个数字直接决定了它**不可行**（会动全库基线与设备兼容性）。**
**⇒ 与判据 `2146`/`2739` 同源：**先查源码/原文，再谈取舍。**
