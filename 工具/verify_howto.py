#!/usr/bin/env python3
"""批量验证说明页的「玩法要点」是否真的显示出来。

★ 2026-11-02（判据 144/154）：
   howTo 已填 183 款，但真机逐款验证非常慢（每款约 20 秒）。
   这个脚本的目标是：**一次跑一批，用"要点文本是否出现在 dump 里"判定**，
   而不是靠"看起来像"。

用法：
  python3 工具/verify_howto.py --limit 20        # 验前 20 款（按 howTo 顺序）
  python3 工具/verify_howto.py --only 24 点 汉诺塔  # 只验指定中文名
  python3 工具/verify_howto.py --limit 5 --dry   # 只打印将验哪些

判定方式（不依赖任何视觉）：
  ① 取该款的 howTo.zh[0] 的**前 12 个字**作指纹
  ② 进游戏 → 点 `?` → dumpLayout → 在全部 text 里找这个指纹
  ③ 找到 = PASS；找不到 = FAIL（并打印实际 dump 里的前 20 条，便于排查）
"""
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV = "127.0.0.1:5555"


def sh(cmd, timeout=40):
    try:
        subprocess.run([HC, '-t', DEV, 'shell', cmd], capture_output=True, timeout=timeout)
    except Exception:
        pass


def device_alive():
    """★ 2026-11-02（判据 158）：**前置条件探测**。
    设备断连时 `hdc shell` 会失败，必须**在跑批之前**发现，
    否则会把"设备断了"误报成"N 款游戏都坏了"。"""
    try:
        r = subprocess.run([HC, '-t', DEV, 'shell', 'echo __OK__'],
                           capture_output=True, timeout=20)
        return b'__OK__' in r.stdout
    except Exception:
        return False


def dump_ok(vb):
    """dump 非空 —— 第二道前置检查（设备在但 UI 拿不到时也要中止）"""
    try:
        return len(vb.dump()) > 5
    except Exception:
        return False


def load_vb():
    spec = importlib.util.spec_from_file_location('vb', os.path.join(ROOT, '工具/verify_batch.py'))
    vb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(vb)
    return vb


def load_howto():
    """从 GameHowTo.ets 里解出 {gameId: (zh0, zh_count)}"""
    p = os.path.join(ROOT, 'entry/src/main/ets/core/GameHowTo.ets')
    src = io.open(p, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r"^  '([a-z0-9_]+)': \{\n    zh: \[(.*?)\],\n    en: \[", src, re.S | re.M):
        gid = m.group(1)
        items = re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(2))
        if items:
            out[gid] = (items[0].replace("\\'", "'"), len(items))
    return out


def load_names():
    """gameId ⇒ 中文名"""
    p = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
    src = io.open(p, encoding='utf-8').read()
    return dict(re.findall(r"id: '([a-z0-9_]+)', name: '([^']+)'", src))


