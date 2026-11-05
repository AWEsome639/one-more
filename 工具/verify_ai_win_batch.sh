#!/usr/bin/env bash
# ============================================================================
#  工具/verify_ai_win_batch.sh —— 批量跑「AI 能不能赢」：分批 + 掉线续跑
#
#  ★ 为什么要有（判据 1682）
#    `verify_ai_win.py` 自己已经会自愈（判据 1674）、会在救不回来时报
#    `DEVICE_DEAD` + 退出码 3（判据 1675）。但**它一报 3 就整个退出**——
#    24 款跑到第 17 款掉线，剩下 7 款就永远没验过，还得人盯着重跑。
#    这个包装器把「批次」和「续跑」补上：
#      · 每批 CHUNK 款（默认 8）一个 python 进程
#      · 退出码 3 ⇒ 等 30s 重跑**这一批**（最多 RETRIES 次），自愈仍交给 python
#      · 重跑前把「这一批里已经有记录」的款剔掉 ⇒ 不重复写、不重跑已出结论的
#      · 每批先写临时文件，成功后再追加进正式 jsonl
#        ⇒ 正式文件永远一行一条（判据 1680），半截批也不会污染
#
#  ★ 用法
#    bash 工具/verify_ai_win_batch.sh                        # 注册表全部 355 款
#    bash 工具/verify_ai_win_batch.sh /tmp/names24.txt       # 指定名单（一行一款）
#    bash 工具/verify_ai_win_batch.sh /tmp/names24.txt 240 8
#        ↑ 位置参数：名单（空=全部）｜单款秒数 ｜每批款数
#
#  ★ 环境变量（优先级高于同名位置参数）
#    PER_GAME=240      单款预算（→ --per-game-timeout）
#    CHUNK=8           每批款数
#    RETRIES=3         掉线重试次数
#    RETRY_SLEEP=30    掉线后等待秒数再重跑本批
#    SKIP=win|all|none 已验过的款跳过口径（默认 win：只跳已 WIN 的）
#
#  ★ 产物
#    验收截图-v1.0.1/ai_win_verified.jsonl    结果（一行一条，追加）
#    验收截图-v1.0.1/ai_win_batch_<ts>.log    全程日志（含每批 python 的原样输出）
#
#  ★ 退出码（沿用判据 1681）
#    0 全 WIN ｜ 1 有 FAIL/TIMEOUT/ERROR ｜ 2 脚本异常 ｜ 3 设备不可用（重试后仍未恢复）
# ============================================================================
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || { echo "🔴 进不去项目根目录" >&2; exit 2; }

PY="工具/verify_ai_win.py"
MAIN_OUT="验收截图-v1.0.1/ai_win_verified.jsonl"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="验收截图-v1.0.1/ai_win_batch_${TS}.log"
mkdir -p "验收截图-v1.0.1"

NAMES_IN="${1:-}"
PER_GAME="${PER_GAME:-${2:-240}}"
CHUNK="${CHUNK:-${3:-8}}"
RETRIES="${RETRIES:-3}"
RETRY_SLEEP="${RETRY_SLEEP:-30}"   # 掉线后等多久再重跑（测试时可设 0）
SKIP="${SKIP:-win}"

case "$CHUNK" in
  ''|*[!0-9]*) echo "🔴 CHUNK 必须是正整数（现在=${CHUNK}）" >&2; exit 2 ;;
esac
case "$RETRIES" in
  ''|*[!0-9]*) echo "🔴 RETRIES 必须是非负整数（现在=${RETRIES}）" >&2; exit 2 ;;
esac
[ -f "$PY" ] || { echo "🔴 找不到 $PY" >&2; exit 2; }

say() { printf '%s\n' "$*" | tee -a "$LOG"; }

