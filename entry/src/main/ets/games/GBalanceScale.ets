/**
 * 天平称重 —— 右盘砝码刚好等于物体的重量
 *
 * 玩法：左盘放着目标物体（重量已标出），右盘自己挑砝码 —— 点一下放上、再点一下拿回。
 * 胜负：连过 5 关 ⇒ 通关；任何一关右盘超重 ⇒ 天平翻，立刻失败。
 * 出题：先抽 6 枚砝码，再取其中 2~4 枚的和当目标 ⇒ 保证一定有解。
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const LEVELS: number = 5;      // 通关关数
const POOL: number = 6;        // 每关砝码个数
const COLS: number = 3;        // 砝码每行个数
const MAX_W: number = 24;      // 单个砝码最大重量
const CHIP_H: number = 64;     // 砝码格子高度
const TICK_MS: number = 1000;

@Component
export struct GBalanceScale {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private weights: number[] = [];
  @State private used: boolean[] = [];
  @State private target: number = 0;
  @State private level: number = 1;
  @State private score: number = 0;
  @State private seconds: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;
  private rows: number[] = [0, 1];
  private cols: number[] = [0, 1, 2];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTick();
  }

  private stopTick(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private reset(): void {
    this.stopTick();
    this.level = 1;
    this.score = 0;
    this.seconds = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.newLevel(true);
    this.timer = setInterval(() => {
      if (!this.over) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  /** 抽砝码 → 取其中几枚之和当目标 */
  private newLevel(first: boolean): void {
    const all: number[] = [];
    while (all.length < POOL) {
      const v: number = 1 + Math.floor(Math.random() * MAX_W);
      if (all.indexOf(v) < 0) {
        all.push(v);
      }
    }
    const want: number = 2 + Math.floor(Math.random() * 3);   // 2~4 枚
    const idx: number[] = [];
    while (idx.length < want) {
      const k: number = Math.floor(Math.random() * POOL);
      if (idx.indexOf(k) < 0) {
        idx.push(k);
      }
    }
    let t: number = 0;
    for (let i = 0; i < idx.length; i++) {
      t += all[idx[i]];
    }
    this.weights = all;
    this.used = new Array<boolean>(POOL).fill(false);
    this.target = t;
    this.msg = first
      ? '点砝码放上右盘，凑到刚好 ' + String(t)
      : TG('第 ') + String(this.level) + ' 关：称出 ' + String(t);
  }

  private sum(): number {
    let s: number = 0;
    for (let i = 0; i < this.weights.length; i++) {
      if (this.used[i]) {
        s += this.weights[i];
      }
    }
    return s;
  }

  private countUsed(): number {
    let n: number = 0;
    for (let i = 0; i < this.used.length; i++) {
      if (this.used[i]) {
        n = n + 1;
      }
    }
    return n;
  }

  /** 代打：该放上哪枚砝码（枚举 2^n 组，挑「已放 + 待放」正好等于目标的一组；-1 = 无解） */
  private autoChip(): number {
    const n: number = this.weights.length;
    const full: number = Math.pow(2, n);
    for (let m = 1; m < full; m++) {
      let s: number = 0;
      let bad: boolean = false;
      let add: number = -1;
      for (let j = 0; j < n; j++) {
        if (Math.floor(m / Math.pow(2, j)) % 2 === 1) {
          s += this.weights[j];
          if (!this.used[j]) {
            add = j;
          }
        } else if (this.used[j]) {
          bad = true;
        }
      }
      if (!bad && s === this.target && add >= 0) {
        return add;
      }
    }
    return -1;
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
    if (this.over || this.autoChip() < 0) {
      return true;
    }
    this.toggle(this.autoChip());
    return !this.over;
  }

  // 目标 = this.target，砝码 = this.weights ⇒ 报「再放哪几枚」（不会超过目标）
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.weights.length;
    const full: number = Math.pow(2, n);
    for (let m = 1; m < full; m++) {
      let s: number = 0;
      let bad: boolean = false;
      const adds: number[] = [];
      for (let j = 0; j < n; j++) {
        if (Math.floor(m / Math.pow(2, j)) % 2 === 1) {
          s += this.weights[j];
          if (!this.used[j]) {
            adds.push(j);
          }
        } else if (this.used[j]) {
          bad = true;
        }
      }
      if (bad || s !== this.target || adds.length === 0) {
        continue;
      }
      const parts: string[] = [];
      for (let k = 0; k < adds.length; k++) {
        parts.push(String(this.weights[adds[k]]));
      }
      return Hint.make(adds, '再放 ' + parts.join(' + ') + ' 号砝码，正好等于 ' + String(this.target),
        'Add weights ' + parts.join(' + '), t0);
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

  private toggle(i: number): void {
    if (this.over) {
      return;
    }
    const u: boolean[] = this.used.slice();
    u[i] = !u[i];
    this.used = u;
    const s: number = this.sum();
    if (s === this.target) {
      this.clearLevel();
      return;
    }
    if (s > this.target) {
      this.over = true;
      this.won = false;
      this.msg = TG2('💥 右盘 {0} 比物体 {1} 重，天平翻了', String(s), String(this.target));
      this.stopTick();
      this.finish(false);
      return;
    }
    this.msg = TG2('右盘 {0} · 还差 {1}', String(s), String(this.target - s));
  }

  private clearLevel(): void {
    this.score += 150 + Math.max(0, 120 - this.seconds * 4);
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.won = true;
      this.msg = TG2('🎉 连过 {0} 关，全部称准！',Digits(String(this.diffTotal), this.langCode));
      this.stopTick();
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    this.level = this.level + 1;
    this.newLevel(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'balance_scale',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.level
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
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 天平：左盘物体 / 右盘砝码
      Row({ space: Space.sm }) {
        this.pan(0)
        Text('⚖️').accessibilityLevel('no').fontSize(FontSize.xxl)
        this.pan(1)
      }
      .width('100%')

      // 砝码
      Column({ space: Space.sm }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.cols, (c: number) => {
              this.chip(r * COLS + c)
            }, (c: number) => 'gc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'gr' + r)
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('提示：右盘一旦超过物体重量，天平就翻了 —— 本局结束'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=关卡 1=得分 2=用时 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('关卡') : (kind === 1 ? TG('得分') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.level + '/' + this.diffTotal
        : (kind === 1 ? String(this.score) : this.seconds + 's'))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /** kind: 0=左盘物体 1=右盘砝码 */
  @Builder
  pan(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '📦 物体' : '🧱 右盘')
        .fontSize(FontSize.xs)
        .fontColor(this.theme.inkFaint)
      Text(String(kind === 0 ? this.target : this.sum()))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 0 ? Palette.teal : Palette.primary)
      Text(kind === 0 ? '重量' : String(this.countUsed()) + ' 枚砝码')
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .layoutWeight(1)
    .padding(Space.md)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.lg)
    .border({ width: 2, color: kind === 0 ? Palette.teal : this.theme.line })
    .shadow(Shadow.card)
  }

  @Builder
  chip(i: number) {
    Column({ space: 2 }) {
      Text(this.used[i] ? '🔵' : '⚪')
        .fontSize(FontSize.sm)
      Text(String(this.weights[i]))
        .fontSize(FontSize.xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.used[i] ? '#FFFFFF' : this.theme.ink)
    }
    .layoutWeight(1)
    .height(CHIP_H)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.used[i] ? Palette.primary : this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .scale({ x: this.used[i] ? 1.04 : 1, y: this.used[i] ? 1.04 : 1 })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.toggle(i); }); })
    .onClick(() => {
      Haptics.tick();
      this.toggle(i);
    })
  }
}
