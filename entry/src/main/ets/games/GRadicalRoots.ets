/** 根式化简 —— √n 化成 a√b｜8 题答对 6 题过关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TOTAL: number = 8;
const PASS: number = 6;
const A_POOL: number[] = [2, 3, 4, 5, 6, 7, 8, 9];
const B_POOL: number[] = [2, 3, 5, 6, 7, 10, 11, 13, 14, 15];

interface Rad { text: string; value: number }
interface RadQ { q: string; ans: string; opts: string[] }

function makeQ(): RadQ {
  const a: number = A_POOL[Math.floor(Math.random() * A_POOL.length)];
  const b: number = B_POOL[Math.floor(Math.random() * B_POOL.length)];
  const value: number = a * a * b;
  const ans: string = String(a) + '√' + String(b);
  const cands: Rad[] = [
    { text: String(a) + '√' + String(b + 1), value: a * a * (b + 1) },
    { text: String(a + 1) + '√' + String(b), value: (a + 1) * (a + 1) * b },
    { text: String(b) + '√' + String(a), value: b * b * a },
    { text: String(a + 2) + '√' + String(b), value: (a + 2) * (a + 2) * b },
    { text: String(a) + '√' + String(b + 2), value: a * a * (b + 2) }
  ];
  if (a > 2) { cands.push({ text: String(a - 1) + '√' + String(b + 3), value: (a - 1) * (a - 1) * (b + 3) }); }
  const opts: string[] = [ans];
  const vals: number[] = [value];
  for (let i = 0; i < cands.length && opts.length < 4; i++) {
    const cd: Rad = cands[i];
    if (cd.value !== value && vals.indexOf(cd.value) < 0 && opts.indexOf(cd.text) < 0) {
      opts.push(cd.text);
      vals.push(cd.value);
    }
  }
  for (let i = opts.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = opts[i];
    opts[i] = opts[j];
    opts[j] = t;
  }
  return { q: '√' + String(value), ans: ans, opts: opts };
}

@Component
export struct GRadicalRoots {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private q: string = '';
  @State private ans: string = '';
  @State private opts: string[] = [];
  @State private picked: string = '';
  @State private idx: number = 0;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('化成最简根式：根号里不能再有平方因子');
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
  aboutToDisappear(): void { if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; } }

  private reset(): void {
    this.startAt = Date.now();
    this.idx = 0;
    this.right = 0;
    this.wrong = 0;
    this.score = 0;
    this.over = false;
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
    this.ask();
  }

  private ask(): void {
    const item: RadQ = makeQ();
    this.q = item.q;
    this.ans = item.ans;
    this.opts = item.opts;
    this.picked = '';
    this.tip = TG2("{0} 化成 a√b", item.q);
  }

  private choose(s: string): void {
    if (this.picked.length > 0 || this.over) { return; }
    this.picked = s;
    if (s === this.ans) {
      this.right++;
      this.score += 12;
      this.tip = '✓ ' + this.q + ' = ' + this.ans;
    } else {
      this.wrong++;
      this.score -= 2;
      this.tip = '✗ ' + this.q + ' = ' + this.ans;
    }
    this.wait = setTimeout(() => { this.next(); }, 850);
  }

  private next(): void {
    this.wait = -1;
    this.idx++;
    if (this.idx >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'radical_roots', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.ask();
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.q).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG('= ?（最简根式）')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        ForEach([0, 1], (i: number) => { Button(this.opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked.length === 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'a' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach([2, 3], (i: number) => { Button(this.opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked.length === 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'b' + i)
      }.width('100%')
      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.amber)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('把 n 拆成 平方数 × 无平方因子数')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }





  private optTone(i: number): string {
    const s: string = this.opts[i];
    if (this.picked.length === 0) { return Palette.amber; }
    if (s === this.ans) { return Palette.emerald; }
    if (s === this.picked) { return Palette.danger; }
    return this.theme.surfaceAlt;
  }

  private optInk(i: number): string {
    const s: string = this.opts[i];
    if (this.picked.length === 0 || s === this.ans || s === this.picked) { return '#FFFFFF'; }
    return this.theme.ink;
  }
}
