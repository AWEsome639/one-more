#!/usr/bin/env bash
# ============================================================================
#  工具/dev_dump.sh —— **安全的 UI dump**：删旧 → 抓取 → 校验 → 报节点数
#
#  ★ 为什么要有这个（判据 1099/1100，第 1372 轮）
#    我在第 1372 轮判「dailyStrip 修复未生效」，而真相是——
#    `file recv` **悄悄失败**了，磁盘上还留着**上一轮**的 dump，
#    而它正好支持了我要的错误结论。**旧文件不会告诉你它旧了。**
#
#    两次更早的同类（判据 1063 / 1075）：
#      1063：界面没变 ⇒ 先怀疑「我读得太早」
#      1075：dump 被覆盖 ⇒ 先怀疑「文件被改写」
#      1100：修复没生效 ⇒ 先怀疑「我读的是旧文件」
#
#  ★ 本脚本保证四件事：
#    ① **先删目标文件**（不存在就报错，不再静默复用旧文件）
#    ② 抓取后**校验 mtime 是刚刚**（不是几小时前）
#    ③ 校验**大小**（默认 > 3000 字节，可用 SIZE 覆盖）
#    ④ 打印**节点数 + 关键文本命中**，让调用者一眼看出内容对不对
#
#  ★ 另一个教训（判据 1101）：
#    `uitest dumpLayout -i` 在本机版本上返回**节点 0**（不可解析）
#    ⇒ ⛔ 本脚本**不用 `-i`**，只用默认参数（实测 116 节点正常）
#
#  用法：
#    bash 工具/dev_dump.sh <输出文件> [关键文本...]
#    例：bash 工具/dev_dump.sh /tmp/home_960.json 今天这一局 LV
#  退出码：0 = 抓到且非空且新鲜；1 = 失败（目标文件已被删除，绝不残留旧内容）
# ============================================================================
set -u
OUT="${1:?用法: dev_dump.sh <输出文件> [关键文本...]}"
shift || true
KEYS=("$@")
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
DEV="127.0.0.1:5555"
MIN_SIZE="${MIN_SIZE:-3000}"

# ── ① 先删目标文件（判据 1099：绝不静默复用旧文件）──
rm -f "$OUT"
if [ -e "$OUT" ]; then
  echo "🔴 无法删除旧文件 $OUT" >&2
  exit 1
fi

# ── ② 设备上抓取 ──
timeout 25 "$HC" -t "$DEV" shell "uitest dumpLayout -p /data/local/tmp/_devdump.json" >/dev/null 2>&1
timeout 20 "$HC" -t "$DEV" file recv /data/local/tmp/_devdump.json "$OUT" >/dev/null 2>&1

# ── ③ 校验：存在 / 大小 / 新鲜 ──
if [ ! -f "$OUT" ]; then
  echo "🔴 file recv 失败（目标文件不存在）" >&2
  exit 1
fi
SZ=$(wc -c < "$OUT" | tr -d ' ')
if [ "$SZ" -lt "$MIN_SIZE" ]; then
  echo "🔴 文件过小（${SZ} < ${MIN_SIZE}）⇒ 可能截断" >&2
  rm -f "$OUT"
  exit 1
fi
AGE=$(( $(date +%s) - $(stat -f %m "$OUT" 2>/dev/null || echo 0) ))
if [ "$AGE" -gt 30 ]; then
  echo "🔴 文件不新鲜（${AGE}s 前）⇒ 不是这次抓的" >&2
  exit 1
fi

# ── ④ 报节点数 + 关键文本 ──
python3 - "$OUT" "${KEYS[@]:-}" <<'PY'
import json, os, sys
p = sys.argv[1]
keys = [k for k in sys.argv[2:] if k]
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception as e:
    print('🔴 JSON 解析失败: %s' % e)
    raise SystemExit(1)
n = 0; texts = []
def w(x):
    global n
    if not isinstance(x, dict): return
    n += 1
    t = (x.get('attributes', {}).get('text') or '').strip()
    if t: texts.append(t)
    for c in x.get('children', []) or []: w(c)
w(d)
if n == 0:
    print('🔴 节点 0 ⇒ dump 不可用（判据 1101：不要用 -i）')
    raise SystemExit(1)
print('✅ dump %s ｜ %d 字节 ｜ **%d 节点** ｜ %d 条文本'
      % (os.path.basename(p), os.path.getsize(p), n, len(texts)))
if keys:
    hit = [k for k in keys if any(k in t for t in texts)]
    miss = [k for k in keys if k not in hit]
    print('   关键文本命中 %d/%d: %s' % (len(hit), len(keys), hit))
    if miss:
        print('   ⚠️ 未命中: %s' % miss)
        raise SystemExit(2)
PY
RC=$?
exit "$RC"
