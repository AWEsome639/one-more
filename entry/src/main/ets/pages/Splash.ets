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
 *   L0      0    240    240   底色 #0D1320 淡入（与启动窗口同色，零白闪）
 *   L1      0    380    380   远景星云浮现
 *   L2    170   2600*  2770*  星尘整体漂移（* 超出总长 ⇒ 交接时仍在动，
 *                             这是特意的：背景不该"停下等你"）
 *   L2'   170   2100   2270   星尘闪烁（第二个独立时钟，与漂移不同速）
 *   L3    200    600    800   主光晕
 *   L4a   280    980   1260   O 环描边亮度到位（98ms 内到顶，见下）
 *   L4a'  280    420    700   日出：金点从山脊后升起（比描边快 ⇒ 先升后成）
 *   L4a"  280    520    800   金属高光绕环（Linear —— 唯一的匀速层）
 *   L4a‴  350    460    810   M 山（比环晚 70ms ⇒ 两拍节奏）
 *   L4b   600    440   1040   填充点亮
 *   L5    740    520   1260   细光带扫过
 *   L6    820    550   1370   标题（每字各自延迟，见 charSeg）
 *   L7   1050    300   1350   副标题
 *   L8   1180    300   1480   标语
 *   L9   1950    320   2270   整体推出（scale 1→0.94 + 淡出）
 *   ──────────────────────────────────────────────────────────────
 *   2270 = TOTAL（进度终点） ｜ 2230 = HOLD（硬跳转兜底）
 *
 * ★★★ 2026-11-03（第 1093 轮）**重排时间表：修「文字全在淡出中」的严重缺陷**
 *   改前（错）：L6 820+550=1370 ｜ L7 1080+360=**1440** ｜ L8 1220+400=**1620**
 *                L9 **1400**+460 ｜ HOLD 1720
 *   ⇒ L9 起点 1400 **早于** L7 止点 1440、L8 止点 1620
 *   ⇒ 副标题在退场已开始 40ms 后才亮完；标语晚 220ms
 *   ⇒ 三行的「可读窗口」= 1370→1400 **30ms** / 1440→1400 **−40ms** / 1620→1400 **−220ms**
 *   ⇒ **没有一个字是静止可读的**，而这在 12 帧"验收"里完全没被抓到
 *      （因为拍的全部早于 1620ms，判据 327 第五次踩坑）
 *
 *   改后（对）：**每层「可读窗口 = [入场止点, 出场起点]」都 ≥ 400ms**
 *     标题   1370 → 1950 = **580ms** ✅
 *     副标题 1350 → 1950 = **600ms** ✅
 *     标语   1480 → 1950 = **470ms** ✅
 *     整屏静止（标语亮完 → 退场开始）：1480 → 1950 = **470ms** ✅
 *
 *   ★ 判据 370：入场止点必须 ≤ 出场起点。改后 L8 止点 1480 ≪ L9 起点 1950。
 *   ★ 判据 371：先定义「可读窗口」，窗口 < 300ms 则动效不可验收。改后最短 470ms。
 *
 * ★ 为什么 L9 的止点(2270) = TOTAL(2270)：
 *   这一版让推出动画**跑完**再硬跳（HOLD=2230 比它早 40ms，
 *   由 Index 的 320ms scale 入场接住）。
 *   ⇒ 两段动画首尾相接，中间不留空白。
 *
 * ── ★ 实测帧对照（2026-10-30，平板横屏 853×533，真机 8 帧）────────
 *   分镜不能只是"我打算这样"，必须能和真机截到的东西对上。
 *   下面这组是 `splash_8frames_LANDSCAPE.jpeg` 逐帧读出来的：
 *
 *   帧  大致的 p    画面上实际有什么                           对应层
 *   ──────────────────────────────────────────────────────────────
 *   1   启动前    系统启动窗口（模糊桌面）—— 还没进 app        （系统）
 *   2   ~0.02    纯墨蓝底 + 几颗星                             L0+L2
 *   3   ~0.10    星尘铺开，OM 还没到                            L1+L2
 *   4   ~0.35    **OM 完整**（金环四段高光 + 金点 + M），无标题  L3+L4
 *   5   ~0.55    OM + 「One More」+ 金线                        L6
 *   6   ~0.62    同上，整体更亮一点                             L5/L6
 *   7   ~0.72    「355 款小游戏」+「碎片时间，随时开局」          L7+L8
 *   8   ~0.85    全亮，开始淡出                                 L9
 *
 *   ★ 读这组帧得到的两条事实（比注释更可信，因为是量出来的）：
 *   ① **OM 全程在正中**，没有横向位移 —— 它的动效是
 *      「亮度 + 一个极小的 y（金点升起 0.0629 倍 OM 高）」，
 *      不是"从旁边滑进来"。
 *      （我一度看缩略图以为它在右侧滑入 —— 看原图才纠正。）
 *   ② **第 4 帧已经 OM 完整但标题还没到**，中间有约 200ms 的"只有标志"的
 *      留白 ⇒ 这正是"标志落定 → 标题被金线托住"两拍节奏的来源。
 *
 *   ⚠️ 抓帧方法（设备端每张截图 300–500ms，串行抓 8 帧会超过开屏时长）：
 *      用「分两次启动 + 错开相位（0.05s / 0.75s），每次抓 4 帧」⇒ 8 帧全不同。
 *
 * ── 层级（从后到前）────────────────────────────────────────────────
 *   L0 底色            纯色，兜底，绝不留白
 *   L1 星云            径向渐变，慢、虚，做"有天光"的感觉
 *   L2 星尘            **24 颗**，三组不同速度（视差）
 *                      ⇒ 复算：`grep -c '\[[0-9.]*, [0-9.]*, [0-9.]*\]' Splash.ets` 里 STARS 数组的三元组数
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
 *   星尘总数 **24**（三组各 8 颗）；极小屏（`tiny`）只渲染前 **16** 颗
 *   ⇒ 复算：`STARS.length` = 24 ｜ `STARS_TINY` = 16
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
const TOTAL: number = 2270;
const HOLD: number = 2230;

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
// 极小屏只保留前 16 颗（STARS 共 24 颗 = 8+8+8；再减到 16 更省）
const STARS_TINY: number = 16;

