# 第 ② 项开工包索引

| 文件 | 作用 | 状态 |
|---|---|---|
| `MindSporeLite推理骨架.ets.txt` | 加载/推理/NPU 两套 Context/采样占位 | 草稿 |
| `QwenBpeTokenizer.ets.txt` | Qwen2 BPE 分词器 | 草稿，今晚校准 |
| `gen_tokenizer_vectors.py` | 生成 16 条「标准答案」向量 | 可用 |
| `如何对拍.md` | 今晚 10 分钟对拍步骤 | 可用 |
| `分词器验收方案.md` | 三条验收（逐 id / 边界 / 往返）| 可用 |
| `今晚验收清单.md` | 七步流程 + 每步验收物 | 可用 |
| `tone-pack.schema.json` | 语气包 schema | 可用 |
| `tone-pack-prompt.md` | prompt 模板 + 3 段范例 + 批量纪律 | 可用 |
| `导出355款元信息.py` | 从注册表导出 id+中文名 | **实测 355 款** |
| `games-sample.json` | 前 20 款样本（可复算证据）| 可用 |
| `tone-baseline.json` | 355 款语气基线逐款明细 | **已测** |

**⇒ 今晚顺序：分词器校到 16/16 → 接现成 .ms 跑通 predict → 量 token/s。**
