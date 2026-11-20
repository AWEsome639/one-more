# `2.0.0` **release 签名包已出好** —— 云测试可用的那一份

## 一、产物

```
release/onemore-2.0.0-release-signed-20261120-0933.hap   29,567,896 字节（≈28 MB）
```

对照：debug 包是 `53,503,662` 字节 ⇒ **release 小了 `45%`**，说明真的做了优化/裁剪。

## 二、签名证据（不是靠文件名猜）

构建日志里：
```
> hvigor Finished :entry:default@SignHap... after 4 s 217 ms
```
⇒ **`SignHap` 任务跑了 `4.2` 秒**。

产物目录里同时有：
```
entry-default-signed.hap     29,567,896
entry-default-unsigned.hap   29,403,562
```
⇒ 两者差 `164,334` 字节 = **签名块**。

⇒ 用的是 `build-profile.json5.release-signed` 那套证书（`keyAlias: onemorerelease`、
`onemore_release.cer` / `onemore.p12` / `onemore_release.p7b`，三个文件实测都在）。

## 三、出包步骤（下次照做，含一个**差点出事**的坑）

```bash
# ① 备份!（这一步今天救了我）
cp build-profile.json5 /tmp/bp.debug.backup.json5
# ② 换成 release 证书
cp build-profile.json5.release-signed build-profile.json5
# ③ 出包（必须 release）
hvigorw --no-daemon assembleHap -p product=default -p buildMode=release
# ④ 复位（★ 见下）
git checkout -- build-profile.json5
```

### ⚠️ 坑：复位时 `cp` 报 `Read-only file system`

第 `④` 步我先用 `cp /tmp/bp.debug.backup.json5 build-profile.json5`，**失败**：
```
cp: build-profile.json5: Read-only file system
```
⇒ 当时 `build-profile.json5` **停在 release 配置**（`keyAlias: onemorerelease`），
   如果没发现，后面所有包都会用 release 证书签、`compatibleSdkVersion` 也可能被改动。

**救回来的办法**：`git checkout -- build-profile.json5` ——
⇒ 立刻恢复成 `debugKey`、与 git 零差异、`compatibleSdkVersion: 6.0.0(20)` 完好。

⇒ **判据**：出包后复位**不要用 `cp`**，用 `git checkout --`：
   它是原子的、可验证（`git diff` 为零）、且不受文件系统怪状态影响。

## 四、这份包能直接干什么

| 用途 | 就绪？ |
|---|---|
| AGC 云测试（真机/兼容性） | ✅ 用这一份 |
| 真机安装验证版面 | ✅ 用这一份 |
| 上架提审 | ⚠️ 还需要版本号/文案确认（奥森定） |

## 五、当前仓库状态（出包后）

```
build-profile.json5   → 已复位（debugKey、与 git 零差异）
release/              → 多一个 2.0.0 release-signed 包
断言                  → 200359 / 0（出包前后都是）
```

## 六、判据

> **出正式包是「有副作用」的操作：它会把本地的调试配置改成发布配置。**
> 所以「出包」必须配一条「复位」，而且**复位要可验证**（`git diff` 为零），
> 不能只靠「我 `cp` 回来了」。

⇒ 三条：
1. **出包前备份、出包后 `git checkout --`**（不是 `cp`）
2. **用「签名任务跑没跑」判断包是否真签名**（`Finished :...@SignHap`），不靠文件名
3. **`signed` 与 `unsigned` 的字节差 = 签名块**，是个好用的旁证

---

## 七、追加：**第一个包是错的** —— `build-profile.json5.release-signed` 是旧副本

### 抓到的问题

| 配置 | `compatibleSdkVersion` |
|---|---|
| `build-profile.json5`（debug，现用）| `6.0.0(20)` ✓ |
| `build-profile.json5.release-signed`（出包用）| **`5.0.0(12)`** ✗ |
| 第一个 release 包的 `minAPIVersion` | **`50000012`** = API 12 ✗ |

⇒ 出包用的那份配置**没跟着 API 20 迁移一起改**，所以包声明成 API 12，与 debug 版（API 20）不一致。
⇒ 要是直接传云测试，装上去的是一个「声明支持 API 12」的包。

### 修法与结果

1. `build-profile.json5.release-signed` 改成 `6.0.0(20)`
2. 重出包 ⇒ `minAPIVersion: 60000020` ✅
3. **删掉错的那个包**（`release/` 里两个同名不同 API 的包最容易装错）

```
release/onemore-2.0.0-release-signed-20261120-0951.hap   29,373,782 字节
minAPIVersion: 60000020 ✅ · versionName 2.0.0 · versionCode 2000000
deviceTypes: phone / tablet / 2in1 / tv / wearable
```

### 判据（`3077`）

> **同一个项目有几份 build 配置时，改一份必须同步全部。**
> 这次 `build-profile.json5` 改了 API 20，而 `build-profile.json5.release-signed` 没改 ——
> **debug 包对、release 包错，而只有打开 `module.json` 才能发现。**

⇒ 三条：
1. **出包后必须读 `module.json` 的 `minAPIVersion` 与 `versionName`** —— 不能只看 `BUILD SUCCESSFUL`
2. **多份 build 配置视为「同一事实的多处副本」** —— 改一处就把其余几处列进清单
3. **错的产物要删掉**，别留着同名不同配置的两个包
