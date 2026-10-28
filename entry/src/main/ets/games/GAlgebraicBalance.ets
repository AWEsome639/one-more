/** 代数天平（Algebraic Balance）—— 解一元一次方程求 x
 *  玩法：从 4 个候选值里点出 x。过关判据：10 题答对 ≥ 7 题
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const TOTAL: number = 10;
const PASS: number = 7;

interface Eq { text: string; answer: number; choices: number[] }

function pick(dist: number[], x0: number): number[] {
  const pool: number[] = [x0 + 1, x0 - 1, -x0, x0 + 2, x0 - 2, 0];
  const out: number[] = [];
  for (let k = 0; k < pool.length && out.length < 3; k++) {
    let dup: boolean = false;
    for (let j = 0; j < out.length; j++) {
      if (out[j] === pool[k]) { dup = true; }
    }
    if (!dup && pool[k] !== x0) { out.push(pool[k]); }
  }
  for (let k = 0; k < out.length; k++) { dist.push(out[k]); }
  return dist;
}

function makeEq(): Eq {
  const a: number = 2 + Math.floor(Math.random() * 4);
  const x0: number = -6 + Math.floor(Math.random() * 13);
  const b: number = 1 + Math.floor(Math.random() * 9);
  const form: number = Math.floor(Math.random() * 3);
  let text: string = '';
  let rhs: number = 0;
  if (form === 0) {
    rhs = a * x0 + b;
    text = String(a) + 'x + ' + String(b) + ' = ' + String(rhs);
  } else if (form === 1) {
    rhs = a * x0 - b;
    text = String(a) + 'x - ' + String(b) + ' = ' + String(rhs);
  } else {
    rhs = a * (x0 + b);
    text = String(a) + '(x + ' + String(b) + ') = ' + String(rhs);
  }
  const bag: number[] = [x0];
  pick(bag, x0);
  for (let i = bag.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = bag[i];
    bag[i] = bag[j];
    bag[j] = t;
  }
  return { text: text, answer: x0, choices: bag };
}

@Component
export struct GAlgebraicBalance {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private eq: Eq = { text: '', answer: 0, choices: [] };
  @State private idx: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('点一个候选值');
  @State private lockTap: boolean = false;

  private startAt: number = 0;
  private wait: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  aboutToDisappear(): void {
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
  }

  private reset(): void {
    this.startAt = Date.now();
    this.idx = 0;
    this.right = 0;
    this.score = 0;
    this.over = false;
    this.lockTap = false;
    this.tip = TG('点一个候选值');
    this.eq = makeEq();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：answer(v) 里比 v === this.eq.answer
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
    if (this.lockTap) {
      return true;
    }
    this.answer(this.eq.answer);
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
  private answer(v: number): void {
    if (this.over || this.lockTap) { return; }
    const good: boolean = v === this.eq.answer;
    if (good) {
      this.right++;
      this.score += 10;
      TG2('✓ 平衡了，x = {0}', String(this.eq.answer))
    } else {
      TG2('✗ 正确答案 x = {0}', String(this.eq.answer))
    }
    this.lockTap = true;
    this.wait = setTimeout(() => {
      this.wait = -1;
      this.idx++;
      if (this.idx >= this.diffTotal) {
        this.over = true;
        this.tip = TG2("共答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
        this.finish(this.right >= PASS);
        return;
      }
      this.eq = makeEq();
      this.lockTap = false;
      this.tip = TG('点一个候选值');
    }, 650);
  }


  /**
   * ★ 2026-10-23 第二期：代数天平提示
   *
   * 三种题型（见 makeEq）：
   *   ax + b = rhs ｜ ax - b = rhs ｜ a(x + b) = rhs
   * ⇒ 提示只给**解方程的步骤**，不给 x 的值：
   *   「先两边减 b，再除以 a」
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const txt: string = this.eq.text;
    if (txt.length === 0) {
      return Hint.none('none');
    }
    // 从文本里抓系数 a 与常数 b
    let a: number = 1;
    let b: number = 0;
    const paren: boolean = txt.indexOf('(') >= 0;
    const m1: RegExpMatchArray | null = txt.match(/^(\d+)/);
    if (m1 !== null) {
      a = Number(m1[1]);
    }
    const m2: RegExpMatchArray | null = txt.match(/([+-])\s*(\d+)/);
    if (m2 !== null) {
      b = Number(m2[2]);
    }
    const isMinus: boolean = m2 !== null && m2[1] === '-';
    if (paren) {
      return Hint.make([],
        TG4('先把两边都除以 {0}，再把 {1} 移到右边（{2}）', String(a), String(b), isMinus ? '加回来' : '减过去'),
        TG4('Divide both sides by {0}, then move {1} to the right', String(a), String(b)), t0);
    }
    if (isMinus) {
      return Hint.make([],
        TG4('先把两边都加上 {0}，再除以 {1}', String(b), String(a)),
        TG4('Add {0} to both sides first, then divide by {1}', String(b), String(a)), t0);
    }
    return Hint.make([],
      TG4('先把两边都减去 {0}，再除以 {1}', String(b), String(a)),
      TG4('Subtract {0} from both sides first, then divide by {1}', String(b), String(a)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'algebraic_balance', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
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
        this.stat(TG('进度'), 0)
        this.stat(TG('答对'), 1)
        this.stat(TG('得分'), 2)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text('⚖️').accessibilityLevel('no').fontSize(FontSize.hero)
        Text(this.eq.text).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.base, curve: Motion.snap() })

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.tip.startsWith('✓') ? Palette.emerald : this.theme.inkSoft)

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          this.choice(0)
          this.choice(1)
        }.width('100%')
        Row({ space: Space.sm }) {
          this.choice(2)
          this.choice(3)
        }.width('100%')
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(42))
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.violet).borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('点候选值 → 立刻判分')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  /**
   * 状态格
   * ★ 收「种类」而不是「算好的字符串」—— `@Builder` 的参数**不会建立观察**，
   *   传算好的串时，`diffTotal` 从 10 变 13 了但 Builder 还用旧参数（实测踩过）。
   *   改成在**内部**读 `this.diffTotal`（`@State`）⇒ ArkUI 才追踪得到。
   */
  @Builder
  stat(label: string, kind: number) {
    Column({ space: 2 }) {
      Text(label).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? (String(this.idx + 1) + '/' + String(this.diffTotal))
        : (kind === 1 ? String(this.right) : String(this.score)))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
  }

  @Builder
  choice(k: number) {
    Button('x = ' + String(this.eq.choices[k] ?? 0))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
      .enabled(!this.lockTap && !this.over).onClick(() => { Haptics.tap(); this.answer(this.eq.choices[k] ?? 0); })
  }
}
