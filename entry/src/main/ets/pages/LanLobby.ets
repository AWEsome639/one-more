/**
 * 局域网对战大厅
 *
 * 流程：进页面 → 自动扫一遍 → 列出手机会（房主）→ 点「加入」；或点「开个房间」当房主。
 * 只列**同一个 Wi-Fi** 下、且**开的是同一款游戏**的房间。
 *
 * 拾海 2026-10-11
 */

import { router } from '@kit.ArkUI';
import { FontSize, Space, Radius, Palette, Theme, Shadow, Layout, Accent } from '../core/Design';
import { Lan, LanRoom, LanMsg } from '../core/Lan';
import { LanRace, RaceScore } from '../core/LanRace';
import { LanMatch } from '../core/LanMatch';
import { GAMES, GameMeta, findGame, displayName } from '../core/GameRegistry';
import { Haptics } from '../core/Haptics';
import { L } from '../core/I18n';

/** 可联机的游戏（回合制对战型） */
// ★ P12（2026-10-13）：奥森要求「合适的都能加上」。
//   接一款只需 4 个调用（setHandler / isActive+myTurn / record），引擎通用不用改 —— 见《联机扩围-交接配方.md》
const LAN_GAMES: string[] = [
  'tic_tac_toe', 'connect_four', 'reversi', 'nim',
  'mancala',      // 播棋（P12 新增：连走用空过包 'P' 补偿）
  'gomoku',       // 五子棋（P12 新增：绝对坐标，直接传下标）
  'checkers',      // 跳棋（P12 新增：180° 旋转映射 + 连吃用 'P' 补偿）
  'go9'           // 9 路围棋（2026-10-13 新增：'P' 是真·停一手，重开翻手单独用 'F'）
];

@Entry
@Component
struct LanLobby {
  @StorageProp('themeDark') dark: boolean = false;
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 设置页改色，本页立刻跟 */
  @StorageProp('accent') accentId: string = Palette.primary;
  @State private scanning: boolean = true;
  @State private rooms: LanRoom[] = [];
  @State private picked: string = 'tic_tac_toe';
  @State private status: string = '';
  @State private manualIp: string = '';
  @State private manualPort: string = '';   // ★ 留空 —— 有默认值时输入会追加在后面，清不掉
  // ★ 竞速模式（奥森 2026-10-13：「所有游戏都可以比速度」）
  @State private raceMode: boolean = false;   // 是否在竞速模式
  @State private raceTick: number = 0;        // 排名变化时 +1 ⇒ 驱动重绘（拱 LanRace 的静态状态）

