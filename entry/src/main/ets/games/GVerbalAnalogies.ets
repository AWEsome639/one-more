/**
 * 词语类比 —— A 比 B 等于 C 比 ?，从四个候选里挑出关系对得上的那个
 * 胜负：8 题里答对 ≥ 6 通关；答错 3 次失败 ｜ 进度：第几题 / 答对数 / 生命 / 得分
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

const ROUNDS: number = 8; const PASS: number = 6; const LIVES: number = 3; const FEED_MS: number = 900;

interface Analog { stem: string; opts: string[]; ans: number }
interface Opt { text: string; ok: boolean }

const BANK: Analog[] = [
  { stem: 'HOT : COLD ＝ UP : ?', opts: ['DOWN 向下', 'TOP 顶部', 'HIGH 高的', 'OVER 在上'], ans: 0 },
  { stem: 'BIRD : NEST ＝ BEE : ?', opts: ['HONEY 蜂蜜', 'HIVE 蜂巢', 'FLOWER 花', 'WING 翅膀'], ans: 1 },
  { stem: 'DOCTOR : HOSPITAL ＝ TEACHER : ?', opts: ['BOOK 书本', 'PUPIL 学生', 'SCHOOL 学校', 'CHALK 粉笔'], ans: 2 },
  { stem: 'HAND : GLOVE ＝ FOOT : ?', opts: ['SOCK 袜子', 'TOE 脚趾', 'LEG 腿', 'SANDAL 凉鞋'], ans: 0 },
  { stem: 'PUPPY : DOG ＝ KITTEN : ?', opts: ['CAT 猫', 'MOUSE 老鼠', 'CUB 幼兽', 'LAMB 羔羊'], ans: 0 },
  { stem: 'PEN : WRITE ＝ KNIFE : ?', opts: ['SHARP 锋利的', 'METAL 金属', 'CUT 切', 'SPOON 勺子'], ans: 2 },
  { stem: 'EYE : SEE ＝ EAR : ?', opts: ['SOUND 声音', 'HEAR 听见', 'LOUD 响的', 'MUSIC 音乐'], ans: 1 },
  { stem: 'SLOW : FAST ＝ QUIET : ?', opts: ['SOFT 软的', 'SILENT 寂静的', 'CALM 平静的', 'LOUD 响亮的'], ans: 3 },
  { stem: 'GALLERY : PAINTINGS ＝ LIBRARY : ?', opts: ['SHELVES 书架', 'BOOKS 书', 'READERS 读者', 'QUIET 安静'], ans: 1 },
  { stem: 'WINTER : SNOW ＝ SUMMER : ?', opts: ['ICE 冰', 'BEACH 沙滩', 'HEAT 炎热', 'COAT 外套'], ans: 2 }
];

/** 从 0..total-1 中随机取 k 个互不相同的下标 */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

@Component
export struct GVerbalAnalogies {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private order: number[] = []; @State private qi: number = 0;
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  @State private opts: Opt[] = []; @State private right: number = 0;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private life: number = 0; @State private score: number = 0;
  @State private picked: number = -1; @State private locked: boolean = false;
  @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private cur(): Analog { return BANK[this.order[this.qi]]; }

  private reset(): void {
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
    this.order = pickIndexes(BANK.length, ROUNDS);
    this.qi = 0; this.right = 0; this.life = this.total; this.score = 0; this.picked = -1;
    this.locked = false; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.load();
  }

  private load(): void {
    const item: Analog = this.cur();
    const raw: Opt[] = [];
    for (let i = 0; i < item.opts.length; i++) { raw.push({ text: item.opts[i], ok: i === item.ans }); }
    this.opts = pickIndexes(raw.length, raw.length).map((k: number) => raw[k]);
    this.picked = -1; this.locked = false;
    this.msg = TG(TG('先看 A 与 B 的关系，再补上第四个词'));
  }

  private findOk(): number {
    for (let i = 0; i < this.opts.length; i++) { if (this.opts[i].ok) { return i; } }
    return 0;
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
          TG2('答案是第 {0} 个', String(i + 1)),
          TG2('The answer is option {0}', String(i + 1)), t0);
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
  // 选项对象自带对错：opts[i].ok ｜ 守卫取自它自己的第一道 if
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.locked) {
      return true;
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        this.tap(i);
        return true;
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
    if (this.over || this.locked) { return; }
    this.locked = true; this.picked = i;
    if (this.opts[i].ok) {
      this.right = this.right + 1; this.score = this.score + 130; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG(TG('✅ 关系对上了'));
    } else {
      this.life = this.life - 1;
      this.msg = TG('❌ 应该是 ') + this.opts[this.findOk()].text + TG('，还剩 ') + this.life + TG(' 条命');
    }
    this.feed = setTimeout(() => {
      this.feed = -1;
      if (this.life <= 0) { this.end(); } else { this.next(); }
    }, FEED_MS);
  }

  private next(): void {
    if (this.qi + 1 >= ROUNDS) { this.end(); return; }
    this.qi = this.qi + 1; this.load();
  }

  private end(): void {
    if (this.done) { return; }
    this.done = true; this.over = true;
    this.won = this.life > 0 && this.right >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", this.right, ROUNDS);
    const r: GameResult = { gameId: 'verbal_analogies', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Text(TG2("题 {0}/{1}", Math.min(this.qi + 1, ROUNDS), ROUNDS)).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).layoutWeight(1).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(TG('词语类比')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.cur().stem).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(Palette.cyan).maxLines(3)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.opts, (o: Opt, i: number) => { this.option(o, i) },
          (o: Opt, i: number) => 'p' + i + o.text)
      }.width('100%')
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(TG('提示：先想「前者是后者的什么」，再去套第三个词'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  option(o: Opt, i: number) {
    Text(o.text).fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      .fontColor(this.locked && (this.picked === i || o.ok) ? '#FFFFFF' : this.theme.ink)
      .width('100%').height(Cell.of(48)).borderRadius(Radius.md).shadow(Shadow.card)
      .backgroundColor(this.locked && o.ok
        ? Palette.emerald : (this.locked && this.picked === i ? Palette.rose : this.theme.surface))
      .scale({ x: this.picked === i ? Motion.pressScale : 1, y: this.picked === i ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
