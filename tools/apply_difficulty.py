#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「难度」批量接进限时类游戏（拾海 2026-10-11）

对每款游戏做 5 件事（缺一即为**静默失效**，构建照样通过、界面看不出）：
  ① 加 `private total: number = GameDiff.timeNow(BASE);`
  ② `@State xxx = BASE;` 改成 `= 0;`
  ③ reset 里 `this.xxx = BASE;` → `this.xxx = this.total;`
  ④ `onRestart()` 里加 `this.total = GameDiff.timeNow(BASE);`（**单行/多行两种写法都要认**）
  ⑤ 加 import

跑完**必须**再跑 `--check` 核对这 5 条 —— 光看构建通过不算数。
"""
import io, os, re, sys, glob

GAMES = 'entry/src/main/ets/games'
TIME_RE = re.compile(r"const (\w*(?:LIMIT|TIME|SEC|DURATION)\w*): number = (\d+)")


def find_targets():
    out = []
    for p in sorted(glob.glob(GAMES + '/*.ets')):
        s = io.open(p, encoding='utf-8').read()
        if 'GameDiff.timeNow' in s:
            continue
        for m in TIME_RE.finditer(s):
            cname = m.group(1)
            sm = re.search(r"@State private (\w+): number = " + cname + r";", s)
            if sm:
                out.append((os.path.basename(p), sm.group(1), cname))
                break
    return out


def apply_one(fname, state, cname):
    p = os.path.join(GAMES, fname)
    s = io.open(p, encoding='utf-8').read()
    o = s
    # ① + ②
    s = s.replace(
        f"@State private {state}: number = {cname};",
        f"// ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）\n"
        f"  private total: number = GameDiff.timeNow({cname});\n"
        f"  @State private {state}: number = 0;")
    # ③
    s = s.replace(f"this.{state} = {cname};", f"this.{state} = this.total;")
    # ④ 多行 / 单行两种写法
    need = f"this.total = GameDiff.timeNow({cname});"
    if need not in s:
        m = re.search(r"(onRestart\(\): void \{)([^\n]*)\}", s)
        if m:
            s = (s[:m.start()] + m.group(1) +
                 f"\n    this.total = GameDiff.timeNow({cname});   // 难度可能刚变过，必须重算\n    "
                 + m.group(2) + "}" + s[m.end():])
        else:
            m2 = re.search(r"(onRestart\(\): void \{\n)", s)
            if m2:
                s = s[:m2.end()] + f"    this.total = GameDiff.timeNow({cname});\n" + s[m2.end():]
    # ⑤ 分母
    s = re.sub(r"this\." + state + r" \* 100 / " + cname, f"this.{state} * 100 / this.total", s)
    s = re.sub(r"this\." + state + r" / " + cname, f"this.{state} / this.total", s)
    # import —— ★ 判据必须查 import 行本身，不能查"文件里有没有 GameDiff"
    if "from '../core/GameDiff'" not in s:
        mm = re.search(r"^import .*?;\n", s, re.M)
        if mm:
            s = s[:mm.end()] + "import { GameDiff } from '../core/GameDiff';\n" + s[mm.end():]
    if s != o:
        io.open(p, 'w', encoding='utf-8').write(s)
        return True
    return False


def check():
    """核对必要条件 —— 静默失效只有这里能抓出来

    ⚠️ 找"计时状态"要认 `this.X = this.total;` 这一句，
       不能拿"第一个 @State = 0"当替身（会误报）。
    """
    bad = []
    for p in sorted(glob.glob(GAMES + '/*.ets')):
        s = io.open(p, encoding='utf-8').read()
        if 'GameDiff.timeNow' not in s:
            continue
        fname = os.path.basename(p)
        m = re.search(r"private total: number = GameDiff\.timeNow\((\w+)\);", s)
        if not m:
            bad.append((fname, ['total 声明']))
            continue
        cname = m.group(1)
        # 计时状态 = 被赋值为 this.total 的那个
        sm = re.search(r"this\.(\w+) = this\.total;", s)
        state = sm.group(1) if sm else None
        need = {
            'import': "from '../core/GameDiff'" in s,
            'reset(赋值 total)': state is not None,
            'onRestart(重算)': f"this.total = GameDiff.timeNow({cname});" in s,
        }
        miss = [k for k, v in need.items() if not v]
        if miss:
            bad.append((fname, miss))
    return bad


if __name__ == '__main__':
    if '--check' in sys.argv:
        bad = check()
        total = len([p for p in glob.glob(GAMES + '/*.ets')
                     if 'GameDiff.timeNow' in io.open(p, encoding='utf-8').read()])
        print(f'  核对：{total - len(bad)}/{total} 款 5 条必要条件齐全')
        for f, miss in bad:
            print(f'    ⚠️ {f}: 缺 {miss}')
        sys.exit(1 if bad else 0)
    tg = find_targets()
    print(f'  待处理 {len(tg)} 款')
    n = 0
    for f, st, cn in tg:
        if apply_one(f, st, cn):
            n += 1
    print(f'  ✔ 改了 {n} 款')
