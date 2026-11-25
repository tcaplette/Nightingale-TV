# The interface strings youtube-subscriptions adds, in every language
# (lib/l10n/GLOSSARY.md). Run once to add them to the ARB files:
#   python3 tool/l10n_youtube_strings.py && flutter gen-l10n
# Keys already in a file are replaced, so it can be run again.
import json
import os
import sys

LANGS = ["en", "de", "fr", "es", "pt", "it", "ja", "zh", "zh_Hant", "zh_Hant_HK"]

# key: (placeholders, {lang: text}); zh_Hant_HK falls back to zh_Hant.
S = {
    "youTube": ({}, {l: "YouTube" for l in LANGS}),
    "youTubeTerms": ({}, {
        "en": "By signing in you agree to YouTube's Terms of Service and the Nightingale TV privacy policy.",
        "de": "Mit der Anmeldung stimmst du den Nutzungsbedingungen von YouTube und der Datenschutzerklärung von Nightingale TV zu.",
        "fr": "En vous connectant, vous acceptez les conditions d'utilisation de YouTube et la politique de confidentialité de Nightingale TV.",
        "es": "Al iniciar sesión aceptas los Términos del servicio de YouTube y la política de privacidad de Nightingale TV.",
        "pt": "Ao entrar, você concorda com os Termos de Serviço do YouTube e a política de privacidade do Nightingale TV.",
        "it": "Accedendo accetti i Termini di servizio di YouTube e l'informativa sulla privacy di Nightingale TV.",
        "ja": "サインインすると、YouTube 利用規約と Nightingale TV のプライバシーポリシーに同意したことになります。",
        "zh": "登录即表示你同意 YouTube 服务条款和 Nightingale TV 隐私政策。",
        "zh_Hant": "登入即表示你同意 YouTube 服務條款和 Nightingale TV 隱私權政策。",
        "zh_Hant_HK": "登入即表示你同意 YouTube 服務條款和 Nightingale TV 私隱政策。",
    }),
    "youTubeTermsOfService": ({}, {
        "en": "YouTube Terms of Service", "de": "YouTube-Nutzungsbedingungen", "fr": "Conditions d'utilisation de YouTube",
        "es": "Términos del servicio de YouTube", "pt": "Termos de Serviço do YouTube", "it": "Termini di servizio di YouTube",
        "ja": "YouTube 利用規約", "zh": "YouTube 服务条款", "zh_Hant": "YouTube 服務條款", "zh_Hant_HK": "YouTube 服務條款",
    }),
    "privacyPolicy": ({}, {
        "en": "Privacy policy", "de": "Datenschutzerklärung", "fr": "Politique de confidentialité",
        "es": "Política de privacidad", "pt": "Política de privacidade", "it": "Informativa sulla privacy",
        "ja": "プライバシーポリシー", "zh": "隐私政策", "zh_Hant": "隱私權政策", "zh_Hant_HK": "私隱政策",
    }),
    "youTubeEnterCode": ({"address": "String"}, {
        "en": "On your phone or computer, go to {address} and enter this code.",
        "de": "Öffne auf deinem Handy oder Computer {address} und gib diesen Code ein.",
        "fr": "Sur votre téléphone ou ordinateur, allez sur {address} et saisissez ce code.",
        "es": "En tu teléfono u ordenador, ve a {address} e introduce este código.",
        "pt": "No celular ou computador, acesse {address} e digite este código.",
        "it": "Sul telefono o sul computer, vai su {address} e inserisci questo codice.",
        "ja": "スマートフォンかパソコンで {address} を開き、このコードを入力してください。",
        "zh": "在手机或电脑上前往 {address}，输入此代码。",
        "zh_Hant": "在手機或電腦上前往 {address}，輸入這組代碼。",
        "zh_Hant_HK": "在手機或電腦上前往 {address}，輸入這組代碼。",
    }),
    "openGoogleDevice": ({}, {
        "en": "Open google.com/device", "de": "google.com/device öffnen", "fr": "Ouvrir google.com/device",
        "es": "Abrir google.com/device", "pt": "Abrir google.com/device", "it": "Apri google.com/device",
        "ja": "google.com/device を開く", "zh": "打开 google.com/device", "zh_Hant": "開啟 google.com/device",
        "zh_Hant_HK": "開啟 google.com/device",
    }),
    "signInWasCancelled": ({}, {
        "en": "Sign-in was cancelled", "de": "Die Anmeldung wurde abgebrochen", "fr": "La connexion a été annulée",
        "es": "Se canceló el inicio de sesión", "pt": "A entrada foi cancelada", "it": "L'accesso è stato annullato",
        "ja": "サインインはキャンセルされました", "zh": "登录已取消", "zh_Hant": "登入已取消", "zh_Hant_HK": "登入已取消",
    }),
    "youTubeChannelsTitle": ({}, {
        "en": "YouTube channels", "de": "YouTube-Kanäle", "fr": "Chaînes YouTube", "es": "Canales de YouTube",
        "pt": "Canais do YouTube", "it": "Canali YouTube", "ja": "YouTube チャンネル", "zh": "YouTube 频道",
        "zh_Hant": "YouTube 頻道", "zh_Hant_HK": "YouTube 頻道",
    }),
    "youTubePickedOf": ({"count": "int", "limit": "int"}, {
        "en": "{count} of {limit}", "de": "{count} von {limit}", "fr": "{count} sur {limit}", "es": "{count} de {limit}",
        "pt": "{count} de {limit}", "it": "{count} di {limit}", "ja": "{count} / {limit}", "zh": "{count} / {limit}",
        "zh_Hant": "{count} / {limit}", "zh_Hant_HK": "{count} / {limit}",
    }),
    "notSubscribed": ({}, {
        "en": "Not subscribed", "de": "Nicht abonniert", "fr": "Pas abonné", "es": "Sin suscripción", "pt": "Não inscrito",
        "it": "Non iscritto", "ja": "登録していません", "zh": "未订阅", "zh_Hant": "未訂閱", "zh_Hant_HK": "未訂閱",
    }),
    "searchSubscriptions": ({}, {
        "en": "Search your subscriptions", "de": "Abos durchsuchen", "fr": "Rechercher dans vos abonnements",
        "es": "Buscar en tus suscripciones", "pt": "Pesquisar suas inscrições", "it": "Cerca nelle iscrizioni",
        "ja": "登録チャンネルを検索", "zh": "搜索你的订阅", "zh_Hant": "搜尋你的訂閱內容", "zh_Hant_HK": "搜尋你的訂閱內容",
    }),
    "noSubscriptions": ({}, {
        "en": "This account has no subscriptions", "de": "Dieses Konto hat keine Abos",
        "fr": "Ce compte n'a aucun abonnement", "es": "Esta cuenta no tiene suscripciones",
        "pt": "Esta conta não tem inscrições", "it": "Questo account non ha iscrizioni",
        "ja": "このアカウントには登録チャンネルがありません", "zh": "此账户没有订阅", "zh_Hant": "這個帳戶沒有訂閱內容",
        "zh_Hant_HK": "這個帳戶沒有訂閱內容",
    }),
    "noSubscriptionsMatch": ({}, {
        "en": "No subscription matches", "de": "Kein Abo passt", "fr": "Aucun abonnement ne correspond",
        "es": "Ninguna suscripción coincide", "pt": "Nenhuma inscrição corresponde", "it": "Nessuna iscrizione corrisponde",
        "ja": "一致する登録チャンネルはありません", "zh": "没有匹配的订阅", "zh_Hant": "沒有相符的訂閱內容",
        "zh_Hant_HK": "沒有相符的訂閱內容",
    }),
    "removeYouTubeChannels": ({"names": "String"}, {
        "en": "Remove {names} from the guide?", "de": "{names} aus dem TV-Guide entfernen?",
        "fr": "Retirer {names} du guide ?", "es": "¿Quitar {names} de la guía?", "pt": "Remover {names} do guia?",
        "it": "Rimuovere {names} dalla guida?", "ja": "{names} を番組表から削除しますか？", "zh": "要从节目指南中移除 {names} 吗？",
        "zh_Hant": "要從節目表中移除 {names} 嗎？", "zh_Hant_HK": "要從節目表中移除 {names} 嗎？",
    }),
    "youTubeChannelCount": ({"count": "int"}, {
        "en": "{count, plural, =1{1 channel} other{{count} channels}}",
        "de": "{count, plural, =1{1 Kanal} other{{count} Kanäle}}",
        "fr": "{count, plural, =1{1 chaîne} other{{count} chaînes}}",
        "es": "{count, plural, =1{1 canal} other{{count} canales}}",
        "pt": "{count, plural, =1{1 canal} other{{count} canais}}",
        "it": "{count, plural, =1{1 canale} other{{count} canali}}",
        "ja": "{count} チャンネル", "zh": "{count} 个频道", "zh_Hant": "{count} 個頻道", "zh_Hant_HK": "{count} 個頻道",
    }),
    "googleClient": ({}, {
        "en": "Google client", "de": "Google-Client", "fr": "Client Google", "es": "Cliente de Google",
        "pt": "Cliente do Google", "it": "Client Google", "ja": "Google クライアント", "zh": "Google 客户端",
        "zh_Hant": "Google 用戶端", "zh_Hant_HK": "Google 用戶端",
    }),
    "googleClientShared": ({}, {
        "en": "Nightingale TV's", "de": "Von Nightingale TV", "fr": "Celui de Nightingale TV", "es": "El de Nightingale TV",
        "pt": "O do Nightingale TV", "it": "Quello di Nightingale TV", "ja": "Nightingale TV のもの",
        "zh": "Nightingale TV 的", "zh_Hant": "Nightingale TV 的", "zh_Hant_HK": "Nightingale TV 的",
    }),
    "googleClientOwn": ({}, {
        "en": "Your own", "de": "Dein eigener", "fr": "Le vôtre", "es": "El tuyo", "pt": "O seu", "it": "Il tuo",
        "ja": "自分のもの", "zh": "你自己的", "zh_Hant": "你自己的", "zh_Hant_HK": "你自己的",
    }),
    "youTubeDailyLimit": ({"time": "String"}, {
        "en": "YouTube's daily limit is reached. New videos come after {time}.",
        "de": "Das Tageslimit von YouTube ist erreicht. Neue Videos kommen nach {time}.",
        "fr": "La limite quotidienne de YouTube est atteinte. Les nouvelles vidéos arriveront après {time}.",
        "es": "Se alcanzó el límite diario de YouTube. Los vídeos nuevos llegarán después de las {time}.",
        "pt": "O limite diário do YouTube foi atingido. Vídeos novos chegam depois de {time}.",
        "it": "Il limite giornaliero di YouTube è stato raggiunto. I nuovi video arriveranno dopo le {time}.",
        "ja": "YouTube の 1 日の上限に達しました。新しい動画は {time} 以降に届きます。",
        "zh": "已达到 YouTube 的每日上限。新视频将在 {time} 之后到来。",
        "zh_Hant": "已達到 YouTube 的每日上限。新影片會在 {time} 之後送達。",
        "zh_Hant_HK": "已達到 YouTube 的每日上限。新影片會在 {time} 之後送達。",
    }),
    "useMyOwnClient": ({}, {
        "en": "Use my own client", "de": "Eigenen Client verwenden", "fr": "Utiliser mon propre client",
        "es": "Usar mi propio cliente", "pt": "Usar meu próprio cliente", "it": "Usa il mio client",
        "ja": "自分のクライアントを使う", "zh": "使用我自己的客户端", "zh_Hant": "使用我自己的用戶端",
        "zh_Hant_HK": "使用我自己的用戶端",
    }),
    "signInToYouTubeAgain": ({}, {
        "en": "Sign in to YouTube again", "de": "Erneut bei YouTube anmelden", "fr": "Reconnectez-vous à YouTube",
        "es": "Vuelve a iniciar sesión en YouTube", "pt": "Entre no YouTube de novo", "it": "Accedi di nuovo a YouTube",
        "ja": "YouTube にもう一度サインインしてください", "zh": "请重新登录 YouTube", "zh_Hant": "請重新登入 YouTube",
        "zh_Hant_HK": "請重新登入 YouTube",
    }),
    "ownClientTitle": ({}, {
        "en": "Your own Google client", "de": "Eigener Google-Client", "fr": "Votre propre client Google",
        "es": "Tu propio cliente de Google", "pt": "Seu próprio cliente do Google", "it": "Il tuo client Google",
        "ja": "自分の Google クライアント", "zh": "你自己的 Google 客户端", "zh_Hant": "你自己的 Google 用戶端",
        "zh_Hant_HK": "你自己的 Google 用戶端",
    }),
    "clientId": ({}, {
        "en": "Client ID", "de": "Client-ID", "it": "ID client", "fr": "ID client", "es": "ID de cliente", "pt": "ID do cliente", "ja": "クライアント ID", "zh": "客户端 ID",
        "zh_Hant": "用戶端 ID", "zh_Hant_HK": "用戶端 ID",
    }),
    "clientSecret": ({}, {
        "en": "Client secret", "de": "Clientschlüssel", "fr": "Code secret du client", "es": "Secreto del cliente",
        "pt": "Chave secreta do cliente", "it": "Chiave segreta del client", "ja": "クライアント シークレット", "zh": "客户端密钥",
        "zh_Hant": "用戶端密鑰", "zh_Hant_HK": "用戶端密鑰",
    }),
    "openClientFile": ({}, {
        "en": "Open file", "de": "Datei öffnen", "fr": "Ouvrir un fichier", "es": "Abrir archivo", "pt": "Abrir arquivo",
        "it": "Apri file", "ja": "ファイルを開く", "zh": "打开文件", "zh_Hant": "開啟檔案", "zh_Hant_HK": "開啟檔案",
    }),
    "clientFileNotRead": ({}, {
        "en": "That file isn't a Google client file", "de": "Diese Datei ist keine Google-Client-Datei",
        "fr": "Ce fichier n'est pas un fichier de client Google", "es": "Ese archivo no es de un cliente de Google",
        "pt": "Esse arquivo não é de um cliente do Google", "it": "Quel file non è un file di client Google",
        "ja": "このファイルは Google クライアントのファイルではありません", "zh": "该文件不是 Google 客户端文件",
        "zh_Hant": "這個檔案不是 Google 用戶端檔案", "zh_Hant_HK": "這個檔案不是 Google 用戶端檔案",
    }),
    "useThisClient": ({}, {
        "en": "Use this client", "de": "Diesen Client verwenden", "fr": "Utiliser ce client", "es": "Usar este cliente",
        "pt": "Usar este cliente", "it": "Usa questo client", "ja": "このクライアントを使う", "zh": "使用此客户端",
        "zh_Hant": "使用這個用戶端", "zh_Hant_HK": "使用這個用戶端",
    }),
    "useSharedClient": ({}, {
        "en": "Use Nightingale TV's client", "de": "Client von Nightingale TV verwenden",
        "fr": "Utiliser le client de Nightingale TV", "es": "Usar el cliente de Nightingale TV",
        "pt": "Usar o cliente do Nightingale TV", "it": "Usa il client di Nightingale TV",
        "ja": "Nightingale TV のクライアントを使う", "zh": "使用 Nightingale TV 的客户端",
        "zh_Hant": "使用 Nightingale TV 的用戶端", "zh_Hant_HK": "使用 Nightingale TV 的用戶端",
    }),
    "ownClientStep1": ({}, {
        "en": "Open console.cloud.google.com and create a project.",
        "de": "Öffne console.cloud.google.com und erstelle ein Projekt.",
        "fr": "Ouvrez console.cloud.google.com et créez un projet.",
        "es": "Abre console.cloud.google.com y crea un proyecto.",
        "pt": "Abra console.cloud.google.com e crie um projeto.",
        "it": "Apri console.cloud.google.com e crea un progetto.",
        "ja": "console.cloud.google.com を開き、プロジェクトを作成します。",
        "zh": "打开 console.cloud.google.com 并创建一个项目。",
        "zh_Hant": "開啟 console.cloud.google.com 並建立專案。",
        "zh_Hant_HK": "開啟 console.cloud.google.com 並建立專案。",
    }),
    "ownClientStep2": ({}, {
        "en": "Turn on YouTube Data API v3.", "de": "Aktiviere YouTube Data API v3.", "fr": "Activez YouTube Data API v3.",
        "es": "Activa YouTube Data API v3.", "pt": "Ative a YouTube Data API v3.", "it": "Attiva YouTube Data API v3.",
        "ja": "YouTube Data API v3 を有効にします。", "zh": "启用 YouTube Data API v3。", "zh_Hant": "啟用 YouTube Data API v3。",
        "zh_Hant_HK": "啟用 YouTube Data API v3。",
    }),
    "ownClientStep3": ({}, {
        "en": "Set up the OAuth consent screen with the youtube.readonly scope.",
        "de": "Richte den OAuth-Zustimmungsbildschirm mit dem Bereich youtube.readonly ein.",
        "fr": "Configurez l'écran de consentement OAuth avec le champ d'application youtube.readonly.",
        "es": "Configura la pantalla de consentimiento de OAuth con el permiso youtube.readonly.",
        "pt": "Configure a tela de consentimento OAuth com o escopo youtube.readonly.",
        "it": "Configura la schermata di consenso OAuth con l'ambito youtube.readonly.",
        "ja": "OAuth 同意画面を設定し、youtube.readonly スコープを追加します。",
        "zh": "设置 OAuth 同意屏幕，并添加 youtube.readonly 范围。",
        "zh_Hant": "設定 OAuth 同意畫面，並加入 youtube.readonly 範圍。",
        "zh_Hant_HK": "設定 OAuth 同意畫面，並加入 youtube.readonly 範圍。",
    }),
    "ownClientStep4": ({}, {
        "en": "Set its publishing status to In production.",
        "de": "Setze den Veröffentlichungsstatus auf „In Produktion“.",
        "fr": "Passez son état de publication à « En production ».",
        "es": "Cambia su estado de publicación a «En producción».",
        "pt": "Mude o status de publicação para \"Em produção\".",
        "it": "Imposta lo stato di pubblicazione su \"In produzione\".",
        "ja": "公開ステータスを「本番環境」にします。",
        "zh": "将发布状态设为“正式版”。",
        "zh_Hant": "將發布狀態設為「正式版」。",
        "zh_Hant_HK": "將發布狀態設為「正式版」。",
    }),
    "ownClientStep5": ({}, {
        "en": "Create an OAuth client of the type TVs and Limited Input devices.",
        "de": "Erstelle einen OAuth-Client vom Typ „Fernseher und Geräte mit begrenzter Eingabe“.",
        "fr": "Créez un client OAuth de type « TV et appareils à saisie limitée ».",
        "es": "Crea un cliente de OAuth del tipo «TVs y dispositivos de entrada limitada».",
        "pt": "Crie um cliente OAuth do tipo \"TVs e dispositivos de entrada limitada\".",
        "it": "Crea un client OAuth di tipo \"TV e dispositivi con input limitato\".",
        "ja": "種類が「テレビと入力が限られたデバイス」の OAuth クライアントを作成します。",
        "zh": "创建类型为“电视和受限输入设备”的 OAuth 客户端。",
        "zh_Hant": "建立類型為「電視和輸入受限的裝置」的 OAuth 用戶端。",
        "zh_Hant_HK": "建立類型為「電視和輸入受限的裝置」的 OAuth 用戶端。",
    }),
    "ownClientStep6": ({}, {
        "en": "Enter its Client ID and Client secret here, or open its downloaded file.",
        "de": "Gib hier die Client-ID und den Clientschlüssel ein oder öffne die heruntergeladene Datei.",
        "fr": "Saisissez ici son ID client et son code secret, ou ouvrez le fichier téléchargé.",
        "es": "Introduce aquí su ID de cliente y su secreto, o abre el archivo descargado.",
        "pt": "Digite aqui o ID do cliente e a chave secreta, ou abra o arquivo baixado.",
        "it": "Inserisci qui il Client ID e il Client secret, oppure apri il file scaricato.",
        "ja": "ここにクライアント ID とシークレットを入力するか、ダウンロードしたファイルを開きます。",
        "zh": "在此输入客户端 ID 和密钥，或打开下载的文件。",
        "zh_Hant": "在這裡輸入用戶端 ID 和密鑰，或開啟下載的檔案。",
        "zh_Hant_HK": "在這裡輸入用戶端 ID 和密鑰，或開啟下載的檔案。",
    }),
    "ownClientGuide": ({"address": "String"}, {
        "en": "The full guide: {address}", "de": "Die ganze Anleitung: {address}", "fr": "Le guide complet : {address}",
        "es": "La guía completa: {address}", "pt": "O guia completo: {address}", "it": "La guida completa: {address}",
        "ja": "詳しい手順: {address}", "zh": "完整指南：{address}", "zh_Hant": "完整指南：{address}",
        "zh_Hant_HK": "完整指南：{address}",
    }),
    "clientRefused": ({}, {
        "en": "Google didn't accept this client. It must be of the type TVs and Limited Input devices.",
        "de": "Google hat diesen Client nicht angenommen. Er muss vom Typ „Fernseher und Geräte mit begrenzter Eingabe“ sein.",
        "fr": "Google n'a pas accepté ce client. Il doit être de type « TV et appareils à saisie limitée ».",
        "es": "Google no aceptó este cliente. Debe ser del tipo «TVs y dispositivos de entrada limitada».",
        "pt": "O Google não aceitou este cliente. Ele precisa ser do tipo \"TVs e dispositivos de entrada limitada\".",
        "it": "Google non ha accettato questo client. Deve essere di tipo \"TV e dispositivi con input limitato\".",
        "ja": "Google がこのクライアントを受け付けませんでした。種類は「テレビと入力が限られたデバイス」である必要があります。",
        "zh": "Google 不接受此客户端。它必须是“电视和受限输入设备”类型。",
        "zh_Hant": "Google 不接受這個用戶端。類型必須是「電視和輸入受限的裝置」。",
        "zh_Hant_HK": "Google 不接受這個用戶端。類型必須是「電視和輸入受限的裝置」。",
    }),
    # youtube-shared-client D3, D6.
    "youTubeNoClient": ({}, {
        "en": "This build has no YouTube client. Its README says how to add one.",
        "de": "Diese Version hat keinen YouTube-Client. Ihre README erklärt, wie man einen hinzufügt.",
        "fr": "Cette version n'a pas de client YouTube. Son fichier README explique comment en ajouter un.",
        "es": "Esta versión no tiene cliente de YouTube. Su README explica cómo añadir uno.",
        "pt": "Esta versão não tem um cliente do YouTube. O README dela explica como adicionar um.",
        "it": "Questa versione non ha un client YouTube. Il suo README spiega come aggiungerne uno.",
        "ja": "このビルドには YouTube クライアントがありません。追加方法は README に書かれています。",
        "zh": "此版本没有 YouTube 客户端。README 中说明了如何添加。",
        "zh_Hant": "這個版本沒有 YouTube 用戶端。README 中說明了如何新增。",
        "zh_Hant_HK": "這個版本沒有 YouTube 用戶端。README 中說明了如何新增。",
    }),
    "youTubeSharedLimit": ({"limit": "int"}, {
        "en": "Nightingale TV's client allows {limit} YouTube channels. For more, use your own Google client in Servers → YouTube → Google client.",
        "de": "Der Client von Nightingale TV erlaubt {limit} YouTube-Kanäle. Für mehr nutze deinen eigenen Google-Client unter Server → YouTube → Google-Client.",
        "fr": "Le client de Nightingale TV permet {limit} chaînes YouTube. Pour plus, utilisez votre propre client Google dans Serveurs → YouTube → Client Google.",
        "es": "El cliente de Nightingale TV permite {limit} canales de YouTube. Para más, usa tu propio cliente de Google en Servidores → YouTube → Cliente de Google.",
        "pt": "O cliente do Nightingale TV permite {limit} canais do YouTube. Para mais, use seu próprio cliente do Google em Servidores → YouTube → Cliente do Google.",
        "it": "Il client di Nightingale TV consente {limit} canali YouTube. Per averne di più, usa il tuo client Google in Server → YouTube → Client Google.",
        "ja": "Nightingale TV のクライアントで追加できる YouTube チャンネルは {limit} 個までです。さらに追加するには、サーバー → YouTube → Google クライアントで自分のクライアントを使ってください。",
        "zh": "Nightingale TV 的客户端最多允许 {limit} 个 YouTube 频道。如需更多，请在 服务器 → YouTube → Google 客户端 中使用你自己的客户端。",
        "zh_Hant": "Nightingale TV 的用戶端最多允許 {limit} 個 YouTube 頻道。如需更多，請在 伺服器 → YouTube → Google 用戶端 中使用你自己的用戶端。",
        "zh_Hant_HK": "Nightingale TV 的用戶端最多允許 {limit} 個 YouTube 頻道。如需更多，請在 伺服器 → YouTube → Google 用戶端 中使用你自己的用戶端。",
    }),
    "youTubeSharedTooMany": ({"limit": "int"}, {
        "en": "Nightingale TV's client allows {limit} YouTube channels. Remove some in Channels first.",
        "de": "Der Client von Nightingale TV erlaubt {limit} YouTube-Kanäle. Entferne zuerst einige unter Sender.",
        "fr": "Le client de Nightingale TV permet {limit} chaînes YouTube. Retirez-en d'abord quelques-unes dans Chaînes.",
        "es": "El cliente de Nightingale TV permite {limit} canales de YouTube. Quita algunos primero en Canales.",
        "pt": "O cliente do Nightingale TV permite {limit} canais do YouTube. Remova alguns primeiro em Canais.",
        "it": "Il client di Nightingale TV consente {limit} canali YouTube. Rimuovine prima alcuni in Canali.",
        "ja": "Nightingale TV のクライアントで追加できる YouTube チャンネルは {limit} 個までです。先に「チャンネル」でいくつか外してください。",
        "zh": "Nightingale TV 的客户端最多允许 {limit} 个 YouTube 频道。请先在“频道”中移除一些。",
        "zh_Hant": "Nightingale TV 的用戶端最多允許 {limit} 個 YouTube 頻道。請先在「頻道」中移除一些。",
        "zh_Hant_HK": "Nightingale TV 的用戶端最多允許 {limit} 個 YouTube 頻道。請先在「頻道」中移除一些。",
    }),
    "noVideosYet": ({}, {
        "en": "No videos yet", "de": "Noch keine Videos", "fr": "Pas encore de vidéos", "es": "Aún no hay vídeos",
        "pt": "Ainda não há vídeos", "it": "Ancora nessun video", "ja": "まだ動画がありません", "zh": "暂无视频",
        "zh_Hant": "還沒有影片", "zh_Hant_HK": "還沒有影片",
    }),
    "youTubeRefusedPlayer": ({}, {
        "en": "YouTube didn't accept this player", "de": "YouTube hat diesen Player nicht angenommen",
        "fr": "YouTube n'a pas accepté ce lecteur", "es": "YouTube no aceptó este reproductor",
        "pt": "O YouTube não aceitou este player", "it": "YouTube non ha accettato questo player",
        "ja": "YouTube がこのプレーヤーを受け付けませんでした", "zh": "YouTube 不接受此播放器",
        "zh_Hant": "YouTube 不接受這個播放器", "zh_Hant_HK": "YouTube 不接受這個播放器",
    }),
    "youTubeNeedsWebView": ({}, {
        "en": "YouTube needs Android System WebView", "de": "YouTube braucht Android System WebView",
        "fr": "YouTube a besoin d'Android System WebView", "es": "YouTube necesita Android System WebView",
        "pt": "O YouTube precisa do Android System WebView", "it": "YouTube richiede Android System WebView",
        "ja": "YouTube には Android System WebView が必要です", "zh": "YouTube 需要 Android System WebView",
        "zh_Hant": "YouTube 需要 Android System WebView", "zh_Hant_HK": "YouTube 需要 Android System WebView",
    }),
    "getItFromPlayStore": ({"address": "String"}, {
        "en": "Get it from the Play Store: {address}", "de": "Im Play Store: {address}",
        "fr": "Disponible sur le Play Store : {address}", "es": "Consíguelo en Play Store: {address}",
        "pt": "Baixe na Play Store: {address}", "it": "Scaricalo dal Play Store: {address}",
        "ja": "Play ストアで入手: {address}", "zh": "从 Play 商店获取：{address}", "zh_Hant": "從 Play 商店取得：{address}",
        "zh_Hant_HK": "從 Play 商店取得：{address}",
    }),
    "youTubeChannelSource": ({"title": "String"}, {
        "en": "YouTube channel: {title}", "de": "YouTube-Kanal: {title}", "fr": "Chaîne YouTube : {title}",
        "es": "Canal de YouTube: {title}", "pt": "Canal do YouTube: {title}", "it": "Canale YouTube: {title}",
        "ja": "YouTube チャンネル: {title}", "zh": "YouTube 频道：{title}", "zh_Hant": "YouTube 頻道：{title}",
        "zh_Hant_HK": "YouTube 頻道：{title}",
    }),
    "publishedOn": ({"date": "String"}, {
        "en": "Published {date}", "de": "Veröffentlicht am {date}", "fr": "Publiée le {date}", "es": "Publicado el {date}",
        "pt": "Publicado em {date}", "it": "Pubblicato il {date}", "ja": "公開日: {date}", "zh": "发布于 {date}",
        "zh_Hant": "發布於 {date}", "zh_Hant_HK": "發布於 {date}",
    }),
    "youTubeCantBeShared": ({}, {
        "en": "YouTube channels can't be shared", "de": "YouTube-Kanäle können nicht geteilt werden",
        "fr": "Les chaînes YouTube ne peuvent pas être partagées", "es": "Los canales de YouTube no se pueden compartir",
        "pt": "Canais do YouTube não podem ser compartilhados", "it": "I canali YouTube non si possono condividere",
        "ja": "YouTube チャンネルは共有できません", "zh": "无法分享 YouTube 频道", "zh_Hant": "無法分享 YouTube 頻道",
        "zh_Hant_HK": "無法分享 YouTube 頻道",
    }),
    "youTubeAlreadyRemovedQuota": ({}, {
        "en": "Try again after YouTube's daily limit resets.",
        "de": "Versuche es erneut, wenn das Tageslimit von YouTube zurückgesetzt ist.",
        "fr": "Réessayez quand la limite quotidienne de YouTube sera réinitialisée.",
        "es": "Vuelve a intentarlo cuando se restablezca el límite diario de YouTube.",
        "pt": "Tente de novo quando o limite diário do YouTube for redefinido.",
        "it": "Riprova quando il limite giornaliero di YouTube si azzera.",
        "ja": "YouTube の 1 日の上限がリセットされてから、もう一度お試しください。",
        "zh": "请在 YouTube 每日上限重置后再试。",
        "zh_Hant": "請在 YouTube 每日上限重設後再試一次。",
        "zh_Hant_HK": "請在 YouTube 每日上限重設後再試一次。",
    }),
    "youTubeAccount": ({}, {
        "en": "YouTube account", "de": "YouTube-Konto", "fr": "Compte YouTube", "es": "Cuenta de YouTube",
        "pt": "Conta do YouTube", "it": "Account YouTube", "ja": "YouTube アカウント", "zh": "YouTube 账户",
        "zh_Hant": "YouTube 帳戶", "zh_Hant_HK": "YouTube 帳戶",
    }),
    "couldNotReachGoogle": ({}, {
        "en": "Google couldn't be reached. Try again.", "de": "Google ist nicht erreichbar. Versuche es erneut.",
        "fr": "Impossible de joindre Google. Réessayez.", "es": "No se pudo conectar con Google. Inténtalo de nuevo.",
        "pt": "Não foi possível acessar o Google. Tente de novo.", "it": "Impossibile raggiungere Google. Riprova.",
        "ja": "Google に接続できませんでした。もう一度お試しください。", "zh": "无法连接 Google，请重试。",
        "zh_Hant": "無法連線到 Google，請再試一次。", "zh_Hant_HK": "無法連線到 Google，請再試一次。",
    }),
    "youTubeDailyLimitShort": ({}, {
        "en": "YouTube's daily limit is reached.", "de": "Das Tageslimit von YouTube ist erreicht.",
        "fr": "La limite quotidienne de YouTube est atteinte.", "es": "Se alcanzó el límite diario de YouTube.",
        "pt": "O limite diário do YouTube foi atingido.", "it": "Il limite giornaliero di YouTube è stato raggiunto.",
        "ja": "YouTube の 1 日の上限に達しました。", "zh": "已达到 YouTube 的每日上限。",
        "zh_Hant": "已達到 YouTube 的每日上限。", "zh_Hant_HK": "已達到 YouTube 的每日上限。",
    }),
    "youTubeNoBreaks": ({}, {
        "en": "YouTube channels have no breaks.", "de": "YouTube-Kanäle haben keine Werbepausen.",
        "fr": "Les chaînes YouTube n'ont pas de pauses publicitaires.", "es": "Los canales de YouTube no tienen pausas publicitarias.",
        "pt": "Canais do YouTube não têm intervalos comerciais.", "it": "I canali YouTube non hanno pause pubblicitarie.",
        "ja": "YouTube チャンネルには CM 枠はありません。", "zh": "YouTube 频道没有广告时间。",
        "zh_Hant": "YouTube 頻道沒有廣告時間。", "zh_Hant_HK": "YouTube 頻道沒有廣告時間。",
    }),
    "youTubeNoBlocks": ({}, {
        "en": "YouTube channels can't have programming blocks.",
        "de": "YouTube-Kanäle können keine Programmblöcke haben.",
        "fr": "Les chaînes YouTube ne peuvent pas avoir de blocs de programmes.",
        "es": "Los canales de YouTube no pueden tener bloques de programación.",
        "pt": "Canais do YouTube não podem ter blocos de programação.",
        "it": "I canali YouTube non possono avere blocchi di programmazione.",
        "ja": "YouTube チャンネルには番組枠を設定できません。", "zh": "YouTube 频道不能有节目时段。",
        "zh_Hant": "YouTube 頻道不能有節目時段。", "zh_Hant_HK": "YouTube 頻道不能有節目時段。",
    }),
    "youTubeRemoveBody": ({}, {
        "en": "Its channels leave the lineup, and Nightingale TV's access to your YouTube account ends.",
        "de": "Seine Sender verschwinden aus der Senderliste, und der Zugriff von Nightingale TV auf dein YouTube-Konto endet.",
        "fr": "Ses chaînes quittent la grille, et l'accès de Nightingale TV à votre compte YouTube prend fin.",
        "es": "Sus canales salen de la parrilla y el acceso de Nightingale TV a tu cuenta de YouTube termina.",
        "pt": "Os canais dele saem da grade, e o acesso do Nightingale TV à sua conta do YouTube termina.",
        "it": "I suoi canali escono dal palinsesto e l'accesso di Nightingale TV al tuo account YouTube termina.",
        "ja": "その YouTube チャンネルはチャンネル構成から外れ、Nightingale TV の YouTube アカウントへのアクセスは終了します。",
        "zh": "它的频道会从频道列表中移除，Nightingale TV 对你 YouTube 账号的访问也会结束。",
        "zh_Hant": "它的頻道會從頻道列表中移除，Nightingale TV 對你 YouTube 帳號的存取也會結束。",
        "zh_Hant_HK": "它的頻道會從頻道列表中移除，Nightingale TV 對你 YouTube 帳號的存取也會結束。",
    }),
    "youTubeAccessNeeded": ({}, {
        "en": "Nightingale TV needs to see your YouTube subscriptions. Enter the new code and allow it.",
        "de": "Nightingale TV muss deine YouTube-Abos sehen können. Gib den neuen Code ein und erlaube es.",
        "fr": "Nightingale TV doit voir vos abonnements YouTube. Saisissez le nouveau code et autorisez-le.",
        "es": "Nightingale TV necesita ver tus suscripciones de YouTube. Introduce el código nuevo y permítelo.",
        "pt": "O Nightingale TV precisa ver suas inscrições do YouTube. Digite o código novo e permita.",
        "it": "Nightingale TV deve poter vedere le tue iscrizioni YouTube. Inserisci il nuovo codice e consentilo.",
        "ja": "Nightingale TV が YouTube の登録チャンネルを見られるようにする必要があります。新しいコードを入力して許可してください。",
        "zh": "Nightingale TV 需要查看你的 YouTube 订阅。请输入新代码并允许。",
        "zh_Hant": "Nightingale TV 需要查看你的 YouTube 訂閱內容。請輸入新的代碼並允許。",
        "zh_Hant_HK": "Nightingale TV 需要查看你的 YouTube 訂閱內容。請輸入新的代碼並允許。",
    }),
}

