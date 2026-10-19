/**
 * 开屏页 —— One More 的第一眼
 *
 * ★ 2026-10-19 第四版（进度驱动 + 点击加速）
 *
 * 奥森的三次要求：
 *   ① 「可以是一个画笔慢慢画出 O 和 M」
 *   ② 「隐形的画笔在屏幕中上方画出大的 O 和 M，很多最高级的动画，参考 Apple」
 *   ③ 「手点击屏幕，动画就加快」「不要有'跳过'之类的按钮，太低端」
 *
 * 架构：单进度 p（0 → 1）驱动全部视觉，点击屏幕让 p 用 1/3.5 的时间跑完
 *   ⇒ 不是"跳到结尾"，是"整体提速"，每一帧都仍然连续
 *
 * 十二个进度点（p 的区间 → 视觉阶段）：
 *   0.00-0.05  深墨蓝底 + 径向光晕淡入
 *   0.05-0.26  O 描边（外圈 → 内圈）
 *   0.26-0.45  M 描边
 *   0.45-0.55  细线淡出 / 实心淡入
 *   0.50-0.58  外发光脉冲
 *   0.52-0.60  金点从 O 心弹出
 *   0.54-0.66  涟漪一
 *   0.58-0.70  涟漪二
 *   0.60-0.72  标题（字间距从 16 收到 1 + 上浮）
 *   0.66-0.78  副标题
 *   0.72-0.84  标语
 *   0.84-0.94  整体轻微放大（呼吸）
 *   0.94-1.00  淡出 → 主界面
 *
 * 路径：Futura Bold（与图标同字体），fontTools 提取
 *   viewPort 3675×1855，宽高比 1.981 = OM 本身比例 ⇒ 撑满容器
 *
 * 拾海 2026-10-19
 */

import { router } from '@kit.ArkUI';
import { FontSize, Space, Motion } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { L } from '../core/I18n';

// ── 与图标完全一致的三色 ──
const OM_INK = '#0D1320';
const OM_GOLD = '#C99E52';
const OM_CREAM = '#FAF8F3';

// ── Futura Bold 的 O 与 M ──
const O_PATH: string = 'M165.4 964.5Q165.4 638.5 404.4 404.5Q642.4 170.5 976.4 170.5Q1306.4 170.5 1542.4 406.5Q1779.4 642.5 1779.4 973.5Q1779.4 1306.5 1541.4 1538.5Q1302.4 1771.5 964.4 1771.5Q665.4 1771.5 427.4 1564.5Q165.4 1335.5 165.4 964.5ZM400.4 967.5Q400.4 1223.5 572.4 1388.5Q743.4 1553.5 967.4 1553.5Q1210.4 1553.5 1377.4 1385.5Q1544.4 1215.5 1544.4 971.5Q1544.4 724.5 1379.4 557.5Q1215.4 389.5 973.4 389.5Q732.4 389.5 566.4 557.5Q400.4 723.5 400.4 967.5Z';
const M_PATH: string = 'M1813.4 1743.5L2138.4 83.5L2668.4 1283.5L3217.4 83.5L3509.4 1743.5';

// ── 描边长度 ──
const O_LEN: number = 8697.4;
const M_LEN: number = 6008.5;

// ── 画布比例与金点位置 ──
const OM_RATIO: number = 3675 / 1855;
const VP_W: number = 3675;
const VP_H: number = 1855;
const DOT_XR: number = 0.2646;
const DOT_YR: number = 0.5235;

/** 把 p 的一段区间映射到 0~1 */
function seg(p: number, a: number, b: number): number {
  if (p <= a) {
    return 0;
  }
  if (p >= b) {
    return 1;
  }
  return (p - a) / (b - a);
}

