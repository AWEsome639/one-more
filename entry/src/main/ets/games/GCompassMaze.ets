/**
 * 罗盘迷宫 🌀
 * 规则：7×7 迷宫（先走通一条路再补墙，必有路）。底部是指南针指令带：
 * 点「走一步」按下达方向走，撞墙白扣一步；⇄ 反转整条指令带（排错用，不扣步数）。
 * 胜负：走到右下角出口 = 通关；步数用尽 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 7; const CELLS: number = N * N;
// ★★ 2026-10-13 修复（奥森："电脑水平太低" 挖出的尺寸越界）：
//   GameDiff.sizeScale 困难档 = ×1.3 ⇒ 棋盘会变成 10×10
//   而数组原来按 CELLS = 49 开 ⇒ 【困难档必越界】✗
//   ⇒ 按【困难档最大尺寸】开数组（多占几百个 int，可忽略）
const MAX_N: number = 10;
const MAX_CELLS: number = MAX_N * MAX_N; const DMAX: number = 20; const TAPE: number = 8;
/** 方向 0上 1右 2下 3左；墙位 1/2/4/8 */
const DR: number[] = [-1, 0, 1, 0]; const DC: number[] = [0, 1, 0, -1];
const ARROW: string[] = ['↑', '→', '↓', '←']; const WALL: number[] = [1, 2, 4, 8];
interface Maze {
 walls: number[]; cmds: number[];
}
/** 从左上角凿一条随机路通到右下角，其余墙随机再拆几道；指令带 = 这条路正反两遍 */
function genMaze(n: number): Maze {
 // ★★★ 2026-10-18 00:2x 真 BUG 修复（与 GClassicMaze 同一类）：
 //   原来用【常量 N=7】生成（终点 CELLS-1=48），但 follow() 用 this.diffTotal（5/7/9）算行列
 //   ⇒ 简单档/困难档下墙壁错位、终点判定错 ⇒ 迷宫可能走不通
 //   ⇒ 修法：按【实际边长 n】生成
 const nn: number = n > 1 ? n : 2;
 const cells: number = nn * nn;
 const w: number[] = new Array<number>(MAX_CELLS).fill(15); const cs: number[] = [];
 let cur: number = 0; let guard: number = 0;
 // ★★★ 2026-10-18 01:0x 真 BUG 修复（第三处）：原来 guard 上限固定 400 步
 //   实测 9×9 时只有 11/20 次能走到终点 ⇒ 指令带 cs 不完整 ⇒ 玩家永远到不了终点
 //   ⇒ 按棋盘大小给足预算（2D 随机游走覆盖时间 ~ n²·log²n，取 cells*400 极保守）
 while (cur !== cells - 1 && guard < cells * 400) {
 guard++; const r: number = Math.floor(cur / nn);
 const c: number = cur - r * nn; const opts: number[] = [];
 if (r < nn - 1) { opts.push(2); }
 if (c < nn - 1) { opts.push(1); }
 if (r > 0) { opts.push(0); }
 if (c > 0) { opts.push(3); }
 const d: number = opts[Math.floor(Math.random() * opts.length)];
 const nb: number = (r + DR[d]) * nn + (c + DC[d]);
 // ★★★ 2026-10-18 00:3x 真 BUG 修复：原来用 `-` 拆墙，重复拆同一面会减成负数
 //   ⇒ 墙壁位掩码变负 ⇒ 位运算结果不可预测 ⇒ 迷宫的墙全乱
 //   ⇒ 改用位清零 `&= ~挡位`（幂等，重复拆也不会错）
 w[cur] = w[cur] & (~WALL[d]);
 w[nb] = w[nb] & (~WALL[(d + 2) % 4]); cs.push(d); cur = nb;
 }
 for (let k = 0; k < 6; k++) { // 再拆几道墙，路不唯一才好玩
 const i: number = Math.floor(Math.random() * cells); const r: number = Math.floor(i / nn);
 const c: number = i - r * nn; const opts: number[] = [];
 if (r > 0) { opts.push(0); }
 if (r < nn - 1) { opts.push(2); }
 if (c > 0) { opts.push(3); }
 if (c < nn - 1) { opts.push(1); }
 const d: number = opts[Math.floor(Math.random() * opts.length)];
 const nb: number = (r + DR[d]) * nn + (c + DC[d]);
 // ★★★ 同上：位清零代替减法
 w[i] = w[i] & (~WALL[d]);
 w[nb] = w[nb] & (~WALL[(d + 2) % 4]);
 }
 const tape: number[] = [];
 for (let i = 0; i < cs.length; i++) { tape.push(cs[i]); }
 for (let i = cs.length - 1; i >= 0; i--) { tape.push((cs[i] + 2) % 4); }
 while (tape.length < TAPE * 2) { tape.push(Math.floor(Math.random() * 4)); }
 return { walls: w, cmds: tape };
}
  @Component
