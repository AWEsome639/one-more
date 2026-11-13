# `GStroopTest` 为什么可能不被创建 —— 只读代码分析

> 执行：verifier-eng2 ｜ ⛔ 未改 `.ets`、未改 `工具/*.py`、未编译、未碰设备、未 commit
> 证据等级：全部来自**当前工作树源码**（`git status` 对相关文件为空）+ `grep` 全库

## 0. 一句话结论

**最可能的原因不是「组件没创建」，而是「探针不在包里」**：
`GStroopTest.ets` **当前源码里既没有 `hilog` 调用、也没有 `import { hilog }`**，`grep -rn SDIAG` 全库 **0 命中**，且该文件**工作树干净**（最后三次提交都与 hilog 无关）。
⇒ 「编译进包」这句话与当前源码对不上；日志不出现**不需要**「组件未创建」来解释。

**如果确认探针真的在包里**，那唯一能「标题对、组件不存在」的代码级路径是：
**你当时在 `pages/GuidePage`（说明页）**——它显示同名标题 + 图标，但**不创建任何游戏组件**；
而且它的「开始玩」按钮**只是 `Back.go()` 返回列表**，不进游戏（`GuidePage.ets:346-356`）。

---

## 1. 先看一条硬证据（这决定了后面所有假设的方向）

| 检查 | 结果 | 命令/位置 |
|---|---|---|
| 全库 `SDIAG` | **0 命中** | `grep -rn "SDIAG" --include=*.ets .` |
| `GStroopTest.ets` 里的 `hilog` | **0 命中**（连 `import { hilog }` 都没有） | 对照 `GBinomialMatch.ets:17` **有** `import { hilog } from '@kit.PerformanceAnalysisKit'` |
| `GStroopTest.ets` 工作树状态 | **干净**（无未提交改动） | `git status --porcelain -- …/GStroopTest.ets` |
| 该文件最近 3 次提交 | 全是间距/重开/文案类，无 hilog | `git log --oneline -3` |

**⇒ 两个后果**：
1. 如果探针确实编译进了包，**工作树里应该有它**（哪怕是未提交改动）—— 现在没有；
2. 如果加了 `hilog.info` 却**没加 import**，ArkTS **编译会失败**；你说编译+安装都成功 ⇒ 更说明**被编译的源码里没有这行**。

**对照写法为什么"看起来正常却不公平"**：`GBinomialMatch` 的 `BinomialAI` 日志打在 **`autoStep` 的配对循环里**（`GBinomialMatch.ets:424/432`），**AI 代打开启后才触发、而且每步都打**；而 `aboutToAppear` **每个实例只跑一次**。两者不是同一类探针。

---

## 2. 假设表

