#!/usr/bin/env python3
"""列出所有 .enabled(...) 及其上下文，供人工复核「条件是否覆盖了动作能否生效」。

★ 2026-11-01（判据 107）：`enabled(!over)` 这种写法语法正确、编译通过、点下去不崩，
  但它让一个"什么都不做"的按钮一直看起来能点。
  这类问题不会出现在任何自动检查里 —— 只能靠列出全部 enabled 逐个问
  「如果现在点它，会发生什么？」
"""
import io, os, re, sys

GAMES = 'entry/src/main/ets/games'


def scan(folder):
    out = []
    for f in sorted(os.listdir(folder)):
        if not f.endswith('.ets') or '.bak' in f:
            continue
        path = os.path.join(folder, f)
        src = io.open(path, encoding='utf-8').read()
        lines = src.split('\n')
        for i, line in enumerate(lines):
            m = re.search(r'\.enabled\(' , line)
            if not m:
                continue
            # 往上找最近的 Button/Text 之类，作为"这个按钮叫什么"
            label = ''
            for k in range(i, max(0, i - 12), -1):
                mm = re.search(r"(?:Button|Text|Row|Column)\(\s*(?:TG\()?'([^']{1,30})'", lines[k])
                if mm:
                    label = mm.group(1)
                    break
            cond = line.strip()
            out.append((f[:-4], i + 1, label, cond))
    return out


def main():
    rows = scan(GAMES)
    print('全项目 .enabled(...) 共 %d 处\n' % len(rows))
    # 分组：条件里出现哪些变量
    buckets = {}
    for g, ln, label, cond in rows:
        body = re.search(r'\.enabled\((.*)\)', cond)
        expr = body.group(1) if body else cond
        vars_ = tuple(sorted(set(re.findall(r'this\.(\w+)', expr))))
        buckets.setdefault(vars_, []).append((g, ln, label, expr))
    print('按"条件里用到的字段"分组：')
    for vars_, items in sorted(buckets.items(), key=lambda x: -len(x[1])):
        print('\n  【%s】%d 处' % (', '.join('this.' + v for v in vars_) if vars_ else '（无字段）', len(items)))
        for g, ln, label, expr in items[:6]:
            print('    %-28s :%-5d %-14s %s' % (g, ln, label, expr[:56]))
        if len(items) > 6:
            print('    … 另 %d 处' % (len(items) - 6))


if __name__ == '__main__':
    main()
