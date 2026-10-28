/** 凑十 —— 选两个数字凑成 10
 *  玩法：4×5 数字格，点两块相加正好是 10 的牌把它们消掉，连击加分
 *  胜负：75 秒内全消 ⇒ 通关；时间到还剩牌 ⇒ 失败 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';
const LIMIT: number = 75; const COLS: number = 4; const ROWS: number = 5; const TOTAL: number = COLS * ROWS;
function shuffle(a: number[]): number[] {
  const out: number[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
/** 10 对 (a, 10-a)，保证一定能全消 */
function makeTiles(): number[] {
  const deck: number[] = [];
  for (let i = 0; i < TOTAL / 2; i++) {
    const a: number = 1 + Math.floor(Math.random() * 9); deck.push(a); deck.push(10 - a);
  }
  return shuffle(deck);
}
@Component
export struct GTarget10 {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private tiles: number[] = []; @State private sel: number = -1; @State private cleared: number = 0;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  /** ★ 2026-10-15 得分跳动 */
  @State private clearedPulse: number = 1;
  @State private score: number = 0; @State private combo: number = 0; @State private best: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0; @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0; private tick: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    this.tick = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.beat();
    }, 1000);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; } }
  private reset(): void {
    this.startAt = Date.now(); this.done = false; this.tiles = makeTiles(); this.sel = -1; this.cleared = 0;
    this.score = 0; this.combo = 0; this.best = 0; this.left = this.total; this.over = false; this.won = false;
    this.msg = TG('点两块相加等于 10 的牌');
  }
  private beat(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) {
      this.left = 0; this.over = true; this.won = false; this.msg = TG2("⏰ 时间到，还剩 {0} 块", String(TOTAL - this.cleared));
      this.finish(false);
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.over) {
      return false;
    }
    if (this.tgTarget() < 0) {
      return true;
    }
    this.tap(this.tgTarget());
    return !this.over;
  }

  /** 代打/提示共用：这一步点哪一格（已选中的那张先找它的补数） */
  private tgTarget(): number {
    const b: number[] = this.tiles;
    const s: number = this.sel;
    if (s >= 0 && b[s] > 0) {
      for (let i = 0; i < TOTAL; i++) {
        if (i !== s && b[i] > 0 && b[i] + b[s] === 10) {
          return i;
        }
      }
    }
    for (let i2: number = 0; i2 < TOTAL; i2++) {
      if (b[i2] <= 0) {
        continue;
      }
      for (let j: number = i2 + 1; j < TOTAL; j++) {
        if (b[j] > 0 && b[i2] + b[j] === 10) {
          return (s === i2) ? j : i2;
        }
      }
    }
    return -1;
  }

  /** 提示：报「哪两张牌凑十」（牌面是内容，不是下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.tgTarget();
    if (k < 0) {
      return Hint.none('none');
    }
    const b: number[] = this.tiles;
    const s: number = this.sel;
    if (s >= 0 && b[s] > 0) {
      return Hint.make([k],
        TG2('再点 {0}（{1} + {0} = 10）', String(b[k]), String(b[s])),
        TG2('Now tap {0} ({1} + {0} = 10)', String(b[k]), String(b[s])), t0);
    }
    return Hint.make([k],
      TG2('消掉 {0} 和 {1}（加起来正好 10）', String(b[k]), String(10 - b[k])),
      TG2('Remove {0} and {1} (they add up to 10)', String(b[k]), String(10 - b[k])), t0);
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
    if (this.over) { return; }
    const board: number[] = this.tiles;
    if (board[i] === 0) { return; }
    const cur: number = this.sel;
    if (cur < 0) { this.sel = i; this.msg = TG2('已选 {0}，再点一块凑 10', String(board[i])); return; }
    if (cur === i) { this.sel = -1; this.msg = TG('已取消选择'); return; }
    const sum: number = board[cur] + board[i];
    if (sum === 10) {
      const next: number[] = board.slice(); next[cur] = 0; next[i] = 0; this.tiles = next;
      this.cleared = this.cleared + 2; this.combo = this.combo + 1; this.clearedPulse = 1.3; setTimeout(() => { this.clearedPulse = 1; }, 140);
      if (this.combo > this.best) { this.best = this.combo; }
      this.score = this.score + 10 + this.combo * 2; this.sel = -1;
      if (this.cleared >= TOTAL) {
        this.over = true; this.won = true; this.msg = TG2("🎉 全消！用时 {0} 秒", String(LIMIT - this.left));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.msg = TG2('✅ 消掉一对，连击 {0}', String(this.combo));
    } else {
      this.combo = 0; this.score = Math.max(0, this.score - 5); this.sel = i;
      this.msg = TG2('❌ {0} + {1} = {2}，再试', String(board[cur]), String(board[i]), String(sum));
    }
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'target_10', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cleared };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  /** 内容随牌面变化 ⇒ key 带上牌值，保证格子重绘 */
  private tileKey(i: number): string { return 't' + i + '_' + this.tiles[i] + (this.sel === i ? 's' : ''); }
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
        Column({ space: 2 }) {
        Text((TG('时间'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(TOTAL - this.cleared))).fontSize(FontSize.md)
        // ★ 得分跳动
        .scale({ x: this.clearedPulse, y: this.clearedPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('连击'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.combo) + '/' + String(this.best))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              Text(this.tiles[(r * COLS + c)] === 0 ? '' : String(this.tiles[(r * COLS + c)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
              .fontColor(this.sel === (r * COLS + c) ? '#FFFFFF' : this.theme.ink)
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.tiles[(r * COLS + c)] === 0
              ? this.theme.bg
              : (this.sel === (r * COLS + c) ? Palette.orange : this.theme.surfaceAlt))
              .borderRadius(Radius.md).border({ width: this.sel === (r * COLS + c) ? 0 : 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
              Haptics.tick();
              this.tap((r * COLS + c));
              })
            }, (c: number) => this.tileKey(r * COLS + c))
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      Text(TG('提示：连续消对会加连击分，消错会掉分')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
