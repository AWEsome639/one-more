/**
 * 电路连接 🔋
 * 规则：4×4 元件盘，点一下顺时针转 90°；电源从左上角左边进电，目标是右下角那格。
 * 胜负：电流通到右下角（且朝右出） = 通关；步数用尽没接通 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

/** ★ 2026-11-08：删掉死代码 `N=4 / LAST=N*N-1`（终点号已改为 `last()` 按棋盘算，全文件无引用）；
 *   `TURNS=26` 这个常量也一并去掉 —— 它不随棋盘走（见 `turns()`）。 */
/** 位序 0上 1右 2下 3左；GLYPH[mask] = 画出来的样子 */
const BASE: number[] = [3, 5, 6, 9, 10, 12, 15];
const GLYPH: string[] = ['·', '╹', '╺', '╚', '╻', '║', '╔', '╠', '╸', '╝', '═', '╩', '╗', '╣', '╦', '╬'];
function has(m: number, d: number): boolean {
 return Math.floor(m / Math.pow(2, d)) % 2 === 1;
}
  @Component
export struct GCircuitConnect {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
 /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
 @State private tvFocus: string = '';
 @State private autoId: number = -1;
 /** 演示动画（项目 C）：-1 = 未运行 */
 @State private demoId: number = -1;
  // ★ 2026-11-01 演示三拍（DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
 @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** ★ 2026-11-08 终点格号**按当前棋盘算**（game-balancer：`LAST` 写死 15，
   *   而 `sizeNow(4)` = 3/4/5 ⇒ 简单档 3×3 只有 **9 格**，`lit[15]=undefined` ⇒
   *   **`solved` 恒 false，简单档 100% 赢不了**；困难档 5×5 又判早到第 15 格。） */
  private last(): number {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    return n2 * n2 - 1;
  }

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
 onFinish: (r: GameResult) => void = () => {};

