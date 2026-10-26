/**
 * 观点采择 📐
 * 规则：房间里站着一位观察者（箭头 = 他面朝的方向）；按他看到的方位，选出对应的物品。
 * 胜负：8 题答对 ≥6 ⇒ 通关；否则失败。　进度：第几题 / 已答对
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5; const TOTAL: number = 8; const NEED: number = 6;
const IDXN: number[] = [0, 1, 2, 3, 4];
const LETTERS: string[] = ['A', 'B', 'C'];
/** 房间里那 3 件物品，A/B/C 与之一一对应 */
const EMO: string[] = ['🍎', '🏀', '📚'];
const FACING: string[] = ['⬆️', '➡️', '⬇️', '⬅️'];
const ASK: string[] = [TG('左手边'), TG('右手边'), TG('正前方'), TG('身后')];
/** 前向量 / 右向量，下标 = 面朝方向（0 北 1 东 2 南 3 西） */
const FX: number[] = [-1, 0, 1, 0]; const FY: number[] = [0, 1, 0, -1];
const RX: number[] = [0, 1, 0, -1]; const RY: number[] = [1, 0, -1, 0];

/**
 * t：0 左 1 右 2 前 3 后 —— 判断某格物品落在观察者的哪个方位
 *
 * ★ 2026-10-23：加 n 参数。
 *   棋盘是按 diffTotal 生成和渲染的（4/5/6），
 *   但这里原来用模块常量 N=5 把 cell 换成坐标
 *   ⇒ 4×4 与 6×6 时几乎每一格都算成别的方位。
 *   调用处本来就传的是 diffTotal 算出来的 or/oc，两边对齐即可。
 */
function rel(or: number, oc: number, cell: number, face: number, t: number, n: number): boolean {
  const dr: number = Math.floor(cell / n) - or; const dc: number = cell % n - oc;
  if (t === 2) { return dr * FX[face] + dc * FY[face] > 0; }
  if (t === 3) { return dr * FX[face] + dc * FY[face] < 0; }
  if (t === 1) { return dr * RX[face] + dc * RY[face] > 0; }
  return dr * RX[face] + dc * RY[face] < 0;
}

