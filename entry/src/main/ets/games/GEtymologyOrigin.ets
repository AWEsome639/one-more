/**
 * 词源探源 —— 看英语单词猜它借自哪门语言
 * 胜负：60 秒内答对 ≥8 通关｜答错扣 3 秒，错满 4 次判负　｜　进度：答对 / 失误 / 倒计时
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

const LIMIT_MS: number = 60000; const TICK_MS: number = 100;
const MAX_WRONG: number = 4; const PASS: number = 8; const PENALTY_MS: number = 3000;

interface EtyQ { word: string; cn: string; lang: string; opts: string[] }

const BANK: EtyQ[] = [
  { word: 'ALGEBRA', cn: TG('代数'), lang: TG('阿拉伯语'), opts: [TG('阿拉伯语'), '希腊语', '拉丁语', '法语'] },
  { word: 'SAUNA', cn: '桑拿浴', lang: '芬兰语', opts: ['芬兰语', '瑞典语', '俄语', '德语'] },
  { word: 'TSAR', cn: '沙皇', lang: '俄语', opts: ['俄语', '拉丁语', '德语', '波兰语'] },
  { word: 'TYCOON', cn: '企业大亨', lang: '日语', opts: ['日语', TG('汉语'), '韩语', '英语'] },
  { word: 'PYJAMAS', cn: '睡衣裤', lang: TG('印地语'), opts: [TG('印地语'), '波斯语', TG('阿拉伯语'), '梵语'] },
  { word: 'COFFEE', cn: '咖啡', lang: TG('阿拉伯语'), opts: [TG('阿拉伯语'), '法语', '拉丁语', '土耳其语'] },
  { word: 'TYPHOON', cn: '台风', lang: '希腊语', opts: ['希腊语', TG('汉语'), TG('阿拉伯语'), '马来语'] },
  { word: 'KETCHUP', cn: '番茄酱', lang: TG('汉语'), opts: [TG('汉语'), '马来语', '英语', '荷兰语'] },
  { word: 'SHAMPOO', cn: '洗发水', lang: TG('印地语'), opts: [TG('印地语'), TG('阿拉伯语'), '梵语', '波斯语'] },
  { word: 'KARAOKE', cn: '卡拉OK', lang: '日语', opts: ['日语', TG('汉语'), '韩语', '英语'] },
  { word: 'PIANO', cn: '钢琴', lang: '意大利语', opts: ['意大利语', '法语', '拉丁语', '西班牙语'] },
  { word: 'ROBOT', cn: '机器人', lang: '捷克语', opts: ['捷克语', '德语', '英语', '波兰语'] },
  { word: 'SAFARI', cn: '野外游猎', lang: '斯瓦希里语', opts: ['斯瓦希里语', TG('阿拉伯语'), '葡萄牙语', TG('印地语')] },
  { word: 'CHOCOLATE', cn: '巧克力', lang: '纳瓦特尔语', opts: ['纳瓦特尔语', '西班牙语', '法语', '玛雅语'] },
  { word: 'YOGURT', cn: '酸奶', lang: '土耳其语', opts: ['土耳其语', '希腊语', TG('阿拉伯语'), '保加利亚语'] }
];

function shuffleStr(arr: string[]): string[] {
  const out: string[] = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GEtymologyOrigin {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State qIdx: number = 0; @State opts: string[] = [];
  @State right: number = 0; @State wrong: number = 0; @State score: number = 0;
  @State leftMs: number = this.diffTotal; @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private roundAt: number = 0;
  private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GEtymologyOrigin')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }
  private reset(): void {
    this.stop();
    this.qIdx = Math.floor(Math.random() * BANK.length);
    this.right = 0; this.wrong = 0; this.score = 0; this.leftMs = this.diffTotal;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('这个单词是从哪门语言借来的？'); this.startAt = Date.now(); this.roundAt = Date.now();
    this.load();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private load(): void { this.opts = shuffleStr(BANK[this.qIdx].opts); }
  private tick(): void {
    if (this.over) { return; }
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) {
      this.over = true; this.won = false; this.msg = TG2("⌛ 时间到 —— 共答对 {0} 个", this.right);
      this.finish(false);
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (this.over) {
      return true;
    }
    this.answer(BANK[this.qIdx].lang);
    return !this.over;
  }

  /** 提示：直接报语源 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const a: string = BANK[this.qIdx].lang;
    return Hint.make([], TG2('语源是「{0}」', a),
      TG2('The origin is {0}', a), t0);
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

  private answer(sel: string): void {
    if (this.over) { return; }
    if (sel === BANK[this.qIdx].lang) {
      this.right = this.right + 1; this.score = this.score + 120; this.msg = '✅ ' + BANK[this.qIdx].word + ' ← ' + sel;
      if (this.right >= PASS) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 通关：答对 {0} 个",Digits(String(this.right), this.langCode));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
    } else {
      this.wrong = this.wrong + 1; this.msg = TG2('❌ 它其实来自 {0}', BANK[this.qIdx].lang);
      const keep: number = this.leftMs - PENALTY_MS > 800 ? this.leftMs - PENALTY_MS : 800;
      this.leftMs = keep; this.roundAt = Date.now() - (this.diffTotal - keep);
      if (this.wrong >= MAX_WRONG) {
        this.over = true; this.won = false;
        this.finish(false);
        return;
      }
    }
    this.qIdx = (this.qIdx + 1) % BANK.length;
    this.load();
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'etymology_origin', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
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
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.wrong + ' / ' + MAX_WRONG)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('这个词借自？')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(BANK[this.qIdx].word).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(BANK[this.qIdx].cn).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Button((0) < this.opts.length ? this.opts[(0)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.answer(this.opts[(0)]); })
          Button((1) < this.opts.length ? this.opts[(1)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.answer(this.opts[(1)]); })
        }.width('100%')
        Row({ space: Space.sm }) {
          Button((2) < this.opts.length ? this.opts[(2)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.answer(this.opts[(2)]); })
          Button((3) < this.opts.length ? this.opts[(3)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.answer(this.opts[(3)]); })
        }.width('100%')
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2("答对 {0} 个通关；答错扣 3 秒，错满 {1} 次结束", PASS,Digits(String(MAX_WRONG), this.langCode))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
