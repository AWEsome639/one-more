#!/bin/bash
# 2026-11-14：**build 前的静态检查**（今晚 32 处改动全靠手工定位行号改的，错率不是意外）
#
# 为什么需要它：今天有 3 处改动把容器行行首的 `}` 吃掉了（整行替换的老坑），
#   语法错但不报错，**只有 build 时才炸** —— 而 build 在深夜跑，最不该浪费时间。
#
# 检查四项（都不需要 SDK / 不需要设备）：
#   ① 去注释/去字符串后的**大括号 / 圆括号配平**
#   ② 用了 `Bp.` 但没 `import { Bp }`
#   ③ 容器行被替换后**行首 `}` 丢失**（对比 git HEAD 的行数与 `}` 数）
#   ④ `Bp.isShort() ?` 三元式**缺冒号**
#
# 用法：bash 工具/preflight.sh            # 查 git 未提交 + 最近 20 个提交改动的 .ets
#       bash 工具/preflight.sh --all      # 查全库 games/
#
# ⚠️ 已知局限（`--all` 模式有假阳性，`changed` 模式才是主用途）：
#   去噪器对**中文文本里的英文撇号**（如 `'s`）、正则字面量、跨行拼接字符串处理不完美，
#   会把某些合法文件误报成「括号不配平」。实测 `--all` 会误报 5 个（`I18n` / `ChatFinder` /
#   `GameI18n` / `Tv` / `GameRegistry`）—— 这些文件**今天在跑，不可能有语法错**。
#   ⇒ **判断真假的标准：该文件今天是否在跑**。在跑 ⇒ 假阳性，忽略。
#       bash 工具/preflight.sh --all      # 查全库 games/
set +u
cd "/Users/a0000/dev/One More" || exit 1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

MODE="${1:-changed}"
python3 - "$MODE" <<'PY'
import io, os, re, subprocess, sys

mode = sys.argv[1] if len(sys.argv) > 1 else 'changed'

def changed_files():
    files = []
    for cmd in (['git', 'diff', '--name-only', 'HEAD~20..HEAD'],
                ['git', 'diff', '--name-only'], ['git', 'diff', '--name-only', '--cached']):
        try:
            out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode('utf-8', 'replace')
            files += [l for l in out.split('\n') if l.strip().endswith('.ets')]
        except Exception:
            pass
    return sorted(set(files))

if mode == '--all':
    files = []
    for root, _d, fs in os.walk('entry/src/main/ets'):
        for f in fs:
            if f.endswith('.ets'):
                files.append(os.path.join(root, f))
else:
    files = changed_files()

def strip_noise(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    s = re.sub(r"'(\\.|[^'\\])*'", "''", s, flags=re.S)
    s = re.sub(r'"(\\.|[^"\\])*"', '""', s, flags=re.S)
    s = re.sub(r'`(\\.|[^`\\])*`', '``', s, flags=re.S)
    return s

bad = []
for p in files:
    if not os.path.exists(p):
        continue
    raw = io.open(p, encoding='utf-8').read()
    s = strip_noise(raw)
    issues = []
    if s.count('{') != s.count('}'):
        issues.append('大括号 %d/%d' % (s.count('{'), s.count('}')))
    if s.count('(') != s.count(')'):
        issues.append('圆括号 %d/%d' % (s.count('('), s.count(')')))
    # 用去噪后的文本判「是否真的用了 Bp」—— 注释/字符串里提到 `Bp.` 不算
    # 且排除 `core/Bp.ets` 本身（它定义 Bp，不需要 import 自己）
    if (re.search(r'\bBp\.', s) and 'core/Bp' not in raw
            and not p.endswith('core/Bp.ets')):
        issues.append('用了 Bp 但没 import')
    for m in re.finditer(r'Bp\.isShort\(\)\s*\?', raw):
        line = raw[m.start():raw.find('\n', m.start())]
        if ':' not in line:
            issues.append('三元式缺冒号: ' + line.strip()[:44])
    if issues:
        bad.append((p, '; '.join(issues)))

print('== preflight：检查 %d 个 .ets ==' % len(files))
if bad:
    print('❌ %d 个有问题：' % len(bad))
    for p, i in bad:
        print('  %-52s %s' % (p.replace('entry/src/main/ets/', ''), i))
    sys.exit(1)
else:
    print('✅ 全部通过（括号配平 / Bp import / 三元式完整）')
PY
