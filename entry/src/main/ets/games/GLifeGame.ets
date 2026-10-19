/**
 * 生命游戏（康威）—— 细胞自动机 🧬
 *
 * 规则：每个细胞看周围 8 格；活细胞 2~3 个邻居存活，死细胞恰好 3 个邻居则诞生。
 * 胜负：撑满 60 代不灭绝 = 通关；中途全部死光 = 失败（可随时点格子人工干预）
 */

import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const G: number = 12;
const GOAL: number = 60;
const TICK: number = 300;

@Component
export struct GLifeGame {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：GOAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(GOAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: boolean[] = [];
  @State private gen: number = 0;
  @State private aliveN: number = 0;
  @State private running: boolean = false;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private k: number = 1;

  private timer: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(GOAL);
    this.reset();
  }

  private stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** ★ 2026-10-14 动画补齐：进度/得分脉冲（本款原来一处 .animation() 都没有） */

  private bumpK(): void {

    this.k = 1.16;

    animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.k = 1; });

  }

  private reset(): void {
    this.stop();
    const c: boolean[] = [];
    let n: number = 0;
    for (let i = 0; i < G * G; i++) {
      const live: boolean = Math.random() < 0.32;
      c.push(live);
      if (live) {
        n++;
      }
    }
    this.cells = c;
    this.gen = 0;
    this.aliveN = n;
    this.running = false;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const c: boolean[] = this.cells.slice();
    c[i] = !c[i];
    this.cells = c;
    let n: number = 0;
    for (let k = 0; k < c.length; k++) {
      if (c[k]) {
        n++;
      }
    }
    this.aliveN = n;
  }

  private step(): void {
    if (this.over) {
      return;
    }
    const next: boolean[] = [];
    let alive: number = 0;
    for (let r = 0; r < G; r++) {
      for (let c = 0; c < G; c++) {
        let cnt: number = 0;
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            if (dr === 0 && dc === 0) {
              continue;
            }
            const rr: number = r + dr;
            const cc: number = c + dc;
            if (rr >= 0 && rr < G && cc >= 0 && cc < G && this.cells[rr * G + cc]) {
              cnt++;
            }
          }
        }
        const live: boolean = this.cells[r * G + c];
        const nxt: boolean = live ? (cnt === 2 || cnt === 3) : (cnt === 3);
        next.push(nxt);
        if (nxt) {
          alive++;
        }
      }
    }
    this.cells = next;
    this.gen = this.gen + 1;
    this.bumpK();
    this.aliveN = alive;

    if (alive === 0) {
      this.stop();
      this.running = false;
      this.over = true;
      this.finish(false);
      return;
    }
    if (this.gen >= this.diffTotal) {
      this.stop();
      this.running = false;
      this.over = true;
      this.won = true;
      this.finish(true);
    }
  }

  private play(): void {
    if (this.over) {
      return;
    }
    if (this.running) {
      this.stop();
      this.running = false;
      return;
    }
    this.running = true;
    this.stop();
    this.timer = setInterval(() => {
      this.step();
    }, TICK);
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'life_game',
      solved: solved,
      score: solved ? 600 + this.aliveN * 20 : this.gen * 10,
      durationMs: Date.now() - this.startAt,
      levelReached: this.gen
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('代数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.gen) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        .scale({ x: this.k, y: this.k })
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('存活'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.aliveN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (c: number) => {
              Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cells[(r * G + c)] ? Palette.violet : this.theme.surface)
              .borderRadius(Radius.xs)
              .onClick(() => {
              Haptics.tick();
              this.tap((r * G + c));
              })
            }, (c: number) => 'c' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.over ? (this.won ? '🎉 存活满 60 代，种群稳定！' : '💀 第 ' + String(this.gen) + ' 代灭绝了') :
        (this.running ? '演化中…点格子可以人工投放生命' : '点格子布种，再按开始'))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(this.running ? TG('暂停') : TG('开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.violet).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.play();
          })
        Button(TG('单步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.running && !this.over)
          .onClick(() => {
            Haptics.tap();
            this.step();
          })
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(TG('随机一局'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.primary).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.stop();
            this.running = false;
            this.cells = new Array<boolean>(G * G).fill(false);
            this.aliveN = 0;
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

}
