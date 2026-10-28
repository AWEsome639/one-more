/** 不发音字母 —— 从字母格里点出那个不发音的字母｜胜负：10 题答对 ≥7 通关，错 3 次失败 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 10; const PASS: number = 7; const LIVES: number = 3; const GAP_MS: number = 800;

interface SW { w: string; i: number; zh: string }

/** i = 不发音字母的下标 */
const WORDS: SW[] = [
  { w: 'KNIFE', i: 0, zh: '小刀' }, { w: 'ISLAND', i: 1, zh: '岛' },
  { w: 'CASTLE', i: 3, zh: '城堡' }, { w: 'LAMB', i: 3, zh: '羔羊' },
  { w: 'HONEST', i: 0, zh: '诚实' }, { w: 'GHOST', i: 1, zh: '幽灵' },
  { w: 'KNEE', i: 0, zh: '膝盖' }, { w: 'DEBT', i: 3, zh: '债务' },
  { w: 'SIGN', i: 2, zh: '标志' }, { w: 'CALM', i: 2, zh: '平静' },
  { w: 'WRIST', i: 0, zh: '手腕' }, { w: 'COMB', i: 3, zh: '梳子' },
  { w: 'LISTEN', i: 3, zh: '听' }, { w: 'WHISTLE', i: 4, zh: '哨子' },
  { w: 'RECEIPT', i: 5, zh: '收据' }, { w: 'THUMB', i: 4, zh: '拇指' },
  { w: 'SWORD', i: 1, zh: '剑' }, { w: 'HALF', i: 2, zh: '一半' },
  { w: 'CHRISTMAS', i: 1, zh: '圣诞节' }, { w: 'HOUR', i: 0, zh: '小时' }
];

function shufIdx(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) { out.push(i); }
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSilentLetterSearch {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State plan: number[] = []; @State letters: string[] = []; @State qi: number = 0;
  @State right: number = 0; @State lives: number = LIVES; @State score: number = 0;
  @State picked: number = -1; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }
  private ansIdx(): number { return WORDS[this.plan[this.qi]].i; }

  private reset(): void {
    this.stop();
    this.plan = shufIdx(WORDS.length).slice(0, this.diffTotal);
    this.qi = 0; this.right = 0; this.lives = LIVES; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.next();
  }

  private next(): void {
    this.letters = WORDS[this.plan[this.qi]].w.split('');
    this.picked = -1;
    this.msg = TG2('点出「{0}」里不发音的字母', WORDS[this.plan[this.qi]].zh);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;
    }
    this.pick(WORDS[this.plan[this.qi]].i);
    return !this.over;
  }

  /** 提示：第几个字母不发音 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.picked >= 0) {
      return Hint.none('none');
    }
    const cur: SW = WORDS[this.plan[this.qi]];
    return Hint.make([cur.i], TG2('第 {0} 个字母不发音', String(cur.i + 1)),
      TG2('Letter {0} is silent', String(cur.i + 1)), t0);
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

  private pick(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    const cur: SW = WORDS[this.plan[this.qi]];
    this.picked = i;
    if (i === cur.i) {
      this.right = this.right + 1; this.score = this.score + 100; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ {0} 里的 {1} 不发音', cur.w, cur.w.charAt(cur.i));
    } else {
      this.lives = this.lives - 1;
      this.msg = TG2('❌ {0} 里不发音的是 {1}', cur.w, cur.w.charAt(cur.i));
    }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    if (this.lives <= 0) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 机会用尽 —— 答对 {0} / {1}', this.right, this.diffTotal);
      this.finish(false); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'silent_letter_search', solved: solved, score: this.score,
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(((this.qi + 1) + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(TG('🔠 哪个字母不发音？')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Row({ space: Space.xs }) {
          ForEach(this.letters, (c: string, i: number) => {
            Text(this.letters.length > (i) ? this.letters[(i)] : '')
            .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor(this.picked === (i) ? '#FFFFFF' : this.theme.ink)
            .backgroundColor(this.picked < 0 ? this.theme.surfaceAlt
            : ((i) === this.ansIdx() ? Palette.emerald : ((i) === this.picked ? Palette.rose : this.theme.surfaceAlt)))
            .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(50))
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { Haptics.tick(); this.pick((i)); })
          }, (c: string, i: number) => 'L' + i)
        }.width('100%')
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2("{0} 题，答对 ≥{1} 通关：点错扣一条命",Digits(String(this.diffTotal), this.langCode), PASS))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
