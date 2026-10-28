/** 速算 —— 60 秒限时心算抢答｜拿到 100 分过关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const LIMIT: number = 60;
const PASS: number = 100;

interface QA { q: string; ans: number; opts: number[] }

function makeQA(): QA {
  const kind: number = Math.floor(Math.random() * 3);
  let a: number = 0;
  let b: number = 0;
  let ans: number = 0;
  let q: string = '';
  if (kind === 0) {
    a = 11 + Math.floor(Math.random() * 89);
    b = 11 + Math.floor(Math.random() * 89);
    ans = a + b;
    q = String(a) + ' + ' + String(b);
  } else if (kind === 1) {
    a = 31 + Math.floor(Math.random() * 69);
    b = 11 + Math.floor(Math.random() * (a - 20));
    ans = a - b;
    q = String(a) + ' − ' + String(b);
  } else {
    a = 3 + Math.floor(Math.random() * 17);
    b = 3 + Math.floor(Math.random() * 10);
    ans = a * b;
    q = String(a) + ' × ' + String(b);
  }
  const cands: number[] = [ans + 1, ans - 1, ans + 2, ans - 2, ans + 10, ans - 10, ans + 3];
  const opts: number[] = [ans];
  for (let i = 0; i < cands.length && opts.length < 4; i++) {
    const v: number = cands[i];
    if (v > 0 && opts.indexOf(v) < 0) { opts.push(v); }
  }
  for (let i = opts.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = opts[i];
    opts[i] = opts[j];
    opts[j] = t;
  }
  return { q: q, ans: ans, opts: opts };
}

@Component
export struct GQuickMath {
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
  @State private q: string = '';
  @State private ans: number = 0;
  @State private opts: number[] = [];
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private combo: number = 0;
  @State private best: number = 0;
  @State private flash: string = TG('60 秒，能答多少答多少');
  @State private over: boolean = false;
  private startAt: number = 0;
  private tick: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => { this.beat(); }, 1000);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GQuickMath')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; } }

  private reset(): void {
    this.startAt = Date.now();
    this.left = this.total;
    this.score = 0;
    this.right = 0;
    this.wrong = 0;
    this.combo = 0;
    this.best = 0;
    this.over = false;
    this.flash = TG('60 秒，能答多少答多少');
    this.next();
  }

  private next(): void {
    const item: QA = makeQA();
    this.q = item.q;
    this.ans = item.ans;
    this.opts = item.opts;
  }

  private beat(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) {
      this.left = 0;
      this.finish();
    }
  }

  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.ans],
      TG2('答案是第 {0} 个', String(this.ans + 1)),
      TG2('The answer is option {0}', String(this.ans + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：v === this.ans  ｜ 守卫取自它自己的 if (...) { return; }
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
    if (this.over) {
      return true;
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

  private choose(v: number): void {
    if (this.over) { return; }
    if (v === this.ans) {
      this.combo++;
      if (this.combo > this.best) { this.best = this.combo; }
      const gain: number = 10 + this.combo;
      this.score += gain; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.right++;
      this.flash = TG2('✓ +{0}，连击 {1}', String(gain), String(this.combo));
    } else {
      this.wrong++;
      this.combo = 0;
      this.left = this.left - 3;
      this.flash = TG2('✗ {0} = {1}，扣 3 秒', this.q,Digits(String(this.ans), this.langCode));
      if (this.left <= 0) {
        this.left = 0;
        this.finish();
        return;
      }
    }
    this.next();
  }

  private finish(): void {
    if (this.over) { return; }
    this.over = true;
    this.flash = TG2('时间到｜答对 {0}、答错 {1}', String(this.right), String(this.wrong));
    const res: GameResult = {
      gameId: 'quick_math', solved: this.score >= PASS,
      score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
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
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最高连击'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.best), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.q + ' = ?').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.over ? '本局已结束，点重开再来' : '抢答，答错扣 3 秒').fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.flash).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        ForEach([0, 1], (i: number) => { Button(this.opts.length > (i) ? String(this.opts[(i)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .enabled(!this.over && this.opts.length > (i)).onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'a' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach([2, 3], (i: number) => { Button(this.opts.length > (i) ? String(this.opts[(i)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .enabled(!this.over && this.opts.length > (i)).onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'b' + i)
      }.width('100%')
      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.emerald)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('连击越高分越多')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
