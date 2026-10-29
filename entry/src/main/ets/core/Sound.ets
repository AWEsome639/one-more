/**
 * Sound —— 音效（项目 D ④ 反馈层）
 *
 * ★★★ 为什么要有这个文件（2026-10-29）
 *   全项目 `grep audio` **零命中** —— 355 款游戏、1178 个可点元素，
 *   **一声都不响**。有触感（Haptics 355/355 都有），但完全没有听觉反馈。
 *
 * ★ 设计原则（按重要性排）
 *   1. **绝不打断游戏**：播放失败、资源缺失、权限不足 ⇒ **静默跳过**
 *      ，一个字都不许报给用户。音效是锦上添花，不是功能。
 *   2. **默认开、可关**：`AppStorage('soundOn')`，设置页有开关
 *   3. **短**：最长的 win.wav 也只有 0.42 秒。游戏节奏快，长音效会烦。
 *   4. **和触感同源**：Haptics 在哪响，Sound 就在哪响（成败要分得出来）
 *
 * ★ 为什么用 SoundPool 而不是 AVPlayer
 *   · SoundPool 专为**短促音效**设计：预加载到内存、低延迟、可并发
 *   · AVPlayer 是给长音频（音乐/视频）用的，每次播放要 prepare，延迟明显
 *   · 这里的音效都是几十~几百毫秒，SoundPool 正合适
 *
 * ★ 资源
 *   entry/src/main/resources/rawfile/sfx/{tap,win,lose}.wav
 *   都是 22050Hz / 16bit / 单声道，用 Python 生成的正弦波（没有版权问题）
 */

import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'Sound';

export class Sound {
  /** 是否已初始化（成功才算） */
  private static ready: boolean = false;
  /** SoundPool 实例 */
  private static pool: media.SoundPool | undefined = undefined;
  /** 三个音效的 id（0 = 未加载） */
  private static idTap: number = 0;
  private static idWin: number = 0;
  private static idLose: number = 0;
  private static idLevelUp: number = 0;
  private static idStreak: number = 0;
  /** 上次播放 tap 的时间 —— 防止一屏滑动时连成一片 */
  private static lastTapMs: number = 0;

  /** 设置里开着吗（默认开） */
  private static on(): boolean {
    const v: boolean | undefined = AppStorage.get<boolean>('soundOn');
    return v === undefined ? true : v;
  }

  /**
   * 初始化（App 启动时调一次）。
   * ★ 全程 try/catch：模拟器/老设备上音频服务可能不可用，绝不能因此让 App 起不来。
   */
  static async init(ctx: common.UIAbilityContext): Promise<void> {
    if (Sound.ready) {
      return;
    }
    try {
      // ① 音频流类型：用「游戏音效」这一类，音量控制跟游戏音量走
      const attrs: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_GAME,
        rendererFlags: 0
      } as audio.AudioRendererInfo;
      // ② SoundPool 最大并发 4 路、同类型最多 2 路（够用，且不会糊）
      Sound.pool = await media.createSoundPool(4, attrs);
      // ③ 预加载三个音效
      //   ★ 正确的签名是 load(fd, offset, length) —— 不是 load(RawFileDescriptor)
      //     getRawFd 返回 { fd, offset, length }，要把三个字段拆开传
      const mgr: resourceManager.ResourceManager = await ctx.resourceManager;
      const t: resourceManager.RawFileDescriptor = await mgr.getRawFd('sfx/tap.wav');
      Sound.idTap = await Sound.pool.load(t.fd, t.offset, t.length);
      const w: resourceManager.RawFileDescriptor = await mgr.getRawFd('sfx/win.wav');
      Sound.idWin = await Sound.pool.load(w.fd, w.offset, w.length);
      const l: resourceManager.RawFileDescriptor = await mgr.getRawFd('sfx/lose.wav');
      Sound.idLose = await Sound.pool.load(l.fd, l.offset, l.length);
      // ★ 2026-10-29：再补两档 —— 升级（大时刻）与连续打卡（小成就）
      const u: resourceManager.RawFileDescriptor = await mgr.getRawFd('sfx/levelup.wav');
      Sound.idLevelUp = await Sound.pool.load(u.fd, u.offset, u.length);
      const st: resourceManager.RawFileDescriptor = await mgr.getRawFd('sfx/streak.wav');
      Sound.idStreak = await Sound.pool.load(st.fd, st.offset, st.length);
      Sound.ready = true;
      hilog.info(DOMAIN, TAG, '音效已就绪: tap=%{public}d win=%{public}d lose=%{public}d lv=%{public}d streak=%{public}d',
        Sound.idTap, Sound.idWin, Sound.idLose, Sound.idLevelUp, Sound.idStreak);
    } catch (e) {
      // ★ 静默降级：没有音效，游戏照常玩
      Sound.ready = false;
      Sound.pool = undefined;
      hilog.warn(DOMAIN, TAG, '音效初始化失败（不影响游戏）: %{public}s', JSON.stringify(e));
    }
  }

  /** 播放一个短音效（内部用） */
  private static play(id: number): void {
    if (!Sound.ready || !Sound.on() || id <= 0 || Sound.pool === undefined) {
      return;
    }
    try {
      // ★ 正确签名：play(soundID, params?) —— 不是 play(id, vol, vol, prio, loop, rate)
      //   play 返回 streamID（>0 = 真的开播了）⇒ 打日志便于真机验"到底响不响"
      Sound.pool.play(id).then((streamId: number) => {
        hilog.info(DOMAIN, TAG, '播放 ok: sound=%{public}d stream=%{public}d', id, streamId);
      }).catch((e: Object) => {
        hilog.warn(DOMAIN, TAG, '播放失败: %{public}s', JSON.stringify(e));
      });
    } catch (e) {
      // 播放失败也不许影响游戏
    }
  }

  // ─────────── 三个语义化的音效 ───────────

  /** 轻点一下（选格、翻牌、点选项）—— 有 60ms 节流，避免连成噪音 */
  static tap(): void {
    const now: number = Date.now();
    if (now - Sound.lastTapMs < 60) {
      return;
    }
    Sound.lastTapMs = now;
    Sound.play(Sound.idTap);
  }

  /** 通关 */
  static win(): void {
    Sound.play(Sound.idWin);
  }

  /** 没通关 */
  static lose(): void {
    Sound.play(Sound.idLose);
  }

  /**
   * 升级 —— 五音上行（比 win 更长更高）。
   * ★ 只在**真的升级**时响，不要在每次通关时都响（会盖过 win）。
   */
  static levelUp(): void {
    Sound.play(Sound.idLevelUp);
  }

  /** 连续打卡 / 解锁成就这类"小成就"—— 两记清脆的叮叮 */
  static streak(): void {
    Sound.play(Sound.idStreak);
  }

  /** 释放（App 退出时调） */
  static async release(): Promise<void> {
    try {
      if (Sound.pool !== undefined) {
        await Sound.pool.release();
      }
    } catch (e) {
    }
    Sound.pool = undefined;
    Sound.ready = false;
  }
}
