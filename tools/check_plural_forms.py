#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「复数形式缺失」检查器（判据：tn() 必须给俄语/阿语复数形式）

★ 背景（2026-11-08）：code-hunter 发现 **36 个 `tn()` 调用里 22 个没传 f1/f2/f5** ⇒
  俄语下 n=1 显示「**1 игр**」（应为「1 игра」），而 n=1 在**新玩家身上高频**。

★ TN 的真实签名（本工具会从 `core/I18n.ets` 现读，签名变了直接报错，不猜）：
      export function TN(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string)
  · f1 = 单数（俄语 1 / 阿语 1）｜f2 = 少数（俄语 2-4 / 阿语 2-10）｜f5 = 多数（俄语 0、5+ / 阿语 11+）
  · ★ 只有**俄语**会用这三个参数；其它语言靠 `L(zh, en)` 查 **EXTRA** 字典。
    ⇒ 「字典里有没有 key」必须查 **EXTRA**（不是 GameI18n.DICT —— 那是 TG 的，TN 不读它）。

★ 判据（两档）
  ① 硬失败：`tn()` 模板含 `{n}`，但**没传 f1/f2/f5**（参数只有 3 个）。
     · 另外把「**包装器不透传**」也算硬失败：形如 `@Builder chip(zh, en, n) { … this.tn(zh, en, n) … }`
       的包装器只转 3 参 ⇒ 它的所有调用点都丢复数（StatsTab.chip 就是）。
  ② 警告：模板（中文原文）在 **EXTRA** 里没有 key ⇒ 非俄语语言查不到译文、退英文。
     （与「传没传 f」分开统计：传了 f 也救不了缺 key。）

★ 白名单
  · 模板不含 `{n}` 的（不需要复数）
  · `n` 是字面量 `1` 的（`tn('{n} 局', …, 1)`）—— 单独计数，不报

★ 输出：机读行 `复数缺失：N 处` / `复数警告：N 处`；退出码 0 = 无硬失败 ｜ 1 = 有 ｜ 2 = 解析/自检失败
  （警告不影响退出码；`--strict` 时警告也返回 1）

