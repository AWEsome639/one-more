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
 * ── 分镜表（单位 ms；总长 TOTAL=1660，兜底跳转 HOLD=1720）─────────
 *
 *   层   起点   时长   止点   内容
 *   ──────────────────────────────────────────────────────────────
 *   L0      0    420    420   底色 #0D1320 淡入（与启动窗口同色，零白闪）
 *   L1    110    520    630   远景星云浮现
 *   L2    170   2600*  2770*  星尘整体漂移（* 超出总长 ⇒ 交接时仍在动，
 *                             这是特意的：背景不该"停下等你"）
 *   L2'   170   1400   1570   星尘闪烁（第二个独立时钟，与漂移不同速）
 *   L3    200    600    800   主光晕
 *   L4a   280    980   1260   O 环描边亮度到位（98ms 内到顶，见下）
 *   L4a'  280    420    700   日出：金点从山脊后升起（比描边快 ⇒ 先升后成）
 *   L4a"  280    520    800   金属高光绕环（Linear —— 唯一的匀速层）
 *   L4a‴  350    460    810   M 山（比环晚 70ms ⇒ 两拍节奏）
 *   L4b   600    440   1040   填充点亮
 *   L5    740    520   1260   细光带扫过
 *   L6    820    550   1370   标题（每字各自延迟，见 charSeg）
 *   L7   1080    360   1440   副标题
 *   L8   1220    400   1620   标语
 *   L9   1400    460   1860   整体推出（scale 1→0.94 + 淡出）
 *   ──────────────────────────────────────────────────────────────
 *   1660 = TOTAL（进度终点） ｜ 1720 = HOLD（硬跳转兜底）
 *
 * ★ 为什么 L9 的止点(1860) > TOTAL(1660)：
 *   TOTAL 只是"进度跑满"的时刻，推出动画自己还要 460ms 走完；
 *   HOLD=1720 是硬跳（比 L9 走完早 140ms）—— 因为交接转场
 *   会接着把这 140ms 补完（Index 有 320ms 的 scale 入场）。
 *   ⇒ **两段动画首尾相接，中间不留空白。**
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
import { PathShape } from '@ohos.arkui.shape';
import { hilog } from '@kit.PerformanceAnalysisKit';
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
const TOTAL: number = 1660;
const HOLD: number = 1720;               // 兜底跳转时刻

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

/**
 * 两拍节奏用的曲线（全局，setTimeout 里不能用 this）。
 * 轻微过冲：y1 = 1.06 > 1 —— M 山"长出来"时有一点点弹性。
 */
function sunCurveGlobal(): ICurve {
  return curves.cubicBezierCurve(0.34, 1.06, 0.36, 1.0);
}

@Entry
@Component
struct Splash {
  // ── 动画进度（全部 0→1，由时间表驱动）──
  @State pBg: number = 0;        // L0 底色
  @State pNebula: number = 0;    // L1 星云
  @State pDust: number = 0;      // L2 星尘漂浮
  @State pGlow: number = 0;      // L3 光晕
  @State pStroke: number = 0;    // L4a 描边生长
  @State pSun: number = 0;       // 日出：金点从山脊后升起
  /** 金属高光：4 段短弧绕环旋转（0→1） */
  @State pGlint: number = 0;
  /** M 山：比环晚 70ms 到（两拍节奏的第二拍） */
  @State pM: number = 0;
  @State pFill: number = 0;      // L4b 填充点亮
  @State pSweep: number = 0;     // L5 光带
  @State pTitle: number = 0;     // L6 标题
  @State pSub: number = 0;       // L7 副标题
  @State pTag: number = 0;       // L8 标语
  @State pOut: number = 0;       // L9 推出
  @State pTwinkle: number = 0;   // 星尘闪烁（独立循环一次）

