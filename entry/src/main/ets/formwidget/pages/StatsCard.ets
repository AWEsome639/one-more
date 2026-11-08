/**
 * 服务卡片 UI —— 桌面上的一块「一局」
 *
 * 数据来自 LocalStorage（FormExtensionAbility 通过 formBindingData 注入）：
 *   level / title / streak / today / solved / pct
 */

import { FontSize, Palette, Overlay, Radius, Space } from '../../core/Design';
import { UiModeMgr } from '../../core/UiMode';

interface CardData {
  level: string;
  title: string;
  streak: string;
  today: string;
  solved: string;
  pct: string;
  footer: string;
  done: string;
}

const storage = new LocalStorage();

@Entry(storage)
@Component
struct StatsCard {
  @LocalStorageProp('level') level: string = '1';
  @LocalStorageProp('title') title: string = '新手上路';
  @LocalStorageProp('streak') streak: string = '0';
  @LocalStorageProp('today') today: string = '今天还没玩';
  @LocalStorageProp('solved') solved: string = '0';
  @LocalStorageProp('pct') pct: string = '0';
  // ★ 2026-10-19 自查 A2：底部文案改为 Ability 注入（已本地化）
  @LocalStorageProp('footer') footer: string = '累计 0 局 · 点我开一局';
  // ★ '1' = 今日已打卡。原来靠 today.indexOf('已') 判断 ⇒ 一旦本地化就永远判成"没玩"
  @LocalStorageProp('done') done: string = '0';
  // ★★★ 2026-11-08（UI 一致性审计 ③ 续）：**界面模式**由 Ability 注入（normal/elder/simple）。
  //   卡片跑在 Form 自己的渲染进程，**没人调 `UiModeMgr.apply()`** ⇒ 就算用了 `FontSize.*`
  //   也永远是 NORMAL 档的值。有了这个字段，卡片才能真正跟随「大字模式」。
  //   ⚠️ 老版本卡片（桌面已添加的实例）拿不到这个键 ⇒ 默认 'normal'，不会崩。
  @LocalStorageProp('uiMode') @Watch('onUiModeChange') uiMode: string = 'normal';
  /**
   * ★★★ 2026-11-08（StatsCard 巡检 ③）：**卡片尺寸规格**（'2*2' / '2*4' / '2*3' / '3*3'）
   * 由 `StatsCardAbility.onAddForm` 从 `want.parameters[DIMENSION_KEY]` 读出后注入。
   * ⚠️ 卡片跑在 Form 渲染进程，**拿不到 Bp**（Bp 只由 App 主进程 WindowStage 初始化，
   *   在这里永远是默认 360×780）⇒ `Bp.tinyWatch()` 在卡片里**恒 false**，
   *   "是不是手表卡"只能看这个字段。
   */
  @LocalStorageProp('dim') dim: string = '2*2';

  /**
   * 是不是手表卡：`2*3` / `3*3` 是官方**仅手表支持**的两档（桌面/平板不支持）
   * ⇒ 用"尺寸"反推设备，比猜 `Bp` 可靠。
   */
  private isWatchCard(): boolean {
    return this.dim === '2*3' || this.dim === '3*3';
  }

  /** 首帧之前就把字号/间距/圆角改成正确的档位（否则会先按 NORMAL 画一帧再跳） */
  aboutToAppear(): void {
    this.applyUiMode();
  }

  /** Ability 推来新模式（onUpdateForm）时跟着换 */
  onUiModeChange(): void {
    this.applyUiMode();
  }

  private applyUiMode(): void {
    try {
      // 只在三档之内才应用 —— 防止脏数据改坏 FontSize 阶梯
      const m: string = (this.uiMode === 'elder' || this.uiMode === 'simple') ? this.uiMode : 'normal';
      UiModeMgr.apply(m);
    } catch (e) {
      // 卡片环境特殊（Form 渲染进程）—— 应用失败就保持默认档，绝不因此不渲染
    }
  }

