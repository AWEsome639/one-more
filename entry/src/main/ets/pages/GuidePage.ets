/**
 * 说明页 —— 一个页面干两件事
 *   ① 玩法说明（对标项目的 game_guide_screen）：进游戏时点「?」看这一款怎么玩
 *   ② 隐私政策：设置页点「隐私政策」进来
 *
 * 路由参数：
 *   { id: 'akari' }            → 该游戏的玩法说明
 *   { kind: 'privacy' }        → 隐私政策
 *
 * 拾海 2026-10-10
 */

import { router } from '@kit.ArkUI';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Accent } from '../core/Design';
import { Haptics } from '../core/Haptics';
// ★★★ 2026-10-16 BUG #26 补完：★ 指南页的游戏名/分类/说明原来用【原文】直接渲染
//   ⇒ 阿语下显示【中文】⇒ 改用 GameRegistry 的本地化助手（GameCard 用的就是这套）
import { findGame, GameMeta, GameCategory, displayName, displayTagline, catLabelEn } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
// ★★★ 2026-10-16 BUG #28：档位进度/次数数字要走 Digits ⇒ 必须导入
//   （★ 铁律 #43 第二次咬我：加了 Digits 用法就必须补 Digits 导入）
import { L, Digits } from '../core/I18n';

/** 模块级取词（不依赖 this）—— 给 categoryTips 这类独立函数用
 *  ★★★ 2026-10-16 实拍阿语指南页抓到 BUG #26：
 *   原来 `return useEN ? en : zh` ⇒ ★ 只有中文/英文两个选项
 *   ⇒ 阿语玩家在指南页看到【英文兜底】（违反奥森「不许英文兜底」铁令）
 *   ⇒ 改成走 L()（真字典，12 语言全覆盖；缺项才退英文）
 *  ⚠️ 第三个参数保留只为【不改 18 处调用点】，实际不再使用
 */
function L2(zh: string, en: string, useEN: boolean): string {
  return L(zh, en);
}

/** 分类通用提示 —— 每款游戏的说明 = 它的 tagline + 所属分类的通用玩法 */
function categoryTips(c: GameCategory, en: boolean): string[] {
  if (c === GameCategory.CLASSIC) {
    return [
      L2('点/滑操作，规则简单，玩起来就懂', 'Tap or swipe. Simple rules, obvious once you start.', en),
      L2('有明确胜负判定，通关或失败都会结算经验', 'There is a clear win or lose, and either way you earn XP.', en),
      L2('右上角 ↻ 可以随时重开这一局', 'Tap ↻ top-right to restart any time.', en)
    ];
  }
  if (c === GameCategory.LOGIC) {
    return [
      L2('点格子填/涂，满足题目给出的数字条件', 'Tap cells to fill or shade until the number clues are satisfied.', en),
      L2('「违规」计数表示当前有几处违反规则，归零即通关', 'The "conflicts" counter shows how many rules are broken. Get it to zero and you win.', en),
      L2('卡住了可以点「换一题」换一个新局面', 'Stuck? Tap "New puzzle" for a fresh board.', en)
    ];
  }
  if (c === GameCategory.MATH) {
    return [
      L2('算就完了 —— 结果对就得分，错会扣时间', 'Just do the maths. Right answers score, wrong ones cost you time.', en),
      L2('多数款有倒计时或步数限制，快比慢强', 'Most have a countdown or a move limit. Fast beats slow.', en),
      L2('心算不稳的话，先在纸上列一下也行', 'Not confident in your head? Scribble it on paper first.', en)
    ];
  }
  if (c === GameCategory.MEMORY) {
    return [
      L2('先「看」后「答」：记住闪现的内容，再按提示回忆', 'Look first, answer after. Remember what flashed up, then recall it.', en),
      L2('答对连续越多，得分越高', 'The longer your streak, the higher the score.', en),
      L2('错了不要紧，重开一局成本很低', 'Getting it wrong is cheap. Just start again.', en)
    ];
  }
  if (c === GameCategory.WORD) {
    return [
      L2('拼词/找词/猜词，考验词汇量与语感', 'Build, find and guess words. Tests vocabulary and feel for language.', en),
      L2('多数款支持逐字母输入，输错可退格', 'Most accept letter-by-letter input, and you can backspace.', en),
      L2('不会的可以跳过，不影响其他题', 'Skip anything you do not know. It will not affect the rest.', en)
    ];
  }
  return [
    L2('观察图形/空间关系，找出规律或路径', 'Study the shapes and space, then find the pattern or the path.', en),
    L2('方向键或点选操作，走到目标即通关', 'Arrow keys or taps. Reach the goal to win.', en),
    L2('步数越少得分越高', 'Fewer moves, higher score.', en)
  ];
}

