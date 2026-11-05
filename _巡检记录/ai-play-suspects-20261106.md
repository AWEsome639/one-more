# AI 代打静态扫描 · 可疑模式清单（2026-11-06）

> 纯静态审计。**未改任何游戏源码、未编译、未碰 hdc/模拟器**（设备正被占用）。
> 扫描对象：`entry/src/main/ets/games/*.ets`（只算 `.ets`，`*.bak-*` 不计）。

---

## 1. 摘要

| 项 | 数 |
|---|---|
| 游戏 `.ets` 文件 | **355** |
| 有 `autoStep()` | 355（100%） |
| 源码含字面量「AI 代打」 | 353（另 2 款见 §6，是假阳性） |
| 通过共享 `HintBar` 的 `onAutoTap` 接入 | 339（其余自己渲染按钮） |
| `autoStep` 内 `return false` 分支总数 | 435 |
| 其中「非终局」条件的 | **83 处 / 分布在 73 款** |
| `return true` 但**不动任何状态**的分支 | 46（真·空转嫌疑） |
| 本轮判定为**真问题** | **3 条高 + 20 款中（一族）** |

### 一句话结论

**旧验证器（「点完后按钮变成停代打」）在原理上就是无效的** —— 按钮文案只取决于
`autoId >= 0`，而 353 款游戏在 `autoStep` 返回 `false` 时**从不把 `autoId` 清回去**
（§2.1）。所以「按钮显示停代打」既可能表示 AI 在跑，也可能表示 AI 早就放弃了 —— 这个检查
**恒为真**，抓不到任何 bug。新验证器必须换成「两次采样之间棋盘/状态是否变化」。

第二点：我按「看着最像 bug」的三大家族逐一核对后，**大部分是死代码**（§5 有证据）。
真正会咬人的只有 3 处，其中最危险的是 2 处「无解状态不算终局 ⇒ `return true` 死循环」。

---

## 2. 高概率真 bug

### 2.1 【系统级 · 353/355 款】`autoStep` 返回 false 后 `autoId` 不归零 ⇒ 按钮永远「停代打」

**文件**：`components/HintBar.ets:35, 59-65` + 全部游戏（以 `games/G2048.ets:432-460` 为例）

```ts
// components/HintBar.ets
35:  @Prop autoOn: boolean = false;          // ← 父组件传 this.autoId >= 0
59:  private autoLabel(): string {
62:      return this.autoOn ? TG('停') : TG('AI');
64:    return this.autoOn ? TG('停代打') : TG('AI 代打');
```

```ts
// games/G2048.ets —— 全项目 355 款的标准骨架
432:  private autoStep(): boolean {
433:    if (this.over || this.won) {
434:      return false;                    // ← 停在这里，autoId 仍是 >= 0
435:    }
436:    const d: number = this.bestDir();
437:    if (d < 0) {
438:      return false;                    // ← 同上：四个方向都动不了，静默放弃
439:    }
440:    this.move(d);
441:    return !this.over;
442:  }
   ...
455:  private stopAuto(): void {          // ← 只有 askAuto() 会调它
456:    if (this.autoId >= 0) {
457:      Hint.autoStop(this.autoId);
458:      this.autoId = -1;
```

**为什么是 bug**：`Hint.autoRun` 的计时器回调收到 `false` 时只做
`clearInterval(id) + Hint.autos.delete(id)`（`ai/Hint.ets:230-241`），**它碰不到游戏自己的
`this.autoId` 字段**。全项目 `stopAuto()` 的调用点只有三类：`askAuto()`（用户手动停）、
少量键盘/认输处理器、以及**离页钩子**（全项目只 3 款做了：`GBlinkDetector.ets:66`、
`GBlockEscape.ets:201`、`GFlappy.ets:135`）。我逐文件核过：**355 款里没有一款把
`stopAuto()` 放在 `finish()` 里** —— 也就是说「本局结束」这条路上，`autoId` 没有任何人清。

**唯一两个做对了的（可当模板抄）**：
- `games/GPegSolitaire.ets:388-404` —— 三个 `return false` 前面都补了 `this.stopAuto()`
- `games/GWaterSort.ets:481-488` —— 带注释的规范写法（判据 1611/1618）：
  ```ts
  478:    if (this.wsPlan.length === 0) {
  481:      if (this.wsPlan.length === 0) {
  485:        this.stopAuto();
  486:        Hint.toast(TG('这一局 AI 没找到解法，请自己来'));
  487:        return false;
  ```

