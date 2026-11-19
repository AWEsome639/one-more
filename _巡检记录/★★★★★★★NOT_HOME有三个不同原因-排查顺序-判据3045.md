# 判据 3045：`NOT_HOME` 有**三个不同原因**，排查顺序必须是「设备 → 锁屏 → app」

## 一、今天下午一次「全库竖屏扫描」被三层假故障挡住

想跑 `354` 款全库竖屏扫描，结果连 `NOT_HOME`，每层查下去都是**不同的原因**：

| 层 | 现象 | 真因 | 修法 |
|---|---|---|---|
| **1** | `[1/354] Bejeweled NOT_HOME`、进程随即退出 | **设备连不上**（`hdc list targets` = `[Empty]`）| `hdc kill` + `start` + `tconn 127.0.0.1:5555` |
| **2** | 设备连上了、仍是 `NOT_HOME` | **模拟器锁屏**（`aa start` 报 `10106102 The device screen is locked`）| `power-shell wakeup` + `uitest uiInput swipe` 解锁 |
| **3** | 我以为「app 没装」，`bm dump -n com.onemore.game` 返回空 | **bundle ID 我写错了** —— 真身是 **`com.andrewoscar.onemore`** | `bm dump -a` 看全部已装 bundle |

⇒ **三层都不是游戏的问题、不是测量判据的问题、也不是代码的问题。**

## 二、排查顺序（写死，别再乱试）

```
① 设备在不在：  hdc list targets          ⇒ 空 ⇒ kill/start/tconn
② 锁屏没锁：    aa start -b <bundle> -a EntryAbility
                ⇒ 10106102 ⇒ power-shell wakeup + uiInput swipe 解锁
③ app 装没装：  bm dump -a | grep onemore   ← ★ 用 `-a` 列全部，别猜 ID
                ⇒ 没有 ⇒ hdc install -r <hap>
④ 才对：        python3 工具/verify_layout.py ...
```

⇒ **`bm dump -n <猜的ID>` 返回空，有两种可能：没装 / ID 猜错。**
   必须用 `bm dump -a` 看清单，**不能用「查不到」直接判定「没装」**（我今天就判错了）。

## 三、★ 工具自己的看门狗会把锁屏状态重启掉

`工具/verify_layout.py:79`：
```
subprocess.Popen('%s -start %s -noWindow > /tmp/emu_wd.log 2>&1' % (EMU, EMU_INST), shell=True)
```
⇒ 只要它启动那一刻 `hdc list targets` 是空的，它就**自己冷启动**模拟器 ⇒
   **我把锁屏解开、把 app 拉起来的状态全丢**，然后又 `NOT_HOME`。

⇒ **正确顺序**：先让设备可见 + 解锁 + app 正在跑，**然后立刻**启动工具（工具会看到设备、不再冷启）。

## 四、还有一个环境层的硬约束

```
内存空闲 77 MB
```
⇒ 在这个余量下，模拟器**反复崩**（实测 `etime` 只有 `00:15` 就说明它刚崩完自动重启过）。

⇒ **`354` 款 × `75s` ≈ `7.4` 小时的全库竖屏扫描，在 `77 MB` 空闲内存下跑不完** ——
   不是代码问题，是这台机器当时没有余量。

⇒ 要么先腾内存（关别的活），要么分成小批次（一次 `60` 款 ≈ `75` 分钟）并在批间检查设备。

## 五、判据

> **`NOT_HOME` 是「测量工具没找到游戏的首页」这一个观测，它背后至少有三种完全不同的原因：
> 设备不在 / 屏幕锁着 / app 没装。按「设备 → 锁屏 → app」的顺序查，不要跳步。**

⇒ 四条：
1. **先查设备**（`hdc list targets` 为空就 `kill`+`start`+`tconn`），别一上来怀疑游戏
2. **再查锁屏**（`aa start` 的 `10106102` 是锁屏专用错误码）
3. **最后查 app**，而且**必须用 `bm dump -a` 看清单**，不能用「查某个 ID 返回空」判定没装
4. **确认这三层都好之后，才允许启动测量工具** —— 否则工具自己的看门狗会冷启动、
   把你刚做好的解锁状态全清掉，然后你再看到一个新的 `NOT_HOME`

## 六、今天这条没做完的事（诚实记）

| 项 | 状态 |
|---|---|
| 全库 `354` 款竖屏扫描 | ❌ **未完成**（三层故障 + 内存不足）|
| 已完成竖屏覆盖 | ✅ 约 **`80` 款**（此处数据仍有效）|
| 建议 | 今晚窗口开跑前：① 腾内存 ② 按上面四步先确认设备/锁屏/app ③ 分批 `60` 款一批 |
