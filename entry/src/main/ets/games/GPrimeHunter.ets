/** 素数猎手 —— 在 5×5 数字阵里点掉所有素数｜3 关猎到 2 关过关 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SIZE: number = 5;
const ROUNDS: number = 3;
const PASS: number = 2;
const PRIME_POOL: number[] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97];
const MIX_POOL: number[] = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30, 32, 33, 34, 35, 36, 38, 39, 40, 42, 44, 45, 46, 48, 49, 50, 51, 52, 54, 55, 56, 57, 58, 60, 62, 63, 64, 65, 66, 68, 69, 70, 72, 74, 75, 76, 77, 78, 80, 81, 82, 84, 85, 86, 87, 88, 90, 91, 92, 93, 94, 95, 96, 98, 99];

function isPrime(n: number): boolean {
  if (n < 2) { return false; }
  for (let i = 2; i * i <= n; i++) { if (n % i === 0) { return false; } }
  return true;
}

function makeBoard(): number[] {
  const cells: number[] = [];
  const hits: number = 7 + Math.floor(Math.random() * 3);
  for (let i = 0; i < hits; i++) { cells.push(PRIME_POOL[Math.floor(Math.random() * PRIME_POOL.length)]); }
  while (cells.length < SIZE * SIZE) { cells.push(MIX_POOL[Math.floor(Math.random() * MIX_POOL.length)]); }
  for (let i = cells.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = cells[i];
    cells[i] = cells[j];
    cells[j] = t;
  }
  return cells;
}

function countPrime(list: number[]): number {
  let c: number = 0;
  for (let i = 0; i < list.length; i++) { if (isPrime(list[i])) { c++; } }
  return c;
}

@Component
export struct GPrimeHunter {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private nums: number[] = [];
  @State private marks: number[] = [];
  @State private remain: number = 0;
  @State private level: number = 0;
  @State private clears: number = 0;
  @State private miss: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('点掉所有素数');
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.level = 0;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.load();
  }

  private load(): void {
    this.nums = makeBoard();
    this.marks = new Array<number>(SIZE * SIZE).fill(0);
    this.remain = countPrime(this.nums);
    this.miss = 0;
    this.tip = TG2('本关藏着 {0} 个素数，全部点掉',Digits(String(this.remain), this.langCode));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (false) {
      return true;
    }
    this.tap(this.nextPrime());
    return !this.over;
  }

  /** 提示：点掉任意一个还没点过的素数（内容报数字本身） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    for (let i = 0; i < this.nums.length; i++) {
      if (this.marks[i] === 0 && isPrime(this.nums[i])) {
        const v: number = this.nums[i];
        return Hint.make([i],
          TG2('点掉 {0}（它还在阵里）', String(v)),
          'Tap the prime ' + String(v), t0);
      }
    }
    return Hint.none('none');
  }

  /** 辅助：下一个还没点过的素数下标（找不到 = -1，tap(-1) 是空操作） */
  private nextPrime(): number {
    for (let i = 0; i < this.nums.length; i++) {
      if (this.marks[i] === 0 && isPrime(this.nums[i])) { return i; }
    }
    return -1;
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
    if (this.over || this.marks[i] !== 0) { return; }
    const v: number = this.nums[i];
    const m: number[] = this.marks.slice();
    if (isPrime(v)) {
      m[i] = 1;
      this.marks = m;
      this.remain = this.remain - 1;
      this.score += 8;
      if (this.remain === 0) {
        this.clears++;
        this.score += 20;
        this.next(TG2('✓ 第 {0} 关猎净', String(this.level + 1)));
      } else {
        this.tip = TG2("{0} 是素数，还剩 {1} 个", String(v), String(this.remain));
      }
      return;
    }
    m[i] = 2;
    this.marks = m;
    this.miss++;
    this.score -= 2;
    this.tip = TG2("{0} 不是素数", String(v));
    if (this.miss >= 2) { this.next(TG('✗ 误点两个合数，本关收网')); }
  }

  private next(msg: string): void {
    this.level++;
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("{0}｜共猎到 {1}/{2} 关", msg,Digits(String(this.clears), this.langCode),Digits(String(this.diffTotal), this.langCode));
      const res: GameResult = {
        gameId: 'prime_hunter', solved: this.clears >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.clears
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.load();
    this.tip = TG2("{0}，进入第 {1} 关", msg, String(this.level + 1));
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.min(this.level + 1, this.diffTotal)) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余素数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.remain), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('误点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.miss) + '/2')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => { Stack() {
            Text(String(this.nums[(r * SIZE + c)])).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
            .fontColor(this.marks[(r * SIZE + c)] === 0 ? this.theme.ink : '#FFFFFF')
            }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cellTone((r * SIZE + c))).borderRadius(Radius.sm)
            .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * SIZE + c)); }); }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('绿=捞到 红=点错')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }





  private cellTone(i: number): string {
    const m: number = this.marks[i];
    if (m === 1) { return Palette.emerald; }
    if (m === 2) { return Palette.danger; }
    return this.theme.surfaceAlt;
  }
}