**影响面**：73 款的 `return false` 是**非终局**条件（不是 `over/won/finished/done`），
这些款的「静默放弃」是**玩家能直接看到**的：棋盘还活着、按钮写着「停代打」、AI 不动了。
只要不点按钮，它会一直那样挂着。

> ⚠️ 这正是 `GDirectionsRecall` 那个 bug 的表现层成因：它把 `phase==='done'` 当成终局返回
> false，`autoRun` 停了、按钮还在「停代打」，于是「AI 卡死 + 按钮说它在跑」。

---

### 2.2 【高】`GBubbleShooter.ets:272` —— 泡泡墙堆到顶后 `return true` 死循环

```ts
// games/GBubbleShooter.ets
268:  private autoStep(): boolean {
269:    if (this.over) {
270:      return false;
271:    }
272:    if (this.over || this.bestCol() < 0) {
273:      return true;                     // ← 没有一列能落子 ⇒ 每 320ms 空转一次
275:    this.fire(this.bestCol());
```

```ts
129:  private landing(f: number[], c: number): number {
130:    for (let r = ROWS - 1; r >= 0; r--) {
131:      if (f[this.idx(r, c)] >= 0) {
132:        return r + 1 < ROWS ? r + 1 : -1;   // ← 该列顶到天花板 ⇒ -1
```

**为什么是 bug**：`bestCol()` 返回 -1 的唯一原因是**所有列的 `landing()` 都返回 -1**，
即泡泡墙堆到顶、一发都打不出去。但本局只有两个终局条件：

```ts
377:    if (this.countLeft(f) === 0) {        // 清空 ⇒ 赢
384:    if (this.left <= 0) {                // 发球次数用完 ⇒ 输
```

「墙堆满」既不是清空也不是次数用完 ⇒ `over` 仍是 false ⇒ `autoStep` 每拍 `return true`，
**永远出不来**。这不是 AI 专属问题：玩家这时也点不动任何一列，是**游戏级死局**，
只是 AI 会以 320ms 的节奏把它变成永动机。

> 判据已有注释、数值未核到：能不能真堆到顶取决于 `left` 与球总数的余量，
> 需要真机或本地模拟确认可达性（见 §4.2）。

---

### 2.3 【高 · 设计相关】`GBlockStackingPhysics.ets:177` —— `bestPillar() < 0` ⇒ `return true`

```ts
// games/GBlockStackingPhysics.ets
173:  private autoStep(): boolean {
177:    if (this.queue.length === 0 || this.bestPillar() < 0) {
178:      return true;                     // ← 没有柱子接得住这块 ⇒ 空转
180:    this.place(this.bestPillar());
```

```ts
203:  private bestPillar(): number {
204:    const w: number = this.queue.length > 0 ? this.queue[0] : -1;
205:    for (let k = 0; k < 3; k++) {
206:      if (LEVELS[this.level].inner[k] !== w) {
207:        continue;                      // ← 宽度对不上就跳过，全不匹配 ⇒ -1
```

**为什么是 bug**：`bestPillar() < 0` 表示「当前这块没有任何一根柱子的内宽接得住」。
这**不是终局**：唯一的终局是 `place()` 里队列清空后 `finish(true)`（`:254-256`）或超高塌了
`finish(false)`（`:250-252`）。块放不进去 ⇒ 既不赢也不输 ⇒ `autoStep` 每拍 `return true`。

**同一个表达式里的另一半是死代码**：`queue.length === 0` 那一支永远走不到，因为队列清空
的那一刻 `place()` 已经调了 `finish(true)` 把 `over` 置真（`:254-255`），提前被 `:174` 拦下。

> 触发前提是「关卡表里某块的宽度没有柱子接受」，属设计期错误；一旦出现就是永久卡死。

---

## 3. 中等可疑

### 3.1 【一族 · 20 款】「求解器说没招了 ⇒ `return true`」—— 与 2.2/2.3 同形，但多数是死代码

判据：`if (this.over || this.xxx() < 0) { return true; }` —— `over` 那半被上一条
`if (this.over) return false` 拦死，所以真正起作用的是**后半句**，而它返回的是 `true`（继续跑）
而不是 `false`（收工）。语义应该是 `return false`。

