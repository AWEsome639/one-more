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

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { Configuration } from '@ohos.app.ability.Configuration';
import { ProgressStore } from '../core/ProgressStore';
// ★★★ 2026-10-23 路线 E：游玩记录（路线 B/C/F 的数据地基）
import { GameLog } from '../core/GameLog';
import { gamePlayer } from '@kit.GameServiceKit';

const DOMAIN = 0x0000;

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
    // 进度系统：读 XP/等级/连胜/打卡（失败也不阻塞启动，ProgressStore 内部有兜底）
    ProgressStore.init(this.context).then(() => {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'ProgressStore ready');
      // ★ 路线 E：游玩记录初始化（同步、内部全兜底，失败只是不落盘，不影响启动）
      GameLog.init(this.context);
      hilog.info(DOMAIN, 'testTag', 'GameLog ready (%{public}d 条)', GameLog.count());
    }).catch((e: Object) => {
      hilog.error(DOMAIN, 'testTag', 'ProgressStore init failed: %{public}s', JSON.stringify(e));
      // ProgressStore 失败也要让 GameLog 尽量起来（两条链路互不拖累）
      GameLog.init(this.context);
    });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
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
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'setWindowBackgroundColor 失败（不影响启动）: %{public}s', JSON.stringify(e));
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

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}