#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把隐私页三条新文案写进 I18n.ets（11 语言）。

★ 转义铁律（这次踩过）：
  GuidePage 源码里的 '\\n\\n' 在文件里是【反斜杠 + n 两个字符】，
  运行期才会变成真换行。写进 I18n 表时必须**保持这两个字符**，
  绝不能把反斜杠再转义一次（那样运行期得到的是字面 "\\n"，key 就对不上了）。
  ⇒ esc() 只做两件事：转义双引号、把真换行变 \\n。
"""
import io
import json
import sys

GP = '/Users/a0000/dev/yiju/entry/src/main/ets/pages/GuidePage.ets'
I18N = '/Users/a0000/dev/yiju/entry/src/main/ets/core/I18n.ets'

import re

src = io.open(GP, encoding='utf-8').read()
k1 = re.search(r"this\.t\('(「One More」不采集[^']*)'", src).group(1)
k2 = k3 = None
for mm in re.finditer(r"this\.sec\(\s*'([^']*)'\s*,\s*'[^']*'\s*,\s*'([^']*)'", src):
    if mm.group(2).startswith('本应用不收集、不存储、不传输'):
        k2 = mm.group(2)
    elif mm.group(2).startswith('本应用只接入了一个第三方组件'):
        k3 = mm.group(2)

assert k1 and k2 and k3

ENTRIES = {}
ENTRIES[k1] = {
 "en": '"One More" does not collect your personal information and never uploads your game records. Everything stays on your device. Only two features use the network: LAN play and Huawei Game Service account check.',
 "zh-Hant": '「One More」不收集你的個人資訊，也不上傳你的遊戲紀錄。所有紀錄只存在你自己的手機裡。需連網的只有兩項：區域網路對戰、華為遊戲服務的帳號校驗。',
 "ja": '「One More」はあなたの個人情報を収集せず、ゲーム記録も送信しません。記録はすべて端末内に残ります。ネットワークを使うのは2つだけ：LAN対戦と、Huawei Game Service のアカウント確認です。',
 "ko": '「One More」는 개인정보를 수집하지 않고 게임 기록도 업로드하지 않습니다. 모든 기록은 기기에 남습니다. 네트워크를 쓰는 기능은 두 가지뿐입니다: LAN 대전과 Huawei Game Service 계정 확인.',
 "fr": "« One More » ne collecte pas vos informations personnelles et n'envoie jamais vos parties. Tout reste sur votre appareil. Seules deux fonctions utilisent le réseau : le jeu en réseau local et la vérification de compte Huawei Game Service.",
 "de": '„One More“ sammelt keine persönlichen Daten und lädt keine Spieldaten hoch. Alles bleibt auf deinem Gerät. Nur zwei Funktionen nutzen das Netzwerk: LAN-Spiel und die Konto-Prüfung von Huawei Game Service.',
 "es": '«One More» no recopila tu información personal ni sube tus partidas. Todo se queda en tu dispositivo. Solo dos funciones usan la red: el juego en red local y la verificación de cuenta de Huawei Game Service.',
 "ru": '«One More» не собирает ваши личные данные и не передаёт игровые записи. Всё остаётся на вашем устройстве. Сеть нужна только двум функциям: игре по локальной сети и проверке аккаунта Huawei Game Service.',
 "ar": '«One More» لا يجمع معلوماتك الشخصية ولا يرفع سجلات لعبك. كل شيء يبقى على جهازك. ميزتان فقط تستخدمان الشبكة: اللعب عبر الشبكة المحلية والتحقق من حساب Huawei Game Service.',
 "pt": '«One More» não recolhe informações pessoais nem envia os seus jogos. Tudo fica no seu dispositivo. Apenas duas funções usam a rede: o jogo em rede local e a verificação de conta Huawei Game Service.',
 "it": "«One More» non raccoglie informazioni personali e non carica le tue partite. Tutto resta sul tuo dispositivo. Solo due funzioni usano la rete: il gioco in rete locale e la verifica dell'account Huawei Game Service.",
}

ENTRIES[k2] = {
 "en": 'This app does not collect, store or transmit: identity information such as your name, phone number or email; contacts; call logs; text messages; location; photos or camera content; microphone content; device identifiers (IMEI / OAID / MAC); your list of installed apps; the clipboard; or any record of network access.\\n\\nAbout network access: this app requests only two permissions — network and Wi-Fi information — for two purposes: (1) LAN play, so two devices on the same Wi-Fi can find each other and connect directly; (2) account check for Huawei Game Service, a compliance requirement for the game category on the app market (anti-addiction), performed by the Huawei SDK — this app never touches the check result content. Beyond that, no location, camera, microphone, contacts, calendar, phone, SMS or storage permissions are requested.\\n\\nLAN play never goes through any server: messages travel directly between the two devices on your Wi-Fi and the connection closes when the round ends. The other 353 games, along with all records and statistics, stay completely offline and work in airplane mode.',
 "zh-Hant": '本應用不收集、不儲存、不傳輸：姓名/手機號/信箱等身分資訊、通訊錄、通話紀錄、簡訊、位置資訊、相簿與相機內容、麥克風內容、裝置識別碼（IMEI/OAID/MAC）、應用程式安裝清單、剪貼簿、網路存取紀錄。\\n\\n關於網路權限：本應用**只申請了網路權限與 Wi-Fi 資訊兩項**，用於兩件事：① **「區域網路對戰」** —— 讓同一 Wi-Fi 下的兩台裝置互相找到並直連；② **華為遊戲服務的帳號校驗** —— 應用市場對遊戲類目的合規要求（防沉迷），由華為 SDK 完成，本應用不接觸校驗內容。**除此之外**，本應用未申請位置、相機、麥克風、通訊錄、行事曆、電話、簡訊、儲存讀寫等任何敏感權限。\\n\\n區域網路對戰**不經過任何伺服器**：訊息只在同一 Wi-Fi 內的兩台裝置之間直接傳輸，一局結束即斷開。其餘 353 款遊戲與全部紀錄、統計**完全離線**，飛航模式下照常可玩。',
 "ja": '本アプリは、氏名・電話番号・メールアドレスなどの身元情報、連絡先、通話履歴、SMS、位置情報、写真・カメラの内容、マイクの内容、端末識別子（IMEI/OAID/MAC）、インストール済みアプリ一覧、クリップボード、ネットワークアクセス記録を収集・保存・送信しません。\\n\\nネットワーク権限について：本アプリが要求するのは**ネットワークと Wi-Fi 情報の2つだけ**で、用途は2つです。①**LAN対戦** —— 同じ Wi-Fi 上の2台が互いを見つけて直接接続するため。②**Huawei Game Service のアカウント確認** —— アプリマーケットのゲーム分類におけるコンプライアンス要件（依存防止）で、Huawei SDK が行い、本アプリは確認内容に触れません。**それ以外**に、位置・カメラ・マイク・連絡先・カレンダー・電話・SMS・ストレージなどの権限は要求しません。\\n\\nLAN対戦は**サーバーを経由しません**：メッセージは同じ Wi-Fi 内の2台の間で直接やり取りされ、1回が終われば切断されます。残り353本のゲームとすべての記録・統計は**完全オフライン**で、機内モードでも遊べます。',
 "ko": '본 앱은 이름·전화번호·이메일 등 신원 정보, 연락처, 통화 기록, 문자, 위치 정보, 사진·카메라 내용, 마이크 내용, 기기 식별자(IMEI/OAID/MAC), 설치된 앱 목록, 클립보드, 네트워크 접속 기록을 수집·저장·전송하지 않습니다.\\n\\n네트워크 권한에 대해: 본 앱이 요청하는 것은 **네트워크와 Wi-Fi 정보 두 가지뿐**이며, 용도는 두 가지입니다. ① **LAN 대전** — 같은 Wi-Fi의 두 기기가 서로를 찾아 직접 연결되도록. ② **Huawei Game Service 계정 확인** — 앱 마켓의 게임 분류 컴플라이언스 요건(과몰입 방지)으로, Huawei SDK가 수행하며 본 앱은 확인 내용에 접근하지 않습니다. **그 외** 위치·카메라·마이크·연락처·캘린더·전화·문자·저장소 권한은 요청하지 않습니다.\\n\\nLAN 대전은 **어떤 서버도 거치지 않습니다**: 메시지는 같은 Wi-Fi의 두 기기 사이에서 직접 오가고, 한 판이 끝나면 연결이 끊깁니다. 나머지 353개 게임과 모든 기록·통계는 **완전 오프라인**이며 비행기 모드에서도 플레이할 수 있습니다.',
 "fr": "Cette application ne collecte, ne stocke et ne transmet pas : vos informations d'identité (nom, téléphone, e-mail), vos contacts, l'historique d'appels, les SMS, votre position, le contenu de l'appareil photo ou des photos, le contenu du microphone, les identifiants d'appareil (IMEI / OAID / MAC), la liste de vos applications installées, le presse-papiers ou l'historique d'accès réseau.\\n\\nÀ propos de l'accès réseau : cette application ne demande que deux autorisations — réseau et informations Wi-Fi — pour deux usages : (1) le jeu en réseau local, afin que deux appareils du même Wi-Fi se trouvent et se connectent directement ; (2) la vérification de compte Huawei Game Service, exigence de conformité pour la catégorie jeu sur la boutique (prévention de l'addiction), réalisée par le SDK Huawei — l'application n'accède jamais au contenu de cette vérification. Au-delà, aucune autorisation de localisation, caméra, micro, contacts, calendrier, téléphone, SMS ou stockage n'est demandée.\\n\\nLe jeu en réseau local ne passe par aucun serveur : les messages circulent directement entre les deux appareils du même Wi-Fi et la connexion se ferme à la fin de la manche. Les 353 autres jeux, ainsi que tous les enregistrements et statistiques, restent entièrement hors ligne et fonctionnent en mode avion.",
 "de": 'Diese App erhebt, speichert und überträgt nicht: Identitätsdaten wie Name, Telefonnummer oder E-Mail; Kontakte; Anruflisten; SMS; Standort; Foto- oder Kamerainhalte; Mikrofoninhalte; Gerätekennungen (IMEI / OAID / MAC); die Liste installierter Apps; die Zwischenablage; oder Netzwerkzugriffsprotokolle.\\n\\nZur Netzwerkberechtigung: Diese App fordert nur zwei Berechtigungen an — Netzwerk und Wi-Fi-Informationen — für zwei Zwecke: (1) LAN-Spiel, damit zwei Geräte im selben Wi-Fi sich finden und direkt verbinden; (2) Konto-Prüfung von Huawei Game Service, eine Compliance-Anforderung für die Kategorie Spiel im App-Markt (Suchtprävention), durchgeführt vom Huawei SDK — die App berührt den Inhalt der Prüfung nie. Darüber hinaus werden keine Berechtigungen für Standort, Kamera, Mikrofon, Kontakte, Kalender, Telefon, SMS oder Speicher angefordert.\\n\\nLAN-Spiel läuft über keinen Server: Nachrichten gehen direkt zwischen den beiden Geräten im selben Wi-Fi und die Verbindung endet mit der Runde. Die übrigen 353 Spiele sowie alle Aufzeichnungen und Statistiken bleiben vollständig offline und funktionieren im Flugmodus.',
 "es": 'Esta aplicación no recopila, almacena ni transmite: información de identidad como nombre, teléfono o correo; contactos; registro de llamadas; mensajes; ubicación; contenido de fotos o cámara; contenido del micrófono; identificadores de dispositivo (IMEI / OAID / MAC); la lista de aplicaciones instaladas; el portapapeles; ni registros de acceso a la red.\\n\\nSobre el acceso a la red: esta aplicación solo solicita dos permisos — red e información Wi-Fi — para dos fines: (1) el juego en red local, para que dos dispositivos en la misma Wi-Fi se encuentren y conecten directamente; (2) la verificación de cuenta de Huawei Game Service, un requisito de cumplimiento para la categoría de juego en la tienda (prevención de adicción), realizada por el SDK de Huawei — la aplicación nunca accede al contenido de esa verificación. Fuera de eso, no se solicitan permisos de ubicación, cámara, micrófono, contactos, calendario, teléfono, SMS ni almacenamiento.\\n\\nEl juego en red local no pasa por ningún servidor: los mensajes viajan directamente entre los dos dispositivos de tu Wi-Fi y la conexión se cierra al terminar la ronda. Los otros 353 juegos, junto con todos los registros y estadísticas, permanecen completamente sin conexión y funcionan en modo avión.',
 "ru": 'Это приложение не собирает, не хранит и не передаёт: идентификационные данные (имя, телефон, e-mail), контакты, журнал вызовов, SMS, местоположение, содержимое фото и камеры, содержимое микрофона, идентификаторы устройства (IMEI / OAID / MAC), список установленных приложений, буфер обмена и записи о сетевых обращениях.\\n\\nО сетевом доступе: приложение запрашивает только два разрешения — сеть и сведения о Wi-Fi — для двух целей: (1) игра по локальной сети, чтобы два устройства в одной Wi-Fi нашли друг друга и соединились напрямую; (2) проверка аккаунта Huawei Game Service — требование соответствия для категории игр в магазине (профилактика зависимости), выполняется SDK Huawei; приложение не касается содержимого проверки. Сверх этого не запрашиваются разрешения на местоположение, камеру, микрофон, контакты, календарь, телефон, SMS или хранилище.\\n\\nИгра по локальной сети не проходит через серверы: сообщения идут напрямую между двумя устройствами в одной Wi-Fi, соединение закрывается по окончании раунда. Остальные 353 игры, а также все записи и статистика полностью офлайн и работают в авиарежиме.',
 "ar": 'لا يجمع هذا التطبيق ولا يخزّن ولا ينقل: معلومات الهوية كالاسم ورقم الهاتف والبريد؛ جهات الاتصال؛ سجل المكالمات؛ الرسائل؛ الموقع؛ محتوى الصور والكاميرا؛ محتوى الميكروفون؛ معرّفات الجهاز (IMEI / OAID / MAC)؛ قائمة التطبيقات المثبتة؛ الحافظة؛ أو سجلات الوصول إلى الشبكة.\\n\\nبخصوص إذن الشبكة: يطلب التطبيق إذنين فقط — الشبكة ومعلومات Wi-Fi — لغرضين: (١) اللعب عبر الشبكة المحلية، ليجد جهازان على نفس Wi-Fi بعضهما ويتصلا مباشرة؛ (٢) التحقق من حساب Huawei Game Service، وهو متطلب امتثال لفئة الألعاب في المتجر (الوقاية من الإدمان)، ينفّذه Huawei SDK ولا يطّلع التطبيق على محتوى التحقق. عدا ذلك لا يطلب التطبيق أذونات الموقع أو الكاميرا أو الميكروفون أو جهات الاتصال أو التقويم أو الهاتف أو الرسائل أو التخزين.\\n\\nاللعب عبر الشبكة المحلية لا يمر بأي خادم: تنتقل الرسائل مباشرة بين الجهازين على نفس Wi-Fi ويُغلق الاتصال عند انتهاء الجولة. أما الألعاب الـ353 الأخرى وكل السجلات والإحصاءات فتبقى دون اتصال تمامًا وتعمل في وضع الطيران.',
 "pt": 'Esta aplicação não recolhe, armazena nem transmite: informações de identidade como nome, telefone ou e-mail; contactos; registo de chamadas; mensagens; localização; conteúdo de fotos ou câmara; conteúdo do microfone; identificadores do dispositivo (IMEI / OAID / MAC); a lista de aplicações instaladas; a área de transferência; ou registos de acesso à rede.\\n\\nSobre o acesso à rede: esta aplicação pede apenas duas permissões — rede e informações de Wi-Fi — para dois fins: (1) o jogo em rede local, para que dois dispositivos na mesma Wi-Fi se encontrem e liguem diretamente; (2) a verificação de conta Huawei Game Service, um requisito de conformidade para a categoria de jogo na loja (prevenção de dependência), realizada pelo SDK da Huawei — a aplicação nunca acede ao conteúdo dessa verificação. Além disso, não são pedidas permissões de localização, câmara, microfone, contactos, calendário, telefone, SMS ou armazenamento.\\n\\nO jogo em rede local não passa por qualquer servidor: as mensagens viajam diretamente entre os dois dispositivos na sua Wi-Fi e a ligação fecha-se no fim da ronda. Os restantes 353 jogos, bem como todos os registos e estatísticas, ficam totalmente offline e funcionam em modo de avião.',
 "it": "Questa applicazione non raccoglie, memorizza o trasmette: dati identificativi come nome, telefono o e-mail; contatti; registro chiamate; SMS; posizione; contenuti di foto o fotocamera; contenuti del microfono; identificatori del dispositivo (IMEI / OAID / MAC); l'elenco delle app installate; gli appunti; o registri di accesso alla rete.\\n\\nSui permessi di rete: questa app richiede solo due permessi — rete e informazioni Wi-Fi — per due scopi: (1) il gioco in rete locale, perché due dispositivi sulla stessa Wi-Fi si trovino e si colleghino direttamente; (2) la verifica dell'account Huawei Game Service, un requisito di conformità per la categoria giochi nello store (prevenzione della dipendenza), eseguita dall'SDK Huawei — l'app non accede mai al contenuto di tale verifica. Oltre a ciò, non vengono richiesti permessi per posizione, fotocamera, microfono, contatti, calendario, telefono, SMS o archiviazione.\\n\\nIl gioco in rete locale non passa da alcun server: i messaggi viaggiano direttamente tra i due dispositivi sulla tua Wi-Fi e la connessione si chiude a fine partita. Gli altri 353 giochi, insieme a tutti i record e le statistiche, restano completamente offline e funzionano in modalità aereo.",
}

ENTRIES[k3] = {
 "en": 'This app integrates only one third-party component: **Huawei Game Service Kit** — used for the account check mentioned above, a compliance requirement for the game category on the app market. Beyond that it includes no other SDKs (an SDK is a pre-written code package) — none for ads, none for analytics, none for crash reporting, none for social sharing, none for payments and none for push notifications.\\n\\nThe app has no ads, no in-app purchases and costs nothing.',
 "zh-Hant": '本應用只接入了一個第三方元件：**華為 Game Service Kit** —— 用於上面提到的帳號校驗，屬應用市場對遊戲類目的合規要求。除此之外沒有接入任何其他 SDK（SDK 就是別人寫好的程式碼包）—— 沒有廣告的、沒有統計分析的、沒有崩潰回報的、沒有社群分享的、沒有支付的、也沒有推播的。\\n\\n本應用不含任何廣告，不含任何內購，不產生任何費用。',
 "ja": '本アプリが組み込むサードパーティ製コンポーネントは1つだけです：**Huawei Game Service Kit** —— 上記のアカウント確認に使用され、アプリマーケットのゲーム分類におけるコンプライアンス要件です。それ以外の SDK（SDK とは他者が用意したコードパッケージのこと）は一切組み込んでいません —— 広告・解析・クラッシュ報告・SNS共有・決済・プッシュ通知のいずれもありません。\\n\\n本アプリは広告なし、アプリ内課金なし、費用は一切かかりません。',
 "ko": '본 앱이 포함한 서드파티 구성 요소는 하나뿐입니다: **Huawei Game Service Kit** — 위에서 언급한 계정 확인에 사용되며, 앱 마켓의 게임 분류 컴플라이언스 요건입니다. 그 외의 SDK(SDK는 다른 곳에서 만든 코드 패키지)는 전혀 포함하지 않았습니다 — 광고·분석·크래시 보고·소셜 공유·결제·푸시 알림 모두 없습니다.\\n\\n본 앱은 광고가 없고, 인앱 결제가 없으며, 비용이 들지 않습니다.',
 "fr": "Cette application n'intègre qu'un seul composant tiers : **Huawei Game Service Kit** — utilisé pour la vérification de compte mentionnée ci-dessus, une exigence de conformité pour la catégorie jeu sur la boutique. Au-delà, elle n'intègre aucun autre SDK (un SDK est un paquet de code fourni par un tiers) — aucun pour la publicité, aucun pour l'analyse, aucun pour les rapports de plantage, aucun pour le partage social, aucun pour le paiement, aucun pour les notifications push.\\n\\nL'application ne contient aucune publicité, aucun achat intégré et ne coûte rien.",
 "de": 'Diese App bindet nur eine Drittanbieter-Komponente ein: **Huawei Game Service Kit** — genutzt für die oben genannte Konto-Prüfung, eine Compliance-Anforderung für die Kategorie Spiel im App-Markt. Darüber hinaus sind keine weiteren SDKs eingebunden (ein SDK ist ein vorgefertigtes Codepaket) — keines für Werbung, keines für Analyse, keines für Absturzberichte, keines für Social Sharing, keines für Zahlungen und keines für Push-Benachrichtigungen.\\n\\nDie App enthält keine Werbung, keine In-App-Käufe und kostet nichts.',
 "es": 'Esta aplicación integra solo un componente de terceros: **Huawei Game Service Kit** — usado para la verificación de cuenta mencionada arriba, un requisito de cumplimiento para la categoría de juego en la tienda. Fuera de eso no integra ningún otro SDK (un SDK es un paquete de código hecho por terceros) — ninguno de publicidad, ninguno de análisis, ninguno de informes de fallos, ninguno de compartir en redes, ninguno de pagos y ninguno de notificaciones push.\\n\\nLa aplicación no tiene anuncios, no tiene compras integradas y no cuesta nada.',
 "ru": 'В приложение встроен только один сторонний компонент: **Huawei Game Service Kit** — он используется для упомянутой выше проверки аккаунта и является требованием соответствия для категории игр в магазине. Помимо этого, никаких других SDK (SDK — это готовый пакет кода) не подключено: ни рекламных, ни аналитических, ни для отчётов о сбоях, ни для соцсетей, ни для платежей, ни для push-уведомлений.\\n\\nВ приложении нет рекламы, нет встроенных покупок, оно бесплатное.',
 "ar": 'يتضمن هذا التطبيق مكوّنًا واحدًا فقط من طرف ثالث: **Huawei Game Service Kit** — يُستخدم للتحقق من الحساب المذكور أعلاه، وهو متطلب امتثال لفئة الألعاب في المتجر. عدا ذلك لا يتضمن أي SDK آخر (الـSDK حزمة أكواد جاهزة من طرف آخر) — لا للإعلانات، ولا للتحليلات، ولا لتقارير الأعطال، ولا للمشاركة الاجتماعية، ولا للمدفوعات، ولا للإشعارات.\\n\\nلا يحتوي التطبيق على إعلانات ولا مشتريات داخلية ولا يترتب عليه أي تكلفة.',
 "pt": 'Esta aplicação integra apenas um componente de terceiros: **Huawei Game Service Kit** — usado para a verificação de conta mencionada acima, um requisito de conformidade para a categoria de jogo na loja. Além disso não integra qualquer outro SDK (um SDK é um pacote de código feito por terceiros) — nenhum de publicidade, nenhum de análise, nenhum de relatórios de falhas, nenhum de partilha social, nenhum de pagamentos e nenhum de notificações push.\\n\\nA aplicação não tem anúncios, não tem compras integradas e não custa nada.',
 "it": "Questa applicazione integra un solo componente di terze parti: **Huawei Game Service Kit** — usato per la verifica dell'account citata sopra, un requisito di conformità per la categoria giochi nello store. Oltre a ciò non integra altri SDK (un SDK è un pacchetto di codice fornito da terzi) — nessuno per pubblicità, nessuno per analisi, nessuno per segnalazioni di crash, nessuno per condivisione social, nessuno per pagamenti e nessuno per notifiche push.\\n\\nL'applicazione non contiene pubblicità, non contiene acquisti in-app e non costa nulla.",
}


def esc(v):
    """v 里的 \\n 已是【反斜杠+n 两个字符】⇒ 原样保留；只转义引号与真换行"""
    return v.replace('"', '\\"').replace('\n', '\\n')


def main():
    lines = []
    for key in (k1, k2, k3):
        langs = ENTRIES[key]
        lines.append('  "%s": {' % esc(key))
        for L in ['en', 'zh-Hant', 'ja', 'ko', 'fr', 'de', 'es', 'ru', 'ar', 'pt', 'it']:
            if L in langs:
                lines.append('    "%s": "%s",' % (L, esc(langs[L])))
        lines.append('  },')
    block = '\n'.join(lines)

    s = io.open(I18N, encoding='utf-8').read()
    if esc(k1) in s:
        print('  · 已存在，跳过')
        return
    ANCHOR = '  "标准字号与间距": {'
    if ANCHOR not in s:
        print('  🔴 锚点未找到')
        return
    s = s.replace(ANCHOR, block + '\n' + ANCHOR, 1)
    io.open(I18N, 'w', encoding='utf-8').write(s)
    print('  ✅ 写入 %d 行（3 条 × 11 语言）' % len(lines))


if __name__ == '__main__':
    main()
