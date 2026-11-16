# 工具加固（`shot_game.py`）+ 9 款溢出复查 —— 2026-11-10

> 执行：**perf-hunter**｜**只读 + 只写本 md**（未改任何文件、未编译、未碰设备）
> 任务 A：批处理静默停的根因 + 加固补丁（精确 diff）
> 任务 B：9 款「无大格子」游戏的底块复查 + 删块/收间隙补丁

---

# 第一部分：`工具/shot_game.py` 加固

## 1.1 证据底数
- 文件 **180 行**（`工具/shot_game.py`，mtime `11-10 10:27`）
- 外部调用共 **3 类**：`hdc shell`（`sh()`，`timeout=30`）、`hdc file recv`（`timeout=90`，**无 try**）、本地文件读（`GameRegistry.ets`）

## 1.2 可能「长时间挂住 / 静默停」的 7 处（按危害排序）

| # | 位置 | 问题 | 后果 |
|---|---|---|---|
| **①** | `sh():15` `subprocess.run(..., capture_output=True, timeout=30)` | **「假超时」**：`run(timeout=)` 超时后 `kill()` 子进程，但随后 `communicate()` **继续等 stdout/stderr 管道 EOF**；若 `hdc` 留下子进程/设备端 shell 仍握着管道，**`run()` 永不返回** | **这就是「跑到 56/68 无声结束」的最可能主因**：进程挂死、没有输出、没有退出码 |
| **②** | `sh():17-18` `except Exception: return ''` | **吞掉一切异常**（超时/找不到 hdc/脚本错），只返回空串 | `dump()` 拿到 `''` → `json` 解析失败 → `None`；上层 `continue`/`return` ⇒ **静默跳过，无任何记录** |
| **③** | `dump():20-25` 固定路径 `/data/local/tmp/shot*.json` | 超时/失败后 `cat` 读到的是**上一次的旧文件**（本项目已踩过的 stale-dump 陷阱） | **比挂住更坏**：不报错、但**数据是上一款的** ⇒ 结论错 |
| **④** | `main():172-173` `file recv ... timeout=90` **无 try** | 超时抛 `TimeoutExpired` 直接冒泡到顶层 | `main()` 带 traceback 退出；批处理若只重定向 stdout ⇒ **看着像静默停** |
| **⑤** | `main():105-123` 搜索重试 `tokens[:3]+[name]` × 每轮最多 4 次 `is_home()` | **没有「单款总预算」**；每次 `is_home()` = 1 次 dump（最坏 2×30s） | 单款最坏 **15+ 分钟**，批处理看起来“卡住” |
| **⑥** | 全文件 | **没有每款的耗时/阶段输出**；4 条早退路径（`NOT_HOME`/`DUMP_FAIL`/`NO_CARD`/`WRONG_GAME`）**不带耗时** | 批处理无法判断卡在哪款、哪一步 |
| ⑦ | `game_title_map():40-51` | 每次调用都重读 9k 行 `GameRegistry.ets` + 全文正则；每款至少调 **3 次** | 慢但不致命，顺手加个缓存 |

## 1.3 加固补丁（精确 diff，**未实施**）

### 补丁 1：新增「杀进程组」的执行器（治 ①，**最关键**）
```diff
@@
-import io, os, re, subprocess, sys, time, json
+import io, os, re, signal, subprocess, sys, time, json, traceback
@@
 HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
 DEV = '127.0.0.1:5557'
 ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
 
-def sh(cmd, timeout=30):
-    try:
-        r = subprocess.run([HC, '-t', DEV, 'shell', cmd], capture_output=True, text=True, timeout=timeout)
-        return r.stdout or ''
-    except Exception:
-        return ''
+class Timeout(Exception):
+    pass
+
+def run(argv, timeout):
+    """硬超时执行：超时杀【整个进程组】。
+
+    为什么不用 subprocess.run(timeout=)：它在超时后只 kill 子进程本身，
+    随后 communicate() 仍要等 stdout/stderr 的 EOF —— hdc 若留下子进程握着管道，
+    就会【永远卡住】（这正是批处理"无声停在 56/68"的最可能原因）。
+    """
+    try:
+        p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
+                             text=True, start_new_session=True)   # ← 独立进程组
+    except Exception as e:
+        raise Timeout('spawn-failed: %r' % (e,))
+    try:
+        out, err = p.communicate(timeout=timeout)
+        return p.returncode, (out or ''), (err or '')
+    except subprocess.TimeoutExpired:
+        try:
+            os.killpg(os.getpgid(p.pid), signal.SIGKILL)   # ← 连子进程一起杀
+        except Exception:
+            pass
+        try:
+            p.communicate(timeout=5)                       # ← 收尸，最多再等 5s
+        except Exception:
+            pass
+        raise Timeout('timeout %ss: %s' % (timeout, ' '.join(argv[-1:])[:60]))
+
+def sh(cmd, timeout=30):
+    """返回 (ok, out)。**永不吞异常成空串** —— 失败要能被上层看见。"""
+    try:
+        rc, out, _err = run([HC, '-t', DEV, 'shell', cmd], timeout)
+        return (rc == 0), out
+    except Timeout:
+        return False, ''
```

