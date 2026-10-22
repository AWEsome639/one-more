/**
 * TinyMlp —— 手写小网络推理（2026-10-23，路线 B）
 *
 * ★★★ 为什么不用 MindSporeLite / .ms：
 *   SDK 里没有 converter_lite，也拿不到样例 .ms（试过两个官方地址都 404）。
 *   但「11 维 → 12 隐层 → 1 输出」这种网络**根本不需要框架**：
 *   它就是一串乘加 + 一个 ReLU。
 *
 *   换掉转换链换来：
 *     · 零依赖（不依赖 syscap、不依赖 .ms 格式版本）
 *     · 零体积代价（权重 JSON 2.7 KB，比 .ms 还小）
 *     · 可读可审计（权重是明文数字，任何人能验）
 *     · 调试直白（错在哪一行算得上）
 *   代价：只能跑**小到能手写**的网络。等到路线 C 要跑 CNN 时，
 *        还是得回到 ModelRunner + .ms —— 那条路已经在上一轮铺好了。
 *
 * 权重格式（由 工具/train_sudoku_diff.py 生成）：
 *   { inDim, hidden, featureMean[], featureStd[], W1[hidden][inDim], b1[hidden], W2[hidden], b2 }
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'TinyMlp';

/** 与训练脚本导出的 JSON 一一对应 */
export interface MlpWeights {
  kinds: string;
  inDim: number;
  hidden: number;
  featureMean: number[];
  featureStd: number[];
  W1: number[][];
  b1: number[];
  W2: number[];
  b2: number;
}

export class TinyMlp {
  private w: MlpWeights | null = null;
  private ok: boolean = false;
  private reason: string = 'idle';

  /** 从 JSON 文本装载。失败只改状态，不抛。 */
  loadFromJson(text: string): boolean {
    try {
      const o: MlpWeights = JSON.parse(text) as MlpWeights;
      if (o.inDim <= 0 || o.hidden <= 0) {
        this.reason = 'bad-weights';
        return false;
      }
      if (o.W1 === undefined || o.W1.length !== o.hidden) {
        this.reason = 'bad-weights';
        return false;
      }
      if (o.featureMean === undefined || o.featureMean.length !== o.inDim) {
        this.reason = 'bad-weights';
        return false;
      }
      this.w = o;
      this.ok = true;
      this.reason = 'ok';
      hilog.info(0x0000, TAG, '装载成功 %{public}d→%{public}d→1', o.inDim, o.hidden);
      return true;
    } catch (e) {
      this.ok = false;
      this.reason = 'parse-failed';
      hilog.error(0x0000, TAG, '权重解析失败: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  isReady(): boolean {
    return this.ok && this.w !== null;
  }

  statusReason(): string {
    return this.reason;
  }

  /**
   * 前向：标准化 → ReLU(隐层) → 线性 → 1 个数
   * 返回 null 表示不可用（调用方必须能接受）
   */
  predict(features: number[]): number | null {
    const w: MlpWeights | null = this.w;
    if (w === null || !this.ok) {
      return null;
    }
    if (features.length !== w.inDim) {
      hilog.warn(0x0000, TAG, '特征维度不符：要 %{public}d 给 %{public}d',
        w.inDim, features.length);
      return null;
    }
    try {
      // ① 标准化（必须用训练时的 mean/std，不能重新算）
      const x: number[] = new Array<number>(w.inDim);
      for (let i = 0; i < w.inDim; i++) {
        const sd: number = w.featureStd[i] === 0 ? 1 : w.featureStd[i];
        x[i] = (features[i] - w.featureMean[i]) / sd;
      }
      // ② 隐层 ReLU
      let out: number = w.b2;
      for (let j = 0; j < w.hidden; j++) {
        const row: number[] = w.W1[j];
        let s: number = w.b1[j];
        for (let i = 0; i < w.inDim; i++) {
          s += row[i] * x[i];
        }
        if (s > 0) {                       // ReLU
          out += w.W2[j] * s;
        }
      }
      return out;
    } catch (e) {
      return null;
    }
  }
}
