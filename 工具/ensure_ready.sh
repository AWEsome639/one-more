#!/usr/bin/env bash
# ============================================================================
#  工具/ensure_ready.sh —— 「按层就绪」检查（判据 942/943/945/946）
#
#  为什么需要它（第 1350~1353 轮四次失败的根因）：
#    `bm clean -d` 清掉了 `privacyAgreed` / `onboarded`
#    ⇒ 之后每次启动都要过 **三层**：
#         ① 开屏动画（约 4s 墙钟，按累计动画帧时间算）
#         ② 「隐私说明」弹窗
#         ③ 「欢迎来到 One More」引导页
#    ⇒ 而 `dump` **同时含两层**（弹窗 + 底层首页）
#    ⇒ 用「dump 里有没有『我收藏的』」判断「在首页」
#      ⇒ **从第一秒就成立** ⇒ 误判 ⇒ 所有点击打在弹窗遮罩上
#
#  判据：
#    942  像素差恒为 0 时，先怀疑「截图没刷新」，而不是「输入无效」
#    943  弹窗盖住时 dump 同时含两层 ⇒ 判断必须**按层优先**
#    945  弹窗文案会污染关键词匹配（引导页里就有「AI 代打」）
#    946  清数据后必须先关弹窗，否则一切点击无效
#
#  用法：
#    bash 工具/ensure_ready.sh onemore3          # 就绪（关掉所有弹窗）
#    bash 工具/ensure_ready.sh onemore3 --check  # 只检查，不改动
#
#  退出码：0 = 已就绪（到了首页/统计/游戏）；1 = 失败
# ============================================================================
set -u
INST="${1:-onemore3}"
CHECK_ONLY=0
[ "${2:-}" = "--check" ] && CHECK_ONLY=1

HC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
A()  { timeout 25 "$HC" -t 127.0.0.1:5555 shell "$@" 2>&1 | tr -d '\r'; }
DUMP() {
  rm -f /tmp/_er.json
  A "uitest dumpLayout -p /data/local/tmp/_er.json" >/dev/null 2>&1
  timeout 15 "$HC" -t 127.0.0.1:5555 file recv /data/local/tmp/_er.json /tmp/_er.json >/dev/null 2>&1
}

# ── 按层判断当前在哪一层（判据 943/945：弹窗特征词优先）─────────────
LAYER() {
  python3 - <<'PY' 2>/dev/null
import json, os
p = '/tmp/_er.json'
if not os.path.exists(p) or os.path.getsize(p) < 500:
    print('UNKNOWN'); raise SystemExit
d = json.load(open(p, encoding='utf-8'))
t = []
def w(x):
    if not isinstance(x, dict): return
    s = (x.get('attributes', {}).get('text') or '').strip()
    if s: t.append(s)
    for c in x.get('children', []) or []: w(c)
w(d)
j = ' '.join(t)
# ① 弹窗层（最高优先）
if '隐私说明' in j or '同意并继续' in j:      print('PRIVACY');  raise SystemExit
if '欢迎来到' in j or '开始玩' in j:          print('ONBOARD');  raise SystemExit
# ② 开屏层
if '碎片时间' in j and '款小游戏' in j:        print('SPLASH');   raise SystemExit
# ③ 页面层
if '演示' in j and '提示' in j and 'AI 代打' in j:
    print('GAME');   raise SystemExit
if '一共玩了' in j:                            print('STATS');    raise SystemExit
if '我收藏的' in j:                            print('HOMEPAGE'); raise SystemExit
if '联系人' in j or '图库' in j:               print('DESKTOP');  raise SystemExit
print('OTHER:' + ' | '.join(t[:5]))
PY
}

# ── 找某个文本的中心坐标 ─────────────────────────────────────────────
XY() {
  python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
want = sys.argv[1]
d = json.load(open('/tmp/_er.json', encoding='utf-8'))
def b(x):
    mm = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', x.get('bounds') or '')
    return tuple(int(v) for v in mm[0]) if mm else None
r = None
def w(n):
    global r
    if not isinstance(n, dict) or r: return
    at = n.get('attributes', {})
    t = (at.get('text') or '').strip()
    if want in t and t and b(at):
        bb = b(at); r = ((bb[0]+bb[2])//2, (bb[1]+bb[3])//2)
    for c in n.get('children', []) or []: w(c)
w(d)
print('%d %d' % r if r else '')
PY
}

echo '══════════════════════════════════════════════════════════'
echo '  按层就绪检查（判据 943/945/946）'
echo '══════════════════════════════════════════════════════════'

for round in 1 2 3 4 5 6; do
  DUMP
  L=$(LAYER)
  printf '  第 %d 轮：%-10s' "$round" "$L"
  case "$L" in
    SPLASH)
      # 开屏：点屏幕中央触发 boost（判据 934：按累计动画帧时间算，墙钟约 4s）
      echo ' ⇒ 点屏幕中央 boost'
      if [ "$CHECK_ONLY" = "0" ]; then A "uitest uiInput click 660 1100" >/dev/null 2>&1; fi
      sleep 2
      ;;
    PRIVACY)
      XYV=$(XY '同意并继续')
      echo " ⇒ 点「同意并继续」@ (\${XYV:-927,1248})"
      if [ "$CHECK_ONLY" = "0" ]; then
        if [ -n "$XYV" ]; then A "uitest uiInput click ${XYV}" >/dev/null 2>&1
        else A "uitest uiInput click 927 1248" >/dev/null 2>&1; fi
      fi
      sleep 2
      ;;
    ONBOARD)
      XYV=$(XY '开始玩')
      echo " ⇒ 点「开始玩」@ (\${XYV:-660,1464})"
      if [ "$CHECK_ONLY" = "0" ]; then
        if [ -n "$XYV" ]; then A "uitest uiInput click ${XYV}" >/dev/null 2>&1
        else A "uitest uiInput click 660 1464" >/dev/null 2>&1; fi
      fi
      sleep 2
      ;;
    HOMEPAGE|STATS|GAME)
      echo ' ⇒ ✅ 已就绪（无弹窗）'
      echo '══════════════════════════════════════════════════════════'
      echo "  ✅ READY: $L"
      exit 0
      ;;
    DESKTOP)
      echo ' ⇒ 🔴 在桌面，不是 app'
      echo '══════════════════════════════════════════════════════════'
      echo '  🔴 NOT_READY: DESKTOP（需要先启动 app）'
      exit 1
      ;;
    *)
      echo ' ⇒ 等待'
      sleep 2
      ;;
  esac
done

DUMP
echo '══════════════════════════════════════════════════════════'
echo "  🔴 NOT_READY: $(LAYER)"
exit 1
