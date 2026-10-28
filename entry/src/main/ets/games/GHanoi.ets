/**
 * 汉诺塔 —— 递归之美
 * 规则：一次只动一个盘，大盘不能压小盘；把所有盘从 A 柱移到 C 柱
 * 通关：C 柱上盘数 == 总盘数
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

@Component
export struct GHanoi {
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
  @State private pegs: number[][] = [[], [], []];
  @State private sel: number = -1;      // 选中的柱子，-1 = 没选
  @State private moves: number = 0;
  // ★ 难度作用到玩法：盘数（简单 2 / 普通 3 / 困难 5）
  @State private level: number = GameDiff.pick(2, 3, 5);     // 盘数
  @State private done: boolean = false;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset(this.level);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.level = GameDiff.pick(2, 3, 5);
    this.reset(this.level);
  }

  private reset(n: number): void {
    const a: number[] = [];
    for (let i = n; i >= 1; i--) {
      a.push(i);   // 大的在底
    }
    this.pegs = [a, [], []];
    this.sel = -1;
    this.moves = 0;
    this.done = false;
    this.startAt = Date.now();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(this.level); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.done) {
      return false;
    }
    const mv: number[] = this.hanoiNext();
    if (mv[0] < 0) {
      return false;
    }
    if (this.sel === mv[0]) {
      this.tap(mv[1]);
      return true;
    }
    if (this.sel >= 0) {
      this.tap(this.sel);
      return true;
    }
    this.tap(mv[0]);
    return true;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 三柱 ≤5 盘 ⇒ 状态数 ≤ 243，直接 BFS 从「当前局面」找最短路的第一步
  /** 下一步该走哪：返回 [从, 到]，无解返回 [-1, -1] */
  private hanoiNext(): number[] {
    const n: number = this.level;
    const tot: number = Math.pow(3, n);
    const pow3: number[] = [];
    let w: number = 1;
    for (let i = 0; i < n; i++) {
      pow3.push(w);
      w = w * 3;
    }
    let id0: number = 0;
    for (let d = 1; d <= n; d++) {
      let pg: number = 0;
      for (let p = 0; p < 3; p++) {
        if (this.pegs[p].indexOf(d) >= 0) {
          pg = p;
        }
      }
      id0 = id0 + pg * pow3[d - 1];
    }
    const goal: number = tot - 1;
    if (id0 === goal) {
      return [-1, -1];
    }
    const first: number[] = new Array<number>(tot).fill(-1);
    const seen: boolean[] = new Array<boolean>(tot).fill(false);
    const q: number[] = [id0];
    seen[id0] = true;
    let head: number = 0;
    while (head < q.length) {
      const cur: number = q[head];
      head++;
      const cp: number[] = [];
      let x: number = cur;
      for (let i = 0; i < n; i++) {
        cp.push(x % 3);
        x = Math.floor(x / 3);
      }
      for (let f = 0; f < 3; f++) {
        let topF: number = 0;
        for (let i = 0; i < n; i++) {
          if (cp[i] === f) {
            topF = i + 1;
            break;
          }
        }
        if (topF === 0) {
          continue;
        }
        for (let t = 0; t < 3; t++) {
          if (t === f) {
            continue;
          }
          let topT: number = 0;
          for (let i = 0; i < n; i++) {
            if (cp[i] === t) {
              topT = i + 1;
              break;
            }
          }
          if (topT !== 0 && topT < topF) {
            continue;
          }
          const nid: number = cur - (f - t) * pow3[topF - 1];
          if (seen[nid]) {
            continue;
          }
          seen[nid] = true;
          first[nid] = first[cur] >= 0 ? first[cur] : (f * 3 + t);
          if (nid === goal) {
            return [Math.floor(first[nid] / 3), first[nid] % 3];
          }
          q.push(nid);
        }
      }
    }
    return [-1, -1];
  }

  /** 提示：报「第几个盘从哪柱搬到哪柱」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.done) {
      return Hint.none('none');
    }
    const mv: number[] = this.hanoiNext();
    if (mv[0] < 0) {
      return Hint.none('none');
    }
    const src: number[] = this.pegs[mv[0]];
    const disk: number = src.length > 0 ? src[src.length - 1] : 0;
    return Hint.make([mv[0], mv[1]],
      TG2('把 {0} 号盘从第 {1} 根柱子搬到第 {2} 根柱子', String(disk), String(mv[0] + 1), String(mv[1] + 1)),
      TG2('Move disk {0} from peg {1} to peg {2}', String(disk), String(mv[0] + 1), String(mv[1] + 1)), t0);
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

  private tap(p: number): void {
    if (this.done) {
      return;
    }
    const cur: number[][] = this.pegs.map((x: number[]) => x.slice());
    if (this.sel === -1) {
      if (cur[p].length === 0) {
        return;
      }
      this.sel = p;
      return;
    }
    if (this.sel === p) {
      this.sel = -1;
      return;
    }
    const from: number[] = cur[this.sel];
    const to: number[] = cur[p];
    const disk: number = from[from.length - 1];
    const top: number = to.length > 0 ? to[to.length - 1] : 999;
    if (disk < top) {
      from.pop();
      to.push(disk);
      this.moves++;
      this.pegs = cur;
      this.sel = -1;
      if (cur[2].length === this.level) {
        this.done = true;
        const r: GameResult = {
          gameId: 'hanoi',
          solved: true,
          score: Math.max(0, 1000 - this.moves * 10),
          durationMs: Date.now() - this.startAt,
          levelReached: this.level
        };
        LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
        this.onFinish(r);
      }
    } else {
      this.sel = -1;   // 非法：取消选择
    }
  }

  build() {
    Column({ space: Space.lg }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最少'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.pow(2, this.level) - 1))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('盘数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.level), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      // 三根柱子
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2], (p: number) => {
          Column() {
            Column({ space: 4 }) {
              // 从顶到底画盘（数组尾在底）
              ForEach(this.pegs[p].slice().reverse(), (d: number) => {
                Row()
                  .width(30 + d * 20)
                  .height(18)
                  .backgroundColor(Palette.wheel[d % Palette.wheel.length])
                  .borderRadius(Radius.xs)
              }, (d: number, i: number) => p + '-' + i + '-' + d)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)

            // 柱底
            Row()
              .width('100%').height(6)
              .backgroundColor(this.sel === p ? Palette.primary : this.theme.lineSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
              .borderRadius(Radius.xs)
          }
          .layoutWeight(1)
          .height('100%')
          .padding(Space.xs)
          .backgroundColor(this.sel === p ? '#1A6366F1' : this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(p); }); })
          .onClick(() => {
            Haptics.tick();
            this.tap(p);
          })
        }, (p: number) => 'peg' + p)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.done ? '🎉 完成！' : (this.sel >= 0 ? '再点一根柱子放过去' : '点一根柱子拿起最上面的盘'))
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.primary).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(this.level); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset(this.level);
          })
        Button(this.level === 3 ? '升到 4 盘' : (this.level === 4 ? '升到 5 盘' : '回到 3 盘'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.level = this.level === 3 ? 4 : (this.level === 4 ? 5 : 3); this.reset(this.level); }); })
          .onClick(() => {
            Haptics.tap();
            this.level = this.level === 3 ? 4 : (this.level === 4 ? 5 : 3);
            this.reset(this.level);
          })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%')
  }


}
