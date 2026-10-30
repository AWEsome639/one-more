/* DiagPage 2 —— 逐层加回 Splash 的属性，找吞掉图元的那个 */
@Entry
@Component
struct DiagPage {
  @State t: number = 1;

  build() {
    Column({ space: 6 }) {
      // A: Image + shadow
      Text('A: Image + shadow').fontSize(10).fontColor('#FFF')
      Image($r('app.media.splash_om'))
        .width(120).height(61).objectFit(ImageFit.Contain)
        .shadow({ radius: 30, color: '#55C99E52', offsetX: 0, offsetY: 0 })

      // B: Image inside Column with translate
      Text('B: + Column translate').fontSize(10).fontColor('#FFF')
      Column() {
        Image($r('app.media.splash_om')).width(120).height(61).objectFit(ImageFit.Contain)
      }.width('100%').translate({ y: -10 })

      // C: Image inside Column with scale
      Text('C: + Column scale').fontSize(10).fontColor('#FFF')
      Column() {
        Image($r('app.media.splash_om')).width(120).height(61).objectFit(ImageFit.Contain)
      }.width('100%').scale({ x: 1.02, y: 1.02 })

      // D: Image inside Column with blur
      Text('D: + Column blur').fontSize(10).fontColor('#FFF')
      Column() {
        Image($r('app.media.splash_om')).width(120).height(61).objectFit(ImageFit.Contain)
      }.width('100%').blur(0)

      // E: Image inside full-height centered Column (Splash 主体列的真实结构)
      Text('E: full-height centered Column').fontSize(10).fontColor('#FFF')
      Column() {
        Image($r('app.media.splash_om')).width(120).height(61).objectFit(ImageFit.Contain)
      }
      .width('100%').height(120)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 0 })
      .translate({ y: -14 })
      .scale({ x: 1, y: 1 })
      .opacity(1)

      // F: 同上但 opacity 来自 @State 绑定
      Text('F: + opacity from @State').fontSize(10).fontColor('#FFF')
      Column() {
        Image($r('app.media.splash_om')).width(120).height(61).objectFit(ImageFit.Contain)
      }
      .width('100%').height(120)
      .justifyContent(FlexAlign.Center)
      .opacity(1 - (1 - this.t) * 0.06)
    }
    .width('100%').height('100%')
    .backgroundColor('#0D1320')
    .padding(12)
    .justifyContent(FlexAlign.Start)
  }
}
