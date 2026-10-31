/**
 * 整体局部（id: navon_hierarchical）—— 大图是个字母，小图又是另一个字母，两问都要答 📐
 * 12 题，每题两问全对才得分；答对 ≥ 8 题通关。进度：题号 / 答对 / 剩余秒数
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 7;
const GAP: number = 2;
const ROUNDS: number = 12;
const WIN: number = 8;
const LIMIT: number = 90;
const TICK: number = 1000;

function letter(ch: string): boolean[] {
  const g = (s: string): boolean[] => s.split('').map((c: string) => c === '1');
  if (ch === 'a') {
    return g('1110001000101111100010001');
  }
  if (ch === 'h') {
    return g('1000110001111111000110001');
  }
  return g('1111110000100001000011111');
}

function flipY(m: boolean[]): boolean[] {
  const o: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      o[r * N + c] = m[(N - 1 - r) * N + c];
    }
  }
  return o;
}

interface Round {
  global: string;
  local: string;
  cell: boolean[];
}

function makeRound(): Round {
  const gs: string[] = ['a', 'h', 'e'];
  const gi: number = Math.floor(Math.random() * gs.length);
  const globalCh: string = gs[gi];
  let localCh: string = gs[Math.floor(Math.random() * gs.length)];
  if (localCh === globalCh) {
    localCh = globalCh === 'a' ? 'e' : 'a';
  }
  const glob: boolean[] = letter(globalCh);
  const small: boolean[] = letter(localCh);
  let other: boolean[] = flipY(small);
  if (Math.random() < 0.3) {
    other = small;
  }
  const cell: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let i = 0; i < N * N; i++) {
    cell[i] = glob[i] ? small[i] : other[i];
  }
  const out: Round = { global: globalCh, local: localCh, cell: cell };
  return out;
}

@Component
export struct GNavonHierarchical {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;
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
  @State private cell: boolean[] = []; @State private globalCh: string = 'a';
  @State private localCh: string = 'h'; @State private gi: number = -1; @State private li: number = -1;
  @State private round: number = 1; @State private right: number = 0; // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GNavonHierarchical')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); this.clearNext(); }
  private clearNext(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private stopTimer(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.stopTimer();
    this.clearNext();
    this.round = 1;
    this.right = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  private nextRound(): void {
    const r: Round = makeRound();
    this.cell = r.cell;
    this.globalCh = r.global;
    this.localCh = r.local;
    this.gi = -1;
    this.li = -1;
    this.msg = TG('大图形是什么字母？小图形又是什么字母？');
    if (this.timer < 0) {
      this.timer = setInterval(() => {
        if (this.done || this.over) { return; }
        const used: number = Math.floor((Date.now() - this.startAt) / 1000);
        this.left = Math.max(0, LIMIT - used);
        if (this.left === 0) {
          this.over = true;
          this.done = true;
          this.won = this.right >= WIN;
          this.msg = TG2('⏰ 时间到 · 答对 {0}/{1}', String(this.right), String(ROUNDS));
          this.stopTimer();
          this.finish();
        }
      }, TICK);
    }
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
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    const gs: string[] = ['a', 'h', 'e'];
    if (this.gi < 0) {
      this.pickGlobal(gs.indexOf(this.globalCh));
      return !this.over;
    }
    if (this.li < 0) {
      this.pickLocal(gs.indexOf(this.localCh));
      return !this.over;
    }
    return true;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const g: string = this.globalCh.toUpperCase();
    const l: string = this.localCh.toUpperCase();
    if (this.gi < 0) {
      return Hint.make([],
        TG2('整体（大图形）是字母 {0}；每个小图形拼的是 {1}', g, l),
        TG2('The global shape is {0}; the local shape is {1}', g, l), t0);
    }
    return Hint.make([],
      TG2('局部（小图形）是字母 {0}', l),
      TG2('The local shape is {0}', l), t0);
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

  private pickGlobal(i: number): void {
    if (this.over || this.gi >= 0) { return; }
    this.gi = i;
    this.judge();
  }
  private pickLocal(i: number): void {
    if (this.over || this.li >= 0) { return; }
    this.li = i;
    this.judge();
  }
  private judge(): void {
    if (this.gi < 0 || this.li < 0) { return; }
    const gs: string[] = ['a', 'h', 'e'];
    const okG: boolean = gs[this.gi] === this.globalCh;
    const okL: boolean = gs[this.li] === this.localCh;
    if (okG && okL) {
      this.right = this.right + 1;
      this.msg = TG2('✅ 大 {0} · 小 {1}', this.globalCh.toUpperCase(), this.localCh.toUpperCase());
    } else {
      this.msg = TG2('❌ 真相：大 {0} · 小 {1}', this.globalCh.toUpperCase(), this.localCh.toUpperCase());
    }
    this.clearNext();
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= ROUNDS) {
        this.over = true;
        this.done = true;
        this.won = this.right >= WIN;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(ROUNDS));
        this.stopTimer();
        this.finish();
        return;
      }
      this.round = this.round + 1;
      this.nextRound();
    }, 900);
  }
  private finish(): void {
    const r: GameResult = {
      gameId: 'navon_hierarchical', solved: this.won,
      score: this.right * 110 + (this.won ? 220 : 0),
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /**
   * 棋盘边长(vp)：宽度与可用高度取小者 —— 不许 aspectRatio 自行决定高度。
   *
   * ★★★ 2026-10-30 为什么改：原来是 `.width('68%')` + `.aspectRatio(1)`，
   *   **没有任何高度约束**：平板横屏 853×533 上 68% × 813 ≈ 553vp 宽
   *   （813 = 853 − 左右 padding 各 20），aspectRatio 把高也锁成 553vp，
   *   而这块地方真正能用的高只有 ~425vp（533 − 顶栏 88 − 底 padding 20）
   *   ⇒ **溢出 1.30 倍**：
   *   下面的按钮/状态被挤出屏外，点不到。
   *   （第 452 轮只扫了 `width('100%')` 那一族，`width('8x%')` 这一族一直漏着）
   *
   * reserve 怎么算（本文件）：
   *   顶栏 88 + 底 padding 20 + 信息行 56（实测：卡片上下 padding 10 + 两行字）
   *   + 38（提示/AI 代打条，在棋盘上方）+ 板下 5 行 = 状态文字 20 + 大图形按钮行 42 + 小图形按钮行 42 + 重开按钮 46 + 判定说明 17 = 167
   *   + 子元素间隙：8 个子元素 ⇒ 7 × 10vp = 70
   *   ⇒ reserve = 88 + 20 + 56 + 38 + 167 + 70 = 439
   *   · 手机竖 420×744 ⇒ min(380, 305) = 305
   *   · 平板横 853×533 ⇒ min(813, 94) = 160
   *   · 平板竖 800×1280 ⇒ min(768, 841) = 768
   * ⚠️ 外层 Column 的间隙是 Space.sm=10（其他文件是 Space.md=16），所以这里是 7 × 10。
   *   ⚠️ 平板横算出来只有 94vp，低于 160 下限 ⇒ 取 160；
   *      533vp 高确实排不下这么多控件，底部仍溢出约 66vp，
   *      但棋盘本身不再暴涨（原来 553vp）。
   */
  private boardPx(reserve: number): number {
    const w: number = Math.max(160, Bp.width - 40);
    const h: number = Math.max(160, Bp.height - reserve);
    return Math.min(w, h);
  }

  build() {
    // ★ 2026-10-30：内容总高在 533vp 横屏上超出（reserve 已触底）
    //   ⇒ **套 Scroll**：超高时可滚，棋盘尺寸不再受"必须一屏装下"约束。
    Scroll() {
      Column({ space: Space.sm }) {
        // ★ 演示条（共用组件；未演示时高度为 0，不占位）
        DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
        HintBar({
          showHint: true,
          onHintTap: () => { this.askHint(); },
          onAutoTap: () => { this.askAuto(); },
          demoOn: false,
          autoOn: this.autoId >= 0
        })
        Row({ space: Space.sm }) {
          Column({ space: Space.xs }) {
          Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
          Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }
        .width('100%')
        Column({ space: GAP }) {
          ForEach([0, 1, 2, 3, 4, 5, 6], (r: number) => {
            Row({ space: GAP }) {
              ForEach([0, 1, 2, 3, 4, 5, 6], (c: number) => {
                Stack() {
                Text('■').accessibilityLevel('no')
                .fontSize(FontSize.xs)
                .fontColor(this.cell[(r * N + c)] ? Palette.rose : this.theme.surfaceAlt)
                }
                .layoutWeight(1)
                .aspectRatio(1)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => 'c' + c)
            }
            .width('100%')
          }, (r: number) => 'r' + r)
        }
        // ★ 2026-10-30：宽高都从「可用高度」反推（见 boardPx 注释），不再让 aspectRatio 决定高度
        .width(this.boardPx(439))
        .height(this.boardPx(439))
        .alignSelf(ItemAlign.Center)
        .padding(Space.xs)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        Text(this.msg)
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
          .width('100%')
          .textAlign(TextAlign.Center)
        Row({ space: Space.sm }) {
        Text((TG('大图形（整体轮廓）')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width(88)
        ForEach([0, 1, 2], (i: number) => {
        Button(['A', 'H', 'E'][(i)])
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.letterBg((i), ((true))))
        .borderRadius(Radius.sm)
        .layoutWeight(1)
        .height(Cell.of(42))
        .scale({ x: this.pickedNow((i), ((true))) ? Motion.pressScale : 1, y: this.pickedNow((i), ((true))) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        if (((true))) {
        this.pickGlobal((i));
        } else {
        this.pickLocal((i));
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (((true))) { this.pickGlobal((i)); } else { this.pickLocal((i)); } }); })
        }, (i: number) => 'k' + i)
        }
        .width('100%')
        Row({ space: Space.sm }) {
        Text((TG('小图形（组成小块）')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width(88)
        ForEach([0, 1, 2], (i: number) => {
        Button(['A', 'H', 'E'][(i)])
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.letterBg((i), ((false))))
        .borderRadius(Radius.sm)
        .layoutWeight(1)
        .height(Cell.of(42))
        .scale({ x: this.pickedNow((i), ((false))) ? Motion.pressScale : 1, y: this.pickedNow((i), ((false))) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        if (((false))) {
        this.pickGlobal((i));
        } else {
        this.pickLocal((i));
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (((false))) { this.pickGlobal((i)); } else { this.pickLocal((i)); } }); })
        }, (i: number) => 'k' + i)
        }
        .width('100%')
        Button(this.over ? TG('再来一局') : TG('重开'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
          .borderRadius(Radius.md)
          .width('100%')
          .height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Text(TG('判定：12 题里两问全对 ≥ 8 题 · 90 秒内完成'))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .onTouch((e: TouchEvent) => {
        // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
        if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
      })
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }




  private pickedNow(i: number, isGlobal: boolean): boolean {
    return isGlobal ? this.gi === i : this.li === i;
  }
  private letterBg(i: number, isGlobal: boolean): string {
    if (!this.pickedNow(i, isGlobal)) {
      return Palette.primary;
    }
    const gs: string[] = ['a', 'h', 'e'];
    const truth: string = isGlobal ? this.globalCh : this.localCh;
    return gs[i] === truth ? Palette.emerald : Palette.rose;
  }
}