| # | 假设 | 代码位置（Lnnn + 原文） | 是否成立 | 如果成立怎么验证 |
|---|---|---|---|---|
| **H1** | **探针没进包**（源码里没有） | `GStroopTest.ets:57-58`：`aboutToAppear(): void {` / `LanRace.noteStart(); this.startAt = Date.now(); this.reset();` —— **没有 hilog 行** | ✅ **最可能**（grep SDIAG=0、无 hilog import、工作树干净） | ① `grep -rn SDIAG entry/src/main/ets/` 应为 0；② 看编辑时间 vs HAP 编译时间；③ 重新加探针**同时加 import**再编 |
| **H2** | **你当时在说明页 `GuidePage`，不是游戏页** | `GameHost.ets:1175`：`router.pushUrl({ url: 'pages/GuidePage', params: { id: this.gameId } })`（页头 `?`）；`GamesTab.ets:1416`：长按菜单「查看说明」同样跳 `GuidePage`；`GuidePage.ets:269` `Text(this.meta ? this.gName() : '')` **显示同名标题**；`GuidePage.ets:346-356` 「开始玩」= `Back.go()`（**只返回列表**） | ⚠️ **成立且能解释全部现象**（标题对、无组件、无日志） | dump 看有没有「开始玩」按钮/「一句话玩法」卡（那是 GuidePage）；游戏页有棋盘/选项、没有「开始玩」按钮 |
| **H3** | **组件实例已存在，`aboutToAppear` 不会再跑** | `GameHost.ets:467` `@State nonce`、`:470` `@State diffTick`；`:895` `this.nonce = this.nonce + 1; this.diffTick = this.diffTick + 1;` | ⚠️ **只解释"日志只出现一次"，不解释"一次都没有"** | 清日志后**退出游戏页再从列表重进**（`router.pushUrl` 会新建页面 ⇒ 新实例） |
| **H4** | **`restartToken` 变化不会重建组件** | `GStroopTest.ets:25` `@Prop @Watch('onRestart') restartToken`；`:64` `onRestart(): void { … this.reset(); }` | ✅ **成立**（`@Watch` 不重建）—— 但**不影响** aboutToAppear 计数 | 见 H3 的验证法 |
| **H5** | **`diffTick` 奇偶翻转才真的重建** | `GameHost.ets:863` 注释原文：「③ `nonce + 1` + `diffTick + 1` 奇偶翻转 ⇒ 子组件**销毁重建**」；`:1267-1273` 重开按钮注释：「只 `nonce + 1` 走 `@Watch('onRestart')` ⇒ 组件不重建 ⇒ … ⇒ 同样先停代打、再切 `diffTick` 强制重建」 | ✅ **成立**（这正是那两个「一模一样的分支」的用途） | 清日志 → 点**重开** → 若探针在包里，`aboutToAppear` 必定再打一次 |
| **H6** | **分支不可达 / 被别的分支截走** | `GameHost.ets:3037` `} else if (this.gameId === 'stroop_test') {`；全链全是 `=== 'id'` 精确匹配；`grep indexOf('stroop')/startsWith('stroop')` = **0** | ❌ **不成立** | — |
| **H7** | **`gameId` 不匹配 ⇒ 渲染 `placeholder()`** | `GameHost.ets:3422` `} else { this.placeholder() }`（链尾） | ❌ **不成立**（标题正确 ⇒ `meta=findGame(gameId)` 成功，`GameHost.ets:551`） | 若真的 gameId 错，标题会是空/「这一款还在路上」占位 |
| **H8** | **两个分支一样 ⇒ 死代码/写错** | `GameHost.ets:3038-3042`：`if (this.diffTick % 2 === 0) { GStroopTest(…) } else { GStroopTest(…) }`（**两行完全相同**） | ❌ **不是写错**：这是**全库 355 款统一的"强制重建"惯用法**（见 H5 的两处注释） | 随便翻一款（如 `G2048` `GameHost.ets:1293-1296`）都是同样写法 |
| **H9** | **`aboutToAppear` 在探针前抛异常** | `GStroopTest.ets:58` `LanRace.noteStart(); this.startAt = Date.now(); this.reset();`；`LanRace.ets:115-120`：`if (!LanRace.racing) { return; }` **提前返回、不抛**；`reset()` 只做状态赋值 + `nextQuestion()`（纯 Math/常量） | ❌ **极低**（这条路径没有抛出点） | 把探针放在**第 1 条语句**（`LanRace.noteStart()` 之前）就能排除 |
| **H10** | **hilog 被 release 构建裁掉** | 同一构建里 `GBinomialMatch` 的 `BinomialAI` 有 3 条 ⇒ hilog 通道正常 | ❌ **不成立** | — |
| **H11** | **跑的是旧包** | `bm dump` 的 `updateTime` 与 HAP 的构建时间 | ⚠️ **待外部核对** | `bm dump -n com.andrewoscar.onemore \| grep updateTime` 比对你的编译完成时间 |

---

## 3. 你问的 4 个问题，逐条回答

**Q1：`L3037` 那两个分支是不是完全一样？为什么要两个？**
**完全一样，且是故意的。** 它们是全库统一的「**奇偶翻转强制重建**」惯用法：
`diffTick % 2` 的**分支奇偶**才是开关 —— ArkUI 把 `if` 的两支当成不同分支，翻一次就销毁重建一次，
从而让子组件 `autoId` 归零、状态清空（见 `GameHost.ets:863` 与 `:1267-1273` 的注释）。
**不是死代码，也不能合并**（合并后就再也重建不了了）。

**Q2：`diffTick` 为奇数时渲染什么？会不会渲染占位/预览？**
**渲染同一个真组件**（`else` 分支）。整个 if 链里**唯一**会渲染占位的是 `gameId` 不匹配任何分支 ⇒
`GameHost.ets:3422` `} else { this.placeholder() }`（文案「这一款还在路上」）。没有"预览组件"这条路。

**Q3：有没有 `@Builder`／`if` 让 `GStroopTest` 走不到？**
- **没有 `@Builder` 包装**：`GameHost.ets:1289` 注释原文「── 游戏区（直接内联，不走 @Builder）──」；
- **没有宽松匹配**截走 `stroop_test`（全链 `===`，`indexOf/startsWith('stroop')` = 0）；
- **真正的另一条路**是你的页面可能根本**不是 GameHost**：页头 `?`（`:1175`）和列表长按「查看说明」（`GamesTab:1416`）都会把页面推到 **`GuidePage`** —— 它显示同名标题，但**不创建任何游戏组件**（`grep -cE 'GStroopTest|G2048|GReverseStroop' GuidePage.ets` = **0**）。

