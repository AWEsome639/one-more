/**
 * 数方 shikaku（5×5）—— 把整盘切成若干矩形，每块矩形里恰有一个数字，且格数等于该数字
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：25 格全部被合法矩形覆盖 ⇒ solved:true；非法尝试 3 次 ⇒ solved:false
 * 进度：已覆盖格数 ／ 错手 ／ 得分
 *
 * 操作：点第一格 → 点对角格圈出矩形；点已圈好的格子即撤销该矩形
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，原来只开 25）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;

/** 3 关提示（数字 = 所属矩形面积，0 = 无提示） */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    1,0,0,0,0,
    1,0,0,8,0,
    0,0,0,0,0,
    2,0,9,0,3,
    1,0,0,0,0
  ],
  // 第 2 关
  [
    0,0,0,0,0,
    10,0,0,0,0,
    0,5,0,0,0,
    0,5,0,0,0,
    1,1,0,2,1
  ],
  // 第 3 关
  [
    1,5,1,10,0,
    0,0,3,0,0,
    4,0,0,0,0,
    0,0,0,0,0,
    0,0,1,0,0
  ]
];

function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GShikaku {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /**
   * ★ 2026-10-23 修「尺寸陷阱」第 18 个：
   *   CLUE_LIB 是手工画的 5×5 = 25 格，但 diffTotal = sizeNow(5)（4/5/7）
   *   ⇒ 简单档只取前 16 项、困难档 25..48 是 undefined（线索全丢）
   *   修法：棋盘固定 5×5，难度改到**容错次数**上。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = 5;
  /** 本局的容错次数：简单 6 / 普通 3 / 困难 2 */
  @State private errMax: number = GShikaku.errNow();

  private static errNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 6;
    }
    if (d === 2) {
      return 2;
    }
    return 3;
  }

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State owner: number[] = [];     // 0 未圈，否则矩形编号
  @State first: number = -1;
  @State covered: number = 0;
  @State errors: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';

  private seq: number = 0;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GShikaku')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.errMax = GShikaku.errNow();
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.owner = new Array<number>(MAX_CELLS).fill(0);
    this.first = -1;
    this.covered = 0;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.seq = 0;
    this.startAt = Date.now();
  }

  private removeRect(id: number): void {
    const own: number[] = this.owner.slice();
    let removed: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (own[i] === id) {
        own[i] = 0;
        removed++;
      }
    }
    this.owner = own;
    this.covered -= removed;
  }


  /**
   * ★ 2026-10-23 第二期：数方提示
   *
   * 每个线索格必须被一个面积 = 线索值、且只含它一个线索的矩形覆盖。
   * ⇒ 对每个线索格，枚举所有「含它、面积对上、不压已有矩形、不含别的线索」的矩形；
   *    如果**只有一种放法**，那个矩形就是确定的，提示直接报它的两个角。
   * 一条都找不到 ⇒ Hint.none()。
   *
   * ⚠️ 只判"这个线索只有一个合法框"，不做全局搜索：
   *    多个线索互相约束出来的推理不在这一版范围内（宁可少给）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    for (let k = 0; k < n * n; k++) {
      const want: number = this.clues[k];
      if (want <= 0 || this.owner[k] !== 0) {
        continue;                       // 没线索 / 已经被圈进去了
      }
      const cr: number = Math.floor(k / n);
      const cc: number = k % n;
      let found: number = 0;
      let aR: number = 0;
      let aC: number = 0;
      let bR: number = 0;
      let bC: number = 0;
      // 枚举高 h 与宽 w，使 h*w == want
      for (let h = 1; h <= want; h++) {
        if (want % h !== 0) {
          continue;
        }
        const w: number = want / h;
        if (h > n || w > n) {
          continue;
        }
        // 矩形左上角 (r0,c0) 必须让 cr/cc 落在里面
        for (let r0 = cr - h + 1; r0 <= cr; r0++) {
          for (let c0 = cc - w + 1; c0 <= cc; c0++) {
            const r1: number = r0 + h - 1;
            const c1: number = c0 + w - 1;
            if (r0 < 0 || c0 < 0 || r1 >= n || c1 >= n) {
              continue;
            }
            let ok: boolean = true;
            let clueCnt: number = 0;
            for (let r = r0; r <= r1 && ok; r++) {
              for (let c = c0; c <= c1; c++) {
                const idx: number = r * n + c;
                if (this.owner[idx] !== 0) {
                  ok = false;
                  break;
                }
                if (this.clues[idx] > 0) {
                  clueCnt++;
                }
              }
            }
            if (!ok || clueCnt !== 1) {
              continue;
            }
            found++;
            aR = r0; aC = c0; bR = r1; bC = c1;
            if (found > 1) {
              break;
            }
          }
          if (found > 1) {
            break;
          }
        }
        if (found > 1) {
          break;
        }
      }
      if (found === 1) {
        return Hint.make([aR * n + aC, bR * n + bC],
          TG4('这里只有一个框法：从第 {0} 行第 {1} 列拖到第 {2} 行第 {3} 列',
            String(aR + 1), String(aC + 1), String(bR + 1), String(bC + 1)),
          TG4('Only one rectangle fits: from row {0}, column {1} to row {2}, column {3}',
            String(aR + 1), String(aC + 1), String(bR + 1), String(bC + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok) {
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintMsg = ''; }, 5000);
      return;
    }
    this.hintMsg = TG('这一步看不出哪块是唯一的，先圈几个简单的');
    setTimeout(() => { this.hintMsg = ''; }, 5000);
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
    if (this.over || this.autoCell() < 0) {
      return true;
    }
    this.tap(this.autoCell());
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

    /** 深搜：把还没圈的格子切成合法矩形（每块恰含一个线索、格数 = 线索数）；own 用副本模拟 */
    private dfsFill(own: number[], out: number[], budget: number[]): boolean {
      const n: number = this.diffTotal;
      let k: number = -1;
      for (let i = 0; i < n * n; i++) {
        if (own[i] === 0) {
          k = i;
          break;
        }
      }
      if (k < 0) {
        return true;
      }
      if (budget[0] <= 0) {
        return false;
      }
      const cr: number = Math.floor(k / n);
      const cc: number = k % n;
      for (let r0 = 0; r0 <= cr; r0++) {
        for (let c0 = 0; c0 <= cc; c0++) {
          for (let r1 = cr; r1 < n; r1++) {
            for (let c1 = cc; c1 < n; c1++) {
              budget[0] = budget[0] - 1;
              if (budget[0] <= 0) {
                return false;
              }
              const area: number = (r1 - r0 + 1) * (c1 - c0 + 1);
              let clue: number = 0;
              let bad: boolean = false;
              for (let r = r0; r <= r1 && !bad; r++) {
                for (let c = c0; c <= c1; c++) {
                  const idx: number = r * n + c;
                  if (own[idx] !== 0) {
                    bad = true;
                    break;
                  }
                  if (this.clues[idx] > 0) {
                    if (clue > 0) {
                      bad = true;
                      break;
                    }
                    clue = this.clues[idx];
                  }
                }
              }
              if (bad || clue !== area) {
                continue;
              }
              for (let r = r0; r <= r1; r++) {
                for (let c = c0; c <= c1; c++) {
                  own[r * n + c] = 1;
                }
              }
              out.push(r0 * n + c0);
              out.push(r1 * n + c1);
              if (this.dfsFill(own, out, budget)) {
                return true;
              }
              out.pop();
              out.pop();
              for (let r = r0; r <= r1; r++) {
                for (let c = c0; c <= c1; c++) {
                  own[r * n + c] = 0;
                }
              }
            }
          }
        }
      }
      return false;
    }

    /** 代打：这一步该点哪一格（先点矩形左上角，再点右下角；-1 = 没解） */
    private autoCell(): number {
      const n: number = this.diffTotal;
      const own: number[] = [];
      for (let i = 0; i < n * n; i++) {
        own.push(this.owner[i] > 0 ? 1 : 0);
      }
      const out: number[] = [];
      const budget: number[] = [40000];
      if (!this.dfsFill(own, out, budget) || out.length < 2) {
        return -1;
      }
      if (this.first < 0) {
        return out[0];
      }
      if (this.first === out[0]) {
        return out[1];
      }
      return this.first;
    }
  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const ownHere: number = this.owner[i];
    if (ownHere > 0) {
      this.removeRect(ownHere);
      this.first = -1;
      return;
    }
    if (this.first < 0) {
      this.first = i;
      return;
    }
    const a: number = this.first;
    this.first = -1;
    if (a === i) {
      return;
    }
    const r0: number = Math.min(Math.floor(a / this.diffTotal), Math.floor(i / this.diffTotal));
    const r1: number = Math.max(Math.floor(a / this.diffTotal), Math.floor(i / this.diffTotal));
    const c0: number = Math.min(a % this.diffTotal, i % this.diffTotal);
    const c1: number = Math.max(a % this.diffTotal, i % this.diffTotal);
    let area: number = 0;
    let clueCnt: number = 0;
    let clueVal: number = 0;
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const k: number = r * this.diffTotal + c;
        if (this.owner[k] !== 0) {
          return;                       // 压到别的矩形上，直接放弃
        }
        area++;
        if (this.clues[k] > 0) {
          clueCnt++;
          clueVal = this.clues[k];
        }
      }
    }
    if (clueCnt !== 1 || clueVal !== area) {
      this.errors++;
      if (this.errors >= this.errMax) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    this.seq++;
    const own: number[] = this.owner.slice();
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        own[r * this.diffTotal + c] = this.seq;
      }
    }
    this.owner = own;
    this.covered += area;
    if (this.covered === CELLS) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(100, 520 - this.errors * 100 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'shikaku',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.covered
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    const id: number = this.owner[i];
    if (id > 0) {
      return tintOf(Palette.wheel[(id - 1) % Palette.wheel.length], this.theme.isDark);
    }
    return this.theme.surface;
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已覆盖'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.covered) + '/' + String(CELLS)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错手'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(this.errMax)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.clues[(r * this.diffTotal + c)] > 0 ? String(this.clues[(r * this.diffTotal + c)]) : '')
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.owner[(r * this.diffTotal + c)] > 0 ? Palette.primaryDeep : this.theme.inkSoft)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .border({
              width: this.first === (r * this.diffTotal + c) ? 2 : 1,
              color: this.first === (r * this.diffTotal + c) ? Palette.violet : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.hintMsg.length > 0 ? this.hintMsg : (this.over
          ? (this.won ? '整盘切好 🎉 得分 ' + String(this.score) : '错手太多，本局失败')
          : '点两格圈矩形：面积要等于里面的数字'))
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint).animation({ duration: Motion.fast, curve: Motion.snap() })
          .layoutWeight(1)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
                Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')
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
