/**
 * 模钟 —— 模 12 计算
 *
 * 玩法：现在 N 点，再过 M 小时（或 M 小时前）是几点？四选一，共 8 题。
 * 胜负：答对 ≥ 6 题 ⇒ 通关；否则失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const ROUNDS: number = 8;
const PASS: number = 6;
const PICK: number = 4;
const DIAL: number = 12;
const NEXT_MS: number = 420;

const FACES: string[] = ['🕐', '🕑', '🕒', '🕓', '🕔', '🕕', '🕖', '🕗', '🕘', '🕙', '🕚', '🕛'];

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

/** 把任意整数折回 1..12 的钟面 */
function onDial(v: number): number {
  return ((v - 1) % DIAL + DIAL) % DIAL + 1;
}

@Component
export struct GModuloClock {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private quiz: string = '';
  @State private face: string = '🕐';
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private nextTo: number = -1;
  private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GModuloClock')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
  }

  private reset(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
    this.round = 1;
    this.right = 0;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG(TG(TG('钟面只有 1~12 点：转满 12 点就回到 1 点')));
    this.ask();
  }

  private ask(): void {
    const now: number = randInt(1, DIAL);
    const delta: number = randInt(1, 11);
    const forward: boolean = Math.random() < 0.6;
    const truth: number = forward ? onDial(now + delta) : onDial(now - delta);
    const pool: number[] = [onDial(truth + 1), onDial(truth - 1), onDial(truth + 3),
      onDial(truth - 3), onDial(truth + 6)];
    const opts: number[] = [truth];
    for (let i = 0; i < pool.length && opts.length < PICK; i++) {
      if (opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    this.opts = opts;
    this.ans = opts.indexOf(truth);
    this.picked = -1;
    this.face = FACES[now - 1];
    this.quiz = forward
      ? TG('现在 ') + now + TG(' 点，再过 ') + delta + TG(' 小时是几点？')
      : TG2('现在 {0} 点，{1} 小时前是几点？', now, delta);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是 {0}', String(this.opts[n])),
      TG2('The answer is {0}', String(this.opts[n])), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  /**
   * ★★★ 2026-11-08 代打「不抄答案」（解题/计算族）：
   *   原来 `this.pick(this.ans)` —— `ans` 是正确选项下标，等于抄答案。
   *   ⇒ 改成**读屏幕题面自己算**：题面里只有两个数（「现在 3 点，再过 5 小时是几点？」/「…5 小时前…」），
   *     而**"后"还是"前"写在不同语言里** ⇒ 不用措辞判断，改走**候选反查**：
   *     两个方向都算一遍（12 点表盘取模），**取在 4 个选项里出现的那个**；
   *     万一两个都在（罕见）按本款 60% 是"后"的先验取"后"。
   */
  private aiNums(s: string): number[] {
    const out: number[] = [];
    let cur: string = '';
    for (let i = 0; i < s.length; i++) {
      const ch: string = s.charAt(i);
      const isDigit: boolean = ch >= '0' && ch <= '9';
      if (isDigit) {
        cur = cur + ch;
      } else if (cur.length > 0) {
        out.push(Number.parseInt(cur, 10));
        cur = '';
      }
    }
    if (cur.length > 0) {
      out.push(Number.parseInt(cur, 10));
    }
    return out;
  }

  private aiCalc(): number {
    const ns: number[] = this.aiNums(this.quiz);
    if (ns.length < 2) {
      return -1;
    }
    const now: number = ns[0];
    const delta: number = ns[1];
    const fwd: number = onDial(now + delta);
    const bwd: number = onDial(now - delta);
    const hasF: boolean = this.opts.indexOf(fwd) >= 0;
    const hasB: boolean = this.opts.indexOf(bwd) >= 0;
    if (hasF && hasB) {
      return fwd;               // 两个都在 ⇒ 按本款"后"更常见的先验
    }
    if (hasF) {
      return fwd;
    }
    return hasB ? bwd : -1;
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    const v: number = this.aiCalc();
    if (v < 0) {
      return false;             // 两个方向都不在选项里 ⇒ 停手（不读 ans 下标）
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === v) {
        this.pick(i);
        return !this.over;
      }
    }
    return false;
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1;
      this.score = this.score + 100; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG(TG(TG('✅ 对了！')));
    } else {
      this.msg = TG('❌ 应该是 ') + this.opts[this.ans] + TG(' 点');
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.advance();
    }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) {
      return;
    }
    if (this.round >= this.diffTotal) {
      const ok: boolean = this.right >= PASS;
      this.msg = ok ? TG2('🎉 答对 {0}/{1} 题，通关！', String(this.right), String(this.diffTotal))
        : TG2('答对 {0}/{1} 题，还差一点', String(this.right), String(this.diffTotal));
      this.finish(ok);
      return;
    }
    this.round = this.round + 1;
    this.ask();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'modulo_clock',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private optBg(i: number): string {
    if (this.picked < 0) {
      return this.theme.surface;
    }
    if (i === this.ans) {
      return Palette.emerald;
    }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }

  private optInk(i: number): string {
    if (this.picked < 0) {
      return this.theme.ink;
    }
    if (i === this.ans) {
      return '#FFFFFF';
    }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.xs }) {
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({

        showHint: true,

        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },

        demoOn: false,

        disabled: this.demoId >= 0,

        autoOn: this.autoId >= 0

      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG(TG('第几题')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() }).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.right + '/' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(this.face).fontSize(FontSize.hero)
        Text(this.quiz).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.emerald).textAlign(TextAlign.Center)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Column({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Row({ space: Space.sm }) {
            Text(String(i + 1)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.inkFaint)
            Text(TG2("{0} 点", String(this.opts[i]))).fontSize(FontSize.xl).minFontSize(13).maxFontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.optInk(i)).layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').height(Cell.of(Bp.isShort() ? 34 : 50)).padding({ left: Space.md, right: Space.md }).backgroundColor(this.optBg(i)).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
            Haptics.tick();
            this.pick(i);
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L382'; })
          .onBlur(() => { if (this.tvFocus === 'L382') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L382'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(i); }); })
        }, (i: number) => 'mc' + i)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%').animation({ duration: Motion.fast, curve: Motion.snap() }).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      // ★ 演示条（共用组件；未演示时高度为 0，不占位）

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.emerald).borderRadius(Radius.md).width('100%').height(Cell.of(Bp.isShort() ? 34 : 46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L411'; })
      .onBlur(() => { if (this.tvFocus === 'L411') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L411'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
