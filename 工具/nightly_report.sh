#!/bin/bash
# 晨检：一条命令看全库状态。跑完这一条，就知道今天能不能开工。
#
# 用法：bash 工具/nightly_report.sh
#
# 为什么需要它：检查工具已经有 6 个，每个都要单独跑、各自一套输出格式；
# 早上第一眼看的是「整体是否有底」，而不是某一个指标的细节（判据 2803 的同类：
# 有能力检查 ≠ 会去检查）。

set -u
cd "$(dirname "$0")/.." || exit 1
echo "════════ 晨检 $(date '+%m-%d %H:%M') ════════"
echo

echo "① 台账新鲜度"
python3 工具/check_ledger_freshness.py 2>/dev/null | grep -E "有效|过期" | sed 's/^/   /'

echo
echo "② 断言基线"
timeout 300 bash 工具/check_assertions.sh 2>&1 | grep -E "合计|与基线一致" | head -2 | sed 's/^/   /'

echo
echo "③ 待看清单（lowh，按升序）"
python3 工具/triage.py 2>/dev/null | sed -n '/必看截图清单/,+6p' | tail -5 | cut -c1-92 | sed 's/^/   /'

echo
echo "④ 截断嫌疑"
python3 工具/check_truncation.py --static 2>/dev/null | head -2 | sed 's/^/   /'

echo
echo "⑤ 截图新鲜度（抽样 40 款，全量太慢）"
python3 - <<'PY' 2>/dev/null | sed 's/^/   /'
import glob, os, re, subprocess, sys
sys.path.insert(0, '工具')
import importlib.util
spec = importlib.util.spec_from_file_location('a', '工具/audit_screenshots.py')
a = importlib.util.module_from_spec(spec); spec.loader.exec_module(a)
names = a.ledger_names()[:40]
stale = 0; missing = 0
for n in names:
    st = a.source_mtime(n); path, nt = a.newest_shot(n)
    if path is None or st == 0: missing += 1
    elif nt < st: stale += 1
print('抽 %d 款：新 %d、旧 %d、缺 %d' % (len(names), len(names)-stale-missing, stale, missing))
PY

echo
echo "⑥ 仓库与设备"
git status --porcelain | wc -l | tr -d ' ' | sed 's/^/   树脏 /'
df -k /Users | tail -1 | awk '{printf "   磁盘 %.1f GiB\n", $4/1024/1024}'
ps aux | grep -c "[q]emu-system" | tr -d ' ' | sed 's/^/   设备 /'
echo
echo "════════ 完 ════════"
