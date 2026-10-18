/**
 * 七巧板 —— 用 4 块砖严丝合缝铺满阴影；点已铺的砖可取回重放
 * 胜负：铺满 ⇒ 通关；次数用尽（12 次）⇒ 失败　｜　进度：铺对 / 次数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4; const LIMIT: number = 12;

interface Piece { cells: number[]; icon: string; name: string; }
interface Slot { p: number; r: number; c: number; }

const PIECES: Piece[] = [
  { cells: [0, 1], icon: '▬', name: '短条2' },
  { cells: [0, 1, 4], icon: '◤', name: '直角3' },
  { cells: [0, 1, 4, 5], icon: '■', name: '方块4' },
  { cells: [0, 4, 8], icon: '▮', name: '竖条3' }
];

const LAYOUTS: Slot[][] = [
  [{ p: 2, r: 0, c: 0 }, { p: 1, r: 0, c: 2 }, { p: 0, r: 2, c: 0 }, { p: 3, r: 1, c: 3 }],
  [{ p: 2, r: 0, c: 0 }, { p: 3, r: 0, c: 2 }, { p: 1, r: 2, c: 0 }, { p: 0, r: 3, c: 2 }],
  [{ p: 1, r: 0, c: 0 }, { p: 0, r: 0, c: 2 }, { p: 2, r: 1, c: 1 }, { p: 3, r: 1, c: 3 }],
  [{ p: 3, r: 0, c: 0 }, { p: 1, r: 0, c: 1 }, { p: 2, r: 1, c: 2 }, { p: 0, r: 3, c: 0 }]
];

function shadowOf(layout: Slot[]): number[] {
  const g: number[] = new Array<number>(N * N).fill(0);
  for (let s = 0; s < layout.length; s++) {
    const cells: number[] = PIECES[layout[s].p].cells;
    for (let m = 0; m < cells.length; m++) {
      g[(layout[s].r + Math.floor(cells[m] / N)) * N + (layout[s].c + cells[m] % N)] = 1;
    }
  }
  return g;
}
@Component
export struct GTangram {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State target: number[] = []; @State pieceAt: number[] = []; @State sel: number = -1;
  @State moves: number = 0; @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  private reset(): void {
    const li: number = Math.floor(Math.random() * LAYOUTS.length);
    this.target = shadowOf(LAYOUTS[li]); this.pieceAt = new Array<number>(this.diffTotal * this.diffTotal).fill(-1);
    this.sel = -1; this.moves = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.msg = TG('选一块砖，再点棋盘落点铺上去');
  }
  /** [铺对格数, 阴影总格数] */
  private scan(): number[] {
    let ok: number = 0; let all: number = 0;
    for (let i = 0; i < this.target.length; i++) {
      if (this.target[i] === 1) { all = all + 1; if (this.pieceAt[i] >= 0) { ok = ok + 1; } }
    }
    return [ok, all];
  }
  private tap(i: number): void {
    if (this.over) { return; }
    if (this.pieceAt[i] >= 0) {
      const back: number[] = this.pieceAt.slice();
      const which: number = this.pieceAt[i];
      for (let k = 0; k < back.length; k++) { if (back[k] === which) { back[k] = -1; } }
      this.pieceAt = back; this.sel = -1; this.msg = TG2("{0} 已取回", PIECES[which].name);
      return;
    }
    if (this.sel < 0) { this.msg = TG('先在上方选一块砖'); return; }
    const cells: number[] = PIECES[this.sel].cells;
    const r: number = Math.floor(i / this.diffTotal); const c: number = i % this.diffTotal;
    for (let m = 0; m < cells.length; m++) {
      const rr: number = r + Math.floor(cells[m] / this.diffTotal); const cc: number = c + cells[m] % this.diffTotal;
      if (rr >= this.diffTotal || cc >= this.diffTotal || this.pieceAt[rr * this.diffTotal + cc] >= 0) { this.msg = TG('❌ 放不下：出界或压住别的砖'); return; }
    }
    const at: number[] = this.pieceAt.slice();
    for (let m = 0; m < cells.length; m++) {
      at[(r + Math.floor(cells[m] / this.diffTotal)) * this.diffTotal + (c + cells[m] % this.diffTotal)] = this.sel;
    }
    this.pieceAt = at; this.sel = -1; this.moves = this.moves + 1;
    let exact: boolean = true;
    for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
      if ((this.target[k] === 1) !== (this.pieceAt[k] >= 0)) { exact = false; }
    }
    const now: number[] = this.scan();
    if (exact) {
      this.over = true; this.won = true; this.msg = TG2("🎉 严丝合缝！用了 {0} 次",Digits(String(this.moves), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    if (this.moves >= LIMIT) {
      this.over = true; this.won = false;
      this.msg = TG2("💤 次数用尽，只铺对 {0} / {1} 格", now[0], now[1]);
      this.finish(false); return;
    }
    this.msg = TG2("铺对 {0} / {1} 格　剩 {2} 次", now[0], now[1], (LIMIT - this.moves));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const sc: number = solved ? 40 + (LIMIT - this.moves) * 5 : this.scan()[0] * 5;
    const r: GameResult = { gameId: 'tangram', solved: solved, score: sc, durationMs: Date.now() - this.startAt, levelReached: this.scan()[0] };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Text(TG2('铺对 {0} / {1}　次数 {2}', String(this.scan()[0]), String(this.scan()[1]),Digits(String(this.moves), this.langCode)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        ForEach(this.rowIdx(), (p: number) => {
          Text((this.pieceAt.indexOf((p)) >= 0 ? '· ' : PIECES[(p)].icon + ' ') + PIECES[(p)].name)
          .fontSize(FontSize.xs).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(50))
          .fontColor(this.pieceAt.indexOf((p)) >= 0 ? this.theme.inkFaint : this.theme.inkSoft)
          .backgroundColor(this.sel === (p) ? '#336366F1' : this.theme.surfaceAlt).borderRadius(Radius.md)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          if (this.pieceAt.indexOf((p)) < 0 && !this.over) { this.sel = this.sel === (p) ? -1 : (p); }
          })
        }, (p: number) => 'p' + p)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text('').fontSize(FontSize.md)
              }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
              .backgroundColor(this.pieceAt[(r * this.diffTotal + c)] >= 0 ? (this.target[(r * this.diffTotal + c)] === 1 ? Palette.sky : Palette.rose)
              : (this.target[(r * this.diffTotal + c)] === 1 ? (this.theme.isDark ? '#220EA5E9' : '#330EA5E9') : this.theme.surfaceAlt))
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { this.tap((r * this.diffTotal + c)); })
            }, (c: number) => 'c' + r + '_' + c)
          }.width('100%').layoutWeight(1)
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开（换一题）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
