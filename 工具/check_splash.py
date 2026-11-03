#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_splash.py —— 开屏动画九条要求的静态审计器

为什么需要它（2026-11-03 第 1034 轮）：
  开屏是项目第一优先级，要求「世界顶尖」，而它的九条要求里
  有五条是**代码可查的**（分镜表 / 渐变与发光 / 逐字 / 景深 / 曲线），
  只有「真机连拍」必须上设备。
  ⇒ 把可查的五条自动化，每次改开屏先跑一遍，省掉一轮编译 + 装机。

用法：
  python3 工具/check_splash.py           # 只报告
  python3 工具/check_splash.py            # 默认严格：有不合格项退出码 1
  python3 工具/check_splash.py --lenient  # 只看报告、不判失败（CI 里别用）

⚠️ 它只做静态核对，**不能代替真机连拍**（第 ⑧ 条永远是"需设备"）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPLASH = os.path.join(ROOT, "entry/src/main/ets/pages/Splash.ets")

# 九条要求（目标文字原文的编号）
REQS = [
    ("①", "分镜表"),
    ("②", "素材质感（渐变 + 高光 + 外发光）"),
    ("③", "逐字动效"),
    ("④", "景深（三组视差 + 远景虚 / 近景实）"),
    ("⑤", "暗角 + 颗粒"),
    ("⑥", "自适应 440/853/800/960/233/195"),
    ("⑦", "降级（极小屏减星尘 / 缩字号 / 收紧间距）"),
    ("⑧", "真机连拍 ≥8 帧"),
    ("⑨", "不用 Curve.Linear 做主线"),
]


def read():
    return io.open(SPLASH, encoding="utf-8").read()


def count(s, pat):
    return len(re.findall(pat, s))


def check():
    s = read()
    lines = s.split("\n")
    res = {}

    # ① 分镜表：注释里形如 " *   L4a   280    980   1260   ..."
    n_layers = count(s, r"^ \*   L\w+\s+\d+", )
    n_layers2 = len(re.findall(r"^ \*   L\w+", s, re.M))
    res["①"] = (n_layers2 >= 8, "%d 条 L 层" % n_layers2)

    # ② 渐变 + 发光：linearGradient / radialGradient 都要有
    lin = count(s, r"linearGradient")
    rad = count(s, r"radialGradient")
    glow = count(s, r"外发光|主光晕")
    ok2 = lin >= 2 and rad >= 2 and glow >= 1
    res["②"] = (ok2, "linearGradient %d ｜ radialGradient %d ｜ 发光注释 %d" % (lin, rad, glow))

    # ③ 逐字：要有 per-char 函数 + 专用曲线（不能用 settle）
    has_charin = re.search(r"private\s+charIn\(", s) is not None
    has_tclock = re.search(r"private\s+titleClock\(", s) is not None
    # titleClock 的 y1 必须是 0（起点慢），否则 8 个字会同时出现
    slow = False
    m = re.search(r"private\s+titleClock\(\)[^{]*\{\s*return\s+curves\.cubicBezierCurve\(([^)]*)\)", s)
    if m:
        parts = [p.strip() for p in m.group(1).split(",")]
        if len(parts) == 4:
            try:
                slow = float(parts[1]) <= 0.2      # y1 小 = 起点慢
            except ValueError:
                slow = False
    res["③"] = (has_charin and has_tclock and slow,
                "charIn %s ｜ titleClock %s ｜ 起点慢 %s" % (
                    "有" if has_charin else "**缺**",
                    "有" if has_tclock else "**缺**",
                    "是" if slow else "**否（逐字会失效）**"))

    # ④ 景深：三组速度 + 模糊分档
    groups = count(s, r"STAR_(FAR|MID|NEAR)|组 0|组 1|组 2")
    blur_fn = re.search(r"private\s+starBlur\(", s) is not None
    res["④"] = (blur_fn and groups >= 2,
                "分组标记 %d ｜ starBlur %s" % (groups, "有" if blur_fn else "**缺**"))

    # ⑤ 暗角 + 颗粒
    vig = count(s, r"暗角|vignette") > 0
    grain = count(s, r"颗粒|grain") > 0
    res["⑤"] = (vig and grain, "暗角 %s ｜ 颗粒 %s" % ("有" if vig else "**缺**", "有" if grain else "**缺**"))

    # ⑥ 自适应：要有 tiny / ultraTiny 分档
    adapt = count(s, r"this\.tiny|ultraTiny")
    res["⑥"] = (adapt >= 4, "tiny/ultraTiny 引用 %d 处" % adapt)

    # ⑦ 降级：星尘数量随尺寸变化
    degrade = re.search(r"starCount\(\)", s) is not None and re.search(r"STARS_TINY", s) is not None
    res["⑦"] = (degrade, "starCount + STARS_TINY %s" % ("都有" if degrade else "**缺**"))

    # ⑧ 真机连拍：静态永远"需设备"
    res["⑧"] = (None, "**需设备**（静态不可判）")

    # ⑨ Curve.Linear：主线禁止
    n_lin = count(s, r"Curve\.Linear")
    n_bez = count(s, r"cubicBezier")
    res["⑨"] = (n_lin == 0 and n_bez >= 3,
                "Curve.Linear **%d** 处 ｜ cubicBezier %d 处" % (n_lin, n_bez))

    return res


