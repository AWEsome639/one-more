import { TG } from '../core/GameI18n';
import { promptAction } from '@kit.ArkUI';

/**
 * Hint —— 统一的「提示」层（2026-10-23 第二期）
 *
 * 为什么需要它：
 *   355 款里 103 款是解谜类（逻辑 44 + 数字 59）。
 *   解谜类的「聪明」不是「有个对手」，是「我卡住时它能帮我」。
 *
 * ★★★ 2026-11-03（第 872 轮）**改掉一句会腐烂的数字**：
 *   原文写「**只有 1 款（数独）有真求解器**」—— 那是 2026-10-23 建层时的状态。
 *   实际现在是：
 *     · `computeHint`（真算提示）  **353 款**
 *     · 内联 `askHint`（G2048 启发式+价值网络 / GPegSolitaire 走法评估）**2 款**
 *     ⇒ **355/355 全部有真提示**
 *   ⚠️ 以后要写"有多少款"这类注释，**必须附上复算命令**（判据 225）：
 *     `grep -l "computeHint" entry/src/main/ets/games/*.ets | wc -l   # ⇒ 353`
 *     `grep -l "askHint"     entry/src/main/ets/games/*.ets | wc -l   # ⇒ 355`
 *   否则半年后又没人能判断这行字还对不对。
 *   ⇒ 做一个统一出口，游戏只要实现「算下一步」就能接入提示，
 *     算不出来也不会把游戏弄坏。
 *
 * 设计三原则：
 *   ① **算不出是正常状态**，不是错误 —— 用 ok=false + reason 表达，不抛异常
 *   ② **有预算**：单次提示超过 BUDGET_MS 就放弃，宁可说"想不出来"也不许冻界面
 *   ③ **文案走 TG**：提示说什么由游戏给，但必须带中英两版，接进 12 语言机制
 *
 * 用法（游戏里）：
 *   const r: HintResult = Hint.run(() => this.computeHint());
 *   if (r.ok) { 高亮 r.cells；显示 r.zh/r.en }
 *   else { 显示"这局暂时想不出来" }
 */

export interface HintResult {
  /** 是否成功给出提示 */
  ok: boolean;
  /** 原因：'ok' | 'none' | 'unsupported' | 'error' */
  reason: string;
  /** 提示指向的格子下标（含义由游戏定义：数独是格号，扫雷是雷格…） */
  cells: number[];
  /** 中文说明（走 TG） */
  zh: string;
  /** 英文说明（走 TG 的第二参数） */
  en: string;
  /** 计算耗时 ms */
  ms: number;
}

export class Hint {
  /** 单次提示的时间预算。超了就明说想不出来，不许冻界面。 */
  static readonly BUDGET_MS: number = 500;

  /** 算不出来（这是正常状态，不是错误） */
  static none(reason: string): HintResult {
    return { ok: false, reason: reason, cells: [], zh: '', en: '', ms: 0 };
  }

  /** 成功给出提示 */
  static make(cells: number[], zh: string, en: string, t0: number): HintResult {
    return { ok: true, reason: 'ok', cells: cells, zh: zh, en: en, ms: Date.now() - t0 };
  }

  /**
   * 带着预算跑一个提示器。
   * ⚠️ 不做真正的超时中断（ArkTS 里同步算没法打断），
   *    但会**测耗时**并把超预算的结果降级成 none —— 至少界面不会显示一个"过期的提示"。
   *    ⇒ 真实防线是各游戏自己的 node 预算（数独有 SOLVER_BUDGET，跳棋有 search budget）。
   */
  static run(fn: () => HintResult): HintResult {
    const t0: number = Date.now();
    let r: HintResult;
    try {
      r = fn();
    } catch (e) {
      return { ok: false, reason: 'error', cells: [], zh: '', en: '', ms: Date.now() - t0 };
    }
    const ms: number = Date.now() - t0;
    if (ms > Hint.BUDGET_MS) {
      // 太慢了：这次的结果不用（避免玩家看到一个卡了半秒才出现的提示）
      return { ok: false, reason: 'timeout', cells: [], zh: '', en: '', ms: ms };
    }
    r.ms = ms;
    return r;
  }

