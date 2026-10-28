/**
 * 记忆翻牌 —— 成对翻出
 * 规则：翻两张，相同则保留，不同则翻回；全部配对即通关
 * 用 emoji 做牌面（零美术依赖）
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const FACES: string[] = ['🍎', '🍇', '🍋', '🍒', '🥝', '🍑', '🌰', '🫐'];

interface Card {
  face: string;
  open: boolean;
  matched: boolean;
}

@Component
export struct GMemory {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  // ★ 难度作用到玩法：对数（简单 4 对 / 普通 6 对 / 困难 8 对）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private pairCount: number = GameDiff.pick(4, 6, 8);

  @State private cards: Card[] = [];
  @State private picked: number[] = [];
  @State private tries: number = 0;
  @State private done: boolean = false;
  @State private lock: boolean = false;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.pairCount = GameDiff.pick(4, 6, 8);
    this.reset();
  }

  private reset(): void {
    const deck: string[] = FACES.slice(0, this.pairCount).concat(FACES.slice(0, this.pairCount));   // 8 对 = 16 张
    for (let i = deck.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = deck[i];
      deck[i] = deck[j];
      deck[j] = t;
    }
    const cs: Card[] = deck.map((f: string) => {
      const c: Card = { face: f, open: false, matched: false };
      return c;
    });
    this.cards = cs;
    this.picked = [];
    this.tries = 0;
    this.done = false;
    this.lock = false;
    this.startAt = Date.now();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.done) {
      return false;
    }
    if (this.lock || this.done) {
      return true;
    }
    this.tap(this.picked.length === 0 ? this.cards.map((c: Card, i: number) => (!c.matched && !c.open) ? i : -1).filter((v: number) => v >= 0)[0] : this.cards.map((c: Card, i: number) => (!c.matched && !c.open && i !== this.picked[0] && c.face === this.cards[this.picked[0]].face) ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.done;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.done) {
      return Hint.none('none');
    }
    for (let a = 0; a < this.cards.length; a++) {
      if (this.cards[a].matched || this.cards[a].open) {
        continue;
      }
      for (let b = a + 1; b < this.cards.length; b++) {
        if (!this.cards[b].matched && !this.cards[b].open && this.cards[b].face === this.cards[a].face) {
          return Hint.make([a, b],
            TG2('翻第 {0} 张和第 {1} 张，都是 {2}', String(a + 1), String(b + 1), this.cards[a].face),
            TG2('Flip cards {0} and {1} — both are {2}', String(a + 1), String(b + 1), this.cards[a].face), t0);
        }
      }
    }
    return Hint.none('none');
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

  private tap(i: number): void {
    if (this.lock || this.done) {
      return;
    }
    const cur: Card[] = this.cards.map((c: Card) => {
      const n: Card = { face: c.face, open: c.open, matched: c.matched };
      return n;
    });
    if (cur[i].open || cur[i].matched) {
      return;
    }
    cur[i].open = true;
    this.cards = cur;
    const p: number[] = this.picked.concat([i]);
    this.picked = p;

    if (p.length === 2) {
      this.tries++;
      const a: number = p[0];
      const b: number = p[1];
      if (cur[a].face === cur[b].face) {
        const c2: Card[] = this.cards.map((c: Card) => {
          const n: Card = { face: c.face, open: c.open, matched: c.matched };
          return n;
        });
        c2[a].matched = true;
        c2[b].matched = true;
        c2[a].open = false;
        c2[b].open = false;
        this.cards = c2;
        this.picked = [];
        if (c2.every((c: Card) => c.matched)) {
          this.done = true;
          const r: GameResult = {
            gameId: 'memory',
            solved: true,
            score: Math.max(100, 1000 - (this.tries - 8) * 60),
            durationMs: Date.now() - this.startAt,
            levelReached: this.tries
          };
          LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
          this.onFinish(r);
        }
      } else {
        this.lock = true;
        setTimeout(() => {
          const c3: Card[] = this.cards.map((c: Card) => {
            const n: Card = { face: c.face, open: c.open, matched: c.matched };
            return n;
          });
          c3[a].open = false;
          c3[b].open = false;
          this.cards = c3;
          this.picked = [];
          this.lock = false;
        }, 700);
      }
    }
  }

  build() {
    Column({ space: Space.lg }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('翻牌次数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.tries), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已配对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.matchedCount() + '/8')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              if ((this.cards[r * 4 + c]) !== undefined && ((this.cards[r * 4 + c]).open || (this.cards[r * 4 + c]).matched)) {
              Text((this.cards[r * 4 + c]).face).fontSize(FontSize.xxl)
              } else {
              Text('?').accessibilityText(TG('待求')).fontSize(FontSize.xl).fontColor('#66FFFFFF')
                .accessibilityLevel('no')
              }
              }
              .layoutWeight(1)
              .aspectRatio(0.82)
              .backgroundColor(
              ((this.cards[r * 4 + c]) !== undefined && ((this.cards[r * 4 + c]).open || (this.cards[r * 4 + c]).matched))
              ? ((this.cards[r * 4 + c]).matched ? '#1A10B981' : this.theme.surface)
              : Palette.violet
              )
              .borderRadius(Radius.md)
              .shadow(Shadow.card)
              .rotate({ angle: ((this.cards[r * 4 + c]) !== undefined && (this.cards[r * 4 + c]).open) ? 0 : 180 })
              .animation({ duration: Motion.base, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * 4 + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * 4 + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.done ? '🎉 全部配对！' : (this.tries >= 20 ? '有点多哦，沉住气' : '每次翻两张，找相同的'))
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkFaint)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46))
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
    .width('100%').height('100%')
  }

  private matchedCount(): number {
    let n: number = 0;
    this.cards.forEach((c: Card) => {
      if (c.matched) {
        n++;
      }
    });
    return n / 2;
  }




}
