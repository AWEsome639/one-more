/** 字母换位 —— 3×3 格子点两个字母交换，按行排成目标单词
 *  胜负：排好 ⇒ 通关；步数用尽 ⇒ 失败 ｜ 进度：步数 / 就位字母数 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 3; const CELLS: number = 9; const MAX_MOVE: number = 24;
const WORDS: string[] = ['ADVENTURE', 'CHOCOLATE', 'EDUCATION', 'MOUNTAINS', 'TELEPHONE',
  'BEAUTIFUL', 'DISCOVERY', 'LIGHTNING', 'BLUEPRINT', 'GARDENING'];
function shuffled(text: string): string[] {
  const out: string[] = text.split('');
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: string = out[i]; out[i] = out[j]; out[j] = tmp;
  }
  return out;
}

@Component
export struct GLetterGridSwapper {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(3);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State tiles: string[] = []; @State goal: string = ''; @State sel: number = -1;
  @State moves: number = 0; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false; @State pressed: number = -1;
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
     this.reset(); }
  private reset(): void {
    const w: string = WORDS[Math.floor(Math.random() * WORDS.length)];
    let arr: string[] = shuffled(w);
    for (let g = 0; g < 20 && arr.join('') === w; g++) { arr = shuffled(w); }
    this.goal = w; this.tiles = arr; this.sel = -1; this.moves = 0;
    this.over = false; this.won = false; this.done = false; this.pressed = -1;
    this.msg = TG('点两个字母交换位置'); this.startAt = Date.now();
  }
  private placed(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { if (this.tiles[i] === this.goal.charAt(i)) { n = n + 1; } }
    return n;
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
    if (this.moves >= MAX_MOVE) {
      return true;
    }
    this.tap(this.sel < 0 ? this.tiles.map((t: string, i: number) => (t !== this.goal.charAt(i)) ? i : -1).filter((v: number) => v >= 0)[0] : this.tiles.map((t: string, i: number) => (t === this.goal.charAt(this.sel) && t !== this.goal.charAt(i)) ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.diffTotal * this.diffTotal;
    let a: number = this.sel;
    if (a < 0) {
      for (let i = 0; i < n; i++) {
        if (this.tiles[i] !== this.goal.charAt(i)) {
          a = i;
          break;
        }
      }
    }
    if (a < 0) {
      return Hint.none('none');
    }
    const want: string = this.goal.charAt(a);
    const ra: number = Math.floor(a / this.diffTotal) + 1;
    const ca: number = (a % this.diffTotal) + 1;
    return Hint.make([a],
      TG2('第 {0} 行第 {1} 列该是「{2}」', String(ra), String(ca), want)
        + TG2('，现在这里放着「{0}」', this.tiles[a]),
      TG2('Row {0}, column {1} should be "{2}"', String(ra), String(ca), want)
        + TG2(', but it holds "{0}" right now', this.tiles[a]), t0);
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
    if (this.over) { return; }
    const first: number = this.sel;
    if (first < 0) { this.sel = i; this.msg = TG('再点一个字母与它交换'); return; }
    if (first === i) { this.sel = -1; this.msg = TG('已取消选择'); return; }
    const next: string[] = this.tiles.slice();
    const tmp: string = next[i]; next[i] = next[first]; next[first] = tmp;
    this.tiles = next; this.sel = -1; this.moves = this.moves + 1;
    if (next.join('') === this.goal) {
      this.over = true; this.won = true;
      this.msg = TG2("🎉 排好了，用了 {0} 步",Digits(String(this.moves), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.moves >= MAX_MOVE) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 步数用尽，答案是 {0}', this.goal);
      this.finish(false);
      return;
    }
    this.msg = TG2('已就位 {0}/{1}', String(this.placed()), String(CELLS));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const score: number = solved ? Math.max(60, (MAX_MOVE - this.moves) * 40) : this.placed() * 10;
    const r: GameResult = { gameId: 'letter_grid_swapper', solved: solved, score: score,
      durationMs: Date.now() - this.startAt, levelReached: this.moves };
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
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(MAX_MOVE))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('就位'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed()) + '/' + String(CELLS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('目标单词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.goal).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.rowIdx(), (c: number) => {
              Text(this.tiles.length > (r * this.diffTotal + c) ? this.tiles[(r * this.diffTotal + c)] : '')
              .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
              .fontColor(this.sel === (r * this.diffTotal + c) ? '#FFFFFF' : this.theme.ink).layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.sel === (r * this.diffTotal + c) ? Palette.amber : this.theme.surface)
              .borderRadius(Radius.md).shadow(Shadow.card)
              .scale({ x: this.pressed === (r * this.diffTotal + c) ? Motion.pressScale : 1, y: this.pressed === (r * this.diffTotal + c) ? Motion.pressScale : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) { this.pressed = (r * this.diffTotal + c); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
              })
              .onClick(() => { Haptics.tick(); this.tap((r * this.diffTotal + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：按行从左到右读，读出来就是目标单词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
