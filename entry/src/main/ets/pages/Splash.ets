/**
 * 开屏页 —— 一局的第一眼
 *
 * 动效序列（总长约 1.2s，可被点击跳过）★ 2026-10-17 从 1.9s 压缩到 1.2s（奥森要求"全部改成完美"）：
 *   0ms    深靛蓝底淡入
 *   0–600  四块彩砖依次弹入（scale 0.4→1，带回弹，每块错峰 110ms）
 *   500    砖块整体轻微上浮
 *   650    「一局」标题淡入上移
 *   880    「ONE MORE」英文副标题淡入
 *   1050   标语淡入
 *   1500   整屏淡出 → 进主页
 *
 * 拾海 2026-10-10
 */

import { router } from '@kit.ArkUI';
import { FontSize, Space, Motion } from '../core/Design';
import { L } from '../core/I18n';

const BRICK = ['#0EA5E9', '#EC4899', '#10B981', '#F59E0B'];

@Entry
@Component
struct Splash {
  /** ★ 2026-10-13（P4）：标语要跟语言（12 语言 + 繁体转换） */
  @StorageProp('lang') langCode: string = 'zh';
  @State private shown: number = 0;      // 已出现的砖块数
  @State private titleIn: boolean = false;
  @State private subIn: boolean = false;
  @State private sloganIn: boolean = false;
  @State private lift: number = 0;       // 整体上浮像素
  @State private fading: boolean = false;
  private jumped: boolean = false;

  /** 取当前语言的文案（读一次 langCode 建立 ArkUI 依赖） */
  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    return L(zh, en);
  }

  aboutToAppear(): void {
    // 四块砖依次弹入
    for (let i = 0; i < 4; i++) {
      setTimeout(() => {
        this.shown = i + 1;
      }, i * 66);
    }
    setTimeout(() => {
      this.lift = -14;
    }, 300);
    setTimeout(() => {
      this.titleIn = true;
    }, 390);
    setTimeout(() => {
      this.subIn = true;
    }, 528);
    setTimeout(() => {
      this.sloganIn = true;
    }, 630);
    setTimeout(() => {
      this.go();
    }, 900);
  }

  private go(): void {
    if (this.jumped) {
      return;
    }
    this.jumped = true;
    animateTo({ duration: 300, curve: Motion.enter() }, () => {
      this.fading = true;
    });
    setTimeout(() => {
      router.replaceUrl({ url: 'pages/Index' });
    }, 300);
  }

  build() {
    Column() {
      Column({ space: Space.lg }) {
        // ── 四块彩砖 ──
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            this.brick(0)
            this.brick(1)
          }
          Row({ space: 10 }) {
            this.brick(2)
            this.brick(3)
          }
        }
        .translate({ y: this.lift })
        .animation({ duration: 360, curve: Motion.spring() })

        // ── 标题 ──
        Column({ space: 6 }) {
          Text('One More')
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .opacity(this.titleIn ? 1 : 0)
            .translate({ y: this.titleIn ? 0 : 18 })
            .animation({ duration: 500, curve: Motion.spring() })

          Text(this.t('355 款小游戏', '355 GAMES'))
            .fontSize(FontSize.xs)
            .fontColor('#99FFFFFF')
            .letterSpacing(4)
            .opacity(this.subIn ? 1 : 0)
            .translate({ y: this.subIn ? 0 : 12 })
            .animation({ duration: 500, curve: Motion.spring() })
        }
      }

      // ── 标语（贴底）──
      Text(this.t('碎片时间，来一局', 'A quick round, any time'))
        .fontSize(FontSize.sm)
        .fontColor('#66FFFFFF')
        .opacity(this.sloganIn ? 1 : 0)
        .animation({ duration: 600, curve: Motion.spring() })
        .margin({ bottom: 64 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#312E81')
    .opacity(this.fading ? 0 : 1)
    .animation({ duration: 380, curve: Motion.enter() })
    .onClick(() => {
      this.go();   // 点一下跳过
    })
  }

  @Builder
  brick(i: number) {
    // 右下那块（i=3）翘起，与 App 图标呼应
    Stack() {
      Column()
        .width('100%')
        .height('56%')
        .backgroundColor('#26FFFFFF')
        .borderRadius({ topLeft: 20, topRight: 20, bottomLeft: 8, bottomRight: 8 })
        .margin({ top: 4 })
    }
    .width(62)
    .height(62)
    .backgroundColor(BRICK[i])
    .borderRadius(18)
    .rotate({ angle: i === 3 ? -9 : 0 })
    .shadow({ radius: 18, color: '#40000000', offsetX: 0, offsetY: 8 })
    .scale({ x: this.shown > i ? 1 : 0.4, y: this.shown > i ? 1 : 0.4 })
    .opacity(this.shown > i ? 1 : 0)
    .animation({ duration: 420, curve: Motion.snap() })
  }
}
