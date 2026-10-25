# 一局 · 游戏开发约定（★动手前必读★）

工程根：`~/dev/One More`　｜　构建：`bash ~/dev/One More/build.sh`（并发安全，撞车会自动排队）

## 一、你要交付什么
在 `entry/src/main/ets/games/` 下**新建你自己的游戏文件**（文件名见你的任务）。
⛔ **绝对不要改**这些共享文件（改了会撞车）：
`core/Design.ets`、`core/GameRegistry.ets`、`core/ProgressStore.ets`、
`components/Common.ets`、`pages/Index.ets`、`pages/GameHost.ets`、`AppScope/**`。
注册到主页与宿主的活由 Lead 统一做。

## 二、★组件契约（照抄，一个字都别改★）
```ts
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { GameResult } from '../core/GameRegistry';

@Component
export struct G你的游戏名 {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  aboutToAppear(): void { this.reset(); }
  onRestart(): void { this.reset(); }        // 宿主点「换一局」时触发

  build() { /* 自己铺满父容器：.width('100%').height('100%') */ }
}
```
**参考实现：`entry/src/main/ets/games/G2048.ets` —— 先通读它，照着它的结构写。**

结算（一局结束必须调）：
```ts
const r: GameResult = { gameId: '<注册表里的 id>', solved: true|false, score: 数字, durationMs: 毫秒 };
this.onFinish(r);
```

## 三、设计系统（不许出现魔法数字）
一律从 `../core/Design` 取：
- **字号** `FontSize.hero/xxxl/xxl/xl/lg/md/sm/xs/xxs`
- **间距** `Space.xs=6 sm=10 md=16 lg=20 xl=28 xxl=32 xxxl=48`
- **圆角** `Radius.xs=8 sm=12 md=16 lg=24 xl=32 full=999`
- **颜色** `Palette.primary '#6366F1' / berry / emerald / amber / teal / violet / sky / rose / lime / orange / cyan`
  主题取色用 `this.theme.ink / inkSoft / inkFaint / surface / surfaceAlt / line / bg`（`theme.isDark` 判断深浅）
- **动效时长** `Motion.fast=160 base=220 slow=260 sheet=300`，`Motion.pressScale=0.96`

## 四、体验铁律（"流畅"就靠这几条）
1. **点击必有反馈**：`.onTouch` 里 Down 时 `pressed=true`，Up/Cancel 时 false；`.scale({x: pressed?0.96:1, y:...})`
2. **状态变化都要有动画**：`.animation({ duration: Motion.fast, curve: Curve.EaseOut })`
3. **进场动效**：卡片/元素从小到大或从上往下淡入
4. 视觉靠 **emoji + 色块 + 圆角 + 阴影**，⛔ **不要引入任何图片资源**

## 五、ArkTS 语法坑（我踩过的，别重踩）
- ❌ 组件实例化**不许传 `key`** ⇒ 要用 `@Prop @Watch('onRestart') restartToken: number = 0`（已给）
- ❌ `SwipeGesture` 没有 `distance` 参数 ⇒ 用 `{ fingers: 1, direction: SwipeDirection.All, speed: 20 }`
- ❌ 不许用 `any`；对象字面量必须有显式类型（先 `interface` 再 `const x: X = {...}`）
- ❌ `struct` 里不能用 `private` 修饰 `@State`；普通成员变量可以
- ✅ `setInterval/clearInterval`、`setTimeout` 可用（记得 `aboutToDisappear` 里清）
- ✅ `Math.random()`、`Math.floor()` 可用

## 六、交付前必须自查
1. `bash ~/dev/One More/build.sh` → **必须 BUILD SUCCESSFUL**（不成功就改到成功）
2. 每个游戏都要有：**重开按钮**、**当前进度/得分显示**、**通关或结束的明确判定**
3. 回复里报：文件名 / 游戏 id / build 结果 / 一句话玩法

## 七、⛔ 合规红线
- **不许抄任何现成项目的代码**（包括 sidhant947/Puzzle）
- 玩法本身（2048/扫雷/数独…）是公有领域，**自己实现**
- 不引入第三方依赖（只用 ArkTS 标准库 + `@kit.*`）

---

# ★★ 351+ 款扩充版补充约定（2026-10-10 晚）

## 零、最重要的一条
**绝对不要改 `pages/GameHost.ets`** —— 它由 `tools/gen_dispatcher.py` 自动生成，
你改了会被下次生成覆盖，而且会和别人的改动撞车。
**你只需新建 `games/<你的文件>.ets`**，宿主的分发由 Lead 跑生成器解决。

## 一、你的 gameId 必须已在注册表里
游戏清单在 `entry/src/main/ets/core/GameRegistry.ets`（354 款，自动生成）。
找你要做的那款：
```bash
grep "id: '<你要的id>'" entry/src/main/ets/core/GameRegistry.ets
```
里面给了 `name`（中文名）、`tagline`（一句话玩法）、`icon`（emoji）、`category`。
**照那个 id 写进你的组件**，不要自己改名。

## 二、文件命名
`entry/src/main/ets/games/` 下，文件名 = 大驼峰，与 struct 同名。
例：id `akari` → 文件 `GAkari.ets`，struct `GAkari`。
（前缀 `G` 是为了和页面文件区分，不是硬性要求，但请统一。）

## 三、★ 组件的骨架（照抄，只有 gameId 不同）
```ts
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { GameResult } from '../core/GameRegistry';

@Component
export struct GAkari {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  aboutToAppear(): void { this.reset(); }
  onRestart(): void { this.reset(); }

  build() { /* 铺满父容器：.width('100%').height('100%') */ }
}
```
结算时：
```ts
this.onFinish({ gameId: 'akari', solved: true, score: 0, durationMs: Date.now() - this.startAt });
```

## 四、三条硬要求（缺一不可）
1. **有明确胜负**：通关 或 失败，必须调 `onFinish`
2. **有重开**：`reset()` 要能完整重置状态
3. **有进度显示**：得分/步数/用时/剩余，至少显示一个

## 五、能短就短
- 优先用 **emoji + 色块 + 圆角**，不引图片
- 棋盘类用 `Row`/`Column` 嵌套，格子 `.layoutWeight(1).aspectRatio(1)`
- ⚠️ **Row 里的格子必须 `.layoutWeight(1)`，不能 `.width('100%')`**（会让每个格子撑满整行）
- 纯逻辑类（反应、记忆、心算）可以很简单，60~120 行就够

## 六、构建
`bash ~/dev/One More/build.sh` → 必须 **BUILD SUCCESSFUL**。
⚠️ 多人同时构建会自动排队，等一会儿正常。