  private played(): boolean {
    // ★ 2026-10-19 修：原来是 today.indexOf('已') ≥ 0 —— 只对中文成立；
    //   本地化后（"Checked in today"）永不命中 ⇒ 打卡状态永远是"没玩"
    return this.done === '1';
  }

  build() {
    // ★★★ 2026-11-08（UI 一致性审计 · ③）：**本卡已接入 `core/Design`**
    //   原来 23 处裸数字（8 字号 / 3 圆角 / 11 颜色 / padding(12)）全是硬码 ⇒ 与全 App 的
    //   视觉阶梯脱钩，且永远不会跟随"大字模式"。现在字号/颜色/圆角一律走 `FontSize.*` /
    //   `Palette.*` / `Overlay.*` / `Radius.*`（**值完全等价，零视觉变化**）。
    //
    //   ✅ 间距也已收口（2026-11-08 第五批）：`.padding(12)` → `Space.snug`（等值，零视觉变化）
    //
    //   ⚠️ 仍有 4 处**故意保留裸数字**——因为阶梯里没有精确对应档，硬套会改视觉：
    //     · `.fontSize(11)` ×2（🔥 连胜数）—— 阶梯是 10(micro)/12(xxs)，11 无档
    //     · `.fontSize(9)`（底部文案）—— 阶梯是 8(badge)/10(micro)，9 无档
    //     · `borderRadius(3)` ×2（进度条圆角）—— 阶梯最小是 8(xs)
    //     · `#1E1B4B`（卡片深底）—— 色板里没有这个深靛蓝
    //   ⇒ 要收干净需**给阶梯补档**（`FontSize.nano=9`、`Radius.hair=3`…），那要同步改
    //     `core/UiMode.ets` 的 Spec/elder/simple 三张表，属于另一批活，本批不动。
    //
    //   ✅ 跟随「大字模式」：**已接好**（2026-11-08 同日第二批）
    //     · `StatsCardAbility` 从 preferences 读 'uiMode' → 随 `formBindingData` 注入
    //     · 本组件 `aboutToAppear` 里 `UiModeMgr.apply(uiMode)` ⇒ 首帧之前就把
    //       FontSize/Space/Radius 换成该档的值
    //     · `EntryAbility` 负责落盘（onBackground/onDestroy）与冷启动恢复（onCreate）
    //     ⚠️ 前提是「界面模式」真的被写进盘 —— 原来它**从来没落过盘**（`UiModeMgr.save()`
    //       只写内存），所以这一轮同时补了落盘，否则卡片永远拿到 'normal'。
    Column({ space: this.isWatchCard() ? 6 : 8 }) {
      // 顶行：名字 + 连胜 —— ★ 手表卡（2*3/3*3）上**整行删掉**：
      //   ① 品牌名在"就是本 App 的卡"上没有信息量；② 🔥 连胜在手表上意义低（同 `Common.ets:654` 的先例）
      //   省下的 ~18vp 正好给等级和进度条。
      if (!this.isWatchCard()) {
        Row() {
        Text('One More')
          .fontSize(FontSize.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.dInk)
        Blank()
        if (Number(this.streak) > 0) {
          Row({ space: 2 }) {
            Text('🔥').accessibilityLevel('no').fontSize(11)
            Text(this.streak).fontSize(11).fontColor(Palette.warning).fontWeight(FontWeight.Bold)
          }
          }
        }
        .width('100%')
      }

      // 主行：等级 —— ★ 手表上环 40→28、等级字 16→13（宽度是大问题：28 只占 2*3 的 ~28%）
      Row({ space: 8 }) {
        Stack() {
          Circle({
            width: this.isWatchCard() ? 28 : 40,
            height: this.isWatchCard() ? 28 : 40
          }).fill(Palette.primary)
          Column() {
            Text('LV').fontSize(FontSize.badge).fontColor(Overlay.onColorSoft)
            Text(this.level)
              .fontSize(this.isWatchCard() ? FontSize.xs : FontSize.md)
              .fontWeight(FontWeight.Bold).fontColor(Overlay.onColor)
          }
        }
        .width(this.isWatchCard() ? 28 : 40)
        .height(this.isWatchCard() ? 28 : 40)

        Column({ space: 2 }) {
          Text(this.title)
            // ★ 手表上 13→12（阶梯最小档），且**保持 maxLines(1)+省略号** —— 宁缺勿换行：
            //   标题一换行就会把进度条挤出 2*3 的高度预算（见巡检报告 §3.3）。
            .fontSize(this.isWatchCard() ? FontSize.xxs : FontSize.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.dInk)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.played() ? '✅ ' + this.today : '⭕ ' + this.today)
            .fontSize(FontSize.micro)
            .fontColor(this.played() ? Palette.success : Palette.dInkSoft)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5).backgroundColor(Overlay.chip).borderRadius(3)
        Row().width(this.pct + '%').height(5).backgroundColor(Palette.primary).borderRadius(3)
      }
      .width('100%').height(5)

      // ★ 2026-10-19 自查 A2：底部文案由 FormExtensionAbility 本地化后注入
      // ★ 2026-11-08（③）：**手表卡不画** —— "累计 N 局 · 点我开一局" 的后半句对手表无意义
      //   （现在卡片真的能点了，但手表上点开是首页、不是"开一局"），省 ~13vp。
      if (!this.isWatchCard()) {
        Text(this.footer)
          .fontSize(9)
          .fontColor(Palette.dInkSoft)
      }
    }
    .width('100%')
    .height('100%')
    // ★ 手表卡：行距 8→6、内边距 12→8（2*3 的可用高只有 ~190vp，省一档是一档）
    .padding(this.isWatchCard() ? Space.tiny : Space.snug)
    // ★★★ 2026-11-08（③）：**手表卡用 SpaceBetween** —— 2*3 是竖长卡，内容只占上半屏，
    //   底部会留一大片空黑。SpaceBetween 把进度条压到底边 ⇒ 既有"进度感"又不空。
    //   桌面卡保持默认（Start）：桌面 2*2/2*4 本来就填满，不需要拉伸。
    .justifyContent(this.isWatchCard() ? FlexAlign.SpaceBetween : FlexAlign.Start)
    .backgroundColor('#1E1B4B')
    .borderRadius(Radius.md)
    // ★★★ 2026-11-08（StatsCard 巡检 ①）**点卡片真的能开 App 了**
    //
    //   问题：底部文案写着「点我开一局」，但卡片里 `onClick` / `FormLink` / `postCardAction`
    //   一个都没有 ⇒ **点卡片什么都不发生**（文案比实现走得远，与 `super_10`、`marathon` 同源）。
    //
    //   ⚠️ 修法**不是** `formConfigAbility`：官方文档写的是
    //      「formConfigAbility：表示桌面**点击编辑后**，需要拉起的 ability 路径」
    //      —— 那是卡片**编辑**入口，不是普通点击。
    //   ✅ 动态卡片的正路是 `postCardAction(router)`（官方《卡片跳转到应用页面（router事件）》）：
    //      `postCardAction` 是 `component/common.d.ts` 里的**全局函数**，卡片内可直接调，不用 import；
    //      `router` 动作**只允许在点击事件里触发**（正好符合这里）。
    //
    //   ℹ️ 当前**只能打开 App 首页**：带 `params` 才能指定页面，而要在指定页落地还得让
    //      `EntryAbility.onCreate/onNewWant` 读 `want.parameters.params` 再决定 `loadContent` 哪个页
    //      —— 本工程没做那层路由。首页也算"能用"（Lead 已确认），真要直达再来一批。
    .onClick(() => {
      try {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility'
        });
      } catch (e) {
        // 卡片环境异常时绝不让点击把卡片搞崩（点了没反应 = 回到改造前的行为）
      }
    })
  }
}
