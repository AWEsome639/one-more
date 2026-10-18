/** 移一字母 —— 两个词只差一个字母：限时点出要换掉的那一位
 *  胜负：8 题答对 ≥5 ⇒ 通关 ｜ 进度：题号 / 答对 / 每题倒计时 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 8; const PASS: number = 5; const FEED_MS: number = 800;
const LIMIT_MS: number = 5000; const TICK_MS: number = 100;
interface WordPair { a: string; b: string; da: string; db: string }
const PAIRS: WordPair[] = [
  { a: 'MILK', b: 'SILK', da: '牛奶', db: '丝绸' }, { a: 'CAT', b: 'HAT', da: '猫', db: '帽子' },
  { a: 'HOUSE', b: 'MOUSE', da: '房子', db: '老鼠' }, { a: 'LIGHT', b: 'NIGHT', da: '光', db: '夜晚' },
  { a: 'TRAIN', b: 'BRAIN', da: '火车', db: '大脑' }, { a: 'SHEEP', b: 'SHEET', da: '绵羊', db: '床单' },
  { a: 'CLOUD', b: 'ALOUD', da: '云', db: '出声的' }, { a: 'PLANT', b: 'PLANE', da: '植物', db: '飞机' },
  { a: 'SNAKE', b: 'SHAKE', da: '蛇', db: '摇动' }, { a: 'HORSE', b: 'HOUSE', da: '马', db: '房子' },
  { a: 'WATER', b: 'WAFER', da: '水', db: '威化饼干' }, { a: 'TABLE', b: 'CABLE', da: '桌子', db: '电缆' },
  { a: 'GRAPE', b: 'DRAPE', da: '葡萄', db: '窗帘' }, { a: 'PEACH', b: 'PEACE', da: '桃子', db: '和平' },
  { a: 'CHAIR', b: 'CHAIN', da: '椅子', db: '链条' }, { a: 'HONEY', b: 'MONEY', da: '蜂蜜', db: '钱' },
  { a: 'TIGER', b: 'TIMER', da: TG('老虎'), db: '计时器' }, { a: 'STONE', b: 'STORE', da: '石头', db: '商店' },
  { a: 'BEACH', b: 'REACH', da: '海滩', db: '到达' }, { a: 'CANDY', b: 'HANDY', da: '糖果', db: '方便的' },
  { a: 'MOON', b: 'SOON', da: '月亮', db: '很快' }
];

@Component
export struct GOneLetterShift {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};
  @State q: WordPair = PAIRS[0]; @State qIndex: number = 0; @State right: number = 0;
  @State score: number = 0; @State leftMs: number = this.diffTotal; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false; @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop();
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.nextQ(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private nextQ(): void {
    this.q = PAIRS[Math.floor(Math.random() * PAIRS.length)];
    this.leftMs = this.diffTotal; this.roundAt = Date.now(); this.msg = TG('点出左边要换掉的那个字母');
  }
  private range(n: number): number[] {
    const out: number[] = [];
    for (let i = 0; i < n; i++) { out.push(i); }
    return out;
  }
  private diffAt(): number {
    const a: string = this.q.a; const b: string = this.q.b;
    for (let i = 0; i < a.length; i++) { if (a.charAt(i) !== b.charAt(i)) { return i; } }
    return 0;
  }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; }
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：第 {0} 位要换', String(this.diffAt() + 1)); this.advance(); }
  }
  private pick(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    if (i === this.diffAt()) {
      const gain: number = 100 + Math.floor(this.leftMs / 25);
      this.right = this.right + 1; this.score = this.score + gain;
      this.msg = '✅ ' + this.q.a + ' → ' + this.q.b + '　+' + String(gain);
    } else { this.msg = TG2('❌ 差在第 {0} 位：{1} → {2}', String(this.diffAt() + 1), this.q.a, this.q.b); }
    this.advance();
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.nextQ(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'one_letter_shift', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.violet))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          ForEach(this.range(this.q.a.length), (i: number) => {
            Text((this.q.a).charAt((i))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor((true) ? this.theme.ink : this.theme.inkFaint).layoutWeight(1).height(Cell.of(52))
            .backgroundColor((true) ? this.theme.surface : this.theme.surfaceAlt).borderRadius(Radius.sm)
            .scale({ x: (true) && this.pressed === (i) ? Motion.pressScale : 1, y: (true) && this.pressed === (i) ? Motion.pressScale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onTouch((e: TouchEvent) => {
            if (!(true)) { return; } else if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
            })
            .onClick(() => { if ((true)) { this.pick((i)); } })
          }, (i: number) => 'a' + i)
        }.width('100%')
        Text(this.q.da).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Row({ space: Space.xs }) {
          ForEach(this.range(this.q.b.length), (i: number) => {
            Text((this.q.b).charAt((i))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor((false) ? this.theme.ink : this.theme.inkFaint).layoutWeight(1).height(Cell.of(52))
            .backgroundColor((false) ? this.theme.surface : this.theme.surfaceAlt).borderRadius(Radius.sm)
            .scale({ x: (false) && this.pressed === (i) ? Motion.pressScale : 1, y: (false) && this.pressed === (i) ? Motion.pressScale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onTouch((e: TouchEvent) => {
            if (!(false)) { return; } else if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
            })
            .onClick(() => { if ((false)) { this.pick((i)); } })
          }, (i: number) => 'b' + i)
        }.width('100%')
        Text(this.q.db).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { this.reset(); })
      Text(TG('提示：换掉一个字母就变成另一个词，位置就是两词不一样的地方'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
