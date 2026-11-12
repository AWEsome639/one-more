# `工具/probe_batch.py` —— 一批游戏一次拿到「谁在占高」

## 它解决什么问题

**今晚 `Kakurasu Sums` 一次就改对**，因为我先量到：
```
Column [381..1351]
  Row    h=114   统计卡
  Row    h=171   提示 + AI 代打
  Column h=810   ← 棋盘（空间占主）
  Row    h=100   ← 底部工具栏（屏内只剩 16px）
```
**⇒ 立刻能算出「需腾 84px ÷ 6 行 = 每行 14px」。**

**而 `Kakuro` 我改错 `10` 次，就是因为**没有先做这一步**。**

## 用法

```bash
python3 工具/probe_batch.py "Number Bonds" "Math Maze" "Tapa"
```

**输出**（同时追加到 `_巡检记录/probe-batch.tsv`，可累积、可复算）：
```
=== Tapa ===
  h= 812 y=[ 684..1496] Column     ''
  h= 171 y=[ 507.. 678] Row        '提示'
  h= 114 y=[ 387.. 501] Row        '步数'
  h= 100 y=[1500..1600] Row        '涂黑'
诊断表已追加到 …/probe-batch.tsv
```

## 设计上的三条小心

| 点 | 为什么 |
|---|---|
| **复用 `shot_game` 来打开游戏** | 搜索/精确名/回首页那一套已经调好了，不重复实现（判据 1942）|
| **排除高度 ≥ `1590` 的节点** | 那就是整屏根容器，量它没意义（判据 1925 的教训）|
| **结果追加到 `tsv`** | 判据 1945：不许只打印到终端 |

## 明天怎么用（`17` 款优先队列）

```bash
python3 工具/probe_batch.py "Number Bonds" "Math Maze" "Tapa" "Modular Clock Arithmetic" \
  "Kurodoko" "Pythagorean Triple Builder" "Fraction Matcher" "Block Stacking Physics" \
  "Phonetic Guess" "Base Shift" "Numerical Estimation" "Digit Span Reverse" \
  "Context Clues" "Switch Task" "Object Displacement" "Snake 3D" "Binary Code"
```

**⇒ 拿到每款的「空间占主」后，按 `需腾像素 ÷ 行数` 算一刀，一次一款。**
