/**
 * 动作序列 —— 记住机器人依次做的动作，再按同样顺序点一遍
 * 胜负：6 关全过通关；错 3 次失败　进度：关卡 / 长度 / 得分 / 生命
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const ACTS: string[] = ['👏', '🦶', '🤚', '✊'];
const NAMES: string[] = [TG('拍手'), TG('跺脚'), TG('举手'), TG('握拳')];
const LEVELS: number = 6; const BASE: number = 3; const LIVES: number = 3; const STEP_MS: number = 340;
@Component
export struct GActionSequenceRecall {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State seq: number[] = []; @State cursor: number = 0; @State showIdx: number = -1;
  @State playing: boolean = false; @State level: number = 1; @State score: number = 0;
  @State life: number = LIVES; @State over: boolean = false; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false;
  private timer: number = -1; private tickN: number = 0; private slots: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GActionSequenceRecall')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  aboutToDisappear(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private reset(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.level = 1; this.score = 0; this.life = LIVES; this.over = false; this.won = false;
    this.finished = false; this.startAt = Date.now(); this.deal();
    this.timer = setInterval(() => { this.step(); }, STEP_MS);
  }

  private len(): number { return BASE + this.level - 1; }

  private deal(): void {
    const s: number[] = [];
    for (let i = 0; i < this.len(); i++) { s.push(Math.floor(Math.random() * ACTS.length)); }
    this.seq = s; this.cursor = 0; this.showIdx = -1; this.playing = true; this.tickN = 0;
    TG2('看好机器人做 {0} 个动作…', this.len())
  }

  /** 每 STEP_MS 走半拍：偶数拍亮、奇数拍灭 */
  private step(): void {
    if (this.over || !this.playing) { return; }
    const k: number = Math.floor(this.tickN / 2);
    if (k >= this.seq.length) {
      this.playing = false; this.showIdx = -1; this.msg = TG('轮到你了 —— 按同样顺序点一遍'); return;
    }
    this.showIdx = this.tickN % 2 === 0 ? this.seq[k] : -1;
    this.tickN = this.tickN + 1;
  }

  /** 提示：按顺序点，现在该点第 idx+1 个（seq[idx]） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.cursor;
    if (k < 0 || k >= this.seq.length) {
      return Hint.none('none');
    }
    return Hint.make([this.seq[k]],
      TG2('该点第 {0} 个', String(this.seq[k] + 1)),
      TG2('Tap number {0}', String(this.seq[k] + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 动作序列回忆：按顺序点 seq
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.playing) {
      return true;              // 还在播放/过渡，等
    }
    if (this.cursor >= this.seq.length) {
      return true;              // 这一轮答完了，等它开下一轮
    }
    this.tap(this.seq[this.cursor]);
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

  private tap(i: number): void {
    if (this.over || this.playing) { return; }
    if (i !== this.seq[this.cursor]) {
      this.life = this.life - 1;
      if (this.life <= 0) { this.end(false); return; }
      this.deal();
      // ★ 2026-10-16 整句化：各语言语序不同，不能拼片段
      this.msg = TG2('❌ 第 {0} 步错了 —— 只剩 {1} 条命，重放一次', this.cursor + 1,Digits(String(this.life), this.langCode));
      return;
    }
    this.cursor = this.cursor + 1;
    this.score = this.score + 15 + this.level * 5;
    if (this.cursor >= this.seq.length) {
      if (this.level >= this.diffTotal) { this.end(true); return; }
      this.level = this.level + 1; this.deal();
      TG2('✅ 过关！第 {0} 关：{1} 个动作',Digits(String(this.level), this.langCode), this.len())
    }
  }

  private end(solved: boolean): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.over = true; this.won = solved; this.playing = false; this.showIdx = -1;
    this.msg = solved ? '🎉 六关全过，通关！' : TG2("💤 命用完了 —— 撑到第 {0} 关",Digits(String(this.level), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'action_sequence_recall', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.level + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.len() + TG(' 个'))).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Stack() {
        Text(this.showIdx < 0 ? (this.playing ? '·' : '👀') : ACTS[this.showIdx])
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }
      .width('100%').height(150)
      .backgroundColor(this.showIdx < 0 ? this.theme.surfaceAlt : Palette.primary)
      .borderRadius(Radius.lg).shadow(Shadow.lifted).animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.xs }) {
        ForEach(this.seq, (v: number, i: number) => {
          Text(i < this.cursor ? '●' : '○').fontSize(FontSize.sm).layoutWeight(1).textAlign(TextAlign.Center)
            .fontColor(i < this.cursor ? Palette.emerald : this.theme.inkFaint)
        }, (v: number, i: number) => 'd' + i)
      }
      .width('100%')
      Row({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Column({ space: 2 }) {
          Text(ACTS[(i)]).fontSize(FontSize.xxl)
          Text(NAMES[(i)]).fontSize(FontSize.xxs).fontColor(this.theme.inkSoft)
          }
          .layoutWeight(1).height(Cell.of(80)).justifyContent(FlexAlign.Center).padding(Space.xs)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
          .opacity(this.playing ? 0.5 : 1).animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((i)); }); })
          .onClick(() => { Haptics.tick(); this.tap((i)); })
        }, (i: number) => 'a' + i)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：回放期间按钮不响应，等「轮到你了」再动手'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
