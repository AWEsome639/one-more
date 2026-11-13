#!/bin/bash
# 2026-11-14：**全量 354 款分批扫**
#   背景：`verify_layout.py` 默认只跑「固定 32 款」，不是全库。
#   约束：macOS 自带 bash 3.2 **没有 mapfile**；游戏名带空格 ⇒ 必须用 `--names-file`。
set +u
# ★ 2026-11-14 实测踩到：**脚本自己的路径里有中文（`工具/`）**
#   ⇒ `dirname "$0"` 在没有 UTF-8 locale 的 bash 3.2 里会产出非法字节 ⇒ 整脚本挂掉
#   ⇒ 直接用绝对路径（项目位置固定）
cd "/Users/a0000/dev/One More" || exit 1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
LOG=/tmp/sweep_all.log
: > "$LOG"
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# ★ 2026-11-14：**名字清单自愈** —— `/tmp/all355.txt` 若不存在（重启/清理）就当场从注册表重建
#   （否则脚本会拿空清单跑一场空，今晚就白等了）
if [ ! -s /tmp/all355.txt ]; then
  echo "[$(date +%H:%M:%S)] /tmp/all355.txt 不见了 ⇒ 从 GameRegistry 重建" | tee -a "$LOG"
  python3 - <<'PY' >> "$LOG" 2>&1
import io, re
reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
names = re.findall(r"enName: '([^']+)'", reg)
io.open('/tmp/all355.txt', 'w', encoding='utf-8').write('\n'.join(names) + '\n')
print('重建 %d 个游戏名' % len(names))
PY
fi

TODO=/tmp/todo_all.txt

# ① 生成待办：全库名 − 今天已测
python3 - <<'PY' > /tmp/todo_gen.out 2>&1
import io
done = set()
for ln in io.open('_巡检记录/layout-canonical.tsv', encoding='utf-8'):
    f = ln.rstrip('\n').split('\t')
    if len(f) < 3:
        continue
    if not f[0].startswith('2026-11-14'):
        continue
    if f[2] in ('OK', 'TIGHT', 'OVER', 'NEAR'):
        done.add(f[1])
alln = [l.strip() for l in io.open('/tmp/all355.txt', encoding='utf-8') if l.strip()]
todo = [n for n in alln if n not in done]
io.open('/tmp/todo_all.txt', 'w', encoding='utf-8').write('\n'.join(todo) + '\n')
print('已测 %d, 待测 %d' % (len(done), len(todo)))
PY
cat /tmp/todo_gen.out | tee -a "$LOG"

for round in $(seq 1 24); do
  n=$(wc -l < "$TODO" | tr -d ' ')
  if [ "$n" -eq 0 ]; then say "全部完成"; break; fi

  head -40 "$TODO" > /tmp/batch.txt
  say "第 $round 批：$(wc -l < /tmp/batch.txt | tr -d ' ') 款（剩 $n）"
  python3 工具/verify_layout.py --every 8 --names-file /tmp/batch.txt >> "$LOG" 2>&1

  grep -vxFf /tmp/batch.txt "$TODO" > /tmp/todo_next.txt 2>/dev/null || true
  mv /tmp/todo_next.txt "$TODO"
  say "第 $round 批结束，剩 $(wc -l < "$TODO" | tr -d ' ') 款"

  hm=$(date +%H%M)
  if [ "$hm" -ge 645 ]; then say "到 06:45，收工"; break; fi
done

say "sweep_all 结束"
