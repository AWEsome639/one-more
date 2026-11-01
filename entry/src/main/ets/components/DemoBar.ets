/**
 * 演示条 —— 演示动画进行中的那一行
 *
 * ★★★ 为什么要有这个组件（2026-10-31 真机定位）
 *   原来演示态靠 `HintBar` 的 `@Prop demoOn` 表达，而这个 @Prop 在本项目
 *   **只进不出**：演示结束后仍停在 true，界面永远显示「演示中…」，
 *   演示文案也永远传不进去（连改 4 版都对不上，最后靠 `[新n]` 探针才抓到）。
 *   ⇒ 演示态**不再交给 HintBar**，改由游戏页用自己页面里的 @State 直接渲染。
 *   ⇒ 抽成这个组件，355 款接入只需两行。
 *
 * 用法（游戏页 build() 里）：
 *   DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
 *   // 或与 HintBar 二选一：
 *   if (this.demoId >= 0) {
 *     DemoBar({ on: true, msg: this.demoMsg })
 *   } else {
 *     HintBar({ demoOn: false, ... })
 *   }
 *
 * 文案规范（看得懂才叫演示）：
 *   · 引导拍：`看这块「卒」：往右推一格` / `看这两颗：交换它们能连成三颗`
 *   · 结果拍：`推过去了。已走 2 步`    / `消掉了！这一下能拿 +30 分（演示不计分）`
 *   · 收尾：  `碰一下屏幕，换你来`
 */
import { TG } from '../core/GameI18n';
import { FontSize, Palette } from '../core/Design';
import { Bp } from '../core/Bp';

@Component
export struct DemoBar {
  /** 是否在演（由游戏页自己传，不依赖 HintBar） */
  @Prop on: boolean = false;
  /** 这一拍的文案（可为空，为空时显示通用提示） */
  @Prop msg: string = '';

  /** 极小屏：高或宽 < 420vp（运动手表 195 / 手表 233 都算） */
  private tiny(): boolean {
    return Bp.height < 420 || Bp.width < 420;
  }

  build() {
    Row() {
      if (this.on) {
        // ★★ 2026-11-01 真机（运动手表 195×195）：完整文案在 195vp 宽上要占 3 行、
        //   而这一拍只有 24vp 高 ⇒ 第二行起被切（截图拍到「答案是第 4」被截断）。
        //   ⇒ 极小屏**只保留「演示中」三个字** —— 它存在的意义是"现在不是你操作"，
        //     而不是"把提示读完"（提示在顶栏下方，棋盘上有描边指路）。
        Text(this.tiny() ? TG('演示中') : (TG('演示中') + ' ｜ '
          + (this.msg.length > 0 ? this.msg : TG('碰一下就停'))
          // ★ 不计分提示：335 款共用这一条，省得每款各写一遍。
          //   已经写明「不计分」的（3 款手工版）就不重复。
          + (this.msg.indexOf(TG('不计分')) >= 0 ? '' : TG('（演示不计分）'))))
          .fontSize(FontSize.sm)
          .fontColor(Palette.amber)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    // ★ 未演示时高度归 0 —— 这样 355 款都可以**恒显示**这个组件，
    //   调用方不必写 if/else 包一层（少一层缩进就少一类改错）。
    // ★★ 2026-11-01 真机（手表 195×195）：38vp 在 195 高的屏上占 19%，
    //   加上顶栏后内容区只剩 86vp。⇒ 极小屏压到 24vp。
    .height(this.on ? (Bp.height < 420 ? 24 : 38) : 0)
  }
}