用法：python3 tools/check_plural_forms.py [--verbose] [--self-test] [--strict]
"""
import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from check_dup_symbol import mask_comments, parse_extra, parse_dict_literal, _key_text
except Exception as e:                                  # pragma: no cover
    print('  🔴 无法复用 tools/check_dup_symbol.py 的解析器：%s' % e)
    sys.exit(2)

I18N = os.path.join(ETS, 'core/I18n.ets')
GAME = os.path.join(ETS, 'core/GameI18n.ets')
SCAN_DIRS = ['components', 'pages', 'games', 'core']
TN_SIG = re.compile(r'export\s+function\s+TN\s*\(([^)]*)\)')
CALL = re.compile(r'(?<![\w$.])(?:this\.tn|TN)\s*\(')
LIT = re.compile(r"^\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*$")
NUM1 = re.compile(r'^\s*1\s*$')
# 俄语里不需要随数词变格的缩写（"5 мин" 的 мин 就是不变格）
INVARIANT = {'мин', 'ч', 'с', 'сек', 'шт', 'км', 'м', 'см', 'кг', 'г', 'мл', 'л', 'руб', 'xp', 'xp.'}


def ru_needs_forms(ru):
    """看俄语译文：`{n}` 后面还有没有**需要变格的名词**。

    · `Пройдено игр: {n}`（名词前置+冒号）⇒ 不需要（False）
    · `Лучший {n}` / `Было {n}`（数词在结尾）⇒ 不需要
    · `{n} мин`（不变格缩写）⇒ 不需要
    · `{n} игра`（数词后跟可变化名词）⇒ 需要（True）
    · 没有 ru 译文 ⇒ 保守判 True（不能证明安全就别放行）
    """
    if not ru:
        return True
    if '{n}' not in ru:
        return False            # 译文里没 {n}，没有复数问题
    tail = ru[ru.find('{n}') + 3:].strip()
    if tail == '':
        return False            # 数词在结尾
    if tail[0] in '—-,.;:!?)]':  # 数词后直接标点/破折号
        return False
    m = re.match(r'[A-Za-zА-Яа-яЁё]+', tail)
    if m and m.group(0).lower() in INVARIANT:
        return False
    return True


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


def split_args(arg):
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
                elif arg[i] == q:
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


def parse_tn_signature(src):
    m = TN_SIG.search(src)
    if not m:
        return None, None
    raw = m.group(1)
    params = []
    for p in split_args(raw):
        p = p.strip()
        if not p:
            continue
        pm = re.match(r'([A-Za-z_$][\w$]*)\s*\??\s*:\s*([^=]+)', p)
        if pm:
            params.append((pm.group(1), pm.group(2).strip(), '?' in p.split(':')[0]))
        else:
            params.append((p, '', '?' in p))
    return raw.strip(), params


def scan_file(path, extra, verbose=False):
    rel = os.path.relpath(path, ROOT)
    if os.path.basename(path) == 'I18n.ets' and os.path.dirname(path) == os.path.join(ETS, 'core'):
        return {'hard': [], 'warn': [], 'skip': {'n1': [], 'nofn': [], 'passthrough': [], 'ru_safe': []}}
    src = io.open(path, encoding='utf-8').read()
    mk = mask_comments(src)
    lines = mk.split('\n')
    raw_lines = src.split('\n')
    found = {'hard': [], 'warn': [], 'skip': {'n1': [], 'nofn': [], 'passthrough': [], 'ru_safe': []}}
    for m in CALL.finditer(mk):
        op = m.end() - 1
        cl = match_paren(mk, op)
        if cl < 0:
            continue
        args = split_args(mk[op + 1:cl])
        if not args:
            continue
        ln = mk.count('\n', 0, m.start()) + 1
        code = raw_lines[ln - 1].strip()[:110]
        first = LIT.match(args[0])
        if first is None:
            # 非字面量模板：区分「透传包装器（6 参）」与「只转 3 参的包装器」
            if len(args) >= 6:
                found['skip']['passthrough'].append({'file': rel, 'line': ln, 'code': code})
            else:
                found['hard'].append({'file': rel, 'line': ln, 'kind': 'wrapper',
                                      'tpl': '（模板是变量：包装器没透传 f1/f2/f5，调用点全丢复数）',
                                      'code': code})
            continue
        tpl = first.group(1)
        if '{n}' not in tpl:
            found['skip']['nofn'].append({'file': rel, 'line': ln, 'tpl': tpl})
            continue
        narg = args[2].strip() if len(args) >= 3 else ''
        if NUM1.match(narg):
            found['skip']['n1'].append({'file': rel, 'line': ln, 'tpl': tpl})
            continue
        has_forms = len(args) >= 6
        if not has_forms:
            row = extra.get(tpl, {})
            ru = row.get('ru', '') if isinstance(row, dict) else ''
            if not ru_needs_forms(ru):
                # ★ 白名单（复核过的 12 处都属这类）：俄语译文里 {n} 后面没有需要变格的名词
                #   （名词前置+冒号 / 数词在结尾 / мин 这类不变格缩写）⇒ 传 f1/f2/f5 反而多余。
                found['skip'].setdefault('ru_safe', []).append(
                    {'file': rel, 'line': ln, 'tpl': tpl, 'ru': ru})
            else:
                found['hard'].append({'file': rel, 'line': ln, 'kind': 'missing-f',
                                      'tpl': tpl, 'n': narg, 'code': code, 'ru': ru})
        # ② 字典（TN 真正读的 EXTRA）里有没有这个中文模板
        if tpl not in extra:
            found['warn'].append({'file': rel, 'line': ln, 'tpl': tpl,
                                  'has_forms': has_forms, 'code': code})
    return found


# ──────────────────────────── 自检 ────────────────────────────
SELF_SRC = '''
@Component
struct Demo {
  @Builder
  chip(zh: string, en: string, n: number) {
    Text(this.tn(zh, en, n))                     // 包装器只转 3 参 ⇒ 硬失败
  }
  build() {
    Text(this.tn('{n} 天', '{n} days', n))       // ru=「Дней: {n}」⇒ 白名单（不需要变格）
    Text(this.tn('{n} 周', '{n} weeks', n))      // ① 硬失败（ru=「{n} недель」需要变格）
    Text(this.tn('{n} 天', '{n} days', n, '1 день', '2 дня', '5 дней'))  // 安全（传了 f）
    Text(this.tn('{n} 天', '{n} days', 1))       // 白名单：n 固定 1
    Text(this.tn('天数', 'days', n))              // 白名单：模板不含 {n}
    Text(this.tn('{n} 张', '{n} cards', n, '1 карта', '2 карты', '5 карт'))  // ② 警告（模板缺字典）
  }
}
'''


def self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix='plural_')
    try:
        p = os.path.join(d, 'demo.ets')
        io.open(p, 'w', encoding='utf-8').write(SELF_SRC)
        # {n} 天 ⇒ ru 是「名词前置+冒号」= 不需要变格；{n} 周 ⇒ ru 数词后跟名词 = 需要变格
        # {n} 张 ⇒ 故意不放字典，用来测 ② 警告
        extra = {'{n} 天': {'ja': 'x', 'ru': 'Дней: {n}'},
                 '{n} 周': {'ru': '{n} недель'}}
        f = scan_file(p, extra)
        ok = [
            ('① 硬失败：应 2 处（{n} 天 被 ru 白名单、{n} 周 仍报 + 包装器）', len(f['hard']) == 2,
             '%d 处 %s' % (len(f['hard']), [x['kind'] for x in f['hard']])),
            ('② 警告：应 1 处（{n} 张 缺字典）', len(f['warn']) == 1,
             '%d 处 %s' % (len(f['warn']), [x['tpl'] for x in f['warn']])),
            ('白名单：n=1 / 不含 {n} / ru 不变格 各 1 处',
             len(f['skip']['n1']) == 1 and len(f['skip']['nofn']) == 1 and len(f['skip']['ru_safe']) == 1,
             'n1=%d nofn=%d ru_safe=%d' % (len(f['skip']['n1']), len(f['skip']['nofn']), len(f['skip']['ru_safe']))),
        ]
    finally:
        try:
            for x in os.listdir(d):
                os.remove(os.path.join(d, x))
            os.rmdir(d)
        except OSError:
            pass
    for name, passed, got in ok:
        print('     %s %s（实际 %s）' % ('✅' if passed else '❌', name, got))
    return all(p for _, p, _ in ok)


def main():
    if '--self-test' in sys.argv:
        print('  ═══ 自检（反证尺子）═══')
        return 0 if self_test() else 2
    verbose = '--verbose' in sys.argv
    strict = '--strict' in sys.argv

    i18n_src = io.open(I18N, encoding='utf-8').read()
    raw_sig, params = parse_tn_signature(i18n_src)
    if not params or len(params) < 6:
        print('  🔴 读不到 TN 签名（期望 6 参：zh, en, n, f1?, f2?, f5?）⇒ 先核对 core/I18n.ets')
        return 2
    names = [p[0] for p in params]
    if names[:3] != ['zh', 'en', 'n'] or names[3:6] != ['f1', 'f2', 'f5']:
        print('  🔴 TN 签名变了：%s ⇒ 判据要重算' % raw_sig)
        return 2

    extra, _dup, n_extra, _stray = parse_extra(i18n_src)
    game_src = io.open(GAME, encoding='utf-8').read()
    entries, _ = parse_dict_literal(game_src, 'const DICT:')
    dict_n = len(entries) if entries else 0
    if n_extra < 300 or dict_n < 3000:
        print('  🔴 字典解析异常（EXTRA %d / DICT %d）' % (n_extra, dict_n))
        return 2

    files = []
    for d in SCAN_DIRS:
        files += sorted(glob.glob(os.path.join(ETS, d, '*.ets')))

    hard, warn, skip = [], [], {'n1': [], 'nofn': [], 'passthrough': [], 'ru_safe': []}
    for p in files:
        f = scan_file(p, extra, verbose)
        hard += f['hard']
        warn += f['warn']
        for k in skip:
            skip[k] += f['skip'][k]

    print('  ═══ 复数形式检查（TN 签名现读）═══')
    print('  签名：TN(%s)' % raw_sig)
    print('  字典：EXTRA %d 条 ｜ GameI18n.DICT %d 条（TN→L→EXTRA，② 只查 EXTRA）' % (n_extra, dict_n))
    print('\n  ① 硬失败（模板含 {n} 但没传 f1/f2/f5）：%d 处' % len(hard))
    for h in hard[: (200 if verbose else 10)]:
        if h['kind'] == 'wrapper':
            print('     · %s:%d  [包装器]  %s' % (h['file'], h['line'], h['code']))
        else:
            print('     · %s:%d  模板「%s」  n=%s' % (h['file'], h['line'], h['tpl'], h.get('n', '?')))
    if len(hard) > 10 and not verbose:
        print('     …（共 %d 处，--verbose 看全部）' % len(hard))

    print('\n  ② 警告（模板在 EXTRA 缺 key ⇒ 非俄语退英文）：%d 处' % len(warn))
    for w in warn[: (200 if verbose else 10)]:
        print('     · %s:%d  「%s」%s' % (w['file'], w['line'], w['tpl'],
                                         '（传了 f 也救不了）' if w['has_forms'] else ''))
    if len(warn) > 10 and not verbose:
        print('     …（共 %d 处，--verbose 看全部）' % len(warn))

    print('\n  白名单：俄语不需要变格的 %d 处 ｜ n 固定为 1 的 %d 处 ｜ 模板不含 {n} 的 %d 处 ｜ 透传包装器（6 参）%d 处'
          % (len(skip['ru_safe']), len(skip['n1']), len(skip['nofn']), len(skip['passthrough'])))
    if verbose:
        for it in skip['ru_safe']:
            print('     ✓ 俄语不变格：%s:%d 「%s」 ru=%r'
                  % (it['file'], it['line'], it['tpl'], it['ru']))
    print('\n  复数缺失：%d 处' % len(hard))
    print('  复数警告：%d 处' % len(warn))
    if hard:
        return 1
    if warn and strict:
        return 1
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        print('  🔴 检查器自身异常（退出码 2）', file=sys.stderr)
        sys.exit(2)
