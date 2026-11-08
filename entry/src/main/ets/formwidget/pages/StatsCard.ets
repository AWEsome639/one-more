/**
 * 服务卡片 UI —— 桌面上的一块「一局」
 *
 * 数据来自 LocalStorage（FormExtensionAbility 通过 formBindingData 注入）：
 *   level / title / streak / today / solved / pct
 */

import { FontSize, Palette, Overlay, Radius } from '../../core/Design';

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
    //   ⚠️ 仍有 5 处**故意保留裸数字**——因为阶梯里没有精确对应档，硬套会改视觉：
    //     · `.fontSize(11)` ×2（🔥 连胜数）—— 阶梯是 10(micro)/12(xxs)，11 无档
    //     · `.fontSize(9)`（底部文案）—— 阶梯是 8(badge)/10(micro)，9 无档
    //     · `borderRadius(3)` ×2（进度条圆角）—— 阶梯最小是 8(xs)
    //     · `.padding(12)` —— 阶梯是 10(sm)/16(md)
    //     · `#1E1B4B`（卡片深底）—— 色板里没有这个深靛蓝
    //   ⇒ 要收干净需**给阶梯补档**（`FontSize.nano=9`、`Space.base=12`…），那要同步改
    //     `core/UiMode.ets` 的 Spec/elder/simple 三张表，属于另一批活，本批不动。
    //
    //   ⚠️ 另一件事**还没做**：卡片运行在 Form 自己的渲染环境里，**没人调 `UiModeMgr.apply()`**
    //     ⇒ 就算用了 `FontSize.*`，在大字模式下仍是 NORMAL 档的值。要真跟随，得在
    //     `StatsCardAbility.onAddForm` 里把当前 uiMode 写进 `formBindingData`，卡片
    //     `aboutToAppear` 里再 `UiModeMgr.apply(...)`。**没做**（要改 Ability 的数据管道）。
    Column({ space: 8 }) {
      // 顶行：名字 + 连胜
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

      // 主行：等级
      Row({ space: 8 }) {
        Stack() {
          Circle({ width: 40, height: 40 }).fill(Palette.primary)
          Column() {
            Text('LV').fontSize(FontSize.badge).fontColor(Overlay.onColorSoft)
            Text(this.level).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(Overlay.onColor)
          }
        }
        .width(40).height(40)

        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(FontSize.xs)
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
      Text(this.footer)
        .fontSize(9)
        .fontColor(Palette.dInkSoft)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#1E1B4B')
    .borderRadius(Radius.md)
  }
}
