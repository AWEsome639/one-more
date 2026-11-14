/**
 * 矩阵推理 —— 找规律填矩阵
 * 玩法：3×3 数阵，每行第三个数由前两个按同一规律得到；补上被挖掉的那格。
 * 胜负：60 秒内答对 8 题 ⇒ 通关；时间归零 ⇒ 失败。
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
import { Digits, Sec } from '../core/I18n';
import { Tv } from '../core/Tv';
import { AppClock } from '../core/AppClock';

const SIDE: number = 3; const CELLS: number = 9; const GOAL: number = 8;
const LIMIT: number = 60; const TICK_MS: number = 1000; const PENALTY: number = 3; const NEXT_MS: number = 900;
const ROWS: number[] = [0, 1, 2];
const OPT_IDX: number[] = [0, 1, 2, 3];
const RULE_TXT: string[] = [TG('第三个数 = 前两个数之和'), TG('第三个数 = 前两个数之积'), TG('第三个数 = 前两个数之和再加 1')];

function ri(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

function applyRule(kind: number, a: number, b: number): number {
  if (kind === 0) { return a + b; }
  if (kind === 1) { return a * b; }
  return a + b + 1;
}

@Component
export struct GMatrixReasoning {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

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
  @State private cells: number[] = [];
  @State private hole: number = -1;
  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private right: number = 0;
  @State private combo: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private rule: string = '';
  @State private msg: string = '';
  // ★ 2026-11-08 常驻结果行：反馈不再依赖显示的几秒，随时能回看上一题的对错
  @State private lastFb: string = '';
  @State private lastOk: boolean = true;
  private startAt: number = 0; private timer: number = -1;
  private nextTo: number = -1; private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMatrixReasoning')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.lastFb = ''; this.lastOk = true;   // ★ 重开清常驻结果行
    this.stop();
    this.right = 0; this.combo = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.ask();
    this.msg = TG('每行都是同一条规律 —— 先看完整的两行');
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.tick();
    }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG2('⏰ 时间到，答对 {0} 题', String(this.right)) + TG(' 题')); }
  }

  private ask(): void {
    const kind: number = ri(0, 2);
    const lo: number = kind === 1 ? 2 : 1;
    const hi: number = kind === 1 ? 6 : 9;
    const grid9: number[] = [];
    for (let r = 0; r < SIDE; r++) {
      const a: number = ri(lo, hi);
      const b: number = ri(lo, hi);
      grid9.push(a); grid9.push(b); grid9.push(applyRule(kind, a, b));
    }
    const hole: number = ri(0, CELLS - 1);
    const correct: number = grid9[hole];
    const cand: number[] = [correct + 1, correct - 1, correct + 2, correct - 2];
    if (hole % SIDE === 2) {
      cand.push(applyRule((kind + 1) % 3, grid9[hole - 2], grid9[hole - 1]));
    } else {
      cand.push(correct + ri(3, 9));
    }
    const opts: number[] = [correct];
    for (let i = 0; i < cand.length && opts.length < 4; i++) {
      if (cand[i] > 0 && opts.indexOf(cand[i]) < 0) { opts.push(cand[i]); }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i]; opts[i] = opts[j]; opts[j] = t;
    }
    this.cells = grid9; this.hole = hole; this.rule = RULE_TXT[kind];
    this.opts = opts; this.ans = opts.indexOf(correct); this.picked = -1;
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
   * ★ 2026-11-08 代打「不抄答案」：**靠规则推理，不读 ans**。
   *   3×3 格里只有 `hole` 那格是被问号盖住的；把 4 个候选逐个填进去，
   *   看哪个值能让**三行都满足同一条 `applyRule(kind)`**（kind 只有 0/1/2 三种）。
   *   ⇒ 这正是人类解题的方式（先用两行补全的行定规则，再算缺的那格）。
   *   返回选项下标；一个都凑不出（异常）返回 -1 ⇒ 调用方停手。
   */
  private aiOption(): number {
    for (let oi = 0; oi < this.opts.length; oi++) {
      const v: number = this.opts[oi];
      const g: number[] = this.cells.slice();
      g[this.hole] = v;
      for (let kind = 0; kind < 3; kind++) {
        let ok: boolean = true;
        for (let r = 0; r < 3; r++) {
          if (g[r * 3 + 2] !== applyRule(kind, g[r * 3], g[r * 3 + 1])) {
            ok = false;
            break;
          }
        }
        if (ok) {
          return oi;
        }
      }
    }
    return -1;
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    // ★ 2026-11-08 代打「不抄答案」：屏幕上是 3×3 格（`cells`，其中 `hole` 那格被问号盖住）
    //   ⇒ 把 4 个候选值逐个填进去，看哪个值能让**三行都满足同一条规则**（`applyRule` 只有 3 种）
    //     找得到就是答案；这是真正的"从已有两行推规则"，不是读答案
    const hit: number = this.aiOption();
    if (hit < 0) {
      return false;
    }
    this.pick(hit);
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
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1; this.combo = this.combo + 1;
      this.score = this.score + 60 + this.combo * 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ 答对！规律：{0}', this.rule);
    } else {
      this.combo = 0; this.score = Math.max(0, this.score - 20); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 错了，扣 {0} 秒（规律：{1}）", String(PENALTY), this.rule);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, NEXT_MS);
  }

  private advance(): void {
    // ★ 2026-11-08 常驻结果行：在加载下一题之前，把上一题的反馈存下来（窗口再短也能回看）
      const fbV: string = this.msg;
      if (fbV.indexOf('✅') >= 0 || fbV.indexOf('🎉') >= 0) { this.lastFb = fbV; this.lastOk = true; }
      else if (fbV.indexOf('❌') >= 0 || fbV.indexOf('💤') >= 0 || fbV.indexOf('😵') >= 0 || fbV.indexOf('⏰') >= 0 || fbV.indexOf('⌛') >= 0) { this.lastFb = fbV; this.lastOk = false; }

    if (this.over) { return; }
    if (this.right >= GOAL) { this.end(true, TG2('🎉 答对 {0} 题，通关！剩 {1} 秒', String(GOAL), String(this.left))); return; }
    if (this.left <= 0) { this.end(false, TG2('⏰ 时间到，答对 {0} 题', String(this.right)) + TG(' 题')); return; }
    this.ask();
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'matrix_reasoning', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + Sec())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(GOAL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(ROWS, (c: number) => { Text((r * SIDE + c) === this.hole ? '?' : String(this.cells[(r * SIDE + c)]))
            .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor((r * SIDE + c) === this.hole ? Palette.orange : this.theme.ink)
            .layoutWeight(1).aspectRatio(1).borderRadius(Radius.md)
            .backgroundColor((r * SIDE + c) === this.hole ? '#33F97316' : this.theme.surface)
            .animation({ duration: Motion.fast, curve: Motion.snap() }) }, (c: number) => 'rc' + c)
          }.width('100%')
        }, (r: number) => 'rr' + r)
      }
      .width(Math.min(Bp.width - 2 * Space.lg, Math.max(200, Bp.height - 360))).aspectRatio(1).padding(Space.sm)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      // ★ 常驻结果行：答过之后固定显示上一次对错（用全角空格占位，避免布局跳动）
      Text(this.lastFb.length > 0 && this.lastFb !== this.msg ? this.lastFb : '　')
        .fontSize(FontSize.xxs).fontColor(this.lastOk ? Palette.emerald : Palette.rose)
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        ForEach(OPT_IDX, (i: number) => { Text(String(this.opts[(i)]))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.picked < 0 ? this.theme.ink
        : ((i) === this.ans ? '#FFFFFF' : ((i) === this.picked ? '#FFFFFF' : this.theme.inkFaint)))
        .layoutWeight(1).height(Cell.of(64)).borderRadius(Radius.md).shadow(Shadow.card)
        .backgroundColor(this.picked < 0 ? this.theme.surface
        : ((i) === this.ans ? Palette.emerald : ((i) === this.picked ? Palette.rose : this.theme.surface)))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L359'; })
        .onBlur(() => { if (this.tvFocus === 'L359') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L359'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((i)); }); })
        .onClick(() => { Haptics.tick(); this.pick((i)); }) }, (i: number) => 'ro' + i)
      }.width('100%')


      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      HintBar({

        showHint: true,

        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },

        demoOn: false,

        disabled: this.demoId >= 0,

        autoOn: this.autoId >= 0

      })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L388'; })
        .onBlur(() => { if (this.tvFocus === 'L388') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L388'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：先看完整的两行推出规律，再用到缺格那一行'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
