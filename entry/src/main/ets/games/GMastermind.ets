/**
 * 珠玑妙算（Mastermind）—— 猜颜色组合 🎨
 *
 * 规则：4 个位置、6 种颜色（可重复）。每次提交后给反馈：
 *      ● 位置和颜色都对，○ 颜色对但位置不对。
 * 胜负：10 次之内猜中 = 通关；10 次用完还没中 = 失败
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const SLOTS: number = 4;
const COLORS: number = 6;
const MAX_TRIES: number = 10;

const HUES: string[] = [
  Palette.danger, Palette.amber, Palette.emerald,
  Palette.sky, Palette.violet, Palette.berry
];

interface GuessRow {
  guess: number[];
  exact: number;
  partial: number;
}

interface Fb {
  exact: number;
  partial: number;
}

@Component
export struct GMastermind {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 SLOTS=4，按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(4);
  onFinish: (r: GameResult) => void = () => {};

  @State private secret: number[] = [];
  @State private cur: number[] = [];
  @State private rows: GuessRow[] = [];
  @State private sel: number = 0;
  @State private tries: number = 0;
  @State private best: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  private reset(): void {
    const s: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      s.push(Math.floor(Math.random() * COLORS));
    }
    this.secret = s;
    this.cur = [-1, -1, -1, -1];
    this.rows = [];
    this.sel = 0;
    this.tries = 0;
    this.best = 0;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
  }

  private feedback(g: number[]): Fb {
    let exact: number = 0;
    for (let i = 0; i < this.diffTotal; i++) {
      if (g[i] === this.secret[i]) {
        exact++;
      }
    }
    let partial: number = 0;
    for (let c = 0; c < COLORS; c++) {
      let inG: number = 0;
      let inS: number = 0;
      for (let i = 0; i < this.diffTotal; i++) {
        if (g[i] === c) {
          inG++;
        }
        if (this.secret[i] === c) {
          inS++;
        }
      }
      partial += Math.min(inG, inS);
    }
    const out: Fb = { exact: exact, partial: partial - exact };
    return out;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    let i: number = -1;
    for (let k = 0; k < this.diffTotal; k++) {
      if (this.cur[k] < 0) {
        i = k;
        break;
      }
    }
    if (i < 0) {
      this.submit();
      return !this.over;
    }
    this.sel = this.secret[i];
    this.tapSlot(i);
    return true;
  }

  /** 提示：答案就在 this.secret 里 —— 直接报颜色序列 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const names: string[] = ['红', '黄', '绿', '蓝', '紫', '莓'];
    let s: string = '';
    for (let i = 0; i < this.secret.length; i++) {
      if (i > 0) {
        s = s + ' · ';
      }
      s = s + names[this.secret[i]];
    }
    return Hint.make([],
      TG2('答案是「{0}」（从左到右）', s),
      TG2('The code is {0} (left to right)', s), t0);
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

  private tapSlot(i: number): void {
    if (this.over || this.sel < 0) {
      return;
    }
    const n: number[] = this.cur.slice();
    n[i] = this.sel;
    this.cur = n;
  }

  private clearCur(): void {
    if (this.over) {
      return;
    }
    this.cur = [-1, -1, -1, -1];
  }

  private submit(): void {
    if (this.over) {
      return;
    }
    for (let i = 0; i < this.diffTotal; i++) {
      if (this.cur[i] < 0) {
        return;
      }
    }
    const fb: Fb = this.feedback(this.cur);
    const row: GuessRow = { guess: this.cur.slice(), exact: fb.exact, partial: fb.partial };
    const nr: GuessRow[] = this.rows.slice();
    nr.push(row);
    this.rows = nr;
    this.tries = this.tries + 1;
    if (fb.exact > this.best) {
      this.best = fb.exact;
    }
    this.cur = [-1, -1, -1, -1];
    if (fb.exact === this.diffTotal) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.tries >= MAX_TRIES) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mastermind',
      solved: solved,
      score: solved ? 1000 + (MAX_TRIES - this.tries) * 100 : this.best * 120,
      durationMs: Date.now() - this.startAt,
      levelReached: solved ? this.tries : this.best
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('第几次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.tries) + '/' + String(MAX_TRIES))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最佳命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.best) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      // 答案（结束后揭晓）
      Row({ space: Space.sm }) {
        Text(TG('答案')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        ForEach([0, 1, 2, 3], (i: number) => {
          Row()
            .layoutWeight(1)
            .aspectRatio(1)
            .backgroundColor(this.over && this.secret.length > i ? HUES[this.secret[i]] : this.theme.surfaceAlt)
            .borderRadius(Radius.full)
            .border({ width: 1, color: this.theme.line })
        }, (i: number) => 'sec' + i)
      }
      .width('100%')

      // 调色盘
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
          Row()
            .layoutWeight(1)
            .aspectRatio(1)
            .backgroundColor(HUES[c])
            .borderRadius(Radius.full)
            .border({ width: this.sel === c ? 3 : 1, color: this.sel === c ? this.theme.ink : this.theme.line })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => {
              Haptics.tick();
              this.sel = c;
            })
        }, (c: number) => 'hue' + c)
      }
      .width('100%')

      // 这一行猜的
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Row()
            .layoutWeight(1)
            .aspectRatio(1)
            .backgroundColor(this.cur.length > i && this.cur[i] >= 0 ? HUES[this.cur[i]] : this.theme.surface)
            .borderRadius(Radius.full)
            .border({ width: 1, color: this.theme.line })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => {
              Haptics.tick();
              this.tapSlot(i);
            })
        }, (i: number) => 'cur' + i)
      }
      .width('100%')
      .padding(Space.xs)

      Row({ space: Space.md }) {
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.cyan).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.submit();
          })
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .width(80).height(Cell.of(44))
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.clearCur();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .width(80).height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: Space.xs }) {
          ForEach(this.rows, (r: GuessRow, i: number) => {
            Row({ space: Space.sm }) {
              Text(String(i + 1)).fontSize(FontSize.xs).fontColor(this.theme.inkFaint).width(20)
              ForEach([0, 1, 2, 3], (k: number) => {
                Row()
                  .width(22).height(22)
                  .backgroundColor(HUES[r.guess[k]])
                  .borderRadius(Radius.full)
              }, (k: number) => 'g' + i + '-' + k)
              Text('● ' + String(r.exact) + '   ○ ' + String(r.partial))
                .fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
            }
            .width('100%')
            .padding(Space.xs)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
          }, (r: GuessRow, i: number) => 'row' + i)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Text(this.over ? (this.won ? '🎉 猜中！' : '没猜中，答案是上面那四个颜色') :
        '先点调色盘选颜色，再点上面的圈放进去')
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
    }
    .width('100%')
    .height('100%')
  }


}
