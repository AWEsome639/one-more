#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 games/ 目录自动生成 GameHost 的导入与分发链（拾海 2026-10-10）

为什么需要它：351 款游戏 ⇒ 351 行 import + 351 条 if/else 分支，
手写必错且每次加游戏都要改。⇒ 扫描 games/*.ets 自动生成。

约定（GAME_BRIEF.md）：
  文件   entry/src/main/ets/games/<FILE>.ets
  结构   export struct <STRUCT>
  id     在文件里出现 gameId: '<ID>'  或  this.gameId = '<ID>'

用法: python3 tools/gen_dispatcher.py
"""
import os
import re
import glob
import json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES_DIR = os.path.join(ROOT, 'entry/src/main/ets/games')
OUT = os.path.join(ROOT, 'entry/src/main/ets/pages/GameHost.ets')
REGISTRY = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')

HEAD = """/**
 * 游戏宿主页 —— 顶栏 + 游戏区 + 结算弹窗
 *
 * ⚠️ 本文件的「导入区」与「分发链」由 tools/gen_dispatcher.py 自动生成，
 *    加游戏只需在 games/ 下新建文件（含 `gameId: 'xxx'`），然后跑：
 *        python3 tools/gen_dispatcher.py && bash build.sh
 *
 * 契约（GAME_BRIEF.md）：
 *   @Prop theme: Theme
 *   @Prop @Watch('onRestart') restartToken: number
 *   onFinish: (r: GameResult) => void
 */

import { router } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Layout, Accent } from '../core/Design';
import { findGame, GameMeta, GameResult, difficultyFactor, Difficulty, displayTagline } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { L, toTrad } from '../core/I18n';
// ── 游戏实现（自动生成，勿手改）──
"""

TAIL_BEFORE_DISPATCH = """
@Entry
@Component
struct GameHost {

  /** 难度标签（读 diffTick 建立 ArkUI 依赖） */
  private diffLabel(): string {
    const tick: number = this.diffTick;
    const d: number = ProgressStore.diffOf(this.gameId);
    // ★ 非中文系一律用英文难度名（以前只判 'en'，日语/韩语下会残留中文）
    const cn: string = ProgressStore.DIFF_NAME[d][0];
    const en: string = ProgressStore.DIFF_NAME[d][1];
    if (this.langCode === 'zh') {
      return cn;
    }
    if (this.langCode === 'zh-Hant') {
      return toTrad(cn);   // ★ 繁體走 toTrad
    }
    return en;
  }

  /** 难度对应的颜色：简单绿 / 普通蓝 / 困难橙 */
  private diffColor(): string {
    const d: number = ProgressStore.diffOf(this.gameId);
    if (d === 0) {
      return Palette.emerald;
    }
    if (d === 2) {
      return Palette.orange;
    }
    return this.accentColor();
  }

