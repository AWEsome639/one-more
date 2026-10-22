/**
 * G2048Value —— 2048 局面价值网络（2026-10-23，路线 C）
 *
 * ★★★ 这与 SudokuDifficulty 是同一套思路的第二次应用：
 *   小网络不需要任何框架，权重导成 JSON，ArkTS 手写前向。
 *
 * 网络做什么：给定 4×4 局面，预测「接下来 30 步还能拿多少分」的 log 值。
 * 为什么这个量有用：不用它也能玩（有启发式），但**用它做一步前瞻更准** ——
 *   对 4 个方向各算滑动后的局面，选 V 最大的那个。
 *   V 是学出来的，能捕捉到启发式没写进去的模式（比如"留空隙的形状"）。
 *
 * ⚠️ 2048 是单人游戏，这里的「策略」不是对手 AI，而是**提示**：
 *   卡住时按提示，程序给出它认为最优的一步。
 *
 * ★ 铁律：模型不可用 ⇒ bestMove 返回 -1 ⇒ 界面回落到原有启发式，绝不卡死。
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TinyMlp } from './TinyMlp';

const TAG: string = 'G2048Value';
const RAW_NAME: string = 'g2048_value.json';
const N: number = 4;

/**
 * 24 维特征 —— 必须与 工具/train_2048_value.py 的 features() 逐项一致。
 * 顺序不能动，改一处就要重新训、重新对拍。
 */
export function g2048Features(cells: number[]): number[] {
  const f: number[] = new Array<number>(24);
  for (let i = 0; i < 24; i++) {
    f[i] = 0;
  }
  // 0-15 每格的 log2(v)/17
  for (let i = 0; i < 16; i++) {
    const v: number = cells[i];
    if (v > 0) {
      const lg: number = Math.log2(v);
      f[i] = lg / 17.0 > 1 ? 1 : lg / 17.0;
    }
  }
  let mx: number = 0;
  let empty: number = 0;
  for (let i = 0; i < 16; i++) {
    if (cells[i] > mx) {
      mx = cells[i];
    }
    if (cells[i] === 0) {
      empty++;
    }
  }
  // 16 最大块
  f[16] = mx > 0 ? Math.min(1, Math.log2(mx) / 17.0) : 0;
  // 17 空格数
  f[17] = empty / 16.0;

  // 18 行单调性
  let mono: number = 0;
  for (let r = 0; r < N; r++) {
    let d1: number = 0;
    let d2: number = 0;
    for (let c = 0; c < N - 1; c++) {
      const a: number = cells[r * N + c] > 0 ? Math.log2(cells[r * N + c]) : 0;
      const b: number = cells[r * N + c + 1] > 0 ? Math.log2(cells[r * N + c + 1]) : 0;
      if (a - b > 0) {
        d1 += a - b;
      }
      if (b - a > 0) {
        d2 += b - a;
      }
    }
    mono += Math.min(d1, d2);
  }
  f[18] = Math.min(1, mono / 40.0);

  // 19 列单调性
  mono = 0;
  for (let c = 0; c < N; c++) {
    let d1: number = 0;
    let d2: number = 0;
    for (let r = 0; r < N - 1; r++) {
      const a: number = cells[r * N + c] > 0 ? Math.log2(cells[r * N + c]) : 0;
      const b: number = cells[(r + 1) * N + c] > 0 ? Math.log2(cells[(r + 1) * N + c]) : 0;
      if (a - b > 0) {
        d1 += a - b;
      }
      if (b - a > 0) {
        d2 += b - a;
      }
    }
    mono += Math.min(d1, d2);
  }
  f[19] = Math.min(1, mono / 40.0);

  // 20 平滑度
  let sm: number = 0;
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N - 1; c++) {
      const a: number = cells[r * N + c] > 0 ? Math.log2(cells[r * N + c]) : 0;
      const b: number = cells[r * N + c + 1] > 0 ? Math.log2(cells[r * N + c + 1]) : 0;
      sm += Math.abs(a - b);
    }
  }
  for (let c = 0; c < N; c++) {
    for (let r = 0; r < N - 1; r++) {
      const a: number = cells[r * N + c] > 0 ? Math.log2(cells[r * N + c]) : 0;
      const b: number = cells[(r + 1) * N + c] > 0 ? Math.log2(cells[(r + 1) * N + c]) : 0;
      sm += Math.abs(a - b);
    }
  }
  f[20] = Math.min(1, sm / 60.0);

  // 21 可合并对数
  let merges: number = 0;
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N - 1; c++) {
      const a: number = cells[r * N + c];
      const b: number = cells[r * N + c + 1];
      if (a !== 0 && a === b) {
        merges++;
      }
    }
  }
  for (let c = 0; c < N; c++) {
    for (let r = 0; r < N - 1; r++) {
      const a: number = cells[r * N + c];
      const b: number = cells[(r + 1) * N + c];
      if (a !== 0 && a === b) {
        merges++;
      }
    }
  }
  f[21] = Math.min(1, merges / 12.0);

  // 22 最大块在不在角落
  let corner: number = 0;
  if (mx > 0) {
    let idx: number = 0;
    for (let i = 0; i < 16; i++) {
      if (cells[i] === mx) {
        idx = i;
        break;
      }
    }
    const r: number = Math.floor(idx / N);
    const c: number = idx % N;
    const onR: boolean = (r === 0 || r === N - 1);
    const onC: boolean = (c === 0 || c === N - 1);
    if (onR && onC) {
      corner = 1.0;
    } else if (onR || onC) {
      corner = 0.5;
    }
  }
  f[22] = corner;

  // 23 四角有几个空
  let ec: number = 0;
  const corners: number[] = [0, N - 1, N * (N - 1), N * N - 1];
  for (let k = 0; k < corners.length; k++) {
    if (cells[corners[k]] === 0) {
      ec++;
    }
  }
  f[23] = ec / 4.0;
  return f;
}