TMPDIR_S="$(mktemp -d /tmp/vaw_batch.XXXXXX)"
trap 'rm -rf "$TMPDIR_S"' EXIT
CAND="$TMPDIR_S/cand.txt"        # 候选名单（去重后）
PENDING="$TMPDIR_S/pending.txt"  # 还没出结论的（本次要跑）
CHUNK_ALL="$TMPDIR_S/chunk_all.txt"   # 本批的原始名单
CHUNK_TODO="$TMPDIR_S/chunk_todo.txt" # 本批剔除「已记录」后的待跑名单
TMP_OUT="$TMPDIR_S/chunk.jsonl"  # 本批结果（成功后再追加进正式文件）
ABORTED="$TMPDIR_S/aborted.txt"  # 重试用尽仍未验成的款
RUN_OUT="$TMPDIR_S/run.jsonl"    # **本次运行**写下的记录（重跑时按它剔，见判据 1682）

# ── 1. 名单 ──
if [ -n "$NAMES_IN" ]; then
  [ -f "$NAMES_IN" ] || { echo "🔴 名单文件不存在：$NAMES_IN
  （第 1 个位置参数是**名单文件**；只想改秒数/批大小请用 PER_GAME=240 CHUNK=8，或放到第 2/3 个参数）" >&2; exit 2; }
  # 去空行/注释行/重复
  awk 'NF && $0 !~ /^[[:space:]]*#/ && !seen[$0]++' "$NAMES_IN" > "$CAND"
  say "  名单来源：$NAMES_IN"
else
  # ★ 用 python 直接复用验证器的注册表解析，避免在 shell 里再写一遍正则
  python3 - "$PY" "$CAND" <<'PY' || { echo "🔴 读注册表失败" >&2; exit 2; }
import importlib.util, io, sys
spec = importlib.util.spec_from_file_location('vaw', sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
seen, out = set(), []
for _gid, nm in m.registry_names():
    if nm not in seen:
        seen.add(nm)
        out.append(nm)
io.open(sys.argv[2], 'w', encoding='utf-8').write(''.join(n + '\n' for n in out))
print('  名单来源：注册表 GameRegistry.ets（%d 款）' % len(out))
PY
fi
[ -s "$CAND" ] || { echo "🔴 候选名单是空的" >&2; exit 2; }

case "$SKIP" in
  win|all|none) ;;
  *) echo "🔴 SKIP 只能是 win/all/none（现在=${SKIP}）" >&2; exit 2 ;;
esac
# ── 2. 跳过口径（判据 1680：以 jsonl 的**最后一条**记录为准）──
python3 - "$CAND" "$PENDING" "$MAIN_OUT" "$SKIP" <<'PY'
import io, json, os, sys
cand, pend, done_path, skip = sys.argv[1:5]
last = {}
if os.path.exists(done_path):
    for ln in io.open(done_path, encoding='utf-8'):
        ln = ln.strip()
        if not ln:
            continue
        try:
            r = json.loads(ln)
        except Exception:
            continue
        if r.get('name'):
            last[r['name']] = r.get('verdict')

def skipped(n):
    if n not in last:
        return False
    if skip == 'none':
        return False
    if skip == 'all':
        return True
    return last[n] == 'WIN'          # 默认 win：FAIL/TIMEOUT 要重验

names = [l.strip() for l in io.open(cand, encoding='utf-8') if l.strip()]
keep = [n for n in names if not skipped(n)]
io.open(pend, 'w', encoding='utf-8').write(''.join(n + '\n' for n in keep))
print('  待验 %d 款（名单 %d，按 SKIP=%s 跳过 %d）' % (len(keep), len(names), skip, len(names) - len(keep)))
PY
[ -f "$PENDING" ] || { echo "🔴 预处理名单失败（没有生成 ${PENDING}）" >&2; exit 2; }

TOTAL="$(awk 'END{print NR+0}' "$PENDING" 2>/dev/null || echo 0)"
TOTAL="${TOTAL:-0}"
if [ "$TOTAL" -eq 0 ]; then
  say "  ✅ 没有待验的款（都已出结论，SKIP=${SKIP}）"
  exit 0