| 文件 | 行 | 守卫 | 判定 |
|---|---|---|---|
| `GBubbleShooter.ets` | 272 | `bestCol() < 0` | **真 bug**（§2.2） |
| `GBlockStackingPhysics.ets` | 177 | `bestPillar() < 0` | **真 bug**（§2.3） |
| `GMatrixMultiplierMatch.ets` | 251 / 258 | `nextLeft() < 0` / `slotOf() < 0` | 中（见 3.2） |
| `GCompoundConnect.ets` | 318 | `path.length >= sol.length` | 中（见 3.3） |
| `GTemporalOrder.ets` | 185 | `locked \|\| nextIdx() < 0` | 中（见 3.4） |
| `GKakuroMini.ets` | 413 | `autoVal() < 1` | 中 |
| `GStroopNumberSize.ets` | 186 | `val === 0` | 中 |
| `GTarget10.ets` | 180 | `tgTarget() < 0` | 中 |
| `GVisualSearch.ets` | 201 | `feed >= 0 \|\| targetIdx < 0` | 中 |
| `GVisualSearchConjunction.ets` | 199 | `targetCell() < 0` | 中 |
| `GFlappy.ets` | 430 | `gapTarget() < 0` | 低（管道会自己刷出来，等是合法的） |
| `GBalanceScale.ets` | 275 | `autoChip() < 0` | 低（= 天平已平 ⇒ 应同时 over） |
| `GBinaryScaleBalance.ets` | 249 | `needBit() < 0` | 低（同上） |
| `GLockPattern.ets` | 241 | `autoCell() < 0` | 低（见 §5.2） |
| `GMasyu.ets` | 428 | `autoCell() < 0` | 低 |
| `GShikaku.ets` | 357 | `autoCell() < 0` | 低 |
| `GNoriNori.ets` | 439 | `autoCell() < 0` | 低 |
| `GYajilin.ets` | 285 | `autoCell() < 0` | 低 |
| `GWordGridConnection.ets` | 221 | `autoCell() < 0` | 低 |
| `GFeatureMatrixRecall.ets` | 206 | `autoCell() < 0` | 低 |

**修法（统一）**：把 `return true` 改成 `return false`，并按 `GWaterSort:485` 的写法
补 `this.stopAuto()`；若「没招了」本身等价于终局，则补 `this.finish(false)`。

### 3.2 `GMatrixMultiplierMatch.ets:252` —— 注释声称「等它换下一块」，但**全文件没有换块计时器**

```ts
245:  private autoStep(): boolean {
249:    if (this.selL < 0) {
250:      const k: number = this.nextLeft();
251:      if (k < 0) {
252:        return true;                 // 这一块全配完了，等它换下一块
```

`nextLeft()`（`:144-151`）只在 `PAIRS` 全部 `done[k]` 时返回 -1。而换块的唯一代码在
`:340-343`：`if (this.board >= BOARDS) end(true) else { this.board++; this.newBoard(); }` ——
**同步执行**，不是计时器。全文件的 `setTimeout` 只有演示、`scorePulse`、扣时动画三种。

⇒ 那句注释是错的。目前靠「最后一次配对同步换板」兜住，所以**暂时不炸**；
但它是典型的「假设有别的机制会来救我」写法 —— `newBoard()` 一旦不重置 `done[]` 就永久卡死。

### 3.3 `GCompoundConnect.ets:314-322` —— sol 驱动 + `tap()` 可静默拒绝

```ts
314:  private autoStep(): boolean {
318:    if (this.over || this.sol.length === 0 || this.path.length >= this.sol.length) {
319:      return true;
321:    this.tap(this.sol[this.path.length]);
```

`tap()` 有 4 条**不报错、不推进**的早退路径：

```ts
378:    if (i === last) { ... p.pop(); this.path = p; }      // 退格
382:      this.msg = TG('退回一步');
385:    if (this.path.indexOf(i) >= 0) {                     // 重复格
386:      this.msg = TG('这条线不能重复走同一格');
389:    if (this.board[i] === 0) {                           // 障碍格
390:      this.msg = TG('障碍格不能走');
```

只要 `sol` 里出现一次「已经走过的格子」或「障碍格」，`path` 就不再增长，
而 `autoStep` 仍 `return !this.over` = `true` ⇒ **每拍都点同一格、状态不变、永久空转**。
`sol` 的生成是否保证了路径无重复，需要看 `solve()`（本轮未核到）。

### 3.4 `GTemporalOrder.ets:185` —— `locked` 没有超时兜底

```ts
185:    if (this.over || this.locked || this.nextIdx() < 0) {
186:      return true;
```