**Q4：`restartToken` 变化会不会重建？`hilog -r` 后进游戏会不会命中已存在组件？**
- **`restartToken`（`nonce`）变化：不会重建**，只触发 `@Watch('onRestart')`（`GStroopTest.ets:25/64`）；
- **`diffTick` 奇偶翻转：会重建**（H5）；
- 所以「清日志后命中已存在组件」**只在一种情况下成立**：你**没有离开这个页面**、也**没点过重开/再来一局/切换游戏**。
  **反证**：GameHost 的重开按钮会 `nonce+1` **且** `diffTick+1`（`:1272-1273`）⇒ 重建 ⇒ `aboutToAppear` 必再跑一次。
  ⇒ 如果你清日志后点过重开还没有日志，那 H3 也可以排除，回到 H1。

---

## 4. 最可能的原因（按概率排序）与 3 步验证

| 排序 | 原因 | 为什么排这里 |
|---|---|---|
| **1** | **探针没进包**（源码里就没有） | 唯一有**硬证据**的：`grep SDIAG=0` + 无 `hilog` import + 工作树干净 |
| **2** | **打开的是 `GuidePage` 说明页** | 唯一能在代码上解释「标题正确 + 组件不存在」的路径；而且它的「开始玩」只 `Back.go()`，**很容易让人以为自己进了游戏** |
| **3** | 组件实例已存在（清日志后没重建） | 只解释"只出现一次"，不解释"一次都没有" |

**验证三步（30 秒，不用改代码）**
1. **确认屏幕是哪个页面**：dump 里找「开始玩」按钮 / 「一句话玩法」——有 ⇒ 是 `GuidePage`（不是游戏）；
   游戏页应该有棋盘/四个颜色选项、**没有**「开始玩」。
2. **确认包里有没有探针**：`grep -rn SDIAG entry/src/main/ets/`（应为 0）；再对比 HAP 构建时间与你编辑该文件的时间。
3. **用"必定会跑"的探针重试**：把 `hilog.info(0x0000,'SDIAG','mount')` 放在 `aboutToAppear` **第一行**，**同时补 `import { hilog } from '@kit.PerformanceAnalysisKit';`**，
   编完装完 → 清日志 → **从列表点卡片进游戏**（不要走 `?`）→ 若仍无日志，再考虑 H11（旧包）。

## 5. 结论

- **「`GStroopTest` 的实例没被创建」这个结论目前没有证据支撑** —— 支持它的现象（无日志）有更简单的解释：**探针不在包里**。
- 代码层面，**不存在**「`stroop_test` 走到别的分支」或「被 `@Builder` 挡住」的路径；
  唯一能"标题对但没组件"的是 **`GuidePage`**。
- **`restartToken`/`nonce` 这条只影响"日志只出现一次"，不影响"一次都没有"**；而且**重开会强制重建**，所以如果你重开过，就直接排除它。

## 边界

- 只读：未改 `.ets`、未改 `工具/*.py`、未编译、未碰设备、未 commit。
- 所有代码位置取自**当前工作树**（行号可能与你的编辑版本差几行，已附原文便于全文匹配）。
- `H2`（GuidePage）是**代码可证**的路径，但「你当时在哪个页面」只能靠 dump/截图确认 —— 我没有做设备侧验证。

---

## 已排除 `GuidePage` 假设（真机实测）

**按队友第 `1` 步验证：**
```
文本数: 23 | 前 6: ['‹', '斯特鲁普', '字义与颜色冲突', '☆', '?', '普通']
有「开始玩」: False
有「一句话玩法」: False
```
**⇒ 屏幕上**没有** `GuidePage` 的「开始玩」/「一句话玩法」⇒ **是真正的游戏页。**

**⇒ 所以「组件没创建」这条也排除了。**

## `Stroop` 的最终状态（`5` 次尝试后）

**已排除 `6` 种可能：**
① 矮屏判定失效（`Wordle` 反证）② 包没更新（HAP 时间戳）
③ 组件映射错（`stroop_test` → `GStroopTest`）④ `GuidePage` 冒充游戏页（真机实测排除）
⑤ `layoutWeight` 吃掉高度（`Row` 上加高度零效果）⑥ `Cell.of` 缩放（算得出 `53vp`，实测 `43vp`）

**⇒ 但 `aboutToAppear` 的日志就是不出来（同 App 的 `GBinomialMatch` 日志正常）。**

**⇒ 这已经超出「读代码 + 改代码 + CLI 看 dump」能解决的范围。
明天必须用 DevEco Studio 调试器下断点，或者干脆**用另一款同构游戏反推**
（找一款「选项行也超出屏底」的其他游戏，看它是怎么修的）。**
