#!/usr/bin/env bash
# push_and_verify.sh —— 推送并**用 ls-remote 确认真的同步了**
#
# ★ 为什么需要这个（第 1230 轮，判据 625）
#   本机 SSH 到 GitHub 是**间歇性**的：实测直连 10 次 ✅7 / ❌2 / ⚪1
#   （`Permission denied (publickey)` 与空输出交替出现）
#   ⇒ 于是有两个坑：
#     ① `git push` 失败时**可能也返回 0**（连接中途断开但已传完对象）
#     ② `git ls-remote` 失败时返回**空字符串**
#        ⇒ 老判定 `[ "$LOCAL" = "$REMOTE" ]` 里 "$REMOTE" 为空 ⇒ 误判「没推送」
#   ⇒ 正确做法：**重试到拿到非空 SHA**，再与之比较；
#     并统一用 `GIT_SSH_COMMAND` 钉死单 key，减少"多 key 尝试"导致的拒绝。
#
# 用法： bash 工具/push_and_verify.sh [branch] [max_tries]
set -u
BRANCH="${1:-main}"
TRIES="${2:-15}"

cd "$(dirname "$0")/.." || exit 1

# 钉死单 key（本机 ~/.ssh/config 已有 alias，但这里显式指定更稳）
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_github -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10"

LOCAL=$(git rev-parse HEAD)
echo "  本地 HEAD: $(echo "$LOCAL" | cut -c1-7)"

# ── ① 先确认没有未提交 ──
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" != "0" ]; then
  echo "  ⚠️ 有 $DIRTY 个未提交改动（继续推送，但提醒你）"
fi

# ── ② 取远端 SHA：**必须重试到非空**（判据 625 的核心）──
get_remote() {
  local i R
  for i in $(seq 1 "$TRIES"); do
    R=$(timeout 30 git ls-remote origin "refs/heads/$BRANCH" 2>/dev/null | awk '{print $1}')
    if [ -n "$R" ]; then echo "$R"; return 0; fi
    sleep 1
  done
  return 1
}

echo "  → 取远端 SHA（重试到非空）…"
REMOTE=$(get_remote)
if [ -z "$REMOTE" ]; then
  echo "  ❌ $TRIES 次都没拿到远端 SHA（SSH 完全不可用，不是"没推送"）"
  exit 2
fi
echo "  远端 $BRANCH: $(echo "$REMOTE" | cut -c1-7)"

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "  ✅ 已经同步，无需推送"
  exit 0
fi

# ── ③ 推送，每次都回头用 ls-remote 复核 ──
for i in $(seq 1 "$TRIES"); do
  timeout 90 git push origin "$BRANCH" >/dev/null 2>&1
  sleep 1
  REMOTE=$(get_remote)
  if [ -n "$REMOTE" ] && [ "$REMOTE" = "$LOCAL" ]; then
    echo "  ✅ 第 $i 次推送后确认同步（远端 = $(echo "$REMOTE" | cut -c1-7)）"
    exit 0
  fi
  echo "  第 $i 次未同步（远端=$(echo "${REMOTE:-空}" | cut -c1-7)），重试…"
  sleep 2
done

echo "  ❌ $TRIES 次仍未同步"
exit 1