### 补丁 2：`dump()` 用**唯一路径** + 存在性检查（治 ②③）
```diff
-def dump(p='/data/local/tmp/shot.json'):
-    sh(f'uitest dumpLayout -p {p}')
-    try:
-        return json.loads(sh(f'cat {p}'))
-    except Exception:
-        return None
+_SEQ = 0
+def dump(tag='d', timeout=25):
+    """唯一路径 dump：避免"超时后 cat 到上一款的旧文件"（stale dump）"""
+    global _SEQ
+    _SEQ += 1
+    p = '/data/local/tmp/shot_%d_%d_%s.json' % (os.getpid(), _SEQ, tag)
+    sh('rm -f ' + p, 10)                       # 先清，保证不存在
+    ok, _ = sh('uitest dumpLayout -p ' + p, timeout)
+    if not ok:
+        return None
+    ok2, txt = sh('cat ' + p, 15)
+    if not ok2 or not txt.strip():
+        return None
+    try:
+        return json.loads(txt)
+    except Exception:
+        return None                            # 解析失败 = 本次无效（不会拿到旧文件）
```

### 补丁 3：每款总预算 + 统一出口 + 耗时（治 ⑤⑥）
```diff
+DEADLINE = 0.0
+def budget_left():
+    return DEADLINE - time.monotonic()
+
+def finish(name, outcome, t0, extra=''):
+    """**所有 return 都走这里**：一款一行，带 outcome 与耗时，永不静默"""
+    print('%s\t%s\t%.1fs\t%s' % (name, outcome, time.monotonic() - t0, extra))
+
 def main():
+    global DEADLINE
+    t0 = time.monotonic()
+    DEADLINE = t0 + 150.0        # ← 单款硬预算 150s
     if len(sys.argv) < 2:
         print(__doc__); return
     name = sys.argv[1]
+    outcome = 'UNKNOWN'
+    try:
+        return _main_body(name, t0)
+    except Timeout as e:
+        finish(name, 'TIMEOUT', t0, str(e))
+    except Exception as e:
+        finish(name, 'CRASH', t0, repr(e))
+        traceback.print_exc(limit=3)
```
（`_main_body` = 原 `main` 除首尾的整段；内部每个 `return X` 改成 `finish(name, X, t0); return`）

### 补丁 4：`file recv` 加超时与失败记录（治 ④）
```diff
-    subprocess.run([HC, '-t', DEV, 'file', 'recv', f'/data/local/tmp/shot_{safe}.jpeg', out],
-                   capture_output=True, text=True, timeout=90)
+    try:
+        rc, _o, _e = run([HC, '-t', DEV, 'file', 'recv',
+                          '/data/local/tmp/shot_%s.jpeg' % safe, out], 60)
+        recv_ok = (rc == 0 and os.path.exists(out))
+    except Timeout:
+        recv_ok = False
@@
-    print(f'[{_ts}] {name}: max_bottom={mb} lowest={lo!r} -> {out}')
+    finish(name, 'OK' if recv_ok else 'OK_NOSHOT', t0,
+           'max_bottom=%d lowest=%r -> %s' % (mb, lo, out if recv_ok else '(recv failed)'))
```

### 补丁 5：`game_title_map()` 加缓存（治 ⑦）
```diff
+_TITLE_CACHE = None
 def game_title_map():
+    global _TITLE_CACHE
+    if _TITLE_CACHE is not None:
+        return _TITLE_CACHE
     ...
-    return m
+    _TITLE_CACHE = m
+    return m
```

### 补丁 6：批处理模板（`/tmp` 那份，按此重写）
```python
import subprocess, sys, time
games = [...]
done = 0
for i, g in enumerate(games, 1):
    t = time.monotonic()
    try:
        r = subprocess.run([sys.executable, '工具/shot_game.py', g],
                           capture_output=True, text=True, timeout=200,
                           start_new_session=True)          # ← 同样防挂
        out = (r.stdout or '').strip().splitlines()
        last = out[-1] if out else '(no output)'
        print(f'[{i}/{len(games)}] {last}  ({time.monotonic()-t:.0f}s)', flush=True)
    except subprocess.TimeoutExpired:
        print(f'[{i}/{len(games)}] {g}\tBATCH_TIMEOUT\t{time.monotonic()-t:.0f}s', flush=True)
    done += 1
print(f'DONE {done}/{len(games)}', flush=True)                # ← 永远打这一行
```