  /** 当前主题色（id 可能是 'system'，一律走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    // ★ 2026-10-13（P4）：这里原来是中英二元式 `observed === 'en' ? en : zh` ——
    //   日/韩/西/法/德/葡/俄/意/阿 十种语言全退中文，繁体也被吞。必须走 L()（12 语言 + 简繁转换）。
    return L(zh, en);
  }

  private theme(): Theme {
    return this.dark ? Theme.dark() : Theme.light();
  }

  aboutToAppear(): void {
    this.doScan();
  }

  aboutToDisappear(): void {
    LanMatch.end();
    Lan.closeAll();
  }

  private async doScan(): Promise<void> {
    this.scanning = true;
    this.status = this.t('正在找同一 Wi-Fi 下的房间…', 'Looking for rooms on your Wi-Fi…');
    const found: LanRoom[] = await Lan.scan();
    this.rooms = found;
    this.scanning = false;
    this.status = found.length === 0
      ? this.t('没找到房间 —— 让对手点「开个房间」', 'No rooms found — ask your opponent to host')
      : '';
  }

  build() {
    // ★★ 2026-10-14 修复（奥森：「让每个长列表都变得可以滑动」）：
    //    本页原本没有 Scroll ⇒ 内容超一屏就滚不动（玩家列表 + 实时排名会溢出）
    Scroll() {
    Column({ space: Space.md }) {
      // 顶栏
      Row() {
        Text('‹').fontSize(FontSize.xl).fontColor(this.theme().ink)
          .accessibilityText(this.t('返回', 'Back'))
          .width(Layout.touchMin).height(Layout.touchMin).textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text(this.t('局域网对战', 'LAN Play')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink).layoutWeight(1)
        Text(this.t('重扫', 'Rescan')).fontSize(FontSize.xs).fontColor(this.accentColor())
          .padding(Space.sm)
          .onClick(() => this.doScan())
      }
      .width('100%').padding({ left: Space.sm, right: Space.md, top: Space.xl })

      Text(this.t('同一 Wi-Fi 下的两台设备直接对局 —— 没有服务器，不上传任何数据',
                  'Two devices on the same Wi-Fi play directly. No server, nothing uploaded.'))
        .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        .padding({ left: Space.lg, right: Space.lg })

      // 选游戏
      // ★ 竞速模式开关（2026-10-13 · 奥森：「所有游戏都可以比速度」）
      Row({ space: Space.sm }) {
        Text(this.raceMode ? '🏁' : '♟️').fontSize(FontSize.lg)
        Column({ space: 1 }) {
          Text(this.raceMode ? this.t('竞速模式', 'Race mode') : this.t('回合制对战', 'Turn-based'))
            .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
          Text(this.raceMode
            ? this.t('同一款游戏一起开，谁先完成谁赢；355 款全都能比', 'Same game, first to finish wins — all 355 games')
            : this.t('井字棋 / 五子棋 / 围棋 等 8 款轮流下', '8 games, take turns'))
            .fontSize(FontSize.micro).fontColor(this.theme().inkFaint)
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.raceMode })
          .onChange((on: boolean) => {
            this.raceMode = on;
            LanRace.setOnChange(() => { this.raceTick = this.raceTick + 1; });
          })
      }
      .width('100%').padding(Space.md)
      .backgroundColor(this.theme().surface).borderRadius(Radius.lg)

      // ★ 排名榜（竞速模式才有）
      if (this.raceMode) {
        Column({ space: 6 }) {
          Text(this.t('实时排名', 'Live ranking')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
          if (LanRace.scoresOf().length === 0) {
            Text(this.t('还没有人完成 —— 开一局吧', 'Nobody finished yet — start a round'))
              .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
          }
          ForEach(LanRace.ranked(), (sc: RaceScore, i: number) => {
            Row({ space: Space.sm }) {
              Text(i === 0 ? '🥇' : (i === 1 ? '🥈' : (i === 2 ? '🥉' : String(i + 1))))
                .fontSize(FontSize.sm).width(28).textAlign(TextAlign.Center)
              Text(sc.nick + (sc.me ? this.t('（我）', ' (me)') : ''))
                .fontSize(FontSize.sm).fontColor(this.theme().ink).layoutWeight(1)
              Text((sc.ms / 1000).toFixed(1) + 's')
                .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.accentColor())
            }
            .width('100%')
          }, (sc: RaceScore, i: number) => sc.nick + '-' + String(this.raceTick))
        }
        .width('100%').padding(Space.md)
        .backgroundColor(this.theme().surfaceAlt).borderRadius(Radius.lg)
      }

      Column({ space: Space.sm }) {
        Text(this.t('玩哪一款', 'Pick a game')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.pickList(), (gid: string) => {
            Text(this.gameName(gid))
              .fontSize(FontSize.xs)
              .fontWeight(this.picked === gid ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.picked === gid ? Color.White : this.theme().inkSoft)
              .padding({ left: Space.md, right: Space.md, top: 7, bottom: 7 })
              .margin({ right: 6, bottom: 6 })
              .backgroundColor(this.picked === gid ? this.accentColor() : this.theme().surfaceAlt)
              .borderRadius(Radius.full)
              .onClick(() => {
                Haptics.tap();
                this.picked = gid;
              })
          }, (gid: string) => gid)
        }
        .width('100%')
      }
      .width('100%').padding(Space.md)
      .margin({ left: Space.lg, right: Space.lg })
      .backgroundColor(this.theme().surface).borderRadius(Radius.md).shadow(Shadow.card)

      // 手动连接（扫不到房间时用；同一 Wi-Fi 但广播被路由器拦掉的情况很常见）
      Column({ space: 6 }) {
        Text(this.t('扫不到？直接输房主 IP', 'Nothing found? Type the host IP'))
          .fontSize(FontSize.xs).fontColor(this.theme().inkFaint).width('100%')
        Row({ space: Space.sm }) {
          TextInput({ text: this.manualIp, placeholder: '192.168.1.5' })
            .fontSize(FontSize.sm).layoutWeight(2).height(40)
            .backgroundColor(this.theme().surfaceAlt).borderRadius(Radius.sm)
            .onChange((v: string) => { this.manualIp = v; })
          TextInput({ text: this.manualPort, placeholder: '41235' })
            .fontSize(FontSize.sm).layoutWeight(1).height(40)
            .backgroundColor(this.theme().surfaceAlt).borderRadius(Radius.sm)
            .onChange((v: string) => { this.manualPort = v; })
          Text(this.t('连接', 'Join'))
            .fontSize(FontSize.xs).fontColor(Color.White)
            .padding({ left: Space.md, right: Space.md, top: 10, bottom: 10 })
            .backgroundColor(Palette.emerald).borderRadius(Radius.full)
            .onClick(() => this.manualJoin())
        }
        .width('100%')
      }
      .width('100%').padding(Space.md)
      .margin({ left: Space.lg, right: Space.lg })
      .backgroundColor(this.theme().surface).borderRadius(Radius.md).shadow(Shadow.card)

      // 开房
      Button(this.t('开个房间（我来当房主）', 'Host a room'))
        .width('100%').height(48)
        .backgroundColor(this.accentColor())
        .onClick(() => this.hostRoom())

      // 房间列表
      Text(this.status).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
      ForEach(this.rooms, (r: LanRoom) => {
        Row({ space: Space.md }) {
          Text('📶').fontSize(FontSize.lg)
            .accessibilityLevel('no')
          Column({ space: 2 }) {
            Text(r.host + this.t(' 的房间', "'s room")).fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
            Text(this.gameName(r.gameId) + ' · ' + r.ip).fontSize(FontSize.micro)
              .fontColor(this.theme().inkFaint)
          }
          .alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(this.t('加入', 'Join')).fontSize(FontSize.xs).fontColor(Color.White)
            .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
            .backgroundColor(Palette.emerald).borderRadius(Radius.full)
        }
        .width('100%').padding(Space.md)
        .margin({ left: Space.lg, right: Space.lg })
        .backgroundColor(this.theme().surface).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => this.joinRoom(r))
      }, (r: LanRoom) => r.ip + ':' + r.port)

      Blank()
    }
    .width('100%')
    }
    .width('100%').height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(this.theme().bg)
  }

  /**
   * 可选的游戏列表
   * ★ 竞速模式（奥森 2026-10-13：「所有游戏都可以比速度」）⇒ **355 款全可选**
   *   回合制 ⇒ 仍然只列那 8 款（多人的回合制需要引擎支持轮转，见 goal 阶段二 B）
   */
  private pickList(): string[] {
    if (!this.raceMode) {
      return LAN_GAMES;
    }
    const out: string[] = [];
    for (let i = 0; i < GAMES.length; i++) {
      out.push(GAMES[i].id);
    }
    return out;
  }

