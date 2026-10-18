/** 单位换算 —— 各种单位转换
 *  玩法：给一个带单位的数值，从 4 个选项里选出换算后的正确结果
 *  胜负：10 题答对 ≥8 ⇒ 通关；否则失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 10; const PASS: number = 8; const NEXT_MS: number = 800;
const VALS: number[] = [1, 2, 3, 4, 5, 8, 10, 12, 20, 25, 30, 50, 60, 100, 120, 250, 500, 1000];
interface Unit { n: string; f: number }
interface Scale { g: string; us: Unit[] }
const SCALES: Scale[] = [
  { g: TG('长度'), us: [{ n: 'mm', f: 0.001 }, { n: 'cm', f: 0.01 }, { n: 'm', f: 1 }, { n: 'km', f: 1000 }] },
  { g: '质量', us: [{ n: 'g', f: 1 }, { n: 'kg', f: 1000 }, { n: 't', f: 1000000 }] },
  { g: TG('时间'), us: [{ n: '秒', f: 1 }, { n: '分', f: 60 }, { n: '时', f: 3600 }] },
  { g: '容量', us: [{ n: 'mL', f: 1 }, { n: 'L', f: 1000 }] },
  { g: '数据', us: [{ n: 'KB', f: 1 }, { n: 'MB', f: 1024 }] }
];
/** 最多 4 位小数，去掉末尾多余的 0 */
function fmt(v: number): string {
  const r: number = Math.round(v * 10000) / 10000; const i: number = Math.floor(r);
  if (Math.abs(r - i) < 0.0000001) { return String(i); }
  let s: string = r.toFixed(4);
  while (s.length > 0 && s.charAt(s.length - 1) === '0') { s = s.substring(0, s.length - 1); }
  if (s.length > 0 && s.charAt(s.length - 1) === '.') { s = s.substring(0, s.length - 1); }
  return s;
}
function perm(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) { out.push(i); }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GUnitConverterPro {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=10
  @State private diffTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State private q: string = ''; @State private group: string = ''; @State private opts: string[] = [];
  @State private ansIdx: number = 0; @State private round: number = 1; @State private right: number = 0;
  @State private score: number = 0; @State private pick: number = -1; @State private answered: boolean = false;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.right = 0; this.score = 0; this.over = false;
    this.won = false; this.ask(); this.msg = TG('选出换算后的正确结果');
  }
  private ask(): void {
    let ready: boolean = false; let tries: number = 0; let qTxt: string = ''; let grp: string = '';
    let texts: string[] = []; let pos: number = 0;
    while (!ready && tries < 60) {
      tries++; const sc: Scale = SCALES[Math.floor(Math.random() * SCALES.length)];
      const i: number = Math.floor(Math.random() * sc.us.length);
      let j: number = Math.floor(Math.random() * sc.us.length);
      if (j === i) { j = (j + 1) % sc.us.length; }
      const uFrom: Unit = sc.us[i]; const uTo: Unit = sc.us[j];
      const v: number = VALS[Math.floor(Math.random() * VALS.length)]; const ans: number = v * uFrom.f / uTo.f;
      if (ans < 0.5 || ans > 200000) { continue; }
      const ansTxt: string = fmt(ans);
      const raw: string[] = [fmt(ans * 10), fmt(ans / 10), fmt(ans * 100), fmt(ans / 100), fmt(ans * 1000)];
      const pool: string[] = [ansTxt];
      for (let k = 0; k < raw.length && pool.length < 4; k++) {
        if (raw[k] !== ansTxt && pool.indexOf(raw[k]) < 0) { pool.push(raw[k]); }
      }
      if (pool.length < 4) { continue; }
      const order: number[] = perm(4); let spot: number = 0; const list: string[] = [];
      for (let k = 0; k < 4; k++) {
        const s: string = pool[order[k]];
        if (s === ansTxt) { spot = k; }
        list.push(s);
      }
      qTxt = String(v) + ' ' + uFrom.n + ' = ? ' + uTo.n; grp = sc.g; texts = list; pos = spot; ready = true;
    }
    if (!ready) { qTxt = '1 m = ? cm'; grp = TG('长度'); texts = ['100', '10', '1000', '0.1']; pos = 0; }
    this.q = qTxt; this.group = grp; this.opts = texts; this.ansIdx = pos; this.pick = -1; this.answered = false;
  }
  private submit(k: number): void {
    if (this.answered || this.over) { return; }
    this.answered = true; this.pick = k;
    if (k === this.ansIdx) {
      this.right = this.right + 1; this.score = this.score + 130; this.msg = '✅ ' + this.q.replace('?', this.opts[k]); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    } else {
      this.score = Math.max(0, this.score - 25); this.msg = TG('❌ 应该是 ') + this.q.replace('?', this.opts[this.ansIdx]); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1; this.next();
    }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask(); this.msg = TG('选出换算后的正确结果');
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'unit_converter_pro', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(PASS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text('📏 ' + this.group).fontSize(FontSize.sm).fontColor(Palette.primaryDeep)
        Text(this.q).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG('1 个『大单位』= 若干『小单位』；大换小乘，小换大除')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? this.opts[(0)] : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (0)
        ? ((0) === this.ansIdx ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.submit((0));
        })
        Button(this.opts.length > (1) ? this.opts[(1)] : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (1)
        ? ((1) === this.ansIdx ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.submit((1));
        })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (2) ? this.opts[(2)] : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (2)
        ? ((2) === this.ansIdx ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.submit((2));
        })
        Button(this.opts.length > (3) ? this.opts[(3)] : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (3)
        ? ((3) === this.ansIdx ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.submit((3));
        })
      }.width('100%')
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          this.reset();
        })
      Text(TG('提示：长度 10 进、数据 1024 进、时间 60 进')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
