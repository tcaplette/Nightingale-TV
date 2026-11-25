// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get onlyChannelsYou =>
      '削除できるのは自分で追加したチャンネルだけです。代わりにこのチャンネルを非表示にしてください。';

  @override
  String get music => '音楽';

  @override
  String get nothingInThe => 'ライブラリに一致するものがありません。';

  @override
  String get chooseSongsOr => '曲またはミュージックビデオを選んでください。';

  @override
  String get blockChannel => '番組枠のチャンネル';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return '同じチャンネルの「$title」（$clash）と重なっています。';
  }

  @override
  String get chooseSomeShows => '番組枠で流す番組や映画を選んでください。';

  @override
  String nothingInThis(Object shortLabel) {
    return 'この組み合わせには $shortLabel 以上の作品がありません。もっと低いレーティングか、別の番組を選んでください。';
  }

  @override
  String get theLineupsShows => 'ラインナップの番組にエピソードがありません。別の番組を選んでください。';

  @override
  String get addAShow => 'ラインナップに番組を追加してください。';

  @override
  String get chooseAChannel => 'チャンネルを選んでください。';

  @override
  String get theBlockHas => '番組枠の終了時刻は開始時刻と違う時刻にしてください。';

  @override
  String get pickAtLeast => '曜日を 1 つ以上選んでください。';

  @override
  String get giveTheBlock => '番組枠にタイトルを付けてください。';

  @override
  String get thisChannelDoesnt => 'このチャンネルには放送枠がありません。';

  @override
  String get onlyShuffledChannels => 'シャッフルし直せるのはシャッフル再生のチャンネルだけです。';

  @override
  String get chooseSomethingFor => 'チャンネルで流すものを選んでください。';

  @override
  String get onlyChannelsYouAdded => '流す内容を変えられるのは自分で追加したチャンネルだけです。';

  @override
  String get myChannel => 'マイチャンネル';

  @override
  String get noneOfYour => 'どのサーバーにも接続できませんでした。';

  @override
  String scanning(Object where) {
    return '$where をスキャン中…';
  }

  @override
  String get buildingChannels => 'チャンネルを作成中…';

  @override
  String get notSignedIn => 'サインインしていません。';

  @override
  String isAlreadyIn(Object name) {
    return '$name はすでにこのプロフィールにあります';
  }

  @override
  String get thatServerIs => 'そのサーバーはもうこのプロフィールにありません';

  @override
  String get yourSessionExpired => 'セッションの有効期限が切れました。もう一度サインインしてください。';

  @override
  String get m3uPlaylist => 'M3U プレイリスト';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName にはライブ TV のチャンネルがありません';
  }

  @override
  String couldntReach(Object serverName) {
    return '$serverName に接続できませんでした';
  }

  @override
  String liveTv(Object serverName) {
    return '$serverName ライブ TV';
  }

  @override
  String liveTvIs(Object serverName) {
    return '$serverName ライブ TV はすでにソースに追加されています';
  }

  @override
  String get notSignedIn2 => 'サインインしていません';

  @override
  String get newGroup => '新しいグループ';

  @override
  String get thisBackupIs => 'このバックアップは壊れています。チャンネルロゴの 1 つを読み込めません。';

  @override
  String get thisBackupIsDamaged => 'このバックアップは壊れています。ライブ TV エクスポートの設定を読み込めません。';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'このバックアップは壊れています。$name の$whatを読み込めません。';
  }

  @override
  String get liveTvSources => 'ライブ TV のソース';

  @override
  String thisBackupCant(Object problem) {
    return 'このバックアップは復元できません。$problem';
  }

  @override
  String get thisBackupIsDamagedIts => 'このバックアップは壊れています。プロフィールを読み込めません。';

  @override
  String get thisFileIs => 'このファイルは Nightingale TV のバックアップとしては大きすぎます。';

  @override
  String get thisBackupWas => 'このバックアップは新しいバージョンの Nightingale TV で作成されました。';

  @override
  String get thisFileIsnt => 'このファイルは Nightingale TV のバックアップではないか、壊れています。';

  @override
  String restoredTheBackup(Object toLocal) {
    return '$toLocal のバックアップを復元しました。';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'バックアップを復元できませんでした：$e';
  }

  @override
  String couldntSaveA(Object e) {
    return '先にバックアップを保存できませんでした：$e';
  }

  @override
  String get automatic => '自動';

  @override
  String get nc1718 => 'NC-17 / 18 歳以上';

  @override
  String get tvMaR => 'TV-MA / R 以上';

  @override
  String get tv14Pg => 'TV-14 / PG-13 以上';

  @override
  String get off => 'オフ';

  @override
  String get nowAndThen => 'ときどき';

  @override
  String get always => '常に';

  @override
  String get truncate => '途中で終了';

  @override
  String get offlineImage => 'オフライン画像';

  @override
  String get filler => '穴埋め';

  @override
  String get leastWatchedFirst => '視聴回数の少ない順';

  @override
  String get shuffled => 'シャッフル';

  @override
  String get inOrderShows => '順番どおり（番組を交互に）';

  @override
  String get channelsWhereEverything =>
      '番組枠も含め、流れるものがすべて TV-Y、TV-Y7、TV-G、G のチャンネル。';

  @override
  String get musicVideoAnd => 'ミュージックビデオとラジオのチャンネル。';

  @override
  String get channelsThatPlay => 'エピソードや音楽ではなく映画を流すチャンネル。';

  @override
  String get channelsFromYour => 'ライブ TV のソースから来たチャンネル。';

  @override
  String get channelsYouMarked => 'お気に入りにしたチャンネル。';

  @override
  String get everyChannel => 'すべてのチャンネル。';

  @override
  String get kids => 'キッズ';

  @override
  String get movies => '映画';

  @override
  String get liveTv2 => 'ライブ TV';

  @override
  String get favorites => 'お気に入り';

  @override
  String get all => 'すべて';

  @override
  String get theAccentsAre => 'アクセントはテーマで、それぞれ theme か channel です。';

  @override
  String get thoseArentRetro => 'それはレトロ設定ではありません。';

  @override
  String get theOverlayTheme =>
      'オーバーレイのテーマは standard、vcr、cableBox、stationIdent のいずれかです。';

  @override
  String get theCrtEffect =>
      'CRT 効果は off、softTube、livingRoom、arcade、studioMonitor、custom のいずれかです。';

  @override
  String get theSurroundImage => '周囲の画像はファイル名で指定します。';

  @override
  String get theSurroundIs => '周囲は black、charcoal、channel、image のいずれかです。';

  @override
  String get thePictureShape => '画面の形は original、fill43、fit43 のいずれかです。';

  @override
  String get channelColor => 'チャンネルの色';

  @override
  String get theme => 'テーマ';

  @override
  String get stationIdent => '局ロゴ';

  @override
  String get cableBox => 'ケーブルボックス';

  @override
  String get vcr => 'ビデオデッキ';

  @override
  String get standard => '標準';

  @override
  String get custom => 'カスタム';

  @override
  String get studioMonitor => 'スタジオモニター';

  @override
  String get arcade => 'アーケード';

  @override
  String get livingRoom => 'リビング';

  @override
  String get softTube => 'やわらかブラウン管';

  @override
  String get customColorIs => 'カスタムの色は natural、warm、faded、vivid のいずれかです。';

  @override
  String get customLinesIs => 'カスタムの走査線は 240 か 480 です。';

  @override
  String customIsOff(Object key) {
    return 'カスタムの $key は off、low、medium、high のいずれかです。';
  }

  @override
  String get thatIsntA => 'それはカスタムスタイルではありません。';

  @override
  String get vivid => '鮮やか';

  @override
  String get faded => '色あせ';

  @override
  String get warm => '暖色';

  @override
  String get natural => '自然';

  @override
  String get high => '高';

  @override
  String get medium => '中';

  @override
  String get low => '低';

  @override
  String get image => '画像';

  @override
  String get charcoal => 'チャコール';

  @override
  String get black => '黒';

  @override
  String get n43Fit => '4:3 フィット';

  @override
  String get n43Fill => '4:3 フィル';

  @override
  String get original => 'オリジナル';

  @override
  String get thisChannelIs => 'このチャンネルは放送休止中です';

  @override
  String get offAir => '放送休止';

  @override
  String get tail => '穴埋め';

  @override
  String get postRoll => '番組後';

  @override
  String get midRoll => '番組中';

  @override
  String get preRoll => '番組前';

  @override
  String get commercials => 'CM';

  @override
  String get bumpers => 'ジングル';

  @override
  String get pleaseStandBy => 'しばらくお待ちください';

  @override
  String get offTheAir => '放送休止中';

  @override
  String get wellBeRight => 'このあとすぐ';

  @override
  String upNextAt(Object at) {
    return '$at から次の番組';
  }

  @override
  String backOnThe(Object next, Object title) {
    return '$next に「$title」で放送再開';
  }

  @override
  String get processor => 'プロセッサー';

  @override
  String get graphicsCardNvenc => 'グラフィックカード（NVENC）';

  @override
  String get graphicsCardVaapi => 'グラフィックカード（VAAPI）';

  @override
  String get signInTo => 'チャンネルをエクスポートするには、TV でこのプロフィールにサインインしてください。';

  @override
  String get signInToThis => 'チャンネルをエクスポートするには、ここでこのプロフィールにサインインしてください。';

  @override
  String portIsIn(Object port) {
    return 'ポート $port は別のプログラムが使っています。別のポートを選んでから、Plex、Jellyfin、Emby のいずれかでも更新してください。';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'ポート $port は別のプロフィールがすでに使っています。';
  }

  @override
  String get pickAPort => '1024 から 65535 までのポートを選んでください。';

  @override
  String get movie => '映画';

  @override
  String backOnTheAir(Object start, Object title) {
    return '$start に「$title」で放送再開します。';
  }

  @override
  String get images => '画像';

  @override
  String get couldNotRead => 'その画像を読み込めませんでした。PNG、JPG、WebP、SVG を試してください。';

  @override
  String get thatFileIs => 'そのファイルは有効な SVG ではありません。';

  @override
  String get thatImageIs => 'その画像は 20 MB を超えています。もっと小さい画像を選んでください。';

  @override
  String get other => 'その他';

  @override
  String get seasonsHolidays => '季節・祝日';

  @override
  String get newsWeather => 'ニュース・天気';

  @override
  String get sports => 'スポーツ';

  @override
  String get genres => 'ジャンル';

  @override
  String get kidsFamily => 'キッズ・ファミリー';

  @override
  String get tvMovies => 'TV・映画';

  @override
  String get theServerWould => 'サーバーがこの項目を変換しませんでした。';

  @override
  String get theServerHas => 'サーバーにこの項目の再生できるバージョンがありません。';

  @override
  String get externalLabel => '外部';

  @override
  String get scanningChannelSources => 'チャンネルのソースをスキャン中…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl は Jellyfin サーバーとして応答しませんでした。';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return '$serverUrl に Jellyfin サーバーが見つかりません。$message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return '$path でサーバーエラー $statusCode が発生しました。';
  }

  @override
  String get wrongUsernameOr => 'ユーザー名かパスワードが違うか、セッションの有効期限が切れました。';

  @override
  String couldNotReach(Object e) {
    return 'サーバーに接続できませんでした（$e）。';
  }

  @override
  String get theServerTook => 'サーバーの応答に時間がかかりすぎました。';

  @override
  String get theServerWouldNot => 'サーバーがこのチャンネルを変換しませんでした。';

  @override
  String get musicVideo => 'ミュージックビデオ';

  @override
  String movie2(Object year) {
    return '映画 · $year';
  }

  @override
  String get commercial => 'CM';

  @override
  String couldntReachThe(Object what) {
    return '$whatに接続できませんでした';
  }

  @override
  String theIsToo(Object what) {
    return '$whatが大きすぎます';
  }

  @override
  String theSAddress(Object what) {
    return '$whatのアドレスが Web アドレスではありません';
  }

  @override
  String get noGuideInformation => '番組情報がありません';

  @override
  String get serverLiveTv => 'サーバーのライブ TV';

  @override
  String get theChannelHas => 'このチャンネルにはストリームのアドレスがありません。';

  @override
  String get couldntReadThe => '番組表を読み込めませんでした';

  @override
  String get couldntReachTheGuide => '番組表に接続できませんでした';

  @override
  String get theSourceHas => 'このソースにはプレイリストがありません';

  @override
  String get couldntReachThePlaylist => 'プレイリストに接続できませんでした';

  @override
  String get couldntReadThePlaylist => 'プレイリストのファイルを読み込めませんでした';

  @override
  String couldntRefresh(Object name) {
    return '$name を更新できませんでした';
  }

  @override
  String get thePlaylistHas => 'プレイリストにチャンネルがありません';

  @override
  String get thatIsntAn => 'M3U プレイリストではありません';

  @override
  String get thatIsntAnXmltv => 'XMLTV の番組表ではありません';

  @override
  String get theGuideIs => '番組表が大きすぎます（1 GB 超）';

  @override
  String get nightingaleTvBackups => 'Nightingale TV のバックアップ';

  @override
  String get uninstallingThisApp =>
      'このアプリをアンインストールすると、先にバックアップか移行をしない限り、プロフィール、チャンネル、設定が削除されます。';

  @override
  String theStoreVersion(Object officialName) {
    return 'Google Play 版は、別のアプリ「$officialName」としてこのアプリと並んでインストールされ、設定も別になります。14 日間は無料で、その後は 1 回の購入でプロジェクトを支援できます。インストール後は、ここから設定を移せます。';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Google Play と公式 Nightingale TV APK のアップデートは、このアプリに上書きでインストールされ、設定はそのまま残ります。自分でビルドした版は別のアプリ「$ownBuildName」としてインストールされ、ここから設定を移せます。';
  }

  @override
  String get yourOwnBuild => '自分でビルドした版';

  @override
  String get officialNightingaleTv => '公式 Nightingale TV APK';

  @override
  String get installedFromGoogle => 'Google Play からインストール';

  @override
  String get nightingaleTvOwn => 'Nightingale TV（自分でビルドした版）';

  @override
  String get sleepTimerOff => 'スリープタイマー オフ';

  @override
  String get sleepAtEnd => '番組の終わりにスリープ';

  @override
  String sleepInMin(Object minutes) {
    return '$minutes 分後にスリープ';
  }

  @override
  String get forced => '強制';

  @override
  String get unknownLanguage => '不明な言語';

  @override
  String didntStart(Object name) {
    return '$name が起動しませんでした';
  }

  @override
  String get thisDeviceCant => 'このデバイスではこのチャンネルの映像を再生できません';

  @override
  String get thisChannelsStream => 'このチャンネルのストリーム形式はこのデバイスでは使えません';

  @override
  String refusedTheStream(Object name) {
    return '$name がストリームを拒否しました。別のデバイスで再生中かもしれません。';
  }

  @override
  String yourAccountCant(Object server) {
    return 'あなたの $server アカウントではこのチャンネルを視聴できません';
  }

  @override
  String cantReach(Object name) {
    return '$name に接続できません';
  }

  @override
  String allOfS(Object server) {
    return '$server のチューナーがすべて使用中です';
  }

  @override
  String lostTheSignal(Object name) {
    return '$name の信号が途切れました';
  }

  @override
  String get couldntPlayThat => 'その部分を再生できませんでした。ライブに戻ります';

  @override
  String get backToLive => 'ライブに戻る';

  @override
  String get theServerTookToo => 'サーバーがこの番組の変換を始めるまでに時間がかかりすぎました。';

  @override
  String get nothingToPlay => 'このチャンネルで流すものがありません';

  @override
  String captionsOn(Object shown) {
    return '字幕オン：$shown';
  }

  @override
  String get captionsOn2 => '字幕オン';

  @override
  String get captionsOnNo => '字幕オン：この番組には字幕がありません';

  @override
  String get captionsOff => '字幕オフ';

  @override
  String get guest => 'ゲスト';

  @override
  String get thereHasTo => '大人のプロフィールが少なくとも 1 つ必要です。';

  @override
  String kidProfilesNeedPins(Object names) {
    return '子どものプロフィールがある間は、子どもが切り替えられないように、大人のプロフィールすべてに PIN が必要です。$names に PIN を設定してください。';
  }

  @override
  String get switchToAnother => 'このプロフィールを削除する前に、別のプロフィールに切り替えてください。';

  @override
  String get me => '自分';

  @override
  String get couldntOpenA => 'リモコン用のネットワークポートを開けませんでした。';

  @override
  String get notPaired => '未ペアリング';

  @override
  String get phone => 'スマートフォン';

  @override
  String get thatCodeDoesnt => 'コードが一致しません。TV に表示されたコードを確認してください。';

  @override
  String get openMenuPhone => 'ペアリングするには、TV で［メニュー］→［スマホリモコン］を開いてください';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'あなたの $serverName アカウントではライブ TV を視聴できません';
  }

  @override
  String get enterYourServer => 'サーバーのアドレスを入力してください。';

  @override
  String get needsSignIn => 'サインインが必要';

  @override
  String get cantBeReached => '接続できません';

  @override
  String isNotAnswering(Object name) {
    return '$name はどのアドレスでも応答しません。電源は入っていますか？';
  }

  @override
  String get everyServerOn => 'この Plex アカウントのサーバーは、すべてこのプロフィールに追加済みです。';

  @override
  String get thisPlexAccount =>
      'この Plex アカウントにはサーバーがありません。サーバーの所有者に共有を頼んでください。';

  @override
  String quickConnectStopped(Object message) {
    return 'Quick Connect が停止しました：$message';
  }

  @override
  String get enterYourUsername => 'ユーザー名を入力してください。';

  @override
  String get plexDidNot => 'Plex がユーザーを切り替えませんでした。';

  @override
  String plexTvError(Object statusCode) {
    return 'plex.tv エラー $statusCode。';
  }

  @override
  String get yourPlexSign => 'Plex のサインインの有効期限が切れました。';

  @override
  String couldNotReachPlex(Object e) {
    return 'plex.tv に接続できませんでした（$e）。';
  }

  @override
  String get plexTvTook => 'plex.tv の応答に時間がかかりすぎました。';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — $ownerName が共有';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'サーバーがこの項目を変換しませんでした（$transcodeDecisionText）。';
  }

  @override
  String get theServerHasNo => 'サーバーにこの項目のファイルがありません。ライブラリを更新してください。';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl は Plex サーバーとして応答しませんでした。';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return '$serverUrl に Plex サーバーが見つかりません。$message';
  }

  @override
  String get thePlexSign => 'Plex のサインインの有効期限が切れました。';

  @override
  String channelIsNot(Object channelId) {
    return 'チャンネル $channelId はどの DVR にもありません。';
  }

  @override
  String get noSuchUser => 'そのユーザーは存在しません。';

  @override
  String get yourCurrentPassword => '現在のパスワードが違います。';

  @override
  String get signInFirst => '先にサインインしてください。';

  @override
  String thereIsAlready(Object name) {
    return '$name という名前のユーザーはすでにいます。';
  }

  @override
  String get thisAccountIs => 'このアカウントはオフになっています。';

  @override
  String get chooseAnAdmin => '管理者アカウントを選んでください。';

  @override
  String useAtMost(Object maxNameLength) {
    return 'ユーザー名は $maxNameLength 文字以内にしてください。';
  }

  @override
  String get enterAUser => 'ユーザー名を入力してください。';

  @override
  String useAtLeast(Object minPasswordLength) {
    return '$minPasswordLength 文字以上にしてください。';
  }

  @override
  String get tooManyWrong => 'パスワードの間違いが多すぎます。1 分後にもう一度お試しください。';

  @override
  String get wrongUserName => 'ユーザー名かパスワードが違います。';

  @override
  String get openTheSetup => 'サーバーのログにあるセットアップ用リンクを開いてください。';

  @override
  String get makeSomeoneElse => '先に別の人を管理者にしてください。';

  @override
  String get noSuchProfile => 'そのプロフィールは存在しません。';

  @override
  String get onlyAnAdmin => 'その操作は管理者だけができます。';

  @override
  String get thatProfileIsnt => 'そのプロフィールはあなたに割り当てられていません。';

  @override
  String get enterAGrown => '子どものプロフィールの設定を変えるには、大人の PIN を入力してください。';

  @override
  String get enterThisProfiles => 'このプロフィールの PIN を入力してください。';

  @override
  String get reloadThePage => 'ページを再読み込みして、もう一度お試しください。';

  @override
  String somethingWentWrong(Object e) {
    return '問題が発生しました：$e';
  }

  @override
  String get signInToThisProfile => '先にこのプロフィールにサインインしてください。';

  @override
  String get changedInAnother => '別のウィンドウで変更されました。最新の内容を表示しています。';

  @override
  String get wrongPin => 'PIN が違います。';

  @override
  String get tooManyWrongPins => 'PIN の間違いが多すぎます。1 分後にもう一度お試しください。';

  @override
  String get theRoleIs => '役割は「admin」か「user」です。';

  @override
  String get noSuchBackup => 'そのバックアップは存在しません。';

  @override
  String get backupsAreOff => 'バックアップはオフです。';

  @override
  String get noSuchEncoder => 'そのエンコーダーは存在しません。';

  @override
  String get allow1To => 'ストリーム数は 1〜16 にしてください。';

  @override
  String get noSuchQuality => 'その画質は存在しません。';

  @override
  String get processorOnly => 'プロセッサーのみ';

  @override
  String get liveTvExport => 'ライブ TV エクスポートは動作していません。';

  @override
  String get thoseArentPremiere => 'それはプレミア設定ではありません。';

  @override
  String get theLogoMode => 'ロゴの表示は always、nowAndThen、off のいずれかです。';

  @override
  String get thatIsntAPicture => 'それはカスタムロゴのフォルダーにある画像ではありません。';

  @override
  String couldntSaveBackupNothingReset(Object e) {
    return '先にバックアップを保存できなかったので、何もリセットしていません：$e';
  }

  @override
  String get theKindIs => '種類は「block」、「music」、「custom」のいずれかです。';

  @override
  String get thatIsntAPlay => 'それは再生順ではありません。';

  @override
  String get musicChannelsOnly => '音楽チャンネルはシャッフル再生だけです。';

  @override
  String get channelNumbersStart => 'チャンネル番号は 1 から始まります。';

  @override
  String get slotLengthsAre => '放送枠の長さは 15、30、60、90、120 分のいずれかです。';

  @override
  String get thatIsntAChannel => 'それはチャンネルではありません。';

  @override
  String get noSuchChannel => 'そのチャンネルは存在しません。';

  @override
  String get thatPictureIs => 'その画像は大きすぎます（最大 5 MB）。';

  @override
  String get unknownAction => '不明な操作です。';

  @override
  String get noSuchServer => 'そのサーバーは存在しません。';

  @override
  String get startSigningIn => '先にサインインを始めてください。';

  @override
  String get aRestoreIs => 'すでに復元を実行中です。';

  @override
  String get uploadTheBackup => 'バックアップをもう一度アップロードしてください。';

  @override
  String get discoveryIsOff =>
      '検出がオフなので、チューナーはアドレスで追加してください。オンにするには、コンテナーをホストネットワークで実行してください。';

  @override
  String get sendKeys => 'キーを送信してください。';

  @override
  String get enterThePlaylists => 'プレイリストのアドレスを入力するか、プレイリストのファイルを選んでください';

  @override
  String get uploadTheFile => 'ファイルをもう一度アップロードしてください。';

  @override
  String get kidProfilesGet => '子どものプロフィールにはライブチャンネルはありません。';

  @override
  String liveTvIsAlready(Object name) {
    return '$name ライブ TV はすでに追加されています';
  }

  @override
  String get noSuchSource => 'そのソースは存在しません。';

  @override
  String get thatFileIsToo => 'そのファイルは大きすぎます（最大 32 MB）。';

  @override
  String get aPinIs => 'PIN は 4 桁の数字です。';

  @override
  String get noSuchRating => 'そのレーティングは存在しません。';

  @override
  String get noSuchKind => 'その種類は存在しません。';

  @override
  String get onlyAnAdminCan => 'それを変えられるのは管理者だけです。';

  @override
  String shouldBeA(Object key) {
    return '「$key」はテキストのリストにしてください。';
  }

  @override
  String shouldBeAn(Object key) {
    return '「$key」はオブジェクトにしてください。';
  }

  @override
  String shouldBeTrue(Object key) {
    return '「$key」は true か false にしてください。';
  }

  @override
  String shouldBeANumber(Object key) {
    return '「$key」は数値にしてください。';
  }

  @override
  String shouldBeText(Object key) {
    return '「$key」はテキストにしてください。';
  }

  @override
  String get expectedAJson => 'JSON オブジェクトが必要です。';

  @override
  String get thatIsToo => '一度に送る量が多すぎます。';

  @override
  String get aQualityLimit => '画質の上限は 500 kbps 以上です。';

  @override
  String get orderShouldName => '「order」にはすべてのサーバーを 1 回ずつ入れてください。';

  @override
  String get orderIsMissing => '「order」がありません。';

  @override
  String get signOutOf => 'メインサーバーを変えるには、プロフィールからサインアウトしてください。';

  @override
  String get thoseArentPool => 'それはグループのフォルダーではありません。';

  @override
  String get sendRoots => 'ルートを送信してください。';

  @override
  String get thatIsntAPool => 'それはグループの種類ではありません。';

  @override
  String get giveThePool => 'グループに名前を付けてください。';

  @override
  String get liveChannelsHave => 'ライブチャンネルには CM 枠がありません。';

  @override
  String get sendAPlan => 'プランを送信してください。';

  @override
  String get thatIsntABreak => 'それは CM 枠のプランではありません。';

  @override
  String get noSuchPool => 'そのグループは存在しません。';

  @override
  String get thatIsntAProgramming => 'それは番組枠ではありません。';

  @override
  String get noSuchBlock => 'その番組枠は存在しません。';

  @override
  String get sendEveryTab => 'すべてのタブを 1 回ずつ送信してください。';

  @override
  String get sendChannelids => 'channelIds を送信してください。';

  @override
  String get giveTheGroup => 'グループに名前を付けてください。';

  @override
  String get noSuchGroup => 'そのグループは存在しません。';

  @override
  String get restoringBringsBack =>
      '復元すると、プロフィール、チャンネル、番組枠、設定が元に戻ります。各プロフィールは一度だけサーバーにサインインします。';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels チャンネル',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup => 'このデバイスに設定のバックアップがあります：';

  @override
  String get welcomeBack => 'おかえりなさい';

  @override
  String get moveOkSelect => '◀▶ 移動    OK 選択';

  @override
  String get startFresh => '最初から始める';

  @override
  String get restoreIt => '復元する';

  @override
  String get couldntRestore => '復元できませんでした';

  @override
  String get cancel => 'キャンセル';

  @override
  String get useYourPhone => 'スマートフォンかパソコンを使う';

  @override
  String get openABackup => 'バックアップファイルを開く';

  @override
  String get setUpThis =>
      'Nightingale TV のバックアップからこの TV を設定します：プロフィール、チャンネル、番組枠、設定。各プロフィールは一度だけサーバーにサインインします。';

  @override
  String get restoreFromA => 'バックアップから復元';

  @override
  String get close => '閉じる';

  @override
  String get thereYouCan =>
      'そこでこの TV のバックアップをダウンロードしたり、ここで復元するバックアップを送ったりできます。送られたものは、まずこの TV で確認します。このウィンドウを閉じるとページも閉じます。';

  @override
  String get onAPhone =>
      'この TV と同じ Wi-Fi につながったスマートフォン、タブレット、パソコンでコードを読み取るか、次を開いてください：';

  @override
  String get couldntOpenANetwork => 'ページ用のネットワークポートを開けませんでした。';

  @override
  String get thePageStopped => '15 分間操作がなかったため、ページを停止しました。これを閉じて、もう一度開いてください。';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCountと$last';
  }

  @override
  String get listSeparator => '、';

  @override
  String labelValue(Object label, Object value) {
    return '$label：$value';
  }

  @override
  String get restore => '復元';

  @override
  String get liveTvExportMoves =>
      'ライブ TV エクスポートはこのデバイスに移ります。古いデバイスではオフにしてください。';

  @override
  String willNeedTo(Object need) {
    return '$need はもう一度サーバーにサインインする必要があります。';
  }

  @override
  String get itSetsUp => 'バックアップの内容どおりにこの TV を設定します。';

  @override
  String get itReplacesEverything => 'この TV の内容をすべて置き換えます。現在の設定は先にバックアップされます。';

  @override
  String restoreTheBackup(Object toLocal) {
    return '$toLocal のバックアップを復元しますか？';
  }

  @override
  String get delete => '削除';

  @override
  String get saveToFile => 'ファイルに保存';

  @override
  String get moveOkSelectEsc => '▲▼◀▶ 移動    OK 選択    ESC 戻る';

  @override
  String get backupRestore => 'バックアップと復元';

  @override
  String get aBackupHolds =>
      'バックアップには、すべてのプロフィールとそのチャンネル、番組枠、CM、設定が含まれます。変更があるたびに最新の状態に保たれます。サインインのパスワードは含まれません。';

  @override
  String couldntSaveThe(Object e) {
    return 'バックアップを保存できませんでした：$e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'うまくいきませんでした：$e';
  }

  @override
  String get aNewChannel => '新しいチャンネルは、夜に放送を終える局のように、番組枠の外では放送休止になります。';

  @override
  String get aNewChannelJust => 'この番組枠専用の新しいチャンネル';

  @override
  String get moveOkChoose => '▲▼ 移動    OK 選ぶ    ESC 戻る';

  @override
  String get chooseAChannel2 => 'チャンネルを選ぶ';

  @override
  String episodes(Object keyCount) {
    return '$keyCount エピソード';
  }

  @override
  String get moveOkAdd => '▲▼ 移動    OK 追加    ESC 戻る';

  @override
  String get addAShow2 => '番組を追加';

  @override
  String get remove => '削除';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count エピソード',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ 月';

  @override
  String get day => '+ 日';

  @override
  String get day2 => '− 日';

  @override
  String get month2 => '− 月';

  @override
  String get save => '保存';

  @override
  String get everyDay => '毎日';

  @override
  String get weekends => '週末';

  @override
  String get weekdays => '平日';

  @override
  String get days => '曜日';

  @override
  String get starts => '開始';

  @override
  String get time => '時刻';

  @override
  String get premieresAreOff => '初回放送はオフ';

  @override
  String get premieresAreOn => '初回放送はオン';

  @override
  String get onTheAir => '放送中';

  @override
  String get episodesAddedTo =>
      'この 2 週間にサーバーに追加されたエピソードは、その番組のチャンネルの夜の枠で初回放送されます。毎晩、番組ごとに新しいエピソードを 1 本、最大 2 時間まで流し、NEW の印を付けます。番組枠が優先されます。';

  @override
  String get moveOkSelectEscCancel => '▲▼◀▶ 移動    OK 選択    ESC キャンセル';

  @override
  String get newEpisodePremieres => '新エピソードの初回放送';

  @override
  String get theChannelGoes => 'この時間になると、チャンネルは通常の番組に戻ります。';

  @override
  String delete2(Object title) {
    return '「$title」を削除しますか？';
  }

  @override
  String get addAnotherShow => '別の番組を追加';

  @override
  String get missingShow => '見つからない番組';

  @override
  String runsThenStarts(Object start) {
    return '$start 流して、また最初から始めます。';
  }

  @override
  String get fillsTheBlock => '番組枠を埋めます。';

  @override
  String longerThanThe(Object end, Object title) {
    return '番組枠より長いため、$end に終わり、$title が途中で切れます。';
  }

  @override
  String get onTheAirNow => 'ただいま放送中';

  @override
  String nextAiring(Object start) {
    return '次回放送 · $start';
  }

  @override
  String inAll(Object runtime) {
    return '合計 $runtime';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '映画 $movies 本',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount 番組',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => 'まだ何もありません。番組か映画を選んでください。';

  @override
  String get nothingYetAdd => 'まだ何もありません。ラインナップに番組を追加してください。';

  @override
  String get plays => '流す内容';

  @override
  String onLabel(Object number, Object name) {
    return '$number $name で放送';
  }

  @override
  String get noChannelChosen => 'チャンネルが選ばれていません';

  @override
  String get onANew => '新しいチャンネルで（それ以外の時間は放送休止）';

  @override
  String get untitledBlock => '無題の番組枠';

  @override
  String get deleteBlock => '番組枠を削除';

  @override
  String get blockIsOff => '番組枠はオフ';

  @override
  String get blockIsOn => '番組枠はオン';

  @override
  String get onlyShowsAnd => 'このレーティング以上の番組と映画だけを流します。レーティングのないものは除きます。';

  @override
  String get anyRating => 'すべてのレーティング';

  @override
  String get minimumRating => '最低レーティング';

  @override
  String get chooseShowsMovies => '番組と映画を選ぶ';

  @override
  String get showsAndMovies => '選んだ番組と映画を、順番どおりかシャッフルで流します。';

  @override
  String get yourShowsIn =>
      '番組をこの順番で、放送のたびに次のエピソードを流します。時間が余ったら、ラインナップを最初からもう一度流します。';

  @override
  String get aLineup => 'ラインナップ';

  @override
  String get aMix => 'ミックス';

  @override
  String get whatItPlays => '流す内容';

  @override
  String get repeatsEveryYear => '毎年くり返します。';

  @override
  String get to => '終了日';

  @override
  String get from => '開始日';

  @override
  String get onlyBetweenDates => '期間限定';

  @override
  String get allYear => '通年';

  @override
  String get dates => '期間';

  @override
  String get nextDay => '（翌日）';

  @override
  String get ends => '終了';

  @override
  String get channel => 'チャンネル';

  @override
  String get saturdayMorningCartoons => '土曜朝のアニメ';

  @override
  String get title => 'タイトル';

  @override
  String get newProgrammingBlock => '新しい番組枠';

  @override
  String get newLateNight => '新しい深夜枠';

  @override
  String get editProgrammingBlock => '番組枠を編集';

  @override
  String next(Object next, Object next2) {
    return '次回：$next $next2';
  }

  @override
  String get onTheAirNow2 => 'ただいま放送中';

  @override
  String get noUpcomingAirings => '今後の放送予定はありません';

  @override
  String get itsChannelIs => 'チャンネルがなくなりました。新しいチャンネルを選んでください。';

  @override
  String get turnedOff => 'オフ';

  @override
  String get blocksTakeOver =>
      '番組枠は、土曜朝のアニメのように、選んだ曜日と時間にチャンネルを引き継ぎます。放送のたびに前回の続きから流します。';

  @override
  String get moveOkEdit => '▲▼ 移動    OK 編集    ESC 戻る';

  @override
  String get programmingBlocks => '番組枠';

  @override
  String get newlyAddedEpisodes => '新しく追加されたエピソードを、その番組のチャンネルで';

  @override
  String get onLabel2 => 'オン';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips 本',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => '100 分の映画';

  @override
  String get n44MinDrama => '44 分のドラマ';

  @override
  String get n22MinSitcom => '22 分のコメディ';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: '、番組中の CM 枠 $midCount 回',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name：CM 枠なし';
  }

  @override
  String get openAndClose => 'CM 枠の始めと終わりに、ジングルに設定したグループから';

  @override
  String get bumpers2 => 'ジングル';

  @override
  String get toTheHalf => '30 分単位まで';

  @override
  String get toTheHour => '1 時間単位まで';

  @override
  String get padsEachSlot => '各放送枠を時刻に合わせて埋め、番組が時間どおりに始まるようにします';

  @override
  String get tail2 => '穴埋め';

  @override
  String get afterEachProgram => '各番組の後';

  @override
  String get postRoll2 => '番組後';

  @override
  String get length => '長さ';

  @override
  String get every => '間隔';

  @override
  String min(Object inMinutes) {
    return '$inMinutes 分';
  }

  @override
  String get breaksInsideShows => '番組や映画の途中の CM 枠。場面の区切りが見つかればそこに入れます';

  @override
  String get midRoll2 => '番組中';

  @override
  String get beforeEachProgram => '各番組の前';

  @override
  String get preRoll2 => '番組前';

  @override
  String get onePool => '1 つのグループ…';

  @override
  String get allBumperPools => 'すべてのジングルのグループ';

  @override
  String get none => 'なし';

  @override
  String clipsFrom(Object pool) {
    return 'クリップの取得元：$pool';
  }

  @override
  String get allPools => 'すべてのグループ';

  @override
  String clips2(Object label) {
    return '$labelのクリップ';
  }

  @override
  String get leave => '移動する';

  @override
  String get yourChangesTo => 'CM 枠の設定の変更は失われます。';

  @override
  String get leaveWithoutSaving => '保存せずに移動しますか？';

  @override
  String get size => 'サイズ';

  @override
  String get captions => '字幕';

  @override
  String get sampleCaption => '字幕のサンプル';

  @override
  String get theServerDraws => 'この字幕はサーバーが映像に描き込むため、ここではサイズを変えられません。';

  @override
  String get findingSubtitles => '字幕を探しています…';

  @override
  String get noSubtitlesFor => 'この番組には字幕がありません';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours 時間 $inMinutes 分';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed 日';
  }

  @override
  String get theChannelGoesAway => 'チャンネルは、その番組枠やチャンネルグループ内の位置と一緒になくなります。';

  @override
  String remove2(Object name) {
    return '「$name」を削除しますか？';
  }

  @override
  String contentOf(Object name) {
    return '$name の内容';
  }

  @override
  String get newChannel => '新しいチャンネル';

  @override
  String get defaultCard => '標準のカード';

  @override
  String get changeOfflineImage => 'オフライン画像を変更…';

  @override
  String get offlineImage2 => 'オフライン画像…';

  @override
  String fillerPool(Object poolName) {
    return '穴埋めのグループ：$poolName';
  }

  @override
  String get slotLength => '放送枠の長さ';

  @override
  String get hideFromGuide => '番組表に表示しない';

  @override
  String get showInGuide => '番組表に表示';

  @override
  String get favorite => 'お気に入り';

  @override
  String get unfavorite => 'お気に入りから外す';

  @override
  String mainSetting(Object label) {
    return '全体の設定（$label）';
  }

  @override
  String get channelLogo => 'チャンネルロゴ';

  @override
  String breaksOn(Object name) {
    return '$name の CM 枠';
  }

  @override
  String get custom2 => 'カスタム…';

  @override
  String get commercials2 => 'CM';

  @override
  String get removeChannel => 'チャンネルを削除';

  @override
  String get reshuffle => 'シャッフルし直す';

  @override
  String get editContent => '内容を編集';

  @override
  String get number => '番号 +';

  @override
  String get number2 => '番号 −';

  @override
  String get sourcesLogo => 'ソースのロゴ';

  @override
  String get changeIcon => 'アイコンを変更';

  @override
  String get rename => '名前を変更';

  @override
  String get channelName => 'チャンネル名';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '番組枠 $blockCount 件',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return '$loop ごとにくり返し';
  }

  @override
  String programs(Object playlistCount) {
    return '$playlistCount 番組';
  }

  @override
  String get programmingBlocksOnly => '番組枠のみ';

  @override
  String channelThere(Object n) {
    return 'そのチャンネル $n';
  }

  @override
  String channel2(Object number) {
    return 'チャンネル $number';
  }

  @override
  String get noChannelsYet => 'チャンネルはまだありません';

  @override
  String get guideRange => '番組表の範囲';

  @override
  String get channelsEditOk => '▲▼ チャンネル    ▶ 編集    OK 選択    ESC 戻る';

  @override
  String get channelsIcons => 'チャンネルとアイコン';

  @override
  String get howFarAhead => '番組表に今から何時間先まで表示するか。';

  @override
  String hours(Object hours) {
    return '$hours 時間';
  }

  @override
  String get theChannelLogo => 'TV とライブ TV エクスポートで、映像の隅に表示するチャンネルロゴ。';

  @override
  String get name => '名前';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'チャンネル';

  @override
  String get groupName => 'グループ名';

  @override
  String group(Object name) {
    return 'グループ：$name';
  }

  @override
  String get deleteGroup => 'グループを削除';

  @override
  String get itsTabLeaves => 'このグループのタブは番組表からなくなります。チャンネルはラインナップに残ります。';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount チャンネル',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => '自分で選んだチャンネル。';

  @override
  String get theTabsAt => '番組表の上部のタブを、この順番で表示します。非表示のタブとチャンネルのないタブは表示しません。';

  @override
  String get channelGroups => 'チャンネルグループ';

  @override
  String get shown => '表示';

  @override
  String get down => '下へ';

  @override
  String get up => '上へ';

  @override
  String get automatic2 => '· 自動';

  @override
  String channels4(Object channelIdsCount) {
    return '· $channelIdsCount チャンネル';
  }

  @override
  String get create => '作成';

  @override
  String get commercialsNeverShow => 'CM はサーバーの視聴履歴に残りません。';

  @override
  String get theSameAds => '同じ CM が、誰にでも毎回流れます。';

  @override
  String get bumperPoolsClips => 'ジングルのグループのクリップは CM 枠の始めと終わりに流れ、CM としては流れません。';

  @override
  String get howBreaksWork => 'CM 枠のしくみ';

  @override
  String get withATail => '穴埋めを使うと、放送枠が時刻に合うように埋められます。';

  @override
  String get adsShrinkTo => 'CM は放送枠に収まるよう短くなり、1 回の CM 枠は 5 分を超えません。';

  @override
  String get aShortBreak =>
      '番組の前に短い CM 枠、番組中は 10 分ごと（映画は 12 分ごと）に場面の区切りが見つかればそこで CM 枠を入れ、残りは番組の後に流します。';

  @override
  String get pickAutomaticFor =>
      'テレビ放送のような CM 枠なら［自動］、自分で設定するなら［カスタム］を選んでください。';

  @override
  String workingOn(Object current) {
    return '$current を処理中…';
  }

  @override
  String get analysis => '解析';

  @override
  String couldNotBe(Object failed) {
    return '$failed は解析できませんでした（ファイルが変わるともう一度試します）';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'CM 枠の位置がわかった番組：$programsDone / $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return '分割した長い動画：$reelsDone / $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders フォルダー  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: 'CM のグループ $used 個から $clips。',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'グループにクリップが入ると CM 枠が始まります。動画のあるフォルダーをグループに追加してください。';

  @override
  String get breaksStartOnceA => 'グループにクリップが入ると CM 枠が始まります。いま長い動画を分割しています。';

  @override
  String get breaksStartOnceAPool =>
      'グループにクリップが入ると CM 枠が始まります。下でグループを作成してください。';

  @override
  String breaksAreOff(Object clips) {
    return 'CM 枠はオフです。グループに $clipsがあります。';
  }

  @override
  String get breaksAreOff2 => 'CM 枠はオフです。';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 本のクリップ',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return '前回のスキャンに失敗しました：$syncError';
  }

  @override
  String get newPool => '新しいグループ';

  @override
  String get pickTheFolders =>
      'サーバーで CM とジングルが入っているフォルダーを選んでください。そこの動画は通常のチャンネルから外れ、代わりに CM 枠を埋めます。グループの種類を［ジングル］にすると、そのクリップが CM 枠の始めと終わりに流れます。';

  @override
  String get pools => 'グループ';

  @override
  String get breakSettings => 'CM 枠の設定…';

  @override
  String get commercialBreaks => 'CM 枠';

  @override
  String get breakSettings2 => 'CM 枠の設定';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$countこれがあると、CM 枠の位置もより自然になります。';
  }

  @override
  String waiting(Object waiting) {
    return '（$waiting 件待機中）。';
  }

  @override
  String get fullStop => '。';

  @override
  String get longCommercialVideos => 'チャプターのない長い CM 動画は、このデバイスでは分割できません';

  @override
  String get installFfmpegTo => '長い CM 動画を分割するには ffmpeg をインストールしてください';

  @override
  String get picturesOnThis => 'このデバイスにある画像（新しい順）。大きな画像は 512 px に縮小します。';

  @override
  String get noPicturesOn =>
      'このデバイスにはまだ画像がありません。PNG か JPG をダウンロードフォルダーか USB ドライブにコピーしてから、もう一度お試しください。';

  @override
  String get lookingForPictures => '画像を探しています…';

  @override
  String get couldntReadThePictures => 'このデバイスの画像を読み込めませんでした。';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV にはこのデバイスの画像を見る権限がありません。Android の［設定］›［アプリ］›［Nightingale TV］›［権限］で「写真と動画」を許可してから、もう一度お試しください。';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ 移動    OK 選ぶ    ESC キャンセル';

  @override
  String get chooseAPicture => '画像を選ぶ';

  @override
  String thePoolHasnt(Object error) {
    return '$error  グループは変更されていません。';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  何も変更されていません。';
  }

  @override
  String get couldntReachTheServer => 'サーバーに接続できませんでした';

  @override
  String get tryAgain => '再試行';

  @override
  String get nothingInside => '中身がありません';

  @override
  String get noMovies => '映画がありません';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount 件';
  }

  @override
  String get video => '動画';

  @override
  String collection(Object name) {
    return '$name（コレクション）';
  }

  @override
  String get included => '含める';

  @override
  String get nothingInside2 => '中身がありません。';

  @override
  String get loadingFolders => 'フォルダーを読み込み中…';

  @override
  String get pressOnA => 'ライブラリで ▶ を押すと中身が見られます。';

  @override
  String get done => '完了';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount 件選択';
  }

  @override
  String get nothingTickedYet =>
      'まだ何も選んでいません。ライブラリ全体を使うならチェックを付け、中身を選ぶなら ▶ を押してください。';

  @override
  String get wholeLibrary => 'ライブラリ全体';

  @override
  String get libraries => 'ライブラリ';

  @override
  String get loadingLibraries => 'ライブラリを読み込み中…';

  @override
  String get moveOkTick => '▲▼ 移動    OK チェック    ▶ 開く    ◀ 上へ    ESC キャンセル';

  @override
  String foldersFor(Object poolName) {
    return '$poolName のフォルダー';
  }

  @override
  String get chooseFolders => 'フォルダーを選ぶ';

  @override
  String get chooseWhatPlays => 'このチャンネルで流すものを選ぶ';

  @override
  String get endsEarly => '途中で終了';

  @override
  String get madeFromThis =>
      'このチャンネルの番組と映画から作られ、ライブラリに合わせて更新されます。何かを変えると、自分のものになります。';

  @override
  String get fromTheLineup => 'ラインナップから';

  @override
  String yesterday(Object t) {
    return '昨日 $t';
  }

  @override
  String today(Object t) {
    return '今日 $t';
  }

  @override
  String behind(Object d) {
    return '$d 遅れ';
  }

  @override
  String hr(Object h) {
    return '$h 時間';
  }

  @override
  String get underAMinute => '1 分未満';

  @override
  String get noProgramming => '番組なし';

  @override
  String get today2 => '今日';

  @override
  String get tuning => '選局中…';

  @override
  String get offAir2 => '放送休止';

  @override
  String get noSignal => '信号なし';

  @override
  String left(Object now) {
    return '残り $now';
  }

  @override
  String get nothingScheduled => '予定なし';

  @override
  String get back => '戻る';

  @override
  String get sleep => 'スリープ';

  @override
  String get menu => 'メニュー';

  @override
  String get nightingaleTvGuide => 'NIGHTINGALE TV 番組表';

  @override
  String nowPlaying(Object title) {
    return '再生中：$title';
  }

  @override
  String get mMenu => 'M メニュー';

  @override
  String get escBackTo => 'ESC TV に戻る';

  @override
  String get channelsTabsTime => '▲▼ チャンネル     ▲ タブ     ◀▶ 時刻     OK 視聴     ';

  @override
  String get color => '色';

  @override
  String get channelsUsingIt => 'これを使っているチャンネルは標準のアイコンに戻ります。';

  @override
  String get deleteThisIcon => 'このアイコンを削除しますか？';

  @override
  String get uploadImage => '画像をアップロード…';

  @override
  String get pngJpgWebp => 'PNG、JPG、WebP、GIF、SVG。大きな画像は自動的に 512 px に縮小します。';

  @override
  String get genericBadgesOnly =>
      '汎用のバッジだけです。実際の放送局のロゴは「マイアイコン」からアップロードしてください。';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'このバッジを使う';

  @override
  String get preview => 'プレビュー';

  @override
  String get shape => '形';

  @override
  String get callLettersUp => '局名の略称（5 文字まで）';

  @override
  String iconFor(Object name) {
    return '$name のアイコン';
  }

  @override
  String get couldntReadThat => 'その画像を読み込めませんでした。別の画像を試してください。';

  @override
  String get myIcons => 'マイアイコン';

  @override
  String get showLogos => 'ロゴを表示';

  @override
  String get badges => 'バッジ';

  @override
  String get builtIn => '内蔵';

  @override
  String get couldntMoveThe => '設定を移せませんでした';

  @override
  String get send => '送る';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'プロフィール、チャンネル、設定を今バックアップして $counterpartName で開きます。$counterpartName は復元する前に確認します。こちらでは何も変わりません。';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return '設定を $counterpartName に送りますか？';
  }

  @override
  String get parentalControls => '保護者による制限';

  @override
  String get notNow => '今はしない';

  @override
  String bringMySetup(Object counterpartName) {
    return '$counterpartName から設定をこちらに持ってくる';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return '設定を $counterpartName に移す';
  }

  @override
  String get uninstallingEitherOne =>
      '残したい設定を移す前にどちらかをアンインストールすると、その設定は削除されます。';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName と $counterpartName は別々のアプリで、それぞれにプロフィール、チャンネル、設定があります。';
  }

  @override
  String get thankYouFor => 'Nightingale TV を支援していただきありがとうございます！';

  @override
  String isAlsoOn(Object counterpartName) {
    return 'このデバイスには $counterpartName もあります';
  }

  @override
  String get aboutThisInstall => 'このインストールについて';

  @override
  String couldntOpen(Object counterpartName) {
    return '$counterpartName を開けませんでした。';
  }

  @override
  String get nothingIsSet => 'ここはまだ何も設定されていないので、移す設定がありません。';

  @override
  String yourSetupIs(Object counterpartName) {
    return '設定を $counterpartName に送っています';
  }

  @override
  String get guide => '番組表';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n / $keysCount';
  }

  @override
  String get saving => '保存中…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$total 件中 $_checkedCount 件を選択';
  }

  @override
  String get channelOrGroup => 'チャンネル名またはグループ名';

  @override
  String get search => '検索';

  @override
  String get moveOkCheck => '▲▼ 移動    OK チェック    ESC 戻る';

  @override
  String chooseChannels(Object name) {
    return 'チャンネルを選ぶ：$name';
  }

  @override
  String get add => '追加';

  @override
  String get readingThePlaylist => 'プレイリストを読み込み中…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return '現在：プレイリストの番組表、$guideUrl';
  }

  @override
  String get leaveEmptyTo => '空欄にすると、プレイリストが指定する番組表を使います';

  @override
  String get xmltvGuideAddress => 'XMLTV 番組表のアドレス';

  @override
  String get guideOptional => '番組表（任意）';

  @override
  String get httpProviderExample =>
      'http://provider.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'プレイリストのアドレス';

  @override
  String get playlist => 'プレイリスト';

  @override
  String get myIptv => 'マイ IPTV';

  @override
  String get useAnAddress => 'アドレスを使う';

  @override
  String get chooseAFile => 'ファイルを選ぶ';

  @override
  String get chooseAnotherFile => '別のファイルを選ぶ';

  @override
  String get moveOkSelectEscBack => '▲▼ 移動    OK 選択    ESC 戻る';

  @override
  String edit(Object name) {
    return '$name を編集';
  }

  @override
  String get addAnM3u => 'M3U プレイリストを追加';

  @override
  String get m3uPlaylists => 'M3U プレイリスト';

  @override
  String get xmltvGuides => 'XMLTV 番組表';

  @override
  String get anIptvPlaylist => 'IPTV のプレイリスト（Web アドレスかファイル）と、あれば XMLTV の番組表。';

  @override
  String get theChannelsAnd => 'サーバーのチューナー（アンテナ、ケーブルボックス、IPTV）のチャンネルと番組表。';

  @override
  String readingSChannels(Object server) {
    return '$server のチャンネルを読み込み中…';
  }

  @override
  String checkingLiveTv(Object server) {
    return '$server のライブ TV を確認中…';
  }

  @override
  String get addALive => 'ライブ TV のソースを追加';

  @override
  String get itsChannelsLeave => 'このソースのチャンネルは、番組表、グループ、お気に入りからなくなります。';

  @override
  String get renameSource => 'ソースの名前を変更';

  @override
  String get edit2 => '編集';

  @override
  String get refreshNow => '今すぐ更新';

  @override
  String get chooseChannels2 => 'チャンネルを選ぶ';

  @override
  String get playlistFile => 'プレイリストのファイル';

  @override
  String get notRefreshedYet => 'まだ更新していません';

  @override
  String refreshed(Object lastRefresh) {
    return '$lastRefresh に更新';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return '前回の更新に失敗しました：$lastError';
  }

  @override
  String get refreshing => '更新中…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · $channelsCount チャンネル中 $keyCount';
  }

  @override
  String get noSourcesYet => 'ソースはまだありません。';

  @override
  String get addSource => 'ソースを追加';

  @override
  String get realBroadcastsAnd =>
      '実際の放送や IPTV を番組表に：サーバーのライブ TV か、XMLTV 番組表付きの M3U プレイリスト。それらのチャンネルは自分のチャンネルの後に並びます。';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return '配信していません。$streamLimit ストリーム中 $runningCount を使用中。';
  }

  @override
  String get savePort => 'ポートを保存';

  @override
  String get port => 'ポート';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'チューナー';

  @override
  String get enterAPort => 'ポート番号を入力してください。';

  @override
  String pinFor(Object name) {
    return '$name の PIN';
  }

  @override
  String get letPlexFind => 'Plex に自動で見つけさせる';

  @override
  String get discovery => '検出';

  @override
  String get encoder => 'エンコーダー';

  @override
  String nowAtOnce(Object streamLimit) {
    return '現在：同時に $streamLimit。ほかの場所で視聴中のチャンネル 1 つが 1 ストリームです。';
  }

  @override
  String get streamsAtOnce => '同時ストリーム数';

  @override
  String get quality => '画質';

  @override
  String get lineups => 'ラインナップ';

  @override
  String get liveTvExport2 => 'ライブ TV エクスポート';

  @override
  String get automaticDiscoveryIsnt =>
      'この PC では自動検出を使えません。Plex、Jellyfin、Emby のいずれかでアドレスを指定してチューナーを追加してください。';

  @override
  String get anyoneOnYour => '自宅のネットワークにいる人なら誰でもこのラインナップを視聴できます。';

  @override
  String get watchYourChannels =>
      '自宅のネットワーク上の Plex、Jellyfin、Emby、IPTV アプリでチャンネルを視聴できます。再生するには Nightingale TV を開いたままにしておく必要があります。';

  @override
  String get offline => 'オフライン';

  @override
  String get online => 'オンライン';

  @override
  String get added => '追加済み';

  @override
  String get chooseAServer => 'サーバーを選ぶ';

  @override
  String get whosSigningIn => 'サインインするのは誰ですか？';

  @override
  String get openPlexTv => 'plex.tv/link を開く';

  @override
  String get waitingForThe => 'コードがリンクされるのを待っています…';

  @override
  String get goToPlex => 'スマートフォンかパソコンで plex.tv/link を開き、このコードを入力してください。';

  @override
  String get signInWith => 'Plex でサインイン';

  @override
  String get waitingForApproval => '承認を待っています…';

  @override
  String onYourPhone(Object label) {
    return 'スマートフォンかパソコンで $label →自分のプロフィール→ Quick Connect を開き、このコードを入力してください：';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'サインイン';

  @override
  String get password => 'パスワード';

  @override
  String get username => 'ユーザー名';

  @override
  String signInTo2(Object name) {
    return '$name にサインイン';
  }

  @override
  String get differentServer => '別のサーバー';

  @override
  String get signInWithPassword => 'パスワードでサインイン';

  @override
  String get quickConnectUse => 'Quick Connect（スマートフォンを使う）';

  @override
  String get connect => '接続';

  @override
  String get serverAddress => 'サーバーのアドレス';

  @override
  String get connectToYour => 'サーバーに接続';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV は、あなたの動画を番組表付きでいつでも放送中のチャンネルに変えます。Jellyfin、Emby、Plex、YouTube、NAS などの SMB 共有フォルダに接続できます。チャンネルを替えて、やっている番組を楽しみましょう。';

  @override
  String get yourLibraryOn => 'あなたのライブラリを、\n24 時間 365 日放送。';

  @override
  String get welcomeToNightingale => 'Nightingale TV へようこそ';

  @override
  String signInFor(Object name) {
    return '$name のサインイン';
  }

  @override
  String signInToAgain(Object name) {
    return '$name にもう一度サインイン';
  }

  @override
  String get addAServer => 'サーバーを追加';

  @override
  String foundNewPrograms(Object list) {
    return '$listが見つかりました。新しい番組は、いま放送中の番組のすぐ後からそれぞれのチャンネルで放送されます。';
  }

  @override
  String get libraryRefreshed => 'ライブラリを更新しました';

  @override
  String get nothingNew => '新しいものはありません';

  @override
  String get yourChannelsAre => 'チャンネルは最新の状態です。';

  @override
  String get refreshFailed => '更新に失敗しました';

  @override
  String get moveOkSelectEscBackTo => '▲▼ 移動    OK 選択    ESC TV に戻る';

  @override
  String get noPoolsYet => 'グループはまだありません';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return '$fetchedAt $fetchedAt2 に更新';
  }

  @override
  String get libraryLabel => 'ライブラリ';

  @override
  String get account => 'アカウント';

  @override
  String get watching => '視聴';

  @override
  String get exitNightingaleTv => 'Nightingale TV を終了';

  @override
  String get signOut => 'サインアウト';

  @override
  String get yourChannelLineup => 'チャンネルのラインナップは消去されます。カスタムアイコンは残ります。';

  @override
  String get signOut2 => 'サインアウトしますか？';

  @override
  String get fullScreenOn => '全画面のオン／オフ（F11）';

  @override
  String get nothingWasReset => '何もリセットされていません';

  @override
  String get reset => 'リセット';

  @override
  String get rebuildsTheDefault =>
      'ライブラリから標準のチャンネルを作り直します。変更した名前、アイコン、番号はリセットされます。自分で追加したチャンネルは残ります。先にバックアップを保存するので、［バックアップと復元］で元に戻せます。';

  @override
  String get resetChannelLineup => 'チャンネルのラインナップをリセットしますか？';

  @override
  String get resetChannelLineup2 => 'チャンネルのラインナップをリセット';

  @override
  String get refreshLibrary => 'ライブラリを更新';

  @override
  String get refreshingLibrary => 'ライブラリを更新中…';

  @override
  String get servers => 'サーバー';

  @override
  String get phoneRemote => 'スマホリモコン';

  @override
  String get profiles => 'プロフィール';

  @override
  String get retroLook => 'レトロな見た目';

  @override
  String get playback => '再生';

  @override
  String get switchProfile => 'プロフィールを切り替え';

  @override
  String get sleepTimer => 'スリープタイマー';

  @override
  String get backToTv => 'TV に戻る';

  @override
  String get removeAll => 'すべて削除';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return '$paired にペアリング · 最終使用 $lastUsed';
  }

  @override
  String get noPhonesPaired => 'ペアリングしたスマートフォンはまだありません。';

  @override
  String get pairedPhones => 'ペアリングしたスマートフォン';

  @override
  String get blockedByThis => 'このパソコンのファイアウォールでブロックされています';

  @override
  String get someWiFi =>
      'Wi-Fi によってはデバイス同士を切り離す設定（AP アイソレーション、クライアント分離）があります。それでもスマートフォンが接続できない場合は、Wi-Fi のその設定をオフにしてください。';

  @override
  String get thePhoneHas =>
      'スマートフォンは、ゲストネットワークやモバイルデータではなく、この TV と同じ Wi-Fi につないでください。';

  @override
  String get ifThePhone =>
      'スマートフォンが接続できない場合は、このパソコンのファイアウォールがブロックしているかもしれません。このパソコンでターミナルを開いて、次を実行してください：';

  @override
  String get checkAgain => 'もう一度確認';

  @override
  String get thenChooseCheck => 'その後、［もう一度確認］を選んでください。';

  @override
  String get thisComputersFirewall =>
      'このパソコンのファイアウォールが、スマートフォンからリモコンへの接続を止めています。許可するには、このパソコンでターミナルを開いて、次を実行してください：';

  @override
  String get notConfirmedYet => '未確認 · まだどのスマートフォンも接続していません';

  @override
  String get working => '動作中';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return '動作中 · 最終使用 $name、$lastUsed';
  }

  @override
  String get theRemoteIs => 'リモコンはオフです。';

  @override
  String get orScanThe => 'または、スマートフォンのカメラでコードを読み取ってください。';

  @override
  String get andEnter => 'を開いて次を入力  ';

  @override
  String get onYourPhoneOpen => 'スマートフォンで';

  @override
  String get useYourPhoneAs =>
      'スマートフォンをリモコンとして使えます。スマートフォンで Web ページを開けば、チャンネルを替えたり、番組表を出したり、チャンネルをタップして選局したりできます。インストールは不要です。';

  @override
  String get everyPairedPhone =>
      'ペアリングしたスマートフォンはすべて、この画面のコードをもう一度読み取るまでリモコンとして使えなくなります。';

  @override
  String get removeAllPhones => 'すべてのスマートフォンを削除しますか？';

  @override
  String get thoseDidntMatch => '一致しませんでした。もう一度お試しください。';

  @override
  String get enterTheSame => '同じ 4 桁をもう一度入力してください。';

  @override
  String get choose4Digits => '4 桁の数字を決めてください。';

  @override
  String get thatPinIsnt => 'PIN が違います。もう一度お試しください。';

  @override
  String get clock => '時計';

  @override
  String get captions2 => '字幕';

  @override
  String get audio => '音声';

  @override
  String get maximumStreamingBitrate => '最大ストリーミングビットレート';

  @override
  String get converting => '変換';

  @override
  String get afterThisLong =>
      'この時間ボタンが押されないと、Nightingale TV は誰か見ているかを確認します。1 分以内に応答がなければスリープします。再生が止まり、サーバーの配信も止まります。スリープタイマーの設定中は確認しません。';

  @override
  String get askIfIm => 'まだ見ているか確認する';

  @override
  String get liveTvStill => 'ライブ TV はダッシュボードに表示されます。';

  @override
  String get offWhatYou =>
      'オフ：ここで見たものは、サーバーの再生回数、視聴済みの印、再開位置を変えず、ダッシュボードにも表示されません。';

  @override
  String get pauseSkipAnd =>
      '放送中の番組を一時停止、スキップ、最初から再生できます。オフ：常時放送のテレビのように、どのチャンネルも時刻どおりに進みます。';

  @override
  String get pauseAndRewind => '一時停止と巻き戻し';

  @override
  String get showsTheTime => '映像の隅に時刻を表示します。';

  @override
  String get onScreenClock => '画面上の時計';

  @override
  String get showACountdown => 'CM が始まる前と番組に戻る前にカウントダウンを表示します。';

  @override
  String get breakNotices => 'CM 枠のお知らせ';

  @override
  String get theSizeOf => 'すべての番組とチャンネルでの字幕のサイズ。';

  @override
  String get whileItsOn => 'オンの間は、サラウンド音声（Dolby、DTS）をレシーバーに渡さず、このデバイスでデコードします。';

  @override
  String get evensOutThe =>
      '視聴中の音量をそろえます。大きな CM や番組は小さく、小さなものは大きくするので、リモコンに手を伸ばす必要がありません。';

  @override
  String get volumeLeveling => '音量の自動調整';

  @override
  String get pickALower =>
      'Wi-Fi やリモート接続で番組がバッファリングしたりカクついたりする場合は、低いビットレートを選んでください。［オリジナル］はビットレートを理由に変換することはありません。';

  @override
  String get connectedThroughPlex => 'Plex Relay 経由で接続中のため、画質が制限されます。';

  @override
  String get offNightingaleTv =>
      'オフ：Nightingale TV は常にオリジナルのファイルを最高画質で再生し、サーバーに余分な負荷はかかりません。オン：番組や映画が最大ビットレートを超えるときか、オリジナルのファイルを再生できないときだけ、サーバーが変換します。変換にはサーバーのプロセッサーかグラフィックカードを使います。CM は常にオリジナルのファイルを再生します。';

  @override
  String get transcodeOnlyIf => '必要なときだけトランスコード（試験運用）';

  @override
  String get longerVideosAd =>
      '長い動画（CM 集）は、チャプターか、画面が黒く無音になる位置で、それぞれの CM に分割します。';

  @override
  String get videosOf5 => '5 秒から 3 分の動画は、それぞれ 1 本のクリップになります。';

  @override
  String get commercialsFillBreaks =>
      'CM が CM 枠を埋めます。局ロゴや「このあとすぐ」のクリップには、種類を［ジングル］にしてください。';

  @override
  String get bumpersTakeAt => 'ジングルは番組前を除き、CM 枠の半分までしか使いません。それより長いものは飛ばします。';

  @override
  String stillToSplit(Object unsplit) {
    return 'あと $unsplit を分割';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '長い動画 $reelsCount 本をクリップに分割',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'グループを削除';

  @override
  String get addFolders => 'フォルダーを追加…';

  @override
  String get libraryLabel2 => 'ライブラリ';

  @override
  String get noFoldersYet => 'フォルダーはまだありません。';

  @override
  String get folders2 => 'フォルダー';

  @override
  String get type => '種類';

  @override
  String get poolName => 'グループ名';

  @override
  String get commercialPool => 'CM のグループ';

  @override
  String get itsVideosGo =>
      'このグループの動画は通常のチャンネルに戻ります。ここから取っていた CM 枠は、代わりにすべてのグループを使います。';

  @override
  String get now => '今';

  @override
  String get watch => '視聴';

  @override
  String get tuning2 => '選局中…';

  @override
  String get fullScreen => '全画面';

  @override
  String get noChannels => 'チャンネルなし';

  @override
  String get theirChannelsProgramming =>
      'そのプロフィールのチャンネル、番組枠、設定が削除され、この TV はそのサーバーからサインアウトします。';

  @override
  String delete3(Object name) {
    return '$name を削除しますか？';
  }

  @override
  String get giveTheProfile => 'プロフィールに名前を付けてください。';

  @override
  String get deleteProfile => 'プロフィールを削除';

  @override
  String get removePin => 'PIN を削除';

  @override
  String get setAPin => 'PIN を設定';

  @override
  String get changePin => 'PIN を変更';

  @override
  String get noPinAnyone => 'PIN なし。誰でもこのプロフィールを開けます。';

  @override
  String get lockedThePin => 'ロック中。このプロフィールを開くには PIN が必要です。';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith => 'レーティングのない番組と映画は除きます。';

  @override
  String get allowedToWatch => '視聴できるもの';

  @override
  String get kid => '子ども';

  @override
  String get grownUp => '大人';

  @override
  String get whoItsFor => '使う人';

  @override
  String get color2 => '色';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get newProfile => '新しいプロフィール';

  @override
  String get watchingNow => '視聴中';

  @override
  String get noPin => 'PIN なし';

  @override
  String get pinLocked => 'PIN でロック';

  @override
  String kid2(Object label, Object description) {
    return '子ども · $label（$description）';
  }

  @override
  String get addProfile => 'プロフィールを追加';

  @override
  String get everyoneGetsTheir =>
      '一人ひとりが自分のサーバーのサインイン、チャンネル、番組枠を持てます。子どものプロフィールでは、年齢に合ったレーティングの番組と映画だけが表示されます。';

  @override
  String enterSPin(Object name) {
    return '$name の PIN を入力';
  }

  @override
  String get whosWatching => '誰が見ますか？';

  @override
  String get moveOkChoose2 => '◀▶ 移動    OK 選ぶ';

  @override
  String get enterAGrownUps => '大人の PIN を入力してください。';

  @override
  String get grownUpsOnly => '大人のみ';

  @override
  String get yourChannelYour => 'あなたのチャンネルを、あなたらしく';

  @override
  String get testPattern => 'テストパターン';

  @override
  String get upNext8 => '次の番組  ·  20:00';

  @override
  String get thisDevice => 'このデバイス';

  @override
  String get glow => 'にじみ';

  @override
  String get curvature => '湾曲';

  @override
  String get vignette => '周辺減光';

  @override
  String get mask => 'マスク';

  @override
  String get lines => '走査線数';

  @override
  String get scanlines => '走査線';

  @override
  String get customCrtStyle => 'カスタム CRT スタイル';

  @override
  String accent(Object label) {
    return 'アクセント（$label）';
  }

  @override
  String get overlayTheme => 'オーバーレイのテーマ';

  @override
  String get crtEffect => 'CRT 効果';

  @override
  String get surround => '周囲';

  @override
  String get pictureShape => '画面の形';

  @override
  String get surroundImage => '周囲の画像';

  @override
  String get notAvailableOn => 'このデバイスでは使えません';

  @override
  String get offTurnsOff =>
      '［オフ］にすると、このデバイスだけで CRT 効果がすべてオフになります。画面の形、周囲、オーバーレイのテーマはそのままです。';

  @override
  String get effectsOnThis => 'このデバイスでの効果';

  @override
  String get retroLook2 => 'レトロな見た目';

  @override
  String get theseSettingsApply =>
      'この設定はアプリを表示している画面に適用されます。ライブ TV エクスポートには適用されません。';

  @override
  String get sameAsThe => 'プロフィールと同じ';

  @override
  String get streamsFromThis =>
      'このサーバーからのストリームはこれ以下に抑えます。プロフィール自体の上限（再生）も適用され、低いほうが優先されます。';

  @override
  String qualityLimit(Object name) {
    return '画質の上限 · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      'このサーバーの番組はチャンネルからなくなりますが、チャンネル番号は残ります。このサーバー上のソースと CM のフォルダーは、変更するまで「見つかりません」と表示されます。';

  @override
  String remove3(Object name) {
    return '$name を削除しますか？';
  }

  @override
  String get signingOutOf => 'このプロフィールからサインアウトすると、メインサーバーが変わります。';

  @override
  String signedInAs(Object user) {
    return '$user としてサインイン中';
  }

  @override
  String get mainServer => 'メインサーバー';

  @override
  String get qualityLimit2 => '画質の上限';

  @override
  String get moveDown => '下へ移動';

  @override
  String get moveUp => '上へ移動';

  @override
  String get signInAgain => 'もう一度サインイン';

  @override
  String get programsFromEvery =>
      'すべてのサーバーの番組が 1 つのラインナップにまとまります。複数のサーバーにある作品は、このリストで先に応答したサーバーから再生します（再生元）。応答しなくなったら、次のサーバーが引き継ぎます。';

  @override
  String get sleepingPressAny => 'スリープ中 · いずれかのボタンを押すと視聴できます';

  @override
  String goingToSleep(Object seconds) {
    return '$seconds でスリープします';
  }

  @override
  String get goingToSleep2 => 'スリープします';

  @override
  String goingToSleepIn(Object hint) {
    return '1 分後にスリープします。$hint';
  }

  @override
  String get pressAnyButton => 'いずれかのボタンを押すと視聴を続けます';

  @override
  String goingToSleepIn0(Object padLeft) {
    return '0:$padLeft でスリープします';
  }

  @override
  String get keepWatching => '視聴を続ける';

  @override
  String get areYouStill => 'まだ見ていますか？';

  @override
  String sleepTimerMin(Object left) {
    return 'スリープタイマー · 残り $left 分';
  }

  @override
  String get whatsOnNow => 'いま放送中の番組には決まった終了時刻がありません。';

  @override
  String endOfThis(Object programEnd) {
    return 'この番組の終わり · $programEnd';
  }

  @override
  String get endOfThisProgram => 'この番組の終わり';

  @override
  String get moveOkToggle => '▲▼◀▶ 移動    OK 切り替え    ESC キャンセル';

  @override
  String get usedWhenNo => '番組を選んでいないときに使います。映画の絞り込みにも使います。';

  @override
  String get genres2 => 'ジャンル';

  @override
  String get includeMovies => '映画も含める';

  @override
  String get add2 => '追加…';

  @override
  String get notFoundOn => 'サーバーに見つかりません';

  @override
  String get collectionsFolders => 'コレクションとフォルダー';

  @override
  String get playOrder => '再生順';

  @override
  String get clear => 'クリア';

  @override
  String get shows2 => '番組';

  @override
  String get pickSomethingTo => '流すものを選んでください。';

  @override
  String everyMovie(Object genreText) {
    return '$genreTextの映画すべて';
  }

  @override
  String get everyMovie2 => '映画すべて';

  @override
  String everyShow(Object genreText) {
    return '$genreTextの番組すべて';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCountまたは$last';
  }

  @override
  String decadesGenres(Object decades, Object genres) {
    return '$decadesの$genres';
  }

  @override
  String get settingUpYour => 'チャンネルを設定しています';

  @override
  String get couldntLoadYour => 'ライブラリを読み込めませんでした';

  @override
  String upNext(Object title) {
    return '次の番組：$title';
  }

  @override
  String firstUp(Object title) {
    return '最初は：$title';
  }

  @override
  String backTo(Object title) {
    return '$title に戻る';
  }

  @override
  String programmingResumesIn(Object left) {
    return '番組再開まで $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabelまで $left';
  }

  @override
  String startingWith(Object title) {
    return '最初は「$title」';
  }

  @override
  String upNext2(Object start) {
    return '次の番組  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return '次 $start：$title';
  }

  @override
  String backOn(Object backOnAir) {
    return '$backOnAir に放送再開';
  }

  @override
  String get offTheAir2 => '放送休止中';

  @override
  String get commercialBreak => 'CM 枠';

  @override
  String tryingAgainAt(Object end) {
    return '$end に再試行します';
  }

  @override
  String get exitFullScreen => '全画面を終了';

  @override
  String get guide2 => '番組表';

  @override
  String thereIsNo(Object number) {
    return 'チャンネル $number はありません';
  }

  @override
  String get liveChannelsCant => 'ライブチャンネルは一時停止できません';

  @override
  String get curvatureAndGlow => '湾曲とにじみはオフです：このデバイスでは処理が追いつきません';

  @override
  String get pressBackAgain => 'もう一度［戻る］を押すと終了します';

  @override
  String backAt(Object backAt) {
    return '$backAt に再開';
  }

  @override
  String get live => 'ライブ';

  @override
  String get newLabel => 'NEW';

  @override
  String nowPlayingOn(Object name) {
    return '$name で放送中';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => '一時停止中';

  @override
  String get seekBar => 'シークバー';

  @override
  String get live2 => 'ライブ';

  @override
  String get forward30 => '30 秒進む';

  @override
  String get pause => '一時停止';

  @override
  String get play => '再生';

  @override
  String get back10 => '10 秒戻る';

  @override
  String get restart => '最初から';

  @override
  String somethingWentWrong2(Object status) {
    return '問題が発生しました（$status）。';
  }

  @override
  String get thatIsTooBig => '大きすぎます。';

  @override
  String get notFound => '見つかりません。';

  @override
  String get youCantDo => 'その操作はできません。';

  @override
  String get cantReachThe => 'サーバーに接続できません。サーバーが動いているか確認してください。';

  @override
  String signOut3(Object userName) {
    return '$userName をサインアウト';
  }

  @override
  String get changePassword => 'パスワードを変更';

  @override
  String get users => 'ユーザー';

  @override
  String get backups2 => 'バックアップ';

  @override
  String get serverAndSign => 'サーバーとサインイン';

  @override
  String get channels5 => 'チャンネル';

  @override
  String get thatProfileIsntYours => 'そのプロフィールはあなたのものではないか、すでにありません。';

  @override
  String get download => 'ダウンロード';

  @override
  String get itReplacesThe => 'ここにあるプロフィール、チャンネル、設定を置き換えます。';

  @override
  String get restoreThisBackup => 'このバックアップを復元しますか？';

  @override
  String get restoring => '復元中…';

  @override
  String get restoreFromAFile => 'ファイルから復元…';

  @override
  String get downloadABackup => '今すぐバックアップをダウンロード';

  @override
  String get aBackupHoldsThe =>
      'バックアップには、プロフィール、チャンネル、番組枠、ロゴ、エクスポートの設定、ユーザーアカウントが含まれます（パスワードやサインイン用トークンは含まれません）。';

  @override
  String get restoredTheBackup2 => 'バックアップを復元しました。';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return '$whenValue（$device）のバックアップ：$profiles。ここにあるプロフィール、チャンネル、設定を置き換えます。';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return '次回放送：$start $end';
  }

  @override
  String programsInIts(Object total) {
    return 'プレイリストに $total 番組。';
  }

  @override
  String get workingOutWhat => '流す内容を準備中…';

  @override
  String get later => '後へ';

  @override
  String get earlier => '前へ';

  @override
  String get eachAiringPlays => '放送のたびに、各枠の次のエピソードを順番に流し、時間が余れば最初からもう一度流します。';

  @override
  String get aLineupOf => '番組のラインナップ';

  @override
  String get whatItPlays2 => '流す内容';

  @override
  String get onlyPartOf => '1 年のうち一部の期間だけ';

  @override
  String get runsPastMidnight => '深夜 0 時を過ぎて翌日まで続きます。';

  @override
  String get whenLabel => '時間';

  @override
  String get aNewChannelFor => 'この番組枠用の新しいチャンネル';

  @override
  String get channel3 => 'チャンネル';

  @override
  String get blocks => '番組枠';

  @override
  String get newBlock => '新しい番組枠';

  @override
  String get programmingBlock => '番組枠';

  @override
  String get aBlockTakes =>
      '番組枠は決まった時間にチャンネルを引き継ぎます。たとえば「土曜朝のアニメ」なら土曜の 7:00〜12:00。';

  @override
  String get overlayTheme2 => 'オーバーレイのテーマ';

  @override
  String get crtEffect2 => 'CRT 効果';

  @override
  String get chooseSurroundImage => '周囲の画像を選ぶ…';

  @override
  String get surround2 => '周囲';

  @override
  String get pictureShape2 => '画面の形';

  @override
  String get chooseOfflineImage => 'オフライン画像を選ぶ…';

  @override
  String get fillerPool2 => '穴埋めのグループ';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes 分';
  }

  @override
  String get slotLength2 => '放送枠の長さ';

  @override
  String get everyProgramStarts => 'どの番組も時刻ちょうどに始まります。各放送枠の残りは穴埋めで埋めます。';

  @override
  String get itLeavesThe => 'ラインナップから外れます。';

  @override
  String get itsProgrammingBlocks => 'その番組枠も削除されます。';

  @override
  String get removeThisChannel => 'このチャンネルを削除';

  @override
  String get channelLogo2 => 'チャンネルロゴ';

  @override
  String get editCustomBreaks => 'カスタムの CM 枠を編集…';

  @override
  String get musicChannelsOnlyShuffle =>
      '音楽チャンネルはシャッフル再生だけで、同じアーティストが続くことはありません。';

  @override
  String get playOrder2 => '再生順';

  @override
  String get saveWhatIt => '流す内容を保存';

  @override
  String get canBeA => '番組の最新エピソードを流すホームチャンネルにできます。';

  @override
  String get hiddenFromThe => '番組表に表示しない';

  @override
  String get chooseIcon => 'アイコンを選ぶ…';

  @override
  String get icon => 'アイコン';

  @override
  String get saveNameAnd => '名前と番号を保存';

  @override
  String get aChannelAlready => 'その番号にすでにあるチャンネルは、このチャンネルの番号と入れ替わります。';

  @override
  String get number3 => '番号';

  @override
  String get nameAndNumber => '名前と番号';

  @override
  String get decadesNoneAny => '年代（なし：すべて）';

  @override
  String get genresNoneAny => 'ジャンル（なし：すべて）';

  @override
  String musicVideos(Object musicVideos) {
    return 'ミュージックビデオ（$musicVideos）';
  }

  @override
  String songs(Object songs) {
    return '曲（$songs）';
  }

  @override
  String get newMusicChannel => '新しい音楽チャンネル';

  @override
  String get aNightlySlot => '番組の最新エピソードを、それぞれのホームチャンネルで流す夜の枠。';

  @override
  String get mainSettings => '全体の設定';

  @override
  String get glow2 => 'にじみ';

  @override
  String get curvature2 => '湾曲';

  @override
  String get vignette2 => '周辺減光';

  @override
  String get mask2 => 'マスク';

  @override
  String get lines2 => '走査線数';

  @override
  String get scanlines2 => '走査線';

  @override
  String get customCrtStyle2 => 'カスタム CRT スタイル';

  @override
  String accent2(Object label) {
    return 'アクセント（$label）';
  }

  @override
  String get hidden => '非表示';

  @override
  String get blockChannel2 => '番組枠のチャンネル';

  @override
  String live3(Object source) {
    return 'ライブ · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return '$channelsCount チャンネル中 $shownCount';
  }

  @override
  String get searchChannels => 'チャンネルを検索';

  @override
  String get resetLineup => 'ラインナップをリセット';

  @override
  String get everyChannelEdit =>
      'チャンネルの編集はすべて破棄され、標準のラインナップが作り直されます。自分で追加したチャンネルは残ります。先にバックアップを保存します。';

  @override
  String get musicChannel => '音楽チャンネル';

  @override
  String get newBlockChannel => '新しい番組枠のチャンネル';

  @override
  String get channelsOwnPlans => 'チャンネルごとのプラン';

  @override
  String get setTypeBumpers => '種類を設定：ジングル';

  @override
  String get setTypeCommercials => '種類を設定：CM';

  @override
  String get chooseFolders2 => 'フォルダーを選ぶ…';

  @override
  String get plansThatDrew =>
      'ここから取っていたプランは代わりにすべてのグループを使い、このグループの動画はチャンネルに戻ります。';

  @override
  String get renamePool => 'グループの名前を変更';

  @override
  String get poolActions => 'グループの操作';

  @override
  String get aPoolIs =>
      'グループとは、放送されずに CM 枠を埋める動画が入ったライブラリのフォルダーの集まりです。グループの種類によって、そのクリップを CM として流すか、CM 枠の始めと終わりに流すジングルとして使うかが決まります。';

  @override
  String get pools2 => 'グループ';

  @override
  String get breaks => 'CM 枠';

  @override
  String clipsInAll(Object clips) {
    return 'すべての CM のグループに $clips 本のクリップ。';
  }

  @override
  String get tunerAddress => 'チューナーのアドレス';

  @override
  String get changePort => 'ポートを変更';

  @override
  String get exportThisProfile => 'このプロフィールをエクスポート';

  @override
  String get letsPlexAnd => 'Plex などがネットワーク上のチューナーを見つけられるようにします。';

  @override
  String get discovery2 => '検出';

  @override
  String get encoder2 => 'エンコーダー';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return '自動：このマシンでは $streamLimitInUse。';
  }

  @override
  String get streamsAtOnce2 => '同時ストリーム数';

  @override
  String get quality2 => '画質';

  @override
  String get settings => '設定';

  @override
  String get eachExportedProfile =>
      'エクスポートした各プロフィールは、Plex、Jellyfin、Emby のチューナーになります。それぞれの DVR 設定でアドレスを指定して追加してください。';

  @override
  String get channelsInThis => 'このグループのチャンネル';

  @override
  String get chooseChannels3 => 'チャンネルを選ぶ…';

  @override
  String channels7(Object channelIds) {
    return '$channelIds チャンネル';
  }

  @override
  String get itsChannelsStay => 'チャンネルはラインナップに残ります。';

  @override
  String get renameGroup => 'グループの名前を変更';

  @override
  String get groupActions => 'グループの操作';

  @override
  String get yourGroup => 'マイグループ';

  @override
  String get theOrderOf => '番組表のタブの順番と、表示するタブ。';

  @override
  String get guideTabs => '番組表のタブ';

  @override
  String get make => '作成';

  @override
  String get breaksBetweenPrograms => '番組の間の CM 枠';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '番組中の CM 枠 $mids 回',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return '$songs 曲';
  }

  @override
  String get newEpisode => '新しいエピソード';

  @override
  String get noChannelsYet2 => 'チャンネルはまだありません。';

  @override
  String get noGuide => '番組表なし';

  @override
  String get noneShown => 'すべて非表示';

  @override
  String get allShown => 'すべて表示';

  @override
  String channels8(Object name) {
    return '$name：チャンネル';
  }

  @override
  String get orChooseA => 'または番組表のファイルを選ぶ…';

  @override
  String get emptyThePlaylists => '空欄：プレイリスト自体の番組表（指定されていれば）。';

  @override
  String get guideAddressXmltv => '番組表のアドレス（XMLTV、任意）';

  @override
  String get orChooseAPlaylist => 'またはプレイリストのファイルを選ぶ…';

  @override
  String get leaveEmptyToKeep => '空欄にすると、プレイリストのファイルをそのまま使います。';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'ファイル';

  @override
  String get itsChannelsJoin => 'このプロフィールがそのサーバーにサインインしている間、そのチャンネルが加わります。';

  @override
  String guide3(Object guideFile) {
    return '番組表：$guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'プレイリストのファイル：$playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return '$last $context に更新';
  }

  @override
  String get itsChannelsLeaveThe => 'そのチャンネルは、ラインナップ、グループ、お気に入りからなくなります。';

  @override
  String read(Object fetched, Object context) {
    return '$fetched $context に読み込み。';
  }

  @override
  String showsEpisodesMovies(
    Object series,
    Object episodes,
    Object movies,
    Object songs,
    Object musicVideos,
    Object commercials,
  ) {
    return '$series 番組 · $episodes エピソード · $movies 本の映画 · $songs 曲 · $musicVideos 本のミュージックビデオ · $commercials 本の CM 動画';
  }

  @override
  String fromAs(Object server, Object user) {
    return '$server から $user として。';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name：ライブラリ';
  }

  @override
  String get removeThePin => 'PIN を削除';

  @override
  String get pinOptional => 'PIN（任意）';

  @override
  String get newPinLeave => '新しい PIN（空欄なら変更しません）';

  @override
  String colour(Object i) {
    return '色 $i';
  }

  @override
  String get colour2 => '色';

  @override
  String get itsChannelsBlocks => 'そのチャンネル、番組枠、設定が削除されます。先にバックアップを保存します。';

  @override
  String get exported => 'エクスポート中';

  @override
  String kid3(Object label) {
    return '子ども · $label';
  }

  @override
  String get noProfilesAre => 'まだ割り当てられたプロフィールがありません。管理者に頼んでください。';

  @override
  String signIn2(Object name) {
    return '$name をサインイン';
  }

  @override
  String get theLibraryIs => 'ライブラリをもう一度読み込んでいます。終わるとサーバーの番組がチャンネルに加わります。';

  @override
  String get itsLibraryIs => 'ライブラリを読み込んでチャンネルを作成しています。1〜2 分かかります。';

  @override
  String isSignedIn(Object name) {
    return '$name はサインインしました。';
  }

  @override
  String get couldntDoThat => 'できませんでした。もう一度お試しください。';

  @override
  String get itsChannelsStayIt => 'チャンネルは残りますが、再生するにはサインインが必要です。';

  @override
  String signOut4(Object name) {
    return '$name をサインアウトしますか？';
  }

  @override
  String get signingIn => 'サインイン中…';

  @override
  String wasSignedIn(Object server, Object user) {
    return '$server に $user としてサインインしていました。もう一度サインインしてください。';
  }

  @override
  String signedInTo(Object server, Object user) {
    return '$server に $user としてサインインしています。';
  }

  @override
  String get profileName => 'プロフィール名';

  @override
  String get nameAProfile =>
      'プロフィールに名前を付けてメディアサーバーにサインインすると、そのチャンネルが作成されてエクスポートされます。';

  @override
  String get chooseABackup => 'バックアップファイルを選ぶ…';

  @override
  String get moveAHousehold =>
      'TV や別のサーバーから家族の設定をここに移します：プロフィール、チャンネル、番組枠、ロゴ、エクスポートの設定。';

  @override
  String get restoreABackup => 'バックアップを復元';

  @override
  String get theServerIs => 'サーバーを起動しています…';

  @override
  String get itsProgramsLeaveThe =>
      'このサーバーの番組はチャンネルからなくなりますが、チャンネル番号は残ります。このサーバー上のソースと CM のフォルダーは、変更するまで「見つかりません」と表示されます。';

  @override
  String addAServerTo(Object name) {
    return '$name にサーバーを追加';
  }

  @override
  String servers2(Object name) {
    return '$name：サーバー';
  }

  @override
  String get makeAccountAnd => 'アカウントを作成してサインイン';

  @override
  String get setPasswordAnd => 'パスワードを設定してサインイン';

  @override
  String get passwordAgain => 'パスワード（確認）';

  @override
  String get atLeast8 => '8 文字以上。';

  @override
  String get userName => 'ユーザー名';

  @override
  String get adminAccount => '管理者アカウント';

  @override
  String get makeTheFirst => '最初の管理者アカウントを作成してください。';

  @override
  String get setANew => '管理者アカウントの新しいパスワードを設定してください。';

  @override
  String get thisSetupLink =>
      'このセットアップ用リンクは使用済みか、前回の起動時のものです。サーバーのログから最新のリンクを開くか、サインインしてください。';

  @override
  String get thePasswordsDont => 'パスワードが一致しません。';

  @override
  String get newPasswordAgain => '新しいパスワード（確認）';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get passwordChangedYour => 'パスワードを変更しました。ほかのブラウザーはサインアウトされました。';

  @override
  String get theNewPasswords => '新しいパスワードが一致しません。';

  @override
  String get theyAreSigned => 'サインアウトされ、もうサインインできません。';

  @override
  String get cantSignIn => 'サインインできません。すべての場所でサインアウトされています。';

  @override
  String get usersReachOnly => 'ユーザーは下のプロフィールだけを使えます。';

  @override
  String get adminsCanDo => '管理者は、すべてのプロフィールで何でもできます。';

  @override
  String get admin => '管理者';

  @override
  String get user => 'ユーザー';

  @override
  String get leaveEmptyToKeepIt => '空欄なら変更しません。設定すると、ほかの場所ではサインアウトされます。';

  @override
  String get needsAPassword => 'サインインするにはパスワードが必要です。';

  @override
  String get addUser => 'ユーザーを追加';

  @override
  String get needsAPassword2 => 'パスワードが必要';

  @override
  String get noProfiles => 'プロフィールなし';

  @override
  String get pad => '穴埋め';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  $clips 本';
  }

  @override
  String get clipsFrom2 => 'クリップの取得元';

  @override
  String get channelsUsingItGo => 'これを使っているチャンネルは内蔵のアイコンに戻ります。';

  @override
  String get uploading => 'アップロード中…';

  @override
  String get noneOfYourShows => 'サーバー上のどの番組にもロゴ画像がありません。';

  @override
  String get chooseAnIcon => 'アイコンを選ぶ';

  @override
  String get couldntCopySelect => 'コピーできませんでした。テキストを選択してコピーしてください。';

  @override
  String copy(Object label) {
    return '$labelをコピー';
  }

  @override
  String get home => 'ホーム';

  @override
  String get thereIsNoPage => 'ここにはページがありません。';

  @override
  String get enterPin => 'PIN を入力';

  @override
  String get thisIsA => 'これは子どものプロフィールです。設定を変えるには大人の PIN が必要です。';

  @override
  String hasAPin(Object name) {
    return '$name には PIN があります。';
  }

  @override
  String get profile => 'プロフィール';

  @override
  String get changingAKid => '子どものプロフィールの設定を変えるには、大人のプロフィールの PIN が必要です。';

  @override
  String get aGrownUps => '大人の PIN';

  @override
  String get thisProfile => 'このプロフィール';

  @override
  String movies3(Object movies) {
    return '映画（$movies）';
  }

  @override
  String get shows3 => '番組';

  @override
  String remove4(Object label) {
    return '$labelを削除';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · サーバーに見つかりません';
  }

  @override
  String get dragACollection => 'コレクション、フォルダー、映画をここにドラッグするか、その［追加］ボタンを使ってください。';

  @override
  String get collectionsAndFolders => 'コレクションとフォルダー';

  @override
  String add3(Object name) {
    return '$name を追加';
  }

  @override
  String added2(Object name) {
    return '$name を追加しました';
  }

  @override
  String get dragToAdd => 'ドラッグして追加';

  @override
  String get languageAutomatic => '自動';

  @override
  String dateAtTime(String date, String time) {
    return '$date $time';
  }

  @override
  String connectingTo(Object server) {
    return '$server に接続中…';
  }

  @override
  String get yourServerLower => 'サーバー';

  @override
  String noServerFoundAt(Object address) {
    return '$address に Jellyfin、Emby、Plex のサーバーが見つかりません。';
  }

  @override
  String captionsValue(Object name) {
    return '字幕：$name';
  }

  @override
  String channelOverrides(int count) {
    return '$count チャンネルが独自の設定を使っています（チャンネルとアイコン）。';
  }

  @override
  String noShowLogosOn(Object kind) {
    return '$kind サーバー上のどの番組にもロゴ画像がありません。';
  }

  @override
  String fileChosen(Object name) {
    return 'ファイル：$name';
  }

  @override
  String get theOneChosenBefore => '前に選んだもの';

  @override
  String streamingChannels(
    int count,
    Object channels,
    Object viewers,
    Object running,
    Object limit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'チャンネル $channels を $viewers 人の視聴者に配信中。$limit ストリーム中 $running を使用中。',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name：このラインナップをエクスポート';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name（子ども）：このラインナップをエクスポート';
  }

  @override
  String encoderInUse(Object encoder) {
    return '使用中のエンコーダー：$encoder';
  }

  @override
  String get checking => '確認中…';

  @override
  String countShows(int count) {
    return '$count 番組';
  }

  @override
  String countEpisodes(int count) {
    return '$count エピソード';
  }

  @override
  String countMovies(int count) {
    return '$count 本の映画';
  }

  @override
  String countSongs(int count) {
    return '$count 曲';
  }

  @override
  String countMusicVideos(int count) {
    return '$count 本のミュージックビデオ';
  }

  @override
  String countHidden(int count) {
    return '$count 件非表示';
  }

  @override
  String countOnTheAir(int count) {
    return '$count 件放送中';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '番組枠 $count 件',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name：$stats';
  }

  @override
  String get yourServerHasNothingNew =>
      '前回の更新以降、サーバーに新しいものはありません。新しいファイルはサーバーがスキャンするとここに表示されます。追加したばかりなら、先にサーバーでライブラリをスキャンしてから、もう一度更新してください。';

  @override
  String serverHasNothingNew(Object server) {
    return '前回の更新以降、$server に新しいものはありません。新しいファイルはサーバーがスキャンするとここに表示されます。追加したばかりなら、先にサーバーでライブラリをスキャンしてから、もう一度更新してください。';
  }

  @override
  String get updateWatchStatusOnYourServer => 'サーバーの視聴状況を更新する';

  @override
  String get updateWatchStatusOnYourServers => 'サーバーの視聴状況を更新する';

  @override
  String updateWatchStatusOn(Object name) {
    return '$name の視聴状況を更新する';
  }

  @override
  String get poolFoldersBumpers =>
      'これらのフォルダー（とその中のフォルダー）の動画はすべて CM 枠の始めと終わりに流れ、番組としては放送されません。';

  @override
  String get poolFoldersCommercials =>
      'これらのフォルダー（とその中のフォルダー）の動画はすべて CM 枠を埋め、番組としては放送されません。';

  @override
  String get newPin => '新しい PIN';

  @override
  String namedPin(Object name) {
    return '$name の PIN';
  }

  @override
  String get qualitySameAsProfile => '画質：プロフィールと同じ';

  @override
  String qualityValue(Object limit) {
    return '画質：$limit';
  }

  @override
  String onChannel(Object channel) {
    return '$channel で';
  }

  @override
  String get aChannelThatIsGone => 'なくなったチャンネル';

  @override
  String liveFrom(Object source) {
    return '$source からライブ';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'ロゴ $mode · 初回放送 $premieres';
  }

  @override
  String get offLower => 'オフ';

  @override
  String streamingNow(Object count) {
    return '$count 件配信中。';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return '$count 件配信中 · $encoder でエンコード。';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · $channels チャンネル中 $chosen';
  }

  @override
  String backupSummary(
    Object when,
    Object device,
    Object profiles,
    Object channels,
    Object blocks,
    Object logos,
  ) {
    return '$when（$device）のバックアップ：$profiles。$channels チャンネル、番組枠 $blocks 件、ロゴ $logos 件。';
  }

  @override
  String get backupSavedFirst => '現在の内容のバックアップを先に保存します。';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい番組 $count 本',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しいエピソード $count 本',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい映画 $count 本',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい曲 $count 曲',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return '$listを流します。';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しいチャンネル $count 個',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => '小さな子ども';

  @override
  String get kidRatingYoungDescription => 'TV-Y と TV-Y7';

  @override
  String get kidRatingKids => '子ども';

  @override
  String get kidRatingKidsDescription => 'TV-G と G まで';

  @override
  String get kidRatingOlder => '大きな子ども';

  @override
  String get kidRatingOlderDescription => 'TV-PG と PG まで';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count プロフィール',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count チャンネル',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '番組枠 $count 件',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枠',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'フォルダー内の動画 $count 本',
    );
    return '$_temp0';
  }

  @override
  String backupProfilesChannelsBlocks(
    Object profiles,
    Object channels,
    Object blocks,
  ) {
    return '$profiles · $channels · $blocks。';
  }

  @override
  String get liveLabel => 'ライブ';

  @override
  String get aMidRollOpens =>
      '番組中の CM 枠はジングルで始まってジングルで終わり、番組後の CM 枠はジングルで始まり、番組前の CM 枠はジングルで終わります。残りは CM で埋めます。';

  @override
  String get programsPlayBack => '番組は CM 枠なしで続けて流れます。';

  @override
  String get everyShowFills =>
      'どの番組も 30 分の放送枠（長いものは 1 時間以上）を埋めるので、番組表は時刻どおりに進みます。';

  @override
  String get chooseHowLong =>
      'CM 枠の長さ、番組中の CM 枠の間隔、各 CM 枠がどのグループから流すかを選んでください。';

  @override
  String get copyAction => 'コピー';

  @override
  String get channelKidsZone => 'キッズゾーン';

  @override
  String get channelToonTv => 'アニメチャンネル';

  @override
  String get channelLaughTrack => 'お笑いチャンネル';

  @override
  String get channelFamilyRoom => 'ファミリータイム';

  @override
  String get channelAdventureTv => '冒険チャンネル';

  @override
  String get channelSciFiFantasy => 'SF・ファンタジー';

  @override
  String get channelMysteryTv => 'ミステリー劇場';

  @override
  String get channelDramaCentral => 'ドラマ館';

  @override
  String get channelCrimeJustice => '刑事・サスペンス';

  @override
  String get channelThrillTv => 'スリラー劇場';

  @override
  String get channelFrightNight => 'ホラーナイト';

  @override
  String get channelRomanceTv => '恋愛チャンネル';

  @override
  String get channelDiscoveryZone => 'ドキュメンタリー';

  @override
  String get channelMusicTv => '音楽 TV';

  @override
  String get channelRealityTv => 'リアリティ TV';

  @override
  String get channelGameShowTv => 'クイズバラエティ';

  @override
  String get channelFrontierTv => '西部劇チャンネル';

  @override
  String get channelHistoryTv => '歴史チャンネル';

  @override
  String get channelSportsTv => 'スポーツ TV';

  @override
  String get channelNewsTv => 'ニュース TV';

  @override
  String get channelAllShows => '全番組';

  @override
  String get channelMovieChannel => '映画チャンネル';

  @override
  String get channelMusicVideos => '音楽ビデオ';

  @override
  String get channelMusicRadio => '音楽ラジオ';

  @override
  String get genreActionAdventure => 'アクション・アドベンチャー';

  @override
  String get genreSciFiFantasy => 'SF・ファンタジー';

  @override
  String get genreKids => 'キッズ';

  @override
  String get genreAnimation => 'アニメ';

  @override
  String get genreComedy => 'コメディ';

  @override
  String get genreFamily => 'ファミリー';

  @override
  String get genreDrama => 'ドラマ';

  @override
  String get genreCrime => '犯罪';

  @override
  String get genreMystery => 'ミステリー';

  @override
  String get genreThriller => 'スリラー';

  @override
  String get genreHorror => 'ホラー';

  @override
  String get genreRomance => 'ロマンス';

  @override
  String get genreDocumentary => 'ドキュメンタリー';

  @override
  String get genreMusic => '音楽';

  @override
  String get genreReality => 'リアリティ';

  @override
  String get genreGameShows => 'クイズ・ゲーム';

  @override
  String get genreWestern => '西部劇';

  @override
  String get genreWar => '戦争';

  @override
  String get genreHistory => '歴史';

  @override
  String get genreNews => 'ニュース';

  @override
  String get genreTalk => 'トーク';

  @override
  String get genreSoap => 'メロドラマ';

  @override
  String get genreSports => 'スポーツ';

  @override
  String get genreClassical => 'クラシック';

  @override
  String get genreElectronic => 'エレクトロニック';

  @override
  String get genreCountry => 'カントリー';

  @override
  String get genreLatin => 'ラテン';

  @override
  String get genreSoundtrack => 'サウンドトラック';

  @override
  String get genreOldies => 'オールディーズ';

  @override
  String get genreDance => 'ダンス';

  @override
  String get genreFolk => 'フォーク';

  @override
  String get genreAlternative => 'オルタナティブ';

  @override
  String get blockDaytime => 'デイタイム';

  @override
  String get blockMovieNight => 'ムービーナイト';

  @override
  String get blockNewEpisodes => '新エピソード';

  @override
  String get kindShow => '番組';

  @override
  String get kindShows => '番組';

  @override
  String get kindMovies => '映画';

  @override
  String get kindMusicVideos => 'ミュージックビデオ';

  @override
  String get kindRadio => 'ラジオ';

  @override
  String genreMovies(Object genre) {
    return '$genre映画';
  }

  @override
  String genreMusicVideos(Object genre) {
    return '$genreのミュージックビデオ';
  }

  @override
  String genreRadio(Object genre) {
    return '$genreラジオ';
  }

  @override
  String kindSuffix(Object name, Object kind) {
    return '$name（$kind）';
  }

  @override
  String kindSuffixNumbered(Object name, Object kind, Object number) {
    return '$name（$kind $number）';
  }

  @override
  String get lateNightTitle => '深夜';

  @override
  String get languageTitle => '言語';

  @override
  String get stillWatchingOff => 'オフ';

  @override
  String afterHours(int hours) {
    return '$hours 時間後';
  }

  @override
  String get bitrateOriginal => 'オリジナル（制限なし）';

  @override
  String get bitrate40 => '40 Mbps · 4K';

  @override
  String get bitrate20 => '20 Mbps · 1080p 高画質';

  @override
  String get bitrate12 => '12 Mbps · 1080p';

  @override
  String get bitrate8 => '8 Mbps · 1080p';

  @override
  String get bitrate4 => '4 Mbps · 720p';

  @override
  String get noSuchLanguage => 'その言語はありません。';

  @override
  String get languageField => '言語';

  @override
  String get remotePageTitle => 'Nightingale TV リモコン';

  @override
  String get remotePairTitle => 'TV とペアリング';

  @override
  String get remotePairHelp =>
      'TV に表示されたコード（メニュー → スマホリモコン）を読み取るか、そこに表示された 6 桁のコードを入力してください。';

  @override
  String get remotePairingCode => 'ペアリングコード';

  @override
  String get remotePair => 'ペアリング';

  @override
  String get remoteConnecting => '接続中…';

  @override
  String get remoteTabRemote => 'リモコン';

  @override
  String get remoteUp => '上';

  @override
  String get remoteLeft => '左';

  @override
  String get remoteRight => '右';

  @override
  String get remoteDown => '下';

  @override
  String get remoteInfo => '情報';

  @override
  String get remoteLastCh => '前の CH';

  @override
  String get remoteCc => '字幕';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => '決定';

  @override
  String get remoteRemovedFromTv =>
      'このスマートフォンは TV から削除されました。もう一度ペアリングするにはコードを読み取ってください。';

  @override
  String get remoteCouldntPair => 'ペアリングできませんでした。もう一度お試しください。';

  @override
  String get remoteCantReachWifi =>
      'TV に接続できません。このスマートフォンは同じ Wi-Fi につながっていますか？';

  @override
  String get remoteEnterDigits => 'TV に表示された 6 桁の数字を入力してください。';

  @override
  String get remoteCantReachTv => 'TV に接続できません';

  @override
  String get remotePickProfile => '矢印と OK でプロフィールを選んでください。';

  @override
  String remoteWatching(Object name) {
    return '視聴中：$name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name（子ども）';
  }

  @override
  String get transferPageTitle => 'Nightingale TV バックアップ';

  @override
  String get transferIntro =>
      'この TV とこのデバイスの間でバックアップを移します。その間、TV のダイアログは開いたままにしてください。';

  @override
  String get transferDownload => 'バックアップをダウンロード';

  @override
  String get transferDownloadHelp => 'TV の現在の設定のバックアップ：プロフィール、チャンネル、番組枠、設定。';

  @override
  String get transferRestoreTitle => 'ファイルから復元';

  @override
  String transferRestoreHelp(Object file) {
    return '$file ファイルを TV に送ります。TV で確認するまで何も変わりません。';
  }

  @override
  String get transferChoose => 'バックアップファイルを選ぶ…';

  @override
  String get transferFoot => 'このページを開けるのは自宅のネットワーク上のデバイスだけです。';

  @override
  String transferSending(Object name) {
    return '$name を送信中…';
  }

  @override
  String get transferCheckTv => 'TV で操作を完了してください。';

  @override
  String get transferClosed => 'TV がこのページを閉じました。［バックアップと復元］からもう一度開いてください。';

  @override
  String get transferCouldntTake => 'TV がそのファイルを受け取れませんでした。';

  @override
  String get transferCouldntReach => 'TV に接続できませんでした。TV にまだコードが表示されていますか？';

  @override
  String get includeShows => '番組も含める';

  @override
  String get everyShow2 => '番組すべて';

  @override
  String get decades => '年代';

  @override
  String get decadesHeading => '年代';

  @override
  String decadeYears(Object decade) {
    return '$decade年代';
  }

  @override
  String get channelActionTv => 'アクションチャンネル';

  @override
  String get channelSciFiTv => 'SF チャンネル';

  @override
  String get channelFantasyTv => 'ファンタジー劇場';

  @override
  String get channelMysteryThrills => '推理・サスペンス';

  @override
  String get genreAction => 'アクション';

  @override
  String get genreAdventure => 'アドベンチャー';

  @override
  String get genreSciFi => 'SF';

  @override
  String get genreFantasy => 'ファンタジー';

  @override
  String get genreThrillerMystery => 'スリラー・ミステリー';

  @override
  String decadeTv(Object decade) {
    return '$decadeの番組';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$decadeの$genre番組';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return '$decadeの$genre映画';
  }

  @override
  String get errorReports => 'エラーレポート';

  @override
  String get sendErrorReportsFrom => 'このデバイスからエラーレポートを送信';

  @override
  String get errorReportsExplain =>
      '問題が起きると、Nightingale TV は開発者に短いレポートを送ります。内容は、エラー、アプリのバージョン、デバイスの種類、直前のいくつかの画面とチャンネル番号です。サーバーのアドレス、パスワードとキー、名前、ファイルパスは送信前に取り除きます。作品のタイトルや視聴内容は送りません。';

  @override
  String get errorReportsOff => 'オフにすると、このデバイスからは何も送られず、送信待ちのレポートは削除されます。';

  @override
  String get recentReports => '最近のレポート';

  @override
  String get reportKindTest => 'テスト';

  @override
  String get reportKindVideo => '映像のレポート';

  @override
  String get reportKindError => 'エラー';

  @override
  String get reportKindExit => '予期しない終了';

  @override
  String get reportKindSlowStart => '起動の遅れ';

  @override
  String get errorReportsAutomatic =>
      'アプリが予期せず終了したときや起動に時間がかかったときも、直前の画面、チャンネル、起動の手順、メモリの数値を含むレポートが自動で送られます。';

  @override
  String get sendATestReport => 'テストレポートを送信';

  @override
  String lastReportId(String id) {
    return '最後のレポート ID：$id';
  }

  @override
  String get noReportSentYet => 'このデバイスからはまだレポートを送っていません。';

  @override
  String get quoteReportId => '開発者に問題を伝えるときは、この ID を知らせてください。';

  @override
  String testReportSent(String id) {
    return 'テストレポートを送信しました：$id';
  }

  @override
  String get testReportNotSent => 'テストレポートを送信できませんでした。少ししてからもう一度お試しください。';

  @override
  String get reportsNotInBuild =>
      'この Nightingale TV のビルドにはエラーレポート機能が含まれていないため、何も送信されません。';

  @override
  String get sendAVideoReport => '映像のレポートを送信';

  @override
  String get videoReportHelp =>
      '映像がおかしいときは、これを押してからチャンネルに戻ってください。映像が 10 秒流れるとレポートが送信され、その ID が TV 画面に表示されます。';

  @override
  String get videoReportArmed => '今すぐチャンネルに戻ってください。映像が 10 秒流れると映像のレポートが送信されます。';

  @override
  String get videoReportTooSoon => '1 分以内に映像のレポートを送信したばかりです。少ししてからもう一度お試しください。';

  @override
  String videoReportSent(String id) {
    return '映像のレポートを送信しました：$id';
  }

  @override
  String get videoReportsExplain =>
      '映像のレポートは、デバイス、映像とそのデコーダーの情報、映像の大まかな色の格子、アプリ自体の最近のログを送ります。視聴中の映像の画像は送りません。アプリのアップデート後、チャンネルが 10 秒流れたときに 1 回送信されます。';

  @override
  String get unlockNightingaleTv => 'Nightingale TV をアンロック';

  @override
  String trialDaysLeftMenu(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '無料体験の残り $count 日',
    );
    return '$_temp0';
  }

  @override
  String get purchasePending => '購入手続き中';

  @override
  String get freeForDaysTitle => '14 日間無料';

  @override
  String welcomeTrialPrice(String price) {
    return 'Nightingale TV は 14 日間無料です。その後、$price の 1 回の購入でずっと使えるようになり、プロジェクトの支援にもなります。';
  }

  @override
  String get welcomeTrial =>
      'Nightingale TV は 14 日間無料です。その後、1 回の購入でずっと使えるようになり、プロジェクトの支援にもなります。';

  @override
  String get unlockNow => '今すぐアンロック';

  @override
  String get startMyFreeTrial => '無料体験を始める';

  @override
  String get lastDayOfTrial => '無料体験の最終日です';

  @override
  String reminderPrice(String price) {
    return '無料体験が終わったら、$price の 1 回の購入で Nightingale TV をずっと使えるようになり、プロジェクトの支援にもなります。';
  }

  @override
  String get reminder =>
      '無料体験が終わったら、1 回の購入で Nightingale TV をずっと使えるようになり、プロジェクトの支援にもなります。';

  @override
  String get freeTrialEnded => '無料体験が終了しました';

  @override
  String get unlockScreenText =>
      '1 回の購入で Nightingale TV をずっと使えるようになり、プロジェクトの支援にもなります。プロフィール、チャンネル、設定はすべてそのまま残っています。';

  @override
  String unlockForPrice(String price) {
    return '$price でアンロック';
  }

  @override
  String get unlock => 'アンロック';

  @override
  String get checkMyPurchaseAgain => '購入をもう一度確認';

  @override
  String get redeemPlayCode => 'Play のコードを利用';

  @override
  String get redeemCodeTitle => 'コードを利用';

  @override
  String get redeemCodeText =>
      'このデバイスで使っている Google アカウントでサインインしたスマートフォンかパソコンで、play.google.com/redeem からコードを利用してください。その後、［購入をもう一度確認］を選んでください。';

  @override
  String get noPurchaseFound => '購入が見つかりません';

  @override
  String get noPurchaseFoundText =>
      'このデバイスの Google アカウントでは Nightingale TV の購入が見つかりませんでした。購入したばかりなら、少ししてからもう一度お試しください。';

  @override
  String get purchaseNotCompleted => '購入が完了しませんでした';

  @override
  String get purchaseNotCompletedText =>
      '購入を完了できませんでした。何も変わっていません。少ししてからもう一度お試しください。';

  @override
  String get purchasePendingText =>
      '購入の完了を待っています。その間も Nightingale TV は使え、完了すると自動的にアンロックされます。';

  @override
  String get unlockedThankYou =>
      'アンロックしました。Nightingale TV を支援していただきありがとうございます。';

  @override
  String freeTrialDaysLeftAbout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '無料体験：残り $count 日',
    );
    return '$_temp0';
  }

  @override
  String couldntReadChannels(Object name) {
    return '$name のチャンネル一覧を読み込めませんでした';
  }

  @override
  String channelNoLongerOn(Object server) {
    return 'このチャンネルはもう $server にありません';
  }

  @override
  String channelsNoLongerOnServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'サーバーにもうないチャンネル $count 個',
    );
    return '$_temp0';
  }

  @override
  String get sharing => '共有';

  @override
  String get sharingIntroTitle => 'Nightingale TV を使っている友達を追加';

  @override
  String get sharingIntroWhat =>
      '共有を使うと、Nightingale TV を使っている友達を追加できます。Nightingale のプロフィールごとに共有アカウントがあります。';

  @override
  String get sharingIntroStored =>
      '保存されるもの：メールアドレス、共有プロフィール、友達、そして今後は共有したものや視聴したもの。';

  @override
  String get sharingIntroNoVideo => 'ユーザー間で映像が送られることはありません。';

  @override
  String get sharingSetUp => '設定する';

  @override
  String get sharingEmailPrompt => 'メールアドレスを入力してください。サインイン用の 6 桁のコードを送ります。';

  @override
  String get sharingEmailLabel => 'メールアドレス';

  @override
  String get sharingSendCode => 'コードを送信';

  @override
  String get sharingNotAnEmail => 'name@example.com のようなメールアドレスを入力してください。';

  @override
  String sharingCodeSent(Object email) {
    return '$email に 6 桁のコードを送りました。ここに入力してください。';
  }

  @override
  String get sharingCodeLabel => '6 桁のコード';

  @override
  String get sharingWrongCode => 'コードが違います';

  @override
  String get sharingTooManyWrong => 'コードの間違いが多すぎます。新しいコードを送信してください。';

  @override
  String get sharingSendNewCode => '新しいコードを送信';

  @override
  String sharingSendNewCodeIn(Object seconds) {
    return '新しいコードを送信（$seconds 秒）';
  }

  @override
  String get sharingOtherEmail => '別のメールアドレスを使う';

  @override
  String get sharingUnavailable => '今は共有を使えません。後でもう一度お試しください。';

  @override
  String get sharingProfileTitle => '共有プロフィール';

  @override
  String get sharingProfileIntro => '友達に表示されます。メールアドレスは表示されません。';

  @override
  String get sharingNameLabel => '表示名';

  @override
  String get sharingHandleLabel => 'ハンドル名';

  @override
  String get sharingHandleRules => '英字、数字、_ を 3〜20 文字で使ってください。';

  @override
  String get sharingHandleTaken => 'そのハンドル名はすでに使われています。';

  @override
  String get sharingNameRequired => '表示名を入力してください。';

  @override
  String get sharingAvatar => 'アバター';

  @override
  String get sharingStationLabel => '局名（任意）';

  @override
  String get sharingAddFriend => '友達を追加';

  @override
  String get sharingCodeHelp =>
      '友達が Nightingale TV の［共有］→［友達を追加］でこのコードを入力するか、リンクを開きます。使えるのは 1 回だけで、7 日で期限が切れます。';

  @override
  String get sharingNewCode => '新しいコード';

  @override
  String get sharingSendInvite => '招待を送る';

  @override
  String get sharingEnterCode => 'コードを入力';

  @override
  String sharingInviteText(Object link) {
    return 'Nightingale TV で友達になってください：$link';
  }

  @override
  String get sharingFriends => '友達';

  @override
  String get sharingNoFriends => '友達はまだいません。コードを共有して追加しましょう。';

  @override
  String get sharingBlocked => 'ブロック中';

  @override
  String get sharingRemoveFriend => '友達から削除';

  @override
  String sharingRemoveFriendConfirm(Object name) {
    return '$name を友達から削除しますか？お互いに友達ではなくなります。';
  }

  @override
  String get sharingBlock => 'ブロック';

  @override
  String sharingBlockConfirm(Object name) {
    return '$name をブロックしますか？友達から削除され、相手はあなたのコードを使えなくなります。';
  }

  @override
  String get sharingUnblock => 'ブロックを解除';

  @override
  String sharingUnblockConfirm(Object name) {
    return '$name のブロックを解除しますか？相手は新しいコードであなたをまた追加できます。';
  }

  @override
  String get sharingSignOutConfirm =>
      'このプロフィールで共有からサインアウトしますか？共有アカウントと友達は残ります。メールアドレスでもう一度サインインできます。';

  @override
  String get sharingDeleteAccount => '共有アカウントを削除';

  @override
  String sharingDeleteConfirm(Object handle) {
    return '共有アカウント、共有プロフィール（@$handle）、友達、招待、それに関して保存されているものすべてを削除し、すべてのデバイスでサインアウトします。元に戻すことはできません。';
  }

  @override
  String get sharingDeleted => '共有アカウントを削除しました。';

  @override
  String get sharingCodeFieldLabel => '友達のコード';

  @override
  String get sharingNotACode => 'コードは英数字 6 文字です（例：AB3K·9Q）。';

  @override
  String sharingAddFriendQuestion(Object name, Object handle) {
    return '$name（@$handle）を友達に追加しますか？';
  }

  @override
  String get sharingOwnCode => 'それは自分のコードです';

  @override
  String get sharingInviteGone => 'この招待は期限切れか、すでに使われています';

  @override
  String get sharingTooManyTries => '試行回数が多すぎます。後でもう一度お試しください';

  @override
  String sharingNowFriends(Object name) {
    return '$name と友達になりました。';
  }

  @override
  String get sharingSwitchToAdult => '友達を追加するには大人のプロフィールに切り替えてください。';

  @override
  String get sharingEditProfile => '編集';

  @override
  String sharingStation(Object station) {
    return '局：$station';
  }

  @override
  String get sharingLiveCantShare => 'ライブチャンネルは自分のチューナーから流れるため共有できません';

  @override
  String get sharingMusicCantShare => '音楽チャンネルは共有できません';

  @override
  String get sharingCopyCantShare => '共有されたチャンネルをさらに共有することはできません';

  @override
  String get sharingTooBig => '20,000 番組を超えるチャンネルは共有できません';

  @override
  String get sharingNoneMatch => 'これらの番組はどれもあなたのサーバーにありません';

  @override
  String get sharingUpdateApp => 'このチャンネルを追加するには Nightingale TV をアップデートしてください。';

  @override
  String sharingStopsFollowing(Object name) {
    return 'このチャンネルは今後 $name の変更に追従しません。';
  }

  @override
  String sharingNewShares(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のチャンネル',
    );
    return '$name が $_temp0を共有しました。［メニュー］→［共有］を開いて追加してください。';
  }

  @override
  String sharingNewSharesMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のチャンネル',
    );
    return '$_temp0が共有されました。［メニュー］→［共有］を開いて追加してください。';
  }

  @override
  String get sharingSharedWithYou => '共有されたもの';

  @override
  String get sharingNothingShared => '待っているものはありません。友達が共有したチャンネルはここに表示されます。';

  @override
  String sharingMatched(Object matched, Object total) {
    return '$total 番組中 $matched 番組が一致';
  }

  @override
  String sharingAddedAs(Object number) {
    return 'チャンネル $number として追加しました';
  }

  @override
  String get sharingDecline => '断る';

  @override
  String get sharingShareChannels => 'チャンネルを共有';

  @override
  String get sharingShareChannelsHelp =>
      '友達には各チャンネルの内容が届き、友達のアプリがそれを友達自身のサーバーから作り直します。映像は送られません。';

  @override
  String get sharingChannelsYouShare => '共有中のチャンネル';

  @override
  String get sharingNoChannelsShared => '共有しているチャンネルはありません。';

  @override
  String get sharingStopSharing => '共有をやめる';

  @override
  String sharingStopSharingConfirm(Object name) {
    return '$name の共有をやめますか？友達のコピーは残りますが、あなたの変更は届かなくなります。';
  }

  @override
  String sharingWith(Object names) {
    return '共有先：$names';
  }

  @override
  String get sharingShareWith => '共有先';

  @override
  String get sharingShare => '共有';

  @override
  String get sharingGetLink => 'リンクを取得';

  @override
  String sharingSharedWith(Object names) {
    return '$names と共有中';
  }

  @override
  String get sharingLinkHelp =>
      'このコードを 7 日以内に使った人があなたの友達になり、これらのチャンネルを受け取ります。使えるのは 1 回だけです。';

  @override
  String sharingChannelsInviteText(Object link) {
    return '私の Nightingale TV のチャンネルをどうぞ：$link';
  }

  @override
  String get sharingPickChannel => 'チャンネルを 1 つ以上選んでください。';

  @override
  String get sharingPickFriend => '友達を 1 人以上選ぶか、［リンクを取得］を使ってください。';

  @override
  String get sharingNoFriendsToShare => '友達はまだいません。リンクを取得して、新しい人と共有しましょう。';

  @override
  String get sharingShareEllipsis => '共有…';

  @override
  String sharingSharedBy(Object name, Object handle) {
    return '$name（@$handle）が共有';
  }

  @override
  String get sharingKeepUpdated => '最新の状態に保つ';

  @override
  String sharingKeepUpdatedHelp(Object name) {
    return 'このチャンネルへの $name の変更に追従する';
  }

  @override
  String get sharingNoLongerUpdated => '更新されなくなりました';

  @override
  String sharingChannelsOffer(Object name, Object handle, Object names) {
    return '$name（@$handle）があなたとこれらのチャンネルを共有しました：$names。$name を友達に追加して受け取りますか？';
  }

  @override
  String sharingNowFriendsChannels(Object name) {
    return '$name と友達になりました。相手のチャンネルは［共有されたもの］で待っています。';
  }

  @override
  String get sharedTab => '共有';

  @override
  String get sharedTabRule => '友達の共有から追加したチャンネル';

  @override
  String get presenceSetting => '視聴中の番組を表示';

  @override
  String presenceSettingValue(Object value) {
    return '視聴中の番組を表示：$value';
  }

  @override
  String get presenceQuestion => '視聴中の番組を友達に表示しますか？';

  @override
  String get presenceExplain =>
      '視聴中は、友達に番組や映画とチャンネルが表示されます。それ以外は表示されず、視聴をやめると何も表示されません。プレーヤーのボタンにある［プライベート視聴］を使うと、アプリを閉じるまで表示されません。この設定は［共有］でいつでも変えられます。';

  @override
  String presenceWatchingOn(Object title, Object channel) {
    return '$channel で「$title」を視聴中';
  }

  @override
  String presenceWatchingChannel(Object channel) {
    return '$channel を視聴中';
  }

  @override
  String presenceIsWatching(Object name) {
    return '$name が視聴中';
  }

  @override
  String presenceAndOthersWatching(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人の友達',
    );
    return '$name とほか $_temp0が視聴中';
  }

  @override
  String presenceWatchingToo(Object name) {
    return '$name も視聴中';
  }

  @override
  String presenceAndOthersWatchingToo(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人の友達',
    );
    return '$name とほか $_temp0も視聴中';
  }

  @override
  String presenceNoticeOne(Object name) {
    return '$name がいま視聴中です';
  }

  @override
  String presenceNoticeMany(Object names) {
    return '$names がいま視聴中です';
  }

  @override
  String get watchPrivately => 'プライベート視聴';

  @override
  String get watchingPrivately => 'プライベート視聴中';

  @override
  String get watchTogether => '一緒に見る';

  @override
  String partyStartTitle(Object title) {
    return '「$title」を一緒に見る';
  }

  @override
  String get partyStartHelp =>
      '全員がそれぞれ自分のサーバーから、同期して再生します。友達を 7 人まで選ぶか、リンクを取得してください。';

  @override
  String get partyNoFriends => '友達はまだいません：リンクを取得して誰かを招待しましょう。';

  @override
  String get partyGetLink => 'リンクを取得';

  @override
  String get partyStart => '開始';

  @override
  String get partyLinkHelp => 'このリンクを開いた人は誰でもあなたの友達になり、参加できます。';

  @override
  String partyInviteBanner(Object name, Object title) {
    return '$name から「$title」を一緒に見ようと招待が届きました';
  }

  @override
  String partyInviteBannerNoTitle(Object name) {
    return '$name から一緒に見ようと招待が届きました';
  }

  @override
  String get partyJoin => '参加';

  @override
  String get partyNotNow => '今はしない';

  @override
  String partyJoinQuestion(Object name) {
    return '$name のウォッチパーティーに参加しますか？';
  }

  @override
  String partyOn(Object title, Object channel) {
    return '$channel の「$title」';
  }

  @override
  String get partyInSync => '同期中';

  @override
  String get partyCatchingUp => '追いついています';

  @override
  String get partyNotOnServers => 'あなたのサーバーにありません';

  @override
  String partyMissingTitle(Object title) {
    return 'あなたのサーバーにありません：$title';
  }

  @override
  String get partyMissingRejoin => '次の番組で再び参加します。';

  @override
  String get partyInvite => '招待';

  @override
  String get partyLeave => '退出';

  @override
  String get partyStay => '残る';

  @override
  String get partyLeaveQuestion => 'ウォッチパーティーから退出しますか？';

  @override
  String get partyLeaveHostDetail => 'あなたはホストなので、全員のパーティーが終了します。';

  @override
  String get partyLeaveGuestDetail => '自分のチャンネルに戻ります。';

  @override
  String get partyHost => 'ホスト';

  @override
  String partyJoined(Object name) {
    return '$name が参加しました';
  }

  @override
  String partyLeft(Object name) {
    return '$name が退出しました';
  }

  @override
  String partyPaused(Object name) {
    return '$name が一時停止しました';
  }

  @override
  String partyResumed(Object name) {
    return '$name が再開しました';
  }

  @override
  String partySkipped(Object name) {
    return '$name がスキップしました';
  }

  @override
  String partyRestarted(Object name) {
    return '$name が番組を最初から再生しました';
  }

  @override
  String partyWentLive(Object name) {
    return '$name がライブに戻りました';
  }

  @override
  String partyEnded(Object name) {
    return '$name がウォッチパーティーを終了しました';
  }

  @override
  String get partyLost => 'ウォッチパーティーとの接続が切れました';

  @override
  String get partyFull => 'そのウォッチパーティーは満員です';

  @override
  String get partyOver => 'そのウォッチパーティーは終了しました';

  @override
  String get partyWatchParties => 'ウォッチパーティー';

  @override
  String get partyNoInvites => 'いまウォッチパーティーの招待はありません。';

  @override
  String partyChannelName(Object channel) {
    return 'ウォッチパーティー · $channel';
  }

  @override
  String get partyReactions => 'リアクション';

  @override
  String partyInvited(Object names) {
    return '$names を招待しました';
  }

  @override
  String get smbGuestsRefused => 'このコンピューターはゲストを受け付けません。ユーザー名とパスワードを入力してください。';

  @override
  String get smbNoAccess => 'アクセスできません';

  @override
  String smbShareGone(String name) {
    return '$name はもうありません。';
  }

  @override
  String smbReadingFiles(String name) {
    return '$name のファイルを読み込んでいます…';
  }

  @override
  String smbScanningFolders(String name, int count) {
    return '$name を確認中：$count フォルダ…';
  }

  @override
  String smbShareOnHost(String share, String host) {
    return '$host の $share';
  }

  @override
  String get smbNotAnAddress =>
      '共有フォルダのアドレスではありません。smb://コンピューター/共有名 または \\\\コンピューター\\共有名 の形で入力してください。';

  @override
  String smbCantReach(String host) {
    return '$host に接続できません。';
  }

  @override
  String smbAnotherShare(String name) {
    return 'これは $name とは別の共有フォルダです。';
  }

  @override
  String get smbMapOne => '少なくとも 1 つのフォルダの中身を選んでください。';

  @override
  String get smbShareButton => 'SMB 共有フォルダ';

  @override
  String get smbFindTitle => '共有フォルダを追加';

  @override
  String get smbFindHelp => 'コンピューターか NAS を選ぶか、共有フォルダのアドレスを入力してください。';

  @override
  String get smbAddress => '共有フォルダのアドレス';

  @override
  String get smbSearching => 'コンピューターを探しています…';

  @override
  String get smbSearchAgain => 'もう一度探す';

  @override
  String get smbNoneFound => 'コンピューターが見つかりません。共有フォルダのアドレスを入力してください。';

  @override
  String smbSharesOn(String host) {
    return '$host の共有フォルダ';
  }

  @override
  String smbNoShares(String host) {
    return '$host には開ける共有フォルダがありません。';
  }

  @override
  String get smbOld => 'SMB1：古く、暗号化されていません';

  @override
  String smbSignInTo(String host) {
    return '$host にサインイン';
  }

  @override
  String get smbDomain => 'ドメイン（任意）';

  @override
  String get smbAsGuest => 'ゲストとして接続';

  @override
  String smbWhatsIn(String share) {
    return '$share の中身は？';
  }

  @override
  String get smbMapHelp =>
      '各フォルダの中身を選んでください。「なし」のフォルダは使いません。選んだフォルダの中のフォルダは別のものを選べます。フォルダ名で OK を押すと開きます。';

  @override
  String get smbTypeNone => 'なし';

  @override
  String get smbTypeTv => 'テレビ番組';

  @override
  String get smbTypeMovies => '映画';

  @override
  String get smbTypeMusic => '音楽';

  @override
  String get smbTypeMusicVideos => 'ミュージックビデオ';

  @override
  String get smbTypeHome => 'ホームビデオ';

  @override
  String get smbTypeCommercials => 'CM';

  @override
  String get smbTypeBumpers => 'ジングル';

  @override
  String smbAsAbove(String type) {
    return '$type（上と同じ）';
  }

  @override
  String get smbUp => '1 つ上のフォルダ';

  @override
  String get smbHistoryName => '履歴の名前';

  @override
  String get smbHistoryHelp =>
      '同じ履歴の名前を使うテレビは、再生回数と続きから再生する位置を共有します。共有フォルダの隠しフォルダ .nightingale に保存され、それ以外は何も変更しません。';

  @override
  String get smbKeepLocal => '履歴をこのデバイスに保存';

  @override
  String get smbReadOnly => 'この共有フォルダは読み取り専用です。履歴はこのデバイスに保存されます。';

  @override
  String get smbFoldersDone => '完了';

  @override
  String smbFilesLeft(int count) {
    return '$count 個のファイルを読み込み中';
  }

  @override
  String smbHistoryOnShare(String name) {
    return '履歴：共有フォルダ上の「$name」';
  }

  @override
  String get smbHistoryOnDevice => '履歴：このデバイス';

  @override
  String get smbHistoryReadOnly => '履歴：このデバイス（共有フォルダは読み取り専用）';

  @override
  String get smbFolders => 'フォルダ';

  @override
  String smbCantPlay(int count) {
    return '再生できないファイル（$count）';
  }

  @override
  String smbCantPlayTitle(String name) {
    return '再生できないファイル · $name';
  }

  @override
  String get smbCantPlayHelp =>
      'これらのファイルは番組表に入りません。ファイルを直したり、変換できる Nightingale TV とペアリングしたりしたら、もう一度確認してください。';

  @override
  String get smbCheckAgain => 'もう一度確認';

  @override
  String get smbCantPlayNone => 'すべてのファイルを再生できます。';

  @override
  String get smbReasonDamaged => '破損しています';

  @override
  String get smbReasonNoVideo => '映像がありません';

  @override
  String get smbReasonTooMuch => 'このデバイスには重すぎ、変換できる Nightingale TV もありません';

  @override
  String smbRenameTitle(String name) {
    return '$name の名前を変更';
  }

  @override
  String smbFoldersTitle(String name) {
    return 'フォルダ · $name';
  }

  @override
  String get smbSave => '保存';

  @override
  String get smbQualityNote =>
      '共有フォルダのファイルは、ペアリングした別の Nightingale TV が合うように変換します。ない場合はそのまま再生します。このデバイスで変換してもネットワークの負担は減らないためです。';

  @override
  String get smbHomeCantShare => 'ホームビデオは共有できません';

  @override
  String get smbHomeVideo => 'ホームビデオ';

  @override
  String get licencesTitle => 'ライセンス';

  @override
  String get licencesHelp =>
      'Nightingale TV は GNU GPL 3 のフリーソフトウェアです。以下のソフトウェアを、それぞれのライセンスのもとで使用しています。';

  @override
  String get colorPurple => '紫';

  @override
  String get colorGreen => '緑';

  @override
  String get colorAmber => '琥珀';

  @override
  String get colorTeal => '青緑';

  @override
  String get colorMagenta => 'マゼンタ';

  @override
  String get colorOlive => 'オリーブ';

  @override
  String get colorSlate => 'スレート';

  @override
  String get colorCocoa => 'ココア';

  @override
  String get colorWine => 'ワインレッド';

  @override
  String get guideColor => '番組表での色';

  @override
  String guideColorTitle(String name) {
    return '番組表での色 · $name';
  }

  @override
  String get guideColorHelp => 'このサーバーの番組は、番組表でこの色になります。';

  @override
  String guideColorUsedBy(String color, String name) {
    return '$color · $name';
  }

  @override
  String get serverColorsSetting => '番組表のサーバー別の色';

  @override
  String get serverColorsHelp => '各番組が再生元のサーバーの色になり、番組表の下に凡例が表示されます。';

  @override
  String playsFrom(String name) {
    return '$name から';
  }

  @override
  String get convertForOthers => '他のテレビのために変換';

  @override
  String get convertForOthersHelp =>
      '共有フォルダのファイルを再生できないテレビは、このコンピューターに変換を頼みます。このコンピューターのプロフィールにも同じ共有フォルダが必要で、割り当てたフォルダのファイルだけを変換します。';

  @override
  String convertCode(String code) {
    return 'ペアリングコード：$code';
  }

  @override
  String get convertPairedTvs => 'ペアリングしたテレビ';

  @override
  String get convertNoTvs => 'ペアリングしたテレビはまだありません。';

  @override
  String get convertHelpers => '他の Nightingale TV で変換';

  @override
  String get convertHelpersHelp =>
      'コンピューターの Nightingale TV や Docker サーバーは、このデバイスで再生できない、または十分に速く再生できない共有フォルダのファイルを変換できます。そちらで「他のテレビのために変換」をオンにし、表示されたコードでペアリングしてください。';

  @override
  String get convertFind => 'ネットワークで探す';

  @override
  String get convertTypeAddress => 'アドレスを入力';

  @override
  String get convertAddress => 'Nightingale TV のアドレス';

  @override
  String convertEnterCode(String name) {
    return '$name に表示されたコード';
  }

  @override
  String convertWrongCode(String name) {
    return 'コードが違うか、$name が応答しませんでした。';
  }

  @override
  String get convertNoneFound =>
      '変換できる Nightingale TV が見つかりません。そちらで「他のテレビのために変換」がオンか確認するか、アドレスを入力してください。';

  @override
  String convertAddShareOn(String share, String name) {
    return '$name に $share を追加してください';
  }

  @override
  String convertNotAnswering(String name) {
    return '$name が応答しません';
  }

  @override
  String get convertPair => 'ペアリング';

  @override
  String get serverKindsHelp =>
      'Jellyfin、Emby、Plex、YouTube、SMB 共有フォルダ（NAS やパソコンの共有フォルダ）を追加できます。';

  @override
  String get youTube => 'YouTube';

  @override
  String get youTubeTerms =>
      'サインインすると、YouTube 利用規約と Nightingale TV のプライバシーポリシーに同意したことになります。';

  @override
  String get youTubeTermsOfService => 'YouTube 利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String youTubeEnterCode(String address) {
    return 'スマートフォンかパソコンで $address を開き、このコードを入力してください。';
  }

  @override
  String get openGoogleDevice => 'google.com/device を開く';

  @override
  String get signInWasCancelled => 'サインインはキャンセルされました';

  @override
  String get youTubeChannelsTitle => 'YouTube チャンネル';

  @override
  String youTubePickedOf(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get notSubscribed => '登録していません';

  @override
  String get searchSubscriptions => '登録チャンネルを検索';

  @override
  String get noSubscriptions => 'このアカウントには登録チャンネルがありません';

  @override
  String get noSubscriptionsMatch => '一致する登録チャンネルはありません';

  @override
  String removeYouTubeChannels(String names) {
    return '$names を番組表から削除しますか？';
  }

  @override
  String youTubeChannelCount(int count) {
    return '$count チャンネル';
  }

  @override
  String get googleClient => 'Google クライアント';

  @override
  String get googleClientShared => 'Nightingale TV のもの';

  @override
  String get googleClientOwn => '自分のもの';

  @override
  String youTubeDailyLimit(String time) {
    return 'YouTube の 1 日の上限に達しました。新しい動画は $time 以降に届きます。';
  }

  @override
  String get useMyOwnClient => '自分のクライアントを使う';

  @override
  String get signInToYouTubeAgain => 'YouTube にもう一度サインインしてください';

  @override
  String get ownClientTitle => '自分の Google クライアント';

  @override
  String get clientId => 'クライアント ID';

  @override
  String get clientSecret => 'クライアント シークレット';

  @override
  String get openClientFile => 'ファイルを開く';

  @override
  String get clientFileNotRead => 'このファイルは Google クライアントのファイルではありません';

  @override
  String get useThisClient => 'このクライアントを使う';

  @override
  String get useSharedClient => 'Nightingale TV のクライアントを使う';

  @override
  String get ownClientStep1 => 'console.cloud.google.com を開き、プロジェクトを作成します。';

  @override
  String get ownClientStep2 => 'YouTube Data API v3 を有効にします。';

  @override
  String get ownClientStep3 => 'OAuth 同意画面を設定し、youtube.readonly スコープを追加します。';

  @override
  String get ownClientStep4 => '公開ステータスを「本番環境」にします。';

  @override
  String get ownClientStep5 => '種類が「テレビと入力が限られたデバイス」の OAuth クライアントを作成します。';

  @override
  String get ownClientStep6 => 'ここにクライアント ID とシークレットを入力するか、ダウンロードしたファイルを開きます。';

  @override
  String ownClientGuide(String address) {
    return '詳しい手順: $address';
  }

  @override
  String get clientRefused =>
      'Google がこのクライアントを受け付けませんでした。種類は「テレビと入力が限られたデバイス」である必要があります。';

  @override
  String get noVideosYet => 'まだ動画がありません';

  @override
  String get youTubeRefusedPlayer => 'YouTube がこのプレーヤーを受け付けませんでした';

  @override
  String get youTubeNeedsWebView => 'YouTube には Android System WebView が必要です';

  @override
  String getItFromPlayStore(String address) {
    return 'Play ストアで入手: $address';
  }

  @override
  String youTubeChannelSource(String title) {
    return 'YouTube チャンネル: $title';
  }

  @override
  String publishedOn(String date) {
    return '公開日: $date';
  }

  @override
  String get youTubeCantBeShared => 'YouTube チャンネルは共有できません';

  @override
  String get youTubeAlreadyRemovedQuota =>
      'YouTube の 1 日の上限がリセットされてから、もう一度お試しください。';

  @override
  String get youTubeAccount => 'YouTube アカウント';

  @override
  String get couldNotReachGoogle => 'Google に接続できませんでした。もう一度お試しください。';

  @override
  String get youTubeDailyLimitShort => 'YouTube の 1 日の上限に達しました。';

  @override
  String get youTubeNoBreaks => 'YouTube チャンネルには CM 枠はありません。';

  @override
  String get youTubeNoBlocks => 'YouTube チャンネルには番組枠を設定できません。';

  @override
  String get youTubeAccessNeeded =>
      'Nightingale TV が YouTube の登録チャンネルを見られるようにする必要があります。新しいコードを入力して許可してください。';

  @override
  String get youTubeRemoveBody =>
      'その YouTube チャンネルはチャンネル構成から外れ、Nightingale TV の YouTube アカウントへのアクセスは終了します。';

  @override
  String get playerQuality => '画質';

  @override
  String playerQualityValue(String value) {
    return '画質：$value';
  }

  @override
  String get playerQualityAuto => '自動';

  @override
  String get playerQualityOriginal => 'オリジナル';

  @override
  String playerQualityMbps(int mbps) {
    return '$mbps Mbps';
  }

  @override
  String get youTubeNoClient =>
      'このビルドには YouTube クライアントがありません。追加方法は README に書かれています。';

  @override
  String youTubeSharedLimit(int limit) {
    return 'Nightingale TV のクライアントで追加できる YouTube チャンネルは $limit 個までです。さらに追加するには、サーバー → YouTube → Google クライアントで自分のクライアントを使ってください。';
  }

  @override
  String youTubeSharedTooMany(int limit) {
    return 'Nightingale TV のクライアントで追加できる YouTube チャンネルは $limit 個までです。先に「チャンネル」でいくつか外してください。';
  }

  @override
  String lastBackedUp(Object when) {
    return '前回のバックアップ：$when';
  }

  @override
  String get notBackedUpYet => 'まだバックアップされていません。';

  @override
  String get undoRestore => '復元を元に戻す';

  @override
  String get undoLineupReset => 'ラインナップのリセットを元に戻す';

  @override
  String undoDeleting(Object name) {
    return '$name の削除を元に戻す';
  }

  @override
  String get undoDeletingAProfile => 'プロフィールの削除を元に戻す';

  @override
  String get undoUpdate => 'アップデートを元に戻す';

  @override
  String get undoLineupCleanup => 'ラインナップの整理を元に戻す';

  @override
  String undoTitle(Object action, Object time) {
    return '$action · $time';
  }

  @override
  String undoPointSaved(Object when, Object profiles) {
    return '$when に保存：$profiles';
  }

  @override
  String get pickThePlaylistFileAgain => 'プレイリストのファイルをもう一度選んでください';

  @override
  String get pickTheGuideFileAgain => '番組表のファイルをもう一度選んでください';

  @override
  String get playlistFileNotOnDevice => 'プレイリストのファイルがこのデバイスにありません';

  @override
  String get guideFileNotOnDevice => '番組表のファイルがこのデバイスにありません';

  @override
  String get youTubeServerOwnClient => 'サーバーモードでは自分の Google クライアントを使います。';

  @override
  String get uploadJsonFile => 'JSON ファイルをアップロード';

  @override
  String get continueStep => '続行';

  @override
  String get watchNoChannels =>
      'このプロフィールには YouTube チャンネルがありません。サーバーで YouTube を追加してください。';
}
