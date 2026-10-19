/**
 * 找不同（id: odd_one_out）—— 一格里混进了一个「另一个字符」，点出来 📐
 * 10 题，答对 ≥ 8 通关；进度：题号 / 答对 / 点错次数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 10;
const WIN: number = 8;

/** 形近字符对：[[]]普通, []异类 */
function pairs(): string[][] {
  return [
    ['●', '◉'], ['■', '▪'], ['★', '☆'], ['◆', '◇'],
    ['▲', '△'], ['▶', '▷'], ['⬤', '⬥'], ['✚', '✛'],
    ['◼', '◾'], ['❍', '◯'], ['⬟', '⬠'], ['♦', '♢']
  ];
}

@Component
export struct GOddOneOut {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=10
  @State private diffTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State private glyphs: string[] = []; @State private odd: number = -1; @State private round: number = 1;
  @State private right: number = 0; @State private wrong: number = 0; @State private picked: number = -1;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private revealed: boolean = false; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false; private startAt: number = 0;
  private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearNext();
    this.round = 1;
    this.right = 0;
    this.wrong = 0;
    this.picked = -1;
    this.revealed = false;
    this.over = false;
    this.won = false;
    this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  private nextRound(): void {
    const p: string[][] = pairs();
    const one: string[] = p[Math.floor(Math.random() * p.length)];
    const n: number = this.round <= 3 ? 6 : (this.round <= 7 ? 9 : 12);
    const g: string[] = [];
    for (let i = 0; i < n; i++) {
      g.push(one[0]);
    }
    const oi: number = Math.floor(Math.random() * n);
    g[oi] = one[1];
    this.glyphs = g;
    this.odd = oi;
    this.picked = -1;
    this.revealed = false;
    this.msg = TG('有一格的字形不一样，点它 👆');
  }
  private tap(i: number): void {
    if (this.over || this.revealed) { return; }
    this.picked = i;
    this.revealed = true;
    if (i === this.odd) {
      this.right = this.right + 1;
      this.msg = TG2('✅ 就是它 · 答对 {0}/{1}', String(this.right), String(this.diffTotal));
    } else {
      this.wrong = this.wrong + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
      this.msg = TG('❌ 点错了，异类在别处');
    }
    this.clearNext();
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.over = true;
        this.done = true;
        this.won = this.right >= WIN;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
        this.finish();
        return;
      }
      this.round = this.round + 1;
      this.nextRound();
    }, 700);
  }
  private finish(): void {
    const r: GameResult = {
      gameId: 'odd_one_out', solved: this.won,
      score: this.right * 100 + (this.won ? 200 : 0) - this.wrong * 30,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('点错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
              Text((r * 3 + c < this.glyphs.length) ? this.glyphs[(r * 3 + c)] : '')
              .fontSize(FontSize.xxxl)
              .fontColor(this.colorOf((r * 3 + c)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.bgOf((r * 3 + c)))
              .borderRadius(Radius.md)
              .borderWidth(this.revealed && (r * 3 + c) === this.odd ? 2 : 0)
              .borderColor(Palette.emerald)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { Haptics.tick(); this.tap((r * 3 + c)); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：10 题答对 ≥ 8 题 · 6→9→12 格逐轮变难'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }


  private colorOf(i: number): string {
    if (!this.revealed) {
      return this.theme.ink;
    }
    if (i === this.odd) {
      return Palette.emerald;
    }
    return this.picked === i ? Palette.rose : this.theme.inkFaint;
  }
  private bgOf(i: number): string {
    if (this.revealed && i === this.odd) {
      return this.theme.isDark ? '#0F2A22' : '#D1FAE5';
    }
    return this.theme.surface;
  }
}
