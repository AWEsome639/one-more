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
}

function defaults(): CardStats {
  const d: CardStats = {
    level: '1', title: '新手上路', streak: '0',
    today: '今天还没玩', solved: '0', xp: '0', pct: '0'
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
