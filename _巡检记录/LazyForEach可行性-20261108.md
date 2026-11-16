# `LazyForEach` 可行性评估 —— 2026-11-08

> 执行：**perf-hunter** ｜ **只读 + 只写这个 md**（没改任何 .ets、没编译、没上真机验证改造）
> 目标：判断**首页 355 卡网格**（`Grid + ForEach`，6,745 节点）能不能换成 `LazyForEach`
> 证据：① 本地 DevEco SDK 的 `.d.ts` 原文（最权威）② 本项目源码 ③ 官方 FAQ

## 0. 结论摘要

| 问题 | 答案 |
|---|---|
| **Grid 支持 `LazyForEach` 吗** | **支持**（SDK 原文明确写了两者配合；见 §1）。**而且顺带查出一个 bug：现在的 `.cachedCount(20)` 是死配置**，只有在 `LazyForEach` 下才生效 |
| `IDataSource` 怎么写 | 只有 **4 个方法**（见 §2 骨架，可整段抄） |
| `GameCard` 的 `@Prop` 会失效吗 | **`@StorageProp`（角标/语言/主题色/模式）不受影响**（自订阅）；**`@Prop`（streak/playedToday）本来就会陈旧**，换 `LazyForEach` **不新增**问题，但也不会自动修好 |
| `Tv` 方向键焦点会断吗 | **有真风险，而且这个项目已经踩过一次**：`moveFocus` 的注释记录过「Grid 虚拟化与 `requestFocus` 的竞态」。换 `LazyForEach` 会让这个竞态**更容易出现**（项目现状见 §4） |
| 改哪、多少行、什么风险 | **~110–130 行、1 个文件（或 +1 新文件）、风险 HIGH**；建议**分两步**：先只迁主网格（A-Z 视图不动），且**必须真机验 TV/键盘**（见 §5） |

**一句话**：技术上完全可行，**收益明确（首屏 6,745 → ~400 节点）**，但这是本项目**首次**用 `LazyForEach`，风险集中在**焦点/转场/刷新**三处，属于「值得做，但不能顺手做」。

---

## 1. Q1：`Grid` 支不支持 `LazyForEach`？——**支持（有 SDK 原文）**

`Grid.cachedCount` 的官方注释（`<SDK>/openharmony/ets/component/grid.d.ts:563–575`）：

> Sets the number of grid items to be cached (preloaded). **It works only in `LazyForEach` and `Repeat` with the `virtualScroll` option enabled.**
> The number of the grid items to be cached before and after the currently displayed one equals the value of **cachedCount multiplied by the number of columns**.
> **`LazyForEach` … will release `GridItem` components that are outside the display and cache range.**

⇒ 三件事同时被证实：
1. **Grid 与 `LazyForEach` 是官方支持的组合**（不是“能用但没人保证”）。
2. 它**真的会回收**屏外的 `GridItem`（这才是我们要的省节点）。
3. ⚠️ **`.cachedCount(20)` 现在挂在 `ForEach` 上是无效的** —— 官方写明「只在 `LazyForEach`/`Repeat+virtualScroll` 下生效」。
   这解释了本项目一直以来的困惑：`GamesTab.ets:1258` 的 `cachedCount(20)`（注释写着“多预加载 14 张卡，快速滑动时内容已经建好”）**从没有生效过** —— 因为 `ForEach` 已经把 355 张全建了，“预加载”无从谈起。
   **`GamesTab.ets:2355`（A-Z 视图）同样如此。**

## 2. Q2：`IDataSource` 的接口 & 最小骨架

### 官方接口（`<SDK>/openharmony/ets/component/lazy_for_each.d.ts:804–809`，逐字）
```ts
declare interface IDataSource {
    totalCount(): number;
    getData(index: number): any;
    registerDataChangeListener(listener: DataChangeListener): void;
    unregisterDataChangeListener(listener: DataChangeListener): void;
}
```
`DataChangeListener` 侧我们**只需要用一个方法**：`onDataReloaded(): void`（整表重载）。
（还有 `onDataAdd/onDataDelete/onDataChange/onDataMove/onDatasetChange`，但我们这里只有“筛选条件变了 ⇒ 整表换”，用 `onDataReloaded` 就够。）

