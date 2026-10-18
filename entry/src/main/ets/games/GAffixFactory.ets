/**
 * 词缀工厂 —— 给词根接上正确的词缀，造出符合中文释义的单词
 * 胜负：8 题答对 ≥6 ⇒ 通关｜进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 8; const PASS: number = 6; const FEED_MS: number = 800;

interface AffixQ { root: string; affix: string; meaning: string; opts: string[] }

const BANK: AffixQ[] = [
  { root: 'happy', affix: 'un-', meaning: '不快乐的', opts: ['un-', 're-', '-ful', '-less'] },
  { root: 'care', affix: '-ful', meaning: '小心的；关心的', opts: ['-less', '-ful', 'un-', '-ly'] },
  { root: 'hope', affix: '-less', meaning: '没有希望的', opts: ['-ful', '-less', 're-', '-ness'] },
  { root: 'write', affix: 're-', meaning: '重写', opts: ['re-', 'un-', '-er', 'dis-'] },
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
  @State private diffTotal: number = GameDiff.sizeNow(QN);
  onFinish: (r: GameResult) => void = () => {};

  @State queue: number[] = []; @State opts: string[] = [];
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State pickedOk: number = -1; @State lastPick: string = ''; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
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
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
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
        .onClick(() => { this.pick((o)); }) }, (o: string) => o)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('提示：un- / re- / dis- 走前面，-ful / -less / -ness 挂后面'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
