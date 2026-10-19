/** 故事回忆 —— 读一段小故事，凭记忆回答细节题；2 篇 6 题答对 ≥5 通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 2;
const PASS: number = 5;

interface Q { text: string; opts: string[]; right: number }
interface Story { body: string; qs: Q[] }

const STORIES: Story[] = [
  {
    body: '清晨六点，林小满骑着蓝色自行车去码头。她在第三个摊位买了一斤橘子，又用旧书换了一本 1987 年的地图册。回家路上忽然下雨，她躲进一家面馆点了一碗牛肉面，却把伞忘在了门口的伞桶里。',
    qs: [
      { text: '她几点出门？', opts: ['五点', '六点', '七点'], right: 1 },
      { text: '她在第几个摊位买橘子？', opts: ['第二', '第三', '第五'], right: 1 },
      { text: '她把什么忘在面馆？', opts: ['地图册', '伞', '自行车'], right: 1 }
    ]
  },
  {
    body: '周四下午，阿海在阁楼找到一个铁皮盒子，里面有三枚硬币和一张褪色的照片。照片背面写着「1996 年，青岛」。他抱着盒子跑到楼下修表铺，老师傅说三枚硬币是 1965 年的，值两百元；阿海没舍得卖，只把照片夹进了课本。',
    qs: [
      { text: '盒子是在哪儿找到的？', opts: ['阁楼', '车库', '抽屉'], right: 0 },
      { text: '照片背面写的是哪一年？', opts: ['1965 年', '1986 年', '1996 年'], right: 2 },
      { text: '老师傅说硬币值多少钱？', opts: ['一百元', '两百元', '三百元'], right: 1 }
    ]
  },
  {
    body: '夜里九点，苏禾带着一只橘猫去海边看流星雨。她等了四十分钟，只看到两颗流星，却在潮水线上捡到一枚青色的玻璃瓶。瓶里塞着一张纸条，上面是七个字：明天清晨再见吧。',
    qs: [
      { text: '她带了什么动物？', opts: ['橘猫', '柴犬', '鹦鹉'], right: 0 },
      { text: '她等了多久？', opts: ['二十分钟', '四十分钟', '一个小时'], right: 1 },
      { text: '纸条上写着几个字？', opts: ['五个', '六个', '七个'], right: 2 }
    ]
  }
];

@Component
export struct GNarrativeRecall {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PASS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(PASS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private story: Story = { body: '', qs: [] };
  @State private qIdx: number = 0;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private asked: number = 0;
  @State private used: number[] = [];
  @State private pick: number = -1;
  @State private phase: number = 0;   // 0 阅读 / 1 答题 / 2 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PASS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.round = 1; this.right = 0; this.asked = 0; this.used = [];
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    let k: number = Math.floor(Math.random() * STORIES.length);
    let guard: number = 0;
    while (this.used.indexOf(k) >= 0 && guard < 20) {
      k = Math.floor(Math.random() * STORIES.length);
      guard = guard + 1;
    }
    const picked: number[] = this.used.slice();
    picked.push(k);
    this.used = picked;
    this.story = STORIES[k];
    this.qIdx = 0; this.pick = -1; this.phase = 0;
    this.msg = TG('第 ') + String(this.round) + ' 篇：读一遍，记住细节';
  }

  private answer(i: number): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    const q: Q = this.story.qs[this.qIdx];
    this.pick = i;
    this.asked = this.asked + 1;
    if (i === q.right) { this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.msg = TG(TG(TG('✅ 答对了'))); }
    else { this.msg = TG2('❌ 应该是：{0}', q.opts[q.right]); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.qIdx + 1 < this.story.qs.length) {
        this.qIdx = this.qIdx + 1; this.pick = -1; this.msg = TG('第 ') + String(this.qIdx + 1) + TG(' 题');
        return;
      }
      if (this.round >= ROUNDS) {
        this.phase = 2; this.over = true; this.won = this.right >= this.diffTotal;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) + String(this.right) + '/' + String(this.asked);
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.newRound();
    }, 900);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'narrative_recall', solved: solved, score: this.right * 100, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2('篇数 {0}', (String(this.round) + '/' + String(ROUNDS)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2("题号 {0}", (this.phase === 1 ? String(this.qIdx + 1) + '/' + String(this.story.qs.length) : '阅读'))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG('答对 ') + (String(this.right) + '/' + String(this.asked))).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Column() {
        if (this.phase === 0) {
          Scroll() {
            Text(this.story.body).fontSize(FontSize.md).lineHeight(28)
              .fontColor(this.theme.inkSoft).width('100%')
          }.width('100%').layoutWeight(1)
        } else if (this.phase === 1 && this.qIdx < this.story.qs.length) {
          Column() {
            Text(this.story.qs[this.qIdx].text).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
          }.width('100%').layoutWeight(1)
        } else {
          Text(this.won ? '🎉' : '💤').fontSize(FontSize.hero).width('100%').textAlign(TextAlign.Center).layoutWeight(1)
        }
      }
      .width('100%').layoutWeight(1).padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      if (this.phase === 0) {
        Button(TG('我记住了'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width('100%').height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.phase = 1; this.msg = TG(TG(TG('第 1 题'))); })
      } else if (this.phase === 1 && this.qIdx < this.story.qs.length) {
        ForEach([0, 1, 2], (k: number) => { this.optBtn(k) }, (k: number) => 'o' + k)
      }

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：不用背原文，抓住时间、地点、数字与人名'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  optBtn(k: number) {
    Text(this.story.qs[this.qIdx].opts[k]).fontSize(FontSize.md).textAlign(TextAlign.Center)
      .fontColor(this.pick === k ? '#FFFFFF' : this.theme.ink)
      .width('100%').height(Cell.of(48)).borderRadius(Radius.md).shadow(Shadow.card)
      .backgroundColor(this.pick === k ? Palette.primaryDeep : this.theme.surfaceAlt)
      .opacity(this.pick >= 0 && this.pick !== k ? 0.45 : 1)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer(k); })
  }
}
