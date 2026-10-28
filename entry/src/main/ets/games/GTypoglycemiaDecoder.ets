/**
 * 乱序解码 —— 每个词只保留首尾字母，中间打乱；靠语感读出原句，再选出正确的一句
 * 胜负：6 句里读对 ≥ 4 句通关 ｜ 进度：第几句 / 读对数 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { Digits, I18n } from '../core/I18n';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 6; const PASS: number = 4; const FEED_MS: number = 1100;

interface Typh { text: string; d1: string; d2: string; gloss: string }

const BANK: Typh[] = [
  { text: 'the quick brown fox jumps over the lazy dog', d1: 'the quick brown fox jumps over the lazy cat', d2: 'the quick green fox jumps over the lazy dog', gloss: '疾狐跃过懒狗' },
  { text: 'a journey of a thousand miles begins with a single step', d1: 'a journey of a thousand miles begins with a single stride', d2: 'a journey of a hundred miles begins with a single step', gloss: '千里之行，始于足下' },
  { text: 'the early bird catches the worm before sunrise', d1: 'the early bird catches the fish before sunrise', d2: 'the early bird eats the worm before sunrise', gloss: '早起的鸟儿有虫吃' },
  { text: 'practice makes perfect when the work is repeated daily', d1: 'practice makes progress when the work is repeated daily', d2: 'practice makes perfect when the task is repeated daily', gloss: '熟能生巧' },
  { text: 'a rolling stone gathers no moss along the long road', d1: 'a rolling stone gathers no dust along the long road', d2: 'a rolling rock gathers no moss along the long road', gloss: '滚石不生苔' },
  { text: 'every cloud has a silver lining after the storm', d1: 'every cloud has a golden lining after the storm', d2: 'every cloud has a silver lining after the rain', gloss: '乌云镶银边' }
];

/** 从 0..total-1 中随机取 k 个互不相同的下标（k=total 就是整段洗牌） */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

/** 首尾照原样，中间洗牌 */
function scrambleWord(w: string): string {
  if (w.length <= 3) { return w; }
  const mid: string[] = [];
  for (let i = 1; i < w.length - 1; i++) { mid.push(w.charAt(i)); }
  const mixed: string[] = pickIndexes(mid.length, mid.length).map((k: number) => mid[k]);
  return w.charAt(0) + mixed.join('') + w.charAt(w.length - 1);
}

function scrambleLine(s: string): string {
  const ws: string[] = s.split(' '); const out: string[] = [];
  for (let i = 0; i < ws.length; i++) { out.push(scrambleWord(ws[i])); }
  return out.join(' ');
}

@Component
export struct GTypoglycemiaDecoder {
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

  @State private order: number[] = []; @State private qi: number = 0;
  @State private jumbled: string = ''; @State private opts: string[] = [];
  @State private right: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private picked: number = -1; @State private locked: boolean = false;
  @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private cur(): Typh { return BANK[this.order[this.qi]]; }

  private reset(): void {
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
    this.order = pickIndexes(BANK.length, this.diffTotal);
    this.qi = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.picked = -1; this.locked = false;
    this.startAt = Date.now(); this.load();
  }

  private load(): void {
    const item: Typh = this.cur();
    const raw: string[] = [item.text, item.d1, item.d2];
    this.jumbled = scrambleLine(item.text);
    this.opts = pickIndexes(3, 3).map((k: number) => raw[k]);
    this.picked = -1; this.locked = false;
    this.msg = TG('把乱序的句子读顺，再选出它原本的样子');
  }

  /** 提示：和代打同一个循环（含局部常量），只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const want: string = this.cur().text;
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === want) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 选项直取：找 opts[i] === cur().text
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
    if (this.locked) {
      return true;              // 已答，等它换下一题
    }
    const want: string = this.cur().text;
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === want) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
  }


  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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
    if (this.over || this.locked) { return; }
    this.locked = true; this.picked = i;
    if (this.opts[i] === this.cur().text) {
      this.right = this.right + 1; this.score = this.score + 150; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ 读对了：{0}', this.cur().gloss);
    } else {
      this.msg = TG2('❌ 原句是：{0}', this.cur().text);
    }
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1; this.load();
  }

  private end(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.right >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("读对 {0}/{1}", this.right, this.diffTotal);
    const r: GameResult = { gameId: 'typoglycemia_decoder', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Text(TG2('句 {0}/{1}　读对 {2}', Math.min(this.qi + 1, this.diffTotal), this.diffTotal, this.right))
          .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).layoutWeight(1)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.xl)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(TG('乱序句')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.jumbled).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(Palette.orange).maxLines(5)
        Text(TG2('大意：{0}', this.cur().gloss)).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.opts, (o: string, i: number) => { this.option(o, i) },
          (o: string, i: number) => 'o' + i + o)
      }.width('100%')
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.xs).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(TG('提示：首尾字母没动，中间只是被洗过牌')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  option(text: string, i: number) {
    Text(text).fontSize(FontSize.sm).textAlign(I18n.isRTL() ? TextAlign.End : TextAlign.Start).maxLines(3)
      .fontColor(this.locked && (this.picked === i || this.opts[i] === this.cur().text) ? '#FFFFFF' : this.theme.ink)
      .width('100%').padding(Space.sm).borderRadius(Radius.md).shadow(Shadow.card)
      .backgroundColor(this.locked && this.opts[i] === this.cur().text
        ? Palette.emerald : (this.locked && this.picked === i ? Palette.rose : this.theme.surface))
      .scale({ x: this.picked === i ? Motion.pressScale : 1, y: this.picked === i ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
