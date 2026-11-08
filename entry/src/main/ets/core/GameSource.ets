/**
 * `GameSource` —— 首页网格的 `LazyForEach` 数据源（2026-11-08 perf-hunter）
 *
 * ## 为什么需要它
 * `GamesTab` 原来是 `Grid + ForEach`。官方 FAQ `faqs-arkui-1291` 原文：
 *   「**初始化渲染时，ForEach 会加载数据源的所有数据**，导致页面卡顿。」
 * ⇒ 355 张 `GameCard` × 19 个节点 ≈ **6,745 个节点**在首帧全部创建；
 *   而 `Grid.cachedCount()` 的官方注释（SDK `grid.d.ts:563`）写明
 *   **"It works only in LazyForEach and Repeat with the virtualScroll option enabled"**
 *   ⇒ 原来那行 `.cachedCount(20)` 一直是**死配置**。
 *
 * 换成 `LazyForEach` 后，框架只创建「可视区 + `cachedCount`」范围内的 GridItem，
 * 屏外组件**会被回收**（SDK 原文："will release GridItem components that are outside the display and cache range"）。
 *
 * ## 接口只有 4 个方法
 * SDK `lazy_for_each.d.ts:804–809`：
 *   `totalCount()` / `getData(index)` / `registerDataChangeListener(l)` / `unregisterDataChangeListener(l)`
 *
 * ## 用法（`GamesTab`）
 * ```ts
 * private source: GameSource = new GameSource();
 * // 列表内容变化时（`list()` 的缓存未命中分支）：
 * this.source.reset(next);
 * // 模板里：
 * LazyForEach(this.source, (g: GameMeta, i: number) => { GridItem() { GameCard({...}) } },
 *            (g: GameMeta) => g.id)     // ★ keyGenerator 必须给
 * ```
 *
 * ⚠️ **keyGenerator 必须显式给**：官方 FAQ `faqs-arkui-327` 说明缺省会退化成
 *    `index + '_' + JSON.stringify(item)` —— 对 `GameMeta`（含 `tags: string[]`）
 *    就是每一项都做一次 JSON.stringify，**比原来的 ForEach 还慢**。
 */

import { GameMeta } from './GameRegistry';

export class GameSource implements IDataSource {
  private items: GameMeta[] = [];
  private listeners: DataChangeListener[] = [];

  // ───────── IDataSource 的 4 个方法 ─────────

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): GameMeta {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    // 同一个 listener 只登记一次（框架可能重复注册，重复会导致重载跑多遍）
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  // ───────── 给业务用的最小接口 ─────────

  /** 当前快照（给断言/调试用，不要拿去改） */
  snapshot(): GameMeta[] {
    return this.items;
  }

  /**
   * 整表替换 + 通知重载。
   *
   * ★ 为什么先比一遍再通知：`list()` 的缓存键含**搜索词**，而搜索词从
   *   `abc` 改成 `abcd` 时结果集可能一模一样 —— 不比较就会白重载一次整张网格。
   *   比较是 O(n)（355 次 id 比对），只在缓存未命中时跑一次，可以忽略。
   *
   * ⚠️ `onDataReloaded()` 是**整表重载**：它会让 LazyForEach 按 keyGenerator 重新比对，
   *    同 key 的项**不会被销毁**（这正是我们要的：收藏/搜索不重建卡片）。
   */
  reset(next: GameMeta[]): void {
    if (this.sameAs(next)) {
      return;
    }
    this.items = next;
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }

  /** 内容是否与当前一致（按 id 逐项比，长度先比） */
  private sameAs(next: GameMeta[]): boolean {
    if (next === this.items) {
      return true;
    }
    if (next.length !== this.items.length) {
      return false;
    }
    for (let i = 0; i < next.length; i++) {
      if (next[i].id !== this.items[i].id) {
        return false;
      }
    }
    return true;
  }

  /** ★ 2026-11-08 **首帧空白修复**（perf-hunter 真机实测）：
   *   `reset()` 在 `aboutToAppear` 里调用时，`LazyForEach` **还没注册 listener**
   *   ⇒ 框架首帧查 `totalCount()` 时没拿到预填数据，之后又无事件触发 `onDataReloaded()`
   *   ⇒ **冷启后网格区 0 张卡**，直到任何一次列表变化（切分类）才出 8 张。
   *   ⇒ 挂载后用 `setTimeout(0)` 补一次无条件通知。 */
  reload(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}
