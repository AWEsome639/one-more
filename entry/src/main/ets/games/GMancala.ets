/**
 * 播棋（Kalah 曼卡拉）—— 石子播种 ♟️
 *
 * 规则：轮到你时选一个自己的坑，把石子一颗颗撒进后面的坑（跳过对手的库）。
 *      最后一颗落进自己的库可以再来一次；落进自己的空坑则把对家正对的坑一起收走。
 * 胜负：一方六坑全空时结算，库里石子多的一方获胜
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { LanMatch, Side } from '../core/LanMatch';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const PITS: number = 6;      // 每方 6 个坑
const P_STORE: number = 6;   // 我方库
const A_STORE: number = 13;  // 对手库
const START: number = 4;     // 每坑初始石子

/**
 * ★★ 局域网对战（2026-10-13，P12）—— 走子编码与两个哨兵包
 *
 * 走子 = 一个坑号（"0".."5"，**发送方自己那一侧的编号**）。
 * 对帧映射：对方第 p 个坑 = 我这边的第 `p + 7` 个（不是镜像 12-p！）。
 *   为什么：两边是**同一个 14 格环**，各自把自己摆在 0~5、对方摆在 7~12，
 *   两个编号系正好差一个 (PITS+1)=7 的循环平移，而且**撒石方向（下标 +1 绕圈）同向**。
 *   写成镜像 12-p 会把撒石方向弄反 —— 推演过，别改。
 * 哨兵包（都借 'move' 通道，因为引擎只认 move 会翻手）：
 *   'P' 空过：只让引擎翻手、不落子 —— 播棋"最后一颗进自己库可以再走一次"时用；
 *   'R' 重开：对方收到就整盘重置（否则两边各自重开 ⇒ 棋盘不一样）。
 */
const LAN_OFFSET: number = PITS + 1;
const LAN_PASS: string = 'P';
const LAN_RESTART: string = 'R';

@Component
export struct GMancala {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 PITS=6）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private pits: number[] = [];
  @State private turn: number = 0;     // 0 = 我方，1 = 对手
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;

