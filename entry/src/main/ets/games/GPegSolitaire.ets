/**
 * 孔明棋（Peg Solitaire）—— 跳吃剩一颗
 *
 * 规则：点一颗棋子选中，再点同一直线隔一格的空位 ⇒ 跳过去，被跳过的棋子拿掉。
 * 结算：全盘没有任何可跳的走法时结算；只剩 1 颗 ⇒ 通关。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';

const SIZE: number = 7;
const CELLS: number = SIZE * SIZE;
const VOID: number = -1;      // 不在棋盘上
const HOLE: number = 0;       // 空位
const PEG: number = 1;        // 有棋子
const START_PEGS: number = 32;
const GAP: number = 2;
const ROW: number[] = [0, 1, 2, 3, 4, 5, 6];
/** 四个跳向（行列增量） */
const DIRS: number[][] = [[-1, 0], [1, 0], [0, -1], [0, 1]];

function at(r: number, c: number): number {
  return r * SIZE + c;
}

/** 标准十字棋盘：四个角的 2×2 是不在盘上的 */
function onBoard(r: number, c: number): boolean {
  if (r < 0 || r >= SIZE || c < 0 || c >= SIZE) {
    return false;
  }
  const rFar: boolean = r < 2 || r > 4;
  const cFar: boolean = c < 2 || c > 4;
  return !(rFar && cFar);
}

@Component
export struct GPegSolitaire {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
  @State private autoId: number = -1;
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private hintMsg: string = '';
  @State private hintFrom: number = -1;
  @State private hintTo: number = -1;
  private memoHit: number = 0;
  @State private sel: number = -1;
  @State private dests: number[] = [];
  // ★ 难度作用到玩法（本局次数/起始量按难度换算）
  private total: number = GameDiff.livesNow(START_PEGS);
  @State private pegs: number = 0;
  @State private steps: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示（项目 C）：每款游戏**只演一次**（Hint.demoOnce 落盘）
    //   ★ 2026-10-29 记：API 是 `Hint.demoOnce('类名')`，不是 ProgressStore.demoOnce
    if (Hint.demoOnce('GPegSolitaire')) {
      this.demoStart();
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.total = GameDiff.livesNow(START_PEGS);
    this.reset();
  }

