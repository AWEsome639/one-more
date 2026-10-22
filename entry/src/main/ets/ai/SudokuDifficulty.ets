/**
 * SudokuDifficulty —— 数独难度预测（2026-10-23，路线 B）
 *
 * 它做的事：
 *   给定一个盘面（81 长数组，0=空），预测「人类体感难度」0-1。
 *
 * 为什么这件事值得做：
 *   原来「难度」只等于**挖空多少格**（简单 28 / 普通 40 / 困难 52）。
 *   但挖空数 ≠ 难度：实测同样挖 54 格，有的题 15 轮技巧就能推完，
 *   有的要 28 轮，还夹着搜索。玩家体感的差别就在这儿。
 *   ⇒ 现在用模型预测「真实难度」，不再只看格数。
 *
 * 模型来源：
 *   工具/train_sudoku_diff.py 训练的手写 MLP（11 维 → 12 → 1），
 *   权重导成 2.7 KB 的 JSON 放在 rawfile 里。
 *
 * ★ 铁律：模型不可用 ⇒ predict 返回 null，调用方回落到「按格数」的老逻辑。
 *   绝不让"没有模型"变成"游戏打不开"。
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TinyMlp } from './TinyMlp';
import { sudokuFeatures } from './SudokuFeatures';

const TAG: string = 'SudokuDifficulty';
const RAW_NAME: string = 'sudoku_diff.json';

export class SudokuDifficulty {
  private static mlp: TinyMlp = new TinyMlp();
  private static tried: boolean = false;

  /** 启动时调一次（读不到就永久降级，不重试、不拖启动） */
  static init(ctx: common.UIAbilityContext): void {
    if (SudokuDifficulty.tried) {
      return;
    }
    SudokuDifficulty.tried = true;
    try {
      const bytes: Uint8Array = ctx.resourceManager.getRawFileContentSync('models/' + RAW_NAME);
      // Uint8Array → 字符串（模型是 UTF-8 JSON，全 ASCII，直接按字节转）
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
      const ok: boolean = SudokuDifficulty.mlp.loadFromJson(s);
      hilog.info(0x0000, TAG, '数独难度模型 %{public}s（%{public}d B）',
        ok ? '就绪' : '装载失败', bytes.length);
    } catch (e) {
      hilog.warn(0x0000, TAG, '模型文件读不到 ⇒ 永久降级到"按格数"');
    }
  }

  /** 是否可用（界面/诊断用） */
  static isReady(): boolean {
    return SudokuDifficulty.mlp.isReady();
  }

  /**
   * 预测难度 0-1。不可用时返回 null —— 调用方必须能接受。
   */
  static predict(grid: number[]): number | null {
    if (!SudokuDifficulty.mlp.isReady()) {
      return null;
    }
    try {
      const f: number[] = sudokuFeatures(grid);
      const raw: number | null = SudokuDifficulty.mlp.predict(f);
      if (raw === null) {
        return null;
      }
      // 模型的输出理论上在 0-1，但外推时可能越界 ⇒ 夹住
      if (raw < 0) {
        return 0;
      }
      if (raw > 1) {
        return 1;
      }
      return raw;
    } catch (e) {
      return null;
    }
  }

  /**
   * 各档的目标难度（由训练集的标签分布经验定，见 train_sudoku_diff.py 的百分位）
   *   简单 0.25 ｜ 普通 0.50 ｜ 困难 0.78
   */
  static targetFor(level: number): number {
    if (level === 0) {
      return 0.25;
    }
    if (level >= 2) {
      return 0.78;
    }
    return 0.50;
  }
}
