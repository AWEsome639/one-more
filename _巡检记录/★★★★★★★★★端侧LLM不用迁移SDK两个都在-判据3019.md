# 判据 3019：端侧 LLM 的「两条路」我之前的说法是错的 —— **两个都在 SDK 里，不用迁移**

## 一、我之前的说法（错）

> 第 ④ 项：`mindSporeLite`（API `10`，需 `.ms`）vs `AgentFramework`（API `20`，**需 target `12→20`**、
> `355` 款 + `200,359` 断言**全在 API `12`**）⇒ 待奥森选路

**暗示的代价是**：选 `AgentFramework` 要把整个工程从 API `12` 升到 `20`，`355` 款游戏和 `20` 万条断言一起冒险。

## 二、实际查到的（本机 SDK）

```bash
$ python3 -c "... sdk-pkg.json ..."
  /data/apiVersion        26
  /data/platformVersion   26.0.0

$ grep compatibleSdkVersion build-profile.json5
  "compatibleSdkVersion": "5.0.0(12)"      ← 支持下限
  "targetSdkVersion":     "26.0.0"         ← 目标已经是 26
```

⇒ **`targetSdkVersion` 本来就是 `26`，`compatibleSdkVersion` 是「最低支持 API」= `12`。**
⇒ **API `20` 的特性现在就能编译，不需要动任何配置。**

两个包**都已经装在 SDK 里**：

```
openharmony/ets/api/@ohos.ai.mindSporeLite.d.ts          @since 10  @syscap …AI.MindSporeLite
hms/ets/api/@hms.ai.AgentFramework.d.ets                 @since 6   @syscap …AI.Agent.AgentKit
hms/ets/kits/@kit.AgentFrameworkKit.d.ts
```

## 三、真正的取舍（我之前的框架漏掉的）

| | `mindSporeLite` | `AgentFramework` |
|---|---|---|
| 编译门槛 | 无（`@since 10` ≤ 26）| 无（`@since 6` ≤ 26）|
| **要不要模型文件** | **要**：`loadModelFromFile(model)` —— 得有一个 `.ms` 模型 | **不要**：直接给提示词 |
| syscap | `SystemCapability.AI.MindSporeLite` | `SystemCapability.AI.Agent.AgentKit` |
| 我们要额外做的 | 找/转一个 `.ms` 模型（体积、许可、量化都是新问题）| 确认设备有没有那个 syscap |

⇒ **真正的取舍不是「迁移风险」，是「模型文件 vs syscap 可用性」。**

## 四、这两件事分别怎么验（都不用改代码）

### ① 设备有没有 syscap（要设备在线）

```bash
hdc shell param get const.product.syscap        # 或
hdc shell hidumper -s 4010 -a -g               # 逐个 syscap 查询
```
⇒ 看到 `SystemCapability.AI.Agent.AgentKit` ⇒ `AgentFramework` 可用。

### ② 有没有 `.ms` 模型

```bash
find . -name "*.ms" -o -name "*.mindir" | head
```
（今晚没查，属于下一步）

## 五、判据

> **「要不要升 SDK」这种前提，先去读 `sdk-pkg.json` 的 `apiVersion` 和 `build-profile.json5` 的
> `targetSdkVersion`/`compatibleSdkVersion` —— 不要凭「某个 API 是 `@since 20`」就假设要迁移。**

⇒ 三条：
1. **`@since N` 是「这个 API 从 N 起有」，不是「工程要升到 N」** ——
   只要 `targetSdkVersion ≥ N` 就能编译，`compatibleSdkVersion` 管的是**能不能在旧设备上跑**
2. **`compatibleSdkVersion` 低 ⇒ 用新 API 处要加 `canIUse`/运行时判断**，这是正确的做法，不是迁移
3. **把一个「技术选型」误报成「大规模迁移」，会让决策者去算一个根本不存在的风险**

## 六、修正后的说法（给奥森）

| 选项 | 代价 | 卡点 |
|---|---|---|
| **`AgentFramework`** | **零编译改动** | 只需确认设备有 `SystemCapability.AI.Agent.AgentKit` |
| `mindSporeLite` | 零编译改动 | **得先有一个 `.ms` 模型**（体积/许可/量化都是新问题）|

⇒ **推荐顺序反过来了**：先验 `AgentFramework` 的 syscap（一条命令），
   通了就**不用碰模型文件**；不通再考虑 `mindSporeLite` 那条要自己找模型的路。

⇒ 这条推翻了我之前「待奥森选路」里暗示的「二选一都有大代价」——
   **其中一条的代价是零。**
