# `GAME_DUMP_FAIL` 的真根因（2026-11-09 04:00）

## 🎯 根因：**路径里有空格**

**v7 加日志后，第一次跑就看到了**：
```
[sh] uitest dumpLayout -p /data/local/tmp/game_Snake 3D → len=47 rc=0 out='DumpLayout saved to:/data/local/tmp/game_Snake'
[sh] cat /data/local/tmp/game_Snake 3D.json → len=321645 rc=0
```

**⚠️ 关键**：
- **`-p /data/local/tmp/game_Snake 3D`** —— **`-p` 参数「被空格「切成两段」」**！
- **⇒ `dumpLayout` 实际写到「`/data/local/tmp/game_Snake`」**（**不是「`game_Snake 3D.json`」**）
- **⇒ `cat /data/local/tmp/game_Snake 3D.json`** —— **`cat` 也「被切成「两个参数」」**
- **⇒ 读的是「`/data/local/tmp/game_Snake`」（如果存在）或「报错」** ⇒ **`json.loads` 抛异常** ⇒ **`None`** ⇒ **`GAME_DUMP_FAIL`**

## 为什么「只有「带空格的游戏」失败

**「`Nonogram`/`Hitori`/`Bejeweled`/`Norinori`」的「`en_name`」都「没有空格」** ⇒ **「路径「没有空格」」** ⇒ **「成功」**。

**「`Snake 3D`/`Fibonacci Merge`/…」的「`en_name`」有空格** ⇒ **「路径有空格」** ⇒ **「失败」**。

**⇒ 「这解释了「为什么「正好是「那 8 款」」」。**

## 修法（v8）

```python
safe = re.sub(r'[^A-Za-z0-9_]', '_', en_name)   # ← 路径只留 ASCII 安全字符
d2 = dump(f'/data/local/tmp/game_{safe}.json')  # ← 'Snake 3D' → 'game_Snake_3D.json'
```

**⚠️ 注意：「`_` 是「安全的」」**（**「`re.sub` 把「空格」和「其它非安全字符」全换成 `_`」**）。

## 修复后实测（5 款之前失败的）

| 游戏 | 状态 | `max_bottom` | `lowest` |
|---|---|---|---|
| **`Snake 3D`** | **`OK`** | `1351` | `'滑动棋盘或点方向键转向；吃满 12 个食物算通关'` |
| **`Fibonacci Merge`** | **🔴 `PUSHED_OUT`** | **`1600`** | **`'重开'`** |
| **`Memory Matrix`** | **`OK`** | `1351` | `'重新开始'` |
| **`Color Maze Nav`** | **`OK`** | `1351` | **`'A'`** |
| **`Path Recall`** | **`OK`** | `1287` | **`'×'`** |

**⇒ 「5 款里「4 款 `OK`」」** ✓
**⇒ 「`GAME_DUMP_FAIL` 完全消失」** ✓

## 🔴 而这就找到了「第二个真溢出」

**`Fibonacci Merge`**：
- **状态**：**`PUSHED_OUT`**
- **`max_bottom`**：**`1600`**
- **`lowest`**：**`'重开'`**

**⇒ 「最底下的元素是「重开」按钮，它在 `1600`（屏底）」。**

**⇒ 「这是「第二个真问题」」**（**和「`Yajilin`」并列**）。

## 今晚「布局验证」的完整成果

| 游戏 | 状态 | 说明 |
|---|---|---|
| **`Yajilin`** | **`TIGHT`（`1568`）** | **「已修」（`1600 → 1568`）** |
| **`Fibonacci Merge`** | **🔴 `PUSHED_OUT`（`1600`）** | **「今晚发现，明早修」** |
| **`Nonogram`** | **`TIGHT`（`1557`）** | **「可接受」** |
| **`Snake 3D`/`Memory Matrix`/`Color Maze Nav`/`Path Recall`/`Hitori`/`Kakuro`/`Nurikabe`/`Bejeweled`/`Norinori`** | **`OK`** | — |

## ⭐ 而这条是「今晚最贵的 bug」

**「一个「路径里的空格」」** —— **「让 8 款游戏「全部失败」」，而且「错误信息「完全误导」（`GAME_DUMP_FAIL` 看起来像「游戏本身有问题」）」**。

**⇒ 「这正是「判据 1819 第五类」的教科书案例」**：
- **现象**：**「8 款游戏 `dump` 失败」**
- **误导归因**：**「游戏本身有问题」**（**`v5` 猜「空格」，但「猜错了方向」——「以为是「搜索词」的空格，其实是「路径」的空格」**）
- **真实机制**：**「路径有空格 ⇒ `hdc shell` 按空格切参数」**

**⇒ 判据 1849（立）**：
> **「给 `hdc shell` 传「含空格」的路径时必须「消毒」」** ——
> **`hdc shell "cmd /tmp/a b.json"` 会「切成「两个参数」」。**
> **⇒ 路径里「不要有空格」**（**用 `_` 或「提前 sanitize」**）。
>
> **⚠️ 而「更一般的」**：
> **「所有「拼进 shell 命令的变量」都要「消毒」」** —— **「尤其是「来自「用户数据」的」**（**如「游戏名」**）。
