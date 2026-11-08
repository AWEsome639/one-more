# `StatsCard`（桌面小组件）竖屏 / 手表适配巡检 · 2026-11-08

> **只读巡检**：未改任何代码，本文件是唯一产物。
> **断言基线**：`bash 工具/check_assertions.sh` ⇒ **200359 / 0** ✅
> **官方依据**：本地 HarmonyOS SDK 文档（`hms_docs`）——
> 「配置ArkTS卡片的配置文件 / arkts-ui-widget-configuration」「如何根据不同尺寸的卡片适配不同的UI / faqs-form-19」
> **未上真机**（判据 1814 的 dump 步骤写在 §7，需要时按那个走）

---

## 0. 四个问题速览

| 问题 | 答案 |
|---|---|
| ① `StatsCard` 有没有 `tinyWatch`/`tinyScreen` 分支？ | **0 处**。而且**写了也没用** —— `Bp` 只在 App 主进程由 WindowStage 初始化，**Form 渲染进程里永远是默认 360×780** ⇒ 两个判断恒为 false |
| ② 手表 195×195 上能显示什么？ | 卡片的**自然尺寸 ≈ 124vp 高 × ≥120vp 宽**（正文字号档）。手表 2\*2 卡片远小于这个数 ⇒ **会溢出**（标题先换行 → 进度条/底部文案被裁）。详见 §2 |
| ③ 手表版最小清单 | 留 **LV 环 + 等级 + 称号 + 今日打卡 + 进度条**；删 **品牌名 / 🔥 连胜 / 底部文案 / 副标题**。目标 ≤ 90vp 高。**前置**：先补「尺寸检测」（官方做法，见 §3.2）|
| ④ `formwidget/` 还有别的组件吗？ | **没有**。只有 `StatsCardAbility.ets` + `pages/StatsCard.ets` 两个文件 |

**一句话**：`StatsCard` **不是"没适配手表"，而是"连尺寸感知都没有"** ——
它按 2\*2 桌面卡写死了一套固定 vp 布局，而 `form_config.json` 又**没有任何手表声明**
（缺 `previewImages`、`2*4` 手表不支持、`2*3`/`3*3` 没配）⇒ 手表上就算能加，也只有"溢出的一张卡"。

---

## 1. 现状：formwidget 只有两个文件

```
entry/src/main/ets/formwidget/
├── StatsCardAbility.ets        (11.6 KB)  ← FormExtensionAbility：读进度 + 本地化文案 + 注入数据
└── pages/StatsCard.ets         ( 6.7 KB)  ← 卡片 UI（单页，@Entry(storage)）
```

- 配置：`entry/src/main/resources/base/profile/form_config.json`（1 个卡片，`uiSyntax: arkts`）
- 注册：`module.json5` 的 `extensionAbilities → StatsCardAbility`（`type: form` + `ohos.extension.form` metadata）
- **没有**第二个卡片、没有独立的"手表卡"、没有 `pages/` 下的其他页面。

---

## 2. ① `tinyWatch` / `tinyScreen` —— 0 处，而且写了也无效

### 2.1 代码里确实一处都没有

```bash
grep -n "Bp\.\|tinyWatch\|tinyScreen" entry/src/main/ets/formwidget/pages/StatsCard.ets
# → 只有 @LocalStorageProp / @UiMode，**没有任何 Bp 引用**
```

### 2.2 更关键：在 Form 里 `Bp` 根本不成立

`Bp` 的值只有一条来源（`core/Bp.ets:48`）：

```ts
static update(w: number, h: number, dev?: string): void { Bp.width = w; Bp.height = h; ... }
```

`Bp.update()` 只被 **App 主进程的 WindowStage** 调用（`EntryAbility.onWindowStageCreate` 链路）。
而卡片跑在 **Form 自己的渲染进程**（Form Kit 的卡片渲染环境），那里：

