/** 回文构造 —— 用给定的字母摆出回文（6 题解出 ≥4 通关 ｜ 进度：题号/答对/倒计时） */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 6; const PASS: number = 4; const FEED_MS: number = 900;
const LIMIT_MS: number = 25000; const TICK_MS: number = 100;
const WORDS: string[] = ['RACECAR', 'LEVEL', 'RADAR', 'MADAM', 'REFER', 'KAYAK',
  'CIVIC', 'DEIFIED', 'ROTATOR', 'SOLOS', 'MINIM', 'NOON'];
function shuffled(text: string): string[] {
  const out: string[] = text.split('');
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: string = out[i]; out[i] = out[j]; out[j] = tmp;
  }
  return out;
}
function isPalindrome(s: string): boolean {
  let i: number = 0; let j: number = s.length - 1;
  while (i < j) {
    if (s.charAt(i) !== s.charAt(j)) { return false; } else { i = i + 1; j = j - 1; }
  }
  return true;
}

@Component
export struct GPalindromeBuilder {
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
  onFinish: (r: GameResult) => void = () => {};
  @State word: string = ''; @State pool: string[] = []; @State used: number[] = [];
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State leftMs: number = this.diffTotal; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false; @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop(); this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.nextQ(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private nextQ(): void {
    const w: string = WORDS[Math.floor(Math.random() * WORDS.length)];
    this.word = w; this.pool = shuffled(w); this.used = [];
    this.leftMs = this.diffTotal; this.roundAt = Date.now(); this.msg = TG('按顺序点字母，摆出一个回文');
  }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; } const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：例如 {0}', this.word); this.advance(); }
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
    if (this.feed >= 0 || this.used.length >= this.pool.length) {
      return true;
    }
    this.tap(this.palPlan()[this.used.length]);
    return !this.over;
  }

  /** 提示：报出该按什么顺序点字母（摆出来的回文本身） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    const plan: number[] = this.palPlan();
    let text: string = '';
    for (let i = 0; i < plan.length; i++) { text = text + this.pool[plan[i]]; }
    return Hint.make(plan,
      TG2('按这个顺序点：{0}（摆出来是回文）', text),
      'Tap in this order: ' + text, t0);
  }

  /** 辅助：要按的 pool 下标顺序 —— 把字母配对成回文再映射回下标 */
  private palPlan(): number[] {
    const n: number = this.pool.length;
    const cnt: number[] = new Array<number>(26).fill(0);
    for (let i = 0; i < n; i++) { cnt[this.pool[i].charCodeAt(0) - 65] = cnt[this.pool[i].charCodeAt(0) - 65] + 1; }
    let odd: number = 0;
    for (let k = 0; k < 26; k++) { if (cnt[k] % 2 === 1) { odd = odd + 1; } }
    const natural: number[] = [];
    for (let i = 0; i < n; i++) { natural.push(i); }
    if (odd > 1) { return natural; }        // 摆不成回文（本款不会发生）：退回原顺序
    const half: string[] = [];
    let mid: string = '';
    for (let k = 0; k < 26; k++) {
      let c: number = cnt[k];
      if (c % 2 === 1) { mid = String.fromCharCode(65 + k); c = c - 1; }
      for (let j = 0; j < (c - c % 2) / 2; j++) { half.push(String.fromCharCode(65 + k)); }
    }
    const target: string = half.join('') + mid + half.slice().reverse().join('');
    if (target.length !== n) { return natural; }
    const taken: boolean[] = [];
    for (let i = 0; i < n; i++) { taken.push(false); }
    const out: number[] = [];
    for (let p = 0; p < n; p++) {
      const ch: string = target.charAt(p);
      let found: number = -1;
      for (let i = 0; i < n; i++) {
        if (!taken[i] && this.pool[i] === ch) { found = i; break; }
      }
      if (found < 0) { return natural; }
      taken[found] = true;
      out.push(found);
    }
    return out;
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
    if (this.over || this.feed >= 0) { return; }
    if (i >= this.pool.length || this.used.indexOf(i) >= 0) { return; }
    const next: number[] = this.used.concat([i]); this.used = next;
    if (next.length >= this.pool.length) { this.check(); }
  }
  private back(): void {
    if (this.over || this.feed >= 0 || this.used.length === 0) { return; } else { this.used = this.used.slice(0, this.used.length - 1); }
  }
  private built(full: boolean): string {
    const parts: string[] = [];
    for (let i = 0; i < this.pool.length; i++) {
      parts.push(i < this.used.length ? this.pool[this.used[i]] : (full ? '' : '·'));
    }
    return parts.join(full ? '' : ' ');
  }
  private check(): void {
    const s: string = this.built(true);
    if (isPalindrome(s)) {
      const gain: number = 100 + Math.floor(this.leftMs / 60); this.right = this.right + 1; this.score = this.score + gain;
      this.msg = TG2('✅ {0} 是回文　+{1}', s, String(gain));
      this.advance();
      return;
    }
    this.msg = TG2('❌ {0} 正读倒读不一样，再摆一次', s); this.used = [];
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1; if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("解出 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.nextQ(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'palindrome_builder', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(TG('摆出的回文')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.built(false)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
          .textAlign(TextAlign.Center).width('100%')
        Text(TG2("共 {0} 个字母，已用 {1}", String(this.pool.length), String(this.used.length)))
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach(this.pool, (ch: string, i: number) => {
          Text((ch)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.used.indexOf((i)) >= 0 ? this.theme.inkFaint : this.theme.ink)
          .layoutWeight(1).height(Cell.of(54))
          .backgroundColor(this.used.indexOf((i)) >= 0 ? this.theme.line : this.theme.surface)
          .borderRadius(Radius.sm).shadow(Shadow.card)
          .scale({ x: this.pressed === (i) ? Motion.pressScale : 1, y: this.pressed === (i) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; } })
          .onClick(() => { Haptics.tick(); this.tap((i)); })
        }, (ch: string, i: number) => 'p' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(TG('退一格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.back(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
