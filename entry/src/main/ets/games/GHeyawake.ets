/**
 * 数间（Heyawake）🧩
 *
 * 规则：把一些格子涂黑，满足 ——
 *   ① 每个分区内黑格数 = 角上的数字；
 *   ② 黑格之间不能上下左右相邻；
 *   ③ 所有白格必须连成一片；
 *   ④ 一行/一列里连续的白格不能跨越两条以上分区边界。
 * 胜负：四条全满足 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 6;
const MAX_MOVES: number = 120;
const TINTS: string[] = ['#FEF3C7', '#DBEAFE', '#DCFCE7', '#FCE7F3', '#EDE9FE', '#CFFAFE'];
const TINTS_DARK: string[] = ['#3F3417', '#16304D', '#14361F', '#43172C', '#2A1F4D', '#0E3A42'];

interface HeyaGen {
  room: number[];
  black: boolean[];
}

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

/** 递归切分矩形，得到 4~6 个分区 */
function heyaRooms(): number[] {
  const rects: number[] = [0, 0, N, N];
  const target: number = 4 + Math.floor(Math.random() * 3);
  let guard: number = 0;
  while (rects.length / 4 < target && guard < 40) {
    guard++;
    let best: number = -1;
    let bestArea: number = -1;
    for (let i = 0; i < rects.length / 4; i++) {
      const h: number = rects[i * 4 + 2];
      const w: number = rects[i * 4 + 3];
      if (h < 2 && w < 2) {
        continue;
      }
      const a: number = h * w;
      if (a > bestArea) {
        bestArea = a;
        best = i;
      }
    }
    if (best < 0) {
      break;
    }
    const r0: number = rects[best * 4];
    const c0: number = rects[best * 4 + 1];
    const h: number = rects[best * 4 + 2];
    const w: number = rects[best * 4 + 3];
    const vert: boolean = w >= 2 && (h < 2 || Math.random() < 0.5);
    if (vert) {
      const cut: number = 1 + Math.floor(Math.random() * (w - 1));
      rects[best * 4 + 3] = cut;
      rects.push(r0, c0 + cut, h, w - cut);
    } else {
      const cut: number = 1 + Math.floor(Math.random() * (h - 1));
      rects[best * 4 + 2] = cut;
      rects.push(r0 + cut, c0, h - cut, w);
    }
  }
  const room: number[] = new Array<number>(N * N).fill(0);
  for (let i = 0; i < rects.length / 4; i++) {
    const r0: number = rects[i * 4];
    const c0: number = rects[i * 4 + 1];
    const h: number = rects[i * 4 + 2];
    const w: number = rects[i * 4 + 3];
    for (let r = r0; r < r0 + h; r++) {
      for (let c = c0; c < c0 + w; c++) {
        room[r * N + c] = i;
      }
    }
  }
  return room;
}

