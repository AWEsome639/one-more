/**
 * MindSporeSelfTest —— 端侧推理链路的**最小自检**（2026-11-13）
 *
 * 目的：在换「0.5B LLM」之前，先证明这条链**通**：
 *   `rawfile` → `getRawFileContent` → `loadModelFromBuffer` → `getInputs` → `setData` → `predict` → `getData`
 *
 * 用法（默认**没有人调用**，只在调试时手动触发）：
 *   import { MindSporeSelfTest } from './MindSporeSelfTest';
 *   MindSporeSelfTest.run(ctx);    // 结果只进 hilog，tag = 'LLMTEST'
 *   （`ctx` 从调用方传入 —— ArkTS strict 下静态方法里不能用 `getContext(this)`）
 *
 * 通过判据（`hdc shell hilog -x | grep LLMTEST`）：
 *   `LLMTEST ok outputs=1 bytes=1000`
 *   ⇒ MobileNetV2 的输出是 `1×1000`（float32 ⇒ `4000` bytes；若报 `1000` 说明是 uint8 量化输出，同样算通）
 *
 * ★ 铁律（与 LocalLLM 一致）：**任何路径都不抛异常**，失败只记 reason。
 * ★ 模型不进包：`mobilenetv2.ms` 只是**测试用**，测完删，正式方案是「首启下载到沙箱」。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';

const DOM = 0x0001;
const TAG = 'LLMTEST';
/** 测试模型的 rawfile 名（放在 entry/src/main/resources/rawfile/ 下） */
const MODEL_RAWFILE = 'mobilenetv2.ms';
/** MobileNetV2 输入：1×224×224×3 float32 */
const IN_N = 1 * 224 * 224 * 3;

export class MindSporeSelfTest {
  /**
   * 跑一次链路自检。**不抛异常**；结果全部进 hilog（tag `LLMTEST`）。
   * @returns true = 链路通（`predict` 返回了至少一个输出张量）
   */
  static async run(ctx: Context): Promise<boolean> {
    let t0: number = Date.now();
    try {
      const rm = ctx.resourceManager;
      let bytes: Uint8Array;
      try {
        bytes = await rm.getRawFileContent(MODEL_RAWFILE);
      } catch (e) {
        hilog.error(DOM, TAG, 'fail step=read-rawfile name=' + MODEL_RAWFILE);
        return false;
      }
      hilog.info(DOM, TAG, 'ok step=read-rawfile bytes=' + String(bytes.length));

      let m: mindSporeLite.Model;
      try {
        m = await mindSporeLite.loadModelFromBuffer(bytes.buffer as ArrayBuffer);
      } catch (e) {
        hilog.error(DOM, TAG, 'fail step=loadModelFromBuffer');
        return false;
      }
      hilog.info(DOM, TAG, 'ok step=loadModelFromBuffer ms=' + String(Date.now() - t0));

      const inputs: mindSporeLite.MSTensor[] = m.getInputs();
      hilog.info(DOM, TAG, 'ok step=getInputs n=' + String(inputs.length));
      if (inputs.length === 0) {
        hilog.error(DOM, TAG, 'fail step=getInputs empty');
        return false;
      }

      // 填零输入（只为跑通链路，不关心推理正确性）
      try {
        inputs[0].setData(new Float32Array(IN_N).buffer as ArrayBuffer);
      } catch (e) {
        hilog.error(DOM, TAG, 'fail step=setData');
        return false;
      }

      let outs: mindSporeLite.MSTensor[];
      try {
        outs = await m.predict(inputs);
      } catch (e) {
        hilog.error(DOM, TAG, 'fail step=predict');
        return false;
      }
      if (outs.length === 0) {
        hilog.error(DOM, TAG, 'fail step=predict no-output');
        return false;
      }

      let n: number = 0;
      try {
        n = outs[0].getData().byteLength;
      } catch (e) {
        n = -1;
      }
      hilog.info(DOM, TAG, 'ok outputs=' + String(outs.length) + ' bytes=' + String(n) +
        ' total=' + String(Date.now() - t0));
      return true;
    } catch (e) {
      hilog.error(DOM, TAG, 'fail step=unexpected');
      return false;
    }
  }
}
