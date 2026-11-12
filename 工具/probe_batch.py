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
                if h < 1590:            # 排除整屏根容器
                    rows.append((h, nums[1], nums[3], ty, (a.get('text') or '')[:14]))
        for c in (n.get('children') or []):
            walk(c)

    walk(d)
    rows.sort(reverse=True)
    return rows[:4]


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
        subprocess.run(['python3', os.path.join(ROOT, '工具', 'shot_game.py'), g],
                       capture_output=True, text=True, timeout=320, cwd=ROOT)
        rows = blocks(t)
        print('\n=== %s ===' % g, flush=True)
        for h, y1, y2, ty, tx in rows:
            line = '%s\t%d\t%d\t%d\t%s\t%s' % (g, h, y1, y2, ty, tx)
            fh.write(line + '\n')
            print('  h=%4d y=[%4d..%4d] %-10s %r' % (h, y1, y2, ty, tx), flush=True)
    fh.close()
    print('\n诊断表已追加到 %s' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
