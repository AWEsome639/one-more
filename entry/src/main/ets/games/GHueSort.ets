/**
 * 色相排序 —— 交换格子，把 16 个色块按色相排成一道彩虹
 * 胜负：在本档步数上限内（简单 27 / 普通 18 / 困难 15）排成严格递增 ⇒ 通关
 * 进度：已归位 / 16 + 剩余步数
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 4;
/**
 * ★ 2026-10-29 修「困难档数学上不可能赢」：
 *   16 个格子的随机排列，排回正序最少要「16 − 环数」次交换 ⇒ 最坏（一个 16 长环）要 15 次
 *   （4/5/6/7 格穷举验证最坏 = n−1）。
 *   原来 diffTotal = lives(18) = 27 / 18 / 10 ⇒ 困难档只给 10 步 < 15 步，那档**任何局都赢不了**。
 *   改成 max(lives(MAX_MOVES), REQUIRED)：只有困难档被抬到 15（= 最坏所需），
 *   简单/普通仍是 27 / 18（普通 = 原设计，一动不动）⇒ 三档 27 / 18 / 15，都够且仍是 易 > 普 > 难。
 */
const MAX_MOVES: number = 18;
const REQUIRED: number = N * N - 1;   // 16 格最坏情形所需交换数 = 15（步数低于它 = 数学上必输）
const R4: number[] = [0, 1, 2, 3];

function hueColor(h: number): string {  // hsl(h,100%,55%) → #RRGGBB
  const c: number = 1 - Math.abs(2 * 0.55 - 1);
  const hp: number = h / 60;
  const x: number = c * (1 - Math.abs(hp % 2 - 1));
  let r: number = 0; let g: number = 0; let b: number = 0;
  if (hp < 1) { r = c; g = x; } else if (hp < 2) { r = x; g = c; }
  else if (hp < 3) { g = c; b = x; } else if (hp < 4) { g = x; b = c; }
  else if (hp < 5) { r = x; b = c; } else { r = c; b = x; }
  const m: number = 0.55 - c / 2;
  const rgb: number[] = [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)];
  let out: string = '#';
  for (let i = 0; i < 3; i++) {
    const s: string = rgb[i].toString(16).toUpperCase();
    out = out + (s.length < 2 ? '0' + s : s);
  }
  return out;
}

