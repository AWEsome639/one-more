/**
 * 找单词 —— 8×8 字母阵里藏着 4 个单词，点首尾两格把它们圈出来
 * 胜负：90 秒内找齐 4 个通关｜超时失败｜进度：已找 / 得分 / 剩余时间
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
const N: number = 8; const CELLS: number = N * N; const COUNT: number = 4;
const LIMIT_MS: number = 90000; const TICK_MS: number = 100;
const LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const BANK: string[] = ['TIGER', 'RIVER', 'CLOUD', 'MUSIC', 'BREAD', 'HONEY',
  'STONE', 'PLANT', 'SNAKE', 'GREEN', 'CHAIR', 'LIGHT', 'DREAM', 'TRAIN'];
function mixList(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GWordSearch {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State grid: string[] = []; @State words: string[] = []; @State found: boolean[] = [];
  @State mark: number[] = []; @State sel: number[] = []; @State msg: string = '';
  @State score: number = 0; @State leftMs: number = this.diffTotal;
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }
  private stopTimer(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }
  private reset(): void {
    this.stopTimer();
    const pick: string[] = mixList(BANK).slice(0, COUNT);
    const grid: string[] = new Array<string>(CELLS).fill('');
    for (let i = 0; i < pick.length; i++) { this.place(grid, pick[i]); }
    for (let i = 0; i < CELLS; i++) {
      if (grid[i] === '') { grid[i] = LETTERS.charAt(Math.floor(Math.random() * LETTERS.length)); }
    }
    this.grid = grid; this.words = pick; this.found = new Array<boolean>(COUNT).fill(false);
    this.mark = []; this.sel = []; this.score = 0; this.leftMs = this.diffTotal;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.msg = TG('点一个词的首尾两格，把它圈出来');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  /** 横放或竖放塞进空格子；重叠处字母必须相同 */
  private place(grid: string[], w: string): void {
    for (let t = 0; t < 80; t++) {
      const flat: boolean = Math.random() < 0.5;
      const r: number = flat ? Math.floor(Math.random() * N) : Math.floor(Math.random() * (N - w.length + 1));
      const c: number = flat ? Math.floor(Math.random() * (N - w.length + 1)) : Math.floor(Math.random() * N);
      let fits: boolean = true;
      for (let k = 0; k < w.length; k++) {
        const idx: number = flat ? r * N + c + k : (r + k) * N + c;
        if (grid[idx] !== '' && grid[idx] !== w.charAt(k)) { fits = false; break; }
      }
      if (!fits) { continue; }
      for (let k = 0; k < w.length; k++) { grid[flat ? r * N + c + k : (r + k) * N + c] = w.charAt(k); }
      return;
    }
  }
  private tick(): void {
    if (this.over) { return; }
    const gap: number = Date.now() - this.startAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.over = true; this.msg = '⌛ 时间到 —— 找到 ' + this.hits() + ' / ' + COUNT + TG(' 个词'); this.finish(false); }
  }
  private hits(): number {
    let n: number = 0;
    for (let i = 0; i < this.found.length; i++) { if (this.found[i]) { n++; } }
    return n;
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
    if (false) {
      return true;
    }
    this.tap(this.wsNext());
    return !this.over;
  }

  /** 提示：报出哪个词在哪一行/列，以及该点哪两格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    for (let i = 0; i < this.words.length; i++) {
      if (this.found[i]) { continue; }
      const ln: number[] = this.wsLine(this.words[i]);
      if (ln.length !== 2) { continue; }
      const r1: number = Math.floor(ln[0] / N) + 1;
      const c1: number = ln[0] % N + 1;
      const r2: number = Math.floor(ln[1] / N);
      if (r1 === r2 + 1) {
        return Hint.make(ln,
          TG2('「{0}」横在第 {1} 行，从第 {2} 列开始', this.words[i], String(r1), String(c1)),
          'Word ' + this.words[i], t0);
      }
      return Hint.make(ln,
        TG2('「{0}」竖在第 {1} 列，从第 {2} 行开始', this.words[i], String(c1), String(r1)),
        'Word ' + this.words[i], t0);
    }
    return Hint.none('none');
  }

  /** 辅助：某个词在盘上的首尾两格（找不到返回空数组） */
  private wsLine(w: string): number[] {
    for (let r = 0; r < N; r++) {
      for (let c = 0; c + w.length <= N; c++) {
        let t: string = '';
        for (let k = 0; k < w.length; k++) { t = t + this.grid[r * N + c + k]; }
        const b: string = t.split('').reverse().join('');
        if (t === w || b === w) { return [r * N + c, r * N + c + w.length - 1]; }
      }
    }
    for (let c = 0; c < N; c++) {
      for (let r = 0; r + w.length <= N; r++) {
        let t: string = '';
        for (let k = 0; k < w.length; k++) { t = t + this.grid[(r + k) * N + c]; }
        const b: string = t.split('').reverse().join('');
        if (t === w || b === w) { return [r * N + c, (r + w.length - 1) * N + c]; }
      }
    }
    return [];
  }

  /** 辅助：这一步该点哪一格（先点首格，再点尾格；-1 = 没有可找的了） */
  private wsNext(): number {
    if (this.sel.length > 0) {
      const first: number = this.sel[0];
      for (let i = 0; i < this.words.length; i++) {
        if (this.found[i]) { continue; }
        const ln: number[] = this.wsLine(this.words[i]);
        if (ln.length !== 2) { continue; }
        if (ln[0] === first) { return ln[1]; }
        if (ln[1] === first) { return ln[0]; }
      }
      return first;                 // 兜底：再点同一格 = 取消选择
    }
    for (let i = 0; i < this.words.length; i++) {
      if (this.found[i]) { continue; }
      const ln: number[] = this.wsLine(this.words[i]);
      if (ln.length === 2) { return ln[0]; }
    }
    return -1;
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

  private tap(i: number): void {
    if (this.over) { return; }
    if (this.sel.length === 0) { this.sel = [i]; this.msg = TG('再点这个词的另一头'); return; }
    const first: number = this.sel[0];
    if (first === i) { this.sel = []; this.msg = TG('已取消'); return; }
    const r1: number = Math.floor(first / N); const c1: number = first % N;
    const r2: number = Math.floor(i / N); const c2: number = i % N;
    if (r1 !== r2 && c1 !== c2) { this.sel = [i]; this.msg = TG('要选同一行或同一列的两格'); return; }
    const line: number[] = [];
    if (r1 === r2) {
      const a: number = c1 < c2 ? c1 : c2; const b: number = c1 < c2 ? c2 : c1;
      for (let c = a; c <= b; c++) { line.push(r1 * N + c); }
    } else {
      const a: number = r1 < r2 ? r1 : r2; const b: number = r1 < r2 ? r2 : r1;
      for (let r = a; r <= b; r++) { line.push(r * N + c1); }
    }
    let text: string = '';
    for (let k = 0; k < line.length; k++) { text = text + this.grid[line[k]]; }
    const back: string = text.split('').reverse().join('');
    this.sel = [];
    let hit: number = -1;
    for (let k = 0; k < this.words.length; k++) {
      if (!this.found[k] && (this.words[k] === text || this.words[k] === back)) { hit = k; break; }
    }
    if (hit < 0) { this.msg = TG2('❌ {0} 不是藏着的词', text); return; }
    const next: boolean[] = this.found.slice(); next[hit] = true; this.found = next;
    this.mark = this.mark.concat(line); this.score = this.score + 150;
    if (this.hits() >= COUNT) {
      this.over = true; this.won = true; this.msg = TG('🎉 4 个词全找到，通关！'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    this.msg = TG2('✅ 找到 {0}（{1}/{2}）', this.words[hit], this.hits(), COUNT);
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true; this.stopTimer();
    const r: GameResult = { gameId: 'word_search', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits() };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private toneAt(i: number): string {
    if (this.mark.indexOf(i) >= 0) { return Palette.emerald; }
    return this.sel.indexOf(i) >= 0 ? Palette.primary : this.theme.surface;
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('已找'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits() + ' / ' + COUNT)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (c: number) => { Text(this.grid.length > (r * N + c) ? this.grid[(r * N + c)] : '').fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.mark.indexOf((r * N + c)) >= 0 || this.sel.indexOf((r * N + c)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).aspectRatio(1).backgroundColor(this.toneAt((r * N + c))).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * N + c)); })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(TG2('藏词：{0}', this.words.join(' · '))).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：单词只横放或竖放，点首尾两格即可（倒着也算）')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