`locked` 在 9 款里是「动画/反馈期间锁输入」的旗标，正常由 `setTimeout` 清掉。
本款我核到的清锁点都在计时器里，**目前不会卡**；但它没有任何「锁超时自愈」，
一旦某次 `clearTimeout` 漏掉或组件重建打断计时器，`locked` 就永久为真、AI 永久空转。
同形还有 `GMemory.ets:182`（`this.lock || this.done`）等，属「可接受但脆」的写法。

---

## 4. 验证建议（每款最少真机操作）

> ⛔ 前提：**不要再用「按钮变成停代打」当判据**（§2.1 已证明它恒真）。
> 也不要只读 `dump` 的 `text` —— 判据 588 记过：`dump` 是逻辑文字，屏幕上可能被截断。

### 4.1 【一类：全部 355 款】判别「AI 是否真的在动」的标准动作（4 步）

1. 进游戏后**先等 6 秒**（演示期 `demoOn=true` 时按钮**整个不渲染**，见 §6）
2. 点「AI 代打」→ 立即 `screenshot`
3. 等 **8 秒**（≥ 25 拍，足够看出是否还在推进）→ 再 `screenshot`
4. 判据：**两次截图的棋盘/题面像素必须有差异**。
   - 有差异 ⇒ AI 在跑（还赢没赢另说）
   - 无差异但按钮仍写「停代打」 ⇒ **静默放弃**（§2.1 的形态），记为 FAIL
   - 无差异且已弹结算 ⇒ PASS

> 只有第 4 步的「像素差」能区分「在跑」和「静默放弃」，`dump` 的文案两条路都一样。

### 4.2 【§2.2 `GBubbleShooter`】确认「墙堆到顶」可达

不必真机：在 `fire()` 里临时打日志（**不在本轮范围内，仅建议**）统计 `bestCol()` 首次返回
`-1` 时 `this.left` 和 `this.countLeft(f)` 的值。若 `left > 0 && countLeft > 0` ⇒ 坐实死局。
真机替代方案：手动往同一列猛打 20 发左右，看顶到天花板时游戏是否还有任何反应。

### 4.3 【§2.3 `GBlockStackingPhysics`】只需查关卡表

静态查 `LEVELS`：对每个 level，`queue` 里每个宽度都能在 `inner[0..2]` 里找到同宽。
找不到 ⇒ 该关卡必卡（一次 grep 即完）。

### 4.4 【§2.1 的 73 款非终局 return false】优先级最高的 5 款

按「玩家最容易自己撞上」排：

| 优先 | 文件 | 非终局 return false 位置 | 触发场景 |
|---|---|---|---|
| 1 | `GCheckers.ets` | 755 `mv2 === null` | AI 无子可走 |
| 2 | `GSokoban.ets` | 481 / 488 | `solvedNow` / 计划为空 |
| 3 | `GCrossword.ets` | 190 / 194 | 词库索引走完 / 银行里没这个词 |
| 4 | `GFreecell.ets` | 253 `fcPlan.length < 3` | 求解器给不出 3 步 |
| 5 | `GHanoi.ets` | 160 `mv[0] < 0` | 汉诺塔无解 |

每款的操作：点 AI → 等 8 秒 → 看是否出现「按钮停代打 + 棋盘不动 + 无结算」三件套。

### 4.5 复看演示的坑

`AppStorage` 是**进程级**（`ai/Hint.ets:143-150`）。想重看演示必须
`aa force-stop` 后重启 App，BACK 出去再进**不会**再演示。

---

## 5. 低 / 已排除（附证据，省得下一个人再查一遍）

### 5.1 【77 款】`if (picked/sel/pick >= 0) return true` —— 全部安全

这类「等答题反馈播完」的守卫看着最像空转。我做了**全 355 款调用图 + 计时器可达性**扫描
（把 `setTimeout`/`setInterval` 回调里调到的函数做传递闭包，再看守卫变量是否在闭包内被赋过值）：
**0 例外** —— 每个守卫变量都存在一条计时器可达的复位路径。

抽检 4 款确认复位点：

| 文件 | 守卫 | 复位点 |
|---|---|---|
| `GChangeBlindness.ets` | `phase !== 2 \|\| pick >= 0` (228) | `:263 setTimeout → 下一轮` |
| `GChoiceReactionTime.ets` | `!live \|\| pick >= 0` (207) | `:248 setTimeout → advance` |
| `GNBack.ets` | `warm() \|\| pick >= 0` (193) | `:246 setTimeout → advance`（`:253 pick = -1`） |
| `GStroopTest.ets` | `pick >= 0 \|\| nextTo >= 0` (175) | `:227 setTimeout → advance`（`:82 pick = -1`） |