/**
 * ★★★ 2026-11-01 金属高光的「三层同心弧」参数（模块级常量 —— ArkTS 严格模式下
 *   内联数组字面量 + 索引会被判成逗号表达式，报 `arkts-no-comma-outside-loops`）。
 *
 *   起因：原来每段高光的 strokeWidth = 整个环宽 ⇒ 必然读作「一块」而不是「一道受光」。
 *   圆头实验（gl_07）证明「放大面积只会更糟」。
 *   ⇒ 三层同心弧（外宽内窄、中层最亮）叠出**横跨环宽方向的亮→更亮→暗**，
 *     这是环面正面受光的真实分布。
 */
const GLINT_STROKE: string[] = ['#E8CE96', '#FFF0CE', '#F5DFB0'];
const GLINT_WIDTH: number[] = [0.115, 0.055, 0.022];
const GLINT_SCALE: number[] = [1.0, 0.955, 0.915];
const GLINT_ALPHA: number[] = [0.55, 0.95, 0.30];
const GLINT_PHASE: number[] = [0.85, 0.40, 0.15, 0.40];

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

  /**
   * ★★★ 2026-11-01 真机 hilog 抓到：逐字入场**实际没生效**。
   *   证据（探针 charIn 打点）：
   *     char[0] first>0 at 907 ms
   *     char[7] first>0 at 914 ms   ⇒ 8 个字只差 7ms，等于同时出现
   *   根因：pTitle 用 `settle()` = cubicBezier(0.22, **1.0**, 0.36, 1.0)，
   *         y1=1.0 ⇒ 前 22% 时间就冲完大部分进度，121ms 内跨过 0.45，
   *         而 8 个字的 start 分别是 0 / 0.064 / 0.129 … / 0.45 ⇒ **一次跨完**。
   *   ⇒ pTitle 只是"逐字的时间轴"，视觉曲线由 charIn 内部的 smoothstep 提供，
   *     所以时间轴本身必须**起点慢**（对称 ease-in-out），偏移才有意义。
   *   ★ 不用 Linear：判据⑨要求主线不用匀速；而这里用对称贝塞尔，
   *     既给了"字与字之间的间隔"，又保留了"整体先慢后稳"的呼吸。
   */
  private titleClock(): ICurve {
    return curves.cubicBezierCurve(0.55, 0.0, 0.45, 1.0);
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
    // ★★★★★ 2026-11-01 架构级修复（第 797 轮）
    //
    //   上一轮的教训：`animateTo` 只把**渲染属性**在原生侧插值，
    //   **@State 的 JS 值只在起、终各变一次**。
    //   而这一屏 15 个进度值**全部**参与 JS 计算（seg / starDrift / translate…），
    //   ⇒ 实测帧间差出现 0（600ms 内画面完全没变）⇒ 整屏其实是"几张静态画面"。
    //
    //   修法：**一个 16ms 的 ticker 统一推进全部 15 个进度值**。
    //   · 每个值有自己的 (起始延迟, 时长, 曲线类型)，照原时间表原样搬过来；
    //   · 每步赋值都是 @State 变更 ⇒ 真的触发 build ⇒ 所有 JS 计算拿到真实中间值；
    //   · 曲线两类：`lin` 线性（星尘漂移 / 金属高光旋转 —— 该匀速的才匀速）、
    //              `sm` smoothstep e²(3−2e)（其余全部，等效 ease-in-out）。
    const T0: number = Date.now();
    const tick = setInterval(() => {
      // ★ 点屏幕加速：直接把时间轴顶到终点（等价于旧版把值硬置 1 的观感）
      //   区别：现在是「时间轴到头」而不是「逐个字段硬写」，逻辑只有一个入口。
      const t: number = this.boosted ? TOTAL : (Date.now() - T0);
      const lin = (st: number, dur: number): number => {
        const e: number = (t - st) / dur;
        return e <= 0 ? 0 : (e >= 1 ? 1 : e);
      };
      const sm = (st: number, dur: number): number => {
        const e: number = (t - st) / dur;
        if (e <= 0) { return 0; }
        if (e >= 1) { return 1; }
        return e * e * (3 - 2 * e);
      };
      // ★ 2026-11-01（第 804 轮）：底与星云都提前，别让观众先看 600ms 虚空。
      //   实测 8 帧里第 2/6/7 帧几乎只有几颗点时，就是这段空窗（pNebula 要到 630ms 才满）。
      //   世界顶尖开屏不会让第一屏是空的 —— 一上来就该有「天光」。
      this.pBg = sm(0, 240);
      this.pNebula = sm(0, 380);
      this.pDust = lin(170, 2600);
      this.pTwinkle = sm(170, 2100);
      this.pGlow = sm(200, 600);
      this.pStroke = sm(280, 980);
      this.pSun = sm(280, 420);
      this.pGlint = lin(280, 520);
      this.pM = sm(350, 460);
      this.pFill = sm(600, 440);
      this.pSweep = sm(740, 520);
      this.pTitle = sm(820, 550);
      this.pSub = sm(1050, 300);
      this.pTag = sm(1180, 300);
      this.pOut = sm(1950, 320);
      if (t >= TOTAL) {
        clearInterval(tick);
        this.pBg = 1; this.pNebula = 1; this.pDust = 1; this.pTwinkle = 1;
        this.pGlow = 1; this.pStroke = 1; this.pSun = 1; this.pGlint = 1;
        this.pM = 1; this.pFill = 1; this.pSweep = 1; this.pTitle = 1;
        this.pSub = 1; this.pTag = 1; this.pOut = 1;
      }
    }, 16);
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
    // ★★★ 点屏幕加速（2026-11-01 第 800 轮定稿）
    //
    //   演进过程（值得记住，因为踩了两次）：
    //   ① 初版：`animateTo(240ms, () => { 11 个值 = 1 })`
    //      ⇒ 换成 ticker 后**完全失效** —— 主驱动每 16ms 会把这些值拉回去。
    //   ② 第 799 轮：给时间轴加 boostOffset 跳 370ms
    //      ⇒ 生效但只快 0.4 秒（实测 2.4s vs 2.8s），**用户感知不到**。
    //   ③ 第 800 轮（本版）：`boosted = true` ⇒ ticker 里 `t = boosted ? TOTAL : ...`
    //      ⇒ 下次 tick 直接把时间轴顶到终点，15 个值一起到 1（"啪"一下，与旧观感一致）
    //      ⇒ 240ms 后 finish()。
    //
    //   ★ 为什么现在是"一个入口"：加速不再是"另写一套赋值"，
    //     而是"让时间轴瞬间走完" —— ticker 是唯一写入者，boost 只改它的输入。
    setTimeout(() => {
      this.finish();
    }, 240);
  }

  /** 星尘可见性：极小屏减半 */
  /**
   * ★★★ 2026-11-01：**景深的后半句 ——「远景虚、近景实」原来没做**。
   *   查代码发现：所有 24 颗星尘共用同一个 `.blur(this.tiny ? 0 : 0.4)`，
   *   ⇒ 远景星和近景星**一样清晰** ⇒ 只有"三组不同速度"（视差），没有"虚/实"分档。
   *   而 `STARS` 的数组已经按组排好（0~7 远景 / 8~15 中景 / 16~23 近景），
   *   半径也是远小近大（1.2~1.8 / 2.2~2.9 / 3.0~3.9）⇒ 只差模糊这一档。
   *
   *   ⇒ 远景模糊 1.4vp、中景 0.6vp、近景 0（实）：
   *     视觉上远景是"雾里的光点"，近景是"清晰的亮点"，中景过渡。
   *   ★ 极小屏一律 0 —— 屏幕太小，模糊只会让星点消失（等于没做，见 grain 的教训）。
   */
  private starBlur(i: number): number {
    if (this.tiny) {
      return 0;
    }
    if (i < 8) {
      return 1.4;      // 组 0 远景：虚
    }
    if (i < 16) {
      return 0.6;      // 组 1 中景：微虚
    }
    return 0;          // 组 2 近景：实
  }

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
        // ★ 2026-11-01（第 804 轮）：星云一开始就要**有底**，不能从 0 起。
        //   实测 z3/z4 两帧是**全屏单色 (13,19,33)** —— 一点渐变都没有，
        //   因为 opacity = pNebula × 0.95 且 pNebula 从 0 开始 ⇒ 前 380ms 是纯色。
        //   世界顶尖开屏的第一帧就该有「天光」（径向渐变的层次），不是一块平色。
        //   ⇒ 底层给 0.35 的常驻，剩下 0.60 由 pNebula 补上。
        .opacity(0.35 + this.pNebula * 0.60)

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
          .blur(this.starBlur(i))
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

          // ── ①a 环面明暗（2026-11-01 新增）──
          //   ★ 真机像素测量：环身实测左 RGB(146,119,74) / 右 RGB(154,126,78)，
          //     差只有 3%（那是外发光溢出）⇒ **环是纯平色，没有渐变**。
          //   ★ 金属环（torus）的受光沿**环宽方向**变化：外缘凸起受光 → 内缘收暗。
          //     做法：在主管上加两条极细的同心弧 ——
          //       外缘 #E2BE74（亮）/ 内缘 #A87C3E（暗），各占环宽的 14%。
          //     这样"边缘亮、内侧沉"，读起来才有厚度。
          //   几何：主管直径 0.4818、环宽 0.1276 ⇒ 环跨半径 0.1771~0.3037；
          //         圆心 (0.2409, 0.0262+0.2409)。
          Circle()
            .width(this.omPxV() * 0.6074).height(this.omPxV() * 0.6074)
            .fill(Color.Transparent)
            .stroke('#E2BE74')
            .strokeWidth(this.omPxV() * 0.0180)
            .position({ x: this.omPxV() * -0.0628, y: this.omPxV() * -0.0366 })
            .opacity(this.seg(this.pStroke, 0.001, 0.10) * 0.55)
          Circle()
            .width(this.omPxV() * 0.3542).height(this.omPxV() * 0.3542)
            .fill(Color.Transparent)
            .stroke('#A87C3E')
            .strokeWidth(this.omPxV() * 0.0180)
            .position({ x: this.omPxV() * 0.0638, y: this.omPxV() * 0.0900 })
            .opacity(this.seg(this.pStroke, 0.001, 0.10) * 0.55)

          // ── ①b 金属高光：4 段绕环旋转（研究报告 P2-1）──
          //   ★ 金的「贵」来自**会动的高光**，不是金色本身。
          //   ★ 这是全片唯一该用 Linear 的地方：金属反射本就匀速。
          //   做法：4 个同尺寸 Circle，各带一段 dash，初相 0/90/180/270，
          //        整组 rotate 0→90 ⇒ 读作"光在环上走"。
          //
          // ★★★ 2026-11-01 **三层同心弧**（外宽内窄、中层最亮）：
          //   起因：原来每段 `strokeWidth` = 整个环宽（0.1276）⇒ 必然读作「一块」，
          //        而不是「一道受光」。圆头实验（gl_07）也证明"放大面积只会更糟"。
          //   ⇒ 三层叠出**横跨环宽方向的亮→更亮→暗**，这才是环面（torus）正面受光的分布。
          //
          //   ⚠️ 踩过的坑（别再试）：**不能用嵌套 ForEach**
          //      （`ForEach([0,1,2], layer => ForEach([0,1,2,3], i => ...))`）
          //      ArkTS 严格模式直接报 61 个错（arkts-no-comma-outside-loops 等）。
          //   ⇒ 必须写成**三个并列的 ForEach**，各自用字面量索引 layer 常量。

          // 外层：贴外缘，暗而宽
          ForEach([0, 1, 2, 3], (i: number) => {
            Circle()
              .width(this.omPxV() * 0.4818).height(this.omPxV() * 0.4818)
              .fill(Color.Transparent)
              .stroke('#E8CE96')
              .strokeWidth(this.omPxV() * GLINT_WIDTH[0])
              .strokeDashArray([this.omPxV() * 0.0832, this.omPxV() * 1.5140])
              // ★★★ 2026-11-01 真机放大看到：`-0.3785 * i` = **每 90° 一个 20° 弧**，
              //   读作「四个等分的装饰条」，不像环面受光。
              //   ⇒ 改成 **每 17° 一段（略重叠）** ⇒ 四段连成一条 ~68° 的**连续高光带**，
              //     随 pGlint 旋转 ⇒ 是「一束光扫过环面」，这才是金属环的正确读法。
              .strokeDashOffset(-this.omPxV() * 0.0710 * i)
              .scale({ x: GLINT_SCALE[0], y: GLINT_SCALE[0] })
              .rotate({ angle: this.pGlint * 90 })
              .opacity(this.pGlint * GLINT_ALPHA[0] * GLINT_PHASE[i])
              .position({ x: this.omPxV() * 0.0, y: this.omPxV() * 0.0262 })
          }, (i: number) => 'glint0_' + i)

          // 中层：最亮（受光峰值）
          ForEach([0, 1, 2, 3], (i: number) => {
            Circle()
              .width(this.omPxV() * 0.4818).height(this.omPxV() * 0.4818)
              .fill(Color.Transparent)
              .stroke('#FFF0CE')
              .strokeWidth(this.omPxV() * GLINT_WIDTH[1])
              .strokeDashArray([this.omPxV() * 0.0832, this.omPxV() * 1.5140])
              .strokeDashOffset(-this.omPxV() * 0.0710 * i)
              .scale({ x: GLINT_SCALE[1], y: GLINT_SCALE[1] })
              .rotate({ angle: this.pGlint * 90 })
              .opacity(this.pGlint * GLINT_ALPHA[1] * GLINT_PHASE[i])
              .position({ x: this.omPxV() * 0.0, y: this.omPxV() * 0.0262 })
          }, (i: number) => 'glint1_' + i)

          // 内层：窄而柔（向环心收）
          ForEach([0, 1, 2, 3], (i: number) => {
            Circle()
              .width(this.omPxV() * 0.4818).height(this.omPxV() * 0.4818)
              .fill(Color.Transparent)
              .stroke('#F5DFB0')
              .strokeWidth(this.omPxV() * GLINT_WIDTH[2])
              .strokeDashArray([this.omPxV() * 0.0832, this.omPxV() * 1.5140])
              .strokeDashOffset(-this.omPxV() * 0.0710 * i)
              .scale({ x: GLINT_SCALE[2], y: GLINT_SCALE[2] })
              .rotate({ angle: this.pGlint * 90 })
              .opacity(this.pGlint * GLINT_ALPHA[2] * GLINT_PHASE[i])
              .position({ x: this.omPxV() * 0.0, y: this.omPxV() * 0.0262 })
          }, (i: number) => 'glint2_' + i)

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
          //   ⚠️ 2026-10-30 三次想给 M "加质感"，三次都失败，都回滚了：
          //     ① linearGradient + maskShape → **M 完全消失**（当时误判为 maskShape 的问题）
          //     ② 拆成三块刻面（色差 1~2% 亮度）→ 深色背景上被对比度放大，
          //        读作"M 右半边脏了"，不是"受光"
          //     ③ 第 561 轮**单独验证** linearGradient（不加 maskShape，四组角度对照）
          //        ⇒ 真机结果：**Polygon 上它会画一个矩形背景，不是填充 M 的形状**
          //        （PROBE_polygon_gradient_is_rect.jpeg：白底方块里有个浅色 M）
          //        ⇒ **这才是①失败的真正原因** —— maskShape 只是把那个矩形遮掉了。
          //
          //   ★★ 结论（机制层面，不是参数层面）：
          //     **`linearGradient` 在 Polygon 上不填充路径，只铺矩形背景。**
          //     换角度、换方向、换颜色都没用 —— 这条路在当前 ArkUI 上是死的。
          //     ⇒ M 只能用**单一纯色**。这也与应用图标一致，是设计上的正确答案。
          //
          //   ★ 而且前两次我都是直接改主视觉（犯同一个错三次）。
          //     正确顺序永远是：先在 XxxTest.ets 里看清效果，再往 OM 上套。
          //     第 561 轮照做了 —— 代价 1 次建页 + 1 次 build，零破坏。
          //   「渐变」这一项在本项目当前 ArkUI 上无解（见台账第 522 轮，四条路全堵死）。
          //
          //   几何（归一化到 1000 宽）：
          //     左底(0,496.1) 左峰(94.5,0) 谷(252.0,351.2) 右峰(417.3,0) 右底(507.1,496.1)
          // ★★★ 2026-11-03（第 1030 轮）**M 的形态：两次尝试都失败，已回滚**
          //   奥森：「O和M的大小好像差太多了？」
          //   实测（960×540 真机，改前）：O 环 544×544 ｜ M 三角 **958×552**
          //     · M 高 / O 高 = **1.015**（设计值 0.4961）⇒ 高度正常
          //     · M 宽 / O 宽 = **1.761**（设计值 0.5071）⇒ **宽了 76%**
          //     · M 自己 宽/高 = **1.736**（设计值 1.022）⇒ **被横向拉伸 70%**
          //   尝试①：**去掉 `.width()/.height()`，只给 points**
          //     ⇒ 真机结果：**M 完全消失**（Polygon 无尺寸 ⇒ 不渲染）⇒ 回滚
          //   尝试②（未做）：把 points 改成归一化 0~1 + 保留 width/height
          //     ⚠️ 台账 522/561 轮记录：`Polygon` 上 `linearGradient` 只铺矩形不填路径，
          //        但**归一化 points + width/height** 与"渐变"是两件事，未试过，仍可试
          //   ⇒ **当前保持原样（M 偏宽 76%），这是已知遗留，不是新 bug。**
          // ★★★ 2026-11-03（第 1044 轮）**奥森：「O 和 M 大小差别还是很大」**
          //   设计值实测：M 高 = omPxV × 0.4961，而 O 外径 = omPxV × 0.6074
          //     ⇒ **M 高 / O 外径 = 0.817** ⇒ M 只有 O 的 **81.7%**
          //   而且 O 是**镂空圆环**、M 是**实心三角** ⇒ 视觉重量差得更多
          //   ⇒ 放大 **×1.2244**（= 0.6074 / 0.4961），让 **M 高与 O 外径齐平**
          //     · points 的归一化坐标与 width/height **按同一系数缩放**（保持设计值一致）
          //     · M 起点(0.4929)不变 ⇒ 右边缘到 0.4929 + 0.5071×1.2244 = **1.1136**
          //       ⇒ logo 总宽从 1.000 变 **1.114 × omPxV**（仍在屏宽占比内，见验算）
          Polygon()
            .width(this.omPxV() * 0.6207).height(this.omPxV() * 0.6074)
            .points([
              [0, this.omPxV() * 0.6074],
              [this.omPxV() * 0.1157, 0],
              [this.omPxV() * 0.3085, this.omPxV() * 0.4300],
              [this.omPxV() * 0.5109, 0],
              [this.omPxV() * 0.6207, this.omPxV() * 0.6074]
            ])
            .fill('#FAF8F3')
            // 2026-11-01 device pixel measure: O bottom y=1104, M bottom y=1046
            // => M sits 58px (14% of ring height) too high; code math says only 10px.
            // => reversible experiment: shift M down by 0.056 x omPxV, measure again.
            // ★★★ 2026-11-03（第 1046 轮）**奥森：「M 和下面的 More 连到一起了」
            //   而且「O 和 M 的上下边框要在同一水平线上」**
            //   根因：上一轮把 M 高度从 **0.4961 → 0.6074**，但 **y 还是 0.0757**
            //     ⇒ M 底边 = 0.0757 + 0.6074 = **0.6831**
            //     ⇒ 而 O 视觉底边 = **0.5718**（见下方 2026-11-01 的推导）
            //     ⇒ 低出 **0.1113 × omPxV** ⇒ **正好撞进标题「One More」** ⇒ 连成一片
            //   ⇒ 用同一条对齐公式重算：y = 0.5718 − 0.6074 = **−0.0356**
            //     · M 底边 = −0.0356 + 0.6074 = **0.5718** = O 底边 ✅
            //     · M 顶点 = −0.0356；O 视觉顶点 = 0.0262 − 0.1276/2 = **−0.0376**
            //       ⇒ 顶边只差 **0.002 × omPxV**（≈0.4vp）⇒ 视觉上齐平 ✅
            // ★★★ 2026-11-03（第 1067 轮）**奥森：「O 和 M 连到一起啦」**
            //   算账：O 圆环 position x=0、直径 0.4818、描边 0.1276
            //     ⇒ O 视觉右边缘 = 0 + 0.4818 + 0.1276/2 = **0.5456**
            //   而 M 起点原来是 **0.4929**
            //     ⇒ **0.4929 < 0.5456** ⇒ M 左边缘插进 O 里 **0.0527 × omPxV**（5.3%）
            //     ⇒ 视觉上"O 和 M 粘在一起"
            //   ⇒ 修：M 起点 = 0.5456 + **0.0100**（留一点呼吸间隙）= **0.5556**
            //     · logo 总宽 1.1136 → **1.1763**（增 5.6%）
            //     · 六尺寸新占宽：59.1% / 42.4% / 59.1% / 72.3% / 72.3% / 37.7%
            //       ⇒ 全部 < 92% ⇒ 仍放得下
            // ★★★ 2026-11-03（第 1070 轮）**间隙从 0.0100 提到 0.0150**
            //   实测发现：0.0100 的间隙「被抗锯齿吃掉大半」
            //     960×540：理论间隙 3.07 vp，但 O 的抗锯齿外扩约 2.3 vp
            //       ⇒ **信噪比 1.33** ⇒ 视觉上"缝很淡"，仍可能被读成"粘着"
            //     233×233：理论间隙 1.43 vp，抗锯齿约 1.0 vp
            //       ⇒ **信噪比 1.43** ⇒ 同样临界
            //   ⇒ 提到 **0.0150**（M 起点 0.5456 + 0.0150 = **0.5606**）
            //     · 960 上间隙 4.6 vp ⇒ 信噪比 **2.0**
            //     · 233 上间隙 2.15 vp ⇒ 信噪比 **2.15**
            //     ⇒ 两个尺寸都达到「信噪比 ≥ 2」的工程安全值
            //   ⇒ 判据 347：阈值判断要给信噪比，比值 < 2 就是临界 ⇒ 不能交货
            .position({ x: this.omPxV() * 0.5606, y: this.omPxV() * -0.0356 })
            // ★★★ 2026-11-01 第二版（理论驱动，不是试参数）：
            //   O 是 Circle + strokeWidth，stroke 画在 width 边界上、一半在外 ⇒
            //     O 视觉底边 = 0.0262(位置) + 0.4818(直径) + 0.1276/2(半描边) = 0.5718
            //   M 的底边 = y + 0.4961（points 里最大 y）
            //   ⇒ 对齐要求 y = 0.5718 - 0.4961 = 0.0757
            //   （上一版 0.0560 是试出来的，比例 2.7:1 不成正比，因为漏算了半描边）
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
              // ★★★ 2026-11-02（第 883 轮）**手表 233×233 真机抓到**：
              //   tiny 档原来是 fontSize 26 + letterSpacing 4，
              //   8 个字（含空格）实测宽度 = 26×8 + 4×7 = **236vp > 屏幕 233vp**
              //   ⇒ 真机截图里「One More」的右侧 "re" 被裁出屏幕外。
              //   ⇒ 改成 21 + 1.5 ⇒ 21×8 + 1.5×7 = **178.5vp**，留 54vp 余量。
              .fontSize(this.tiny ? 21 : this.titlePx)
              .fontWeight(FontWeight.Bold)
              .fontColor(OM_CREAM)
              .letterSpacing(this.tiny ? 1.5 : 6)
              .opacity(this.charIn(i, 8))
              .translate({ y: (1 - this.charIn(i, 8)) * (this.tiny ? 8 : 16) })
              .blur((1 - this.charIn(i, 8)) * (this.tiny ? 6 : 10))
          }, (ch: string, i: number) => 'c' + i + ch)
        }
        .margin({ top: this.tiny ? 6 : (this.vh > 0 && this.vh < 620 ? 12 : 40) })

        // ═══ 金线（2026-10-30 新增 · 在临时页 TitleTest 里先验过）═══
        //   研究报告的「轮廓先行」思路，落不到 dash 上（见第 503 轮实测），
        //   但**可以用一条金线的展开来达成同样的"成形感"**：
        //     线从中间向两边长出来，标题在这条线的"上方"被托住
        //   ⇒ 读起来是"标志落定 → 一条基线承住它"，而不是"文字淡入"。
        //
        //   为什么用 `Divider` 而不是 `Rect`/`Line`：
        //     临时页里 `Divider().strokeWidth(2).color(...).width(...)` 一次就成
        //     （`Rect` 要管 fill/height，`Line` 的坐标语义更容易踩坑）。
        //
        //   ★ 时序：线比标题晚 120ms 起、但更早完成（0.42→0.78 vs 标题 0.30→0.72）
        //     ⇒ 视觉上是"标题先到、线随即把它承住"，不是"线先画完再放标题"。
        //   ★ 极小屏（手表）不画线：那里宽度只有 ~110vp，一条线会显得局促。
        if (!this.tiny) {
          Row() {
            Divider()
              .strokeWidth(2)
              .color('#C99E52')
              // 线宽：从 0 长到标题宽的约 1.15 倍（略宽于文字，视觉上才"托得住"）
              .width(this.seg(this.pTitle, 0.42, 0.78) * this.titlePx * 5.6)
              // 线本身也淡入，避免"啪"地出现
              .opacity(this.seg(this.pTitle, 0.42, 0.62) * 0.85)
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: this.vh > 0 && this.vh < 620 ? 4 : 10 })
        }

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
      // ★★★ 2026-11-01 真机 195×195 抓到：**logo 顶距状态栏只有 2px（0.7vp）**，
      //   原因：tiny 下 `padding bottom 34` 把内容往上推 + `translate -6` 再推 ⇒
      //   整体上移约 23vp，而 195vp 的屏幕只有 195 高 ⇒ 顶到状态栏。
      //   但 ultraTiny 时**副标题与标语都已隐藏**（见 pSub / pTag 的 opacity 分支），
      //   那 34vp 的底部留白本来就是空的 ⇒ ultraTiny 下收到 10vp。
      .padding({ bottom: this.ultraTiny ? 10 : (this.tiny ? 34 : 0) })
      .translate({ y: this.ultraTiny ? 0 : (this.tiny ? -6 : -14) })
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
      //   ★ 2026-11-01 真机自检抓到：原来只有 **10 颗 1.8vp** 的点，
      //     #16FFFFFF（8.6% 白）⇒ 在 440×744 上覆盖率约 0.006%，
      //     **真机截图里根本看不出颗粒感** —— 等于没做这一层。
      //   ⇒ 提到 60 颗，且大小 / 透明度 / 位置全部伪随机（线性同余），
      //     读起来才是"胶片噪点"，不是"10 个能数出来的点"。
      //   ★ 仍然不生成噪点贴图（60 个纯色小圆的开销远小于一张全屏 PNG）。
      // ★ 2026-11-03（第 1002 轮）**60 → 200**：60 颗时覆盖率仅 0.35%，
      //   实测背景块 `std` 中位 1.1~1.8（还是暗角渐变贡献的）⇒ 颗粒等于不存在。
      //   200 颗 ⇒ 覆盖率 ≈ 1.2%，单颗仍弱（不脏），总量可感知。
      ForEach(Array.from({ length: 200 }, (v: number, i: number) => i), (i: number) => {
        Column()
          .width(this.tiny ? 1.0 + (i * 7 % 11) * 0.08 : 1.2 + (i * 7 % 11) * 0.10)
          .height(this.tiny ? 1.0 + (i * 7 % 11) * 0.08 : 1.2 + (i * 7 % 11) * 0.10)
          .borderRadius(99)
          // 透明度 5%~13% 之间伪随机 —— 有明有暗才像噪点
          .backgroundColor((i * 13 % 9) > 4 ? '#17FFFFFF' : '#0DFFFFFF')
          .position({
            x: (((i * 37 + 11) % 100)) + '%',   // ★ 第 1002 轮：绝对 vp → 百分比（原来在 233 上跑出屏幕）
            y: (((i * 61 + 23) % 100)) + '%'   // ★ 第 1002 轮：同上
          })
          .opacity(this.pBg * 0.75)
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
    // ★★★ 2026-11-03（第 1004 轮）**真 bug：开屏顶部 37vp 露白**
    //   440×300 实测：y 0~112 px（= 37.3 vp，正好状态栏高）全是白色（均值 157），
    //   而 y 112 以下是 OM_INK（均值 30）。⇒ 开屏的根 Stack 没延伸到状态栏区域。
    //   233/195 上看不到，因为手表没有状态栏。
    //   ⇒ 加 `expandSafeArea`：开屏是全屏动画，必须盖住状态栏与导航栏。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
        // ★★★ 2026-11-03（第 1035 轮）**运动手表 195×195 上开屏 logo 比屏幕还宽**
        //   验算：om = max(**96**, min(150, 195 × 0.245 = 47.8)) = 96
        //         ⇒ omPxV = 96 × 2.05 = **196.8 > 屏宽 195** ⇒ 占宽 **100.9%**
        //         ⇒ 竖向也溢出：logo 高 + 标题 + 副标题 ≈ 225 > 195
        //   根因：**下限 96 在极小屏上比"按宽度算出来的值"还大** ⇒ clamp 反过来放大了它。
        //   ⇒ 下限降到 **50**（195 × 0.245 = 47.8 ⇒ om = 50 ⇒ omPxV = 102.5 ⇒ 占宽 52.6%）
        //   ⚠️ 不用 96 是因为：手表屏只有 195vp，96 已经接近半屏；
        //     而 233 的方块屏上 96 是合适的（233 × 0.245 = 57.1 ⇒ 仍取下限 96？）
        //     ⇒ 见下：改成**按宽度缩放的软下限**，保留大屏的手感。
        const omFloor: number = Math.max(50, Math.min(96, w * 0.30));
        const om: number = Math.max(omFloor, Math.min(cap, w * 0.245));
        // ★★★ 2026-11-03（第 1036 轮）**字号也有同一个坑（判据 320 的同伙）**
        //   195×195 实测验算：ti = max(**38**, min(104, 195 × 0.098 = 19.1)) = **38**
        //     ⇒ 标题「One More」8 字符 × 0.62 × 38 = **188 vp / 屏宽 195 = 96.7%**
        //     ⇒ **几乎贴边**（233 手表上也是 80.9%，同样偏挤）
        //   ⇒ 和 om 一样的修法：**硬下限改成随宽度缩放的软下限**
        //     ti：max(24, min(38, w*0.16))  ⇒ 195→31.2（79.3%）｜233→37.3（79.4%）｜440+ 仍 38
        //     su：max(7,  min(11, w*0.055)) ⇒ 195→10.7 ｜233→11（不变）
        //     tg：max(6,  min(10, w*0.048)) ⇒ 195→9.4  ｜233→10（不变）
        //   ⚠️ 大屏完全不受影响：w*0.16 ≥ 38 当 w ≥ 238，而 440+ 本来 ti ≥ 43
        const tiFloor: number = Math.max(24, Math.min(38, w * 0.16));
        const suFloor: number = Math.max(7, Math.min(11, w * 0.055));
        const tgFloor: number = Math.max(6, Math.min(10, w * 0.048));
        const ti: number = Math.max(tiFloor, Math.min(104, w * 0.098));
        const su: number = Math.max(suFloor, Math.min(28, w * 0.027));
        const tg: number = Math.max(tgFloor, Math.min(24, w * 0.023));
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
