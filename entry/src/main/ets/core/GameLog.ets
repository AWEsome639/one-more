/**
 * GameLog —— 每局游玩记录（2026-10-23 新增，路线 E 数据层）
 *
 * 为什么需要它：
 *   路线 B（数独难度模型）要「人类解题时间」当训练标签、
 *   路线 C（强化学习）要 reward 曲线、
 *   路线 F（难度自适应）要「这个玩家连赢几局」
 *   —— 而现在 App **一局都不留痕**。这三条路全悬在半空。
 *
 * 设计取舍（每条都有原因）：
 *   ① 用**文件**不用 Preferences：Preferences 单个值有大小上限，
 *      几千条记录会撑爆；而 JSONL 是追加式，天然适合"只增不改"
 *   ② 用 **JSONL**（一行一条）不用一个大 JSON 数组：
 *      追加只需写一行，不用读出来改再写回去
 *   ③ 内存里留最近 N 条，界面/统计直接读内存，不碰磁盘
 *   ④ 上限 5000 条，超了从**旧的头**截断 —— 保住最近的，丢掉最早的
 *   ⑤ 全部 try/catch：**记录失败绝不能让游戏崩或变慢**
 *
 * 隐私：只写本机 filesDir，**不上传、不联网**。与 App「零采集」的承诺一致。
 */

import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

/** 一条游玩记录（短键名是为了让 JSONL 小一点） */
export interface PlayRecord {
  /** 结束时间戳（ms） */
  t: number;
  /** gameId */
  g: string;
  /** 难度档位 0/1/2 */
  d: number;
  /** 本局时长（ms） */
  ms: number;
  /** 得分 */
  s: number;
  /** 是否完成（true=通关，false=中途退出/失败） */
  ok: boolean;
  /** 关卡（有就记，没有填 -1） */
  lv: number;
}

/** 导出文件里的 summary 段（显式接口 —— ArkTS 不许 Record 的对象字面量） */
interface ExportSummary {
  total: number;
  solved: number;
  totalMs: number;
  recentWins: number;
  recentLosses: number;
}

/** 导出文件的整体结构 */
interface ExportPayload {
  app: string;
  version: string;
  exportedAt: string;
  note: string;
  summary: ExportSummary;
  records: PlayRecord[];
}

/** 汇总统计（给界面与路线 F 用） */
export interface LogSummary {
  total: number;
  solved: number;
  totalMs: number;
  /** 最近 10 局的胜负数 */
  recentWins: number;
  recentLosses: number;
  /** 每款游戏的通关率（0–1），按 gameId */
  perGameRate: Map<string, number>;
}

const FILE_NAME: string = 'playlog.jsonl';
const MAX_LINES: number = 5000;
/** 内存里保留的条数（比文件上限小，省内存） */
const KEEP_IN_MEM: number = 800;

export class GameLog {
  private static dir: string = '';
  private static path: string = '';
  private static mem: PlayRecord[] = [];
  private static ready: boolean = false;
  /** 累计写失败的次数（只用于诊断，不打扰用户） */
  private static writeErrors: number = 0;

  /** 应用启动时调一次（在 ProgressStore.init 之后） */
  static init(ctx: common.UIAbilityContext): void {
    if (GameLog.ready) {
      return;
    }
    try {
      GameLog.dir = ctx.filesDir;
      GameLog.path = ctx.filesDir + '/' + FILE_NAME;
      GameLog.load();
      GameLog.ready = true;
      hilog.info(0x0000, 'GameLog', 'init ok path=%{public}s mem=%{public}d', GameLog.path, GameLog.mem.length);
    } catch (e) {
      // 拿不到目录就只在内存里记 —— 不影响游戏
      GameLog.ready = false;
      hilog.error(0x0000, 'GameLog', 'init FAILED: %{public}s', JSON.stringify(e));
    }
  }

