/**
 * 24 点 —— 4 个数，用 ＋ − × ÷ 凑出 24
 *
 * 玩法：
 *   · 开局随机 4 个数（1~13），**穷举校验保证一定有解**
 *   · 点一个数 → 点另一个数 → 点一个运算符 ⇒ 两个数合并成一个结果
 *   · 凑出 24 通关；走不通可以「撤销」或「换一题」
 * 算理：全程用**精确分数**（分子/分母 + 约分），不碰浮点误差，
 *       所以 8 ÷ (3 − 8 ÷ 3) = 24 这类分数解也判得准。
 * 判据：只剩一个数且等于 24 ⇒ 通关
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
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

const TARGET: number = 24;        // 目标值
const COUNT: number = 4;          // 4 个数
const MIN_V: number = 1;
const MAX_V: number = 13;         // A~K
const TICK_MS: number = 1000;
const TILE: number = 64;          // 数字牌的边长
const OP_KEYS: string[] = ['＋', '−', '×', '÷'];

/** 精确分数：值 = n / d（d 恒 > 0、已约分）；text 是表达式文本 */
interface Frac {
  n: number;
  d: number;
  text: string;
}

@Component
export struct GGame24 {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TARGET 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TARGET);
  onFinish: (r: GameResult) => void = () => {};

  @State private items: Frac[] = [];        // 还没合并的数（前 4 个是原题）
  @State private origin: number[] = [];     // 本题的 4 个原始数字
  @State private selA: number = -1;         // 第一个数
  @State private selB: number = -1;         // 第二个数
  @State private status: string = '';
  @State private tip: string = '';
  @State private merges: number = 0;
  @State private hints: number = 0;
  @State private seconds: number = 0;
  @State private done: boolean = false;
  @State private undoDepth: number = 0;

  private hist: Frac[][] = [];              // 撤销栈
  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TARGET);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  // ────────────────────────── 分数运算 ──────────────────────────

  private gcd(a: number, b: number): number {
    let x: number = a < 0 ? -a : a;
    let y: number = b < 0 ? -b : b;
    while (y !== 0) {
      const t: number = x % y;
      x = y;
      y = t;
    }
    return x === 0 ? 1 : x;
  }

  private mk(n: number, d: number, text: string): Frac {
    let num: number = n;
    let den: number = d;
    if (den < 0) {
      num = -num;
      den = -den;
    }
    const g: number = this.gcd(num, den);
    const f: Frac = { n: num / g, d: den / g, text: text };
    return f;
  }

  /** 玩家点的运算符：0=+ 1=− 2=× 3=÷（a 在前、b 在后） */
  private applyOp(a: Frac, b: Frac, op: number): Frac | null {
    if (op === 0) {
      return this.mk(a.n * b.d + b.n * a.d, a.d * b.d, '(' + a.text + ' ＋ ' + b.text + ')');
    }
    if (op === 1) {
      return this.mk(a.n * b.d - b.n * a.d, a.d * b.d, '(' + a.text + ' − ' + b.text + ')');
    }
    if (op === 2) {
      return this.mk(a.n * b.n, a.d * b.d, '(' + a.text + ' × ' + b.text + ')');
    }
    if (b.n === 0) {
      return null;                    // 不能除以 0
    }
    return this.mk(a.n * b.d, a.d * b.n, '(' + a.text + ' ÷ ' + b.text + ')');
  }

  /** 求解器用：两个数的全部 6 种合并（含交换律的两种顺序） */
  private combos(a: Frac, b: Frac): Frac[] {
    const out: Frac[] = [];
    const plus: Frac | null = this.applyOp(a, b, 0);
    const minus: Frac | null = this.applyOp(a, b, 1);
    const cross: Frac | null = this.applyOp(a, b, 2);
    const div: Frac | null = this.applyOp(a, b, 3);
    const revMinus: Frac | null = this.applyOp(b, a, 1);
    const revDiv: Frac | null = this.applyOp(b, a, 3);
    if (plus !== null) {
      out.push(plus);
    }
    if (minus !== null) {
      out.push(minus);
    }
    if (revMinus !== null) {
      out.push(revMinus);
    }
    if (cross !== null) {
      out.push(cross);
    }
    if (div !== null) {
      out.push(div);
    }
    if (revDiv !== null) {
      out.push(revDiv);
    }
    return out;
  }

  /** 穷举：从当前这堆数出发，能不能凑到 24；能就返回一个解法的表达式 */
  private solve(list: Frac[]): Frac | null {
    if (list.length === 1) {
      const f: Frac = list[0];
      return f.n === this.diffTotal * f.d ? f : null;
    }
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const rest: Frac[] = [];
        for (let k = 0; k < list.length; k++) {
          if (k !== i && k !== j) {
            rest.push(list[k]);
          }
        }
        const cs: Frac[] = this.combos(list[i], list[j]);
        for (let c = 0; c < cs.length; c++) {
          const next: Frac[] = rest.concat([cs[c]]);
          const hit: Frac | null = this.solve(next);
          if (hit !== null) {
            return hit;
          }
        }
      }
    }
    return null;
  }

  /** 去掉最外面那层括号，看着清爽：((3 − 2) × (4 × 6)) → (3 − 2) × (4 × 6) */
  private pretty(t: string): string {
    if (t.length > 2 && t.charAt(0) === '(' && t.charAt(t.length - 1) === ')') {
      return t.substring(1, t.length - 1);
    }
    return t;
  }

  private fracText(f: Frac): string {
    return f.d === 1 ? String(f.n) : f.n + '/' + f.d;
  }

  /** 越界保护：取第 i 张数牌 */
  private fracAt(i: number): Frac {
    if (i >= 0 && i < this.items.length) {
      return this.items[i];
    }
    const blank: Frac = { n: 0, d: 1, text: '0' };
    return blank;
  }

  private sameAsTarget(f: Frac): boolean {
    return f.n === this.diffTotal * f.d;
  }

  // ────────────────────────── 生命周期 / 计时 ──────────────────────────

  private reset(): void {
    this.stopTimer();
    let picked: Frac[] = [];
    let answer: string = '';
    let tries: number = 0;
    while (tries < 400 && answer === '') {
      tries++;
      const nums: number[] = [];
      for (let i = 0; i < COUNT; i++) {
        nums.push(MIN_V + Math.floor(Math.random() * (MAX_V - MIN_V + 1)));
      }
      const cand: Frac[] = nums.map((v: number) => this.mk(v, 1, String(v)));
      const hit: Frac | null = this.solve(cand);
      if (hit !== null) {
        picked = cand;
        answer = this.pretty(hit.text);
      }
    }

    this.items = picked;
    const nums2: number[] = [];
    for (let i = 0; i < picked.length; i++) {
      nums2.push(picked[i].n);
    }
    if (nums2.length === 0) {          // 兜底：极端情况下也要给出一副有解的牌
      nums2.push(3);
      nums2.push(3);
      nums2.push(8);
      nums2.push(8);
      const fb: Frac[] = nums2.map((v: number) => this.mk(v, 1, String(v)));
      this.items = fb;
    }
    this.origin = nums2;
    this.selA = -1;
    this.selB = -1;
    this.hist = [];
    this.undoDepth = 0;
    this.merges = 0;
    this.hints = 0;
    this.seconds = 0;
    this.done = false;
    this.finished = false;
    this.status = TG('先点一个数');
    this.tip = '';
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.done && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  // ────────────────────────── 玩法 ──────────────────────────

  private ready(): boolean {
    return this.selA >= 0 && this.selB >= 0;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 用文件里现成的穷举求解器 solve()：只挑「合并之后仍然有解」的那一步
  /** 返回 i * 10000 + j * 100 + op，-1 = 这局面已经走不通了 */
  private aiPick(): number {
    for (let i = 0; i < this.items.length; i++) {
      for (let j = 0; j < this.items.length; j++) {
        if (i === j) {
          continue;
        }
        for (let op = 0; op < 4; op++) {
          const res: Frac | null = this.applyOp(this.items[i], this.items[j], op);
          if (res === null) {
            continue;
          }
          const rest: Frac[] = [];
          for (let k = 0; k < this.items.length; k++) {
            if (k !== i && k !== j) {
              rest.push(this.items[k]);
            }
          }
          rest.push(res);
          if (this.solve(rest) !== null) {
            return i * 10000 + (j * 100) + op;
          }
        }
      }
    }
    return -1;
  }

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
    if (this.done || this.finished) {
      return false;
    }
    const m: number = this.aiPick();
    if (m < 0) {
      return false;
    }
    this.selA = -1;
    this.selB = -1;
    this.tapTile(Math.floor(m / 10000));
    this.tapTile(Math.floor((m % 10000) / 100));
    this.tapOp(m % 100);
    return !this.done;
  }

  /** 提示：报把哪两个数用什么符号合并（走的是求解器验过的那一步） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.done || this.finished) {
      return Hint.none('none');
    }
    const m: number = this.aiPick();
    if (m < 0) {
      return Hint.none('none');
    }
    const i: number = Math.floor(m / 10000);
    const j: number = Math.floor((m % 10000) / 100);
    const op: number = m % 100;
    const a: Frac = this.items[i];
    const b: Frac = this.items[j];
    return Hint.make([], TG2('把 {0} 和 {1} 用 {2} 合并', this.fracText(a), this.fracText(b), OP_KEYS[op]),
      TG2('Merge {0} and {1} with {2}', this.fracText(a), this.fracText(b), OP_KEYS[op]), t0);
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

  private tapTile(i: number): void {
    if (this.done || this.finished) {
      return;
    }
    if (this.selA < 0) {
      this.selA = i;
      this.status = TG('再点一个数');
      return;
    }
    if (this.selA === i) {
      this.selA = -1;
      this.selB = -1;
      this.status = TG('先点一个数');
      return;
    }
    this.selB = i;
    this.status = TG('选一个运算符，合并这两个数');
  }

  private tapOp(op: number): void {
    if (this.done || this.finished) {
      return;
    }
    if (!this.ready()) {
      this.status = TG('先点两个数，再点运算符');
      return;
    }
    const a: Frac = this.items[this.selA];
    const b: Frac = this.items[this.selB];
    const res: Frac | null = this.applyOp(a, b, op);
    if (res === null) {
      this.status = TG('不能除以 0 哦');
      return;
    }

    this.hist.push(this.items.slice());     // 记一步，可撤销
    this.undoDepth = this.hist.length;

    const next: Frac[] = [];
    for (let k = 0; k < this.items.length; k++) {
      if (k !== this.selA && k !== this.selB) {
        next.push(this.items[k]);
      }
    }
    next.push(res);
    this.items = next;
    this.selA = -1;
    this.selB = -1;
    this.merges = this.merges + 1;

    if (next.length === 1) {
      if (this.sameAsTarget(next[0])) {
        this.done = true;
        this.status = TG2("🎉 凑出 24！用了 {0} 步",Digits(String(this.merges), this.langCode));
        this.finish(true);
      } else {
        this.status = TG('只剩一个数了，不是 24 —— 撤销试试');
      }
    } else {
      this.status = TG2('还剩 {0} 个数，继续合并', next.length);
    }
  }

  private undo(): void {
    if (this.hist.length === 0 || this.done || this.finished) {
      return;
    }
    const prev: Frac[] | undefined = this.hist.pop();
    if (prev !== undefined) {
      this.items = prev;
      this.merges = this.merges > 0 ? this.merges - 1 : 0;
    }
    this.undoDepth = this.hist.length;
    this.selA = -1;
    this.selB = -1;
    this.status = TG('已撤销一步');
  }

  private hint(): void {
    if (this.done || this.finished) {
      return;
    }
    const hit: Frac | null = this.solve(this.items.slice());
    if (hit === null) {
      this.status = TG('这个局面走不通了 —— 撤销或换一题');
      this.tip = '';
      return;
    }
    this.hints = this.hints + 1;
    this.tip = TG2('提示：{0} = 24', this.pretty(hit.text));
    this.status = TG2('这是当前局面的一种走法（用了 {0} 次提示）',Digits(String(this.hints), this.langCode));
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const usedMs: number = Date.now() - this.startAt;
    const usedSec: number = Math.floor(usedMs / TICK_MS);
    const r: GameResult = {
      gameId: 'game24',
      solved: solved,
      score: solved ? Math.max(100, 900 - usedSec * 4 - this.hints * 120) : 0,
      durationMs: usedMs,
      levelReached: this.merges
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ────────────────────────── 渲染 ──────────────────────────

  private originText(): string {
    let s: string = '';
    for (let i = 0; i < this.origin.length; i++) {
      s = i === 0 ? String(this.origin[i]) : s + ' · ' + this.origin[i];
    }
    return s;
  }

  private tileBg(i: number): string {
    if (i === this.selA) {
      return Palette.primary;
    }
    if (i === this.selB) {
      return Palette.amber;
    }
    return this.theme.surface;
  }

  private tileInk(i: number): string {
    if (i === this.selA || i === this.selB) {
      return '#FFFFFF';   // 返回类型是 string，不能用 Color.White（Color 类型）
    }
    return this.theme.ink;
  }

  build() {
    Column({ space: Space.lg }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      // 数牌
      Row({ space: Space.md }) {
        ForEach(this.items, (it: Frac, i: number) => {
          this.tileView(i)
        }, (it: Frac, i: number) => 't' + i + '#' + it.text)
      }
      .width('100%')
      .height(TILE)
      .justifyContent(FlexAlign.Center)

      // 运算符
      Row({ space: Space.md }) {
        ForEach(OP_KEYS, (k: string, op: number) => {
          Button(k)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(Palette.violet)
            .borderRadius(Radius.md)
            .layoutWeight(1)
            .height(Cell.of(56))
            .opacity(this.ready() ? 1 : 0.45)
            .onClick(() => {
              Haptics.tap();
              this.tapOp(op);
            })
        }, (k: string) => 'op' + k)
      }
      .width('100%')

      Text(this.status)
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)
        .width('100%')

      if (this.tip !== '') {
        Text(this.tip)
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .width('100%')
          .padding(Space.sm)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
      }

      Row({ space: Space.md }) {
        Button(TG('撤销'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .opacity(this.undoDepth > 0 && !this.done ? 1 : 0.45)
          .onClick(() => {
            Haptics.tap();
            this.undo();
          })
        Button(TG('提示'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.hint();
          })
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('规则：点两个数 → 点运算符合并；四个数用完、凑出 24 就通关'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=本题 1=步数 2=用时（值在 Builder 内部读状态，保证刷新） */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '本题' : (kind === 1 ? TG('步数') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.originText()
        : (kind === 1 ? String(this.merges) : this.seconds + 's'))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  tileView(i: number) {
    Stack() {
      Text(this.fracText(this.fracAt(i)))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tileInk(i))
    }
    .width(TILE)
    .height(TILE)
    .backgroundColor(this.tileBg(i))
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .scale({
      x: (i === this.selA || i === this.selB) ? 1.06 : 1,
      y: (i === this.selA || i === this.selB) ? 1.06 : 1
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.tapTile(i);
    })
  }
}
