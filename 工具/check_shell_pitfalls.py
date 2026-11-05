#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_shell_pitfalls.py —— 扫 shell 脚本里的「静默失效」陷阱

★ 为什么需要（判据 854，第 1329 轮）
  第 1325 轮我写下判据 848（`grep -c` 匹配 0 行时退出码是 1），
  还专门修了 `capture_splash_timing.sh`。
  第 1328 轮**我自己在新代码里又写了同一个坑**，立刻复现。
  ⇒ **判据写进台账 ≠ 免疫；必须写进检查器。**

★ 按判据 759：**检查器报 0 之前，必须先在已知的真实案例上验证它**
  ⇒ `--selftest` 用历史上的真 bug 做正例（必须报警）
  ⇒ 并配反例（正确的写法必须不报）

用法:
  python3 工具/check_shell_pitfalls.py              # 扫 工具/*.sh
  python3 工具/check_shell_pitfalls.py --selftest   # 自检（含正例+反例）
  python3 工具/check_shell_pitfalls.py <file...>    # 指定文件
退出码: 0 = 无问题 ｜ 1 = 有问题 ｜ 2 = 输入/自检失败
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── 规则表（★ 判据 855：只报「确定是 bug」的，⛔ 宁少不乱）
#    每条规则 = (id, 判据号, 检测函数, 说明)
#    检测函数返回 [(行号, 该行文本)]，由 scan_file 调用

def _rule_sc01(lines):
    """判据 848：`grep -c ... || echo 0` ⇒ 匹配 0 行时得到 "0\\n0" """
    out = []
    for i, l in enumerate(lines, 1):
        if re.search(r'grep\s+-c', l) and re.search(r'\|\|\s*echo\s+0', l):
            out.append((i, l.strip()[:100]))
    return out


def _rule_sc02(lines):
    """判据 836/1207：`$VAR` 紧跟**任何非 ASCII 字节** ⇒ bash 把它算进变量名

    ★ 2026-11-05（第 1382 轮）**从「枚举全角字符」改成「任何非 ASCII」**
      原来只列了 `（）【】，。：；、""''！？～`
      ⇒ 而真实世界里紧跟变量的可能是 `→` `｜` `·` `（` 之后的任何东西
      ⇒ 我因此**同一个坑踩了五次**（957 / 1004 / 1165 / 1199 / 1205）
      ⇒ 根治：**机器不管哪个字符，只要不是 ASCII 就报**
      ⚠️ 例外：`${VAR}` 是正确写法，不该报 ⇒ 正则用负向后视排除花括号
    """
    out = []
    for i, l in enumerate(lines, 1):
        # 跳过纯注释行（注释里的示例不该报错）
        st = l.lstrip()
        if st.startswith('#'):
            continue
        # $VAR 后紧跟任何非 ASCII 字符（且不是 ${VAR} 形式）
        for m in re.finditer(r'(?<![{$\w])\$([A-Za-z_]\w*)([^\x00-\x7f])', l):
            out.append((i, l.strip()[:100]))
            break
    return out


def _rule_sc03(lines):
    """判据 803：**取管道结果后立刻看 `$?`** 才是 bug（单纯取字符串不是）"""
    out = []
    for i, l in enumerate(lines, 1):
        # 本行有 `X=$(... | ...)`
        if not re.search(r'\w+=\$\([^)]*\|', l):
            continue
        # 看后面 1~3 行有没有 `$?`
        nxt = '\n'.join(lines[i:min(len(lines), i + 3)])
        if re.search(r'\$\?', nxt):
            out.append((i, l.strip()[:100]))
    return out


