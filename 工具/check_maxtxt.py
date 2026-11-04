#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_maxtxt.py —— HUD 数字/短文本"没限行"检查器
================================================================
来历（第 845 轮，判据 199）：
  手表 233×233 上 `GAffixFactory` 的 HUD「0/10」被**折成两行**
  （实测 bounds 高 126px = 2 行；加了 `maxLines(1)` 后降到 72px）。
  我当时算过"文字区 133px、文字 88px ⇒ 放得下"——**算式错了**，
  字体度量比估算宽。
  ⇒ 判据 199：「maxLines(1) > 缩字号 > 追根因」。
  ⇒ 那么这件事该有系统检查，不能靠一款款目视。

做什么：
  扫 `entry/src/main/ets/games/*.ets`，找出**同时满足**下面三条的 `Text(...)`：
    ① `.fontSize(FontSize.lg)` 或更大（x l / xxl / xxxl / hero / 18+）
    ② **没有** `.maxLines(...)`
    ③ 内容是"短文本"：表达式里出现 `/`、`+`、`Digits(`、`String(` 之一
       （纯中文标签一般不会超，但数字拼接最容易变长）
  ⇒ 报出来，并给出行号。

用法：
  python3 工具/check_maxtxt.py            # 全量
  python3 工具/check_maxtxt.py --limit 40 # 只看前 40 条
  python3 工具/check_maxtxt.py --file entry/src/main/ets/games/GAffixFactory.ets

退出码：
  0 = 没有可疑项
  1 = 有可疑项（需人工确认是否真会折行）
  2 = 环境不可用（目录不存在）
