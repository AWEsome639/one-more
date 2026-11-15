#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
第 ② 项 · 分词器「同一把尺子」的尺子本体。

用途：今晚下载 Qwen2.5-0.5B-Instruct 后，跑本脚本生成标准答案向量
      （token id 序列），再用 ArkTS 的 QwenBpeTokenizer 对同一批句子跑一遍，
      逐 id 比对 —— 完全一致才算分词器正确。

用法：
    pip install transformers
    python3 gen_tokenizer_vectors.py            # 生成 tokenizer_vectors.json

⚠️ 不要用「我看输出像中文」来判断对错（判据 2026-11-15：自查器测的必须是门真正打分的量）。
"""
import json
import sys

CASES = [
    # (标签, 文本)
    ("空串", ""),
    ("纯中文", "你好世界"),
    ("中文带标点", "嗯，今天做点什么？"),
    ("纯英文", "One More"),
    ("中英混排", "One More 有 355 款游戏"),
    ("前导空格", "  hello"),
    ("连续空格", "a    b"),
    ("换行", "第一行\n第二行"),
    ("单个数字", "7"),
    ("多位数字", "355"),
    ("小数", "3.14"),
    ("emoji", "🐳"),
    ("emoji带变体", "❤️"),
    ("组合emoji", "👩‍💻"),
    ("零宽与标点", "a—b…c"),
    ("长文本", "把 One More 做成世界顶尖的 355 款小游戏合集。" * 20),
]


def main() -> int:
    try:
        from transformers import AutoTokenizer
    except ImportError:
        print("❌ 未安装 transformers：pip install transformers", file=sys.stderr)
        return 1

    name = "Qwen/Qwen2.5-0.5B-Instruct"
    print(f"加载 {name} 的 tokenizer …", file=sys.stderr)
    tk = AutoTokenizer.from_pretrained(name)

    out = {"model": name, "cases": []}
    for label, text in CASES:
        ids = tk.encode(text, add_special_tokens=False)
        # 往返：decode 应还原原文（空格/换行敏感，故逐条记录是否一致）
        back = tk.decode(ids, skip_special_tokens=True)
        out["cases"].append({
            "label": label,
            "text": text,
            "ids": ids,
            "n": len(ids),
            "roundtrip_ok": back == text,
            "roundtrip_text": back,
        })
        print(f"  {label:<10} n={len(ids):<5} roundtrip={'OK' if back == text else 'DIFF'}")

    with open("tokenizer_vectors.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("\n✅ 已写 tokenizer_vectors.json（%d 条）" % len(out["cases"]))
    bad = [c["label"] for c in out["cases"] if not c["roundtrip_ok"]]
    if bad:
        print("⚠️ 往返不完全一致的用例（解码器也会丢空格/换行，属正常）：%s" % ", ".join(bad))
    return 0


if __name__ == "__main__":
    sys.exit(main())
