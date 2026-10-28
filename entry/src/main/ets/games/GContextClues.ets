/**
 * 上下文线索 —— 读英文例句，从语境推断生词的意思（四选一）
 * 胜负：10 题答对 ≥8 题通关；错 3 次即失败
 * 进度：题号 / 答对数 / 生命 / 得分
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
const ROUNDS: number = 10; const PASS: number = 8; const LIVES: number = 3;
interface Q { s: string; w: string; opts: string[] }
/** opts[0] 恒为正确释义，运行时打乱 */
const POOL: Q[] = [
  { s: 'The arid desert offered no shade for miles.', w: 'arid', opts: ['干旱的', '潮湿的', '寒冷的', '肥沃的'] },
  { s: 'She gave a terse reply and hurried out.', w: 'terse', opts: ['简短生硬的', '冗长啰嗦的', '热情洋溢的', '含糊不清的'] },
  { s: 'The doctor said the drug alleviated her pain.', w: 'alleviated', opts: ['减轻了', '加剧了', '忽视了', '引发了'] },
  { s: 'He was meticulous about every detail of the plan.', w: 'meticulous', opts: ['一丝不苟的', '粗心大意的', '漫不经心的', '慷慨大方的'] },
  { s: 'The boisterous crowd drowned out the speaker.', w: 'boisterous', opts: ['喧闹的', '安静的', '悲伤的', '整齐的'] },
  { s: 'They shared a frugal meal of bread and soup.', w: 'frugal', opts: ['节俭的', '奢侈的', '丰盛的', '辛辣的'] },
  { s: 'The evidence was ambiguous, so the jury hesitated.', w: 'ambiguous', opts: ['模棱两可的', '确凿无疑的', '伪造的', '充分的'] },
  { s: 'She remained stoic through the whole ordeal.', w: 'stoic', opts: ['坚忍克制的', '惊慌失措的', '兴高采烈的', '犹豫不决的'] },
  { s: 'The rancid butter made the whole kitchen smell.', w: 'rancid', opts: ['变质发臭的', '新鲜可口的', '香甜的', '昂贵的'] },
  { s: 'He tends to procrastinate until the last night.', w: 'procrastinate', opts: ['拖延', '提前完成', '彻底放弃', '不断抱怨'] },
  { s: 'The view from the ridge was sublime.', w: 'sublime', opts: ['壮丽崇高的', '平庸乏味的', '恐怖吓人的', '熟悉亲切的'] },
  { s: 'Her candid remarks surprised the whole room.', w: 'candid', opts: ['坦率的', '虚伪的', '含糊的', '客套的'] }
];
@Component
export struct GContextClues {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
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
  onFinish: (r: GameResult) => void = () => {};
  @State order: number[] = []; @State qi: number = 0; @State opts: string[] = [];
  @State ans: number = 0; @State picked: number = -1; @State correct: number = 0;
  @State life: number = LIVES; @State score: number = 0; @State over: boolean = false;
  @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  private cur(): Q { return POOL[this.order[this.qi]]; }
  private reset(): void {
    this.qi = 0; this.correct = 0; this.life = LIVES; this.score = 0;
    this.picked = -1; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    const idx: number[] = []; const out: number[] = [];
    for (let i = 0; i < POOL.length; i++) { idx.push(i); }
    for (let i = 0; i < this.diffTotal; i++) {
      const p: number = Math.floor(Math.random() * idx.length);
      out.push(idx[p]); idx.splice(p, 1);
    }
    this.order = out;
    this.deal();
  }
  private deal(): void {
    const arr: string[] = this.cur().opts.slice();
    for (let i = arr.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    this.opts = arr; this.ans = arr.indexOf(this.cur().opts[0]);
    this.picked = -1; this.msg = TG('这句话里，这个词是什么意思？');
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项（这款的答案就存在 this.ans 里） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是「{0}」', this.opts[n]),
      TG2('The answer is "{0}"', this.opts[n]), t0);
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
    if (this.picked >= 0) {
      // ★ 这款**没有定时器**：「下一题」是玩家自己点的按钮（第 198 行）
      //   所以代打必须自己按，否则会一直在原地等
      this.nextQ();
      return !this.over;
    }
    this.choose(this.ans);
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

  private choose(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = i;
    if (i === this.ans) {
      this.correct = this.correct + 1; this.score = this.score + 100;
      this.msg = TG2('✅ 对！「{0}」正是此意', this.cur().w);
    } else {
      this.life = this.life - 1;
      this.msg = TG2("❌ 不对，正解是「{0}」，还剩 {1} 条命", this.cur().opts[0],Digits(String(this.life), this.langCode));
    }
    if (this.life <= 0) { this.end(); }
  }
  private nextQ(): void {
    if (this.over) { return; }
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1;
    this.deal();
  }
  private end(): void {
    this.over = true; this.won = this.correct >= PASS && this.life > 0;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.correct, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'context_clues', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.correct };
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.correct + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.sm }) {
        Text(this.cur().s).fontSize(FontSize.md).fontColor(this.theme.ink).width('100%')
        Text(TG2('生词：{0}', this.cur().w)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
          .fontColor(Palette.berry)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Text((this.opts.length > 0 ? this.opts[0] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(44))
      .fontColor(this.picked >= 0 && ((0) === this.ans || (0) === this.picked) ? '#FFFFFF' : this.theme.ink)
      .backgroundColor(this.bg((0))).borderRadius(Radius.md).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.choose((0)); })
      Text((this.opts.length > 1 ? this.opts[1] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(44))
      .fontColor(this.picked >= 0 && ((1) === this.ans || (1) === this.picked) ? '#FFFFFF' : this.theme.ink)
      .backgroundColor(this.bg((1))).borderRadius(Radius.md).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.choose((1)); })
      Text((this.opts.length > 2 ? this.opts[2] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(44))
      .fontColor(this.picked >= 0 && ((2) === this.ans || (2) === this.picked) ? '#FFFFFF' : this.theme.ink)
      .backgroundColor(this.bg((2))).borderRadius(Radius.md).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.choose((2)); })
      Text((this.opts.length > 3 ? this.opts[3] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(44))
      .fontColor(this.picked >= 0 && ((3) === this.ans || (3) === this.picked) ? '#FFFFFF' : this.theme.ink)
      .backgroundColor(this.bg((3))).borderRadius(Radius.md).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.choose((3)); })
      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Button(this.picked < 0 ? '选一个释义' : '下一题 →')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .enabled(this.picked >= 0).onClick(() => { Haptics.tap(); this.nextQ(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).width(96).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.reset(); })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


  /** 作答后上色：正解绿、选错的那个红 */
  private bg(i: number): string {
    if (this.picked < 0) { return this.theme.surface; }
    if (i === this.ans) { return Palette.emerald; }
    if (i === this.picked) { return Palette.rose; }
    return this.theme.surface;
  }
}
