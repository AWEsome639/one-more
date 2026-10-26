/**
 * 镜像（id: mirror_image）—— 右边是不是左边沿中轴翻转出来的真镜像？
 * 胜负：10 题答对 ≥ 8 题通关；进度：题号 / 答对 / 已判对局数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const ROUNDS: number = 10;
const WIN: number = 8;

/** 绕中轴翻转（水平镜像） */
function flipX(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[r * N + c] = m[r * N + (N - 1 - c)];
    }
  }
  return o;
}

/** 上下翻转 */
function flipY(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[r * N + c] = m[(N - 1 - r) * N + c];
    }
  }
  return o;
}

function shuffled(m: boolean[]): boolean[] {
  const o: boolean[] = m.slice();
  for (let i = o.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: boolean = o[i];
    o[i] = o[j];
    o[j] = t;
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

function pool(): boolean[][] {
  const g = (s: string): boolean[] => s.split('').map((ch: string) => ch === '1');
  return [
    g('1100001000010000100001110'),
    g('0111001000010000100000111'),
    g('1000011000011100010000100'),
    g('1110000010000100001011100'),
    g('0010000110011100100000000'),
    g('1101001010010100100001100'),
    g('1000101010111110000010000'),
    g('0100001100111000010000100')
  ];
}

interface Round {
  left: boolean[];
  right: boolean[];
  truth: boolean;
}

/** 出题：一半真镜像，另一半用「上下翻转/打乱」保证一定不是水平镜像 */
function makeRound(): Round {
  const p: boolean[][] = pool();
  const left: boolean[] = p[Math.floor(Math.random() * p.length)];
  const mir: boolean[] = flipX(left);
  const truth: boolean = Math.random() < 0.5;
  let right: boolean[] = mir.slice();
  if (!truth) {
    const up: boolean[] = flipY(left);
    right = same(up, mir) ? shuffled(left) : up;
    let guard: number = 0;
    while (same(right, mir) && guard < 8) {
      right = shuffled(left);
      guard++;
    }
  }
  const out: Round = { left: left, right: right, truth: truth };
  return out;
}

@Component
export struct GMirrorImage {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=10
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State private left: boolean[] = []; @State private right: boolean[] = [];
  @State private truth: boolean = false; @State private round: number = 1; @State private rightN: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private rightNPulse: number = 1;
  @State private judged: number = 0; @State private picked: number = -1; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false; private startAt: number = 0;
  private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.round = 1; this.rightN = 0; this.judged = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  private nextRound(): void {
    const r: Round = makeRound();
    this.left = r.left; this.right = r.right; this.truth = r.truth;
    this.picked = -1;
    this.msg = TG('右边是左边的镜像吗？🪞');
  }
  /** 提示：报「是 / 否」——代打用的表达式算出来是它 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const truth: boolean = this.truth;
    return Hint.make([],
      truth ? TG('答案是「是」') : TG('答案是「否」'),
      truth ? TG('The answer is Yes') : TG('The answer is No'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里 ⇒ 每一拍"选正确答案"；答过就等下一题（picked 守卫）
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.answer(this.truth);
    return !this.over;
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

  private answer(sayMirror: boolean): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = sayMirror ? 1 : 0;
    this.judged = this.judged + 1;
    const hit: boolean = sayMirror === this.truth;
    if (hit) {
      this.rightN = this.rightN + 1; this.rightNPulse = 1.3; setTimeout(() => { this.rightNPulse = 1; }, 140);
      this.msg = this.truth ? '✅ 是镜像 · 每条横线都左右对调了' : '✅ 不是镜像 · 它被上下翻了';
    } else {
      this.msg = this.truth ? '❌ 它确实是镜像' : '❌ 它不是镜像（上下翻转／重排）';
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 800);
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
    this.won = this.rightN >= WIN;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.rightN), String(this.diffTotal));
    const r: GameResult = {
      gameId: 'mirror_image', solved: this.won,
      score: this.rightN * 130 + (this.won ? 260 : 0),
      durationMs: Date.now() - this.startAt, levelReached: this.rightN
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
        Text(Digits(String(this.rightN), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.rightNPulse, y: this.rightNPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已判定'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.judged), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('左'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.rows((this.left)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.picked >= 0 ? Palette.amber : this.theme.ink)
        .textAlign(TextAlign.Center)
        .lineHeight(FontSize.lg)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg)
        .shadow(Shadow.card)
        Text('≟').accessibilityText(TG('比较')).fontSize(FontSize.xxl).fontColor(this.theme.inkFaint)
        Column({ space: Space.xs }) {
        Text((TG('右'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.rows((this.right)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.picked >= 0 ? Palette.amber : this.theme.ink)
        .textAlign(TextAlign.Center)
        .lineHeight(FontSize.lg)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg)
        .shadow(Shadow.card)
      }
      .width('100%')
      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.md }) {
        Button((TG('是镜像')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.picked === (1) ? Palette.primaryDeep : (true ? Palette.teal : Palette.sky))
        .borderRadius(Radius.lg)
        .layoutWeight(1)
        .height(Cell.of(60))
        .scale({ x: this.picked === (1) ? Motion.pressScale : 1, y: this.picked === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer(true); })
        Button((TG('不是')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.picked === (0) ? Palette.primaryDeep : (false ? Palette.teal : Palette.sky))
        .borderRadius(Radius.lg)
        .layoutWeight(1)
        .height(Cell.of(60))
        .scale({ x: this.picked === (0) ? Motion.pressScale : 1, y: this.picked === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer(false); })
      }
      .width('100%')
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：10 题答对 ≥ 8 题 · 干扰项是「上下翻转」，别与左右镜像混了'))
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