- 没有 WindowStage、没有 `windowStage.getMainWindowSync()`；
- `Bp.width/height` 保持类字段默认值 **360 / 780**（`Bp.ets:33-35`）

⇒ `Bp.tinyWatch()`（`height < 210`）**恒 false**，`Bp.tinyScreen()`（`height < 340`）**也恒 false**。

> ⚠️ 这条对"给 355 款游戏补手表布局"同样成立：**凡是靠 `Bp` 判断设备尺寸的代码，搬进卡片都不起作用**。
> 卡片要用的是 **`formInfo.FormParam.DIMENSION_KEY`**（官方唯一做法，见 §3.2）。

### 2.3 卡片里唯一"能感知尺寸"的东西：`height('100%')`

根 `Column` 只写了 `.width('100%').height('100%')` ⇒ **跟随卡片容器**，
但**内部所有元素都是固定 vp**（40 的 LV 环、13/16/10/9 的字号、12 的 padding、8 的间距）
⇒ 容器变小，内容**不会跟着缩**，只会被裁。

（官方 FAQ 原话：「**卡片字体大小、边距等需自行调配，不会自动适配大小**」—— 与我读代码的结论一致。）

---

## 3. ② 手表 195×195 上能显示什么

### 3.1 卡片的自然尺寸（按 normal 档 token 算）

| 行 | 内容 | 高度（≈字号×1.4）|
|---|---|---:|
| ① 顶行 | `One More`（`FontSize.xs`=13）+ 可选 🔥 连胜（11）| **18.2** |
| ② 主行 | LV 环 `Circle` **40×40** + 称号（16）+ 副标题（10）| **40**（被环撑住）|
| ③ 进度条 | `Row().height(5)` | **5** |
| ④ 底行 | 底部文案（9）| **12.6** |
| 合计内容 | | **75.8** |
| + 3 个 `space: 8` | | +24 |
| + `padding(Space.snug=12)` 上下 | | +24 |
| **自然高度** | | **≈ 123.8 vp** |

**自然宽度下限**（横向不会再缩）：`12 + 40(LV 环) + 8(间距) + 标题最小可读 ~48 + 12 = **≈120 vp**`

**大字模式（elder）下还要再涨**：`FontSize` 13→18 / 16→21 / 9→15、`Space.snug` 12→16
⇒ 高度 **≈ 155 vp**、宽度 **≈ 145 vp**。

### 3.2 手表上的 2\*2 卡片大概多大

官方**不给固定 vp**（FAQ 明确说「尺寸与基础参数是设计标准画板，实际真机卡片尺寸各不相同」）。
可用的两个参照：

| 参照 | 数值 | 来源 |
|---|---|---|
| 手表屏宽 | **195vp** | 项目 `Bp.tinyWatch()`（高 < 210）；`Common.ets:1250` 注释「195vp 屏」|
| 项目内 195 屏上的 2 列卡片 | **≈ 80vp 宽** | `Common.ets:1250`「195vp 屏上卡片只有约 80vp 宽」（那是**游戏列表卡**，不是卡片）|

2\*2 桌面卡在手表上的实际边长，官方没有数字。按手表桌面通常是 **3~4 列宫格**估：
`195 / 4 ≈ 49 | 195 / 3 ≈ 65` ⇒ **2\*2 卡片 ≈ 98~130vp 见方**。

### 3.3 结论：**必然溢出**

| 维度 | 需要 | 手表 2\*2（估 98~130） | 结果 |
|---|---:|---|---|
| 高 | **124**（elder 155）| 98~130 | **溢出**（elder 下必定；normal 在 98~124 区间也会）|
| 宽 | **≈120**（elder 145）| 98~130 | **宽度临界/溢出** |

**溢出时会发生什么**（按渲染顺序）：

