/**
 * 立方体展开 📐 —— 六个面两两成对，展开图上只有同字母才能折到同一个棱边
 * 玩法：点格子选面（A/B/C 循环），把配对的字母放进正确的格；全部正确即通关
 * 胜负：6 关过 ≥4 关通关　进度：关号 / 过关数 / 错放次数
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

const TOTAL: number = 6;
const PASS: number = 4;
const SLOTS: number = 6;
const PICK: string[] = ['A', 'B', 'C'];

/** 六个面在展开图上的位置：3 列 × 4 行，-1 = 不占格 */
const LAYOUT: number[] = [1, 2, 3, -1, 4, 5, -1, 6, -1, -1, -1, -1];
const LETTERS: string[] = ['A', 'B', 'C', 'A', 'B', 'C'];

function shuffleLetters(): string[] {
  const out: string[] = LETTERS.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GCubeNetFold {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private slots: string[] = [];       // 每格当前填的字母，'' = 空
  @State private answer: string[] = [];      // 正确答案
  @State private round: number = 0;
  @State private wins: number = 0;
  @State private wrong: number = 0;
  @State private note: string = '';
  @State private over: boolean = false;
  private startAt: number = 0;
  private locked: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  private reset(): void {
    this.round = 0; this.wins = 0; this.wrong = 0; this.over = false;
    this.load(); this.startAt = Date.now();
  }

  private load(): void {
    const ans: string[] = shuffleLetters();
    this.answer = ans;
    this.slots = new Array<string>(SLOTS).fill('');
    this.note = TG(TG(TG('点格子循环选 A / B / C —— 只有折到同一棱边的两个面才成对')));
    this.locked = false;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在 this.answer（每格该是 A/B/C）；tap 是循环换字母 ⇒ 一格一格换过去
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.locked) {
      return true;              // 过关过渡里，等下一关加载
    }
    for (let i = 0; i < SLOTS; i++) {
      if (this.slots[i] !== this.answer[i]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
  }

  /** 提示：报「第几格该填哪个字母」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.locked) {
      return Hint.none('none');
    }
    for (let i = 0; i < SLOTS; i++) {
      if (this.slots[i] !== this.answer[i]) {
        return Hint.make([i], TG2('第 {0} 格填 {1}', i + 1, this.answer[i]),
          TG2('Cell {0} should be {1}', i + 1, this.answer[i]), t0);
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
    if (this.locked || this.over) { return; }
    const cur: string = this.slots[i];
    const nextIdx: number = cur.length === 0 ? 0 : (PICK.indexOf(cur) + 1) % PICK.length;
    const next: string[] = this.slots.slice();
    next[i] = PICK[nextIdx];
    this.slots = next;
    for (let k = 0; k < SLOTS; k++) {
      if (next[k].length === 0) { return; }   // 没填完不判
    }
    const same: number = next.join('') === this.answer.join('') ? 1 : 0;
    if (same === 1) {
      this.wins++; this.note = TG(TG(TG('这一关折对了 ✅')));
    } else {
      this.wrong++; this.note = TG(TG(TG('配错了 ❌ —— 上下相邻的面折到同一条棱，左右相邻则不是')));
      this.slots = new Array<string>(SLOTS).fill('');
      return;
    }
    if (this.round + 1 >= this.diffTotal) {
      this.finish(this.wins >= PASS);
      return;
    }
    this.locked = true;
    this.timer = setTimeout(() => { this.round++; this.load(); }, 900);
  }

  private finish(solved: boolean): void {
    this.over = true;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'cube_net_fold', solved: solved,
      score: Math.max(0, this.wins * 120 - this.wrong * 20),
      durationMs: Date.now() - this.startAt, levelReached: this.wins
    });
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); }
  }

  @Builder
  cubeCell(i: number) {
    Stack() {
      Text(this.slots[i].length === 0 ? '·' : this.slots[i])
        .fontSize(this.slots[i].length === 0 ? FontSize.lg : FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.slots[i].length === 0 ? this.theme.inkFaint : '#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(this.slots[i].length === 0 ? this.theme.surface : Palette.sky).animation({ duration: Motion.fast, curve: Motion.snap() })
    .borderRadius(Radius.sm)
    .shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Text(TG2("第 {0}/{1}", Math.min(this.round + 1, this.diffTotal), this.diffTotal)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
        Text(TG2('过关 {0}',Digits(String(this.wins), this.langCode))).fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
        Text(TG2('配错 {0}', this.wrong)).fontSize(FontSize.md).fontColor(Palette.rose).layoutWeight(1)
      }.width('100%')

      Text(TG('📐 展开图 ↔ 立方体：把 6 个面填成 3 对，配对正确的字母才算折得起来'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
                if (LAYOUT[r * 3 + c] > 0) {
                  this.cubeCell(LAYOUT[r * 3 + c] - 1)
                }
              }
              .layoutWeight(1).aspectRatio(1)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        ForEach([0, 1, 2], (i: number) => {
          Text(TG2('可填 {0}', PICK[i])).fontSize(FontSize.sm).fontColor(this.theme.ink).textAlign(TextAlign.Center)
            .layoutWeight(1).height(Cell.of(34)).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm)
        }, (i: number) => 'k' + i)
      }.width('100%')

      Button(this.over ? (this.wins >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
