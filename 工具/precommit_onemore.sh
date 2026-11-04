#!/bin/bash
# precommit_onemore.sh —— **One More 专用**提交前检查（七项）
#
# ★ 为什么不复用 `工具/precommit.sh`（判据 857）
#   那个文件第 4 行是 `cd ~/dev/yiju` ⇒ **属于另一个项目**
#   ⇒ 往它里面加 One More 的检查会**污染另一个项目**
#   ⇒ 本项目单独一份
#
# 用法: bash 工具/precommit_onemore.sh
# 退出码: 0 = 全绿 ｜ 1 = 有红项 ｜ 2 = 环境问题

set -u
cd "$(dirname "$0")/.." || exit 2

FAIL=0
run() {  # $1=名字 $2=命令...
  local name="$1"; shift
  printf '  %-26s ' "$name"
  if "$@" > /tmp/_pc_out.log 2>&1; then
    echo "✅"
  else
    echo "🔴"
    sed 's/^/      /' /tmp/_pc_out.log | head -12
    FAIL=$((FAIL + 1))
  fi
}

echo "════ One More · 提交前检查（七项）════"

# ① 断言基线
printf '  %-26s ' "① 断言基线"
ASRT=$(bash 工具/check_assertions.sh 2>&1 | tail -1)
if printf '%s' "$ASRT" | grep -q "200359 / 0"; then
  echo "✅ 200,359 / 0"
else
  echo "🔴 $ASRT"
  FAIL=$((FAIL + 1))
fi

# ② 开屏九项 + 证据新鲜度
run "② check_splash" python3 工具/check_splash.py

# ③ 文档 tracked
run "③ check_docs_tracked" python3 工具/check_docs_tracked.py

# ④ 描边挂载
run "④ check_outline_owner" python3 工具/check_outline_owner.py

# ⑤ 文本挤压
run "⑤ check_text_fit" python3 工具/check_text_fit.py

# ⑥ 变异测试
run "⑥ mutation_test" python3 工具/mutation_test.py

# ⑦ shell 陷阱（第 1329 轮新增）
run "⑦ check_shell_pitfalls" python3 工具/check_shell_pitfalls.py

echo "════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ 七项全绿，可以提交"
  exit 0
fi
echo "  🔴 $FAIL 项红，⛔ 不要提交"
exit 1
