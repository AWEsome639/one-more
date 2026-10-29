import { i18n } from '@kit.LocalizationKit';
/**
萬與專業叢東絲兩嚴個豐臨為麗舉麼義烏樂習書買亂於雲亞親從們價優會傘傳傷倫偽體餘偵側倆儉債傾儲兒蘭關興茲養獸內冊寫衝決淨準涼減湊幾憑凱擊鑿則剛刪別劍劇辦務動區醫華單賣佔卻廠曆壓廚參雙發變疊號後嚇嗎聽啓吶員響嚙囉嚕團園圍國圖圓聖場塊堅牆壯聲殼處備復夠頭夾學寶實寵宮寬賓對導將爾盡層屜屬嶼嵐島巔幣師帳簾帶幀幫冪並廣莊庫應廟廢開異棄張彎彈強歸當錄徹徵徑憶誌態總惡驚癒懶戲戰戶撲執擴掃擾撫搶護報擔攏擁撥擇掛擋擠撈撿換據擺搖攤撐攢數斷無舊時顯曉暈暫術機雜權條來楊極構櫃檸標棟樹樣檔橋檢稜樓橫櫻歡歐氣匯漢沈沒灑淺漿澆測濃塗渙漲澀淵漸滲溫遊濕滾滿灘潛滅燈靈點煉燭煙煩燒熱愛狀猶獨獅獵貓璣瑪環現電畫暢盞監蓋盤著睜碼磚礎確礙禮離種積稱穩窺竪筆籠築篩箏簡籃類緊紅約級紉純納紙紋線練組細織終經綁結繞繪給絡絕統繼續維綿綢綠綴纜緩編縫纏網羅罰聾聯聰膽勝衚腦腳脫臉臘捨節蒼蘇蘋範藥蘿營薩蔥藍虛蟲蟻螞蠟蠅補襪裝褲見觀規視覽覺計認讓議記講許論設訣證評識診詞譯試詩誠話誕該語誤說請諾讀課誰調談誼謎謙負敗賬質貪購貫貼貴費賭賽贏趙趕躍蹤車軌轉輪軟軸輕較輔輛輝輯輸辭邊達過運還這進遠違連遲適選遜遞邏郵鄰醬採釋裡針鐘鋼鑰鈎鈕錢鐵鉛銅鏟銀鋪鏈銷鎖鍋鋒錯錨鍵鏡鑲長門閃閉問閏閒間鬧閣閱闊陽陰陣階際陳險隨隱難雛霧靜韋韓韻頁頂項順須預頸頻顆題顏額風飄飛飯飲飾餅館饋馬駝駱驗騎騙驟魚魯鮮鯨鳥雞鵝鵡鸚黃齊齒齡龍龜產僅眾訊訪詰諒謂謝賢貨資賴軒載輩跡釣聞績馆馈马驼骆验骑骗骤鱼鲁鲜鲸鸟鸡鹅鹉鹦黄齐齿龄龙龟产仅众讯访诘谅谓谢贤货资赖轩载辈迹钓闻绩龟绩L()` 写成 `if (cur === ZH || cur === ZHTW) return zh;` —— **繁体被短路成简体**，
 *      字典里 281 条 zh-Hant 译文一条都用不上。现在繁体先查字典，再走 `toTrad()` 转换。
 *   ② 繁体不能只靠字典：界面还有大量没进字典的裸中文 ⇒ 补一张 578 单字 + 128 词的转换表。
 *   ③ 语言选择用 `PersistentStorage` 落盘（以前只在内存里，重启就回简体）。
 */

/** 支持的语言 */
export enum Lang {
  ZH = 'zh',
  ZHTW = 'zh-Hant',
  EN = 'en',
  JA = 'ja',
  KO = 'ko',
  ES = 'es',
  FR = 'fr',
  DE = 'de',
  PT = 'pt',
  RU = 'ru',
  IT = 'it',
  AR = 'ar',
}

/** 语言信息（给选择器用） */
export interface LangInfo {
  code: string;
  native: string;   // 用该语言自己的写法
  zh: string;       // 中文名（便于中文用户找）
  flag: string;
}

export const LANGS: LangInfo[] = [
  { code: Lang.ZH, native: '简体中文', zh: '简体中文', flag: '🇨🇳' },
  { code: Lang.ZHTW, native: '繁體中文', zh: '繁体中文', flag: '🇭🇰' },
  { code: Lang.EN, native: 'English', zh: '英语', flag: '🇬🇧' },
  { code: Lang.JA, native: '日本語', zh: '日语', flag: '🇯🇵' },
  { code: Lang.KO, native: '한국어', zh: '韩语', flag: '🇰🇷' },
  { code: Lang.ES, native: 'Español', zh: '西班牙语', flag: '🇪🇸' },
  { code: Lang.FR, native: 'Français', zh: '法语', flag: '🇫🇷' },
  { code: Lang.DE, native: 'Deutsch', zh: '德语', flag: '🇩🇪' },
  { code: Lang.PT, native: 'Português', zh: '葡萄牙语', flag: '🇵🇹' },
  { code: Lang.RU, native: 'Русский', zh: '俄语', flag: '🇷🇺' },
  { code: Lang.IT, native: 'Italiano', zh: '意大利语', flag: '🇮🇹' },
  { code: Lang.AR, native: 'العربية', zh: '阿拉伯语', flag: '🇸🇦' },
];

export class I18n {
  /** ★ 语言缓存 —— 热路径里绝不能读 AppStorage（700+ 次代理查询会触发 THREAD_BLOCK_6S） */
  private static cached: string = '';

  /**
   * 语言落盘（只做一次）—— **必须在 UI 实例创建之前调用**
   *
   * ★ 背景：语言以前只存 AppStorage（内存）⇒ 重启回简体，用户觉得"切了没用"。
   *
   * ★★ 2026-10-13 模拟器实测（差点写成假修复）：
   *   · 一开始我把这句放在 `current()` 里**懒调**（首次取词时才调，那时 UI 已经建好）
   *     ⇒ 结果 `persistent_storage` 里**只有默认值 `zh`**：切换语言后**写不进去**，
   *       重启照样回简体（主题色却正常，因为 Design.ets 是在**模块加载期**调的）。
   *   · 改成**模块加载期**调用（本文件末尾 `I18n.initPersist()`，早于 windowStage.loadContent）
   *     ⇒ 模拟器复验：切语言后文件立刻变成所选语言，杀进程重启**留住** ✅
   *   ⇒ 结论：`PersistentStorage.persistProp` 要**早于 UI 实例**，晚了只写一次默认值、后续不同步。
   *
   * ⚠️ 卡片（Form）等没有 UI 上下文的进程里可能不可用 ⇒ try/catch 兜住，失败不影响取词。
   */
  private static persistTried: boolean = false;

  static initPersist(): void {
    // ★ 2026-10-13 模拟器实测后**停用** PersistentStorage：
    //   它在本工程「只写不读」—— 切完语言文件里确实写了 lang="zh-Hant"，
    //   但 force-stop 重启后界面照旧是简体，且它启动时会把文件覆盖回默认值。
    //   ⇒ 落盘改走 ProgressStore 的 preferences 通道（saveLang / init 里恢复）。
    //   这里保留空实现，是为了不破坏卡片进程等老调用点。
  }

  static current(): string {
    if (I18n.cached.length === 0) {
      I18n.initPersist();   // 兜底：模块加载期没调成（如卡片进程）时再试一次
      I18n.cached = AppStorage.get<string>('lang') ?? Lang.ZH;
    }
    return I18n.cached;
  }

  static isEN(): boolean {
    return I18n.current() === Lang.EN;
  }

  /** 是不是中文系（简/繁都用中文原文，只是字形不同） */
  static isZH(): boolean {
    const c: string = I18n.current();
    return c === Lang.ZH || c === Lang.ZHTW;
  }

  /** 是不是繁体中文（zh-Hant）—— 繁体要额外做 简→繁 转换 */
  static isHant(): boolean {
    return I18n.current() === Lang.ZHTW;
  }

  static set(lang: string): void {
    I18n.cached = lang;
    AppStorage.setOrCreate('lang', lang);
  }

  static refresh(): void {
    I18n.initPersist();
    I18n.cached = AppStorage.get<string>('lang') ?? Lang.ZH;
  }

  /**
   * ★★★ 2026-10-17 20:1x 新增：首启检测系统语言
   *
   * 背景：原来「一局」装在英文手机上首启也是中文（语言只由 app 内选择器决定）。
   * 对 355 款游戏 × 12 语言的产品，首启跟系统语言是更符合直觉的默认。
   *
   * 做法：读系统语言 → 映射到本 app 支持的 12 个代码 → 不认识的退回中文。
   * 只在【用户还没选过语言】时调用一次（ProgressStore.init 里 savedLang 为空时）。
   * 失败一律退回中文，绝不让首启在这里崩。
   */
  static detectSystemLang(): string {
    try {
      const sys: string = i18n.System.getSystemLanguage();   // 如 'zh-Hans'/'en'/'ja'
      const low: string = sys.toLowerCase();
      // ★ 繁体优先判断（zh-Hant / zh-TW / zh-HK / zh-MO）
      if (low.indexOf('hant') >= 0 || low.indexOf('zh-tw') >= 0
        || low.indexOf('zh-hk') >= 0 || low.indexOf('zh-mo') >= 0) {
        return Lang.ZHTW;
      }
      // ★ 简体（zh / zh-CN / zh-Hans / zh-SG）
      if (low.indexOf('zh') === 0) {
        return Lang.ZH;
      }
      // ★ 其余 10 种：取主语言（'en-US' → 'en'）
      const base: string = low.split('-')[0];
      for (let i = 0; i < LANGS.length; i++) {
        if (LANGS[i].code === base) {
          return LANGS[i].code;
        }
      }
      return Lang.ZH;   // 不认识 ⇒ 中文（主市场）
    } catch (e) {
      return Lang.ZH;   // 任何异常都不影响首启
    }
  }

  /** 该语言是否从右往左排 */
  static isRTL(): boolean {
    return I18n.current() === Lang.AR;
  }
}

/**
 * 「简 → 繁」转换表（zh-Hant 兜底）
 *
 * 为什么需要它：字典只收 281 条中文原文，界面里还有大量没进字典的裸中文
 * （游戏内文案、成就名、数字拼接串）。繁体用户若只靠字典，这些地方会一直是简体。
 *
 * 表怎么来的（tools/gen_s2t.py 生成，勿手改）：
 *   ① 把全项目 5,009 条中文字面量过一遍 ICU 的 Simplified-Traditional 转换；
 *   ② 逐字对齐投票 ⇒ 只取「语料内 100% 一致」的 578 个单字（多义字一律不进单字表）；
 *   ③ 多义字（后/里/只/面/回/周/干/复/并/采/舍/准…）交给词语表按最长匹配兜底；
 *   ④ 词表口径与应用自带 281 条 zh-Hant 译文对齐（台灣用語：資料/資訊/設定/螢幕/介面…）。
 *
 * 覆盖实测：ICU 参照一致率 97.7%（5,009 条），46 个易错词（游泳/干活/皇后/公里/词汇…）
 * 全部正确；不一致的那 2.3% 多是 ICU 偏港式（后/里/余）而本表按台灣口径转换。
 */
const S2T_FROM: string =
  '万与专业丛东丝两严个丰临为丽举么义乌乐习书买乱于云亚亲从们价优会伞传伤伦伪体余侦侧俩俭债倾储儿兰关兴兹养兽内册写冲决净准凉减凑几凭凯击凿则刚删别剑剧办务动区医华单卖占却厂历压厨参双发变叠号后吓吗听启呐员响啮啰噜团园围国图圆圣场块坚墙壮声壳处备复够头夹学宝实宠宫宽宾对导将尔尽层屉属屿岚岛巅币师帐帘带帧帮幂并广庄库应庙废开异弃张弯弹强归当录彻征径忆志态总恶惊愈懒戏战户扑执扩扫扰抚抢护报担拢拥拨择挂挡挤捞捡换据摆摇摊撑攒数断无旧时显晓晕暂术机杂权条来杨极构柜柠标栋树样档桥检棱楼横樱欢欧气汇汉沉没洒浅浆浇测浓涂涣涨涩渊渐渗温游湿滚满滩潜灭灯灵点炼烛烟烦烧热爱状犹独狮猎猫玑玛环现电画畅盏监盖盘着睁码砖础确碍礼离种积称稳窥竖笔笼筑筛筝简篮类紧红约级纫纯纳纸纹线练组细织终经绑结绕绘给络绝统继续维绵绸绿缀缆缓编缝缠网罗罚聋联聪胆胜胡脑脚脱脸腊舍节苍苏苹范药萝营萨葱蓝虚虫蚁蚂蜡蝇补袜装裤见观规视览觉计认让议记讲许论设诀证评识诊词译试诗诚话诞该语误说请诺读课谁调谈谊谜谦负败账质贪购贯贴贵费赌赛赢赵赶跃踪车轨转轮软轴轻较辅辆辉辑输辞边达过运还这进远违连迟适选逊递逻邮邻酱采释里针钟钢钥钩钮钱铁铅铜铲银铺链销锁锅锋错锚键镜镶长门闪闭问闰闲间闹阁阅阔阳阴阵阶际陈险随隐难雏雾静韦韩韵页顶项顺须预颈频颗题颜额风飘飞饭饮饰饼馆馈马驼骆验骑骗骤鱼鲁鲜鲸鸟鸡鹅鹉鹦黄齐齿龄龙龟产仅众讯访诘谅谓谢贤货资赖轩载辈迹钓闻绩';
const S2T_TO: string =
  '萬與專業叢東絲兩嚴個豐臨為麗舉麼義烏樂習書買亂於雲亞親從們價優會傘傳傷倫偽體餘偵側倆儉債傾儲兒蘭關興茲養獸內冊寫衝決淨準涼減湊幾憑凱擊鑿則剛刪別劍劇辦務動區醫華單賣佔卻廠曆壓廚參雙發變疊號後嚇嗎聽啓吶員響嚙囉嚕團園圍國圖圓聖場塊堅牆壯聲殼處備復夠頭夾學寶實寵宮寬賓對導將爾盡層屜屬嶼嵐島巔幣師帳簾帶幀幫冪並廣莊庫應廟廢開異棄張彎彈強歸當錄徹徵徑憶誌態總惡驚癒懶戲戰戶撲執擴掃擾撫搶護報擔攏擁撥擇掛擋擠撈撿換據擺搖攤撐攢數斷無舊時顯曉暈暫術機雜權條來楊極構櫃檸標棟樹樣檔橋檢稜樓橫櫻歡歐氣匯漢沈沒灑淺漿澆測濃塗渙漲澀淵漸滲溫遊濕滾滿灘潛滅燈靈點煉燭煙煩燒熱愛狀猶獨獅獵貓璣瑪環現電畫暢盞監蓋盤著睜碼磚礎確礙禮離種積稱穩窺竪筆籠築篩箏簡籃類緊紅約級紉純納紙紋線練組細織終經綁結繞繪給絡絕統繼續維綿綢綠綴纜緩編縫纏網羅罰聾聯聰膽勝衚腦腳脫臉臘捨節蒼蘇蘋範藥蘿營薩蔥藍虛蟲蟻螞蠟蠅補襪裝褲見觀規視覽覺計認讓議記講許論設訣證評識診詞譯試詩誠話誕該語誤說請諾讀課誰調談誼謎謙負敗賬質貪購貫貼貴費賭賽贏趙趕躍蹤車軌轉輪軟軸輕較輔輛輝輯輸辭邊達過運還這進遠違連遲適選遜遞邏郵鄰醬採釋裡針鐘鋼鑰鈎鈕錢鐵鉛銅鏟銀鋪鏈銷鎖鍋鋒錯錨鍵鏡鑲長門閃閉問閏閒間鬧閣閱闊陽陰陣階際陳險隨隱難雛霧靜韋韓韻頁頂項順須預頸頻顆題顏額風飄飛飯飲飾餅館饋馬駝駱驗騎騙驟魚魯鮮鯨鳥雞鵝鵡鸚黃齊齒齡龍龜產僅眾訊訪詰諒謂謝賢貨資賴軒載輩跡釣聞績';

/** 词语表 —— 两两一对：原文, 繁体（长匹配优先，最长 6 字） */
const S2T_WORDS: string[] = [
  '兴高采烈', '興高采烈',
  '没关系啦', '沒關係啦',
  '游来游去', '游來游去',
  '文件夹', '資料夾',
  '服务器', '伺服器',
  '没关系', '沒關係',
  '一只', '一隻',
  '一周', '一週',
  '万里', '萬里',
  '三只', '三隻',
  '上周', '上週',
  '上游', '上游',
  '下周', '下週',
  '下游', '下游',
  '不准', '不准',
  '两只', '兩隻',
  '两周', '兩週',
  '丰采', '丰采',
  '信息', '資訊',
  '公里', '公里',
  '关系', '關係',
  '兼并', '兼併',
  '准予', '准予',
  '准许', '准許',
  '几只', '幾隻',
  '千里', '千里',
  '反馈', '回饋',
  '台风', '颱風',
  '合并', '合併',
  '后冠', '后冠',
  '后妃', '后妃',
  '向导', '嚮導',
  '周一', '週一',
  '周三', '週三',
  '周二', '週二',
  '周五', '週五',
  '周六', '週六',
  '周四', '週四',
  '周围', '周圍',
  '周年', '週年',
  '周报', '週報',
  '周日', '週日',
  '周末', '週末',
  '喝采', '喝采',
  '回廊', '迴廊',
  '回形', '迴形',
  '回旋', '迴旋',
  '回纹', '迴紋',
  '回路', '迴路',
  '复制', '複製',
  '复句', '複句',
  '复数', '複數',
  '复杂', '複雜',
  '复选', '複選',
  '太后', '太后',
  '字汇', '字彙',
  '宿舍', '宿舍',
  '寒舍', '寒舍',
  '屏幕', '螢幕',
  '干事', '幹事',
  '干净', '乾淨',
  '干旱', '乾旱',
  '干杯', '乾杯',
  '干枯', '乾枯',
  '干活', '幹活',
  '干燥', '乾燥',
  '干练', '幹練',
  '干货', '乾貨',
  '干部', '幹部',
  '并数', '併數',
  '并购', '併購',
  '影后', '影后',
  '批准', '批准',
  '折叠', '摺疊',
  '折扇', '摺扇',
  '折纸', '摺紙',
  '拉面', '拉麵',
  '放松', '放鬆',
  '故里', '故里',
  '数只', '數隻',
  '数据', '資料',
  '本周', '本週',
  '松林', '松林',
  '松果', '松果',
  '松柏', '松柏',
  '松树', '松樹',
  '松针', '松針',
  '松鼠', '松鼠',
  '校舍', '校舍',
  '棋后', '棋后',
  '每只', '每隻',
  '每周', '每週',
  '泡面', '泡麵',
  '游动', '游動',
  '游标', '游標',
  '游泳', '游泳',
  '游走', '游走',
  '王后', '王后',
  '界面', '介面',
  '百里', '百里',
  '皇后', '皇后',
  '神采', '神采',
  '网络', '網路',
  '联系', '聯繫',
  '舍友', '舍友',
  '船只', '船隻',
  '获准', '獲准',
  '视频', '視訊',
  '记录', '記錄',
  '设备', '裝置',
  '设置', '設定',
  '词汇', '詞彙',
  '语汇', '語彙',
  '轻松', '輕鬆',
  '这只', '這隻',
  '那只', '那隻',
  '邻里', '鄰里',
  '里拉', '里拉',
  '里程', '里程',
  '里长', '里長',
  '重复', '重複',
  '面包', '麵包',
  '面条', '麵條',
  '面粉', '麵粉',
  '面食', '麵食',
  '面馆', '麵館',
  '风采', '風采',
  '饼干', '餅乾',
];

/** 单字表 / 词表 → Map（模块加载时建一次，转换是冷路径，不进热路径） */
function toMap(keys: string, vals: string): Map<string, string> {
  const m: Map<string, string> = new Map<string, string>();
  const n: number = keys.length < vals.length ? keys.length : vals.length;
  for (let i = 0; i < n; i++) {
    m.set(keys.charAt(i), vals.charAt(i));
  }
  return m;
}

function toPairMap(flat: string[]): Map<string, string> {
  const m: Map<string, string> = new Map<string, string>();
  for (let i = 0; i + 1 < flat.length; i += 2) {
    m.set(flat[i], flat[i + 1]);
  }
  return m;
}

const S2T_CHAR: Map<string, string> = toMap(S2T_FROM, S2T_TO);
const S2T_WORD: Map<string, string> = toPairMap(S2T_WORDS);
/** 词表最长匹配长度 */
const S2T_MAX: number = 6;

/**
 * 简体 → 繁体
 *
 * 只给繁体模式兜底用：字典里有显式 zh-Hant 的走字典（口径更好），
 * 没有的（裸中文、游戏内文案、动态拼接串）走这里，**绝不留在简体**。
 */
export function toTrad(s: string): string {
  const n: number = s.length;
  if (n === 0) {
    return s;
  }
  let out: string = '';
  let i: number = 0;
  while (i < n) {
    // ① 先按词表做最长匹配（多义字靠词兜：皇后/一只/干活/面包/回路/周末…）
    let hit: string | undefined = undefined;
    let used: number = 0;
    let len: number = S2T_MAX;
    while (len >= 2) {
      if (i + len <= n) {
        const w: string | undefined = S2T_WORD.get(s.substring(i, i + len));
        if (w !== undefined) {
          hit = w;
          used = len;
          break;
        }
      }
      len--;
    }
    if (hit !== undefined) {
      out += hit;
      i += used;
      continue;
    }
    // ② 单字表；表里没有的原样输出（数字、英文、emoji 天然不受影响）
    const c: string = s.charAt(i);
    const t: string | undefined = S2T_CHAR.get(c);
    out += (t === undefined ? c : t);
    i++;
  }
  return out;
}

/**
 * 给「不走字典」的裸中文用的一行式转换：
 *   `Text(TZ('游戏'))` ⇒ 简体/英文模式下原样，繁体模式下「遊戲」
 * 已经走 `L()`/`this.t()` 的文案不用它（L 内部已经处理）。
 */
export function TZ(zh: string): string {
  return I18n.isHant() ? toTrad(zh) : zh;
}

/**
 * 额外语言的文案字典：EXTRA[中文原文][语言码] = 译文
 *
 * ⚠️ 缺项一律**退回英文**，绝不显示空白 —— 半翻译好过没翻译。
 * 加新语言：往每一行加一个键即可（生成器 tools/gen_langs.py 批量产出）。
 */

/** ★★★ 2026-10-16 游戏名本地化 —— 起因：奥森「每种语言都要认真对待」
 *  实测：非中文语言下 displayName 直接返回 enName ⇒ 日语玩家看到英文游戏名
 *  ⇒ 这里按 game id 存 9 种语言的本地名；中/英仍走原字段，繁体走 toTrad。 */

/** ★★★ 2026-10-16 游戏一句话说明的本地化（与 GAME_NAME 同因） */
const GAME_TAGLINE: Record<string, Record<string, string>> = {
  "navon_hierarchical": { "ja": "大きな図と小さな図がぶつかる", "ko": "큰 그림과 작은 그림 충돌", "fr": "Grande et petite figure en conflit", "de": "Großes und kleines Bild im Konflikt", "es": "Figura grande y pequeña en conflicto", "ru": "Большая и малая фигура спорят", "ar": "الشكل الكبير والصغير متعارضان", "pt": "Figura grande e pequena em conflito", "it": "Figura grande e piccola in conflitto" },
  "odd_one_out": { "ja": "仲間はずれを探せ", "ko": "다른 것 찾기", "fr": "Trouvez l’intrus", "de": "Finde den Ausreißer", "es": "Encuentra al intruso", "ru": "Найди лишнее", "ar": "ابحث عن المختلف", "pt": "Encontre o intruso", "it": "Trova l’intruso" },
  "odd_rotation": { "ja": "回転が違うものを探せ", "ko": "회전이 다른 것 찾기", "fr": "Trouvez la rotation différente", "de": "Finde die andere Drehung", "es": "Encuentra la rotación distinta", "ru": "Найди другой поворот", "ar": "ابحث عن الدوران المختلف", "pt": "Ache a rotação diferente", "it": "Trova la rotazione diversa" },
  "orbit_tap": { "ja": "軌道上の的を叩け", "ko": "궤도 위 목표 누르기", "fr": "Touchez la cible en orbite", "de": "Ziel auf der Umlaufbahn treffen", "es": "Toca el objetivo en órbita", "ru": "Попади в цель на орбите", "ar": "انقر الهدف في المدار", "pt": "Toque o alvo em órbita", "it": "Tocca il bersaglio in orbita" },
  "paper_folding": { "ja": "折ってから穴を開けろ", "ko": "접은 뒤 구멍 뚫기", "fr": "Pliez puis percez", "de": "Falten und lochen", "es": "Pliega y perfora", "ru": "Сложи и проколи", "ar": "اطوِ ثم اثقب", "pt": "Dobre e perfure", "it": "Piega e fora" },
  "path_recall": { "ja": "通った道を覚えろ", "ko": "지나온 길 기억", "fr": "Retenez le chemin parcouru", "de": "Merke den gegangenen Weg", "es": "Recuerda el camino recorrido", "ru": "Запомни пройденный путь", "ar": "تذكّر المسار الذي سلكته", "pt": "Memorize o caminho percorrido", "it": "Ricorda il percorso fatto" },
  "perspective_shift_view": { "ja": "視点を変えて見ろ", "ko": "시점 바꿔 보기", "fr": "Changez de point de vue", "de": "Perspektive wechseln", "es": "Cambia de perspectiva", "ru": "Смени точку зрения", "ar": "غيّر زاوية النظر", "pt": "Mude de perspetiva", "it": "Cambia prospettiva" },
  "perspective_taking": { "ja": "相手の立場で見ろ", "ko": "상대 입장에서 보기", "fr": "Adoptez le point de vue d’autrui", "de": "Nimm die Sicht des anderen ein", "es": "Ponte en su lugar", "ru": "Встань на место другого", "ar": "تبنَّ وجهة نظر الآخر", "pt": "Ponha-se no lugar do outro", "it": "Mettiti nei panni altrui" },
  "pixel_mimic": { "ja": "見本どおりにドットを打て", "ko": "견본대로 픽셀 찍기", "fr": "Reproduisez les pixels", "de": "Pixel nachbilden", "es": "Reproduce los píxeles", "ru": "Повтори пиксели", "ar": "انسخ البكسلات", "pt": "Reproduza os píxeis", "it": "Riproduci i pixel" },
  "polyomino_tiling": { "ja": "ピースで盤を埋め尽くせ", "ko": "조각으로 판 채우기", "fr": "Remplissez la grille de pièces", "de": "Fülle das Gitter mit Teilen", "es": "Rellena el tablero con piezas", "ru": "Заполни поле фигурами", "ar": "املأ اللوح بالقطع", "pt": "Preencha o tabuleiro", "it": "Riempi la griglia" },
  "room_inspector": { "ja": "部屋の違いを見つけろ", "ko": "방 안의 차이 찾기", "fr": "Trouvez les différences de la pièce", "de": "Finde die Unterschiede im Raum", "es": "Encuentra las diferencias", "ru": "Найди отличия в комнате", "ar": "ابحث عن اختلافات الغرفة", "pt": "Ache as diferenças da sala", "it": "Trova le differenze" },
  "rotating_maze": { "ja": "回る迷路を進め", "ko": "도는 미로 나아가기", "fr": "Avancez dans le labyrinthe tournant", "de": "Im Drehlabyrinth voran", "es": "Avanza en el laberinto giratorio", "ru": "Иди по вращающемуся лабиринту", "ar": "تقدّم في المتاهة الدوّارة", "pt": "Avance no labirinto giratório", "it": "Avanza nel labirinto rotante" },
  "shadow_pivot": { "ja": "光に合わせて影が回る", "ko": "빛에 따라 그림자 회전", "fr": "L’ombre tourne avec la lumière", "de": "Schatten dreht mit dem Licht", "es": "La sombra gira con la luz", "ru": "Тень вращается со светом", "ar": "يدور الظل مع الضوء", "pt": "A sombra gira com a luz", "it": "L’ombra gira con la luce" },
  "shape_shifter": { "ja": "形が変わるものを見分けろ", "ko": "모양이 바뀌는 것 구별", "fr": "Repérez la forme changeante", "de": "Erkenne die wechselnde Form", "es": "Detecta la forma cambiante", "ru": "Различи изменчивую форму", "ar": "ميّز الشكل المتغيّر", "pt": "Detete a forma mutável", "it": "Individua la forma mutante" },
  "silhouette_match": { "ja": "影の形を合わせろ", "ko": "그림자 모양 맞추기", "fr": "Associez les silhouettes", "de": "Silhouetten zuordnen", "es": "Empareja las siluetas", "ru": "Подбери силуэты", "ar": "طابق الظلال", "pt": "Emparelhe as silhuetas", "it": "Abbina le silhouette" },
  "silhouette_match_ortho": { "ja": "正投影の影を合わせろ", "ko": "정투영 그림자 맞추기", "fr": "Associez les silhouettes orthogonales", "de": "Orthogonale Silhouetten zuordnen", "es": "Empareja siluetas ortogonales", "ru": "Подбери ортогональные силуэты", "ar": "طابق الظلال المتعامدة", "pt": "Emparelhe silhuetas ortogonais", "it": "Abbina silhouette ortogonali" },
  "simon_command": { "ja": "指令どおりに動け", "ko": "지시대로 움직이기", "fr": "Faites ce qui est ordonné", "de": "Folge den Anweisungen", "es": "Haz lo que se ordena", "ru": "Делай, что велено", "ar": "نفّذ ما يُطلب", "pt": "Faça o que é pedido", "it": "Fai ciò che è chiesto" },
  "simon_sequence": { "ja": "光った順番を覚えろ", "ko": "빛난 순서 기억", "fr": "Retenez l’ordre des lumières", "de": "Merke die Lichtfolge", "es": "Recuerda el orden de las luces", "ru": "Запомни порядок огней", "ar": "احفظ ترتيب الأضواء", "pt": "Memorize a ordem das luzes", "it": "Ricorda l’ordine delle luci" },
  "source_monitoring": { "ja": "情報の出どころを覚えろ", "ko": "정보 출처 기억", "fr": "Retenez la source de l’info", "de": "Merke die Quelle der Info", "es": "Recuerda la fuente", "ru": "Запомни источник", "ar": "تذكّر مصدر المعلومة", "pt": "Memorize a fonte", "it": "Ricorda la fonte" },
  "spatial_conflict": { "ja": "ぶつかる課題をこなせ", "ko": "충돌하는 과제 해내기", "fr": "Gérez des tâches conflictuelles", "de": "Konflikthafte Aufgaben lösen", "es": "Resuelve tareas en conflicto", "ru": "Решай конфликтующие задачи", "ar": "أنجز مهامًا متعارضة", "pt": "Resolva tarefas em conflito", "it": "Gestisci compiti in conflitto" },
  "sternberg_task": { "ja": "短時間で記憶を走査しろ", "ko": "짧은 시간에 기억 훑기", "fr": "Balayez la mémoire brièvement", "de": "Kurz das Gedächtnis durchsuchen", "es": "Rastrea la memoria brevemente", "ru": "Быстро просканируй память", "ar": "امسح الذاكرة سريعًا", "pt": "Percorra a memória brevemente", "it": "Scansiona la memoria" },
  "symmetry": { "ja": "対称軸を探せ", "ko": "대칭축 찾기", "fr": "Trouvez l’axe de symétrie", "de": "Finde die Symmetrieachse", "es": "Encuentra el eje de simetría", "ru": "Найди ось симметрии", "ar": "ابحث عن محور التماثل", "pt": "Ache o eixo de simetria", "it": "Trova l’asse di simmetria" },
  "symmetry_span": { "ja": "対称な図を覚えろ", "ko": "대칭 도형 기억", "fr": "Retenez les figures symétriques", "de": "Symmetrische Figuren merken", "es": "Recuerda las figuras simétricas", "ru": "Запомни симметричные фигуры", "ar": "احفظ الأشكال المتماثلة", "pt": "Memorize as figuras simétricas", "it": "Ricorda le figure simmetriche" },
  "tangram": { "ja": "目標の形に組み上げろ", "ko": "목표 모양으로 맞추기", "fr": "Reconstituez la forme cible", "de": "Zielform zusammensetzen", "es": "Recompón la forma objetivo", "ru": "Собери целевую фигуру", "ar": "ركّب الشكل الهدف", "pt": "Recomponha a forma alvo", "it": "Componi la forma bersaglio" },
  "temporal_order": { "ja": "出来事を順に並べろ", "ko": "사건을 순서대로", "fr": "Classez les événements", "de": "Ereignisse ordnen", "es": "Ordena los acontecimientos", "ru": "Расставь события", "ar": "رتّب الأحداث", "pt": "Ordene os acontecimentos", "it": "Ordina gli eventi" },
  "temporal_order_judgment": { "ja": "どちらが先か判断しろ", "ko": "어느 쪽이 먼저인지 판단", "fr": "Dites lequel vient en premier", "de": "Entscheide, was zuerst kam", "es": "Di cuál fue primero", "ru": "Определи, что было раньше", "ar": "حدّد أيّهما أولًا", "pt": "Diga qual veio primeiro", "it": "Di quale è venuto prima" },
  "topology": { "ja": "トポロジー的に同じか判断しろ", "ko": "위상적으로 같은지 판단", "fr": "Jugez l’équivalence topologique", "de": "Topologische Gleichheit beurteilen", "es": "Juzga la equivalencia topológica", "ru": "Оцени топологическую эквивалентность", "ar": "احكم على التكافؤ الطوبولوجي", "pt": "Julgue a equivalência topológica", "it": "Giudica l’equivalenza topologica" },
  "tower_of_hanoi": { "ja": "古典的な再帰パズル", "ko": "고전 재귀 퍼즐", "fr": "Le casse-tête récursif classique", "de": "Der klassische Rekursionspuzzle", "es": "El puzle recursivo clásico", "ru": "Классическая рекурсия", "ar": "أحجية العودية الكلاسيكية", "pt": "O puzzle recursivo clássico", "it": "Il classico puzzle ricorsivo" },
  "tower_of_london": { "ja": "手順を計画して移せ", "ko": "순서를 계획해 옮기기", "fr": "Planifiez les déplacements", "de": "Züge vorausplanen", "es": "Planifica los movimientos", "ru": "Планируй ходы", "ar": "خطّط للحركات", "pt": "Planeie os movimentos", "it": "Pianifica le mosse" },
  "trace_path": { "ja": "道に沿って線を引け", "ko": "길을 따라 선 긋기", "fr": "Suivez le chemin au trait", "de": "Linie entlang des Wegs", "es": "Traza la línea por el camino", "ru": "Веди линию по пути", "ar": "ارسم الخط على المسار", "pt": "Trace a linha pelo caminho", "it": "Traccia la linea sul percorso" },
  "triple_sequence": { "ja": "三つの系列を同時に", "ko": "세 계열을 동시에", "fr": "Trois séries en parallèle", "de": "Drei Reihen parallel", "es": "Tres series en paralelo", "ru": "Три ряда одновременно", "ar": "ثلاثة متسلسلات معًا", "pt": "Três séries em paralelo", "it": "Tre serie in parallelo" },
  "triplets_logic": { "ja": "三つの要素で推論しろ", "ko": "세 요소로 추론", "fr": "Raisonnez sur trois éléments", "de": "Mit drei Elementen schließen", "es": "Razona con tres elementos", "ru": "Рассуждай тремя элементами", "ar": "استنتج بثلاثة عناصر", "pt": "Racine com três elementos", "it": "Ragiona con tre elementi" },
  "visual_search_all": { "ja": "難しい視覚探索", "ko": "어려운 시각 탐색", "fr": "Recherche visuelle difficile", "de": "Schwere visuelle Suche", "es": "Búsqueda visual difícil", "ru": "Сложный зрительный поиск", "ar": "بحث بصري صعب", "pt": "Busca visual difícil", "it": "Ricerca visiva difficile" },
  "visual_statistical_learning": { "ja": "隠れた規則を見つけろ", "ko": "숨은 규칙 찾기", "fr": "Découvrez la règle cachée", "de": "Finde die versteckte Regel", "es": "Descubre la regla oculta", "ru": "Найди скрытую закономерность", "ar": "اكتشف القاعدة الخفية", "pt": "Descubra a regra oculta", "it": "Scopri la regola nascosta" },
  "wireframe_3d_rotation": { "ja": "3D 回転を判断しろ", "ko": "3D 회전 판단", "fr": "Jugez la rotation 3D", "de": "3D-Drehung beurteilen", "es": "Juzga la rotación 3D", "ru": "Оцени 3D-поворот", "ar": "احكم على الدوران 3D", "pt": "Julgue a rotação 3D", "it": "Giudica la rotazione 3D" },
  "binary_matrix_rank_all": { "ja": "大きな二進行列の階数", "ko": "큰 이진 행렬 계수", "fr": "Rang d’une grande matrice", "de": "Rang großer Binärmatrizen", "es": "Rango de una matriz grande", "ru": "Ранг большой матрицы", "ar": "رتبة مصفوفة كبيرة", "pt": "Posto de matriz grande", "it": "Rango di matrice grande" },
  "blink_detector": { "ja": "まばたきを捉えろ", "ko": "눈 깜빡임 포착", "fr": "Repérez les clignements", "de": "Erkenne das Blinzeln", "es": "Detecta los parpadeos", "ru": "Лови моргания", "ar": "التقط الرمش", "pt": "Detete as piscadas", "it": "Cattura i battiti" },
  "block_count_3d": { "ja": "立体のブロックを数えろ", "ko": "입체 블록 세기", "fr": "Comptez les cubes en volume", "de": "Zähle die Würfel im Raum", "es": "Cuenta los cubos", "ru": "Посчитай кубики", "ar": "عُدّ المكعبات", "pt": "Conte os cubos", "it": "Conta i cubi" },
  "block_stacking_physics": { "ja": "物理に従って積み上げろ", "ko": "물리대로 쌓기", "fr": "Empilez selon la physique", "de": "Physikalisch stapeln", "es": "Apila según la física", "ru": "Ставь блоки по физике", "ar": "رصّ وفق الفيزياء", "pt": "Empilhe segundo a física", "it": "Impila secondo la fisica" },
  "box_completion": { "ja": "箱を完成させろ", "ko": "상자 완성하기", "fr": "Complétez la boîte", "de": "Vervollständige die Kiste", "es": "Completa la caja", "ru": "Дополни коробку", "ar": "أكمل الصندوق", "pt": "Complete a caixa", "it": "Completa la scatola" },
  "chain_reaction": { "ja": "連鎖を起こせ", "ko": "연쇄 일으키기", "fr": "Déclenchez la réaction", "de": "Löse die Kettenreaktion aus", "es": "Provoca la reacción en cadena", "ru": "Запусти цепную реакцию", "ar": "أطلق التفاعل المتسلسل", "pt": "Provocar a reação em cadeia", "it": "Scatena la reazione" },
  "circuit_connect": { "ja": "回路をつなげ", "ko": "회로 연결하기", "fr": "Connectez le circuit", "de": "Schließe den Stromkreis", "es": "Conecta el circuito", "ru": "Замкни цепь", "ar": "وصّل الدائرة", "pt": "Ligue o circuito", "it": "Collega il circuito" },
  "classic_maze": { "ja": "迷路を抜け出せ", "ko": "미로 빠져나가기", "fr": "Sortez du labyrinthe", "de": "Finde aus dem Labyrinth", "es": "Sal del laberinto", "ru": "Выйди из лабиринта", "ar": "اخرج من المتاهة", "pt": "Saia do labirinto", "it": "Esci dal labirinto" },
  "color_match": { "ja": "同じ色を合わせろ", "ko": "같은 색 맞추기", "fr": "Associez les mêmes couleurs", "de": "Gleiche Farben paaren", "es": "Empareja los mismos colores", "ru": "Подбери одинаковый цвет", "ar": "طابق نفس اللون", "pt": "Emparelhe as mesmas cores", "it": "Abbina gli stessi colori" },
  "color_maze_nav": { "ja": "色の指示どおりに進め", "ko": "색 지시대로 나아가기", "fr": "Avancez selon les couleurs", "de": "Nach Farben vorangehen", "es": "Avanza según los colores", "ru": "Иди по цветам", "ar": "تقدّم حسب الألوان", "pt": "Avance pelas cores", "it": "Avanza secondo i colori" },
  "compass_maze": { "ja": "方角の指示で進め", "ko": "방위 지시로 나아가기", "fr": "Avancez selon la boussole", "de": "Nach Kompassangaben gehen", "es": "Avanza según la brújula", "ru": "Иди по компасу", "ar": "تقدّم حسب البوصلة", "pt": "Avance pela bússola", "it": "Avanza con la bussola" },
  "complex_folding_nets": { "ja": "何度も折りたたんで考えろ", "ko": "여러 번 접어 생각하기", "fr": "Pliez en plusieurs étapes", "de": "Mehrfach falten", "es": "Pliega en varios pasos", "ru": "Складывай в несколько шагов", "ar": "اطوِ على مراحل", "pt": "Dobre em vários passos", "it": "Piega in più passi" },
  "counting_sheep": { "ja": "寝る前に羊を数えろ", "ko": "자기 전 양 세기", "fr": "Comptez les moutons avant de dormir", "de": "Vor dem Schlafen Schafe zählen", "es": "Cuenta ovejas antes de dormir", "ru": "Считай овец перед сном", "ar": "عُدّ الخراف قبل النوم", "pt": "Conte ovelhas antes de dormir", "it": "Conta le pecore prima di dormire" },
  "cross_section_slice": { "ja": "切った断面を想像しろ", "ko": "자른 단면 상상하기", "fr": "Imaginez la coupe", "de": "Stell dir den Schnitt vor", "es": "Imagina el corte", "ru": "Представь сечение", "ar": "تخيّل المقطع", "pt": "Imagine o corte", "it": "Immagina la sezione" },
  "cryptogram_all": { "ja": "難しい置換暗号を解け", "ko": "어려운 치환 암호 풀기", "fr": "Déchiffrez une substitution difficile", "de": "Knacke die schwere Substitution", "es": "Descifra la sustitución difícil", "ru": "Разгадай сложную подстановку", "ar": "فكّ استبدالًا صعبًا", "pt": "Decifre a substituição difícil", "it": "Decifra la sostituzione difficile" },
  "cube_net_fold": { "ja": "展開図を立方体に折れ", "ko": "전개도를 정육면체로 접기", "fr": "Pliez le patron en cube", "de": "Netz zum Würfel falten", "es": "Pliega el desarrollo en cubo", "ru": "Сложи развёртку в куб", "ar": "اطوِ الشبكة إلى مكعب", "pt": "Dobre a planificação em cubo", "it": "Piega lo sviluppo in cubo" },
  "directions_recall": { "ja": "方向の順番を覚えろ", "ko": "방향 순서 기억", "fr": "Retenez la suite de directions", "de": "Merke die Richtungsfolge", "es": "Recuerda la secuencia de direcciones", "ru": "Запомни последовательность направлений", "ar": "احفظ تسلسل الاتجاهات", "pt": "Memorize a sequência de direções", "it": "Ricorda la sequenza di direzioni" },
  "distractor_matrix": { "ja": "邪魔なものを無視しろ", "ko": "방해 요소 무시하기", "fr": "Ignorez les intrus", "de": "Ignoriere die Störer", "es": "Ignora los distractores", "ru": "Игнорируй помехи", "ar": "تجاهل المشتّتات", "pt": "Ignore os intrusos", "it": "Ignora i distrattori" },
  "einstein_riddle": { "ja": "手がかりから答えを導け", "ko": "단서로 답 이끌어내기", "fr": "Déduisez à partir des indices", "de": "Aus Hinweisen ableiten", "es": "Deduce a partir de las pistas", "ru": "Выведи из подсказок", "ar": "استنتج من القرائن", "pt": "Deduza pelas pistas", "it": "Deduci dagli indizi" },
  "fact_binder": { "ja": "事実を正しく結びつけろ", "ko": "사실을 바르게 연결", "fr": "Reliez correctement les faits", "de": "Fakten richtig verbinden", "es": "Relaciona bien los hechos", "ru": "Свяжи факты верно", "ar": "اربط الحقائق صحيحًا", "pt": "Ligue bem os factos", "it": "Collega bene i fatti" },
  "focus_tunnel": { "ja": "一点だけに集中しろ", "ko": "한 점에만 집중", "fr": "Concentrez-vous sur un point", "de": "Nur auf einen Punkt achten", "es": "Concéntrate en un punto", "ru": "Сосредоточься на точке", "ar": "ركّز على نقطة", "pt": "Concentre-se num ponto", "it": "Concentrati su un punto" },
  "gear_rotation": { "ja": "歯車の回る向きを当てろ", "ko": "기어 도는 방향 맞히기", "fr": "Devinez le sens des engrenages", "de": "Drehrichtung der Zahnräder", "es": "Adivina el sentido de giro", "ru": "Угадай направление шестерён", "ar": "خمّن اتجاه التروس", "pt": "Adivinhe o sentido", "it": "Indovina il verso" },
  "gear_train_direction": { "ja": "複数の歯車の伝わり方", "ko": "여러 기어 전달 방향", "fr": "Sens de transmission des engrenages", "de": "Kraftfluss durch Zahnräder", "es": "Sentido de transmisión", "ru": "Передача через шестерни", "ar": "اتجاه النقل بين التروس", "pt": "Sentido de transmissão", "it": "Senso di trasmissione" },
  "geometric_vision": { "ja": "図形を直感的に捉えろ", "ko": "도형을 직관적으로 파악", "fr": "Saisissez la figure d’instinct", "de": "Figuren intuitiv erfassen", "es": "Capta la figura por instinto", "ru": "Схватывай фигуру чутьём", "ar": "أدرك الشكل بحدسك", "pt": "Apreenda a figura por instinto", "it": "Cogli la figura d’istinto" },
  "graph_coordinate_plot": { "ja": "座標どおりに点を打て", "ko": "좌표대로 점 찍기", "fr": "Placez les points aux coordonnées", "de": "Punkte nach Koordinaten setzen", "es": "Marca los puntos según coordenadas", "ru": "Ставь точки по координатам", "ar": "ضع النقاط حسب الإحداثيات", "pt": "Marque os pontos pelas coordenadas", "it": "Segna i punti sulle coordinate" },
  "gravity_sort": { "ja": "傾けてボールを戻せ", "ko": "기울여 공 되돌리기", "fr": "Inclinez pour remettre les billes", "de": "Kippen und Kugeln einsortieren", "es": "Inclina para colocar las bolas", "ru": "Наклони и расставь шары", "ar": "أمِل لتُعيد الكرات", "pt": "Incline para repor as bolas", "it": "Inclina per rimettere le palline" },
  "grid_displacement": { "ja": "移動の指示どおりに動け", "ko": "이동 지시대로 움직이기", "fr": "Déplacez-vous selon les consignes", "de": "Nach Vorgaben verschieben", "es": "Desplázate según las órdenes", "ru": "Двигайся по указаниям", "ar": "تحرّك حسب التعليمات", "pt": "Desloque-se pelas ordens", "it": "Spostati secondo le istruzioni" },
  "hue_sort": { "ja": "色相の順に並べろ", "ko": "색상 순으로 배열", "fr": "Classez par teinte", "de": "Nach Farbton ordnen", "es": "Ordena por tono", "ru": "Расставь по оттенку", "ar": "رتّب حسب الدرجة اللونية", "pt": "Ordene por tonalidade", "it": "Ordina per tonalità" },
  "interlock_puzzle": { "ja": "絡まった仕掛けを外せ", "ko": "얽힌 장치 풀기", "fr": "Désolidarisez les pièces", "de": "Verriegelung lösen", "es": "Desenlaza las piezas", "ru": "Разъедини детали", "ar": "فكّ التشابك", "pt": "Desencaixe as peças", "it": "Sblocca i pezzi" },
  "laser_link": { "ja": "レーザーを的まで反射させろ", "ko": "레이저를 목표까지 반사", "fr": "Réfléchissez le laser vers la cible", "de": "Laser zum Ziel umleiten", "es": "Refleja el láser al blanco", "ru": "Направь лазер в цель", "ar": "اعكس الليزر نحو الهدف", "pt": "Reflita o laser no alvo", "it": "Rifletti il laser sul bersaglio" },
  "laser_reflect": { "ja": "鏡を置いて光を通せ", "ko": "거울 놓아 빛 통과시키기", "fr": "Placez des miroirs pour guider la lumière", "de": "Spiegel setzen und Licht leiten", "es": "Coloca espejos y guía la luz", "ru": "Ставь зеркала и веди свет", "ar": "ضع المرايا ووجّه الضوء", "pt": "Ponha espelhos e guie a luz", "it": "Metti gli specchi e guida la luce" },
  "logical_syllogisms": { "ja": "推論が正しいか判断しろ", "ko": "추론이 옳은지 판단", "fr": "Jugez si le raisonnement tient", "de": "Prüfe, ob der Schluss gilt", "es": "Juzga si el razonamiento vale", "ru": "Оцени верность вывода", "ar": "احكم على صحة الاستنتاج", "pt": "Julgue se o raciocínio vale", "it": "Giudica se il ragionamento regge" },
  "math_guess": { "ja": "二分探索で数を当てろ", "ko": "이분 탐색으로 수 맞히기", "fr": "Trouvez par dichotomie", "de": "Mit Halbierung erraten", "es": "Adivina por bisección", "ru": "Угадай делением пополам", "ar": "خمّن بالتنصيف", "pt": "Adivinhe por bisseção", "it": "Indovina per bisezione" },
  "maze_nav_3d": { "ja": "立体迷路を進め", "ko": "입체 미로 나아가기", "fr": "Avancez dans le labyrinthe 3D", "de": "Im 3D-Labyrinth voran", "es": "Avanza en el laberinto 3D", "ru": "Иди по 3D-лабиринту", "ar": "تقدّم في المتاهة 3D", "pt": "Avance no labirinto 3D", "it": "Avanza nel labirinto 3D" },
  "mental_mapping": { "ja": "頭の中に地図を作れ", "ko": "머릿속에 지도 그리기", "fr": "Construisez la carte mentalement", "de": "Karte im Kopf aufbauen", "es": "Construye el mapa mental", "ru": "Построй карту в уме", "ar": "ابنِ الخريطة ذهنيًا", "pt": "Construa o mapa mental", "it": "Costruisci la mappa mentale" },
  "mental_rotation": { "ja": "回転した形を判断しろ", "ko": "회전한 모양 판단", "fr": "Jugez la forme après rotation", "de": "Drehform beurteilen", "es": "Juzga la forma girada", "ru": "Оцени повёрнутую фигуру", "ar": "احكم على الشكل المُدار", "pt": "Julgue a forma rodada", "it": "Giudica la forma ruotata" },
  "mirror_image": { "ja": "鏡像かどうか見分けろ", "ko": "거울상인지 가려내기", "fr": "Dites s’il s’agit d’un miroir", "de": "Erkenne das Spiegelbild", "es": "Di si es un espejo", "ru": "Определи, зеркало ли это", "ar": "حدّد إن كانت مرآة", "pt": "Diga se é espelho", "it": "Di se è uno specchio" },
  "mirror_maze": { "ja": "鏡の方向で進め", "ko": "거울 방향으로 나아가기", "fr": "Avancez selon le miroir", "de": "Nach Spiegelrichtung gehen", "es": "Avanza según el espejo", "ru": "Иди по зеркалу", "ar": "تقدّم حسب المرآة", "pt": "Avance pelo espelho", "it": "Avanza secondo lo specchio" },
  "mirror_tracing": { "ja": "鏡を見ながらなぞれ", "ko": "거울 보며 따라 그리기", "fr": "Tracez en regardant le miroir", "de": "Am Spiegel nachzeichnen", "es": "Traza mirando el espejo", "ru": "Обводи, глядя в зеркало", "ar": "ارسم بالنظر إلى المرآة", "pt": "Trace olhando no espelho", "it": "Traccia guardando lo specchio" },
  "multi_track_counter": { "ja": "複数を同時に数えろ", "ko": "여러 개 동시에 세기", "fr": "Comptez plusieurs séries à la fois", "de": "Mehrere Reihen zugleich zählen", "es": "Cuenta varias series a la vez", "ru": "Считай несколько рядов сразу", "ar": "عُدّ عدة متسلسلات معًا", "pt": "Conte várias séries ao mesmo tempo", "it": "Conta più serie insieme" },
  "homophone_hunt": { "ja": "同音異義語を探せ", "ko": "동음이의어 찾기", "fr": "Trouvez les homophones", "de": "Finde die Homophone", "es": "Encuentra los homófonos", "ru": "Найди омофоны", "ar": "ابحث عن المتجانسات", "pt": "Ache os homófonos", "it": "Trova gli omofoni" },
  "letter_bridge": { "ja": "文字を補って単語にしろ", "ko": "글자 채워 단어 완성", "fr": "Complétez le mot", "de": "Ergänze das Wort", "es": "Completa la palabra", "ru": "Дополни слово", "ar": "أكمل الكلمة", "pt": "Complete a palavra", "it": "Completa la parola" },
  "letter_cancellation": { "ja": "指定の文字を消せ", "ko": "지정 글자 지우기", "fr": "Barrez les lettres indiquées", "de": "Angegebene Buchstaben streichen", "es": "Tacha las letras indicadas", "ru": "Зачеркни указанные буквы", "ar": "اشطب الحروف المحدّدة", "pt": "Risque as letras indicadas", "it": "Cancella le lettere indicate" },
  "letter_frequency_scan": { "ja": "文字の出現回数を数えろ", "ko": "글자 등장 횟수 세기", "fr": "Comptez les occurrences", "de": "Zähle die Häufigkeiten", "es": "Cuenta las apariciones", "ru": "Посчитай вхождения букв", "ar": "عُدّ تكرار الحروف", "pt": "Conte as ocorrências", "it": "Conta le occorrenze" },
  "letter_grid_swapper": { "ja": "文字を入れ替えて単語を作れ", "ko": "글자 바꿔 단어 만들기", "fr": "Échangez pour former des mots", "de": "Tauschen und Wörter bilden", "es": "Cambia para formar palabras", "ru": "Переставь и составь слова", "ar": "بدّل لتكوين كلمات", "pt": "Troque para formar palavras", "it": "Scambia per formare parole" },
  "missing_vowels": { "ja": "抜けた母音を補え", "ko": "빠진 모음 채우기", "fr": "Complétez les voyelles manquantes", "de": "Fehlende Vokale ergänzen", "es": "Completa las vocales", "ru": "Вставь пропущенные гласные", "ar": "أكمل حروف العلة", "pt": "Complete as vogais", "it": "Completa le vocali" },
  "one_letter_shift": { "ja": "一文字変えて別の単語に", "ko": "한 글자 바꿔 다른 단어로", "fr": "Changez une lettre pour un nouveau mot", "de": "Ein Buchstabe, neues Wort", "es": "Cambia una letra y forma otra", "ru": "Замени букву — новое слово", "ar": "بدّل حرفًا لتصنع كلمة", "pt": "Mude uma letra e forme outra", "it": "Cambia una lettera e forma un’altra" },
  "oxymoron_hunt": { "ja": "矛盾した組み合わせを探せ", "ko": "모순된 조합 찾기", "fr": "Trouvez les oxymores", "de": "Finde die Oxymora", "es": "Encuentra los oxímoron", "ru": "Найди оксюмороны", "ar": "ابحث عن المفارقات", "pt": "Ache os oximoros", "it": "Trova gli ossimori" },
  "palindrome_builder": { "ja": "回文を作れ", "ko": "회문 만들기", "fr": "Créez des palindromes", "de": "Bilde Palindrome", "es": "Crea palíndromos", "ru": "Составь палиндром", "ar": "كوّن جملة معكوسة", "pt": "Crie palíndromos", "it": "Crea palindromi" },
  "pangram_sprint": { "ja": "全部の文字を使い切れ", "ko": "모든 글자 다 쓰기", "fr": "Utilisez toutes les lettres", "de": "Nutze alle Buchstaben", "es": "Usa todas las letras", "ru": "Используй все буквы", "ar": "استخدم كل الحروف", "pt": "Use todas as letras", "it": "Usa tutte le lettere" },
  "portmanteau_split": { "ja": "かばん語を分けろ", "ko": "혼성어 나누기", "fr": "Séparez les mots-valises", "de": "Kofferwörter trennen", "es": "Separa las palabras combinadas", "ru": "Раздели слова-гибриды", "ar": "فكّك الكلمات المدمجة", "pt": "Separe as palavras mistas", "it": "Dividi le parole macedonia" },
  "rhyme_master": { "ja": "韻を踏む語を探せ", "ko": "운율 맞는 단어 찾기", "fr": "Trouvez les rimes", "de": "Finde die Reimwörter", "es": "Encuentra las rimas", "ru": "Найди рифмы", "ar": "ابحث عن القوافي", "pt": "Ache as rimas", "it": "Trova le rime" },
  "semantic_association": { "ja": "意味の近い語を合わせろ", "ko": "의미가 가까운 단어 짝", "fr": "Associez les mots proches", "de": "Ähnliche Wörter paaren", "es": "Empareja palabras afines", "ru": "Сопоставь близкие слова", "ar": "طابق الكلمات المتقاربة", "pt": "Emparelhe palavras próximas", "it": "Abbina parole affini" },
  "semantic_distance": { "ja": "意味の遠近を判断しろ", "ko": "의미의 원근 판단", "fr": "Jugez la proximité du sens", "de": "Beurteile die Bedeutungsnähe", "es": "Juzga la cercanía de sentido", "ru": "Оцени близость смысла", "ar": "احكم على تقارب المعنى", "pt": "Julgue a proximidade de sentido", "it": "Giudica la vicinanza di senso" },
  "semantic_link": { "ja": "意味の鎖をつなげ", "ko": "의미 사슬 잇기", "fr": "Formez une chaîne de sens", "de": "Bilde eine Bedeutungskette", "es": "Forma una cadena de sentido", "ru": "Составь смысловую цепь", "ar": "صِل سلسلة المعنى", "pt": "Forme uma cadeia de sentido", "it": "Forma una catena di senso" },
  "sentence_unscramble": { "ja": "ばらばらの文を元に戻せ", "ko": "흩어진 문장 되돌리기", "fr": "Remettez la phrase en ordre", "de": "Bring den Satz in Ordnung", "es": "Ordena la frase", "ru": "Собери предложение", "ar": "رتّب الجملة", "pt": "Ordene a frase", "it": "Riordina la frase" },
  "silent_letter_search": { "ja": "発音しない文字を探せ", "ko": "묵음 글자 찾기", "fr": "Trouvez les lettres muettes", "de": "Finde die stummen Buchstaben", "es": "Encuentra las letras mudas", "ru": "Найди немые буквы", "ar": "ابحث عن الحروف الصامتة", "pt": "Ache as letras mudas", "it": "Trova le lettere mute" },
  "spelling_sprint": { "ja": "制限時間で綴れ", "ko": "제한 시간 안에 철자", "fr": "Épelez contre la montre", "de": "Rechtschreibung auf Zeit", "es": "Deletrea contra el reloj", "ru": "Пиши на время", "ar": "اهجِ قبل الوقت", "pt": "Soletre contra o tempo", "it": "Compita contro il tempo" },
  "spoonerism_solver": { "ja": "頭の音を入れ替えろ", "ko": "머리소리 바꾸기", "fr": "Intervertissez les initiales", "de": "Anlaute vertauschen", "es": "Intercambia las iniciales", "ru": "Поменяй начальные звуки", "ar": "بدّل الأصوات الأولى", "pt": "Troque as iniciais", "it": "Scambia le iniziali" },
  "story_builder": { "ja": "物語を組み立てろ", "ko": "이야기 짜맞추기", "fr": "Reconstituez l’histoire", "de": "Setze die Geschichte zusammen", "es": "Recompón el relato", "ru": "Собери рассказ", "ar": "ركّب القصة", "pt": "Recomponha a história", "it": "Ricostruisci la storia" },
  "syllable_stack": { "ja": "音節で単語を作れ", "ko": "음절로 단어 만들기", "fr": "Formez des mots par syllabes", "de": "Wörter aus Silben bilden", "es": "Forma palabras por sílabas", "ru": "Составь слова из слогов", "ar": "كوّن كلمات بالمقاطع", "pt": "Forme palavras por sílabas", "it": "Forma parole con le sillabe" },
  "typing_speed": { "ja": "タイピングの速さを測れ", "ko": "타자 속도 측정", "fr": "Mesurez votre vitesse de frappe", "de": "Miss die Tippgeschwindigkeit", "es": "Mide tu velocidad al teclear", "ru": "Измерь скорость печати", "ar": "قِس سرعة الكتابة", "pt": "Meça a sua velocidade", "it": "Misura la velocità" },
  "typoglycemia_decoder": { "ja": "最初と最後が合っていれば読める", "ko": "처음과 끝이 맞으면 읽힌다", "fr": "Début et fin suffisent à lire", "de": "Anfang und Ende genügen", "es": "Con principio y fin basta", "ru": "Начала и конца достаточно", "ar": "تكفي البداية والنهاية", "pt": "Basta o início e o fim", "it": "Basta inizio e fine" },
  "verbal_analogies": { "ja": "A 対 B は C 対 何？", "ko": "A 대 B는 C 대 ?", "fr": "A est à B ce que C est à ?", "de": "A zu B wie C zu ?", "es": "A es a B como C es a ?", "ru": "A к B, как C к ?", "ar": "A إلى B مثل C إلى ?", "pt": "A está para B como C para ?", "it": "A sta a B come C sta a ?" },
  "vocabulary_builder": { "ja": "語彙を増やせ", "ko": "어휘 늘리기", "fr": "Enrichissez votre vocabulaire", "de": "Erweitere den Wortschatz", "es": "Amplía tu vocabulario", "ru": "Пополняй словарный запас", "ar": "عزّز مفرداتك", "pt": "Amplie o vocabulário", "it": "Arricchisci il vocabolario" },
  "vowel_reconstruct": { "ja": "母音を元に戻せ", "ko": "모음 복원", "fr": "Reconstituez les voyelles", "de": "Vokale wiederherstellen", "es": "Reconstruye las vocales", "ru": "Восстанови гласные", "ar": "استعد حروف العلة", "pt": "Reconstrua as vogais", "it": "Ricostruisci le vocali" },
  "word_association_recall": { "ja": "連想した語を思い出せ", "ko": "연상 단어 기억", "fr": "Rappelez les mots associés", "de": "Assoziierte Wörter erinnern", "es": "Recuerda las palabras asociadas", "ru": "Вспомни связанные слова", "ar": "تذكّر الكلمات المرتبطة", "pt": "Recorde as palavras associadas", "it": "Ricorda le parole associate" },
  "word_grid_connection": { "ja": "関連する語をつなげ", "ko": "관련 단어 연결", "fr": "Reliez les mots liés", "de": "Verwandte Wörter verbinden", "es": "Une las palabras relacionadas", "ru": "Соедини связанные слова", "ar": "صِل الكلمات المترابطة", "pt": "Ligue as palavras relacionadas", "it": "Collega le parole legate" },
  "word_ladder": { "ja": "一文字ずつ変えてたどり着け", "ko": "한 글자씩 바꿔 도달", "fr": "Changez une lettre à chaque pas", "de": "Je einen Buchstaben ändern", "es": "Cambia una letra por paso", "ru": "Меняй по одной букве", "ar": "بدّل حرفًا في كل خطوة", "pt": "Mude uma letra por passo", "it": "Cambia una lettera per volta" },
  "word_ladder_step": { "ja": "一歩だけ文字を変えろ", "ko": "한 걸음만 글자 바꾸기", "fr": "Changez une seule lettre", "de": "Nur einen Buchstaben ändern", "es": "Cambia solo una letra", "ru": "Измени одну букву", "ar": "بدّل حرفًا واحدًا", "pt": "Mude só uma letra", "it": "Cambia solo una lettera" },
  "word_mastermind": { "ja": "隠れた単語を当てろ", "ko": "숨은 단어 맞추기", "fr": "Devinez le mot caché", "de": "Errate das versteckte Wort", "es": "Adivina la palabra oculta", "ru": "Угадай скрытое слово", "ar": "خمّن الكلمة المخفية", "pt": "Adivinhe a palavra oculta", "it": "Indovina la parola nascosta" },
  "word_scramble": { "ja": "ばらばらの文字を並べ直せ", "ko": "흩어진 글자 재배열", "fr": "Remettez les lettres en ordre", "de": "Buchstaben neu ordnen", "es": "Ordena las letras", "ru": "Расставь буквы", "ar": "رتّب الحروف", "pt": "Ordene as letras", "it": "Riordina le lettere" },
  "word_search": { "ja": "文字の陣から単語を探せ", "ko": "글자 판에서 단어 찾기", "fr": "Trouvez les mots cachés", "de": "Finde die Wörter im Gitter", "es": "Encuentra las palabras", "ru": "Найди слова в сетке", "ar": "ابحث عن الكلمات في الشبكة", "pt": "Ache as palavras", "it": "Trova le parole" },
  "word_snake_trail": { "ja": "蛇の道で単語を探せ", "ko": "뱀 길로 단어 찾기", "fr": "Trouvez les mots en serpentant", "de": "Wörter in Schlangenlinie", "es": "Encuentra palabras serpenteando", "ru": "Найди слова змейкой", "ar": "ابحث عن الكلمات بمسار ثعبان", "pt": "Ache palavras em cobra", "it": "Trova parole a serpentina" },
  "word_surge": { "ja": "制限時間で単語を作れ", "ko": "제한 시간 안에 단어 만들기", "fr": "Formez des mots à temps", "de": "Wörter auf Zeit bilden", "es": "Forma palabras a tiempo", "ru": "Составляй слова на время", "ar": "كوّن كلمات قبل الوقت", "pt": "Forme palavras a tempo", "it": "Forma parole in tempo" },
  "word_wheel": { "ja": "文字を組み合わせて単語を作れ", "ko": "글자 조합해 단어 만들기", "fr": "Formez des mots avec les lettres", "de": "Wörter aus Buchstaben bilden", "es": "Forma palabras con las letras", "ru": "Составь слова из букв", "ar": "كوّن كلمات من الحروف", "pt": "Forme palavras com as letras", "it": "Forma parole con le lettere" },
  "ab_reversal_oddball": { "ja": "異質な刺激を見抜け", "ko": "이질적 자극 가려내기", "fr": "Repérez le stimulus aberrant", "de": "Erkenne den abweichenden Reiz", "es": "Detecta el estímulo anómalo", "ru": "Найди аномальный стимул", "ar": "اكتشف المنبّه الشاذ", "pt": "Detete o estímulo anómalo", "it": "Individua lo stimolo anomalo" },
  "action_sequence_recall": { "ja": "動作の順番を覚えろ", "ko": "동작 순서 기억", "fr": "Retenez l’ordre des gestes", "de": "Merke die Reihenfolge der Gesten", "es": "Recuerda el orden de los gestos", "ru": "Запомни порядок движений", "ar": "احفظ ترتيب الحركات", "pt": "Memorize a ordem dos gestos", "it": "Ricorda l’ordine dei gesti" },
  "angle_finder": { "ja": "図形の角度を求めろ", "ko": "도형 각도 구하기", "fr": "Trouvez l’angle de la figure", "de": "Berechne den Winkel", "es": "Calcula el ángulo", "ru": "Найди угол фигуры", "ar": "احسب زاوية الشكل", "pt": "Calcule o ângulo", "it": "Calcola l’angolo" },
  "area_perimeter_match": { "ja": "面積と周長を合わせろ", "ko": "넓이와 둘레 짝맞추기", "fr": "Associez aire et périmètre", "de": "Fläche und Umfang paaren", "es": "Empareja área y perímetro", "ru": "Сопоставь площадь и периметр", "ar": "طابق المساحة والمحيط", "pt": "Emparelhe área e perímetro", "it": "Abbina area e perimetro" },
  "running_memory_span": { "ja": "順番どおりに思い出せ", "ko": "순서대로 기억해내기", "fr": "Rappelez dans l’ordre", "de": "In der Reihenfolge erinnern", "es": "Recuerda en orden", "ru": "Вспомни по порядку", "ar": "تذكّر بالترتيب", "pt": "Recorde por ordem", "it": "Ricorda in ordine" },
  "sdmt": { "ja": "制限時間で記号を数字に置き換えろ", "ko": "제한 시간 안에 기호를 숫자로", "fr": "Remplacez les symboles à temps", "de": "Symbole rechtzeitig ersetzen", "es": "Sustituye símbolos a tiempo", "ru": "Заменяй символы на время", "ar": "استبدل الرموز قبل الوقت", "pt": "Substitua símbolos a tempo", "it": "Sostituisci i simboli in tempo" },
  "shell_game": { "ja": "カップの下の球を追え", "ko": "컵 아래 공 추적", "fr": "Suivez la balle sous les gobelets", "de": "Verfolge die Kugel unter den Bechern", "es": "Sigue la bola bajo los vasos", "ru": "Следи за шариком под чашками", "ar": "تابع الكرة تحت الأكواب", "pt": "Siga a bola sob os copos", "it": "Segui la pallina sotto i bicchieri" },
  "sopt": { "ja": "自分で決めた順に指させ", "ko": "스스로 정한 순서로 가리키기", "fr": "Montrez dans votre propre ordre", "de": "In selbstgewählter Reihenfolge zeigen", "es": "Señala en tu propio orden", "ru": "Показывай в своём порядке", "ar": "أشِر بترتيبك الخاص", "pt": "Aponte na sua própria ordem", "it": "Indica nel tuo ordine" },
  "spatial_cabinet_memory": { "ja": "物の場所を覚えろ", "ko": "물건 위치 기억", "fr": "Retenez où sont les objets", "de": "Merke die Positionen der Dinge", "es": "Recuerda dónde están los objetos", "ru": "Запомни, где лежат предметы", "ar": "تذكّر مواضع الأشياء", "pt": "Memorize onde estão os objetos", "it": "Ricorda dove sono gli oggetti" },
  "spotlight_track": { "ja": "光の spot を追え", "ko": "빛을 따라가기", "fr": "Suivez le projecteur", "de": "Folge dem Scheinwerfer", "es": "Sigue el foco", "ru": "Следи за лучом", "ar": "تابع الضوء", "pt": "Siga o foco", "it": "Segui il faro" },
  "staircase_memory": { "ja": "階段の順を覚えろ", "ko": "계단 순서 기억", "fr": "Retenez l’ordre des marches", "de": "Treppenfolge merken", "es": "Recuerda el orden de los escalones", "ru": "Запомни порядок ступеней", "ar": "تذكّر ترتيب الدرجات", "pt": "Memorize a ordem dos degraus", "it": "Ricorda l’ordine dei gradini" },
  "stop_signal": { "ja": "反応をぐっとこらえろ", "ko": "반응을 꾹 참기", "fr": "Retenez votre réponse", "de": "Reaktion unterdrücken", "es": "Contén tu respuesta", "ru": "Сдерживай реакцию", "ar": "اكبح استجابتك", "pt": "Contenha a resposta", "it": "Trattieni la risposta" },
  "stroop_number_size": { "ja": "数字の大きさは無視しろ", "ko": "숫자 크기는 무시", "fr": "Ignorez la taille des chiffres", "de": "Ignoriere die Zifferngröße", "es": "Ignora el tamaño del número", "ru": "Игнорируй размер числа", "ar": "تجاهل حجم الرقم", "pt": "Ignore o tamanho do número", "it": "Ignora la dimensione del numero" },
  "stroop_test": { "ja": "文字の意味と色がぶつかる", "ko": "글자 뜻과 색이 충돌", "fr": "Le sens et la couleur se contredisent", "de": "Wort und Farbe im Konflikt", "es": "Sentido y color en conflicto", "ru": "Смысл и цвет спорят", "ar": "المعنى واللون متعارضان", "pt": "Sentido e cor em conflito", "it": "Significato e colore in conflitto" },
  "subitizing_rush": { "ja": "一瞬で数を捉えろ", "ko": "순식간에 개수 파악", "fr": "Saisissez la quantité d’un coup d’œil", "de": "Anzahl auf einen Blick erfassen", "es": "Capta la cantidad de un vistazo", "ru": "Схватывай количество мгновенно", "ar": "أدرك العدد بنظرة", "pt": "Apreenda a quantidade num relance", "it": "Cogli la quantità a colpo d’occhio" },
  "switch_task": { "ja": "ルールを切り替えろ", "ko": "규칙 전환", "fr": "Changez de règle", "de": "Wechsle die Regel", "es": "Cambia de regla", "ru": "Меняй правило", "ar": "بدّل القاعدة", "pt": "Mude de regra", "it": "Cambia regola" },
  "symbol_digit_assoc": { "ja": "記号に数字を対応させろ", "ko": "기호에 숫자 대응", "fr": "Associez symboles et chiffres", "de": "Symbole und Ziffern zuordnen", "es": "Asocia símbolos y dígitos", "ru": "Сопоставь символы и цифры", "ar": "طابق الرموز والأرقام", "pt": "Associe símbolos e dígitos", "it": "Associa simboli e cifre" },
  "symbol_logic": { "ja": "記号で推論しろ", "ko": "기호로 추론", "fr": "Raisonnez avec des symboles", "de": "Mit Symbolen schließen", "es": "Razona con símbolos", "ru": "Рассуждай символами", "ar": "استنتج بالرموز", "pt": "Racine com símbolos", "it": "Ragiona con i simboli" },
  "symbolic_flanker": { "ja": "記号版の妨害を無視しろ", "ko": "기호판 방해 무시", "fr": "Ignorez les distracteurs symboliques", "de": "Symbolische Störreize ignorieren", "es": "Ignora distractores simbólicos", "ru": "Игнорируй символьные помехи", "ar": "تجاهل المشتّتات الرمزية", "pt": "Ignore distratores simbólicos", "it": "Ignora i distrattori simbolici" },
  "task_switching": { "ja": "切り替えの負担を測る", "ko": "전환 부담 측정", "fr": "Mesurez le coût du changement", "de": "Miss den Wechselaufwand", "es": "Mide el coste del cambio", "ru": "Измерь цену переключения", "ar": "قِس كلفة التبديل", "pt": "Meça o custo da troca", "it": "Misura il costo del cambio" },
  "trail_making": { "ja": "順番に線でつなげ", "ko": "순서대로 선 잇기", "fr": "Reliez dans l’ordre", "de": "In der Reihenfolge verbinden", "es": "Une en orden", "ru": "Соединяй по порядку", "ar": "صِل بالترتيب", "pt": "Ligue por ordem", "it": "Collega in ordine" },
  "vigilance_task": { "ja": "長いあいだ集中を保て", "ko": "오래 집중 유지", "fr": "Restez vigilant longtemps", "de": "Lange aufmerksam bleiben", "es": "Mantén la atención mucho tiempo", "ru": "Долго сохраняй бдительность", "ar": "حافظ على اليقظة طويلًا", "pt": "Mantenha-se atento muito tempo", "it": "Resta vigile a lungo" },
  "visual_crowding_acuity": { "ja": "混み合った図形を見分けろ", "ko": "빽빽한 도형 구별", "fr": "Distinguez des formes serrées", "de": "Dichte Formen unterscheiden", "es": "Distingue formas apiñadas", "ru": "Различай тесные фигуры", "ar": "ميّز الأشكال المتزاحمة", "pt": "Distinga formas apertadas", "it": "Distingui forme strette" },
  "visual_search": { "ja": "目標を見つけ出せ", "ko": "목표 찾아내기", "fr": "Trouvez la cible", "de": "Finde das Ziel", "es": "Encuentra el objetivo", "ru": "Найди цель", "ar": "اعثر على الهدف", "pt": "Encontre o alvo", "it": "Trova il bersaglio" },
  "visual_search_conjunction": { "ja": "複数の特徴で探せ", "ko": "여러 특징으로 찾기", "fr": "Cherchez par plusieurs traits", "de": "Nach mehreren Merkmalen suchen", "es": "Busca por varios rasgos", "ru": "Ищи по нескольким признакам", "ar": "ابحث بعدة سمات", "pt": "Procure por vários traços", "it": "Cerca per più tratti" },
  "wisconsin_card_sorting": { "ja": "カードを分類しろ", "ko": "카드 분류하기", "fr": "Classez les cartes", "de": "Karten sortieren", "es": "Clasifica las cartas", "ru": "Разложи карты", "ar": "صنّف البطاقات", "pt": "Classifique as cartas", "it": "Classifica le carte" },
  "word_pair_associate_memory": { "ja": "単語のペアを覚えろ", "ko": "단어 짝 기억", "fr": "Retenez les paires de mots", "de": "Wortpaare merken", "es": "Memoriza los pares de palabras", "ru": "Запомни пары слов", "ar": "احفظ أزواج الكلمات", "pt": "Memorize os pares de palavras", "it": "Memorizza le coppie di parole" },
  "affix_factory": { "ja": "接辞をつけて単語を作れ", "ko": "접사 붙여 단어 만들기", "fr": "Créez des mots avec des affixes", "de": "Wörter mit Affixen bilden", "es": "Crea palabras con afijos", "ru": "Образуй слова с аффиксами", "ar": "كوّن كلمات باللواحق", "pt": "Crie palavras com afixos", "it": "Crea parole con affissi" },
  "anagram_definition": { "ja": "定義を手がかりに並べ替えろ", "ko": "정의를 단서로 재배열", "fr": "Remettez en ordre grâce à la définition", "de": "Aus der Definition erschließen", "es": "Ordena con la definición", "ru": "Собери слово по определению", "ar": "رتّب بالاستعانة بالتعريف", "pt": "Ordene com a definição", "it": "Riordina con la definizione" },
  "category_fluency": { "ja": "制限時間で同じ仲間を挙げろ", "ko": "제한 시간 안에 같은 무리 나열", "fr": "Citez le plus de mots d’une catégorie", "de": "Auf Zeit Wörter einer Kategorie", "es": "Di palabras de una categoría a tiempo", "ru": "Называй слова категории на время", "ar": "اذكر كلمات الفئة قبل الوقت", "pt": "Diga palavras da categoria a tempo", "it": "Elenca parole della categoria in tempo" },
  "chalk_and_talk": { "ja": "同時に二つのことをしろ", "ko": "두 가지를 동시에", "fr": "Faites deux choses à la fois", "de": "Zwei Dinge gleichzeitig", "es": "Haz dos cosas a la vez", "ru": "Делай два дела сразу", "ar": "افعل شيئين معًا", "pt": "Faça duas coisas ao mesmo tempo", "it": "Fai due cose insieme" },
  "chimp_test": { "ja": "一瞬で数字の位置を覚えろ", "ko": "순식간에 숫자 위치 기억", "fr": "Retenez les positions en un éclair", "de": "Positionen blitzschnell merken", "es": "Retén las posiciones al instante", "ru": "Мгновенно запомни позиции", "ar": "احفظ المواضع في لمحة", "pt": "Memorize as posições num instante", "it": "Ricorda le posizioni in un lampo" },
  "cognate_catch": { "ja": "同源語を見分けろ", "ko": "동원어 가려내기", "fr": "Repérez les mots apparentés", "de": "Verwandte Wörter erkennen", "es": "Detecta las palabras afines", "ru": "Узнавай родственные слова", "ar": "تعرّف على الكلمات المتشابهة", "pt": "Detete palavras cognatas", "it": "Riconosci le parole imparentate" },
  "consonant_reconstruct": { "ja": "子音を元に戻せ", "ko": "자음 복원", "fr": "Reconstituez les consonnes", "de": "Konsonanten wiederherstellen", "es": "Reconstruye las consonantes", "ru": "Восстанови согласные", "ar": "استعد الحروف الساكنة", "pt": "Reconstrua as consoantes", "it": "Ricostruisci le consonanti" },
  "context_clues": { "ja": "文脈から意味を推し量れ", "ko": "문맥으로 뜻 짐작", "fr": "Devinez le sens d’après le contexte", "de": "Bedeutung aus dem Kontext", "es": "Adivina el sentido por el contexto", "ru": "Угадай смысл по контексту", "ar": "خمّن المعنى من السياق", "pt": "Adivinhe pelo contexto", "it": "Indovina dal contesto" },
  "conundrum_anagram": { "ja": "なぞなぞを解け", "ko": "수수께끼 풀기", "fr": "Résolvez la devinette", "de": "Löse das Rätsel", "es": "Resuelve el acertijo", "ru": "Разгадай загадку", "ar": "حلّ الأحجية", "pt": "Resolva a charada", "it": "Risolvi l’indovinello" },
  "crossword": { "ja": "横竖のマスに語を入れろ", "ko": "가로세로 칸에 단어 넣기", "fr": "Remplissez la grille", "de": "Fülle das Gitter", "es": "Rellena la cuadrícula", "ru": "Заполни сетку словами", "ar": "املأ الشبكة بالكلمات", "pt": "Preencha a grelha", "it": "Riempi lo schema" },
  "cryptogram": { "ja": "置換暗号を解け", "ko": "치환 암호 풀기", "fr": "Déchiffrez la substitution", "de": "Löse die Substitution", "es": "Descifra la sustitución", "ru": "Разгадай подстановку", "ar": "فكّ شيفرة الاستبدال", "pt": "Decifre a substituição", "it": "Decifra la sostituzione" },
  "definition_dash": { "ja": "制限時間で意味を選べ", "ko": "제한 시간 안에 뜻 고르기", "fr": "Choisissez le sens à temps", "de": "Bedeutung rechtzeitig wählen", "es": "Elige el significado a tiempo", "ru": "Выбери значение вовремя", "ar": "اختر المعنى قبل الوقت", "pt": "Escolha o sentido a tempo", "it": "Scegli il significato in tempo" },
  "etymology_origin": { "ja": "語源を見極めろ", "ko": "어원 가려내기", "fr": "Déterminez l’origine du mot", "de": "Bestimme die Wortherkunft", "es": "Determina el origen", "ru": "Определи происхождение", "ar": "حدّد أصل الكلمة", "pt": "Determine a origem", "it": "Determina l’origine" },
  "etymon_oddball": { "ja": "違う語根を探せ", "ko": "다른 어근 찾기", "fr": "Trouvez la racine intruse", "de": "Finde die andere Wurzel", "es": "Encuentra la raíz distinta", "ru": "Найди другой корень", "ar": "ابحث عن الجذر المختلف", "pt": "Ache a raiz diferente", "it": "Trova la radice diversa" },
  "find_word": { "ja": "すばやく単語を見つけろ", "ko": "빠르게 단어 찾기", "fr": "Trouvez le mot vite", "de": "Finde das Wort schnell", "es": "Encuentra la palabra rápido", "ru": "Быстро найди слово", "ar": "اعثر على الكلمة بسرعة", "pt": "Ache a palavra depressa", "it": "Trova la parola in fretta" },
  "grammar_police": { "ja": "文法の間違いを探せ", "ko": "문법 오류 찾기", "fr": "Traquez les fautes de grammaire", "de": "Finde die Grammatikfehler", "es": "Caza los errores gramaticales", "ru": "Найди грамматические ошибки", "ar": "ابحث عن أخطاء القواعد", "pt": "Cace os erros gramaticais", "it": "Trova gli errori di grammatica" },
  "grammar_sort": { "ja": "品詞ごとに分けろ", "ko": "품사별로 나누기", "fr": "Classez par nature de mot", "de": "Nach Wortart sortieren", "es": "Clasifica por categoría", "ru": "Разложи по частям речи", "ar": "صنّف حسب نوع الكلمة", "pt": "Classifique por classe", "it": "Classifica per categoria" },
  "counting_span": { "ja": "数えてから個数を思い出せ", "ko": "세고 나서 개수 기억", "fr": "Comptez puis rappelez la quantité", "de": "Zählen und Anzahl merken", "es": "Cuenta y recuerda la cantidad", "ru": "Посчитай и запомни количество", "ar": "عُدّ ثم تذكّر العدد", "pt": "Conte e recorde a quantidade", "it": "Conta e ricorda la quantità" },
  "d2_attention": { "ja": "素早く印を探して消せ", "ko": "빠르게 표시 찾아 지우기", "fr": "Repérez et barrez vite", "de": "Schnell markieren und streichen", "es": "Marca y tacha rápido", "ru": "Быстро находи и зачёркивай", "ar": "علّم واشطب بسرعة", "pt": "Marque e risque depressa", "it": "Segna e barra in fretta" },
  "delayed_match_sample": { "ja": "少し待ってから見たものを当てろ", "ko": "잠시 뒤 본 것 맞추기", "fr": "Reconnaissez après un délai", "de": "Nach kurzer Pause wiedererkennen", "es": "Reconoce tras una pausa", "ru": "Узнай после паузы", "ar": "تعرّف بعد مهلة", "pt": "Reconheça após uma pausa", "it": "Riconosci dopo una pausa" },
  "digit_span_reverse": { "ja": "数字を逆の順で思い出せ", "ko": "숫자를 거꾸로 기억", "fr": "Rappelez les chiffres à l’envers", "de": "Ziffern rückwärts merken", "es": "Recuerda los dígitos al revés", "ru": "Вспомни цифры в обратном порядке", "ar": "تذكّر الأرقام بالعكس", "pt": "Recorde os dígitos ao contrário", "it": "Ricorda le cifre al contrario" },
  "divided_attention": { "ja": "二つの課題を同時にこなせ", "ko": "두 과제 동시에 해내기", "fr": "Menez deux tâches de front", "de": "Zwei Aufgaben gleichzeitig", "es": "Atiende dos tareas a la vez", "ru": "Делай две задачи сразу", "ar": "أنجز مهمتين معًا", "pt": "Faça duas tarefas ao mesmo tempo", "it": "Svolgi due compiti insieme" },
  "dnms": { "ja": "見ていない方を選べ", "ko": "못 본 쪽 고르기", "fr": "Choisissez ce que vous n’avez pas vu", "de": "Wähle das Ungesehene", "es": "Elige lo que no viste", "ru": "Выбери то, чего не видел", "ar": "اختر ما لم تره", "pt": "Escolha o que não viu", "it": "Scegli ciò che non hai visto" },
  "double_n_back": { "ja": "二つの流れを N 手前で照合", "ko": "두 흐름을 N단계 전과 대조", "fr": "Comparez deux flux à N pas", "de": "Zwei Reihen N Schritte zurück", "es": "Compara dos series N pasos atrás", "ru": "Сверяй два потока на N шагов назад", "ar": "قارن مسارين قبل N خطوة", "pt": "Compare dois fluxos N passos atrás", "it": "Confronta due flussi N passi indietro" },
  "dual_coding": { "ja": "言葉と絵の両方で覚えろ", "ko": "말과 그림 둘 다로 기억", "fr": "Retenez par le mot et l’image", "de": "Mit Wort und Bild merken", "es": "Retén con palabra e imagen", "ru": "Запоминай словом и образом", "ar": "احفظ بالكلمة والصورة", "pt": "Memorize com palavra e imagem", "it": "Memorizza con parola e immagine" },
  "dual_task_memory": { "ja": "計算しながら覚えろ", "ko": "계산하면서 기억하기", "fr": "Calculez tout en mémorisant", "de": "Rechnen und dabei merken", "es": "Calcula mientras memorizas", "ru": "Считай и запоминай одновременно", "ar": "احسب واحفظ في الوقت نفسه", "pt": "Calcule enquanto memoriza", "it": "Calcola mentre memorizzi" },
  "dynamic_salience": { "ja": "一番目立つものを探せ", "ko": "가장 눈에 띄는 것 찾기", "fr": "Trouvez le plus saillant", "de": "Finde das Auffälligste", "es": "Encuentra lo más llamativo", "ru": "Найди самое заметное", "ar": "ابحث عن الأبرز", "pt": "Ache o mais saliente", "it": "Trova il più saliente" },
  "event_timeline_memory": { "ja": "出来事を正しい順に並べろ", "ko": "사건을 올바른 순서로", "fr": "Remettez les événements dans l’ordre", "de": "Ereignisse richtig ordnen", "es": "Ordena los acontecimientos", "ru": "Расставь события по порядку", "ar": "رتّب الأحداث", "pt": "Ordene os acontecimentos", "it": "Ordina gli eventi" },
  "face_name_association": { "ja": "顔と名前を結びつけろ", "ko": "얼굴과 이름 연결", "fr": "Associez visages et noms", "de": "Gesichter und Namen verbinden", "es": "Asocia caras y nombres", "ru": "Свяжи лица и имена", "ar": "اربط الوجوه بالأسماء", "pt": "Associe rostos e nomes", "it": "Associa volti e nomi" },
  "face_trait_association": { "ja": "顔の特徴を覚えろ", "ko": "얼굴 특징 기억", "fr": "Retenez les traits du visage", "de": "Gesichtsmerkmale merken", "es": "Recuerda los rasgos", "ru": "Запомни черты лица", "ar": "تذكّر ملامح الوجه", "pt": "Memorize os traços", "it": "Ricorda i tratti del volto" },
  "feature_matrix_recall": { "ja": "特徴を思い出せ", "ko": "특징 기억해내기", "fr": "Rappelez les caractéristiques", "de": "Merkmale erinnern", "es": "Recuerda las características", "ru": "Вспомни признаки", "ar": "تذكّر السمات", "pt": "Recorde as características", "it": "Ricorda le caratteristiche" },
  "feature_matrix_recall_all": { "ja": "特徴の並びを思い出せ", "ko": "특징 배열 기억해내기", "fr": "Rappelez la grille de traits", "de": "Merkmalmatrix erinnern", "es": "Recuerda la matriz de rasgos", "ru": "Вспомни матрицу признаков", "ar": "تذكّر مصفوفة السمات", "pt": "Recorde a matriz de traços", "it": "Ricorda la matrice di tratti" },
  "flanker_test": { "ja": "まわりの妨害を無視しろ", "ko": "주변 방해 무시하기", "fr": "Ignorez les distracteurs", "de": "Störreize ignorieren", "es": "Ignora los distractores", "ru": "Игнорируй помехи", "ar": "تجاهل المشتّتات", "pt": "Ignore os distratores", "it": "Ignora i distrattori" },
  "frequency_tap": { "ja": "リズムに合わせて叩け", "ko": "리듬에 맞춰 누르기", "fr": "Tapez en rythme", "de": "Im Rhythmus tippen", "es": "Toca al ritmo", "ru": "Стучи в ритм", "ar": "انقر على الإيقاع", "pt": "Toque no ritmo", "it": "Batti a ritmo" },
  "ghost_tap": { "ja": "現れた的を叩け", "ko": "나타난 목표 누르기", "fr": "Touchez la cible apparue", "de": "Erschienenes Ziel antippen", "es": "Toca el objetivo que aparece", "ru": "Нажми на появившуюся цель", "ar": "انقر الهدف الظاهر", "pt": "Toque no alvo que surge", "it": "Tocca il bersaglio che appare" },
  "go_no_go": { "ja": "合図のときだけ反応しろ", "ko": "신호일 때만 반응", "fr": "Réagissez seulement au bon signal", "de": "Nur beim richtigen Signal reagieren", "es": "Reacciona solo a la señal", "ru": "Реагируй только на сигнал", "ar": "استجب للإشارة فقط", "pt": "Reaja só ao sinal", "it": "Reagisci solo al segnale" },
  "grocery_list": { "ja": "買い物リストを覚えろ", "ko": "장보기 목록 기억", "fr": "Retenez la liste de courses", "de": "Einkaufsliste merken", "es": "Memoriza la lista", "ru": "Запомни список покупок", "ar": "احفظ قائمة التسوّق", "pt": "Memorize a lista", "it": "Memorizza la lista" },
  "mandala_recall": { "ja": "描かれた模様を思い出せ", "ko": "그려진 무늬 기억", "fr": "Rappelez le motif dessiné", "de": "Gemustertes erinnern", "es": "Recuerda el dibujo", "ru": "Вспомни узор", "ar": "تذكّر النقش", "pt": "Recorde o padrão", "it": "Ricorda il disegno" },
  "memory_matrix": { "ja": "光ったマスを覚えろ", "ko": "빛난 칸 기억", "fr": "Retenez les cases allumées", "de": "Erleuchtete Felder merken", "es": "Recuerda las casillas iluminadas", "ru": "Запомни зажжённые клетки", "ar": "تذكّر الخانات المضيئة", "pt": "Memorize as casas acesas", "it": "Ricorda le caselle accese" },
  "memory_palace": { "ja": "場所に結びつけて覚えろ", "ko": "장소에 연결해 기억", "fr": "Associez aux lieux pour retenir", "de": "Mit Orten verknüpft merken", "es": "Asocia lugares para recordar", "ru": "Запоминай через места", "ar": "احفظ بربط الأماكن", "pt": "Memorize associando lugares", "it": "Memorizza con i luoghi" },
  "multiple_object_tracking": { "ja": "複数の的を目で追え", "ko": "여러 목표를 눈으로 쫓기", "fr": "Suivez plusieurs cibles", "de": "Mehrere Ziele verfolgen", "es": "Sigue varios objetivos", "ru": "Следи за несколькими целями", "ar": "تابع عدة أهداف", "pt": "Siga vários alvos", "it": "Segui più bersagli" },
  "n_back": { "ja": "N 手前と同じ刺激を見分けろ", "ko": "N단계 전과 같은 자극 가려내기", "fr": "Repérez le stimulus d’il y a N pas", "de": "Reiz von vor N Schritten erkennen", "es": "Detecta el estímulo de hace N pasos", "ru": "Узнай стимул N шагов назад", "ar": "تعرّف على المنبّه قبل N خطوة", "pt": "Detete o estímulo de N passos atrás", "it": "Riconosci lo stimolo di N passi fa" },
  "narrative_recall": { "ja": "物語を自分の言葉で話せ", "ko": "이야기를 자기 말로 말하기", "fr": "Racontez l’histoire avec vos mots", "de": "Erzähle die Geschichte nach", "es": "Cuenta la historia con tus palabras", "ru": "Перескажи историю своими словами", "ar": "أعد سرد القصة بكلماتك", "pt": "Reconte a história por palavras suas", "it": "Racconta la storia con parole tue" },
  "negative_space_detection": { "ja": "空白の形を見抜け", "ko": "빈 공간 모양 알아보기", "fr": "Repérez la forme du vide", "de": "Erkenne die Leerform", "es": "Descubre la forma del vacío", "ru": "Разгляди форму пустоты", "ar": "اكتشف شكل الفراغ", "pt": "Descubra a forma do vazio", "it": "Scopri la forma del vuoto" },
  "object_displacement": { "ja": "動いた物を見つけろ", "ko": "움직인 물체 찾기", "fr": "Repérez l’objet déplacé", "de": "Erkenne das Verscho­bene", "es": "Detecta el objeto movido", "ru": "Найди перемещённый предмет", "ar": "اكتشف الجسم المتحرّك", "pt": "Detete o objeto movido", "it": "Trova l’oggetto spostato" },
  "object_shuffle": { "ja": "入れ替わりを追え", "ko": "바뀐 위치 추적", "fr": "Suivez les échanges", "de": "Vertauschungen verfolgen", "es": "Sigue los intercambios", "ru": "Следи за перестановками", "ar": "تابع التبديلات", "pt": "Siga as trocas", "it": "Segui gli scambi" },
  "odd_even_flash": { "ja": "一瞬で奇数か偶数か見分けろ", "ko": "순식간에 홀짝 가리기", "fr": "Dites pair ou impair en un éclair", "de": "Blitzschnell gerade oder ungerade", "es": "Di par o impar al vuelo", "ru": "Мгновенно чёт или нечет", "ar": "حدّد الزوجي والفردي بلمح البصر", "pt": "Diga par ou ímpar num instante", "it": "Di' pari o dispari in un lampo" },
  "operation_span": { "ja": "計算して結果を覚えろ", "ko": "계산하고 결과 기억", "fr": "Calculez puis retenez le résultat", "de": "Rechnen und Ergebnis merken", "es": "Calcula y retén el resultado", "ru": "Реши и запомни результат", "ar": "احسب ثم احفظ النتيجة", "pt": "Calcule e retenha o resultado", "it": "Calcola e ricorda il risultato" },
  "peripheral_focus": { "ja": "余光で見分けろ", "ko": "주변 시야로 알아보기", "fr": "Reconnaissez du coin de l’œil", "de": "Aus dem Augenwinkel erkennen", "es": "Reconoce con el rabillo del ojo", "ru": "Узнавай боковым зрением", "ar": "تعرّف بطرف العين", "pt": "Reconheça pelo canto do olho", "it": "Riconosci con la coda dell’occhio" },
  "posner_spatial_cueing": { "ja": "合図の場所に素早く反応", "ko": "신호 위치에 빠르게 반응", "fr": "Réagissez vite au bon endroit", "de": "Schnell am Hinweisort reagieren", "es": "Reacciona rápido donde indica", "ru": "Быстро реагируй на подсказку", "ar": "استجب سريعًا عند الإشارة", "pt": "Reaja depressa onde indica", "it": "Reagisci in fretta dove indica" },
  "probe_digit_span": { "ja": "指定された位置の数字を思い出せ", "ko": "지정된 위치의 숫자 기억", "fr": "Rappelez le chiffre à la position dite", "de": "Ziffer an der genannten Stelle", "es": "Recuerda el dígito en esa posición", "ru": "Вспомни цифру на месте", "ar": "تذكّر الرقم في الموضع", "pt": "Recorde o dígito na posição", "it": "Ricorda la cifra nella posizione" },
  "reading_span": { "ja": "読んでから内容を思い出せ", "ko": "읽고 나서 내용 기억", "fr": "Lisez puis rappelez", "de": "Lesen und danach erinnern", "es": "Lee y luego recuerda", "ru": "Прочитай и вспомни", "ar": "اقرأ ثم تذكّر", "pt": "Leia e depois recorde", "it": "Leggi e poi ricorda" },
  "reflex_tap": { "ja": "できるだけ速く叩け", "ko": "최대한 빠르게 누르기", "fr": "Tapez le plus vite possible", "de": "So schnell wie möglich tippen", "es": "Toca lo más rápido posible", "ru": "Нажимай как можно быстрее", "ar": "انقر بأسرع ما يمكن", "pt": "Toque o mais rápido possível", "it": "Tocca il più veloce possibile" },
  "relational_memory": { "ja": "ペアの関係を覚えろ", "ko": "짝 관계 기억", "fr": "Retenez les paires liées", "de": "Verbundene Paare merken", "es": "Retén las parejas relacionadas", "ru": "Запомни связанные пары", "ar": "احفظ الأزواج المرتبطة", "pt": "Memorize os pares ligados", "it": "Ricorda le coppie legate" },
  "reverse_stroop": { "ja": "逆のルールで答えろ", "ko": "거꾸로 규칙으로 답하기", "fr": "Répondez à l’envers", "de": "Antworte nach umgekehrter Regel", "es": "Responde al revés", "ru": "Отвечай наоборот", "ar": "أجب بالعكس", "pt": "Responda ao contrário", "it": "Rispondi al contrario" },
  "rhythm_master": { "ja": "リズムに乗れ", "ko": "리듬 타기", "fr": "Suivez le rythme", "de": "Bleib im Rhythmus", "es": "Sigue el ritmo", "ru": "Держи ритм", "ar": "التزم بالإيقاع", "pt": "Siga o ritmo", "it": "Segui il ritmo" },
  "rule_switcher": { "ja": "ルールを素早く切り替えろ", "ko": "규칙 빠르게 전환", "fr": "Changez de règle rapidement", "de": "Regel schnell wechseln", "es": "Cambia de regla rápido", "ru": "Быстро меняй правило", "ar": "بدّل القاعدة بسرعة", "pt": "Mude de regra depressa", "it": "Cambia regola in fretta" },
  "mental_calendar": { "ja": "頭の中で日付と曜日を割り出せ", "ko": "머릿속으로 날짜와 요일 계산", "fr": "Trouvez la date de tête", "de": "Datum im Kopf berechnen", "es": "Calcula la fecha mentalmente", "ru": "Вычисли дату в уме", "ar": "احسب التاريخ ذهنيًا", "pt": "Calcule a data de cabeça", "it": "Calcola la data a mente" },
  "missing_operator": { "ja": "正しい演算子を入れろ", "ko": "올바른 연산자 넣기", "fr": "Insérez le bon opérateur", "de": "Setze den richtigen Operator", "es": "Pon el operador correcto", "ru": "Вставь верный знак", "ar": "ضع العملية الصحيحة", "pt": "Insira o operador certo", "it": "Inserisci l’operatore giusto" },
  "modular_clock_arithmetic": { "ja": "時計の文字盤で合同算術", "ko": "시계판으로 모듈러 연산", "fr": "Arithmétique modulaire sur cadran", "de": "Modulare Arithmetik am Zifferblatt", "es": "Aritmética modular en el reloj", "ru": "Модульная арифметика на циферблате", "ar": "حساب معياري على الساعة", "pt": "Aritmética modular no mostrador", "it": "Aritmetica modulare sul quadrante" },
  "modulo_clock": { "ja": "時計を読んで mod 12 で計算", "ko": "시계 읽고 mod 12 계산", "fr": "Lisez l’heure, calculez modulo 12", "de": "Uhr lesen, modulo 12 rechnen", "es": "Lee el reloj, calcula módulo 12", "ru": "Читай часы, считай по модулю 12", "ar": "اقرأ الساعة واحسب بمعيار 12", "pt": "Leia o relógio e calcule módulo 12", "it": "Leggi l’orologio e calcola modulo 12" },
  "modulo_path": { "ja": "余りに従ってマスを進め", "ko": "나머지대로 칸 이동", "fr": "Avancez selon le reste", "de": "Nach dem Rest weitergehen", "es": "Avanza según el resto", "ru": "Иди по остатку", "ar": "تقدّم حسب الباقي", "pt": "Avance pelo resto", "it": "Avanza secondo il resto" },
  "number_bonds": { "ja": "数を二つに分けろ", "ko": "수를 둘로 나누기", "fr": "Décomposez le nombre en deux", "de": "Zahl in zwei Teile zerlegen", "es": "Descompón el número en dos", "ru": "Разложи число на два", "ar": "فكّك العدد إلى اثنين", "pt": "Decomponha em dois", "it": "Scomponi in due" },
  "number_bonds_all": { "ja": "数の分解を練習", "ko": "수 분해 연습", "fr": "Entraînez la décomposition", "de": "Zerlegung üben", "es": "Practica la descomposición", "ru": "Тренируй разложение", "ar": "تدرّب على التفكيك", "pt": "Pratique a decomposição", "it": "Esercita la scomposizione" },
  "numerical_estimation": { "ja": "結果をおおよそ見積もれ", "ko": "결과를 어림잡기", "fr": "Estimez le résultat", "de": "Ergebnis überschlagen", "es": "Estima el resultado", "ru": "Оцени результат", "ar": "قدّر النتيجة", "pt": "Estime o resultado", "it": "Stima il risultato" },
  "pattern_sequence_draw": { "ja": "規則どおりに模様を描け", "ko": "규칙대로 무늬 그리기", "fr": "Dessinez selon la règle", "de": "Nach der Regel zeichnen", "es": "Dibuja según la regla", "ru": "Нарисуй по правилу", "ar": "ارسم وفق القاعدة", "pt": "Desenhe segundo a regra", "it": "Disegna secondo la regola" },
  "percentage_peak": { "ja": "制限時間で百分率", "ko": "제한 시간 안에 백분율", "fr": "Pourcentages contre la montre", "de": "Prozente auf Zeit", "es": "Porcentajes contra el reloj", "ru": "Проценты на время", "ar": "نسب مئوية قبل الوقت", "pt": "Percentagens contra o tempo", "it": "Percentuali contro il tempo" },
  "percentage_shopping": { "ja": "割引後の値段を計算", "ko": "할인가 계산하기", "fr": "Calculez le prix remisé", "de": "Berechne den Rabattpreis", "es": "Calcula el precio rebajado", "ru": "Посчитай цену со скидкой", "ar": "احسب السعر المخفّض", "pt": "Calcule o preço com desconto", "it": "Calcola il prezzo scontato" },
  "prime_factor_trees": { "ja": "素因数に分解しろ", "ko": "소인수로 분해하기", "fr": "Décomposez en facteurs premiers", "de": "In Primfaktoren zerlegen", "es": "Descompón en factores primos", "ru": "Разложи на простые множители", "ar": "حلّل إلى عوامل أولية", "pt": "Decomponha em fatores primos", "it": "Scomponi in fattori primi" },
  "prime_gap_hunt": { "ja": "隣り合う素数の差を探せ", "ko": "이웃 소수의 차 찾기", "fr": "Trouvez l’écart entre premiers", "de": "Lücke zwischen Primzahlen finden", "es": "Halla la brecha entre primos", "ru": "Найди разрыв между простыми", "ar": "ابحث عن الفرق بين الأولية", "pt": "Ache a diferença entre primos", "it": "Trova il divario tra primi" },
  "prime_hunter": { "ja": "素数を全部見つけろ", "ko": "소수 전부 찾기", "fr": "Trouvez tous les nombres premiers", "de": "Finde alle Primzahlen", "es": "Halla todos los primos", "ru": "Найди все простые числа", "ar": "ابحث عن كل الأعداد الأولية", "pt": "Ache todos os primos", "it": "Trova tutti i primi" },
  "pythagorean_triple_builder": { "ja": "ピタゴラス数を組み立てろ", "ko": "피타고라스 수 만들기", "fr": "Construisez des triplets", "de": "Pythagoräische Tripel bilden", "es": "Construye ternas pitagóricas", "ru": "Составь пифагоровы тройки", "ar": "كوّن ثلاثيات فيثاغورس", "pt": "Construa ternos pitagóricos", "it": "Costruisci terne pitagoriche" },
  "quick_math": { "ja": "制限時間で暗算", "ko": "제한 시간 암산", "fr": "Calcul mental contre la montre", "de": "Kopfrechnen auf Zeit", "es": "Cálculo mental contra el reloj", "ru": "Устный счёт на время", "ar": "حساب ذهني قبل الوقت", "pt": "Cálculo mental contra o tempo", "it": "Calcolo mentale contro il tempo" },
  "radical_roots": { "ja": "根号を簡約せよ", "ko": "근호 간단히 하기", "fr": "Simplifiez les radicaux", "de": "Wurzeln vereinfachen", "es": "Simplifica los radicales", "ru": "Упрости корни", "ar": "بسّط الجذور", "pt": "Simplifique os radicais", "it": "Semplifica i radicali" },
  "roman_arithmetic": { "ja": "ローマ数字で計算せよ", "ko": "로마 숫자로 계산", "fr": "Calculez en chiffres romains", "de": "Mit römischen Zahlen rechnen", "es": "Calcula en números romanos", "ru": "Считай римскими цифрами", "ar": "احسب بالأرقام الرومانية", "pt": "Calcule em números romanos", "it": "Calcola con i numeri romani" },
  "sequence_sleuth": { "ja": "数列の規則を見抜け", "ko": "수열 규칙 찾아내기", "fr": "Percez la règle de la suite", "de": "Erkenne die Zahlenfolge", "es": "Descifra la regla de la serie", "ru": "Разгадай правило ряда", "ar": "اكتشف قاعدة المتتالية", "pt": "Desvende a regra da sequência", "it": "Scopri la regola della serie" },
  "sequence_stack": { "ja": "数列を積み上げろ", "ko": "수열 쌓기", "fr": "Empilez les suites", "de": "Folgen stapeln", "es": "Apila las series", "ru": "Складывай последовательности", "ar": "كدّس المتتاليات", "pt": "Empilhe as sequências", "it": "Impila le sequenze" },
  "set_theory_venn": { "ja": "集合の演算", "ko": "집합 연산", "fr": "Opérations sur les ensembles", "de": "Mengenoperationen", "es": "Operaciones de conjuntos", "ru": "Операции над множествами", "ar": "عمليات المجموعات", "pt": "Operações de conjuntos", "it": "Operazioni sugli insiemi" },
  "sum_pyramid": { "ja": "下の段の和が上になるように", "ko": "아래 층 합이 위가 되게", "fr": "La somme du bas donne le haut", "de": "Summe unten ergibt oben", "es": "La suma de abajo da arriba", "ru": "Сумма снизу даёт верх", "ar": "مجموع الأسفل يعطي الأعلى", "pt": "A soma de baixo dá o topo", "it": "La somma in basso dà la cima" },
  "target_10": { "ja": "数字を選んで 10 を作れ", "ko": "숫자 골라 10 만들기", "fr": "Choisissez des nombres pour faire 10", "de": "Zahlen wählen und 10 bilden", "es": "Elige números para hacer 10", "ru": "Выбери числа и собери 10", "ar": "اختر أرقامًا لتصنع 10", "pt": "Escolha números e faça 10", "it": "Scegli i numeri e fai 10" },
  "target_number": { "ja": "四則演算で目標の数を作れ", "ko": "사칙연산으로 목표 수 만들기", "fr": "Atteignez le nombre cible", "de": "Zielzahl mit vier Rechenarten", "es": "Alcanza el número objetivo", "ru": "Достигни целевого числа", "ar": "ابلغ العدد الهدف", "pt": "Atinga o número alvo", "it": "Raggiungi il numero bersaglio" },
  "unit_converter_pro": { "ja": "いろいろな単位を換算", "ko": "여러 단위 변환", "fr": "Convertissez toutes sortes d’unités", "de": "Verschiedene Einheiten umrechnen", "es": "Convierte distintas unidades", "ru": "Переводи разные единицы", "ar": "حوّل وحدات متنوعة", "pt": "Converta várias unidades", "it": "Converti varie unità" },
  "vector_dot_product": { "ja": "内積を計算せよ", "ko": "내적 계산하기", "fr": "Calculez le produit scalaire", "de": "Berechne das Skalarprodukt", "es": "Calcula el producto escalar", "ru": "Вычисли скалярное произведение", "ar": "احسب الضرب القياسي", "pt": "Calcule o produto escalar", "it": "Calcola il prodotto scalare" },
  "vector_grid_alignment": { "ja": "ベクトルを格子に合わせろ", "ko": "벡터를 격자에 맞추기", "fr": "Alignez les vecteurs", "de": "Vektoren ausrichten", "es": "Alinea los vectores", "ru": "Выровняй векторы", "ar": "حاذِ المتجهات", "pt": "Alinhe os vetores", "it": "Allinea i vettori" },
  "vektor_vector": { "ja": "ベクトルの足し算・引き算", "ko": "벡터 덧셈·뺄셈", "fr": "Addition et soustraction de vecteurs", "de": "Vektoren addieren und subtrahieren", "es": "Suma y resta de vectores", "ru": "Сложение и вычитание векторов", "ar": "جمع وطرح المتجهات", "pt": "Soma e subtração de vetores", "it": "Somma e sottrazione di vettori" },
  "venn_numbers": { "ja": "ベン図に数を入れろ", "ko": "벤 다이어그램에 수 넣기", "fr": "Remplissez le diagramme de Venn", "de": "Zahlen ins Venn-Diagramm", "es": "Rellena el diagrama de Venn", "ru": "Заполни диаграмму Венна", "ar": "املأ مخطط فن", "pt": "Preencha o diagrama de Venn", "it": "Riempi il diagramma di Venn" },
  "associative_pairs": { "ja": "記憶のペア合わせ", "ko": "기억 짝 맞추기", "fr": "Paires à mémoriser", "de": "Paare merken", "es": "Parejas para memorizar", "ru": "Запомни пары", "ar": "أزواج للحفظ", "pt": "Pares para memorizar", "it": "Coppie da memorizzare" },
  "attentional_blink": { "ja": "二つ目の目標を捉えろ", "ko": "두 번째 목표 잡기", "fr": "Attrapez la seconde cible", "de": "Erfasse das zweite Ziel", "es": "Atrapa el segundo objetivo", "ru": "Поймай вторую цель", "ar": "أمسك الهدف الثاني", "pt": "Apanhe o segundo alvo", "it": "Cattura il secondo bersaglio" },
  "attentional_blink_probe": { "ja": "二つ目の目標を捉えろ", "ko": "두 번째 목표 잡기", "fr": "Attrapez la seconde cible", "de": "Erfasse das zweite Ziel", "es": "Atrapa el segundo objetivo", "ru": "Поймай вторую цель", "ar": "أمسك الهدف الثاني", "pt": "Apanhe o segundo alvo", "it": "Cattura il secondo bersaglio" },
  "card_counting_memory": { "ja": "出た札を覚えておけ", "ko": "나온 카드 기억하기", "fr": "Retenez les cartes sorties", "de": "Gemerkte Karten behalten", "es": "Recuerda las cartas salidas", "ru": "Запоминай вышедшие карты", "ar": "تذكّر البطاقات الظاهرة", "pt": "Memorize as cartas saídas", "it": "Ricorda le carte uscite" },
  "change_blindness": { "ja": "何か変わった？", "ko": "뭐가 바뀌었나?", "fr": "Quelque chose a changé ?", "de": "Hat sich etwas geändert?", "es": "¿Cambió algo?", "ru": "Что-то изменилось?", "ar": "هل تغيّر شيء؟", "pt": "Algo mudou?", "it": "Qualcosa è cambiato?" },
  "choice_reaction_time": { "ja": "合図が出たらすぐ選べ", "ko": "신호가 나오면 바로 선택", "fr": "Choisissez dès le signal", "de": "Beim Signal sofort wählen", "es": "Elige al instante", "ru": "Выбирай по сигналу", "ar": "اختر فور الإشارة", "pt": "Escolha ao sinal", "it": "Scegli al segnale" },
  "color_word_match_up": { "ja": "記憶力を試す短い検査", "ko": "기억력을 시험하는 짧은 검사", "fr": "Un petit test de mémoire", "de": "Ein kurzer Gedächtnistest", "es": "Una breve prueba de memoria", "ru": "Короткий тест памяти", "ar": "اختبار ذاكرة قصير", "pt": "Um breve teste de memória", "it": "Un breve test di memoria" },
  "conjunction_search": { "ja": "すばやく仲間はずれを探せ", "ko": "빠르게 다른 것 찾기", "fr": "Repérez l’intrus rapidement", "de": "Schnell den Ausreißer finden", "es": "Encuentra al intruso rápido", "ru": "Быстро найди лишнее", "ar": "اعثر على المختلف بسرعة", "pt": "Ache o intruso depressa", "it": "Trova l’intruso in fretta" },
  "continuous_recognition": { "ja": "記憶力を試す短い検査", "ko": "기억력을 시험하는 짧은 검사", "fr": "Un petit test de mémoire", "de": "Ein kurzer Gedächtnistest", "es": "Una breve prueba de memoria", "ru": "Короткий тест памяти", "ar": "اختبار ذاكرة قصير", "pt": "Um breve teste de memória", "it": "Un breve test di memoria" },
  "corsi_backward_span": { "ja": "ブロックの順番を逆にたどれ", "ko": "블록 순서를 거꾸로 따라가기", "fr": "Reproduisez la suite à l’envers", "de": "Reihenfolge rückwärts nachtippen", "es": "Repite la secuencia al revés", "ru": "Повтори последовательность в обратном порядке", "ar": "أعد التسلسل بالعكس", "pt": "Repita a sequência ao contrário", "it": "Ripeti la sequenza al contrario" },
  "corsi_blocks": { "ja": "ブロックの順番を覚えろ", "ko": "블록 순서 기억하기", "fr": "Mémorisez la suite de blocs", "de": "Blockfolge merken", "es": "Memoriza la secuencia de bloques", "ru": "Запомни последовательность блоков", "ar": "احفظ تسلسل المكعبات", "pt": "Memorize a sequência de blocos", "it": "Memorizza la sequenza di blocchi" },
  "slide_puzzle": { "ja": "スライドして揃えろ", "ko": "슬라이드해서 맞추기", "fr": "Faites glisser pour ranger", "de": "Schieben bis alles passt", "es": "Desliza hasta ordenar", "ru": "Двигай до порядка", "ar": "حرّك حتى الترتيب", "pt": "Deslize até ordenar", "it": "Fai scorrere fino all’ordine" },
  "slitherlink": { "ja": "数字どおりに回路を描け", "ko": "숫자대로 회로 그리기", "fr": "Tracez la boucle selon les chiffres", "de": "Schleife nach den Zahlen", "es": "Traza el bucle según los números", "ru": "Начерти петлю по числам", "ar": "ارسم الحلقة حسب الأرقام", "pt": "Trace o laço pelos números", "it": "Traccia l’anello secondo i numeri" },
  "sudoku": { "ja": "各行・列・ブロックに重複なし", "ko": "행·열·블록 중복 없이", "fr": "Sans répétition ligne, colonne, bloc", "de": "Ohne Doppelte in Zeile, Spalte, Block", "es": "Sin repetir en fila, columna y bloque", "ru": "Без повторов в строке, столбце, блоке", "ar": "بلا تكرار في الصف والعمود والمربع", "pt": "Sem repetir em linha, coluna e bloco", "it": "Senza ripetere in riga, colonna e blocco" },
  "sum_snake": { "ja": "蛇の道で合計を出せ", "ko": "뱀 길로 합 구하기", "fr": "Additionnez le long du serpent", "de": "Entlang der Schlange addieren", "es": "Suma a lo largo de la serpiente", "ru": "Считай вдоль змейки", "ar": "اجمع على طول الثعبان", "pt": "Some ao longo da cobra", "it": "Somma lungo il serpente" },
  "tangle_fix": { "ja": "もつれをほどけ", "ko": "엉킨 선 풀기", "fr": "Démêlez les lignes", "de": "Linien entwirren", "es": "Desenreda las líneas", "ru": "Распутай линии", "ar": "فكّ تشابك الخطوط", "pt": "Desembarace as linhas", "it": "Districa le linee" },
  "tapa": { "ja": "数字どおりに連続した黒マスを描け", "ko": "숫자대로 연속 검은 칸 그리기", "fr": "Noircissez par blocs continus", "de": "Zusammenhängende Blöcke schwärzen", "es": "Ennegrece en bloques seguidos", "ru": "Черни непрерывными блоками", "ar": "سوّد بكتل متّصلة", "pt": "Ennegreça em blocos contínuos", "it": "Annerisci in blocchi continui" },
  "tenner_grid": { "ja": "各行・列に 0〜9 を一つずつ", "ko": "행·열에 0~9 하나씩", "fr": "Un chiffre de 0 à 9 par ligne", "de": "Je 0–9 einmal pro Zeile", "es": "Un 0–9 por fila y columna", "ru": "По одной цифре 0–9", "ar": "رقم 0–9 لكل صف", "pt": "Um 0–9 por linha e coluna", "it": "Uno 0–9 per riga e colonna" },
  "tents_and_trees": { "ja": "木ごとにテントを一つ", "ko": "나무마다 텐트 하나", "fr": "Une tente par arbre", "de": "Ein Zelt pro Baum", "es": "Una tienda por árbol", "ru": "Одна палатка на дерево", "ar": "خيمة لكل شجرة", "pt": "Uma tenda por árvore", "it": "Una tenda per albero" },
  "water_sort": { "ja": "同じ色に揃うまで注げ", "ko": "같은 색으로 모을 때까지 붓기", "fr": "Versez jusqu’à regrouper les couleurs", "de": "Gießen bis Farben sortiert sind", "es": "Vierte hasta agrupar colores", "ru": "Лей, пока цвета не сойдутся", "ar": "اسكب حتى تتجمّع الألوان", "pt": "Deite até agrupar as cores", "it": "Versa fino a raggruppare i colori" },
  "yajilin": { "ja": "矢印のヒントで黒マスを置き回路を作れ", "ko": "화살표 힌트로 검은 칸 놓고 회로 만들기", "fr": "Placez du noir selon les flèches", "de": "Schwarz nach Pfeilen setzen", "es": "Pon negro según las flechas", "ru": "Ставь чёрное по стрелкам", "ar": "ضع الأسود حسب الأسهم", "pt": "Ponha preto pelas setas", "it": "Metti il nero secondo le frecce" },
  "algebraic_balance": { "ja": "方程式を釣り合わせろ", "ko": "방정식 균형 맞추기", "fr": "Équilibrez l’équation", "de": "Gleichung ausbalancieren", "es": "Equilibra la ecuación", "ru": "Уравновесь уравнение", "ar": "وازن المعادلة", "pt": "Equilibre a equação", "it": "Equilibra l’equazione" },
  "algebraic_inequality_solver": { "ja": "不等式を解け", "ko": "부등식 풀기", "fr": "Résolvez l’inégalité", "de": "Löse die Ungleichung", "es": "Resuelve la inecuación", "ru": "Реши неравенство", "ar": "حلّ المتباينة", "pt": "Resolva a inequação", "it": "Risolvi la disuguaglianza" },
  "arithmetic_chain": { "ja": "計算をつないで目標に届け", "ko": "계산 이어 목표 도달", "fr": "Enchaînez les calculs jusqu’au but", "de": "Rechenkette bis zum Ziel", "es": "Encadena hasta el objetivo", "ru": "Дойди до цели цепочкой", "ar": "صِل الحساب للهدف", "pt": "Encadeie até a meta", "it": "Concatena fino al bersaglio" },
  "balance_scale": { "ja": "目標の重さを量り出せ", "ko": "목표 무게 재기", "fr": "Pesez le poids cible", "de": "Zielgewicht abwiegen", "es": "Pesa el peso objetivo", "ru": "Отвесь нужный вес", "ar": "زِن الوزن الهدف", "pt": "Pese o peso alvo", "it": "Pesa il peso bersaglio" },
  "base_conversion_run": { "ja": "制限時間で基数を換算", "ko": "제한 시간 안에 진법 변환", "fr": "Convertissez contre la montre", "de": "Basisumrechnung auf Zeit", "es": "Convierte contra el reloj", "ru": "Переводи на время", "ar": "حوّل قبل انتهاء الوقت", "pt": "Converta contra o tempo", "it": "Converti contro il tempo" },
  "base_shift": { "ja": "基数を切り替えろ", "ko": "진법 전환", "fr": "Changez de base", "de": "Basis wechseln", "es": "Cambia de base", "ru": "Меняй основание", "ar": "بدّل الأساس", "pt": "Mude de base", "it": "Cambia base" },
  "binary_code": { "ja": "二進を符号化・復号せよ", "ko": "이진 부호화·복호화", "fr": "Encodez et décodez", "de": "Kodieren und dekodieren", "es": "Codifica y descodifica", "ru": "Кодируй и декодируй", "ar": "رمّز وفكّ الترميز", "pt": "Codifique e descodifique", "it": "Codifica e decodifica" },
  "binary_matrix_rank": { "ja": "二進行列の階数を求めよ", "ko": "이진 행렬 계수 구하기", "fr": "Trouvez le rang de la matrice", "de": "Bestimme den Matrixrang", "es": "Halla el rango", "ru": "Найди ранг матрицы", "ar": "أوجد رتبة المصفوفة", "pt": "Ache o posto da matriz", "it": "Trova il rango" },
  "binary_scale_balance": { "ja": "二進法で重さを量れ", "ko": "이진법으로 무게 재기", "fr": "Pesez en binaire", "de": "Binär abwiegen", "es": "Pesa en binario", "ru": "Взвешивай в двоичной", "ar": "زِن بالنظام الثنائي", "pt": "Pese em binário", "it": "Pesa in binario" },
  "binomial_match": { "ja": "展開式を合わせろ", "ko": "전개식 짝맞추기", "fr": "Associez les développements", "de": "Entwicklungen zuordnen", "es": "Empareja los desarrollos", "ru": "Сопоставь разложения", "ar": "طابق المفكوكات", "pt": "Emparelhe os desenvolvimentos", "it": "Abbina gli sviluppi" },
  "calculation_sprint": { "ja": "制限時間で連続計算", "ko": "제한 시간 연속 계산", "fr": "Calculs en série contre la montre", "de": "Rechenserie auf Zeit", "es": "Cálculo en serie contra el reloj", "ru": "Серия вычислений на время", "ar": "حساب متتابع قبل الوقت", "pt": "Cálculo em série contra o tempo", "it": "Calcolo a raffica contro il tempo" },
  "collatz": { "ja": "3n+1 で 1 まで", "ko": "3n+1로 1까지", "fr": "De 3n+1 jusqu’à 1", "de": "Von 3n+1 bis zur 1", "es": "De 3n+1 hasta 1", "ru": "От 3n+1 до единицы", "ar": "من 3n+1 إلى 1", "pt": "De 3n+1 até 1", "it": "Da 3n+1 fino a 1" },
  "common_denominator": { "ja": "共通の分母を探せ", "ko": "공통 분모 찾기", "fr": "Trouvez le dénominateur commun", "de": "Finde den Hauptnenner", "es": "Halla el común denominador", "ru": "Найди общий знаменатель", "ar": "ابحث عن المقام المشترك", "pt": "Ache o denominador comum", "it": "Trova il denominatore comune" },
  "countdown_math": { "ja": "制限時間で数を作れ", "ko": "제한 시간 안에 수 만들기", "fr": "Fabriquez le nombre à temps", "de": "Zahl rechtzeitig bilden", "es": "Forma el número a tiempo", "ru": "Собери число вовремя", "ar": "كوّن العدد في الوقت", "pt": "Forme o número a tempo", "it": "Componi il numero in tempo" },
  "crypto_arithmetic": { "ja": "文字が数字を表す式を解け", "ko": "문자가 숫자인 식 풀기", "fr": "Les lettres valent des chiffres", "de": "Buchstaben stehen für Ziffern", "es": "Las letras son cifras", "ru": "Буквы вместо цифр", "ar": "الحروف أرقام", "pt": "As letras são dígitos", "it": "Le lettere sono cifre" },
  "digit_swap_eq": { "ja": "数字を入れ替えて式を成立させろ", "ko": "숫자 바꿔 식 성립시키기", "fr": "Échangez pour que l’égalité tienne", "de": "Tauschen bis die Gleichung stimmt", "es": "Cambia hasta que cuadre", "ru": "Переставь, чтобы сошлось", "ar": "بدّل حتى تصحّ المعادلة", "pt": "Troque até a igualdade valer", "it": "Scambia finché torna" },
  "divisibility_dash": { "ja": "制限時間で整除を判定", "ko": "제한 시간 안에 배수 판정", "fr": "Divisibilité contre la montre", "de": "Teilbarkeit auf Zeit", "es": "Divisibilidad contra el reloj", "ru": "Делимость на время", "ar": "قابلية القسمة قبل الوقت", "pt": "Divisibilidade contra o tempo", "it": "Divisibilità contro il tempo" },
  "exponent_tower": { "ja": "べき乗の塔を計算せよ", "ko": "거듭제곱 탑 계산", "fr": "Calculez la tour d’exposants", "de": "Berechne den Exponententurm", "es": "Calcula la torre de exponentes", "ru": "Вычисли башню степеней", "ar": "احسب برج الأسس", "pt": "Calcule a torre de expoentes", "it": "Calcola la torre di esponenti" },
  "factor_finder": { "ja": "約数を全部挙げろ", "ko": "약수 전부 나열", "fr": "Listez tous les diviseurs", "de": "Alle Teiler auflisten", "es": "Enumera todos los divisores", "ru": "Перечисли все делители", "ar": "اذكر كل القواسم", "pt": "Liste todos os divisores", "it": "Elenca tutti i divisori" },
  "fibonacci_merge": { "ja": "フィボナッチ数を合体させろ", "ko": "피보나치 수 합치기", "fr": "Fusionnez les nombres de Fibonacci", "de": "Fibonacci-Zahlen verschmelzen", "es": "Fusiona los números de Fibonacci", "ru": "Сливай числа Фибоначчи", "ar": "ادمج أعداد فيبوناتشي", "pt": "Funda os números de Fibonacci", "it": "Fondi i numeri di Fibonacci" },
  "fraction_match": { "ja": "等しい分数を合わせろ", "ko": "같은 분수 짝맞추기", "fr": "Associez les fractions égales", "de": "Gleiche Brüche paaren", "es": "Empareja fracciones iguales", "ru": "Сопоставь равные дроби", "ar": "طابق الكسور المتساوية", "pt": "Emparelhe frações iguais", "it": "Abbina le frazioni uguali" },
  "fraction_matcher": { "ja": "等しい分数を探せ", "ko": "같은 분수 찾기", "fr": "Trouvez les fractions égales", "de": "Finde gleiche Brüche", "es": "Halla fracciones iguales", "ru": "Найди равные дроби", "ar": "ابحث عن الكسور المتساوية", "pt": "Ache frações iguais", "it": "Trova le frazioni uguali" },
  "fractional_pizza": { "ja": "分数どおりにピザを切れ", "ko": "분수대로 피자 자르기", "fr": "Coupez la pizza en fractions", "de": "Pizza in Bruchteile schneiden", "es": "Corta la pizza en fracciones", "ru": "Разрежь пиццу по дробям", "ar": "قطّع البيتزا حسب الكسور", "pt": "Corte a pizza em frações", "it": "Taglia la pizza in frazioni" },
  "inequality_balance_ops": { "ja": "不等号で釣り合いを取れ", "ko": "부등호로 균형 잡기", "fr": "Équilibrez avec des inégalités", "de": "Mit Ungleichungen ausgleichen", "es": "Equilibra con desigualdades", "ru": "Уравновесь неравенствами", "ar": "وازن بالمتباينات", "pt": "Equilibre com inequações", "it": "Equilibra con disuguaglianze" },
  "inequality_dash": { "ja": "制限時間で不等式を解け", "ko": "제한 시간 안에 부등식 풀기", "fr": "Inégalités contre la montre", "de": "Ungleichungen auf Zeit", "es": "Inecuaciones contra el reloj", "ru": "Неравенства на время", "ar": "متباينات قبل الوقت", "pt": "Inequações contra o tempo", "it": "Disuguaglianze contro il tempo" },
  "magic_squares": { "ja": "行・列・対角の和を揃えろ", "ko": "행·열·대각선 합 맞추기", "fr": "Même somme partout", "de": "Überall gleiche Summe", "es": "Misma suma en todo", "ru": "Одинаковая сумма везде", "ar": "المجموع نفسه في كل اتجاه", "pt": "Mesma soma em todo lado", "it": "Stessa somma ovunque" },
  "matrix_multiplier": { "ja": "行列の積を計算せよ", "ko": "행렬 곱 계산", "fr": "Calculez le produit matriciel", "de": "Berechne das Matrixprodukt", "es": "Calcula el producto", "ru": "Вычисли произведение матриц", "ar": "احسب ضرب المصفوفات", "pt": "Calcule o produto", "it": "Calcola il prodotto" },
  "matrix_multiplier_match": { "ja": "積の結果を合わせろ", "ko": "곱 결과 짝맞추기", "fr": "Associez les produits", "de": "Produkte zuordnen", "es": "Empareja los productos", "ru": "Сопоставь произведения", "ar": "طابق النواتج", "pt": "Emparelhe os produtos", "it": "Abbina i prodotti" },
  "matrix_reasoning": { "ja": "規則を見つけて行列を埋めろ", "ko": "규칙 찾아 행렬 채우기", "fr": "Trouvez la règle et remplissez", "de": "Regel finden und füllen", "es": "Halla la regla y rellena", "ru": "Найди правило и заполни", "ar": "اكتشف القاعدة واملأ", "pt": "Ache a regra e preencha", "it": "Trova la regola e riempi" },
  "mental_abacus": { "ja": "そろばん暗算", "ko": "주판 암산", "fr": "Boulier mental", "de": "Kopfrechnen mit Abakus", "es": "Ábaco mental", "ru": "Счёт на абаке", "ar": "حساب بالمعداد", "pt": "Cálculo com ábaco", "it": "Calcolo con l’abaco" },
  "sorting_visualizer": { "ja": "並べ替えが踊る", "ko": "정렬이 춤춘다", "fr": "Le tri qui danse", "de": "Sortieren zum Zusehen", "es": "El orden que baila", "ru": "Сортировка в танце", "ar": "فرز يرقص", "pt": "A ordenação que dança", "it": "L’ordinamento che balla" },
  "spider_solitaire": { "ja": "同じスートで順に並べる", "ko": "같은 무늬 순서대로", "fr": "Même couleur, ordre croissant", "de": "Gleiche Farbe, aufsteigend", "es": "Mismo palo en orden", "ru": "Одна масть по порядку", "ar": "نفس اللون بالترتيب", "pt": "Mesmo naipe em ordem", "it": "Stesso seme in ordine" },
  "sudoku_hex": { "ja": "6×6 のマスを埋めろ", "ko": "6×6 칸 채우기", "fr": "Remplissez la grille 6×6", "de": "Fülle das 6×6-Gitter", "es": "Rellena la cuadrícula 6×6", "ru": "Заполни сетку 6×6", "ar": "املأ شبكة 6×6", "pt": "Preencha a grelha 6×6", "it": "Riempi la griglia 6×6" },
  "tetris": { "ja": "落ちるブロックを積め", "ko": "떨어지는 블록 쌓기", "fr": "Empilez les blocs", "de": "Stapel die fallenden Blöcke", "es": "Apila los bloques", "ru": "Складывай падающие блоки", "ar": "رصّ المكعبات المتساقطة", "pt": "Empilhe os blocos", "it": "Impila i blocchi" },
  "tic_tac_toe": { "ja": "三つ並べたら勝ち", "ko": "세 개 잇면 승리", "fr": "Trois alignés, gagné", "de": "Drei in Reihe gewinnt", "es": "Tres en línea gana", "ru": "Три в ряд — победа", "ar": "ثلاثة في صف تفوز", "pt": "Três em linha ganha", "it": "Tre in fila vincono" },
  "wordle": { "ja": "5文字の単語を当てろ", "ko": "5글자 단어 맞추기", "fr": "Devinez le mot de cinq lettres", "de": "Errate das Fünf-Buchstaben-Wort", "es": "Adivina la palabra de cinco letras", "ru": "Угадай слово из пяти букв", "ar": "خمّن كلمة من خمسة أحرف", "pt": "Adivinhe a palavra de cinco letras", "it": "Indovina la parola di cinque lettere" },
  "akari": { "ja": "光で全部のマスを照らせ", "ko": "빛으로 모든 칸 밝히기", "fr": "Éclairez toutes les cases", "de": "Erhelle alle Felder", "es": "Ilumina todas las casillas", "ru": "Освети все клетки", "ar": "أضئ كل الخانات", "pt": "Ilumine todas as casas", "it": "Illumina tutte le caselle" },
  "alphabet_sudoku": { "ja": "数字の代わりに文字で", "ko": "숫자 대신 글자로", "fr": "Des lettres au lieu de chiffres", "de": "Buchstaben statt Zahlen", "es": "Letras en vez de números", "ru": "Буквы вместо цифр", "ar": "حروف بدل الأرقام", "pt": "Letras em vez de números", "it": "Lettere invece di numeri" },
  "binary_puzzle": { "ja": "各行・列の数が同じで三連なし", "ko": "행·열 개수 같고 삼연속 없이", "fr": "Autant de 1 par ligne, jamais trois", "de": "Gleiche Anzahl, nie drei in Folge", "es": "Igual cantidad, nunca tres seguidas", "ru": "Поровну, но не три подряд", "ar": "بالتساوي ودون ثلاثة متتالية", "pt": "Iguais, nunca três seguidas", "it": "Uguali, mai tre di fila" },
  "block_escape": { "ja": "障害をどけてブロックを出せ", "ko": "장애물 치우고 블록 빼기", "fr": "Dégagez le bloc", "de": "Block freilegen", "es": "Libera el bloque", "ru": "Освободи блок", "ar": "حرّر المكعب", "pt": "Liberte o bloco", "it": "Libera il blocco" },
  "bridges": { "ja": "数字の島を橋でつなげ", "ko": "숫자 섬을 다리로 잇기", "fr": "Reliez les îles par des ponts", "de": "Inseln mit Brücken verbinden", "es": "Une islas con puentes", "ru": "Соедини острова мостами", "ar": "صِل الجزر بجسور", "pt": "Ligue as ilhas por pontes", "it": "Collega le isole con ponti" },
  "bridges_all": { "ja": "大きな盤で橋をかけろ", "ko": "큰 판에서 다리 놓기", "fr": "Ponts sur grand plateau", "de": "Brücken auf großem Feld", "es": "Puentes en tablero grande", "ru": "Мосты на большом поле", "ar": "جسور على لوح كبير", "pt": "Pontes em tabuleiro grande", "it": "Ponti su grande griglia" },
  "color_flood": { "ja": "一色で盤を広げろ", "ko": "한 색으로 판 채우기", "fr": "Inondez d’une seule couleur", "de": "Mit einer Farbe fluten", "es": "Inunda con un solo color", "ru": "Залей одним цветом", "ar": "اغمر بلون واحد", "pt": "Inunde com uma cor", "it": "Inonda con un colore" },
  "crown": { "ja": "各行・列・区に王冠ひとつ", "ko": "행·열·구역에 왕관 하나", "fr": "Une couronne par ligne et région", "de": "Eine Krone je Reihe und Block", "es": "Una corona por fila y región", "ru": "Одна корона на ряд и блок", "ar": "تاج واحد لكل صف ومنطقة", "pt": "Uma coroa por linha e região", "it": "Una corona per riga e regione" },
  "dominosa": { "ja": "骨牌で網目を埋めろ", "ko": "도미노로 격자 채우기", "fr": "Remplissez la grille de dominos", "de": "Fülle das Gitter mit Dominos", "es": "Rellena con dominós", "ru": "Заполни сетку домино", "ar": "املأ الشبكة بالدومينو", "pt": "Preencha com dominós", "it": "Riempi con i domino" },
  "fillomino": { "ja": "同じ数字を決まった大きさの塊に", "ko": "같은 숫자를 정해진 크기로", "fr": "Reliez les mêmes nombres", "de": "Gleiche Zahlen zu Blöcken", "es": "Une los números iguales", "ru": "Соедини одинаковые числа", "ar": "صِل الأرقام المتشابهة", "pt": "Ligue os números iguais", "it": "Unisci i numeri uguali" },
  "futoshiki": { "ja": "重複なし、不等号も守れ", "ko": "중복 없이 부등호도 지켜라", "fr": "Sans répétition, respectez les signes", "de": "Ohne Wiederholung, Zeichen beachten", "es": "Sin repetir y con desigualdades", "ru": "Без повторов, чти знаки", "ar": "بلا تكرار ومع المتباينات", "pt": "Sem repetir e com desigualdades", "it": "Senza ripetizioni e con i segni" },
  "gokigen_naname": { "ja": "斜線を引いて数字と合わせろ", "ko": "대각선 그어 숫자 맞추기", "fr": "Tracez des diagonales", "de": "Diagonalen ziehen", "es": "Traza diagonales", "ru": "Проведи диагонали", "ar": "ارسم الأقطار", "pt": "Trace diagonais", "it": "Traccia le diagonali" },
  "heyawake": { "ja": "部屋を分けて黒く塗れ", "ko": "방 나눠 검게 칠하기", "fr": "Noircissez par pièces", "de": "Räume schwärzen", "es": "Ennegrece por habitaciones", "ru": "Черни по комнатам", "ar": "سوّد حسب الغرف", "pt": "Ennegreça por salas", "it": "Annerisci per stanze" },
  "hitori": { "ja": "塗りつぶして重複を消せ", "ko": "칠해서 중복 없애기", "fr": "Noircissez pour éviter les doublons", "de": "Schwärzen gegen Doppelte", "es": "Ennegrece sin repetir", "ru": "Зачерни без повторов", "ar": "سوّد بلا تكرار", "pt": "Ennegreça sem repetir", "it": "Annerisci senza ripetere" },
  "hitori_all": { "ja": "大きな盤で重複を消せ", "ko": "큰 판에서 중복 없애기", "fr": "Grand plateau sans doublons", "de": "Großes Feld ohne Doppelte", "es": "Tablero grande sin repetir", "ru": "Большое поле без повторов", "ar": "لوح كبير بلا تكرار", "pt": "Tabuleiro grande sem repetir", "it": "Grande griglia senza ripetere" },
  "kakurasu_sums": { "ja": "塗った列と行で目標数を作れ", "ko": "칠한 열·행으로 목표 수 만들기", "fr": "Atteignez la cible en noircissant", "de": "Zielzahl durch Schwärzen", "es": "Alcanza la meta ennegreciendo", "ru": "Набери цель зачернением", "ar": "ابلغ الهدف بالتسويد", "pt": "Atinga a meta enegrecendo", "it": "Raggiungi il bersaglio annerendo" },
  "kakuro": { "ja": "横竖の和がヒントになるように", "ko": "가로세로 합이 힌트와 같게", "fr": "Les sommes doivent coller aux indices", "de": "Summen müssen zu den Hinweisen passen", "es": "Las sumas deben cuadrar", "ru": "Суммы должны сойтись", "ar": "يجب أن تطابق المجاميع", "pt": "As somas devem bater", "it": "Le somme devono tornare" },
  "kenken": { "ja": "四則演算でマスを埋めろ", "ko": "사칙연산으로 칸 채우기", "fr": "Remplissez avec les quatre opérations", "de": "Mit den vier Rechenarten füllen", "es": "Rellena con las cuatro operaciones", "ru": "Заполни четырьмя действиями", "ar": "املأ بالعمليات الأربع", "pt": "Preencha com as quatro operações", "it": "Riempi con le quattro operazioni" },
  "klotski": { "ja": "ブロックを動かして脱出させろ", "ko": "블록 움직여 탈출시키기", "fr": "Faites sortir le bloc", "de": "Block herausbewegen", "es": "Saca el bloque", "ru": "Выведи блок", "ar": "أخرج المكعب", "pt": "Faça sair o bloco", "it": "Fai uscire il blocco" },
  "kurodoko": { "ja": "黒マスを置いて白をつなげ", "ko": "검은 칸 놓고 흰 칸 잇기", "fr": "Placez du noir, reliez le blanc", "de": "Schwarz setzen, Weiß verbinden", "es": "Pon negro y une el blanco", "ru": "Ставь чёрное, соединяй белое", "ar": "ضع الأسود وصِل الأبيض", "pt": "Ponha preto e ligue o branco", "it": "Metti il nero e unisci il bianco" },
  "lighthouses": { "ja": "灯台で船を照らせ", "ko": "등대로 배 비추기", "fr": "Éclairez les bateaux", "de": "Schiffe mit Leuchttürmen beleuchten", "es": "Ilumina los barcos", "ru": "Освети корабли маяками", "ar": "أضئ السفن بالمنارات", "pt": "Ilumine os barcos", "it": "Illumina le navi" },
  "lights_out": { "ja": "全部消灯にしろ", "ko": "전부 소등시키기", "fr": "Éteignez toutes les lumières", "de": "Alle Lichter aus", "es": "Apaga todas las luces", "ru": "Погаси все огни", "ar": "أطفئ كل الأنوار", "pt": "Apague todas as luzes", "it": "Spegni tutte le luci" },
  "magnets": { "ja": "プラスとマイナスを合わせろ", "ko": "플러스와 마이너스 맞추기", "fr": "Associez les pôles", "de": "Plus und Minus paaren", "es": "Empareja los polos", "ru": "Соедини полюса", "ar": "طابق الأقطاب", "pt": "Emparelhe os polos", "it": "Abbina i poli" },
  "masyu": { "ja": "白黒の輪のルールで回路を作れ", "ko": "흑백 원 규칙으로 회로 만들기", "fr": "Formez une boucle selon les cercles", "de": "Schleife nach den Kreisen", "es": "Forma un bucle según los círculos", "ru": "Замкни петлю по кругам", "ar": "شكّل حلقة وفق الدوائر", "pt": "Forme um laço pelos círculos", "it": "Forma un anello secondo i cerchi" },
  "math_maze": { "ja": "計算結果どおりに進め", "ko": "계산 결과대로 나아가기", "fr": "Avancez selon les résultats", "de": "Nach den Rechenergebnissen gehen", "es": "Avanza según los resultados", "ru": "Иди по результатам", "ar": "تقدّم حسب النتائج", "pt": "Avance pelos resultados", "it": "Avanza con i risultati" },
  "math_path": { "ja": "正しい式になる道をつなげ", "ko": "올바른 식이 되는 길 잇기", "fr": "Reliez pour former l’opération", "de": "Zum richtigen Rechenweg verbinden", "es": "Une para formar la operación", "ru": "Соедини в верное выражение", "ar": "صِل لتكوين العملية", "pt": "Ligue para formar a operação", "it": "Collega per formare l’operazione" },
  "nonogram": { "ja": "数字どおりに塗って絵を出せ", "ko": "숫자대로 칠해 그림 완성", "fr": "Révélez l’image en noircissant", "de": "Bild durch Schwärzen zeigen", "es": "Revela la imagen ennegreciendo", "ru": "Прояви картинку закраской", "ar": "اكشف الصورة بالتسويد", "pt": "Revele a imagem enegrecendo", "it": "Rivela l’immagine annerendo" },
  "norinori": { "ja": "各区域にドミノを二つ置け", "ko": "각 구역에 도미노 두 개", "fr": "Deux dominos par région", "de": "Zwei Dominos je Region", "es": "Dos dominós por región", "ru": "Два домино в каждой зоне", "ar": "دومينو اثنان لكل منطقة", "pt": "Dois dominós por região", "it": "Due domino per regione" },
  "nurikabe": { "ja": "数字どおりに壁を作れ", "ko": "숫자대로 벽 만들기", "fr": "Bâtissez les murs selon les nombres", "de": "Mauern nach den Zahlen bauen", "es": "Construye muros según los números", "ru": "Строй стены по числам", "ar": "ابنِ الجدران حسب الأرقام", "pt": "Construa muros pelos números", "it": "Costruisci muri secondo i numeri" },
  "path_finder": { "ja": "唯一の道をつなげ", "ko": "유일한 길 잇기", "fr": "Tracez l’unique chemin", "de": "Den einzigen Weg finden", "es": "Traza el único camino", "ru": "Найди единственный путь", "ar": "صِل المسار الوحيد", "pt": "Trace o único caminho", "it": "Traccia l’unico percorso" },
  "path_intersect": { "ja": "線が交差しないようにつなげ", "ko": "선이 교차하지 않게 잇기", "fr": "Reliez sans croiser", "de": "Verbinden ohne Kreuzung", "es": "Une sin cruzar", "ru": "Соедини без пересечений", "ar": "صِل دون تقاطع", "pt": "Ligue sem cruzar", "it": "Collega senza incrociare" },
  "pipes": { "ja": "パイプを回して水を通せ", "ko": "파이프 돌려 물 통과시키기", "fr": "Faites passer l’eau", "de": "Wasser durchleiten", "es": "Haz pasar el agua", "ru": "Проведи воду", "ar": "مرّر الماء", "pt": "Faça passar a água", "it": "Fai passare l’acqua" },
  "shikaku": { "ja": "数字どおりの長方形に分けろ", "ko": "숫자대로 직사각형 나누기", "fr": "Découpez en rectangles", "de": "In Rechtecke teilen", "es": "Divide en rectángulos", "ru": "Раздели на прямоугольники", "ar": "قسّم إلى مستطيلات", "pt": "Divida em retângulos", "it": "Dividi in rettangoli" },
  "skyscrapers": { "ja": "外から見た高さが重複しないように", "ko": "밖에서 본 높이가 겹치지 않게", "fr": "Les hauteurs vues ne se répètent pas", "de": "Von außen gesehen keine Doppelten", "es": "Sin repetir alturas vistas", "ru": "Без повторов высот", "ar": "بلا تكرار في الارتفاعات", "pt": "Sem repetir alturas", "it": "Senza ripetere le altezze" },
  "bejeweled": { "ja": "3つ並べて消そう", "ko": "3개 맞춰 지우기", "fr": "Alignez trois gemmes", "de": "Drei gleiche reihen", "es": "Junta tres gemas", "ru": "Собери три в ряд", "ar": "اصنع صفًا من ثلاثة", "pt": "Junte três gemas", "it": "Allinea tre gemme" },
  "breakout": { "ja": "ボールで全部崩せ", "ko": "공으로 전부 깨기", "fr": "Cassez tout à la balle", "de": "Räume alles mit dem Ball ab", "es": "Rompe todo con la bola", "ru": "Выбей всё мячом", "ar": "كسّر الكل بالكرة", "pt": "Quebre tudo com a bola", "it": "Rompi tutto con la palla" },
  "bubble_shooter": { "ja": "泡を撃って3つ消し", "ko": "버블 쏴서 3개 맞추기", "fr": "Tirez et alignez trois", "de": "Blasen schießen, drei treffen", "es": "Dispara y junta tres", "ru": "Стреляй и собирай три", "ar": "اطلق وطابق ثلاثة", "pt": "Atire e junte três", "it": "Spara e allinea tre" },
  "checkers": { "ja": "飛び越えて取る", "ko": "뛰어넘어 잡기", "fr": "Sautez et capturez", "de": "Springen und schlagen", "es": "Salta y captura", "ru": "Прыгай и ешь", "ar": "اقفز وخذ", "pt": "Salte e capture", "it": "Salta e cattura" },
  "compound_connect": { "ja": "複数条件でつなぐ", "ko": "여러 조건으로 연결", "fr": "Reliez sous conditions", "de": "Unter Bedingungen verbinden", "es": "Conecta con condiciones", "ru": "Соединяй по условиям", "ar": "اربط وفق الشروط", "pt": "Ligue por condições", "it": "Collega con condizioni" },
  "connect_four": { "ja": "四つ並べたら勝ち", "ko": "네 개 잇면 승리", "fr": "Quatre alignés, gagné", "de": "Vier in einer Reihe gewinnt", "es": "Cuatro en línea gana", "ru": "Четыре в ряд — победа", "ar": "أربعة في صف تفوز", "pt": "Quatro em linha ganha", "it": "Quattro in fila vincono" },
  "continuous_paired_associate": { "ja": "覚えてペアを作る", "ko": "기억해서 짝 만들기", "fr": "Mémorisez et associez", "de": "Merken und zuordnen", "es": "Memoriza y empareja", "ru": "Запомни и сопоставь", "ar": "احفظ وطابق", "pt": "Memorize e emparelhe", "it": "Memorizza e abbina" },
  "doodle_jump": { "ja": "タップで跳び続けろ", "ko": "탭해서 계속 점프", "fr": "Tapez pour rester en l’air", "de": "Tippen und oben bleiben", "es": "Toca para seguir subiendo", "ru": "Прыгай без остановки", "ar": "انقر لتبقى محلّقًا", "pt": "Toque para subir", "it": "Tocca per restare in aria" },
  "double_trouble": { "ja": "二つの課題を同時に", "ko": "두 과제를 동시에", "fr": "Deux tâches à la fois", "de": "Zwei Aufgaben zugleich", "es": "Dos tareas a la vez", "ru": "Две задачи сразу", "ar": "مهمتان معًا", "pt": "Duas tarefas ao mesmo tempo", "it": "Due compiti insieme" },
  "dual_mirror": { "ja": "左右同時に鏡操作", "ko": "좌우 동시 미러 조작", "fr": "Miroir des deux côtés", "de": "Beidseitig spiegeln", "es": "Espejo por ambos lados", "ru": "Зеркаль оба края", "ar": "مرآة على الجانبين", "pt": "Espelhe os dois lados", "it": "Specchia entrambi i lati" },
  "flappy": { "ja": "パイプをすり抜けろ", "ko": "파이프 사이로 통과", "fr": "Passez entre les tuyaux", "de": "Durch die Rohre fliegen", "es": "Pasa entre las tuberías", "ru": "Пролетай между труб", "ar": "مرّ بين الأنابيب", "pt": "Passe entre os tubos", "it": "Passa tra i tubi" },
  "freecell": { "ja": "4列を自由に運ぶ", "ko": "4열 자유 이동", "fr": "Quatre colonnes libres", "de": "Vier freie Spalten", "es": "Cuatro columnas libres", "ru": "Четыре свободные стопки", "ar": "أربعة أعمدة حرّة", "pt": "Quatro colunas livres", "it": "Quattro colonne libere" },
  "g2048": { "ja": "数字を合わせて塞がるな", "ko": "숫자 합치되 막히지 마라", "fr": "Fusionnez sans bloquer", "de": "Zahlen mergen, nicht blockieren", "es": "Fusiona sin bloquear", "ru": "Сливай числа, не застрянь", "ar": "ادمج الأرقام ولا تسدّ", "pt": "Junte sem bloquear", "it": "Unisci senza bloccare" },
  "game24": { "ja": "四つの数で24を作れ", "ko": "네 수로 24 만들기", "fr": "Faites 24 avec quatre nombres", "de": "Mit vier Zahlen 24 bilden", "es": "Haz 24 con cuatro números", "ru": "Собери 24 из четырёх", "ar": "اصنع 24 من أربعة", "pt": "Faça 24 com quatro", "it": "Fai 24 con quattro" },
  "go9": { "ja": "地を囲み石を取れ", "ko": "집을 둘러 돌 잡기", "fr": "Encerclez plus de territoire", "de": "Umzingle mehr Gebiet", "es": "Rodea más territorio", "ru": "Окружай территорию", "ar": "طوّق أرضًا أكثر", "pt": "Cerque mais território", "it": "Circonda più territorio" },
  "gomoku": { "ja": "AI と五目並べ", "ko": "AI와 오목", "fr": "Cinq en ligne contre l’IA", "de": "Fünf in Reihe gegen KI", "es": "Cinco en línea contra la IA", "ru": "Пять в ряд против ИИ", "ar": "خمسة في صف ضد الحاسوب", "pt": "Cinco em linha contra a IA", "it": "Cinque in fila contro l’IA" },
  "hanoi": { "ja": "三本の棒で全部移せ", "ko": "세 기둥으로 전부 옮기기", "fr": "Déplacez toute la tour", "de": "Verschiebe den ganzen Turm", "es": "Mueve toda la torre", "ru": "Перенеси всю башню", "ar": "انقل البرج كله", "pt": "Mova a torre inteira", "it": "Sposta tutta la torre" },
  "kakuro_mini": { "ja": "小さな足し算パズル", "ko": "작은 덧셈 퍼즐", "fr": "Petit puzzle d’additions", "de": "Kleines Summenrätsel", "es": "Pequeño puzle de sumas", "ru": "Маленькая сумма-головоломка", "ar": "أحجية جمع صغيرة", "pt": "Pequeno puzzle de somas", "it": "Piccolo puzzle di somme" },
  "life_game": { "ja": "動くアルゴリズム", "ko": "살아 움직이는 알고리즘", "fr": "Un algorithme vivant", "de": "Ein lebendiger Algorithmus", "es": "Un algoritmo vivo", "ru": "Живой алгоритм", "ar": "خوارزمية حيّة", "pt": "Um algoritmo vivo", "it": "Un algoritmo vivo" },
  "lock_pattern": { "ja": "一筆で模様を描け", "ko": "한 붓으로 패턴 그리기", "fr": "Dessinez le motif d’un trait", "de": "Muster in einem Zug", "es": "Dibuja el patrón de un trazo", "ru": "Нарисуй узор одним ходом", "ar": "ارسم النمط بخط واحد", "pt": "Desenhe o padrão num traço", "it": "Disegna il motivo in un tratto" },
  "mahjong_solitaire": { "ja": "牌を合わせて消す", "ko": "패 맞춰 지우기", "fr": "Associez et éliminez les tuiles", "de": "Paare finden und entfernen", "es": "Empareja y elimina fichas", "ru": "Собирай пары и убирай", "ar": "طابق وأزل البلاطات", "pt": "Empareje e elimine", "it": "Abbina ed elimina" },
  "mancala": { "ja": "石をまいて集めろ", "ko": "돌 뿌려 모으기", "fr": "Semez et récoltez", "de": "Säen und ernten", "es": "Siembra y cosecha", "ru": "Сей и собирай", "ar": "ابذر واحصد", "pt": "Semeie e colha", "it": "Semina e raccogli" },
  "mandelbrot": { "ja": "動くアルゴリズム", "ko": "살아 움직이는 알고리즘", "fr": "Un algorithme vivant", "de": "Ein lebendiger Algorithmus", "es": "Un algoritmo vivo", "ru": "Живой алгоритм", "ar": "خوارزمية حيّة", "pt": "Um algoritmo vivo", "it": "Un algoritmo vivo" },
  "mastermind": { "ja": "色の組み合わせを当てろ", "ko": "색 조합 맞추기", "fr": "Devinez la combinaison", "de": "Errate die Farbkombination", "es": "Adivina la combinación", "ru": "Угадай комбинацию", "ar": "خمّن التركيبة", "pt": "Adivinhe a combinação", "it": "Indovina la combinazione" },
  "match3": { "ja": "3つ並べて連鎖", "ko": "3개 맞춰 연쇄", "fr": "Alignez trois et enchaînez", "de": "Drei reihen, Ketten bilden", "es": "Junta tres y encadena", "ru": "Собирай три и комбо", "ar": "طابق ثلاثة وسلسل", "pt": "Junte três e encadeie", "it": "Allinea tre e concatena" },
  "memory": { "ja": "めくって揃える記憶力", "ko": "뒤집어 짝 맞추기", "fr": "Retournez et associez", "de": "Umdrehen und paaren", "es": "Voltea y empareja", "ru": "Переворачивай и находи пары", "ar": "اقلب وطابق", "pt": "Vire e emparelhe", "it": "Gira e abbina" },
  "minesweeper": { "ja": "地雷に旗を立てろ", "ko": "지뢰에 깃발 꽂기", "fr": "Marquez les mines", "de": "Minen markieren", "es": "Marca las minas", "ru": "Отмечай мины флажками", "ar": "علّم الألغام", "pt": "Marque as minas", "it": "Segna le mine" },
  "nim": { "ja": "最後の一個を取ったら負け", "ko": "마지막 하나를 가져가면 패배", "fr": "Prenez le dernier et perdez", "de": "Wer zuletzt nimmt, verliert", "es": "Quien toma el último pierde", "ru": "Кто берёт последний — проиграл", "ar": "من يأخذ الأخير يخسر", "pt": "Quem tira o último perde", "it": "Chi prende l’ultimo perde" },
  "peg_solitaire": { "ja": "跳んで一粒だけ残せ", "ko": "뛰어서 하나만 남기기", "fr": "Sautez jusqu’à une seule", "de": "Springen bis auf einen", "es": "Salta hasta dejar uno", "ru": "Прыгай, оставь одну", "ar": "اقفز حتى تبقى واحدة", "pt": "Salte até sobrar um", "it": "Salta fino a uno" },
  "phonetic_guess": { "ja": "発音記号から単語を当てろ", "ko": "발음기호로 단어 맞추기", "fr": "Devinez le mot par sa phonétique", "de": "Wort aus Lautschrift erraten", "es": "Adivina la palabra por su fonética", "ru": "Угадай слово по транскрипции", "ar": "خمّن الكلمة من الرمز الصوتي", "pt": "Adivinhe pela fonética", "it": "Indovina dalla fonetica" },
  "pong": { "ja": "球を打ち合え", "ko": "공 주고받기", "fr": "Échangez la balle", "de": "Ball hin und her", "es": "Intercambia la bola", "ru": "Отбивай мяч", "ar": "تبادل الكرة", "pt": "Troque a bola", "it": "Scambia la palla" },
  "reversi": { "ja": "挟んでひっくり返せ", "ko": "사이에 두고 뒤집기", "fr": "Encerclez et retournez", "de": "Einklemmen und umdrehen", "es": "Rodea y voltea", "ru": "Зажми и переверни", "ar": "حاصر واقلب", "pt": "Cerque e vire", "it": "Circonda e gira" },
  "schulte": { "ja": "数字を順に押して集中", "ko": "숫자를 순서대로 눌러 집중", "fr": "Trouvez les nombres dans l’ordre", "de": "Zahlen der Reihe nach finden", "es": "Encuentra los números en orden", "ru": "Находи числа по порядку", "ar": "ابحث عن الأرقام بالترتيب", "pt": "Encontre os números em ordem", "it": "Trova i numeri in ordine" },
  "sieve_visualizer": { "ja": "素数がふるい落とされる", "ko": "소수가 걸러지는 모습", "fr": "Le crible des nombres premiers", "de": "Primzahlen sieben", "es": "La criba de los primos", "ru": "Решето простых чисел", "ar": "غربال الأعداد الأولية", "pt": "O crivo dos primos", "it": "Il crivello dei primi" },
  "simon_says": { "ja": "動作をまねしろ", "ko": "동작 따라 하기", "fr": "Imitez les gestes", "de": "Bewegungen nachmachen", "es": "Imita los gestos", "ru": "Повторяй движения", "ar": "قلّد الحركات", "pt": "Imite os gestos", "it": "Imita i gesti" },
  "slide15": { "ja": "スライドして揃えろ", "ko": "슬라이드해서 맞추기", "fr": "Faites glisser pour ranger", "de": "Schieben bis alles passt", "es": "Desliza hasta ordenar", "ru": "Двигай до порядка", "ar": "حرّك حتى الترتيب", "pt": "Deslize até ordenar", "it": "Fai scorrere fino all’ordine" },
  "snake": { "ja": "食べて伸びろ、噛むな", "ko": "먹고 자라되 물지 마라", "fr": "Mangez, grandissez, sans mordre", "de": "Fressen, wachsen, nicht beißen", "es": "Come, crece y no te muerdas", "ru": "Ешь, расти, не кусай", "ar": "كُل واطُل ولا تعضّ نفسك", "pt": "Coma, cresça, não se morda", "it": "Mangia, cresci, non morderti" },
  "snake_3d": { "ja": "食べて伸びろ、噛むな", "ko": "먹고 자라되 물지 마라", "fr": "Mangez, grandissez, sans mordre", "de": "Fressen, wachsen, nicht beißen", "es": "Come, crece y no te muerdas", "ru": "Ешь, расти, не кусай", "ar": "كُل واطُل ولا تعضّ نفسك", "pt": "Coma, cresça, não se morda", "it": "Mangia, cresci, non morderti" },
  "sokoban": { "ja": "押して運び、詰めろ", "ko": "밀어서 옮기기", "fr": "Poussez chaque caisse", "de": "Jede Kiste an ihren Platz", "es": "Empuja cada caja", "ru": "Толкай ящики на места", "ar": "ادفع كل صندوق لمكانه", "pt": "Empurre cada caixa", "it": "Spingi ogni cassa" },
  "solitaire": { "ja": "定番のカード並べ", "ko": "정석 카드 놀이", "fr": "La patience classique", "de": "Klassische Kartenpatience", "es": "El solitario clásico", "ru": "Классический пасьянс", "ar": "السوليتير الكلاسيكي", "pt": "A paciência clássica", "it": "Il solitario classico" },
};

export function gameTagline(id: string, zh: string, en: string): string {
  const c: string = I18n.current();
  if (c === Lang.ZH) { return zh; }
  if (c === Lang.EN) { return en; }
  if (c === Lang.ZHTW) { return toTrad(zh); }
  const row: Record<string, string> | undefined = GAME_TAGLINE[id];
  if (row !== undefined) {
    const hit: string = row[c];
    if (hit !== undefined && hit.length > 0) { return hit; }
  }
  return en;   // 未收录 ⇒ 暂退英文
}

const GAME_NAME: Record<string, Record<string, string>> = {
  "ab_reversal_oddball": { "ja": "AB 反転", "ko": "AB 역전", "fr": "Inversion AB", "de": "AB-Umkehr", "es": "Inversión AB", "ru": "Обращение AB", "ar": "انعكاس AB", "pt": "Inversão AB", "it": "Inversione AB" },
  "action_sequence_recall": { "ja": "動作系列", "ko": "동작 순서", "fr": "Séquence d’actions", "de": "Handlungsfolge", "es": "Secuencia de acciones", "ru": "Последовательность действий", "ar": "تسلسل الحركات", "pt": "Sequência de ações", "it": "Sequenza di azioni" },
  "angle_finder": { "ja": "角度を探せ", "ko": "각도 찾기", "fr": "Trouve l’angle", "de": "Winkel finden", "es": "Encuentra el ángulo", "ru": "Найди угол", "ar": "ابحث عن الزاوية", "pt": "Ache o ângulo", "it": "Trova l’angolo" },
  "area_perimeter_match": { "ja": "面積と周長", "ko": "넓이와 둘레", "fr": "Aire et périmètre", "de": "Fläche und Umfang", "es": "Área y perímetro", "ru": "Площадь и периметр", "ar": "المساحة والمحيط", "pt": "Área e perímetro", "it": "Area e perimetro" },
  "binary_matrix_rank_all": { "ja": "行列の階数・上級", "ko": "행렬 계수 심화", "fr": "Rang matriciel avancé", "de": "Matrixrang Profi", "es": "Rango avanzado", "ru": "Ранг матрицы: сложное", "ar": "رتبة متقدّمة", "pt": "Posto avançado", "it": "Rango avanzato" },
  "blink_detector": { "ja": "まばたき検出", "ko": "눈 깜빡임 감지", "fr": "Détection de clignement", "de": "Blinzeln erkennen", "es": "Detector de parpadeos", "ru": "Детектор моргания", "ar": "كشف الرمش", "pt": "Detector de piscadas", "it": "Rileva il battito di ciglia" },
  "block_count_3d": { "ja": "立体ブロック数え", "ko": "3D 블록 세기", "fr": "Compter les cubes", "de": "Würfel zählen", "es": "Contar cubos", "ru": "Счёт кубиков", "ar": "عدّ المكعبات", "pt": "Contar cubos", "it": "Conta i cubi" },
  "block_stacking_physics": { "ja": "ブロック積み", "ko": "블록 쌓기", "fr": "Empiler des blocs", "de": "Blöcke stapeln", "es": "Apilar bloques", "ru": "Ставь блоки", "ar": "رصّ المكعبات", "pt": "Empilhar blocos", "it": "Impila i blocchi" },
  "box_completion": { "ja": "箱を完成させろ", "ko": "상자 완성", "fr": "Compléter la boîte", "de": "Kiste vervollständigen", "es": "Completar la caja", "ru": "Дополни коробку", "ar": "أكمل الصندوق", "pt": "Completar a caixa", "it": "Completa la scatola" },
  "chain_reaction": { "ja": "連鎖反応", "ko": "연쇄 반응", "fr": "Réaction en chaîne", "de": "Kettenreaktion", "es": "Reacción en cadena", "ru": "Цепная реакция", "ar": "تفاعل متسلسل", "pt": "Reação em cadeia", "it": "Reazione a catena" },
  "circuit_connect": { "ja": "回路をつなげ", "ko": "회로 연결", "fr": "Connecter le circuit", "de": "Schaltung verbinden", "es": "Conectar el circuito", "ru": "Соедини цепь", "ar": "وصّل الدائرة", "pt": "Ligar o circuito", "it": "Collega il circuito" },
  "classic_maze": { "ja": "古典迷路", "ko": "클래식 미로", "fr": "Labyrinthe classique", "de": "Klassisches Labyrinth", "es": "Laberinto clásico", "ru": "Классический лабиринт", "ar": "متاهة كلاسيكية", "pt": "Labirinto clássico", "it": "Labirinto classico" },
  "color_match": { "ja": "色合わせ", "ko": "색 맞추기", "fr": "Correspondance de couleurs", "de": "Farbabgleich", "es": "Coincidencia de colores", "ru": "Подбор цвета", "ar": "مطابقة الألوان", "pt": "Combinação de cores", "it": "Abbina i colori" },
  "color_maze_nav": { "ja": "色彩迷路", "ko": "색 미로", "fr": "Labyrinthe de couleurs", "de": "Farbenlabyrinth", "es": "Laberinto de colores", "ru": "Цветовой лабиринт", "ar": "متاهة الألوان", "pt": "Labirinto de cores", "it": "Labirinto di colori" },
  "compass_maze": { "ja": "コンパス迷路", "ko": "나침반 미로", "fr": "Labyrinthe boussole", "de": "Kompass-Labyrinth", "es": "Laberinto de brújula", "ru": "Лабиринт по компасу", "ar": "متاهة البوصلة", "pt": "Labirinto da bússola", "it": "Labirinto della bussola" },
  "complex_folding_nets": { "ja": "複雑折り紙", "ko": "복잡한 종이접기", "fr": "Pliage complexe", "de": "Komplexes Falten", "es": "Plegado complejo", "ru": "Сложное складывание", "ar": "طيّ معقّد", "pt": "Dobra complexa", "it": "Piegatura complessa" },
  "counting_sheep": { "ja": "羊を数える", "ko": "양 세기", "fr": "Compter les moutons", "de": "Schafe zählen", "es": "Contar ovejas", "ru": "Считать овец", "ar": "عدّ الخراف", "pt": "Contar ovelhas", "it": "Conta le pecore" },
  "cross_section_slice": { "ja": "断面スライス", "ko": "단면 자르기", "fr": "Coupe transversale", "de": "Querschnitt", "es": "Corte transversal", "ru": "Поперечное сечение", "ar": "مقطع عرضي", "pt": "Corte transversal", "it": "Sezione trasversale" },
  "cryptogram_all": { "ja": "暗号文・上級", "ko": "암호문 심화", "fr": "Cryptogramme avancé", "de": "Kryptogramm Profi", "es": "Criptograma avanzado", "ru": "Криптограмма: сложное", "ar": "نص مشفّر متقدّم", "pt": "Criptograma avançado", "it": "Crittogramma avanzato" },
  "cube_net_fold": { "ja": "立方体の展開図", "ko": "정육면체 전개도", "fr": "Patron du cube", "de": "Würfelnetz", "es": "Desarrollo del cubo", "ru": "Развёртка куба", "ar": "شبكة المكعب", "pt": "Planificação do cubo", "it": "Sviluppo del cubo" },
  "directions_recall": { "ja": "方向の記憶", "ko": "방향 기억", "fr": "Mémoire des directions", "de": "Richtungsgedächtnis", "es": "Memoria de direcciones", "ru": "Память направлений", "ar": "ذاكرة الاتجاهات", "pt": "Memória de direções", "it": "Memoria delle direzioni" },
  "distractor_matrix": { "ja": "妨害行列", "ko": "방해 행렬", "fr": "Matrice de distracteurs", "de": "Störmatrix", "es": "Matriz de distractores", "ru": "Матрица помех", "ar": "مصفوفة المشتّتات", "pt": "Matriz de distratores", "it": "Matrice di distrattori" },
  "einstein_riddle": { "ja": "アインシュタインの謎", "ko": "아인슈타인 수수께끼", "fr": "Énigme d’Einstein", "de": "Einstein-Rätsel", "es": "Acertijo de Einstein", "ru": "Загадка Эйнштейна", "ar": "أحجية أينشتاين", "pt": "Enigma de Einstein", "it": "Indovinello di Einstein" },
  "fact_binder": { "ja": "事実の結びつけ", "ko": "사실 연결", "fr": "Lier les faits", "de": "Fakten verbinden", "es": "Vincular hechos", "ru": "Свяжи факты", "ar": "اربط الحقائق", "pt": "Ligar factos", "it": "Collega i fatti" },
  "focus_tunnel": { "ja": "集中トンネル", "ko": "집중 터널", "fr": "Tunnel de concentration", "de": "Fokus-Tunnel", "es": "Túnel de concentración", "ru": "Туннель внимания", "ar": "نفق التركيز", "pt": "Túnel de foco", "it": "Tunnel di concentrazione" },
  "gear_rotation": { "ja": "歯車の回転", "ko": "기어 회전", "fr": "Rotation d’engrenages", "de": "Zahnraddrehung", "es": "Rotación de engranajes", "ru": "Вращение шестерён", "ar": "دوران التروس", "pt": "Rotação de engrenagens", "it": "Rotazione degli ingranaggi" },
  "gear_train_direction": { "ja": "歯車列", "ko": "기어 열", "fr": "Train d’engrenages", "de": "Zahnradgetriebe", "es": "Tren de engranajes", "ru": "Зубчатая передача", "ar": "مجموعة التروس", "pt": "Trem de engrenagens", "it": "Treno di ingranaggi" },
  "geometric_vision": { "ja": "幾何直觉", "ko": "기하 직관", "fr": "Intuition géométrique", "de": "Geometrische Intuition", "es": "Intuición geométrica", "ru": "Геометрическая интуиция", "ar": "حدس هندسي", "pt": "Intuição geométrica", "it": "Intuizione geometrica" },
  "graph_coordinate_plot": { "ja": "座標プロット", "ko": "좌표 그리기", "fr": "Tracé de coordonnées", "de": "Koordinaten zeichnen", "es": "Trazar coordenadas", "ru": "Построй по координатам", "ar": "رسم الإحداثيات", "pt": "Traçar coordenadas", "it": "Traccia le coordinate" },
  "gravity_sort": { "ja": "重力ソート", "ko": "중력 정렬", "fr": "Tri par gravité", "de": "Schwerkraft-Sortierung", "es": "Orden por gravedad", "ru": "Сортировка гравитацией", "ar": "فرز الجاذبية", "pt": "Ordenar por gravidade", "it": "Ordina con la gravità" },
  "grid_displacement": { "ja": "グリッド移動", "ko": "격자 이동", "fr": "Déplacement de grille", "de": "Gitterverschiebung", "es": "Desplazamiento de rejilla", "ru": "Смещение по сетке", "ar": "إزاحة الشبكة", "pt": "Deslocamento na grelha", "it": "Spostamento sulla griglia" },
  "hue_sort": { "ja": "色相ソート", "ko": "색상 정렬", "fr": "Tri par teinte", "de": "Farbton sortieren", "es": "Orden por tono", "ru": "Сортировка по оттенку", "ar": "ترتيب الدرجة اللونية", "pt": "Ordenar por tonalidade", "it": "Ordina per tonalità" },
  "interlock_puzzle": { "ja": "interlock パズル", "ko": "맞물림 퍼즐", "fr": "Puzzle à emboîtement", "de": "Verriegelungspuzzle", "es": "Puzle entrelazado", "ru": "Сцеплённая головоломка", "ar": "أحجية متشابكة", "pt": "Puzzle entrelaçado", "it": "Puzzle a incastro" },
  "laser_link": { "ja": "レーザー連結", "ko": "레이저 연결", "fr": "Liaison laser", "de": "Laser-Verbindung", "es": "Conexión láser", "ru": "Лазерная связь", "ar": "ربط الليزر", "pt": "Ligação laser", "it": "Collegamento laser" },
  "laser_reflect": { "ja": "鏡の反射", "ko": "거울 반사", "fr": "Réflexion de miroir", "de": "Spiegelreflexion", "es": "Reflejo de espejos", "ru": "Отражение зеркал", "ar": "انعكاس المرايا", "pt": "Reflexão de espelhos", "it": "Riflessione degli specchi" },
  "logical_syllogisms": { "ja": "論理三段論法", "ko": "논리 삼단논법", "fr": "Syllogismes logiques", "de": "Logische Syllogismen", "es": "Silogismos lógicos", "ru": "Логические силлогизмы", "ar": "القياس المنطقي", "pt": "Silogismos lógicos", "it": "Sillogismi logici" },
  "math_guess": { "ja": "数字当て", "ko": "숫자 맞추기", "fr": "Devine le nombre", "de": "Zahl erraten", "es": "Adivina el número", "ru": "Угадай число", "ar": "خمّن الرقم", "pt": "Adivinhe o número", "it": "Indovina il numero" },
  "maze_nav_3d": { "ja": "3D 迷路", "ko": "3D 미로", "fr": "Labyrinthe 3D", "de": "3D-Labyrinth", "es": "Laberinto 3D", "ru": "3D-лабиринт", "ar": "متاهة 3D", "pt": "Labirinto 3D", "it": "Labirinto 3D" },
  "mental_mapping": { "ja": "心の地図", "ko": "심적 지도", "fr": "Carte mentale", "de": "Mentale Karte", "es": "Mapa mental", "ru": "Мысленная карта", "ar": "خريطة ذهنية", "pt": "Mapa mental", "it": "Mappa mentale" },
  "mental_rotation": { "ja": "心的回転", "ko": "심적 회전", "fr": "Rotation mentale", "de": "Mentale Rotation", "es": "Rotación mental", "ru": "Мысленное вращение", "ar": "تدوير ذهني", "pt": "Rotação mental", "it": "Rotazione mentale" },
  "mirror_image": { "ja": "鏡像", "ko": "거울상", "fr": "Image miroir", "de": "Spiegelbild", "es": "Imagen especular", "ru": "Зеркальное отражение", "ar": "صورة مرآة", "pt": "Imagem espelhada", "it": "Immagine speculare" },
  "mirror_maze": { "ja": "鏡迷路", "ko": "거울 미로", "fr": "Labyrinthe miroir", "de": "Spiegel-Labyrinth", "es": "Laberinto espejo", "ru": "Зеркальный лабиринт", "ar": "متاهة المرآة", "pt": "Labirinto espelhado", "it": "Labirinto a specchio" },
  "mirror_tracing": { "ja": "鏡でなぞる", "ko": "거울 따라 그리기", "fr": "Tracé au miroir", "de": "Spiegel-Nachzeichnen", "es": "Trazar con espejo", "ru": "Рисование по зеркалу", "ar": "الرسم بالمرآة", "pt": "Traçar ao espelho", "it": "Traccia allo specchio" },
  "multi_track_counter": { "ja": "多重カウント", "ko": "다중 추적 세기", "fr": "Comptage multi-pistes", "de": "Mehrfachzählung", "es": "Conteo múltiple", "ru": "Многоканальный счёт", "ar": "عدّ متعدّد", "pt": "Contagem múltipla", "it": "Conteggio multiplo" },
  "navon_hierarchical": { "ja": "全体と部分", "ko": "전체와 부분", "fr": "Global et local", "de": "Ganzes und Teile", "es": "Global y local", "ru": "Целое и части", "ar": "الكل والجزء", "pt": "Global e local", "it": "Globale e locale" },
  "odd_one_out": { "ja": "仲間はずれ", "ko": "다른 것 찾기", "fr": "Intrus", "de": "Finde den Ausreißer", "es": "El intruso", "ru": "Найди лишнее", "ar": "ابحث عن المختلف", "pt": "Encontre o intruso", "it": "Trova l’intruso" },
  "odd_rotation": { "ja": "回転の異類", "ko": "회전 이상치", "fr": "Rotation intruse", "de": "Dreh-Ausreißer", "es": "Rotación intrusa", "ru": "Лишний поворот", "ar": "شاذّ الدوران", "pt": "Rotação intrusa", "it": "Rotazione intrusa" },
  "orbit_tap": { "ja": "軌道タップ", "ko": "궤도 탭", "fr": "Tap orbital", "de": "Orbit-Tippen", "es": "Toque orbital", "ru": "Орбитальное нажатие", "ar": "نقر مداري", "pt": "Toque orbital", "it": "Tocco orbitale" },
  "paper_folding": { "ja": "紙折り", "ko": "종이 접기", "fr": "Pliage de papier", "de": "Papierfalten", "es": "Plegado de papel", "ru": "Складывание бумаги", "ar": "طيّ الورق", "pt": "Dobra de papel", "it": "Piegatura della carta" },
  "path_recall": { "ja": "経路の記憶", "ko": "경로 기억", "fr": "Mémoire du chemin", "de": "Weg-Gedächtnis", "es": "Memoria del camino", "ru": "Память пути", "ar": "ذاكرة المسار", "pt": "Memória do caminho", "it": "Memoria del percorso" },
  "perspective_shift_view": { "ja": "視点切替", "ko": "시점 전환", "fr": "Changement de point de vue", "de": "Perspektivwechsel", "es": "Cambio de perspectiva", "ru": "Смена перспективы", "ar": "تغيير المنظور", "pt": "Mudança de perspetiva", "it": "Cambio di prospettiva" },
  "perspective_taking": { "ja": "他者視点", "ko": "타자 시점", "fr": "Prise de perspective", "de": "Perspektivübernahme", "es": "Toma de perspectiva", "ru": "Принятие перспективы", "ar": "تبنّي المنظور", "pt": "Adotar a perspetiva", "it": "Assumere la prospettiva" },
  "pixel_mimic": { "ja": "ピクセル模写", "ko": "픽셀 따라 그리기", "fr": "Copie de pixels", "de": "Pixel nachzeichnen", "es": "Copiar píxeles", "ru": "Копируй пиксели", "ar": "نسخ البكسلات", "pt": "Copiar píxeis", "it": "Copia i pixel" },
  "polyomino_tiling": { "ja": "ポリオミノ", "ko": "폴리오미노", "fr": "Polyomino", "de": "Polyomino", "es": "Poliominó", "ru": "Полиомино", "ar": "بوليومينو", "pt": "Poliominó", "it": "Poliomino" },
  "room_inspector": { "ja": "部屋の観察", "ko": "방 안 살피기", "fr": "Inspecteur de pièce", "de": "Raum-Prüfer", "es": "Inspector de habitación", "ru": "Осмотр комнаты", "ar": "مفتّش الغرفة", "pt": "Inspetor de sala", "it": "Ispettore della stanza" },
  "rotating_maze": { "ja": "回転迷路", "ko": "회전 미로", "fr": "Labyrinthe tournant", "de": "Drehlabyrinth", "es": "Laberinto giratorio", "ru": "Вращающийся лабиринт", "ar": "متاهة دوّارة", "pt": "Labirinto giratório", "it": "Labirinto rotante" },
  "shadow_pivot": { "ja": "影の回転", "ko": "그림자 회전", "fr": "Rotation d’ombre", "de": "Schatten-Drehung", "es": "Rotación de sombra", "ru": "Поворот тени", "ar": "دوران الظل", "pt": "Rotação da sombra", "it": "Rotazione dell’ombra" },
  "shape_shifter": { "ja": "変形", "ko": "변형", "fr": "Métamorphe", "de": "Formwandler", "es": "Transformista", "ru": "Формоизменение", "ar": "متغيّر الشكل", "pt": "Transformador", "it": "Trasformista" },
  "silhouette_match": { "ja": "シルエット合わせ", "ko": "실루엣 맞추기", "fr": "Correspondance de silhouettes", "de": "Silhouetten-Abgleich", "es": "Coincidencia de siluetas", "ru": "Подбор силуэта", "ar": "مطابقة الظل", "pt": "Combinação de silhuetas", "it": "Abbina le silhouette" },
  "silhouette_match_ortho": { "ja": "正投影シルエット", "ko": "정투영 실루엣", "fr": "Silhouettes orthogonales", "de": "Orthogonale Silhouetten", "es": "Siluetas ortogonales", "ru": "Ортогональные силуэты", "ar": "ظلال متعامدة", "pt": "Silhuetas ortogonais", "it": "Silhouette ortogonali" },
  "simon_command": { "ja": "サイモンの指令", "ko": "사이먼 지시", "fr": "Ordres de Simon", "de": "Simons Befehle", "es": "Órdenes de Simón", "ru": "Команды Саймона", "ar": "أوامر سايمون", "pt": "Ordens do Simon", "it": "Comandi di Simon" },
  "simon_sequence": { "ja": "サイモンの順序", "ko": "사이먼 순서", "fr": "Séquence de Simon", "de": "Simons Reihenfolge", "es": "Secuencia de Simón", "ru": "Последовательность Саймона", "ar": "تسلسل سايمون", "pt": "Sequência do Simon", "it": "Sequenza di Simon" },
  "source_monitoring": { "ja": "出典の記憶", "ko": "출처 기억", "fr": "Mémoire de la source", "de": "Quellengedächtnis", "es": "Memoria de la fuente", "ru": "Память об источнике", "ar": "ذاكرة المصدر", "pt": "Memória da fonte", "it": "Memoria della fonte" },
  "spatial_conflict": { "ja": "空間の衝突", "ko": "공간 충돌", "fr": "Conflit spatial", "de": "Räumlicher Konflikt", "es": "Conflicto espacial", "ru": "Пространственный конфликт", "ar": "تعارض مكاني", "pt": "Conflito espacial", "it": "Conflitto spaziale" },
  "sternberg_task": { "ja": "スタンバーグ課題", "ko": "스턴버그 과제", "fr": "Tâche de Sternberg", "de": "Sternberg-Aufgabe", "es": "Tarea de Sternberg", "ru": "Задача Стернберга", "ar": "مهمة ستيرنبرغ", "pt": "Tarefa de Sternberg", "it": "Compito di Sternberg" },
  "symmetry": { "ja": "対称", "ko": "대칭", "fr": "Symétrie", "de": "Symmetrie", "es": "Simetría", "ru": "Симметрия", "ar": "التناظر", "pt": "Simetria", "it": "Simmetria" },
  "symmetry_span": { "ja": "対称スパン", "ko": "대칭 폭", "fr": "Empan de symétrie", "de": "Symmetriespanne", "es": "Amplitud de simetría", "ru": "Объём симметрии", "ar": "امتداد التناظر", "pt": "Amplitude de simetria", "it": "Span di simmetria" },
  "tangram": { "ja": "タングラム", "ko": "탱그램", "fr": "Tangram", "de": "Tangram", "es": "Tangram", "ru": "Танграм", "ar": "تانغرام", "pt": "Tangram", "it": "Tangram" },
  "temporal_order": { "ja": "時間の順序", "ko": "시간 순서", "fr": "Ordre temporel", "de": "Zeitliche Reihenfolge", "es": "Orden temporal", "ru": "Временной порядок", "ar": "الترتيب الزمني", "pt": "Ordem temporal", "it": "Ordine temporale" },
  "temporal_order_judgment": { "ja": "時系列判断", "ko": "시간 순서 판단", "fr": "Jugement temporel", "de": "Zeitfolge beurteilen", "es": "Juicio temporal", "ru": "Оценка порядка во времени", "ar": "حكم زمني", "pt": "Julgamento temporal", "it": "Giudizio temporale" },
  "topology": { "ja": "トポロジー", "ko": "위상수학", "fr": "Topologie", "de": "Topologie", "es": "Topología", "ru": "Топология", "ar": "الطوبولوجيا", "pt": "Topologia", "it": "Topologia" },
  "tower_of_hanoi": { "ja": "ハノイの塔", "ko": "하노이 탑", "fr": "Tours de Hanoï", "de": "Türme von Hanoi", "es": "Torres de Hanói", "ru": "Ханойская башня", "ar": "أبراج هانوي", "pt": "Torres de Hanói", "it": "Torri di Hanoi" },
  "tower_of_london": { "ja": "ロンドン塔", "ko": "런던 탑", "fr": "Tour de Londres", "de": "Turm von London", "es": "Torre de Londres", "ru": "Лондонская башня", "ar": "برج لندن", "pt": "Torre de Londres", "it": "Torre di Londra" },
  "trace_path": { "ja": "経路をなぞる", "ko": "경로 따라가기", "fr": "Suivre le chemin", "de": "Weg nachzeichnen", "es": "Trazar el camino", "ru": "Обведи путь", "ar": "تتبّع المسار", "pt": "Traçar o caminho", "it": "Traccia il percorso" },
  "triple_sequence": { "ja": "三重系列", "ko": "삼중 순서", "fr": "Triple séquence", "de": "Dreifachfolge", "es": "Triple secuencia", "ru": "Тройная последовательность", "ar": "تسلسل ثلاثي", "pt": "Sequência tripla", "it": "Sequenza tripla" },
  "triplets_logic": { "ja": "三要素論理", "ko": "삼원 논리", "fr": "Logique à trois", "de": "Dreierlogik", "es": "Lógica de tríos", "ru": "Логика троек", "ar": "منطق الثلاثيات", "pt": "Lógica de trios", "it": "Logica delle terne" },
  "visual_search_all": { "ja": "視覚探索・上級", "ko": "시각 탐색 심화", "fr": "Recherche visuelle avancée", "de": "Visuelle Suche Profi", "es": "Búsqueda visual avanzada", "ru": "Зрительный поиск: сложное", "ar": "بحث بصري متقدّم", "pt": "Busca visual avançada", "it": "Ricerca visiva avanzata" },
  "visual_statistical_learning": { "ja": "統計的学習", "ko": "통계적 학습", "fr": "Apprentissage statistique", "de": "Statistisches Lernen", "es": "Aprendizaje estadístico", "ru": "Статистическое обучение", "ar": "تعلّم إحصائي", "pt": "Aprendizagem estatística", "it": "Apprendimento statistico" },
  "wireframe_3d_rotation": { "ja": "ワイヤーフレーム回転", "ko": "와이어프레임 회전", "fr": "Rotation filaire 3D", "de": "Drahtgitter-Rotation", "es": "Rotación de alambre 3D", "ru": "Вращение каркаса 3D", "ar": "دوران سلكي 3D", "pt": "Rotação de arame 3D", "it": "Rotazione wireframe 3D" },
  "etymon_oddball": { "ja": "語根の異類", "ko": "어근 이상치", "fr": "Intrus en racines", "de": "Wurzel-Ausreißer", "es": "Intruso de raíces", "ru": "Лишний корень", "ar": "شاذّ الجذور", "pt": "Intruso de raízes", "it": "Intruso di radici" },
  "find_word": { "ja": "単語探し", "ko": "단어 찾기", "fr": "Trouve le mot", "de": "Wort finden", "es": "Encuentra la palabra", "ru": "Найди слово", "ar": "ابحث عن الكلمة", "pt": "Ache a palavra", "it": "Trova la parola" },
  "grammar_police": { "ja": "文法警察", "ko": "문법 경찰", "fr": "Police grammaticale", "de": "Grammatikpolizei", "es": "Policía gramatical", "ru": "Грамматическая полиция", "ar": "شرطة القواعد", "pt": "Polícia gramatical", "it": "Polizia grammaticale" },
  "grammar_sort": { "ja": "文法分類", "ko": "문법 분류", "fr": "Tri grammatical", "de": "Grammatik sortieren", "es": "Clasificación gramatical", "ru": "Сортировка частей речи", "ar": "تصنيف القواعد", "pt": "Classificação gramatical", "it": "Classifica grammaticale" },
  "homophone_hunt": { "ja": "同音語探し", "ko": "동음이의어 찾기", "fr": "Chasse aux homophones", "de": "Homophon-Jagd", "es": "Caza de homófonos", "ru": "Охота на омофоны", "ar": "صيد المتجانسات", "pt": "Caça aos homófonos", "it": "Caccia agli omofoni" },
  "letter_bridge": { "ja": "文字の橋", "ko": "글자 다리", "fr": "Pont de lettres", "de": "Buchstabenbrücke", "es": "Puente de letras", "ru": "Мост из букв", "ar": "جسر الحروف", "pt": "Ponte de letras", "it": "Ponte di lettere" },
  "letter_cancellation": { "ja": "文字消し", "ko": "글자 지우기", "fr": "Barrer les lettres", "de": "Buchstaben streichen", "es": "Tachar letras", "ru": "Зачеркни буквы", "ar": "شطب الحروف", "pt": "Riscar letras", "it": "Cancella le lettere" },
  "letter_frequency_scan": { "ja": "文字頻度", "ko": "글자 빈도", "fr": "Fréquence des lettres", "de": "Buchstabenhäufigkeit", "es": "Frecuencia de letras", "ru": "Частота букв", "ar": "تكرار الحروف", "pt": "Frequência de letras", "it": "Frequenza delle lettere" },
  "letter_grid_swapper": { "ja": "文字の入れ替え", "ko": "글자 바꾸기", "fr": "Échange de lettres", "de": "Buchstabentausch", "es": "Cambio de letras", "ru": "Перестановка букв", "ar": "تبديل الحروف", "pt": "Troca de letras", "it": "Scambio di lettere" },
  "missing_vowels": { "ja": "抜けた母音", "ko": "빠진 모음", "fr": "Voyelles manquantes", "de": "Fehlende Vokale", "es": "Vocales que faltan", "ru": "Пропущенные гласные", "ar": "حروف العلة الناقصة", "pt": "Vogais que faltam", "it": "Vocali mancanti" },
  "one_letter_shift": { "ja": "一文字シフト", "ko": "한 글자 바꾸기", "fr": "Décalage d’une lettre", "de": "Ein Buchstabe anders", "es": "Cambio de una letra", "ru": "Сдвиг на букву", "ar": "تغيير حرف", "pt": "Troca de uma letra", "it": "Cambia una lettera" },
  "oxymoron_hunt": { "ja": "矛盾語探し", "ko": "모순어 찾기", "fr": "Chasse aux oxymores", "de": "Oxymoron-Jagd", "es": "Caza de oxímoron", "ru": "Охота на оксюмороны", "ar": "صيد المفارقات", "pt": "Caça aos oximoros", "it": "Caccia agli ossimori" },
  "palindrome_builder": { "ja": "回文づくり", "ko": "회문 만들기", "fr": "Créer des palindromes", "de": "Palindrome bauen", "es": "Crea palíndromos", "ru": "Составь палиндром", "ar": "كوّن جملة معكوسة", "pt": "Crie palíndromos", "it": "Crea palindromi" },
  "pangram_sprint": { "ja": "パングラム", "ko": "팬그램", "fr": "Pangramme", "de": "Pangramm", "es": "Pangrama", "ru": "Панграмма", "ar": "جملة شاملة الحروف", "pt": "Pangrama", "it": "Pangramma" },
  "portmanteau_split": { "ja": "かばん語の分割", "ko": "혼성어 나누기", "fr": "Découper les mots-valises", "de": "Kofferwort trennen", "es": "Separar palabras combinadas", "ru": "Раздели слово-гибрид", "ar": "فصل الكلمات المدمجة", "pt": "Separar palavras mistas", "it": "Dividi le parole macedonia" },
  "rhyme_master": { "ja": "韻マスター", "ko": "운율 마스터", "fr": "Maître des rimes", "de": "Reim-Meister", "es": "Maestro de rimas", "ru": "Мастер рифмы", "ar": "سيّد القوافي", "pt": "Mestre das rimas", "it": "Maestro delle rime" },
  "semantic_association": { "ja": "意味連想", "ko": "의미 연상", "fr": "Association sémantique", "de": "Semantische Assoziation", "es": "Asociación semántica", "ru": "Смысловые связи", "ar": "ترابط دلالي", "pt": "Associação semântica", "it": "Associazione semantica" },
  "semantic_distance": { "ja": "意味の距離", "ko": "의미 거리", "fr": "Distance sémantique", "de": "Semantische Distanz", "es": "Distancia semántica", "ru": "Смысловая дистанция", "ar": "المسافة الدلالية", "pt": "Distância semântica", "it": "Distanza semantica" },
  "semantic_link": { "ja": "意味つなぎ", "ko": "의미 연결", "fr": "Chaîne sémantique", "de": "Semantische Kette", "es": "Cadena semántica", "ru": "Смысловая цепь", "ar": "سلسلة دلالية", "pt": "Cadeia semântica", "it": "Catena semantica" },
  "sentence_unscramble": { "ja": "文の並べ替え", "ko": "문장 재배열", "fr": "Phrase à remettre en ordre", "de": "Satz ordnen", "es": "Frase desordenada", "ru": "Собери предложение", "ar": "رتّب الجملة", "pt": "Frase embaralhada", "it": "Frase da riordinare" },
  "silent_letter_search": { "ja": "発音しない文字", "ko": "묵음 글자", "fr": "Lettres muettes", "de": "Stumme Buchstaben", "es": "Letras mudas", "ru": "Немые буквы", "ar": "الحروف الصامتة", "pt": "Letras mudas", "it": "Lettere mute" },
  "spelling_sprint": { "ja": "綴りダッシュ", "ko": "철자 스프린트", "fr": "Sprint d’orthographe", "de": "Rechtschreib-Tempo", "es": "Sprint de ortografía", "ru": "Спринт правописания", "ar": "سباق التهجئة", "pt": "Corrida de ortografia", "it": "Sprint di ortografia" },
  "spoonerism_solver": { "ja": "頭音入れ替え", "ko": "머리소리 바꾸기", "fr": "Spoonérisme", "de": "Schüttelreim", "es": "Espunerismo", "ru": "Спунерíзм", "ar": "قلب الأصوات", "pt": "Spoonerismo", "it": "Spoonerismo" },
  "story_builder": { "ja": "物語づくり", "ko": "이야기 만들기", "fr": "Construire une histoire", "de": "Geschichte bauen", "es": "Construir un relato", "ru": "Собери рассказ", "ar": "بناء قصة", "pt": "Construir uma história", "it": "Costruisci una storia" },
  "syllable_stack": { "ja": "音節スタック", "ko": "음절 쌓기", "fr": "Pile de syllabes", "de": "Silbenstapel", "es": "Pila de sílabas", "ru": "Слог-стек", "ar": "مكدّس المقاطع", "pt": "Pilha de sílabas", "it": "Pila di sillabe" },
  "typing_speed": { "ja": "タイピング速度", "ko": "타자 속도", "fr": "Vitesse de frappe", "de": "Tippgeschwindigkeit", "es": "Velocidad de escritura", "ru": "Скорость печати", "ar": "سرعة الكتابة", "pt": "Velocidade de digitação", "it": "Velocità di digitazione" },
  "typoglycemia_decoder": { "ja": "語順ゆらぎ解読", "ko": "어순 흐트러짐 해독", "fr": "Décodage typoglycémique", "de": "Typoglykämie-Decoder", "es": "Descifrado tipoglucémico", "ru": "Расшифровка перестановок", "ar": "فكّ تشوّش الحروف", "pt": "Decodificador tipoglicêmico", "it": "Decodifica tipoglicemica" },
  "verbal_analogies": { "ja": "言語アナロジー", "ko": "언어 유추", "fr": "Analogies verbales", "de": "Sprachliche Analogien", "es": "Analogías verbales", "ru": "Словесные аналогии", "ar": "تناظر لفظي", "pt": "Analogias verbais", "it": "Analogie verbali" },
  "vocabulary_builder": { "ja": "語彙づくり", "ko": "어휘 늘리기", "fr": "Enrichir son vocabulaire", "de": "Wortschatz aufbauen", "es": "Ampliar vocabulario", "ru": "Пополнение словаря", "ar": "بناء المفردات", "pt": "Ampliar vocabulário", "it": "Arricchisci il vocabolario" },
  "vowel_reconstruct": { "ja": "母音の復元", "ko": "모음 복원", "fr": "Reconstruire les voyelles", "de": "Vokale rekonstruieren", "es": "Reconstruir vocales", "ru": "Восстанови гласные", "ar": "استعادة الحروف", "pt": "Reconstruir vogais", "it": "Ricostruisci le vocali" },
  "word_association_recall": { "ja": "語彙連想", "ko": "어휘 연상", "fr": "Rappel d’associations", "de": "Wortassoziation", "es": "Recuerdo de asociaciones", "ru": "Припоминание связей", "ar": "تذكّر الترابط", "pt": "Recordação de associações", "it": "Richiamo di associazioni" },
  "word_grid_connection": { "ja": "語の格子つなぎ", "ko": "단어 격자 연결", "fr": "Grille de mots à relier", "de": "Wortgitter verbinden", "es": "Rejilla de palabras", "ru": "Сетка слов", "ar": "شبكة الكلمات", "pt": "Grade de palavras", "it": "Griglia di parole" },
  "word_ladder": { "ja": "単語のはしご", "ko": "단어 사다리", "fr": "Échelle de mots", "de": "Wortleiter", "es": "Escalera de palabras", "ru": "Словесная лестница", "ar": "سلّم الكلمات", "pt": "Escada de palavras", "it": "Scala di parole" },
  "word_ladder_step": { "ja": "はしご一歩", "ko": "사다리 한 걸음", "fr": "Un pas d’échelle", "de": "Ein Leiterschritt", "es": "Un paso de escalera", "ru": "Один шаг лестницы", "ar": "خطوة واحدة", "pt": "Um degrau", "it": "Un gradino" },
  "word_mastermind": { "ja": "単語マスターマインド", "ko": "단어 마스터마인드", "fr": "Mastermind de mots", "de": "Wort-Mastermind", "es": "Mastermind de palabras", "ru": "Словесный мастермайнд", "ar": "ماسترمايند الكلمات", "pt": "Mastermind de palavras", "it": "Mastermind di parole" },
  "word_scramble": { "ja": "文字並べ替え", "ko": "글자 재배열", "fr": "Lettres mélangées", "de": "Buchstabensalat", "es": "Letras revueltas", "ru": "Собери слово", "ar": "حروف مبعثرة", "pt": "Letras embaralhadas", "it": "Lettere mescolate" },
  "word_search": { "ja": "単語探しゲーム", "ko": "단어 찾기 퍼즐", "fr": "Mots mêlés", "de": "Wortsuchrätsel", "es": "Sopa de letras", "ru": "Найди слова", "ar": "البحث عن الكلمات", "pt": "Caça-palavras", "it": "Crucipuzzle" },
  "word_snake_trail": { "ja": "単語スネーク", "ko": "단어 스네이크", "fr": "Serpent de mots", "de": "Wortschlange", "es": "Serpiente de palabras", "ru": "Змейка из слов", "ar": "ثعبان الكلمات", "pt": "Cobra de palavras", "it": "Serpente di parole" },
  "word_surge": { "ja": "語彙ラッシュ", "ko": "단어 러시", "fr": "Ruée de mots", "de": "Wortrausch", "es": "Torrente de palabras", "ru": "Словесный поток", "ar": "تدفّق الكلمات", "pt": "Torrente de palavras", "it": "Fiume di parole" },
  "word_wheel": { "ja": "単語ホイール", "ko": "단어 휠", "fr": "Roue de mots", "de": "Wortrad", "es": "Rueda de palabras", "ru": "Словесное колесо", "ar": "عجلة الكلمات", "pt": "Roda de palavras", "it": "Ruota di parole" },
  "relational_memory": { "ja": "関係記憶", "ko": "관계 기억", "fr": "Mémoire relationnelle", "de": "Beziehungsgedächtnis", "es": "Memoria relacional", "ru": "Память связей", "ar": "ذاكرة العلاقات", "pt": "Memória relacional", "it": "Memoria relazionale" },
  "reverse_stroop": { "ja": "逆ストループ", "ko": "역 스트룹", "fr": "Stroop inversé", "de": "Umgekehrter Stroop", "es": "Stroop inverso", "ru": "Обратный Струп", "ar": "ستروب معكوس", "pt": "Stroop inverso", "it": "Stroop inverso" },
  "rhythm_master": { "ja": "リズムマスター", "ko": "리듬 마스터", "fr": "Maître du rythme", "de": "Rhythmus-Meister", "es": "Maestro del ritmo", "ru": "Мастер ритма", "ar": "سيّد الإيقاع", "pt": "Mestre do ritmo", "it": "Maestro del ritmo" },
  "rule_switcher": { "ja": "ルール切替", "ko": "규칙 전환", "fr": "Changeur de règles", "de": "Regelwechsler", "es": "Cambiador de reglas", "ru": "Переключатель правил", "ar": "مبدّل القواعد", "pt": "Troca-regras", "it": "Cambia regole" },
  "running_memory_span": { "ja": "記憶スパン", "ko": "기억 폭", "fr": "Empan de mémoire", "de": "Gedächtnisspanne", "es": "Amplitud de memoria", "ru": "Объём памяти", "ar": "امتداد الذاكرة", "pt": "Amplitude de memória", "it": "Span di memoria" },
  "sdmt": { "ja": "符号数字変換", "ko": "기호 숫자 변환", "fr": "Substitution symbole-chiffre", "de": "Symbol-Ziffern-Test", "es": "Sustitución símbolo-dígito", "ru": "Символ-цифра", "ar": "رمز إلى رقم", "pt": "Substituição símbolo-dígito", "it": "Sostituzione simbolo-cifra" },
  "shell_game": { "ja": "カップ当て", "ko": "컵 맞추기", "fr": "Bonneteau", "de": "Hütchenspiel", "es": "Juego de los vasos", "ru": "Наперсток", "ar": "لعبة الكؤوس", "pt": "Jogo dos copos", "it": "Gioco delle tre tazze" },
  "sopt": { "ja": "自定順序", "ko": "자율 순서", "fr": "Ordre auto-défini", "de": "Selbstgewählte Reihenfolge", "es": "Orden autoimpuesto", "ru": "Свой порядок", "ar": "ترتيب ذاتي", "pt": "Ordem própria", "it": "Ordine scelto" },
  "spatial_cabinet_memory": { "ja": "戸棚の記憶", "ko": "장롱 기억", "fr": "Mémoire du meuble", "de": "Schrank-Gedächtnis", "es": "Memoria del armario", "ru": "Память шкафа", "ar": "ذاكرة الخزانة", "pt": "Memória do armário", "it": "Memoria dell’armadio" },
  "spotlight_track": { "ja": "スポット追跡", "ko": "스포트라이트 추적", "fr": "Suivi du projecteur", "de": "Scheinwerfer-Verfolgung", "es": "Seguimiento del foco", "ru": "Слежение за лучом", "ar": "تتبّع الضوء", "pt": "Rastreio do foco", "it": "Tracciamento del faro" },
  "staircase_memory": { "ja": "階段記憶", "ko": "계단 기억", "fr": "Mémoire en escalier", "de": "Treppen-Gedächtnis", "es": "Memoria en escalera", "ru": "Память лестницы", "ar": "ذاكرة الدرج", "pt": "Memória em escada", "it": "Memoria a scalini" },
  "stop_signal": { "ja": "停止信号", "ko": "정지 신호", "fr": "Signal d’arrêt", "de": "Stoppsignal", "es": "Señal de alto", "ru": "Стоп-сигнал", "ar": "إشارة التوقف", "pt": "Sinal de parada", "it": "Segnale di stop" },
  "stroop_number_size": { "ja": "数字の大きさ", "ko": "숫자 크기", "fr": "Taille des chiffres", "de": "Zifferngröße", "es": "Tamaño del número", "ru": "Размер числа", "ar": "حجم الرقم", "pt": "Tamanho do número", "it": "Dimensione del numero" },
  "stroop_test": { "ja": "ストループ", "ko": "스트룹", "fr": "Stroop", "de": "Stroop", "es": "Stroop", "ru": "Струп", "ar": "ستروب", "pt": "Stroop", "it": "Stroop" },
  "subitizing_rush": { "ja": "サビタイジング", "ko": "수량 직관", "fr": "Subitizing", "de": "Subitizing", "es": "Subitizing", "ru": "Субитизация", "ar": "إدراك العدد", "pt": "Subitizing", "it": "Subitizing" },
  "switch_task": { "ja": "課題切替", "ko": "과제 전환", "fr": "Alternance de tâches", "de": "Aufgabenwechsel", "es": "Cambio de tarea", "ru": "Переключение задач", "ar": "تبديل المهام", "pt": "Troca de tarefa", "it": "Cambio di compito" },
  "symbol_digit_assoc": { "ja": "記号と数字", "ko": "기호와 숫자", "fr": "Symboles et chiffres", "de": "Symbol und Ziffer", "es": "Símbolos y dígitos", "ru": "Символы и цифры", "ar": "رموز وأرقام", "pt": "Símbolos e dígitos", "it": "Simboli e cifre" },
  "symbol_logic": { "ja": "記号論理", "ko": "기호 논리", "fr": "Logique symbolique", "de": "Symbolische Logik", "es": "Lógica simbólica", "ru": "Символьная логика", "ar": "منطق رمزي", "pt": "Lógica simbólica", "it": "Logica simbolica" },
  "symbolic_flanker": { "ja": "記号フランカー", "ko": "기호 플랭커", "fr": "Flanker symbolique", "de": "Symbolischer Flanker", "es": "Flanker simbólico", "ru": "Символьный фланкер", "ar": "فلانكر رمزي", "pt": "Flanker simbólico", "it": "Flanker simbolico" },
  "task_switching": { "ja": "切替コスト", "ko": "전환 비용", "fr": "Coût du changement", "de": "Wechselkosten", "es": "Coste del cambio", "ru": "Цена переключения", "ar": "كلفة التبديل", "pt": "Custo da troca", "it": "Costo del cambio" },
  "trail_making": { "ja": "線引きテスト", "ko": "선 잇기 검사", "fr": "Test du tracé", "de": "Spurenlegen", "es": "Test del trazo", "ru": "Тест следования", "ar": "اختبار التتبّع", "pt": "Teste de trilha", "it": "Test della traccia" },
  "vigilance_task": { "ja": "警戒課題", "ko": "경계 과제", "fr": "Tâche de vigilance", "de": "Vigilanzaufgabe", "es": "Tarea de vigilancia", "ru": "Задача бдительности", "ar": "مهمة اليقظة", "pt": "Tarefa de vigilância", "it": "Compito di vigilanza" },
  "visual_crowding_acuity": { "ja": "混雑視力", "ko": "혼잡 시력", "fr": "Acuité d’encombrement", "de": "Gedrängelsehschärfe", "es": "Agudeza de apiñamiento", "ru": "Скученность зрения", "ar": "حدّة الازدحام", "pt": "Acuidade de aglomeração", "it": "Acuità di affollamento" },
  "visual_search": { "ja": "視覚探索", "ko": "시각 탐색", "fr": "Recherche visuelle", "de": "Visuelle Suche", "es": "Búsqueda visual", "ru": "Зрительный поиск", "ar": "بحث بصري", "pt": "Busca visual", "it": "Ricerca visiva" },
  "visual_search_conjunction": { "ja": "結合探索", "ko": "결합 탐색", "fr": "Recherche conjonctive", "de": "Konjunktionssuche", "es": "Búsqueda conjuntiva", "ru": "Поиск по сочетанию", "ar": "بحث مقترن", "pt": "Busca conjuntiva", "it": "Ricerca congiunta" },
  "wisconsin_card_sorting": { "ja": "ウィスコンシンカード", "ko": "위스콘신 카드", "fr": "Tri de cartes du Wisconsin", "de": "Wisconsin-Kartensortierung", "es": "Clasificación de Wisconsin", "ru": "Висконсинский тест", "ar": "فرز بطاقات ويسكونسن", "pt": "Classificação de Wisconsin", "it": "Ordinamento del Wisconsin" },
  "word_pair_associate_memory": { "ja": "語対記憶", "ko": "단어쌍 기억", "fr": "Mémoire de paires de mots", "de": "Wortpaar-Gedächtnis", "es": "Memoria de pares de palabras", "ru": "Память пар слов", "ar": "ذاكرة أزواج الكلمات", "pt": "Memória de pares de palavras", "it": "Memoria di coppie di parole" },
  "affix_factory": { "ja": "接辞工場", "ko": "접사 공장", "fr": "Fabrique d’affixes", "de": "Affix-Fabrik", "es": "Fábrica de afijos", "ru": "Фабрика аффиксов", "ar": "مصنع اللواحق", "pt": "Fábrica de afixos", "it": "Fabbrica di affissi" },
  "anagram_definition": { "ja": "定義アナグラム", "ko": "정의 애너그램", "fr": "Anagramme et définition", "de": "Definition-Anagramm", "es": "Anagrama con definición", "ru": "Анаграмма по определению", "ar": "أناغرام بالتعريف", "pt": "Anagrama com definição", "it": "Anagramma con definizione" },
  "category_fluency": { "ja": "カテゴリ流暢", "ko": "범주 유창성", "fr": "Fluence catégorielle", "de": "Kategorien-Flüssigkeit", "es": "Fluidez por categorías", "ru": "Беглость категорий", "ar": "طلاقة الفئات", "pt": "Fluência por categoria", "it": "Fluenza per categorie" },
  "chalk_and_talk": { "ja": "二重課題（書いて話す）", "ko": "이중 과제 (쓰며 말하기)", "fr": "Écrire et parler", "de": "Schreiben und Sprechen", "es": "Escribir y hablar", "ru": "Писать и говорить", "ar": "اكتب وتكلّم", "pt": "Escrever e falar", "it": "Scrivi e parla" },
  "chimp_test": { "ja": "チンパンジー検査", "ko": "침팬지 검사", "fr": "Test du chimpanzé", "de": "Schimpansen-Test", "es": "Test del chimpancé", "ru": "Тест шимпанзе", "ar": "اختبار الشمبانزي", "pt": "Teste do chimpanzé", "it": "Test dello scimpanzé" },
  "cognate_catch": { "ja": "同源語", "ko": "동원어", "fr": "Mots apparentés", "de": "Verwandte Wörter", "es": "Palabras afines", "ru": "Родственные слова", "ar": "كلمات متشابهة", "pt": "Palavras cognatas", "it": "Parole imparentate" },
  "consonant_reconstruct": { "ja": "子音の復元", "ko": "자음 복원", "fr": "Reconstruire les consonnes", "de": "Konsonanten rekonstruieren", "es": "Reconstruir consonantes", "ru": "Восстанови согласные", "ar": "استعادة الحروف", "pt": "Reconstruir consoantes", "it": "Ricostruisci le consonanti" },
  "context_clues": { "ja": "文脈の手がかり", "ko": "문맥 단서", "fr": "Indices du contexte", "de": "Kontexthinweise", "es": "Pistas del contexto", "ru": "Подсказки контекста", "ar": "قرائن السياق", "pt": "Pistas de contexto", "it": "Indizi dal contesto" },
  "conundrum_anagram": { "ja": "謎かけアナグラム", "ko": "수수께끼 애너그램", "fr": "Devinette anagramme", "de": "Rätsel-Anagramm", "es": "Acertijo anagrama", "ru": "Загадка-анаграмма", "ar": "أحجية أناغرام", "pt": "Charada anagrama", "it": "Indovinello anagramma" },
  "crossword": { "ja": "クロスワード", "ko": "십자말풀이", "fr": "Mots croisés", "de": "Kreuzworträtsel", "es": "Crucigrama", "ru": "Кроссворд", "ar": "الكلمات المتقاطعة", "pt": "Palavras cruzadas", "it": "Parole crociate" },
  "cryptogram": { "ja": "暗号文", "ko": "암호문", "fr": "Cryptogramme", "de": "Kryptogramm", "es": "Criptograma", "ru": "Криптограмма", "ar": "نص مشفّر", "pt": "Criptograma", "it": "Crittogramma" },
  "definition_dash": { "ja": "定義ダッシュ", "ko": "정의 스프린트", "fr": "Sprint de définitions", "de": "Definitions-Tempo", "es": "Sprint de definiciones", "ru": "Спринт определений", "ar": "سباق التعريفات", "pt": "Corrida de definições", "it": "Sprint di definizioni" },
  "etymology_origin": { "ja": "語源探し", "ko": "어원 탐구", "fr": "Origine des mots", "de": "Wortherkunft", "es": "Origen de las palabras", "ru": "Происхождение слов", "ar": "أصل الكلمات", "pt": "Origem das palavras", "it": "Origine delle parole" },
  "conjunction_search": { "ja": "結合特徴検索", "ko": "결합 특징 탐색", "fr": "Recherche conjonctive", "de": "Konjunktionssuche", "es": "Búsqueda conjuntiva", "ru": "Поиск по признакам", "ar": "بحث مقترن", "pt": "Busca conjuntiva", "it": "Ricerca congiunta" },
  "continuous_recognition": { "ja": "連続再認", "ko": "연속 재인", "fr": "Reconnaissance continue", "de": "Fortlaufendes Wiedererkennen", "es": "Reconocimiento continuo", "ru": "Непрерывное узнавание", "ar": "تعرّف متواصل", "pt": "Reconhecimento contínuo", "it": "Riconoscimento continuo" },
  "corsi_backward_span": { "ja": "逆順空間", "ko": "역순 공간", "fr": "Espace inversé", "de": "Räumlich rückwärts", "es": "Espacio inverso", "ru": "Пространство в обратном порядке", "ar": "فضاء معكوس", "pt": "Espaço inverso", "it": "Spazio inverso" },
  "corsi_blocks": { "ja": "空間スパン", "ko": "공간 폭", "fr": "Empan spatial", "de": "Raumspanne", "es": "Amplitud espacial", "ru": "Пространственный объём", "ar": "امتداد مكاني", "pt": "Amplitude espacial", "it": "Span spaziale" },
  "counting_span": { "ja": "計数スパン", "ko": "계수 폭", "fr": "Empan de comptage", "de": "Zählspanne", "es": "Amplitud de conteo", "ru": "Объём счёта", "ar": "امتداد العدّ", "pt": "Amplitude de contagem", "it": "Span di conteggio" },
  "d2_attention": { "ja": "d2 注意", "ko": "d2 주의", "fr": "Attention d2", "de": "d2-Aufmerksamkeit", "es": "Atención d2", "ru": "Тест d2", "ar": "انتباه d2", "pt": "Atenção d2", "it": "Attenzione d2" },
  "delayed_match_sample": { "ja": "遅延見本合わせ", "ko": "지연 표본 맞추기", "fr": "Appariement différé", "de": "Verzögerte Zuordnung", "es": "Emparejamiento diferido", "ru": "Отложенное сравнение", "ar": "مطابقة مؤجّلة", "pt": "Emparelhamento diferido", "it": "Accoppiamento differito" },
  "digit_span_reverse": { "ja": "逆唱数字", "ko": "숫자 거꾸로", "fr": "Chiffres à l’envers", "de": "Ziffern rückwärts", "es": "Dígitos al revés", "ru": "Цифры в обратном порядке", "ar": "أرقام معكوسة", "pt": "Dígitos invertidos", "it": "Cifre al contrario" },
  "divided_attention": { "ja": "分割注意", "ko": "분할 주의", "fr": "Attention divisée", "de": "Geteilte Aufmerksamkeit", "es": "Atención dividida", "ru": "Разделённое внимание", "ar": "انتباه مقسّم", "pt": "Atenção dividida", "it": "Attenzione divisa" },
  "dnms": { "ja": "非一致遅延", "ko": "비일치 지연", "fr": "Non-appariement différé", "de": "Verzögerte Nichtzuordnung", "es": "No emparejamiento diferido", "ru": "Отложенное несовпадение", "ar": "عدم تطابق مؤجّل", "pt": "Não emparelhamento diferido", "it": "Non accoppiamento differito" },
  "double_n_back": { "ja": "ダブル N-back", "ko": "이중 N-back", "fr": "Double N-back", "de": "Doppel-N-back", "es": "Doble N-back", "ru": "Двойной N-back", "ar": "N-back مزدوج", "pt": "N-back duplo", "it": "Doppio N-back" },
  "dual_coding": { "ja": "二重符号化", "ko": "이중 부호화", "fr": "Double codage", "de": "Duale Kodierung", "es": "Codificación dual", "ru": "Двойное кодирование", "ar": "ترميز مزدوج", "pt": "Codificação dupla", "it": "Doppia codifica" },
  "dual_task_memory": { "ja": "二重課題記憶", "ko": "이중 과제 기억", "fr": "Mémoire en double tâche", "de": "Doppelaufgaben-Gedächtnis", "es": "Memoria de doble tarea", "ru": "Память при двух задачах", "ar": "ذاكرة المهمة المزدوجة", "pt": "Memória de tarefa dupla", "it": "Memoria a doppio compito" },
  "dynamic_salience": { "ja": "動的顕著性", "ko": "동적 돌출", "fr": "Saillance dynamique", "de": "Dynamische Salienz", "es": "Saliencia dinámica", "ru": "Динамическая заметность", "ar": "بروز ديناميكي", "pt": "Saliência dinâmica", "it": "Salienza dinamica" },
  "event_timeline_memory": { "ja": "出来事の順序記憶", "ko": "사건 순서 기억", "fr": "Mémoire chronologique", "de": "Ereignis-Zeitachse", "es": "Memoria de la línea temporal", "ru": "Память о событиях", "ar": "ذاكرة الخط الزمني", "pt": "Memória da linha do tempo", "it": "Memoria della linea temporale" },
  "face_name_association": { "ja": "顔と名前", "ko": "얼굴과 이름", "fr": "Visages et noms", "de": "Gesicht und Name", "es": "Caras y nombres", "ru": "Лица и имена", "ar": "الوجوه والأسماء", "pt": "Rostos e nomes", "it": "Volti e nomi" },
  "face_trait_association": { "ja": "顔と特徴", "ko": "얼굴과 특징", "fr": "Visages et traits", "de": "Gesicht und Merkmal", "es": "Caras y rasgos", "ru": "Лица и черты", "ar": "الوجوه والسمات", "pt": "Rostos e traços", "it": "Volti e tratti" },
  "feature_matrix_recall": { "ja": "特徴行列", "ko": "특징 행렬", "fr": "Matrice de traits", "de": "Merkmalmatrix", "es": "Matriz de rasgos", "ru": "Матрица признаков", "ar": "مصفوفة السمات", "pt": "Matriz de traços", "it": "Matrice di tratti" },
  "feature_matrix_recall_all": { "ja": "特徴記憶", "ko": "특징 기억", "fr": "Mémoire des traits", "de": "Merkmalgedächtnis", "es": "Memoria de rasgos", "ru": "Память признаков", "ar": "ذاكرة السمات", "pt": "Memória de traços", "it": "Memoria dei tratti" },
  "flanker_test": { "ja": "フランカー課題", "ko": "플랭커 과제", "fr": "Tâche de flanker", "de": "Flanker-Aufgabe", "es": "Tarea de flanker", "ru": "Задача фланкеров", "ar": "مهمة فلانكر", "pt": "Tarefa de flanker", "it": "Compito di flanker" },
  "frequency_tap": { "ja": "リズムタップ", "ko": "리듬 탭", "fr": "Tap en rythme", "de": "Rhythmus-Tippen", "es": "Toque al ritmo", "ru": "Ритмичные нажатия", "ar": "نقر إيقاعي", "pt": "Toque no ritmo", "it": "Tocco a ritmo" },
  "ghost_tap": { "ja": "ゴーストタップ", "ko": "고스트 탭", "fr": "Tap fantôme", "de": "Geister-Tippen", "es": "Toque fantasma", "ru": "Нажатие призрака", "ar": "نقر شبح", "pt": "Toque fantasma", "it": "Tocco fantasma" },
  "go_no_go": { "ja": "ゴー・ノーゴー", "ko": "고/노고", "fr": "Go / No-Go", "de": "Go / No-Go", "es": "Go / No-Go", "ru": "Go / No-Go", "ar": "اذهب / توقف", "pt": "Go / No-Go", "it": "Go / No-Go" },
  "grocery_list": { "ja": "買い物リスト", "ko": "장보기 목록", "fr": "Liste de courses", "de": "Einkaufsliste", "es": "Lista de la compra", "ru": "Список покупок", "ar": "قائمة التسوّق", "pt": "Lista de compras", "it": "Lista della spesa" },
  "mandala_recall": { "ja": "マンダラ記憶", "ko": "만다라 기억", "fr": "Mémoire mandala", "de": "Mandala-Gedächtnis", "es": "Memoria mandala", "ru": "Память мандалы", "ar": "ذاكرة الماندالا", "pt": "Memória mandala", "it": "Memoria mandala" },
  "memory_matrix": { "ja": "記憶マトリクス", "ko": "기억 행렬", "fr": "Matrice mémoire", "de": "Gedächtnismatrix", "es": "Matriz de memoria", "ru": "Матрица памяти", "ar": "مصفوفة الذاكرة", "pt": "Matriz de memória", "it": "Matrice di memoria" },
  "memory_palace": { "ja": "記憶の宮殿", "ko": "기억의 궁전", "fr": "Palais de mémoire", "de": "Gedächtnispalast", "es": "Palacio de la memoria", "ru": "Дворец памяти", "ar": "قصر الذاكرة", "pt": "Palácio da memória", "it": "Palazzo della memoria" },
  "multiple_object_tracking": { "ja": "多重対象追跡", "ko": "다중 물체 추적", "fr": "Suivi multi-objets", "de": "Multipel-Objekt-Verfolgung", "es": "Seguimiento múltiple", "ru": "Слежение за объектами", "ar": "تتبّع أهداف متعددة", "pt": "Rastreio de múltiplos objetos", "it": "Tracciamento multiplo" },
  "n_back": { "ja": "N-back", "ko": "N-back", "fr": "N-back", "de": "N-back", "es": "N-back", "ru": "N-back", "ar": "N-back", "pt": "N-back", "it": "N-back" },
  "narrative_recall": { "ja": "物語の記憶", "ko": "이야기 기억", "fr": "Mémoire du récit", "de": "Geschichte erinnern", "es": "Memoria del relato", "ru": "Память рассказа", "ar": "ذاكرة السرد", "pt": "Memória da narrativa", "it": "Memoria del racconto" },
  "negative_space_detection": { "ja": "ネガティブスペース", "ko": "네거티브 스페이스", "fr": "Espace négatif", "de": "Negativraum", "es": "Espacio negativo", "ru": "Негативное пространство", "ar": "الفراغ السلبي", "pt": "Espaço negativo", "it": "Spazio negativo" },
  "object_displacement": { "ja": "物体の移動", "ko": "물체 이동", "fr": "Déplacement d’objets", "de": "Objektverschiebung", "es": "Desplazamiento de objetos", "ru": "Смещение объектов", "ar": "إزاحة الأجسام", "pt": "Deslocamento de objetos", "it": "Spostamento di oggetti" },
  "object_shuffle": { "ja": "物体の入れ替え", "ko": "물체 바꿔치기", "fr": "Mélange d’objets", "de": "Objekt-Tausch", "es": "Mezcla de objetos", "ru": "Перестановка объектов", "ar": "خلط الأجسام", "pt": "Troca de objetos", "it": "Scambio di oggetti" },
  "odd_even_flash": { "ja": "奇数偶数フラッシュ", "ko": "홀짝 플래시", "fr": "Pair ou impair", "de": "Gerade oder ungerade", "es": "Par o impar", "ru": "Чёт или нечет", "ar": "زوجي أم فردي", "pt": "Par ou ímpar", "it": "Pari o dispari" },
  "operation_span": { "ja": "演算スパン", "ko": "연산 폭", "fr": "Empan d’opérations", "de": "Rechenspanne", "es": "Amplitud de operaciones", "ru": "Объём вычислений", "ar": "امتداد العمليات", "pt": "Amplitude de operações", "it": "Span di operazioni" },
  "peripheral_focus": { "ja": "周辺視野", "ko": "주변 시야", "fr": "Vision périphérique", "de": "Peripheres Sehen", "es": "Visión periférica", "ru": "Периферийное зрение", "ar": "الرؤية المحيطية", "pt": "Visão periférica", "it": "Visione periferica" },
  "posner_spatial_cueing": { "ja": "空間手がかり", "ko": "공간 단서", "fr": "Indiçage spatial", "de": "Räumlicher Hinweisreiz", "es": "Señalización espacial", "ru": "Пространственная подсказка", "ar": "إشارة مكانية", "pt": "Pista espacial", "it": "Indizio spaziale" },
  "probe_digit_span": { "ja": "数字プローブ", "ko": "숫자 프로브", "fr": "Sonde de chiffres", "de": "Ziffernsonde", "es": "Sonda de dígitos", "ru": "Цифровой зонд", "ar": "مسبار الأرقام", "pt": "Sonda de dígitos", "it": "Sonda di cifre" },
  "reading_span": { "ja": "読解スパン", "ko": "읽기 폭", "fr": "Empan de lecture", "de": "Lesespanne", "es": "Amplitud de lectura", "ru": "Объём чтения", "ar": "امتداد القراءة", "pt": "Amplitude de leitura", "it": "Span di lettura" },
  "reflex_tap": { "ja": "反応タップ", "ko": "반사 탭", "fr": "Tap réflexe", "de": "Reflex-Tippen", "es": "Toque reflejo", "ru": "Нажатие на реакцию", "ar": "نقر انعكاسي", "pt": "Toque reflexo", "it": "Tocco rapido" },
  "matrix_multiplier": { "ja": "行列の積", "ko": "행렬 곱셈", "fr": "Produit matriciel", "de": "Matrixmultiplikation", "es": "Producto de matrices", "ru": "Умножение матриц", "ar": "ضرب المصفوفات", "pt": "Produto de matrizes", "it": "Prodotto di matrici" },
  "matrix_multiplier_match": { "ja": "行列の積合わせ", "ko": "행렬 곱 짝맞추기", "fr": "Paires de produits matriciels", "de": "Matrixprodukt-Paare", "es": "Parejas de productos", "ru": "Пары произведений матриц", "ar": "مطابقة ضرب المصفوفات", "pt": "Pares de produtos", "it": "Coppie di prodotti" },
  "matrix_reasoning": { "ja": "行列推理", "ko": "행렬 추론", "fr": "Raisonnement matriciel", "de": "Matrix-Logik", "es": "Razonamiento matricial", "ru": "Матричная логика", "ar": "استدلال المصفوفات", "pt": "Raciocínio matricial", "it": "Ragionamento matriciale" },
  "mental_abacus": { "ja": "暗算そろばん", "ko": "암산 주판", "fr": "Boulier mental", "de": "Kopfrechnen-Abakus", "es": "Ábaco mental", "ru": "Ментальный абак", "ar": "المعداد الذهني", "pt": "Ábaco mental", "it": "Abaco mentale" },
  "mental_calendar": { "ja": "暗算カレンダー", "ko": "암산 달력", "fr": "Calendrier mental", "de": "Kalender-Kopfrechnen", "es": "Calendario mental", "ru": "Ментальный календарь", "ar": "التقويم الذهني", "pt": "Calendário mental", "it": "Calendario mentale" },
  "missing_operator": { "ja": "演算子当て", "ko": "연산자 찾기", "fr": "Opérateur manquant", "de": "Fehlender Operator", "es": "Operador que falta", "ru": "Пропущенный знак", "ar": "العملية الناقصة", "pt": "Operador que falta", "it": "Operatore mancante" },
  "modular_clock_arithmetic": { "ja": "時計の合同算術", "ko": "시계 모듈러 연산", "fr": "Arithmétique modulaire horloge", "de": "Modulare Uhr-Arithmetik", "es": "Aritmética modular de reloj", "ru": "Модульная арифметика часов", "ar": "حساب الساعة المعياري", "pt": "Aritmética modular de relógio", "it": "Aritmetica modulare dell’orologio" },
  "modulo_clock": { "ja": "モジュロ時計", "ko": "모듈로 시계", "fr": "Horloge modulo", "de": "Modulo-Uhr", "es": "Reloj módulo", "ru": "Часы по модулю", "ar": "ساعة معيارية", "pt": "Relógio módulo", "it": "Orologio modulo" },
  "modulo_path": { "ja": "モジュロ経路", "ko": "모듈로 경로", "fr": "Chemin modulo", "de": "Modulo-Pfad", "es": "Camino módulo", "ru": "Путь по модулю", "ar": "مسار معياري", "pt": "Caminho módulo", "it": "Percorso modulo" },
  "number_bonds": { "ja": "数の分解", "ko": "수 분해", "fr": "Décomposition de nombres", "de": "Zahlzerlegung", "es": "Descomposición numérica", "ru": "Разложение числа", "ar": "تفكيك الأعداد", "pt": "Decomposição numérica", "it": "Scomposizione numerica" },
  "number_bonds_all": { "ja": "数の分解・練習", "ko": "수 분해 연습", "fr": "Décomposition avancée", "de": "Zahlzerlegung Profi", "es": "Descomposición avanzada", "ru": "Разложение: практика", "ar": "تفكيك متقدّم", "pt": "Decomposição avançada", "it": "Scomposizione avanzata" },
  "numerical_estimation": { "ja": "数値推定", "ko": "수치 어림", "fr": "Estimation numérique", "de": "Zahlen schätzen", "es": "Estimación numérica", "ru": "Оценка чисел", "ar": "تقدير رقمي", "pt": "Estimativa numérica", "it": "Stima numerica" },
  "pattern_sequence_draw": { "ja": "規則で描く", "ko": "규칙 그리기", "fr": "Dessine la suite", "de": "Muster zeichnen", "es": "Dibuja el patrón", "ru": "Нарисуй узор", "ar": "ارسم النمط", "pt": "Desenhe o padrão", "it": "Disegna lo schema" },
  "percentage_peak": { "ja": "パーセント頂上", "ko": "퍼센트 정상", "fr": "Sommet des pourcentages", "de": "Prozent-Gipfel", "es": "Cumbre de porcentajes", "ru": "Пик процентов", "ar": "قمة النسب", "pt": "Pico de porcentagens", "it": "Vetta delle percentuali" },
  "percentage_shopping": { "ja": "割引ショッピング", "ko": "할인 쇼핑", "fr": "Courses en solde", "de": "Rabatt-Einkauf", "es": "Compras con descuento", "ru": "Покупки со скидкой", "ar": "تسوّق بخصم", "pt": "Compras com desconto", "it": "Shopping scontato" },
  "prime_factor_trees": { "ja": "素因数分解の木", "ko": "소인수분해 나무", "fr": "Arbre de facteurs premiers", "de": "Primfaktorbaum", "es": "Árbol de factores primos", "ru": "Дерево простых множителей", "ar": "شجرة العوامل الأولية", "pt": "Árvore de fatores primos", "it": "Albero dei fattori primi" },
  "prime_gap_hunt": { "ja": "素数の間隔", "ko": "소수 간격", "fr": "Écart entre premiers", "de": "Primzahllücken", "es": "Brecha entre primos", "ru": "Разрыв простых чисел", "ar": "فجوة الأعداد الأولية", "pt": "Intervalo entre primos", "it": "Divario tra primi" },
  "prime_hunter": { "ja": "素数ハンター", "ko": "소수 사냥꾼", "fr": "Chasseur de premiers", "de": "Primzahljäger", "es": "Cazador de primos", "ru": "Охотник за простыми", "ar": "صيّاد الأعداد الأولية", "pt": "Caçador de primos", "it": "Cacciatore di primi" },
  "pythagorean_triple_builder": { "ja": "ピタゴラス数", "ko": "피타고라스 수", "fr": "Triplets pythagoriciens", "de": "Pythagoräische Tripel", "es": "Ternas pitagóricas", "ru": "Пифагоровы тройки", "ar": "ثلاثيات فيثاغورس", "pt": "Ternos pitagóricos", "it": "Terne pitagoriche" },
  "quick_math": { "ja": "速算", "ko": "속산", "fr": "Calcul rapide", "de": "Schnellrechnen", "es": "Cálculo rápido", "ru": "Быстрый счёт", "ar": "حساب سريع", "pt": "Cálculo rápido", "it": "Calcolo rapido" },
  "radical_roots": { "ja": "根号の簡約", "ko": "근호 간단히", "fr": "Simplifier les radicaux", "de": "Wurzeln vereinfachen", "es": "Simplificar radicales", "ru": "Упростить корни", "ar": "تبسيط الجذور", "pt": "Simplificar radicais", "it": "Semplifica i radicali" },
  "roman_arithmetic": { "ja": "ローマ数字の計算", "ko": "로마 숫자 연산", "fr": "Calcul romain", "de": "Römisch rechnen", "es": "Aritmética romana", "ru": "Римская арифметика", "ar": "حساب روماني", "pt": "Aritmética romana", "it": "Aritmetica romana" },
  "sequence_sleuth": { "ja": "数列探偵", "ko": "수열 탐정", "fr": "Détective de suites", "de": "Zahlenfolgen-Detektiv", "es": "Detective de series", "ru": "Детектив последовательностей", "ar": "محقّق المتتاليات", "pt": "Detetive de sequências", "it": "Detective di sequenze" },
  "sequence_stack": { "ja": "数列スタック", "ko": "수열 쌓기", "fr": "Pile de suites", "de": "Folgenstapel", "es": "Pila de series", "ru": "Стек последовательностей", "ar": "مكدّس المتتاليات", "pt": "Pilha de sequências", "it": "Pila di sequenze" },
  "set_theory_venn": { "ja": "ベン図", "ko": "벤 다이어그램", "fr": "Diagramme de Venn", "de": "Venn-Diagramm", "es": "Diagrama de Venn", "ru": "Диаграмма Венна", "ar": "مخطط فن", "pt": "Diagrama de Venn", "it": "Diagramma di Venn" },
  "sum_pyramid": { "ja": "数字ピラミッド", "ko": "숫자 피라미드", "fr": "Pyramide de nombres", "de": "Zahlenpyramide", "es": "Pirámide numérica", "ru": "Числовая пирамида", "ar": "هرم الأرقام", "pt": "Pirâmide numérica", "it": "Piramide numerica" },
  "target_10": { "ja": "10 を作れ", "ko": "10 만들기", "fr": "Faire 10", "de": "Ziel 10", "es": "Hacer 10", "ru": "Собери 10", "ar": "اصنع 10", "pt": "Faça 10", "it": "Fai 10" },
  "target_number": { "ja": "目標の数", "ko": "목표 숫자", "fr": "Nombre cible", "de": "Zielzahl", "es": "Número objetivo", "ru": "Целевое число", "ar": "العدد الهدف", "pt": "Número alvo", "it": "Numero bersaglio" },
  "unit_converter_pro": { "ja": "単位換算", "ko": "단위 변환", "fr": "Conversion d’unités", "de": "Einheiten umrechnen", "es": "Conversión de unidades", "ru": "Перевод единиц", "ar": "تحويل الوحدات", "pt": "Conversão de unidades", "it": "Conversione di unità" },
  "vector_dot_product": { "ja": "ベクトルの内積", "ko": "벡터 내적", "fr": "Produit scalaire", "de": "Skalarprodukt", "es": "Producto escalar", "ru": "Скалярное произведение", "ar": "الضرب القياسي", "pt": "Produto escalar", "it": "Prodotto scalare" },
  "vector_grid_alignment": { "ja": "ベクトル整列", "ko": "벡터 정렬", "fr": "Alignement de vecteurs", "de": "Vektor-Ausrichtung", "es": "Alineación de vectores", "ru": "Выравнивание векторов", "ar": "محاذاة المتجهات", "pt": "Alinhamento de vetores", "it": "Allineamento di vettori" },
  "vektor_vector": { "ja": "ベクトル演算", "ko": "벡터 연산", "fr": "Opérations vectorielles", "de": "Vektorrechnung", "es": "Operaciones vectoriales", "ru": "Действия с векторами", "ar": "عمليات المتجهات", "pt": "Operações vetoriais", "it": "Operazioni vettoriali" },
  "venn_numbers": { "ja": "数入りベン図", "ko": "숫자 벤 다이어그램", "fr": "Venn numérique", "de": "Zahlen-Venn", "es": "Venn numérico", "ru": "Числовая диаграмма Венна", "ar": "فن رقمي", "pt": "Venn numérico", "it": "Venn numerico" },
  "associative_pairs": { "ja": "連想ペア", "ko": "연상 짝", "fr": "Paires associatives", "de": "Assoziationspaare", "es": "Parejas asociativas", "ru": "Ассоциативные пары", "ar": "أزواج ترابطية", "pt": "Pares associativos", "it": "Coppie associative" },
  "attentional_blink": { "ja": "注意の瞬き", "ko": "주의 깜박임", "fr": "Clignement attentionnel", "de": "Aufmerksamkeitsblinzeln", "es": "Parpadeo atencional", "ru": "Внимание-мигание", "ar": "الوميض الانتباهي", "pt": "Piscar atencional", "it": "Blink attentivo" },
  "attentional_blink_probe": { "ja": "注意の瞬き・探査", "ko": "주의 깜박임 심화", "fr": "Clignement avancé", "de": "Aufmerksamkeitsblinzeln Profi", "es": "Parpadeo avanzado", "ru": "Внимание-мигание: проба", "ar": "وميض متقدّم", "pt": "Piscar avançado", "it": "Blink avanzato" },
  "card_counting_memory": { "ja": "カード記憶", "ko": "카드 기억", "fr": "Mémoire des cartes", "de": "Kartenzählen", "es": "Memoria de cartas", "ru": "Память на карты", "ar": "ذاكرة البطاقات", "pt": "Memória de cartas", "it": "Memoria delle carte" },
  "change_blindness": { "ja": "変化の見落とし", "ko": "변화 맹시", "fr": "Cécité au changement", "de": "Veränderungsblindheit", "es": "Ceguera al cambio", "ru": "Слепота к изменениям", "ar": "عمى التغيّر", "pt": "Cegueira de mudança", "it": "Cecità al cambiamento" },
  "choice_reaction_time": { "ja": "選択反応", "ko": "선택 반응", "fr": "Temps de réaction", "de": "Reaktionszeit", "es": "Tiempo de reacción", "ru": "Время реакции", "ar": "زمن رد الفعل", "pt": "Tempo de reação", "it": "Tempo di reazione" },
  "color_word_match_up": { "ja": "色と語のマッチ", "ko": "색과 단어 맞추기", "fr": "Couleur et mot", "de": "Farbe und Wort", "es": "Color y palabra", "ru": "Цвет и слово", "ar": "اللون والكلمة", "pt": "Cor e palavra", "it": "Colore e parola" },
  "path_intersect": { "ja": "経路クロス", "ko": "경로 교차", "fr": "Chemins croisés", "de": "Wege kreuzen", "es": "Caminos cruzados", "ru": "Пересечение путей", "ar": "تقاطع المسارات", "pt": "Caminhos cruzados", "it": "Percorsi incrociati" },
  "pipes": { "ja": "パイプ", "ko": "파이프", "fr": "Tuyaux", "de": "Rohre", "es": "Tuberías", "ru": "Трубы", "ar": "أنابيب", "pt": "Tubos", "it": "Tubi" },
  "shikaku": { "ja": "四角に切れ", "ko": "시카쿠", "fr": "Shikaku", "de": "Shikaku", "es": "Shikaku", "ru": "Шикаку", "ar": "شيكاكو", "pt": "Shikaku", "it": "Shikaku" },
  "skyscrapers": { "ja": "摩天楼", "ko": "마천루", "fr": "Gratte-ciel", "de": "Wolkenkratzer", "es": "Rascacielos", "ru": "Небоскрёбы", "ar": "ناطحات السحاب", "pt": "Arranha-céus", "it": "Grattacieli" },
  "slide_puzzle": { "ja": "スライドパズル", "ko": "슬라이드 퍼즐", "fr": "Taquin", "de": "Schiebepuzzle", "es": "Rompecabezas", "ru": "Пятнашки", "ar": "الأحجية المنزلقة", "pt": "Quebra-cabeça", "it": "Gioco del 15" },
  "slitherlink": { "ja": "スリザーリンク", "ko": "슬리더링크", "fr": "Slitherlink", "de": "Slitherlink", "es": "Slitherlink", "ru": "Слизерлинк", "ar": "سليذرلينك", "pt": "Slitherlink", "it": "Slitherlink" },
  "sudoku": { "ja": "数独", "ko": "스도쿠", "fr": "Sudoku", "de": "Sudoku", "es": "Sudoku", "ru": "Судоку", "ar": "سودوكو", "pt": "Sudoku", "it": "Sudoku" },
  "sum_snake": { "ja": "サムスネーク", "ko": "섬 스네이크", "fr": "Serpent somme", "de": "Summenschlange", "es": "Serpiente suma", "ru": "Змейка-сумма", "ar": "ثعبان المجموع", "pt": "Cobra soma", "it": "Serpente somma" },
  "tangle_fix": { "ja": "もつれ解き", "ko": "엉킴 풀기", "fr": "Démêler", "de": "Entwirren", "es": "Desenredar", "ru": "Распутать", "ar": "فك التشابك", "pt": "Desembaralhar", "it": "Districare" },
  "tapa": { "ja": "タパ", "ko": "타파", "fr": "Tapa", "de": "Tapa", "es": "Tapa", "ru": "Тапа", "ar": "تابا", "pt": "Tapa", "it": "Tapa" },
  "tenner_grid": { "ja": "テナーグリッド", "ko": "테너 그리드", "fr": "Grille de dix", "de": "Zehner-Gitter", "es": "Rejilla de diez", "ru": "Сетка десятки", "ar": "شبكة العشرة", "pt": "Grade de dez", "it": "Griglia del dieci" },
  "tents_and_trees": { "ja": "テントと木", "ko": "텐트와 나무", "fr": "Tentes et arbres", "de": "Zelte und Bäume", "es": "Tiendas y árboles", "ru": "Палатки и деревья", "ar": "خيام وأشجار", "pt": "Tendas e árvores", "it": "Tende e alberi" },
  "water_sort": { "ja": "ウォーターソート", "ko": "워터 정렬", "fr": "Tri d’eau", "de": "Wassersortieren", "es": "Clasificación de agua", "ru": "Сортировка воды", "ar": "فرز الماء", "pt": "Classificação de água", "it": "Ordina l’acqua" },
  "yajilin": { "ja": "ヤジリン", "ko": "야지린", "fr": "Yajilin", "de": "Yajilin", "es": "Yajilin", "ru": "Яджилин", "ar": "ياجيلين", "pt": "Yajilin", "it": "Yajilin" },
  "algebraic_balance": { "ja": "代数天秤", "ko": "대수 저울", "fr": "Balance algébrique", "de": "Algebra-Waage", "es": "Balanza algebraica", "ru": "Алгебраические весы", "ar": "ميزان جبري", "pt": "Balança algébrica", "it": "Bilancia algebrica" },
  "algebraic_inequality_solver": { "ja": "不等式を解く", "ko": "부등식 풀기", "fr": "Résoudre l’inégalité", "de": "Ungleichung lösen", "es": "Resolver la inecuación", "ru": "Решить неравенство", "ar": "حلّ المتباينة", "pt": "Resolver a inequação", "it": "Risolvi la disuguaglianza" },
  "arithmetic_chain": { "ja": "計算チェーン", "ko": "연산 체인", "fr": "Chaîne arithmétique", "de": "Rechenkette", "es": "Cadena aritmética", "ru": "Арифметическая цепь", "ar": "سلسلة حسابية", "pt": "Cadeia aritmética", "it": "Catena aritmetica" },
  "balance_scale": { "ja": "天秤量り", "ko": "저울질", "fr": "Balance", "de": "Waage", "es": "Balanza", "ru": "Весы", "ar": "ميزان", "pt": "Balança", "it": "Bilancia" },
  "base_conversion_run": { "ja": "基数変換", "ko": "진법 변환", "fr": "Conversion de base", "de": "Basisumrechnung", "es": "Conversión de base", "ru": "Перевод систем", "ar": "تحويل الأساس", "pt": "Conversão de base", "it": "Conversione di base" },
  "base_shift": { "ja": "基数シフト", "ko": "진법 시프트", "fr": "Décalage de base", "de": "Basis-Verschiebung", "es": "Desplazamiento de base", "ru": "Сдвиг основания", "ar": "إزاحة الأساس", "pt": "Deslocamento de base", "it": "Spostamento di base" },
  "binary_code": { "ja": "バイナリコード", "ko": "이진 코드", "fr": "Code binaire", "de": "Binärcode", "es": "Código binario", "ru": "Двоичный код", "ar": "الرمز الثنائي", "pt": "Código binário", "it": "Codice binario" },
  "binary_matrix_rank": { "ja": "行列の階数", "ko": "행렬 계수", "fr": "Rang matriciel", "de": "Matrixrang", "es": "Rango matricial", "ru": "Ранг матрицы", "ar": "رتبة المصفوفة", "pt": "Posto da matriz", "it": "Rango di matrice" },
  "binary_scale_balance": { "ja": "二進天秤", "ko": "이진 저울", "fr": "Balance binaire", "de": "Binärwaage", "es": "Balanza binaria", "ru": "Двоичные весы", "ar": "ميزان ثنائي", "pt": "Balança binária", "it": "Bilancia binaria" },
  "binomial_match": { "ja": "二項式合わせ", "ko": "이항식 짝맞추기", "fr": "Paires binomiales", "de": "Binome paaren", "es": "Parejas binomiales", "ru": "Биномы в пары", "ar": "مطابقة ذات الحدين", "pt": "Pares binomiais", "it": "Coppie binomiali" },
  "calculation_sprint": { "ja": "計算ダッシュ", "ko": "계산 스프린트", "fr": "Sprint de calcul", "de": "Rechentempo", "es": "Sprint de cálculo", "ru": "Спринт счёта", "ar": "سباق الحساب", "pt": "Corrida de cálculo", "it": "Sprint di calcolo" },
  "collatz": { "ja": "コラッツ", "ko": "콜라츠", "fr": "Collatz", "de": "Collatz", "es": "Collatz", "ru": "Коллатц", "ar": "كولاتز", "pt": "Collatz", "it": "Collatz" },
  "common_denominator": { "ja": "通分", "ko": "통분", "fr": "Dénominateur commun", "de": "Hauptnenner", "es": "Denominador común", "ru": "Общий знаменатель", "ar": "المقام المشترك", "pt": "Denominador comum", "it": "Denominatore comune" },
  "countdown_math": { "ja": "カウントダウン計算", "ko": "카운트다운 계산", "fr": "Calcul compte à rebours", "de": "Countdown-Rechnen", "es": "Cálculo de cuenta atrás", "ru": "Обратный счёт", "ar": "حساب العد التنازلي", "pt": "Cálculo regressivo", "it": "Calcolo a tempo" },
  "crypto_arithmetic": { "ja": "字母算术", "ko": "문자 산술", "fr": "Arithmétique des lettres", "de": "Buchstabenrechnung", "es": "Aritmética de letras", "ru": "Буквенная арифметика", "ar": "حساب الحروف", "pt": "Aritmética de letras", "it": "Aritmetica delle lettere" },
  "digit_swap_eq": { "ja": "数字入れ替え", "ko": "숫자 바꾸기", "fr": "Échange de chiffres", "de": "Zifferntausch", "es": "Cambio de dígitos", "ru": "Перестановка цифр", "ar": "تبديل الأرقام", "pt": "Troca de dígitos", "it": "Scambio di cifre" },
  "divisibility_dash": { "ja": "整除ダッシュ", "ko": "배수 스프린트", "fr": "Sprint de divisibilité", "de": "Teilbarkeits-Tempo", "es": "Sprint de divisibilidad", "ru": "Спринт делимости", "ar": "سباق القسمة", "pt": "Corrida de divisibilidade", "it": "Sprint di divisibilità" },
  "exponent_tower": { "ja": "指数タワー", "ko": "지수 탑", "fr": "Tour d’exposants", "de": "Exponententurm", "es": "Torre de exponentes", "ru": "Башня степеней", "ar": "برج الأسس", "pt": "Torre de expoentes", "it": "Torre di esponenti" },
  "factor_finder": { "ja": "約数を探せ", "ko": "약수 찾기", "fr": "Trouve les diviseurs", "de": "Teiler finden", "es": "Busca los divisores", "ru": "Найди делители", "ar": "ابحث عن القواسم", "pt": "Ache os divisores", "it": "Trova i divisori" },
  "fibonacci_merge": { "ja": "フィボナッチ合体", "ko": "피보나치 합치기", "fr": "Fusion Fibonacci", "de": "Fibonacci-Verschmelzung", "es": "Fusión Fibonacci", "ru": "Слияние Фибоначчи", "ar": "دمج فيبوناتشي", "pt": "Fusão Fibonacci", "it": "Fusione Fibonacci" },
  "fraction_match": { "ja": "分数合わせ", "ko": "분수 짝맞추기", "fr": "Paires de fractions", "de": "Bruchpaare", "es": "Parejas de fracciones", "ru": "Пары дробей", "ar": "مطابقة الكسور", "pt": "Pares de frações", "it": "Coppie di frazioni" },
  "fraction_matcher": { "ja": "分数マッチ", "ko": "분수 매칭", "fr": "Association de fractions", "de": "Brüche zuordnen", "es": "Asocia fracciones", "ru": "Сопоставь дроби", "ar": "طابق الكسور", "pt": "Combine frações", "it": "Abbina le frazioni" },
  "fractional_pizza": { "ja": "分数ピザ", "ko": "분수 피자", "fr": "Pizza en fractions", "de": "Bruch-Pizza", "es": "Pizza fraccionaria", "ru": "Дробная пицца", "ar": "بيتزا الكسور", "pt": "Pizza fracionária", "it": "Pizza frazionaria" },
  "inequality_balance_ops": { "ja": "不等式天秤", "ko": "부등식 저울", "fr": "Balance d’inégalités", "de": "Ungleichungs-Waage", "es": "Balanza de inecuaciones", "ru": "Весы неравенств", "ar": "ميزان المتباينات", "pt": "Balança de inequações", "it": "Bilancia di disuguaglianze" },
  "inequality_dash": { "ja": "不等式ダッシュ", "ko": "부등식 스프린트", "fr": "Sprint d’inégalités", "de": "Ungleichungs-Tempo", "es": "Sprint de inecuaciones", "ru": "Спринт неравенств", "ar": "سباق المتباينات", "pt": "Corrida de inequações", "it": "Sprint di disuguaglianze" },
  "magic_squares": { "ja": "魔方陣", "ko": "마방진", "fr": "Carrés magiques", "de": "Magische Quadrate", "es": "Cuadrados mágicos", "ru": "Магические квадраты", "ar": "المربعات السحرية", "pt": "Quadrados mágicos", "it": "Quadrati magici" },
  "g2048": { "ja": "2048", "ko": "2048", "fr": "2048", "de": "2048", "es": "2048", "ru": "2048", "ar": "2048", "pt": "2048", "it": "2048" },
  "life_game": { "ja": "ライフゲーム", "ko": "라이프 게임", "fr": "Jeu de la vie", "de": "Game of Life", "es": "Juego de la vida", "ru": "Игра «Жизнь»", "ar": "لعبة الحياة", "pt": "Jogo da Vida", "it": "Gioco della vita" },
  "sieve_visualizer": { "ja": "篩の可視化", "ko": "체 시각화", "fr": "Crible visuel", "de": "Sieb-Visualisierung", "es": "Criba visual", "ru": "Визуализация решета", "ar": "غربال مرئي", "pt": "Crivo visual", "it": "Crivello visivo" },
  "snake_3d": { "ja": "3D スネーク", "ko": "3D 스네이크", "fr": "Serpent 3D", "de": "Snake 3D", "es": "Serpiente 3D", "ru": "Змейка 3D", "ar": "الثعبان 3D", "pt": "Cobrinha 3D", "it": "Snake 3D" },
  "sorting_visualizer": { "ja": "ソート可視化", "ko": "정렬 시각화", "fr": "Tri visuel", "de": "Sortier-Visualisierung", "es": "Ordenación visual", "ru": "Визуализация сортировки", "ar": "فرز مرئي", "pt": "Ordenação visual", "it": "Ordinamento visivo" },
  "spider_solitaire": { "ja": "スパイダー", "ko": "스파이더 카드놀이", "fr": "Spider", "de": "Spider", "es": "Spider", "ru": "Паук", "ar": "سبايدر", "pt": "Spider", "it": "Spider" },
  "sudoku_hex": { "ja": "6×6 数独", "ko": "6×6 스도쿠", "fr": "Sudoku 6×6", "de": "Sudoku 6×6", "es": "Sudoku 6×6", "ru": "Судоку 6×6", "ar": "سودوكو 6×6", "pt": "Sudoku 6×6", "it": "Sudoku 6×6" },
  "tetris": { "ja": "テトリス", "ko": "테트리스", "fr": "Tetris", "de": "Tetris", "es": "Tetris", "ru": "Тетрис", "ar": "تتريس", "pt": "Tetris", "it": "Tetris" },
  "tic_tac_toe": { "ja": "三目並べ", "ko": "틱택토", "fr": "Morpion", "de": "Tic-Tac-Toe", "es": "Tres en línea", "ru": "Крестики-нолики", "ar": "إكس-أو", "pt": "Jogo da velha", "it": "Tris" },
  "wordle": { "ja": "単語当て", "ko": "단어 맞추기", "fr": "Devine le mot", "de": "Wort raten", "es": "Adivina la palabra", "ru": "Угадай слово", "ar": "خمّن الكلمة", "pt": "Adivinhe a palavra", "it": "Indovina la parola" },
  "akari": { "ja": "美術館", "ko": "아카리", "fr": "Akari", "de": "Akari", "es": "Akari", "ru": "Акари", "ar": "أكاري", "pt": "Akari", "it": "Akari" },
  "alphabet_sudoku": { "ja": "アルファベット数独", "ko": "알파벳 스도쿠", "fr": "Sudoku lettres", "de": "Buchstaben-Sudoku", "es": "Sudoku de letras", "ru": "Судоку с буквами", "ar": "سودوكو الحروف", "pt": "Sudoku de letras", "it": "Sudoku di lettere" },
  "binary_puzzle": { "ja": "バイナリ", "ko": "바이너리", "fr": "Binaire", "de": "Binär", "es": "Binario", "ru": "Бинарная", "ar": "ثنائي", "pt": "Binário", "it": "Binario" },
  "block_escape": { "ja": "ブロック脱出", "ko": "블록 탈출", "fr": "Évasion de blocs", "de": "Block-Ausbruch", "es": "Escape de bloques", "ru": "Побег блока", "ar": "هروب الكتلة", "pt": "Fuga do bloco", "it": "Fuga a blocchi" },
  "bridges": { "ja": "橋をかけろ", "ko": "다리 놓기", "fr": "Ponts", "de": "Brücken", "es": "Puentes", "ru": "Мосты", "ar": "الجسور", "pt": "Pontes", "it": "Ponti" },
  "bridges_all": { "ja": "橋をかけろ・上級", "ko": "다리 놓기 심화", "fr": "Ponts avancés", "de": "Brücken Profi", "es": "Puentes avanzados", "ru": "Мосты: сложные", "ar": "جسور متقدّمة", "pt": "Pontes avançadas", "it": "Ponti avanzati" },
  "color_flood": { "ja": "フラッドフィル", "ko": "컬러 플러드", "fr": "Inondation de couleur", "de": "Farbflut", "es": "Inundación de color", "ru": "Цветовой поток", "ar": "فيضان الألوان", "pt": "Inundação de cor", "it": "Inondazione di colore" },
  "crown": { "ja": "クラウン", "ko": "크라운", "fr": "Couronnes", "de": "Kronen", "es": "Coronas", "ru": "Короны", "ar": "التيجان", "pt": "Coroas", "it": "Corone" },
  "dominosa": { "ja": "ドミノサ", "ko": "도미노사", "fr": "Dominosa", "de": "Dominosa", "es": "Dominosa", "ru": "Доминоса", "ar": "دومينوسا", "pt": "Dominosa", "it": "Dominosa" },
  "fillomino": { "ja": "フィルオミノ", "ko": "필로미노", "fr": "Fillomino", "de": "Fillomino", "es": "Fillomino", "ru": "Филломино", "ar": "فيلومينو", "pt": "Fillomino", "it": "Fillomino" },
  "futoshiki": { "ja": "不等式", "ko": "부등호", "fr": "Futoshiki", "de": "Futoshiki", "es": "Futoshiki", "ru": "Футошики", "ar": "فوتوشيكي", "pt": "Futoshiki", "it": "Futoshiki" },
  "gokigen_naname": { "ja": "スリザーリンク", "ko": "슬리더링크", "fr": "Slitherlink", "de": "Slitherlink", "es": "Slitherlink", "ru": "Слизерлинк", "ar": "سليذرلينك", "pt": "Slitherlink", "it": "Slitherlink" },
  "heyawake": { "ja": "へやわけ", "ko": "헤야와케", "fr": "Heyawake", "de": "Heyawake", "es": "Heyawake", "ru": "Хеяваке", "ar": "هياواكي", "pt": "Heyawake", "it": "Heyawake" },
  "hitori": { "ja": "ひとりにしてくれ", "ko": "히토리", "fr": "Hitori", "de": "Hitori", "es": "Hitori", "ru": "Хитори", "ar": "هيتوري", "pt": "Hitori", "it": "Hitori" },
  "hitori_all": { "ja": "ひとり・上級", "ko": "히토리 심화", "fr": "Hitori avancé", "de": "Hitori Profi", "es": "Hitori avanzado", "ru": "Хитори: сложные", "ar": "هيتوري متقدّم", "pt": "Hitori avançado", "it": "Hitori avanzato" },
  "kakurasu_sums": { "ja": "カックラス", "ko": "카쿠라스", "fr": "Kakurasu", "de": "Kakurasu", "es": "Kakurasu", "ru": "Какурасу", "ar": "كاكوراسو", "pt": "Kakurasu", "it": "Kakurasu" },
  "kakuro": { "ja": "カックロ", "ko": "카쿠로", "fr": "Kakuro", "de": "Kakuro", "es": "Kakuro", "ru": "Какуро", "ar": "كاكورو", "pt": "Kakuro", "it": "Kakuro" },
  "kenken": { "ja": "賢賢", "ko": "켄켄", "fr": "KenKen", "de": "KenKen", "es": "KenKen", "ru": "КенКен", "ar": "كينكين", "pt": "KenKen", "it": "KenKen" },
  "klotski": { "ja": "華容道", "ko": "화용도", "fr": "Klotski", "de": "Klotski", "es": "Klotski", "ru": "Клоцки", "ar": "كلوتسكي", "pt": "Klotski", "it": "Klotski" },
  "kurodoko": { "ja": "黒どこ", "ko": "쿠로도코", "fr": "Kurodoko", "de": "Kurodoko", "es": "Kurodoko", "ru": "Куродоко", "ar": "كورودوكو", "pt": "Kurodoko", "it": "Kurodoko" },
  "lighthouses": { "ja": "灯台", "ko": "등대", "fr": "Phares", "de": "Leuchttürme", "es": "Faros", "ru": "Маяки", "ar": "المنارات", "pt": "Faróis", "it": "Fari" },
  "lights_out": { "ja": "ライツアウト", "ko": "라이트 아웃", "fr": "Lights Out", "de": "Lights Out", "es": "Luces fuera", "ru": "Погаси свет", "ar": "أطفئ الأنوار", "pt": "Apague as luzes", "it": "Lights Out" },
  "magnets": { "ja": "マグネット", "ko": "자석", "fr": "Aimants", "de": "Magnete", "es": "Imanes", "ru": "Магниты", "ar": "مغناطيسات", "pt": "Ímãs", "it": "Magneti" },
  "masyu": { "ja": "ましゅ", "ko": "마슈", "fr": "Masyu", "de": "Masyu", "es": "Masyu", "ru": "Масю", "ar": "ماشو", "pt": "Masyu", "it": "Masyu" },
  "math_maze": { "ja": "計算迷路", "ko": "계산 미로", "fr": "Labyrinthe math", "de": "Rechen-Labyrinth", "es": "Laberinto matemático", "ru": "Математический лабиринт", "ar": "متاهة الرياضيات", "pt": "Labirinto matemático", "it": "Labirinto matematico" },
  "math_path": { "ja": "数字パス", "ko": "숫자 경로", "fr": "Chemin des nombres", "de": "Zahlenpfad", "es": "Camino numérico", "ru": "Числовой путь", "ar": "مسار الأرقام", "pt": "Caminho numérico", "it": "Percorso numerico" },
  "nonogram": { "ja": "ののぐラム", "ko": "노노그램", "fr": "Nonogramme", "de": "Nonogramm", "es": "Nonograma", "ru": "Нонограмма", "ar": "نونوغرام", "pt": "Nonograma", "it": "Nonogramma" },
  "norinori": { "ja": "のりのり", "ko": "노리노리", "fr": "Norinori", "de": "Norinori", "es": "Norinori", "ru": "Норинори", "ar": "نورينوري", "pt": "Norinori", "it": "Norinori" },
  "nurikabe": { "ja": "ぬりかべ", "ko": "누리카베", "fr": "Nurikabe", "de": "Nurikabe", "es": "Nurikabe", "ru": "Нурикабе", "ar": "نوريكابي", "pt": "Nurikabe", "it": "Nurikabe" },
  "path_finder": { "ja": "経路探し", "ko": "경로 찾기", "fr": "Trouve le chemin", "de": "Wegfinder", "es": "Buscador de caminos", "ru": "Поиск пути", "ar": "إيجاد المسار", "pt": "Ache o caminho", "it": "Trova il percorso" },
  "bejeweled": { "ja": "ジュエルマッチ", "ko": "주얼 매치", "fr": "Bejeweled", "de": "Bejeweled", "es": "Bejeweled", "ru": "Беджьюэлд", "ar": "مجوهرات", "pt": "Bejeweled", "it": "Bejeweled" },
  "breakout": { "ja": "ブロック崩し", "ko": "벽돌깨기", "fr": "Casse-briques", "de": "Breakout", "es": "Rompebloques", "ru": "Арканоид", "ar": "كسر الطوب", "pt": "Quebra-blocos", "it": "Breakout" },
  "bubble_shooter": { "ja": "バブルシューター", "ko": "버블 슈터", "fr": "Bubble Shooter", "de": "Bubble Shooter", "es": "Bubble Shooter", "ru": "Пузырьки", "ar": "فقاعات", "pt": "Bubble Shooter", "it": "Bubble Shooter" },
  "checkers": { "ja": "チェッカー", "ko": "체커", "fr": "Dames", "de": "Dame", "es": "Damas", "ru": "Шашки", "ar": "الداما", "pt": "Damas", "it": "Dama" },
  "connect_four": { "ja": "四目並べ", "ko": "사목", "fr": "Puissance 4", "de": "Vier gewinnt", "es": "Conecta 4", "ru": "Четыре в ряд", "ar": "أربعة في صف", "pt": "Ligue 4", "it": "Forza 4" },
  "doodle_jump": { "ja": "ドゥードルジャンプ", "ko": "두들 점프", "fr": "Doodle Jump", "de": "Doodle Jump", "es": "Doodle Jump", "ru": "Дудл Джамп", "ar": "قفزة", "pt": "Doodle Jump", "it": "Doodle Jump" },
  "flappy": { "ja": "フラッピー", "ko": "플래피", "fr": "Flappy", "de": "Flappy", "es": "Flappy", "ru": "Флаппи", "ar": "فلابي", "pt": "Flappy", "it": "Flappy" },
  "freecell": { "ja": "フリーセル", "ko": "프리셀", "fr": "FreeCell", "de": "FreeCell", "es": "FreeCell", "ru": "Фриселл", "ar": "فريسيل", "pt": "FreeCell", "it": "FreeCell" },
  "game24": { "ja": "24 ゲーム", "ko": "24 게임", "fr": "Le compte est bon", "de": "24-Spiel", "es": "Juego 24", "ru": "24 очка", "ar": "لعبة 24", "pt": "Jogo 24", "it": "Gioco 24" },
  "go9": { "ja": "9 路盤囲碁", "ko": "9로 바둑", "fr": "Go 9×9", "de": "Go 9×9", "es": "Go 9×9", "ru": "Го 9×9", "ar": "غو 9×9", "pt": "Go 9×9", "it": "Go 9×9" },
  "gomoku": { "ja": "五目並べ", "ko": "오목", "fr": "Gomoku", "de": "Gomoku", "es": "Gomoku", "ru": "Гомоку", "ar": "خمسة في صف", "pt": "Gomoku", "it": "Gomoku" },
  "hanoi": { "ja": "ハノイの塔", "ko": "하노이 탑", "fr": "Tours de Hanoï", "de": "Türme von Hanoi", "es": "Torres de Hanói", "ru": "Ханойская башня", "ar": "أبراج هانوي", "pt": "Torres de Hanói", "it": "Torri di Hanoi" },
  "mancala": { "ja": "マンカラ", "ko": "만칼라", "fr": "Mancala", "de": "Mancala", "es": "Mancala", "ru": "Манкала", "ar": "منقلة", "pt": "Mancala", "it": "Mancala" },
  "mandelbrot": { "ja": "マンデルブロ集合", "ko": "만델브로 집합", "fr": "Ensemble de Mandelbrot", "de": "Mandelbrot-Menge", "es": "Conjunto de Mandelbrot", "ru": "Множество Мандельброта", "ar": "مجموعة ماندلبرو", "pt": "Conjunto de Mandelbrot", "it": "Insieme di Mandelbrot" },
  "mastermind": { "ja": "マスターマインド", "ko": "마스터마인드", "fr": "Mastermind", "de": "Mastermind", "es": "Mastermind", "ru": "Мастермайнд", "ar": "ماسترمايند", "pt": "Mastermind", "it": "Mastermind" },
  "memory": { "ja": "神経衰弱", "ko": "기억 카드", "fr": "Memory", "de": "Memory", "es": "Memoria", "ru": "Мемори", "ar": "الذاكرة", "pt": "Memória", "it": "Memory" },
  "minesweeper": { "ja": "マインスイーパー", "ko": "지뢰찾기", "fr": "Démineur", "de": "Minesweeper", "es": "Buscaminas", "ru": "Сапёр", "ar": "كانسة الألغام", "pt": "Campo Minado", "it": "Campo minato" },
  "nim": { "ja": "ニム", "ko": "님", "fr": "Nim", "de": "Nim", "es": "Nim", "ru": "Ним", "ar": "نيم", "pt": "Nim", "it": "Nim" },
  "peg_solitaire": { "ja": "ペグソリティア", "ko": "페그 솔리테어", "fr": "Solitaire à clous", "de": "Steckhalma", "es": "Solitario de clavijas", "ru": "Солитёр с колышками", "ar": "سوليتير الأوتاد", "pt": "Solitário de pinos", "it": "Peg Solitaire" },
  "pong": { "ja": "ポン", "ko": "퐁", "fr": "Pong", "de": "Pong", "es": "Pong", "ru": "Понг", "ar": "بونغ", "pt": "Pong", "it": "Pong" },
  "reversi": { "ja": "オセロ", "ko": "오셀로", "fr": "Othello", "de": "Othello", "es": "Reversi", "ru": "Реверси", "ar": "ريفيرسي", "pt": "Reversi", "it": "Othello" },
  "schulte": { "ja": "シュルテ表", "ko": "슐테 표", "fr": "Table de Schulte", "de": "Schulte-Tabelle", "es": "Tabla de Schulte", "ru": "Таблица Шульте", "ar": "جدول شولتة", "pt": "Tabela de Schulte", "it": "Tabella di Schulte" },
  "simon_says": { "ja": "サイモンゲーム", "ko": "사이먼 게임", "fr": "Jacques a dit", "de": "Simon sagt", "es": "Simón dice", "ru": "Саймон говорит", "ar": "قال سايمون", "pt": "Simon diz", "it": "Simone dice" },
  "slide15": { "ja": "15 パズル", "ko": "15 퍼즐", "fr": "Taquin", "de": "Schiebepuzzle", "es": "Rompecabezas", "ru": "Пятнашки", "ar": "الأحجية المنزلقة", "pt": "Quebra-cabeça 15", "it": "Gioco del 15" },
  "snake": { "ja": "スネーク", "ko": "스네이크", "fr": "Serpent", "de": "Snake", "es": "Serpiente", "ru": "Змейка", "ar": "الثعبان", "pt": "Cobrinha", "it": "Snake" },
  "snake3d": { "ja": "3D スネーク", "ko": "3D 스네이크", "fr": "Serpent 3D", "de": "Snake 3D", "es": "Serpiente 3D", "ru": "Змейка 3D", "ar": "الثعبان ثلاثي الأبعاد", "pt": "Cobrinha 3D", "it": "Snake 3D" },
  "sokoban": { "ja": "倉庫番", "ko": "소코반", "fr": "Sokoban", "de": "Sokoban", "es": "Sokoban", "ru": "Сокобан", "ar": "سوكوبان", "pt": "Sokoban", "it": "Sokoban" },
  "solitaire": { "ja": "クロンダイク", "ko": "클론다이크", "fr": "Klondike", "de": "Klondike", "es": "Klondike", "ru": "Клондайк", "ar": "كلوندايك", "pt": "Klondike", "it": "Klondike" },
  "mahjong_solitaire": { "ja": "上海麻雀", "ko": "마작 솔리테어", "fr": "Mahjong Solitaire", "de": "Mahjong Solitaire", "es": "Mahjong Solitaire", "ru": "Маджонг-солитёр", "ar": "ماهجونغ", "pt": "Mahjong Solitaire", "it": "Mahjong Solitaire" },
  "lock_pattern": { "ja": "パターンロック", "ko": "패턴 잠금", "fr": "Verrouillage par motif", "de": "Muster entsperren", "es": "Patrón de desbloqueo", "ru": "Графический ключ", "ar": "نمط القفل", "pt": "Padrão de desbloqueio", "it": "Sequenza di sblocco" },
  "life": { "ja": "ライフゲーム", "ko": "라이프 게임", "fr": "Jeu de la vie", "de": "Game of Life", "es": "Juego de la vida", "ru": "Игра «Жизнь»", "ar": "لعبة الحياة", "pt": "Jogo da Vida", "it": "Gioco della vita" },
  "sieve": { "ja": "エラトステネスの篩", "ko": "에라토스테네스의 체", "fr": "Crible d’Ératosthène", "de": "Sieb des Eratosthenes", "es": "Criba de Eratóstenes", "ru": "Решето Эратосфена", "ar": "غربال إراتوستينس", "pt": "Crivo de Eratóstenes", "it": "Crivello di Eratostene" },
  "kakuro_mini": { "ja": "ミニ数谜", "ko": "미니 카쿠로", "fr": "Kakuro mini", "de": "Kakuro mini", "es": "Kakuro mini", "ru": "Мини-какуро", "ar": "كاكورو مصغّر", "pt": "Kakuro mini", "it": "Kakuro mini" },
  "match3": { "ja": "マッチ 3", "ko": "매치 3", "fr": "Match 3", "de": "Match 3", "es": "Match 3", "ru": "Три в ряд", "ar": "ثلاثة متطابقة", "pt": "Match 3", "it": "Match 3" },
  "phonetic_guess": { "ja": "発音記号クイズ", "ko": "발음기호 퀴즈", "fr": "Devine la phonétique", "de": "Lautschrift raten", "es": "Adivina la fonética", "ru": "Угадай по транскрипции", "ar": "خمّن بالرمز الصوتي", "pt": "Adivinhe a fonética", "it": "Indovina la fonetica" },
  "double_trouble": { "ja": "ダブルタスク", "ko": "이중 과제", "fr": "Double tâche", "de": "Doppelaufgabe", "es": "Doble tarea", "ru": "Двойная задача", "ar": "مهمة مزدوجة", "pt": "Tarefa dupla", "it": "Doppio compito" },
  "dual_mirror": { "ja": "左右ミラー", "ko": "좌우 미러", "fr": "Miroir double", "de": "Spiegel beidseits", "es": "Espejo doble", "ru": "Двойное зеркало", "ar": "مرآة مزدوجة", "pt": "Espelho duplo", "it": "Doppio specchio" },
  "compound_connect": { "ja": "複合ライン", "ko": "복합 연결", "fr": "Liaison multiple", "de": "Mehrfach-Verbindung", "es": "Conexión múltiple", "ru": "Составная линия", "ar": "ربط مركّب", "pt": "Ligação composta", "it": "Collegamento multiplo" },
  "continuous_paired_associate": { "ja": "連続ペア連想", "ko": "연속 짝 연상", "fr": "Paires en chaîne", "de": "Fortlaufende Paare", "es": "Parejas continuas", "ru": "Непрерывные пары", "ar": "أزواج متتابعة", "pt": "Pares contínuos", "it": "Coppie continue" },
};

/** 游戏名的本地化取用（id + 中文原名 + 英文名） */
export function gameName(id: string, zh: string, en: string): string {
  const c: string = I18n.current();
  if (c === Lang.ZH) { return zh; }
  if (c === Lang.EN) { return en; }
  if (c === Lang.ZHTW) { return toTrad(zh); }
  const row: Record<string, string> | undefined = GAME_NAME[id];
  if (row !== undefined) {
    const hit: string = row[c];
    if (hit !== undefined && hit.length > 0) { return hit; }
  }
  return en;   // 该 id 未收录 ⇒ 暂退英文（收一条少一条）
}

const EXTRA: Record<string, Record<string, string>> = {
  /** ★★ 2026-10-16 实拍日语发现：界面模式三档的名字/说明没本地化 */
  "默认": {
    "en": "Default",
    "zh-Hant": "預設",
    "ja": "デフォルト",
    "ko": "기본",
    "fr": "Par défaut",
    "de": "Standard",
    "es": "Predeterminado",
    "ru": "По умолчанию",
    "ar": "الافتراضي",
    "pt": "Padrão",
    "it": "Predefinito",
  },
  /** ★★ 2026-10-16 实拍日语发现：界面模式三档的名字/说明没本地化 */
  "大字模式": {
    "en": "Large text",
    "zh-Hant": "大字模式",
    "ja": "大きな文字",
    "ko": "큰 글자",
    "fr": "Grand texte",
    "de": "Große Schrift",
    "es": "Texto grande",
    "ru": "Крупный текст",
    "ar": "خط كبير",
    "pt": "Texto grande",
    "it": "Testo grande",
  },
  /** ★★ 2026-10-16 实拍日语发现：界面模式三档的名字/说明没本地化 */
  "简约模式": {
    "en": "Compact",
    "zh-Hant": "簡約模式",
    "ja": "コンパクト",
    "ko": "간결",
    "fr": "Compact",
    "de": "Kompakt",
    "es": "Compacto",
    "ru": "Компактный",
    "ar": "مضغوط",
    "pt": "Compacto",
    "it": "Compatto",
  },
  /** ★★ 2026-10-16 实拍日语发现：界面模式三档的名字/说明没本地化 */
  // ★★★ 2026-10-19 奥森报的 bug：「切换到别的模式后，默认模式下面的文字还是"当前模式"什么的」
  //   根因：原文「现在的样子 / As it is now」是【相对说法】—— 它描述的是"当前状态"，
  //        而这一格是"默认档"的固定名字 ⇒ 切走之后那句话就变成假话，读起来像"这格才是当前模式"
  //   ⇒ 改成【绝对描述】：只说这一档是什么，不说它是不是当前
  // ★★★ 2026-10-19 全面自查（A7）抓到：开屏这两句走了 t()，但表里没有 key
  //   ⇒ 非中文缺翻译时 L() 退英文 ⇒ 俄/日/韩用户的开屏右下角是英文
  //   补上 12 语言（英文串与 Splash 里传的第二参数一致，避免两处不一致）
  "355 款小游戏": {
    "en": "355 GAMES",
    "zh-Hant": "355 款小遊戲",
    "ja": "355 種のミニゲーム",
    "ko": "355개의 미니게임",
    "fr": "355 mini-jeux",
    "de": "355 Minispiele",
    "es": "355 minijuegos",
    "ru": "355 мини-игр",
    "ar": "٣٥٥ لعبة صغيرة",
    "pt": "355 mini-jogos",
    "it": "355 minigiochi",
  },
  "碎片时间，随时开局": {
    "en": "A quick round, any time",
    "zh-Hant": "碎片時間，隨時開局",
    "ja": "すきま時間に、いつでも一局",
    "ko": "자투리 시간에 언제든 한 판",
    "fr": "Une partie rapide, à tout moment",
    "de": "Eine schnelle Runde, jederzeit",
    "es": "Una partida rápida, cuando quieras",
    "ru": "Быстрый раунд в любое время",
    "ar": "جولة سريعة في أي وقت",
    "pt": "Uma partida rápida, a qualquer hora",
    "it": "Una partita veloce, quando vuoi",
  },
  // ★★★ 2026-10-19 全面自查 A7 补：这 5 条原来「动态拼接」或「压根没进表」
  //   ⇒ 非中英用户一律退英文。改成 {a}/{b}/{n}/{s} 占位符 + 静态 key。
  "符合这 {a} 个条件的有 {b} 款": {
    "en": "{a} filters · {b} matches",
    "zh-Hant": "符合這 {a} 個條件的共有 {b} 款",
    "ja": "{a} 個の条件に合うのは {b} 本",
    "ko": "{a}개 조건에 맞는 게임 {b}개",
    "fr": "{a} filtres · {b} jeux",
    "de": "{a} Filter · {b} Spiele",
    "es": "{a} filtros · {b} juegos",
    "ru": "Фильтров: {a} · игр: {b}",
    "ar": "{a} عوامل تصفية · {b} لعبة",
    "pt": "{a} filtros · {b} jogos",
    "it": "{a} filtri · {b} giochi",
  },
  "已选 {n} 个条件": {
    "en": "{n} filters on",
    "zh-Hant": "已選 {n} 個條件",
    "ja": "{n} 個の条件を選択中",
    "ko": "{n}개 조건 선택됨",
    "fr": "{n} filtres actifs",
    "de": "{n} Filter aktiv",
    "es": "{n} filtros activos",
    "ru": "Фильтров: {n}",
    "ar": "{n} عوامل تصفية مفعّلة",
    "pt": "{n} filtros ativos",
    "it": "{n} filtri attivi",
  },
  "{s} 的房间": {
    "en": "{s}'s room",
    "zh-Hant": "{s} 的房間",
    "ja": "{s} のルーム",
    "ko": "{s}의 방",
    "fr": "Salon de {s}",
    "de": "Raum von {s}",
    "es": "Sala de {s}",
    "ru": "Комната {s}",
    "ar": "غرفة {s}",
    "pt": "Sala de {s}",
    "it": "Stanza di {s}",
  },
  "房间已开（端口 {n}）—— 等对手加入": {
    "en": "Room open on port {n} — waiting",
    "zh-Hant": "房間已開（埠 {n}）—— 等對手加入",
    "ja": "ルーム開放（ポート {n}）—— 対戦相手を待っています",
    "ko": "방 열림(포트 {n}) — 상대를 기다리는 중",
    "fr": "Salon ouvert (port {n}) — en attente",
    "de": "Raum offen (Port {n}) — warte",
    "es": "Sala abierta (puerto {n}) — esperando",
    "ru": "Комната открыта (порт {n}) — ждём",
    "ar": "الغرفة مفتوحة (المنفذ {n}) — في الانتظار",
    "pt": "Sala aberta (porta {n}) — a aguardar",
    "it": "Stanza aperta (porta {n}) — in attesa",
  },
  "正在连接 {s}…": {
    "en": "Connecting to {s}…",
    "zh-Hant": "正在連線 {s}…",
    "ja": "{s} に接続中…",
    "ko": "{s}에 연결 중…",
    "fr": "Connexion à {s}…",
    "de": "Verbinde mit {s}…",
    "es": "Conectando con {s}…",
    "ru": "Подключение к {s}…",
    "ar": "جارٍ الاتصال بـ {s}…",
    "pt": "A ligar a {s}…",
    "it": "Connessione a {s}…",
  },
  // ★★★ 2026-10-19 自查 A7：首启隐私弹窗这条【整条 key 压根不在表里】
  //   ⇒ 12 语言里 10 种会退英文。这是每个用户第一次打开就看到的文案，必须补。
  "「One More」不采集你的个人信息，也不上传你的游戏记录。所有记录只存在你自己的手机里。需联网的只有两项：局域网对战、华为游戏服务的账号校验。": {
    "en": "\"One More\" does not collect your personal information and never uploads your game records. Everything stays on your device. Only two features use the network: LAN play and Huawei Game Service account check.",
    "zh-Hant": "「One More」不收集你的個人資訊，也不上傳你的遊戲紀錄。所有紀錄只存在你自己的手機裡。需連網的只有兩項：區域網路對戰、華為遊戲服務的帳號校驗。",
    "ja": "「One More」はあなたの個人情報を収集せず、ゲーム記録も送信しません。記録はすべて端末内に残ります。ネットワークを使うのは2つだけ：LAN対戦と、Huawei Game Service のアカウント確認です。",
    "ko": "「One More」는 개인정보를 수집하지 않고 게임 기록도 업로드하지 않습니다. 모든 기록은 기기에 남습니다. 네트워크를 쓰는 기능은 두 가지뿐입니다: LAN 대전과 Huawei Game Service 계정 확인.",
    "fr": "« One More » ne collecte pas vos informations personnelles et n'envoie jamais vos parties. Tout reste sur votre appareil. Seules deux fonctions utilisent le réseau : le jeu en réseau local et la vérification de compte Huawei Game Service.",
    "de": "„One More“ sammelt keine persönlichen Daten und lädt keine Spieldaten hoch. Alles bleibt auf deinem Gerät. Nur zwei Funktionen nutzen das Netzwerk: LAN-Spiel und die Konto-Prüfung von Huawei Game Service.",
    "es": "«One More» no recopila tu información personal ni sube tus partidas. Todo se queda en tu dispositivo. Solo dos funciones usan la red: el juego en red local y la verificación de cuenta de Huawei Game Service.",
    "ru": "«One More» не собирает ваши личные данные и не передаёт игровые записи. Всё остаётся на вашем устройстве. Сеть нужна только двум функциям: игре по локальной сети и проверке аккаунта Huawei Game Service.",
    "ar": "«One More» لا يجمع معلوماتك الشخصية ولا يرفع سجلات لعبك. كل شيء يبقى على جهازك. ميزتان فقط تستخدمان الشبكة: اللعب عبر الشبكة المحلية والتحقق من حساب Huawei Game Service.",
    "pt": "«One More» não recolhe informações pessoais nem envia os seus jogos. Tudo fica no seu dispositivo. Apenas duas funções usam a rede: o jogo em rede local e a verificação de conta Huawei Game Service.",
    "it": "«One More» non raccoglie informazioni personali e non carica le tue partite. Tutto resta sul tuo dispositivo. Solo due funzioni usano la rete: il gioco in rete locale e la verifica dell'account Huawei Game Service.",
  },
  "不联网也能玩": {  "zh-Hant": "不連網也能玩",  "ja": "オフラインでも遊べます",  "ko": "오프라인에서도 플레이 가능",  "es": "Jugable sin conexión",  "fr": "Jouable hors ligne",  "de": "Auch offline spielbar",  "pt": "Jogável sem conexão",  "ru": "Играется без сети",  "it": "Giocabile offline",  "ar": "تُلعب بدون اتصال" },
  "355 款游戏全都不用联网。只有局域网对战、和华为游戏服务账号校验会用到网络": {  "zh-Hant": "355 款遊戲全都不用連網。只有區域網路對戰與華為遊戲服務帳號校驗會用到網路",  "ja": "355 本すべてオフラインで遊べます。ネットを使うのは LAN 対戦と HUAWEI ゲームサービスのアカウント認証だけです",  "ko": "355개 게임 모두 오프라인으로 즐길 수 있습니다. 네트워크는 LAN 대전과 HUAWEI 게임 서비스 계정 인증에만 사용됩니다",  "es": "Los 355 juegos funcionan sin conexión. La red solo se usa para juego en LAN y la verificación de cuenta de Huawei Game Service",  "fr": "Les 355 jeux fonctionnent hors ligne. Le réseau sert uniquement au jeu en LAN et à la vérification du compte Huawei Game Service",  "de": "Alle 355 Spiele laufen offline. Netz wird nur für LAN-Spiel und die HUAWEI Game Service-Konto-Prüfung genutzt",  "pt": "Todos os 355 jogos funcionam sem conexão. A rede só é usada para jogo em LAN e verificação de conta do Huawei Game Service",  "ru": "Все 355 игр работают без сети. Сеть нужна только для игры по LAN и проверки аккаунта Huawei Game Service",  "it": "Tutti i 355 giochi funzionano offline. La rete serve solo per il gioco in LAN e la verifica account Huawei Game Service",  "ar": "جميع الألعاب الـ355 تعمل دون اتصال. تُستخدم الشبكة فقط للعب المحلي وللتحقق من حساب خدمة ألعاب هواوي" },
  "不采集你的数据": {  "zh-Hant": "不蒐集你的資料",  "ja": "あなたのデータは集めません",  "ko": "데이터를 수집하지 않습니다",  "es": "No recogemos tus datos",  "fr": "Nous ne collectons pas vos données",  "de": "Wir sammeln deine Daten nicht",  "pt": "Não coletamos seus dados",  "ru": "Мы не собираем ваши данные",  "it": "Non raccogliamo i tuoi dati",  "ar": "لا نجمع بياناتك" },
  "不用注册账号，不上传游戏记录。只用华为游戏服务做账号校验": {  "zh-Hant": "不用註冊帳號，不上傳遊戲紀錄。只用華為遊戲服務做帳號校驗",  "ja": "アカウント登録は不要、ゲーム記録も送信しません。HUAWEI ゲームサービスはアカウント認証のみに使用します",  "ko": "계정 가입이 필요 없고 게임 기록도 전송하지 않습니다. HUAWEI 게임 서비스는 계정 인증에만 사용됩니다",  "es": "Sin cuenta ni subida de tus registros. Huawei Game Service solo se usa para verificar la cuenta",  "fr": "Aucun compte requis, aucune partie envoyée. Huawei Game Service sert seulement à vérifier le compte",  "de": "Kein Konto, kein Hochladen deiner Spielstände. HUAWEI Game Service dient nur der Konto-Prüfung",  "pt": "Sem conta e sem envio dos seus registros. O Huawei Game Service é usado só para verificar a conta",  "ru": "Без аккаунта и без отправки ваших записей. Huawei Game Service нужен только для проверки аккаунта",  "it": "Nessun account, nessun invio delle tue partite. Huawei Game Service serve solo a verificare il tuo account",  "ar": "بلا حساب وبلا رفع لسجلاتك. خدمة ألعاب هواوي تُستخدم فقط للتحقق من الحساب" },
  "本应用不收集、不存储、不传输：姓名/手机号/邮箱等身份信息、通讯录、通话记录、短信、位置信息、相册与相机内容、麦克风内容、设备标识符（IMEI/OAID/MAC）、应用安装列表、剪贴板、网络访问记录。\n\n关于网络权限：本应用**只申请了网络权限与 Wi-Fi 信息两项**，用于两件事：① **「局域网对战」** —— 让同一 Wi-Fi 下的两台设备互相找到并直连；② **华为游戏服务的账号校验** —— 应用市场对游戏类目的合规要求（防沉迷），由华为 SDK 完成，本应用不接触校验内容。**除此之外**，本应用未申请位置、相机、麦克风、通讯录、日历、电话、短信、存储读写等任何敏感权限。\n\n局域网对战**不经过任何服务器**：消息只在同一 Wi-Fi 内的两台设备之间直接传输，一局结束即断开。其余 353 款游戏与全部记录、统计**完全离线**，飞行模式下照常可玩。": {
    "en": "This app does not collect, store or transmit: identity information such as your name, phone number or email; contacts; call logs; text messages; location; photos or camera content; microphone content; device identifiers (IMEI / OAID / MAC); your list of installed apps; the clipboard; or any record of network access.\n\nAbout network access: this app requests only two permissions — network and Wi-Fi information — for two purposes: (1) LAN play, so two devices on the same Wi-Fi can find each other and connect directly; (2) account check for Huawei Game Service, a compliance requirement for the game category on the app market (anti-addiction), performed by the Huawei SDK — this app never touches the check result content. Beyond that, no location, camera, microphone, contacts, calendar, phone, SMS or storage permissions are requested.\n\nLAN play never goes through any server: messages travel directly between the two devices on your Wi-Fi and the connection closes when the round ends. The other 353 games, along with all records and statistics, stay completely offline and work in airplane mode.",
    "zh-Hant": "本應用不收集、不儲存、不傳輸：姓名/手機號/信箱等身分資訊、通訊錄、通話紀錄、簡訊、位置資訊、相簿與相機內容、麥克風內容、裝置識別碼（IMEI/OAID/MAC）、應用程式安裝清單、剪貼簿、網路存取紀錄。\n\n關於網路權限：本應用**只申請了網路權限與 Wi-Fi 資訊兩項**，用於兩件事：① **「區域網路對戰」** —— 讓同一 Wi-Fi 下的兩台裝置互相找到並直連；② **華為遊戲服務的帳號校驗** —— 應用市場對遊戲類目的合規要求（防沉迷），由華為 SDK 完成，本應用不接觸校驗內容。**除此之外**，本應用未申請位置、相機、麥克風、通訊錄、行事曆、電話、簡訊、儲存讀寫等任何敏感權限。\n\n區域網路對戰**不經過任何伺服器**：訊息只在同一 Wi-Fi 內的兩台裝置之間直接傳輸，一局結束即斷開。其餘 353 款遊戲與全部紀錄、統計**完全離線**，飛航模式下照常可玩。",
    "ja": "本アプリは、氏名・電話番号・メールアドレスなどの身元情報、連絡先、通話履歴、SMS、位置情報、写真・カメラの内容、マイクの内容、端末識別子（IMEI/OAID/MAC）、インストール済みアプリ一覧、クリップボード、ネットワークアクセス記録を収集・保存・送信しません。\n\nネットワーク権限について：本アプリが要求するのは**ネットワークと Wi-Fi 情報の2つだけ**で、用途は2つです。①**LAN対戦** —— 同じ Wi-Fi 上の2台が互いを見つけて直接接続するため。②**Huawei Game Service のアカウント確認** —— アプリマーケットのゲーム分類におけるコンプライアンス要件（依存防止）で、Huawei SDK が行い、本アプリは確認内容に触れません。**それ以外**に、位置・カメラ・マイク・連絡先・カレンダー・電話・SMS・ストレージなどの権限は要求しません。\n\nLAN対戦は**サーバーを経由しません**：メッセージは同じ Wi-Fi 内の2台の間で直接やり取りされ、1回が終われば切断されます。残り353本のゲームとすべての記録・統計は**完全オフライン**で、機内モードでも遊べます。",
    "ko": "본 앱은 이름·전화번호·이메일 등 신원 정보, 연락처, 통화 기록, 문자, 위치 정보, 사진·카메라 내용, 마이크 내용, 기기 식별자(IMEI/OAID/MAC), 설치된 앱 목록, 클립보드, 네트워크 접속 기록을 수집·저장·전송하지 않습니다.\n\n네트워크 권한에 대해: 본 앱이 요청하는 것은 **네트워크와 Wi-Fi 정보 두 가지뿐**이며, 용도는 두 가지입니다. ① **LAN 대전** — 같은 Wi-Fi의 두 기기가 서로를 찾아 직접 연결되도록. ② **Huawei Game Service 계정 확인** — 앱 마켓의 게임 분류 컴플라이언스 요건(과몰입 방지)으로, Huawei SDK가 수행하며 본 앱은 확인 내용에 접근하지 않습니다. **그 외** 위치·카메라·마이크·연락처·캘린더·전화·문자·저장소 권한은 요청하지 않습니다.\n\nLAN 대전은 **어떤 서버도 거치지 않습니다**: 메시지는 같은 Wi-Fi의 두 기기 사이에서 직접 오가고, 한 판이 끝나면 연결이 끊깁니다. 나머지 353개 게임과 모든 기록·통계는 **완전 오프라인**이며 비행기 모드에서도 플레이할 수 있습니다.",
    "fr": "Cette application ne collecte, ne stocke et ne transmet pas : vos informations d'identité (nom, téléphone, e-mail), vos contacts, l'historique d'appels, les SMS, votre position, le contenu de l'appareil photo ou des photos, le contenu du microphone, les identifiants d'appareil (IMEI / OAID / MAC), la liste de vos applications installées, le presse-papiers ou l'historique d'accès réseau.\n\nÀ propos de l'accès réseau : cette application ne demande que deux autorisations — réseau et informations Wi-Fi — pour deux usages : (1) le jeu en réseau local, afin que deux appareils du même Wi-Fi se trouvent et se connectent directement ; (2) la vérification de compte Huawei Game Service, exigence de conformité pour la catégorie jeu sur la boutique (prévention de l'addiction), réalisée par le SDK Huawei — l'application n'accède jamais au contenu de cette vérification. Au-delà, aucune autorisation de localisation, caméra, micro, contacts, calendrier, téléphone, SMS ou stockage n'est demandée.\n\nLe jeu en réseau local ne passe par aucun serveur : les messages circulent directement entre les deux appareils du même Wi-Fi et la connexion se ferme à la fin de la manche. Les 353 autres jeux, ainsi que tous les enregistrements et statistiques, restent entièrement hors ligne et fonctionnent en mode avion.",
    "de": "Diese App erhebt, speichert und überträgt nicht: Identitätsdaten wie Name, Telefonnummer oder E-Mail; Kontakte; Anruflisten; SMS; Standort; Foto- oder Kamerainhalte; Mikrofoninhalte; Gerätekennungen (IMEI / OAID / MAC); die Liste installierter Apps; die Zwischenablage; oder Netzwerkzugriffsprotokolle.\n\nZur Netzwerkberechtigung: Diese App fordert nur zwei Berechtigungen an — Netzwerk und Wi-Fi-Informationen — für zwei Zwecke: (1) LAN-Spiel, damit zwei Geräte im selben Wi-Fi sich finden und direkt verbinden; (2) Konto-Prüfung von Huawei Game Service, eine Compliance-Anforderung für die Kategorie Spiel im App-Markt (Suchtprävention), durchgeführt vom Huawei SDK — die App berührt den Inhalt der Prüfung nie. Darüber hinaus werden keine Berechtigungen für Standort, Kamera, Mikrofon, Kontakte, Kalender, Telefon, SMS oder Speicher angefordert.\n\nLAN-Spiel läuft über keinen Server: Nachrichten gehen direkt zwischen den beiden Geräten im selben Wi-Fi und die Verbindung endet mit der Runde. Die übrigen 353 Spiele sowie alle Aufzeichnungen und Statistiken bleiben vollständig offline und funktionieren im Flugmodus.",
    "es": "Esta aplicación no recopila, almacena ni transmite: información de identidad como nombre, teléfono o correo; contactos; registro de llamadas; mensajes; ubicación; contenido de fotos o cámara; contenido del micrófono; identificadores de dispositivo (IMEI / OAID / MAC); la lista de aplicaciones instaladas; el portapapeles; ni registros de acceso a la red.\n\nSobre el acceso a la red: esta aplicación solo solicita dos permisos — red e información Wi-Fi — para dos fines: (1) el juego en red local, para que dos dispositivos en la misma Wi-Fi se encuentren y conecten directamente; (2) la verificación de cuenta de Huawei Game Service, un requisito de cumplimiento para la categoría de juego en la tienda (prevención de adicción), realizada por el SDK de Huawei — la aplicación nunca accede al contenido de esa verificación. Fuera de eso, no se solicitan permisos de ubicación, cámara, micrófono, contactos, calendario, teléfono, SMS ni almacenamiento.\n\nEl juego en red local no pasa por ningún servidor: los mensajes viajan directamente entre los dos dispositivos de tu Wi-Fi y la conexión se cierra al terminar la ronda. Los otros 353 juegos, junto con todos los registros y estadísticas, permanecen completamente sin conexión y funcionan en modo avión.",
    "ru": "Это приложение не собирает, не хранит и не передаёт: идентификационные данные (имя, телефон, e-mail), контакты, журнал вызовов, SMS, местоположение, содержимое фото и камеры, содержимое микрофона, идентификаторы устройства (IMEI / OAID / MAC), список установленных приложений, буфер обмена и записи о сетевых обращениях.\n\nО сетевом доступе: приложение запрашивает только два разрешения — сеть и сведения о Wi-Fi — для двух целей: (1) игра по локальной сети, чтобы два устройства в одной Wi-Fi нашли друг друга и соединились напрямую; (2) проверка аккаунта Huawei Game Service — требование соответствия для категории игр в магазине (профилактика зависимости), выполняется SDK Huawei; приложение не касается содержимого проверки. Сверх этого не запрашиваются разрешения на местоположение, камеру, микрофон, контакты, календарь, телефон, SMS или хранилище.\n\nИгра по локальной сети не проходит через серверы: сообщения идут напрямую между двумя устройствами в одной Wi-Fi, соединение закрывается по окончании раунда. Остальные 353 игры, а также все записи и статистика полностью офлайн и работают в авиарежиме.",
    "ar": "لا يجمع هذا التطبيق ولا يخزّن ولا ينقل: معلومات الهوية كالاسم ورقم الهاتف والبريد؛ جهات الاتصال؛ سجل المكالمات؛ الرسائل؛ الموقع؛ محتوى الصور والكاميرا؛ محتوى الميكروفون؛ معرّفات الجهاز (IMEI / OAID / MAC)؛ قائمة التطبيقات المثبتة؛ الحافظة؛ أو سجلات الوصول إلى الشبكة.\n\nبخصوص إذن الشبكة: يطلب التطبيق إذنين فقط — الشبكة ومعلومات Wi-Fi — لغرضين: (١) اللعب عبر الشبكة المحلية، ليجد جهازان على نفس Wi-Fi بعضهما ويتصلا مباشرة؛ (٢) التحقق من حساب Huawei Game Service، وهو متطلب امتثال لفئة الألعاب في المتجر (الوقاية من الإدمان)، ينفّذه Huawei SDK ولا يطّلع التطبيق على محتوى التحقق. عدا ذلك لا يطلب التطبيق أذونات الموقع أو الكاميرا أو الميكروفون أو جهات الاتصال أو التقويم أو الهاتف أو الرسائل أو التخزين.\n\nاللعب عبر الشبكة المحلية لا يمر بأي خادم: تنتقل الرسائل مباشرة بين الجهازين على نفس Wi-Fi ويُغلق الاتصال عند انتهاء الجولة. أما الألعاب الـ353 الأخرى وكل السجلات والإحصاءات فتبقى دون اتصال تمامًا وتعمل في وضع الطيران.",
    "pt": "Esta aplicação não recolhe, armazena nem transmite: informações de identidade como nome, telefone ou e-mail; contactos; registo de chamadas; mensagens; localização; conteúdo de fotos ou câmara; conteúdo do microfone; identificadores do dispositivo (IMEI / OAID / MAC); a lista de aplicações instaladas; a área de transferência; ou registos de acesso à rede.\n\nSobre o acesso à rede: esta aplicação pede apenas duas permissões — rede e informações de Wi-Fi — para dois fins: (1) o jogo em rede local, para que dois dispositivos na mesma Wi-Fi se encontrem e liguem diretamente; (2) a verificação de conta Huawei Game Service, um requisito de conformidade para a categoria de jogo na loja (prevenção de dependência), realizada pelo SDK da Huawei — a aplicação nunca acede ao conteúdo dessa verificação. Além disso, não são pedidas permissões de localização, câmara, microfone, contactos, calendário, telefone, SMS ou armazenamento.\n\nO jogo em rede local não passa por qualquer servidor: as mensagens viajam diretamente entre os dois dispositivos na sua Wi-Fi e a ligação fecha-se no fim da ronda. Os restantes 353 jogos, bem como todos os registos e estatísticas, ficam totalmente offline e funcionam em modo de avião.",
    "it": "Questa applicazione non raccoglie, memorizza o trasmette: dati identificativi come nome, telefono o e-mail; contatti; registro chiamate; SMS; posizione; contenuti di foto o fotocamera; contenuti del microfono; identificatori del dispositivo (IMEI / OAID / MAC); l'elenco delle app installate; gli appunti; o registri di accesso alla rete.\n\nSui permessi di rete: questa app richiede solo due permessi — rete e informazioni Wi-Fi — per due scopi: (1) il gioco in rete locale, perché due dispositivi sulla stessa Wi-Fi si trovino e si colleghino direttamente; (2) la verifica dell'account Huawei Game Service, un requisito di conformità per la categoria giochi nello store (prevenzione della dipendenza), eseguita dall'SDK Huawei — l'app non accede mai al contenuto di tale verifica. Oltre a ciò, non vengono richiesti permessi per posizione, fotocamera, microfono, contatti, calendario, telefono, SMS o archiviazione.\n\nIl gioco in rete locale non passa da alcun server: i messaggi viaggiano direttamente tra i due dispositivi sulla tua Wi-Fi e la connessione si chiude a fine partita. Gli altri 353 giochi, insieme a tutti i record e le statistiche, restano completamente offline e funzionano in modalità aereo.",
  },
  "本应用只接入了一个第三方组件：**华为 Game Service Kit** —— 用于上面提到的账号校验，属应用市场对游戏类目的合规要求。除此之外没有接入任何其他 SDK（SDK 就是别人写好的代码包）—— 没有广告的、没有统计分析的、没有崩溃上报的、没有社交分享的、没有支付的、也没有推送的。\n\n本应用不含任何广告，不含任何内购，不产生任何费用。": {
    "en": "This app integrates only one third-party component: **Huawei Game Service Kit** — used for the account check mentioned above, a compliance requirement for the game category on the app market. Beyond that it includes no other SDKs (an SDK is a pre-written code package) — none for ads, none for analytics, none for crash reporting, none for social sharing, none for payments and none for push notifications.\n\nThe app has no ads, no in-app purchases and costs nothing.",
    "zh-Hant": "本應用只接入了一個第三方元件：**華為 Game Service Kit** —— 用於上面提到的帳號校驗，屬應用市場對遊戲類目的合規要求。除此之外沒有接入任何其他 SDK（SDK 就是別人寫好的程式碼包）—— 沒有廣告的、沒有統計分析的、沒有崩潰回報的、沒有社群分享的、沒有支付的、也沒有推播的。\n\n本應用不含任何廣告，不含任何內購，不產生任何費用。",
    "ja": "本アプリが組み込むサードパーティ製コンポーネントは1つだけです：**Huawei Game Service Kit** —— 上記のアカウント確認に使用され、アプリマーケットのゲーム分類におけるコンプライアンス要件です。それ以外の SDK（SDK とは他者が用意したコードパッケージのこと）は一切組み込んでいません —— 広告・解析・クラッシュ報告・SNS共有・決済・プッシュ通知のいずれもありません。\n\n本アプリは広告なし、アプリ内課金なし、費用は一切かかりません。",
    "ko": "본 앱이 포함한 서드파티 구성 요소는 하나뿐입니다: **Huawei Game Service Kit** — 위에서 언급한 계정 확인에 사용되며, 앱 마켓의 게임 분류 컴플라이언스 요건입니다. 그 외의 SDK(SDK는 다른 곳에서 만든 코드 패키지)는 전혀 포함하지 않았습니다 — 광고·분석·크래시 보고·소셜 공유·결제·푸시 알림 모두 없습니다.\n\n본 앱은 광고가 없고, 인앱 결제가 없으며, 비용이 들지 않습니다.",
    "fr": "Cette application n'intègre qu'un seul composant tiers : **Huawei Game Service Kit** — utilisé pour la vérification de compte mentionnée ci-dessus, une exigence de conformité pour la catégorie jeu sur la boutique. Au-delà, elle n'intègre aucun autre SDK (un SDK est un paquet de code fourni par un tiers) — aucun pour la publicité, aucun pour l'analyse, aucun pour les rapports de plantage, aucun pour le partage social, aucun pour le paiement, aucun pour les notifications push.\n\nL'application ne contient aucune publicité, aucun achat intégré et ne coûte rien.",
    "de": "Diese App bindet nur eine Drittanbieter-Komponente ein: **Huawei Game Service Kit** — genutzt für die oben genannte Konto-Prüfung, eine Compliance-Anforderung für die Kategorie Spiel im App-Markt. Darüber hinaus sind keine weiteren SDKs eingebunden (ein SDK ist ein vorgefertigtes Codepaket) — keines für Werbung, keines für Analyse, keines für Absturzberichte, keines für Social Sharing, keines für Zahlungen und keines für Push-Benachrichtigungen.\n\nDie App enthält keine Werbung, keine In-App-Käufe und kostet nichts.",
    "es": "Esta aplicación integra solo un componente de terceros: **Huawei Game Service Kit** — usado para la verificación de cuenta mencionada arriba, un requisito de cumplimiento para la categoría de juego en la tienda. Fuera de eso no integra ningún otro SDK (un SDK es un paquete de código hecho por terceros) — ninguno de publicidad, ninguno de análisis, ninguno de informes de fallos, ninguno de compartir en redes, ninguno de pagos y ninguno de notificaciones push.\n\nLa aplicación no tiene anuncios, no tiene compras integradas y no cuesta nada.",
    "ru": "В приложение встроен только один сторонний компонент: **Huawei Game Service Kit** — он используется для упомянутой выше проверки аккаунта и является требованием соответствия для категории игр в магазине. Помимо этого, никаких других SDK (SDK — это готовый пакет кода) не подключено: ни рекламных, ни аналитических, ни для отчётов о сбоях, ни для соцсетей, ни для платежей, ни для push-уведомлений.\n\nВ приложении нет рекламы, нет встроенных покупок, оно бесплатное.",
    "ar": "يتضمن هذا التطبيق مكوّنًا واحدًا فقط من طرف ثالث: **Huawei Game Service Kit** — يُستخدم للتحقق من الحساب المذكور أعلاه، وهو متطلب امتثال لفئة الألعاب في المتجر. عدا ذلك لا يتضمن أي SDK آخر (الـSDK حزمة أكواد جاهزة من طرف آخر) — لا للإعلانات، ولا للتحليلات، ولا لتقارير الأعطال، ولا للمشاركة الاجتماعية، ولا للمدفوعات، ولا للإشعارات.\n\nلا يحتوي التطبيق على إعلانات ولا مشتريات داخلية ولا يترتب عليه أي تكلفة.",
    "pt": "Esta aplicação integra apenas um componente de terceiros: **Huawei Game Service Kit** — usado para a verificação de conta mencionada acima, um requisito de conformidade para a categoria de jogo na loja. Além disso não integra qualquer outro SDK (um SDK é um pacote de código feito por terceiros) — nenhum de publicidade, nenhum de análise, nenhum de relatórios de falhas, nenhum de partilha social, nenhum de pagamentos e nenhum de notificações push.\n\nA aplicação não tem anúncios, não tem compras integradas e não custa nada.",
    "it": "Questa applicazione integra un solo componente di terze parti: **Huawei Game Service Kit** — usato per la verifica dell'account citata sopra, un requisito di conformità per la categoria giochi nello store. Oltre a ciò non integra altri SDK (un SDK è un pacchetto di codice fornito da terzi) — nessuno per pubblicità, nessuno per analisi, nessuno per segnalazioni di crash, nessuno per condivisione social, nessuno per pagamenti e nessuno per notifiche push.\n\nL'applicazione non contiene pubblicità, non contiene acquisti in-app e non costa nulla.",
  },
  "标准字号与间距": {
    "en": "Standard text & spacing",
    "zh-Hant": "標準字號與間距",
    "ja": "標準の文字と間隔",
    "ko": "표준 글자와 간격",
    "fr": "Taille et espacement standard",
    "de": "Standardgröße und -abstand",
    "es": "Texto y espaciado estándar",
    "ru": "Стандартный размер и отступы",
    "ar": "حجم ونظام قياسي",
    "pt": "Texto e espaçamento padrão",
    "it": "Testo e spaziatura standard",
  },
  /** ★★ 2026-10-16 实拍日语发现：界面模式三档的名字/说明没本地化 */
  "字更大、按钮更大、间距更宽": {
    "en": "Bigger text, buttons and spacing",
    "zh-Hant": "字更大、按鈕更大、間距更寬",
    "ja": "文字もボタンも大きく、余白も広め",
    "ko": "글자·버튼·간격 모두 크게",
    "fr": "Texte, boutons et espacements plus grands",
    "de": "Größere Schrift, Buttons und Abstände",
    "es": "Texto, botones y espacios más grandes",
    "ru": "Крупнее текст, кнопки и отступы",
    "ar": "خط وأزرار ومسافات أكبر",
    "pt": "Texto, botões e espaçamentos maiores",
    "it": "Testo, pulsanti e spazi più grandi",
  },
  /** ★★ 2026-10-16 实拍日语发现：界面模式三档的名字/说明没本地化 */
  "更紧凑，一屏看更多": {
    "en": "Tighter — more per screen",
    "zh-Hant": "更緊湊，一屏看更多",
    "ja": "詰めて、一画面に多く",
    "ko": "더 촘촘하게, 한 화면에 더 많이",
    "fr": "Plus compact, plus par écran",
    "de": "Kompakter, mehr pro Bildschirm",
    "es": "Más compacto, más por pantalla",
    "ru": "Плотнее — больше на экране",
    "ar": "أكثر إحكامًا، والمزيد في الشاشة",
    "pt": "Mais compacto, mais por ecrã",
    "it": "Più compatto, più per schermo",
  },
  /** ★★ 2026-10-16 带 emoji 前缀的界面键（原来只有不带 emoji 的版本） */
  "🎮 全部": {
    "ja": "🎮 すべて",
    "ko": "🎮 전체",
    "fr": "🎮 Tout",
    "de": "🎮 Alle",
    "es": "🎮 Todo",
    "ru": "🎮 Все",
    "ar": "🎮 الكل",
    "pt": "🎮 Tudo",
    "it": "🎮 Tutti",
  },
  /** ★★ 2026-10-16 带 emoji 前缀的界面键（原来只有不带 emoji 的版本） */
  "⭐ 我收藏的 ": {
    "ja": "⭐ お気に入り ",
    "ko": "⭐ 즐겨찾기 ",
    "fr": "⭐ Favoris ",
    "de": "⭐ Favoriten ",
    "es": "⭐ Favoritos ",
    "ru": "⭐ Избранное ",
    "ar": "⭐ المفضّلة ",
    "pt": "⭐ Favoritos ",
    "it": "⭐ Preferiti ",
  },
  /** ★★ 2026-10-16 带 emoji 前缀的界面键（原来只有不带 emoji 的版本） */
  "🕐 玩过的": {
    "ja": "🕐 遊んだ",
    "ko": "🕐 플레이함",
    "fr": "🕐 Joués",
    "de": "🕐 Gespielt",
    "es": "🕐 Jugados",
    "ru": "🕐 Игранные",
    "ar": "🕐 المُلعَبة",
    "pt": "🕐 Jogados",
    "it": "🕐 Giocati",
  },
  /** ★★ 2026-10-16 分段标签（最近） */
  "最近": {
    "ja": "最近",
    "ko": "최근",
    "fr": "Récents",
    "de": "Zuletzt",
    "es": "Recientes",
    "ru": "Недавние",
    "ar": "الأخيرة",
    "pt": "Recentes",
    "it": "Recenti",
  },
  /** ★★ 2026-10-16 界面残留片段（原来 9 语言退英文） */
  " 款": {
    "ja": " 本",
    "ko": " 개",
    "fr": " jeux",
    "de": " Spiele",
    "es": " juegos",
    "ru": " игр",
    "ar": " لعبة",
    "pt": " jogos",
    "it": " giochi",
  },
  /** ★★ 2026-10-16 界面残留片段（原来 9 语言退英文） */
  "作者 ": {
    "ja": "作者 ",
    "ko": "만든이 ",
    "fr": "Par ",
    "de": "Von ",
    "es": "Por ",
    "ru": "Автор ",
    "ar": "بقلم ",
    "pt": "Por ",
    "it": "Di ",
  },
  /** ★★ 2026-10-16 界面残留片段（原来 9 语言退英文） */
  "🏆 解锁成就 ": {
    "ja": "🏆 実績解除 ",
    "ko": "🏆 업적 달성 ",
    "fr": "🏆 Succès débloqué ",
    "de": "🏆 Erfolg freigeschaltet ",
    "es": "🏆 Logro desbloqueado ",
    "ru": "🏆 Достижение получено ",
    "ar": "🏆 تم فتح إنجاز ",
    "pt": "🏆 Conquista desbloqueada ",
    "it": "🏆 Obiettivo sbloccato ",
  },
  /** ★★ 2026-10-16 界面残留片段（原来 9 语言退英文） */
  "升到 LV ": {
    "ja": "LV に到達 ",
    "ko": "LV 달성 ",
    "fr": "Niveau LV ",
    "de": "LV erreicht ",
    "es": "Nivel LV ",
    "ru": "Уровень LV ",
    "ar": "المستوى LV ",
    "pt": "Nível LV ",
    "it": "Livello LV ",
  },
  /** ★★ 2026-10-16 隐私摘要句（原来 9 语言退英文） */
  /** ★★ 2026-10-16 隐私政策第 1 段正文（原来 9 语言退英文） */
  "本应用不收集、不存储、不传输：姓名/手机号/邮箱等身份信息、通讯录、通话记录、短信、位置信息、相册与相机内容、麦克风内容、设备标识符（IMEI/OAID/MAC）、应用安装列表、剪贴板、网络访问记录。\\n\\n关于网络权限：本应用**只申请了网络权限与 Wi-Fi 信息两项**，且**只用于「局域网对战」** —— 让同一 Wi-Fi 下的两台设备互相找到并直连。**除此之外**，本应用未申请位置、相机、麦克风、通讯录、日历、电话、短信、存储读写等任何敏感权限。\\n\\n局域网对战**不连接互联网、不上传任何数据**：消息只在同一 Wi-Fi 内的两台设备之间直接传输，一局结束即断开。其余 353 款游戏与全部记录、统计**完全离线**，飞行模式下照常可玩。": {
    "ja": "本アプリは収集・保存・送信しません：氏名／電話番号／メール等の身元情報、連絡先、通話履歴、SMS、位置情報、写真とカメラの内容、マイクの内容、端末識別子（IMEI/OAID/MAC）、インストール済みアプリ一覧、クリップボード、ネットワークアクセス履歴。\\n\\nネットワーク権限について：本アプリが申請するのは**ネットワーク権限と Wi-Fi 情報の2つのみ**で、**「LAN 対戦」専用**です —— 同じ Wi-Fi 上の2台が互いを見つけて直接接続するため。**それ以外**に、位置・カメラ・マイク・連絡先・カレンダー・電話・SMS・ストレージ読み書き等の機微な権限は一切申請していません。\\n\\nLAN 対戦は**インターネットに接続せず、いかなるデータも送信しません**：メッセージは同じ Wi-Fi 内の2台間で直接やり取りされ、1局終われば切断されます。残り 353 本のゲームとすべての記録・統計は**完全オフライン**で、機内モードでも遊べます。",
    "ko": "본 앱은 수집·저장·전송하지 않습니다: 이름/전화번호/이메일 등 신원 정보, 연락처, 통화 기록, 문자, 위치 정보, 사진과 카메라 내용, 마이크 내용, 기기 식별자(IMEI/OAID/MAC), 설치된 앱 목록, 클립보드, 네트워크 접속 기록.\\n\\n네트워크 권한에 대해: 본 앱이 요청하는 것은 **네트워크 권한과 Wi-Fi 정보 두 가지뿐**이며 **「LAN 대전」 전용**입니다 —— 같은 Wi-Fi의 두 기기가 서로를 찾아 직접 연결하기 위해서입니다. **그 외에** 위치·카메라·마이크·연락처·캘린더·전화·문자·저장소 읽기쓰기 등 민감한 권한은 전혀 요청하지 않습니다.\\n\\nLAN 대전은 **인터넷에 연결하지 않고 어떤 데이터도 업로드하지 않습니다**: 메시지는 같은 Wi-Fi 내 두 기기 사이에서만 직접 전송되고, 한 판이 끝나면 끊깁니다. 나머지 353개 게임과 모든 기록·통계는 **완전 오프라인**이라 비행기 모드에서도 즐길 수 있습니다.",
    "fr": "Cette application ne collecte, ne stocke ni ne transmet : nom/numéro de téléphone/e-mail et autres données d’identité, contacts, historique d’appels, SMS, localisation, contenu de la galerie et de la caméra, contenu du micro, identifiants d’appareil (IMEI/OAID/MAC), liste des applications installées, presse-papiers, historique d’accès réseau.\\n\\nÀ propos des permissions réseau : l’application ne demande **que la permission réseau et les informations Wi-Fi**, et **uniquement pour le « duel en réseau local »** —— pour que deux appareils du même Wi-Fi se trouvent et se connectent directement. **En dehors de cela**, aucune permission sensible (localisation, caméra, micro, contacts, calendrier, téléphone, SMS, lecture/écriture du stockage) n’est demandée.\\n\\nLe duel en réseau local **ne se connecte pas à Internet et n’envoie aucune donnée** : les messages circulent directement entre deux appareils du même Wi-Fi et la connexion se coupe à la fin d’une partie. Les 353 autres jeux et toutes les statistiques sont **entièrement hors ligne** : jouables en mode avion.",
    "de": "Diese App erhebt, speichert und überträgt nichts: Name/Telefonnummer/E-Mail und andere Identitätsdaten, Kontakte, Anrufliste, SMS, Standort, Galerie- und Kamerainhalte, Mikrofoninhalte, Gerätekennungen (IMEI/OAID/MAC), Liste installierter Apps, Zwischenablage, Netzwerkzugriffsprotokolle.\\n\\nZu den Netzwerkberechtigungen: Die App beantragt **nur Netzwerkberechtigung und Wi-Fi-Informationen** und **ausschließlich für das „LAN-Duell“** —— damit zwei Geräte im selben Wi-Fi sich finden und direkt verbinden. **Darüber hinaus** werden keine sensiblen Berechtigungen (Standort, Kamera, Mikrofon, Kontakte, Kalender, Telefon, SMS, Speicherzugriff) beantragt.\\n\\nDas LAN-Duell **verbindet sich nicht mit dem Internet und lädt keine Daten hoch**: Nachrichten laufen direkt zwischen zwei Geräten im selben Wi-Fi und die Verbindung endet mit der Runde. Die übrigen 353 Spiele und alle Statistiken sind **völlig offline** —— auch im Flugmodus spielbar.",
    "es": "Esta aplicación no recopila, almacena ni transmite: nombre/teléfono/correo y otros datos de identidad, contactos, historial de llamadas, SMS, ubicación, contenido de la galería y la cámara, contenido del micrófono, identificadores del dispositivo (IMEI/OAID/MAC), lista de apps instaladas, portapapeles, registros de acceso a la red.\\n\\nSobre los permisos de red: la app **solo solicita permiso de red e información de Wi-Fi**, y **únicamente para el «duelo por red local»** —— para que dos dispositivos en la misma Wi-Fi se encuentren y conecten directamente. **Aparte de eso**, no solicita permisos sensibles (ubicación, cámara, micrófono, contactos, calendario, teléfono, SMS, lectura/escritura de almacenamiento).\\n\\nEl duelo por red local **no se conecta a Internet ni sube dato alguno**: los mensajes viajan directamente entre dos dispositivos de la misma Wi-Fi y la conexión se corta al acabar la partida. Los otros 353 juegos y todas las estadísticas son **totalmente sin conexión**: jugables en modo avión.",
    "ru": "Это приложение не собирает, не хранит и не передаёт: имя/телефон/почту и другие данные личности, контакты, историю звонков, SMS, местоположение, содержимое галереи и камеры, содержимое микрофона, идентификаторы устройства (IMEI/OAID/MAC), список установленных приложений, буфер обмена, журналы сетевого доступа.\\n\\nО сетевых разрешениях: приложение запрашивает **только разрешение на сеть и сведения о Wi-Fi**, и **исключительно для «дуэли по локальной сети»** —— чтобы два устройства в одной Wi-Fi нашли друг друга и соединились напрямую. **Кроме этого**, никакие чувствительные разрешения (местоположение, камера, микрофон, контакты, календарь, телефон, SMS, доступ к памяти) не запрашиваются.\\n\\nДуэль по локальной сети **не выходит в интернет и ничего не загружает**: сообщения идут напрямую между двумя устройствами в одной Wi-Fi, а связь обрывается после партии. Остальные 353 игры и вся статистика **полностью офлайн** —— играть можно в авиарежиме.",
    "ar": "لا يجمع هذا التطبيق ولا يخزّن ولا يرسل: الاسم/رقم الهاتف/البريد وغيرها من بيانات الهوية، وجهات الاتصال، وسجل المكالمات، والرسائل، والموقع، ومحتوى المعرض والكاميرا، ومحتوى الميكروفون، ومعرّفات الجهاز (IMEI/OAID/MAC)، وقائمة التطبيقات المثبَّتة، والحافظة، وسجلات الوصول إلى الشبكة.\\n\\nبشأن أذونات الشبكة: لا يطلب التطبيق **سوى إذن الشبكة ومعلومات Wi-Fi**، و**فقط من أجل «مبارزة الشبكة المحلية»** —— ليجد جهازان على نفس شبكة Wi-Fi بعضهما ويتصلا مباشرة. **وبخلاف ذلك** لا يطلب أي أذونات حساسة (الموقع، الكاميرا، الميكروفون، جهات الاتصال، التقويم، الهاتف، الرسائل، قراءة/كتابة التخزين).\\n\\nمبارزة الشبكة المحلية **لا تتصل بالإنترنت ولا ترفع أي بيانات**: الرسائل تنتقل مباشرة بين جهازين على نفس شبكة Wi-Fi، وينقطع الاتصال بعد انتهاء الجولة. أما الألعاب الـ353 الأخرى وكل السجلات والإحصاءات فهي **دون اتصال بالكامل** —— تُلعب في وضع الطيران.",
    "pt": "Este aplicativo não coleta, armazena nem transmite: nome/telefone/e-mail e outros dados de identidade, contatos, histórico de chamadas, SMS, localização, conteúdo da galeria e da câmera, conteúdo do microfone, identificadores do dispositivo (IMEI/OAID/MAC), lista de apps instalados, área de transferência, registros de acesso à rede.\\n\\nSobre as permissões de rede: o app **só solicita permissão de rede e informações de Wi-Fi**, e **apenas para o «duelo em rede local»** —— para que dois aparelhos na mesma Wi-Fi se encontrem e se conectem diretamente. **Fora disso**, não solicita permissões sensíveis (localização, câmera, microfone, contatos, calendário, telefone, SMS, leitura/escrita de armazenamento).\\n\\nO duelo em rede local **não se conecta à internet nem envia dados**: as mensagens vão direto entre dois aparelhos na mesma Wi-Fi e a conexão cai ao fim da partida. Os outros 353 jogos e todas as estatísticas são **totalmente offline** —— jogáveis em modo avião.",
    "it": "Questa app non raccoglie, non conserva e non trasmette: nome/telefono/email e altri dati identitari, contatti, registro chiamate, SMS, posizione, contenuti di galleria e fotocamera, contenuti del microfono, identificatori del dispositivo (IMEI/OAID/MAC), elenco delle app installate, appunti, registri di accesso alla rete.\\n\\nSui permessi di rete: l’app **chiede solo il permesso di rete e le informazioni Wi-Fi**, e **unicamente per il «duello in rete locale»** —— perché due dispositivi sulla stessa Wi-Fi si trovino e si connettano direttamente. **Al di fuori di questo**, non chiede permessi sensibili (posizione, fotocamera, microfono, contatti, calendario, telefono, SMS, lettura/scrittura dello storage).\\n\\nIl duello in rete locale **non si connette a Internet e non carica alcun dato**: i messaggi viaggiano direttamente tra due dispositivi sulla stessa Wi-Fi e la connessione si chiude a fine partita. Gli altri 353 giochi e tutte le statistiche sono **completamente offline**: giocabili in modalità aereo.",
  },
  /** ★★ 2026-10-16 游戏分类名（界面分类标签，原来 9 语言退英文） */
  "经典": { "ja": "クラシック", "ko": "클래식", "fr": "Classique", "de": "Klassiker", "es": "Clásicos", "ru": "Классика", "ar": "كلاسيكي", "pt": "Clássicos", "it": "Classici",},
  /** ★★ 2026-10-16 游戏分类名（界面分类标签，原来 9 语言退英文） */
  "逻辑": { "ja": "ロジック", "ko": "논리", "fr": "Logique", "de": "Logik", "es": "Lógica", "ru": "Логика", "ar": "منطقي", "pt": "Lógica", "it": "Logica",},
  /** ★★ 2026-10-16 游戏分类名（界面分类标签，原来 9 语言退英文） */
  "数字": { "ja": "数字", "ko": "숫자", "fr": "Nombres", "de": "Zahlen", "es": "Números", "ru": "Числа", "ar": "أرقام", "pt": "Números", "it": "Numeri",},
  /** ★★ 2026-10-16 游戏分类名（界面分类标签，原来 9 语言退英文） */
  "记忆": { "ja": "記憶", "ko": "기억", "fr": "Mémoire", "de": "Gedächtnis", "es": "Memoria", "ru": "Память", "ar": "ذاكرة", "pt": "Memória", "it": "Memoria",},
  /** ★★ 2026-10-16 游戏分类名（界面分类标签，原来 9 语言退英文） */
  "文字": { "ja": "言葉", "ko": "단어", "fr": "Mots", "de": "Wörter", "es": "Palabras", "ru": "Слова", "ar": "كلمات", "pt": "Palavras", "it": "Parole",},
  /** ★★ 2026-10-16 游戏分类名（界面分类标签，原来 9 语言退英文） */
  "空间": { "ja": "空間", "ko": "공간", "fr": "Spatial", "de": "Räumlich", "es": "Espacial", "ru": "Пространство", "ar": "مكاني", "pt": "Espacial", "it": "Spaziale",},
  /**
   * ★★★ 2026-10-15 补译（起因：奥森要我注意"语言切换后的界面"）
   *   实测发现：阿拉伯语等 10 种语言下，关于/反馈区这几条【显示英文】——
   *   查证为【字典缺项 + 有意兜底退英文】（I18n.ets 里 L() 的最后一行）
   *   ⇒ 奥森说过「大胆做就好」⇒ 我按他的用词习惯补上 9 种语言
   *   （中英已有原文；繁体由 toTrad 简→繁转换覆盖）
   */
  /**
   * ★★★ 2026-10-15 补译【第二批】：全库扫出 25 条会退英文的界面文案，
   *   这里补最显眼的 14 条（设置页 / LAN 对战 / 成就区）
   *   —— 起因：奥森「注意语言切换后的界面」；缺项时 L() 会退英文（有意兜底）
   */
  "界面模式": { "ja": "画面モード", "ko": "화면 모드", "es": "Modo de interfaz", "fr": "Mode d'affichage", "de": "Anzeigemodus", "pt": "Modo de interface", "ru": "Режим интерфейса", "it": "Modalità interfaccia", "ar": "وضع الواجهة" },
  "字大还是紧凑，一按就变": { "ja": "文字を大きく、または詰めて —— 押すだけ", "ko": "글자를 크게 또는 촘촘하게 — 누르면 바로", "es": "Texto grande o compacto — un toque", "fr": "Texte grand ou compact — un appui", "de": "Große oder kompakte Schrift — ein Tipp", "pt": "Texto grande ou compacto — um toque", "ru": "Крупный или компактный текст — одним нажатием", "it": "Testo grande o compatto — un tocco", "ar": "نص أكبر أو أكثر إحكامًا — بضغطة" },
  "作者": { "ja": "作者", "ko": "만든이", "es": "Autor", "fr": "Auteur", "de": "Autor", "pt": "Autor", "ru": "Автор", "it": "Autore", "ar": "المؤلف" },
  "竞速模式": { "ja": "レースモード", "ko": "레이스 모드", "es": "Modo carrera", "fr": "Mode course", "de": "Rennmodus", "pt": "Modo corrida", "ru": "Режим гонки", "it": "Modalità gara", "ar": "وضع السباق" },
  "回合制对战": { "ja": "ターン制対戦", "ko": "턴제 대전", "es": "Duelo por turnos", "fr": "Duel au tour par tour", "de": "Rundenbasiertes Duell", "pt": "Duelo por turnos", "ru": "Поединок по очереди", "it": "Sfida a turni", "ar": "مبارزة بالأدوار" },
  "同一款游戏一起开，谁先完成谁赢；355 款全都能比": { "ja": "同じゲームを同時に開始、先に終えた方の勝ち。355 本すべて対戦可", "ko": "같은 게임을 함께 시작해 먼저 끝내면 승리 — 355개 모두 가능", "es": "Empezad el mismo juego; gana quien termine antes. Los 355 sirven", "fr": "Lancez le même jeu ; le plus rapide gagne. Les 355 marchent", "de": "Startet dasselbe Spiel — wer zuerst fertig ist, gewinnt. Alle 355", "pt": "Comecem o mesmo jogo; vence quem terminar antes. Todos os 355", "ru": "Запустите одну игру — победит тот, кто финиширует первым. Все 355", "it": "Iniziate lo stesso gioco: vince chi finisce prima. Tutti i 355", "ar": "ابدآ اللعبة نفسها — من ينتهِ أولًا يفوز. كل الـ355 لعبة" },
  "井字棋 / 五子棋 / 围棋 等 8 款轮流下": { "ja": "三目並べ / 五目並べ / 囲碁 など 8 本を交互に", "ko": "틱택토 / 오목 / 바둑 등 8종을 번갈아", "es": "Tres en raya / Cinco en línea / Go y 5 más por turnos", "fr": "Morpion / Puissance 5 / Go et 5 autres à tour de rôle", "de": "Tic-Tac-Toe / Fünf in einer Reihe / Go u. a. abwechselnd", "pt": "Jogo da velha / Cinco em linha / Go e mais 5 por turnos", "ru": "Крестики-нолики / Пять в ряд / Го и ещё 5 по очереди", "it": "Tris / Cinque in fila / Go e altri 5 a turni", "ar": "إكس-أو / خمسة على التوالي / غو و5 غيرها بالتناوب" },
  "实时排名": { "ja": "リアルタイム順位", "ko": "실시간 순위", "es": "Clasificación en vivo", "fr": "Classement en direct", "de": "Live-Rangliste", "pt": "Ranking ao vivo", "ru": "Рейтинг в реальном времени", "it": "Classifica live", "ar": "ترتيب مباشر" },
  "还没有人完成 —— 开一局吧": { "ja": "まだ誰もクリアしていません —— 始めましょう", "ko": "아직 아무도 완료하지 않았어요 — 시작해 보세요", "es": "Nadie ha terminado aún — juega una", "fr": "Personne n'a encore terminé — lancez une partie", "de": "Noch niemand fertig — starte eine Runde", "pt": "Ninguém terminou ainda — jogue uma", "ru": "Пока никто не прошёл — сыграйте", "it": "Nessuno ha ancora finito — gioca", "ar": "لم يكمل أحد بعد — ابدأ جولة" },
  "正在开房…": { "ja": "部屋を作成中…", "ko": "방 만드는 중…", "es": "Creando sala…", "fr": "Création de la salle…", "de": "Raum wird erstellt…", "pt": "Criando sala…", "ru": "Создание комнаты…", "it": "Creazione stanza…", "ar": "جارٍ إنشاء الغرفة…" },
  "有人来了！": { "ja": "誰か来ました！", "ko": "누군가 왔어요!", "es": "¡Alguien ha entrado!", "fr": "Quelqu'un est arrivé !", "de": "Jemand ist da!", "pt": "Alguém entrou!", "ru": "Кто-то пришёл!", "it": "Qualcuno è arrivato!", "ar": "وصل أحدهم!" },
  "开房失败": { "ja": "部屋を作成できません", "ko": "방 만들기 실패", "es": "No se pudo crear la sala", "fr": "Échec de création de la salle", "de": "Raumerstellung fehlgeschlagen", "pt": "Falha ao criar a sala", "ru": "Не удалось создать комнату", "it": "Creazione stanza non riuscita", "ar": "فشل إنشاء الغرفة" },
  "竞速开始！谁先完成谁赢": { "ja": "レース開始！先に終えた方の勝ち", "ko": "레이스 시작! 먼저 끝내면 승리", "es": "¡Empieza la carrera! Gana quien termine antes", "fr": "La course commence ! Le plus rapide gagne", "de": "Rennen läuft! Wer zuerst fertig ist, gewinnt", "pt": "Corrida começou! Vence quem terminar antes", "ru": "Гонка началась! Победит первый", "it": "Gara iniziata! Vince chi finisce prima", "ar": "بدأ السباق! من ينتهِ أولًا يفوز" },
  "连不上，检查同一 Wi-Fi": { "ja": "接続できません。同じ Wi-Fi か確認してください", "ko": "연결 실패 — 같은 Wi-Fi인지 확인하세요", "es": "Sin conexión: comprueba el mismo Wi-Fi", "fr": "Connexion impossible — vérifiez le même Wi-Fi", "de": "Keine Verbindung — gleiches WLAN prüfen", "pt": "Sem conexão — verifique o mesmo Wi-Fi", "ru": "Нет связи — проверьте один и тот же Wi-Fi", "it": "Nessuna connessione — controlla lo stesso Wi-Fi", "ar": "تعذّر الاتصال — تأكد من نفس شبكة Wi-Fi" },
  "已加入，等房主开始": { "ja": "参加しました。ホストの開始を待っています", "ko": "참가했습니다 — 방장이 시작하기를 기다리는 중", "es": "Te has unido — espera a que el anfitrión empiece", "fr": "Rejoint — attendez que l'hôte lance", "de": "Beigetreten — warte auf den Host", "pt": "Entrou — aguarde o anfitrião", "ru": "Вы вошли — ждите хоста", "it": "Entrato — attendi l'host", "ar": "انضممت — انتظر بدء المضيف" },
  /**
   * ★★★ 2026-10-15 补译【第三批】：★ 首启隐私弹窗 + 其余零散文案
   *   ★ 隐私弹窗是【每个用户第一眼看到的】—— 10 语言下显示英文会砸第一印象
   *   （其中「A-Z」与「 款」是符号/单位，不译）
   */
  "隐私说明": { "ja": "プライバシーについて", "ko": "개인정보 안내", "es": "Privacidad", "fr": "Confidentialité", "de": "Datenschutz", "pt": "Privacidade", "ru": "Конфиденциальность", "it": "Privacy", "ar": "الخصوصية" },
  "查看全文": { "ja": "全文を見る", "ko": "전문 보기", "es": "Ver la política", "fr": "Lire la politique", "de": "Richtlinie lesen", "pt": "Ler a política", "ru": "Читать политику", "it": "Leggi l'informativa", "ar": "قراءة السياسة" },
  "不收集信息 · 只存本地": { "ja": "情報は収集しません · 端末内のみ", "ko": "정보 수집 없음 · 기기 내 저장", "es": "Sin datos · Solo local", "fr": "Aucune donnée · Local", "de": "Keine Daten · Nur lokal", "pt": "Sem dados · Só local", "ru": "Без сбора · Только локально", "it": "Nessun dato · Solo locale", "ar": "لا بيانات · محلي فقط" },
  "不收集你的信息，记录只存在手表里。": { "ja": "情報は収集しません。記録はウォッチ内だけです。", "ko": "정보를 수집하지 않습니다. 기록은 워치에만 저장됩니다.", "es": "No recopilamos datos. Todo queda en el reloj.", "fr": "Aucune donnée collectée. Tout reste sur la montre.", "de": "Keine Datenerhebung. Alles bleibt auf der Uhr.", "pt": "Nenhum dado coletado. Tudo fica no relógio.", "ru": "Данные не собираются. Всё хранится на часах.", "it": "Nessun dato raccolto. Tutto resta sull\'orologio.", "ar": "لا نجمع أي بيانات. كل السجلات على الساعة." },
  "第 {0}/{1} 题 —— 只看正中间第 3 个字母（粉的），先数横线，再看有没有斜线或腿": { "ja": "第{0}/{1}問 —— 中央3番目（ピンク）だけ。まず横線の数、次に斜線や脚", "ko": "{0}/{1}번 — 가운데 3번째(분홍)만. 가로선 개수부터, 다음 사선이나 다리", "es": "{0}/{1}: mira solo el 3.º (rosa). Cuenta las horizontales y busca diagonales o patas", "fr": "{0}/{1} : seulement le 3e (rose). Comptez les horizontales, puis les diagonales ou jambes", "de": "{0}/{1}: nur der 3. (rosa). Erst Querlinien zählen, dann Schrägen oder Beine", "pt": "{0}/{1}: só o 3.º (rosa). Conte as horizontais, depois diagonais ou pernas", "ru": "{0}/{1}: только 3-я (розовая). Сначала горизонтали, затем наклонные и ножки", "it": "{0}/{1}: solo il 3º (rosa). Prima le orizzontali, poi diagonali o gambe", "ar": "{0}/{1}: الثالث فقط (الوردي). اعدد الأفقي ثم المائل أو الأرجل" },
  "同意并继续": { "ja": "同意して続ける", "ko": "동의하고 계속", "es": "Aceptar y continuar", "fr": "Accepter et continuer", "de": "Zustimmen und weiter", "pt": "Aceitar e continuar", "ru": "Принять и продолжить", "it": "Accetta e continua", "ar": "أوافق وأتابع" },
  "打不开链接，请手动访问：": { "ja": "リンクを開けません。手動でアクセスしてください：", "ko": "링크를 열 수 없습니다 — 직접 방문하세요:", "es": "No se pudo abrir el enlace. Visita:", "fr": "Impossible d'ouvrir le lien. Visitez :", "de": "Link lässt sich nicht öffnen. Bitte besuche:", "pt": "Não foi possível abrir o link. Visite:", "ru": "Не удалось открыть ссылку. Перейдите:", "it": "Impossibile aprire il link. Visita:", "ar": "تعذّر فتح الرابط. تفضّل بزيارة:" },
  "网格": { "ja": "グリッド", "ko": "그리드", "es": "Cuadrícula", "fr": "Grille", "de": "Raster", "pt": "Grade", "ru": "Сетка", "it": "Griglia", "ar": "شبكة" },
  "🏆 解锁成就": { "ja": "🏆 実績解除", "ko": "🏆 업적 달성", "es": "🏆 Logro desbloqueado", "fr": "🏆 Succès débloqué", "de": "🏆 Erfolg freigeschaltet", "pt": "🏆 Conquista desbloqueada", "ru": "🏆 Достижение открыто", "it": "🏆 Obiettivo sbloccato", "ar": "🏆 إنجاز مفتوح" },
  "升到 LV": { "ja": "LV 到達", "ko": "LV 도달", "es": "Nivel alcanzado", "fr": "Niveau atteint", "de": "Level erreicht", "pt": "Nível alcançado", "ru": "Уровень достигнут", "it": "Livello raggiunto", "ar": "المستوى المحقَّق" },
  "（我）": { "ja": "（自分）", "ko": "(나)", "es": "(yo)", "fr": "(moi)", "de": "(ich)", "pt": "(eu)", "ru": "(я)", "it": "(io)", "ar": "(أنا)" },
  "反馈与关于": { "ja": "フィードバックと概要", "ko": "피드백 및 정보", "es": "Comentarios y acerca de", "fr": "Retours et à propos", "de": "Feedback & Über", "pt": "Comentários e sobre", "ru": "Отзывы и о приложении", "it": "Feedback e info", "ar": "الملاحظات وحول" },
  "有问题、想加游戏、发现 bug —— 写信给我": { "ja": "不具合・アイデア・追加してほしいゲーム —— メールで教えてください", "ko": "버그·아이디어·추가할 게임 —— 메일로 알려주세요", "es": "Errores, ideas, nuevos juegos — escríbeme", "fr": "Bugs, idées, nouveaux jeux — écris-moi", "de": "Bugs, Ideen, neue Spiele — schreib mir", "pt": "Bugs, ideias, novos jogos — escreva-me", "ru": "Ошибки, идеи, новые игры — напишите мне", "it": "Bug, idee, nuovi giochi — scrivimi", "ar": "أخطاء أو أفكار أو ألعاب جديدة — راسلني" },
  "复制": { "ja": "コピー", "ko": "복사", "es": "Copiar", "fr": "Copier", "de": "Kopieren", "pt": "Copiar", "ru": "Копировать", "it": "Copia", "ar": "نسخ" },
  "已复制 ✓": { "ja": "コピーしました ✓", "ko": "복사됨 ✓", "es": "Copiado ✓", "fr": "Copié ✓", "de": "Kopiert ✓", "pt": "Copiado ✓", "ru": "Скопировано ✓", "it": "Copiato ✓", "ar": "تم النسخ ✓" },
  "不收集任何信息 · 记录只在你手机里": { "ja": "情報を一切収集しません · 記録は端末内だけ", "ko": "어떤 정보도 수집하지 않습니다 · 기록은 기기에만", "es": "No se recopila nada · Todo queda en tu móvil", "fr": "Aucune donnée collectée · Tout reste sur ton téléphone", "de": "Keine Daten gesammelt · Alles bleibt auf deinem Gerät", "pt": "Nada é coletado · Tudo fica no seu aparelho", "ru": "Ничего не собираем · Всё остаётся на устройстве", "it": "Nessun dato raccolto · Tutto resta sul tuo telefono", "ar": "لا نجمع أي بيانات · كل شيء يبقى على جهازك" },
  "复制失败，请手动输入": { "ja": "コピーできません。手動で入力してください", "ko": "복사 실패 — 직접 입력해 주세요", "es": "No se pudo copiar — escríbelo manualmente", "fr": "Échec de la copie — saisis-le manuellement", "de": "Kopieren fehlgeschlagen — bitte manuell eingeben", "pt": "Falha ao copiar — digite manualmente", "ru": "Не удалось скопировать — введите вручную", "it": "Copia non riuscita — inseriscilo manualmente", "ar": "فشل النسخ — اكتبه يدويًا" },

  "游戏": { "ja": "ゲーム", "ko": "게임", "es": "Juegos", "fr": "Jeux", "de": "Spiele", "pt": "Jogos", "ru": "Игры", "it": "Giochi", "ar": "الألعاب", "zh-Hant": "遊戲" },
  "统计": { "ja": "統計", "ko": "통계", "es": "Estadísticas", "fr": "Stats", "de": "Statistik", "pt": "Estatísticas", "ru": "Статистика", "it": "Statistiche", "ar": "إحصائيات", "zh-Hant": "統計" },
  "设置": { "ja": "設定", "ko": "설정", "es": "Ajustes", "fr": "Réglages", "de": "Einstellungen", "pt": "Ajustes", "ru": "Настройки", "it": "Impostazioni", "ar": "الإعدادات", "zh-Hant": "設定" },
  "按喜好挑游戏": { "ja": "好みで選ぶ", "ko": "취향으로 고르기", "es": "Elige por gusto", "fr": "Choisir par goût", "de": "Nach Geschmack", "pt": "Escolha por gosto", "ru": "Выбор по вкусу", "it": "Scegli per gusto", "ar": "اختر حسب ذوقك", "zh-Hant": "按喜好挑遊戲" },
  "今天这一局": { "ja": "今日の一局", "ko": "오늘의 한 판", "es": "La de hoy", "fr": "Celle du jour", "de": "Heutige Runde", "pt": "A de hoje", "ru": "Игра дня", "it": "Quella di oggi", "ar": "جولة اليوم", "zh-Hant": "今天這一局" },
  "随机来一局": { "ja": "ランダムに一局", "ko": "무작위 한 판", "es": "Una al azar", "fr": "Une au hasard", "de": "Zufallsrunde", "pt": "Uma aleatória", "ru": "Случайная игра", "it": "Una a caso", "ar": "جولة عشوائية", "zh-Hant": "隨機來一局" },
  "开始": { "ja": "開始 ›", "ko": "시작 ›", "es": "Jugar ›", "fr": "Jouer ›", "de": "Start ›", "pt": "Jogar ›", "ru": "Играть ›", "it": "Gioca ›", "ar": "ابدأ ›", "zh-Hant": "開始 ›" },
  "全部": { "ja": "すべて", "ko": "전체", "es": "Todo", "fr": "Tout", "de": "Alle", "pt": "Tudo", "ru": "Все", "it": "Tutti", "ar": "الكل", "zh-Hant": "全部" },
  "我收藏的": { "ja": "お気に入り", "ko": "즐겨찾기", "es": "Guardados", "fr": "Favoris", "de": "Gespeichert", "pt": "Salvos", "ru": "Избранное", "it": "Salvati", "ar": "المحفوظة", "zh-Hant": "我收藏的" },
  "玩过的": { "ja": "プレイ済み", "ko": "플레이함", "es": "Jugados", "fr": "Joués", "de": "Gespielt", "pt": "Jogados", "ru": "Игранные", "it": "Giocati", "ar": "الملعوبة", "zh-Hant": "玩過的" },
  "简单": { "ja": "やさしい", "ko": "쉬움", "es": "Fácil", "fr": "Facile", "de": "Leicht", "pt": "Fácil", "ru": "Легко", "it": "Facile", "ar": "سهل", "zh-Hant": "簡單" },
  "普通": { "ja": "ふつう", "ko": "보통", "es": "Normal", "fr": "Normal", "de": "Normal", "pt": "Normal", "ru": "Обычно", "it": "Normale", "ar": "عادي", "zh-Hant": "普通" },
  "困难": { "ja": "むずかしい", "ko": "어려움", "es": "Difícil", "fr": "Difficile", "de": "Schwer", "pt": "Difícil", "ru": "Сложно", "it": "Difficile", "ar": "صعب", "zh-Hant": "困難" },
  "通关了": { "ja": "クリア", "ko": "클리어", "es": "Superados", "fr": "Terminés", "de": "Geschafft", "pt": "Concluídos", "ru": "Пройдено", "it": "Completati", "ar": "مكتملة", "zh-Hant": "通關了" },
  "一共玩了": { "ja": "総プレイ", "ko": "총 플레이", "es": "Partidas", "fr": "Parties", "de": "Partien", "pt": "Partidas", "ru": "Игр всего", "it": "Partite", "ar": "الجولات", "zh-Hant": "一共玩了" },
  "玩了多久": { "ja": "プレイ時間", "ko": "플레이 시간", "es": "Tiempo", "fr": "Temps", "de": "Spielzeit", "pt": "Tempo", "ru": "Время", "it": "Tempo", "ar": "الوقت", "zh-Hant": "玩了多久" },
  "玩过几款": { "ja": "プレイ本数", "ko": "플레이한 수", "es": "Juegos probados", "fr": "Jeux essayés", "de": "Gespielte Spiele", "pt": "Jogos testados", "ru": "Игр опробовано", "it": "Giochi provati", "ar": "الألعاب المجرّبة", "zh-Hant": "玩過幾款" },
  "外观": { "ja": "外観", "ko": "모양", "es": "Aspecto", "fr": "Apparence", "de": "Aussehen", "pt": "Aparência", "ru": "Вид", "it": "Aspetto", "ar": "المظهر", "zh-Hant": "外觀" },
  "外观模式": { "ja": "テーマ", "ko": "테마", "es": "Tema", "fr": "Thème", "de": "Design", "pt": "Tema", "ru": "Тема", "it": "Tema", "ar": "السمة", "zh-Hant": "外觀模式" },
  "语言": { "ja": "言語", "ko": "언어", "es": "Idioma", "fr": "Langue", "de": "Sprache", "pt": "Idioma", "ru": "Язык", "it": "Lingua", "ar": "اللغة", "zh-Hant": "語言" },
  "主题色": { "ja": "アクセント色", "ko": "강조 색", "es": "Color de acento", "fr": "Couleur d'accent", "de": "Akzentfarbe", "pt": "Cor de destaque", "ru": "Акцентный цвет", "it": "Colore accento", "ar": "لون التمييز", "zh-Hant": "主題色" },
  "音效": { "ja": "効果音", "ko": "효과음", "es": "Sonido", "fr": "Son", "de": "Ton", "pt": "Som", "ru": "Звук", "it": "Audio", "ar": "الصوت", "zh-Hant": "音效" },
  "振动反馈": { "ja": "振動", "ko": "진동", "es": "Vibración", "fr": "Vibration", "de": "Vibration", "pt": "Vibração", "ru": "Вибрация", "it": "Vibrazione", "ar": "الاهتزاز", "zh-Hant": "振動回饋" },
  "深色模式": { "ja": "ダークモード", "ko": "다크 모드", "es": "Modo oscuro", "fr": "Mode sombre", "de": "Dunkelmodus", "pt": "Modo escuro", "ru": "Тёмная тема", "it": "Modalità scura", "ar": "الوضع الداكن", "zh-Hant": "深色模式" },
  "浅色": { "ja": "ライト", "ko": "라이트", "es": "Claro", "fr": "Clair", "de": "Hell", "pt": "Claro", "ru": "Светлая", "it": "Chiaro", "ar": "فاتح", "zh-Hant": "淺色" },
  "深色": { "ja": "ダーク", "ko": "다크", "es": "Oscuro", "fr": "Sombre", "de": "Dunkel", "pt": "Escuro", "ru": "Тёмная", "it": "Scuro", "ar": "داكن", "zh-Hant": "深色" },
  "跟随系统": { "ja": "システムに従う", "ko": "시스템 설정", "es": "Seguir al sistema", "fr": "Suivre le système", "de": "System folgen", "pt": "Seguir o sistema", "ru": "Как в системе", "it": "Segui sistema", "ar": "حسب النظام", "zh-Hant": "跟隨系統" },
  "关于": { "ja": "このアプリ", "ko": "정보", "es": "Acerca de", "fr": "À propos", "de": "Über", "pt": "Sobre", "ru": "О приложении", "it": "Informazioni", "ar": "حول", "zh-Hant": "關於" },
  "隐私政策": { "ja": "プライバシー", "ko": "개인정보", "es": "Privacidad", "fr": "Confidentialité", "de": "Datenschutz", "pt": "Privacidade", "ru": "Конфиденциальность", "it": "Privacy", "ar": "الخصوصية", "zh-Hant": "隱私政策" },
  "确定重置": { "ja": "リセットする", "ko": "초기화", "es": "Sí, borrar", "fr": "Oui, effacer", "de": "Ja, löschen", "pt": "Sim, apagar", "ru": "Да, сбросить", "it": "Sì, cancella", "ar": "نعم، امسح", "zh-Hant": "確定重置" },
  "再想想": { "ja": "やめる", "ko": "취소", "es": "Mejor no", "fr": "Annuler", "de": "Doch nicht", "pt": "Deixa", "ru": "Отмена", "it": "Annulla", "ar": "ليس الآن", "zh-Hant": "再想想" },
  "这里还空着": { "ja": "まだ何もありません", "ko": "아직 비어 있어요", "es": "Aún no hay nada", "fr": "Encore vide", "de": "Noch leer", "pt": "Ainda vazio", "ru": "Пока пусто", "it": "Ancora vuoto", "ar": "لا شيء بعد", "zh-Hant": "這裡還空著" },
  "等级、通关记录、玩过的游戏、收藏和统计都会归零，删了就找不回来了。": { "ja": "レベル・クリア記録・プレイ済み・お気に入り・統計がすべてゼロに戻ります。元に戻せません。", "ko": "레벨, 클리어 기록, 플레이한 게임, 즐겨찾기, 통계가 모두 0이 됩니다. 되돌릴 수 없어요.", "es": "Nivel, partidas, juegos jugados, guardados y estadísticas vuelven a cero. No se puede deshacer.", "fr": "Niveau, parties, jeux joués, favoris et stats reviennent à zéro. Irréversible.", "de": "Level, Erfolge, gespielte Spiele, Favoriten und Statistik gehen auf null. Nicht umkehrbar.", "pt": "Nível, partidas, jogos jogados, salvos e estatísticas voltam a zero. Não dá para desfazer.", "ru": "Уровень, рекорды, сыгранные игры, избранное и статистика обнулятся. Отменить нельзя.", "it": "Livello, partite, giochi giocati, salvati e statistiche tornano a zero. Non si può annullare.", "ar": "سيعود المستوى والسجلات والألعاب المحفوظة والإحصائيات إلى الصفر. لا يمكن التراجع.", "zh-Hant": "等級、通關記錄、玩過的遊戲、收藏和統計都會歸零，刪了就找不回來了。" },
  "局域网对战": { "ja": "LAN対戦", "ko": "LAN 대전", "es": "Juego en LAN", "fr": "Jeu en LAN", "de": "LAN-Spiel", "pt": "Jogo em LAN", "ru": "Игра по LAN", "it": "Gioco in LAN", "ar": "لعب محلي", "zh-Hant": "局域網對戰" },
  "已达最高等级": { "ja": "最高レベル", "ko": "최고 레벨", "es": "Nivel máximo", "fr": "Niveau max", "de": "Höchste Stufe", "pt": "Nível máximo", "ru": "Максимум", "it": "Livello massimo", "ar": "أعلى مستوى", "zh-Hant": "已達最高等級" },
  "记录只存在你手机里，不上传、不联网也能看": { "ja": "記録は端末の中だけ。送信も通信も不要", "ko": "기록은 기기 안에만. 전송도 통신도 없음", "es": "Todo se queda en tu teléfono, sin subidas", "fr": "Tout reste sur votre téléphone", "de": "Alles bleibt auf deinem Gerät", "pt": "Tudo fica no seu telefone", "ru": "Всё остаётся на телефоне", "it": "Tutto resta sul telefono", "ar": "كل شيء يبقى على هاتفك", "zh-Hant": "記錄只存在你手機裡，不上傳、不聯網也能看" },
  "最近玩过的": { "ja": "最近プレイ", "ko": "최근 플레이", "es": "Recientes", "fr": "Récents", "de": "Zuletzt gespielt", "pt": "Recentes", "ru": "Недавние", "it": "Recenti", "ar": "الأحدث", "zh-Hant": "最近玩過的" },
  "玩得最多的": { "ja": "よく遊ぶ", "ko": "많이 한 게임", "es": "Más jugados", "fr": "Les plus joués", "de": "Meistgespielt", "pt": "Mais jogados", "ru": "Чаще всего", "it": "Più giocati", "ar": "الأكثر لعباً", "zh-Hant": "玩得最多的" },
  "成就": { "ja": "🏅 実績", "ko": "🏅 업적", "es": "🏅 Logros", "fr": "🏅 Succès", "de": "🏅 Erfolge", "pt": "🏅 Conquistas", "ru": "🏅 Достижения", "it": "🏅 Obiettivi", "ar": "🏅 الإنجازات", "zh-Hant": "🏅 成就" },
  "看全部": { "ja": "すべて見る", "ko": "전체 보기", "es": "Ver todo", "fr": "Tout voir", "de": "Alle ansehen", "pt": "Ver tudo", "ru": "Смотреть все", "it": "Vedi tutto", "ar": "عرض الكل", "zh-Hant": "看全部" },
  "收起": { "ja": "閉じる ▲", "ko": "접기 ▲", "es": "Menos ▲", "fr": "Reduire ▲", "de": "Weniger ▲", "pt": "Menos ▲", "ru": "Свернуть ▲", "it": "Meno ▲", "ar": "أقل ▲", "zh-Hant": "收起 ▲" },
  "游戏徽章": { "ja": "🎖️ ゲームバッジ", "ko": "🎖️ 게임 배지", "es": "🎖️ Insignias", "fr": "🎖️ Badges", "de": "🎖️ Abzeichen", "pt": "🎖️ Emblemas", "ru": "🎖️ Значки", "it": "🎖️ Distintivi", "ar": "🎖️ الأوسمة", "zh-Hant": "🎖️ 遊戲徽章" },
  "还没有徽章——通关任意一局就点亮": { "ja": "まだバッジなし。1回クリアで点灯", "ko": "아직 배지 없음. 한 판 클리어 시 획득", "es": "Sin insignias: supera una partida", "fr": "Aucun badge — terminez une partie", "de": "Noch keine Abzeichen", "pt": "Sem emblemas — conclua uma partida", "ru": "Значков нет — пройдите игру", "it": "Nessun distintivo", "ar": "لا أوسمة بعد", "zh-Hant": "還沒有徽章——通關任意一局就點亮" },
  "切换后界面立刻变，游戏名也会跟着换": { "ja": "切り替えると即座に反映。ゲーム名も変わります", "ko": "바꾸면 바로 적용되고 게임 이름도 바뀝니다", "es": "Cambia al instante, también los nombres", "fr": "Change instantanément, noms inclus", "de": "Wechselt sofort, auch Spieletitel", "pt": "Muda na hora, inclusive os nomes", "ru": "Меняется сразу, включая названия", "it": "Cambia subito, nomi inclusi", "ar": "يتغير فوراً مع أسماء الألعاب", "zh-Hant": "切換後介面立刻變，遊戲名也會跟著換" },
  "同一 Wi-Fi 下两台设备直接对局，没有服务器": { "ja": "同じWi-Fiの2台で直接対戦。サーバー不要", "ko": "같은 Wi-Fi의 두 기기로 직접 대전. 서버 없음", "es": "Dos dispositivos en la misma Wi-Fi, sin servidor", "fr": "Deux appareils sur le même Wi-Fi, sans serveur", "de": "Zwei Geräte im selben WLAN, kein Server", "pt": "Dois aparelhos no mesmo Wi-Fi, sem servidor", "ru": "Два устройства в одной сети, без сервера", "it": "Due dispositivi sullo stesso Wi-Fi, senza server", "ar": "جهازان على نفس الشبكة، بلا خادم", "zh-Hant": "同一 Wi-Fi 下兩台裝置直接對局，沒有伺服器" },
  "游戏偏好": { "ja": "ゲーム設定", "ko": "게임 설정", "es": "Juego", "fr": "Jeu", "de": "Spiel", "pt": "Jogo", "ru": "Игра", "it": "Gioco", "ar": "اللعب", "zh-Hant": "遊戲偏好" },
  "通关、失败、点按都有声音": { "ja": "クリア・失敗・タップで音", "ko": "클리어, 실패, 탭에 소리", "es": "Sonido al ganar, fallar y tocar", "fr": "Sons pour victoire, échec, appui", "de": "Ton bei Sieg, Niederlage, Tippen", "pt": "Som ao vencer, falhar e tocar", "ru": "Звук при победе, проигрыше, нажатии", "it": "Suoni per vittoria, sconfitta, tocco", "ar": "صوت عند الفوز والخسارة واللمس", "zh-Hant": "通關、失敗、點按都有聲音" },
  "答对时轻轻震一下": { "ja": "正解で軽く振動", "ko": "정답이면 살짝 진동", "es": "Vibra al acertar", "fr": "Vibre si c'est juste", "de": "Kurzes Vibrieren bei richtig", "pt": "Vibra ao acertar", "ru": "Вибро при верном ответе", "it": "Vibra se giusto", "ar": "اهتزاز عند الإجابة الصحيحة", "zh-Hant": "答對時輕輕震一下" },
  "游戏时屏幕常亮": { "ja": "プレイ中は画面を消さない", "ko": "게임 중 화면 켜짐", "es": "Pantalla siempre activa", "fr": "Écran toujours allumé", "de": "Bildschirm bleibt an", "pt": "Tela sempre ligada", "ru": "Экран не гаснет", "it": "Schermo sempre acceso", "ar": "إبقاء الشاشة مضاءة", "zh-Hant": "遊戲時螢幕常亮" },
  "玩的时候屏幕不会自己黑掉": { "ja": "プレイ中は画面が暗くなりません", "ko": "게임 중 화면이 꺼지지 않아요", "es": "La pantalla no se apaga", "fr": "L'écran ne s'éteint pas", "de": "Der Bildschirm dunkelt nicht ab", "pt": "A tela não escurece", "ru": "Экран не затемняется", "it": "Lo schermo non si spegne", "ar": "لن تخبو الشاشة", "zh-Hant": "玩的時候螢幕不會自己黑掉" },
  "数据": { "ja": "データ", "ko": "데이터", "es": "Datos", "fr": "Données", "de": "Daten", "pt": "Dados", "ru": "Данные", "it": "Dati", "ar": "البيانات", "zh-Hant": "資料" },
  "重置进度": { "ja": "進行をリセット", "ko": "진행 초기화", "es": "Borrar progreso", "fr": "Réinitialiser", "de": "Fortschritt löschen", "pt": "Apagar progresso", "ru": "Сбросить прогресс", "it": "Azzera progressi", "ar": "مسح التقدم", "zh-Hant": "重置進度" },
  "点一下直接续上": { "ja": "タップで続きから", "ko": "탭하면 이어서", "es": "Toca para continuar", "fr": "Touchez pour reprendre", "de": "Tippen zum Fortsetzen", "pt": "Toque para continuar", "ru": "Нажмите, чтобы продолжить", "it": "Tocca per continuare", "ar": "اضغط للمتابعة", "zh-Hant": "點一下直接續上" },
  "按玩的次数排": { "ja": "プレイ回数順", "ko": "플레이 횟수순", "es": "Por partidas", "fr": "Par parties", "de": "Nach Partien", "pt": "Por partidas", "ru": "По числу игр", "it": "Per partite", "ar": "حسب عدد الجولات", "zh-Hant": "按玩的次數排" },
  "每款游戏 4 档：首通 · 熟练 10 次 · 精通 50 次 · 大师 100 次": { "ja": "各ゲーム4段階：初クリア・10回・50回・100回", "ko": "게임당 4단계: 첫 클리어 · 10회 · 50회 · 100회", "es": "4 niveles: primer pase, 10, 50 y 100 veces", "fr": "4 paliers : 1re réussite, 10, 50, 100 fois", "de": "4 Stufen: erstmals, 10, 50, 100 Mal", "pt": "4 níveis: primeira, 10, 50, 100 vezes", "ru": "4 уровня: первый раз, 10, 50, 100 раз", "it": "4 livelli: primo, 10, 50, 100 volte", "ar": "4 مراحل: أول مرة، 10، 50، 100", "zh-Hant": "每款遊戲 4 檔：首通 · 熟練 10 次 · 精通 50 次 · 大師 100 次" },
  "今日已打卡": { "ja": "✅ 今日チェックイン済み", "ko": "✅ 오늘 체크인 완료", "es": "✅ Marcado hoy", "fr": "✅ Fait aujourd hui", "de": "✅ Heute erledigt", "pt": "✅ Marcado hoje", "ru": "✅ Отмечено сегодня", "it": "✅ Fatto oggi", "ar": "✅ تم اليوم", "zh-Hant": "✅ 今日已打卡" },
  "还没玩 · 来一局就打卡": { "ja": "⭕ 未プレイ・1回で達成", "ko": "⭕ 아직 없음 · 한 판 하면 완료", "es": "⭕ Nada aún: juega una", "fr": "⭕ Rien encore — jouez", "de": "⭕ Noch nichts — spiel eine", "pt": "⭕ Nada ainda — jogue uma", "ru": "⭕ Пока пусто — сыграйте", "it": "⭕ Ancora nulla — gioca", "ar": "⭕ لا شيء بعد — العب جولة", "zh-Hant": "⭕ 還沒玩 · 來一局就打卡" },
  "调成你顺手的样子，随时都能改": { "ja": "使いやすく調整。いつでも変更可", "ko": "편하게 맞추세요. 언제든 변경", "es": "Ajusta a tu gusto, cuando quieras", "fr": "Ajustez a votre gout, a tout moment", "de": "Nach Wunsch anpassen, jederzeit", "pt": "Ajuste do seu jeito, quando quiser", "ru": "Настройте под себя в любой момент", "it": "Regola a piacere, quando vuoi", "ar": "اضبطه كما تحب في أي وقت", "zh-Hant": "調成你順手的樣子，隨時都能改" },
  "一直用浅色": { "ja": "常にライト", "ko": "항상 라이트", "es": "Siempre claro", "fr": "Toujours clair", "de": "Immer hell", "pt": "Sempre claro", "ru": "Всегда светлая", "it": "Sempre chiaro", "ar": "فاتح دائماً", "zh-Hant": "一直用淺色" },
  "一直用深色，纯黑省电": { "ja": "常にダーク。純黒で省電力", "ko": "항상 다크. 순검정은 절전", "es": "Siempre oscuro: negro puro ahorra", "fr": "Toujours sombre : noir = economie", "de": "Immer dunkel — Schwarz spart Strom", "pt": "Sempre escuro: preto puro poupa", "ru": "Всегда тёмная — экономит заряд", "it": "Sempre scuro: nero puro risparmia", "ar": "داكن دائماً: الأسود يوفر الطاقة", "zh-Hant": "一直用深色，純黑省電" },
  "难度自证": { "ja": "🔍 難易度チェック", "ko": "🔍 난이도 확인", "es": "🔍 Comprobar dificultad", "fr": "🔍 Verif. difficulte", "de": "🔍 Schwierigkeit", "pt": "🔍 Conferir dificuldade", "ru": "🔍 Проверка сложности", "it": "🔍 Verifica difficolta", "ar": "🔍 تحقق الصعوبة", "zh-Hant": "🔍 難度自證" },
  "按钮和高亮都跟着换成这个颜色": { "ja": "ボタンとハイライトがこの色に", "ko": "버튼과 강조가 이 색으로", "es": "Botones y resaltados toman este color", "fr": "Boutons et surbrillances suivent", "de": "Buttond und Akzente folgen dieser Farbe", "pt": "Botoes e destaques seguem esta cor", "ru": "Кнопки и акценты в этом цвете", "it": "Pulsanti ed evidenze seguono", "ar": "تتبع الأزرار هذا اللون", "zh-Hant": "按鈕和高亮都跟著換成這個顏色" },
  "真的要清空吗？": { "ja": "本当に消しますか？", "ko": "정말 지울까요?", "es": "¿Borrar todo?", "fr": "Tout effacer ?", "de": "Wirklich alles löschen?", "pt": "Apagar tudo mesmo?", "ru": "Точно всё стереть?", "it": "Cancellare tutto?", "ar": "هل تمسح كل شيء؟", "zh-Hant": "真的要清空嗎？" },
  "今天已完成": { "ja": "今日は完了", "ko": "오늘 완료", "es": "Hecho hoy", "fr": "Fait aujourd hui", "de": "Heute erledigt", "pt": "Feito hoje", "ru": "Сегодня готово", "it": "Fatto oggi", "ar": "تم اليوم", "zh-Hant": "今天已完成" },
  "通关 +50 经验": { "ja": "クリアで +50 EXP", "ko": "클리어 +50 XP", "es": "Superar: +50 XP", "fr": "Reussir : +50 XP", "de": "Schaffen: +50 XP", "pt": "Concluir: +50 XP", "ru": "Пройти: +50 XP", "it": "Completa: +50 XP", "ar": "أكمل: +50 خبرة", "zh-Hant": "通關 +50 經驗" },
  "再看看": { "ja": "見る", "ko": "보기", "es": "Ver", "fr": "Voir", "de": "Ansehen", "pt": "Ver", "ru": "Смотреть", "it": "Vedi", "ar": "عرض", "zh-Hant": "再看看" },
  "挑不出来？交给运气": { "ja": "選べない？運に任せて", "ko": "못 고르겠으면? 운에 맡겨요", "es": "¿Indeciso? Dejalo al azar", "fr": "Indecis ? Au hasard", "de": "Unentschlossen? Zufall", "pt": "Indeciso? Deixe a sorte", "ru": "Не выбрать? Доверьтесь удаче", "it": "Indeciso? Lascia al caso", "ar": "متردد؟ اتركه للحظ", "zh-Hant": "挑不出來？交給運氣" },
  "清空": { "ja": "消去", "ko": "비우기", "es": "Borrar", "fr": "Effacer", "de": "Löschen", "pt": "Apagar", "ru": "Очистить", "it": "Cancella", "ar": "مسح", "zh-Hant": "清空" },
  "展开": { "ja": "もっと ▼", "ko": "펼치기 ▼", "es": "Mas ▼", "fr": "Plus ▼", "de": "Mehr ▼", "pt": "Mais ▼", "ru": "Развернуть ▼", "it": "Altro ▼", "ar": "المزيد ▼", "zh-Hant": "展開 ▼" },
  "通关": { "ja": "クリア", "ko": "클리어", "es": "Superados", "fr": "Termines", "de": "Geschafft", "pt": "Concluidos", "ru": "Пройдено", "it": "Completati", "ar": "مكتملة", "zh-Hant": "通關" },
  "怎么玩": { "ja": "遊び方", "ko": "플레이 방법", "es": "Como jugar", "fr": "Comment jouer", "de": "So geht es", "pt": "Como jogar", "ru": "Как играть", "it": "Come si gioca", "ar": "كيف تلعب", "zh-Hant": "怎麼玩" },
  "一句话": { "ja": "ひとことで", "ko": "한 줄 요약", "es": "En una linea", "fr": "En une ligne", "de": "In einem Satz", "pt": "Em uma linha", "ru": "Одной строкой", "it": "In una riga", "ar": "في سطر", "zh-Hant": "一句話" },
  "玩法要点": { "ja": "ポイント", "ko": "핵심", "es": "Puntos clave", "fr": "Points cles", "de": "Kernpunkte", "pt": "Pontos-chave", "ru": "Главное", "it": "Punti chiave", "ar": "النقاط الأساسية", "zh-Hant": "玩法要點" },
  "通用操作": { "ja": "共通操作", "ko": "공통 조작", "es": "Controles", "fr": "Commandes", "de": "Steuerung", "pt": "Controles", "ru": "Управление", "it": "Comandi", "ar": "التحكم", "zh-Hant": "通用操作" },
  "得分": { "ja": "スコア", "ko": "점수", "es": "Puntos", "fr": "Score", "de": "Punkte", "pt": "Pontos", "ru": "Очки", "it": "Punti", "ar": "النقاط", "zh-Hant": "得分" },
  "用时": { "ja": "タイム", "ko": "시간", "es": "Tiempo", "fr": "Temps", "de": "Zeit", "pt": "Tempo", "ru": "Время", "it": "Tempo", "ar": "الوقت", "zh-Hant": "用時" },
  "经验": { "ja": "EXP", "ko": "경험치", "es": "XP", "fr": "XP", "de": "XP", "pt": "XP", "ru": "Опыт", "it": "XP", "ar": "خبرة", "zh-Hant": "經驗" },
  "重扫": { "ja": "再検索", "ko": "다시 찾기", "es": "Buscar otra vez", "fr": "Relancer", "de": "Neu suchen", "pt": "Buscar de novo", "ru": "Искать снова", "it": "Ricerca", "ar": "إعادة البحث", "zh-Hant": "重掃" },
  "连接": { "ja": "接続", "ko": "연결", "es": "Conectar", "fr": "Connecter", "de": "Verbinden", "pt": "Conectar", "ru": "Подключить", "it": "Connetti", "ar": "اتصال", "zh-Hant": "連接" },
  "加入": { "ja": "参加", "ko": "참가", "es": "Unirse", "fr": "Rejoindre", "de": "Beitreten", "pt": "Entrar", "ru": "Войти", "it": "Unisciti", "ar": "انضم", "zh-Hant": "加入" },
  "开始玩": { "ja": "プレイ開始", "ko": "플레이 시작", "es": "Empezar a jugar", "fr": "Commencer", "de": "Losspielen", "pt": "Comecar a jogar", "ru": "Начать игру", "it": "Inizia a giocare", "ar": "ابدأ اللعب", "zh-Hant": "開始玩" },
  "结算弹窗": { "ja": "結果画面", "ko": "결과 창", "es": "Resumen", "fr": "Resultat", "de": "Ergebnis", "pt": "Resultado", "ru": "Итоги", "it": "Riepilogo", "ar": "النتيجة", "zh-Hant": "結算彈窗" },
  "再来一局": { "ja": "もう一局", "ko": "한 판 더", "es": "Otra partida", "fr": "Rejouer", "de": "Nochmal", "pt": "Jogar de novo", "ru": "Ещё раз", "it": "Ancora", "ar": "جولة أخرى", "zh-Hant": "再來一局" },
  "返回列表": { "ja": "一覧へ戻る", "ko": "목록으로", "es": "Volver a la lista", "fr": "Retour a la liste", "de": "Zurueck zur Liste", "pt": "Voltar a lista", "ru": "К списку", "it": "Torna alla lista", "ar": "عودة إلى القائمة", "zh-Hant": "返回列表" },
  "玩哪一款": { "ja": "どれで遊ぶ？", "ko": "무엇을 할까요", "es": "Elige un juego", "fr": "Choisissez un jeu", "de": "Spiel waehlen", "pt": "Escolha um jogo", "ru": "Выберите игру", "it": "Scegli un gioco", "ar": "اختر لعبة", "zh-Hant": "玩哪一款" },
  "连上了！": { "ja": "接続しました！", "ko": "연결됐어요!", "es": "¡Conectado!", "fr": "Connecte !", "de": "Verbunden!", "pt": "Conectado!", "ru": "Подключено!", "it": "Connesso!", "ar": "تم الاتصال!", "zh-Hant": "連上了！" },
  "重开这一局": { "ja": "この局をやり直す", "ko": "이 판 다시 시작", "es": "Reiniciar ronda", "fr": "Recommencer", "de": "Runde neu starten", "pt": "Reiniciar rodada", "ru": "Начать заново", "it": "Ricomincia", "ar": "أعد الجولة", "zh-Hant": "重開這一局" },
  "这款的成就": { "ja": "このゲームの実績", "ko": "이 게임 업적", "es": "Logros de este juego", "fr": "Succes du jeu", "de": "Erfolge dieses Spiels", "pt": "Conquistas do jogo", "ru": "Достижения игры", "it": "Obiettivi del gioco", "ar": "إنجازات اللعبة", "zh-Hant": "這款的成就" },
  "再来一局？": { "ja": "もう一局やる？", "ko": "한 판 더?", "es": "¿Otra partida?", "fr": "Rejouer ?", "de": "Noch eine Runde?", "pt": "Mais uma?", "ru": "Ещё раз?", "it": "Ancora una?", "ar": "جولة أخرى؟", "zh-Hant": "再來一局？" },
  "已连上房主": { "ja": "ホストに接続しました", "ko": "호스트에 연결됨", "es": "Conectado al anfitrion", "fr": "Connecte a l hote", "de": "Mit Host verbunden", "pt": "Conectado ao anfitriao", "ru": "Подключено к хосту", "it": "Connesso all host", "ar": "تم الاتصال بالمضيف", "zh-Hant": "已連上房主" },
  "换一款玩玩？": { "ja": "別のゲームは？", "ko": "다른 게임은?", "es": "¿Otro juego?", "fr": "Un autre jeu ?", "de": "Ein anderes Spiel?", "pt": "Outro jogo?", "ru": "Другую игру?", "it": "Un altro gioco?", "ar": "لعبة أخرى؟", "zh-Hant": "換一款玩玩？" },
  "这一局拿下！": { "ja": "クリア！", "ko": "클리어!", "es": "¡Superado!", "fr": "Reussi !", "de": "Geschafft!", "pt": "Concluido!", "ru": "Пройдено!", "it": "Completato!", "ar": "أُنجزت!", "zh-Hant": "這一局拿下！" },
  "对手已连上！": { "ja": "相手が接続しました！", "ko": "상대가 연결됐어요!", "es": "¡Rival conectado!", "fr": "Adversaire connecte !", "de": "Gegner verbunden!", "pt": "Rival conectado!", "ru": "Соперник подключён!", "it": "Avversario connesso!", "ar": "تم اتصال الخصم!", "zh-Hant": "對手已連上！" },
  "返回游戏列表": { "ja": "ゲーム一覧へ", "ko": "게임 목록으로", "es": "Volver a los juegos", "fr": "Retour aux jeux", "de": "Zurueck zu den Spielen", "pt": "Voltar aos jogos", "ru": "К списку игр", "it": "Torna ai giochi", "ar": "عودة إلى الألعاب", "zh-Hant": "返回遊戲列表" },
  "你的权利": { "ja": "あなたの権利", "ko": "당신의 권리", "es": "Tus derechos", "fr": "Vos droits", "de": "Ihre Rechte", "pt": "Seus direitos", "ru": "Ваши права", "it": "I tuoi diritti", "ar": "حقوقك", "zh-Hant": "你的權利" },
  "合规声明": { "ja": "コンプライアンス", "ko": "준법 선언", "es": "Cumplimiento", "fr": "Conformite", "de": "Compliance", "pt": "Conformidade", "ru": "Соответствие", "it": "Conformita", "ar": "الامتثال", "zh-Hant": "合規聲明" },
  "六、你的权利": { "ja": "六、あなたの権利", "ko": "6. 당신의 권리", "es": "6. Tus derechos", "fr": "6. Vos droits", "de": "6. Ihre Rechte", "pt": "6. Seus direitos", "ru": "6. Ваши права", "it": "6. I tuoi diritti", "ar": "6. حقوقك", "zh-Hant": "六、你的權利" },
  "七、合规声明": { "ja": "七、コンプライアンス", "ko": "7. 준법 선언", "es": "7. Cumplimiento", "fr": "7. Conformite", "de": "7. Compliance", "pt": "7. Conformidade", "ru": "7. Соответствие", "it": "7. Conformita", "ar": "7. الامتثال", "zh-Hant": "七、合規聲明" },
  "三、第三方服务": { "ja": "三、第三者サービス", "ko": "3. 제3자 서비스", "es": "3. Servicios de terceros", "fr": "3. Services tiers", "de": "3. Drittanbieter", "pt": "3. Servicos de terceiros", "ru": "3. Сторонние сервисы", "it": "3. Servizi di terzi", "ar": "3. خدمات الطرف الثالث", "zh-Hant": "三、第三方服務" },
  "四、桌面服务卡片": { "ja": "四、ホーム画面ウィジェット", "ko": "4. 홈 화면 위젯", "es": "4. Widget de inicio", "fr": "4. Widget d accueil", "de": "4. Startbildschirm-Widget", "pt": "4. Widget de tela inicial", "ru": "4. Виджет на главном экране", "it": "4. Widget di sistema", "ar": "4. أداة الشاشة الرئيسية", "zh-Hant": "四、桌面服務卡片" },
  "五、未成年人保护": { "ja": "五、未成年者の保護", "ko": "5. 미성년자 보호", "es": "5. Proteccion de menores", "fr": "5. Protection des mineurs", "de": "5. Schutz Minderjaehriger", "pt": "5. Protecao de menores", "ru": "5. Защита несовершеннолетних", "it": "5. Tutela dei minori", "ar": "5. حماية القاصرين", "zh-Hant": "五、未成年人保護" },
  "一、我们不收集哪些信息": { "ja": "一、収集しない情報", "ko": "1. 수집하지 않는 정보", "es": "1. Lo que no recogemos", "fr": "1. Ce que nous ne collectons pas", "de": "1. Was wir nicht erheben", "pt": "1. O que nao coletamos", "ru": "1. Что мы не собираем", "it": "1. Cosa non raccogliamo", "ar": "1. ما لا نجمعه", "zh-Hant": "一、我們不收集哪些資訊" },
  "二、应用会在本地保存什么": { "ja": "二、端末に保存するもの", "ko": "2. 기기에 저장되는 것", "es": "2. Que se guarda en tu movil", "fr": "2. Ce qui reste sur l appareil", "de": "2. Was lokal gespeichert wird", "pt": "2. O que fica no aparelho", "ru": "2. Что хранится на устройстве", "it": "2. Cosa resta sul dispositivo", "ar": "2. ما يُحفظ على جهازك", "zh-Hant": "二、應用會在本機保存什麼" },
  "这一款还在路上": { "ja": "このゲームは準備中", "ko": "이 게임은 준비 중", "es": "Este juego va en camino", "fr": "Ce jeu arrive bientot", "de": "Dieses Spiel kommt noch", "pt": "Este jogo vem ai", "ru": "Эта игра ещё в пути", "it": "Questo gioco arrivera", "ar": "هذه اللعبة قادمة", "zh-Hant": "這一款還在路上" },
  "先填房主 IP": { "ja": "まずホストのIPを入力", "ko": "먼저 호스트 IP 입력", "es": "Escribe la IP del anfitrion", "fr": "Saisissez l IP de l hote", "de": "Zuerst Host-IP eingeben", "pt": "Digite o IP do anfitriao", "ru": "Сначала введите IP хоста", "it": "Inserisci l IP dell host", "ar": "أدخل عنوان المضيف أولاً", "zh-Hant": "先填房主 IP" },
  "收到对手消息：": { "ja": "相手からの受信：", "ko": "상대 메시지: ", "es": "Mensaje del rival: ", "fr": "Message recu : ", "de": "Nachricht: ", "pt": "Mensagem do rival: ", "ru": "Сообщение соперника: ", "it": "Messaggio ricevuto: ", "ar": "رسالة من الخصم: ", "zh-Hant": "收到對手訊息：" },
  "选一款游戏开始吧": { "ja": "ゲームを選んで開始", "ko": "게임을 골라 시작하세요", "es": "Elige un juego para empezar", "fr": "Choisissez un jeu", "de": "Waehle ein Spiel", "pt": "Escolha um jogo", "ru": "Выберите игру", "it": "Scegli un gioco", "ar": "اختر لعبة لتبدأ", "zh-Hant": "選一款遊戲開始吧" },
  "连上了！等对手开局": { "ja": "接続完了！相手の開始待ち", "ko": "연결됨! 상대 시작 대기", "es": "¡Conectado! Esperando al rival", "fr": "Connecte ! En attente", "de": "Verbunden! Warte auf Gegner", "pt": "Conectado! Aguardando", "ru": "Подключено! Ждём соперника", "it": "Connesso! Attendo", "ar": "تم الاتصال! بانتظار الخصم", "zh-Hant": "連上了！等對手開局" },
  "可得经验值，等级会涨": { "ja": "EXPがもらえ、レベルが上がる", "ko": "경험치를 얻고 레벨이 오릅니다", "es": "Gana XP y sube de nivel", "fr": "Gagne de l XP et monte de niveau", "de": "Bringt XP und Level", "pt": "Ganha XP e sobe de nivel", "ru": "Даёт опыт и уровень", "it": "Da XP e sale di livello", "ar": "يمنح خبرة ويرفع المستوى", "zh-Hant": "可得經驗值，等級會漲" },
  "开个房间（我来当房主）": { "ja": "部屋を作る（ホスト）", "ko": "방 만들기 (호스트)", "es": "Crear sala (ser anfitrion)", "fr": "Creer une salle (hote)", "de": "Raum erstellen (Host)", "pt": "Criar sala (anfitriao)", "ru": "Создать комнату (хост)", "it": "Crea stanza (host)", "ar": "أنشئ غرفة (مضيف)", "zh-Hant": "開個房間（我來當房主）" },
  "连不上，可能房主退出了": { "ja": "接続不可。ホストが退出したかも", "ko": "연결 실패. 호스트가 나갔을 수 있어요", "es": "No conecta: quiza salio el anfitrion", "fr": "Echec : l hote est peut-etre parti", "de": "Kein Verbindung: Host evtl. weg", "pt": "Nao conecta: anfitriao pode ter saido", "ru": "Не подключиться: хост вышел", "it": "Connessione fallita: host assente", "ar": "تعذر الاتصال: ربما خرج المضيف", "zh-Hant": "連不上，可能房主退出了" },
  "扫不到？直接输房主 IP": { "ja": "見つからない？ホストIPを直接入力", "ko": "안 보이나요? 호스트 IP 직접 입력", "es": "¿Nada? Escribe la IP del anfitrion", "fr": "Rien trouve ? Saisissez l IP", "de": "Nichts gefunden? Host-IP eingeben", "pt": "Nada? Digite o IP do anfitriao", "ru": "Не нашли? Введите IP хоста", "it": "Niente? Inserisci l IP", "ar": "لم تجد؟ أدخل عنوان المضيف", "zh-Hant": "掃不到？直接輸房主 IP" },
  "开房失败，检查 Wi-Fi": { "ja": "作成失敗。Wi-Fiを確認", "ko": "방 생성 실패. Wi-Fi 확인", "es": "Fallo al crear: revisa el Wi-Fi", "fr": "Echec : verifiez le Wi-Fi", "de": "Fehlgeschlagen: WLAN pruefen", "pt": "Falhou: confira o Wi-Fi", "ru": "Не удалось: проверьте Wi-Fi", "it": "Creazione fallita: controlla il Wi-Fi", "ar": "تعذر الإنشاء: تحقق من الواي فاي", "zh-Hant": "開房失敗，檢查 Wi-Fi" },
  "收藏这一款（在游戏页右上角）": { "ja": "お気に入り（ゲーム画面右上）", "ko": "즐겨찾기 (게임 화면 오른쪽 위)", "es": "Guardar (arriba a la derecha)", "fr": "Favori (en haut a droite)", "de": "Merken (oben rechts)", "pt": "Salvar (canto superior direito)", "ru": "В избранное (справа вверху)", "it": "Salva (in alto a destra)", "ar": "حفظ (أعلى اليمين)", "zh-Hant": "收藏這一款（在遊戲頁右上角）" },
  "跟着手机设置走，白天黑夜自动换": { "ja": "端末設定に追従。昼夜で自動切替", "ko": "기기 설정을 따름. 낮밤 자동 전환", "es": "Sigue al movil: cambia solo", "fr": "Suit le telephone", "de": "Folgt dem Geraet", "pt": "Segue o aparelho", "ru": "Как в системе", "it": "Segue il telefono", "ar": "يتبع إعدادات هاتفك", "zh-Hant": "跟著手機設定走，白天黑夜自動換" },
  "正在找同一 Wi-Fi 下的房间…": { "ja": "同じWi-Fiの部屋を検索中…", "ko": "같은 Wi-Fi의 방을 찾는 중…", "es": "Buscando salas en tu Wi-Fi…", "fr": "Recherche de salles…", "de": "Suche Raeume im WLAN…", "pt": "Procurando salas no Wi-Fi…", "ru": "Ищем комнаты в Wi-Fi…", "it": "Cerco stanze sul Wi-Fi…", "ar": "أبحث عن غرف على شبكتك…", "zh-Hant": "正在找同一 Wi-Fi 下的房間…" },
  "没找到房间 —— 让对手点「开个房间」": { "ja": "部屋なし —— 相手に作成を依頼", "ko": "방 없음 — 상대에게 생성을 요청", "es": "Sin salas: pide al rival que cree una", "fr": "Aucune salle — demandez a l hote", "de": "Kein Raum — Gegner soll erstellen", "pt": "Sem salas — peca ao rival", "ru": "Комнат нет — пусть соперник создаст", "it": "Nessuna stanza — chiedi all host", "ar": "لا غرف — اطلب من الخصم الإنشاء", "zh-Hant": "沒找到房間 —— 讓對手點「開個房間」" },
  "连不上 —— 检查 IP 和 Wi-Fi": { "ja": "接続不可 —— IPとWi-Fiを確認", "ko": "연결 실패 — IP와 Wi-Fi 확인", "es": "No conecta: revisa IP y Wi-Fi", "fr": "Echec : verifiez IP et Wi-Fi", "de": "Keine Verbindung: IP/WLAN pruefen", "pt": "Nao conecta: confira IP e Wi-Fi", "ru": "Нет связи: проверьте IP и Wi-Fi", "it": "Non connesso: controlla IP e Wi-Fi", "ar": "تعذر الاتصال: تحقق من العنوان", "zh-Hant": "連不上 —— 檢查 IP 和 Wi-Fi" },
  "354 款小游戏，不用联网也能玩": { "ja": "354本のミニゲーム。通信不要", "ko": "354개 미니게임. 인터넷 불필요", "es": "354 juegos, sin conexion", "fr": "354 jeux, sans connexion", "de": "354 Spiele, ohne Netz", "pt": "354 jogos, sem internet", "ru": "354 игры без интернета", "it": "354 giochi, senza rete", "ar": "354 لعبة بلا إنترنت", "zh-Hant": "354 款小遊戲，不用聯網也能玩" },
  "初次开局": { "ja": "はじめての一局", "ko": "첫 판", "es": "Primera partida", "fr": "Premiere partie", "de": "Erste Runde", "pt": "Primeira partida", "ru": "Первая игра", "it": "Prima partita", "ar": "أول جولة", "zh-Hant": "初次開局" },
  "首次通关": { "ja": "初クリア", "ko": "첫 클리어", "es": "Primer pase", "fr": "Premiere reussite", "de": "Erster Sieg", "pt": "Primeira vitoria", "ru": "Первая победа", "it": "Prima vittoria", "ar": "أول فوز", "zh-Hant": "首次通關" },
  "手熟": { "ja": "手慣らし", "ko": "손풀기", "es": "Calentando", "fr": "Echauffement", "de": "Eingespielt", "pt": "Aquecendo", "ru": "Разминка", "it": "Riscaldamento", "ar": "تسخين", "zh-Hant": "手熟" },
  "常客": { "ja": "常連", "ko": "단골", "es": "Habitual", "fr": "Habitué", "de": "Stammgast", "pt": "Frequente", "ru": "Завсегдатай", "it": "Assiduo", "ar": "معتاد", "zh-Hant": "常客" },
  "老玩家": { "ja": "ベテラン", "ko": "고인물", "es": "Veterano", "fr": "Veteran", "de": "Veteran", "pt": "Veterano", "ru": "Ветеран", "it": "Veterano", "ar": "محترف", "zh-Hant": "老玩家" },
  "千局不倦": { "ja": "千回の情熱", "ko": "천 판", "es": "Mil partidas", "fr": "Mille parties", "de": "Tausend Runden", "pt": "Mil partidas", "ru": "Тысяча игр", "it": "Mille partite", "ar": "ألف جولة", "zh-Hant": "千局不倦" },
  "博览群游": { "ja": "ゲーム博士", "ko": "박학다식", "es": "Gran conocedor", "fr": "Grand connaisseur", "de": "Spielkenner", "pt": "Grande conhecedor", "ru": "Знаток игр", "it": "Grande esperto", "ar": "خبير الألعاب", "zh-Hant": "博覽群遊" },
  "半百猎手": { "ja": "50本ハンター", "ko": "50개 헌터", "es": "Cazador de 50", "fr": "Chasseur de 50", "de": "Jaeger der 50", "pt": "Cacador de 50", "ru": "Охотник за 50", "it": "Cacciatore di 50", "ar": "قناص الخمسين", "zh-Hant": "半百獵手" },
  "百款猎手": { "ja": "100本ハンター", "ko": "100개 헌터", "es": "Cazador de 100", "fr": "Chasseur de 100", "de": "Jaeger der 100", "pt": "Cacador de 100", "ru": "Охотник за 100", "it": "Cacciatore di 100", "ar": "قناص المئة", "zh-Hant": "百款獵手" },
  "两百款巡礼": { "ja": "200本の旅", "ko": "200개 순례", "es": "Peregrino de 200", "fr": "Pelerin des 200", "de": "Pilger der 200", "pt": "Peregrino de 200", "ru": "Паломник 200", "it": "Pellegrino di 200", "ar": "حاج المئتين", "zh-Hant": "兩百款巡禮" },
  "全收集": { "ja": "全制覇", "ko": "전체 수집", "es": "Coleccion total", "fr": "Collection complete", "de": "Alles gesammelt", "pt": "Colecao total", "ru": "Всё собрано", "it": "Collezione completa", "ar": "جمع كامل", "zh-Hant": "全收集" },
  "通关达人": { "ja": "クリアの達人", "ko": "클리어 달인", "es": "Maestro del pase", "fr": "Maitre du succes", "de": "Meister des Siegs", "pt": "Mestre da vitoria", "ru": "Мастер побед", "it": "Maestro di vittorie", "ar": "سيد الإنجاز", "zh-Hant": "通關達人" },
  "百局老手": { "ja": "100勝の熟練", "ko": "100판 고수", "es": "Cien victorias", "fr": "Cent victoires", "de": "Hundert Siege", "pt": "Cem vitorias", "ru": "Сто побед", "it": "Cento vittorie", "ar": "مئة فوز", "zh-Hant": "百局老手" },
  "五百胜": { "ja": "500勝", "ko": "500승", "es": "Quinientas victorias", "fr": "Cinq cents victoires", "de": "Fuenfhundert Siege", "pt": "Quinhentas vitorias", "ru": "Пятьсот побед", "it": "Cinquecento vittorie", "ar": "خمسمئة فوز", "zh-Hant": "五百勝" },
  "通关 30 款": { "ja": "30本クリア", "ko": "30개 클리어", "es": "30 juegos superados", "fr": "30 jeux termines", "de": "30 Spiele geschafft", "pt": "30 jogos concluidos", "ru": "30 игр пройдено", "it": "30 giochi completati", "ar": "إتمام 30 لعبة", "zh-Hant": "通關 30 款" },
  "通关 100 款": { "ja": "100本クリア", "ko": "100개 클리어", "es": "100 juegos superados", "fr": "100 jeux termines", "de": "100 Spiele geschafft", "pt": "100 jogos concluidos", "ru": "100 игр пройдено", "it": "100 giochi completati", "ar": "إتمام 100 لعبة", "zh-Hant": "通關 100 款" },
  "大满贯": { "ja": "グランドスラム", "ko": "그랜드슬램", "es": "Grand Slam", "fr": "Grand Chelem", "de": "Grand Slam", "pt": "Grand Slam", "ru": "Большой шлем", "it": "Grande Slam", "ar": "البطولات الكبرى", "zh-Hant": "大滿貫" },
  "三日连击": { "ja": "3日連続", "ko": "3일 연속", "es": "Racha de 3 dias", "fr": "Serie de 3 jours", "de": "3 Tage Serie", "pt": "Sequencia de 3 dias", "ru": "3 дня подряд", "it": "Serie di 3 giorni", "ar": "3 أيام متتالية", "zh-Hant": "三日連擊" },
  "七日连击": { "ja": "7日連続", "ko": "7일 연속", "es": "Racha de 7 dias", "fr": "Serie de 7 jours", "de": "7 Tage Serie", "pt": "Sequencia de 7 dias", "ru": "7 дней подряд", "it": "Serie di 7 giorni", "ar": "7 أيام متتالية", "zh-Hant": "七日連擊" },
  "满月连击": { "ja": "満月連続", "ko": "한 달 연속", "es": "Un mes seguido", "fr": "Un mois de serie", "de": "Ein Monat Serie", "pt": "Um mes seguido", "ru": "Месяц подряд", "it": "Un mese di fila", "ar": "شهر كامل", "zh-Hant": "滿月連擊" },
  "百日连击": { "ja": "100日連続", "ko": "100일 연속", "es": "Cien dias seguidos", "fr": "Cent jours de serie", "de": "Hundert Tage Serie", "pt": "Cem dias seguidos", "ru": "Сто дней подряд", "it": "Cento giorni di fila", "ar": "مئة يوم", "zh-Hant": "百日連擊" },
  "月度常客": { "ja": "今月の常連", "ko": "이달의 단골", "es": "Habitual del mes", "fr": "Habitué du mois", "de": "Stammgast des Monats", "pt": "Frequente do mes", "ru": "Завсегдатай месяца", "it": "Assiduo del mese", "ar": "معتاد الشهر", "zh-Hant": "月度常客" },
  "百日之约": { "ja": "百日の約束", "ko": "100일의 약속", "es": "Cita de cien dias", "fr": "Rendez-vous de cent jours", "de": "Hundert Tage Bund", "pt": "Encontro de cem dias", "ru": "Обещание ста дней", "it": "Patto di cento giorni", "ar": "وعد المئة يوم", "zh-Hant": "百日之約" },
  "小有所成": { "ja": "小さな成果", "ko": "작은 성과", "es": "Primeros logros", "fr": "Premiers succes", "de": "Erste Erfolge", "pt": "Primeiros feitos", "ru": "Первые успехи", "it": "Primi successi", "ar": "إنجاز صغير", "zh-Hant": "小有所成" },
  "渐入佳境": { "ja": "上達中", "ko": "점점 좋아짐", "es": "Mejorando", "fr": "En progres", "de": "Auf dem Weg", "pt": "Melhorando", "ru": "Всё лучше", "it": "In crescita", "ar": "في تحسن", "zh-Hant": "漸入佳境" },
  "登峰造极": { "ja": "頂点へ", "ko": "정점", "es": "En la cima", "fr": "Au sommet", "de": "Auf dem Gipfel", "pt": "No topo", "ru": "На вершине", "it": "Sulla vetta", "ar": "في القمة", "zh-Hant": "登峰造極" },
  "一代宗师": { "ja": "一代の宗師", "ko": "일대 종사", "es": "Gran maestro", "fr": "Grand maitre", "de": "Grossmeister", "pt": "Grande mestre", "ru": "Грандмастер", "it": "Gran maestro", "ar": "أستاذ الجيل", "zh-Hant": "一代宗師" },
  "满级": { "ja": "最大レベル", "ko": "최고 레벨", "es": "Nivel maximo", "fr": "Niveau max", "de": "Maximalstufe", "pt": "Nivel maximo", "ru": "Максимальный уровень", "it": "Livello massimo", "ar": "أعلى مستوى", "zh-Hant": "滿級" },
  "时间旅人": { "ja": "時の旅人", "ko": "시간 여행자", "es": "Viajero del tiempo", "fr": "Voyageur du temps", "de": "Zeitreisender", "pt": "Viajante do tempo", "ru": "Путешественник во времени", "it": "Viaggiatore del tempo", "ar": "مسافر الزمن", "zh-Hant": "時間旅人" },
  "光阴似箭": { "ja": "光陰矢のごとし", "ko": "시간은 화살", "es": "El tiempo vuela", "fr": "Le temps file", "de": "Zeit verfliegt", "pt": "O tempo voa", "ru": "Время летит", "it": "Il tempo vola", "ar": "الوقت يمر", "zh-Hant": "光陰似箭" },
  "半百小时": { "ja": "50時間", "ko": "50시간", "es": "Cincuenta horas", "fr": "Cinquante heures", "de": "Fuenfzig Stunden", "pt": "Cinquenta horas", "ru": "Пятьдесят часов", "it": "Cinquanta ore", "ar": "خمسون ساعة", "zh-Hant": "半百小時" },
  "百日之功": { "ja": "百日の功", "ko": "백일의 공", "es": "Cien dias de labor", "fr": "Cent jours d effort", "de": "Hundert Tage Werk", "pt": "Cem dias de obra", "ru": "Сто дней труда", "it": "Cento giorni d opera", "ar": "عمل مئة يوم", "zh-Hant": "百日之功" },
  "第一个收藏": { "ja": "はじめての保存", "ko": "첫 즐겨찾기", "es": "Primer guardado", "fr": "Premier favori", "de": "Erster Favorit", "pt": "Primeiro salvo", "ru": "Первое избранное", "it": "Primo salvataggio", "ar": "أول حفظ", "zh-Hant": "第一個收藏" },
  "收藏家": { "ja": "コレクター", "ko": "수집가", "es": "Coleccionista", "fr": "Collectionneur", "de": "Sammler", "pt": "Colecionador", "ru": "Коллекционер", "it": "Collezionista", "ar": "جامع", "zh-Hant": "收藏家" },
  "珍藏家": { "ja": "キュレーター", "ko": "큐레이터", "es": "Conservador", "fr": "Conservateur", "de": "Kurator", "pt": "Curador", "ru": "Хранитель", "it": "Curatore", "ar": "أمين", "zh-Hant": "珍藏家" },
  "挑战者": { "ja": "挑戦者", "ko": "도전자", "es": "Retador", "fr": "Challengeur", "de": "Herausforderer", "pt": "Desafiante", "ru": "Претендент", "it": "Sfidante", "ar": "متحدٍ", "zh-Hant": "挑戰者" },
  "挑战常客": { "ja": "挑戦の常連", "ko": "도전 단골", "es": "Retador habitual", "fr": "Habitué du defi", "de": "Stamm-Herausforderer", "pt": "Desafiante frequente", "ru": "Постоянный претендент", "it": "Sfidante abituale", "ar": "متحدٍ معتاد", "zh-Hant": "挑戰常客" },
  "挑战达人": { "ja": "挑戦の達人", "ko": "도전 달인", "es": "Maestro del reto", "fr": "Maitre du defi", "de": "Meister der Herausforderung", "pt": "Mestre do desafio", "ru": "Мастер вызова", "it": "Maestro della sfida", "ar": "سيد التحدي", "zh-Hant": "挑戰達人" },
  "挑战之王": { "ja": "挑戦の王", "ko": "도전의 왕", "es": "Rey del reto", "fr": "Roi du defi", "de": "Koenig der Herausforderung", "pt": "Rei do desafio", "ru": "Король вызова", "it": "Re della sfida", "ar": "ملك التحدي", "zh-Hant": "挑戰之王" },
  "经典通": { "ja": "クラシック通", "ko": "클래식통", "es": "Experto clasico", "fr": "Expert classique", "de": "Klassiker-Kenner", "pt": "Expert em classicos", "ru": "Знаток классики", "it": "Esperto di classici", "ar": "خبير الكلاسيكيات", "zh-Hant": "經典通" },
  "逻辑通": { "ja": "ロジック通", "ko": "논리통", "es": "Experto en logica", "fr": "Expert en logique", "de": "Logik-Kenner", "pt": "Expert em logica", "ru": "Знаток логики", "it": "Esperto di logica", "ar": "خبير المنطق", "zh-Hant": "邏輯通" },
  "算术通": { "ja": "計算通", "ko": "계산통", "es": "Experto en calculo", "fr": "Expert en calcul", "de": "Rechen-Kenner", "pt": "Expert em calculo", "ru": "Знаток счёта", "it": "Esperto di calcolo", "ar": "خبير الحساب", "zh-Hant": "算術通" },
  "记忆通": { "ja": "記憶通", "ko": "기억통", "es": "Experto en memoria", "fr": "Expert en memoire", "de": "Gedaechtnis-Kenner", "pt": "Expert em memoria", "ru": "Знаток памяти", "it": "Esperto di memoria", "ar": "خبير الذاكرة", "zh-Hant": "記憶通" },
  "文字通": { "ja": "言葉通", "ko": "단어통", "es": "Experto en palabras", "fr": "Expert en mots", "de": "Wort-Kenner", "pt": "Expert em palavras", "ru": "Знаток слов", "it": "Esperto di parole", "ar": "خبير الكلمات", "zh-Hant": "文字通" },
  "空间通": { "ja": "空間通", "ko": "공간통", "es": "Experto espacial", "fr": "Expert en espace", "de": "Raum-Kenner", "pt": "Expert em espaco", "ru": "Знаток пространства", "it": "Esperto di spazio", "ar": "خبير الفضاء", "zh-Hant": "空間通" },
  "五连霸": { "ja": "5連覇", "ko": "5연패", "es": "Cinco seguidas", "fr": "Cinq d affilee", "de": "Fuenf in Folge", "pt": "Cinco seguidas", "ru": "Пять подряд", "it": "Cinque di fila", "ar": "خمس متتالية", "zh-Hant": "五連霸" },
  "十连霸": { "ja": "10連覇", "ko": "10연패", "es": "Diez seguidas", "fr": "Dix d affilee", "de": "Zehn in Folge", "pt": "Dez seguidas", "ru": "Десять подряд", "it": "Dieci di fila", "ar": "عشر متتالية", "zh-Hant": "十連霸" },
  "超级十连": { "ja": "スーパー10連", "ko": "슈퍼 10연승", "es": "Super diez", "fr": "Super dix", "de": "Super zehn", "pt": "Super dez", "ru": "Супер десять", "it": "Super dieci", "ar": "عشر خارقة", "zh-Hant": "超級十連" },
  "夜猫子": { "ja": "夜型", "ko": "올빼미족", "es": "Noctambulo", "fr": "Oiseau de nuit", "de": "Nachteule", "pt": "Notivago", "ru": "Полуночник", "it": "Nottambulo", "ar": "ساهر", "zh-Hant": "夜貓子" },
  "早起鸟": { "ja": "早起き", "ko": "아침형", "es": "Madrugador", "fr": "Lever tot", "de": "Fruehaufsteher", "pt": "Madrugador", "ru": "Ранняя пташка", "it": "Mattiniero", "ar": "مبكر", "zh-Hant": "早起鳥" },
  "马拉松": { "ja": "マラソン", "ko": "마라톤", "es": "Maraton", "fr": "Marathon", "de": "Marathon", "pt": "Maratona", "ru": "Марафон", "it": "Maratona", "ar": "ماراثون", "zh-Hant": "馬拉松" },
  "完美主义": { "ja": "完璧主義", "ko": "완벽주의", "es": "Perfeccionista", "fr": "Perfectionniste", "de": "Perfektionist", "pt": "Perfeccionista", "ru": "Перфекционист", "it": "Perfezionista", "ar": "مثالي", "zh-Hant": "完美主義" },
  "探索者": { "ja": "探検家", "ko": "탐험가", "es": "Explorador", "fr": "Explorateur", "de": "Entdecker", "pt": "Explorador", "ru": "Исследователь", "it": "Esploratore", "ar": "مستكشف", "zh-Hant": "探索者" },
  "玩出你的第一局": { "ja": "初めての一局を", "ko": "첫 판을 플레이", "es": "Juega tu primera partida", "fr": "Jouez votre premiere partie", "de": "Spiele deine erste Runde", "pt": "Jogue sua primeira partida", "ru": "Сыграйте первую игру", "it": "Gioca la prima partita", "ar": "العب أول جولة", "zh-Hant": "玩出你的第一局" },
  "第一次通关": { "ja": "初めてクリア", "ko": "첫 클리어", "es": "Supera una por primera vez", "fr": "Reussissez une premiere fois", "de": "Schaffe zum ersten Mal", "pt": "Conclua pela primeira vez", "ru": "Пройдите впервые", "it": "Completa la prima volta", "ar": "أكمل لأول مرة", "zh-Hant": "第一次通關" },
  "玩满 10 局": { "ja": "10局プレイ", "ko": "10판 플레이", "es": "Juega 10 partidas", "fr": "Jouez 10 parties", "de": "Spiele 10 Runden", "pt": "Jogue 10 partidas", "ru": "Сыграйте 10 игр", "it": "Gioca 10 partite", "ar": "العب 10 جولات", "zh-Hant": "玩滿 10 局" },
  "玩满 50 局": { "ja": "50局プレイ", "ko": "50판 플레이", "es": "Juega 50 partidas", "fr": "Jouez 50 parties", "de": "Spiele 50 Runden", "pt": "Jogue 50 partidas", "ru": "Сыграйте 50 игр", "it": "Gioca 50 partite", "ar": "العب 50 جولة", "zh-Hant": "玩滿 50 局" },
  "玩满 200 局": { "ja": "200局プレイ", "ko": "200판 플레이", "es": "Juega 200 partidas", "fr": "Jouez 200 parties", "de": "Spiele 200 Runden", "pt": "Jogue 200 partidas", "ru": "Сыграйте 200 игр", "it": "Gioca 200 partite", "ar": "العب 200 جولة", "zh-Hant": "玩滿 200 局" },
  "玩满 1000 局": { "ja": "1000局プレイ", "ko": "1000판 플레이", "es": "Juega 1000 partidas", "fr": "Jouez 1000 parties", "de": "Spiele 1000 Runden", "pt": "Jogue 1000 partidas", "ru": "Сыграйте 1000 игр", "it": "Gioca 1000 partite", "ar": "العب 1000 جولة", "zh-Hant": "玩滿 1000 局" },
  "玩过 10 款不一样的": { "ja": "10種類をプレイ", "ko": "10종류 플레이", "es": "Prueba 10 juegos distintos", "fr": "Essayez 10 jeux differents", "de": "Spiele 10 verschiedene", "pt": "Experimente 10 jogos", "ru": "Попробуйте 10 разных", "it": "Prova 10 giochi diversi", "ar": "جرب 10 ألعاب", "zh-Hant": "玩過 10 款不一樣的" },
  "玩过 50 款不一样的": { "ja": "50種類をプレイ", "ko": "50종류 플레이", "es": "Prueba 50 juegos distintos", "fr": "Essayez 50 jeux differents", "de": "Spiele 50 verschiedene", "pt": "Experimente 50 jogos", "ru": "Попробуйте 50 разных", "it": "Prova 50 giochi diversi", "ar": "جرب 50 لعبة", "zh-Hant": "玩過 50 款不一樣的" },
  "玩过 100 款不一样的": { "ja": "100種類をプレイ", "ko": "100종류 플레이", "es": "Prueba 100 juegos", "fr": "Essayez 100 jeux", "de": "Spiele 100 verschiedene", "pt": "Experimente 100 jogos", "ru": "Попробуйте 100 разных", "it": "Prova 100 giochi", "ar": "جرب 100 لعبة", "zh-Hant": "玩過 100 款不一樣的" },
  "玩过 200 款不一样的": { "ja": "200種類をプレイ", "ko": "200종류 플레이", "es": "Prueba 200 juegos", "fr": "Essayez 200 jeux", "de": "Spiele 200 verschiedene", "pt": "Experimente 200 jogos", "ru": "Попробуйте 200 разных", "it": "Prova 200 giochi", "ar": "جرب 200 لعبة", "zh-Hant": "玩過 200 款不一樣的" },
  "354 款一款不落": { "ja": "354本すべて制覇", "ko": "354개 전부", "es": "Los 354 juegos", "fr": "Les 354 jeux", "de": "Alle 354 Spiele", "pt": "Todos os 354 jogos", "ru": "Все 354 игры", "it": "Tutti i 354 giochi", "ar": "كل الألعاب 354", "zh-Hant": "354 款一款不落" },
  "通关 10 局": { "ja": "10局クリア", "ko": "10판 클리어", "es": "Supera 10 partidas", "fr": "Reussissez 10 parties", "de": "Schaffe 10 Runden", "pt": "Conclua 10 partidas", "ru": "Пройдите 10 игр", "it": "Completa 10 partite", "ar": "أكمل 10 جولات", "zh-Hant": "通關 10 局" },
  "通关 100 局": { "ja": "100局クリア", "ko": "100판 클리어", "es": "Supera 100 partidas", "fr": "Reussissez 100 parties", "de": "Schaffe 100 Runden", "pt": "Conclua 100 partidas", "ru": "Пройдите 100 игр", "it": "Completa 100 partite", "ar": "أكمل 100 جولة", "zh-Hant": "通關 100 局" },
  "通关 500 局": { "ja": "500局クリア", "ko": "500판 클리어", "es": "Supera 500 partidas", "fr": "Reussissez 500 parties", "de": "Schaffe 500 Runden", "pt": "Conclua 500 partidas", "ru": "Пройдите 500 игр", "it": "Completa 500 partite", "ar": "أكمل 500 جولة", "zh-Hant": "通關 500 局" },
  "30 款都通关了": { "ja": "30本クリア", "ko": "30개 클리어", "es": "30 juegos superados", "fr": "30 jeux termines", "de": "30 Spiele geschafft", "pt": "30 jogos concluidos", "ru": "30 игр пройдено", "it": "30 giochi completati", "ar": "إتمام 30 لعبة", "zh-Hant": "30 款都通關了" },
  "100 款都通关了": { "ja": "100本クリア", "ko": "100개 클리어", "es": "100 juegos superados", "fr": "100 jeux termines", "de": "100 Spiele geschafft", "pt": "100 jogos concluidos", "ru": "100 игр пройдено", "it": "100 giochi completati", "ar": "إتمام 100 لعبة", "zh-Hant": "100 款都通關了" },
  "354 款全部通关": { "ja": "354本すべてクリア", "ko": "354개 전부 클리어", "es": "Los 354 superados", "fr": "Les 354 termines", "de": "Alle 354 geschafft", "pt": "Todos os 354 concluidos", "ru": "Все 354 пройдены", "it": "Tutti i 354 completati", "ar": "إتمام الـ354", "zh-Hant": "354 款全部通關" },
  "连着 3 天来玩": { "ja": "3日連続プレイ", "ko": "3일 연속 플레이", "es": "Juega 3 dias seguidos", "fr": "Jouez 3 jours de suite", "de": "Spiele 3 Tage in Folge", "pt": "Jogue 3 dias seguidos", "ru": "Играйте 3 дня подряд", "it": "Gioca 3 giorni di fila", "ar": "العب 3 أيام متتالية", "zh-Hant": "連著 3 天來玩" },
  "连着 7 天来玩": { "ja": "7日連続プレイ", "ko": "7일 연속 플레이", "es": "Juega 7 dias seguidos", "fr": "Jouez 7 jours de suite", "de": "Spiele 7 Tage in Folge", "pt": "Jogue 7 dias seguidos", "ru": "Играйте 7 дней подряд", "it": "Gioca 7 giorni di fila", "ar": "العب 7 أيام متتالية", "zh-Hant": "連著 7 天來玩" },
  "连着 30 天来玩": { "ja": "30日連続プレイ", "ko": "30일 연속 플레이", "es": "Juega 30 dias seguidos", "fr": "Jouez 30 jours de suite", "de": "Spiele 30 Tage in Folge", "pt": "Jogue 30 dias seguidos", "ru": "Играйте 30 дней подряд", "it": "Gioca 30 giorni di fila", "ar": "العب 30 يوماً", "zh-Hant": "連著 30 天來玩" },
  "连着 100 天来玩": { "ja": "100日連続プレイ", "ko": "100일 연속 플레이", "es": "Juega 100 dias seguidos", "fr": "Jouez 100 jours de suite", "de": "Spiele 100 Tage in Folge", "pt": "Jogue 100 dias seguidos", "ru": "Играйте 100 дней подряд", "it": "Gioca 100 giorni di fila", "ar": "العب 100 يوم", "zh-Hant": "連著 100 天來玩" },
  "一共来了 30 天": { "ja": "通算30日", "ko": "총 30일", "es": "30 dias en total", "fr": "30 jours au total", "de": "Insgesamt 30 Tage", "pt": "30 dias no total", "ru": "Всего 30 дней", "it": "30 giorni in totale", "ar": "30 يوماً إجمالاً", "zh-Hant": "一共來了 30 天" },
  "一共来了 100 天": { "ja": "通算100日", "ko": "총 100일", "es": "100 dias en total", "fr": "100 jours au total", "de": "Insgesamt 100 Tage", "pt": "100 dias no total", "ru": "Всего 100 дней", "it": "100 giorni in totale", "ar": "100 يوم إجمالاً", "zh-Hant": "一共來了 100 天" },
  "等级到 10 级": { "ja": "レベル10到達", "ko": "레벨 10 달성", "es": "Llega al nivel 10", "fr": "Atteignez le niveau 10", "de": "Erreiche Level 10", "pt": "Alcance o nivel 10", "ru": "Достигните 10 уровня", "it": "Raggiungi il livello 10", "ar": "ابلغ المستوى 10", "zh-Hant": "等級到 10 級" },
  "等级到 25 级": { "ja": "レベル25到達", "ko": "레벨 25 달성", "es": "Llega al nivel 25", "fr": "Atteignez le niveau 25", "de": "Erreiche Level 25", "pt": "Alcance o nivel 25", "ru": "Достигните 25 уровня", "it": "Raggiungi il livello 25", "ar": "ابلغ المستوى 25", "zh-Hant": "等級到 25 級" },
  "等级到 50 级": { "ja": "レベル50到達", "ko": "레벨 50 달성", "es": "Llega al nivel 50", "fr": "Atteignez le niveau 50", "de": "Erreiche Level 50", "pt": "Alcance o nivel 50", "ru": "Достигните 50 уровня", "it": "Raggiungi il livello 50", "ar": "ابلغ المستوى 50", "zh-Hant": "等級到 50 級" },
  "等级到 80 级": { "ja": "レベル80到達", "ko": "레벨 80 달성", "es": "Llega al nivel 80", "fr": "Atteignez le niveau 80", "de": "Erreiche Level 80", "pt": "Alcance o nivel 80", "ru": "Достигните 80 уровня", "it": "Raggiungi il livello 80", "ar": "ابلغ المستوى 80", "zh-Hant": "等級到 80 級" },
  "满级啦（100 级）": { "ja": "最大レベル（100）", "ko": "최고 레벨 (100)", "es": "Nivel maximo (100)", "fr": "Niveau max (100)", "de": "Maximalstufe (100)", "pt": "Nivel maximo (100)", "ru": "Максимум (100)", "it": "Livello massimo (100)", "ar": "أعلى مستوى (100)", "zh-Hant": "滿級啦（100 級）" },
  "一共玩了 1 小时": { "ja": "通算1時間", "ko": "총 1시간", "es": "1 hora en total", "fr": "1 heure au total", "de": "Insgesamt 1 Stunde", "pt": "1 hora no total", "ru": "Всего 1 час", "it": "1 ora in totale", "ar": "ساعة واحدة", "zh-Hant": "一共玩了 1 小時" },
  "一共玩了 10 小时": { "ja": "通算10時間", "ko": "총 10시간", "es": "10 horas en total", "fr": "10 heures au total", "de": "Insgesamt 10 Stunden", "pt": "10 horas no total", "ru": "Всего 10 часов", "it": "10 ore in totale", "ar": "10 ساعات", "zh-Hant": "一共玩了 10 小時" },
  "一共玩了 50 小时": { "ja": "通算50時間", "ko": "총 50시간", "es": "50 horas en total", "fr": "50 heures au total", "de": "Insgesamt 50 Stunden", "pt": "50 horas no total", "ru": "Всего 50 часов", "it": "50 ore in totale", "ar": "50 ساعة", "zh-Hant": "一共玩了 50 小時" },
  "一共玩了 100 小时": { "ja": "通算100時間", "ko": "총 100시간", "es": "100 horas en total", "fr": "100 heures au total", "de": "Insgesamt 100 Stunden", "pt": "100 horas no total", "ru": "Всего 100 часов", "it": "100 ore in totale", "ar": "100 ساعة", "zh-Hant": "一共玩了 100 小時" },
  "收藏第一个游戏": { "ja": "初めてのお気に入り", "ko": "첫 즐겨찾기", "es": "Guarda tu primer juego", "fr": "Enregistrez un premier jeu", "de": "Erstes Spiel merken", "pt": "Salve o primeiro jogo", "ru": "Первое избранное", "it": "Salva il primo gioco", "ar": "احفظ أول لعبة", "zh-Hant": "收藏第一個遊戲" },
  "收藏 10 款": { "ja": "10本お気に入り", "ko": "10개 즐겨찾기", "es": "Guarda 10 juegos", "fr": "Enregistrez 10 jeux", "de": "10 Spiele merken", "pt": "Salve 10 jogos", "ru": "10 в избранном", "it": "Salva 10 giochi", "ar": "احفظ 10 ألعاب", "zh-Hant": "收藏 10 款" },
  "收藏 50 款": { "ja": "50本お気に入り", "ko": "50개 즐겨찾기", "es": "Guarda 50 juegos", "fr": "Enregistrez 50 jeux", "de": "50 Spiele merken", "pt": "Salve 50 jogos", "ru": "50 в избранном", "it": "Salva 50 giochi", "ar": "احفظ 50 لعبة", "zh-Hant": "收藏 50 款" },
  "完成一次今天这一局": { "ja": "今日の一局を1回", "ko": "오늘의 한 판 1회", "es": "Completa la de hoy", "fr": "Terminez celle du jour", "de": "Heutige Runde einmal", "pt": "Conclua a de hoje", "ru": "Пройдите игру дня", "it": "Completa quella di oggi", "ar": "أكمل جولة اليوم", "zh-Hant": "完成一次今天這一局" },
  "完成 7 次今天这一局": { "ja": "今日の一局を7回", "ko": "오늘의 한 판 7회", "es": "Completa la de hoy 7 veces", "fr": "Terminez celle du jour 7 fois", "de": "Heutige Runde 7-mal", "pt": "Conclua a de hoje 7 vezes", "ru": "Игра дня 7 раз", "it": "Completa quella di oggi 7 volte", "ar": "أكمل جولة اليوم 7 مرات", "zh-Hant": "完成 7 次今天這一局" },
  "完成 30 次今天这一局": { "ja": "今日の一局を30回", "ko": "오늘의 한 판 30회", "es": "Completa la de hoy 30 veces", "fr": "Terminez celle du jour 30 fois", "de": "Heutige Runde 30-mal", "pt": "Conclua a de hoje 30 vezes", "ru": "Игра дня 30 раз", "it": "Completa quella di oggi 30 volte", "ar": "أكمل جولة اليوم 30 مرة", "zh-Hant": "完成 30 次今天這一局" },
  "完成 100 次今天这一局": { "ja": "今日の一局を100回", "ko": "오늘의 한 판 100회", "es": "Completa la de hoy 100 veces", "fr": "Terminez celle du jour 100 fois", "de": "Heutige Runde 100-mal", "pt": "Conclua a de hoje 100 vezes", "ru": "Игра дня 100 раз", "it": "Completa quella di oggi 100 volte", "ar": "أكمل جولة اليوم 100 مرة", "zh-Hant": "完成 100 次今天這一局" },
  "玩过 30 款经典": { "ja": "クラシック30本", "ko": "클래식 30개", "es": "30 clasicos jugados", "fr": "30 jeux classiques", "de": "30 Klassiker gespielt", "pt": "30 classicos jogados", "ru": "30 классических игр", "it": "30 classici giocati", "ar": "30 لعبة كلاسيكية", "zh-Hant": "玩過 30 款經典" },
  "玩过 30 款逻辑": { "ja": "ロジック30本", "ko": "논리 30개", "es": "30 de logica", "fr": "30 jeux de logique", "de": "30 Logikspiele", "pt": "30 de logica", "ru": "30 логических игр", "it": "30 giochi di logica", "ar": "30 لعبة منطق", "zh-Hant": "玩過 30 款邏輯" },
  "玩过 30 款数字": { "ja": "数字30本", "ko": "숫자 30개", "es": "30 de numeros", "fr": "30 jeux de chiffres", "de": "30 Zahlen-Spiele", "pt": "30 de numeros", "ru": "30 игр с числами", "it": "30 giochi di numeri", "ar": "30 لعبة أرقام", "zh-Hant": "玩過 30 款數字" },
  "玩过 40 款记忆": { "ja": "記憶40本", "ko": "기억 40개", "es": "40 de memoria", "fr": "40 jeux de memoire", "de": "40 Gedaechtnisspiele", "pt": "40 de memoria", "ru": "40 игр на память", "it": "40 giochi di memoria", "ar": "40 لعبة ذاكرة", "zh-Hant": "玩過 40 款記憶" },
  "玩过 30 款文字": { "ja": "言葉30本", "ko": "단어 30개", "es": "30 de palabras", "fr": "30 jeux de mots", "de": "30 Wortspiele", "pt": "30 de palavras", "ru": "30 игр со словами", "it": "30 giochi di parole", "ar": "30 لعبة كلمات", "zh-Hant": "玩過 30 款文字" },
  "玩过 40 款空间": { "ja": "空間40本", "ko": "공간 40개", "es": "40 espaciales", "fr": "40 jeux d espace", "de": "40 Raumspiele", "pt": "40 espaciais", "ru": "40 игр с пространством", "it": "40 giochi spaziali", "ar": "40 لعبة فضاء", "zh-Hant": "玩過 40 款空間" },
  "同一个游戏连赢 5 局": { "ja": "同じゲームで5連勝", "ko": "같은 게임 5연승", "es": "Gana 5 seguidas en un juego", "fr": "Gagnez 5 fois au meme jeu", "de": "5 Siege in Folge im selben Spiel", "pt": "Ganhe 5 seguidas no mesmo jogo", "ru": "5 побед подряд в одной игре", "it": "Vinci 5 di fila allo stesso gioco", "ar": "5 انتصارات متتالية", "zh-Hant": "同一個遊戲連贏 5 局" },
  "同一个游戏连赢 10 局": { "ja": "同じゲームで10連勝", "ko": "같은 게임 10연승", "es": "Gana 10 seguidas", "fr": "Gagnez 10 fois de suite", "de": "10 Siege in Folge", "pt": "Ganhe 10 seguidas", "ru": "10 побед подряд", "it": "Vinci 10 di fila", "ar": "10 انتصارات متتالية", "zh-Hant": "同一個遊戲連贏 10 局" },
  "连着 10 天每天都通关": { "ja": "10日連続クリア", "ko": "10일 연속 클리어", "es": "10 dias seguidos superando", "fr": "10 jours de suite reussis", "de": "10 Tage in Folge geschafft", "pt": "10 dias seguidos concluindo", "ru": "10 дней подряд с победой", "it": "10 giorni di fila completando", "ar": "10 أيام متتالية إنجاز", "zh-Hant": "連著 10 天每天都通關" },
  "凌晨 0–5 点还在玩": { "ja": "深夜0–5時にプレイ", "ko": "새벽 0–5시 플레이", "es": "Juega entre las 0 y las 5", "fr": "Jouez entre 0h et 5h", "de": "Spiele zwischen 0 und 5 Uhr", "pt": "Jogue entre 0h e 5h", "ru": "Играйте с 0 до 5 ночи", "it": "Gioca tra le 0 e le 5", "ar": "العب بين 0 و5 فجراً", "zh-Hant": "凌晨 0–5 點還在玩" },
  "清晨 5–7 点就开玩": { "ja": "早朝5–7時にプレイ", "ko": "새벽 5–7시 플레이", "es": "Juega entre las 5 y las 7", "fr": "Jouez entre 5h et 7h", "de": "Spiele zwischen 5 und 7 Uhr", "pt": "Jogue entre 5h e 7h", "ru": "Играйте с 5 до 7 утра", "it": "Gioca tra le 5 e le 7", "ar": "العب بين 5 و7 صباحاً", "zh-Hant": "清晨 5–7 點就開玩" },
  "一天玩了 2 小时": { "ja": "1日で2時間", "ko": "하루 2시간", "es": "2 horas en un dia", "fr": "2 heures en un jour", "de": "2 Stunden an einem Tag", "pt": "2 horas em um dia", "ru": "2 часа за день", "it": "2 ore in un giorno", "ar": "ساعتان في يوم", "zh-Hant": "一天玩了 2 小時" },
  "拿过一次满分": { "ja": "一度は満点", "ko": "한 번 만점", "es": "Un perfecto", "fr": "Un sans-faute", "de": "Einmal perfekt", "pt": "Um perfeito", "ru": "Один идеальный результат", "it": "Un punteggio pieno", "ar": "علامة كاملة مرة", "zh-Hant": "拿過一次滿分" },
  "六大类各玩过 5 款以上": { "ja": "6カテゴリ各5本以上", "ko": "6개 분야 각 5개 이상", "es": "5 o mas en cada categoria", "fr": "5 ou plus par categorie", "de": "5 oder mehr je Kategorie", "pt": "5 ou mais por categoria", "ru": "По 5 в каждой категории", "it": "5 o piu per categoria", "ar": "5 على الأقل لكل فئة", "zh-Hant": "六大類各玩過 5 款以上" },
  "为了让「等级」「连胜」「今日打卡」正常工作，本应用会在你手机上存下这些：累计经验值、各游戏通关次数与最佳成绩、连胜天数、最近一次游玩日期、深色模式开关、收藏与最近玩过的游戏。\n\n这些数据只存在应用自己的文件夹里，别的应用读不到；不会传到任何服务器；不含任何能认出你是谁的信息；把应用卸载掉，它们就一起没了。": { "ja": "「レベル」「連勝」「今日のチェックイン」を動かすため、端末に以下を保存します：累計EXP、ゲームごとのクリア回数と最高記録、連勝日数、最後に遊んだ日付、ダークモードの設定、お気に入りと最近遊んだゲーム。\n\nこれらはアプリ自身のフォルダにだけ保存され、他のアプリからは読めません。どのサーバーにも送信されず、あなたを特定できる情報は含まれません。アプリを削除すれば一緒に消えます。", "ko": "레벨, 연속 일수, 오늘의 체크인을 위해 기기에 다음을 저장합니다: 누적 경험치, 게임별 클리어 횟수와 최고 기록, 연속 일수, 마지막 플레이 날짜, 다크 모드 설정, 즐겨찾기와 최근 플레이한 게임.\n\n이 데이터는 앱 자체 폴더에만 저장되어 다른 앱이 읽을 수 없습니다. 어떤 서버로도 전송되지 않고, 당신을 알아볼 수 있는 정보도 없습니다. 앱을 삭제하면 함께 사라집니다.", "es": "Para que funcionen el nivel, la racha y el registro diario, la app guarda en tu telefono: XP acumulada, partidas superadas y mejores marcas por juego, dias de racha, la fecha de tu ultima partida, el modo oscuro, tus guardados y los juegos recientes.\n\nEstos datos viven solo en la carpeta de la app, ninguna otra app puede leerlos. Nunca se envian a ningun servidor, no contienen nada que pueda identificarte y desaparecen al desinstalar la app.", "fr": "Pour faire fonctionner le niveau, la serie et le pointage du jour, l app enregistre sur votre telephone : XP cumulee, reussites et meilleurs scores par jeu, jours de serie, date de la derniere partie, mode sombre, favoris et jeux recents.\n\nCes donnees restent dans le dossier de l app, aucune autre app ne peut les lire. Elles ne partent vers aucun serveur, ne contiennent rien permettant de vous identifier et disparaissent si vous desinstallez l app.", "de": "Damit Level, Serie und Tages-Check-in funktionieren, speichert die App auf deinem Geraet: gesammelte XP, Erfolge und Bestwerte je Spiel, Serientage, das Datum der letzten Partie, den Dunkelmodus, Favoriten und zuletzt gespielte Spiele.\n\nDiese Daten liegen nur im eigenen App-Ordner, keine andere App kann sie lesen. Sie gehen an keinen Server, enthalten nichts, was dich erkennen koennte, und verschwinden mit der Deinstallation.", "pt": "Para o nivel, a sequencia e o check-in diario funcionarem, o app guarda no seu aparelho: XP acumulada, vitorias e melhores marcas por jogo, dias de sequencia, a data da ultima partida, o modo escuro, seus salvos e jogos recentes.\n\nEsses dados ficam so na pasta do proprio app, nenhum outro app consegue ler. Nunca vao para servidor algum, nao contem nada que identifique voce e somem ao desinstalar.", "ru": "Чтобы работали уровень, серия и ежедневная отметка, приложение хранит на телефоне: накопленный опыт, число прохождений и лучшие результаты по играм, дни серии, дату последней игры, тёмную тему, избранное и недавние игры.\n\nЭти данные лежат только в папке приложения, другие приложения их не видят. Они не отправляются ни на какой сервер, не содержат ничего, что могло бы вас опознать, и исчезают вместе с удалением приложения.", "it": "Per far funzionare livello, serie e check-in giornaliero, l app salva sul telefono: XP accumulata, partite completate e migliori punteggi per gioco, giorni di serie, data dell ultima partita, modalita scura, salvati e giochi recenti.\n\nQuesti dati restano solo nella cartella dell app, nessun altra app puo leggerli. Non vengono inviati ad alcun server, non contengono nulla che possa identificarti e spariscono disinstallando l app.", "ar": "لكي تعمل المستويات والسلاسل وتسجيل اليوم، يحفظ التطبيق على هاتفك: الخبرة المتراكمة، وعدد الإنجازات وأفضل النتائج لكل لعبة، وأيام التتابع، وتاريخ آخر لعب، ووضع داكن، والمحفوظات والألعاب الأخيرة.\n\nتبقى هذه البيانات داخل مجلد التطبيق وحده، ولا يستطيع أي تطبيق آخر قراءتها. لا تُرسل إلى أي خادم، ولا تحتوي على ما يمكن أن يعرّف بك، وتزول مع إزالة التطبيق.", "zh-Hant": "為了讓「等級」「連勝」「今日打卡」正常運作，本應用會在你手機上存下這些：累計經驗值、各遊戲通關次數與最佳成績、連勝天數、最近一次遊玩日期、深色模式開關、收藏與最近玩過的遊戲。\n\n這些資料只存在應用自己的資料夾裡，別的應用讀不到；不會傳到任何伺服器；不含任何能認出你是誰的資訊；將應用卸載掉，它們就一起沒了。" },
  "本应用没有接入任何第三方 SDK（SDK 就是别人写好的代码包）—— 没有广告的、没有统计分析的、没有崩溃上报的、没有社交分享的、没有支付的、也没有推送的。\n\n本应用不含任何广告，不含任何内购，不产生任何费用。": { "ja": "本アプリは第三者SDK（＝他人が書いたコードパッケージ）を一切組み込んでいません —— 広告、解析、クラッシュ報告、SNS共有、決済、プッシュ通知のいずれもありません。\n\n広告も課金もなく、費用は一切かかりません。", "ko": "이 앱은 제3자 SDK(다른 사람이 만든 코드 묶음)를 전혀 넣지 않았습니다 — 광고, 분석, 오류 보고, 소셜 공유, 결제, 푸시 어느 것도 없습니다.\n\n광고도 인앱 결제도 없고 비용이 들지 않습니다.", "es": "La app no incluye ningun SDK de terceros (un SDK es un paquete de codigo ya escrito): ni de anuncios, ni de analitica, ni de fallos, ni de compartir, ni de pagos, ni de notificaciones.\n\nNo tiene anuncios ni compras dentro de la app y no cuesta nada.", "fr": "L app n integre aucun SDK tiers (un SDK est un paquet de code deja ecrit) : ni publicite, ni analyse, ni rapport de plantage, ni partage social, ni paiement, ni notification.\n\nAucune publicite, aucun achat integre, aucun frais.", "de": "Die App enthaelt keine fremden SDKs (ein SDK ist ein fertiges Codepaket) — keine fuer Werbung, Analyse, Absturzberichte, Teilen, Bezahlung oder Push.\n\nKeine Werbung, keine In-App-Kaeufe, keine Kosten.", "pt": "O app nao inclui nenhum SDK de terceiros (SDK e um pacote de codigo pronto) — nem de anuncios, nem de analise, nem de erros, nem de compartilhamento, nem de pagamento, nem de notificacao.\n\nNao tem anuncios, nao tem compras dentro do app e nao custa nada.", "ru": "Приложение не включает сторонних SDK (SDK — это готовый пакет кода): ни рекламных, ни аналитических, ни для отчётов о сбоях, ни для соцсетей, ни платёжных, ни для уведомлений.\n\nВ приложении нет рекламы, нет встроенных покупок и нет никаких расходов.", "it": "L app non include alcun SDK di terzi (un SDK e un pacchetto di codice gia scritto): nessuno per pubblicita, analisi, crash, condivisione, pagamenti o notifiche.\n\nNessuna pubblicita, nessun acquisto in-app, nessun costo.", "ar": "لا يتضمن التطبيق أي SDK من طرف ثالث (وهو حزمة كود جاهزة) — لا للإعلانات ولا للتحليلات ولا لتقارير الأعطال ولا للمشاركة ولا للدفع ولا للإشعارات.\n\nلا إعلانات ولا مشتريات داخلية ولا أي تكلفة.", "zh-Hant": "本應用沒有接入任何第三方 SDK（SDK 就是別人寫好的程式碼包）—— 沒有廣告的、沒有統計分析的、沒有崩潰上報的、沒有社交分享的、沒有支付的和推送的。\n\n本應用不含任何廣告，不含任何內購，不產生任何費用。" },
  "本应用提供桌面服务卡片（显示等级、连胜与今日打卡状态）。卡片读取的数据与主应用完全相同，均来自上述本地存储，不涉及任何额外的信息收集或网络传输。": { "ja": "本アプリはホーム画面ウィジェット（レベル・連勝・今日のチェックインを表示）を提供します。ウィジェットが読むデータは本体アプリと完全に同じで、すべて上記のローカル保存からのものであり、追加の収集や通信は行いません。", "ko": "이 앱은 홈 화면 위젯(레벨, 연속 일수, 오늘의 체크인 표시)을 제공합니다. 위젯이 읽는 데이터는 본 앱과 완전히 같으며 모두 위에 설명한 기기 저장소에서 오고, 추가 수집이나 전송은 없습니다.", "es": "La app ofrece un widget de inicio que muestra nivel, racha y registro diario. El widget lee exactamente los mismos datos que la app, todos del almacenamiento local descrito arriba, sin recogida ni transmision adicional.", "fr": "L app propose un widget d ecran d accueil affichant niveau, serie et pointage du jour. Le widget lit exactement les memes donnees que l app, toutes issues du stockage local decrit plus haut, sans collecte ni transfert supplementaire.", "de": "Die App bietet ein Startbildschirm-Widget mit Level, Serie und Tages-Check-in. Das Widget liest genau dieselben Daten wie die App, alle aus dem oben beschriebenen lokalen Speicher, ohne zusaetzliches Sammeln oder Uebertragen.", "pt": "O app oferece um widget de tela inicial com nivel, sequencia e check-in. O widget le exatamente os mesmos dados do app, todos do armazenamento local descrito acima, sem coleta nem transmissao extra.", "ru": "Приложение даёт виджет на главном экране с уровнем, серией и отметкой дня. Виджет читает ровно те же данные, что и приложение, — всё из локального хранилища, описанного выше, без дополнительного сбора и передачи.", "it": "L app offre un widget di sistema con livello, serie e check-in. Il widget legge esattamente gli stessi dati dell app, tutti dalla memoria locale descritta sopra, senza raccolta o trasmissione aggiuntiva.", "ar": "يوفّر التطبيق أداة على الشاشة الرئيسية تعرض المستوى والتتابع وتسجيل اليوم. تقرأ الأداة البيانات نفسها التي يقرأها التطبيق، وكلها من التخزين المحلي المذكور أعلاه، دون أي جمع أو إرسال إضافي.", "zh-Hant": "本應用提供桌面服務卡片（顯示等級、連勝與今日打卡狀態）。卡片讀取的資料與主應用完全相同，均來自上述本機儲存，不涉及任何額外的資訊收集或網路傳輸。" },
  "本应用为全年龄向休闲益智游戏合集，内容为经典益智玩法（数字合并、扫雷、数独等），不含暴力、色情、赌博、恐怖或其他不适宜内容，不含社交功能，不含用户间交流，不含任何付费项目。由于不收集任何个人信息，因此不存在未成年人个人信息被收集的风险。": { "ja": "本アプリは全年齢向けのパズルゲーム集で、内容は古典的なパズル（数字合わせ、マインスイーパ、数独など）です。暴力・性的表現・ギャンブル・ホラーその他の不適切な内容、SNS機能、利用者どうしの交流、有料項目は一切ありません。個人情報を収集しないため、未成年者の個人情報が集められる恐れもありません。", "ko": "이 앱은 전 연령용 퍼즐 모음으로, 내용은 고전 퍼즐(숫자 합치기, 지뢰찾기, 스도쿠 등)입니다. 폭력, 성적 표현, 도박, 공포 등 부적절한 내용이 없고, 소셜 기능도 이용자 간 대화도 유료 항목도 없습니다. 개인정보를 수집하지 않으므로 미성년자 개인정보가 수집될 위험도 없습니다.", "es": "Es una coleccion de puzles para todas las edades con juegos clasicos (fusionar numeros, buscaminas, sudoku, etc.). No contiene violencia, contenido sexual, apuestas, terror ni nada inadecuado, ni funciones sociales, ni comunicacion entre usuarios, ni pagos. Como no se recoge informacion personal, no existe riesgo para los menores.", "fr": "C est une collection de puzzles pour tous les ages, avec des jeux classiques (fusion de nombres, demineur, sudoku, etc.). Aucune violence, aucun contenu sexuel, aucun jeu d argent, aucune horreur ni contenu inadapte, aucune fonction sociale, aucun echange entre utilisateurs, aucun paiement. Comme aucune donnee personnelle n est collectee, aucun risque n existe pour les mineurs.", "de": "Es ist eine Puzzlesammlung fuer alle Altersgruppen mit Klassikern (Zahlen zusammenfuegen, Minesweeper, Sudoku und so weiter). Keine Gewalt, keine sexuellen Inhalte, kein Gluecksspiel, kein Horror und nichts Ungeeignetes, keine sozialen Funktionen, kein Austausch zwischen Nutzern, keine Bezahlangebote. Da keine persoenlichen Daten erhoben werden, besteht auch kein Risiko fuer Minderjaehrige.", "pt": "E uma colecao de quebra-cabecas para todas as idades, com jogos classicos (juntar numeros, campo minado, sudoku etc.). Nao ha violencia, conteudo sexual, apostas, terror ou qualquer conteudo inadequado, nem funcoes sociais, nem conversa entre usuarios, nem itens pagos. Como nenhum dado pessoal e coletado, nao ha risco para menores.", "ru": "Это сборник головоломок для всех возрастов: классические игры (слияние чисел, сапёр, судоку и другие). Здесь нет насилия, сексуального контента, азартных игр, ужасов и другого неподходящего, нет соцфункций, переписки между пользователями и платных покупок. Личные данные не собираются, поэтому риска для несовершеннолетних нет.", "it": "E una raccolta di puzzle per tutte le eta, con giochi classici (unire numeri, campo minato, sudoku e altri). Nessuna violenza, contenuto sessuale, gioco d azzardo, horror o altro materiale inadatto, nessuna funzione social, nessuno scambio tra utenti, nessun acquisto. Poiche non si raccolgono dati personali, non esiste alcun rischio per i minori.", "ar": "هذا التطبيق مجموعة ألعاب ذهنية لكل الأعمار، ومحتواها ألعاب كلاسيكية (دمج الأرقام، كانسة الألغام، سودوكو وغيرها). لا يحتوي على عنف أو محتوى جنسي أو قمار أو رعب أو أي محتوى غير مناسب، ولا ميزات اجتماعية ولا تواصل بين المستخدمين ولا مشتريات. ولأنه لا يجمع أي بيانات شخصية، فلا خطر على بيانات القاصرين.", "zh-Hant": "本應用為全年齡向休閒益智遊戲合集，內容為經典益智玩法（數字合併、掃雷、數獨等），不含暴力、色情、賭博、恐怖或其他不適宜內容，不含社交功能，不含使用者間交流，不含任何付費項目。由於不收集任何個人資訊，因此不存在未成年人個人資訊被收集的風險。" },
  "你对自己的本地数据拥有完全控制权：\n· 清除数据：系统「设置 → 应用 → One More → 存储 → 清除数据」\n· 彻底删除：卸载应用即可\n· 也可以在应用「设置 → 重置进度」里一键清空": { "ja": "自分のローカルデータは完全に自分で管理できます：\n・ データ消去：設定 → アプリ → 一局 → ストレージ → データを消去\n・ 完全削除：アプリをアンインストール\n・ アプリ内の「設定 → 進行をリセット」で一発消去も可能", "ko": "자신의 로컬 데이터를 완전히 통제할 수 있습니다:\n· 데이터 지우기: 설정 → 앱 → 一局 → 저장공간 → 데이터 지우기\n· 완전 삭제: 앱 삭제\n· 앱 안의 설정 → 진행 초기화로 한 번에 비울 수도 있습니다", "es": "Tienes control total sobre tus datos locales:\n· Borrar datos: Ajustes → Apps → One More → Almacenamiento → Borrar datos\n· Borrado total: desinstala la app\n· O usa Reiniciar progreso dentro de la app para vaciarlo de una vez", "fr": "Vous controle totalement vos donnees locales :\n· Effacer les donnees : Reglages → Applications → One More → Stockage → Effacer\n· Suppression totale : desinstallez l app\n· Ou utilisez Reinitialiser dans l app pour tout vider d un coup", "de": "Du hast die volle Kontrolle ueber deine lokalen Daten:\n· Daten loeschen: Einstellungen → Apps → One More → Speicher → Daten loeschen\n· Voellig entfernen: App deinstallieren\n· Oder in der App Fortschritt zuruecksetzen nutzen", "pt": "Voce tem controle total sobre seus dados locais:\n· Apagar dados: Ajustes → Apps → One More → Armazenamento → Apagar dados\n· Remover de vez: desinstale o app\n· Ou use Apagar progresso dentro do app para limpar tudo de uma vez", "ru": "Вы полностью управляете своими локальными данными:\n· Очистить данные: Настройки → Приложения → One More → Память → Очистить\n· Удалить полностью: удалите приложение\n· Или нажмите «Сбросить прогресс» в приложении", "it": "Hai il pieno controllo sui tuoi dati locali:\n· Cancella dati: Impostazioni → App → One More → Archiviazione → Cancella dati\n· Rimozione totale: disinstalla l app\n· Oppure usa Azzera progressi nell app per svuotare tutto in un tocco", "ar": "لديك سيطرة كاملة على بياناتك المحلية:\n· مسح البيانات: الإعدادات ← التطبيقات ← One More ← التخزين ← مسح البيانات\n· الحذف الكامل: إزالة التطبيق\n· أو استخدم «مسح التقدم» داخل التطبيق لمسح كل شيء بضغطة", "zh-Hant": "你對自己的本機資料擁有完全控制權：\n· 清除資料：系統「設定 → 應用 → 一局 → 儲存 → 清除資料」\n· 徹底刪除：卸載應用即可\n· 也可以在應用「設定 → 重置進度」裡一鍵清空" },
  "本应用为个人开发者独立开发的休闲益智游戏合集：\n· 全部代码为原创编写（ArkTS / ArkUI 原生开发）\n· 玩法均为公有领域的经典益智玩法\n· 未复制、未改编任何第三方项目的代码、美术资源或名称\n· 未使用任何第三方依赖库\n· 图标与界面视觉均为原创设计": { "ja": "本アプリは個人開発者が単独で作ったパズルゲーム集です：\n・ すべてのコードは自作（ArkTS / ArkUI のネイティブ開発）\n・ 玩法はすべて公有領域の古典パズル\n・ 第三者のコード・素材・名称を複製も改変もしていません\n・ 第三者ライブラリを一切使用していません\n・ アイコンと画面デザインはすべて自作です", "ko": "이 앱은 개인 개발자가 혼자 만든 퍼즐 모음입니다:\n· 모든 코드는 직접 작성(ArkTS / ArkUI 네이티브 개발)\n· 모든 게임은 퍼블릭 도메인의 고전 퍼즐\n· 어떤 제3자 프로젝트의 코드, 이미지, 이름도 복제하거나 각색하지 않았습니다\n· 제3자 라이브러리를 사용하지 않았습니다\n· 아이콘과 화면 디자인은 모두 자체 제작입니다", "es": "Es una coleccion de puzles desarrollada en solitario por un desarrollador independiente:\n· Todo el codigo es original (desarrollo nativo en ArkTS / ArkUI)\n· Todas las mecanicas son puzles clasicos de dominio publico\n· No se ha copiado ni adaptado codigo, arte ni nombre de ningun proyecto de terceros\n· No se usa ninguna libreria de terceros\n· El icono y todo el diseno visual son originales", "fr": "C est une collection de puzzles developpee seule par un developpeur independant :\n· Tout le code est original (developpement natif ArkTS / ArkUI)\n· Toutes les mecaniques sont des puzzles classiques du domaine public\n· Aucun code, visuel ou nom de projet tiers n a ete copie ni adapte\n· Aucune bibliotheque tierce n est utilisee\n· L icone et tout le design visuel sont originaux", "de": "Es ist eine Puzzlesammlung, die ein einzelner Entwickler selbst gebaut hat:\n· Der gesamte Code ist selbst geschrieben (native Entwicklung mit ArkTS / ArkUI)\n· Alle Spielideen stammen aus gemeinfreien Klassikern\n· Kein Code, keine Grafik und kein Name eines fremden Projekts wurde kopiert oder bearbeitet\n· Es werden keine fremden Bibliotheken verwendet\n· Icon und gesamtes Erscheinungsbild sind eigene Entwuerfe", "pt": "E uma colecao de quebra-cabecas desenvolvida sozinha por um desenvolvedor independente:\n· Todo o codigo e original (desenvolvimento nativo em ArkTS / ArkUI)\n· Todas as mecanicas sao quebra-cabecas classicos de dominio publico\n· Nenhum codigo, arte ou nome de projeto de terceiros foi copiado ou adaptado\n· Nenhuma biblioteca de terceiros e usada\n· O icone e todo o visual sao originais", "ru": "Это сборник головоломок, сделанный одним независимым разработчиком:\n· Весь код написан самостоятельно (нативная разработка на ArkTS / ArkUI)\n· Все механики — классические головоломки из общественного достояния\n· Код, графика и названия сторонних проектов не копировались и не переделывались\n· Сторонние библиотеки не используются\n· Иконка и весь визуальный дизайн созданы самостоятельно", "it": "E una raccolta di puzzle sviluppata da un singolo sviluppatore indipendente:\n· Tutto il codice e originale (sviluppo nativo in ArkTS / ArkUI)\n· Tutte le meccaniche sono puzzle classici di pubblico dominio\n· Nessun codice, grafica o nome di progetti terzi e stato copiato o adattato\n· Non si usano librerie di terze parti\n· L icona e tutto il design visivo sono originali", "ar": "هذا التطبيق مجموعة ألعاب ذهنية طوّرها مطوّر فردي مستقل:\n· كل الشيفرة مكتوبة أصلاً (تطوير أصلي بـ ArkTS / ArkUI)\n· جميع أساليب اللعب ألعاب كلاسيكية من الملكية العامة\n· لم يُنسخ أو يُعدّل أي شيفرة أو رسم أو اسم من مشاريع أخرى\n· لا تُستخدم أي مكتبات من طرف ثالث\n· الأيقونة وكل التصميم البصري من تصميم أصلي", "zh-Hant": "本應用為個人開發者獨立開發的休閒益智遊戲合集：\n· 全部程式碼為原創撰寫（ArkTS / ArkUI 原生開發）\n· 玩法均為公有領域的經典益智玩法\n· 未複製、未改編任何第三方專案的程式碼、美術資源或名稱\n· 未使用任何第三方依賴函式庫\n· 圖示與介面視覺均為原創設計" },
  "🏅 成就": { "ja": "🏅 実績", "ko": "🏅 업적", "es": "🏅 Logros", "fr": "🏅 Succes", "de": "🏅 Erfolge", "pt": "🏅 Conquistas", "ru": "🏅 Достижения", "it": "🏅 Obiettivi", "ar": "🏅 الإنجازات", "zh-Hant": "🏅 成就" },
  "看全部 ": { "ja": "すべて見る ", "ko": "전체 보기 ", "es": "Ver todo ", "fr": "Tout voir ", "de": "Alle ansehen ", "pt": "Ver tudo ", "ru": "Смотреть все ", "it": "Vedi tutto ", "ar": "عرض الكل ", "zh-Hant": "看全部 " },
  "开始 ›": { "ja": "開始 ›", "ko": "시작 ›", "es": "Jugar ›", "fr": "Jouer ›", "de": "Start ›", "pt": "Jogar ›", "ru": "Играть ›", "it": "Gioca ›", "ar": "ابدأ ›", "zh-Hant": "開始 ›" },
  "收起 ▲": { "ja": "閉じる ▲", "ko": "접기 ▲", "es": "Menos ▲", "fr": "Reduire ▲", "de": "Weniger ▲", "pt": "Menos ▲", "ru": "Свернуть ▲", "it": "Meno ▲", "ar": "أقل ▲", "zh-Hant": "收起 ▲" },
  "展开 ▼": { "ja": "もっと ▼", "ko": "펼치기 ▼", "es": "Mas ▼", "fr": "Plus ▼", "de": "Mehr ▼", "pt": "Mais ▼", "ru": "Развернуть ▼", "it": "Altro ▼", "ar": "المزيد ▼", "zh-Hant": "展開 ▼" },
  "↻ 右上角": { "ja": "↻ 右上", "ko": "↻ 오른쪽 위", "es": "↻ arriba a la derecha", "fr": "↻ en haut a droite", "de": "↻ oben rechts", "pt": "↻ canto superior direito", "ru": "↻ справа вверху", "it": "↻ in alto a destra", "ar": "↻ أعلى اليمين", "zh-Hant": "↻ 右上角" },
  "‹ 左上角": { "ja": "‹ 左上", "ko": "‹ 왼쪽 위", "es": "‹ arriba a la izquierda", "fr": "‹ en haut a gauche", "de": "‹ oben links", "pt": "‹ canto superior esquerdo", "ru": "‹ слева вверху", "it": "‹ in alto a sinistra", "ar": "‹ أعلى اليسار", "zh-Hant": "‹ 左上角" },
  "对手落子：": { "ja": "相手の着手：", "ko": "상대의 수: ", "es": "Jugada del rival: ", "fr": "Coup adverse : ", "de": "Gegnerzug: ", "pt": "Jogada do rival: ", "ru": "Ход соперника: ", "it": "Mossa avversaria: ", "ar": "نقلة الخصم: ", "zh-Hant": "對手落子：" },
  "🔍 难度自证": { "ja": "🔍 難易度チェック", "ko": "🔍 난이도 확인", "es": "🔍 Comprobar dificultad", "fr": "🔍 Verif. difficulte", "de": "🔍 Schwierigkeit", "pt": "🔍 Conferir dificuldade", "ru": "🔍 Проверка сложности", "it": "🔍 Verifica difficolta", "ar": "🔍 تحقق الصعوبة", "zh-Hant": "🔍 難度自證" },
  "✅ 今日已打卡": { "ja": "✅ 今日チェック済み", "ko": "✅ 오늘 체크인 완료", "es": "✅ Marcado hoy", "fr": "✅ Fait aujourd hui", "de": "✅ Heute erledigt", "pt": "✅ Marcado hoje", "ru": "✅ Отмечено сегодня", "it": "✅ Fatto oggi", "ar": "✅ تم اليوم", "zh-Hant": "✅ 今日已打卡" },
  "🎖️ 游戏徽章": { "ja": "🎖️ ゲームバッジ", "ko": "🎖️ 게임 배지", "es": "🎖️ Insignias", "fr": "🎖️ Badges", "de": "🎖️ Abzeichen", "pt": "🎖️ Emblemas", "ru": "🎖️ Значки", "it": "🎖️ Distintivi", "ar": "🎖️ الأوسمة", "zh-Hant": "🎖️ 遊戲徽章" },
  "对手已连上！开局…": { "ja": "相手が接続！開始…", "ko": "상대 연결됨! 시작…", "es": "¡Rival conectado! Empezando…", "fr": "Adversaire connecte ! On commence…", "de": "Gegner verbunden! Start…", "pt": "Rival conectado! Comecando…", "ru": "Соперник подключён! Начинаем…", "it": "Avversario connesso! Si parte…", "ar": "تم اتصال الخصم! نبدأ…", "zh-Hant": "對手已連上！開局…" },
  "已连上房主，开局…": { "ja": "ホストに接続、開始…", "ko": "호스트 연결됨, 시작…", "es": "Conectado al anfitrion, empezando…", "fr": "Connecte a l hote, on commence…", "de": "Mit Host verbunden, Start…", "pt": "Conectado ao anfitriao, comecando…", "ru": "Подключено к хосту, начинаем…", "it": "Connesso all host, si parte…", "ar": "تم الاتصال بالمضيف، نبدأ…", "zh-Hant": "已連上房主，開局…" },
  "⭕ 还没玩 · 来一局就打卡": { "ja": "⭕ 未プレイ・1回で達成", "ko": "⭕ 아직 없음 · 한 판 하면 완료", "es": "⭕ Nada aun: juega una", "fr": "⭕ Rien encore — jouez", "de": "⭕ Noch nichts — spiel eine", "pt": "⭕ Nada ainda — jogue uma", "ru": "⭕ Пока пусто — сыграйте", "it": "⭕ Ancora nulla — gioca", "ar": "⭕ لا شيء بعد — العب جولة", "zh-Hant": "⭕ 還沒玩 · 來一局就打卡" },
  "进过的游戏会记在这里 —— 看\"实际\"一列是否随难度变化": { "ja": "遊んだゲームがここに記録されます —— 「実際」列が難易度で変わるか見てください", "ko": "플레이한 게임이 여기 기록됩니다 — '실제' 열이 난이도에 따라 바뀌는지 보세요", "es": "Los juegos que abras aparecen aqui: mira si la columna real cambia con la dificultad", "fr": "Les jeux ouverts apparaissent ici : voyez si la colonne reelle change avec la difficulte", "de": "Gespielte Spiele erscheinen hier — sieh, ob sich die Spalte mit der Schwierigkeit aendert", "pt": "Os jogos abertos aparecem aqui: veja se a coluna real muda com a dificuldade", "ru": "Сыгранные игры появятся здесь — смотрите, меняется ли столбец с уровнем сложности", "it": "I giochi aperti compaiono qui: guarda se la colonna reale cambia con la difficolta", "ar": "تظهر الألعاب التي لعبتها هنا — راقب هل يتغير عمود القيمة مع الصعوبة", "zh-Hant": "玩過的遊戲會記在這裡 —— 看「實際」一欄是否隨難度變化" },
  "同一 Wi-Fi 下的两台设备直接对局 —— 没有服务器，不上传任何数据": { "ja": "同じWi-Fiの2台で直接対戦 —— サーバーなし、送信なし", "ko": "같은 Wi-Fi의 두 기기로 직접 대전 — 서버 없음, 전송 없음", "es": "Dos dispositivos en la misma Wi-Fi, sin servidor ni subidas", "fr": "Deux appareils sur le meme Wi-Fi, sans serveur ni envoi", "de": "Zwei Geraete im selben WLAN, kein Server, nichts wird gesendet", "pt": "Dois aparelhos no mesmo Wi-Fi, sem servidor e sem envio", "ru": "Два устройства в одной сети, без сервера и без отправки данных", "it": "Due dispositivi sullo stesso Wi-Fi, senza server ne invii", "ar": "جهازان على نفس الشبكة، بلا خادم وبلا إرسال", "zh-Hant": "同一 Wi-Fi 下的兩台裝置直接對局 —— 沒有伺服器，不上傳任何資料" },
  "「One More」不采集、不上传你的任何个人信息；你在应用里的所有记录，都只存在你自己的手机里。单机玩法全程不需要网络。": { "ja": "「One More」は通信も収集も送信もしません。アプリ内の記録はすべてあなたの端末にだけ残ります。", "ko": "「One More」는 인터넷도 수집도 전송도 하지 않습니다. 앱 안의 모든 기록은 당신의 기기에만 남습니다.", "es": "One More no se conecta, no recoge ni sube ningun dato tuyo. Todo queda en tu telefono.", "fr": "One More ne se connecte pas, ne collecte rien et n envoie rien. Tout reste sur votre telephone.", "de": "One More geht nicht online, sammelt nichts und sendet nichts. Alles bleibt auf deinem Geraet.", "pt": "One More nao acessa a internet, nao coleta e nao envia nada seu. Tudo fica no seu aparelho.", "ru": "One More не выходит в сеть, ничего не собирает и не отправляет. Всё остаётся на вашем телефоне.", "it": "One More non si connette, non raccoglie e non invia nulla. Tutto resta sul tuo telefono.", "ar": "لا يتصل التطبيق بالإنترنت ولا يجمع ولا يرسل أي بيانات شخصية. كل السجلات تبقى على هاتفك.", "zh-Hant": "「一局」不聯網、不採集、不上傳你的任何個人資訊。你在應用裡的所有記錄，都只存在你自己的手機裡。" },
  "{n} 局": { "ja": "{n}局", "ko": "{n}판", "es": "{n} partidas", "fr": "{n} parties", "de": "{n} Runden", "pt": "{n} partidas", "ru": "{n} игр", "it": "{n} partite", "ar": "{n} جولات", "zh-Hant": "{n} 局" },
  "{n} 款": { "ja": "{n}本", "ko": "{n}개", "es": "{n} juegos", "fr": "{n} jeux", "de": "{n} Spiele", "pt": "{n} jogos", "ru": "{n} игр", "it": "{n} giochi", "ar": "{n} لعبة", "zh-Hant": "{n} 款" },
  "{n} 天": { "ja": "{n}日", "ko": "{n}일", "es": "{n} dias", "fr": "{n} jours", "de": "{n} Tage", "pt": "{n} dias", "ru": "{n} дн.", "it": "{n} giorni", "ar": "{n} يوم", "zh-Hant": "{n} 天" },
  "再攒 {n} 点经验就升级": { "ja": "あと{n}EXPでレベルアップ", "ko": "{n} 경험치 더 모으면 레벨업", "es": "{n} XP para subir", "fr": "{n} XP avant le niveau suivant", "de": "Noch {n} XP bis zum Level", "pt": "{n} XP para subir", "ru": "Ещё {n} опыта до уровня", "it": "{n} XP per salire", "ar": "تبقى {n} خبرة للمستوى التالي", "zh-Hant": "再攢 {n} 點經驗就升級" },
  "{n} 款已记录": { "ja": "{n}本を記録", "ko": "{n}개 기록됨", "es": "{n} juegos registrados", "fr": "{n} jeux enregistres", "de": "{n} Spiele erfasst", "pt": "{n} jogos registrados", "ru": "Записано игр: {n}", "it": "{n} giochi registrati", "ar": "{n} لعبة مسجلة", "zh-Hant": "{n} 款已記錄" },
  "升到 LV {n}": { "ja": "LV {n} に到達", "ko": "LV {n} 달성", "es": "Llega a LV {n}", "fr": "Niveau LV {n}", "de": "LV {n} erreicht", "pt": "Chegou ao LV {n}", "ru": "Достигнут LV {n}", "it": "Livello LV {n}", "ar": "وصلت إلى LV {n}", "zh-Hant": "升到 LV {n}" },
  "等级": { "ja": "レベル", "ko": "레벨", "es": "Nivel", "fr": "Niveau", "de": "Level", "pt": "Nível", "ru": "Уровень", "it": "Livello", "ar": "المستوى", "zh-Hant": "等級" },
  "收藏": { "ja": "お気に入り", "ko": "즐겨찾기", "es": "Guardados", "fr": "Favoris", "de": "Favoriten", "pt": "Salvos", "ru": "Избранное", "it": "Salvati", "ar": "المحفوظة", "zh-Hant": "收藏" },
  "共 {n} 款游戏": { "ja": "全{n}本", "ko": "총 {n}개 게임", "es": "{n} juegos en total", "fr": "{n} jeux au total", "de": "Insgesamt {n} Spiele", "pt": "{n} jogos no total", "ru": "Всего игр: {n}", "it": "{n} giochi in totale", "ar": "{n} لعبة إجمالاً", "zh-Hant": "共 {n} 款遊戲" },
  "{n} 分钟": { "ja": "{n}分", "ko": "{n}분", "es": "{n} min", "fr": "{n} min", "de": "{n} Min.", "pt": "{n} min", "ru": "{n} мин", "it": "{n} min", "ar": "{n} دقيقة", "zh-Hant": "{n} 分鐘" },
  "{n} 款小游戏，不用联网也能玩": { "ja": "{n}本のミニゲーム。通信不要", "ko": "{n}개 미니게임. 인터넷 불필요", "es": "{n} minijuegos, sin conexión", "fr": "{n} mini-jeux, sans connexion", "de": "{n} Mini-Spiele, offline spielbar", "pt": "{n} minijogos, sem internet", "ru": "{n} мини-игр без интернета", "it": "{n} mini-giochi, senza rete", "ar": "{n} لعبة صغيرة بلا إنترنت", "zh-Hant": "{n} 款小遊戲，不用聯網也能玩" },
  "等级、通关记录、收藏和统计全部归零": { "ja": "レベル・クリア記録・お気に入り・統計がすべてゼロに", "ko": "레벨, 클리어 기록, 즐겨찾기, 통계가 모두 0이 됩니다", "es": "Nivel, partidas, guardados y estadísticas vuelven a cero", "fr": "Niveau, parties, favoris et stats reviennent à zéro", "de": "Level, Erfolge, Favoriten und Statistik gehen auf null", "pt": "Nível, partidas, salvos e estatísticas voltam a zero", "ru": "Уровень, рекорды, избранное и статистика обнулятся", "it": "Livello, partite, salvati e statistiche tornano a zero", "ar": "يعود المستوى والسجلات والمحفوظة والإحصائيات إلى الصفر", "zh-Hant": "等級、通關記錄、收藏和統計全部歸零" },
  "这个应用不做什么，都写在这儿": { "ja": "このアプリが何をしないか、ここに全部書いてあります", "ko": "이 앱이 하지 않는 일을 여기 적었어요", "es": "Aquí contamos lo que la app no hace", "fr": "Ce que l app ne fait pas est écrit ici", "de": "Was die App nicht tut, steht hier", "pt": "O que o app não faz está escrito aqui", "ru": "Здесь написано, чего приложение не делает", "it": "Qui c è scritto cosa non fa l app", "ar": "ما لا يفعله التطبيق مكتوب هنا", "zh-Hant": "這個應用不做什麼，都寫在這兒" },
  "无广告": { "ja": "広告なし", "ko": "광고 없음", "es": "Sin anuncios", "fr": "Sans pub", "de": "Keine Werbung", "pt": "Sem anúncios", "ru": "Без рекламы", "it": "Niente pubblicità", "ar": "بلا إعلانات", "zh-Hant": "無廣告" },
  "没有开屏广告、弹窗广告和看视频解锁": { "ja": "起動広告・ポップアップ広告・動画視聴解除はありません", "ko": "시작 광고, 팝업 광고, 영상 시청 해제가 없습니다", "es": "Sin anuncios de inicio, emergentes ni vídeos para desbloquear", "fr": "Aucune pub au lancement, en pop-up ou à débloquer par vidéo", "de": "Keine Start-, Pop-up- oder Video-Werbung", "pt": "Sem anúncio de abertura, pop-up ou vídeo para liberar", "ru": "Ни стартовой рекламы, ни всплывающей, ни за просмотр видео", "it": "Nessun annuncio iniziale, pop-up o video da guardare", "ar": "لا إعلانات بدء ولا نوافذ منبثقة ولا فيديو للفتح", "zh-Hant": "沒有開屏廣告、彈窗廣告和看影片解鎖" },
  "已经清干净了：等级回到 1，通关和收藏都归零 ✅": { "ja": "きれいに消しました：レベルは1、クリアとお気に入りはゼロ ✅", "ko": "깨끗이 지웠어요: 레벨은 1, 클리어와 즐겨찾기는 0 ✅", "es": "Todo limpio: nivel 1, partidas y guardados a cero ✅", "fr": "Tout est effacé : niveau 1, parties et favoris à zéro ✅", "de": "Alles gelöscht: Level 1, Erfolge und Favoriten auf null ✅", "pt": "Tudo limpo: nível 1, partidas e salvos zerados ✅", "ru": "Всё очищено: уровень 1, рекорды и избранное обнулены ✅", "it": "Tutto pulito: livello 1, partite e salvati a zero ✅", "ar": "تم المسح: المستوى 1 والسجلات والمحفوظة صفر ✅", "zh-Hant": "已經清乾淨了：等級回到 1，通關和收藏都歸零 ✅" },
  "重置没成功 —— 请再试一次，或到系统设置里清除应用数据 ↺": { "ja": "リセットできませんでした —— もう一度試すか、端末設定でデータを消去してください ↺", "ko": "초기화하지 못했어요 — 다시 시도하거나 기기 설정에서 데이터를 지우세요 ↺", "es": "No se pudo borrar: inténtalo otra vez o borra los datos desde los ajustes ↺", "fr": "Échec : réessayez ou effacez les données dans les réglages ↺", "de": "Fehlgeschlagen — erneut versuchen oder Daten in den Einstellungen löschen ↺", "pt": "Não deu: tente de novo ou apague os dados nas configurações ↺", "ru": "Не удалось — попробуйте снова или очистите данные в настройках ↺", "it": "Non riuscito: riprova o cancella i dati dalle impostazioni ↺", "ar": "لم ينجح — أعد المحاولة أو امسح البيانات من إعدادات الجهاز ↺", "zh-Hant": "重置沒成功 —— 請再試一次，或到系統設定裡清除應用資料 ↺" },
  "靛蓝": { "ja": "インディゴ", "ko": "남색", "es": "Índigo", "fr": "Indigo", "de": "Indigo", "pt": "Índigo", "ru": "Индиго", "it": "Indaco", "ar": "نيلي", "zh-Hant": "靛藍" },
  "红": { "ja": "赤", "ko": "빨강", "es": "Rojo", "fr": "Rouge", "de": "Rot", "pt": "Vermelho", "ru": "Красный", "it": "Rosso", "ar": "أحمر", "zh-Hant": "紅" },
  "橙": { "ja": "オレンジ", "ko": "주황", "es": "Naranja", "fr": "Orange", "de": "Orange", "pt": "Laranja", "ru": "Оранжевый", "it": "Arancione", "ar": "برتقالي", "zh-Hant": "橙" },
  "黄": { "ja": "黄", "ko": "노랑", "es": "Amarillo", "fr": "Jaune", "de": "Gelb", "pt": "Amarelo", "ru": "Жёлтый", "it": "Giallo", "ar": "أصفر", "zh-Hant": "黃" },
  "绿": { "ja": "緑", "ko": "초록", "es": "Verde", "fr": "Vert", "de": "Grün", "pt": "Verde", "ru": "Зелёный", "it": "Verde", "ar": "أخضر", "zh-Hant": "綠" },
  "青": { "ja": "シアン", "ko": "청록", "es": "Cian", "fr": "Cyan", "de": "Türkis", "pt": "Ciano", "ru": "Голубой", "it": "Ciano", "ar": "سماوي", "zh-Hant": "青" },
  "蓝": { "ja": "青", "ko": "파랑", "es": "Azul", "fr": "Bleu", "de": "Blau", "pt": "Azul", "ru": "Синий", "it": "Blu", "ar": "أزرق", "zh-Hant": "藍" },
  "紫": { "ja": "紫", "ko": "보라", "es": "Morado", "fr": "Violet", "de": "Violett", "pt": "Roxo", "ru": "Фиолетовый", "it": "Viola", "ar": "بنفسجي", "zh-Hant": "紫" },
  "品红": { "ja": "マゼンタ", "ko": "자홍", "es": "Magenta", "fr": "Magenta", "de": "Magenta", "pt": "Magenta", "ru": "Пурпурный", "it": "Magenta", "ar": "أرجواني", "zh-Hant": "品紅" },
  "天蓝": { "ja": "スカイブルー", "ko": "하늘색", "es": "Celeste", "fr": "Bleu ciel", "de": "Himmelblau", "pt": "Azul-céu", "ru": "Небесно-голубой", "it": "Azzurro", "ar": "أزرق سماوي", "zh-Hant": "天藍" },
  "石墨": { "ja": "グレー", "ko": "회색", "es": "Gris", "fr": "Gris", "de": "Grau", "pt": "Cinza", "ru": "Серый", "it": "Grigio", "ar": "رمادي", "zh-Hant": "石墨" },
  "游戏宗师": { "ja": "ゲームのグランドマスター", "ko": "게임 그랜드마스터", "es": "Gran Maestro", "fr": "Grandmaster", "de": "Meister", "pt": "Grande Mestre", "ru": "Гроссмейстер", "it": "Maestro di gioco", "ar": "أستاذ الألعاب", "zh-Hant": "遊戲宗師" },
  "解谜高手": { "ja": "パズルマスター", "ko": "퍼즐 마스터", "es": "Maestro de Enigmas", "fr": "Maître des puzzles", "de": "Rätselmeister", "pt": "Mestre de Enigmas", "ru": "Мастер головоломок", "it": "Maestro di enigmi", "ar": "خبير الألغاز", "zh-Hant": "解謎高手" },
  "益智达人": { "ja": "パズルプロ", "ko": "퍼즐 고수", "es": "Experto en Rompecabezas", "fr": "Expert en énigmes", "de": "Puzzle-Profi", "pt": "Especialista em Quebra-Cabeças", "ru": "Профи пазлов", "it": "Esperto di puzzle", "ar": "محترف الألغاز", "zh-Hant": "益智達人" },
  "初窥门径": { "ja": "最初の一歩", "ko": "첫걸음", "es": "Primeros Pasos", "fr": "Premiers pas", "de": "Erste Schritte", "pt": "Primeiros Passos", "ru": "Первые шаги", "it": "Primi passi", "ar": "الخطوات الأولى", "zh-Hant": "初窺門徑" },
  "新手上路": { "ja": "初心者", "ko": "초보자", "es": "Principiante", "fr": "Débutant", "de": "Neuling", "pt": "Iniciante", "ru": "Новичок", "it": "Principiante", "ar": "مبتدئ", "zh-Hant": "新手上路" },
  "小时": { "ja": "時間", "ko": "시간", "es": "h", "fr": "h", "de": "h", "pt": "h", "ru": "ч", "it": "h", "ar": "ساعة", "zh-Hant": "小時" },
  "分": { "ja": "分", "ko": "분", "es": "min", "fr": "min", "de": "min", "pt": "min", "ru": "мин", "it": "min", "ar": "دقيقة", "zh-Hant": "分" },
  "局": { "ja": "ラウンド", "ko": "판", "es": "partidas", "fr": "parties", "de": "Runden", "pt": "rodadas", "ru": "раундов", "it": "rounds", "ar": "جولة", "zh-Hant": "局" },
  "款": { "ja": "ゲーム", "ko": "개", "es": "juegos", "fr": "jeux", "de": "Spiele", "pt": "jogos", "ru": "игр", "it": "giochi", "ar": "لعبة", "zh-Hant": "款" },
  "一共攒了 {n} 点经验": { "ja": "{n} の経験値を獲得", "ko": "{n} 경험치 획득", "es": "{n} PX ganados", "fr": "{n} XP gagnés", "de": "{n} XP verdient", "pt": "{n} XP ganhos", "ru": "{n} очков опыта заработано", "it": "{n} XP guadagnati", "ar": "حصلت على {n} نقطة خبرة", "zh-Hant": "一共攢了 {n} 點經驗" },
  "连胜 {n} 天": { "ja": "連勝 {n} 日", "ko": "{n}일 연속", "es": "Racha {n} días", "fr": "Série de {n} jours", "de": "Serienrekord {n} Tage", "pt": "Série de {n} dias", "ru": "Серия {n} дней", "it": "Striscia {n} giorni", "ar": "سلسلة {n} يوم", "zh-Hant": "連勝 {n} 天" },
  "最长连了 {n} 天": { "ja": "最長 {n} 日", "ko": "최장 {n}일 연속", "es": "Más largo {n} días", "fr": "Plus longue série de {n} jours", "de": "Längste Serie {n} Tage", "pt": "Maior série de {n} dias", "ru": "Наибольшая серия {n} дней", "it": "Massima {n} giorni", "ar": "أطول سلسلة {n} يوم", "zh-Hant": "最長連了 {n} 天" },
  "今天玩了 {n} 局": { "ja": "今日 {n} ラウンド", "ko": "오늘 {n}판", "es": "Hoy {n} partidas", "fr": "{n} parties aujourd'hui", "de": "Heute {n} Runden gespielt", "pt": "Jogou {n} rodadas hoje", "ru": "Играл сегодня {n} раундов", "it": "Oggi {n} rounds", "ar": "اليوم {n} جولة", "zh-Hant": "今天玩了 {n} 局" },
  "收藏 {n} 款": { "ja": "お気に入り {n}", "ko": "저장 {n}개", "es": "Guardados {n}", "fr": "{n} jeux sauvegardés", "de": "Gespeichert {n}", "pt": "Salvou {n}", "ru": "Сохранено {n}", "it": "Salvati {n}", "ar": "المحفوظة {n}", "zh-Hant": "收藏 {n} 款" },
  "玩过 {n} 次": { "ja": "{n} 回プレイ", "ko": "{n}회 플레이", "es": "Jugado {n} veces", "fr": "Joué {n} fois", "de": "{n} mal gespielt", "pt": "Jogado {n} vezes", "ru": "Играл {n} раз", "it": "Giocate {n} volte", "ar": "لعبت {n} مرة", "zh-Hant": "玩過 {n} 次" },
  "最高 {n}": { "ja": "最高 {n}", "ko": "최고 {n}", "es": "Mejor {n}", "fr": "Meilleur {n}", "de": "Beste {n}", "pt": "Melhor {n}", "ru": "Лучший {n}", "it": "Migliore {n}", "ar": "الأفضل {n}", "zh-Hant": "最高 {n}" },
  "回「游戏」页随便开一局 ——\n通关、时长、连胜都会记在这一页": { "ja": "「ゲーム」タブから開く - クリア、時間、連勝はすべてここに記録されます", "ko": "「게임」탭에서 아무 게임이나 시작하세요 —— 클리어, 플레이 시간, 연속 기록이 이 페이지에 기록됩니다", "es": "Abre una partida desde la pestaña Juegos — los avances, el tiempo y las rachas se registran aquí", "fr": "Ouvrez une partie depuis l'onglet Jeux — les réussites, le temps et les séries sont enregistrées ici", "de": "Öffne ein Spiel auf der Spiele-Seite - alle Cleare, Zeit und Serien werden hier erfasst", "pt": "Abra um jogo na aba Jogos — clears, tempo e séries serão registrados aqui", "ru": "Откройте игру на вкладке Игр — все очки, время и серии будут отображаться здесь", "it": "Apri un gioco dalla scheda Giochi - completamenti, tempo e strisce si registrano qui", "ar": "افتح أي لعبة من صفحة الألعاب — ستُسجَّل هنا الإنجازات والوقت والسلاسل", "zh-Hant": "回「遊戲」頁隨便開一局 ——\n通關、時長、連勝都會記在這一頁" },
  "最后更新：2026 年 10 月 10 日": { "ja": "最終更新：2026年10月10日", "ko": "최종 업데이트: 2026년 10월 10일", "es": "Última actualización: 10 de octubre de 2026", "fr": "Dernière mise à jour : 10 octobre 2026", "de": "Zuletzt aktualisiert: 10. Oktober 2026", "pt": "Última atualização: 10 de outubro de 2026", "ru": "Последнее обновление: 10 октября 2026 года", "it": "Ultimo aggiornamento: 10 ottobre 2026", "ar": "آخر تحديث: 10 أكتوبر 2026", "zh-Hant": "最後更新：2026 年 10 月 10 日" },
  "玩法：": { "ja": "遊び方：", "ko": "플레이 방법:", "es": "Cómo jugar:", "fr": "Comment jouer :", "de": "So spielt man:", "pt": "Como jogar:", "ru": "Как играть:", "it": "Come giocare:", "ar": "طريقة اللعب:", "zh-Hant": "玩法：" },
  "碎片时间，来一局": { "ja": "いつでも一局", "ko": "짬날 때 한 판", "es": "Una partida rápida, en cualquier momento", "fr": "Une partie rapide, à tout moment", "de": "Schnelle Runde, jederzeit", "pt": "Uma rodada rápida, a qualquer momento", "ru": "Быстрый раунд в любое время", "it": "Una partita veloce, in qualsiasi momento", "ar": "جولة سريعة في أي وقت", "zh-Hant": "碎片時間，來一局" },
  "⭐ 已收藏": { "ja": "⭐ お気に入り", "ko": "⭐ 저장됨", "es": "⭐ Guardado", "fr": "⭐ Sauvegardé", "de": "⭐ Gespeichert", "pt": "⭐ Salvo", "ru": "⭐ Сохранено", "it": "⭐ Salvato", "ar": "⭐ محفوظة", "zh-Hant": "⭐ 已收藏" },
  "已取消收藏": { "ja": "お気に入り解除", "ko": "저장 취소됨", "es": "Eliminado", "fr": "Supprimé", "de": "Entfernt", "pt": "Removido", "ru": "Удалено", "it": "Rimosso", "ar": "أُزيل الحفظ", "zh-Hant": "已取消收藏" },
  "没有同时满足这些条件的游戏": { "ja": "これらの条件をすべて満たすゲームはありません", "ko": "이 조건을 모두 만족하는 게임이 없습니다", "es": "No hay ningún juego que cumpla todas esas condiciones", "fr": "Aucun jeu ne correspond à tous ces critères", "de": "Kein Spiel passt zu diesen Filtern", "pt": "Nenhum jogo corresponde a todos esses filtros", "ru": "Нет игр, соответствующих всем фильтрам", "it": "Nessun gioco corrisponde a tutti questi filtri", "ar": "لا توجد لعبة تطابق كل هذه الشروط", "zh-Hant": "沒有同時滿足這些條件的遊戲" },
  "还没收藏过游戏": { "ja": "まだお気に入りのゲームはありません", "ko": "아직 저장한 게임이 없습니다", "es": "Aún no has guardado ningún juego", "fr": "Aucun jeu sauvegardé pour l'instant", "de": "Noch keine Spiele gespeichert", "pt": "Ainda não há jogos salvos", "ru": "Еще нет сохраненных игр", "it": "Ancora non hai salvato nessun gioco", "ar": "لا توجد ألعاب محفوظة بعد", "zh-Hant": "還沒收藏過遊戲" },
  "还一局都没玩过": { "ja": "まだ一局もプレイしていません", "ko": "아직 한 판도 플레이하지 않았습니다", "es": "Aún no has jugado ninguna partida", "fr": "Vous n'avez pas encore joué à une partie", "de": "Du hast noch keine Runde gespielt", "pt": "Você ainda não jogou uma rodada", "ru": "Вы еще не играли ни одного раунда", "it": "Non hai ancora giocato una partita", "ar": "لم تلعب أي جولة بعد", "zh-Hant": "還一局都沒玩過" },
  "这一类还没有游戏": { "ja": "このカテゴリにはまだゲームがありません", "ko": "이 분류에는 아직 게임이 없습니다", "es": "Aún no hay juegos en esta categoría", "fr": "Aucun jeu dans cette catégorie pour l'instant", "de": "Noch keine Spiele in dieser Kategorie", "pt": "Ainda não há jogos nesta categoria", "ru": "Еще нет игр в этой категории", "it": "Ancora non ci sono giochi in questa categoria", "ar": "لا توجد ألعاب في هذه الفئة بعد", "zh-Hant": "這一類還沒有遊戲" },
  "少挑几个条件试试？": { "ja": "少しフィルターを減らしてみますか？", "ko": "조건을 줄여 보세요", "es": "¿Intentar con menos filtros?", "fr": "Essayez d'en choisir moins", "de": "Versuche weniger Filter auszuwählen", "pt": "Tente escolher menos filtros?", "ru": "Попробуйте выбрать меньше фильтров?", "it": "Prova a selezionare meno filtri?", "ar": "جرّب اختيار شروط أقل", "zh-Hant": "少挑幾個條件試試？" },
  "进任意一局，点右上角 ⭐ 就收藏了": { "ja": "任意のゲームを開いて、隅の ⭐ をタップすると保存されます", "ko": "아무 게임이나 열고 오른쪽 위 ⭐를 누르면 저장됩니다", "es": "Abre cualquier partida y toca ⭐ en la esquina para guardarla", "fr": "Ouvrez n'importe quelle partie et appuyez sur ⭐ dans le coin pour la sauvegarder", "de": "Öffne jedes Spiel und tippe auf ⭐ in der Ecke, um es zu speichern", "pt": "Abra qualquer jogo e toque em ⭐ no canto para salvá-lo", "ru": "Откройте любую игру и нажмите ⭐ в углу, чтобы сохранить ее", "it": "Apri qualsiasi gioco e tocca ⭐ nell'angolo per salvarlo", "ar": "افتح أي لعبة واضغط ⭐ في الأعلى للحفظ", "zh-Hant": "進任意一局，點右上角 ⭐ 就收藏了" },
  "随便挑一局，这里就记上了": { "ja": "任意のラウンドをプレイすると、ここに表示されます", "ko": "아무 게임이나 한 판 하면 여기에 기록됩니다", "es": "Juega cualquier partida y aparecerá aquí", "fr": "Jouez à n'importe quelle partie et elle s'affiche ici", "de": "Spiel einfach eine Runde und sie erscheint hier", "pt": "Jogue qualquer rodada e ela aparecerá aqui", "ru": "Играйте в любой раунд, и он отобразится здесь", "it": "Gioca a qualsiasi round e apparirà qui", "ar": "العب أي جولة وستظهر هنا", "zh-Hant": "隨便挑一局，這裡就記上了" },
  "换个分类看看": { "ja": "別のカテゴリを試してみる", "ko": "다른 분류를 보세요", "es": "Intenta con otra categoría", "fr": "Essayez une autre catégorie", "de": "Versuche eine andere Kategorie", "pt": "Experimente outra categoria", "ru": "Попробуйте другую категорию", "it": "Prova un'altra categoria", "ar": "جرّب فئة أخرى", "zh-Hant": "換個分類看看" },
  "看全部 {n} 个": { "ja": "すべて見る {n}件", "ko": "전체 {n}개 보기", "es": "Ver los {n}", "fr": "Voir les {n}", "de": "Alle {n} ansehen", "pt": "Ver todos os {n}", "ru": "Показать все {n}", "it": "Vedi tutti i {n}", "ar": "عرض الكل {n}", "zh-Hant": "看全部 {n} 個" },
  "通关 {n} 局": {"ja": "{n}局クリア", "ko": "{n}판 클리어", "es": "{n} partidas superadas", "fr": "{n} parties reussies", "de": "{n} Runden geschafft", "pt": "{n} partidas concluidas", "ru": "Пройдено игр: {n}", "it": "{n} partite completate", "ar": "{n} جولة مكتملة", "zh-Hant": "通關 {n} 局"},
  /** ★★★ 2026-10-16 指南页分类要点：18 条 × 10 语言（奥森铁令：不许英文兜底，每种语言都真译） */
  "点/滑操作，规则简单，玩起来就懂": { "ja": "タップ／スワイプだけ。ルールはシンプルで、始めればすぐ分かります", "ko": "탭하거나 스와이프만 하면 됩니다. 규칙이 단순해서 시작하면 바로 이해됩니다", "fr": "Touchez ou faites glisser. Règles simples, on comprend en jouant.", "de": "Tippen oder wischen. Einfache Regeln, sofort verständlich.", "es": "Toca o desliza. Reglas sencillas, se entienden al jugar.", "ru": "Только касания и свайпы. Правила простые — разберётесь с первых секунд.", "ar": "اضغط أو اسحب. القواعد بسيطة وتتضح بمجرد أن تبدأ اللعب.", "pt": "Toque ou deslize. Regras simples, entende-se logo ao jogar.", "it": "Tocca o scorri. Regole semplici, si capiscono giocando.", "zh-Hant": "點/滑操作，規則簡單，玩起來就懂" },
  "有明确胜负判定；通关才有经验": { "zh-Hant": "有明確勝負判定，只有通關才給經驗", "ja": "勝ち負けははっきり決まります。経験値はクリアしたときだけ", "ko": "승패가 분명하게 갈립니다. 경험치는 클리어했을 때만", "es": "Victoria o derrota están claras: solo ganas experiencia al superarlo.", "fr": "Victoire ou défaite, c'est clair : l'XP ne s'obtient qu'en gagnant.", "de": "Sieg oder Niederlage stehen klar fest – XP gibt es nur beim Sieg.", "pt": "Vitória ou derrota são claras: você ganha XP só ao vencer.", "ru": "Исход ясен: опыт даётся только за победу.", "it": "Vittoria o sconfitta sono chiare: guadagni XP solo se vinci.", "ar": "الفوز والخسارة واضحان، وتحصل على نقاط الخبرة عند الفوز فقط." },
  "右上角 ↻ 可以随时重开这一局": { "ja": "右上の ↻ でいつでもやり直せます", "ko": "오른쪽 위 ↻를 누르면 언제든 다시 시작할 수 있습니다", "fr": "L'icône ↻ en haut à droite relance la partie à tout moment.", "de": "Das ↻ oben rechts startet die Runde jederzeit neu.", "es": "El ↻ de arriba a la derecha reinicia la partida cuando quieras.", "ru": "Значок ↻ в правом верхнем углу перезапускает раунд в любой момент.", "ar": "أيقونة ↻ في أعلى اليمين تعيد الجولة في أي وقت.", "pt": "O ↻ no canto superior direito reinicia a partida a qualquer momento.", "it": "L'icona ↻ in alto a destra ricomincia la partita quando vuoi.", "zh-Hant": "右上角 ↻ 可以隨時重開這一局" },
  "点格子填/涂，满足题目给出的数字条件": { "ja": "マスをタップして数字の条件を満たすように埋めていきます", "ko": "칸을 눌러 숫자 조건을 만족하도록 채우거나 칠합니다", "fr": "Touchez les cases pour remplir ou noircir jusqu'à respecter les indices chiffrés.", "de": "Tippe Zellen an, um sie zu füllen oder zu schwärzen, bis die Zahlenvorgaben stimmen.", "es": "Toca las casillas para rellenarlas o sombrearlas hasta cumplir las pistas numéricas.", "ru": "Нажимайте на клетки, заполняя их или закрашивая, пока не соблюдены числовые условия.", "ar": "اضغط الخلايا لتعبئتها أو تظليلها حتى تحقق الشروط الرقمية المطلوبة.", "pt": "Toque nas células para preencher ou sombrear até cumprir as pistas numéricas.", "it": "Tocca le caselle per riempirle o annerirle fino a rispettare gli indizi numerici.", "zh-Hant": "點格子填/塗，滿足題目給出的數字條件" },
  "「违规」计数表示当前有几处违反规则，归零即通关": { "ja": "「違反」の数は今いくつルールを破っているかを示します。0になればクリアです", "ko": "「위반」 숫자는 현재 규칙을 어긴 곳이 몇 군데인지 보여줍니다. 0이 되면 클리어입니다", "fr": "Le compteur « infractions » indique combien de règles sont enfreintes. À zéro, c'est gagné.", "de": "Der Zähler „Verstöße“ zeigt, wie viele Regeln gerade gebrochen werden. Bei null ist die Runde gewonnen.", "es": "El contador de «infracciones» indica cuántas reglas se incumplen. Al llegar a cero, ganas.", "ru": "Счётчик «нарушения» показывает, сколько правил нарушено. Обнулите его — и уровень пройден.", "ar": "عدّاد «المخالفات» يبيّن عدد القواعد المخالفة حاليًا. عندما يصل إلى صفر تفوز بالمرحلة.", "pt": "O contador de «infrações» mostra quantas regras estão sendo violadas. Ao zerar, você vence.", "it": "Il contatore delle «violazioni» indica quante regole sono infrante. A zero, hai vinto.", "zh-Hant": "「違規」計數表示當前有幾處違反規則，歸零即通關" },
  "卡住了可以点「换一题」换一个新局面": { "ja": "行き詰まったら「問題を変える」で新しい盤面に変えられます", "ko": "막히면 「문제 바꾸기」를 눌러 새 판으로 바꿀 수 있습니다", "fr": "Bloqué ? Touchez « Nouveau puzzle » pour repartir sur une nouvelle grille.", "de": "Festgefahren? Tippe auf „Neues Rätsel“ für ein frisches Spielfeld.", "es": "¿Atascado? Toca «Nuevo puzzle» para empezar con un tablero nuevo.", "ru": "Застряли? Нажмите «Другая задача» — и получите новую позицию.", "ar": "إذا توقفت عن الحل فاضغط «سؤال آخر» للحصول على لوحة جديدة.", "pt": "Travou? Toque em «Novo desafio» para começar com um tabuleiro novo.", "it": "Bloccato? Tocca «Nuovo puzzle» per avere una griglia nuova.", "zh-Hant": "卡住了可以點「換一題」換一個新局面" },
  "算就完了 —— 结果对就得分，错会扣时间": { "ja": "とにかく計算するだけ。正解なら得点、間違えると時間が減ります", "ko": "그냥 계산하면 됩니다. 맞히면 점수를 얻고 틀리면 시간이 줄어듭니다", "fr": "Calculez, c'est tout : bonne réponse, des points ; erreur, du temps en moins.", "de": "Einfach rechnen: richtige Ergebnisse bringen Punkte, Fehler kosten Zeit.", "es": "Solo hay que calcular: si aciertas, sumas puntos; si fallas, pierdes tiempo.", "ru": "Просто считайте: верный ответ приносит очки, ошибка отнимает время.", "ar": "كل ما عليك هو الحساب: الإجابة الصحيحة تمنحك نقاطًا والخاطئة تخصم من وقتك.", "pt": "É só calcular: acerto rende pontos, erro custa tempo.", "it": "Basta calcolare: la risposta giusta dà punti, l'errore costa tempo.", "zh-Hant": "算就完了 —— 結果對就得分，錯會扣時間" },
  "多数款有倒计时或步数限制，快比慢强": { "ja": "ほとんどのゲームに制限時間か手数制限があります。ゆっくりより速くが有利です", "ko": "대부분의 게임에 제한 시간이나 횟수 제한이 있습니다. 느린 것보다 빠른 게 유리합니다", "fr": "La plupart ont un compte à rebours ou une limite de coups : la rapidité paie.", "de": "Die meisten haben einen Countdown oder ein Zuglimit. Schnell schlägt langsam.", "es": "La mayoría tiene cuenta atrás o límite de movimientos: la rapidez manda.", "ru": "В большинстве игр есть отсчёт времени или лимит ходов — быстро лучше, чем медленно.", "ar": "معظم الألعاب فيها عدّ تنازلي أو حدّ للحركات، فالسرعة أفضل من التمهّل.", "pt": "A maioria tem contagem regressiva ou limite de jogadas: ser rápido compensa.", "it": "Quasi tutti hanno un conto alla rovescia o un limite di mosse: la velocità paga.", "zh-Hant": "多數款有倒計時或步數限制，快比慢強" },
  "心算不稳的话，先在纸上列一下也行": { "ja": "暗算が不安なら、先に紙に書き出してもかまいません", "ko": "암산이 불안하면 종이에 먼저 적어도 됩니다", "fr": "Pas sûr de tête ? Posez d'abord le calcul sur papier, c'est permis.", "de": "Kopfrechnen unsicher? Dann rechne es ruhig erst auf Papier.", "es": "¿No te fías del cálculo mental? Puedes apuntarlo antes en papel.", "ru": "Не уверены в устном счёте? Ничего страшного — сначала запишите на бумаге.", "ar": "إذا لم تكن واثقًا من الحساب الذهني، فلا بأس أن تكتبه على ورقة أولًا.", "pt": "Não confia no cálculo mental? Pode anotar no papel primeiro.", "it": "Non sei sicuro a mente? Puoi prima scriverlo sulla carta.", "zh-Hant": "心算不穩的話，先在紙上列一下也行" },
  "先「看」后「答」：记住闪现的内容，再按提示回忆": { "ja": "まず「見る」、次に「答える」。一瞬だけ表示される内容を覚えて、あとで思い出します", "ko": "먼저 「보고」 그다음 「답합니다」. 잠깐 나타난 내용을 기억하고 안내에 따라 떠올리세요", "fr": "D'abord « regarder », ensuite « répondre » : mémorisez ce qui apparaît, puis rappelez-vous.", "de": "Erst „schauen“, dann „antworten“: merken Sie sich das Aufblitzende und rufen Sie es ab.", "es": "Primero «mirar» y luego «responder»: memoriza lo que aparece y recuérdalo después.", "ru": "Сначала «смотрите», потом «отвечайте»: запомните мелькнувшее и вспомните его.", "ar": "«انظر» أولًا ثم «أجب»: احفظ ما يظهر سريعًا ثم استرجعه حسب التلميح.", "pt": "Primeiro «ver», depois «responder»: memorize o que aparece e depois recorde.", "it": "Prima «guarda», poi «rispondi»: memorizza ciò che appare e poi ricordalo.", "zh-Hant": "先「看」後「答」：記住閃現的內容，再按提示回憶" },
  "答对连续越多，得分越高": { "ja": "連続で正解するほど、得点が高くなります", "ko": "연속으로 맞힐수록 점수가 높아집니다", "fr": "Plus votre série de bonnes réponses est longue, plus le score grimpe.", "de": "Je länger die Serie richtiger Antworten, desto höher der Punktestand.", "es": "Cuanto más larga sea tu racha de aciertos, mayor será la puntuación.", "ru": "Чем длиннее серия верных ответов, тем выше счёт.", "ar": "كلما زادت إجاباتك الصحيحة المتتالية ارتفعت نقاطك.", "pt": "Quanto maior for a sua sequência de acertos, maior será a pontuação.", "it": "Più lunga è la serie di risposte giuste, più alto è il punteggio.", "zh-Hant": "答對連續越多，得分越高" },
  "错了不要紧，重开一局成本很低": { "ja": "間違えても大丈夫。やり直しの負担はほとんどありません", "ko": "틀려도 괜찮습니다. 다시 시작하는 부담은 거의 없습니다", "fr": "Se tromper n'est pas grave : relancer une partie coûte très peu.", "de": "Ein Fehler ist kein Problem – eine neue Runde kostet kaum etwas.", "es": "Equivocarse no es grave: reiniciar una partida cuesta muy poco.", "ru": "Ошибиться не страшно: начать раунд заново почти ничего не стоит.", "ar": "لا مشكلة إن أخطأت، فبدء جولة جديدة لا يكلّفك شيئًا يُذكر.", "pt": "Errar não é problema: recomeçar uma partida custa muito pouco.", "it": "Sbagliare non è un problema: ricominciare una partita costa pochissimo.", "zh-Hant": "錯了不要緊，重開一局成本很低" },
  "拼词/找词/猜词，考验词汇量与语感": { "ja": "文字を並べたり探したり推測したり。語彙力と言葉の感覚が試されます", "ko": "글자를 맞추고 찾고 추리합니다. 어휘력과 언어 감각이 필요한 장르입니다", "fr": "Assembler, trouver, devinez des mots : vocabulaire et feeling linguistique au programme.", "de": "Wörter bilden, finden, erraten – hier zählen Wortschatz und Sprachgefühl.", "es": "Formar, buscar y adivinar palabras: se ponen a prueba el vocabulario y el oído.", "ru": "Составляйте, ищите и угадывайте слова — проверка словарного запаса и языкового чутья.", "ar": "تركيب الكلمات والبحث عنها وتخمينها، وهذا يختبر حصيلتك اللغوية وحسّك بالكلمات.", "pt": "Montar, achar e adivinhar palavras: testa vocabulário e sensibilidade linguística.", "it": "Comporre, trovare e indovinare parole: mette alla prova lessico e orecchio linguistico.", "zh-Hant": "拼詞/找詞/猜詞，考驗詞彙量與語感" },
  "多数款支持逐字母输入，输错可退格": { "ja": "ほとんどのゲームは一文字ずつ入力でき、打ち間違えても消せます", "ko": "대부분 한 글자씩 입력할 수 있고 잘못 입력하면 지울 수 있습니다", "fr": "La plupart acceptent la saisie lettre par lettre, avec retour arrière possible.", "de": "Bei den meisten tippst du Buchstabe für Buchstabe und kannst löschen.", "es": "La mayoría admite escribir letra a letra y puedes borrar si te equivocas.", "ru": "В большинстве игр буквы вводятся по одной, а ошибку можно стереть.", "ar": "معظم الألعاب تتيح الإدخال حرفًا بحرف، ويمكنك الحذف عند الخطأ.", "pt": "A maioria aceita digitar letra a letra, e dá para apagar se errar.", "it": "Nella maggior parte puoi digitare lettera per lettera e correggere con backspace.", "zh-Hant": "多數款支持逐字母輸入，輸錯可退格" },
  "不会的可以跳过，不影响其他题": { "ja": "分からない問題は飛ばせます。ほかの問題には影響しません", "ko": "모르는 문제는 건너뛸 수 있고 다른 문제에 영향이 없습니다", "fr": "Passez ce que vous ignorez : cela n'affecte pas les autres questions.", "de": "Unbekanntes einfach überspringen – die anderen Aufgaben bleiben davon unberührt.", "es": "Puedes saltar lo que no sepas: no afecta a las demás preguntas.", "ru": "Не знаете — можно пропустить без ущерба для остальных заданий.", "ar": "يمكنك تخطي ما لا تعرفه دون أن يؤثر ذلك على بقية الأسئلة.", "pt": "Pode pular o que não souber: isso não afeta as outras questões.", "it": "Puoi saltare ciò che non sai: non influisce sulle altre domande.", "zh-Hant": "不會的可以跳過，不影響其他題" },
  "观察图形/空间关系，找出规律或路径": { "ja": "図形や位置関係をよく見て、規則性や進む道を見つけます", "ko": "도형과 공간 관계를 관찰해 규칙이나 경로를 찾아냅니다", "fr": "Observez les formes et l'espace, puis trouvez la logique ou le chemin.", "de": "Formen und räumliche Beziehungen beobachten und Muster oder Weg finden.", "es": "Observa las figuras y el espacio, y halla el patrón o el camino.", "ru": "Наблюдайте за фигурами и их расположением — найдите закономерность или путь.", "ar": "راقب الأشكال والعلاقات المكانية لاكتشاف النمط أو المسار.", "pt": "Observe as formas e o espaço, e descubra o padrão ou o caminho.", "it": "Osserva le figure e lo spazio, poi trova lo schema o il percorso.", "zh-Hant": "觀察圖形/空間關係，找出規律或路徑" },
  "方向键或点选操作，走到目标即通关": { "ja": "方向キーかタップで操作し、目標にたどり着けばクリアです", "ko": "방향키나 탭으로 움직여 목표에 도달하면 클리어입니다", "fr": "Flèches ou toucher : atteignez l'objectif pour gagner.", "de": "Steuerung per Pfeiltasten oder Tippen – Ziel erreichen und gewonnen.", "es": "Con las flechas o toques: llega al objetivo y ganas.", "ru": "Управление стрелками или касанием: дойдите до цели — и уровень пройден.", "ar": "استخدم أسهم الاتجاه أو اللمس، وما إن تصل إلى الهدف حتى تفوز.", "pt": "Com as setas ou toques: chegue ao objetivo e você vence.", "it": "Con le frecce o toccando: raggiungi l'obiettivo e vinci.", "zh-Hant": "方向鍵或點選操作，走到目標即通關" },
  "步数越少得分越高": { "ja": "手数が少ないほど高得点になります", "ko": "이동 횟수가 적을수록 점수가 높아집니다", "fr": "Moins de coups, plus de points.", "de": "Je weniger Züge, desto höher die Punktzahl.", "es": "Cuantos menos movimientos, mayor puntuación.", "ru": "Чем меньше ходов, тем выше счёт.", "ar": "كلما قلّت الحركات ارتفعت نقاطك.", "pt": "Quanto menos jogadas, maior a pontuação.", "it": "Meno mosse fai, più alto è il punteggio.", "zh-Hant": "步數越少得分越高" },
  /** ★★★ 2026-10-16 成就 4 档档位名 × 10 语言（奥森铁令：不许英文兜底，每种语言都真译）
   *  ★ 无 en 列：英文由调用方的 en 参数给（ProgressStore.TIER_NAME[i][1]）
   *  ★ 繁体列键名必须是 "zh-Hant"（L() 用 row[cur] 直接取，cur = "zh-Hant"） */
  "返回": { "ja": "戻る", "ko": "뒤로", "es": "Volver", "fr": "Retour", "de": "Zurück", "pt": "Voltar", "ru": "Назад", "it": "Indietro", "ar": "رجوع", "zh-Hant": "返回" },
  "重新开始": { "ja": "やり直す", "ko": "다시 시작", "es": "Reiniciar", "fr": "Recommencer", "de": "Neu starten", "pt": "Reiniciar", "ru": "Заново", "it": "Ricomincia", "ar": "إعادة", "zh-Hant": "重新開始" },
  "玩法说明": { "ja": "遊び方", "ko": "게임 방법", "es": "Cómo jugar", "fr": "Comment jouer", "de": "Spielanleitung", "pt": "Como jogar", "ru": "Как играть", "it": "Come giocare", "ar": "طريقة اللعب", "zh-Hant": "玩法說明" },
  "删除": { "ja": "削除", "ko": "삭제", "es": "Borrar", "fr": "Supprimer", "de": "Löschen", "pt": "Apagar", "ru": "Удалить", "it": "Elimina", "ar": "حذف", "zh-Hant": "刪除" },
  "首通": { "ja": "初クリア", "ko": "첫 클리어", "fr": "Première", "de": "Erster Sieg", "es": "Primer pase", "ru": "Первый", "ar": "أول فوز", "pt": "Primeira", "it": "Prima", "zh-Hant": "首通" },
  "熟练": { "ja": "熟練", "ko": "숙련", "fr": "Habitué", "de": "Geübt", "es": "Hábil", "ru": "Опытный", "ar": "ماهر", "pt": "Hábil", "it": "Abile", "zh-Hant": "熟練" },
  "精通": { "ja": "達人", "ko": "달인", "fr": "Virtuose", "de": "Experte", "es": "Experto", "ru": "Знаток", "ar": "خبير", "pt": "Especialista", "it": "Esperto", "zh-Hant": "精通" },
  "大师": { "ja": "マスター", "ko": "마스터", "fr": "Maître", "de": "Meister", "es": "Maestro", "ru": "Мастер", "ar": "أستاذ", "pt": "Mestre", "it": "Maestro", "zh-Hant": "大師" },

  /** ★★ 2026-10-23 路线 E：游玩记录导出（11 语言） */
  "导出游玩记录": {
    "en": "Export play log",
    "zh-Hant": "匯出遊玩記錄",
    "ja": "プレイ記録を書き出す",
    "ko": "플레이 기록 내보내기",
    "fr": "Exporter le journal de jeu",
    "de": "Spielverlauf exportieren",
    "es": "Exportar el registro de partidas",
    "ru": "Экспорт журнала игры",
    "ar": "تصدير سجل اللعب",
    "pt": "Exportar o registro de partidas",
    "it": "Esporta il registro di gioco",
  },
  /** ★★ 2026-10-23 路线 E：游玩记录导出（11 语言） */
  "把每局的用时与结果导出成 JSON，只存在本机": {
    "en": "Export each game time and result as JSON, stored on this device only",
    "zh-Hant": "將每局的用時與結果匯出成 JSON，只存在本機",
    "ja": "各プレイの所要時間と結果を JSON に書き出します。端末内にのみ保存",
    "ko": "각 판의 소요 시간과 결과를 JSON으로 내보냅니다. 이 기기에만 저장",
    "fr": "Exporter la duree et le resultat de chaque partie en JSON, uniquement sur cet appareil",
    "de": "Zeit und Ergebnis jeder Partie als JSON exportieren, nur auf diesem Geraet",
    "es": "Exporta el tiempo y el resultado de cada partida en JSON, solo en este dispositivo",
    "ru": "Экспорт времени и результата каждой партии в JSON, только на этом устройстве",
    "ar": "تصدير وقت كل جولة ونتيجتها بصيغة JSON، على هذا الجهاز فقط",
    "pt": "Exportar o tempo e o resultado de cada partida em JSON, apenas neste dispositivo",
    "it": "Esporta il tempo e il risultato di ogni partita in JSON, solo su questo dispositivo",
  },
  /** ★★ 2026-10-23 路线 E：游玩记录导出（11 语言） */
  "还没有游玩记录 —— 先玩几局再来导出": {
    "en": "No play records yet — play a few games first",
    "zh-Hant": "還沒有遊玩記錄 —— 先玩幾局再來匯出",
    "ja": "プレイ記録がまだありません —— 何局か遊んでから書き出してください",
    "ko": "아직 플레이 기록이 없습니다 —— 몇 판 먼저 해 보세요",
    "fr": "Aucun historique de jeu — jouez d abord quelques parties",
    "de": "Noch kein Spielverlauf — spielen Sie zuerst ein paar Partien",
    "es": "Aun no hay registros de partidas — juega algunas partidas primero",
    "ru": "Записей пока нет — сначала сыграйте несколько партий",
    "ar": "لا توجد سجلات لعب بعد — العب بضع جولات أولاً",
    "pt": "Ainda nao ha registros de partidas — jogue algumas partidas primeiro",
    "it": "Nessun registro di gioco — gioca prima qualche partita",
  },
  /** ★★ 2026-10-23 路线 E：游玩记录导出（11 语言） */
  "导出失败 —— 请再试一次": {
    "en": "Export failed — please try again",
    "zh-Hant": "匯出失敗 —— 請再試一次",
    "ja": "書き出しに失敗しました —— もう一度お試しください",
    "ko": "내보내기 실패 —— 다시 시도해 주세요",
    "fr": "Echec de l export — veuillez reessayer",
    "de": "Export fehlgeschlagen — bitte erneut versuchen",
    "es": "Error al exportar — intentalo de nuevo",
    "ru": "Ошибка экспорта — попробуйте ещё раз",
    "ar": "فشل التصدير — يرجى المحاولة مرة أخرى",
    "pt": "Falha na exportacao — tente novamente",
    "it": "Esportazione non riuscita — riprova",
  },
  /** ★★ 2026-10-23 路线 E：游玩记录导出（11 语言） */
  "游玩记录已导出，文件在手机上": {
    "en": "Play log exported and saved on this device",
    "zh-Hant": "遊玩記錄已匯出，檔案在手機上",
    "ja": "プレイ記録を書き出しました。ファイルは端末内にあります",
    "ko": "플레이 기록을 내보냈습니다. 파일은 이 기기에 있습니다",
    "fr": "Historique exporte, fichier enregistre sur cet appareil",
    "de": "Spielverlauf exportiert, Datei auf diesem Geraet gespeichert",
    "es": "Registro de partidas exportado, archivo guardado en este dispositivo",
    "ru": "Журнал игры экспортирован, файл сохранён на устройстве",
    "ar": "تم تصدير سجل اللعب وحفظ الملف على هذا الجهاز",
    "pt": "Registro de partidas exportado, arquivo salvo neste dispositivo",
    "it": "Registro di gioco esportato, file salvato su questo dispositivo",
  },

  /** ★★ 2026-10-23 路线 F：自动难度档（三档都有，这档之前没有） */
  "自动": {
    "en": "Auto",
    "zh-Hant": "自動",
    "ja": "自動",
    "ko": "자동",
    "fr": "Auto",
    "de": "Auto",
    "es": "Auto",
    "ru": "Авто",
    "ar": "تلقائي",
    "pt": "Auto",
    "it": "Auto",
  },
};

/**
 * 整句模板：把 {n} 换成数字
 *
 * ★ 为什么需要它：中文的「3 局」在别的语言里语序不同
 *   （英文 "3 games"、日语 "3局"、阿拉伯语要反过来）——
 *   **不能把「 局」当片段翻**，必须把**整句**当一个键。
 *   用法：TN('{n} 局', '{n} games', n)
 */
/**
 * ★★★ 2026-10-14 新增【语言小特色】—— 奥森：「部分游戏可以因着语言的不同而有一些小特色」
 *
 * 第一件：**阿拉伯语用阿拉伯-印度数字**（٠١٢٣٤٥٦٧٨٩）
 *   阿拉伯世界日常书写用这两套数字；只用 0-9 会显得"没本地化"。
 *   实测：埃及/沙特等地手机系统在 ar 区域下确实显示 ٠-٩。
 *
 * 用法：
 *   Num(12)        → 阿拉伯语下 "١٢"，其他语言 "12"
 *   Digits('3/8')  → 只把其中的数字换掉，其余字符（斜杠、冒号、百分号）不动
 *
 * ⚠️ 不影响任何计算 —— 只在【显示】时替换（游戏内部仍用 number 运算）
 */
const AR_DIGITS: string[] = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/**
 * ★★★ 2026-10-14 语言特色【第 2 件】—— 日语用汉字数字
 *   奥森：「部分游戏可以因着语言的不同而有一些小特色」
 *   日语里 〇一二三四五六七八九 是正式书写形式（尤其年号、传统场合）
 *   ⇒ 数字类界面在日语下显示汉字数字，一眼就有"这是日语版"的味道
 *   ⚠️ 只用于【显示】；不用于需要一眼读数的紧凑处（如倒计时秒数）—— 由调用方决定
 */
const JA_DIGITS: string[] = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/**
 * 把字符串里的 0-9 换成当前语言习惯的数字（阿拉伯语 / 日语）
 *
 * ★★★ 2026-10-15 关键修正（实测发现）：
 *   原来只读 `I18n.current()`（静态缓存）⇒ **ArkUI 的依赖追踪看不到它**
 *   ⇒ 切语言后这些数字【不重算】，实测阿拉伯语下"355"和"LV 1"仍是 0-9。
 *   ⇒ 修法：加可选参数 `lang` —— 调用方传 `this.langCode`（@StorageProp）
 *      ⇒ 建立观察依赖 ⇒ 语言一变就重算 ✓
 *   ⇒ 用法：`Digits(String(this.level), this.langCode)`
 */
export function Digits(s: string, lang?: string): string {
  const cur: string = lang !== undefined && lang.length > 0 ? lang : I18n.current();
  let table: string[] | undefined = undefined;
  if (cur === Lang.AR) {
    table = AR_DIGITS;
  } else if (cur === Lang.JA) {
    // ★★★ 2026-10-16 实拍日语统计页抓到 BUG #30（★ 范围问题，不是"要不要"的问题）：
    //   奥森原意 = 「日语下有点小特色，一眼看出是日语版」（2026-10-14 第 2 件特色）
    //   ★ 但原实现把【所有】数字都转汉字数词 ⇒ 实拍日语统计页出现：
    //     「すべて見る 五三件」（应是 53件）｜「一〇局プレイ」（应是 10局プレイ）
    //     ｜「〇 / 五三」（应是 0 / 53）｜「一〇〇EXP」（应是 100EXP）
    //   ⇒ ★ 日语母语者看着别扭：现代日语界面【用阿拉伯数字】，汉字数词只用于
    //     竖排/年号/传统场合；多位数字尤其不能用汉字数词
    //   ⇒ 修法：★ 保留"小特色"，但只对【单个数字字符】生效
    //     （「〇%」「一」有日语味道；「53」「100」「1000」保持阿拉伯数字可读）
    if (s.length === 1) {
      table = JA_DIGITS;
    }
  }
  if (table === undefined) {
    return s;
  }
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const c: string = s.charAt(i);
    const d: number = c.charCodeAt(0) - 48;
    out += (d >= 0 && d <= 9) ? table[d] : c;
  }
  return out;
}

/** 数字 → 当前语言习惯的写法 */
export function Num(n: number): string {
  return Digits(String(n));
}

/**
 * ★★★ 2026-10-16 复数类别（语言特色第 9 件）
 *   起因：TN() 原来只替换 {n}，不做复数变化 ⇒ 俄语玩家看到「5 игра」（应为 5 игр）
 *   返回：0=单数 ｜ 1=少数 ｜ 2=多数 ｜ 3=无复数（中/日/韩，用原文即可）
 *   规则依 CLDR：俄语三形式；阿拉伯语用其简化三形式；其余欧洲语言单/多两形式。
 */
export function pluralIdx(n: number): number {
  const c: string = I18n.current();
  if (c === Lang.ZH || c === Lang.ZHTW || c === Lang.JA || c === Lang.KO) {
    return 3;   // 无复数变化
  }
  const a: number = n < 0 ? -n : n;
  if (c === Lang.RU) {
    const m10: number = a % 10;
    const m100: number = a % 100;
    if (m10 === 1 && m100 !== 11) { return 0; }
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) { return 1; }
    return 2;
  }
  if (c === Lang.AR) {
    if (a === 1) { return 0; }
    if (a === 2) { return 1; }
    if (a >= 3 && a <= 10) { return 1; }
    return 2;
  }
  return a === 1 ? 0 : 2;   // 英/法/德/西/葡/意：单数 or 复数
}

/**
 * 带复数的模板（TN 的扩展版）
 * @param f1 单数形式（俄语 1、阿语 1）
 * @param f2 少数形式（俄语 2-4、阿语 2-10）
 * @param f5 多数形式（俄语 0/5+、阿语 11+）
 * ★ 不传 f1/f2/f5 ⇒ 退回原 TN 行为（只替换 {n}），所以旧调用点完全不受影响
 */
export function TN(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
  let s: string = L(zh, en);
  // ★★★ 2026-10-16 实拍法语抓到 BUG：f1/f2/f5 是【俄语三形式】，
  //   原来只要传了就对所有语言生效 ⇒ ★ 法语 n=0 时返回「{n} игр」= 俄语泄漏到法语界面！
  //   ⇒ 修：★ 只有【俄语】才用这三个参数；其它语言一律用字典给的本语言文案（s）。
  //   ★ 判据：法语实拍出现「0 дне́й」「355 игр」，其余文案全是正确法语。
  if (I18n.current() === Lang.RU && f1 !== undefined && f2 !== undefined && f5 !== undefined) {
    const k: number = pluralIdx(n);
    s = k === 0 ? f1 : (k === 1 ? f2 : f5);
  }
  // ★★★ 2026-10-16 实拍阿语统计页抓到 BUG #25：tn() 把 {n} 直接换成 String(n)
  //   ⇒ ★ 阿语下「جولة مكتملة 0」「玩过 0 次」全是【西文数字】，
  //     而同页 LV 的「١」是阿语 ⇒ ★ 一页两种数字
  //   ⇒ 修：数字先过 Digits（★ 一处改，所有 tn() 调用点全受益）
  const num: string = Digits(String(n), I18n.current());
  return s.indexOf('{n}') >= 0 ? s.replace('{n}', num) : (num + s);
}

/**
 * 取当前语言的文案
 *
 * ★ 2026-10-13 修：旧版第一行是 `if (cur === ZH || cur === ZHTW) return zh;`
 *   ⇒ **繁体（zh-Hant）直接被当成简体返回**，字典里那 281 条 zh-Hant 永无出头之日，
 *     这就是奥森报的「繁體中文切換無效」。现在分三档：简体走原文、繁体先查字典再转换、
 *     其它语言查字典、缺项退英文。
 */
export function L(zh: string, en: string): string {
  const cur: string = I18n.current();
  // ★★★ 2026-10-16 实拍阿语统计页抓到 BUG #25（第三处）：
  //   成就说明「玩满 10 局」这类【文案自带数字】的，Digits 包不进调用点（是静态字符串）
  //   ⇒ ★ 在 L() 出口统一做数字本地化
  //   ★ L() 只服务【界面文案】（EXTRA 字典），不碰 games/ 的谜题内容 ⇒ 安全
  if (cur === Lang.ZH) {
    return Digits(zh, cur);
  }
  if (cur === Lang.EN) {
    return Digits(en, cur);
  }
  const row: Record<string, string> | undefined = EXTRA[zh];
  if (row !== undefined) {
    const hit: string = row[cur];
    if (hit !== undefined && hit.length > 0) {
      return Digits(hit, cur);
    }
  }
  if (cur === Lang.ZHTW) {
    return Digits(toTrad(zh), cur);   // ★ 繁体缺项：转换，**不退英文、更不退简体**
  }
  return Digits(en, cur);   // 其它语言缺翻译退英文
}

/** 带数字的文案：L2('再攒 {n} 点经验就升级', '{n} XP to next level', n) */
export function L2(zh: string, en: string, n: number): string {
  return L(zh, en).replace('{n}', String(n));
}


/**
 * 语言落盘不再用 PersistentStorage —— 见 `I18n.initPersist()` 里的模拟器实测结论。
 * 现在：`ProgressStore.init()`（UI 起来之前）恢复；设置页/顶栏切换时调 `ProgressStore.saveLang()`。
 */