  private reset(): void {
    const a: number[] = [];
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        a.push(onBoard(r, c) ? PEG : VOID);
      }
    }
    a[at(3, 3)] = HOLE;                  // 正中央先空一格
    this.cells = a;
    this.sel = -1;
    this.dests = [];
    this.pegs = this.total;
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
  }

  /** 从 p 出发的所有合法落点 */
  private legalDests(p: number): number[] {
    const out: number[] = [];
    const r: number = Math.floor(p / SIZE);
    const c: number = p % SIZE;
    for (let k = 0; k < DIRS.length; k++) {
      const dr: number = DIRS[k][0];
      const dc: number = DIRS[k][1];
      const mr: number = r + dr;
      const mc: number = c + dc;
      const tr: number = r + dr * 2;
      const tc: number = c + dc * 2;
      if (!onBoard(tr, tc)) {
        continue;
      }
      if (this.cells[at(mr, mc)] !== PEG) {
        continue;
      }
      if (this.cells[at(tr, tc)] !== HOLE) {
        continue;
      }
      out.push(at(tr, tc));
    }
    return out;
  }

  private anyMove(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (this.cells[i] === PEG && this.legalDests(i).length > 0) {
        return true;
      }
    }
    return false;
  }

  private tap(i: number): void {
    if (this.over || this.cells[i] === VOID) {
      return;
    }
    if (this.cells[i] === PEG) {
      this.sel = i;
      this.dests = this.legalDests(i);
      return;
    }
    const from: number = this.sel;
    if (from < 0 || this.dests.indexOf(i) < 0) {
      return;
    }
    const next: number[] = this.cells.slice();
    const mid: number = at(Math.floor((Math.floor(from / SIZE) + Math.floor(i / SIZE)) / 2),
      Math.floor((from % SIZE + i % SIZE) / 2));
    next[from] = HOLE;
    next[mid] = HOLE;
    next[i] = PEG;
    this.cells = next;
    this.pegs--;
    this.steps++;
    this.sel = -1;
    this.dests = [];
    if (!this.anyMove()) {
      this.over = true;
      this.won = this.pegs === 1;
      this.finish(this.won);
    }
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const score: number = solved
      ? Math.max(100, 800 - this.steps * 15)
      : (START_PEGS - this.pegs) * 20;
    const r: GameResult = {
      gameId: 'peg_solitaire',
      solved: solved,
      score: score,
      durationMs: Date.now() - this.startAt,
      levelReached: START_PEGS - this.pegs + 1
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ═══════════ 提示 / AI 代打（项目 A · B）═══════════
  //
  // 孔明棋要给出「能赢的那一步」必须真搜索 —— 局面 32 颗棋子、31 步。
  // 做法：DFS + 失败记忆化（canWin=false 缓存），**带硬预算**，超了就退回"任意合法步"。
  //   ★ 预算必须有：不设上限的搜索会让 UI 冻住（这是孔明棋最容易踩的坑）。
  private solveNodes: number = 0;

  /** 一局最多 31 步 ⇒ 预算 4 万节点约几十毫秒 */
  private static readonly SOLVE_BUDGET: number = 40000;

  /** 从 b 出发，把「能一路赢到只剩一颗」的走法按顺序填进 path；赢不了返 false */
  private canWin(b: number[], path: number[], memo: Map<string, boolean>): boolean {
    this.solveNodes = this.solveNodes + 1;
    if (this.solveNodes > GPegSolitaire.SOLVE_BUDGET) {
      return false;
    }
    let pegs: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (b[i] === PEG) {
        pegs = pegs + 1;
      }
    }
    if (pegs === 1) {
      return true;
    }
    const key: string = b.join('');
    const cached: boolean | undefined = memo.get(key);
    if (cached !== undefined) {
      return cached;
    }
    for (let i = 0; i < CELLS; i++) {
      if (b[i] !== PEG) {
        continue;
      }
      const r: number = Math.floor(i / SIZE);
      const c: number = i % SIZE;
      for (let k = 0; k < DIRS.length; k++) {
        const mr: number = r + DIRS[k][0];
        const mc: number = c + DIRS[k][1];
        const tr: number = r + DIRS[k][0] * 2;
        const tc: number = c + DIRS[k][1] * 2;
        if (!onBoard(tr, tc)) {
          continue;
        }
        const mi: number = at(mr, mc);
        const ti: number = at(tr, tc);
        if (b[mi] !== PEG || b[ti] !== HOLE) {
          continue;
        }
        b[i] = HOLE;
        b[mi] = HOLE;
        b[ti] = PEG;
        path.push(i * 100 + ti);
        if (this.canWin(b, path, memo)) {
          return true;
        }
        path.pop();
        b[i] = PEG;
        b[mi] = PEG;
        b[ti] = HOLE;
      }
    }
    memo.set(key, false);
    return false;
  }

  /** 求一条能赢的完整走法（空数组 = 求不出） */
  private solveNow(): number[] {
    this.solveNodes = 0;
    const path: number[] = [];
    const memo: Map<string, boolean> = new Map<string, boolean>();
    const b: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      b.push(this.cells[i]);
    }
    const ok: boolean = this.canWin(b, path, memo);
    return ok ? path : [];
  }

  /** 任意一个合法走法（求解失败时的兜底，保证代打还能推进） */
  private anyLegalMove(): number {
    for (let i = 0; i < CELLS; i++) {
      if (this.cells[i] !== PEG) {
        continue;
      }
      const ds: number[] = this.legalDests(i);
      if (ds.length > 0) {
        return i * 100 + ds[0];
      }
    }
    return -1;
  }

  /** 「提示」：点亮一步（优先给能赢的那一步） */
  private askHint(): void {
    Haptics.tap();
    if (this.over || this.won) {
      this.hintMsg = TG('这局已经结束，点「重开」再来一局');
    } else {
      const sol: number[] = this.solveNow();
      const mv: number = sol.length > 0 ? sol[0] : this.anyLegalMove();
      if (mv < 0) {
        this.hintMsg = TG('没有可跳的走法了');
      } else {
        this.hintFrom = Math.floor(mv / 100);
        this.hintTo = mv % 100;
        const fr: number = Math.floor(this.hintFrom / SIZE) + 1;
        const fc: number = this.hintFrom % SIZE + 1;
        const tr2: number = Math.floor(this.hintTo / SIZE) + 1;
        const tc2: number = this.hintTo % SIZE + 1;
        // ★ TG2 最多 3 个占位符 ⇒ 起点/终点各自拼成一个"行·列"字符串
        const fromTxt: string = Digits(String(fr), this.langCode) + '·' + Digits(String(fc), this.langCode);
        const toTxt: string = Digits(String(tr2), this.langCode) + '·' + Digits(String(tc2), this.langCode);
        this.hintMsg = TG2('从 {0} 跳到 {1}', fromTxt, toTxt);
      }
    }
    setTimeout(() => {
      this.hintMsg = '';
      this.hintFrom = -1;
      this.hintTo = -1;
    }, 4200);
  }

  /** 走一步 mv = from*100+to；返回是否成功 */
  private doMove(mv: number): boolean {
    const from: number = Math.floor(mv / 100);
    const to: number = mv % 100;
    const fr: number = Math.floor(from / SIZE);
    const fc: number = from % SIZE;
    const tr2: number = Math.floor(to / SIZE);
    const tc2: number = to % SIZE;
    const mr: number = (fr + tr2) / 2;
    const mc: number = (fc + tc2) / 2;
    if (!onBoard(mr, mc)) {
      return false;
    }
    const mi: number = at(mr, mc);
    const ti: number = at(tr2, tc2);
    if (this.cells[from] !== PEG || this.cells[mi] !== PEG || this.cells[ti] !== HOLE) {
      return false;
    }
    const nx: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      nx.push(this.cells[i]);
    }
    nx[from] = HOLE;
    nx[mi] = HOLE;
    nx[ti] = PEG;
    this.cells = nx;
    this.pegs = this.pegs - 1;
    this.steps = this.steps + 1;
    this.sel = -1;
    this.dests = [];
    if (this.pegs === 1) {
      this.won = true;
      this.over = true;
      this.finish(true);
    } else if (!this.anyMove()) {
      this.over = true;
      this.finish(false);
    }
    return true;
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

  private autoStep(): boolean {
    if (this.over || this.won) {
      this.stopAuto();
      return false;
    }
    const sol: number[] = this.solveNow();
    const mv: number = sol.length > 0 ? sol[0] : this.anyLegalMove();
    if (mv < 0) {
      this.stopAuto();
      return false;
    }
    const ok: boolean = this.doMove(mv);
    if (!ok || this.over || this.won) {
      this.stopAuto();
      return false;
    }
    return true;
  }

  // ═══════════ 演示动画（项目 C）═══════════
  private demoStart(): void {
    if (this.demoId >= 0) {
      return;
    }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private demoStep(): boolean {
    if (this.demoLeft <= 0 || this.over || this.won) {
      this.demoFinish();
      return false;
    }
    const mv: number = this.anyLegalMove();
    if (mv < 0) {
      this.demoFinish();
      return false;
    }
    this.demoLeft = this.demoLeft - 1;
    this.doMove(mv);
    return this.demoLeft > 0 && !this.over && !this.won;
  }

  /** 演示结束：**必须 reset()**（沙盒规则，成绩/记录不能被污染） */
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  /** 玩家碰了一下：停演示，但**不 reset**（他们那一下就是要开始玩） */
  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
      this.demoLeft = 0;
    }
  }

  private status(): string {
    if (this.won) {
      return TG('🎉 只剩一颗，完美通关！');
    }
    if (this.over) {
      return TG2('😵 还剩 {0} 颗，没有可跳的走法了',Digits(String(this.pegs), this.langCode));
    }
    if (this.sel >= 0) {
      return this.dests.length > 0 ? '再点绿点，跳过去' : '这颗跳不动，换一颗试试';
    }
    return TG('点棋子选中，再点绿点跳过它旁边的棋子');
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余棋子'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.pegs), this.langCode))
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
        Text(Digits(String(this.steps), this.langCode))
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
        Text((TG('可跳'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.sel >= 0 ? this.dests.length + ' 处' : '—'))
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

      Column({ space: GAP }) {
        ForEach(ROW, (r: number) => {
          Row({ space: GAP }) {
            ForEach(ROW, (c: number) => {
              Stack() {
              if (this.cells[at((r), (c))] === PEG) {
              Row()
              .width('68%')
              .aspectRatio(1)
              .backgroundColor(this.sel === at((r), (c)) ? Palette.orange : Palette.amber).animation({ duration: Motion.fast, curve: Motion.snap() })
              .borderRadius(Radius.full)
              .shadow(Shadow.card)
              } else if (this.cells[at((r), (c))] === HOLE) {
              Row()
              .width('30%')
              .aspectRatio(1)
              .backgroundColor(this.dests.indexOf(at((r), (c))) >= 0 ? Palette.emerald : this.theme.line)
              .borderRadius(Radius.full)
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              // ★★ 2026-10-14 修复【死动画】：原来读的都是常量
              //    现在绑【可跳目标】⇒ 目标格弹大一点（动画真的活了）
              .scale({
                x: this.dests.indexOf(at((r), (c))) >= 0 ? 1.1 : 1,
                y: this.dests.indexOf(at((r), (c))) >= 0 ? 1.1 : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap(at((r), (c)));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(at((r), (c))); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★★★ 2026-10-29 真机抓到（和数独同一个坑）：
      //   棋盘的格子用 `aspectRatio(1)` ⇒ **高度被宽度锁死**，
      //   把「提示/AI 代打」那行挤到屏幕最底（y=2226 / 屏高 2232，离底只有 6px）
      //   ⇒ 被系统手势区吃掉 ⇒ **点不动**。
      // ⇒ 给棋盘限高，让它让出空间。
      .constraintSize({ maxHeight: '50%' })
      .padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#F1E7D0')
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.status())
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('目标：最后只剩 1 颗（中央开局，32 颗）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      // 提示文字（点「提示」或代打时显示）
      if (this.hintMsg.length > 0) {
        Text(this.hintMsg)
          .fontSize(FontSize.xs)
          .fontColor(this.theme.ink)
          .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.sm)
          .margin({ bottom: Space.xs })
      }

      // ★ 提示 / AI 代打 / 演示 三合一（项目 A·B·C 统一入口）
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0,
        demoOn: this.demoId >= 0
      })
    }
    .width('100%')
    .height('100%')
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    // ★ 底部安全区：手指区会吃掉贴底的按钮（数独那次踩过）
    .padding({ bottom: 20 })
    .justifyContent(FlexAlign.Start)
  }




}
