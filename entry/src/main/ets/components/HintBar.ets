/**
 * 通用的「提示 + AI 代打」按钮条（2026-10-24）
 *
 * 来历：这个按钮行我手工插了十几次，前后踩了 8 次布局坑：
 *   ① 插在 Column 直接子元素位置 + layoutWeight ⇒ 压成 0 高，不渲染
 *   ② 插在别的 Button 行与它的属性之间 ⇒ 拆散属性
 *   ③ 和已有按钮同一行，但已有按钮保留 .width('100%') ⇒ 把新按钮挤出屏幕
 *
 * 所以做成一个组件：**父容器是 Row，每个按钮都 layoutWeight(1)**，
 * 从根上不可能再犯这三条。用完只需在 build() 里写一行：
 *
 *   HintBar({ onHintTap: () => { this.askHint(); },
 *             onAutoTap: () => { this.askAuto(); },
 *             autoOn: this.autoId >= 0 })
 */
import { TG } from '../core/GameI18n';
import { FontSize, Space, Radius, Palette } from '../core/Design';

@Component
export struct HintBar {
  /** 点「提示」时回调（游戏自己实现 askHint） */
  onHintTap: () => void = () => {};
  /** 点「代打/停代打」时回调（游戏自己实现 askAuto） */
  onAutoTap: () => void = () => {};
  /** 代打是否正在跑（决定按钮文字） */
  autoOn: boolean = false;
  /** 高度，默认 38（比主按钮矮一点，不和它们抢视觉） */
  barHeight: number = 38;
  /** 是否显示「提示」按钮（默认显示；游戏自带提示时传 false） */
  showHint: boolean = true;

  build() {
    Row({ space: Space.sm }) {
      if (this.showHint) {
        Button(TG('提示'))
          .layoutWeight(1)
          .height(this.barHeight)
          .fontSize(FontSize.sm)
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .onClick(() => {
            this.onHintTap();
          })
      }
      Button(this.autoOn ? TG('停代打') : TG('AI 代打'))
        .layoutWeight(1)
        .height(this.barHeight)
        .fontSize(FontSize.sm)
        .backgroundColor(this.autoOn ? Palette.rose : Palette.cyan)
        .borderRadius(Radius.md)
        .onClick(() => {
          this.onAutoTap();
        })
    }
    .width('100%')
  }
}
