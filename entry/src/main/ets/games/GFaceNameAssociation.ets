/**
 * 人名配对 —— 先记 6 张脸的名字，再逐一配对
 * 胜负：6 题答对 ≥ 5 ⇒ 通关；进度：记脸倒计时 / 题号 / 答对数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';

interface FaceItem { icon: string; name: string; }
interface NameChoice { label: string; ok: boolean; }

const POOL: FaceItem[] = [
  { icon: '🧑‍🚀', name: '阿航' }, { icon: '👩‍🍳', name: '苏眉' }, { icon: '🧑‍🎨', name: '林拓' },
  { icon: '👨‍🔬', name: '周原' }, { icon: '🧝', name: '白芨' }, { icon: '🧛', name: '黎夜' },
  { icon: '👩‍🌾', name: '陶然' }, { icon: '🧑‍✈️', name: '陈风' }, { icon: '🤠', name: '韦岚' },
  { icon: '🧜', name: '海玥' }, { icon: '👨‍🚒', name: '石敢' }, { icon: '👩‍⚕️', name: '温言' }
];
const ROUNDS: number = 6;
const SHOW_SEC: number = 5;
const NEED: number = 5;

@Component
export struct GFaceNameAssociation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private faces: FaceItem[] = [];
  @State private opts: NameChoice[] = [];
  @State private phase: number = 0;      // 0 记脸 1 作答 2 结束
  @State private askNo: number = 1;
  @State private rightN: number = 0;
  @State private pick: number = -1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(SHOW_SEC);
  @State private secLeft: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(SHOW_SEC);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    const bag: FaceItem[] = [];
    while (bag.length < ROUNDS) {
      const cand: FaceItem = POOL[Math.floor(Math.random() * POOL.length)];
      let dup: boolean = false;
      for (let i = 0; i < bag.length; i++) { if (bag[i].name === cand.name) { dup = true; } }
      if (!dup) { bag.push(cand); }
    }
    this.faces = bag;                      // 顺序本身随机，直接当出题顺序
    this.phase = 0; this.askNo = 1; this.rightN = 0; this.pick = -1; this.secLeft = this.total;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('记住每张脸对应的人名');
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (this.phase !== 0) { return; }
      this.secLeft = this.secLeft - 1;
      if (this.secLeft <= 0) { this.startQuiz(); }
    }, 1000);
  }

  private startQuiz(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.phase = 1;
    this.msg = TG('从下面选一个名字');
    this.loadQuestion();
  }

  private loadQuestion(): void {
    const target: FaceItem = this.faces[this.askNo - 1];
    const pool: NameChoice[] = [{ label: target.name, ok: true }];
    while (pool.length < 4) {
      const cand: FaceItem = POOL[Math.floor(Math.random() * POOL.length)];
      if (cand.name === target.name) { continue; }
      let dup: boolean = false;
      for (let i = 0; i < pool.length; i++) { if (pool[i].label === cand.name) { dup = true; } }
      if (!dup) { pool.push({ label: cand.name, ok: false }); }
    }
    const mixed: NameChoice[] = [];
    while (pool.length > 0) { mixed.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
    this.opts = mixed;
    this.pick = -1;
  }

  private answer(i: number): void {
    if (this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = i;
    if (this.opts[i].ok) { this.rightN = this.rightN + 1; this.msg = TG('✅ 配对成功'); }
    else { this.msg = TG2('❌ 他叫 {0}', this.faces[this.askNo - 1].name); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.askNo >= ROUNDS) { this.judge(); return; }
      this.askNo = this.askNo + 1;
      this.msg = TG('从下面选一个名字');
      this.loadQuestion();
    }, 760);
  }

  private judge(): void {
    this.phase = 2; this.over = true; this.won = this.rightN >= NEED;
    this.msg = TG2(this.won ? '🎉 通关！答对 {0}/{1}' : '💤 结束，答对 {0}/{1}',Digits(String(this.rightN), this.langCode),Digits(String(ROUNDS), this.langCode));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'face_name_association', solved: this.won, score: this.rightN * 100,
        durationMs: Date.now() - this.startAt, levelReached: this.rightN
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? '记脸' : (this.over ? TG('结束') : '作答'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.over ? ROUNDS : this.askNo) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.rightN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      if (this.phase === 0) {
        Column({ space: Space.sm }) {
          Text(TG2('⏳ {0} 秒后开始提问',Digits(String(this.secLeft), this.langCode)))
            .fontSize(FontSize.sm).fontColor(Palette.amber).width('100%').textAlign(TextAlign.Center)
          ForEach([0, 1], (row: number) => {
            Row({ space: Space.sm }) {
              ForEach([0, 1, 2], (col: number) => {
                Column({ space: Space.xs }) {
                  Text(this.faces[row * 3 + col].icon).fontSize(FontSize.xxl)
                  Text(this.faces[row * 3 + col].name).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
                }.layoutWeight(1).padding(Space.sm)
                .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
              }, (col: number) => 'c' + col + this.faces[row * 3 + col].name)
            }.width('100%')
          }, (row: number) => 'r' + row)
        }.width('100%').padding(Space.md)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      } else if (this.phase === 1) {
        Column({ space: Space.xs }) {
          Text(this.faces[this.askNo - 1].icon).fontSize(FontSize.hero)
          Text(TG('这张脸叫什么？')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }.width('100%').padding(Space.lg)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
        Column({ space: Space.sm }) { Text(this.opts[(0)].label)
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).width('100%').height(Space.xxxl)
        .backgroundColor(this.pick === (0) ? (this.opts[(0)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((0)); }); Text(this.opts[(1)].label)
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).width('100%').height(Space.xxxl)
        .backgroundColor(this.pick === (1) ? (this.opts[(1)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((1)); }); Text(this.opts[(2)].label)
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).width('100%').height(Space.xxxl)
        .backgroundColor(this.pick === (2) ? (this.opts[(2)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (2) ? Motion.pressScale : 1, y: this.pick === (2) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((2)); }); Text(this.opts[(3)].label)
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).width('100%').height(Space.xxxl)
        .backgroundColor(this.pick === (3) ? (this.opts[(3)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (3) ? Motion.pressScale : 1, y: this.pick === (3) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((3)); }) }.width('100%')
      } else {
        Column({ space: Space.xs }) {
          Text(this.won ? '🎉' : '💤').fontSize(FontSize.hero)
          Text(this.msg).fontSize(FontSize.md).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
        }.width('100%').padding(Space.lg)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      }

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .onClick(() => { this.reset(); })

      Text(TG2('判定：6 题答对 ≥ {0} 即通关。人名皆为虚构。',Digits(String(NEED), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
