/**
 * 泡泡龙 —— 点一列把泡泡射上去，同色连成三个及以上就炸掉
 *
 * 玩法：底部有一个待发射的泡泡，点泡泡墙的任意一列 ⇒ 泡泡沿该列上升，停在最下面那颗泡泡的下方；
 *       落点周围同色相连 ≥ 3 颗 ⇒ 一起消除（10 分/颗 + 每团 50 分奖励）
 * 胜负：泡泡墙清空 ⇒ solved=true；发射次数用完还有泡泡 ⇒ solved=false
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { A11y } from '../core/A11y';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const COLS: number = 9;            // 列数
const ROWS: number = 9;            // 行数
const KINDS: number = 4;           // 颜色数
const SHOTS: number = 28;          // 发射次数上限
const PER_BUBBLE: number = 10;     // 每颗得分
const GROUP_BONUS: number = 50;    // 每团奖励

const BUBBLE_COLORS: string[] = [Palette.rose, Palette.sky, Palette.lime, Palette.violet];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GBubbleShooter {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private field: number[] = [];     // -1 = 空，0..KINDS-1 = 颜色
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private shot: number = 0;         // 下一颗的颜色
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法（本局次数/起始量按难度换算）
  private total: number = GameDiff.livesNow(SHOTS);
  @State private left: number = 0;
  @State private msg: string = TG('点一列，把泡泡射上去');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(ROWS);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBubbleShooter')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.total = GameDiff.livesNow(SHOTS);
    this.reset();
  }

  private idx(r: number, c: number): number {
    return r * COLS + c;
  }

  private reset(): void {
    const f: number[] = new Array<number>(ROWS * COLS).fill(-1);
    for (let r = 0; r < 3; r++) {
      for (let c = 0; c < COLS; c++) {
        f[this.idx(r, c)] = Math.floor(Math.random() * KINDS);
      }
    }
    for (let c = 0; c < COLS; c++) {
      if (Math.random() < 0.55) {
        f[this.idx(3, c)] = Math.floor(Math.random() * KINDS);
      }
      if (Math.random() < 0.25) {
        f[this.idx(4, c)] = Math.floor(Math.random() * KINDS);
      }
    }
    this.field = f;
    this.shot = Math.floor(Math.random() * KINDS);
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点一列，把泡泡射上去');
    this.startAt = Date.now();
  }

  /**
   * 泡泡沿这一列上升，停在「最下面那颗泡泡的下方」。
   * ⚠️ 必须从底往上找第一颗泡泡：开局第一行是满的，若从上往下找会立刻得到 -1（整列都射不进去）。
   * 整列为空 ⇒ 落到最底行；最底行已经有泡泡 ⇒ 这一列满了（-1）。
   */
  private landing(f: number[], c: number): number {
    for (let r = ROWS - 1; r >= 0; r--) {
      if (f[this.idx(r, c)] >= 0) {
        return r + 1 < ROWS ? r + 1 : -1;
      }
    }
    return ROWS - 1;
  }

  /** 同色四连通一团（返回格子下标数组） */
  private group(f: number[], start: number): number[] {
    const color: number = f[start];
    const seen: number[] = new Array<number>(ROWS * COLS).fill(0);
    const out: number[] = [];
    const stack: number[] = [start];
    seen[start] = 1;
    while (stack.length > 0) {
      const cur: number = stack[stack.length - 1];
      stack.pop();
      out.push(cur);
      const r: number = Math.floor(cur / COLS);
      const c: number = cur % COLS;
      const nb: number[] = [];
      if (c > 0) {
        nb.push(cur - 1);
      }
      if (c < COLS - 1) {
        nb.push(cur + 1);
      }
      if (r > 0) {
        nb.push(cur - COLS);
      }
      if (r < ROWS - 1) {
        nb.push(cur + COLS);
      }
      for (let i = 0; i < nb.length; i++) {
        const n: number = nb[i];
        if (seen[n] === 0 && f[n] === color) {
          seen[n] = 1;
          stack.push(n);
        }
      }
    }
    return out;
  }

  private countLeft(f: number[]): number {
    let n: number = 0;
    for (let i = 0; i < f.length; i++) {
      if (f[i] >= 0) {
        n++;
      }
    }
    return n;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
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
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
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

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.bestCol() < 0) {
      return true;
    }
    this.fire(this.bestCol());
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 没有现成答案 ⇒ 预演：每列都试打一次（landing + group），挑能连上最多同色的
  /** 最该打的列（满列跳过；全满返回 -1） */
  private bestCol(): number {
    const f: number[] = this.field.slice();
    let best: number = -1;
    let bestN: number = -1;
    for (let c = 0; c < COLS; c++) {
      const row: number = this.landing(f, c);
      if (row < 0) {
        continue;
      }
      const t: number[] = f.slice();
      const at: number = this.idx(row, c);
      t[at] = this.shot;
      const n: number = this.group(t, at).length;
      if (n > bestN) {
        bestN = n;
        best = c;
      }
    }
    return best;
  }

  /** 提示：报打第几列、能连几颗 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const c: number = this.bestCol();
    if (c < 0) {
      return Hint.none('none');
    }
    const f: number[] = this.field.slice();
    const row: number = this.landing(f, c);
    const t: number[] = f.slice();
    const at: number = this.idx(row, c);
    t[at] = this.shot;
    const n: number = this.group(t, at).length;
    return Hint.make([at],
      TG2('打第 {0} 列 —— 能连 {1} 颗', String(c + 1), String(n)),
      TG2('Fire column {0} — joins {1} bubbles', String(c + 1), String(n)), t0);
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

  private fire(c: number): void {
    if (this.over) {
      return;
    }
    const f: number[] = this.field.slice();
    const row: number = this.landing(f, c);
    if (row < 0) {
      this.msg = TG('这一列满了，换一列');
      return;
    }
    const at: number = this.idx(row, c);
    f[at] = this.shot;
    this.left--;

    const g: number[] = this.group(f, at);
    if (g.length >= 3) {
      for (let i = 0; i < g.length; i++) {
        f[g[i]] = -1;
      }
      const gained: number = g.length * PER_BUBBLE + GROUP_BONUS;
      this.score += gained; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2("炸掉 {0} 颗，+{1} 分", g.length, gained);
    } else {
      this.msg = TG('粘住了，凑够 3 颗同色才会炸');
    }

    this.field = f;
    this.shot = this.pickColor(f);

    if (this.countLeft(f) === 0) {
      this.over = true;
      this.won = true;
      this.msg = TG('🎉 泡泡墙清空！');
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.left <= 0) {
      this.over = true;
      this.won = false;
      this.msg = TG2('发射次数用完，还剩 {0} 颗', this.countLeft(f));
      this.finish(false);
      return;
    }
  }

  /** 下一颗的颜色只在场上还存在的颜色里挑（避免死色） */
  private pickColor(f: number[]): number {
    const alive: number[] = [];
    for (let i = 0; i < f.length; i++) {
      if (f[i] >= 0 && alive.indexOf(f[i]) < 0) {
        alive.push(f[i]);
      }
    }
    if (alive.length === 0) {
      return Math.floor(Math.random() * KINDS);
    }
    return alive[Math.floor(Math.random() * alive.length)];
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'bubble_shooter',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: SHOTS - this.left
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 每格边长（vp）：按「可用高度 / 行数」算，不按宽度算
   *  ★★★ 2026-10-30（平板横屏 853×533 真机实测）：
   *    原来只用 `.layoutWeight(1) + aspectRatio(1)`：
   *      每格宽 = 屏宽/9 ≈ 88vp ⇒ 每格高也 88vp ⇒ **9 行 = 792vp**，
   *      远超可用高度（约 400vp）⇒ 气泡网格**溢出，压到三张信息卡上**，
   *      把「得分 / 剩余 / 剩余发射」的数字全遮住。
   *    ⇒ 改成按高度算：每格 ≤ 可用高度/9。
   *    ⚠️ 试过 `.constraintSize({maxHeight:'100%'})` —— 溢出是没了，
   *      但格子在 `layoutWeight` 压扁的行里变得**极小**（挤在左上角），更糟。
   */
  private cellPx(): number {
    // 9 行 + 8 个 2vp 间隙 ⇒ 每格 = (可用高 - 间隙) / 9
    const gap: number = 2 * (ROWS - 1);
    const avail: number = Math.max(120, Bp.height * 0.30);   // 横屏 533 ⇒ 160vp
    return Math.max(10, (avail - gap) / ROWS);
  }

  build() {
    Column({ space: Space.sm }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
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
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.countLeft(this.field)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余发射'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.left), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rows, (c: number) => {
              Stack() {
              if (this.field.length > (this.idx(r, c)) && this.field[(this.idx(r, c))] >= 0) {
              Row()
              .width('86%')
              .aspectRatio(1)
              .backgroundColor(BUBBLE_COLORS[this.field[(this.idx(r, c))]])
              .borderRadius(Radius.full)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              // ★★★ 2026-10-31 色盲支持：气泡是**纯色圆**，红绿色盲无法区分
              //   ⇒ 按颜色下标画一个字母（A11y 统一 8 色→A/B/C…）
              //   白色 + 阴影，在任何底色上都看得清（见 A11y.glyphInk 的注释）
              //   字号按格子边长自动夹在 8~20，不会破坏色块观感。
              Text(A11y.glyph(this.field[(this.idx(r, c))]))
                .fontSize(A11y.glyphSize(this.cellPx()))
                .fontColor(A11y.glyphInk(this.field[(this.idx(r, c))]))
                .textShadow(A11y.glyphShadow())
                .fontWeight(FontWeight.Bold)
              }
              }
              .width(this.cellPx())
              .height(this.cellPx())
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.fire((c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.fire((c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      // 容器按内容高度（不再 layoutWeight ⇒ 不会把行压扁）
      .clip(true)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      // 待发射的泡泡
      Row({ space: Space.sm }) {
        Text(TG('待发射')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Row()
          .width(34)
          .height(Cell.of(34))
          .backgroundColor(BUBBLE_COLORS[this.shot])
          .borderRadius(Radius.full)
        Text(TG('点上面任意一列把它射出去'))
          .fontSize(FontSize.xs)
          .fontColor(this.theme.inkSoft)
          .layoutWeight(1)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG2('同色连 3 颗起炸；把全场炸光通关，{0} 次发射用完还有剩就算输',Digits(String(SHOTS), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
