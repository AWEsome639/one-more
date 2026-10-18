/**
 * 类别流畅 —— 限时列举同类词：打字回车提交，重复与词库外的都不算分
 * 胜负：4 个类别共列出 ≥8 个有效词 ⇒ 通关｜进度：类别 / 已列 / 剩余秒数
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const CAT_N: number = 4; const PASS: number = 8;
const LIMIT_S: number = 25; const TICK_MS: number = 1000;

interface Cat { name: string; words: string[] }

const CATS: Cat[] = [
  { name: '水果', words: [TG('苹果'), TG('香蕉'), '橙子', '葡萄', '西瓜', '草莓', '梨', '桃子',
    '芒果', '菠萝', '柚子', '蓝莓', '樱桃', '柠檬', '石榴', '火龙果'] },
  { name: '动物', words: [TG('老虎'), '大象', '熊猫', '猴子', '兔子', '狮子', '长颈鹿', '斑马',
    '企鹅', '鲸鱼', '海豚', '狐狸', '骆驼', '松鼠', '乌龟', '孔雀'] },
  { name: '颜色', words: ['红色', '蓝色', '绿色', '黄色', '紫色', '橙色', '黑色', '白色',
    '灰色', '粉色', '棕色', '青色', '金色', '银色', '米色', '靛蓝'] },
  { name: '交通工具', words: ['汽车', '火车', '飞机', '轮船', '自行车', '地铁', '公交车', '摩托车',
    '直升机', '热气球', '卡车', '帆船', '潜艇', '电车', '三轮车', '滑板'] }
];

@Component
export struct GCategoryFluency {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_S 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_S);
  onFinish: (r: GameResult) => void = () => {};

  @State catIdx: number = 0; @State input: string = ''; @State used: string[] = [];
  @State total: number = 0; @State score: number = 0; @State leftS: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  @State private k: number = 1;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;
  private lastCatAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_S);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  /** ★ 2026-10-14 动画补齐：进度/得分脉冲（本款原来一处 .animation() 都没有） */
  private bumpK(): void {
    this.k = 1.16;
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.k = 1; });
  }

  private reset(): void {
    this.stop();
    this.catIdx = 0; this.input = ''; this.used = []; this.total = 0; this.score = 0;
    this.leftS = this.diffTotal; this.over = false; this.won = false; this.done = false;
    this.msg = TG2('第一类：{0} —— 越快越多越好', CATS[0].name);
    this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private cat(): Cat { return CATS[this.catIdx < CAT_N ? this.catIdx : CAT_N - 1]; }
  private tick(): void {
    if (this.over) { return; }
    this.leftS = this.leftS - 1;
    if (this.leftS <= 0) { this.nextCat(); }
  }
  private submit(): void {
    if (this.over) { return; }
    const w: string = this.input.trim();
    this.input = '';
    if (w.length === 0) { return; }
    if (this.used.indexOf(w) >= 0) { this.msg = TG2('🔁 「{0}」已经列过啦', w); return; }
    if (this.cat().words.indexOf(w) < 0) { this.msg = TG2('🤔 词库里没有「{0}」，换一个', w); return; }
    this.used = this.used.concat([w]);
    this.total = this.total + 1; this.score = this.score + 60;
    this.bumpK();
    this.msg = TG2("✅ {0} —— 本类已列 {1} 个", w, this.used.length);
  }
  private nextCat(): void {
    if (Date.now() - this.lastCatAt < 500) { return; }
    this.lastCatAt = Date.now();
    this.catIdx = this.catIdx + 1; this.used = [];
    if (this.catIdx >= CAT_N) { this.end(); return; }
    this.leftS = this.diffTotal; this.msg = TG2('下一类：{0}', this.cat().name);
  }
  private end(): void {
    this.stop();
    this.over = true; this.won = this.total >= PASS;
    this.msg = TG2("{0}共列出 {1} 个有效词", (this.won ? TG('🎉 通关：') : TG('💤 结束：')), this.total);
    this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'category_fluency', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.total };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('类别'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.catIdx + 1, CAT_N) + '/' + CAT_N)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.lime))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已列'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.total), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        .scale({ x: this.k, y: this.k })
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.leftS + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.over ? '本轮结束' : this.cat().name).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
        Text(TG('严格属于这一类的词，打出来按回车')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: TG2('输入「{0}」类的一个词', this.cat().name)})
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(46)).padding({ left: Space.sm, right: Space.sm })
          .onChange((v: string) => { this.input = v; })
          .onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.lime)
          .borderRadius(Radius.md).width(84).height(Cell.of(46))
          .enabled(!this.over).onClick(() => { this.submit(); })
      }.width('100%')
      Text(this.used.length > 0 ? this.used.join(' · ') : '（还没列出来）')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Button(TG('换下一类'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).enabled(!this.over)
          .onClick(() => { this.nextCat(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { this.reset(); })
      }.width('100%')
      Text(TG2('提示：每类 {0} 秒，共列 {1} 个有效词即通关（词库有限，常见词优先）',Digits(String(this.diffTotal), this.langCode), PASS))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
