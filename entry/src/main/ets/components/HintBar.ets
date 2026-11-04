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
import { Tv } from '../core/Tv';
import { LanRace } from '../core/LanRace';
import { TG } from '../core/GameI18n';
import { FontSize, Space, Radius, Palette } from '../core/Design';

@Component
export struct HintBar {

  /** ★ 2026-11-04（第 1179 轮）：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  /** 点「提示」时回调（游戏自己实现 askHint） */
  onHintTap: () => void = () => {};
  /** 点「代打/停代打」时回调（游戏自己实现 askAuto） */
  onAutoTap: () => void = () => {};
  /** 代打是否正在跑（决定按钮文字）
   *  ★ 必须 @Prop：普通成员不随父组件刷新（和 demoOn 同一个坑） */
  @Prop autoOn: boolean = false;
  /** 高度，默认 38（比主按钮矮一点，不和它们抢视觉） */
  barHeight: number = 38;
  /** 是否显示「提示」按钮（默认显示；游戏自带提示时传 false） */
  showHint: boolean = true;
  /** 演示动画是否在跑（项目 C）：跑的时候显示「演示中…」而不是两个按钮
   *  ★ 必须 @Prop：普通成员不会随父组件状态刷新（实测 demoOn 不生效） */
  @Prop demoOn: boolean = false;
  /** 演示中的引导文案（"看这块关羽，往右推一格"）
   *  ★ 2026-10-31：单独一行 Text 在某些布局里不渲染（真机 dump 抓不到），
   *    但这一行**确定会渲染** ⇒ 直接挂在这里，不再另开一行。 */
  @Prop demoMsg: string = '';
  /** 演示进行中 ⇒ 提示/代打按钮不可用（置灰、不可点）。
   *  ★ 与 `demoOn` 的区别：`demoOn` 会把两个按钮**整个换掉**成一行文字；
   *    而演示文案已由 DemoBar 承载，这里只需要"按钮还能看见但点不了"。
   *    用 `demoOn` 会造成"演示中"重复显示两遍。 */
  @Prop disabled: boolean = false;

  build() {
    Row({ space: Space.sm }) {
      // ★ 演示动画进行中（项目 C）：不显示按钮，只显示「演示中…」
      //   ⇒ 玩家一眼知道"现在不是我在玩"，一碰屏幕就会停
      if (this.demoOn) {
        Text(this.demoMsg.length > 0
          ? (TG('演示中') + ' ｜ ' + this.demoMsg)
          : TG('演示中…（碰一下就停）'))
          .layoutWeight(1)
          .height(this.barHeight)
          .fontSize(FontSize.sm)
          .fontColor(Palette.amber)
          .textAlign(TextAlign.Center)
          // ★ 无障碍：这行本身就是给用户的完整说明，直接可读
          .accessibilityLevel('yes')
          .accessibilityGroup(true)
      } else if (this.showHint) {
        Button(TG('提示'))
          .layoutWeight(1)
          .height(this.barHeight)
          .fontSize(FontSize.sm)
          .backgroundColor(this.disabled ? Palette.lineSoft : Palette.cyan)
          .fontColor(this.disabled ? Palette.inkFaint : Color.White)
          .enabled(!this.disabled)
          .borderRadius(Radius.md)
          // ★★★ 2026-11-03（第 1118 轮）**无障碍：按钮要有"点了会做什么"，不只是"提示"两个字**
          //   原来按钮的唯一标签就是 `TG('提示')` —— 读屏念「提示」，
          //   但用户不知道是"给我一个提示"还是"显示提示历史"。
          //   ⇒ 补 accessibilityText 说清动作；禁用时说明**为什么**不能点。
          .accessibilityText(this.disabled
            ? TG('提示（演示进行中，暂不可用）')
            : TG('提示：看这一步该怎么走'))
          .accessibilityLevel('yes')
          // ★ 2026-10-29（项目 F 阶段 2）：智慧屏焦点
          //   Tv.on() 在非电视上恒为 false ⇒ 手机/平板/PC 零影响
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L87'; })
          .onBlur(() => { if (this.tvFocus === 'L87') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L87'))
          .onKeyEvent((e: KeyEvent) => {
            Tv.handleKey(e, () => { if (!this.disabled) { this.onHintTap(); } });
          })
          .onClick(() => {
            if (!this.disabled) { this.onHintTap(); }
          })
      }
      if (!this.demoOn) {
      // ★★ 2026-10-31 奥森要求：**AI 代打在联机对战中不能启用**
      //   理由很硬：代打会让对手面对一个"机器"，对局不公平，也毁掉联机的意义。
      //   ⇒ 联机进行中（LanRace.isRacing()）把按钮置灰、文案改「联机禁用」、点击无效。
      Button(LanRace.isRacing()
        ? TG('联机禁用')
        : (this.autoOn ? TG('停代打') : TG('AI 代打')))
        .layoutWeight(1)
        .height(this.barHeight)
        .fontSize(FontSize.sm)
        .backgroundColor((LanRace.isRacing() || this.disabled)
          ? Palette.lineSoft
          : (this.autoOn ? Palette.rose : Palette.cyan))
        .fontColor((LanRace.isRacing() || this.disabled) ? Palette.inkFaint : Color.White)
        .enabled(!LanRace.isRacing() && !this.disabled)
        .borderRadius(Radius.md)
        // ★ 无障碍：代打按钮同理 —— 说明动作 + 说明禁用原因
        //   联机中禁用是**产品决策**（代打会让对手面对机器，不公平），
        //   所以理由必须能被读屏说出来，否则残障用户只会觉得"按钮坏了"。
        .accessibilityText(LanRace.isRacing()
          ? TG('AI 代打（联机对战中不可用）')
          : (this.disabled
            ? TG('AI 代打（演示进行中，暂不可用）')
            : (this.autoOn ? TG('停止 AI 代打') : TG('AI 代打：让电脑替你走这一步'))))
        .accessibilityLevel('yes')
        // ★ 2026-10-29（项目 F 阶段 2）：智慧屏焦点
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L122'; })
        .onBlur(() => { if (this.tvFocus === 'L122') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L122'))
        .onKeyEvent((e: KeyEvent) => {
          Tv.handleKey(e, () => {
            // 联机中不响应（.enabled 已挡一层，这里是双保险）
            if (!LanRace.isRacing() && !this.disabled) { this.onAutoTap(); }
          });
        })
        .onClick(() => {
          if (!LanRace.isRacing() && !this.disabled) { this.onAutoTap(); }
        })
      }
    }
    .width('100%')
  }
}
