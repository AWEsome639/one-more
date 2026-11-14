#!/bin/bash
# 2026-11-14：**全量 354 款分批扫**
#   背景：`verify_layout.py` 默认只跑「固定 32 款」，不是全库。
#   约束：macOS 自带 bash 3.2 **没有 mapfile**；游戏名带空格 ⇒ 必须用 `--names-file`。
# 用法：
#   bash 工具/sweep_all.sh          # 真跑（会起模拟器）
#   bash 工具/sweep_all.sh --dry    # **只生成待办并打印，不碰设备**（白天安全测试用）
#
# ⚠️ 2026-11-14 教训：这个脚本**没有 dry-run 之前，白天测试它会真起模拟器**（我犯过）。
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
# ★ 2026-11-14：**改过的款排最前** —— 今晚要验那 32 处改动，
#   如果按文件名顺序跑，7 小时只能跑 ~180 款，改过的款可能排在后面 ⇒ 白等一晚。
#   ⇒ 用 git 找出「最近改动过的 .ets」→ 映射到英文名 → 提到队首。
import subprocess as _sp
try:
    # ⚠️ 2026-11-14 修正：原来用 `HEAD~40..HEAD`（按提交数）⇒ **我今天提交太多，
    #   早期改动掉出了 40 个提交的窗口** ⇒ 优先级从 27 款掉到 21 款，**16 款改动没被优先**。
    #   ⇒ 改成**按时间**（`--since`），与提交数无关。
    out = _sp.check_output(['git', 'log', '--since=2026-11-13 22:00', '--name-only', '--pretty=format:'],
                           stderr=_sp.DEVNULL).decode('utf-8', 'replace')
    changed_files = [l.strip() for l in out.split('\n') if l.strip().startswith('entry/src/main/ets/games/')]
    reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
    import re as _re
    id2en = dict(_re.findall(r"id: '([^']+)'[^}]*?enName: '([^']+)'", reg))
    prio = []
    for f in changed_files:
        src = io.open(f, encoding='utf-8').read()
        m = _re.search(r"(?:id|gameId)\s*[:=]\s*'([a-z0-9_]+)'", src)
        if m and m.group(1) in id2en:
            en = id2en[m.group(1)]
            if en not in prio:
                prio.append(en)
    # ⚠️ 2026-11-14 关键修正：**改过的款即使「今天已测」，也必须重测**
    #   因为它们今天的测量是**改动生效之前**的（`00:05-06:45` 那轮用的是旧 HAP）
    #   ⇒ 若按「已测就跳过」处理，今晚恰恰会**跳过我要验的那 32 款**。
    # ★ 2026-11-14（判据 2003）：**已知「缺数据」的款排第二优先**
    #   这 6 款的旧行没有 `blk=` 字段（`11-12`/`11-13` 测的），而 `triage.py` 原来把
    #   「缺数据」当成「blk=0 干净」⇒ 它们一直没被发现要重测。
    #   ⇒ 现在把它们顶到最前面，**即使今晚跑不完 245 款，这几个缺口也先填上**。
    KNOWN_GAP = [
        'Block Stacking Physics', 'Polyomino Tiling', 'Frequency Tap',
        'Counting Sheep', 'Object Displacement',
    ]
    gaps = [g for g in KNOWN_GAP if g in todo]
    if gaps:
        todo = gaps + [n for n in todo if n not in gaps]
        print('已知缺数据 %d 款顶到最前（判据 2003）' % len(gaps))
    prio = [n for n in prio if n not in gaps]

    if prio:
        todo = prio + [n for n in todo if n not in prio]
        print('优先 %d 款（改过的排最前，且强制重测）' % len(prio))
except Exception as e:
    print('（优先排序跳过: %s）' % e)

io.open('/tmp/todo_all.txt', 'w', encoding='utf-8').write('\n'.join(todo) + '\n')
print('已测 %d, 待测 %d' % (len(done), len(todo)))
PY
cat /tmp/todo_gen.out | tee -a "$LOG"

# ★ 2026-11-14：**写入「可复算基线」快照** —— 目标要求「一次跑完、可复算的正式基线」，
#   而「可复算」的前提是**能追溯是哪个 HAP / 哪个提交 / 哪台实例跑出来的**。
#   ⇒ 每次开跑前落一份 md，把环境与构建指纹固定下来。
SNAP="_巡检记录/基线快照-$(date +%Y%m%d-%H%M).md"
{
  echo "# 基线快照 $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo '| 项 | 值 |'
  echo '|---|---|'
  echo "| git HEAD | \`$(git rev-parse --short HEAD)\` |"
  echo "| 工作区脏 | $(git status --porcelain | wc -l | tr -d ' ') 个文件 |"
  echo "| HAP | \`$(ls -l entry/build/default/outputs/default/entry-default-signed.hap 2>/dev/null | awk '{print $5}')\` bytes |"
  echo "| HAP sha256 | \`$(shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap 2>/dev/null | cut -c1-16)…\` |"
  echo "| 实例 | onemore7（\`2560x1600@480\` ⇒ \`853x533 vp\`）|"
  echo "| 待办 | $(wc -l < "$TODO" 2>/dev/null | tr -d ' ') 款 |"
  echo "| 工具版本 | \`shot_game.py\` $(shasum -a 256 工具/shot_game.py | cut -c1-8)… \`sweep_all.sh\` $(shasum -a 256 工具/sweep_all.sh | cut -c1-8)… |"
  echo
  echo "**⇒ 复算方法**：同一 HAP + 同一实例 ⇒ 跑 \`bash 工具/sweep_all.sh\`；"
  echo "差异只应来自环境失败（\`NO_CARD\`/\`NOT_HOME\`），那些要重测。"
} > "$SNAP" 2>/dev/null
say "基线快照 → $SNAP"

# ★ 2026-11-14：**`--dry` 只生成待办，绝不碰设备**
#   教训：这脚本没有 dry-run 之前，我为了「验证 todo 生成」跑了一次它，
#   结果它真的去起了模拟器（他当时醒着）。白天测试必须走这条分支。
if [ "${1:-}" = "--dry" ]; then
  echo "===== --dry：前 40 款（不会起设备）=====" | tee -a "$LOG"
  head -40 "$TODO" | nl -ba | sed 's/^/  /' | tee -a "$LOG"
  echo "===== --dry 结束，共 $(wc -l < "$TODO" | tr -d ' ') 款 =====" | tee -a "$LOG"
  exit 0
fi


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
