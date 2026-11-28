# 2.0.1 今日改动回归审查（2026-11-28 00:00 之后）

- 审查对象：`D:\work\one-more`，基线 `59a852ce`（2026-11-27 23:39）→ `HEAD`
- 取数命令：`git log --since='2026-11-28 00:00' --name-only --format='' | grep '\.ets$' | sort -u` → **98 个 .ets**
- 看的是 diff 不是全库：`git diff -U3 59a852ce..HEAD -- '*.ets'` → 599 insertions / 381 deletions
- 只用只读命令（git log/diff/show + 读文件）；**未改仓库、未编译、未连设备**（`git status --porcelain` 为空）
- 结论：**9 条高置信度**（均可复算，逐条给出改前/改后与算式）

分布：规则文案与实际判定不同源 1 条 · 新增字段只在 reset 生效 1 条 · 结算与按钮互相矛盾 1 条 · 阈值缩放未同步到 HUD/帮助文案 4 条 · "差 X 题"写成通关线 1 条 · 新公式被 10 秒下限吃掉 1 条 · 热循环副作用 1 条。

---

## 1. `entry/src/main/ets/games/GWordAssociationRecall.ets:138`（高）

**改前**
```ts
this.leftMs = this.total; this.msg = TG(TG('记住每一组搭配，9 秒后开始回忆'));
```
**改后**
```ts
this.leftMs = this.total;
this.msg = TG2('记住每一组搭配，{0} 秒后开始回忆', String(Math.round(this.total / 1000)));
```
**判定侧没改**（`:155`）：`const limit: number = this.phase === 0 ? STUDY_MS : Q_MS;`

**为什么是错的（复算）**
`STUDY_MS = 9000`，`total = GameDiff.timeNow(9000)`，`time()` = `round(base × 1.5/1/0.7)`：
- 简单 13500 → 文案"14 秒"，但 `tick()` 在 `gap >= 9000` 就切到回忆 ⇒ 实际 9 秒，**文案多 5 秒**
- 普通 9000 → 9 vs 9 ✅
- 困难 6300 → 文案"6 秒"，实际仍是 9 秒，**文案少 3 秒**

改前那句"9 秒"正好等于 `STUDY_MS`，是对的；今天把文案换成按难度缩放的 `total`，而真正决定翻页的常量没跟着改，于是简单/困难两档的说明与实际行为当场对不上（`leftMs` 只参与 tick 判定、没有上屏，所以唯一可见症状就是这句秒数说错）。

**一行修法**：`:155` 改成 `const limit: number = this.phase === 0 ? this.total : Q_MS;`（让倒计时、翻页、文案三者同源）。

---

## 2. `entry/src/main/ets/games/GEtymonOddball.ets:275`（高）

**改前**：没有 `limitS()`，全档每题恒 20 秒（`LIMIT_S`），三档自洽
```ts
:86   @State leftS: number = LIMIT_S;
:275  this.leftS = LIMIT_S;
:349  ... Digits(String(LIMIT_S), this.langCode)     // 文案"每题 20 秒"
```
**改后**（今天新增了 `limitS()`，但只接到 `reset()`）
```ts
:81  private limitS(): number { return Math.max(5, Math.round(GameDiff.timeNow(LIMIT_S * 1000) / 1000)); }
:105 this.round = 0; ... this.leftS = this.limitS();      // reset 用上了
:275 this.leftS = LIMIT_S;                                 // 每题切下一题仍是常量 20
:349 ... Digits(String(LIMIT_S), this.langCode)             // 文案仍是 20（未同步）
```

**为什么是错的（复算）**
`LIMIT_S = 20`，`timeNow(20000)` = 30000 / 20000 / 14000 → `limitS()` = **30 / 20 / 14** 秒。
`advance()` 在每答完一题后把 `leftS` 重置为 `LIMIT_S`，所以：
- 简单档：第 1 题 30 秒，第 2 题起掉回 20 秒（且 `score = ... + leftS*10` 的加分也跟着第一题虚高）
- 困难档：**永远拿不到 14 秒**，全部 20 秒 —— 今天这条修复在困难档等于没生效

`reset()` 与 `advance()` 是同一语义的两个入口，新字段只初始化了其中一个（正是"reset/重开是否都初始化"这一类）。

**附带同类点**：`:349` 帮助文案 `"共 {0} 轮，答对 ≥{1} 通关；每题 {2} 秒"` 第 3 个参数仍是 `LIMIT_S`（印 20），改成 `limitS()` 后应同步。

**一行修法**：`:275` 改 `this.leftS = this.limitS();`；`:349` 第三参数改 `Digits(String(this.limitS()), this.langCode)`。

---

## 3. `entry/src/main/ets/games/GCryptogramAll.ets:361`（高）

