/**
 * 打字速度 —— 照抄屏幕上的一句话，实时统计 WPM 与正确率
 * 胜负：5 句都在 25 秒内打完且正确率 ≥ 90% 通关 ｜ 进度：第几句 / WPM / 正确率 / 剩余秒
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 5; const LIMIT_MS: number = 25000;
const TICK_MS: number = 100; const PASS_ACC: number = 90;

const LINES: string[] = [
  'the quick brown fox jumps over the lazy dog', 'practice every day and the fingers will remember',
  'a small step today becomes a long road tomorrow', 'keep the rhythm steady and the errors will fall away',
  'type with your eyes ahead and your hands will follow', 'slow is smooth and smooth is fast in the end',
  'every long word is only a row of small letters', 'read the whole line first then let the hands run'
];

function norm(s: string): string {
  const parts: string[] = s.trim().toLowerCase().split(' '); const out: string[] = [];
  for (let i = 0; i < parts.length; i++) { if (parts[i].length > 0) { out.push(parts[i]); } }
  return out.join(' ');
}

function matched(typed: string, target: string): number {
  const n: number = typed.length < target.length ? typed.length : target.length;
  let ok: number = 0;
  for (let i = 0; i < n; i++) { if (typed.charAt(i) === target.charAt(i)) { ok = ok + 1; } }
  return ok;
}

/** 从 0..total-1 中随机取 k 个互不相同的下标 */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

@Component
export struct GTypingSpeed {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private order: number[] = []; @State private qi: number = 0;
  @State private typed: string = ''; // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT_MS);
  @State private leftMs: number = 0;
  @State private wpm: number = 0; @State private acc: number = 100;
  @State private doneRounds: number = 0; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false;
  @State private k: number = 1;

  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private baseOk: number = 0; private baseTyped: number = 0; private finished: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT_MS);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private target(): string { return LINES[this.order[this.qi]]; }

  /** ★ 2026-10-14 动画补齐：进度/得分脉冲（本款原来一处 .animation() 都没有） */

  private bumpK(): void {

    this.k = 1.16;

    animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.k = 1; });

  }


  private reset(): void {
    this.stop();
    this.order = pickIndexes(LINES.length, ROUNDS);
    this.qi = 0; this.typed = ''; this.leftMs = this.total; this.wpm = 0; this.acc = 100;
    this.doneRounds = 0; this.over = false; this.won = false; this.finished = false;
    this.baseOk = 0; this.baseTyped = 0;
    this.startAt = Date.now(); this.roundAt = Date.now();
    this.msg = TG('照着上面那句打，打完自动换句');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 没有"答案字段"—— 要打的就是 this.target()，填满再走玩家的结算（roundDone）
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    this.typed = this.target();
    this.roundDone();
    return !this.over;
  }

  /** 提示：报这一句里还没打的部分 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const t: string = this.target();
    if (this.typed.length >= t.length) {
      return Hint.none('none');
    }
    const rest: string = t.substring(this.typed.length);
    return Hint.make([], TG2('接下来要打：{0}', rest),
      TG2('Coming up: {0}', rest), t0);
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

  private statsNow(): void {
    const totalOk: number = this.baseOk + matched(this.typed, this.target());
    const totalTyped: number = this.baseTyped + this.typed.length;
    const mins: number = (Date.now() - this.startAt) / 60000;
    this.wpm = mins > 0 ? Math.round((totalOk / 5) / mins) : 0;
    this.bumpK();
    this.acc = totalTyped > 0 ? Math.round(totalOk * 100 / totalTyped) : 100;
  }

  private roundDone(): void {
    this.baseOk = this.baseOk + matched(this.typed, this.target());
    this.baseTyped = this.baseTyped + this.target().length;
    this.typed = ''; this.statsNow();
    this.doneRounds = this.doneRounds + 1;
    if (this.qi + 1 >= ROUNDS) { this.end(); return; }
    this.qi = this.qi + 1; this.leftMs = this.total; this.roundAt = Date.now();
  }

  private tick(): void {
    if (this.over) { return; }
    const gap: number = Date.now() - this.roundAt;
    if (gap >= LIMIT_MS) {
      if (this.leftMs === 0) { return; }
      this.leftMs = 0; this.msg = TG('⌛ 超时，这句算错');
      this.roundDone();
      return;
    }
    this.leftMs = LIMIT_MS - gap; this.statsNow();
  }

  private end(): void {
    this.stop();
    if (this.finished) { return; }
    this.finished = true; this.over = true;
    this.won = this.doneRounds >= ROUNDS && this.acc >= PASS_ACC;
    this.msg = TG2("{0}{1} WPM ｜ 正确率 {2}%", (this.won ? TG('🎉 通关：') : TG('💤 结束：')), this.wpm, this.acc);
    const r: GameResult = { gameId: 'typing_speed', solved: this.won, score: this.wpm,
      durationMs: Date.now() - this.startAt, levelReached: this.doneRounds };
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
      Row({ space: Space.sm }) {
        Text(TG2('句 {0}/{1}　{2} WPM　正确率 ', Math.min(this.qi + 1, ROUNDS), ROUNDS, this.wpm)
          + this.acc + TG2('%　剩余 {0}s', (this.leftMs / 1000).toFixed(1)))
          .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).layoutWeight(1)
        .scale({ x: this.k, y: this.k })
        Text(Digits(String(this.doneRounds), this.langCode)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(TG('照着打这一句')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.target()).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink).maxLines(3)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      TextInput({ text: this.typed, placeholder: '在这里输入…' })
        .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
        .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).width('100%').height(Cell.of(52)).padding({ left: Space.sm, right: Space.sm })
        .enabled(!this.over)
        .onChange((v: string) => {
          this.typed = v; this.statsNow();
          const local: string = norm(v);
          if (local.length > 0 && local === norm(this.target())) {
            this.msg = TG('✅ 这一句拿下'); this.roundDone();
          }
        })
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(TG('提示：不区分大小写；25 秒没打完算这句错')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
