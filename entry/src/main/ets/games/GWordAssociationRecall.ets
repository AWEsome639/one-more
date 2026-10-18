/**
 * 词汇联想 —— 先记 6 组「词—关联词」，再凭记忆把每个词和它的关联词配回来
 * 胜负：6 题里回忆对 ≥ 4 题通关 ｜ 进度：第几题 / 回忆对数 / 剩余秒 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

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
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
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
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { this.reset(); })
      }.width('100%')
      Text(TG('提示：只考记忆时间里的那 6 组')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
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
      .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { this.tap(i); })
  }
}
