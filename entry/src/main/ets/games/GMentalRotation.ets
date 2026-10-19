/**
 * 心理旋转（id: mental_rotation）—— 右边那组是左边「纯旋转」，还是被偷偷镜像了？
 * 胜负：10 题答对 ≥ 8 题通关；进度：题号 / 答对 / 总旋转角度
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const ROUNDS: number = 10;
const WIN: number = 8;
const GAP: number = 2;

/** 顺时针转 90° */
function rot90(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[c * N + (N - 1 - r)] = m[r * N + c];
    }
  }
  return o;
}

/** 左右镜像 */
function mirrorX(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[r * N + c] = m[r * N + (N - 1 - c)];
    }
  }
  return o;
}

function turn(times: number, m: boolean[]): boolean[] {
  let o: boolean[] = m.slice();
  for (let i = 0; i < times; i++) {
    o = rot90(o);
  }
  return o;
}

function same(a: boolean[], b: boolean[]): boolean {
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

/** 手写的不对称图案池（不对称 ⇒ 旋转绝不会与镜像重合，答案无歧义） */
function pool(): boolean[][] {
  const g = (s: string): boolean[] => s.split('').map((ch: string) => ch === '1');
  return [
    g('1000011000001000110000100'),
    g('1110000100001001110000000'),
    g('1000001000111100100001000'),
    g('1000011000110000010000100'),
    g('1100000100111000001000000'),
    g('1000001100011000001000100'),
    g('1111100000001000001000010'),
    g('0100000100111000001001000')
  ];
}

interface Round {
  base: boolean[];
  cand: boolean[];
  mir: boolean[];
  isMirror: boolean;
  deg: number;
}

function makeRound(): Round {
  const p: boolean[][] = pool();
  const base: boolean[] = p[Math.floor(Math.random() * p.length)];
  const deg: number = (1 + Math.floor(Math.random() * 3)) * 90;
  const isMirror: boolean = Math.random() < 0.5;
  const cand: boolean[] = isMirror ? turn(deg / 90, mirrorX(base)) : turn(deg / 90, base);
  const out: Round = { base: base, cand: cand, mir: mirrorX(base), isMirror: isMirror, deg: deg };
  return out;
}

@Component
export struct GMentalRotation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=10
  @State private diffTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State private base: boolean[] = []; @State private cand: boolean[] = []; @State private mir: boolean[] = [];
  @State private truth: boolean = false; @State private deg: number = 0; @State private round: number = 1;
  @State private right: number = 0; @State private sumDeg: number = 0; @State private picked: number = -1;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private cur: Round | null = null;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.round = 1; this.right = 0; this.sumDeg = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  private nextRound(): void {
    const r: Round = makeRound();
    this.cur = r;
    this.base = r.base; this.cand = r.cand; this.mir = r.mir;
    this.truth = r.isMirror; this.deg = r.deg; this.picked = -1;
    this.msg = TG('右边那组是怎么变来的？');
  }
  private answer(sayMirror: boolean): void {
    if (this.over || this.picked >= 0 || this.cur === null) { return; }
    this.picked = sayMirror ? 1 : 0;
    const hit: boolean = sayMirror === this.truth;
    if (hit) {
      this.right = this.right + 1;
      this.sumDeg = this.sumDeg + this.deg;
      this.msg = TG2('✅ 答对 · 累计转过 {0}°', String(this.sumDeg));
    } else {
      this.msg = TG2("❌ 它是{0}{1}°）", (this.truth ? '镜像（转 ' : '纯旋转（转 '), String(this.deg));
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 780);
  }
  private advance(): void {
    if (this.round >= this.diffTotal) { this.end(); return; }
    this.round = this.round + 1;
    this.nextRound();
  }
  private end(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= WIN;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
    const r: GameResult = {
      gameId: 'mental_rotation', solved: this.won,
      score: this.right * 120 + (this.won ? 240 : 0) + this.sumDeg,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('转过'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.sumDeg) + '°')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
      Text((TG('原图'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(this.rows(((this.base))))
      .fontSize(FontSize.md)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .lineHeight(FontSize.lg)
      .width('100%')
      }
      .layoutWeight(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .borderWidth((false) ? 2 : 0)
      .borderColor(Palette.emerald)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      Column({ space: Space.xs }) {
      Text((TG('右边这组'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(this.rows(((this.cand))))
      .fontSize(FontSize.md)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .lineHeight(FontSize.lg)
      .width('100%')
      }
      .layoutWeight(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .borderWidth((this.picked >= 0 && this.truth) ? 2 : 0)
      .borderColor(Palette.emerald)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.md }) {
        Button((TG('纯旋转 ⟳')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.picked === (0) ? Palette.primaryDeep : (true ? Palette.sky : Palette.violet))
        .borderRadius(Radius.lg)
        .layoutWeight(1)
        .height(Cell.of(60))
        .scale({ x: this.picked === (0) ? Motion.pressScale : 1, y: this.picked === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer(false); })
        Button((TG('镜像 🪞')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.picked === (1) ? Palette.primaryDeep : (false ? Palette.sky : Palette.violet))
        .borderRadius(Radius.lg)
        .layoutWeight(1)
        .height(Cell.of(60))
        .scale({ x: this.picked === (1) ? Motion.pressScale : 1, y: this.picked === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer(true); })
      }
      .width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：10 题答对 ≥ 8 题 · 提示：不对称图形转过 90/180/270° 的样子'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



  private rows(m: boolean[]): string {
    let out: string = '';
    for (let r = 0; r < N; r++) {
      let s: string = '';
      for (let c = 0; c < N; c++) {
        s = s + (m[r * N + c] ? '■' : '·');
      }
      out = out + (r > 0 ? '\n' : '') + s;
    }
    return out;
  }

}