def main():
    args = sys.argv[1:]
    limit = 20
    only = []
    dry = '--dry' in args
    if '--limit' in args:
        limit = int(args[args.index('--limit') + 1])
    if '--only' in args:
        i = args.index('--only')
        only = args[i + 1:]
    vb = load_vb()
    howto = load_howto()
    names = load_names()
    items = [(g, names.get(g, ''), v[0]) for g, v in howto.items()]
    if only:
        items = [x for x in items if x[1] in only]
    # ★ 2026-11-02：**已验过的跳过**（jsonl 是累积台账，不重复记）
    verified_path = os.path.join(ROOT, '验收截图-v1.0.1/howto_verified.jsonl')
    done = set()
    if os.path.exists(verified_path):
        for ln in io.open(verified_path, encoding='utf-8'):
            ln = ln.strip()
            if ln:
                try:
                    done.add(json.loads(ln)['name'])
                except Exception:
                    pass
    before = len(items)
    items = [x for x in items if x[1] not in done]
    if before != len(items):
        print('  已验过 %d 款，跳过；本次待验 %d 款' % (before - len(items), len(items)))
    items = items[:limit]
    print('将验 %d 款：%s' % (len(items), ', '.join(x[1] for x in items)))
    if dry:
        return 0

    # ★★★ 前置条件探测（判据 158）：任一不过 ⇒ 整批中止，**不写任何 FAIL 记录**
    if not device_alive():
        print()
        print('  ⛔ **环境不可用**：设备断连（hdc 无响应）')
        print('  ⇒ 整批中止，本次不产生任何 PASS/FAIL 记录。')
        print('  ⇒ 修法：bash 工具/device_ready.sh --install')
        return 2
    if not dump_ok(vb):
        print()
        print('  ⛔ **环境不可用**：dump 为空（设备在但 UI 拿不到）')
        print('  ⇒ 整批中止，本次不产生任何 PASS/FAIL 记录。')
        print('  ⇒ 可能原因：锁屏 / app 未启动。先 bash 工具/device_ready.sh --install')
        return 2
    # 首页必须在（否则"滚动找卡片"永远找不到 —— 上一次 10/10 误报就是这么来的）
    rows0 = vb.dump()
    if not any(str(r[0]) == '游戏' for r in rows0):
        print()
        print('  ⛔ **环境不可用**：不在首页（dump 前 6 条：%s）'
              % [str(r[0])[:12] for r in rows0[:6]])
        print('  ⇒ 整批中止，本次不产生任何 PASS/FAIL 记录。')
        return 2
    print('  ✅ 前置条件通过（设备在 ｜ dump 正常 ｜ 已停在首页）')

    passed, failed = [], []
    t0 = time.time()
    for idx, (gid, name, zh0) in enumerate(items):
        fingerprint = zh0[:12]
        # ★★★ 回到首页 —— 必须**每步校验**，不能假设"点 2 次就到"
        #   2026-11-02（第 866 轮真机抓到）：原来只点 2 次 ‹，
        #   但说明页 → 游戏页 → 首页 之后，**游戏页可能弹出结算窗**，
        #   此时 ‹ 被盖住 ⇒ 停在中途 ⇒ 后面 8 款全部"卡片未找到"。
        #   ⇒ 改成：最多 8 次，每步都 dump 校验是否已到首页。
        home = False
        for _ in range(8):
            rows = vb.dump()
            if any(str(r[0]) == '游戏' for r in rows):
                home = True
                break
            # 结算弹窗优先点「返回列表」
            rl = [r for r in rows if '返回列表' in str(r[0])]
            if rl:
                sh("uitest uiInput click %d %d" % (int(rl[0][1]), int(rl[0][2]))); time.sleep(2.2)
                continue
            b = [r for r in rows if str(r[0]) == '‹']
            if b:
                sh("uitest uiInput click %d %d" % (int(b[0][1]), int(b[0][2]))); time.sleep(2.2)
            else:
                sh("uitest uiInput keyEvent Back"); time.sleep(2.2)
        if not home:
            # ★★★ 2026-11-02（第 867 轮）：**回不了首页就直接重启 app**。
            #   实测：点 8 次 ‹ / 返回键仍然回不去（可能卡在某个弹窗层）。
            #   而 `force-stop + start` 只要 ~18 秒，比挣扎更快也更可靠。
            print('  ⚠️ %-14s 回不了首页 ⇒ 重启 app' % name)
            sh("aa force-stop com.andrewoscar.onemore"); time.sleep(3)
            sh("power-shell wakeup"); time.sleep(2)
            sh("uitest uiInput swipe 660 1900 660 500 1200"); time.sleep(3)
            sh("aa start -b com.andrewoscar.onemore -a EntryAbility"); time.sleep(15)
            rows = vb.dump()
            if not any(str(r[0]) == '游戏' for r in rows):
                failed.append((name, '重启后仍不在首页'))
                print('  ❌ %-14s 重启后仍不在首页（整批中止）' % name)
                break
        # ★★★ 先滚回列表顶部（否则上一款验证后列表停在底部，永远找不到卡片）
        #   2026-11-02（第 866 轮）：上一次跑了 2 款后，列表停在底部 ⇒ 后面全"卡片未找到"。
        for _ in range(14):
            sh("uitest uiInput swipe 660 700 660 1900 250", timeout=8)
        time.sleep(0.8)
        # 滚动找目标卡
        found = False
        for _ in range(16):
            rows = vb.dump()
            c = [r for r in rows if str(r[0]) == name]
            if c:
                sh("uitest uiInput click %d %d" % (int(c[0][1]), int(c[0][2]))); time.sleep(4.5)
                found = True
                break
            sh("uitest uiInput swipe 660 1700 660 850 450", timeout=8); time.sleep(1.0)
        if not found:
            failed.append((name, '卡片未找到'))
            print('  ❌ %-14s 卡片未找到' % name)
            continue
        # 点 ?
        q = [r for r in vb.dump() if str(r[0]) == '?']
        if not q:
            failed.append((name, '无 ? 按钮'))
            print('  ❌ %-14s 无 ? 按钮' % name)
            continue
        sh("uitest uiInput click %d %d" % (int(q[0][1]), int(q[0][2]))); time.sleep(2.8)
        texts = [str(r[0]) for r in vb.dump()]
        # 说明页可能需要滚一下才看到要点
        hit = any(fingerprint in t for t in texts)
        if not hit:
            for _ in range(3):
                sh("uitest uiInput swipe 660 1700 660 900 400"); time.sleep(1.3)
                texts += [str(r[0]) for r in vb.dump()]
                if any(fingerprint in t for t in texts):
                    hit = True
                    break
        if hit:
            passed.append(name)
            print('  ✅ %-14s 「%s…」' % (name, fingerprint))
        else:
            failed.append((name, '要点未出现'))
            print('  ❌ %-14s 要点未出现（dump 前 8 条：%s）' % (name, [t[:12] for t in texts[:8]]))
        print('     进度 %d/%d ｜ 用时 %.0fs' % (idx + 1, len(items), time.time() - t0))

    print()
    print('  ══ 结果：✅ %d ｜ ❌ %d ══' % (len(passed), len(failed)))
    for n, why in failed:
        print('    ❌ %s —— %s' % (n, why))
    # 落盘
    out = os.path.join(ROOT, '验收截图-v1.0.1/howto_verified.jsonl')
    with io.open(out, 'a', encoding='utf-8') as f:
        for n in passed:
            f.write(json.dumps({'name': n, 'ok': True}, ensure_ascii=False) + '\n')
    print('  已追加到 %s' % out)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
