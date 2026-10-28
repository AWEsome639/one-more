/**
 * 阅读广度 —— 一句一句读并判断通不通顺，一组读完再按顺序回忆每句的关键词
 * 胜负：组长度 2 → 3 → 4 全部走通 ⇒ 通关；判断错或回忆错顺序 ⇒ 失败
 * 进度：组长度 / 记住几句 / 得分
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

interface Sent {
  text: string;
  ok: boolean;
  key: string;
}

const SENTS: Sent[] = [
  { text: '太阳从东边升起', ok: true, key: '太阳' }, { text: '鱼在树上打盹', ok: false, key: '鱼' },
  { text: '冬天下雪', ok: true, key: TG('冬天') }, { text: '石头会自己走路', ok: false, key: '石头' },
  { text: '春天花开', ok: true, key: '春天' }, { text: '猫会飞上天', ok: false, key: '猫' },
  { text: '海水是咸的', ok: true, key: '海水' }, { text: '火车在水底跑', ok: false, key: '火车' },
  { text: '小鸟会筑巢', ok: true, key: '小鸟' }, { text: '铅笔能写字', ok: true, key: TG('铅笔') },
  { text: '蚂蚁比大象重', ok: false, key: '蚂蚁' }, { text: '雨后常有彩虹', ok: true, key: '彩虹' }
];

const START_SPAN: number = 2;
const MAX_SPAN: number = 4;
const ROWS: number[] = [0, 1];
const COLS: number[] = [0, 1, 2];

@Component
export struct GReadingSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 START_SPAN=2，按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(2);
  onFinish: (r: GameResult) => void = () => {};
  @State phase: number = 0;        // 0 判断　1 回忆　2 结算
  @State span: number = this.diffTotal; @State pos: number = 0; @State got: number = 0;
  @State curText: string = ''; @State curOk: boolean = true; @State curKey: string = '';
  @State keys: string[] = []; @State pool: string[] = [];
  @State right: number = 0; @State score: number = 0; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private order: number[] = []; private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(2);
     this.reset(); }

  private shuffle(src: string[]): string[] {
    const out: string[] = src.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }

  private reset(): void {
    this.span = this.diffTotal; this.right = 0; this.score = 0; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newSet();
  }

  private newSet(): void {
    this.keys = []; this.pos = 0; this.got = 0; this.pool = []; this.phase = 0;
    const picked: number[] = [];
    while (picked.length < this.span) {
      const k: number = Math.floor(Math.random() * SENTS.length);
      if (picked.indexOf(k) < 0) { picked.push(k); }
    }
    this.order = picked;
    this.showSentence();
  }

  private showSentence(): void {
    const s: Sent = SENTS[this.order[this.pos]];
    this.curText = s.text; this.curOk = s.ok; this.curKey = s.key;
    this.msg = TG2("第 {0} / {1} 句：这句话通顺吗？", (this.pos + 1), this.span);
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
    if (this.phase === 0) {
      this.judge(this.curOk);
      return !this.over;
    }
    if (this.phase === 1) {
      const want: string = this.keys[this.got];
      for (let i = 0; i < this.pool.length; i++) {
        if (this.pool[i] === want) {
          this.pickPool(i);
          return !this.over;
        }
      }
    }
    return false;
  }

  /** 提示：判断阶段报「这句通不通」，回忆阶段报「下一个关键词」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 0) {
      return this.curOk
        ? Hint.make([], TG2('这句是通顺的：{0}', this.curText), TG2('This sentence makes sense: {0}', this.curText), t0)
        : Hint.make([], TG2('这句不通：「{0}」', this.curText), TG2('This sentence is wrong: {0}', this.curText), t0);
    }
    if (this.phase === 1) {
      const want: string = this.keys[this.got];
      return Hint.make([this.pool.indexOf(want)],
        TG2('第 {0} 个关键词是「{1}」', String(this.got + 1), want),
        TG2('Keyword {0} is "{1}"', String(this.got + 1), want), t0);
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

  private judge(sayOk: boolean): void {
    if (this.phase !== 0) { return; }
    const truth: boolean = this.curOk;
    if (sayOk !== truth) {
      this.end(false, '❌ 「' + this.curText + '」' + (truth ? '是通顺的' : '是不通的'));
      return;
    }
    this.right = this.right + 1; this.score = this.score + 30;
    this.keys = this.keys.concat([this.curKey]);
    this.pos = this.pos + 1;
    if (this.pos >= this.span) { this.beginRecall(); return; }
    this.showSentence();
  }

  private beginRecall(): void {
    this.phase = 1; this.got = 0;
    const pool: string[] = this.keys.slice();
    let extra: number = 0; let guard: number = 0;
    while (extra < 2 && guard < 80) {
      const cand: string = SENTS[Math.floor(Math.random() * SENTS.length)].key;
      if (pool.indexOf(cand) < 0) { pool.push(cand); extra = extra + 1; }
      guard = guard + 1;
    }
    this.pool = this.shuffle(pool);
    this.msg = TG('读完了，按出现顺序点出这些关键词');
  }

  private pickPool(i: number): void {
    if (this.phase !== 1 || this.pool[i] === '✔') { return; }
    const want: string = this.keys[this.got];
    if (this.pool[i] !== want) {
      this.end(false, TG('❌ 第 ') + (this.got + 1) + ' 个关键词应该是「' + want + '」');
      return;
    }
    const next: string[] = this.pool.slice();
    next[i] = '✔'; this.pool = next;
    this.got = this.got + 1; this.score = this.score + 40;
    if (this.got >= this.keys.length) {
      if (this.span >= MAX_SPAN) { this.end(true, TG2('✅ {0} 句的关键词全对',Digits(String(MAX_SPAN), this.langCode))); return; }
      this.span = this.span + 1; this.newSet();
      return;
    }
    this.msg = TG2('对，继续点第 {0} 个关键词', (this.got + 1));
  }

  private end(solved: boolean, note: string): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true; this.won = solved; this.phase = 2;
    this.msg = note + (solved ? '　🎉 通关' : '　💤 结束');
    const r: GameResult = { gameId: 'reading_span', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.span };
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
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('组长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.berry))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('记住'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.keys.length + ' / ' + this.span)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        if (this.phase === 0) {
          Text(this.curText).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).textAlign(TextAlign.Center)
        } else if (this.phase === 1) {
          Text(TG2('按顺序回忆第 {0} 个关键词', (this.got + 1))).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        } else {
          Text(this.won ? '🎉' : '🏁').fontSize(FontSize.hero)
        }
      }.width('100%').height(140).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      if (this.phase === 0) {
        Row({ space: Space.sm }) {
          Button((TG('✔ 通顺')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor((true) ? Palette.emerald : Palette.rose)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.phase === 0).onClick(() => { Haptics.tap(); this.judge((true)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge((true)); }); })
          Button((TG('✖ 不通')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor((false) ? Palette.emerald : Palette.rose)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.phase === 0).onClick(() => { Haptics.tap(); this.judge((false)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge((false)); }); })
        }.width('100%')
      } else if (this.phase === 1) {
        Column({ space: Space.sm }) {
          ForEach(ROWS, (row: number) => {
            Row({ space: Space.sm }) {
              ForEach(COLS, (col: number) => {
                if (row * 3 + col < this.pool.length) { Button(this.pool[(row * 3 + col)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.pool[(row * 3 + col)] === '✔' ? Palette.lime : Palette.berry)
                .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(this.pool[(row * 3 + col)] !== '✔').onClick(() => { Haptics.tap(); this.pickPool((row * 3 + col)); })
                .focusable(Tv.on())
                .focusBox(Tv.box())
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickPool((row * 3 + col)); }); }) }
              }, (col: number) => 'rc' + row + '_' + col)
            }.width('100%')
          }, (row: number) => 'rr' + row)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：先判断通不通顺，整组读完再按顺序回忆关键词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
