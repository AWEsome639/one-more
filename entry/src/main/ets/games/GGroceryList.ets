/** 购物清单 —— 先记清单，再逐题判断「这件东西在单子上吗」；3 轮答对 ≥75% ⇒ 通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const POOL: string[] = ['🍎', '🥛', '🍞', '🥚', '🧀', '🍌', '🥕', '🍇', '🐟', '🍯', '🍜', '🧴'];
const ROUNDS: number = 3;
const MEM_MS: number = 2400;

interface Probe { icon: string; inside: boolean }

function bag(a: string[]): string[] {
  const out: string[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

@Component
export struct GGroceryList {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private list: string[] = [];
  @State private probes: Probe[] = [];
  @State private pIdx: number = 0;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private asked: number = 0;
  @State private phase: number = 0;   // 0 记忆 / 1 答题 / 2 结束
  @State private pick: number = -1;   // -1 未答 / 0 不在 / 1 在
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private memTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.memTo >= 0) { clearTimeout(this.memTo); this.memTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.round = 1; this.right = 0; this.asked = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const n: number = 2 + this.round;
    const all: string[] = bag(POOL);
    const onList: string[] = all.slice(0, n);
    const offs: string[] = all.slice(n, n + 2);
    const ps: Probe[] = [];
    for (let i = 0; i < onList.length; i++) { ps.push({ icon: onList[i], inside: true }); }
    for (let i = 0; i < offs.length; i++) { ps.push({ icon: offs[i], inside: false }); }
    for (let i = ps.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: Probe = ps[i];
      ps[i] = ps[j];
      ps[j] = t;
    }
    this.list = onList; this.probes = ps; this.pIdx = 0; this.pick = -1; this.phase = 0;
    this.msg = TG('记住这 ') + String(n) + ' 样东西';
    this.memTo = setTimeout(() => {
      this.memTo = -1; this.phase = 1; this.pick = -1; this.msg = TG(TG(TG('刚才的东西，在清单里吗？')));
    }, MEM_MS);
  }

  private answer(yes: boolean): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    const cur: Probe = this.probes[this.pIdx];
    const hit: boolean = yes === cur.inside;
    this.pick = yes ? 1 : 0;
    this.asked = this.asked + 1;
    if (hit) { this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.msg = TG(TG(TG('✅ 答对了'))); }
    else { this.msg = cur.inside ? '❌ 它在清单里' : '❌ 它不在清单里'; }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.pIdx + 1 < this.probes.length) {
        this.pIdx = this.pIdx + 1; this.pick = -1; this.msg = TG(TG(TG('刚才的东西，在清单里吗？')));
        return;
      }
      if (this.round >= this.diffTotal) {
        this.over = true; this.phase = 2; this.won = this.right * 4 >= this.asked * 3;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) + String(this.right) + '/' + String(this.asked);
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.newRound();
    }, 760);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'grocery_list', solved: solved, score: this.right * 100, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2("轮次 {0}", (String(this.round) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + (String(this.right) + '/' + String(this.asked))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2('清单 {0}', (String(this.list.length) + ' 件'))).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Stack() {
        if (this.phase === 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(this.list, (it: string) => {
              Text(it).fontSize(FontSize.xxl).padding(Space.xs).margin(Space.xs)
                .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm)
            }, (it: string) => 'g' + it)
          }.width('100%')
        } else if (this.phase === 1 && this.pIdx < this.probes.length) {
          Column({ space: Space.sm }) {
            Text(this.probes[this.pIdx].icon).fontSize(FontSize.hero)
            Text(TG('在清单里吗？')).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
          }
        } else {
          Text(this.won ? '🎉' : '💤').fontSize(FontSize.hero)
        }
      }
      .width('100%').layoutWeight(1)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) { this.ansBtn(TG(TG('不在')), false); this.ansBtn(TG(TG('在清单里')), true) }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.cyan)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：每轮清单更长，答对 75% 即通关'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  ansBtn(label: string, yes: boolean) {
    Text(label).fontSize(FontSize.md).fontColor('#FFFFFF').textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(52)).backgroundColor(yes ? Palette.cyan : Palette.inkSoft).borderRadius(Radius.md)
      .opacity(this.phase === 1 && this.pick < 0 ? 1 : 0.5).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer(yes); })
  }
}
