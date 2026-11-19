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

---

## 七、★ 官方完整示例已拿到（`21:2x`）—— Step 1 现在是可执行的

来源：`开发指南/Data_Augmentation_Kit_数据增强服务/RAG/完整示例代码/data-augmentation-rag-demo`
（`hms_docs action=read`）

### ① schema 文件的**准确位置**（这是之前唯一缺的东西）

```
src/main/resources/rawfile/arkdata/knowledge/knowledge_schema.json
```

```json
{
  "knowledgeSource": [{
    "version": 1,
    "dbName": "onemore_kb.db",
    "tables": [{
      "tableName": "game_rule",
      "referenceFields": ["id"],
      "knowledgeFields": [
        { "columnName": "name", "type": ["Text"] },
        { "columnName": "rule", "type": ["Text"] },
        { "columnName": "slug", "type": ["Scalar"], "description": "slug" }
      ]
    }]
  }]
}
```

⇒ `dbName` / `tableName` / `columnName` **必须与 `StoreConfig.name` 和建表语句逐字一致**（文档原话）。

### ② 最小流程（只建倒排、不用向量）

```typescript
// 1. 开库（enableSemanticIndex 必须 true，tokenizer 必须 CUSTOM_TOKENIZER）
const storeConfig: relationalStore.StoreConfig = {
  name: 'onemore_kb.db', securityLevel: relationalStore.SecurityLevel.S1,
  vector: false, tokenizer: relationalStore.Tokenizer.CUSTOM_TOKENIZER,
  enableSemanticIndex: true,
};
const store = await relationalStore.getRdbStore(ctx, storeConfig);
await store.executeSql('CREATE TABLE IF NOT EXISTS game_rule (' +
  'id INTEGER PRIMARY KEY, slug TEXT, name TEXT, rule TEXT);');
await store.execute(insertSql);          // 灌 355 款的规则

// 2. 加工（只倒排）
const proc = await knowledgeProcessor.getKnowledgeProcessor(ctx, {
  sourceConfig: { rdbSource: storeConfig }, llm: new LocalChatLLM(),
});
await proc.startProcess({ mode: knowledgeProcessor.KnowledgeProcessMode.INVERTED_INDEX });

// 3. 检索
const retrievalConfig: retrieval.RetrievalConfig = { channelConfigs: [{
  channelType: retrieval.ChannelType.INVERTED_INDEX_DATABASE, context: ctx,
  dbConfig: { name: 'onemore_kb.db', securityLevel: relationalStore.SecurityLevel.S1,
              tokenizer: relationalStore.Tokenizer.CUSTOM_TOKENIZER },
}] };
const retrievalCondition: retrieval.RetrievalCondition = {
  recallConditions: [{
    ftsTableName: 'game_rule_inverted',
    fromClause: 'game_rule_inverted',
    primaryKey: ['chunk_id'],
    responseColumns: ['reference_id', 'chunk_id', 'chunk_source', 'chunk_text'],
    deepSize: 500, recallName: 'inv',
  }],
);
```

⇒ `ftsTableName` 的规律：**表名 + `_inverted`**（示例里 `email` → `email_inverted`）。

### ③ ★ 两个必须改掉的地方（示例工程不能直接用）

| 示例里的做法 | 为什么不能照抄 | 我们怎么做 |
|---|---|---|
| `MyChatLlm` 用 **`http.createHttp()` 调远端 qwen3-32b** | ⚠️ **直接违反「不联网」条款** | 换成 `localChatModel`（见下方）|
| 同时建**向量库**（`_vector.db`）| 需要 embedding 模型，重且慢 | **只建倒排索引**（`INVERTED_INDEX`）|

### ④ `rag.ChatLLM` 的正确实现（用 `localChatModel`，全程端侧）

`rag.ChatLLM` 要求的是**流式**接口：
```typescript
abstract class ChatLLM {
  abstract streamChat(query: string, callback: Callback<rag.LLMStreamAnswer>): Promise<rag.LLMRequestInfo>;
  abstract cancel(chatId: number): void;
}
interface LLMStreamAnswer { isFinished: boolean; chunk: string; }
interface LLMRequestInfo { chatId: number; status: LLMRequestStatus; }
```
⇒ 实现：把 `localChatModel` 的流式回调转成 `LLMStreamAnswer{isFinished, chunk}`，
   失败时返回 `LLMRequestStatus.LLM_REQUEST_ERROR`（**不要抛异常**，否则会话挂住）。

### ⑤ 剩下唯一的未知

`LocalChatLLM` 的具体流式适配还没写；`localChatModel.chat(questionInfo, {isStream:true}, cb)`
的回调签名要照着 `core/LocalLLM.ets` 现有的流式用法写（那里已经有可用的调用样例）。

⇒ **Step 1 的验收不变**：检索结果里能命中灌进去的规则原文（`hilog` 打印出来看）。
