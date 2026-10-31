/**
 * 心理旋转（id: mental_rotation）—— 右边那组是左边「纯旋转」，还是被偷偷镜像了？
 * 胜负：10 题答对 ≥ 8 题通关；进度：题号 / 答对 / 总旋转角度
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 5;
const ROUNDS: number = 10;
const WIN: number = 8;
const GAP: number = 2;

/** 顺时针转 90° */
function rot90(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[c * N + (N - 1 - r)] = m[r * N + c];
    }
  }
  return o;
}

/** 左右镜像 */
function mirrorX(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[r * N + c] = m[r * N + (N - 1 - c)];
    }
  }
  return o;
}

function turn(times: number, m: boolean[]): boolean[] {
  let o: boolean[] = m.slice();
  for (let i = 0; i < times; i++) {
    o = rot90(o);
  }
  return o;
}

function same(a: boolean[], b: boolean[]): boolean {
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

/** 手写的不对称图案池（不对称 ⇒ 旋转绝不会与镜像重合，答案无歧义） */
function pool(): boolean[][] {
  const g = (s: string): boolean[] => s.split('').map((ch: string) => ch === '1');
  return [
    g('1000011000001000110000100'),
    g('1110000100001001110000000'),
    g('1000001000111100100001000'),
    g('1000011000110000010000100'),
    g('1100000100111000001000000'),
    g('1000001100011000001000100'),
    g('1111100000001000001000010'),
    g('0100000100111000001001000')
  ];
}

interface Round {
  base: boolean[];
  cand: boolean[];
  mir: boolean[];
  isMirror: boolean;
  deg: number;
}

function makeRound(): Round {
  const p: boolean[][] = pool();
  const base: boolean[] = p[Math.floor(Math.random() * p.length)];
  const deg: number = (1 + Math.floor(Math.random() * 3)) * 90;
  const isMirror: boolean = Math.random() < 0.5;
  const cand: boolean[] = isMirror ? turn(deg / 90, mirrorX(base)) : turn(deg / 90, base);
  const out: Round = { base: base, cand: cand, mir: mirrorX(base), isMirror: isMirror, deg: deg };
  return out;
}

@Component
export struct GMentalRotation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=10
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State private base: boolean[] = []; @State private cand: boolean[] = []; @State private mir: boolean[] = [];
  @State private truth: boolean = false; @State private deg: number = 0; @State private round: number = 1;
  @State private right: number = 0; @State private sumDeg: number = 0; @State private picked: number = -1;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private cur: Round | null = null;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMentalRotation')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.round = 1; this.right = 0; this.sumDeg = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  private nextRound(): void {
    const r: Round = makeRound();
    this.cur = r;
    this.base = r.base; this.cand = r.cand; this.mir = r.mir;
    this.truth = r.isMirror; this.deg = r.deg; this.picked = -1;
    this.msg = TG('右边那组是怎么变来的？');
  }
  /** 提示：报「是 / 否」——代打用的表达式算出来是它 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const truth: boolean = this.truth;
    return Hint.make([],
      truth ? TG('答案是「是」') : TG('答案是「否」'),
      truth ? TG('The answer is Yes') : TG('The answer is No'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里 ⇒ 每一拍"选正确答案"；答过就等下一题（picked 守卫）
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.answer(this.truth);
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

  private answer(sayMirror: boolean): void {
    if (this.over || this.picked >= 0 || this.cur === null) { return; }
    this.picked = sayMirror ? 1 : 0;
    const hit: boolean = sayMirror === this.truth;
    if (hit) {
      this.right = this.right + 1;
      this.sumDeg = this.sumDeg + this.deg;
      this.msg = TG2('✅ 答对 · 累计转过 {0}°', String(this.sumDeg));
    } else {
      this.msg = TG2("❌ 它是{0}{1}°）", (this.truth ? '镜像（转 ' : '纯旋转（转 '), String(this.deg));
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 780);
  }
  private advance(): void {
    if (this.round >= this.diffTotal) { this.end(); return; }
    this.round = this.round + 1;
    this.nextRound();
  }
  private end(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= WIN;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
    const r: GameResult = {
      gameId: 'mental_rotation', solved: this.won,
      score: this.right * 120 + (this.won ? 240 : 0) + this.sumDeg,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('转过'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.sumDeg) + '°')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
      Text((TG('原图'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(this.rows(((this.base))))
      .fontSize(FontSize.md)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .lineHeight(FontSize.lg)
      .width('100%')
      }
      .layoutWeight(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .borderWidth((false) ? 2 : 0)
      .borderColor(Palette.emerald)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      Column({ space: Space.xs }) {
      Text((TG('右边这组'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(this.rows(((this.cand))))
      .fontSize(FontSize.md)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .lineHeight(FontSize.lg)
      .width('100%')
      }
      .layoutWeight(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .borderWidth((this.picked >= 0 && this.truth) ? 2 : 0)
      .borderColor(Palette.emerald)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.md }) {
        Button((TG('纯旋转 ⟳')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.picked === (0) ? Palette.primaryDeep : (true ? Palette.sky : Palette.violet))
        .borderRadius(Radius.lg)
        .layoutWeight(1)
        .height(Cell.of(60))
        .scale({ x: this.picked === (0) ? Motion.pressScale : 1, y: this.picked === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer(false); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(false); }); })
        Button((TG('镜像 🪞')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.picked === (1) ? Palette.primaryDeep : (false ? Palette.sky : Palette.violet))
        .borderRadius(Radius.lg)
        .layoutWeight(1)
        .height(Cell.of(60))
        .scale({ x: this.picked === (1) ? Motion.pressScale : 1, y: this.picked === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer(true); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(true); }); })
      }
      .width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：10 题答对 ≥ 8 题 · 提示：不对称图形转过 90/180/270° 的样子'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



  private rows(m: boolean[]): string {
    let out: string = '';
    for (let r = 0; r < N; r++) {
      let s: string = '';
      for (let c = 0; c < N; c++) {
        s = s + (m[r * N + c] ? '■' : '·');
      }
      out = out + (r > 0 ? '\n' : '') + s;
    }
    return out;
  }

}