  /** 取当前语言的文案（必须读 langCode 建立 ArkUI 依赖，否则不重渲染） */
  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    // ★ 2026-10-13（P4）：这里原来是中英二元式 `observed === 'en' ? en : zh` ——
    //   日/韩/西/法/德/葡/俄/意/阿 十种语言全退中文，繁体也被吞。必须走 L()（12 语言 + 简繁转换）。
    return L(zh, en);
  }
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 设置页改色，本页立刻跟 */
  @StorageProp('accent') accentId: string = Palette.primary;
  /** 当前主题色（id 可能是 'system'，一律走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  @State meta: GameMeta | undefined = undefined;
  @State gameId: string = '';
  @State nonce: number = 0;
  // ★ 难度标签必须读一个 @State —— 只调 ProgressStore.diffOf() 的话
  //   ArkUI 看不到依赖，切了难度标签不会重渲染（同一个坑踩了四次）
  @State diffTick: number = 0;
  @State dark: boolean = false;
  @State showResult: boolean = false;
  @State lastGain: number = 0;
  /** ★ 本局新解锁的成就（结算面板要展示并庆祝） */
  @State newAch: string[] = [];
  /** ★ 滚动计数用（0 → 最终值）：直接内联 Text 读它，才能逐帧刷新 */
  @State gainShown: number = 0;
  @State scoreShown: number = 0;
  private countTimer: number = -1;
  @State lastScore: number = 0;
  @State lastMs: number = 0;
  @State lastSolved: boolean = false;
  @State fav: boolean = false;
  @State pop: boolean = false;
  @State levelUpTo: number = 0;

  aboutToAppear(): void {
    const p: Record<string, Object> = router.getParams() as Record<string, Object>;
    if (p && p.id !== undefined) {
      this.gameId = p.id as string;
    }
    // ★ 必须在 this.gameId 赋值**之后**登记 —— 写在前面时它还是空串（真踩过）
    GameDiff.enter(this.gameId);
    this.meta = findGame(this.gameId);
    this.fav = ProgressStore.isFavorite(this.gameId);
    // 游戏时屏幕常亮（对标项目的 wakelock 体验）
    try {
      window.getLastWindow(getContext(this)).then((w: window.Window) => {
        w.setWindowKeepScreenOn(true);
      });
    } catch (e) {
      // 拿不到窗口就算了，不影响游戏
    }
  }

  aboutToDisappear(): void {
    try {
      window.getLastWindow(getContext(this)).then((w: window.Window) => {
        w.setWindowKeepScreenOn(false);
      });
    } catch (e) {
    }
  }

  private theme(): Theme {
    return this.dark ? Theme.dark() : Theme.light();
  }

  /** 所有游戏结算都走这里 */
  /**
   * ★ 手感：数字**滚动计数**（0 → target，约 610ms）
   *
   * 为什么用 setInterval 而不是 animateTo：
   *   `animateTo` 只能插值**属性**，插不了"显示用的数字" ⇒ 只能自己逐帧推。
   *   缓动取 easeOutCubic（先快后慢）—— 比线性更有"冲上去再稳住"的手感。
   * ⚠️ 重开一局要先清掉上一个计时器，否则数字会抖（已用 countTimer 兜住）
   */
  private countUp(target: number, apply: (v: number) => void): void {
    if (this.countTimer >= 0) {
      clearInterval(this.countTimer);
      this.countTimer = -1;
    }
    if (target <= 0) {
      apply(0);
      return;
    }
    const steps: number = 18;
    let i: number = 0;
    this.countTimer = setInterval(() => {
      i = i + 1;
      const p: number = i / steps;
      const e: number = 1 - Math.pow(1 - p, 3);
      apply(Math.round(target * e));
      if (i >= steps) {
        clearInterval(this.countTimer);
        this.countTimer = -1;
        apply(target);
      }
    }, 34);
  }

  private handleFinish(r: GameResult): void {
    const m: GameMeta | undefined = this.meta;
    const baseXp: number = m ? m.baseXp : 10;
    const factor: number = m ? difficultyFactor(m.difficulty) : 1;
    const gain: number = ProgressStore.finishGame(r.gameId, r.solved, baseXp, factor * ProgressStore.DIFF_XP[ProgressStore.diffOf(r.gameId)], r.score, r.durationMs);
    this.lastGain = gain;
    this.lastScore = r.score;
    this.lastMs = r.durationMs;
    this.lastSolved = r.solved;
    this.levelUpTo = AppStorage.get<number>('levelUpTo') ?? 0;
    this.pop = false;
    // ★ 手感（2026-10-12 手感专项）：**结束的瞬间必须有触感**，而且成功/失败要能分辨
    //   · 通关 + 升级  ⇒ celebrate()  三连轻震（大时刻）
    //   · 通关         ⇒ success()    一记略重的
    //   · 没通关       ⇒ fail()       两下短震（和 success 明显不同）
    // ★ 手感：得分与经验**滚上去**（0 → 最终值，约 700ms）
    this.countUp(r.score, (v2: number) => { this.scoreShown = v2; });
    setTimeout(() => {
      this.countUp(gain, (v2: number) => { this.gainShown = v2; });
    }, 140);
    // ★ 手感：解锁成就 = 大时刻 ⇒ 三连庆祝（优先于普通通关）
    this.newAch = ProgressStore.lastNewAch;
    if (r.solved) {
      if (this.levelUpTo > 0 || this.newAch.length > 0) {
        Haptics.celebrate();
      } else {
        Haptics.success();
      }
    } else {
      Haptics.fail();
    }
    animateTo({ duration: Motion.sheet, curve: Motion.spring() }, () => {
      this.showResult = true;
    });
    setTimeout(() => {
      this.pop = true;
    }, 60);
  }

