# 判据 3051：奥森要的「最强能力」**是 `RAG` 栈**，不是 `AgentFrameworkKit`

## 一、查 SDK 的结果

`/Applications/DevEco-Studio.app/Contents/sdk/default/hms/ets/kits` 里只有三个 AI kit：

| kit | `@since` | 用途 |
|---|---|---|
| **`@kit.DataAugmentationKit`** | **`6.0.0(20)`** | 导出 **`retrieval` · `rag` · `knowledgeProcessor` · `localChatModel`** |
| `@kit.AgentFrameworkKit` | `6.0.0(20)` | `AgentController` · `createA2AServer` · `FunctionController` —— **A2A 智能体编排**，不是问答模型 |
| `@kit.EnterpriseDataGuardKit` | — | 数据防护，与 AI 能力无关 |

⇒ **`AgentFrameworkKit` 是「智能体之间互相调用」的框架**，它不会让「提示」这个功能变聪明。
⇒ **真正能让它变聪明的是 `DataAugmentationKit` 里现在没用到的三件：`retrieval` + `rag` + `knowledgeProcessor`。**

## 二、所以「换最强」的具体含义

**现在**（`LocalLLM.ets`，11 天前就做完了）：只用 `localChatModel` —— **裸问答**，
模型凭自己的参数回答「这题怎么解」。

**API 20 能给的**：
```
retrieval.getRetriever(config)      ← 本地知识库检索（SystemCapability.DataAugmentation.Retrieval）
knowledgeProcessor                  ← 文档切分/入库（SystemCapability.DataAugmentation.KnowledgeProcessor）
rag                                 ← 检索 + 生成串起来
```
⇒ 可以把 `355` 款游戏的**规则、解法、易错点**做成知识库，让提示**引用真实规则**而不是靠模型瞎编。
⇒ 这是**能力的档次差**，不是参数差。

## 三、★ 顺手发现一个潜在崩溃（已修）

`@hms.data.localChatModel.d.ts` 是 **`@since 6.0.0(20)`** ——
而工程原来写 `compatibleSdkVersion: "5.0.0(12)"`。

⇒ `compileSdkVersion` 是 `26`，所以**编译一直能过**；
⇒ 但装到 `5.x`（API 12–19）的机器上，`localChatModel` 这个 API **运行时不存在** ⇒ 会挂。

⇒ 刚才把 `compatibleSdkVersion` 抬到 `6.0.0(20)` **顺手把这个隐患修掉了**：
   现在清单声明的下限 = 实际用到的 API 下限。

⇒ 这也解答了 `3020` 那条挂着的「verify LLM syscap on a live device」——
   **清单层已经对齐，剩下的是设备层 syscap 是否真的存在**（需要真机/模拟器验证）。

## 四、下一步（按代价排序）

| 序 | 事 | 需要什么 | 状态 |
|---|---|---|---|
| 1 | `compatibleSdkVersion → 6.0.0(20)` | 编译 | ✅ **已完成**（`BUILD SUCCESSFUL`、断言 `200359/0`）|
| 2 | 验证设备上有 `DataAugmentation.*` 三个 syscap | **真机或模拟器**（`param get const.product.syscap`）| ⬜ 待做 |
| 3 | 把游戏规则做成知识库 + 接 `retrieval`/`rag` | 大量代码 + 真机验证 | ⬜ 待做 |
| 4 | `AgentFrameworkKit`（A2A 编排）| 与本项目「提示」功能关系不大 | ⏸ **暂不需要** |

⇒ **`4` 是被排除的**：它是「智能体互相调用」，不是「模型更聪明」。
   奥森要的是后者 ⇒ 走 `2`、`3`。

## 五、判据

> **「换更强能力」要先问「强在哪一维」**：同一个 kit 里可能既有「更强」（`rag`/`retrieval`）、
> 也有「更强但无关」（`AgentFrameworkKit` 的 A2A）。**按需求那一维选，不按名字里的「Agent/AI」选。**

⇒ 三条：
1. **列 SDK 的 kit 清单再看导出**，不要凭 kit 名字猜能力
2. **看 `@syscap`** —— `DataAugmentation.Retrieval` / `.KnowledgeProcessor` 是**设备能力**，
   不是「有 API 就能用」，必须在目标设备上确认存在
3. **`@since` 与 `compatibleSdkVersion` 必须对齐** —— 不一致时编译能过、运行时崩（今天这个例子）
