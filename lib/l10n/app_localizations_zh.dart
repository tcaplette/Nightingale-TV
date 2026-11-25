// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get onlyChannelsYou => '只能删除你自己添加的频道。可以改为隐藏这个频道。';

  @override
  String get music => '音乐';

  @override
  String get nothingInThe => '媒体库中没有符合条件的内容。';

  @override
  String get chooseSongsOr => '请选择歌曲或音乐视频。';

  @override
  String get blockChannel => '节目时段频道';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return '这与同一频道上的“$title”（$clash）重叠。';
  }

  @override
  String get chooseSomeShows => '请为这个节目时段选择要播放的节目或电影。';

  @override
  String nothingInThis(Object shortLabel) {
    return '这个组合中没有分级为 $shortLabel 或更高的内容。请选择更低的分级或其他节目。';
  }

  @override
  String get theLineupsShows => '频道列表中的节目没有任何剧集。请选择其他节目。';

  @override
  String get addAShow => '请向频道列表添加一个节目。';

  @override
  String get chooseAChannel => '请选择一个频道。';

  @override
  String get theBlockHas => '节目时段的结束时间必须与开始时间不同。';

  @override
  String get pickAtLeast => '请至少选择一天。';

  @override
  String get giveTheBlock => '请为节目时段输入标题。';

  @override
  String get thisChannelDoesnt => '这个频道没有时段。';

  @override
  String get onlyShuffledChannels => '只有随机播放的频道才能重新随机排列。';

  @override
  String get chooseSomethingFor => '请选择这个频道要播放的内容。';

  @override
  String get onlyChannelsYouAdded => '只有你自己添加的频道才能更改播放内容。';

  @override
  String get myChannel => '我的频道';

  @override
  String get noneOfYour => '无法连接到你的任何服务器。';

  @override
  String scanning(Object where) {
    return '正在扫描 $where…';
  }

  @override
  String get buildingChannels => '正在创建频道…';

  @override
  String get notSignedIn => '尚未登录。';

  @override
  String isAlreadyIn(Object name) {
    return '$name 已在这个个人资料中';
  }

  @override
  String get thatServerIs => '这个服务器已不在这个个人资料中';

  @override
  String get yourSessionExpired => '你的会话已过期。请重新登录。';

  @override
  String get m3uPlaylist => 'M3U 播放列表';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName 没有直播电视频道';
  }

  @override
  String couldntReach(Object serverName) {
    return '无法连接到 $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return '$serverName 直播电视';
  }

  @override
  String liveTvIs(Object serverName) {
    return '$serverName 直播电视已经是一个来源';
  }

  @override
  String get notSignedIn2 => '尚未登录';

  @override
  String get newGroup => '新建素材组';

  @override
  String get thisBackupIs => '这个备份已损坏：无法读取其中一个频道标志。';

  @override
  String get thisBackupIsDamaged => '这个备份已损坏：无法读取其中的直播电视导出设置。';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return '这个备份已损坏：无法读取 $name 的$what。';
  }

  @override
  String get liveTvSources => '直播电视来源';

  @override
  String thisBackupCant(Object problem) {
    return '无法恢复这个备份。$problem';
  }

  @override
  String get thisBackupIsDamagedIts => '这个备份已损坏：无法读取其中的个人资料。';

  @override
  String get thisFileIs => '这个文件太大，不可能是 Nightingale TV 备份。';

  @override
  String get thisBackupWas => '这个备份是由更新版本的 Nightingale TV 创建的。';

  @override
  String get thisFileIsnt => '这个文件不是 Nightingale TV 备份，或者已损坏。';

  @override
  String restoredTheBackup(Object toLocal) {
    return '已恢复 $toLocal 的备份。';
  }

  @override
  String couldntRestoreThe(Object e) {
    return '无法恢复备份：$e';
  }

  @override
  String couldntSaveA(Object e) {
    return '无法先保存备份：$e';
  }

  @override
  String get automatic => '自动';

  @override
  String get nc1718 => 'NC-17 / 18 岁及以上';

  @override
  String get tvMaR => 'TV-MA / R 及以上';

  @override
  String get tv14Pg => 'TV-14 / PG-13 及以上';

  @override
  String get off => '关';

  @override
  String get nowAndThen => '偶尔';

  @override
  String get always => '始终';

  @override
  String get truncate => '提前结束';

  @override
  String get offlineImage => '离线图片';

  @override
  String get filler => '填充';

  @override
  String get leastWatchedFirst => '最少观看的优先';

  @override
  String get shuffled => '随机';

  @override
  String get inOrderShows => '按顺序（节目轮流播放）';

  @override
  String get channelsWhereEverything =>
      '所有播放内容（包括节目时段）均为 TV-Y、TV-Y7、TV-G 或 G 级的频道。';

  @override
  String get musicVideoAnd => '音乐视频和电台频道。';

  @override
  String get channelsThatPlay => '只播放电影、不播放剧集或音乐的频道。';

  @override
  String get channelsFromYour => '来自你的直播电视来源的频道。';

  @override
  String get channelsYouMarked => '你收藏的频道。';

  @override
  String get everyChannel => '所有频道。';

  @override
  String get kids => '儿童';

  @override
  String get movies => '电影';

  @override
  String get liveTv2 => '直播电视';

  @override
  String get favorites => '收藏';

  @override
  String get all => '全部';

  @override
  String get theAccentsAre => '强调色是一个主题，每项为 theme 或 channel。';

  @override
  String get thoseArentRetro => '这些不是复古设置。';

  @override
  String get theOverlayTheme => '叠加层主题为 standard、vcr、cableBox 或 stationIdent。';

  @override
  String get theCrtEffect =>
      'CRT 效果为 off、softTube、livingRoom、arcade、studioMonitor 或 custom。';

  @override
  String get theSurroundImage => '边框图片是一个文件名。';

  @override
  String get theSurroundIs => '边框为 black、charcoal、channel 或 image。';

  @override
  String get thePictureShape => '画面形状为 original、fill43 或 fit43。';

  @override
  String get channelColor => '频道颜色';

  @override
  String get theme => '主题';

  @override
  String get stationIdent => '台标';

  @override
  String get cableBox => '有线电视盒';

  @override
  String get vcr => '录像机';

  @override
  String get standard => '标准';

  @override
  String get custom => '自定义';

  @override
  String get studioMonitor => '演播室监视器';

  @override
  String get arcade => '街机';

  @override
  String get livingRoom => '客厅';

  @override
  String get softTube => '柔和显像管';

  @override
  String get customColorIs => '自定义颜色为 natural、warm、faded 或 vivid。';

  @override
  String get customLinesIs => '自定义扫描线为 240 或 480。';

  @override
  String customIsOff(Object key) {
    return '自定义 $key 为 off、low、medium 或 high。';
  }

  @override
  String get thatIsntA => '这不是自定义样式。';

  @override
  String get vivid => '鲜艳';

  @override
  String get faded => '褪色';

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
  String get image => '图片';

  @override
  String get charcoal => '炭灰';

  @override
  String get black => '黑色';

  @override
  String get n43Fit => '4:3 适应';

  @override
  String get n43Fill => '4:3 填满';

  @override
  String get original => '原始';

  @override
  String get thisChannelIs => '这个频道暂停播出';

  @override
  String get offAir => '暂停播出';

  @override
  String get tail => '填充';

  @override
  String get postRoll => '节目后';

  @override
  String get midRoll => '节目中';

  @override
  String get preRoll => '节目前';

  @override
  String get commercials => '广告';

  @override
  String get bumpers => '过场片段';

  @override
  String get pleaseStandBy => '请稍候';

  @override
  String get offTheAir => '暂停播出';

  @override
  String get wellBeRight => '马上回来';

  @override
  String upNextAt(Object at) {
    return '$at 接下来播出';
  }

  @override
  String backOnThe(Object next, Object title) {
    return '$next 恢复播出《$title》';
  }

  @override
  String get processor => '处理器';

  @override
  String get graphicsCardNvenc => '显卡（NVENC）';

  @override
  String get graphicsCardVaapi => '显卡（VAAPI）';

  @override
  String get signInTo => '请在电视上登录这个个人资料，以导出它的频道。';

  @override
  String get signInToThis => '请在这里登录这个个人资料，以导出它的频道。';

  @override
  String portIsIn(Object port) {
    return '端口 $port 已被其他程序占用。请选择其他端口，然后在 Plex、Jellyfin 或 Emby 中更新它。';
  }

  @override
  String anotherProfileAlready(Object port) {
    return '另一个个人资料已在使用端口 $port。';
  }

  @override
  String get pickAPort => '请选择 1024 到 65535 之间的端口。';

  @override
  String get movie => '电影';

  @override
  String backOnTheAir(Object start, Object title) {
    return '$start 恢复播出《$title》。';
  }

  @override
  String get images => '图片';

  @override
  String get couldNotRead => '无法读取这张图片。请尝试 PNG、JPG、WebP 或 SVG。';

  @override
  String get thatFileIs => '这个文件不是有效的 SVG。';

  @override
  String get thatImageIs => '这张图片超过 20 MB。请选择更小的图片。';

  @override
  String get other => '其他';

  @override
  String get seasonsHolidays => '季节与节日';

  @override
  String get newsWeather => '新闻与天气';

  @override
  String get sports => '体育';

  @override
  String get genres => '类型';

  @override
  String get kidsFamily => '儿童与家庭';

  @override
  String get tvMovies => '电视与电影';

  @override
  String get theServerWould => '服务器拒绝转换这个项目。';

  @override
  String get theServerHas => '服务器没有这个项目的可播放版本。';

  @override
  String get externalLabel => '外部';

  @override
  String get scanningChannelSources => '正在扫描频道来源…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl 的响应不像 Jellyfin 服务器。';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return '在 $serverUrl 找不到 Jellyfin 服务器。$message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return '$path 出现服务器错误 $statusCode。';
  }

  @override
  String get wrongUsernameOr => '用户名或密码错误，或者会话已过期。';

  @override
  String couldNotReach(Object e) {
    return '无法连接到服务器（$e）。';
  }

  @override
  String get theServerTook => '服务器响应时间过长。';

  @override
  String get theServerWouldNot => '服务器拒绝转换这个频道。';

  @override
  String get musicVideo => '音乐视频';

  @override
  String movie2(Object year) {
    return '电影 · $year';
  }

  @override
  String get commercial => '广告';

  @override
  String couldntReachThe(Object what) {
    return '无法连接到$what';
  }

  @override
  String theIsToo(Object what) {
    return '$what太大';
  }

  @override
  String theSAddress(Object what) {
    return '$what的地址不是网址';
  }

  @override
  String get noGuideInformation => '没有节目信息';

  @override
  String get serverLiveTv => '服务器直播电视';

  @override
  String get theChannelHas => '这个频道没有流地址。';

  @override
  String get couldntReadThe => '无法读取节目指南';

  @override
  String get couldntReachTheGuide => '无法连接到节目指南';

  @override
  String get theSourceHas => '这个来源没有播放列表';

  @override
  String get couldntReachThePlaylist => '无法连接到播放列表';

  @override
  String get couldntReadThePlaylist => '无法读取播放列表文件';

  @override
  String couldntRefresh(Object name) {
    return '无法刷新 $name';
  }

  @override
  String get thePlaylistHas => '播放列表中没有频道';

  @override
  String get thatIsntAn => '这不是 M3U 播放列表';

  @override
  String get thatIsntAnXmltv => '这不是 XMLTV 节目指南';

  @override
  String get theGuideIs => '节目指南太大（超过 1 GB）';

  @override
  String get nightingaleTvBackups => 'Nightingale TV 备份';

  @override
  String get uninstallingThisApp => '卸载这个应用会删除它的个人资料、频道和设置，除非你事先备份或迁移它们。';

  @override
  String theStoreVersion(Object officialName) {
    return 'Google Play 版本会作为单独的应用“$officialName”与这个应用并存安装，并有自己的设置。它可免费使用 14 天，之后一次性购买即可支持这个项目。安装后，你可以从这里把设置迁移过去。';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return '来自 Google Play 和官方 Nightingale TV APK 的更新会覆盖安装这个应用，并保留你的设置。你自己构建的版本会作为单独的应用“$ownBuildName”安装，你可以从这里把设置迁移过去。';
  }

  @override
  String get yourOwnBuild => '你自己构建的版本';

  @override
  String get officialNightingaleTv => '官方 Nightingale TV APK';

  @override
  String get installedFromGoogle => '从 Google Play 安装';

  @override
  String get nightingaleTvOwn => 'Nightingale TV（自行构建版）';

  @override
  String get sleepTimerOff => '睡眠定时器已关闭';

  @override
  String get sleepAtEnd => '节目结束时睡眠';

  @override
  String sleepInMin(Object minutes) {
    return '$minutes 分钟后睡眠';
  }

  @override
  String get forced => '强制';

  @override
  String get unknownLanguage => '未知语言';

  @override
  String didntStart(Object name) {
    return '$name 未能启动';
  }

  @override
  String get thisDeviceCant => '这台设备无法播放这个频道的视频';

  @override
  String get thisChannelsStream => '这台设备不支持这个频道的流类型';

  @override
  String refusedTheStream(Object name) {
    return '$name 拒绝了视频流。它可能正在另一台设备上播放。';
  }

  @override
  String yourAccountCant(Object server) {
    return '你的 $server 账户无法观看这个频道';
  }

  @override
  String cantReach(Object name) {
    return '无法连接到 $name';
  }

  @override
  String allOfS(Object server) {
    return '$server 的所有调谐器都在使用中';
  }

  @override
  String lostTheSignal(Object name) {
    return '$name 信号中断';
  }

  @override
  String get couldntPlayThat => '无法播放这一段。正在返回直播';

  @override
  String get backToLive => '返回直播';

  @override
  String get theServerTookToo => '服务器开始转换这个节目的时间过长。';

  @override
  String get nothingToPlay => '这个频道没有可播放的内容';

  @override
  String captionsOn(Object shown) {
    return '字幕已开启：$shown';
  }

  @override
  String get captionsOn2 => '字幕已开启';

  @override
  String get captionsOnNo => '字幕已开启：这个节目没有字幕';

  @override
  String get captionsOff => '字幕已关闭';

  @override
  String get guest => '访客';

  @override
  String get thereHasTo => '必须至少有一个成人个人资料。';

  @override
  String kidProfilesNeedPins(Object names) {
    return '只要还有儿童个人资料，每个成人个人资料都需要设置 PIN，以免儿童切换进去。请为 $names 设置 PIN。';
  }

  @override
  String get switchToAnother => '删除这个个人资料前，请先切换到另一个个人资料。';

  @override
  String get me => '我';

  @override
  String get couldntOpenA => '无法为遥控器打开网络端口。';

  @override
  String get notPaired => '未配对';

  @override
  String get phone => '手机';

  @override
  String get thatCodeDoesnt => '代码不匹配。请核对电视上显示的代码。';

  @override
  String get openMenuPhone => '请在电视上打开“菜单”→“手机遥控器”进行配对';

  @override
  String yourAccountCantWatch(Object serverName) {
    return '你的 $serverName 账户无法观看直播电视';
  }

  @override
  String get enterYourServer => '请输入服务器地址。';

  @override
  String get needsSignIn => '需要登录';

  @override
  String get cantBeReached => '无法连接';

  @override
  String isNotAnswering(Object name) {
    return '$name 的所有地址都没有响应。它开机了吗？';
  }

  @override
  String get everyServerOn => '这个 Plex 账户上的所有服务器都已在这个个人资料中。';

  @override
  String get thisPlexAccount => '这个 Plex 账户没有服务器。请让服务器的所有者与你共享。';

  @override
  String quickConnectStopped(Object message) {
    return '快速连接已停止：$message';
  }

  @override
  String get enterYourUsername => '请输入用户名。';

  @override
  String get plexDidNot => 'Plex 未能切换用户。';

  @override
  String plexTvError(Object statusCode) {
    return 'plex.tv 错误 $statusCode。';
  }

  @override
  String get yourPlexSign => '你的 Plex 登录已过期。';

  @override
  String couldNotReachPlex(Object e) {
    return '无法连接到 plex.tv（$e）。';
  }

  @override
  String get plexTvTook => 'plex.tv 响应时间过长。';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — 由 $ownerName 共享';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return '服务器拒绝转换这个项目（$transcodeDecisionText）。';
  }

  @override
  String get theServerHasNo => '服务器上没有这个项目的文件；请刷新媒体库。';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl 的响应不像 Plex 服务器。';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return '在 $serverUrl 找不到 Plex 服务器。$message';
  }

  @override
  String get thePlexSign => 'Plex 登录已过期。';

  @override
  String channelIsNot(Object channelId) {
    return '频道 $channelId 不在任何 DVR 上。';
  }

  @override
  String get noSuchUser => '没有这个用户。';

  @override
  String get yourCurrentPassword => '当前密码错误。';

  @override
  String get signInFirst => '请先登录。';

  @override
  String thereIsAlready(Object name) {
    return '已经有名为 $name 的用户。';
  }

  @override
  String get thisAccountIs => '这个账户已停用。';

  @override
  String get chooseAnAdmin => '请选择一个管理员账户。';

  @override
  String useAtMost(Object maxNameLength) {
    return '用户名最多 $maxNameLength 个字符。';
  }

  @override
  String get enterAUser => '请输入用户名。';

  @override
  String useAtLeast(Object minPasswordLength) {
    return '请至少使用 $minPasswordLength 个字符。';
  }

  @override
  String get tooManyWrong => '密码错误次数过多。请一分钟后再试。';

  @override
  String get wrongUserName => '用户名或密码错误。';

  @override
  String get openTheSetup => '请打开服务器日志中的设置链接。';

  @override
  String get makeSomeoneElse => '请先将其他人设为管理员。';

  @override
  String get noSuchProfile => '没有这个个人资料。';

  @override
  String get onlyAnAdmin => '只有管理员才能这样做。';

  @override
  String get thatProfileIsnt => '这个个人资料没有分配给你。';

  @override
  String get enterAGrown => '要更改儿童个人资料的设置，请输入成人的 PIN。';

  @override
  String get enterThisProfiles => '请输入这个个人资料的 PIN。';

  @override
  String get reloadThePage => '请重新加载页面后再试。';

  @override
  String somethingWentWrong(Object e) {
    return '出现问题：$e';
  }

  @override
  String get signInToThisProfile => '请先登录这个个人资料。';

  @override
  String get changedInAnother => '已在另一个窗口中更改。正在显示最新内容。';

  @override
  String get wrongPin => 'PIN 错误。';

  @override
  String get tooManyWrongPins => 'PIN 错误次数过多。请一分钟后再试。';

  @override
  String get theRoleIs => '角色为“admin”或“user”。';

  @override
  String get noSuchBackup => '没有这个备份。';

  @override
  String get backupsAreOff => '备份已关闭。';

  @override
  String get noSuchEncoder => '没有这个编码器。';

  @override
  String get allow1To => '请允许 1 到 16 路流。';

  @override
  String get noSuchQuality => '没有这个画质。';

  @override
  String get processorOnly => '仅处理器';

  @override
  String get liveTvExport => '直播电视导出未在运行。';

  @override
  String get thoseArentPremiere => '这些不是首播设置。';

  @override
  String get theLogoMode => '标志模式为 always、nowAndThen 或 off。';

  @override
  String get thatIsntAPicture => '这不是自定义标志文件夹中的图片。';

  @override
  String couldntSaveBackupNothingReset(Object e) {
    return '无法先保存备份，因此没有重置任何内容：$e';
  }

  @override
  String get theKindIs => '类型为“block”、“music”或“custom”。';

  @override
  String get thatIsntAPlay => '这不是播放顺序。';

  @override
  String get musicChannelsOnly => '音乐频道只能随机播放。';

  @override
  String get channelNumbersStart => '频道号从 1 开始。';

  @override
  String get slotLengthsAre => '时段长度为 15、30、60、90 或 120 分钟。';

  @override
  String get thatIsntAChannel => '这不是频道。';

  @override
  String get noSuchChannel => '没有这个频道。';

  @override
  String get thatPictureIs => '这张图片太大（最大 5 MB）。';

  @override
  String get unknownAction => '未知操作。';

  @override
  String get noSuchServer => '没有这个服务器。';

  @override
  String get startSigningIn => '请先开始登录。';

  @override
  String get aRestoreIs => '已有恢复正在进行。';

  @override
  String get uploadTheBackup => '请重新上传备份。';

  @override
  String get discoveryIsOff => '发现功能已关闭，请通过地址添加调谐器。要开启它，请以主机网络模式运行容器。';

  @override
  String get sendKeys => '请发送按键。';

  @override
  String get enterThePlaylists => '请输入播放列表的地址，或选择播放列表文件';

  @override
  String get uploadTheFile => '请重新上传文件。';

  @override
  String get kidProfilesGet => '儿童个人资料没有直播频道。';

  @override
  String liveTvIsAlready(Object name) {
    return '$name 直播电视已添加';
  }

  @override
  String get noSuchSource => '没有这个来源。';

  @override
  String get thatFileIsToo => '这个文件太大（最大 32 MB）。';

  @override
  String get aPinIs => 'PIN 为 4 位数字。';

  @override
  String get noSuchRating => '没有这个分级。';

  @override
  String get noSuchKind => '没有这个类型。';

  @override
  String get onlyAnAdminCan => '只有管理员才能更改这一项。';

  @override
  String shouldBeA(Object key) {
    return '“$key”应为文本列表。';
  }

  @override
  String shouldBeAn(Object key) {
    return '“$key”应为对象。';
  }

  @override
  String shouldBeTrue(Object key) {
    return '“$key”应为 true 或 false。';
  }

  @override
  String shouldBeANumber(Object key) {
    return '“$key”应为数字。';
  }

  @override
  String shouldBeText(Object key) {
    return '“$key”应为文本。';
  }

  @override
  String get expectedAJson => '需要 JSON 对象。';

  @override
  String get thatIsToo => '一次发送的内容太多。';

  @override
  String get aQualityLimit => '画质上限至少为 500 kbps。';

  @override
  String get orderShouldName => '“order”应包含每个服务器各一次。';

  @override
  String get orderIsMissing => '缺少“order”。';

  @override
  String get signOutOf => '要更改主服务器，请先退出这个个人资料。';

  @override
  String get thoseArentPool => '这些不是素材组文件夹。';

  @override
  String get sendRoots => '请发送根目录。';

  @override
  String get thatIsntAPool => '这不是素材组类型。';

  @override
  String get giveThePool => '请为素材组命名。';

  @override
  String get liveChannelsHave => '直播频道没有广告时间。';

  @override
  String get sendAPlan => '请发送方案。';

  @override
  String get thatIsntABreak => '这不是广告时间方案。';

  @override
  String get noSuchPool => '没有这个素材组。';

  @override
  String get thatIsntAProgramming => '这不是节目时段。';

  @override
  String get noSuchBlock => '没有这个节目时段。';

  @override
  String get sendEveryTab => '请将每个标签页各发送一次。';

  @override
  String get sendChannelids => '请发送 channelIds。';

  @override
  String get giveTheGroup => '请为分组命名。';

  @override
  String get noSuchGroup => '没有这个分组。';

  @override
  String get restoringBringsBack =>
      '恢复后会找回你的个人资料、频道、节目时段和设置。每个个人资料需要登录一次它的服务器。';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels 个频道',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup => '这台设备上有你的设置备份：';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get moveOkSelect => '◀▶ 移动    OK 选择';

  @override
  String get startFresh => '重新开始';

  @override
  String get restoreIt => '恢复';

  @override
  String get couldntRestore => '无法恢复';

  @override
  String get cancel => '取消';

  @override
  String get useYourPhone => '使用手机或电脑';

  @override
  String get openABackup => '打开备份文件';

  @override
  String get setUpThis =>
      '用 Nightingale TV 备份设置这台电视：你的个人资料、频道、节目时段和设置。每个个人资料需要登录一次它的服务器。';

  @override
  String get restoreFromA => '从备份恢复';

  @override
  String get close => '关闭';

  @override
  String get thereYouCan =>
      '你可以在那里下载这台电视的备份，或发送一个备份到这里恢复。发送的任何内容都会先在这台电视上确认。关闭这个窗口后，页面也会关闭。';

  @override
  String get onAPhone => '在与这台电视连接同一 Wi-Fi 的手机、平板电脑或电脑上，扫描二维码或打开：';

  @override
  String get couldntOpenANetwork => '无法为这个页面打开网络端口。';

  @override
  String get thePageStopped => '页面在 15 分钟无操作后已停止。请关闭后重新打开。';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount和$last';
  }

  @override
  String get listSeparator => '、';

  @override
  String labelValue(Object label, Object value) {
    return '$label：$value';
  }

  @override
  String get restore => '恢复';

  @override
  String get liveTvExportMoves => '直播电视导出将转移到这台设备；请在旧设备上将其关闭。';

  @override
  String willNeedTo(Object need) {
    return '$need 需要重新登录服务器。';
  }

  @override
  String get itSetsUp => '它会按照备份中的内容设置这台电视。';

  @override
  String get itReplacesEverything => '它会替换这台电视上的所有内容。你当前的设置会先被备份。';

  @override
  String restoreTheBackup(Object toLocal) {
    return '要恢复 $toLocal 的备份吗？';
  }

  @override
  String get delete => '删除';

  @override
  String get saveToFile => '保存到文件';

  @override
  String get moveOkSelectEsc => '▲▼◀▶ 移动    OK 选择    ESC 返回';

  @override
  String get backupRestore => '备份与恢复';

  @override
  String get aBackupHolds =>
      '备份包含每个个人资料及其频道、节目时段、广告和设置。每次有更改时都会保持最新。登录密码永远不会包含在内。';

  @override
  String couldntSaveThe(Object e) {
    return '无法保存备份：$e';
  }

  @override
  String thatDidntWork(Object e) {
    return '操作失败：$e';
  }

  @override
  String get aNewChannel => '新频道在节目时段之外暂停播出，就像夜间停播的电视台一样。';

  @override
  String get aNewChannelJust => '专为这个节目时段新建的频道';

  @override
  String get moveOkChoose => '▲▼ 移动    OK 选择    ESC 返回';

  @override
  String get chooseAChannel2 => '选择频道';

  @override
  String episodes(Object keyCount) {
    return '$keyCount 集';
  }

  @override
  String get moveOkAdd => '▲▼ 移动    OK 添加    ESC 返回';

  @override
  String get addAShow2 => '添加节目';

  @override
  String get remove => '移除';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 集',
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
  String get everyDay => '每天';

  @override
  String get weekends => '周末';

  @override
  String get weekdays => '工作日';

  @override
  String get days => '日期';

  @override
  String get starts => '开始';

  @override
  String get time => '时间';

  @override
  String get premieresAreOff => '首播已关闭';

  @override
  String get premieresAreOn => '首播已开启';

  @override
  String get onTheAir => '播出中';

  @override
  String get episodesAddedTo =>
      '最近两周添加到服务器的剧集，会在其节目频道的夜间时段首播：每晚每个节目播出一集新剧集，最长两小时，并标记为 NEW。节目时段优先。';

  @override
  String get moveOkSelectEscCancel => '▲▼◀▶ 移动    OK 选择    ESC 取消';

  @override
  String get newEpisodePremieres => '新剧集首播';

  @override
  String get theChannelGoes => '在这些时间，频道会恢复常规节目。';

  @override
  String delete2(Object title) {
    return '要删除“$title”吗？';
  }

  @override
  String get addAnotherShow => '再添加一个节目';

  @override
  String get missingShow => '缺失的节目';

  @override
  String runsThenStarts(Object start) {
    return '播放 $start，然后从头开始。';
  }

  @override
  String get fillsTheBlock => '填满节目时段。';

  @override
  String longerThanThe(Object end, Object title) {
    return '比节目时段长：它会在 $end 结束，截断 $title。';
  }

  @override
  String get onTheAirNow => '正在播出';

  @override
  String nextAiring(Object start) {
    return '下次播出 · $start';
  }

  @override
  String inAll(Object runtime) {
    return '共 $runtime';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies 部电影',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount 个节目',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => '还没有内容。请选择节目或电影。';

  @override
  String get nothingYetAdd => '还没有内容。请向频道列表添加节目。';

  @override
  String get plays => '播放内容';

  @override
  String onLabel(Object number, Object name) {
    return '在 $number $name 播出';
  }

  @override
  String get noChannelChosen => '未选择频道';

  @override
  String get onANew => '在新频道上（其他时间暂停播出）';

  @override
  String get untitledBlock => '未命名的节目时段';

  @override
  String get deleteBlock => '删除节目时段';

  @override
  String get blockIsOff => '节目时段已关闭';

  @override
  String get blockIsOn => '节目时段已开启';

  @override
  String get onlyShowsAnd => '只播放达到或高于这个分级的节目和电影。未分级的内容会被排除。';

  @override
  String get anyRating => '任意分级';

  @override
  String get minimumRating => '最低分级';

  @override
  String get chooseShowsMovies => '选择节目和电影';

  @override
  String get showsAndMovies => '你选择的节目和电影，按顺序或随机播放。';

  @override
  String get yourShowsIn => '按这个顺序播放你的节目，每次播出时各播下一集。如果还有剩余时间，频道列表会从头开始。';

  @override
  String get aLineup => '频道列表';

  @override
  String get aMix => '混合';

  @override
  String get whatItPlays => '播放内容';

  @override
  String get repeatsEveryYear => '每年重复。';

  @override
  String get to => '到';

  @override
  String get from => '从';

  @override
  String get onlyBetweenDates => '仅在指定日期之间';

  @override
  String get allYear => '全年';

  @override
  String get dates => '日期';

  @override
  String get nextDay => '（次日）';

  @override
  String get ends => '结束';

  @override
  String get channel => '频道';

  @override
  String get saturdayMorningCartoons => '周六早间动画';

  @override
  String get title => '标题';

  @override
  String get newProgrammingBlock => '新建节目时段';

  @override
  String get newLateNight => '新建深夜时段';

  @override
  String get editProgrammingBlock => '编辑节目时段';

  @override
  String next(Object next, Object next2) {
    return '下次：$next $next2';
  }

  @override
  String get onTheAirNow2 => '正在播出';

  @override
  String get noUpcomingAirings => '没有即将播出的节目';

  @override
  String get itsChannelIs => '它的频道已不存在。请选择新的频道。';

  @override
  String get turnedOff => '已关闭';

  @override
  String get blocksTakeOver => '节目时段会在你选择的日期和时间接管频道，比如周六早间动画。每次播出都会从上次停止的地方继续。';

  @override
  String get moveOkEdit => '▲▼ 移动    OK 编辑    ESC 返回';

  @override
  String get programmingBlocks => '节目时段';

  @override
  String get newlyAddedEpisodes => '新添加的剧集，在其节目的频道上';

  @override
  String get onLabel2 => '开';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips 个片段',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => '100 分钟电影';

  @override
  String get n44MinDrama => '44 分钟剧集';

  @override
  String get n22MinSitcom => '22 分钟情景喜剧';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: '，中间 $midCount 次广告',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name：无广告';
  }

  @override
  String get openAndClose => '广告时间的开头和结尾，来自设为过场片段的素材组';

  @override
  String get bumpers2 => '过场片段';

  @override
  String get toTheHalf => '补足到半点';

  @override
  String get toTheHour => '补足到整点';

  @override
  String get padsEachSlot => '将每个时段补足到整点，使节目准时开始';

  @override
  String get tail2 => '填充';

  @override
  String get afterEachProgram => '每个节目之后';

  @override
  String get postRoll2 => '节目后';

  @override
  String get length => '长度';

  @override
  String get every => '间隔';

  @override
  String min(Object inMinutes) {
    return '$inMinutes 分钟';
  }

  @override
  String get breaksInsideShows => '节目和电影中间的广告时间，尽量放在剧情转折处';

  @override
  String get midRoll2 => '节目中';

  @override
  String get beforeEachProgram => '每个节目之前';

  @override
  String get preRoll2 => '节目前';

  @override
  String get onePool => '一个素材组…';

  @override
  String get allBumperPools => '所有过场片段素材组';

  @override
  String get none => '无';

  @override
  String clipsFrom(Object pool) {
    return '片段来源：$pool';
  }

  @override
  String get allPools => '所有素材组';

  @override
  String clips2(Object label) {
    return '$label片段';
  }

  @override
  String get leave => '离开';

  @override
  String get yourChangesTo => '你对广告时间设置的更改将丢失。';

  @override
  String get leaveWithoutSaving => '不保存就离开吗？';

  @override
  String get size => '大小';

  @override
  String get captions => '字幕';

  @override
  String get sampleCaption => '字幕示例';

  @override
  String get theServerDraws => '这些字幕由服务器绘制到画面中，因此无法在这里更改大小。';

  @override
  String get findingSubtitles => '正在查找字幕…';

  @override
  String get noSubtitlesFor => '这个节目没有字幕';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours 小时 $inMinutes 分钟';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed 天';
  }

  @override
  String get theChannelGoesAway => '这个频道会连同它的节目时段及其在频道分组中的位置一起删除。';

  @override
  String remove2(Object name) {
    return '要移除“$name”吗？';
  }

  @override
  String contentOf(Object name) {
    return '$name 的内容';
  }

  @override
  String get newChannel => '新频道';

  @override
  String get defaultCard => '默认卡片';

  @override
  String get changeOfflineImage => '更改离线图片…';

  @override
  String get offlineImage2 => '离线图片…';

  @override
  String fillerPool(Object poolName) {
    return '填充素材组：$poolName';
  }

  @override
  String get slotLength => '时段长度';

  @override
  String get hideFromGuide => '从节目指南中隐藏';

  @override
  String get showInGuide => '在节目指南中显示';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String mainSetting(Object label) {
    return '主设置（$label）';
  }

  @override
  String get channelLogo => '频道标志';

  @override
  String breaksOn(Object name) {
    return '$name 的广告时间';
  }

  @override
  String get custom2 => '自定义…';

  @override
  String get commercials2 => '广告';

  @override
  String get removeChannel => '移除频道';

  @override
  String get reshuffle => '重新随机排列';

  @override
  String get editContent => '编辑内容';

  @override
  String get number => '频道号 +';

  @override
  String get number2 => '频道号 −';

  @override
  String get sourcesLogo => '来源的标志';

  @override
  String get changeIcon => '更改图标';

  @override
  String get rename => '重命名';

  @override
  String get channelName => '频道名称';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount 个节目时段',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return '每 $loop 重复一次';
  }

  @override
  String programs(Object playlistCount) {
    return '$playlistCount 个节目';
  }

  @override
  String get programmingBlocksOnly => '仅节目时段';

  @override
  String channelThere(Object n) {
    return '那里的频道 $n';
  }

  @override
  String channel2(Object number) {
    return '频道 $number';
  }

  @override
  String get noChannelsYet => '还没有频道';

  @override
  String get guideRange => '节目指南范围';

  @override
  String get channelsEditOk => '▲▼ 频道    ▶ 编辑    OK 选择    ESC 返回';

  @override
  String get channelsIcons => '频道和图标';

  @override
  String get howFarAhead => '节目指南从现在起显示多长时间。';

  @override
  String hours(Object hours) {
    return '$hours 小时';
  }

  @override
  String get theChannelLogo => '在电视和直播电视导出中，显示在画面角落的频道标志。';

  @override
  String get name => '名称';

  @override
  String get ok => '确定';

  @override
  String get channels2 => '频道';

  @override
  String get groupName => '分组名称';

  @override
  String group(Object name) {
    return '分组：$name';
  }

  @override
  String get deleteGroup => '删除分组';

  @override
  String get itsTabLeaves => '它的标签页会从节目指南中移除。频道仍保留在你的频道列表中。';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount 个频道',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => '你选择的频道。';

  @override
  String get theTabsAt => '节目指南顶部的标签页，按这个顺序排列。隐藏的标签页和没有频道的标签页不会显示。';

  @override
  String get channelGroups => '频道分组';

  @override
  String get shown => '显示';

  @override
  String get down => '下移';

  @override
  String get up => '上移';

  @override
  String get automatic2 => '· 自动';

  @override
  String channels4(Object channelIdsCount) {
    return '· $channelIdsCount 个频道';
  }

  @override
  String get create => '创建';

  @override
  String get commercialsNeverShow => '广告永远不会出现在服务器的观看记录中。';

  @override
  String get theSameAds => '每个人每次看到的都是相同的广告。';

  @override
  String get bumperPoolsClips => '过场片段素材组的片段用于广告时间的开头和结尾，不会作为广告播放。';

  @override
  String get howBreaksWork => '广告时间如何运作';

  @override
  String get withATail => '使用填充时，时段会被补足到整点。';

  @override
  String get adsShrinkTo => '广告会缩短以适应时段，每次广告时间不超过 5 分钟。';

  @override
  String get aShortBreak =>
      '节目前有一段短广告，节目中每 10 分钟（电影为 12 分钟）插入一次广告，尽量放在剧情转折处，其余广告放在节目后。';

  @override
  String get pickAutomaticFor => '选择“自动”可获得类似电视广播的广告时间，选择“自定义”可自行设置。';

  @override
  String workingOn(Object current) {
    return '正在处理 $current…';
  }

  @override
  String get analysis => '分析';

  @override
  String couldNotBe(Object failed) {
    return '$failed 无法分析（文件更改后会再次尝试）';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return '已找到广告点的节目：$programsDone / $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return '已拆分的长视频：$reelsDone / $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders 个文件夹  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '来自 $used 个广告素材组的 $clips。',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce => '素材组中有片段后，广告时间才会开始。请向素材组添加包含视频的文件夹。';

  @override
  String get breaksStartOnceA => '素材组中有片段后，广告时间才会开始。它的长视频正在拆分中。';

  @override
  String get breaksStartOnceAPool => '素材组中有片段后，广告时间才会开始。请在下方创建素材组。';

  @override
  String breaksAreOff(Object clips) {
    return '广告时间已关闭。你的素材组中有 $clips 可用。';
  }

  @override
  String get breaksAreOff2 => '广告时间已关闭。';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 个片段',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return '上次扫描失败：$syncError';
  }

  @override
  String get newPool => '新建素材组';

  @override
  String get pickTheFolders =>
      '请选择服务器上存放广告和过场片段的文件夹。其中的视频会从常规频道中移出，改为填充广告时间。将素材组的类型设为“过场片段”，即可用它的片段作为广告时间的开头和结尾。';

  @override
  String get pools => '素材组';

  @override
  String get breakSettings => '广告时间设置…';

  @override
  String get commercialBreaks => '广告时间';

  @override
  String get breakSettings2 => '广告时间设置';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count有了它，广告点也会更自然。';
  }

  @override
  String waiting(Object waiting) {
    return '（$waiting 个等待中）。';
  }

  @override
  String get fullStop => '。';

  @override
  String get longCommercialVideos => '这台设备无法拆分没有章节的长广告视频';

  @override
  String get installFfmpegTo => '安装 ffmpeg 以拆分长广告视频';

  @override
  String get picturesOnThis => '这台设备上的图片，最新的在前。大图会缩小到 512 px。';

  @override
  String get noPicturesOn =>
      '这台设备上还没有图片。请将 PNG 或 JPG 复制到它的 Download 文件夹或 U 盘中，然后再试一次。';

  @override
  String get lookingForPictures => '正在查找图片…';

  @override
  String get couldntReadThePictures => '无法读取这台设备上的图片。';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV 没有查看这台设备上图片的权限。请在 Android 的“设置”›“应用”›“Nightingale TV”›“权限”中允许“照片和视频”，然后再试一次。';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ 移动    OK 选择    ESC 取消';

  @override
  String get chooseAPicture => '选择图片';

  @override
  String thePoolHasnt(Object error) {
    return '$error  素材组没有更改。';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  没有任何更改。';
  }

  @override
  String get couldntReachTheServer => '无法连接到服务器';

  @override
  String get tryAgain => '重试';

  @override
  String get nothingInside => '里面没有内容';

  @override
  String get noMovies => '没有电影';

  @override
  String inside(Object childrenCount) {
    return '里面有 $childrenCount 项';
  }

  @override
  String get video => '视频';

  @override
  String collection(Object name) {
    return '$name（合集）';
  }

  @override
  String get included => '已包含';

  @override
  String get nothingInside2 => '里面没有内容。';

  @override
  String get loadingFolders => '正在加载文件夹…';

  @override
  String get pressOnA => '在媒体库上按 ▶ 查看其中的内容。';

  @override
  String get done => '完成';

  @override
  String ticked(Object _pickedCount) {
    return '已勾选 $_pickedCount 项';
  }

  @override
  String get nothingTickedYet => '还没有勾选任何内容。勾选媒体库即可使用全部内容，或按 ▶ 选择其中的内容。';

  @override
  String get wholeLibrary => '整个媒体库';

  @override
  String get libraries => '媒体库';

  @override
  String get loadingLibraries => '正在加载媒体库…';

  @override
  String get moveOkTick => '▲▼ 移动    OK 勾选    ▶ 打开    ◀ 返回上级    ESC 取消';

  @override
  String foldersFor(Object poolName) {
    return '$poolName 的文件夹';
  }

  @override
  String get chooseFolders => '选择文件夹';

  @override
  String get chooseWhatPlays => '选择这个频道播放的内容';

  @override
  String get endsEarly => '提前结束';

  @override
  String get madeFromThis => '由这个频道的节目和电影生成，并随媒体库更新。更改任何内容后，它就归你所有。';

  @override
  String get fromTheLineup => '来自频道列表';

  @override
  String yesterday(Object t) {
    return '昨天 $t';
  }

  @override
  String today(Object t) {
    return '今天 $t';
  }

  @override
  String behind(Object d) {
    return '落后 $d';
  }

  @override
  String hr(Object h) {
    return '$h 小时';
  }

  @override
  String get underAMinute => '不到一分钟';

  @override
  String get noProgramming => '没有节目';

  @override
  String get today2 => '今天';

  @override
  String get tuning => '正在调台…';

  @override
  String get offAir2 => '暂停播出';

  @override
  String get noSignal => '无信号';

  @override
  String left(Object now) {
    return '剩余 $now';
  }

  @override
  String get nothingScheduled => '没有节目安排';

  @override
  String get back => '返回';

  @override
  String get sleep => '睡眠';

  @override
  String get menu => '菜单';

  @override
  String get nightingaleTvGuide => 'NIGHTINGALE TV 节目指南';

  @override
  String nowPlaying(Object title) {
    return '正在播放：$title';
  }

  @override
  String get mMenu => 'M 菜单';

  @override
  String get escBackTo => 'ESC 返回电视';

  @override
  String get channelsTabsTime => '▲▼ 频道     ▲ 标签页     ◀▶ 时间     OK 观看     ';

  @override
  String get color => '颜色';

  @override
  String get channelsUsingIt => '使用它的频道会改回默认图标。';

  @override
  String get deleteThisIcon => '要删除这个图标吗？';

  @override
  String get uploadImage => '上传图片…';

  @override
  String get pngJpgWebp => 'PNG、JPG、WebP、GIF 或 SVG。大图会自动缩小到 512 px。';

  @override
  String get genericBadgesOnly => '这里只有通用徽章。请在“我的图标”下上传真实的电视台标志。';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => '使用这个徽章';

  @override
  String get preview => '预览';

  @override
  String get shape => '形状';

  @override
  String get callLettersUp => '台名缩写（最多 5 个字符）';

  @override
  String iconFor(Object name) {
    return '$name 的图标';
  }

  @override
  String get couldntReadThat => '无法读取这张图片。请换一张试试。';

  @override
  String get myIcons => '我的图标';

  @override
  String get showLogos => '显示标志';

  @override
  String get badges => '徽章';

  @override
  String get builtIn => '内置';

  @override
  String get couldntMoveThe => '无法迁移设置';

  @override
  String get send => '发送';

  @override
  String thisBacksUp(Object counterpartName) {
    return '这会立即备份你的个人资料、频道和设置，并在 $counterpartName 中打开，$counterpartName 会在恢复前先询问你。这里不会有任何更改。';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return '要将你的设置发送到 $counterpartName 吗？';
  }

  @override
  String get parentalControls => '家长控制';

  @override
  String get notNow => '以后再说';

  @override
  String bringMySetup(Object counterpartName) {
    return '从 $counterpartName 把我的设置带到这里';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return '将我的设置迁移到 $counterpartName';
  }

  @override
  String get uninstallingEitherOne => '在迁移你想保留的设置之前卸载其中任何一个，都会删除那份设置。';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName 和 $counterpartName 是两个独立的应用，各有自己的个人资料、频道和设置。';
  }

  @override
  String get thankYouFor => '感谢你支持 Nightingale TV！';

  @override
  String isAlsoOn(Object counterpartName) {
    return '这台设备上也有 $counterpartName';
  }

  @override
  String get aboutThisInstall => '关于这次安装';

  @override
  String couldntOpen(Object counterpartName) {
    return '无法打开 $counterpartName。';
  }

  @override
  String get nothingIsSet => '这里还没有任何设置，因此没有可迁移的内容。';

  @override
  String yourSetupIs(Object counterpartName) {
    return '你的设置正在发送到 $counterpartName';
  }

  @override
  String get guide => '节目指南';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n / $keysCount';
  }

  @override
  String get saving => '正在保存…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '已选择 $_checkedCount / $total';
  }

  @override
  String get channelOrGroup => '频道或分组名称';

  @override
  String get search => '搜索';

  @override
  String get moveOkCheck => '▲▼ 移动    OK 勾选    ESC 返回';

  @override
  String chooseChannels(Object name) {
    return '选择频道：$name';
  }

  @override
  String get add => '添加';

  @override
  String get readingThePlaylist => '正在读取播放列表…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return '当前：播放列表的节目指南，$guideUrl';
  }

  @override
  String get leaveEmptyTo => '留空则使用播放列表指定的节目指南';

  @override
  String get xmltvGuideAddress => 'XMLTV 节目指南地址';

  @override
  String get guideOptional => '节目指南（可选）';

  @override
  String get httpProviderExample =>
      'http://provider.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => '播放列表地址';

  @override
  String get playlist => '播放列表';

  @override
  String get myIptv => '我的 IPTV';

  @override
  String get useAnAddress => '改用地址';

  @override
  String get chooseAFile => '选择文件';

  @override
  String get chooseAnotherFile => '选择其他文件';

  @override
  String get moveOkSelectEscBack => '▲▼ 移动    OK 选择    ESC 返回';

  @override
  String edit(Object name) {
    return '编辑 $name';
  }

  @override
  String get addAnM3u => '添加 M3U 播放列表';

  @override
  String get m3uPlaylists => 'M3U 播放列表';

  @override
  String get xmltvGuides => 'XMLTV 节目指南';

  @override
  String get anIptvPlaylist => 'IPTV 播放列表（网址或文件），如果有的话，再加上 XMLTV 节目指南。';

  @override
  String get theChannelsAnd => '服务器调谐器（天线、有线电视盒或 IPTV）的频道和节目指南。';

  @override
  String readingSChannels(Object server) {
    return '正在读取 $server 的频道…';
  }

  @override
  String checkingLiveTv(Object server) {
    return '正在检查 $server 直播电视…';
  }

  @override
  String get addALive => '添加直播电视来源';

  @override
  String get itsChannelsLeave => '它的频道会从节目指南、分组和收藏中移除。';

  @override
  String get renameSource => '重命名来源';

  @override
  String get edit2 => '编辑';

  @override
  String get refreshNow => '立即刷新';

  @override
  String get chooseChannels2 => '选择频道';

  @override
  String get playlistFile => '播放列表文件';

  @override
  String get notRefreshedYet => '尚未刷新';

  @override
  String refreshed(Object lastRefresh) {
    return '已于 $lastRefresh 刷新';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return '上次刷新失败：$lastError';
  }

  @override
  String get refreshing => '正在刷新…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · $keyCount / $channelsCount 个频道';
  }

  @override
  String get noSourcesYet => '还没有来源。';

  @override
  String get addSource => '添加来源';

  @override
  String get realBroadcastsAnd =>
      '在节目指南中加入真实的广播和 IPTV：你服务器的直播电视，或带 XMLTV 节目指南的 M3U 播放列表。它们的频道排在你的频道之后。';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return '未在推流。已使用 $runningCount / $streamLimit 路流。';
  }

  @override
  String get savePort => '保存端口';

  @override
  String get port => '端口';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => '调谐器';

  @override
  String get enterAPort => '请输入端口号。';

  @override
  String pinFor(Object name) {
    return '$name 的 PIN';
  }

  @override
  String get letPlexFind => '让 Plex 自动查找';

  @override
  String get discovery => '发现';

  @override
  String get encoder => '编码器';

  @override
  String nowAtOnce(Object streamLimit) {
    return '当前：同时 $streamLimit 路。在其他地方观看的每个频道算一路流。';
  }

  @override
  String get streamsAtOnce => '同时推流数';

  @override
  String get quality => '画质';

  @override
  String get lineups => '频道列表';

  @override
  String get liveTvExport2 => '直播电视导出';

  @override
  String get automaticDiscoveryIsnt =>
      '这台电脑无法使用自动发现。请在 Plex、Jellyfin 或 Emby 中通过地址添加调谐器。';

  @override
  String get anyoneOnYour => '家庭网络中的任何人都可以观看这个频道列表。';

  @override
  String get watchYourChannels =>
      '在家庭网络中用 Plex、Jellyfin、Emby 或任何 IPTV 应用观看你的频道。播放时 Nightingale TV 必须保持打开。';

  @override
  String get offline => '离线';

  @override
  String get online => '在线';

  @override
  String get added => '已添加';

  @override
  String get chooseAServer => '选择服务器';

  @override
  String get whosSigningIn => '谁要登录？';

  @override
  String get openPlexTv => '打开 plex.tv/link';

  @override
  String get waitingForThe => '正在等待代码关联…';

  @override
  String get goToPlex => '请在手机或电脑上前往 plex.tv/link 并输入这个代码。';

  @override
  String get signInWith => '使用 Plex 登录';

  @override
  String get waitingForApproval => '正在等待批准…';

  @override
  String onYourPhone(Object label) {
    return '请在手机或电脑上打开 $label → 你的个人资料 → 快速连接，然后输入这个代码：';
  }

  @override
  String get quickConnect => '快速连接';

  @override
  String get signIn => '登录';

  @override
  String get password => '密码';

  @override
  String get username => '用户名';

  @override
  String signInTo2(Object name) {
    return '登录 $name';
  }

  @override
  String get differentServer => '其他服务器';

  @override
  String get signInWithPassword => '使用密码登录';

  @override
  String get quickConnectUse => '快速连接（使用手机）';

  @override
  String get connect => '连接';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get connectToYour => '连接到你的服务器';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV 把你的视频变成全天候播出的频道，并配有节目指南。可连接 Jellyfin、Emby、Plex、YouTube，或 NAS 等 SMB 共享文件夹。随便换台，看看正在播什么。';

  @override
  String get yourLibraryOn => '你的媒体库，\n全天候播出。';

  @override
  String get welcomeToNightingale => '欢迎使用 Nightingale TV';

  @override
  String signInFor(Object name) {
    return '为 $name 登录';
  }

  @override
  String signInToAgain(Object name) {
    return '重新登录 $name';
  }

  @override
  String get addAServer => '添加服务器';

  @override
  String foundNewPrograms(Object list) {
    return '找到了$list。新节目会在当前节目结束后立即在各自的频道上开始播出。';
  }

  @override
  String get libraryRefreshed => '媒体库已刷新';

  @override
  String get nothingNew => '没有新内容';

  @override
  String get yourChannelsAre => '你的频道已是最新。';

  @override
  String get refreshFailed => '刷新失败';

  @override
  String get moveOkSelectEscBackTo => '▲▼ 移动    OK 选择    ESC 返回电视';

  @override
  String get noPoolsYet => '还没有素材组';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return '更新于 $fetchedAt $fetchedAt2';
  }

  @override
  String get libraryLabel => '媒体库';

  @override
  String get account => '账户';

  @override
  String get watching => '观看';

  @override
  String get exitNightingaleTv => '退出 Nightingale TV';

  @override
  String get signOut => '退出登录';

  @override
  String get yourChannelLineup => '你的频道列表会被清空。自定义图标会保留。';

  @override
  String get signOut2 => '要退出登录吗？';

  @override
  String get fullScreenOn => '全屏开/关（F11）';

  @override
  String get nothingWasReset => '没有重置任何内容';

  @override
  String get reset => '重置';

  @override
  String get rebuildsTheDefault =>
      '根据你的媒体库重建默认频道。你更改过的名称、图标和频道号会被重置。你添加的频道会保留。系统会先保存一份备份，你可以在“备份与恢复”中找回它们。';

  @override
  String get resetChannelLineup => '要重置频道列表吗？';

  @override
  String get resetChannelLineup2 => '重置频道列表';

  @override
  String get refreshLibrary => '刷新媒体库';

  @override
  String get refreshingLibrary => '正在刷新媒体库…';

  @override
  String get servers => '服务器';

  @override
  String get phoneRemote => '手机遥控器';

  @override
  String get profiles => '个人资料';

  @override
  String get retroLook => '复古外观';

  @override
  String get playback => '播放';

  @override
  String get switchProfile => '切换个人资料';

  @override
  String get sleepTimer => '睡眠定时器';

  @override
  String get backToTv => '返回电视';

  @override
  String get removeAll => '全部移除';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return '配对于 $paired · 上次使用 $lastUsed';
  }

  @override
  String get noPhonesPaired => '还没有配对的手机。';

  @override
  String get pairedPhones => '已配对的手机';

  @override
  String get blockedByThis => '被这台电脑的防火墙阻止';

  @override
  String get someWiFi =>
      '有些 Wi-Fi 网络会隔离设备（称为 AP 隔离或客户端隔离）。如果手机仍然无法连接，请为你的 Wi-Fi 关闭这项设置。';

  @override
  String get thePhoneHas => '手机必须连接到与这台电视相同的 Wi-Fi，而不是访客网络或移动数据。';

  @override
  String get ifThePhone => '如果手机无法连接，可能是这台电脑的防火墙阻止了它。请在这台电脑上打开终端并运行：';

  @override
  String get checkAgain => '重新检查';

  @override
  String get thenChooseCheck => '然后选择“重新检查”。';

  @override
  String get thisComputersFirewall => '这台电脑的防火墙阻止手机连接遥控器。要允许连接，请在这台电脑上打开终端并运行：';

  @override
  String get notConfirmedYet => '尚未确认 · 还没有手机连接过';

  @override
  String get working => '正常';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return '正常 · 上次由 $name 使用，$lastUsed';
  }

  @override
  String get theRemoteIs => '遥控器已关闭。';

  @override
  String get orScanThe => '或用手机相机扫描二维码。';

  @override
  String get andEnter => '并输入  ';

  @override
  String get onYourPhoneOpen => '在你的手机上打开';

  @override
  String get useYourPhoneAs =>
      '把手机当作遥控器：在手机上打开一个网页，就可以换台、调出节目指南，或点按频道收看。无需安装任何东西。';

  @override
  String get everyPairedPhone => '所有已配对的手机都将无法用作遥控器，直到它们再次扫描这个屏幕上的二维码。';

  @override
  String get removeAllPhones => '要移除所有手机吗？';

  @override
  String get thoseDidntMatch => '两次输入不一致。请再试一次。';

  @override
  String get enterTheSame => '请再次输入相同的 4 位数字。';

  @override
  String get choose4Digits => '请设置 4 位数字。';

  @override
  String get thatPinIsnt => 'PIN 不正确。请再试一次。';

  @override
  String get clock => '时钟';

  @override
  String get captions2 => '字幕';

  @override
  String get audio => '音频';

  @override
  String get maximumStreamingBitrate => '最大流媒体码率';

  @override
  String get converting => '转换';

  @override
  String get afterThisLong =>
      '在这段时间内没有按任何按钮，Nightingale TV 会询问是否还有人在看。如果一分钟内没有回应，它就会进入睡眠：播放停止，服务器也会停止推流。设置了睡眠定时器时不会询问。';

  @override
  String get askIfIm => '询问我是否还在观看';

  @override
  String get liveTvStill => '直播电视仍会显示在仪表板上。';

  @override
  String get offWhatYou =>
      '关闭：你在这里观看的内容永远不会改变服务器上的播放次数、已观看标记或续播位置，也不会显示在它的仪表板上。';

  @override
  String get pauseSkipAnd => '暂停、跳过和重新播放当前节目。关闭：每个频道都按时间播放，就像全天候电视一样。';

  @override
  String get pauseAndRewind => '暂停和倒回';

  @override
  String get showsTheTime => '在画面角落显示时间。';

  @override
  String get onScreenClock => '屏幕时钟';

  @override
  String get showACountdown => '在广告开始前和节目回来前显示倒计时。';

  @override
  String get breakNotices => '广告提示';

  @override
  String get theSizeOf => '所有节目和频道中字幕的大小。';

  @override
  String get whileItsOn => '开启时，环绕声音频（Dolby、DTS）由这台设备解码，而不是直通到功放。';

  @override
  String get evensOutThe => '观看时自动平衡音量：调低吵闹的广告和节目，调高安静的，你不必再伸手拿遥控器。';

  @override
  String get volumeLeveling => '音量均衡';

  @override
  String get pickALower =>
      '如果节目通过 Wi-Fi 或远程连接播放时缓冲或卡顿，请选择更低的码率。“原始”永远不会因为码率而转换。';

  @override
  String get connectedThroughPlex => '通过 Plex Relay 连接；画质受限。';

  @override
  String get offNightingaleTv =>
      '关闭：Nightingale TV 始终以完整画质播放你的原始文件，服务器不做额外工作。开启：只有当节目或电影超过最大码率，或原始文件无法播放时，服务器才会转换。转换会使用服务器的处理器或显卡。广告始终播放原始文件。';

  @override
  String get transcodeOnlyIf => '仅在需要时转码（实验性）';

  @override
  String get longerVideosAd => '较长的视频（广告合集）会按章节或画面变黑无声的位置拆分成单独的广告。';

  @override
  String get videosOf5 => '5 秒到 3 分钟的视频各算一个片段。';

  @override
  String get commercialsFillBreaks =>
      '广告用于填充广告时间。若是台标和“马上回来”之类的片段，请将类型设为“过场片段”。';

  @override
  String get bumpersTakeAt => '除节目前外，过场片段最多占广告时间的一半。超出这个长度的片段会被跳过。';

  @override
  String stillToSplit(Object unsplit) {
    return '还有 $unsplit 待拆分';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount 个长视频已拆分成片段',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => '删除素材组';

  @override
  String get addFolders => '添加文件夹…';

  @override
  String get libraryLabel2 => '媒体库';

  @override
  String get noFoldersYet => '还没有文件夹。';

  @override
  String get folders2 => '文件夹';

  @override
  String get type => '类型';

  @override
  String get poolName => '素材组名称';

  @override
  String get commercialPool => '广告素材组';

  @override
  String get itsVideosGo => '它的视频会回到你的常规频道。原本从这里取片段的广告时间会改用所有素材组。';

  @override
  String get now => '现在';

  @override
  String get watch => '观看';

  @override
  String get tuning2 => '正在调台…';

  @override
  String get fullScreen => '全屏';

  @override
  String get noChannels => '没有频道';

  @override
  String get theirChannelsProgramming => '其频道、节目时段和设置会被删除，这台电视也会退出其服务器的登录。';

  @override
  String delete3(Object name) {
    return '要删除 $name 吗？';
  }

  @override
  String get giveTheProfile => '请为个人资料命名。';

  @override
  String get deleteProfile => '删除个人资料';

  @override
  String get removePin => '移除 PIN';

  @override
  String get setAPin => '设置 PIN';

  @override
  String get changePin => '更改 PIN';

  @override
  String get noPinAnyone => '未设置 PIN。任何人都可以打开这个个人资料。';

  @override
  String get lockedThePin => '已锁定。打开这个个人资料需要 PIN。';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith => '未分级的节目和电影会被排除。';

  @override
  String get allowedToWatch => '允许观看';

  @override
  String get kid => '儿童';

  @override
  String get grownUp => '成人';

  @override
  String get whoItsFor => '使用者';

  @override
  String get color2 => '颜色';

  @override
  String get editProfile => '编辑个人资料';

  @override
  String get newProfile => '新建个人资料';

  @override
  String get watchingNow => '正在观看';

  @override
  String get noPin => '无 PIN';

  @override
  String get pinLocked => 'PIN 已锁定';

  @override
  String kid2(Object label, Object description) {
    return '儿童 · $label（$description）';
  }

  @override
  String get addProfile => '添加个人资料';

  @override
  String get everyoneGetsTheir =>
      '每个人都有自己的服务器登录、频道和节目时段。儿童个人资料只能看到适合其年龄分级的节目和电影。';

  @override
  String enterSPin(Object name) {
    return '请输入 $name 的 PIN';
  }

  @override
  String get whosWatching => '谁在观看？';

  @override
  String get moveOkChoose2 => '◀▶ 移动    OK 选择';

  @override
  String get enterAGrownUps => '请输入成人的 PIN。';

  @override
  String get grownUpsOnly => '仅限成人';

  @override
  String get yourChannelYour => '你的频道，你的风格';

  @override
  String get testPattern => '测试图';

  @override
  String get upNext8 => '接下来  ·  20:00';

  @override
  String get thisDevice => '这台设备';

  @override
  String get glow => '辉光';

  @override
  String get curvature => '曲面';

  @override
  String get vignette => '暗角';

  @override
  String get mask => '荫罩';

  @override
  String get lines => '线数';

  @override
  String get scanlines => '扫描线';

  @override
  String get customCrtStyle => '自定义 CRT 样式';

  @override
  String accent(Object label) {
    return '强调色（$label）';
  }

  @override
  String get overlayTheme => '叠加层主题';

  @override
  String get crtEffect => 'CRT 效果';

  @override
  String get surround => '边框';

  @override
  String get pictureShape => '画面形状';

  @override
  String get surroundImage => '边框图片';

  @override
  String get notAvailableOn => '这台设备不支持';

  @override
  String get offTurnsOff => '“关”只会关闭这台设备上的所有 CRT 效果。画面形状、边框和叠加层主题保持不变。';

  @override
  String get effectsOnThis => '这台设备上的效果';

  @override
  String get retroLook2 => '复古外观';

  @override
  String get theseSettingsApply => '这些设置适用于运行这个应用的屏幕，不适用于直播电视导出。';

  @override
  String get sameAsThe => '与个人资料相同';

  @override
  String get streamsFromThis => '来自这个服务器的流会保持在这个上限以下。个人资料自身的上限（播放）仍然适用，以较低者为准。';

  @override
  String qualityLimit(Object name) {
    return '画质上限 · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      '它的节目会从你的频道中移除，频道号保持不变。它上面的来源和广告文件夹会显示为未找到，直到你更改它们。';

  @override
  String remove3(Object name) {
    return '要移除 $name 吗？';
  }

  @override
  String get signingOutOf => '退出这个个人资料的登录会更改它的主服务器。';

  @override
  String signedInAs(Object user) {
    return '已作为 $user 登录';
  }

  @override
  String get mainServer => '主服务器';

  @override
  String get qualityLimit2 => '画质上限';

  @override
  String get moveDown => '下移';

  @override
  String get moveUp => '上移';

  @override
  String get signInAgain => '重新登录';

  @override
  String get programsFromEvery =>
      '所有服务器的节目会合并到同一个频道列表。在多个服务器上都有的作品，会从这个列表中第一个响应的服务器播放（播放来源）；如果它停止响应，下一个会接替。';

  @override
  String get sleepingPressAny => '睡眠中 · 按任意键继续观看';

  @override
  String goingToSleep(Object seconds) {
    return '$seconds 后进入睡眠';
  }

  @override
  String get goingToSleep2 => '即将进入睡眠';

  @override
  String goingToSleepIn(Object hint) {
    return '1 分钟后进入睡眠。$hint';
  }

  @override
  String get pressAnyButton => '按任意键继续观看';

  @override
  String goingToSleepIn0(Object padLeft) {
    return '0:$padLeft 后进入睡眠';
  }

  @override
  String get keepWatching => '继续观看';

  @override
  String get areYouStill => '你还在观看吗？';

  @override
  String sleepTimerMin(Object left) {
    return '睡眠定时器 · 剩余 $left 分钟';
  }

  @override
  String get whatsOnNow => '当前节目没有固定的结束时间。';

  @override
  String endOfThis(Object programEnd) {
    return '这个节目结束时 · $programEnd';
  }

  @override
  String get endOfThisProgram => '这个节目结束时';

  @override
  String get moveOkToggle => '▲▼◀▶ 移动    OK 切换    ESC 取消';

  @override
  String get usedWhenNo => '在没有选择节目时使用。也会用于筛选电影。';

  @override
  String get genres2 => '类型';

  @override
  String get includeMovies => '包括电影';

  @override
  String get add2 => '添加…';

  @override
  String get notFoundOn => '服务器上找不到';

  @override
  String get collectionsFolders => '合集和文件夹';

  @override
  String get playOrder => '播放顺序';

  @override
  String get clear => '清除';

  @override
  String get shows2 => '节目';

  @override
  String get pickSomethingTo => '请选择要播放的内容。';

  @override
  String everyMovie(Object genreText) {
    return '所有$genreText电影';
  }

  @override
  String get everyMovie2 => '所有电影';

  @override
  String everyShow(Object genreText) {
    return '所有$genreText节目';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount或$last';
  }

  @override
  String decadesGenres(Object decades, Object genres) {
    return '$decades$genres';
  }

  @override
  String get settingUpYour => '正在设置你的频道';

  @override
  String get couldntLoadYour => '无法加载你的媒体库';

  @override
  String upNext(Object title) {
    return '接下来：$title';
  }

  @override
  String firstUp(Object title) {
    return '首先播放：$title';
  }

  @override
  String backTo(Object title) {
    return '返回 $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return '距节目恢复还有 $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '距$commercialBreakLabel还有 $left';
  }

  @override
  String startingWith(Object title) {
    return '从《$title》开始';
  }

  @override
  String upNext2(Object start) {
    return '接下来  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return '下一个 $start：$title';
  }

  @override
  String backOn(Object backOnAir) {
    return '$backOnAir 恢复播出';
  }

  @override
  String get offTheAir2 => '暂停播出';

  @override
  String get commercialBreak => '广告时间';

  @override
  String tryingAgainAt(Object end) {
    return '将于 $end 重试';
  }

  @override
  String get exitFullScreen => '退出全屏';

  @override
  String get guide2 => '节目指南';

  @override
  String thereIsNo(Object number) {
    return '没有频道 $number';
  }

  @override
  String get liveChannelsCant => '直播频道无法暂停';

  @override
  String get curvatureAndGlow => '曲面和辉光已关闭：这台设备性能不足';

  @override
  String get pressBackAgain => '再按一次返回键退出';

  @override
  String backAt(Object backAt) {
    return '$backAt 回来';
  }

  @override
  String get live => '直播';

  @override
  String get newLabel => '新';

  @override
  String nowPlayingOn(Object name) {
    return '$name 正在播放';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => '已暂停';

  @override
  String get seekBar => '进度条';

  @override
  String get live2 => '直播';

  @override
  String get forward30 => '快进 30 秒';

  @override
  String get pause => '暂停';

  @override
  String get play => '播放';

  @override
  String get back10 => '后退 10 秒';

  @override
  String get restart => '从头播放';

  @override
  String somethingWentWrong2(Object status) {
    return '出现问题（$status）。';
  }

  @override
  String get thatIsTooBig => '内容太大。';

  @override
  String get notFound => '未找到。';

  @override
  String get youCantDo => '你不能这样做。';

  @override
  String get cantReachThe => '无法连接到服务器。请检查它是否正在运行。';

  @override
  String signOut3(Object userName) {
    return '退出 $userName 的登录';
  }

  @override
  String get changePassword => '更改密码';

  @override
  String get users => '用户';

  @override
  String get backups2 => '备份';

  @override
  String get serverAndSign => '服务器和登录';

  @override
  String get channels5 => '频道';

  @override
  String get thatProfileIsntYours => '这个个人资料不是你的，或者已不存在。';

  @override
  String get download => '下载';

  @override
  String get itReplacesThe => '它会替换这里的个人资料、频道和设置。';

  @override
  String get restoreThisBackup => '要恢复这个备份吗？';

  @override
  String get restoring => '正在恢复…';

  @override
  String get restoreFromAFile => '从文件恢复…';

  @override
  String get downloadABackup => '立即下载备份';

  @override
  String get aBackupHoldsThe => '备份包含个人资料、频道、节目时段、标志、导出设置和用户账户（绝不包含密码或登录令牌）。';

  @override
  String get restoredTheBackup2 => '已恢复备份。';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return '来自 $whenValue（$device）：$profiles。它会替换这里的个人资料、频道和设置。';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return '下次播出：$start $end';
  }

  @override
  String programsInIts(Object total) {
    return '播放列表中有 $total 个节目。';
  }

  @override
  String get workingOutWhat => '正在确定播放内容…';

  @override
  String get later => '更晚';

  @override
  String get earlier => '更早';

  @override
  String get eachAiringPlays => '每次播出都会按顺序播放每个位置的下一集，如果还有剩余时间就从头开始。';

  @override
  String get aLineupOf => '节目列表';

  @override
  String get whatItPlays2 => '播放内容';

  @override
  String get onlyPartOf => '仅在一年中的部分时间';

  @override
  String get runsPastMidnight => '跨过午夜延续到次日。';

  @override
  String get whenLabel => '时间';

  @override
  String get aNewChannelFor => '为这个节目时段新建的频道';

  @override
  String get channel3 => '频道';

  @override
  String get blocks => '节目时段';

  @override
  String get newBlock => '新建节目时段';

  @override
  String get programmingBlock => '节目时段';

  @override
  String get aBlockTakes => '节目时段会在固定时间接管频道：例如“周六早间动画”，每周六 7:00 至 12:00。';

  @override
  String get overlayTheme2 => '叠加层主题';

  @override
  String get crtEffect2 => 'CRT 效果';

  @override
  String get chooseSurroundImage => '选择边框图片…';

  @override
  String get surround2 => '边框';

  @override
  String get pictureShape2 => '画面形状';

  @override
  String get chooseOfflineImage => '选择离线图片…';

  @override
  String get fillerPool2 => '填充素材组';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes 分钟';
  }

  @override
  String get slotLength2 => '时段长度';

  @override
  String get everyProgramStarts => '每个节目都整点开始。每个时段的剩余部分由填充补足。';

  @override
  String get itLeavesThe => '它会离开频道列表。';

  @override
  String get itsProgrammingBlocks => '它的节目时段也会被移除。';

  @override
  String get removeThisChannel => '移除这个频道';

  @override
  String get channelLogo2 => '频道标志';

  @override
  String get editCustomBreaks => '编辑自定义广告时间…';

  @override
  String get musicChannelsOnlyShuffle => '音乐频道只能随机播放，且不会连续播放同一位艺人的作品。';

  @override
  String get playOrder2 => '播放顺序';

  @override
  String get saveWhatIt => '保存播放内容';

  @override
  String get canBeA => '可以作为节目最新剧集的主频道。';

  @override
  String get hiddenFromThe => '在节目指南中隐藏';

  @override
  String get chooseIcon => '选择图标…';

  @override
  String get icon => '图标';

  @override
  String get saveNameAnd => '保存名称和频道号';

  @override
  String get aChannelAlready => '已占用这个频道号的频道会与这个频道互换位置。';

  @override
  String get number3 => '频道号';

  @override
  String get nameAndNumber => '名称和频道号';

  @override
  String get decadesNoneAny => '年代（不选：任意）';

  @override
  String get genresNoneAny => '类型（不选：任意）';

  @override
  String musicVideos(Object musicVideos) {
    return '音乐视频（$musicVideos）';
  }

  @override
  String songs(Object songs) {
    return '歌曲（$songs）';
  }

  @override
  String get newMusicChannel => '新建音乐频道';

  @override
  String get aNightlySlot => '每晚在各节目主频道上播出节目最新剧集的时段。';

  @override
  String get mainSettings => '主设置';

  @override
  String get glow2 => '辉光';

  @override
  String get curvature2 => '曲面';

  @override
  String get vignette2 => '暗角';

  @override
  String get mask2 => '荫罩';

  @override
  String get lines2 => '线数';

  @override
  String get scanlines2 => '扫描线';

  @override
  String get customCrtStyle2 => '自定义 CRT 样式';

  @override
  String accent2(Object label) {
    return '强调色（$label）';
  }

  @override
  String get hidden => '已隐藏';

  @override
  String get blockChannel2 => '节目时段频道';

  @override
  String live3(Object source) {
    return '直播 · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return '$shownCount / $channelsCount 个频道';
  }

  @override
  String get searchChannels => '搜索频道';

  @override
  String get resetLineup => '重置频道列表';

  @override
  String get everyChannelEdit =>
      '所有频道编辑都会被舍弃，并重新生成默认频道列表。你添加的频道会保留。系统会先保存一份备份。';

  @override
  String get musicChannel => '音乐频道';

  @override
  String get newBlockChannel => '新建节目时段频道';

  @override
  String get channelsOwnPlans => '频道自己的方案';

  @override
  String get setTypeBumpers => '设置类型：过场片段';

  @override
  String get setTypeCommercials => '设置类型：广告';

  @override
  String get chooseFolders2 => '选择文件夹…';

  @override
  String get plansThatDrew => '原本从它取片段的方案会改用所有素材组，它的视频也会回到频道中。';

  @override
  String get renamePool => '重命名素材组';

  @override
  String get poolActions => '素材组操作';

  @override
  String get aPoolIs =>
      '素材组是一组媒体库文件夹，其中的视频用于填充广告时间，而不会作为节目播出。素材组的类型决定它的片段是作为广告播放，还是作为过场片段用于广告时间的开头和结尾。';

  @override
  String get pools2 => '素材组';

  @override
  String get breaks => '广告时间';

  @override
  String clipsInAll(Object clips) {
    return '所有广告素材组中共有 $clips 个片段。';
  }

  @override
  String get tunerAddress => '调谐器地址';

  @override
  String get changePort => '更改端口';

  @override
  String get exportThisProfile => '导出这个个人资料';

  @override
  String get letsPlexAnd => '让 Plex 等应用在网络上找到调谐器。';

  @override
  String get discovery2 => '发现';

  @override
  String get encoder2 => '编码器';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return '自动：这台机器上为 $streamLimitInUse。';
  }

  @override
  String get streamsAtOnce2 => '同时推流数';

  @override
  String get quality2 => '画质';

  @override
  String get settings => '设置';

  @override
  String get eachExportedProfile =>
      '每个导出的个人资料都是 Plex、Jellyfin 或 Emby 的一个调谐器。请在它们的 DVR 设置中通过地址添加。';

  @override
  String get channelsInThis => '这个分组中的频道';

  @override
  String get chooseChannels3 => '选择频道…';

  @override
  String channels7(Object channelIds) {
    return '$channelIds 个频道';
  }

  @override
  String get itsChannelsStay => '它的频道仍保留在频道列表中。';

  @override
  String get renameGroup => '重命名分组';

  @override
  String get groupActions => '分组操作';

  @override
  String get yourGroup => '你的分组';

  @override
  String get theOrderOf => '节目指南中标签页的顺序，以及要显示哪些。';

  @override
  String get guideTabs => '节目指南标签页';

  @override
  String get make => '创建';

  @override
  String get breaksBetweenPrograms => '节目之间的广告时间';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '中间 $mids 次广告',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return '$songs 首歌曲';
  }

  @override
  String get newEpisode => '新剧集';

  @override
  String get noChannelsYet2 => '还没有频道。';

  @override
  String get noGuide => '没有节目指南';

  @override
  String get noneShown => '全部隐藏';

  @override
  String get allShown => '全部显示';

  @override
  String channels8(Object name) {
    return '$name：频道';
  }

  @override
  String get orChooseA => '或选择节目指南文件…';

  @override
  String get emptyThePlaylists => '留空：使用播放列表自带的节目指南（如果有）。';

  @override
  String get guideAddressXmltv => '节目指南地址（XMLTV，可选）';

  @override
  String get orChooseAPlaylist => '或选择播放列表文件…';

  @override
  String get leaveEmptyToKeep => '留空则保留播放列表文件。';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => '文件';

  @override
  String get itsChannelsJoin => '这个个人资料登录该服务器期间，它的频道会加入进来。';

  @override
  String guide3(Object guideFile) {
    return '节目指南：$guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return '播放列表文件：$playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return '已于 $last $context 刷新';
  }

  @override
  String get itsChannelsLeaveThe => '它的频道会从频道列表、分组和收藏中移除。';

  @override
  String read(Object fetched, Object context) {
    return '已于 $fetched $context 读取。';
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
    return '$series 个节目 · $episodes 集 · $movies 部电影 · $songs 首歌曲 · $musicVideos 个音乐视频 · $commercials 个广告视频';
  }

  @override
  String fromAs(Object server, Object user) {
    return '来自 $server，身份为 $user。';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name：媒体库';
  }

  @override
  String get removeThePin => '移除 PIN';

  @override
  String get pinOptional => 'PIN（可选）';

  @override
  String get newPinLeave => '新 PIN（留空则保持不变）';

  @override
  String colour(Object i) {
    return '颜色 $i';
  }

  @override
  String get colour2 => '颜色';

  @override
  String get itsChannelsBlocks => '其频道、节目时段和设置会被删除。系统会先保存一份备份。';

  @override
  String get exported => '已导出';

  @override
  String kid3(Object label) {
    return '儿童 · $label';
  }

  @override
  String get noProfilesAre => '还没有分配给你的个人资料。请联系管理员。';

  @override
  String signIn2(Object name) {
    return '为 $name 登录';
  }

  @override
  String get theLibraryIs => '正在重新读取媒体库；完成后，服务器的节目会加入频道。';

  @override
  String get itsLibraryIs => '正在读取它的媒体库并创建频道。这需要一两分钟。';

  @override
  String isSignedIn(Object name) {
    return '$name 已登录。';
  }

  @override
  String get couldntDoThat => '无法完成操作。请再试一次。';

  @override
  String get itsChannelsStayIt => '它的频道会保留；需要登录后才能播放。';

  @override
  String signOut4(Object name) {
    return '要退出 $name 的登录吗？';
  }

  @override
  String get signingIn => '正在登录…';

  @override
  String wasSignedIn(Object server, Object user) {
    return '曾以 $user 身份登录 $server。请重新登录。';
  }

  @override
  String signedInTo(Object server, Object user) {
    return '已以 $user 身份登录 $server。';
  }

  @override
  String get profileName => '个人资料名称';

  @override
  String get nameAProfile => '为个人资料命名并登录你的媒体服务器，系统就会创建并导出它的频道。';

  @override
  String get chooseABackup => '选择备份文件…';

  @override
  String get moveAHousehold => '从电视或其他服务器将家庭设置迁移到这里：其个人资料、频道、节目时段、标志和导出设置。';

  @override
  String get restoreABackup => '恢复备份';

  @override
  String get theServerIs => '服务器正在启动…';

  @override
  String get itsProgramsLeaveThe =>
      '它的节目会从频道中移除，频道号保持不变。它上面的来源和广告文件夹会显示为未找到，直到你更改它们。';

  @override
  String addAServerTo(Object name) {
    return '为 $name 添加服务器';
  }

  @override
  String servers2(Object name) {
    return '$name：服务器';
  }

  @override
  String get makeAccountAnd => '创建账户并登录';

  @override
  String get setPasswordAnd => '设置密码并登录';

  @override
  String get passwordAgain => '再次输入密码';

  @override
  String get atLeast8 => '至少 8 个字符。';

  @override
  String get userName => '用户名';

  @override
  String get adminAccount => '管理员账户';

  @override
  String get makeTheFirst => '创建第一个管理员账户。';

  @override
  String get setANew => '为管理员账户设置新密码。';

  @override
  String get thisSetupLink => '这个设置链接已被使用，或者来自之前的启动。请从服务器日志中打开最新的链接，或者直接登录。';

  @override
  String get thePasswordsDont => '两次输入的密码不一致。';

  @override
  String get newPasswordAgain => '再次输入新密码';

  @override
  String get newPassword => '新密码';

  @override
  String get currentPassword => '当前密码';

  @override
  String get passwordChangedYour => '密码已更改。你的其他浏览器已退出登录。';

  @override
  String get theNewPasswords => '两次输入的新密码不一致。';

  @override
  String get theyAreSigned => '他们已退出登录，且无法再次登录。';

  @override
  String get cantSignIn => '无法登录；已在所有地方退出登录。';

  @override
  String get usersReachOnly => '用户只能访问下面的个人资料。';

  @override
  String get adminsCanDo => '管理员可以对所有个人资料进行任何操作。';

  @override
  String get admin => '管理员';

  @override
  String get user => '用户';

  @override
  String get leaveEmptyToKeepIt => '留空则保持不变。设置新密码会让其在其他地方退出登录。';

  @override
  String get needsAPassword => '需要设置密码才能登录。';

  @override
  String get addUser => '添加用户';

  @override
  String get needsAPassword2 => '需要密码';

  @override
  String get noProfiles => '没有个人资料';

  @override
  String get pad => '填充';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  $clips 个片段';
  }

  @override
  String get clipsFrom2 => '片段来源';

  @override
  String get channelsUsingItGo => '使用它的频道会改回内置图标。';

  @override
  String get uploading => '正在上传…';

  @override
  String get noneOfYourShows => '你服务器上的节目都没有标志图片。';

  @override
  String get chooseAnIcon => '选择图标';

  @override
  String get couldntCopySelect => '无法复制。请选中文字后手动复制。';

  @override
  String copy(Object label) {
    return '复制$label';
  }

  @override
  String get home => '首页';

  @override
  String get thereIsNoPage => '这里没有页面。';

  @override
  String get enterPin => '输入 PIN';

  @override
  String get thisIsA => '这是儿童个人资料。更改其设置需要成人的 PIN。';

  @override
  String hasAPin(Object name) {
    return '$name 设有 PIN。';
  }

  @override
  String get profile => '个人资料';

  @override
  String get changingAKid => '更改儿童个人资料的设置需要成人个人资料的 PIN。';

  @override
  String get aGrownUps => '成人的 PIN';

  @override
  String get thisProfile => '这个个人资料';

  @override
  String movies3(Object movies) {
    return '电影（$movies）';
  }

  @override
  String get shows3 => '节目';

  @override
  String remove4(Object label) {
    return '移除$label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · 服务器上找不到';
  }

  @override
  String get dragACollection => '将合集、文件夹或电影拖到这里，或使用它的“添加”按钮。';

  @override
  String get collectionsAndFolders => '合集和文件夹';

  @override
  String add3(Object name) {
    return '添加 $name';
  }

  @override
  String added2(Object name) {
    return '已添加 $name';
  }

  @override
  String get dragToAdd => '拖动以添加';

  @override
  String get languageAutomatic => '自动';

  @override
  String dateAtTime(String date, String time) {
    return '$date $time';
  }

  @override
  String connectingTo(Object server) {
    return '正在连接到 $server…';
  }

  @override
  String get yourServerLower => '你的服务器';

  @override
  String noServerFoundAt(Object address) {
    return '在 $address 找不到 Jellyfin、Emby 或 Plex 服务器。';
  }

  @override
  String captionsValue(Object name) {
    return '字幕：$name';
  }

  @override
  String channelOverrides(int count) {
    return '$count 个频道有自己的设置（频道和图标）。';
  }

  @override
  String noShowLogosOn(Object kind) {
    return '你的 $kind 服务器上的节目都没有标志图片。';
  }

  @override
  String fileChosen(Object name) {
    return '文件：$name';
  }

  @override
  String get theOneChosenBefore => '之前选择的那个';

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
      other: '正在向 $viewers 位观众推流频道 $channels。已使用 $running / $limit 路流。',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name：导出这个频道列表';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name（儿童）：导出这个频道列表';
  }

  @override
  String encoderInUse(Object encoder) {
    return '正在使用的编码器：$encoder';
  }

  @override
  String get checking => '正在检查…';

  @override
  String countShows(int count) {
    return '$count 个节目';
  }

  @override
  String countEpisodes(int count) {
    return '$count 集';
  }

  @override
  String countMovies(int count) {
    return '$count 部电影';
  }

  @override
  String countSongs(int count) {
    return '$count 首歌曲';
  }

  @override
  String countMusicVideos(int count) {
    return '$count 个音乐视频';
  }

  @override
  String countHidden(int count) {
    return '$count 个已隐藏';
  }

  @override
  String countOnTheAir(int count) {
    return '$count 个播出中';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个节目时段',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name：$stats';
  }

  @override
  String get yourServerHasNothingNew =>
      '自上次刷新以来，你的服务器没有新内容。服务器扫描新文件后，它们才会出现在这里：如果你刚添加了文件，请先在服务器上扫描媒体库，然后再刷新。';

  @override
  String serverHasNothingNew(Object server) {
    return '自上次刷新以来，$server 没有新内容。服务器扫描新文件后，它们才会出现在这里：如果你刚添加了文件，请先在服务器上扫描媒体库，然后再刷新。';
  }

  @override
  String get updateWatchStatusOnYourServer => '更新服务器上的观看状态';

  @override
  String get updateWatchStatusOnYourServers => '更新各服务器上的观看状态';

  @override
  String updateWatchStatusOn(Object name) {
    return '更新 $name 上的观看状态';
  }

  @override
  String get poolFoldersBumpers =>
      '这些文件夹（及其子文件夹）中的每个视频都会用于广告时间的开头和结尾，永远不会作为节目播出。';

  @override
  String get poolFoldersCommercials =>
      '这些文件夹（及其子文件夹）中的每个视频都会用于填充广告时间，永远不会作为节目播出。';

  @override
  String get newPin => '新 PIN';

  @override
  String namedPin(Object name) {
    return '$name 的 PIN';
  }

  @override
  String get qualitySameAsProfile => '画质：与个人资料相同';

  @override
  String qualityValue(Object limit) {
    return '画质：$limit';
  }

  @override
  String onChannel(Object channel) {
    return '在 $channel';
  }

  @override
  String get aChannelThatIsGone => '已不存在的频道';

  @override
  String liveFrom(Object source) {
    return '来自 $source 的直播';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return '标志 $mode · 首播 $premieres';
  }

  @override
  String get offLower => '关';

  @override
  String streamingNow(Object count) {
    return '当前有 $count 路在推流。';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return '当前有 $count 路在推流 · 使用 $encoder 编码。';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · $chosen / $channels 个频道';
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
    return '来自 $when（$device）：$profiles。$channels 个频道、$blocks 个节目时段、$logos 个标志。';
  }

  @override
  String get backupSavedFirst => '系统会先备份这里现有的内容。';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个新节目',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 集新剧集',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部新电影',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首新歌曲',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return '播放$list。';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个新频道',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => '幼儿';

  @override
  String get kidRatingYoungDescription => 'TV-Y 和 TV-Y7';

  @override
  String get kidRatingKids => '儿童';

  @override
  String get kidRatingKidsDescription => '最高 TV-G 和 G';

  @override
  String get kidRatingOlder => '大龄儿童';

  @override
  String get kidRatingOlderDescription => '最高 TV-PG 和 PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个个人资料',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个频道',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个节目时段',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个时段',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '其文件夹中有 $count 个视频',
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
  String get liveLabel => '直播';

  @override
  String get aMidRollOpens =>
      '节目中的广告时间以过场片段开始和结束，节目后的广告时间以过场片段开始，节目前的广告时间以过场片段结束。其余时间由广告填充。';

  @override
  String get programsPlayBack => '节目连续播放，没有广告时间。';

  @override
  String get everyShowFills => '每个节目都占满半小时时段（较长的节目占一小时或更长），因此节目指南始终按整点进行。';

  @override
  String get chooseHowLong => '选择每次广告时间的长度、节目中插播广告的频率，以及每次广告时间从哪个素材组取片段。';

  @override
  String get copyAction => '复制';

  @override
  String get channelKidsZone => '少儿天地';

  @override
  String get channelToonTv => '动画频道';

  @override
  String get channelLaughTrack => '欢乐喜剧';

  @override
  String get channelFamilyRoom => '合家欢';

  @override
  String get channelAdventureTv => '冒险频道';

  @override
  String get channelSciFiFantasy => '科幻奇幻';

  @override
  String get channelMysteryTv => '悬疑频道';

  @override
  String get channelDramaCentral => '电视剧场';

  @override
  String get channelCrimeJustice => '警匪罪案';

  @override
  String get channelThrillTv => '惊悚频道';

  @override
  String get channelFrightNight => '午夜惊魂';

  @override
  String get channelRomanceTv => '浪漫爱情';

  @override
  String get channelDiscoveryZone => '纪实天地';

  @override
  String get channelMusicTv => '音乐频道';

  @override
  String get channelRealityTv => '真人秀';

  @override
  String get channelGameShowTv => '游戏综艺';

  @override
  String get channelFrontierTv => '西部片频道';

  @override
  String get channelHistoryTv => '历史频道';

  @override
  String get channelSportsTv => '体育频道';

  @override
  String get channelNewsTv => '新闻频道';

  @override
  String get channelAllShows => '全部节目';

  @override
  String get channelMovieChannel => '电影频道';

  @override
  String get channelMusicVideos => '音乐视频';

  @override
  String get channelMusicRadio => '音乐电台';

  @override
  String get genreActionAdventure => '动作冒险';

  @override
  String get genreSciFiFantasy => '科幻奇幻';

  @override
  String get genreKids => '儿童';

  @override
  String get genreAnimation => '动画';

  @override
  String get genreComedy => '喜剧';

  @override
  String get genreFamily => '家庭';

  @override
  String get genreDrama => '剧情';

  @override
  String get genreCrime => '犯罪';

  @override
  String get genreMystery => '悬疑';

  @override
  String get genreThriller => '惊悚';

  @override
  String get genreHorror => '恐怖';

  @override
  String get genreRomance => '爱情';

  @override
  String get genreDocumentary => '纪录片';

  @override
  String get genreMusic => '音乐';

  @override
  String get genreReality => '真人秀';

  @override
  String get genreGameShows => '游戏节目';

  @override
  String get genreWestern => '西部';

  @override
  String get genreWar => '战争';

  @override
  String get genreHistory => '历史';

  @override
  String get genreNews => '新闻';

  @override
  String get genreTalk => '脱口秀';

  @override
  String get genreSoap => '肥皂剧';

  @override
  String get genreSports => '体育';

  @override
  String get genreClassical => '古典';

  @override
  String get genreElectronic => '电子';

  @override
  String get genreCountry => '乡村';

  @override
  String get genreLatin => '拉丁';

  @override
  String get genreSoundtrack => '原声';

  @override
  String get genreOldies => '老歌';

  @override
  String get genreDance => '舞曲';

  @override
  String get genreFolk => '民谣';

  @override
  String get genreAlternative => '另类';

  @override
  String get blockDaytime => '白天档';

  @override
  String get blockMovieNight => '电影之夜';

  @override
  String get blockNewEpisodes => '新剧集';

  @override
  String get kindShow => '节目';

  @override
  String get kindShows => '节目';

  @override
  String get kindMovies => '电影';

  @override
  String get kindMusicVideos => '音乐视频';

  @override
  String get kindRadio => '电台';

  @override
  String genreMovies(Object genre) {
    return '$genre电影';
  }

  @override
  String genreMusicVideos(Object genre) {
    return '$genre音乐视频';
  }

  @override
  String genreRadio(Object genre) {
    return '$genre电台';
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
  String get lateNightTitle => '深夜档';

  @override
  String get languageTitle => '语言';

  @override
  String get stillWatchingOff => '关';

  @override
  String afterHours(int hours) {
    return '$hours 小时后';
  }

  @override
  String get bitrateOriginal => '原始（无限制）';

  @override
  String get bitrate40 => '40 Mbps · 4K';

  @override
  String get bitrate20 => '20 Mbps · 1080p 高';

  @override
  String get bitrate12 => '12 Mbps · 1080p';

  @override
  String get bitrate8 => '8 Mbps · 1080p';

  @override
  String get bitrate4 => '4 Mbps · 720p';

  @override
  String get noSuchLanguage => '没有这种语言。';

  @override
  String get languageField => '语言';

  @override
  String get remotePageTitle => 'Nightingale TV 遥控器';

  @override
  String get remotePairTitle => '与电视配对';

  @override
  String get remotePairHelp => '扫描电视上的二维码（菜单 → 手机遥控器），或输入那里显示的 6 位代码。';

  @override
  String get remotePairingCode => '配对代码';

  @override
  String get remotePair => '配对';

  @override
  String get remoteConnecting => '正在连接…';

  @override
  String get remoteTabRemote => '遥控器';

  @override
  String get remoteUp => '上';

  @override
  String get remoteLeft => '左';

  @override
  String get remoteRight => '右';

  @override
  String get remoteDown => '下';

  @override
  String get remoteInfo => '信息';

  @override
  String get remoteLastCh => '上个频道';

  @override
  String get remoteCc => '字幕';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => '确定';

  @override
  String get remoteRemovedFromTv => '这部手机已从电视中移除。请扫描二维码重新配对。';

  @override
  String get remoteCouldntPair => '无法配对。请再试一次。';

  @override
  String get remoteCantReachWifi => '无法连接到电视。这部手机连接的是同一个 Wi-Fi 吗？';

  @override
  String get remoteEnterDigits => '请输入电视上显示的 6 位数字。';

  @override
  String get remoteCantReachTv => '无法连接到电视';

  @override
  String get remotePickProfile => '请用方向键和 OK 选择个人资料。';

  @override
  String remoteWatching(Object name) {
    return '正在观看：$name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name（儿童）';
  }

  @override
  String get transferPageTitle => 'Nightingale TV 备份';

  @override
  String get transferIntro => '在这台电视和这台设备之间传送备份。传送期间请保持电视上的对话框打开。';

  @override
  String get transferDownload => '下载备份';

  @override
  String get transferDownloadHelp => '电视当前设置的备份：个人资料、频道、节目时段和设置。';

  @override
  String get transferRestoreTitle => '从文件恢复';

  @override
  String transferRestoreHelp(Object file) {
    return '向电视发送一个 $file 文件。在电视上确认之前不会有任何更改。';
  }

  @override
  String get transferChoose => '选择备份文件…';

  @override
  String get transferFoot => '只有家庭网络中的设备才能打开这个页面。';

  @override
  String transferSending(Object name) {
    return '正在发送 $name…';
  }

  @override
  String get transferCheckTv => '请在电视上完成操作。';

  @override
  String get transferClosed => '电视已关闭这个页面。请从“备份与恢复”中重新打开。';

  @override
  String get transferCouldntTake => '电视无法接收这个文件。';

  @override
  String get transferCouldntReach => '无法连接到电视。电视上还显示着二维码吗？';

  @override
  String get includeShows => '包括节目';

  @override
  String get everyShow2 => '所有节目';

  @override
  String get decades => '年代';

  @override
  String get decadesHeading => '年代';

  @override
  String decadeYears(Object decade) {
    return '$decade年代';
  }

  @override
  String get channelActionTv => '动作频道';

  @override
  String get channelSciFiTv => '科幻频道';

  @override
  String get channelFantasyTv => '奇幻频道';

  @override
  String get channelMysteryThrills => '悬疑惊悚';

  @override
  String get genreAction => '动作';

  @override
  String get genreAdventure => '冒险';

  @override
  String get genreSciFi => '科幻';

  @override
  String get genreFantasy => '奇幻';

  @override
  String get genreThrillerMystery => '惊悚悬疑';

  @override
  String decadeTv(Object decade) {
    return '$decade节目';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$decade$genre节目';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return '$decade$genre电影';
  }

  @override
  String get errorReports => '错误报告';

  @override
  String get sendErrorReportsFrom => '从这台设备发送错误报告';

  @override
  String get errorReportsExplain =>
      '出现问题时，Nightingale TV 会向开发者发送一份简短报告：错误信息、应用版本、设备类型，以及最近的几个界面和频道号。服务器地址、密码和密钥、名称和文件路径会在发送前去除。节目标题和你观看的内容永远不会发送。';

  @override
  String get errorReportsOff => '关闭后，这台设备不会发送任何内容；等待发送的报告会被删除。';

  @override
  String get recentReports => '最近的报告';

  @override
  String get reportKindTest => '测试';

  @override
  String get reportKindVideo => '视频报告';

  @override
  String get reportKindError => '错误';

  @override
  String get reportKindExit => '意外退出';

  @override
  String get reportKindSlowStart => '启动缓慢';

  @override
  String get errorReportsAutomatic =>
      '应用意外退出或启动缓慢时，也会自动发送一份报告，包含之前的界面、频道、启动步骤和内存数据。';

  @override
  String get sendATestReport => '发送测试报告';

  @override
  String lastReportId(String id) {
    return '最近一次报告 ID：$id';
  }

  @override
  String get noReportSentYet => '这台设备还没有发送过报告。';

  @override
  String get quoteReportId => '向开发者反馈问题时，请提供这个 ID。';

  @override
  String testReportSent(String id) {
    return '测试报告已发送：$id';
  }

  @override
  String get testReportNotSent => '无法发送测试报告。请稍后再试。';

  @override
  String get reportsNotInBuild =>
      '这个版本的 Nightingale TV 不包含错误报告功能，因此永远不会发送任何内容。';

  @override
  String get sendAVideoReport => '发送视频报告';

  @override
  String get videoReportHelp =>
      '如果画面看起来不对，请按这里，然后返回某个频道。画面播放 10 秒后会发送报告，报告 ID 会显示在电视屏幕上。';

  @override
  String get videoReportArmed => '现在请返回某个频道。画面播放 10 秒后会发送视频报告。';

  @override
  String get videoReportTooSoon => '不到一分钟前刚发送过视频报告。请稍后再试。';

  @override
  String videoReportSent(String id) {
    return '视频报告已发送：$id';
  }

  @override
  String get videoReportsExplain =>
      '视频报告会发送有关设备、视频及其解码器的信息、画面的粗略颜色网格以及应用自身最近的日志；绝不会发送你所观看内容的图像。每次应用更新后，频道播放 10 秒时会发送一次。';

  @override
  String get unlockNightingaleTv => '解锁 Nightingale TV';

  @override
  String trialDaysLeftMenu(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '免费试用还剩 $count 天',
    );
    return '$_temp0';
  }

  @override
  String get purchasePending => '购买待处理';

  @override
  String get freeForDaysTitle => '免费 14 天';

  @override
  String welcomeTrialPrice(String price) {
    return 'Nightingale TV 可免费使用 14 天。之后，一次性支付 $price 即可永久解锁，并支持这个项目。';
  }

  @override
  String get welcomeTrial =>
      'Nightingale TV 可免费使用 14 天。之后，一次性购买即可永久解锁，并支持这个项目。';

  @override
  String get unlockNow => '立即解锁';

  @override
  String get startMyFreeTrial => '开始免费试用';

  @override
  String get lastDayOfTrial => '今天是免费试用的最后一天';

  @override
  String reminderPrice(String price) {
    return '免费试用结束后，一次性支付 $price 即可永久解锁 Nightingale TV，并支持这个项目。';
  }

  @override
  String get reminder => '免费试用结束后，一次性购买即可永久解锁 Nightingale TV，并支持这个项目。';

  @override
  String get freeTrialEnded => '你的免费试用已结束';

  @override
  String get unlockScreenText =>
      '一次性购买即可永久解锁 Nightingale TV，并支持这个项目。你的个人资料、频道和设置都还在。';

  @override
  String unlockForPrice(String price) {
    return '以 $price 解锁';
  }

  @override
  String get unlock => '解锁';

  @override
  String get checkMyPurchaseAgain => '重新检查我的购买';

  @override
  String get redeemPlayCode => '兑换 Play 代码';

  @override
  String get redeemCodeTitle => '兑换代码';

  @override
  String get redeemCodeText =>
      '请在手机或电脑上登录这台设备使用的 Google 账户，然后前往 play.google.com/redeem 兑换代码。之后选择“重新检查我的购买”。';

  @override
  String get noPurchaseFound => '未找到购买记录';

  @override
  String get noPurchaseFoundText =>
      '这台设备上的 Google 账户没有 Nightingale TV 的购买记录。如果你刚刚购买，请稍后再试。';

  @override
  String get purchaseNotCompleted => '购买未完成';

  @override
  String get purchaseNotCompletedText => '无法完成购买。没有任何更改；请稍后再试。';

  @override
  String get purchasePendingText =>
      '你的购买正在等待完成。在此期间 Nightingale TV 可以正常使用，完成后会自动解锁。';

  @override
  String get unlockedThankYou => '已解锁。感谢你支持 Nightingale TV。';

  @override
  String freeTrialDaysLeftAbout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '免费试用：还剩 $count 天',
    );
    return '$_temp0';
  }

  @override
  String couldntReadChannels(Object name) {
    return '无法读取 $name 的频道列表';
  }

  @override
  String channelNoLongerOn(Object server) {
    return '这个频道已不在 $server 上';
  }

  @override
  String channelsNoLongerOnServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个频道已不在服务器上',
    );
    return '$_temp0';
  }

  @override
  String get sharing => '分享';

  @override
  String get sharingIntroTitle => '添加也在用 Nightingale TV 的好友';

  @override
  String get sharingIntroWhat =>
      '通过分享，你可以添加同样使用 Nightingale TV 的好友。每个 Nightingale 个人资料都有自己的分享账户。';

  @override
  String get sharingIntroStored => '存储的内容：你的电子邮件、你的分享资料、你的好友，以及日后你分享和观看的内容。';

  @override
  String get sharingIntroNoVideo => '用户之间永远不会传送任何视频。';

  @override
  String get sharingSetUp => '设置';

  @override
  String get sharingEmailPrompt => '请输入你的电子邮件。我们会发送一个 6 位代码供你登录。';

  @override
  String get sharingEmailLabel => '电子邮件';

  @override
  String get sharingSendCode => '发送代码';

  @override
  String get sharingNotAnEmail => '请输入电子邮件地址，例如 name@example.com。';

  @override
  String sharingCodeSent(Object email) {
    return '我们已向 $email 发送了一个 6 位代码。请在这里输入。';
  }

  @override
  String get sharingCodeLabel => '6 位代码';

  @override
  String get sharingWrongCode => '代码不正确';

  @override
  String get sharingTooManyWrong => '代码错误次数过多。请发送新的代码。';

  @override
  String get sharingSendNewCode => '发送新代码';

  @override
  String sharingSendNewCodeIn(Object seconds) {
    return '发送新代码（$seconds 秒）';
  }

  @override
  String get sharingOtherEmail => '使用其他电子邮件';

  @override
  String get sharingUnavailable => '分享功能暂时不可用。请稍后再试。';

  @override
  String get sharingProfileTitle => '你的分享资料';

  @override
  String get sharingProfileIntro => '好友会看到这些内容。你的电子邮件永远不会显示。';

  @override
  String get sharingNameLabel => '显示名称';

  @override
  String get sharingHandleLabel => '用户名';

  @override
  String get sharingHandleRules => '请使用 3–20 个字母、数字或 _。';

  @override
  String get sharingHandleTaken => '这个用户名已被占用。';

  @override
  String get sharingNameRequired => '请输入显示名称。';

  @override
  String get sharingAvatar => '头像';

  @override
  String get sharingStationLabel => '电视台名称（可选）';

  @override
  String get sharingAddFriend => '添加好友';

  @override
  String get sharingCodeHelp =>
      '好友在 Nightingale TV 的“分享”→“添加好友”中输入这个代码，或打开链接。代码只能使用一次，7 天后过期。';

  @override
  String get sharingNewCode => '新代码';

  @override
  String get sharingSendInvite => '发送邀请';

  @override
  String get sharingEnterCode => '输入代码';

  @override
  String sharingInviteText(Object link) {
    return '在 Nightingale TV 上加我为好友：$link';
  }

  @override
  String get sharingFriends => '好友';

  @override
  String get sharingNoFriends => '还没有好友。分享你的代码来添加好友。';

  @override
  String get sharingBlocked => '已屏蔽';

  @override
  String get sharingRemoveFriend => '删除好友';

  @override
  String sharingRemoveFriendConfirm(Object name) {
    return '要删除好友 $name 吗？你们将不再是好友。';
  }

  @override
  String get sharingBlock => '屏蔽';

  @override
  String sharingBlockConfirm(Object name) {
    return '要屏蔽 $name 吗？这会将对方从好友中删除，对方也无法使用你的代码。';
  }

  @override
  String get sharingUnblock => '取消屏蔽';

  @override
  String sharingUnblockConfirm(Object name) {
    return '要取消屏蔽 $name 吗？对方可以用新代码再次添加你。';
  }

  @override
  String get sharingSignOutConfirm =>
      '要在这个个人资料上退出分享吗？你的分享账户和好友会保留。用你的电子邮件即可重新登录。';

  @override
  String get sharingDeleteAccount => '删除分享账户';

  @override
  String sharingDeleteConfirm(Object handle) {
    return '这会删除你的分享账户、分享资料（@$handle）、好友、邀请以及为其存储的所有内容，并在所有设备上退出登录。此操作无法撤销。';
  }

  @override
  String get sharingDeleted => '你的分享账户已删除。';

  @override
  String get sharingCodeFieldLabel => '好友的代码';

  @override
  String get sharingNotACode => '代码由 6 个字母和数字组成，例如 AB3K·9Q。';

  @override
  String sharingAddFriendQuestion(Object name, Object handle) {
    return '要添加 $name（@$handle）为好友吗？';
  }

  @override
  String get sharingOwnCode => '这是你自己的代码';

  @override
  String get sharingInviteGone => '这个邀请已过期或已被使用';

  @override
  String get sharingTooManyTries => '尝试次数过多。请稍后再试';

  @override
  String sharingNowFriends(Object name) {
    return '你和 $name 现在是好友了。';
  }

  @override
  String get sharingSwitchToAdult => '请切换到成人个人资料来添加好友。';

  @override
  String get sharingEditProfile => '编辑';

  @override
  String sharingStation(Object station) {
    return '电视台：$station';
  }

  @override
  String get sharingLiveCantShare => '直播频道通过你自己的调谐器播放，无法分享';

  @override
  String get sharingMusicCantShare => '音乐频道无法分享';

  @override
  String get sharingCopyCantShare => '别人分享给你的频道无法再次分享';

  @override
  String get sharingTooBig => '超过 20,000 个节目的频道无法分享';

  @override
  String get sharingNoneMatch => '这些节目都不在你的服务器上';

  @override
  String get sharingUpdateApp => '请更新 Nightingale TV 以添加这个频道。';

  @override
  String sharingStopsFollowing(Object name) {
    return '这个频道将不再跟随 $name 的更改。';
  }

  @override
  String sharingNewShares(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个频道',
    );
    return '$name 与你分享了 $_temp0。打开“菜单”→“分享”即可添加。';
  }

  @override
  String sharingNewSharesMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个频道',
    );
    return '有 $_temp0分享给了你。打开“菜单”→“分享”即可添加。';
  }

  @override
  String get sharingSharedWithYou => '分享给你的';

  @override
  String get sharingNothingShared => '没有待处理的内容。好友分享给你的频道会显示在这里。';

  @override
  String sharingMatched(Object matched, Object total) {
    return '已匹配 $matched / $total 个节目';
  }

  @override
  String sharingAddedAs(Object number) {
    return '已添加为频道 $number';
  }

  @override
  String get sharingDecline => '拒绝';

  @override
  String get sharingShareChannels => '分享频道';

  @override
  String get sharingShareChannelsHelp =>
      '好友会收到每个频道的描述，他们的应用会用自己的服务器重建频道。不会发送任何视频。';

  @override
  String get sharingChannelsYouShare => '你分享的频道';

  @override
  String get sharingNoChannelsShared => '你没有分享任何频道。';

  @override
  String get sharingStopSharing => '停止分享';

  @override
  String sharingStopSharingConfirm(Object name) {
    return '要停止分享 $name 吗？好友会保留他们的副本，但不会再收到你的更改。';
  }

  @override
  String sharingWith(Object names) {
    return '分享给 $names';
  }

  @override
  String get sharingShareWith => '分享给';

  @override
  String get sharingShare => '分享';

  @override
  String get sharingGetLink => '获取链接';

  @override
  String sharingSharedWith(Object names) {
    return '已分享给 $names';
  }

  @override
  String get sharingLinkHelp => '7 天内使用这个代码的人会成为你的好友，并获得这些频道。代码只能使用一次。';

  @override
  String sharingChannelsInviteText(Object link) {
    return '这是我在 Nightingale TV 上的一些频道：$link';
  }

  @override
  String get sharingPickChannel => '请至少选择一个频道。';

  @override
  String get sharingPickFriend => '请至少选择一位好友，或使用“获取链接”。';

  @override
  String get sharingNoFriendsToShare => '还没有好友。获取链接即可与新朋友分享。';

  @override
  String get sharingShareEllipsis => '分享…';

  @override
  String sharingSharedBy(Object name, Object handle) {
    return '由 $name（@$handle）分享';
  }

  @override
  String get sharingKeepUpdated => '保持更新';

  @override
  String sharingKeepUpdatedHelp(Object name) {
    return '跟随 $name 对这个频道的更改';
  }

  @override
  String get sharingNoLongerUpdated => '不再更新';

  @override
  String sharingChannelsOffer(Object name, Object handle, Object names) {
    return '$name（@$handle）与你分享了这些频道：$names。要添加 $name 为好友并获取这些频道吗？';
  }

  @override
  String sharingNowFriendsChannels(Object name) {
    return '你和 $name 现在是好友了。对方的频道正在“分享给你的”中等待。';
  }

  @override
  String get sharedTab => '分享';

  @override
  String get sharedTabRule => '你从好友的分享中添加的频道';

  @override
  String get presenceSetting => '显示我正在观看的内容';

  @override
  String presenceSettingValue(Object value) {
    return '显示我正在观看的内容：$value';
  }

  @override
  String get presenceQuestion => '让好友看到你正在观看什么吗？';

  @override
  String get presenceExplain =>
      '你观看时，好友会看到节目或电影以及频道。不会显示其他任何内容，你停止观看后也不会显示。在播放器按钮中选择“私密观看”可在关闭应用前隐藏这些信息。你可以随时在“分享”中更改这项设置。';

  @override
  String presenceWatchingOn(Object title, Object channel) {
    return '正在 $channel 观看《$title》';
  }

  @override
  String presenceWatchingChannel(Object channel) {
    return '正在观看 $channel';
  }

  @override
  String presenceIsWatching(Object name) {
    return '$name 正在观看';
  }

  @override
  String presenceAndOthersWatching(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友',
    );
    return '$name 和另外 $_temp0正在观看';
  }

  @override
  String presenceWatchingToo(Object name) {
    return '$name 也在观看';
  }

  @override
  String presenceAndOthersWatchingToo(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友',
    );
    return '$name 和另外 $_temp0也在观看';
  }

  @override
  String presenceNoticeOne(Object name) {
    return '$name 正在观看';
  }

  @override
  String presenceNoticeMany(Object names) {
    return '$names 正在观看';
  }

  @override
  String get watchPrivately => '私密观看';

  @override
  String get watchingPrivately => '正在私密观看';

  @override
  String get watchTogether => '一起看';

  @override
  String partyStartTitle(Object title) {
    return '一起看《$title》';
  }

  @override
  String get partyStartHelp => '每个人都从自己的服务器同步播放。最多选择 7 位好友，或获取链接。';

  @override
  String get partyNoFriends => '还没有好友：获取链接来邀请别人。';

  @override
  String get partyGetLink => '获取链接';

  @override
  String get partyStart => '开始';

  @override
  String get partyLinkHelp => '打开这个链接的任何人都会成为你的好友，并可以加入。';

  @override
  String partyInviteBanner(Object name, Object title) {
    return '$name 邀请你一起看《$title》';
  }

  @override
  String partyInviteBannerNoTitle(Object name) {
    return '$name 邀请你一起看';
  }

  @override
  String get partyJoin => '加入';

  @override
  String get partyNotNow => '以后再说';

  @override
  String partyJoinQuestion(Object name) {
    return '要加入 $name 的观影派对吗？';
  }

  @override
  String partyOn(Object title, Object channel) {
    return '$channel 上的《$title》';
  }

  @override
  String get partyInSync => '已同步';

  @override
  String get partyCatchingUp => '正在追赶';

  @override
  String get partyNotOnServers => '不在你的服务器上';

  @override
  String partyMissingTitle(Object title) {
    return '不在你的服务器上：$title';
  }

  @override
  String get partyMissingRejoin => '你会在下一个节目时重新加入。';

  @override
  String get partyInvite => '邀请';

  @override
  String get partyLeave => '离开';

  @override
  String get partyStay => '留下';

  @override
  String get partyLeaveQuestion => '要离开观影派对吗？';

  @override
  String get partyLeaveHostDetail => '你是主持人，因此派对会为所有人结束。';

  @override
  String get partyLeaveGuestDetail => '你会回到自己的频道。';

  @override
  String get partyHost => '主持人';

  @override
  String partyJoined(Object name) {
    return '$name 已加入';
  }

  @override
  String partyLeft(Object name) {
    return '$name 已离开';
  }

  @override
  String partyPaused(Object name) {
    return '$name 已暂停';
  }

  @override
  String partyResumed(Object name) {
    return '$name 已继续播放';
  }

  @override
  String partySkipped(Object name) {
    return '$name 已跳过';
  }

  @override
  String partyRestarted(Object name) {
    return '$name 已从头播放节目';
  }

  @override
  String partyWentLive(Object name) {
    return '$name 已返回直播';
  }

  @override
  String partyEnded(Object name) {
    return '$name 结束了观影派对';
  }

  @override
  String get partyLost => '与观影派对的连接已断开';

  @override
  String get partyFull => '这个观影派对已满';

  @override
  String get partyOver => '这个观影派对已结束';

  @override
  String get partyWatchParties => '观影派对';

  @override
  String get partyNoInvites => '目前没有观影派对邀请。';

  @override
  String partyChannelName(Object channel) {
    return '观影派对 · $channel';
  }

  @override
  String get partyReactions => '互动表情';

  @override
  String partyInvited(Object names) {
    return '已邀请 $names';
  }

  @override
  String get smbGuestsRefused => '这台电脑不允许访客登录。请输入用户名和密码。';

  @override
  String get smbNoAccess => '无法访问';

  @override
  String smbShareGone(String name) {
    return '$name 已不存在。';
  }

  @override
  String smbReadingFiles(String name) {
    return '正在读取 $name 上的文件…';
  }

  @override
  String smbScanningFolders(String name, int count) {
    return '正在扫描 $name：$count 个文件夹…';
  }

  @override
  String smbShareOnHost(String share, String host) {
    return '$host 上的 $share';
  }

  @override
  String get smbNotAnAddress =>
      '这不是共享文件夹的地址。请按 smb://电脑/共享名 或 \\\\电脑\\共享名 的格式输入。';

  @override
  String smbCantReach(String host) {
    return '无法连接到 $host。';
  }

  @override
  String smbAnotherShare(String name) {
    return '这不是 $name，而是另一个共享文件夹。';
  }

  @override
  String get smbMapOne => '请至少为一个文件夹选择内容类型。';

  @override
  String get smbShareButton => 'SMB 共享文件夹';

  @override
  String get smbFindTitle => '添加共享文件夹';

  @override
  String get smbFindHelp => '选择一台电脑或 NAS，或输入共享文件夹的地址。';

  @override
  String get smbAddress => '共享文件夹地址';

  @override
  String get smbSearching => '正在查找电脑…';

  @override
  String get smbSearchAgain => '重新查找';

  @override
  String get smbNoneFound => '未找到电脑。请输入共享文件夹的地址。';

  @override
  String smbSharesOn(String host) {
    return '$host 上的共享文件夹';
  }

  @override
  String smbNoShares(String host) {
    return '$host 上没有你能打开的共享文件夹。';
  }

  @override
  String get smbOld => 'SMB1：旧协议，未加密';

  @override
  String smbSignInTo(String host) {
    return '登录 $host';
  }

  @override
  String get smbDomain => '域（可选）';

  @override
  String get smbAsGuest => '以访客身份连接';

  @override
  String smbWhatsIn(String share) {
    return '$share 里有什么？';
  }

  @override
  String get smbMapHelp =>
      '为每个文件夹选择内容类型。保留为“无”的文件夹会被忽略；已选择的文件夹中的子文件夹可以单独选择。在文件夹名称上按 OK 可打开它。';

  @override
  String get smbTypeNone => '无';

  @override
  String get smbTypeTv => '电视节目';

  @override
  String get smbTypeMovies => '电影';

  @override
  String get smbTypeMusic => '音乐';

  @override
  String get smbTypeMusicVideos => '音乐视频';

  @override
  String get smbTypeHome => '家庭视频';

  @override
  String get smbTypeCommercials => '广告';

  @override
  String get smbTypeBumpers => '过场片段';

  @override
  String smbAsAbove(String type) {
    return '$type（同上）';
  }

  @override
  String get smbUp => '上一级文件夹';

  @override
  String get smbHistoryName => '历史记录名称';

  @override
  String get smbHistoryHelp =>
      '使用相同历史记录名称的电视会共享播放次数和续播位置。它们保存在共享文件夹中的隐藏文件夹 .nightingale 里，其他内容不会被更改。';

  @override
  String get smbKeepLocal => '在此设备上保存历史记录';

  @override
  String get smbReadOnly => '此共享文件夹为只读：历史记录保存在此设备上。';

  @override
  String get smbFoldersDone => '完成';

  @override
  String smbFilesLeft(int count) {
    return '正在读取 $count 个文件';
  }

  @override
  String smbHistoryOnShare(String name) {
    return '历史记录：在共享文件夹上，名称为“$name”';
  }

  @override
  String get smbHistoryOnDevice => '历史记录：在此设备上';

  @override
  String get smbHistoryReadOnly => '历史记录：在此设备上（共享文件夹为只读）';

  @override
  String get smbFolders => '文件夹';

  @override
  String smbCantPlay(int count) {
    return '无法播放（$count）';
  }

  @override
  String smbCantPlayTitle(String name) {
    return '无法播放 · $name';
  }

  @override
  String get smbCantPlayHelp =>
      '这些文件不会排入节目。修复文件或配对一台能转换的 Nightingale TV 后，请重新检查。';

  @override
  String get smbCheckAgain => '重新检查';

  @override
  String get smbCantPlayNone => '所有文件都能播放。';

  @override
  String get smbReasonDamaged => '已损坏';

  @override
  String get smbReasonNoVideo => '没有画面';

  @override
  String get smbReasonTooMuch => '超出此设备的能力，也没有其他 Nightingale TV 可以转换';

  @override
  String smbRenameTitle(String name) {
    return '重命名 $name';
  }

  @override
  String smbFoldersTitle(String name) {
    return '文件夹 · $name';
  }

  @override
  String get smbSave => '保存';

  @override
  String get smbQualityNote =>
      '共享文件夹中的文件由已配对的另一台 Nightingale TV 转换以适应网络；没有的话会按原样播放，因为在此设备上转换并不能减轻网络负担。';

  @override
  String get smbHomeCantShare => '家庭视频无法分享';

  @override
  String get smbHomeVideo => '家庭视频';

  @override
  String get licencesTitle => '许可证';

  @override
  String get licencesHelp =>
      'Nightingale TV 是采用 GNU GPL 3 的自由软件。它使用以下软件，每个软件都遵循各自的许可证。';

  @override
  String get colorPurple => '紫色';

  @override
  String get colorGreen => '绿色';

  @override
  String get colorAmber => '琥珀色';

  @override
  String get colorTeal => '蓝绿色';

  @override
  String get colorMagenta => '洋红色';

  @override
  String get colorOlive => '橄榄色';

  @override
  String get colorSlate => '石板灰';

  @override
  String get colorCocoa => '可可色';

  @override
  String get colorWine => '酒红色';

  @override
  String get guideColor => '节目指南中的颜色';

  @override
  String guideColorTitle(String name) {
    return '节目指南中的颜色 · $name';
  }

  @override
  String get guideColorHelp => '来自此服务器的节目在节目指南中显示为此颜色。';

  @override
  String guideColorUsedBy(String color, String name) {
    return '$color · $name';
  }

  @override
  String get serverColorsSetting => '节目指南中的服务器颜色';

  @override
  String get serverColorsHelp => '每个节目显示为其播放来源服务器的颜色，节目指南下方有图例。';

  @override
  String playsFrom(String name) {
    return '来自 $name';
  }

  @override
  String get convertForOthers => '为其他电视转换';

  @override
  String get convertForOthersHelp =>
      '无法播放共享文件夹中某个文件的电视会请这台电脑转换。这台电脑的某个个人资料中需要有相同的共享文件夹，并且只转换其已指定文件夹中的文件。';

  @override
  String convertCode(String code) {
    return '配对码：$code';
  }

  @override
  String get convertPairedTvs => '已配对的电视';

  @override
  String get convertNoTvs => '还没有配对的电视。';

  @override
  String get convertHelpers => '在其他 Nightingale TV 上转换';

  @override
  String get convertHelpersHelp =>
      '电脑上的 Nightingale TV 或 Docker 服务器可以转换此设备无法播放、或无法足够快播放的共享文件夹文件。在那边打开“为其他电视转换”，然后用显示的代码配对。';

  @override
  String get convertFind => '在网络中查找';

  @override
  String get convertTypeAddress => '输入地址';

  @override
  String get convertAddress => 'Nightingale TV 的地址';

  @override
  String convertEnterCode(String name) {
    return '$name 上显示的代码';
  }

  @override
  String convertWrongCode(String name) {
    return '代码不对，或 $name 没有响应。';
  }

  @override
  String get convertNoneFound =>
      '未找到可转换的 Nightingale TV。请确认那边已打开“为其他电视转换”，或输入地址。';

  @override
  String convertAddShareOn(String share, String name) {
    return '在 $name 上添加 $share';
  }

  @override
  String convertNotAnswering(String name) {
    return '$name 没有响应';
  }

  @override
  String get convertPair => '配对';

  @override
  String get serverKindsHelp =>
      '你可以添加 Jellyfin、Emby、Plex、YouTube 和 SMB 共享文件夹（NAS 或电脑上的共享文件夹）。';

  @override
  String get youTube => 'YouTube';

  @override
  String get youTubeTerms => '登录即表示你同意 YouTube 服务条款和 Nightingale TV 隐私政策。';

  @override
  String get youTubeTermsOfService => 'YouTube 服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String youTubeEnterCode(String address) {
    return '在手机或电脑上前往 $address，输入此代码。';
  }

  @override
  String get openGoogleDevice => '打开 google.com/device';

  @override
  String get signInWasCancelled => '登录已取消';

  @override
  String get youTubeChannelsTitle => 'YouTube 频道';

  @override
  String youTubePickedOf(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get notSubscribed => '未订阅';

  @override
  String get searchSubscriptions => '搜索你的订阅';

  @override
  String get noSubscriptions => '此账户没有订阅';

  @override
  String get noSubscriptionsMatch => '没有匹配的订阅';

  @override
  String removeYouTubeChannels(String names) {
    return '要从节目指南中移除 $names 吗？';
  }

  @override
  String youTubeChannelCount(int count) {
    return '$count 个频道';
  }

  @override
  String get googleClient => 'Google 客户端';

  @override
  String get googleClientShared => 'Nightingale TV 的';

  @override
  String get googleClientOwn => '你自己的';

  @override
  String youTubeDailyLimit(String time) {
    return '已达到 YouTube 的每日上限。新视频将在 $time 之后到来。';
  }

  @override
  String get useMyOwnClient => '使用我自己的客户端';

  @override
  String get signInToYouTubeAgain => '请重新登录 YouTube';

  @override
  String get ownClientTitle => '你自己的 Google 客户端';

  @override
  String get clientId => '客户端 ID';

  @override
  String get clientSecret => '客户端密钥';

  @override
  String get openClientFile => '打开文件';

  @override
  String get clientFileNotRead => '该文件不是 Google 客户端文件';

  @override
  String get useThisClient => '使用此客户端';

  @override
  String get useSharedClient => '使用 Nightingale TV 的客户端';

  @override
  String get ownClientStep1 => '打开 console.cloud.google.com 并创建一个项目。';

  @override
  String get ownClientStep2 => '启用 YouTube Data API v3。';

  @override
  String get ownClientStep3 => '设置 OAuth 同意屏幕，并添加 youtube.readonly 范围。';

  @override
  String get ownClientStep4 => '将发布状态设为“正式版”。';

  @override
  String get ownClientStep5 => '创建类型为“电视和受限输入设备”的 OAuth 客户端。';

  @override
  String get ownClientStep6 => '在此输入客户端 ID 和密钥，或打开下载的文件。';

  @override
  String ownClientGuide(String address) {
    return '完整指南：$address';
  }

  @override
  String get clientRefused => 'Google 不接受此客户端。它必须是“电视和受限输入设备”类型。';

  @override
  String get noVideosYet => '暂无视频';

  @override
  String get youTubeRefusedPlayer => 'YouTube 不接受此播放器';

  @override
  String get youTubeNeedsWebView => 'YouTube 需要 Android System WebView';

  @override
  String getItFromPlayStore(String address) {
    return '从 Play 商店获取：$address';
  }

  @override
  String youTubeChannelSource(String title) {
    return 'YouTube 频道：$title';
  }

  @override
  String publishedOn(String date) {
    return '发布于 $date';
  }

  @override
  String get youTubeCantBeShared => '无法分享 YouTube 频道';

  @override
  String get youTubeAlreadyRemovedQuota => '请在 YouTube 每日上限重置后再试。';

  @override
  String get youTubeAccount => 'YouTube 账户';

  @override
  String get couldNotReachGoogle => '无法连接 Google，请重试。';

  @override
  String get youTubeDailyLimitShort => '已达到 YouTube 的每日上限。';

  @override
  String get youTubeNoBreaks => 'YouTube 频道没有广告时间。';

  @override
  String get youTubeNoBlocks => 'YouTube 频道不能有节目时段。';

  @override
  String get youTubeAccessNeeded =>
      'Nightingale TV 需要查看你的 YouTube 订阅。请输入新代码并允许。';

  @override
  String get youTubeRemoveBody =>
      '它的频道会从频道列表中移除，Nightingale TV 对你 YouTube 账号的访问也会结束。';

  @override
  String get playerQuality => '画质';

  @override
  String playerQualityValue(String value) {
    return '画质：$value';
  }

  @override
  String get playerQualityAuto => '自动';

  @override
  String get playerQualityOriginal => '原画';

  @override
  String playerQualityMbps(int mbps) {
    return '$mbps Mbps';
  }

  @override
  String get youTubeNoClient => '此版本没有 YouTube 客户端。README 中说明了如何添加。';

  @override
  String youTubeSharedLimit(int limit) {
    return 'Nightingale TV 的客户端最多允许 $limit 个 YouTube 频道。如需更多，请在 服务器 → YouTube → Google 客户端 中使用你自己的客户端。';
  }

  @override
  String youTubeSharedTooMany(int limit) {
    return 'Nightingale TV 的客户端最多允许 $limit 个 YouTube 频道。请先在“频道”中移除一些。';
  }

  @override
  String lastBackedUp(Object when) {
    return '上次备份：$when';
  }

  @override
  String get notBackedUpYet => '尚未备份。';

  @override
  String get undoRestore => '撤销恢复';

  @override
  String get undoLineupReset => '撤销重置频道列表';

  @override
  String undoDeleting(Object name) {
    return '撤销删除 $name';
  }

  @override
  String get undoDeletingAProfile => '撤销删除个人资料';

  @override
  String get undoUpdate => '撤销更新';

  @override
  String get undoLineupCleanup => '撤销整理频道列表';

  @override
  String undoTitle(Object action, Object time) {
    return '$action · $time';
  }

  @override
  String undoPointSaved(Object when, Object profiles) {
    return '保存于 $when：$profiles';
  }

  @override
  String get pickThePlaylistFileAgain => '请重新选择播放列表文件';

  @override
  String get pickTheGuideFileAgain => '请重新选择节目指南文件';

  @override
  String get playlistFileNotOnDevice => '此设备上没有播放列表文件';

  @override
  String get guideFileNotOnDevice => '此设备上没有节目指南文件';

  @override
  String get youTubeServerOwnClient => '服务器模式使用你自己的 Google 客户端。';

  @override
  String get uploadJsonFile => '上传 JSON 文件';

  @override
  String get continueStep => '继续';

  @override
  String get watchNoChannels => '此个人资料没有 YouTube 频道。请在 服务器 中添加 YouTube。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get onlyChannelsYou => '只能移除你自己新增的頻道。可以改為隱藏這個頻道。';

  @override
  String get music => '音樂';

  @override
  String get nothingInThe => '媒體庫中沒有符合的內容。';

  @override
  String get chooseSongsOr => '請選擇歌曲或音樂影片。';

  @override
  String get blockChannel => '節目時段頻道';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return '這與同一頻道上的「$title」（$clash）重疊。';
  }

  @override
  String get chooseSomeShows => '請為這個節目時段選擇要播放的節目或電影。';

  @override
  String nothingInThis(Object shortLabel) {
    return '這個組合中沒有分級為 $shortLabel 或更高的內容。請選擇較低的分級或其他節目。';
  }

  @override
  String get theLineupsShows => '頻道列表中的節目沒有任何集數。請選擇其他節目。';

  @override
  String get addAShow => '請在頻道列表中新增一個節目。';

  @override
  String get chooseAChannel => '請選擇一個頻道。';

  @override
  String get theBlockHas => '節目時段的結束時間必須與開始時間不同。';

  @override
  String get pickAtLeast => '請至少選擇一天。';

  @override
  String get giveTheBlock => '請為節目時段輸入標題。';

  @override
  String get thisChannelDoesnt => '這個頻道沒有時段。';

  @override
  String get onlyShuffledChannels => '只有隨機播放的頻道才能重新隨機排列。';

  @override
  String get chooseSomethingFor => '請選擇這個頻道要播放的內容。';

  @override
  String get onlyChannelsYouAdded => '只有你自己新增的頻道才能變更播放內容。';

  @override
  String get myChannel => '我的頻道';

  @override
  String get noneOfYour => '無法連線到你的任何伺服器。';

  @override
  String scanning(Object where) {
    return '正在掃描 $where…';
  }

  @override
  String get buildingChannels => '正在建立頻道…';

  @override
  String get notSignedIn => '尚未登入。';

  @override
  String isAlreadyIn(Object name) {
    return '$name 已在這個設定檔中';
  }

  @override
  String get thatServerIs => '這部伺服器已不在這個設定檔中';

  @override
  String get yourSessionExpired => '你的工作階段已過期。請重新登入。';

  @override
  String get m3uPlaylist => 'M3U 播放清單';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName 沒有直播電視頻道';
  }

  @override
  String couldntReach(Object serverName) {
    return '無法連線到 $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return '$serverName 直播電視';
  }

  @override
  String liveTvIs(Object serverName) {
    return '$serverName 直播電視已經是一個來源';
  }

  @override
  String get notSignedIn2 => '尚未登入';

  @override
  String get newGroup => '新增素材組';

  @override
  String get thisBackupIs => '這個備份已損毀：無法讀取其中一個頻道標誌。';

  @override
  String get thisBackupIsDamaged => '這個備份已損毀：無法讀取其中的直播電視匯出設定。';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return '這個備份已損毀：無法讀取 $name 的$what。';
  }

  @override
  String get liveTvSources => '直播電視來源';

  @override
  String thisBackupCant(Object problem) {
    return '無法還原這個備份。$problem';
  }

  @override
  String get thisBackupIsDamagedIts => '這個備份已損毀：無法讀取其中的設定檔。';

  @override
  String get thisFileIs => '這個檔案太大，不可能是 Nightingale TV 備份。';

  @override
  String get thisBackupWas => '這個備份是由較新版本的 Nightingale TV 建立的。';

  @override
  String get thisFileIsnt => '這個檔案不是 Nightingale TV 備份，或者已損毀。';

  @override
  String restoredTheBackup(Object toLocal) {
    return '已還原 $toLocal 的備份。';
  }

  @override
  String couldntRestoreThe(Object e) {
    return '無法還原備份：$e';
  }

  @override
  String couldntSaveA(Object e) {
    return '無法先儲存備份：$e';
  }

  @override
  String get automatic => '自動';

  @override
  String get nc1718 => 'NC-17 / 18 歲以上';

  @override
  String get tvMaR => 'TV-MA / R 以上';

  @override
  String get tv14Pg => 'TV-14 / PG-13 以上';

  @override
  String get off => '關閉';

  @override
  String get nowAndThen => '偶爾';

  @override
  String get always => '一律';

  @override
  String get truncate => '提前結束';

  @override
  String get offlineImage => '離線圖片';

  @override
  String get filler => '填補';

  @override
  String get leastWatchedFirst => '最少觀看的優先';

  @override
  String get shuffled => '隨機';

  @override
  String get inOrderShows => '依序（節目輪流播放）';

  @override
  String get channelsWhereEverything =>
      '所有播放內容（包括節目時段）均為 TV-Y、TV-Y7、TV-G 或 G 級的頻道。';

  @override
  String get musicVideoAnd => '音樂影片和電台頻道。';

  @override
  String get channelsThatPlay => '只播放電影、不播放集數或音樂的頻道。';

  @override
  String get channelsFromYour => '來自你的直播電視來源的頻道。';

  @override
  String get channelsYouMarked => '你加入最愛的頻道。';

  @override
  String get everyChannel => '所有頻道。';

  @override
  String get kids => '兒童';

  @override
  String get movies => '電影';

  @override
  String get liveTv2 => '直播電視';

  @override
  String get favorites => '最愛';

  @override
  String get all => '全部';

  @override
  String get theAccentsAre => '強調色是一個主題，每項為 theme 或 channel。';

  @override
  String get thoseArentRetro => '這些不是復古設定。';

  @override
  String get theOverlayTheme => '疊加層主題為 standard、vcr、cableBox 或 stationIdent。';

  @override
  String get theCrtEffect =>
      'CRT 效果為 off、softTube、livingRoom、arcade、studioMonitor 或 custom。';

  @override
  String get theSurroundImage => '邊框圖片是一個檔案名稱。';

  @override
  String get theSurroundIs => '邊框為 black、charcoal、channel 或 image。';

  @override
  String get thePictureShape => '畫面形狀為 original、fill43 或 fit43。';

  @override
  String get channelColor => '頻道顏色';

  @override
  String get theme => '主題';

  @override
  String get stationIdent => '台標';

  @override
  String get cableBox => '有線電視盒';

  @override
  String get vcr => '錄放影機';

  @override
  String get standard => '標準';

  @override
  String get custom => '自訂';

  @override
  String get studioMonitor => '攝影棚監看螢幕';

  @override
  String get arcade => '街機';

  @override
  String get livingRoom => '客廳';

  @override
  String get softTube => '柔和映像管';

  @override
  String get customColorIs => '自訂顏色為 natural、warm、faded 或 vivid。';

  @override
  String get customLinesIs => '自訂掃描線為 240 或 480。';

  @override
  String customIsOff(Object key) {
    return '自訂 $key 為 off、low、medium 或 high。';
  }

  @override
  String get thatIsntA => '這不是自訂樣式。';

  @override
  String get vivid => '鮮豔';

  @override
  String get faded => '褪色';

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
  String get image => '圖片';

  @override
  String get charcoal => '炭灰';

  @override
  String get black => '黑色';

  @override
  String get n43Fit => '4:3 符合';

  @override
  String get n43Fill => '4:3 填滿';

  @override
  String get original => '原始';

  @override
  String get thisChannelIs => '這個頻道暫停播出';

  @override
  String get offAir => '暫停播出';

  @override
  String get tail => '填補';

  @override
  String get postRoll => '節目後';

  @override
  String get midRoll => '節目中';

  @override
  String get preRoll => '節目前';

  @override
  String get commercials => '廣告';

  @override
  String get bumpers => '過場片段';

  @override
  String get pleaseStandBy => '請稍候';

  @override
  String get offTheAir => '暫停播出';

  @override
  String get wellBeRight => '馬上回來';

  @override
  String upNextAt(Object at) {
    return '$at 接下來播出';
  }

  @override
  String backOnThe(Object next, Object title) {
    return '$next 恢復播出《$title》';
  }

  @override
  String get processor => '處理器';

  @override
  String get graphicsCardNvenc => '顯示卡（NVENC）';

  @override
  String get graphicsCardVaapi => '顯示卡（VAAPI）';

  @override
  String get signInTo => '請在電視上登入這個設定檔，以匯出它的頻道。';

  @override
  String get signInToThis => '請在這裡登入這個設定檔，以匯出它的頻道。';

  @override
  String portIsIn(Object port) {
    return '連接埠 $port 已被其他程式占用。請選擇其他連接埠，然後在 Plex、Jellyfin 或 Emby 中更新。';
  }

  @override
  String anotherProfileAlready(Object port) {
    return '另一個設定檔已在使用連接埠 $port。';
  }

  @override
  String get pickAPort => '請選擇 1024 到 65535 之間的連接埠。';

  @override
  String get movie => '電影';

  @override
  String backOnTheAir(Object start, Object title) {
    return '$start 恢復播出《$title》。';
  }

  @override
  String get images => '圖片';

  @override
  String get couldNotRead => '無法讀取這張圖片。請試試 PNG、JPG、WebP 或 SVG。';

  @override
  String get thatFileIs => '這個檔案不是有效的 SVG。';

  @override
  String get thatImageIs => '這張圖片超過 20 MB。請選擇較小的圖片。';

  @override
  String get other => '其他';

  @override
  String get seasonsHolidays => '季節與節日';

  @override
  String get newsWeather => '新聞與天氣';

  @override
  String get sports => '體育';

  @override
  String get genres => '類型';

  @override
  String get kidsFamily => '兒童與家庭';

  @override
  String get tvMovies => '電視與電影';

  @override
  String get theServerWould => '伺服器拒絕轉換這個項目。';

  @override
  String get theServerHas => '伺服器沒有這個項目的可播放版本。';

  @override
  String get externalLabel => '外部';

  @override
  String get scanningChannelSources => '正在掃描頻道來源…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl 的回應不像 Jellyfin 伺服器。';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return '在 $serverUrl 找不到 Jellyfin 伺服器。$message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return '$path 發生伺服器錯誤 $statusCode。';
  }

  @override
  String get wrongUsernameOr => '使用者名稱或密碼錯誤，或者工作階段已過期。';

  @override
  String couldNotReach(Object e) {
    return '無法連線到伺服器（$e）。';
  }

  @override
  String get theServerTook => '伺服器回應時間過長。';

  @override
  String get theServerWouldNot => '伺服器拒絕轉換這個頻道。';

  @override
  String get musicVideo => '音樂影片';

  @override
  String movie2(Object year) {
    return '電影 · $year';
  }

  @override
  String get commercial => '廣告';

  @override
  String couldntReachThe(Object what) {
    return '無法連線到$what';
  }

  @override
  String theIsToo(Object what) {
    return '$what太大';
  }

  @override
  String theSAddress(Object what) {
    return '$what的位址不是網址';
  }

  @override
  String get noGuideInformation => '沒有節目資訊';

  @override
  String get serverLiveTv => '伺服器直播電視';

  @override
  String get theChannelHas => '這個頻道沒有串流位址。';

  @override
  String get couldntReadThe => '無法讀取節目表';

  @override
  String get couldntReachTheGuide => '無法連線到節目表';

  @override
  String get theSourceHas => '這個來源沒有播放清單';

  @override
  String get couldntReachThePlaylist => '無法連線到播放清單';

  @override
  String get couldntReadThePlaylist => '無法讀取播放清單檔案';

  @override
  String couldntRefresh(Object name) {
    return '無法重新整理 $name';
  }

  @override
  String get thePlaylistHas => '播放清單中沒有頻道';

  @override
  String get thatIsntAn => '這不是 M3U 播放清單';

  @override
  String get thatIsntAnXmltv => '這不是 XMLTV 節目表';

  @override
  String get theGuideIs => '節目表太大（超過 1 GB）';

  @override
  String get nightingaleTvBackups => 'Nightingale TV 備份';

  @override
  String get uninstallingThisApp => '解除安裝這個應用程式會刪除它的設定檔、頻道和設定，除非你事先備份或轉移它們。';

  @override
  String theStoreVersion(Object officialName) {
    return 'Google Play 版本會以獨立的應用程式「$officialName」與這個應用程式並存安裝，並有自己的設定。可免費使用 14 天，之後一次購買即可支持這個專案。安裝後，你可以從這裡把設定轉移過去。';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return '來自 Google Play 和官方 Nightingale TV APK 的更新會覆蓋安裝這個應用程式，並保留你的設定。你自己建置的版本會以獨立的應用程式「$ownBuildName」安裝，你可以從這裡把設定轉移過去。';
  }

  @override
  String get yourOwnBuild => '你自己建置的版本';

  @override
  String get officialNightingaleTv => '官方 Nightingale TV APK';

  @override
  String get installedFromGoogle => '從 Google Play 安裝';

  @override
  String get nightingaleTvOwn => 'Nightingale TV（自行建置版）';

  @override
  String get sleepTimerOff => '睡眠定時器已關閉';

  @override
  String get sleepAtEnd => '節目結束時睡眠';

  @override
  String sleepInMin(Object minutes) {
    return '$minutes 分鐘後睡眠';
  }

  @override
  String get forced => '強制';

  @override
  String get unknownLanguage => '未知語言';

  @override
  String didntStart(Object name) {
    return '$name 未能啟動';
  }

  @override
  String get thisDeviceCant => '這部裝置無法播放這個頻道的影片';

  @override
  String get thisChannelsStream => '這部裝置不支援這個頻道的串流類型';

  @override
  String refusedTheStream(Object name) {
    return '$name 拒絕了串流。它可能正在另一部裝置上播放。';
  }

  @override
  String yourAccountCant(Object server) {
    return '你的 $server 帳戶無法觀看這個頻道';
  }

  @override
  String cantReach(Object name) {
    return '無法連線到 $name';
  }

  @override
  String allOfS(Object server) {
    return '$server 的所有調諧器都在使用中';
  }

  @override
  String lostTheSignal(Object name) {
    return '$name 訊號中斷';
  }

  @override
  String get couldntPlayThat => '無法播放這一段。正在返回直播';

  @override
  String get backToLive => '返回直播';

  @override
  String get theServerTookToo => '伺服器開始轉換這個節目的時間過長。';

  @override
  String get nothingToPlay => '這個頻道沒有可播放的內容';

  @override
  String captionsOn(Object shown) {
    return '字幕已開啟：$shown';
  }

  @override
  String get captionsOn2 => '字幕已開啟';

  @override
  String get captionsOnNo => '字幕已開啟：這個節目沒有字幕';

  @override
  String get captionsOff => '字幕已關閉';

  @override
  String get guest => '訪客';

  @override
  String get thereHasTo => '至少要有一個成人設定檔。';

  @override
  String kidProfilesNeedPins(Object names) {
    return '只要還有兒童設定檔，每個成人設定檔都需要設定 PIN，以免兒童切換進去。請為 $names 設定 PIN。';
  }

  @override
  String get switchToAnother => '刪除這個設定檔前，請先切換到另一個設定檔。';

  @override
  String get me => '我';

  @override
  String get couldntOpenA => '無法為遙控器開啟網路連接埠。';

  @override
  String get notPaired => '未配對';

  @override
  String get phone => '手機';

  @override
  String get thatCodeDoesnt => '代碼不符。請核對電視上顯示的代碼。';

  @override
  String get openMenuPhone => '請在電視上開啟「選單」→「手機遙控器」進行配對';

  @override
  String yourAccountCantWatch(Object serverName) {
    return '你的 $serverName 帳戶無法觀看直播電視';
  }

  @override
  String get enterYourServer => '請輸入伺服器位址。';

  @override
  String get needsSignIn => '需要登入';

  @override
  String get cantBeReached => '無法連線';

  @override
  String isNotAnswering(Object name) {
    return '$name 的所有位址都沒有回應。它開機了嗎？';
  }

  @override
  String get everyServerOn => '這個 Plex 帳戶上的所有伺服器都已在這個設定檔中。';

  @override
  String get thisPlexAccount => '這個 Plex 帳戶沒有伺服器。請請伺服器的擁有者與你分享。';

  @override
  String quickConnectStopped(Object message) {
    return '快速連線已停止：$message';
  }

  @override
  String get enterYourUsername => '請輸入使用者名稱。';

  @override
  String get plexDidNot => 'Plex 未能切換使用者。';

  @override
  String plexTvError(Object statusCode) {
    return 'plex.tv 錯誤 $statusCode。';
  }

  @override
  String get yourPlexSign => '你的 Plex 登入已過期。';

  @override
  String couldNotReachPlex(Object e) {
    return '無法連線到 plex.tv（$e）。';
  }

  @override
  String get plexTvTook => 'plex.tv 回應時間過長。';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — 由 $ownerName 分享';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return '伺服器拒絕轉換這個項目（$transcodeDecisionText）。';
  }

  @override
  String get theServerHasNo => '伺服器上沒有這個項目的檔案；請重新整理媒體庫。';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl 的回應不像 Plex 伺服器。';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return '在 $serverUrl 找不到 Plex 伺服器。$message';
  }

  @override
  String get thePlexSign => 'Plex 登入已過期。';

  @override
  String channelIsNot(Object channelId) {
    return '頻道 $channelId 不在任何 DVR 上。';
  }

  @override
  String get noSuchUser => '沒有這個使用者。';

  @override
  String get yourCurrentPassword => '目前的密碼錯誤。';

  @override
  String get signInFirst => '請先登入。';

  @override
  String thereIsAlready(Object name) {
    return '已經有名為 $name 的使用者。';
  }

  @override
  String get thisAccountIs => '這個帳戶已停用。';

  @override
  String get chooseAnAdmin => '請選擇一個管理員帳戶。';

  @override
  String useAtMost(Object maxNameLength) {
    return '使用者名稱最多 $maxNameLength 個字元。';
  }

  @override
  String get enterAUser => '請輸入使用者名稱。';

  @override
  String useAtLeast(Object minPasswordLength) {
    return '請至少使用 $minPasswordLength 個字元。';
  }

  @override
  String get tooManyWrong => '密碼錯誤次數過多。請一分鐘後再試。';

  @override
  String get wrongUserName => '使用者名稱或密碼錯誤。';

  @override
  String get openTheSetup => '請開啟伺服器記錄中的設定連結。';

  @override
  String get makeSomeoneElse => '請先將其他人設為管理員。';

  @override
  String get noSuchProfile => '沒有這個設定檔。';

  @override
  String get onlyAnAdmin => '只有管理員才能這樣做。';

  @override
  String get thatProfileIsnt => '這個設定檔沒有指派給你。';

  @override
  String get enterAGrown => '要變更兒童設定檔的設定，請輸入成人的 PIN。';

  @override
  String get enterThisProfiles => '請輸入這個設定檔的 PIN。';

  @override
  String get reloadThePage => '請重新載入頁面後再試一次。';

  @override
  String somethingWentWrong(Object e) {
    return '發生問題：$e';
  }

  @override
  String get signInToThisProfile => '請先登入這個設定檔。';

  @override
  String get changedInAnother => '已在另一個視窗中變更。正在顯示最新內容。';

  @override
  String get wrongPin => 'PIN 錯誤。';

  @override
  String get tooManyWrongPins => 'PIN 錯誤次數過多。請一分鐘後再試。';

  @override
  String get theRoleIs => '角色為「admin」或「user」。';

  @override
  String get noSuchBackup => '沒有這個備份。';

  @override
  String get backupsAreOff => '備份已關閉。';

  @override
  String get noSuchEncoder => '沒有這個編碼器。';

  @override
  String get allow1To => '請允許 1 到 16 路串流。';

  @override
  String get noSuchQuality => '沒有這個畫質。';

  @override
  String get processorOnly => '僅處理器';

  @override
  String get liveTvExport => '直播電視匯出未在執行。';

  @override
  String get thoseArentPremiere => '這些不是首播設定。';

  @override
  String get theLogoMode => '標誌模式為 always、nowAndThen 或 off。';

  @override
  String get thatIsntAPicture => '這不是自訂標誌資料夾中的圖片。';

  @override
  String couldntSaveBackupNothingReset(Object e) {
    return '無法先儲存備份，因此沒有重設任何內容：$e';
  }

  @override
  String get theKindIs => '類型為「block」、「music」或「custom」。';

  @override
  String get thatIsntAPlay => '這不是播放順序。';

  @override
  String get musicChannelsOnly => '音樂頻道只能隨機播放。';

  @override
  String get channelNumbersStart => '頻道號碼從 1 開始。';

  @override
  String get slotLengthsAre => '時段長度為 15、30、60、90 或 120 分鐘。';

  @override
  String get thatIsntAChannel => '這不是頻道。';

  @override
  String get noSuchChannel => '沒有這個頻道。';

  @override
  String get thatPictureIs => '這張圖片太大（最大 5 MB）。';

  @override
  String get unknownAction => '未知的動作。';

  @override
  String get noSuchServer => '沒有這部伺服器。';

  @override
  String get startSigningIn => '請先開始登入。';

  @override
  String get aRestoreIs => '已有還原正在進行。';

  @override
  String get uploadTheBackup => '請重新上傳備份。';

  @override
  String get discoveryIsOff => '探索功能已關閉，請透過位址新增調諧器。若要開啟，請以主機網路模式執行容器。';

  @override
  String get sendKeys => '請傳送按鍵。';

  @override
  String get enterThePlaylists => '請輸入播放清單的位址，或選擇播放清單檔案';

  @override
  String get uploadTheFile => '請重新上傳檔案。';

  @override
  String get kidProfilesGet => '兒童設定檔沒有直播頻道。';

  @override
  String liveTvIsAlready(Object name) {
    return '$name 直播電視已新增';
  }

  @override
  String get noSuchSource => '沒有這個來源。';

  @override
  String get thatFileIsToo => '這個檔案太大（最大 32 MB）。';

  @override
  String get aPinIs => 'PIN 為 4 位數字。';

  @override
  String get noSuchRating => '沒有這個分級。';

  @override
  String get noSuchKind => '沒有這個類型。';

  @override
  String get onlyAnAdminCan => '只有管理員才能變更這一項。';

  @override
  String shouldBeA(Object key) {
    return '「$key」應為文字清單。';
  }

  @override
  String shouldBeAn(Object key) {
    return '「$key」應為物件。';
  }

  @override
  String shouldBeTrue(Object key) {
    return '「$key」應為 true 或 false。';
  }

  @override
  String shouldBeANumber(Object key) {
    return '「$key」應為數字。';
  }

  @override
  String shouldBeText(Object key) {
    return '「$key」應為文字。';
  }

  @override
  String get expectedAJson => '需要 JSON 物件。';

  @override
  String get thatIsToo => '一次傳送的內容太多。';

  @override
  String get aQualityLimit => '畫質上限至少為 500 kbps。';

  @override
  String get orderShouldName => '「order」應包含每部伺服器各一次。';

  @override
  String get orderIsMissing => '缺少「order」。';

  @override
  String get signOutOf => '若要變更主要伺服器，請先登出這個設定檔。';

  @override
  String get thoseArentPool => '這些不是素材組資料夾。';

  @override
  String get sendRoots => '請傳送根目錄。';

  @override
  String get thatIsntAPool => '這不是素材組類型。';

  @override
  String get giveThePool => '請為素材組命名。';

  @override
  String get liveChannelsHave => '直播頻道沒有廣告時間。';

  @override
  String get sendAPlan => '請傳送方案。';

  @override
  String get thatIsntABreak => '這不是廣告時間方案。';

  @override
  String get noSuchPool => '沒有這個素材組。';

  @override
  String get thatIsntAProgramming => '這不是節目時段。';

  @override
  String get noSuchBlock => '沒有這個節目時段。';

  @override
  String get sendEveryTab => '請將每個分頁各傳送一次。';

  @override
  String get sendChannelids => '請傳送 channelIds。';

  @override
  String get giveTheGroup => '請為群組命名。';

  @override
  String get noSuchGroup => '沒有這個群組。';

  @override
  String get restoringBringsBack => '還原後會找回你的設定檔、頻道、節目時段和設定。每個設定檔需要登入一次它的伺服器。';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels 個頻道',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup => '這部裝置上有你的設定備份：';

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get moveOkSelect => '◀▶ 移動    OK 選取';

  @override
  String get startFresh => '重新開始';

  @override
  String get restoreIt => '還原';

  @override
  String get couldntRestore => '無法還原';

  @override
  String get cancel => '取消';

  @override
  String get useYourPhone => '使用手機或電腦';

  @override
  String get openABackup => '開啟備份檔案';

  @override
  String get setUpThis =>
      '用 Nightingale TV 備份設定這部電視：你的設定檔、頻道、節目時段和設定。每個設定檔需要登入一次它的伺服器。';

  @override
  String get restoreFromA => '從備份還原';

  @override
  String get close => '關閉';

  @override
  String get thereYouCan =>
      '你可以在那裡下載這部電視的備份，或傳送一個備份到這裡還原。傳送的任何內容都會先在這部電視上確認。關閉這個視窗後，頁面也會關閉。';

  @override
  String get onAPhone => '在與這部電視連線同一個 Wi-Fi 的手機、平板電腦或電腦上，掃描 QR 碼或開啟：';

  @override
  String get couldntOpenANetwork => '無法為這個頁面開啟網路連接埠。';

  @override
  String get thePageStopped => '頁面在 15 分鐘無操作後已停止。請關閉後重新開啟。';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount和$last';
  }

  @override
  String get listSeparator => '、';

  @override
  String labelValue(Object label, Object value) {
    return '$label：$value';
  }

  @override
  String get restore => '還原';

  @override
  String get liveTvExportMoves => '直播電視匯出將轉移到這部裝置；請在舊裝置上將其關閉。';

  @override
  String willNeedTo(Object need) {
    return '$need 需要重新登入伺服器。';
  }

  @override
  String get itSetsUp => '它會依照備份中的內容設定這部電視。';

  @override
  String get itReplacesEverything => '它會取代這部電視上的所有內容。你目前的設定會先備份。';

  @override
  String restoreTheBackup(Object toLocal) {
    return '要還原 $toLocal 的備份嗎？';
  }

  @override
  String get delete => '刪除';

  @override
  String get saveToFile => '儲存為檔案';

  @override
  String get moveOkSelectEsc => '▲▼◀▶ 移動    OK 選取    ESC 返回';

  @override
  String get backupRestore => '備份與還原';

  @override
  String get aBackupHolds =>
      '備份包含每個設定檔及其頻道、節目時段、廣告和設定。每次有變更時都會保持最新。登入密碼永遠不會包含在內。';

  @override
  String couldntSaveThe(Object e) {
    return '無法儲存備份：$e';
  }

  @override
  String thatDidntWork(Object e) {
    return '操作失敗：$e';
  }

  @override
  String get aNewChannel => '新頻道在節目時段之外暫停播出，就像夜間收播的電視台一樣。';

  @override
  String get aNewChannelJust => '專為這個節目時段新增的頻道';

  @override
  String get moveOkChoose => '▲▼ 移動    OK 選擇    ESC 返回';

  @override
  String get chooseAChannel2 => '選擇頻道';

  @override
  String episodes(Object keyCount) {
    return '$keyCount 集';
  }

  @override
  String get moveOkAdd => '▲▼ 移動    OK 新增    ESC 返回';

  @override
  String get addAShow2 => '新增節目';

  @override
  String get remove => '移除';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 集',
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
  String get save => '儲存';

  @override
  String get everyDay => '每天';

  @override
  String get weekends => '週末';

  @override
  String get weekdays => '平日';

  @override
  String get days => '日期';

  @override
  String get starts => '開始';

  @override
  String get time => '時間';

  @override
  String get premieresAreOff => '首播已關閉';

  @override
  String get premieresAreOn => '首播已開啟';

  @override
  String get onTheAir => '播出中';

  @override
  String get episodesAddedTo =>
      '最近兩週新增到伺服器的集數，會在其節目頻道的夜間時段首播：每晚每個節目播出一集新集數，最長兩小時，並標示為 NEW。節目時段優先。';

  @override
  String get moveOkSelectEscCancel => '▲▼◀▶ 移動    OK 選取    ESC 取消';

  @override
  String get newEpisodePremieres => '新集數首播';

  @override
  String get theChannelGoes => '在這些時間，頻道會恢復一般節目。';

  @override
  String delete2(Object title) {
    return '要刪除「$title」嗎？';
  }

  @override
  String get addAnotherShow => '再新增一個節目';

  @override
  String get missingShow => '遺失的節目';

  @override
  String runsThenStarts(Object start) {
    return '播放 $start，然後從頭開始。';
  }

  @override
  String get fillsTheBlock => '填滿節目時段。';

  @override
  String longerThanThe(Object end, Object title) {
    return '比節目時段長：它會在 $end 結束，截斷 $title。';
  }

  @override
  String get onTheAirNow => '正在播出';

  @override
  String nextAiring(Object start) {
    return '下次播出 · $start';
  }

  @override
  String inAll(Object runtime) {
    return '共 $runtime';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies 部電影',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount 個節目',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => '還沒有內容。請選擇節目或電影。';

  @override
  String get nothingYetAdd => '還沒有內容。請在頻道列表中新增節目。';

  @override
  String get plays => '播放內容';

  @override
  String onLabel(Object number, Object name) {
    return '在 $number $name 播出';
  }

  @override
  String get noChannelChosen => '未選擇頻道';

  @override
  String get onANew => '在新頻道上（其他時間暫停播出）';

  @override
  String get untitledBlock => '未命名的節目時段';

  @override
  String get deleteBlock => '刪除節目時段';

  @override
  String get blockIsOff => '節目時段已關閉';

  @override
  String get blockIsOn => '節目時段已開啟';

  @override
  String get onlyShowsAnd => '只播放達到或高於這個分級的節目和電影。未分級的內容會被排除。';

  @override
  String get anyRating => '任何分級';

  @override
  String get minimumRating => '最低分級';

  @override
  String get chooseShowsMovies => '選擇節目和電影';

  @override
  String get showsAndMovies => '你選擇的節目和電影，依序或隨機播放。';

  @override
  String get yourShowsIn => '依這個順序播放你的節目，每次播出時各播下一集。如果還有剩餘時間，頻道列表會從頭開始。';

  @override
  String get aLineup => '頻道列表';

  @override
  String get aMix => '混合';

  @override
  String get whatItPlays => '播放內容';

  @override
  String get repeatsEveryYear => '每年重複。';

  @override
  String get to => '到';

  @override
  String get from => '從';

  @override
  String get onlyBetweenDates => '僅在指定日期之間';

  @override
  String get allYear => '全年';

  @override
  String get dates => '日期';

  @override
  String get nextDay => '（隔天）';

  @override
  String get ends => '結束';

  @override
  String get channel => '頻道';

  @override
  String get saturdayMorningCartoons => '週六早晨卡通';

  @override
  String get title => '標題';

  @override
  String get newProgrammingBlock => '新增節目時段';

  @override
  String get newLateNight => '新增深夜時段';

  @override
  String get editProgrammingBlock => '編輯節目時段';

  @override
  String next(Object next, Object next2) {
    return '下次：$next $next2';
  }

  @override
  String get onTheAirNow2 => '正在播出';

  @override
  String get noUpcomingAirings => '沒有即將播出的節目';

  @override
  String get itsChannelIs => '它的頻道已不存在。請選擇新的頻道。';

  @override
  String get turnedOff => '已關閉';

  @override
  String get blocksTakeOver => '節目時段會在你選擇的日期和時間接管頻道，例如週六早晨卡通。每次播出都會從上次停止的地方繼續。';

  @override
  String get moveOkEdit => '▲▼ 移動    OK 編輯    ESC 返回';

  @override
  String get programmingBlocks => '節目時段';

  @override
  String get newlyAddedEpisodes => '新增的集數，在其節目的頻道上';

  @override
  String get onLabel2 => '開啟';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips 個片段',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => '100 分鐘電影';

  @override
  String get n44MinDrama => '44 分鐘影集';

  @override
  String get n22MinSitcom => '22 分鐘情境喜劇';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: '，中間 $midCount 次廣告',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name：無廣告';
  }

  @override
  String get openAndClose => '廣告時間的開頭和結尾，來自設為過場片段的素材組';

  @override
  String get bumpers2 => '過場片段';

  @override
  String get toTheHalf => '補足到半點';

  @override
  String get toTheHour => '補足到整點';

  @override
  String get padsEachSlot => '將每個時段補足到整點，讓節目準時開始';

  @override
  String get tail2 => '填補';

  @override
  String get afterEachProgram => '每個節目之後';

  @override
  String get postRoll2 => '節目後';

  @override
  String get length => '長度';

  @override
  String get every => '間隔';

  @override
  String min(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String get breaksInsideShows => '節目和電影中間的廣告時間，盡量放在劇情轉折處';

  @override
  String get midRoll2 => '節目中';

  @override
  String get beforeEachProgram => '每個節目之前';

  @override
  String get preRoll2 => '節目前';

  @override
  String get onePool => '一個素材組…';

  @override
  String get allBumperPools => '所有過場片段素材組';

  @override
  String get none => '無';

  @override
  String clipsFrom(Object pool) {
    return '片段來源：$pool';
  }

  @override
  String get allPools => '所有素材組';

  @override
  String clips2(Object label) {
    return '$label片段';
  }

  @override
  String get leave => '離開';

  @override
  String get yourChangesTo => '你對廣告時間設定的變更將會遺失。';

  @override
  String get leaveWithoutSaving => '不儲存就離開嗎？';

  @override
  String get size => '大小';

  @override
  String get captions => '字幕';

  @override
  String get sampleCaption => '字幕範例';

  @override
  String get theServerDraws => '這些字幕由伺服器繪製到畫面中，因此無法在這裡變更大小。';

  @override
  String get findingSubtitles => '正在尋找字幕…';

  @override
  String get noSubtitlesFor => '這個節目沒有字幕';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours 小時 $inMinutes 分鐘';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed 天';
  }

  @override
  String get theChannelGoesAway => '這個頻道會連同它的節目時段及其在頻道群組中的位置一起刪除。';

  @override
  String remove2(Object name) {
    return '要移除「$name」嗎？';
  }

  @override
  String contentOf(Object name) {
    return '$name 的內容';
  }

  @override
  String get newChannel => '新頻道';

  @override
  String get defaultCard => '預設卡片';

  @override
  String get changeOfflineImage => '變更離線圖片…';

  @override
  String get offlineImage2 => '離線圖片…';

  @override
  String fillerPool(Object poolName) {
    return '填補素材組：$poolName';
  }

  @override
  String get slotLength => '時段長度';

  @override
  String get hideFromGuide => '從節目表中隱藏';

  @override
  String get showInGuide => '在節目表中顯示';

  @override
  String get favorite => '加入最愛';

  @override
  String get unfavorite => '從最愛中移除';

  @override
  String mainSetting(Object label) {
    return '主要設定（$label）';
  }

  @override
  String get channelLogo => '頻道標誌';

  @override
  String breaksOn(Object name) {
    return '$name 的廣告時間';
  }

  @override
  String get custom2 => '自訂…';

  @override
  String get commercials2 => '廣告';

  @override
  String get removeChannel => '移除頻道';

  @override
  String get reshuffle => '重新隨機排列';

  @override
  String get editContent => '編輯內容';

  @override
  String get number => '頻道號碼 +';

  @override
  String get number2 => '頻道號碼 −';

  @override
  String get sourcesLogo => '來源的標誌';

  @override
  String get changeIcon => '變更圖示';

  @override
  String get rename => '重新命名';

  @override
  String get channelName => '頻道名稱';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount 個節目時段',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return '每 $loop 重複一次';
  }

  @override
  String programs(Object playlistCount) {
    return '$playlistCount 個節目';
  }

  @override
  String get programmingBlocksOnly => '僅節目時段';

  @override
  String channelThere(Object n) {
    return '那裡的頻道 $n';
  }

  @override
  String channel2(Object number) {
    return '頻道 $number';
  }

  @override
  String get noChannelsYet => '還沒有頻道';

  @override
  String get guideRange => '節目表範圍';

  @override
  String get channelsEditOk => '▲▼ 頻道    ▶ 編輯    OK 選取    ESC 返回';

  @override
  String get channelsIcons => '頻道和圖示';

  @override
  String get howFarAhead => '節目表從現在起顯示多長時間。';

  @override
  String hours(Object hours) {
    return '$hours 小時';
  }

  @override
  String get theChannelLogo => '在電視和直播電視匯出中，顯示在畫面角落的頻道標誌。';

  @override
  String get name => '名稱';

  @override
  String get ok => '確定';

  @override
  String get channels2 => '頻道';

  @override
  String get groupName => '群組名稱';

  @override
  String group(Object name) {
    return '群組：$name';
  }

  @override
  String get deleteGroup => '刪除群組';

  @override
  String get itsTabLeaves => '它的分頁會從節目表中移除。頻道仍保留在你的頻道列表中。';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount 個頻道',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => '你選擇的頻道。';

  @override
  String get theTabsAt => '節目表頂端的分頁，依這個順序排列。隱藏的分頁和沒有頻道的分頁不會顯示。';

  @override
  String get channelGroups => '頻道群組';

  @override
  String get shown => '顯示';

  @override
  String get down => '下移';

  @override
  String get up => '上移';

  @override
  String get automatic2 => '· 自動';

  @override
  String channels4(Object channelIdsCount) {
    return '· $channelIdsCount 個頻道';
  }

  @override
  String get create => '建立';

  @override
  String get commercialsNeverShow => '廣告永遠不會出現在伺服器的觀看記錄中。';

  @override
  String get theSameAds => '每個人每次看到的都是相同的廣告。';

  @override
  String get bumperPoolsClips => '過場片段素材組的片段用於廣告時間的開頭和結尾，不會當作廣告播放。';

  @override
  String get howBreaksWork => '廣告時間如何運作';

  @override
  String get withATail => '使用填補時，時段會補足到整點。';

  @override
  String get adsShrinkTo => '廣告會縮短以符合時段，每次廣告時間不超過 5 分鐘。';

  @override
  String get aShortBreak =>
      '節目前有一段短廣告，節目中每 10 分鐘（電影為 12 分鐘）插入一次廣告，盡量放在劇情轉折處，其餘廣告放在節目後。';

  @override
  String get pickAutomaticFor => '選擇「自動」可獲得類似電視廣播的廣告時間，選擇「自訂」可自行設定。';

  @override
  String workingOn(Object current) {
    return '正在處理 $current…';
  }

  @override
  String get analysis => '分析';

  @override
  String couldNotBe(Object failed) {
    return '$failed 無法分析（檔案變更後會再試一次）';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return '已找到廣告點的節目：$programsDone / $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return '已分割的長影片：$reelsDone / $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders 個資料夾  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '來自 $used 個廣告素材組的 $clips。',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce => '素材組中有片段後，廣告時間才會開始。請在素材組中新增含有影片的資料夾。';

  @override
  String get breaksStartOnceA => '素材組中有片段後，廣告時間才會開始。它的長影片正在分割中。';

  @override
  String get breaksStartOnceAPool => '素材組中有片段後，廣告時間才會開始。請在下方建立素材組。';

  @override
  String breaksAreOff(Object clips) {
    return '廣告時間已關閉。你的素材組中有 $clips 可用。';
  }

  @override
  String get breaksAreOff2 => '廣告時間已關閉。';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 個片段',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return '上次掃描失敗：$syncError';
  }

  @override
  String get newPool => '新增素材組';

  @override
  String get pickTheFolders =>
      '請選擇伺服器上存放廣告和過場片段的資料夾。其中的影片會從一般頻道中移出，改為填補廣告時間。將素材組的類型設為「過場片段」，即可用它的片段作為廣告時間的開頭和結尾。';

  @override
  String get pools => '素材組';

  @override
  String get breakSettings => '廣告時間設定…';

  @override
  String get commercialBreaks => '廣告時間';

  @override
  String get breakSettings2 => '廣告時間設定';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count有了它，廣告點也會更自然。';
  }

  @override
  String waiting(Object waiting) {
    return '（$waiting 個等待中）。';
  }

  @override
  String get fullStop => '。';

  @override
  String get longCommercialVideos => '這部裝置無法分割沒有章節的長廣告影片';

  @override
  String get installFfmpegTo => '安裝 ffmpeg 以分割長廣告影片';

  @override
  String get picturesOnThis => '這部裝置上的圖片，最新的在前。大圖會縮小到 512 px。';

  @override
  String get noPicturesOn =>
      '這部裝置上還沒有圖片。請將 PNG 或 JPG 複製到它的 Download 資料夾或 USB 隨身碟中，然後再試一次。';

  @override
  String get lookingForPictures => '正在尋找圖片…';

  @override
  String get couldntReadThePictures => '無法讀取這部裝置上的圖片。';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV 沒有查看這部裝置上圖片的權限。請在 Android 的「設定」›「應用程式」›「Nightingale TV」›「權限」中允許「相片和影片」，然後再試一次。';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ 移動    OK 選擇    ESC 取消';

  @override
  String get chooseAPicture => '選擇圖片';

  @override
  String thePoolHasnt(Object error) {
    return '$error  素材組沒有變更。';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  沒有任何變更。';
  }

  @override
  String get couldntReachTheServer => '無法連線到伺服器';

  @override
  String get tryAgain => '重試';

  @override
  String get nothingInside => '裡面沒有內容';

  @override
  String get noMovies => '沒有電影';

  @override
  String inside(Object childrenCount) {
    return '裡面有 $childrenCount 項';
  }

  @override
  String get video => '影片';

  @override
  String collection(Object name) {
    return '$name（合集）';
  }

  @override
  String get included => '已包含';

  @override
  String get nothingInside2 => '裡面沒有內容。';

  @override
  String get loadingFolders => '正在載入資料夾…';

  @override
  String get pressOnA => '在媒體庫上按 ▶ 查看其中的內容。';

  @override
  String get done => '完成';

  @override
  String ticked(Object _pickedCount) {
    return '已勾選 $_pickedCount 項';
  }

  @override
  String get nothingTickedYet => '還沒有勾選任何內容。勾選媒體庫即可使用全部內容，或按 ▶ 選擇其中的內容。';

  @override
  String get wholeLibrary => '整個媒體庫';

  @override
  String get libraries => '媒體庫';

  @override
  String get loadingLibraries => '正在載入媒體庫…';

  @override
  String get moveOkTick => '▲▼ 移動    OK 勾選    ▶ 開啟    ◀ 返回上層    ESC 取消';

  @override
  String foldersFor(Object poolName) {
    return '$poolName 的資料夾';
  }

  @override
  String get chooseFolders => '選擇資料夾';

  @override
  String get chooseWhatPlays => '選擇這個頻道播放的內容';

  @override
  String get endsEarly => '提前結束';

  @override
  String get madeFromThis => '由這個頻道的節目和電影產生，並隨媒體庫更新。變更任何內容後，它就歸你所有。';

  @override
  String get fromTheLineup => '來自頻道列表';

  @override
  String yesterday(Object t) {
    return '昨天 $t';
  }

  @override
  String today(Object t) {
    return '今天 $t';
  }

  @override
  String behind(Object d) {
    return '落後 $d';
  }

  @override
  String hr(Object h) {
    return '$h 小時';
  }

  @override
  String get underAMinute => '不到一分鐘';

  @override
  String get noProgramming => '沒有節目';

  @override
  String get today2 => '今天';

  @override
  String get tuning => '正在轉台…';

  @override
  String get offAir2 => '暫停播出';

  @override
  String get noSignal => '無訊號';

  @override
  String left(Object now) {
    return '剩餘 $now';
  }

  @override
  String get nothingScheduled => '沒有節目安排';

  @override
  String get back => '返回';

  @override
  String get sleep => '睡眠';

  @override
  String get menu => '選單';

  @override
  String get nightingaleTvGuide => 'NIGHTINGALE TV 節目表';

  @override
  String nowPlaying(Object title) {
    return '正在播放：$title';
  }

  @override
  String get mMenu => 'M 選單';

  @override
  String get escBackTo => 'ESC 返回電視';

  @override
  String get channelsTabsTime => '▲▼ 頻道     ▲ 分頁     ◀▶ 時間     OK 觀看     ';

  @override
  String get color => '顏色';

  @override
  String get channelsUsingIt => '使用它的頻道會改回預設圖示。';

  @override
  String get deleteThisIcon => '要刪除這個圖示嗎？';

  @override
  String get uploadImage => '上傳圖片…';

  @override
  String get pngJpgWebp => 'PNG、JPG、WebP、GIF 或 SVG。大圖會自動縮小到 512 px。';

  @override
  String get genericBadgesOnly => '這裡只有通用徽章。請在「我的圖示」下上傳真實的電視台標誌。';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => '使用這個徽章';

  @override
  String get preview => '預覽';

  @override
  String get shape => '形狀';

  @override
  String get callLettersUp => '台名縮寫（最多 5 個字元）';

  @override
  String iconFor(Object name) {
    return '$name 的圖示';
  }

  @override
  String get couldntReadThat => '無法讀取這張圖片。請換一張試試。';

  @override
  String get myIcons => '我的圖示';

  @override
  String get showLogos => '顯示標誌';

  @override
  String get badges => '徽章';

  @override
  String get builtIn => '內建';

  @override
  String get couldntMoveThe => '無法轉移設定';

  @override
  String get send => '傳送';

  @override
  String thisBacksUp(Object counterpartName) {
    return '這會立即備份你的設定檔、頻道和設定，並在 $counterpartName 中開啟，$counterpartName 會在還原前先詢問你。這裡不會有任何變更。';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return '要將你的設定傳送到 $counterpartName 嗎？';
  }

  @override
  String get parentalControls => '家長監護';

  @override
  String get notNow => '稍後再說';

  @override
  String bringMySetup(Object counterpartName) {
    return '從 $counterpartName 把我的設定帶到這裡';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return '將我的設定轉移到 $counterpartName';
  }

  @override
  String get uninstallingEitherOne => '在轉移你想保留的設定之前解除安裝其中任何一個，都會刪除那份設定。';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName 和 $counterpartName 是兩個獨立的應用程式，各有自己的設定檔、頻道和設定。';
  }

  @override
  String get thankYouFor => '感謝你支持 Nightingale TV！';

  @override
  String isAlsoOn(Object counterpartName) {
    return '這部裝置上也有 $counterpartName';
  }

  @override
  String get aboutThisInstall => '關於這次安裝';

  @override
  String couldntOpen(Object counterpartName) {
    return '無法開啟 $counterpartName。';
  }

  @override
  String get nothingIsSet => '這裡還沒有任何設定，因此沒有可轉移的內容。';

  @override
  String yourSetupIs(Object counterpartName) {
    return '你的設定正在傳送到 $counterpartName';
  }

  @override
  String get guide => '節目表';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n / $keysCount';
  }

  @override
  String get saving => '正在儲存…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '已選擇 $_checkedCount / $total';
  }

  @override
  String get channelOrGroup => '頻道或群組名稱';

  @override
  String get search => '搜尋';

  @override
  String get moveOkCheck => '▲▼ 移動    OK 勾選    ESC 返回';

  @override
  String chooseChannels(Object name) {
    return '選擇頻道：$name';
  }

  @override
  String get add => '新增';

  @override
  String get readingThePlaylist => '正在讀取播放清單…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return '目前：播放清單的節目表，$guideUrl';
  }

  @override
  String get leaveEmptyTo => '留空則使用播放清單指定的節目表';

  @override
  String get xmltvGuideAddress => 'XMLTV 節目表位址';

  @override
  String get guideOptional => '節目表（選填）';

  @override
  String get httpProviderExample =>
      'http://provider.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => '播放清單位址';

  @override
  String get playlist => '播放清單';

  @override
  String get myIptv => '我的 IPTV';

  @override
  String get useAnAddress => '改用位址';

  @override
  String get chooseAFile => '選擇檔案';

  @override
  String get chooseAnotherFile => '選擇其他檔案';

  @override
  String get moveOkSelectEscBack => '▲▼ 移動    OK 選取    ESC 返回';

  @override
  String edit(Object name) {
    return '編輯 $name';
  }

  @override
  String get addAnM3u => '新增 M3U 播放清單';

  @override
  String get m3uPlaylists => 'M3U 播放清單';

  @override
  String get xmltvGuides => 'XMLTV 節目表';

  @override
  String get anIptvPlaylist => 'IPTV 播放清單（網址或檔案），如果有的話，再加上 XMLTV 節目表。';

  @override
  String get theChannelsAnd => '伺服器調諧器（天線、有線電視盒或 IPTV）的頻道和節目表。';

  @override
  String readingSChannels(Object server) {
    return '正在讀取 $server 的頻道…';
  }

  @override
  String checkingLiveTv(Object server) {
    return '正在檢查 $server 直播電視…';
  }

  @override
  String get addALive => '新增直播電視來源';

  @override
  String get itsChannelsLeave => '它的頻道會從節目表、群組和最愛中移除。';

  @override
  String get renameSource => '重新命名來源';

  @override
  String get edit2 => '編輯';

  @override
  String get refreshNow => '立即重新整理';

  @override
  String get chooseChannels2 => '選擇頻道';

  @override
  String get playlistFile => '播放清單檔案';

  @override
  String get notRefreshedYet => '尚未重新整理';

  @override
  String refreshed(Object lastRefresh) {
    return '已於 $lastRefresh 重新整理';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return '上次重新整理失敗：$lastError';
  }

  @override
  String get refreshing => '正在重新整理…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · $keyCount / $channelsCount 個頻道';
  }

  @override
  String get noSourcesYet => '還沒有來源。';

  @override
  String get addSource => '新增來源';

  @override
  String get realBroadcastsAnd =>
      '在節目表中加入真實的廣播和 IPTV：你伺服器的直播電視，或附 XMLTV 節目表的 M3U 播放清單。它們的頻道排在你的頻道之後。';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return '未在串流。已使用 $runningCount / $streamLimit 路串流。';
  }

  @override
  String get savePort => '儲存連接埠';

  @override
  String get port => '連接埠';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => '調諧器';

  @override
  String get enterAPort => '請輸入連接埠號碼。';

  @override
  String pinFor(Object name) {
    return '$name 的 PIN';
  }

  @override
  String get letPlexFind => '讓 Plex 自動尋找';

  @override
  String get discovery => '探索';

  @override
  String get encoder => '編碼器';

  @override
  String nowAtOnce(Object streamLimit) {
    return '目前：同時 $streamLimit 路。在其他地方觀看的每個頻道算一路串流。';
  }

  @override
  String get streamsAtOnce => '同時串流數';

  @override
  String get quality => '畫質';

  @override
  String get lineups => '頻道列表';

  @override
  String get liveTvExport2 => '直播電視匯出';

  @override
  String get automaticDiscoveryIsnt =>
      '這部電腦無法使用自動探索。請在 Plex、Jellyfin 或 Emby 中透過位址新增調諧器。';

  @override
  String get anyoneOnYour => '家用網路中的任何人都可以觀看這個頻道列表。';

  @override
  String get watchYourChannels =>
      '在家用網路中用 Plex、Jellyfin、Emby 或任何 IPTV 應用程式觀看你的頻道。播放時 Nightingale TV 必須保持開啟。';

  @override
  String get offline => '離線';

  @override
  String get online => '線上';

  @override
  String get added => '已新增';

  @override
  String get chooseAServer => '選擇伺服器';

  @override
  String get whosSigningIn => '誰要登入？';

  @override
  String get openPlexTv => '開啟 plex.tv/link';

  @override
  String get waitingForThe => '正在等待代碼連結…';

  @override
  String get goToPlex => '請在手機或電腦上前往 plex.tv/link 並輸入這個代碼。';

  @override
  String get signInWith => '使用 Plex 登入';

  @override
  String get waitingForApproval => '正在等待核准…';

  @override
  String onYourPhone(Object label) {
    return '請在手機或電腦上開啟 $label → 你的設定檔 → 快速連線，然後輸入這個代碼：';
  }

  @override
  String get quickConnect => '快速連線';

  @override
  String get signIn => '登入';

  @override
  String get password => '密碼';

  @override
  String get username => '使用者名稱';

  @override
  String signInTo2(Object name) {
    return '登入 $name';
  }

  @override
  String get differentServer => '其他伺服器';

  @override
  String get signInWithPassword => '使用密碼登入';

  @override
  String get quickConnectUse => '快速連線（使用手機）';

  @override
  String get connect => '連線';

  @override
  String get serverAddress => '伺服器位址';

  @override
  String get connectToYour => '連線到你的伺服器';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV 把你的影片變成全天候播出的頻道，並附有節目表。可連接 Jellyfin、Emby、Plex、YouTube，或 NAS 等 SMB 共用資料夾。隨意轉台，看看正在播什麼。';

  @override
  String get yourLibraryOn => '你的媒體庫，\n全天候播出。';

  @override
  String get welcomeToNightingale => '歡迎使用 Nightingale TV';

  @override
  String signInFor(Object name) {
    return '為 $name 登入';
  }

  @override
  String signInToAgain(Object name) {
    return '重新登入 $name';
  }

  @override
  String get addAServer => '新增伺服器';

  @override
  String foundNewPrograms(Object list) {
    return '找到了$list。新節目會在目前節目結束後立即在各自的頻道上開始播出。';
  }

  @override
  String get libraryRefreshed => '媒體庫已重新整理';

  @override
  String get nothingNew => '沒有新內容';

  @override
  String get yourChannelsAre => '你的頻道已是最新狀態。';

  @override
  String get refreshFailed => '重新整理失敗';

  @override
  String get moveOkSelectEscBackTo => '▲▼ 移動    OK 選取    ESC 返回電視';

  @override
  String get noPoolsYet => '還沒有素材組';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return '更新於 $fetchedAt $fetchedAt2';
  }

  @override
  String get libraryLabel => '媒體庫';

  @override
  String get account => '帳戶';

  @override
  String get watching => '觀看';

  @override
  String get exitNightingaleTv => '結束 Nightingale TV';

  @override
  String get signOut => '登出';

  @override
  String get yourChannelLineup => '你的頻道列表會被清除。自訂圖示會保留。';

  @override
  String get signOut2 => '要登出嗎？';

  @override
  String get fullScreenOn => '全螢幕開/關（F11）';

  @override
  String get nothingWasReset => '沒有重設任何內容';

  @override
  String get reset => '重設';

  @override
  String get rebuildsTheDefault =>
      '根據你的媒體庫重建預設頻道。你變更過的名稱、圖示和頻道號碼會被重設。你新增的頻道會保留。系統會先儲存一份備份，你可以在「備份與還原」中找回它們。';

  @override
  String get resetChannelLineup => '要重設頻道列表嗎？';

  @override
  String get resetChannelLineup2 => '重設頻道列表';

  @override
  String get refreshLibrary => '重新整理媒體庫';

  @override
  String get refreshingLibrary => '正在重新整理媒體庫…';

  @override
  String get servers => '伺服器';

  @override
  String get phoneRemote => '手機遙控器';

  @override
  String get profiles => '設定檔';

  @override
  String get retroLook => '復古外觀';

  @override
  String get playback => '播放';

  @override
  String get switchProfile => '切換設定檔';

  @override
  String get sleepTimer => '睡眠定時器';

  @override
  String get backToTv => '返回電視';

  @override
  String get removeAll => '全部移除';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return '配對於 $paired · 上次使用 $lastUsed';
  }

  @override
  String get noPhonesPaired => '還沒有配對的手機。';

  @override
  String get pairedPhones => '已配對的手機';

  @override
  String get blockedByThis => '被這部電腦的防火牆封鎖';

  @override
  String get someWiFi =>
      '有些 Wi-Fi 網路會隔離裝置（稱為 AP 隔離或用戶端隔離）。如果手機仍然無法連線，請為你的 Wi-Fi 關閉這項設定。';

  @override
  String get thePhoneHas => '手機必須連線到與這部電視相同的 Wi-Fi，而不是訪客網路或行動數據。';

  @override
  String get ifThePhone => '如果手機無法連線，可能是這部電腦的防火牆封鎖了它。請在這部電腦上開啟終端機並執行：';

  @override
  String get checkAgain => '重新檢查';

  @override
  String get thenChooseCheck => '然後選擇「重新檢查」。';

  @override
  String get thisComputersFirewall =>
      '這部電腦的防火牆阻止手機連線到遙控器。若要允許連線，請在這部電腦上開啟終端機並執行：';

  @override
  String get notConfirmedYet => '尚未確認 · 還沒有手機連線過';

  @override
  String get working => '正常';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return '正常 · 上次由 $name 使用，$lastUsed';
  }

  @override
  String get theRemoteIs => '遙控器已關閉。';

  @override
  String get orScanThe => '或用手機相機掃描 QR 碼。';

  @override
  String get andEnter => '並輸入  ';

  @override
  String get onYourPhoneOpen => '在你的手機上開啟';

  @override
  String get useYourPhoneAs =>
      '把手機當作遙控器：在手機上開啟一個網頁，就可以轉台、叫出節目表，或點一下頻道收看。不需要安裝任何東西。';

  @override
  String get everyPairedPhone => '所有已配對的手機都將無法當作遙控器，直到它們再次掃描這個畫面上的 QR 碼。';

  @override
  String get removeAllPhones => '要移除所有手機嗎？';

  @override
  String get thoseDidntMatch => '兩次輸入不一致。請再試一次。';

  @override
  String get enterTheSame => '請再次輸入相同的 4 位數字。';

  @override
  String get choose4Digits => '請設定 4 位數字。';

  @override
  String get thatPinIsnt => 'PIN 不正確。請再試一次。';

  @override
  String get clock => '時鐘';

  @override
  String get captions2 => '字幕';

  @override
  String get audio => '音訊';

  @override
  String get maximumStreamingBitrate => '最大串流位元率';

  @override
  String get converting => '轉換';

  @override
  String get afterThisLong =>
      '在這段時間內沒有按任何按鈕，Nightingale TV 會詢問是否還有人在看。如果一分鐘內沒有回應，它就會進入睡眠：播放停止，伺服器也會停止串流。設定了睡眠定時器時不會詢問。';

  @override
  String get askIfIm => '詢問我是否還在觀看';

  @override
  String get liveTvStill => '直播電視仍會顯示在儀表板上。';

  @override
  String get offWhatYou =>
      '關閉：你在這裡觀看的內容永遠不會改變伺服器上的播放次數、已觀看標記或續播位置，也不會顯示在它的儀表板上。';

  @override
  String get pauseSkipAnd => '暫停、跳過和重新播放目前的節目。關閉：每個頻道都依時間播放，就像全天候電視一樣。';

  @override
  String get pauseAndRewind => '暫停和倒轉';

  @override
  String get showsTheTime => '在畫面角落顯示時間。';

  @override
  String get onScreenClock => '螢幕時鐘';

  @override
  String get showACountdown => '在廣告開始前和節目回來前顯示倒數計時。';

  @override
  String get breakNotices => '廣告提示';

  @override
  String get theSizeOf => '所有節目和頻道中字幕的大小。';

  @override
  String get whileItsOn => '開啟時，環繞音效（Dolby、DTS）由這部裝置解碼，而不是直接傳送到擴大機。';

  @override
  String get evensOutThe => '觀看時自動平衡音量：調低吵鬧的廣告和節目，調高安靜的，你不必再伸手拿遙控器。';

  @override
  String get volumeLeveling => '音量平衡';

  @override
  String get pickALower =>
      '如果節目透過 Wi-Fi 或遠端連線播放時緩衝或卡頓，請選擇較低的位元率。「原始」永遠不會因為位元率而轉換。';

  @override
  String get connectedThroughPlex => '透過 Plex Relay 連線；畫質受限。';

  @override
  String get offNightingaleTv =>
      '關閉：Nightingale TV 一律以完整畫質播放你的原始檔案，伺服器不做額外工作。開啟：只有當節目或電影超過最大位元率，或原始檔案無法播放時，伺服器才會轉換。轉換會使用伺服器的處理器或顯示卡。廣告一律播放原始檔案。';

  @override
  String get transcodeOnlyIf => '僅在需要時轉碼（實驗性）';

  @override
  String get longerVideosAd => '較長的影片（廣告合集）會依章節或畫面變黑無聲的位置分割成個別的廣告。';

  @override
  String get videosOf5 => '5 秒到 3 分鐘的影片各算一個片段。';

  @override
  String get commercialsFillBreaks =>
      '廣告用於填補廣告時間。若是台標和「馬上回來」之類的片段，請將類型設為「過場片段」。';

  @override
  String get bumpersTakeAt => '除節目前外，過場片段最多占廣告時間的一半。超出這個長度的片段會被略過。';

  @override
  String stillToSplit(Object unsplit) {
    return '還有 $unsplit 待分割';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount 個長影片已分割成片段',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => '刪除素材組';

  @override
  String get addFolders => '新增資料夾…';

  @override
  String get libraryLabel2 => '媒體庫';

  @override
  String get noFoldersYet => '還沒有資料夾。';

  @override
  String get folders2 => '資料夾';

  @override
  String get type => '類型';

  @override
  String get poolName => '素材組名稱';

  @override
  String get commercialPool => '廣告素材組';

  @override
  String get itsVideosGo => '它的影片會回到你的一般頻道。原本從這裡取片段的廣告時間會改用所有素材組。';

  @override
  String get now => '現在';

  @override
  String get watch => '觀看';

  @override
  String get tuning2 => '正在轉台…';

  @override
  String get fullScreen => '全螢幕';

  @override
  String get noChannels => '沒有頻道';

  @override
  String get theirChannelsProgramming => '其頻道、節目時段和設定會被刪除，這部電視也會登出其伺服器。';

  @override
  String delete3(Object name) {
    return '要刪除 $name 嗎？';
  }

  @override
  String get giveTheProfile => '請為設定檔命名。';

  @override
  String get deleteProfile => '刪除設定檔';

  @override
  String get removePin => '移除 PIN';

  @override
  String get setAPin => '設定 PIN';

  @override
  String get changePin => '變更 PIN';

  @override
  String get noPinAnyone => '未設定 PIN。任何人都可以開啟這個設定檔。';

  @override
  String get lockedThePin => '已鎖定。開啟這個設定檔需要 PIN。';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith => '未分級的節目和電影會被排除。';

  @override
  String get allowedToWatch => '允許觀看';

  @override
  String get kid => '兒童';

  @override
  String get grownUp => '成人';

  @override
  String get whoItsFor => '使用者';

  @override
  String get color2 => '顏色';

  @override
  String get editProfile => '編輯設定檔';

  @override
  String get newProfile => '新增設定檔';

  @override
  String get watchingNow => '正在觀看';

  @override
  String get noPin => '無 PIN';

  @override
  String get pinLocked => 'PIN 已鎖定';

  @override
  String kid2(Object label, Object description) {
    return '兒童 · $label（$description）';
  }

  @override
  String get addProfile => '新增設定檔';

  @override
  String get everyoneGetsTheir =>
      '每個人都有自己的伺服器登入、頻道和節目時段。兒童設定檔只能看到符合其年齡分級的節目和電影。';

  @override
  String enterSPin(Object name) {
    return '請輸入 $name 的 PIN';
  }

  @override
  String get whosWatching => '誰在觀看？';

  @override
  String get moveOkChoose2 => '◀▶ 移動    OK 選擇';

  @override
  String get enterAGrownUps => '請輸入成人的 PIN。';

  @override
  String get grownUpsOnly => '僅限成人';

  @override
  String get yourChannelYour => '你的頻道，你的風格';

  @override
  String get testPattern => '測試圖';

  @override
  String get upNext8 => '接下來  ·  20:00';

  @override
  String get thisDevice => '這部裝置';

  @override
  String get glow => '光暈';

  @override
  String get curvature => '曲面';

  @override
  String get vignette => '暗角';

  @override
  String get mask => '蔭罩';

  @override
  String get lines => '線數';

  @override
  String get scanlines => '掃描線';

  @override
  String get customCrtStyle => '自訂 CRT 樣式';

  @override
  String accent(Object label) {
    return '強調色（$label）';
  }

  @override
  String get overlayTheme => '疊加層主題';

  @override
  String get crtEffect => 'CRT 效果';

  @override
  String get surround => '邊框';

  @override
  String get pictureShape => '畫面形狀';

  @override
  String get surroundImage => '邊框圖片';

  @override
  String get notAvailableOn => '這部裝置不支援';

  @override
  String get offTurnsOff => '「關閉」只會關閉這部裝置上的所有 CRT 效果。畫面形狀、邊框和疊加層主題保持不變。';

  @override
  String get effectsOnThis => '這部裝置上的效果';

  @override
  String get retroLook2 => '復古外觀';

  @override
  String get theseSettingsApply => '這些設定適用於執行這個應用程式的螢幕，不適用於直播電視匯出。';

  @override
  String get sameAsThe => '與設定檔相同';

  @override
  String get streamsFromThis => '來自這部伺服器的串流會維持在這個上限以下。設定檔本身的上限（播放）仍然適用，以較低者為準。';

  @override
  String qualityLimit(Object name) {
    return '畫質上限 · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      '它的節目會從你的頻道中移除，頻道號碼保持不變。它上面的來源和廣告資料夾會顯示為找不到，直到你變更它們。';

  @override
  String remove3(Object name) {
    return '要移除 $name 嗎？';
  }

  @override
  String get signingOutOf => '登出這個設定檔會變更它的主要伺服器。';

  @override
  String signedInAs(Object user) {
    return '已以 $user 身分登入';
  }

  @override
  String get mainServer => '主要伺服器';

  @override
  String get qualityLimit2 => '畫質上限';

  @override
  String get moveDown => '下移';

  @override
  String get moveUp => '上移';

  @override
  String get signInAgain => '重新登入';

  @override
  String get programsFromEvery =>
      '所有伺服器的節目會合併到同一個頻道列表。在多部伺服器上都有的作品，會從這個清單中第一個回應的伺服器播放（播放來源）；如果它停止回應，下一部會接手。';

  @override
  String get sleepingPressAny => '睡眠中 · 按任意按鈕繼續觀看';

  @override
  String goingToSleep(Object seconds) {
    return '$seconds 後進入睡眠';
  }

  @override
  String get goingToSleep2 => '即將進入睡眠';

  @override
  String goingToSleepIn(Object hint) {
    return '1 分鐘後進入睡眠。$hint';
  }

  @override
  String get pressAnyButton => '按任意按鈕繼續觀看';

  @override
  String goingToSleepIn0(Object padLeft) {
    return '0:$padLeft 後進入睡眠';
  }

  @override
  String get keepWatching => '繼續觀看';

  @override
  String get areYouStill => '你還在觀看嗎？';

  @override
  String sleepTimerMin(Object left) {
    return '睡眠定時器 · 剩餘 $left 分鐘';
  }

  @override
  String get whatsOnNow => '目前的節目沒有固定的結束時間。';

  @override
  String endOfThis(Object programEnd) {
    return '這個節目結束時 · $programEnd';
  }

  @override
  String get endOfThisProgram => '這個節目結束時';

  @override
  String get moveOkToggle => '▲▼◀▶ 移動    OK 切換    ESC 取消';

  @override
  String get usedWhenNo => '在沒有選擇節目時使用。也會用來篩選電影。';

  @override
  String get genres2 => '類型';

  @override
  String get includeMovies => '包含電影';

  @override
  String get add2 => '新增…';

  @override
  String get notFoundOn => '伺服器上找不到';

  @override
  String get collectionsFolders => '合集和資料夾';

  @override
  String get playOrder => '播放順序';

  @override
  String get clear => '清除';

  @override
  String get shows2 => '節目';

  @override
  String get pickSomethingTo => '請選擇要播放的內容。';

  @override
  String everyMovie(Object genreText) {
    return '所有$genreText電影';
  }

  @override
  String get everyMovie2 => '所有電影';

  @override
  String everyShow(Object genreText) {
    return '所有$genreText節目';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount或$last';
  }

  @override
  String decadesGenres(Object decades, Object genres) {
    return '$decades$genres';
  }

  @override
  String get settingUpYour => '正在設定你的頻道';

  @override
  String get couldntLoadYour => '無法載入你的媒體庫';

  @override
  String upNext(Object title) {
    return '接下來：$title';
  }

  @override
  String firstUp(Object title) {
    return '首先播放：$title';
  }

  @override
  String backTo(Object title) {
    return '返回 $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return '距離節目恢復還有 $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '距離$commercialBreakLabel還有 $left';
  }

  @override
  String startingWith(Object title) {
    return '從《$title》開始';
  }

  @override
  String upNext2(Object start) {
    return '接下來  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return '下一個 $start：$title';
  }

  @override
  String backOn(Object backOnAir) {
    return '$backOnAir 恢復播出';
  }

  @override
  String get offTheAir2 => '暫停播出';

  @override
  String get commercialBreak => '廣告時間';

  @override
  String tryingAgainAt(Object end) {
    return '將於 $end 重試';
  }

  @override
  String get exitFullScreen => '結束全螢幕';

  @override
  String get guide2 => '節目表';

  @override
  String thereIsNo(Object number) {
    return '沒有頻道 $number';
  }

  @override
  String get liveChannelsCant => '直播頻道無法暫停';

  @override
  String get curvatureAndGlow => '曲面和光暈已關閉：這部裝置效能不足';

  @override
  String get pressBackAgain => '再按一次返回鍵結束';

  @override
  String backAt(Object backAt) {
    return '$backAt 回來';
  }

  @override
  String get live => '直播';

  @override
  String get newLabel => '新';

  @override
  String nowPlayingOn(Object name) {
    return '$name 正在播放';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => '已暫停';

  @override
  String get seekBar => '進度列';

  @override
  String get live2 => '直播';

  @override
  String get forward30 => '快轉 30 秒';

  @override
  String get pause => '暫停';

  @override
  String get play => '播放';

  @override
  String get back10 => '倒轉 10 秒';

  @override
  String get restart => '從頭播放';

  @override
  String somethingWentWrong2(Object status) {
    return '發生問題（$status）。';
  }

  @override
  String get thatIsTooBig => '內容太大。';

  @override
  String get notFound => '找不到。';

  @override
  String get youCantDo => '你不能這樣做。';

  @override
  String get cantReachThe => '無法連線到伺服器。請檢查它是否正在執行。';

  @override
  String signOut3(Object userName) {
    return '登出 $userName';
  }

  @override
  String get changePassword => '變更密碼';

  @override
  String get users => '使用者';

  @override
  String get backups2 => '備份';

  @override
  String get serverAndSign => '伺服器和登入';

  @override
  String get channels5 => '頻道';

  @override
  String get thatProfileIsntYours => '這個設定檔不是你的，或者已不存在。';

  @override
  String get download => '下載';

  @override
  String get itReplacesThe => '它會取代這裡的設定檔、頻道和設定。';

  @override
  String get restoreThisBackup => '要還原這個備份嗎？';

  @override
  String get restoring => '正在還原…';

  @override
  String get restoreFromAFile => '從檔案還原…';

  @override
  String get downloadABackup => '立即下載備份';

  @override
  String get aBackupHoldsThe => '備份包含設定檔、頻道、節目時段、標誌、匯出設定和使用者帳戶（絕不包含密碼或登入權杖）。';

  @override
  String get restoredTheBackup2 => '已還原備份。';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return '來自 $whenValue（$device）：$profiles。它會取代這裡的設定檔、頻道和設定。';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return '下次播出：$start $end';
  }

  @override
  String programsInIts(Object total) {
    return '播放清單中有 $total 個節目。';
  }

  @override
  String get workingOutWhat => '正在決定播放內容…';

  @override
  String get later => '較晚';

  @override
  String get earlier => '較早';

  @override
  String get eachAiringPlays => '每次播出都會依序播放每個位置的下一集，如果還有剩餘時間就從頭開始。';

  @override
  String get aLineupOf => '節目列表';

  @override
  String get whatItPlays2 => '播放內容';

  @override
  String get onlyPartOf => '僅在一年中的部分時間';

  @override
  String get runsPastMidnight => '跨過午夜延續到隔天。';

  @override
  String get whenLabel => '時間';

  @override
  String get aNewChannelFor => '為這個節目時段新增的頻道';

  @override
  String get channel3 => '頻道';

  @override
  String get blocks => '節目時段';

  @override
  String get newBlock => '新增節目時段';

  @override
  String get programmingBlock => '節目時段';

  @override
  String get aBlockTakes => '節目時段會在固定時間接管頻道：例如「週六早晨卡通」，每週六 7:00 至 12:00。';

  @override
  String get overlayTheme2 => '疊加層主題';

  @override
  String get crtEffect2 => 'CRT 效果';

  @override
  String get chooseSurroundImage => '選擇邊框圖片…';

  @override
  String get surround2 => '邊框';

  @override
  String get pictureShape2 => '畫面形狀';

  @override
  String get chooseOfflineImage => '選擇離線圖片…';

  @override
  String get fillerPool2 => '填補素材組';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String get slotLength2 => '時段長度';

  @override
  String get everyProgramStarts => '每個節目都準點開始。每個時段的剩餘部分由填補補足。';

  @override
  String get itLeavesThe => '它會離開頻道列表。';

  @override
  String get itsProgrammingBlocks => '它的節目時段也會被移除。';

  @override
  String get removeThisChannel => '移除這個頻道';

  @override
  String get channelLogo2 => '頻道標誌';

  @override
  String get editCustomBreaks => '編輯自訂廣告時間…';

  @override
  String get musicChannelsOnlyShuffle => '音樂頻道只能隨機播放，且不會連續播放同一位藝人的作品。';

  @override
  String get playOrder2 => '播放順序';

  @override
  String get saveWhatIt => '儲存播放內容';

  @override
  String get canBeA => '可以作為節目最新集數的主頻道。';

  @override
  String get hiddenFromThe => '在節目表中隱藏';

  @override
  String get chooseIcon => '選擇圖示…';

  @override
  String get icon => '圖示';

  @override
  String get saveNameAnd => '儲存名稱和頻道號碼';

  @override
  String get aChannelAlready => '已占用這個頻道號碼的頻道會與這個頻道互換位置。';

  @override
  String get number3 => '頻道號碼';

  @override
  String get nameAndNumber => '名稱和頻道號碼';

  @override
  String get decadesNoneAny => '年代（不選：任何）';

  @override
  String get genresNoneAny => '類型（不選：任何）';

  @override
  String musicVideos(Object musicVideos) {
    return '音樂影片（$musicVideos）';
  }

  @override
  String songs(Object songs) {
    return '歌曲（$songs）';
  }

  @override
  String get newMusicChannel => '新增音樂頻道';

  @override
  String get aNightlySlot => '每晚在各節目主頻道上播出節目最新集數的時段。';

  @override
  String get mainSettings => '主要設定';

  @override
  String get glow2 => '光暈';

  @override
  String get curvature2 => '曲面';

  @override
  String get vignette2 => '暗角';

  @override
  String get mask2 => '蔭罩';

  @override
  String get lines2 => '線數';

  @override
  String get scanlines2 => '掃描線';

  @override
  String get customCrtStyle2 => '自訂 CRT 樣式';

  @override
  String accent2(Object label) {
    return '強調色（$label）';
  }

  @override
  String get hidden => '已隱藏';

  @override
  String get blockChannel2 => '節目時段頻道';

  @override
  String live3(Object source) {
    return '直播 · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return '$shownCount / $channelsCount 個頻道';
  }

  @override
  String get searchChannels => '搜尋頻道';

  @override
  String get resetLineup => '重設頻道列表';

  @override
  String get everyChannelEdit =>
      '所有頻道編輯都會被捨棄，並重新產生預設頻道列表。你新增的頻道會保留。系統會先儲存一份備份。';

  @override
  String get musicChannel => '音樂頻道';

  @override
  String get newBlockChannel => '新增節目時段頻道';

  @override
  String get channelsOwnPlans => '頻道自己的方案';

  @override
  String get setTypeBumpers => '設定類型：過場片段';

  @override
  String get setTypeCommercials => '設定類型：廣告';

  @override
  String get chooseFolders2 => '選擇資料夾…';

  @override
  String get plansThatDrew => '原本從它取片段的方案會改用所有素材組，它的影片也會回到頻道中。';

  @override
  String get renamePool => '重新命名素材組';

  @override
  String get poolActions => '素材組動作';

  @override
  String get aPoolIs =>
      '素材組是一組媒體庫資料夾，其中的影片用來填補廣告時間，而不會當作節目播出。素材組的類型決定它的片段是當作廣告播放，還是當作過場片段用於廣告時間的開頭和結尾。';

  @override
  String get pools2 => '素材組';

  @override
  String get breaks => '廣告時間';

  @override
  String clipsInAll(Object clips) {
    return '所有廣告素材組中共有 $clips 個片段。';
  }

  @override
  String get tunerAddress => '調諧器位址';

  @override
  String get changePort => '變更連接埠';

  @override
  String get exportThisProfile => '匯出這個設定檔';

  @override
  String get letsPlexAnd => '讓 Plex 等應用程式在網路上找到調諧器。';

  @override
  String get discovery2 => '探索';

  @override
  String get encoder2 => '編碼器';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return '自動：這部機器上為 $streamLimitInUse。';
  }

  @override
  String get streamsAtOnce2 => '同時串流數';

  @override
  String get quality2 => '畫質';

  @override
  String get settings => '設定';

  @override
  String get eachExportedProfile =>
      '每個匯出的設定檔都是 Plex、Jellyfin 或 Emby 的一個調諧器。請在它們的 DVR 設定中透過位址新增。';

  @override
  String get channelsInThis => '這個群組中的頻道';

  @override
  String get chooseChannels3 => '選擇頻道…';

  @override
  String channels7(Object channelIds) {
    return '$channelIds 個頻道';
  }

  @override
  String get itsChannelsStay => '它的頻道仍保留在頻道列表中。';

  @override
  String get renameGroup => '重新命名群組';

  @override
  String get groupActions => '群組動作';

  @override
  String get yourGroup => '你的群組';

  @override
  String get theOrderOf => '節目表中分頁的順序，以及要顯示哪些。';

  @override
  String get guideTabs => '節目表分頁';

  @override
  String get make => '建立';

  @override
  String get breaksBetweenPrograms => '節目之間的廣告時間';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '中間 $mids 次廣告',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return '$songs 首歌曲';
  }

  @override
  String get newEpisode => '新集數';

  @override
  String get noChannelsYet2 => '還沒有頻道。';

  @override
  String get noGuide => '沒有節目表';

  @override
  String get noneShown => '全部隱藏';

  @override
  String get allShown => '全部顯示';

  @override
  String channels8(Object name) {
    return '$name：頻道';
  }

  @override
  String get orChooseA => '或選擇節目表檔案…';

  @override
  String get emptyThePlaylists => '留空：使用播放清單本身的節目表（如果有）。';

  @override
  String get guideAddressXmltv => '節目表位址（XMLTV，選填）';

  @override
  String get orChooseAPlaylist => '或選擇播放清單檔案…';

  @override
  String get leaveEmptyToKeep => '留空則保留播放清單檔案。';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => '檔案';

  @override
  String get itsChannelsJoin => '這個設定檔登入該伺服器期間，它的頻道會加入進來。';

  @override
  String guide3(Object guideFile) {
    return '節目表：$guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return '播放清單檔案：$playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return '已於 $last $context 重新整理';
  }

  @override
  String get itsChannelsLeaveThe => '它的頻道會從頻道列表、群組和最愛中移除。';

  @override
  String read(Object fetched, Object context) {
    return '已於 $fetched $context 讀取。';
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
    return '$series 個節目 · $episodes 集 · $movies 部電影 · $songs 首歌曲 · $musicVideos 個音樂影片 · $commercials 個廣告影片';
  }

  @override
  String fromAs(Object server, Object user) {
    return '來自 $server，身分為 $user。';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name：媒體庫';
  }

  @override
  String get removeThePin => '移除 PIN';

  @override
  String get pinOptional => 'PIN（選填）';

  @override
  String get newPinLeave => '新 PIN（留空則保持不變）';

  @override
  String colour(Object i) {
    return '顏色 $i';
  }

  @override
  String get colour2 => '顏色';

  @override
  String get itsChannelsBlocks => '其頻道、節目時段和設定會被刪除。系統會先儲存一份備份。';

  @override
  String get exported => '已匯出';

  @override
  String kid3(Object label) {
    return '兒童 · $label';
  }

  @override
  String get noProfilesAre => '還沒有指派給你的設定檔。請聯絡管理員。';

  @override
  String signIn2(Object name) {
    return '為 $name 登入';
  }

  @override
  String get theLibraryIs => '正在重新讀取媒體庫；完成後，伺服器的節目會加入頻道。';

  @override
  String get itsLibraryIs => '正在讀取它的媒體庫並建立頻道。這需要一兩分鐘。';

  @override
  String isSignedIn(Object name) {
    return '$name 已登入。';
  }

  @override
  String get couldntDoThat => '無法完成操作。請再試一次。';

  @override
  String get itsChannelsStayIt => '它的頻道會保留；需要登入後才能播放。';

  @override
  String signOut4(Object name) {
    return '要登出 $name 嗎？';
  }

  @override
  String get signingIn => '正在登入…';

  @override
  String wasSignedIn(Object server, Object user) {
    return '曾以 $user 身分登入 $server。請重新登入。';
  }

  @override
  String signedInTo(Object server, Object user) {
    return '已以 $user 身分登入 $server。';
  }

  @override
  String get profileName => '設定檔名稱';

  @override
  String get nameAProfile => '為設定檔命名並登入你的媒體伺服器，系統就會建立並匯出它的頻道。';

  @override
  String get chooseABackup => '選擇備份檔案…';

  @override
  String get moveAHousehold => '從電視或其他伺服器將家庭設定轉移到這裡：其設定檔、頻道、節目時段、標誌和匯出設定。';

  @override
  String get restoreABackup => '還原備份';

  @override
  String get theServerIs => '伺服器正在啟動…';

  @override
  String get itsProgramsLeaveThe =>
      '它的節目會從頻道中移除，頻道號碼保持不變。它上面的來源和廣告資料夾會顯示為找不到，直到你變更它們。';

  @override
  String addAServerTo(Object name) {
    return '為 $name 新增伺服器';
  }

  @override
  String servers2(Object name) {
    return '$name：伺服器';
  }

  @override
  String get makeAccountAnd => '建立帳戶並登入';

  @override
  String get setPasswordAnd => '設定密碼並登入';

  @override
  String get passwordAgain => '再次輸入密碼';

  @override
  String get atLeast8 => '至少 8 個字元。';

  @override
  String get userName => '使用者名稱';

  @override
  String get adminAccount => '管理員帳戶';

  @override
  String get makeTheFirst => '建立第一個管理員帳戶。';

  @override
  String get setANew => '為管理員帳戶設定新密碼。';

  @override
  String get thisSetupLink => '這個設定連結已使用過，或者來自先前的啟動。請從伺服器記錄中開啟最新的連結，或者直接登入。';

  @override
  String get thePasswordsDont => '兩次輸入的密碼不一致。';

  @override
  String get newPasswordAgain => '再次輸入新密碼';

  @override
  String get newPassword => '新密碼';

  @override
  String get currentPassword => '目前的密碼';

  @override
  String get passwordChangedYour => '密碼已變更。你的其他瀏覽器已登出。';

  @override
  String get theNewPasswords => '兩次輸入的新密碼不一致。';

  @override
  String get theyAreSigned => '他們已登出，且無法再次登入。';

  @override
  String get cantSignIn => '無法登入；已在所有地方登出。';

  @override
  String get usersReachOnly => '使用者只能存取下面的設定檔。';

  @override
  String get adminsCanDo => '管理員可以對所有設定檔進行任何操作。';

  @override
  String get admin => '管理員';

  @override
  String get user => '使用者';

  @override
  String get leaveEmptyToKeepIt => '留空則保持不變。設定新密碼會讓其在其他地方登出。';

  @override
  String get needsAPassword => '需要設定密碼才能登入。';

  @override
  String get addUser => '新增使用者';

  @override
  String get needsAPassword2 => '需要密碼';

  @override
  String get noProfiles => '沒有設定檔';

  @override
  String get pad => '填補';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  $clips 個片段';
  }

  @override
  String get clipsFrom2 => '片段來源';

  @override
  String get channelsUsingItGo => '使用它的頻道會改回內建圖示。';

  @override
  String get uploading => '正在上傳…';

  @override
  String get noneOfYourShows => '你伺服器上的節目都沒有標誌圖片。';

  @override
  String get chooseAnIcon => '選擇圖示';

  @override
  String get couldntCopySelect => '無法複製。請選取文字後手動複製。';

  @override
  String copy(Object label) {
    return '複製$label';
  }

  @override
  String get home => '首頁';

  @override
  String get thereIsNoPage => '這裡沒有頁面。';

  @override
  String get enterPin => '輸入 PIN';

  @override
  String get thisIsA => '這是兒童設定檔。變更其設定需要成人的 PIN。';

  @override
  String hasAPin(Object name) {
    return '$name 設有 PIN。';
  }

  @override
  String get profile => '設定檔';

  @override
  String get changingAKid => '變更兒童設定檔的設定需要成人設定檔的 PIN。';

  @override
  String get aGrownUps => '成人的 PIN';

  @override
  String get thisProfile => '這個設定檔';

  @override
  String movies3(Object movies) {
    return '電影（$movies）';
  }

  @override
  String get shows3 => '節目';

  @override
  String remove4(Object label) {
    return '移除$label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · 伺服器上找不到';
  }

  @override
  String get dragACollection => '將合集、資料夾或電影拖曳到這裡，或使用它的「新增」按鈕。';

  @override
  String get collectionsAndFolders => '合集和資料夾';

  @override
  String add3(Object name) {
    return '新增 $name';
  }

  @override
  String added2(Object name) {
    return '已新增 $name';
  }

  @override
  String get dragToAdd => '拖曳以新增';

  @override
  String get languageAutomatic => '自動';

  @override
  String dateAtTime(String date, String time) {
    return '$date $time';
  }

  @override
  String connectingTo(Object server) {
    return '正在連線到 $server…';
  }

  @override
  String get yourServerLower => '你的伺服器';

  @override
  String noServerFoundAt(Object address) {
    return '在 $address 找不到 Jellyfin、Emby 或 Plex 伺服器。';
  }

  @override
  String captionsValue(Object name) {
    return '字幕：$name';
  }

  @override
  String channelOverrides(int count) {
    return '$count 個頻道有自己的設定（頻道和圖示）。';
  }

  @override
  String noShowLogosOn(Object kind) {
    return '你的 $kind 伺服器上的節目都沒有標誌圖片。';
  }

  @override
  String fileChosen(Object name) {
    return '檔案：$name';
  }

  @override
  String get theOneChosenBefore => '先前選擇的那個';

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
      other: '正在向 $viewers 位觀眾串流頻道 $channels。已使用 $running / $limit 路串流。',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name：匯出這個頻道列表';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name（兒童）：匯出這個頻道列表';
  }

  @override
  String encoderInUse(Object encoder) {
    return '正在使用的編碼器：$encoder';
  }

  @override
  String get checking => '正在檢查…';

  @override
  String countShows(int count) {
    return '$count 個節目';
  }

  @override
  String countEpisodes(int count) {
    return '$count 集';
  }

  @override
  String countMovies(int count) {
    return '$count 部電影';
  }

  @override
  String countSongs(int count) {
    return '$count 首歌曲';
  }

  @override
  String countMusicVideos(int count) {
    return '$count 個音樂影片';
  }

  @override
  String countHidden(int count) {
    return '$count 個已隱藏';
  }

  @override
  String countOnTheAir(int count) {
    return '$count 個播出中';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個節目時段',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name：$stats';
  }

  @override
  String get yourServerHasNothingNew =>
      '自上次重新整理以來，你的伺服器沒有新內容。伺服器掃描新檔案後，它們才會出現在這裡：如果你剛新增了檔案，請先在伺服器上掃描媒體庫，然後再重新整理。';

  @override
  String serverHasNothingNew(Object server) {
    return '自上次重新整理以來，$server 沒有新內容。伺服器掃描新檔案後，它們才會出現在這裡：如果你剛新增了檔案，請先在伺服器上掃描媒體庫，然後再重新整理。';
  }

  @override
  String get updateWatchStatusOnYourServer => '更新伺服器上的觀看狀態';

  @override
  String get updateWatchStatusOnYourServers => '更新各伺服器上的觀看狀態';

  @override
  String updateWatchStatusOn(Object name) {
    return '更新 $name 上的觀看狀態';
  }

  @override
  String get poolFoldersBumpers =>
      '這些資料夾（及其子資料夾）中的每部影片都會用於廣告時間的開頭和結尾，永遠不會當作節目播出。';

  @override
  String get poolFoldersCommercials =>
      '這些資料夾（及其子資料夾）中的每部影片都會用來填補廣告時間，永遠不會當作節目播出。';

  @override
  String get newPin => '新 PIN';

  @override
  String namedPin(Object name) {
    return '$name 的 PIN';
  }

  @override
  String get qualitySameAsProfile => '畫質：與設定檔相同';

  @override
  String qualityValue(Object limit) {
    return '畫質：$limit';
  }

  @override
  String onChannel(Object channel) {
    return '在 $channel';
  }

  @override
  String get aChannelThatIsGone => '已不存在的頻道';

  @override
  String liveFrom(Object source) {
    return '來自 $source 的直播';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return '標誌 $mode · 首播 $premieres';
  }

  @override
  String get offLower => '關閉';

  @override
  String streamingNow(Object count) {
    return '目前有 $count 路在串流。';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return '目前有 $count 路在串流 · 使用 $encoder 編碼。';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · $chosen / $channels 個頻道';
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
    return '來自 $when（$device）：$profiles。$channels 個頻道、$blocks 個節目時段、$logos 個標誌。';
  }

  @override
  String get backupSavedFirst => '系統會先備份這裡現有的內容。';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個新節目',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 集新集數',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部新電影',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首新歌曲',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return '播放$list。';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個新頻道',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => '幼兒';

  @override
  String get kidRatingYoungDescription => 'TV-Y 和 TV-Y7';

  @override
  String get kidRatingKids => '兒童';

  @override
  String get kidRatingKidsDescription => '最高 TV-G 和 G';

  @override
  String get kidRatingOlder => '大齡兒童';

  @override
  String get kidRatingOlderDescription => '最高 TV-PG 和 PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個設定檔',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個節目時段',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個時段',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '其資料夾中有 $count 部影片',
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
  String get liveLabel => '直播';

  @override
  String get aMidRollOpens =>
      '節目中的廣告時間以過場片段開始和結束，節目後的廣告時間以過場片段開始，節目前的廣告時間以過場片段結束。其餘時間由廣告填補。';

  @override
  String get programsPlayBack => '節目連續播放，沒有廣告時間。';

  @override
  String get everyShowFills => '每個節目都占滿半小時時段（較長的節目占一小時或更長），因此節目表始終依整點進行。';

  @override
  String get chooseHowLong => '選擇每次廣告時間的長度、節目中插播廣告的頻率，以及每次廣告時間從哪個素材組取片段。';

  @override
  String get copyAction => '複製';

  @override
  String get channelKidsZone => '兒童天地';

  @override
  String get channelToonTv => '卡通頻道';

  @override
  String get channelLaughTrack => '歡樂喜劇';

  @override
  String get channelFamilyRoom => '闔家歡';

  @override
  String get channelAdventureTv => '冒險頻道';

  @override
  String get channelSciFiFantasy => '科幻奇幻';

  @override
  String get channelMysteryTv => '懸疑頻道';

  @override
  String get channelDramaCentral => '戲劇館';

  @override
  String get channelCrimeJustice => '警匪犯罪';

  @override
  String get channelThrillTv => '驚悚頻道';

  @override
  String get channelFrightNight => '午夜驚魂';

  @override
  String get channelRomanceTv => '浪漫愛情';

  @override
  String get channelDiscoveryZone => '紀實天地';

  @override
  String get channelMusicTv => '音樂頻道';

  @override
  String get channelRealityTv => '真人實境';

  @override
  String get channelGameShowTv => '益智綜藝';

  @override
  String get channelFrontierTv => '西部片頻道';

  @override
  String get channelHistoryTv => '歷史頻道';

  @override
  String get channelSportsTv => '體育頻道';

  @override
  String get channelNewsTv => '新聞頻道';

  @override
  String get channelAllShows => '全部節目';

  @override
  String get channelMovieChannel => '電影頻道';

  @override
  String get channelMusicVideos => '音樂 MV';

  @override
  String get channelMusicRadio => '音樂電台';

  @override
  String get genreActionAdventure => '動作冒險';

  @override
  String get genreSciFiFantasy => '科幻奇幻';

  @override
  String get genreKids => '兒童';

  @override
  String get genreAnimation => '動畫';

  @override
  String get genreComedy => '喜劇';

  @override
  String get genreFamily => '家庭';

  @override
  String get genreDrama => '劇情';

  @override
  String get genreCrime => '犯罪';

  @override
  String get genreMystery => '懸疑';

  @override
  String get genreThriller => '驚悚';

  @override
  String get genreHorror => '恐怖';

  @override
  String get genreRomance => '愛情';

  @override
  String get genreDocumentary => '紀錄片';

  @override
  String get genreMusic => '音樂';

  @override
  String get genreReality => '實境';

  @override
  String get genreGameShows => '益智節目';

  @override
  String get genreWestern => '西部';

  @override
  String get genreWar => '戰爭';

  @override
  String get genreHistory => '歷史';

  @override
  String get genreNews => '新聞';

  @override
  String get genreTalk => '談話';

  @override
  String get genreSoap => '肥皂劇';

  @override
  String get genreSports => '體育';

  @override
  String get genreClassical => '古典';

  @override
  String get genreElectronic => '電子';

  @override
  String get genreCountry => '鄉村';

  @override
  String get genreLatin => '拉丁';

  @override
  String get genreSoundtrack => '原聲帶';

  @override
  String get genreOldies => '老歌';

  @override
  String get genreDance => '舞曲';

  @override
  String get genreFolk => '民謠';

  @override
  String get genreAlternative => '另類';

  @override
  String get blockDaytime => '白天時段';

  @override
  String get blockMovieNight => '電影之夜';

  @override
  String get blockNewEpisodes => '新集數';

  @override
  String get kindShow => '節目';

  @override
  String get kindShows => '節目';

  @override
  String get kindMovies => '電影';

  @override
  String get kindMusicVideos => '音樂影片';

  @override
  String get kindRadio => '電台';

  @override
  String genreMovies(Object genre) {
    return '$genre電影';
  }

  @override
  String genreMusicVideos(Object genre) {
    return '$genre音樂影片';
  }

  @override
  String genreRadio(Object genre) {
    return '$genre電台';
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
  String get lateNightTitle => '深夜時段';

  @override
  String get languageTitle => '語言';

  @override
  String get stillWatchingOff => '關閉';

  @override
  String afterHours(int hours) {
    return '$hours 小時後';
  }

  @override
  String get bitrateOriginal => '原始（無限制）';

  @override
  String get bitrate40 => '40 Mbps · 4K';

  @override
  String get bitrate20 => '20 Mbps · 1080p 高';

  @override
  String get bitrate12 => '12 Mbps · 1080p';

  @override
  String get bitrate8 => '8 Mbps · 1080p';

  @override
  String get bitrate4 => '4 Mbps · 720p';

  @override
  String get noSuchLanguage => '沒有這種語言。';

  @override
  String get languageField => '語言';

  @override
  String get remotePageTitle => 'Nightingale TV 遙控器';

  @override
  String get remotePairTitle => '與電視配對';

  @override
  String get remotePairHelp => '掃描電視上的 QR 碼（選單 → 手機遙控器），或輸入那裡顯示的 6 位數代碼。';

  @override
  String get remotePairingCode => '配對代碼';

  @override
  String get remotePair => '配對';

  @override
  String get remoteConnecting => '正在連線…';

  @override
  String get remoteTabRemote => '遙控器';

  @override
  String get remoteUp => '上';

  @override
  String get remoteLeft => '左';

  @override
  String get remoteRight => '右';

  @override
  String get remoteDown => '下';

  @override
  String get remoteInfo => '資訊';

  @override
  String get remoteLastCh => '上個頻道';

  @override
  String get remoteCc => '字幕';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => '確定';

  @override
  String get remoteRemovedFromTv => '這支手機已從電視中移除。請掃描 QR 碼重新配對。';

  @override
  String get remoteCouldntPair => '無法配對。請再試一次。';

  @override
  String get remoteCantReachWifi => '無法連線到電視。這支手機連線的是同一個 Wi-Fi 嗎？';

  @override
  String get remoteEnterDigits => '請輸入電視上顯示的 6 位數字。';

  @override
  String get remoteCantReachTv => '無法連線到電視';

  @override
  String get remotePickProfile => '請用方向鍵和 OK 選擇設定檔。';

  @override
  String remoteWatching(Object name) {
    return '正在觀看：$name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name（兒童）';
  }

  @override
  String get transferPageTitle => 'Nightingale TV 備份';

  @override
  String get transferIntro => '在這部電視和這部裝置之間傳送備份。傳送期間請保持電視上的對話框開啟。';

  @override
  String get transferDownload => '下載備份';

  @override
  String get transferDownloadHelp => '電視目前設定的備份：設定檔、頻道、節目時段和設定。';

  @override
  String get transferRestoreTitle => '從檔案還原';

  @override
  String transferRestoreHelp(Object file) {
    return '傳送一個 $file 檔案到電視。在電視上確認之前不會有任何變更。';
  }

  @override
  String get transferChoose => '選擇備份檔案…';

  @override
  String get transferFoot => '只有家用網路中的裝置才能開啟這個頁面。';

  @override
  String transferSending(Object name) {
    return '正在傳送 $name…';
  }

  @override
  String get transferCheckTv => '請在電視上完成操作。';

  @override
  String get transferClosed => '電視已關閉這個頁面。請從「備份與還原」中重新開啟。';

  @override
  String get transferCouldntTake => '電視無法接收這個檔案。';

  @override
  String get transferCouldntReach => '無法連線到電視。電視上還顯示著 QR 碼嗎？';

  @override
  String get includeShows => '包含節目';

  @override
  String get everyShow2 => '所有節目';

  @override
  String get decades => '年代';

  @override
  String get decadesHeading => '年代';

  @override
  String decadeYears(Object decade) {
    return '$decade年代';
  }

  @override
  String get channelActionTv => '動作頻道';

  @override
  String get channelSciFiTv => '科幻頻道';

  @override
  String get channelFantasyTv => '奇幻頻道';

  @override
  String get channelMysteryThrills => '懸疑驚悚';

  @override
  String get genreAction => '動作';

  @override
  String get genreAdventure => '冒險';

  @override
  String get genreSciFi => '科幻';

  @override
  String get genreFantasy => '奇幻';

  @override
  String get genreThrillerMystery => '驚悚懸疑';

  @override
  String decadeTv(Object decade) {
    return '$decade節目';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$decade$genre節目';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return '$decade$genre電影';
  }

  @override
  String get errorReports => '錯誤報告';

  @override
  String get sendErrorReportsFrom => '從這部裝置傳送錯誤報告';

  @override
  String get errorReportsExplain =>
      '發生問題時，Nightingale TV 會傳送一份簡短報告給開發者：錯誤資訊、應用程式版本、裝置類型，以及最近的幾個畫面和頻道號碼。伺服器位址、密碼和金鑰、名稱和檔案路徑會在傳送前移除。節目標題和你觀看的內容永遠不會傳送。';

  @override
  String get errorReportsOff => '關閉後，這部裝置不會傳送任何內容；等待傳送的報告會被刪除。';

  @override
  String get recentReports => '最近的報告';

  @override
  String get reportKindTest => '測試';

  @override
  String get reportKindVideo => '影片報告';

  @override
  String get reportKindError => '錯誤';

  @override
  String get reportKindExit => '意外結束';

  @override
  String get reportKindSlowStart => '啟動緩慢';

  @override
  String get errorReportsAutomatic =>
      '應用程式意外結束或啟動緩慢時，也會自動傳送一份報告，包含之前的畫面、頻道、啟動步驟和記憶體數據。';

  @override
  String get sendATestReport => '傳送測試報告';

  @override
  String lastReportId(String id) {
    return '最近一次報告 ID：$id';
  }

  @override
  String get noReportSentYet => '這部裝置還沒有傳送過報告。';

  @override
  String get quoteReportId => '向開發者回報問題時，請提供這個 ID。';

  @override
  String testReportSent(String id) {
    return '測試報告已傳送：$id';
  }

  @override
  String get testReportNotSent => '無法傳送測試報告。請稍後再試。';

  @override
  String get reportsNotInBuild =>
      '這個版本的 Nightingale TV 不包含錯誤報告功能，因此永遠不會傳送任何內容。';

  @override
  String get sendAVideoReport => '傳送影片報告';

  @override
  String get videoReportHelp =>
      '如果畫面看起來不對，請按這裡，然後返回某個頻道。畫面播放 10 秒後會傳送報告，報告 ID 會顯示在電視螢幕上。';

  @override
  String get videoReportArmed => '現在請返回某個頻道。畫面播放 10 秒後會傳送影片報告。';

  @override
  String get videoReportTooSoon => '不到一分鐘前剛傳送過影片報告。請稍後再試。';

  @override
  String videoReportSent(String id) {
    return '影片報告已傳送：$id';
  }

  @override
  String get videoReportsExplain =>
      '影片報告會傳送有關裝置、影片及其解碼器的資訊、畫面的粗略顏色格線以及應用程式本身最近的記錄；絕不會傳送你所觀看內容的影像。每次應用程式更新後，頻道播放 10 秒時會傳送一次。';

  @override
  String get unlockNightingaleTv => '解鎖 Nightingale TV';

  @override
  String trialDaysLeftMenu(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '免費試用還剩 $count 天',
    );
    return '$_temp0';
  }

  @override
  String get purchasePending => '購買處理中';

  @override
  String get freeForDaysTitle => '免費 14 天';

  @override
  String welcomeTrialPrice(String price) {
    return 'Nightingale TV 可免費使用 14 天。之後，一次支付 $price 即可永久解鎖，並支持這個專案。';
  }

  @override
  String get welcomeTrial => 'Nightingale TV 可免費使用 14 天。之後，一次購買即可永久解鎖，並支持這個專案。';

  @override
  String get unlockNow => '立即解鎖';

  @override
  String get startMyFreeTrial => '開始免費試用';

  @override
  String get lastDayOfTrial => '今天是免費試用的最後一天';

  @override
  String reminderPrice(String price) {
    return '免費試用結束後，一次支付 $price 即可永久解鎖 Nightingale TV，並支持這個專案。';
  }

  @override
  String get reminder => '免費試用結束後，一次購買即可永久解鎖 Nightingale TV，並支持這個專案。';

  @override
  String get freeTrialEnded => '你的免費試用已結束';

  @override
  String get unlockScreenText =>
      '一次購買即可永久解鎖 Nightingale TV，並支持這個專案。你的設定檔、頻道和設定都還在。';

  @override
  String unlockForPrice(String price) {
    return '以 $price 解鎖';
  }

  @override
  String get unlock => '解鎖';

  @override
  String get checkMyPurchaseAgain => '重新檢查我的購買';

  @override
  String get redeemPlayCode => '兌換 Play 代碼';

  @override
  String get redeemCodeTitle => '兌換代碼';

  @override
  String get redeemCodeText =>
      '請在手機或電腦上登入這部裝置使用的 Google 帳戶，然後前往 play.google.com/redeem 兌換代碼。之後選擇「重新檢查我的購買」。';

  @override
  String get noPurchaseFound => '找不到購買記錄';

  @override
  String get noPurchaseFoundText =>
      '這部裝置上的 Google 帳戶沒有 Nightingale TV 的購買記錄。如果你剛剛購買，請稍後再試。';

  @override
  String get purchaseNotCompleted => '購買未完成';

  @override
  String get purchaseNotCompletedText => '無法完成購買。沒有任何變更；請稍後再試。';

  @override
  String get purchasePendingText =>
      '你的購買正在等待完成。在此期間 Nightingale TV 可以正常使用，完成後會自動解鎖。';

  @override
  String get unlockedThankYou => '已解鎖。感謝你支持 Nightingale TV。';

  @override
  String freeTrialDaysLeftAbout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '免費試用：還剩 $count 天',
    );
    return '$_temp0';
  }

  @override
  String couldntReadChannels(Object name) {
    return '無法讀取 $name 的頻道清單';
  }

  @override
  String channelNoLongerOn(Object server) {
    return '這個頻道已不在 $server 上';
  }

  @override
  String channelsNoLongerOnServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道已不在伺服器上',
    );
    return '$_temp0';
  }

  @override
  String get sharing => '分享';

  @override
  String get sharingIntroTitle => '新增也在用 Nightingale TV 的好友';

  @override
  String get sharingIntroWhat =>
      '透過分享，你可以新增同樣使用 Nightingale TV 的好友。每個 Nightingale 設定檔都有自己的分享帳戶。';

  @override
  String get sharingIntroStored => '儲存的內容：你的電子郵件、你的分享個人資料、你的好友，以及日後你分享和觀看的內容。';

  @override
  String get sharingIntroNoVideo => '使用者之間永遠不會傳送任何影片。';

  @override
  String get sharingSetUp => '設定';

  @override
  String get sharingEmailPrompt => '請輸入你的電子郵件。我們會傳送一組 6 位數代碼供你登入。';

  @override
  String get sharingEmailLabel => '電子郵件';

  @override
  String get sharingSendCode => '傳送代碼';

  @override
  String get sharingNotAnEmail => '請輸入電子郵件地址，例如 name@example.com。';

  @override
  String sharingCodeSent(Object email) {
    return '我們已傳送一組 6 位數代碼到 $email。請在這裡輸入。';
  }

  @override
  String get sharingCodeLabel => '6 位數代碼';

  @override
  String get sharingWrongCode => '代碼不正確';

  @override
  String get sharingTooManyWrong => '代碼錯誤次數過多。請傳送新的代碼。';

  @override
  String get sharingSendNewCode => '傳送新代碼';

  @override
  String sharingSendNewCodeIn(Object seconds) {
    return '傳送新代碼（$seconds 秒）';
  }

  @override
  String get sharingOtherEmail => '使用其他電子郵件';

  @override
  String get sharingUnavailable => '分享功能暫時無法使用。請稍後再試。';

  @override
  String get sharingProfileTitle => '你的分享個人資料';

  @override
  String get sharingProfileIntro => '好友會看到這些內容。你的電子郵件永遠不會顯示。';

  @override
  String get sharingNameLabel => '顯示名稱';

  @override
  String get sharingHandleLabel => '帳號名稱';

  @override
  String get sharingHandleRules => '請使用 3–20 個字母、數字或 _。';

  @override
  String get sharingHandleTaken => '這個帳號名稱已被使用。';

  @override
  String get sharingNameRequired => '請輸入顯示名稱。';

  @override
  String get sharingAvatar => '大頭貼';

  @override
  String get sharingStationLabel => '電視台名稱（選填）';

  @override
  String get sharingAddFriend => '新增好友';

  @override
  String get sharingCodeHelp =>
      '好友在 Nightingale TV 的「分享」→「新增好友」中輸入這個代碼，或開啟連結。代碼只能使用一次，7 天後過期。';

  @override
  String get sharingNewCode => '新代碼';

  @override
  String get sharingSendInvite => '傳送邀請';

  @override
  String get sharingEnterCode => '輸入代碼';

  @override
  String sharingInviteText(Object link) {
    return '在 Nightingale TV 上加我為好友：$link';
  }

  @override
  String get sharingFriends => '好友';

  @override
  String get sharingNoFriends => '還沒有好友。分享你的代碼來新增好友。';

  @override
  String get sharingBlocked => '已封鎖';

  @override
  String get sharingRemoveFriend => '移除好友';

  @override
  String sharingRemoveFriendConfirm(Object name) {
    return '要移除好友 $name 嗎？你們將不再是好友。';
  }

  @override
  String get sharingBlock => '封鎖';

  @override
  String sharingBlockConfirm(Object name) {
    return '要封鎖 $name 嗎？這會將對方從好友中移除，對方也無法使用你的代碼。';
  }

  @override
  String get sharingUnblock => '解除封鎖';

  @override
  String sharingUnblockConfirm(Object name) {
    return '要解除封鎖 $name 嗎？對方可以用新代碼再次新增你。';
  }

  @override
  String get sharingSignOutConfirm =>
      '要在這個設定檔上登出分享嗎？你的分享帳戶和好友會保留。用你的電子郵件即可重新登入。';

  @override
  String get sharingDeleteAccount => '刪除分享帳戶';

  @override
  String sharingDeleteConfirm(Object handle) {
    return '這會刪除你的分享帳戶、分享個人資料（@$handle）、好友、邀請以及為其儲存的所有內容，並在所有裝置上登出。此動作無法復原。';
  }

  @override
  String get sharingDeleted => '你的分享帳戶已刪除。';

  @override
  String get sharingCodeFieldLabel => '好友的代碼';

  @override
  String get sharingNotACode => '代碼由 6 個字母和數字組成，例如 AB3K·9Q。';

  @override
  String sharingAddFriendQuestion(Object name, Object handle) {
    return '要新增 $name（@$handle）為好友嗎？';
  }

  @override
  String get sharingOwnCode => '這是你自己的代碼';

  @override
  String get sharingInviteGone => '這個邀請已過期或已使用過';

  @override
  String get sharingTooManyTries => '嘗試次數過多。請稍後再試';

  @override
  String sharingNowFriends(Object name) {
    return '你和 $name 現在是好友了。';
  }

  @override
  String get sharingSwitchToAdult => '請切換到成人設定檔來新增好友。';

  @override
  String get sharingEditProfile => '編輯';

  @override
  String sharingStation(Object station) {
    return '電視台：$station';
  }

  @override
  String get sharingLiveCantShare => '直播頻道透過你自己的調諧器播放，無法分享';

  @override
  String get sharingMusicCantShare => '音樂頻道無法分享';

  @override
  String get sharingCopyCantShare => '別人分享給你的頻道無法再次分享';

  @override
  String get sharingTooBig => '超過 20,000 個節目的頻道無法分享';

  @override
  String get sharingNoneMatch => '這些節目都不在你的伺服器上';

  @override
  String get sharingUpdateApp => '請更新 Nightingale TV 以新增這個頻道。';

  @override
  String sharingStopsFollowing(Object name) {
    return '這個頻道將不再跟隨 $name 的變更。';
  }

  @override
  String sharingNewShares(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道',
    );
    return '$name 與你分享了 $_temp0。開啟「選單」→「分享」即可新增。';
  }

  @override
  String sharingNewSharesMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道',
    );
    return '有 $_temp0分享給你。開啟「選單」→「分享」即可新增。';
  }

  @override
  String get sharingSharedWithYou => '分享給你的';

  @override
  String get sharingNothingShared => '沒有待處理的內容。好友分享給你的頻道會顯示在這裡。';

  @override
  String sharingMatched(Object matched, Object total) {
    return '已比對到 $matched / $total 個節目';
  }

  @override
  String sharingAddedAs(Object number) {
    return '已新增為頻道 $number';
  }

  @override
  String get sharingDecline => '拒絕';

  @override
  String get sharingShareChannels => '分享頻道';

  @override
  String get sharingShareChannelsHelp =>
      '好友會收到每個頻道的描述，他們的應用程式會用自己的伺服器重建頻道。不會傳送任何影片。';

  @override
  String get sharingChannelsYouShare => '你分享的頻道';

  @override
  String get sharingNoChannelsShared => '你沒有分享任何頻道。';

  @override
  String get sharingStopSharing => '停止分享';

  @override
  String sharingStopSharingConfirm(Object name) {
    return '要停止分享 $name 嗎？好友會保留他們的副本，但不會再收到你的變更。';
  }

  @override
  String sharingWith(Object names) {
    return '分享給 $names';
  }

  @override
  String get sharingShareWith => '分享給';

  @override
  String get sharingShare => '分享';

  @override
  String get sharingGetLink => '取得連結';

  @override
  String sharingSharedWith(Object names) {
    return '已分享給 $names';
  }

  @override
  String get sharingLinkHelp => '7 天內使用這個代碼的人會成為你的好友，並取得這些頻道。代碼只能使用一次。';

  @override
  String sharingChannelsInviteText(Object link) {
    return '這是我在 Nightingale TV 上的一些頻道：$link';
  }

  @override
  String get sharingPickChannel => '請至少選擇一個頻道。';

  @override
  String get sharingPickFriend => '請至少選擇一位好友，或使用「取得連結」。';

  @override
  String get sharingNoFriendsToShare => '還沒有好友。取得連結即可與新朋友分享。';

  @override
  String get sharingShareEllipsis => '分享…';

  @override
  String sharingSharedBy(Object name, Object handle) {
    return '由 $name（@$handle）分享';
  }

  @override
  String get sharingKeepUpdated => '保持更新';

  @override
  String sharingKeepUpdatedHelp(Object name) {
    return '跟隨 $name 對這個頻道的變更';
  }

  @override
  String get sharingNoLongerUpdated => '不再更新';

  @override
  String sharingChannelsOffer(Object name, Object handle, Object names) {
    return '$name（@$handle）與你分享了這些頻道：$names。要新增 $name 為好友並取得這些頻道嗎？';
  }

  @override
  String sharingNowFriendsChannels(Object name) {
    return '你和 $name 現在是好友了。對方的頻道正在「分享給你的」中等待。';
  }

  @override
  String get sharedTab => '分享';

  @override
  String get sharedTabRule => '你從好友的分享中新增的頻道';

  @override
  String get presenceSetting => '顯示我正在觀看的內容';

  @override
  String presenceSettingValue(Object value) {
    return '顯示我正在觀看的內容：$value';
  }

  @override
  String get presenceQuestion => '要讓好友看到你正在觀看什麼嗎？';

  @override
  String get presenceExplain =>
      '你觀看時，好友會看到節目或電影以及頻道。不會顯示其他任何內容，你停止觀看後也不會顯示。在播放器按鈕中選擇「私密觀看」可在關閉應用程式前隱藏這些資訊。你可以隨時在「分享」中變更這項設定。';

  @override
  String presenceWatchingOn(Object title, Object channel) {
    return '正在 $channel 觀看《$title》';
  }

  @override
  String presenceWatchingChannel(Object channel) {
    return '正在觀看 $channel';
  }

  @override
  String presenceIsWatching(Object name) {
    return '$name 正在觀看';
  }

  @override
  String presenceAndOthersWatching(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友',
    );
    return '$name 和另外 $_temp0正在觀看';
  }

  @override
  String presenceWatchingToo(Object name) {
    return '$name 也在觀看';
  }

  @override
  String presenceAndOthersWatchingToo(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友',
    );
    return '$name 和另外 $_temp0也在觀看';
  }

  @override
  String presenceNoticeOne(Object name) {
    return '$name 正在觀看';
  }

  @override
  String presenceNoticeMany(Object names) {
    return '$names 正在觀看';
  }

  @override
  String get watchPrivately => '私密觀看';

  @override
  String get watchingPrivately => '正在私密觀看';

  @override
  String get watchTogether => '一起看';

  @override
  String partyStartTitle(Object title) {
    return '一起看《$title》';
  }

  @override
  String get partyStartHelp => '每個人都從自己的伺服器同步播放。最多選擇 7 位好友，或取得連結。';

  @override
  String get partyNoFriends => '還沒有好友：取得連結來邀請別人。';

  @override
  String get partyGetLink => '取得連結';

  @override
  String get partyStart => '開始';

  @override
  String get partyLinkHelp => '開啟這個連結的任何人都會成為你的好友，並可以加入。';

  @override
  String partyInviteBanner(Object name, Object title) {
    return '$name 邀請你一起看《$title》';
  }

  @override
  String partyInviteBannerNoTitle(Object name) {
    return '$name 邀請你一起看';
  }

  @override
  String get partyJoin => '加入';

  @override
  String get partyNotNow => '稍後再說';

  @override
  String partyJoinQuestion(Object name) {
    return '要加入 $name 的觀影派對嗎？';
  }

  @override
  String partyOn(Object title, Object channel) {
    return '$channel 上的《$title》';
  }

  @override
  String get partyInSync => '已同步';

  @override
  String get partyCatchingUp => '正在追上進度';

  @override
  String get partyNotOnServers => '不在你的伺服器上';

  @override
  String partyMissingTitle(Object title) {
    return '不在你的伺服器上：$title';
  }

  @override
  String get partyMissingRejoin => '你會在下一個節目時重新加入。';

  @override
  String get partyInvite => '邀請';

  @override
  String get partyLeave => '離開';

  @override
  String get partyStay => '留下';

  @override
  String get partyLeaveQuestion => '要離開觀影派對嗎？';

  @override
  String get partyLeaveHostDetail => '你是主持人，因此派對會為所有人結束。';

  @override
  String get partyLeaveGuestDetail => '你會回到自己的頻道。';

  @override
  String get partyHost => '主持人';

  @override
  String partyJoined(Object name) {
    return '$name 已加入';
  }

  @override
  String partyLeft(Object name) {
    return '$name 已離開';
  }

  @override
  String partyPaused(Object name) {
    return '$name 已暫停';
  }

  @override
  String partyResumed(Object name) {
    return '$name 已繼續播放';
  }

  @override
  String partySkipped(Object name) {
    return '$name 已跳過';
  }

  @override
  String partyRestarted(Object name) {
    return '$name 已從頭播放節目';
  }

  @override
  String partyWentLive(Object name) {
    return '$name 已返回直播';
  }

  @override
  String partyEnded(Object name) {
    return '$name 結束了觀影派對';
  }

  @override
  String get partyLost => '與觀影派對的連線已中斷';

  @override
  String get partyFull => '這個觀影派對已滿';

  @override
  String get partyOver => '這個觀影派對已結束';

  @override
  String get partyWatchParties => '觀影派對';

  @override
  String get partyNoInvites => '目前沒有觀影派對邀請。';

  @override
  String partyChannelName(Object channel) {
    return '觀影派對 · $channel';
  }

  @override
  String get partyReactions => '互動表情';

  @override
  String partyInvited(Object names) {
    return '已邀請 $names';
  }

  @override
  String get smbGuestsRefused => '這台電腦不允許訪客登入。請輸入使用者名稱和密碼。';

  @override
  String get smbNoAccess => '無法存取';

  @override
  String smbShareGone(String name) {
    return '$name 已不存在。';
  }

  @override
  String smbReadingFiles(String name) {
    return '正在讀取 $name 上的檔案…';
  }

  @override
  String smbScanningFolders(String name, int count) {
    return '正在掃描 $name：$count 個資料夾…';
  }

  @override
  String smbShareOnHost(String share, String host) {
    return '$host 上的 $share';
  }

  @override
  String get smbNotAnAddress =>
      '這不是共用資料夾的位址。請以 smb://電腦/共用名稱 或 \\\\電腦\\共用名稱 的格式輸入。';

  @override
  String smbCantReach(String host) {
    return '無法連線到 $host。';
  }

  @override
  String smbAnotherShare(String name) {
    return '這不是 $name，而是另一個共用資料夾。';
  }

  @override
  String get smbMapOne => '請至少為一個資料夾選擇內容類型。';

  @override
  String get smbShareButton => 'SMB 共用資料夾';

  @override
  String get smbFindTitle => '新增共用資料夾';

  @override
  String get smbFindHelp => '選擇一台電腦或 NAS，或輸入共用資料夾的位址。';

  @override
  String get smbAddress => '共用資料夾位址';

  @override
  String get smbSearching => '正在尋找電腦…';

  @override
  String get smbSearchAgain => '重新尋找';

  @override
  String get smbNoneFound => '找不到電腦。請輸入共用資料夾的位址。';

  @override
  String smbSharesOn(String host) {
    return '$host 上的共用資料夾';
  }

  @override
  String smbNoShares(String host) {
    return '$host 上沒有你能開啟的共用資料夾。';
  }

  @override
  String get smbOld => 'SMB1：舊協定，未加密';

  @override
  String smbSignInTo(String host) {
    return '登入 $host';
  }

  @override
  String get smbDomain => '網域（選填）';

  @override
  String get smbAsGuest => '以訪客身分連線';

  @override
  String smbWhatsIn(String share) {
    return '$share 裡有什麼？';
  }

  @override
  String get smbMapHelp =>
      '為每個資料夾選擇內容類型。保留為「無」的資料夾會被忽略；已選擇的資料夾中的子資料夾可以另外選擇。在資料夾名稱上按 OK 可開啟它。';

  @override
  String get smbTypeNone => '無';

  @override
  String get smbTypeTv => '電視節目';

  @override
  String get smbTypeMovies => '電影';

  @override
  String get smbTypeMusic => '音樂';

  @override
  String get smbTypeMusicVideos => '音樂影片';

  @override
  String get smbTypeHome => '家庭影片';

  @override
  String get smbTypeCommercials => '廣告';

  @override
  String get smbTypeBumpers => '過場片段';

  @override
  String smbAsAbove(String type) {
    return '$type（同上）';
  }

  @override
  String get smbUp => '上一層資料夾';

  @override
  String get smbHistoryName => '記錄名稱';

  @override
  String get smbHistoryHelp =>
      '使用相同記錄名稱的電視會共用播放次數和續播位置。它們儲存在共用資料夾中的隱藏資料夾 .nightingale 裡，其他內容不會被更改。';

  @override
  String get smbKeepLocal => '在此裝置上保存記錄';

  @override
  String get smbReadOnly => '此共用資料夾為唯讀：記錄保存在此裝置上。';

  @override
  String get smbFoldersDone => '完成';

  @override
  String smbFilesLeft(int count) {
    return '正在讀取 $count 個檔案';
  }

  @override
  String smbHistoryOnShare(String name) {
    return '記錄：在共用資料夾上，名稱為「$name」';
  }

  @override
  String get smbHistoryOnDevice => '記錄：在此裝置上';

  @override
  String get smbHistoryReadOnly => '記錄：在此裝置上（共用資料夾為唯讀）';

  @override
  String get smbFolders => '資料夾';

  @override
  String smbCantPlay(int count) {
    return '無法播放（$count）';
  }

  @override
  String smbCantPlayTitle(String name) {
    return '無法播放 · $name';
  }

  @override
  String get smbCantPlayHelp =>
      '這些檔案不會排入節目。修好檔案或配對一台能轉換的 Nightingale TV 後，請重新檢查。';

  @override
  String get smbCheckAgain => '重新檢查';

  @override
  String get smbCantPlayNone => '所有檔案都能播放。';

  @override
  String get smbReasonDamaged => '已損壞';

  @override
  String get smbReasonNoVideo => '沒有畫面';

  @override
  String get smbReasonTooMuch => '超出此裝置的能力，也沒有其他 Nightingale TV 可以轉換';

  @override
  String smbRenameTitle(String name) {
    return '重新命名 $name';
  }

  @override
  String smbFoldersTitle(String name) {
    return '資料夾 · $name';
  }

  @override
  String get smbSave => '儲存';

  @override
  String get smbQualityNote =>
      '共用資料夾中的檔案由已配對的另一台 Nightingale TV 轉換以適應網路；沒有的話會按原樣播放，因為在此裝置上轉換並不能減輕網路負擔。';

  @override
  String get smbHomeCantShare => '家庭影片無法分享';

  @override
  String get smbHomeVideo => '家庭影片';

  @override
  String get licencesTitle => '授權條款';

  @override
  String get licencesHelp =>
      'Nightingale TV 是採用 GNU GPL 3 的自由軟體。它使用以下軟體，每個軟體都依循各自的授權條款。';

  @override
  String get colorPurple => '紫色';

  @override
  String get colorGreen => '綠色';

  @override
  String get colorAmber => '琥珀色';

  @override
  String get colorTeal => '藍綠色';

  @override
  String get colorMagenta => '洋紅色';

  @override
  String get colorOlive => '橄欖色';

  @override
  String get colorSlate => '石板灰';

  @override
  String get colorCocoa => '可可色';

  @override
  String get colorWine => '酒紅色';

  @override
  String get guideColor => '節目表中的顏色';

  @override
  String guideColorTitle(String name) {
    return '節目表中的顏色 · $name';
  }

  @override
  String get guideColorHelp => '來自此伺服器的節目在節目表中顯示為此顏色。';

  @override
  String guideColorUsedBy(String color, String name) {
    return '$color · $name';
  }

  @override
  String get serverColorsSetting => '節目表中的伺服器顏色';

  @override
  String get serverColorsHelp => '每個節目顯示為其播放來源伺服器的顏色，節目表下方有圖例。';

  @override
  String playsFrom(String name) {
    return '來自 $name';
  }

  @override
  String get convertForOthers => '為其他電視轉換';

  @override
  String get convertForOthersHelp =>
      '無法播放共用資料夾中某個檔案的電視會請這台電腦轉換。這台電腦的某個設定檔中需要有相同的共用資料夾，而且只轉換其已指定資料夾中的檔案。';

  @override
  String convertCode(String code) {
    return '配對碼：$code';
  }

  @override
  String get convertPairedTvs => '已配對的電視';

  @override
  String get convertNoTvs => '還沒有配對的電視。';

  @override
  String get convertHelpers => '在其他 Nightingale TV 上轉換';

  @override
  String get convertHelpersHelp =>
      '電腦上的 Nightingale TV 或 Docker 伺服器可以轉換此裝置無法播放、或無法夠快播放的共用資料夾檔案。在那邊開啟「為其他電視轉換」，然後用顯示的代碼配對。';

  @override
  String get convertFind => '在網路中尋找';

  @override
  String get convertTypeAddress => '輸入位址';

  @override
  String get convertAddress => 'Nightingale TV 的位址';

  @override
  String convertEnterCode(String name) {
    return '$name 上顯示的代碼';
  }

  @override
  String convertWrongCode(String name) {
    return '代碼不對，或 $name 沒有回應。';
  }

  @override
  String get convertNoneFound =>
      '找不到可轉換的 Nightingale TV。請確認那邊已開啟「為其他電視轉換」，或輸入位址。';

  @override
  String convertAddShareOn(String share, String name) {
    return '在 $name 上新增 $share';
  }

  @override
  String convertNotAnswering(String name) {
    return '$name 沒有回應';
  }

  @override
  String get convertPair => '配對';

  @override
  String get serverKindsHelp =>
      '你可以新增 Jellyfin、Emby、Plex、YouTube 和 SMB 共用資料夾（NAS 或電腦上的共用資料夾）。';

  @override
  String get youTube => 'YouTube';

  @override
  String get youTubeTerms => '登入即表示你同意 YouTube 服務條款和 Nightingale TV 隱私權政策。';

  @override
  String get youTubeTermsOfService => 'YouTube 服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String youTubeEnterCode(String address) {
    return '在手機或電腦上前往 $address，輸入這組代碼。';
  }

  @override
  String get openGoogleDevice => '開啟 google.com/device';

  @override
  String get signInWasCancelled => '登入已取消';

  @override
  String get youTubeChannelsTitle => 'YouTube 頻道';

  @override
  String youTubePickedOf(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get notSubscribed => '未訂閱';

  @override
  String get searchSubscriptions => '搜尋你的訂閱內容';

  @override
  String get noSubscriptions => '這個帳戶沒有訂閱內容';

  @override
  String get noSubscriptionsMatch => '沒有相符的訂閱內容';

  @override
  String removeYouTubeChannels(String names) {
    return '要從節目表中移除 $names 嗎？';
  }

  @override
  String youTubeChannelCount(int count) {
    return '$count 個頻道';
  }

  @override
  String get googleClient => 'Google 用戶端';

  @override
  String get googleClientShared => 'Nightingale TV 的';

  @override
  String get googleClientOwn => '你自己的';

  @override
  String youTubeDailyLimit(String time) {
    return '已達到 YouTube 的每日上限。新影片會在 $time 之後送達。';
  }

  @override
  String get useMyOwnClient => '使用我自己的用戶端';

  @override
  String get signInToYouTubeAgain => '請重新登入 YouTube';

  @override
  String get ownClientTitle => '你自己的 Google 用戶端';

  @override
  String get clientId => '用戶端 ID';

  @override
  String get clientSecret => '用戶端密鑰';

  @override
  String get openClientFile => '開啟檔案';

  @override
  String get clientFileNotRead => '這個檔案不是 Google 用戶端檔案';

  @override
  String get useThisClient => '使用這個用戶端';

  @override
  String get useSharedClient => '使用 Nightingale TV 的用戶端';

  @override
  String get ownClientStep1 => '開啟 console.cloud.google.com 並建立專案。';

  @override
  String get ownClientStep2 => '啟用 YouTube Data API v3。';

  @override
  String get ownClientStep3 => '設定 OAuth 同意畫面，並加入 youtube.readonly 範圍。';

  @override
  String get ownClientStep4 => '將發布狀態設為「正式版」。';

  @override
  String get ownClientStep5 => '建立類型為「電視和輸入受限的裝置」的 OAuth 用戶端。';

  @override
  String get ownClientStep6 => '在這裡輸入用戶端 ID 和密鑰，或開啟下載的檔案。';

  @override
  String ownClientGuide(String address) {
    return '完整指南：$address';
  }

  @override
  String get clientRefused => 'Google 不接受這個用戶端。類型必須是「電視和輸入受限的裝置」。';

  @override
  String get noVideosYet => '還沒有影片';

  @override
  String get youTubeRefusedPlayer => 'YouTube 不接受這個播放器';

  @override
  String get youTubeNeedsWebView => 'YouTube 需要 Android System WebView';

  @override
  String getItFromPlayStore(String address) {
    return '從 Play 商店取得：$address';
  }

  @override
  String youTubeChannelSource(String title) {
    return 'YouTube 頻道：$title';
  }

  @override
  String publishedOn(String date) {
    return '發布於 $date';
  }

  @override
  String get youTubeCantBeShared => '無法分享 YouTube 頻道';

  @override
  String get youTubeAlreadyRemovedQuota => '請在 YouTube 每日上限重設後再試一次。';

  @override
  String get youTubeAccount => 'YouTube 帳戶';

  @override
  String get couldNotReachGoogle => '無法連線到 Google，請再試一次。';

  @override
  String get youTubeDailyLimitShort => '已達到 YouTube 的每日上限。';

  @override
  String get youTubeNoBreaks => 'YouTube 頻道沒有廣告時間。';

  @override
  String get youTubeNoBlocks => 'YouTube 頻道不能有節目時段。';

  @override
  String get youTubeAccessNeeded =>
      'Nightingale TV 需要查看你的 YouTube 訂閱內容。請輸入新的代碼並允許。';

  @override
  String get youTubeRemoveBody =>
      '它的頻道會從頻道列表中移除，Nightingale TV 對你 YouTube 帳號的存取也會結束。';

  @override
  String get playerQuality => '畫質';

  @override
  String playerQualityValue(String value) {
    return '畫質：$value';
  }

  @override
  String get playerQualityAuto => '自動';

  @override
  String get playerQualityOriginal => '原畫';

  @override
  String playerQualityMbps(int mbps) {
    return '$mbps Mbps';
  }

  @override
  String get youTubeNoClient => '這個版本沒有 YouTube 用戶端。README 中說明了如何新增。';

  @override
  String youTubeSharedLimit(int limit) {
    return 'Nightingale TV 的用戶端最多允許 $limit 個 YouTube 頻道。如需更多，請在 伺服器 → YouTube → Google 用戶端 中使用你自己的用戶端。';
  }

  @override
  String youTubeSharedTooMany(int limit) {
    return 'Nightingale TV 的用戶端最多允許 $limit 個 YouTube 頻道。請先在「頻道」中移除一些。';
  }

  @override
  String lastBackedUp(Object when) {
    return '上次備份：$when';
  }

  @override
  String get notBackedUpYet => '尚未備份。';

  @override
  String get undoRestore => '撤銷還原';

  @override
  String get undoLineupReset => '撤銷重設頻道列表';

  @override
  String undoDeleting(Object name) {
    return '撤銷刪除 $name';
  }

  @override
  String get undoDeletingAProfile => '撤銷刪除設定檔';

  @override
  String get undoUpdate => '撤銷更新';

  @override
  String get undoLineupCleanup => '撤銷整理頻道列表';

  @override
  String undoTitle(Object action, Object time) {
    return '$action · $time';
  }

  @override
  String undoPointSaved(Object when, Object profiles) {
    return '儲存於 $when：$profiles';
  }

  @override
  String get pickThePlaylistFileAgain => '請重新選擇播放清單檔案';

  @override
  String get pickTheGuideFileAgain => '請重新選擇節目表檔案';

  @override
  String get playlistFileNotOnDevice => '此裝置上沒有播放清單檔案';

  @override
  String get guideFileNotOnDevice => '此裝置上沒有節目表檔案';

  @override
  String get youTubeServerOwnClient => '伺服器模式使用你自己的 Google 用戶端。';

  @override
  String get uploadJsonFile => '上傳 JSON 檔案';

  @override
  String get continueStep => '繼續';

  @override
  String get watchNoChannels => '這個設定檔沒有 YouTube 頻道。請在 伺服器 中新增 YouTube。';
}

/// The translations for Chinese, as used in Hong Kong, using the Han script (`zh_Hant_HK`).
class AppLocalizationsZhHantHk extends AppLocalizationsZh {
  AppLocalizationsZhHantHk() : super('zh_Hant_HK');

  @override
  String get onlyChannelsYou => '只能移除你自己新增的頻道。可以改為隱藏這個頻道。';

  @override
  String get music => '音樂';

  @override
  String get nothingInThe => '媒體庫中沒有符合的內容。';

  @override
  String get chooseSongsOr => '請選擇歌曲或音樂影片。';

  @override
  String get blockChannel => '節目時段頻道';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return '這與同一頻道上的「$title」（$clash）重疊。';
  }

  @override
  String get chooseSomeShows => '請為這個節目時段選擇要播放的節目或電影。';

  @override
  String nothingInThis(Object shortLabel) {
    return '這個組合中沒有分級為 $shortLabel 或更高的內容。請選擇較低的分級或其他節目。';
  }

  @override
  String get theLineupsShows => '頻道列表中的節目沒有任何劇集。請選擇其他節目。';

  @override
  String get addAShow => '請在頻道列表中新增一個節目。';

  @override
  String get chooseAChannel => '請選擇一個頻道。';

  @override
  String get theBlockHas => '節目時段的結束時間必須與開始時間不同。';

  @override
  String get pickAtLeast => '請至少選擇一天。';

  @override
  String get giveTheBlock => '請為節目時段輸入標題。';

  @override
  String get thisChannelDoesnt => '這個頻道沒有時段。';

  @override
  String get onlyShuffledChannels => '只有隨機播放的頻道才能重新隨機排列。';

  @override
  String get chooseSomethingFor => '請選擇這個頻道要播放的內容。';

  @override
  String get onlyChannelsYouAdded => '只有你自己新增的頻道才能變更播放內容。';

  @override
  String get myChannel => '我的頻道';

  @override
  String get noneOfYour => '無法連線到你的任何伺服器。';

  @override
  String scanning(Object where) {
    return '正在掃描 $where…';
  }

  @override
  String get buildingChannels => '正在建立頻道…';

  @override
  String get notSignedIn => '尚未登入。';

  @override
  String isAlreadyIn(Object name) {
    return '$name 已在這個個人檔案中';
  }

  @override
  String get thatServerIs => '這部伺服器已不在這個個人檔案中';

  @override
  String get yourSessionExpired => '你的工作階段已過期。請重新登入。';

  @override
  String get m3uPlaylist => 'M3U 播放清單';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName 沒有直播電視頻道';
  }

  @override
  String couldntReach(Object serverName) {
    return '無法連線到 $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return '$serverName 直播電視';
  }

  @override
  String liveTvIs(Object serverName) {
    return '$serverName 直播電視已經是一個來源';
  }

  @override
  String get notSignedIn2 => '尚未登入';

  @override
  String get newGroup => '新增素材組';

  @override
  String get thisBackupIs => '這個備份已損毀：無法讀取其中一個頻道標誌。';

  @override
  String get thisBackupIsDamaged => '這個備份已損毀：無法讀取其中的直播電視匯出設定。';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return '這個備份已損毀：無法讀取 $name 的$what。';
  }

  @override
  String get liveTvSources => '直播電視來源';

  @override
  String thisBackupCant(Object problem) {
    return '無法還原這個備份。$problem';
  }

  @override
  String get thisBackupIsDamagedIts => '這個備份已損毀：無法讀取其中的個人檔案。';

  @override
  String get thisFileIs => '這個檔案太大，不可能是 Nightingale TV 備份。';

  @override
  String get thisBackupWas => '這個備份是由較新版本的 Nightingale TV 建立的。';

  @override
  String get thisFileIsnt => '這個檔案不是 Nightingale TV 備份，或者已損毀。';

  @override
  String restoredTheBackup(Object toLocal) {
    return '已還原 $toLocal 的備份。';
  }

  @override
  String couldntRestoreThe(Object e) {
    return '無法還原備份：$e';
  }

  @override
  String couldntSaveA(Object e) {
    return '無法先儲存備份：$e';
  }

  @override
  String get automatic => '自動';

  @override
  String get nc1718 => 'NC-17 / 18 歲以上';

  @override
  String get tvMaR => 'TV-MA / R 以上';

  @override
  String get tv14Pg => 'TV-14 / PG-13 以上';

  @override
  String get off => '關閉';

  @override
  String get nowAndThen => '偶爾';

  @override
  String get always => '一律';

  @override
  String get truncate => '提前結束';

  @override
  String get offlineImage => '離線圖片';

  @override
  String get filler => '填補';

  @override
  String get leastWatchedFirst => '最少觀看的優先';

  @override
  String get shuffled => '隨機';

  @override
  String get inOrderShows => '依序（節目輪流播放）';

  @override
  String get channelsWhereEverything =>
      '所有播放內容（包括節目時段）均為 TV-Y、TV-Y7、TV-G 或 G 級的頻道。';

  @override
  String get musicVideoAnd => '音樂影片和電台頻道。';

  @override
  String get channelsThatPlay => '只播放電影、不播放劇集或音樂的頻道。';

  @override
  String get channelsFromYour => '來自你的直播電視來源的頻道。';

  @override
  String get channelsYouMarked => '你加入「我的最愛」的頻道。';

  @override
  String get everyChannel => '所有頻道。';

  @override
  String get kids => '兒童';

  @override
  String get movies => '電影';

  @override
  String get liveTv2 => '直播電視';

  @override
  String get favorites => '我的最愛';

  @override
  String get all => '全部';

  @override
  String get theAccentsAre => '強調色是一個主題，每項為 theme 或 channel。';

  @override
  String get thoseArentRetro => '這些不是復古設定。';

  @override
  String get theOverlayTheme => '疊加層主題為 standard、vcr、cableBox 或 stationIdent。';

  @override
  String get theCrtEffect =>
      'CRT 效果為 off、softTube、livingRoom、arcade、studioMonitor 或 custom。';

  @override
  String get theSurroundImage => '邊框圖片是一個檔案名稱。';

  @override
  String get theSurroundIs => '邊框為 black、charcoal、channel 或 image。';

  @override
  String get thePictureShape => '畫面形狀為 original、fill43 或 fit43。';

  @override
  String get channelColor => '頻道顏色';

  @override
  String get theme => '主題';

  @override
  String get stationIdent => '台標';

  @override
  String get cableBox => '有線電視盒';

  @override
  String get vcr => '錄影機';

  @override
  String get standard => '標準';

  @override
  String get custom => '自訂';

  @override
  String get studioMonitor => '錄影廠監視器';

  @override
  String get arcade => '街機';

  @override
  String get livingRoom => '客廳';

  @override
  String get softTube => '柔和顯像管';

  @override
  String get customColorIs => '自訂顏色為 natural、warm、faded 或 vivid。';

  @override
  String get customLinesIs => '自訂掃描線為 240 或 480。';

  @override
  String customIsOff(Object key) {
    return '自訂 $key 為 off、low、medium 或 high。';
  }

  @override
  String get thatIsntA => '這不是自訂樣式。';

  @override
  String get vivid => '鮮豔';

  @override
  String get faded => '褪色';

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
  String get image => '圖片';

  @override
  String get charcoal => '炭灰';

  @override
  String get black => '黑色';

  @override
  String get n43Fit => '4:3 符合';

  @override
  String get n43Fill => '4:3 填滿';

  @override
  String get original => '原始';

  @override
  String get thisChannelIs => '這個頻道暫停播出';

  @override
  String get offAir => '暫停播出';

  @override
  String get tail => '填補';

  @override
  String get postRoll => '節目後';

  @override
  String get midRoll => '節目中';

  @override
  String get preRoll => '節目前';

  @override
  String get commercials => '廣告';

  @override
  String get bumpers => '過場片段';

  @override
  String get pleaseStandBy => '請稍候';

  @override
  String get offTheAir => '暫停播出';

  @override
  String get wellBeRight => '馬上回來';

  @override
  String upNextAt(Object at) {
    return '$at 稍後播放';
  }

  @override
  String backOnThe(Object next, Object title) {
    return '$next 恢復播出《$title》';
  }

  @override
  String get processor => '處理器';

  @override
  String get graphicsCardNvenc => '顯示卡（NVENC）';

  @override
  String get graphicsCardVaapi => '顯示卡（VAAPI）';

  @override
  String get signInTo => '請在電視上登入這個個人檔案，以匯出它的頻道。';

  @override
  String get signInToThis => '請在這裡登入這個個人檔案，以匯出它的頻道。';

  @override
  String portIsIn(Object port) {
    return '連接埠 $port 已被其他程式占用。請選擇其他連接埠，然後在 Plex、Jellyfin 或 Emby 中更新。';
  }

  @override
  String anotherProfileAlready(Object port) {
    return '另一個個人檔案已在使用連接埠 $port。';
  }

  @override
  String get pickAPort => '請選擇 1024 到 65535 之間的連接埠。';

  @override
  String get movie => '電影';

  @override
  String backOnTheAir(Object start, Object title) {
    return '$start 恢復播出《$title》。';
  }

  @override
  String get images => '圖片';

  @override
  String get couldNotRead => '無法讀取這張圖片。請試試 PNG、JPG、WebP 或 SVG。';

  @override
  String get thatFileIs => '這個檔案不是有效的 SVG。';

  @override
  String get thatImageIs => '這張圖片超過 20 MB。請選擇較小的圖片。';

  @override
  String get other => '其他';

  @override
  String get seasonsHolidays => '季節與節日';

  @override
  String get newsWeather => '新聞與天氣';

  @override
  String get sports => '體育';

  @override
  String get genres => '類型';

  @override
  String get kidsFamily => '兒童與家庭';

  @override
  String get tvMovies => '電視與電影';

  @override
  String get theServerWould => '伺服器拒絕轉換這個項目。';

  @override
  String get theServerHas => '伺服器沒有這個項目的可播放版本。';

  @override
  String get externalLabel => '外部';

  @override
  String get scanningChannelSources => '正在掃描頻道來源…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl 的回應不像 Jellyfin 伺服器。';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return '在 $serverUrl 找不到 Jellyfin 伺服器。$message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return '$path 發生伺服器錯誤 $statusCode。';
  }

  @override
  String get wrongUsernameOr => '用戶名稱或密碼錯誤，或者工作階段已過期。';

  @override
  String couldNotReach(Object e) {
    return '無法連線到伺服器（$e）。';
  }

  @override
  String get theServerTook => '伺服器回應時間過長。';

  @override
  String get theServerWouldNot => '伺服器拒絕轉換這個頻道。';

  @override
  String get musicVideo => '音樂影片';

  @override
  String movie2(Object year) {
    return '電影 · $year';
  }

  @override
  String get commercial => '廣告';

  @override
  String couldntReachThe(Object what) {
    return '無法連線到$what';
  }

  @override
  String theIsToo(Object what) {
    return '$what太大';
  }

  @override
  String theSAddress(Object what) {
    return '$what的地址不是網址';
  }

  @override
  String get noGuideInformation => '沒有節目資訊';

  @override
  String get serverLiveTv => '伺服器直播電視';

  @override
  String get theChannelHas => '這個頻道沒有串流地址。';

  @override
  String get couldntReadThe => '無法讀取節目表';

  @override
  String get couldntReachTheGuide => '無法連線到節目表';

  @override
  String get theSourceHas => '這個來源沒有播放清單';

  @override
  String get couldntReachThePlaylist => '無法連線到播放清單';

  @override
  String get couldntReadThePlaylist => '無法讀取播放清單檔案';

  @override
  String couldntRefresh(Object name) {
    return '無法重新整理 $name';
  }

  @override
  String get thePlaylistHas => '播放清單中沒有頻道';

  @override
  String get thatIsntAn => '這不是 M3U 播放清單';

  @override
  String get thatIsntAnXmltv => '這不是 XMLTV 節目表';

  @override
  String get theGuideIs => '節目表太大（超過 1 GB）';

  @override
  String get nightingaleTvBackups => 'Nightingale TV 備份';

  @override
  String get uninstallingThisApp => '解除安裝這個應用程式會刪除它的個人檔案、頻道和設定，除非你事先備份或轉移它們。';

  @override
  String theStoreVersion(Object officialName) {
    return 'Google Play 版本會以獨立的應用程式「$officialName」與這個應用程式並存安裝，並有自己的設定。可免費使用 14 天，之後一次購買即可支持這個項目。安裝後，你可以從這裡把設定轉移過去。';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return '來自 Google Play 和官方 Nightingale TV APK 的更新會覆蓋安裝這個應用程式，並保留你的設定。你自己建置的版本會以獨立的應用程式「$ownBuildName」安裝，你可以從這裡把設定轉移過去。';
  }

  @override
  String get yourOwnBuild => '你自己建置的版本';

  @override
  String get officialNightingaleTv => '官方 Nightingale TV APK';

  @override
  String get installedFromGoogle => '從 Google Play 安裝';

  @override
  String get nightingaleTvOwn => 'Nightingale TV（自行建置版）';

  @override
  String get sleepTimerOff => '睡眠定時器已關閉';

  @override
  String get sleepAtEnd => '節目結束時睡眠';

  @override
  String sleepInMin(Object minutes) {
    return '$minutes 分鐘後睡眠';
  }

  @override
  String get forced => '強制';

  @override
  String get unknownLanguage => '未知語言';

  @override
  String didntStart(Object name) {
    return '$name 未能啟動';
  }

  @override
  String get thisDeviceCant => '這部裝置無法播放這個頻道的影片';

  @override
  String get thisChannelsStream => '這部裝置不支援這個頻道的串流類型';

  @override
  String refusedTheStream(Object name) {
    return '$name 拒絕了串流。它可能正在另一部裝置上播放。';
  }

  @override
  String yourAccountCant(Object server) {
    return '你的 $server 帳戶無法觀看這個頻道';
  }

  @override
  String cantReach(Object name) {
    return '無法連線到 $name';
  }

  @override
  String allOfS(Object server) {
    return '$server 的所有調諧器都在使用中';
  }

  @override
  String lostTheSignal(Object name) {
    return '$name 訊號中斷';
  }

  @override
  String get couldntPlayThat => '無法播放這一段。正在返回直播';

  @override
  String get backToLive => '返回直播';

  @override
  String get theServerTookToo => '伺服器開始轉換這個節目的時間過長。';

  @override
  String get nothingToPlay => '這個頻道沒有可播放的內容';

  @override
  String captionsOn(Object shown) {
    return '字幕已開啟：$shown';
  }

  @override
  String get captionsOn2 => '字幕已開啟';

  @override
  String get captionsOnNo => '字幕已開啟：這個節目沒有字幕';

  @override
  String get captionsOff => '字幕已關閉';

  @override
  String get guest => '訪客';

  @override
  String get thereHasTo => '至少要有一個成人個人檔案。';

  @override
  String kidProfilesNeedPins(Object names) {
    return '只要還有兒童個人檔案，每個成人個人檔案都需要設定 PIN，以免兒童切換進去。請為 $names 設定 PIN。';
  }

  @override
  String get switchToAnother => '刪除這個個人檔案前，請先切換到另一個個人檔案。';

  @override
  String get me => '我';

  @override
  String get couldntOpenA => '無法為遙控器開啟網絡連接埠。';

  @override
  String get notPaired => '未配對';

  @override
  String get phone => '手機';

  @override
  String get thatCodeDoesnt => '代碼不符。請核對電視上顯示的代碼。';

  @override
  String get openMenuPhone => '請在電視上開啟「選單」→「手機遙控器」進行配對';

  @override
  String yourAccountCantWatch(Object serverName) {
    return '你的 $serverName 帳戶無法觀看直播電視';
  }

  @override
  String get enterYourServer => '請輸入伺服器地址。';

  @override
  String get needsSignIn => '需要登入';

  @override
  String get cantBeReached => '無法連線';

  @override
  String isNotAnswering(Object name) {
    return '$name 的所有地址都沒有回應。它開機了嗎？';
  }

  @override
  String get everyServerOn => '這個 Plex 帳戶上的所有伺服器都已在這個個人檔案中。';

  @override
  String get thisPlexAccount => '這個 Plex 帳戶沒有伺服器。請請伺服器的擁有者與你分享。';

  @override
  String quickConnectStopped(Object message) {
    return '快速連線已停止：$message';
  }

  @override
  String get enterYourUsername => '請輸入用戶名稱。';

  @override
  String get plexDidNot => 'Plex 未能切換用戶。';

  @override
  String plexTvError(Object statusCode) {
    return 'plex.tv 錯誤 $statusCode。';
  }

  @override
  String get yourPlexSign => '你的 Plex 登入已過期。';

  @override
  String couldNotReachPlex(Object e) {
    return '無法連線到 plex.tv（$e）。';
  }

  @override
  String get plexTvTook => 'plex.tv 回應時間過長。';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — 由 $ownerName 分享';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return '伺服器拒絕轉換這個項目（$transcodeDecisionText）。';
  }

  @override
  String get theServerHasNo => '伺服器上沒有這個項目的檔案；請重新整理媒體庫。';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl 的回應不像 Plex 伺服器。';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return '在 $serverUrl 找不到 Plex 伺服器。$message';
  }

  @override
  String get thePlexSign => 'Plex 登入已過期。';

  @override
  String channelIsNot(Object channelId) {
    return '頻道 $channelId 不在任何 DVR 上。';
  }

  @override
  String get noSuchUser => '沒有這個用戶。';

  @override
  String get yourCurrentPassword => '目前的密碼錯誤。';

  @override
  String get signInFirst => '請先登入。';

  @override
  String thereIsAlready(Object name) {
    return '已經有名為 $name 的用戶。';
  }

  @override
  String get thisAccountIs => '這個帳戶已停用。';

  @override
  String get chooseAnAdmin => '請選擇一個管理員帳戶。';

  @override
  String useAtMost(Object maxNameLength) {
    return '用戶名稱最多 $maxNameLength 個字元。';
  }

  @override
  String get enterAUser => '請輸入用戶名稱。';

  @override
  String useAtLeast(Object minPasswordLength) {
    return '請至少使用 $minPasswordLength 個字元。';
  }

  @override
  String get tooManyWrong => '密碼錯誤次數過多。請一分鐘後再試。';

  @override
  String get wrongUserName => '用戶名稱或密碼錯誤。';

  @override
  String get openTheSetup => '請開啟伺服器記錄中的設定連結。';

  @override
  String get makeSomeoneElse => '請先將其他人設為管理員。';

  @override
  String get noSuchProfile => '沒有這個個人檔案。';

  @override
  String get onlyAnAdmin => '只有管理員才能這樣做。';

  @override
  String get thatProfileIsnt => '這個個人檔案沒有指派給你。';

  @override
  String get enterAGrown => '要變更兒童個人檔案的設定，請輸入成人的 PIN。';

  @override
  String get enterThisProfiles => '請輸入這個個人檔案的 PIN。';

  @override
  String get reloadThePage => '請重新載入頁面後再試一次。';

  @override
  String somethingWentWrong(Object e) {
    return '發生問題：$e';
  }

  @override
  String get signInToThisProfile => '請先登入這個個人檔案。';

  @override
  String get changedInAnother => '已在另一個視窗中變更。正在顯示最新內容。';

  @override
  String get wrongPin => 'PIN 錯誤。';

  @override
  String get tooManyWrongPins => 'PIN 錯誤次數過多。請一分鐘後再試。';

  @override
  String get theRoleIs => '角色為「admin」或「user」。';

  @override
  String get noSuchBackup => '沒有這個備份。';

  @override
  String get backupsAreOff => '備份已關閉。';

  @override
  String get noSuchEncoder => '沒有這個編碼器。';

  @override
  String get allow1To => '請允許 1 到 16 路串流。';

  @override
  String get noSuchQuality => '沒有這個畫質。';

  @override
  String get processorOnly => '僅處理器';

  @override
  String get liveTvExport => '直播電視匯出未在執行。';

  @override
  String get thoseArentPremiere => '這些不是首播設定。';

  @override
  String get theLogoMode => '標誌模式為 always、nowAndThen 或 off。';

  @override
  String get thatIsntAPicture => '這不是自訂標誌資料夾中的圖片。';

  @override
  String couldntSaveBackupNothingReset(Object e) {
    return '無法先儲存備份，因此沒有重設任何內容：$e';
  }

  @override
  String get theKindIs => '類型為「block」、「music」或「custom」。';

  @override
  String get thatIsntAPlay => '這不是播放順序。';

  @override
  String get musicChannelsOnly => '音樂頻道只能隨機播放。';

  @override
  String get channelNumbersStart => '頻道號碼從 1 開始。';

  @override
  String get slotLengthsAre => '時段長度為 15、30、60、90 或 120 分鐘。';

  @override
  String get thatIsntAChannel => '這不是頻道。';

  @override
  String get noSuchChannel => '沒有這個頻道。';

  @override
  String get thatPictureIs => '這張圖片太大（最大 5 MB）。';

  @override
  String get unknownAction => '未知的動作。';

  @override
  String get noSuchServer => '沒有這部伺服器。';

  @override
  String get startSigningIn => '請先開始登入。';

  @override
  String get aRestoreIs => '已有還原正在進行。';

  @override
  String get uploadTheBackup => '請重新上傳備份。';

  @override
  String get discoveryIsOff => '探索功能已關閉，請透過地址新增調諧器。若要開啟，請以主機網絡模式執行容器。';

  @override
  String get sendKeys => '請傳送按鍵。';

  @override
  String get enterThePlaylists => '請輸入播放清單的地址，或選擇播放清單檔案';

  @override
  String get uploadTheFile => '請重新上傳檔案。';

  @override
  String get kidProfilesGet => '兒童個人檔案沒有直播頻道。';

  @override
  String liveTvIsAlready(Object name) {
    return '$name 直播電視已新增';
  }

  @override
  String get noSuchSource => '沒有這個來源。';

  @override
  String get thatFileIsToo => '這個檔案太大（最大 32 MB）。';

  @override
  String get aPinIs => 'PIN 為 4 位數字。';

  @override
  String get noSuchRating => '沒有這個分級。';

  @override
  String get noSuchKind => '沒有這個類型。';

  @override
  String get onlyAnAdminCan => '只有管理員才能變更這一項。';

  @override
  String shouldBeA(Object key) {
    return '「$key」應為文字清單。';
  }

  @override
  String shouldBeAn(Object key) {
    return '「$key」應為物件。';
  }

  @override
  String shouldBeTrue(Object key) {
    return '「$key」應為 true 或 false。';
  }

  @override
  String shouldBeANumber(Object key) {
    return '「$key」應為數字。';
  }

  @override
  String shouldBeText(Object key) {
    return '「$key」應為文字。';
  }

  @override
  String get expectedAJson => '需要 JSON 物件。';

  @override
  String get thatIsToo => '一次傳送的內容太多。';

  @override
  String get aQualityLimit => '畫質上限至少為 500 kbps。';

  @override
  String get orderShouldName => '「order」應包含每部伺服器各一次。';

  @override
  String get orderIsMissing => '缺少「order」。';

  @override
  String get signOutOf => '若要變更主要伺服器，請先登出這個個人檔案。';

  @override
  String get thoseArentPool => '這些不是素材組資料夾。';

  @override
  String get sendRoots => '請傳送根目錄。';

  @override
  String get thatIsntAPool => '這不是素材組類型。';

  @override
  String get giveThePool => '請為素材組命名。';

  @override
  String get liveChannelsHave => '直播頻道沒有廣告時間。';

  @override
  String get sendAPlan => '請傳送方案。';

  @override
  String get thatIsntABreak => '這不是廣告時間方案。';

  @override
  String get noSuchPool => '沒有這個素材組。';

  @override
  String get thatIsntAProgramming => '這不是節目時段。';

  @override
  String get noSuchBlock => '沒有這個節目時段。';

  @override
  String get sendEveryTab => '請將每個分頁各傳送一次。';

  @override
  String get sendChannelids => '請傳送 channelIds。';

  @override
  String get giveTheGroup => '請為群組命名。';

  @override
  String get noSuchGroup => '沒有這個群組。';

  @override
  String get restoringBringsBack =>
      '還原後會找回你的個人檔案、頻道、節目時段和設定。每個個人檔案需要登入一次它的伺服器。';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels 個頻道',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup => '這部裝置上有你的設定備份：';

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get moveOkSelect => '◀▶ 移動    OK 選取';

  @override
  String get startFresh => '重新開始';

  @override
  String get restoreIt => '還原';

  @override
  String get couldntRestore => '無法還原';

  @override
  String get cancel => '取消';

  @override
  String get useYourPhone => '使用手機或電腦';

  @override
  String get openABackup => '開啟備份檔案';

  @override
  String get setUpThis =>
      '用 Nightingale TV 備份設定這部電視：你的個人檔案、頻道、節目時段和設定。每個個人檔案需要登入一次它的伺服器。';

  @override
  String get restoreFromA => '從備份還原';

  @override
  String get close => '關閉';

  @override
  String get thereYouCan =>
      '你可以在那裡下載這部電視的備份，或傳送一個備份到這裡還原。傳送的任何內容都會先在這部電視上確認。關閉這個視窗後，頁面也會關閉。';

  @override
  String get onAPhone => '在與這部電視連線同一個 Wi-Fi 的手機、平板電腦或電腦上，掃描 QR 碼或開啟：';

  @override
  String get couldntOpenANetwork => '無法為這個頁面開啟網絡連接埠。';

  @override
  String get thePageStopped => '頁面在 15 分鐘無操作後已停止。請關閉後重新開啟。';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount和$last';
  }

  @override
  String get listSeparator => '、';

  @override
  String labelValue(Object label, Object value) {
    return '$label：$value';
  }

  @override
  String get restore => '還原';

  @override
  String get liveTvExportMoves => '直播電視匯出將轉移到這部裝置；請在舊裝置上將其關閉。';

  @override
  String willNeedTo(Object need) {
    return '$need 需要重新登入伺服器。';
  }

  @override
  String get itSetsUp => '它會依照備份中的內容設定這部電視。';

  @override
  String get itReplacesEverything => '它會取代這部電視上的所有內容。你目前的設定會先備份。';

  @override
  String restoreTheBackup(Object toLocal) {
    return '要還原 $toLocal 的備份嗎？';
  }

  @override
  String get delete => '刪除';

  @override
  String get saveToFile => '儲存為檔案';

  @override
  String get moveOkSelectEsc => '▲▼◀▶ 移動    OK 選取    ESC 返回';

  @override
  String get backupRestore => '備份與還原';

  @override
  String get aBackupHolds =>
      '備份包含每個個人檔案及其頻道、節目時段、廣告和設定。每次有變更時都會保持最新。登入密碼永遠不會包含在內。';

  @override
  String couldntSaveThe(Object e) {
    return '無法儲存備份：$e';
  }

  @override
  String thatDidntWork(Object e) {
    return '操作失敗：$e';
  }

  @override
  String get aNewChannel => '新頻道在節目時段之外暫停播出，就像夜間收播的電視台一樣。';

  @override
  String get aNewChannelJust => '專為這個節目時段新增的頻道';

  @override
  String get moveOkChoose => '▲▼ 移動    OK 選擇    ESC 返回';

  @override
  String get chooseAChannel2 => '選擇頻道';

  @override
  String episodes(Object keyCount) {
    return '$keyCount 集';
  }

  @override
  String get moveOkAdd => '▲▼ 移動    OK 新增    ESC 返回';

  @override
  String get addAShow2 => '新增節目';

  @override
  String get remove => '移除';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 集',
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
  String get save => '儲存';

  @override
  String get everyDay => '每天';

  @override
  String get weekends => '週末';

  @override
  String get weekdays => '平日';

  @override
  String get days => '日期';

  @override
  String get starts => '開始';

  @override
  String get time => '時間';

  @override
  String get premieresAreOff => '首播已關閉';

  @override
  String get premieresAreOn => '首播已開啟';

  @override
  String get onTheAir => '播出中';

  @override
  String get episodesAddedTo =>
      '最近兩週新增到伺服器的劇集，會在其節目頻道的夜間時段首播：每晚每個節目播出一集新劇集，最長兩小時，並標示為 NEW。節目時段優先。';

  @override
  String get moveOkSelectEscCancel => '▲▼◀▶ 移動    OK 選取    ESC 取消';

  @override
  String get newEpisodePremieres => '新劇集首播';

  @override
  String get theChannelGoes => '在這些時間，頻道會恢復一般節目。';

  @override
  String delete2(Object title) {
    return '要刪除「$title」嗎？';
  }

  @override
  String get addAnotherShow => '再新增一個節目';

  @override
  String get missingShow => '遺失的節目';

  @override
  String runsThenStarts(Object start) {
    return '播放 $start，然後從頭開始。';
  }

  @override
  String get fillsTheBlock => '填滿節目時段。';

  @override
  String longerThanThe(Object end, Object title) {
    return '比節目時段長：它會在 $end 結束，截斷 $title。';
  }

  @override
  String get onTheAirNow => '正在播出';

  @override
  String nextAiring(Object start) {
    return '下次播出 · $start';
  }

  @override
  String inAll(Object runtime) {
    return '共 $runtime';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies 部電影',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount 個節目',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => '還沒有內容。請選擇節目或電影。';

  @override
  String get nothingYetAdd => '還沒有內容。請在頻道列表中新增節目。';

  @override
  String get plays => '播放內容';

  @override
  String onLabel(Object number, Object name) {
    return '在 $number $name 播出';
  }

  @override
  String get noChannelChosen => '未選擇頻道';

  @override
  String get onANew => '在新頻道上（其他時間暫停播出）';

  @override
  String get untitledBlock => '未命名的節目時段';

  @override
  String get deleteBlock => '刪除節目時段';

  @override
  String get blockIsOff => '節目時段已關閉';

  @override
  String get blockIsOn => '節目時段已開啟';

  @override
  String get onlyShowsAnd => '只播放達到或高於這個分級的節目和電影。未分級的內容會被排除。';

  @override
  String get anyRating => '任何分級';

  @override
  String get minimumRating => '最低分級';

  @override
  String get chooseShowsMovies => '選擇節目和電影';

  @override
  String get showsAndMovies => '你選擇的節目和電影，依序或隨機播放。';

  @override
  String get yourShowsIn => '依這個順序播放你的節目，每次播出時各播下一集。如果還有剩餘時間，頻道列表會從頭開始。';

  @override
  String get aLineup => '頻道列表';

  @override
  String get aMix => '混合';

  @override
  String get whatItPlays => '播放內容';

  @override
  String get repeatsEveryYear => '每年重複。';

  @override
  String get to => '到';

  @override
  String get from => '從';

  @override
  String get onlyBetweenDates => '僅在指定日期之間';

  @override
  String get allYear => '全年';

  @override
  String get dates => '日期';

  @override
  String get nextDay => '（隔天）';

  @override
  String get ends => '結束';

  @override
  String get channel => '頻道';

  @override
  String get saturdayMorningCartoons => '週六早晨卡通';

  @override
  String get title => '標題';

  @override
  String get newProgrammingBlock => '新增節目時段';

  @override
  String get newLateNight => '新增深夜時段';

  @override
  String get editProgrammingBlock => '編輯節目時段';

  @override
  String next(Object next, Object next2) {
    return '下次：$next $next2';
  }

  @override
  String get onTheAirNow2 => '正在播出';

  @override
  String get noUpcomingAirings => '沒有即將播出的節目';

  @override
  String get itsChannelIs => '它的頻道已不存在。請選擇新的頻道。';

  @override
  String get turnedOff => '已關閉';

  @override
  String get blocksTakeOver => '節目時段會在你選擇的日期和時間接管頻道，例如週六早晨卡通。每次播出都會從上次停止的地方繼續。';

  @override
  String get moveOkEdit => '▲▼ 移動    OK 編輯    ESC 返回';

  @override
  String get programmingBlocks => '節目時段';

  @override
  String get newlyAddedEpisodes => '新增的劇集，在其節目的頻道上';

  @override
  String get onLabel2 => '開啟';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips 個片段',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => '100 分鐘電影';

  @override
  String get n44MinDrama => '44 分鐘劇集';

  @override
  String get n22MinSitcom => '22 分鐘處境喜劇';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: '，中間 $midCount 次廣告',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name：無廣告';
  }

  @override
  String get openAndClose => '廣告時間的開頭和結尾，來自設為過場片段的素材組';

  @override
  String get bumpers2 => '過場片段';

  @override
  String get toTheHalf => '補足到半點';

  @override
  String get toTheHour => '補足到整點';

  @override
  String get padsEachSlot => '將每個時段補足到整點，讓節目準時開始';

  @override
  String get tail2 => '填補';

  @override
  String get afterEachProgram => '每個節目之後';

  @override
  String get postRoll2 => '節目後';

  @override
  String get length => '長度';

  @override
  String get every => '間隔';

  @override
  String min(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String get breaksInsideShows => '節目和電影中間的廣告時間，盡量放在劇情轉折處';

  @override
  String get midRoll2 => '節目中';

  @override
  String get beforeEachProgram => '每個節目之前';

  @override
  String get preRoll2 => '節目前';

  @override
  String get onePool => '一個素材組…';

  @override
  String get allBumperPools => '所有過場片段素材組';

  @override
  String get none => '無';

  @override
  String clipsFrom(Object pool) {
    return '片段來源：$pool';
  }

  @override
  String get allPools => '所有素材組';

  @override
  String clips2(Object label) {
    return '$label片段';
  }

  @override
  String get leave => '離開';

  @override
  String get yourChangesTo => '你對廣告時間設定的變更將會遺失。';

  @override
  String get leaveWithoutSaving => '不儲存就離開嗎？';

  @override
  String get size => '大小';

  @override
  String get captions => '字幕';

  @override
  String get sampleCaption => '字幕範例';

  @override
  String get theServerDraws => '這些字幕由伺服器繪製到畫面中，因此無法在這裡變更大小。';

  @override
  String get findingSubtitles => '正在尋找字幕…';

  @override
  String get noSubtitlesFor => '這個節目沒有字幕';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours 小時 $inMinutes 分鐘';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed 天';
  }

  @override
  String get theChannelGoesAway => '這個頻道會連同它的節目時段及其在頻道群組中的位置一起刪除。';

  @override
  String remove2(Object name) {
    return '要移除「$name」嗎？';
  }

  @override
  String contentOf(Object name) {
    return '$name 的內容';
  }

  @override
  String get newChannel => '新頻道';

  @override
  String get defaultCard => '預設卡片';

  @override
  String get changeOfflineImage => '變更離線圖片…';

  @override
  String get offlineImage2 => '離線圖片…';

  @override
  String fillerPool(Object poolName) {
    return '填補素材組：$poolName';
  }

  @override
  String get slotLength => '時段長度';

  @override
  String get hideFromGuide => '從節目表中隱藏';

  @override
  String get showInGuide => '在節目表中顯示';

  @override
  String get favorite => '加入我的最愛';

  @override
  String get unfavorite => '從我的最愛中移除';

  @override
  String mainSetting(Object label) {
    return '主要設定（$label）';
  }

  @override
  String get channelLogo => '頻道標誌';

  @override
  String breaksOn(Object name) {
    return '$name 的廣告時間';
  }

  @override
  String get custom2 => '自訂…';

  @override
  String get commercials2 => '廣告';

  @override
  String get removeChannel => '移除頻道';

  @override
  String get reshuffle => '重新隨機排列';

  @override
  String get editContent => '編輯內容';

  @override
  String get number => '頻道號碼 +';

  @override
  String get number2 => '頻道號碼 −';

  @override
  String get sourcesLogo => '來源的標誌';

  @override
  String get changeIcon => '變更圖示';

  @override
  String get rename => '重新命名';

  @override
  String get channelName => '頻道名稱';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount 個節目時段',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return '每 $loop 重複一次';
  }

  @override
  String programs(Object playlistCount) {
    return '$playlistCount 個節目';
  }

  @override
  String get programmingBlocksOnly => '僅節目時段';

  @override
  String channelThere(Object n) {
    return '那裡的頻道 $n';
  }

  @override
  String channel2(Object number) {
    return '頻道 $number';
  }

  @override
  String get noChannelsYet => '還沒有頻道';

  @override
  String get guideRange => '節目表範圍';

  @override
  String get channelsEditOk => '▲▼ 頻道    ▶ 編輯    OK 選取    ESC 返回';

  @override
  String get channelsIcons => '頻道和圖示';

  @override
  String get howFarAhead => '節目表從現在起顯示多長時間。';

  @override
  String hours(Object hours) {
    return '$hours 小時';
  }

  @override
  String get theChannelLogo => '在電視和直播電視匯出中，顯示在畫面角落的頻道標誌。';

  @override
  String get name => '名稱';

  @override
  String get ok => '確定';

  @override
  String get channels2 => '頻道';

  @override
  String get groupName => '群組名稱';

  @override
  String group(Object name) {
    return '群組：$name';
  }

  @override
  String get deleteGroup => '刪除群組';

  @override
  String get itsTabLeaves => '它的分頁會從節目表中移除。頻道仍保留在你的頻道列表中。';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount 個頻道',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => '你選擇的頻道。';

  @override
  String get theTabsAt => '節目表頂端的分頁，依這個順序排列。隱藏的分頁和沒有頻道的分頁不會顯示。';

  @override
  String get channelGroups => '頻道群組';

  @override
  String get shown => '顯示';

  @override
  String get down => '下移';

  @override
  String get up => '上移';

  @override
  String get automatic2 => '· 自動';

  @override
  String channels4(Object channelIdsCount) {
    return '· $channelIdsCount 個頻道';
  }

  @override
  String get create => '建立';

  @override
  String get commercialsNeverShow => '廣告永遠不會出現在伺服器的觀看記錄中。';

  @override
  String get theSameAds => '每個人每次看到的都是相同的廣告。';

  @override
  String get bumperPoolsClips => '過場片段素材組的片段用於廣告時間的開頭和結尾，不會當作廣告播放。';

  @override
  String get howBreaksWork => '廣告時間如何運作';

  @override
  String get withATail => '使用填補時，時段會補足到整點。';

  @override
  String get adsShrinkTo => '廣告會縮短以符合時段，每次廣告時間不超過 5 分鐘。';

  @override
  String get aShortBreak =>
      '節目前有一段短廣告，節目中每 10 分鐘（電影為 12 分鐘）插入一次廣告，盡量放在劇情轉折處，其餘廣告放在節目後。';

  @override
  String get pickAutomaticFor => '選擇「自動」可獲得類似電視廣播的廣告時間，選擇「自訂」可自行設定。';

  @override
  String workingOn(Object current) {
    return '正在處理 $current…';
  }

  @override
  String get analysis => '分析';

  @override
  String couldNotBe(Object failed) {
    return '$failed 無法分析（檔案變更後會再試一次）';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return '已找到廣告點的節目：$programsDone / $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return '已分割的長影片：$reelsDone / $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders 個資料夾  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '來自 $used 個廣告素材組的 $clips。',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce => '素材組中有片段後，廣告時間才會開始。請在素材組中新增含有影片的資料夾。';

  @override
  String get breaksStartOnceA => '素材組中有片段後，廣告時間才會開始。它的長影片正在分割中。';

  @override
  String get breaksStartOnceAPool => '素材組中有片段後，廣告時間才會開始。請在下方建立素材組。';

  @override
  String breaksAreOff(Object clips) {
    return '廣告時間已關閉。你的素材組中有 $clips 可用。';
  }

  @override
  String get breaksAreOff2 => '廣告時間已關閉。';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 個片段',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return '上次掃描失敗：$syncError';
  }

  @override
  String get newPool => '新增素材組';

  @override
  String get pickTheFolders =>
      '請選擇伺服器上存放廣告和過場片段的資料夾。其中的影片會從一般頻道中移出，改為填補廣告時間。將素材組的類型設為「過場片段」，即可用它的片段作為廣告時間的開頭和結尾。';

  @override
  String get pools => '素材組';

  @override
  String get breakSettings => '廣告時間設定…';

  @override
  String get commercialBreaks => '廣告時間';

  @override
  String get breakSettings2 => '廣告時間設定';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count有了它，廣告點也會更自然。';
  }

  @override
  String waiting(Object waiting) {
    return '（$waiting 個等待中）。';
  }

  @override
  String get fullStop => '。';

  @override
  String get longCommercialVideos => '這部裝置無法分割沒有章節的長廣告影片';

  @override
  String get installFfmpegTo => '安裝 ffmpeg 以分割長廣告影片';

  @override
  String get picturesOnThis => '這部裝置上的圖片，最新的在前。大圖會縮小到 512 px。';

  @override
  String get noPicturesOn =>
      '這部裝置上還沒有圖片。請將 PNG 或 JPG 複製到它的 Download 資料夾或 USB 手指中，然後再試一次。';

  @override
  String get lookingForPictures => '正在尋找圖片…';

  @override
  String get couldntReadThePictures => '無法讀取這部裝置上的圖片。';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV 沒有查看這部裝置上圖片的權限。請在 Android 的「設定」›「應用程式」›「Nightingale TV」›「權限」中允許「相片和影片」，然後再試一次。';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ 移動    OK 選擇    ESC 取消';

  @override
  String get chooseAPicture => '選擇圖片';

  @override
  String thePoolHasnt(Object error) {
    return '$error  素材組沒有變更。';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  沒有任何變更。';
  }

  @override
  String get couldntReachTheServer => '無法連線到伺服器';

  @override
  String get tryAgain => '重試';

  @override
  String get nothingInside => '裡面沒有內容';

  @override
  String get noMovies => '沒有電影';

  @override
  String inside(Object childrenCount) {
    return '裡面有 $childrenCount 項';
  }

  @override
  String get video => '影片';

  @override
  String collection(Object name) {
    return '$name（合集）';
  }

  @override
  String get included => '已包含';

  @override
  String get nothingInside2 => '裡面沒有內容。';

  @override
  String get loadingFolders => '正在載入資料夾…';

  @override
  String get pressOnA => '在媒體庫上按 ▶ 查看其中的內容。';

  @override
  String get done => '完成';

  @override
  String ticked(Object _pickedCount) {
    return '已勾選 $_pickedCount 項';
  }

  @override
  String get nothingTickedYet => '還沒有勾選任何內容。勾選媒體庫即可使用全部內容，或按 ▶ 選擇其中的內容。';

  @override
  String get wholeLibrary => '整個媒體庫';

  @override
  String get libraries => '媒體庫';

  @override
  String get loadingLibraries => '正在載入媒體庫…';

  @override
  String get moveOkTick => '▲▼ 移動    OK 勾選    ▶ 開啟    ◀ 返回上層    ESC 取消';

  @override
  String foldersFor(Object poolName) {
    return '$poolName 的資料夾';
  }

  @override
  String get chooseFolders => '選擇資料夾';

  @override
  String get chooseWhatPlays => '選擇這個頻道播放的內容';

  @override
  String get endsEarly => '提前結束';

  @override
  String get madeFromThis => '由這個頻道的節目和電影產生，並隨媒體庫更新。變更任何內容後，它就歸你所有。';

  @override
  String get fromTheLineup => '來自頻道列表';

  @override
  String yesterday(Object t) {
    return '昨天 $t';
  }

  @override
  String today(Object t) {
    return '今天 $t';
  }

  @override
  String behind(Object d) {
    return '落後 $d';
  }

  @override
  String hr(Object h) {
    return '$h 小時';
  }

  @override
  String get underAMinute => '不到一分鐘';

  @override
  String get noProgramming => '沒有節目';

  @override
  String get today2 => '今天';

  @override
  String get tuning => '正在轉台…';

  @override
  String get offAir2 => '暫停播出';

  @override
  String get noSignal => '無訊號';

  @override
  String left(Object now) {
    return '剩餘 $now';
  }

  @override
  String get nothingScheduled => '沒有節目安排';

  @override
  String get back => '返回';

  @override
  String get sleep => '睡眠';

  @override
  String get menu => '選單';

  @override
  String get nightingaleTvGuide => 'NIGHTINGALE TV 節目表';

  @override
  String nowPlaying(Object title) {
    return '正在播放：$title';
  }

  @override
  String get mMenu => 'M 選單';

  @override
  String get escBackTo => 'ESC 返回電視';

  @override
  String get channelsTabsTime => '▲▼ 頻道     ▲ 分頁     ◀▶ 時間     OK 觀看     ';

  @override
  String get color => '顏色';

  @override
  String get channelsUsingIt => '使用它的頻道會改回預設圖示。';

  @override
  String get deleteThisIcon => '要刪除這個圖示嗎？';

  @override
  String get uploadImage => '上傳圖片…';

  @override
  String get pngJpgWebp => 'PNG、JPG、WebP、GIF 或 SVG。大圖會自動縮小到 512 px。';

  @override
  String get genericBadgesOnly => '這裡只有通用徽章。請在「我的圖示」下上傳真實的電視台標誌。';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => '使用這個徽章';

  @override
  String get preview => '預覽';

  @override
  String get shape => '形狀';

  @override
  String get callLettersUp => '台名縮寫（最多 5 個字元）';

  @override
  String iconFor(Object name) {
    return '$name 的圖示';
  }

  @override
  String get couldntReadThat => '無法讀取這張圖片。請換一張試試。';

  @override
  String get myIcons => '我的圖示';

  @override
  String get showLogos => '顯示標誌';

  @override
  String get badges => '徽章';

  @override
  String get builtIn => '內建';

  @override
  String get couldntMoveThe => '無法轉移設定';

  @override
  String get send => '傳送';

  @override
  String thisBacksUp(Object counterpartName) {
    return '這會立即備份你的個人檔案、頻道和設定，並在 $counterpartName 中開啟，$counterpartName 會在還原前先詢問你。這裡不會有任何變更。';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return '要將你的設定傳送到 $counterpartName 嗎？';
  }

  @override
  String get parentalControls => '家長監護';

  @override
  String get notNow => '稍後再說';

  @override
  String bringMySetup(Object counterpartName) {
    return '從 $counterpartName 把我的設定帶到這裡';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return '將我的設定轉移到 $counterpartName';
  }

  @override
  String get uninstallingEitherOne => '在轉移你想保留的設定之前解除安裝其中任何一個，都會刪除那份設定。';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName 和 $counterpartName 是兩個獨立的應用程式，各有自己的個人檔案、頻道和設定。';
  }

  @override
  String get thankYouFor => '感謝你支持 Nightingale TV！';

  @override
  String isAlsoOn(Object counterpartName) {
    return '這部裝置上也有 $counterpartName';
  }

  @override
  String get aboutThisInstall => '關於這次安裝';

  @override
  String couldntOpen(Object counterpartName) {
    return '無法開啟 $counterpartName。';
  }

  @override
  String get nothingIsSet => '這裡還沒有任何設定，因此沒有可轉移的內容。';

  @override
  String yourSetupIs(Object counterpartName) {
    return '你的設定正在傳送到 $counterpartName';
  }

  @override
  String get guide => '節目表';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n / $keysCount';
  }

  @override
  String get saving => '正在儲存…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '已選擇 $_checkedCount / $total';
  }

  @override
  String get channelOrGroup => '頻道或群組名稱';

  @override
  String get search => '搜尋';

  @override
  String get moveOkCheck => '▲▼ 移動    OK 勾選    ESC 返回';

  @override
  String chooseChannels(Object name) {
    return '選擇頻道：$name';
  }

  @override
  String get add => '新增';

  @override
  String get readingThePlaylist => '正在讀取播放清單…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return '目前：播放清單的節目表，$guideUrl';
  }

  @override
  String get leaveEmptyTo => '留空則使用播放清單指定的節目表';

  @override
  String get xmltvGuideAddress => 'XMLTV 節目表地址';

  @override
  String get guideOptional => '節目表（選填）';

  @override
  String get httpProviderExample =>
      'http://provider.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => '播放清單地址';

  @override
  String get playlist => '播放清單';

  @override
  String get myIptv => '我的 IPTV';

  @override
  String get useAnAddress => '改用地址';

  @override
  String get chooseAFile => '選擇檔案';

  @override
  String get chooseAnotherFile => '選擇其他檔案';

  @override
  String get moveOkSelectEscBack => '▲▼ 移動    OK 選取    ESC 返回';

  @override
  String edit(Object name) {
    return '編輯 $name';
  }

  @override
  String get addAnM3u => '新增 M3U 播放清單';

  @override
  String get m3uPlaylists => 'M3U 播放清單';

  @override
  String get xmltvGuides => 'XMLTV 節目表';

  @override
  String get anIptvPlaylist => 'IPTV 播放清單（網址或檔案），如果有的話，再加上 XMLTV 節目表。';

  @override
  String get theChannelsAnd => '伺服器調諧器（天線、有線電視盒或 IPTV）的頻道和節目表。';

  @override
  String readingSChannels(Object server) {
    return '正在讀取 $server 的頻道…';
  }

  @override
  String checkingLiveTv(Object server) {
    return '正在檢查 $server 直播電視…';
  }

  @override
  String get addALive => '新增直播電視來源';

  @override
  String get itsChannelsLeave => '它的頻道會從節目表、群組和最愛中移除。';

  @override
  String get renameSource => '重新命名來源';

  @override
  String get edit2 => '編輯';

  @override
  String get refreshNow => '立即重新整理';

  @override
  String get chooseChannels2 => '選擇頻道';

  @override
  String get playlistFile => '播放清單檔案';

  @override
  String get notRefreshedYet => '尚未重新整理';

  @override
  String refreshed(Object lastRefresh) {
    return '已於 $lastRefresh 重新整理';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return '上次重新整理失敗：$lastError';
  }

  @override
  String get refreshing => '正在重新整理…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · $keyCount / $channelsCount 個頻道';
  }

  @override
  String get noSourcesYet => '還沒有來源。';

  @override
  String get addSource => '新增來源';

  @override
  String get realBroadcastsAnd =>
      '在節目表中加入真實的廣播和 IPTV：你伺服器的直播電視，或附 XMLTV 節目表的 M3U 播放清單。它們的頻道排在你的頻道之後。';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return '未在串流。已使用 $runningCount / $streamLimit 路串流。';
  }

  @override
  String get savePort => '儲存連接埠';

  @override
  String get port => '連接埠';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => '調諧器';

  @override
  String get enterAPort => '請輸入連接埠號碼。';

  @override
  String pinFor(Object name) {
    return '$name 的 PIN';
  }

  @override
  String get letPlexFind => '讓 Plex 自動尋找';

  @override
  String get discovery => '探索';

  @override
  String get encoder => '編碼器';

  @override
  String nowAtOnce(Object streamLimit) {
    return '目前：同時 $streamLimit 路。在其他地方觀看的每個頻道算一路串流。';
  }

  @override
  String get streamsAtOnce => '同時串流數';

  @override
  String get quality => '畫質';

  @override
  String get lineups => '頻道列表';

  @override
  String get liveTvExport2 => '直播電視匯出';

  @override
  String get automaticDiscoveryIsnt =>
      '這部電腦無法使用自動探索。請在 Plex、Jellyfin 或 Emby 中透過地址新增調諧器。';

  @override
  String get anyoneOnYour => '家居網絡中的任何人都可以觀看這個頻道列表。';

  @override
  String get watchYourChannels =>
      '在家居網絡中用 Plex、Jellyfin、Emby 或任何 IPTV 應用程式觀看你的頻道。播放時 Nightingale TV 必須保持開啟。';

  @override
  String get offline => '離線';

  @override
  String get online => '在線';

  @override
  String get added => '已新增';

  @override
  String get chooseAServer => '選擇伺服器';

  @override
  String get whosSigningIn => '誰要登入？';

  @override
  String get openPlexTv => '開啟 plex.tv/link';

  @override
  String get waitingForThe => '正在等待代碼連結…';

  @override
  String get goToPlex => '請在手機或電腦上前往 plex.tv/link 並輸入這個代碼。';

  @override
  String get signInWith => '使用 Plex 登入';

  @override
  String get waitingForApproval => '正在等待核准…';

  @override
  String onYourPhone(Object label) {
    return '請在手機或電腦上開啟 $label → 你的個人檔案 → 快速連線，然後輸入這個代碼：';
  }

  @override
  String get quickConnect => '快速連線';

  @override
  String get signIn => '登入';

  @override
  String get password => '密碼';

  @override
  String get username => '用戶名稱';

  @override
  String signInTo2(Object name) {
    return '登入 $name';
  }

  @override
  String get differentServer => '其他伺服器';

  @override
  String get signInWithPassword => '使用密碼登入';

  @override
  String get quickConnectUse => '快速連線（使用手機）';

  @override
  String get connect => '連線';

  @override
  String get serverAddress => '伺服器地址';

  @override
  String get connectToYour => '連線到你的伺服器';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV 把你的影片變成全天候播出的頻道，並附有節目表。可連接 Jellyfin、Emby、Plex、YouTube，或 NAS 等 SMB 共用資料夾。隨意轉台，看看正在播什麼。';

  @override
  String get yourLibraryOn => '你的媒體庫，\n全天候播出。';

  @override
  String get welcomeToNightingale => '歡迎使用 Nightingale TV';

  @override
  String signInFor(Object name) {
    return '為 $name 登入';
  }

  @override
  String signInToAgain(Object name) {
    return '重新登入 $name';
  }

  @override
  String get addAServer => '新增伺服器';

  @override
  String foundNewPrograms(Object list) {
    return '找到了$list。新節目會在目前節目結束後立即在各自的頻道上開始播出。';
  }

  @override
  String get libraryRefreshed => '媒體庫已重新整理';

  @override
  String get nothingNew => '沒有新內容';

  @override
  String get yourChannelsAre => '你的頻道已是最新狀態。';

  @override
  String get refreshFailed => '重新整理失敗';

  @override
  String get moveOkSelectEscBackTo => '▲▼ 移動    OK 選取    ESC 返回電視';

  @override
  String get noPoolsYet => '還沒有素材組';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return '更新於 $fetchedAt $fetchedAt2';
  }

  @override
  String get libraryLabel => '媒體庫';

  @override
  String get account => '帳戶';

  @override
  String get watching => '觀看';

  @override
  String get exitNightingaleTv => '結束 Nightingale TV';

  @override
  String get signOut => '登出';

  @override
  String get yourChannelLineup => '你的頻道列表會被清除。自訂圖示會保留。';

  @override
  String get signOut2 => '要登出嗎？';

  @override
  String get fullScreenOn => '全屏幕開/關（F11）';

  @override
  String get nothingWasReset => '沒有重設任何內容';

  @override
  String get reset => '重設';

  @override
  String get rebuildsTheDefault =>
      '根據你的媒體庫重建預設頻道。你變更過的名稱、圖示和頻道號碼會被重設。你新增的頻道會保留。系統會先儲存一份備份，你可以在「備份與還原」中找回它們。';

  @override
  String get resetChannelLineup => '要重設頻道列表嗎？';

  @override
  String get resetChannelLineup2 => '重設頻道列表';

  @override
  String get refreshLibrary => '重新整理媒體庫';

  @override
  String get refreshingLibrary => '正在重新整理媒體庫…';

  @override
  String get servers => '伺服器';

  @override
  String get phoneRemote => '手機遙控器';

  @override
  String get profiles => '個人檔案';

  @override
  String get retroLook => '復古外觀';

  @override
  String get playback => '播放';

  @override
  String get switchProfile => '切換個人檔案';

  @override
  String get sleepTimer => '睡眠定時器';

  @override
  String get backToTv => '返回電視';

  @override
  String get removeAll => '全部移除';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return '配對於 $paired · 上次使用 $lastUsed';
  }

  @override
  String get noPhonesPaired => '還沒有配對的手機。';

  @override
  String get pairedPhones => '已配對的手機';

  @override
  String get blockedByThis => '被這部電腦的防火牆封鎖';

  @override
  String get someWiFi =>
      '有些 Wi-Fi 網絡會隔離裝置（稱為 AP 隔離或用戶端隔離）。如果手機仍然無法連線，請為你的 Wi-Fi 關閉這項設定。';

  @override
  String get thePhoneHas => '手機必須連線到與這部電視相同的 Wi-Fi，而不是訪客網絡或流動數據。';

  @override
  String get ifThePhone => '如果手機無法連線，可能是這部電腦的防火牆封鎖了它。請在這部電腦上開啟終端機並執行：';

  @override
  String get checkAgain => '重新檢查';

  @override
  String get thenChooseCheck => '然後選擇「重新檢查」。';

  @override
  String get thisComputersFirewall =>
      '這部電腦的防火牆阻止手機連線到遙控器。若要允許連線，請在這部電腦上開啟終端機並執行：';

  @override
  String get notConfirmedYet => '尚未確認 · 還沒有手機連線過';

  @override
  String get working => '正常';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return '正常 · 上次由 $name 使用，$lastUsed';
  }

  @override
  String get theRemoteIs => '遙控器已關閉。';

  @override
  String get orScanThe => '或用手機相機掃描 QR 碼。';

  @override
  String get andEnter => '並輸入  ';

  @override
  String get onYourPhoneOpen => '在你的手機上開啟';

  @override
  String get useYourPhoneAs =>
      '把手機當作遙控器：在手機上開啟一個網頁，就可以轉台、叫出節目表，或點一下頻道收看。不需要安裝任何東西。';

  @override
  String get everyPairedPhone => '所有已配對的手機都將無法當作遙控器，直到它們再次掃描這個畫面上的 QR 碼。';

  @override
  String get removeAllPhones => '要移除所有手機嗎？';

  @override
  String get thoseDidntMatch => '兩次輸入不一致。請再試一次。';

  @override
  String get enterTheSame => '請再次輸入相同的 4 位數字。';

  @override
  String get choose4Digits => '請設定 4 位數字。';

  @override
  String get thatPinIsnt => 'PIN 不正確。請再試一次。';

  @override
  String get clock => '時鐘';

  @override
  String get captions2 => '字幕';

  @override
  String get audio => '音訊';

  @override
  String get maximumStreamingBitrate => '最大串流位元率';

  @override
  String get converting => '轉換';

  @override
  String get afterThisLong =>
      '在這段時間內沒有按任何按鈕，Nightingale TV 會詢問是否還有人在看。如果一分鐘內沒有回應，它就會進入睡眠：播放停止，伺服器也會停止串流。設定了睡眠定時器時不會詢問。';

  @override
  String get askIfIm => '詢問我是否還在觀看';

  @override
  String get liveTvStill => '直播電視仍會顯示在儀表板上。';

  @override
  String get offWhatYou =>
      '關閉：你在這裡觀看的內容永遠不會改變伺服器上的播放次數、已觀看標記或續播位置，也不會顯示在它的儀表板上。';

  @override
  String get pauseSkipAnd => '暫停、跳過和重新播放目前的節目。關閉：每個頻道都依時間播放，就像全天候電視一樣。';

  @override
  String get pauseAndRewind => '暫停和倒帶';

  @override
  String get showsTheTime => '在畫面角落顯示時間。';

  @override
  String get onScreenClock => '屏幕時鐘';

  @override
  String get showACountdown => '在廣告開始前和節目回來前顯示倒數計時。';

  @override
  String get breakNotices => '廣告提示';

  @override
  String get theSizeOf => '所有節目和頻道中字幕的大小。';

  @override
  String get whileItsOn => '開啟時，環繞音效（Dolby、DTS）由這部裝置解碼，而不是直接傳送到擴音機。';

  @override
  String get evensOutThe => '觀看時自動平衡音量：調低吵鬧的廣告和節目，調高安靜的，你不必再伸手拿遙控器。';

  @override
  String get volumeLeveling => '音量平衡';

  @override
  String get pickALower =>
      '如果節目透過 Wi-Fi 或遠端連線播放時緩衝或卡頓，請選擇較低的位元率。「原始」永遠不會因為位元率而轉換。';

  @override
  String get connectedThroughPlex => '透過 Plex Relay 連線；畫質受限。';

  @override
  String get offNightingaleTv =>
      '關閉：Nightingale TV 一律以完整畫質播放你的原始檔案，伺服器不做額外工作。開啟：只有當節目或電影超過最大位元率，或原始檔案無法播放時，伺服器才會轉換。轉換會使用伺服器的處理器或顯示卡。廣告一律播放原始檔案。';

  @override
  String get transcodeOnlyIf => '僅在需要時轉碼（實驗性）';

  @override
  String get longerVideosAd => '較長的影片（廣告合集）會依章節或畫面變黑無聲的位置分割成個別的廣告。';

  @override
  String get videosOf5 => '5 秒到 3 分鐘的影片各算一個片段。';

  @override
  String get commercialsFillBreaks =>
      '廣告用於填補廣告時間。若是台標和「馬上回來」之類的片段，請將類型設為「過場片段」。';

  @override
  String get bumpersTakeAt => '除節目前外，過場片段最多占廣告時間的一半。超出這個長度的片段會被略過。';

  @override
  String stillToSplit(Object unsplit) {
    return '還有 $unsplit 待分割';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount 個長影片已分割成片段',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => '刪除素材組';

  @override
  String get addFolders => '新增資料夾…';

  @override
  String get libraryLabel2 => '媒體庫';

  @override
  String get noFoldersYet => '還沒有資料夾。';

  @override
  String get folders2 => '資料夾';

  @override
  String get type => '類型';

  @override
  String get poolName => '素材組名稱';

  @override
  String get commercialPool => '廣告素材組';

  @override
  String get itsVideosGo => '它的影片會回到你的一般頻道。原本從這裡取片段的廣告時間會改用所有素材組。';

  @override
  String get now => '現在';

  @override
  String get watch => '觀看';

  @override
  String get tuning2 => '正在轉台…';

  @override
  String get fullScreen => '全屏幕';

  @override
  String get noChannels => '沒有頻道';

  @override
  String get theirChannelsProgramming => '其頻道、節目時段和設定會被刪除，這部電視也會登出其伺服器。';

  @override
  String delete3(Object name) {
    return '要刪除 $name 嗎？';
  }

  @override
  String get giveTheProfile => '請為個人檔案命名。';

  @override
  String get deleteProfile => '刪除個人檔案';

  @override
  String get removePin => '移除 PIN';

  @override
  String get setAPin => '設定 PIN';

  @override
  String get changePin => '變更 PIN';

  @override
  String get noPinAnyone => '未設定 PIN。任何人都可以開啟這個個人檔案。';

  @override
  String get lockedThePin => '已鎖定。開啟這個個人檔案需要 PIN。';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith => '未分級的節目和電影會被排除。';

  @override
  String get allowedToWatch => '允許觀看';

  @override
  String get kid => '兒童';

  @override
  String get grownUp => '成人';

  @override
  String get whoItsFor => '用戶';

  @override
  String get color2 => '顏色';

  @override
  String get editProfile => '編輯個人檔案';

  @override
  String get newProfile => '新增個人檔案';

  @override
  String get watchingNow => '正在觀看';

  @override
  String get noPin => '無 PIN';

  @override
  String get pinLocked => 'PIN 已鎖定';

  @override
  String kid2(Object label, Object description) {
    return '兒童 · $label（$description）';
  }

  @override
  String get addProfile => '新增個人檔案';

  @override
  String get everyoneGetsTheir =>
      '每個人都有自己的伺服器登入、頻道和節目時段。兒童個人檔案只能看到符合其年齡分級的節目和電影。';

  @override
  String enterSPin(Object name) {
    return '請輸入 $name 的 PIN';
  }

  @override
  String get whosWatching => '誰在觀看？';

  @override
  String get moveOkChoose2 => '◀▶ 移動    OK 選擇';

  @override
  String get enterAGrownUps => '請輸入成人的 PIN。';

  @override
  String get grownUpsOnly => '僅限成人';

  @override
  String get yourChannelYour => '你的頻道，你的風格';

  @override
  String get testPattern => '測試圖';

  @override
  String get upNext8 => '稍後播放  ·  20:00';

  @override
  String get thisDevice => '這部裝置';

  @override
  String get glow => '光暈';

  @override
  String get curvature => '曲面';

  @override
  String get vignette => '暗角';

  @override
  String get mask => '蔭罩';

  @override
  String get lines => '線數';

  @override
  String get scanlines => '掃描線';

  @override
  String get customCrtStyle => '自訂 CRT 樣式';

  @override
  String accent(Object label) {
    return '強調色（$label）';
  }

  @override
  String get overlayTheme => '疊加層主題';

  @override
  String get crtEffect => 'CRT 效果';

  @override
  String get surround => '邊框';

  @override
  String get pictureShape => '畫面形狀';

  @override
  String get surroundImage => '邊框圖片';

  @override
  String get notAvailableOn => '這部裝置不支援';

  @override
  String get offTurnsOff => '「關閉」只會關閉這部裝置上的所有 CRT 效果。畫面形狀、邊框和疊加層主題保持不變。';

  @override
  String get effectsOnThis => '這部裝置上的效果';

  @override
  String get retroLook2 => '復古外觀';

  @override
  String get theseSettingsApply => '這些設定適用於執行這個應用程式的屏幕，不適用於直播電視匯出。';

  @override
  String get sameAsThe => '與個人檔案相同';

  @override
  String get streamsFromThis =>
      '來自這部伺服器的串流會維持在這個上限以下。個人檔案本身的上限（播放）仍然適用，以較低者為準。';

  @override
  String qualityLimit(Object name) {
    return '畫質上限 · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      '它的節目會從你的頻道中移除，頻道號碼保持不變。它上面的來源和廣告資料夾會顯示為找不到，直到你變更它們。';

  @override
  String remove3(Object name) {
    return '要移除 $name 嗎？';
  }

  @override
  String get signingOutOf => '登出這個個人檔案會變更它的主要伺服器。';

  @override
  String signedInAs(Object user) {
    return '已以 $user 身分登入';
  }

  @override
  String get mainServer => '主要伺服器';

  @override
  String get qualityLimit2 => '畫質上限';

  @override
  String get moveDown => '下移';

  @override
  String get moveUp => '上移';

  @override
  String get signInAgain => '重新登入';

  @override
  String get programsFromEvery =>
      '所有伺服器的節目會合併到同一個頻道列表。在多部伺服器上都有的作品，會從這個清單中第一個回應的伺服器播放（播放來源）；如果它停止回應，下一部會接手。';

  @override
  String get sleepingPressAny => '睡眠中 · 按任意按鈕繼續觀看';

  @override
  String goingToSleep(Object seconds) {
    return '$seconds 後進入睡眠';
  }

  @override
  String get goingToSleep2 => '即將進入睡眠';

  @override
  String goingToSleepIn(Object hint) {
    return '1 分鐘後進入睡眠。$hint';
  }

  @override
  String get pressAnyButton => '按任意按鈕繼續觀看';

  @override
  String goingToSleepIn0(Object padLeft) {
    return '0:$padLeft 後進入睡眠';
  }

  @override
  String get keepWatching => '繼續觀看';

  @override
  String get areYouStill => '你還在觀看嗎？';

  @override
  String sleepTimerMin(Object left) {
    return '睡眠定時器 · 剩餘 $left 分鐘';
  }

  @override
  String get whatsOnNow => '目前的節目沒有固定的結束時間。';

  @override
  String endOfThis(Object programEnd) {
    return '這個節目結束時 · $programEnd';
  }

  @override
  String get endOfThisProgram => '這個節目結束時';

  @override
  String get moveOkToggle => '▲▼◀▶ 移動    OK 切換    ESC 取消';

  @override
  String get usedWhenNo => '在沒有選擇節目時使用。也會用來篩選電影。';

  @override
  String get genres2 => '類型';

  @override
  String get includeMovies => '包含電影';

  @override
  String get add2 => '新增…';

  @override
  String get notFoundOn => '伺服器上找不到';

  @override
  String get collectionsFolders => '合集和資料夾';

  @override
  String get playOrder => '播放順序';

  @override
  String get clear => '清除';

  @override
  String get shows2 => '節目';

  @override
  String get pickSomethingTo => '請選擇要播放的內容。';

  @override
  String everyMovie(Object genreText) {
    return '所有$genreText電影';
  }

  @override
  String get everyMovie2 => '所有電影';

  @override
  String everyShow(Object genreText) {
    return '所有$genreText節目';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount或$last';
  }

  @override
  String decadesGenres(Object decades, Object genres) {
    return '$decades$genres';
  }

  @override
  String get settingUpYour => '正在設定你的頻道';

  @override
  String get couldntLoadYour => '無法載入你的媒體庫';

  @override
  String upNext(Object title) {
    return '稍後播放：$title';
  }

  @override
  String firstUp(Object title) {
    return '首先播放：$title';
  }

  @override
  String backTo(Object title) {
    return '返回 $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return '距離節目恢復還有 $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '距離$commercialBreakLabel還有 $left';
  }

  @override
  String startingWith(Object title) {
    return '從《$title》開始';
  }

  @override
  String upNext2(Object start) {
    return '稍後播放  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return '下一個 $start：$title';
  }

  @override
  String backOn(Object backOnAir) {
    return '$backOnAir 恢復播出';
  }

  @override
  String get offTheAir2 => '暫停播出';

  @override
  String get commercialBreak => '廣告時間';

  @override
  String tryingAgainAt(Object end) {
    return '將於 $end 重試';
  }

  @override
  String get exitFullScreen => '結束全屏幕';

  @override
  String get guide2 => '節目表';

  @override
  String thereIsNo(Object number) {
    return '沒有頻道 $number';
  }

  @override
  String get liveChannelsCant => '直播頻道無法暫停';

  @override
  String get curvatureAndGlow => '曲面和光暈已關閉：這部裝置效能不足';

  @override
  String get pressBackAgain => '再按一次返回鍵結束';

  @override
  String backAt(Object backAt) {
    return '$backAt 回來';
  }

  @override
  String get live => '直播';

  @override
  String get newLabel => '新';

  @override
  String nowPlayingOn(Object name) {
    return '$name 正在播放';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => '已暫停';

  @override
  String get seekBar => '進度列';

  @override
  String get live2 => '直播';

  @override
  String get forward30 => '快進 30 秒';

  @override
  String get pause => '暫停';

  @override
  String get play => '播放';

  @override
  String get back10 => '倒帶 10 秒';

  @override
  String get restart => '從頭播放';

  @override
  String somethingWentWrong2(Object status) {
    return '發生問題（$status）。';
  }

  @override
  String get thatIsTooBig => '內容太大。';

  @override
  String get notFound => '找不到。';

  @override
  String get youCantDo => '你不能這樣做。';

  @override
  String get cantReachThe => '無法連線到伺服器。請檢查它是否正在執行。';

  @override
  String signOut3(Object userName) {
    return '登出 $userName';
  }

  @override
  String get changePassword => '變更密碼';

  @override
  String get users => '用戶';

  @override
  String get backups2 => '備份';

  @override
  String get serverAndSign => '伺服器和登入';

  @override
  String get channels5 => '頻道';

  @override
  String get thatProfileIsntYours => '這個個人檔案不是你的，或者已不存在。';

  @override
  String get download => '下載';

  @override
  String get itReplacesThe => '它會取代這裡的個人檔案、頻道和設定。';

  @override
  String get restoreThisBackup => '要還原這個備份嗎？';

  @override
  String get restoring => '正在還原…';

  @override
  String get restoreFromAFile => '從檔案還原…';

  @override
  String get downloadABackup => '立即下載備份';

  @override
  String get aBackupHoldsThe => '備份包含個人檔案、頻道、節目時段、標誌、匯出設定和用戶帳戶（絕不包含密碼或登入權杖）。';

  @override
  String get restoredTheBackup2 => '已還原備份。';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return '來自 $whenValue（$device）：$profiles。它會取代這裡的個人檔案、頻道和設定。';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return '下次播出：$start $end';
  }

  @override
  String programsInIts(Object total) {
    return '播放清單中有 $total 個節目。';
  }

  @override
  String get workingOutWhat => '正在決定播放內容…';

  @override
  String get later => '較晚';

  @override
  String get earlier => '較早';

  @override
  String get eachAiringPlays => '每次播出都會依序播放每個位置的下一集，如果還有剩餘時間就從頭開始。';

  @override
  String get aLineupOf => '節目列表';

  @override
  String get whatItPlays2 => '播放內容';

  @override
  String get onlyPartOf => '僅在一年中的部分時間';

  @override
  String get runsPastMidnight => '跨過午夜延續到隔天。';

  @override
  String get whenLabel => '時間';

  @override
  String get aNewChannelFor => '為這個節目時段新增的頻道';

  @override
  String get channel3 => '頻道';

  @override
  String get blocks => '節目時段';

  @override
  String get newBlock => '新增節目時段';

  @override
  String get programmingBlock => '節目時段';

  @override
  String get aBlockTakes => '節目時段會在固定時間接管頻道：例如「週六早晨卡通」，每週六 7:00 至 12:00。';

  @override
  String get overlayTheme2 => '疊加層主題';

  @override
  String get crtEffect2 => 'CRT 效果';

  @override
  String get chooseSurroundImage => '選擇邊框圖片…';

  @override
  String get surround2 => '邊框';

  @override
  String get pictureShape2 => '畫面形狀';

  @override
  String get chooseOfflineImage => '選擇離線圖片…';

  @override
  String get fillerPool2 => '填補素材組';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String get slotLength2 => '時段長度';

  @override
  String get everyProgramStarts => '每個節目都準點開始。每個時段的剩餘部分由填補補足。';

  @override
  String get itLeavesThe => '它會離開頻道列表。';

  @override
  String get itsProgrammingBlocks => '它的節目時段也會被移除。';

  @override
  String get removeThisChannel => '移除這個頻道';

  @override
  String get channelLogo2 => '頻道標誌';

  @override
  String get editCustomBreaks => '編輯自訂廣告時間…';

  @override
  String get musicChannelsOnlyShuffle => '音樂頻道只能隨機播放，且不會連續播放同一位藝人的作品。';

  @override
  String get playOrder2 => '播放順序';

  @override
  String get saveWhatIt => '儲存播放內容';

  @override
  String get canBeA => '可以作為節目最新劇集的主頻道。';

  @override
  String get hiddenFromThe => '在節目表中隱藏';

  @override
  String get chooseIcon => '選擇圖示…';

  @override
  String get icon => '圖示';

  @override
  String get saveNameAnd => '儲存名稱和頻道號碼';

  @override
  String get aChannelAlready => '已占用這個頻道號碼的頻道會與這個頻道互換位置。';

  @override
  String get number3 => '頻道號碼';

  @override
  String get nameAndNumber => '名稱和頻道號碼';

  @override
  String get decadesNoneAny => '年代（不選：任何）';

  @override
  String get genresNoneAny => '類型（不選：任何）';

  @override
  String musicVideos(Object musicVideos) {
    return '音樂影片（$musicVideos）';
  }

  @override
  String songs(Object songs) {
    return '歌曲（$songs）';
  }

  @override
  String get newMusicChannel => '新增音樂頻道';

  @override
  String get aNightlySlot => '每晚在各節目主頻道上播出節目最新劇集的時段。';

  @override
  String get mainSettings => '主要設定';

  @override
  String get glow2 => '光暈';

  @override
  String get curvature2 => '曲面';

  @override
  String get vignette2 => '暗角';

  @override
  String get mask2 => '蔭罩';

  @override
  String get lines2 => '線數';

  @override
  String get scanlines2 => '掃描線';

  @override
  String get customCrtStyle2 => '自訂 CRT 樣式';

  @override
  String accent2(Object label) {
    return '強調色（$label）';
  }

  @override
  String get hidden => '已隱藏';

  @override
  String get blockChannel2 => '節目時段頻道';

  @override
  String live3(Object source) {
    return '直播 · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return '$shownCount / $channelsCount 個頻道';
  }

  @override
  String get searchChannels => '搜尋頻道';

  @override
  String get resetLineup => '重設頻道列表';

  @override
  String get everyChannelEdit =>
      '所有頻道編輯都會被捨棄，並重新產生預設頻道列表。你新增的頻道會保留。系統會先儲存一份備份。';

  @override
  String get musicChannel => '音樂頻道';

  @override
  String get newBlockChannel => '新增節目時段頻道';

  @override
  String get channelsOwnPlans => '頻道自己的方案';

  @override
  String get setTypeBumpers => '設定類型：過場片段';

  @override
  String get setTypeCommercials => '設定類型：廣告';

  @override
  String get chooseFolders2 => '選擇資料夾…';

  @override
  String get plansThatDrew => '原本從它取片段的方案會改用所有素材組，它的影片也會回到頻道中。';

  @override
  String get renamePool => '重新命名素材組';

  @override
  String get poolActions => '素材組動作';

  @override
  String get aPoolIs =>
      '素材組是一組媒體庫資料夾，其中的影片用來填補廣告時間，而不會當作節目播出。素材組的類型決定它的片段是當作廣告播放，還是當作過場片段用於廣告時間的開頭和結尾。';

  @override
  String get pools2 => '素材組';

  @override
  String get breaks => '廣告時間';

  @override
  String clipsInAll(Object clips) {
    return '所有廣告素材組中共有 $clips 個片段。';
  }

  @override
  String get tunerAddress => '調諧器地址';

  @override
  String get changePort => '變更連接埠';

  @override
  String get exportThisProfile => '匯出這個個人檔案';

  @override
  String get letsPlexAnd => '讓 Plex 等應用程式在網絡上找到調諧器。';

  @override
  String get discovery2 => '探索';

  @override
  String get encoder2 => '編碼器';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return '自動：這部機器上為 $streamLimitInUse。';
  }

  @override
  String get streamsAtOnce2 => '同時串流數';

  @override
  String get quality2 => '畫質';

  @override
  String get settings => '設定';

  @override
  String get eachExportedProfile =>
      '每個匯出的個人檔案都是 Plex、Jellyfin 或 Emby 的一個調諧器。請在它們的 DVR 設定中透過地址新增。';

  @override
  String get channelsInThis => '這個群組中的頻道';

  @override
  String get chooseChannels3 => '選擇頻道…';

  @override
  String channels7(Object channelIds) {
    return '$channelIds 個頻道';
  }

  @override
  String get itsChannelsStay => '它的頻道仍保留在頻道列表中。';

  @override
  String get renameGroup => '重新命名群組';

  @override
  String get groupActions => '群組動作';

  @override
  String get yourGroup => '你的群組';

  @override
  String get theOrderOf => '節目表中分頁的順序，以及要顯示哪些。';

  @override
  String get guideTabs => '節目表分頁';

  @override
  String get make => '建立';

  @override
  String get breaksBetweenPrograms => '節目之間的廣告時間';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '中間 $mids 次廣告',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return '$songs 首歌曲';
  }

  @override
  String get newEpisode => '新劇集';

  @override
  String get noChannelsYet2 => '還沒有頻道。';

  @override
  String get noGuide => '沒有節目表';

  @override
  String get noneShown => '全部隱藏';

  @override
  String get allShown => '全部顯示';

  @override
  String channels8(Object name) {
    return '$name：頻道';
  }

  @override
  String get orChooseA => '或選擇節目表檔案…';

  @override
  String get emptyThePlaylists => '留空：使用播放清單本身的節目表（如果有）。';

  @override
  String get guideAddressXmltv => '節目表地址（XMLTV，選填）';

  @override
  String get orChooseAPlaylist => '或選擇播放清單檔案…';

  @override
  String get leaveEmptyToKeep => '留空則保留播放清單檔案。';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => '檔案';

  @override
  String get itsChannelsJoin => '這個個人檔案登入該伺服器期間，它的頻道會加入進來。';

  @override
  String guide3(Object guideFile) {
    return '節目表：$guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return '播放清單檔案：$playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return '已於 $last $context 重新整理';
  }

  @override
  String get itsChannelsLeaveThe => '它的頻道會從頻道列表、群組和最愛中移除。';

  @override
  String read(Object fetched, Object context) {
    return '已於 $fetched $context 讀取。';
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
    return '$series 個節目 · $episodes 集 · $movies 部電影 · $songs 首歌曲 · $musicVideos 個音樂影片 · $commercials 個廣告影片';
  }

  @override
  String fromAs(Object server, Object user) {
    return '來自 $server，身分為 $user。';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name：媒體庫';
  }

  @override
  String get removeThePin => '移除 PIN';

  @override
  String get pinOptional => 'PIN（選填）';

  @override
  String get newPinLeave => '新 PIN（留空則保持不變）';

  @override
  String colour(Object i) {
    return '顏色 $i';
  }

  @override
  String get colour2 => '顏色';

  @override
  String get itsChannelsBlocks => '其頻道、節目時段和設定會被刪除。系統會先儲存一份備份。';

  @override
  String get exported => '已匯出';

  @override
  String kid3(Object label) {
    return '兒童 · $label';
  }

  @override
  String get noProfilesAre => '還沒有指派給你的個人檔案。請聯絡管理員。';

  @override
  String signIn2(Object name) {
    return '為 $name 登入';
  }

  @override
  String get theLibraryIs => '正在重新讀取媒體庫；完成後，伺服器的節目會加入頻道。';

  @override
  String get itsLibraryIs => '正在讀取它的媒體庫並建立頻道。這需要一兩分鐘。';

  @override
  String isSignedIn(Object name) {
    return '$name 已登入。';
  }

  @override
  String get couldntDoThat => '無法完成操作。請再試一次。';

  @override
  String get itsChannelsStayIt => '它的頻道會保留；需要登入後才能播放。';

  @override
  String signOut4(Object name) {
    return '要登出 $name 嗎？';
  }

  @override
  String get signingIn => '正在登入…';

  @override
  String wasSignedIn(Object server, Object user) {
    return '曾以 $user 身分登入 $server。請重新登入。';
  }

  @override
  String signedInTo(Object server, Object user) {
    return '已以 $user 身分登入 $server。';
  }

  @override
  String get profileName => '個人檔案名稱';

  @override
  String get nameAProfile => '為個人檔案命名並登入你的媒體伺服器，系統就會建立並匯出它的頻道。';

  @override
  String get chooseABackup => '選擇備份檔案…';

  @override
  String get moveAHousehold => '從電視或其他伺服器將家庭設定轉移到這裡：其個人檔案、頻道、節目時段、標誌和匯出設定。';

  @override
  String get restoreABackup => '還原備份';

  @override
  String get theServerIs => '伺服器正在啟動…';

  @override
  String get itsProgramsLeaveThe =>
      '它的節目會從頻道中移除，頻道號碼保持不變。它上面的來源和廣告資料夾會顯示為找不到，直到你變更它們。';

  @override
  String addAServerTo(Object name) {
    return '為 $name 新增伺服器';
  }

  @override
  String servers2(Object name) {
    return '$name：伺服器';
  }

  @override
  String get makeAccountAnd => '建立帳戶並登入';

  @override
  String get setPasswordAnd => '設定密碼並登入';

  @override
  String get passwordAgain => '再次輸入密碼';

  @override
  String get atLeast8 => '至少 8 個字元。';

  @override
  String get userName => '用戶名稱';

  @override
  String get adminAccount => '管理員帳戶';

  @override
  String get makeTheFirst => '建立第一個管理員帳戶。';

  @override
  String get setANew => '為管理員帳戶設定新密碼。';

  @override
  String get thisSetupLink => '這個設定連結已使用過，或者來自先前的啟動。請從伺服器記錄中開啟最新的連結，或者直接登入。';

  @override
  String get thePasswordsDont => '兩次輸入的密碼不一致。';

  @override
  String get newPasswordAgain => '再次輸入新密碼';

  @override
  String get newPassword => '新密碼';

  @override
  String get currentPassword => '目前的密碼';

  @override
  String get passwordChangedYour => '密碼已變更。你的其他瀏覽器已登出。';

  @override
  String get theNewPasswords => '兩次輸入的新密碼不一致。';

  @override
  String get theyAreSigned => '他們已登出，且無法再次登入。';

  @override
  String get cantSignIn => '無法登入；已在所有地方登出。';

  @override
  String get usersReachOnly => '用戶只能存取下面的個人檔案。';

  @override
  String get adminsCanDo => '管理員可以對所有個人檔案進行任何操作。';

  @override
  String get admin => '管理員';

  @override
  String get user => '用戶';

  @override
  String get leaveEmptyToKeepIt => '留空則保持不變。設定新密碼會讓其在其他地方登出。';

  @override
  String get needsAPassword => '需要設定密碼才能登入。';

  @override
  String get addUser => '新增用戶';

  @override
  String get needsAPassword2 => '需要密碼';

  @override
  String get noProfiles => '沒有個人檔案';

  @override
  String get pad => '填補';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  $clips 個片段';
  }

  @override
  String get clipsFrom2 => '片段來源';

  @override
  String get channelsUsingItGo => '使用它的頻道會改回內建圖示。';

  @override
  String get uploading => '正在上傳…';

  @override
  String get noneOfYourShows => '你伺服器上的節目都沒有標誌圖片。';

  @override
  String get chooseAnIcon => '選擇圖示';

  @override
  String get couldntCopySelect => '無法複製。請選取文字後手動複製。';

  @override
  String copy(Object label) {
    return '複製$label';
  }

  @override
  String get home => '首頁';

  @override
  String get thereIsNoPage => '這裡沒有頁面。';

  @override
  String get enterPin => '輸入 PIN';

  @override
  String get thisIsA => '這是兒童個人檔案。變更其設定需要成人的 PIN。';

  @override
  String hasAPin(Object name) {
    return '$name 設有 PIN。';
  }

  @override
  String get profile => '個人檔案';

  @override
  String get changingAKid => '變更兒童個人檔案的設定需要成人個人檔案的 PIN。';

  @override
  String get aGrownUps => '成人的 PIN';

  @override
  String get thisProfile => '這個個人檔案';

  @override
  String movies3(Object movies) {
    return '電影（$movies）';
  }

  @override
  String get shows3 => '節目';

  @override
  String remove4(Object label) {
    return '移除$label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · 伺服器上找不到';
  }

  @override
  String get dragACollection => '將合集、資料夾或電影拖曳到這裡，或使用它的「新增」按鈕。';

  @override
  String get collectionsAndFolders => '合集和資料夾';

  @override
  String add3(Object name) {
    return '新增 $name';
  }

  @override
  String added2(Object name) {
    return '已新增 $name';
  }

  @override
  String get dragToAdd => '拖曳以新增';

  @override
  String get languageAutomatic => '自動';

  @override
  String dateAtTime(String date, String time) {
    return '$date $time';
  }

  @override
  String connectingTo(Object server) {
    return '正在連線到 $server…';
  }

  @override
  String get yourServerLower => '你的伺服器';

  @override
  String noServerFoundAt(Object address) {
    return '在 $address 找不到 Jellyfin、Emby 或 Plex 伺服器。';
  }

  @override
  String captionsValue(Object name) {
    return '字幕：$name';
  }

  @override
  String channelOverrides(int count) {
    return '$count 個頻道有自己的設定（頻道和圖示）。';
  }

  @override
  String noShowLogosOn(Object kind) {
    return '你的 $kind 伺服器上的節目都沒有標誌圖片。';
  }

  @override
  String fileChosen(Object name) {
    return '檔案：$name';
  }

  @override
  String get theOneChosenBefore => '先前選擇的那個';

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
      other: '正在向 $viewers 位觀眾串流頻道 $channels。已使用 $running / $limit 路串流。',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name：匯出這個頻道列表';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name（兒童）：匯出這個頻道列表';
  }

  @override
  String encoderInUse(Object encoder) {
    return '正在使用的編碼器：$encoder';
  }

  @override
  String get checking => '正在檢查…';

  @override
  String countShows(int count) {
    return '$count 個節目';
  }

  @override
  String countEpisodes(int count) {
    return '$count 集';
  }

  @override
  String countMovies(int count) {
    return '$count 部電影';
  }

  @override
  String countSongs(int count) {
    return '$count 首歌曲';
  }

  @override
  String countMusicVideos(int count) {
    return '$count 個音樂影片';
  }

  @override
  String countHidden(int count) {
    return '$count 個已隱藏';
  }

  @override
  String countOnTheAir(int count) {
    return '$count 個播出中';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個節目時段',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name：$stats';
  }

  @override
  String get yourServerHasNothingNew =>
      '自上次重新整理以來，你的伺服器沒有新內容。伺服器掃描新檔案後，它們才會出現在這裡：如果你剛新增了檔案，請先在伺服器上掃描媒體庫，然後再重新整理。';

  @override
  String serverHasNothingNew(Object server) {
    return '自上次重新整理以來，$server 沒有新內容。伺服器掃描新檔案後，它們才會出現在這裡：如果你剛新增了檔案，請先在伺服器上掃描媒體庫，然後再重新整理。';
  }

  @override
  String get updateWatchStatusOnYourServer => '更新伺服器上的觀看狀態';

  @override
  String get updateWatchStatusOnYourServers => '更新各伺服器上的觀看狀態';

  @override
  String updateWatchStatusOn(Object name) {
    return '更新 $name 上的觀看狀態';
  }

  @override
  String get poolFoldersBumpers =>
      '這些資料夾（及其子資料夾）中的每部影片都會用於廣告時間的開頭和結尾，永遠不會當作節目播出。';

  @override
  String get poolFoldersCommercials =>
      '這些資料夾（及其子資料夾）中的每部影片都會用來填補廣告時間，永遠不會當作節目播出。';

  @override
  String get newPin => '新 PIN';

  @override
  String namedPin(Object name) {
    return '$name 的 PIN';
  }

  @override
  String get qualitySameAsProfile => '畫質：與個人檔案相同';

  @override
  String qualityValue(Object limit) {
    return '畫質：$limit';
  }

  @override
  String onChannel(Object channel) {
    return '在 $channel';
  }

  @override
  String get aChannelThatIsGone => '已不存在的頻道';

  @override
  String liveFrom(Object source) {
    return '來自 $source 的直播';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return '標誌 $mode · 首播 $premieres';
  }

  @override
  String get offLower => '關閉';

  @override
  String streamingNow(Object count) {
    return '目前有 $count 路在串流。';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return '目前有 $count 路在串流 · 使用 $encoder 編碼。';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · $chosen / $channels 個頻道';
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
    return '來自 $when（$device）：$profiles。$channels 個頻道、$blocks 個節目時段、$logos 個標誌。';
  }

  @override
  String get backupSavedFirst => '系統會先備份這裡現有的內容。';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個新節目',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 集新劇集',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部新電影',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首新歌曲',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return '播放$list。';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個新頻道',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => '幼兒';

  @override
  String get kidRatingYoungDescription => 'TV-Y 和 TV-Y7';

  @override
  String get kidRatingKids => '兒童';

  @override
  String get kidRatingKidsDescription => '最高 TV-G 和 G';

  @override
  String get kidRatingOlder => '大齡兒童';

  @override
  String get kidRatingOlderDescription => '最高 TV-PG 和 PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個個人檔案',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個節目時段',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個時段',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '其資料夾中有 $count 部影片',
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
  String get liveLabel => '直播';

  @override
  String get aMidRollOpens =>
      '節目中的廣告時間以過場片段開始和結束，節目後的廣告時間以過場片段開始，節目前的廣告時間以過場片段結束。其餘時間由廣告填補。';

  @override
  String get programsPlayBack => '節目連續播放，沒有廣告時間。';

  @override
  String get everyShowFills => '每個節目都占滿半小時時段（較長的節目占一小時或更長），因此節目表始終依整點進行。';

  @override
  String get chooseHowLong => '選擇每次廣告時間的長度、節目中插播廣告的頻率，以及每次廣告時間從哪個素材組取片段。';

  @override
  String get copyAction => '複製';

  @override
  String get channelKidsZone => '兒童天地';

  @override
  String get channelToonTv => '卡通台';

  @override
  String get channelLaughTrack => '歡樂喜劇';

  @override
  String get channelFamilyRoom => '闔家歡';

  @override
  String get channelAdventureTv => '冒險頻道';

  @override
  String get channelSciFiFantasy => '科幻奇幻';

  @override
  String get channelMysteryTv => '懸疑頻道';

  @override
  String get channelDramaCentral => '戲劇館';

  @override
  String get channelCrimeJustice => '警匪犯罪';

  @override
  String get channelThrillTv => '驚悚頻道';

  @override
  String get channelFrightNight => '午夜驚魂';

  @override
  String get channelRomanceTv => '浪漫愛情';

  @override
  String get channelDiscoveryZone => '紀實天地';

  @override
  String get channelMusicTv => '音樂台';

  @override
  String get channelRealityTv => '真人騷';

  @override
  String get channelGameShowTv => '遊戲綜藝';

  @override
  String get channelFrontierTv => '西部片頻道';

  @override
  String get channelHistoryTv => '歷史頻道';

  @override
  String get channelSportsTv => '體育台';

  @override
  String get channelNewsTv => '新聞台';

  @override
  String get channelAllShows => '全部節目';

  @override
  String get channelMovieChannel => '電影台';

  @override
  String get channelMusicVideos => '音樂 MV';

  @override
  String get channelMusicRadio => '音樂電台';

  @override
  String get genreActionAdventure => '動作冒險';

  @override
  String get genreSciFiFantasy => '科幻奇幻';

  @override
  String get genreKids => '兒童';

  @override
  String get genreAnimation => '動畫';

  @override
  String get genreComedy => '喜劇';

  @override
  String get genreFamily => '家庭';

  @override
  String get genreDrama => '劇情';

  @override
  String get genreCrime => '犯罪';

  @override
  String get genreMystery => '懸疑';

  @override
  String get genreThriller => '驚悚';

  @override
  String get genreHorror => '恐怖';

  @override
  String get genreRomance => '愛情';

  @override
  String get genreDocumentary => '紀錄片';

  @override
  String get genreMusic => '音樂';

  @override
  String get genreReality => '真人騷';

  @override
  String get genreGameShows => '益智節目';

  @override
  String get genreWestern => '西部';

  @override
  String get genreWar => '戰爭';

  @override
  String get genreHistory => '歷史';

  @override
  String get genreNews => '新聞';

  @override
  String get genreTalk => '清談';

  @override
  String get genreSoap => '處境劇';

  @override
  String get genreSports => '體育';

  @override
  String get genreClassical => '古典';

  @override
  String get genreElectronic => '電子';

  @override
  String get genreCountry => '鄉村';

  @override
  String get genreLatin => '拉丁';

  @override
  String get genreSoundtrack => '原聲帶';

  @override
  String get genreOldies => '老歌';

  @override
  String get genreDance => '舞曲';

  @override
  String get genreFolk => '民謠';

  @override
  String get genreAlternative => '另類';

  @override
  String get blockDaytime => '白天時段';

  @override
  String get blockMovieNight => '電影之夜';

  @override
  String get blockNewEpisodes => '新劇集';

  @override
  String get kindShow => '節目';

  @override
  String get kindShows => '節目';

  @override
  String get kindMovies => '電影';

  @override
  String get kindMusicVideos => '音樂影片';

  @override
  String get kindRadio => '電台';

  @override
  String genreMovies(Object genre) {
    return '$genre電影';
  }

  @override
  String genreMusicVideos(Object genre) {
    return '$genre音樂影片';
  }

  @override
  String genreRadio(Object genre) {
    return '$genre電台';
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
  String get lateNightTitle => '深夜時段';

  @override
  String get languageTitle => '語言';

  @override
  String get stillWatchingOff => '關閉';

  @override
  String afterHours(int hours) {
    return '$hours 小時後';
  }

  @override
  String get bitrateOriginal => '原始（無限制）';

  @override
  String get bitrate40 => '40 Mbps · 4K';

  @override
  String get bitrate20 => '20 Mbps · 1080p 高';

  @override
  String get bitrate12 => '12 Mbps · 1080p';

  @override
  String get bitrate8 => '8 Mbps · 1080p';

  @override
  String get bitrate4 => '4 Mbps · 720p';

  @override
  String get noSuchLanguage => '沒有這種語言。';

  @override
  String get languageField => '語言';

  @override
  String get remotePageTitle => 'Nightingale TV 遙控器';

  @override
  String get remotePairTitle => '與電視配對';

  @override
  String get remotePairHelp => '掃描電視上的 QR 碼（選單 → 手機遙控器），或輸入那裡顯示的 6 位數代碼。';

  @override
  String get remotePairingCode => '配對代碼';

  @override
  String get remotePair => '配對';

  @override
  String get remoteConnecting => '正在連線…';

  @override
  String get remoteTabRemote => '遙控器';

  @override
  String get remoteUp => '上';

  @override
  String get remoteLeft => '左';

  @override
  String get remoteRight => '右';

  @override
  String get remoteDown => '下';

  @override
  String get remoteInfo => '資訊';

  @override
  String get remoteLastCh => '上個頻道';

  @override
  String get remoteCc => '字幕';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => '確定';

  @override
  String get remoteRemovedFromTv => '這支手機已從電視中移除。請掃描 QR 碼重新配對。';

  @override
  String get remoteCouldntPair => '無法配對。請再試一次。';

  @override
  String get remoteCantReachWifi => '無法連線到電視。這支手機連線的是同一個 Wi-Fi 嗎？';

  @override
  String get remoteEnterDigits => '請輸入電視上顯示的 6 位數字。';

  @override
  String get remoteCantReachTv => '無法連線到電視';

  @override
  String get remotePickProfile => '請用方向鍵和 OK 選擇個人檔案。';

  @override
  String remoteWatching(Object name) {
    return '正在觀看：$name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name（兒童）';
  }

  @override
  String get transferPageTitle => 'Nightingale TV 備份';

  @override
  String get transferIntro => '在這部電視和這部裝置之間傳送備份。傳送期間請保持電視上的對話框開啟。';

  @override
  String get transferDownload => '下載備份';

  @override
  String get transferDownloadHelp => '電視目前設定的備份：個人檔案、頻道、節目時段和設定。';

  @override
  String get transferRestoreTitle => '從檔案還原';

  @override
  String transferRestoreHelp(Object file) {
    return '傳送一個 $file 檔案到電視。在電視上確認之前不會有任何變更。';
  }

  @override
  String get transferChoose => '選擇備份檔案…';

  @override
  String get transferFoot => '只有家居網絡中的裝置才能開啟這個頁面。';

  @override
  String transferSending(Object name) {
    return '正在傳送 $name…';
  }

  @override
  String get transferCheckTv => '請在電視上完成操作。';

  @override
  String get transferClosed => '電視已關閉這個頁面。請從「備份與還原」中重新開啟。';

  @override
  String get transferCouldntTake => '電視無法接收這個檔案。';

  @override
  String get transferCouldntReach => '無法連線到電視。電視上還顯示著 QR 碼嗎？';

  @override
  String get includeShows => '包含節目';

  @override
  String get everyShow2 => '所有節目';

  @override
  String get decades => '年代';

  @override
  String get decadesHeading => '年代';

  @override
  String decadeYears(Object decade) {
    return '$decade年代';
  }

  @override
  String get channelActionTv => '動作頻道';

  @override
  String get channelSciFiTv => '科幻頻道';

  @override
  String get channelFantasyTv => '奇幻頻道';

  @override
  String get channelMysteryThrills => '懸疑驚悚';

  @override
  String get genreAction => '動作';

  @override
  String get genreAdventure => '冒險';

  @override
  String get genreSciFi => '科幻';

  @override
  String get genreFantasy => '奇幻';

  @override
  String get genreThrillerMystery => '驚悚懸疑';

  @override
  String decadeTv(Object decade) {
    return '$decade節目';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$decade$genre節目';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return '$decade$genre電影';
  }

  @override
  String get errorReports => '錯誤報告';

  @override
  String get sendErrorReportsFrom => '從這部裝置傳送錯誤報告';

  @override
  String get errorReportsExplain =>
      '發生問題時，Nightingale TV 會傳送一份簡短報告給開發者：錯誤資訊、應用程式版本、裝置類型，以及最近的幾個畫面和頻道號碼。伺服器地址、密碼和金鑰、名稱和檔案路徑會在傳送前移除。節目標題和你觀看的內容永遠不會傳送。';

  @override
  String get errorReportsOff => '關閉後，這部裝置不會傳送任何內容；等待傳送的報告會被刪除。';

  @override
  String get recentReports => '最近的報告';

  @override
  String get reportKindTest => '測試';

  @override
  String get reportKindVideo => '影片報告';

  @override
  String get reportKindError => '錯誤';

  @override
  String get reportKindExit => '意外結束';

  @override
  String get reportKindSlowStart => '啟動緩慢';

  @override
  String get errorReportsAutomatic =>
      '應用程式意外結束或啟動緩慢時，也會自動傳送一份報告，包含之前的畫面、頻道、啟動步驟和記憶體數據。';

  @override
  String get sendATestReport => '傳送測試報告';

  @override
  String lastReportId(String id) {
    return '最近一次報告 ID：$id';
  }

  @override
  String get noReportSentYet => '這部裝置還沒有傳送過報告。';

  @override
  String get quoteReportId => '向開發者回報問題時，請提供這個 ID。';

  @override
  String testReportSent(String id) {
    return '測試報告已傳送：$id';
  }

  @override
  String get testReportNotSent => '無法傳送測試報告。請稍後再試。';

  @override
  String get reportsNotInBuild =>
      '這個版本的 Nightingale TV 不包含錯誤報告功能，因此永遠不會傳送任何內容。';

  @override
  String get sendAVideoReport => '傳送影片報告';

  @override
  String get videoReportHelp =>
      '如果畫面看起來不對，請按這裡，然後返回某個頻道。畫面播放 10 秒後會傳送報告，報告 ID 會顯示在電視屏幕上。';

  @override
  String get videoReportArmed => '現在請返回某個頻道。畫面播放 10 秒後會傳送影片報告。';

  @override
  String get videoReportTooSoon => '不到一分鐘前剛傳送過影片報告。請稍後再試。';

  @override
  String videoReportSent(String id) {
    return '影片報告已傳送：$id';
  }

  @override
  String get videoReportsExplain =>
      '影片報告會傳送有關裝置、影片及其解碼器的資訊、畫面的粗略顏色格線以及應用程式本身最近的記錄；絕不會傳送你所觀看內容的影像。每次應用程式更新後，頻道播放 10 秒時會傳送一次。';

  @override
  String get unlockNightingaleTv => '解鎖 Nightingale TV';

  @override
  String trialDaysLeftMenu(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '免費試用還剩 $count 天',
    );
    return '$_temp0';
  }

  @override
  String get purchasePending => '購買處理中';

  @override
  String get freeForDaysTitle => '免費 14 天';

  @override
  String welcomeTrialPrice(String price) {
    return 'Nightingale TV 可免費使用 14 天。之後，一次支付 $price 即可永久解鎖，並支持這個項目。';
  }

  @override
  String get welcomeTrial => 'Nightingale TV 可免費使用 14 天。之後，一次購買即可永久解鎖，並支持這個項目。';

  @override
  String get unlockNow => '立即解鎖';

  @override
  String get startMyFreeTrial => '開始免費試用';

  @override
  String get lastDayOfTrial => '今天是免費試用的最後一天';

  @override
  String reminderPrice(String price) {
    return '免費試用結束後，一次支付 $price 即可永久解鎖 Nightingale TV，並支持這個項目。';
  }

  @override
  String get reminder => '免費試用結束後，一次購買即可永久解鎖 Nightingale TV，並支持這個項目。';

  @override
  String get freeTrialEnded => '你的免費試用已結束';

  @override
  String get unlockScreenText =>
      '一次購買即可永久解鎖 Nightingale TV，並支持這個項目。你的個人檔案、頻道和設定都還在。';

  @override
  String unlockForPrice(String price) {
    return '以 $price 解鎖';
  }

  @override
  String get unlock => '解鎖';

  @override
  String get checkMyPurchaseAgain => '重新檢查我的購買';

  @override
  String get redeemPlayCode => '兌換 Play 代碼';

  @override
  String get redeemCodeTitle => '兌換代碼';

  @override
  String get redeemCodeText =>
      '請在手機或電腦上登入這部裝置使用的 Google 帳戶，然後前往 play.google.com/redeem 兌換代碼。之後選擇「重新檢查我的購買」。';

  @override
  String get noPurchaseFound => '找不到購買記錄';

  @override
  String get noPurchaseFoundText =>
      '這部裝置上的 Google 帳戶沒有 Nightingale TV 的購買記錄。如果你剛剛購買，請稍後再試。';

  @override
  String get purchaseNotCompleted => '購買未完成';

  @override
  String get purchaseNotCompletedText => '無法完成購買。沒有任何變更；請稍後再試。';

  @override
  String get purchasePendingText =>
      '你的購買正在等待完成。在此期間 Nightingale TV 可以正常使用，完成後會自動解鎖。';

  @override
  String get unlockedThankYou => '已解鎖。感謝你支持 Nightingale TV。';

  @override
  String freeTrialDaysLeftAbout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '免費試用：還剩 $count 天',
    );
    return '$_temp0';
  }

  @override
  String couldntReadChannels(Object name) {
    return '無法讀取 $name 的頻道清單';
  }

  @override
  String channelNoLongerOn(Object server) {
    return '這個頻道已不在 $server 上';
  }

  @override
  String channelsNoLongerOnServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道已不在伺服器上',
    );
    return '$_temp0';
  }

  @override
  String get sharing => '分享';

  @override
  String get sharingIntroTitle => '新增也在用 Nightingale TV 的好友';

  @override
  String get sharingIntroWhat =>
      '透過分享，你可以新增同樣使用 Nightingale TV 的好友。每個 Nightingale 個人檔案都有自己的分享帳戶。';

  @override
  String get sharingIntroStored => '儲存的內容：你的電子郵件、你的分享個人資料、你的好友，以及日後你分享和觀看的內容。';

  @override
  String get sharingIntroNoVideo => '用戶之間永遠不會傳送任何影片。';

  @override
  String get sharingSetUp => '設定';

  @override
  String get sharingEmailPrompt => '請輸入你的電子郵件。我們會傳送一組 6 位數代碼供你登入。';

  @override
  String get sharingEmailLabel => '電子郵件';

  @override
  String get sharingSendCode => '傳送代碼';

  @override
  String get sharingNotAnEmail => '請輸入電子郵件地址，例如 name@example.com。';

  @override
  String sharingCodeSent(Object email) {
    return '我們已傳送一組 6 位數代碼到 $email。請在這裡輸入。';
  }

  @override
  String get sharingCodeLabel => '6 位數代碼';

  @override
  String get sharingWrongCode => '代碼不正確';

  @override
  String get sharingTooManyWrong => '代碼錯誤次數過多。請傳送新的代碼。';

  @override
  String get sharingSendNewCode => '傳送新代碼';

  @override
  String sharingSendNewCodeIn(Object seconds) {
    return '傳送新代碼（$seconds 秒）';
  }

  @override
  String get sharingOtherEmail => '使用其他電子郵件';

  @override
  String get sharingUnavailable => '分享功能暫時無法使用。請稍後再試。';

  @override
  String get sharingProfileTitle => '你的分享個人資料';

  @override
  String get sharingProfileIntro => '好友會看到這些內容。你的電子郵件永遠不會顯示。';

  @override
  String get sharingNameLabel => '顯示名稱';

  @override
  String get sharingHandleLabel => '帳號名稱';

  @override
  String get sharingHandleRules => '請使用 3–20 個字母、數字或 _。';

  @override
  String get sharingHandleTaken => '這個帳號名稱已被使用。';

  @override
  String get sharingNameRequired => '請輸入顯示名稱。';

  @override
  String get sharingAvatar => '頭像';

  @override
  String get sharingStationLabel => '電視台名稱（選填）';

  @override
  String get sharingAddFriend => '新增好友';

  @override
  String get sharingCodeHelp =>
      '好友在 Nightingale TV 的「分享」→「新增好友」中輸入這個代碼，或開啟連結。代碼只能使用一次，7 天後過期。';

  @override
  String get sharingNewCode => '新代碼';

  @override
  String get sharingSendInvite => '傳送邀請';

  @override
  String get sharingEnterCode => '輸入代碼';

  @override
  String sharingInviteText(Object link) {
    return '在 Nightingale TV 上加我為好友：$link';
  }

  @override
  String get sharingFriends => '好友';

  @override
  String get sharingNoFriends => '還沒有好友。分享你的代碼來新增好友。';

  @override
  String get sharingBlocked => '已封鎖';

  @override
  String get sharingRemoveFriend => '移除好友';

  @override
  String sharingRemoveFriendConfirm(Object name) {
    return '要移除好友 $name 嗎？你們將不再是好友。';
  }

  @override
  String get sharingBlock => '封鎖';

  @override
  String sharingBlockConfirm(Object name) {
    return '要封鎖 $name 嗎？這會將對方從好友中移除，對方也無法使用你的代碼。';
  }

  @override
  String get sharingUnblock => '解除封鎖';

  @override
  String sharingUnblockConfirm(Object name) {
    return '要解除封鎖 $name 嗎？對方可以用新代碼再次新增你。';
  }

  @override
  String get sharingSignOutConfirm =>
      '要在這個個人檔案上登出分享嗎？你的分享帳戶和好友會保留。用你的電子郵件即可重新登入。';

  @override
  String get sharingDeleteAccount => '刪除分享帳戶';

  @override
  String sharingDeleteConfirm(Object handle) {
    return '這會刪除你的分享帳戶、分享個人資料（@$handle）、好友、邀請以及為其儲存的所有內容，並在所有裝置上登出。此動作無法復原。';
  }

  @override
  String get sharingDeleted => '你的分享帳戶已刪除。';

  @override
  String get sharingCodeFieldLabel => '好友的代碼';

  @override
  String get sharingNotACode => '代碼由 6 個字母和數字組成，例如 AB3K·9Q。';

  @override
  String sharingAddFriendQuestion(Object name, Object handle) {
    return '要新增 $name（@$handle）為好友嗎？';
  }

  @override
  String get sharingOwnCode => '這是你自己的代碼';

  @override
  String get sharingInviteGone => '這個邀請已過期或已使用過';

  @override
  String get sharingTooManyTries => '嘗試次數過多。請稍後再試';

  @override
  String sharingNowFriends(Object name) {
    return '你和 $name 現在是好友了。';
  }

  @override
  String get sharingSwitchToAdult => '請切換到成人個人檔案來新增好友。';

  @override
  String get sharingEditProfile => '編輯';

  @override
  String sharingStation(Object station) {
    return '電視台：$station';
  }

  @override
  String get sharingLiveCantShare => '直播頻道透過你自己的調諧器播放，無法分享';

  @override
  String get sharingMusicCantShare => '音樂頻道無法分享';

  @override
  String get sharingCopyCantShare => '別人分享給你的頻道無法再次分享';

  @override
  String get sharingTooBig => '超過 20,000 個節目的頻道無法分享';

  @override
  String get sharingNoneMatch => '這些節目都不在你的伺服器上';

  @override
  String get sharingUpdateApp => '請更新 Nightingale TV 以新增這個頻道。';

  @override
  String sharingStopsFollowing(Object name) {
    return '這個頻道將不再跟隨 $name 的變更。';
  }

  @override
  String sharingNewShares(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道',
    );
    return '$name 與你分享了 $_temp0。開啟「選單」→「分享」即可新增。';
  }

  @override
  String sharingNewSharesMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個頻道',
    );
    return '有 $_temp0分享給你。開啟「選單」→「分享」即可新增。';
  }

  @override
  String get sharingSharedWithYou => '分享給你的';

  @override
  String get sharingNothingShared => '沒有待處理的內容。好友分享給你的頻道會顯示在這裡。';

  @override
  String sharingMatched(Object matched, Object total) {
    return '已比對到 $matched / $total 個節目';
  }

  @override
  String sharingAddedAs(Object number) {
    return '已新增為頻道 $number';
  }

  @override
  String get sharingDecline => '拒絕';

  @override
  String get sharingShareChannels => '分享頻道';

  @override
  String get sharingShareChannelsHelp =>
      '好友會收到每個頻道的描述，他們的應用程式會用自己的伺服器重建頻道。不會傳送任何影片。';

  @override
  String get sharingChannelsYouShare => '你分享的頻道';

  @override
  String get sharingNoChannelsShared => '你沒有分享任何頻道。';

  @override
  String get sharingStopSharing => '停止分享';

  @override
  String sharingStopSharingConfirm(Object name) {
    return '要停止分享 $name 嗎？好友會保留他們的副本，但不會再收到你的變更。';
  }

  @override
  String sharingWith(Object names) {
    return '分享給 $names';
  }

  @override
  String get sharingShareWith => '分享給';

  @override
  String get sharingShare => '分享';

  @override
  String get sharingGetLink => '取得連結';

  @override
  String sharingSharedWith(Object names) {
    return '已分享給 $names';
  }

  @override
  String get sharingLinkHelp => '7 天內使用這個代碼的人會成為你的好友，並取得這些頻道。代碼只能使用一次。';

  @override
  String sharingChannelsInviteText(Object link) {
    return '這是我在 Nightingale TV 上的一些頻道：$link';
  }

  @override
  String get sharingPickChannel => '請至少選擇一個頻道。';

  @override
  String get sharingPickFriend => '請至少選擇一位好友，或使用「取得連結」。';

  @override
  String get sharingNoFriendsToShare => '還沒有好友。取得連結即可與新朋友分享。';

  @override
  String get sharingShareEllipsis => '分享…';

  @override
  String sharingSharedBy(Object name, Object handle) {
    return '由 $name（@$handle）分享';
  }

  @override
  String get sharingKeepUpdated => '保持更新';

  @override
  String sharingKeepUpdatedHelp(Object name) {
    return '跟隨 $name 對這個頻道的變更';
  }

  @override
  String get sharingNoLongerUpdated => '不再更新';

  @override
  String sharingChannelsOffer(Object name, Object handle, Object names) {
    return '$name（@$handle）與你分享了這些頻道：$names。要新增 $name 為好友並取得這些頻道嗎？';
  }

  @override
  String sharingNowFriendsChannels(Object name) {
    return '你和 $name 現在是好友了。對方的頻道正在「分享給你的」中等待。';
  }

  @override
  String get sharedTab => '分享';

  @override
  String get sharedTabRule => '你從好友的分享中新增的頻道';

  @override
  String get presenceSetting => '顯示我正在觀看的內容';

  @override
  String presenceSettingValue(Object value) {
    return '顯示我正在觀看的內容：$value';
  }

  @override
  String get presenceQuestion => '要讓好友看到你正在觀看什麼嗎？';

  @override
  String get presenceExplain =>
      '你觀看時，好友會看到節目或電影以及頻道。不會顯示其他任何內容，你停止觀看後也不會顯示。在播放器按鈕中選擇「私密觀看」可在關閉應用程式前隱藏這些資訊。你可以隨時在「分享」中變更這項設定。';

  @override
  String presenceWatchingOn(Object title, Object channel) {
    return '正在 $channel 觀看《$title》';
  }

  @override
  String presenceWatchingChannel(Object channel) {
    return '正在觀看 $channel';
  }

  @override
  String presenceIsWatching(Object name) {
    return '$name 正在觀看';
  }

  @override
  String presenceAndOthersWatching(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友',
    );
    return '$name 和另外 $_temp0正在觀看';
  }

  @override
  String presenceWatchingToo(Object name) {
    return '$name 也在觀看';
  }

  @override
  String presenceAndOthersWatchingToo(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友',
    );
    return '$name 和另外 $_temp0也在觀看';
  }

  @override
  String presenceNoticeOne(Object name) {
    return '$name 正在觀看';
  }

  @override
  String presenceNoticeMany(Object names) {
    return '$names 正在觀看';
  }

  @override
  String get watchPrivately => '私密觀看';

  @override
  String get watchingPrivately => '正在私密觀看';

  @override
  String get watchTogether => '一起看';

  @override
  String partyStartTitle(Object title) {
    return '一起看《$title》';
  }

  @override
  String get partyStartHelp => '每個人都從自己的伺服器同步播放。最多選擇 7 位好友，或取得連結。';

  @override
  String get partyNoFriends => '還沒有好友：取得連結來邀請別人。';

  @override
  String get partyGetLink => '取得連結';

  @override
  String get partyStart => '開始';

  @override
  String get partyLinkHelp => '開啟這個連結的任何人都會成為你的好友，並可以加入。';

  @override
  String partyInviteBanner(Object name, Object title) {
    return '$name 邀請你一起看《$title》';
  }

  @override
  String partyInviteBannerNoTitle(Object name) {
    return '$name 邀請你一起看';
  }

  @override
  String get partyJoin => '加入';

  @override
  String get partyNotNow => '稍後再說';

  @override
  String partyJoinQuestion(Object name) {
    return '要加入 $name 的觀影派對嗎？';
  }

  @override
  String partyOn(Object title, Object channel) {
    return '$channel 上的《$title》';
  }

  @override
  String get partyInSync => '已同步';

  @override
  String get partyCatchingUp => '正在追上進度';

  @override
  String get partyNotOnServers => '不在你的伺服器上';

  @override
  String partyMissingTitle(Object title) {
    return '不在你的伺服器上：$title';
  }

  @override
  String get partyMissingRejoin => '你會在下一個節目時重新加入。';

  @override
  String get partyInvite => '邀請';

  @override
  String get partyLeave => '離開';

  @override
  String get partyStay => '留下';

  @override
  String get partyLeaveQuestion => '要離開觀影派對嗎？';

  @override
  String get partyLeaveHostDetail => '你是主持人，因此派對會為所有人結束。';

  @override
  String get partyLeaveGuestDetail => '你會回到自己的頻道。';

  @override
  String get partyHost => '主持人';

  @override
  String partyJoined(Object name) {
    return '$name 已加入';
  }

  @override
  String partyLeft(Object name) {
    return '$name 已離開';
  }

  @override
  String partyPaused(Object name) {
    return '$name 已暫停';
  }

  @override
  String partyResumed(Object name) {
    return '$name 已繼續播放';
  }

  @override
  String partySkipped(Object name) {
    return '$name 已跳過';
  }

  @override
  String partyRestarted(Object name) {
    return '$name 已從頭播放節目';
  }

  @override
  String partyWentLive(Object name) {
    return '$name 已返回直播';
  }

  @override
  String partyEnded(Object name) {
    return '$name 結束了觀影派對';
  }

  @override
  String get partyLost => '與觀影派對的連線已中斷';

  @override
  String get partyFull => '這個觀影派對已滿';

  @override
  String get partyOver => '這個觀影派對已結束';

  @override
  String get partyWatchParties => '觀影派對';

  @override
  String get partyNoInvites => '目前沒有觀影派對邀請。';

  @override
  String partyChannelName(Object channel) {
    return '觀影派對 · $channel';
  }

  @override
  String get partyReactions => '互動表情';

  @override
  String partyInvited(Object names) {
    return '已邀請 $names';
  }

  @override
  String get smbGuestsRefused => '這台電腦不允許訪客登入。請輸入使用者名稱和密碼。';

  @override
  String get smbNoAccess => '無法存取';

  @override
  String smbShareGone(String name) {
    return '$name 已不存在。';
  }

  @override
  String smbReadingFiles(String name) {
    return '正在讀取 $name 上的檔案…';
  }

  @override
  String smbScanningFolders(String name, int count) {
    return '正在掃描 $name：$count 個資料夾…';
  }

  @override
  String smbShareOnHost(String share, String host) {
    return '$host 上的 $share';
  }

  @override
  String get smbNotAnAddress =>
      '這不是共用資料夾的地址。請以 smb://電腦/共用名稱 或 \\\\電腦\\共用名稱 的格式輸入。';

  @override
  String smbCantReach(String host) {
    return '無法連線到 $host。';
  }

  @override
  String smbAnotherShare(String name) {
    return '這不是 $name，而是另一個共用資料夾。';
  }

  @override
  String get smbMapOne => '請至少為一個資料夾選擇內容類型。';

  @override
  String get smbShareButton => 'SMB 共用資料夾';

  @override
  String get smbFindTitle => '新增共用資料夾';

  @override
  String get smbFindHelp => '選擇一台電腦或 NAS，或輸入共用資料夾的地址。';

  @override
  String get smbAddress => '共用資料夾地址';

  @override
  String get smbSearching => '正在尋找電腦…';

  @override
  String get smbSearchAgain => '重新尋找';

  @override
  String get smbNoneFound => '找不到電腦。請輸入共用資料夾的地址。';

  @override
  String smbSharesOn(String host) {
    return '$host 上的共用資料夾';
  }

  @override
  String smbNoShares(String host) {
    return '$host 上沒有你能開啟的共用資料夾。';
  }

  @override
  String get smbOld => 'SMB1：舊協定，未加密';

  @override
  String smbSignInTo(String host) {
    return '登入 $host';
  }

  @override
  String get smbDomain => '網域（選填）';

  @override
  String get smbAsGuest => '以訪客身分連線';

  @override
  String smbWhatsIn(String share) {
    return '$share 裡有什麼？';
  }

  @override
  String get smbMapHelp =>
      '為每個資料夾選擇內容類型。保留為「無」的資料夾會被忽略；已選擇的資料夾中的子資料夾可以另外選擇。在資料夾名稱上按 OK 可開啟它。';

  @override
  String get smbTypeNone => '無';

  @override
  String get smbTypeTv => '電視節目';

  @override
  String get smbTypeMovies => '電影';

  @override
  String get smbTypeMusic => '音樂';

  @override
  String get smbTypeMusicVideos => '音樂影片';

  @override
  String get smbTypeHome => '家庭影片';

  @override
  String get smbTypeCommercials => '廣告';

  @override
  String get smbTypeBumpers => '過場片段';

  @override
  String smbAsAbove(String type) {
    return '$type（同上）';
  }

  @override
  String get smbUp => '上一層資料夾';

  @override
  String get smbHistoryName => '記錄名稱';

  @override
  String get smbHistoryHelp =>
      '使用相同記錄名稱的電視會共用播放次數和續播位置。它們儲存在共用資料夾中的隱藏資料夾 .nightingale 裡，其他內容不會被更改。';

  @override
  String get smbKeepLocal => '在此裝置上保存記錄';

  @override
  String get smbReadOnly => '此共用資料夾為唯讀：記錄保存在此裝置上。';

  @override
  String get smbFoldersDone => '完成';

  @override
  String smbFilesLeft(int count) {
    return '正在讀取 $count 個檔案';
  }

  @override
  String smbHistoryOnShare(String name) {
    return '記錄：在共用資料夾上，名稱為「$name」';
  }

  @override
  String get smbHistoryOnDevice => '記錄：在此裝置上';

  @override
  String get smbHistoryReadOnly => '記錄：在此裝置上（共用資料夾為唯讀）';

  @override
  String get smbFolders => '資料夾';

  @override
  String smbCantPlay(int count) {
    return '無法播放（$count）';
  }

  @override
  String smbCantPlayTitle(String name) {
    return '無法播放 · $name';
  }

  @override
  String get smbCantPlayHelp =>
      '這些檔案不會排入節目。修好檔案或配對一台能轉換的 Nightingale TV 後，請重新檢查。';

  @override
  String get smbCheckAgain => '重新檢查';

  @override
  String get smbCantPlayNone => '所有檔案都能播放。';

  @override
  String get smbReasonDamaged => '已損壞';

  @override
  String get smbReasonNoVideo => '沒有畫面';

  @override
  String get smbReasonTooMuch => '超出此裝置的能力，也沒有其他 Nightingale TV 可以轉換';

  @override
  String smbRenameTitle(String name) {
    return '重新命名 $name';
  }

  @override
  String smbFoldersTitle(String name) {
    return '資料夾 · $name';
  }

  @override
  String get smbSave => '儲存';

  @override
  String get smbQualityNote =>
      '共用資料夾中的檔案由已配對的另一台 Nightingale TV 轉換以適應網絡；沒有的話會按原樣播放，因為在此裝置上轉換並不能減輕網絡負擔。';

  @override
  String get smbHomeCantShare => '家庭影片無法分享';

  @override
  String get smbHomeVideo => '家庭影片';

  @override
  String get licencesTitle => '授權條款';

  @override
  String get licencesHelp =>
      'Nightingale TV 是採用 GNU GPL 3 的自由軟件。它使用以下軟件，每個軟件都依循各自的授權條款。';

  @override
  String get colorPurple => '紫色';

  @override
  String get colorGreen => '綠色';

  @override
  String get colorAmber => '琥珀色';

  @override
  String get colorTeal => '藍綠色';

  @override
  String get colorMagenta => '洋紅色';

  @override
  String get colorOlive => '橄欖色';

  @override
  String get colorSlate => '石板灰';

  @override
  String get colorCocoa => '可可色';

  @override
  String get colorWine => '酒紅色';

  @override
  String get guideColor => '節目表中的顏色';

  @override
  String guideColorTitle(String name) {
    return '節目表中的顏色 · $name';
  }

  @override
  String get guideColorHelp => '來自此伺服器的節目在節目表中顯示為此顏色。';

  @override
  String guideColorUsedBy(String color, String name) {
    return '$color · $name';
  }

  @override
  String get serverColorsSetting => '節目表中的伺服器顏色';

  @override
  String get serverColorsHelp => '每個節目顯示為其播放來源伺服器的顏色，節目表下方有圖例。';

  @override
  String playsFrom(String name) {
    return '來自 $name';
  }

  @override
  String get convertForOthers => '為其他電視轉換';

  @override
  String get convertForOthersHelp =>
      '無法播放共用資料夾中某個檔案的電視會請這台電腦轉換。這台電腦的某個個人檔案中需要有相同的共用資料夾，而且只轉換其已指定資料夾中的檔案。';

  @override
  String convertCode(String code) {
    return '配對碼：$code';
  }

  @override
  String get convertPairedTvs => '已配對的電視';

  @override
  String get convertNoTvs => '還沒有配對的電視。';

  @override
  String get convertHelpers => '在其他 Nightingale TV 上轉換';

  @override
  String get convertHelpersHelp =>
      '電腦上的 Nightingale TV 或 Docker 伺服器可以轉換此裝置無法播放、或無法夠快播放的共用資料夾檔案。在那邊開啟「為其他電視轉換」，然後用顯示的代碼配對。';

  @override
  String get convertFind => '在網絡中尋找';

  @override
  String get convertTypeAddress => '輸入地址';

  @override
  String get convertAddress => 'Nightingale TV 的地址';

  @override
  String convertEnterCode(String name) {
    return '$name 上顯示的代碼';
  }

  @override
  String convertWrongCode(String name) {
    return '代碼不對，或 $name 沒有回應。';
  }

  @override
  String get convertNoneFound =>
      '找不到可轉換的 Nightingale TV。請確認那邊已開啟「為其他電視轉換」，或輸入地址。';

  @override
  String convertAddShareOn(String share, String name) {
    return '在 $name 上新增 $share';
  }

  @override
  String convertNotAnswering(String name) {
    return '$name 沒有回應';
  }

  @override
  String get convertPair => '配對';

  @override
  String get serverKindsHelp =>
      '你可以新增 Jellyfin、Emby、Plex、YouTube 和 SMB 共用資料夾（NAS 或電腦上的共用資料夾）。';

  @override
  String get youTube => 'YouTube';

  @override
  String get youTubeTerms => '登入即表示你同意 YouTube 服務條款和 Nightingale TV 私隱政策。';

  @override
  String get youTubeTermsOfService => 'YouTube 服務條款';

  @override
  String get privacyPolicy => '私隱政策';

  @override
  String youTubeEnterCode(String address) {
    return '在手機或電腦上前往 $address，輸入這組代碼。';
  }

  @override
  String get openGoogleDevice => '開啟 google.com/device';

  @override
  String get signInWasCancelled => '登入已取消';

  @override
  String get youTubeChannelsTitle => 'YouTube 頻道';

  @override
  String youTubePickedOf(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get notSubscribed => '未訂閱';

  @override
  String get searchSubscriptions => '搜尋你的訂閱內容';

  @override
  String get noSubscriptions => '這個帳戶沒有訂閱內容';

  @override
  String get noSubscriptionsMatch => '沒有相符的訂閱內容';

  @override
  String removeYouTubeChannels(String names) {
    return '要從節目表中移除 $names 嗎？';
  }

  @override
  String youTubeChannelCount(int count) {
    return '$count 個頻道';
  }

  @override
  String get googleClient => 'Google 用戶端';

  @override
  String get googleClientShared => 'Nightingale TV 的';

  @override
  String get googleClientOwn => '你自己的';

  @override
  String youTubeDailyLimit(String time) {
    return '已達到 YouTube 的每日上限。新影片會在 $time 之後送達。';
  }

  @override
  String get useMyOwnClient => '使用我自己的用戶端';

  @override
  String get signInToYouTubeAgain => '請重新登入 YouTube';

  @override
  String get ownClientTitle => '你自己的 Google 用戶端';

  @override
  String get clientId => '用戶端 ID';

  @override
  String get clientSecret => '用戶端密鑰';

  @override
  String get openClientFile => '開啟檔案';

  @override
  String get clientFileNotRead => '這個檔案不是 Google 用戶端檔案';

  @override
  String get useThisClient => '使用這個用戶端';

  @override
  String get useSharedClient => '使用 Nightingale TV 的用戶端';

  @override
  String get ownClientStep1 => '開啟 console.cloud.google.com 並建立專案。';

  @override
  String get ownClientStep2 => '啟用 YouTube Data API v3。';

  @override
  String get ownClientStep3 => '設定 OAuth 同意畫面，並加入 youtube.readonly 範圍。';

  @override
  String get ownClientStep4 => '將發布狀態設為「正式版」。';

  @override
  String get ownClientStep5 => '建立類型為「電視和輸入受限的裝置」的 OAuth 用戶端。';

  @override
  String get ownClientStep6 => '在這裡輸入用戶端 ID 和密鑰，或開啟下載的檔案。';

  @override
  String ownClientGuide(String address) {
    return '完整指南：$address';
  }

  @override
  String get clientRefused => 'Google 不接受這個用戶端。類型必須是「電視和輸入受限的裝置」。';

  @override
  String get noVideosYet => '還沒有影片';

  @override
  String get youTubeRefusedPlayer => 'YouTube 不接受這個播放器';

  @override
  String get youTubeNeedsWebView => 'YouTube 需要 Android System WebView';

  @override
  String getItFromPlayStore(String address) {
    return '從 Play 商店取得：$address';
  }

  @override
  String youTubeChannelSource(String title) {
    return 'YouTube 頻道：$title';
  }

  @override
  String publishedOn(String date) {
    return '發布於 $date';
  }

  @override
  String get youTubeCantBeShared => '無法分享 YouTube 頻道';

  @override
  String get youTubeAlreadyRemovedQuota => '請在 YouTube 每日上限重設後再試一次。';

  @override
  String get youTubeAccount => 'YouTube 帳戶';

  @override
  String get couldNotReachGoogle => '無法連線到 Google，請再試一次。';

  @override
  String get youTubeDailyLimitShort => '已達到 YouTube 的每日上限。';

  @override
  String get youTubeNoBreaks => 'YouTube 頻道沒有廣告時間。';

  @override
  String get youTubeNoBlocks => 'YouTube 頻道不能有節目時段。';

  @override
  String get youTubeAccessNeeded =>
      'Nightingale TV 需要查看你的 YouTube 訂閱內容。請輸入新的代碼並允許。';

  @override
  String get youTubeRemoveBody =>
      '它的頻道會從頻道列表中移除，Nightingale TV 對你 YouTube 帳號的存取也會結束。';

  @override
  String get playerQuality => '畫質';

  @override
  String playerQualityValue(String value) {
    return '畫質：$value';
  }

  @override
  String get playerQualityAuto => '自動';

  @override
  String get playerQualityOriginal => '原畫';

  @override
  String playerQualityMbps(int mbps) {
    return '$mbps Mbps';
  }

  @override
  String get youTubeNoClient => '這個版本沒有 YouTube 用戶端。README 中說明了如何新增。';

  @override
  String youTubeSharedLimit(int limit) {
    return 'Nightingale TV 的用戶端最多允許 $limit 個 YouTube 頻道。如需更多，請在 伺服器 → YouTube → Google 用戶端 中使用你自己的用戶端。';
  }

  @override
  String youTubeSharedTooMany(int limit) {
    return 'Nightingale TV 的用戶端最多允許 $limit 個 YouTube 頻道。請先在「頻道」中移除一些。';
  }

  @override
  String lastBackedUp(Object when) {
    return '上次備份：$when';
  }

  @override
  String get notBackedUpYet => '尚未備份。';

  @override
  String get undoRestore => '撤銷還原';

  @override
  String get undoLineupReset => '撤銷重設頻道列表';

  @override
  String undoDeleting(Object name) {
    return '撤銷刪除 $name';
  }

  @override
  String get undoDeletingAProfile => '撤銷刪除個人檔案';

  @override
  String get undoUpdate => '撤銷更新';

  @override
  String get undoLineupCleanup => '撤銷整理頻道列表';

  @override
  String undoTitle(Object action, Object time) {
    return '$action · $time';
  }

  @override
  String undoPointSaved(Object when, Object profiles) {
    return '儲存於 $when：$profiles';
  }

  @override
  String get pickThePlaylistFileAgain => '請重新選擇播放清單檔案';

  @override
  String get pickTheGuideFileAgain => '請重新選擇節目表檔案';

  @override
  String get playlistFileNotOnDevice => '此裝置上沒有播放清單檔案';

  @override
  String get guideFileNotOnDevice => '此裝置上沒有節目表檔案';

  @override
  String get youTubeServerOwnClient => '伺服器模式使用你自己的 Google 用戶端。';

  @override
  String get uploadJsonFile => '上傳 JSON 檔案';

  @override
  String get continueStep => '繼續';

  @override
  String get watchNoChannels => '這個個人檔案沒有 YouTube 頻道。請在 伺服器 中新增 YouTube。';
}