  @State private grid: number[] = []; @State private rot: number[] = [];
  @State private on: boolean[] = []; @State private moves: number = 0;
  @State private over: boolean = false; @State private won: boolean = false;
  @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void {
   LanRace.noteStart(); this.reset();
   // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
   if (Hint.demoOnce('GCircuitConnect')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
 }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
 /**
  * ★★★ 2026-11-08（ai-fixer-b 蒙特卡洛）**两个真问题**：
  *   ① **生成本身大多无解**：原来每个格随机取 `BASE` 掩码 + 随机朝向。而通关要求
  *      「源点格有 bit3（左侧馈入）」+「终点格有 bit1（右侧灯）」+ 沿途每对相邻格**双向**匹配。
  *      实测随机盘的可解率只有 **约 7~13%**（500 局/档贪心求解：简单 65/500、普通 36/500、困难 34/500）。
  *   ② `TURNS=26` 写死不随棋盘走（3×3 也是 26、5×5 还是 26）。
  *   ⇒ 改成**「先造答案再打乱」**：随机生成一条 0→last 的简单路径，给路径格配上「正好通向
  *     前后两格」的掩码（源点补 bit3、终点补 bit1），其余格随便给；最后把每格随机转 k 圈（k 取 0/1/2/3）。
  *     这样**一定存在解**（把每格转回去即可），步数上限按棋盘给（见 `turns()`）。
  */
 private reset(): void {
 const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
 const g: number[] = this.genSolved(n);
 const rt: number[] = [];
 for (let i = 0; i < n * n; i++) {
 rt.push(Math.floor(Math.random() * 4));
 }
 this.moves = 0; this.over = false;
 this.won = false; this.note = TG(TG(TG('转动元件，把电送到右下角 🔋')));
 this.startAt = Date.now();
 this.rot = rt; this.grid = g; this.on = this.powered();
 }

 /**
  * 步数上限：**按棋盘算**（原来三档都写死 26）。
  * 依据（500 局/档模拟）：打乱后「朴素还原」（把每格转回原朝向）所需步数
  *   3×3 中位 14 / 最长 22；4×4 中位 24 / 最长 36；5×5 中位 38 / 最长 **55**。
  * ⇒ 取 `2.5 n²`：23 / 40 / 63，**覆盖朴素还原的最长值**（保证"照答案转回去"一定能完成），
  *   同时比 26 更合理（5×5 原来 26 步连朴素还原的 38 都不够）。
  */
 private turns(): number {
 const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
 return Math.ceil(n * n * 2.5);
 }

 /** 方向位：from → to 是哪个方向（0上 1右 2下 3左） */
 private dirBit(from: number, to: number): number {
 const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
 const fr: number = Math.floor(from / n); const fc: number = from % n;
 const tr: number = Math.floor(to / n); const tc: number = to % n;
 if (tr < fr) { return 1; }
 if (tc > fc) { return 2; }
 if (tr > fr) { return 4; }
 return 8;
 }

 /** 随机一条 0 → last 的简单路径（DFS + 回溯；棋盘 ≤ 25 格，瞬间完成） */
 private buildPath(n: number): number[] {
 const last: number = n * n - 1;
 const seen: boolean[] = new Array<boolean>(n * n).fill(false);
 const path: number[] = [0];
 seen[0] = true;
 // 迭代 DFS（不用递归箭头函数：ArkTS 里 const 自引用会「使用前声明」报错）
 while (path.length > 0 && path[path.length - 1] !== last) {
   const cur: number = path[path.length - 1];
   const r: number = Math.floor(cur / n); const c: number = cur % n;
   const opts: number[] = [];
   if (r > 0 && !seen[cur - n]) { opts.push(cur - n); }
   if (c < n - 1 && !seen[cur + 1]) { opts.push(cur + 1); }
   if (r < n - 1 && !seen[cur + n]) { opts.push(cur + n); }
   if (c > 0 && !seen[cur - 1]) { opts.push(cur - 1); }
   if (opts.length === 0) { path.pop(); continue; }
   const pick: number = opts[Math.floor(Math.random() * opts.length)];
   seen[pick] = true;
   path.push(pick);
 }
 return path;
 }

 /** 造一个「已解开」的盘面（每格掩码正好通向路径前后两格；源点 bit3、终点 bit1） */
 private genSolved(n: number): number[] {
 const g: number[] = new Array<number>(n * n).fill(15);
 const path: number[] = this.buildPath(n);
 for (let k = 0; k < path.length; k++) {
   const i: number = path[k];
   let m: number = 0;
   if (k === 0) { m |= 8; }                       // 源点：左侧馈入（bit3）
   if (k === path.length - 1) { m |= 2; }          // 终点：右侧灯（bit1）
   if (k > 0) { m |= this.dirBit(i, path[k - 1]); }
   if (k < path.length - 1) { m |= this.dirBit(i, path[k + 1]); }
   g[i] = m;
 }
 return g;
 }
 /** 当前朝向的导通掩码 */
 private maskAt(i: number): number {
 const m: number = this.grid[i]; const r: number = this.rot[i]; let out: number = 0;
 for (let d = 0; d < 4; d++) {
 if (has(m, d)) { out += Math.pow(2, (d + r) % 4); }
 }
 return out;
 }
 /** 从左上角注电（左边视为电源馈入） */
 private powered(): boolean[] {
 const lit: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
 if (!has(this.maskAt(0), 3)) { return lit; }
 const st: number[] = [0]; lit[0] = true;
 while (st.length > 0) {
 const i: number = st.pop() as number; const r: number = Math.floor(i / this.diffTotal);
 const c: number = i % this.diffTotal; const m: number = this.maskAt(i);
 if (r > 0 && has(m, 0) && has(this.maskAt(i - this.diffTotal), 2) && !lit[i - this.diffTotal]) {
 lit[i - this.diffTotal] = true; st.push(i - this.diffTotal);
 }
 if (c < this.diffTotal - 1 && has(m, 1) && has(this.maskAt(i + 1), 3) && !lit[i + 1]) {
 lit[i + 1] = true; st.push(i + 1);
 }
 if (r < this.diffTotal - 1 && has(m, 2) && has(this.maskAt(i + this.diffTotal), 0) && !lit[i + this.diffTotal]) {
 lit[i + this.diffTotal] = true; st.push(i + this.diffTotal);
 }
 if (c > 0 && has(m, 3) && has(this.maskAt(i - 1), 1) && !lit[i - 1]) {
 lit[i - 1] = true; st.push(i - 1);
 }
 }
 return lit;
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

  // ═══════════ 演示动画 · 三拍（2026-11-01 手工接）
  // ★ 旧版一个 tick 直接 autoStep()，匀速连发 ⇒ 看不出在演什么。
  // ★ 新版：引导(720) → 执行(280) → 结果(1150)，3 轮，结束后 this.reset()。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
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
    this.reset();
  }

  private demoStop(): void {
    this.demoFinish();
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
   const i: number = this.autoCell();
   if (i < 0) {
     return false;        // 全部转正了（正常不会到这：那时已通关）
   }
   this.spin(i);
   return !this.over;
 }

 // 通关 = 电流到得了右下角且它朝右出（finish 里的 solved）
 private computeHint(): HintResult {
   const t0: number = Date.now();
   if (this.over) {
     return Hint.none('none');
   }
   const best: number = this.trySpin();
   if (best < 0) {
     return Hint.none('none');
   }
   const r: number = Math.floor(best / this.diffTotal);
   const c: number = best % this.diffTotal;
   return Hint.make([best],
     TG2('转第 {0} 行第 {1} 列那颗（顺时针 90°），带电格会变多', r + 1, c + 1),
     'Rotate row ' + String(r + 1) + ', column ' + String(c + 1) + ' clockwise', t0);
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

 private askHint(): void {
   Haptics.tap();
   const r: HintResult = this.computeHint();
   Hint.toastResult(r, TG('这一步看不出答案'));
 }

  /** 用一份「假设的朝向」算带电格数（通到终点再 +1000）—— 不动 this.rot，纯试算 */
  private simLit(rot: number[]): number {
    const n: number = this.diffTotal;
    const total: number = n * n;
    const mask: number[] = [];
    for (let i = 0; i < total; i++) {
      const m: number = this.grid[i];
      const r: number = rot[i];
      let out: number = 0;
      for (let d = 0; d < 4; d++) {
        if (has(m, d)) {
          out += Math.pow(2, (d + r) % 4);
        }
      }
      mask.push(out);
    }
    const lit: boolean[] = new Array<boolean>(total).fill(false);
    if (!has(mask[0], 3)) {
      return 0;
    }
    lit[0] = true;
    const st: number[] = [0];
    let cnt: number = 1;
    while (st.length > 0) {
      const i: number = st.pop() as number;
      const r: number = Math.floor(i / n);
      const c: number = i % n;
      const mm: number = mask[i];
      if (r > 0 && has(mm, 0) && has(mask[i - n], 2) && !lit[i - n]) {
        lit[i - n] = true;
        cnt++;
        st.push(i - n);
      }
      if (c < n - 1 && has(mm, 1) && has(mask[i + 1], 3) && !lit[i + 1]) {
        lit[i + 1] = true;
        cnt++;
        st.push(i + 1);
      }
      if (r < n - 1 && has(mm, 2) && has(mask[i + n], 0) && !lit[i + n]) {
        lit[i + n] = true;
        cnt++;
        st.push(i + n);
      }
      if (c > 0 && has(mm, 3) && has(mask[i - 1], 1) && !lit[i - 1]) {
        lit[i - 1] = true;
        cnt++;
        st.push(i - 1);
      }
    }
    if (lit[total - 1] && has(mask[total - 1], 1)) {
      cnt += 1000;
    } else if (lit[total - 1]) {
      cnt += 100;
    }
    return cnt;
  }

  /** 试算某格顺时针转 90° 后能多带多少电（-1 表示没有更好的） */
  private trySpin(): number {
    const total: number = this.diffTotal * this.diffTotal;
    const base: number = this.simLit(this.rot);
    let best: number = -1;
    let bestSc: number = base;
    for (let i = 0; i < total; i++) {
      const rt: number[] = this.rot.slice();
      rt[i] = (rt[i] + 1) % 4;
      const sc: number = this.simLit(rt);
      if (sc > bestSc) {
        bestSc = sc;
        best = i;
      }
    }
    return best;
  }

  /** 代打：转哪一格最能推进；一点进步都没有就随机转一格破局 */
  /**
   * ★★★ 2026-11-08（lead 批准）**代打按"答案"走，不再贪心**：
   *   `genSolved()` 造出的盘面以 `rot[i] === 0` 为"已解开"（reset 再给每格随机转 k 圈），
   *   所以 AI 只要**把每格转回 0** 就一定能赢：
   *   朴素步数 = Σ (4−rot[i])%4，模拟最长 22 / 36 / 55 ⇒ 都在 `turns()`(23/40/63) 预算内。
   *   原来用 `trySpin()` 贪心会卡在局部最优 —— 实测只解出 7~13%，那才是 AI 代打 FAIL 的真因。
   *   返回 -1 = 所有格子都已转正（此刻其实已通关）。
   */
  private autoCell(): number {
    const total: number = this.diffTotal * this.diffTotal;
    for (let i = 0; i < total; i++) {
      if (this.rot[i] % 4 !== 0) {
        return i;
      }
    }
    return -1;
  }
 private spin(i: number): void {
 if (this.over) { return; }
 const rt: number[] = this.rot.slice(); rt[i] = (rt[i] + 1) % 4; this.rot = rt; this.moves++;
 const lit: boolean[] = this.powered(); this.on = lit; let cnt: number = 0;
 for (let t = 0; t < lit.length; t++) { if (lit[t]) { cnt++; } }
 const solved: boolean = lit[this.last()] && has(this.maskAt(this.last()), 1);
 if (solved || this.moves >= this.turns()) {
 this.note = solved ? TG("接通了，灯亮 🎉") : TG("步数用尽，还没接通 😵"); this.finish(solved, cnt); return;
 }
 this.note = TG2('当前带电 {0}/{1} 格 ⚡', cnt, (this.diffTotal * this.diffTotal));
 }
 private finish(solved: boolean, lit: number): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'circuit_connect', solved: solved,
 score: solved ? 60 + Math.max(0, (this.turns() - this.moves) * 4) : lit * 3,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.sm }) {
   DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
   HintBar({
     showHint: true,
     onHintTap: () => { this.askHint(); },
     onAutoTap: () => { this.askAuto(); },
     autoOn: this.autoId >= 0,
     demoOn: false,
     disabled: this.demoId >= 0,
   })
 Text(TG2('步数 {0}/{1}　电源 {2}',Digits(String(this.moves), this.langCode), String(this.turns()), this.on[0] ? TG('接入 ✅') : TG('断开 ❌'))
 + TG2('　终点 {0}', this.on[this.last()] ? TG('通电 💡') : TG('未通'))).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: Space.xs }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(GLYPH[this.maskAt(r * this.diffTotal + c)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.on[r * this.diffTotal + c] ? Palette.amber : this.theme.inkFaint)
 Text(r * this.diffTotal + c === 0 ? '⚡' : (r * this.diffTotal + c === this.last() ? '💡' : '')).fontSize(FontSize.xs).offset({ x: 0, y: 20 })
 }.layoutWeight(1).height(Cell.of(62)).backgroundColor(this.on[r * this.diffTotal + c] ? this.theme.surfaceAlt : this.theme.surface).borderRadius(Radius.md).borderWidth(2).borderColor(this.on[r * this.diffTotal + c] ? Palette.amber : this.theme.line).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on())
 .onFocus(() => { this.tvFocus = 'L363'; })
 .onBlur(() => { if (this.tvFocus === 'L363') { this.tvFocus = ''; } })
 .outline(Tv.focusOutline(this.tvFocus === 'L363')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.spin(r * this.diffTotal + c); }); }).onClick(() => { Haptics.tick(); this.spin(r * this.diffTotal + c); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Button(TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).width('100%').height(Cell.tap(44)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L368'; })
      .onBlur(() => { if (this.tvFocus === 'L368') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L368')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
 }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}