### 5.2 `autoCell()/nextDiff()/nextMiss() < 0 ⇒ return true` 这一族 —— 死代码（不是 bug）

「没活儿干了」和「已经赢了」在正常流程里是**同一时刻**发生的，赢判定会在同一个同步调用里
把 `over` 置真，所以下一拍在 `:if (this.over) return false` 就被拦下，根本走不到那个分支。
逐款核到 4 个反例证明：

| 文件 | 分支 | 反证（赢判定同步触发） |
|---|---|---|
| `GRoomInspector.ets` | 195 `nextDiff() < 0` | `:251 if (f.length >= DIFFS) finish(true)` |
| `GSyllableStack.ets` | 192 `built >= parts.length` | `:268 if (this.built >= parts.length) this.next()` |
| `GTicTacToe.ets` | 341 `humanMove() < 0` | `:550 if (full(this.cells,...))` ⇒ `over = true` + 平局结算 |
| `GGomoku.ets` | 714 `bestMove() < 0` | `:788 steps >= cellCount()` ⇒ `over = true` + DRAW |

⇒ 本轮**不判它们为 bug**，但 `return true` 的语义仍是错的（应为 `false`），
建议随 §3.1 一起统一改掉，免得以后改动打破「同步性」时静默变卡死。

### 5.3 【9 款】字符串 `phase` 守卫 —— 全部由计时器推进

`GDirectionsRecall / GRelationalMemory / GRhythmMaster / GRunningMemorySpan / GSimonSays /
GSimonSequence / GSourceMonitoring` 等。扫描结论：所有 `phase` 赋值都在计时器可达函数内。

- `GRhythmMaster.ets:190` 的 `phase === 'done'` 与 GDirectionsRecall **形似但不同**：
  `:283` 和 `:302` 都是 `this.phase = 'done'; this.over = true;` **同时**置位 ⇒ 是终局，不是过渡态。
- `GRunningMemorySpan.ets:195` 的 `typed.length >= this.span` ⇒ 靠 `:250` 的
  `setTimeout(... startLevel ...)`（850ms）进下一关，等待合法。

### 5.4 【5 款】`if (false) { return true; }` —— 死分支（代码卫生问题）

`GDualMirror.ets:240`、`GEtymonOddball.ets:203`、`GHomophoneHunt.ets:197`、
`GPrimeHunter.ets:198`、`GWordSearch.ets:200`

```ts
238:  private autoStep(): boolean {
239:    if (this.over) { return false; }
240:    if (false) { return true; }        // ← 谁写的？原本这里应该有个守卫
242:    this.tap(this.mirrorNext());
```

像是某次修 bug 时把守卫条件整个删了、只留了壳。**不影响运行**，但说明这 5 款曾经有过
空转/越界问题，值得单独看一眼 `mirrorNext()/wsNext()` 在「没活儿了」时返回什么。

### 5.5 `GWaterSort` —— 两个已修 bug 的复核结果

**C 类（`runTop`）已修好**，写法正确：

```ts
158:  private runTop(st: number[], t: number): number {
159:    const c: number = this.topOf(st, t);
160:    if (c < 0) {
161:      return 0;
163:    let n: number = 0;
164:    let started: boolean = false;
165:    for (let k = CAP - 1; k >= 0; k--) {
166:      const v: number = this.at(st, t, k);
167:      if (v < 0) {
168:        if (started) {
169:          break;                     // ★ 只有「已经数到球之后」才 break
171:        continue;                    // ★ 顶部的空位先跳过
```

**D 类（`poured` 的 move=0）仍然存在，但已被 `legal()` 挡死**：

```ts
197:  private legal(st: number[], a: number, b: number): boolean {
198:    if (a === b) { return false; }
201:    const ca: number = this.topOf(st, a);
202:    if (ca < 0) { return false; }        // 源管空
205:    if (this.freeOf(st, b) === 0) { return false; }   // 目标管满
209:    if (cb < 0) { return !this.sameAll(st, a); }      // 单色管不许倒进空管
```

`poured` 只有 3 个调用点，全部被 `legal()` 前置拦截：

| 调用点 | 位置 | 谁保证合法 |
|---|---|---|
| `solvable()` | `:312` | `mv` 出自 `pickMove()`（`:261`），每个候选先过 `legal()` |
| `wsPlanGreedy()` | `:533` | 同上 |
| `tapTube()` | `:602` | 上一行 `:599 if (!this.legal(this.flat, a, t)) { ... return; }` |

