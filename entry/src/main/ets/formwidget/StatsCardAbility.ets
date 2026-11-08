/**
 * 「一局」桌面服务卡片 —— 把等级与打卡摆到桌面上
 *
 * 卡片显示：等级 / 称号 / 今日打卡 / 连胜 / XP 进度
 * 点卡片直达主页，随手来一局。
 */

import { formBindingData, FormExtensionAbility, formProvider, formInfo } from '@kit.FormKit';
import { Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
// ★★★ 2026-11-08（成就体系巡检 P1）：等级曲线唯一真相源（纯数学、零依赖 ⇒ 可安全带进 Form 进程）
import { LevelCurve } from '../core/LevelCurve';

const DOMAIN = 0x0001;
const TAG = 'StatsCard';
const STORE = 'onemore_progress';

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
  // ★★★ 2026-11-08（UI 一致性审计 ③ 续）：**界面模式**（normal / elder / simple）
  //   卡片在自己的 Form 渲染进程里跑，**看不到主进程的 AppStorage** ⇒ 必须由 Ability
  //   从 preferences 读出来、随 formBindingData 一起注入，卡片再 `UiModeMgr.apply()`。
  uiMode: string;
  // ★★★ 2026-11-08（StatsCard 巡检 ③）：**卡片的尺寸规格**（'2*2' / '2*4' / '2*3' / '3*3' …）
  //   卡片在 Form 渲染进程里**拿不到 Bp**（Bp 只由 App 主进程的 WindowStage 初始化）⇒
  //   判断"是不是手表卡"只能靠这个字段（官方做法：onAddForm 读 DIMENSION_KEY 再注入）。
  dim: string;
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

/**
 * 同步读「界面模式」—— 卡片首帧就要用，等不了异步。
 * 与 `lang` 同一个库（`onemore_progress`）、同一套写法；读不到就 'normal'（绝不阻塞出画面）。
 */
function readUiModeSync(ctx: common.Context): string {
  try {
    const opt: preferences.Options = { name: STORE };
    const pr: preferences.Preferences = preferences.getPreferencesSync(ctx, opt);
    const m: string = pr.getSync('uiMode', '') as string;
    return (m === 'elder' || m === 'simple') ? m : 'normal';
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'readUiMode failed: %{public}s', JSON.stringify(e));
    return 'normal';
  }
}

/**
 * ★★★ 2026-11-08（③ 手表适配）：`formInfo.FormDimension` 枚举 → `'2*3'` 这种可读规格。
 * 数值取自 SDK `@ohos.app.form.formInfo.d.ts`：1_2=1 / 2_2=2 / 2_4=3 / 4_4=4 / 1_1=6 / 6_4=7 / 2_3=8 / 3_3=9
 */
function dimName(d: number): string {
  if (d === formInfo.FormDimension.Dimension_1_2) { return '1*2'; }
  if (d === formInfo.FormDimension.Dimension_2_2) { return '2*2'; }
  if (d === formInfo.FormDimension.Dimension_2_4) { return '2*4'; }
  if (d === formInfo.FormDimension.Dimension_4_4) { return '4*4'; }
  if (d === formInfo.FormDimension.DIMENSION_1_1) { return '1*1'; }
  if (d === formInfo.FormDimension.DIMENSION_6_4) { return '6*4'; }
  if (d === formInfo.FormDimension.DIMENSION_2_3) { return '2*3'; }
  if (d === formInfo.FormDimension.DIMENSION_3_3) { return '3*3'; }
  return '2*2';
}

/**
 * 从 `want` 里取卡片尺寸（官方《如何根据不同尺寸的卡片适配不同的UI / faqs-form-19》的做法）。
 * ⚠️ `want.parameters` 的值类型不稳定（number / string 都可能）⇒ 先 JSON.stringify 再 Number，
 *    这是官方示例里的写法，最稳。
 */
function readDim(want: Want): string {
  try {
    if (!want.parameters) {
      return '2*2';
    }
    const raw: string = JSON.stringify(want.parameters[formInfo.FormParam.DIMENSION_KEY]);
    const n: number = Number(raw);
    return isNaN(n) ? '2*2' : dimName(n);
  } catch (e) {
    return '2*2';
  }
}

