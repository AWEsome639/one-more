#!/usr/bin/env python3
"""把 UI 位置里「没包 TG」的中文纯字面量自动包进 TG()。

依据 verify_i18n.py 的**词法扫描器**（区分字符串/注释/代码），
所以不会误改注释、不会跨字符串边界。

用法：
  python3 工具/wrap_tg.py --dry     # 只列要改的（不写文件）
  python3 工具/wrap_tg.py --apply   # 真的改
"""
import io, os, sys, re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
spec = importlib.util.spec_from_file_location('vi', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'verify_i18n.py'))
vi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vi)

GAMES_DIR = 'entry/src/main/ets/games'
UI_KW = ('Text', 'Button', 'accessibilityText', 'label')


def edits_for(src):
    """返回 [(start, end, new_text)] —— 每个要包 TG 的中文串。"""
    masked_list = list(src)
    for kind, s, e, _ in vi.scan(src):
        if kind in ('line_comment', 'block_comment'):
            for k in range(s, e):
                if masked_list[k] != '\n':
                    masked_list[k] = ' '
    masked = ''.join(masked_list)

    stack, last_ident, out = [], '', []
    for kind, s, e, val in vi.scan(masked):
        if kind == 'code':
            pos = 0
            for ch in val:
                if ch == '(':
                    stack.append(type('F', (), {'name': last_ident})())
                elif ch == ')':
                    if stack:
                        stack.pop()
                pos += 1
            idm = re.search(r'([A-Za-z_$][\w$]*)\s*$', val)
            if idm:
                last_ident = idm.group(1)
        elif kind == 'str':
            if not vi.CJK.search(val):
                continue
            # ★ 判「已包 TG」用**源码前缀**最可靠（括号栈在 ArkTS 的复杂表达式里易失效）：
            #   看字符串前面是不是紧跟 `TG(` / `TG2(` / `TG4(`。
            if re.search(r'\bTG[24]?\s*\(\s*$', src[max(0, s - 12):s]):
                continue
            # 只看 UI 调用括号内的
            win = masked[max(0, s - 500):s]
            k = None
            for mm in re.finditer(r'\b(Text|Button|accessibilityText|label)\s*\(', win):
                k = mm
            if k is None:
                continue
            tail = win[k.end():]
            if not (1 + tail.count('(') - tail.count(')') > 0):
                continue
            # 取原始源码里的字符串片段（保留原引号）
            raw = src[s:e]
            if not (raw.startswith("'") and raw.endswith("'")):
                continue
            out.append((s, e, 'TG(' + raw + ')'))
    return out


def dict_keys():
    """读字典现有键（只包裹"翻译已就绪"的词，避免 ③ 项变红）。"""
    src = io.open('entry/src/main/ets/core/GameI18n.ets', encoding='utf-8').read()
    return set(re.findall(r'^\s*"(.+?)"\s*:\s*\{', src, re.M))


def main():
    apply = '--apply' in sys.argv
    only_ready = '--ready-only' in sys.argv
    ready = dict_keys() if only_ready else None
    total = 0
    for f in sorted(os.listdir(GAMES_DIR)):
        if not f.endswith('.ets') or '.bak' in f:
            continue
        p = os.path.join(GAMES_DIR, f)
        src = io.open(p, encoding='utf-8').read()
        ed = edits_for(src)
        if only_ready:
            ed = [x for x in ed if src[x[0] + 1:x[1] - 1] in ready]
        if not ed:
            continue
        if apply:
            for s, e, new in sorted(ed, key=lambda x: -x[0]):
                src = src[:s] + new + src[e:]
            io.open(p, 'w', encoding='utf-8').write(src)
        total += len(ed)
        print('  %-32s %d 处' % (f[:-4], len(ed)))
    print('  ⇒ 合计 %d 处 %s' % (total, '（已写入）' if apply else '（dry-run）'))


if __name__ == '__main__':
    main()
