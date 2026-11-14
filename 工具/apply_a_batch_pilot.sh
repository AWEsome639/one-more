#!/bin/bash
# A 批（网格 ≤5 的 15 款）**试点**：先只改 `2048` 一款，验证「下限 240 → 200」这个机制。
#
# 为什么先只改一款（判据：一次只改一处并量一个数）：
#   A 批 15 款都是 `Math.max(240, Bp.height - 360)`。
#   在 533vp 屏上 `Bp.height - 360 = 173`，而下限 240 赢了 ⇒ 盘面 240vp。
#   改成 200 ⇒ 盘面 200vp ⇒ 省 40vp = 120px 垂直空间。
#   ⚠️ 但「省了 120px 之后 blk 会不会降、格子会不会太小」没人量过 ⇒ 先量一款。
#
# 用法：
#   bash 工具/apply_a_batch_pilot.sh --dry    # 只验证命中，不写
#   bash 工具/apply_a_batch_pilot.sh          # 真改（之后必须编译 + 装包 + 单测）
#
# 单测验收（改完编译装包后）：
#   python3 工具/shot_game.py "2048"
#   ⇒ blk 应下降；board= 的 W/H 应约 600px（200vp）
#   ⇒ 若 blk 没降或出现新问题：停下，不要批量
set -u
cd "/Users/a0000/dev/One More" || exit 1
DRY=0; [ "${1:-}" = '--dry' ] && DRY=1

F='entry/src/main/ets/games/G2048.ets'
L=817
OLD='Math.max(240, Bp.height - 360)'
NEW='Math.max(200, Bp.height - 360)'

python3 - "$F" "$L" "$OLD" "$NEW" "$DRY" <<'PY'
import io, sys
f, ln, old, new, dry = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5] == '1'
L = io.open(f, encoding='utf-8').read().split('\n')
if ln > len(L):
    print('❌ 第 %d 行超出文件（共 %d 行）' % (ln, len(L))); sys.exit(1)
line = L[ln-1]
if old not in line:
    print('❌ 第 %d 行不含预期串，实际内容：' % ln); print('   ' + line.strip()[:120]); sys.exit(1)
if line.count(old) != 1:
    print('❌ 第 %d 行出现 %d 次（应为 1）' % (ln, line.count(old))); sys.exit(1)
if dry:
    print('✅ 命中（dry，不写）：L%d  %s  →  %s' % (ln, old, new)); sys.exit(0)
L[ln-1] = line.replace(old, new, 1)
io.open(f, 'w', encoding='utf-8').write('\n'.join(L))
print('✅ 已改：%s L%d  %s → %s' % (f, ln, old, new))
print('⚠️ 接下来必须：编译 → 装包 → python3 工具/shot_game.py "2048"')
PY
