import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
  ];

  /// No description provided for @onlyChannelsYou.
  ///
  /// In en, this message translates to:
  /// **'Only channels you added can be removed. Hide this one instead.'**
  String get onlyChannelsYou;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @nothingInThe.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the library matches that.'**
  String get nothingInThe;

  /// No description provided for @chooseSongsOr.
  ///
  /// In en, this message translates to:
  /// **'Choose songs or music videos.'**
  String get chooseSongsOr;

  /// No description provided for @blockChannel.
  ///
  /// In en, this message translates to:
  /// **'Block Channel'**
  String get blockChannel;

  /// No description provided for @thisOverlapsOn.
  ///
  /// In en, this message translates to:
  /// **'This overlaps \"{title}\" ({clash}) on the same channel.'**
  String thisOverlapsOn(Object title, Object clash);

  /// No description provided for @chooseSomeShows.
  ///
  /// In en, this message translates to:
  /// **'Choose some shows or movies for the block to play.'**
  String get chooseSomeShows;

  /// No description provided for @nothingInThis.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this mix is rated {shortLabel} or higher. Choose a lower rating or other shows.'**
  String nothingInThis(Object shortLabel);

  /// No description provided for @theLineupsShows.
  ///
  /// In en, this message translates to:
  /// **'The lineup\'s shows have no episodes. Pick other shows.'**
  String get theLineupsShows;

  /// No description provided for @addAShow.
  ///
  /// In en, this message translates to:
  /// **'Add a show to the lineup.'**
  String get addAShow;

  /// No description provided for @chooseAChannel.
  ///
  /// In en, this message translates to:
  /// **'Choose a channel.'**
  String get chooseAChannel;

  /// No description provided for @theBlockHas.
  ///
  /// In en, this message translates to:
  /// **'The block has to end at a different time than it starts.'**
  String get theBlockHas;

  /// No description provided for @pickAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day.'**
  String get pickAtLeast;

  /// No description provided for @giveTheBlock.
  ///
  /// In en, this message translates to:
  /// **'Give the block a title.'**
  String get giveTheBlock;

  /// No description provided for @thisChannelDoesnt.
  ///
  /// In en, this message translates to:
  /// **'This channel doesn\'t have slots.'**
  String get thisChannelDoesnt;

  /// No description provided for @onlyShuffledChannels.
  ///
  /// In en, this message translates to:
  /// **'Only shuffled channels can be reshuffled.'**
  String get onlyShuffledChannels;

  /// No description provided for @chooseSomethingFor.
  ///
  /// In en, this message translates to:
  /// **'Choose something for the channel to play.'**
  String get chooseSomethingFor;

  /// No description provided for @onlyChannelsYouAdded.
  ///
  /// In en, this message translates to:
  /// **'Only channels you added can change what they play.'**
  String get onlyChannelsYouAdded;

  /// No description provided for @myChannel.
  ///
  /// In en, this message translates to:
  /// **'My Channel'**
  String get myChannel;

  /// No description provided for @noneOfYour.
  ///
  /// In en, this message translates to:
  /// **'None of your servers could be reached.'**
  String get noneOfYour;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning {where}…'**
  String scanning(Object where);

  /// No description provided for @buildingChannels.
  ///
  /// In en, this message translates to:
  /// **'Building channels…'**
  String get buildingChannels;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in.'**
  String get notSignedIn;

  /// No description provided for @isAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'{name} is already in this profile'**
  String isAlreadyIn(Object name);

  /// No description provided for @thatServerIs.
  ///
  /// In en, this message translates to:
  /// **'That server is no longer in this profile'**
  String get thatServerIs;

  /// No description provided for @yourSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get yourSessionExpired;

  /// No description provided for @m3uPlaylist.
  ///
  /// In en, this message translates to:
  /// **'M3U playlist'**
  String get m3uPlaylist;

  /// No description provided for @hasNoLive.
  ///
  /// In en, this message translates to:
  /// **'{serverName} has no Live TV channels'**
  String hasNoLive(Object serverName);

  /// No description provided for @couldntReach.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {serverName}'**
  String couldntReach(Object serverName);

  /// No description provided for @liveTv.
  ///
  /// In en, this message translates to:
  /// **'{serverName} Live TV'**
  String liveTv(Object serverName);

  /// No description provided for @liveTvIs.
  ///
  /// In en, this message translates to:
  /// **'{serverName} Live TV is already a source'**
  String liveTvIs(Object serverName);

  /// No description provided for @notSignedIn2.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn2;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @thisBackupIs.
  ///
  /// In en, this message translates to:
  /// **'This backup is damaged: one of its channel logos can\'t be read.'**
  String get thisBackupIs;

  /// No description provided for @thisBackupIsDamaged.
  ///
  /// In en, this message translates to:
  /// **'This backup is damaged: its Live TV export settings can\'t be read.'**
  String get thisBackupIsDamaged;

  /// No description provided for @thisBackupIsDamagedS.
  ///
  /// In en, this message translates to:
  /// **'This backup is damaged: {name}\'s {what} can\'t be read.'**
  String thisBackupIsDamagedS(Object name, Object what);

  /// No description provided for @liveTvSources.
  ///
  /// In en, this message translates to:
  /// **'Live TV sources'**
  String get liveTvSources;

  /// No description provided for @thisBackupCant.
  ///
  /// In en, this message translates to:
  /// **'This backup can\'t be restored. {problem}'**
  String thisBackupCant(Object problem);

  /// No description provided for @thisBackupIsDamagedIts.
  ///
  /// In en, this message translates to:
  /// **'This backup is damaged: its profiles can\'t be read.'**
  String get thisBackupIsDamagedIts;

  /// No description provided for @thisFileIs.
  ///
  /// In en, this message translates to:
  /// **'This file is too big to be a Nightingale TV backup.'**
  String get thisFileIs;

  /// No description provided for @thisBackupWas.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of Nightingale TV.'**
  String get thisBackupWas;

  /// No description provided for @thisFileIsnt.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a Nightingale TV backup, or it\'s damaged.'**
  String get thisFileIsnt;

  /// No description provided for @restoredTheBackup.
  ///
  /// In en, this message translates to:
  /// **'Restored the backup from {toLocal}.'**
  String restoredTheBackup(Object toLocal);

  /// No description provided for @couldntRestoreThe.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the backup: {e}'**
  String couldntRestoreThe(Object e);

  /// No description provided for @couldntSaveA.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save a backup first: {e}'**
  String couldntSaveA(Object e);

  /// No description provided for @madeByYou.
  ///
  /// In en, this message translates to:
  /// **'Made by you'**
  String get madeByYou;

  /// No description provided for @fromNightingaleTv.
  ///
  /// In en, this message translates to:
  /// **'From Nightingale TV (own build)'**
  String get fromNightingaleTv;

  /// No description provided for @fromNightingaleTv2.
  ///
  /// In en, this message translates to:
  /// **'From Nightingale TV'**
  String get fromNightingaleTv2;

  /// No description provided for @movingToNightingale.
  ///
  /// In en, this message translates to:
  /// **'Moving to Nightingale TV (own build)'**
  String get movingToNightingale;

  /// No description provided for @movingToNightingaleTv.
  ///
  /// In en, this message translates to:
  /// **'Moving to Nightingale TV'**
  String get movingToNightingaleTv;

  /// No description provided for @fromAFile.
  ///
  /// In en, this message translates to:
  /// **'From a file'**
  String get fromAFile;

  /// No description provided for @beforeLineupCleanup.
  ///
  /// In en, this message translates to:
  /// **'Before lineup cleanup'**
  String get beforeLineupCleanup;

  /// No description provided for @beforeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Before update'**
  String get beforeUpdate;

  /// No description provided for @beforeDeleting.
  ///
  /// In en, this message translates to:
  /// **'Before deleting {subject}'**
  String beforeDeleting(Object subject);

  /// No description provided for @beforeDeletingA.
  ///
  /// In en, this message translates to:
  /// **'Before deleting a profile'**
  String get beforeDeletingA;

  /// No description provided for @beforeReset.
  ///
  /// In en, this message translates to:
  /// **'Before reset'**
  String get beforeReset;

  /// No description provided for @beforeRestore.
  ///
  /// In en, this message translates to:
  /// **'Before restore'**
  String get beforeRestore;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @nc1718.
  ///
  /// In en, this message translates to:
  /// **'NC-17 / 18 and up'**
  String get nc1718;

  /// No description provided for @tvMaR.
  ///
  /// In en, this message translates to:
  /// **'TV-MA / R and up'**
  String get tvMaR;

  /// No description provided for @tv14Pg.
  ///
  /// In en, this message translates to:
  /// **'TV-14 / PG-13 and up'**
  String get tv14Pg;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @nowAndThen.
  ///
  /// In en, this message translates to:
  /// **'Now and then'**
  String get nowAndThen;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// No description provided for @truncate.
  ///
  /// In en, this message translates to:
  /// **'Truncate'**
  String get truncate;

  /// No description provided for @offlineImage.
  ///
  /// In en, this message translates to:
  /// **'Offline image'**
  String get offlineImage;

  /// No description provided for @filler.
  ///
  /// In en, this message translates to:
  /// **'Filler'**
  String get filler;

  /// No description provided for @leastWatchedFirst.
  ///
  /// In en, this message translates to:
  /// **'Least watched first'**
  String get leastWatchedFirst;

  /// No description provided for @shuffled.
  ///
  /// In en, this message translates to:
  /// **'Shuffled'**
  String get shuffled;

  /// No description provided for @inOrderShows.
  ///
  /// In en, this message translates to:
  /// **'In order (shows take turns)'**
  String get inOrderShows;

  /// No description provided for @channelsWhereEverything.
  ///
  /// In en, this message translates to:
  /// **'Channels where everything that plays, blocks included, is rated TV-Y, TV-Y7, TV-G or G.'**
  String get channelsWhereEverything;

  /// No description provided for @musicVideoAnd.
  ///
  /// In en, this message translates to:
  /// **'Music video and radio channels.'**
  String get musicVideoAnd;

  /// No description provided for @channelsThatPlay.
  ///
  /// In en, this message translates to:
  /// **'Channels that play movies and no episodes or music.'**
  String get channelsThatPlay;

  /// No description provided for @channelsFromYour.
  ///
  /// In en, this message translates to:
  /// **'Channels from your Live TV sources.'**
  String get channelsFromYour;

  /// No description provided for @channelsYouMarked.
  ///
  /// In en, this message translates to:
  /// **'Channels you marked as favorites.'**
  String get channelsYouMarked;

  /// No description provided for @everyChannel.
  ///
  /// In en, this message translates to:
  /// **'Every channel.'**
  String get everyChannel;

  /// No description provided for @kids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get kids;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @liveTv2.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get liveTv2;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @theAccentsAre.
  ///
  /// In en, this message translates to:
  /// **'The accents are a theme and theme or channel for each.'**
  String get theAccentsAre;

  /// No description provided for @thoseArentRetro.
  ///
  /// In en, this message translates to:
  /// **'Those aren\'t retro settings.'**
  String get thoseArentRetro;

  /// No description provided for @theOverlayTheme.
  ///
  /// In en, this message translates to:
  /// **'The overlay theme is standard, vcr, cableBox or stationIdent.'**
  String get theOverlayTheme;

  /// No description provided for @theCrtEffect.
  ///
  /// In en, this message translates to:
  /// **'The CRT effect is off, softTube, livingRoom, arcade, studioMonitor or custom.'**
  String get theCrtEffect;

  /// No description provided for @theSurroundImage.
  ///
  /// In en, this message translates to:
  /// **'The surround image is a file name.'**
  String get theSurroundImage;

  /// No description provided for @theSurroundIs.
  ///
  /// In en, this message translates to:
  /// **'The surround is black, charcoal, channel or image.'**
  String get theSurroundIs;

  /// No description provided for @thePictureShape.
  ///
  /// In en, this message translates to:
  /// **'The picture shape is original, fill43 or fit43.'**
  String get thePictureShape;

  /// No description provided for @channelColor.
  ///
  /// In en, this message translates to:
  /// **'Channel color'**
  String get channelColor;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @stationIdent.
  ///
  /// In en, this message translates to:
  /// **'Station ident'**
  String get stationIdent;

  /// No description provided for @cableBox.
  ///
  /// In en, this message translates to:
  /// **'Cable box'**
  String get cableBox;

  /// No description provided for @vcr.
  ///
  /// In en, this message translates to:
  /// **'VCR'**
  String get vcr;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @studioMonitor.
  ///
  /// In en, this message translates to:
  /// **'Studio monitor'**
  String get studioMonitor;

  /// No description provided for @arcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade'**
  String get arcade;

  /// No description provided for @livingRoom.
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get livingRoom;

  /// No description provided for @softTube.
  ///
  /// In en, this message translates to:
  /// **'Soft tube'**
  String get softTube;

  /// No description provided for @customColorIs.
  ///
  /// In en, this message translates to:
  /// **'Custom color is natural, warm, faded or vivid.'**
  String get customColorIs;

  /// No description provided for @customLinesIs.
  ///
  /// In en, this message translates to:
  /// **'Custom lines is 240 or 480.'**
  String get customLinesIs;

  /// No description provided for @customIsOff.
  ///
  /// In en, this message translates to:
  /// **'Custom {key} is off, low, medium or high.'**
  String customIsOff(Object key);

  /// No description provided for @thatIsntA.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a Custom style.'**
  String get thatIsntA;

  /// No description provided for @vivid.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get vivid;

  /// No description provided for @faded.
  ///
  /// In en, this message translates to:
  /// **'Faded'**
  String get faded;

  /// No description provided for @warm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get warm;

  /// No description provided for @natural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get natural;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @charcoal.
  ///
  /// In en, this message translates to:
  /// **'Charcoal'**
  String get charcoal;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get black;

  /// No description provided for @n43Fit.
  ///
  /// In en, this message translates to:
  /// **'4:3 fit'**
  String get n43Fit;

  /// No description provided for @n43Fill.
  ///
  /// In en, this message translates to:
  /// **'4:3 fill'**
  String get n43Fill;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @thisChannelIs.
  ///
  /// In en, this message translates to:
  /// **'This channel is off the air'**
  String get thisChannelIs;

  /// No description provided for @offAir.
  ///
  /// In en, this message translates to:
  /// **'Off Air'**
  String get offAir;

  /// No description provided for @tail.
  ///
  /// In en, this message translates to:
  /// **'Tail'**
  String get tail;

  /// No description provided for @postRoll.
  ///
  /// In en, this message translates to:
  /// **'Post-roll'**
  String get postRoll;

  /// No description provided for @midRoll.
  ///
  /// In en, this message translates to:
  /// **'Mid-roll'**
  String get midRoll;

  /// No description provided for @preRoll.
  ///
  /// In en, this message translates to:
  /// **'Pre-roll'**
  String get preRoll;

  /// No description provided for @commercials.
  ///
  /// In en, this message translates to:
  /// **'Commercials'**
  String get commercials;

  /// No description provided for @bumpers.
  ///
  /// In en, this message translates to:
  /// **'Bumpers'**
  String get bumpers;

  /// No description provided for @pleaseStandBy.
  ///
  /// In en, this message translates to:
  /// **'PLEASE STAND BY'**
  String get pleaseStandBy;

  /// No description provided for @offTheAir.
  ///
  /// In en, this message translates to:
  /// **'OFF THE AIR'**
  String get offTheAir;

  /// No description provided for @wellBeRight.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be right back'**
  String get wellBeRight;

  /// No description provided for @upNextAt.
  ///
  /// In en, this message translates to:
  /// **'Up next at {at}'**
  String upNextAt(Object at);

  /// No description provided for @backOnThe.
  ///
  /// In en, this message translates to:
  /// **'Back on the air {next} with {title}'**
  String backOnThe(Object next, Object title);

  /// No description provided for @processor.
  ///
  /// In en, this message translates to:
  /// **'Processor'**
  String get processor;

  /// No description provided for @graphicsCardNvenc.
  ///
  /// In en, this message translates to:
  /// **'Graphics card (NVENC)'**
  String get graphicsCardNvenc;

  /// No description provided for @graphicsCardVaapi.
  ///
  /// In en, this message translates to:
  /// **'Graphics card (VAAPI)'**
  String get graphicsCardVaapi;

  /// No description provided for @signInTo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this profile on the TV to export its channels.'**
  String get signInTo;

  /// No description provided for @signInToThis.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this profile here to export its channels.'**
  String get signInToThis;

  /// No description provided for @portIsIn.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is in use by another program. Pick another port, then update it in Plex or Jellyfin.'**
  String portIsIn(Object port);

  /// No description provided for @anotherProfileAlready.
  ///
  /// In en, this message translates to:
  /// **'Another profile already uses port {port}.'**
  String anotherProfileAlready(Object port);

  /// No description provided for @pickAPort.
  ///
  /// In en, this message translates to:
  /// **'Pick a port between 1024 and 65535.'**
  String get pickAPort;

  /// No description provided for @movie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get movie;

  /// No description provided for @backOnTheAir.
  ///
  /// In en, this message translates to:
  /// **'Back on the air {start} with {title}.'**
  String backOnTheAir(Object start, Object title);

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @couldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read that image. Try PNG, JPG, WebP or SVG.'**
  String get couldNotRead;

  /// No description provided for @thatFileIs.
  ///
  /// In en, this message translates to:
  /// **'That file is not a valid SVG.'**
  String get thatFileIs;

  /// No description provided for @thatImageIs.
  ///
  /// In en, this message translates to:
  /// **'That image is over 20 MB. Please pick a smaller one.'**
  String get thatImageIs;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @seasonsHolidays.
  ///
  /// In en, this message translates to:
  /// **'Seasons & Holidays'**
  String get seasonsHolidays;

  /// No description provided for @newsWeather.
  ///
  /// In en, this message translates to:
  /// **'News & Weather'**
  String get newsWeather;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get sports;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @kidsFamily.
  ///
  /// In en, this message translates to:
  /// **'Kids & Family'**
  String get kidsFamily;

  /// No description provided for @tvMovies.
  ///
  /// In en, this message translates to:
  /// **'TV & Movies'**
  String get tvMovies;

  /// No description provided for @theServerWould.
  ///
  /// In en, this message translates to:
  /// **'The server would not convert this item.'**
  String get theServerWould;

  /// No description provided for @theServerHas.
  ///
  /// In en, this message translates to:
  /// **'The server has no playable version of this item.'**
  String get theServerHas;

  /// No description provided for @externalLabel.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get externalLabel;

  /// No description provided for @scanningChannelSources.
  ///
  /// In en, this message translates to:
  /// **'Scanning channel sources…'**
  String get scanningChannelSources;

  /// No description provided for @didNotAnswer.
  ///
  /// In en, this message translates to:
  /// **'{serverUrl} did not answer like a Jellyfin server.'**
  String didNotAnswer(Object serverUrl);

  /// No description provided for @noJellyfinServer.
  ///
  /// In en, this message translates to:
  /// **'No Jellyfin server found at {serverUrl}. {message}'**
  String noJellyfinServer(Object serverUrl, Object message);

  /// No description provided for @serverErrorOn.
  ///
  /// In en, this message translates to:
  /// **'Server error {statusCode} on {path}.'**
  String serverErrorOn(Object statusCode, Object path);

  /// No description provided for @wrongUsernameOr.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password, or the session expired.'**
  String get wrongUsernameOr;

  /// No description provided for @couldNotReach.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server ({e}).'**
  String couldNotReach(Object e);

  /// No description provided for @theServerTook.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond.'**
  String get theServerTook;

  /// No description provided for @theServerWouldNot.
  ///
  /// In en, this message translates to:
  /// **'The server would not convert this channel.'**
  String get theServerWouldNot;

  /// No description provided for @musicVideo.
  ///
  /// In en, this message translates to:
  /// **'Music video'**
  String get musicVideo;

  /// No description provided for @movie2.
  ///
  /// In en, this message translates to:
  /// **'Movie · {year}'**
  String movie2(Object year);

  /// No description provided for @commercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial'**
  String get commercial;

  /// No description provided for @couldntReachThe.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the {what}'**
  String couldntReachThe(Object what);

  /// No description provided for @theIsToo.
  ///
  /// In en, this message translates to:
  /// **'The {what} is too big'**
  String theIsToo(Object what);

  /// No description provided for @theSAddress.
  ///
  /// In en, this message translates to:
  /// **'The {what}\'s address isn\'t a web address'**
  String theSAddress(Object what);

  /// No description provided for @noGuideInformation.
  ///
  /// In en, this message translates to:
  /// **'No guide information'**
  String get noGuideInformation;

  /// No description provided for @serverLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Server Live TV'**
  String get serverLiveTv;

  /// No description provided for @theChannelHas.
  ///
  /// In en, this message translates to:
  /// **'The channel has no stream address.'**
  String get theChannelHas;

  /// No description provided for @couldntReadThe.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the guide'**
  String get couldntReadThe;

  /// No description provided for @couldntReachTheGuide.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the guide'**
  String get couldntReachTheGuide;

  /// No description provided for @theSourceHas.
  ///
  /// In en, this message translates to:
  /// **'The source has no playlist'**
  String get theSourceHas;

  /// No description provided for @couldntReachThePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the playlist'**
  String get couldntReachThePlaylist;

  /// No description provided for @couldntReadThePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the playlist file'**
  String get couldntReadThePlaylist;

  /// No description provided for @couldntRefresh.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh {name}'**
  String couldntRefresh(Object name);

  /// No description provided for @thePlaylistHas.
  ///
  /// In en, this message translates to:
  /// **'The playlist has no channels'**
  String get thePlaylistHas;

  /// No description provided for @thatIsntAn.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t an M3U playlist'**
  String get thatIsntAn;

  /// No description provided for @thatIsntAnXmltv.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t an XMLTV guide'**
  String get thatIsntAnXmltv;

  /// No description provided for @theGuideIs.
  ///
  /// In en, this message translates to:
  /// **'The guide is too big (over 1 GB)'**
  String get theGuideIs;

  /// No description provided for @nightingaleTvBackups.
  ///
  /// In en, this message translates to:
  /// **'Nightingale TV backups'**
  String get nightingaleTvBackups;

  /// No description provided for @uninstallingThisApp.
  ///
  /// In en, this message translates to:
  /// **'Uninstalling this app deletes its profiles, channels and settings unless you back them up or move them first.'**
  String get uninstallingThisApp;

  /// No description provided for @theStoreVersion.
  ///
  /// In en, this message translates to:
  /// **'The store version installs beside this one as a separate app, \"{officialName}\", with its own setup. Buying it supports the project. Once it\'s installed, your setup can be moved to it from here.'**
  String theStoreVersion(Object officialName);

  /// No description provided for @updatesFromGoogle.
  ///
  /// In en, this message translates to:
  /// **'Updates from Google Play and official Nightingale TV APKs install over this one and keep your setup. A build of your own installs as a separate app, \"{ownBuildName}\", and your setup can be moved to it from here.'**
  String updatesFromGoogle(Object ownBuildName);

  /// No description provided for @yourOwnBuild.
  ///
  /// In en, this message translates to:
  /// **'Your own build'**
  String get yourOwnBuild;

  /// No description provided for @officialNightingaleTv.
  ///
  /// In en, this message translates to:
  /// **'Official Nightingale TV APK'**
  String get officialNightingaleTv;

  /// No description provided for @installedFromGoogle.
  ///
  /// In en, this message translates to:
  /// **'Installed from Google Play'**
  String get installedFromGoogle;

  /// No description provided for @nightingaleTvOwn.
  ///
  /// In en, this message translates to:
  /// **'Nightingale TV (own build)'**
  String get nightingaleTvOwn;

  /// No description provided for @sleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer off'**
  String get sleepTimerOff;

  /// No description provided for @sleepAtEnd.
  ///
  /// In en, this message translates to:
  /// **'Sleep at end of program'**
  String get sleepAtEnd;

  /// No description provided for @sleepInMin.
  ///
  /// In en, this message translates to:
  /// **'Sleep in {minutes} min'**
  String sleepInMin(Object minutes);

  /// No description provided for @forced.
  ///
  /// In en, this message translates to:
  /// **'Forced'**
  String get forced;

  /// No description provided for @unknownLanguage.
  ///
  /// In en, this message translates to:
  /// **'Unknown language'**
  String get unknownLanguage;

  /// No description provided for @didntStart.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t start'**
  String didntStart(Object name);

  /// No description provided for @thisDeviceCant.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t play this channel\'s video'**
  String get thisDeviceCant;

  /// No description provided for @thisChannelsStream.
  ///
  /// In en, this message translates to:
  /// **'This channel\'s stream type isn\'t supported on this device'**
  String get thisChannelsStream;

  /// No description provided for @refusedTheStream.
  ///
  /// In en, this message translates to:
  /// **'{name} refused the stream. It may be playing on another device.'**
  String refusedTheStream(Object name);

  /// No description provided for @yourAccountCant.
  ///
  /// In en, this message translates to:
  /// **'Your {server} account can\'t watch this channel'**
  String yourAccountCant(Object server);

  /// No description provided for @cantReach.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach {name}'**
  String cantReach(Object name);

  /// No description provided for @allOfS.
  ///
  /// In en, this message translates to:
  /// **'All of {server}\'s tuners are in use'**
  String allOfS(Object server);

  /// No description provided for @lostTheSignal.
  ///
  /// In en, this message translates to:
  /// **'Lost the signal on {name}'**
  String lostTheSignal(Object name);

  /// No description provided for @couldntPlayThat.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play that part. Back to live'**
  String get couldntPlayThat;

  /// No description provided for @backToLive.
  ///
  /// In en, this message translates to:
  /// **'Back to live'**
  String get backToLive;

  /// No description provided for @theServerTookToo.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to start converting this program.'**
  String get theServerTookToo;

  /// No description provided for @nothingToPlay.
  ///
  /// In en, this message translates to:
  /// **'Nothing to play on this channel'**
  String get nothingToPlay;

  /// No description provided for @captionsOn.
  ///
  /// In en, this message translates to:
  /// **'Captions on: {shown}'**
  String captionsOn(Object shown);

  /// No description provided for @captionsOn2.
  ///
  /// In en, this message translates to:
  /// **'Captions on'**
  String get captionsOn2;

  /// No description provided for @captionsOnNo.
  ///
  /// In en, this message translates to:
  /// **'Captions on: no subtitles for this program'**
  String get captionsOnNo;

  /// No description provided for @captionsOff.
  ///
  /// In en, this message translates to:
  /// **'Captions off'**
  String get captionsOff;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @thereHasTo.
  ///
  /// In en, this message translates to:
  /// **'There has to be at least one grown-up profile.'**
  String get thereHasTo;

  /// No description provided for @switchToAnother.
  ///
  /// In en, this message translates to:
  /// **'Switch to another profile before deleting this one.'**
  String get switchToAnother;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @couldntOpenA.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a network port for the remote.'**
  String get couldntOpenA;

  /// No description provided for @notPaired.
  ///
  /// In en, this message translates to:
  /// **'Not paired'**
  String get notPaired;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @thatCodeDoesnt.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match. Check the code on the TV.'**
  String get thatCodeDoesnt;

  /// No description provided for @openMenuPhone.
  ///
  /// In en, this message translates to:
  /// **'Open Menu → Phone remote on the TV to pair'**
  String get openMenuPhone;

  /// No description provided for @yourAccountCantWatch.
  ///
  /// In en, this message translates to:
  /// **'Your {serverName} account can\'t watch Live TV'**
  String yourAccountCantWatch(Object serverName);

  /// No description provided for @enterYourServer.
  ///
  /// In en, this message translates to:
  /// **'Enter your server address.'**
  String get enterYourServer;

  /// No description provided for @needsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Needs sign-in'**
  String get needsSignIn;

  /// No description provided for @cantBeReached.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be reached'**
  String get cantBeReached;

  /// No description provided for @isNotAnswering.
  ///
  /// In en, this message translates to:
  /// **'{name} is not answering at any of its addresses. Is it on?'**
  String isNotAnswering(Object name);

  /// No description provided for @everyServerOn.
  ///
  /// In en, this message translates to:
  /// **'Every server on this Plex account is already in this profile.'**
  String get everyServerOn;

  /// No description provided for @thisPlexAccount.
  ///
  /// In en, this message translates to:
  /// **'This Plex account has no servers. Ask the server\'s owner to share it with you.'**
  String get thisPlexAccount;

  /// No description provided for @quickConnectStopped.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect stopped: {message}'**
  String quickConnectStopped(Object message);

  /// No description provided for @enterYourUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter your username.'**
  String get enterYourUsername;

  /// No description provided for @plexDidNot.
  ///
  /// In en, this message translates to:
  /// **'Plex did not switch users.'**
  String get plexDidNot;

  /// No description provided for @plexTvError.
  ///
  /// In en, this message translates to:
  /// **'plex.tv error {statusCode}.'**
  String plexTvError(Object statusCode);

  /// No description provided for @yourPlexSign.
  ///
  /// In en, this message translates to:
  /// **'Your Plex sign-in expired.'**
  String get yourPlexSign;

  /// No description provided for @couldNotReachPlex.
  ///
  /// In en, this message translates to:
  /// **'Could not reach plex.tv ({e}).'**
  String couldNotReachPlex(Object e);

  /// No description provided for @plexTvTook.
  ///
  /// In en, this message translates to:
  /// **'plex.tv took too long to respond.'**
  String get plexTvTook;

  /// No description provided for @sharedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} — Shared by {ownerName}'**
  String sharedBy(Object name, Object ownerName);

  /// No description provided for @theServerWouldNotConvert.
  ///
  /// In en, this message translates to:
  /// **'The server would not convert this item ({transcodeDecisionText}).'**
  String theServerWouldNotConvert(Object transcodeDecisionText);

  /// No description provided for @theServerHasNo.
  ///
  /// In en, this message translates to:
  /// **'The server has no file for this item; refresh the library.'**
  String get theServerHasNo;

  /// No description provided for @didNotAnswerLike.
  ///
  /// In en, this message translates to:
  /// **'{serverUrl} did not answer like a Plex server.'**
  String didNotAnswerLike(Object serverUrl);

  /// No description provided for @noPlexServer.
  ///
  /// In en, this message translates to:
  /// **'No Plex server found at {serverUrl}. {message}'**
  String noPlexServer(Object serverUrl, Object message);

  /// No description provided for @thePlexSign.
  ///
  /// In en, this message translates to:
  /// **'The Plex sign-in expired.'**
  String get thePlexSign;

  /// No description provided for @channelIsNot.
  ///
  /// In en, this message translates to:
  /// **'Channel {channelId} is not on any DVR.'**
  String channelIsNot(Object channelId);

  /// No description provided for @noSuchUser.
  ///
  /// In en, this message translates to:
  /// **'No such user.'**
  String get noSuchUser;

  /// No description provided for @yourCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Your current password is wrong.'**
  String get yourCurrentPassword;

  /// No description provided for @signInFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in first.'**
  String get signInFirst;

  /// No description provided for @thereIsAlready.
  ///
  /// In en, this message translates to:
  /// **'There is already a user named {name}.'**
  String thereIsAlready(Object name);

  /// No description provided for @thisAccountIs.
  ///
  /// In en, this message translates to:
  /// **'This account is turned off.'**
  String get thisAccountIs;

  /// No description provided for @chooseAnAdmin.
  ///
  /// In en, this message translates to:
  /// **'Choose an admin account.'**
  String get chooseAnAdmin;

  /// No description provided for @useAtMost.
  ///
  /// In en, this message translates to:
  /// **'Use at most {maxNameLength} characters for the user name.'**
  String useAtMost(Object maxNameLength);

  /// No description provided for @enterAUser.
  ///
  /// In en, this message translates to:
  /// **'Enter a user name.'**
  String get enterAUser;

  /// No description provided for @useAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Use at least {minPasswordLength} characters.'**
  String useAtLeast(Object minPasswordLength);

  /// No description provided for @tooManyWrong.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong passwords. Try again in a minute.'**
  String get tooManyWrong;

  /// No description provided for @wrongUserName.
  ///
  /// In en, this message translates to:
  /// **'Wrong user name or password.'**
  String get wrongUserName;

  /// No description provided for @openTheSetup.
  ///
  /// In en, this message translates to:
  /// **'Open the setup link from the server\'s log.'**
  String get openTheSetup;

  /// No description provided for @makeSomeoneElse.
  ///
  /// In en, this message translates to:
  /// **'Make someone else an admin first.'**
  String get makeSomeoneElse;

  /// No description provided for @noSuchProfile.
  ///
  /// In en, this message translates to:
  /// **'No such profile.'**
  String get noSuchProfile;

  /// No description provided for @onlyAnAdmin.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can do that.'**
  String get onlyAnAdmin;

  /// No description provided for @thatProfileIsnt.
  ///
  /// In en, this message translates to:
  /// **'That profile isn\'t assigned to you.'**
  String get thatProfileIsnt;

  /// No description provided for @enterAGrown.
  ///
  /// In en, this message translates to:
  /// **'Enter a grown-up\'s PIN to change a kid profile\'s settings.'**
  String get enterAGrown;

  /// No description provided for @enterThisProfiles.
  ///
  /// In en, this message translates to:
  /// **'Enter this profile\'s PIN.'**
  String get enterThisProfiles;

  /// No description provided for @reloadThePage.
  ///
  /// In en, this message translates to:
  /// **'Reload the page and try again.'**
  String get reloadThePage;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {e}'**
  String somethingWentWrong(Object e);

  /// No description provided for @signInToThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this profile first.'**
  String get signInToThisProfile;

  /// No description provided for @changedInAnother.
  ///
  /// In en, this message translates to:
  /// **'Changed in another window. Showing the latest.'**
  String get changedInAnother;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get wrongPin;

  /// No description provided for @tooManyWrongPins.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Try again in a minute.'**
  String get tooManyWrongPins;

  /// No description provided for @theRoleIs.
  ///
  /// In en, this message translates to:
  /// **'The role is \"admin\" or \"user\".'**
  String get theRoleIs;

  /// No description provided for @noSuchBackup.
  ///
  /// In en, this message translates to:
  /// **'No such backup.'**
  String get noSuchBackup;

  /// No description provided for @backupsAreOff.
  ///
  /// In en, this message translates to:
  /// **'Backups are off.'**
  String get backupsAreOff;

  /// No description provided for @noSuchEncoder.
  ///
  /// In en, this message translates to:
  /// **'No such encoder.'**
  String get noSuchEncoder;

  /// No description provided for @allow1To.
  ///
  /// In en, this message translates to:
  /// **'Allow 1 to 16 streams.'**
  String get allow1To;

  /// No description provided for @noSuchQuality.
  ///
  /// In en, this message translates to:
  /// **'No such quality.'**
  String get noSuchQuality;

  /// No description provided for @processorOnly.
  ///
  /// In en, this message translates to:
  /// **'Processor only'**
  String get processorOnly;

  /// No description provided for @liveTvExport.
  ///
  /// In en, this message translates to:
  /// **'Live TV export isn\'t running.'**
  String get liveTvExport;

  /// No description provided for @thoseArentPremiere.
  ///
  /// In en, this message translates to:
  /// **'Those aren\'t premiere settings.'**
  String get thoseArentPremiere;

  /// No description provided for @theLogoMode.
  ///
  /// In en, this message translates to:
  /// **'The logo mode is always, nowAndThen or off.'**
  String get theLogoMode;

  /// No description provided for @thatIsntAPicture.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a picture in the custom logos folder.'**
  String get thatIsntAPicture;

  /// No description provided for @couldntSaveASafety.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save a safety backup first, so nothing was reset: {e}'**
  String couldntSaveASafety(Object e);

  /// No description provided for @theKindIs.
  ///
  /// In en, this message translates to:
  /// **'The kind is \"block\", \"music\" or \"custom\".'**
  String get theKindIs;

  /// No description provided for @thatIsntAPlay.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a play order.'**
  String get thatIsntAPlay;

  /// No description provided for @musicChannelsOnly.
  ///
  /// In en, this message translates to:
  /// **'Music channels only shuffle.'**
  String get musicChannelsOnly;

  /// No description provided for @channelNumbersStart.
  ///
  /// In en, this message translates to:
  /// **'Channel numbers start at 1.'**
  String get channelNumbersStart;

  /// No description provided for @slotLengthsAre.
  ///
  /// In en, this message translates to:
  /// **'Slot lengths are 15, 30, 60, 90 or 120 minutes.'**
  String get slotLengthsAre;

  /// No description provided for @thatIsntAChannel.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a channel.'**
  String get thatIsntAChannel;

  /// No description provided for @noSuchChannel.
  ///
  /// In en, this message translates to:
  /// **'No such channel.'**
  String get noSuchChannel;

  /// No description provided for @thatPictureIs.
  ///
  /// In en, this message translates to:
  /// **'That picture is too big (5 MB at most).'**
  String get thatPictureIs;

  /// No description provided for @unknownAction.
  ///
  /// In en, this message translates to:
  /// **'Unknown action.'**
  String get unknownAction;

  /// No description provided for @noSuchServer.
  ///
  /// In en, this message translates to:
  /// **'No such server.'**
  String get noSuchServer;

  /// No description provided for @startSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Start signing in first.'**
  String get startSigningIn;

  /// No description provided for @aRestoreIs.
  ///
  /// In en, this message translates to:
  /// **'A restore is already running.'**
  String get aRestoreIs;

  /// No description provided for @uploadTheBackup.
  ///
  /// In en, this message translates to:
  /// **'Upload the backup again.'**
  String get uploadTheBackup;

  /// No description provided for @discoveryIsOff.
  ///
  /// In en, this message translates to:
  /// **'Discovery is off, so add the tuner by address. Run the container with host networking to turn it on.'**
  String get discoveryIsOff;

  /// No description provided for @sendKeys.
  ///
  /// In en, this message translates to:
  /// **'Send keys.'**
  String get sendKeys;

  /// No description provided for @enterThePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Enter the playlist\'s address, or choose a playlist file'**
  String get enterThePlaylists;

  /// No description provided for @uploadTheFile.
  ///
  /// In en, this message translates to:
  /// **'Upload the file again.'**
  String get uploadTheFile;

  /// No description provided for @kidProfilesGet.
  ///
  /// In en, this message translates to:
  /// **'Kid profiles get no live channels.'**
  String get kidProfilesGet;

  /// No description provided for @liveTvIsAlready.
  ///
  /// In en, this message translates to:
  /// **'{name} Live TV is already added'**
  String liveTvIsAlready(Object name);

  /// No description provided for @noSuchSource.
  ///
  /// In en, this message translates to:
  /// **'No such source.'**
  String get noSuchSource;

  /// No description provided for @thatFileIsToo.
  ///
  /// In en, this message translates to:
  /// **'That file is too big (32 MB at most).'**
  String get thatFileIsToo;

  /// No description provided for @aPinIs.
  ///
  /// In en, this message translates to:
  /// **'A PIN is 4 digits.'**
  String get aPinIs;

  /// No description provided for @noSuchRating.
  ///
  /// In en, this message translates to:
  /// **'No such rating.'**
  String get noSuchRating;

  /// No description provided for @noSuchKind.
  ///
  /// In en, this message translates to:
  /// **'No such kind.'**
  String get noSuchKind;

  /// No description provided for @onlyAnAdminCan.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can change that.'**
  String get onlyAnAdminCan;

  /// No description provided for @shouldBeA.
  ///
  /// In en, this message translates to:
  /// **'\"{key}\" should be a list of text.'**
  String shouldBeA(Object key);

  /// No description provided for @shouldBeAn.
  ///
  /// In en, this message translates to:
  /// **'\"{key}\" should be an object.'**
  String shouldBeAn(Object key);

  /// No description provided for @shouldBeTrue.
  ///
  /// In en, this message translates to:
  /// **'\"{key}\" should be true or false.'**
  String shouldBeTrue(Object key);

  /// No description provided for @shouldBeANumber.
  ///
  /// In en, this message translates to:
  /// **'\"{key}\" should be a number.'**
  String shouldBeANumber(Object key);

  /// No description provided for @shouldBeText.
  ///
  /// In en, this message translates to:
  /// **'\"{key}\" should be text.'**
  String shouldBeText(Object key);

  /// No description provided for @expectedAJson.
  ///
  /// In en, this message translates to:
  /// **'Expected a JSON object.'**
  String get expectedAJson;

  /// No description provided for @thatIsToo.
  ///
  /// In en, this message translates to:
  /// **'That is too much to send at once.'**
  String get thatIsToo;

  /// No description provided for @aQualityLimit.
  ///
  /// In en, this message translates to:
  /// **'A quality limit is at least 500 kbps.'**
  String get aQualityLimit;

  /// No description provided for @orderShouldName.
  ///
  /// In en, this message translates to:
  /// **'\"order\" should name every server once.'**
  String get orderShouldName;

  /// No description provided for @orderIsMissing.
  ///
  /// In en, this message translates to:
  /// **'\"order\" is missing.'**
  String get orderIsMissing;

  /// No description provided for @signOutOf.
  ///
  /// In en, this message translates to:
  /// **'Sign out of the profile to change its main server.'**
  String get signOutOf;

  /// No description provided for @thoseArentPool.
  ///
  /// In en, this message translates to:
  /// **'Those aren\'t pool folders.'**
  String get thoseArentPool;

  /// No description provided for @sendRoots.
  ///
  /// In en, this message translates to:
  /// **'Send roots.'**
  String get sendRoots;

  /// No description provided for @thatIsntAPool.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a pool type.'**
  String get thatIsntAPool;

  /// No description provided for @giveThePool.
  ///
  /// In en, this message translates to:
  /// **'Give the pool a name.'**
  String get giveThePool;

  /// No description provided for @liveChannelsHave.
  ///
  /// In en, this message translates to:
  /// **'Live channels have no breaks.'**
  String get liveChannelsHave;

  /// No description provided for @sendAPlan.
  ///
  /// In en, this message translates to:
  /// **'Send a plan.'**
  String get sendAPlan;

  /// No description provided for @thatIsntABreak.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a break plan.'**
  String get thatIsntABreak;

  /// No description provided for @noSuchPool.
  ///
  /// In en, this message translates to:
  /// **'No such pool.'**
  String get noSuchPool;

  /// No description provided for @thatIsntAProgramming.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a programming block.'**
  String get thatIsntAProgramming;

  /// No description provided for @noSuchBlock.
  ///
  /// In en, this message translates to:
  /// **'No such block.'**
  String get noSuchBlock;

  /// No description provided for @sendEveryTab.
  ///
  /// In en, this message translates to:
  /// **'Send every tab once.'**
  String get sendEveryTab;

  /// No description provided for @sendChannelids.
  ///
  /// In en, this message translates to:
  /// **'Send channelIds.'**
  String get sendChannelids;

  /// No description provided for @giveTheGroup.
  ///
  /// In en, this message translates to:
  /// **'Give the group a name.'**
  String get giveTheGroup;

  /// No description provided for @noSuchGroup.
  ///
  /// In en, this message translates to:
  /// **'No such group.'**
  String get noSuchGroup;

  /// No description provided for @restoringBringsBack.
  ///
  /// In en, this message translates to:
  /// **'Restoring brings back your profiles, channels, blocks and settings. Each profile signs in to its server once.'**
  String get restoringBringsBack;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'{channels, plural, =1{{profiles} · {channels} channel} other{{profiles} · {channels} channels}}'**
  String channels(Object profiles, int channels);

  /// No description provided for @theresABackup.
  ///
  /// In en, this message translates to:
  /// **'There\'s a backup of your setup on this device:'**
  String get theresABackup;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @moveOkSelect.
  ///
  /// In en, this message translates to:
  /// **'◀▶ Move    OK Select'**
  String get moveOkSelect;

  /// No description provided for @startFresh.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get startFresh;

  /// No description provided for @restoreIt.
  ///
  /// In en, this message translates to:
  /// **'Restore it'**
  String get restoreIt;

  /// No description provided for @couldntRestore.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore'**
  String get couldntRestore;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @useYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Use your phone or computer'**
  String get useYourPhone;

  /// No description provided for @openABackup.
  ///
  /// In en, this message translates to:
  /// **'Open a backup file'**
  String get openABackup;

  /// No description provided for @setUpThis.
  ///
  /// In en, this message translates to:
  /// **'Set up this TV from a Nightingale TV backup: your profiles, channels, blocks and settings. Each profile signs in to its server once.'**
  String get setUpThis;

  /// No description provided for @restoreFromA.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get restoreFromA;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @thereYouCan.
  ///
  /// In en, this message translates to:
  /// **'There you can download a backup of this TV, or send one to restore here. Anything sent is confirmed on this TV first. The page closes with this window.'**
  String get thereYouCan;

  /// No description provided for @onAPhone.
  ///
  /// In en, this message translates to:
  /// **'On a phone, tablet or computer on the same Wi-Fi as this TV, scan the code or open:'**
  String get onAPhone;

  /// No description provided for @couldntOpenANetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a network port for the page.'**
  String get couldntOpenANetwork;

  /// No description provided for @thePageStopped.
  ///
  /// In en, this message translates to:
  /// **'The page stopped after 15 minutes with nothing to do. Close this and open it again.'**
  String get thePageStopped;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'{namesCount} and {last}'**
  String and(Object namesCount, Object last);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @liveTvExportMoves.
  ///
  /// In en, this message translates to:
  /// **'Live TV export moves to this device; turn it off on the old one.'**
  String get liveTvExportMoves;

  /// No description provided for @willNeedTo.
  ///
  /// In en, this message translates to:
  /// **'{need} will need to sign in to their server again.'**
  String willNeedTo(Object need);

  /// No description provided for @itSetsUp.
  ///
  /// In en, this message translates to:
  /// **'It sets up this TV as the backup has it.'**
  String get itSetsUp;

  /// No description provided for @itReplacesEverything.
  ///
  /// In en, this message translates to:
  /// **'It replaces everything on this TV. Your current setup is backed up first.'**
  String get itReplacesEverything;

  /// No description provided for @restoreTheBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore the backup from {toLocal}?'**
  String restoreTheBackup(Object toLocal);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @saveToFile.
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get saveToFile;

  /// No description provided for @madeOn.
  ///
  /// In en, this message translates to:
  /// **'Made on {device}'**
  String madeOn(Object device);

  /// No description provided for @moveOkSelectEsc.
  ///
  /// In en, this message translates to:
  /// **'▲▼◀▶ Move    OK Select    ESC Back'**
  String get moveOkSelectEsc;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupRestore;

  /// No description provided for @backups.
  ///
  /// In en, this message translates to:
  /// **'BACKUPS'**
  String get backups;

  /// No description provided for @backUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backUpNow;

  /// No description provided for @aBackupHolds.
  ///
  /// In en, this message translates to:
  /// **'A backup holds every profile with its channels, blocks, commercials and settings, and is made every day something changes. Sign-in passwords are never in it.'**
  String get aBackupHolds;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {toLocal} ({kindLabel}).'**
  String lastBackup(Object toLocal, Object kindLabel);

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet.'**
  String get noBackupsYet;

  /// No description provided for @itCantBe.
  ///
  /// In en, this message translates to:
  /// **'{toLocal} · {kindLabel}. It can\'t be brought back.'**
  String itCantBe(Object toLocal, Object kindLabel);

  /// No description provided for @deleteThisBackup.
  ///
  /// In en, this message translates to:
  /// **'Delete this backup?'**
  String get deleteThisBackup;

  /// No description provided for @couldntSaveThe.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the backup: {e}'**
  String couldntSaveThe(Object e);

  /// No description provided for @thatDidntWork.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work: {e}'**
  String thatDidntWork(Object e);

  /// No description provided for @aNewChannel.
  ///
  /// In en, this message translates to:
  /// **'A new channel is off the air outside the block, like a channel that signs off at night.'**
  String get aNewChannel;

  /// No description provided for @aNewChannelJust.
  ///
  /// In en, this message translates to:
  /// **'A new channel just for this block'**
  String get aNewChannelJust;

  /// No description provided for @moveOkChoose.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Choose    ESC Back'**
  String get moveOkChoose;

  /// No description provided for @chooseAChannel2.
  ///
  /// In en, this message translates to:
  /// **'Choose a channel'**
  String get chooseAChannel2;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'{keyCount} episodes'**
  String episodes(Object keyCount);

  /// No description provided for @moveOkAdd.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Add    ESC Back'**
  String get moveOkAdd;

  /// No description provided for @addAShow2.
  ///
  /// In en, this message translates to:
  /// **'Add a show'**
  String get addAShow2;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @episodes2.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} episode} other{{count} episodes}}'**
  String episodes2(int count);

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'+ Month'**
  String get month;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'+ Day'**
  String get day;

  /// No description provided for @day2.
  ///
  /// In en, this message translates to:
  /// **'− Day'**
  String get day2;

  /// No description provided for @month2.
  ///
  /// In en, this message translates to:
  /// **'− Month'**
  String get month2;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @weekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'DAYS'**
  String get days;

  /// No description provided for @starts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get starts;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get time;

  /// No description provided for @premieresAreOff.
  ///
  /// In en, this message translates to:
  /// **'Premieres are off'**
  String get premieresAreOff;

  /// No description provided for @premieresAreOn.
  ///
  /// In en, this message translates to:
  /// **'Premieres are on'**
  String get premieresAreOn;

  /// No description provided for @onTheAir.
  ///
  /// In en, this message translates to:
  /// **'ON THE AIR'**
  String get onTheAir;

  /// No description provided for @episodesAddedTo.
  ///
  /// In en, this message translates to:
  /// **'Episodes added to your server in the last two weeks premiere in a nightly slot on their show\'s channel: one new episode per show each night, for up to two hours, marked NEW. Programming blocks come first.'**
  String get episodesAddedTo;

  /// No description provided for @moveOkSelectEscCancel.
  ///
  /// In en, this message translates to:
  /// **'▲▼◀▶ Move    OK Select    ESC Cancel'**
  String get moveOkSelectEscCancel;

  /// No description provided for @newEpisodePremieres.
  ///
  /// In en, this message translates to:
  /// **'New episode premieres'**
  String get newEpisodePremieres;

  /// No description provided for @theChannelGoes.
  ///
  /// In en, this message translates to:
  /// **'The channel goes back to its regular programming at these times.'**
  String get theChannelGoes;

  /// No description provided for @delete2.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String delete2(Object title);

  /// No description provided for @addAnotherShow.
  ///
  /// In en, this message translates to:
  /// **'Add another show'**
  String get addAnotherShow;

  /// No description provided for @missingShow.
  ///
  /// In en, this message translates to:
  /// **'Missing show'**
  String get missingShow;

  /// No description provided for @runsThenStarts.
  ///
  /// In en, this message translates to:
  /// **'Runs {start}, then starts over.'**
  String runsThenStarts(Object start);

  /// No description provided for @fillsTheBlock.
  ///
  /// In en, this message translates to:
  /// **'Fills the block.'**
  String get fillsTheBlock;

  /// No description provided for @longerThanThe.
  ///
  /// In en, this message translates to:
  /// **'Longer than the block: it ends at {end}, cutting off {title}.'**
  String longerThanThe(Object end, Object title);

  /// No description provided for @onTheAirNow.
  ///
  /// In en, this message translates to:
  /// **'ON THE AIR NOW'**
  String get onTheAirNow;

  /// No description provided for @nextAiring.
  ///
  /// In en, this message translates to:
  /// **'NEXT AIRING · {start}'**
  String nextAiring(Object start);

  /// No description provided for @inAll.
  ///
  /// In en, this message translates to:
  /// **'{runtime} in all'**
  String inAll(Object runtime);

  /// No description provided for @movies2.
  ///
  /// In en, this message translates to:
  /// **'{movies, plural, =1{{movies} movie} other{{movies} movies}}'**
  String movies2(int movies);

  /// No description provided for @shows.
  ///
  /// In en, this message translates to:
  /// **'{showsCount, plural, =1{{showsCount} show} other{{showsCount} shows}}'**
  String shows(int showsCount);

  /// No description provided for @nothingYetChoose.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Choose shows or movies.'**
  String get nothingYetChoose;

  /// No description provided for @nothingYetAdd.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Add shows to the lineup.'**
  String get nothingYetAdd;

  /// No description provided for @plays.
  ///
  /// In en, this message translates to:
  /// **'PLAYS'**
  String get plays;

  /// No description provided for @onLabel.
  ///
  /// In en, this message translates to:
  /// **'On {number} {name}'**
  String onLabel(Object number, Object name);

  /// No description provided for @noChannelChosen.
  ///
  /// In en, this message translates to:
  /// **'No channel chosen'**
  String get noChannelChosen;

  /// No description provided for @onANew.
  ///
  /// In en, this message translates to:
  /// **'On a new channel (off the air at other times)'**
  String get onANew;

  /// No description provided for @untitledBlock.
  ///
  /// In en, this message translates to:
  /// **'Untitled block'**
  String get untitledBlock;

  /// No description provided for @deleteBlock.
  ///
  /// In en, this message translates to:
  /// **'Delete block'**
  String get deleteBlock;

  /// No description provided for @blockIsOff.
  ///
  /// In en, this message translates to:
  /// **'Block is off'**
  String get blockIsOff;

  /// No description provided for @blockIsOn.
  ///
  /// In en, this message translates to:
  /// **'Block is on'**
  String get blockIsOn;

  /// No description provided for @onlyShowsAnd.
  ///
  /// In en, this message translates to:
  /// **'Only shows and movies rated this or higher. Unrated ones are left out.'**
  String get onlyShowsAnd;

  /// No description provided for @anyRating.
  ///
  /// In en, this message translates to:
  /// **'Any rating'**
  String get anyRating;

  /// No description provided for @minimumRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum rating'**
  String get minimumRating;

  /// No description provided for @chooseShowsMovies.
  ///
  /// In en, this message translates to:
  /// **'Choose shows & movies'**
  String get chooseShowsMovies;

  /// No description provided for @showsAndMovies.
  ///
  /// In en, this message translates to:
  /// **'Shows and movies you choose, in order or shuffled.'**
  String get showsAndMovies;

  /// No description provided for @yourShowsIn.
  ///
  /// In en, this message translates to:
  /// **'Your shows in this order, each playing its next episode every airing. If time is left, the lineup starts over.'**
  String get yourShowsIn;

  /// No description provided for @aLineup.
  ///
  /// In en, this message translates to:
  /// **'A lineup'**
  String get aLineup;

  /// No description provided for @aMix.
  ///
  /// In en, this message translates to:
  /// **'A mix'**
  String get aMix;

  /// No description provided for @whatItPlays.
  ///
  /// In en, this message translates to:
  /// **'WHAT IT PLAYS'**
  String get whatItPlays;

  /// No description provided for @repeatsEveryYear.
  ///
  /// In en, this message translates to:
  /// **'Repeats every year.'**
  String get repeatsEveryYear;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @onlyBetweenDates.
  ///
  /// In en, this message translates to:
  /// **'Only between dates'**
  String get onlyBetweenDates;

  /// No description provided for @allYear.
  ///
  /// In en, this message translates to:
  /// **'All year'**
  String get allYear;

  /// No description provided for @dates.
  ///
  /// In en, this message translates to:
  /// **'DATES'**
  String get dates;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **' (next day)'**
  String get nextDay;

  /// No description provided for @ends.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get ends;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL'**
  String get channel;

  /// No description provided for @saturdayMorningCartoons.
  ///
  /// In en, this message translates to:
  /// **'Saturday Morning Cartoons'**
  String get saturdayMorningCartoons;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @newProgrammingBlock.
  ///
  /// In en, this message translates to:
  /// **'New programming block'**
  String get newProgrammingBlock;

  /// No description provided for @newLateNight.
  ///
  /// In en, this message translates to:
  /// **'New late-night block'**
  String get newLateNight;

  /// No description provided for @editProgrammingBlock.
  ///
  /// In en, this message translates to:
  /// **'Edit programming block'**
  String get editProgrammingBlock;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next: {next} {next2}'**
  String next(Object next, Object next2);

  /// No description provided for @onTheAirNow2.
  ///
  /// In en, this message translates to:
  /// **'On the air now'**
  String get onTheAirNow2;

  /// No description provided for @noUpcomingAirings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming airings'**
  String get noUpcomingAirings;

  /// No description provided for @itsChannelIs.
  ///
  /// In en, this message translates to:
  /// **'Its channel is gone. Pick a new one.'**
  String get itsChannelIs;

  /// No description provided for @turnedOff.
  ///
  /// In en, this message translates to:
  /// **'Turned off'**
  String get turnedOff;

  /// No description provided for @blocksTakeOver.
  ///
  /// In en, this message translates to:
  /// **'Blocks take over a channel on the days and times you choose, like Saturday morning cartoons. Each airing picks up where the last one left off.'**
  String get blocksTakeOver;

  /// No description provided for @moveOkEdit.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Edit    ESC Back'**
  String get moveOkEdit;

  /// No description provided for @programmingBlocks.
  ///
  /// In en, this message translates to:
  /// **'Programming blocks'**
  String get programmingBlocks;

  /// No description provided for @newlyAddedEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Newly added episodes, on their show\'s channel'**
  String get newlyAddedEpisodes;

  /// No description provided for @onLabel2.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onLabel2;

  /// No description provided for @clips.
  ///
  /// In en, this message translates to:
  /// **'{clips, plural, =1{{name}  ·  {clips} clip} other{{name}  ·  {clips} clips}}'**
  String clips(Object name, int clips);

  /// No description provided for @n100MinMovie.
  ///
  /// In en, this message translates to:
  /// **'100-min movie'**
  String get n100MinMovie;

  /// No description provided for @n44MinDrama.
  ///
  /// In en, this message translates to:
  /// **'44-min drama'**
  String get n44MinDrama;

  /// No description provided for @n22MinSitcom.
  ///
  /// In en, this message translates to:
  /// **'22-min sitcom'**
  String get n22MinSitcom;

  /// No description provided for @breaksInside.
  ///
  /// In en, this message translates to:
  /// **'{midCount, plural, =1{, {midCount} break inside} other{, {midCount} breaks inside}}'**
  String breaksInside(int midCount);

  /// No description provided for @noBreaks.
  ///
  /// In en, this message translates to:
  /// **'{name}: no breaks'**
  String noBreaks(Object name);

  /// No description provided for @openAndClose.
  ///
  /// In en, this message translates to:
  /// **'Open and close breaks, from pools set to Bumpers'**
  String get openAndClose;

  /// No description provided for @bumpers2.
  ///
  /// In en, this message translates to:
  /// **'BUMPERS'**
  String get bumpers2;

  /// No description provided for @toTheHalf.
  ///
  /// In en, this message translates to:
  /// **'To the half hour'**
  String get toTheHalf;

  /// No description provided for @toTheHour.
  ///
  /// In en, this message translates to:
  /// **'To the hour'**
  String get toTheHour;

  /// No description provided for @padsEachSlot.
  ///
  /// In en, this message translates to:
  /// **'Pads each slot to the clock, so programs start on time'**
  String get padsEachSlot;

  /// No description provided for @tail2.
  ///
  /// In en, this message translates to:
  /// **'TAIL'**
  String get tail2;

  /// No description provided for @afterEachProgram.
  ///
  /// In en, this message translates to:
  /// **'After each program'**
  String get afterEachProgram;

  /// No description provided for @postRoll2.
  ///
  /// In en, this message translates to:
  /// **'POST-ROLL'**
  String get postRoll2;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'{inMinutes} min'**
  String min(Object inMinutes);

  /// No description provided for @breaksInsideShows.
  ///
  /// In en, this message translates to:
  /// **'Breaks inside shows and movies, at act breaks when they can be found'**
  String get breaksInsideShows;

  /// No description provided for @midRoll2.
  ///
  /// In en, this message translates to:
  /// **'MID-ROLL'**
  String get midRoll2;

  /// No description provided for @beforeEachProgram.
  ///
  /// In en, this message translates to:
  /// **'Before each program'**
  String get beforeEachProgram;

  /// No description provided for @preRoll2.
  ///
  /// In en, this message translates to:
  /// **'PRE-ROLL'**
  String get preRoll2;

  /// No description provided for @onePool.
  ///
  /// In en, this message translates to:
  /// **'One pool…'**
  String get onePool;

  /// No description provided for @allBumperPools.
  ///
  /// In en, this message translates to:
  /// **'All bumper pools'**
  String get allBumperPools;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @clipsFrom.
  ///
  /// In en, this message translates to:
  /// **'Clips from: {pool}'**
  String clipsFrom(Object pool);

  /// No description provided for @allPools.
  ///
  /// In en, this message translates to:
  /// **'All pools'**
  String get allPools;

  /// No description provided for @clips2.
  ///
  /// In en, this message translates to:
  /// **'{label} clips'**
  String clips2(Object label);

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @yourChangesTo.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the break settings are lost.'**
  String get yourChangesTo;

  /// No description provided for @leaveWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get leaveWithoutSaving;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @captions.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get captions;

  /// No description provided for @sampleCaption.
  ///
  /// In en, this message translates to:
  /// **'Sample caption'**
  String get sampleCaption;

  /// No description provided for @theServerDraws.
  ///
  /// In en, this message translates to:
  /// **'The server draws these captions into the picture, so their size can\'t change here.'**
  String get theServerDraws;

  /// No description provided for @findingSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Finding subtitles…'**
  String get findingSubtitles;

  /// No description provided for @noSubtitlesFor.
  ///
  /// In en, this message translates to:
  /// **'No subtitles for this program'**
  String get noSubtitlesFor;

  /// No description provided for @hrMin.
  ///
  /// In en, this message translates to:
  /// **'{inHours} hr {inMinutes} min'**
  String hrMin(Object inHours, Object inMinutes);

  /// No description provided for @days2.
  ///
  /// In en, this message translates to:
  /// **'{toStringAsFixed} days'**
  String days2(Object toStringAsFixed);

  /// No description provided for @theChannelGoesAway.
  ///
  /// In en, this message translates to:
  /// **'The channel goes away, with its programming blocks and its places in channel groups.'**
  String get theChannelGoesAway;

  /// No description provided for @remove2.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String remove2(Object name);

  /// No description provided for @contentOf.
  ///
  /// In en, this message translates to:
  /// **'Content of {name}'**
  String contentOf(Object name);

  /// No description provided for @newChannel.
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get newChannel;

  /// No description provided for @defaultCard.
  ///
  /// In en, this message translates to:
  /// **'Default card'**
  String get defaultCard;

  /// No description provided for @changeOfflineImage.
  ///
  /// In en, this message translates to:
  /// **'Change offline image…'**
  String get changeOfflineImage;

  /// No description provided for @offlineImage2.
  ///
  /// In en, this message translates to:
  /// **'Offline image…'**
  String get offlineImage2;

  /// No description provided for @fillerPool.
  ///
  /// In en, this message translates to:
  /// **'Filler pool: {poolName}'**
  String fillerPool(Object poolName);

  /// No description provided for @slotLength.
  ///
  /// In en, this message translates to:
  /// **'SLOT LENGTH'**
  String get slotLength;

  /// No description provided for @hideFromGuide.
  ///
  /// In en, this message translates to:
  /// **'Hide from guide'**
  String get hideFromGuide;

  /// No description provided for @showInGuide.
  ///
  /// In en, this message translates to:
  /// **'Show in guide'**
  String get showInGuide;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get unfavorite;

  /// No description provided for @mainSetting.
  ///
  /// In en, this message translates to:
  /// **'Main setting ({label})'**
  String mainSetting(Object label);

  /// No description provided for @channelLogo.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL LOGO'**
  String get channelLogo;

  /// No description provided for @breaksOn.
  ///
  /// In en, this message translates to:
  /// **'Breaks on {name}'**
  String breaksOn(Object name);

  /// No description provided for @custom2.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get custom2;

  /// No description provided for @commercials2.
  ///
  /// In en, this message translates to:
  /// **'COMMERCIALS'**
  String get commercials2;

  /// No description provided for @removeChannel.
  ///
  /// In en, this message translates to:
  /// **'Remove channel'**
  String get removeChannel;

  /// No description provided for @reshuffle.
  ///
  /// In en, this message translates to:
  /// **'Reshuffle'**
  String get reshuffle;

  /// No description provided for @editContent.
  ///
  /// In en, this message translates to:
  /// **'Edit content'**
  String get editContent;

  /// No description provided for @number.
  ///
  /// In en, this message translates to:
  /// **'Number +'**
  String get number;

  /// No description provided for @number2.
  ///
  /// In en, this message translates to:
  /// **'Number −'**
  String get number2;

  /// No description provided for @sourcesLogo.
  ///
  /// In en, this message translates to:
  /// **'Source\'s logo'**
  String get sourcesLogo;

  /// No description provided for @changeIcon.
  ///
  /// In en, this message translates to:
  /// **'Change icon'**
  String get changeIcon;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelName;

  /// No description provided for @programmingBlocks2.
  ///
  /// In en, this message translates to:
  /// **'{blockCount, plural, =1{{blockCount} programming block} other{{blockCount} programming blocks}}'**
  String programmingBlocks2(int blockCount);

  /// No description provided for @repeatsEvery.
  ///
  /// In en, this message translates to:
  /// **'repeats every {loop}'**
  String repeatsEvery(Object loop);

  /// No description provided for @programs.
  ///
  /// In en, this message translates to:
  /// **'{playlistCount} programs'**
  String programs(Object playlistCount);

  /// No description provided for @programmingBlocksOnly.
  ///
  /// In en, this message translates to:
  /// **'Programming blocks only'**
  String get programmingBlocksOnly;

  /// No description provided for @channelThere.
  ///
  /// In en, this message translates to:
  /// **'channel {n} there'**
  String channelThere(Object n);

  /// No description provided for @channel2.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL {number}'**
  String channel2(Object number);

  /// No description provided for @noChannelsYet.
  ///
  /// In en, this message translates to:
  /// **'No channels yet'**
  String get noChannelsYet;

  /// No description provided for @guideRange.
  ///
  /// In en, this message translates to:
  /// **'GUIDE RANGE'**
  String get guideRange;

  /// No description provided for @channelsEditOk.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Channels    ▶ Edit    OK Select    ESC Back'**
  String get channelsEditOk;

  /// No description provided for @channelsIcons.
  ///
  /// In en, this message translates to:
  /// **'Channels & icons'**
  String get channelsIcons;

  /// No description provided for @howFarAhead.
  ///
  /// In en, this message translates to:
  /// **'How far ahead the guide shows, from now.'**
  String get howFarAhead;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String hours(Object hours);

  /// No description provided for @theChannelLogo.
  ///
  /// In en, this message translates to:
  /// **'The channel logo in the corner of the picture, on the TV and in Live TV export.'**
  String get theChannelLogo;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @channels2.
  ///
  /// In en, this message translates to:
  /// **'CHANNELS'**
  String get channels2;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group: {name}'**
  String group(Object name);

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @itsTabLeaves.
  ///
  /// In en, this message translates to:
  /// **'Its tab leaves the guide. The channels stay in your lineup.'**
  String get itsTabLeaves;

  /// No description provided for @channels3.
  ///
  /// In en, this message translates to:
  /// **'{membersCount, plural, =1{{membersCount} channel} other{{membersCount} channels}}'**
  String channels3(int membersCount);

  /// No description provided for @channelsYouPicked.
  ///
  /// In en, this message translates to:
  /// **'Channels you picked.'**
  String get channelsYouPicked;

  /// No description provided for @theTabsAt.
  ///
  /// In en, this message translates to:
  /// **'The tabs at the top of the guide, in this order. Hidden tabs and tabs with no channels aren\'t shown.'**
  String get theTabsAt;

  /// No description provided for @channelGroups.
  ///
  /// In en, this message translates to:
  /// **'Channel groups'**
  String get channelGroups;

  /// No description provided for @shown.
  ///
  /// In en, this message translates to:
  /// **'Shown'**
  String get shown;

  /// No description provided for @down.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get down;

  /// No description provided for @up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get up;

  /// No description provided for @automatic2.
  ///
  /// In en, this message translates to:
  /// **'· automatic'**
  String get automatic2;

  /// No description provided for @channels4.
  ///
  /// In en, this message translates to:
  /// **'· {channelIdsCount} channels'**
  String channels4(Object channelIdsCount);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @commercialsNeverShow.
  ///
  /// In en, this message translates to:
  /// **'Commercials never show up in your server\'s watch history.'**
  String get commercialsNeverShow;

  /// No description provided for @theSameAds.
  ///
  /// In en, this message translates to:
  /// **'The same ads play for everyone, every time.'**
  String get theSameAds;

  /// No description provided for @bumperPoolsClips.
  ///
  /// In en, this message translates to:
  /// **'Bumper pools\' clips open and close breaks, and never play as ads.'**
  String get bumperPoolsClips;

  /// No description provided for @howBreaksWork.
  ///
  /// In en, this message translates to:
  /// **'HOW BREAKS WORK'**
  String get howBreaksWork;

  /// No description provided for @withATail.
  ///
  /// In en, this message translates to:
  /// **'With a tail, slots are padded out to the clock.'**
  String get withATail;

  /// No description provided for @adsShrinkTo.
  ///
  /// In en, this message translates to:
  /// **'Ads shrink to fit the slot, and no break runs over 5 minutes.'**
  String get adsShrinkTo;

  /// No description provided for @aShortBreak.
  ///
  /// In en, this message translates to:
  /// **'A short break before the show, a break every 10 minutes inside it (12 for movies), at act breaks when they can be found, and the rest after it.'**
  String get aShortBreak;

  /// No description provided for @pickAutomaticFor.
  ///
  /// In en, this message translates to:
  /// **'Pick Automatic for breaks like broadcast TV, or Custom to set them up yourself.'**
  String get pickAutomaticFor;

  /// No description provided for @workingOn.
  ///
  /// In en, this message translates to:
  /// **'Working on {current}…'**
  String workingOn(Object current);

  /// No description provided for @analysis.
  ///
  /// In en, this message translates to:
  /// **'ANALYSIS'**
  String get analysis;

  /// No description provided for @couldNotBe.
  ///
  /// In en, this message translates to:
  /// **'{failed} could not be analyzed (they\'re tried again if the file changes)'**
  String couldNotBe(Object failed);

  /// No description provided for @programsWithBreak.
  ///
  /// In en, this message translates to:
  /// **'Programs with break points: {programsDone} of {programsTotal}'**
  String programsWithBreak(Object programsDone, Object programsTotal);

  /// No description provided for @longVideosSplit.
  ///
  /// In en, this message translates to:
  /// **'Long videos split: {reelsDone} of {reelsTotal}'**
  String longVideosSplit(Object reelsDone, Object reelsTotal);

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'{folders, plural, =1{{folders} folder  ·  {idCount}} other{{folders} folders  ·  {idCount}}}'**
  String folders(int folders, Object idCount);

  /// No description provided for @fromCommercialPools.
  ///
  /// In en, this message translates to:
  /// **'{used, plural, =1{{clips} from {used} commercial pool.} other{{clips} from {used} commercial pools.}}'**
  String fromCommercialPools(Object clips, int used);

  /// No description provided for @breaksStartOnce.
  ///
  /// In en, this message translates to:
  /// **'Breaks start once a pool has clips. Add folders with videos to a pool.'**
  String get breaksStartOnce;

  /// No description provided for @breaksStartOnceA.
  ///
  /// In en, this message translates to:
  /// **'Breaks start once a pool has clips. Its long videos are being split now.'**
  String get breaksStartOnceA;

  /// No description provided for @breaksStartOnceAPool.
  ///
  /// In en, this message translates to:
  /// **'Breaks start once a pool has clips. Make a pool below.'**
  String get breaksStartOnceAPool;

  /// No description provided for @breaksAreOff.
  ///
  /// In en, this message translates to:
  /// **'Breaks are off. {clips} ready in your pools.'**
  String breaksAreOff(Object clips);

  /// No description provided for @breaksAreOff2.
  ///
  /// In en, this message translates to:
  /// **'Breaks are off.'**
  String get breaksAreOff2;

  /// No description provided for @clips3.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} clip} other{{n} clips}}'**
  String clips3(int n);

  /// No description provided for @lastScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Last scan failed: {syncError}'**
  String lastScanFailed(Object syncError);

  /// No description provided for @newPool.
  ///
  /// In en, this message translates to:
  /// **'New pool'**
  String get newPool;

  /// No description provided for @pickTheFolders.
  ///
  /// In en, this message translates to:
  /// **'Pick the folders on your server that hold commercials and bumpers. Their videos leave your regular channels and fill the breaks instead. Set a pool\'s type to Bumpers to have its clips open and close breaks.'**
  String get pickTheFolders;

  /// No description provided for @pools.
  ///
  /// In en, this message translates to:
  /// **'POOLS'**
  String get pools;

  /// No description provided for @breakSettings.
  ///
  /// In en, this message translates to:
  /// **'Break settings…'**
  String get breakSettings;

  /// No description provided for @commercialBreaks.
  ///
  /// In en, this message translates to:
  /// **'COMMERCIAL BREAKS'**
  String get commercialBreaks;

  /// No description provided for @breakSettings2.
  ///
  /// In en, this message translates to:
  /// **'Break settings'**
  String get breakSettings2;

  /// No description provided for @breakPointsAlso.
  ///
  /// In en, this message translates to:
  /// **'{ffmpegWarning}{count} Break points also land more naturally with it.'**
  String breakPointsAlso(Object ffmpegWarning, Object count);

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **' ({waiting} waiting).'**
  String waiting(Object waiting);

  /// No description provided for @longCommercialVideos.
  ///
  /// In en, this message translates to:
  /// **'Long commercial videos without chapters can\'t be split on this device'**
  String get longCommercialVideos;

  /// No description provided for @installFfmpegTo.
  ///
  /// In en, this message translates to:
  /// **'Install ffmpeg to split long commercial videos'**
  String get installFfmpegTo;

  /// No description provided for @picturesOnThis.
  ///
  /// In en, this message translates to:
  /// **'Pictures on this device, newest first. Big ones are shrunk to 512 px.'**
  String get picturesOnThis;

  /// No description provided for @noPicturesOn.
  ///
  /// In en, this message translates to:
  /// **'No pictures on this device yet. Copy a PNG or JPG to its Download folder or onto a USB drive, then try again.'**
  String get noPicturesOn;

  /// No description provided for @lookingForPictures.
  ///
  /// In en, this message translates to:
  /// **'Looking for pictures…'**
  String get lookingForPictures;

  /// No description provided for @couldntReadThePictures.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the pictures on this device.'**
  String get couldntReadThePictures;

  /// No description provided for @nightingaleTvIsnt.
  ///
  /// In en, this message translates to:
  /// **'Nightingale TV isn\'t allowed to see the pictures on this device. Allow \"Photos and videos\" for it in Android\'s Settings › Apps › Nightingale TV › Permissions, then try again.'**
  String get nightingaleTvIsnt;

  /// No description provided for @moveOkChooseEsc.
  ///
  /// In en, this message translates to:
  /// **'◀▶▲▼ Move    OK Choose    ESC Cancel'**
  String get moveOkChooseEsc;

  /// No description provided for @chooseAPicture.
  ///
  /// In en, this message translates to:
  /// **'Choose a picture'**
  String get chooseAPicture;

  /// No description provided for @thePoolHasnt.
  ///
  /// In en, this message translates to:
  /// **'{error}  The pool hasn\'t changed.'**
  String thePoolHasnt(Object error);

  /// No description provided for @nothingHasChanged.
  ///
  /// In en, this message translates to:
  /// **'{error}  Nothing has changed.'**
  String nothingHasChanged(Object error);

  /// No description provided for @couldntReachTheServer.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server'**
  String get couldntReachTheServer;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @nothingInside.
  ///
  /// In en, this message translates to:
  /// **'Nothing inside'**
  String get nothingInside;

  /// No description provided for @noMovies.
  ///
  /// In en, this message translates to:
  /// **'No movies'**
  String get noMovies;

  /// No description provided for @inside.
  ///
  /// In en, this message translates to:
  /// **'{childrenCount} inside'**
  String inside(Object childrenCount);

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'{name} (collection)'**
  String collection(Object name);

  /// No description provided for @included.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get included;

  /// No description provided for @nothingInside2.
  ///
  /// In en, this message translates to:
  /// **'Nothing inside.'**
  String get nothingInside2;

  /// No description provided for @loadingFolders.
  ///
  /// In en, this message translates to:
  /// **'Loading folders…'**
  String get loadingFolders;

  /// No description provided for @pressOnA.
  ///
  /// In en, this message translates to:
  /// **'Press ▶ on a library to see what\'s in it.'**
  String get pressOnA;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ticked.
  ///
  /// In en, this message translates to:
  /// **'{_pickedCount} ticked'**
  String ticked(Object _pickedCount);

  /// No description provided for @nothingTickedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing ticked yet. Tick a library to use all of it, or ▶ to pick what\'s in it.'**
  String get nothingTickedYet;

  /// No description provided for @wholeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Whole library'**
  String get wholeLibrary;

  /// No description provided for @libraries.
  ///
  /// In en, this message translates to:
  /// **'LIBRARIES'**
  String get libraries;

  /// No description provided for @loadingLibraries.
  ///
  /// In en, this message translates to:
  /// **'Loading libraries…'**
  String get loadingLibraries;

  /// No description provided for @moveOkTick.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Tick    ▶ Open    ◀ Back up    ESC Cancel'**
  String get moveOkTick;

  /// No description provided for @foldersFor.
  ///
  /// In en, this message translates to:
  /// **'Folders for {poolName}'**
  String foldersFor(Object poolName);

  /// No description provided for @chooseFolders.
  ///
  /// In en, this message translates to:
  /// **'Choose folders'**
  String get chooseFolders;

  /// No description provided for @chooseWhatPlays.
  ///
  /// In en, this message translates to:
  /// **'Choose what plays on this channel'**
  String get chooseWhatPlays;

  /// No description provided for @endsEarly.
  ///
  /// In en, this message translates to:
  /// **'Ends early'**
  String get endsEarly;

  /// No description provided for @madeFromThis.
  ///
  /// In en, this message translates to:
  /// **'Made from this channel\'s shows and movies, and updated with the library. Change anything and it becomes yours.'**
  String get madeFromThis;

  /// No description provided for @fromTheLineup.
  ///
  /// In en, this message translates to:
  /// **'From the lineup'**
  String get fromTheLineup;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday {t}'**
  String yesterday(Object t);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today {t}'**
  String today(Object t);

  /// No description provided for @behind.
  ///
  /// In en, this message translates to:
  /// **'{d} behind'**
  String behind(Object d);

  /// No description provided for @hr.
  ///
  /// In en, this message translates to:
  /// **'{h} hr'**
  String hr(Object h);

  /// No description provided for @underAMinute.
  ///
  /// In en, this message translates to:
  /// **'under a minute'**
  String get underAMinute;

  /// No description provided for @noProgramming.
  ///
  /// In en, this message translates to:
  /// **'No programming'**
  String get noProgramming;

  /// No description provided for @today2.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today2;

  /// No description provided for @tuning.
  ///
  /// In en, this message translates to:
  /// **'TUNING…'**
  String get tuning;

  /// No description provided for @offAir2.
  ///
  /// In en, this message translates to:
  /// **'OFF AIR'**
  String get offAir2;

  /// No description provided for @noSignal.
  ///
  /// In en, this message translates to:
  /// **'NO SIGNAL'**
  String get noSignal;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'{now} left'**
  String left(Object now);

  /// No description provided for @nothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get nothingScheduled;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @nightingaleTvGuide.
  ///
  /// In en, this message translates to:
  /// **'NIGHTINGALE TV GUIDE'**
  String get nightingaleTvGuide;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing: {title}'**
  String nowPlaying(Object title);

  /// No description provided for @mMenu.
  ///
  /// In en, this message translates to:
  /// **'M Menu'**
  String get mMenu;

  /// No description provided for @escBackTo.
  ///
  /// In en, this message translates to:
  /// **'ESC Back to TV'**
  String get escBackTo;

  /// No description provided for @channelsTabsTime.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Channels     ▲ Tabs     ◀▶ Time     OK Watch     '**
  String get channelsTabsTime;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @channelsUsingIt.
  ///
  /// In en, this message translates to:
  /// **'Channels using it go back to a default icon.'**
  String get channelsUsingIt;

  /// No description provided for @deleteThisIcon.
  ///
  /// In en, this message translates to:
  /// **'Delete this icon?'**
  String get deleteThisIcon;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image…'**
  String get uploadImage;

  /// No description provided for @pngJpgWebp.
  ///
  /// In en, this message translates to:
  /// **'PNG, JPG, WebP, GIF or SVG. Big images are shrunk to 512 px automatically.'**
  String get pngJpgWebp;

  /// No description provided for @genericBadgesOnly.
  ///
  /// In en, this message translates to:
  /// **'Generic badges only. Upload a real network logo under \"My icons\".'**
  String get genericBadgesOnly;

  /// No description provided for @tv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get tv;

  /// No description provided for @useThisBadge.
  ///
  /// In en, this message translates to:
  /// **'Use this badge'**
  String get useThisBadge;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @shape.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get shape;

  /// No description provided for @callLettersUp.
  ///
  /// In en, this message translates to:
  /// **'Call letters (up to 5)'**
  String get callLettersUp;

  /// No description provided for @iconFor.
  ///
  /// In en, this message translates to:
  /// **'Icon for {name}'**
  String iconFor(Object name);

  /// No description provided for @couldntReadThat.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that picture. Try another one.'**
  String get couldntReadThat;

  /// No description provided for @myIcons.
  ///
  /// In en, this message translates to:
  /// **'My icons'**
  String get myIcons;

  /// No description provided for @showLogos.
  ///
  /// In en, this message translates to:
  /// **'Show logos'**
  String get showLogos;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @couldntMoveThe.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t move the setup'**
  String get couldntMoveThe;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @thisBacksUp.
  ///
  /// In en, this message translates to:
  /// **'This backs up your profiles, channels and settings now and opens them in {counterpartName}, which asks before restoring them. Nothing changes here.'**
  String thisBacksUp(Object counterpartName);

  /// No description provided for @sendYourSetup.
  ///
  /// In en, this message translates to:
  /// **'Send your setup to {counterpartName}?'**
  String sendYourSetup(Object counterpartName);

  /// No description provided for @parentalControls.
  ///
  /// In en, this message translates to:
  /// **'Parental controls'**
  String get parentalControls;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @bringMySetup.
  ///
  /// In en, this message translates to:
  /// **'Bring my setup here from {counterpartName}'**
  String bringMySetup(Object counterpartName);

  /// No description provided for @moveMySetup.
  ///
  /// In en, this message translates to:
  /// **'Move my setup to {counterpartName}'**
  String moveMySetup(Object counterpartName);

  /// No description provided for @uninstallingEitherOne.
  ///
  /// In en, this message translates to:
  /// **'Uninstalling either one before moving the setup you want to keep deletes that setup.'**
  String get uninstallingEitherOne;

  /// No description provided for @andAreSeparate.
  ///
  /// In en, this message translates to:
  /// **'{appName} and {counterpartName} are separate apps, each with its own profiles, channels and settings.'**
  String andAreSeparate(Object appName, Object counterpartName);

  /// No description provided for @thankYouFor.
  ///
  /// In en, this message translates to:
  /// **'Thank you for supporting Nightingale TV!'**
  String get thankYouFor;

  /// No description provided for @isAlsoOn.
  ///
  /// In en, this message translates to:
  /// **'{counterpartName} is also on this device'**
  String isAlsoOn(Object counterpartName);

  /// No description provided for @aboutThisInstall.
  ///
  /// In en, this message translates to:
  /// **'ABOUT THIS INSTALL'**
  String get aboutThisInstall;

  /// No description provided for @couldntOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {counterpartName}.'**
  String couldntOpen(Object counterpartName);

  /// No description provided for @nothingIsSet.
  ///
  /// In en, this message translates to:
  /// **'Nothing is set up here yet, so there\'s no setup to move.'**
  String get nothingIsSet;

  /// No description provided for @yourSetupIs.
  ///
  /// In en, this message translates to:
  /// **'Your setup is on its way to {counterpartName}'**
  String yourSetupIs(Object counterpartName);

  /// No description provided for @guide.
  ///
  /// In en, this message translates to:
  /// **'GUIDE'**
  String get guide;

  /// No description provided for @ofLabel.
  ///
  /// In en, this message translates to:
  /// **'{n} of {keysCount}'**
  String ofLabel(Object n, Object keysCount);

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @ofChosen.
  ///
  /// In en, this message translates to:
  /// **'{_checkedCount} of {total} chosen'**
  String ofChosen(Object _checkedCount, Object total);

  /// No description provided for @channelOrGroup.
  ///
  /// In en, this message translates to:
  /// **'Channel or group name'**
  String get channelOrGroup;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @moveOkCheck.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Check    ESC Back'**
  String get moveOkCheck;

  /// No description provided for @chooseChannels.
  ///
  /// In en, this message translates to:
  /// **'Choose channels: {name}'**
  String chooseChannels(Object name);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @readingThePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Reading the playlist…'**
  String get readingThePlaylist;

  /// No description provided for @nowThePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Now: the playlist\'s guide, {guideUrl}'**
  String nowThePlaylists(Object guideUrl);

  /// No description provided for @leaveEmptyTo.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the guide the playlist names'**
  String get leaveEmptyTo;

  /// No description provided for @xmltvGuideAddress.
  ///
  /// In en, this message translates to:
  /// **'XMLTV guide address'**
  String get xmltvGuideAddress;

  /// No description provided for @guideOptional.
  ///
  /// In en, this message translates to:
  /// **'GUIDE (OPTIONAL)'**
  String get guideOptional;

  /// No description provided for @httpProviderExample.
  ///
  /// In en, this message translates to:
  /// **'http://provider.example/get.php?username=…&type=m3u_plus'**
  String get httpProviderExample;

  /// No description provided for @playlistAddress.
  ///
  /// In en, this message translates to:
  /// **'Playlist address'**
  String get playlistAddress;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'PLAYLIST'**
  String get playlist;

  /// No description provided for @myIptv.
  ///
  /// In en, this message translates to:
  /// **'My IPTV'**
  String get myIptv;

  /// No description provided for @useAnAddress.
  ///
  /// In en, this message translates to:
  /// **'Use an address instead'**
  String get useAnAddress;

  /// No description provided for @chooseAFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get chooseAFile;

  /// No description provided for @chooseAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnotherFile;

  /// No description provided for @moveOkSelectEscBack.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Select    ESC Back'**
  String get moveOkSelectEscBack;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String edit(Object name);

  /// No description provided for @addAnM3u.
  ///
  /// In en, this message translates to:
  /// **'Add an M3U playlist'**
  String get addAnM3u;

  /// No description provided for @m3uPlaylists.
  ///
  /// In en, this message translates to:
  /// **'M3U playlists'**
  String get m3uPlaylists;

  /// No description provided for @xmltvGuides.
  ///
  /// In en, this message translates to:
  /// **'XMLTV guides'**
  String get xmltvGuides;

  /// No description provided for @anIptvPlaylist.
  ///
  /// In en, this message translates to:
  /// **'An IPTV playlist (a web address or a file), with an XMLTV guide if you have one.'**
  String get anIptvPlaylist;

  /// No description provided for @theChannelsAnd.
  ///
  /// In en, this message translates to:
  /// **'The channels and guide of your server\'s tuner (an antenna, cable box or IPTV it has).'**
  String get theChannelsAnd;

  /// No description provided for @readingSChannels.
  ///
  /// In en, this message translates to:
  /// **'Reading {server}\'s channels…'**
  String readingSChannels(Object server);

  /// No description provided for @checkingLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Checking {server} Live TV…'**
  String checkingLiveTv(Object server);

  /// No description provided for @addALive.
  ///
  /// In en, this message translates to:
  /// **'Add a Live TV source'**
  String get addALive;

  /// No description provided for @itsChannelsLeave.
  ///
  /// In en, this message translates to:
  /// **'Its channels leave the guide, their groups and favorites.'**
  String get itsChannelsLeave;

  /// No description provided for @renameSource.
  ///
  /// In en, this message translates to:
  /// **'Rename source'**
  String get renameSource;

  /// No description provided for @edit2.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit2;

  /// No description provided for @refreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get refreshNow;

  /// No description provided for @chooseChannels2.
  ///
  /// In en, this message translates to:
  /// **'Choose channels'**
  String get chooseChannels2;

  /// No description provided for @playlistFile.
  ///
  /// In en, this message translates to:
  /// **'Playlist file'**
  String get playlistFile;

  /// No description provided for @notRefreshedYet.
  ///
  /// In en, this message translates to:
  /// **'Not refreshed yet'**
  String get notRefreshedYet;

  /// No description provided for @refreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {lastRefresh}'**
  String refreshed(Object lastRefresh);

  /// No description provided for @lastRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Last refresh failed: {lastError}'**
  String lastRefreshFailed(Object lastError);

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get refreshing;

  /// No description provided for @ofChannels.
  ///
  /// In en, this message translates to:
  /// **'{label} · {keyCount} of {channelsCount} channels'**
  String ofChannels(Object label, Object keyCount, Object channelsCount);

  /// No description provided for @noSourcesYet.
  ///
  /// In en, this message translates to:
  /// **'No sources yet.'**
  String get noSourcesYet;

  /// No description provided for @addSource.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get addSource;

  /// No description provided for @realBroadcastsAnd.
  ///
  /// In en, this message translates to:
  /// **'Real broadcasts and IPTV in your guide: your server\'s Live TV, or an M3U playlist with an XMLTV guide. Their channels join the lineup after yours.'**
  String get realBroadcastsAnd;

  /// No description provided for @notStreamingOf.
  ///
  /// In en, this message translates to:
  /// **'Not streaming. {runningCount} of {streamLimit} streams in use.'**
  String notStreamingOf(Object runningCount, Object streamLimit);

  /// No description provided for @savePort.
  ///
  /// In en, this message translates to:
  /// **'Save port'**
  String get savePort;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @xmltv.
  ///
  /// In en, this message translates to:
  /// **'XMLTV'**
  String get xmltv;

  /// No description provided for @tuner.
  ///
  /// In en, this message translates to:
  /// **'Tuner'**
  String get tuner;

  /// No description provided for @enterAPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a port number.'**
  String get enterAPort;

  /// No description provided for @pinFor.
  ///
  /// In en, this message translates to:
  /// **'PIN for {name}'**
  String pinFor(Object name);

  /// No description provided for @letPlexFind.
  ///
  /// In en, this message translates to:
  /// **'Let Plex find it automatically'**
  String get letPlexFind;

  /// No description provided for @discovery.
  ///
  /// In en, this message translates to:
  /// **'DISCOVERY'**
  String get discovery;

  /// No description provided for @encoder.
  ///
  /// In en, this message translates to:
  /// **'ENCODER'**
  String get encoder;

  /// No description provided for @nowAtOnce.
  ///
  /// In en, this message translates to:
  /// **'Now: {streamLimit} at once. Each channel being watched elsewhere is one stream.'**
  String nowAtOnce(Object streamLimit);

  /// No description provided for @streamsAtOnce.
  ///
  /// In en, this message translates to:
  /// **'STREAMS AT ONCE'**
  String get streamsAtOnce;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'QUALITY'**
  String get quality;

  /// No description provided for @lineups.
  ///
  /// In en, this message translates to:
  /// **'LINEUPS'**
  String get lineups;

  /// No description provided for @liveTvExport2.
  ///
  /// In en, this message translates to:
  /// **'Live TV export'**
  String get liveTvExport2;

  /// No description provided for @automaticDiscoveryIsnt.
  ///
  /// In en, this message translates to:
  /// **'Automatic discovery isn\'t available on this PC. Add the tuner in Plex or Jellyfin by its address.'**
  String get automaticDiscoveryIsnt;

  /// No description provided for @anyoneOnYour.
  ///
  /// In en, this message translates to:
  /// **'Anyone on your home network can watch this lineup.'**
  String get anyoneOnYour;

  /// No description provided for @watchYourChannels.
  ///
  /// In en, this message translates to:
  /// **'Watch your channels in Plex, Jellyfin or any IPTV app on your home network. Nightingale TV has to stay open for them to play.'**
  String get watchYourChannels;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @chooseAServer.
  ///
  /// In en, this message translates to:
  /// **'Choose a server'**
  String get chooseAServer;

  /// No description provided for @whosSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Who\'s signing in?'**
  String get whosSigningIn;

  /// No description provided for @openPlexTv.
  ///
  /// In en, this message translates to:
  /// **'Open plex.tv/link'**
  String get openPlexTv;

  /// No description provided for @waitingForThe.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the code to be linked…'**
  String get waitingForThe;

  /// No description provided for @goToPlex.
  ///
  /// In en, this message translates to:
  /// **'Go to plex.tv/link on your phone or computer and enter this code.'**
  String get goToPlex;

  /// No description provided for @signInWith.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Plex'**
  String get signInWith;

  /// No description provided for @waitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval…'**
  String get waitingForApproval;

  /// No description provided for @onYourPhone.
  ///
  /// In en, this message translates to:
  /// **'On your phone or computer, open {label} → your profile → Quick Connect, and enter this code:'**
  String onYourPhone(Object label);

  /// No description provided for @quickConnect.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect'**
  String get quickConnect;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @signInTo2.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {name}'**
  String signInTo2(Object name);

  /// No description provided for @differentServer.
  ///
  /// In en, this message translates to:
  /// **'Different server'**
  String get differentServer;

  /// No description provided for @signInWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Sign in with password'**
  String get signInWithPassword;

  /// No description provided for @quickConnectUse.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect (use your phone)'**
  String get quickConnectUse;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @connectToYour.
  ///
  /// In en, this message translates to:
  /// **'Connect to your server'**
  String get connectToYour;

  /// No description provided for @nightingaleTvTurns.
  ///
  /// In en, this message translates to:
  /// **'Nightingale TV turns your Jellyfin, Emby or Plex library into always-on channels with a program guide. Flip around and catch whatever is on.'**
  String get nightingaleTvTurns;

  /// No description provided for @yourLibraryOn.
  ///
  /// In en, this message translates to:
  /// **'Your library.\nOn the air, 24/7.'**
  String get yourLibraryOn;

  /// No description provided for @welcomeToNightingale.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Nightingale TV'**
  String get welcomeToNightingale;

  /// No description provided for @signInFor.
  ///
  /// In en, this message translates to:
  /// **'Sign in for {name}'**
  String signInFor(Object name);

  /// No description provided for @signInToAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {name} again'**
  String signInToAgain(Object name);

  /// No description provided for @addAServer.
  ///
  /// In en, this message translates to:
  /// **'Add a server'**
  String get addAServer;

  /// No description provided for @foundNewPrograms.
  ///
  /// In en, this message translates to:
  /// **'Found {list}. New programs start airing on their channels right after what\'s on now.'**
  String foundNewPrograms(Object list);

  /// No description provided for @libraryRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Library refreshed'**
  String get libraryRefreshed;

  /// No description provided for @nothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new'**
  String get nothingNew;

  /// No description provided for @yourChannelsAre.
  ///
  /// In en, this message translates to:
  /// **'Your channels are up to date.'**
  String get yourChannelsAre;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed'**
  String get refreshFailed;

  /// No description provided for @moveOkSelectEscBackTo.
  ///
  /// In en, this message translates to:
  /// **'▲▼ Move    OK Select    ESC Back to TV'**
  String get moveOkSelectEscBackTo;

  /// No description provided for @noPoolsYet.
  ///
  /// In en, this message translates to:
  /// **'no pools yet'**
  String get noPoolsYet;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {fetchedAt} at {fetchedAt2}'**
  String updatedAt(Object fetchedAt, Object fetchedAt2);

  /// No description provided for @libraryLabel.
  ///
  /// In en, this message translates to:
  /// **'LIBRARY'**
  String get libraryLabel;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get account;

  /// No description provided for @watching.
  ///
  /// In en, this message translates to:
  /// **'WATCHING'**
  String get watching;

  /// No description provided for @exitNightingaleTv.
  ///
  /// In en, this message translates to:
  /// **'Exit Nightingale TV'**
  String get exitNightingaleTv;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @yourChannelLineup.
  ///
  /// In en, this message translates to:
  /// **'Your channel lineup is cleared. Custom icons are kept.'**
  String get yourChannelLineup;

  /// No description provided for @signOut2.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOut2;

  /// No description provided for @fullScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Full screen on/off (F11)'**
  String get fullScreenOn;

  /// No description provided for @nothingWasReset.
  ///
  /// In en, this message translates to:
  /// **'Nothing was reset'**
  String get nothingWasReset;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @rebuildsTheDefault.
  ///
  /// In en, this message translates to:
  /// **'Rebuilds the default channels from your library. Names, icons and numbers you changed are reset. Channels you added are kept. A backup is saved first, so you can bring them back in Backup & restore.'**
  String get rebuildsTheDefault;

  /// No description provided for @resetChannelLineup.
  ///
  /// In en, this message translates to:
  /// **'Reset channel lineup?'**
  String get resetChannelLineup;

  /// No description provided for @resetChannelLineup2.
  ///
  /// In en, this message translates to:
  /// **'Reset channel lineup'**
  String get resetChannelLineup2;

  /// No description provided for @refreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh library'**
  String get refreshLibrary;

  /// No description provided for @refreshingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refreshing library…'**
  String get refreshingLibrary;

  /// No description provided for @servers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get servers;

  /// No description provided for @phoneRemote.
  ///
  /// In en, this message translates to:
  /// **'Phone remote'**
  String get phoneRemote;

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @retroLook.
  ///
  /// In en, this message translates to:
  /// **'Retro look'**
  String get retroLook;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get switchProfile;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @backToTv.
  ///
  /// In en, this message translates to:
  /// **'Back to TV'**
  String get backToTv;

  /// No description provided for @removeAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get removeAll;

  /// No description provided for @pairedLastUsed.
  ///
  /// In en, this message translates to:
  /// **'paired {paired} · last used {lastUsed}'**
  String pairedLastUsed(Object paired, Object lastUsed);

  /// No description provided for @noPhonesPaired.
  ///
  /// In en, this message translates to:
  /// **'No phones paired yet.'**
  String get noPhonesPaired;

  /// No description provided for @pairedPhones.
  ///
  /// In en, this message translates to:
  /// **'PAIRED PHONES'**
  String get pairedPhones;

  /// No description provided for @blockedByThis.
  ///
  /// In en, this message translates to:
  /// **'Blocked by this computer\'s firewall'**
  String get blockedByThis;

  /// No description provided for @someWiFi.
  ///
  /// In en, this message translates to:
  /// **'Some Wi-Fi networks keep devices apart (called AP or client isolation). If the phone still can\'t connect, turn that setting off for your Wi-Fi.'**
  String get someWiFi;

  /// No description provided for @thePhoneHas.
  ///
  /// In en, this message translates to:
  /// **'The phone has to be on the same Wi-Fi as this TV, not a guest network or mobile data.'**
  String get thePhoneHas;

  /// No description provided for @ifThePhone.
  ///
  /// In en, this message translates to:
  /// **'If the phone can\'t connect, this computer\'s firewall may be blocking it. Open a terminal on this computer and run:'**
  String get ifThePhone;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @thenChooseCheck.
  ///
  /// In en, this message translates to:
  /// **'Then choose Check again.'**
  String get thenChooseCheck;

  /// No description provided for @thisComputersFirewall.
  ///
  /// In en, this message translates to:
  /// **'This computer\'s firewall stops phones from reaching the remote. To let them in, open a terminal on this computer and run:'**
  String get thisComputersFirewall;

  /// No description provided for @notConfirmedYet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet · no phone has connected'**
  String get notConfirmedYet;

  /// No description provided for @working.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get working;

  /// No description provided for @workingLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Working · last used by {name}, {lastUsed}'**
  String workingLastUsed(Object name, Object lastUsed);

  /// No description provided for @theRemoteIs.
  ///
  /// In en, this message translates to:
  /// **'The remote is off.'**
  String get theRemoteIs;

  /// No description provided for @orScanThe.
  ///
  /// In en, this message translates to:
  /// **'or scan the code with the phone\'s camera.'**
  String get orScanThe;

  /// No description provided for @andEnter.
  ///
  /// In en, this message translates to:
  /// **'and enter  '**
  String get andEnter;

  /// No description provided for @onYourPhoneOpen.
  ///
  /// In en, this message translates to:
  /// **'ON YOUR PHONE, OPEN'**
  String get onYourPhoneOpen;

  /// No description provided for @useYourPhoneAs.
  ///
  /// In en, this message translates to:
  /// **'Use your phone as the remote: open a web page on it to change channels, bring up the guide, or tap a channel to tune in. Nothing to install.'**
  String get useYourPhoneAs;

  /// No description provided for @everyPairedPhone.
  ///
  /// In en, this message translates to:
  /// **'Every paired phone stops working as a remote until it scans the code on this screen again.'**
  String get everyPairedPhone;

  /// No description provided for @removeAllPhones.
  ///
  /// In en, this message translates to:
  /// **'Remove all phones?'**
  String get removeAllPhones;

  /// No description provided for @thoseDidntMatch.
  ///
  /// In en, this message translates to:
  /// **'Those didn\'t match. Try again.'**
  String get thoseDidntMatch;

  /// No description provided for @enterTheSame.
  ///
  /// In en, this message translates to:
  /// **'Enter the same 4 digits again.'**
  String get enterTheSame;

  /// No description provided for @choose4Digits.
  ///
  /// In en, this message translates to:
  /// **'Choose 4 digits.'**
  String get choose4Digits;

  /// No description provided for @thatPinIsnt.
  ///
  /// In en, this message translates to:
  /// **'That PIN isn\'t right. Try again.'**
  String get thatPinIsnt;

  /// No description provided for @clock.
  ///
  /// In en, this message translates to:
  /// **'CLOCK'**
  String get clock;

  /// No description provided for @captions2.
  ///
  /// In en, this message translates to:
  /// **'CAPTIONS'**
  String get captions2;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'AUDIO'**
  String get audio;

  /// No description provided for @maximumStreamingBitrate.
  ///
  /// In en, this message translates to:
  /// **'MAXIMUM STREAMING BITRATE'**
  String get maximumStreamingBitrate;

  /// No description provided for @converting.
  ///
  /// In en, this message translates to:
  /// **'CONVERTING'**
  String get converting;

  /// No description provided for @afterThisLong.
  ///
  /// In en, this message translates to:
  /// **'After this long with no button pressed, Nightingale TV asks if anyone is watching. With no answer in a minute, it goes to sleep: playback stops and your server stops streaming. Not while a sleep timer is set.'**
  String get afterThisLong;

  /// No description provided for @askIfIm.
  ///
  /// In en, this message translates to:
  /// **'Ask if I\'m still watching'**
  String get askIfIm;

  /// No description provided for @liveTvStill.
  ///
  /// In en, this message translates to:
  /// **'Live TV still shows on the dashboard.'**
  String get liveTvStill;

  /// No description provided for @offWhatYou.
  ///
  /// In en, this message translates to:
  /// **'Off: what you watch here never changes play counts, watched marks or resume points on your server, and doesn\'t show on its dashboard.'**
  String get offWhatYou;

  /// No description provided for @pauseSkipAnd.
  ///
  /// In en, this message translates to:
  /// **'Pause, skip and restart what\'s on. Off: every channel stays on the clock, like always-on TV.'**
  String get pauseSkipAnd;

  /// No description provided for @pauseAndRewind.
  ///
  /// In en, this message translates to:
  /// **'Pause and rewind'**
  String get pauseAndRewind;

  /// No description provided for @showsTheTime.
  ///
  /// In en, this message translates to:
  /// **'Shows the time in the corner of the picture.'**
  String get showsTheTime;

  /// No description provided for @onScreenClock.
  ///
  /// In en, this message translates to:
  /// **'On-screen clock'**
  String get onScreenClock;

  /// No description provided for @showACountdown.
  ///
  /// In en, this message translates to:
  /// **'Show a countdown before commercials start and before the program comes back.'**
  String get showACountdown;

  /// No description provided for @breakNotices.
  ///
  /// In en, this message translates to:
  /// **'Break notices'**
  String get breakNotices;

  /// No description provided for @theSizeOf.
  ///
  /// In en, this message translates to:
  /// **'The size of captions on every program and channel.'**
  String get theSizeOf;

  /// No description provided for @whileItsOn.
  ///
  /// In en, this message translates to:
  /// **'While it\'s on, surround audio (Dolby, DTS) is decoded by this device instead of being passed through to a receiver.'**
  String get whileItsOn;

  /// No description provided for @evensOutThe.
  ///
  /// In en, this message translates to:
  /// **'Evens out the volume as you watch: loud commercials and programs are turned down and quiet ones turned up, so you don\'t have to reach for the remote.'**
  String get evensOutThe;

  /// No description provided for @volumeLeveling.
  ///
  /// In en, this message translates to:
  /// **'Volume leveling'**
  String get volumeLeveling;

  /// No description provided for @pickALower.
  ///
  /// In en, this message translates to:
  /// **'Pick a lower bitrate if shows buffer or stutter over Wi-Fi or a remote connection. Original never converts because of bitrate.'**
  String get pickALower;

  /// No description provided for @connectedThroughPlex.
  ///
  /// In en, this message translates to:
  /// **'Connected through Plex Relay; quality is limited.'**
  String get connectedThroughPlex;

  /// No description provided for @offNightingaleTv.
  ///
  /// In en, this message translates to:
  /// **'Off: Nightingale TV always plays your original files at full quality, and your server does no extra work. On: your server converts a show or movie only when it\'s above the maximum bitrate, or when the original file won\'t play. Converting uses your server\'s processor or graphics card. Commercials always play the original files.'**
  String get offNightingaleTv;

  /// No description provided for @transcodeOnlyIf.
  ///
  /// In en, this message translates to:
  /// **'Transcode only if needed (experimental)'**
  String get transcodeOnlyIf;

  /// No description provided for @longerVideosAd.
  ///
  /// In en, this message translates to:
  /// **'Longer videos (ad compilations) are split into their ads, at chapters or where the picture goes black and silent.'**
  String get longerVideosAd;

  /// No description provided for @videosOf5.
  ///
  /// In en, this message translates to:
  /// **'Videos of 5 seconds to 3 minutes are one clip each.'**
  String get videosOf5;

  /// No description provided for @commercialsFillBreaks.
  ///
  /// In en, this message translates to:
  /// **'Commercials fill breaks. Set the type to Bumpers for station idents and \"we\'ll be right back\" clips.'**
  String get commercialsFillBreaks;

  /// No description provided for @bumpersTakeAt.
  ///
  /// In en, this message translates to:
  /// **'Bumpers take at most half of a break, except in a pre-roll. One too long for that is skipped.'**
  String get bumpersTakeAt;

  /// No description provided for @stillToSplit.
  ///
  /// In en, this message translates to:
  /// **'{unsplit} still to split'**
  String stillToSplit(Object unsplit);

  /// No description provided for @longOnesSplit.
  ///
  /// In en, this message translates to:
  /// **'{reelsCount, plural, =1{{reelsCount} long one split into clips} other{{reelsCount} long ones split into clips}}'**
  String longOnesSplit(int reelsCount);

  /// No description provided for @deletePool.
  ///
  /// In en, this message translates to:
  /// **'Delete pool'**
  String get deletePool;

  /// No description provided for @addFolders.
  ///
  /// In en, this message translates to:
  /// **'Add folders…'**
  String get addFolders;

  /// No description provided for @libraryLabel2.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryLabel2;

  /// No description provided for @noFoldersYet.
  ///
  /// In en, this message translates to:
  /// **'No folders yet.'**
  String get noFoldersYet;

  /// No description provided for @folders2.
  ///
  /// In en, this message translates to:
  /// **'FOLDERS'**
  String get folders2;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get type;

  /// No description provided for @poolName.
  ///
  /// In en, this message translates to:
  /// **'Pool name'**
  String get poolName;

  /// No description provided for @commercialPool.
  ///
  /// In en, this message translates to:
  /// **'Commercial pool'**
  String get commercialPool;

  /// No description provided for @itsVideosGo.
  ///
  /// In en, this message translates to:
  /// **'Its videos go back to your regular channels. Breaks that drew from it use all pools instead.'**
  String get itsVideosGo;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @tuning2.
  ///
  /// In en, this message translates to:
  /// **'Tuning…'**
  String get tuning2;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// No description provided for @noChannels.
  ///
  /// In en, this message translates to:
  /// **'No channels'**
  String get noChannels;

  /// No description provided for @theirChannelsProgramming.
  ///
  /// In en, this message translates to:
  /// **'Their channels, programming blocks and settings are deleted, and this TV is signed out of their server.'**
  String get theirChannelsProgramming;

  /// No description provided for @delete3.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String delete3(Object name);

  /// No description provided for @giveTheProfile.
  ///
  /// In en, this message translates to:
  /// **'Give the profile a name.'**
  String get giveTheProfile;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @removePin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get removePin;

  /// No description provided for @setAPin.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get setAPin;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @noPinAnyone.
  ///
  /// In en, this message translates to:
  /// **'No PIN. Anyone can open this profile.'**
  String get noPinAnyone;

  /// No description provided for @lockedThePin.
  ///
  /// In en, this message translates to:
  /// **'Locked. The PIN is needed to open this profile.'**
  String get lockedThePin;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @showsAndMoviesWith.
  ///
  /// In en, this message translates to:
  /// **'Shows and movies with no rating are left out.'**
  String get showsAndMoviesWith;

  /// No description provided for @allowedToWatch.
  ///
  /// In en, this message translates to:
  /// **'ALLOWED TO WATCH'**
  String get allowedToWatch;

  /// No description provided for @kid.
  ///
  /// In en, this message translates to:
  /// **'Kid'**
  String get kid;

  /// No description provided for @grownUp.
  ///
  /// In en, this message translates to:
  /// **'Grown-up'**
  String get grownUp;

  /// No description provided for @whoItsFor.
  ///
  /// In en, this message translates to:
  /// **'WHO IT\'S FOR'**
  String get whoItsFor;

  /// No description provided for @color2.
  ///
  /// In en, this message translates to:
  /// **'COLOR'**
  String get color2;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @newProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// No description provided for @watchingNow.
  ///
  /// In en, this message translates to:
  /// **'Watching now'**
  String get watchingNow;

  /// No description provided for @noPin.
  ///
  /// In en, this message translates to:
  /// **'No PIN'**
  String get noPin;

  /// No description provided for @pinLocked.
  ///
  /// In en, this message translates to:
  /// **'PIN locked'**
  String get pinLocked;

  /// No description provided for @kid2.
  ///
  /// In en, this message translates to:
  /// **'Kid · {label} ({description})'**
  String kid2(Object label, Object description);

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addProfile;

  /// No description provided for @everyoneGetsTheir.
  ///
  /// In en, this message translates to:
  /// **'Everyone gets their own server sign-in, channels and programming blocks. Kid profiles only see shows and movies rated for their age.'**
  String get everyoneGetsTheir;

  /// No description provided for @enterSPin.
  ///
  /// In en, this message translates to:
  /// **'Enter {name}\'s PIN'**
  String enterSPin(Object name);

  /// No description provided for @whosWatching.
  ///
  /// In en, this message translates to:
  /// **'Who\'s watching?'**
  String get whosWatching;

  /// No description provided for @moveOkChoose2.
  ///
  /// In en, this message translates to:
  /// **'◀▶ Move    OK Choose'**
  String get moveOkChoose2;

  /// No description provided for @enterAGrownUps.
  ///
  /// In en, this message translates to:
  /// **'Enter a grown-up\'s PIN.'**
  String get enterAGrownUps;

  /// No description provided for @grownUpsOnly.
  ///
  /// In en, this message translates to:
  /// **'Grown-ups only'**
  String get grownUpsOnly;

  /// No description provided for @yourChannelYour.
  ///
  /// In en, this message translates to:
  /// **'Your channel, your look'**
  String get yourChannelYour;

  /// No description provided for @testPattern.
  ///
  /// In en, this message translates to:
  /// **'Test Pattern'**
  String get testPattern;

  /// No description provided for @upNext8.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT  ·  8:00 PM'**
  String get upNext8;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'THIS DEVICE'**
  String get thisDevice;

  /// No description provided for @glow.
  ///
  /// In en, this message translates to:
  /// **'GLOW'**
  String get glow;

  /// No description provided for @curvature.
  ///
  /// In en, this message translates to:
  /// **'CURVATURE'**
  String get curvature;

  /// No description provided for @vignette.
  ///
  /// In en, this message translates to:
  /// **'VIGNETTE'**
  String get vignette;

  /// No description provided for @mask.
  ///
  /// In en, this message translates to:
  /// **'MASK'**
  String get mask;

  /// No description provided for @lines.
  ///
  /// In en, this message translates to:
  /// **'LINES'**
  String get lines;

  /// No description provided for @scanlines.
  ///
  /// In en, this message translates to:
  /// **'SCANLINES'**
  String get scanlines;

  /// No description provided for @customCrtStyle.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM CRT STYLE'**
  String get customCrtStyle;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'ACCENT ({label})'**
  String accent(Object label);

  /// No description provided for @overlayTheme.
  ///
  /// In en, this message translates to:
  /// **'OVERLAY THEME'**
  String get overlayTheme;

  /// No description provided for @crtEffect.
  ///
  /// In en, this message translates to:
  /// **'CRT EFFECT'**
  String get crtEffect;

  /// No description provided for @surround.
  ///
  /// In en, this message translates to:
  /// **'SURROUND'**
  String get surround;

  /// No description provided for @pictureShape.
  ///
  /// In en, this message translates to:
  /// **'PICTURE SHAPE'**
  String get pictureShape;

  /// No description provided for @surroundImage.
  ///
  /// In en, this message translates to:
  /// **'Surround image'**
  String get surroundImage;

  /// No description provided for @notAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get notAvailableOn;

  /// No description provided for @offTurnsOff.
  ///
  /// In en, this message translates to:
  /// **'Off turns off all CRT effects on this device only. Picture shape, surround and overlay themes stay as they are.'**
  String get offTurnsOff;

  /// No description provided for @effectsOnThis.
  ///
  /// In en, this message translates to:
  /// **'Effects on this device'**
  String get effectsOnThis;

  /// No description provided for @retroLook2.
  ///
  /// In en, this message translates to:
  /// **'RETRO LOOK'**
  String get retroLook2;

  /// No description provided for @theseSettingsApply.
  ///
  /// In en, this message translates to:
  /// **'These settings apply on screens running the app. They don\'t apply to Live TV export.'**
  String get theseSettingsApply;

  /// No description provided for @sameAsThe.
  ///
  /// In en, this message translates to:
  /// **'Same as the profile'**
  String get sameAsThe;

  /// No description provided for @streamsFromThis.
  ///
  /// In en, this message translates to:
  /// **'Streams from this server stay under this. The profile\'s own limit (Playback) still applies; the lower one wins.'**
  String get streamsFromThis;

  /// No description provided for @qualityLimit.
  ///
  /// In en, this message translates to:
  /// **'Quality limit · {name}'**
  String qualityLimit(Object name);

  /// No description provided for @mbps.
  ///
  /// In en, this message translates to:
  /// **'{toStringAsFixed} Mbps'**
  String mbps(Object toStringAsFixed);

  /// No description provided for @itsProgramsLeave.
  ///
  /// In en, this message translates to:
  /// **'Its programs leave your channels, which keep their numbers. Sources and commercial folders on it show as not found until you change them.'**
  String get itsProgramsLeave;

  /// No description provided for @remove3.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String remove3(Object name);

  /// No description provided for @signingOutOf.
  ///
  /// In en, this message translates to:
  /// **'Signing out of this profile changes its main server.'**
  String get signingOutOf;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {user}'**
  String signedInAs(Object user);

  /// No description provided for @mainServer.
  ///
  /// In en, this message translates to:
  /// **'Main server'**
  String get mainServer;

  /// No description provided for @qualityLimit2.
  ///
  /// In en, this message translates to:
  /// **'Quality limit'**
  String get qualityLimit2;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @programsFromEvery.
  ///
  /// In en, this message translates to:
  /// **'Programs from every server join one lineup. A title on several servers plays from the first one in this list that answers (Play from); if it stops answering, the next one takes over.'**
  String get programsFromEvery;

  /// No description provided for @sleepingPressAny.
  ///
  /// In en, this message translates to:
  /// **'Sleeping · Press any button to watch'**
  String get sleepingPressAny;

  /// No description provided for @goingToSleep.
  ///
  /// In en, this message translates to:
  /// **'Going to sleep in {seconds}'**
  String goingToSleep(Object seconds);

  /// No description provided for @goingToSleep2.
  ///
  /// In en, this message translates to:
  /// **'Going to sleep'**
  String get goingToSleep2;

  /// No description provided for @goingToSleepIn.
  ///
  /// In en, this message translates to:
  /// **'Going to sleep in 1 minute. {hint}'**
  String goingToSleepIn(Object hint);

  /// No description provided for @pressAnyButton.
  ///
  /// In en, this message translates to:
  /// **'Press any button to keep watching'**
  String get pressAnyButton;

  /// No description provided for @goingToSleepIn0.
  ///
  /// In en, this message translates to:
  /// **'Going to sleep in 0:{padLeft}'**
  String goingToSleepIn0(Object padLeft);

  /// No description provided for @keepWatching.
  ///
  /// In en, this message translates to:
  /// **'Keep watching'**
  String get keepWatching;

  /// No description provided for @areYouStill.
  ///
  /// In en, this message translates to:
  /// **'Are you still watching?'**
  String get areYouStill;

  /// No description provided for @sleepTimerMin.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer · {left} min left'**
  String sleepTimerMin(Object left);

  /// No description provided for @whatsOnNow.
  ///
  /// In en, this message translates to:
  /// **'What\'s on now has no set end time.'**
  String get whatsOnNow;

  /// No description provided for @endOfThis.
  ///
  /// In en, this message translates to:
  /// **'End of this program · {programEnd}'**
  String endOfThis(Object programEnd);

  /// No description provided for @endOfThisProgram.
  ///
  /// In en, this message translates to:
  /// **'End of this program'**
  String get endOfThisProgram;

  /// No description provided for @moveOkToggle.
  ///
  /// In en, this message translates to:
  /// **'▲▼◀▶ Move    OK Toggle    ESC Cancel'**
  String get moveOkToggle;

  /// No description provided for @usedWhenNo.
  ///
  /// In en, this message translates to:
  /// **'Used when no shows are picked. Also narrows down movies.'**
  String get usedWhenNo;

  /// No description provided for @genres2.
  ///
  /// In en, this message translates to:
  /// **'GENRES'**
  String get genres2;

  /// No description provided for @includeMovies.
  ///
  /// In en, this message translates to:
  /// **'Include movies'**
  String get includeMovies;

  /// No description provided for @add2.
  ///
  /// In en, this message translates to:
  /// **'Add…'**
  String get add2;

  /// No description provided for @notFoundOn.
  ///
  /// In en, this message translates to:
  /// **'Not found on the server'**
  String get notFoundOn;

  /// No description provided for @collectionsFolders.
  ///
  /// In en, this message translates to:
  /// **'COLLECTIONS & FOLDERS'**
  String get collectionsFolders;

  /// No description provided for @playOrder.
  ///
  /// In en, this message translates to:
  /// **'PLAY ORDER'**
  String get playOrder;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @shows2.
  ///
  /// In en, this message translates to:
  /// **'SHOWS'**
  String get shows2;

  /// No description provided for @pickSomethingTo.
  ///
  /// In en, this message translates to:
  /// **'Pick something to play.'**
  String get pickSomethingTo;

  /// No description provided for @everyMovie.
  ///
  /// In en, this message translates to:
  /// **'every {genreText} movie'**
  String everyMovie(Object genreText);

  /// No description provided for @everyMovie2.
  ///
  /// In en, this message translates to:
  /// **'every movie'**
  String get everyMovie2;

  /// No description provided for @everyShow.
  ///
  /// In en, this message translates to:
  /// **'every {genreText} show'**
  String everyShow(Object genreText);

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'{genresCount} or {last}'**
  String or(Object genresCount, Object last);

  /// No description provided for @settingUpYour.
  ///
  /// In en, this message translates to:
  /// **'Setting up your channels'**
  String get settingUpYour;

  /// No description provided for @couldntLoadYour.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your library'**
  String get couldntLoadYour;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next: {title}'**
  String upNext(Object title);

  /// No description provided for @backTo.
  ///
  /// In en, this message translates to:
  /// **'Back to {title}'**
  String backTo(Object title);

  /// No description provided for @programmingResumesIn.
  ///
  /// In en, this message translates to:
  /// **'Programming resumes in {left}'**
  String programmingResumesIn(Object left);

  /// No description provided for @inLabel.
  ///
  /// In en, this message translates to:
  /// **'{commercialBreakLabel} in {left}'**
  String inLabel(Object commercialBreakLabel, Object left);

  /// No description provided for @startingWith.
  ///
  /// In en, this message translates to:
  /// **'Starting with {title}'**
  String startingWith(Object title);

  /// No description provided for @upNext2.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT  ·  {start}'**
  String upNext2(Object start);

  /// No description provided for @next2.
  ///
  /// In en, this message translates to:
  /// **'Next {start}: {title}'**
  String next2(Object start, Object title);

  /// No description provided for @backOn.
  ///
  /// In en, this message translates to:
  /// **'Back on {backOnAir}'**
  String backOn(Object backOnAir);

  /// No description provided for @offTheAir2.
  ///
  /// In en, this message translates to:
  /// **'Off the air'**
  String get offTheAir2;

  /// No description provided for @commercialBreak.
  ///
  /// In en, this message translates to:
  /// **'Commercial break'**
  String get commercialBreak;

  /// No description provided for @tryingAgainAt.
  ///
  /// In en, this message translates to:
  /// **'Trying again at {end}'**
  String tryingAgainAt(Object end);

  /// No description provided for @exitFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get exitFullScreen;

  /// No description provided for @guide2.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guide2;

  /// No description provided for @thereIsNo.
  ///
  /// In en, this message translates to:
  /// **'There is no channel {number}'**
  String thereIsNo(Object number);

  /// No description provided for @liveChannelsCant.
  ///
  /// In en, this message translates to:
  /// **'Live channels can\'t be paused'**
  String get liveChannelsCant;

  /// No description provided for @curvatureAndGlow.
  ///
  /// In en, this message translates to:
  /// **'Curvature and glow are off: this device can\'t keep up'**
  String get curvatureAndGlow;

  /// No description provided for @pressBackAgain.
  ///
  /// In en, this message translates to:
  /// **'Press Back again to exit'**
  String get pressBackAgain;

  /// No description provided for @backAt.
  ///
  /// In en, this message translates to:
  /// **'Back at {backAt}'**
  String backAt(Object backAt);

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newLabel;

  /// No description provided for @nowPlayingOn.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING ON {name}'**
  String nowPlayingOn(Object name);

  /// No description provided for @ch.
  ///
  /// In en, this message translates to:
  /// **'CH {padLeft}'**
  String ch(Object padLeft);

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get paused;

  /// No description provided for @seekBar.
  ///
  /// In en, this message translates to:
  /// **'Seek bar'**
  String get seekBar;

  /// No description provided for @live2.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live2;

  /// No description provided for @forward30.
  ///
  /// In en, this message translates to:
  /// **'Forward 30'**
  String get forward30;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @back10.
  ///
  /// In en, this message translates to:
  /// **'Back 10'**
  String get back10;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @somethingWentWrong2.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({status}).'**
  String somethingWentWrong2(Object status);

  /// No description provided for @thatIsTooBig.
  ///
  /// In en, this message translates to:
  /// **'That is too big.'**
  String get thatIsTooBig;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get notFound;

  /// No description provided for @youCantDo.
  ///
  /// In en, this message translates to:
  /// **'You can\'t do that.'**
  String get youCantDo;

  /// No description provided for @cantReachThe.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check that it\'s running.'**
  String get cantReachThe;

  /// No description provided for @signOut3.
  ///
  /// In en, this message translates to:
  /// **'Sign out {userName}'**
  String signOut3(Object userName);

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @backups2.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backups2;

  /// No description provided for @serverAndSign.
  ///
  /// In en, this message translates to:
  /// **'Server and sign-in'**
  String get serverAndSign;

  /// No description provided for @channels5.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels5;

  /// No description provided for @thatProfileIsntYours.
  ///
  /// In en, this message translates to:
  /// **'That profile isn\'t yours, or it\'s gone.'**
  String get thatProfileIsntYours;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @itReplacesThe.
  ///
  /// In en, this message translates to:
  /// **'It replaces the profiles, channels and settings here.'**
  String get itReplacesThe;

  /// No description provided for @restoreThisBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get restoreThisBackup;

  /// No description provided for @backupActions.
  ///
  /// In en, this message translates to:
  /// **'Backup actions'**
  String get backupActions;

  /// No description provided for @channels6.
  ///
  /// In en, this message translates to:
  /// **'{profiles} · {channels} channels · {device}'**
  String channels6(Object profiles, Object channels, Object device);

  /// No description provided for @noneYetOne.
  ///
  /// In en, this message translates to:
  /// **'None yet. One is saved each day the household changes.'**
  String get noneYetOne;

  /// No description provided for @savedOnThe.
  ///
  /// In en, this message translates to:
  /// **'Saved on the server'**
  String get savedOnThe;

  /// No description provided for @restoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get restoring;

  /// No description provided for @restoreFromAFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file…'**
  String get restoreFromAFile;

  /// No description provided for @downloadABackup.
  ///
  /// In en, this message translates to:
  /// **'Download a backup now'**
  String get downloadABackup;

  /// No description provided for @aBackupHoldsThe.
  ///
  /// In en, this message translates to:
  /// **'A backup holds the profiles, channels, blocks, logos, export settings and user accounts (never passwords or sign-in tokens).'**
  String get aBackupHoldsThe;

  /// No description provided for @restoredTheBackup2.
  ///
  /// In en, this message translates to:
  /// **'Restored the backup.'**
  String get restoredTheBackup2;

  /// No description provided for @fromItReplaces.
  ///
  /// In en, this message translates to:
  /// **'From {whenValue} ({device}): {profiles}. It replaces the profiles, channels and settings here.'**
  String fromItReplaces(Object whenValue, Object device, Object profiles);

  /// No description provided for @nextAiring2.
  ///
  /// In en, this message translates to:
  /// **'Next airing: {start} {end}'**
  String nextAiring2(Object start, Object end);

  /// No description provided for @programsInIts.
  ///
  /// In en, this message translates to:
  /// **'{total} programs in its playlist.'**
  String programsInIts(Object total);

  /// No description provided for @workingOutWhat.
  ///
  /// In en, this message translates to:
  /// **'Working out what it plays…'**
  String get workingOutWhat;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @eachAiringPlays.
  ///
  /// In en, this message translates to:
  /// **'Each airing plays every spot\'s next episodes in order, then starts over if time is left.'**
  String get eachAiringPlays;

  /// No description provided for @aLineupOf.
  ///
  /// In en, this message translates to:
  /// **'A lineup of shows'**
  String get aLineupOf;

  /// No description provided for @whatItPlays2.
  ///
  /// In en, this message translates to:
  /// **'What it plays'**
  String get whatItPlays2;

  /// No description provided for @onlyPartOf.
  ///
  /// In en, this message translates to:
  /// **'Only part of the year'**
  String get onlyPartOf;

  /// No description provided for @runsPastMidnight.
  ///
  /// In en, this message translates to:
  /// **'Runs past midnight into the next day.'**
  String get runsPastMidnight;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get whenLabel;

  /// No description provided for @aNewChannelFor.
  ///
  /// In en, this message translates to:
  /// **'A new channel for this block'**
  String get aNewChannelFor;

  /// No description provided for @channel3.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel3;

  /// No description provided for @blocks.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get blocks;

  /// No description provided for @newBlock.
  ///
  /// In en, this message translates to:
  /// **'New block'**
  String get newBlock;

  /// No description provided for @programmingBlock.
  ///
  /// In en, this message translates to:
  /// **'Programming block'**
  String get programmingBlock;

  /// No description provided for @aBlockTakes.
  ///
  /// In en, this message translates to:
  /// **'A block takes over a channel at set times: \"Saturday Morning Cartoons\", Saturdays 7 AM to noon.'**
  String get aBlockTakes;

  /// No description provided for @overlayTheme2.
  ///
  /// In en, this message translates to:
  /// **'Overlay theme'**
  String get overlayTheme2;

  /// No description provided for @crtEffect2.
  ///
  /// In en, this message translates to:
  /// **'CRT effect'**
  String get crtEffect2;

  /// No description provided for @chooseSurroundImage.
  ///
  /// In en, this message translates to:
  /// **'Choose surround image…'**
  String get chooseSurroundImage;

  /// No description provided for @surround2.
  ///
  /// In en, this message translates to:
  /// **'Surround'**
  String get surround2;

  /// No description provided for @pictureShape2.
  ///
  /// In en, this message translates to:
  /// **'Picture shape'**
  String get pictureShape2;

  /// No description provided for @chooseOfflineImage.
  ///
  /// In en, this message translates to:
  /// **'Choose offline image…'**
  String get chooseOfflineImage;

  /// No description provided for @fillerPool2.
  ///
  /// In en, this message translates to:
  /// **'Filler pool'**
  String get fillerPool2;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{inMinutes} minutes'**
  String minutes(Object inMinutes);

  /// No description provided for @slotLength2.
  ///
  /// In en, this message translates to:
  /// **'Slot length'**
  String get slotLength2;

  /// No description provided for @everyProgramStarts.
  ///
  /// In en, this message translates to:
  /// **'Every program starts on the clock. The tail fills the rest of each slot.'**
  String get everyProgramStarts;

  /// No description provided for @itLeavesThe.
  ///
  /// In en, this message translates to:
  /// **'It leaves the lineup.'**
  String get itLeavesThe;

  /// No description provided for @itsProgrammingBlocks.
  ///
  /// In en, this message translates to:
  /// **'Its programming blocks are removed too.'**
  String get itsProgrammingBlocks;

  /// No description provided for @removeThisChannel.
  ///
  /// In en, this message translates to:
  /// **'Remove this channel'**
  String get removeThisChannel;

  /// No description provided for @channelLogo2.
  ///
  /// In en, this message translates to:
  /// **'Channel logo'**
  String get channelLogo2;

  /// No description provided for @editCustomBreaks.
  ///
  /// In en, this message translates to:
  /// **'Edit custom breaks…'**
  String get editCustomBreaks;

  /// No description provided for @musicChannelsOnlyShuffle.
  ///
  /// In en, this message translates to:
  /// **'Music channels only shuffle, never the same artist twice in a row.'**
  String get musicChannelsOnlyShuffle;

  /// No description provided for @playOrder2.
  ///
  /// In en, this message translates to:
  /// **'Play order'**
  String get playOrder2;

  /// No description provided for @saveWhatIt.
  ///
  /// In en, this message translates to:
  /// **'Save what it plays'**
  String get saveWhatIt;

  /// No description provided for @canBeA.
  ///
  /// In en, this message translates to:
  /// **'Can be a show\'s home channel for its newest episodes.'**
  String get canBeA;

  /// No description provided for @hiddenFromThe.
  ///
  /// In en, this message translates to:
  /// **'Hidden from the guide'**
  String get hiddenFromThe;

  /// No description provided for @chooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose icon…'**
  String get chooseIcon;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @saveNameAnd.
  ///
  /// In en, this message translates to:
  /// **'Save name and number'**
  String get saveNameAnd;

  /// No description provided for @aChannelAlready.
  ///
  /// In en, this message translates to:
  /// **'A channel already on that number swaps into this one\'s place.'**
  String get aChannelAlready;

  /// No description provided for @number3.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get number3;

  /// No description provided for @nameAndNumber.
  ///
  /// In en, this message translates to:
  /// **'Name and number'**
  String get nameAndNumber;

  /// No description provided for @decadesNoneAny.
  ///
  /// In en, this message translates to:
  /// **'Decades (none: any)'**
  String get decadesNoneAny;

  /// No description provided for @genresNoneAny.
  ///
  /// In en, this message translates to:
  /// **'Genres (none: any)'**
  String get genresNoneAny;

  /// No description provided for @musicVideos.
  ///
  /// In en, this message translates to:
  /// **'Music videos ({musicVideos})'**
  String musicVideos(Object musicVideos);

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs ({songs})'**
  String songs(Object songs);

  /// No description provided for @newMusicChannel.
  ///
  /// In en, this message translates to:
  /// **'New music channel'**
  String get newMusicChannel;

  /// No description provided for @aNightlySlot.
  ///
  /// In en, this message translates to:
  /// **'A nightly slot for shows\' newest episodes, on each show\'s home channel.'**
  String get aNightlySlot;

  /// No description provided for @mainSettings.
  ///
  /// In en, this message translates to:
  /// **'Main settings'**
  String get mainSettings;

  /// No description provided for @glow2.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get glow2;

  /// No description provided for @curvature2.
  ///
  /// In en, this message translates to:
  /// **'Curvature'**
  String get curvature2;

  /// No description provided for @vignette2.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get vignette2;

  /// No description provided for @mask2.
  ///
  /// In en, this message translates to:
  /// **'Mask'**
  String get mask2;

  /// No description provided for @lines2.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get lines2;

  /// No description provided for @scanlines2.
  ///
  /// In en, this message translates to:
  /// **'Scanlines'**
  String get scanlines2;

  /// No description provided for @customCrtStyle2.
  ///
  /// In en, this message translates to:
  /// **'Custom CRT style'**
  String get customCrtStyle2;

  /// No description provided for @accent2.
  ///
  /// In en, this message translates to:
  /// **'Accent ({label})'**
  String accent2(Object label);

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @blockChannel2.
  ///
  /// In en, this message translates to:
  /// **'Block channel'**
  String get blockChannel2;

  /// No description provided for @live3.
  ///
  /// In en, this message translates to:
  /// **'Live · {source}'**
  String live3(Object source);

  /// No description provided for @ofChannels2.
  ///
  /// In en, this message translates to:
  /// **'{shownCount} of {channelsCount} channels'**
  String ofChannels2(Object shownCount, Object channelsCount);

  /// No description provided for @searchChannels.
  ///
  /// In en, this message translates to:
  /// **'Search channels'**
  String get searchChannels;

  /// No description provided for @resetLineup.
  ///
  /// In en, this message translates to:
  /// **'Reset lineup'**
  String get resetLineup;

  /// No description provided for @everyChannelEdit.
  ///
  /// In en, this message translates to:
  /// **'Every channel edit is discarded and the default lineup is made again. Channels you added are kept. A backup is saved first.'**
  String get everyChannelEdit;

  /// No description provided for @musicChannel.
  ///
  /// In en, this message translates to:
  /// **'Music channel'**
  String get musicChannel;

  /// No description provided for @newBlockChannel.
  ///
  /// In en, this message translates to:
  /// **'New block channel'**
  String get newBlockChannel;

  /// No description provided for @channelsOwnPlans.
  ///
  /// In en, this message translates to:
  /// **'Channels\' own plans'**
  String get channelsOwnPlans;

  /// No description provided for @setTypeBumpers.
  ///
  /// In en, this message translates to:
  /// **'Set type: Bumpers'**
  String get setTypeBumpers;

  /// No description provided for @setTypeCommercials.
  ///
  /// In en, this message translates to:
  /// **'Set type: Commercials'**
  String get setTypeCommercials;

  /// No description provided for @chooseFolders2.
  ///
  /// In en, this message translates to:
  /// **'Choose folders…'**
  String get chooseFolders2;

  /// No description provided for @plansThatDrew.
  ///
  /// In en, this message translates to:
  /// **'Plans that drew from it use all pools instead, and its videos rejoin the channels.'**
  String get plansThatDrew;

  /// No description provided for @renamePool.
  ///
  /// In en, this message translates to:
  /// **'Rename pool'**
  String get renamePool;

  /// No description provided for @poolActions.
  ///
  /// In en, this message translates to:
  /// **'Pool actions'**
  String get poolActions;

  /// No description provided for @aPoolIs.
  ///
  /// In en, this message translates to:
  /// **'A pool is a set of library folders whose videos fill breaks instead of airing. A pool\'s type says whether its clips play as commercials or as bumpers, which open and close breaks.'**
  String get aPoolIs;

  /// No description provided for @pools2.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get pools2;

  /// No description provided for @breaks.
  ///
  /// In en, this message translates to:
  /// **'Breaks'**
  String get breaks;

  /// No description provided for @clipsInAll.
  ///
  /// In en, this message translates to:
  /// **'{clips} clips in all commercial pools.'**
  String clipsInAll(Object clips);

  /// No description provided for @tunerAddress.
  ///
  /// In en, this message translates to:
  /// **'Tuner address'**
  String get tunerAddress;

  /// No description provided for @changePort.
  ///
  /// In en, this message translates to:
  /// **'Change port'**
  String get changePort;

  /// No description provided for @exportThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Export this profile'**
  String get exportThisProfile;

  /// No description provided for @letsPlexAnd.
  ///
  /// In en, this message translates to:
  /// **'Lets Plex and others find the tuners on the network.'**
  String get letsPlexAnd;

  /// No description provided for @discovery2.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get discovery2;

  /// No description provided for @encoder2.
  ///
  /// In en, this message translates to:
  /// **'Encoder'**
  String get encoder2;

  /// No description provided for @automaticOnThis.
  ///
  /// In en, this message translates to:
  /// **'Automatic: {streamLimitInUse} on this machine.'**
  String automaticOnThis(Object streamLimitInUse);

  /// No description provided for @streamsAtOnce2.
  ///
  /// In en, this message translates to:
  /// **'Streams at once'**
  String get streamsAtOnce2;

  /// No description provided for @quality2.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality2;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @eachExportedProfile.
  ///
  /// In en, this message translates to:
  /// **'Each exported profile is a tuner for Plex, Jellyfin or Emby. Add it in their DVR settings by its address.'**
  String get eachExportedProfile;

  /// No description provided for @channelsInThis.
  ///
  /// In en, this message translates to:
  /// **'Channels in this group'**
  String get channelsInThis;

  /// No description provided for @chooseChannels3.
  ///
  /// In en, this message translates to:
  /// **'Choose channels…'**
  String get chooseChannels3;

  /// No description provided for @channels7.
  ///
  /// In en, this message translates to:
  /// **'{channelIds} channels'**
  String channels7(Object channelIds);

  /// No description provided for @itsChannelsStay.
  ///
  /// In en, this message translates to:
  /// **'Its channels stay in the lineup.'**
  String get itsChannelsStay;

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroup;

  /// No description provided for @groupActions.
  ///
  /// In en, this message translates to:
  /// **'Group actions'**
  String get groupActions;

  /// No description provided for @yourGroup.
  ///
  /// In en, this message translates to:
  /// **'Your group'**
  String get yourGroup;

  /// No description provided for @theOrderOf.
  ///
  /// In en, this message translates to:
  /// **'The order of the tabs in the guide, and which are shown.'**
  String get theOrderOf;

  /// No description provided for @guideTabs.
  ///
  /// In en, this message translates to:
  /// **'Guide tabs'**
  String get guideTabs;

  /// No description provided for @make.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get make;

  /// No description provided for @breaksBetweenPrograms.
  ///
  /// In en, this message translates to:
  /// **'Breaks between programs'**
  String get breaksBetweenPrograms;

  /// No description provided for @breaksInside2.
  ///
  /// In en, this message translates to:
  /// **'{mids, plural, =1{{mids} break inside} other{{mids} breaks inside}}'**
  String breaksInside2(int mids);

  /// No description provided for @songs2.
  ///
  /// In en, this message translates to:
  /// **'{songs} songs'**
  String songs2(Object songs);

  /// No description provided for @newEpisode.
  ///
  /// In en, this message translates to:
  /// **'New episode'**
  String get newEpisode;

  /// No description provided for @noChannelsYet2.
  ///
  /// In en, this message translates to:
  /// **'No channels yet.'**
  String get noChannelsYet2;

  /// No description provided for @noGuide.
  ///
  /// In en, this message translates to:
  /// **'No guide'**
  String get noGuide;

  /// No description provided for @noneShown.
  ///
  /// In en, this message translates to:
  /// **'None shown'**
  String get noneShown;

  /// No description provided for @allShown.
  ///
  /// In en, this message translates to:
  /// **'All shown'**
  String get allShown;

  /// No description provided for @channels8.
  ///
  /// In en, this message translates to:
  /// **'{name}: channels'**
  String channels8(Object name);

  /// No description provided for @orChooseA.
  ///
  /// In en, this message translates to:
  /// **'Or choose a guide file…'**
  String get orChooseA;

  /// No description provided for @emptyThePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Empty: the playlist\'s own guide, if it names one.'**
  String get emptyThePlaylists;

  /// No description provided for @guideAddressXmltv.
  ///
  /// In en, this message translates to:
  /// **'Guide address (XMLTV, optional)'**
  String get guideAddressXmltv;

  /// No description provided for @orChooseAPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Or choose a playlist file…'**
  String get orChooseAPlaylist;

  /// No description provided for @leaveEmptyToKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the playlist file.'**
  String get leaveEmptyToKeep;

  /// No description provided for @httpPlaylistM3u.
  ///
  /// In en, this message translates to:
  /// **'http://…/playlist.m3u'**
  String get httpPlaylistM3u;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @itsChannelsJoin.
  ///
  /// In en, this message translates to:
  /// **'Its channels join while this profile is signed in to that server.'**
  String get itsChannelsJoin;

  /// No description provided for @guide3.
  ///
  /// In en, this message translates to:
  /// **'Guide: {guideFile}'**
  String guide3(Object guideFile);

  /// No description provided for @playlistFile2.
  ///
  /// In en, this message translates to:
  /// **'Playlist file: {playlistFile}'**
  String playlistFile2(Object playlistFile);

  /// No description provided for @refreshed2.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {last} {context}'**
  String refreshed2(Object last, Object context);

  /// No description provided for @itsChannelsLeaveThe.
  ///
  /// In en, this message translates to:
  /// **'Its channels leave the lineup, groups and favorites.'**
  String get itsChannelsLeaveThe;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read {fetched} {context}.'**
  String read(Object fetched, Object context);

  /// No description provided for @showsEpisodesMovies.
  ///
  /// In en, this message translates to:
  /// **'{series} shows · {episodes} episodes · {movies} movies · {songs} songs · {musicVideos} music videos · {commercials} commercial videos'**
  String showsEpisodesMovies(
    Object series,
    Object episodes,
    Object movies,
    Object songs,
    Object musicVideos,
    Object commercials,
  );

  /// No description provided for @fromAs.
  ///
  /// In en, this message translates to:
  /// **'From {server} as {user}.'**
  String fromAs(Object server, Object user);

  /// No description provided for @libraryLabel3.
  ///
  /// In en, this message translates to:
  /// **'{name}: library'**
  String libraryLabel3(Object name);

  /// No description provided for @removeThePin.
  ///
  /// In en, this message translates to:
  /// **'Remove the PIN'**
  String get removeThePin;

  /// No description provided for @pinOptional.
  ///
  /// In en, this message translates to:
  /// **'PIN (optional)'**
  String get pinOptional;

  /// No description provided for @newPinLeave.
  ///
  /// In en, this message translates to:
  /// **'New PIN (leave empty to keep it)'**
  String get newPinLeave;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour {i}'**
  String colour(Object i);

  /// No description provided for @colour2.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour2;

  /// No description provided for @itsChannelsBlocks.
  ///
  /// In en, this message translates to:
  /// **'Its channels, blocks and settings are deleted. A backup is saved first.'**
  String get itsChannelsBlocks;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get exported;

  /// No description provided for @kid3.
  ///
  /// In en, this message translates to:
  /// **'Kid · {label}'**
  String kid3(Object label);

  /// No description provided for @noProfilesAre.
  ///
  /// In en, this message translates to:
  /// **'No profiles are assigned to you yet. Ask an admin.'**
  String get noProfilesAre;

  /// No description provided for @signIn2.
  ///
  /// In en, this message translates to:
  /// **'Sign {name} in'**
  String signIn2(Object name);

  /// No description provided for @theLibraryIs.
  ///
  /// In en, this message translates to:
  /// **'The library is being read again; the server\'s programs join the channels when it\'s done.'**
  String get theLibraryIs;

  /// No description provided for @itsLibraryIs.
  ///
  /// In en, this message translates to:
  /// **'Its library is being read and its channels made. This takes a minute or two.'**
  String get itsLibraryIs;

  /// No description provided for @isSignedIn.
  ///
  /// In en, this message translates to:
  /// **'{name} is signed in.'**
  String isSignedIn(Object name);

  /// No description provided for @couldntDoThat.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t do that. Try again.'**
  String get couldntDoThat;

  /// No description provided for @itsChannelsStayIt.
  ///
  /// In en, this message translates to:
  /// **'Its channels stay; it needs signing in to play.'**
  String get itsChannelsStayIt;

  /// No description provided for @signOut4.
  ///
  /// In en, this message translates to:
  /// **'Sign {name} out?'**
  String signOut4(Object name);

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @wasSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Was signed in to {server} as {user}. Sign in again.'**
  String wasSignedIn(Object server, Object user);

  /// No description provided for @signedInTo.
  ///
  /// In en, this message translates to:
  /// **'Signed in to {server} as {user}.'**
  String signedInTo(Object server, Object user);

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// No description provided for @nameAProfile.
  ///
  /// In en, this message translates to:
  /// **'Name a profile, sign it in to your media server, and its channels are made and exported.'**
  String get nameAProfile;

  /// No description provided for @chooseABackup.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup file…'**
  String get chooseABackup;

  /// No description provided for @moveAHousehold.
  ///
  /// In en, this message translates to:
  /// **'Move a household here from a TV or another server: its profiles, channels, blocks, logos and export settings.'**
  String get moveAHousehold;

  /// No description provided for @restoreABackup.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get restoreABackup;

  /// No description provided for @theServerIs.
  ///
  /// In en, this message translates to:
  /// **'The server is starting…'**
  String get theServerIs;

  /// No description provided for @itsProgramsLeaveThe.
  ///
  /// In en, this message translates to:
  /// **'Its programs leave the channels, which keep their numbers. Sources and commercial folders on it show as not found until you change them.'**
  String get itsProgramsLeaveThe;

  /// No description provided for @addAServerTo.
  ///
  /// In en, this message translates to:
  /// **'Add a server to {name}'**
  String addAServerTo(Object name);

  /// No description provided for @servers2.
  ///
  /// In en, this message translates to:
  /// **'{name}: servers'**
  String servers2(Object name);

  /// No description provided for @makeAccountAnd.
  ///
  /// In en, this message translates to:
  /// **'Make account and sign in'**
  String get makeAccountAnd;

  /// No description provided for @setPasswordAnd.
  ///
  /// In en, this message translates to:
  /// **'Set password and sign in'**
  String get setPasswordAnd;

  /// No description provided for @passwordAgain.
  ///
  /// In en, this message translates to:
  /// **'Password again'**
  String get passwordAgain;

  /// No description provided for @atLeast8.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get atLeast8;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userName;

  /// No description provided for @adminAccount.
  ///
  /// In en, this message translates to:
  /// **'Admin account'**
  String get adminAccount;

  /// No description provided for @makeTheFirst.
  ///
  /// In en, this message translates to:
  /// **'Make the first admin account.'**
  String get makeTheFirst;

  /// No description provided for @setANew.
  ///
  /// In en, this message translates to:
  /// **'Set a new password for an admin account.'**
  String get setANew;

  /// No description provided for @thisSetupLink.
  ///
  /// In en, this message translates to:
  /// **'This setup link has been used, or it\'s from an earlier start. Open the newest one from the server\'s log, or sign in.'**
  String get thisSetupLink;

  /// No description provided for @thePasswordsDont.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get thePasswordsDont;

  /// No description provided for @newPasswordAgain.
  ///
  /// In en, this message translates to:
  /// **'New password again'**
  String get newPasswordAgain;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @passwordChangedYour.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Your other browsers are signed out.'**
  String get passwordChangedYour;

  /// No description provided for @theNewPasswords.
  ///
  /// In en, this message translates to:
  /// **'The new passwords don\'t match.'**
  String get theNewPasswords;

  /// No description provided for @theyAreSigned.
  ///
  /// In en, this message translates to:
  /// **'They are signed out and can\'t sign in again.'**
  String get theyAreSigned;

  /// No description provided for @cantSignIn.
  ///
  /// In en, this message translates to:
  /// **'Can\'t sign in; signed out everywhere.'**
  String get cantSignIn;

  /// No description provided for @usersReachOnly.
  ///
  /// In en, this message translates to:
  /// **'Users reach only the profiles below.'**
  String get usersReachOnly;

  /// No description provided for @adminsCanDo.
  ///
  /// In en, this message translates to:
  /// **'Admins can do everything, on every profile.'**
  String get adminsCanDo;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @leaveEmptyToKeepIt.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep it. Setting one signs them out elsewhere.'**
  String get leaveEmptyToKeepIt;

  /// No description provided for @needsAPassword.
  ///
  /// In en, this message translates to:
  /// **'Needs a password before it can sign in.'**
  String get needsAPassword;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @needsAPassword2.
  ///
  /// In en, this message translates to:
  /// **'Needs a password'**
  String get needsAPassword2;

  /// No description provided for @noProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profiles'**
  String get noProfiles;

  /// No description provided for @pad.
  ///
  /// In en, this message translates to:
  /// **'Pad'**
  String get pad;

  /// No description provided for @clips4.
  ///
  /// In en, this message translates to:
  /// **'{name}  ·  {clips} clips'**
  String clips4(Object name, Object clips);

  /// No description provided for @clipsFrom2.
  ///
  /// In en, this message translates to:
  /// **'Clips from'**
  String get clipsFrom2;

  /// No description provided for @channelsUsingItGo.
  ///
  /// In en, this message translates to:
  /// **'Channels using it go back to a built-in icon.'**
  String get channelsUsingItGo;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @noneOfYourShows.
  ///
  /// In en, this message translates to:
  /// **'None of your shows have a logo image on your server.'**
  String get noneOfYourShows;

  /// No description provided for @chooseAnIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get chooseAnIcon;

  /// No description provided for @couldntCopySelect.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t copy. Select the text and copy it.'**
  String get couldntCopySelect;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String copy(Object label);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @thereIsNoPage.
  ///
  /// In en, this message translates to:
  /// **'There is no page here.'**
  String get thereIsNoPage;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @thisIsA.
  ///
  /// In en, this message translates to:
  /// **'This is a kid profile. Changing its settings needs a grown-up\'s PIN.'**
  String get thisIsA;

  /// No description provided for @hasAPin.
  ///
  /// In en, this message translates to:
  /// **'{name} has a PIN.'**
  String hasAPin(Object name);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @changingAKid.
  ///
  /// In en, this message translates to:
  /// **'Changing a kid profile\'s settings needs the PIN of a grown-up profile.'**
  String get changingAKid;

  /// No description provided for @aGrownUps.
  ///
  /// In en, this message translates to:
  /// **'A grown-up\'s PIN'**
  String get aGrownUps;

  /// No description provided for @thisProfile.
  ///
  /// In en, this message translates to:
  /// **'this profile'**
  String get thisProfile;

  /// No description provided for @movies3.
  ///
  /// In en, this message translates to:
  /// **'Movies ({movies})'**
  String movies3(Object movies);

  /// No description provided for @shows3.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get shows3;

  /// No description provided for @remove4.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String remove4(Object label);

  /// No description provided for @notFoundOnThe.
  ///
  /// In en, this message translates to:
  /// **'{label} · Not found on the server'**
  String notFoundOnThe(Object label);

  /// No description provided for @dragACollection.
  ///
  /// In en, this message translates to:
  /// **'Drag a collection, folder or movie here, or use its Add button.'**
  String get dragACollection;

  /// No description provided for @collectionsAndFolders.
  ///
  /// In en, this message translates to:
  /// **'Collections and folders'**
  String get collectionsAndFolders;

  /// No description provided for @add3.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String add3(Object name);

  /// No description provided for @added2.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String added2(Object name);

  /// No description provided for @dragToAdd.
  ///
  /// In en, this message translates to:
  /// **'Drag to add'**
  String get dragToAdd;

  /// No description provided for @languageAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get languageAutomatic;

  /// No description provided for @dateAtTime.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateAtTime(String date, String time);

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {server}…'**
  String connectingTo(Object server);

  /// No description provided for @yourServerLower.
  ///
  /// In en, this message translates to:
  /// **'your server'**
  String get yourServerLower;

  /// No description provided for @noServerFoundAt.
  ///
  /// In en, this message translates to:
  /// **'No Jellyfin, Emby or Plex server found at {address}.'**
  String noServerFoundAt(Object address);

  /// No description provided for @captionsValue.
  ///
  /// In en, this message translates to:
  /// **'Captions: {name}'**
  String captionsValue(Object name);

  /// No description provided for @channelOverrides.
  ///
  /// In en, this message translates to:
  /// **'{count} channels have its own setting (Channels & icons).'**
  String channelOverrides(int count);

  /// No description provided for @noShowLogosOn.
  ///
  /// In en, this message translates to:
  /// **'None of your shows have a logo image on your {kind} server.'**
  String noShowLogosOn(Object kind);

  /// No description provided for @fileChosen.
  ///
  /// In en, this message translates to:
  /// **'File: {name}'**
  String fileChosen(Object name);

  /// No description provided for @theOneChosenBefore.
  ///
  /// In en, this message translates to:
  /// **'the one chosen before'**
  String get theOneChosenBefore;

  /// No description provided for @streamingChannels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Streaming channel {channels} to {viewers} viewer(s). {running} of {limit} streams in use.} other{Streaming channels {channels} to {viewers} viewer(s). {running} of {limit} streams in use.}}'**
  String streamingChannels(
    int count,
    Object channels,
    Object viewers,
    Object running,
    Object limit,
  );

  /// No description provided for @exportThisLineup.
  ///
  /// In en, this message translates to:
  /// **'{name}: export this lineup'**
  String exportThisLineup(Object name);

  /// No description provided for @exportThisLineupKid.
  ///
  /// In en, this message translates to:
  /// **'{name} (kid): export this lineup'**
  String exportThisLineupKid(Object name);

  /// No description provided for @encoderInUse.
  ///
  /// In en, this message translates to:
  /// **'Encoder in use: {encoder}'**
  String encoderInUse(Object encoder);

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'checking…'**
  String get checking;

  /// No description provided for @countShows.
  ///
  /// In en, this message translates to:
  /// **'{count} shows'**
  String countShows(int count);

  /// No description provided for @countEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes'**
  String countEpisodes(int count);

  /// No description provided for @countMovies.
  ///
  /// In en, this message translates to:
  /// **'{count} movies'**
  String countMovies(int count);

  /// No description provided for @countSongs.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String countSongs(int count);

  /// No description provided for @countMusicVideos.
  ///
  /// In en, this message translates to:
  /// **'{count} music videos'**
  String countMusicVideos(int count);

  /// No description provided for @countHidden.
  ///
  /// In en, this message translates to:
  /// **'{count} hidden'**
  String countHidden(int count);

  /// No description provided for @countOnTheAir.
  ///
  /// In en, this message translates to:
  /// **'{count} on the air'**
  String countOnTheAir(int count);

  /// No description provided for @countProgrammingBlocks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} programming block} other{{count} programming blocks}}'**
  String countProgrammingBlocks(int count);

  /// No description provided for @perServerStats.
  ///
  /// In en, this message translates to:
  /// **'{name}: {stats}'**
  String perServerStats(Object name, Object stats);

  /// No description provided for @yourServerHasNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Your server has nothing new since the last refresh. New files show up here once the server has scanned them: if you just added some, scan the library on the server first, then refresh again.'**
  String get yourServerHasNothingNew;

  /// No description provided for @serverHasNothingNew.
  ///
  /// In en, this message translates to:
  /// **'{server} has nothing new since the last refresh. New files show up here once the server has scanned them: if you just added some, scan the library on the server first, then refresh again.'**
  String serverHasNothingNew(Object server);

  /// No description provided for @updateWatchStatusOnYourServer.
  ///
  /// In en, this message translates to:
  /// **'Update watch status on your server'**
  String get updateWatchStatusOnYourServer;

  /// No description provided for @updateWatchStatusOnYourServers.
  ///
  /// In en, this message translates to:
  /// **'Update watch status on your servers'**
  String get updateWatchStatusOnYourServers;

  /// No description provided for @updateWatchStatusOn.
  ///
  /// In en, this message translates to:
  /// **'Update watch status on {name}'**
  String updateWatchStatusOn(Object name);

  /// No description provided for @poolFoldersBumpers.
  ///
  /// In en, this message translates to:
  /// **'Every video in these folders (and the folders inside them) opens and closes breaks, and never airs as a program.'**
  String get poolFoldersBumpers;

  /// No description provided for @poolFoldersCommercials.
  ///
  /// In en, this message translates to:
  /// **'Every video in these folders (and the folders inside them) fills breaks, and never airs as a program.'**
  String get poolFoldersCommercials;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// No description provided for @namedPin.
  ///
  /// In en, this message translates to:
  /// **'{name} PIN'**
  String namedPin(Object name);

  /// No description provided for @qualitySameAsProfile.
  ///
  /// In en, this message translates to:
  /// **'Quality: same as the profile'**
  String get qualitySameAsProfile;

  /// No description provided for @qualityValue.
  ///
  /// In en, this message translates to:
  /// **'Quality: {limit}'**
  String qualityValue(Object limit);

  /// No description provided for @onChannel.
  ///
  /// In en, this message translates to:
  /// **'on {channel}'**
  String onChannel(Object channel);

  /// No description provided for @aChannelThatIsGone.
  ///
  /// In en, this message translates to:
  /// **'a channel that is gone'**
  String get aChannelThatIsGone;

  /// No description provided for @liveFrom.
  ///
  /// In en, this message translates to:
  /// **'Live from {source}'**
  String liveFrom(Object source);

  /// No description provided for @logoAndPremieres.
  ///
  /// In en, this message translates to:
  /// **'Logo {mode} · Premieres {premieres}'**
  String logoAndPremieres(Object mode, Object premieres);

  /// No description provided for @offLower.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get offLower;

  /// No description provided for @streamingNow.
  ///
  /// In en, this message translates to:
  /// **'{count} streaming now.'**
  String streamingNow(Object count);

  /// No description provided for @streamingNowEncoding.
  ///
  /// In en, this message translates to:
  /// **'{count} streaming now · encoding with {encoder}.'**
  String streamingNowEncoding(Object count, Object encoder);

  /// No description provided for @kindChosenChannels.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {chosen} of {channels} channels'**
  String kindChosenChannels(Object kind, Object chosen, Object channels);

  /// No description provided for @backupSummary.
  ///
  /// In en, this message translates to:
  /// **'From {when} ({device}): {profiles}. {channels} channels, {blocks} programming blocks, {logos} logos.'**
  String backupSummary(
    Object when,
    Object device,
    Object profiles,
    Object channels,
    Object blocks,
    Object logos,
  );

  /// No description provided for @backupSavedFirst.
  ///
  /// In en, this message translates to:
  /// **'A backup of what\'s here now is saved first.'**
  String get backupSavedFirst;

  /// No description provided for @newShows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} new show} other{{count} new shows}}'**
  String newShows(int count);

  /// No description provided for @newEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} new episode} other{{count} new episodes}}'**
  String newEpisodes(int count);

  /// No description provided for @newMovies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} new movie} other{{count} new movies}}'**
  String newMovies(int count);

  /// No description provided for @newSongs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} new song} other{{count} new songs}}'**
  String newSongs(int count);

  /// No description provided for @playsList.
  ///
  /// In en, this message translates to:
  /// **'Plays {list}.'**
  String playsList(Object list);

  /// No description provided for @newChannels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} new channel} other{{count} new channels}}'**
  String newChannels(int count);

  /// No description provided for @kidRatingYoung.
  ///
  /// In en, this message translates to:
  /// **'Young kids'**
  String get kidRatingYoung;

  /// No description provided for @kidRatingYoungDescription.
  ///
  /// In en, this message translates to:
  /// **'TV-Y and TV-Y7'**
  String get kidRatingYoungDescription;

  /// No description provided for @kidRatingKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get kidRatingKids;

  /// No description provided for @kidRatingKidsDescription.
  ///
  /// In en, this message translates to:
  /// **'Up to TV-G and G'**
  String get kidRatingKidsDescription;

  /// No description provided for @kidRatingOlder.
  ///
  /// In en, this message translates to:
  /// **'Older kids'**
  String get kidRatingOlder;

  /// No description provided for @kidRatingOlderDescription.
  ///
  /// In en, this message translates to:
  /// **'Up to TV-PG and PG'**
  String get kidRatingOlderDescription;

  /// No description provided for @countProfilesWord.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} profile} other{{count} profiles}}'**
  String countProfilesWord(int count);

  /// No description provided for @countChannelsWord.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} channel} other{{count} channels}}'**
  String countChannelsWord(int count);

  /// No description provided for @countBlocksWord.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} block} other{{count} blocks}}'**
  String countBlocksWord(int count);

  /// No description provided for @countSlots.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} slot} other{{count} slots}}'**
  String countSlots(int count);

  /// No description provided for @videosInFolders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} video in its folders} other{{count} videos in its folders}}'**
  String videosInFolders(int count);

  /// No description provided for @backupProfilesChannelsBlocks.
  ///
  /// In en, this message translates to:
  /// **'{profiles} · {channels} · {blocks}.'**
  String backupProfilesChannelsBlocks(
    Object profiles,
    Object channels,
    Object blocks,
  );

  /// No description provided for @liveLabel.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveLabel;

  /// No description provided for @aMidRollOpens.
  ///
  /// In en, this message translates to:
  /// **'A mid-roll opens and closes with a bumper, a post-roll opens with one, and a pre-roll closes with one. Commercials fill the rest.'**
  String get aMidRollOpens;

  /// No description provided for @programsPlayBack.
  ///
  /// In en, this message translates to:
  /// **'Programs play back to back, with no breaks.'**
  String get programsPlayBack;

  /// No description provided for @everyShowFills.
  ///
  /// In en, this message translates to:
  /// **'Every show fills a half-hour slot (an hour or more for long ones), so the guide stays on the clock.'**
  String get everyShowFills;

  /// No description provided for @chooseHowLong.
  ///
  /// In en, this message translates to:
  /// **'Choose how long each break is, how often shows break, and which pool each break draws from.'**
  String get chooseHowLong;

  /// No description provided for @kindSentenceAutomatic.
  ///
  /// In en, this message translates to:
  /// **'automatic'**
  String get kindSentenceAutomatic;

  /// No description provided for @kindSentenceBeforeRestore.
  ///
  /// In en, this message translates to:
  /// **'before restore'**
  String get kindSentenceBeforeRestore;

  /// No description provided for @kindSentenceBeforeReset.
  ///
  /// In en, this message translates to:
  /// **'before reset'**
  String get kindSentenceBeforeReset;

  /// No description provided for @kindSentenceBeforeDeletingAProfile.
  ///
  /// In en, this message translates to:
  /// **'before deleting a profile'**
  String get kindSentenceBeforeDeletingAProfile;

  /// No description provided for @kindSentenceBeforeDeleting.
  ///
  /// In en, this message translates to:
  /// **'before deleting {subject}'**
  String kindSentenceBeforeDeleting(Object subject);

  /// No description provided for @kindSentenceBeforeUpdate.
  ///
  /// In en, this message translates to:
  /// **'before update'**
  String get kindSentenceBeforeUpdate;

  /// No description provided for @kindSentenceBeforeLineupCleanup.
  ///
  /// In en, this message translates to:
  /// **'before lineup cleanup'**
  String get kindSentenceBeforeLineupCleanup;

  /// No description provided for @kindSentenceFromAFile.
  ///
  /// In en, this message translates to:
  /// **'from a file'**
  String get kindSentenceFromAFile;

  /// No description provided for @kindSentenceMovingToOfficial.
  ///
  /// In en, this message translates to:
  /// **'moving to Nightingale TV'**
  String get kindSentenceMovingToOfficial;

  /// No description provided for @kindSentenceMovingToOwnBuild.
  ///
  /// In en, this message translates to:
  /// **'moving to Nightingale TV (own build)'**
  String get kindSentenceMovingToOwnBuild;

  /// No description provided for @kindSentenceFromOfficial.
  ///
  /// In en, this message translates to:
  /// **'from Nightingale TV'**
  String get kindSentenceFromOfficial;

  /// No description provided for @kindSentenceFromOwnBuild.
  ///
  /// In en, this message translates to:
  /// **'from Nightingale TV (own build)'**
  String get kindSentenceFromOwnBuild;

  /// No description provided for @kindSentenceMadeByYou.
  ///
  /// In en, this message translates to:
  /// **'made by you'**
  String get kindSentenceMadeByYou;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @channelKidsZone.
  ///
  /// In en, this message translates to:
  /// **'Kids Zone'**
  String get channelKidsZone;

  /// No description provided for @channelToonTv.
  ///
  /// In en, this message translates to:
  /// **'Toon TV'**
  String get channelToonTv;

  /// No description provided for @channelLaughTrack.
  ///
  /// In en, this message translates to:
  /// **'Laugh Track'**
  String get channelLaughTrack;

  /// No description provided for @channelFamilyRoom.
  ///
  /// In en, this message translates to:
  /// **'Family Room'**
  String get channelFamilyRoom;

  /// No description provided for @channelAdventureTv.
  ///
  /// In en, this message translates to:
  /// **'Adventure TV'**
  String get channelAdventureTv;

  /// No description provided for @channelSciFiFantasy.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi & Fantasy'**
  String get channelSciFiFantasy;

  /// No description provided for @channelMysteryTv.
  ///
  /// In en, this message translates to:
  /// **'Mystery TV'**
  String get channelMysteryTv;

  /// No description provided for @channelDramaCentral.
  ///
  /// In en, this message translates to:
  /// **'Drama Central'**
  String get channelDramaCentral;

  /// No description provided for @channelCrimeJustice.
  ///
  /// In en, this message translates to:
  /// **'Crime & Justice'**
  String get channelCrimeJustice;

  /// No description provided for @channelThrillTv.
  ///
  /// In en, this message translates to:
  /// **'Thrill TV'**
  String get channelThrillTv;

  /// No description provided for @channelFrightNight.
  ///
  /// In en, this message translates to:
  /// **'Fright Night'**
  String get channelFrightNight;

  /// No description provided for @channelRomanceTv.
  ///
  /// In en, this message translates to:
  /// **'Romance TV'**
  String get channelRomanceTv;

  /// No description provided for @channelDiscoveryZone.
  ///
  /// In en, this message translates to:
  /// **'Discovery Zone'**
  String get channelDiscoveryZone;

  /// No description provided for @channelMusicTv.
  ///
  /// In en, this message translates to:
  /// **'Music TV'**
  String get channelMusicTv;

  /// No description provided for @channelRealityTv.
  ///
  /// In en, this message translates to:
  /// **'Reality TV'**
  String get channelRealityTv;

  /// No description provided for @channelGameShowTv.
  ///
  /// In en, this message translates to:
  /// **'Game Show TV'**
  String get channelGameShowTv;

  /// No description provided for @channelFrontierTv.
  ///
  /// In en, this message translates to:
  /// **'Frontier TV'**
  String get channelFrontierTv;

  /// No description provided for @channelHistoryTv.
  ///
  /// In en, this message translates to:
  /// **'History TV'**
  String get channelHistoryTv;

  /// No description provided for @channelSportsTv.
  ///
  /// In en, this message translates to:
  /// **'Sports TV'**
  String get channelSportsTv;

  /// No description provided for @channelNewsTv.
  ///
  /// In en, this message translates to:
  /// **'News TV'**
  String get channelNewsTv;

  /// No description provided for @channelAllShows.
  ///
  /// In en, this message translates to:
  /// **'All Shows'**
  String get channelAllShows;

  /// No description provided for @channelMovieChannel.
  ///
  /// In en, this message translates to:
  /// **'Movie Channel'**
  String get channelMovieChannel;

  /// No description provided for @channelMusicVideos.
  ///
  /// In en, this message translates to:
  /// **'Music Videos'**
  String get channelMusicVideos;

  /// No description provided for @channelMusicRadio.
  ///
  /// In en, this message translates to:
  /// **'Music Radio'**
  String get channelMusicRadio;

  /// No description provided for @genreActionAdventure.
  ///
  /// In en, this message translates to:
  /// **'Action & Adventure'**
  String get genreActionAdventure;

  /// No description provided for @genreSciFiFantasy.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi & Fantasy'**
  String get genreSciFiFantasy;

  /// No description provided for @genreKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get genreKids;

  /// No description provided for @genreAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get genreAnimation;

  /// No description provided for @genreComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get genreComedy;

  /// No description provided for @genreFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get genreFamily;

  /// No description provided for @genreDrama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get genreDrama;

  /// No description provided for @genreCrime.
  ///
  /// In en, this message translates to:
  /// **'Crime'**
  String get genreCrime;

  /// No description provided for @genreMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get genreMystery;

  /// No description provided for @genreThriller.
  ///
  /// In en, this message translates to:
  /// **'Thriller'**
  String get genreThriller;

  /// No description provided for @genreHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get genreHorror;

  /// No description provided for @genreRomance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get genreRomance;

  /// No description provided for @genreDocumentary.
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get genreDocumentary;

  /// No description provided for @genreMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get genreMusic;

  /// No description provided for @genreReality.
  ///
  /// In en, this message translates to:
  /// **'Reality'**
  String get genreReality;

  /// No description provided for @genreGameShows.
  ///
  /// In en, this message translates to:
  /// **'Game Shows'**
  String get genreGameShows;

  /// No description provided for @genreWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get genreWestern;

  /// No description provided for @genreWar.
  ///
  /// In en, this message translates to:
  /// **'War'**
  String get genreWar;

  /// No description provided for @genreHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get genreHistory;

  /// No description provided for @genreNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get genreNews;

  /// No description provided for @genreTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get genreTalk;

  /// No description provided for @genreSoap.
  ///
  /// In en, this message translates to:
  /// **'Soap'**
  String get genreSoap;

  /// No description provided for @genreSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get genreSports;

  /// No description provided for @genreClassical.
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get genreClassical;

  /// No description provided for @genreElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic'**
  String get genreElectronic;

  /// No description provided for @genreCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get genreCountry;

  /// No description provided for @genreLatin.
  ///
  /// In en, this message translates to:
  /// **'Latin'**
  String get genreLatin;

  /// No description provided for @genreSoundtrack.
  ///
  /// In en, this message translates to:
  /// **'Soundtrack'**
  String get genreSoundtrack;

  /// No description provided for @genreOldies.
  ///
  /// In en, this message translates to:
  /// **'Oldies'**
  String get genreOldies;

  /// No description provided for @genreDance.
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get genreDance;

  /// No description provided for @genreFolk.
  ///
  /// In en, this message translates to:
  /// **'Folk'**
  String get genreFolk;

  /// No description provided for @genreAlternative.
  ///
  /// In en, this message translates to:
  /// **'Alternative'**
  String get genreAlternative;

  /// No description provided for @blockDaytime.
  ///
  /// In en, this message translates to:
  /// **'Daytime'**
  String get blockDaytime;

  /// No description provided for @blockMovieNight.
  ///
  /// In en, this message translates to:
  /// **'Movie Night'**
  String get blockMovieNight;

  /// No description provided for @blockNewEpisodes.
  ///
  /// In en, this message translates to:
  /// **'New Episodes'**
  String get blockNewEpisodes;

  /// No description provided for @kindShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get kindShow;

  /// No description provided for @kindShows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get kindShows;

  /// No description provided for @kindMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get kindMovies;

  /// No description provided for @kindMusicVideos.
  ///
  /// In en, this message translates to:
  /// **'Music Videos'**
  String get kindMusicVideos;

  /// No description provided for @kindRadio.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get kindRadio;

  /// No description provided for @genreMovies.
  ///
  /// In en, this message translates to:
  /// **'{genre} Movies'**
  String genreMovies(Object genre);

  /// No description provided for @genreMusicVideos.
  ///
  /// In en, this message translates to:
  /// **'{genre} Music Videos'**
  String genreMusicVideos(Object genre);

  /// No description provided for @genreRadio.
  ///
  /// In en, this message translates to:
  /// **'{genre} Radio'**
  String genreRadio(Object genre);

  /// No description provided for @kindSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} ({kind})'**
  String kindSuffix(Object name, Object kind);

  /// No description provided for @kindSuffixNumbered.
  ///
  /// In en, this message translates to:
  /// **'{name} ({kind} {number})'**
  String kindSuffixNumbered(Object name, Object kind, Object number);

  /// No description provided for @lateNightTitle.
  ///
  /// In en, this message translates to:
  /// **'Late Night'**
  String get lateNightTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @stillWatchingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get stillWatchingOff;

  /// No description provided for @afterHours.
  ///
  /// In en, this message translates to:
  /// **'After {hours} hours'**
  String afterHours(int hours);

  /// No description provided for @bitrateOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original (no limit)'**
  String get bitrateOriginal;

  /// No description provided for @bitrate40.
  ///
  /// In en, this message translates to:
  /// **'40 Mbps · 4K'**
  String get bitrate40;

  /// No description provided for @bitrate20.
  ///
  /// In en, this message translates to:
  /// **'20 Mbps · 1080p high'**
  String get bitrate20;

  /// No description provided for @bitrate12.
  ///
  /// In en, this message translates to:
  /// **'12 Mbps · 1080p'**
  String get bitrate12;

  /// No description provided for @bitrate8.
  ///
  /// In en, this message translates to:
  /// **'8 Mbps · 1080p'**
  String get bitrate8;

  /// No description provided for @bitrate4.
  ///
  /// In en, this message translates to:
  /// **'4 Mbps · 720p'**
  String get bitrate4;

  /// No description provided for @noSuchLanguage.
  ///
  /// In en, this message translates to:
  /// **'No such language.'**
  String get noSuchLanguage;

  /// No description provided for @languageField.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageField;

  /// No description provided for @remotePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Nightingale TV Remote'**
  String get remotePageTitle;

  /// No description provided for @remotePairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair with the TV'**
  String get remotePairTitle;

  /// No description provided for @remotePairHelp.
  ///
  /// In en, this message translates to:
  /// **'Scan the code on the TV (Menu → Phone remote), or enter the 6-digit code shown there.'**
  String get remotePairHelp;

  /// No description provided for @remotePairingCode.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get remotePairingCode;

  /// No description provided for @remotePair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get remotePair;

  /// No description provided for @remoteConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get remoteConnecting;

  /// No description provided for @remoteTabRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remoteTabRemote;

  /// No description provided for @remoteUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get remoteUp;

  /// No description provided for @remoteLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get remoteLeft;

  /// No description provided for @remoteRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get remoteRight;

  /// No description provided for @remoteDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get remoteDown;

  /// No description provided for @remoteInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get remoteInfo;

  /// No description provided for @remoteLastCh.
  ///
  /// In en, this message translates to:
  /// **'Last ch'**
  String get remoteLastCh;

  /// No description provided for @remoteCc.
  ///
  /// In en, this message translates to:
  /// **'CC'**
  String get remoteCc;

  /// No description provided for @remoteChUp.
  ///
  /// In en, this message translates to:
  /// **'CH +'**
  String get remoteChUp;

  /// No description provided for @remoteChDown.
  ///
  /// In en, this message translates to:
  /// **'CH −'**
  String get remoteChDown;

  /// No description provided for @remoteEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get remoteEnter;

  /// No description provided for @remoteRemovedFromTv.
  ///
  /// In en, this message translates to:
  /// **'This phone was removed from the TV. Scan the code to pair again.'**
  String get remoteRemovedFromTv;

  /// No description provided for @remoteCouldntPair.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t pair. Try again.'**
  String get remoteCouldntPair;

  /// No description provided for @remoteCantReachWifi.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the TV. Is this phone on the same Wi-Fi?'**
  String get remoteCantReachWifi;

  /// No description provided for @remoteEnterDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits shown on the TV.'**
  String get remoteEnterDigits;

  /// No description provided for @remoteCantReachTv.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the TV'**
  String get remoteCantReachTv;

  /// No description provided for @remotePickProfile.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile with the arrows and OK.'**
  String get remotePickProfile;

  /// No description provided for @remoteWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching: {name}'**
  String remoteWatching(Object name);

  /// No description provided for @remoteKidName.
  ///
  /// In en, this message translates to:
  /// **'{name} (kid)'**
  String remoteKidName(Object name);

  /// No description provided for @transferPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Nightingale TV Backup'**
  String get transferPageTitle;

  /// No description provided for @transferIntro.
  ///
  /// In en, this message translates to:
  /// **'Move a backup between this TV and this device. Keep the TV\'s dialog open while you do.'**
  String get transferIntro;

  /// No description provided for @transferDownload.
  ///
  /// In en, this message translates to:
  /// **'Download backup'**
  String get transferDownload;

  /// No description provided for @transferDownloadHelp.
  ///
  /// In en, this message translates to:
  /// **'A backup of the TV\'s setup as it is now: profiles, channels, blocks and settings.'**
  String get transferDownloadHelp;

  /// No description provided for @transferRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file'**
  String get transferRestoreTitle;

  /// No description provided for @transferRestoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Send a {file} file to the TV. Nothing changes until you confirm it on the TV.'**
  String transferRestoreHelp(Object file);

  /// No description provided for @transferChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup file…'**
  String get transferChoose;

  /// No description provided for @transferFoot.
  ///
  /// In en, this message translates to:
  /// **'Only devices on your home network can open this page.'**
  String get transferFoot;

  /// No description provided for @transferSending.
  ///
  /// In en, this message translates to:
  /// **'Sending {name}…'**
  String transferSending(Object name);

  /// No description provided for @transferCheckTv.
  ///
  /// In en, this message translates to:
  /// **'Check your TV to finish.'**
  String get transferCheckTv;

  /// No description provided for @transferClosed.
  ///
  /// In en, this message translates to:
  /// **'The TV closed this page. Open it again from Backup & restore.'**
  String get transferClosed;

  /// No description provided for @transferCouldntTake.
  ///
  /// In en, this message translates to:
  /// **'The TV couldn’t take that file.'**
  String get transferCouldntTake;

  /// No description provided for @transferCouldntReach.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the TV. Is it still showing the code?'**
  String get transferCouldntReach;

  /// No description provided for @includeShows.
  ///
  /// In en, this message translates to:
  /// **'Include shows'**
  String get includeShows;

  /// No description provided for @everyShow2.
  ///
  /// In en, this message translates to:
  /// **'every show'**
  String get everyShow2;

  /// No description provided for @decades.
  ///
  /// In en, this message translates to:
  /// **'Decades'**
  String get decades;

  /// No description provided for @decadesHeading.
  ///
  /// In en, this message translates to:
  /// **'DECADES'**
  String get decadesHeading;

  /// No description provided for @channelActionTv.
  ///
  /// In en, this message translates to:
  /// **'Action TV'**
  String get channelActionTv;

  /// No description provided for @channelSciFiTv.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi TV'**
  String get channelSciFiTv;

  /// No description provided for @channelFantasyTv.
  ///
  /// In en, this message translates to:
  /// **'Fantasy TV'**
  String get channelFantasyTv;

  /// No description provided for @channelMysteryThrills.
  ///
  /// In en, this message translates to:
  /// **'Mystery & Thrills'**
  String get channelMysteryThrills;

  /// No description provided for @genreAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get genreAction;

  /// No description provided for @genreAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get genreAdventure;

  /// No description provided for @genreSciFi.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get genreSciFi;

  /// No description provided for @genreFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get genreFantasy;

  /// No description provided for @genreThrillerMystery.
  ///
  /// In en, this message translates to:
  /// **'Thriller & Mystery'**
  String get genreThrillerMystery;

  /// No description provided for @decadeTv.
  ///
  /// In en, this message translates to:
  /// **'{decade} TV'**
  String decadeTv(Object decade);

  /// No description provided for @decadeGenreTv.
  ///
  /// In en, this message translates to:
  /// **'{decade} {genre} TV'**
  String decadeGenreTv(Object decade, Object genre);

  /// No description provided for @decadeGenreMovies.
  ///
  /// In en, this message translates to:
  /// **'{decade} {genre} Movies'**
  String decadeGenreMovies(Object decade, Object genre);

  /// No description provided for @errorReports.
  ///
  /// In en, this message translates to:
  /// **'Error reports'**
  String get errorReports;

  /// No description provided for @sendErrorReportsFrom.
  ///
  /// In en, this message translates to:
  /// **'Send error reports from this device'**
  String get sendErrorReportsFrom;

  /// No description provided for @errorReportsExplain.
  ///
  /// In en, this message translates to:
  /// **'When something goes wrong, Nightingale TV sends its developer a short report: the error, the app version, the kind of device, and the last few screens and channel numbers. Server addresses, passwords and keys, names and file paths are taken out before it\'s sent. Titles and what you watch are never sent.'**
  String get errorReportsExplain;

  /// No description provided for @errorReportsOff.
  ///
  /// In en, this message translates to:
  /// **'Turn this off and nothing is sent from this device; reports waiting to go are deleted.'**
  String get errorReportsOff;

  /// No description provided for @sendATestReport.
  ///
  /// In en, this message translates to:
  /// **'Send a test report'**
  String get sendATestReport;

  /// No description provided for @lastReportId.
  ///
  /// In en, this message translates to:
  /// **'Last report ID: {id}'**
  String lastReportId(String id);

  /// No description provided for @noReportSentYet.
  ///
  /// In en, this message translates to:
  /// **'No report sent from this device yet.'**
  String get noReportSentYet;

  /// No description provided for @quoteReportId.
  ///
  /// In en, this message translates to:
  /// **'Quote this ID when you tell the developer about a problem.'**
  String get quoteReportId;

  /// No description provided for @testReportSent.
  ///
  /// In en, this message translates to:
  /// **'Test report sent: {id}'**
  String testReportSent(String id);

  /// No description provided for @testReportNotSent.
  ///
  /// In en, this message translates to:
  /// **'The test report couldn\'t be sent. Try again in a moment.'**
  String get testReportNotSent;

  /// No description provided for @reportsNotInBuild.
  ///
  /// In en, this message translates to:
  /// **'Error reporting isn\'t part of this build of Nightingale TV, so nothing is ever sent.'**
  String get reportsNotInBuild;

  /// No description provided for @sendAVideoReport.
  ///
  /// In en, this message translates to:
  /// **'Send a video report'**
  String get sendAVideoReport;

  /// No description provided for @videoReportHelp.
  ///
  /// In en, this message translates to:
  /// **'If the picture looks wrong, press this, then go back to a channel. After 10 seconds of picture, the report is sent and its ID shows on the TV screen.'**
  String get videoReportHelp;

  /// No description provided for @videoReportArmed.
  ///
  /// In en, this message translates to:
  /// **'Go back to a channel now. The video report is sent after 10 seconds of its picture.'**
  String get videoReportArmed;

  /// No description provided for @videoReportTooSoon.
  ///
  /// In en, this message translates to:
  /// **'A video report was sent less than a minute ago. Try again in a moment.'**
  String get videoReportTooSoon;

  /// No description provided for @videoReportSent.
  ///
  /// In en, this message translates to:
  /// **'Video report sent: {id}'**
  String videoReportSent(String id);

  /// No description provided for @videoReportsExplain.
  ///
  /// In en, this message translates to:
  /// **'A video report sends facts about the device, the video and its decoder, coarse colour grids of the picture and the app\'s own recent log lines; never an image of what you watch. One is sent once after each app update, when a channel has played for 10 seconds.'**
  String get videoReportsExplain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