/** 从 `want` 里取 formId（更新卡片时要按 id 找回尺寸） */
function readFormId(want: Want): string {
  try {
    if (!want.parameters) {
      return '';
    }
    const raw: string = JSON.stringify(want.parameters[formInfo.FormParam.IDENTITY_KEY]);
    return raw === undefined || raw === 'undefined' ? '' : raw;
  } catch (e) {
    return '';
  }
}

function defaults(): CardStats {
  const d: CardStats = {
    level: '1', title: '新手上路', streak: '0',
    today: '今天还没玩', solved: '0', xp: '0', pct: '0',
    footer: '累计 0 局 · 点我开一局', done: '0',
    uiMode: 'normal', dim: '2*2'
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

async function readStats(ctx: common.Context, dim: string): Promise<CardStats> {
  const out: CardStats = defaults();
  out.dim = dim;
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
      // ★★★ 2026-11-08：原来这里把公式**又抄了一遍**（1/2.04），一旦 ProgressStore 改曲线，
      //   桌面卡片就会和 App 显示**不一样的等级**。现在两边都走 `LevelCurve`。
      : LevelCurve.levelOf(xp);
    // ★★★ 2026-11-08：进度条的两个端点原来**也各写了一遍 2.04** —— 同一个坑。
    //   现在统一走 `LevelCurve`（它内部还处理了"99 级 hi<=lo 时进度条永远满格"那个 bug）。
    const lo: number = LevelCurve.xpForLevel(level);
    const hi: number = LevelCurve.xpForLevel(level + 1);
    const pct: number = Math.round(LevelCurve.progress(xp) * 100);

    out.level = String(level);
    out.title = levelTitle(level);
    out.streak = String(alive ? streakRaw : 0);
    out.today = playedToday ? '今日已打卡' : '今天还没玩';
    out.solved = String(total);
    out.xp = String(xp);
    out.pct = String(pct);
    // ★ 2026-11-08：界面模式（大字/简约）—— 卡片据此调 UiModeMgr.apply
    //   这里**复用已有的 `p` 句柄**（不另开一个，避免同一库两个实例各自缓存）
    const modeRaw: string = p.getSync('uiMode', '') as string;
    out.uiMode = (modeRaw === 'elder' || modeRaw === 'simple') ? modeRaw : 'normal';
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'readStats failed: %{public}s', JSON.stringify(e));
  }
  return out;
}

export default class StatsCardAbility extends FormExtensionAbility {
  /**
   * ★★★ 2026-11-08（③）：**formId → 尺寸规格** 的记忆。
   *
   *   `onUpdateForm(formId)` / `onFormVisible(formId)` 这两个回调**只给 formId，不给 want**
   *   ⇒ 刷新时没法再问系统"这张卡多大"。所以在 `onAddForm` 时记下来，刷新时按 id 取回。
   *   取不到就退回 `'2*2'`（桌面默认卡），最坏是"手表卡按桌面样式画"，不会崩。
   */
  private dims: Map<string, string> = new Map<string, string>();

  /** 卡片被加到桌面：先给默认值，保证立刻出画面 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onAddForm');
    const d: CardStats = defaults();
    // ★ 首帧就按用户的界面模式出画面，避免"先小字再跳大字"
    d.uiMode = readUiModeSync(this.context);
    // ★ ③：首帧就带上尺寸，卡片据此选「桌面版 / 手表版」布局
    d.dim = readDim(want);
    const fid: string = readFormId(want);
    if (fid.length > 0) {
      this.dims.set(fid, d.dim);
    }
    hilog.info(DOMAIN, TAG, 'onAddForm dim=%{public}s id=%{public}s', d.dim, fid);
    return formBindingData.createFormBindingData(d);
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
    // ★ ③：按 id 取回这张卡的尺寸（取不到退回桌面默认）
    const dim: string = this.dims.get(formId) ?? '2*2';
    readStats(this.context, dim).then((data: CardStats) => {
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
