/**
 * d2 注意 —— 划消测验：限时点出所有「带正好两个小撇的 d」
 * 胜负：30 秒内找齐 6 个目标通关，时间到判负　｜　进度：剩余 / 命中 / 点错
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

const COLS: number = 8;
const CELLS: number = 32;
const TARGETS: number = 6;
const TIME_LIMIT: number = 30;
const HIT_SCORE: number = 100;
const MISS_PENALTY: number = 40;

function markStr(n: number): string {
  if (n <= 0) { return ' '; }
  return n === 1 ? '·' : '··';
}

@Component
export struct GD2Attention {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：TIME_LIMIT 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(TIME_LIMIT);
  onFinish: (r: GameResult) => void = () => {};

  @State letters: string[] = [];
  @State marks: number[] = [];
  @State isTarget: boolean[] = [];
  @State picked: boolean[] = [];
  @State hits: number = 0;
  @State wrongTap: number = 0;
  @State timeLeft: number = this.diffTotal;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(TIME_LIMIT);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }

  private stopTimer(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }

  /** 造字阵：6 个「d + 2 撇」为目标，其余是带 1/3/4 撇的 d 或任意撇数的 p */
  private reset(): void {
    this.stopTimer();
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { pool.push(i); }
    for (let k = pool.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const tmp: number = pool[k];
      pool[k] = pool[j];
      pool[j] = tmp;
    }
    const tset: number[] = [];
    for (let i = 0; i < TARGETS; i++) { tset.push(pool[i]); }
    const ls: string[] = [];
    const ms: number[] = [];
    const ts: boolean[] = [];
    const ps: boolean[] = [];
    const opts: number[] = [1, 3, 4];
    for (let i = 0; i < CELLS; i++) {
      const isT: boolean = tset.indexOf(i) >= 0;
      if (isT) {
        ls.push('d');
        ms.push(2);
      } else {
        ls.push(Math.random() < 0.5 ? 'd' : 'p');
        ms.push(opts[Math.floor(Math.random() * opts.length)]);
      }
      ts.push(isT);
      ps.push(false);
    }
    this.letters = ls; this.marks = ms; this.isTarget = ts; this.picked = ps;
    this.hits = 0; this.wrongTap = 0; this.timeLeft = this.diffTotal;
    this.over = false; this.won = false; this.finished = false;
    this.msg = TG('点出「d + 正好两个小撇」');
    this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, 1000);
  }

  private tick(): void {
    if (this.over) { return; }
    this.timeLeft--;
    if (this.timeLeft <= 0) { this.end(false); }
  }

  /** 提示：和代打同一个循环，只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.isTarget.length; i++) {
      if (this.isTarget[i] && !this.picked[i]) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 变体⑦：真值数组 isTarget + picked 守卫 ⇒ 直接点"是目标且还没点过"的
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    for (let i = 0; i < this.isTarget.length; i++) {
      if (this.isTarget[i] && !this.picked[i]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private tap(i: number): void {
    if (this.over || this.picked[i]) { return; }
    const next: boolean[] = this.picked.slice();
    next[i] = true;
    this.picked = next;
    if (this.isTarget[i]) {
      this.hits++;
      this.msg = TG2('✅ 命中 {0} / {1}',Digits(String(this.hits), this.langCode),Digits(String(TARGETS), this.langCode));
      if (this.hits >= TARGETS) { this.end(true); }
      return;
    }
    this.wrongTap++;
    this.msg = TG('❌ 那不是目标（要 d + 正好 2 撇）');
  }

  private end(solved: boolean): void {
    this.stopTimer();
    this.over = true;
    this.won = solved;
    this.msg = solved ? '🎉 全找到了！用时 ' + (this.diffTotal - this.timeLeft) + TG(' 秒')
      : TG2('时间到：命中 {0} / {1}，点错 {2}',Digits(String(this.hits), this.langCode),Digits(String(TARGETS), this.langCode),Digits(String(this.wrongTap), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'd2_attention', solved: solved,
      score: this.hits * HIT_SCORE - this.wrongTap * MISS_PENALTY,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({

        showHint: true,

        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },

        autoOn: this.autoId >= 0

      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.timeLeft + TG(' 秒'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.teal))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + TARGETS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('点错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrongTap), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (c: number) => {
              Column({ space: 0 }) {
              Text(markStr(Math.min(this.marks[(r * COLS + c)], 2))).fontSize(FontSize.xxs).fontColor(this.theme.inkSoft)
              Text(this.letters[(r * COLS + c)]).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
              .fontColor(this.picked[(r * COLS + c)] ? (this.isTarget[(r * COLS + c)] ? Palette.emerald : Palette.rose) : this.theme.ink)
              Text(markStr(this.marks[(r * COLS + c)] - Math.min(this.marks[(r * COLS + c)], 2)))
              .fontSize(FontSize.xxs).fontColor(this.theme.inkSoft)
              }.layoutWeight(1).height(Cell.of(46)).justifyContent(FlexAlign.Center)
              .backgroundColor(this.picked[(r * COLS + c)] ? this.theme.surfaceAlt : this.theme.surface)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { Haptics.tick(); this.tap((r * COLS + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)


      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2("目标＝字母 d 且上下小撇共 2 个；{0} 秒内找齐 {1} 个",Digits(String(this.diffTotal), this.langCode),Digits(String(TARGETS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
