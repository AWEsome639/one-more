# 端侧 RAG：**能力已验证在设备上存在 + 接入方案**

## 一、设备能力验证（`3051` 悬着的那一条，已闭环）

从模拟器拉 `/system/etc/syscap.json`（`38,495` 字节、`385` 个 cap）逐项查：

| syscap | 结果 |
|---|---|
| `SystemCapability.DataAugmentation.RAG` | ✅ |
| `SystemCapability.DataAugmentation.Retrieval` | ✅ |
| `SystemCapability.DataAugmentation.KnowledgeProcessor` | ✅ |
| `SystemCapability.DataAugmentation.LocalChatModel` | ✅（现在就在用）|
| `SystemCapability.DataAugmentation.GraphStore` | ✅ |
| `SystemCapability.AI.MindSporeLite` | ✅（`ModelRunner` 在用）|
| `SystemCapability.AI.GenerateAI.LLM` | ✅ |
| `SystemCapability.AI.Agent.AgentKit` | ✅ |

设备：`emulator`，API `26`（≥ `20` ⇒ 版本也够）。

⇒ **两种 `param get const.product.syscap` 都拿不到**（返回 `errNum 106` / 不存在），
   **权威来源是 `/system/etc/syscap.json`** —— 记下来，以后别再走 `param get` 那条路。

## 二、现有两条端侧 AI 路径（不要混）

| 文件 | 用什么 | 干什么 |
|---|---|---|
| `core/LocalLLM.ets`（`230` 行）| **`localChatModel`**（`DataAugmentationKit`）| 游戏里的「提示 / AI 代打」问答 |
| `ai/ModelRunner.ets`（`213` 行）+ `ai/TinyMlp.ets` | **`mindSporeLite`** | 棋力评估这类小模型（2048 估值等）|

⇒ RAG 要接的是**第一条**（`LocalLLM`），不是第二条。

## 三、RAG 的三步接口（都从 SDK `.d.ts` 读出来的）

### ① 建库 —— `@hms.data.knowledgeProcessor`
```
getKnowledgeProcessor(context: common.BaseContext, config: KnowledgeProcessorConfig)
interface KnowledgeProcessorConfig / KnowledgeSourceConfig / KnowledgeProcessConfig
enum ProcessorStatus · enum KnowledgeProcessMode
cleanKnowledgeData(context, config)          // 清库
interface ChatLLM                            // ★ RAG 需要的模型接口，要自己实现或适配
```

### ② 检索 —— `@hms.data.retrieval`
```
getRetriever(config: RetrievalConfig): Promise<Retriever>
interface RetrievalCondition / ChannelConfig / enum ChannelType
enum Bm25Strategy · InvertedIndexRecallCondition · FilterInfo · enum Operator
```

### ③ 生成 —— `@hms.data.rag`
```
createRagSession(context: common.Context, config: Config): Promise<RagSession>
interface Config { llm: ChatLLM; retrievalConfig: retrieval.RetrievalConfig;
                   retrievalCondition: retrieval.RetrievalCondition }
interface RagSession { streamRun(question, RunConfig, cb): Promise<number>;
                       cancel(runId); close() }
feedback(context, FeedbackInfo)
```

## 四、落地方案（三步，按可验证性排序）

### Step 1（最小可验证）：把「一款游戏的规则」做成库，能检索出来
1. 新建 `core/LocalRAG.ets`，形状照 `LocalLLM.ets`（`init()` + `stat` + 超时回落）
2. 用 `getKnowledgeProcessor` 灌**一段静态文本**（比如 `Shadow Pivot` 的规则 + 易错点）
3. 用 `getRetriever` + `RetrievalCondition` 检索「旋转 90 度后影子怎么变」
4. **验收**：检索结果里能命中那段规则的原文（打印出来看，不看就下结论）

### Step 2：把 `355` 款的规则批量灌库
- 规则文本来源：每款游戏文件里的注释/字符串常量（`G*.ets` 的 `RULE`/`HOW_TO`/`MSG` 之类）
- **先统计**：`355` 个文件里到底有多少款有可用的规则文本 ⇒ 没有的先不灌（不许编）
- 灌库放在**首次进入游戏时懒加载**，不在启动时做（`355` 款全灌会拖慢冷启动）

### Step 3：接进提示链路
- `Hint.ets` 现在走的是规则兜底 → `LocalLLM` 问答
- RAG 版：**先检索再问** —— 把检索到的规则片段作为上下文喂给模型
- **必须保留原来的降级链**：`no-syscap` → `init 失败` → `超时` → `规则兜底`
  （`LocalLLM.ets` 里已有的那四级一个都不能少，RAG 只是**多一层**，不是替换）

## 五、风险与红线

| 风险 | 处理 |
|---|---|
| **破坏现有提示** | RAG 走**新文件**，`LocalLLM.ets` 不动；开关控制 |
| **拖慢冷启动** | 灌库懒加载 + 后台；不许在 `EntryAbility.onCreate` 里做 |
| **不联网条款** | `retrieval`/`rag`/`knowledgeProcessor` **全是端侧**（`DataAugmentation` 是设备能力）⇒ 隐私声明不用改 |
| **`ChatLLM` 要自己实现** | 先看 `localChatModel` 能不能直接满足；不行就写一个薄适配层 |
| **机器 `8 GB`** | 灌库 + 编译 + 模拟器同开有风险 ⇒ 分步做，每步一编译一验证 |

## 六、判据

> **「能力更强」要先验证「设备上真的有这个能力」** —— `3051` 说要验 syscap，
> 今天验了：**六项 `DataAugmentation` 能力全在**。这一步花 `10` 分钟，省掉的是「写完才发现跑不起来」。

⇒ 三条：
1. **`param get const.product.syscap` 在模拟器上不可靠**（`errNum 106`）⇒ **用 `/system/etc/syscap.json`**
2. **先分清有两条 AI 路径**（`localChatModel` vs `mindSporeLite`）⇒ 别接到错的那条上
3. **RAG 只加一层、不替换降级链** —— `LocalLLM` 已有的四级回落一条都不能删