**改前**：结算与按钮都用 `PASS`
```ts
:262  gameId: 'cryptogram_all', solved: this.right >= PASS,
:361  Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
```
**改后**：只改了结算
```ts
:262  gameId: 'cryptogram_all', solved: this.right >= Math.max(1, Math.round(PASS * this.diffTotal / TOTAL)),
:361  Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))   // 未同步
```

**为什么是错的（复算）**
`TOTAL = 8`，`PASS = 6`，`diffTotal = sizeNow(8)` = 6 / 8 / 10：
| 档 | 题数 | 实际通关线 `round(6·n/8)` | 按钮判定 `>= 6` |
|---|---|---|---|
| 简单 | 6 | 5 | 5 分算通关，但按钮印「结束」 |
| 普通 | 8 | 6 | 一致 |
| 困难 | 10 | 8 | 答对 6/7 时按钮印「通关 🎉」，而成绩记为失败 |

同一屏上，成绩（`solved`）和按钮文字对同一局给出相反结论 —— 玩家最容易看到的那处没改。

**一行修法**：`:361` 的条件换成与 `:262` 完全相同的表达式（或抽一个 `need()` 方法两处共用）。

---

## 4. `entry/src/main/ets/games/GColorWordMatchUp.ets:338`（中高）

**改前**：判定与文案都用 `PASS`
```ts
if (this.trial >= this.diffTotal) { this.end(this.correct >= PASS); return; }
Text(TG2('答满 {0} 题且答对 ≥ {1} 即通关', Digits(String(this.diffTotal), ...), Digits(String(PASS), ...)))   // 现 :338
```
**改后**：只改了判定
```ts
:239  if (this.trial >= this.diffTotal) { this.end(this.correct >= Math.max(1, Math.round(PASS * this.diffTotal / TRIALS))); return; }
:338  ... Digits(String(PASS), this.langCode)      // 仍是 16
```

**为什么是错的（复算）**
`TRIALS = 24`，`PASS = 16`，`diffTotal = sizeNow(24)` = 17 / 24 / 31 → 通关线 = `round(16·n/24)` = **11 / 16 / 21**。
- 简单档：帮助页说"答对 ≥ 16"，实际 11 就通关（多要求 5 题）
- 困难档：帮助页说"答对 ≥ 16"，实际要 21（少报 5 题）

同一句里"答满 {题数}"已经随难度（`diffTotal`）走，后半句却还是常量，句子内部自相矛盾。

**一行修法**：`:338` 第二参数改 `Digits(String(Math.max(1, Math.round(PASS * this.diffTotal / TRIALS))), this.langCode)`。

---

## 5. `entry/src/main/ets/games/GTripletsLogic.ets:274`（中高）

**改前**：`if (this.asked >= this.diffTotal) { this.finish(this.hits >= NEED); return; }`，HUD 印 `hits/NEED` → 自洽。
**改后**：判定缩放（`:244`），HUD 没动（`:274`）
```ts
:244  if (this.asked >= this.diffTotal) { this.finish(this.hits >= Math.max(1, Math.round(NEED * this.diffTotal / ROUNDS))); return; }
:274  Text(TG4('第 {0}/{1} 题 · 答对 {2}/{3}', ..., this.hits, NEED))    // {3} 仍是 4
```

**为什么是错的（复算）**
`ROUNDS = 6`，`NEED = 4`，`diffTotal = sizeNow(6)` = 4 / 6 / 8 → 通关线 = `round(4·n/6)` = **3 / 4 / 5**。
- 简单档：HUD 停在"答对 3/4"时其实已经通关（分母虚高 1）
- 困难档：HUD 走到"4/4"看起来满了，实际还要再对 1 题（分母虚低 1）—— 玩家会以为"已经达标却输了"

**一行修法**：`:274` 第 4 参数改 `Math.max(1, Math.round(NEED * this.diffTotal / ROUNDS))`。

---

## 6. `entry/src/main/ets/games/GSourceMonitoring.ets:278`（中高）

**改前**：`this.finish(this.score >= NEED)`，HUD 印 `score/NEED` → 自洽。
**改后**：判定缩放（`:247`），HUD 没动（`:278`）
```ts
:247  if (this.q + 1 >= this.diffTotal) { this.finish(this.score >= Math.max(1, Math.round(NEED * this.diffTotal / 5))); return; }
:278  + TG4('　答对 {0}/{1}　倒计时 {2}s', this.score, NEED, this.left, '')     // {1} 仍是 4
```

**为什么是错的（复算）**
`QUIZ = 5`，`NEED = 4`，`diffTotal = sizeNow(5)` = 4 / 5 / 7 → 通关线 = `round(4·n/5)` = **3 / 4 / 6**。
- 困难档：HUD 上限写 4，实际要 6 ⇒ 屏幕上会出现"答对 5/4"却仍未通关
- 简单档：写 4，实际 3 ⇒ 提前通关而 HUD 显示不满

