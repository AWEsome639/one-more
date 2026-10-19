/**
 * SparkBurst —— 庆祝粒子爆发（「动画拉满」新增维度）
 *
 * 为什么要它：
 *   胜利/解锁这一刻是全应用情绪最高点。原来这里只有一个 🎉 表情，
 *   空间上没有任何爆发感。
 *   Apple 那种质感的关键不在"多"，而在三件事：
 *     ① 从一点向四周散开（有物理因果，不是凭空出现）
 *     ② 越远越淡、越远越小（景深）
 *     ③ 每颗粒子的出发时间与轨迹都不同（没有"整齐划一"的机器感）
 *
 * 架构：跟开屏同一套 —— 一个 0→1 的进度，所有粒子从它算出来
 *   ⇒ 调用方只需要 animateTo 推这个进度，粒子的每一帧都对
 *
 * 为什么用 Canvas 而不是 ForEach + Circle：
 *   20+ 个 Circle 每帧改 translate/opacity ⇒ 20+ 个组件重排
 *   Canvas 只有 1 个组件，一帧画完 ⇒ 同样的画面，成本低一个数量级
 *
 * 用法：
 *   SparkBurst({ progress: this.burstP, count: 22, spread: 150 })
 *   animateTo({ duration: 900, curve: Curve.EaseOut }, () => { this.burstP = 1; })
 *
 * 拾海 2026-10-19
 */

/** 一颗粒子的固定参数（只算一次，之后只随进度变化位置） */
interface Spark {
  angle: number;    // 出发角度（弧度）
  dist: number;     // 半径系数 0.55 ~ 1.00
  size: number;     // 初始直径 vp
  delay: number;    // 相位偏移 0 ~ 0.24
  gold: boolean;    // 金色 or 象牙白
}

/** 把 x 夹到 [0, 1] */
function clamp01(x: number): number {
  if (x <= 0) {
    return 0;
  }
  return x >= 1 ? 1 : x;
}

@Component
export struct SparkBurst {
  /** 爆发进度 0 → 1，由外部 animateTo 驱动 */
  @Prop @Watch('redraw') progress: number = 0;
  /** 粒子数量 */
  @Prop count: number = 22;
  /** 扩散半径（vp） */
  @Prop spread: number = 150;
  /** 主色（金） */
  @Prop goldColor: string = '#E8C97C';
  /** 辅色（象牙白） */
  @Prop creamColor: string = '#FAF8F3';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private sparks: Spark[] = [];

  aboutToAppear(): void {
    const arr: Spark[] = [];
    for (let i = 0; i < this.count; i++) {
      arr.push({
        // ★ 黄金角 137.508° 散开 —— 相邻粒子永不共线，看起来是"自然散落"而不是"排好的"
        angle: ((i * 137.508) % 360) * Math.PI / 180,
        dist: 0.55 + ((i * 37) % 45) / 100,
        size: 2.6 + ((i * 13) % 5) * 0.9,
        delay: ((i * 53) % 25) / 100,
        gold: i % 3 !== 0
      });
    }
    this.sparks = arr;
  }

  /** 进度一变就重绘（@Watch 触发） */
  redraw(): void {
    this.draw();
  }

  private draw(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, w, h);

    const cx: number = w / 2;
    const cy: number = h / 2;
    const p: number = clamp01(this.progress);

    for (let i = 0; i < this.sparks.length; i++) {
      const s: Spark = this.sparks[i];
      // 每颗按自己的相位错开 ⇒ 不是"同时炸开"，而是"陆续飞出"
      const t: number = clamp01((p - s.delay) / (1 - s.delay));
      if (t <= 0) {
        continue;
      }
      // 三次方缓出：出手快、后段拖尾 ⇒ 空气阻力的感觉
      const e: number = 1 - Math.pow(1 - t, 3);
      const r: number = s.dist * this.spread * e;
      const x: number = cx + Math.cos(s.angle) * r;
      const y: number = cy + Math.sin(s.angle) * r;
      // 前 15% 淡入（从无到有），之后一路淡出
      const fadeIn: number = clamp01(t / 0.15);
      // 2026-10-19 真机修：原来 0.95 太实，粒子落在文字/按钮上看着脏
      //   => 降到 0.72：还是亮的，但能透出下面的字
      const alpha: number = fadeIn * (1 - t) * 0.72;
      if (alpha <= 0.01) {
        continue;
      }
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = s.gold ? this.goldColor : this.creamColor;
      this.ctx.beginPath();
      // 越远越小 ⇒ 景深
      this.ctx.arc(x, y, s.size * (1 - t * 0.55), 0, Math.PI * 2);
      this.ctx.fill();
    }
    this.ctx.globalAlpha = 1;
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw();
      })
      .hitTestBehavior(HitTestMode.None)
  }
}