  private aiTimer: number = -1;
  private lastLand: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 联机对局（P12）：对方的走子 = 本局「AI 的那一步」
    LanMatch.setHandler((d: string) => {
      const pit: number = Number.parseInt(d, 10);
      if (isNaN(pit) || this.over || pit < 0 || pit >= this.pits.length || this.pits[pit] === 0) {
        return;
      }
      this.moves = this.moves + 1;
      this.applyMove(pit, 1);
      this.turn = 0;                     // 交回我方
    });
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMancala')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  aboutToDisappear(): void {
    this.clearAi();
  }

  onRestart(): void {
    // 宿主点「换一局」：联机时也要通知对方，否则两边棋盘不一样
    this.restartTap();
  }

  private clearAi(): void {
    if (this.aiTimer !== -1) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
  }

  /**
   * 本局坑数。★ 联机时**固定标准 6 坑**：难度会改坑数（简单 4 / 普通 6 / 困难 8），
   * 两边难度不同 ⇒ 坑数不同 ⇒ 走子编号对不上（大厅的 diff 广播因为 `LanMatch.begin`
   * 没传 gameId 而实际不生效）⇒ 联机必须钉死同一尺寸。
   */
  private pickSize(): number {
    return LanMatch.isActive() ? PITS : GameDiff.sizeNow(6);
  }

  private reset(): void {
    this.clearAi();
    this.diffTotal = this.pickSize();
    const p: number[] = new Array<number>(14).fill(START);
    p[P_STORE] = 0;
    p[A_STORE] = 0;
    this.pits = p;
    this.turn = 0;
    // ★ 联机：本地 turn 必须跟"轮到谁"对齐 —— 否则加入方开局会显示"轮到你"却点不动
    if (LanMatch.isActive()) {
      this.turn = LanMatch.myTurn() ? 0 : 1;
    }
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
  }

  /** 撒石：skip 是对手的库；结果写进 this.lastLand */
  private sow(p: number[], pit: number, skip: number): number[] {
    const n: number[] = p.slice();
    let stones: number = n[pit];
    n[pit] = 0;
    let pos: number = pit;
    while (stones > 0) {
      pos = (pos + 1) % 14;
      if (pos === skip) {
        continue;
      }
      n[pos] = n[pos] + 1;
      stones--;
    }
    this.lastLand = pos;
    return n;
  }

  private mine(i: number, side: number): boolean {
    return side === 0 ? (i >= 0 && i < this.diffTotal) : (i > this.diffTotal && i < A_STORE);
  }

  private applyMove(pit: number, side: number): void {
    const store: number = side === 0 ? P_STORE : A_STORE;
    const skip: number = side === 0 ? A_STORE : P_STORE;
    let n: number[] = this.sow(this.pits, pit, skip);
    const last: number = this.lastLand;
    const extra: boolean = last === store;

    if (!extra && this.mine(last, side) && n[last] === 1) {
      const opp: number = 12 - last;
      n[store] = n[store] + n[opp] + 1;
      n[opp] = 0;
      n[last] = 0;
    }
    this.pits = n;

    if (this.checkEnd()) {
      return;
    }
    if (!extra) {
      this.turn = side === 0 ? 1 : 0;
    }
  }

  private checkEnd(): boolean {
    let pEmpty: boolean = true;
    for (let i = 0; i < this.diffTotal; i++) {
      if (this.pits[i] > 0) {
        pEmpty = false;
      }
    }
    let aEmpty: boolean = true;
    for (let i = this.diffTotal + 1; i < A_STORE; i++) {
      if (this.pits[i] > 0) {
        aEmpty = false;
      }
    }
    if (!pEmpty && !aEmpty) {
      return false;
    }
    const n: number[] = this.pits.slice();
    for (let i = 0; i < this.diffTotal; i++) {
      n[P_STORE] = n[P_STORE] + n[i];
      n[i] = 0;
    }
    for (let i = this.diffTotal + 1; i < A_STORE; i++) {
      n[A_STORE] = n[A_STORE] + n[i];
      n[i] = 0;
    }
    this.pits = n;
    this.over = true;
    this.won = n[P_STORE] > n[A_STORE];
    this.finish(this.won);
    return true;
  }

  /** 对手：一眼看一步（拿到多少 + 是否连走 − 对手最好的反击） */
  private aiPick(): number {
    let best: number = -1;
    let bestVal: number = -999999;
    for (let i = this.diffTotal + 1; i < A_STORE; i++) {
      if (this.pits[i] === 0) {
        continue;
      }
      const s: number[] = this.sow(this.pits, i, P_STORE);
      const extra: boolean = this.lastLand === A_STORE;
      const gain: number = s[A_STORE] - this.pits[A_STORE];
      let opp: number = 0;
      for (let j = 0; j < this.diffTotal; j++) {
        if (s[j] === 0) {
          continue;
        }
        const s2: number[] = this.sow(s, j, A_STORE);
        const g: number = s2[P_STORE] - s[P_STORE];
        if (g > opp) {
          opp = g;
        }
      }
      const val: number = gain * 2 + (extra ? 3 : 0) - opp;
      if (val > bestVal) {
        bestVal = val;
        best = i;
      }
    }
    return best;
  }

  /**
   * 收到对方的走子（LanMatch 转进来）
   * ★ 对方第 p 个坑 ⇒ 我这边第 `p + LAN_OFFSET` 个坑，按"对手（side=1）"应用
   */
  private onRemote(d: string): void {
    if (d === LAN_RESTART) {
      this.reset();          // 对方重开 ⇒ 我也整盘重置
      return;
    }
    if (d === LAN_PASS) {
      // 空过包：只为了翻手，棋盘不动；但本地 turn 要跟着对齐
      // （连走时它是幂等的；重开时正是靠它把"该谁走"定下来）
      this.turn = LanMatch.myTurn() ? 0 : 1;
      return;
    }
    const p: number = Number.parseInt(d, 10);
    if (isNaN(p) || this.over || p < 0 || p >= this.diffTotal) {
      return;
    }
    const pit: number = p + LAN_OFFSET;
    if (pit >= A_STORE || this.pits[pit] === 0) {
      return;
    }
    this.moves = this.moves + 1;
    this.applyMove(pit, 1);   // 连走/收子/结算都由 applyMove 自己算 ⇒ 两边必然一致
  }

  /**
   * 重开（按钮与宿主「换一局」都走这里）
   * ★ 联机时必须**通知对方一起重置**，否则两边棋盘不一样；
   *   并且要把回合翻回"房主先手"——所以按"重开前轮到的是不是房主"决定要不要补一个空过包。
   */
  private restartTap(): void {
    if (!LanMatch.isActive()) {
      this.reset();
      return;
    }
    const iAmHost: boolean = LanMatch.mySide() === Side.HOST;
    const turnWasHost: boolean = iAmHost ? LanMatch.myTurn() : !LanMatch.myTurn();
    this.reset();
    LanMatch.record(LAN_RESTART);
    if (turnWasHost) {
      LanMatch.record(LAN_PASS);   // 把回合再翻回房主
    }
    // record 会翻 LanMatch 的回合 ⇒ 本地 turn 要按最终结果再对齐一次
    this.turn = LanMatch.myTurn() ? 0 : 1;
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
    if (this.turn !== 0 || this.bestPit() < 0) {
      return true;                       // 轮不到我 / 没有合法的坑 ⇒ 这一拍不动
    }
    this.playerMove(this.bestPit());
    return !this.over;
  }

  /** 代打与提示共用的选坑：拿到多少 + 是否连走 − 对手最好的反击（对手 AI 的镜像） */
  private bestPit(): number {
    let best: number = -1;
    let bestVal: number = -999999;
    for (let i = 0; i < this.diffTotal; i++) {
      if (this.pits[i] === 0) {
        continue;
      }
      const s: number[] = this.sow(this.pits, i, A_STORE);
      const last: number = this.lastLand;
      const extra: boolean = last === P_STORE;
      let gain: number = s[P_STORE] - this.pits[P_STORE];
      if (!extra && last < this.diffTotal && s[last] === 1) {
        gain = gain + s[12 - last];
      }
      let opp: number = 0;
      for (let j = this.diffTotal + 1; j < A_STORE; j++) {
        if (s[j] === 0) {
          continue;
        }
        const s2: number[] = this.sow(s, j, P_STORE);
        const g: number = s2[A_STORE] - s[A_STORE];
        if (g > opp) {
          opp = g;
        }
      }
      const val: number = gain * 2 + (extra ? 3 : 0) - opp;
      if (val > bestVal) {
        bestVal = val;
        best = i;
      }
    }
    return best;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.turn !== 0) {
      return Hint.make([], TG('等对手走完这一手，再看提示'),
        'Wait for the opponent move', t0);
    }
    const p: number = this.bestPit();
    if (p < 0) {
      return Hint.none('none');
    }
    const before: number = this.pits[P_STORE];
    const s: number[] = this.sow(this.pits, p, A_STORE);
    const last: number = this.lastLand;
    const extra: boolean = last === P_STORE;
    let add: number = s[P_STORE] - before;
    if (!extra && last < this.diffTotal && s[last] === 1) {
      add = add + s[12 - last];
    }
    const tail: string = extra ? TG('，最后一颗进自己的库 ⇒ 能再走一次') : '';
    return Hint.make([p],
      TG2('选第 {0} 个坑：这一手进库 {1} 颗{2}', String(p + 1), String(add), tail),
      'Play pit ' + String(p + 1) + ' (+' + String(add) + ' in store)', t0);
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

  private playerMove(pit: number): void {
    if (this.over || this.turn !== 0 || this.pits[pit] === 0) {
      return;
    }
    // ★ 联机：不是我的回合就不接受点击（本地 this.turn 是权威，myTurn() 再兜一层）
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      return;
    }
    this.moves = this.moves + 1;
    this.applyMove(pit, 0);
    // ★ 联机：广播这一步，**不跑 AI**（对手就是那个人）
    if (LanMatch.isActive()) {
      LanMatch.record(String(pit));
      if (!this.over && this.turn === 0) {
        // ★ 最后一颗进了自己的库 ⇒ 我还要再走一次；但 record() 已经把回合交给对方了
        //   ⇒ 补发一个"空过包"把回合换回来（对方收到只翻手、不落子）。
        LanMatch.record(LAN_PASS);
      }
      return;
    }
    const nextTurn: number = this.turn;   // 取局部变量，避免 ArkTS 把 this.turn 收窄成字面量
    if (!this.over && nextTurn === 1) {
      this.scheduleAi();
    }
  }

  private scheduleAi(): void {
    if (LanMatch.isActive()) {
      return;                    // ★ 联机时没有 AI
    }
    this.clearAi();
    this.aiTimer = setTimeout(() => {
      this.aiTimer = -1;
      this.aiTurn();
    }, 650);
  }

  private aiTurn(): void {
    if (this.over || this.turn !== 1) {
      return;
    }
    const pit: number = this.aiPick();
    if (pit < 0) {
      return;
    }
    this.applyMove(pit, 1);
    if (!this.over && this.turn === 1) {
      this.scheduleAi();
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mancala',
      solved: solved,
      score: this.pits[P_STORE] * 100 + (solved ? 200 : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.pits[P_STORE]
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
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
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('我方库'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.pits.length > 0 ? this.pits[P_STORE] : 0))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('对手库'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.pits.length > 0 ? this.pits[A_STORE] : 0))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Row({ space: Space.sm }) {
        // 对手的库（在左）
        Column({ space: Space.xs }) {
          Text(LanMatch.isActive() ? '对手' : 'AI').fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(String(this.pits.length > 0 ? this.pits[A_STORE] : 0))
            .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.orange)
        }
        .width(56)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.lg)

        Column({ space: Space.sm }) {
          Row({ space: Space.sm }) {
            ForEach([12, 11, 10, 9, 8, 7], (i: number) => {
              Column({ space: 2 }) {
              Text(String(this.pits.length > 0 ? this.pits[(i)] : 0))
              .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink)
              Text(this.pits.length > 0 && this.pits[(i)] > 0 ? '●' : '·')
              .fontSize(FontSize.xxs)
              .fontColor(false ? Palette.emerald : Palette.orange)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(false && this.turn === 0 && !this.over && this.pits[(i)] > 0
              ? '#2210B981' : this.theme.surface)
              .borderRadius(Radius.full)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (false) { this.playerMove((i)); } }); })
              .onClick(() => {
              Haptics.tick();
              if (false) {
              this.playerMove((i));
              }
              })
            }, (i: number) => 'a' + i)
          }
          .width('100%')

          Row({ space: Space.sm }) {
            ForEach(this.rowIdx(), (i: number) => {
              Column({ space: 2 }) {
              Text(String(this.pits.length > 0 ? this.pits[(i)] : 0))
              .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink)
              Text(this.pits.length > 0 && this.pits[(i)] > 0 ? '●' : '·')
              .fontSize(FontSize.xxs)
              .fontColor(true ? Palette.emerald : Palette.orange)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(true && this.turn === 0 && !this.over && this.pits[(i)] > 0
              ? '#2210B981' : this.theme.surface)
              .borderRadius(Radius.full)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (true) { this.playerMove((i)); } }); })
              .onClick(() => {
              Haptics.tick();
              if (true) {
              this.playerMove((i));
              }
              })
            }, (i: number) => 'p' + i)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        // 我方的库（在右）
        Column({ space: Space.xs }) {
          Text(TG('我')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(String(this.pits.length > 0 ? this.pits[P_STORE] : 0))
            .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
        }
        .width(56)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.lg)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.over ? (this.won ? '🎉 你的库更多，赢了！' : '这局输了，再来一局') :
        (this.turn === 0 ? '轮到你：点一个自己的坑撒石子'
          : (LanMatch.isActive() ? '联机：等对手走子…' : '对手思考中…')))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.lime).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.restartTap(); }); })
        .onClick(() => {
          Haptics.tap();
          this.restartTap();
        })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
  }




}
