/**
 * QwenBpeSelfTest —— BPE 分词器的**端侧自检**（2026-11-17，第 ② 项第二步）
 *
 * 目的：证明 `QwenBpeTokenizer` 在真机上**算得对**，而不只是「能编译」。
 *   链路：rawfile → getRawFileContent → TextDecoder → JSON.parse → init → encode → 比对 16 条标准答案
 *
 * 用法（默认没有人调用，只在调试时手动触发）：
 *   import { QwenBpeSelfTest } from './QwenBpeSelfTest';
 *   QwenBpeSelfTest.run(ctx);      // 结果只进 hilog，tag = 'TOKTEST'
 *
 * 通过判据（`hdc shell hilog -x | grep TOKTEST | tail`）：
 *   `TOKTEST RESULT 16/16`
 *
 * ★ 铁律（与 MindSporeSelfTest 一致）：**任何路径都不抛异常**，失败只记 reason。
 * ★ 两个 rawfile 都只是**测试用**：`tokenizer.json`（6.7MB）测完应改为「首启下载到沙箱」，
 *   否则包体白涨 6.7MB。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { QwenBpeTokenizer, VocabJson, MergesJson } from './QwenBpeTokenizer';

const DOM = 0x0001;
const TAG = 'TOKTEST';
const TOKENIZER_RAWFILE = 'tokenizer.json';
const VECTORS_RAWFILE = 'tokenizer_vectors.json';

/** tokenizer.json 里我们只关心 model 段 */
interface TokModel {
  vocab: VocabJson;
  merges: MergesJson;
}
interface TokJson {
  model: TokModel;
}
/** tokenizer_vectors.json 的一条标准答案 */
interface VectCase {
  label: string;
  text: string;
  ids: number[];
  n: number;
  roundtrip_ok: boolean;
  roundtrip_text: string;
}
interface VectJson {
  model: string;
  cases: VectCase[];
}

export class QwenBpeSelfTest {
  /**
   * 跑一次分词器自检。**不抛异常**；结果全部进 hilog（tag `TOKTEST`）。
   * @returns true = 16 条全部一致
   */
  static async run(ctx: Context): Promise<boolean> {
    try {
      const rm = ctx.resourceManager;
      const t0: number = Date.now();
      let tb: Uint8Array;
      let vb: Uint8Array;
      try {
        tb = await rm.getRawFileContent(TOKENIZER_RAWFILE);
        vb = await rm.getRawFileContent(VECTORS_RAWFILE);
      } catch (_e) {
        hilog.error(DOM, TAG, 'rawfile 读不到（%{public}s / %{public}s）',
          TOKENIZER_RAWFILE, VECTORS_RAWFILE);
        return false;
      }
      const dec = util.TextDecoder.create('utf-8');
      const tj: TokJson = JSON.parse(dec.decodeToString(tb)) as TokJson;
      const vec: VectJson = JSON.parse(dec.decodeToString(vb)) as VectJson;
      if (tj === null || tj.model === null || vec === null || vec.cases === null) {
        hilog.error(DOM, TAG, 'JSON 结构不对');
        return false;
      }
      const tk = new QwenBpeTokenizer();
      tk.init(tj.model.vocab, tj.model.merges);
      const tInit: number = Date.now() - t0;

      let pass: number = 0;
      const total: number = vec.cases.length;
      for (let i = 0; i < total; i++) {
        const c: VectCase = vec.cases[i];
        let got: number[] = [];
        let err: string = '';
        try {
          got = tk.encode(c.text);
        } catch (e) {
          err = JSON.stringify(e);
        }
        let ok: boolean = true;
        if (err.length > 0 || got.length !== c.ids.length) {
          ok = false;
        } else {
          for (let k = 0; k < got.length; k++) {
            if (got[k] !== c.ids[k]) {
              ok = false;
              break;
            }
          }
        }
        if (ok) {
          pass++;
        }
        hilog.info(DOM, TAG, '%{public}s %{public}s exp=%{public}d got=%{public}d %{public}s',
          c.label, ok ? 'OK' : 'MISMATCH', c.ids.length, got.length, err);
      }
      const tAll: number = Date.now() - t0;
      hilog.info(DOM, TAG, 'TOKTEST RESULT %{public}d/%{public}d init=%{public}dms total=%{public}dms vocab=%{public}d',
        pass, total, tInit, tAll, Object.keys(tj.model.vocab).length);
      return pass === total;
    } catch (e) {
      // ★ 2026-11-17：`JSON.stringify(Error)` 给出 `{}`（属性不可枚举）⇒ 取 message
      const msg: string = (e as Error).message !== undefined ? (e as Error).message : String(e);
      hilog.error(DOM, TAG, '异常 %{public}s', msg);
      return false;
    }
  }
}
