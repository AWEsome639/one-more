# 判据 3000：`NOT_HOME` 里 44% 是**空 dump**，不是游戏的问题

## 一、量化

全台账 `NOT_HOME` 共 **66** 条，按失败备注分类：

| 备注形态 | 条数 | 含义 |
|---|---|---|
| `last texts=[…]`（有内容）| **31** | 真不在首页（卡在别的界面）|
| `last texts=[]`（**空**）| **29（44%）** | **一次树都没抓到** |
| `no budget for recovery path` | 6 | 超时，没来得及回 |

⇒ **近一半 `NOT_HOME` 来自「什么都没抓到」**，与游戏本身无关。

## 二、根因

`工具/shot_game.py:110 dump()` **没有重试**：

```python
ok, _ = sh('uitest dumpLayout -p ' + p, timeout)
if not ok:
    return None          # ← 单次失败就放弃
```

而 `is_home()` 拿到 `None` ⇒ 返回 `False` ⇒ 判 `NOT_HOME`。

`1953`（2026-11-12）已经把超时 `25s → 60s`，理由是「负载高时单次 dump 可达 30~40s」——
**但那只是把单次失败率降低，没有消除**。高负载下 `dumpLayout` 偶发失败是常态。

## 三、判据（能改变的）

> **空 dump ⇒ 测量无效，不是被测对象有问题。**

⇒ 任何「没抓到 / 读到空」的失败，**先重试，再判失败**。

⇒ 与 `2603` 同源：
· `2603`：失败备注里含**本该匹配的标题** ⇒ 是判据的问题
· `3000`：失败备注里是**空列表** ⇒ 是采集的问题

⇒ 共同点：**失败信息里已经写着「我没测到」，却被当成「被测对象不合格」。**

## 四、修法（已落地）

`dump()` 改成**最多 3 次**，每次先 `rm` 再抓，中间 `sleep 1.5`：

```python
txt = ''
for _attempt in range(3):
    sh('rm -f ' + p, 10)
    ok, _ = sh('uitest dumpLayout -p ' + p, timeout)
    if ok:
        ok2, _txt = sh('cat ' + p, 15)
        if ok2 and _txt.strip():
            txt = _txt
            break
    if _attempt < 2:
        time.sleep(1.5)
if not txt.strip():
    return None
```

⚠️ **重试只加在「没抓到」上，不加在「抓到了但不是首页」上** ——
后者是真不在首页，重试只会白花时间。

## 五、生效路径（不用重启跑批）

`工具/verify_layout.py:124` 每款 `subprocess.run(['python3','工具/shot_game.py', g])`
⇒ **下一款就是新逻辑**。跑批不用重启。

## 六、验证标准（尚未满足）

**「我觉得能减少」不算证据。** 要看：
1. 之后的新 `NOT_HOME` 里 `last texts=[]` 的比例**显著下降**
2. 且没有把「真不在首页」误判成首页（那是反方向错误，更危险）

⇒ 两者都要看 → 下次跑批跑够 `10` 款以上再统计。

---

## 七、★★★ 追加：**台账是累计的，失败数里混着已修好的 bug**

判据 `2613` 在这一节兑现了。

`NO_CARD` 全台账 `81` 条，看起来是最大的一类。按日期拆：

| 日期 | 条数 |
|---|---|
| 11-12 | 2 |
| 11-13 | 18 |
| 11-14 | 30 |
| 11-15 | 14 |
| 11-16 | 15 |
| 11-17 | 2 |
| **11-18 / 11-19** | **0** |

⇒ 中文输入修复（`2026-11-14`，注释在 `shot_game.py:936-939`）之后逐步收敛，
**最后一条 `NO_CARD` 是 11-17，此后归零**。

⇒ ⇒ **`NO_CARD 81` 是历史存量，不是当前问题。** 差点据此去重写「滚动找卡片」——
而那功能**代码里早就有**（`shot_game.py:949-956`）。两条判据同时拦住：
· `2613`：代码今天被改过 ⇒ 手上的值可能是改动之前的
· 「我发现了一个机会」先搜代码：`grep swipe|scroll` 一搜就知道已实现

## 八、当前真实画像（只看最近两天 `133` 条）

| outcome | 条数 | 占比 |
|---|---|---|
| `OK` | 107 | **80.5%** |
| `TIMEOUT` | 9 | 6.8% |
| `NOT_HOME` | 10 | 7.5% |
| `WRONG_GAME` | 6 | 4.5% |
| `DUMP_FAIL` | 1 | 0.8% |

`NOT_HOME` 10 条里 **7 条是空 dump**（`last texts=[]`）⇒ 占近两天失败的 **27%**。

## 九、可复算的预测（这就是验收标准）

> **`dump()` 加重试之后，后续跑批里 `NOT_HOME` 的 `last texts=[]` 应趋近 0。**
> **同时 `last texts=【有内容】` 的条数不应上升**（那意味着把「真不在首页」误判成首页了）。

⇒ 复算命令（跑够 `10` 款以上再执行）：

```bash
python3 - <<'PY'
rows=[l.split('\t') for l in open('_巡检记录/layout-canonical.tsv',encoding='utf-8') if l.count('\t')>=4]
r=[x for x in rows if x[0][:10] in ('2026-11-19',)]
nh=[x for x in r if x[2]=='NOT_HOME']
print('今晚 NOT_HOME %d：空 %d · 有内容 %d' % (
  len(nh), sum(1 for x in nh if 'last texts=[]' in x[4]),
  sum(1 for x in nh if 'last texts=[' in x[4] and 'last texts=[]' not in x[4])))
PY
```

⇒ **`p99` 耗时 `170s` / `max` `257s`，`>200s` 仅 `0.4%`** ⇒ `SHOT_BUDGET_S=260` **标定正确，不要加**（否定性结论：`62` 条 `TIMEOUT` 是卡死，加预算只会更慢）。
