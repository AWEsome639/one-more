/** 镜面反射 —— 光路更长更绕，六块镜子导两束光　胜负：18 步内点亮全部探头 ⇒ 通关｜进度：已亮/总数 + 剩余步数
 *  造局：随机镜位 → 随机「解态」朝向 → 光束射出棋盘的那格即探头 ⇒ **每局必定可解**；
 *  开局给随机朝向且保证还没点亮 ⇒ 必须先转镜子。／ 右→上、上→右；＼ 右→下、下→右。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const GS: number = 9;
const NB: number = 2; const NF: number = 4; const NX: number = 2; const MAX: number = 18;
const RG: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];

/** 走一遍光束：返回途经格子，出口坐标写进 out */
function walk(g: number[], e: number[], out: number[]): number[] {
  let r: number = e[0]; let c: number = e[1]; let d: number = e[2];
  const p: number[] = [];
  for (let s = 0; s < 160; s++) {
    r = r + (d === 0 ? -1 : (d === 2 ? 1 : 0));
    c = c + (d === 1 ? 1 : (d === 3 ? -1 : 0));
    if (r < 0 || r >= GS || c < 0 || c >= GS) { out[0] = r; out[1] = c; break; }
    const i: number = r * GS + c; p.push(i); const t: number = g[i];
    if (t === 1) { d = d === 1 ? 0 : (d === 0 ? 1 : (d === 3 ? 2 : 3)); }
    else if (t === 2) { d = d === 2 ? 1 : (d === 1 ? 2 : (d === 0 ? 3 : 0)); }
  }
  return p;
}
function glyph(t: number): string { return t === 1 ? '／' : (t === 2 ? '＼' : ''); }

