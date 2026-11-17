#!/bin/bash
# 在「isShort == false」（大屏）那条路上逐款测量 —— 扫那 334 款未测分支。
#
# 前置（都已验证）：
#   · 折叠屏实例 onemore_fold（Mate X5, 2224x2496@500dpi ≈ 711x798vp ⇒ isShort()==false）
#   · shot_game.py 已支持 ONEMORE_SCREEN 与「按类型找 TextInput」
#
# 规矩（判据 2814/2818）：
#   · 一次只开一台；开之前先把在跑的优雅停掉
#   · 收尾只用 Emulator -stop，绝不 pkill
#   · 判断设备状态问 hdc list targets，不数进程名
#
# 结果写到 `_巡检记录/layout-nonshort.tsv`（独立文件，不污染手机台账）
# 可续跑：已成功测过的款默认跳过（--force 重测全部）
#
# 用法：
#   bash 工具/sweep_nonshort.sh            # 续跑
#   bash 工具/sweep_nonshort.sh --force    # 全部重测
#   bash 工具/sweep_nonshort.sh --dry      # 只列待测

set -u
cd "$(dirname "$0")/.." || exit 1
EMU='/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator'
HC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
INST='onemore_fold'
SCREEN='2224x2496'
# ★ 2026-11-16（判据 2824）：**溢出阈值必须跟屏幕走**。
#   工具默认 GAME_BOTTOM=1516/SLACK=60（=1576）是手机口径；折叠屏屏高 2496 ⇒
#   若不传，1600–2496 之间的正常节点全被算成溢出（实测三款都报 blk=10~±5000-7000px，手工 dump 却是 0）。
export SHOT_SCREEN_H=2496
export SHOT_GAME_BOTTOM=2412   # 2496 - 84（手机上 1600-84=1516）
export SHOT_PX_PER_VP=3.125
# ★ 2026-11-16（判据 2827）：**不写手机台账**。名字叫手机台账就该只收手机数据；
#   折叠屏数据写进去会让 triage.py 把它当成手机的数（实测已污染 65 行，已清洗）。
export SHOT_NO_LEDGER=1
export SHOT_BUDGET_S=420   # 大屏每步更慢，预算从 260s 放宽到 420s（手机不受影响）    # 500dpi / 160（手机 480/160=3）
OUT='_巡检记录/layout-nonshort.tsv'
LOG='/tmp/sweep_nonshort.log'
FORCE=0
DRY=0
LIMIT=0
args=("$@")
for idx in "${!args[@]}"; do
  a="${args[$idx]}"
  if [ "$a" = "--limit" ]; then LIMIT="${args[$((idx+1))]:-0}"; fi
  case "$a" in
    --force) FORCE=1 ;;
    --dry) DRY=1 ;;
    --limit) : ;;
  esac
done

say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# ① 目标名单：取手机台账里**测成功过**的款（那 355 款的英文名）
python3 - <<'PY' > /tmp/ns_names.txt
import io, re
seen = []
ok = set()
for ln in io.open('_巡检记录/layout-canonical.tsv', encoding='utf-8', errors='replace'):
    p = ln.rstrip('\n').split('\t')
    if len(p) >= 3 and p[1] and p[1] != 'game':
        if p[2] == 'OK':
            ok.add(p[1])
        if p[1] not in seen:
            seen.append(p[1])
names = [n for n in seen if n in ok and '__' not in n and n.strip()]   # ★ 排除 __selftest__ 这类测试条目
for n in names:
    print(n)
PY

# ② 已测过的（续跑用）
DONE=/tmp/ns_done.txt
: > "$DONE"
# ★ 2026-11-16（判据 2828）：**只跳过「成功」的**。
#   原来 `cut -f2` 把所有出现过的款都当已完成 ⇒ DUMP_FAIL/WRONG_GAME 的款永远不会重试（实测 22% 失败）。
if [ "$FORCE" -eq 0 ] && [ -f "$OUT" ]; then
  awk -F'\t' '$3 == "OK" {print $2}' "$OUT" | sort -u > "$DONE"
fi

# ③ 待测清单
: > /tmp/ns_todo.txt
while IFS= read -r n; do
  [ -z "$n" ] && continue
  grep -qxF "$n" "$DONE" 2>/dev/null || echo "$n" >> /tmp/ns_todo.txt
