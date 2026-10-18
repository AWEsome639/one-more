/** 混合词拆分 —— 合成词由哪两个词拼成？（6 题答对 ≥4 通关 ｜ 进度：题号/答对/倒计时） */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 6; const PASS: number = 4; const FEED_MS: number = 1000;
const LIMIT_MS: number = 10000; const TICK_MS: number = 100;
interface Blend { word: string; def: string; a: string; b: string; d1: string; d2: string }
interface BlendRound { word: string; def: string; a: string; b: string; opts: string[] }
const BANK: Blend[] = [
  { word: 'SMOG', def: '烟雾', a: 'SMOKE', b: 'FOG', d1: 'SMOOTH', d2: 'FROST' },
  { word: 'BRUNCH', def: '早午餐', a: 'BREAKFAST', b: 'LUNCH', d1: 'DINNER', d2: 'BUNCH' },
  { word: 'MOTEL', def: '汽车旅馆', a: 'MOTOR', b: 'HOTEL', d1: 'MOTIVE', d2: 'HOSTEL' },
  { word: 'SPORK', def: '叉勺', a: 'SPOON', b: 'FORK', d1: 'SPORT', d2: 'CORK' },
  { word: 'BLOG', def: '博客', a: 'WEB', b: 'LOG', d1: 'GLOBE', d2: 'BOG' },
  { word: 'CHORTLE', def: '咯咯笑', a: 'CHUCKLE', b: 'SNORT', d1: 'CHORUS', d2: 'TURTLE' },
  { word: 'EMOTICON', def: '颜文字', a: 'EMOTION', b: 'ICON', d1: 'EMOTIVE', d2: 'TONIC' },
  { word: 'PIXEL', def: '像素', a: 'PICTURE', b: 'ELEMENT', d1: 'PIXIE', d2: 'EXCEL' },
  { word: 'CYBORG', def: '半机械人', a: 'CYBERNETIC', b: 'ORGANISM', d1: 'CYPRESS', d2: 'ORGAN' }
];
function shuffled(arr: string[]): string[] {
  const out: string[] = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: string = out[i]; out[i] = out[j]; out[j] = tmp;
  }
  return out;
}
function makeRound(): BlendRound {
  const pick: Blend = BANK[Math.floor(Math.random() * BANK.length)];
  return { word: pick.word, def: pick.def, a: pick.a, b: pick.b,
    opts: shuffled([pick.a, pick.b, pick.d1, pick.d2]) };
}

@Component
export struct GPortmanteauSplit {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};
  @State q: BlendRound = makeRound(); @State sel: number[] = []; @State qIndex: number = 0;
  @State right: number = 0; @State score: number = 0; @State leftMs: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop();
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.nextQ(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private nextQ(): void {
    this.q = makeRound(); this.sel = []; this.leftMs = this.diffTotal; this.roundAt = Date.now();
    this.msg = TG('选出拼成它的两个词');
  }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; } const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：{0} + {1}', this.q.a, this.q.b); this.advance(); }
  }
  private tap(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    const at: number = this.sel.indexOf(i);
    if (at >= 0) { this.sel = this.sel.slice(0, at).concat(this.sel.slice(at + 1)); return; }
    if (this.sel.length >= 2) { return; }
    const next: number[] = this.sel.concat([i]);
    this.sel = next;
    if (next.length === 2) { this.check(); }
  }
  private check(): void {
    const picked: string[] = [];
    for (let i = 0; i < this.sel.length; i++) { picked.push(this.q.opts[this.sel[i]]); }
    if (picked.indexOf(this.q.a) >= 0 && picked.indexOf(this.q.b) >= 0) {
      const gain: number = 120 + Math.floor(this.leftMs / 35);
      this.right = this.right + 1; this.score = this.score + gain;
      this.msg = '✅ ' + this.q.word + ' = ' + this.q.a + ' + ' + this.q.b + '　+' + String(gain);
      this.advance();
      return;
    }
    this.msg = TG2('❌ 这两个合不出 {0}，再想想', this.q.word); this.sel = [];
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1; if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.nextQ(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'portmanteau_split', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.orange))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.q.word).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.orange)
        Text(this.q.def).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        Text(TG2('已选 {0}/2', String(this.sel.length))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        Text(this.q.opts.length > (0) ? this.q.opts[(0)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((0)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((0)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (0) ? Motion.pressScale : 1, y: this.pressed === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (0); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { this.tap((0)); })
        Text(this.q.opts.length > (1) ? this.q.opts[(1)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((1)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((1)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (1) ? Motion.pressScale : 1, y: this.pressed === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (1); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { this.tap((1)); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Text(this.q.opts.length > (2) ? this.q.opts[(2)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((2)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((2)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (2) ? Motion.pressScale : 1, y: this.pressed === (2) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (2); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { this.tap((2)); })
        Text(this.q.opts.length > (3) ? this.q.opts[(3)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((3)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((3)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (3) ? Motion.pressScale : 1, y: this.pressed === (3) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (3); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { this.tap((3)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
