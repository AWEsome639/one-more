/**
 * 音标猜词 —— 看音标猜单词
 *
 * 规则：给一个国际音标，从 4 个单词里选出对应的那一个；共 8 题。
 * 结算：答对 ≥ 6 题 ⇒ 通关；否则失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

interface Word {
  w: string;
  ipa: string;
  cn: string;
}

const BANK: Word[] = [
  { w: 'apple', ipa: '/ˈæpl/', cn: TG('苹果') },
  { w: 'banana', ipa: '/bəˈnɑːnə/', cn: TG('香蕉') },
  { w: 'chocolate', ipa: '/ˈtʃɒklət/', cn: '巧克力' },
  { w: 'university', ipa: '/ˌjuːnɪˈvɜːsəti/', cn: '大学' },
  { w: 'hospital', ipa: '/ˈhɒspɪtl/', cn: '医院' },
  { w: 'computer', ipa: '/kəmˈpjuːtə/', cn: '电脑' },
  { w: 'elephant', ipa: '/ˈelɪfənt/', cn: '大象' },
  { w: 'weather', ipa: '/ˈweðə/', cn: '天气' },
  { w: 'January', ipa: '/ˈdʒænjuəri/', cn: '一月' },
  { w: 'garden', ipa: '/ˈɡɑːdn/', cn: TG('花园') },
  { w: 'silent', ipa: '/ˈsaɪlənt/', cn: '安静的' },
  { w: 'southern', ipa: '/ˈsʌðən/', cn: '南方的' }
];

const PICK: number = 4;          // 每题选项数
const TOTAL: number = 8;         // 每局题数
const PASS: number = 6;          // 通关线
const NEXT_MS: number = 800;     // 答完到下一题的间隔
const LETTERS: string[] = ['A', 'B', 'C', 'D'];

@Component
export struct GPhoneticGuess {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private opts: string[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private hint: boolean = false;

  private order: number[] = [];
  private startAt: number = 0;
  private finished: boolean = false;
  private to: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
    this.reset();
  }

  aboutToDisappear(): void {
    this.clearNext();
  }

  private clearNext(): void {
    if (this.to >= 0) {
      clearTimeout(this.to);
      this.to = -1;
    }
  }

  private reset(): void {
    this.clearNext();
    const a: number[] = [];
    for (let i = 0; i < BANK.length; i++) {
      a.push(i);
    }
    for (let i = a.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = a[i];
      a[i] = a[j];
      a[j] = t;
    }
    while (a.length > this.diffTotal) {
      a.pop();
    }
    this.order = a;
    this.round = 1;
    this.right = 0;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.ask();
  }

  private ask(): void {
    const q: number = this.order[this.round - 1];
    const pool: number[] = [];
    for (let i = 0; i < BANK.length; i++) {
      if (i !== q) {
        pool.push(i);
      }
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    const idxs: number[] = [q];
    for (let i = 0; i < pool.length && idxs.length < PICK; i++) {
      idxs.push(pool[i]);
    }
    for (let i = idxs.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = idxs[i];
      idxs[i] = idxs[j];
      idxs[j] = t;
    }
    const out: string[] = [];
    for (let i = 0; i < idxs.length; i++) {
      out.push(BANK[idxs[i]].w);
    }
    this.opts = out;
    this.ans = idxs.indexOf(q);
    this.picked = -1;
    this.hint = false;
  }

  private cur(): Word {
    return BANK[this.order[this.round - 1]];
  }

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right++;
      this.score += 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    } else {
      this.score = Math.max(0, this.score - 20); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    }
    this.clearNext();
    this.to = setTimeout(() => {
      this.to = -1;
      this.next();
    }, NEXT_MS);
  }

  private next(): void {
    if (this.round >= this.diffTotal) {
      this.over = true;
      this.won = this.right >= PASS;
      this.finish(this.won);
      return;
    }
    this.round++;
    this.ask();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'phonetic_guess',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private pickColor(i: number): string {
    if (this.picked < 0) {
      return this.theme.surface;
    }
    if (i === this.ans) {
      return Palette.emerald;
    }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }

  private pickInk(i: number): string {
    if (this.picked < 0) {
      return this.theme.ink;
    }
    if (i === this.ans) {
      return '#FFFFFF';
    }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  private status(): string {
    if (this.over) {
      return this.won
        ? TG('🎉 答对 ') + this.right + '/' + this.diffTotal + TG('，通关！')
        : TG('😵 只答对 ') + this.right + '/' + this.diffTotal + '，再练一局';
    }
    if (this.picked >= 0) {
      return this.picked === this.ans ? '✅ 答对了！' : TG('❌ 错了，正确答案已标绿');
    }
    return TG('这个音标是哪个词？');
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题目'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() })
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.full)
        Row()
          .width((this.round - 1) * 100 / this.diffTotal + '%')
          .height('100%')
          .backgroundColor(Palette.teal)
          .borderRadius(Radius.full)
          .animation({ duration: Motion.base, curve: Motion.snap() })
      }
      .width('100%')
      .height(8)

      // 音标卡
      Column({ space: Space.xs }) {
        Text(this.cur().ipa)
          .fontSize(FontSize.xxl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.teal)
        Text(this.hint ? '释义：' + this.cur().cn : '点「提示」看中文释义')
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      // 四个选项
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i])
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.inkFaint)
            Text(this.opts[i])
              .fontSize(FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.pickInk(i))
              .layoutWeight(1)
          }
          .width('100%')
          .height(Cell.of(52))
          .padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.pickColor(i))
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
            this.pick(i);
          })
        }, (i: number) => 'o' + i)
      }
      .width('100%')

      Text(this.status())
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('提示'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .onClick(() => {
            this.hint = true;
          })
        Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.teal)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }


}