  /**
   * ★ 2026-10-23：用 toast 显示一条提示。
   *
   * 为什么放进框架：
   *   到第 13 款时，我发现「提示怎么显示」其实有三种做法 ——
   *     ① 有状态栏 → 复用那个 Text（最省，零风险）
   *     ② 没有状态栏 → toast（零布局改动）
   *     ③ 都不适合 → 才新增元素（⚠️ 必须当场截图确认没挤坏别的控件，
   *        管道/黑白和就是在这里把按钮挤出屏幕的）
   *   皇冠用的是 ②，那段 try/catch 写在各游戏里很重复
   *   ⇒ 收到框架里，以后新接游戏只需一行。
   *
   * ⚠️ toast 起不来（设备不支持 / 权限）就算了 —— 提示是附加功能，
   *    绝不能因为它让游戏出问题。
   */
  static toast(msg: string): void {
    if (msg.length === 0) {
      return;
    }
    try {
      promptAction.showToast({ message: msg, duration: 4000 });
    } catch (e) {
      // 静默失败
    }
  }

  /**
   * 结果给不出时，用一句兜底话走 toast。
   *
   * ★★★ 2026-11-07（ai-fixer-b 审计发现的真缺口）：原来**只判 `r.ok`，完全不看 `r.reason`**。
   *   `reason` 是设计好的四态字段（ok/none/timeout/error），而且有些游戏**把「人话」当 reason 传**
   *   （`GFreecell.ets:524` `Hint.none(TG('这局已经走不通了，换一局吧'))`）——
   *   这些话**一个字都没显示过**（全项目 `grep "\.reason" games/` = 0 命中）。
   *   ⇒ 335 款的提示失败一律只弹「这一步看不出答案」，玩家分不清「这局死了」还是「算法不行」。
   *
   *   现在：timeout 说「想得有点久」/ error 说「出错了」/ 游戏传的人话直接念 / 其余才用兜底。
   */
  static toastResult(r: HintResult, zhFail: string): void {
    if (r.ok) {
      Hint.toast(r.zh);
      return;
    }
    const reason: string = r.reason === undefined || r.reason === null ? '' : r.reason;
    if (reason === 'timeout') {
      Hint.toast(TG('想得有点久，再点一次'));
      return;
    }
    if (reason === 'error') {
      Hint.toast(TG('出错了，再点一次'));
      return;
    }
    // 游戏自己传的「人话」（已由 TG 翻好）—— 直接念，别丢
    if (reason.length > 0 && reason !== 'none' && reason !== 'unsupported') {
      Hint.toast(reason);
      return;
    }
    Hint.toast(zhFail);
  }

  // ═══════════ 第二期·AI 代打（2026-10-24 奥森提的想法）═══════════
  // 他说：「这 355 个游戏都可以加入一个 AI 代打按钮；点下去后，
  //         会有一个所谓的 AI 帮人玩，数独就一格一格填满（不是一下子全满），
  //         棋类就代下（也是一步一步下）。」
  //
  // 实现思路：**代打 = 把提示层"下一步"自动执行**。
  // 每款游戏只需要实现一个 `autoStep(): boolean`：
  //   算一步 → 调用游戏自己的落子函数 → 返回是否还有下一步。
  // 这里的 autoRun/autoStop 只负责"按节奏重复调用它"。

  /** 代打节拍（毫秒）。太快会看不清，太慢会像卡住。 */
  static AUTO_MS: number = 320;

  // ═══════════ 演示动画（项目 C，2026-10-28）═══════════
  // ★ 核心认识：**演示 = 代打跑一遍**，只是节奏更慢、步数有限、不许通关。
  //   ⇒ 有 autoStep 的游戏，演示只要把它放进"沙盒模式"跑几秒。
  static DEMO_MS: number = 520;      // 比代打慢（320），看得清
  static DEMO_STEPS: number = 6;     // 最多 6 步，演到"看起来懂了"就停

  // ★ 每次进入只演示一次
  //   踩坑：先用 `private static DEMO_SEEN: Set<string>` —— **翻页后没保住**
  //        （struct 的静态成员在页面重建时会被重新初始化）
  //   ⇒ 改用 ArkUI 原生全局存储 AppStorage（页面重建不收走）
  // ⚠️⚠️ **作用域说明（2026-11-04 第 1229 轮补，判据 602）**：
  //   `AppStorage` 是**进程级**存储 ⇒ 这里的「一次」= **每次 App 生命周期一次**，
  //   不是「每次进入这个游戏一次」。
  //   ⇒ 实测（第 1217 轮）：`aa force-stop` 后重启动 ⇒ 首次进游戏**会演示**；
  //     BACK 出游戏再点进去 ⇒ **不会演示**（key 还在）
  //   ⇒ 所以自动化里要重看演示，必须 `aa force-stop` 后重新启动 App。
  //   📖 文案两种形态（具体指引 / 通用回退）的完整说明见
  //      `文档/演示文案两形态-20261104.md`（判据 622）
  static demoOnce(key: string): boolean {
    const k: string = 'demo_seen_' + key;
    if (AppStorage.has(k)) {
      return false;
    }
    AppStorage.setOrCreate<boolean>(k, true);
    return true;
  }

