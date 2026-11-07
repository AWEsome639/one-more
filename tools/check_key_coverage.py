#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「代码里的 key 在不在字典」检查器（判据 1790 的可执行形式）

★ 为什么需要它（2026-11-08）：
  · a11y 批量补了 43 处，其中 12 个 `this.t('中文','English')` **只写了 zh/en**，
    10 种非英语语言下读屏说明会退英文 —— 「德语环境听到英文动作说明」。
  · `check_i18n.py` 只查「字典里的条目完不完整」，**不查「代码里的 key 在不在字典」**，
    所以这类缺口它能一直绿着。
  ⇒ 判据 1790：新增 `this.t(zh, en)` 调用时，必须同步往 `EXTRA` 补该 key 的 10 语言译文。

★ 检查什么
  扫 `this.t / this.tn / L / L2 / TG / TG2 / TG4` 调用的**第一个字符串字面量** X：
  X 既不在 `EXTRA`、也不在 `GameI18n.DICT` ⇒ **报缺字典**。

★ 白名单（避免把不是 key 的字符串当缺口）
  ① X 不含中文（纯英文/数字/符号，如 `'One More'` / `'+'` / `'—'` / `'{0} XP'`）⇒ 不查
  ② `this.t('X','Y')` 且 **X == Y**（key 自带译文 = 英文原文）⇒ 不查
  ③ 参数不是字面量（变量/表达式/拼接）⇒ 不查
  ④ 字典自身文件（I18n.ets / GameI18n.ets）不扫

★ 机读行：`缺字典：N 处`（供 check_assertions.sh grep）；退出码 0/1/2。
用法：
  python3 tools/check_key_coverage.py               # 全仓扫（用当前字典）
  python3 tools/check_key_coverage.py --verbose     # 附白名单统计
  python3 tools/check_key_coverage.py --self-test   # 先验尺子
  python3 tools/check_key_coverage.py --i18n /tmp/I18n_old.ets   # 换一份字典（回归/自检用）
  python3 tools/check_key_coverage.py --strict      # 按调用类型分别查（t/L→EXTRA，TG→DICT）
