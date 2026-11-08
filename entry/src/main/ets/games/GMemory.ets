/**
 * 记忆翻牌 —— 成对翻出
 * 规则：翻两张，相同则保留，不同则翻回；全部配对即通关
 * 用 emoji 做牌面（零美术依赖）
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
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
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private pairCount: number = GameDiff.pick(4, 6, 8);

  @State private cards: Card[] = [];
  @State private picked: number[] = [];
  @State private tries: number = 0;
  @State private done: boolean = false;
  @State private lock: boolean = false;

  private startAt: number = 0;

  /** ★ 2026-11-08 重入闩锁（结算函数可能被多路径调用；over 由调用方先置，不能当守卫） */
  private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMemory')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.pairCount = GameDiff.pick(4, 6, 8);
    this.reset();
  }

  private reset(): void {
    this.settled = false;
    this.aiKnown = [];
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
    this.aiKnown = new Array<string>(cs.length).fill('');   // ★ 记忆表：'' = 这张还没见过
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
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  /**
   * ★ 2026-11-08 代打挑牌：**只用自己记住的牌面**（`aiKnown`），不读背面真值。
   *   第一张：优先「记得、且记得它的另一张也还在」的牌；否则翻没见过的（收集信息）。
   *   第二张：从**记得的**牌里找配对；记不到就随便翻一张（和人类一样靠猜）。
   */
  private aiPick(): number {
    const n: number = this.cards.length;
    const closed: boolean[] = [];
    for (let i = 0; i < n; i++) {
      const c: Card = this.cards[i];
      closed.push(!c.matched && !c.open);
    }
    if (this.picked.length === 0) {
      for (let i = 0; i < n; i++) {
        if (!closed[i] || this.aiKnown[i].length === 0) {
          continue;
        }
        for (let j = 0; j < n; j++) {
          if (j !== i && closed[j] && this.aiKnown[j] === this.aiKnown[i]) {
            return i;                 // 记得配对 ⇒ 先翻它
          }
        }
      }
      for (let i = 0; i < n; i++) {
        if (closed[i] && this.aiKnown[i].length === 0) {
          return i;                   // 没见过 ⇒ 翻一张探路
        }
      }
      for (let i = 0; i < n; i++) {
        if (closed[i]) {
          return i;
        }
      }
      return -1;
    }
    const first: number = this.picked[0];
    const want: string = first >= 0 && first < n ? this.aiKnown[first] : '';
    if (want.length > 0) {
      for (let i = 0; i < n; i++) {
        if (i !== first && closed[i] && this.aiKnown[i] === want) {
          return i;                   // 记住了配对 ⇒ 直接翻
        }
      }
    }
    for (let i = 0; i < n; i++) {
      if (i !== first && closed[i]) {
        return i;                     // 记不到 ⇒ 猜一张
      }
    }
    return -1;
  }

  private autoStep(): boolean {
    if (this.done) {
      return false;
    }
    if (this.lock || this.done) {
      return true;
    }
    const pick: number = this.aiPick();
    if (pick < 0) {
      return false;
    }
    this.tap(pick);
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
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
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

  /**
   * ★★★ 2026-11-08 代打「不抄答案」：
   *   原来第二张牌直接比 `c.face === this.cards[picked[0]].face` —— 读的是**牌面真值**
   *   （闭着的牌玩家根本看不见）⇒ 等于透视。
   *   ⇒ 改成 AI 只记「自己翻看过的牌面」(`aiKnown[i]`)：翻开时记一笔，配对时只从**记住的**里找。
   *   记不到就退化成随便翻一张（和人类一样靠猜）。
   */
  private aiKnown: string[] = [];

  private tap(i: number): void {
    if (this.settled) {
      return;
    }
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
    if (i >= 0 && i < this.aiKnown.length) {
      this.aiKnown[i] = cur[i].face;      // ★ 它被翻开了 ⇒ AI 记住了这一张
    }
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
          this.settled = true;
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
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
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
              .onFocus(() => { this.tvFocus = 'L341'; })
              .onBlur(() => { if (this.tvFocus === 'L341') { this.tvFocus = ''; } })
              .outline(Tv.focusOutline(this.tvFocus === 'L341'))
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

      Text(this.done ? TG('🎉 全部配对！') : (this.tries >= 20 ? TG('有点多哦，沉住气') : TG('每次翻两张，找相同的')))
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkFaint)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46))
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L365'; })
        .onBlur(() => { if (this.tvFocus === 'L365') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L365'))
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