/** ②③④ 三条规则（① 的每区计数在组件里单独查） */
function heyaRules(room: number[], black: boolean[]): boolean {
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      if (!black[r * N + c]) {
        continue;
      }
      if (r + 1 < N && black[(r + 1) * N + c]) {
        return false;
      }
      if (c + 1 < N && black[r * N + c + 1]) {
        return false;
      }
    }
  }
  let start: number = -1;
  for (let i = 0; i < N * N; i++) {
    if (!black[i]) {
      start = i;
      break;
    }
  }
  if (start < 0) {
    return false;
  }
  const seen: boolean[] = new Array<boolean>(N * N).fill(false);
  const st: number[] = [start];
  seen[start] = true;
  let cnt: number = 0;
  let whites: number = 0;
  for (let i = 0; i < N * N; i++) {
    if (!black[i]) {
      whites++;
    }
  }
  while (st.length > 0) {
    const k: number = st[st.length - 1];
    st.splice(st.length - 1, 1);
    cnt++;
    const r: number = Math.floor(k / N);
    const c: number = k - r * N;
    if (c > 0 && !black[k - 1] && !seen[k - 1]) {
      seen[k - 1] = true;
      st.push(k - 1);
    }
    if (c < N - 1 && !black[k + 1] && !seen[k + 1]) {
      seen[k + 1] = true;
      st.push(k + 1);
    }
    if (r > 0 && !black[k - N] && !seen[k - N]) {
      seen[k - N] = true;
      st.push(k - N);
    }
    if (r < N - 1 && !black[k + N] && !seen[k + N]) {
      seen[k + N] = true;
      st.push(k + N);
    }
  }
  if (cnt !== whites) {
    return false;
  }
  for (let r = 0; r < N; r++) {
    const rooms: number[] = [];
    for (let c = 0; c < N; c++) {
      if (black[r * N + c]) {
        if (rooms.length >= 3) {
          return false;
        }
        rooms.splice(0, rooms.length);
      } else if (rooms.indexOf(room[r * N + c]) < 0) {
        rooms.push(room[r * N + c]);
      }
    }
    if (rooms.length >= 3) {
      return false;
    }
  }
  for (let c = 0; c < N; c++) {
    const rooms: number[] = [];
    for (let r = 0; r < N; r++) {
      if (black[r * N + c]) {
        if (rooms.length >= 3) {
          return false;
        }
        rooms.splice(0, rooms.length);
      } else if (rooms.indexOf(room[r * N + c]) < 0) {
        rooms.push(room[r * N + c]);
      }
    }
    if (rooms.length >= 3) {
      return false;
    }
  }
  return true;
}

function heyaGen(): HeyaGen {
  for (let t = 0; t < 500; t++) {
    const room: number[] = heyaRooms();
    const order: number[] = [];
    for (let i = 0; i < N * N; i++) {
      order.push(i);
    }
    shuffleArr(order);
    const black: boolean[] = new Array<boolean>(N * N).fill(false);
    const target: number = 5 + Math.floor(Math.random() * 4);
    let nb: number = 0;
    for (let k = 0; k < order.length && nb < target; k++) {
      const i: number = order[k];
      const r: number = Math.floor(i / N);
      const c: number = i - r * N;
      let bad: boolean = false;
      if (c > 0 && black[i - 1]) {
        bad = true;
      }
      if (c < N - 1 && black[i + 1]) {
        bad = true;
      }
      if (r > 0 && black[i - N]) {
        bad = true;
      }
      if (r < N - 1 && black[i + N]) {
        bad = true;
      }
      if (bad) {
        continue;
      }
      black[i] = true;
      nb++;
    }
    if (nb > 0 && heyaRules(room, black)) {
      return { room: room, black: black };
    }
  }
  const room: number[] = new Array<number>(N * N).fill(0);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      room[r * N + c] = (r < 3 ? 0 : 2) + (c < 3 ? 0 : 1);
    }
  }
  return { room: room, black: new Array<boolean>(N * N).fill(false) };
}

@Component
export struct GHeyawake {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private room: number[] = [];
  @State private need: number[] = [];
  @State private labelAt: number[] = [];
  @State private black: boolean[] = [];
  /** 造局时那一版解（AI 代打与提示都用它；只记黑格） */
  private sol: boolean[] = [];
  @State private rooms: number = 0;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GHeyawake')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
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
    this.aiFill(0);
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

