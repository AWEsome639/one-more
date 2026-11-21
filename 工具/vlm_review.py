#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""vlm_review.py —— 让视觉大模型审截图，找布局缺陷（第二意见）

用法：
  python3 工具/vlm_review.py --limit 20            # 审今天最新的 20 个不同游戏
  python3 工具/vlm_review.py --files a.jpeg b.jpeg # 指定文件

输出：每张一行判定，汇总写 _巡检记录/★★★-VLM审查-<时间>.md
"""
import base64, io, json, os, re, ssl, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, '_巡检记录')
KEY = None
for line in io.open('/Users/a0000/.dsh/.credentials.yaml', encoding='utf-8', errors='replace'):
    m = re.match(r'\s*DASHSCOPE_API_KEY:\s*"?([^"\s]+)"?', line)
    if m:
        KEY = m.group(1)
        break
if not KEY:
    print('找不到 DASHSCOPE_API_KEY'); sys.exit(1)

URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'
MODEL = os.environ.get('VLM_MODEL', 'qwen3-vl-plus')

PROMPT = """这是一张手机游戏截图（竖屏，2224×2496 像素）。

请只回答「布局」问题，严格按下面格式输出一行：

判定: 正常 或 可疑
问题: <如果没有问题写"无"；有问题就一句话说清，例如"底部重开按钮只露出上边缘">
位置: <上/中/下/左/右，或多处；没问题写"无">

重点检查：
1. 底部有没有按钮被屏幕下边缘切断（只看到上边缘、或文字被截）
2. 格子/卡片网格的最后一排是否完整
3. 左右有没有内容溢出屏幕
4. 有没有明显的元素重叠、文字压在别的元素上

⚠️ 只描述你**真的看到**的。看不清就写"看不清"。不要猜测意图。"""


def ask(path):
    b64 = base64.b64encode(io.open(path, 'rb').read()).decode()
    body = {
        'model': MODEL,
        'messages': [{'role': 'user', 'content': [
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,' + b64}},
            {'type': 'text', 'text': PROMPT},
        ]}],
        'max_tokens': 220,
        'temperature': 0,
    }
    req = urllib.request.Request(URL, data=json.dumps(body).encode(),
                                 headers={'Authorization': 'Bearer ' + KEY,
                                          'Content-Type': 'application/json'})
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=120, context=ctx) as r:
        data = json.loads(r.read().decode())
    return data['choices'][0]['message']['content'].strip()


def pick(limit):
    # ★ 判据 3112/3113：① 用**滚动窗口**（不用「今天」，跨零点会清零）
    #                  ② 取最新按 **mtime**，不按文件名里的 HHMMSS（它无日期，202127 会盖掉次日的 111701）
    win_h = int(os.environ.get('SCREENSHOT_WINDOW_H', '36'))
    cutoff = time.time() - win_h * 3600
    newest = {}
    for n in os.listdir(D):
        if not (n.startswith('截图-') and n.endswith('.jpeg')):
            continue
        p = os.path.join(D, n)
        mt = os.path.getmtime(p)
        if mt < cutoff:
            continue
        m = re.match(r'截图-(.+)-(\d{6})\.jpeg$', n)
        if not m:
            continue
        g = m.group(1)
        if g not in newest or mt > newest[g][0]:
            newest[g] = (mt, p)
    items = sorted(newest.items(), key=lambda kv: -kv[1][0])
    return [(g, p) for g, (mt, p) in items[:limit]]


def main():
    args = sys.argv[1:]
    if '--files' in args:
        i = args.index('--files')
        targets = [(os.path.basename(f), f) for f in args[i + 1:]]
    else:
        lim = 20
        if '--limit' in args:
            lim = int(args[args.index('--limit') + 1])
        targets = pick(lim)
    print('  模型 %s，共 %d 张' % (MODEL, len(targets)))
    rows = []
    for g, p in targets:
        t0 = time.time()
        try:
            ans = ask(p)
        except Exception as e:
            ans = '判定: 错误\n问题: %s' % str(e)[:100]
        verdict = '可疑' if '可疑' in ans.split('\n')[0] else ('正常' if '正常' in ans.split('\n')[0] else '?')
        q = ''
        for line in ans.split('\n'):
            if line.startswith('问题'):
                q = line.split(':', 1)[-1].strip()
        rows.append((g, verdict, q, round(time.time() - t0, 1)))
        print('  %-28s %-4s %5.1fs  %s' % (g[:28], verdict, time.time() - t0, q[:52]))
    out = os.path.join(D, '★★★-VLM审查-%s.md' % time.strftime('%m%d-%H%M%S'))
    with io.open(out, 'w', encoding='utf-8') as f:
        f.write('# VLM 视觉审查（%s，模型 `%s`）\n\n' % (time.strftime('%Y-%m-%d %H:%M'), MODEL))
        f.write('| 游戏 | 判定 | 问题 | 耗时 |\n|---|---|---|---|\n')
        for g, v, q, s in rows:
            f.write('| `%s` | %s | %s | %.1fs |\n' % (g, v, q or '无', s))
        sus = [r for r in rows if r[1] == '可疑']
        f.write('\n**可疑 %d / %d**\n' % (len(sus), len(rows)))
    print('\n  可疑 %d / %d  →  %s' % (len([r for r in rows if r[1] == '可疑']), len(rows), out))


if __name__ == '__main__':
    main()
