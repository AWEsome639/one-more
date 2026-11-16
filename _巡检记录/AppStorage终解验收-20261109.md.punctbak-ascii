# AppStorage 终解 · 验收（2026-11-09 02:5x）

> 执行：**perf-hunter** ｜ 设备 `127.0.0.1:5557` ｜包 `updateTime=1794163925035` = **02:52:05** ✅
> 判据 1814 已执行（中文 / 游戏页 / 8 卡）｜判据 1812（像素差分）｜判据 1813b（页面重建对照）
> **本轮 .ets 改动 0 行**

---

## 0. 结论

**对照步骤 ✅ 通过（`@StorageProp` 确实是真观察源）；但「点击 → 重绘」**仍然是 0 差异** ⇒ 按 lead 预案：`AppStorage` 也没救，下一步要**重构卡片**。**

| 步 | 结果 |
|---|---|
| **对照**（问一次 → 进设置页，**不点卡**） | ✅ **卡面直接显示 `初始化 1028 ms` / `init-false`**（= 刚问那次 init 的 `1028ms`）⇒ **`@StorageProp` 在"构建时"读到的是真值** |
| **2 点击像素差分** | ❌ **+0.19 / +0.33 / +0.46s 三张，差异像素 = 0**（与修前完全一样） |
| **3 点后 ~2s** | ❌ **卡面仍 `1028 ms`**，而本次 init 是 **1032ms**（hilog：`02:53:45.779 init=false 耗时 1032ms`） |

## 1. 关键原始数据
```
# 对照：问一次（02:53:06.689 init=false 耗时 1028ms）→ 进设置页（未点卡）
AI 诊断, …, 模型状态, init-false, 初始化, 1028 ms, …     ← ★ 进页面就有真值 1028
# 点卡片：hilog 证明 retry+init 都跑了（02:53:45.779 init=false 1032ms）
z_after0.png (+0.19s): 差异像素=0
z_after1.png (+0.33s): 差异像素=0
z_after2.png (+0.46s): 差异像素=0
# 点后 2s 卡面
AI 诊断, …, 初始化, 1028 ms, …                            ← 仍是旧值（stat 已是 1032）
```

## 2. 这一轮把结论又收紧了一层

| 层 | 结论 | 证据 |
|---|---|---|
| **数据 / 观察源** | ✅ 正常 | `@StorageProp` 在**构建时**能读到真值（1028）；`LocalLLM.sync()` 确实写进了 AppStorage |
| **运行时重绘** | ❌ **断的** | 点击后（`retry()` 同步 sync `reason='idle'`、随后 init 完成 sync `initMs=1032`）**三张截图 0 差异**、2s 后卡面仍旧值 |
| `@Builder` | ✅ 会执行 | 页面重建时卡面能显示新值（本轮再次验证：进页面 = 1028） |

⇒ **不是状态（`@State`/`@StorageProp`）的问题** —— 两种观察源都"能读不能触发重绘"。
⇒ 完全符合 lead 的预案：**「`AppStorage` 也没救 ⇒ 是这个 `@Builder` 结构本身有问题 ⇒ 下一步重构卡片」**。

## 3. 重构方向（建议，未实施）

**观察到的精确症状**：**该卡片所在子树在"页面构建后"就不再响应任何状态变化** —— 而同一页其它控件（`confirming` 面板/主题色/语言）是正常的。
⇒ 优先怀疑 **`aiDiagCard()` 这个 `@Builder` 与它所在的容器**，而不是数据：

1. **把卡片内联进 `build()`**（不再走 `@Builder`）：直接写 `Column(){…}`，读 `@StorageProp`。
   —— 最直接，能排除"@Builder 子树不参与更新"。
2. **给卡片包一层独立 `@Component`**（`AiDiagCard` 自定义组件，用 `@Prop`/`@StorageProp` 传入）：
   自定义组件有**自己的重建边界**，通常能绕开父级"不重建"的问题。**这是最推荐的**。
3. 把上面的"三层证据"作为重构后的验收基线：**像素差分必须 > 0**、`初始化` 必须跟着 `stat.initMs` 变。

