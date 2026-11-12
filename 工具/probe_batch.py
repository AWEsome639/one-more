#!/usr/bin/env python3
"""对一批游戏逐个「打开 → dump → 打印最高的 4 个块」，产出诊断表。

用途（判据 1932/1938）：**改任何容器之前，先知道「谁在占高」** ——
今晚 `Kakurasu Sums` 能一次改对，就是因为我先量到了「棋盘 810px 是空间占主」。

输出：`_巡检记录/probe-batch.tsv`（每行：游戏 / 高度 / y1 / y2 / type / text）
"""
import io, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
OUT = os.path.join(ROOT, '_巡检记录', 'probe-batch.tsv')


def target():
    try:
        out = subprocess.run('%s list targets' % HC, shell=True, capture_output=True,
                             text=True, timeout=25).stdout or ''
    except Exception:
        return None
    for line in out.splitlines():
        line = line.strip()
        if re.match(r'^\d+\.\d+\.\d+\.\d+:\d+$', line):
            return line
    return None


def blocks(t):
    """返回 [(h, y1, y2, type, text)]，按高度降序（排除高度=整屏的根容器）。"""
    cmd = "%s -t %s shell 'uitest dumpLayout -p /data/local/tmp/pb.json >/dev/null 2>&1; cat /data/local/tmp/pb.json'" % (HC, t)
    try:
        raw = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=90).stdout
    except Exception:
        return []
    import json
    try:
        d = json.loads(raw)
    except Exception:
        return []
    rows = []

    def walk(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {}) or {}
        b = (a.get('bounds') or '').strip()
        if b:
            nums = [int(x) for x in re.findall(r'-?\d+', b)]
            if len(nums) == 4:
                h = nums[3] - nums[1]
                ty = a.get('type') or ''
                # ★ 2026-11-12 修正：整屏容器（`root`/`WindowScene`/`Stack`/`Flex`/`EffectComponent`）
                #   会占满高度而毫无信息量 ⇒ 排除；同时只保留**页头以下**（`y1 >= 340`）的真实内容块。
                ROOTISH = ('root', 'WindowScene', 'EffectComponent', 'Flex')
                if h < 1400 and nums[1] >= 340 and ty not in ROOTISH:
                    rows.append((h, nums[1], nums[3], ty, (a.get('text') or '')[:14]))
        for c in (n.get('children') or []):
            walk(c)

    walk(d)
    # ★ 2026-11-12（判据 1925 的延伸）：**「最高的」和「最靠下的」是两回事** ——
    #   `Tapa`/`Kurodoko` 的最深块只到 `1306/1204`，但 `max_bottom=1583` ⇒
    #   真正触底的是**一个很矮的节点（说明行/按钮）**，只看「最高 4 个」看不见它。
    rows.sort(key=lambda r: -r[0])
    tallest = rows[:4]
    rows.sort(key=lambda r: -r[2])
    deepest = rows[:4]
    return tallest, deepest


def main():
    names = sys.argv[1:]
    if not names:
        print(__doc__)
        return 2
    t = target()
    if not t:
        print('设备不在（hdc list targets 空）')
        return 1
    fh = io.open(OUT, 'a', encoding='utf-8')
    for g in names:
        # 先让 shot_game 把游戏打开（它自己会处理搜索/精确定位）
        r = subprocess.run(['python3', os.path.join(ROOT, '工具', 'shot_game.py'), g],
                           capture_output=True, text=True, timeout=320, cwd=ROOT)
        last = (r.stdout or '').strip().split('\n')[-1]
        # ★ 2026-11-12：**打开失败就别 dump** —— 否则量到的是首页卡片（`Tapa` 那次就是这样）
        if '\tOK\t' not in last and '\tOK_NOSHOT\t' not in last:
            print('\n=== %s === 跳过（打开失败）: %s' % (g, last[:70]), flush=True)
            fh.write('%s\tSKIP\t-\t-\t%s\t%s\n' % (g, 'open-failed', last.split('\t')[1] if '\t' in last else '?'))
            continue
        print('\n=== %s === %s' % (g, last.split('\t')[2]), flush=True)
        tallest, deepest = blocks(t)
        print('\n=== %s ===' % g, flush=True)
        print('  ── 最高 4 个（谁占空间）──', flush=True)
        for h, y1, y2, ty, tx in tallest:
            fh.write('%s\tTALL\t%d\t%d\t%d\t%s\t%s\n' % (g, h, y1, y2, ty, tx))
            print('  h=%4d y=[%4d..%4d] %-10s %r' % (h, y1, y2, ty, tx), flush=True)
        print('  ── 最靠下 4 个（谁触底）──', flush=True)
        for h, y1, y2, ty, tx in deepest:
            fh.write('%s\tDEEP\t%d\t%d\t%d\t%s\t%s\n' % (g, h, y1, y2, ty, tx))
            print('  h=%4d y=[%4d..%4d] %-10s %r' % (h, y1, y2, ty, tx), flush=True)
    fh.close()
    print('\n诊断表已追加到 %s' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
