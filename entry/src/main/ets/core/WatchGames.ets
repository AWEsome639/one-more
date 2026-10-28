/**
 * WatchGames —— 手表上"精选支持"的游戏清单
 *
 * ★★★ 为什么要有这个文件（2026-10-29，项目 F 阶段 3）
 *
 *   奥森要六种设备全支持，但手表是 **466×466 圆形屏**：
 *   · 内切正方形只有约 330×330 —— 数独/象棋/五子棋这类棋盘根本放不下
 *   · 没有键盘、字很小、滚不动长列表
 *   ⇒ **355 款全塞进手表 = 355 个坏体验**
 *
 *   所以这里做的是**诚实的取舍**：
 *   手表上只放"纯点按、无大棋盘、无长文本、单屏能玩完"的款，
 *   其余的在手表上**不显示**（而不是显示一个点不动的坏界面）。
 *
 * ★ 收录标准（必须同时满足）
 *   ① 纯点按：不需要拖拽/长按/多指
 *   ② 无大棋盘：格子数 ≤ 12，或只用列布局
 *   ③ 短文本：标题 + 一句话能说清
 *   ④ 单局短：30 秒~2 分钟能玩完
 *
 * ★ 怎么扩
 *   想加一款：先在手机上把它玩一遍，问自己「466px 圆屏上还看得清吗」，
 *   看得清就加进这个表，然后**在手表上真机验一遍**。
 *   验不过就撤掉 —— 加进来而不验，等于骗自己。
 */
export class WatchGames {
  /**
   * 手表支持的游戏 id 清单。
   * ★ 当前 24 款：都是"看一个刺激、点一下、给个反馈"这一类。
   */
  static readonly IDS: string[] = [
    // ── 反应 / 注意（最适合手表：一眼一看一点）──
    'reflex_tap',          // 反应点击
    'choice_reaction_time',// 选择反应时
    'odd_even_flash',      // 奇偶闪现
    'go_no_go',            // 去/不去
    'stop_signal',         // 停止信号
    'vigilance_task',      // 警戒任务
    'dynamic_salience',    // 动态凸显
    'blink_detector',      // 眨眼检测
    'focus_tunnel',        // 焦点隧道
    'spatial_conflict',    // 空间冲突

    // ── 字词（短、单屏）──
    'stroop_test',         // 斯特鲁普
    'reverse_stroop',      // 反向斯特鲁普
    'stroop_number_size',  // 数字大小斯特鲁普
    'color_word_match_up', // 颜色词匹配
    'typoglycemia_decoder',// 乱序词解码
    'homophone_hunt',      // 同音词搜寻

    // ── 数字（快问快答）──
    'math_guess',          // 猜数字
    'quick_math',          // 快速算术
    'target_number',       // 凑目标数
    'missing_operator',    // 缺运算符

    // ── 记忆（短序列）──
    'digit_span_reverse',  // 倒序数字
    'probe_digit_span',    // 数字探针
    'shell_game',          // 猜壳
    'orbit_tap',           // 轨道点击
  ];

  /** 这款游戏在手表上支持吗 */
  static has(id: string): boolean {
    return WatchGames.IDS.indexOf(id) >= 0;
  }

  /** 手表上支持多少款 */
  static count(): number {
    return WatchGames.IDS.length;
  }
}
