#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 354 款游戏内部的中文文案批量翻成英文（拾海 2026-10-11）

走**免费通道**（魔搭 ms，其余 6 条路由额度都用完了）。
· 按出现频次从高到低翻 —— 高频的先翻好，中途断了也有价值
· 断点续传：结果实时写盘，重跑会跳过已翻的
· 结果落 /tmp/game_i18n.json
"""
import json
import os
import subprocess
import sys
import time

SRC = '/tmp/strings_cn.json'
OUT = '/tmp/game_i18n.json'
BATCH = 12
ROUTE = 'ms'


def llm(prompt):
    env = dict(os.environ)
    env['FREELLM_MAXTOK'] = '8000'          # 默认太小 ⇒ 输出被截断，JSON 解析失败
    r = subprocess.run(['bash', os.path.expanduser('~/.dsh/tools/free-llm.sh'), ROUTE, prompt],
                       capture_output=True, text=True, timeout=300, env=env)
    return r.stdout


def main():
    cnt = json.load(open(SRC, encoding='utf-8'))
    done = {}
    if os.path.exists(OUT):
        done = json.load(open(OUT, encoding='utf-8'))
    # 按频次降序
    items = [k for k, _ in sorted(cnt.items(), key=lambda kv: -kv[1]) if k not in done]
    print(f'  待翻 {len(items)} 条（已完成 {len(done)}）', flush=True)

    batch = []
    for i, s in enumerate(items):
        batch.append(s)
        if len(batch) >= BATCH or i == len(items) - 1:
            prompt = ("Translate each Chinese game-UI string to short natural English "
                      "(these are labels and one-line messages inside a puzzle game). "
                      "Keep emoji as-is. Output ONLY a JSON object mapping original to "
                      "translation, no markdown, no explanation.\n"
                      + json.dumps(batch, ensure_ascii=False))
            try:
                out = llm(prompt).strip()
                # 去掉可能的 ```json 包裹
                if out.startswith('```'):
                    out = out.split('```')[1]
                    if out.startswith('json'):
                        out = out[4:]
                m = json.loads(out)
                got = 0
                for k in batch:
                    if k in m and isinstance(m[k], str) and m[k].strip():
                        done[k] = m[k].strip()
                        got += 1
                json.dump(done, open(OUT, 'w'), ensure_ascii=False, indent=0)
                print(f'  [{len(done)}/{len(cnt)}] 本批 {got}/{len(batch)} 成功', flush=True)
            except Exception as e:
                print(f'  ⚠️ 本批失败: {str(e)[:80]}', flush=True)
                time.sleep(2)
            batch = []
            time.sleep(0.4)
    json.dump(done, open(OUT, 'w'), ensure_ascii=False, indent=0)
    print(f'  ✅ 完成：{len(done)} 条 → {OUT}', flush=True)


if __name__ == '__main__':
    main()