1. 标题 `this.title`（如「渐入佳境」）**没有 `maxLines`** ⇒ 在 40vp 的窄列里**换成 2~3 行**，把整块往下顶；
2. 进度条（`height(5)`）与底部文案被推到 `.height('100%')` 之外 ⇒ **直接被裁**；
3. 底部的**「今天还没玩 / 今日已打卡」这条最重要的信息正好在第 ② 行的第二列**，宽度不够时会被省略号吃掉；
4. LV 环固定 40vp，在 98vp 宽的卡里**占掉 40% 宽度**，剩给文字 ≈ 26vp ⇒ 称号只显示 1~2 个字。

**换句话说：手表上这张卡大概率是"一个紫色圆圈 + 半行被截的中文 + 看不见的进度条"。**

### 3.4 还有一个隐藏的叠加：`fontScaleFollowSystem`

`form_config.json` **没有配** `fontScaleFollowSystem`，官方文档说**缺省为 true** ⇒
卡片字号**跟随系统字体大小**。而我们又刚给它接了 `UiModeMgr.apply(uiMode)`（App 的"大字模式"）。
⇒ **两套放大逻辑并列**：系统字体放大 ×1.3 与 elder 档 ×1.375 可能叠加到 **×1.8**。

（这与"卡片跟随大字模式"那一批不冲突，但需要在手表/大字两个场景同时开时真机确认。）

---

## 4. ③ 手表版最小清单

### 4.1 前置：先补「尺寸检测」（否则一切都是猜）

**官方唯一做法**（`faqs-form-19`）：

```ts
// StatsCardAbility.onAddForm(want)
const dim: string = JSON.stringify(want.parameters[formInfo.FormParam.DIMENSION_KEY]);
// → 塞进 formBindingData → 卡片 @LocalStorageProp('dimension') → 按尺寸选 UI
```

`StatsCardAbility.onAddForm` **现在完全没用 `want`**（只读统计 + uiMode）⇒ 这是第一块缺口。

⚠️ 备选方案（若不想改 Ability）：卡片根节点 `.onAreaChange` 测实际宽高 —— 但**表单渲染环境里
`onAreaChange` 是否回调**我没验过，官方 FAQ 也没推荐；**首选 DIMENSION_KEY**。

### 4.2 手表版该删 / 该留

| # | 元素 | 手表（2\*2 ≈ 100~130vp） | 理由 |
|---|---|---|---|
| ① | `One More` 品牌名 | **删** | 卡片本身就是这个 App 的，名字没有信息量；占一行 18vp |
| ① | 🔥 连胜 + 天数 | **删** | 手表上看"连续几天"意义低；`Common.ets:654` 在 195 屏的游戏卡上**也做了同样决定**（「195×195 上不显示火焰」）—— 有先例 |
| ② | LV 环 40×40 | **留，缩到 28** | 等级是小卡片的核心信息；40 → 28 省 12vp 宽/高 |
| ② | 等级数字（16） | **留，缩到 13** | 环内的数字 |
| ② | `LV` 小标签（8） | **留**（环内两行之一）| 不占额外空间 |
| ② | 称号 `title`（16） | **留，缩到 12 + `maxLines(1)` + 省略号** | 卡片最想表达的东西 |
| ② | 今日打卡（10） | **留**，但**挪到环的右侧上行**、`maxLines(1)` | 这是卡片"有没有打卡"的唯一信息 |
| ③ | 进度条（5） | **留**（正是卡片的价值：离下一级还有多少）| 5vp，很便宜 |
| ④ | 底部文案 `footer`（9） | **删** | 「累计 N 局 · 点我开一局」—— 后半句在手表上点不了（卡片点击行为也没配），前半句可省 |

**手表版布局草案（算过高度）**：

```
┌───────────────┐   padding 12
│  ◯28  渐入佳境 │   ← 环 28 + 称号 12
│  13   ✅ 今日已打卡 │   ← 打卡状态 10
│  ▬▬▬▬▬░░░     │   ← 进度条 5
└───────────────┘
高 = 12 + max(28, 12+2+14) + 8 + 5 + 12 = 12+28+8+5+12 = **65vp**  ✅ 远小于 ~98
宽 = 12 + 28 + 6 + ~50 + 12 = **≈108vp**（称号/打卡可各自省略）
```

