/**
 * 消消乐（三消）—— 三消连锁 💥
 *
 * 规则：点一个果子，再点它上下左右相邻的果子交换位置；能连成 3 个以上才生效，
 *      消掉后上方落下补新，连锁越多次得分越高。
 * 胜负：25 步内攒够 1800 分 = 通关；步数用尽还没到 = 失败
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 8;
const KINDS: number = 6;
const TARGET: number = 1800;
const MOVES: number = 25;

const FACES: string[] = ['🍎', '🍊', '🍋', '🍇', '🥝', '🍒'];
const TINTS: string[] = [
  '#3DEF4444', '#3DF59E0B', '#3DFACC15', '#3D8B5CF6', '#3D10B981', '#3DF43F5E'
];

@Component
export struct GMatch3 {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private board: number[] = [];
  @State private sel: number = -1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法（本局次数/起始量按难度换算）
  private total: number = GameDiff.livesNow(MOVES);
  @State private movesLeft: number = 0;
  @State private combo: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMatch3')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.total = GameDiff.livesNow(MOVES);
    this.reset();
  }

  // ── 棋盘 ──

  private makeBoard(): number[] {
    const b: number[] = [];
    for (let i = 0; i < N * N; i++) {
      const r: number = Math.floor(i / N);
      const c: number = i % N;
      let v: number = Math.floor(Math.random() * KINDS);
      let guard: number = 0;
      while (guard < 40 && this.badStart(b, i, r, c, v)) {
        v = Math.floor(Math.random() * KINDS);
        guard++;
      }
      b.push(v);
    }
    return b;
  }

  private badStart(b: number[], i: number, r: number, c: number, v: number): boolean {
    if (c >= 2 && b[i - 1] === v && b[i - 2] === v) {
      return true;
    }
    if (r >= 2 && b[i - N] === v && b[i - 2 * N] === v) {
      return true;
    }
    return false;
  }

  private findMatches(b: number[]): boolean[] {
    const m: boolean[] = new Array<boolean>(N * N).fill(false);
    for (let r = 0; r < N; r++) {
      let run: number = 1;
      for (let c = 1; c <= N; c++) {
        const same: boolean = c < N && b[r * N + c] >= 0 && b[r * N + c] === b[r * N + c - 1];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = c - run; k < c; k++) {
              m[r * N + k] = true;
            }
          }
          run = 1;
        }
      }
    }
    for (let c = 0; c < N; c++) {
      let run: number = 1;
      for (let r = 1; r <= N; r++) {
        const same: boolean = r < N && b[r * N + c] >= 0 && b[r * N + c] === b[(r - 1) * N + c];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = r - run; k < r; k++) {
              m[k * N + c] = true;
            }
          }
          run = 1;
        }
      }
    }
    return m;
  }

  private anyMatch(b: number[]): boolean {
    const m: boolean[] = this.findMatches(b);
    for (let i = 0; i < m.length; i++) {
      if (m[i]) {
        return true;
      }
    }
    return false;
  }

  private hasAnyMove(b: number[]): boolean {
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        const i: number = r * N + c;
        if (c + 1 < N) {
          const t: number[] = b.slice();
          const tmp: number = t[i];
          t[i] = t[i + 1];
          t[i + 1] = tmp;
          if (this.anyMatch(t)) {
            return true;
          }
        }
        if (r + 1 < N) {
          const t2: number[] = b.slice();
          const tmp2: number = t2[i];
          t2[i] = t2[i + N];
          t2[i + N] = tmp2;
          if (this.anyMatch(t2)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这盘没有"答案字段"—— 现搜一对能换出三连的相邻格（判据就是游戏自己的 anyMatch）
  private aiSwapOk(a: number, b: number): boolean {
    const t: number[] = this.board.slice();
    const tmp: number = t[a];
    t[a] = t[b];
    t[b] = tmp;
    return this.anyMatch(t);
  }

  /** 返回 a * 100 + b（一对可换的相邻格），-1 = 没有可换的 */
  private aiFindPair(): number {
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        const a: number = r * N + c;
        if (c + 1 < N && this.aiSwapOk(a, a + 1)) {
          return a * 100 + (a + 1);
        }
        if (r + 1 < N && this.aiSwapOk(a, a + N)) {
          return a * 100 + (a + N);
        }
      }
    }
    return -1;
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
    this.sel = -1;
    const m: number = this.aiFindPair();
    if (m < 0) {
      return false;
    }
    this.tap(Math.floor(m / 100));
    this.tap(m % 100);
    return !this.over;
  }

  /** 提示：报这一对可换的格子（报行列，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const m: number = this.aiFindPair();
    if (m < 0) {
      return Hint.none('none');
    }
    const a: number = Math.floor(m / 100);
    const b: number = m % 100;
    const pa: string = (Math.floor(a / N) + 1) + '排' + (a % N + 1) + '列';
    const pb: string = (Math.floor(b / N) + 1) + '排' + (b % N + 1) + '列';
    return Hint.make([a, b], TG2('换 {0} 与 {1} 这两个果子能消', pa, pb),
      TG2('Swap {0} with {1} to clear', pa, pb), t0);
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

  private reset(): void {
    let b: number[] = this.makeBoard();
    if (!this.hasAnyMove(b)) {
      b = this.makeBoard();
    }
    this.board = b;
    this.sel = -1;
    this.score = 0;
    this.movesLeft = this.total;
    this.combo = 0;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
  }

  /** 消 + 落 + 补，直到没有可消的；返回本轮得分 */
  private resolve(): number {
    let b: number[] = this.board.slice();
    let gained: number = 0;
    let chain: number = 0;
    while (true) {
      const m: boolean[] = this.findMatches(b);
      let cnt: number = 0;
      for (let i = 0; i < m.length; i++) {
        if (m[i]) {
          cnt++;
        }
      }
      if (cnt === 0) {
        break;
      }
      chain++;
      gained += cnt * 10 * chain;
      const nb: number[] = b.slice();
      for (let i = 0; i < nb.length; i++) {
        if (m[i]) {
          nb[i] = -1;
        }
      }
      for (let c = 0; c < N; c++) {
        let write: number = N - 1;
        for (let r = N - 1; r >= 0; r--) {
          if (nb[r * N + c] >= 0) {
            nb[write * N + c] = nb[r * N + c];
            write--;
          }
        }
        for (let r = write; r >= 0; r--) {
          nb[r * N + c] = Math.floor(Math.random() * KINDS);
        }
      }
      b = nb;
    }
    this.combo = chain;
    this.board = b;
    if (!this.hasAnyMove(b)) {
      this.board = this.makeBoard();
    }
    return gained;
  }

  private adjacent(a: number, b: number): boolean {
    const ar: number = Math.floor(a / N);
    const ac: number = a % N;
    const br: number = Math.floor(b / N);
    const bc: number = b % N;
    return Math.abs(ar - br) + Math.abs(ac - bc) === 1;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.sel === -1) {
      this.sel = i;
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    if (!this.adjacent(this.sel, i)) {
      this.sel = i;
      return;
    }
    const t: number[] = this.board.slice();
    const tmp: number = t[this.sel];
    t[this.sel] = t[i];
    t[i] = tmp;
    if (!this.anyMatch(t)) {
      this.sel = i;
      return;
    }
    this.board = t;
    this.sel = -1;
    this.movesLeft = this.movesLeft - 1;
    this.score = this.score + this.resolve(); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    if (this.score >= TARGET) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.movesLeft <= 0) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'match3',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: MOVES - this.movesLeft
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('分数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.score) + '/' + String(TARGET))).fontSize(FontSize.md)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.movesLeft), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('连锁'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.combo), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (c: number) => {
              Stack() {
              Text(this.board.length > (r * N + c) && this.board[(r * N + c)] >= 0 ? FACES[this.board[(r * N + c)]] : '')
              .fontSize(FontSize.lg)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.board.length > (r * N + c) && this.board[(r * N + c)] >= 0 ? TINTS[this.board[(r * N + c)]] : '#00000000')
              .borderRadius(Radius.xs)
              .border({ width: this.sel === (r * N + c) ? 2 : 1, color: this.sel === (r * N + c) ? Palette.primary : this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'm' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'mr' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      .constraintSize({ maxHeight: '100%' })
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.over ? (this.won ? '🎉 达标通关！' : '步数用完了，再来一局') :
        (this.sel === -1 ? '点一个果子，再点旁边的换位' : '再点一个相邻的果子交换'))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primaryDeep).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
  }




}
