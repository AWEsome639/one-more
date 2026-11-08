#!/bin/bash
# UI 改动的「真机验收闸门」 —— 判据 1829 / 1815 的下游工具
#
# 来历：2026-11-08 奥森现场报「3 张卡片背后一大片紫色」，
#   而 check_i18n / check_rtl / check_focusable **三项全绿**。
#   ⇒ 那三把尺子查的是「文案 / 方向 / 焦点」，而故障在「布局几何」维度。
#   ⇒ 这个脚本补第四维：**按你改了什么，要求你验什么**。
#
# 误报率实测（2026-11-08 的 101 个提交）：
#   几何规则触发 30 个（30%），提交级 **30/30 真阳性 ⇒ 误报 0%**
#   联合触发 40 个（39%）⇒ 61% 的提交完全不需要真机验证
#
# 用法：
#   bash 工具/check_ui_change.sh            # 只提示（默认，退出码恒 0）
#   bash 工具/check_ui_change.sh --strict   # 有几何改动但没证据 ⇒ 退出码 1
#   bash 工具/check_ui_change.sh --commit <hash>  # 回溯检查某一次提交（而不是工作区）
#
# 证据怎么给（--strict 才需要）：
#   UI_VERIFIED=1 bash 工具/check_ui_change.sh --strict
#   （意味着：你已经跑过 uitest dumpLayout 并看过对应节点）

set -u
STRICT=0
STRICT=0
COMMIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --commit) COMMIT="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# ── 从 git diff 里取「新增的代码行」（去掉注释行）──
# 只看工作区 + 暂存区的改动（**不是** git log：今天的紫色事故从未提交，
#  所以任何「扫历史提交」的做法都抓不到它）
if [ -n "$COMMIT" ]; then
  DIFF=$(git show "$COMMIT" --unified=0 --format= -- '*.ets' 2>/dev/null)
  echo "── 检查提交 ${COMMIT}（git show）──"
else
  DIFF=$(git diff HEAD --unified=0 -- '*.ets' 2>/dev/null)
fi
[ -z "$DIFF" ] && { echo "✅ 工作区没有 .ets 改动，无需验"; exit 0; }

ADDED=$(printf '%s\n' "$DIFF" | grep -E "^\+" | grep -vE "^\+\+\+" | sed 's/^+//' \
        | grep -vE "^[[:space:]]*(//|\*|/\*)" | grep -vE "^[[:space:]]*$")

if [ -z "$ADDED" ]; then
  echo "✅ 只有注释改动，无需验"
  exit 0
fi

# ── 三条规则 ──
GEO=$(printf '%s\n' "$ADDED" | grep -cE '\.(width|height|position|offset|aspectRatio|constraintSize|backgroundColor|borderRadius|padding|margin)[[:space:]]*\(|@Builder|layoutWeight|flexShrink|\.scale\(' || true)
CPY=$(printf '%s\n' "$ADDED" | grep -cE '(TG|TG2|TG4|TN|L)[[:space:]]*\(' || true)
DIR=$(printf '%s\n' "$ADDED" | grep -cE 'direction[[:space:]]*\(|\.align[[:space:]]*\(|Alignment\.|start[[:space:]]*:|end[[:space:]]*:|\.mirror' || true)

# 组件类型替换（判据 1829 的核心形态：Text(emoji) → SymbolGlyph）
#   ⚠️ 这类改动**一个几何属性都不改**，纯靠「换组件」就换了布局语义
REMOVED_COMP=$(printf '%s\n' "$DIFF" | grep -E "^-" | grep -vE "^---" \
  | grep -oE "^-[[:space:]]*(Text|SymbolGlyph|Image|Row|Column|Stack|Flex|Button|Grid|List|Scroll)[[:space:]]*\(" \
  | grep -oE '(Text|SymbolGlyph|Image|Row|Column|Stack|Flex|Button|Grid|List|Scroll)' | sort -u)
ADDED_COMP=$(printf '%s\n' "$ADDED" \
  | grep -oE "^[[:space:]]*(Text|SymbolGlyph|Image|Row|Column|Stack|Flex|Button|Grid|List|Scroll)[[:space:]]*\(" \
  | grep -oE '(Text|SymbolGlyph|Image|Row|Column|Stack|Flex|Button|Grid|List|Scroll)' | sort -u)
