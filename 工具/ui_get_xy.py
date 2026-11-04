#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ui_get_xy.py —— 从 uitest dumpLayout 的 json 里**安全地**取一个控件的中心坐标

★ 为什么需要这个（第 1231 轮，判据 627）
  旧的取坐标写法有两个坑，本轮都踩到了：

  ① **stderr 被吞**：`python3 -c '...' 2>/dev/null` 出错时输出空，
     变量变成 `""` ⇒ 后面的 `[ "$V" = "0 0" ]` 判 false ⇒ **继续执行**
     ⇒ 用空坐标去点 ⇒ 什么也没发生，而脚本还以为成功了
  ② **哨兵值守卫不覆盖"命令失败"**：
     `[ "$CARD" = "0 0" ]` 只排除"命中了哨兵"这一种；
     `""`、`"ERR"`、`"abc"` 全都会走进"继续执行"分支

  本轮实测代价：`/tmp/srr.json` 是 **0 字节** ⇒ 解析失败 ⇒ CARD="" ⇒
  点了空坐标 ⇒ 12 帧截到的是**锁屏**（「11月4日，星期三」「无服务」）

⇒ 本工具的契约：
   · **成功** ⇒ 打印 `"x y"`，退出码 **0**
   · **失败** ⇒ 打印 `ERR:<原因>`，退出码 **非 0**
   ⇒ 调用方**必须检查退出码**，不能只看输出字符串

用法：
  python3 工具/ui_get_xy.py <dump.json> <控件 id> [--text <可见文字>]
  # 退出码：0 成功 ｜ 1 文件缺失/为空 ｜ 2 JSON 解析失败 ｜ 3 找不到控件
"""
import json
import os
import re
import sys


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 2:
        print('ERR:usage(need <dump.json> <id>)')
        return 1
    path = args[0]
    want_id = args[1]
    want_text = None
    if '--text' in args:
        i = args.index('--text')
        if i + 1 < len(args):
            want_text = args[i + 1]

    # ── ① 文件存在且非空（0 字节是"dump 失败"，不是"没找到控件"）──
    if not os.path.exists(path):
        print('ERR:file_missing(%s)' % path)
        return 1
    size = os.path.getsize(path)
    if size < 500:                      # dump 正常都在 10KB 以上；<500 一定是失败
        print('ERR:file_empty(%s, %d bytes)' % (path, size))
        return 1

    # ── ② JSON 必须能解析 ──
    try:
        root = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        print('ERR:json(%s)' % e)
        return 2

    # ── ③ 找控件 ──
    found = []

    def walk(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {})
        cid = a.get('id') or ''
        txt = (a.get('text') or '').strip()
        hit = False
        if want_id and want_text is None:
            hit = (cid == want_id)
        elif want_text is not None:
            hit = (txt == want_text)
        if hit:
            m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds', ''))
            if m:
                b = [int(v) for v in m[0]]
                found.append(((b[0] + b[2]) // 2, (b[1] + b[3]) // 2))
        for c in n.get('children', []) or []:
            walk(c)

    walk(root)

    if not found:
        print('ERR:not_found(id=%s,text=%s)' % (want_id, want_text))
        return 3

    x, y = found[0]
    print('%d %d' % (x, y))
    return 0


if __name__ == '__main__':
    sys.exit(main())