/**
 * ★★★ 2026-10-23 实测抓到的重大负面结果（必须留着）：
 *   拿价值网络**贪婪地**选方向（V 最大的那步），100 局均分从 10,885 掉到 919，
 *   逐局 0 胜 100 负。
 *
 *   根因：价值网络是在「启发式策略的轨迹」上训的。一旦用它做决策，
 *        就会走进训练时没见过的局面 ⇒ 预测变垃圾 ⇒ 越下越死。
 *        这是 off-policy 价值函数直接贪心的经典失败，不是训练量不够。
 *
 *   ⇒ 产品上正确的做法：**启发式当主评估**（它被实测证明能到 1 万分），
 *     价值网络只在「启发式自己也拿不定主意」时当裁决。
 *   ⇒ 将来若要让模型主导，必须先做策略迭代（用当前策略产生数据再训），
 *     而不是拿一个固定数据集训完就用。
 */
export function heuristicScore(cells: number[]): number {
  const f: number[] = g2048Features(cells);
  // 与 工具/train_2048_value.py 的 heuristic_value() 完全同一组权重
  return f[17] * 120.0 + f[22] * 60.0 + (1.0 - f[18]) * 50.0
    + (1.0 - f[19]) * 50.0 + (1.0 - f[20]) * 40.0 + f[21] * 15.0 + f[16] * 100.0;
}

export class G2048Value {
  private static mlp: TinyMlp = new TinyMlp();
  private static tried: boolean = false;

  static init(ctx: common.UIAbilityContext): void {
    if (G2048Value.tried) {
      return;
    }
    G2048Value.tried = true;
    try {
      const bytes: Uint8Array = ctx.resourceManager.getRawFileContentSync('models/' + RAW_NAME);
      let s: string = '';
      const chunk: number = 4096;
      for (let i = 0; i < bytes.length; i += chunk) {
        const end: number = Math.min(i + chunk, bytes.length);
        let part: string = '';
        for (let k = i; k < end; k++) {
          part += String.fromCharCode(bytes[k]);
        }
        s += part;
      }
      const ok: boolean = G2048Value.mlp.loadFromJson(s);
      hilog.info(0x0000, TAG, '2048 价值网络 %{public}s（%{public}d B）',
        ok ? '就绪' : '装载失败', bytes.length);
    } catch (e) {
      hilog.warn(0x0000, TAG, '权重读不到 ⇒ 永久降级到启发式提示');
    }
  }

  static isReady(): boolean {
    return G2048Value.mlp.isReady();
  }

  /** 预测「接下来 K 步能拿多少分」的 log 值；不可用返回 null */
  static value(cells: number[]): number | null {
    if (!G2048Value.mlp.isReady()) {
      return null;
    }
    try {
      const out: number | null = G2048Value.mlp.predict(g2048Features(cells));
      return out;
    } catch (e) {
      return null;
    }
  }
}
