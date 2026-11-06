/**
 * 词缀工厂 —— 给词根接上正确的词缀，造出符合中文释义的单词
 * 胜负：8 题答对 ≥6 ⇒ 通关｜进度：题号 / 答对 / 得分
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { Bp } from '../core/Bp';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const QN: number = 8; const PASS: number = 6; const FEED_MS: number = 800;

interface AffixQ { root: string; affix: string; meaning: string; opts: string[] }

const BANK: AffixQ[] = [
  { root: 'happy', affix: 'un-', meaning: TG('不快乐的'), opts: ['un-', 're-', '-ful', '-less'] },
  { root: 'care', affix: '-ful', meaning: '小心的；关心的', opts: ['-less', '-ful', 'un-', '-ly'] },
  { root: 'hope', affix: '-less', meaning: '没有希望的', opts: ['-ful', '-less', 're-', '-ness'] },
  { root: 'write', affix: 're-', meaning: TG('重写'), opts: ['re-', 'un-', '-er', 'dis-'] },
  { root: 'teach', affix: '-er', meaning: '教师', opts: ['-er', '-ness', '-ing', 'pre-'] },
  { root: 'kind', affix: '-ness', meaning: '善良', opts: ['-ness', '-ly', 'un-', '-ful'] },
  { root: 'possible', affix: 'im-', meaning: '不可能的', opts: ['im-', 'un-', 'dis-', '-less'] },
  { root: 'agree', affix: 'dis-', meaning: '不同意', opts: ['dis-', 'un-', 're-', '-ment'] },
  { root: 'quick', affix: '-ly', meaning: '迅速地', opts: ['-ly', '-ness', '-er', '-ful'] },
  { root: 'view', affix: 'pre-', meaning: '预览', opts: ['pre-', 're-', 'dis-', '-er'] },
  { root: 'act', affix: '-or', meaning: '演员', opts: ['-or', '-ness', 'un-', '-ly'] },
  { root: 'fair', affix: 'un-', meaning: '不公平的', opts: ['un-', '-ly', 'dis-', '-ness'] }
];

/** 从 0..total-1 里随机取 k 个互不相同的下标 */
function pickIndexes(total: number, k: number): number[] {
  const out: number[] = [];
  while (out.length < k) {
    const j: number = Math.floor(Math.random() * total);
    if (out.indexOf(j) < 0) { out.push(j); }
  }
  return out;
}
function shuffleStr(arr: string[]): string[] {
  const out: string[] = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
/** 前加词缀（un-）拼左边，后加词缀（-ful）拼右边 */
function joinWord(root: string, affix: string): string {
  if (affix.substring(affix.length - 1) === '-') { return affix.substring(0, affix.length - 1) + root; }
  if (affix.substring(0, 1) === '-') { return root + affix.substring(1); }
  return root + affix;
}

@Component
export struct GAffixFactory {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：QN 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private diffTotal: number = GameDiff.sizeNow(QN);
  onFinish: (r: GameResult) => void = () => {};

  @State queue: number[] = []; @State opts: string[] = [];
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State pickedOk: number = -1; @State lastPick: string = ''; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAffixFactory')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(QN);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }
  private reset(): void {
    this.stop();
    this.queue = pickIndexes(BANK.length, this.diffTotal);
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now(); this.load();
  }
  private cur(): AffixQ { return this.qIndex >= this.diffTotal ? BANK[0] : BANK[this.queue[this.qIndex]]; }
  private load(): void {
    this.opts = shuffleStr(this.cur().opts); this.pickedOk = -1; this.lastPick = '';
    this.msg = TG2('词根「{0}」该接哪个词缀？', this.cur().root);
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.pickedOk >= 0) {
      return true;
    }
    this.pick(this.cur().affix);
    return !this.over;
  }

  /** 提示：直接报答案 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.pickedOk >= 0) {
      return Hint.none('none');
    }
    const a: string = this.cur().affix;
    if (a.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('应加「{0}」', a),
      TG2('Add {0}', a), t0);
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

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private pick(o: string): void {
    if (this.pickedOk >= 0 || this.over) { return; }
    const q: AffixQ = this.cur();
    this.lastPick = o;
    if (o === q.affix) {
      this.pickedOk = 1; this.right = this.right + 1; this.score = this.score + 100;
      this.msg = '✅ ' + joinWord(q.root, q.affix) + ' ＝ ' + q.meaning;
    } else {
      this.pickedOk = 0; this.msg = TG2('❌ 应加「{0}」⇒ {1}', q.affix, joinWord(q.root, q.affix));
    }
    this.feed = setTimeout(() => { this.feed = -1; this.advance(); }, FEED_MS);
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won);
      return;
    }
    this.load();
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'affix_factory', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private tone(o: string): string {
    if (this.pickedOk < 0 || this.qIndex >= this.diffTotal) { return Palette.sky; }
    if (o === this.cur().affix) { return Palette.emerald; }
    return o === this.lastPick ? Palette.rose : Palette.sky;
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, this.diffTotal) + '/' + this.diffTotal))
          // ★ 2026-11-02（第 845 轮）**233×233 真机抓到**：这里原来没限行，
          //   「0/10」在手表上被折成两行（实测 bounds 高 126px = 2 行）。
          //   ⇒ 加 maxLines(1) 强制单行；极小屏缩一档字号（lg→md）。
          .fontSize(Bp.tinyScreen() ? FontSize.md : FontSize.lg).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode))
          .fontSize(Bp.tinyScreen() ? FontSize.md : FontSize.lg).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
          .fontSize(Bp.tinyScreen() ? FontSize.md : FontSize.lg).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.qIndex >= this.diffTotal ? TG('本局结束') : this.cur().root).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.qIndex >= this.diffTotal ? TG('答对 ') + this.right + ' / ' + this.diffTotal : '＋ ？ ＝ ' + this.cur().meaning).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.opts, (o: string) => { Button((o))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.tone((o))).borderRadius(Radius.md).width('100%').height(Cell.of(48))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
          .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L326'; })
        .onBlur(() => { if (this.tvFocus === 'L326') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L326'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((o)); }); })
        .onClick(() => { Haptics.tap(); this.pick((o)); }) }, (o: string) => o)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L334'; })
        .onBlur(() => { if (this.tvFocus === 'L334') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L334')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：un- / re- / dis- 走前面，-ful / -less / -ness 挂后面'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
