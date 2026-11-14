#!/bin/bash
# 明早第一条命令：把「今晚数据到了没有、还剩多少旧图、该改什么」一次打出来。
#
# 为什么需要它：
#   明早要看的数分散在台账 / stale_shots / triage / morning_report 四个地方，
#   逐个跑容易漏。这个脚本只**读**、不改任何东西。
#
# 用法：bash 工具/morning_check.sh
set -u
cd "/Users/a0000/dev/One More" || exit 1
T=$(date '+%Y-%m-%d')
Y=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d yesterday '+%Y-%m-%d')

echo "════════ 明早检查（$(date '+%F %T')）════════"
echo
echo "── ① 今晚跑出多少新行（期望 215–221；为 0 先查 HAP 与 BASELINE，别先查模拟器）──"
# ★ 2026-11-14 修：原来用「时间戳以今天/昨天开头」计数 ⇒ 会把今天白天的测量也数进去
#   （试跑时明明没有今晚数据却报 433 行）⇒ 改成与**跑批前的基线行数**比。
BASE_FILE=/tmp/onemore_ledger_baseline
CUR=$(wc -l < _巡检记录/layout-canonical.tsv 2>/dev/null | tr -d ' ')
if [ -f "${BASE_FILE}" ]; then
  B=$(cat "${BASE_FILE}" | tr -d ' ')
  N=$((CUR - B))
  echo "   台账行数：${CUR}｜跑批前基线：${B}｜**新增：${N}**"
else
  echo "   台账行数：${CUR}｜⚠️ 没有基线文件 ${BASE_FILE}"
  echo "   ⇒ 无法算「新增」；用「时间戳 ≥ 今晚 00:00」人工核："
  N=$(grep -cE "^${T}T(0[0-5]|06:[0-3])" _巡检记录/layout-canonical.tsv 2>/dev/null || echo 0)
  echo "      粗估（今天 00:00–06:39 的行）：${N}"
fi
if [ ! -f "${BASE_FILE}" ]; then
  # ★ 没有基线 ⇒ **不能判**「有没有新数据」（粗估会把白天测量算进来）
  echo "   ⚠️ 没有基线 ⇒ **无法判断今晚有没有跑**；先看 /tmp/onemore_nightrun.log 的时间戳"
elif [ "${N}" -le 0 ]; then
  echo "   ❌ 新增 0 行 ⇒ 今晚的跑批没成功。看 /tmp/onemore_nightrun.log 与 /tmp/sweep_all.log"
else
  echo "   ✅ 新增 ${N} 行"
fi
echo
echo "── ② 新行里 cov= / board= 有值吗（今晚首次产出）──"
grep -E "^(${T}|${Y})" _巡检记录/layout-canonical.tsv 2>/dev/null \
  | grep -oE 'cov=-?[0-9]+' | sort | uniq -c | head -4 | sed 's/^/   cov /'
grep -E "^(${T}|${Y})" _巡检记录/layout-canonical.tsv 2>/dev/null \
  | grep -oE 'board=[^ ]+' | sort | uniq -c | head -4 | sed 's/^/   board /'
echo "   ⚠️ 若这两个都空 ⇒ 字段没产出，回查 shot_game.py 的格式串"
echo
echo "── ③ 还剩多少张过期截图（今晚能刷新约 43 张）──"
python3 工具/stale_shots.py --count 2>/dev/null | sed 's/^/   /'
echo
echo "── ④ 分档：哪些款现在要修（A 档 blk≥24、无 blk 数据单列）──"
python3 工具/triage.py 2>/dev/null | grep -E "^【|判据 2003|判据 2007" | head -8 | sed 's/^/   /'
echo
echo "── ⑤ morning_report 六节（含 ②·五 盘面实测高、④ 遮挡）──"
python3 工具/morning_report.py 2>/dev/null | grep -E "^== |✅ 没有|⚠️ 台账里" | head -12 | sed 's/^/   /'
echo
echo "── ⑥ A 批补丁是否仍命中（10 处；2048 若已改会报「不含旧串」属正常）──"
bash 工具/apply_a_batch.sh --dry 2>/dev/null | tail -2 | sed 's/^/   /'
echo
echo "════════ 结论怎么读 ════════"
cat <<'TIP'
   · ③ 的「过期」从 37 降到 14 左右 ⇒ 今晚刷新正常（注：2026-11-14 修正过 stale_shots 两个 bug，原报 69 偏大一倍）
   · ④ 的 A 档就是明天要改的；「无 blk 数据」那几款要重测、不能当干净
   · ⑤ 的 ②·五 若还报「没有合格的 board=」⇒ board= 字段没产出
   · ⑥ 全命中 ⇒ 可以按决策表 ④ 逐步试点
   · 任何一步是「没数据」而不是「没有」⇒ 先解决数据，别改代码
TIP
