/**
 * 黑猩猩测验 —— 数字位置瞬时记忆：点下 1 后数字全部隐藏，仍须按升序点完
 * 胜负：连过 7 关（4→10 个数字）通关；点错扣一条命，命尽即失败
 * 进度：关卡 / 本关个数 / 得分 / 生命
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
const N: number = 5;
const LEVELS: number = 7; const BASE: number = 4; const LIVES: number = 3;
@Component
export struct GChimpTest {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State cells: number[] = []; @State hidden: boolean = false; @State next: number = 1;
  @State level: number = 1; @State score: number = 0; @State life: number = LIVES;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  private count(): number { return BASE + this.level - 1; }
  private reset(): void {
    this.level = 1; this.score = 0; this.life = LIVES;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.deal();
  }
  /** 随机格子撒 1..count */
  private deal(): void {
    const grid: number[] = new Array<number>(N * N).fill(0);
    const pool: number[] = [];
    for (let i = 0; i < N * N; i++) { pool.push(i); }
    for (let k = 1; k <= this.count(); k++) {
      const p: number = Math.floor(Math.random() * pool.length);
      grid[pool[p]] = k; pool.splice(p, 1);
    }
    this.cells = grid; this.hidden = false; this.next = 1;
    this.msg = TG2("记住这 {0} 个数字的位置", this.count());
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.next > this.count()) {
      return true;
    }
    this.tap(this.cells.indexOf(this.next));
    return !this.over;
  }

  /** 提示：报「现在该点几」+ 它在第几行第几列（数字已藏起来，位置就是内容） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.cells.indexOf(this.next);
    if (k < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(k / N) + 1;
    const c: number = k - Math.floor(k / N) * N + 1;
    return Hint.make([k],
      TG2('现在该点 {0}（第 {1} 行第 {2} 列）', String(this.next), String(r), String(c)),
      TG2('Tap {0} now (row {1}, column {2})', String(this.next), String(r), String(c)), t0);
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

  private tap(idx: number): void {
    if (this.over) { return; }
    const v: number = this.cells[idx];
    if (v <= 0) { return; }
    if (!this.hidden) { this.hidden = true; this.msg = TG2('数字已藏起 → 依次点 1 到 {0}', this.count()); }
    if (v !== this.next) {
      this.life = this.life - 1;
      if (this.life <= 0) { this.end(false); return; }
      this.hidden = false; this.msg = TG2('❌ 点错了，只剩 {0} 条命 —— 数字已显示回来',Digits(String(this.life), this.langCode));
      return;
    }
    const grid: number[] = this.cells.slice();
    grid[idx] = -v; this.cells = grid; this.next = this.next + 1;
    this.score = this.score + 10 + this.level * 5;
    if (this.next > this.count()) { this.levelUp(); }
  }
  private levelUp(): void {
    this.score = this.score + 100;
    if (this.level >= this.diffTotal) { this.end(true); return; }
    this.level = this.level + 1; this.deal();
    this.msg = TG2('✅ 过关！第 {0} 关：{1} 个数字',Digits(String(this.level), this.langCode), this.count());
  }
  private end(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 七关全过，通关！' : '💤 命用完了';
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'chimp_test', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.level + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('本关'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.count() + TG(' 个'))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text((this.cells[r * N + c]) === 0 ? '' : ((this.cells[r * N + c]) < 0 ? String(-(this.cells[r * N + c])) : (this.hidden ? '' : String((this.cells[r * N + c])))))
              .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor((this.cells[r * N + c]) < 0 ? '#FFFFFF' : this.theme.ink)
              }
              .layoutWeight(1).aspectRatio(1).borderRadius(Radius.sm)
              .backgroundColor((this.cells[r * N + c]) < 0 ? Palette.emerald : ((this.cells[r * N + c]) === 0 ? this.theme.surfaceAlt : this.theme.surface))
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { Haptics.tick(); this.tap((r * N + c)); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.md }) {
        Button(this.hidden ? '数字已藏起' : '看好位置，再点 1')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).enabled(false)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      }
      .width('100%')
      Text(TG('提示：点下 1 之后数字全部消失，全靠脑内地图；点错会重新显示但扣一条命'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
