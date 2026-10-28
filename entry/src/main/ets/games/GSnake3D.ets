/**
 * 立体贪吃蛇 —— 三维空间贪吃蛇
 *
 * 空间：3 层 × 4×4（共 48 格）。方向和平面贪吃蛇一样（上下左右），
 *       另有「升层 / 降层」两个键 ⇒ 在立体的盒子里追食物。
 * 结算：撞墙或咬到自己 ⇒ 失败；长到 8 节 ⇒ 通关。
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

const SIZE: number = 4;                  // 每层 4×4
const LAYERS: number = 3;
const PER: number = SIZE * SIZE;         // 16
const CELLS: number = PER * LAYERS;      // 48
const WIN_LEN: number = 8;
const TICK_MS: number = 360;
const GAP: number = 2;
const START_LEN: number = 2;
const DRAG_MIN: number = 22;             // 滑动判定阈值（vp）
const CELL_IDX: number[] = [0, 1, 2, 3];
/**
 * 渲染顺序：上层排最左（"上层先显示"）。
 *
 * ★★★ 2026-10-13 P13「升降层反了」的根因
 *   坐标系里 **z 越大越靠上**：dir 4「⬆ 升层」做 z+1、dir 5「⬇ 降层」做 z-1；
 *   而这里把 z=LAYERS-1=2 排在最左 ⇒ **z=2 才是上层**。
 *   但旧代码的 LAYER_NAME 写成 ['上层','中层','下层']，等于把 z=0 叫「上层」——
 *   两套口径正好相反 ⇒ 玩的人按「⬆ 升层」，高亮往左跳到一块写着「下层」的板子上，
 *   看着就是**升层反而往下走**。
 *   ⇒ 唯一正确的改法是把名字对齐到 z 轴：z=0 是最下层。⛔ 别只把 dir 4/5 调换 ——
 *     那样 LAYER_ORDER 的"上层先显示"又对不上了。
 */
const LAYER_ORDER: number[] = [2, 1, 0]; // 上层先显示（z=2 是上层）
const LAYER_NAME: string[] = [TG('下层'), TG('中层'), TG('上层')];   // 与 z 轴一致：z=0 最下
const BTN_H: number = 44;
/** 方向：0 左 1 右 2 上 3 下 4 升层 5 降层 */
const DIR_LABEL: string[] = ['←', '→', '↑', '↓', TG('⬆ 升层'), TG('⬇ 降层')];

function cellAt(z: number, y: number, x: number): number {
  return z * PER + y * SIZE + x;
}

