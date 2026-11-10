// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get onlyChannelsYou =>
      'Nur selbst hinzugefügte Sender können entfernt werden. Blende diesen stattdessen aus.';

  @override
  String get music => 'Musik';

  @override
  String get nothingInThe => 'Nichts in der Mediathek passt dazu.';

  @override
  String get chooseSongsOr => 'Wähle Songs oder Musikvideos.';

  @override
  String get blockChannel => 'Blocksender';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return 'Das überschneidet sich mit „$title“ ($clash) auf demselben Sender.';
  }

  @override
  String get chooseSomeShows =>
      'Wähle Serien oder Filme, die der Block spielen soll.';

  @override
  String nothingInThis(Object shortLabel) {
    return 'Nichts in dieser Mischung hat die Altersfreigabe $shortLabel oder höher. Wähle eine niedrigere Freigabe oder andere Serien.';
  }

  @override
  String get theLineupsShows =>
      'Die Serien der Abfolge haben keine Folgen. Wähle andere Serien.';

  @override
  String get addAShow => 'Füge der Abfolge eine Serie hinzu.';

  @override
  String get chooseAChannel => 'Wähle einen Sender.';

  @override
  String get theBlockHas =>
      'Der Block muss zu einer anderen Zeit enden, als er beginnt.';

  @override
  String get pickAtLeast => 'Wähle mindestens einen Tag.';

  @override
  String get giveTheBlock => 'Gib dem Block einen Titel.';

  @override
  String get thisChannelDoesnt => 'Dieser Sender hat keine Sendeplätze.';

  @override
  String get onlyShuffledChannels =>
      'Nur Sender mit Zufallswiedergabe können neu gemischt werden.';

  @override
  String get chooseSomethingFor =>
      'Wähle etwas aus, das der Sender spielen soll.';

  @override
  String get onlyChannelsYouAdded =>
      'Nur bei selbst hinzugefügten Sendern lässt sich das Programm ändern.';

  @override
  String get myChannel => 'Mein Sender';

  @override
  String get noneOfYour => 'Keiner deiner Server war erreichbar.';

  @override
  String scanning(Object where) {
    return '$where wird durchsucht…';
  }

  @override
  String get buildingChannels => 'Sender werden erstellt…';

  @override
  String get notSignedIn => 'Nicht angemeldet.';

  @override
  String isAlreadyIn(Object name) {
    return '$name ist bereits in diesem Profil';
  }

  @override
  String get thatServerIs => 'Dieser Server ist nicht mehr in diesem Profil';

  @override
  String get yourSessionExpired =>
      'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get m3uPlaylist => 'M3U-Wiedergabeliste';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName hat keine Live-TV-Sender';
  }

  @override
  String couldntReach(Object serverName) {
    return '$serverName nicht erreichbar';
  }

  @override
  String liveTv(Object serverName) {
    return '$serverName Live-TV';
  }

  @override
  String liveTvIs(Object serverName) {
    return '$serverName Live-TV ist bereits eine Quelle';
  }

  @override
  String get notSignedIn2 => 'Nicht angemeldet';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get thisBackupIs =>
      'Diese Sicherung ist beschädigt: Eines ihrer Senderlogos kann nicht gelesen werden.';

  @override
  String get thisBackupIsDamaged =>
      'Diese Sicherung ist beschädigt: Ihre Live-TV-Export-Einstellungen können nicht gelesen werden.';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'Diese Sicherung ist beschädigt: $what von $name kann nicht gelesen werden.';
  }

  @override
  String get liveTvSources => 'Live-TV-Quellen';

  @override
  String thisBackupCant(Object problem) {
    return 'Diese Sicherung kann nicht wiederhergestellt werden. $problem';
  }

  @override
  String get thisBackupIsDamagedIts =>
      'Diese Sicherung ist beschädigt: Ihre Profile können nicht gelesen werden.';

  @override
  String get thisFileIs =>
      'Diese Datei ist zu groß für eine Nightingale-TV-Sicherung.';

  @override
  String get thisBackupWas =>
      'Diese Sicherung wurde mit einer neueren Version von Nightingale TV erstellt.';

  @override
  String get thisFileIsnt =>
      'Diese Datei ist keine Nightingale-TV-Sicherung oder sie ist beschädigt.';

  @override
  String restoredTheBackup(Object toLocal) {
    return 'Sicherung vom $toLocal wiederhergestellt.';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'Sicherung konnte nicht wiederhergestellt werden: $e';
  }

  @override
  String couldntSaveA(Object e) {
    return 'Es konnte zuvor keine Sicherung gespeichert werden: $e';
  }

  @override
  String get madeByYou => 'Von dir erstellt';

  @override
  String get fromNightingaleTv => 'Von Nightingale TV (eigener Build)';

  @override
  String get fromNightingaleTv2 => 'Von Nightingale TV';

  @override
  String get movingToNightingale => 'Umzug zu Nightingale TV (eigener Build)';

  @override
  String get movingToNightingaleTv => 'Umzug zu Nightingale TV';

  @override
  String get fromAFile => 'Aus einer Datei';

  @override
  String get beforeLineupCleanup => 'Vor dem Aufräumen der Senderliste';

  @override
  String get beforeUpdate => 'Vor dem Update';

  @override
  String beforeDeleting(Object subject) {
    return 'Vor dem Löschen von $subject';
  }

  @override
  String get beforeDeletingA => 'Vor dem Löschen eines Profils';

  @override
  String get beforeReset => 'Vor dem Zurücksetzen';

  @override
  String get beforeRestore => 'Vor dem Wiederherstellen';

  @override
  String get automatic => 'Automatisch';

  @override
  String get nc1718 => 'NC-17 / 18 und höher';

  @override
  String get tvMaR => 'TV-MA / R und höher';

  @override
  String get tv14Pg => 'TV-14 / PG-13 und höher';

  @override
  String get off => 'Aus';

  @override
  String get nowAndThen => 'Ab und zu';

  @override
  String get always => 'Immer';

  @override
  String get truncate => 'Abschneiden';

  @override
  String get offlineImage => 'Offline-Bild';

  @override
  String get filler => 'Füllmaterial';

  @override
  String get leastWatchedFirst => 'Am wenigsten Gesehenes zuerst';

  @override
  String get shuffled => 'Zufällig';

  @override
  String get inOrderShows => 'Der Reihe nach (Serien wechseln sich ab)';

  @override
  String get channelsWhereEverything =>
      'Sender, bei denen alles, auch Blöcke, die Freigabe TV-Y, TV-Y7, TV-G oder G hat.';

  @override
  String get musicVideoAnd => 'Musikvideo- und Radiosender.';

  @override
  String get channelsThatPlay =>
      'Sender, die Filme und keine Folgen oder Musik spielen.';

  @override
  String get channelsFromYour => 'Sender aus deinen Live-TV-Quellen.';

  @override
  String get channelsYouMarked => 'Sender, die du als Favoriten markiert hast.';

  @override
  String get everyChannel => 'Jeder Sender.';

  @override
  String get kids => 'Kinder';

  @override
  String get movies => 'Filme';

  @override
  String get liveTv2 => 'Live-TV';

  @override
  String get favorites => 'Favoriten';

  @override
  String get all => 'Alle';

  @override
  String get theAccentsAre =>
      'Die Akzente sind ein Design und jeweils „theme“ oder „channel“.';

  @override
  String get thoseArentRetro => 'Das sind keine Retro-Einstellungen.';

  @override
  String get theOverlayTheme =>
      'Das Overlay-Design ist standard, vcr, cableBox oder stationIdent.';

  @override
  String get theCrtEffect =>
      'Der CRT-Effekt ist off, softTube, livingRoom, arcade, studioMonitor oder custom.';

  @override
  String get theSurroundImage => 'Das Umgebungsbild ist ein Dateiname.';

  @override
  String get theSurroundIs =>
      'Die Umgebung ist black, charcoal, channel oder image.';

  @override
  String get thePictureShape => 'Die Bildform ist original, fill43 oder fit43.';

  @override
  String get channelColor => 'Senderfarbe';

  @override
  String get theme => 'Design';

  @override
  String get stationIdent => 'Senderkennung';

  @override
  String get cableBox => 'Kabelbox';

  @override
  String get vcr => 'Videorekorder';

  @override
  String get standard => 'Standard';

  @override
  String get custom => 'Eigene';

  @override
  String get studioMonitor => 'Studiomonitor';

  @override
  String get arcade => 'Spielhalle';

  @override
  String get livingRoom => 'Wohnzimmer';

  @override
  String get softTube => 'Weiche Röhre';

  @override
  String get customColorIs =>
      'Die eigene Farbe ist natural, warm, faded oder vivid.';

  @override
  String get customLinesIs => 'Die eigenen Zeilen sind 240 oder 480.';

  @override
  String customIsOff(Object key) {
    return 'Eigenes $key ist off, low, medium oder high.';
  }

  @override
  String get thatIsntA => 'Das ist kein eigener Stil.';

  @override
  String get vivid => 'Lebendig';

  @override
  String get faded => 'Verblasst';

  @override
  String get warm => 'Warm';

  @override
  String get natural => 'Natürlich';

  @override
  String get high => 'Hoch';

  @override
  String get medium => 'Mittel';

  @override
  String get low => 'Niedrig';

  @override
  String get image => 'Bild';

  @override
  String get charcoal => 'Anthrazit';

  @override
  String get black => 'Schwarz';

  @override
  String get n43Fit => '4:3 einpassen';

  @override
  String get n43Fill => '4:3 füllen';

  @override
  String get original => 'Original';

  @override
  String get thisChannelIs => 'Dieser Sender ist nicht auf Sendung';

  @override
  String get offAir => 'Sendepause';

  @override
  String get tail => 'Auffüller';

  @override
  String get postRoll => 'Post-Roll';

  @override
  String get midRoll => 'Mid-Roll';

  @override
  String get preRoll => 'Pre-Roll';

  @override
  String get commercials => 'Werbung';

  @override
  String get bumpers => 'Bumper';

  @override
  String get pleaseStandBy => 'BITTE WARTEN';

  @override
  String get offTheAir => 'SENDEPAUSE';

  @override
  String get wellBeRight => 'Wir sind gleich zurück';

  @override
  String upNextAt(Object at) {
    return 'Als Nächstes um $at';
  }

  @override
  String backOnThe(Object next, Object title) {
    return 'Wieder auf Sendung $next mit $title';
  }

  @override
  String get processor => 'Prozessor';

  @override
  String get graphicsCardNvenc => 'Grafikkarte (NVENC)';

  @override
  String get graphicsCardVaapi => 'Grafikkarte (VAAPI)';

  @override
  String get signInTo =>
      'Melde dieses Profil am Fernseher an, um seine Sender zu exportieren.';

  @override
  String get signInToThis =>
      'Melde dieses Profil hier an, um seine Sender zu exportieren.';

  @override
  String portIsIn(Object port) {
    return 'Port $port wird von einem anderen Programm verwendet. Wähle einen anderen Port und ändere ihn dann in Plex oder Jellyfin.';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'Ein anderes Profil verwendet bereits Port $port.';
  }

  @override
  String get pickAPort => 'Wähle einen Port zwischen 1024 und 65535.';

  @override
  String get movie => 'Film';

  @override
  String backOnTheAir(Object start, Object title) {
    return 'Wieder auf Sendung $start mit $title.';
  }

  @override
  String get images => 'Bilder';

  @override
  String get couldNotRead =>
      'Das Bild konnte nicht gelesen werden. Versuche PNG, JPG, WebP oder SVG.';

  @override
  String get thatFileIs => 'Diese Datei ist kein gültiges SVG.';

  @override
  String get thatImageIs =>
      'Das Bild ist größer als 20 MB. Bitte wähle ein kleineres.';

  @override
  String get other => 'Sonstiges';

  @override
  String get seasonsHolidays => 'Jahreszeiten und Feiertage';

  @override
  String get newsWeather => 'Nachrichten und Wetter';

  @override
  String get sports => 'Sport';

  @override
  String get genres => 'Genres';

  @override
  String get kidsFamily => 'Kinder und Familie';

  @override
  String get tvMovies => 'TV und Filme';

  @override
  String get theServerWould =>
      'Der Server konnte diesen Titel nicht umwandeln.';

  @override
  String get theServerHas =>
      'Der Server hat keine abspielbare Version dieses Titels.';

  @override
  String get externalLabel => 'Extern';

  @override
  String get scanningChannelSources => 'Senderquellen werden durchsucht…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl hat nicht wie ein Jellyfin-Server geantwortet.';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return 'Kein Jellyfin-Server unter $serverUrl gefunden. $message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return 'Serverfehler $statusCode bei $path.';
  }

  @override
  String get wrongUsernameOr =>
      'Falscher Benutzername oder falsches Passwort, oder die Sitzung ist abgelaufen.';

  @override
  String couldNotReach(Object e) {
    return 'Der Server war nicht erreichbar ($e).';
  }

  @override
  String get theServerTook => 'Der Server hat zu lange nicht geantwortet.';

  @override
  String get theServerWouldNot =>
      'Der Server konnte diesen Sender nicht umwandeln.';

  @override
  String get musicVideo => 'Musikvideo';

  @override
  String movie2(Object year) {
    return 'Film · $year';
  }

  @override
  String get commercial => 'Werbung';

  @override
  String couldntReachThe(Object what) {
    return '$what: nicht erreichbar';
  }

  @override
  String theIsToo(Object what) {
    return '$what: zu groß';
  }

  @override
  String theSAddress(Object what) {
    return '$what: Die Adresse ist keine Webadresse';
  }

  @override
  String get noGuideInformation => 'Keine Programminformationen';

  @override
  String get serverLiveTv => 'Live-TV des Servers';

  @override
  String get theChannelHas => 'Der Sender hat keine Streamadresse.';

  @override
  String get couldntReadThe => 'Der Guide konnte nicht gelesen werden';

  @override
  String get couldntReachTheGuide => 'Der Guide war nicht erreichbar';

  @override
  String get theSourceHas => 'Die Quelle hat keine Wiedergabeliste';

  @override
  String get couldntReachThePlaylist =>
      'Die Wiedergabeliste war nicht erreichbar';

  @override
  String get couldntReadThePlaylist =>
      'Die Wiedergabelisten-Datei konnte nicht gelesen werden';

  @override
  String couldntRefresh(Object name) {
    return '$name konnte nicht aktualisiert werden';
  }

  @override
  String get thePlaylistHas => 'Die Wiedergabeliste hat keine Sender';

  @override
  String get thatIsntAn => 'Das ist keine M3U-Wiedergabeliste';

  @override
  String get thatIsntAnXmltv => 'Das ist kein XMLTV-Guide';

  @override
  String get theGuideIs => 'Der Guide ist zu groß (über 1 GB)';

  @override
  String get nightingaleTvBackups => 'Nightingale-TV-Sicherungen';

  @override
  String get uninstallingThisApp =>
      'Beim Deinstallieren dieser App werden ihre Profile, Sender und Einstellungen gelöscht, sofern du sie nicht vorher sicherst oder umziehst.';

  @override
  String theStoreVersion(Object officialName) {
    return 'Die Store-Version wird als eigene App „$officialName“ mit eigener Einrichtung neben dieser installiert. Mit dem Kauf unterstützt du das Projekt. Sobald sie installiert ist, kannst du deine Einrichtung von hier aus dorthin umziehen.';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Updates von Google Play und offizielle Nightingale-TV-APKs werden über diese App installiert und behalten deine Einrichtung. Ein eigener Build wird als separate App „$ownBuildName“ installiert, und du kannst deine Einrichtung von hier aus dorthin umziehen.';
  }

  @override
  String get yourOwnBuild => 'Dein eigener Build';

  @override
  String get officialNightingaleTv => 'Offizielle Nightingale-TV-APK';

  @override
  String get installedFromGoogle => 'Von Google Play installiert';

  @override
  String get nightingaleTvOwn => 'Nightingale TV (eigener Build)';

  @override
  String get sleepTimerOff => 'Sleep-Timer aus';

  @override
  String get sleepAtEnd => 'Schlafen am Ende der Sendung';

  @override
  String sleepInMin(Object minutes) {
    return 'Schlafen in $minutes Min.';
  }

  @override
  String get forced => 'Erzwungen';

  @override
  String get unknownLanguage => 'Unbekannte Sprache';

  @override
  String didntStart(Object name) {
    return '$name ist nicht gestartet';
  }

  @override
  String get thisDeviceCant =>
      'Dieses Gerät kann das Video dieses Senders nicht abspielen';

  @override
  String get thisChannelsStream =>
      'Der Streamtyp dieses Senders wird auf diesem Gerät nicht unterstützt';

  @override
  String refusedTheStream(Object name) {
    return '$name hat den Stream abgelehnt. Er läuft vielleicht auf einem anderen Gerät.';
  }

  @override
  String yourAccountCant(Object server) {
    return 'Dein $server-Konto kann diesen Sender nicht ansehen';
  }

  @override
  String cantReach(Object name) {
    return '$name nicht erreichbar';
  }

  @override
  String allOfS(Object server) {
    return 'Alle Tuner von $server sind belegt';
  }

  @override
  String lostTheSignal(Object name) {
    return 'Signal von $name verloren';
  }

  @override
  String get couldntPlayThat =>
      'Dieser Teil konnte nicht abgespielt werden. Zurück zu live';

  @override
  String get backToLive => 'Zurück zu live';

  @override
  String get theServerTookToo =>
      'Der Server hat zu lange gebraucht, um mit der Umwandlung dieser Sendung zu beginnen.';

  @override
  String get nothingToPlay => 'Auf diesem Sender gibt es nichts abzuspielen';

  @override
  String captionsOn(Object shown) {
    return 'Untertitel an: $shown';
  }

  @override
  String get captionsOn2 => 'Untertitel an';

  @override
  String get captionsOnNo =>
      'Untertitel an: Keine Untertitel für diese Sendung';

  @override
  String get captionsOff => 'Untertitel aus';

  @override
  String get guest => 'Gast';

  @override
  String get thereHasTo =>
      'Es muss mindestens ein Profil für Erwachsene geben.';

  @override
  String get switchToAnother =>
      'Wechsle zu einem anderen Profil, bevor du dieses löschst.';

  @override
  String get me => 'Ich';

  @override
  String get couldntOpenA =>
      'Für die Fernbedienung konnte kein Netzwerkport geöffnet werden.';

  @override
  String get notPaired => 'Nicht gekoppelt';

  @override
  String get phone => 'Handy';

  @override
  String get thatCodeDoesnt =>
      'Der Code stimmt nicht. Prüfe den Code auf dem Fernseher.';

  @override
  String get openMenuPhone =>
      'Öffne am Fernseher Menü → Handy-Fernbedienung, um zu koppeln';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'Dein $serverName-Konto kann kein Live-TV ansehen';
  }

  @override
  String get enterYourServer => 'Gib deine Serveradresse ein.';

  @override
  String get needsSignIn => 'Anmeldung nötig';

  @override
  String get cantBeReached => 'Nicht erreichbar';

  @override
  String isNotAnswering(Object name) {
    return '$name antwortet unter keiner seiner Adressen. Ist er eingeschaltet?';
  }

  @override
  String get everyServerOn =>
      'Jeder Server dieses Plex-Kontos ist bereits in diesem Profil.';

  @override
  String get thisPlexAccount =>
      'Dieses Plex-Konto hat keine Server. Bitte den Besitzer des Servers, ihn mit dir zu teilen.';

  @override
  String quickConnectStopped(Object message) {
    return 'Quick Connect wurde beendet: $message';
  }

  @override
  String get enterYourUsername => 'Gib deinen Benutzernamen ein.';

  @override
  String get plexDidNot => 'Plex hat den Benutzer nicht gewechselt.';

  @override
  String plexTvError(Object statusCode) {
    return 'plex.tv-Fehler $statusCode.';
  }

  @override
  String get yourPlexSign => 'Deine Plex-Anmeldung ist abgelaufen.';

  @override
  String couldNotReachPlex(Object e) {
    return 'plex.tv war nicht erreichbar ($e).';
  }

  @override
  String get plexTvTook => 'plex.tv hat zu lange nicht geantwortet.';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — Geteilt von $ownerName';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'Der Server konnte diesen Titel nicht umwandeln ($transcodeDecisionText).';
  }

  @override
  String get theServerHasNo =>
      'Der Server hat keine Datei für diesen Titel. Aktualisiere die Mediathek.';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl hat nicht wie ein Plex-Server geantwortet.';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return 'Kein Plex-Server unter $serverUrl gefunden. $message';
  }

  @override
  String get thePlexSign => 'Die Plex-Anmeldung ist abgelaufen.';

  @override
  String channelIsNot(Object channelId) {
    return 'Sender $channelId ist auf keinem DVR.';
  }

  @override
  String get noSuchUser => 'Kein solcher Benutzer.';

  @override
  String get yourCurrentPassword => 'Dein aktuelles Passwort ist falsch.';

  @override
  String get signInFirst => 'Melde dich zuerst an.';

  @override
  String thereIsAlready(Object name) {
    return 'Es gibt bereits einen Benutzer namens $name.';
  }

  @override
  String get thisAccountIs => 'Dieses Konto ist deaktiviert.';

  @override
  String get chooseAnAdmin => 'Wähle ein Admin-Konto.';

  @override
  String useAtMost(Object maxNameLength) {
    return 'Verwende höchstens $maxNameLength Zeichen für den Benutzernamen.';
  }

  @override
  String get enterAUser => 'Gib einen Benutzernamen ein.';

  @override
  String useAtLeast(Object minPasswordLength) {
    return 'Verwende mindestens $minPasswordLength Zeichen.';
  }

  @override
  String get tooManyWrong =>
      'Zu viele falsche Passwörter. Versuche es in einer Minute erneut.';

  @override
  String get wrongUserName => 'Falscher Benutzername oder falsches Passwort.';

  @override
  String get openTheSetup =>
      'Öffne den Einrichtungslink aus dem Serverprotokoll.';

  @override
  String get makeSomeoneElse => 'Mache zuerst jemand anderen zum Admin.';

  @override
  String get noSuchProfile => 'Kein solches Profil.';

  @override
  String get onlyAnAdmin => 'Das kann nur ein Admin.';

  @override
  String get thatProfileIsnt => 'Dieses Profil ist dir nicht zugewiesen.';

  @override
  String get enterAGrown =>
      'Gib die PIN eines Erwachsenen ein, um die Einstellungen eines Kinderprofils zu ändern.';

  @override
  String get enterThisProfiles => 'Gib die PIN dieses Profils ein.';

  @override
  String get reloadThePage => 'Lade die Seite neu und versuche es noch einmal.';

  @override
  String somethingWentWrong(Object e) {
    return 'Etwas ist schiefgegangen: $e';
  }

  @override
  String get signInToThisProfile => 'Melde dich zuerst bei diesem Profil an.';

  @override
  String get changedInAnother =>
      'In einem anderen Fenster geändert. Der neueste Stand wird angezeigt.';

  @override
  String get wrongPin => 'Falsche PIN.';

  @override
  String get tooManyWrongPins =>
      'Zu viele falsche PINs. Versuche es in einer Minute erneut.';

  @override
  String get theRoleIs => 'Die Rolle ist „admin“ oder „user“.';

  @override
  String get noSuchBackup => 'Keine solche Sicherung.';

  @override
  String get backupsAreOff => 'Sicherungen sind aus.';

  @override
  String get noSuchEncoder => 'Kein solcher Encoder.';

  @override
  String get allow1To => 'Erlaube 1 bis 16 Streams.';

  @override
  String get noSuchQuality => 'Keine solche Qualität.';

  @override
  String get processorOnly => 'Nur Prozessor';

  @override
  String get liveTvExport => 'Der Live-TV-Export läuft nicht.';

  @override
  String get thoseArentPremiere => 'Das sind keine Premieren-Einstellungen.';

  @override
  String get theLogoMode => 'Der Logo-Modus ist always, nowAndThen oder off.';

  @override
  String get thatIsntAPicture =>
      'Das ist kein Bild im Ordner für eigene Logos.';

  @override
  String couldntSaveASafety(Object e) {
    return 'Es konnte zuvor keine Sicherheitskopie gespeichert werden, daher wurde nichts zurückgesetzt: $e';
  }

  @override
  String get theKindIs => 'Die Art ist „block“, „music“ oder „custom“.';

  @override
  String get thatIsntAPlay => 'Das ist keine Wiedergabereihenfolge.';

  @override
  String get musicChannelsOnly => 'Musiksender spielen nur zufällig.';

  @override
  String get channelNumbersStart => 'Sendernummern beginnen bei 1.';

  @override
  String get slotLengthsAre =>
      'Sendeplätze dauern 15, 30, 60, 90 oder 120 Minuten.';

  @override
  String get thatIsntAChannel => 'Das ist kein Sender.';

  @override
  String get noSuchChannel => 'Kein solcher Sender.';

  @override
  String get thatPictureIs => 'Das Bild ist zu groß (höchstens 5 MB).';

  @override
  String get unknownAction => 'Unbekannte Aktion.';

  @override
  String get noSuchServer => 'Kein solcher Server.';

  @override
  String get startSigningIn => 'Starte zuerst die Anmeldung.';

  @override
  String get aRestoreIs => 'Es läuft bereits eine Wiederherstellung.';

  @override
  String get uploadTheBackup => 'Lade die Sicherung erneut hoch.';

  @override
  String get discoveryIsOff =>
      'Die Erkennung ist aus, füge den Tuner also über seine Adresse hinzu. Starte den Container mit Host-Netzwerk, um sie einzuschalten.';

  @override
  String get sendKeys => 'Sende „keys“.';

  @override
  String get enterThePlaylists =>
      'Gib die Adresse der Wiedergabeliste ein oder wähle eine Wiedergabelisten-Datei';

  @override
  String get uploadTheFile => 'Lade die Datei erneut hoch.';

  @override
  String get kidProfilesGet => 'Kinderprofile bekommen keine Live-Sender.';

  @override
  String liveTvIsAlready(Object name) {
    return '$name Live-TV ist bereits hinzugefügt';
  }

  @override
  String get noSuchSource => 'Keine solche Quelle.';

  @override
  String get thatFileIsToo => 'Die Datei ist zu groß (höchstens 32 MB).';

  @override
  String get aPinIs => 'Eine PIN hat 4 Ziffern.';

  @override
  String get noSuchRating => 'Keine solche Altersfreigabe.';

  @override
  String get noSuchKind => 'Keine solche Art.';

  @override
  String get onlyAnAdminCan => 'Das kann nur ein Admin ändern.';

  @override
  String shouldBeA(Object key) {
    return '„$key“ sollte eine Textliste sein.';
  }

  @override
  String shouldBeAn(Object key) {
    return '„$key“ sollte ein Objekt sein.';
  }

  @override
  String shouldBeTrue(Object key) {
    return '„$key“ sollte wahr oder falsch sein.';
  }

  @override
  String shouldBeANumber(Object key) {
    return '„$key“ sollte eine Zahl sein.';
  }

  @override
  String shouldBeText(Object key) {
    return '„$key“ sollte Text sein.';
  }

  @override
  String get expectedAJson => 'JSON-Objekt erwartet.';

  @override
  String get thatIsToo => 'Das ist zu viel, um es auf einmal zu senden.';

  @override
  String get aQualityLimit => 'Ein Qualitätslimit beträgt mindestens 500 kbps.';

  @override
  String get orderShouldName => '„order“ sollte jeden Server einmal nennen.';

  @override
  String get orderIsMissing => '„order“ fehlt.';

  @override
  String get signOutOf =>
      'Melde das Profil ab, um seinen Hauptserver zu ändern.';

  @override
  String get thoseArentPool => 'Das sind keine Pool-Ordner.';

  @override
  String get sendRoots => 'Sende „roots“.';

  @override
  String get thatIsntAPool => 'Das ist kein Pool-Typ.';

  @override
  String get giveThePool => 'Gib dem Pool einen Namen.';

  @override
  String get liveChannelsHave => 'Live-Sender haben keine Pausen.';

  @override
  String get sendAPlan => 'Sende einen Plan.';

  @override
  String get thatIsntABreak => 'Das ist kein Pausenplan.';

  @override
  String get noSuchPool => 'Kein solcher Pool.';

  @override
  String get thatIsntAProgramming => 'Das ist kein Programmblock.';

  @override
  String get noSuchBlock => 'Kein solcher Block.';

  @override
  String get sendEveryTab => 'Sende jeden Tab einmal.';

  @override
  String get sendChannelids => 'Sende „channelIds“.';

  @override
  String get giveTheGroup => 'Gib der Gruppe einen Namen.';

  @override
  String get noSuchGroup => 'Keine solche Gruppe.';

  @override
  String get restoringBringsBack =>
      'Beim Wiederherstellen kommen deine Profile, Sender, Blöcke und Einstellungen zurück. Jedes Profil meldet sich einmal bei seinem Server an.';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels Sender',
      one: '$profiles · $channels Sender',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup =>
      'Auf diesem Gerät gibt es eine Sicherung deiner Einrichtung:';

  @override
  String get welcomeBack => 'Willkommen zurück';

  @override
  String get moveOkSelect => '◀▶ Bewegen    OK Auswählen';

  @override
  String get startFresh => 'Neu beginnen';

  @override
  String get restoreIt => 'Wiederherstellen';

  @override
  String get couldntRestore => 'Wiederherstellen fehlgeschlagen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get useYourPhone => 'Handy oder Computer verwenden';

  @override
  String get openABackup => 'Sicherungsdatei öffnen';

  @override
  String get setUpThis =>
      'Richte diesen Fernseher aus einer Nightingale-TV-Sicherung ein: mit deinen Profilen, Sendern, Blöcken und Einstellungen. Jedes Profil meldet sich einmal bei seinem Server an.';

  @override
  String get restoreFromA => 'Aus einer Sicherung wiederherstellen';

  @override
  String get close => 'Schließen';

  @override
  String get thereYouCan =>
      'Dort kannst du eine Sicherung dieses Fernsehers herunterladen oder eine zum Wiederherstellen senden. Alles Gesendete wird zuerst an diesem Fernseher bestätigt. Die Seite schließt sich mit diesem Fenster.';

  @override
  String get onAPhone =>
      'Scanne auf einem Handy, Tablet oder Computer im selben WLAN wie dieser Fernseher den Code oder öffne:';

  @override
  String get couldntOpenANetwork =>
      'Für die Seite konnte kein Netzwerkport geöffnet werden.';

  @override
  String get thePageStopped =>
      'Die Seite wurde nach 15 Minuten ohne Aktivität beendet. Schließe dies und öffne sie erneut.';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount und $last';
  }

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get liveTvExportMoves =>
      'Der Live-TV-Export zieht auf dieses Gerät um. Schalte ihn auf dem alten aus.';

  @override
  String willNeedTo(Object need) {
    return '$need muss sich erneut beim Server anmelden.';
  }

  @override
  String get itSetsUp =>
      'Dieser Fernseher wird so eingerichtet, wie es in der Sicherung steht.';

  @override
  String get itReplacesEverything =>
      'Alles auf diesem Fernseher wird ersetzt. Deine aktuelle Einrichtung wird zuerst gesichert.';

  @override
  String restoreTheBackup(Object toLocal) {
    return 'Sicherung vom $toLocal wiederherstellen?';
  }

  @override
  String get delete => 'Löschen';

  @override
  String get saveToFile => 'In Datei speichern';

  @override
  String madeOn(Object device) {
    return 'Erstellt auf $device';
  }

  @override
  String get moveOkSelectEsc => '▲▼◀▶ Bewegen    OK Auswählen    ESC Zurück';

  @override
  String get backupRestore => 'Sichern und wiederherstellen';

  @override
  String get backups => 'SICHERUNGEN';

  @override
  String get backUpNow => 'Jetzt sichern';

  @override
  String get aBackupHolds =>
      'Eine Sicherung enthält jedes Profil mit seinen Sendern, Blöcken, Werbungen und Einstellungen und wird an jedem Tag erstellt, an dem sich etwas ändert. Anmeldepasswörter sind nie enthalten.';

  @override
  String lastBackup(Object toLocal, Object kindLabel) {
    return 'Letzte Sicherung: $toLocal ($kindLabel).';
  }

  @override
  String get noBackupsYet => 'Noch keine Sicherungen.';

  @override
  String itCantBe(Object toLocal, Object kindLabel) {
    return '$toLocal · $kindLabel. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteThisBackup => 'Diese Sicherung löschen?';

  @override
  String couldntSaveThe(Object e) {
    return 'Die Sicherung konnte nicht gespeichert werden: $e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'Das hat nicht geklappt: $e';
  }

  @override
  String get aNewChannel =>
      'Ein neuer Sender ist außerhalb des Blocks nicht auf Sendung, wie ein Sender, der nachts abschaltet.';

  @override
  String get aNewChannelJust => 'Ein neuer Sender nur für diesen Block';

  @override
  String get moveOkChoose => '▲▼ Bewegen    OK Wählen    ESC Zurück';

  @override
  String get chooseAChannel2 => 'Sender wählen';

  @override
  String episodes(Object keyCount) {
    return 'Folgen: $keyCount';
  }

  @override
  String get moveOkAdd => '▲▼ Bewegen    OK Hinzufügen    ESC Zurück';

  @override
  String get addAShow2 => 'Serie hinzufügen';

  @override
  String get remove => 'Entfernen';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Folgen',
      one: '$count Folge',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ Monat';

  @override
  String get day => '+ Tag';

  @override
  String get day2 => '− Tag';

  @override
  String get month2 => '− Monat';

  @override
  String get save => 'Speichern';

  @override
  String get everyDay => 'Jeden Tag';

  @override
  String get weekends => 'Wochenenden';

  @override
  String get weekdays => 'Werktage';

  @override
  String get days => 'TAGE';

  @override
  String get starts => 'Beginn';

  @override
  String get time => 'ZEIT';

  @override
  String get premieresAreOff => 'Premieren sind aus';

  @override
  String get premieresAreOn => 'Premieren sind an';

  @override
  String get onTheAir => 'AUF SENDUNG';

  @override
  String get episodesAddedTo =>
      'Folgen, die in den letzten zwei Wochen zu deinem Server hinzugekommen sind, haben auf dem Sender ihrer Serie Premiere in einem nächtlichen Sendeplatz: eine neue Folge pro Serie und Nacht, bis zu zwei Stunden lang, mit NEU markiert. Programmblöcke haben Vorrang.';

  @override
  String get moveOkSelectEscCancel =>
      '▲▼◀▶ Bewegen    OK Auswählen    ESC Abbrechen';

  @override
  String get newEpisodePremieres => 'Premieren neuer Folgen';

  @override
  String get theChannelGoes =>
      'Der Sender kehrt zu diesen Zeiten zu seinem normalen Programm zurück.';

  @override
  String delete2(Object title) {
    return '„$title“ löschen?';
  }

  @override
  String get addAnotherShow => 'Weitere Serie hinzufügen';

  @override
  String get missingShow => 'Serie fehlt';

  @override
  String runsThenStarts(Object start) {
    return 'Läuft $start, dann von vorn.';
  }

  @override
  String get fillsTheBlock => 'Füllt den Block.';

  @override
  String longerThanThe(Object end, Object title) {
    return 'Länger als der Block: Er endet um $end und schneidet $title ab.';
  }

  @override
  String get onTheAirNow => 'JETZT AUF SENDUNG';

  @override
  String nextAiring(Object start) {
    return 'NÄCHSTE AUSSTRAHLUNG · $start';
  }

  @override
  String inAll(Object runtime) {
    return 'Insgesamt $runtime';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies Filme',
      one: '$movies Film',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount Serien',
      one: '$showsCount Serie',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => 'Noch nichts. Wähle Serien oder Filme.';

  @override
  String get nothingYetAdd => 'Noch nichts. Füge Serien zur Abfolge hinzu.';

  @override
  String get plays => 'SPIELT';

  @override
  String onLabel(Object number, Object name) {
    return 'Auf $number $name';
  }

  @override
  String get noChannelChosen => 'Kein Sender gewählt';

  @override
  String get onANew =>
      'Auf einem neuen Sender (zu anderen Zeiten nicht auf Sendung)';

  @override
  String get untitledBlock => 'Unbenannter Block';

  @override
  String get deleteBlock => 'Block löschen';

  @override
  String get blockIsOff => 'Block ist aus';

  @override
  String get blockIsOn => 'Block ist an';

  @override
  String get onlyShowsAnd =>
      'Nur Serien und Filme mit dieser oder einer höheren Freigabe. Titel ohne Freigabe werden ausgelassen.';

  @override
  String get anyRating => 'Jede Freigabe';

  @override
  String get minimumRating => 'Mindestfreigabe';

  @override
  String get chooseShowsMovies => 'Serien und Filme wählen';

  @override
  String get showsAndMovies =>
      'Serien und Filme deiner Wahl, der Reihe nach oder zufällig.';

  @override
  String get yourShowsIn =>
      'Deine Serien in dieser Reihenfolge, jede spielt bei jeder Ausstrahlung ihre nächste Folge. Bleibt Zeit übrig, beginnt die Abfolge von vorn.';

  @override
  String get aLineup => 'Eine Abfolge';

  @override
  String get aMix => 'Eine Mischung';

  @override
  String get whatItPlays => 'WAS GESPIELT WIRD';

  @override
  String get repeatsEveryYear => 'Wiederholt sich jedes Jahr.';

  @override
  String get to => 'Bis';

  @override
  String get from => 'Von';

  @override
  String get onlyBetweenDates => 'Nur zwischen zwei Daten';

  @override
  String get allYear => 'Ganzjährig';

  @override
  String get dates => 'DATEN';

  @override
  String get nextDay => ' (Folgetag)';

  @override
  String get ends => 'Ende';

  @override
  String get channel => 'SENDER';

  @override
  String get saturdayMorningCartoons => 'Samstagmorgen-Cartoons';

  @override
  String get title => 'Titel';

  @override
  String get newProgrammingBlock => 'Neuer Programmblock';

  @override
  String get newLateNight => 'Neuer Late-Night-Block';

  @override
  String get editProgrammingBlock => 'Programmblock bearbeiten';

  @override
  String next(Object next, Object next2) {
    return 'Nächste: $next $next2';
  }

  @override
  String get onTheAirNow2 => 'Gerade auf Sendung';

  @override
  String get noUpcomingAirings => 'Keine anstehenden Ausstrahlungen';

  @override
  String get itsChannelIs =>
      'Sein Sender existiert nicht mehr. Wähle einen neuen.';

  @override
  String get turnedOff => 'Ausgeschaltet';

  @override
  String get blocksTakeOver =>
      'Blöcke übernehmen einen Sender an den Tagen und zu den Zeiten deiner Wahl, wie Cartoons am Samstagmorgen. Jede Ausstrahlung macht dort weiter, wo die letzte aufgehört hat.';

  @override
  String get moveOkEdit => '▲▼ Bewegen    OK Bearbeiten    ESC Zurück';

  @override
  String get programmingBlocks => 'Programmblöcke';

  @override
  String get newlyAddedEpisodes =>
      'Neu hinzugefügte Folgen, auf dem Sender ihrer Serie';

  @override
  String get onLabel2 => 'An';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips Clips',
      one: '$name  ·  $clips Clip',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => 'Sitcom, 22 Min.';

  @override
  String get n44MinDrama => 'Drama, 44 Min.';

  @override
  String get n22MinSitcom => 'Film, 100 Min.';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: ', $midCount Pausen darin',
      one: ', $midCount Pause darin',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name: keine Pausen';
  }

  @override
  String get openAndClose =>
      'Eröffnen und beenden Pausen, aus Pools vom Typ Bumper';

  @override
  String get bumpers2 => 'BUMPER';

  @override
  String get toTheHalf => 'Auf die halbe Stunde';

  @override
  String get toTheHour => 'Auf die volle Stunde';

  @override
  String get padsEachSlot =>
      'Füllt jeden Sendeplatz bis zur vollen Zeit auf, damit Sendungen pünktlich beginnen';

  @override
  String get tail2 => 'AUFFÜLLER';

  @override
  String get afterEachProgram => 'Nach jeder Sendung';

  @override
  String get postRoll2 => 'POST-ROLL';

  @override
  String get length => 'Länge';

  @override
  String get every => 'Alle';

  @override
  String min(Object inMinutes) {
    return '$inMinutes Min.';
  }

  @override
  String get breaksInsideShows =>
      'Pausen in Serien und Filmen, an Aktschlüssen, wenn sie sich finden lassen';

  @override
  String get midRoll2 => 'MID-ROLL';

  @override
  String get beforeEachProgram => 'Vor jeder Sendung';

  @override
  String get preRoll2 => 'PRE-ROLL';

  @override
  String get onePool => 'Ein Pool…';

  @override
  String get allBumperPools => 'Alle Bumper-Pools';

  @override
  String get none => 'Keine';

  @override
  String clipsFrom(Object pool) {
    return 'Clips aus: $pool';
  }

  @override
  String get allPools => 'Alle Pools';

  @override
  String clips2(Object label) {
    return '$label-Clips';
  }

  @override
  String get leave => 'Verlassen';

  @override
  String get yourChangesTo =>
      'Deine Änderungen an den Pausen-Einstellungen gehen verloren.';

  @override
  String get leaveWithoutSaving => 'Ohne Speichern verlassen?';

  @override
  String get size => 'Größe';

  @override
  String get captions => 'Untertitel';

  @override
  String get sampleCaption => 'Beispiel-Untertitel';

  @override
  String get theServerDraws =>
      'Der Server zeichnet diese Untertitel ins Bild, daher lässt sich ihre Größe hier nicht ändern.';

  @override
  String get findingSubtitles => 'Untertitel werden gesucht…';

  @override
  String get noSubtitlesFor => 'Keine Untertitel für diese Sendung';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours Std. $inMinutes Min.';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed Tage';
  }

  @override
  String get theChannelGoesAway =>
      'Der Sender verschwindet mit seinen Programmblöcken und seinen Plätzen in Sendergruppen.';

  @override
  String remove2(Object name) {
    return '„$name“ entfernen?';
  }

  @override
  String contentOf(Object name) {
    return 'Inhalt von $name';
  }

  @override
  String get newChannel => 'Neuer Sender';

  @override
  String get defaultCard => 'Standardkarte';

  @override
  String get changeOfflineImage => 'Offline-Bild ändern…';

  @override
  String get offlineImage2 => 'Offline-Bild…';

  @override
  String fillerPool(Object poolName) {
    return 'Füll-Pool: $poolName';
  }

  @override
  String get slotLength => 'SENDEPLATZLÄNGE';

  @override
  String get hideFromGuide => 'Im TV-Guide ausblenden';

  @override
  String get showInGuide => 'Im TV-Guide anzeigen';

  @override
  String get favorite => 'Favorit';

  @override
  String get unfavorite => 'Kein Favorit mehr';

  @override
  String mainSetting(Object label) {
    return 'Haupteinstellung ($label)';
  }

  @override
  String get channelLogo => 'SENDERLOGO';

  @override
  String breaksOn(Object name) {
    return 'Pausen auf $name';
  }

  @override
  String get custom2 => 'Eigene…';

  @override
  String get commercials2 => 'WERBUNG';

  @override
  String get removeChannel => 'Sender entfernen';

  @override
  String get reshuffle => 'Neu mischen';

  @override
  String get editContent => 'Inhalt bearbeiten';

  @override
  String get number => 'Nummer +';

  @override
  String get number2 => 'Nummer −';

  @override
  String get sourcesLogo => 'Logo der Quelle';

  @override
  String get changeIcon => 'Symbol ändern';

  @override
  String get rename => 'Umbenennen';

  @override
  String get channelName => 'Sendername';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount Programmblöcke',
      one: '$blockCount Programmblock',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return 'wiederholt sich alle $loop';
  }

  @override
  String programs(Object playlistCount) {
    return 'Sendungen: $playlistCount';
  }

  @override
  String get programmingBlocksOnly => 'Nur Programmblöcke';

  @override
  String channelThere(Object n) {
    return 'Sender $n dort';
  }

  @override
  String channel2(Object number) {
    return 'SENDER $number';
  }

  @override
  String get noChannelsYet => 'Noch keine Sender';

  @override
  String get guideRange => 'GUIDE-ZEITRAUM';

  @override
  String get channelsEditOk =>
      '▲▼ Sender    ▶ Bearbeiten    OK Auswählen    ESC Zurück';

  @override
  String get channelsIcons => 'Sender und Symbole';

  @override
  String get howFarAhead => 'Wie weit der TV-Guide ab jetzt vorausschaut.';

  @override
  String hours(Object hours) {
    return '$hours Stunden';
  }

  @override
  String get theChannelLogo =>
      'Das Senderlogo in der Bildecke, am Fernseher und im Live-TV-Export.';

  @override
  String get name => 'Name';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'SENDER';

  @override
  String get groupName => 'Gruppenname';

  @override
  String group(Object name) {
    return 'Gruppe: $name';
  }

  @override
  String get deleteGroup => 'Gruppe löschen';

  @override
  String get itsTabLeaves =>
      'Der Tab verschwindet aus dem TV-Guide. Die Sender bleiben in deiner Senderliste.';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount Sender',
      one: '$membersCount Sender',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => 'Von dir ausgewählte Sender.';

  @override
  String get theTabsAt =>
      'Die Tabs oben im TV-Guide, in dieser Reihenfolge. Ausgeblendete Tabs und Tabs ohne Sender werden nicht angezeigt.';

  @override
  String get channelGroups => 'Sendergruppen';

  @override
  String get shown => 'Sichtbar';

  @override
  String get down => 'Runter';

  @override
  String get up => 'Hoch';

  @override
  String get automatic2 => '· automatisch';

  @override
  String channels4(Object channelIdsCount) {
    return '· Sender: $channelIdsCount';
  }

  @override
  String get create => 'Erstellen';

  @override
  String get commercialsNeverShow =>
      'Werbung erscheint nie im Wiedergabeverlauf deines Servers.';

  @override
  String get theSameAds => 'Für alle laufen immer dieselben Werbespots.';

  @override
  String get bumperPoolsClips =>
      'Clips aus Bumper-Pools eröffnen und beenden Pausen und laufen nie als Werbung.';

  @override
  String get howBreaksWork => 'SO FUNKTIONIEREN PAUSEN';

  @override
  String get withATail =>
      'Mit einem Auffüller werden Sendeplätze bis zur vollen Zeit aufgefüllt.';

  @override
  String get adsShrinkTo =>
      'Werbung wird an den Sendeplatz angepasst, und keine Pause dauert länger als 5 Minuten.';

  @override
  String get aShortBreak =>
      'Eine kurze Pause vor der Sendung, alle 10 Minuten eine Pause darin (12 bei Filmen), an Aktschlüssen, wenn sie sich finden lassen, und der Rest danach.';

  @override
  String get pickAutomaticFor =>
      'Wähle Automatisch für Pausen wie im Fernsehen oder Eigene, um sie selbst festzulegen.';

  @override
  String workingOn(Object current) {
    return 'Bearbeite $current…';
  }

  @override
  String get analysis => 'ANALYSE';

  @override
  String couldNotBe(Object failed) {
    return '$failed konnten nicht analysiert werden (ein neuer Versuch folgt, wenn sich die Datei ändert)';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'Sendungen mit Pausenpunkten: $programsDone von $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return 'Lange Videos aufgeteilt: $reelsDone von $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders Ordner  ·  $idCount',
      one: '$folders Ordner  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$clips aus $used Werbe-Pools.',
      one: '$clips aus $used Werbe-Pool.',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'Pausen beginnen, sobald ein Pool Clips hat. Füge einem Pool Ordner mit Videos hinzu.';

  @override
  String get breaksStartOnceA =>
      'Pausen beginnen, sobald ein Pool Clips hat. Seine langen Videos werden gerade aufgeteilt.';

  @override
  String get breaksStartOnceAPool =>
      'Pausen beginnen, sobald ein Pool Clips hat. Erstelle unten einen Pool.';

  @override
  String breaksAreOff(Object clips) {
    return 'Pausen sind aus. $clips bereit in deinen Pools.';
  }

  @override
  String get breaksAreOff2 => 'Pausen sind aus.';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Clips',
      one: '$n Clip',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return 'Letzter Scan fehlgeschlagen: $syncError';
  }

  @override
  String get newPool => 'Neuer Pool';

  @override
  String get pickTheFolders =>
      'Wähle die Ordner auf deinem Server, die Werbung und Bumper enthalten. Ihre Videos verlassen deine normalen Sender und füllen stattdessen die Pausen. Stelle den Typ eines Pools auf Bumper, damit seine Clips Pausen eröffnen und beenden.';

  @override
  String get pools => 'POOLS';

  @override
  String get breakSettings => 'Pausen-Einstellungen…';

  @override
  String get commercialBreaks => 'WERBEPAUSEN';

  @override
  String get breakSettings2 => 'Pausen-Einstellungen';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count Auch Pausenpunkte liegen damit natürlicher.';
  }

  @override
  String waiting(Object waiting) {
    return ' ($waiting warten).';
  }

  @override
  String get longCommercialVideos =>
      'Lange Werbevideos ohne Kapitel können auf diesem Gerät nicht aufgeteilt werden';

  @override
  String get installFfmpegTo =>
      'Installiere ffmpeg, um lange Werbevideos aufzuteilen';

  @override
  String get picturesOnThis =>
      'Bilder auf diesem Gerät, neueste zuerst. Große werden auf 512 px verkleinert.';

  @override
  String get noPicturesOn =>
      'Noch keine Bilder auf diesem Gerät. Kopiere ein PNG oder JPG in den Download-Ordner oder auf einen USB-Stick und versuche es erneut.';

  @override
  String get lookingForPictures => 'Bilder werden gesucht…';

  @override
  String get couldntReadThePictures =>
      'Die Bilder auf diesem Gerät konnten nicht gelesen werden.';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV darf die Bilder auf diesem Gerät nicht sehen. Erlaube „Fotos und Videos“ in den Android-Einstellungen › Apps › Nightingale TV › Berechtigungen und versuche es erneut.';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ Bewegen    OK Wählen    ESC Abbrechen';

  @override
  String get chooseAPicture => 'Bild wählen';

  @override
  String thePoolHasnt(Object error) {
    return '$error  Der Pool wurde nicht geändert.';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  Nichts wurde geändert.';
  }

  @override
  String get couldntReachTheServer => 'Der Server war nicht erreichbar';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get nothingInside => 'Nichts darin';

  @override
  String get noMovies => 'Keine Filme';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount darin';
  }

  @override
  String get video => 'Video';

  @override
  String collection(Object name) {
    return '$name (Sammlung)';
  }

  @override
  String get included => 'Enthalten';

  @override
  String get nothingInside2 => 'Nichts darin.';

  @override
  String get loadingFolders => 'Ordner werden geladen…';

  @override
  String get pressOnA =>
      'Drücke ▶ auf einer Mediathek, um ihren Inhalt zu sehen.';

  @override
  String get done => 'Fertig';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount markiert';
  }

  @override
  String get nothingTickedYet =>
      'Noch nichts markiert. Markiere eine Mediathek, um alles zu verwenden, oder drücke ▶, um etwas daraus zu wählen.';

  @override
  String get wholeLibrary => 'Ganze Mediathek';

  @override
  String get libraries => 'MEDIATHEKEN';

  @override
  String get loadingLibraries => 'Mediatheken werden geladen…';

  @override
  String get moveOkTick =>
      '▲▼ Bewegen    OK Markieren    ▶ Öffnen    ◀ Hoch    ESC Abbrechen';

  @override
  String foldersFor(Object poolName) {
    return 'Ordner für $poolName';
  }

  @override
  String get chooseFolders => 'Ordner wählen';

  @override
  String get chooseWhatPlays => 'Wähle, was auf diesem Sender läuft';

  @override
  String get endsEarly => 'Endet früher';

  @override
  String get madeFromThis =>
      'Erstellt aus den Serien und Filmen dieses Senders und mit der Mediathek aktualisiert. Sobald du etwas änderst, gehört er dir.';

  @override
  String get fromTheLineup => 'Aus der Senderliste';

  @override
  String yesterday(Object t) {
    return 'gestern $t';
  }

  @override
  String today(Object t) {
    return 'heute $t';
  }

  @override
  String behind(Object d) {
    return '$d zurück';
  }

  @override
  String hr(Object h) {
    return '$h Std.';
  }

  @override
  String get underAMinute => 'unter einer Minute';

  @override
  String get noProgramming => 'Kein Programm';

  @override
  String get today2 => 'HEUTE';

  @override
  String get tuning => 'WIRD EINGESTELLT…';

  @override
  String get offAir2 => 'SENDEPAUSE';

  @override
  String get noSignal => 'KEIN SIGNAL';

  @override
  String left(Object now) {
    return 'Noch $now';
  }

  @override
  String get nothingScheduled => 'Nichts geplant';

  @override
  String get back => 'Zurück';

  @override
  String get sleep => 'Schlafen';

  @override
  String get menu => 'Menü';

  @override
  String get nightingaleTvGuide => 'NIGHTINGALE TV GUIDE';

  @override
  String nowPlaying(Object title) {
    return 'Läuft gerade: $title';
  }

  @override
  String get mMenu => 'M Menü';

  @override
  String get escBackTo => 'ESC Zurück zum TV';

  @override
  String get channelsTabsTime =>
      '▲▼ Sender     ▲ Tabs     ◀▶ Zeit     OK Ansehen     ';

  @override
  String get color => 'Farbe';

  @override
  String get channelsUsingIt =>
      'Sender, die es verwenden, erhalten wieder ein Standardsymbol.';

  @override
  String get deleteThisIcon => 'Dieses Symbol löschen?';

  @override
  String get uploadImage => 'Bild hochladen…';

  @override
  String get pngJpgWebp =>
      'PNG, JPG, WebP, GIF oder SVG. Große Bilder werden automatisch auf 512 px verkleinert.';

  @override
  String get genericBadgesOnly =>
      'Nur allgemeine Abzeichen. Lade ein echtes Senderlogo unter „Meine Symbole“ hoch.';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'Dieses Abzeichen verwenden';

  @override
  String get preview => 'Vorschau';

  @override
  String get shape => 'Form';

  @override
  String get callLettersUp => 'Kennbuchstaben (bis zu 5)';

  @override
  String iconFor(Object name) {
    return 'Symbol für $name';
  }

  @override
  String get couldntReadThat =>
      'Das Bild konnte nicht gelesen werden. Versuche ein anderes.';

  @override
  String get myIcons => 'Meine Symbole';

  @override
  String get showLogos => 'Serienlogos';

  @override
  String get badges => 'Abzeichen';

  @override
  String get builtIn => 'Integriert';

  @override
  String get couldntMoveThe => 'Die Einrichtung konnte nicht umgezogen werden';

  @override
  String get send => 'Senden';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'Deine Profile, Sender und Einstellungen werden jetzt gesichert und in $counterpartName geöffnet, das vor dem Wiederherstellen nachfragt. Hier ändert sich nichts.';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return 'Deine Einrichtung an $counterpartName senden?';
  }

  @override
  String get parentalControls => 'Kindersicherung';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String bringMySetup(Object counterpartName) {
    return 'Meine Einrichtung von $counterpartName hierher holen';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return 'Meine Einrichtung zu $counterpartName umziehen';
  }

  @override
  String get uninstallingEitherOne =>
      'Wenn du eine der beiden deinstallierst, bevor du die Einrichtung umgezogen hast, die du behalten willst, wird diese gelöscht.';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName und $counterpartName sind getrennte Apps mit jeweils eigenen Profilen, Sendern und Einstellungen.';
  }

  @override
  String get thankYouFor => 'Danke, dass du Nightingale TV unterstützt!';

  @override
  String isAlsoOn(Object counterpartName) {
    return '$counterpartName ist auch auf diesem Gerät';
  }

  @override
  String get aboutThisInstall => 'ÜBER DIESE INSTALLATION';

  @override
  String couldntOpen(Object counterpartName) {
    return '$counterpartName konnte nicht geöffnet werden.';
  }

  @override
  String get nothingIsSet =>
      'Hier ist noch nichts eingerichtet, es gibt also keine Einrichtung zum Umziehen.';

  @override
  String yourSetupIs(Object counterpartName) {
    return 'Deine Einrichtung ist auf dem Weg zu $counterpartName';
  }

  @override
  String get guide => 'TV-GUIDE';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n von $keysCount';
  }

  @override
  String get saving => 'Wird gespeichert…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$_checkedCount von $total gewählt';
  }

  @override
  String get channelOrGroup => 'Sender- oder Gruppenname';

  @override
  String get search => 'Suchen';

  @override
  String get moveOkCheck => '▲▼ Bewegen    OK Markieren    ESC Zurück';

  @override
  String chooseChannels(Object name) {
    return 'Sender wählen: $name';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String get readingThePlaylist => 'Wiedergabeliste wird gelesen…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return 'Aktuell: Guide der Wiedergabeliste, $guideUrl';
  }

  @override
  String get leaveEmptyTo =>
      'Leer lassen, um den in der Wiedergabeliste genannten Guide zu verwenden';

  @override
  String get xmltvGuideAddress => 'XMLTV-Guide-Adresse';

  @override
  String get guideOptional => 'GUIDE (OPTIONAL)';

  @override
  String get httpProviderExample =>
      'http://anbieter.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'Adresse der Wiedergabeliste';

  @override
  String get playlist => 'WIEDERGABELISTE';

  @override
  String get myIptv => 'Mein IPTV';

  @override
  String get useAnAddress => 'Stattdessen eine Adresse verwenden';

  @override
  String get chooseAFile => 'Datei wählen';

  @override
  String get chooseAnotherFile => 'Andere Datei wählen';

  @override
  String get moveOkSelectEscBack => '▲▼ Bewegen    OK Auswählen    ESC Zurück';

  @override
  String edit(Object name) {
    return '$name bearbeiten';
  }

  @override
  String get addAnM3u => 'M3U-Wiedergabeliste hinzufügen';

  @override
  String get m3uPlaylists => 'M3U-Wiedergabelisten';

  @override
  String get xmltvGuides => 'XMLTV-Guides';

  @override
  String get anIptvPlaylist =>
      'Eine IPTV-Wiedergabeliste (Webadresse oder Datei), mit XMLTV-Guide, falls vorhanden.';

  @override
  String get theChannelsAnd =>
      'Die Sender und der Guide des Tuners deines Servers (Antenne, Kabelbox oder IPTV).';

  @override
  String readingSChannels(Object server) {
    return 'Sender von $server werden gelesen…';
  }

  @override
  String checkingLiveTv(Object server) {
    return '$server Live-TV wird geprüft…';
  }

  @override
  String get addALive => 'Live-TV-Quelle hinzufügen';

  @override
  String get itsChannelsLeave =>
      'Seine Sender verschwinden aus dem TV-Guide, ihren Gruppen und Favoriten.';

  @override
  String get renameSource => 'Quelle umbenennen';

  @override
  String get edit2 => 'Bearbeiten';

  @override
  String get refreshNow => 'Jetzt aktualisieren';

  @override
  String get chooseChannels2 => 'Sender wählen';

  @override
  String get playlistFile => 'Wiedergabelisten-Datei';

  @override
  String get notRefreshedYet => 'Noch nicht aktualisiert';

  @override
  String refreshed(Object lastRefresh) {
    return 'Aktualisiert $lastRefresh';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return 'Letzte Aktualisierung fehlgeschlagen: $lastError';
  }

  @override
  String get refreshing => 'Wird aktualisiert…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · Sender: $keyCount von $channelsCount';
  }

  @override
  String get noSourcesYet => 'Noch keine Quellen.';

  @override
  String get addSource => 'Quelle hinzufügen';

  @override
  String get realBroadcastsAnd =>
      'Echte Sendungen und IPTV in deinem TV-Guide: das Live-TV deines Servers oder eine M3U-Wiedergabeliste mit XMLTV-Guide. Ihre Sender kommen nach deinen in die Senderliste.';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return 'Kein Streaming. $runningCount von $streamLimit Streams in Verwendung.';
  }

  @override
  String get savePort => 'Port speichern';

  @override
  String get port => 'Port';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'Tuner';

  @override
  String get enterAPort => 'Gib eine Portnummer ein.';

  @override
  String pinFor(Object name) {
    return 'PIN für $name';
  }

  @override
  String get letPlexFind => 'Plex automatisch suchen lassen';

  @override
  String get discovery => 'ERKENNUNG';

  @override
  String get encoder => 'ENCODER';

  @override
  String nowAtOnce(Object streamLimit) {
    return 'Aktuell: $streamLimit gleichzeitig. Jeder anderswo angesehene Sender ist ein Stream.';
  }

  @override
  String get streamsAtOnce => 'GLEICHZEITIGE STREAMS';

  @override
  String get quality => 'QUALITÄT';

  @override
  String get lineups => 'SENDERLISTEN';

  @override
  String get liveTvExport2 => 'Live-TV-Export';

  @override
  String get automaticDiscoveryIsnt =>
      'Die automatische Erkennung ist auf diesem PC nicht verfügbar. Füge den Tuner in Plex oder Jellyfin über seine Adresse hinzu.';

  @override
  String get anyoneOnYour =>
      'Jeder in deinem Heimnetz kann diese Senderliste ansehen.';

  @override
  String get watchYourChannels =>
      'Sieh deine Sender in Plex, Jellyfin oder jeder IPTV-App in deinem Heimnetz. Nightingale TV muss dafür geöffnet bleiben.';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get added => 'Hinzugefügt';

  @override
  String get chooseAServer => 'Server wählen';

  @override
  String get whosSigningIn => 'Wer meldet sich an?';

  @override
  String get openPlexTv => 'plex.tv/link öffnen';

  @override
  String get waitingForThe => 'Warten, bis der Code verknüpft ist…';

  @override
  String get goToPlex =>
      'Öffne plex.tv/link auf deinem Handy oder Computer und gib diesen Code ein.';

  @override
  String get signInWith => 'Mit Plex anmelden';

  @override
  String get waitingForApproval => 'Warten auf Bestätigung…';

  @override
  String onYourPhone(Object label) {
    return 'Öffne auf deinem Handy oder Computer $label → dein Profil → Quick Connect und gib diesen Code ein:';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'Anmelden';

  @override
  String get password => 'Passwort';

  @override
  String get username => 'Benutzername';

  @override
  String signInTo2(Object name) {
    return 'Bei $name anmelden';
  }

  @override
  String get differentServer => 'Anderer Server';

  @override
  String get signInWithPassword => 'Mit Passwort anmelden';

  @override
  String get quickConnectUse => 'Quick Connect (mit dem Handy)';

  @override
  String get connect => 'Verbinden';

  @override
  String get serverAddress => 'Serveradresse';

  @override
  String get connectToYour => 'Mit deinem Server verbinden';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV macht aus deiner Jellyfin-, Emby- oder Plex-Mediathek durchgehend laufende Sender mit TV-Guide. Zappe herum und schau, was gerade läuft.';

  @override
  String get yourLibraryOn => 'Deine Mediathek.\nAuf Sendung, rund um die Uhr.';

  @override
  String get welcomeToNightingale => 'Willkommen bei Nightingale TV';

  @override
  String signInFor(Object name) {
    return 'Anmeldung für $name';
  }

  @override
  String signInToAgain(Object name) {
    return 'Erneut bei $name anmelden';
  }

  @override
  String get addAServer => 'Server hinzufügen';

  @override
  String foundNewPrograms(Object list) {
    return 'Gefunden: $list. Neue Sendungen laufen auf ihren Sendern direkt nach dem aktuellen Programm an.';
  }

  @override
  String get libraryRefreshed => 'Mediathek aktualisiert';

  @override
  String get nothingNew => 'Nichts Neues';

  @override
  String get yourChannelsAre => 'Deine Sender sind auf dem neuesten Stand.';

  @override
  String get refreshFailed => 'Aktualisierung fehlgeschlagen';

  @override
  String get moveOkSelectEscBackTo =>
      '▲▼ Bewegen    OK Auswählen    ESC Zurück zum TV';

  @override
  String get noPoolsYet => 'noch keine Pools';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return 'Aktualisiert $fetchedAt um $fetchedAt2';
  }

  @override
  String get libraryLabel => 'MEDIATHEK';

  @override
  String get account => 'KONTO';

  @override
  String get watching => 'ZUSCHAUER';

  @override
  String get exitNightingaleTv => 'Nightingale TV beenden';

  @override
  String get signOut => 'Abmelden';

  @override
  String get yourChannelLineup =>
      'Deine Senderliste wird geleert. Eigene Symbole bleiben erhalten.';

  @override
  String get signOut2 => 'Abmelden?';

  @override
  String get fullScreenOn => 'Vollbild an/aus (F11)';

  @override
  String get nothingWasReset => 'Nichts wurde zurückgesetzt';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get rebuildsTheDefault =>
      'Erstellt die Standardsender aus deiner Mediathek neu. Von dir geänderte Namen, Symbole und Nummern werden zurückgesetzt. Selbst hinzugefügte Sender bleiben. Vorher wird eine Sicherung gespeichert, mit der du sie unter „Sichern und wiederherstellen“ zurückholen kannst.';

  @override
  String get resetChannelLineup => 'Senderliste zurücksetzen?';

  @override
  String get resetChannelLineup2 => 'Senderliste zurücksetzen';

  @override
  String get refreshLibrary => 'Mediathek aktualisieren';

  @override
  String get refreshingLibrary => 'Mediathek wird aktualisiert…';

  @override
  String get servers => 'Server';

  @override
  String get phoneRemote => 'Handy-Fernbedienung';

  @override
  String get profiles => 'Profile';

  @override
  String get retroLook => 'Retro-Look';

  @override
  String get playback => 'Wiedergabe';

  @override
  String get switchProfile => 'Profil wechseln';

  @override
  String get sleepTimer => 'Sleep-Timer';

  @override
  String get backToTv => 'Zurück zum TV';

  @override
  String get removeAll => 'Alle entfernen';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return 'gekoppelt $paired · zuletzt verwendet $lastUsed';
  }

  @override
  String get noPhonesPaired => 'Noch keine Handys gekoppelt.';

  @override
  String get pairedPhones => 'GEKOPPELTE HANDYS';

  @override
  String get blockedByThis => 'Von der Firewall dieses Computers blockiert';

  @override
  String get someWiFi =>
      'Manche WLANs halten Geräte voneinander getrennt (AP- oder Client-Isolation). Wenn sich das Handy weiterhin nicht verbinden kann, schalte diese Einstellung für dein WLAN aus.';

  @override
  String get thePhoneHas =>
      'Das Handy muss im selben WLAN wie dieser Fernseher sein, nicht in einem Gastnetz oder im Mobilfunknetz.';

  @override
  String get ifThePhone =>
      'Wenn sich das Handy nicht verbinden kann, blockiert es vielleicht die Firewall dieses Computers. Öffne auf diesem Computer ein Terminal und führe aus:';

  @override
  String get checkAgain => 'Erneut prüfen';

  @override
  String get thenChooseCheck => 'Wähle dann „Erneut prüfen“.';

  @override
  String get thisComputersFirewall =>
      'Die Firewall dieses Computers hindert Handys daran, die Fernbedienung zu erreichen. Um sie zuzulassen, öffne auf diesem Computer ein Terminal und führe aus:';

  @override
  String get notConfirmedYet =>
      'Noch nicht bestätigt · kein Handy hat sich verbunden';

  @override
  String get working => 'Funktioniert';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return 'Funktioniert · zuletzt verwendet von $name, $lastUsed';
  }

  @override
  String get theRemoteIs => 'Die Fernbedienung ist aus.';

  @override
  String get orScanThe => 'oder scanne den Code mit der Handykamera.';

  @override
  String get andEnter => 'und gib ein  ';

  @override
  String get onYourPhoneOpen => 'ÖFFNE AUF DEINEM HANDY';

  @override
  String get useYourPhoneAs =>
      'Nutze dein Handy als Fernbedienung: Öffne darauf eine Webseite, um Sender zu wechseln, den TV-Guide aufzurufen oder einen Sender anzutippen. Keine Installation nötig.';

  @override
  String get everyPairedPhone =>
      'Jedes gekoppelte Handy funktioniert nicht mehr als Fernbedienung, bis es den Code auf diesem Bildschirm erneut scannt.';

  @override
  String get removeAllPhones => 'Alle Handys entfernen?';

  @override
  String get thoseDidntMatch =>
      'Die stimmen nicht überein. Versuche es erneut.';

  @override
  String get enterTheSame => 'Gib dieselben 4 Ziffern erneut ein.';

  @override
  String get choose4Digits => 'Wähle 4 Ziffern.';

  @override
  String get thatPinIsnt => 'Diese PIN stimmt nicht. Versuche es erneut.';

  @override
  String get clock => 'UHR';

  @override
  String get captions2 => 'UNTERTITEL';

  @override
  String get audio => 'TON';

  @override
  String get maximumStreamingBitrate => 'MAXIMALE STREAMING-BITRATE';

  @override
  String get converting => 'UMWANDLUNG';

  @override
  String get afterThisLong =>
      'Wenn so lange keine Taste gedrückt wurde, fragt Nightingale TV, ob noch jemand zuschaut. Ohne Antwort innerhalb einer Minute geht es in den Ruhezustand: Die Wiedergabe stoppt und dein Server beendet das Streaming. Nicht, solange ein Sleep-Timer läuft.';

  @override
  String get askIfIm => 'Fragen, ob ich noch zuschaue';

  @override
  String get liveTvStill => 'Live-TV wird weiterhin im Dashboard angezeigt.';

  @override
  String get offWhatYou =>
      'Aus: Was du hier schaust, ändert nie Wiedergabezähler, Gesehen-Markierungen oder Fortsetzungspunkte auf deinem Server und erscheint nicht in seinem Dashboard.';

  @override
  String get pauseSkipAnd =>
      'Pausieren, springen und neu starten. Aus: Jeder Sender bleibt im Zeitplan, wie durchgehendes Fernsehen.';

  @override
  String get pauseAndRewind => 'Pausieren und zurückspulen';

  @override
  String get showsTheTime => 'Zeigt die Uhrzeit in der Bildecke.';

  @override
  String get onScreenClock => 'Bildschirmuhr';

  @override
  String get showACountdown =>
      'Zeigt einen Countdown, bevor die Werbung beginnt und bevor die Sendung zurückkommt.';

  @override
  String get breakNotices => 'Pausenhinweise';

  @override
  String get theSizeOf =>
      'Die Größe der Untertitel in jeder Sendung und auf jedem Sender.';

  @override
  String get whileItsOn =>
      'Solange das an ist, wird Surround-Ton (Dolby, DTS) von diesem Gerät dekodiert, statt an einen Receiver durchgereicht zu werden.';

  @override
  String get evensOutThe =>
      'Gleicht die Lautstärke beim Zuschauen an: Laute Werbung und Sendungen werden leiser, leise lauter, damit du nicht zur Fernbedienung greifen musst.';

  @override
  String get volumeLeveling => 'Lautstärkeausgleich';

  @override
  String get pickALower =>
      'Wähle eine niedrigere Bitrate, wenn Sendungen über WLAN oder eine Fernverbindung puffern oder ruckeln. Original wird nie wegen der Bitrate umgewandelt.';

  @override
  String get connectedThroughPlex =>
      'Über Plex Relay verbunden. Die Qualität ist begrenzt.';

  @override
  String get offNightingaleTv =>
      'Aus: Nightingale TV spielt immer deine Originaldateien in voller Qualität, und dein Server hat keine Zusatzarbeit. An: Dein Server wandelt eine Serie oder einen Film nur um, wenn die maximale Bitrate überschritten ist oder die Originaldatei nicht abspielbar ist. Die Umwandlung beansprucht Prozessor oder Grafikkarte deines Servers. Werbung spielt immer die Originaldateien.';

  @override
  String get transcodeOnlyIf => 'Nur bei Bedarf umwandeln (experimentell)';

  @override
  String get longerVideosAd =>
      'Längere Videos (Werbe-Zusammenstellungen) werden in ihre Spots aufgeteilt, an Kapiteln oder dort, wo das Bild schwarz und der Ton still wird.';

  @override
  String get videosOf5 =>
      'Videos von 5 Sekunden bis 3 Minuten sind jeweils ein Clip.';

  @override
  String get commercialsFillBreaks =>
      'Werbung füllt Pausen. Stelle den Typ auf Bumper für Senderkennungen und „Wir sind gleich zurück“-Clips.';

  @override
  String get bumpersTakeAt =>
      'Bumper nehmen höchstens die Hälfte einer Pause ein, außer im Pre-Roll. Ein dafür zu langer wird übersprungen.';

  @override
  String stillToSplit(Object unsplit) {
    return '$unsplit noch aufzuteilen';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount lange in Clips aufgeteilt',
      one: '$reelsCount langes in Clips aufgeteilt',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'Pool löschen';

  @override
  String get addFolders => 'Ordner hinzufügen…';

  @override
  String get libraryLabel2 => 'Mediathek';

  @override
  String get noFoldersYet => 'Noch keine Ordner.';

  @override
  String get folders2 => 'ORDNER';

  @override
  String get type => 'TYP';

  @override
  String get poolName => 'Pool-Name';

  @override
  String get commercialPool => 'Werbe-Pool';

  @override
  String get itsVideosGo =>
      'Seine Videos kehren zu deinen normalen Sendern zurück. Pausen, die daraus gespeist wurden, verwenden stattdessen alle Pools.';

  @override
  String get now => 'Jetzt';

  @override
  String get watch => 'Ansehen';

  @override
  String get tuning2 => 'Wird eingestellt…';

  @override
  String get fullScreen => 'Vollbild';

  @override
  String get noChannels => 'Keine Sender';

  @override
  String get theirChannelsProgramming =>
      'Sender, Programmblöcke und Einstellungen werden gelöscht, und dieser Fernseher wird von ihrem Server abgemeldet.';

  @override
  String delete3(Object name) {
    return '$name löschen?';
  }

  @override
  String get giveTheProfile => 'Gib dem Profil einen Namen.';

  @override
  String get deleteProfile => 'Profil löschen';

  @override
  String get removePin => 'PIN entfernen';

  @override
  String get setAPin => 'PIN festlegen';

  @override
  String get changePin => 'PIN ändern';

  @override
  String get noPinAnyone => 'Keine PIN. Jeder kann dieses Profil öffnen.';

  @override
  String get lockedThePin =>
      'Gesperrt. Die PIN wird zum Öffnen dieses Profils benötigt.';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith =>
      'Serien und Filme ohne Freigabe werden ausgelassen.';

  @override
  String get allowedToWatch => 'DARF ANSEHEN';

  @override
  String get kid => 'Kind';

  @override
  String get grownUp => 'Erwachsene';

  @override
  String get whoItsFor => 'FÜR WEN';

  @override
  String get color2 => 'FARBE';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get newProfile => 'Neues Profil';

  @override
  String get watchingNow => 'Schaut gerade';

  @override
  String get noPin => 'Keine PIN';

  @override
  String get pinLocked => 'Mit PIN gesperrt';

  @override
  String kid2(Object label, Object description) {
    return 'Kind · $label ($description)';
  }

  @override
  String get addProfile => 'Profil hinzufügen';

  @override
  String get everyoneGetsTheir =>
      'Jede Person bekommt eigene Server-Anmeldung, Sender und Programmblöcke. Kinderprofile sehen nur Serien und Filme, die für ihr Alter freigegeben sind.';

  @override
  String enterSPin(Object name) {
    return 'PIN von $name eingeben';
  }

  @override
  String get whosWatching => 'Wer schaut zu?';

  @override
  String get moveOkChoose2 => '◀▶ Bewegen    OK Wählen';

  @override
  String get enterAGrownUps => 'Gib die PIN eines Erwachsenen ein.';

  @override
  String get grownUpsOnly => 'Nur für Erwachsene';

  @override
  String get yourChannelYour => 'Dein Sender, dein Look';

  @override
  String get testPattern => 'Testbild';

  @override
  String get upNext8 => 'ALS NÄCHSTES  ·  20:00';

  @override
  String get thisDevice => 'DIESES GERÄT';

  @override
  String get glow => 'LEUCHTEN';

  @override
  String get curvature => 'WÖLBUNG';

  @override
  String get vignette => 'VIGNETTE';

  @override
  String get mask => 'MASKE';

  @override
  String get lines => 'ZEILEN';

  @override
  String get scanlines => 'SCANLINES';

  @override
  String get customCrtStyle => 'EIGENER CRT-STIL';

  @override
  String accent(Object label) {
    return 'AKZENT ($label)';
  }

  @override
  String get overlayTheme => 'OVERLAY-DESIGN';

  @override
  String get crtEffect => 'CRT-EFFEKT';

  @override
  String get surround => 'UMGEBUNG';

  @override
  String get pictureShape => 'BILDFORM';

  @override
  String get surroundImage => 'Umgebungsbild';

  @override
  String get notAvailableOn => 'Auf diesem Gerät nicht verfügbar';

  @override
  String get offTurnsOff =>
      'Aus schaltet alle CRT-Effekte nur auf diesem Gerät ab. Bildform, Umgebung und Overlay-Designs bleiben, wie sie sind.';

  @override
  String get effectsOnThis => 'Effekte auf diesem Gerät';

  @override
  String get retroLook2 => 'RETRO-LOOK';

  @override
  String get theseSettingsApply =>
      'Diese Einstellungen gelten auf Bildschirmen mit der App. Sie gelten nicht für den Live-TV-Export.';

  @override
  String get sameAsThe => 'Wie im Profil';

  @override
  String get streamsFromThis =>
      'Streams von diesem Server bleiben darunter. Das Limit des Profils (Wiedergabe) gilt weiterhin. Das niedrigere gewinnt.';

  @override
  String qualityLimit(Object name) {
    return 'Qualitätslimit · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbit/s';
  }

  @override
  String get itsProgramsLeave =>
      'Seine Sendungen verschwinden von deinen Sendern, die ihre Nummern behalten. Quellen und Werbeordner darauf werden als nicht gefunden angezeigt, bis du sie änderst.';

  @override
  String remove3(Object name) {
    return '$name entfernen?';
  }

  @override
  String get signingOutOf =>
      'Das Abmelden dieses Profils ändert seinen Hauptserver.';

  @override
  String signedInAs(Object user) {
    return 'Angemeldet als $user';
  }

  @override
  String get mainServer => 'Hauptserver';

  @override
  String get qualityLimit2 => 'Qualitätslimit';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get signInAgain => 'Erneut anmelden';

  @override
  String get programsFromEvery =>
      'Sendungen von allen Servern kommen in eine Senderliste. Ein Titel auf mehreren Servern wird vom ersten in dieser Liste abgespielt, der antwortet (Abspielen von). Antwortet er nicht mehr, übernimmt der nächste.';

  @override
  String get sleepingPressAny =>
      'Ruhezustand · Beliebige Taste zum Ansehen drücken';

  @override
  String goingToSleep(Object seconds) {
    return 'Ruhezustand in $seconds';
  }

  @override
  String get goingToSleep2 => 'Ruhezustand beginnt';

  @override
  String goingToSleepIn(Object hint) {
    return 'Ruhezustand in 1 Minute. $hint';
  }

  @override
  String get pressAnyButton => 'Beliebige Taste drücken, um weiterzuschauen';

  @override
  String goingToSleepIn0(Object padLeft) {
    return 'Ruhezustand in 0:$padLeft';
  }

  @override
  String get keepWatching => 'Weiterschauen';

  @override
  String get areYouStill => 'Schaust du noch?';

  @override
  String sleepTimerMin(Object left) {
    return 'Sleep-Timer · noch $left Min.';
  }

  @override
  String get whatsOnNow => 'Das aktuelle Programm hat kein festes Ende.';

  @override
  String endOfThis(Object programEnd) {
    return 'Ende dieser Sendung · $programEnd';
  }

  @override
  String get endOfThisProgram => 'Ende dieser Sendung';

  @override
  String get moveOkToggle => '▲▼◀▶ Bewegen    OK Umschalten    ESC Abbrechen';

  @override
  String get usedWhenNo =>
      'Wird verwendet, wenn keine Serien gewählt sind. Grenzt auch Filme ein.';

  @override
  String get genres2 => 'GENRES';

  @override
  String get includeMovies => 'Filme einbeziehen';

  @override
  String get add2 => 'Hinzufügen…';

  @override
  String get notFoundOn => 'Auf dem Server nicht gefunden';

  @override
  String get collectionsFolders => 'SAMMLUNGEN UND ORDNER';

  @override
  String get playOrder => 'WIEDERGABEREIHENFOLGE';

  @override
  String get clear => 'Leeren';

  @override
  String get shows2 => 'SERIEN';

  @override
  String get pickSomethingTo => 'Wähle etwas zum Abspielen.';

  @override
  String everyMovie(Object genreText) {
    return 'jeden $genreText-Film';
  }

  @override
  String get everyMovie2 => 'jeden Film';

  @override
  String everyShow(Object genreText) {
    return 'jede $genreText-Serie';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount oder $last';
  }

  @override
  String get settingUpYour => 'Deine Sender werden eingerichtet';

  @override
  String get couldntLoadYour => 'Deine Mediathek konnte nicht geladen werden';

  @override
  String upNext(Object title) {
    return 'Als Nächstes: $title';
  }

  @override
  String backTo(Object title) {
    return 'Zurück zu $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return 'Das Programm geht weiter in $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabel in $left';
  }

  @override
  String startingWith(Object title) {
    return 'Beginnt mit $title';
  }

  @override
  String upNext2(Object start) {
    return 'ALS NÄCHSTES  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return 'Als Nächstes $start: $title';
  }

  @override
  String backOn(Object backOnAir) {
    return 'Wieder da $backOnAir';
  }

  @override
  String get offTheAir2 => 'Nicht auf Sendung';

  @override
  String get commercialBreak => 'Werbepause';

  @override
  String tryingAgainAt(Object end) {
    return 'Neuer Versuch um $end';
  }

  @override
  String get exitFullScreen => 'Vollbild beenden';

  @override
  String get guide2 => 'TV-Guide';

  @override
  String thereIsNo(Object number) {
    return 'Es gibt keinen Sender $number';
  }

  @override
  String get liveChannelsCant => 'Live-Sender können nicht pausiert werden';

  @override
  String get curvatureAndGlow =>
      'Wölbung und Leuchten sind aus: Dieses Gerät kommt nicht mit';

  @override
  String get pressBackAgain => 'Erneut Zurück drücken zum Beenden';

  @override
  String backAt(Object backAt) {
    return 'Zurück um $backAt';
  }

  @override
  String get live => 'LIVE';

  @override
  String get newLabel => 'NEU';

  @override
  String nowPlayingOn(Object name) {
    return 'LÄUFT AUF $name';
  }

  @override
  String ch(Object padLeft) {
    return 'KANAL $padLeft';
  }

  @override
  String get paused => 'PAUSIERT';

  @override
  String get seekBar => 'Suchleiste';

  @override
  String get live2 => 'Live';

  @override
  String get forward30 => '30 vor';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Abspielen';

  @override
  String get back10 => '10 zurück';

  @override
  String get restart => 'Neu starten';

  @override
  String somethingWentWrong2(Object status) {
    return 'Etwas ist schiefgegangen ($status).';
  }

  @override
  String get thatIsTooBig => 'Das ist zu groß.';

  @override
  String get notFound => 'Nicht gefunden.';

  @override
  String get youCantDo => 'Das darfst du nicht.';

  @override
  String get cantReachThe =>
      'Der Server ist nicht erreichbar. Prüfe, ob er läuft.';

  @override
  String signOut3(Object userName) {
    return '$userName abmelden';
  }

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get users => 'Benutzer';

  @override
  String get backups2 => 'Sicherungen';

  @override
  String get serverAndSign => 'Server und Anmeldung';

  @override
  String get channels5 => 'Sender';

  @override
  String get thatProfileIsntYours =>
      'Dieses Profil gehört dir nicht oder existiert nicht mehr.';

  @override
  String get download => 'Herunterladen';

  @override
  String get itReplacesThe =>
      'Die Profile, Sender und Einstellungen hier werden ersetzt.';

  @override
  String get restoreThisBackup => 'Diese Sicherung wiederherstellen?';

  @override
  String get backupActions => 'Sicherungsaktionen';

  @override
  String channels6(Object profiles, Object channels, Object device) {
    return '$profiles · Sender: $channels · $device';
  }

  @override
  String get noneYetOne =>
      'Noch keine. Jeden Tag, an dem sich der Haushalt ändert, wird eine gespeichert.';

  @override
  String get savedOnThe => 'Auf dem Server gespeichert';

  @override
  String get restoring => 'Wird wiederhergestellt…';

  @override
  String get restoreFromAFile => 'Aus einer Datei wiederherstellen…';

  @override
  String get downloadABackup => 'Jetzt eine Sicherung herunterladen';

  @override
  String get aBackupHoldsThe =>
      'Eine Sicherung enthält Profile, Sender, Blöcke, Logos, Export-Einstellungen und Benutzerkonten (nie Passwörter oder Anmelde-Token).';

  @override
  String get restoredTheBackup2 => 'Sicherung wiederhergestellt.';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return 'Vom $whenValue ($device): $profiles. Die Profile, Sender und Einstellungen hier werden ersetzt.';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return 'Nächste Ausstrahlung: $start $end';
  }

  @override
  String programsInIts(Object total) {
    return 'Sendungen in der Wiedergabeliste: $total';
  }

  @override
  String get workingOutWhat => 'Inhalt wird ermittelt…';

  @override
  String get later => 'Später';

  @override
  String get earlier => 'Früher';

  @override
  String get eachAiringPlays =>
      'Jede Ausstrahlung spielt die nächsten Folgen jedes Platzes der Reihe nach und beginnt von vorn, wenn Zeit übrig bleibt.';

  @override
  String get aLineupOf => 'Eine Abfolge von Serien';

  @override
  String get whatItPlays2 => 'Was gespielt wird';

  @override
  String get onlyPartOf => 'Nur einen Teil des Jahres';

  @override
  String get runsPastMidnight => 'Läuft über Mitternacht in den nächsten Tag.';

  @override
  String get whenLabel => 'Wann';

  @override
  String get aNewChannelFor => 'Ein neuer Sender für diesen Block';

  @override
  String get channel3 => 'Sender';

  @override
  String get blocks => 'Blöcke';

  @override
  String get newBlock => 'Neuer Block';

  @override
  String get programmingBlock => 'Programmblock';

  @override
  String get aBlockTakes =>
      'Ein Block übernimmt einen Sender zu festen Zeiten: „Samstagmorgen-Cartoons“, samstags von 7 bis 12 Uhr.';

  @override
  String get overlayTheme2 => 'Overlay-Design';

  @override
  String get crtEffect2 => 'CRT-Effekt';

  @override
  String get chooseSurroundImage => 'Umgebungsbild wählen…';

  @override
  String get surround2 => 'Umgebung';

  @override
  String get pictureShape2 => 'Bildform';

  @override
  String get chooseOfflineImage => 'Offline-Bild wählen…';

  @override
  String get fillerPool2 => 'Füll-Pool';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes Minuten';
  }

  @override
  String get slotLength2 => 'Sendeplatzlänge';

  @override
  String get everyProgramStarts =>
      'Jede Sendung beginnt pünktlich. Der Auffüller füllt den Rest jedes Sendeplatzes.';

  @override
  String get itLeavesThe => 'Er verlässt die Senderliste.';

  @override
  String get itsProgrammingBlocks =>
      'Seine Programmblöcke werden ebenfalls entfernt.';

  @override
  String get removeThisChannel => 'Diesen Sender entfernen';

  @override
  String get channelLogo2 => 'Senderlogo';

  @override
  String get editCustomBreaks => 'Eigene Pausen bearbeiten…';

  @override
  String get musicChannelsOnlyShuffle =>
      'Musiksender spielen nur zufällig und nie denselben Künstler zweimal hintereinander.';

  @override
  String get playOrder2 => 'Wiedergabereihenfolge';

  @override
  String get saveWhatIt => 'Programm speichern';

  @override
  String get canBeA =>
      'Kann der Heimatsender einer Serie für ihre neuesten Folgen sein.';

  @override
  String get hiddenFromThe => 'Im TV-Guide ausgeblendet';

  @override
  String get chooseIcon => 'Symbol wählen…';

  @override
  String get icon => 'Symbol';

  @override
  String get saveNameAnd => 'Name und Nummer speichern';

  @override
  String get aChannelAlready =>
      'Ein Sender, der diese Nummer schon hat, tauscht den Platz mit diesem.';

  @override
  String get number3 => 'Nummer';

  @override
  String get nameAndNumber => 'Name und Nummer';

  @override
  String get decadesNoneAny => 'Jahrzehnte (keines: beliebig)';

  @override
  String get genresNoneAny => 'Genres (keines: beliebig)';

  @override
  String musicVideos(Object musicVideos) {
    return 'Musikvideos ($musicVideos)';
  }

  @override
  String songs(Object songs) {
    return 'Songs ($songs)';
  }

  @override
  String get newMusicChannel => 'Neuer Musiksender';

  @override
  String get aNightlySlot =>
      'Ein nächtlicher Sendeplatz für die neuesten Folgen von Serien, auf dem Heimatsender jeder Serie.';

  @override
  String get mainSettings => 'Haupteinstellungen';

  @override
  String get glow2 => 'Leuchten';

  @override
  String get curvature2 => 'Wölbung';

  @override
  String get vignette2 => 'Vignette';

  @override
  String get mask2 => 'Maske';

  @override
  String get lines2 => 'Zeilen';

  @override
  String get scanlines2 => 'Scanlines';

  @override
  String get customCrtStyle2 => 'Eigener CRT-Stil';

  @override
  String accent2(Object label) {
    return 'Akzent ($label)';
  }

  @override
  String get hidden => 'Ausgeblendet';

  @override
  String get blockChannel2 => 'Blocksender';

  @override
  String live3(Object source) {
    return 'Live · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return 'Sender: $shownCount von $channelsCount';
  }

  @override
  String get searchChannels => 'Sender suchen';

  @override
  String get resetLineup => 'Senderliste zurücksetzen';

  @override
  String get everyChannelEdit =>
      'Alle Änderungen an Sendern werden verworfen und die Standard-Senderliste neu erstellt. Selbst hinzugefügte Sender bleiben. Vorher wird eine Sicherung gespeichert.';

  @override
  String get musicChannel => 'Musiksender';

  @override
  String get newBlockChannel => 'Neuer Blocksender';

  @override
  String get channelsOwnPlans => 'Eigene Pläne der Sender';

  @override
  String get setTypeBumpers => 'Typ festlegen: Bumper';

  @override
  String get setTypeCommercials => 'Typ festlegen: Werbung';

  @override
  String get chooseFolders2 => 'Ordner wählen…';

  @override
  String get plansThatDrew =>
      'Pläne, die daraus gespeist wurden, verwenden stattdessen alle Pools, und seine Videos kehren zu den Sendern zurück.';

  @override
  String get renamePool => 'Pool umbenennen';

  @override
  String get poolActions => 'Pool-Aktionen';

  @override
  String get aPoolIs =>
      'Ein Pool ist eine Gruppe von Mediatheksordnern, deren Videos Pausen füllen, statt ausgestrahlt zu werden. Der Typ eines Pools legt fest, ob seine Clips als Werbung oder als Bumper laufen, die Pausen eröffnen und beenden.';

  @override
  String get pools2 => 'Pools';

  @override
  String get breaks => 'Pausen';

  @override
  String clipsInAll(Object clips) {
    return 'Clips in allen Werbe-Pools: $clips';
  }

  @override
  String get tunerAddress => 'Tuner-Adresse';

  @override
  String get changePort => 'Port ändern';

  @override
  String get exportThisProfile => 'Dieses Profil exportieren';

  @override
  String get letsPlexAnd =>
      'Lässt Plex und andere die Tuner im Netzwerk finden.';

  @override
  String get discovery2 => 'Erkennung';

  @override
  String get encoder2 => 'Encoder';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return 'Automatisch: $streamLimitInUse auf diesem Rechner.';
  }

  @override
  String get streamsAtOnce2 => 'Gleichzeitige Streams';

  @override
  String get quality2 => 'Qualität';

  @override
  String get settings => 'Einstellungen';

  @override
  String get eachExportedProfile =>
      'Jedes exportierte Profil ist ein Tuner für Plex, Jellyfin oder Emby. Füge es in deren DVR-Einstellungen über seine Adresse hinzu.';

  @override
  String get channelsInThis => 'Sender in dieser Gruppe';

  @override
  String get chooseChannels3 => 'Sender wählen…';

  @override
  String channels7(Object channelIds) {
    return 'Sender: $channelIds';
  }

  @override
  String get itsChannelsStay => 'Seine Sender bleiben in der Senderliste.';

  @override
  String get renameGroup => 'Gruppe umbenennen';

  @override
  String get groupActions => 'Gruppenaktionen';

  @override
  String get yourGroup => 'Deine Gruppe';

  @override
  String get theOrderOf =>
      'Die Reihenfolge der Tabs im TV-Guide und welche angezeigt werden.';

  @override
  String get guideTabs => 'Guide-Tabs';

  @override
  String get make => 'Erstellen';

  @override
  String get breaksBetweenPrograms => 'Pausen zwischen Sendungen';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '$mids Pausen darin',
      one: '$mids Pause darin',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return 'Songs: $songs';
  }

  @override
  String get newEpisode => 'Neue Folge';

  @override
  String get noChannelsYet2 => 'Noch keine Sender.';

  @override
  String get noGuide => 'Kein Guide';

  @override
  String get noneShown => 'Keine anzeigen';

  @override
  String get allShown => 'Alle anzeigen';

  @override
  String channels8(Object name) {
    return '$name: Sender';
  }

  @override
  String get orChooseA => 'Oder eine Guide-Datei wählen…';

  @override
  String get emptyThePlaylists =>
      'Leer: der eigene Guide der Wiedergabeliste, falls sie einen nennt.';

  @override
  String get guideAddressXmltv => 'Guide-Adresse (XMLTV, optional)';

  @override
  String get orChooseAPlaylist => 'Oder eine Wiedergabelisten-Datei wählen…';

  @override
  String get leaveEmptyToKeep =>
      'Leer lassen, um die Wiedergabelisten-Datei zu behalten.';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'Dateien';

  @override
  String get itsChannelsJoin =>
      'Seine Sender kommen hinzu, solange dieses Profil bei diesem Server angemeldet ist.';

  @override
  String guide3(Object guideFile) {
    return 'Guide: $guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'Wiedergabelisten-Datei: $playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return 'Aktualisiert $last $context';
  }

  @override
  String get itsChannelsLeaveThe =>
      'Seine Sender verschwinden aus der Senderliste, den Gruppen und Favoriten.';

  @override
  String read(Object fetched, Object context) {
    return 'Gelesen $fetched $context.';
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
    return 'Serien: $series · Folgen: $episodes · Filme: $movies · Songs: $songs · Musikvideos: $musicVideos · Werbevideos: $commercials';
  }

  @override
  String fromAs(Object server, Object user) {
    return 'Von $server als $user.';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name: Mediathek';
  }

  @override
  String get removeThePin => 'PIN entfernen';

  @override
  String get pinOptional => 'PIN (optional)';

  @override
  String get newPinLeave => 'Neue PIN (leer lassen, um sie zu behalten)';

  @override
  String colour(Object i) {
    return 'Farbe $i';
  }

  @override
  String get colour2 => 'Farbe';

  @override
  String get itsChannelsBlocks =>
      'Sender, Blöcke und Einstellungen werden gelöscht. Vorher wird eine Sicherung gespeichert.';

  @override
  String get exported => 'Exportiert';

  @override
  String kid3(Object label) {
    return 'Kind · $label';
  }

  @override
  String get noProfilesAre =>
      'Dir sind noch keine Profile zugewiesen. Frag einen Admin.';

  @override
  String signIn2(Object name) {
    return '$name anmelden';
  }

  @override
  String get theLibraryIs =>
      'Die Mediathek wird erneut gelesen. Die Sendungen des Servers kommen zu den Sendern, sobald das fertig ist.';

  @override
  String get itsLibraryIs =>
      'Die Mediathek wird gelesen und die Sender werden erstellt. Das dauert ein bis zwei Minuten.';

  @override
  String isSignedIn(Object name) {
    return '$name ist angemeldet.';
  }

  @override
  String get couldntDoThat => 'Das hat nicht geklappt. Versuche es erneut.';

  @override
  String get itsChannelsStayIt =>
      'Die Sender bleiben. Zum Abspielen ist eine Anmeldung nötig.';

  @override
  String signOut4(Object name) {
    return '$name abmelden?';
  }

  @override
  String get signingIn => 'Anmeldung läuft…';

  @override
  String wasSignedIn(Object server, Object user) {
    return 'War bei $server als $user angemeldet. Melde dich erneut an.';
  }

  @override
  String signedInTo(Object server, Object user) {
    return 'Bei $server als $user angemeldet.';
  }

  @override
  String get profileName => 'Profilname';

  @override
  String get nameAProfile =>
      'Benenne ein Profil, melde es bei deinem Medienserver an, und seine Sender werden erstellt und exportiert.';

  @override
  String get chooseABackup => 'Sicherungsdatei wählen…';

  @override
  String get moveAHousehold =>
      'Ziehe einen Haushalt von einem Fernseher oder anderen Server hierher um: mit Profilen, Sendern, Blöcken, Logos und Export-Einstellungen.';

  @override
  String get restoreABackup => 'Sicherung wiederherstellen';

  @override
  String get theServerIs => 'Der Server startet…';

  @override
  String get itsProgramsLeaveThe =>
      'Seine Sendungen verschwinden von den Sendern, die ihre Nummern behalten. Quellen und Werbeordner darauf werden als nicht gefunden angezeigt, bis du sie änderst.';

  @override
  String addAServerTo(Object name) {
    return 'Server zu $name hinzufügen';
  }

  @override
  String servers2(Object name) {
    return '$name: Server';
  }

  @override
  String get makeAccountAnd => 'Konto erstellen und anmelden';

  @override
  String get setPasswordAnd => 'Passwort festlegen und anmelden';

  @override
  String get passwordAgain => 'Passwort wiederholen';

  @override
  String get atLeast8 => 'Mindestens 8 Zeichen.';

  @override
  String get userName => 'Benutzername';

  @override
  String get adminAccount => 'Admin-Konto';

  @override
  String get makeTheFirst => 'Erstelle das erste Admin-Konto.';

  @override
  String get setANew => 'Lege ein neues Passwort für ein Admin-Konto fest.';

  @override
  String get thisSetupLink =>
      'Dieser Einrichtungslink wurde schon verwendet oder stammt von einem früheren Start. Öffne den neuesten aus dem Serverprotokoll oder melde dich an.';

  @override
  String get thePasswordsDont => 'Die Passwörter stimmen nicht überein.';

  @override
  String get newPasswordAgain => 'Neues Passwort wiederholen';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get passwordChangedYour =>
      'Passwort geändert. Deine anderen Browser wurden abgemeldet.';

  @override
  String get theNewPasswords => 'Die neuen Passwörter stimmen nicht überein.';

  @override
  String get theyAreSigned =>
      'Die Person wird abgemeldet und kann sich nicht wieder anmelden.';

  @override
  String get cantSignIn => 'Keine Anmeldung möglich, überall abgemeldet.';

  @override
  String get usersReachOnly => 'Benutzer erreichen nur die Profile unten.';

  @override
  String get adminsCanDo => 'Admins dürfen alles, bei jedem Profil.';

  @override
  String get admin => 'Admin';

  @override
  String get user => 'Benutzer';

  @override
  String get leaveEmptyToKeepIt =>
      'Leer lassen, um es zu behalten. Ein neues meldet die Person überall sonst ab.';

  @override
  String get needsAPassword =>
      'Braucht ein Passwort, bevor die Anmeldung möglich ist.';

  @override
  String get addUser => 'Benutzer hinzufügen';

  @override
  String get needsAPassword2 => 'Braucht ein Passwort';

  @override
  String get noProfiles => 'Keine Profile';

  @override
  String get pad => 'Auffüllen';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  Clips: $clips';
  }

  @override
  String get clipsFrom2 => 'Clips aus';

  @override
  String get channelsUsingItGo =>
      'Sender, die es verwenden, erhalten wieder ein integriertes Symbol.';

  @override
  String get uploading => 'Wird hochgeladen…';

  @override
  String get noneOfYourShows =>
      'Keine deiner Serien hat ein Logobild auf deinem Server.';

  @override
  String get chooseAnIcon => 'Symbol wählen';

  @override
  String get couldntCopySelect =>
      'Kopieren fehlgeschlagen. Markiere den Text und kopiere ihn.';

  @override
  String copy(Object label) {
    return '$label kopieren';
  }

  @override
  String get home => 'Startseite';

  @override
  String get thereIsNoPage => 'Hier gibt es keine Seite.';

  @override
  String get enterPin => 'PIN eingeben';

  @override
  String get thisIsA =>
      'Das ist ein Kinderprofil. Zum Ändern seiner Einstellungen ist die PIN eines Erwachsenen nötig.';

  @override
  String hasAPin(Object name) {
    return '$name hat eine PIN.';
  }

  @override
  String get profile => 'Profil';

  @override
  String get changingAKid =>
      'Zum Ändern der Einstellungen eines Kinderprofils ist die PIN eines Erwachsenenprofils nötig.';

  @override
  String get aGrownUps => 'PIN eines Erwachsenen';

  @override
  String get thisProfile => 'dieses Profil';

  @override
  String movies3(Object movies) {
    return 'Filme ($movies)';
  }

  @override
  String get shows3 => 'Serien';

  @override
  String remove4(Object label) {
    return '$label entfernen';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · Auf dem Server nicht gefunden';
  }

  @override
  String get dragACollection =>
      'Ziehe eine Sammlung, einen Ordner oder Film hierher oder nutze die Schaltfläche Hinzufügen.';

  @override
  String get collectionsAndFolders => 'Sammlungen und Ordner';

  @override
  String add3(Object name) {
    return '$name hinzufügen';
  }

  @override
  String added2(Object name) {
    return '$name hinzugefügt';
  }

  @override
  String get dragToAdd => 'Zum Hinzufügen ziehen';

  @override
  String get languageAutomatic => 'Automatisch';

  @override
  String dateAtTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String connectingTo(Object server) {
    return 'Verbinde mit $server…';
  }

  @override
  String get yourServerLower => 'deinem Server';

  @override
  String noServerFoundAt(Object address) {
    return 'Kein Jellyfin-, Emby- oder Plex-Server unter $address gefunden.';
  }

  @override
  String captionsValue(Object name) {
    return 'Untertitel: $name';
  }

  @override
  String channelOverrides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Sender haben ihre eigene Einstellung (Sender und Symbole).',
      one: '$count Sender hat seine eigene Einstellung (Sender und Symbole).',
    );
    return '$_temp0';
  }

  @override
  String noShowLogosOn(Object kind) {
    return 'Keine deiner Serien hat ein Logobild auf deinem $kind-Server.';
  }

  @override
  String fileChosen(Object name) {
    return 'Datei: $name';
  }

  @override
  String get theOneChosenBefore => 'die zuvor gewählte';

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
          'Sender $channels werden an $viewers Zuschauer gestreamt. $running von $limit Streams in Verwendung.',
      one:
          'Sender $channels wird an $viewers Zuschauer gestreamt. $running von $limit Streams in Verwendung.',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name: diese Senderliste exportieren';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name (Kind): diese Senderliste exportieren';
  }

  @override
  String encoderInUse(Object encoder) {
    return 'Verwendeter Encoder: $encoder';
  }

  @override
  String get checking => 'wird geprüft…';

  @override
  String countShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Serien',
      one: '$count Serie',
    );
    return '$_temp0';
  }

  @override
  String countEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Folgen',
      one: '$count Folge',
    );
    return '$_temp0';
  }

  @override
  String countMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Filme',
      one: '$count Film',
    );
    return '$_temp0';
  }

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '$count Song',
    );
    return '$_temp0';
  }

  @override
  String countMusicVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Musikvideos',
      one: '$count Musikvideo',
    );
    return '$_temp0';
  }

  @override
  String countHidden(int count) {
    return '$count ausgeblendet';
  }

  @override
  String countOnTheAir(int count) {
    return '$count auf Sendung';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Programmblöcke',
      one: '$count Programmblock',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name: $stats';
  }

  @override
  String get yourServerHasNothingNew =>
      'Dein Server hat seit der letzten Aktualisierung nichts Neues. Neue Dateien erscheinen hier, sobald der Server sie erfasst hat. Wenn du gerade welche hinzugefügt hast, scanne zuerst die Mediathek auf dem Server und aktualisiere dann erneut.';

  @override
  String serverHasNothingNew(Object server) {
    return '$server hat seit der letzten Aktualisierung nichts Neues. Neue Dateien erscheinen hier, sobald der Server sie erfasst hat. Wenn du gerade welche hinzugefügt hast, scanne zuerst die Mediathek auf dem Server und aktualisiere dann erneut.';
  }

  @override
  String get updateWatchStatusOnYourServer =>
      'Gesehen-Status auf deinem Server aktualisieren';

  @override
  String get updateWatchStatusOnYourServers =>
      'Gesehen-Status auf deinen Servern aktualisieren';

  @override
  String updateWatchStatusOn(Object name) {
    return 'Gesehen-Status auf $name aktualisieren';
  }

  @override
  String get poolFoldersBumpers =>
      'Jedes Video in diesen Ordnern (und ihren Unterordnern) eröffnet und beendet Pausen und wird nie als Sendung ausgestrahlt.';

  @override
  String get poolFoldersCommercials =>
      'Jedes Video in diesen Ordnern (und ihren Unterordnern) füllt Pausen und wird nie als Sendung ausgestrahlt.';

  @override
  String get newPin => 'Neue PIN';

  @override
  String namedPin(Object name) {
    return 'PIN für $name';
  }

  @override
  String get qualitySameAsProfile => 'Qualität: wie im Profil';

  @override
  String qualityValue(Object limit) {
    return 'Qualität: $limit';
  }

  @override
  String onChannel(Object channel) {
    return 'auf $channel';
  }

  @override
  String get aChannelThatIsGone => 'einem Sender, den es nicht mehr gibt';

  @override
  String liveFrom(Object source) {
    return 'Live von $source';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'Logo $mode · Premieren $premieres';
  }

  @override
  String get offLower => 'aus';

  @override
  String streamingNow(Object count) {
    return 'Streams gerade: $count.';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return 'Streams gerade: $count · Kodierung mit $encoder.';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · Sender: $chosen von $channels';
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
    return 'Vom $when ($device): $profiles. Sender: $channels, Programmblöcke: $blocks, Logos: $logos.';
  }

  @override
  String get backupSavedFirst =>
      'Vorher wird eine Sicherung des aktuellen Stands gespeichert.';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Serien',
      one: '$count neue Serie',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Folgen',
      one: '$count neue Folge',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Filme',
      one: '$count neuer Film',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Songs',
      one: '$count neuer Song',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return 'Spielt $list.';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Sender',
      one: '$count neuer Sender',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => 'Kleine Kinder';

  @override
  String get kidRatingYoungDescription => 'TV-Y und TV-Y7';

  @override
  String get kidRatingKids => 'Kinder';

  @override
  String get kidRatingKidsDescription => 'Bis TV-G und G';

  @override
  String get kidRatingOlder => 'Ältere Kinder';

  @override
  String get kidRatingOlderDescription => 'Bis TV-PG und PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Profile',
      one: '$count Profil',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sender',
      one: '$count Sender',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Blöcke',
      one: '$count Block',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sendeplätze',
      one: '$count Sendeplatz',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos in seinen Ordnern',
      one: '$count Video in seinen Ordnern',
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
      'Ein Mid-Roll beginnt und endet mit einem Bumper, ein Post-Roll beginnt mit einem und ein Pre-Roll endet mit einem. Werbung füllt den Rest.';

  @override
  String get programsPlayBack =>
      'Sendungen laufen direkt hintereinander, ohne Pausen.';

  @override
  String get everyShowFills =>
      'Jede Serie füllt einen halbstündigen Sendeplatz (bei langen eine Stunde oder mehr), damit der TV-Guide im Takt bleibt.';

  @override
  String get chooseHowLong =>
      'Lege fest, wie lang jede Pause ist, wie oft Serien unterbrochen werden und aus welchem Pool jede Pause kommt.';

  @override
  String get kindSentenceAutomatic => 'automatisch';

  @override
  String get kindSentenceBeforeRestore => 'vor dem Wiederherstellen';

  @override
  String get kindSentenceBeforeReset => 'vor dem Zurücksetzen';

  @override
  String get kindSentenceBeforeDeletingAProfile =>
      'vor dem Löschen eines Profils';

  @override
  String kindSentenceBeforeDeleting(Object subject) {
    return 'vor dem Löschen von $subject';
  }

  @override
  String get kindSentenceBeforeUpdate => 'vor dem Update';

  @override
  String get kindSentenceBeforeLineupCleanup =>
      'vor dem Aufräumen der Senderliste';

  @override
  String get kindSentenceFromAFile => 'aus einer Datei';

  @override
  String get kindSentenceMovingToOfficial => 'Umzug zu Nightingale TV';

  @override
  String get kindSentenceMovingToOwnBuild =>
      'Umzug zu Nightingale TV (eigener Build)';

  @override
  String get kindSentenceFromOfficial => 'von Nightingale TV';

  @override
  String get kindSentenceFromOwnBuild => 'von Nightingale TV (eigener Build)';

  @override
  String get kindSentenceMadeByYou => 'von dir erstellt';

  @override
  String get copyAction => 'Kopieren';

  @override
  String get channelKidsZone => 'Kinderland';

  @override
  String get channelToonTv => 'Toon TV';

  @override
  String get channelLaughTrack => 'Lachkanal';

  @override
  String get channelFamilyRoom => 'Familienzimmer';

  @override
  String get channelAdventureTv => 'Abenteuer TV';

  @override
  String get channelSciFiFantasy => 'Sci-Fi & Fantasy';

  @override
  String get channelMysteryTv => 'Krimi TV';

  @override
  String get channelDramaCentral => 'Drama Zentrale';

  @override
  String get channelCrimeJustice => 'Tatort & Justiz';

  @override
  String get channelThrillTv => 'Thrill TV';

  @override
  String get channelFrightNight => 'Gruselnacht';

  @override
  String get channelRomanceTv => 'Romantik TV';

  @override
  String get channelDiscoveryZone => 'Entdecker TV';

  @override
  String get channelMusicTv => 'Musik TV';

  @override
  String get channelRealityTv => 'Reality TV';

  @override
  String get channelGameShowTv => 'Quiz TV';

  @override
  String get channelFrontierTv => 'Grenzland TV';

  @override
  String get channelHistoryTv => 'Geschichte TV';

  @override
  String get channelSportsTv => 'Sport TV';

  @override
  String get channelNewsTv => 'Nachrichten TV';

  @override
  String get channelAllShows => 'Alle Serien';

  @override
  String get channelMovieChannel => 'Filmkanal';

  @override
  String get channelMusicVideos => 'Musikvideos';

  @override
  String get channelMusicRadio => 'Musikradio';

  @override
  String get genreActionAdventure => 'Action & Abenteuer';

  @override
  String get genreSciFiFantasy => 'Sci-Fi & Fantasy';

  @override
  String get genreKids => 'Kinder';

  @override
  String get genreAnimation => 'Animation';

  @override
  String get genreComedy => 'Komödie';

  @override
  String get genreFamily => 'Familie';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreCrime => 'Krimi';

  @override
  String get genreMystery => 'Mystery';

  @override
  String get genreThriller => 'Thriller';

  @override
  String get genreHorror => 'Horror';

  @override
  String get genreRomance => 'Romantik';

  @override
  String get genreDocumentary => 'Dokumentation';

  @override
  String get genreMusic => 'Musik';

  @override
  String get genreReality => 'Reality';

  @override
  String get genreGameShows => 'Spielshows';

  @override
  String get genreWestern => 'Western';

  @override
  String get genreWar => 'Krieg';

  @override
  String get genreHistory => 'Geschichte';

  @override
  String get genreNews => 'Nachrichten';

  @override
  String get genreTalk => 'Talk';

  @override
  String get genreSoap => 'Seifenoper';

  @override
  String get genreSports => 'Sport';

  @override
  String get genreClassical => 'Klassik';

  @override
  String get genreElectronic => 'Elektronisch';

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
  String get blockDaytime => 'Tagsüber';

  @override
  String get blockMovieNight => 'Filmabend';

  @override
  String get blockNewEpisodes => 'Neue Folgen';

  @override
  String get kindShow => 'Serie';

  @override
  String get kindShows => 'Serien';

  @override
  String get kindMovies => 'Filme';

  @override
  String get kindMusicVideos => 'Musikvideos';

  @override
  String get kindRadio => 'Radio';

  @override
  String genreMovies(Object genre) {
    return '$genre-Filme';
  }

  @override
  String genreMusicVideos(Object genre) {
    return '$genre-Musikvideos';
  }

  @override
  String genreRadio(Object genre) {
    return '$genre-Radio';
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
  String get languageTitle => 'Sprache';

  @override
  String get stillWatchingOff => 'Aus';

  @override
  String afterHours(int hours) {
    return 'Nach $hours Stunden';
  }

  @override
  String get bitrateOriginal => 'Original (ohne Limit)';

  @override
  String get bitrate40 => '40 Mbit/s · 4K';

  @override
  String get bitrate20 => '20 Mbit/s · 1080p hoch';

  @override
  String get bitrate12 => '12 Mbit/s · 1080p';

  @override
  String get bitrate8 => '8 Mbit/s · 1080p';

  @override
  String get bitrate4 => '4 Mbit/s · 720p';

  @override
  String get noSuchLanguage => 'Keine solche Sprache.';

  @override
  String get languageField => 'Sprache';

  @override
  String get remotePageTitle => 'Nightingale TV Fernbedienung';

  @override
  String get remotePairTitle => 'Mit dem Fernseher koppeln';

  @override
  String get remotePairHelp =>
      'Scanne den Code auf dem Fernseher (Menü → Handy-Fernbedienung) oder gib den dort angezeigten 6-stelligen Code ein.';

  @override
  String get remotePairingCode => 'Kopplungscode';

  @override
  String get remotePair => 'Koppeln';

  @override
  String get remoteConnecting => 'Verbinde…';

  @override
  String get remoteTabRemote => 'Fernbedienung';

  @override
  String get remoteUp => 'Hoch';

  @override
  String get remoteLeft => 'Links';

  @override
  String get remoteRight => 'Rechts';

  @override
  String get remoteDown => 'Runter';

  @override
  String get remoteInfo => 'Info';

  @override
  String get remoteLastCh => 'Letzter';

  @override
  String get remoteCc => 'UT';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => 'Eingabe';

  @override
  String get remoteRemovedFromTv =>
      'Dieses Handy wurde vom Fernseher entfernt. Scanne den Code, um es neu zu koppeln.';

  @override
  String get remoteCouldntPair =>
      'Kopplung fehlgeschlagen. Versuche es erneut.';

  @override
  String get remoteCantReachWifi =>
      'Der Fernseher ist nicht erreichbar. Ist dieses Handy im selben WLAN?';

  @override
  String get remoteEnterDigits =>
      'Gib die 6 Ziffern ein, die auf dem Fernseher angezeigt werden.';

  @override
  String get remoteCantReachTv => 'Der Fernseher ist nicht erreichbar';

  @override
  String get remotePickProfile => 'Wähle mit den Pfeilen und OK ein Profil.';

  @override
  String remoteWatching(Object name) {
    return 'Schaut: $name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name (Kind)';
  }

  @override
  String get transferPageTitle => 'Nightingale TV Sicherung';

  @override
  String get transferIntro =>
      'Verschiebe eine Sicherung zwischen diesem Fernseher und diesem Gerät. Lass dabei das Fenster am Fernseher geöffnet.';

  @override
  String get transferDownload => 'Sicherung herunterladen';

  @override
  String get transferDownloadHelp =>
      'Eine Sicherung der aktuellen Einrichtung des Fernsehers: Profile, Sender, Blöcke und Einstellungen.';

  @override
  String get transferRestoreTitle => 'Aus einer Datei wiederherstellen';

  @override
  String transferRestoreHelp(Object file) {
    return 'Sende eine $file-Datei an den Fernseher. Nichts ändert sich, bis du es am Fernseher bestätigst.';
  }

  @override
  String get transferChoose => 'Sicherungsdatei wählen…';

  @override
  String get transferFoot =>
      'Nur Geräte in deinem Heimnetz können diese Seite öffnen.';

  @override
  String transferSending(Object name) {
    return '$name wird gesendet…';
  }

  @override
  String get transferCheckTv => 'Schau auf deinen Fernseher, um abzuschließen.';

  @override
  String get transferClosed =>
      'Der Fernseher hat diese Seite geschlossen. Öffne sie erneut unter „Sichern und wiederherstellen“.';

  @override
  String get transferCouldntTake =>
      'Der Fernseher konnte diese Datei nicht annehmen.';

  @override
  String get transferCouldntReach =>
      'Der Fernseher war nicht erreichbar. Zeigt er noch den Code an?';

  @override
  String get includeShows => 'Serien einbeziehen';

  @override
  String get everyShow2 => 'jede Serie';

  @override
  String get decades => 'Jahrzehnte';

  @override
  String get decadesHeading => 'JAHRZEHNTE';

  @override
  String get channelActionTv => 'Action TV';

  @override
  String get channelSciFiTv => 'Sci-Fi TV';

  @override
  String get channelFantasyTv => 'Fantasy TV';

  @override
  String get channelMysteryThrills => 'Krimi & Spannung';

  @override
  String get genreAction => 'Action';

  @override
  String get genreAdventure => 'Abenteuer';

  @override
  String get genreSciFi => 'Sci-Fi';

  @override
  String get genreFantasy => 'Fantasy';

  @override
  String get genreThrillerMystery => 'Thriller & Krimi';

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
    return '$decade $genre-Filme';
  }

  @override
  String get errorReports => 'Fehlerberichte';

  @override
  String get sendErrorReportsFrom => 'Fehlerberichte von diesem Gerät senden';

  @override
  String get errorReportsExplain =>
      'Wenn etwas schiefgeht, schickt Nightingale TV dem Entwickler einen kurzen Bericht: den Fehler, die App-Version, die Art des Geräts und die letzten Bildschirme und Sendernummern. Serveradressen, Passwörter und Schlüssel, Namen und Dateipfade werden vor dem Senden entfernt. Titel und was du schaust, werden nie gesendet.';

  @override
  String get errorReportsOff =>
      'Schaltest du das aus, wird von diesem Gerät nichts gesendet; wartende Berichte werden gelöscht.';

  @override
  String get sendATestReport => 'Testbericht senden';

  @override
  String lastReportId(String id) {
    return 'ID des letzten Berichts: $id';
  }

  @override
  String get noReportSentYet =>
      'Von diesem Gerät wurde noch kein Bericht gesendet.';

  @override
  String get quoteReportId =>
      'Nenne diese ID, wenn du dem Entwickler ein Problem meldest.';

  @override
  String testReportSent(String id) {
    return 'Testbericht gesendet: $id';
  }

  @override
  String get testReportNotSent =>
      'Der Testbericht konnte nicht gesendet werden. Versuch es gleich noch einmal.';

  @override
  String get reportsNotInBuild =>
      'Fehlerberichte sind in diesem Build von Nightingale TV nicht enthalten, daher wird nie etwas gesendet.';

  @override
  String get sendAVideoReport => 'Videobericht senden';

  @override
  String get videoReportHelp =>
      'Wenn das Bild falsch aussieht, drück hier und geh dann zurück zu einem Sender. Nach 10 Sekunden Bild wird der Bericht gesendet und seine ID im TV-Bild angezeigt.';

  @override
  String get videoReportArmed =>
      'Geh jetzt zurück zu einem Sender. Der Videobericht wird nach 10 Sekunden Bild gesendet.';

  @override
  String get videoReportTooSoon =>
      'Vor weniger als einer Minute wurde ein Videobericht gesendet. Versuch es gleich noch einmal.';

  @override
  String videoReportSent(String id) {
    return 'Videobericht gesendet: $id';
  }

  @override
  String get videoReportsExplain =>
      'Ein Videobericht sendet Angaben zum Gerät, zum Video und seinem Decoder, grobe Farbraster des Bildes und die letzten Protokollzeilen der App; nie ein Bild von dem, was du schaust. Nach jedem App-Update wird einmal einer gesendet, sobald ein Sender 10 Sekunden lang lief.';
}