**一行修法**：`:278` 第二参数改 `Math.max(1, Math.round(NEED * this.diffTotal / 5))`（顺手把分母 `5` 换成 `QUIZ`，与 `:62 sizeNow(5)` 对齐）。

---

## 7. `entry/src/main/ets/games/GBaseShift.ets:390`（中）

**改前**
```ts
: TG2('😵 只答对 {0}/{1}，差 {2} 题', String(this.right), String(this.diffTotal), String(PASS))
```
**改后**
```ts
: TG2('😵 只答对 {0}/{1}，差 {2} 题', String(this.right), String(this.diffTotal),
      String(Math.max(1, Math.round(PASS * this.diffTotal / TOTAL))))     // 少了 "- this.right"
```

**为什么是错的（复算）**
`TOTAL = 10`，`PASS = 7`，`diffTotal = sizeNow(10)` = 7 / 10 / 13 → 通关线 = **5 / 7 / 9**。
简单档答对 2 题：文案印"差 5 题"，实际只差 3 题；答对 0 题时才碰巧对。
今天同一批把**另外 8 个同款文件**（`GBinaryMatrixRank:351`、`GCommonDenominator:336`、`GFractionMatcher:269`、`GInequalityBalanceOps:255`、`GSetTheoryVenn:250`、`GTargetNumber:338`、`GUnitConverterPro:315`、`GVectorDotProduct:278`）都改成了 `... - this.right`，只有这一处只换了被减数没做减法 —— 属批量替换漏改，不是设计。

**一行修法**：`:390` 末尾补 `- this.right`。

---

## 8. `entry/src/main/ets/games/GFaceNameAssociation.ets:75`（中）

**改前**：`private total: number = GameDiff.timeNow(SHOW_SEC);`（`SHOW_SEC = 5`）
**改后**
```ts
:74  // ★ 2026-11-28（第六批·中）：timeNow 有 10 秒下限，timeNow(5) 三档都变成 10 ⇒ 改成 timeNow(10)（15/10/7）。
:75  private total: number = GameDiff.timeNow(SHOW_SEC * 2);
```

**为什么是错的（复算）**
`GameDiff.time()` 的收尾是 `const v = Math.round(base * timeScale); return v < 10 ? 10 : v;`。
`timeNow(10)`：简单 `round(15)=15`、普通 `10`、困难 `round(10×0.7)=7 → 7 < 10 → 被抬回 10`。
所以实际是 **15 / 10 / 10**，不是注释写的 15/10/7 —— 困难档的记忆时间与普通档完全相同，今天这处"修难度"只修好了简单档，注释里的 7 是被 `time()` 的下限吃掉的（把注释当真值）。
`:120` 的计时器是 `secLeft = secLeft - 1`（每 1000ms 一次），即 `total` 的单位是**秒**，所以这个值直接就是玩家看到的记忆秒数。

**一行修法**：绕开毫秒下限，直接用秒的倍率算：
```ts
private total: number = Math.max(4, Math.round(SHOW_SEC * 2 * GameDiff.timeScale(GameDiff.gameId())));
```
（15 / 10 / 7）

---

## 9. `entry/src/main/ets/games/GFlappy.ets:268`（中，副作用类）

**改前**：`if (this.score >= PIPE_GOAL && !this.endless) {`
**改后**
```ts
:148  private goalPipes(): number { return GameDiff.sizeNow(PIPE_GOAL); }
:268  if (this.score >= this.goalPipes() && !this.endless) {
```

**为什么是错的（可复算）**
`:268` 在 `tick()` 里，而 `TICK_MS = 16` ⇒ **62.5 次/秒**。`GameDiff.sizeNow()` 每次都会走 `GameDiff.log()`，后者是：
`AppStorage.get<string>('diffLog')` → `split(';')` → 过滤重建（最多 400 条）→ `join(';')` → `AppStorage.setOrCreate`。
等于把"每帧读一次全局存储 + 重建最多 400 段字符串 + 写回"挂到 16ms 循环上；同一 tick 内 `:292`（`msg` 文案）还会再调一次，`build()` 里的 `:717`、`:739` 每次重渲染各再调一次。数值没错，但把常量换成函数调用时，把带副作用的日志打进了热路径（`sizeNow` 是"会写 AppStorage"的函数，不是纯函数）。

**一行修法**：缓存成字段（`private goal: number = 0;`，`reset()`/`onRestart()` 里 `this.goal = GameDiff.sizeNow(PIPE_GOAL)`），tick 里读字段。

---

## 已核查、未发现问题（给复核者的边界，避免重复劳动）

