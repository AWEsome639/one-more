# 第 ④ 项（端侧 LLM）**两条路已探明**，而且结论与原来的假设相反

> `2026-11-19 00:20`。全部来自**本机 SDK 的 `.d.ts` 实读**（`hms_api`），不是猜的。

## 一、⇒ 核心结论：两条路**不等价**，且**不必冒升 API 的风险**

| 路线 | 模块 | `@since` | 能力性质 | 需不需要升 target |
|---|---|---|---|---|
| **A. `mindSporeLite`** | `@ohos.ai.mindSporeLite` | **`10`** | **真正的端侧推理**（加载模型 → `predict`）| ❌ **不需要**（当前 `12` 就够）|
| B. `AgentFrameworkKit` | `@kit.AgentFrameworkKit` | **`6.0.0(20)`** | **Agent 编排 / A2A 协议**（`AgentController`、`createA2AServer`）| ✅ 要升到 `20` |

**⇒ ⇒ **原来的假设「`mindSporeLite` 要升到 20」是错的**：它 `@since 10`，**当前 `targetSdkVersion 12` 直接可用**。**

## 二、⇒ `mindSporeLite` 的接口面（`@ohos.ai.mindSporeLite`，`SDK API 26` 实读）

```
loadModelFromFile / FromBuffer / FromFd        ← 三种加载方式
Model { getInputs, predict, resize }
Context / CpuDevice / NNRTDevice               ← 可指定 NPU 加速
getAllNNRTDeviceDescriptions()                  ← **能查本机有没有 NPU**
QuantizationType / PerformanceMode / Priority   ← 量化与调度
MSTensor / DataType / Format                    ← 输入输出张量
```

**⇒ 关键：`syscap = SystemCapability.AI.MindSporeLite` ⇒ 需要在 `module.json5` 声明该 syscap。**

## 三、⇒ 真正的阻塞点**不是 API 版本，是模型文件**

**⇒ `mindSporeLite` 要一个 **`.ms` 模型**；本项目现在**一个模型文件都没有**。**
**⇒ 拿 `.ms` 有两条子路：**
1. **官方现成模型**（HMS 或 MindSpore 模型仓里的 `.ms`）—— 若是「分类/检测」类，**不能**做「AI 代打」这种需要理解题面的活；
2. **自己转**（PyTorch/ONNX → `.ms`，需在本机装 MindSpore 工具链）—— **几 GB 依赖 + 一个转换脚本**，在今天这台 `8 GB` 机器上要慎重排期。

## 四、⇒ `AgentFrameworkKit` 是什么（避免误用）

**⇒ 它导出 `AgentController` / `BaseOptions` / `FunctionController` / `Role` / `Task` / `Message` / `Artifact` / `createA2AServer`**
**⇒ 这是**Agent 编排与 A2A 通信**框架 —— 面向「把任务派给别的 Agent / 云端助手」，**不是本机 LLM 推理**。**
**⇒ 且 `AgentFrameworkKit.json` 写着 `deviceTypes: phone/tablet since 26.0.0` ⇒ 对设备系统版本也有要求。**
**⇒ ⇒ **若 ④ 的目标是「断网也能 AI 代打」，只有 A 路可行**；B 路是联网/多 Agent 场景。**

## 五、⇒ 给奥森的一句话选择

**⇒ 若你要的是「**离线、游戏里就地代打**」⇒ 走 **A（`mindSporeLite`）**，不用升 API，**唯一要解决的是拿一个够用的 `.ms` 模型**。**
**⇒ 若你要的是「**接华为的助手/多 Agent**」⇒ 走 **B**，那要接受 API `12→20` 的迁移风险（`355` 款 + `200,359` 条断言全在 `12`）。**

## ⇒ 判据 `2959`

**⇒ 「某能力要升 API」这个前提，**必须去 `.d.ts` 里读 `@since`** —— 今天这条错误前提（`mindSporeLite` 要 `20`）如果不去读，会让我把一个**零迁移成本**的方案判成「要冒大险」。**
**⇒ ⇒ 顺序：`hms_api modules` 找模块 → `hms_api lookup` 看 `@since`/`syscap` → 再决定要不要升。**
