#!/usr/bin/env bash
# ============================================================================
#  工具/verify_ai_game.sh —— **验一款游戏的 AI 代打**（搜索进游戏 + 跑 + 截图）
#
#  ★ 为什么用搜索不用滚动（判据 1210，第 1382 轮）
#    `blink_detector` 在注册表**第 355 条**（最后几条）
#    ⇒ 一次滚动露出 8 张卡 ⇒ 需要 **~44 屏**
#    ⇒ 我原来的 `find_card.sh` 只滚 16 次 —— **数量级就不对**
#    而搜索框实测可用：点 `🔍` 后出现
#      `TextInput [179,381][1242,495]`，占位符「搜游戏名或玩法」
#
#  ★ 判据 1198/1201：中文**不当 shell 参数传** ⇒ 内部 `case` 映射 + `\uXXXX`
#  ★ 判据 1200：本脚本**先过 `check_shell_pitfalls` 再跑**
#
#  用法：bash 工具/verify_ai_game.sh <game_id> [设备名]
#  退出码：0 = 跑完并拿到结算；1 = 失败
# ============================================================================
set -u
HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TAG="$(date +%Y%m%d)"
GID="${1:?用法: verify_ai_game.sh <game_id> [device]}"

# ★ 判据 1198：中文用 \uXXXX，不经过参数
# ★ 判据 1211：macOS 的 /bin/bash 是 **3.2**，`printf '\uXXXX'` **不支持**（会原样打印）
#   ⇒ 用 `python3` 生成 UTF-8（python3 一定在，本项目其它脚本都依赖它）
#   ⛔ 不要用 `$'\uXXXX'`（同样不支持）
mkname() { python3 -c "import sys; print(sys.argv[1].encode().decode('unicode_escape').encode('latin1').decode('utf-8'))" "$1" 2>/dev/null; }
case "$GID" in
  blink_detector)      NAME="$(python3 -c "print(chr(0x7728)+chr(0x773c)+chr(0x68c0)+chr(0x6d4b))")" ;;  # 眨眼检测
  ab_reversal_oddball) NAME="$(python3 -c "print('AB '+chr(0x53CD)+chr(0x8F6C))")" ;;                    # AB 反转
  frequency_tap)       NAME="$(python3 -c "print(chr(0x9891)+chr(0x7387)+chr(0x70B9)+chr(0x51FB))")" ;;  # 频率点击
  *)                   NAME="?" ;;
esac
[ "$NAME" = "?" ] && { echo "🔴 未知 game_id: $GID"; exit 2; }

A() { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
DK() { rm -f /tmp/vg.json; A "uitest dumpLayout -p /data/local/tmp/_vg.json" >/dev/null 2>&1; timeout 20 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_vg.json /tmp/vg.json >/dev/null 2>&1; }
TX() { python3 -c "
import json,os
p='/tmp/vg.json'
if not os.path.exists(p) or os.path.getsize(p)<1000: print(''); raise SystemExit
d=json.load(open(p,encoding='utf-8')); t=[]
def w(x):
    if not isinstance(x,dict): return
    s=(x.get('attributes',{}).get('text') or '').strip()
    if s: t.append(s)
    for c in x.get('children',[]) or []: w(c)
w(d)
print('|'.join(t))
" 2>/dev/null; }
POS() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = sys.argv[1]
d = json.load(open('/tmp/vg.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    t=(at.get('text') or '')
    if want in t and b(at):
        bb=b(at); r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
# ★ 判据 1231：按**卡片文本**找（id 是内部实现，文本是用户看到的）
CARD_BY_TEXT() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = sys.argv[1]
d = json.load(open('/tmp/vg.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    t=(at.get('text') or '').strip()
    if t == want and b(at):
        bb=b(at)
        if bb[1] > 400:
            r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
CARD() { python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = 'card-' + sys.argv[1]
d = json.load(open('/tmp/vg.json', encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if (at.get('id') or '') == want:
        bb=b(at)
        if bb: r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
PY
}
INPUT() { python3 -c "
import json,re
d=json.load(open('/tmp/vg.json',encoding='utf-8'))
def b(x):
    mm=re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r=None
def w(n):
    global r
    if not isinstance(n,dict) or r: return
    at=n.get('attributes',{})
    if (at.get('type') or '')=='TextInput' and b(at):
        bb=b(at); r=((bb[0]+bb[2])//2,(bb[1]+bb[3])//2)
    for c in n.get('children',[]) or []: w(c)
w(d)
print('%d %d'%r if r else '')
" 2>/dev/null | tr -d '\r\n'; }

echo "════════ ${NAME}（${GID}）════════"
# ★★★ 判据 1235：强制冷启 ⇒ 重置所有 @State（searchOpen/searchText/seg/滚动位置）
echo "  冷启（重置 @State）…"
A 'aa force-stop com.andrewoscar.onemore' >/dev/null 2>&1
sleep 2
A 'aa start -b com.andrewoscar.onemore -a EntryAbility' >/dev/null 2>&1
for _t in 3 4 5; do
  sleep $_t
  _pv="$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}')"
  printf '%s' "$_pv" | grep -qE '^[0-9]+$' && break
done
echo "  冷启 pid: [${_pv}]"
sleep 8
# ★★★ 判据 1212/1229：`Back` 在**首页**上会**退出 app**
#   ⇒ 必须先判断当前在哪一页，再决定按不按
DK
CUR_PAGE="$(TX)"
if printf '%s' "$CUR_PAGE" | grep -qE "联系人|拨号|信息|相机"; then
  echo "  ⚠️ 在**系统桌面** ⇒ 重新启动 app（判据 1229）"
  A 'aa start -b com.andrewoscar.onemore -a EntryAbility' >/dev/null 2>&1
  sleep 8
elif printf '%s' "$CUR_PAGE" | grep -qE "AI 代打|重开|再来一局"; then
  echo "  在**游戏内** ⇒ 按一次 Back"
  A 'uitest uiInput keyEvent Back' >/dev/null 2>&1
  sleep 3
else
  echo "  已在**首页** ⇒ 不按 Back（判据 1229）"
fi
bash 工具/ensure_ready.sh onemore3 >/dev/null 2>&1
# ★ 判据 530：启动后必须校验进程活着
PV="$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}')"
if ! printf '%s' "$PV" | grep -qE '^[0-9]+$'; then
  echo "  ⚠️ app 已被退出 ⇒ 重新启动"
  A 'aa start -b com.andrewoscar.onemore -a EntryAbility' >/dev/null 2>&1
  for t in 3 4 5; do
    sleep $t
    PV="$(A 'pidof com.andrewoscar.onemore' 2>/dev/null | head -1 | awk '{print $1}')"
    printf '%s' "$PV" | grep -qE '^[0-9]+$' && break
  done
  echo "  pid: [${PV}]"
  bash 工具/ensure_ready.sh onemore3 >/dev/null 2>&1
fi
DK
C="$(CARD "$GID")"
if [ -z "$C" ]; then
  echo "  卡片不在首屏 ⇒ 用**搜索**（判据 1210）"
  SR="$(POS "🔍")"
  echo "  🔍 @ (${SR:-无})"
  if [ -n "$SR" ]; then
    A "uitest uiInput click ${SR}" >/dev/null 2>&1
    sleep 3; DK
    SB="$(INPUT)"
    echo "  搜索框 @ (${SB:-无})"
    if [ -n "$SB" ]; then
      # ★ 判据 1232：`inputText` 是**追加**不是替换 ⇒ 先清空（Backspace × 12）
      A "uitest uiInput click ${SB}" >/dev/null 2>&1
      sleep 1
      for _b in 1 2 3 4 5 6 7 8 9 10 11 12; do
        A "uitest uiInput keyEvent 2055" >/dev/null 2>&1
      done
      sleep 1; DK
      SB="$(INPUT)"
      A "uitest uiInput inputText ${SB} ${NAME}" >/dev/null 2>&1
      sleep 3; DK
      C="$(CARD "$GID")"
    fi
  fi
fi
echo "  卡片 @ (${C:-无})"
if [ -z "$C" ]; then
  echo "  ── 当前页面前 16 条 ──"
  TX | tr '|' '\n' | head -16 | sed 's/^/    /'
  exit 1
fi
A "uitest uiInput click ${C}" >/dev/null 2>&1
sleep 6
DK
GOT="$(TX)"
if printf '%s' "$GOT" | grep -q "$NAME"; then
  echo "  ✅ 已进入（**核对游戏名**：${NAME}）"
else
  echo "  🔴 **进错游戏**：$(printf '%s' "$GOT" | cut -c1-80)"
  exit 1
fi
# 停演示
for a in 1 2 3; do
  DK
  if TX | grep -q "演示中"; then A "uitest uiInput click 660 300" >/dev/null 2>&1; sleep 2; else break; fi
done
DK
S="$(POS "开始")"
echo "  开始 @ (${S:-无})"
if [ -n "$S" ]; then A "uitest uiInput click ${S}" >/dev/null 2>&1; sleep 2; fi
DK
AI="$(POS "AI 代打")"
echo "  AI 代打 @ (${AI:-无})"
if [ -n "$AI" ]; then A "uitest uiInput click ${AI}" >/dev/null 2>&1; else echo "  🔴 找不到 AI 代打"; exit 1; fi
echo "  等结算…"
for i in $(seq 1 24); do
  sleep 2
  DK
  CUR="$(TX)"
  if printf '%s' "$CUR" | grep -qE "再来一局"; then
    echo "  第 ${i}×2s ⇒ **结算**"
    echo "  $(printf '%s' "$CUR" | cut -c1-185)"
    A "snapshot_display -t png -f /data/local/tmp/_gs.png" >/dev/null 2>&1
    timeout 25 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_gs.png "/tmp/ai_${GID}.png" >/dev/null 2>&1
    if [ -s "/tmp/ai_${GID}.png" ] && [ "$(wc -c < "/tmp/ai_${GID}.png" | tr -d ' ')" -gt 2000 ]; then
      cp "/tmp/ai_${GID}.png" "验收截图-v1.0.1/AI_PLAY_${GID}_440x744_${TAG}.png"
      echo "  📸 ⇒ 验收截图-v1.0.1/AI_PLAY_${GID}_440x744_${TAG}.png"
    fi
    exit 0
  fi
done
echo "  ⚠️ 未结算"
exit 1
