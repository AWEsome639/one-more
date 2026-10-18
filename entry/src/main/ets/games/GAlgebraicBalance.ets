/** 代数天平（Algebraic Balance）—— 解一元一次方程求 x
 *  玩法：从 4 个候选值里点出 x。过关判据：10 题答对 ≥ 7 题
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
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
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.violet).borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { this.reset(); })
        Text(TG('点候选值 → 立刻判分')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
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
      .enabled(!this.lockTap && !this.over).onClick(() => { this.answer(this.eq.choices[k] ?? 0); })
  }
}
