/** 分数配对 —— 匹配等值分数（翻牌记忆）；玩法：8 张牌两两成对，一对是等值的两个分数；每次翻两张；胜负：60 秒内配齐 4 对 ⇒ 通关；超时 ⇒ 失败 */
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
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';

const PAIRS: number = 4; const CARD: number = 8; const LIMIT: number = 60; const HIDE_MS: number = 700;
/** 8 个互不相等的基准分数：分子 / 分母 */
const BASE_N: number[] = [1, 1, 2, 1, 3, 2, 3, 5]; const BASE_D: number[] = [2, 3, 3, 4, 4, 5, 5, 6];
const ROWS: number[] = [0, 1]; const COLS: number[] = [0, 1, 2, 3];
@Component
export struct GFractionMatch {
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
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private labels: string[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private keys: string[] = [];
  @State private open: number[] = [];
  @State private done: boolean[] = [];
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private matched: number = 0;
  @State private tries: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private tick: number = -1; private hideTo: number = -1;
  private finished: boolean = false; private pool: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFractionMatch')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
  }
  private reset(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
    this.left = this.total; this.matched = 0; this.tries = 0; this.score = 0;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now(); this.deal(); this.msg = TG('翻两张：值相等的分数即为一对');
    this.tick = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.left = this.left - 1;
      if (this.left <= 0) {
        this.left = 0;
        if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
        if (!this.over) {
          this.over = true; this.won = false;
          this.msg = TG2('⏰ 时间到，只配了 {0}/{1} 对', String(this.matched), String(PAIRS)); this.finish(false);
        }
      }
    }, 1000);
  }
  /** 发牌：每对给「约分前」与「约分后」各一张，打乱 */
  private deal(): void {
    const pickPool: number[] = this.pool.slice(); const order: number[] = [];
    for (let t = 0; t < PAIRS; t++) {
      const at: number = Math.floor(Math.random() * pickPool.length); const bi: number = pickPool[at];
      pickPool.splice(at, 1); order.push(bi); order.push(bi);
    }
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1)); const t: number = order[i]; order[i] = order[j]; order[j] = t;
    }
    const labels: string[] = []; const keys: string[] = []; const seen: number[] = new Array<number>(PAIRS).fill(0);
    for (let i = 0; i < order.length; i++) {
      const bi: number = order[i]; const mult: number = seen[bi] === 0 ? (Math.random() < 0.5 ? 2 : 3) : 1;
      seen[bi] = seen[bi] + 1; labels.push(String(BASE_N[bi] * mult) + '/' + String(BASE_D[bi] * mult)); keys.push(String(bi));
    }
    this.labels = labels; this.keys = keys; this.open = []; this.done = new Array<boolean>(CARD).fill(false);
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
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
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

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.open.length >= 2) {
      return true;
    }
    if (this.open.length === 1) {
      const a: number = this.open[0];
      for (let i = 0; i < CARD; i++) {
        if (i !== a && !this.done[i] && this.keys[i] === this.keys[a]) {
          this.flip(i);
          return !this.over;
        }
      }
      return true;
    }
    for (let i = 0; i < CARD; i++) {
      if (!this.done[i]) {
        this.flip(i);
        return !this.over;
      }
    }
    return false;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.open.length === 1) {
      const a: number = this.open[0];
      for (let i = 0; i < CARD; i++) {
        if (i !== a && !this.done[i] && this.keys[i] === this.keys[a]) {
          return Hint.make([i],
            TG2('这张「{0}」和已翻开的「{1}」正好相等 ⇒ 翻它', this.labels[i], this.labels[a]),
            TG2('{0} equals the open card {1} — flip it', this.labels[i], this.labels[a]), t0);
        }
      }
    }
    for (let i = 0; i < CARD; i++) {
      if (this.done[i]) {
        continue;
      }
      for (let j = i + 1; j < CARD; j++) {
        if (!this.done[j] && this.keys[i] === this.keys[j]) {
          return Hint.make([i, j],
            TG2('第 {0} 张和第 {1} 张是一对（都是「{2}」）', i + 1, j + 1, this.labels[i]),
            TG2('Cards {0} and {1} are a pair (both {2})', i + 1, j + 1, this.labels[i]), t0);
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

  private flip(i: number): void {
    if (this.over || this.done[i] || this.open.indexOf(i) >= 0 || this.open.length >= 2) { return; }
    const cur: number[] = this.open.concat([i]); this.open = cur;
    if (cur.length < 2) { return; }
    this.tries = this.tries + 1;
    if (this.keys[cur[0]] === this.keys[cur[1]]) {
      const nd: boolean[] = this.done.slice(); nd[cur[0]] = true; nd[cur[1]] = true; this.done = nd; this.open = [];
      this.matched = this.matched + 1; this.score += 150;
      if (this.matched >= PAIRS) {
        this.over = true; this.won = true; this.msg = TG2("🎉 4 对全配齐，共翻 {0} 次",Digits(String(this.tries), this.langCode)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.msg = TG2('✅ 等值！还剩 {0} 对', String(PAIRS - this.matched)); return;
    }
    this.score = Math.max(0, this.score - 10); this.msg = TG('❌ 不等值，记好位置再来');
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); }
    this.hideTo = setTimeout(() => { this.hideTo = -1; this.open = []; }, HIDE_MS);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    const r: GameResult = {
      gameId: 'fraction_match', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.matched
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private face(i: number): string {
    if (this.done[i] || this.open.indexOf(i) >= 0) { return this.labels[i]; }
    return '?';
  }
  private cardBg(i: number): string {
    if (this.done[i]) { return Palette.emerald; }
    if (this.open.indexOf(i) >= 0) { return Palette.violet; }
    return this.theme.surface;
  }
  private cardInk(i: number): string {
    if (this.done[i] || this.open.indexOf(i) >= 0) { return '#FFFFFF'; }
    return this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('配对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.matched + '/' + PAIRS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('翻牌'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.tries), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach(ROWS, (row: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (col: number) => {
              Stack() {
              Text(this.face((row * 4 + col))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.cardInk((row * 4 + col)))
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cardBg((row * 4 + col))).borderRadius(Radius.md).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.flip((row * 4 + col)); }); }).onClick(() => { Haptics.tick(); this.flip((row * 4 + col)); })
            }, (col: number) => 'fmc' + col)
          }.width('100%')
        }, (row: number) => 'fmr' + row)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：2/4 与 1/2 等值 —— 同乘（同除）同一个数，分数大小不变')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
