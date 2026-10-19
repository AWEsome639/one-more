/**
 * 柜子记忆 —— 六格里亮出几件物品，1.5 秒后收起，再问「某件物品在哪一格」
 * 胜负：6 轮答对 ≥5 轮通关
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const COLS: number = 3;
const ROWS: number = 2;
const CELLS: number = COLS * ROWS;
const ITEMS: number = 4;
const ROUNDS: number = 6;
const SHOW_MS: number = 1500;

const ICONS: string[] = ['🍎', '🔑', '☕', '📕', '🎲', '🧸'];

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GSpatialCabinetMemory {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ITEMS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ITEMS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private slotOf: number[] = [];    // 每格放第几件物品，-1 = 空
  @State private items: number[] = [];     // 本局用到的物品
  @State private target: number = -1;      // 问哪件物品
  @State private pick: number = -1;
  @State private phase: number = 0;        // 0 记忆 1 作答 2 揭晓
  @State private round: number = 1;
  @State private hit: number = 0;
  @State private score: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private hideTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ITEMS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.slotOf = []; this.items = []; this.target = -1; this.pick = -1; this.phase = 0;
    this.round = 1; this.hit = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newTrial();
  }

  /** 撒物品：4 件各占一格，然后随机挑一件来问 */
  private newTrial(): void {
    const pool: number[] = [0, 1, 2, 3, 4, 5];
    const slot: number[] = [-1, -1, -1, -1, -1, -1];
    const used: number[] = [];
    for (let k = 0; k < this.diffTotal; k++) {
      const s: number = Math.floor(Math.random() * pool.length);
      const cell: number = pool[s];
      pool.splice(s, 1);
      let icon: number = Math.floor(Math.random() * ICONS.length);
      let guard: number = 0;
      while (has(used, icon) && guard < ICONS.length) { icon = (icon + 1) % ICONS.length; guard = guard + 1; }
      slot[cell] = icon;
      used.push(icon);
    }
    this.slotOf = slot;
    this.items = used;
    this.target = used[Math.floor(Math.random() * used.length)];
    this.pick = -1;
    this.phase = 0;
    this.msg = TG(TG(TG('记住每件物品的柜格')));
    this.hideTo = setTimeout(() => {
      this.hideTo = -1;
      this.phase = 1;
      this.msg = ICONS[this.target] + ' 刚才在哪一格？点它';
    }, SHOW_MS);
  }

  private tap(cell: number): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = cell;
    this.phase = 2;
    const real: number = this.slotOf.indexOf(this.target);
    if (cell === real) {
      this.hit = this.hit + 1;
      this.score = this.score + 120; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ 对！{0} 就在这里', ICONS[this.target]);
    } else {
      this.msg = '❌ 它在第 ' + String(real + 1) + TG(' 格');
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 1000);
  }

  private advance(): void {
    if (this.round >= ROUNDS) {
      const win: boolean = this.hit >= 5;
      this.over = true; this.won = win;
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 轮", String(this.hit), String(ROUNDS));
      const res: GameResult = {
        gameId: 'spatial_cabinet_memory', solved: win, score: this.score,
        durationMs: Date.now() - this.startAt, levelReached: this.round
      };
      if (!this.done) { this.done = true; LanRace.noteDone(); this.onFinish(res); }
      return;
    }
    this.round = this.round + 1;
    this.newTrial();
  }

  /** 记忆阶段显示物品；作答后只把点过的那格翻开 */
  private face(cell: number): string {
    const v: number = this.slotOf.length > 0 ? this.slotOf[cell] : -1;
    if (this.phase === 0) { return v >= 0 ? ICONS[v] : ''; }
    return this.pick === cell ? '❓' : '';
  }

  private tint(cell: number): string {
    const v: number = this.slotOf.length > 0 ? this.slotOf[cell] : -1;
    if (this.phase === 0) { return v >= 0 ? Palette.primaryDeep : this.theme.surface; }
    if (this.pick !== cell) { return this.theme.surface; }
    return v === this.target ? Palette.emerald : Palette.rose;
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2("轮次 {0}/{1}",Digits(String(this.round), this.langCode),Digits(String(ROUNDS), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + String(this.hit)).fontSize(FontSize.sm).fontColor(Palette.primaryDeep)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              this.cellView(r * COLS + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.md).fontColor(this.phase === 0 ? this.theme.ink : Palette.primaryDeep)
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(cell: number) {
    Stack() {
      Text(this.face(cell)).fontSize(FontSize.xxl)
    }
    .layoutWeight(1).height(Cell.of(64)).backgroundColor(this.tint(cell)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(cell); })
  }
}
