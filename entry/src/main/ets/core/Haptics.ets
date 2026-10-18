/**
 * 触感反馈 —— 全应用唯一的振动入口
 *
 * 为什么单独一个文件：
 *   ① 设置里的「振动反馈」开关（AppStorage 'hapticsOn'）在这里统一判断，
 *      业务代码只管调 Haptics.tap()，不必每处都查开关；
 *   ② 振动在模拟器上无效、在真机上才有效 —— 但**不报错**，所以调用方不用 try/catch；
 *   ③ 时长都取「短促」档（6–30ms）：触感是标点，不是句子，长了会烦。
 *
 * 权限：ohos.permission.VIBRATE（module.json5 已声明）
 *
 * ★ 2026-10-12 手感专项（奥森：「反馈更贴合手机」）
 *   原来只有 tap/success/press 三个，且**全项目只用了 15 次** ⇒ 手机上几乎没手感。
 *   本轮补成一套**分级触感**，并接到所有关键交互点：
 *
 *   | 调用           | 时长      | 用在哪                                  |
 *   |---------------|----------|-----------------------------------------|
 *   | `tick()`      | 6ms      | 高频轻点（选格、翻牌、点选项）—— 比 tap 更轻 |
 *   | `tap()`       | 12ms     | 一般点按：卡片、按钮、切换                |
 *   | `press()`     | 18ms     | 长按确认：收藏、拖拽起手                  |
 *   | `success()`   | 30ms     | 通关、升级、成就解锁                      |
 *   | `fail()`      | 短-停-短  | 失败、答错 —— **两下**，与成功明确区分      |
 *   | `celebrate()` | 三连      | 大时刻：升级、解锁成就、连胜里程碑          |
 *
 *   ⚠️ 铁律：**每种触感都要能被手指分辨** ——
 *   若两种场景震感一样，等于没有反馈（这才是"贴合手机"的核心）。
 *
 * 拾海 2026-10-10 建；2026-10-12 分级扩充
 */

import { vibrator } from '@kit.SensorServiceKit';

export class Haptics {
  /** 设置里开着吗（默认开） */
  private static on(): boolean {
    return AppStorage.get<boolean>('hapticsOn') ?? true;
  }

  // ───────── 五档触感（从轻到重）─────────

  /**
   * 最轻的一下 —— 高频操作专用（选格、翻牌、点选项）
   * ★ 比 tap 更短：一局游戏要点几十次，重了会烦
   */
  static tick(): void {
    Haptics.buzz(6);
  }

  /** 轻点一下 —— 点按、切换、收藏、切页 */
  static tap(): void {
    Haptics.buzz(12);
  }

  /** 长按的确认感 */
  static press(): void {
    Haptics.buzz(18);
  }

  /** 略重一点 —— 通关、升级、成就解锁 */
  static success(): void {
    Haptics.buzz(30);
  }

  /**
   * 失败 —— **两下短震**，与 success 明确区分
   * ★ 不做成"一下长的"：长震像卡顿，两下才有"错了"的语义
   */
  static fail(): void {
    if (!Haptics.on()) {
      return;
    }
    Haptics.buzz(14);
    setTimeout(() => {
      Haptics.buzz(14);
    }, 90);
  }

  /**
   * 庆祝 —— **三连轻震**，用于升级 / 解锁成就 / 连胜里程碑
   * ★ 只在"大时刻"用：一局最多响一次，多了就廉价了
   */
  static celebrate(): void {
    if (!Haptics.on()) {
      return;
    }
    Haptics.buzz(16);
    setTimeout(() => {
      Haptics.buzz(16);
    }, 70);
    setTimeout(() => {
      Haptics.buzz(26);
    }, 150);
  }

  // ───────── 内部 ─────────

  private static buzz(ms: number): void {
    if (!Haptics.on()) {
      return;
    }
    try {
      vibrator.startVibration(
        { type: 'time', duration: ms },
        { id: 0, usage: 'unknown' }
      );
    } catch (e) {
      // 模拟器、无马达设备、权限未授予 —— 一律静默忽略
    }
  }
}
