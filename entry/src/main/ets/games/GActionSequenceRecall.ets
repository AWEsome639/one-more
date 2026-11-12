/**
 * 动作序列 —— 记住机器人依次做的动作，再按同样顺序点一遍
 * 胜负：6 关全过通关；错 3 次失败　进度：关卡 / 长度 / 得分 / 生命
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { ProgressStore } from '../core/ProgressStore';
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
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  /** ★ 2026-11-08 代打的记忆副本（刺激播完后抄下，作答只看它） */
  private aiMem: number[] = [];
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
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
    // ★★★ 2026-11-08（退出恢复最小版）：从上次玩到的那一关接着玩（level 1 基）
    // ★ 每进程只恢复一次：`再来一局` 会重建组件、`aboutToAppear` 会再跑 —— 不设闸门就会破坏「再来一局 = 从头」
    const lastLv: number = ProgressStore.shouldRestoreNow('action_sequence_recall') ? ProgressStore.lastLevel('action_sequence_recall') : 0;
    if (lastLv > 1 && lastLv < this.diffTotal) {
      this.level = lastLv;
      this.deal();
    }
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
    // ★ 2026-11-07 真机 bug（verifier-dev 扫描 S-01）：原来这行是**裸表达式**（值被丢弃），
    //   本该赋值给 this.msg ⇒ 新局没有引导语、HUD 还挂着上一局的「命用完了」。
    this.msg = TG2('看好机器人做 {0} 个动作…', this.len());
  }

  /** 每 STEP_MS 走半拍：偶数拍亮、奇数拍灭 */
  private step(): void {
    if (this.over || !this.playing) { return; }
    const k: number = Math.floor(this.tickN / 2);
    if (k >= this.seq.length) {
      this.playing = false; this.showIdx = -1; this.msg = TG('轮到你了 —— 按同样顺序点一遍');
      // ★ 2026-11-08（ai-fixer-a）代打「记住」刚演完的动作序列
      this.aiMem = this.seq.slice(); return;
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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    // ★ 2026-11-08 只读自己的记忆副本；没记到就停手
    if (this.aiMem.length === 0) {
      return false;
    }
    this.tap(this.aiMem[this.cursor]);
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
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
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
      // ★ 2026-11-08（退出恢复最小版）：记下当前关卡（1 基）
      ProgressStore.saveLastWhere('action_sequence_recall', this.level, String(GameDiff.of('action_sequence_recall')));
      // ★★★ 2026-11-07 同 A1：裸 `TG2(...)` ⇒ 过关正反馈丢失（verifier-dev 扫描 A2）
      this.msg = TG2('✅ 过关！第 {0} 关：{1} 个动作',Digits(String(this.level), this.langCode), this.len());
    }
  }

  private end(solved: boolean): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.over = true; this.won = solved; this.playing = false; this.showIdx = -1;
    this.msg = solved ? TG('🎉 六关全过，通关！') : TG2("💤 命用完了 —— 撑到第 {0} 关",Digits(String(this.level), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'action_sequence_recall', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.level + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.len() + TG(' 个'))).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
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
          .onFocus(() => { this.tvFocus = 'L305'; })
          .onBlur(() => { if (this.tvFocus === 'L305') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L305'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((i)); }); })
          .onClick(() => { Haptics.tick(); this.tap((i)); })
        }, (i: number) => 'a' + i)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L325'; })
        .onBlur(() => { if (this.tvFocus === 'L325') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L325')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
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