SIZES = [
    ("手机竖",   440, 744),
    ("平板横",   853, 533),
    ("平板竖",   800, 1280),
    ("手表",     233, 233),
    ("运动手表", 195, 195),
    ("智慧屏",   960, 540),
]


def estimate(w, h):
    """按 Splash.ets 的 onAreaChange 公式复算三项关键尺寸。

    ⚠️⚠️ 重要边界（2026-11-03 第 1037 轮实测）：
      本函数是**独立复算**的，不读 Splash.ets 的源码。
      ⇒ 它能验证「我的公式推导对不对」（六个尺寸的占比合不合理），
     但它**不能自动发现「源码被改坏了」** ——
        把源码里的软下限改回硬下限 96，本工具照样输出"全部通过"。
      ⇒ 所以它必须和 `git diff` 一起用：
         改了公式 ⇒ **先改本函数**，再看六尺寸是否仍通过。
    ⚠️ 公式改了这里必须同步改 —— 否则审计会与真机不符。"""
    cap = 150 if h < 620 else 200
    om_floor = max(50, min(96, w * 0.30))
    om = max(om_floor, min(cap, w * 0.245))
    om_v = om * 2.05
    ti_floor = max(24, min(38, w * 0.16))
    ti = max(ti_floor, min(104, w * 0.098))

    # ★★★ 2026-11-03（第 1066 轮）修正 tiny 分支盲区
    #   `Splash.ets:868` 的实际代码是：
    #     `.fontSize(this.tiny ? 21 : this.titlePx)`   ← **tiny 时硬编码 21**
    #   ⇒ 233×233 的 tiny=true ⇒ 实际字号 **21 vp**，不是 ti=37.3
    #   ⇒ 修正前报「标题占宽 79.4%」，真机实测只有 **45.8%**（高估 34 个百分点）
    #   ⇒ 修正后用 21 算：8 × 0.62 × 21 = 104.2 vp ÷ 233 = **44.7%** ≈ 实测 45.8% ✅
    #   `tiny` 的定义（Splash.ets onAreaChange）：`isTiny = h > 0 && h < 360`
    is_tiny = (h > 0 and h < 360)
    font_px = 21 if is_tiny else ti
    # `letterSpacing` 也随分支变：tiny 用 1.5，否则 6
    letter = 1.5 if is_tiny else 6

    o_d = om_v * 0.6074
    # 「One More」= 8 个字符槽（含空格）；字宽 0.62em + letterSpacing
    title_w = 8 * (0.62 * font_px + letter)
    vert = o_d + font_px * 1.2 + 20 + 20 + 20   # logo + 标题 + 副标题 + 标签 + 间距
    return {
        "om": om, "omV": om_v, "ti": ti,
        "font": font_px, "tiny": is_tiny,
        "logo_ratio": om_v / w * 100,
        "title_ratio": title_w / w * 100,
        "vert": vert, "h": h, "w": w,
    }


