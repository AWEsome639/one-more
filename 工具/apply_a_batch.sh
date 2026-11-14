#!/bin/bash
# A 批：下限 `240` 且可玩网格 ≤5 的 10 款，把 `Math.max(240, Bp.height - 360)` 改成 `Math.max(200, …)`。
#
# 依据（2026-11-14 按代码事实扫全库得出，见 _巡检记录/★★★★★★权威清单-下限大于173的29处）：
#   533vp 屏上 `Bp.height - 360 = 173`，而下限 240 赢了 ⇒ 盘面 240vp。
#   改 200 ⇒ 盘面 200vp ⇒ 省 40vp = 120px 垂直空间，格子仍大：
#     4×4 → 50vp、5×5 → 40vp（GGo9 的 9×9 只用 19.2vp 且是全库参考实现）。
#
# ⚠️ 纪律：先只改 `2048` 一款、编译装包、单测通过，再批量。
#   单款试点请用 工具/apply_a_batch_pilot.sh（只这一款）。
#
# 用法：
#   bash 工具/apply_a_batch.sh --dry              # 只验 10 处全部命中，不写
#   bash 工具/apply_a_batch.sh --only 2048        # 只改一款（真写）
#   bash 工具/apply_a_batch.sh                    # 改全部 10 款（真写）
#   bash 工具/apply_a_batch.sh --only 2048 --dry  # 组合
#
# 改完之后必须：编译 → 装包 → 对每款跑 shot_game.py 看 blk 与 board=
set -u
cd "/Users/a0000/dev/One More" || exit 1
DRY=0; ONLY=''
# ★ 2026-11-14 修：原来用 `for a in "$@"` + 内部 `shift`，参数顺序为 `--dry --only X` 时
#   `$1` 已被 shift 掉前一个参数、取到的是 `--only` 本身 ⇒ ONLY="--only" ⇒ 没有任何一款匹配
#   ⇒ 报「成功 0、跳过 N」但退出码 0 ⇒ **静默什么都不做**（与 BASELINE='' 同类的问题）。
#   改用 while + shift 逐个消费，并对「--only 缺值」直接报错。
while [ $# -gt 0 ]; do
  case "$1" in
    --dry) DRY=1; shift ;;
    --only)
      shift
      ONLY="${1:-}"
      if [ -z "$ONLY" ] || [ "${ONLY#--}" != "$ONLY" ]; then
        echo "❌ --only 后面要跟游戏名（如 --only 2048）"; exit 2
      fi
      shift ;;
    *) echo "❌ 未知参数：$1（支持 --dry / --only <游戏>）"; exit 2 ;;
  esac
done


# 游戏|文件|行号|旧串|新串   （10 款，按权威清单；行号与旧串都已核实）
SPEC='
2048|G2048.ets|817|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
Memory|GMemory.ets|438|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
Dominosa|GDominosa.ets|677|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
ModuloPath|GModuloPath.ets|429|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
NoriNori|GNoriNori.ets|655|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
PathIntersect|GPathIntersect.ets|825|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
Pipes|GPipes.ets|553|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
Schulte|GSchulte.ets|341|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
Shikaku|GShikaku.ets|777|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
Skyscrapers|GSkyscrapers.ets|749|Math.max(240, Bp.height - 360)|Math.max(200, Bp.height - 360)
'

# ★ 校验 --only 的名字确实在清单里，避免拼错后静默跳过全部
if [ -n "$ONLY" ]; then
  # 名字在每行**行首**（`2048|G2048.ets|…`）⇒ 模式要允许「行首」或「前面的 |」
  echo "$SPEC" | grep -qE "(^|\|)${ONLY}\|" || { echo "❌ --only ${ONLY} 不在 A 批 10 款里"; exit 2; }
fi

ok=0; bad=0; skip=0
while IFS='|' read -r name file ln old new; do
  [ -z "$name" ] && continue
  if [ -n "$ONLY" ] && [ "$name" != "$ONLY" ]; then skip=$((skip+1)); continue; fi
  R=$(python3 - "entry/src/main/ets/games/$file" "$ln" "$old" "$new" "$DRY" <<'PY'
import io, sys
f, ln, old, new, dry = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5] == '1'
L = io.open(f, encoding='utf-8').read().split('\n')
if ln > len(L):
    print('FAIL 行号超出（共 %d 行）' % len(L)); sys.exit(1)
line = L[ln-1]
if old not in line:
    print('FAIL 该行不含旧串，实际：' + line.strip()[:100]); sys.exit(1)
if line.count(old) != 1:
    print('FAIL 旧串出现 %d 次（应 1）' % line.count(old)); sys.exit(1)
if dry:
    print('HIT'); sys.exit(0)
L[ln-1] = line.replace(old, new, 1)
io.open(f, 'w', encoding='utf-8').write('\n'.join(L))
print('WROTE')
PY
)
  case "$R" in
    HIT*|WROTE*) ok=$((ok+1)); printf '  ✅ %-16s L%-4s %s\n' "$name" "$ln" "$([ "$DRY" = 1 ] && echo '命中（dry）' || echo '已改')" ;;
    *) bad=$((bad+1)); printf '  ❌ %-16s L%-4s %s\n' "$name" "$ln" "${R#FAIL }" ;;
  esac
done <<EOF
$(printf '%s' "$SPEC")
EOF

echo
echo "==== 结果：成功 ${ok}、失败 ${bad} $([ "$skip" -gt 0 ] && echo "、跳过 ${skip}" || true) ===="
if [ "$bad" -gt 0 ]; then echo '❌ 有未命中 ⇒ 先查清楚再改，不要盲改'; exit 1; fi
if [ "$DRY" = 1 ]; then echo '（--dry：未写文件）'; else
  echo '⇒ 接下来必须：编译 → 装包 → 对每款 python3 工具/shot_game.py "<显示名>" 看 blk 与 board='
fi