  private gameName(gid: string): string {
    const m: GameMeta | undefined = findGame(gid);
    if (m === undefined) {
      return gid;
    }
    const observed: string = this.langCode;   // ← 依赖声明
    return displayName(m);   // ★ 繁體走 toTrad
  }

  /** ★ 竞速模式：房主开一局（广播 race_go，各端同时开始） */
  private async raceHost(): Promise<void> {
    Haptics.press();
    this.status = this.t('正在开房…', 'Opening room…');
    const port: number = await Lan.host(this.picked, (m: LanMsg) => {
      LanRace.receive(m);
      if (m.t === 'hello') {
        this.status = this.t('有人来了！', 'Someone joined!');
      }
    });
    if (port <= 0) {
      this.status = this.t('开房失败', 'Failed to open room');
      return;
    }
    await LanRace.hostStart(this.picked);
    this.status = this.t('竞速开始！谁先完成谁赢', 'Race on! First to finish wins');
    Haptics.success();
    router.pushUrl({ url: 'pages/GameHost', params: { id: this.picked } });
  }

  /** ★ 竞速模式：加入（先问一次当前局） */
  private async raceJoin(room: LanRoom): Promise<void> {
    Haptics.press();
    const ok: boolean = await Lan.join(room, (m: LanMsg) => {
      LanRace.receive(m);
    });
    if (!ok) {
      this.status = this.t('连不上，检查同一 Wi-Fi', 'Cannot connect — check same Wi-Fi');
      return;
    }
    await LanRace.ask();
    this.status = this.t('已加入，等房主开始', 'Joined — waiting for host');
    Haptics.success();
    router.pushUrl({ url: 'pages/GameHost', params: { id: room.gameId } });
  }