@Component
export struct GSnake3D {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private body: number[] = [];
  @State private food: number = 0;
  @State private dir: number = 1;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(START_LEN);
  @State private len: number = 0;
  @State private score: number = 0;
  @State private running: boolean = false;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private timer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;
  /** ★ 滑动起点（vp）：每认一次方向就重置，支持连续滑动 */
  private dragX: number = 0;
  private dragY: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.total = GameDiff.livesNow(START_LEN);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
  }

  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private reset(): void {
    this.stopLoop();
    this.body = [cellAt(1, 1, 1), cellAt(1, 0, 1)];   // 中层，头在前
    this.len = this.total;
    this.dir = 1;
    this.score = 0;
    this.running = false;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('按方向键出发');
    this.placeFood(this.body);
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      this.tick();
    }, TICK_MS);
  }

  private placeFood(occupied: number[]): void {
    const free: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (occupied.indexOf(i) < 0) {
        free.push(i);
      }
    }
    this.food = free.length > 0 ? free[Math.floor(Math.random() * free.length)] : -1;
  }

  private tick(): void {
    if (!this.running || this.over || this.won) {
      return;
    }
    const head: number = this.body[0];
    const z: number = Math.floor(head / PER);
    const rest: number = head % PER;
    const y: number = Math.floor(rest / SIZE);
    const x: number = rest % SIZE;
    let nx: number = x;
    let ny: number = y;
    let nz: number = z;
    if (this.dir === 0) {
      nx--;
    } else if (this.dir === 1) {
      nx++;
    } else if (this.dir === 2) {
      ny--;
    } else if (this.dir === 3) {
      ny++;
    } else if (this.dir === 4) {
      nz++;
    } else {
      nz--;
    }
    if (nx < 0 || nx >= SIZE || ny < 0 || ny >= SIZE || nz < 0 || nz >= LAYERS) {
      this.lose(TG('撞墙了'));
      return;
    }
    const ni: number = cellAt(nz, ny, nx);
    const grow: boolean = ni === this.food;
    const limit: number = grow ? this.body.length : this.body.length - 1;
    for (let i = 0; i < limit; i++) {
      if (this.body[i] === ni) {
        this.lose(TG('咬到自己了'));
        return;
      }
    }
    const next: number[] = [ni];
    for (let i = 0; i < this.body.length; i++) {
      next.push(this.body[i]);
    }
    if (!grow) {
      next.pop();
    }
    this.body = next;
    this.len = next.length;
    if (grow) {
      this.score += 10;
      if (next.length >= WIN_LEN) {
        this.win();
        return;
      }
      this.placeFood(next);
    }
  }

  private lose(why: string): void {
    this.over = true;
    this.won = false;
    this.running = false;
    this.msg = TG2('💥 {0}，长度停在 {1}', why, this.len);
    this.stopLoop();
    this.finish(false);
  }

  private win(): void {
    this.over = true;
    this.won = true;
    this.running = false;
    this.score += 200;
    this.msg = TG2('🎉 长到 {0} 节，通关！',Digits(String(WIN_LEN), this.langCode));
    this.stopLoop();
    this.finish(true);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'snake_3d',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.len
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 这个方向走过去会不会撞墙 / 咬到自己 / 是掉头（setDir 会直接忽略） */
  private dirOk(d: number): boolean {
    if (this.body.length === 0) {
      return false;
    }
    if ((this.dir === 0 && d === 1) || (this.dir === 1 && d === 0)
      || (this.dir === 2 && d === 3) || (this.dir === 3 && d === 2)
      || (this.dir === 4 && d === 5) || (this.dir === 5 && d === 4)) {
      return false;
    }
    const head: number = this.body[0];
    const z: number = Math.floor(head / PER);
    const rest: number = head % PER;
    const y: number = Math.floor(rest / SIZE);
    const x: number = rest % SIZE;
    let nx: number = x;
    let ny: number = y;
    let nz: number = z;
    if (d === 0) {
      nx--;
    } else if (d === 1) {
      nx++;
    } else if (d === 2) {
      ny--;
    } else if (d === 3) {
      ny++;
    } else if (d === 4) {
      nz++;
    } else {
      nz--;
    }
    if (nx < 0 || nx >= SIZE || ny < 0 || ny >= SIZE || nz < 0 || nz >= LAYERS) {
      return false;
    }
    const ni: number = cellAt(nz, ny, nx);
    for (let i = 0; i < this.body.length - 1; i++) {
      if (this.body[i] === ni) {
        return false;
      }
    }
    return true;
  }

  /** 代打：朝食物走，差得多的那根轴优先；都不行就找个安全方向绕（-1 = 无路可走） */
  private autoDir(): number {
    if (this.body.length === 0 || this.food < 0) {
      return -1;
    }
    const head: number = this.body[0];
    const hz: number = Math.floor(head / PER);
    const hrest: number = head % PER;
    const hy: number = Math.floor(hrest / SIZE);
    const hx: number = hrest % SIZE;
    const fz: number = Math.floor(this.food / PER);
    const frest: number = this.food % PER;
    const fy: number = Math.floor(frest / SIZE);
    const fx: number = frest % SIZE;
    const dxs: number[] = [fx > hx ? 1 : 0, fy > hy ? 3 : 2, fz > hz ? 4 : 5];
    const ds: number[] = [Math.abs(fx - hx), Math.abs(fy - hy), Math.abs(fz - hz)];
    const order: number[] = [];
    for (let i = 0; i < 3; i++) {
      if (ds[i] === 0) {
        continue;
      }
      let at: number = order.length;
      for (let k = 0; k < order.length; k++) {
        if (ds[i] > ds[order[k]]) {
          at = k;
          break;
        }
      }
      order.splice(at, 0, i);
    }
    for (let i = 0; i < order.length; i++) {
      if (this.dirOk(dxs[order[i]])) {
        return dxs[order[i]];
      }
    }
    for (let d = 0; d < 6; d++) {
      if (this.dirOk(d)) {
        return d;
      }
    }
    return -1;
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
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.won || this.autoDir() < 0) {
      return true;
    }
    this.setDir(this.autoDir());
    return !this.over;
  }

  // 食物在 this.food、身体在 this.body ⇒ 报下一步该按的方向
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.won) {
      return Hint.none('none');
    }
    const d: number = this.autoDir();
    if (d < 0) {
      return Hint.none('none');
    }
    return Hint.make([], '按「' + DIR_LABEL[d] + '」，食物在第 ' + String(Math.floor(this.food / PER) + 1) + ' 层',
      'Press "' + DIR_LABEL[d] + '" toward the food', t0);
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

  private setDir(d: number): void {
    if (this.over || this.won) {
      return;
    }
    // 不许 180° 掉头（会直接咬到自己）
    if ((this.dir === 0 && d === 1) || (this.dir === 1 && d === 0)
      || (this.dir === 2 && d === 3) || (this.dir === 3 && d === 2)
      || (this.dir === 4 && d === 5) || (this.dir === 5 && d === 4)) {
      return;
    }
    this.dir = d;
    this.running = true;
    this.msg = TG2("第 {0} 层 · 长度 {1}/{2}", (this.headZ() + 1), this.len, WIN_LEN);
  }

  private headZ(): number {
    if (this.body.length === 0) {
      return 0;
    }
    return Math.floor(this.body[0] / PER);
  }

  private cellColor(i: number): string {
    if (this.body.length > 0 && this.body[0] === i) {
      return Palette.emerald;
    }
    if (this.body.indexOf(i) >= 0) {
      return Palette.teal;
    }
    if (i === this.food) {
      return Palette.rose;
    }
    return this.theme.surfaceAlt;
  }

  private status(): string {
    if (this.won) {
      return TG2('🎉 通关！得分 {0}',Digits(String(this.score), this.langCode));
    }
    if (this.over) {
      return this.msg + TG2(' · 得分 {0}',Digits(String(this.score), this.langCode));
    }
    if (!this.running) {
      return TG('按方向键出发；升/降层换一个平面 ⬆⬇');
    }
    return this.msg;
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      Row({ space: Space.xs }) {
        ForEach(LAYER_ORDER, (z: number) => {
          this.layer(z)
        }, (z: number) => 'L' + z)
      }
      .width('100%')
      // ★ P9：手指直接在棋盘上滑 = 转方向（不用去够下面那排小按钮）
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 8 })
          .onActionStart(() => {
            this.dragX = 0;
            this.dragY = 0;
          })
          .onActionUpdate((e: GestureEvent) => {
            const dx: number = e.offsetX - this.dragX;
            const dy: number = e.offsetY - this.dragY;
            if (Math.abs(dx) < DRAG_MIN && Math.abs(dy) < DRAG_MIN) {
              return;
            }
            this.dragX = e.offsetX;
            this.dragY = e.offsetY;
            if (Math.abs(dx) >= Math.abs(dy)) {
              this.setDir(dx > 0 ? 1 : 0);
            } else {
              this.setDir(dy > 0 ? 3 : 2);
            }
          })
          .onActionEnd(() => {
            this.dragX = 0;
            this.dragY = 0;
          })
      )

      Text(this.status())
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          this.pad(4)
          this.pad(2)
          this.pad(5)
        }
        .width('100%')
        Row({ space: Space.xs }) {
          this.pad(0)
          this.pad(3)
          this.pad(1)
        }
        .width('100%')
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(this.running ? TG('暂停') : TG('开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(this.running ? Palette.amber : Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.running = !this.running;
            if (this.running) {
              this.msg = TG2("第 {0} 层 · 长度 {1}/{2}", (this.headZ() + 1), this.len, WIN_LEN);
            }
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.running = !this.running; if (this.running) { this.msg = TG2("第 {0} 层 · 长度 {1}/{2}", (this.headZ() + 1), this.len, WIN_LEN); } }); })
        Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.emerald)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
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

  /**
   * 顶部小格：kind 0=所在层 1=长度 2=得分
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值的话这三个数
   *    一局都不会变（P13 的"按了升层没反应"里也混着这条）。读取必须落在闭包内。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '所在层' : (kind === 1 ? TG('长度') : TG('得分')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? (this.headZ() + 1) + ' / ' + LAYERS
        : (kind === 1 ? this.len + ' / ' + WIN_LEN : String(this.score)))
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

  @Builder
  layer(z: number) {
    Column({ space: GAP }) {
      Text(LAYER_NAME[z])
        .fontSize(FontSize.xxs)
        .fontColor(this.headZ() === z ? Palette.amber : this.theme.inkFaint)
      Column({ space: GAP }) {
        ForEach(CELL_IDX, (y: number) => {
          Row({ space: GAP }) {
            ForEach(CELL_IDX, (x: number) => {
              this.cell3(z, y, x)
            }, (x: number) => 'x' + x)
          }
          .width('100%')
        }, (y: number) => 'y' + y)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .padding(GAP)
    .backgroundColor(this.headZ() === z
      ? (this.theme.isDark ? '#2A230A' : '#FFF7E6')
      : this.theme.surface)
    .borderRadius(Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  cell3(z: number, y: number, x: number) {
    Stack() {
      Row()
        .width('74%')
        .aspectRatio(1)
        .backgroundColor(this.cellColor(cellAt(z, y, x)))
        .borderRadius(Radius.xs)
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  pad(d: number) {
    Text(DIR_LABEL[d])
      .fontSize(FontSize.sm)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(Cell.of(38))
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .onClick(() => {
        Haptics.tick();
        this.setDir(d);
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.setDir(d); }); })
  }
}
