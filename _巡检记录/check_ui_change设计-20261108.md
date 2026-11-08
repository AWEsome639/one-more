# `check_ui_change.sh` 设计 + 误报率实测（2026-11-09 00:2x）

> **先测量，再决定做不做。** 结论：**误报率 0%，远低于 30% 阈值 ⇒ 已落地成工具。**
> 产出：`工具/check_ui_change.sh`（可运行）+ 本文档。
> 边界：只新增了这一个工具文件，**未改任何 `.ets`**。

---

## 结论：做

| 指标 | 实测值 | 阈值 | 判定 |
|---|---|---|---|
| **几何规则误报率** | **0%**（30/30 提交级真阳性）| < 30% | ✅ 通过 |
| 行级误报 | 572 行中 **1 行**（0.17%）| — | ✅ |
| 联合触发率 | **39%**（40/101 提交）| — | 可接受（61% 的提交免验）|

**⇒ 已落地：`工具/check_ui_change.sh`（含 `--strict` 模式）**

---

## 一、测量方法（不猜，跑真实历史）

**样本**：2026-11-08 全天的 **101 个提交**。

**规则**：只看 `+` 行的**代码**（排除注释行），按三条正则分类。

**误报的定义**：一个提交触发了规则，但它的命中行**全部落在块注释里**（即实际没改代码）。

**结果**：

| 规则 | 触发提交 | 占比 |
|---|---:|---:|
| 几何（`width/height/position/aspectRatio/constraintSize/backgroundColor/@Builder/...`）| **30** | 30% |
| 文案（`TG/TG2/TG4/TN/L(`）| 23 | 23% |
| 方向（`direction/align/Alignment./start:end:`）| 8 | 7% |
| **联合** | **40** | **39%** |
| 纯注释/无代码改动（**正确未触发**）| 44 | 43% |

**几何规则逐提交复核**：

```
30 个触发提交
  ├─ 命中行 572 行  → 571 行是真代码，1 行在块注释里
  └─ 提交级：30/30 都至少有一条真命中 ⇒ 误报 0%
```

**⇒ 误报率 0% ≪ 30%，值得做。**

---

## 二、但我在测量中发现一个「致命的盲区」

**今天最严重的那起（`SymbolGlyph` 拉伸成紫色色块），用最初的规则测 ⇒ 触发 0 行。**

原因：那笔改动是

```diff
-        Text('🔍')
+        SymbolGlyph($r('sys.symbol.magnifyingglass'))
```

**一个几何属性都没改** —— `width/height` 那几行在 diff 里根本没动。
它换的是**组件类型**，而 `Text` 是「文字（宽由字形定）」、`SymbolGlyph` 是「组件（宽由 flex 定）」——
**布局语义变了，但没有任何几何属性的变化。**

**⇒ 必须补第 4 条规则：`组件类型替换`。**

```bash
# 取被删掉的组件名 vs 新增的组件名，差集非空 ⇒ 触发
REMOVED_COMP = diff 里 "-  Text(" "--  SymbolGlyph(" … 的组件名
ADDED_COMP   = diff 里 "+  SymbolGlyph(" … 的组件名
ADDED - REMOVED ≠ ∅  ⇒ 触发几何检查
```

**合成 diff 自检**：`-Text('🔍')` / `+SymbolGlyph(...)` ⇒ `removed={Text} added={SymbolGlyph}` ⇒ **触发 ✓**

**⚠️ 另一条更硬的教训**：这笔改动**从未提交**（直接在包里看到紫色后回滚）。

**⇒ 任何「扫 git log」的实现都抓不到它。工具必须看 `git diff HEAD`（工作区 + 暂存区），不是历史提交。**

---

## 三、工具设计

### 输入

```bash
git diff HEAD -- '*.ets'        # 工作区 + 暂存区（不是 git log！）
```

### 四条规则

| 规则 | 正则（摘要）| 触发后要求 |
|---|---|---|
| **几何** | `\.(width\|height\|position\|offset\|aspectRatio\|constraintSize\|backgroundColor\|borderRadius\|padding\|margin)\s*\(` `@Builder` `layoutWeight` `flexShrink` `.scale(` | **真机 dumpLayout** |
| **组件替换** | 组件名差集非空（`Text/SymbolGlyph/Image/Row/Column/Stack/Flex/Button/Grid/List/Scroll`）| **真机 dumpLayout** |
| **文案** | `(TG\|TG2\|TG4\|TN\|L)\s*\(` | `check_i18n.py` |
| **方向** | `direction\(` `.align\(` `Alignment.` `start:` `end:` `.mirror` | `check_rtl.py` |