### 最小骨架（**可以整段抄**，本项目适配版）
```ts
/** 首页网格的数据源：只有 4 个接口方法 + 一个 reload 通知 */
class GameSource implements IDataSource {
  private items: GameMeta[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): GameMeta { return this.items[index]; }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) { this.listeners.splice(i, 1); }
  }

  /** ★ 唯一给外部用的入口：整表换 + 通知 */
  reset(next: GameMeta[]): void {
    this.items = next;
    for (let i = 0; i < this.listeners.length; i++) { this.listeners[i].onDataReloaded(); }
  }
}
```
**用法**（`GamesTab` 里）：
```ts
Grid(this.gridScroller) {
  LazyForEach(this.source, (g: GameMeta, i: number) => {
    GridItem() { GameCard({ /* 参数原样搬 */ }) }
  }, (g: GameMeta) => g.id)          // ← keyGenerator 必须给（官方：不给会用 index+JSON.stringify，极慢）
}
```
⚠️ **`LazyForEach` 必须提供第 3 个参数（keyGenerator）**——官方 FAQ `faqs-arkui-327`：「缺省会退化成 `index + '_' + JSON.stringify(item)`」。对 `GameMeta`（含 `tags[]`）就是**每项一次 JSON.stringify**，比现在还慢。

### 唯一真正的活儿：**什么时候 `reset()`**
`list()` 现在的变化来源有 6 个（都在 `GamesTab` 内）：
`seg 切换`（全部/收藏/最近）、`category 切换`、`picked 特征`、`searchText`（我加防抖后 150ms 一次）、`tick`（收藏/长按）、`onPageShow`（回到首页时 dailyId 刷新）。
⇒ 现成的卡口是 **`list()` 自己**（它有 `listCacheKey` 记忆化）。最省的做法：**在 `list()` 命中缓存失效的那一分支里顺手 `this.source.reset(next)`**，一处覆盖 6 个来源。

## 3. Q3：`GameCard` 的依赖在 `LazyForEach` 下会不会失效？

`GameCard` 的 14 个入参（`Common.ets:946–1023`）分三类：

| 类别 | 具体 | 换 `LazyForEach` 后 | 结论 |
|---|---|---|---|
| **`@StorageProp`（自订阅）** | `lang` / `accent` / `uiMode` / **`clearedGames`** / **`perGameBest`** | 子组件**自己**订阅 AppStorage，值一变**自己重建**，与父容器怎么创建无关 | ✅ **完全不受影响**（角标就是这么修的，见 `卡片角标-20261107.md`） |
| **`@Prop`（父传）** | `meta` / `theme` / `index` / `streak` / `playedToday` / `first` / `sharedId` / `allowMenu` / `gridCols` | 只在**创建时**赋值。key 不变 ⇒ 父重渲染**不会**重跑 itemGenerator ⇒ **值会陈旧** | ⚠️ **与今天完全一样**（`ForEach` 同 key 也不更新）。**不新增问题，也不修旧问题** |
| **`@State`（卡内）** | `focused` / `pressed` / `hovered` / `shown` / `entered` | 每个实例自己的状态 | ✅ 不受影响 |

**关于 `@Prop streak` / `playedToday` 的既有缺口**（不是 `LazyForEach` 引入的）：
它们来自父组件现调 `ProgressStore.streakOf/playedToday`（`GamesTab.ets:1153–1154`，现取）。
今天靠 key 里塞 `tick` 来“顺手刷新”，而 `tick` **只在收藏/长按时才 +1**（玩完一局不会碰它）。
⇒ 也就是说：**现在「玩完一局回到首页，那张卡的 🔥/今日 到底更不更新」本身就没有可靠路径**。
换 `LazyForEach` 后这个洞**依然在**，且**更难靠 key 兜**（因为真正的解法是让卡自己 `@StorageProp` 一份每款连胜 —— 那要新增 AppStorage 键，属功能改动）。
👉 **建议：把这件事和 `LazyForEach` 解耦**，先单独确认这个洞口是否真实存在（真机验一条：玩一局 → 返回 → 看那张卡）。

