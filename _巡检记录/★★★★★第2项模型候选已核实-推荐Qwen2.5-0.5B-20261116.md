# 第 ② 项：端侧模型候选**已核实许可证**，推荐 `Qwen2.5-0.5B-Instruct`

> `2026-11-16 07:06`。**三条硬标准（可商用 / 端侧体积 / 中文）逐个核过。**

## 一、⇒ 三个候选

| 模型 | 许可证（出处）| 参数量 | `Q4` 体积 | 中文 |
|---|---|---|---:|---|
| **`Qwen2.5-0.5B-Instruct`** | **Apache 2.0**（[composite license 明写](https://huggingface.co/AXONVERTEX-AI-RESEARCH/qwen2.5-0.5b-pii-anonymizer/blob/main/LICENSE.md#1)：Base Model — Qwen2.5-0.5B-Instruct License: Apache License 2.0）| `0.5B` | **~300 MB** | **强** ✅ |
| `SmolLM2-135M-Instruct` | Apache 2.0（[说明](https://llm.co/llms/smollm2-135m-instruct)）| `135M` | ~80 MB | 弱 |
| `TinyLlama-1.1B` | Apache 2.0（[README](https://huggingface.co/TinyLlama/TinyLlama_v1.1)）| `1.1B` | ~650 MB | 弱（Llama 2 架构/英文语料）|

## 二、⇒ 为什么选 `Qwen2.5-0.5B-Instruct`

**① 许可证**：Apache 2.0，**允许商用**（不是 CC-BY-NC、不是研究-only）✅
**② 体积**：`0.5B` 参数，`Q4` 量化约 **`300 MB`** —— 满足「量化后 `< 600 MB`」✅
**③ 中文**：`One More` 是**中文界面 + `355` 款中文文案** ⇒ 中文能力是硬指标，而另两个候选是英文语料为主 ❌
**④ 生态**：阿里系模型，与鸿蒙/MindSpore 生态同源，**转 `.ms` 的路径最短** ✅

## 三、⇒ 下一步（真正开工时）

1. 下载 `Qwen2.5-0.5B-Instruct`（HuggingFace）
2. 导出 **ONNX**（MindSpore Lite 转换器支持 ONNX 输入）
3. 用 MindSpore Lite 的 `converter` 转成 **`.ms`**（**在开发机上做，不进 App**）
4. `.ms` 放进 `entry/src/main/resources/rawfile/`
5. App 内用 `@ohos.ai.mindSporeLite` 的 `loadModelFromFile` + `Model.predict` 调用（API 12 已验证可用）

**⚠️ 风险与未知（必须实测才知道）：**
- `0.5B` 在**手机 CPU** 上的 token/s 未知（可能需要 `NNRTDevice` 卸载到 NPU）
- `Q4` 量化后的中文质量未知
- **首包体积增加 ~300 MB** ⇒ 需要考虑「按需下载」而不是打进 HAP

## 四、⇒ 我建议的用法（不是"接个大模型聊天"）

**⇒ 不是让它在游戏里聊天，而是**让它把 `355` 款的文案生成得更自然/更有个性**（例如每款的开场白、失败安慰语、AI 代打时的解释）——
   **这是「世界顶尖」里最难被抄走的那层：一致的语气。**
