/**
 * 服务卡片 UI —— 桌面上的一块「一局」
 *
 * 数据来自 LocalStorage（FormExtensionAbility 通过 formBindingData 注入）：
 *   level / title / streak / today / solved / pct
 */

interface CardData {
  level: string;
  title: string;
  streak: string;
  today: string;
  solved: string;
  pct: string;
}

const storage = new LocalStorage();

@Entry(storage)
@Component
struct StatsCard {
  @LocalStorageProp('level') level: string = '1';
  @LocalStorageProp('title') title: string = '新手上路';
  @LocalStorageProp('streak') streak: string = '0';
  @LocalStorageProp('today') today: string = '今天还没玩';
  @LocalStorageProp('solved') solved: string = '0';
  @LocalStorageProp('pct') pct: string = '0';

  private played(): boolean {
    return this.today.indexOf('已') >= 0;
  }

  build() {
    Column({ space: 8 }) {
      // 顶行：名字 + 连胜
      Row() {
        Text('一局')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
        Blank()
        if (Number(this.streak) > 0) {
          Row({ space: 2 }) {
            Text('🔥').accessibilityLevel('no').fontSize(11)
            Text(this.streak).fontSize(11).fontColor('#F59E0B').fontWeight(FontWeight.Bold)
          }
        }
      }
      .width('100%')

      // 主行：等级
      Row({ space: 8 }) {
        Stack() {
          Circle({ width: 40, height: 40 }).fill('#6366F1')
          Column() {
            Text('LV').fontSize(8).fontColor('#CCFFFFFF')
            Text(this.level).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          }
        }
        .width(40).height(40)

        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
            .maxLines(1)
          Text(this.played() ? '✅ ' + this.today : '⭕ ' + this.today)
            .fontSize(10)
            .fontColor(this.played() ? '#10B981' : '#94A3B8')
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5).backgroundColor('#33FFFFFF').borderRadius(3)
        Row().width(this.pct + '%').height(5).backgroundColor('#6366F1').borderRadius(3)
      }
      .width('100%').height(5)

      Text('累计 ' + this.solved + ' 局 · 点我开一局')
        .fontSize(9)
        .fontColor('#94A3B8')
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#1E1B4B')
    .borderRadius(16)
  }
}
