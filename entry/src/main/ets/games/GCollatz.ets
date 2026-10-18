/**
 * 考拉兹 —— 3n+1 推到 1
 *
 * 玩法：从随机起点出发，每一步从 4 个候选里选出正确的下一项
 *       （偶数除以 2，奇数乘 3 加 1），一路推到 1。
 * 胜负：推到 1 ⇒ 通关；错满 3 次 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const MISS: number = 3;          // 失误上限
const NEXT_MS: number = 460;     // 选完到下一步
const LETTERS: string[] = ['A', 'B', 'C', 'D'];

@Component
export struct GCollatz {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MISS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.livesNow(MISS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private n: number = 0;          // 当前值
  @State private start: number = 0;      // 起点
  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private steps: number = 0;
  @State private bad: number = 0;
  @State private score: number = 0;
  @State private path: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private nextTo: number = -1;
  private finished: boolean = false;
  private optsIdx: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MISS);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
  }

  private reset(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
    this.start = 10 + Math.floor(Math.random() * 90);      // 起点 10~99
    this.n = this.start;
    this.steps = 0;
    this.bad = 0;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.path = String(this.start);
    this.ask();
    this.msg = TG('偶数 ÷2 · 奇数 ×3＋1，推到 1');
  }

  private evenNext(v: number): number {
    return v % 2 === 0 ? Math.floor(v / 2) : v * 3 + 1;
  }

  private ask(): void {
    const correct: number = this.evenNext(this.n);
    const pool: number[] = this.n % 2 === 0
      ? [this.n * 3 + 1, this.n - 1, Math.floor(this.n / 2) + 1, this.n + 2]
      : [Math.floor(this.n / 2), this.n * 2 + 1, this.n + 1, this.n * 3 - 1];
    const opts: number[] = [correct];
    for (let i = 0; i < pool.length && opts.length < 4; i++) {
      if (pool[i] > 0 && pool[i] !== this.n && opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    this.opts = opts;
    this.ans = opts.indexOf(correct);
    this.picked = -1;
  }

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.score += 60;
      this.msg = this.n % 2 === 0
        ? '✅ ' + String(this.n) + ' 是偶数 → ÷2'
        : TG2('✅ {0} 是奇数 → ×3＋1', String(this.n));
    } else {
      this.bad = this.bad + 1;
      this.score = Math.max(0, this.score - 30);
      this.msg = TG2('❌ 错了（失误 {0}/{1}），正确答案已标绿', String(this.bad), String(this.diffTotal));
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.step();
    }, NEXT_MS);
  }

  /** 无论是答对还是答错，都按正确的下一步往前走（答错只记失误） */
  private step(): void {
    if (this.over) {
      return;
    }
    const nxt: number = this.evenNext(this.n);
    this.n = nxt;
    this.steps = this.steps + 1;
    this.path = this.path + ' → ' + String(nxt);
    if (this.path.length > 60) {
      this.path = '… ' + this.path.substring(this.path.length - 58);
    }
    if (this.bad >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.msg = TG2('💥 错满 {0} 次，停在 {1}',Digits(String(this.diffTotal), this.langCode), String(nxt));
      this.finish(false);
      return;
    }
    if (nxt === 1) {
      this.over = true;
      this.won = true;
      this.msg = TG2('🎉 从 {0} 推到 1，共 {1} 步！',Digits(String(this.start), this.langCode),Digits(String(this.steps), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    this.ask();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'collatz',
      solved: solved,
      score: solved ? Math.max(100, 800 - this.bad * 150 - this.steps * 4) : this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.steps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private optBg(i: number): string {
    if (this.picked < 0) {
      return this.theme.surface;
    }
    if (i === this.ans) {
      return Palette.emerald;
    }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }

  private optInk(i: number): string {
    if (this.picked < 0) {
      return this.theme.ink;
    }
    if (i === this.ans) {
      return '#FFFFFF';
    }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        Text(Digits(String(this.n), this.langCode))
          .fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.n % 2 === 0 ? Palette.teal : Palette.orange)
        Text(this.n % 2 === 0 ? '偶数 → 下一步是 ÷2' : '奇数 → 下一步是 ×3＋1')
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Column({ space: Space.sm }) {
        ForEach(this.optsIdx, (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i])
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.inkFaint)
            Text(String(this.opts[i]))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.optInk(i))
              .layoutWeight(1)
          }
          .width('100%')
          .height(Cell.of(52))
          .padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.optBg(i))
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
            this.pick(i);
          })
        }, (i: number) => 'cz' + i)
      }
      .width('100%')

      Text(this.path)
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : '换个数')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal).animation({ duration: Motion.fast, curve: Motion.snap() })
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          this.reset();
        })

      Text(TG('提示：考拉兹猜想 —— 任何正整数这样算下去最终都会落到 1'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=起点 1=步数 2=失误 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '起点' : (kind === 1 ? TG('步数') : TG('失误')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.start)
        : (kind === 1 ? String(this.steps) : this.bad + '/' + this.diffTotal))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 2 && this.bad > 0 ? Palette.rose : this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }
}
