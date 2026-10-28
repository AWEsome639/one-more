/** 句子重组 —— 把打乱的 6 个单词按正确语序点回去｜胜负：5 句答对 ≥4 通关，错 3 次失败 */
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

const ROUNDS: number = 5; const PASS: number = 4; const LIVES: number = 3; const GAP_MS: number = 900;

/** 全部是 6 词句，正好铺成 3×2 的格子 */
const SENTS: string[] = [
  'THE CAT SLEEPS ON THE MAT', 'SHE READS A BOOK EVERY NIGHT',
  'THE OLD MAN DREAMS ABOUT LIONS', 'RAIN FALLS SOFTLY ON THE ROOF',
  'HE KEEPS A SMALL BLUE NOTEBOOK', 'TIME FLIES WHEN WE ARE READING',
  'THE SEA RETURNS WHAT IT TAKES', 'A SMALL BOAT CROSSES THE BAY',
  'WE WALK TO SCHOOL EVERY MORNING', 'THE LAMP GLOWS IN THE DARK',
  'HIS NOTEBOOK HOLDS MANY SECRET WORDS', 'SHE SINGS A QUIET SONG TONIGHT'
];

function shufStr(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSentenceUnscramble {
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

  @State plan: string[] = []; @State tiles: string[] = []; @State pickedIdx: number[] = [];
  @State qi: number = 0; @State right: number = 0; @State lives: number = LIVES;
  @State score: number = 0; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private reset(): void {
    this.stop();
    this.plan = shufStr(SENTS).slice(0, this.diffTotal);
    this.qi = 0; this.right = 0; this.lives = LIVES; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now(); this.next();
  }

  private next(): void {
    const sent: string = this.plan[this.qi];
    const words: string[] = sent.split(' ');
    let mixed: string[] = shufStr(words);
    if (mixed.join(' ') === sent) { mixed = mixed.slice(1).concat(mixed.slice(0, 1)); }
    this.tiles = mixed; this.pickedIdx = [];
    this.msg = TG2('按正确语序点词 —— 第 {0} 句', (this.qi + 1));
  }

  private usedAt(i: number): boolean { return this.pickedIdx.indexOf(i) >= 0; }
  private placed(): string {
    const out: string[] = [];
    for (let i = 0; i < this.pickedIdx.length; i++) { out.push(this.tiles[this.pickedIdx[i]]); }
    return out.join(' ');
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
    if (this.over) {
      return false;
    }
    if (this.feed >= 0 || this.pickedIdx.length >= this.tiles.length) {
      return true;
    }
    this.pick(this.tiles.map((w: string, i: number) => (!this.usedAt(i) && w === this.plan[this.qi].split(' ')[this.pickedIdx.length]) ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const words: string[] = this.plan[this.qi].split(' ');
    const p: number = this.pickedIdx.length;
    if (p >= words.length) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('下一个词是「{0}」（第 {1} 个）', words[p], String(p + 1)),
      TG2('Next word: "{0}" (number {1})', words[p], String(p + 1)), t0);
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

  private pick(i: number): void {
    if (this.over || this.usedAt(i) || this.msg.indexOf('❌') === 0) { return; }
    const sel: number[] = this.pickedIdx.slice();
    sel.push(i); this.pickedIdx = sel;
    if (sel.length < this.tiles.length) { return; }
    if (this.placed() === this.plan[this.qi]) {
      this.right = this.right + 1; this.score = this.score + 120; this.msg = TG('✅ 语序正确！');
    } else {
      this.lives = this.lives - 1; this.msg = TG2('❌ 正确语序：{0}', this.plan[this.qi]);
    }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    if (this.lives <= 0) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 机会用尽 —— 答对 {0} / {1}', this.right, this.diffTotal);
      this.finish(false); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'sentence_unscramble', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
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
        Column({ space: Space.xs }) {
        Text((TG('句号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.qi + 1) + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('📖 已拼')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.pickedIdx.length === 0 ? '_ _ _ _ _ _' : this.placed())
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.pickedIdx.length === 0 ? this.theme.inkFaint : this.theme.ink)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Text(this.tiles.length > (0) ? this.tiles[(0)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((0)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((0)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((0)); }); })
        Text(this.tiles.length > (1) ? this.tiles[(1)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((1)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((1)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((1)); }); })
        Text(this.tiles.length > (2) ? this.tiles[(2)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((2)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((2)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((2)); }); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Text(this.tiles.length > (3) ? this.tiles[(3)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((3)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((3)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((3)); }); })
        Text(this.tiles.length > (4) ? this.tiles[(4)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((4)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((4)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((4)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((4)); }); })
        Text(this.tiles.length > (5) ? this.tiles[(5)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((5)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((5)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((5)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((5)); }); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG2("{0} 句，答对 ≥{1} 通关",Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