## 4. 判据沉淀
- **1811**（既有）：`@Builder` 内部读 `@State` 的卡片/面板不会可靠重建 —— **本轮把范围扩大**：
  **`@StorageProp` 也一样**（"能读到真值" ≠ "会触发重绘"）
- **1813b**（既有）：页面重建 ≠ 点击重建 —— 本轮再次用对照实验分层成功
- **新增（本条）**：**判断"观察源是否生效"必须分两个动作**：
  ① **构建时读**（进页面看值对不对）② **运行时触发**（改值后看像素变不变）。
  只验①会误判成"修好了"——本轮对照通过、点击仍 0 差异，就是这两个动作的差别。

## 5. 设备已复位
首页（聊天面板关）｜简体中文｜8 张卡｜主题色靛蓝

---

## 6. 重构：`aiDiagCard` → 独立 `@Component`（2026-11-09 03:1x，**未编译**）

### 6.1 改了什么
| 文件 | 改动 |
|---|---|
| `components/SettingsTab.ets` | **+151 / −151**（净 0，是"搬"不是"加"）：<br>· 新增 **`@Component export struct AiDiagCard`**（文件末尾，独立重建边界）<br>· `build()` 里 `this.aiDiagCard()` → **`AiDiagCard()`**（一行调用）<br>· 删掉 `SettingsTab` 里的 `aiDiagCard()` / `diagRow()` / `diagMs()` / `diagA11yText()` / `retryDiag()` 与 5 个 `@StorageProp('llm…')`<br>· 顺手删掉已无引用的 `DIAG_LABEL_W` 常量 |

**新组件的自包含结构**（判据 1828：依赖面已全搜，只有 `build()` 里一处调用）：
```ts
@Component
export struct AiDiagCard {
  @StorageProp('llmReason')  reasonV: string = 'idle';
  @StorageProp('llmInitMs')  initMsV: number = 0;
  @StorageProp('llmFirstMs') firstMsV: number = 0;
  @StorageProp('llmCalls')   callsV: number = 0;
  @StorageProp('llmReady')   readyV: boolean = false;
  @StorageProp('themeDark')  dark: boolean = false;   // 组件自己的主题订阅
  @StorageProp('lang')       lang: string = 'zh';     // 组件自己的语言订阅
  @State private focused: boolean = false;            // 自己的焦点环（原来借父组件的 tvFocus）
  private retry(): void { LocalLLM.retry(); LocalLLM.init().then(...); }   // 回调不需要从父传入
  build() { … }   // 卡片内容整体搬进来
}
```

### 6.2 为什么这次可能成
- 之前两条路（`@State` / `@StorageProp`）都是**父组件持有状态**，改值能读、**不触发子树重绘**；
- 现在状态**归组件自己所有**（`@StorageProp` 在组件内），组件有**独立重建边界** ⇒ 值变化直接作用于组件自身；
- 回调也内聚（不需要 `@Prop` 传函数）——避开了 ArkUI 对 `@Prop` 函数类型的限制。

### 6.3 验收（下一版包，仍是那三步 + 像素差分）
1. **进设置页**：`模型状态` = `idle` 或上次结果（构建时读，必须过）
2. **点卡片**（`hilog -r` → 点 → +0.2/0.4/0.6s 连拍）：**卡片区域像素差 > 0**（修前 0）
3. **点后 ~2s**：`初始化` == 本次 `initMs`（与 `LocalLLM: init=` 日志一致）、`reason` 回 `init-false`

### 6.4 如果这次仍是 0 差异 —— 那就是更深的框架问题
按 lead 的判断：**「可能这个页面有更上层的重建阻塞」** ⇒
- 记成**已知项**（不再在状态/组件结构上打转）
- 下一步只能查 `SettingsTab` 的**上层容器**（`Tabs`/`TabContent`/`Scroll`）或整个设置页的构建方式，
  或者干脆给诊断信息做**一次性快照 + 手动"重新读取"文案**（承认它不实时，但不骗人）。
