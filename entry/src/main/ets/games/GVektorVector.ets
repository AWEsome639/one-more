/**
 * 向量运算 —— 给出两个平面向量，算 a ± b，从四个候选里选出正确分量
 * 胜负：8 题拿满 600 分以上 ⇒ 通关；进度：题号 / 得分 / 用时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 8;
const NEED: number = 600;

interface VecPair { ax: number; ay: number; bx: number; by: number; }
interface VecChoice { x: number; y: number; ok: boolean; }
const SLOTS: number[] = [0, 1, 2, 3];

function fmt(n: number): string { return n < 0 ? '−' + String(-n) : String(n); }

@Component
export struct GVektorVector {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private cur: VecPair = { ax: 3, ay: 2, bx: 1, by: 4 };
  @State private plus: boolean = true;
  @State private opts: VecChoice[] = [];
  @State private round: number = 1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  @State private clock: number = 0;
  @State private pick: number = -1;
  private startAt: number = 0;
  private timer: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.round = 1; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.msg = ''; this.clock = 0; this.startAt = Date.now();
    this.nextRound();
    this.timer = setInterval(() => { if (!this.over) { this.clock = this.clock + 1; } }, 1000);
  }
  private trueAns(): VecChoice {
    return {
      x: this.plus ? this.cur.ax + this.cur.bx : this.cur.ax - this.cur.bx,
      y: this.plus ? this.cur.ay + this.cur.by : this.cur.ay - this.cur.by, ok: true
    };
  }
  /** 造 4 个候选（含正确答案），打乱后展示 */
  private nextRound(): void {
    this.pick = -1;
    this.plus = Math.random() < 0.5;
    this.cur = {
      ax: 1 + Math.floor(Math.random() * 8), ay: 1 + Math.floor(Math.random() * 8),
      bx: 1 + Math.floor(Math.random() * 8), by: 1 + Math.floor(Math.random() * 8)
    };
    const tru: VecChoice = this.trueAns();
    const pool: VecChoice[] = [tru];
    while (pool.length < 4) {
      const cand: VecChoice = {
        x: tru.x + Math.floor(Math.random() * 5) - 2,
        y: tru.y + Math.floor(Math.random() * 5) - 2, ok: false
      };
      if (cand.x === tru.x && cand.y === tru.y) { continue; }
      let dup: boolean = false;
      for (let i = 0; i < pool.length; i++) {
        if (pool[i].x === cand.x && pool[i].y === cand.y) { dup = true; }
      }
      if (!dup) { pool.push(cand); }
    }
    const mixed: VecChoice[] = [];
    while (pool.length > 0) { mixed.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
    this.opts = mixed;
  }
  /** 提示：哪个选项是对的（代打就是找 opts[i].ok） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        return Hint.make([i],
          TG2('答案是第 {0} 个', String(i + 1)),
          TG2('The answer is option {0}', String(i + 1)), t0);
      }
    }
    // ★ 找不到 ok ⇒ 不是"算不出"，是"还没出题"：明确告诉玩家等一等
    return Hint.make([],
      TG('还没出题，等一下再点'),
      TG('Not dealt yet — try again in a moment'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 选项对象自带对错：opts[i].ok ｜ 守卫取自它自己的第一道 if
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
    if (this.over || this.pick >= 0) {
      return true;
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        this.answer(i);
        return true;
      }
    }
    return false;
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

  private answer(i: number): void {
    if (this.over || this.pick >= 0) { return; }
    this.pick = i;
    if (this.opts[i].ok) {
      this.score += 100 + Math.max(0, 40 - this.clock); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG('✅ 对了！');
    } else {
      const t: VecChoice = this.trueAns();
      this.msg = TG2('❌ 正确答案是 ({0}, {1})', fmt(t.x), fmt(t.y));
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.over = true;
        this.won = this.score >= NEED;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("得分 {0}",Digits(String(this.score), this.langCode));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.nextRound();
    }, 680);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'vektor_vector', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('题目'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.clock + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Column({ space: Space.sm }) {
        Text(this.plus ? 'a + b = ?' : 'a − b = ?').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
        Row({ space: Space.sm }) {
        Text(('a')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .width(34).height(Cell.of(34)).textAlign(TextAlign.Center).backgroundColor((Palette.emerald)).borderRadius(Radius.sm)
        Text('(' + fmt((this.cur.ax)) + ', ' + fmt((this.cur.ay)) + ')').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.width('100%')
        Row({ space: Space.sm }) {
        Text(('b')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .width(34).height(Cell.of(34)).textAlign(TextAlign.Center).backgroundColor((Palette.amber)).borderRadius(Radius.sm)
        Text('(' + fmt((this.cur.bx)) + ', ' + fmt((this.cur.by)) + ')').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.width('100%')
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) { Text('(' + fmt(this.opts[(0)].x) + ', ' + fmt(this.opts[(0)].y) + ')')
      .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(56))
      .backgroundColor(this.pick === (0) ? Palette.primaryDeep : this.theme.surfaceAlt).borderRadius(Radius.md)
      .shadow(Shadow.card).scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((0)); }); Text('(' + fmt(this.opts[(1)].x) + ', ' + fmt(this.opts[(1)].y) + ')')
      .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(56))
      .backgroundColor(this.pick === (1) ? Palette.primaryDeep : this.theme.surfaceAlt).borderRadius(Radius.md)
      .shadow(Shadow.card).scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((1)); }) }.width('100%')
      Row({ space: Space.sm }) { Text('(' + fmt(this.opts[(2)].x) + ', ' + fmt(this.opts[(2)].y) + ')')
      .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(56))
      .backgroundColor(this.pick === (2) ? Palette.primaryDeep : this.theme.surfaceAlt).borderRadius(Radius.md)
      .shadow(Shadow.card).scale({ x: this.pick === (2) ? Motion.pressScale : 1, y: this.pick === (2) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((2)); }); Text('(' + fmt(this.opts[(3)].x) + ', ' + fmt(this.opts[(3)].y) + ')')
      .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(56))
      .backgroundColor(this.pick === (3) ? Palette.primaryDeep : this.theme.surfaceAlt).borderRadius(Radius.md)
      .shadow(Shadow.card).scale({ x: this.pick === (3) ? Motion.pressScale : 1, y: this.pick === (3) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((3)); }) }.width('100%')
      Text(this.msg.length > 0 ? this.msg : '选一个正确答案').fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：a − b 是逐分量相减，符号别弄反')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}