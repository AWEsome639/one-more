/**
 * 单词蛇 —— 用方向键操纵小蛇去吃字母，按顺序拼出目标单词
 * 胜负：拼完 3 个词通关｜生命（吃错/撞墙/咬自己）耗尽失败｜进度：第几个词 / 已拼 / 生命
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

const N: number = 8; const CELLS: number = N * N; const TICK_MS: number = 430;
const ROUNDS: number = 3; const LIVES: number = 5;
const LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const WORDS: string[] = ['CAT', 'DOG', 'SUN', 'MAP', 'ICE', 'BUS', 'FOX', 'JAM', 'KEY', 'OWL'];
function randLetter(): string { return LETTERS.charAt(Math.floor(Math.random() * LETTERS.length)); }
function mixList(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GWordSnakeTrail {
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
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State letters: string[] = []; @State body: number[] = []; @State dir: number = 0;
  @State target: string = ''; @State queue: string[] = []; @State round: number = 0;
  @State spelled: number = 0; @State lives: number = LIVES; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private len: number = 3; private startAt: number = 0; private timer: number = -1;
  private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordSnakeTrail')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }
  private stopTimer(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }
  private reset(): void {
    this.stopTimer();
    const grid: string[] = [];
    for (let i = 0; i < CELLS; i++) { grid.push(randLetter()); }
    this.letters = grid; this.queue = mixList(WORDS).slice(0, this.diffTotal);
    this.round = 0; this.spelled = 0; this.lives = LIVES; this.score = 0;
    this.over = false; this.won = false; this.settled = false;
    this.loadWord(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.step(); }, TICK_MS);
  }
  private loadWord(): void {
    this.target = this.queue.length > this.round ? this.queue[this.round] : 'CAT';
    this.spelled = 0; this.len = 3; this.body = [27, 28, 29]; this.dir = 0; this.fillNeed();
    this.msg = TG2('去吃 {0}，按顺序拼出 {1}', this.target.charAt(0), this.target);
  }
  /** 保证下一个要吃的字母在盘上至少 3 个 */
  private fillNeed(): void {
    const need: string = this.target.charAt(this.spelled);
    const g: string[] = this.letters.slice();
    let cnt: number = 0;
    for (let i = 0; i < CELLS; i++) { if (g[i] === need) { cnt++; } }
    for (let guard = 0; guard < 120 && cnt < 3; guard++) {
      const i: number = Math.floor(Math.random() * CELLS);
      if (g[i] === need || this.body.indexOf(i) >= 0) { continue; }
      g[i] = need; cnt = cnt + 1;
    }
    this.letters = g;
  }
  /** ★ AI 代打/提示共用：朝「下一个要吃的字母」那一格的方向（0 上 1 右 2 下 3 左，-1 = 没法走） */
  /** 优先挑字母对得上的邻格（吃到算对）；没有就退而求其次挑任意能走的格 */
  private bestDir(): number {
    if (this.body.length === 0) {
      return -1;
    }
    const head: number = this.body[0];
    const r: number = Math.floor(head / N);
    const c: number = head % N;
    const need: string = this.target.charAt(this.spelled);
    let safe: number = -1;
    let any: number = -1;
    for (let d = 0; d < 4; d++) {
      let nr: number = r;
      let nc: number = c;
      if (d === 0) {
        nr = r - 1;
      } else if (d === 1) {
        nc = c + 1;
      } else if (d === 2) {
        nr = r + 1;
      } else {
        nc = c - 1;
      }
      if (nr < 0 || nr >= N || nc < 0 || nc >= N) {
        continue;
      }
      const at: number = nr * N + nc;
      if (this.body.indexOf(at) >= 0) {
        continue;
      }
      if (((this.dir + 2) % 4) === d && this.body.length > 1) {
        continue;
      }
      if (any < 0) {
        any = d;
      }
      if (this.letters.length > at && this.letters[at] === need) {
        safe = d;
        break;
      }
    }
    return safe >= 0 ? safe : any;
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
    const d: number = this.bestDir();
    if (d < 0) {
      return false;
    }
    this.turn(d);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const need: string = this.target.charAt(this.spelled);
    const d: number = this.bestDir();
    if (d < 0) {
      return Hint.make([],
        TG2('下一个要吃的字母是 {0}，但四个方向都堵死了', need),
        TG2('The next letter is {0}, but all four directions are blocked', need), t0);
    }
    const dirs: string[] = [TG('上'), TG('右'), TG('下'), TG('左')];
    return Hint.make([],
      TG2('往下要拼 {0}，下一个字母是 {1} ⇒ 往{2}走', this.target, need, dirs[d]),
      TG2('Spelling {0}; next letter is {1} — go {2}', this.target, need, dirs[d]), t0);
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

  private turn(d: number): void {
    if (this.over || ((this.dir + 2) % 4 === d && this.body.length > 1)) { return; }
    this.dir = d;
  }
  private crash(why: string): void {
    this.lives = this.lives - 1;
    if (this.lives <= 0) { this.over = true; this.msg = TG2('❌ {0}，生命耗尽', why); this.finish(false); return; }
    this.body = [27, 28, 29]; this.dir = 0;
    this.msg = TG2("💥 {0}，还剩 {1} 条命", why,Digits(String(this.lives), this.langCode));
  }
  private step(): void {
    if (this.over || this.body.length === 0) { return; }
    const head: number = this.body[0];
    const r: number = Math.floor(head / N); const c: number = head % N;
    let nr: number = r; let nc: number = c;
    if (this.dir === 0) { nr = r - 1; } else if (this.dir === 1) { nc = c + 1; }
    else if (this.dir === 2) { nr = r + 1; } else { nc = c - 1; }
    if (nr < 0 || nr >= N || nc < 0 || nc >= N) { this.crash(TG('撞墙')); return; }
    const next: number = nr * N + nc;
    if (this.body.indexOf(next) >= 0) { this.crash(TG('咬到自己')); return; }
    const grown: number[] = [next].concat(this.body);
    while (grown.length > this.len) { grown.pop(); }
    this.body = grown;
    const cell: string = this.letters[next];
    const g: string[] = this.letters.slice(); g[next] = randLetter();
    if (cell !== this.target.charAt(this.spelled)) { this.letters = g; this.crash(cell + ' 不是下一个字母'); return; }
    this.spelled = this.spelled + 1; this.score = this.score + 50; this.len = this.len + 1;
    this.letters = g;
    if (this.spelled < this.target.length) {
      this.fillNeed();
      this.msg = TG2('✅ 吃到 {0}，继续找 {1}', cell, this.target.charAt(this.spelled));
      return;
    }
    this.score = this.score + 200; this.round = this.round + 1;
    if (this.round < this.diffTotal) { this.loadWord(); this.msg = TG2('✅ 拼完一个词，下一个：{0}', this.target); return; }
    this.over = true; this.won = true; this.score = this.score + this.lives * 100;
    this.msg = TG2('🎉 {0} 个词全拼完，通关！',Digits(String(this.diffTotal), this.langCode)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true; this.stopTimer();
    const r: GameResult = { gameId: 'word_snake_trail', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private toneAt(i: number): string { const at: number = this.body.indexOf(i); return at === 0 ? Palette.emerald : (at > 0 ? Palette.primary : this.theme.surface); }
  build() {
    Column({ space: Space.sm }) {
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
        Column({ space: Space.xs }) {
        Text((TG('第几个'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.round + 1) + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已拼'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.spelled + ' / ' + this.target.length)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + ' ❤')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Text(TG2('目标 {0}｜得分 {1}', this.target,Digits(String(this.score), this.langCode))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (c: number) => { Text(this.letters.length > (r * N + c) ? this.letters[(r * N + c)] : '').fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.body.indexOf((r * N + c)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).aspectRatio(1).backgroundColor(this.toneAt((r * N + c))).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Button(('↑'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(42)).onClick(() => { Haptics.tap(); this.turn((0)); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.turn((0)); }); })
        Button(('←'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(42)).onClick(() => { Haptics.tap(); this.turn((3)); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.turn((3)); }); })
        Button(('↓'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(42)).onClick(() => { Haptics.tap(); this.turn((2)); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.turn((2)); }); })
        Button(('→'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(42)).onClick(() => { Haptics.tap(); this.turn((1)); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.turn((1)); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(42)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
      Text(TG('提示：吃错字母、撞墙、咬自己都扣一条命')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