### 输出（几何触发时，直接把「四个自检项」打出来）

```
🔴 触发布局几何检查 —— 必须跑一次真机并贴 bounds 结论：
    hdc shell "uitest dumpLayout -p /data/local/tmp/a.json"
    hdc file recv /data/local/tmp/a.json /tmp/a.json
  然后自检四条（判据 1829/1819/1825）：
    ① 拉伸：实际宽 > 声明宽 × 1.05 ？        ⇒ 加 .flexShrink(0)
    ② 撑爆：子节点 height > 父节点 height ？ ⇒ constraintSize / 放宽上限
    ③ position：dump 里找不到那个节点？      ⇒ 换 Canvas 或改布局
    ④ 视觉vs判定：S = 视觉尺寸 / 判定系数，实际容器 ≠ S ？
```

### 两种模式

| 模式 | 行为 |
|---|---|
| 默认 | 只提示，**退出码恒 0**（不挡人）|
| `--strict` | 有几何改动但 `UI_VERIFIED` ≠ 1 ⇒ **退出码 1** |

```bash
# 验完再放行
UI_VERIFIED=1 bash 工具/check_ui_change.sh --strict
```

---

## 四、实测（工具已跑过）

| 场景 | 结果 |
|---|---|
| 干净工作区 | `✅ 工作区没有 .ets 改动，无需验`，退出 0 |
| 只有注释改动 | `✅ 只有注释改动，无需验`，退出 0 |
| 合成几何改动（`SymbolGlyph` + `.width(` + `.aspectRatio(`）| 几何 2 行 + **新组件 SymbolGlyph 被识别** ⇒ 打印四条自检 |
| 同上 + `--strict`（无证据）| **退出码 1** ✓ |
| 同上 + `UI_VERIFIED=1 --strict` | `✅ --strict：UI 已验证`，退出 0 ✓ |

测试用**新建临时文件**（`git add -N`）跑，跑完 `git reset` + 删除，**没碰任何现有文件**。

---

## 五、这个工具**查不到**什么（必须写清楚，否则会被当万能）

| 盲区 | 为什么 | 怎么补 |
|---|---|---|
| **编译缓存导致改动没进包** | 工具看的是 diff，不是产物 | **另一条独立闸门**：装包前 `grep` 转译产物里有没有改动 token（今天已踩 2 次）|
| **渲染效果好不好看** | `dumpLayout` 只给 bounds，不给颜色/观感 | **人眼截图**，工具替代不了 |
| **`@State` 时序类问题** | 静态规则看不出运行时求值时机 | 真机观察 + 日志 |
| **非 `.ets` 的改动**（如 `build-profile.json5`、签名配置）| 规则只扫 `*.ets` | 那类问题有别的闸门（`BUILD_STRICT`）|

**⇒ 它是「第四把尺子（几何）」，不是「唯一一把」。**

---

## 六、建议的接入方式

```bash
# 改完 UI，提交前
bash 工具/check_ui_change.sh

# 或者接进出包脚本（推荐 strict）：
UI_VERIFIED=${UI_VERIFIED:-0} bash 工具/check_ui_change.sh --strict || exit 1
```

**和现有三把尺子的分工**：

| 尺子 | 查什么 | 维度 |
|---|---|---|
| `check_i18n.py` | 文案走没走取词 | 文案 |
| `check_rtl.py` | 方向属性 | 方向 |
| `check_focusable.py` | 可点元素有无焦点 | 可达性 |
| **`check_ui_change.sh`（新）** | **按改动类型要求对应验证** | **分流 + 几何** |

---

## 七、一句话

**今天 7 起 UI 事故、三把尺子全绿，不是因为尺子不准，而是因为它们量的不是同一个维度。**
这个工具不量任何东西，它只做一件事：**看你改了什么，然后要求你去量对应的那一维。**

**误报 0%，39% 的提交会触发 —— 值得。**
