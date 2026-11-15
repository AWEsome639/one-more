#!/bin/bash
# 在 _巡检记录/ 的 1000+ 份文档里定位：先搜文件名，再搜首行标题，最后搜正文。
#
# 用法：
#   bash 工具/find_doc.sh 截断          # 关键词
#   bash 工具/find_doc.sh dark 深色     # 多个关键词（任一命中）
#   bash 工具/find_doc.sh -n 20 容量界  # 限制条数
#
# 为什么需要它：_巡检记录/ 已超 1000 份，且文件名是「★★★★★★标题-日期.md」这种形状，
# 光靠 ls 翻不动（判据 2799 同族：有索引不等于找得到）。

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/_巡检记录"
LIMIT=12

if [ "${1:-}" = "-n" ]; then LIMIT="${2:-12}"; shift 2; fi
if [ $# -eq 0 ]; then
  echo "用法: bash 工具/find_doc.sh [-n N] 关键词 [关键词2 ...]" >&2
  exit 2
fi

# 拼一个 OR 正则
PAT=""
for kw in "$@"; do
  if [ -z "$PAT" ]; then PAT="$kw"; else PAT="$PAT|$kw"; fi
done

echo "=== ① 文件名命中（最可能是你要的）==="
ls -1t "$DIR" 2>/dev/null | grep -iE "$PAT" | head -"$LIMIT" | sed 's/^/  /'

echo
echo "=== ② 首行标题命中（文件名看不出内容时）==="
found=0
for f in "$DIR"/*.md; do
  [ -f "$f" ] || continue
  head1=$(head -3 "$f" 2>/dev/null | grep -m1 '^#' | sed 's/^#*[[:space:]]*//')
  if printf '%s' "$head1" | grep -qiE "$PAT"; then
    echo "  $(basename "$f")"
    echo "      — $head1"
    found=$((found+1))
    [ "$found" -ge "$LIMIT" ] && break
  fi
done
[ "$found" -eq 0 ] && echo "  （无）"

echo
echo "=== ③ 正文命中（只列文件名与行号，最多 $LIMIT 条）==="
grep -rilE "$PAT" "$DIR"/*.md 2>/dev/null | head -"$LIMIT" | sed "s|^$DIR/|  |"