@Entry
@Component
struct GuidePage {
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源（本页的 kv 键、强调色都跟主题色） */
  @StorageProp('accent') accentId: string = Palette.primary;

  /** 取当前语言的文案（必须读 langCode，ArkUI 才认这条依赖） */
  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    // ★ 2026-10-13（P4）：这里原来是中英二元式 `observed === 'en' ? en : zh` ——
    //   日/韩/西/法/德/葡/俄/意/阿 十种语言全退中文，繁体也被吞。必须走 L()（12 语言 + 简繁转换）。
    return L(zh, en);
  }
  /** 当前主题色（id 可能是 'system'，走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  @State private meta: GameMeta | undefined = undefined;

  /** ★ BUG #26：游戏名（★ 先读 langCode 建立 ArkUI 依赖，否则换语言不重算） */
  private gName(): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return this.meta !== undefined ? displayName(this.meta) : '';
  }

  /** ★ BUG #26：游戏说明 */
  private gTagline(): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return this.meta !== undefined ? displayTagline(this.meta) : '';
  }

  /** ★ BUG #26：分类（给 L() 当键用） */
  private catOf(): GameCategory {
    return this.meta !== undefined ? this.meta.category : GameCategory.CLASSIC;
  }
  @State private isPrivacy: boolean = false;
  @State private dark: boolean = false;
  @State private entered: boolean = false;

  aboutToAppear(): void {
    this.dark = AppStorage.get<boolean>('themeDark') ?? false;
    const p: Record<string, Object> = router.getParams() as Record<string, Object>;
    if (p) {
      if (p.kind !== undefined && (p.kind as string) === 'privacy') {
        this.isPrivacy = true;
      }
      if (p.id !== undefined) {
        this.meta = findGame(p.id as string);
      }
    }
    setTimeout(() => {
      this.entered = true;
    }, 30);
  }

  private theme(): Theme {
    return this.dark ? Theme.dark() : Theme.light();
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: Space.md }) {
        Text('‹')
          .accessibilityText(this.t('返回', 'Back'))
          .fontSize(30).fontColor(this.theme().ink)
          .width(44).height(44).textAlign(TextAlign.Center)
          .backgroundColor(this.theme().surface).borderRadius(Radius.full)
          .shadow(Shadow.card)
          // ★ 2026-10-19 自查 A6：这个返回键原来点了没反馈、也没触感
          //   （GameHost 顶栏那个有 IconPress 缩放，这里补齐一致的手感）
          .stateStyles({
            pressed: { .scale({ x: 0.9, y: 0.9 }).opacity(0.85) },
            normal: { .scale({ x: 1, y: 1 }).opacity(1) }
          })
          .onClick(() => {
            Haptics.tap();
            router.back();
          })
        Text(this.isPrivacy ? this.t('隐私政策', 'Privacy policy') : this.t('怎么玩', 'How to play'))
          .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: Space.lg, right: Space.lg, top: Space.xl, bottom: Space.md })

      Scroll() {
        Column({ space: Space.lg }) {
          // ★ 2026-10-19：两块内容切换原来是"啪"一下换掉
          //   ⇒ 各自包一层带过渡的 Column（淡入 + 轻微上浮），跟全应用进场语言一致
          if (this.isPrivacy) {
            Column({ space: Space.lg }) {
              this.privacyBody()
            }
            .width('100%')
            .transition(TransitionEffect.OPACITY
              .animation({ duration: Motion.base, curve: Motion.spring() })
              .combine(TransitionEffect.translate({ y: 8 })
                .animation({ duration: Motion.base, curve: Motion.spring() })))
          } else {
            Column({ space: Space.lg }) {
              this.guideBody()
            }
            .width('100%')
            .transition(TransitionEffect.OPACITY
              .animation({ duration: Motion.base, curve: Motion.spring() })
              .combine(TransitionEffect.translate({ y: 8 })
                .animation({ duration: Motion.base, curve: Motion.spring() })))
          }
        }
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, bottom: Space.xxxl })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bg)
    .opacity(this.entered ? 1 : 0)
    .translate({ y: this.entered ? 0 : 12 })
    .animation({ duration: Motion.slow, curve: Motion.spring() })
  }

  // ───────────── 玩法说明 ─────────────

  @Builder
  guideBody() {
    // 游戏头卡
    Row({ space: Space.md }) {
      Text(this.meta ? this.meta.icon : '🎮')
        .fontSize(36)
        .width(64).height(64).textAlign(TextAlign.Center)
        .backgroundColor(this.theme().surfaceAlt)
        .borderRadius(Radius.md)
      Column({ space: 4 }) {
        Text(this.meta ? this.gName() : '')
          .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
        // ★ BUG #26：分类原来显示【中文原文】⇒ 走 L() + catLabelEn()
        Text(this.meta ? L(this.catOf(), catLabelEn(this.catOf())) : '')
          .fontSize(FontSize.xs).fontColor(this.accentColor())
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#1A6366F1')
          .borderRadius(Radius.full)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)

    // 一句话玩法
    Column({ space: Space.sm }) {
      Text(this.t('一句话', 'In one line')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
      Text(this.meta ? this.gTagline() : '')
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)

    // 玩法要点
    Column({ space: Space.md }) {
      Text(this.t('玩法要点', 'Key points')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
      ForEach(this.tips(), (t: string, i: number) => {
        Row({ space: Space.sm }) {
          Text(String(i + 1))
            .fontSize(FontSize.xs).fontColor(Color.White)
            .width(20).height(20).textAlign(TextAlign.Center)
            .backgroundColor(this.accentColor())
            .borderRadius(Radius.full)
          Text(t)
            .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (t: string) => t)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)

    // 通用操作
    Column({ space: Space.sm }) {
      this.tierRow(this.meta !== undefined ? this.meta.id : "")
      Text(this.t('通用操作', 'Controls')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
      this.kv('↻ 右上角', '↻ top right', '重开这一局', 'Restart this round')
      this.kv('‹ 左上角', '‹ top left', '返回游戏列表', 'Back to the game list')
      this.kv('⭐', '⭐', '收藏这一款（在游戏页右上角）', 'Save this game (top right of a game page)')
      this.kv('结算弹窗', 'Result sheet', '可得经验值，等级会涨', 'Earns XP and levels you up')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)

    Button(this.t('开始玩', 'Start playing'))
      .fontSize(FontSize.md).fontColor(Color.White)
      .backgroundColor(this.accentColor()).borderRadius(Radius.md)
      .width('100%').height(46)
      .onClick(() => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        router.back();
      })
  }

  private tips(): string[] {
    const m: GameMeta | undefined = this.meta;
    if (m === undefined) {
      return [this.t('选一款游戏开始吧', 'Pick a game to get started')];
    }
    const out: string[] = [];
    // ★★★ 2026-10-16 BUG #26 最后一片：原来是 `out.push(m.tagline)` 用【原文】
    //   ⇒ 实拍阿语指南页：要点①还是中文「交换消宝石」
    //   ⇒ 改用 displayTagline(m)（走 GAME_TAGLINE 字典，12 语言全覆盖）
    out.push(displayTagline(m));
    // ★ 非中文系一律用英文提示（以前只判 'en'，日语/韩语下会残留中文）
    const zhLike: boolean = this.langCode === 'zh' || this.langCode === 'zh-Hant';
    const t: string[] = categoryTips(m.category, !zhLike);
    for (let i = 0; i < t.length; i++) {
      out.push(t[i]);
    }
    return out;
  }

  /** 这款游戏的 4 档成就进度 */
  @Builder
  tierRow(gid: string) {
    Column({ space: 6 }) {
      Row() {
        Text(this.t('这款的成就', 'Badges for this game'))
          .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        Blank()
        // ★ BUG #25 同源：档位进度数字没走 Digits ⇒ 阿语下是西文
        Text(Digits(String(ProgressStore.tierOf(gid)), this.langCode) + ' / ' +
          Digits('4', this.langCode))
          .fontSize(FontSize.xs).fontColor(Palette.amber).fontWeight(FontWeight.Bold)
      }
      .width('100%')
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Column({ space: 2 }) {
            Text(ProgressStore.tierOf(gid) > i ? '🏅' : '🔒').fontSize(FontSize.lg)
            // ★★★ 2026-10-16 BUG #28：原来是
            //   `langCode === 'zh' ? 中文 : (zh-Hant ? toTrad : 英文)` ⇒ ★ 只有三个分支！
            //   ⇒ 日/韩/法/德/西/俄/阿/葡/意 九种语言全看到【英文档位名】
            //   ⇒ 改走 L()（真字典 12 语言）；字典缺项才退英文
            Text(L(ProgressStore.TIER_NAME[i][0], ProgressStore.TIER_NAME[i][1]))
              .fontSize(FontSize.micro)
              .fontColor(ProgressStore.tierOf(gid) > i ? this.theme().ink : this.theme().inkFaint)
            Text(Digits(String(ProgressStore.clearsOf(gid)), this.langCode) + '/' +
              Digits(String(ProgressStore.TIER_NEED[i]), this.langCode))
              .fontSize(FontSize.micro).fontColor(this.theme().inkFaint)
          }
          .layoutWeight(1)
        }, (i: number) => 'tier' + i)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  /**
   * 键值行
   * ★ 只收**字面量对** (zh, en)，翻译在 Builder 内部做 ——
   *   `@Builder` 的参数会被 ArkUI 记忆化，传算好的字符串时换语言不重建。
   */
  kv(kZh: string, kEn: string, vZh: string, vEn: string) {
    Row({ space: Space.sm }) {
      Text(this.t(kZh, kEn)).fontSize(FontSize.xs).fontColor(this.accentColor()).width(88)
      Text(this.t(vZh, vEn)).fontSize(FontSize.sm).fontColor(this.theme().inkSoft).layoutWeight(1)
    }
    .width('100%')
  }

  // ───────────── 隐私政策 ─────────────

  @Builder
  privacyBody() {
    Column({ space: Space.md }) {
      Text(this.t('一句话', 'In one line'))
        .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
      Text(this.t('「One More」不采集你的个人信息，也不上传你的游戏记录。所有记录只存在你自己的手机里。需联网的只有两项：局域网对战、华为游戏服务的账号校验。', '"One More" does not collect your personal information and never uploads your game records. Everything stays on your device. Only two features use the network: LAN play and Huawei Game Service account check.'))
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
        .lineHeight(24)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)

    this.sec('一、我们不收集哪些信息', '1. What we do not collect', '本应用不收集、不存储、不传输：姓名/手机号/邮箱等身份信息、通讯录、通话记录、短信、位置信息、相册与相机内容、麦克风内容、设备标识符（IMEI/OAID/MAC）、应用安装列表、剪贴板、网络访问记录。\n\n关于网络权限：本应用**只申请了网络权限与 Wi-Fi 信息两项**，用于两件事：① **「局域网对战」** —— 让同一 Wi-Fi 下的两台设备互相找到并直连；② **华为游戏服务的账号校验** —— 应用市场对游戏类目的合规要求（防沉迷），由华为 SDK 完成，本应用不接触校验内容。**除此之外**，本应用未申请位置、相机、麦克风、通讯录、日历、电话、短信、存储读写等任何敏感权限。\n\n局域网对战**不经过任何服务器**：消息只在同一 Wi-Fi 内的两台设备之间直接传输，一局结束即断开。其余 353 款游戏与全部记录、统计**完全离线**，飞行模式下照常可玩。', 'This app does not collect, store or transmit: identity information such as your name, phone number or email; contacts; call logs; text messages; location; photos or camera content; microphone content; device identifiers (IMEI / OAID / MAC); your list of installed apps; the clipboard; or any record of network access.\n\nAbout network access: this app requests only two permissions — network and Wi-Fi information — and uses them solely for LAN play, so two devices on the same Wi-Fi can find each other and connect directly. Beyond that, no location, camera, microphone, contacts, calendar, phone, SMS or storage permissions are requested.\n\nLAN play never connects to the internet and never uploads anything: messages travel directly between the two devices on your Wi-Fi and the connection closes when the round ends. The other 353 games, along with all records and statistics, stay completely offline and work in airplane mode.')

    this.sec('二、应用会在本地保存什么', '2. What is stored on your device', '为了让「等级」「连胜」「今日打卡」正常工作，本应用会在你手机上存下这些：累计经验值、各游戏通关次数与最佳成绩、连胜天数、最近一次游玩日期、深色模式开关、收藏与最近玩过的游戏。\n\n这些数据只存在应用自己的文件夹里，别的应用读不到；不会传到任何服务器；不含任何能认出你是谁的信息；把应用卸载掉，它们就一起没了。', 'To make Level, Streak and the Daily Pick work, the app stores these on your phone: total XP, clears and best scores per game, streak days, the date you last played, the dark-mode switch, your saves and recently played games.\n\nThis data lives only inside the app own folder, so no other app can read it. It is never sent to any server, it contains nothing that could identify you, and uninstalling the app removes it all.')

    this.sec('三、第三方服务', '3. Third-party services', '本应用只接入了一个第三方组件：**华为 Game Service Kit** —— 用于上面提到的账号校验，属应用市场对游戏类目的合规要求。除此之外没有接入任何其他 SDK（SDK 就是别人写好的代码包）—— 没有广告的、没有统计分析的、没有崩溃上报的、没有社交分享的、没有支付的、也没有推送的。\n\n本应用不含任何广告，不含任何内购，不产生任何费用。', 'The app includes no third-party SDKs (an SDK is a pre-written code package) — none for ads, none for analytics, none for crash reporting, none for social sharing, none for payments and none for push notifications.\n\nThe app has no ads, no in-app purchases and costs nothing.')

    this.sec('四、桌面服务卡片', '4. Home screen widget', '本应用提供桌面服务卡片（显示等级、连胜与今日打卡状态）。卡片读取的数据与主应用完全相同，均来自上述本地存储，不涉及任何额外的信息收集或网络传输。', 'The app offers a home-screen widget showing your level, streak and daily check-in. The widget reads exactly the same data as the main app, all of it from the local storage described above, and involves no extra data collection or network transfer.')

    this.sec('五、未成年人保护', '5. Protection of minors', '本应用为全年龄向休闲益智游戏合集，内容为经典益智玩法（数字合并、扫雷、数独等），不含暴力、色情、赌博、恐怖或其他不适宜内容，不含社交功能，不含用户间交流，不含任何付费项目。由于不收集任何个人信息，因此不存在未成年人个人信息被收集的风险。', 'This is an all-ages collection of classic puzzle games (number merging, minesweeper, sudoku and so on). It contains no violence, sexual content, gambling, horror or anything else unsuitable, no social features, no user-to-user messaging and no paid items. Because no personal information is collected at all, there is no risk of personal information from a minor being gathered.')

    this.sec('六、你的权利', '6. Your rights', '你对自己的本地数据拥有完全控制权：\n· 清除数据：系统「设置 → 应用 → One More → 存储 → 清除数据」\n· 彻底删除：卸载应用即可\n· 也可以在应用「设置 → 重置进度」里一键清空', 'You have full control over your local data:\n· Clear data: Settings → Apps → One More → Storage → Clear data\n· Delete completely: uninstall the app\n· Or use Reset progress inside the app to wipe everything in one tap')

    this.sec('七、合规声明', '7. Compliance', '本应用为个人开发者独立开发的休闲益智游戏合集：\n· 全部代码为原创编写（ArkTS / ArkUI 原生开发）\n· 玩法均为公有领域的经典益智玩法\n· 未复制、未改编任何第三方项目的代码、美术资源或名称\n· 未使用任何第三方依赖库\n· 图标与界面视觉均为原创设计', 'This is a casual puzzle collection independently developed by a solo developer:\n· All code is originally written (native ArkTS / ArkUI)\n· All gameplay comes from classic puzzles in the public domain\n· No code, artwork or name from any third-party project has been copied or adapted\n· No third-party dependency libraries are used\n· The icon and all interface visuals are original designs')

    Text(this.t('最后更新：2026 年 10 月 10 日', 'Last updated: 10 October 2026'))
      .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
      .width('100%').textAlign(TextAlign.Center)
      .margin({ top: Space.md })
  }

  @Builder
  /** 小节卡（同上：字面量对进，内部算） */
  sec(titleZh: string, titleEn: string, bodyZh: string, bodyEn: string) {
    Column({ space: Space.sm }) {
      Text(this.t(titleZh, titleEn)).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(this.t(bodyZh, bodyEn)).fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
        .lineHeight(22)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }
}
