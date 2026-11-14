# ★★ `Percentage Shopping` 的减元素路径（明晚 `P1` 用）

> `2026-11-14 12:0x`。它没有限宽算式（全 `layoutWeight`）⇒ 只能减元素。这是查出来的可减项。

## 一、结构

```
L363  Column({ space: isShort ? sm : md })          ← 主容器
L379  Row({ space: sm })                            ← 三张统计卡
L380-383   Column: '第几件' + round/total
             .layoutWeight(1).padding(Space.sm)
             .backgroundColor(surface).borderRadius(Radius.md).shadow(Shadow.card)
L384-387   Column: '答对' + right/PASS               ← 同上
L388-394   Column: '得分' + score                   ← 同上
L397  Column({ space: Space.xs })
L399     Text(this.icon).fontSize(isShort ? FontSize.xxl : FontSize.hero)   ← **大图标**
```

## 二、可减项

| 位置 | 内容 | 估计可省 |
|---|---|---:|
| `L379-394` | **三张统计卡**：各 `label(xxs≈10vp) + value(lg≈20vp) + padding(sm 8vp × 2) = 46vp` | **`~20vp`**（改成一行紧凑、去 `padding`/`shadow`）|
| `L399` | **大图标**：`FontSize.hero`（矮屏已降 `xxl`）| **`~15vp`**（矮屏再降一档，如 `xl`）|
| **合计** | | **`~35vp`** |

## 三、⇒ 这 `35vp` 够不够

**它的功能级表现是：`lowest='3'`（选项值）只剩 `5px` 可见。**
**⇒ 一个选项值正常高约 `40px` ⇒ 被裁约 `35px` = `12vp`。**

**⇒ 所以只要省 `12vp` 就够，而可减项有 `35vp` ⇒ **余量充足**。**

**⚠️ 但这是按「被裁 `35px`」推的，而 `bounds` 被钳在 `1600` ⇒ 实际裁掉多少不可知（可能更多）。
⇒ 所以**仍需 `board=` 数据确认**，但方向是对的。**

## 四、⇒ `Calculation Sprint` 的同类可减项

```
L478  Row           ← 头部/统计
L486  Stack         ← 进度条
L502  Column: quiz 文字 + '连击 ×{0} · 最高 ×{1} · 第 {2} 题'
L520  Column: 四个选项（Row: LETTERS[i] + opts[i]）
L553  Text(this.msg)          ← **消息行**（可减）
L563  Button(重开/再来一局)   ← 按钮
```

**⇒ 可减：`L553` 的消息行（可并入题目区）+ `L507` 的连击信息（可并入头部统计）⇒ 约 `~30vp`。**

## ⇒ 判据（`2201`）

**「减元素」也不是随便减 —— 要先看**哪些元素是辅助性的**（统计卡、说明行、大图标、进度条），
而不是动核心玩法元素（选项、题目、按键）。**

**⇒ 判据：减元素的顺序是「装饰 → 辅助信息 → 缩字号 → 动核心」。
⇒ 这次两款的可减项都落在前两档：统计卡（装饰/辅助）、消息行（辅助）、大图标（装饰）。**

## ⇒ 判据（`2202`）

**代码里已有的 `Bp.isShort()` 分支，是「作者也认为这里该缩」的证据。**
**⇒ 这次 `L399` 已经写了 `isShort ? xxl : hero` ⇒ 说明「矮屏降字号」是被认可的，只是降得不够。**

**⇒ 判据：找可减项时，先 `grep` `isShort` / `Bp.height <` —— 那些地方作者已经标记了「这里可以缩」，
只需再缩一档即可，改动风险最低。**
