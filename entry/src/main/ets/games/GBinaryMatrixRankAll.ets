/**
 * 矩阵秩进阶 —— 6×6 的 0/1 矩阵，求它在模 2 下的秩；点一行选中、再点另一行 = 后者异或前者
 * （秩不变；同样两行再点一遍即复原）　胜负：6 题答对 ≥4 通关　进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const N: number = 6; const CELLS: number = N * N; const TOTAL: number = 6; const PASS: number = 4; const NEXT_MS: number = 820;
@Component
export struct GBinaryMatrixRankAll {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State m: number[] = []; @State sel: number = -1; @State picked: number = -1;
  @State round: number = 1; @State rightN: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private nextTo: number = -1; private realRank: number = 0;
  private rows: number[] = [0, 1, 2, 3, 4, 5]; private ranks: number[] = [0, 1, 2, 3, 4, 5, 6];
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    this.clearNext(); this.round = 1; this.rightN = 0; this.score = 0; this.over = false;
    this.won = false; this.finished = false; this.sel = -1; this.startAt = Date.now(); this.ask();
  }
  /** 模 2 高斯消元（按位异或）求秩 */
  private rank(src: number[]): number {
    const a: number[] = src.slice();
    let r: number = 0;
    for (let c = 0; c < this.diffTotal; c++) {
      if (r >= this.diffTotal) { break; }
      let piv: number = -1;
      for (let i = r; i < this.diffTotal; i++) { if (a[i * this.diffTotal + c] === 1) { piv = i; break; } }
      if (piv < 0) { continue; }
      if (piv !== r) { for (let k = 0; k < this.diffTotal; k++) { const t: number = a[r * this.diffTotal + k]; a[r * this.diffTotal + k] = a[piv * this.diffTotal + k]; a[piv * this.diffTotal + k] = t; } }
      for (let i = 0; i < this.diffTotal; i++) {
        if (i !== r && a[i * this.diffTotal + c] === 1) { for (let k = 0; k < this.diffTotal; k++) { a[i * this.diffTotal + k] = a[i * this.diffTotal + k] ^ a[r * this.diffTotal + k]; } }
      }
      r = r + 1;
    }
    return r;
  }
  private ask(): void {
    const m: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { m.push(Math.random() < 0.5 ? 0 : 1); }
    this.m = m; this.realRank = this.rank(m); this.sel = -1; this.picked = -1;
    this.msg = TG('点一行选中，再点另一行 → 后者异或前者，把它消成行阶梯');
  }
  /** 行变换：先点的行当主元，后点的行 ^= 它（异或两次即还原） */
  private tapRow(r: number): void {
    if (this.over || this.picked >= 0) { return; }
    const s: number = this.sel;
    if (s < 0) { this.sel = r; this.msg = TG2('已选中第 {0} 行 —— 再点一行让它异或这行', (r + 1)); return; }
    if (s === r) { this.sel = -1; this.msg = TG('取消选中'); return; }
    const a: number[] = this.m.slice();
    for (let k = 0; k < this.diffTotal; k++) { a[r * this.diffTotal + k] = a[r * this.diffTotal + k] ^ a[s * this.diffTotal + k]; }
    this.m = a; this.sel = -1;
    this.msg = TG2("第 {0} 行 ← 第 {1} 行 ⊕ 第 {2} 行（秩不变）", (r + 1), (r + 1), (s + 1));
  }
  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i;
    if (i === this.realRank) { this.rightN = this.rightN + 1; this.score = this.score + 160; this.msg = TG2('✅ 秩就是 {0}', this.realRank); }
    else { this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 正确答案是 {0} —— 阶梯里非零行有几行就是几', this.realRank); }
    this.clearNext();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round < TOTAL) { this.round = this.round + 1; this.ask(); return; }
    this.over = true; this.won = this.rightN >= PASS;
    this.msg = this.won ? TG2("🎉 答对 {0}/{1}，通关！",Digits(String(this.rightN), this.langCode), TOTAL) : TG2("😵 只答对 {0}/{1}，差 {2} 题", this.rightN, TOTAL, (PASS - this.rightN));
    this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'binary_matrix_rank_all', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rightN };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + TOTAL)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.rightN + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: 2 }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.xs }) {
          ForEach(this.rows, (c: number) => {
          Text(String(this.m[((r)) * this.diffTotal + (c)])).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(30))
          .fontColor(this.m[((r)) * this.diffTotal + (c)] === 1 ? '#FFFFFF' : this.theme.inkFaint)
          .backgroundColor(this.m[((r)) * this.diffTotal + (c)] === 1 ? Palette.amber : this.theme.surface)
          .borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (c: number) => 'mc' + (r) + '-' + c)
          }
          .width('100%').borderRadius(Radius.xs)
          .borderWidth(this.sel === (r) ? 2 : 0).borderColor(Palette.amber)
          .onClick(() => { Haptics.tick(); this.tapRow((r)); })
        }, (r: number) => 'mr' + r)
      }
      .width('100%').padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Row({ space: Space.xs }) {
        ForEach(this.ranks, (v: number) => {
          Text(String((v))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.picked >= 0 && ((v) === this.realRank || (v) === this.picked) ? '#FFFFFF' : this.theme.ink)
          .layoutWeight(1).height(Cell.of(48))
          .backgroundColor(this.picked < 0 ? this.theme.surface
          : ((v) === this.realRank ? Palette.emerald : ((v) === this.picked ? Palette.rose : this.theme.surface)))
          .borderRadius(Radius.sm).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick((v)); })
        }, (v: number) => 'op' + v)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：秩 = 行阶梯里非零行的行数；异或两次等于没做，点错就再点一遍那两行'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