export struct GCompassMaze {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=7；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5, 6]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(7);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
 onFinish: (r: GameResult) => void = () => {};

  @State private walls: number[] = []; @State private cmds: number[] = [];
  @State private pos: number = 0; @State private idx: number = 0;
  @State private steps: number = 0; @State private over: boolean = false;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void {
   LanRace.noteStart(); this.reset();
   // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
   setTimeout(() => { this.demoStart(); }, 3000);
 }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(7);
     this.reset(); }
 /** ★ 出口格子下标（随棋盘边长走） */
 private goalIdx(): number { return this.diffTotal * this.diffTotal - 1; }
 private reset(): void {
 const m: Maze = genMaze(this.diffTotal); this.walls = m.walls; this.cmds = m.cmds; this.pos = 0;
 this.idx = 0; this.steps = 0; this.over = false; this.won = false;
 this.note = TG('照着指令走到右下角 🌀'); this.startAt = Date.now();
 }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款玩家只能按「走一步」（照指令带）或「⇄ 反转」（不扣步数）。
  // 关键认识：反转不花步数 ⇒ 每一步都能自由选「这条指令」或「它的反向」，
  //   而指令带指针每走一步必然 +1 ⇒ 第 k 步用的指令一定在 (idx + k) 处，
  //   于是状态只剩「人在哪个格子」⇒ 逐层可达集就够，不需要搜树。
  /** 按方向 d 从 pos 走一步（撞墙/出界就地不动），与 follow() 同一套判据 */
  private stepFrom(pos: number, d: number): number {
    const n: number = this.diffTotal;
    const r: number = Math.floor(pos / n);
    const c: number = pos % n;
    const nr: number = r + DR[d];
    const nc: number = c + DC[d];
    if ((this.walls[pos] & WALL[d]) !== 0 || nr < 0 || nr >= n || nc < 0 || nc >= n) {
      return pos;
    }
    return nr * n + nc;
  }

  /** [要不要先翻转(0/1), 还需要几步到出口(-1 = 步数内到不了)] */
  private planInfo(): number[] {
    const n: number = this.diffTotal;
    const cells: number = n * n;
    const goal: number = this.goalIdx();
    const L: number = this.cmds.length;
    const budget: number = DMAX - this.steps;
    if (L <= 0 || this.walls.length < cells || budget <= 0) {
      return [0, -1];                  // 盘面还没初始化 / 没有剩余步数
    }
    const reach: boolean[] = new Array<boolean>(cells).fill(false);
    reach[this.pos] = true;
    const fromPos: number[][] = [];
    const fromPar: number[][] = [];
    let layer0: number[] = new Array<number>(cells).fill(-1);
    fromPos.push(layer0);
    fromPar.push(new Array<number>(cells).fill(-1));
    let kstar: number = this.pos === goal ? 0 : -1;
    for (let k = 0; k < budget && kstar < 0; k++) {
      const d0: number = this.cmds[(this.idx + k) % L];
      const next: boolean[] = new Array<boolean>(cells).fill(false);
      const fp: number[] = new Array<number>(cells).fill(-1);
      const fq: number[] = new Array<number>(cells).fill(-1);
      for (let pos = 0; pos < cells; pos++) {
        if (!reach[pos]) {
          continue;
        }
        for (let par = 0; par < 2; par++) {
          const np: number = this.stepFrom(pos, (d0 + 2 * par) % 4);
          if (!next[np]) {
            next[np] = true;
            fp[np] = pos;
            fq[np] = par;
          }
        }
      }
      fromPos.push(fp);
      fromPar.push(fq);
      for (let pos = 0; pos < cells; pos++) {
        reach[pos] = next[pos];
      }
      if (reach[goal]) {
        kstar = k + 1;
      }
    }
    if (kstar > 0) {
      // 从出口往回倒推，取"第 1 步该不该翻转"
      let pos: number = goal;
      let par: number = 0;
      for (let k = kstar; k >= 1; k--) {
        par = fromPar[k][pos];
        pos = fromPos[k][pos];
      }
      return [par, kstar];
    }
    // 到不了 ⇒ 往"离出口更近"的那边走（撞墙也行，至少别原地不动等死）
    const dNow: number = this.cmds[this.idx];
    const p0: number = this.stepFrom(this.pos, dNow);
    const p1: number = this.stepFrom(this.pos, (dNow + 2) % 4);
    const gr: number = Math.floor(goal / n);
    const gc: number = goal % n;
    const dist0: number = Math.abs(Math.floor(p0 / n) - gr) + Math.abs(p0 % n - gc);
    const dist1: number = Math.abs(Math.floor(p1 / n) - gr) + Math.abs(p1 % n - gc);
    return [dist1 < dist0 ? 1 : 0, -1];
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.pos === this.goalIdx()) {
      return false;
    }
    const info: number[] = this.planInfo();
    if (info[0] === 1) {
      this.flip();                      // 先反转指令带（不扣步数），下一步方向才对上
    }
    this.follow();
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.pos === this.goalIdx()) {
      return Hint.none('none');
    }
    if (this.steps >= DMAX) {
      return Hint.none('none');
    }
    const info: number[] = this.planInfo();
    const d: number = (this.cmds[this.idx] + 2 * info[0]) % 4;
    const arrow: string = ARROW[d];
    const needFlip: string = info[0] === 1 ? TG('先点「⇄ 反转」') : '';
    if (info[1] < 0) {
      return Hint.make([], TG('剩余步数已经走不到出口了') + needFlip +
        TG2('，这一下走 {0}，尽量往右下角靠', arrow),
        'Cannot reach the exit any more', t0);
    }
    return Hint.make([], needFlip +
      TG2('然后点「走一步 {0}」—— {1} 步之后就能出关', arrow, String(info[1])),
      'Flip first, then step ' + arrow, t0);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

 private follow(): void {
 if (this.over) { return; }
 const d: number = this.cmds[this.idx]; const cur: number = this.pos;
 const nr: number = Math.floor(cur / this.diffTotal) + DR[d]; const nc: number = cur % this.diffTotal + DC[d];
 if ((this.walls[cur] & WALL[d]) !== 0 || nr < 0 || nr >= this.diffTotal || nc < 0 || nc >= this.diffTotal) {
 this.note = TG('撞墙，这一步白走 🧱');
 } else {
 this.pos = nr * this.diffTotal + nc;
 }
 this.idx = (this.idx + 1) % this.cmds.length; this.steps++;
 if (this.pos === this.goalIdx()) {
 this.note = TG('指令走完，出关 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 if (this.steps >= DMAX) {
 this.note = TG('步数用尽，还在半路 😵'); this.finish(false); return;
 }
 this.note = TG2('下一步指令：{0}', ARROW[this.cmds[this.idx]]);
 }
 /** ⇄ 反转整条指令带：0↔2、1↔3，不扣步数 */
 private flip(): void {
 if (this.over) { return; }
 const cs: number[] = [];
 for (let i = 0; i < this.cmds.length; i++) { cs.push((this.cmds[i] + 2) % 4); }
 this.cmds = cs; this.note = TG('指令带已反转 ⇄（不扣步数）');
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'compass_maze', solved: solved,
 score: solved ? 70 + Math.max(0, (DMAX - this.steps) * 5) : this.steps * 4,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.xs }) {
   HintBar({
     showHint: true,
     onHintTap: () => { this.askHint(); },
     onAutoTap: () => { this.askAuto(); },
     autoOn: this.autoId >= 0
   })
 Text(TG('步数 ') + this.steps + '/' + DMAX + '　指令 ' + (this.idx + 1) + '/' + this.cmds.length
 + TG2('　出口 {0}排{1}列', this.diffTotal, this.diffTotal)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: 0 }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: 0 }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(this.pos === r * this.diffTotal + c ? '🔵' : (r * this.diffTotal + c === this.goalIdx() ? '🏁' : '')).fontSize(FontSize.sm)
 }.layoutWeight(1).height(Cell.of(40)).backgroundColor(this.theme.surface).borderRadius(Radius.xs).borderWidth({
 top: (this.walls[r * this.diffTotal + c] & 1) !== 0 ? 2 : 0, right: (this.walls[r * this.diffTotal + c] & 2) !== 0 ? 2 : 0,
 bottom: (this.walls[r * this.diffTotal + c] & 4) !== 0 ? 2 : 0,
 left: (this.walls[r * this.diffTotal + c] & 8) !== 0 ? 2 : 0
 }).borderColor(Palette.wall).animation({ duration: Motion.fast, curve: Motion.snap() })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Row({ space: 2 }) {
 ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
 Text(ARROW[this.cmds[(this.idx + i) % this.cmds.length]]).fontSize(FontSize.sm).fontColor(i === 0 ? '#FFFFFF' : this.theme.inkSoft).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(30)).backgroundColor(i === 0 ? Palette.amber : this.theme.surface).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
 }, (i: number) => 'm' + i) }.width('100%')
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Row({ space: Space.xs }) {
 Button(TG2('走一步 {0}', ARROW[this.cmds[this.idx]]))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(2).height(Cell.of(46)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.follow(); }); }).onClick(() => { Haptics.tap(); this.follow(); })
 Button(TG('⇄ 反转'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(46)).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.flip(); }); }).onClick(() => { Haptics.tap(); this.flip(); })
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(46)).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.violet).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
 }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}