# Changed strings: the server kinds line names YouTube.
CHANGED = {
    "serverKindsHelp": {
        "en": "You can add Jellyfin, Emby, Plex, YouTube and SMB shares (a NAS, or a computer's shared folder).",
        "de": "Du kannst Jellyfin, Emby, Plex, YouTube und SMB-Freigaben hinzufügen (ein NAS oder den freigegebenen Ordner eines Computers).",
        "fr": "Vous pouvez ajouter Jellyfin, Emby, Plex, YouTube et des partages SMB (un NAS, ou le dossier partagé d'un ordinateur).",
        "es": "Puedes añadir Jellyfin, Emby, Plex, YouTube y carpetas compartidas SMB (un NAS, o la carpeta compartida de un ordenador).",
        "pt": "Você pode adicionar Jellyfin, Emby, Plex, YouTube e compartilhamentos SMB (um NAS, ou a pasta compartilhada de um computador).",
        "it": "Puoi aggiungere Jellyfin, Emby, Plex, YouTube e condivisioni SMB (un NAS, o la cartella condivisa di un computer).",
        "ja": "Jellyfin、Emby、Plex、YouTube、SMB 共有フォルダ（NAS やパソコンの共有フォルダ）を追加できます。",
        "zh": "你可以添加 Jellyfin、Emby、Plex、YouTube 和 SMB 共享文件夹（NAS 或电脑上的共享文件夹）。",
        "zh_Hant": "你可以新增 Jellyfin、Emby、Plex、YouTube 和 SMB 共用資料夾（NAS 或電腦上的共用資料夾）。",
        "zh_Hant_HK": "你可以新增 Jellyfin、Emby、Plex、YouTube 和 SMB 共用資料夾（NAS 或電腦上的共用資料夾）。",
    },
}


def main():
    root = os.path.join(os.path.dirname(__file__), "..", "lib", "l10n")
    for lang in LANGS:
        path = os.path.join(root, f"app_{lang}.arb")
        data = json.load(open(path, encoding="utf-8"))
        for key, (placeholders, texts) in S.items():
            text = texts.get(lang) or texts.get("zh_Hant" if lang == "zh_Hant_HK" else "en")
            data[key] = text
            if lang == "en" and placeholders:
                data["@" + key] = {"placeholders": {n: {"type": t} for n, t in placeholders.items()}}
        for key, texts in CHANGED.items():
            if lang in texts:
                data[key] = texts[lang]
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"{len(S)} strings in {len(LANGS)} languages")


if __name__ == "__main__":
    sys.exit(main())
