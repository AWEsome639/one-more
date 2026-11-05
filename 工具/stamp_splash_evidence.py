#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把开屏截图**绑到具体的构建产物**上（判据 383）

★ 为什么要有这个（2026-11-03 第 1100 轮）
  判据 330 早就说过「不能用文件 mtime 判断证据新鲜度」——
  因为 mtime 会把"改了又改回"也算成改动。

  而本轮我自己又犯了同一个错，只是换了个 mtime：
    先用「Splash.ets 的 git 提交时间」当基线
      ⇒ 系统性假阴性：流程是「改代码→编译→装机→**拍**→提交」，
        截图必然早于提交 ⇒ 每轮都被判"旧版"
    再改成「HAP 的构建时间」
      ⇒ 变成**假阳性**：`cp` 一个旧图就会刷新它的 mtime，
        让旧证据看起来比新构建还新

  ⇒ 结论：**任何基于 mtime 的新鲜度判断都是错的**，不管比的是哪个文件。
  ⇒ 正确做法：**把截图绑到构建产物的内容哈希上**。

★ ⚠️ 已知漏判边界（判据 390）
  绑定的是 `Splash.ets` 的源码哈希。
  若以下文件改动**影响开屏观感**，本检查**不会**变红：
    · `core/Design.ets`（调色板 / 字号 / 动效曲线）
    · `core/Bp.ets`（断点）
    · `core/I18n.ets` / `core/GameI18n.ets`（文案）
    · `AppScope/resources` 下的图标资源
  ⇒ 这些文件改动后，请**手工重拍开屏并重新盖章**。
  （不把它们纳入哈希，是因为它们改动的绝大多数与开屏无关；
    绑太宽会让证据天天失效，反而没人愿意盖章。）

★ 做法
  1. 计算当前 HAP 的 sha256
  2. 给指定截图记录 {file, hap_sha256, hap_bytes, stamped_at}
  3. 写进 验收截图-v1.0.1/splash_evidence.jsonl
  4. check_splash.py 读它：只有 hap_sha256 == 当前 HAP 的 sha256，才算"改后"

用法：
  python3 工具/stamp_splash_evidence.py 验收截图-v1.0.1/SPLASH_xxx.png ...
  python3 工具/stamp_splash_evidence.py --list        # 看已盖章的证据
"""
import hashlib
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HAP = os.path.join(ROOT, 'entry/build/default/outputs/default/entry-default-signed.hap')
SHOT_DIR = os.path.join(ROOT, '验收截图-v1.0.1')
MANIFEST = os.path.join(SHOT_DIR, 'splash_evidence.jsonl')


SPLASH_SRC = os.path.join(ROOT, 'entry/src/main/ets/pages/Splash.ets')


def splash_hash():
    """Splash.ets 的内容哈希 —— 这才是"这份证据证明的是哪一版开屏"。

    ★ 2026-11-03（第 1104 轮）修正：原来绑的是**整个 HAP** 的哈希。
      问题：我改一个跟开屏无关的文件（如 Index.ets 的路由转场），
            HAP 哈希就变了 ⇒ **所有开屏证据瞬间失效**。
      ⇒ 太粗。开屏的证据只该绑**开屏自己的源码**。
      （仍保留 HAP 哈希作为附加信息，便于追查构建。）
    """
    if not os.path.exists(SPLASH_SRC):
        return None
    h = hashlib.sha256()
    with io.open(SPLASH_SRC, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()


def hap_hash():
    if not os.path.exists(HAP):
        return None, 0
    h = hashlib.sha256()
    with io.open(HAP, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest(), os.path.getsize(HAP)


def read_manifest():
    out = []
    if not os.path.exists(MANIFEST):
        return out
    for line in io.open(MANIFEST, encoding='utf-8'):
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except Exception:
            pass
    return out


def main():
    args = sys.argv[1:]
    hh, hs = hap_hash()
    sh = splash_hash()
    if sh is None:
        print('🔴 找不到 Splash.ets')
        return 1
    if hh is None:
        print('⚠️ 找不到 HAP（仍可用源码哈希绑定）：%s' % HAP)

    if not args or args[0] == '--list':
        cur = read_manifest()
        print('  当前 **Splash.ets** sha256 = %s…（判定用这个）' % sh[:16])
        if hh:
            print('  当前 HAP         sha256 = %s…（附加信息）' % hh[:16])
        print()
        if not cur:
            print('  （清单为空）')
            return 0
        print('  %-46s %-18s %s' % ('文件', '绑定的 Splash.ets', '是否当前源码'))
        n_ok = 0
        for e in cur:
            ok = e.get('splash_sha256') == sh
            if ok:
                n_ok += 1
            print('  %-46s %-18s %s' % (
                os.path.basename(e.get('file', ''))[:46],
                (e.get('splash_sha256') or e.get('hap_sha256') or '')[:16],
                '✅ 当前' if ok else '⚠️ 旧源码'))
        print()
        print('  ⇒ %d / %d 张绑在当前 Splash.ets 上' % (n_ok, len(cur)))
        return 0

    # 盖章
    cur = read_manifest()
    by_file = {e.get('file'): e for e in cur}
    now = time.strftime('%Y-%m-%d %H:%M:%S')
    n_new = 0
    for a in args:
        p = a if os.path.isabs(a) else os.path.join(ROOT, a)
        if not os.path.exists(p):
            print('  ⚠️ 跳过（不存在）: %s' % a)
            continue
        rel = os.path.relpath(p, ROOT)
        by_file[rel] = {
            'file': rel,
            'splash_sha256': sh,        # ★ 判定用这个
            'hap_sha256': hh,           # 附加：便于追查构建
            'hap_bytes': hs,
            'stamped_at': now,
        }
        n_new += 1
        print('  ✅ %s' % os.path.basename(rel))
    with io.open(MANIFEST, 'w', encoding='utf-8') as f:
        for e in by_file.values():
            # ★★★ 2026-11-05（第 1357 轮，判据 959/960）：**拒绝「比 HAP 旧」的截图**
            #   实证：`853×533` 那台启动失败被跳过，脚本仍把 **Nov 4 的旧图**拿去盖章
            #     ⇒ 旧图（修前拍的 OM 未对齐）被绑上**当前源码哈希**
            #     ⇒ **证据撒谎**：它证明不了当前这版
            #   ⇒ 判据：盖章前必须核对 `mtime(截图) >= mtime(HAP)`，
            #     **更旧直接拒绝**（不静默放行）
            try:
                _hap_m = os.path.getmtime(hap_path) if 'hap_path' in dir() else 0.0
            except Exception:
                _hap_m = 0.0
            if _hap_m > 0:
                _fresh, _stale = [], []
                for f in fps:
                    try:
                        if os.path.getmtime(f) + 1.0 < _hap_m:
                            _stale.append(f)
                        else:
                            _fresh.append(f)
                    except Exception:
                        pass
                if _stale:
                    print('  🔴 **拒绝盖章（比 HAP 旧，证明不了当前这版）**：')
                    for f in _stale:
                        print('      %s' % f)
                    print('  ⇒ 请重拍这些尺寸后再盖章')
                fps = _fresh
            f.write(json.dumps(e, ensure_ascii=False) + '\n')
    print()
    print('  已绑到 **Splash.ets** sha256=%s…' % sh[:16])
    if hh:
        print('  （附加 HAP sha256=%s…）' % hh[:16])
    print('  清单共 %d 条' % len(by_file))
    return 0


if __name__ == '__main__':
    sys.exit(main())