## 4. Q4：`Tv` 方向键焦点会不会断？—— **有真风险，项目已踩过一次**

### 项目自己的历史（`GamesTab.ets` 里 `moveFocus` 的注释，逐字要点）
> 「实测 DOWN×2+RIGHT 后页面滚到了**顶部**，因为 **Grid 的虚拟化与 `requestFocus` 有竞态：焦点请求时目标 item 还没渲染**，滚动器不知道往哪滚，退回顶部。」
> 「现在的做法：**不自己滚**。ArkUI 在 `requestFocus` 成功后会自动把聚焦元素滚进可见区。」

⇒ 这说明：**即使是 `ForEach`（全量创建），Grid 的虚拟化也已经和焦点打过架**，项目是靠「不手动滚 + 依赖 requestFocus 自动滚」绕过去的。

### 换 `LazyForEach` 后的两个具体风险
| 风险 | 机制 | 触发场景 |
|---|---|---|
| **R1 目标项不存在** | `focusControl.requestFocus('card-' + target)`（`moveFocus` 里）请求的 id 若**还没被创建**（屏外 + 超出 `cachedCount` 范围），请求落空 ⇒ 焦点停在原地/丢失 | TV/键盘**长距离**方向键连按（尤其 4 列布局下按上下键跨行） |
| **R2 回收即失焦** | `LazyForEach` 会释放屏外 `GridItem`（SDK 原文）⇒ 正在聚焦的卡被滚出缓存区后，**组件被销毁** ⇒ 焦点自然消失 | 用方向键一路推到底、或用滚轮滑走 |

### 缓解手段（都有代价）
1. **加大 `cachedCount`**（例如 40）：这次它**真会生效**，能覆盖「一屏 + 前后各 40 项」。代价：多建 40×列数 个卡，收益打折。
2. **`moveFocus` 改成先 `scrollToIndex(to)` 再延迟 `requestFocus`**（`setTimeout(...,0)`）——项目注释里已标过「若后续发现远距离跳转时目标不自动可见，再考虑 `setTimeout(..., 0)` 延迟滚动」。**这正是那种场景**。
3. 最坏情况：TV/键盘路径**回退成 `ForEach`**（`if (Tv.on()) { ForEach(...) } else { LazyForEach(...) }`）——**能用但代码两份，不推荐**。

### 还有一个非焦点风险：共享元素转场
`Common.ets:1382` 用的是 `.sharedTransition(this.sharedId, ...)`（注释 `:1377–1381` 说明了为什么不用 `geometryTransition`：**它明确支持跨页面**）。
本项目的用法是「点哪张卡，就给哪张卡挂 `sharedId` 然后 push 页面」⇒ 被挂的那个实例**刚被点过、一定在屏上**，正常情况安全。
⚠️ 但 `LazyForEach` 下若在**转场进行中**（`Motion.base=260ms`）列表发生重排/重载（例如 `tick` 变化、或 `onPageShow` 的 `dailyId` 刷新触发 `list()` 变更），**卡被回收 ⇒ 转场会闪/丢**。`GamesTab` 已有 `flyingId` 400ms 兜底清理（`:775–776`，`openGame` 里），但**回收是被动的**，兜底不了。

## 5. Q5：改哪里、改多少行、风险等级

### 改动清单（**只迁主网格**，A-Z 视图不动）
| # | 位置 | 改什么 | 行数 |
|---|---|---|---|
| 1 | `components/GamesTab.ets:1134–1203` | `ForEach(this.list(), …)` → `LazyForEach(this.source, …)`；卡片参数（69 行）**原样不动** | 首尾各改 1 行 + 加 keyGenerator 1 行 ≈ **3 行** |
| 2 | `GamesTab` 内新增 `GameSource` 类 | §2 的骨架（4 个接口方法 + `reset`） | **≈ 25 行** |
| 3 | `GamesTab.list()` 的**缓存未命中分支** | 算出 `next` 后调用 `this.source.reset(next)`（一处覆盖 6 个变化来源） | **≈ 2 行** |
| 4 | `aboutToAppear` | 首次把 `list()` 灌进 source（避免首帧空列表） | **≈ 2 行** |
| 5 | `.cachedCount(20)`（`:1258`） | 现在**终于生效** ⇒ 建议**先降到 8–12** 观察（20 会预建 20×列数 = 80 张） | **1 行** |
| 6 | `moveFocus`（`:722`） | 若要保 TV：加「先 scrollToIndex 再延迟 requestFocus」 | **≈ 6 行** |
| — | **合计** | | **≈ 35–40 行净改 + 25 行新类 ≈ 60–65 行**（比我之前估的 110 行小，因为卡片参数不用动） |

