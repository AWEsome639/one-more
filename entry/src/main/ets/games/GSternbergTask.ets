/**
 * 斯滕伯格 —— 先记住 4 个水果，再看探针是否在记忆集里（短时记忆扫描）
 * 胜负：10 次答对 ≥ 7 ⇒ 通关（越快分越高）　｜　进度：试次 / 答对 / 得分
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

const TRIALS: number = 10; const PASS: number = 7; const SET_N: number = 4;
const SHOW_MS: number = 1900; const FEED_MS: number = 460;
const POOL: string[] = ['🍎', '🍌', '🍇', '🍒', '🥝', '🍑', '🍍', '🥥'];

@Component
export struct GSternbergTask {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State memo: string[] = []; @State probe: string = ''; @State inSet: boolean = false;
  @State phase: number = 0;      // 0 记忆　1 探测　2 反馈
  @State trial: number = 1; @State hits: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private shownAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll(); this.trial = 1; this.hits = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const bag: string[] = POOL.slice();
    for (let i = bag.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: string = bag[i]; bag[i] = bag[j]; bag[j] = tmp;
    }
    const set: string[] = bag.slice(0, SET_N);
    this.memo = set;
    this.inSet = Math.random() < 0.5;
    this.probe = this.inSet ? set[Math.floor(Math.random() * SET_N)]
      : bag[SET_N + Math.floor(Math.random() * (POOL.length - SET_N))];
    this.phase = 0;
    this.msg = TG2("第 {0} / {1} 次：记住这 {2} 个",Digits(String(this.trial), this.langCode),Digits(String(this.diffTotal), this.langCode), SET_N);
    this.timer = setTimeout(() => {
      this.timer = -1; this.phase = 1; this.shownAt = Date.now();
      this.msg = TG2('刚才的集合里有 {0} 吗？', this.probe);
    }, SHOW_MS);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔直取：斯特恩伯格，答案就在 this.inSet
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    this.answer(this.inSet);
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

  private answer(yes: boolean): void {
    if (this.phase !== 1) { return; }
    const rt: number = Date.now() - this.shownAt;
    this.phase = 2;
    if (yes === this.inSet) {
      this.hits = this.hits + 1; this.score = this.score + Math.max(20, 100 - Math.floor(rt / 30));
      this.msg = '✅ ' + rt + ' ms';
    } else {
      this.msg = TG2("❌ 它{0}刚才的集合里", (this.inSet ? '在' : TG('不在')));
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.trial >= this.diffTotal) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.hits, this.diffTotal);
      this.finish(this.won); return;
    }
    this.trial = this.trial + 1; this.newTrial();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'sternberg_task', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.trial };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trial + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(this.phase === 0 ? '👀 记忆集' : (this.phase === 1 ? '❓ 探针' : '🔍 复盘'))
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        if (this.phase === 0) {
          Row({ space: Space.sm }) {
            ForEach(this.memo, (s: string, i: number) => {
              Stack() {
              Text((s)).fontSize(FontSize.hero)
              }.layoutWeight(1).height('100%').backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (s: string, i: number) => 'm' + i + s)
          }.width('100%').layoutWeight(1)
        } else if (this.phase === 1) {
          Row({ space: Space.sm }) {
            Stack() {
            Text((this.probe)).fontSize(FontSize.hero)
            }.layoutWeight(1).height('100%').backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
          }.width('100%').layoutWeight(1)
        } else {
          Column({ space: Space.sm }) {
            Row({ space: Space.sm }) {
              ForEach(this.memo, (s: string, i: number) => {
                Text((s)).fontSize(FontSize.xxl).layoutWeight(1).textAlign(TextAlign.Center).padding(Space.xs)
                .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm)
              }, (s: string, i: number) => 'r' + i + s)
            }.width('100%')
            Text(TG2("探针 {0}{1}", this.probe, (this.inSet ? ' 在集合里' : ' 不在集合里')))
              .fontSize(FontSize.sm).fontColor(this.inSet ? Palette.emerald : Palette.rose)
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }.width('100%').layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        Button((TG('出现过 ✅')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor((true) ? Palette.emerald : Palette.rose)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(this.phase === 1).onClick(() => { Haptics.tap(); this.answer((true)); })
        Button((TG('没出现 ❌')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor((false) ? Palette.emerald : Palette.rose)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(this.phase === 1).onClick(() => { Haptics.tap(); this.answer((false)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        onAutoTap: () => { this.askAuto(); },
        showHint: false,
        autoOn: this.autoId >= 0
      })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
