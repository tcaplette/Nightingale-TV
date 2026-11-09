// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onlyChannelsYou =>
      'Only channels you added can be removed. Hide this one instead.';

  @override
  String get music => 'Music';

  @override
  String get nothingInThe => 'Nothing in the library matches that.';

  @override
  String get chooseSongsOr => 'Choose songs or music videos.';

  @override
  String get blockChannel => 'Block Channel';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return 'This overlaps \"$title\" ($clash) on the same channel.';
  }

  @override
  String get chooseSomeShows =>
      'Choose some shows or movies for the block to play.';

  @override
  String nothingInThis(Object shortLabel) {
    return 'Nothing in this mix is rated $shortLabel or higher. Choose a lower rating or other shows.';
  }

  @override
  String get theLineupsShows =>
      'The lineup\'s shows have no episodes. Pick other shows.';

  @override
  String get addAShow => 'Add a show to the lineup.';

  @override
  String get chooseAChannel => 'Choose a channel.';

  @override
  String get theBlockHas =>
      'The block has to end at a different time than it starts.';

  @override
  String get pickAtLeast => 'Pick at least one day.';

  @override
  String get giveTheBlock => 'Give the block a title.';

  @override
  String get thisChannelDoesnt => 'This channel doesn\'t have slots.';

  @override
  String get onlyShuffledChannels =>
      'Only shuffled channels can be reshuffled.';

  @override
  String get chooseSomethingFor => 'Choose something for the channel to play.';

  @override
  String get onlyChannelsYouAdded =>
      'Only channels you added can change what they play.';

  @override
  String get myChannel => 'My Channel';

  @override
  String get noneOfYour => 'None of your servers could be reached.';

  @override
  String scanning(Object where) {
    return 'Scanning $where…';
  }

  @override
  String get buildingChannels => 'Building channels…';

  @override
  String get notSignedIn => 'Not signed in.';

  @override
  String isAlreadyIn(Object name) {
    return '$name is already in this profile';
  }

  @override
  String get thatServerIs => 'That server is no longer in this profile';

  @override
  String get yourSessionExpired =>
      'Your session expired. Please sign in again.';

  @override
  String get m3uPlaylist => 'M3U playlist';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName has no Live TV channels';
  }

  @override
  String couldntReach(Object serverName) {
    return 'Couldn\'t reach $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return '$serverName Live TV';
  }

  @override
  String liveTvIs(Object serverName) {
    return '$serverName Live TV is already a source';
  }

  @override
  String get notSignedIn2 => 'Not signed in';

  @override
  String get newGroup => 'New group';

  @override
  String get thisBackupIs =>
      'This backup is damaged: one of its channel logos can\'t be read.';

  @override
  String get thisBackupIsDamaged =>
      'This backup is damaged: its Live TV export settings can\'t be read.';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'This backup is damaged: $name\'s $what can\'t be read.';
  }

  @override
  String get liveTvSources => 'Live TV sources';

  @override
  String thisBackupCant(Object problem) {
    return 'This backup can\'t be restored. $problem';
  }

  @override
  String get thisBackupIsDamagedIts =>
      'This backup is damaged: its profiles can\'t be read.';

  @override
  String get thisFileIs =>
      'This file is too big to be a Nightingale TV backup.';

  @override
  String get thisBackupWas =>
      'This backup was made by a newer version of Nightingale TV.';

  @override
  String get thisFileIsnt =>
      'This file isn\'t a Nightingale TV backup, or it\'s damaged.';

  @override
  String restoredTheBackup(Object toLocal) {
    return 'Restored the backup from $toLocal.';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'Couldn\'t restore the backup: $e';
  }

  @override
  String couldntSaveA(Object e) {
    return 'Couldn\'t save a backup first: $e';
  }

  @override
  String get madeByYou => 'Made by you';

  @override
  String get fromNightingaleTv => 'From Nightingale TV (own build)';

  @override
  String get fromNightingaleTv2 => 'From Nightingale TV';

  @override
  String get movingToNightingale => 'Moving to Nightingale TV (own build)';

  @override
  String get movingToNightingaleTv => 'Moving to Nightingale TV';

  @override
  String get fromAFile => 'From a file';

  @override
  String get beforeLineupCleanup => 'Before lineup cleanup';

  @override
  String get beforeUpdate => 'Before update';

  @override
  String beforeDeleting(Object subject) {
    return 'Before deleting $subject';
  }

  @override
  String get beforeDeletingA => 'Before deleting a profile';

  @override
  String get beforeReset => 'Before reset';

  @override
  String get beforeRestore => 'Before restore';

  @override
  String get automatic => 'Automatic';

  @override
  String get nc1718 => 'NC-17 / 18 and up';

  @override
  String get tvMaR => 'TV-MA / R and up';

  @override
  String get tv14Pg => 'TV-14 / PG-13 and up';

  @override
  String get off => 'Off';

  @override
  String get nowAndThen => 'Now and then';

  @override
  String get always => 'Always';

  @override
  String get truncate => 'Truncate';

  @override
  String get offlineImage => 'Offline image';

  @override
  String get filler => 'Filler';

  @override
  String get leastWatchedFirst => 'Least watched first';

  @override
  String get shuffled => 'Shuffled';

  @override
  String get inOrderShows => 'In order (shows take turns)';

  @override
  String get channelsWhereEverything =>
      'Channels where everything that plays, blocks included, is rated TV-Y, TV-Y7, TV-G or G.';

  @override
  String get musicVideoAnd => 'Music video and radio channels.';

  @override
  String get channelsThatPlay =>
      'Channels that play movies and no episodes or music.';

  @override
  String get channelsFromYour => 'Channels from your Live TV sources.';

  @override
  String get channelsYouMarked => 'Channels you marked as favorites.';

  @override
  String get everyChannel => 'Every channel.';

  @override
  String get kids => 'Kids';

  @override
  String get movies => 'Movies';

  @override
  String get liveTv2 => 'Live TV';

  @override
  String get favorites => 'Favorites';

  @override
  String get all => 'All';

  @override
  String get theAccentsAre =>
      'The accents are a theme and theme or channel for each.';

  @override
  String get thoseArentRetro => 'Those aren\'t retro settings.';

  @override
  String get theOverlayTheme =>
      'The overlay theme is standard, vcr, cableBox or stationIdent.';

  @override
  String get theCrtEffect =>
      'The CRT effect is off, softTube, livingRoom, arcade, studioMonitor or custom.';

  @override
  String get theSurroundImage => 'The surround image is a file name.';

  @override
  String get theSurroundIs =>
      'The surround is black, charcoal, channel or image.';

  @override
  String get thePictureShape =>
      'The picture shape is original, fill43 or fit43.';

  @override
  String get channelColor => 'Channel color';

  @override
  String get theme => 'Theme';

  @override
  String get stationIdent => 'Station ident';

  @override
  String get cableBox => 'Cable box';

  @override
  String get vcr => 'VCR';

  @override
  String get standard => 'Standard';

  @override
  String get custom => 'Custom';

  @override
  String get studioMonitor => 'Studio monitor';

  @override
  String get arcade => 'Arcade';

  @override
  String get livingRoom => 'Living room';

  @override
  String get softTube => 'Soft tube';

  @override
  String get customColorIs => 'Custom color is natural, warm, faded or vivid.';

  @override
  String get customLinesIs => 'Custom lines is 240 or 480.';

  @override
  String customIsOff(Object key) {
    return 'Custom $key is off, low, medium or high.';
  }

  @override
  String get thatIsntA => 'That isn\'t a Custom style.';

  @override
  String get vivid => 'Vivid';

  @override
  String get faded => 'Faded';

  @override
  String get warm => 'Warm';

  @override
  String get natural => 'Natural';

  @override
  String get high => 'High';

  @override
  String get medium => 'Medium';

  @override
  String get low => 'Low';

  @override
  String get image => 'Image';

  @override
  String get charcoal => 'Charcoal';

  @override
  String get black => 'Black';

  @override
  String get n43Fit => '4:3 fit';

  @override
  String get n43Fill => '4:3 fill';

  @override
  String get original => 'Original';

  @override
  String get thisChannelIs => 'This channel is off the air';

  @override
  String get offAir => 'Off Air';

  @override
  String get tail => 'Tail';

  @override
  String get postRoll => 'Post-roll';

  @override
  String get midRoll => 'Mid-roll';

  @override
  String get preRoll => 'Pre-roll';

  @override
  String get commercials => 'Commercials';

  @override
  String get bumpers => 'Bumpers';

  @override
  String get pleaseStandBy => 'PLEASE STAND BY';

  @override
  String get offTheAir => 'OFF THE AIR';

  @override
  String get wellBeRight => 'We\'ll be right back';

  @override
  String upNextAt(Object at) {
    return 'Up next at $at';
  }

  @override
  String backOnThe(Object next, Object title) {
    return 'Back on the air $next with $title';
  }

  @override
  String get processor => 'Processor';

  @override
  String get graphicsCardNvenc => 'Graphics card (NVENC)';

  @override
  String get graphicsCardVaapi => 'Graphics card (VAAPI)';

  @override
  String get signInTo =>
      'Sign in to this profile on the TV to export its channels.';

  @override
  String get signInToThis =>
      'Sign in to this profile here to export its channels.';

  @override
  String portIsIn(Object port) {
    return 'Port $port is in use by another program. Pick another port, then update it in Plex or Jellyfin.';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'Another profile already uses port $port.';
  }

  @override
  String get pickAPort => 'Pick a port between 1024 and 65535.';

  @override
  String get movie => 'Movie';

  @override
  String backOnTheAir(Object start, Object title) {
    return 'Back on the air $start with $title.';
  }

  @override
  String get images => 'Images';

  @override
  String get couldNotRead =>
      'Could not read that image. Try PNG, JPG, WebP or SVG.';

  @override
  String get thatFileIs => 'That file is not a valid SVG.';

  @override
  String get thatImageIs =>
      'That image is over 20 MB. Please pick a smaller one.';

  @override
  String get other => 'Other';

  @override
  String get seasonsHolidays => 'Seasons & Holidays';

  @override
  String get newsWeather => 'News & Weather';

  @override
  String get sports => 'Sports';

  @override
  String get genres => 'Genres';

  @override
  String get kidsFamily => 'Kids & Family';

  @override
  String get tvMovies => 'TV & Movies';

  @override
  String get theServerWould => 'The server would not convert this item.';

  @override
  String get theServerHas => 'The server has no playable version of this item.';

  @override
  String get externalLabel => 'External';

  @override
  String get scanningChannelSources => 'Scanning channel sources…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl did not answer like a Jellyfin server.';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return 'No Jellyfin server found at $serverUrl. $message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return 'Server error $statusCode on $path.';
  }

  @override
  String get wrongUsernameOr =>
      'Wrong username or password, or the session expired.';

  @override
  String couldNotReach(Object e) {
    return 'Could not reach the server ($e).';
  }

  @override
  String get theServerTook => 'The server took too long to respond.';

  @override
  String get theServerWouldNot => 'The server would not convert this channel.';

  @override
  String get musicVideo => 'Music video';

  @override
  String movie2(Object year) {
    return 'Movie · $year';
  }

  @override
  String get commercial => 'Commercial';

  @override
  String couldntReachThe(Object what) {
    return 'Couldn\'t reach the $what';
  }

  @override
  String theIsToo(Object what) {
    return 'The $what is too big';
  }

  @override
  String theSAddress(Object what) {
    return 'The $what\'s address isn\'t a web address';
  }

  @override
  String get noGuideInformation => 'No guide information';

  @override
  String get serverLiveTv => 'Server Live TV';

  @override
  String get theChannelHas => 'The channel has no stream address.';

  @override
  String get couldntReadThe => 'Couldn\'t read the guide';

  @override
  String get couldntReachTheGuide => 'Couldn\'t reach the guide';

  @override
  String get theSourceHas => 'The source has no playlist';

  @override
  String get couldntReachThePlaylist => 'Couldn\'t reach the playlist';

  @override
  String get couldntReadThePlaylist => 'Couldn\'t read the playlist file';

  @override
  String couldntRefresh(Object name) {
    return 'Couldn\'t refresh $name';
  }

  @override
  String get thePlaylistHas => 'The playlist has no channels';

  @override
  String get thatIsntAn => 'That isn\'t an M3U playlist';

  @override
  String get thatIsntAnXmltv => 'That isn\'t an XMLTV guide';

  @override
  String get theGuideIs => 'The guide is too big (over 1 GB)';

  @override
  String get nightingaleTvBackups => 'Nightingale TV backups';

  @override
  String get uninstallingThisApp =>
      'Uninstalling this app deletes its profiles, channels and settings unless you back them up or move them first.';

  @override
  String theStoreVersion(Object officialName) {
    return 'The store version installs beside this one as a separate app, \"$officialName\", with its own setup. Buying it supports the project. Once it\'s installed, your setup can be moved to it from here.';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Updates from Google Play and official Nightingale TV APKs install over this one and keep your setup. A build of your own installs as a separate app, \"$ownBuildName\", and your setup can be moved to it from here.';
  }

  @override
  String get yourOwnBuild => 'Your own build';

  @override
  String get officialNightingaleTv => 'Official Nightingale TV APK';

  @override
  String get installedFromGoogle => 'Installed from Google Play';

  @override
  String get nightingaleTvOwn => 'Nightingale TV (own build)';

  @override
  String get sleepTimerOff => 'Sleep timer off';

  @override
  String get sleepAtEnd => 'Sleep at end of program';

  @override
  String sleepInMin(Object minutes) {
    return 'Sleep in $minutes min';
  }

  @override
  String get forced => 'Forced';

  @override
  String get unknownLanguage => 'Unknown language';

  @override
  String didntStart(Object name) {
    return '$name didn\'t start';
  }

  @override
  String get thisDeviceCant => 'This device can\'t play this channel\'s video';

  @override
  String get thisChannelsStream =>
      'This channel\'s stream type isn\'t supported on this device';

  @override
  String refusedTheStream(Object name) {
    return '$name refused the stream. It may be playing on another device.';
  }

  @override
  String yourAccountCant(Object server) {
    return 'Your $server account can\'t watch this channel';
  }

  @override
  String cantReach(Object name) {
    return 'Can\'t reach $name';
  }

  @override
  String allOfS(Object server) {
    return 'All of $server\'s tuners are in use';
  }

  @override
  String lostTheSignal(Object name) {
    return 'Lost the signal on $name';
  }

  @override
  String get couldntPlayThat => 'Couldn\'t play that part. Back to live';

  @override
  String get backToLive => 'Back to live';

  @override
  String get theServerTookToo =>
      'The server took too long to start converting this program.';

  @override
  String get nothingToPlay => 'Nothing to play on this channel';

  @override
  String captionsOn(Object shown) {
    return 'Captions on: $shown';
  }

  @override
  String get captionsOn2 => 'Captions on';

  @override
  String get captionsOnNo => 'Captions on: no subtitles for this program';

  @override
  String get captionsOff => 'Captions off';

  @override
  String get guest => 'Guest';

  @override
  String get thereHasTo => 'There has to be at least one grown-up profile.';

  @override
  String get switchToAnother =>
      'Switch to another profile before deleting this one.';

  @override
  String get me => 'Me';

  @override
  String get couldntOpenA => 'Couldn\'t open a network port for the remote.';

  @override
  String get notPaired => 'Not paired';

  @override
  String get phone => 'Phone';

  @override
  String get thatCodeDoesnt =>
      'That code doesn\'t match. Check the code on the TV.';

  @override
  String get openMenuPhone => 'Open Menu → Phone remote on the TV to pair';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'Your $serverName account can\'t watch Live TV';
  }

  @override
  String get enterYourServer => 'Enter your server address.';

  @override
  String get needsSignIn => 'Needs sign-in';

  @override
  String get cantBeReached => 'Can\'t be reached';

  @override
  String isNotAnswering(Object name) {
    return '$name is not answering at any of its addresses. Is it on?';
  }

  @override
  String get everyServerOn =>
      'Every server on this Plex account is already in this profile.';

  @override
  String get thisPlexAccount =>
      'This Plex account has no servers. Ask the server\'s owner to share it with you.';

  @override
  String quickConnectStopped(Object message) {
    return 'Quick Connect stopped: $message';
  }

  @override
  String get enterYourUsername => 'Enter your username.';

  @override
  String get plexDidNot => 'Plex did not switch users.';

  @override
  String plexTvError(Object statusCode) {
    return 'plex.tv error $statusCode.';
  }

  @override
  String get yourPlexSign => 'Your Plex sign-in expired.';

  @override
  String couldNotReachPlex(Object e) {
    return 'Could not reach plex.tv ($e).';
  }

  @override
  String get plexTvTook => 'plex.tv took too long to respond.';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — Shared by $ownerName';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'The server would not convert this item ($transcodeDecisionText).';
  }

  @override
  String get theServerHasNo =>
      'The server has no file for this item; refresh the library.';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl did not answer like a Plex server.';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return 'No Plex server found at $serverUrl. $message';
  }

  @override
  String get thePlexSign => 'The Plex sign-in expired.';

  @override
  String channelIsNot(Object channelId) {
    return 'Channel $channelId is not on any DVR.';
  }

  @override
  String get noSuchUser => 'No such user.';

  @override
  String get yourCurrentPassword => 'Your current password is wrong.';

  @override
  String get signInFirst => 'Sign in first.';

  @override
  String thereIsAlready(Object name) {
    return 'There is already a user named $name.';
  }

  @override
  String get thisAccountIs => 'This account is turned off.';

  @override
  String get chooseAnAdmin => 'Choose an admin account.';

  @override
  String useAtMost(Object maxNameLength) {
    return 'Use at most $maxNameLength characters for the user name.';
  }

  @override
  String get enterAUser => 'Enter a user name.';

  @override
  String useAtLeast(Object minPasswordLength) {
    return 'Use at least $minPasswordLength characters.';
  }

  @override
  String get tooManyWrong => 'Too many wrong passwords. Try again in a minute.';

  @override
  String get wrongUserName => 'Wrong user name or password.';

  @override
  String get openTheSetup => 'Open the setup link from the server\'s log.';

  @override
  String get makeSomeoneElse => 'Make someone else an admin first.';

  @override
  String get noSuchProfile => 'No such profile.';

  @override
  String get onlyAnAdmin => 'Only an admin can do that.';

  @override
  String get thatProfileIsnt => 'That profile isn\'t assigned to you.';

  @override
  String get enterAGrown =>
      'Enter a grown-up\'s PIN to change a kid profile\'s settings.';

  @override
  String get enterThisProfiles => 'Enter this profile\'s PIN.';

  @override
  String get reloadThePage => 'Reload the page and try again.';

  @override
  String somethingWentWrong(Object e) {
    return 'Something went wrong: $e';
  }

  @override
  String get signInToThisProfile => 'Sign in to this profile first.';

  @override
  String get changedInAnother =>
      'Changed in another window. Showing the latest.';

  @override
  String get wrongPin => 'Wrong PIN.';

  @override
  String get tooManyWrongPins => 'Too many wrong PINs. Try again in a minute.';

  @override
  String get theRoleIs => 'The role is \"admin\" or \"user\".';

  @override
  String get noSuchBackup => 'No such backup.';

  @override
  String get backupsAreOff => 'Backups are off.';

  @override
  String get noSuchEncoder => 'No such encoder.';

  @override
  String get allow1To => 'Allow 1 to 16 streams.';

  @override
  String get noSuchQuality => 'No such quality.';

  @override
  String get processorOnly => 'Processor only';

  @override
  String get liveTvExport => 'Live TV export isn\'t running.';

  @override
  String get thoseArentPremiere => 'Those aren\'t premiere settings.';

  @override
  String get theLogoMode => 'The logo mode is always, nowAndThen or off.';

  @override
  String get thatIsntAPicture =>
      'That isn\'t a picture in the custom logos folder.';

  @override
  String couldntSaveASafety(Object e) {
    return 'Couldn\'t save a safety backup first, so nothing was reset: $e';
  }

  @override
  String get theKindIs => 'The kind is \"block\", \"music\" or \"custom\".';

  @override
  String get thatIsntAPlay => 'That isn\'t a play order.';

  @override
  String get musicChannelsOnly => 'Music channels only shuffle.';

  @override
  String get channelNumbersStart => 'Channel numbers start at 1.';

  @override
  String get slotLengthsAre =>
      'Slot lengths are 15, 30, 60, 90 or 120 minutes.';

  @override
  String get thatIsntAChannel => 'That isn\'t a channel.';

  @override
  String get noSuchChannel => 'No such channel.';

  @override
  String get thatPictureIs => 'That picture is too big (5 MB at most).';

  @override
  String get unknownAction => 'Unknown action.';

  @override
  String get noSuchServer => 'No such server.';

  @override
  String get startSigningIn => 'Start signing in first.';

  @override
  String get aRestoreIs => 'A restore is already running.';

  @override
  String get uploadTheBackup => 'Upload the backup again.';

  @override
  String get discoveryIsOff =>
      'Discovery is off, so add the tuner by address. Run the container with host networking to turn it on.';

  @override
  String get sendKeys => 'Send keys.';

  @override
  String get enterThePlaylists =>
      'Enter the playlist\'s address, or choose a playlist file';

  @override
  String get uploadTheFile => 'Upload the file again.';

  @override
  String get kidProfilesGet => 'Kid profiles get no live channels.';

  @override
  String liveTvIsAlready(Object name) {
    return '$name Live TV is already added';
  }

  @override
  String get noSuchSource => 'No such source.';

  @override
  String get thatFileIsToo => 'That file is too big (32 MB at most).';

  @override
  String get aPinIs => 'A PIN is 4 digits.';

  @override
  String get noSuchRating => 'No such rating.';

  @override
  String get noSuchKind => 'No such kind.';

  @override
  String get onlyAnAdminCan => 'Only an admin can change that.';

  @override
  String shouldBeA(Object key) {
    return '\"$key\" should be a list of text.';
  }

  @override
  String shouldBeAn(Object key) {
    return '\"$key\" should be an object.';
  }

  @override
  String shouldBeTrue(Object key) {
    return '\"$key\" should be true or false.';
  }

  @override
  String shouldBeANumber(Object key) {
    return '\"$key\" should be a number.';
  }

  @override
  String shouldBeText(Object key) {
    return '\"$key\" should be text.';
  }

  @override
  String get expectedAJson => 'Expected a JSON object.';

  @override
  String get thatIsToo => 'That is too much to send at once.';

  @override
  String get aQualityLimit => 'A quality limit is at least 500 kbps.';

  @override
  String get orderShouldName => '\"order\" should name every server once.';

  @override
  String get orderIsMissing => '\"order\" is missing.';

  @override
  String get signOutOf => 'Sign out of the profile to change its main server.';

  @override
  String get thoseArentPool => 'Those aren\'t pool folders.';

  @override
  String get sendRoots => 'Send roots.';

  @override
  String get thatIsntAPool => 'That isn\'t a pool type.';

  @override
  String get giveThePool => 'Give the pool a name.';

  @override
  String get liveChannelsHave => 'Live channels have no breaks.';

  @override
  String get sendAPlan => 'Send a plan.';

  @override
  String get thatIsntABreak => 'That isn\'t a break plan.';

  @override
  String get noSuchPool => 'No such pool.';

  @override
  String get thatIsntAProgramming => 'That isn\'t a programming block.';

  @override
  String get noSuchBlock => 'No such block.';

  @override
  String get sendEveryTab => 'Send every tab once.';

  @override
  String get sendChannelids => 'Send channelIds.';

  @override
  String get giveTheGroup => 'Give the group a name.';

  @override
  String get noSuchGroup => 'No such group.';

  @override
  String get restoringBringsBack =>
      'Restoring brings back your profiles, channels, blocks and settings. Each profile signs in to its server once.';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels channels',
      one: '$profiles · $channels channel',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup => 'There\'s a backup of your setup on this device:';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get moveOkSelect => '◀▶ Move    OK Select';

  @override
  String get startFresh => 'Start fresh';

  @override
  String get restoreIt => 'Restore it';

  @override
  String get couldntRestore => 'Couldn\'t restore';

  @override
  String get cancel => 'Cancel';

  @override
  String get useYourPhone => 'Use your phone or computer';

  @override
  String get openABackup => 'Open a backup file';

  @override
  String get setUpThis =>
      'Set up this TV from a Nightingale TV backup: your profiles, channels, blocks and settings. Each profile signs in to its server once.';

  @override
  String get restoreFromA => 'Restore from a backup';

  @override
  String get close => 'Close';

  @override
  String get thereYouCan =>
      'There you can download a backup of this TV, or send one to restore here. Anything sent is confirmed on this TV first. The page closes with this window.';

  @override
  String get onAPhone =>
      'On a phone, tablet or computer on the same Wi-Fi as this TV, scan the code or open:';

  @override
  String get couldntOpenANetwork =>
      'Couldn\'t open a network port for the page.';

  @override
  String get thePageStopped =>
      'The page stopped after 15 minutes with nothing to do. Close this and open it again.';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount and $last';
  }

  @override
  String get restore => 'Restore';

  @override
  String get liveTvExportMoves =>
      'Live TV export moves to this device; turn it off on the old one.';

  @override
  String willNeedTo(Object need) {
    return '$need will need to sign in to their server again.';
  }

  @override
  String get itSetsUp => 'It sets up this TV as the backup has it.';

  @override
  String get itReplacesEverything =>
      'It replaces everything on this TV. Your current setup is backed up first.';

  @override
  String restoreTheBackup(Object toLocal) {
    return 'Restore the backup from $toLocal?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get saveToFile => 'Save to file';

  @override
  String madeOn(Object device) {
    return 'Made on $device';
  }

  @override
  String get moveOkSelectEsc => '▲▼◀▶ Move    OK Select    ESC Back';

  @override
  String get backupRestore => 'Backup & restore';

  @override
  String get backups => 'BACKUPS';

  @override
  String get backUpNow => 'Back up now';

  @override
  String get aBackupHolds =>
      'A backup holds every profile with its channels, blocks, commercials and settings, and is made every day something changes. Sign-in passwords are never in it.';

  @override
  String lastBackup(Object toLocal, Object kindLabel) {
    return 'Last backup: $toLocal ($kindLabel).';
  }

  @override
  String get noBackupsYet => 'No backups yet.';

  @override
  String itCantBe(Object toLocal, Object kindLabel) {
    return '$toLocal · $kindLabel. It can\'t be brought back.';
  }

  @override
  String get deleteThisBackup => 'Delete this backup?';

  @override
  String couldntSaveThe(Object e) {
    return 'Couldn\'t save the backup: $e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'That didn\'t work: $e';
  }

  @override
  String get aNewChannel =>
      'A new channel is off the air outside the block, like a channel that signs off at night.';

  @override
  String get aNewChannelJust => 'A new channel just for this block';

  @override
  String get moveOkChoose => '▲▼ Move    OK Choose    ESC Back';

  @override
  String get chooseAChannel2 => 'Choose a channel';

  @override
  String episodes(Object keyCount) {
    return '$keyCount episodes';
  }

  @override
  String get moveOkAdd => '▲▼ Move    OK Add    ESC Back';

  @override
  String get addAShow2 => 'Add a show';

  @override
  String get remove => 'Remove';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '$count episode',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ Month';

  @override
  String get day => '+ Day';

  @override
  String get day2 => '− Day';

  @override
  String get month2 => '− Month';

  @override
  String get save => 'Save';

  @override
  String get everyDay => 'Every day';

  @override
  String get weekends => 'Weekends';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get days => 'DAYS';

  @override
  String get starts => 'Starts';

  @override
  String get time => 'TIME';

  @override
  String get premieresAreOff => 'Premieres are off';

  @override
  String get premieresAreOn => 'Premieres are on';

  @override
  String get onTheAir => 'ON THE AIR';

  @override
  String get episodesAddedTo =>
      'Episodes added to your server in the last two weeks premiere in a nightly slot on their show\'s channel: one new episode per show each night, for up to two hours, marked NEW. Programming blocks come first.';

  @override
  String get moveOkSelectEscCancel => '▲▼◀▶ Move    OK Select    ESC Cancel';

  @override
  String get newEpisodePremieres => 'New episode premieres';

  @override
  String get theChannelGoes =>
      'The channel goes back to its regular programming at these times.';

  @override
  String delete2(Object title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get addAnotherShow => 'Add another show';

  @override
  String get missingShow => 'Missing show';

  @override
  String runsThenStarts(Object start) {
    return 'Runs $start, then starts over.';
  }

  @override
  String get fillsTheBlock => 'Fills the block.';

  @override
  String longerThanThe(Object end, Object title) {
    return 'Longer than the block: it ends at $end, cutting off $title.';
  }

  @override
  String get onTheAirNow => 'ON THE AIR NOW';

  @override
  String nextAiring(Object start) {
    return 'NEXT AIRING · $start';
  }

  @override
  String inAll(Object runtime) {
    return '$runtime in all';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies movies',
      one: '$movies movie',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount shows',
      one: '$showsCount show',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => 'Nothing yet. Choose shows or movies.';

  @override
  String get nothingYetAdd => 'Nothing yet. Add shows to the lineup.';

  @override
  String get plays => 'PLAYS';

  @override
  String onLabel(Object number, Object name) {
    return 'On $number $name';
  }

  @override
  String get noChannelChosen => 'No channel chosen';

  @override
  String get onANew => 'On a new channel (off the air at other times)';

  @override
  String get untitledBlock => 'Untitled block';

  @override
  String get deleteBlock => 'Delete block';

  @override
  String get blockIsOff => 'Block is off';

  @override
  String get blockIsOn => 'Block is on';

  @override
  String get onlyShowsAnd =>
      'Only shows and movies rated this or higher. Unrated ones are left out.';

  @override
  String get anyRating => 'Any rating';

  @override
  String get minimumRating => 'Minimum rating';

  @override
  String get chooseShowsMovies => 'Choose shows & movies';

  @override
  String get showsAndMovies =>
      'Shows and movies you choose, in order or shuffled.';

  @override
  String get yourShowsIn =>
      'Your shows in this order, each playing its next episode every airing. If time is left, the lineup starts over.';

  @override
  String get aLineup => 'A lineup';

  @override
  String get aMix => 'A mix';

  @override
  String get whatItPlays => 'WHAT IT PLAYS';

  @override
  String get repeatsEveryYear => 'Repeats every year.';

  @override
  String get to => 'To';

  @override
  String get from => 'From';

  @override
  String get onlyBetweenDates => 'Only between dates';

  @override
  String get allYear => 'All year';

  @override
  String get dates => 'DATES';

  @override
  String get nextDay => ' (next day)';

  @override
  String get ends => 'Ends';

  @override
  String get channel => 'CHANNEL';

  @override
  String get saturdayMorningCartoons => 'Saturday Morning Cartoons';

  @override
  String get title => 'Title';

  @override
  String get newProgrammingBlock => 'New programming block';

  @override
  String get newLateNight => 'New late-night block';

  @override
  String get editProgrammingBlock => 'Edit programming block';

  @override
  String next(Object next, Object next2) {
    return 'Next: $next $next2';
  }

  @override
  String get onTheAirNow2 => 'On the air now';

  @override
  String get noUpcomingAirings => 'No upcoming airings';

  @override
  String get itsChannelIs => 'Its channel is gone. Pick a new one.';

  @override
  String get turnedOff => 'Turned off';

  @override
  String get blocksTakeOver =>
      'Blocks take over a channel on the days and times you choose, like Saturday morning cartoons. Each airing picks up where the last one left off.';

  @override
  String get moveOkEdit => '▲▼ Move    OK Edit    ESC Back';

  @override
  String get programmingBlocks => 'Programming blocks';

  @override
  String get newlyAddedEpisodes =>
      'Newly added episodes, on their show\'s channel';

  @override
  String get onLabel2 => 'On';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips clips',
      one: '$name  ·  $clips clip',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => '100-min movie';

  @override
  String get n44MinDrama => '44-min drama';

  @override
  String get n22MinSitcom => '22-min sitcom';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: ', $midCount breaks inside',
      one: ', $midCount break inside',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name: no breaks';
  }

  @override
  String get openAndClose => 'Open and close breaks, from pools set to Bumpers';

  @override
  String get bumpers2 => 'BUMPERS';

  @override
  String get toTheHalf => 'To the half hour';

  @override
  String get toTheHour => 'To the hour';

  @override
  String get padsEachSlot =>
      'Pads each slot to the clock, so programs start on time';

  @override
  String get tail2 => 'TAIL';

  @override
  String get afterEachProgram => 'After each program';

  @override
  String get postRoll2 => 'POST-ROLL';

  @override
  String get length => 'Length';

  @override
  String get every => 'Every';

  @override
  String min(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get breaksInsideShows =>
      'Breaks inside shows and movies, at act breaks when they can be found';

  @override
  String get midRoll2 => 'MID-ROLL';

  @override
  String get beforeEachProgram => 'Before each program';

  @override
  String get preRoll2 => 'PRE-ROLL';

  @override
  String get onePool => 'One pool…';

  @override
  String get allBumperPools => 'All bumper pools';

  @override
  String get none => 'None';

  @override
  String clipsFrom(Object pool) {
    return 'Clips from: $pool';
  }

  @override
  String get allPools => 'All pools';

  @override
  String clips2(Object label) {
    return '$label clips';
  }

  @override
  String get leave => 'Leave';

  @override
  String get yourChangesTo => 'Your changes to the break settings are lost.';

  @override
  String get leaveWithoutSaving => 'Leave without saving?';

  @override
  String get size => 'Size';

  @override
  String get captions => 'Captions';

  @override
  String get sampleCaption => 'Sample caption';

  @override
  String get theServerDraws =>
      'The server draws these captions into the picture, so their size can\'t change here.';

  @override
  String get findingSubtitles => 'Finding subtitles…';

  @override
  String get noSubtitlesFor => 'No subtitles for this program';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours hr $inMinutes min';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed days';
  }

  @override
  String get theChannelGoesAway =>
      'The channel goes away, with its programming blocks and its places in channel groups.';

  @override
  String remove2(Object name) {
    return 'Remove \"$name\"?';
  }

  @override
  String contentOf(Object name) {
    return 'Content of $name';
  }

  @override
  String get newChannel => 'New channel';

  @override
  String get defaultCard => 'Default card';

  @override
  String get changeOfflineImage => 'Change offline image…';

  @override
  String get offlineImage2 => 'Offline image…';

  @override
  String fillerPool(Object poolName) {
    return 'Filler pool: $poolName';
  }

  @override
  String get slotLength => 'SLOT LENGTH';

  @override
  String get hideFromGuide => 'Hide from guide';

  @override
  String get showInGuide => 'Show in guide';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String mainSetting(Object label) {
    return 'Main setting ($label)';
  }

  @override
  String get channelLogo => 'CHANNEL LOGO';

  @override
  String breaksOn(Object name) {
    return 'Breaks on $name';
  }

  @override
  String get custom2 => 'Custom…';

  @override
  String get commercials2 => 'COMMERCIALS';

  @override
  String get removeChannel => 'Remove channel';

  @override
  String get reshuffle => 'Reshuffle';

  @override
  String get editContent => 'Edit content';

  @override
  String get number => 'Number +';

  @override
  String get number2 => 'Number −';

  @override
  String get sourcesLogo => 'Source\'s logo';

  @override
  String get changeIcon => 'Change icon';

  @override
  String get rename => 'Rename';

  @override
  String get channelName => 'Channel name';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount programming blocks',
      one: '$blockCount programming block',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return 'repeats every $loop';
  }

  @override
  String programs(Object playlistCount) {
    return '$playlistCount programs';
  }

  @override
  String get programmingBlocksOnly => 'Programming blocks only';

  @override
  String channelThere(Object n) {
    return 'channel $n there';
  }

  @override
  String channel2(Object number) {
    return 'CHANNEL $number';
  }

  @override
  String get noChannelsYet => 'No channels yet';

  @override
  String get guideRange => 'GUIDE RANGE';

  @override
  String get channelsEditOk => '▲▼ Channels    ▶ Edit    OK Select    ESC Back';

  @override
  String get channelsIcons => 'Channels & icons';

  @override
  String get howFarAhead => 'How far ahead the guide shows, from now.';

  @override
  String hours(Object hours) {
    return '$hours hours';
  }

  @override
  String get theChannelLogo =>
      'The channel logo in the corner of the picture, on the TV and in Live TV export.';

  @override
  String get name => 'Name';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'CHANNELS';

  @override
  String get groupName => 'Group name';

  @override
  String group(Object name) {
    return 'Group: $name';
  }

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get itsTabLeaves =>
      'Its tab leaves the guide. The channels stay in your lineup.';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount channels',
      one: '$membersCount channel',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => 'Channels you picked.';

  @override
  String get theTabsAt =>
      'The tabs at the top of the guide, in this order. Hidden tabs and tabs with no channels aren\'t shown.';

  @override
  String get channelGroups => 'Channel groups';

  @override
  String get shown => 'Shown';

  @override
  String get down => 'Down';

  @override
  String get up => 'Up';

  @override
  String get automatic2 => '· automatic';

  @override
  String channels4(Object channelIdsCount) {
    return '· $channelIdsCount channels';
  }

  @override
  String get create => 'Create';

  @override
  String get commercialsNeverShow =>
      'Commercials never show up in your server\'s watch history.';

  @override
  String get theSameAds => 'The same ads play for everyone, every time.';

  @override
  String get bumperPoolsClips =>
      'Bumper pools\' clips open and close breaks, and never play as ads.';

  @override
  String get howBreaksWork => 'HOW BREAKS WORK';

  @override
  String get withATail => 'With a tail, slots are padded out to the clock.';

  @override
  String get adsShrinkTo =>
      'Ads shrink to fit the slot, and no break runs over 5 minutes.';

  @override
  String get aShortBreak =>
      'A short break before the show, a break every 10 minutes inside it (12 for movies), at act breaks when they can be found, and the rest after it.';

  @override
  String get pickAutomaticFor =>
      'Pick Automatic for breaks like broadcast TV, or Custom to set them up yourself.';

  @override
  String workingOn(Object current) {
    return 'Working on $current…';
  }

  @override
  String get analysis => 'ANALYSIS';

  @override
  String couldNotBe(Object failed) {
    return '$failed could not be analyzed (they\'re tried again if the file changes)';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'Programs with break points: $programsDone of $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return 'Long videos split: $reelsDone of $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders folders  ·  $idCount',
      one: '$folders folder  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$clips from $used commercial pools.',
      one: '$clips from $used commercial pool.',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'Breaks start once a pool has clips. Add folders with videos to a pool.';

  @override
  String get breaksStartOnceA =>
      'Breaks start once a pool has clips. Its long videos are being split now.';

  @override
  String get breaksStartOnceAPool =>
      'Breaks start once a pool has clips. Make a pool below.';

  @override
  String breaksAreOff(Object clips) {
    return 'Breaks are off. $clips ready in your pools.';
  }

  @override
  String get breaksAreOff2 => 'Breaks are off.';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n clips',
      one: '$n clip',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return 'Last scan failed: $syncError';
  }

  @override
  String get newPool => 'New pool';

  @override
  String get pickTheFolders =>
      'Pick the folders on your server that hold commercials and bumpers. Their videos leave your regular channels and fill the breaks instead. Set a pool\'s type to Bumpers to have its clips open and close breaks.';

  @override
  String get pools => 'POOLS';

  @override
  String get breakSettings => 'Break settings…';

  @override
  String get commercialBreaks => 'COMMERCIAL BREAKS';

  @override
  String get breakSettings2 => 'Break settings';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count Break points also land more naturally with it.';
  }

  @override
  String waiting(Object waiting) {
    return ' ($waiting waiting).';
  }

  @override
  String get longCommercialVideos =>
      'Long commercial videos without chapters can\'t be split on this device';

  @override
  String get installFfmpegTo =>
      'Install ffmpeg to split long commercial videos';

  @override
  String get picturesOnThis =>
      'Pictures on this device, newest first. Big ones are shrunk to 512 px.';

  @override
  String get noPicturesOn =>
      'No pictures on this device yet. Copy a PNG or JPG to its Download folder or onto a USB drive, then try again.';

  @override
  String get lookingForPictures => 'Looking for pictures…';

  @override
  String get couldntReadThePictures =>
      'Couldn\'t read the pictures on this device.';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV isn\'t allowed to see the pictures on this device. Allow \"Photos and videos\" for it in Android\'s Settings › Apps › Nightingale TV › Permissions, then try again.';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ Move    OK Choose    ESC Cancel';

  @override
  String get chooseAPicture => 'Choose a picture';

  @override
  String thePoolHasnt(Object error) {
    return '$error  The pool hasn\'t changed.';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  Nothing has changed.';
  }

  @override
  String get couldntReachTheServer => 'Couldn\'t reach the server';

  @override
  String get tryAgain => 'Try again';

  @override
  String get nothingInside => 'Nothing inside';

  @override
  String get noMovies => 'No movies';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount inside';
  }

  @override
  String get video => 'Video';

  @override
  String collection(Object name) {
    return '$name (collection)';
  }

  @override
  String get included => 'Included';

  @override
  String get nothingInside2 => 'Nothing inside.';

  @override
  String get loadingFolders => 'Loading folders…';

  @override
  String get pressOnA => 'Press ▶ on a library to see what\'s in it.';

  @override
  String get done => 'Done';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount ticked';
  }

  @override
  String get nothingTickedYet =>
      'Nothing ticked yet. Tick a library to use all of it, or ▶ to pick what\'s in it.';

  @override
  String get wholeLibrary => 'Whole library';

  @override
  String get libraries => 'LIBRARIES';

  @override
  String get loadingLibraries => 'Loading libraries…';

  @override
  String get moveOkTick =>
      '▲▼ Move    OK Tick    ▶ Open    ◀ Back up    ESC Cancel';

  @override
  String foldersFor(Object poolName) {
    return 'Folders for $poolName';
  }

  @override
  String get chooseFolders => 'Choose folders';

  @override
  String get chooseWhatPlays => 'Choose what plays on this channel';

  @override
  String get endsEarly => 'Ends early';

  @override
  String get madeFromThis =>
      'Made from this channel\'s shows and movies, and updated with the library. Change anything and it becomes yours.';

  @override
  String get fromTheLineup => 'From the lineup';

  @override
  String yesterday(Object t) {
    return 'yesterday $t';
  }

  @override
  String today(Object t) {
    return 'today $t';
  }

  @override
  String behind(Object d) {
    return '$d behind';
  }

  @override
  String hr(Object h) {
    return '$h hr';
  }

  @override
  String get underAMinute => 'under a minute';

  @override
  String get noProgramming => 'No programming';

  @override
  String get today2 => 'TODAY';

  @override
  String get tuning => 'TUNING…';

  @override
  String get offAir2 => 'OFF AIR';

  @override
  String get noSignal => 'NO SIGNAL';

  @override
  String left(Object now) {
    return '$now left';
  }

  @override
  String get nothingScheduled => 'Nothing scheduled';

  @override
  String get back => 'Back';

  @override
  String get sleep => 'Sleep';

  @override
  String get menu => 'Menu';

  @override
  String get nightingaleTvGuide => 'NIGHTINGALE TV GUIDE';

  @override
  String nowPlaying(Object title) {
    return 'Now playing: $title';
  }

  @override
  String get mMenu => 'M Menu';

  @override
  String get escBackTo => 'ESC Back to TV';

  @override
  String get channelsTabsTime =>
      '▲▼ Channels     ▲ Tabs     ◀▶ Time     OK Watch     ';

  @override
  String get color => 'Color';

  @override
  String get channelsUsingIt => 'Channels using it go back to a default icon.';

  @override
  String get deleteThisIcon => 'Delete this icon?';

  @override
  String get uploadImage => 'Upload image…';

  @override
  String get pngJpgWebp =>
      'PNG, JPG, WebP, GIF or SVG. Big images are shrunk to 512 px automatically.';

  @override
  String get genericBadgesOnly =>
      'Generic badges only. Upload a real network logo under \"My icons\".';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'Use this badge';

  @override
  String get preview => 'Preview';

  @override
  String get shape => 'Shape';

  @override
  String get callLettersUp => 'Call letters (up to 5)';

  @override
  String iconFor(Object name) {
    return 'Icon for $name';
  }

  @override
  String get couldntReadThat => 'Couldn\'t read that picture. Try another one.';

  @override
  String get myIcons => 'My icons';

  @override
  String get showLogos => 'Show logos';

  @override
  String get badges => 'Badges';

  @override
  String get builtIn => 'Built-in';

  @override
  String get couldntMoveThe => 'Couldn\'t move the setup';

  @override
  String get send => 'Send';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'This backs up your profiles, channels and settings now and opens them in $counterpartName, which asks before restoring them. Nothing changes here.';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return 'Send your setup to $counterpartName?';
  }

  @override
  String get parentalControls => 'Parental controls';

  @override
  String get notNow => 'Not now';

  @override
  String bringMySetup(Object counterpartName) {
    return 'Bring my setup here from $counterpartName';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return 'Move my setup to $counterpartName';
  }

  @override
  String get uninstallingEitherOne =>
      'Uninstalling either one before moving the setup you want to keep deletes that setup.';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName and $counterpartName are separate apps, each with its own profiles, channels and settings.';
  }

  @override
  String get thankYouFor => 'Thank you for supporting Nightingale TV!';

  @override
  String isAlsoOn(Object counterpartName) {
    return '$counterpartName is also on this device';
  }

  @override
  String get aboutThisInstall => 'ABOUT THIS INSTALL';

  @override
  String couldntOpen(Object counterpartName) {
    return 'Couldn\'t open $counterpartName.';
  }

  @override
  String get nothingIsSet =>
      'Nothing is set up here yet, so there\'s no setup to move.';

  @override
  String yourSetupIs(Object counterpartName) {
    return 'Your setup is on its way to $counterpartName';
  }

  @override
  String get guide => 'GUIDE';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n of $keysCount';
  }

  @override
  String get saving => 'Saving…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$_checkedCount of $total chosen';
  }

  @override
  String get channelOrGroup => 'Channel or group name';

  @override
  String get search => 'Search';

  @override
  String get moveOkCheck => '▲▼ Move    OK Check    ESC Back';

  @override
  String chooseChannels(Object name) {
    return 'Choose channels: $name';
  }

  @override
  String get add => 'Add';

  @override
  String get readingThePlaylist => 'Reading the playlist…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return 'Now: the playlist\'s guide, $guideUrl';
  }

  @override
  String get leaveEmptyTo => 'Leave empty to use the guide the playlist names';

  @override
  String get xmltvGuideAddress => 'XMLTV guide address';

  @override
  String get guideOptional => 'GUIDE (OPTIONAL)';

  @override
  String get httpProviderExample =>
      'http://provider.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'Playlist address';

  @override
  String get playlist => 'PLAYLIST';

  @override
  String get myIptv => 'My IPTV';

  @override
  String get useAnAddress => 'Use an address instead';

  @override
  String get chooseAFile => 'Choose a file';

  @override
  String get chooseAnotherFile => 'Choose another file';

  @override
  String get moveOkSelectEscBack => '▲▼ Move    OK Select    ESC Back';

  @override
  String edit(Object name) {
    return 'Edit $name';
  }

  @override
  String get addAnM3u => 'Add an M3U playlist';

  @override
  String get m3uPlaylists => 'M3U playlists';

  @override
  String get xmltvGuides => 'XMLTV guides';

  @override
  String get anIptvPlaylist =>
      'An IPTV playlist (a web address or a file), with an XMLTV guide if you have one.';

  @override
  String get theChannelsAnd =>
      'The channels and guide of your server\'s tuner (an antenna, cable box or IPTV it has).';

  @override
  String readingSChannels(Object server) {
    return 'Reading $server\'s channels…';
  }

  @override
  String checkingLiveTv(Object server) {
    return 'Checking $server Live TV…';
  }

  @override
  String get addALive => 'Add a Live TV source';

  @override
  String get itsChannelsLeave =>
      'Its channels leave the guide, their groups and favorites.';

  @override
  String get renameSource => 'Rename source';

  @override
  String get edit2 => 'Edit';

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get chooseChannels2 => 'Choose channels';

  @override
  String get playlistFile => 'Playlist file';

  @override
  String get notRefreshedYet => 'Not refreshed yet';

  @override
  String refreshed(Object lastRefresh) {
    return 'Refreshed $lastRefresh';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return 'Last refresh failed: $lastError';
  }

  @override
  String get refreshing => 'Refreshing…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · $keyCount of $channelsCount channels';
  }

  @override
  String get noSourcesYet => 'No sources yet.';

  @override
  String get addSource => 'Add source';

  @override
  String get realBroadcastsAnd =>
      'Real broadcasts and IPTV in your guide: your server\'s Live TV, or an M3U playlist with an XMLTV guide. Their channels join the lineup after yours.';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return 'Not streaming. $runningCount of $streamLimit streams in use.';
  }

  @override
  String get savePort => 'Save port';

  @override
  String get port => 'Port';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'Tuner';

  @override
  String get enterAPort => 'Enter a port number.';

  @override
  String pinFor(Object name) {
    return 'PIN for $name';
  }

  @override
  String get letPlexFind => 'Let Plex find it automatically';

  @override
  String get discovery => 'DISCOVERY';

  @override
  String get encoder => 'ENCODER';

  @override
  String nowAtOnce(Object streamLimit) {
    return 'Now: $streamLimit at once. Each channel being watched elsewhere is one stream.';
  }

  @override
  String get streamsAtOnce => 'STREAMS AT ONCE';

  @override
  String get quality => 'QUALITY';

  @override
  String get lineups => 'LINEUPS';

  @override
  String get liveTvExport2 => 'Live TV export';

  @override
  String get automaticDiscoveryIsnt =>
      'Automatic discovery isn\'t available on this PC. Add the tuner in Plex or Jellyfin by its address.';

  @override
  String get anyoneOnYour =>
      'Anyone on your home network can watch this lineup.';

  @override
  String get watchYourChannels =>
      'Watch your channels in Plex, Jellyfin or any IPTV app on your home network. Nightingale TV has to stay open for them to play.';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get added => 'Added';

  @override
  String get chooseAServer => 'Choose a server';

  @override
  String get whosSigningIn => 'Who\'s signing in?';

  @override
  String get openPlexTv => 'Open plex.tv/link';

  @override
  String get waitingForThe => 'Waiting for the code to be linked…';

  @override
  String get goToPlex =>
      'Go to plex.tv/link on your phone or computer and enter this code.';

  @override
  String get signInWith => 'Sign in with Plex';

  @override
  String get waitingForApproval => 'Waiting for approval…';

  @override
  String onYourPhone(Object label) {
    return 'On your phone or computer, open $label → your profile → Quick Connect, and enter this code:';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'Sign in';

  @override
  String get password => 'Password';

  @override
  String get username => 'Username';

  @override
  String signInTo2(Object name) {
    return 'Sign in to $name';
  }

  @override
  String get differentServer => 'Different server';

  @override
  String get signInWithPassword => 'Sign in with password';

  @override
  String get quickConnectUse => 'Quick Connect (use your phone)';

  @override
  String get connect => 'Connect';

  @override
  String get serverAddress => 'Server address';

  @override
  String get connectToYour => 'Connect to your server';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV turns your Jellyfin, Emby or Plex library into always-on channels with a program guide. Flip around and catch whatever is on.';

  @override
  String get yourLibraryOn => 'Your library.\nOn the air, 24/7.';

  @override
  String get welcomeToNightingale => 'Welcome to Nightingale TV';

  @override
  String signInFor(Object name) {
    return 'Sign in for $name';
  }

  @override
  String signInToAgain(Object name) {
    return 'Sign in to $name again';
  }

  @override
  String get addAServer => 'Add a server';

  @override
  String foundNewPrograms(Object list) {
    return 'Found $list. New programs start airing on their channels right after what\'s on now.';
  }

  @override
  String get libraryRefreshed => 'Library refreshed';

  @override
  String get nothingNew => 'Nothing new';

  @override
  String get yourChannelsAre => 'Your channels are up to date.';

  @override
  String get refreshFailed => 'Refresh failed';

  @override
  String get moveOkSelectEscBackTo => '▲▼ Move    OK Select    ESC Back to TV';

  @override
  String get noPoolsYet => 'no pools yet';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return 'Updated $fetchedAt at $fetchedAt2';
  }

  @override
  String get libraryLabel => 'LIBRARY';

  @override
  String get account => 'ACCOUNT';

  @override
  String get watching => 'WATCHING';

  @override
  String get exitNightingaleTv => 'Exit Nightingale TV';

  @override
  String get signOut => 'Sign out';

  @override
  String get yourChannelLineup =>
      'Your channel lineup is cleared. Custom icons are kept.';

  @override
  String get signOut2 => 'Sign out?';

  @override
  String get fullScreenOn => 'Full screen on/off (F11)';

  @override
  String get nothingWasReset => 'Nothing was reset';

  @override
  String get reset => 'Reset';

  @override
  String get rebuildsTheDefault =>
      'Rebuilds the default channels from your library. Names, icons and numbers you changed are reset. Channels you added are kept. A backup is saved first, so you can bring them back in Backup & restore.';

  @override
  String get resetChannelLineup => 'Reset channel lineup?';

  @override
  String get resetChannelLineup2 => 'Reset channel lineup';

  @override
  String get refreshLibrary => 'Refresh library';

  @override
  String get refreshingLibrary => 'Refreshing library…';

  @override
  String get servers => 'Servers';

  @override
  String get phoneRemote => 'Phone remote';

  @override
  String get profiles => 'Profiles';

  @override
  String get retroLook => 'Retro look';

  @override
  String get playback => 'Playback';

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get backToTv => 'Back to TV';

  @override
  String get removeAll => 'Remove all';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return 'paired $paired · last used $lastUsed';
  }

  @override
  String get noPhonesPaired => 'No phones paired yet.';

  @override
  String get pairedPhones => 'PAIRED PHONES';

  @override
  String get blockedByThis => 'Blocked by this computer\'s firewall';

  @override
  String get someWiFi =>
      'Some Wi-Fi networks keep devices apart (called AP or client isolation). If the phone still can\'t connect, turn that setting off for your Wi-Fi.';

  @override
  String get thePhoneHas =>
      'The phone has to be on the same Wi-Fi as this TV, not a guest network or mobile data.';

  @override
  String get ifThePhone =>
      'If the phone can\'t connect, this computer\'s firewall may be blocking it. Open a terminal on this computer and run:';

  @override
  String get checkAgain => 'Check again';

  @override
  String get thenChooseCheck => 'Then choose Check again.';

  @override
  String get thisComputersFirewall =>
      'This computer\'s firewall stops phones from reaching the remote. To let them in, open a terminal on this computer and run:';

  @override
  String get notConfirmedYet => 'Not confirmed yet · no phone has connected';

  @override
  String get working => 'Working';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return 'Working · last used by $name, $lastUsed';
  }

  @override
  String get theRemoteIs => 'The remote is off.';

  @override
  String get orScanThe => 'or scan the code with the phone\'s camera.';

  @override
  String get andEnter => 'and enter  ';

  @override
  String get onYourPhoneOpen => 'ON YOUR PHONE, OPEN';

  @override
  String get useYourPhoneAs =>
      'Use your phone as the remote: open a web page on it to change channels, bring up the guide, or tap a channel to tune in. Nothing to install.';

  @override
  String get everyPairedPhone =>
      'Every paired phone stops working as a remote until it scans the code on this screen again.';

  @override
  String get removeAllPhones => 'Remove all phones?';

  @override
  String get thoseDidntMatch => 'Those didn\'t match. Try again.';

  @override
  String get enterTheSame => 'Enter the same 4 digits again.';

  @override
  String get choose4Digits => 'Choose 4 digits.';

  @override
  String get thatPinIsnt => 'That PIN isn\'t right. Try again.';

  @override
  String get clock => 'CLOCK';

  @override
  String get captions2 => 'CAPTIONS';

  @override
  String get audio => 'AUDIO';

  @override
  String get maximumStreamingBitrate => 'MAXIMUM STREAMING BITRATE';

  @override
  String get converting => 'CONVERTING';

  @override
  String get afterThisLong =>
      'After this long with no button pressed, Nightingale TV asks if anyone is watching. With no answer in a minute, it goes to sleep: playback stops and your server stops streaming. Not while a sleep timer is set.';

  @override
  String get askIfIm => 'Ask if I\'m still watching';

  @override
  String get liveTvStill => 'Live TV still shows on the dashboard.';

  @override
  String get offWhatYou =>
      'Off: what you watch here never changes play counts, watched marks or resume points on your server, and doesn\'t show on its dashboard.';

  @override
  String get pauseSkipAnd =>
      'Pause, skip and restart what\'s on. Off: every channel stays on the clock, like always-on TV.';

  @override
  String get pauseAndRewind => 'Pause and rewind';

  @override
  String get showsTheTime => 'Shows the time in the corner of the picture.';

  @override
  String get onScreenClock => 'On-screen clock';

  @override
  String get showACountdown =>
      'Show a countdown before commercials start and before the program comes back.';

  @override
  String get breakNotices => 'Break notices';

  @override
  String get theSizeOf => 'The size of captions on every program and channel.';

  @override
  String get whileItsOn =>
      'While it\'s on, surround audio (Dolby, DTS) is decoded by this device instead of being passed through to a receiver.';

  @override
  String get evensOutThe =>
      'Evens out the volume as you watch: loud commercials and programs are turned down and quiet ones turned up, so you don\'t have to reach for the remote.';

  @override
  String get volumeLeveling => 'Volume leveling';

  @override
  String get pickALower =>
      'Pick a lower bitrate if shows buffer or stutter over Wi-Fi or a remote connection. Original never converts because of bitrate.';

  @override
  String get connectedThroughPlex =>
      'Connected through Plex Relay; quality is limited.';

  @override
  String get offNightingaleTv =>
      'Off: Nightingale TV always plays your original files at full quality, and your server does no extra work. On: your server converts a show or movie only when it\'s above the maximum bitrate, or when the original file won\'t play. Converting uses your server\'s processor or graphics card. Commercials always play the original files.';

  @override
  String get transcodeOnlyIf => 'Transcode only if needed (experimental)';

  @override
  String get longerVideosAd =>
      'Longer videos (ad compilations) are split into their ads, at chapters or where the picture goes black and silent.';

  @override
  String get videosOf5 => 'Videos of 5 seconds to 3 minutes are one clip each.';

  @override
  String get commercialsFillBreaks =>
      'Commercials fill breaks. Set the type to Bumpers for station idents and \"we\'ll be right back\" clips.';

  @override
  String get bumpersTakeAt =>
      'Bumpers take at most half of a break, except in a pre-roll. One too long for that is skipped.';

  @override
  String stillToSplit(Object unsplit) {
    return '$unsplit still to split';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount long ones split into clips',
      one: '$reelsCount long one split into clips',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'Delete pool';

  @override
  String get addFolders => 'Add folders…';

  @override
  String get libraryLabel2 => 'Library';

  @override
  String get noFoldersYet => 'No folders yet.';

  @override
  String get folders2 => 'FOLDERS';

  @override
  String get type => 'TYPE';

  @override
  String get poolName => 'Pool name';

  @override
  String get commercialPool => 'Commercial pool';

  @override
  String get itsVideosGo =>
      'Its videos go back to your regular channels. Breaks that drew from it use all pools instead.';

  @override
  String get now => 'Now';

  @override
  String get watch => 'Watch';

  @override
  String get tuning2 => 'Tuning…';

  @override
  String get fullScreen => 'Full screen';

  @override
  String get noChannels => 'No channels';

  @override
  String get theirChannelsProgramming =>
      'Their channels, programming blocks and settings are deleted, and this TV is signed out of their server.';

  @override
  String delete3(Object name) {
    return 'Delete $name?';
  }

  @override
  String get giveTheProfile => 'Give the profile a name.';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String get removePin => 'Remove PIN';

  @override
  String get setAPin => 'Set a PIN';

  @override
  String get changePin => 'Change PIN';

  @override
  String get noPinAnyone => 'No PIN. Anyone can open this profile.';

  @override
  String get lockedThePin => 'Locked. The PIN is needed to open this profile.';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith =>
      'Shows and movies with no rating are left out.';

  @override
  String get allowedToWatch => 'ALLOWED TO WATCH';

  @override
  String get kid => 'Kid';

  @override
  String get grownUp => 'Grown-up';

  @override
  String get whoItsFor => 'WHO IT\'S FOR';

  @override
  String get color2 => 'COLOR';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get newProfile => 'New profile';

  @override
  String get watchingNow => 'Watching now';

  @override
  String get noPin => 'No PIN';

  @override
  String get pinLocked => 'PIN locked';

  @override
  String kid2(Object label, Object description) {
    return 'Kid · $label ($description)';
  }

  @override
  String get addProfile => 'Add profile';

  @override
  String get everyoneGetsTheir =>
      'Everyone gets their own server sign-in, channels and programming blocks. Kid profiles only see shows and movies rated for their age.';

  @override
  String enterSPin(Object name) {
    return 'Enter $name\'s PIN';
  }

  @override
  String get whosWatching => 'Who\'s watching?';

  @override
  String get moveOkChoose2 => '◀▶ Move    OK Choose';

  @override
  String get enterAGrownUps => 'Enter a grown-up\'s PIN.';

  @override
  String get grownUpsOnly => 'Grown-ups only';

  @override
  String get yourChannelYour => 'Your channel, your look';

  @override
  String get testPattern => 'Test Pattern';

  @override
  String get upNext8 => 'UP NEXT  ·  8:00 PM';

  @override
  String get thisDevice => 'THIS DEVICE';

  @override
  String get glow => 'GLOW';

  @override
  String get curvature => 'CURVATURE';

  @override
  String get vignette => 'VIGNETTE';

  @override
  String get mask => 'MASK';

  @override
  String get lines => 'LINES';

  @override
  String get scanlines => 'SCANLINES';

  @override
  String get customCrtStyle => 'CUSTOM CRT STYLE';

  @override
  String accent(Object label) {
    return 'ACCENT ($label)';
  }

  @override
  String get overlayTheme => 'OVERLAY THEME';

  @override
  String get crtEffect => 'CRT EFFECT';

  @override
  String get surround => 'SURROUND';

  @override
  String get pictureShape => 'PICTURE SHAPE';

  @override
  String get surroundImage => 'Surround image';

  @override
  String get notAvailableOn => 'Not available on this device';

  @override
  String get offTurnsOff =>
      'Off turns off all CRT effects on this device only. Picture shape, surround and overlay themes stay as they are.';

  @override
  String get effectsOnThis => 'Effects on this device';

  @override
  String get retroLook2 => 'RETRO LOOK';

  @override
  String get theseSettingsApply =>
      'These settings apply on screens running the app. They don\'t apply to Live TV export.';

  @override
  String get sameAsThe => 'Same as the profile';

  @override
  String get streamsFromThis =>
      'Streams from this server stay under this. The profile\'s own limit (Playback) still applies; the lower one wins.';

  @override
  String qualityLimit(Object name) {
    return 'Quality limit · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      'Its programs leave your channels, which keep their numbers. Sources and commercial folders on it show as not found until you change them.';

  @override
  String remove3(Object name) {
    return 'Remove $name?';
  }

  @override
  String get signingOutOf =>
      'Signing out of this profile changes its main server.';

  @override
  String signedInAs(Object user) {
    return 'Signed in as $user';
  }

  @override
  String get mainServer => 'Main server';

  @override
  String get qualityLimit2 => 'Quality limit';

  @override
  String get moveDown => 'Move down';

  @override
  String get moveUp => 'Move up';

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get programsFromEvery =>
      'Programs from every server join one lineup. A title on several servers plays from the first one in this list that answers (Play from); if it stops answering, the next one takes over.';

  @override
  String get sleepingPressAny => 'Sleeping · Press any button to watch';

  @override
  String goingToSleep(Object seconds) {
    return 'Going to sleep in $seconds';
  }

  @override
  String get goingToSleep2 => 'Going to sleep';

  @override
  String goingToSleepIn(Object hint) {
    return 'Going to sleep in 1 minute. $hint';
  }

  @override
  String get pressAnyButton => 'Press any button to keep watching';

  @override
  String goingToSleepIn0(Object padLeft) {
    return 'Going to sleep in 0:$padLeft';
  }

  @override
  String get keepWatching => 'Keep watching';

  @override
  String get areYouStill => 'Are you still watching?';

  @override
  String sleepTimerMin(Object left) {
    return 'Sleep timer · $left min left';
  }

  @override
  String get whatsOnNow => 'What\'s on now has no set end time.';

  @override
  String endOfThis(Object programEnd) {
    return 'End of this program · $programEnd';
  }

  @override
  String get endOfThisProgram => 'End of this program';

  @override
  String get moveOkToggle => '▲▼◀▶ Move    OK Toggle    ESC Cancel';

  @override
  String get usedWhenNo =>
      'Used when no shows are picked. Also narrows down movies.';

  @override
  String get genres2 => 'GENRES';

  @override
  String get includeMovies => 'Include movies';

  @override
  String get add2 => 'Add…';

  @override
  String get notFoundOn => 'Not found on the server';

  @override
  String get collectionsFolders => 'COLLECTIONS & FOLDERS';

  @override
  String get playOrder => 'PLAY ORDER';

  @override
  String get clear => 'Clear';

  @override
  String get shows2 => 'SHOWS';

  @override
  String get pickSomethingTo => 'Pick something to play.';

  @override
  String everyMovie(Object genreText) {
    return 'every $genreText movie';
  }

  @override
  String get everyMovie2 => 'every movie';

  @override
  String everyShow(Object genreText) {
    return 'every $genreText show';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount or $last';
  }

  @override
  String get settingUpYour => 'Setting up your channels';

  @override
  String get couldntLoadYour => 'Couldn\'t load your library';

  @override
  String upNext(Object title) {
    return 'Up next: $title';
  }

  @override
  String backTo(Object title) {
    return 'Back to $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return 'Programming resumes in $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabel in $left';
  }

  @override
  String startingWith(Object title) {
    return 'Starting with $title';
  }

  @override
  String upNext2(Object start) {
    return 'UP NEXT  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return 'Next $start: $title';
  }

  @override
  String backOn(Object backOnAir) {
    return 'Back on $backOnAir';
  }

  @override
  String get offTheAir2 => 'Off the air';

  @override
  String get commercialBreak => 'Commercial break';

  @override
  String tryingAgainAt(Object end) {
    return 'Trying again at $end';
  }

  @override
  String get exitFullScreen => 'Exit full screen';

  @override
  String get guide2 => 'Guide';

  @override
  String thereIsNo(Object number) {
    return 'There is no channel $number';
  }

  @override
  String get liveChannelsCant => 'Live channels can\'t be paused';

  @override
  String get curvatureAndGlow =>
      'Curvature and glow are off: this device can\'t keep up';

  @override
  String get pressBackAgain => 'Press Back again to exit';

  @override
  String backAt(Object backAt) {
    return 'Back at $backAt';
  }

  @override
  String get live => 'LIVE';

  @override
  String get newLabel => 'NEW';

  @override
  String nowPlayingOn(Object name) {
    return 'NOW PLAYING ON $name';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => 'PAUSED';

  @override
  String get seekBar => 'Seek bar';

  @override
  String get live2 => 'Live';

  @override
  String get forward30 => 'Forward 30';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get back10 => 'Back 10';

  @override
  String get restart => 'Restart';

  @override
  String somethingWentWrong2(Object status) {
    return 'Something went wrong ($status).';
  }

  @override
  String get thatIsTooBig => 'That is too big.';

  @override
  String get notFound => 'Not found.';

  @override
  String get youCantDo => 'You can\'t do that.';

  @override
  String get cantReachThe =>
      'Can\'t reach the server. Check that it\'s running.';

  @override
  String signOut3(Object userName) {
    return 'Sign out $userName';
  }

  @override
  String get changePassword => 'Change password';

  @override
  String get users => 'Users';

  @override
  String get backups2 => 'Backups';

  @override
  String get serverAndSign => 'Server and sign-in';

  @override
  String get channels5 => 'Channels';

  @override
  String get thatProfileIsntYours =>
      'That profile isn\'t yours, or it\'s gone.';

  @override
  String get download => 'Download';

  @override
  String get itReplacesThe =>
      'It replaces the profiles, channels and settings here.';

  @override
  String get restoreThisBackup => 'Restore this backup?';

  @override
  String get backupActions => 'Backup actions';

  @override
  String channels6(Object profiles, Object channels, Object device) {
    return '$profiles · $channels channels · $device';
  }

  @override
  String get noneYetOne =>
      'None yet. One is saved each day the household changes.';

  @override
  String get savedOnThe => 'Saved on the server';

  @override
  String get restoring => 'Restoring…';

  @override
  String get restoreFromAFile => 'Restore from a file…';

  @override
  String get downloadABackup => 'Download a backup now';

  @override
  String get aBackupHoldsThe =>
      'A backup holds the profiles, channels, blocks, logos, export settings and user accounts (never passwords or sign-in tokens).';

  @override
  String get restoredTheBackup2 => 'Restored the backup.';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return 'From $whenValue ($device): $profiles. It replaces the profiles, channels and settings here.';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return 'Next airing: $start $end';
  }

  @override
  String programsInIts(Object total) {
    return '$total programs in its playlist.';
  }

  @override
  String get workingOutWhat => 'Working out what it plays…';

  @override
  String get later => 'Later';

  @override
  String get earlier => 'Earlier';

  @override
  String get eachAiringPlays =>
      'Each airing plays every spot\'s next episodes in order, then starts over if time is left.';

  @override
  String get aLineupOf => 'A lineup of shows';

  @override
  String get whatItPlays2 => 'What it plays';

  @override
  String get onlyPartOf => 'Only part of the year';

  @override
  String get runsPastMidnight => 'Runs past midnight into the next day.';

  @override
  String get whenLabel => 'When';

  @override
  String get aNewChannelFor => 'A new channel for this block';

  @override
  String get channel3 => 'Channel';

  @override
  String get blocks => 'Blocks';

  @override
  String get newBlock => 'New block';

  @override
  String get programmingBlock => 'Programming block';

  @override
  String get aBlockTakes =>
      'A block takes over a channel at set times: \"Saturday Morning Cartoons\", Saturdays 7 AM to noon.';

  @override
  String get overlayTheme2 => 'Overlay theme';

  @override
  String get crtEffect2 => 'CRT effect';

  @override
  String get chooseSurroundImage => 'Choose surround image…';

  @override
  String get surround2 => 'Surround';

  @override
  String get pictureShape2 => 'Picture shape';

  @override
  String get chooseOfflineImage => 'Choose offline image…';

  @override
  String get fillerPool2 => 'Filler pool';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes minutes';
  }

  @override
  String get slotLength2 => 'Slot length';

  @override
  String get everyProgramStarts =>
      'Every program starts on the clock. The tail fills the rest of each slot.';

  @override
  String get itLeavesThe => 'It leaves the lineup.';

  @override
  String get itsProgrammingBlocks => 'Its programming blocks are removed too.';

  @override
  String get removeThisChannel => 'Remove this channel';

  @override
  String get channelLogo2 => 'Channel logo';

  @override
  String get editCustomBreaks => 'Edit custom breaks…';

  @override
  String get musicChannelsOnlyShuffle =>
      'Music channels only shuffle, never the same artist twice in a row.';

  @override
  String get playOrder2 => 'Play order';

  @override
  String get saveWhatIt => 'Save what it plays';

  @override
  String get canBeA => 'Can be a show\'s home channel for its newest episodes.';

  @override
  String get hiddenFromThe => 'Hidden from the guide';

  @override
  String get chooseIcon => 'Choose icon…';

  @override
  String get icon => 'Icon';

  @override
  String get saveNameAnd => 'Save name and number';

  @override
  String get aChannelAlready =>
      'A channel already on that number swaps into this one\'s place.';

  @override
  String get number3 => 'Number';

  @override
  String get nameAndNumber => 'Name and number';

  @override
  String get decadesNoneAny => 'Decades (none: any)';

  @override
  String get genresNoneAny => 'Genres (none: any)';

  @override
  String musicVideos(Object musicVideos) {
    return 'Music videos ($musicVideos)';
  }

  @override
  String songs(Object songs) {
    return 'Songs ($songs)';
  }

  @override
  String get newMusicChannel => 'New music channel';

  @override
  String get aNightlySlot =>
      'A nightly slot for shows\' newest episodes, on each show\'s home channel.';

  @override
  String get mainSettings => 'Main settings';

  @override
  String get glow2 => 'Glow';

  @override
  String get curvature2 => 'Curvature';

  @override
  String get vignette2 => 'Vignette';

  @override
  String get mask2 => 'Mask';

  @override
  String get lines2 => 'Lines';

  @override
  String get scanlines2 => 'Scanlines';

  @override
  String get customCrtStyle2 => 'Custom CRT style';

  @override
  String accent2(Object label) {
    return 'Accent ($label)';
  }

  @override
  String get hidden => 'Hidden';

  @override
  String get blockChannel2 => 'Block channel';

  @override
  String live3(Object source) {
    return 'Live · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return '$shownCount of $channelsCount channels';
  }

  @override
  String get searchChannels => 'Search channels';

  @override
  String get resetLineup => 'Reset lineup';

  @override
  String get everyChannelEdit =>
      'Every channel edit is discarded and the default lineup is made again. Channels you added are kept. A backup is saved first.';

  @override
  String get musicChannel => 'Music channel';

  @override
  String get newBlockChannel => 'New block channel';

  @override
  String get channelsOwnPlans => 'Channels\' own plans';

  @override
  String get setTypeBumpers => 'Set type: Bumpers';

  @override
  String get setTypeCommercials => 'Set type: Commercials';

  @override
  String get chooseFolders2 => 'Choose folders…';

  @override
  String get plansThatDrew =>
      'Plans that drew from it use all pools instead, and its videos rejoin the channels.';

  @override
  String get renamePool => 'Rename pool';

  @override
  String get poolActions => 'Pool actions';

  @override
  String get aPoolIs =>
      'A pool is a set of library folders whose videos fill breaks instead of airing. A pool\'s type says whether its clips play as commercials or as bumpers, which open and close breaks.';

  @override
  String get pools2 => 'Pools';

  @override
  String get breaks => 'Breaks';

  @override
  String clipsInAll(Object clips) {
    return '$clips clips in all commercial pools.';
  }

  @override
  String get tunerAddress => 'Tuner address';

  @override
  String get changePort => 'Change port';

  @override
  String get exportThisProfile => 'Export this profile';

  @override
  String get letsPlexAnd =>
      'Lets Plex and others find the tuners on the network.';

  @override
  String get discovery2 => 'Discovery';

  @override
  String get encoder2 => 'Encoder';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return 'Automatic: $streamLimitInUse on this machine.';
  }

  @override
  String get streamsAtOnce2 => 'Streams at once';

  @override
  String get quality2 => 'Quality';

  @override
  String get settings => 'Settings';

  @override
  String get eachExportedProfile =>
      'Each exported profile is a tuner for Plex, Jellyfin or Emby. Add it in their DVR settings by its address.';

  @override
  String get channelsInThis => 'Channels in this group';

  @override
  String get chooseChannels3 => 'Choose channels…';

  @override
  String channels7(Object channelIds) {
    return '$channelIds channels';
  }

  @override
  String get itsChannelsStay => 'Its channels stay in the lineup.';

  @override
  String get renameGroup => 'Rename group';

  @override
  String get groupActions => 'Group actions';

  @override
  String get yourGroup => 'Your group';

  @override
  String get theOrderOf =>
      'The order of the tabs in the guide, and which are shown.';

  @override
  String get guideTabs => 'Guide tabs';

  @override
  String get make => 'Make';

  @override
  String get breaksBetweenPrograms => 'Breaks between programs';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '$mids breaks inside',
      one: '$mids break inside',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return '$songs songs';
  }

  @override
  String get newEpisode => 'New episode';

  @override
  String get noChannelsYet2 => 'No channels yet.';

  @override
  String get noGuide => 'No guide';

  @override
  String get noneShown => 'None shown';

  @override
  String get allShown => 'All shown';

  @override
  String channels8(Object name) {
    return '$name: channels';
  }

  @override
  String get orChooseA => 'Or choose a guide file…';

  @override
  String get emptyThePlaylists =>
      'Empty: the playlist\'s own guide, if it names one.';

  @override
  String get guideAddressXmltv => 'Guide address (XMLTV, optional)';

  @override
  String get orChooseAPlaylist => 'Or choose a playlist file…';

  @override
  String get leaveEmptyToKeep => 'Leave empty to keep the playlist file.';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'Files';

  @override
  String get itsChannelsJoin =>
      'Its channels join while this profile is signed in to that server.';

  @override
  String guide3(Object guideFile) {
    return 'Guide: $guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'Playlist file: $playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return 'Refreshed $last $context';
  }

  @override
  String get itsChannelsLeaveThe =>
      'Its channels leave the lineup, groups and favorites.';

  @override
  String read(Object fetched, Object context) {
    return 'Read $fetched $context.';
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
    return '$series shows · $episodes episodes · $movies movies · $songs songs · $musicVideos music videos · $commercials commercial videos';
  }

  @override
  String fromAs(Object server, Object user) {
    return 'From $server as $user.';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name: library';
  }

  @override
  String get removeThePin => 'Remove the PIN';

  @override
  String get pinOptional => 'PIN (optional)';

  @override
  String get newPinLeave => 'New PIN (leave empty to keep it)';

  @override
  String colour(Object i) {
    return 'Colour $i';
  }

  @override
  String get colour2 => 'Colour';

  @override
  String get itsChannelsBlocks =>
      'Its channels, blocks and settings are deleted. A backup is saved first.';

  @override
  String get exported => 'Exported';

  @override
  String kid3(Object label) {
    return 'Kid · $label';
  }

  @override
  String get noProfilesAre =>
      'No profiles are assigned to you yet. Ask an admin.';

  @override
  String signIn2(Object name) {
    return 'Sign $name in';
  }

  @override
  String get theLibraryIs =>
      'The library is being read again; the server\'s programs join the channels when it\'s done.';

  @override
  String get itsLibraryIs =>
      'Its library is being read and its channels made. This takes a minute or two.';

  @override
  String isSignedIn(Object name) {
    return '$name is signed in.';
  }

  @override
  String get couldntDoThat => 'Couldn\'t do that. Try again.';

  @override
  String get itsChannelsStayIt =>
      'Its channels stay; it needs signing in to play.';

  @override
  String signOut4(Object name) {
    return 'Sign $name out?';
  }

  @override
  String get signingIn => 'Signing in…';

  @override
  String wasSignedIn(Object server, Object user) {
    return 'Was signed in to $server as $user. Sign in again.';
  }

  @override
  String signedInTo(Object server, Object user) {
    return 'Signed in to $server as $user.';
  }

  @override
  String get profileName => 'Profile name';

  @override
  String get nameAProfile =>
      'Name a profile, sign it in to your media server, and its channels are made and exported.';

  @override
  String get chooseABackup => 'Choose a backup file…';

  @override
  String get moveAHousehold =>
      'Move a household here from a TV or another server: its profiles, channels, blocks, logos and export settings.';

  @override
  String get restoreABackup => 'Restore a backup';

  @override
  String get theServerIs => 'The server is starting…';

  @override
  String get itsProgramsLeaveThe =>
      'Its programs leave the channels, which keep their numbers. Sources and commercial folders on it show as not found until you change them.';

  @override
  String addAServerTo(Object name) {
    return 'Add a server to $name';
  }

  @override
  String servers2(Object name) {
    return '$name: servers';
  }

  @override
  String get makeAccountAnd => 'Make account and sign in';

  @override
  String get setPasswordAnd => 'Set password and sign in';

  @override
  String get passwordAgain => 'Password again';

  @override
  String get atLeast8 => 'At least 8 characters.';

  @override
  String get userName => 'User name';

  @override
  String get adminAccount => 'Admin account';

  @override
  String get makeTheFirst => 'Make the first admin account.';

  @override
  String get setANew => 'Set a new password for an admin account.';

  @override
  String get thisSetupLink =>
      'This setup link has been used, or it\'s from an earlier start. Open the newest one from the server\'s log, or sign in.';

  @override
  String get thePasswordsDont => 'The passwords don\'t match.';

  @override
  String get newPasswordAgain => 'New password again';

  @override
  String get newPassword => 'New password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get passwordChangedYour =>
      'Password changed. Your other browsers are signed out.';

  @override
  String get theNewPasswords => 'The new passwords don\'t match.';

  @override
  String get theyAreSigned => 'They are signed out and can\'t sign in again.';

  @override
  String get cantSignIn => 'Can\'t sign in; signed out everywhere.';

  @override
  String get usersReachOnly => 'Users reach only the profiles below.';

  @override
  String get adminsCanDo => 'Admins can do everything, on every profile.';

  @override
  String get admin => 'Admin';

  @override
  String get user => 'User';

  @override
  String get leaveEmptyToKeepIt =>
      'Leave empty to keep it. Setting one signs them out elsewhere.';

  @override
  String get needsAPassword => 'Needs a password before it can sign in.';

  @override
  String get addUser => 'Add user';

  @override
  String get needsAPassword2 => 'Needs a password';

  @override
  String get noProfiles => 'No profiles';

  @override
  String get pad => 'Pad';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  $clips clips';
  }

  @override
  String get clipsFrom2 => 'Clips from';

  @override
  String get channelsUsingItGo =>
      'Channels using it go back to a built-in icon.';

  @override
  String get uploading => 'Uploading…';

  @override
  String get noneOfYourShows =>
      'None of your shows have a logo image on your server.';

  @override
  String get chooseAnIcon => 'Choose an icon';

  @override
  String get couldntCopySelect =>
      'Couldn\'t copy. Select the text and copy it.';

  @override
  String copy(Object label) {
    return 'Copy $label';
  }

  @override
  String get home => 'Home';

  @override
  String get thereIsNoPage => 'There is no page here.';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get thisIsA =>
      'This is a kid profile. Changing its settings needs a grown-up\'s PIN.';

  @override
  String hasAPin(Object name) {
    return '$name has a PIN.';
  }

  @override
  String get profile => 'Profile';

  @override
  String get changingAKid =>
      'Changing a kid profile\'s settings needs the PIN of a grown-up profile.';

  @override
  String get aGrownUps => 'A grown-up\'s PIN';

  @override
  String get thisProfile => 'this profile';

  @override
  String movies3(Object movies) {
    return 'Movies ($movies)';
  }

  @override
  String get shows3 => 'Shows';

  @override
  String remove4(Object label) {
    return 'Remove $label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · Not found on the server';
  }

  @override
  String get dragACollection =>
      'Drag a collection, folder or movie here, or use its Add button.';

  @override
  String get collectionsAndFolders => 'Collections and folders';

  @override
  String add3(Object name) {
    return 'Add $name';
  }

  @override
  String added2(Object name) {
    return '$name added';
  }

  @override
  String get dragToAdd => 'Drag to add';

  @override
  String get languageAutomatic => 'Automatic';

  @override
  String dateAtTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String connectingTo(Object server) {
    return 'Connecting to $server…';
  }

  @override
  String get yourServerLower => 'your server';

  @override
  String noServerFoundAt(Object address) {
    return 'No Jellyfin, Emby or Plex server found at $address.';
  }

  @override
  String captionsValue(Object name) {
    return 'Captions: $name';
  }

  @override
  String channelOverrides(int count) {
    return '$count channels have its own setting (Channels & icons).';
  }

  @override
  String noShowLogosOn(Object kind) {
    return 'None of your shows have a logo image on your $kind server.';
  }

  @override
  String fileChosen(Object name) {
    return 'File: $name';
  }

  @override
  String get theOneChosenBefore => 'the one chosen before';

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
          'Streaming channels $channels to $viewers viewer(s). $running of $limit streams in use.',
      one:
          'Streaming channel $channels to $viewers viewer(s). $running of $limit streams in use.',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name: export this lineup';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name (kid): export this lineup';
  }

  @override
  String encoderInUse(Object encoder) {
    return 'Encoder in use: $encoder';
  }

  @override
  String get checking => 'checking…';

  @override
  String countShows(int count) {
    return '$count shows';
  }

  @override
  String countEpisodes(int count) {
    return '$count episodes';
  }

  @override
  String countMovies(int count) {
    return '$count movies';
  }

  @override
  String countSongs(int count) {
    return '$count songs';
  }

  @override
  String countMusicVideos(int count) {
    return '$count music videos';
  }

  @override
  String countHidden(int count) {
    return '$count hidden';
  }

  @override
  String countOnTheAir(int count) {
    return '$count on the air';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count programming blocks',
      one: '$count programming block',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name: $stats';
  }

  @override
  String get yourServerHasNothingNew =>
      'Your server has nothing new since the last refresh. New files show up here once the server has scanned them: if you just added some, scan the library on the server first, then refresh again.';

  @override
  String serverHasNothingNew(Object server) {
    return '$server has nothing new since the last refresh. New files show up here once the server has scanned them: if you just added some, scan the library on the server first, then refresh again.';
  }

  @override
  String get updateWatchStatusOnYourServer =>
      'Update watch status on your server';

  @override
  String get updateWatchStatusOnYourServers =>
      'Update watch status on your servers';

  @override
  String updateWatchStatusOn(Object name) {
    return 'Update watch status on $name';
  }

  @override
  String get poolFoldersBumpers =>
      'Every video in these folders (and the folders inside them) opens and closes breaks, and never airs as a program.';

  @override
  String get poolFoldersCommercials =>
      'Every video in these folders (and the folders inside them) fills breaks, and never airs as a program.';

  @override
  String get newPin => 'New PIN';

  @override
  String namedPin(Object name) {
    return '$name PIN';
  }

  @override
  String get qualitySameAsProfile => 'Quality: same as the profile';

  @override
  String qualityValue(Object limit) {
    return 'Quality: $limit';
  }

  @override
  String onChannel(Object channel) {
    return 'on $channel';
  }

  @override
  String get aChannelThatIsGone => 'a channel that is gone';

  @override
  String liveFrom(Object source) {
    return 'Live from $source';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'Logo $mode · Premieres $premieres';
  }

  @override
  String get offLower => 'off';

  @override
  String streamingNow(Object count) {
    return '$count streaming now.';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return '$count streaming now · encoding with $encoder.';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · $chosen of $channels channels';
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
    return 'From $when ($device): $profiles. $channels channels, $blocks programming blocks, $logos logos.';
  }

  @override
  String get backupSavedFirst => 'A backup of what\'s here now is saved first.';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new shows',
      one: '$count new show',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new episodes',
      one: '$count new episode',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new movies',
      one: '$count new movie',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new songs',
      one: '$count new song',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return 'Plays $list.';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new channels',
      one: '$count new channel',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => 'Young kids';

  @override
  String get kidRatingYoungDescription => 'TV-Y and TV-Y7';

  @override
  String get kidRatingKids => 'Kids';

  @override
  String get kidRatingKidsDescription => 'Up to TV-G and G';

  @override
  String get kidRatingOlder => 'Older kids';

  @override
  String get kidRatingOlderDescription => 'Up to TV-PG and PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '$count profile',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '$count channel',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '$count block',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slots',
      one: '$count slot',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos in its folders',
      one: '$count video in its folders',
    );
    return '$_temp0';
  }

  @override
  String backupProfilesChannelsBlocks(
    Object profiles,
    Object channels,
    Object blocks,
  ) {
    return '$profiles · $channels · $blocks.';
  }

  @override
  String get liveLabel => 'Live';

  @override
  String get aMidRollOpens =>
      'A mid-roll opens and closes with a bumper, a post-roll opens with one, and a pre-roll closes with one. Commercials fill the rest.';

  @override
  String get programsPlayBack => 'Programs play back to back, with no breaks.';

  @override
  String get everyShowFills =>
      'Every show fills a half-hour slot (an hour or more for long ones), so the guide stays on the clock.';

  @override
  String get chooseHowLong =>
      'Choose how long each break is, how often shows break, and which pool each break draws from.';

  @override
  String get kindSentenceAutomatic => 'automatic';

  @override
  String get kindSentenceBeforeRestore => 'before restore';

  @override
  String get kindSentenceBeforeReset => 'before reset';

  @override
  String get kindSentenceBeforeDeletingAProfile => 'before deleting a profile';

  @override
  String kindSentenceBeforeDeleting(Object subject) {
    return 'before deleting $subject';
  }

  @override
  String get kindSentenceBeforeUpdate => 'before update';

  @override
  String get kindSentenceBeforeLineupCleanup => 'before lineup cleanup';

  @override
  String get kindSentenceFromAFile => 'from a file';

  @override
  String get kindSentenceMovingToOfficial => 'moving to Nightingale TV';

  @override
  String get kindSentenceMovingToOwnBuild =>
      'moving to Nightingale TV (own build)';

  @override
  String get kindSentenceFromOfficial => 'from Nightingale TV';

  @override
  String get kindSentenceFromOwnBuild => 'from Nightingale TV (own build)';

  @override
  String get kindSentenceMadeByYou => 'made by you';

  @override
  String get copyAction => 'Copy';

  @override
  String get channelKidsZone => 'Kids Zone';

  @override
  String get channelToonTv => 'Toon TV';

  @override
  String get channelLaughTrack => 'Laugh Track';

  @override
  String get channelFamilyRoom => 'Family Room';

  @override
  String get channelAdventureTv => 'Adventure TV';

  @override
  String get channelSciFiFantasy => 'Sci-Fi & Fantasy';

  @override
  String get channelMysteryTv => 'Mystery TV';

  @override
  String get channelDramaCentral => 'Drama Central';

  @override
  String get channelCrimeJustice => 'Crime & Justice';

  @override
  String get channelThrillTv => 'Thrill TV';

  @override
  String get channelFrightNight => 'Fright Night';

  @override
  String get channelRomanceTv => 'Romance TV';

  @override
  String get channelDiscoveryZone => 'Discovery Zone';

  @override
  String get channelMusicTv => 'Music TV';

  @override
  String get channelRealityTv => 'Reality TV';

  @override
  String get channelGameShowTv => 'Game Show TV';

  @override
  String get channelFrontierTv => 'Frontier TV';

  @override
  String get channelHistoryTv => 'History TV';

  @override
  String get channelSportsTv => 'Sports TV';

  @override
  String get channelNewsTv => 'News TV';

  @override
  String get channelAllShows => 'All Shows';

  @override
  String get channelMovieChannel => 'Movie Channel';

  @override
  String get channelMusicVideos => 'Music Videos';

  @override
  String get channelMusicRadio => 'Music Radio';

  @override
  String get genreActionAdventure => 'Action & Adventure';

  @override
  String get genreSciFiFantasy => 'Sci-Fi & Fantasy';

  @override
  String get genreKids => 'Kids';

  @override
  String get genreAnimation => 'Animation';

  @override
  String get genreComedy => 'Comedy';

  @override
  String get genreFamily => 'Family';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreCrime => 'Crime';

  @override
  String get genreMystery => 'Mystery';

  @override
  String get genreThriller => 'Thriller';

  @override
  String get genreHorror => 'Horror';

  @override
  String get genreRomance => 'Romance';

  @override
  String get genreDocumentary => 'Documentary';

  @override
  String get genreMusic => 'Music';

  @override
  String get genreReality => 'Reality';

  @override
  String get genreGameShows => 'Game Shows';

  @override
  String get genreWestern => 'Western';

  @override
  String get genreWar => 'War';

  @override
  String get genreHistory => 'History';

  @override
  String get genreNews => 'News';

  @override
  String get genreTalk => 'Talk';

  @override
  String get genreSoap => 'Soap';

  @override
  String get genreSports => 'Sports';

  @override
  String get genreClassical => 'Classical';

  @override
  String get genreElectronic => 'Electronic';

  @override
  String get genreCountry => 'Country';

  @override
  String get genreLatin => 'Latin';

  @override
  String get genreSoundtrack => 'Soundtrack';

  @override
  String get genreOldies => 'Oldies';

  @override
  String get genreDance => 'Dance';

  @override
  String get genreFolk => 'Folk';

  @override
  String get genreAlternative => 'Alternative';

  @override
  String get blockDaytime => 'Daytime';

  @override
  String get blockMovieNight => 'Movie Night';

  @override
  String get blockNewEpisodes => 'New Episodes';

  @override
  String get kindShow => 'Show';

  @override
  String get kindShows => 'Shows';

  @override
  String get kindMovies => 'Movies';

  @override
  String get kindMusicVideos => 'Music Videos';

  @override
  String get kindRadio => 'Radio';

  @override
  String genreMovies(Object genre) {
    return '$genre Movies';
  }

  @override
  String genreMusicVideos(Object genre) {
    return '$genre Music Videos';
  }

  @override
  String genreRadio(Object genre) {
    return '$genre Radio';
  }

  @override
  String kindSuffix(Object name, Object kind) {
    return '$name ($kind)';
  }

  @override
  String kindSuffixNumbered(Object name, Object kind, Object number) {
    return '$name ($kind $number)';
  }

  @override
  String get lateNightTitle => 'Late Night';

  @override
  String get languageTitle => 'Language';

  @override
  String get stillWatchingOff => 'Off';

  @override
  String afterHours(int hours) {
    return 'After $hours hours';
  }

  @override
  String get bitrateOriginal => 'Original (no limit)';

  @override
  String get bitrate40 => '40 Mbps · 4K';

  @override
  String get bitrate20 => '20 Mbps · 1080p high';

  @override
  String get bitrate12 => '12 Mbps · 1080p';

  @override
  String get bitrate8 => '8 Mbps · 1080p';

  @override
  String get bitrate4 => '4 Mbps · 720p';

  @override
  String get noSuchLanguage => 'No such language.';

  @override
  String get languageField => 'Language';

  @override
  String get remotePageTitle => 'Nightingale TV Remote';

  @override
  String get remotePairTitle => 'Pair with the TV';

  @override
  String get remotePairHelp =>
      'Scan the code on the TV (Menu → Phone remote), or enter the 6-digit code shown there.';

  @override
  String get remotePairingCode => 'Pairing code';

  @override
  String get remotePair => 'Pair';

  @override
  String get remoteConnecting => 'Connecting…';

  @override
  String get remoteTabRemote => 'Remote';

  @override
  String get remoteUp => 'Up';

  @override
  String get remoteLeft => 'Left';

  @override
  String get remoteRight => 'Right';

  @override
  String get remoteDown => 'Down';

  @override
  String get remoteInfo => 'Info';

  @override
  String get remoteLastCh => 'Last ch';

  @override
  String get remoteCc => 'CC';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => 'Enter';

  @override
  String get remoteRemovedFromTv =>
      'This phone was removed from the TV. Scan the code to pair again.';

  @override
  String get remoteCouldntPair => 'Couldn\'t pair. Try again.';

  @override
  String get remoteCantReachWifi =>
      'Can\'t reach the TV. Is this phone on the same Wi-Fi?';

  @override
  String get remoteEnterDigits => 'Enter the 6 digits shown on the TV.';

  @override
  String get remoteCantReachTv => 'Can\'t reach the TV';

  @override
  String get remotePickProfile => 'Pick a profile with the arrows and OK.';

  @override
  String remoteWatching(Object name) {
    return 'Watching: $name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name (kid)';
  }

  @override
  String get transferPageTitle => 'Nightingale TV Backup';

  @override
  String get transferIntro =>
      'Move a backup between this TV and this device. Keep the TV\'s dialog open while you do.';

  @override
  String get transferDownload => 'Download backup';

  @override
  String get transferDownloadHelp =>
      'A backup of the TV\'s setup as it is now: profiles, channels, blocks and settings.';

  @override
  String get transferRestoreTitle => 'Restore from a file';

  @override
  String transferRestoreHelp(Object file) {
    return 'Send a $file file to the TV. Nothing changes until you confirm it on the TV.';
  }

  @override
  String get transferChoose => 'Choose a backup file…';

  @override
  String get transferFoot =>
      'Only devices on your home network can open this page.';

  @override
  String transferSending(Object name) {
    return 'Sending $name…';
  }

  @override
  String get transferCheckTv => 'Check your TV to finish.';

  @override
  String get transferClosed =>
      'The TV closed this page. Open it again from Backup & restore.';

  @override
  String get transferCouldntTake => 'The TV couldn’t take that file.';

  @override
  String get transferCouldntReach =>
      'Couldn’t reach the TV. Is it still showing the code?';

  @override
  String get includeShows => 'Include shows';

  @override
  String get everyShow2 => 'every show';

  @override
  String get decades => 'Decades';

  @override
  String get decadesHeading => 'DECADES';

  @override
  String get channelActionTv => 'Action TV';

  @override
  String get channelSciFiTv => 'Sci-Fi TV';

  @override
  String get channelFantasyTv => 'Fantasy TV';

  @override
  String get channelMysteryThrills => 'Mystery & Thrills';

  @override
  String get genreAction => 'Action';

  @override
  String get genreAdventure => 'Adventure';

  @override
  String get genreSciFi => 'Sci-Fi';

  @override
  String get genreFantasy => 'Fantasy';

  @override
  String get genreThrillerMystery => 'Thriller & Mystery';

  @override
  String decadeTv(Object decade) {
    return '$decade TV';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$decade $genre TV';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return '$decade $genre Movies';
  }

  @override
  String get errorReports => 'Error reports';

  @override
  String get sendErrorReportsFrom => 'Send error reports from this device';

  @override
  String get errorReportsExplain =>
      'When something goes wrong, Nightingale TV sends its developer a short report: the error, the app version, the kind of device, and the last few screens and channel numbers. Server addresses, passwords and keys, names and file paths are taken out before it\'s sent. Titles and what you watch are never sent.';

  @override
  String get errorReportsOff =>
      'Turn this off and nothing is sent from this device; reports waiting to go are deleted.';

  @override
  String get sendATestReport => 'Send a test report';

  @override
  String lastReportId(String id) {
    return 'Last report ID: $id';
  }

  @override
  String get noReportSentYet => 'No report sent from this device yet.';

  @override
  String get quoteReportId =>
      'Quote this ID when you tell the developer about a problem.';

  @override
  String testReportSent(String id) {
    return 'Test report sent: $id';
  }

  @override
  String get testReportNotSent =>
      'The test report couldn\'t be sent. Try again in a moment.';

  @override
  String get reportsNotInBuild =>
      'Error reporting isn\'t part of this build of Nightingale TV, so nothing is ever sent.';
}
