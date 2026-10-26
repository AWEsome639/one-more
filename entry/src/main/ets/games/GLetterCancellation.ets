/**
 * 字母划消 —— 在字母盘里划掉指定字母：漏点会扣剩余时间，点错直接罚 3 秒
 * 胜负：划满 3 盘通关｜进度：盘数 / 已划 / 剩余秒数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6; const CELLS: number = N * N;
const TARGETS: number = 8; const PLATES: number = 3;
const LIMIT_S: number = 40; const TICK_MS: number = 500;
const ALL: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

@Component
export struct GLetterCancellation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_S 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_S);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State g: string[] = []; @State target: string = 'A'; @State hit: number[] = [];
  @State plate: number = 0; @State need: number = TARGETS; @State wrong: number = 0;
  @State score: number = 0; @State leftS: number = this.diffTotal; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_S);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }
  private reset(): void {
    this.stop();
    this.plate = 0; this.wrong = 0; this.score = 0; this.leftS = this.diffTotal;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('划掉盘里所有的目标字母');
    this.startAt = Date.now();
    this.load();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private load(): void {
    this.target = ALL[Math.floor(Math.random() * ALL.length)];
    const grid: string[] = [];
    for (let i = 0; i < CELLS; i++) {
      grid.push(ALL[Math.floor(Math.random() * ALL.length)]);
    }
    const slots: number[] = [];
    for (let i = 0; i < CELLS; i++) { slots.push(i); }
    for (let i = slots.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = slots[i]; slots[i] = slots[j]; slots[j] = t;
    }
    for (let k = 0; k < TARGETS; k++) {
      grid[slots[k]] = this.target;
    }
    let cnt: number = 0;
    for (let i = 0; i < grid.length; i++) {
      if (grid[i] === this.target) { cnt = cnt + 1; }
    }
    this.need = cnt;
    this.g = grid;
    this.hit = [];
  }
  private tick(): void {
    if (this.over) { return; }
    this.leftS = this.leftS - 0.5;
    if (this.leftS <= 0) {
      this.leftS = 0; this.over = true; this.won = false;
      this.msg = TG2('⌛ 时间到 —— 划完 {0} / {1} 盘', this.plate, PLATES); this.finish(false);
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 真值直取：找出所有等于目标字母的格子
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    // 真值直取：g[i] === target 且还没被点过 ⇒ 点它
    for (let i = 0; i < this.g.length; i++) {
      if (this.g[i] === this.target && this.hit.indexOf(i) < 0) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
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

  private tap(i: number): void {
    if (this.over || this.hit.indexOf(i) >= 0) { return; }
    if (this.g[i] !== this.target) {
      this.wrong = this.wrong + 1;
      this.leftS = this.leftS - 3;
      this.msg = TG2('❌ 这不是「{0}」，罚 3 秒', this.target);
      if (this.leftS <= 0) {
        this.leftS = 0; this.over = true; this.won = false;
        this.finish(false);
      }
      return;
    }
    this.hit = this.hit.concat([i]);
    this.score = this.score + 30;
    if (this.hit.length >= this.need) {
      this.plate = this.plate + 1;
      if (this.plate >= PLATES) {
        this.over = true; this.won = true;
        this.score = this.score + Math.floor(this.leftS) * 20;
        this.msg = TG2('🎉 通关：划完 {0} 盘', PLATES); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.load();
      this.msg = TG2("✅ 第 {0} 盘清空，下一盘！", this.plate);
      return;
    }
    this.msg = TG2('✅ 还剩 {0} 个「{1}」', (this.need - this.hit.length), this.target);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'letter_cancellation', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.plate };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({

        onAutoTap: () => { this.askAuto(); },

        showHint: false,

        autoOn: this.autoId >= 0

      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('盘数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.plate + ' / ' + PLATES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.berry))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已划'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hit.length + ' / ' + this.need)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('点错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.ceil(this.leftS) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Row({ space: Space.sm }) {
        Text(TG('目标')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        Text(this.target).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.berry)
        Text(TG2("盘里共 {0} 个", this.need)).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').justifyContent(FlexAlign.Center)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              Text(this.g.length > (r * N + c) ? this.g[(r * N + c)] : '').fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.hit.indexOf((r * N + c)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).aspectRatio(1).backgroundColor(this.hit.indexOf((r * N + c)) >= 0 ? Palette.berry : this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * N + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)


      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('划满 {0} 盘通关；漏一个罚 3 秒，点错也罚 3 秒', PLATES)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
