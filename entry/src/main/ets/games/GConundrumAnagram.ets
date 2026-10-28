/**
 * 谜语字谜 —— 读英文谜面猜一个单词；卡住可看字母乱序（anagram）提示
 * 胜负：6 则谜语猜中 ≥5 则通关，错 3 次或一直放弃即失败　进度：题号 / 猜中 / 生命 / 得分
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const ROUNDS: number = 6; const PASS: number = 5; const LIVES: number = 3;
interface R { q: string; a: string; hint: string }
const POOL: R[] = [
  { q: 'What becomes shorter when you add two letters to it?', a: 'SHORT', hint: '加两个字母，它反而更短' }, { q: 'I am an odd number; take away one letter and I become even.', a: 'SEVEN', hint: '去掉一个字母，奇数变偶数' },
  { q: 'What has a face and two hands but no arms?', a: 'CLOCK', hint: '有脸有手，却无手臂' }, { q: 'What gets wetter the more it dries?', a: 'TOWEL', hint: '越擦越湿' },
  { q: 'What has a head and a tail but no body?', a: 'COIN', hint: '有头有尾，没有身子' }, { q: 'What has teeth but cannot bite?', a: 'COMB', hint: '有齿不能咬' },
  { q: 'What has a neck but no head?', a: 'BOTTLE', hint: '有颈无头' }, { q: 'What has an eye but cannot see?', a: 'NEEDLE', hint: '有眼不能看' },
  { q: 'What has many keys but opens no lock?', a: 'PIANO', hint: '键很多，却开不了锁' }, { q: 'What can travel the world while staying in a corner?', a: 'STAMP', hint: '走遍世界，却一直待在角落' },
  { q: 'What has words but never speaks?', a: 'BOOK', hint: '满纸文字，从不开口' }, { q: 'The more you take, the more you leave behind.', a: 'FOOTSTEPS', hint: '取得越多，身后留得越多' }
];
/** 字母乱序（anagram 提示） */
function scramble(w: string): string {
  const arr: string[] = [];
  for (let i = 0; i < w.length; i++) { arr.push(w.charAt(i)); }
  for (let i = arr.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = arr[i]; arr[i] = arr[j]; arr[j] = t;
  }
  return arr.join(' ');
}
@Component
export struct GConundrumAnagram {
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
  @State order: number[] = []; @State qi: number = 0; @State input: string = '';
  @State solved: number = 0; @State life: number = LIVES; @State score: number = 0;
  @State hinted: boolean = false; @State over: boolean = false; /** ★ 动效：进度数字弹动 */ @State bump: number = 1; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GConundrumAnagram')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  private cur(): R { return POOL[this.order[this.qi]]; }
  private reset(): void {
    this.qi = 0; this.solved = 0; this.life = LIVES; this.score = 0; this.input = '';
    this.hinted = false; this.over = false; this.won = false; this.done = false;
    this.msg = TG('谜底是一个英文单词，答案用大写'); this.startAt = Date.now();
    const idx: number[] = []; const out: number[] = [];
    for (let i = 0; i < POOL.length; i++) { idx.push(i); }
    for (let i = 0; i < this.diffTotal; i++) {
      const p: number = Math.floor(Math.random() * idx.length);
      out.push(idx[p]); idx.splice(p, 1);
    }
    this.order = out;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在 this.cur().a；submit() 读的是 this.input ⇒ 先填词再走玩家的提交路径
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
    if (this.over) {
      return false;
    }
    this.submitWord(this.cur().a);
    return !this.over;
  }

  /** 提示：直接报谜底单词（谜面是英文谜语，报字母数帮不上忙） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const a: string = this.cur().a;
    return Hint.make([], TG2('谜底是 {0}（{1} 个字母）', a, a.length),
      TG2('The answer is {0}', a), t0);
  }

  /** AI 用：先把答案填进输入框，再走玩家的 submit（提交里会自己 trim/大写） */
  private submitWord(w: string): void {
    this.input = w;
    this.submit();
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

  private submit(): void {
    if (this.over) { return; }
    const guess: string = this.input.trim().toUpperCase();
    this.input = '';
    if (guess.length === 0) { return; }
    if (guess === this.cur().a) {
      this.solved = this.solved + 1; this.score = this.score + 120;
      this.msg = TG2('✅ 正是 {0}！', this.cur().a);
      this.nextQ();
    } else {
      this.life = this.life - 1;
      this.msg = TG2('❌ 「{0}」不对，还剩 {1} 条命（可看乱序提示）', guess,Digits(String(this.life), this.langCode));
      if (this.life <= 0) { this.end(); }
    }
  }
  private hint(): void {
    if (this.over || this.hinted) { return; }
    this.hinted = true; this.score = this.score > 40 ? this.score - 40 : 0;
    this.msg = TG2('🔤 字母乱序：{0}', scramble(this.cur().a));
  }
  private skip(): void {
    if (this.over) { return; }
    this.life = this.life - 1; this.input = ''; this.msg = TG2("⏭ 放弃：谜底是 {0}", this.cur().a);
    if (this.life <= 0) { this.end(); return; }
    this.nextQ();
  }
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private nextQ(): void {
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1;
    this.doBump();   // ★ 弹一下 this.hinted = false;
  }
  private end(): void {
    this.over = true; this.won = this.solved >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("猜中 {0} / {1}", this.solved, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'conundrum_anagram', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.solved };
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
// ★ 动效：进度一变就弹一下
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('猜中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.solved + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
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
        Text(TG('🤔 谜面')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.cur().q).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).width('100%')
          .fontColor(this.theme.ink)
        Text(TG2('线索：{0}', this.cur().hint)).fontSize(FontSize.sm).fontColor(Palette.emerald)
        Text(TG2("谜底 {0} 个字母", this.cur().a.length)).fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: '输入谜底（英文）' })
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .padding({ left: Space.sm, right: Space.sm })
          .onChange((v: string) => { this.input = v; }).onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.emerald)
          .borderRadius(Radius.md).width(84).height(Cell.of(46)).enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); })
          .onClick(() => { Haptics.tap(); this.submit(); })
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.sm }) {
        Button(TG('字母乱序（-40 分）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.hint(); }); }).onClick(() => { Haptics.tap(); this.hint(); })
        Button(TG('放弃（-1 命）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.skip(); }); }).onClick(() => { Haptics.tap(); this.skip(); })
      }
      .width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