fi
say "  单款上限 ${PER_GAME}s ｜ 每批 ${CHUNK} 款 ｜ 掉线重试 ${RETRIES} 次"
say "  结果追加到：$MAIN_OUT"
say "  日志：$LOG"

# ── 3. 分批跑 ──
: > "$ABORTED"
: > "$RUN_OUT"
BATCH_NO=0
OVERALL=0      # 0=全 WIN ｜ 1=有失败 ｜ 2=脚本异常 ｜ 3=设备不可用
while [ -s "$PENDING" ]; do
  BATCH_NO=$((BATCH_NO + 1))
  head -n "$CHUNK" "$PENDING" > "$CHUNK_ALL"
  N_THIS="$(awk 'END{print NR}' "$CHUNK_ALL")"
  say ""
  say "── 第 ${BATCH_NO} 批（${N_THIS} 款）: $(paste -sd' ' "$CHUNK_ALL" | cut -c1-120) ──"

  ATTEMPT=0
  BATCH_RC=0
  while : ; do
    ATTEMPT=$((ATTEMPT + 1))
    # 剔掉「**本次运行**已经有记录」的款（判据 1682：重跑不重复）
    # ★ 为什么看 RUN_OUT 而不是 MAIN_OUT：MAIN_OUT 是跨轮累计的。
    #   若按它剔，SKIP=none（想把老记录重验一遍）会被剔成空批 ⇒ 整批静默不跑，
    #   汇总还读回旧结论（2026-11-06 实测踩到）。
    if [ -f "$RUN_OUT" ]; then
      python3 - "$CHUNK_ALL" "$CHUNK_TODO" "$RUN_OUT" <<'PY'
import io, json, os, sys
chunk, todo, done_path = sys.argv[1:4]
have = set()
if os.path.exists(done_path):
    for ln in io.open(done_path, encoding='utf-8'):
        ln = ln.strip()
        if not ln:
            continue
        try:
            r = json.loads(ln)
        except Exception:
            continue
        if r.get('name'):
            have.add(r['name'])
names = [l.strip() for l in io.open(chunk, encoding='utf-8') if l.strip()]
io.open(todo, 'w', encoding='utf-8').write(''.join(n + '\n' for n in names if n not in have))
PY
    else
      cp "$CHUNK_ALL" "$CHUNK_TODO"
    fi
    [ -f "$CHUNK_TODO" ] || cp "$CHUNK_ALL" "$CHUNK_TODO"   # 过滤脚本异常也照跑，不静默跳批
    if [ ! -s "$CHUNK_TODO" ]; then
      BATCH_RC=0
      break
    fi

    : > "$TMP_OUT"
    python3 "$PY" --names-file "$CHUNK_TODO" --per-game-timeout "$PER_GAME" \
            --out "$TMP_OUT" 2>&1 | tee -a "$LOG"
    BATCH_RC="${PIPESTATUS[0]}"
    # 本批已有结论的部分先落正式文件（判据 1680：一行一条、逐条 flush 的是 python 那边）
    if [ -s "$TMP_OUT" ]; then
      cat "$TMP_OUT" >> "$MAIN_OUT"
      cat "$TMP_OUT" >> "$RUN_OUT"
    fi

    if [ "$BATCH_RC" -eq 3 ] && [ "$ATTEMPT" -le "$RETRIES" ]; then
      say "  🔴 DEVICE_DEAD（第 ${ATTEMPT} 次）→ ${RETRY_SLEEP}s 后重跑本批（还剩 $((RETRIES - ATTEMPT + 1)) 次）"
      sleep "$RETRY_SLEEP"
      continue
    fi
    break
  done

  # 本批无论成败都不再进 PENDING；重试用尽仍未验成的单独记账
  if [ "$BATCH_RC" -eq 3 ]; then
    python3 - "$CHUNK_ALL" "$CHUNK_TODO" "$RUN_OUT" "$ABORTED" <<'PY'
