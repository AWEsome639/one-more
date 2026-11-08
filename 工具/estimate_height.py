# -*- coding: utf-8 -*-
# ⛔ 这个脚本的「高度估算」**不可用作判据**（2026-11-09 实测校准失败，见 _巡检记录/静态估高失败-20261109.md）
#   与真机实测「零相关」：
#     GGame24        估 558vp（最高档）→ 实测 OK
#     GSudoku        估 286vp（最低档）→ 实测 1600（但看图正常）
#     GCompoundConnect 估 262vp     → 实测「真溢出」（修前）
#   ⇒ 只当「块数 / 间隙档位」的统计工具用，别拿它排优先级。
"""静态估算「每款游戏根 Column 的内容总高」（不需要真机）

用途：给「横屏溢出」排优先级 —— 估出来的高度超 395vp（横屏 533vp 的游戏区）越多，越可能真溢出。
⚠️ 只是「排序用」，不是判据；真判据是「真机 dump + 截图」（判据 1854）。

用法：python3 工具/estimate_height.py [topN]
"""
import io, glob, os, re, sys

AVAIL_VP = 395.0          # 横屏 533vp 减去页头/顶栏后的大致可用高
SPACE = {'xxs': 2, 'xs': 6, 'tiny': 8, 'sm': 10, 'snug': 12, 'md': 16, 'lg': 24, 'xl': 32}

def block_of(s, start):
    """从 start（'{' 的位置）开始做花括号配对，返回 block 内文本与结束位置"""
    i = s.find('{', start)
    if i < 0:
        return '', start
    depth, j = 0, i
    while j < len(s):
        if s[j] == '{':
            depth += 1
        elif s[j] == '}':
            depth -= 1
            if depth == 0:
                return s[i + 1:j], j
        j += 1
    return s[i + 1:], len(s)

CHILD_START = re.compile(r'^\s{6}([A-Za-z_][A-Za-z0-9_]*)\s*\(', re.M)

def estimate(path):
    s = io.open(path, encoding='utf-8').read()
    m = re.search(r'build\(\)\s*\{', s)
    if not m:
        return None
    body, _ = block_of(s, m.end() - 1)
    # 根 Column 的 space 档
    ms = re.search(r'Column\(\{\s*space:\s*Space\.(\w+)', body)
    gap = SPACE.get(ms.group(1), 10) if ms else 10
    # 直接子块：按 6 空格缩进的组件调用切
    starts = [c.start() for c in CHILD_START.finditer(body)]
    if not starts:
        return None
    starts.append(len(body))
    pieces = [body[starts[k]:starts[k + 1]] for k in range(len(starts) - 1)]
    total, unknown = 0.0, 0
    for pc in pieces:
        name = CHILD_START.match(pc).group(1)
        if name in ('DemoBar',):
            h = 0.0
        elif name in ('HintBar',):
            h = 34.0
        elif name in ('Text', 'Button'):
            h = 26.0 if name == 'Button' else 14.0
        elif name in ('Row', 'Column', 'Stack', 'Grid'):
            cells = [int(x) for x in re.findall(r'Cell\.of\((\d+)\)', pc)]
            taps = [int(x) for x in re.findall(r'Cell\.tap\((\d+)\)', pc)]
            cand = cells + taps
            if cand:
                # 一个块内有 N 个固定高元素：竖向堆叠按张数估、横向按最大
                rows = len(re.findall(r'Row\(\{', pc)) + 1
                h = float(max(cand)) * max(1, min(rows, 4))
            else:
                h = 20.0
                unknown += 1
        else:
            h = 20.0
            unknown += 1
        total += h
    total += gap * max(0, len(pieces) - 1)
    return {'file': os.path.basename(path)[:-4], 'blocks': len(pieces), 'gap': gap,
            'est': round(total, 0), 'unknown': unknown}

def main():
    topn = int(sys.argv[1]) if len(sys.argv) > 1 else 25
    rows = []
    for f in sorted(glob.glob('entry/src/main/ets/games/*.ets')):
        r = estimate(f)
        if r:
            rows.append(r)
    rows.sort(key=lambda r: -r['est'])
    print(f"{'游戏':28s} {'块':>3s} {'间隙':>4s} {'估计高':>6s} {'未知块':>5s}  超 395vp")
    for r in rows[:topn]:
        over = r['est'] - AVAIL_VP
        flag = f"⚠️ +{over:.0f}vp" if over > 0 else ""
        print(f"{r['file']:28s} {r['blocks']:3d} {r['gap']:4d} {r['est']:6.0f} {r['unknown']:5d}  {flag}")
    over_n = sum(1 for r in rows if r['est'] > AVAIL_VP)
    print(f"\n共估 {len(rows)} 款，估计超过 {AVAIL_VP:.0f}vp 的 {over_n} 款")
    io.open('/tmp/est_rank.json', 'w', encoding='utf-8').write('\n'.join(
        f"{r['file']}\t{r['est']:.0f}\t{r['blocks']}\t{r['gap']}" for r in rows))

if __name__ == '__main__':
    main()
