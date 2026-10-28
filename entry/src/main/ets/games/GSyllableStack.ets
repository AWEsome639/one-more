/**
 * 音节堆叠 —— 看中文提示，把打乱的音节按正确顺序叠成一个英文单词
 * 胜负：6 个词全部叠对通关；错叠 3 次失败 ｜ 进度：第几词 / 已叠对 / 生命 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const ROUNDS: number = 6; const LIVES: number = 3; const SLOTS: number = 6;

interface Syl { w: string; gloss: string; parts: string[]; extra: string[] }

const BANK: Syl[] = [
  { w: 'TELEPHONE', gloss: '电话 ☎️', parts: ['TE', 'LE', 'PHONE'], extra: ['TA', 'ING'] },
  { w: 'BASKETBALL', gloss: '篮球 🏀', parts: ['BAS', 'KET', 'BALL'], extra: ['BO', 'NESS'] },
  { w: 'CHOCOLATE', gloss: '巧克力 🍫', parts: ['CHO', 'CO', 'LATE'], extra: ['CHI', 'EST'] },
  { w: 'BICYCLE', gloss: '自行车 🚲', parts: ['BI', 'CY', 'CLE'], extra: ['BY', 'ING'] },
  { w: 'UMBRELLA', gloss: '雨伞 ☂️', parts: ['UM', 'BREL', 'LA'], extra: ['UN', 'LY'] },
  { w: 'HOSPITAL', gloss: '医院 🏥', parts: ['HOS', 'PI', 'TAL'], extra: ['TEL', 'ER'] },
  { w: 'PINEAPPLE', gloss: '菠萝 🍍', parts: ['PINE', 'AP', 'PLE'], extra: ['PIN', 'ER'] },
  { w: 'COMPUTER', gloss: '电脑 💻', parts: ['COM', 'PU', 'TER'], extra: ['PUT', 'OR'] },
  { w: 'MOUNTAIN', gloss: '高山 ⛰️', parts: ['MOUN', 'TAIN'], extra: ['MOON', 'LY'] },
  { w: 'SANDWICH', gloss: '三明治 🥪', parts: ['SAND', 'WICH'], extra: ['WISH', 'ES'] },
  { w: 'ELEPHANT', gloss: '大象 🐘', parts: ['E', 'LE', 'PHANT'], extra: ['AN', 'EST'] },
  { w: 'WATERMELON', gloss: '西瓜 🍉', parts: ['WA', 'TER', 'MEL'], extra: ['ON', 'ING'] }
];

/** 从 0..total-1 中随机取 k 个互不相同的下标（k=total 就是整段洗牌） */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

@Component
export struct GSyllableStack {
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
  @State private order: number[] = []; @State private qi: number = 0;
  @State private tiles: string[] = []; @State private slots: string[] = [];
  @State private built: number = 0; @State private right: number = 0;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private life: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false; @State private pressed: number = -1;

