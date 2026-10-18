/** 记忆矩阵 —— 亮格闪一下，凭记忆全部点出来；过 5 关通关，点错 3 次失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 3;
const CELLS: number = N * N;
const PASS_LEVEL: number = 5;
const LIVES: number = 3;
const SHOW_MS: number = 1500;

@Component
export struct GMemoryMatrix {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  @State private lit: boolean[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private need: number = 0;
  @State private picks: number[] = [];
  @State private wrong: number[] = [];
  @State private level: number = 1;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private lives: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private phase: number = 0;   // 0 展示 / 1 作答 / 2 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private showTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.showTo >= 0) { clearTimeout(this.showTo); this.showTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  /** 本局要画几颗心（读 this.lives 建立 ArkUI 依赖，否则不重渲染） */
  private heartIdx(): number[] {
    const observed: number = this.lives;
    const n: number = this.total > 0 ? this.total : 3;
    const a: number[] = [];
    for (let i = 0; i < n; i++) {
      a.push(i);
    }
    return observed >= 0 ? a : a;
  }

  private reset(): void {
    this.clearAll();
    this.level = 1; this.lives = this.total; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newLevel();
  }

  private newLevel(): void {
    const k: number = Math.min(1 + this.level, CELLS - 2);
    const slots: number[] = [];
    for (let i = 0; i < CELLS; i++) { slots.push(i); }
    for (let i = slots.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = slots[i]; slots[i] = slots[j]; slots[j] = t;
    }
    const flags: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let i = 0; i < k; i++) { flags[slots[i]] = true; }
    this.lit = flags; this.need = k; this.picks = []; this.wrong = []; this.phase = 0;
    this.msg = TG('第 ') + String(this.level) + ' 关：记住 ' + String(k) + ' 个亮格';
    this.showTo = setTimeout(() => {
      this.showTo = -1; this.phase = 1; this.msg = TG(TG(TG('把亮过的格子点出来')));
    }, SHOW_MS);
  }

  private tap(i: number): void {
    if (this.over || this.phase !== 1) { return; }
    if (this.picks.indexOf(i) >= 0 || this.wrong.indexOf(i) >= 0) { return; }
    if (this.lit[i]) {
      const next: number[] = this.picks.slice();
      next.push(i);
      this.picks = next;
      if (next.length < this.need) {
        this.msg = TG('还差 ') + String(this.need - next.length) + TG(' 格');
        return;
      }
      this.score = this.score + 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.level >= PASS_LEVEL) {
        this.phase = 2; this.over = true; this.won = true;
        this.msg = TG('🎉 通关！') + String(PASS_LEVEL) + ' 关全过';
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.level = this.level + 1;
      this.msg = TG(TG(TG('✅ 过关')));
      this.nextTo = setTimeout(() => { this.nextTo = -1; this.newLevel(); }, 620);
      return;
    }
    const bad: number[] = this.wrong.slice();
    bad.push(i);
    this.wrong = bad;
    this.lives = this.lives - 1;
    if (this.lives <= 0) {
      this.phase = 2; this.over = true; this.won = false;
      this.msg = '❌ 生命耗尽，止步第 ' + String(this.level) + TG(' 关');
      this.finish(false);
      return;
    }
    this.msg = '❌ 这格没亮过，还剩 ' + String(this.lives) + TG(' 条命');
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'memory_matrix', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    if (this.phase === 0) { return this.lit[i] ? Palette.primary : this.theme.surfaceAlt; }
    if (this.phase === 1) {
      if (this.picks.indexOf(i) >= 0) { return Palette.emerald; }
      return this.wrong.indexOf(i) >= 0 ? Palette.rose : this.theme.surfaceAlt;
    }
    return this.lit[i] ? Palette.emerald : this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2('关卡 {0}', (String(this.level) + '/' + String(PASS_LEVEL)))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2("得分 {0}",Digits(String(this.score), this.langCode))).fontSize(FontSize.xs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.ink)
        Text(TG2('还需 {0}', this.phase === 1 ? String(Math.max(this.need - this.picks.length, 0)) : '—')).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Row({ space: Space.xs }) {
        // ★ 心数按**本局实际命数**渲染（简单 5 / 普通 3 / 困难 1），
        //   以前写死 [0,1,2] ⇒ 简单档 5 条命只画 3 颗，玩家看不出难度差别
        ForEach(this.heartIdx(), (k: number) => {
          Text('❤️').accessibilityLevel('no').fontSize(FontSize.md).opacity(k < this.lives ? 1 : 0.2).animation({ duration: Motion.fast, curve: Motion.snap() })
        }, (k: number) => 'h' + k)
      }.width('100%').justifyContent(FlexAlign.Center)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .onClick(() => { this.reset(); })

      Text(TG('提示：每关多一格，点错扣一条命'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(this.phase === 1 && this.picks.indexOf(i) >= 0 ? '✓'
        : (this.phase === 1 && this.wrong.indexOf(i) >= 0 ? '✕' : ''))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { this.tap(i); })
  }
}
