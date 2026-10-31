#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
diff_check.py —— 提交前给改动做一次「体检」

★★★ 起因（2026-10-30，第 543 轮）：
    我用正则把 GChainReaction 的 `Palette.violet` 改成 `Palette.cyan`，
    结果 `.backgroundColor(Palette.violet)` **整段被删掉**。
    编译过、断言 200,342/0 过、真机也"能跑" —— 只是按钮没底色。
    这是**静默破坏**：所有自动化都说 OK，只有肉眼能看出来。

⇒ 这个脚本扫 `git diff`，把「可能被静默破坏」的改动标出来。

用法：
    python3 工具/diff_check.py              # 扫工作区未提交的改动
    python3 工具/diff_check.py --staged     # 扫已 git add 的
    python3 工具/diff_check.py HEAD~1 HEAD  # 扫某两次提交之间

输出：三类告警
    🔴 严重：属性/调用被整段删除（如 .backgroundColor(...) 消失）
    🟡 可疑：单行改动但属性数量变化（例如多/少一个 .xxx( )
    🔵 提示：同一文件里同一常量出现多次（改一处要确认另一处该不该改）
"""
import io, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ArkUI 常见可链式属性（用来数「一行里有多少个属性」）
ATTRS = [
    'width', 'height', 'fontSize', 'fontColor', 'fontWeight', 'backgroundColor',
    'borderRadius', 'padding', 'margin', 'layoutWeight', 'border', 'shadow',
    'opacity', 'scale', 'translate', 'rotate', 'animation', 'transition',
    'alignItems', 'justifyContent', 'textAlign', 'maxLines', 'textOverflow',
    'constraintSize', 'aspectRatio', 'focusable', 'focusBox', 'onClick',
    'onTouch', 'onKeyEvent', 'stateStyles', 'enabled', 'visibility',
]


def git(*args):
    r = subprocess.run(['git'] + list(args), cwd=ROOT,
                       capture_output=True, text=True)
    return r.stdout


def get_diff(args):
    return git('diff', '-U0', *args)


def parse(diff_text):
    """→ [(file, [removed lines], [added lines])]"""
    out = []
    cur = None
    for line in diff_text.splitlines():
        if line.startswith('diff --git'):
            m = re.search(r' b/(.+)$', line)
            if m:
                cur = {'file': m.group(1), 'minus': [], 'plus': []}
                out.append(cur)
        elif cur is not None:
            if line.startswith('---') or line.startswith('+++'):
                continue
            if line.startswith('-'):
                cur['minus'].append(line[1:])
            elif line.startswith('+'):
                cur['plus'].append(line[1:])
    return out


def count_attrs(line):
    n = 0
    for a in ATTRS:
        n += len(re.findall(r'\.' + a + r'\s*\(', line))
    return n


def check(files):
    sev = {'red': [], 'yellow': [], 'blue': []}
    for f in files:
        name = f['file']
        if not name.endswith('.ets'):
            continue
        # 🔴 严重：属性被整段删掉（removed 里有、added 里没有同名属性）
        for rm in f['minus']:
            for a in ATTRS:
                if '.' + a + '(' in rm:
                    present = any('.' + a + '(' in ad for ad in f['plus'])
                    if not present:
                        sev['red'].append(
                            '%s：`.%s(...)` 在新增行里完全消失' % (name, a))
        # 🟡 可疑：属性总数变少（减了但没补回）
        rm_n = sum(count_attrs(l) for l in f['minus'])
        ad_n = sum(count_attrs(l) for l in f['plus'])
        if f['minus'] and ad_n < rm_n:
            sev['yellow'].append(
                '%s：属性总数 %d → %d（少了 %d 个）' % (name, rm_n, ad_n, rm_n - ad_n))

    return sev


def const_repeat(files):
    """🔵 改动的文件里，是否同一个 Palette.xxx 出现多次（提醒确认另一处该不该改）"""
    out = []
    seen = set()
    for f in files:
        name = f['file']
        if name in seen or not name.endswith('.ets'):
            continue
        seen.add(name)
        path = os.path.join(ROOT, name)
        if not os.path.exists(path):
            continue
        try:
            src = io.open(path, encoding='utf-8').read()
        except Exception:
            continue
        for c in set(re.findall(r'Palette\.(\w+)', src)):
            n = len(re.findall(r'Palette\.' + c + r'\b', src))
            if n >= 2:
                out.append('%s：`Palette.%s` 出现 %d 次 —— 确认只改了该改的那处' % (name, c, n))
    return out


def main():
    args = sys.argv[1:]
    if args and args[0] == '--staged':
        diff = get_diff(['--cached'])
        label = '已暂存（--staged）'
    elif len(args) >= 2:
        diff = get_diff([args[0], args[1]])
        label = '%s..%s' % (args[0], args[1])
    else:
        diff = get_diff([])
        label = '工作区未提交'

    files = parse(diff)
    real = [f for f in files if f['minus'] or f['plus']]
    if not real:
        print('✅ [%s] 没有 .ets 改动' % label)
        return

    print('══ diff 体检：%s ｜ %d 个文件有改动 ══' % (label, len(real)))
    sev = check(real)
    blue = const_repeat(real)

    if sev['red']:
        print('\n🔴 严重（属性被整段删除）— 必须逐条确认：')
        for x in dict.fromkeys(sev['red']):
            print('   · %s' % x)
    if sev['yellow']:
        print('\n🟡 可疑（属性总数减少）— 是不是误删了什么：')
        for x in dict.fromkeys(sev['yellow']):
            print('   · %s' % x)
    if blue:
        print('\n🔵 提示（同常量多次出现）— 改一处别误伤另一处：')
        for x in dict.fromkeys(blue):
            print('   · %s' % x)

    if not (sev['red'] or sev['yellow'] or blue):
        print('\n✅ 没发现可疑删除或属性缺失')

    print('\n★ 这三类告警都是「编译能过、断言能过、但用户看得出来」的静默破坏。')
    print('  第 543 轮的 .backgroundColor 整段消失，就属于 🔴。')


if __name__ == '__main__':
    main()
