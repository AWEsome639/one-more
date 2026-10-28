/**
 * 单词阶梯 —— 每次只换一个字母，把起点词一步步走成目标词（词库里都是真实单词）
 * 胜负：步数上限内到达目标词通关｜步数用尽未到失败｜进度：步数 / 剩余 / 目标
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
const DICT: string =
  'ABLE ACHE ACID ACRE AGED AIDE AREA ARMY AUNT AWAY BABY BACK BAKE BALL BAND BANK BARE BARN BASE BATH BEAD BEAM BEAN BEAR BEAT BEEN BEER BELL BELT BEND BEST BIKE BILL BIRD BITE BLUE BOAT BODY BOIL BOLD BOLT BOMB BOND BONE BOOK BOOM BOOT BORE BORN BOSS BOTH BOWL BULK BULL BURN BUSH BUSY CAFE CAGE CAKE CALL CALM CAME CAMP CARD CARE CART CASE CASH CAST CAVE CELL CHAT CHEF CHIN CHIP CITE CITY CLAM CLAP CLAW CLAY CLIP CLUB COAL COAT CODE COIN COLD COME CONE COOK COOL COPE COPY CORD CORE CORN COST CRAB CREW CROP CROW CUBE CURB CURE CURL DARE DARK DART DASH DATA DATE DAWN DEAL DEAR DEBT DECK DEEP DEER' +
  ' DESK DIAL DIET DIRT DISC DISH DIVE DOCK DOLL DONE DOOR DOSE DOWN DRAG DRAW DROP DRUM DUAL DUCK DULL DUNE DUSK DUST DUTY EACH EARL EARN EASE EAST EASY ECHO EDGE EPIC EVEN EVER EVIL EXAM EXIT FACE FACT FADE FAIL FAIR FAKE FALL FAME FARM FAST FATE FEAR FEAT FEED FEEL FELT FILE FILL FILM FIND FINE FIRE FIRM FISH FIST FIVE FLAG FLAT FLAW FLED FLEE FLEW FLIP FLOW FOAM FOIL FOLD FOLK FOND FONT FOOD FOOL FOOT FORK FORM FORT FOUL FOUR FREE FROG FUEL FULL FUND FUSE GAIN GAME GANG GATE GAVE GAZE GEAR GENE GIFT GIRL GIVE GLAD GLOW GLUE GOAL GOAT GOLD GOLF GONE GOOD GOWN GRAB GRAY GRID GRIM GRIN GRIP GROW' +
  ' GULF HAIR HALF HALL HAND HANG HARD HARM HARP HATE HAVE HAWK HAZE HEAD HEAL HEAP HEAR HEAT HEEL HELL HELP HERB HERD HERE HERO HIDE HIGH HIKE HILL HINT HIRE HOLD HOLE HOLY HOME HOOK HOPE HORN HOSE HOST HOUR HUGE HUNT HURT HYMN ICON IDEA IDLE INCH INTO IRON ITEM JADE JAIL JAZZ JOIN JOKE JUMP JURY JUST KEEN KEEP KEPT KICK KIND KING KISS KNEE KNEW KNIT KNOB KNOT KNOW LACK LADY LAID LAKE LAMP LAND LANE LAST LATE LAZY LEAD LEAF LEAN LEAP LEFT LEND LENS LESS LIAR LICK LIFE LIFT LIKE LIMB LIME LINE LINK LION LIST LIVE LOAD LOAF LOAN LOCK LOFT LOGO LONE LONG LOOK LOOP LORD LOSE LOSS LOST LOUD LOVE LUCK' +
  ' LUNG MADE MAID MAIL MAIN MAKE MALE MALL MANY MARE MARK MASK MASS MAST MATE MATH MEAL MEAN MEAT MELT MERE MESS MICE MILD MILE MILK MILL MIND MINE MINT MIST MODE MOLE MONK MOOD MOON MORE MOSS MOST MOVE MUCH MUST MUTE MYTH NAIL NAME NAVY NEAR NEAT NECK NEED NEST NEWS NEXT NICE NINE NODE NOON NOSE NOTE NOUN OBEY ONCE ONLY ONTO OPEN ORAL OVAL OVER PACE PACK PAGE PAID PAIL PAIN PAIR PALE PALM PARK PART PASS PAST PATH PEAK PEAR PECK PEEL PEER PICK PIER PILE PILL PINE PINK PIPE PLAN PLAY PLOT PLUS POEM POET POLE POLL POND POOL POOR PORE PORK PORT POSE POST POUR PRAY PREY PULL PULP PUMP PURE PUSH QUIZ' +
  ' RACE RAIL RAIN RANK RARE RASH RATE READ REAL REAP REAR RENT REST RICE RICH RIDE RING RISE RISK ROAD ROAM ROAR ROBE ROCK RODE ROLE ROLL ROOF ROOM ROOT ROPE ROSE RUDE RUIN RULE RUNG RUSH RUST SAFE SAID SAIL SAKE SALE SALT SAME SAND SANE SANG SAVE SCAN SEAL SEAM SEAT SEED SEEK SEEM SEEN SELF SELL SEND SENT SHIP SHOE SHOP SHOT SHOW SHUT SICK SIDE SIGH SIGN SILK SING SINK SITE SIZE SKIN SLID SLIM SLIP SLOW SNAP SNOW SOAK SOAP SOFA SOFT SOIL SOLD SOLE SOME SONG SOON SORE SORT SOUL SOUP SPIN SPOT STAR STAY STEM STEP STIR STOP SUCH SUIT SURE SWAM SWAN SWAP SWIM TACK TAIL TAKE TALE TALK TALL TAME TANK' +
  ' TAPE TASK TEAL TEAM TEAR TELL TEND TENT TERM TEST TEXT THAN THAT THEM THEN THEY THIN THIS THUS TICK TIDE TIDY TIED TILE TILL TILT TIME TINY TIRE TOAD TOIL TOLD TOLL TOMB TONE TOOK TOOL TORN TOSS TOUR TOWN TRAP TRAY TREE TRIM TRIP TRUE TUBE TUNE TURN TWIN TYPE UNIT UPON USED USER VAIN VASE VAST VEIL VEIN VERB VERY VEST VIEW VINE VOID VOTE WADE WAGE WAIT WAKE WALK WALL WAND WANT WARD WARM WARN WASH WAVE WEAK WEAR WEED WEEK WEEP WELL WENT WERE WEST WHAT WHEN WHIP WHOM WIDE WIFE WILD WILL WIND WINE WING WINK WIPE WIRE WISE WISH WITH WOKE WOLF WOOD WOOL WORD WORE WORK WORM WORN YARD YARN YEAR YELL' +
  ' YOUR ZERO ZONE';
const LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'; const LEN: number = 4;
interface Ladder { from: string; to: string; limit: number }
const LADDERS: Ladder[] = [
  { from: 'COLD', to: 'WARM', limit: 6 }, { from: 'LOVE', to: 'HATE', limit: 6 },
  { from: 'RICE', to: 'MILK', limit: 5 }, { from: 'DARK', to: 'LAMP', limit: 7 },
  { from: 'HEAD', to: 'TAIL', limit: 7 }, { from: 'HAND', to: 'FOOT', limit: 7 },
  { from: 'FIRE', to: 'WOOD', limit: 6 }, { from: 'BALL', to: 'GAME', limit: 6 }
];
function isWord(w: string): boolean { return (' ' + DICT + ' ').indexOf(' ' + w + ' ') >= 0; }
@Component
export struct GWordLadder {
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
  @State from: string = ''; @State to: string = ''; @State word: string = '';
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State limit: number = GameDiff.pick(9, 6, 4); @State steps: number = 0; @State pick: number = -1;
  @State trail: string[] = []; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordLadder')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void { this.reset(); }
  private reset(): void {
    const l: Ladder = LADDERS[Math.floor(Math.random() * LADDERS.length)];
    this.from = l.from; this.to = l.to; this.limit = l.limit; this.word = l.from;
    this.limit = GameDiff.pick(9, 6, 4);   // ★ 难度作用到玩法：步数上限（简单 9 / 普通 6 / 困难 4）
    this.trail = [l.from]; this.steps = 0; this.pick = -1;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.msg = TG2('点一个字母位，再从键盘挑新字母（{0} 步内到 {1}）', l.limit, l.to);
  }
  private left(): number { const n: number = this.limit - this.steps; return n > 0 ? n : 0; }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 没有"答案字段"—— 在词库上做 BFS，求「当前词 → 目标词」的最短阶梯
  private aiWords: string[] = [];

  private aiDict(): string[] {
    if (this.aiWords.length === 0) {
      this.aiWords = DICT.split(' ');
    }
    return this.aiWords;
  }

  /** 下一步该变成的词（'' = 走不到/已经到了） */
  private aiNextWord(): string {
    if (this.word === this.to) {
      return '';
    }
    const all: string[] = this.aiDict();
    const s0: number = all.indexOf(this.word);
    const g0: number = all.indexOf(this.to);
    if (s0 < 0 || g0 < 0 || s0 === g0) {
      return '';
    }
    const seen: boolean[] = new Array<boolean>(all.length).fill(false);
    const par: number[] = new Array<number>(all.length).fill(-1);
    const q: number[] = [s0];
    seen[s0] = true;
    let head: number = 0;
    while (head < q.length && !seen[g0]) {
      const w: string = all[q[head]];
      for (let i = 0; i < all.length; i++) {
        if (seen[i]) {
          continue;
        }
        if (all[i].length !== LEN) {
          continue;
        }
        let diff: number = 0;
        for (let p = 0; p < LEN; p++) {
          if (all[i].charAt(p) !== w.charAt(p)) {
            diff = diff + 1;
          }
        }
        if (diff === 1) {
          seen[i] = true;
          par[i] = q[head];
          q.push(i);
        }
      }
      head = head + 1;
    }
    if (!seen[g0]) {
      return '';
    }
    let at: number = g0;
    let guard: number = 0;
    while (guard < all.length && par[at] >= 0 && par[at] !== s0) {
      at = par[at];
      guard = guard + 1;
    }
    if (par[at] !== s0) {
      return '';
    }
    return all[at];
  }

  /** 把 word 改成 nx 需要「第几位、换成什么字母」 */
  private aiDiffPos(w: string, nx: string): number {
    for (let i = 0; i < LEN; i++) {
      if (w.charAt(i) !== nx.charAt(i)) {
        return i;
      }
    }
    return -1;
  }

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
    const nx: string = this.aiNextWord();
    if (nx.length !== LEN) {
      return false;
    }
    const pos: number = this.aiDiffPos(this.word, nx);
    if (pos < 0) {
      return false;
    }
    this.tapPos(pos);
    this.tapLetter(nx.charAt(pos));
    return !this.over;
  }

  /** 提示：报「第几位换成哪个字母 ⇒ 变成哪个单词」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const nx: string = this.aiNextWord();
    if (nx.length !== LEN) {
      return Hint.none('none');
    }
    const pos: number = this.aiDiffPos(this.word, nx);
    if (pos < 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('第 {0} 位换成 {1} ⇒ {2}', pos + 1, nx.charAt(pos), nx),
      TG2('Set letter {0} to {1} → {2}', pos + 1, nx.charAt(pos), nx), t0);
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

  private tapPos(i: number): void {
    if (this.over) { return; }
    this.pick = i; this.msg = TG2('已选第 {0} 位 ⇒ 挑个新字母', (i + 1));
  }
  private tapLetter(c: string): void {
    if (this.over) { return; }
    const at: number = this.pick;
    if (at < 0) { this.msg = TG('先在单词里点一个位置'); return; }
    const cur: string = this.word;
    if (c === cur.charAt(at)) { this.msg = TG('这个字母没换哦'); return; }
    const next: string = cur.substring(0, at) + c + cur.substring(at + 1);
    this.steps = this.steps + 1;
    if (!isWord(next)) {
      this.msg = TG2('❌ {0} 不在词库里', next);
    } else {
      this.word = next; this.trail = this.trail.concat([next]); this.pick = -1;
      if (next === this.to) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 到 {0} 了，用了 {1} 步", this.to,Digits(String(this.steps), this.langCode));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.msg = TG2("✅ {0}，还剩 {1} 步", next, this.left());
    }
    if (!this.over && this.steps >= this.limit) {
      this.over = true; this.msg = TG2('❌ 步数用尽，没能走到 {0}', this.to); this.finish(false);
    }
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true;
    const r: GameResult = { gameId: 'word_ladder', solved: solved,
      score: solved ? (this.limit - this.steps + 1) * 100 : this.steps * 10,
      durationMs: Date.now() - this.startAt, levelReached: this.steps };
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
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.steps + ' / ' + this.limit)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.to)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => { Text(this.word.length > (i) ? this.word.charAt((i)) : '').fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.pick === (i) ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(60)).backgroundColor(this.pick === (i) ? Palette.primary : this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tapPos((i)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPos((i)); }); }) }, (i: number) => 's' + i)
      }.width('100%')
      Text(this.trail.join(' → ')).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%').maxLines(2)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5, 6], (c: number) => {
              if (r * 7 + c < LETTERS.length) {
                Text((LETTERS.charAt(r * 7 + c))).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(36)).backgroundColor(this.theme.surface).borderRadius(Radius.xs).shadow(Shadow.card).onClick(() => { Haptics.tick(); this.tapLetter((LETTERS.charAt(r * 7 + c))); })
                .focusable(Tv.on())
                .focusBox(Tv.box())
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapLetter((LETTERS.charAt(r * 7 + c))); }); })
              }
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG2('提示：起点 {0} → 目标 {1}，词库里都是常见 {2} 字母单词', this.from, this.to, LEN)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
