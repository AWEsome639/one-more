/**
 * 频率点击 —— 跟着 100 BPM 的节拍点圆盘，测节奏同步
 * 胜负：20 拍命中 ≥ 16 ⇒ 通关；进度：拍号 / 命中数 / 上次误差 ms
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const BEATS: number = 20;
const GAP: number = 600;        // 100 BPM
const HIT_MS: number = 170;
const WIN_HITS: number = 16;

@Component
export struct GFrequencyTap {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：BEATS 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(BEATS);
  onFinish: (r: GameResult) => void = () => {};

  @State private phase: number = 0;      // 0 待开始 1 进行中 2 结束
  @State private beatN: number = 0;
  @State private hitN: number = 0;
  @State private tapN: number = 0;
  @State private lastErr: number = 0;
  @State private pulse: boolean = false;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private beatTs: number[] = [];
  private hitFlags: boolean[] = [];
  private startAt: number = 0;
  private timer: number = -1;
  private endTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(BEATS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.endTo >= 0) { clearTimeout(this.endTo); this.endTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.phase = 0; this.beatN = 0; this.hitN = 0; this.tapN = 0; this.lastErr = 0;
    this.pulse = false; this.over = false; this.won = false; this.done = false;
    this.beatTs = []; this.hitFlags = [];
    this.msg = TG(TG(TG('按「开始」，然后每拍点一下圆盘')));
    this.startAt = Date.now();
  }

  private start(): void {
    this.reset();
    this.phase = 1;
    this.msg = TG(TG(TG('跟住节拍：点圆盘')));
    this.timer = setInterval(() => { this.onBeat(); }, GAP);
  }

  private onBeat(): void {
    this.beatTs.push(Date.now());      // 记真实时刻，不用"理想节拍"
    this.hitFlags.push(false);
    this.beatN = this.beatN + 1;
    this.pulse = !this.pulse;
    if (this.beatN >= this.diffTotal) {
      this.clearAll();
      this.endTo = setTimeout(() => { this.endTo = -1; this.judge(); }, GAP + 200);
    }
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase === 2) {
      return true;
    }
    this.tap();
    return !this.over;
  }

  // 这款没有"答案格"，只有节拍 ⇒ 提示报节拍间隔与本拍进度
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase === 2) {
      return Hint.none('none');
    }
    if (this.beatTs.length === 0) {
      return Hint.make([], '先按「开始」，之后每 ' + String(GAP) + ' 毫秒点一下圆盘（误差 ±' + String(HIT_MS) + 'ms 都算命中）',
        'Press start, then tap once every ' + String(GAP) + ' ms', t0);
    }
    const last: number = this.beatTs[this.beatTs.length - 1];
    const next: number = last + GAP;
    return Hint.make([], '跟着节拍点：下一拍还有 ' + String(Math.max(0, next - Date.now())) + ' ms（已命中 ' + String(this.hitN) + '/' + String(this.diffTotal) + '）',
      'Next beat in ' + String(Math.max(0, next - Date.now())) + ' ms', t0);
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

  private tap(): void {
    if (this.phase === 0) { this.start(); return; }
    if (this.phase !== 1) { return; }
    const now: number = Date.now();
    let bestI: number = -1;
    let bestD: number = 99999;
    for (let i = 0; i < this.beatTs.length; i++) {
      const d: number = Math.abs(now - this.beatTs[i]);
      if (d < bestD) { bestD = d; bestI = i; }
    }
    if (bestI < 0 || bestD > HIT_MS * 2) { this.msg = TG(TG(TG('⚠️ 完全没踩上，再跟紧一点'))); return; }
    this.tapN = this.tapN + 1;
    this.lastErr = now - this.beatTs[bestI];
    const early: boolean = this.lastErr < 0;
    if (bestD <= HIT_MS && !this.hitFlags[bestI]) {
      const flags: boolean[] = this.hitFlags.slice();
      flags[bestI] = true;
      this.hitFlags = flags;
      this.hitN = this.hitN + 1;
      this.msg = '✅ 误差 ' + (early ? '' : '+') + String(this.lastErr) + ' ms';
    } else {
      this.msg = TG2('😐 偏差 {0} ms（{1}）', String(this.lastErr), early ? TG('偏快') : TG('偏慢'));
    }
  }

  private judge(): void {
    this.phase = 2; this.over = true; this.won = this.hitN >= WIN_HITS;
    this.msg = TG2(this.won ? '🎉 节奏稳！命中 {0}/{1} 拍' : '💤 结束，命中 {0}/{1} 拍',Digits(String(this.hitN), this.langCode),Digits(String(this.diffTotal), this.langCode));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'frequency_tap', solved: this.won,
        score: Math.max(0, this.hitN * 60 - (this.diffTotal - this.hitN) * 20),
        durationMs: Date.now() - this.startAt, levelReached: this.hitN
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
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
        Column({ space: Space.xs }) {
        Text((TG(TG('拍号')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.beatN) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hitN), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG(TG('上次误差')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.tapN > 0 ? (String(this.lastErr) + 'ms') : '—')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Stack() {
        Text(this.phase === 1 ? '👆' : (this.phase === 2 ? (this.won ? '🎉' : '💤') : '▶️'))
          .fontSize(FontSize.hero)
      }.width('64%').aspectRatio(1)
      .backgroundColor(this.pulse ? Palette.rose : this.theme.surfaceAlt)
      .borderRadius(Radius.full).shadow(Shadow.card)
      .scale({ x: this.pulse ? 1.05 : 0.95, y: this.pulse ? 1.05 : 0.95 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.tap(); })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Button(this.phase === 0 ? TG('开始') : (this.phase === 2 ? TG('再来一局') : TG('重开')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .onClick(() => { Haptics.tap(); if (this.phase === 0) { this.start(); } else { this.reset(); } })

      Text(TG2("{0}{1} 拍即通关", TG2('判定：每拍误差 ≤ {0} ms 记命中，{1} 拍中 ', String(HIT_MS), String(this.diffTotal)),Digits(String(WIN_HITS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
