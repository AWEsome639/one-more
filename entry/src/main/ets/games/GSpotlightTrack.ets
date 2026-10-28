/**
 * 聚光追踪 —— 一块亮斑在 4×5 网格里挪动，停下后点出它落脚的格子
 * 胜负：8 轮答对 ≥6 轮通关；轮次越高挪得越多
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

const COLS: number = 4;
const ROWS: number = 5;
const CELLS: number = COLS * ROWS;
const ROUNDS: number = 8;

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GSpotlightTrack {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private at: number = 0;
  @State private trails: number[] = [];   // 走过留下的余晖
  @State private chasing: boolean = true; // true 追光中 / false 该答题
  @State private round: number = 1;
  @State private hit: number = 0;
  @State private streak: number = 0;
  @State private score: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private moveId: number = -1;
  private nextTo: number = -1;
  private left: number = 0;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSpotlightTrack')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.moveId >= 0) { clearInterval(this.moveId); this.moveId = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.round = 1; this.hit = 0; this.streak = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    this.at = Math.floor(Math.random() * CELLS);
    this.trails = [];
    this.chasing = true;
    this.left = 2 + this.round;
    this.msg = '盯住亮斑，它会走 ' + String(this.left) + TG(' 步');
    this.moveId = setInterval(() => { this.step(); }, 520);
  }

  /** 每一拍挪到相邻格 */
  private step(): void {
    if (this.over) { return; }
    const c: number = this.at % COLS;
    const r: number = Math.floor(this.at / COLS);
    const opts: number[] = [];
    if (c > 0) { opts.push(this.at - 1); }
    if (c < COLS - 1) { opts.push(this.at + 1); }
    if (r > 0) { opts.push(this.at - COLS); }
    if (r < ROWS - 1) { opts.push(this.at + COLS); }
    const t: number[] = this.trails.slice();
    t.push(this.at);
    this.trails = t;
    this.at = opts[Math.floor(Math.random() * opts.length)];
    this.left = this.left - 1;
    if (this.left <= 0) {
      this.clearAll();
      this.chasing = false;
      this.msg = TG(TG(TG('停！它停在哪一格？')));
    }}

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.at   ｜ 守卫取自它自己的 if (...) { return; }
  /** 提示：报答案（字段 this.at） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.at],
      TG2('答案是第 {0} 个', String(this.at + 1)),
      TG2('The answer is option {0}', String(this.at + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (this.over || this.chasing) {
      return true;              // 追光中，不能答
    }
    if (this.nextTo >= 0) {
      return true;              // ★ 换题的 760ms 过渡期，也不该再答
    }
    this.tap(this.at);
    return !this.over;
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

  private tap(cell: number): void {
    if (this.over || this.chasing) { return; }
    if (cell === this.at) {
      this.hit = this.hit + 1;
      this.streak = this.streak + 1;
      this.score = this.score + 100 + this.streak * 20; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ 对！连对 {0}', String(this.streak));
    } else {
      this.streak = 0;
      this.msg = '❌ 它停在第 ' + String(this.at + 1) + TG(' 格');
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 760);
  }

  private advance(): void {
    if (this.round >= this.diffTotal) {
      const win: boolean = this.hit >= 6;
      this.over = true; this.won = win;
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 轮", String(this.hit), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'spotlight_track', solved: win, score: this.score,
        durationMs: Date.now() - this.startAt, levelReached: this.round
      };
      if (!this.done) { this.done = true; LanRace.noteDone(); this.onFinish(res); }
      return;
    }
    this.round = this.round + 1;
    this.newRound();
  }

  /** 亮斑本身 / 余晖 / 空地 */
  private tint(cell: number): string {
    if (this.chasing && cell === this.at) { return Palette.amber; }
    if (this.chasing && has(this.trails, cell)) { return this.theme.lineSoft; }
    return this.theme.surface;
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
      Row() {
        Text(TG2("轮次 {0}/{1}",Digits(String(this.round), this.langCode),Digits(String(this.diffTotal), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + String(this.hit)).fontSize(FontSize.sm).fontColor(Palette.primary)
        Text(TG2('连对 {0}', String(this.streak))).fontSize(FontSize.sm).fontColor(this.theme.ink)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              this.cellView(r * COLS + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.md).fontColor(this.chasing ? this.theme.inkSoft : Palette.primary)
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(cell: number) {
    Stack() {
      Text(this.chasing && cell === this.at ? '🔆' : '').fontSize(FontSize.lg)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(cell)).borderRadius(Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(cell); })
  }
}