/** 未实现的游戏：给个友好的占位，而不是白屏 */
@Builder
    placeholder() {
    Column({ space: Space.md }) {
      Text(this.meta ? this.meta.icon : '🎮').fontSize(56)
      Text(this.t('这一款还在路上', 'This one is still on the way')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(this.meta ? this.meta.name : '')
        .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
      Text(this.t('玩法：', 'How to play: ') + (this.meta ? displayTagline(this.meta) : ''))
        .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        .textAlign(TextAlign.Center)
      Text(this.t('换一款玩玩？', 'Try another?')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        .margin({ top: Space.lg })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(Space.xxl)
}

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // ── 顶栏 ──
        Row() {
          Text('‹')
            .fontSize(30)
            .fontColor(this.theme().ink)
            .width(44).height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .onClick(() => {
              router.back();
            })

          Column({ space: 2 }) {
            Text(this.meta ? this.meta.name : '')
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().ink)
            Text(this.meta ? this.meta.tagline : '')
              .fontSize(FontSize.xs)
              .fontColor(this.theme().inkFaint)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: Space.md })

          Text(this.fav ? '⭐' : '☆')
            .fontSize(FontSize.lg)
            .fontColor(this.fav ? Palette.amber : this.theme().inkFaint)
            .width(44).height(44).textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .animation({ duration: Motion.fast, curve: Motion.spring() })
            .onClick(() => {
              const now: boolean = ProgressStore.toggleFavorite(this.gameId);
              animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
                this.fav = now;
              });
            })

          Text('?')
            .fontSize(FontSize.lg)
            .fontColor(this.theme().inkSoft)
            .width(44).height(44).textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .margin({ right: Space.sm })
            .onClick(() => {
              router.pushUrl({ url: 'pages/GuidePage', params: { id: this.gameId } });
            })

          // 难度选择：点一下循环切 简单 → 普通 → 困难
          // ★ 手感：**视觉胶囊保持小巧，但点击热区撑到 44vp**
          //   实测原热区只有 44.3 × 24.0 vp（高度差一半）—— 手指点不准。
          //   做法：外面套一层 44vp 高的 Row 做居中，胶囊本身尺寸/圆角/配色一律不动。
          // ★ 手感：**点击热区 ≥44vp**
          //   实测原热区 44.3 × 24.0 vp（高度差一半，手指点不准）。
          //   ⚠️ 踩过的坑：外面套一层 Row 定高**不生效** ——
          //   `dumpLayout` 报的仍是内部 Text 的尺寸（ArkUI 的命中区跟着最内层文本走）。
          //   ⇒ 必须**直接给 Text 定高**；左右内边距保留，上下内边距去掉（高度已由 height 决定）。
          Text(this.diffLabel())
            .fontSize(FontSize.xxs).fontWeight(FontWeight.Bold)
            .fontColor(this.diffColor())
            .height(Layout.touchMin)
            .textAlign(TextAlign.Center)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.full)
            .onClick(() => {
              Haptics.tap();
              const next: number = (ProgressStore.diffOf(this.gameId) + 1) % ProgressStore.DIFF_COUNT;
              ProgressStore.setDiff(this.gameId, next);
              this.diffTick = this.diffTick + 1;
              this.nonce = this.nonce + 1;
            })

          Text('↻')
            .fontSize(FontSize.xl)
            .fontColor(this.theme().ink)
            .width(44).height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .onClick(() => {
              this.nonce = this.nonce + 1;
            })
        }
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, top: Space.xl, bottom: Space.md })

        // ── 游戏区（直接内联，不走 @Builder）──
        Column() {
"""

TAIL_AFTER_DISPATCH = """        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, bottom: Space.lg })
      }
      .width('100%')
      .height('100%')

      // ── 结算弹窗 ──
      if (this.showResult) {
        Column({ space: Space.md }) {
          Text(this.lastSolved ? '🎉' : '💪')
            .fontSize(44)
            .scale({ x: this.pop ? 1 : 0.4, y: this.pop ? 1 : 0.4 })
            .rotate({ angle: this.pop ? 0 : -18 })
            .animation({ duration: 480, curve: Motion.snap() })
          Text(this.lastSolved ? this.t('这一局拿下！', 'You cleared it!') : this.t('再来一局？', 'One more?'))
            .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          // ★ 手感：刚解锁的成就**当场亮出来** + 三连庆祝（大时刻）
          if (this.newAch.length > 0) {
            Column({ space: 4 }) {
              ForEach(this.newAch, (a: string) => {
                Text(this.t('🏆 解锁成就 ', '🏆 Unlocked ') + a)
                  .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
                  .fontColor(Palette.amber)
              }, (a: string) => a)
            }
            .width('100%')
            .padding({ left: Space.md, right: Space.md, top: 8, bottom: 8 })
            .backgroundColor('#1AF59E0B')
            .borderRadius(Radius.md)
            .scale({ x: this.pop ? 1 : 0.8, y: this.pop ? 1 : 0.8 })
            .opacity(this.pop ? 1 : 0)
            .animation({ duration: Motion.base, curve: Motion.snap(), delay: 120 })
          }
          if (this.levelUpTo > 0) {
            Row({ space: Space.sm }) {
              Text('🎊').fontSize(FontSize.lg)
              Text(this.t('升到 LV ', 'Reached LV ') + this.levelUpTo + ' · ' + ProgressStore.titleOf(this.levelUpTo))
                .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
                .fontColor(Palette.amber)
            }
            .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
            .backgroundColor('#1AF59E0B')
            .borderRadius(Radius.full)
            .scale({ x: this.pop ? 1 : 0.7, y: this.pop ? 1 : 0.7 })
            .opacity(this.pop ? 1 : 0)
            .animation({ duration: Motion.base, curve: Motion.snap(), delay: 220 })
          }

          // ★ 手感：得分与经验**滚动计数**（从 0 数到最终值）
          //   ⚠️ 必须内联 Text 读 @State —— this.stat(...) 是 @Builder，
          //   它的参数不建立 ArkUI 观察，计数过程中不会刷新（这个坑真踩过）
          Row({ space: Space.xl }) {
            Column({ space: 2 }) {
              Text(String(this.scoreShown)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
                .fontColor(this.theme().ink)
              Text(this.t('得分', 'Score')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            }.layoutWeight(1)
            .opacity(this.pop ? 1 : 0).translate({ y: this.pop ? 0 : 10 })
            .animation({ duration: Motion.base, curve: Motion.spring() })
            Column({ space: 2 }) {
              Text((this.lastMs / 1000).toFixed(1) + 's').fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
                .fontColor(this.theme().ink)
              Text(this.t('用时', 'Time')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            }.layoutWeight(1)
            .opacity(this.pop ? 1 : 0).translate({ y: this.pop ? 0 : 10 })
            .animation({ duration: Motion.base, curve: Motion.spring(), delay: 80 })
            Column({ space: 2 }) {
              Text('+' + String(this.gainShown)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
                .fontColor(Palette.emerald)
              Text(this.t('经验', 'XP')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            }.layoutWeight(1)
            .opacity(this.pop ? 1 : 0).translate({ y: this.pop ? 0 : 10 })
            .animation({ duration: Motion.base, curve: Motion.spring(), delay: 160 })
          }
          Button(this.t('再来一局', 'Play again'))
            .fontSize(FontSize.md)
            .fontColor(Color.White)
            .backgroundColor(this.accentColor())
            .borderRadius(Radius.md)
            .width('100%').height(46)
            .onClick(() => {
              animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
                this.showResult = false;
                this.nonce = this.nonce + 1;
              });
            })
          Button(this.t('返回列表', 'Back to list'))
            .fontSize(FontSize.md)
            .fontColor(this.theme().inkSoft)
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.md)
            .width('100%').height(46)
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .padding(Space.xxl)
        .backgroundColor(this.theme().surface)
        .borderRadius({ topLeft: Radius.xl, topRight: Radius.xl })
        .shadow(Shadow.card)
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.sheet })
          .combine(TransitionEffect.translate({ y: 300 })))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bg)
  }

  @Builder
  stat(label: string, value: string, delay: number) {
    Column({ space: 2 }) {
      Text(value).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(label).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
    }
    .opacity(this.pop ? 1 : 0)
    .translate({ y: this.pop ? 0 : 10 })
    .animation({ duration: Motion.base, curve: Motion.spring(), delay: delay })
  }
}
"""


def scan_games():
    """扫描 games/*.ets，返回 [(structName, fileBase, gameId)]"""
    found = []
    for path in sorted(glob.glob(os.path.join(GAMES_DIR, '*.ets'))):
        src = open(path, encoding='utf-8').read()
        m = re.search(r'export\s+struct\s+([A-Za-z0-9_]+)', src)
        if not m:
            continue
        struct = m.group(1)
        ids = re.findall(r"gameId:\s*'([^']+)'", src)
        if not ids:
            ids = re.findall(r"this\.gameId\s*=\s*'([^']+)'", src)
        gid = ids[0] if ids else ''
        base = os.path.basename(path)[:-4]
        found.append((struct, base, gid))
    return found


def registry_ids():
    """注册表里有哪些 id（用来报告还差多少）"""
    src = open(REGISTRY, encoding='utf-8').read()
    return set(re.findall(r"id:\s*'([^']+)'", src))


def main():
    games = scan_games()
    implemented = [g for g in games if g[2]]
    missing_id = [g for g in games if not g[2]]

    imports = []
    for struct, base, gid in implemented:
        imports.append(f"import {{ {struct} }} from '../games/{base}';")

    branches = []
    for i, (struct, base, gid) in enumerate(implemented):
        kw = 'if' if i == 0 else '} else if'
        # ★ 把游戏组件包在「按 diffTick 切换的两个相同分支」里 ——
        #   切难度时 diffTick 变 ⇒ ArkUI 销毁旧组件、重建新的 ⇒
        #   **字段初始化重跑，读到新难度**。
        #   为什么需要：`@Builder` 的参数不建立观察，游戏内用 Builder 显示的值
        #   在 partial update 时不会刷新（实测「代数天平」显示恒为 1/10）。
        #   这样一处改动，**354 款全部受益**，不用逐款改代码。
        call = (f"{struct}({{ theme: this.theme(), restartToken: this.nonce, "
                f"onFinish: (r) => this.handleFinish(r) }})")
        branches.append(
            f"          {kw} (this.gameId === '{gid}') {{\n"
            f"            if (this.diffTick % 2 === 0) {{\n"
            f"              {call}\n"
            f"            }} else {{\n"
            f"              {call}\n"
            f"            }}\n"
        )
    branches.append("          } else {\n            this.placeholder()\n          }\n")

    content = HEAD + '\n'.join(imports) + '\n' + TAIL_BEFORE_DISPATCH \
        + ''.join(branches) + TAIL_AFTER_DISPATCH

    open(OUT, 'w', encoding='utf-8').write(content)

    reg = registry_ids()
    done_ids = set(g[2] for g in implemented)
    print(f'✅ 生成 {OUT}')
    print(f'   已实现游戏: {len(implemented)} 款')
    print(f'   注册表总数: {len(reg)} 款')
    print(f'   还差: {len(reg - done_ids)} 款')
    if missing_id:
        print(f'   ⚠️ 有 struct 但没写 gameId 的文件 {len(missing_id)} 个: '
              + ', '.join(b for _, b, _ in missing_id[:8]))
    bad = done_ids - reg
    if bad:
        print(f'   ⚠️ gameId 不在注册表里（主页不会显示）: {sorted(bad)[:8]}')


if __name__ == '__main__':
    main()
