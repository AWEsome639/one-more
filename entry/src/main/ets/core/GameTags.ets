/**
 * 游戏特征定义（自动生成，勿手改）
 *
 * 生成器：tools/gen_tags.py
 * 数据在 GameRegistry 的 GameMeta.tags 里（避免 ArkTS 动态取 Record 的坑）
 */

/** 一个特征 */
export interface GameTag {
  group: string;
  id: string;
  icon: string;
  label: string;
  enLabel: string;
  enGroup: string;
}

/** 全部特征（按组排列） */
export const TAGS: GameTag[] = [
  { group: '时长', id: 'speed', icon: '⚡', label: '30 秒内', enLabel: 'Under 30s', enGroup: 'Length' },
  { group: '时长', id: 'short', icon: '⏱️', label: '1–3 分钟', enLabel: '1-3 min', enGroup: 'Length' },
  { group: '时长', id: 'medium', icon: '🕐', label: '3–10 分钟', enLabel: '3-10 min', enGroup: 'Length' },
  { group: '时长', id: 'long', icon: '⏳', label: '10 分钟以上', enLabel: '10 min+', enGroup: 'Length' },
  { group: '难度', id: 'easy', icon: '🌱', label: '轻松', enLabel: 'Relaxed', enGroup: 'Difficulty' },
  { group: '难度', id: 'normal', icon: '⚖️', label: '普通', enLabel: 'Standard', enGroup: 'Difficulty' },
  { group: '难度', id: 'hard', icon: '🔥', label: '烧脑', enLabel: 'Brain-bender', enGroup: 'Difficulty' },
  { group: '操作', id: 'tap', icon: '👆', label: '点按', enLabel: 'Tap', enGroup: 'Controls' },
  { group: '操作', id: 'swipe', icon: '👉', label: '滑动', enLabel: 'Swipe', enGroup: 'Controls' },
  { group: '操作', id: 'drag', icon: '✋', label: '拖拽', enLabel: 'Drag', enGroup: 'Controls' },
  { group: '操作', id: 'type', icon: '⌨️', label: '输入', enLabel: 'Type', enGroup: 'Controls' },
  { group: '节奏', id: 'timed', icon: '⏰', label: '有时间压力', enLabel: 'Against the clock', enGroup: 'Pace' },
  { group: '节奏', id: 'untimed', icon: '🧘', label: '不限时', enLabel: 'No timer', enGroup: 'Pace' },
  { group: '节奏', id: 'pausable', icon: '🚌', label: '随时可停', enLabel: 'Pause anytime', enGroup: 'Pace' },
  { group: '脑力', id: 'calc', icon: '🧮', label: '计算', enLabel: 'Numbers', enGroup: 'Skills' },
  { group: '脑力', id: 'memory', icon: '🧠', label: '记忆', enLabel: 'Memory', enGroup: 'Skills' },
  { group: '脑力', id: 'word', icon: '🔤', label: '语言', enLabel: 'Words', enGroup: 'Skills' },
  { group: '脑力', id: 'space', icon: '📐', label: '空间', enLabel: 'Spatial', enGroup: 'Skills' },
  { group: '脑力', id: 'logic', icon: '🧩', label: '逻辑', enLabel: 'Logic', enGroup: 'Skills' },
  { group: '脑力', id: 'focus', icon: '🎯', label: '专注力', enLabel: 'Focus', enGroup: 'Skills' },
  { group: '场景', id: 'onehand', icon: '👍', label: '单手可玩', enLabel: 'One hand', enGroup: 'Vibe' },
  { group: '场景', id: 'endless', icon: '♾️', label: '可无限玩', enLabel: 'Endless', enGroup: 'Vibe' },
  { group: '场景', id: 'zen', icon: '🌸', label: '解压放松', enLabel: 'Wind down', enGroup: 'Vibe' },
  { group: '场景', id: 'brainy', icon: '🎓', label: '烧脑挑战', enLabel: 'Challenge', enGroup: 'Vibe' },
  { group: '场景', id: 'cozy', icon: '🛋️', label: '躺着玩', enLabel: 'Cosy', enGroup: 'Vibe' },
];

/** 分组清单（按出现顺序） */
export function tagsByGroup(): string[] {
  const out: string[] = [];
  for (let i = 0; i < TAGS.length; i++) {
    const g: string = TAGS[i].group;
    if (out.indexOf(g) < 0) {
      out.push(g);
    }
  }
  return out;
}

/** 某组下的特征 */
export function tagsIn(group: string): GameTag[] {
  const out: GameTag[] = [];
  for (let i = 0; i < TAGS.length; i++) {
    if (TAGS[i].group === group) {
      out.push(TAGS[i]);
    }
  }
  return out;
}
