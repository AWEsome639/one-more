/**
 * 幻方 —— 行列对角线和相等
 * 玩法：3×3 幻方挖 4 格，从托盘选数字填回；填满即校验八条线。
 * 胜负：120 秒内过 3 关 ⇒ 通关；超时或错满 4 次 ⇒ 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SIDE: number = 3; const CELLS: number = 9; const BLANKS: number = 4; const MAGIC: number = 15;
const ROUNDS: number = 3; const MAX_ERR: number = 4; const LIMIT: number = 120; const TICK_MS: number = 1000;
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
const ROWS: number[] = [0, 1, 2];
const LINES: number[][] = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
const BASE: number[] = [2, 7, 6, 9, 5, 1, 4, 3, 8];

function shuffled(src: number[]): number[] {
  const out: number[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

/** 随机取一个幻方形态（旋转 × 镜像仍是幻方） */
function magicSquare(): number[] {
  let v: number[] = BASE.slice();
  const turns: number = Math.floor(Math.random() * 4);
  for (let t = 0; t < turns; t++) {
    const rot: number[] = new Array<number>(CELLS).fill(0);
    for (let i = 0; i < CELLS; i++) {
      const row: number = Math.floor(i / SIDE); const col: number = i % SIDE;
      rot[col * SIDE + (SIDE - 1 - row)] = v[i];
    }
    v = rot;
  }
  if (Math.random() < 0.5) { return v; }
  const mir: number[] = new Array<number>(CELLS).fill(0);
  for (let i = 0; i < CELLS; i++) {
    const row: number = Math.floor(i / SIDE); const col: number = i % SIDE;
    mir[row * SIDE + (SIDE - 1 - col)] = v[i];
  }
  return mir;
}

@Component
export struct GMagicSquares {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private board: number[] = [];
  @State private fixed: boolean[] = [];
  @State private pool: number[] = [];
  @State private sel: number = -1;
  @State private round: number = 1;
  @State private errors: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1; private finished: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private reset(): void {
    this.stop();
    this.round = 1; this.errors = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.newRound();
    this.msg = TG2('让每行、每列、两条对角线的和都等于 {0}', String(MAGIC));
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到')); }
  }

  private newRound(): void {
    const solved9: number[] = magicSquare();
    const holes: number[] = shuffled(IDX).slice(0, BLANKS);
    const board: number[] = solved9.slice();
    const fixed: boolean[] = [];
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { fixed.push(true); }
    for (let k = 0; k < holes.length; k++) {
      const at: number = holes[k];
      pool.push(solved9[at]); board[at] = 0; fixed[at] = false;
    }
    this.board = board; this.fixed = fixed; this.pool = shuffled(pool); this.sel = -1;
  }

  private pickNum(i: number): void {
    if (this.over) { return; }
    this.sel = i;
    this.msg = TG2('已选 {0} —— 点棋盘上的空格放进去', String(this.pool[i]));
  }

  private tapCell(i: number): void {
    if (this.over) { return; }
    if (this.fixed[i]) { this.msg = TG('这格是题目给的，不能动'); return; }
    if (this.board[i] !== 0) {                       // 取回托盘
      const b2: number[] = this.board.slice();
      const back: number = b2[i];
      b2[i] = 0;
      const p2: number[] = this.pool.slice();
      p2.push(back);
      this.board = b2; this.pool = p2; this.sel = -1;
      this.msg = TG2('已取回 {0}', String(back));
      return;
    }
    if (this.sel < 0) { this.msg = TG('先在下面托盘里选一个数字'); return; }
    const put: number = this.pool[this.sel];
    const b3: number[] = this.board.slice();
    const p3: number[] = this.pool.slice();
    b3[i] = put; p3.splice(this.sel, 1);
    this.board = b3; this.pool = p3; this.sel = -1;
    if (p3.length === 0) { this.check(); } else { this.msg = TG('还差 ') + String(p3.length) + ' 个数字'; }
  }

  private check(): void {
    let ok: boolean = true;
    for (let k = 0; k < LINES.length; k++) {
      const ln: number[] = LINES[k];
      if (this.board[ln[0]] + this.board[ln[1]] + this.board[ln[2]] !== MAGIC) { ok = false; }
    }
    if (ok) {
      this.score = this.score + 120 + this.left; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.round >= ROUNDS) { this.end(true, TG('🎉 三关全过')); return; }
      this.round = this.round + 1;
      this.newRound();
      this.msg = TG2("✅ 幻方成立！进入第 {0} 关",Digits(String(this.round), this.langCode));
      return;
    }
    this.errors = this.errors + 1;
    this.score = Math.max(0, this.score - 15); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    if (this.errors >= MAX_ERR) { this.end(false, '❌ 错了 ' + String(MAX_ERR) + TG(' 次')); return; }
    this.clearBlanks();
    this.msg = TG2('❌ 有线不对（错 {0}/{1}），已清空重来', String(this.errors), String(MAX_ERR));
  }

  private clearBlanks(): void {
    const board: number[] = this.board.slice();
    const back: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (!this.fixed[i] && board[i] !== 0) { back.push(board[i]); board[i] = 0; }
    }
    this.board = board; this.pool = shuffled(back); this.sel = -1;
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'magic_squares', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(ROWS, (c: number) => { Text(this.board[(r * SIDE + c)] === 0 ? '' : String(this.board[(r * SIDE + c)]))
            .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor(this.fixed[(r * SIDE + c)] ? this.theme.ink : Palette.sky)
            .layoutWeight(1).aspectRatio(1).borderRadius(Radius.md)
            .backgroundColor(this.fixed[(r * SIDE + c)] ? this.theme.surface : (this.theme.isDark ? '#16283A' : '#E0F2FE'))
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { this.tapCell((r * SIDE + c)); }) }, (c: number) => 'mc' + c)
          }.width('100%')
        }, (r: number) => 'mr' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.sm }) {
        ForEach(this.pool, (v: number, i: number) => { Text(String((v)))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel === (i) ? '#FFFFFF' : this.theme.ink)
        .layoutWeight(1).height(Cell.of(56)).borderRadius(Radius.md).shadow(Shadow.card)
        .backgroundColor(this.sel === (i) ? Palette.sky : this.theme.surface)
        .scale({ x: this.sel === (i) ? 1.06 : 1, y: this.sel === (i) ? 1.06 : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pickNum((i)); }) }, (v: number) => 'mp' + v)
      }.width('100%').height(Cell.of(64))

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky)
        .onClick(() => { this.reset(); })

      Text(TG('提示：点已填的格子可以把数字取回托盘'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