  /** 从文件读回内存（只留最近 KEEP_IN_MEM 条） */
  private static load(): void {
    GameLog.mem = [];
    try {
      if (!fileIo.accessSync(GameLog.path)) {
        return;
      }
      const content: string = fileIo.readTextSync(GameLog.path);
      if (content.length === 0) {
        return;
      }
      const lines: string[] = content.split('\n');
      const start: number = lines.length > KEEP_IN_MEM ? lines.length - KEEP_IN_MEM : 0;
      for (let i = start; i < lines.length; i++) {
        const ln: string = lines[i].trim();
        if (ln.length === 0) {
          continue;
        }
        const r: PlayRecord | null = GameLog.parseLine(ln);
        if (r !== null) {
          GameLog.mem.push(r);
        }
      }
    } catch (e) {
      GameLog.mem = [];
    }
  }

  /** 解析一行 JSONL（自己解析，避免 JSON.parse 的类型断言在 ArkTS 里绕） */
  private static parseLine(ln: string): PlayRecord | null {
    try {
      const o: Record<string, number | string | boolean> = JSON.parse(ln) as Record<string, number | string | boolean>;
      const t: number = typeof o.t === 'number' ? o.t as number : 0;
      const g: string = typeof o.g === 'string' ? o.g as string : '';
      if (g.length === 0 || t <= 0) {
        return null;
      }
      return {
        t: t,
        g: g,
        d: typeof o.d === 'number' ? o.d as number : 1,
        ms: typeof o.ms === 'number' ? o.ms as number : 0,
        s: typeof o.s === 'number' ? o.s as number : 0,
        ok: o.ok === true,
        lv: typeof o.lv === 'number' ? o.lv as number : -1,
      };
    } catch (e) {
      return null;
    }
  }

  /**
   * 记一局（核心入口）。
   * 调用点：GameHost.handleFinish()，每局结束一次。
   * 失败只累加 writeErrors，不抛、不弹窗、不拖慢。
   */
  static record(r: PlayRecord): void {
    // ① 内存先记（界面/统计立即可用）
    GameLog.mem.push(r);
    if (GameLog.mem.length > KEEP_IN_MEM) {
      GameLog.mem.shift();
    }
    // ② 落盘（追加一行）
    if (!GameLog.ready) {
      hilog.warn(0x0000, 'GameLog', 'record: not ready, mem only');
      return;
    }
    try {
      const line: string = JSON.stringify(r) + '\n';
      // 文件不存在就建，存在就追加
      const file: fileIo.File = fileIo.openSync(GameLog.path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
      try {
        fileIo.writeSync(file.fd, line);
      } finally {
        fileIo.closeSync(file);
      }
      hilog.info(0x0000, 'GameLog', 'record ok %{public}s ok=%{public}s mem=%{public}d',
        r.g, r.ok ? 'Y' : 'N', GameLog.mem.length);
    } catch (e) {
      GameLog.writeErrors++;
      hilog.error(0x0000, 'GameLog', 'record WRITE FAILED: %{public}s', JSON.stringify(e));
    }
  }

  /** 直接给一个 GameResult 口径的便捷入口（避免调用方自己拼字段） */
  static recordResult(gameId: string, solved: boolean, score: number, durationMs: number,
                      level: number, levelReached: number): void {
    GameLog.record({
      t: Date.now(),
      g: gameId,
      d: level,
      ms: durationMs,
      s: score,
      ok: solved,
      lv: levelReached,
    });
  }

  /** 最近 n 条（新的在后） */
  static recent(n: number): PlayRecord[] {
    const total: number = GameLog.mem.length;
    const from: number = total > n ? total - n : 0;
    const out: PlayRecord[] = [];
    for (let i = from; i < total; i++) {
      out.push(GameLog.mem[i]);
    }
    return out;
  }

  static count(): number {
    return GameLog.mem.length;
  }

