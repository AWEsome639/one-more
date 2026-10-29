/**
 * A11y —— 无障碍辅助（项目 D ③）
 *
 * ★★★ 为什么要有这个文件（2026-10-29）
 *   全项目有 14 款游戏**只靠颜色**表达关键信息：
 *     色相排序 · 色彩洪水 · 颜色匹配 · 色彩迷宫 · 倒水排序
 *     大师猜谜 · 纸牌 · 双 Trouble · 任务切换 · 视觉搜索
 *     色词匹配 · 威斯康星分类 …
 *   ⇒ 红绿色盲（约 8% 的男性）、全色盲、以及在强光下看屏幕的人，
 *     **这些游戏对他们等于不可玩**。
 *
 * ★ 做法：**颜色 + 字形，双编码**
 *   给每个颜色下标配一个固定的字形（字母 A/B/C…），叠在色块上：
 *     · 看得见颜色的人：字形很小、几乎不打扰（也可以完全不看它）
 *     · 看不见颜色的人：**按字形判断**，玩法与按颜色判断**完全等价**
 *   ⇒ 这不是"给色盲做的阉割版"，而是**同一套玩法多一条通道**。
 *
 * ★ 为什么用字母而不是图案
 *   · 图案（●■▲）在 20~30px 的格子里容易糊，字母更清楚
 *   · 字母与「Mastermind / 猜色」这类经典玩法的记法一致，玩家不用重新学
 *   · 最多支持 8 色（A~H），够用（全项目最多 6~7 色）
 *
 * ★ 使用方式（三行接完）
 *   ① import { A11y } from '../core/A11y';
 *   ② 在色块里叠一层：
 *        Text(A11y.glyph(colorIndex))
 *          .fontSize(A11y.glyphSize(cellPx))
 *          .fontColor(A11y.glyphInk(colorIndex))
 *   ③ 完 —— 玩法逻辑一行不动
 */

/** 8 个颜色的固定字形（下标 → 字母） */
const GLYPHS: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

export class A11y {
  /**
   * 颜色下标 → 字形。
   * 越界时退回数字（不会崩，也不会返回空串）。
   */
  static glyph(colorIndex: number): string {
    if (colorIndex < 0) {
      return '?';
    }
    if (colorIndex < GLYPHS.length) {
      return GLYPHS[colorIndex];
    }
    return String(colorIndex % 10);
  }

  /**
   * 字形该用多大字号（按格子边长算）。
   * ★ 原则：**看得见、但不抢戏** —— 大约格子的 1/3，且夹在 8~20 之间。
   *   太小看不见（对色盲就没用了），太大破坏色块观感。
   */
  static glyphSize(cellPx: number): number {
    const s: number = Math.round(cellPx / 3);
    if (s < 8) {
      return 8;
    }
    if (s > 20) {
      return 20;
    }
    return s;
  }

  /**
   * 字形颜色 —— 永远是白色 + 深色阴影。
   * ★ 为什么不按背景色算对比色：算出来的颜色在某些色块上会不达标；
   *   白色 + 1px 黑色阴影在**任何底色**上都能看清（这是经过验证的通用做法）。
   */
  static glyphInk(colorIndex: number): string {
    return '#FFFFFF';
  }

  /** 字形阴影（白色字在有浅色块上需要它才清楚） */
  static glyphShadow(): ShadowOptions {
    return { radius: 2, color: '#000000B3', offsetX: 0, offsetY: 1 };
  }
}
