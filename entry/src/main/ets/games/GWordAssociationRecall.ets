/**
 * 词汇联想 —— 先记 6 组「词—关联词」，再凭记忆把每个词和它的关联词配回来
 * 胜负：6 题里回忆对 ≥ 4 题通关 ｜ 进度：第几题 / 回忆对数 / 剩余秒 / 得分
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

const SETS: number = 6; const PASS: number = 4; const STUDY_MS: number = 9000;
const Q_MS: number = 8000; const TICK_MS: number = 100; const FEED_MS: number = 800;

interface Pair { cue: string; mate: string }
interface Opt { text: string; ok: boolean }

const PAIRS: Pair[] = [
  { cue: '医生 👨‍⚕️', mate: '医院 🏥' }, { cue: '蜜蜂 🐝', mate: '蜂蜜 🍯' }, { cue: '下雨 🌧️', mate: '雨伞 ☂️' },
  { cue: '小鱼 🐟', mate: '河水 💧' }, { cue: '冬天 ❄️', mate: '雪人 ⛄' }, { cue: '钥匙 🔑', mate: '门锁 🔒' },
  { cue: '月亮 🌙', mate: '夜晚 🌃' }, { cue: '铅笔 ✏️', mate: '白纸 📄' }, { cue: '厨房 🍳', mate: '厨师 👨‍🍳' },
  { cue: '书本 📚', mate: '书架 🗄️' } ];

/** 从 0..total-1 中随机取 k 个互不相同的下标（k=total 就是整段洗牌） */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

@Component
export struct GWordAssociationRecall {
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
  @State private study: number[] = []; @State private order: number[] = [];
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  @State private qi: number = 0; @State private opts: Opt[] = [];
  @State private right: number = 0; @State private score: number = 0;
  // ★ 难度作用到玩法（本局时长按难度换算）
  private total: number = GameDiff.timeNow(STUDY_MS);
  @State private leftMs: number = 0; @State private phase: number = 0;
  @State private picked: number = -1; @State private locked: boolean = false;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;

  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordAssociationRecall')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(STUDY_MS);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }
  /** 当前第 qi 题考的是 study 里的第 order[qi] 组 */
  private pairIdx(): number { return this.study[this.order[this.qi]]; }
  private reset(): void {
    this.stop();
    this.study = pickIndexes(PAIRS.length, SETS); this.order = pickIndexes(SETS, SETS);
    this.qi = 0; this.right = 0; this.score = 0; this.picked = -1; this.locked = false;
    this.phase = 0; this.over = false; this.won = false; this.done = false;
    this.leftMs = this.total; this.msg = TG(TG('记住每一组搭配，9 秒后开始回忆'));
    this.startAt = Date.now(); this.roundAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private loadQuestion(): void {
    const idx: number = this.pairIdx();
    const raw: Opt[] = [{ text: PAIRS[idx].mate, ok: true }];
    const others: number[] = this.study.filter((p: number) => p !== idx);
    const seq: number[] = pickIndexes(others.length, 3);
    for (let i = 0; i < seq.length; i++) { raw.push({ text: PAIRS[others[seq[i]]].mate, ok: false }); }
    this.opts = pickIndexes(raw.length, raw.length).map((k: number) => raw[k]);
    this.picked = -1; this.locked = false; this.leftMs = Q_MS; this.roundAt = Date.now();
    this.msg = TG(TG('它刚才和谁配成一对？'));
  }
  private tick(): void {
    if (this.over) { return; }
    const gap: number = Date.now() - this.roundAt;
    const limit: number = this.phase === 0 ? STUDY_MS : Q_MS;
    if (gap < limit) { this.leftMs = limit - gap; return; }
    if (this.leftMs === 0) { return; }
    this.leftMs = 0;
    if (this.phase === 0) { this.phase = 1; this.qi = 0; this.loadQuestion(); return; }
    if (this.locked) { return; }
    this.locked = true; this.msg = TG2('⏰ 没想起来，它配的是 {0}', PAIRS[this.pairIdx()].mate);
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, FEED_MS);
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
          TG2('选「{0}」', this.opts[i].text),
          TG2('Pick "{0}"', this.opts[i].text), t0);
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
    if (this.over || this.locked || this.phase === 0) {
      return true;
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        this.tap(i);
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

  private tap(i: number): void {
    if (this.over || this.locked || this.phase === 0) { return; }
    this.locked = true; this.picked = i;
    if (this.opts[i].ok) { this.right = this.right + 1; this.score = this.score + 150; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.msg = TG(TG('✅ 配对了')); }
    else { this.msg = TG('❌ 应该是 ') + PAIRS[this.pairIdx()].mate; }
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, FEED_MS);
  }
  private next(): void {
    if (this.qi + 1 >= SETS) { this.end(); return; }
    this.qi = this.qi + 1; this.loadQuestion();
  }
  private end(): void {
    this.stop();
    if (this.done) { return; }
    this.done = true; this.over = true; this.phase = 2; this.won = this.right >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("回忆对 {0}/{1}", this.right, SETS);
    const r: GameResult = { gameId: 'word_association_recall', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Text(TG2("{0}　回忆对 {1}", (this.phase === 0 ? '记忆 ' : TG('题 ') + Math.min(this.qi + 1, SETS) + '/' + SETS), this.right)).fontSize(FontSize.xs).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
          .fontColor(this.theme.inkSoft).layoutWeight(1)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(this.phase === 1 ? '回忆' : '记忆时间').fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.phase === 1 ? PAIRS[this.pairIdx()].cue : '把 6 组搭配记牢').fontSize(FontSize.xl)
          .fontWeight(FontWeight.Bold).fontColor(Palette.berry)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      if (this.phase !== 1) {
        Column({ space: Space.xs }) {
          ForEach(this.study, (p: number) => { this.pairRow(p) }, (p: number) => 's' + p)
        }.width('100%')
      } else {
        Column({ space: Space.sm }) {
          ForEach(this.opts, (o: Opt, i: number) => { this.option(o, i) }, (o: Opt, i: number) => 'w' + i + o.text)
        }.width('100%')
      }
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
      Text(TG('提示：只考记忆时间里的那 6 组')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  pairRow(p: number) {
    Row({ space: Space.sm }) {
      Text(PAIRS[p].cue).fontSize(FontSize.md).layoutWeight(1).fontColor(this.theme.ink)
      Text('→').accessibilityText(TG('指向')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        .accessibilityLevel('no')
      Text(PAIRS[p].mate).fontSize(FontSize.md).layoutWeight(1).textAlign(TextAlign.End).fontColor(Palette.berry)
    }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
  }
  @Builder
  option(o: Opt, i: number) {
    Text(o.text).fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      .fontColor(this.locked && (this.picked === i || o.ok) ? '#FFFFFF' : this.theme.ink)
      .width('100%').height(Cell.of(48)).borderRadius(Radius.md).shadow(Shadow.card)
      .backgroundColor(this.locked && o.ok
        ? Palette.emerald : (this.locked && this.picked === i ? Palette.rose : this.theme.surface))
      .scale({ x: this.picked === i ? Motion.pressScale : 1, y: this.picked === i ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap(i); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
  }
}
