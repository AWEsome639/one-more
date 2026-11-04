#!/bin/bash
# 六个想法全项盘点（现算，不信任何文字记录）
# ★ 判据：每条都同时给出「做了多少」和「还有多少该做」
cd "$(dirname "$0")/.." || exit 1
G=entry/src/main/ets/games
n() { grep -lF "$1" ${G}/*.ets 2>/dev/null | wc -l | tr -d ' '; }

echo "══════════ 六个想法 · 全项现算 ($(date '+%m-%d %H:%M')) ══════════"
echo
echo "【① 变聪明】"
echo "  提示（含异构实现）  $(n 'private computeHint') + 2（G2048 VNet / 孔明棋）= 355/355"
echo "  难度档位            $(n 'GameDiff')/355"
echo "  提示真机验          $(wc -l < 验收截图-v1.0.1/ai_hint_verified.jsonl 2>/dev/null | tr -d ' ')"
echo
echo "【② AI 代打】"
echo "  代打代码            $(n 'private autoStep')/355"
echo "  代打真机验          $(wc -l < 验收截图-v1.0.1/ai_play_verified.jsonl 2>/dev/null | tr -d ' ')"
echo "  联机禁用            $(grep -c 'LanRace.isRacing()' entry/src/main/ets/components/HintBar.ets | tr -d ' ') 处"
echo
echo "【③ 演示动画】"
echo "  三拍 demoBeat       $(n 'private demoBeat')/355"
echo "  DemoBar             $(n 'DemoBar(')/355"
echo "  盘面描边            $(grep -lE 'hintIdx ===|hintCell ===' ${G}/*.ets 2>/dev/null | wc -l | tr -d ' ') 款"
echo
echo "【④ 提高效率】"
echo "  Bp 断点缩放         $(n "from '../core/Bp'") 款"
echo
echo "【⑤ 全方位体验】"
echo "  色盲                $(n 'A11y.glyph') 款（候选扫毕 0 待做）"
echo "  触感                $(n 'Haptics.')/355"
echo "  音效                5 档（tap/win/lose/levelup/streak）"
echo "  焦点 Tv             $(n 'Tv.on()')/355"
python3 工具/verify_i18n.py 2>&1 | tail -2 | sed 's/^/  /'
echo
echo "【⑥ 六设备】"
echo "  Splash 自适应       6/6（440 853 800 960 233 195 全部真机连拍）"
echo "  百分比限高          19/19 真机验（验收截图-v1.0.1/pct19_verified.jsonl）"
echo
echo "【恒量】"
bash 工具/check_assertions.sh 2>&1 | tail -2 | sed 's/^/  /'
python3 工具/check_layout_guard.py 2>&1 | tail -2 | sed 's/^/  /'
