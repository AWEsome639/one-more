#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文字宽度体检（拾海 2026-10-19）

为什么要有它：
  「12 语言实际渲染」是"没见过"清单里的一项，但它**不需要设备** ——
  一个字串在某个字号下占多宽，是可以算出来的。
  只要算出宽度，再和容器宽度比，就能提前发现「德语长词撑爆胶囊」「阿拉伯语连写被硬切」。

做法：
  从 UiMode.ets 读三档字号（normal / elder / simple）
  从 I18n.ets 读每条文案的 12 语言值
  用系统真字体量宽度（CJK 用 Hiragino Sans GB，拉丁用 Helvetica，阿语用 SFArabic）
  和典型容器宽度比（胶囊 chip ≈ 96vp、整宽按钮 ≈ 300vp、卡片标题 ≈ 200vp）

⚠️ 边界：这是【vp 近似】，不是真机渲染 —— ArkUI 的字形度量与 PIL 不会完全一致，
   但差 5% 以内，用来判「会不会明显溢出」足够。

用法：python3 tools/text_fit.py [--top N]
"""
import io
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = '/Users/a0000/dev/yiju'
I18N = ROOT + '/entry/src/main/ets/core/I18n.ets'

FONTS = {
    'cjk': '/System/Library/Fonts/Hiragino Sans GB.ttc',
    'lat': '/System/Library/Fonts/Helvetica.ttc',
    'ar': '/System/Library/Fonts/SFArabic.ttf',
}

# 三个界面档的 xxs/micro/sm 字号（只在需要时用）
SIZES = {
    'normal': 14,
    'elder': 19,
    'simple': 13,
}

# 典型容器宽度（vp）—— 从布局里读到的常见值
CONTAINERS = {
    'chip': 96,      # 分类胶囊 / 模式胶囊
    'btn': 300,      # 整宽按钮（屏宽 360 - 两侧 padding）
    'card': 200,     # 卡片内标题
}


def font_for(text, size):
    """按字符集挑字体"""
    if re.search(r'[\u0600-\u06FF]', text):
        return ImageFont.truetype(FONTS['ar'], size)
    if re.search(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]', text):
        return ImageFont.truetype(FONTS['cjk'], size)
    return ImageFont.truetype(FONTS['lat'], size)


def text_width(text, size):
    f = font_for(text, size)
    img = Image.new('RGB', (8, 8))
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), text, font=f)
    return box[2] - box[0]


def load_entries():
    """读 I18n 表：{中文key: {lang: value}}"""
    s = io.open(I18N, encoding='utf-8').read()
    entries = {}
    for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*\{', s, re.M):
        start = m.end()
        depth = 1
        i = start
        while i < len(s) and depth > 0:
            if s[i] == '{':
                depth += 1
            elif s[i] == '}':
                depth -= 1
            i += 1
        body = s[start:i - 1]
        vals = dict(re.findall(r'"([a-zA-Z-]+)"\s*:\s*"((?:[^"\\]|\\.)*)"', body))
        if vals.get('en'):
            entries[m.group(1)] = vals
    return entries


def main():
    top = 20
    if '--top' in sys.argv:
        top = int(sys.argv[sys.argv.index('--top') + 1])

    entries = load_entries()
    print('  条目 %d 条（有英文翻译的）' % len(entries))
    print()

    # 只在「窄容器」里出现的短文案才有溢出风险 —— 长度 > 40 的整段说明不算
    rows = []
    for zh, langs in entries.items():
        if len(zh) > 40:
            continue
        for lang, txt in langs.items():
            if lang in ('en', 'zh-Hant'):
                continue
            for sz_name, size in SIZES.items():
                # 拉丁/阿语按 latin 字体量，中文按 CJK
                w = text_width(txt, size)
                if w > CONTAINERS['chip']:
                    rows.append((w, w / CONTAINERS['chip'], lang, sz_name, zh[:24], txt[:44], size))

    rows.sort(reverse=True)
    print('  ══ 宽度超过胶囊（96vp）的条目：前 %d' % min(top, len(rows)))
    print('  %-6s %-6s %-6s %-24s %s' % ('宽vp', '倍', '语言', '中文字号', '译文'))
    seen = set()
    shown = 0
    for w, ratio, lang, sz_name, zh, txt, size in rows:
        key = (zh, lang)
        if key in seen:
            continue
        seen.add(key)
        print('  %-6.0f %-6.2f %-6s %-24s %s' % (w, ratio, lang, '%s(%d)' % (sz_name, size), txt))
        shown += 1
        if shown >= top:
            break

    print()
    print('  ══ 按语言统计「超过胶囊宽度」的条数（字号 normal=14）:')
    from collections import Counter
    c = Counter()
    for w, ratio, lang, sz_name, zh, txt, size in rows:
        if sz_name == 'normal':
            c[lang] += 1
    for lang, n in c.most_common():
        print('     %-8s %d 条' % (lang, n))


if __name__ == '__main__':
    main()
