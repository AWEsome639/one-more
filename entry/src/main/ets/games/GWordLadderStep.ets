/**
 * 阶梯一步 —— 每题四个候选，挑出「只改一个字母、且是真实单词」的那个
 * 胜负：10 题内生命不耗尽通关｜生命耗尽失败｜进度：题号 / 生命 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const DICT: string =
  'ABLE ACHE ACID ACRE AGED AIDE AREA ARMY AUNT AWAY BABY BACK BAKE BALL BAND BANK BARE BARN BASE BATH BEAD BEAM BEAN BEAR BEAT BEEN BEER BELL BELT BEND BEST BIKE BILL BIRD BITE BLUE BOAT BODY BOIL BOLD BOLT BOMB BOND BONE BOOK BOOM BOOT BORE BORN BOSS BOTH BOWL BULK BULL BURN BUSH BUSY CAFE CAGE CAKE CALL CALM CAME CAMP CARD CARE CART CASE CASH CAST CAVE CELL CHAT CHEF CHIN CHIP CITE CITY CLAM CLAP CLAW CLAY CLIP CLUB COAL COAT CODE COIN COLD COME CONE COOK COOL COPE COPY CORD CORE CORN COST CRAB CREW CROP CROW CUBE CURB CURE CURL DARE DARK DART DASH DATA DATE DAWN DEAL DEAR DEBT DECK DEEP DEER' +
  ' DESK DIAL DIET DIRT DISC DISH DIVE DOCK DOLL DONE DOOR DOSE DOWN DRAG DRAW DROP DRUM DUAL DUCK DULL DUNE DUSK DUST DUTY EACH EARL EARN EASE EAST EASY ECHO EDGE EPIC EVEN EVER EVIL EXAM EXIT FACE FACT FADE FAIL FAIR FAKE FALL FAME FARM FAST FATE FEAR FEAT FEED FEEL FELT FILE FILL FILM FIND FINE FIRE FIRM FISH FIST FIVE FLAG FLAT FLAW FLED FLEE FLEW FLIP FLOW FOAM FOIL FOLD FOLK FOND FONT FOOD FOOL FOOT FORK FORM FORT FOUL FOUR FREE FROG FUEL FULL FUND FUSE GAIN GAME GANG GATE GAVE GAZE GEAR GENE GIFT GIRL GIVE GLAD GLOW GLUE GOAL GOAT GOLD GOLF GONE GOOD GOWN GRAB GRAY GRID GRIM GRIN GRIP GROW' +
  ' GULF HAIR HALF HALL HAND HANG HARD HARM HARP HATE HAVE HAWK HAZE HEAD HEAL HEAP HEAR HEAT HEEL HELL HELP HERB HERD HERE HERO HIDE HIGH HIKE HILL HINT HIRE HOLD HOLE HOLY HOME HOOK HOPE HORN HOSE HOST HOUR HUGE HUNT HURT HYMN ICON IDEA IDLE INCH INTO IRON ITEM JADE JAIL JAZZ JOIN JOKE JUMP JURY JUST KEEN KEEP KEPT KICK KIND KING KISS KNEE KNEW KNIT KNOB KNOT KNOW LACK LADY LAID LAKE LAMP LAND LANE LAST LATE LAZY LEAD LEAF LEAN LEAP LEFT LEND LENS LESS LIAR LICK LIFE LIFT LIKE LIMB LIME LINE LINK LION LIST LIVE LOAD LOAF LOAN LOCK LOFT LOGO LONE LONG LOOK LOOP LORD LOSE LOSS LOST LOUD LOVE LUCK';
const WORDS: string[] = DICT.split(' '); const LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const ROUNDS: number = 10; const LIVES: number = 3; const LEN: number = 4;
const FEED_MS: number = 620; const CONSONANTS: string = 'XQZJKVWY';
interface Option { text: string; ok: boolean }
function isWord(w: string): boolean { return (' ' + DICT + ' ').indexOf(' ' + w + ' ') >= 0; }
function differs(a: string, b: string): number {
  let n: number = 0;
  for (let i = 0; i < LEN; i++) { if (a.charAt(i) !== b.charAt(i)) { n++; } }
  return n;
}
function mixOptions(src: Option[]): Option[] {
  const out: Option[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: Option = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GWordLadderStep {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State cur: string = ''; @State opts: Option[] = []; @State round: number = 1;
  @State lives: number = LIVES; @State score: number = 0; @State streak: number = 0;
  @State picked: number = -1; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private settled: boolean = false; private feed: number = -1;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordLadderStep')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stopFeed(); }
  private stopFeed(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }
  private reset(): void {
    this.stopFeed();
    this.round = 1; this.lives = LIVES; this.score = 0; this.streak = 0; this.picked = -1;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.buildRound();
  }
  private mangle(w: string): string {
    const arr: string[] = w.split('');
    const a: number = Math.floor(Math.random() * LEN);
    let b: number = Math.floor(Math.random() * LEN);
    if (b === a) { b = (a + 1) % LEN; }
    arr[a] = LETTERS.charAt(Math.floor(Math.random() * LETTERS.length));
    arr[b] = LETTERS.charAt(Math.floor(Math.random() * LETTERS.length));
    return arr.join('');
  }
  private buildRound(): void {
    let cur: string = WORDS[Math.floor(Math.random() * WORDS.length)];
    const good: string[] = [];
    for (let guard = 0; guard < 30 && good.length === 0; guard++) {
      for (let i = 0; i < LEN; i++) {
        for (let k = 0; k < LETTERS.length; k++) {
          const c: string = LETTERS.charAt(k);
          if (c === cur.charAt(i)) { continue; }
          const cand: string = cur.substring(0, i) + c + cur.substring(i + 1);
          if (isWord(cand) && good.indexOf(cand) < 0) { good.push(cand); }
        }
      }
      if (good.length === 0) { cur = WORDS[Math.floor(Math.random() * WORDS.length)]; }
    }
    const bad: string[] = [];
    for (let guard = 0; guard < 400 && bad.length < 3; guard++) {
      const cand: string = this.mangle(cur);
      if (differs(cand, cur) < 2 || isWord(cand) || bad.indexOf(cand) >= 0) { continue; }
      bad.push(cand);
    }
    while (bad.length < 3) { bad.push(CONSONANTS + LETTERS.charAt(bad.length)); }
    this.cur = cur;
    this.opts = mixOptions([{ text: good[Math.floor(Math.random() * good.length)], ok: true },
      { text: bad[0], ok: false }, { text: bad[1], ok: false }, { text: bad[2], ok: false }]);
    this.picked = -1;
  }
  /** 提示：哪个选项是对的（代打就是找 opts[i].ok） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        return Hint.make([i],
          TG2('选「{0}」', this.opts[i].text),
          TG2('Pick "{0}"', this.opts[i].text), t0);
      }
    }
    // ★ 找不到 ok ⇒ 不是"算不出"，是"还没出题"：明确告诉玩家等一等
    return Hint.make([],
      TG('还没出题，等一下再点'),
      TG('Not dealt yet — try again in a moment'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 选项型直取：找 opts[i].ok 的那个
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    if (this.picked >= 0) {
      return true;              // 已答，等它换下一题
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
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

  private tap(i: number): void {
    if (this.over || this.picked >= 0 || this.opts.length <= i) { return; }
    this.picked = i;
    if (this.opts[i].ok) {
      this.streak = this.streak + 1; this.score = this.score + 100 + this.streak * 20;
      this.msg = TG2('✅ 对了：{0} 只差一个字母，也是词', this.opts[i].text);
    } else {
      this.streak = 0; this.lives = this.lives - 1;
      this.msg = TG2('❌ {0} 不是词库里的单词', this.opts[i].text);
    }
    this.feed = setTimeout(() => { this.next(); }, FEED_MS);
  }
  private next(): void {
    this.feed = -1;
    if (this.lives <= 0) {
      this.over = true; this.msg = TG2("❌ 生命耗尽，撑到第 {0} 题",Digits(String(this.round), this.langCode)); this.finish(false); return;
    }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = true; this.msg = TG2('🎉 {0} 题全过，通关！',Digits(String(this.diffTotal), this.langCode)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    this.round = this.round + 1;
    this.msg = TG2("第 {0} 题：挑只差一个字母的真实单词", this.round);
    this.buildRound();
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true; this.stopFeed();
    const r: GameResult = { gameId: 'word_ladder_step', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private toneOf(i: number): string {
    if (this.picked < 0 || this.opts.length <= i) { return this.theme.surface; }
    if (i === this.picked) { return this.opts[i].ok ? Palette.emerald : Palette.rose; }
    return this.opts[i].ok ? Palette.emerald : this.theme.surface;
  }
  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + ' ❤')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.cur).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG2('连击 {0}', this.streak)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => { Text(this.opts.length > (i) ? this.opts[(i)].text : '').fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.opts.length > (i) && this.picked >= 0 && ((i) === this.picked || this.opts[(i)].ok) ? '#FFFFFF' : this.theme.ink).width('100%').height(Cell.of(52)).backgroundColor(this.toneOf((i))).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((i)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((i)); }); }) }, (i: number) => 'o' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：选「改一个字母就是真词」的那个；另外三个其实不是单词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
