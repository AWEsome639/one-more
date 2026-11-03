#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
横屏溢出静态审计（判据 479：能算的先算，别一上来就逐款截图）

★ 背景
  第 1130 轮发现：`GBejeweled` 在 853×533 上「棋盘 + 固定项」超出视口，
  导致底部按钮要滚动才能看到。而 355 款里只有 21 款套了 `Scroll()` 兜底。

★ 本工具做什么（纯静态，不连设备）
  对每款游戏估算两个量：
    ① **棋盘/内容的最大高度**（从代码里的尺寸表达式算）
    ② **固定项高度**（HintBar + 信息卡 + 按钮行 + 文字）
  然后算「内容高 / 视口高」，超 100% 且**无滚动兜底**的才报警。

★ 为什么用静态估算而不是逐款 dumpLayout
  355 款 × 每款 10 s ≈ 1 小时；而静态扫描 2 秒跑完。
  静态会漏（无法精确算 flex 布局），但能**先筛出可疑清单**，
  再把真机时间花在可疑的那几款上 —— 这才是"能算的先算"。

★ 适用范围（判据 480：检查器必须自带范围声明）
  · **只做粗略筛查**，不代替真机
  · 只认几种常见尺寸表达式：`Bp.height * k`、`(Bp.height - N) * k`、`Cell.of(N)`
  · 认不出表达式时计为「未知」，不计入报警（宁可漏报，不制造假警报）

退出码：0 = 无可疑 ｜ 1 = 有可疑 ｜ 2 = 脚本问题
"""
import io
import os
import re
import sys

# ★★★ 2026-11-03（第 1156 轮）**基数修正 —— 判据 450 的又一次教训**
#   我第一版用 `AREA_H = 361`（= 533 − 顶栏 88 − tab 60 − padding 的**推算**）
#   ⇒ 而第 1131 轮真机 dump 实测：**内容底 485 vp < 屏幕 533 vp**
#      ⇒ Scroll 实际占满整屏 ⇒ **视口 = 533，不是 361**
#   ⇒ 用 361 会让「内容 485」看起来超 124 vp，全是假警报
AREA_H = 533
# 固定项合计（HintBar 26 + 信息卡 30/50 + 按钮行 46 + 提示 16 + 规则 14 + 间距）
# ★★★ 固定项也用实测值（第 1131 轮 dump）：
#   内容总高 485 vp ｜ 其中棋盘 233 vp
#   ⇒ **固定项 = 485 − 233 = 252 vp**（含顶栏、HintBar、信息卡、提示、按钮、规则、间距）
#   ⚠️ 第一版我估成 334（248 + 86），把「棋盘顶」当成了固定项 ⇒ **重复计算**
FIXED = 252


def strip_comments(src):
    """去掉 // 行注释与 /* */ 块注释（★ 判据 431：注释里常有已失效的旧公式）"""
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    out = []
    for ln in src.split('\n'):
        q = 0
        cut = len(ln)
        for i, ch in enumerate(ln):
            if ch in ('"', "'"):
                q ^= 1
            elif ch == '/' and i + 1 < len(ln) and ln[i + 1] == '/' and q == 0:
                cut = i
                break
        out.append(ln[:cut])
    return '\n'.join(out)


def has_fallback(raw_src):
    src = strip_comments(raw_src)
    return ('Scroll()' in src) or ('List()' in src) or ('Grid()' in src)


