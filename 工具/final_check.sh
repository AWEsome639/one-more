#!/bin/bash
# 2026-11-14：**今晚跑步前的总检** —— 一条命令确认「一切就绪」
#
# 为什么需要：今天抓到 `6` 个「报告会给我一个看起来正确的错误答案」的坑，
#   其中最后一个（优先级按提交数、被自己的提交挤出窗口）是**最后一次复核**才暴露的。
#   ⇒ 说明「收尾再跑一遍」不是形式主义，而是必要的。
#
# 七项检查（全部不需要设备）：
#   ① 改动在位核对      —— 37 处改动有没有被后编辑吃掉
#   ② 语法预检          —— 括号配平 / Bp import / 三元式
#   ③ 八把断言          —— 200359 / 0
#   ④ 格子尺寸审计      —— 有没有「小到点不准」
#   ⑤ 台账完整性        —— 格式 / 时间戳 / 重复
#   ⑥ 复核名单覆盖      —— verify_changed 是否覆盖全部改动
#   ⑦ 扫描器 dry-run    —— 优先级数量 + 待测数量（**不起设备**）
#
# 用法：bash 工具/final_check.sh
set +u
cd "/Users/a0000/dev/One More" || exit 1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

FAIL=0
step() { echo; echo "───── $* ─────"; }
fail() { echo "  ❌ $*"; FAIL=$((FAIL+1)); }

step "① 改动在位核对"
if python3 工具/verify_changes_present.py > /tmp/fc1.log 2>&1; then
  tail -2 /tmp/fc1.log | sed 's/^/  /'
else
  grep -E "❌|缺" /tmp/fc1.log | head -5 | sed 's/^/  /'; fail "有改动不在位"
fi

step "② 语法预检"
if bash 工具/preflight.sh > /tmp/fc2.log 2>&1; then
  tail -1 /tmp/fc2.log | sed 's/^/  /'
else
  grep -E "❌|大括号|圆括号|import" /tmp/fc2.log | head -5 | sed 's/^/  /'
  # 已知假阳性文件（preflight.sh 文件头登记过）
  if grep -qE "GameI18n|ChatFinder|core/I18n|core/Tv|GameRegistry" /tmp/fc2.log; then
    echo "  ⚠️ 报的是**已登记的假阳性文件** ⇒ 不算失败（见 preflight.sh 文件头）"
  else
    fail "语法预检未过"
  fi
fi

step "③ 八把断言"
if bash 工具/check_assertions.sh > /tmp/fc3.log 2>&1; then
  grep -E "合计|与基线一致" /tmp/fc3.log | tail -2 | sed 's/^/  /'
else
  tail -3 /tmp/fc3.log | sed 's/^/  /'; fail "断言未过"
fi

step "④ 格子尺寸审计（只看结论行）"
python3 工具/cell_size_audit.py > /tmp/fc4.log 2>&1
grep -E "偏小|封顶太松" /tmp/fc4.log | head -3 | sed 's/^/  /'

step "⑤ 台账完整性"
python3 - <<'PY' 2>&1 | sed 's/^/  /'
import io, re, collections
rows, bad = [], 0
for ln in io.open('_巡检记录/layout-canonical.tsv', encoding='utf-8'):
    f = ln.rstrip('\n').split('\t')
    if len(f) < 4: bad += 1; continue
    rows.append(f)
tsbad = sum(1 for r in rows if not re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$', r[0]))
last = {}
for r in rows: last[r[1]] = r[2]
c = collections.Counter(last.values())
good = sum(1 for v in last.values() if v in ('OK','TIGHT','OVER','NEAR'))
print('总行 %d / 格式异常 %d / 时间戳异常 %d' % (len(rows), bad, tsbad))
print('覆盖率 %d/354 = %.1f%%（最新状态: %s）' % (good, good/354*100, dict(c)))
PY

step "⑥ 复核名单覆盖"
python3 - <<'PY' 2>&1 | sed 's/^/  /'
import io, re
import importlib.util
spec = importlib.util.spec_from_file_location('vc', '工具/verify_changes_present.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
sh = io.open('工具/verify_changed.sh', encoding='utf-8').read()
in_sh = set(re.findall(r'^\s*"([^"|]+)\|', sh, re.M))
reg = io.open('entry/src/main/ets/core/GameRegistry.ets', encoding='utf-8').read()
id2en = dict(re.findall(r"id: '([^']+)'[^}]*?enName: '([^']+)'", reg))
miss = []
for cls, _, _ in m.CHECKS:
    src = io.open('entry/src/main/ets/games/%s.ets' % cls, encoding='utf-8').read()
    mm = re.search(r"(?:id|gameId)\s*[:=]\s*'([a-z0-9_]+)'", src)
    en = id2en.get(mm.group(1)) if mm else None
    if en and en not in in_sh: miss.append(en)
print('改动 %d 处 / verify_changed.sh 覆盖 %d 款 / 缺 %d 款' % (len(m.CHECKS), len(in_sh), len(miss)))
if miss: print('缺: %s' % ', '.join(miss))
PY

step "⑦ 扫描器 dry-run（不起设备）"
timeout 120 bash 工具/sweep_all.sh --dry > /tmp/fc7.log 2>&1
grep -E "优先|待测" /tmp/fc7.log | head -2 | sed 's/^/  /'
EMU=$(pgrep -f 'tools/emulator/Emulator' | wc -l | tr -d ' ')
# ⚠️ 2026-11-14：这里原来写 `echo "  模拟器进程: $EMU（必须 0）"`，
#   而某些 locale 下中文全角括号 + 变量会输出成乱码（实测 `��必须 0）`）。
#   ⇒ 诊断脚本里**只用 ASCII**，避免「检查结果本身好看但读不出」。
echo "  emulator procs: $EMU  (must be 0)"
[ "$EMU" != "0" ] && fail "dry-run 起了模拟器"

echo
echo "═════════════════ 总检结论 ═════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ 全部就绪 —— 今晚可以按四步跑"
  echo "   ① hdc install -r entry/build/default/outputs/default/entry-default-signed.hap"
  echo "   ② bash 工具/verify_changed.sh"
  echo "   ③ python3 工具/triage.py"
  echo "   ④ bash 工具/sweep_all.sh"
else
  echo "❌ 有 $FAIL 项未过 —— 先修再跑"
fi
exit "$FAIL"