@Component
export struct GPerspectiveTaking {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  //   ⚠️ 原本 ForEach(IDXN, …) 是常量数组，已改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(5);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private obs: number = 12; @State private face: number = 0;
  @State private items: number[] = [];
  @State private ask: number = 0; @State private answer: number = 0;
  @State private q: number = 1; @State private correct: number = 0; @State private chosen: number = -1;
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private over: boolean = false; @State private won: boolean = false; @State private msg: string = '';
  private startAt: number = 0; private delay: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { this.halt(); }
  private halt(): void {
    if (this.delay >= 0) { clearTimeout(this.delay); this.delay = -1; }
  }
  private reset(): void {
    this.halt(); this.q = 1; this.correct = 0; this.chosen = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.question();
    this.msg = TG(TG(TG('箭头是他面朝的方向，按他的视角来选')));
  }
  /** 随机摆人 + 3 件物品，再挑一个「恰好只有一件」的方位来问 */
  private question(): void {
    let ok: boolean = false; let guard: number = 0;
    let spot: number = 12; let way: number = 0; let cells: number[] = [];
    let ask: number = 2; let ans: number = 0;
    while (!ok && guard < 100) {
      guard = guard + 1;
      spot = Math.floor(Math.random() * this.diffTotal * this.diffTotal);
      way = Math.floor(Math.random() * 4);
      const free: number[] = [];
      for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { if (i !== spot) { free.push(i); } }
      cells = [];
      for (let k = 0; k < 3; k++) {
        const j: number = Math.floor(Math.random() * free.length);
        cells.push(free[j]); free.splice(j, 1);
      }
      const types: number[] = []; const who: number[] = [-1, -1, -1, -1];
      for (let t = 0; t < 4; t++) {
        let cnt: number = 0;
        for (let k = 0; k < 3; k++) {
          if (rel(Math.floor(spot / this.diffTotal), spot % this.diffTotal, cells[k], way, t, this.diffTotal)) { cnt = cnt + 1; who[t] = k; }
        }
        if (cnt === 1) { types.push(t); }
      }
      if (types.length > 0) {
        ask = types[Math.floor(Math.random() * types.length)]; ans = who[ask]; ok = true;
      }
    }
    if (!ok) { spot = 12; way = 0; cells = [2, 14, 22]; ask = 2; ans = 0; }
    this.obs = spot; this.face = way; this.items = cells; this.ask = ask; this.answer = ans;
  }
  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.answer],
      TG2('答案是第 {0} 个', String(this.answer + 1)),
      TG2('The answer is option {0}', String(this.answer + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    // ★ 关键：choose() 答完会等 1000ms 才 next()。
    //   如果这里每拍都重置 chosen 再作答，1 秒内会被调用 3 次
    //   ⇒ 每题多加几次 correct、排多个 next() ⇒ 题目被跳过、计数错乱。
    //   ⇒ 答过的这一轮什么都不做，只等 next()。
    if (this.chosen >= 0) {
      return true;
    }
    this.choose(this.answer);
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

  private choose(k: number): void {
    if (this.over || this.chosen >= 0) { return; }
    this.chosen = k;
    if (k === this.answer) { this.correct = this.correct + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); }
    this.msg = k === this.answer ? '✅ 他看到的正是这一件' : '❌ 正确答案已标绿';
    this.halt();
    this.delay = setTimeout(() => { this.delay = -1; this.next(); }, 1000);
  }
  private next(): void {
    if (this.q >= TOTAL) { this.finish(); return; }
    this.q = this.q + 1; this.chosen = -1;
    this.question();
    this.msg = TG2("继续：第 {0} 题", String(this.q));
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.halt();
    const solved: boolean = this.correct >= NEED;
    const raw: number = this.correct * 60 - (TOTAL - this.correct) * 20;
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 视角全对！' : TG2("本局答对 {0}/{1} 题",Digits(String(this.correct), this.langCode), String(TOTAL));
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'perspective_taking', solved: solved, score: raw > 0 ? raw : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.correct
    });
  }
  private mark(i: number): string {
    if (i === this.obs) { return FACING[this.face]; }
    const k: number = this.items.indexOf(i);
    return k < 0 ? '' : EMO[k];
  }
  private optBorder(k: number): string {
    if (this.chosen < 0) { return this.theme.line; }
    if (k === this.answer) { return Palette.emerald; }
    if (k === this.chosen) { return Palette.rose; }
    return this.theme.line;
  }
  build() {
    Column({ space: Space.md }) {
      Text(TG('第 ') + String(this.q) + '/' + String(TOTAL) + ' 题 · 答对 ' + String(this.correct)
        + ' · 需要 ' + String(NEED) + TG(' 题'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
          ForEach(this.rowIdx(), (r: number) => {
            Row({ space: 2 }) {
              ForEach(this.rowIdx(), (c: number) => { Stack() {
              Text(this.mark((r * this.diffTotal + c))).fontSize(FontSize.lg).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor((r * this.diffTotal + c) === this.obs ? Palette.emerald : this.theme.surfaceAlt)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() }) }, (c: number) => 'c' + c)
            }.width('100%')
          }, (r: number) => 'r' + r)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(TG('他在哪')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(TG2('面朝 {0}', FACING[this.face])).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
            .fontColor(Palette.emerald)
          Text(ASK[this.ask] + '的是哪一件？').fontSize(FontSize.md).fontColor(this.theme.ink)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: Space.sm }) {
        ForEach(this.rowIdx(), (k: number) => { Column({ space: 2 }) {
        Text(EMO[(k)]).fontSize(FontSize.xxl)
        Text(LETTERS[(k)]).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(2).borderColor(this.optBorder((k)))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.choose((k)); }) }, (k: number) => 'opt' + k)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