done < /tmp/ns_names.txt
# ★ --limit N：只做前 N 款（验证用）
if [ "${LIMIT:-0}" -gt 0 ] 2>/dev/null; then head -"$LIMIT" /tmp/ns_todo.txt > /tmp/ns_todo2.txt && mv /tmp/ns_todo2.txt /tmp/ns_todo.txt; fi
TOTAL=$(wc -l < /tmp/ns_todo.txt | tr -d ' ')
say "目标 $TOTAL 款（总名单 $(wc -l < /tmp/ns_names.txt | tr -d ' ')，已做 $(wc -l < "$DONE" | tr -d ' ')）"
[ "$TOTAL" -eq 0 ] && { say "没有待测项"; exit 0; }
if [ "$DRY" -eq 1 ]; then
  head -8 /tmp/ns_todo.txt | sed 's/^/  /'
  say "--dry：只列清单，不碰设备"; exit 0
fi

# ④ 一次只开一台
if pgrep -f "Emulator -start" >/dev/null 2>&1; then
  for n in $(pgrep -fl "Emulator -start" | sed -n 's/.*-start \([A-Za-z0-9_]*\).*/\1/p' | sort -u); do
    say "先优雅停掉在跑的：$n"; "$EMU" -stop "$n" >/dev/null 2>&1
  done
  sleep 6
fi

cleanup() {
  say "→ 优雅停止 $INST"
  "$EMU" -stop "$INST" >/dev/null 2>&1
  sleep 4
  say "→ 设备状态: $("$HC" list targets 2>/dev/null | head -1)"
}
trap cleanup EXIT INT TERM

# ⑤ 启动 + 装包
echo y > /tmp/yes.txt
say "启动 $INST ($SCREEN)"
(nohup "$EMU" -start "$INST" < /tmp/yes.txt > /tmp/ns_boot.log 2>&1 &)
for i in $(seq 1 40); do
  n=$("$HC" list targets 2>/dev/null | grep -cE '^[0-9A-Za-z]')
  [ "$n" -ge 1 ] && { say "设备就绪 $((i*10))s"; break; }
  sleep 10
done
sleep 22
say "屏幕: $("$HC" shell "hidumper -s RenderService -a screen" 2>/dev/null | grep -oE 'render resolution=[0-9]+x[0-9]+' | head -1)"
say "装包"
timeout 300 "$HC" install -r entry/build/default/outputs/default/entry-default-signed.hap 2>&1 | tail -1 | tee -a "$LOG"
sleep 3

[ -f "$OUT" ] || printf 'ts\tgame\tstatus\twall_s\tlowest\tlowh\tblk\n' > "$OUT"

# ⑥ 逐款测
i=0
while IFS= read -r g; do
  [ -z "$g" ] && continue
  i=$((i+1))
  say "[$i/$TOTAL] $g"
  line=$(ONEMORE_SCREEN="$SCREEN" timeout 300 python3 工具/shot_game.py "$g" 2>&1 | tail -1)
  st=$(echo "$line" | awk -F'\t' '{print $2}')
  wall=$(echo "$line" | awk -F'\t' '{print $4}')
  # ★ 2026-11-16（判据 2825）：**必须记 lowest 的高度**。
  #   大屏缺陷的信号是「lowest 被切成几 px」（如 Mental Mapping 被切到 8px），
  #   而不是 blk的像素数（阈值修正后只剩 24px、看着像没事）。
  #   只记文字会把这个信号丢掉 ⇒ 整轮跑批白跑。
  low=$(echo "$line" | sed -n "s/.*lowest='\([^']*\)'.*/\1/p" | cut -c1-30)
  lowh=$(echo "$line" | python3 -c "
import sys, re
ln = sys.stdin.read()
m = re.search(r\"lowest='.*?'\s*\[(\d+),(\d+)\]\[(\d+),(\d+)\]\", ln)
print((int(m.group(4)) - int(m.group(2))) if m else -1)
" 2>/dev/null)
  blk=$(echo "$line" | sed -n 's/.*blk=\([0-9]*\/\)\([0-9]*\)px.*/\1\2/p' | head -1)
  # ★ 2026-11-17（判据 2842）：**备注不能丢**。shot_game.py 会打印
  #   「title %r not found; first texts=[...]」这类诊断，而原来只取前 7 列 ⇒ 28 个 WRONG_GAME 在台账里全是空白。
  note=$(echo "$line" | cut -f5- | cut -c1-120)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$g" "${st:-?}" "${wall:-?}" "$low" "${lowh:--1}" "${blk:-?}" >> "$OUT" "$note"
  printf '[%s] %s %s lowh=%s blk=%s\n' "$(date +%H:%M:%S)" "$g" "${st:-?}" "${lowh:--1}" "${blk:-?}" >> "$LOG"
done < /tmp/ns_todo.txt

say "跑批结束：本轮 $i 款"
