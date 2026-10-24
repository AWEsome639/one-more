/**
 * 数方块 —— 3×3 底座上叠着高度不等的方块塔，数出一共多少块（每格高度相加）
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const SIDE: number = 3; const CELLS: number = SIDE * SIDE; const MAXH: number = 3;
const TOTAL: number = 8; const PASS: number = 6; const NEXT_MS: number = 880; const LETTERS: string[] = ['A', 'B', 'C', 'D'];
@Component
export struct GBlockCount3d {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State h: number[] = []; @State opts: number[] = []; @State ansIdx: number = 0;
  @State picked: number = -1; @State round: number = 1; @State rightN: number = 0;
  @State score: number = 0; @State over: boolean = false; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private nextTo: number = -1;
  private rowIdx: number[] = [0, 1, 2]; private colIdx: number[] = [0, 1, 2]; private optIdx: number[] = [0, 1, 2, 3];
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    this.clearNext(); this.round = 1; this.rightN = 0; this.score = 0; this.over = false;
    this.won = false; this.finished = false; this.startAt = Date.now(); this.ask();
  }
  private shuffle(a: number[]): number[] {
    for (let i = a.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }
  private ask(): void {
    const h: number[] = []; let total: number = 0;
    for (let i = 0; i < CELLS; i++) {
      const v: number = Math.floor(Math.random() * (MAXH + 1));
      h.push(v); total = total + v;
    }
    while (total < 6) {                        // 太矮就加高，保证有得数
      for (let i = 0; i < CELLS && total < 6; i++) { if (h[i] < MAXH) { h[i] = h[i] + 1; total = total + 1; } }
    }
    const pool: number[] = [];
    const cand: number[] = [total + 1, total + 2, total - 1, total - 2, total + 3];
    for (let i = 0; i < cand.length; i++) { if (cand[i] > 0 && pool.indexOf(cand[i]) < 0) { pool.push(cand[i]); } }
    this.shuffle(pool);
    const opts: number[] = this.shuffle([total, pool[0], pool[1], pool[2]]);
    this.h = h; this.opts = opts; this.ansIdx = opts.indexOf(total); this.picked = -1;
    this.msg = TG('这堆方块一共有多少块？');
  }
  private total(): number {
    let t: number = 0;
    for (let i = 0; i < this.h.length; i++) { t = t + this.h[i]; }
    return t;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ansIdx）+ 有"已答"守卫
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ansIdx);
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

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i;
    const t: number = this.total();
    if (i === this.ansIdx) { this.rightN = this.rightN + 1; this.score = this.score + 140; this.msg = '✅ 一共 ' + t + TG(' 块'); }
    else { this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 一共 {0} 块 —— 每格的高度加起来就是它', t); }
    this.clearNext();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round < this.diffTotal) { this.round = this.round + 1; this.ask(); return; }
    this.over = true; this.won = this.rightN >= PASS;
    this.msg = this.won ? TG2("🎉 答对 {0}/{1}，通关！",Digits(String(this.rightN), this.langCode),Digits(String(this.diffTotal), this.langCode)) : TG2("😵 只答对 {0}/{1}，差 {2} 题", this.rightN, this.diffTotal, (PASS - this.rightN));
    this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'block_count_3d', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rightN };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.rightN + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.colIdx, (c: number) => {
              Column() {
              if (this.h[(r * SIDE + c)] > 2) {
              Text('🧊').accessibilityLevel('no').fontSize(FontSize.lg)
              }
              if (this.h[(r * SIDE + c)] > 1) {
              Text('🧊').accessibilityLevel('no').fontSize(FontSize.lg)
              }
              if (this.h[(r * SIDE + c)] > 0) {
              Text('🧊').accessibilityLevel('no').fontSize(FontSize.lg)
              }
              }
              .layoutWeight(1).height(112).justifyContent(FlexAlign.End).padding(Space.xs)
              .backgroundColor(this.theme.surface).borderRadius(Radius.xs)
            }, (c: number) => 'bc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'br' + r)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Row({ space: Space.sm }) {
        ForEach(this.optIdx, (i: number) => {
          Text(LETTERS[(i)] + '. ' + this.opts[(i)]).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.picked >= 0 && ((i) === this.ansIdx || (i) === this.picked) ? '#FFFFFF' : this.theme.ink)
          .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(56))
          .backgroundColor(this.picked < 0 ? this.theme.surface
          : ((i) === this.ansIdx ? Palette.emerald : ((i) === this.picked ? Palette.rose : this.theme.surface)))
          .borderRadius(Radius.md).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick((i)); })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        }, (i: number) => 'o' + i)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：每格从下往上数高度，全部加起来才是总块数；空格是 0'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
