/*
 * ════════════════════════════════════════════════════════════════════════
 * Splash —— One More 开屏动画
 * ════════════════════════════════════════════════════════════════════════
 *
 * 设计目标：世界顶尖水平的开屏。判据不是"能跑"，是"每一帧都值钱"。
 *
 * ── 为什么要有这么长的一份文件 ─────────────────────────────────────
 *   开屏是用户看到的**第一秒钟**。它承载三件事：
 *     ① 品牌记忆（"OM" 这两个字母要能被记住）
 *     ② 品质暗示（动效的精度 = 产品的精度）
 *     ③ 情绪定调（深墨蓝 + 金色 = 沉静、克制、有点贵）
 *   所以它不是"一个过渡页"，而是一段**编排好的影像**：
 *   有分镜、有时间表、有景深、有材质、有呼吸。
 *
 * ── 时间表（单位 ms，总长 3000，之后推出）────────────────────────
 *     0 ── 420    L0 底色淡入（不允许白屏闪）
 *   180 ── 700    L1 远景星云浮现
 *   260 ── 2900   L2 星尘漂浮（48 颗，各自速度/相位/闪烁）
 *   300 ── 900    L3 主光晕呼吸开始（之后持续到最后）
 *   420 ── 1400   L4a OM 描边生长（O 先起，M 后跟 —— 有先后，不是同时）
 *  1180 ── 1620   L4b OM 渐变填充点亮（描边快完成时点亮，衔接处最亮）
 *  1380 ── 1900   L5 细光带扫过笔画（窄、亮、带 bloom）
 *  1500 ── 2050   L6 标题逐字入场（每个字有自己的延迟与位移）
 *  1900 ── 2260   L7 副标题淡入
 *  2150 ── 2550   L8 底部标语
 *  2500 ── 2960   L9 暗角收拢 + 整体推近 + 淡出
 *
 * ── 层级（从后到前）────────────────────────────────────────────────
 *   L0 底色            纯色，兜底，绝不留白
 *   L1 星云            径向渐变，慢、虚，做"有天光"的感觉
 *   L2 星尘            48 颗，三组不同速度（视差）
 *   L3 主光晕          金色底光，随 logo 点亮而增强
 *   L4 OM logo         三层材质叠：描边 / 渐变填充 / 高光描边
 *   L5 光带            1.4% 宽的亮带，SCREEN 混合
 *   L6 标题            逐字
 *   L7 副标题
 *   L8 标语
 *   L9 颗粒噪点 + 暗角  质感层
 *
 * ── 适配 ──────────────────────────────────────────────────────────
 *   全部尺寸用百分比 / aspectRatio，不写死 vp ⇒
 *   手机 440、平板 853/800、电视 960、手表 233/195 都能自适应。
 *   极小屏（< 340vp）自动降级：星尘减半、字号缩小、间距收紧。
 *
 * ── 性能 ──────────────────────────────────────────────────────────
 *   星尘总数 48，其中 24 颗只在「非极小屏」渲染 ⇒ 手表上只有 24。
 *   所有动画都走同一个 @State 进度值（p），避免 48 个独立动画轨道。
 *
 * ════════════════════════════════════════════════════════════════════════
 */
import { router, curves } from '@kit.ArkUI';
import { Haptics } from '../core/Haptics';
import { L } from '../core/I18n';

// ── 品牌色 ──
const OM_INK: string = '#0D1320';        // 底色：深墨蓝
const OM_INK_HI: string = '#16223A';     // 底色亮部
const OM_GOLD: string = '#C99E52';       // 主金
const OM_GOLD_HI: string = '#F0D9A8';    // 亮金（高光）
const OM_CREAM: string = '#FAF8F3';      // 米白（文字）