@Component
export struct GLaserReflect {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 GS=9）
  @State private diffTotal: number = GameDiff.sizeNow(9);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State grid: number[] = []; @State emits: number[][] = []; @State slots: number[] = [];
  @State dets: number[] = []; @State lit: number = 0; @State moves: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private beam: number[] = []; private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(9);
     this.reset(); }

  /** 反推造局：先定解态，再按光束落点放探头 ⇒ 必定有解 */
  private setup(): void {
    for (let a = 0; a < 400; a++) {
      const rows: number[] = [];

      while (rows.length < NB) {
        const x: number = 1 + Math.floor(Math.random() * (this.diffTotal - 2));
        if (rows.indexOf(x) < 0) { rows.push(x); }
      }
      const beams: number[][] = []; const cells: number[] = [];
      for (let k = 0; k < NB; k++) { beams.push(k % 2 === 0 ? [rows[k], 0, 1] : [rows[k], this.diffTotal - 1, 3]); }
      for (let r = 1; r < this.diffTotal - 1; r++) { for (let c = 2; c < this.diffTotal - 2; c++) { cells.push(r * this.diffTotal + c); } }
      for (let i = cells.length - 1; i > 0; i--) {
        const j: number = Math.floor(Math.random() * (i + 1)); const tv: number = cells[i]; cells[i] = cells[j]; cells[j] = tv;
      }
      const free: number[] = []; const fix: number[] = [];
      for (let i = 0; i < cells.length && (free.length < NF || fix.length < NX); i++) {
        const v: number = cells[i]; let apart: boolean = true;
        for (let j = 0; j < free.length + fix.length; j++) {
          const o: number = j < free.length ? free[j] : fix[j - free.length];
          if (Math.abs(Math.floor(v / this.diffTotal) - Math.floor(o / this.diffTotal)) + Math.abs(v % this.diffTotal - o % this.diffTotal) <= 1) { apart = false; }
        }
        if (!apart) { continue; }
        if (free.length < NF) { free.push(v); } else { fix.push(v); }
      }
      if (free.length < NF || fix.length < NX) { continue; }
      const base: number[] = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
      for (let i = 0; i < fix.length; i++) { base[fix[i]] = 1 + Math.floor(Math.random() * 2); }

      for (let t = 0; t < 120; t++) {
        const target: number[] = []; const gs: number[] = base.slice();
        for (let i = 0; i < NF; i++) {
          target.push(1 + Math.floor(Math.random() * 2)); gs[free[i]] = target[i];
        }
        const dets: number[] = []; let bad: boolean = false;
        for (let k = 0; k < NB; k++) {
          const out: number[] = [-9, -9]; const p: number[] = walk(gs, beams[k], out);
          let d0: number = -1;   // 探头 = 出界前最后那个空格（必在路径上，不会被走过头）
          let j: number = p.length - 1;
          while (j >= 0) {
            if (free.indexOf(p[j]) < 0 && fix.indexOf(p[j]) < 0) { d0 = p[j]; break; }
            j--;
          }
          const em: number = beams[k][0] * this.diffTotal + beams[k][1];
          if (d0 < 0 || d0 === em || dets.indexOf(d0) >= 0) { bad = true; break; }
          dets.push(d0);
        }
        if (bad) { continue; }
        const init: number[] = []; const gi: number[] = base.slice();
        for (let i = 0; i < NF; i++) {
          init.push((target[i] % 2) + 1); gi[free[i]] = init[i];   // 与解态不同，且必为 1/2
        }
        let already: number = 0;
        for (let k = 0; k < NB; k++) {
          const o2: number[] = [-9, -9];
          if (walk(gi, beams[k], o2).indexOf(dets[k]) >= 0) { already++; }
        }
        if (already >= NB) { continue; }
        this.emits = beams; this.dets = dets; this.slots = free; this.grid = gi; return;
      }
    }
  }
  /** 重算光束与已亮数 */ private refresh(): void {
    let n: number = 0; const lit: number[] = [];
    for (let k = 0; k < this.emits.length; k++) {
      const out: number[] = [-9, -9]; const p: number[] = walk(this.grid, this.emits[k], out);
      for (let j = 0; j < p.length; j++) { lit.push(p[j]); }
      if (p.indexOf(this.dets[k]) >= 0) { n++; }
    }
    this.beam = lit; this.lit = n;
  }
  private reset(): void {
    this.moves = 0; this.score = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.setup(); this.msg = TG(TG(TG('点 ／＼ 换朝向，把光折到 🎯'))); this.refresh();
  }
  private rotateAt(slot: number): void {
    if (this.over) { return; }
    const ng: number[] = this.grid.slice();
    ng[slot] = ng[slot] >= 2 ? 1 : ng[slot] + 1;
    this.grid = ng; this.moves = this.moves + 1; this.score = this.score + 5; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.refresh();
    if (this.lit >= this.dets.length) {
      this.over = true; this.won = true; this.score = this.score + (MAX - this.moves) * 20 + 200;
      this.msg = '🎉 全部点亮！用了 ' + this.moves + TG(' 步'); this.finish(true);
      return;
    }
    if (this.moves >= MAX) {
      this.over = true; this.msg = TG2('💤 步数用尽，只亮了 {0}/{1}',Digits(String(this.lit), this.langCode), this.dets.length);
      this.finish(false); return;
    }
    this.msg = TG2('已亮 {0}/{1}，继续调镜子', this.lit, this.dets.length);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'laser_reflect', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.lit };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  /** 优先级：发射器 > 探头 > 镜子 > 光路 */
  private mark(i: number): string {
    if (this.emits.some((e: number[]) => e[0] * this.diffTotal + e[1] === i)) { return '🔦'; }
    if (this.dets.indexOf(i) >= 0) { return '🎯'; }
    if (this.grid[i] > 0) { return glyph(this.grid[i]); }
    return this.beam.indexOf(i) >= 0 ? '·' : '';
  }
  private bg(i: number): string {
    if (this.dets.indexOf(i) >= 0) { return this.lit > 0 ? '#A7F3D0' : this.theme.surfaceAlt; }
    if (this.beam.indexOf(i) >= 0 && this.grid[i] === 0) { return '#FDE68A'; }
    const t: number = this.grid[i];
    return t > 0 ? (t === 1 ? Palette.cyan : Palette.amber) : this.theme.surface;
  }
  build() {
    Column({ space: Space.md }) {
      Text(TG2("已亮 {0}/{1}", this.lit, this.dets.length))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.orange)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: 3 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 3 }) {
            ForEach(this.rowIdx(), (c: number) => { this.cell(r * this.diffTotal + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#0B0B0B' : '#EEF2F7').borderRadius(Radius.lg)
      Row({ space: Space.md }) {
        Text(this.msg + '　🔦发射器 🎯探头').fontSize(FontSize.xs).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
          .fontColor(this.theme.inkSoft).layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).onClick(() => { this.reset(); })
      }.width('100%')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder cell(i: number) {
    Stack() {
      Text(this.mark(i)).fontSize(FontSize.sm).textAlign(TextAlign.Center)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.bg(i)).borderRadius(Radius.xs)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { if (this.slots.indexOf(i) >= 0) { this.rotateAt(i); } })
  }
}
