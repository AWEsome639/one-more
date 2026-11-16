# -*- coding: utf-8 -*-
"""在 Mac 上验证「Qwen2 BPE 算法」是否正确 —— 用真实 tokenizer.json 跑 16 条标准答案。

为什么先做这一步（判据 2793 的延伸）：
  把 ArkTS 版直接编译上设备再对拍，一次失败的代价是「编译 + 装包 + 启动 + 看日志」。
  而算法层面的对错，**在 Mac 上几十毫秒就能验**；
  Mac 上都不一致的算法，搬到 ArkTS 上不可能自动变一致。

用法: python3 工具/bpe_crosscheck.py
"""
import io, json, os, sys, glob
try:
    import regex as re   # 支持 \p{L} 等 Unicode 属性
    HAVE_REGEX = True
except ImportError:
    import re
    HAVE_REGEX = False

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TK = os.path.expanduser(
    '~/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct/'
    'snapshots/7ae557604adf67be50417f59c2c2f167def9a775/tokenizer.json')
VEC = os.path.join(ROOT, '_巡检记录/第2项-骨架/tokenizer_vectors.json')


def bytes_to_unicode():
    """GPT-2 的 bytes_to_unicode：让任意字节都能变成可打印字符参与合并。"""
    bs = list(range(ord('!'), ord('~') + 1)) + \
         list(range(ord('¡'), ord('¬') + 1)) + \
         list(range(ord('®'), ord('ÿ') + 1))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1
    return {b: chr(c) for b, c in zip(bs, cs)}


def main():
    for p in (TK, VEC):
        if not os.path.exists(p):
            print('❌ 缺文件:', p); return 1
    tk = json.load(io.open(TK, encoding='utf-8'))
    vec = json.load(io.open(VEC, encoding='utf-8'))
    model = tk['model']
    vocab = model['vocab']
    merges = model['merges']
    # merges 可能是 ["a b", ...] 或 [[a,b], ...]
    pairs = []
    for m in merges:
        if isinstance(m, str):
            a, b = m.split(' ', 1)
        else:
            a, b = m[0], m[1]
        pairs.append((a, b))
    rank = {p: i for i, p in enumerate(pairs)}
    b2u = bytes_to_unicode()
    unk = vocab.get('<|endoftext|>', 0)

    # 预切分正则：优先从 tokenizer.json 读，读不到才用 Qwen2 的已知值
    pat = None
    pt = tk.get('pre_tokenizer') or {}
    def find_pattern(o):
        nonlocal pat
        if isinstance(o, dict):
            if o.get('type') == 'Split' and isinstance(o.get('pattern'), dict):
                p = o['pattern'].get('Regex')
                if p: pat = p
            for v in o.values(): find_pattern(v)
        elif isinstance(o, list):
            for v in o: find_pattern(v)
    find_pattern(pt)
    if not pat:
        pat = (r"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\w]?\w+|[^\s\w]+|\s+(?!\S)|\s+")
    print('预切分正则来源:', ('tokenizer.json' if pt else '内置默认'), '| regex 模块:', HAVE_REGEX)
    print('vocab %d 条、merges %d 条' % (len(vocab), len(pairs)))

    def bpe(token):
        word = list(token)
        while len(word) > 1:
            best = None; bi = -1
            for i in range(len(word) - 1):
                r = rank.get((word[i], word[i + 1]))
                if r is not None and (best is None or r < best):
                    best = r; bi = i
            if best is None: break
            word[bi:bi + 2] = [word[bi] + word[bi + 1]]
        return word

    def encode(text):
        ids = []
        for m in re.finditer(pat, text):
            piece = m.group(0)
            s = ''.join(b2u[b] for b in piece.encode('utf-8'))
            for w in bpe(s):
                ids.append(vocab.get(w, unk))
        return ids

    ok = 0; bad = []
    cases = vec if isinstance(vec, list) else vec.get('cases', [])
    for c in cases:
        # ★ 判据 2811：**字段名得对照生成器实际写的什么**（这里是 label）
        name = c.get('label') or c.get('name') or '?'
        text = c['text']
        # ★ 判据 2811：`x.get(k) or y` 会把**空数组/空串/零**当成缺失，
        #   而空串的正确答案恰恰就是 `[]` ⇒ 必须用 `k in d` 判存在。
        exp = c['ids'] if 'ids' in c else c.get('token_ids')
        got = encode(text)
        if not isinstance(exp, list):
            print('  %-14s 无期望 ids，跳过' % name); continue
        if got == exp:
            ok += 1
            print('  %-14s ✅ %d ids' % (name, len(got)))
        else:
            bad.append((name, exp, got))
            print('  %-14s ❌ 期望 %d、实际 %d' % (name, len(exp), len(got)))
    print()
    print('结果: %d/%d 一致' % (ok, ok + len(bad)))
    for name, exp, got in bad[:3]:
        i = next((k for k in range(min(len(exp), len(got))) if exp[k] != got[k]), 0)
        print('  %s 首个分歧 @%d 期望 %r 实际 %r' % (name, i, exp[i:i+3], got[i:i+3]))
    return 0 if not bad else 2


if __name__ == '__main__':
    sys.exit(main())