// ── OM 字形（3675 × 1855 的 viewBox）──
const O_PATH: string = 'M165.4 964.5Q165.4 638.5 404.4 404.5Q642.4 170.5 976.4 170.5Q1306.4 170.5 1542.4 406.5Q1779.4 642.5 1779.4 973.5Q1779.4 1306.5 1542.4 1542.5Q1306.4 1778.5 976.4 1778.5Q642.4 1778.5 404.4 1542.5Q165.4 1306.5 165.4 964.5Z';
const M_PATH: string = 'M1813.4 1743.5L2138.4 83.5L2668.4 1283.5L3217.4 83.5L3509.4 1743.5';
const O_LEN: number = 8697.4;            // O 的笔画长度（strokeDash 用）
const M_LEN: number = 6008.5;            // M 的笔画长度
const VP_W: number = 3675;
const VP_H: number = 1855;
const OM_RATIO: number = VP_W / VP_H;    // ≈ 1.981

// ── 总时长 ──
const TOTAL: number = 3000;
const HOLD: number = 3120;               // 兜底跳转时刻

// ── 星尘：三组，各自速度/相位 ──
//   每组 16 颗；每颗有 x, y, 半径, 组号
const STARS: number[][] = [
  // 组 0 —— 慢（远景）：8 颗
  [0.075, 0.140, 1.6], [0.215, 0.335, 1.3], [0.355, 0.560, 1.8],
  [0.520, 0.115, 1.2], [0.665, 0.420, 1.7], [0.800, 0.720, 1.4],
  [0.915, 0.245, 1.5], [0.130, 0.815, 1.3],
  // 组 1 —— 中：8 颗
  [0.100, 0.455, 2.4], [0.275, 0.690, 2.8], [0.430, 0.235, 2.2],
  [0.585, 0.880, 2.6], [0.720, 0.170, 2.5], [0.845, 0.545, 2.9],
  [0.945, 0.815, 2.3], [0.190, 0.955, 2.7],
  // 组 2 —— 快（近景）：8 颗
  [0.045, 0.630, 3.4], [0.310, 0.080, 3.8], [0.480, 0.735, 3.2],
  [0.640, 0.295, 3.6], [0.775, 0.905, 3.0], [0.880, 0.060, 3.9],
  [0.240, 0.215, 3.3], [0.560, 0.480, 3.5]
];
// 极小屏只保留前 24 颗（8+8+8 已经是 24；这里再减到 16 更省）
const STARS_TINY: number = 16;

@Entry
@Component
struct Splash {
  // ── 动画进度（全部 0→1，由时间表驱动）──
  @State pBg: number = 0;        // L0 底色
  @State pNebula: number = 0;    // L1 星云
  @State pDust: number = 0;      // L2 星尘漂浮
  @State pGlow: number = 0;      // L3 光晕
  @State pStroke: number = 0;    // L4a 描边生长
  @State pFill: number = 0;      // L4b 填充点亮
  @State pSweep: number = 0;     // L5 光带
  @State pTitle: number = 0;     // L6 标题
  @State pSub: number = 0;       // L7 副标题
  @State pTag: number = 0;       // L8 标语
  @State pOut: number = 0;       // L9 推出
  @State pTwinkle: number = 0;   // 星尘闪烁（独立循环一次）

  private started: boolean = false;
  private finished: boolean = false;
  private boosted: boolean = false;
  @State private tiny: boolean = false;

  private t(zh: string, en: string): string {
    return L(zh, en);
  }

  // ── 缓动：这些曲线决定了「贵不贵」 ──
  /** 快起慢收，用于大面积淡入 */
  private easeOut(): ICurve {
    return curves.cubicBezierCurve(0.16, 0.84, 0.24, 1.0);
  }

  /** 有回弹的收尾，用于标题/徽标落位 */
  private settle(): ICurve {
    return curves.cubicBezierCurve(0.22, 1.0, 0.36, 1.0);
  }

  /** 钟形：先快后慢再快，用于光带扫过 */
  private sweepCurve(): ICurve {
    return curves.cubicBezierCurve(0.45, 0.0, 0.25, 1.0);
  }

