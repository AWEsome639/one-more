#!/bin/bash
# rebuild_release_app.sh —— 重出 release .app 并核对元数据
#
# 为什么要有这个脚本（判据 3092 / 3077 / 3081）：
#   1. `build-profile.json5` 要临时换成 release 签名配置，**复位必须用 `git checkout`**
#      （用 `cp` 复位会失败：Read-only file system）
#   2. `.app` 的版本号在 `pack.info` 的 `summary.app.version`，
#      而 `minAPIVersion` **不在 pack.info 里** —— 必须抽出内层 `.hap` 读 `module.json`
#   3. 构建必须**前台**跑，且出完必须核对「字节 + mtime」都变（判据 3092）
#
# 用法：bash 工具/rebuild_release_app.sh
#   前置：工作区干净（`git status` 无改动）、无需模拟器
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)
HV=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
APP="build/outputs/default/One More-default-signed.app"

echo "== 0. 前置检查 =="
if [ -n "$(git status --porcelain)" ]; then
  echo "  ⛔ 工作区不干净，先提交或回滚："; git status --short | head -5; exit 1
fi
echo "  ✅ 工作区干净"

BEFORE=""
[ -f "$APP" ] && BEFORE=$(ls -l "$APP" | awk '{print $5"-"$8}')

echo "== 1. 换 release 签名配置 =="
cp build-profile.json5 /tmp/bp.rebuild.bak
cp build-profile.json5.release-signed build-profile.json5 || { cp /tmp/bp.rebuild.bak build-profile.json5; exit 1; }

echo "== 2. 前台构建（判据 3092：不要 nohup &）=="
timeout 900 "$HV" --no-daemon assembleApp -p product=default -p buildMode=release 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' | grep -E "BUILD (SUCCESSFUL|FAILED)|error:" | head -3

echo "== 3. 复位配置（必须 git checkout）=="
git checkout -- build-profile.json5
echo "  keyAlias 现在是: $(grep -o '"keyAlias": "[^"]*"' build-profile.json5 | head -1)"

echo "== 4. 核对产物 =="
if [ ! -f "$APP" ]; then echo "  ⛔ 没有产物"; exit 1; fi
AFTER=$(ls -l "$APP" | awk '{print $5"-"$8}')
echo "  构建前: ${BEFORE:-<无>}"
echo "  构建后: $AFTER"
[ "$BEFORE" = "$AFTER" ] && echo "  ⚠️ 字节与时间都没变 ⇒ 构建没生效（判据 3092），不要发这个包" || echo "  ✅ 产物已更新"

python3 - "$APP" <<'PY'
import json, subprocess, sys, tempfile, zipfile, os
app = sys.argv[1]
with zipfile.ZipFile(app) as z:
    info = json.loads(z.open('pack.info').read().decode('utf-8'))
    a = (info.get('summary') or {}).get('app') or {}
    v = a.get('version') or {}
    print('  包名      :', a.get('bundleName'))
    print('  版本      :', v.get('name'), '(', v.get('code'), ')')
    inner = [n for n in z.namelist() if n.endswith('.hap')]
    if inner:
        with tempfile.TemporaryDirectory() as td:
            p = z.extract(inner[0], td)
            with zipfile.ZipFile(p) as z2:
                m = json.loads(z2.open('module.json').read().decode('utf-8'))['app']
                print('  minAPI    :', m.get('minAPIVersion'), '（期望 60000020）')
PY

echo "== 5. 归档 =="
TS=$(date '+%Y%m%d-%H%M')
OUT="release/onemore-$(python3 -c "
import json,zipfile,sys
z=zipfile.ZipFile('$APP'); a=json.loads(z.open('pack.info').read().decode())['summary']['app']
print(a['version']['name'])" )-release-signed-${TS}.app"
cp "$APP" "$OUT"
cp "$OUT" ~/Desktop/"One More正式签名包.app"
echo "  归档: $OUT ($(ls -l "$OUT" | awk '{print $5}') 字节)"
echo "  桌面已同步"
echo
echo "== 6. 交付完整性 =="
python3 工具/check_deliverables.py 2>&1 | tail -1