NEWCOMP=""
for c in $ADDED_COMP; do
  echo "$REMOVED_COMP" | grep -qx "$c" || NEWCOMP="$NEWCOMP $c"
done

echo "═══ UI 改动闸门 ═══"
echo "几何命中 $GEO 行 ｜ 文案 $CPY 行 ｜ 方向 $DIR 行 ｜ 新组件类型:${NEWCOMP:- 无}"
echo

NEED_DEVICE=0
if [ "$GEO" -gt 0 ] || [ -n "$(echo $NEWCOMP | tr -d ' ')" ]; then
  NEED_DEVICE=1
  echo "🔴 触发布局几何检查 —— 必须跑一次真机并贴 bounds 结论："
  echo "    hdc shell \"uitest dumpLayout -p /data/local/tmp/a.json\""
  echo "    hdc file recv /data/local/tmp/a.json /tmp/a.json"
  echo "  然后自检四条（判据 1829/1819/1825）："
  echo "    ① 拉伸：实际宽 > 声明宽 × 1.05 ？        ⇒ 加 .flexShrink(0)"
  echo "    ② 撑爆：子节点 height > 父节点 height ？ ⇒ constraintSize / 放宽上限"
  echo "    ③ position：dump 里找不到那个节点？      ⇒ 换 Canvas 或改布局"
  echo "    ④ 视觉vs判定：S = 视觉尺寸 / 判定系数，实际容器 ≠ S ？"
  echo
fi
if [ "$CPY" -gt 0 ]; then
  echo "🟡 触发文案检查：python3 tools/check_i18n.py"
fi
if [ "$DIR" -gt 0 ]; then
  echo "🟡 触发方向检查：python3 tools/check_rtl.py"
fi
[ "$NEED_DEVICE" -eq 0 ] && [ "$CPY" -eq 0 ] && [ "$DIR" -eq 0 ] && echo "✅ 三条规则都没触发，这次改动不需要真机验证"

echo
if [ "$STRICT" -eq 1 ] && [ "$NEED_DEVICE" -eq 1 ]; then
  EVIDENCE_OK=0
  # ① 首选：UI_EVIDENCE=<报告路径>（真证据：报告存在 + 里面有 dump/像素差关键词）
  if [ -n "${UI_EVIDENCE:-}" ]; then
    if [ ! -f "${UI_EVIDENCE}" ]; then
      echo "❌ --strict：UI_EVIDENCE 指向的报告不存在：${UI_EVIDENCE}"
      exit 1
    fi
    if grep -qE "像素差|dump|bounds|边界|坐标" "${UI_EVIDENCE}" 2>/dev/null; then
      echo "✅ --strict：证据来自报告 ${UI_EVIDENCE}（含 dump/bounds/像素差关键词）"
      EVIDENCE_OK=1
    else
      echo "❌ --strict：报告 ${UI_EVIDENCE} 里没有 dump/bounds/像素差 等关键词 —— 不算证据"
      exit 1
    fi
  fi
  # ② 向后兼容：UI_VERIFIED=1（弱证据，任何人能设；不推荐）
  if [ "$EVIDENCE_OK" -eq 0 ] && [ "${UI_VERIFIED:-0}" = "1" ]; then
    echo "🟡 --strict：用的是 UI_VERIFIED=1（弱证据，任何人都能设）"
    echo "   建议改用：UI_EVIDENCE=<报告路径> bash 工具/check_ui_change.sh --strict"
    EVIDENCE_OK=1
  fi
  if [ "$EVIDENCE_OK" -eq 0 ]; then
    echo "❌ --strict：有布局几何改动，但没有证据"
    echo "   跑完 dumpLayout 并写成报告后："
    echo "   UI_EVIDENCE=_巡检记录/<报告>.md bash 工具/check_ui_change.sh --strict"
    echo "   （旧的 UI_VERIFIED=1 仍可用，但属弱证据）"
    exit 1
  fi
fi
exit 0