  private startAt: number = 0; private done: boolean = false; private feed: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSyllableStack')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private cur(): Syl { return BANK[this.order[this.qi]]; }
  private reset(): void {
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
    this.order = pickIndexes(BANK.length, ROUNDS);
    this.qi = 0; this.right = 0; this.life = this.total; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.pressed = -1; this.startAt = Date.now(); this.load();
  }
  private load(): void {
    const it: Syl = this.cur(); const pool: string[] = it.parts.concat(it.extra);
    this.tiles = pickIndexes(pool.length, pool.length).map((k: number) => pool[k]);
    const pad: string[] = [];
    for (let i = 0; i < SLOTS; i++) { pad.push(i < this.tiles.length ? this.tiles[i] : ''); }
    this.slots = pad; this.built = 0; this.msg = TG('按顺序点音节，叠出这个词');
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
    if (this.over || this.built >= this.cur().parts.length || this.tileIdx() < 0) {
      return true;
    }
    this.tap(this.tileIdx());
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值在 cur().parts（正确音节序列）里；tiles 是打乱的托盘 ⇒ 反查下标
  /** 下一个该点的托盘格（找不到返回 -1） */
  private tileIdx(): number {
    const parts: string[] = this.cur().parts;
    if (this.built >= parts.length) {
      return -1;
    }
    const want: string = parts[this.built];
    // ★ 2026-10-28 修：托盘是洗牌过的，不能从 built 开始找
    //   （正确音节排在已点格之前时，从 built 起永远搜不到 ⇒ 死局）
    for (let i = 0; i < this.tiles.length; i++) {
      if (this.slots.length > i && this.slots[i].length === 0) {
        continue;                      // 这一格已经叠掉了
      }
      if (this.tiles[i] === want) {
        return i;
      }
    }
    return -1;
  }

  /** 提示：报下一个音节本身 + 这个词的释义 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const parts: string[] = this.cur().parts;
    if (this.over || this.built >= parts.length) {
      return Hint.none('none');
    }
    return Hint.make([this.tileIdx()],
      TG2('接「{0}」—— 拼的是 {1}', parts[this.built], this.cur().gloss),
      TG2('Next syllable: {0}', parts[this.built]), t0);
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
    const parts: string[] = this.cur().parts;
    // ★ 2026-10-28 修：原来的 `i < this.built` 把"已点格都排在最前"当成事实，
    //   可托盘是洗牌的 ⇒ 要点的那个音节排在后面时点不到，六局里经常整局无解。
    //   ⇒ 改成看"这一格是不是已经被叠掉"（叠掉就把 slots[i] 清空）
    if (this.over || this.built >= parts.length || i >= this.tiles.length || i < 0) { return; }
    if (this.slots.length > i && this.slots[i].length === 0) { return; }
    if (this.tiles[i] === parts[this.built]) {
      this.built = this.built + 1; this.score = this.score + 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      const nd: string[] = this.slots.slice(); nd[i] = ''; this.slots = nd;
      this.msg = TG2('✅ 叠上 {0}', this.tiles[i]);
      if (this.built >= parts.length) { this.next(); }
      return;
    }
    this.life = this.life - 1; this.msg = TG2("❌ 「{0}」不该在这，还剩 {1} 条命", this.tiles[i],Digits(String(this.life), this.langCode));
    if (this.life <= 0) { this.end(); }
  }

  private next(): void {
    const solvedWord: string = this.cur().w; this.right = this.right + 1;
    if (this.right >= ROUNDS || this.qi + 1 >= ROUNDS) { this.end(); return; }
    this.qi = this.qi + 1;
    this.msg = TG2('👏 {0} —— 下一个', solvedWord);
    this.feed = setTimeout(() => { this.feed = -1; this.load(); }, 600);
  }
  private end(): void {
    if (this.done) { return; }
    this.over = true; this.won = this.right >= ROUNDS; this.done = true;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("叠对 {0}/{1}", this.right, ROUNDS);
    const r: GameResult = { gameId: 'syllable_stack', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private progressText(): string {
    const parts: string[] = this.cur().parts; const out: string[] = [];
    for (let i = 0; i < parts.length; i++) { out.push(i < this.built ? parts[i] : '＿'); }
    return out.join(' · ');
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
        Text(TG2('词 {0}/{1}　叠对 {2}', Math.min(this.qi + 1, ROUNDS), ROUNDS, this.right)
          + TG2('　生命 {0}',Digits(String(this.life), this.langCode))).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).layoutWeight(1)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.xl)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(this.cur().gloss).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.progressText()).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        Text(TG2("共 {0} 个音节", this.cur().parts.length)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        this.slot(0)
        this.slot(1)
        this.slot(2)
      }.width('100%')
      Row({ space: Space.sm }) {
        this.slot(3)
        this.slot(4)
        this.slot(5)
      }.width('100%')
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
                Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
      Text(TG('提示：每个词都混进了 2 个假音节')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  slot(i: number) {
    Text(this.slots[i]).fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      .fontColor(this.slots[i].length === 0 ? this.theme.inkFaint : this.theme.ink)
      .layoutWeight(1).height(Cell.of(52))
      .backgroundColor(this.slots[i].length === 0 ? this.theme.surfaceAlt : this.theme.surface).animation({ duration: Motion.fast, curve: Motion.snap() })
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pressed === i ? Motion.pressScale : 1, y: this.pressed === i ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap(i); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
      .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressed = i; } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; } })
  }
}