  /** 汇总（路线 F 的难度自适应直接吃这个） */
  static summary(): LogSummary {
    let solved: number = 0;
    let totalMs: number = 0;
    const perGameTotal: Map<string, number> = new Map<string, number>();
    const perGameOk: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < GameLog.mem.length; i++) {
      const r: PlayRecord = GameLog.mem[i];
      totalMs += r.ms;
      const tt: number = (perGameTotal.get(r.g) ?? 0) + 1;
      perGameTotal.set(r.g, tt);
      if (r.ok) {
        solved++;
        perGameOk.set(r.g, (perGameOk.get(r.g) ?? 0) + 1);
      }
    }
    // 最近 10 局胜负
    let rw: number = 0;
    let rl: number = 0;
    const from: number = GameLog.mem.length > 10 ? GameLog.mem.length - 10 : 0;
    for (let i = from; i < GameLog.mem.length; i++) {
      if (GameLog.mem[i].ok) {
        rw++;
      } else {
        rl++;
      }
    }
    const rate: Map<string, number> = new Map<string, number>();
    perGameTotal.forEach((tot: number, gid: string) => {
      const ok: number = perGameOk.get(gid) ?? 0;
      rate.set(gid, tot > 0 ? ok / tot : 0);
    });
    return {
      total: GameLog.mem.length,
      solved: solved,
      totalMs: totalMs,
      recentWins: rw,
      recentLosses: rl,
      perGameRate: rate,
    };
  }

  /**
   * 导出一份完整 JSON（给设置页「导出我的游戏记录」用）。
   * 返回的是**字符串**，调用方决定存哪儿 / 分享给谁。
   */
  static exportJson(): string {
    const all: PlayRecord[] = GameLog.loadAllFromFile();
    const s: LogSummary = GameLog.summary();
    const sum: ExportSummary = {
      total: s.total,
      solved: s.solved,
      totalMs: s.totalMs,
      recentWins: s.recentWins,
      recentLosses: s.recentLosses,
    };
    const payload: ExportPayload = {
      app: 'One More',
      version: '1.0.1',
      exportedAt: new Date().toISOString(),
      note: '仅本机生成，未上传任何服务器',
      summary: sum,
      records: all,
    };
    return JSON.stringify(payload, null, 2);
  }

  /** 从文件读全部（导出用；不回写内存） */
  private static loadAllFromFile(): PlayRecord[] {
    const out: PlayRecord[] = [];
    if (!GameLog.ready) {
      return GameLog.mem.slice();
    }
    try {
      if (!fileIo.accessSync(GameLog.path)) {
        return GameLog.mem.slice();
      }
      const content: string = fileIo.readTextSync(GameLog.path);
      const lines: string[] = content.split('\n');
      const start: number = lines.length > MAX_LINES ? lines.length - MAX_LINES : 0;
      for (let i = start; i < lines.length; i++) {
        const ln: string = lines[i].trim();
        if (ln.length === 0) {
          continue;
        }
        const r: PlayRecord | null = GameLog.parseLine(ln);
        if (r !== null) {
          out.push(r);
        }
      }
    } catch (e) {
      return GameLog.mem.slice();
    }
    return out;
  }

  /** 把导出的 JSON 写到 filesDir，返回文件路径（失败返回空串） */
  static writeExport(): string {
    if (!GameLog.ready) {
      hilog.error(0x0000, 'GameLog', 'writeExport: not ready');
      return '';
    }
    try {
      hilog.info(0x0000, 'GameLog', 'writeExport: building json, dir=%{public}s', GameLog.dir);
      const json: string = GameLog.exportJson();
      hilog.info(0x0000, 'GameLog', 'writeExport: json len=%{public}d', json.length);
      const p: string = GameLog.dir + '/onemore-playlog-' + GameLog.stamp() + '.json';
      const file: fileIo.File = fileIo.openSync(p,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, json);
      } finally {
        fileIo.closeSync(file);
      }
      hilog.info(0x0000, 'GameLog', 'writeExport: ok path=%{public}s', p);
      return p;
    } catch (e) {
      hilog.error(0x0000, 'GameLog', 'writeExport FAILED: %{public}s', JSON.stringify(e));
      return '';
    }
  }

  private static stamp(): string {
    const d: Date = new Date();
    const pad = (n: number): string => (n < 10 ? '0' + n : '' + n);
    return '' + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate())
      + '-' + pad(d.getHours()) + pad(d.getMinutes());
  }

  /** 诊断用：写失败过几次（设置页可以显示，也可以不显示） */
  static errorCount(): number {
    return GameLog.writeErrors;
  }

  /** 清空（设置页给一个「清除游玩记录」，走二次确认） */
  static clear(): boolean {
    GameLog.mem = [];
    if (!GameLog.ready) {
      return true;
    }
    try {
      if (fileIo.accessSync(GameLog.path)) {
        fileIo.unlinkSync(GameLog.path);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