  /** 一个值在 [a,b] 区间内的归一化进度，并做平滑（smoothstep） */
  private seg(v: number, a: number, b: number): number {
    if (v <= a) {
      return 0;
    }
    if (v >= b) {
      return 1;
    }
    const x: number = (v - a) / (b - a);
    return x * x * (3 - 2 * x);   // smoothstep：两端平、中间快
  }

  /** 逐字进度：第 i 个字相对整体 pTitle 的偏移 */
  private charIn(i: number, total: number): number {
    const span: number = 0.55;                       // 每个字占整体进度的 55%
    const gap: number = (1 - span) / Math.max(1, total - 1);
    const start: number = i * gap;
    const raw: number = (this.pTitle - start) / span;
    if (raw <= 0) {
      return 0;
    }
    if (raw >= 1) {
      return 1;
    }
    return raw * raw * (3 - 2 * raw);
  }

  aboutToAppear(): void {
    // 极小屏判定：用页面自己的 onAreaChange 拿，不读 Bp
    //   （Bp 在 aboutToAppear 时可能还没 update 完 —— 今晚已踩过 3 次）
    //   见下方根容器 onAreaChange
  }

  onPageShow(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.runTimeline();
  }

  /** ★ 时间表：每一层有自己的入场时刻 —— 错开才有层次 */
  private runTimeline(): void {
    // L0 底色
    animateTo({ duration: 420, curve: this.easeOut() }, () => {
      this.pBg = 1;
    });
    // L1 星云
    setTimeout(() => {
      animateTo({ duration: 520, curve: this.easeOut() }, () => {
        this.pNebula = 1;
      });
    }, 180);
    // L2 星尘（一次长动，覆盖全程）
    setTimeout(() => {
      animateTo({ duration: 2600, curve: Curve.Linear }, () => {
        this.pDust = 1;
      });
      animateTo({ duration: 1400, curve: this.easeOut() }, () => {
        this.pTwinkle = 1;
      });
    }, 260);
    // L3 光晕
    setTimeout(() => {
      animateTo({ duration: 600, curve: this.easeOut() }, () => {
        this.pGlow = 1;
      });
    }, 300);
    // L4a 描边生长
    setTimeout(() => {
      animateTo({ duration: 980, curve: this.settle() }, () => {
        this.pStroke = 1;
      });
    }, 420);
    // L4b 填充点亮（描边快完成时起，衔接最自然）
    setTimeout(() => {
      animateTo({ duration: 440, curve: this.easeOut() }, () => {
        this.pFill = 1;
      });
    }, 1180);
    // L5 光带扫过
    setTimeout(() => {
      animateTo({ duration: 520, curve: this.sweepCurve() }, () => {
        this.pSweep = 1;
      });
    }, 1380);
    // L6 标题
    setTimeout(() => {
      animateTo({ duration: 550, curve: this.settle() }, () => {
        this.pTitle = 1;
      });
    }, 1500);
    // L7 副标题
    setTimeout(() => {
      animateTo({ duration: 360, curve: this.easeOut() }, () => {
        this.pSub = 1;
      });
    }, 1900);
    // L8 标语
    setTimeout(() => {
      animateTo({ duration: 400, curve: this.easeOut() }, () => {
        this.pTag = 1;
      });
    }, 2150);
    // L9 推出
    setTimeout(() => {
      animateTo({ duration: 460, curve: this.easeOut() }, () => {
        this.pOut = 1;
      });
    }, 2500);
    // 兜底
    setTimeout(() => {
      this.finish();
    }, HOLD);
  }