⇒ 手表版 **65vp 高**，比现在的 124vp 少一半，能在 2\*2 里舒服放下。

### 4.3 实现建议（**本轮不做**，只列）

- **路线 A（推荐、改动最小）**：`onAddForm` 读 `DIMENSION_KEY` → bindingData 加 `dim` → 卡片
  用 `@LocalStorageProp('dim')` 切两套 build 分支（`if (this.isTinyCard())`）。
  ⚠️ 但**只靠 2\*2 分不出"手表"和"手机 2\*2"**（都是 Dimension_2_2）⇒ 若两者要不同布局，
  得**再配一个 `2*3`/`3*3` 的纯手表卡**（这两个尺寸官方标注「仅支持手表设备」），
  用"哪个尺寸"来区分设备类型。**这才是官方推荐做法**（「若卡片内容差异较大，可以配置多个卡片」）。
- **路线 B**：保持单卡，改成"全响应式"（百分比 + `layoutWeight` + `constraintSize` + 字号 `minFontScale`），
  不区分设备。成本高（要重画整张卡的布局），但一次到位。

> 我的建议：**先做路线 A 的多尺寸卡（2\*3 手表专用）+ 保留现有 2\*2 给桌面**。
> 这样"手机桌面卡"完全不动（零回归），手表是新增的一张。

---

## 5. ④ `formwidget/` 里还有别的组件吗 —— 没有

| 文件 | 作用 | 有没有尺寸分支 |
|---|---|---|
| `StatsCardAbility.ets` | FormExtensionAbility（读进度 / 本地化 / 注入）| 无 |
| `pages/StatsCard.ets` | 卡片 UI | 无 |
| `form_config.json` | 1 个卡片，`2*2` + `2*4` | — |

`module.json5` 里也只有 `StatsCardAbility` 这一个 form extension。

---

## 6. 配置层的 4 个坑（比 UI 更该先修）

### 6.1 `window` 那一段是**死配置**

```json
"window": { "designWidth": 720, "autoDesignWidth": true }
```
官方文档明确：**「该字段仅对 JS 卡片生效」**。我们是 `uiSyntax: "arkts"` ⇒
**这 4 行完全不起作用**（模板自带的，一直没人删）。
⇒ 打印/审查时别以为"卡片会按 720 缩放"——**不会，就是固定 vp**。

### 6.2 `2*4` 在手表上**不被支持**

官方 supportDimensions × 设备表：

| 尺寸 | Phone | Tablet | TV | **Wearable** |
|---|---|---|---|---|
| `1*1` | 是（仅锁屏）| 是（仅锁屏）| 否 | **是** |
| `1*2` | 是 | 是 | 是 | **是** |
| `2*2` | 是 | 是 | 是 | **是** |
| `2*4` | 是 | 是 | 是 | **否** |
| `2*3` / `3*3` | 否 | 否 | 否 | **是（仅手表）** |

我们配的是 `["2*2", "2*4"]` ⇒ **手表只能用 2\*2**，`2*4` 那份配置在手表上等于不存在。
**真要上手表，该加的是 `2*3` 或 `3*3`**（这两个只在手表可用 ⇒ 天然区分设备）。

### 6.3 `previewImages` 缺失 ⇒ **穿戴卡片"根本没声明"**

官方字段说明：
> `previewImages`：卡片预览图，与 supportDimensions 一一对应。**智能穿戴卡片必须配置**，当前仅支持在智能穿戴上使用。

我们**没配**（grep 0 处）⇒ 手表卡片中心很可能**看不到这张卡**（或没有预览图）⇒
"手表适配"目前是 0，而不是"做了但不完美"。

### 6.4 其他缺省值须知

