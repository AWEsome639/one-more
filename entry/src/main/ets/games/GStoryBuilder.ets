/**
 * 故事拼装 —— 打乱的句子按「事情发生的先后」一段段接回完整故事
 * 胜负：接完 3 段故事通关；错接 3 次失败 ｜ 进度：第几段 / 已接句数 / 生命 / 得分
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

const STORIES: number = 3; const LINES: number = 5; const LIVES: number = 3;

interface Story { title: string; lines: string[] }

const BANK: Story[] = [
  { title: '赶早八', lines: ['闹钟响了第三遍', '他爬起来洗了把脸', '出门才发现下着雨', '只好折回去拿伞', '最后还是迟到了十分钟'] },
  { title: '煮一碗面', lines: ['锅里先烧上半锅水', '水开后下面条', '撒一勺酱油与葱花', '盛出来晾上两分钟', '呼噜呼噜吃个精光'] },
  { title: '一棵番茄', lines: ['种子被埋进松软的土里', '春雨把它轻轻浇醒', '嫩芽顶开了泥土', '夏天长成一丛浓绿', '秋天结出红红的果实'] },
  { title: '一封信', lines: ['他把信纸铺得平平整整', '一笔一画写下问候', '折好塞进信封', '贴上邮票投进邮筒', '一周后收到了回信'] }
];

/** 从 0..total-1 中随机取 k 个互不相同的下标（k=total 就是整段洗牌） */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

@Component
export struct GStoryBuilder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private picks: number[] = []; @State private si: number = 0;
  @State private pool: string[] = []; @State private placed: number = 0;
  @State private cleared: number = 0; // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private life: number = 0;
  @State private score: number = 0; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GStoryBuilder')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }

  private reset(): void {
    this.picks = pickIndexes(BANK.length, STORIES);
    this.si = 0; this.cleared = 0; this.life = this.total; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.pressed = -1;
    this.startAt = Date.now(); this.load();
  }

  private load(): void {
    const st: Story = BANK[this.picks[this.si]];
    this.pool = pickIndexes(LINES, LINES).map((i: number) => st.lines[i]);
    this.placed = 0;
    this.msg = TG('按先后顺序，一句句接上');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：故事重建
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    if (this.over) {
      return true;
    }
    this.tap(this.placed);
    return !this.over;
  }

  /** 提示：直接报该点的位置 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.placed;
    return Hint.make([k],
      TG2('点第 {0} 个', String(k + 1)),
      TG2('Tap number {0}', String(k + 1)), t0);
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
    if (this.over || i < this.placed) { return; }
    if (i === this.placed) {
      this.placed = this.placed + 1; this.score = this.score + 100;
      this.msg = TG2("✅ 第 {0} 句归位", this.placed);
      if (this.placed >= LINES) { this.nextStory(); }
      return;
    }
    this.life = this.life - 1;
    this.msg = TG2("❌ 这句还不到时候，还剩 {0} 条命",Digits(String(this.life), this.langCode));
    if (this.life <= 0) { this.end(); }
  }

  private nextStory(): void {
    this.cleared = this.cleared + 1;
    if (this.cleared >= STORIES) { this.end(); return; }
    this.si = this.cleared; this.load();
    this.msg = TG2('👏 第 {0} 段接好了，继续下一段', this.cleared);
  }

  private end(): void {
    if (this.done) { return; }
    this.over = true;
    this.won = this.cleared >= STORIES && this.life > 0;
    this.msg = TG2("{0}接好 {1}/{2} 段故事", (this.won ? TG('🎉 通关：') : TG('💤 结束：')), this.cleared, STORIES);
    this.done = true;
    const r: GameResult = { gameId: 'story_builder', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cleared };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Text(TG2('段 {0}/{1}　已接 {2}', String(Math.min(this.si + 1, STORIES)), String(STORIES), String(this.placed))
          + TG2('/{0}　生命 {1}', String(LINES),Digits(String(this.life), this.langCode)))
          .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).layoutWeight(1)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(TG2('主题：{0}', BANK[this.picks[this.si]].title)).fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG('把句子按时间顺序点出来')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.pool, (line: string, i: number) => { this.lineTile(line, i) },
          (line: string, i: number) => 'l' + i + line)
      }.width('100%')
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
      Text(TG('提示：✅ 表示已归位，点错了要扣一条命')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  lineTile(line: string, i: number) {
    Row({ space: Space.sm }) {
      Text(i < this.placed ? '✅' : '＋').fontSize(FontSize.sm)
        .fontColor(i < this.placed ? Palette.emerald : this.theme.inkFaint)
      Text(line).fontSize(FontSize.md).layoutWeight(1).maxLines(2)
        .fontColor(i < this.placed ? this.theme.inkFaint : this.theme.ink)
    }.width('100%').padding(Space.sm).borderRadius(Radius.md).shadow(Shadow.card)
      .backgroundColor(i < this.placed ? this.theme.surfaceAlt : this.theme.surface).animation({ duration: Motion.fast, curve: Motion.snap() })
      .scale({ x: this.pressed === i ? Motion.pressScale : 1, y: this.pressed === i ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = i; } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
      })
      .onClick(() => { Haptics.tick(); this.tap(i); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
  }
}