  /** 演示：每 DEMO_MS 调一次 tick，tick 返回 false 就停。 */

  static demoRun(tick: () => boolean): number {
    let id: number = -1;
    id = setInterval(() => {
      let more: boolean = false;
      try {
        more = tick();
      } catch (e) {
        more = false;                // 演示里出错也要停，绝不能让游戏卡死
      }
      if (!more) {
        if (id >= 0) {
          clearInterval(id);
          id = -1;
        }
      }
    }, Hint.DEMO_MS);
    return id;
  }

  /**
   * 开始代打：每 AUTO_MS 调一次 tick，tick 返回 false 就自动停。
   * @returns 计时器 id（传给 autoStop）
   */
  /**
   * ★★★★ 2026-11-01 真机端到端抓到：**「再来一局」后 AI 代打还在跑**。
   *
   *   机制：`autoRun` 用 `setInterval`（全局计时器），**不随组件销毁而停**。
   *   而「再来一局」只把 `nonce + 1` ⇒ 触发游戏的 `@Watch('onRestart')` ⇒
   *   **组件不重建** ⇒ 游戏自己的 `autoId` 仍是原值（按钮还显示"停代打"），
   *   旧计时器继续调用 `autoStep()` ⇒ **AI 在新的一局里自己玩起来**。
   *
   *   ⇒ 用一份**全局活跃登记**，让页面级能一次性停掉所有代打
   *     （一处改动覆盖 355 款，不用每款去改 onRestart）。
   */
  private static autos: Set<number> = new Set<number>();

  /** 停掉所有正在跑的代打（结算 / 再来一局 / 重开 / 切游戏时调用） */
  static stopAllAuto(): void {
    Hint.autos.forEach((id: number) => {
      if (id >= 0) {
        clearInterval(id);
      }
    });
    Hint.autos.clear();
  }

  /** 当前有没有代打在跑（调试/断言用） */
  static anyAuto(): boolean {
    return Hint.autos.size > 0;
  }

  /**
   * ★ 判据 1685：代打**自然停下**时，必须给游戏一次清 `autoId` 的机会。
   *
   * 为什么：按钮文案只取决于游戏的 `autoId >= 0`（HintBar 的 autoOn）。
   * `autoRun` 收到 tick 返回 false 时只 clearInterval + 从 autos 删掉，
   * **碰不到游戏自己的 autoId 字段** ⇒ 353/355 款会出现「AI 已停、按钮还写停代打」。
   *
   * onStop 保证**只调一次**；用户手动 `autoStop(id)` 不触发（那条路游戏自己清）。
   */
  static autoRun(tick: () => boolean, onStop?: () => void): number {
    return Hint.autoRunMs(tick, Hint.AUTO_MS, onStop);
  }

  /**
   * ★★★ 2026-11-07（判据 1731 的落地）：**实时游戏专用的快速代打**。
   *
   * 背景：`autoRun` 固定 320ms 一拍，对回合制/解谜游戏刚好（人能看清）；
   * 但**实时游戏**里球/线每 16ms 动一次，AI 每 320ms 才追一次 ⇒ 永远追不上。
   * 实测：乒乓、描路径在 320ms 下一直是 TIMEOUT。
   *
   * ⇒ 给实时游戏一个 `ms` 参数（建议 16~50），让 AI 按帧追。
   * ⚠️ 只给**物理/实时**类游戏用；回合制游戏用 `autoRun`，否则按钮像抽风。
   */
  static autoRunMs(tick: () => boolean, ms: number, onStop?: () => void): number {
    let id: number = -1;
    let fired: boolean = false;
    const step: number = ms > 0 ? ms : Hint.AUTO_MS;
    id = setInterval(() => {
      let more: boolean = false;
      try {
        more = tick();
      } catch (e) {
        more = false;                  // 代打里出错也要停，绝不能让游戏卡死
      }
      if (!more) {
        if (id >= 0) {
          clearInterval(id);
          Hint.autos.delete(id);
        }
        if (!fired && onStop !== undefined) {
          fired = true;
          onStop();
        }
      }
    }, step);
    Hint.autos.add(id);
    return id;
  }

  /** 停止代打（幂等） */
  static autoStop(id: number): void {
    if (id >= 0) {
      clearInterval(id);
      Hint.autos.delete(id);
    }
  }

  /** 把结果翻译成「给玩家看的一句话」（给不出时也有话说） */
  static describe(r: HintResult, zhFail: string, enFail: string): string {
    if (r.ok) {
      return r.zh.length > 0 ? r.zh : '';
    }
    if (r.reason === 'timeout') {
      return zhFail;
    }
    return zhFail;
  }
}