  private reset(): void {
    const g: HeyaGen = heyaGen();
    this.sol = g.black.slice();   // ★ 解别丢：need 是由它反推的，留着才能代打
    let rooms: number = 0;
    for (let i = 0; i < N * N; i++) {
      if (g.room[i] + 1 > rooms) {
        rooms = g.room[i] + 1;
      }
    }
    const need: number[] = new Array<number>(rooms).fill(0);
    for (let i = 0; i < N * N; i++) {
      if (g.black[i]) {
        need[g.room[i]]++;
      }
    }
    const labelAt: number[] = new Array<number>(N * N).fill(-1);
    for (let gi = 0; gi < rooms; gi++) {
      for (let i = 0; i < N * N; i++) {
        if (g.room[i] === gi) {
          labelAt[i] = gi;
          break;
        }
      }
    }
    this.room = g.room;
    this.need = need;
    this.rooms = rooms;
    this.labelAt = labelAt;
    this.black = new Array<boolean>(N * N).fill(false);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private placed(): number {
    let n: number = 0;
    for (let i = 0; i < this.black.length; i++) {
      if (this.black[i]) {
        n++;
      }
    }
    return n;
  }

  private needTotal(): number {
    let n: number = 0;
    for (let i = 0; i < this.need.length; i++) {
      n += this.need[i];
    }
    return n;
  }

  private roomOk(): number {
    let n: number = 0;
    for (let g = 0; g < this.rooms; g++) {
      let cnt: number = 0;
      for (let i = 0; i < N * N; i++) {
        if (this.room[i] === g && this.black[i]) {
          cnt++;
        }
      }
      if (cnt === this.need[g]) {
        n++;
      }
    }
    return n;
  }

  private isSolved(): boolean {
    if (this.roomOk() !== this.rooms) {
      return false;
    }
    return heyaRules(this.room, this.black);
  }


  /**
   * ★ 2026-10-23 第二期：数间提示
   * ★ 2026-10-24 第三期：改成「直接比造局时那一版解」
   *   原来的推理规则只能推「必须黑」这一种情况，几乎点不出提示；
   *   现在 reset() 把 heyaGen() 的解留在 this.sol 里（need[] 本来就是由它反推的），
   *   ⇒ 提示只要报「第一处不一样的格子该涂黑 / 该取消」即可，永远不会错。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.sol.length < N * N) { return Hint.none('none'); }
    for (let i = 0; i < N * N; i++) {
      if (this.black[i] === this.sol[i]) { continue; }
      const rr: string = String(Math.floor(i / N) + 1);
      const cc: string = String((i % N) + 1);
      if (this.sol[i]) {
        return Hint.make([i], TG2('第 {0} 行第 {1} 列涂黑', rr, cc),
          TG2('Paint row {0}, column {1} black', rr, cc), t0);
      }
      return Hint.make([i], TG2('第 {0} 行第 {1} 列不用涂黑', rr, cc),
        TG2('Leave row {0}, column {1} white', rr, cc), t0);
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格必须涂黑'));
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const b: boolean[] = this.black.slice();
    b[i] = !b[i];
    this.black = b;
    this.moves++;
    if (this.isSolved()) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'heyawake',
      solved: solved,
      score: solved ? Math.max(200, 1400 - this.moves * 10) : this.roomOk() * 120,
      durationMs: Date.now() - this.startAt,
      levelReached: this.roomOk()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** AI 用：和造局时的解比，第一处不一样的格子点一下 */
  private aiFill(_d: number): void {
    if (this.sol.length < N * N) { return; }
    for (let i = 0; i < N * N; i++) {
      if (this.black[i] !== this.sol[i]) { this.tap(i); return; }
    }
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
        Text((TG('已涂黑'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed()) + '/' + String(this.needTotal())))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('达标区'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.roomOk()) + '/' + String(this.rooms)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 1 }) {
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: 1 }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              Stack() {
              if (this.labelAt[(r * N + c)] >= 0) {
              Text(String(this.need[this.labelAt[(r * N + c)]]))
              .fontSize(FontSize.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.black[(r * N + c)] ? '#FFFFFF' : this.theme.inkSoft)
              }
              }
              .alignContent(Alignment.TopStart)
              .padding(2)
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.black[(r * N + c)] ? (this.theme.isDark ? '#0B0B0B' : '#1F2937') :
              (this.theme.isDark ? TINTS_DARK[this.room[(r * N + c)]] : TINTS[this.room[(r * N + c)]]))
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r * N + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * N + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * N + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'hw' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'hwr' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点格子涂黑 / 擦白')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .enabled(false)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(44)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
                Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('左上角小数字 = 该分区要涂黑的数量；黑格不能相邻，白格要连成一片'))
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