def check_sizes():
    """六尺寸自适应验算：返回 (全部通过, 详情行)"""
    rows = []
    ok_all = True
    for name, w, h in SIZES:
        r = estimate(w, h)
        bad = []
        if r["logo_ratio"] > 100:
            bad.append("logo 超宽 %.1f%%" % r["logo_ratio"])
        if r["title_ratio"] > 100:
            bad.append("标题超宽 %.1f%%" % r["title_ratio"])
        if r["title_ratio"] > 85:
            bad.append("标题极挤 %.1f%%" % r["title_ratio"])
        if r["vert"] > h:
            bad.append("竖向超高 %.0f>%d" % (r["vert"], h))
        if bad:
            ok_all = False
        rows.append((name, w, h, r, bad))
    return ok_all, rows


SHOT_DIR = os.path.join(ROOT, "验收截图-v1.0.1")
TARGET_SIZES = [(440, 744), (853, 533), (800, 1280), (960, 540), (233, 233), (195, 195)]



def _size_of(path):
    """返回 (w//3, h//3)；读不到返回 None。"""
    try:
        from PIL import Image
        im = Image.open(path)
        return (im.width // 3, im.height // 3)
    except Exception:
        return None

def check_evidence_freshness(base_override: float = None):
    """判据 330：引用的截图必须晚于源码改动，否则只能证明旧版。

    返回 [(尺寸, 最新文件, 时间戳, 是否新于源码, 该尺寸总张数)]
    """
    import glob
    try:
        from PIL import Image
    except ImportError:
        return None, "缺少 Pillow，跳过"
    if not os.path.isdir(SHOT_DIR):
        return None, "缺少截图目录"
    # ★ 用 **git 提交时间** 而不是文件 mtime（判据 331）
    #   原因：mtime 会把"临时改动又改回"也算成改动
    #         （实测 19:36 只是 TOTAL 改 3300 又改回 1660，内容与截图时一致）
    # ★★★ 2026-11-03（第 1100 轮）：基线优先用**被验证产物（HAP）的构建时间**
    #   原来的 git 提交时间当基线会产生**系统性假阴性** ——
    #   正常流程是「改代码 → 编译 → 装机 → 拍截图 → 提交」，
    #   截图必然早于提交 ⇒ 每一轮都被判"旧版"。
    #   HAP 的 mtime 才是"这张截图拍的是哪一版代码"的直接依据。
    if base_override is not None and base_override > 0:
        src_mtime = float(base_override)
    else:
        src_mtime = os.path.getmtime(SPLASH)   # 兜底
        try:
            import subprocess
            out = subprocess.check_output(
                ["git", "-C", ROOT, "log", "-1", "--format=%ct", "--",
                 "entry/src/main/ets/pages/Splash.ets"],
                stderr=subprocess.DEVNULL, timeout=10)
            ct = int(out.decode().strip())
            if ct > 0:
                src_mtime = float(ct)
        except Exception:
            pass
    rows = []
    for tw, th in TARGET_SIZES:
        files = []
        for f in glob.glob(os.path.join(SHOT_DIR, "*")):
            n = os.path.basename(f).lower()
            if "splash" not in n:
                continue
            try:
                im = Image.open(f)
            except Exception:
                continue
            if im.width // 3 == tw and im.height // 3 == th:
                files.append((f, os.path.getmtime(f)))
        if files:
            files.sort(key=lambda x: -x[1])
            f, mt = files[0]
            rows.append((tw, th, os.path.basename(f), mt, mt >= src_mtime, len(files)))
        else:
            rows.append((tw, th, None, 0, False, 0))
    return rows, src_mtime


def main():
    # ★★★ 2026-11-03（第 1121 轮）**默认改为严格**
    #   原来是「默认宽松、加 --strict 才失败」：
    #     `python3 工具/check_splash.py` 即使打印 🔴 也返回 **0**
    #   ⇒ 而我在前面几轮的验收里，一直用不带 --strict 的调用
    #     去判断"是否全绿" ⇒ **那个 0 是假的**
    #   ⇒ 判据 423：**检查器的默认行为必须是"有问题就失败"**；
    #     要宽松请显式 `--lenient`（默认拿到 0 才是真绿）。
    strict = "--lenient" not in sys.argv
    if not os.path.exists(SPLASH):
        print("  ❌ 找不到 %s" % SPLASH)
        return 2
    res = check()
    print("=" * 68)
    print("  开屏动画 · 九条要求静态审计")
    print("=" * 68)
    print("  文件: %s（%d 行）" % (
        os.path.relpath(SPLASH, ROOT), len(read().split("\n"))))
    print()
    fail = 0
    unknown = 0
    for (num, name) in REQS:
        ok, detail = res[num]
        if ok is None:
            mark = "◻"
            unknown += 1
        elif ok:
            mark = "✅"
        else:
            mark = "❌"
            fail += 1
        print("  %s %s %-28s %s" % (mark, num, name, detail))
    print()
    print("  ⇒ 通过 %d ｜ 不合格 **%d** ｜ 需设备 %d" % (9 - fail - unknown, fail, unknown))
    print()
    if fail:
        print("  ⚠️ 有 %d 条不合格，改完再上设备。" % fail)
    else:
        print("  ✅ 静态可查的 8 条全部通过；第 ⑧ 条需真机连拍。")
    # ── ⑥ 的源码级守卫：软下限是否还在（防"源码被改回硬下限"）──
    print()
    print("  " + "-" * 64)
    print("  ⑥ 源码级守卫 · 软下限关键表达式")
    print("  " + "-" * 64)
    src = read()
    guards = [
        ("om 软下限",  r"Math\.max\(50,\s*Math\.min\(96,\s*w\s*\*\s*0\.30\)\)"),
        ("ti 软下限",  r"Math\.max\(24,\s*Math\.min\(38,\s*w\s*\*\s*0\.16\)\)"),
        ("su 软下限",  r"Math\.max\(7,\s*Math\.min\(11,\s*w\s*\*\s*0\.055\)\)"),
        ("tg 软下限",  r"Math\.max\(6,\s*Math\.min\(10,\s*w\s*\*\s*0\.048\)\)"),
    ]
    missing = 0
    for label, pat in guards:
        found = re.search(pat, src) is not None
        print("    %s %-12s %s" % ("✅" if found else "❌", label,
              "在位" if found else "**缺失（可能被改回硬下限）**"))
        if not found:
            missing += 1
    if missing:
        print()
        print("    ⚠️ 有 %d 个软下限不在源码里 ⇒ 六尺寸验算的结论**不适用于当前源码**" % missing)
        fail += 1
    else:
        print()
        print("    ✅ 四个软下限全部在位 ⇒ 六尺寸验算结论对当前源码成立")

    # ── ⑥ 的细分：六尺寸逐项验算 ──
    print()
    print("  " + "-" * 64)
    print("  ⑥ 自适应细分 · 六尺寸逐项验算")
    print("  " + "-" * 64)
    ok_all, rows = check_sizes()
    print("    %-10s %9s  %6s  %6s  %7s  %7s  %s" % (
        "屏幕", "vp", "om", "ti", "logo占宽", "标题占宽", "判定"))
    for name, w, h, r, bad in rows:
        print("    %-10s %4dx%-4d  %6.1f  %6.1f  %6.1f%%  %6.1f%%  %s" % (
            name, w, h, r["om"], r["ti"], r["logo_ratio"], r["title_ratio"],
            "✅" if not bad else "❌ " + "；".join(bad)))
    print()
    if ok_all:
        print("  ✅ 六尺寸自适应全部通过")
    else:
        print("  ❌ 六尺寸自适应有不合格项")
        fail += 1

    # ── 证据时间戳校验（判据 330）──
    # ★★★ 2026-11-03（第 1100 轮）**修一个假阴性**
    #   原来基线用「最后一次提交 Splash.ets 的时间」。
    #   而正常流程是：改代码 → 编译 → 装机 → **拍截图** → 提交
    #   ⇒ 截图**必然**早于提交 ⇒ 每一轮都会被判"旧版"，全是假阴性。
    #   ⇒ 基线改为「**被验证产物**（HAP）的 mtime」——
    #     那才是"这张截图拍的是哪一版代码"的直接依据。
    #   （HAP 不存在时退回 git 提交时间，并提示）
    import os as _os
    _hap = _os.path.join(ROOT, 'entry/build/default/outputs/default/entry-default-signed.hap')
    _base_override = _os.path.getmtime(_hap) if _os.path.exists(_hap) else None
    # ★★★ 2026-11-03（第 1101 轮）**彻底改成「绑构建哈希」**（判据 383 / 384）
    #
    #   演进（三次，前两次都用 mtime，都错）：
    #     ① 基线 = Splash.ets 的 git 提交时间
    #        ⇒ **系统性假阴**：流程是「改代码→编译→装机→拍→提交」，
    #          截图必然早于提交 ⇒ 每一轮都被判"旧版"
    #     ② 基线 = HAP 构建时间
    #        ⇒ **假阳**：`cp` 一个旧图就刷新它的 mtime，
    #          旧证据看起来比新构建还新
    #     ③ **本版：不用任何时间戳**，只比内容哈希
    #        ⇒ 截图绑定的 HAP sha256 == 当前 HAP 的 sha256
    #        ⇒ 构建改了哈希一定变（密码学保证）｜截图被 cp/mv/touch 不影响绑定
    #
    #   ★ 判据 384：判据只有**在检查器里被执行**才算立住。
    #     判据 330 早就写过"不能用 mtime"，但它只活在台账里，
    #     所以同一类错误又发生了一次 —— 这一版把它钉在代码里。
    import hashlib
    import json
    hap_path = os.path.join(ROOT, 'entry/build/default/outputs/default/entry-default-signed.hap')
    manifest = os.path.join(SHOT_DIR, 'splash_evidence.jsonl')

    def _hap_sha(path):
        if not os.path.exists(path):
            return None
        h = hashlib.sha256()
        with io.open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(1 << 20), b''):
                h.update(chunk)
        return h.hexdigest()

    # ★ 第 1104 轮修正：判定用 **Splash.ets 的源码哈希**，不用整个 HAP 的哈希
    #   原因：改一个与开屏无关的文件（如 Index.ets 的路由转场），HAP 哈希就变，
    #         会让**所有开屏证据瞬间失效** —— 太粗。
    #   开屏的证据只该绑**开屏自己的源码**。
    cur_sha = _hap_sha(os.path.join(ROOT, 'entry/src/main/ets/pages/Splash.ets'))
    stamped = {}
    if os.path.exists(manifest):
        for line in io.open(manifest, encoding='utf-8'):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            stamped[os.path.basename(e.get('file', ''))] = e

    print()
    print("  " + "-" * 64)
    print("  证据新鲜度 · 截图**与 Splash.ets 源码哈希的绑定**（判据 383/390）")
    print("  " + "-" * 64)
    if cur_sha is None:
        print("    ⚠️ 找不到 HAP，无法比对：%s" % hap_path)
        print("       ⇒ 先跑 bash build.sh assembleHap")
    else:
        print("    当前 **Splash.ets** sha256 = **%s…**" % cur_sha[:16])
        print("    （**不看任何时间戳** —— 时间戳回答不了「这份证据证明的是哪一版」）")
        print()
        print("    %-10s %-6s %-40s %s" % ("尺寸", "已绑定", "绑在当前源码上的文件", "版本"))
        missing = 0
        for tw, th in TARGET_SIZES:
            hits = []
            for fname, e in stamped.items():
                if e.get('splash_sha256') != cur_sha:
                    continue
                f = os.path.join(SHOT_DIR, fname)
                if not os.path.exists(f):
                    continue
                try:
                    from PIL import Image
                    im = Image.open(f)
                except Exception:
                    continue
                if im.width // 3 == tw and im.height // 3 == th:
                    hits.append(fname)
            tot = sum(1 for e in stamped.values()
                      if os.path.exists(os.path.join(SHOT_DIR, os.path.basename(e.get('file', '')))))
            if hits:
                print("    %-10s %-6d %-40s ✅ 当前源码"
                      % ("%dx%d" % (tw, th), len(hits), hits[0][:40]))
            else:
                missing += 1
                print("    %-10s %-6d %-40s ⚠️ 无当前源码证据"
                      % ("%dx%d" % (tw, th), tot, "—"))
        print()
        # ★ 判据 382：验收工作量按**分支**算，不按设备数算
        #   逐尺寸表是"原始数据"，分支表才是"是否达成"的判定
        def _branch(h):
            if h > 0 and h < 260:
                return "ultraTiny"
            if h > 0 and h < 360:
                return "tiny"
            return "normal"

        print()
        print("    ══ 按分支汇总（判据 382：达成与否看分支，不看设备数）══")
        br_hits = {}
        for tw, th in TARGET_SIZES:
            b = _branch(th)
            ok_here = any(
                e.get('splash_sha256') == cur_sha
                and os.path.exists(os.path.join(SHOT_DIR, os.path.basename(e.get('file', ''))))
                and _size_of(os.path.join(SHOT_DIR, os.path.basename(e.get('file', '')))) == (tw, th)
                for e in stamped.values())
            br_hits.setdefault(b, [0, 0])
            br_hits[b][1] += 1
            if ok_here:
                br_hits[b][0] += 1
        br_missing = 0
        for b in ("normal", "tiny", "ultraTiny"):
            if b not in br_hits:
                continue
            got, tot = br_hits[b]
            if got > 0:
                print("      %-10s %d/%d 尺寸有当前源码证据  ✅ 该分支已覆盖"
                      % (b, got, tot))
            else:
                br_missing += 1
                print("      %-10s %d/%d 尺寸有当前源码证据  🔴 该分支**无证据**"
                      % (b, got, tot))
        print()
        if br_missing:
            print("    🔴 **%d 个分支完全没有当前源码的证据**" % br_missing)
            fail += 1
        else:
            print("    ✅ **所有分支都有当前源码证据**（源码哈希相等，不靠时间戳）")
        # ★ 这条提示只在"分支都覆盖了、只是某些尺寸没拍"时才成立
        if missing and br_missing == 0:
            print("    ℹ️ 逐尺寸看有 %d 个尺寸无证据，但它们所属分支已被覆盖"
                  % missing)
            print("       ⇒ 按判据 382 不重复拍摄；需要时可补")
        elif missing:
            print("    🔴 逐尺寸有 %d 个尺寸无证据，且分支也未覆盖 ⇒ 必须补拍"
                  % missing)
        print("    清单：验收截图-v1.0.1/splash_evidence.jsonl（%d 条）" % len(stamped))

    if strict and fail:
        return 1
    return 0


if __name__ == "__main__":
    # ★★★ 2026-11-03（第 1124 轮）**崩溃与判定失败用不同退出码**（判据 428）
    #   原来 `sys.exit(main())`：main 里抛异常就变成非 0 的 traceback 退出（也是 1）
    #   ⇒ **"检测到不合格"和"脚本自己崩了"退出码一样**
    #   ⇒ 看到 1 时无法判断该去改代码还是该去查环境
    #   ⇒ 约定：**0 = 合格 ｜ 1 = 判定不合格 ｜ 2 = 脚本异常**
    try:
        _rc = main()
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
    sys.exit(_rc if isinstance(_rc, int) else 0)