import io, json, os, sys
chunk, todo, done_path, aborted = sys.argv[1:5]
have = set()
if os.path.exists(done_path):
    for ln in io.open(done_path, encoding='utf-8'):
        ln = ln.strip()
        if not ln:
            continue
        try:
            r = json.loads(ln)
        except Exception:
            continue
        if r.get('name'):
            have.add(r['name'])
miss = [l.strip() for l in io.open(chunk, encoding='utf-8') if l.strip() and l.strip() not in have]
with io.open(aborted, 'a', encoding='utf-8') as f:
    for n in miss:
        f.write(n + '\n')
print('  ⚠️ 设备始终不可用，本批未验成 %d 款' % len(miss))
PY
    OVERALL=3
  elif [ "$BATCH_RC" -eq 2 ]; then
    say "  🔴 python 脚本异常（退出码 2）—— 停止整批"
    OVERALL=2
    break
  elif [ "$BATCH_RC" -ne 0 ]; then
    [ "$OVERALL" -eq 0 ] && OVERALL=1
  fi

  grep -vxF -f "$CHUNK_ALL" "$PENDING" > "$TMPDIR_S/pending.new" || true
  mv "$TMPDIR_S/pending.new" "$PENDING"
done

# ── 4. 汇总（以 jsonl 里每款的**最后一条**记录为准，判据 1680）──
say ""
python3 - "$CAND" "$MAIN_OUT" "$ABORTED" <<'PY' | tee -a "$LOG"
import io, json, os, sys
cand, done_path, aborted = sys.argv[1:4]
want = [l.strip() for l in io.open(cand, encoding='utf-8') if l.strip()]
last = {}
if os.path.exists(done_path):
    for ln in io.open(done_path, encoding='utf-8'):
        ln = ln.strip()
        if not ln:
            continue
        try:
            r = json.loads(ln)
        except Exception:
            continue
        if r.get('name'):
            last[r['name']] = r
miss = set()
if os.path.exists(aborted):
    miss = set(l.strip() for l in io.open(aborted, encoding='utf-8') if l.strip())

c = {}
bad = []
for n in want:
    # ★ 未验优先：本次因设备不可用根本没跑成的款，不许用**上一轮**的旧记录冒充结论
    #   （否则掉线那批会显示成 WIN/FAIL，看起来「都验过了」——2026-11-06 实测踩到）
    if n in miss:
        c['未验'] = c.get('未验', 0) + 1
        bad.append((n, '未验', '设备不可用，本次未跑成'))
        continue
    r = last.get(n)
    v = r.get('verdict') if r else '未验'
    c[v] = c.get(v, 0) + 1
    if v != 'WIN':
        bad.append((n, v, (r or {}).get('detail', '')))
n_win = c.get('WIN', 0)
print('════ 本轮名单 %d 款：WIN %d ｜ FAIL %d ｜ TIMEOUT %d ｜ ERROR %d ｜ 未验 %d ════' % (
    len(want), n_win, c.get('FAIL', 0), c.get('TIMEOUT', 0), c.get('ERROR', 0), c.get('未验', 0)))
if bad:
    print('  未通过：')
    for n, v, d in bad:
        print('    %-12s => %-8s %s' % (n, v, (d or '')[:100]))
print('  结果：%s' % done_path)
print('  下次再跑同样的命令即会跳过已 WIN 的（SKIP=win）')
PY
SUM_RC=$?
if [ "$SUM_RC" -ne 0 ]; then
  say "  🔴 汇总脚本失败（退出码 ${SUM_RC}）—— 结果文件请手工核对"
  [ "$OVERALL" -eq 0 ] && OVERALL=2
fi

# 还有没验成的款（重试用尽）⇒ 必须报 3，不能当「全 WIN」
if [ -s "$ABORTED" ]; then
  OVERALL=3
fi
say ""
say "  （日志：${LOG}）"
exit "$OVERALL"
