#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""找文字并点击 —— dump 与 click 在同一个进程里完成，避免中间页面滚动

为什么不用 shell 版：
  设置页会**记住滚动位置**，而且两次 dump 之间位置还会自己变。
  shell 版是「dump → 退出 → 解析 → 再起一个进程点击」，
  中间隔了几百毫秒，控件可能已经滑出屏幕 ⇒ 点击落空。
  这个版本在同一次 dump 的 JSON 上直接算坐标并立刻点击。

用法: python3 tools/tap_text.py "日本語" [包含匹配即可，支持 emoji 前缀]
"""
import json, re, subprocess, sys, os, time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
TMP = '/tmp/tap_text.json'


def dump():
    subprocess.run([HDC, 'shell', 'uitest dumpLayout -p /data/local/tmp/tt.json'],
                   capture_output=True, timeout=60)
    subprocess.run([HDC, 'file', 'recv', '/data/local/tmp/tt.json', TMP],
                   capture_output=True, timeout=60)
    with open(TMP, encoding='utf-8') as f:
        return json.load(f)


def find(node, needle, out):
    a = node.get('attributes', {})
    t = a.get('text', '')
    # ★ 包含匹配 —— 芯片文案是「🇯🇵 日本語」，用开头匹配永远匹配不上
    if needle in t:
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', a.get('bounds', '') or '')
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            out.append(((x1 + x2) // 2, (y1 + y2) // 2, t, y2))
    for c in node.get('children', []):
        find(c, needle, out)


def main():
    needle = sys.argv[1]
    scrolls = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    for attempt in range(scrolls + 1):
        try:
            tree = dump()
        except Exception as e:
            print(f'  dump 失败: {e}')
            return 1
        hits = []
        find(tree, needle, hits)
        onscreen = [h for h in hits if h[3] <= 2232]
        if onscreen:
            x, y, t, _ = onscreen[0]
            # ★ 立刻点，不再起第二个进程做别的事
            subprocess.run([HDC, 'shell', f'uitest uiInput click {x} {y}'],
                           capture_output=True, timeout=60)
            print(f'  ✅ 点了「{t}」@({x},{y})')
            return 0
        # 没找到 ⇒ 上滚一点再试（上滚 = 从小的 y 拖到大的 y）
        subprocess.run([HDC, 'shell', 'uitest uiInput swipe 660 500 660 1500 1200'],
                       capture_output=True, timeout=60)
        time.sleep(1)
    print(f'  ❌ 滚了 {scrolls} 次没找到「{needle}」')
    return 1


if __name__ == '__main__':
    sys.exit(main())
