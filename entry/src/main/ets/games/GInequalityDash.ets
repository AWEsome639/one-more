/** 不等式冲刺 —— 限时解不等式；玩法：把 ax + c ⋚ k 解成 x 的范围，四选一，60 秒内尽量多答；胜负：答对 8 题 ⇒ 通关；时间到 ⇒ 按答对数判失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';

const LIMIT: number = 60; const TARGET: number = 8; const NEXT_MS: number = 480;
const OPS: string[] = ['<', '≤', '>', '≥']; const ROWS: number[] = [0, 1]; const COLS: number[] = [0, 1];
@Component
export struct GInequalityDash {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private expr: string = '';
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private opts: string[] = [];
  @State private ans: number = 0;
  @State private picked: number = -1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private hits: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private hitsPulse: number = 1;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private tick: number = -1; private nextTo: number = -1;
  private finished: boolean = false; private cells: number[] = [0, 1, 2, 3];
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.left = this.total; this.hits = 0; this.score = 0; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.ask(); this.msg = TG('移项、两边同除系数，注意不等号方向');
    this.tick = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.left = this.left - 1;
      if (this.left > 0) { return; }
      this.left = 0;
      if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
      if (this.over) { return; }
      this.over = true; this.won = this.hits >= TARGET;
      this.msg = this.won ? TG('🎉 答对 ') + String(this.hits) + ' 题，通关！'
        : '⏰ 时间到，只答对 ' + String(this.hits) + '/' + String(TARGET) + TG(' 题');
      this.finish(this.won);
    }, 1000);
  }
  /** 出题：a·x + c ⋚ k ⇒ x ⋚ (k-c)/a，正确答案 + 3 个易错项 */
  private ask(): void {
    const a: number = 2 + Math.floor(Math.random() * 3);        // 2 ~ 4
    const sol: number = 2 + Math.floor(Math.random() * 8);      // 2 ~ 9
    const c: number = 1 + Math.floor(Math.random() * 9); const oi: number = Math.floor(Math.random() * 4);
    const k: number = a * sol + c; this.expr = String(a) + 'x + ' + String(c) + ' ' + OPS[oi] + ' ' + String(k);
    const flip: number = oi < 2 ? oi + 2 : oi - 2; const good: string = OPS[oi] + ' ' + String(sol);
    const pool: string[] = [
      OPS[flip] + ' ' + String(sol),
      OPS[oi] + ' ' + String(sol + 1),
      OPS[oi] + ' ' + String(sol - 1),
      OPS[flip] + ' ' + String(sol + 2)
    ]; const list: string[] = [good];
    for (let i = 0; i < pool.length && list.length < 4; i++) {
      if (list.indexOf(pool[i]) < 0) { list.push(pool[i]); }
    }
    for (let i = list.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1)); const t: string = list[i]; list[i] = list[j]; list[j] = t;
    }
    this.opts = list; this.ans = list.indexOf(good); this.picked = -1;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
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
    if (i === this.ans) {
      this.hits = this.hits + 1; this.score += 120 + this.left; this.msg = TG2('✅ 答案 x {0}', this.opts[this.ans]); this.hitsPulse = 1.3; setTimeout(() => { this.hitsPulse = 1; }, 140);
      if (this.hits >= TARGET) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 答对 {0} 题，用了 {1} 秒", String(TARGET), String(LIMIT - this.left)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
    } else {
      this.score = Math.max(0, this.score - 25); this.msg = TG2('❌ 应是 x {0}', this.opts[this.ans]);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.ask(); }, NEXT_MS);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    const r: GameResult = {
      gameId: 'inequality_dash', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private btnBg(i: number): string {
    if (this.picked < 0) { return this.theme.surface; }
    if (i === this.ans) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private btnInk(i: number): string {
    if (this.picked < 0) { return this.theme.ink; }
    if (i === this.ans) { return '#FFFFFF'; }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + '/' + TARGET)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.hitsPulse, y: this.hitsPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('🔢').fontSize(FontSize.xxl)
          .accessibilityLevel('no')
        Text(this.expr).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.violet)
        Text(TG('x 的范围是？')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(ROWS, (row: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (col: number) => {
              Stack() {
              Text('x ' + this.opts[(row * 2 + col)]).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.btnInk((row * 2 + col)))
              }.layoutWeight(1).height(Cell.of(56)).backgroundColor(this.btnBg((row * 2 + col))).borderRadius(Radius.md).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick((row * 2 + col)); })
            }, (col: number) => 'idc' + col)
          }.width('100%')
        }, (row: number) => 'idr' + row)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：ax + c > k ⇒ x > (k−c)/a；两边同除负数才要变号')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
