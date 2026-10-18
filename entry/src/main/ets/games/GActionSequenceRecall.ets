/**
 * 动作序列 —— 记住机器人依次做的动作，再按同样顺序点一遍
 * 胜负：6 关全过通关；错 3 次失败　进度：关卡 / 长度 / 得分 / 生命
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ACTS: string[] = ['👏', '🦶', '🤚', '✊'];
const NAMES: string[] = [TG('拍手'), TG('跺脚'), TG('举手'), TG('握拳')];
const LEVELS: number = 6; const BASE: number = 3; const LIVES: number = 3; const STEP_MS: number = 340;
@Component
export struct GActionSequenceRecall {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State seq: number[] = []; @State cursor: number = 0; @State showIdx: number = -1;
  @State playing: boolean = false; @State level: number = 1; @State score: number = 0;
  @State life: number = LIVES; @State over: boolean = false; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false;
  private timer: number = -1; private tickN: number = 0; private slots: number[] = [0, 1, 2, 3];

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  aboutToDisappear(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private reset(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.level = 1; this.score = 0; this.life = LIVES; this.over = false; this.won = false;
    this.finished = false; this.startAt = Date.now(); this.deal();
    this.timer = setInterval(() => { this.step(); }, STEP_MS);
  }

  private len(): number { return BASE + this.level - 1; }

  private deal(): void {
    const s: number[] = [];
    for (let i = 0; i < this.len(); i++) { s.push(Math.floor(Math.random() * ACTS.length)); }
    this.seq = s; this.cursor = 0; this.showIdx = -1; this.playing = true; this.tickN = 0;
    TG2('看好机器人做 {0} 个动作…', this.len())
  }

  /** 每 STEP_MS 走半拍：偶数拍亮、奇数拍灭 */
  private step(): void {
    if (this.over || !this.playing) { return; }
    const k: number = Math.floor(this.tickN / 2);
    if (k >= this.seq.length) {
      this.playing = false; this.showIdx = -1; this.msg = TG('轮到你了 —— 按同样顺序点一遍'); return;
    }
    this.showIdx = this.tickN % 2 === 0 ? this.seq[k] : -1;
    this.tickN = this.tickN + 1;
  }

  private tap(i: number): void {
    if (this.over || this.playing) { return; }
    if (i !== this.seq[this.cursor]) {
      this.life = this.life - 1;
      if (this.life <= 0) { this.end(false); return; }
      this.deal();
      // ★ 2026-10-16 整句化：各语言语序不同，不能拼片段
      this.msg = TG2('❌ 第 {0} 步错了 —— 只剩 {1} 条命，重放一次', this.cursor + 1,Digits(String(this.life), this.langCode));
      return;
    }
    this.cursor = this.cursor + 1;
    this.score = this.score + 15 + this.level * 5;
    if (this.cursor >= this.seq.length) {
      if (this.level >= this.diffTotal) { this.end(true); return; }
      this.level = this.level + 1; this.deal();
      TG2('✅ 过关！第 {0} 关：{1} 个动作',Digits(String(this.level), this.langCode), this.len())
    }
  }

  private end(solved: boolean): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.over = true; this.won = solved; this.playing = false; this.showIdx = -1;
    this.msg = solved ? '🎉 六关全过，通关！' : TG2("💤 命用完了 —— 撑到第 {0} 关",Digits(String(this.level), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'action_sequence_recall', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.level + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.len() + TG(' 个'))).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Stack() {
        Text(this.showIdx < 0 ? (this.playing ? '·' : '👀') : ACTS[this.showIdx])
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }
      .width('100%').height(150)
      .backgroundColor(this.showIdx < 0 ? this.theme.surfaceAlt : Palette.primary)
      .borderRadius(Radius.lg).shadow(Shadow.lifted).animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.xs }) {
        ForEach(this.seq, (v: number, i: number) => {
          Text(i < this.cursor ? '●' : '○').fontSize(FontSize.sm).layoutWeight(1).textAlign(TextAlign.Center)
            .fontColor(i < this.cursor ? Palette.emerald : this.theme.inkFaint)
        }, (v: number, i: number) => 'd' + i)
      }
      .width('100%')
      Row({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Column({ space: 2 }) {
          Text(ACTS[(i)]).fontSize(FontSize.xxl)
          Text(NAMES[(i)]).fontSize(FontSize.xxs).fontColor(this.theme.inkSoft)
          }
          .layoutWeight(1).height(Cell.of(80)).justifyContent(FlexAlign.Center).padding(Space.xs)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
          .opacity(this.playing ? 0.5 : 1).animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { this.tap((i)); })
        }, (i: number) => 'a' + i)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).onClick(() => { this.reset(); })
      Text(TG('提示：回放期间按钮不响应，等「轮到你了」再动手'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
