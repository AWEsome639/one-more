"""提示代码静态审计：确认每个 computeHint 都有返回、没有明显的越界/除零风险。

★ 2026-10-27 建立。为什么要"花括号配平"提取函数体：
  用正则 `private computeHint\\(\\)[\\s\\S]{0,1500}?\\n  \\}` 会误报 18 个
  （提示函数里有嵌套括号）⇒ 必须按 {} 配平找真正的结尾。
"""
import io
import os
import re
import sys

G = 'entry/src/main/ets/games'


def extract_fn(lines, header_re, maxlen=160):
    for i, l in enumerate(lines):
        if re.search(header_re, l) and '{' in l:
            depth = 0
            for j in range(i, min(i + maxlen, len(lines))):
                depth += lines[j].count('{') - lines[j].count('}')
                if depth <= 0 and j > i:
                    return '\n'.join(lines[i:j + 1])
    return None


def main():
    issues = []
    count = 0
    for fn in sorted(os.listdir(G)):
        if not fn.endswith('.ets') or '.bak' in fn:
            continue
        s = io.open(os.path.join(G, fn), encoding='utf-8').read()
        if 'private computeHint' not in s:
            continue
        count += 1
        body = extract_fn(s.split('\n'), r'private computeHint\(\)')
        if not body:
            issues.append((fn, '提取失败'))
            continue
        if 'Hint.make' not in body and 'Hint.none' not in body:
            issues.append((fn, '没有 Hint.make / Hint.none'))
        if re.search(r'this\.\w+\[\s*this\.\w+\s*\+\s*1\s*\]', body) and 'length' not in body:
            issues.append((fn, '下标 +1 可能越界且没查 length'))
        if re.search(r'/\s*[A-Za-z_][\w.]*', body) and 'if (' not in body and '?' not in body:
            issues.append((fn, '除法没判 0'))
    print("  ✅ 审计 %d 个提示函数（花括号配平提取）" % count)
    print("  ⚠️ 可疑 %d 处：" % len(issues))
    for f, r in issues[:20]:
        print("     %-30s %s" % (f, r))
    if not issues:
        print("     （无）")
    return 1 if issues else 0


if __name__ == '__main__':
    sys.exit(main())
