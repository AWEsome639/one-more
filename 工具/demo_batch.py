# -*- coding: utf-8 -*-
"""把「三拍演示 + DemoBar + 不计分」批量铺到所有结构同构的游戏。

★ 只处理**能确认同构**的部分（351 款的 demoStep 三件套一模一样）：
  · 若某款的 demoStep 三件套与标准不符 ⇒ 跳过并记录，绝不硬改
★ 用法：python3 工具/demo_batch.py --dry    先看会改哪些
        python3 工具/demo_batch.py --only GXxx,GYyy
        python3 工具/demo_batch.py          全量
"""
import io, os, re, sys, glob

GAMES = 'entry/src/main/ets/games'

STD_STEP = """  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }"""

STD_STOP = """  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }"""

STD_START = """  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }"""



# ── 变体 B（170 款）：有 demoFinish、无 demoStop ──
STD_STEP_B = """  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }"""

STD_FIN_B = """  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }"""

STD_START_B = """  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }"""



# 变体 B 里的 demoStop（不 reset，只清状态）
STD_STOP_B = """  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }"""


NEW = """  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }"""

FIELDS = """
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;"""


def patch(path, dry=False):
    name = os.path.basename(path)[:-4]
    s = io.open(path, encoding='utf-8').read()
    if 'private demoBeat()' in s:
        return (name, 'skip-已改', None)
    # ① 三件套必须与某个标准变体一字不差
    variant = None
    trio_a = STD_STEP + '\n\n' + STD_STOP + '\n\n' + STD_START
    trio_b = STD_FIN_B + '\n\n' + STD_STOP_B + '\n\n' + STD_STEP_B + '\n\n' + STD_START_B
    if trio_a in s:
        variant = 'A'; s = s.replace(trio_a, NEW, 1)
    elif trio_b in s:
        variant = 'B'; s = s.replace(trio_b, NEW, 1)
    else:
        # 逐块判断是哪一块不符，方便排查
        for blk, tag in ((STD_STEP, 'StepA'), (STD_STEP_B, 'StepB'),
                         (STD_STOP, 'StopA'), (STD_FIN_B, 'FinB'), (STD_START_B, 'StartB')):
            if blk not in s:
                return (name, 'skip-%s不符' % tag, None)
        return (name, 'skip-三件套不连续', None)
    # ② 加状态字段
    anchor = '  @State private demoLeft: number = 0;'
    if anchor not in s:
        return (name, 'skip-无demoLeft', None)
    s = s.replace(anchor, anchor + FIELDS, 1)
    # ③ HintBar 前插 DemoBar
    m = re.search(r'(\n[ \t]*)HintBar\(\{', s)
    if not m:
        return (name, 'skip-无HintBar', None)
    ind = m.group(1)
    s = s[:m.start()] + ind + '// ★ 演示条（共用组件；未演示时高度为 0，不占位）' + ind + 'DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })' + s[m.start():]
    # ④ demoOn 恒 false
    s = re.sub(r'demoOn: this\.demoId >= 0,?', 'demoOn: false,', s)
    # ⑤ imports
    if "from '../core/Demo'" not in s:
        mm = re.search(r"import \{[^}]*\} from '\.\./core/[A-Za-z]+';", s)
        if mm: s = s[:mm.end()] + "\nimport { Demo } from '../core/Demo';" + s[mm.end():]
        else: return (name, 'skip-无core import', None)
    if "from '../components/DemoBar'" not in s:
        mm = re.search(r"import \{[^}]*\} from '\.\./components/[A-Za-z]+';", s)
        if mm: s = s[:mm.end()] + "\nimport { DemoBar } from '../components/DemoBar';" + s[mm.end():]
        else:
            mm2 = re.search(r"^import .*;$", s, re.M)
            s = s[:mm2.end()] + "\nimport { DemoBar } from '../components/DemoBar';" + s[mm2.end():]
    # ⑥ 补 TG2 import（部分游戏只 import 了 TG）
    if 'TG2(' in s and 'TG2' not in re.search(r"^import .*GameI18n.*$", s, re.M).group(0):
        s = re.sub(r"(import \{[^}]*?)\bTG\b,", r"\1TG, TG2,", s, count=1)
        if 'TG2' not in re.search(r"^import .*GameI18n.*$", s, re.M).group(0):
            s = re.sub(r"import \{ TG \} from '(.*GameI18n)';",
                       r"import { TG, TG2 } from '\1';", s, count=1)
    if not dry:
        io.open(path, 'w', encoding='utf-8').write(s)
    return (name, 'ok', None)


if __name__ == '__main__':
    dry = '--dry' in sys.argv
    only = None
    for a in sys.argv:
        if a.startswith('--only'):
            only = [x.strip() for x in a.split('=', 1)[1].split(',')]
    files = sorted(glob.glob(GAMES + '/*.ets'))
    ok, skips = [], []
    for f in files:
        name = os.path.basename(f)[:-4]
        if only and name not in only:
            continue
        n, st, _ = patch(f, dry)
        (ok if st == 'ok' else skips).append((n, st))
    print('  可改 %d 款 ｜ 跳过 %d 款%s' % (len(ok), len(skips), '（dry-run，未写盘）' if dry else ''))
    if skips:
        from collections import Counter
        c = Counter(st for _, st in skips)
        for k, v in c.most_common():
            print('    %-28s %d 款' % (k, v))
        print('    跳过样本: %s' % [n for n, _ in skips[:8]])