def board_height(raw_src):
    """从源码里找棋盘/内容的最大高度表达式（vp）。返回 (值, 依据) 或 (None, '未知')"""
    src = strip_comments(raw_src)   # ★ 关键：先剥注释
    cands = []
    # ① (Bp.height - FIXED) * k
    for m in re.finditer(r'\(Bp\.height\s*-\s*(\w+|\d+)\)\s*\*\s*(0?\.\d+)', src):
        fx, k = m.group(1), float(m.group(2))
        fxv = 0
        if fx.isdigit():
            fxv = int(fx)
        else:
            mm = re.search(r'const\s+%s\s*:\s*number\s*=\s*(\d+)' % fx, src)
            if mm:
                fxv = int(mm.group(1))
            else:
                continue
        cands.append((max(120.0, (533 - fxv) * k), '(Bp.height-%d)*%.2f' % (fxv, k)))
    # ② Bp.height * k
    for m in re.finditer(r'Bp\.height\s*\*\s*(0?\.\d+)', src):
        k = float(m.group(1))
        cands.append((533.0 * k, 'Bp.height*%.2f' % k))
    # ③ `Cell.of(N)` **不算内容高** —— 它只是某个按钮/格子的尺寸
    #    第 1156 轮实测：把它算进来会让 313 款（88%）假阳性
    #    ⇒ 只统计"整块棋盘"的尺寸表达式（Bp.height 系列）
    if not cands:
        return None, '未知'
    cands.sort(key=lambda t: -t[0])
    return cands[0]


def main():
    d = 'entry/src/main/ets/games'
    if not os.path.isdir(d):
        print('🔴 找不到 %s' % d)
        return 2
    files = sorted(f for f in os.listdir(d) if f.endswith('.ets'))
    rows = []
    unknown = 0
    for f in files:
        p = os.path.join(d, f)
        src = io.open(p, encoding='utf-8', errors='ignore').read()
        h, why = board_height(src)
        if h is None:
            unknown += 1
            continue
        rows.append({
            'file': f[:-4], 'h': h, 'why': why,
            'fb': has_fallback(src),
            'total': h + FIXED,
        })

    print('=' * 78)
    print('  横屏 853×533 溢出静态审计（视口 %d vp ｜ 固定项 %d~%d vp）' % (AREA_H, FIXED, FIXED))
    print('=' * 78)
    print('  扫了 %d 款 ｜ 能算出尺寸的 **%d** 款 ｜ 认不出表达式 %d 款（计为未知，不报警）'
          % (len(files), len(rows), unknown))
    print()

    risky = [r for r in rows if r['total'] > AREA_H and not r['fb']]
    risky.sort(key=lambda r: -r['total'])
    safe_fb = [r for r in rows if r['total'] > AREA_H and r['fb']]

    print('  ══ 🔴 可疑（内容高 > 视口 且 **无滚动兜底**）：%d 款 ══' % len(risky))
    if risky:
        print('  %-34s %9s %9s %9s  %s' % ('文件', '内容高', '固定项', '合计', '依据'))
        for r in risky:
            print('  %-34s %8.0f %9d %9.0f  %s' % (
                r['file'][:34], r['h'], FIXED, r['total'], r['why']))
    else:
        print('    （无）')
    print()
    print('  ══ ✅ 内容高 > 视口但**有滚动兜底**：%d 款 ══' % len(safe_fb))
    for r in safe_fb[:12]:
        print('    %-34s %.0f vp  %s' % (r['file'][:34], r['total'], r['why']))
    if len(safe_fb) > 12:
        print('    …（共 %d 款）' % len(safe_fb))
    print()
    print('=' * 78)
    print('  ⚠️ 基数为**实测值**：视口 533 vp（Scroll 占满屏）｜固定项 252 vp')
    print('     来源：第 1131 轮 `uitest dumpLayout` 实测「内容底 485 vp、棋盘 233 vp」')
    print('     ❗ 第一版用「视口 361 / 固定项 334」全是推算 ⇒ 报了 313 款假阳性')
    print('  ⚠️ 范围为「粗略筛查」：只认 Bp.height*k / (Bp.height-N)*k')
    print('  ⚠️ 认不出的一律计为"未知"、不报警（宁可漏报，不制造假警报）')
    print('  ⚠️ 报警款必须**逐款真机 dumpLayout** 确认，本工具不能代替真机')
    print('  ⚠️ `Cell.of(N)` 只表示单个元素尺寸，**不参与**内容高估算')
    print('     （第 1156 轮实测：把它算进来会让 313/355 = 88% 假阳性）')
    print('=' * 78)
    return 1 if risky else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