1. **分母用错常量（重点怀疑项）**：把今天全部 46 处 `PASS / NEED / WIN_RIGHT / 10 / 8 × diffTotal / <分母>` 的分母逐个与所在文件的模块常量对齐，**没有发现把 TRIALS 的公式抄进 ROUNDS 游戏**——例如 `GColorWordMatchUp` 用 `TRIALS(24)`、`GCognateCatch` 用 `ROUNDS(12)`、`GSwitchTask` 用 `TRIALS(12)`、`GArithmeticChain` 用 `LEVELS(5)`，均与本文件 `sizeNow(同一个常量)` 一致。`GSourceMonitoring` 的分母写死 `5`，但它的 `sizeNow(5)` 也是 5，数值正确（仅可读性，不计入缺陷）。
2. **除零 / 边界**：所有缩放都套了 `Math.max(1, Math.round(...))`；分母都是 ≥5 的常量，不存在 0 分母；`Math.min(池长, sizeNow(...))` 共 6 个文件（`GComplexFoldingNets`/`GContextClues`/`GRelationalMemory`/`GTemporalOrder`/`GTypoglycemiaDecoder`/`GTrailMaking`），池长最小 6（`GTemporalOrder` SETS、`GTypoglycemiaDecoder` BANK、`GRelationalMemory` POOL/2=6 整数），**没有出现 0 题或 1 题档**，`Math.max(1, ...)` 也兜住了"通关线 = 0"。
3. **池/下标越界类的补丁是对的**：`GEtymonOddball` GROUPS=10 ≥ 硬档 10、`GGrammarSort` BANK=24 ≥ 硬档 21、`GContextClues` POOL=13 = 硬档 13、`GTemporalOrder`/`GTypoglycemiaDecoder` 的池都只有 6（硬档 7 被夹回 6，通关线随之回落，不是 0/1 题）、`GTrailMaking` TOTAL=25、`GComplexFoldingNets` SEED=8 的夹取均成立；`GTennerGrid` 把 givens 从固定 55 改成 `0.55n²`（7×7=27、13×13=93）正确；`GTentsAndTrees` `max(2, n²/4)`、`GSumSnake` 蛇头取 `n²`、`GMazeNav3d` 按 4 层分配（`W·H·4=100`，`pick(2,3,4)` 上界 4）均无越界。
4. **结构类复算通过**：`GMancala` 下标派生自洽（`boardN=2n+2`、`myStore=n`、`oppStore=2n+1`、镜像 `2n-last`、双方坑区间 `n+1..2n`、LAN 仍钉 6 坑）；`GCheckers` 4×4 每方 1 行（2 枚）确实避免了"深色格占满"；`GBoxCompletion` `target=2(h0+w0)` 恰好等于 h0+1 × w0+1 矩形的周边格数（`2(h+w)-4`）；`GSymmetrySpan` 取 `floor(n/2)` 列对奇数边正确（中间列镜像到自己）；`GCountingSpan` `gridN/livesN/maxCount`、`GColorMatch` 目标 70/95/125、`GKenken` 28、`GHueSort` `REQUIRED+3`、`GFlappy` 8/12/16 均为数值一致的平衡调整。
5. **新增 i18n 键**：今天新增的 7 个 `{0}/{1}` 模板（`记住每一组搭配，{0} 秒后开始回忆`、`点亮空格，把边框补成 {0} 格 📐`、`提示：不区分大小写；{0} 秒没打完算这句错`、`判定：正确 ≥ {0}/{1}；≤ 4 个靠直觉…`、`判定：正确 ≥ {0}/{1}；答的是墨色…`、`通关线 {0}`，以及复用的 `判定：正确 ≥ {0}/{1}` 已在 `GameI18n.ets:10223`）参数个数与调用一一对应，无 `{n}` 缺参/多参或顺序错。
6. **文案数字与代码对得上的**：`GStroopTest`/`GStroopNumberSize`/`GStopSignal`/`GSubitizingRush`/`GReverseStroop` 的判定行都已按同一表达式生成；`GFaceNameAssociation` 以外没有第二处"文案说秒数、代码用常量"的（`GTypingSpeed`、`GWordScramble`、`GMultiTrackCounter` 三处已把 `total/limitMs` 接到判定与显示，仅 `GTypingSpeed` 困难档 `17.5s` 会被 `Math.round` 印成 18 秒，属显示取整，不计入）。

## 建议修复顺序

1. 第 1、2、3 条（玩家直接看到"规则/结算/按钮"与实际不符）
2. 第 4、5、6 条 —— 同一类批量遗漏（今天已建 `scan_hud_const`，但仍有 3 处 HUD/帮助文案 + 1 处按钮判定漏网），建议把扫描口径从"常量出现在 Text 里"扩到"任何与缩放阈值同义的展示位"
3. 第 7 条（补 `- this.right`，与同批 8 处对齐）
4. 第 8 条（秒数换算显式化，别再依赖 `timeNow` 的毫秒口径）
5. 第 9 条（缓存 `goalPipes`）