| 字段 | 我们 | 官方缺省 | 影响 |
|---|---|---|---|
| `supportShapes` | 未配 | `["rect"]` | 圆形表盘不支持圆卡 |
| `supportDeviceTypes` | 未配 | 全设备（API22+）| 声明上"支持手表"，但缺 previewImages ⇒ 实际不可用 |
| `fontScaleFollowSystem` | 未配 | **true** | 卡片字号跟随系统 ⇒ 与 `UiModeMgr` 的 elder 可能叠加（§3.4）|
| `updateDuration: 2` + `scheduledUpdateTime: 08:00` | 都配了 | — | 官方：**updateDuration 优先** ⇒ `08:00` 定点刷新其实不生效（周期 = 60 分钟）|
| `colorMode: auto` | 配了 | — | 官方：该字段**从 API 20 起废弃**、且**仅对 JS 卡片生效** ⇒ ArkTS 卡里也是死配置 |

### 6.5 🔴 「点我开一局」是**空承诺**（这条独立成项）

底部文案写的是「累计 0 局 · **点我开一局**」，但：

| 检查 | 结果 |
|---|---|
| `StatsCard.ets` 里有 `onClick` / `FormLink` / `postCardAction` 吗 | **0 处** |
| `form_config.json` 里有 `formConfigAbility` 吗 | **没有** |

按官方机制，卡片**不会**因为"点了"就打开 App —— 要么配 `formConfigAbility`（点击拉起 ability），
要么在卡片里放 `FormLink`/`Button`。两者都没有 ⇒ **点卡片什么都不发生**，
而卡片自己这么写着 ⇒ 用户会以为"点了没反应是卡了"。

> 这条和手表无关：**桌面上也是一样**。属于"文案比实现走得远"，与本轮审计同源的 bug 类型
> （`super_10` 文案撒谎、`marathon` 判的不是"一天"）。修法二选一：
> ① 配 `formConfigAbility: "ability://EntryAbility"`（1 行 JSON，最快）
> ② 改文案去掉"点我开一局"

---

## 7. 如果要上真机验（判据 1814）

**先 dump，再动手**（我本轮没上机）：

1. `hdc -t 127.0.0.1:5557 shell "bm dump -n <bundleName> | head -40"` —— 确认 form 已注册；
2. 手表/矮屏上把卡片加到桌面（2\*2），**dump 一次布局**：
   `hdc shell uitest dumpLayout -p /data/local/tmp/card.json && hdc file recv ...` ——
   确认 ①语言（判据 1814：先确认语言/页面）②卡片实际 bounds（这正是 §3.2 缺的那个数）；
3. 截图对照：标题是否换行、进度条/底部文案是否可见。

**注意**：本机 `127.0.0.1:5557` 是 **853×533 的横屏窗口**，不是手表 ⇒
**在这台机器上验不出"195×195"**；要验得用 `Bp.tinyWatch()` 成立的设备或改窗口尺寸。

---

## 8. 没做的事 / 边界

- **只读**：没改任何代码（`form_config.json`、`StatsCard.ets`、`StatsCardAbility.ets` 都没动）。
- **没上真机**：§7 的三步没做 ⇒ 手表 2\*2 的**真实 bounds 是估的（98~130vp）**，不是量出来的。
- **没说"325 款游戏补手表布局"**：那是另一批活（`verifier-eng2` 的发现），本轮只回答"卡片呢"。
- **没验 `onAreaChange` 在表单渲染环境里是否回调**（所以 §4.1 把它列为备选而非首选）。
- **没查 `previewImages` 的图片该放哪、什么规格**（`rawfile`/`media`、1:1？）—— 真要加得再查官方。
- **没动"卡片点击行为"**：卡片文案说「点我开一局」，但 `form_config.json` 没配 `action`
  （要在卡片里配 `FormLink`/`onClick` 才能跳转）⇒ 这条**可能本来就是个空承诺**，建议单独核。
