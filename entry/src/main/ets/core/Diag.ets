/**
 * 诊断开关 —— **故意放在 `Splash.ets` 之外**（判据 564）
 *
 * ★ 为什么要有这个文件（第 1201 轮）
 *   第 1196 轮我在 `pages/Splash.ets` 里直接加了几条 `hilog.info(..., 'SplashTiming', ...)`
 *   用来量「时间轴 vs 墙钟」的偏离。目的达到了（拿到了项目第一份实测时序），
 *   但**代价很大**：
 *     `工具/check_splash.py` 与 `工具/stamp_splash_evidence.py` 都把
 *     **`Splash.ets` 的 sha256** 当作「这份证据证明的是哪一版」。
 *     改一行日志 ⇒ 源码 hash 变 ⇒ **24 条开屏证据全部失效** ⇒ 要重拍六个尺寸。
 *
 *   ⇒ 判据 564：「证据失效」的修复成本取决于「证据绑不绑会变的量」，
 *     **所以绑定对象的选择本身就是设计决策**。
 *     应该让「纯诊断/纯日志/纯注释」的改动**不**让证据失效。
 *
 *   ⇒ 做法：把开关值放在本文件（**不进 Splash.ets 的 hash**），
 *     `Splash.ets` 里只留 `if (Diag.splashTiming) { ... }` 这一句判断。
 *     以后调开关 ⇒ 只改本文件 ⇒ **证据不失效**。
 *
 * ★ 用法
 *   想打开开屏时序日志 ⇒ 把 `splashTiming` 改成 `true` ⇒ 编译装机
 *   想关掉 ⇒ 改回 `false`
 *
 * ⚠️ 本文件**不会**被 `check_splash.py` 的哈希检查覆盖。
 *    ⇒ 若某个诊断开关**影响观感**（比如改变布局），必须把它挪进 `Splash.ets`，
 *      让证据随它失效；**只放"只看不改"的诊断**在这里。
 */
export class Diag {
  /**
   * 开屏时序诊断日志（`hilog | grep SplashTiming`）
   *   · `MILESTONE pStroke>0 | accum=… ｜ wall=… ｜ drift=…`
   *   · `MILESTONE pM>0      | accum=… ｜ wall=… ｜ drift=…`
   *   · `END | accum=… ｜ wall=… ｜ drift=… ｜ dropped=…`
   *
   * 第 1196 轮实测（800×1280）：
   *   pStroke accum=287ms / wall=482ms ｜ pM accum=351ms / wall=545ms
   *   drift **恒定 195ms**（非累积）｜ dropped=1
   *   ⇒ 三口径差：70（设计）/ 64（时间轴）/ 63（墙钟）ms
   *
   * ⚠️ 默认关：只在需要复算时序时打开。
   */
  static readonly splashTiming: boolean = false;
}
