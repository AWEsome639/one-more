#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
开屏布局六尺寸验算（判据 379）

★ 为什么要有这个文件（2026-11-03 第 1098 轮）
  开屏的标语位置修过**四次**，前三次都只对了一半：
    ① height('100%') + justifyContent(End)  ⇒ 853 压副标题
    ② Alignment.Bottom                      ⇒ 440 断裂（隔 270vp）
    ③ vh >= 620 分支 + vh × 0.615            ⇒ 800×1280 会撞进内容
    ④ 放进文字 Column（最终解）              ⇒ 任何尺寸都对
  而 ③ 在 440 上实测**完全正常** —— 只验一个尺寸就收工会留下潜伏 bug。
  ⇒ 判据 379：**任何"按比例算出来的偏移/尺寸"，
     必须用表格式验算覆盖**所有目标尺寸**，不能只实测那一个。

  这个脚本就是那张表。

★ 检查内容
  ① 六尺寸的内容总高 / 屏高（> 92% 判为溢出风险）
  ② 标语与副标题在各尺寸上的可见性（ultraTiny 是否按设计隐藏）
  ③ 源码守卫：确认关键公式没有被改回旧写法

用法：python3 工具/check_splash_layout.py
退出码：0 = 全通过 ｜ 1 = 有不合格
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPLASH = os.path.join(ROOT, 'entry/src/main/ets/pages/Splash.ets')

SIZES = [
    (960, 540, '智慧屏 lg'),
    (853, 533, '平板横 lg'),
    (800, 1280, '平板竖 md'),
    (440, 744, '手机竖 sm'),
    (233, 233, '手表 sm'),
    (195, 195, '运动表 sm'),
]

MAX_RATIO = 92.0   # 内容高 / 屏高 上限（%）


def calc(w, h):
    """复刻 Splash.ets 的 onAreaChange 字号公式与 margin。"""
    cap = 150 if (h > 0 and h < 620) else 200
    is_tiny = h > 0 and h < 360
    is_ultra = h > 0 and h < 260

    om_floor = max(50, min(96, w * 0.30))
    om = max(om_floor, min(cap, w * 0.245))
    omPxV = (54 if is_tiny else om) * 2.05

    ti_floor = max(24, min(38, w * 0.16))
    su_floor = max(7, min(11, w * 0.055))
    tg_floor = max(6, min(10, w * 0.048))
    ti = max(ti_floor, min(104, w * 0.098))
    su = max(su_floor, min(28, w * 0.027))
    tg = max(tg_floor, min(24, w * 0.023))

    title_px = 21 if is_tiny else ti
    sub_px = 9 if is_tiny else su
    tag_px = 8 if is_tiny else tg

    logo_h = omPxV * 0.5055
    logo_mb = 4 if is_tiny else 10
    title_h = title_px * 1.35
    title_mt = 6 if is_tiny else (12 if (h > 0 and h < 620) else 40)
    div_h = 2
    div_mt = 4 if (h > 0 and h < 620) else 10
    sub_h = 0 if is_ultra else sub_px * 1.4
    sub_mt = 4 if is_tiny else 14
    tag_h = 0 if is_ultra else tag_px * 1.5
    tag_mt = 8 if is_tiny else (20 if (h > 0 and h < 620) else 26)

    total = (logo_h + logo_mb + title_h + title_mt + div_h + div_mt
             + sub_h + sub_mt + tag_h + tag_mt)
    return dict(om=om, omPxV=omPxV, tiny=is_tiny, ultra=is_ultra,
                sub=sub_px, tag=tag_px, total=total)


def main() -> int:
    if not os.path.exists(SPLASH):
        print('🔴 找不到 %s' % SPLASH)
        return 1
    src = io.open(SPLASH, encoding='utf-8').read()
    fails = 0

    print('=' * 66)
    print('开屏布局六尺寸验算（判据 379）')
    print('=' * 66)
    print('  %-11s %-9s %-8s %-9s %-7s %-8s %s'
          % ('设备', '尺寸', 'omPxV', '内容高', '屏高', '占屏高', '判定'))
    print('  ' + '-' * 62)

    for w, h, n in SIZES:
        r = calc(w, h)
        pct = r['total'] / h * 100
        ok = pct <= MAX_RATIO
        if not ok:
            fails += 1
        print('  %-11s %4dx%-4d %7.1f %9.1f %7d %7.1f%% %s%s'
              % (n, w, h, r['omPxV'], r['total'], h, pct,
                 '✅' if ok else '🚨 溢出风险',
                 '  (tiny)' if r['tiny'] else ''))

    print('  ' + '-' * 62)
    print()
    print('  ══ 标语 / 副标题 可见性 ══')
    for w, h, n in SIZES:
        r = calc(w, h)
        print('    %-11s 副标题 %2d vp ｜ 标语 %2d vp ｜ %s'
              % (n, r['sub'], r['tag'],
                 '按设计隐藏（ultraTiny）' if r['ultra'] else '可见'))

    print()
    print('  ══ 源码守卫 ══')
    # ★ 先剥掉注释再检查 —— 否则「演进史」里提到的旧写法会被误报
    code = re.sub(r'/\*.*?\*/', '', src, flags=re.S)      # 块注释
    code = re.sub(r'//[^\n]*', '', code)                  # 行注释

    guards = [
        # 判据 378：标语必须在文字 Column 里，不能再用贴底 Stack
        (r'Stack\(\{\s*alignContent:\s*Alignment\.Bottom\s*\}\)', False,
         '标语不该再用贴底 Stack（判据 378：放进内容流）'),
        # 判据 379：标语的 margin 不该用 vh × 系数 当偏移
        #   ⚠️ 只查 margin 上下文 —— 光带的 `y: vh * 0.30` 是装饰元素按比例定位，合法
        (r'margin\(\s*\{\s*top:\s*this\.vh\s*\*', False,
         '标语 margin 不该用 vh × 系数（判据 379：比例公式在极端尺寸失效）'),
        # 标语文本应该在（且只在）文字 Column 里出现一次
        (r'碎片时间，随时开局', True,
         '标语文本应存在'),
        # 标语必须真的在 Column 内 —— 用「副标题之后 800 字符内出现」近似
        (r"355 GAMES'\)\s*\)[\s\S]{0,900}碎片时间，随时开局", True,
         '标语应紧跟副标题（在同一个 Column 内）'),
    ]
    for pat, should_exist, desc in guards:
        hit = re.search(pat, code) is not None
        ok = (hit == should_exist)
        if not ok:
            fails += 1
        print('    %s %s' % ('✅' if ok else '🔴', desc))

    print()
    print('=' * 66)
    if fails == 0:
        print('✅ 全部通过（六尺寸内容 ≤ %d%% 屏高 ｜ 源码守卫 %d 条）'
              % (MAX_RATIO, len(guards)))
    else:
        print('🔴 %d 处不合格' % fails)
    print('=' * 66)
    return 0 if fails == 0 else 1


if __name__ == '__main__':
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