/** 缓动：三次方 in-out */
function ease(t: number): number {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

@Entry
@Component
struct Splash {
  @StorageProp('lang') langCode: string = 'zh';

  /** 唯一进度：0 → 1 */
  @State private p: number = 0;
  /** 是否已加速（避免重复触发） */
  private boosted: boolean = false;
  private jumped: boolean = false;
  private finished: boolean = false;

  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    return L(zh, en);
  }

  aboutToAppear(): void {
    // 主时间线：3.4 秒跑完 p 0 → 1
    animateTo({ duration: 3400, curve: Curve.Linear }, () => {
      this.p = 1;
    });
    // 兜底：结束后进主页
    setTimeout(() => {
      this.finish();
    }, 3500);
  }

  private finish(): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    router.replaceUrl({ url: 'pages/Index' });
  }

  /** ★ 点屏幕 = 加速，不是跳过 */
  private boost(): void {
    if (this.boosted || this.p >= 0.999) {
      return;
    }
    this.boosted = true;
    // 剩余进度用 1/3.5 的时间跑完
    const remain: number = Math.max(0.12, (1 - this.p) / 3.5);
    animateTo({ duration: Math.round(3400 * remain), curve: Curve.Linear }, () => {
      this.p = 1;
    });
    setTimeout(() => {
      this.finish();
    }, Math.round(3400 * remain) + 120);
  }

  build() {
    Stack() {
      // ══ ① 背景：径向光晕（两层，不同相位，视差）══
      Column()
        .width('140%')
        .height('80%')
        .radialGradient({
          center: ['50%', '42%'],
          radius: '62%',
          colors: [['#22355C', 0.0], ['#16223A', 0.52], ['#0D1320', 1.0]]
        })
        .opacity(seg(this.p, 0.00, 0.12))
        .translate({ y: -60 })

      Column()
        .width('96%')
        .height('46%')
        .radialGradient({
          center: ['50%', '50%'],
          radius: '58%',
          colors: [['#2B2348', 0.0], ['#1A1830', 0.55], ['#0D1320', 1.0]]
        })
        .opacity(seg(this.p, 0.06, 0.22) * 0.72)
        .translate({ y: -30 })

      // ④ ★ 星点 24 颗（固定位置，随进度呼吸）
          Circle()
            .width(2.0)
            .height(2.0)
            .fill('#FFFFFF')
            .position({ x: '62.0%', y: '42.0%' })
            .markAnchor({ x: 1.0, y: 1.0 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 0.0))))
          Circle()
            .width(5.6)
            .height(5.6)
            .fill('#FFFFFF')
            .position({ x: '35.8%', y: '53.1%' })
            .markAnchor({ x: 2.8, y: 2.8 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 0.537981875))))
          Circle()
            .width(5.0)
            .height(5.0)
            .fill('#FFFFFF')
            .position({ x: '52.3%', y: '19.5%' })
            .markAnchor({ x: 2.5, y: 2.5 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 1.07596375))))
          Circle()
            .width(4.4)
            .height(4.4)
            .fill('#FFFFFF')
            .position({ x: '70.6%', y: '64.9%' })
            .markAnchor({ x: 2.2, y: 2.2 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 1.6139456250000002))))
          Circle()
            .width(3.8)
            .height(3.8)
            .fill('#FFFFFF')
            .position({ x: '9.4%', y: '35.9%' })
            .markAnchor({ x: 1.9, y: 1.9 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 2.1519275))))
          Circle()
            .width(3.2)
            .height(3.2)
            .fill('#FFFFFF')
            .position({ x: '90.9%', y: '19.9%' })
            .markAnchor({ x: 1.6, y: 1.6 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 2.689909375))))
          Circle()
            .width(2.6)
            .height(2.6)
            .fill('#FFFFFF')
            .position({ x: '35.5%', y: '87.8%' })
            .markAnchor({ x: 1.3, y: 1.3 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 3.2278912500000003))))
          Circle()
            .width(2.0)
            .height(2.0)
            .fill('#FFFFFF')
            .position({ x: '20.9%', y: '-5.6%' })
            .markAnchor({ x: 1.0, y: 1.0 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 3.765873125))))
          Circle()
            .width(5.6)
            .height(5.6)
            .fill('#FFFFFF')
            .position({ x: '116.1%', y: '62.5%' })
            .markAnchor({ x: 2.8, y: 2.8 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 4.303855))))
          Circle()
            .width(5.0)
            .height(5.0)
            .fill('#FFFFFF')
            .position({ x: '-21.8%', y: '67.2%' })
            .markAnchor({ x: 2.5, y: 2.5 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 4.841836875))))
          Circle()
            .width(4.4)
            .height(4.4)
            .fill('#FFFFFF')
            .position({ x: '86.0%', y: '-23.4%' })
            .markAnchor({ x: 2.2, y: 2.2 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 5.37981875))))
          Circle()
            .width(3.8)
            .height(3.8)
            .fill('#FFFFFF')
            .position({ x: '54.9%', y: '55.2%' })
            .markAnchor({ x: 1.9, y: 1.9 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 5.917800625000001))))
          Circle()
            .width(3.2)
            .height(3.2)
            .fill('#FFFFFF')
            .position({ x: '29.6%', y: '31.9%' })
            .markAnchor({ x: 1.6, y: 1.6 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 0.1727825))))
          Circle()
            .width(2.6)
            .height(2.6)
            .fill('#FFFFFF')
            .position({ x: '80.2%', y: '36.4%' })
            .markAnchor({ x: 1.3, y: 1.3 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 0.7107643750000001))))
          Circle()
            .width(2.0)
            .height(2.0)
            .fill('#FFFFFF')
            .position({ x: '28.0%', y: '68.6%' })
            .markAnchor({ x: 1.0, y: 1.0 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 1.2487462500000002))))
          Circle()
            .width(5.6)
            .height(5.6)
            .fill('#FFFFFF')
            .position({ x: '44.2%', y: '3.6%' })
            .markAnchor({ x: 2.8, y: 2.8 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 1.786728125))))
          Circle()
            .width(5.0)
            .height(5.0)
            .fill('#FFFFFF')
            .position({ x: '90.4%', y: '70.9%' })
            .markAnchor({ x: 2.5, y: 2.5 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 2.32471))))
          Circle()
            .width(4.4)
            .height(4.4)
            .fill('#FFFFFF')
            .position({ x: '-10.0%', y: '44.1%' })
            .markAnchor({ x: 2.2, y: 2.2 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 2.8626918750000003))))
          Circle()
            .width(3.8)
            .height(3.8)
            .fill('#FFFFFF')
            .position({ x: '97.8%', y: '1.6%' })
            .markAnchor({ x: 1.9, y: 1.9 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 3.40067375))))
          Circle()
            .width(3.2)
            .height(3.2)
            .fill('#FFFFFF')
            .position({ x: '46.5%', y: '105.4%' })
            .markAnchor({ x: 1.6, y: 1.6 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 3.938655625))))
          Circle()
            .width(2.6)
            .height(2.6)
            .fill('#FFFFFF')
            .position({ x: '-2.5%', y: '-11.5%' })
            .markAnchor({ x: 1.3, y: 1.3 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 4.476637500000001))))
          Circle()
            .width(2.0)
            .height(2.0)
            .fill('#FFFFFF')
            .position({ x: '63.2%', y: '43.5%' })
            .markAnchor({ x: 1.0, y: 1.0 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 5.0146193750000005))))
          Circle()
            .width(5.6)
            .height(5.6)
            .fill('#FFFFFF')
            .position({ x: '33.1%', y: '52.0%' })
            .markAnchor({ x: 2.8, y: 2.8 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 5.55260125))))
          Circle()
            .width(5.0)
            .height(5.0)
            .fill('#FFFFFF')
            .position({ x: '56.1%', y: '18.9%' })
            .markAnchor({ x: 2.5, y: 2.5 })
            .opacity(seg(this.p, 0.00, 0.30) * (0.18 + 0.42 * Math.abs(Math.sin(this.p * 3.4 + 6.090583125))))
      // ⑤ ★ 暗角 vignette（四角压暗，把视线收到中心）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '40%'],
          radius: '78%',
          colors: [['#00000000', 0.0], ['#00000000', 0.55], ['#00000066', 1.0]]
        })
        .opacity(seg(this.p, 0.02, 0.16))
        .hitTestBehavior(HitTestMode.None)

      // ⑥ ★ 金色微光带（从左扫到右，全程只扫一次）
      Column()
        .width('34%')
        .height('150%')
        .linearGradient({
          angle: 104,
          colors: [['#00C99E52', 0.0], ['#2AC99E52', 0.5], ['#00C99E52', 1.0]]
        })
        .rotate({ angle: 14 })
        .position({ x: '-40%', y: '-22%' })
        .translate({ x: seg(this.p, 0.06, 0.72) * 340 })
        .opacity(seg(this.p, 0.06, 0.16) * (1 - seg(this.p, 0.60, 0.74)))
        .hitTestBehavior(HitTestMode.None)

            // ══ 主体 ══
      Column() {
        // ── OM（占屏宽 78%，中上方）──
        Stack() {
          // 描边层：细线勾勒
          Shape() {
            Path()
              .commands(O_PATH)
              .fillOpacity(0)
              .stroke(OM_GOLD)
              .strokeWidth(6)
              .strokeLineCap(LineCapStyle.Round)
              .strokeLineJoin(LineJoinStyle.Round)
              .strokeDashArray([O_LEN, O_LEN])
              .strokeDashOffset(O_LEN * (1 - ease(seg(this.p, 0.05, 0.26))))
            Path()
              .commands(M_PATH)
              .fillOpacity(0)
              .stroke(OM_CREAM)
              .strokeWidth(6)
              .strokeLineCap(LineCapStyle.Round)
              .strokeLineJoin(LineJoinStyle.Round)
              .strokeDashArray([M_LEN, M_LEN])
              .strokeDashOffset(M_LEN * (1 - ease(seg(this.p, 0.26, 0.45))))
          }
          .viewPort({ x: 0, y: 0, width: VP_W, height: VP_H })
          .width('100%')
          .height('100%')
          .opacity(1 - seg(this.p, 0.45, 0.55))

          // 实心层：画完即成形
          Shape() {
            Path()
              .commands(O_PATH)
              .fill(OM_GOLD)
            Path()
              .commands(M_PATH)
              .fill(OM_CREAM)
          }
          .viewPort({ x: 0, y: 0, width: VP_W, height: VP_H })
          .width('100%')
          .height('100%')
          .opacity(seg(this.p, 0.45, 0.55))

          // 金点
          Circle()
            .width(22)
            .height(22)
            .fill(OM_GOLD)
            .position({
              x: (DOT_XR * 100) + '%',
              y: (DOT_YR * 100) + '%'
            })
            .markAnchor({ x: 11, y: 11 })
            .scale({
              x: ease(seg(this.p, 0.52, 0.60)),
              y: ease(seg(this.p, 0.52, 0.60))
            })
            .opacity(seg(this.p, 0.52, 0.60))

          // 涟漪一
          Circle()
            .width(22)
            .height(22)
            .fillOpacity(0)
            .stroke(OM_GOLD)
            .strokeWidth(1.5)
            .position({
              x: (DOT_XR * 100) + '%',
              y: (DOT_YR * 100) + '%'
            })
            .markAnchor({ x: 11, y: 11 })
            .scale({
              x: 1 + seg(this.p, 0.54, 0.66) * 4.6,
              y: 1 + seg(this.p, 0.54, 0.66) * 4.6
            })
            .opacity(seg(this.p, 0.54, 0.66) * (1 - seg(this.p, 0.54, 0.66)) * 2.2)

          // 涟漪二
          Circle()
            .width(22)
            .height(22)
            .fillOpacity(0)
            .stroke(OM_GOLD)
            .strokeWidth(1)
            .position({
              x: (DOT_XR * 100) + '%',
              y: (DOT_YR * 100) + '%'
            })
            .markAnchor({ x: 11, y: 11 })
            .scale({
              x: 1 + seg(this.p, 0.58, 0.70) * 7.8,
              y: 1 + seg(this.p, 0.58, 0.70) * 7.8
            })
            .opacity(seg(this.p, 0.58, 0.70) * (1 - seg(this.p, 0.58, 0.70)) * 1.6)

          // 涟漪三（最外圈，最淡）
          Circle()
            .width(22)
            .height(22)
            .fillOpacity(0)
            .stroke(OM_GOLD)
            .strokeWidth(0.8)
            .position({
              x: (DOT_XR * 100) + '%',
              y: (DOT_YR * 100) + '%'
            })
            .markAnchor({ x: 11, y: 11 })
            .scale({
              x: 1 + seg(this.p, 0.62, 0.78) * 11.0,
              y: 1 + seg(this.p, 0.62, 0.78) * 11.0
            })
            .opacity(seg(this.p, 0.62, 0.78) * (1 - seg(this.p, 0.62, 0.78)) * 1.1)

          // ★ 十字星芒：四道光芒从金点射出
          Column()
            .width(2)
            .height(seg(this.p, 0.54, 0.64) * 96)
            .linearGradient({
              angle: 180,
              colors: [['#FFE4B8', 0.0], ['#00C99E52', 1.0]]
            })
            .position({ x: (DOT_XR * 100) + '%', y: (DOT_YR * 100) + '%' })
            .markAnchor({ x: 1, y: seg(this.p, 0.54, 0.64) * 96 + 6 })
            .opacity(seg(this.p, 0.54, 0.64) * (1 - seg(this.p, 0.66, 0.82)))
          Column()
            .width(2)
            .height(seg(this.p, 0.54, 0.64) * 96)
            .linearGradient({
              angle: 0,
              colors: [['#FFE4B8', 0.0], ['#00C99E52', 1.0]]
            })
            .position({ x: (DOT_XR * 100) + '%', y: (DOT_YR * 100) + '%' })
            .markAnchor({ x: 1, y: -6 })
            .opacity(seg(this.p, 0.54, 0.64) * (1 - seg(this.p, 0.66, 0.82)))
          Row()
            .width(seg(this.p, 0.54, 0.64) * 96)
            .height(2)
            .linearGradient({
              angle: 90,
              colors: [['#FFE4B8', 0.0], ['#00C99E52', 1.0]]
            })
            .position({ x: (DOT_XR * 100) + '%', y: (DOT_YR * 100) + '%' })
            .markAnchor({ x: -6, y: 1 })
            .opacity(seg(this.p, 0.54, 0.64) * (1 - seg(this.p, 0.66, 0.82)))
          Row()
            .width(seg(this.p, 0.54, 0.64) * 96)
            .height(2)
            .linearGradient({
              angle: 270,
              colors: [['#FFE4B8', 0.0], ['#00C99E52', 1.0]]
            })
            .position({ x: (DOT_XR * 100) + '%', y: (DOT_YR * 100) + '%' })
            .markAnchor({ x: seg(this.p, 0.54, 0.64) * 96 + 6, y: 1 })
            .opacity(seg(this.p, 0.54, 0.64) * (1 - seg(this.p, 0.66, 0.82)))
        }
        // ★ 2026-10-19（离线渲染比对后调）：78% → 88%
        //   渲染出来 OM + 标题只占屏幕上方 43%，下面 57% 空着 ⇒ 太稀
        //   88% 让 OM 成为绝对主体，内容占到 51%
        .width('88%')
        .aspectRatio(OM_RATIO)
        .shadow({
          radius: seg(this.p, 0.50, 0.58) * (1 - seg(this.p, 0.62, 0.80)) * 44,
          color: '#55C99E52',
          offsetX: 0,
          offsetY: 0
        })
        .scale({
          x: 1 + seg(this.p, 0.84, 0.94) * 0.035,
          y: 1 + seg(this.p, 0.84, 0.94) * 0.035
        })

        // ── 标题：字间距从宽收窄 ──
        Text('One More')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(16 - seg(this.p, 0.60, 0.72) * 15)
          .opacity(seg(this.p, 0.60, 0.72))
          .translate({ y: (1 - seg(this.p, 0.60, 0.72)) * 14 })
          .shadow({
            radius: seg(this.p, 0.60, 0.72) * 26,
            color: '#66FFFFFF',
            offsetX: 0,
            offsetY: 0
          })
          .margin({ top: 52 })

        // ── 副标题 ──
        Text(this.t('355 款小游戏', '355 GAMES'))
          .fontSize(FontSize.xs)
          .fontColor('#8AFFFFFF')
          .letterSpacing(5)
          .opacity(seg(this.p, 0.66, 0.78))
          .translate({ y: (1 - seg(this.p, 0.66, 0.78)) * 10 })
          .margin({ top: 14 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      // ★ 同步下调：17% → 20%，让 OM 落在屏幕中上方
      .padding({ top: '20%' })

      // ── 标语（贴底）──
      Column() {
        Text(this.t('碎片时间，随时开局', 'A quick round, any time'))
          .fontSize(FontSize.sm)
          .fontColor('#5AFFFFFF')
          .letterSpacing(2)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 66 })
      .opacity(seg(this.p, 0.72, 0.84))
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(OM_INK)
    .opacity(1 - seg(this.p, 0.94, 1.00))
    .onClick(() => {
      Haptics.tap();   // ★ 2026-10-19 按压反馈
      this.boost();   // ★ 点屏幕 = 加速
    })
  }
}