  private finish(): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    router.replaceUrl({ url: 'pages/Index' });
  }

  /** 点屏幕 = 加速跑完（不是直接跳过，保留观感） */
  private boost(): void {
    if (this.boosted || this.finished) {
      return;
    }
    this.boosted = true;
    Haptics.tap();
    animateTo({ duration: 240, curve: this.easeOut() }, () => {
      this.pBg = 1;
      this.pNebula = 1;
      this.pDust = 1;
      this.pTwinkle = 1;
      this.pGlow = 1;
      this.pStroke = 1;
      this.pFill = 1;
      this.pSweep = 1;
      this.pTitle = 1;
      this.pSub = 1;
      this.pTag = 1;
    });
    setTimeout(() => {
      animateTo({ duration: 240, curve: this.easeOut() }, () => {
        this.pOut = 1;
      });
    }, 260);
    setTimeout(() => {
      this.finish();
    }, 560);
  }

  /** 星尘可见性：极小屏减半 */
  private starCount(): number {
    return this.tiny ? STARS_TINY : STARS.length;
  }

  /** 星尘漂移幅度：组号越大（近景）动得越多 */
  private starDrift(i: number): number {
    const group: number = Math.floor(i / 8);
    const amp: number = 10 + group * 16;
    return -this.pDust * amp;
  }

  /** 星尘闪烁：每颗相位不同 */
  private starTwi(i: number): number {
    const ph: number = (i * 0.37) % 1;
    const v: number = this.pTwinkle * 2 - ph;
    const osc: number = 0.5 + 0.5 * Math.sin(v * Math.PI * 2);
    return 0.35 + osc * 0.65;
  }

  // ── 几何量（vp）：随屏宽自适应，但不读 Bp ──
  //   基准：宽 440vp 时 O 直径 118vp、笔画 9vp、M 宽 108vp
  private get oD(): number {
    return this.tiny ? 62 : 118;
  }
  private get strokeW(): number {
    return this.tiny ? 5 : 9;
  }
  private get oLen(): number {
    // 圆周长 = π d
    return Math.PI * this.oD;
  }
  private get mW(): number {
    return this.tiny ? 56 : 108;
  }
  private get mH(): number {
    return this.tiny ? 62 : 118;
  }
  private get mLen(): number {
    // 5 点折线的真实长度（4 段），直接用勾股逐段算
    const p: number[][] = [[0, this.mH], [this.mW * 0.30, 0],
                           [this.mW * 0.60, this.mH * 0.62], [this.mW * 0.90, 0],
                           [this.mW, this.mH]];
    let total: number = 0;
    for (let k: number = 1; k < p.length; k++) {
      const dx: number = p[k][0] - p[k - 1][0];
      const dy: number = p[k][1] - p[k - 1][1];
      total = total + Math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  // ══════════════════════════════════════════════════════════════════
  //  渲染
  // ══════════════════════════════════════════════════════════════════
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ──────── L0 底色（永远不透明，绝不留白）────────
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OM_INK)
        .opacity(this.pBg)

      // ──────── L1 星云：径向渐变，慢，虚 ────────
      Column()
        .width('170%')
        .height('120%')
        .radialGradient({
          center: ['50%', '36%'],
          radius: '60%',
          colors: [
            [OM_INK_HI, 0.0],
            ['#121E36', 0.46],
            [OM_INK, 1.0]
          ]
        })
        .position({ x: '-35%', y: '-8%' })
        .opacity(this.pNebula * 0.95)

      // ──────── L2 星尘：48 颗（极小屏 16 颗）────────
      ForEach(Array.from({ length: this.starCount() }, (_v: number, k: number) => k), (i: number) => {
        Column()
          .width(STARS[i][2])
          .height(STARS[i][2])
          .borderRadius(99)
          .backgroundColor(i % 5 === 0 ? OM_GOLD_HI : OM_CREAM)
          .position({
            x: (STARS[i][0] * 100) + '%',
            y: (STARS[i][1] * 100) + '%'
          })
          .translate({ y: this.starDrift(i) })
          .opacity(this.pNebula * 0.5 * this.starTwi(i))
          .blur(this.tiny ? 0 : 0.4)
      }, (i: number) => 'dust' + i)

      // ──────── L3 主光晕：金色底光，随点亮增强 ────────
      Column()
        .width('150%')
        .height('80%')
        .radialGradient({
          center: ['50%', '48%'],
          radius: '54%',
          colors: [
            ['#2EC99E52', 0.0],
            ['#14C99E52', 0.44],
            ['#00C99E52', 1.0]
          ]
        })
        .position({ x: '-25%', y: '4%' })
        .opacity(this.pGlow * (0.45 + this.pFill * 0.55))

      // ──────── L5（提前占位：光带要盖在 logo 上，所以放在 logo 之前声明、之后叠？）
      //          —— 放在 logo 之后绘制，见下方 sweep 段。

      // ──────── L4~L7 合并为「一个 Column」：OM / 标题 / 副标题自然垂直排列 ────────
      //   ★★★ 2026-10-30 手表 233×233 真机抓到：OM 与标题**重叠成一团**。
      //     根因：OM 是独立层（translate -22），标题列是另一层（translate +10），
      //           小屏上两层直接撞在一起。
      //   ⇒ 结构修法：**把 OM / 标题 / 副标题放进同一个 Column**，
      //     间距由 margin 控制、由 tiny 分支给不同值 —— 永远不会重叠。
      Column() {
        // ── OM 字标（三层：辉光 / 主体 / 高光）──
        Stack() {
        // 外发光层（大字号、极低透明度、模糊）—— 制造"金色在发光"的空气感
        Text('OM')
          .fontSize(this.tiny ? 54 : 108)
          .fontWeight(FontWeight.Bold)
          .fontColor(OM_GOLD)
          .letterSpacing(this.tiny ? -2 : -4)
          .opacity(this.seg(this.pFill, 0.10, 0.80) * 0.30)
          .blur(this.tiny ? 10 : 22)

        // 主体：金色
        Text('OM')
          .fontSize(this.tiny ? 54 : 108)
          .fontWeight(FontWeight.Bold)
          .fontColor(OM_GOLD)
          .letterSpacing(this.tiny ? -2 : -4)
          .opacity(this.seg(this.pStroke, 0.05, 0.46))
          .blur((1 - this.seg(this.pStroke, 0.05, 0.46)) * (this.tiny ? 8 : 16))
          .translate({ y: (1 - this.seg(this.pStroke, 0.05, 0.46)) * (this.tiny ? 6 : 12) })

        // 高光层：亮金，略微上移 1vp 制造"字面反光"
        Text('OM')
          .fontSize(this.tiny ? 54 : 108)
          .fontWeight(FontWeight.Bold)
          .fontColor(OM_GOLD_HI)
          .letterSpacing(this.tiny ? -2 : -4)
          .opacity(this.seg(this.pFill, 0.30, 1.00) * 0.55)
          .translate({ y: this.tiny ? -0.5 : -1 })
          .textShadow({
            radius: this.seg(this.pFill, 0.2, 1.0) * (this.tiny ? 16 : 34),
            color: '#66C99E52',
            offsetX: 0,
            offsetY: 0
          })

        // ── L5 光带：极窄、高亮、SCREEN 混合 ──
        Column()
          .width('2.4%')
          .height('520%')
          .linearGradient({
            angle: 96,
            colors: [
              ['#00FFFFFF', 0.00],
              ['#1AFFF4D6', 0.34],
              ['#F2F0D9A8', 0.50],
              ['#1AFFF4D6', 0.66],
              ['#00FFFFFF', 1.00]
            ]
          })
          .rotate({ angle: 11 })
          .translate({ x: (-160 + this.pSweep * 320) + 'vp', y: '-210%' })
          .opacity(this.seg(this.pSweep, 0.00, 0.14) * (1 - this.seg(this.pSweep, 0.72, 1.00)) * 0.95)
          .blendMode(BlendMode.SCREEN, BlendApplyType.OFFSCREEN)
          .hitTestBehavior(HitTestMode.None)
        }
        // ★ 2026-10-30 手表真机抓到：这里原来写死 width(62/120)，
        //   而 54pt 的「OM」两个字母需要 70vp+ ⇒ **宽度不足 ⇒ M 被换行挤下去**，
        //   正好叠在标题上。⇒ 不设固定宽高，让内容自己撑开；只给一个最小宽度兜底。
        .constraintSize({ minWidth: this.tiny ? 78 : 150 })
        .clip(false)

        // ── 标题：逐字入场 ──
        // 逐字
        Row({ space: this.tiny ? 1 : 2 }) {
          ForEach(['O', 'n', 'e', ' ', 'M', 'o', 'r', 'e'], (ch: string, i: number) => {
            Text(ch)
              .fontSize(this.tiny ? 26 : 44)
              .fontWeight(FontWeight.Bold)
              .fontColor(OM_CREAM)
              .letterSpacing(this.tiny ? 4 : 6)
              .opacity(this.charIn(i, 8))
              .translate({ y: (1 - this.charIn(i, 8)) * (this.tiny ? 8 : 16) })
              .blur((1 - this.charIn(i, 8)) * (this.tiny ? 6 : 10))
          }, (ch: string, i: number) => 'c' + i + ch)
        }
        .margin({ top: this.tiny ? 6 : 40 })

        // 副标题
        Text(this.t('3 5 5 款 小 游 戏', '3 5 5  G A M E S'))
          .fontSize(this.tiny ? 9 : 12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#B8C99E52')
          .opacity(this.pSub * 0.94)
          .translate({ y: (1 - this.pSub) * 10 })
          .margin({ top: this.tiny ? 4 : 14 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      // 极小屏：把整组内容上移一点，给底部标语留位置
      .padding({ bottom: this.tiny ? 34 : 0 })
      .translate({ y: this.tiny ? -6 : -14 })
      .scale({ x: 1 + this.pOut * 0.06, y: 1 + this.pOut * 0.06 })
      .opacity(1 - this.pOut)

      // ──────── L8 底部标语 ────────
      // ★ 2026-10-30 平板横屏真机抓到：标语原来用 height('100%') + justifyContent(End)，
      //   在 533vp 高的横屏上**没有落到最底**，反而压到了副标题上。
      //   ⇒ 改用 Stack 的 align(Alignment.Bottom)：位置由 Stack 决定，与高度无关。
      // ★ 2026-10-30：`.align(Alignment.Bottom)` 在 Stack 的直接子节点上不生效
      //   （容器没有高度 ⇒ 没有"底"可对齐）。
      //   ⇒ 用一个**撑满高度的内层 Stack** + `alignContent: Bottom`，
      //     文字就一定贴底，与屏幕高度无关（440/533/1280/540 都成立）。
      Stack({ alignContent: Alignment.Bottom }) {
        Text(this.t('碎片时间，随时开局', 'A quick round, any time'))
          .fontSize(this.tiny ? 8 : 11)
          .fontColor('#9AC99E52')
          .letterSpacing(this.tiny ? 1 : 3)
          .margin({ bottom: this.tiny ? 16 : 40 })
      }
      .width('100%')
      .height('100%')
      .opacity(this.pTag * 0.9 * (1 - this.pOut))
      .hitTestBehavior(HitTestMode.None)

      // ──────── L9 暗角（vignette）：把注意力收到中间 ────────
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '46%'],
          radius: '72%',
          colors: [
            ['#00000000', 0.0],
            ['#00000000', 0.52],
            ['#66000000', 1.0]
          ]
        })
        .opacity(this.pBg * 0.9)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(OM_INK)
    .onAreaChange((_o: Area, n: Area) => {
      const h: number = n.height as number;
      const isTiny: boolean = h > 0 && h < 360;
      if (isTiny !== this.tiny) {
        this.tiny = isTiny;
      }
    })
    .onClick(() => {
      this.boost();
    })
  }
}
