/**
 * GameJump —— 临时页：游戏清单，点一款直接进 GameHost
 *
 * ★ 为什么需要它（2026-10-30）：
 *   要验「某某游戏在横屏下底部按钮是否被切」，就得先打开那一款。
 *   但设备上 355 款的列表要滚很久才能定位（实测 45 页只找到 2/17），
 *   而且 dump() 拿不到元素 id，滚动定位不可靠。
 *
 *   GameHost 是用 `router.getParams().id` 拿 gameId 的（GameHost.ets:493-496）
 *   ⇒ 这个页直接 pushUrl 进去，**绕过列表，秒开任意一款**。
 *
 *   ★ 一次 build 就能验完一批：下面 LIST 里放全部待验游戏，
 *     点一款 → 验 → 返回 → 点下一款。
 *
 * 验完删页面 + 注销路由 + 恢复 Splash。
 */
import { router } from '@kit.ArkUI';

interface Item { id: string; name: string }

const LIST: Item[] = [
  { id: 'compound_connect', name: '复合连线' },
  { id: 'dual_mirror', name: '双镜像' },
  { id: 'go9', name: '9 路围棋' },
  { id: 'life_game', name: '生命游戏' },
  { id: 'lock_pattern', name: '图案锁' },
  { id: 'mahjong_solitaire', name: '麻将连连看' },
  { id: 'match3', name: '三连' },
  { id: 'maze_nav3d', name: '3D 迷宫' },
  { id: 'mental_mapping', name: '心理地图' },
  { id: 'mirror_maze', name: '镜像迷宫' },
  { id: 'reversi', name: '黑白棋（已修）' },
  { id: 'sieve_visualizer', name: '筛法可视化' },
  { id: 'slide_puzzle', name: '数字华容道' },
  { id: 'slitherlink', name: '数回环' },
  { id: 'snake', name: '贪吃蛇' },
  { id: 'sum_snake', name: '数蛇' },
  { id: 'tapa', name: '塔帕' },
];

@Entry
@Component
struct GameJump {
  private go(id: string): void {
    router.pushUrl({ url: 'pages/GameHost', params: { id: id } });
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Text('待验游戏（横屏 853×533）')
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFF')
          .margin({ top: 12, bottom: 6 })
        ForEach(LIST, (it: Item) => {
          Button(it.name + '   ' + it.id)
            .width('96%')
            .height(50)
            .fontSize(15)
            .backgroundColor('#2A3550')
            .fontColor('#E8E8E8')
            .borderRadius(10)
            .onClick(() => { this.go(it.id); })
        }, (it: Item) => it.id)
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .width('100%').height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#0D1320')
  }
}