**加固后「静默停」会变成什么**：最坏情况每款打一行 `TIMEOUT/NOT_HOME/DUMP_FAIL/CRASH`，
批处理末尾**必有** `DONE n/N`；**再也不会出现“跑到 56/68 就没了”**。

---

# 第二部分：9 款溢出的底块复查

## 2.1 ⚠️ 先纠一个前提（判据 1824：读代码，不看命名）
任务里说「这 9 款既没有 `Cell.of(≥40)` 也没有 `Cell.tap`」——**实测不成立，9 款里有 4 款冲突**：

| 游戏 | 实测 | 是什么 |
|---|---|---|
| `GBubbleShooter` | `:576` **`Cell.of(46)`** | 重开按钮高度 |
| `GStroopTest` | `:313` **`Cell.of(62)`** | **答题区**（`layoutWeight(1)`）—— 真·大块 |
| `GSlidePuzzle` | `:516` **`Cell.tap(44)`** | 重开按钮高度 |
| `GRadicalRoots` | `:382` / `:393` `Cell.of(48|56)` | 两个操作按钮（`layoutWeight(1)`，并列） |
| 其余 5 款 | 最大 `Cell.of(32)` / 无 | 确实是小格子 |

⇒ **9 款里 4 款有「≥40 的固定高度」，其中 3 款是按钮、1 款（Stroop）是答题区**。
⇒ 建议：**先按「按钮高度」与「棋盘高度」分开看**，别把按钮高度当成格子尺寸。

## 2.2 逐款：最底那块是什么 + 补丁

| # | 游戏 | 最底那块（行号） | 已矮屏门控？ | 补丁 | 预估省 |
|---|---|---|---|---|---|
| 1 | `GAssociativePairs` | `Text(TG2('用时 {0}s · 连对越长分越高'))` **:397** | ❌ | 加 `Bp.isShort() ? Visibility.None : Visible` | ~14vp |
| 2 | `GBubbleShooter` | `Text(TG2('同色连 3 颗起炸；…'))` **:591-593** | ❌ | 同上 | ~14vp |
| 3 | `GLetterCancellation` | `Text(TG2('划满 {0} 盘通关；漏一个罚 3 秒…'))` **:358** | ❌ | 同上 | ~14vp |
| 4 | `GLetterGridSwapper` | 按钮 **:327-329**（门控✓）、提示 **:338-340**（门控✓） | ✅✅ | **底块无肉**：溢出在目标单词栏（`:295` 附近 `FontSize.xxl`）⇒ 短屏 `xxl → xl` | ~12vp |
| 5 | `GRadicalRoots` | `Text(TG('把 n 拆成 平方数 × 无平方因子数'))` **:427** | ❌ | 门控 **:427** + 短屏把两个操作按钮 `48/56 → 40/44`（`:382/:393`） | ~14 + 8vp |
| 6 | `GSlidePuzzle` | **重开按钮 `Cell.tap(44)` :516**（无任何门控） | ❌ | 给 :516 加 `Bp.isShort()` 门控 | **44vp（最大一块）** |
| 7 | `GStroopTest` | `Text(TG('判定：12 题答对 ≥ 10 题…'))` **:295** | ❌ | 门控 **:295** + 短屏答题区 `62 → 52`（`:313`） | ~14 + 10vp |
| 8 | `GTrailMaking` | 按钮 **:340-341**（门控✓）、提示 **:351-354**（门控✓） | ✅✅ | **底块无肉**：溢出在棋盘 `ForEach(ROWS)` 段；需单独查棋盘行高/`space` | 待查 |
| 9 | `GVisualSearch` | 重开 **:314-316**（门控✓）、`Text(this.msg)` **:312**（未门控，但它是反馈行） | ◐ | 短屏把 `msg` 改 `fontSize.sm` + `maxLines(1)` | ~10vp |

## 2.3 汇总
- **6 款有明确可删/可收的底块**：①③⑤⑥⑦（含大肉 `SlidePuzzle` 44vp）+ ② 同款式提示 ⇒ **1/2/3/5/6/7 六款**
- **2 款底块已无肉**（`LetterGridSwapper`、`TrailMaking`）——问题在棋盘/目标栏，**这两款要单独看**
- **1 款只需收反馈行**（`VisualSearch`）
- **最省事、收益最大的一刀**：`GSlidePuzzle:516` 的重开按钮（**44vp**，且页头 ↻ 同动作，与 `1880 补漏` 的既有做法完全一致）

## 2.4 统一补丁形状（与既有 1880/1853/1867 判据一致）
```diff
       Text(TG2('…说明文字…')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
+        // ★ 矮屏不渲染说明行（页头已有 ↻ / 规则见首页，判据 1853/1867）
+        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
```
> 全项目已有 20+ 处同款写法，**改法统一、零新风险**；改完用 `check_assertions.sh` 看基线仍 `200359 / 0`。
