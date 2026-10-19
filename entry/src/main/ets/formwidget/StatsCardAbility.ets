/**
 * 「一局」桌面服务卡片 —— 把等级与打卡摆到桌面上
 *
 * 卡片显示：等级 / 称号 / 今日打卡 / 连胜 / XP 进度
 * 点卡片直达主页，随手来一局。
 */

import { formBindingData, FormExtensionAbility, formProvider } from '@kit.FormKit';
import { Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0001;
const TAG = 'StatsCard';
const STORE = 'yiju_progress';

/** 卡片数据（显式接口，ArkTS 不许无类型对象字面量） */
interface CardStats {
  level: string;
  title: string;
  streak: string;
  today: string;
  solved: string;
  xp: string;
  pct: string;
  footer: string;      // ★ 卡片底部文案（Ability 已本地化）
  done: string;        // ★ '1' 今日已打卡 / '0' 还没玩 —— 卡片不再靠中文「已」字判断
}


// ═══════════════════════════════════════════════════════════════════
// 卡片文案本地化（2026-10-19 全面自查 A2）
//
// 为什么放在 Ability 而不是卡片里：
//   服务卡片是独立进程/独立页面，塞不进主应用的 3113 条 I18n 表（体积）⇒
//   ★ 正确架构：Ability 负责"翻译成字符串"，卡片只负责"显示字符串"。
//
// 语言从 preferences 的 'lang' 读（ProgressStore 写的就是这个 key）。
// 查不到就退英文；英文也没配就退中文原文。
// ═══════════════════════════════════════════════════════════════════

/** 连胜/打卡两态 */
const T_TODAY_YET: Record<string, string> = {
  'zh': '今天还没玩', 'zh-Hant': '今天還沒玩', 'en': 'Not played today',
  'ja': '今日はまだ', 'ko': '오늘 아직 안 함', 'fr': 'Pas encore joué',
  'de': 'Heute noch nicht', 'es': 'Sin jugar hoy', 'ru': 'Сегодня ещё нет',
  'ar': 'لم تلعب اليوم', 'pt': 'Ainda não jogou', 'it': 'Non ancora giocato'
};
const T_TODAY_DONE: Record<string, string> = {
  'zh': '今日已打卡', 'zh-Hant': '今日已打卡', 'en': 'Checked in today',
  'ja': '今日クリア', 'ko': '오늘 완료', 'fr': 'Fait aujourd’hui',
  'de': 'Heute erledigt', 'es': 'Hecho hoy', 'ru': 'Сегодня есть',
  'ar': 'أُنجز اليوم', 'pt': 'Feito hoje', 'it': 'Fatto oggi'
};

/** 卡片底部一行：累计 X 局 · 点我开一局 */
const T_FOOTER: Record<string, string> = {
  'zh': '累计 {n} 局 · 点我开一局', 'zh-Hant': '累計 {n} 局 · 點我開一局',
  'en': '{n} rounds · tap to play', 'ja': '通算 {n} 回 · タップで開始',
  'ko': '누적 {n}판 · 탭하여 시작', 'fr': '{n} parties · appuyez pour jouer',
  'de': '{n} Runden · tippen zum Spielen', 'es': '{n} partidas · toca para jugar',
  'ru': 'Раундов: {n} · нажмите', 'ar': '{n} جولة · اضغط للعب',
  'pt': '{n} rondas · toque para jogar', 'it': '{n} partite · tocca per giocare'
};

/** 称号七档（下标 0 最低） */
const T_TIERS: Record<string, string[]> = {
  'zh': ['新手上路', '初窥门径', '渐入佳境', '小有所成', '益智达人', '解谜高手', '游戏宗师'],
  'zh-Hant': ['新手上路', '初窺門徑', '漸入佳境', '小有所成', '益智達人', '解謎高手', '遊戲宗師'],
  'en': ['Getting started', 'First steps', 'Finding form', 'Getting good', 'Puzzle adept', 'Puzzle expert', 'Grandmaster'],
  'ja': ['はじめの一歩', '入口に立つ', '調子が出る', 'なかなか', 'パズル達人', 'パズル名人', 'グランドマスター'],
  'ko': ['첫걸음', '입문', '감 잡음', '제법', '퍼즐 달인', '퍼즐 고수', '그랜드마스터'],
  'fr': ['Débutant', 'Premiers pas', 'En forme', 'Bon niveau', 'Adepte', 'Expert', 'Grand maître'],
  'de': ['Einsteiger', 'Erste Schritte', 'In Form', 'Gut dabei', 'Rätselprofi', 'Experte', 'Großmeister'],
  'es': ['Principiante', 'Primeros pasos', 'En forma', 'Buen nivel', 'Adepto', 'Experto', 'Gran maestro'],
  'ru': ['Новичок', 'Первые шаги', 'В форме', 'Хорошо', 'Знаток', 'Эксперт', 'Гроссмейстер'],
  'ar': ['مبتدئ', 'خطوات أولى', 'في تحسّن', 'جيد', 'بارع', 'خبير', 'أستاذ كبير'],
  'pt': ['Iniciante', 'Primeiros passos', 'Em forma', 'Bom nível', 'Adepto', 'Especialista', 'Grão-mestre'],
  'it': ['Principiante', 'Primi passi', 'In forma', 'Buon livello', 'Adepto', 'Esperto', 'Gran maestro']
};

/** 按语言取字符串：缺项退英文，再缺退中文 */
function pick(table: Record<string, string>, lang: string, zh: string): string {
  const hit: string | undefined = table[lang];
  if (hit !== undefined) {
    return hit;
  }
  const en: string | undefined = table['en'];
  return en !== undefined ? en : zh;
}

/** 按语言取称号 */
function pickTier(level: number, lang: string): string {
  let tier: number = 0;
  if (level >= 60) { tier = 6; }
  else if (level >= 40) { tier = 5; }
  else if (level >= 25) { tier = 4; }
  else if (level >= 15) { tier = 3; }
  else if (level >= 8) { tier = 2; }
  else if (level >= 3) { tier = 1; }
  const row: string[] | undefined = T_TIERS[lang];
  const use: string[] | undefined = row !== undefined ? row : T_TIERS['en'];
  if (use !== undefined && use.length > tier) {
    return use[tier];
  }
  return levelTitle(level);
}

function defaults(): CardStats {
  const d: CardStats = {
    level: '1', title: '新手上路', streak: '0',
    today: '今天还没玩', solved: '0', xp: '0', pct: '0',
    footer: '累计 0 局 · 点我开一局', done: '0'
  };
  return d;
}

function pad2(n: number): string {
  return (n < 10 ? '0' : '') + n;
}

function todayStr(): string {
  const d: Date = new Date();
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

function isYesterday(last: string, today: string): boolean {
  if (!last) {
    return false;
  }
  const a: string[] = last.split('-');
  const b: string[] = today.split('-');
  if (a.length !== 3 || b.length !== 3) {
    return false;
  }
  const ta: number = new Date(Number(a[0]), Number(a[1]) - 1, Number(a[2])).getTime();
  const tb: number = new Date(Number(b[0]), Number(b[1]) - 1, Number(b[2])).getTime();
  return Math.round((tb - ta) / 86400000) === 1;
}

function levelTitle(l: number): string {
  if (l >= 60) {
    return '游戏宗师';
  }
  if (l >= 40) {
    return '解谜高手';
  }
  if (l >= 25) {
    return '益智达人';
  }
  if (l >= 15) {
    return '小有所成';
  }
  if (l >= 8) {
    return '渐入佳境';
  }
  if (l >= 3) {
    return '初窥门径';
  }
  return '新手上路';
}

async function readStats(ctx: common.Context): Promise<CardStats> {
  const out: CardStats = defaults();
  try {
    const p: preferences.Preferences = await preferences.getPreferences(ctx, STORE);
    const xp: number = p.getSync('xp', 0) as number;
    const total: number = p.getSync('totalSolved', 0) as number;
    const streakRaw: number = p.getSync('superStreak', 0) as number;
    const lastDay: string = p.getSync('lastDay', '') as string;

    const today: string = todayStr();
    const playedToday: boolean = lastDay === today;
    // 断档超过一天就不显示旧连胜数字
    const alive: boolean = playedToday || isYesterday(lastDay, today);

    const level: number = xp <= 0 ? 1
      : Math.min(100, Math.max(1, Math.floor(Math.pow(xp / 100, 1 / 2.04)) + 1));
    const lo: number = level <= 1 ? 0 : Math.floor(100 * Math.pow(level - 1, 2.04));
    const hi: number = Math.floor(100 * Math.pow(level, 2.04));
    const pct: number = hi <= lo ? 100 : Math.min(100, Math.max(0, Math.round(((xp - lo) / (hi - lo)) * 100)));

    out.level = String(level);
    out.title = levelTitle(level);
    out.streak = String(alive ? streakRaw : 0);
    out.today = playedToday ? '今日已打卡' : '今天还没玩';
    out.solved = String(total);
    out.xp = String(xp);
    out.pct = String(pct);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'readStats failed: %{public}s', JSON.stringify(e));
  }
  return out;
}

export default class StatsCardAbility extends FormExtensionAbility {
  /** 卡片被加到桌面：先给默认值，保证立刻出画面 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onAddForm');
    return formBindingData.createFormBindingData(defaults());
  }

  /** 卡片出现在桌面时刷新 */
  onFormVisible(formId: string): void {
    this.push(formId);
  }

  /** 系统定时拉起刷新 */
  onUpdateForm(formId: string): void {
    this.push(formId);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm: %{public}s', formId);
  }

  /** 读真实进度 → 推给指定卡片 */
  private push(formId: string): void {
    readStats(this.context).then((data: CardStats) => {
      try {
        const bind: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
        formProvider.updateForm(formId, bind).catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'updateForm: %{public}s', JSON.stringify(e));
        });
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'bind failed: %{public}s', JSON.stringify(e));
      }
    });
  }
}