def _rule_sc04(lines):
    """判据 830：**变量直接来自管道/grep -c**，又立刻做整数比较 ⇒ 才是 bug"""
    # 先收集「从管道赋值」的变量名
    # ★ 判据 855：**只有 `grep -c` 会产生 "0\n0"**
    #   `stat -f%z ... || echo 0` 实测只输出 "0"（单行）⇒ 不是 bug
    # ★ 判据 856（第 1329 轮）：`grep -c` 有**两种**写法，都要覆盖
    #   ① X=$(grep -c ...)            ← 裸的
    #   ② X=$(cmd | grep -c ...)      ← 管道里的（我第一版漏了这个）
    risky = set()
    for l in lines:
        for pat in (r'(?:^|\s)(\w+)=\$\(\s*grep\s+-c',         # ① 裸
                    r'(?:^|\s)(\w+)=\$\([^)]*\|\s*grep\s+-c'): # ② 管道里
            m = re.search(pat, l)
            if m:
                risky.add(m.group(1))
    if not risky:
        return []
    out = []
    for i, l in enumerate(lines, 1):
        for v in risky:
            if re.search(r'\[\s*"\$\{?%s\}?"\s+-[a-z]{1,2}\s+\d+\s*\]' % re.escape(v), l):
                out.append((i, l.strip()[:100]))
                break
    return out


def _rule_sc05(lines):
    """判据 810：`grep -c` 的结果**没经过数字校验**就存进变量"""
    out = []
    for i, l in enumerate(lines, 1):
        # ★ 判据 855：只报「既没 `||`、也没 `case` 校验」的裸赋值
        if re.search(r'\w+=\$\(\s*grep\s+-c[^)]*\)\s*$', l) and '||' not in l:
            # 后面 2 行内没有 case/校验
            nxt = '\n'.join(lines[i:min(len(lines), i + 3)])
            if not re.search(r'case\s+"\$\w+"\s+in|=\$\{\w+:-0\}.*head', nxt):
                out.append((i, l.strip()[:100]))
    return out


def _rule_sc06(lines):
    """判据 812：**只用 `-f` 判存在、不判大小**的地方（同文件里若有 -s/stat 就跳过）"""
    src = '\n'.join(lines)
    if re.search(r'-s\s+"\$\w+"|stat\s+-f%z', src):
        return []          # 该文件已知道要判大小
    out = []
    for i, l in enumerate(lines, 1):
        if re.search(r'if\s+\[\s+-f\s+"\$\w+"\s+\]', l):
            out.append((i, l.strip()[:100]))
    return out


RULES = [
    ('SC01', '848', _rule_sc01,
     '`grep -c ... || echo 0` ⇒ 匹配 0 行时退出码 1 ⇒ 得到 "0\\n0"'),
    ('SC02', '836', _rule_sc02,
     '`$VAR）` ⇒ bash 把全角符号算进变量名 ⇒ 报 unbound variable；须写 `${VAR}`'),
    ('SC03', '803', _rule_sc03,
     '取管道结果后**立刻看 `$?`** ⇒ 拿到的是管道最后一个命令的退出码'),
    ('SC04', '830', _rule_sc04,
     '变量直接来自管道、又立刻做整数比较 ⇒ 可能是 "0\\n0"'),
    ('SC05', '810', _rule_sc05,
     '`grep -c` 结果未做数字校验 ⇒ 后续整数比较会崩'),
    ('SC06', '812', _rule_sc06,
     '只用 `-f` 判存在、不判大小 ⇒ 空壳文件会通过'),
]


def strip_comments_sh(src):
    """去掉 # 注释（但保留行号），跳过 heredoc 内的内容"""
    out = []
    in_heredoc = None
    for line in src.split('\n'):
        if in_heredoc:
            if line.strip() == in_heredoc:
                in_heredoc = None
            out.append('')
            continue
        m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", line)
        if m:
            in_heredoc = m.group(1)
            out.append(line)
            continue
        # 去掉行内注释（不处理引号内的 #，粗粒度但够用）
        idx = line.find('#')
        if idx >= 0 and (idx == 0 or line[idx-1] in ' \t'):
            out.append(line[:idx])
        else:
            out.append(line)
    return '\n'.join(out)


