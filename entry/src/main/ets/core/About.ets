/**
 * 「关于」—— 反馈邮箱 + 制作者信息
 *
 * 奥森 2026-10-13 09:5x：「游戏里可以放"反馈邮箱"什么的，以及制作者（我）的一些合适的信息」
 *
 * ⚠️ 邮箱待定（我提了顾虑：他用的是**含学号**的学校邮箱，上架给大众会暴露学号 + 毕业后会回收）
 *   ⇒ 换邮箱**只改这一个常量**，别处不用动。
 *
 * 设计原则（我定的，理由写在下面）：
 *   ① **只放必要信息**：一个联系方式 + 一个署名。不放真名/学号/住址/生日 —— 全国可下载
 *   ② **邮箱不直接可点**（有些平台会把裸邮箱当地址抓）⇒ 展示给用户，复制走 `copyToPasteboard`
 *   ③ 署名用**英文名**（与 Kaggle/AtCoder 一致），中文名只在中文界面出现
 */
export class About {
  /**
   * ★ 2026-10-13 10:3x **奥森定案：「就用这个」**
   *   ⇒ 反馈邮箱 = `andrew680701@outlook.com`（他自己选的、无其他用途的专用邮箱）
   *
   *   过程留档（我提过顾虑、他知情后拍板）：
   *     · 学校邮箱 ✗ 含学号 + 毕业后会回收 ⇒ 反馈渠道断
   *     · QQ 邮箱   ⚠️ QQ 号可搜到社交关联
   *     · **Outlook** ✅ 与身份解耦 + 专用 + 长期可用（`andrew` 与英文名 Andrew Oscar 呼应）
   *   我另外提过一句：`680701` 与学号后 6 位 `610701` 有 5 位相同
   *     ⇒ 建议过 Outlook 别名（`onemore@outlook.com`，同邮箱、不含数字）
   *   **他明确说「就用这个」⇒ 就这么定，不再改、不再提。**
   */
  static readonly FEEDBACK_EMAIL: string = 'andrew680701@outlook.com';

  /** 署名（英文界面） */
  static readonly AUTHOR_EN: string = 'Andrew Oscar';
  /**
   * ★★★ 2026-10-15 改：原来这里是「奥森」—— 那是【我们之间的昵称】。
   *   而「关于」页是【给所有下载者看的对外材料】⇒ 按奥森 2026-10-06 的规矩
   *   （「王奥森」只在我们之间叫），对外一律用他的公开身份。
   *   ⚠️ 同时也守着本页设计原则①「不放真名/学号/住址/生日」（隐私）
   *   ⇒ 用英文名 `Andrew Oscar`（与 Kaggle `andrewoscar`、AtCoder `Andrew_Oscar` 一致，
   *      是他自己定的对外身份）—— 既不是私昵称、也不暴露真名。
   *   ★ 他若要中文名，只需改这一行（如 `'王子乐'` 或 `'安德鲁·奥斯卡'`）。
   */
  static readonly AUTHOR_CN: string = 'Andrew Oscar';


  /**
   * ★ 隐私政策 URL（AGC 上架【硬要求】—— 必须是一个可公开访问的地址）
   *
   * ✅ **已上线**（2026-10-13 15:30 · GitHub Pages · 实测 HTTP 200）：
   *   · GitHub Pages  ⇒ https://<用户名>.github.io/onemore/privacy-zh.html
   *   · Gitee Pages   ⇒ （需实名）
   *   · AGC 合规服务  ⇒ AGC 后台生成后填这里
   *   · Cloudflare Pages ⇒ https://<项目>.pages.dev/privacy-zh.html
   *   ⇒ **换托管只改这一行**；改完记得重新构建 + 上架前在真机点一次确认能打开。
   *
   * ⚠️ 应用内「隐私政策」入口与首启弹窗都读这个常量 ⇒ 只有一个真相源。
   */
  static readonly PRIVACY_URL: string = 'https://awesome639.github.io/onemore-privacy/';

  /** 英文版（英文界面下用；没有就回落中文版） */
  static readonly PRIVACY_URL_EN: string = 'https://awesome639.github.io/onemore-privacy/privacy-en.html';

  /** 用户协议的标题（AGC 有时要） */
  static readonly PRIVACY_TITLE_CN: string = '隐私政策';
  static readonly PRIVACY_TITLE_EN: string = 'Privacy Policy';

  /** 版本号（发版时改这里） */
  static readonly VERSION: string = '1.0.0';

  /** 版权行 */
  static readonly YEAR: string = '2026';
}
