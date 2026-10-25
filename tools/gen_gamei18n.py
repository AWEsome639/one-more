# -*- coding: utf-8 -*-
"""生成 core/GameI18n.ets —— 354 款游戏内部文案的中英对照字典"""
import io, json

M = {
 "重开":"Restart","再来一局":"Play Again","得分":"Score","答对":"Correct","答对 ":"Correct ",
 " 题":"","已通关 🎉":"Cleared 🎉","第 ":"No. ","🎉 通关：":"🎉 Cleared: ","💤 结束：":"💤 Over: ",
 "题号":"Question","剩余":"Left","步数":"Moves","🎉 答对 ":"🎉 Correct ","🎉 通关 ":"🎉 Cleared ",
 "💤 结束 ":"💤 Over "," 个":""," 格":" cells","再来一局 🎉":"Play Again 🎉","再试一次":"Try Again",
 " 次":""," 步":" moves","用时":"Time","，通关！":", cleared!"," 秒":"s"," 关":" levels",
 "已结束":"Finished","生命":"Lives","失误":"Mistakes","轮次":"Round","⏰ 时间到，答对 ":"⏰ Time up. Correct: ",
 "得分 ":"Score ","😵 只答对 ":"😵 Only ","结束":"End","，差 ":", off by ","关卡":"Level",
 "进度":"Progress","目标":"Goal"," 条命":" lives","❌ 应该是 ":"❌ Should be ",
 "步数用尽，重开一题吧":"Out of moves — starting a new puzzle","已取消选择":"Selection cleared",
 "　答对 ":"  correct ","步数 ":"Moves ","还差 ":"Still ","答错":"Wrong"," 通关":" cleared",
 "🎉 通关！":"🎉 Cleared!","重新开始":"Start Over","换一题":"New Puzzle","已填":"Filled",
 "提交":"Submit","✅ 第 ":"✅ No. ","阿拉伯语":"Arabic","长度":"Length","题":"Puzzle","阶段":"Stage",
 "❌ 错了，扣 ":"❌ Wrong, -"," 题，通关！剩 ":" done! ","💤 本局结束：":"💤 Round over: ",
 "重开一题":"New puzzle","题号 ":"Question ","命中":"Hits","铅笔":"Pencil","暂停":"Pause",
 "提示":"Hint","苹果":"Apple","🎉 已通关":"🎉 Cleared"," 个字母":" letters","　分 ":"  pts ",
 "花园":"Garden","冬天":"Winter","桥":"Bridge","题 ":" ","共 ":"of "," 分":" pts","清空":"Clear",
 "老虎":"Tiger","平均":"Average","错误":"Errors","通关 🎉":"Cleared 🎉","左":"Left","右":"Right",
 "　失误 ":"  mistakes ","确认":"Confirm","试次":"Tries","❌ 第 ":"❌ No. ","本局结束":"Round over",
 " 次，这一局没通关":", this round was not cleared","放弃":"Give up","已放弃这一局":"Round abandoned",
 "河流":"River"," 块":" pcs","已走 ":"Moved ","香蕉":"Banana","红":"Red","蓝":"Blue","绿":"Green",
 " 与 ":" and ","记住这 ":"Remember these ","状态":"Status","，还剩 ":", ",
 "记忆":"Memory","汉语":"Chinese","印地语":"Hindi"," 轮":" rounds"," 个）":""," 个词":" words",
 "开始":"Start","　步 ":"  moves "," 列":" cols","轮次 ":"Round ","黑格":"Black cells"," 点":"",
 " 下":"","选中 ":"Selected ","已用步数":"Moves used","步数用尽，本局失败":"Out of moves — round lost",
 "点":"pt"," 题，答对 ≥":", correct ≥",
}

lines = ['''/**
 * 354 款游戏内部文案的中英对照（自动生成，勿手改）
 *
 * 生成器：tools/gen_gamei18n.py
 *
 * 为什么用"字典 + 查表"而不是逐文件改文案：
 *   354 个游戏文件里有 4,389 条不同的中文字符串 —— 逐条改是 4,389 次编辑，
 *   而查表只需要把 `'中文'` 换成 `G('中文')`，**文案逻辑一行不动**。
 *
 * 覆盖范围：**出现 ≥5 次的 120 条**（占全部出现次数的 31%）——
 *   这批是每个游戏都会用到的通用标签（重开/得分/答对/步数/剩余…），
 *   翻好它们，英文模式下游戏内就不会满屏中文。
 *   长尾（只出现 1–4 次的 4,269 条）多数是各游戏特有的说明句，暂保留中文。
 */

import { I18n } from './I18n';

/** 中文原文 → 英文 */
const DICT: Record<string, string> = {
''']
for k, v in M.items():
    lines.append("  " + json.dumps(k, ensure_ascii=False) + ": " + json.dumps(v, ensure_ascii=False) + ",\n")
lines.append('''};

/**
 * 取当前语言下的文案。
 * 中文模式直接返回原文（零开销）；英文模式查表，查不到就退回原文。
 */
export function G(zh: string): string {
  if (!I18n.isEN()) {
    return zh;
  }
  const hit: string = DICT[zh];
  return hit === undefined ? zh : hit;
}
''')
io.open('/Users/a0000/dev/One More/entry/src/main/ets/core/GameI18n.ets', 'w', encoding='utf-8').write(''.join(lines))
print(f'  ✅ core/GameI18n.ets 已生成（{len(M)} 条对照）')