  private async hostRoom(): Promise<void> {
    Haptics.tap();
    // ★ 开房 = 我是房主（先手）；所有消息同时喂给对局层
    // ★ P12：第三个参数 gameId 必须传 —— 否则 LanMatch.gameId 是空串，
    //   引擎里收 'diff' 的分支恒假 ⇒ 房主的难度**压根广播不出去**（两边棋盘会不一样）
    LanMatch.begin(true, (d: string) => {
      this.status = this.t('对手落子：', 'Opponent moved: ') + d;
    }, this.picked);
    const port: number = await Lan.host(this.picked, (m: LanMsg) => {
      LanMatch.receive(m);
      LanRace.receive(m);      // ★ 竞速模式（P-race）：和回合制并列，互不干扰
      if (m.t === 'hello') {
        // ★ 对手来了 ⇒ 先把我的难度告诉他，保证两边棋盘一致
        LanMatch.broadcastDiff(this.picked);
        this.status = this.t('对手已连上！开局…', 'Opponent connected! Starting…');
        // ★ 对手来了 ⇒ 直接进游戏（房主先手）
        router.pushUrl({ url: 'pages/GameHost', params: { id: this.picked } });
      }
    });
    this.status = port > 0
      ? this.t('房间已开（端口 ' + port + '）—— 等对手加入', 'Room open on port ' + port + ' — waiting')
      : this.t('开房失败，检查 Wi-Fi', 'Could not host — check your Wi-Fi');
  }

  /** 手动输 IP 直连（绕开 UDP 发现） */
  private async manualJoin(): Promise<void> {
    Haptics.tap();
    const ip: string = this.manualIp.trim();
    if (ip.length === 0) {
      this.status = this.t('先填房主 IP', 'Enter the host IP first');
      return;
    }
    const pt: number = Number.parseInt(this.manualPort.trim(), 10);
    const room: LanRoom = { ip: ip, port: isNaN(pt) ? 41235 : pt, host: 'Host', gameId: this.picked };
    this.status = this.t('正在连接 ' + ip + '…', 'Connecting to ' + ip + '…');
    LanMatch.begin(false, (d: string) => {
      this.status = this.t('对手落子：', 'Opponent moved: ') + d;
    }, this.picked);          // ★ P12：传 gameId，难度广播才生效
    const ok: boolean = await Lan.join(room, (m: LanMsg) => {
      LanMatch.receive(m);
      LanRace.receive(m);      // ★ 竞速模式（P-race）：和回合制并列，互不干扰
      if (m.t === 'ack') {
        this.status = this.t('已连上房主，开局…', 'Connected! Starting…');
        // ★ 握手完成 ⇒ 直接进游戏（加入方后手）
        router.pushUrl({ url: 'pages/GameHost', params: { id: this.picked } });
      }
    });
    this.status = ok
      ? this.t('连上了！等对手开局', 'Connected! Waiting for the host')
      : this.t('连不上 —— 检查 IP 和 Wi-Fi', 'Could not connect — check IP and Wi-Fi');
  }

  private async joinRoom(r: LanRoom): Promise<void> {
    Haptics.tap();
    LanMatch.begin(false, (d: string) => {
      this.status = this.t('对手落子：', 'Opponent moved: ') + d;
    }, this.picked);          // ★ P12：传 gameId，难度广播才生效
    const ok: boolean = await Lan.join(r, (m: LanMsg) => {
      LanMatch.receive(m);
      LanRace.receive(m);      // ★ 竞速模式（P-race）：和回合制并列，互不干扰
      if (m.t === 'ack') {
        this.status = this.t('已连上房主，开局…', 'Connected! Starting…');
        // ★ 握手完成 ⇒ 直接进游戏（加入方后手）
        router.pushUrl({ url: 'pages/GameHost', params: { id: this.picked } });
      }
    });
    this.status = ok ? this.t('连上了！', 'Connected!') : this.t('连不上，可能房主退出了', 'Could not connect');
  }
}
