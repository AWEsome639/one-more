#!/usr/bin/env bash
# ============================================================================
#  工具/smoke_six.sh —— **六设备冒烟回归**：每台装机 + 冷启 + 验首页渲染
#
#  ★ 为什么要有（判据 1183，第 1379 轮）
#    第 1371~1378 轮我改了 `GamesTab.ets`（日卡分支）+ `ProgressStore.ets`
#    （ensureDaily 完整性检查）+ 3 款游戏的代打（事件驱动）。
#    单点验证都通过了，**但改动的影响面是全局的**：
#      · `GamesTab` 是首页 —— 六台设备都会走它
#      · `ProgressStore.init()` 每次启动都跑 —— 写坏了会丢全部进度
#      · 3 款游戏的 `onBeat`/`tick` 里加了一句 —— 只在进那三款时生效
#    ⇒ 必须**六台各跑一遍**，而不是「某几台验过就算」。
#
#  ★ 冒烟判据（每台五条，缺一即 FAIL）：
#    ① `install` 成功且 `bm dump -a` 能查到
#    ② `aa start` 后 `pidof` 是**纯数字**（判据 530）
#    ③ 冷启后 dump **节点数 ≥ 40**（空页/白屏会远低于此）
#    ④ 含标题 `One More`（首页确实渲染了）
#    ⑤ 无 `jscrash`（崩溃日志）
#    ⚠️ 不判「日卡在不在」—— 那依赖分支（展开/收起/极小屏），已在 1374/1375/1377 单独验过
#
#  ★ 用法：bash 工具/smoke_six.sh [设备名...]
#    省略参数 = 六台全跑
#  退出码：0 = 全过；1 = 有失败（会打印失败项）
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
HAP="entry/build/default/outputs/default/entry-default-signed.hap"
OUTDIR="/tmp/smoke_six"
mkdir -p "$OUTDIR"

ALL="onemore:853x533 onemore2:800x1280 onemore3:440x744 onemore4:233x233 onemore5:960x540 onemore6:195x195"
if [ "$#" -gt 0 ]; then
  LIST=""
  for a in "$@"; do
    for kv in $ALL; do
      case "$kv" in "$a":*) LIST="$LIST $kv";; esac
    done
  done
else
  LIST="$ALL"
fi

A() { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
STOP_ALL() { for X in $(ps aux | grep '[E]mulator' | grep -v grep | awk '{print $2}'); do kill -TERM "$X" 2>/dev/null; done; sleep 5; timeout 8 "$HC" kill -r >/dev/null 2>&1; }

PASS=0; FAIL=0; FAILED=""

for kv in $LIST; do
  INST="${kv%%:*}"; TAG="${kv##*:}"
  echo "════════════════════════════════════════════════════"
  echo "  ${INST}（${TAG}）"
  echo "════════════════════════════════════════════════════"
  F="$OUTDIR/${TAG}.json"
  ERR=""

  STOP_ALL
  sleep 2
  nohup "$EMU" -start "$INST" > "$OUTDIR/${INST}.log" 2>&1 &

  OK=0
  for a in 1 2 3; do
    R=$(bash 工具/start_app_on_device.sh "$INST" 2>&1); RC=$?
    echo "  起机第 $a 次: $(echo "$R" | tail -1 | cut -c1-40)"
    [ "$RC" = "0" ] && { OK=1; break; }
    STOP_ALL; sleep 20
    nohup "$EMU" -start "$INST" > "$OUTDIR/${INST}.log" 2>&1 &
  done
  if [ "$OK" != "1" ]; then
    echo "  🔴 起机失败"
    FAIL=$((FAIL+1)); FAILED="$FAILED $TAG(起机)"; continue
  fi

  # ① 装机
  timeout 1200 "$HC" -t 127.0.0.1:5555 install -r "$HAP" > "$OUTDIR/${INST}_install.log" 2>&1
  CNT=$(A 'bm dump -a 2>/dev/null | grep -c "com.andrewoscar.onemore"' | tr -d ' ')
  echo "  ① 装机: ${CNT:-0}"
  [ "${CNT:-0}" -lt 1 ] && ERR="$ERR 装机失败;"

  # ② 冷启 + pidof
  A 'aa force-stop com.andrewoscar.onemore' >/dev/null 2>&1
  sleep 2
  A 'aa start -b com.andrewoscar.onemore -a EntryAbility' >/dev/null 2>&1
  P=""
  for t in 3 4 5; do
    sleep $t; P=$(A "pidof com.andrewoscar.onemore" | head -1 | awk '{print $1}')
    printf '%s' "$P" | grep -qE '^[0-9]+$' && break
  done
  echo "  ② pid: [${P:-空}]"
  printf '%s' "$P" | grep -qE '^[0-9]+$' || ERR="$ERR 进程未起;"

  sleep 12

  # ③④ dump 判据
  rm -f "$F"
  A "uitest dumpLayout -p /data/local/tmp/_smk.json" >/dev/null 2>&1
  timeout 20 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_smk.json "$F" >/dev/null 2>&1
  # 判据 812/1099/1187：用 `-s`（**存在且非空**）而不是 `-f`
  #   ⇒ `-f` 只判存在，空壳/旧文件会混过去；`-s` 同时判「非空」
  #   ⇒ 再加一道 ≥3000 的实质门槛（dump 正常在 7 万字节以上）
  if [ -s "$F" ] && [ "$(wc -c < "$F" 2>/dev/null | tr -d ' ')" -ge 3000 ]; then
    RES=$(python3 - "$F" <<'PY'
import json, os, sys
p = sys.argv[1]
try:
    d = json.load(open(p, encoding='utf-8'))
except Exception:
    print('0|0|0'); raise SystemExit
n = 0; texts = []
def w(x):
    global n
    if not isinstance(x, dict): return
    n += 1
    t = (x.get('attributes', {}).get('text') or '').strip()
    if t: texts.append(t)
    for c in x.get('children', []) or []: w(c)
w(d)
print('%d|%d|%d' % (n, len(texts), 1 if any('One More' in t for t in texts) else 0))
PY
)
    NODES=$(echo "$RES" | cut -d'|' -f1)
    TEXTS=$(echo "$RES" | cut -d'|' -f2)
    HAS_TITLE=$(echo "$RES" | cut -d'|' -f3)
    echo "  ③ 节点 $NODES ｜ 文本 $TEXTS"
    [ "${NODES:-0}" -lt 40 ] && ERR="$ERR 节点过少($NODES);"
    echo "  ④ 标题 One More: $([ "$HAS_TITLE" = "1" ] && echo ✅ || echo 🔴)"
    [ "$HAS_TITLE" != "1" ] && ERR="$ERR 无标题;"
  else
    echo "  ③ dump 失败"
    ERR="$ERR dump失败;"
  fi

  # ⑤ 崩溃日志（判据 1185：**faultlogger 不会自动清理** ⇒ 只算**当天**的）
  #   旧日志（昨天/上周）与本次启动无关 —— 只在今天这个日期里数
  TODAY_=$(A 'date +%Y%m%d' | tr -d '\r\n ')
  CR=$(A "ls /data/log/faultlog/faultlogger/ 2>/dev/null | grep 'com.andrewoscar.onemore' | grep -c \"${TODAY_}\"" | tr -d ' ')
  CRALL=$(A 'ls /data/log/faultlog/faultlogger/ 2>/dev/null | grep -c "com.andrewoscar.onemore"' | tr -d ' ')
  echo "  ⑤ 崩溃日志: 今日 ${CR:-0} ／ 历史共 ${CRALL:-0}"
  if [ "${CR:-0}" -gt 0 ]; then
    echo "     今日的："
    A "ls -la /data/log/faultlog/faultlogger/ 2>/dev/null | grep 'com.andrewoscar.onemore' | grep \"${TODAY_}\"" | sed 's/^/       /'
    ERR="$ERR 今日有崩溃(${CR});"
  fi

  printf '%s' "$P" | grep -qE '^[0-9]+$' && A "snapshot_display -t png -f /data/local/tmp/_smk.png" >/dev/null 2>&1
  timeout 25 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_smk.png "$OUTDIR/${TAG}.png" >/dev/null 2>&1

  if [ -z "$ERR" ]; then
    echo "  ✅ **PASS**"
    PASS=$((PASS+1))
  else
    echo "  🔴 **FAIL**:$ERR"
    FAIL=$((FAIL+1)); FAILED="$FAILED $TAG($ERR)"
  fi
  echo
done

STOP_ALL
echo "════════════════════════════════════════════════════"
echo "  冒烟结果：**PASS $PASS ／ FAIL $FAIL**"
[ -n "$FAILED" ] && echo "  失败项:$FAILED"
echo "  产物: $OUTDIR"
echo "════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