"""
import glob
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')

# 大字号：这些值及以上认为"一旦变长就容易撑破"
BIG_SIZES = {
    'FontSize.hero', 'FontSize.xxxl', 'FontSize.xxl', 'FontSize.xl', 'FontSize.lg',
    '36', '28', '24', '20', '18',
}

# ★ 第 2 版收紧（第 906 轮）：第一版太宽，扫出 892 处，
#   因为 `Text(this.sym)`（单个 emoji）也被算进"动态短文本"——它根本不会折行。
#   ⇒ 现在只认**多段拼接**：必须同时出现「拼接运算符」与「数字/字符串构造」。
CONCAT_OPS = ("'/'", '" / "', ' + ', "' ' +", " + '/'")
NUM_CTORS = ('Digits(', 'String(', 'TG2(')


def is_concat_text(block):
    """判断这个 Text 的内容是不是"多段拼接"（最容易变长的一类）"""
    body = '\n'.join(l for l in block.split('\n') if not l.strip().startswith('//'))
    has_op = any(op in body for op in CONCAT_OPS)
    has_num = any(c in body for c in NUM_CTORS)
    return has_op and has_num


def load_text_blocks(src):
    """把 src 里所有 `Text( ... )` 的调用块抽出来（含其后连续的方法链）。

    返回 [(line_no, block_text)]。
    做法：找 `Text(`，然后括号配平找到闭合的 `)`，
    再把闭合之后到下一个 `.` 链结束（遇到 `}` 或 `,` 或换行后的非 `.` 开头）的方法链一并带上。
    这是启发式，宁可多带一点。
    """
    out = []
    for m in re.finditer(r'\bText\(', src):
        start = m.start()
        line_no = src[:start].count('\n') + 1
        # 括号配平
        depth = 0
        i = m.end() - 1
        n = len(src)
        while i < n:
            c = src[i]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            i += 1
        # 接方法链：允许跨行，直到遇到 `}`（块结束）或空行
        tail_start = i
        j = i
        while j < n:
            # 跳过空白
            while j < n and src[j] in ' \t':
                j += 1
            if j < n and src[j] == '\n':
                # 换行后看下一行是不是 `.` 开头
                k = j + 1
                while k < n and src[k] in ' \t':
                    k += 1
                if k < n and src[k] == '.':
                    j = k
                    continue
                break
            if j < n and src[j] == '.':
                # 吃掉这一整条链到行尾
                while j < n and src[j] != '\n':
                    j += 1
                continue
            break
        out.append((line_no, src[start:j]))
    return out


def check_file(path):
    with io.open(path, encoding='utf-8') as f:
        src = f.read()
    hits = []
    for line_no, block in load_text_blocks(src):
        # ① 大字号？
        big = any(s in block for s in BIG_SIZES)
        if not big:
            continue
        # ② 没有 maxLines？
        if '.maxLines(' in block:
            continue
        # ③ 多段拼接？
        if not is_concat_text(block):
            continue
        snippet = ' '.join(block.split())[:90]
        hits.append((line_no, snippet))
    return hits


def check_version():
    """★ 2026-11-03（第 876 轮，判据 229）：**验证前先确认"装的是哪一版"**。

    为什么需要它：
      第 875 轮我改完底部安全区，`aa start` 启动后量到 "零余量"，
      差点得出"修复无效"的结论 —— 实际是**设备上跑的是旧包**（新包还没装）。
      ⇒ 装包后立刻量到「余 22 px」。

    判据：
      `hap 的 mtime` 必须 **早于** `设备上 app 进程的启动时间`，
      才说明跑的是新包。否则**验证无效**。

    实现（设备端可用的命令，2026-11-03 实测）：
      · `pidof <bundle>`               ⇒ 进程号
      · `stat -c %Y /proc/<pid>`       ⇒ 该进程启动的 Unix 时间戳
      ⚠️ 不能用 `cat /proc/uptime`（设备 shell 里返回 `/bin/sh:` 报错）

    返回 (ok, 说明)。
    """
    import os
    import subprocess
    HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
    TARGET = '127.0.0.1:5555'
    HAP = os.path.join(ROOT, 'entry/build/default/outputs/default/entry-default-signed.hap')

    if not os.path.exists(HAP):
        return False, '找不到 hap（先 build）'
    hap_mt = os.path.getmtime(HAP)

    r = subprocess.run([HC, '-t', TARGET, 'shell', 'pidof com.andrewoscar.onemore'],
                       capture_output=True, timeout=30)
    pid = r.stdout.decode('utf-8', 'replace').replace('\r', '').strip()
    if not pid:
        return False, 'app 没在跑'
    pid = pid.split()[0]

    r2 = subprocess.run([HC, '-t', TARGET, 'shell', 'stat -c %%Y /proc/%s' % pid],
                        capture_output=True, timeout=30)
    raw = r2.stdout.decode('utf-8', 'replace').replace('\r', '').strip()
    try:
        proc_start = float(raw)
    except ValueError:
        return False, '读不到进程启动时间（原始输出：%s）' % raw[:40]

    print('    hap 编译于: %d' % int(hap_mt))
    print('    进程启动于: %d' % int(proc_start))
    if proc_start < hap_mt:
        return False, ('**旧包**：进程启动比 hap 编译早 %d 秒 ⇒ 先装包再验'
                       % int(hap_mt - proc_start))
    return True, '跑的是新包（进程比 hap 新 %d 秒）' % int(proc_start - hap_mt)


def check_runtime():
    """★ 运行时折行检测（第 906 轮新增）：
    读 `uitest dumpLayout`，找**高度异常**的短文本。

    判据（不依赖字体度量）：
      · 文本长度 <= 8 个字符（短文本本该一行）
      · 且 `height > 1.6 × 行高估计`
      · 行高估计 = max(24, 0.075 × 屏幕宽) px（233vp → 屏宽 699 → 52px；
                         440vp → 1320 → 99px；经验值，覆盖 16~20vp 字号）
      ⇒ 命中就是折行。
    """
    import json
    import subprocess
    HC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
    TARGET = '127.0.0.1:5555'
    TMP = '/data/local/tmp/maxtxt.json'
    LOCAL = '/tmp/maxtxt.json'
    try:
        r = subprocess.run([HC, '-t', TARGET, 'shell', 'uitest dumpLayout -p ' + TMP],
                           capture_output=True, timeout=45)
        if r.returncode != 0:
            print('  ❌ 环境不可用：dumpLayout 失败')
            return 2
        r2 = subprocess.run([HC, '-t', TARGET, 'shell', 'cat ' + TMP],
                            capture_output=True, timeout=45)
        txt = r2.stdout.decode('utf-8', 'replace')
        if not txt.strip().startswith('{'):
            print('  ❌ 环境不可用：读不到 dump')
            return 2
        with io.open(LOCAL, 'w', encoding='utf-8') as f:
            f.write(txt.replace('\r', ''))
        d = json.load(io.open(LOCAL, encoding='utf-8'))
    except Exception as e:
        print('  ❌ 环境不可用：%s' % e)
        return 2

    # 屏幕宽
    rb = d.get('attributes', {}).get('bounds', '')
    m = re.findall(r'-?\d+', rb)
    if len(m) < 4:
        print('  ❌ 环境不可用：读不到屏幕尺寸')
        return 2
    SW = int(m[2])
    line_h = max(24.0, 0.075 * SW)

    rows = []

    # 注意：rows 里是 (text, w, h, bounds)

    def walk(n):
        if isinstance(n, dict):
            a = n.get('attributes', {}) or {}
            t = (a.get('text') or '').strip()
            b = a.get('bounds') or ''
            if t and b and len(t) <= 8:
                q = re.findall(r'-?\d+', b)
                if len(q) >= 4:
                    w = int(q[2]) - int(q[0])
                    h = int(q[3]) - int(q[1])
                    rows.append((t, w, h, b))
            for v in n.values():
                if isinstance(v, (dict, list)):
                    walk(v)
        elif isinstance(n, list):
            for v in n:
                walk(v)

    walk(d)
    print('  屏幕宽 %d px ｜ 行高估计 %.0f px ｜ 短文本 %d 个' % (SW, line_h, len(rows)))
    print()
    # ★ 第 3 版判据（第 906 轮）：用**中位数高度**当"单行基准"。
    #   前两版都错了：
    #     ① 「高 > 1.6×行高」⇒ 把圆形按钮（‹ ? ↻，90×90）报成折行
    #     ② 「高 > 宽」⇒ 把单字符（"0" 33×63、":" 13×45）报成折行
    #        因为**单字符天然是窄的**，宽小于高完全正常
    #   ⇒ 正解：同一屏里的短文本，绝大多数是单行；
    #     取**高度中位数**当单行基准，只报「高 > 1.6 × 中位数」的。
    #     这样单字符、按钮、正常数字都不会误报，
    #     只有真正折成两行的（高度约 2 倍）才会命中。
    # ★ 第 4 版判据（第 906 轮，最终）：三条同时满足才算折行。
    #   前三版都试过、都不行：
    #     ① 「高 > 1.6×行高估计」 ⇒ 圆形按钮（90×90）误报
    #     ② 「高 > 宽」            ⇒ 单字符（"0" 33×63）误报
    #     ③ 「高 > 1.6×中位数」     ⇒ 大字按钮（"普通" 145×132）误报
    #   ⇒ 正解是**三条同时**成立：
    #        a. 高 > 宽           （折行的形状特征）
    #        b. 宽 < 150 px       （排除大按钮/整行按钮）
    #        c. 文本长度 >= 3      （排除单字符 "0" ":"）
    #   实测：「0/10」88×126、长 4 ⇒ 命中 ✅
    #         「普通」145×132、长 2 ⇒ 被 b/c 排除
    #         「再来一局」603×138 ⇒ 被 b 排除
    bad = [(t, w, h, b) for t, w, h, b in rows
           if h > w and w < 150 and len(t) >= 3]
    print()
    if not bad:
        print('  ✅ 没有折行的短文本')
        return 0
    print('  ⚠️ 发现 %d 个疑似折行（高>宽 且 宽<150 且 长度>=3）：' % len(bad))
    for t, w, h, b in bad:
        print('     %-12s 宽 %3d × 高 %3d px  %s' % (t, w, h, b))
    return 1


def main():
    args = sys.argv[1:]
    limit = 40
    only = None
    i = 0
    while i < len(args):
        if args[i] == '--limit' and i + 1 < len(args):
            limit = int(args[i + 1]); i += 1
        elif args[i] == '--file' and i + 1 < len(args):
            only = args[i + 1]; i += 1
        i += 1

    if '--version' in args:
        print('  ══ 判据 229：验证前确认装的是哪一版 ══')
        ok, msg = check_version()
        print('  %s %s' % ('✅' if ok else '❌', msg))
        return 0 if ok else 1

    if '--device' in args:
        # ★ 判据 229：device 模式自动先做版本检查
        ok, msg = check_version()
        if not ok:
            print('  ❌ 版本检查未过：%s' % msg)
            print('     （先 `hdc install -r <hap>` 再验，否则量的是旧包）')
            return 2
        return check_runtime()

    if not os.path.isdir(GAMES):
        print('  ❌ 环境不可用：找不到 %s' % GAMES)
        print('     （请在项目根目录下运行）')
        return 2

    files = [only] if only else sorted(glob.glob(os.path.join(GAMES, '*.ets')))
    if only and not os.path.exists(only):
        print('  ❌ 环境不可用：文件不存在 %s' % only)
        return 2

    total = 0
    unread = []       # 读不了 ⇒ 未检查（判据 655）
    per_file = []
    for f in files:
        # ★★★ 2026-11-04（第 1247 轮，判据 655）**「没查」不能算「通过」**
        #   原来：读不了文件 ⇒ 打印「⚠️ 读不了」⇒ continue
        #   ⇒ 那个文件**没被检查**，而 total 可能仍为 0 ⇒ 报告说「✅ 没有可疑项」
        #   修：计入 `unread`，最后由它决定 rc=2
        try:
            h = check_file(f)
        except Exception as e:
            print('  🔴 **读不了，无法检查** %s: %s' % (os.path.basename(f), e))
            unread.append(os.path.basename(f))
            continue
        if h:
            per_file.append((os.path.basename(f), h))
            total += len(h)

    print('  扫描 %d 个文件' % len(files))
    print('  可疑项：**%d**（大字号 Text + 无 maxLines + 动态短文本）' % total)
    print()

    shown = 0
    for fn, hits in per_file:
        print('  ── %s（%d 处）' % (fn, len(hits)))
        for line_no, snip in hits:
            if shown >= limit:
                print('     …还有更多（用 --limit 放大）')
                break
            print('     L%-5d %s' % (line_no, snip))
            shown += 1
        if shown >= limit:
            break

    print()
    if unread:
        print('  🔴 **%d 个文件读不了，未做检查**：%s' % (len(unread), ' '.join(unread[:5])))
        print('  ⇒ 退出码 2（**未检查 ≠ 通过**，判据 655/546）')
        return 2
    if total == 0:
        print('  ✅ 没有可疑项')
        return 0
    print('  ⇒ 这些不一定都会折行 —— 需要看**实际可用宽度**。')
    print('     但按判据 199：**不确定就先加 `.maxLines(1)`**，')
    print('     它不会伤害已经放得下的情况，只会阻止折行。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
