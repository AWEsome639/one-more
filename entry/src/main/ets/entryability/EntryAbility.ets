/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { Diag } from '../core/Diag';
import { Sound } from '../core/Sound';
import { Bp, BpDev } from '../core/Bp';
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { Configuration } from '@ohos.app.ability.Configuration';
import { ProgressStore } from '../core/ProgressStore';
import { preferences } from '@kit.ArkData';
import { UiMode, UiModeMgr } from '../core/UiMode';
// ★★★ 2026-10-23 路线 E：游玩记录（路线 B/C/F 的数据地基）
import { GameLog } from '../core/GameLog';
// ★★★ 2026-10-23 路线 D：端侧 AI 引擎（探针失败是正常状态，不影响任何玩法）
import { AiEngine } from '../ai/AiEngine';
// ★★★ 2026-10-23 路线 B：数独难度模型（11→12→1 手写 MLP，权重 2.7 KB）
import { SudokuDifficulty } from '../ai/SudokuDifficulty';
// ★★★ 2026-10-23 路线 C：2048 价值网络（24→24→1，权重 9.5 KB）
import { G2048Value } from '../ai/G2048Value';
import { gamePlayer } from '@kit.GameServiceKit';

const DOMAIN = 0x0000;
/** 与 ProgressStore / StatsCardAbility 同一个 preferences 库 */
const STORE_NAME: string = 'onemore_progress';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    // ★ 把系统当前深浅写进 AppStorage —— ProgressStore 是静态类拿不到 context，
    //    「跟随系统」这一态靠这个值解析（真踩过：ApplicationContext 没有 getColorMode）
    AppStorage.setOrCreate('systemDark',
      this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // ★★★ 2026-11-08（UI 一致性审计 ③ 续）：**把界面模式接回来**
    //   原来它从来没落盘：`UiModeMgr.save()` 只写了内存里的 `AppStorage 'uiModePersist'`，
    //   而 `UiModeMgr.current()` 冷启动永远是 'normal' ⇒ **重启就丢大字模式**；
    //   桌面卡片跑在 Form 进程、看不到 AppStorage ⇒ 更拿不到。
    //   ⇒ 落到 `onemore_progress` 库的 'uiMode' 键（与 `lang` 同一个库、同一套写法）。
    //   ⚠️ 必须在第一帧（onWindowStageCreate→loadContent）之前跑完，否则会先按 NORMAL 画一帧。
    this.loadUiMode();
    // ★ 2026-11-08：把「落盘通道」注册给 UiModeMgr —— 设置页一点模式就写盘，
    //   不再依赖"用户有没有切过后台"（原来只在 onBackground 写，切完直接强杀就丢）。
    UiModeMgr.bindWriter((m: string) => { this.persistUiMode(m); });

    // 进度系统：读 XP/等级/连胜/打卡（失败也不阻塞启动，ProgressStore 内部有兜底）
    ProgressStore.init(this.context).then(() => {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'ProgressStore ready');
      // ★ 路线 E：游玩记录初始化（同步、内部全兜底，失败只是不落盘，不影响启动）
      GameLog.init(this.context);
      // ★ 路线 D：AI 引擎探针 —— 不 await，绝不让模型加载拖慢首屏
      AiEngine.probe(this.context);
      // ★ 路线 B：读不到权重就永久降级（内部只试一次）
      SudokuDifficulty.init(this.context);
      // ★ 路线 C：读不到就永久降级到手工提示
      G2048Value.init(this.context);
      hilog.info(DOMAIN, 'testTag', 'GameLog ready (%{public}d 条)', GameLog.count());
    }).catch((e: Object) => {
      hilog.error(DOMAIN, 'testTag', 'ProgressStore init failed: %{public}s', JSON.stringify(e));
      // ProgressStore 失败也要让 GameLog 尽量起来（两条链路互不拖累）
      GameLog.init(this.context);
    });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    this.saveUiMode();   // ★ 2026-11-08：与 onBackground 双保险
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  /** ★ 系统深浅变化时，如果用户选的是「跟随系统」就立刻跟着变 */
  onConfigurationUpdate(newConfig: Configuration): void {
    AppStorage.setOrCreate('systemDark',
      newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    if (ProgressStore.themeMode() === 'system') {
      ProgressStore.applyThemeMode('system');
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // ★★★ 2026-10-19 全面自查：全工程从来没设过【窗口底色】
    //   后果：onWindowStageCreate 到第一帧之间，窗口是系统默认底色（浅色）
    //        ⇒ 每次启动都会先闪一下白，然后才是深墨蓝的开屏
    //   ⇒ 在 loadContent【之前】把窗口底色调成开屏同色 —— 启动变成"无缝入画"
    //   ⚠️ 用 try/catch：个别设备/低版本 API 不支持 setWindowBackgroundColor，
    //      失败只影响那一下白闪，不能因此让应用起不来
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      // #0D1320 = Splash.ets 的 OM_INK，与开屏、图标底色完全一致
      win.setWindowBackgroundColor('#0D1320');
      // ★★ 2026-11-01 查证（**没有改**，只留结论）：
      //   一度以为"状态栏文字在深色开屏上看不见"，准备把 statusBarContentColor 设成 #FFFFFF。
      //   查日志发现：系统（com.ohos.sceneboard）会把状态栏设成
      //     `System bar property change ... to #FF000000` + `onPluginContentColorChange #FF000000`
      //   ⇒ **状态栏是系统画的：白底 + 黑字**，像素取样 y=10~75 是 (255,255,255) 纯白。
      //   ⇒ 截图里那行黑字是在**白底**上，完全可读 —— 是我看截图时的误读。
      //   ⛔ 不要把它改成白色：那会变成白字白底，反而看不见。

    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'setWindowBackgroundColor 失败（不影响启动）: %{public}s', JSON.stringify(e));
    }

    // ★★★ 2026-10-28（项目 F：六设备支持）：把窗口尺寸交给 Bp，全项目按它自适应
    //   · 读一次当前尺寸 ⇒ 第一帧就是对的（不会先按手机画再跳一下）
    //   · 监听 windowSizeChange ⇒ 折叠屏展开/收起、PC 拖窗口、分屏都跟着变
    //   ⚠️ 全程 try/catch：拿不到尺寸就退回手机 360vp，绝不能因为读尺寸失败就打不开
    try {
      const mainWin: window.Window = windowStage.getMainWindowSync();
      const prop: window.WindowProperties = mainWin.getWindowProperties();
      // ★★★ 2026-10-29（项目 F 阶段 3）：把**设备类型**也交给 Bp
      //   deviceInfo.deviceType 的取值：phone / tablet / 2in1 / tv / wearable / car ...
      //   之前 Bp 里明明有 WATCH / TV 分支，却从没人设置过 ⇒ 永远是 phone
      //   ⚠️ 用 try/catch：某些设备/低版本取不到，取不到就按宽度推断
      let dev: string = '';
      try {
        dev = deviceInfo.deviceType;
      } catch (e3) {
        dev = '';
      }
      // ★★★ 2026-10-29（lead）：**windowRect 给的是 px，不是 vp！**
      //   实测：1320×2232 px 的手机（440×744 vp）被判成 lg（平板/PC）
      //   ⇒ isLg() 为真 ⇒ 列表排 4 列 + 格子放大 1.12 倍 ⇒ 界面像被撑爆了
      //   ⇒ 必须先用 px2vp 换成 vp（ArkUI 里所有布局单位都是 vp）
      const wVp: number = px2vp(prop.windowRect.width);
      const hVp: number = px2vp(prop.windowRect.height);
      // ★ 第 1207 轮：`Diag.forceTv` 用于在模拟器上验电视字号（1.45 倍）
      if (Diag.forceTv) {
        dev = BpDev.TV;
      }
      Bp.update(wVp, hVp, dev);
      try {
        mainWin.on('windowSizeChange', (sz: window.Size) => {
          Bp.update(px2vp(sz.width), px2vp(sz.height));
        });
      } catch (e2) {
        hilog.warn(DOMAIN, 'testTag', 'windowSizeChange 监听失败（不影响使用）: %{public}s', JSON.stringify(e2));
      }
      hilog.info(DOMAIN, 'testTag', 'Bp 初始化: %{public}s x %{public}s | tag=%{public}s dev=%{public}s forceTv=%{public}s scale=%{public}s',
        String(wVp), String(hVp), Bp.tag(), Bp.dev, String(Diag.forceTv), String(Bp.scale()));
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', '读窗口尺寸失败，按手机 360vp 走: %{public}s', JSON.stringify(e));
    }

    windowStage.loadContent('pages/Splash', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // ★★★ 2026-10-18：华为审核要求 —— 游戏类目必须集成 Game Service Kit 的 init + verifyLocalPlayer
      //   检测报告原文：「未集成 verifyLocalPlayer / init API，不符合华为应用市场审核标准」
      //   ⇒ 在 UI 加载完成后初始化；失败不阻断（这是离线游戏，别因为断网就让用户玩不了）
      this.initGameService();
      // ★ 2026-10-29（项目 D ④）：音效初始化
      //   放在 UI 加载完成之后 —— SoundPool 要资源管理器就绪才拿得到 rawfile
      //   ⚠️ 失败静默（Sound.init 内部已 try/catch），没有音效也能玩
      Sound.init(this.context).catch(() => {});
    });
  }

  /**
   * ★ 初始化华为游戏服务（合规前置）+ 防沉迷校验
   *
   * 为什么失败要降级：355 款游戏本身纯离线；联网只用于局域网对战与华为游戏服务的账号校验，
   *   两者失败都不该影响开局。
   * 若因「无网络 / 设备未登录华为账号」而拒绝启动，等于把离线卖点废掉了。
   * 但【未成年无游戏时长】这类硬合规错误码必须尊重 —— 交给上层决定怎么提示。
   */
  private async initGameService(): Promise<void> {
    const ctx = this.context;
    try {
      await gamePlayer.init(ctx);
      hilog.info(DOMAIN, 'GameService', 'init ok');
      try {
        const player = await gamePlayer.getLocalPlayer(ctx);
        const pid: string = player && player.gamePlayerId ? player.gamePlayerId : '';
        hilog.info(DOMAIN, 'GameService', 'getLocalPlayer ok len=%{public}d', pid.length);
        // 防沉迷合规校验
        //   thirdOpenId = 官方游戏账号 ID，本应用无自有账号体系 ⇒ 按文档传空串
        //   isAdult / isRealName 由华为侧根据实名结果判定（错误码 1002000006 = 未成年无时长）
        const userInfo: gamePlayer.ThirdUserInfo = { thirdOpenId: '' };
        await gamePlayer.verifyLocalPlayer(ctx, userInfo);
        hilog.info(DOMAIN, 'GameService', 'verifyLocalPlayer ok');
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        hilog.warn(DOMAIN, 'GameService', 'player/verify failed code=%{public}d msg=%{public}s',
          err.code, err.message);
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, 'GameService', 'init failed code=%{public}d msg=%{public}s',
        err.code, err.message);
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  /**
   * ★★★ 2026-11-08：从 preferences 恢复「界面模式」并立刻应用到设计系统常量。
   * 读不到/读坏了 ⇒ 'normal'（绝不因此不启动）。
   * ⚠️ 应用这一步是**全局**的：它改写 `FontSize/Space/Radius` 的静态值，
   *    而 `Index.aboutToAppear` 随后会再 `apply(UiModeMgr.current())` —— 因为这里
   *    已经 `apply` 过，`current()` 就是正确档位，不会被打回 normal。
   */
  private loadUiMode(): void {
    try {
      const opt: preferences.Options = { name: STORE_NAME };
      const pr: preferences.Preferences = preferences.getPreferencesSync(this.context, opt);
      const m: string = pr.getSync('uiMode', '') as string;
      const mode: string = (m === UiMode.ELDER || m === UiMode.SIMPLE) ? m : UiMode.NORMAL;
      UiModeMgr.apply(mode);
      hilog.info(DOMAIN, 'testTag', 'uiMode = %{public}s', mode);
    } catch (e) {
      hilog.error(DOMAIN, 'testTag', 'loadUiMode failed: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 把**指定档位**写盘。
   * ★ 2026-11-08：从 `saveUiMode()` 里拆出来 —— 两条触发路径共用：
   *   ① `UiModeMgr.save()`（设置页点一下，通过 `bindWriter` 注册的钩子，**立刻写**）
   *   ② `saveUiMode()`（onBackground / onDestroy 兜底，读当前 AppStorage 值）
   */
  private persistUiMode(mode: string): void {
    try {
      if (mode.length === 0) {
        return;
      }
      const opt: preferences.Options = { name: STORE_NAME };
      const pr: preferences.Preferences = preferences.getPreferencesSync(this.context, opt);
      // 存储满时 putSync/flush 会抛 ⇒ 静默失败（同 ProgressStore.putString 的做法）
      pr.putSync('uiMode', mode);
      pr.flush();
    } catch (e) {
      // 写不进去只影响"下次启动的记忆"，不动声色
    }
  }

  /** 兜底：把当前模式写盘（唯一真相源是 `AppStorage 'uiMode'`，由 UiModeMgr.apply 维护） */
  private saveUiMode(): void {
    try {
      const m: string | undefined = AppStorage.get<string>('uiMode');
      if (m === undefined) {
        return;
      }
      this.persistUiMode(m);
    } catch (e) {
      // 同上：静默
    }
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    // ★ 2026-11-08：切后台时把当前界面模式落盘（用户刚在大字/简约之间切过就靠这一下）
    this.saveUiMode();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}