AI 代打走的正是 `tapTube`（`autoStep:498/502/505`），所以 `move = 0` 不可达。
**结论：无需再动 `poured`。**

### 5.6 `GReversi` —— 没有 pass 逻辑，但 `beginTurn()` 兜住了

`autoStep:440` 的 `autoPick() < 0` 看着像「Reversi 无子可下必须跳过，这里会卡」。核到：

```ts
252:  private beginTurn(): void {
258:    if (mine.length === 0 && theirs.length === 0) { this.end(); return; }
263:    if (this.turn === BLACK && mine.length === 0) {
264:      this.turn = WHITE;                   // ★ 黑方无子 ⇒ 自动跳过
```

⇒ 轮到 BLACK 且无合法点时，`beginTurn` 立刻把 `turn` 交给 WHITE，`autoStep` 看到
`turn !== BLACK` 就等 AI 的 `AI_DELAY` 计时器，不会卡。**排除。**

### 5.7 整体健康度

- 355/355 的 `autoStep` 都有 `return false`（不存在「永不停止」型）。
- 所有 `for (k = CAP - 1; k >= 0; k--)` 形状的「从顶往下数」循环**只有 `GWaterSort` 一处**
  （`:140 topOf` / `:158 runTop` / `:222 poured`），无第二例同类风险。
- 「整盘落子」型函数（`poured` / `applyMove` / `apply`）全项目只有 4 个文件有
  （`GWaterSort:poured` / `GCheckers:apply` / `GFreecell:applyMove` / `GMancala:applyMove`），
  其余 351 款都走 `tap()` 风格 —— C/D 两类的排查面积实际只有这 4 个文件。

---

## 6. 附：无「AI 代打」文案的游戏 —— **0 款真缺，2 款是验证器假阳性**

按文件 grep 字面量「AI 代打」，有 2 款没命中：

| 文件 | 真相 |
|---|---|
| `GTentsAndTrees.ets` | 用共享组件 `HintBar` 渲染（`:579 onAutoTap: () => { this.askAuto(); }`），按钮文案在 `components/HintBar.ets:64` |
| `GTowerOfLondon.ets` | 同上（`:342 onAutoTap`） |

⇒ **355 款全都有 AI 代打按钮**，只是这 2 款的文案不在游戏文件里。
**验证器如果按「游戏文件里搜到 AI 代打」来判，这 2 款必误报。**

### 验证器「找不到 AI 代打」的 3 个**真**原因（都在 `components/HintBar.ets`）

1. **演示期按钮根本不渲染** —— `:131 if (!this.demoOn) { ...AI 按钮... }`
   进游戏后演示跑 3~6 秒，这段时间 `dump` 里**没有任何 AI 按钮节点**。
   ⇒ 必须**等 6 秒再找**，或者先 `aa force-stop` 后首次进入时跳过演示。
2. **极小屏 / 手表改短标签** —— `:59-65 tinyLabel()`，`Bp.tinyScreen() || Bp.isWatch()`
   时标签是 **「AI」/「停」**，不是「AI 代打」/「停代打」。
   ⇒ 195×195 圆屏上做文字匹配「AI 代打」**必然找不到**（判据 588 就是这么踩到的）。
3. **联机对战中改文案且禁用** —— `:136-138` 变成 **「联机禁用」/「联机」**，且 `.enabled(false)`。

> 建议验证器改成匹配 **`accessibilityText`**：那三个字段始终是完整句子
> （`:150-154`「AI 代打：让电脑替你走这一步」/「停止 AI 代打」），不受截断和短标签影响。

---

## 7. 给下一个人的 3 件事

1. **先修 §2.1**（353 款），否则任何「按钮文案」类断言都是废的。模板抄 `GPegSolitaire:388-404`。
2. **修 §2.2 / §2.3** 两处 `return true → false` + `stopAuto()`。
3. §3.1 表里除 2.2/2.3 之外的 18 款，统一把 `return true` 改成语义正确的 `false`
   （该补 `stopAuto()`），顺手清掉 §5.4 的 5 个 `if (false)`。

---

*扫描方法：`/tmp/aiscan/`（一次性脚本，未入库）。核心两步：① 注释/字符串感知的括号匹配，
精确取出 355 个 `autoStep` 体（首轮朴素正则会因字符串里的花括号把函数体算成 46 行，已废弃）；
② 全文件调用图 + 计时器可达性闭包，用来区分「等计时器复位」和「永久空转」。*
