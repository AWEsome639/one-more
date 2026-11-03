#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v1.0.1 验收脚本（拾海 2026-10-19）

为什么单独写一个：
  现有的 `模拟器-状态机.py` 覆盖的是「通用导航 + 帧率」；
  这一版改动集中在 **开屏 / 触感 / 12 语言 / 三种界面模式** 四处，
  验收要按这四条走，且要在同一次运行内做完（全新安装会重置语言与模式）。

用法：
  python3 工具/验收-v1.0.1.py              # 全流程
  python3 工具/验收-v1.0.1.py --skip-start  # 模拟器已在跑，只做验收
  python3 工具/验收-v1.0.1.py --only splash # 只验开屏

产出：~/dev/yiju/验收截图-v1.0.1/<步骤>.png ＋ 同目录 report.md
"""

import os
import re
import sys
import time
import json
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = os.path.expanduser('~/Desktop/One More正式签名包.app')
OUT = os.path.join(ROOT, '验收截图-v1.0.1')
EMU_NAME = 'yiju2'
EMU_INST = os.path.expanduser('~/.Huawei/Emulator/deployed')

LOG = []


def log(msg):
    line = '[%s] %s' % (time.strftime('%H:%M:%S'), msg)
    print(line, flush=True)
    LOG.append(line)


def sh(cmd, t=120):
    """跑一条命令，返回 (rc, 合并输出)"""
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t)
        return p.returncode, (p.stdout or '') + (p.stderr or '')
    except subprocess.TimeoutExpired:
        return 124, '(timeout)'


def find_hdc():
    """找 hdc 可执行文件"""
    for p in (
        os.path.expanduser('~/Library/Huawei/Sdk/*/toolchains/hdc'),
        '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc',
        os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/*/toolchains/hdc'),
    ):
        import glob
        for hit in glob.glob(p):
            if os.path.isfile(hit) and os.access(hit, os.X_OK):
                return hit
    rc, out = sh('which hdc')
    return out.strip() if rc == 0 and out.strip() else None


def find_emulator():
    import glob
    for p in (
        os.path.expanduser('~/Library/Huawei/Sdk/*/toolchains/emulator'),
        '/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator',
        os.path.expanduser('~/Library/Huawei/command-line-tools/emulator/Emulator'),
    ):
        for hit in glob.glob(p):
            if os.path.isfile(hit) and os.access(hit, os.X_OK):
                return hit
    return None


def wait_device(timeout=180):
    """等 127.0.0.1:5555 出现在 hdc list targets"""
    hdc = find_hdc()
    if not hdc:
        log('🔴 找不到 hdc')
        return False
    deadline = time.time() + timeout
    while time.time() < deadline:
        rc, out = sh('%s list targets' % hdc, t=30)
        if '127.0.0.1:5555' in out:
            log('✅ 设备已就绪：127.0.0.1:5555')
            return True
        time.sleep(5)
    log('🔴 等设备超时')
    return False


def hdc_shell(cmd, t=60):
    hdc = find_hdc()
    return sh('%s -t 127.0.0.1:5555 shell "%s"' % (hdc, cmd), t=t)


def screencap(tag):
    """截图落盘"""
    if not os.path.isdir(OUT):
        os.makedirs(OUT, exist_ok=True)
    remote = '/data/local/tmp/_shot.jpeg'
    local = os.path.join(OUT, '%s.jpeg' % tag)
    hdc = find_hdc()
    sh('%s -t 127.0.0.1:5555 shell snapshot_display -f %s' % (hdc, remote), t=40)
    sh('%s -t 127.0.0.1:5555 file recv %s %s' % (hdc, remote, local), t=40)
    if os.path.isfile(local) and os.path.getsize(local) > 1000:
        log('📸 %s（%d B）' % (tag, os.path.getsize(local)))
        return local
    log('⚠️ 截图失败：%s' % tag)
    return None


def dump_layout():
    """拿当前界面的 UI 树（JSON）"""
    hdc = find_hdc()
    sh('%s -t 127.0.0.1:5555 shell uitest dumpLayout -p /data/local/tmp/_layout.json' % hdc, t=60)
    rc, out = sh('%s -t 127.0.0.1:5555 shell cat /data/local/tmp/_layout.json' % hdc, t=60)
    try:
        return json.loads(out)
    except Exception:
        return None


def walk_nodes(node, out):
    if isinstance(node, dict):
        a = node.get('attributes', {})
        txt = a.get('text', '')
        if txt:
            out.append((txt, a.get('bounds', '')))
        for ch in node.get('children', []) or []:
            walk_nodes(ch, out)


def texts():
    d = dump_layout()
    if not d:
        return []
    out = []
    walk_nodes(d, out)
    return out


def tap_text(sub, wait=2.0):
    """按文字找元素并点它的中心"""
    for txt, bounds in texts():
        if sub in txt:
            m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds or '')
            if m:
                x = (int(m.group(1)) + int(m.group(3))) // 2
                y = (int(m.group(2)) + int(m.group(4))) // 2
                hdc = find_hdc()
                sh('%s -t 127.0.0.1:5555 shell uitest uiInput click %d %d' % (hdc, x, y), t=30)
                log('👆 点了「%s」(%d,%d)' % (sub, x, y))
                time.sleep(wait)
                return True
    return False


def back(wait=1.6):
    hdc = find_hdc()
    sh('%s -t 127.0.0.1:5555 shell uitest uiInput key Back' % hdc, t=30)
    time.sleep(wait)


def dismiss_privacy():
    """★ 铁律：隐私弹窗会吃掉所有点击"""
    for _ in range(3):
        if tap_text('同意并继续', wait=1.5):
            log('✅ 过了隐私弹窗')
            return True
        time.sleep(1)
    return False


# ─────────────────────────────────────────────
# 四个验收阶段
# ─────────────────────────────────────────────

def stage_splash():
    """
    验开屏：连拍抓描边 → 实心 → 金点
    做法：先回桌面，再点图标启动，立刻连拍
    """
    log('── 阶段 1：开屏 24 层 ──')
    hdc = find_hdc()
    # 回桌面
    sh('%s -t 127.0.0.1:5555 shell uitest uiInput key Home' % hdc, t=30)
    time.sleep(2)
    screencap('01-桌面（看应用名是不是 One More）')

    # 启动应用
    rc, out = sh('%s -t 127.0.0.1:5555 shell aa start -b com.andrewoscar.onemore -a EntryAbility' % hdc, t=40)
    log('启动：%s' % ('成功' if rc == 0 else out.strip()[:80]))

    # 连拍（开屏 3.4 秒，抓 5 张）
    for i in range(5):
        screencap('02-开屏-%d' % i)
        time.sleep(0.45)

    time.sleep(4)
    dismiss_privacy()
    screencap('03-主界面')
    return True


def stage_home():
    log('── 阶段 2：主页动画与触感 ──')
    # 切分类（看内容刷新脉冲）
    for name in ('逻辑', '数字', '记忆'):
        if tap_text(name, wait=1.2):
            screencap('04-切到分类-%s' % name)
    tap_text('全部', wait=1.2)
    screencap('05-回到全部')
    return True


def stage_settings_modes():
    """
    验三种界面模式：default / 大字 / 紧凑
    ★ 全新安装会重置模式 ⇒ 必须在同一次运行内做完
    """
    log('── 阶段 3：三种界面模式 ──')
    if not tap_text('设置', wait=2.0):
        log('⚠️ 找不到「设置」入口')
        return False
    screencap('06-设置页')

    for mode in ('默认', '大字模式', '简约模式'):
        if tap_text(mode, wait=2.2):
            screencap('07-模式-%s' % mode)
            # 回主页看布局
            tap_text('游戏', wait=1.8)
            screencap('08-%s-下的主页' % mode)
            tap_text('设置', wait=1.8)
    # 收回到默认
    tap_text('默认', wait=2.0)
    back()
    return True


def stage_languages():
    log('── 阶段 4：12 语言抽查 ──')
    if not tap_text('设置', wait=2.0):
        return False
    for lang in ('日本語', '한국어', 'Русский', 'العربية'):
        if tap_text(lang, wait=2.0):
            screencap('09-语言-%s' % lang)
            back()
            time.sleep(1)
            tap_text('设置', wait=1.8)
    # 收回中文
    tap_text('简体中文', wait=2.0)
    back()
    return True


def main():
    args = sys.argv[1:]
    only = None
    if '--only' in args:
        only = args[args.index('--only') + 1]

    log('════ One More v1.0.1 验收 ════')
    if not os.path.exists(PKG):
        log('🔴 找不到包：%s' % PKG)
        return 1

    if '--skip-start' not in args:
        emu = find_emulator()
        if not emu:
            log('🔴 找不到 emulator')
            return 1
        log('启动模拟器（后台）…')
        subprocess.Popen([emu, '-start', EMU_NAME, '-instancePath', EMU_INST],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not wait_device():
            return 1

    # 装包
    hdc = find_hdc()
    log('装包…')
    rc, out = sh('%s -t 127.0.0.1:5555 install -r "%s"' % (hdc, PKG), t=300)
    ok = 'install bundle successfully' in out or 'successfully' in out.lower()
    log('%s 装包：%s' % ('✅' if ok else '🔴', out.strip()[-120:]))

    stages = [('splash', stage_splash), ('home', stage_home),
              ('modes', stage_settings_modes), ('langs', stage_languages)]
    for name, fn in stages:
        if only and name != only:
            continue
        try:
            fn()
        except Exception as e:
            log('🔴 阶段 %s 出错：%s' % (name, e))

    # 写报告
    if not os.path.isdir(OUT):
        os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'report.md'), 'w', encoding='utf-8') as f:
        f.write('# One More v1.0.1 验收报告\n\n```\n' + '\n'.join(LOG) + '\n```\n')
    log('✅ 报告写到 %s' % os.path.join(OUT, 'report.md'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
