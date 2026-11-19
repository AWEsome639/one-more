/**
 * 本地知识库（倒排索引）自检 —— 判据 `3062`
 *
 * ★ 触发：`aa start -b com.andrewoscar.onemore -a EntryAbility --ps ragTest true`
 *   ⇒ 结果只进 hilog（tag `RAGTEST`），默认**不触发**、不影响正常启动。
 *   照 `MindSporeSelfTest` / `QwenBpeSelfTest` 的同一套写法。
 *
 * ★ 铁律（与那两支自检一致）：**任何路径都不抛异常**，失败只记 `reason`。
 *
 * ★ 这一步只验证「建库 → 加工 → 检索」能不能出东西，**不做 RAG 生成**
 *   —— 生成需要 `rag.ChatLLM`（流式 `streamChat`），那是第二步。
 *
 * 依据：官方 `data-augmentation-rag-demo` + `知识加工` 开发指南（判据 `3062`）。
 */
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { relationalStore } from '@kit.ArkData';
import { knowledgeProcessor, retrieval, rag } from '@kit.DataAugmentationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { LocalLLM } from './LocalLLM';

const TAG: string = 'RAGTEST';
const DB_NAME: string = 'onemore_kb.db';
const TABLE: string = 'game_rule';

/** 三款游戏的规则样本（先各来一句，验证链路通不通） */
const SEED: string[] = [
  "INSERT INTO game_rule (slug, name, rule) VALUES ('shadow_pivot', '影子旋转', '光源顺时针转 90 度，影子也顺时针转 90 度；方块绕中心旋转后位置改变。')",
  "INSERT INTO game_rule (slug, name, rule) VALUES ('simon_says', '西蒙说', '只有以「西蒙说」开头的指令才照做，没有那三个字就不要动。')",
  "INSERT INTO game_rule (slug, name, rule) VALUES ('collatz', '考拉兹', '偶数的下一步是除以 2，奇数的下一步是乘 3 加 1，一直推到 1。')",
];

export class LocalKRagSelfTest {
  static async run(ctx: common.UIAbilityContext): Promise<boolean> {
    hilog.info(0x0001, TAG, 'RESULT start db=%{public}s table=%{public}s', DB_NAME, TABLE);
    // ★ 顺带报一下「本地对话模型」的真实可用性（判据 3062：声明 ≠ 能用）
    try {
      const llmOk: boolean = LocalLLM.available();
      hilog.info(0x0001, TAG, 'DIAG localChatModel available=%{public}s stat=%{public}s',
        String(llmOk), JSON.stringify(LocalLLM.stat));
    } catch (e) {
      hilog.warn(0x0001, TAG, 'DIAG localChatModel probe threw');
    }
    try {
      // ① 开库：enableSemanticIndex 必须 true、tokenizer 必须 CUSTOM_TOKENIZER（否则不触发加工）
      const storeConfig: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        vector: false,
        tokenizer: relationalStore.Tokenizer.CUSTOM_TOKENIZER,
        enableSemanticIndex: true,
      };
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(ctx, storeConfig);
      hilog.info(0x0001, TAG, 'STEP open-db ok');

      // ② 建表（表名/列名必须与 schema 逐字一致）
      await store.executeSql('CREATE TABLE IF NOT EXISTS ' + TABLE +
        ' (id INTEGER PRIMARY KEY, slug TEXT, name TEXT, rule TEXT);');
      const cur = await store.querySql('SELECT COUNT(*) AS c FROM ' + TABLE);
      let cnt: number = 0;
      if (cur && cur.goToFirstRow()) {
        cnt = cur.getLong(0);
        cur.close();
      }
      hilog.info(0x0001, TAG, 'STEP table ok rows=%{public}d', cnt);
      if (cnt <= 0) {
        for (const sql of SEED) {
          await store.execute(sql);
        }
        hilog.info(0x0001, TAG, 'STEP seed ok n=%{public}d', SEED.length);
      }

      // ★ 诊断：先把三个导出各打一行，分清是「导入为空」还是「模拟器缺实现」
      const kpFn: boolean = knowledgeProcessor.getKnowledgeProcessor !== undefined;
      const rtFn: boolean = retrieval.getRetriever !== undefined;
      const ragFn: boolean = rag.createRagSession !== undefined;
      hilog.info(0x0001, TAG, 'DIAG kpFn=%{public}s rtFn=%{public}s ragFn=%{public}s',
        String(kpFn), String(rtFn), String(ragFn));
      // ③ 加工（只建倒排索引，不建向量）
      const proc = await knowledgeProcessor.getKnowledgeProcessor(ctx, {
        sourceConfig: { rdbSource: storeConfig },
      });
      hilog.info(0x0001, TAG, 'STEP processor ok');
      await proc.startProcess({ mode: knowledgeProcessor.KnowledgeProcessMode.INVERTED_INDEX });
      hilog.info(0x0001, TAG, 'STEP startProcess ok');

      // ④ 等加工完成（最多 20 秒；先看一下状态能不能读到）
      let statusOk: boolean = false;
      for (let i = 0; i < 20; i++) {
        const st = await proc.getStatus();
        hilog.info(0x0001, TAG, 'STEP status i=%{public}d st=%{public}s', i, JSON.stringify(st));
        statusOk = true;
        break;
      }
      if (!statusOk) {
        hilog.warn(0x0001, TAG, 'RESULT fail step=getStatus');
        return false;
      }

      // ⑤ 检索
      const retrievalConfig: retrieval.RetrievalConfig = {
        channelConfigs: [{
          channelType: retrieval.ChannelType.INVERTED_INDEX_DATABASE,
          context: ctx,
          dbConfig: {
            name: DB_NAME,
            securityLevel: relationalStore.SecurityLevel.S1,
            tokenizer: relationalStore.Tokenizer.CUSTOM_TOKENIZER,
          },
        }],
      };
      const retriever: retrieval.Retriever = await retrieval.getRetriever(retrievalConfig);
      hilog.info(0x0001, TAG, 'STEP retriever ok');

      const cond: retrieval.RetrievalCondition = {
        recallConditions: [{
          ftsTableName: TABLE + '_inverted',
          fromClause: TABLE + '_inverted',
          primaryKey: ['chunk_id'],
          responseColumns: ['reference_id', 'chunk_id', 'chunk_source', 'chunk_text'],
          deepSize: 500,
          recallName: 'inv',
        } as retrieval.InvertedIndexRecallCondition],
        resultCount: 5,
      };
      const recs: retrieval.RdbRecords = await retriever.retrieveRdb('影子怎么旋转', cond);
      const items: retrieval.ItemInfo[] = recs ? recs.records : [];
      const n: number = items.length;
      hilog.info(0x0001, TAG, 'RESULT retrieve rows=%{public}d', n);
      if (n > 0) {
        for (let i = 0; i < n && i < 3; i++) {
          const cols: Record<string, relationalStore.ValueType> = items[i].columns;
          const raw = cols['chunk_text'];
          const t: string = raw === undefined || raw === null ? '' : String(raw);
          hilog.info(0x0001, TAG, 'RESULT hit[%{public}d] score=%{public}f text=%{public}s',
            i, items[i].score, t.substring(0, 120));
        }
        hilog.info(0x0001, TAG, 'RESULT PASS');
        return true;
      }
      hilog.warn(0x0001, TAG, 'RESULT fail step=retrieve rows=%{public}d', n);
      return false;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0001, TAG, 'RESULT fail code=%{public}d msg=%{public}s',
        e && e.code ? e.code : -1, e && e.message ? e.message : String(err));
      return false;
    }
  }
}
