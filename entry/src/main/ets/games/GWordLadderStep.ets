/**
 * 阶梯一步 —— 每题四个候选，挑出「只改一个字母、且是真实单词」的那个
 * 胜负：10 题内生命不耗尽通关｜生命耗尽失败｜进度：题号 / 生命 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
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
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State cur: string = ''; @State opts: Option[] = []; @State round: number = 1;
  @State lives: number = LIVES; @State score: number = 0; @State streak: number = 0;
  @State picked: number = -1; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private settled: boolean = false; private feed: number = -1;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
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
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 选项型直取：找 opts[i].ok 的那个
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
        ForEach([0, 1, 2, 3], (i: number) => { Text(this.opts.length > (i) ? this.opts[(i)].text : '').fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.opts.length > (i) && this.picked >= 0 && ((i) === this.picked || this.opts[(i)].ok) ? '#FFFFFF' : this.theme.ink).width('100%').height(Cell.of(52)).backgroundColor(this.toneOf((i))).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((i)); }) }, (i: number) => 'o' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      HintBar({
        onAutoTap: () => { this.askAuto(); },
        showHint: false,
        autoOn: this.autoId >= 0
      })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：选「改一个字母就是真词」的那个；另外三个其实不是单词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