  private started: boolean = false;
  /** 页面诞生时刻（ms），用于 boost 的时间护栏 */
  private born: number = 0;
  private finished: boolean = false;
  private boosted: boolean = false;
  @State private tiny: boolean = false;
  /** 极小屏（< 260vp，如运动手表 195）：只留 OM + 标题，其余省略 */
  @State private ultraTiny: boolean = false;
  /** 屏宽（vp），由 onAreaChange 写入；用于**按比例**决定字号 ——
   *  固定 pt 在大屏上会显得很小（平板竖屏 800vp 上 108pt 只占 13% 宽）。 */
  @State private vw: number = 0;
  @State private vh: number = 0;
  // ★ 2026-10-30 真机踩到：getter 里读 @State 会拿到 NaN
  //   （日志：SPLASH w=800 h=1213 om=NaN）
  //   ⇒ 改成**在 onAreaChange 里算好、存进 @State**，模板直接读字段。
  @State private omPx: number = 108;
  @State private titlePx: number = 44;
  @State private subPx: number = 12;
  @State private tagPx: number = 11;

  private t(zh: string, en: string): string {
    return L(zh, en);
  }

  // ── 缓动：这些曲线决定了「贵不贵」 ──
  /** 快起慢收，用于大面积淡入 */
  private easeOut(): ICurve {
    return curves.cubicBezierCurve(0.16, 0.84, 0.24, 1.0);
  }