### 风险等级：**HIGH**（三条理由）
1. **全仓 0 先例** —— 没有可抄的代码，`IDataSource` 在这个项目里是第一次出现；
2. **焦点竞态有前科** —— 项目注释白纸黑字记着「Grid 虚拟化与 requestFocus 有竞态」，改造会放大它；
3. **刷新是官方 FAQ 的重灾区** —— `faqs-arkui-828 / 770 / 41 / 605` 四篇都在讲「LazyForEach 改了数据 UI 不刷新」，而这个项目的刷新来源有 **6 个**（seg/category/picked/search/tick/onPageShow），**漏一个就是“列表不刷新”**。

### 建议：**分两步，先做“零风险的一半”**
- **第 0 步（先做，0 风险）**：把 `.cachedCount(20)`（`:1258`）**降下来或加注释说明它是死配置** —— 因为它现在**完全无效**，留着一个“以为在预加载”的假象比删掉更危险。
- **第 1 步（可做）**：只迁主网格 + 不碰 A-Z + `cachedCount` 设 8 + **暂不动 TV 焦点逻辑**，然后在**非 TV 设备**（手机/平板）上验收：首屏节点数、滚动连贯、搜索/分类/收藏/切语言 5 件事。
- **第 2 步（单独做）**：TV/键盘焦点（按 §4 的 R1/R2 加 `scrollToIndex + 延迟 requestFocus`），在智慧屏/键盘上验收。
- **A-Z 视图（`:2334–2355`）建议不迁**：它是 `ListItemGroup + ForEach(sec.games)` 两层结构，`LazyForEach` 包 `ListItemGroup` 要额外处理组头，收益（A-Z 是次要入口）远小于风险。

### 验收清单（缺一条都不算过）
1. 首屏节点数：`uitest dumpLayout` 里 `Stack` 卡片节点应从 355 → **≤ 一屏+缓存**；
2. 滚动连贯（快速甩到第 300 款不白屏）；
3. **搜索/分类/特征/收藏/最近/切语言** 六个来源各改一次，列表**都跟着变**；
4. 收藏一张卡：**不应**重建全表（key 里已无 `tick`）；
5. 点卡进游戏：**共享元素转场正常**，返回后列表位置不跳；
6. TV/键盘：方向键 4 方向 + 跨行 + 长距离连按，焦点不丢、目标自动进视野。

## 6. 复现 / 依据出处

| 结论 | 出处 |
|---|---|
| `IDataSource` 4 个方法 | `<SDK>/openharmony/ets/component/lazy_for_each.d.ts:804–809` |
| `cachedCount` 只在 `LazyForEach`/`Repeat+virtualScroll` 生效；会回收屏外 `GridItem` | `<SDK>/openharmony/ets/component/grid.d.ts:563–575` |
| 缺省 keyGenerator = `index + JSON.stringify(item)`（必须显式给） | 官方 FAQ `faqs-arkui-327` |
| 「LazyForEach 改数据 UI 不刷新」的四种成因 | 官方 FAQ `faqs-arkui-828 / 770 / 41 / 605` |
| 本项目的焦点竞态前科 | `components/GamesTab.ets` `moveFocus()` 注释（原文见 §4） |
| 共享元素用的是 `sharedTransition` 而非 `geometryTransition` | `components/Common.ets:1377–1382` |
| 卡片 14 个入参的分类 | `components/Common.ets:946–1023` |
