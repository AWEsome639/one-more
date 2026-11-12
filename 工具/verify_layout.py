#!/usr/bin/env python3
"""批量验证 + **写唯一台账**（判据 1945）。

用法：
  python3 工具/verify_batch.py                 # 跑默认清单（已修 6 + 疑似溢出 18 + 前缀歧义 4）
  python3 工具/verify_batch.py --names a b c   # 只跑指定游戏（英文全名，判据 1942）
  python3 工具/verify_batch.py --every 12      # 每 12 款重启一次模拟器（判据 1923b）

设计要点：
· **单款失败不影响后续**（每款独立 subprocess，带超时）
· **每 15 款重启模拟器**（判据 1923：连跑会劣化）
· **结果自动进 `_巡检记录/layout-canonical.tsv`**（由 shot_game 的 finish() 写入）
· **结束时打印「本轮 N 款：OK/TIGHT/溢出」**，并直接给出溢出清单
"""
import io, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = '/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'

FIXED = ['Nonogram', 'Nurikabe', 'Masyu', 'Relational Memory', 'Math Path', 'Kakurasu Sums']
SUSPECT = ['Wordle', 'Kakuro Mini', 'Magnets', 'Path Finder', 'Base Conversion Run', 'Binomial Match',
           'Modulo Clock', 'Number Bonds All', 'Pattern Sequence Draw', 'Percentage Peak',
           'Stroop Test', 'Corsi Backward Span', 'Futoshiki', 'Collatz', 'Common Denominator']
AMBIG = ['Binary Matrix Rank All', 'Visual Search All', 'Cryptogram All', 'Word Ladder']


def restart_emu():
    print('  · 重启模拟器…', flush=True)
    subprocess.run('%s -stop onemore' % EMU, shell=True, capture_output=True, timeout=90)
    time.sleep(5)
    subprocess.Popen('%s -start onemore -noWindow > /tmp/emu_verify.log 2>&1' % EMU, shell=True)
    time.sleep(120)
    hc = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
    subprocess.run('%s tconn 127.0.0.1:5557' % hc, shell=True, capture_output=True, timeout=30)
    time.sleep(3)


HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'


def device_alive():
    """★ 2026-11-12（判据 1923b）：模拟器会在批中**静默消失**（`list targets` = Empty）。
    单纯「每 15 款重启」不够 —— 必须在**每款之前**探活，没了就立刻拉起并等它回来。
    """
    try:
        out = subprocess.run('%s list targets' % HC, shell=True, capture_output=True,
                             text=True, timeout=25).stdout or ''
    except Exception:
        return False
    return any(l.strip().count(':') == 1 and l.strip()[0].isdigit() for l in out.splitlines())


def ensure_device(wait_s=200):
    """设备不在就冷启动并轮询到活；返回是否可用。"""
    if device_alive():
        return True
    print('  · 设备不在 ⇒ 冷启动模拟器…', flush=True)
    subprocess.run('pkill -9 -f "Emulator -start"', shell=True, capture_output=True, timeout=30)
    time.sleep(3)
    subprocess.Popen('%s -stop onemore' % EMU, shell=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(4)
    subprocess.Popen('%s -start onemore -noWindow > /tmp/emu_wd.log 2>&1' % EMU, shell=True)
    t0 = time.time()
    while time.time() - t0 < wait_s:
        time.sleep(10)
        if device_alive():
            subprocess.run('%s tconn 127.0.0.1:5557' % HC, shell=True,
                           capture_output=True, timeout=25)
            time.sleep(3)
            return True
    return False


def main():
    args = sys.argv[1:]
    every = 15
    if '--every' in args:
        every = int(args[args.index('--every') + 1])
    names = FIXED + SUSPECT + AMBIG
    if '--names' in args:
        names = [a for a in args[args.index('--names') + 1:] if not a.startswith('--')]
    results = []
    for i, g in enumerate(names, 1):
        if i > 1 and (i - 1) % every == 0:
            restart_emu()
        ensure_device()
        t0 = time.time()
        try:
            r = subprocess.run(['python3', os.path.join(ROOT, '工具', 'shot_game.py'), g],
                               capture_output=True, text=True, timeout=320, cwd=ROOT)
            line = (r.stdout or '').strip().split('\n')[-1]
        except subprocess.TimeoutExpired:
            line = '%s\tTIMEOUT\t-\t%.1fs shot_game 超时' % (g, time.time() - t0)
        print('[%d/%d] %s' % (i, len(names), line[:96]), flush=True)
        results.append(line)
    # ★ 2026-11-12：**失败款自动重试一轮** —— 批中掉线是常态（今天 23/25 全挂就是设备没了），
    #   重试前 `ensure_device()` 会把模拟器拉回来，所以第二轮通过率会显著高于第一轮。
    retry = [ln.split('\t')[0] for ln in results
             if len(ln.split('\t')) > 2 and ln.split('\t')[2] == '-']
    if retry and '--no-retry' not in args:
        print('\n===== 第二轮：重试 %d 款 =====' % len(retry), flush=True)
        ensure_device()
        for i, g in enumerate(retry, 1):
            ensure_device()
            t0 = time.time()
            try:
                r = subprocess.run(['python3', os.path.join(ROOT, '工具', 'shot_game.py'), g],
                                   capture_output=True, text=True, timeout=320, cwd=ROOT)
                line = (r.stdout or '').strip().split('\n')[-1]
            except subprocess.TimeoutExpired:
                line = '%s\tTIMEOUT\t-\t%.1fs 重试超时' % (g, time.time() - t0)
            print('[retry %d/%d] %s' % (i, len(retry), line[:96]), flush=True)
            results.append(line)
    ok = tight = bad = fail = 0
    overs = []
    for ln in results:
        p = ln.split('\t')
        if len(p) < 3 or p[2] == '-':
            fail += 1
            continue
        v = int(p[2])
        if v <= 1516:
            ok += 1
        elif v <= 1584:
            tight += 1
        else:
            bad += 1
            overs.append((p[0], v))
    print('\n本轮 %d 款：OK %d / TIGHT %d / 溢出 %d / 测不到 %d' % (len(results), ok, tight, bad, fail))
    if overs:
        print('溢出：')
        for n, v in overs:
            print('  %5d  %s' % (v, n))
    return 0


if __name__ == '__main__':
    sys.exit(main())