"""
import argparse
import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 复用 check_dup_symbol 里的字典解析器（它带「check_i18n 改名就切兜底」的保护）
try:
    from check_dup_symbol import parse_extra, parse_dict_literal, _key_text, mask_comments
except Exception as e:                                    # pragma: no cover
    print('  🔴 无法复用 tools/check_dup_symbol.py 的解析器：%s' % e)
    sys.exit(2)

# 只有**含汉字**的字面量才需要字典；纯标点/占位符/数字/英文一律白名单
#   （`'，'` / `'：'` / `'{p}%（{a}/{b}）'` 这类是格式碎片，不算缺译）
CJK = re.compile(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]')

# 调用点：this.t / this.tn / L / L2 / TG / TG2 / TG4（TG 系列只查 DICT）
CALL_RE = re.compile(r'(?<![\w$.])(this\.tn|this\.t|L2|L|TG4|TG2|TG)\s*\(')
# 需要 EXTRA 的：this.t / this.tn / L / L2；只查 DICT 的：TG 系列
EXTRA_FNS = {'this.t', 'this.tn', 'L', 'L2'}
DICT_FNS = {'TG', 'TG2', 'TG4'}

SKIP_FILES = {'I18n.ets', 'GameI18n.ets'}

SCAN_DIRS = ['components', 'pages', 'games', 'core']
STATS = {'files': 0, 'calls': 0, 'cn_literals': 0, 'skip_en': 0, 'skip_same': 0,
         'skip_expr': 0, 'skip_other': 0}


def load_dicts(i18n_path, game_path):
    src = io.open(i18n_path, encoding='utf-8').read()
    extra, _dup, n_extra, _stray = parse_extra(src)
    src2 = io.open(game_path, encoding='utf-8').read()
    entries, _stray2 = parse_dict_literal(src2, 'const DICT:')
    game = {}
    if entries:
        for raw, row in entries:
            game.setdefault(_key_text(raw), {}).update(row)
    return extra, game, n_extra, len(game)


def match_paren(masked, open_idx):
    depth = 0
    for i in range(open_idx, len(masked)):
        c = masked[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def split_top_args(arg):
    """按顶层逗号切参数（跳过字符串/括号/花括号）。"""
    out, cur, depth, i, n = [], '', 0, 0, len(arg)
    while i < n:
        c = arg[i]
        if c in '\'"`':
            q = c
            cur += c
            i += 1
            while i < n:
                cur += arg[i]
                if arg[i] == '\\':
                    i += 1
                    if i < n:
                        cur += arg[i]
                    i += 1
                    continue
                if arg[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        if c == ',' and depth <= 0:
            out.append(cur)
            cur = ''
        else:
            cur += c
        i += 1
    out.append(cur)
    return out


def literal_value(s):
    """整段必须**恰好是一个字符串字面量**（拼接/表达式 ⇒ None）。

    ★ 用正则 `^'...'$` 贪心会把 `'是「' + it.category + '」类'` 也当成一个字面量
      （首尾都是引号）—— 实测踩过，必须逐字符解析并在闭合引号后要求空串。
    """
    t = s.strip()
    if not t or t[0] not in '\'"':
        return None
    q = t[0]
    i = 1
    out = []
    while i < len(t):
        c = t[i]
        if c == '\\':
            out.append(t[i:i + 2])
            i += 2
            continue
        if c == q:
            if t[i + 1:].strip() == '':
                return ''.join(out)
            return None
        out.append(c)
        i += 1
    return None


def unescape(s):
    return (s.replace('\\n', '\n').replace('\\t', '\t')
             .replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\'))


def scan_file(path, extra, game, strict=False):
    rel = os.path.relpath(path, ROOT)
    src = io.open(path, encoding='utf-8').read()
    masked = mask_comments(src)          # 注释抹掉、字符串保留（要读字面量）
    hits = []
    STATS['files'] += 1
    for mt in CALL_RE.finditer(masked):
        fn = mt.group(1)
        op = mt.end() - 1
        cl = match_paren(masked, op)
        if cl < 0:
            continue
        STATS['calls'] += 1
        args = split_top_args(masked[op + 1:cl])
        if not args:
            continue
        key = literal_value(args[0])
        if key is None:
            STATS['skip_expr'] += 1
            continue
        if not CJK.search(key):
            STATS['skip_en'] += 1
            continue
        STATS['cn_literals'] += 1
        # 白名单②：this.t('X','Y') 且 X == Y（key 自带译文）
        if fn in EXTRA_FNS and len(args) >= 2:
            en = literal_value(args[1])
            if en is not None and en == key:
                STATS['skip_same'] += 1
                continue
        k2 = unescape(key)
        in_extra = (key in extra) or (k2 in extra)
        in_dict = (key in game) or (k2 in game)
        if strict:
            need_extra = fn in EXTRA_FNS
            ok = in_extra if need_extra else in_dict
            miss = (not ok)
        else:
            miss = not (in_extra or in_dict)
        if not miss:
            continue
        ln = masked.count('\n', 0, mt.start()) + 1
        hits.append({'file': rel, 'line': ln, 'fn': fn, 'key': key,
                     'in_extra': in_extra, 'in_dict': in_dict,
                     'code': src.split('\n')[ln - 1].strip()[:110]})
    return hits


# ──────────────────────────── 自检 ────────────────────────────
SELF_POS = '''
@Component
struct Demo {
  build() {
    Text(this.t('新加的说明文字', 'New hint'))
    Text(TG('没有进字典的提示'))
  }
}
'''
SELF_NEG = '''
@Component
struct Demo {
  build() {
    Text(this.t('打开 ', 'Open '))                 // 缺字典但…
    Text(this.t('One More', 'One More'))           // 纯英文 ⇒ 白名单
    Text(this.t('Skip', 'Skip'))                   // 纯英文 ⇒ 白名单
    Text(this.t('确定', '确定'))                    // X == Y ⇒ 白名单
    Text(this.t(someVar, 'En'))                    // 表达式 ⇒ 白名单
    Text(this.t('+', '+'))                         // 纯符号 ⇒ 白名单
  }
}
'''


def self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix='keycov_')
    ok = []
    try:
        extra = {'确定': {'ja': 'OK'}, '打开 ': {'ja': '開く'}}
        game = {'没有进字典的提示': {'ja': 'ヒント'}}
        p1 = os.path.join(d, 'pos.ets')
        io.open(p1, 'w', encoding='utf-8').write(SELF_POS)
        h1 = scan_file(p1, extra, game)
        keys1 = sorted(x['key'] for x in h1)
        ok.append(('正例必须命中（缺 EXTRA / 缺 DICT）', keys1 == ['新加的说明文字'], '命中 %s' % keys1))
        p2 = os.path.join(d, 'neg.ets')
        io.open(p2, 'w', encoding='utf-8').write(SELF_NEG)
        h2 = scan_file(p2, extra, game)
        ok.append(('负例必须 0 命中（英文/同文/变量/符号/已存在）', len(h2) == 0,
                   '%d 处 %s' % (len(h2), [x['key'] for x in h2])))
    finally:
        try:
            for f in os.listdir(d):
                os.remove(os.path.join(d, f))
            os.rmdir(d)
        except OSError:
            pass
    for name, passed, got in ok:
        print('     %s %s（%s）' % ('✅' if passed else '❌', name, got))
    return all(p for _, p, _ in ok)


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('--self-test', action='store_true')
    ap.add_argument('--verbose', action='store_true')
    ap.add_argument('--strict', action='store_true')
    ap.add_argument('--i18n', default=os.path.join(ETS, 'core/I18n.ets'))
    ap.add_argument('--gamei18n', default=os.path.join(ETS, 'core/GameI18n.ets'))
    a = ap.parse_args()

    if a.self_test:
        print('  ═══ 自检（反证尺子）═══')
        return 0 if self_test() else 2

    try:
        extra, game, n_extra, n_game = load_dicts(a.i18n, a.gamei18n)
    except Exception as e:
        print('  🔴 字典解析失败：%s' % e)
        return 2
    probe = [k for k in ('确定', '取消', '返回') if k in extra]
    if n_extra < 300 or n_game < 3000 or not probe:
        print('  🔴 字典解析异常（EXTRA %d / DICT %d / 抽查 %d）⇒ 先修解析器再量'
              % (n_extra, n_game, len(probe)))
        return 2

    files = []
    for d in SCAN_DIRS:
        for p in sorted(glob.glob(os.path.join(ETS, d, '*.ets'))):
            if os.path.basename(p) in SKIP_FILES:
                continue
            files.append(p)
    if not files:
        print('  🔴 没找到 .ets 文件')
        return 2

    hits = []
    for p in files:
        hits += scan_file(p, extra, game, a.strict)

    print('  ═══ key 覆盖检查（判据 1790）═══')
    print('  字典：EXTRA %d 条 ｜ GameI18n %d 条' % (n_extra, n_game))
    print('  扫描 .ets：%d 个 ｜ i18n 调用 %d 处 ｜ 含中文字面量 %d 个'
          % (STATS['files'], STATS['calls'], STATS['cn_literals']))
    if a.verbose:
        print('  白名单：纯英文/数字/符号 %d ｜ X==Y %d ｜ 表达式 %d'
              % (STATS['skip_en'], STATS['skip_same'], STATS['skip_expr']))
    if hits:
        print('\n  ❌ 代码里的 key 不在字典 %d 处：' % len(hits))
        for h in hits:
            why = ('EXTRA 缺' if not h['in_extra'] else '') + \
                  (' / DICT 缺' if not h['in_dict'] else '')
            print('     · %s:%d  [%s]  「%s」   (%s)'
                  % (h['file'], h['line'], h['fn'], h['key'], why.strip(' /')))
            print('         %s' % h['code'])
        print('\n  修法：往 EXTRA / GameI18n.DICT 补这个 key 的 10 语言译文（判据 1790）。')
        print('  缺字典：%d 处' % len(hits))
        return 1
    print('\n  ✅ 代码里的中文 key 都在字典里')
    print('  缺字典：0 处')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