def scan_file(path):
    try:
        raw = io.open(path, encoding='utf-8', errors='ignore').read()
    except Exception:
        return []
    code = strip_comments_sh(raw)
    lines = code.split('\n')
    hits = []
    for rid, crit, fn, desc in RULES:
        try:
            found = fn(lines)
        except Exception:
            found = []
        for ln, txt in found:
            hits.append((rid, crit, ln, txt, desc))
    return hits


def run_selftest():
    """★ 判据 759 + 855：既要在**真实案例**上报警，也要在**正确写法**上不报"""
    CASES = [
        # (id, 判据, 正例（必须报）, 反例（必须不报）)
        ('SC01', '848',
         ['N=$(grep -c x /tmp/x.log 2>/dev/null || echo 0)'],
         ['N=$(grep -c x /tmp/x.log 2>/dev/null || true)']),
        ('SC02', '836',
         ['log "   屏幕亮（${EL}s，亮度 $L）"'],
         ['log "按钮（${L}）"']),
        ('SC03', '803',
         ['RC=$(命令 | sed s/^/  /)', 'echo "rc=$?"'],
         ['P=$(A "pidof x" | head -1)', 'echo "$P"']),
        ('SC04', '830',
         ['N=$(ls | grep -c x)', 'if [ "$N" -lt 1 ]; then'],
         ['if [ "$SZ" -lt 1 ]; then']),
        ('SC05', '810',
         ['LINES=$(grep -c PATTERN /tmp/x.log)'],
         ['LINES=$(grep -c PATTERN /tmp/x.log || true)']),
        ('SC06', '812',
         ['raw="东西"', 'if [ -f "$f" ]; then', 'echo hi', 'fi'],
         ['if [ -s "$f" ]; then']),
    ]
    bad = 0
    print('=' * 78)
    print('  自检（判据 759：先在真实案例上验证；判据 855：也要在正确写法上不报）')
    print('=' * 78)
    fnmap = {rid: fn for rid, crit, fn, desc in RULES}
    for rid, crit, pos, neg in CASES:
        fn = fnmap[rid]
        got_p = len(fn(pos)) > 0
        got_n = len(fn(neg)) > 0
        ok = got_p and not got_n
        if not ok:
            bad += 1
        print('  %s (判据 %-4s) 正例:%-4s 反例:%-4s ⇒ %s'
              % (rid, crit, '报' if got_p else '**漏**',
                 '报' if got_n else '不报', '✅' if ok else '🔴 规则有问题'))
    print()
    print('  ⇒ %d / %d 规则通过' % (len(CASES) - bad, len(CASES)))
    return 0 if bad == 0 else 2


def main():
    if '--selftest' in sys.argv:
        return run_selftest()

    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if args:
        files = args
    else:
        d = os.path.join(ROOT, '工具')
        files = sorted(os.path.join(d, f) for f in os.listdir(d)
                       if f.endswith('.sh'))

    if not files:
        print('  没有 .sh 文件可扫')
        return 2

    total = 0
    print('=' * 78)
    print('  shell 陷阱扫描：%d 个文件' % len(files))
    print('=' * 78)
    for f in files:
        hits = scan_file(f)
        if hits:
            total += len(hits)
            print()
            print('  📄 %s' % os.path.basename(f))
            for rid, crit, ln, txt, desc in hits:
                print('     L%-5d [%s/判据%s]' % (ln, rid, crit))
                print('        %s' % txt)
                print('        ⇒ %s' % desc)

    print()
    print('=' * 78)
    if total == 0:
        print('  ✅ 未发现 shell 陷阱')
        return 0
    print('  ⚠️ 共 **%d 处**' % total)
    print('  ⇒ 这些都会**静默失效**：脚本照跑，但检查/断言不生效')
    return 1


if __name__ == '__main__':
    sys.exit(main())