@Component
export struct GHueSort {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = Math.max(GameDiff.livesNow(MAX_MOVES), REQUIRED);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State hues: number[] = [];
  @State sel: number = -1; @State moves: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GHueSort')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = Math.max(GameDiff.livesNow(MAX_MOVES), REQUIRED);
     this.reset(); }

  private reset(): void {
    const mixed: number[] = [];
    for (let i = 0; i < N * N; i++) { mixed.push(Math.round(i * 360 / (N * N))); }
    for (let i = mixed.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = mixed[i]; mixed[i] = mixed[j]; mixed[j] = t;
    }
    this.hues = mixed; this.sel = -1; this.moves = 0; this.score = 0;
    this.msg = TG(TG(TG('先点一块，再点另一块交换')));
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
  }

  /** 从左上起连续「比前一块色相大」的格子数 */
  private fixed(): number {
    let n: number = 1;
    for (let i = 1; i < this.hues.length; i++) {
      if (this.hues[i] > this.hues[i - 1]) { n++; } else { break; }
    }
    return this.hues.length === 0 ? 0 : n;
  }

  private sortedAll(): boolean {
    for (let i = 1; i < this.hues.length; i++) {
      if (this.hues[i] <= this.hues[i - 1]) { return false; }
    }
    return true;
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
    if (this.sel >= 0) {
      const need: number = Math.round(this.sel * 360 / (N * N));
      for (let i = 0; i < this.hues.length; i++) {
        if (i !== this.sel && this.hues[i] === need) {
          this.tap(i);
          return !this.over;
        }
      }
      this.sel = -1;
      return true;
    }
    for (let p = 0; p < this.hues.length; p++) {
      if (this.hues[p] !== Math.round(p * 360 / (N * N))) {
        this.tap(p);
        return !this.over;
      }
    }
    return false;
  }

  /** 第 p 格应该放的色相（出题时就是按这个式子生成的） */
  private wantHue(p: number): number {
    return Math.round(p * 360 / (N * N));
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n2: number = N * N;
    if (this.sel >= 0) {
      const need: number = this.wantHue(this.sel);
      for (let i = 0; i < this.hues.length; i++) {
        if (i !== this.sel && this.hues[i] === need) {
          return Hint.make([this.sel, i],
            TG2('把它换到第 {0} 行第 {1} 列（色相 {2}°）',
              Math.floor(i / n2) + 1, i % n2 + 1, need),
            TG2('Swap it to row {0}, column {1} (hue {2})',
              Math.floor(i / n2) + 1, i % n2 + 1, need), t0);
        }
      }
    }
    for (let p = 0; p < this.hues.length; p++) {
      const need: number = this.wantHue(p);
      if (this.hues[p] === need) {
        continue;
      }
      for (let i = 0; i < this.hues.length; i++) {
        if (i !== p && this.hues[i] === need) {
          return Hint.make([p, i],
            TG2('第一处错在第 {0} 行第 {1} 列（该放 {2}°）',
              Math.floor(p / n2) + 1, p % n2 + 1, need),
            TG2('First wrong cell is row {0}, column {1} (needs hue {2})',
              Math.floor(p / n2) + 1, p % n2 + 1, need), t0);
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
    if (this.over) { return; }
    if (this.sel < 0) { this.sel = i; this.msg = TG(TG(TG('已选中，再点一块交换'))); return; }
    if (this.sel === i) { this.sel = -1; this.msg = TG('已取消选择'); return; }
    const nh: number[] = this.hues.slice();
    const t: number = nh[this.sel]; nh[this.sel] = nh[i]; nh[i] = t;
    this.hues = nh; this.sel = -1;
    this.moves = this.moves + 1; this.score = this.score + 10; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    if (this.sortedAll()) {
      this.over = true; this.won = true;
      this.score = this.score + (this.diffTotal - this.moves) * 15;
      this.msg = TG2('🎉 彩虹排好了！还剩 {0} 步没用', (this.diffTotal - this.moves));
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.msg = TG2('💤 步数用尽，归位 {0}/{1}', this.fixed(), (N * N));
      this.finish(false);
      return;
    }
    this.msg = TG(TG(TG('换了一步，继续')));
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'hue_sort', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.fixed() };
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
      Text(TG2("归位 {0}/{1}", this.fixed(), (N * N)))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.sky)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        ForEach(R4, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(R4, (c: number) => { this.swatch(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#EEF2F7').borderRadius(Radius.lg)
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(TG(TG(TG('正确顺序：左上 → 右下，色相 0° 递增到 337°'))))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  /** 色相的两位数字标签（色盲辅助：不看颜色也能排出顺序） */
  private hueText(i: number): string {
    const h: number = Math.round(this.hues[i]);
    return h < 10 ? '0' + String(h) : String(h);
  }

  @Builder
  swatch(i: number) {
    Stack() {
      // ★★★ 2026-10-29（项目 D ③ 色盲友好）：
      //   这块原来**只有一个色块**，红绿色盲/全色盲玩家根本无法判断顺序。
      //   ⇒ 在色块上叠一个**色相数字**（00~337）：
      //     · 看得见颜色的人：数字很小、几乎不打扰
      //     · 看不见颜色的人：**直接按数字排序就行**，玩法完全等价
      //   ⇒ 提示文案里本来就有「色相 {n}°」，现在方块上也对得上了。
      Text(this.hueText(i))
        .fontSize(FontSize.xs)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textShadow({ radius: 2, color: '#00000099', offsetX: 0, offsetY: 1 })
      Text(this.sel === i ? '◉' : '').fontSize(FontSize.lg).fontColor('#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(hueColor(this.hues[i]))
    .borderRadius(Radius.sm).borderWidth(this.sel === i ? 3 : 0).borderColor('#FFFFFF')
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