  /** 有回弹的收尾，用于标题/徽标落位 */
  /**
   * 日出的曲线：轻微过冲（y1 = 1.12 > 1）。
   * ★ M3 Expressive 纪律：**位移可过冲，透明度不可**。
   *   所以同一个 pSun 驱动 translate（有过冲的"升起感"）与 opacity（临界阻尼）。
   */
  private sunCurve(): ICurve {
    return curves.cubicBezierCurve(0.34, 1.12, 0.36, 1.0);
  }

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
    this.born = Date.now();
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
    }, 110);
    // L2 星尘（一次长动，覆盖全程）
    // ★ 用 `Curve.Linear` 是**特意**的：星尘是 2600ms 的背景漂移，
    //   如果给它加 ease（前快后慢），星幕会在中段"刹车"，一眼看出是动画。
    //   真实星空是匀速漂的 ⇒ 只有匀速才"不像是动画"。
    //   ★ 判据：`Linear` 不是"廉价"，是"匀速"；
    //     该匀速的（星幕漂移 / 金属高光旋转）用它，该有加减速的绝不用。
    setTimeout(() => {
      animateTo({ duration: 2600, curve: Curve.Linear }, () => {
        this.pDust = 1;
      });
      animateTo({ duration: 1400, curve: this.easeOut() }, () => {
        this.pTwinkle = 1;
      });
    }, 170);
    // L3 光晕
    setTimeout(() => {
      animateTo({ duration: 600, curve: this.easeOut() }, () => {
        this.pGlow = 1;
      });
    }, 200);
    // L4a 描边生长
    setTimeout(() => {
      animateTo({ duration: 980, curve: this.settle() }, () => {
        this.pStroke = 1;
      });
      // 日出：比描边快，420ms 内升到位
      animateTo({ duration: 420, curve: this.sunCurve() }, () => {
        this.pSun = 1;
      });
      // 金属高光：520ms 匀速绕环
      // 本文件另一处 Linear 是 L2 星尘漂移，两处理由相同：**该匀速的才匀速**。
      animateTo({ duration: 520, curve: Curve.Linear }, () => {
        this.pGlint = 1;
      });
      // 两拍节奏第二拍：M 山比环晚 70ms 到（scale 0.94→1 + 淡入）
      setTimeout(() => {
        animateTo({ duration: 460, curve: sunCurveGlobal() }, () => {
          this.pM = 1;
        });
      }, 70);
    }, 280);
    // L4b 填充点亮（描边快完成时起，衔接最自然）
    setTimeout(() => {
      animateTo({ duration: 440, curve: this.easeOut() }, () => {
        this.pFill = 1;
      });
    }, 600);
    // L5 光带扫过
    setTimeout(() => {
      animateTo({ duration: 520, curve: this.sweepCurve() }, () => {
        this.pSweep = 1;
      });
    }, 740);
    // L6 标题
    setTimeout(() => {
      animateTo({ duration: 550, curve: this.settle() }, () => {
        this.pTitle = 1;
      });
    }, 820);
    // L7 副标题
    setTimeout(() => {
      animateTo({ duration: 360, curve: this.easeOut() }, () => {
        this.pSub = 1;
      });
    }, 1080);
    // L8 标语
    setTimeout(() => {
      animateTo({ duration: 400, curve: this.easeOut() }, () => {
        this.pTag = 1;
      });
    }, 1220);
    // L9 推出
    setTimeout(() => {
      animateTo({ duration: 460, curve: this.easeOut() }, () => {
        this.pOut = 1;
      });
    }, 1400);
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
    // ★★★ 2026-10-30 真机抓到：开屏**约 0.9 秒就跳走**（时间表设的是 3 秒）。
    //   根因：根 Stack 的 `onClick` 在启动过程中被触发（系统把启动触摸传了下来）
    //   ⇒ boost() 立刻跑完 ⇒ 560ms 后就 finish()。
    //   ⇒ 加时间护栏：**前 900ms 的点击一律忽略**。
    if (Date.now() - this.born < 900) {
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

  // ── 响应式字号 ──
  //   ★ 2026-10-30 平板竖屏（800vp）真机抓到：写死的 108pt 在 800vp 宽上只占 13%，
  //     视觉重心完全立不起来。⇒ 字号按**屏宽比例**推导，再 clamp 到合理区间。
  //     比例取自手机 440vp 上的观感（OM≈108pt ⇒ 0.245w）。
  // ── 图标几何（与 foreground.png 同比例）──
  //   O 外径 : M 宽 = 316 : 318  ⇒ 几乎 1:1
  //   O 与 M 的间距 = (511-510) ≈ 图标里几乎相接，这里给 2% 外径当作呼吸
  private get omD(): number {
    // omPx 是"OM 整体"的字号；这里 O 的直径取它的 0.46
    const t: number = this.tiny ? 54 : this.omPx;
    return t * 0.46;
  }

  private get omGap(): number {
    return this.omD * 0.06;
  }

  /** M 的多边形路径（归一化到 318×268 的框内） */
  private get mPath(): string {
    // 原图坐标 → 减去 (511, 398) → 得到 318 × 268
    //   峰1 (590,398) → (79, 0)
    //   谷  (670,576) → (159, 178)
    //   峰2 (749,405) → (238, 7)
    //   起 (511,644) → (0, 246)
    //   终 (829,664) → (318, 266)
    //   底 (318,268) → (0,268)
    return 'M0 246 L79 0 L159 178 L238 7 L318 266 L318 268 L0 268 Z';
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
  /**
   * OM 的宽度（vp）—— 与图标同比例。
   * ★ 不用 getter：本工程里 getter 读 @State 会返回 NaN（已踩两次，导致 Image 静默不渲染）。
   *   直接在方法里算，模板中调用。
   */
  private omPxV(): number {
    // 矢量 OM 的整体宽度（vp）。与 Image 版同口径：omPx × 2.05
    const t: number = this.tiny ? 54 : this.omPx;
    return t * 2.05;
  }

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
        // ── OM 字标：**直接用应用图标的原始资产** ──
        //   ★★★ 2026-10-30 奥森：「"O""M"的样式应该和应用图标一致」。
        //   我试过三套矢量方案（Shape/Path+viewPort、Circle+Polyline、
        //   Path 实心多边形）—— **在这个页面上全部不渲染**，
        //   只有 Text 与 Image 可靠。
        //   ⇒ 那就用最正确、也最可靠的做法：
        //     **把 AppScope 的 foreground.png 复制进 entry 资源，直接 Image 显示。**
        //     这就是图标本身，样式 100% 一致，且跨设备渲染稳定。
        // ═══════════════════════════════════════════════════════════
        //  OM 不是位图，是**三层可独立驱动的矢量**（2026-10-30 重做）
        //
        //  为什么必须拆（子代理研究报告的核心结论）：
        //    Image 只吃 opacity / blur / translate ⇒ 12 层背景全在动，
        //    **唯一该被看的主角反而一动不动** —— 这就是"丑"的真根因。
        //
        //  几何：从 AppScope/foreground.png 逐像素量出，归一化到 1000 宽
        //    · O 环  圆心(240.9, 266.1) 外半径 240.9 环宽 127.6
        //    · O 心  半径 62.9
        //    · M 山  左底(492.9,496.1) 左峰(587.4,0) 谷(744.9,351.2)
        //            右峰(910.2,0) 右底(1000,496.1)
        //    整体 1000 × 505.5（比率 1.978，与应用图标一致）
        //
        //  层序（Stack 子节点顺序即层序）：环 → 点 → M
        //    ⇒ M 的实心米白会遮住金点的下半 ⇒ **点从山脊后升起的"日出"成立**
        // ═══════════════════════════════════════════════════════════
        Stack() {
          // ═══ ⓿ 外发光（2026-10-30，第四次尝试 —— 终于对了）═══
          //   前三次的失败方式各不相同，最值得记的是**为什么第三版变成橙块**：
          //
          //   ★★★ ArkUI 的 8 位色值是 `#AARRGGBB`（**alpha 在前**），
          //        不是 CSS 的 `#RRGGBBAA`（alpha 在后）。
          //        我写 `#FFE8B833` 本意是「亮金 #E8B833 + alpha 0x33」，
          //        但引擎读成「alpha=FF（全不透明）+ 颜色 #E8B833」
          //        ⇒ 直接铺成一块**不透明的橙色**。这就是那个橙方块的来历。
          //   ⇒ 正确写法：`#33E8B833`（alpha 0x33 在前）。
          //
          //   前两版（OM 副本做发光）的失败是**概念错误**，不是格式问题：
          //     有形状的东西做发光，形状一定会露出来 ⇒ 读作"脏描边 / 灰影子"。
          //   ⇒ 外发光必须用**无形状**的径向渐变，且**直接挂在 OM 的 Stack 上**
          //     （不额外套容器）—— 这样它只贡献"这里亮着"，不贡献任何边界。
          //
          //   光斑参数：
          //     center 50%/48%  —— 对准 OM 的视觉重心（不是几何中心）
          //     radius 62%      —— 刚好铺满 OM 外接框，不硬边
          //     三段衰减       —— 核心亮 → 中段快掉 → 边缘全透
          //   跟着 pGlow 一起亮：logo 亮起来的时候，光也亮起来。
          Column()
            // ★ 第五版修正（第四版露出了矩形的暗边）：
            //   盒子放大到 1.85×1.85 倍 ⇒ 半径 50% 之外还有大量余量，
            //   **边缘一定落在全透明区**，看不到矩形边界。
            //   再用 position 把盒子中心对到 OM 的视觉重心（约 50% / 42%），
            //   而不是交给 Stack 的 alignContent 居中（OM 内容是绝对定位的，
            //   会和"居中"错开）。
            .width(this.omPxV() * 1.85)
            .height(this.omPxV() * 1.85)
            .position({
              x: this.omPxV() * (0.5 - 1.85 / 2),
              y: this.omPxV() * (0.42 - 1.85 / 2)
            })
            .radialGradient({
              center: ['50%', '50%'],
              radius: '42%',
              colors: [
                ['#30E8C87A', 0.0],      // alpha=0x30
                ['#14E8C87A', 0.40],
                ['#00E8C87A', 0.72],
                ['#00C99E52', 1.0]
              ]
            })
            .opacity(this.seg(this.pGlow, 0.0, 1.0))

          // ── ① O 环（描边圆，可 dash / 可独立高光）──
          //   几何（归一化到 1000 宽，再用 omW 换算成 vp）：
          //     圆心 (240.9, 266.1)  外半径 240.9  环宽 127.6
          // ── ① O 环（静态完整环；"成形感"由 opacity + 后面的错峰提供）──
          //   ★ 2026-10-30 实测结论：`strokeDashOffset` **不被 animateTo 插值**
          //     （放慢到 3000ms 仍 550ms 就到位）⇒ "从 12 点画出来"这条路走不通。
          //     已改用两拍节奏（环先到 → M 晚 70ms 到），见下方 M 的注释。
          Circle()
            .width(this.omPxV() * 0.4818).height(this.omPxV() * 0.4818)
            .fill(Color.Transparent)
            .stroke('#C99E52')
            .strokeWidth(this.omPxV() * 0.1276)
            .position({ x: this.omPxV() * 0.0, y: this.omPxV() * 0.0262 })
            .opacity(this.seg(this.pStroke, 0.001, 0.10))

          // ── ①b 金属高光：4 段短弧绕环旋转（研究报告 P2-1）──
          //   ★ 金的「贵」来自**会动的高光**，不是金色本身。
          //   ★ 这是全片唯一该用 Linear 的地方：金属反射本就匀速。
          //   做法：4 个同尺寸 Circle，各带一段 dash，初相 0/90/180/270，
          //        整组 rotate 0→90 ⇒ 读作"光在环上走"。
          ForEach([0, 1, 2, 3], (i: number) => {
            Circle()
              .width(this.omPxV() * 0.4818).height(this.omPxV() * 0.4818)
              .fill(Color.Transparent)
              .stroke('#F0D9A8')
              .strokeWidth(this.omPxV() * 0.1276)
              .strokeDashArray([this.omPxV() * 0.0832, this.omPxV() * 1.5140])
              .strokeDashOffset(-this.omPxV() * 0.3785 * i)
              .rotate({ angle: this.pGlint * 90 })
              .opacity(this.pGlint * [0.85, 0.40, 0.15, 0.40][i])
              .position({ x: this.omPxV() * 0.0, y: this.omPxV() * 0.0262 })
          }, (i: number) => 'glint' + i)

          // ── ② O 心点（金）：日出时从山脊后升起 ──
          Column()
            .width(this.omPxV() * 0.1258).height(this.omPxV() * 0.1258)
            .borderRadius(999)
            .backgroundColor('#E8C87A')
            .position({ x: this.omPxV() * (0.2409 - 0.0629), y: this.omPxV() * (0.2661 - 0.0629) })
            // ★「日出」（2026-10-30）：金点从山脊后升起 —— 位移可过冲，透明度不可
            .translate({ y: (1 - this.pSun) * this.omPxV() * 0.0629 })
            .opacity(this.seg(this.pSun, 0.001, 0.30))

          // ── ③ M 山（米白多边形）：压在点上，遮住下半 ⇒ 日出感 ──
          //   左底(492.9,496.1) 左峰(587.4,0) 谷(744.9,351.2) 右峰(910.2,0) 右底(1000,496.1)
          // ★ 2026-10-30：`Polygon.points` 收的是**绝对坐标**（vp），不是百分比 ——
          //   原来传 [[0,100],[18.6,0]…] 被当成 100vp 的盒子 ⇒ M 缩成一小块。
          //   ⇒ 改成按 omPxV 换算的真实 vp 坐标（M 的 5 个顶点，归一化值 × omPxV）。
          // ── ③ M 山（米白多边形，单块）──
          //   ⚠️ 2026-10-30 两次想给 M "加质感"，两次都失败，都回滚了：
          //     ① linearGradient + maskShape → **M 完全消失**（maskShape 本项目无效）
          //     ② 拆成三块刻面（色差 1~2% 亮度）→ 深色背景上被对比度放大，
          //        读作"M 右半边脏了"，不是"受光"
          //   ★ 而且第二次我又是直接改主视觉（第三次犯同一个错）。
          //     正确顺序永远是：先在 XxxTest.ets 里看清效果，再往 OM 上套。
          //
          //   现状：M 保持**单一米白 Polygon**（与应用图标一致）。
          //   「渐变」这一项在本项目当前 ArkUI 上无解（见台账第 522 轮，四条路全堵死）。
          //
          //   几何（归一化到 1000 宽）：
          //     左底(0,496.1) 左峰(94.5,0) 谷(252.0,351.2) 右峰(417.3,0) 右底(507.1,496.1)
          Polygon()
            .width(this.omPxV() * 0.5071).height(this.omPxV() * 0.4961)
            .points([
              [0, this.omPxV() * 0.4961],
              [this.omPxV() * 0.0945, 0],
              [this.omPxV() * 0.2520, this.omPxV() * 0.3512],
              [this.omPxV() * 0.4173, 0],
              [this.omPxV() * 0.5071, this.omPxV() * 0.4961]
            ])
            .fill('#FAF8F3')
            .position({ x: this.omPxV() * 0.4929, y: this.omPxV() * 0.0 })
            // ★ 两拍节奏：环先到（pStroke），M 晚 70ms 到（pM）
            .opacity(this.seg(this.pM, 0.001, 0.55))
            .scale({ x: 0.94 + this.seg(this.pM, 0.0, 1.0) * 0.06,
                     y: 0.94 + this.seg(this.pM, 0.0, 1.0) * 0.06 })
        }
        // 整体 1000 × 505.5 ⇒ 宽高比 1.978（与应用图标一致）
        .width(this.omPxV() * 1.0)
        .height(this.omPxV() * 0.5055)
        .margin({ bottom: this.tiny ? 4 : 10 })


        // ── 标题：逐字入场 ──
        // 逐字
        Row({ space: this.tiny ? 1 : 2 }) {
          ForEach(['O', 'n', 'e', ' ', 'M', 'o', 'r', 'e'], (ch: string, i: number) => {
            Text(ch)
              .fontSize(this.tiny ? 26 : this.titlePx)
              .fontWeight(FontWeight.Bold)
              .fontColor(OM_CREAM)
              .letterSpacing(this.tiny ? 4 : 6)
              .opacity(this.charIn(i, 8))
              .translate({ y: (1 - this.charIn(i, 8)) * (this.tiny ? 8 : 16) })
              .blur((1 - this.charIn(i, 8)) * (this.tiny ? 6 : 10))
          }, (ch: string, i: number) => 'c' + i + ch)
        }
        .margin({ top: this.tiny ? 6 : (this.vh > 0 && this.vh < 620 ? 12 : 40) })

        // 副标题（极小屏省略 —— 那里只留 OM + 标题）
        Text(this.t('355 款小游戏', '355 GAMES'))
          .fontSize(this.tiny ? 9 : this.subPx)
          .fontWeight(FontWeight.Medium)
          .fontColor('#B8C99E52')
          .opacity(this.ultraTiny ? 0 : this.pSub * 0.94)
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
      .scale({ x: 1 - this.pOut * 0.06, y: 1 - this.pOut * 0.06 })
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
          .fontSize(this.tiny ? 8 : this.tagPx)
          // ★ 2026-10-30：原来是 '#9AC99E52'（alpha 0x9A=60%）× opacity 0.9
          //   ⇒ 最终约 54% ⇒ 真机上"几乎看不见"，等于没做这一层。
          //   ⇒ 提到 0xCC（80%）：可读、但仍低于标题与副标题的亮度（不抢戏）。
          .fontColor('#CC9E52')  // ★ 注意：这是 6 位 hex = 全不透明（不是 80%）
          .letterSpacing(this.tiny ? 1 : 3)
          .margin({ bottom: this.tiny ? 16 : 40 })
      }
      .width('100%')
      .height('100%')
      .opacity(this.ultraTiny ? 0 : this.pTag * (1 - this.pOut))
      .hitTestBehavior(HitTestMode.None)

      // ──────── L10 细光带：从 OM 左侧扫到右侧 ────────
      //   ★ 2026-10-30（第二次尝试，这次对了）：
      //     第一次把它塞进 OM 的 Stack 里 ⇒ **把 Stack 撑高、OM 被顶出屏幕**。
      //     正确做法：作为**根 Stack 的独立层 + `.position()` 绝对定位**，
      //     不参与其它兄弟的布局测量。
      Column()
        .width(this.vw > 0 ? this.vw * 0.045 : 20)
        .height(this.vw > 0 ? this.vw * 0.22 : 100)
        .linearGradient({
          angle: 96,
          colors: [
            ['#00FFFFFF', 0.00],
            ['#22FFF4D6', 0.36],
            ['#CFF0D9A8', 0.50],
            ['#22FFF4D6', 0.64],
            ['#00FFFFFF', 1.00]
          ]
        })
        .rotate({ angle: 12 })
        .blur(this.tiny ? 8 : 16)
        .position({
          x: ((this.vw > 0 ? this.vw * 0.18 : 80) + this.pSweep * (this.vw > 0 ? this.vw * 0.62 : 270)) + 'vp',
          y: (this.vh > 0 ? this.vh * 0.30 : 230) + 'vp'
        })
        .opacity(this.seg(this.pSweep, 0.00, 0.12) * (1 - this.seg(this.pSweep, 0.78, 1.00)) * 0.85)
        .hitTestBehavior(HitTestMode.None)

      // ──────── L11 胶片颗粒 ────────
      //   10 颗极小的半透明点，散布全屏 —— 给画面"胶片感"，不做噪点贴图（省资源）
      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (i: number) => {
        Column()
          .width(this.tiny ? 1.2 : 1.8)
          .height(this.tiny ? 1.2 : 1.8)
          .borderRadius(99)
          .backgroundColor('#16FFFFFF')
          .position({
            x: (((i * 37 + 11) % 100) * 0.01 * (this.vw > 0 ? this.vw : 440)) + 'vp',
            y: (((i * 61 + 23) % 100) * 0.01 * (this.vh > 0 ? this.vh : 744)) + 'vp'
          })
          .opacity(this.pBg * 0.55)
          .hitTestBehavior(HitTestMode.None)
      }, (i: number) => 'grain' + i)


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
      const w: number = n.width as number;
      if (w > 0 && Math.abs(w - this.vw) > 1) {
        this.vw = w;
      }
      if (h > 0 && Math.abs(h - this.vh) > 1) {
        this.vh = h;
      }
      // 按屏宽比例算字号，并 clamp 到合理区间
      if (w > 0) {
        // 矮屏（h < 620，如智慧屏 540 / 平板横屏 533）用更小的上限
        const cap: number = h > 0 && h < 620 ? 150 : 200;
        const om: number = Math.max(96, Math.min(cap, w * 0.245));
        const ti: number = Math.max(38, Math.min(104, w * 0.098));
        const su: number = Math.max(11, Math.min(28, w * 0.027));
        const tg: number = Math.max(10, Math.min(24, w * 0.023));
        if (Math.abs(om - this.omPx) > 1) {
          this.omPx = om;
        }
        if (Math.abs(ti - this.titlePx) > 1) {
          this.titlePx = ti;
        }
        if (Math.abs(su - this.subPx) > 1) {
          this.subPx = su;
        }
        if (Math.abs(tg - this.tagPx) > 1) {
          this.tagPx = tg;
        }
      }
      const isTiny: boolean = h > 0 && h < 360;
      // ★ 2026-10-30 运动手表 195×195 真机抓到：「碎片时间」与「One More」重叠。
      //   195vp 高，塞四层内容必然叠。⇒ **分级降级**：
      //     < 260vp：只留 OM + 标题（副标题、标语全部省略）
      //     < 360vp：星尘减半、字号缩小、间距收紧（原有 tiny 分支）
      const isUltra: boolean = h > 0 && h < 260;
      if (isTiny !== this.tiny) {
        this.tiny = isTiny;
      }
      if (isUltra !== this.ultraTiny) {
        this.ultraTiny = isUltra;
      }
    })
    .onClick(() => {
      this.boost();
    })
  }
}
