// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get onlyChannelsYou =>
      'Puoi rimuovere solo i canali che hai aggiunto. Nascondi questo invece.';

  @override
  String get music => 'Musica';

  @override
  String get nothingInThe => 'Nella libreria non c\'è nulla di corrispondente.';

  @override
  String get chooseSongsOr => 'Scegli brani o video musicali.';

  @override
  String get blockChannel => 'Canale a blocchi';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return 'Si sovrappone a «$title» ($clash) sullo stesso canale.';
  }

  @override
  String get chooseSomeShows =>
      'Scegli serie o film da trasmettere nel blocco.';

  @override
  String nothingInThis(Object shortLabel) {
    return 'In questo mix non c\'è nulla classificato $shortLabel o superiore. Scegli una classificazione più bassa o altre serie.';
  }

  @override
  String get theLineupsShows =>
      'Le serie del palinsesto non hanno episodi. Scegli altre serie.';

  @override
  String get addAShow => 'Aggiungi una serie al palinsesto.';

  @override
  String get chooseAChannel => 'Scegli un canale.';

  @override
  String get theBlockHas =>
      'Il blocco deve finire a un orario diverso da quello di inizio.';

  @override
  String get pickAtLeast => 'Scegli almeno un giorno.';

  @override
  String get giveTheBlock => 'Dai un titolo al blocco.';

  @override
  String get thisChannelDoesnt => 'Questo canale non ha fasce.';

  @override
  String get onlyShuffledChannels =>
      'Solo i canali casuali possono essere rimescolati.';

  @override
  String get chooseSomethingFor => 'Scegli cosa trasmettere sul canale.';

  @override
  String get onlyChannelsYouAdded =>
      'Solo i canali che hai aggiunto possono cambiare ciò che trasmettono.';

  @override
  String get myChannel => 'Il mio canale';

  @override
  String get noneOfYour => 'Nessuno dei tuoi server è raggiungibile.';

  @override
  String scanning(Object where) {
    return 'Analisi di $where…';
  }

  @override
  String get buildingChannels => 'Creazione dei canali…';

  @override
  String get notSignedIn => 'Accesso non effettuato.';

  @override
  String isAlreadyIn(Object name) {
    return '$name è già in questo profilo';
  }

  @override
  String get thatServerIs => 'Quel server non è più in questo profilo';

  @override
  String get yourSessionExpired => 'La sessione è scaduta. Accedi di nuovo.';

  @override
  String get m3uPlaylist => 'Playlist M3U';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName non ha canali TV in diretta';
  }

  @override
  String couldntReach(Object serverName) {
    return 'Impossibile raggiungere $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return 'TV in diretta di $serverName';
  }

  @override
  String liveTvIs(Object serverName) {
    return 'La TV in diretta di $serverName è già una fonte';
  }

  @override
  String get notSignedIn2 => 'Accesso non effettuato';

  @override
  String get newGroup => 'Nuovo gruppo';

  @override
  String get thisBackupIs =>
      'Questo backup è danneggiato: uno dei loghi dei canali non è leggibile.';

  @override
  String get thisBackupIsDamaged =>
      'Questo backup è danneggiato: le impostazioni di esportazione TV in diretta non sono leggibili.';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'Questo backup è danneggiato: $what di $name non è leggibile.';
  }

  @override
  String get liveTvSources => 'Fonti TV in diretta';

  @override
  String thisBackupCant(Object problem) {
    return 'Questo backup non può essere ripristinato. $problem';
  }

  @override
  String get thisBackupIsDamagedIts =>
      'Questo backup è danneggiato: i profili non sono leggibili.';

  @override
  String get thisFileIs =>
      'Questo file è troppo grande per essere un backup di Nightingale TV.';

  @override
  String get thisBackupWas =>
      'Questo backup è stato creato da una versione più recente di Nightingale TV.';

  @override
  String get thisFileIsnt =>
      'Questo file non è un backup di Nightingale TV o è danneggiato.';

  @override
  String restoredTheBackup(Object toLocal) {
    return 'Backup del $toLocal ripristinato.';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'Impossibile ripristinare il backup: $e';
  }

  @override
  String couldntSaveA(Object e) {
    return 'Impossibile salvare prima un backup: $e';
  }

  @override
  String get madeByYou => 'Creato da te';

  @override
  String get fromNightingaleTv => 'Da Nightingale TV (versione personale)';

  @override
  String get fromNightingaleTv2 => 'Da Nightingale TV';

  @override
  String get movingToNightingale =>
      'Trasferimento a Nightingale TV (versione personale)';

  @override
  String get movingToNightingaleTv => 'Trasferimento a Nightingale TV';

  @override
  String get fromAFile => 'Da un file';

  @override
  String get beforeLineupCleanup => 'Prima della pulizia del palinsesto';

  @override
  String get beforeUpdate => 'Prima dell\'aggiornamento';

  @override
  String beforeDeleting(Object subject) {
    return 'Prima di eliminare $subject';
  }

  @override
  String get beforeDeletingA => 'Prima di eliminare un profilo';

  @override
  String get beforeReset => 'Prima del ripristino iniziale';

  @override
  String get beforeRestore => 'Prima del ripristino';

  @override
  String get automatic => 'Automatico';

  @override
  String get nc1718 => 'NC-17 / 18 o superiore';

  @override
  String get tvMaR => 'TV-MA / R o superiore';

  @override
  String get tv14Pg => 'TV-14 / PG-13 o superiore';

  @override
  String get off => 'Disattivato';

  @override
  String get nowAndThen => 'Ogni tanto';

  @override
  String get always => 'Sempre';

  @override
  String get truncate => 'Taglia';

  @override
  String get offlineImage => 'Immagine fuori onda';

  @override
  String get filler => 'Riempitivo';

  @override
  String get leastWatchedFirst => 'Prima i meno visti';

  @override
  String get shuffled => 'Casuale';

  @override
  String get inOrderShows => 'In ordine (le serie si alternano)';

  @override
  String get channelsWhereEverything =>
      'Canali in cui tutto ciò che va in onda, blocchi inclusi, è classificato TV-Y, TV-Y7, TV-G o G.';

  @override
  String get musicVideoAnd => 'Canali di video musicali e radio.';

  @override
  String get channelsThatPlay =>
      'Canali che trasmettono film, senza episodi né musica.';

  @override
  String get channelsFromYour => 'Canali dalle tue fonti TV in diretta.';

  @override
  String get channelsYouMarked => 'Canali che hai segnato come preferiti.';

  @override
  String get everyChannel => 'Tutti i canali.';

  @override
  String get kids => 'Bambini';

  @override
  String get movies => 'Film';

  @override
  String get liveTv2 => 'TV in diretta';

  @override
  String get favorites => 'Preferiti';

  @override
  String get all => 'Tutti';

  @override
  String get theAccentsAre =>
      'Gli accenti sono un tema e «theme» o «channel» per ciascuno.';

  @override
  String get thoseArentRetro => 'Queste non sono impostazioni retrò.';

  @override
  String get theOverlayTheme =>
      'Il tema della sovrimpressione è standard, vcr, cableBox o stationIdent.';

  @override
  String get theCrtEffect =>
      'L\'effetto CRT è off, softTube, livingRoom, arcade, studioMonitor o custom.';

  @override
  String get theSurroundImage => 'L\'immagine di contorno è un nome di file.';

  @override
  String get theSurroundIs => 'Il contorno è black, charcoal, channel o image.';

  @override
  String get thePictureShape =>
      'La forma dell\'immagine è original, fill43 o fit43.';

  @override
  String get channelColor => 'Colore del canale';

  @override
  String get theme => 'Tema';

  @override
  String get stationIdent => 'Sigla del canale';

  @override
  String get cableBox => 'Decoder';

  @override
  String get vcr => 'Videoregistratore';

  @override
  String get standard => 'Standard';

  @override
  String get custom => 'Personalizzato';

  @override
  String get studioMonitor => 'Monitor da studio';

  @override
  String get arcade => 'Sala giochi';

  @override
  String get livingRoom => 'Soggiorno';

  @override
  String get softTube => 'Tubo morbido';

  @override
  String get customColorIs =>
      'Il colore personalizzato è natural, warm, faded o vivid.';

  @override
  String get customLinesIs => 'Le righe personalizzate sono 240 o 480.';

  @override
  String customIsOff(Object key) {
    return '$key personalizzato è off, low, medium o high.';
  }

  @override
  String get thatIsntA => 'Questo non è uno stile personalizzato.';

  @override
  String get vivid => 'Vivace';

  @override
  String get faded => 'Sbiadito';

  @override
  String get warm => 'Caldo';

  @override
  String get natural => 'Naturale';

  @override
  String get high => 'Alto';

  @override
  String get medium => 'Medio';

  @override
  String get low => 'Basso';

  @override
  String get image => 'Immagine';

  @override
  String get charcoal => 'Antracite';

  @override
  String get black => 'Nero';

  @override
  String get n43Fit => '4:3 adatta';

  @override
  String get n43Fill => '4:3 riempi';

  @override
  String get original => 'Originale';

  @override
  String get thisChannelIs => 'Questo canale è fuori onda';

  @override
  String get offAir => 'Fuori onda';

  @override
  String get tail => 'Riempimento';

  @override
  String get postRoll => 'Post-roll';

  @override
  String get midRoll => 'Mid-roll';

  @override
  String get preRoll => 'Pre-roll';

  @override
  String get commercials => 'Pubblicità';

  @override
  String get bumpers => 'Stacchi';

  @override
  String get pleaseStandBy => 'ATTENDERE PREGO';

  @override
  String get offTheAir => 'FUORI ONDA';

  @override
  String get wellBeRight => 'Torniamo subito';

  @override
  String upNextAt(Object at) {
    return 'A seguire alle $at';
  }

  @override
  String backOnThe(Object next, Object title) {
    return 'Di nuovo in onda $next con $title';
  }

  @override
  String get processor => 'Processore';

  @override
  String get graphicsCardNvenc => 'Scheda grafica (NVENC)';

  @override
  String get graphicsCardVaapi => 'Scheda grafica (VAAPI)';

  @override
  String get signInTo =>
      'Accedi a questo profilo sulla TV per esportarne i canali.';

  @override
  String get signInToThis =>
      'Accedi a questo profilo qui per esportarne i canali.';

  @override
  String portIsIn(Object port) {
    return 'La porta $port è usata da un altro programma. Scegli un\'altra porta, poi aggiornala in Plex o Jellyfin.';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'Un altro profilo usa già la porta $port.';
  }

  @override
  String get pickAPort => 'Scegli una porta tra 1024 e 65535.';

  @override
  String get movie => 'Film';

  @override
  String backOnTheAir(Object start, Object title) {
    return 'Di nuovo in onda $start con $title.';
  }

  @override
  String get images => 'Immagini';

  @override
  String get couldNotRead =>
      'Impossibile leggere l\'immagine. Prova PNG, JPG, WebP o SVG.';

  @override
  String get thatFileIs => 'Questo file non è un SVG valido.';

  @override
  String get thatImageIs =>
      'L\'immagine supera i 20 MB. Scegline una più piccola.';

  @override
  String get other => 'Altro';

  @override
  String get seasonsHolidays => 'Stagioni e festività';

  @override
  String get newsWeather => 'Notizie e meteo';

  @override
  String get sports => 'Sport';

  @override
  String get genres => 'Generi';

  @override
  String get kidsFamily => 'Bambini e famiglia';

  @override
  String get tvMovies => 'TV e film';

  @override
  String get theServerWould => 'Il server non ha convertito questo elemento.';

  @override
  String get theServerHas =>
      'Il server non ha una versione riproducibile di questo elemento.';

  @override
  String get externalLabel => 'Esterni';

  @override
  String get scanningChannelSources => 'Analisi delle fonti dei canali…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl non ha risposto come un server Jellyfin.';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return 'Nessun server Jellyfin trovato su $serverUrl. $message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return 'Errore del server $statusCode su $path.';
  }

  @override
  String get wrongUsernameOr =>
      'Nome utente o password errati, oppure la sessione è scaduta.';

  @override
  String couldNotReach(Object e) {
    return 'Impossibile raggiungere il server ($e).';
  }

  @override
  String get theServerTook =>
      'Il server ha impiegato troppo tempo a rispondere.';

  @override
  String get theServerWouldNot => 'Il server non ha convertito questo canale.';

  @override
  String get musicVideo => 'Video musicale';

  @override
  String movie2(Object year) {
    return 'Film · $year';
  }

  @override
  String get commercial => 'Pubblicità';

  @override
  String couldntReachThe(Object what) {
    return '$what: impossibile raggiungere';
  }

  @override
  String theIsToo(Object what) {
    return '$what: troppo grande';
  }

  @override
  String theSAddress(Object what) {
    return '$what: l\'indirizzo non è un indirizzo web';
  }

  @override
  String get noGuideInformation => 'Nessuna informazione sui programmi';

  @override
  String get serverLiveTv => 'TV in diretta del server';

  @override
  String get theChannelHas => 'Il canale non ha un indirizzo di streaming.';

  @override
  String get couldntReadThe => 'Impossibile leggere la guida';

  @override
  String get couldntReachTheGuide => 'Impossibile raggiungere la guida';

  @override
  String get theSourceHas => 'La fonte non ha una playlist';

  @override
  String get couldntReachThePlaylist => 'Impossibile raggiungere la playlist';

  @override
  String get couldntReadThePlaylist =>
      'Impossibile leggere il file della playlist';

  @override
  String couldntRefresh(Object name) {
    return 'Impossibile aggiornare $name';
  }

  @override
  String get thePlaylistHas => 'La playlist non ha canali';

  @override
  String get thatIsntAn => 'Questa non è una playlist M3U';

  @override
  String get thatIsntAnXmltv => 'Questa non è una guida XMLTV';

  @override
  String get theGuideIs => 'La guida è troppo grande (oltre 1 GB)';

  @override
  String get nightingaleTvBackups => 'Backup di Nightingale TV';

  @override
  String get uninstallingThisApp =>
      'Disinstallare questa app elimina i suoi profili, canali e impostazioni, a meno che tu non ne faccia prima un backup o li trasferisca.';

  @override
  String theStoreVersion(Object officialName) {
    return 'La versione dello store si installa accanto a questa come app separata, «$officialName», con la propria configurazione. Acquistarla sostiene il progetto. Una volta installata, puoi trasferirvi la tua configurazione da qui.';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Gli aggiornamenti da Google Play e gli APK ufficiali di Nightingale TV si installano su questa e mantengono la tua configurazione. Una versione personale si installa come app separata, «$ownBuildName», e puoi trasferirvi la tua configurazione da qui.';
  }

  @override
  String get yourOwnBuild => 'La tua versione personale';

  @override
  String get officialNightingaleTv => 'APK ufficiale di Nightingale TV';

  @override
  String get installedFromGoogle => 'Installata da Google Play';

  @override
  String get nightingaleTvOwn => 'Nightingale TV (versione personale)';

  @override
  String get sleepTimerOff => 'Timer di spegnimento disattivato';

  @override
  String get sleepAtEnd => 'Spegnimento a fine programma';

  @override
  String sleepInMin(Object minutes) {
    return 'Spegnimento tra $minutes min';
  }

  @override
  String get forced => 'Forzati';

  @override
  String get unknownLanguage => 'Lingua sconosciuta';

  @override
  String didntStart(Object name) {
    return '$name non si è avviato';
  }

  @override
  String get thisDeviceCant =>
      'Questo dispositivo non può riprodurre il video di questo canale';

  @override
  String get thisChannelsStream =>
      'Il tipo di streaming di questo canale non è supportato su questo dispositivo';

  @override
  String refusedTheStream(Object name) {
    return '$name ha rifiutato lo streaming. Forse è in riproduzione su un altro dispositivo.';
  }

  @override
  String yourAccountCant(Object server) {
    return 'Il tuo account $server non può guardare questo canale';
  }

  @override
  String cantReach(Object name) {
    return 'Impossibile raggiungere $name';
  }

  @override
  String allOfS(Object server) {
    return 'Tutti i sintonizzatori di $server sono in uso';
  }

  @override
  String lostTheSignal(Object name) {
    return 'Segnale perso su $name';
  }

  @override
  String get couldntPlayThat =>
      'Impossibile riprodurre quella parte. Ritorno alla diretta';

  @override
  String get backToLive => 'Ritorno alla diretta';

  @override
  String get theServerTookToo =>
      'Il server ha impiegato troppo tempo per iniziare a convertire questo programma.';

  @override
  String get nothingToPlay => 'Niente da riprodurre su questo canale';

  @override
  String captionsOn(Object shown) {
    return 'Sottotitoli attivi: $shown';
  }

  @override
  String get captionsOn2 => 'Sottotitoli attivi';

  @override
  String get captionsOnNo =>
      'Sottotitoli attivi: nessun sottotitolo per questo programma';

  @override
  String get captionsOff => 'Sottotitoli disattivati';

  @override
  String get guest => 'Ospite';

  @override
  String get thereHasTo => 'Deve esserci almeno un profilo adulto.';

  @override
  String get switchToAnother =>
      'Passa a un altro profilo prima di eliminare questo.';

  @override
  String get me => 'Io';

  @override
  String get couldntOpenA =>
      'Impossibile aprire una porta di rete per il telecomando.';

  @override
  String get notPaired => 'Non associato';

  @override
  String get phone => 'Telefono';

  @override
  String get thatCodeDoesnt =>
      'Il codice non corrisponde. Controlla il codice sulla TV.';

  @override
  String get openMenuPhone =>
      'Apri Menu → Telecomando sul telefono sulla TV per associare';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'Il tuo account $serverName non può guardare la TV in diretta';
  }

  @override
  String get enterYourServer => 'Inserisci l\'indirizzo del tuo server.';

  @override
  String get needsSignIn => 'Accesso necessario';

  @override
  String get cantBeReached => 'Non raggiungibile';

  @override
  String isNotAnswering(Object name) {
    return '$name non risponde a nessuno dei suoi indirizzi. È acceso?';
  }

  @override
  String get everyServerOn =>
      'Tutti i server di questo account Plex sono già in questo profilo.';

  @override
  String get thisPlexAccount =>
      'Questo account Plex non ha server. Chiedi al proprietario del server di condividerlo con te.';

  @override
  String quickConnectStopped(Object message) {
    return 'Quick Connect si è interrotto: $message';
  }

  @override
  String get enterYourUsername => 'Inserisci il tuo nome utente.';

  @override
  String get plexDidNot => 'Plex non ha cambiato utente.';

  @override
  String plexTvError(Object statusCode) {
    return 'Errore plex.tv $statusCode.';
  }

  @override
  String get yourPlexSign => 'L\'accesso a Plex è scaduto.';

  @override
  String couldNotReachPlex(Object e) {
    return 'Impossibile raggiungere plex.tv ($e).';
  }

  @override
  String get plexTvTook => 'plex.tv ha impiegato troppo tempo a rispondere.';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — Condiviso da $ownerName';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'Il server non ha convertito questo elemento ($transcodeDecisionText).';
  }

  @override
  String get theServerHasNo =>
      'Il server non ha alcun file per questo elemento. Aggiorna la libreria.';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl non ha risposto come un server Plex.';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return 'Nessun server Plex trovato su $serverUrl. $message';
  }

  @override
  String get thePlexSign => 'L\'accesso a Plex è scaduto.';

  @override
  String channelIsNot(Object channelId) {
    return 'Il canale $channelId non è su nessun DVR.';
  }

  @override
  String get noSuchUser => 'Utente inesistente.';

  @override
  String get yourCurrentPassword => 'La password attuale è errata.';

  @override
  String get signInFirst => 'Accedi prima.';

  @override
  String thereIsAlready(Object name) {
    return 'Esiste già un utente di nome $name.';
  }

  @override
  String get thisAccountIs => 'Questo account è disattivato.';

  @override
  String get chooseAnAdmin => 'Scegli un account amministratore.';

  @override
  String useAtMost(Object maxNameLength) {
    return 'Usa al massimo $maxNameLength caratteri per il nome utente.';
  }

  @override
  String get enterAUser => 'Inserisci un nome utente.';

  @override
  String useAtLeast(Object minPasswordLength) {
    return 'Usa almeno $minPasswordLength caratteri.';
  }

  @override
  String get tooManyWrong => 'Troppe password errate. Riprova tra un minuto.';

  @override
  String get wrongUserName => 'Nome utente o password errati.';

  @override
  String get openTheSetup =>
      'Apri il link di configurazione dal log del server.';

  @override
  String get makeSomeoneElse => 'Rendi prima amministratore un\'altra persona.';

  @override
  String get noSuchProfile => 'Profilo inesistente.';

  @override
  String get onlyAnAdmin => 'Solo un amministratore può farlo.';

  @override
  String get thatProfileIsnt => 'Quel profilo non è assegnato a te.';

  @override
  String get enterAGrown =>
      'Inserisci il PIN di un adulto per modificare le impostazioni di un profilo bambino.';

  @override
  String get enterThisProfiles => 'Inserisci il PIN di questo profilo.';

  @override
  String get reloadThePage => 'Ricarica la pagina e riprova.';

  @override
  String somethingWentWrong(Object e) {
    return 'Si è verificato un errore: $e';
  }

  @override
  String get signInToThisProfile => 'Accedi prima a questo profilo.';

  @override
  String get changedInAnother =>
      'Modificato in un\'altra finestra. Viene mostrata l\'ultima versione.';

  @override
  String get wrongPin => 'PIN errato.';

  @override
  String get tooManyWrongPins => 'Troppi PIN errati. Riprova tra un minuto.';

  @override
  String get theRoleIs => 'Il ruolo è «admin» o «user».';

  @override
  String get noSuchBackup => 'Backup inesistente.';

  @override
  String get backupsAreOff => 'I backup sono disattivati.';

  @override
  String get noSuchEncoder => 'Codificatore inesistente.';

  @override
  String get allow1To => 'Consenti da 1 a 16 flussi.';

  @override
  String get noSuchQuality => 'Qualità inesistente.';

  @override
  String get processorOnly => 'Solo processore';

  @override
  String get liveTvExport =>
      'L\'esportazione TV in diretta non è in esecuzione.';

  @override
  String get thoseArentPremiere =>
      'Queste non sono impostazioni delle prime visioni.';

  @override
  String get theLogoMode => 'La modalità del logo è always, nowAndThen o off.';

  @override
  String get thatIsntAPicture =>
      'Questa non è un\'immagine della cartella dei loghi personalizzati.';

  @override
  String couldntSaveASafety(Object e) {
    return 'Impossibile salvare prima un backup di sicurezza, quindi non è stato reimpostato nulla: $e';
  }

  @override
  String get theKindIs => 'Il tipo è «block», «music» o «custom».';

  @override
  String get thatIsntAPlay => 'Questo non è un ordine di riproduzione.';

  @override
  String get musicChannelsOnly => 'I canali musicali sono solo casuali.';

  @override
  String get channelNumbersStart => 'I numeri dei canali iniziano da 1.';

  @override
  String get slotLengthsAre => 'Le fasce durano 15, 30, 60, 90 o 120 minuti.';

  @override
  String get thatIsntAChannel => 'Questo non è un canale.';

  @override
  String get noSuchChannel => 'Canale inesistente.';

  @override
  String get thatPictureIs => 'L\'immagine è troppo grande (5 MB al massimo).';

  @override
  String get unknownAction => 'Azione sconosciuta.';

  @override
  String get noSuchServer => 'Server inesistente.';

  @override
  String get startSigningIn => 'Avvia prima l\'accesso.';

  @override
  String get aRestoreIs => 'È già in corso un ripristino.';

  @override
  String get uploadTheBackup => 'Carica di nuovo il backup.';

  @override
  String get discoveryIsOff =>
      'Il rilevamento è disattivato, quindi aggiungi il sintonizzatore tramite indirizzo. Esegui il container con la rete host per attivarlo.';

  @override
  String get sendKeys => 'Invia «keys».';

  @override
  String get enterThePlaylists =>
      'Inserisci l\'indirizzo della playlist o scegli un file di playlist';

  @override
  String get uploadTheFile => 'Carica di nuovo il file.';

  @override
  String get kidProfilesGet => 'I profili bambino non hanno canali in diretta.';

  @override
  String liveTvIsAlready(Object name) {
    return 'La TV in diretta di $name è già aggiunta';
  }

  @override
  String get noSuchSource => 'Fonte inesistente.';

  @override
  String get thatFileIsToo => 'Il file è troppo grande (32 MB al massimo).';

  @override
  String get aPinIs => 'Un PIN è di 4 cifre.';

  @override
  String get noSuchRating => 'Classificazione inesistente.';

  @override
  String get noSuchKind => 'Tipo inesistente.';

  @override
  String get onlyAnAdminCan => 'Solo un amministratore può modificarlo.';

  @override
  String shouldBeA(Object key) {
    return '«$key» deve essere un elenco di testi.';
  }

  @override
  String shouldBeAn(Object key) {
    return '«$key» deve essere un oggetto.';
  }

  @override
  String shouldBeTrue(Object key) {
    return '«$key» deve essere vero o falso.';
  }

  @override
  String shouldBeANumber(Object key) {
    return '«$key» deve essere un numero.';
  }

  @override
  String shouldBeText(Object key) {
    return '«$key» deve essere testo.';
  }

  @override
  String get expectedAJson => 'Atteso un oggetto JSON.';

  @override
  String get thatIsToo => 'È troppo da inviare in una volta.';

  @override
  String get aQualityLimit => 'Un limite di qualità è di almeno 500 kbps.';

  @override
  String get orderShouldName => '«order» deve indicare ogni server una volta.';

  @override
  String get orderIsMissing => 'Manca «order».';

  @override
  String get signOutOf =>
      'Esci dal profilo per cambiarne il server principale.';

  @override
  String get thoseArentPool => 'Queste non sono cartelle di gruppo.';

  @override
  String get sendRoots => 'Invia «roots».';

  @override
  String get thatIsntAPool => 'Questo non è un tipo di gruppo.';

  @override
  String get giveThePool => 'Dai un nome al gruppo.';

  @override
  String get liveChannelsHave => 'I canali in diretta non hanno pause.';

  @override
  String get sendAPlan => 'Invia un piano.';

  @override
  String get thatIsntABreak => 'Questo non è un piano di pause.';

  @override
  String get noSuchPool => 'Gruppo inesistente.';

  @override
  String get thatIsntAProgramming =>
      'Questo non è un blocco di programmazione.';

  @override
  String get noSuchBlock => 'Blocco inesistente.';

  @override
  String get sendEveryTab => 'Invia ogni scheda una volta.';

  @override
  String get sendChannelids => 'Invia «channelIds».';

  @override
  String get giveTheGroup => 'Dai un nome al gruppo.';

  @override
  String get noSuchGroup => 'Gruppo inesistente.';

  @override
  String get restoringBringsBack =>
      'Il ripristino riporta i tuoi profili, canali, blocchi e impostazioni. Ogni profilo accede una volta al proprio server.';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels canali',
      one: '$profiles · $channels canale',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup =>
      'Su questo dispositivo c\'è un backup della tua configurazione:';

  @override
  String get welcomeBack => 'Bentornato';

  @override
  String get moveOkSelect => '◀▶ Sposta    OK Seleziona';

  @override
  String get startFresh => 'Ricomincia da capo';

  @override
  String get restoreIt => 'Ripristinalo';

  @override
  String get couldntRestore => 'Impossibile ripristinare';

  @override
  String get cancel => 'Annulla';

  @override
  String get useYourPhone => 'Usa il telefono o il computer';

  @override
  String get openABackup => 'Apri un file di backup';

  @override
  String get setUpThis =>
      'Configura questa TV da un backup di Nightingale TV: i tuoi profili, canali, blocchi e impostazioni. Ogni profilo accede una volta al proprio server.';

  @override
  String get restoreFromA => 'Ripristina da un backup';

  @override
  String get close => 'Chiudi';

  @override
  String get thereYouCan =>
      'Lì puoi scaricare un backup di questa TV o inviarne uno da ripristinare qui. Ogni invio viene prima confermato su questa TV. La pagina si chiude con questa finestra.';

  @override
  String get onAPhone =>
      'Su un telefono, tablet o computer collegato allo stesso Wi-Fi di questa TV, scansiona il codice o apri:';

  @override
  String get couldntOpenANetwork =>
      'Impossibile aprire una porta di rete per la pagina.';

  @override
  String get thePageStopped =>
      'La pagina si è fermata dopo 15 minuti di inattività. Chiudi e riaprila.';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount e $last';
  }

  @override
  String get restore => 'Ripristina';

  @override
  String get liveTvExportMoves =>
      'L\'esportazione TV in diretta passa a questo dispositivo. Disattivala su quello vecchio.';

  @override
  String willNeedTo(Object need) {
    return '$need dovrà accedere di nuovo al proprio server.';
  }

  @override
  String get itSetsUp => 'Configura questa TV come nel backup.';

  @override
  String get itReplacesEverything =>
      'Sostituisce tutto su questa TV. Prima viene salvato un backup della configurazione attuale.';

  @override
  String restoreTheBackup(Object toLocal) {
    return 'Ripristinare il backup del $toLocal?';
  }

  @override
  String get delete => 'Elimina';

  @override
  String get saveToFile => 'Salva su file';

  @override
  String madeOn(Object device) {
    return 'Creato su $device';
  }

  @override
  String get moveOkSelectEsc => '▲▼◀▶ Sposta    OK Seleziona    ESC Indietro';

  @override
  String get backupRestore => 'Backup e ripristino';

  @override
  String get backups => 'BACKUP';

  @override
  String get backUpNow => 'Esegui backup ora';

  @override
  String get aBackupHolds =>
      'Un backup contiene ogni profilo con canali, blocchi, pubblicità e impostazioni, e viene creato ogni giorno in cui qualcosa cambia. Le password di accesso non sono mai incluse.';

  @override
  String lastBackup(Object toLocal, Object kindLabel) {
    return 'Ultimo backup: $toLocal ($kindLabel).';
  }

  @override
  String get noBackupsYet => 'Ancora nessun backup.';

  @override
  String itCantBe(Object toLocal, Object kindLabel) {
    return '$toLocal · $kindLabel. Non potrà essere recuperato.';
  }

  @override
  String get deleteThisBackup => 'Eliminare questo backup?';

  @override
  String couldntSaveThe(Object e) {
    return 'Impossibile salvare il backup: $e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'Non ha funzionato: $e';
  }

  @override
  String get aNewChannel =>
      'Un nuovo canale è fuori onda al di fuori del blocco, come un canale che chiude di notte.';

  @override
  String get aNewChannelJust => 'Un nuovo canale solo per questo blocco';

  @override
  String get moveOkChoose => '▲▼ Sposta    OK Scegli    ESC Indietro';

  @override
  String get chooseAChannel2 => 'Scegli un canale';

  @override
  String episodes(Object keyCount) {
    return 'Episodi: $keyCount';
  }

  @override
  String get moveOkAdd => '▲▼ Sposta    OK Aggiungi    ESC Indietro';

  @override
  String get addAShow2 => 'Aggiungi una serie';

  @override
  String get remove => 'Rimuovi';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodi',
      one: '$count episodio',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ Mese';

  @override
  String get day => '+ Giorno';

  @override
  String get day2 => '− Giorno';

  @override
  String get month2 => '− Mese';

  @override
  String get save => 'Salva';

  @override
  String get everyDay => 'Ogni giorno';

  @override
  String get weekends => 'Fine settimana';

  @override
  String get weekdays => 'Giorni feriali';

  @override
  String get days => 'GIORNI';

  @override
  String get starts => 'Inizio';

  @override
  String get time => 'ORARIO';

  @override
  String get premieresAreOff => 'Le prime visioni sono disattivate';

  @override
  String get premieresAreOn => 'Le prime visioni sono attive';

  @override
  String get onTheAir => 'IN ONDA';

  @override
  String get episodesAddedTo =>
      'Gli episodi aggiunti al tuo server nelle ultime due settimane vanno in prima visione in una fascia notturna sul canale della loro serie: un nuovo episodio per serie ogni notte, fino a due ore, contrassegnato come NUOVO. I blocchi di programmazione hanno la precedenza.';

  @override
  String get moveOkSelectEscCancel =>
      '▲▼◀▶ Sposta    OK Seleziona    ESC Annulla';

  @override
  String get newEpisodePremieres => 'Prime visioni di nuovi episodi';

  @override
  String get theChannelGoes =>
      'Il canale torna alla programmazione normale in questi orari.';

  @override
  String delete2(Object title) {
    return 'Eliminare «$title»?';
  }

  @override
  String get addAnotherShow => 'Aggiungi un\'altra serie';

  @override
  String get missingShow => 'Serie mancante';

  @override
  String runsThenStarts(Object start) {
    return 'Dura $start, poi ricomincia.';
  }

  @override
  String get fillsTheBlock => 'Riempie il blocco.';

  @override
  String longerThanThe(Object end, Object title) {
    return 'Più lungo del blocco: finisce alle $end, tagliando $title.';
  }

  @override
  String get onTheAirNow => 'IN ONDA ORA';

  @override
  String nextAiring(Object start) {
    return 'PROSSIMA MESSA IN ONDA · $start';
  }

  @override
  String inAll(Object runtime) {
    return '$runtime in tutto';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies film',
      one: '$movies film',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount serie',
      one: '$showsCount serie',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => 'Ancora niente. Scegli serie o film.';

  @override
  String get nothingYetAdd => 'Ancora niente. Aggiungi serie al palinsesto.';

  @override
  String get plays => 'TRASMETTE';

  @override
  String onLabel(Object number, Object name) {
    return 'Su $number $name';
  }

  @override
  String get noChannelChosen => 'Nessun canale scelto';

  @override
  String get onANew => 'Su un nuovo canale (fuori onda negli altri orari)';

  @override
  String get untitledBlock => 'Blocco senza titolo';

  @override
  String get deleteBlock => 'Elimina blocco';

  @override
  String get blockIsOff => 'Il blocco è disattivato';

  @override
  String get blockIsOn => 'Il blocco è attivo';

  @override
  String get onlyShowsAnd =>
      'Solo serie e film con questa classificazione o superiore. Quelli senza classificazione sono esclusi.';

  @override
  String get anyRating => 'Qualsiasi classificazione';

  @override
  String get minimumRating => 'Classificazione minima';

  @override
  String get chooseShowsMovies => 'Scegli serie e film';

  @override
  String get showsAndMovies =>
      'Serie e film a tua scelta, in ordine o casuali.';

  @override
  String get yourShowsIn =>
      'Le tue serie in questo ordine, ognuna con l\'episodio successivo a ogni messa in onda. Se avanza tempo, il palinsesto ricomincia.';

  @override
  String get aLineup => 'Un palinsesto';

  @override
  String get aMix => 'Un mix';

  @override
  String get whatItPlays => 'COSA TRASMETTE';

  @override
  String get repeatsEveryYear => 'Si ripete ogni anno.';

  @override
  String get to => 'A';

  @override
  String get from => 'Da';

  @override
  String get onlyBetweenDates => 'Solo tra due date';

  @override
  String get allYear => 'Tutto l\'anno';

  @override
  String get dates => 'DATE';

  @override
  String get nextDay => ' (giorno dopo)';

  @override
  String get ends => 'Fine';

  @override
  String get channel => 'CANALE';

  @override
  String get saturdayMorningCartoons => 'Cartoni del sabato mattina';

  @override
  String get title => 'Titolo';

  @override
  String get newProgrammingBlock => 'Nuovo blocco di programmazione';

  @override
  String get newLateNight => 'Nuovo blocco notturno';

  @override
  String get editProgrammingBlock => 'Modifica blocco di programmazione';

  @override
  String next(Object next, Object next2) {
    return 'Prossima: $next $next2';
  }

  @override
  String get onTheAirNow2 => 'In onda ora';

  @override
  String get noUpcomingAirings => 'Nessuna messa in onda prevista';

  @override
  String get itsChannelIs =>
      'Il suo canale non esiste più. Scegline uno nuovo.';

  @override
  String get turnedOff => 'Disattivato';

  @override
  String get blocksTakeOver =>
      'I blocchi prendono il controllo di un canale nei giorni e negli orari che scegli, come i cartoni del sabato mattina. Ogni messa in onda riprende da dove si era fermata l\'ultima.';

  @override
  String get moveOkEdit => '▲▼ Sposta    OK Modifica    ESC Indietro';

  @override
  String get programmingBlocks => 'Blocchi di programmazione';

  @override
  String get newlyAddedEpisodes =>
      'Episodi aggiunti di recente, sul canale della loro serie';

  @override
  String get onLabel2 => 'Attivo';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips clip',
      one: '$name  ·  $clips clip',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => 'Film da 100 min';

  @override
  String get n44MinDrama => 'Drama da 44 min';

  @override
  String get n22MinSitcom => 'Sitcom da 22 min';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: ', $midCount pause interne',
      one: ', $midCount pausa interna',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name: nessuna pausa';
  }

  @override
  String get openAndClose =>
      'Aprono e chiudono le pause, dai gruppi impostati su Stacchi';

  @override
  String get bumpers2 => 'STACCHI';

  @override
  String get toTheHalf => 'Alla mezz\'ora';

  @override
  String get toTheHour => 'All\'ora esatta';

  @override
  String get padsEachSlot =>
      'Riempie ogni fascia fino all\'orario, così i programmi iniziano puntuali';

  @override
  String get tail2 => 'RIEMPIMENTO';

  @override
  String get afterEachProgram => 'Dopo ogni programma';

  @override
  String get postRoll2 => 'POST-ROLL';

  @override
  String get length => 'Durata';

  @override
  String get every => 'Ogni';

  @override
  String min(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get breaksInsideShows =>
      'Pause dentro serie e film, ai cambi d\'atto quando rilevabili';

  @override
  String get midRoll2 => 'MID-ROLL';

  @override
  String get beforeEachProgram => 'Prima di ogni programma';

  @override
  String get preRoll2 => 'PRE-ROLL';

  @override
  String get onePool => 'Un gruppo…';

  @override
  String get allBumperPools => 'Tutti i gruppi di stacchi';

  @override
  String get none => 'Nessuno';

  @override
  String clipsFrom(Object pool) {
    return 'Clip da: $pool';
  }

  @override
  String get allPools => 'Tutti i gruppi';

  @override
  String clips2(Object label) {
    return 'Clip di $label';
  }

  @override
  String get leave => 'Esci';

  @override
  String get yourChangesTo =>
      'Le modifiche alle impostazioni delle pause andranno perse.';

  @override
  String get leaveWithoutSaving => 'Uscire senza salvare?';

  @override
  String get size => 'Dimensione';

  @override
  String get captions => 'Sottotitoli';

  @override
  String get sampleCaption => 'Esempio di sottotitolo';

  @override
  String get theServerDraws =>
      'Il server disegna questi sottotitoli nell\'immagine, quindi la dimensione non può cambiare qui.';

  @override
  String get findingSubtitles => 'Ricerca sottotitoli…';

  @override
  String get noSubtitlesFor => 'Nessun sottotitolo per questo programma';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours h $inMinutes min';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed giorni';
  }

  @override
  String get theChannelGoesAway =>
      'Il canale viene rimosso, con i suoi blocchi di programmazione e i suoi posti nei gruppi di canali.';

  @override
  String remove2(Object name) {
    return 'Rimuovere «$name»?';
  }

  @override
  String contentOf(Object name) {
    return 'Contenuto di $name';
  }

  @override
  String get newChannel => 'Nuovo canale';

  @override
  String get defaultCard => 'Scheda predefinita';

  @override
  String get changeOfflineImage => 'Cambia immagine fuori onda…';

  @override
  String get offlineImage2 => 'Immagine fuori onda…';

  @override
  String fillerPool(Object poolName) {
    return 'Gruppo di riempimento: $poolName';
  }

  @override
  String get slotLength => 'DURATA FASCIA';

  @override
  String get hideFromGuide => 'Nascondi dalla guida';

  @override
  String get showInGuide => 'Mostra nella guida';

  @override
  String get favorite => 'Preferito';

  @override
  String get unfavorite => 'Rimuovi dai preferiti';

  @override
  String mainSetting(Object label) {
    return 'Impostazione principale ($label)';
  }

  @override
  String get channelLogo => 'LOGO DEL CANALE';

  @override
  String breaksOn(Object name) {
    return 'Pause su $name';
  }

  @override
  String get custom2 => 'Personalizzato…';

  @override
  String get commercials2 => 'PUBBLICITÀ';

  @override
  String get removeChannel => 'Rimuovi canale';

  @override
  String get reshuffle => 'Rimescola';

  @override
  String get editContent => 'Modifica contenuto';

  @override
  String get number => 'Numero +';

  @override
  String get number2 => 'Numero −';

  @override
  String get sourcesLogo => 'Logo della fonte';

  @override
  String get changeIcon => 'Cambia icona';

  @override
  String get rename => 'Rinomina';

  @override
  String get channelName => 'Nome del canale';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount blocchi di programmazione',
      one: '$blockCount blocco di programmazione',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return 'si ripete ogni $loop';
  }

  @override
  String programs(Object playlistCount) {
    return 'Programmi: $playlistCount';
  }

  @override
  String get programmingBlocksOnly => 'Solo blocchi di programmazione';

  @override
  String channelThere(Object n) {
    return 'canale $n lì';
  }

  @override
  String channel2(Object number) {
    return 'CANALE $number';
  }

  @override
  String get noChannelsYet => 'Ancora nessun canale';

  @override
  String get guideRange => 'INTERVALLO GUIDA';

  @override
  String get channelsEditOk =>
      '▲▼ Canali    ▶ Modifica    OK Seleziona    ESC Indietro';

  @override
  String get channelsIcons => 'Canali e icone';

  @override
  String get howFarAhead => 'Fin dove arriva la guida, a partire da ora.';

  @override
  String hours(Object hours) {
    return '$hours ore';
  }

  @override
  String get theChannelLogo =>
      'Il logo del canale nell\'angolo dell\'immagine, sulla TV e nell\'esportazione TV in diretta.';

  @override
  String get name => 'Nome';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'CANALI';

  @override
  String get groupName => 'Nome del gruppo';

  @override
  String group(Object name) {
    return 'Gruppo: $name';
  }

  @override
  String get deleteGroup => 'Elimina gruppo';

  @override
  String get itsTabLeaves =>
      'La sua scheda esce dalla guida. I canali restano nel tuo palinsesto.';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount canali',
      one: '$membersCount canale',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => 'Canali che hai scelto.';

  @override
  String get theTabsAt =>
      'Le schede in alto nella guida, in questo ordine. Le schede nascoste e quelle senza canali non vengono mostrate.';

  @override
  String get channelGroups => 'Gruppi di canali';

  @override
  String get shown => 'Visibile';

  @override
  String get down => 'Giù';

  @override
  String get up => 'Su';

  @override
  String get automatic2 => '· automatico';

  @override
  String channels4(Object channelIdsCount) {
    return '· Canali: $channelIdsCount';
  }

  @override
  String get create => 'Crea';

  @override
  String get commercialsNeverShow =>
      'La pubblicità non compare mai nella cronologia del tuo server.';

  @override
  String get theSameAds =>
      'Le stesse pubblicità vanno in onda per tutti, ogni volta.';

  @override
  String get bumperPoolsClips =>
      'Le clip dei gruppi di stacchi aprono e chiudono le pause, e non vanno mai in onda come pubblicità.';

  @override
  String get howBreaksWork => 'COME FUNZIONANO LE PAUSE';

  @override
  String get withATail =>
      'Con il riempimento, le fasce vengono completate fino all\'orario.';

  @override
  String get adsShrinkTo =>
      'Le pubblicità si adattano alla fascia e nessuna pausa supera i 5 minuti.';

  @override
  String get aShortBreak =>
      'Una breve pausa prima del programma, una pausa ogni 10 minuti durante (12 per i film), ai cambi d\'atto quando rilevabili, e il resto dopo.';

  @override
  String get pickAutomaticFor =>
      'Scegli Automatico per pause come in TV, o Personalizzato per impostarle tu.';

  @override
  String workingOn(Object current) {
    return 'Elaborazione di $current…';
  }

  @override
  String get analysis => 'ANALISI';

  @override
  String couldNotBe(Object failed) {
    return '$failed non analizzati (nuovo tentativo se il file cambia)';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'Programmi con punti di pausa: $programsDone di $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return 'Video lunghi divisi: $reelsDone di $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders cartelle  ·  $idCount',
      one: '$folders cartella  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$clips da $used gruppi di pubblicità.',
      one: '$clips da $used gruppo di pubblicità.',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'Le pause iniziano quando un gruppo ha delle clip. Aggiungi a un gruppo cartelle con video.';

  @override
  String get breaksStartOnceA =>
      'Le pause iniziano quando un gruppo ha delle clip. I suoi video lunghi sono in fase di divisione.';

  @override
  String get breaksStartOnceAPool =>
      'Le pause iniziano quando un gruppo ha delle clip. Crea un gruppo qui sotto.';

  @override
  String breaksAreOff(Object clips) {
    return 'Le pause sono disattivate. $clips pronte nei tuoi gruppi.';
  }

  @override
  String get breaksAreOff2 => 'Le pause sono disattivate.';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n clip',
      one: '$n clip',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return 'Ultima analisi non riuscita: $syncError';
  }

  @override
  String get newPool => 'Nuovo gruppo';

  @override
  String get pickTheFolders =>
      'Scegli le cartelle del tuo server che contengono pubblicità e stacchi. I loro video lasciano i canali normali e riempiono le pause. Imposta il tipo di un gruppo su Stacchi per far aprire e chiudere le pause alle sue clip.';

  @override
  String get pools => 'GRUPPI';

  @override
  String get breakSettings => 'Impostazioni pause…';

  @override
  String get commercialBreaks => 'PAUSE PUBBLICITARIE';

  @override
  String get breakSettings2 => 'Impostazioni pause';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count Anche i punti di pausa risultano più naturali.';
  }

  @override
  String waiting(Object waiting) {
    return ' ($waiting in attesa).';
  }

  @override
  String get longCommercialVideos =>
      'I video pubblicitari lunghi senza capitoli non possono essere divisi su questo dispositivo';

  @override
  String get installFfmpegTo =>
      'Installa ffmpeg per dividere i video pubblicitari lunghi';

  @override
  String get picturesOnThis =>
      'Immagini su questo dispositivo, prima le più recenti. Quelle grandi sono ridotte a 512 px.';

  @override
  String get noPicturesOn =>
      'Ancora nessuna immagine su questo dispositivo. Copia un PNG o JPG nella cartella Download o su una chiavetta USB, poi riprova.';

  @override
  String get lookingForPictures => 'Ricerca immagini…';

  @override
  String get couldntReadThePictures =>
      'Impossibile leggere le immagini di questo dispositivo.';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV non è autorizzato a vedere le immagini di questo dispositivo. Consenti «Foto e video» in Impostazioni Android › App › Nightingale TV › Autorizzazioni, poi riprova.';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ Sposta    OK Scegli    ESC Annulla';

  @override
  String get chooseAPicture => 'Scegli un\'immagine';

  @override
  String thePoolHasnt(Object error) {
    return '$error  Il gruppo non è cambiato.';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  Non è cambiato nulla.';
  }

  @override
  String get couldntReachTheServer => 'Impossibile raggiungere il server';

  @override
  String get tryAgain => 'Riprova';

  @override
  String get nothingInside => 'Vuoto';

  @override
  String get noMovies => 'Nessun film';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount all\'interno';
  }

  @override
  String get video => 'Video';

  @override
  String collection(Object name) {
    return '$name (raccolta)';
  }

  @override
  String get included => 'Incluso';

  @override
  String get nothingInside2 => 'Vuoto.';

  @override
  String get loadingFolders => 'Caricamento cartelle…';

  @override
  String get pressOnA => 'Premi ▶ su una libreria per vederne il contenuto.';

  @override
  String get done => 'Fatto';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount selezionati';
  }

  @override
  String get nothingTickedYet =>
      'Ancora nulla di selezionato. Seleziona una libreria per usarla tutta, o ▶ per sceglierne il contenuto.';

  @override
  String get wholeLibrary => 'Intera libreria';

  @override
  String get libraries => 'LIBRERIE';

  @override
  String get loadingLibraries => 'Caricamento librerie…';

  @override
  String get moveOkTick =>
      '▲▼ Sposta    OK Seleziona    ▶ Apri    ◀ Su    ESC Annulla';

  @override
  String foldersFor(Object poolName) {
    return 'Cartelle di $poolName';
  }

  @override
  String get chooseFolders => 'Scegli cartelle';

  @override
  String get chooseWhatPlays => 'Scegli cosa va in onda su questo canale';

  @override
  String get endsEarly => 'Finisce prima';

  @override
  String get madeFromThis =>
      'Creato dalle serie e dai film di questo canale e aggiornato con la libreria. Se cambi qualcosa, diventa tuo.';

  @override
  String get fromTheLineup => 'Dal palinsesto';

  @override
  String yesterday(Object t) {
    return 'ieri $t';
  }

  @override
  String today(Object t) {
    return 'oggi $t';
  }

  @override
  String behind(Object d) {
    return '$d indietro';
  }

  @override
  String hr(Object h) {
    return '$h h';
  }

  @override
  String get underAMinute => 'meno di un minuto';

  @override
  String get noProgramming => 'Nessun programma';

  @override
  String get today2 => 'OGGI';

  @override
  String get tuning => 'SINTONIZZAZIONE…';

  @override
  String get offAir2 => 'FUORI ONDA';

  @override
  String get noSignal => 'NESSUN SEGNALE';

  @override
  String left(Object now) {
    return 'Ancora $now';
  }

  @override
  String get nothingScheduled => 'Niente in programma';

  @override
  String get back => 'Indietro';

  @override
  String get sleep => 'Spegni';

  @override
  String get menu => 'Menu';

  @override
  String get nightingaleTvGuide => 'GUIDA NIGHTINGALE TV';

  @override
  String nowPlaying(Object title) {
    return 'In riproduzione: $title';
  }

  @override
  String get mMenu => 'M Menu';

  @override
  String get escBackTo => 'ESC Torna alla TV';

  @override
  String get channelsTabsTime =>
      '▲▼ Canali     ▲ Schede     ◀▶ Orario     OK Guarda     ';

  @override
  String get color => 'Colore';

  @override
  String get channelsUsingIt =>
      'I canali che la usano tornano a un\'icona predefinita.';

  @override
  String get deleteThisIcon => 'Eliminare questa icona?';

  @override
  String get uploadImage => 'Carica immagine…';

  @override
  String get pngJpgWebp =>
      'PNG, JPG, WebP, GIF o SVG. Le immagini grandi sono ridotte automaticamente a 512 px.';

  @override
  String get genericBadgesOnly =>
      'Solo badge generici. Carica un vero logo di rete in «Le mie icone».';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'Usa questo badge';

  @override
  String get preview => 'Anteprima';

  @override
  String get shape => 'Forma';

  @override
  String get callLettersUp => 'Sigla (fino a 5 lettere)';

  @override
  String iconFor(Object name) {
    return 'Icona di $name';
  }

  @override
  String get couldntReadThat =>
      'Impossibile leggere l\'immagine. Provane un\'altra.';

  @override
  String get myIcons => 'Le mie icone';

  @override
  String get showLogos => 'Loghi delle serie';

  @override
  String get badges => 'Badge';

  @override
  String get builtIn => 'Integrate';

  @override
  String get couldntMoveThe => 'Impossibile trasferire la configurazione';

  @override
  String get send => 'Invia';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'Viene creato ora un backup di profili, canali e impostazioni, poi aperto in $counterpartName, che chiede conferma prima del ripristino. Qui non cambia nulla.';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return 'Inviare la tua configurazione a $counterpartName?';
  }

  @override
  String get parentalControls => 'Controllo genitori';

  @override
  String get notNow => 'Non ora';

  @override
  String bringMySetup(Object counterpartName) {
    return 'Porta qui la mia configurazione da $counterpartName';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return 'Trasferisci la mia configurazione a $counterpartName';
  }

  @override
  String get uninstallingEitherOne =>
      'Disinstallare una delle due prima di trasferire la configurazione che vuoi tenere elimina quella configurazione.';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName e $counterpartName sono app separate, ciascuna con i propri profili, canali e impostazioni.';
  }

  @override
  String get thankYouFor => 'Grazie per il tuo sostegno a Nightingale TV!';

  @override
  String isAlsoOn(Object counterpartName) {
    return '$counterpartName è anche su questo dispositivo';
  }

  @override
  String get aboutThisInstall => 'INFORMAZIONI SU QUESTA INSTALLAZIONE';

  @override
  String couldntOpen(Object counterpartName) {
    return 'Impossibile aprire $counterpartName.';
  }

  @override
  String get nothingIsSet =>
      'Qui non è ancora configurato nulla, quindi non c\'è nulla da trasferire.';

  @override
  String yourSetupIs(Object counterpartName) {
    return 'La tua configurazione sta arrivando a $counterpartName';
  }

  @override
  String get guide => 'GUIDA';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n di $keysCount';
  }

  @override
  String get saving => 'Salvataggio…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$_checkedCount di $total scelti';
  }

  @override
  String get channelOrGroup => 'Nome del canale o del gruppo';

  @override
  String get search => 'Cerca';

  @override
  String get moveOkCheck => '▲▼ Sposta    OK Seleziona    ESC Indietro';

  @override
  String chooseChannels(Object name) {
    return 'Scegli canali: $name';
  }

  @override
  String get add => 'Aggiungi';

  @override
  String get readingThePlaylist => 'Lettura della playlist…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return 'Ora: la guida della playlist, $guideUrl';
  }

  @override
  String get leaveEmptyTo =>
      'Lascia vuoto per usare la guida indicata dalla playlist';

  @override
  String get xmltvGuideAddress => 'Indirizzo della guida XMLTV';

  @override
  String get guideOptional => 'GUIDA (FACOLTATIVA)';

  @override
  String get httpProviderExample =>
      'http://fornitore.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'Indirizzo della playlist';

  @override
  String get playlist => 'PLAYLIST';

  @override
  String get myIptv => 'Il mio IPTV';

  @override
  String get useAnAddress => 'Usa invece un indirizzo';

  @override
  String get chooseAFile => 'Scegli un file';

  @override
  String get chooseAnotherFile => 'Scegli un altro file';

  @override
  String get moveOkSelectEscBack => '▲▼ Sposta    OK Seleziona    ESC Indietro';

  @override
  String edit(Object name) {
    return 'Modifica $name';
  }

  @override
  String get addAnM3u => 'Aggiungi una playlist M3U';

  @override
  String get m3uPlaylists => 'Playlist M3U';

  @override
  String get xmltvGuides => 'Guide XMLTV';

  @override
  String get anIptvPlaylist =>
      'Una playlist IPTV (indirizzo web o file), con una guida XMLTV se ne hai una.';

  @override
  String get theChannelsAnd =>
      'I canali e la guida del sintonizzatore del tuo server (antenna, decoder o IPTV).';

  @override
  String readingSChannels(Object server) {
    return 'Lettura dei canali di $server…';
  }

  @override
  String checkingLiveTv(Object server) {
    return 'Verifica della TV in diretta di $server…';
  }

  @override
  String get addALive => 'Aggiungi una fonte TV in diretta';

  @override
  String get itsChannelsLeave =>
      'I suoi canali escono dalla guida, dai gruppi e dai preferiti.';

  @override
  String get renameSource => 'Rinomina fonte';

  @override
  String get edit2 => 'Modifica';

  @override
  String get refreshNow => 'Aggiorna ora';

  @override
  String get chooseChannels2 => 'Scegli canali';

  @override
  String get playlistFile => 'File della playlist';

  @override
  String get notRefreshedYet => 'Non ancora aggiornato';

  @override
  String refreshed(Object lastRefresh) {
    return 'Aggiornato $lastRefresh';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return 'Ultimo aggiornamento non riuscito: $lastError';
  }

  @override
  String get refreshing => 'Aggiornamento…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · Canali: $keyCount di $channelsCount';
  }

  @override
  String get noSourcesYet => 'Ancora nessuna fonte.';

  @override
  String get addSource => 'Aggiungi fonte';

  @override
  String get realBroadcastsAnd =>
      'Vere trasmissioni e IPTV nella tua guida: la TV in diretta del tuo server o una playlist M3U con guida XMLTV. I loro canali si aggiungono al palinsesto dopo i tuoi.';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return 'Nessuno streaming. $runningCount di $streamLimit flussi in uso.';
  }

  @override
  String get savePort => 'Salva porta';

  @override
  String get port => 'Porta';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'Sintonizzatore';

  @override
  String get enterAPort => 'Inserisci un numero di porta.';

  @override
  String pinFor(Object name) {
    return 'PIN di $name';
  }

  @override
  String get letPlexFind => 'Lascia che Plex lo trovi automaticamente';

  @override
  String get discovery => 'RILEVAMENTO';

  @override
  String get encoder => 'CODIFICATORE';

  @override
  String nowAtOnce(Object streamLimit) {
    return 'Ora: $streamLimit alla volta. Ogni canale guardato altrove è un flusso.';
  }

  @override
  String get streamsAtOnce => 'FLUSSI SIMULTANEI';

  @override
  String get quality => 'QUALITÀ';

  @override
  String get lineups => 'PALINSESTI';

  @override
  String get liveTvExport2 => 'Esportazione TV in diretta';

  @override
  String get automaticDiscoveryIsnt =>
      'Il rilevamento automatico non è disponibile su questo PC. Aggiungi il sintonizzatore in Plex o Jellyfin tramite il suo indirizzo.';

  @override
  String get anyoneOnYour =>
      'Chiunque sulla tua rete domestica può guardare questo palinsesto.';

  @override
  String get watchYourChannels =>
      'Guarda i tuoi canali in Plex, Jellyfin o qualsiasi app IPTV sulla tua rete domestica. Nightingale TV deve restare aperto per riprodurli.';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get added => 'Aggiunto';

  @override
  String get chooseAServer => 'Scegli un server';

  @override
  String get whosSigningIn => 'Chi sta accedendo?';

  @override
  String get openPlexTv => 'Apri plex.tv/link';

  @override
  String get waitingForThe => 'In attesa del collegamento del codice…';

  @override
  String get goToPlex =>
      'Vai su plex.tv/link dal telefono o dal computer e inserisci questo codice.';

  @override
  String get signInWith => 'Accedi con Plex';

  @override
  String get waitingForApproval => 'In attesa di approvazione…';

  @override
  String onYourPhone(Object label) {
    return 'Sul telefono o sul computer, apri $label → il tuo profilo → Quick Connect e inserisci questo codice:';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'Accedi';

  @override
  String get password => 'Password';

  @override
  String get username => 'Nome utente';

  @override
  String signInTo2(Object name) {
    return 'Accedi a $name';
  }

  @override
  String get differentServer => 'Altro server';

  @override
  String get signInWithPassword => 'Accedi con la password';

  @override
  String get quickConnectUse => 'Quick Connect (usa il telefono)';

  @override
  String get connect => 'Connetti';

  @override
  String get serverAddress => 'Indirizzo del server';

  @override
  String get connectToYour => 'Connettiti al tuo server';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV trasforma la tua libreria Jellyfin, Emby o Plex in canali sempre attivi con guida ai programmi. Fai zapping e guarda quello che c\'è.';

  @override
  String get yourLibraryOn => 'La tua libreria.\nIn onda, 24 ore su 24.';

  @override
  String get welcomeToNightingale => 'Benvenuto in Nightingale TV';

  @override
  String signInFor(Object name) {
    return 'Accesso per $name';
  }

  @override
  String signInToAgain(Object name) {
    return 'Accedi di nuovo a $name';
  }

  @override
  String get addAServer => 'Aggiungi un server';

  @override
  String foundNewPrograms(Object list) {
    return 'Trovati: $list. I nuovi programmi vanno in onda sui loro canali subito dopo quello in corso.';
  }

  @override
  String get libraryRefreshed => 'Libreria aggiornata';

  @override
  String get nothingNew => 'Niente di nuovo';

  @override
  String get yourChannelsAre => 'I tuoi canali sono aggiornati.';

  @override
  String get refreshFailed => 'Aggiornamento non riuscito';

  @override
  String get moveOkSelectEscBackTo =>
      '▲▼ Sposta    OK Seleziona    ESC Torna alla TV';

  @override
  String get noPoolsYet => 'ancora nessun gruppo';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return 'Aggiornata il $fetchedAt alle $fetchedAt2';
  }

  @override
  String get libraryLabel => 'LIBRERIA';

  @override
  String get account => 'ACCOUNT';

  @override
  String get watching => 'STA GUARDANDO';

  @override
  String get exitNightingaleTv => 'Esci da Nightingale TV';

  @override
  String get signOut => 'Disconnetti';

  @override
  String get yourChannelLineup =>
      'Il palinsesto viene cancellato. Le icone personalizzate restano.';

  @override
  String get signOut2 => 'Disconnettere?';

  @override
  String get fullScreenOn => 'Schermo intero sì/no (F11)';

  @override
  String get nothingWasReset => 'Non è stato reimpostato nulla';

  @override
  String get reset => 'Reimposta';

  @override
  String get rebuildsTheDefault =>
      'Ricrea i canali predefiniti dalla tua libreria. Nomi, icone e numeri modificati vengono reimpostati. I canali aggiunti restano. Prima viene salvato un backup, così puoi recuperarli in Backup e ripristino.';

  @override
  String get resetChannelLineup => 'Reimpostare il palinsesto?';

  @override
  String get resetChannelLineup2 => 'Reimposta il palinsesto';

  @override
  String get refreshLibrary => 'Aggiorna libreria';

  @override
  String get refreshingLibrary => 'Aggiornamento libreria…';

  @override
  String get servers => 'Server';

  @override
  String get phoneRemote => 'Telecomando sul telefono';

  @override
  String get profiles => 'Profili';

  @override
  String get retroLook => 'Aspetto retrò';

  @override
  String get playback => 'Riproduzione';

  @override
  String get switchProfile => 'Cambia profilo';

  @override
  String get sleepTimer => 'Timer di spegnimento';

  @override
  String get backToTv => 'Torna alla TV';

  @override
  String get removeAll => 'Rimuovi tutti';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return 'associato $paired · ultimo uso $lastUsed';
  }

  @override
  String get noPhonesPaired => 'Ancora nessun telefono associato.';

  @override
  String get pairedPhones => 'TELEFONI ASSOCIATI';

  @override
  String get blockedByThis => 'Bloccato dal firewall di questo computer';

  @override
  String get someWiFi =>
      'Alcune reti Wi-Fi tengono separati i dispositivi (isolamento AP o client). Se il telefono non riesce ancora a connettersi, disattiva questa impostazione per il tuo Wi-Fi.';

  @override
  String get thePhoneHas =>
      'Il telefono deve essere sullo stesso Wi-Fi di questa TV, non su una rete ospite o con dati mobili.';

  @override
  String get ifThePhone =>
      'Se il telefono non si connette, il firewall di questo computer potrebbe bloccarlo. Apri un terminale su questo computer ed esegui:';

  @override
  String get checkAgain => 'Controlla di nuovo';

  @override
  String get thenChooseCheck => 'Poi scegli Controlla di nuovo.';

  @override
  String get thisComputersFirewall =>
      'Il firewall di questo computer impedisce ai telefoni di raggiungere il telecomando. Per consentirli, apri un terminale su questo computer ed esegui:';

  @override
  String get notConfirmedYet =>
      'Non ancora confermato · nessun telefono connesso';

  @override
  String get working => 'Funziona';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return 'Funziona · ultimo uso di $name, $lastUsed';
  }

  @override
  String get theRemoteIs => 'Il telecomando è disattivato.';

  @override
  String get orScanThe =>
      'o scansiona il codice con la fotocamera del telefono.';

  @override
  String get andEnter => 'e inserisci  ';

  @override
  String get onYourPhoneOpen => 'SUL TELEFONO, APRI';

  @override
  String get useYourPhoneAs =>
      'Usa il telefono come telecomando: aprici una pagina web per cambiare canale, aprire la guida o toccare un canale per sintonizzarti. Niente da installare.';

  @override
  String get everyPairedPhone =>
      'Ogni telefono associato smette di funzionare come telecomando finché non scansiona di nuovo il codice su questa schermata.';

  @override
  String get removeAllPhones => 'Rimuovere tutti i telefoni?';

  @override
  String get thoseDidntMatch => 'Non corrispondono. Riprova.';

  @override
  String get enterTheSame => 'Inserisci di nuovo le stesse 4 cifre.';

  @override
  String get choose4Digits => 'Scegli 4 cifre.';

  @override
  String get thatPinIsnt => 'Questo PIN non è corretto. Riprova.';

  @override
  String get clock => 'OROLOGIO';

  @override
  String get captions2 => 'SOTTOTITOLI';

  @override
  String get audio => 'AUDIO';

  @override
  String get maximumStreamingBitrate => 'BITRATE MASSIMO DI STREAMING';

  @override
  String get converting => 'CONVERSIONE';

  @override
  String get afterThisLong =>
      'Dopo questo tempo senza premere alcun tasto, Nightingale TV chiede se qualcuno sta guardando. Senza risposta entro un minuto si spegne: la riproduzione si ferma e il server smette di trasmettere. Non mentre è attivo un timer di spegnimento.';

  @override
  String get askIfIm => 'Chiedi se sto ancora guardando';

  @override
  String get liveTvStill =>
      'La TV in diretta compare comunque nella dashboard.';

  @override
  String get offWhatYou =>
      'Disattivato: ciò che guardi qui non cambia mai conteggi di riproduzione, segni di visione o punti di ripresa sul tuo server, e non compare nella sua dashboard.';

  @override
  String get pauseSkipAnd =>
      'Metti in pausa, salta e riavvia ciò che è in onda. Disattivato: ogni canale segue l\'orario, come la TV sempre attiva.';

  @override
  String get pauseAndRewind => 'Pausa e riavvolgi';

  @override
  String get showsTheTime => 'Mostra l\'ora nell\'angolo dell\'immagine.';

  @override
  String get onScreenClock => 'Orologio a schermo';

  @override
  String get showACountdown =>
      'Mostra un conto alla rovescia prima dell\'inizio della pubblicità e prima del ritorno del programma.';

  @override
  String get breakNotices => 'Avvisi di pausa';

  @override
  String get theSizeOf =>
      'La dimensione dei sottotitoli su tutti i programmi e canali.';

  @override
  String get whileItsOn =>
      'Quando è attivo, l\'audio surround (Dolby, DTS) viene decodificato da questo dispositivo invece di essere inviato a un ricevitore.';

  @override
  String get evensOutThe =>
      'Uniforma il volume mentre guardi: pubblicità e programmi forti vengono abbassati e quelli deboli alzati, così non devi prendere il telecomando.';

  @override
  String get volumeLeveling => 'Livellamento del volume';

  @override
  String get pickALower =>
      'Scegli un bitrate più basso se i programmi si bloccano via Wi-Fi o in connessione remota. Originale non viene mai convertito a causa del bitrate.';

  @override
  String get connectedThroughPlex =>
      'Connesso tramite Plex Relay: la qualità è limitata.';

  @override
  String get offNightingaleTv =>
      'Disattivato: Nightingale TV riproduce sempre i file originali a piena qualità e il server non fa lavoro extra. Attivo: il server converte una serie o un film solo se supera il bitrate massimo o se il file originale non si riproduce. La conversione usa il processore o la scheda grafica del server. Le pubblicità riproducono sempre i file originali.';

  @override
  String get transcodeOnlyIf => 'Converti solo se necessario (sperimentale)';

  @override
  String get longerVideosAd =>
      'I video più lunghi (raccolte di pubblicità) vengono divisi nelle singole pubblicità, ai capitoli o dove l\'immagine diventa nera e silenziosa.';

  @override
  String get videosOf5 =>
      'I video da 5 secondi a 3 minuti sono una clip ciascuno.';

  @override
  String get commercialsFillBreaks =>
      'Le pubblicità riempiono le pause. Imposta il tipo su Stacchi per sigle di canale e clip «torniamo subito».';

  @override
  String get bumpersTakeAt =>
      'Gli stacchi occupano al massimo metà pausa, tranne in un pre-roll. Uno troppo lungo viene saltato.';

  @override
  String stillToSplit(Object unsplit) {
    return '$unsplit da dividere';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount lunghi divisi in clip',
      one: '$reelsCount lungo diviso in clip',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'Elimina gruppo';

  @override
  String get addFolders => 'Aggiungi cartelle…';

  @override
  String get libraryLabel2 => 'Libreria';

  @override
  String get noFoldersYet => 'Ancora nessuna cartella.';

  @override
  String get folders2 => 'CARTELLE';

  @override
  String get type => 'TIPO';

  @override
  String get poolName => 'Nome del gruppo';

  @override
  String get commercialPool => 'Gruppo di pubblicità';

  @override
  String get itsVideosGo =>
      'I suoi video tornano ai canali normali. Le pause che lo usavano useranno tutti i gruppi.';

  @override
  String get now => 'Ora';

  @override
  String get watch => 'Guarda';

  @override
  String get tuning2 => 'Sintonizzazione…';

  @override
  String get fullScreen => 'Schermo intero';

  @override
  String get noChannels => 'Nessun canale';

  @override
  String get theirChannelsProgramming =>
      'I suoi canali, blocchi di programmazione e impostazioni vengono eliminati, e questa TV viene disconnessa dal suo server.';

  @override
  String delete3(Object name) {
    return 'Eliminare $name?';
  }

  @override
  String get giveTheProfile => 'Dai un nome al profilo.';

  @override
  String get deleteProfile => 'Elimina profilo';

  @override
  String get removePin => 'Rimuovi PIN';

  @override
  String get setAPin => 'Imposta un PIN';

  @override
  String get changePin => 'Cambia PIN';

  @override
  String get noPinAnyone => 'Nessun PIN. Chiunque può aprire questo profilo.';

  @override
  String get lockedThePin =>
      'Bloccato. Serve il PIN per aprire questo profilo.';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith =>
      'Serie e film senza classificazione sono esclusi.';

  @override
  String get allowedToWatch => 'PUÒ GUARDARE';

  @override
  String get kid => 'Bambino';

  @override
  String get grownUp => 'Adulto';

  @override
  String get whoItsFor => 'PER CHI È';

  @override
  String get color2 => 'COLORE';

  @override
  String get editProfile => 'Modifica profilo';

  @override
  String get newProfile => 'Nuovo profilo';

  @override
  String get watchingNow => 'Sta guardando';

  @override
  String get noPin => 'Nessun PIN';

  @override
  String get pinLocked => 'Bloccato da PIN';

  @override
  String kid2(Object label, Object description) {
    return 'Bambino · $label ($description)';
  }

  @override
  String get addProfile => 'Aggiungi profilo';

  @override
  String get everyoneGetsTheir =>
      'Ognuno ha il proprio accesso al server, i propri canali e blocchi di programmazione. I profili bambino vedono solo serie e film adatti alla loro età.';

  @override
  String enterSPin(Object name) {
    return 'Inserisci il PIN di $name';
  }

  @override
  String get whosWatching => 'Chi sta guardando?';

  @override
  String get moveOkChoose2 => '◀▶ Sposta    OK Scegli';

  @override
  String get enterAGrownUps => 'Inserisci il PIN di un adulto.';

  @override
  String get grownUpsOnly => 'Solo adulti';

  @override
  String get yourChannelYour => 'Il tuo canale, il tuo stile';

  @override
  String get testPattern => 'Monoscopio';

  @override
  String get upNext8 => 'A SEGUIRE  ·  20:00';

  @override
  String get thisDevice => 'QUESTO DISPOSITIVO';

  @override
  String get glow => 'BAGLIORE';

  @override
  String get curvature => 'CURVATURA';

  @override
  String get vignette => 'VIGNETTATURA';

  @override
  String get mask => 'MASCHERA';

  @override
  String get lines => 'RIGHE';

  @override
  String get scanlines => 'LINEE DI SCANSIONE';

  @override
  String get customCrtStyle => 'STILE CRT PERSONALIZZATO';

  @override
  String accent(Object label) {
    return 'ACCENTO ($label)';
  }

  @override
  String get overlayTheme => 'TEMA SOVRIMPRESSIONE';

  @override
  String get crtEffect => 'EFFETTO CRT';

  @override
  String get surround => 'CONTORNO';

  @override
  String get pictureShape => 'FORMA IMMAGINE';

  @override
  String get surroundImage => 'Immagine di contorno';

  @override
  String get notAvailableOn => 'Non disponibile su questo dispositivo';

  @override
  String get offTurnsOff =>
      'Disattivato spegne tutti gli effetti CRT solo su questo dispositivo. Forma dell\'immagine, contorno e temi di sovrimpressione restano invariati.';

  @override
  String get effectsOnThis => 'Effetti su questo dispositivo';

  @override
  String get retroLook2 => 'ASPETTO RETRÒ';

  @override
  String get theseSettingsApply =>
      'Queste impostazioni valgono sugli schermi con l\'app. Non valgono per l\'esportazione TV in diretta.';

  @override
  String get sameAsThe => 'Come il profilo';

  @override
  String get streamsFromThis =>
      'Gli streaming di questo server restano sotto questo limite. Il limite del profilo (Riproduzione) vale comunque: prevale il più basso.';

  @override
  String qualityLimit(Object name) {
    return 'Limite di qualità · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      'I suoi programmi lasciano i tuoi canali, che mantengono i numeri. Le fonti e le cartelle di pubblicità su di esso risultano non trovate finché non le cambi.';

  @override
  String remove3(Object name) {
    return 'Rimuovere $name?';
  }

  @override
  String get signingOutOf =>
      'Disconnettere questo profilo cambia il suo server principale.';

  @override
  String signedInAs(Object user) {
    return 'Accesso come $user';
  }

  @override
  String get mainServer => 'Server principale';

  @override
  String get qualityLimit2 => 'Limite di qualità';

  @override
  String get moveDown => 'Sposta giù';

  @override
  String get moveUp => 'Sposta su';

  @override
  String get signInAgain => 'Accedi di nuovo';

  @override
  String get programsFromEvery =>
      'I programmi di tutti i server confluiscono in un unico palinsesto. Un titolo presente su più server viene riprodotto dal primo di questo elenco che risponde (Riproduci da); se smette di rispondere, subentra il successivo.';

  @override
  String get sleepingPressAny => 'Spento · Premi un tasto per guardare';

  @override
  String goingToSleep(Object seconds) {
    return 'Spegnimento tra $seconds';
  }

  @override
  String get goingToSleep2 => 'Spegnimento';

  @override
  String goingToSleepIn(Object hint) {
    return 'Spegnimento tra 1 minuto. $hint';
  }

  @override
  String get pressAnyButton => 'Premi un tasto per continuare a guardare';

  @override
  String goingToSleepIn0(Object padLeft) {
    return 'Spegnimento tra 0:$padLeft';
  }

  @override
  String get keepWatching => 'Continua a guardare';

  @override
  String get areYouStill => 'Stai ancora guardando?';

  @override
  String sleepTimerMin(Object left) {
    return 'Timer di spegnimento · $left min rimasti';
  }

  @override
  String get whatsOnNow =>
      'Ciò che è in onda non ha un orario di fine definito.';

  @override
  String endOfThis(Object programEnd) {
    return 'Fine di questo programma · $programEnd';
  }

  @override
  String get endOfThisProgram => 'Fine di questo programma';

  @override
  String get moveOkToggle =>
      '▲▼◀▶ Sposta    OK Attiva/disattiva    ESC Annulla';

  @override
  String get usedWhenNo =>
      'Usato quando non sono scelte serie. Restringe anche i film.';

  @override
  String get genres2 => 'GENERI';

  @override
  String get includeMovies => 'Includi film';

  @override
  String get add2 => 'Aggiungi…';

  @override
  String get notFoundOn => 'Non trovato sul server';

  @override
  String get collectionsFolders => 'RACCOLTE E CARTELLE';

  @override
  String get playOrder => 'ORDINE DI RIPRODUZIONE';

  @override
  String get clear => 'Cancella';

  @override
  String get shows2 => 'SERIE';

  @override
  String get pickSomethingTo => 'Scegli cosa riprodurre.';

  @override
  String everyMovie(Object genreText) {
    return 'ogni film $genreText';
  }

  @override
  String get everyMovie2 => 'ogni film';

  @override
  String everyShow(Object genreText) {
    return 'ogni serie $genreText';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount o $last';
  }

  @override
  String get settingUpYour => 'Configurazione dei tuoi canali';

  @override
  String get couldntLoadYour => 'Impossibile caricare la libreria';

  @override
  String upNext(Object title) {
    return 'A seguire: $title';
  }

  @override
  String backTo(Object title) {
    return 'Si torna a $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return 'La programmazione riprende tra $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabel tra $left';
  }

  @override
  String startingWith(Object title) {
    return 'Si inizia con $title';
  }

  @override
  String upNext2(Object start) {
    return 'A SEGUIRE  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return 'Prossimo $start: $title';
  }

  @override
  String backOn(Object backOnAir) {
    return 'Di ritorno $backOnAir';
  }

  @override
  String get offTheAir2 => 'Fuori onda';

  @override
  String get commercialBreak => 'Pausa pubblicitaria';

  @override
  String tryingAgainAt(Object end) {
    return 'Nuovo tentativo alle $end';
  }

  @override
  String get exitFullScreen => 'Esci da schermo intero';

  @override
  String get guide2 => 'Guida';

  @override
  String thereIsNo(Object number) {
    return 'Il canale $number non esiste';
  }

  @override
  String get liveChannelsCant =>
      'I canali in diretta non possono essere messi in pausa';

  @override
  String get curvatureAndGlow =>
      'Curvatura e bagliore disattivati: questo dispositivo non regge';

  @override
  String get pressBackAgain => 'Premi di nuovo Indietro per uscire';

  @override
  String backAt(Object backAt) {
    return 'Di ritorno alle $backAt';
  }

  @override
  String get live => 'DIRETTA';

  @override
  String get newLabel => 'NUOVO';

  @override
  String nowPlayingOn(Object name) {
    return 'IN ONDA SU $name';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => 'IN PAUSA';

  @override
  String get seekBar => 'Barra di avanzamento';

  @override
  String get live2 => 'Diretta';

  @override
  String get forward30 => 'Avanti 30';

  @override
  String get pause => 'Pausa';

  @override
  String get play => 'Riproduci';

  @override
  String get back10 => 'Indietro 10';

  @override
  String get restart => 'Riavvia';

  @override
  String somethingWentWrong2(Object status) {
    return 'Si è verificato un errore ($status).';
  }

  @override
  String get thatIsTooBig => 'È troppo grande.';

  @override
  String get notFound => 'Non trovato.';

  @override
  String get youCantDo => 'Non puoi farlo.';

  @override
  String get cantReachThe =>
      'Impossibile raggiungere il server. Verifica che sia in esecuzione.';

  @override
  String signOut3(Object userName) {
    return 'Disconnetti $userName';
  }

  @override
  String get changePassword => 'Cambia password';

  @override
  String get users => 'Utenti';

  @override
  String get backups2 => 'Backup';

  @override
  String get serverAndSign => 'Server e accesso';

  @override
  String get channels5 => 'Canali';

  @override
  String get thatProfileIsntYours => 'Quel profilo non è tuo o non esiste più.';

  @override
  String get download => 'Scarica';

  @override
  String get itReplacesThe =>
      'Sostituisce i profili, i canali e le impostazioni qui.';

  @override
  String get restoreThisBackup => 'Ripristinare questo backup?';

  @override
  String get backupActions => 'Azioni backup';

  @override
  String channels6(Object profiles, Object channels, Object device) {
    return '$profiles · Canali: $channels · $device';
  }

  @override
  String get noneYetOne =>
      'Ancora nessuno. Ne viene salvato uno ogni giorno in cui la famiglia cambia.';

  @override
  String get savedOnThe => 'Salvati sul server';

  @override
  String get restoring => 'Ripristino…';

  @override
  String get restoreFromAFile => 'Ripristina da un file…';

  @override
  String get downloadABackup => 'Scarica un backup ora';

  @override
  String get aBackupHoldsThe =>
      'Un backup contiene profili, canali, blocchi, loghi, impostazioni di esportazione e account utente (mai password o token di accesso).';

  @override
  String get restoredTheBackup2 => 'Backup ripristinato.';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return 'Del $whenValue ($device): $profiles. Sostituisce i profili, i canali e le impostazioni qui.';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return 'Prossima messa in onda: $start $end';
  }

  @override
  String programsInIts(Object total) {
    return 'Programmi nella playlist: $total';
  }

  @override
  String get workingOutWhat => 'Calcolo del contenuto…';

  @override
  String get later => 'Dopo';

  @override
  String get earlier => 'Prima';

  @override
  String get eachAiringPlays =>
      'Ogni messa in onda trasmette in ordine gli episodi successivi di ogni posizione, poi ricomincia se avanza tempo.';

  @override
  String get aLineupOf => 'Un palinsesto di serie';

  @override
  String get whatItPlays2 => 'Cosa trasmette';

  @override
  String get onlyPartOf => 'Solo una parte dell\'anno';

  @override
  String get runsPastMidnight =>
      'Prosegue oltre la mezzanotte nel giorno dopo.';

  @override
  String get whenLabel => 'Quando';

  @override
  String get aNewChannelFor => 'Un nuovo canale per questo blocco';

  @override
  String get channel3 => 'Canale';

  @override
  String get blocks => 'Blocchi';

  @override
  String get newBlock => 'Nuovo blocco';

  @override
  String get programmingBlock => 'Blocco di programmazione';

  @override
  String get aBlockTakes =>
      'Un blocco prende il controllo di un canale a orari fissi: «Cartoni del sabato mattina», il sabato dalle 7 alle 12.';

  @override
  String get overlayTheme2 => 'Tema sovrimpressione';

  @override
  String get crtEffect2 => 'Effetto CRT';

  @override
  String get chooseSurroundImage => 'Scegli immagine di contorno…';

  @override
  String get surround2 => 'Contorno';

  @override
  String get pictureShape2 => 'Forma dell\'immagine';

  @override
  String get chooseOfflineImage => 'Scegli immagine fuori onda…';

  @override
  String get fillerPool2 => 'Gruppo di riempimento';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes minuti';
  }

  @override
  String get slotLength2 => 'Durata fascia';

  @override
  String get everyProgramStarts =>
      'Ogni programma inizia puntuale. Il riempimento completa il resto di ogni fascia.';

  @override
  String get itLeavesThe => 'Lascia il palinsesto.';

  @override
  String get itsProgrammingBlocks =>
      'Anche i suoi blocchi di programmazione vengono rimossi.';

  @override
  String get removeThisChannel => 'Rimuovi questo canale';

  @override
  String get channelLogo2 => 'Logo del canale';

  @override
  String get editCustomBreaks => 'Modifica pause personalizzate…';

  @override
  String get musicChannelsOnlyShuffle =>
      'I canali musicali sono solo casuali, mai lo stesso artista due volte di seguito.';

  @override
  String get playOrder2 => 'Ordine di riproduzione';

  @override
  String get saveWhatIt => 'Salva cosa trasmette';

  @override
  String get canBeA =>
      'Può essere il canale principale di una serie per gli episodi più recenti.';

  @override
  String get hiddenFromThe => 'Nascosto dalla guida';

  @override
  String get chooseIcon => 'Scegli icona…';

  @override
  String get icon => 'Icona';

  @override
  String get saveNameAnd => 'Salva nome e numero';

  @override
  String get aChannelAlready =>
      'Un canale già su quel numero si scambia di posto con questo.';

  @override
  String get number3 => 'Numero';

  @override
  String get nameAndNumber => 'Nome e numero';

  @override
  String get decadesNoneAny => 'Decenni (nessuno: qualsiasi)';

  @override
  String get genresNoneAny => 'Generi (nessuno: qualsiasi)';

  @override
  String musicVideos(Object musicVideos) {
    return 'Video musicali ($musicVideos)';
  }

  @override
  String songs(Object songs) {
    return 'Brani ($songs)';
  }

  @override
  String get newMusicChannel => 'Nuovo canale musicale';

  @override
  String get aNightlySlot =>
      'Una fascia notturna per gli episodi più recenti delle serie, sul canale principale di ciascuna.';

  @override
  String get mainSettings => 'Impostazioni principali';

  @override
  String get glow2 => 'Bagliore';

  @override
  String get curvature2 => 'Curvatura';

  @override
  String get vignette2 => 'Vignettatura';

  @override
  String get mask2 => 'Maschera';

  @override
  String get lines2 => 'Righe';

  @override
  String get scanlines2 => 'Linee di scansione';

  @override
  String get customCrtStyle2 => 'Stile CRT personalizzato';

  @override
  String accent2(Object label) {
    return 'Accento ($label)';
  }

  @override
  String get hidden => 'Nascosto';

  @override
  String get blockChannel2 => 'Canale a blocchi';

  @override
  String live3(Object source) {
    return 'Diretta · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return 'Canali: $shownCount di $channelsCount';
  }

  @override
  String get searchChannels => 'Cerca canali';

  @override
  String get resetLineup => 'Reimposta palinsesto';

  @override
  String get everyChannelEdit =>
      'Ogni modifica ai canali viene annullata e il palinsesto predefinito viene ricreato. I canali aggiunti restano. Prima viene salvato un backup.';

  @override
  String get musicChannel => 'Canale musicale';

  @override
  String get newBlockChannel => 'Nuovo canale a blocchi';

  @override
  String get channelsOwnPlans => 'Piani propri dei canali';

  @override
  String get setTypeBumpers => 'Imposta tipo: Stacchi';

  @override
  String get setTypeCommercials => 'Imposta tipo: Pubblicità';

  @override
  String get chooseFolders2 => 'Scegli cartelle…';

  @override
  String get plansThatDrew =>
      'I piani che lo usavano useranno tutti i gruppi, e i suoi video tornano sui canali.';

  @override
  String get renamePool => 'Rinomina gruppo';

  @override
  String get poolActions => 'Azioni gruppo';

  @override
  String get aPoolIs =>
      'Un gruppo è un insieme di cartelle della libreria i cui video riempiono le pause invece di andare in onda. Il tipo indica se le sue clip vanno in onda come pubblicità o come stacchi, che aprono e chiudono le pause.';

  @override
  String get pools2 => 'Gruppi';

  @override
  String get breaks => 'Pause';

  @override
  String clipsInAll(Object clips) {
    return 'Clip in tutti i gruppi di pubblicità: $clips';
  }

  @override
  String get tunerAddress => 'Indirizzo del sintonizzatore';

  @override
  String get changePort => 'Cambia porta';

  @override
  String get exportThisProfile => 'Esporta questo profilo';

  @override
  String get letsPlexAnd =>
      'Permette a Plex e ad altri di trovare i sintonizzatori sulla rete.';

  @override
  String get discovery2 => 'Rilevamento';

  @override
  String get encoder2 => 'Codificatore';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return 'Automatico: $streamLimitInUse su questo computer.';
  }

  @override
  String get streamsAtOnce2 => 'Flussi simultanei';

  @override
  String get quality2 => 'Qualità';

  @override
  String get settings => 'Impostazioni';

  @override
  String get eachExportedProfile =>
      'Ogni profilo esportato è un sintonizzatore per Plex, Jellyfin o Emby. Aggiungilo nelle loro impostazioni DVR tramite il suo indirizzo.';

  @override
  String get channelsInThis => 'Canali in questo gruppo';

  @override
  String get chooseChannels3 => 'Scegli canali…';

  @override
  String channels7(Object channelIds) {
    return 'Canali: $channelIds';
  }

  @override
  String get itsChannelsStay => 'I suoi canali restano nel palinsesto.';

  @override
  String get renameGroup => 'Rinomina gruppo';

  @override
  String get groupActions => 'Azioni gruppo';

  @override
  String get yourGroup => 'Il tuo gruppo';

  @override
  String get theOrderOf =>
      'L\'ordine delle schede nella guida e quali sono mostrate.';

  @override
  String get guideTabs => 'Schede della guida';

  @override
  String get make => 'Crea';

  @override
  String get breaksBetweenPrograms => 'Pause tra i programmi';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '$mids pause interne',
      one: '$mids pausa interna',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return 'Brani: $songs';
  }

  @override
  String get newEpisode => 'Nuovo episodio';

  @override
  String get noChannelsYet2 => 'Ancora nessun canale.';

  @override
  String get noGuide => 'Nessuna guida';

  @override
  String get noneShown => 'Nessuno visibile';

  @override
  String get allShown => 'Tutti visibili';

  @override
  String channels8(Object name) {
    return '$name: canali';
  }

  @override
  String get orChooseA => 'O scegli un file di guida…';

  @override
  String get emptyThePlaylists =>
      'Vuoto: la guida della playlist, se ne indica una.';

  @override
  String get guideAddressXmltv => 'Indirizzo della guida (XMLTV, facoltativo)';

  @override
  String get orChooseAPlaylist => 'O scegli un file di playlist…';

  @override
  String get leaveEmptyToKeep =>
      'Lascia vuoto per mantenere il file della playlist.';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'File';

  @override
  String get itsChannelsJoin =>
      'I suoi canali si aggiungono finché questo profilo ha effettuato l\'accesso a quel server.';

  @override
  String guide3(Object guideFile) {
    return 'Guida: $guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'File della playlist: $playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return 'Aggiornato $last $context';
  }

  @override
  String get itsChannelsLeaveThe =>
      'I suoi canali lasciano il palinsesto, i gruppi e i preferiti.';

  @override
  String read(Object fetched, Object context) {
    return 'Letta $fetched $context.';
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
    return 'Serie: $series · Episodi: $episodes · Film: $movies · Brani: $songs · Video musicali: $musicVideos · Video pubblicitari: $commercials';
  }

  @override
  String fromAs(Object server, Object user) {
    return 'Da $server come $user.';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name: libreria';
  }

  @override
  String get removeThePin => 'Rimuovi il PIN';

  @override
  String get pinOptional => 'PIN (facoltativo)';

  @override
  String get newPinLeave => 'Nuovo PIN (lascia vuoto per mantenerlo)';

  @override
  String colour(Object i) {
    return 'Colore $i';
  }

  @override
  String get colour2 => 'Colore';

  @override
  String get itsChannelsBlocks =>
      'I suoi canali, blocchi e impostazioni vengono eliminati. Prima viene salvato un backup.';

  @override
  String get exported => 'Esportato';

  @override
  String kid3(Object label) {
    return 'Bambino · $label';
  }

  @override
  String get noProfilesAre =>
      'Non ti è ancora stato assegnato alcun profilo. Chiedi a un amministratore.';

  @override
  String signIn2(Object name) {
    return 'Accesso di $name';
  }

  @override
  String get theLibraryIs =>
      'La libreria viene riletta. I programmi del server si aggiungeranno ai canali al termine.';

  @override
  String get itsLibraryIs =>
      'La libreria viene letta e i canali creati. Ci vogliono uno o due minuti.';

  @override
  String isSignedIn(Object name) {
    return '$name ha effettuato l\'accesso.';
  }

  @override
  String get couldntDoThat => 'Non è stato possibile. Riprova.';

  @override
  String get itsChannelsStayIt =>
      'I suoi canali restano. Serve l\'accesso per riprodurre.';

  @override
  String signOut4(Object name) {
    return 'Disconnettere $name?';
  }

  @override
  String get signingIn => 'Accesso in corso…';

  @override
  String wasSignedIn(Object server, Object user) {
    return 'Aveva effettuato l\'accesso a $server come $user. Accedi di nuovo.';
  }

  @override
  String signedInTo(Object server, Object user) {
    return 'Accesso a $server come $user.';
  }

  @override
  String get profileName => 'Nome del profilo';

  @override
  String get nameAProfile =>
      'Dai un nome a un profilo, collegalo al tuo server multimediale e i suoi canali vengono creati ed esportati.';

  @override
  String get chooseABackup => 'Scegli un file di backup…';

  @override
  String get moveAHousehold =>
      'Trasferisci qui una famiglia da una TV o da un altro server: profili, canali, blocchi, loghi e impostazioni di esportazione.';

  @override
  String get restoreABackup => 'Ripristina un backup';

  @override
  String get theServerIs => 'Il server si sta avviando…';

  @override
  String get itsProgramsLeaveThe =>
      'I suoi programmi lasciano i canali, che mantengono i numeri. Le fonti e le cartelle di pubblicità su di esso risultano non trovate finché non le cambi.';

  @override
  String addAServerTo(Object name) {
    return 'Aggiungi un server a $name';
  }

  @override
  String servers2(Object name) {
    return '$name: server';
  }

  @override
  String get makeAccountAnd => 'Crea account e accedi';

  @override
  String get setPasswordAnd => 'Imposta password e accedi';

  @override
  String get passwordAgain => 'Ripeti la password';

  @override
  String get atLeast8 => 'Almeno 8 caratteri.';

  @override
  String get userName => 'Nome utente';

  @override
  String get adminAccount => 'Account amministratore';

  @override
  String get makeTheFirst => 'Crea il primo account amministratore.';

  @override
  String get setANew =>
      'Imposta una nuova password per un account amministratore.';

  @override
  String get thisSetupLink =>
      'Questo link di configurazione è già stato usato o risale a un avvio precedente. Apri il più recente dal log del server o accedi.';

  @override
  String get thePasswordsDont => 'Le password non corrispondono.';

  @override
  String get newPasswordAgain => 'Ripeti la nuova password';

  @override
  String get newPassword => 'Nuova password';

  @override
  String get currentPassword => 'Password attuale';

  @override
  String get passwordChangedYour =>
      'Password cambiata. Gli altri browser sono stati disconnessi.';

  @override
  String get theNewPasswords => 'Le nuove password non corrispondono.';

  @override
  String get theyAreSigned => 'Viene disconnesso e non può più accedere.';

  @override
  String get cantSignIn => 'Accesso impossibile; disconnesso ovunque.';

  @override
  String get usersReachOnly =>
      'Gli utenti raggiungono solo i profili qui sotto.';

  @override
  String get adminsCanDo =>
      'Gli amministratori possono fare tutto, su ogni profilo.';

  @override
  String get admin => 'Amministratore';

  @override
  String get user => 'Utente';

  @override
  String get leaveEmptyToKeepIt =>
      'Lascia vuoto per mantenerla. Impostarne una lo disconnette altrove.';

  @override
  String get needsAPassword =>
      'Ha bisogno di una password prima di poter accedere.';

  @override
  String get addUser => 'Aggiungi utente';

  @override
  String get needsAPassword2 => 'Ha bisogno di una password';

  @override
  String get noProfiles => 'Nessun profilo';

  @override
  String get pad => 'Riempi';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  Clip: $clips';
  }

  @override
  String get clipsFrom2 => 'Clip da';

  @override
  String get channelsUsingItGo =>
      'I canali che la usano tornano a un\'icona integrata.';

  @override
  String get uploading => 'Caricamento…';

  @override
  String get noneOfYourShows =>
      'Nessuna delle tue serie ha un\'immagine del logo sul tuo server.';

  @override
  String get chooseAnIcon => 'Scegli un\'icona';

  @override
  String get couldntCopySelect =>
      'Impossibile copiare. Seleziona il testo e copialo.';

  @override
  String copy(Object label) {
    return 'Copia $label';
  }

  @override
  String get home => 'Home';

  @override
  String get thereIsNoPage => 'Qui non c\'è nessuna pagina.';

  @override
  String get enterPin => 'Inserisci PIN';

  @override
  String get thisIsA =>
      'Questo è un profilo bambino. Per modificare le sue impostazioni serve il PIN di un adulto.';

  @override
  String hasAPin(Object name) {
    return '$name ha un PIN.';
  }

  @override
  String get profile => 'Profilo';

  @override
  String get changingAKid =>
      'Per modificare le impostazioni di un profilo bambino serve il PIN di un profilo adulto.';

  @override
  String get aGrownUps => 'PIN di un adulto';

  @override
  String get thisProfile => 'questo profilo';

  @override
  String movies3(Object movies) {
    return 'Film ($movies)';
  }

  @override
  String get shows3 => 'Serie';

  @override
  String remove4(Object label) {
    return 'Rimuovi $label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · Non trovato sul server';
  }

  @override
  String get dragACollection =>
      'Trascina qui una raccolta, una cartella o un film, o usa il suo pulsante Aggiungi.';

  @override
  String get collectionsAndFolders => 'Raccolte e cartelle';

  @override
  String add3(Object name) {
    return 'Aggiungi $name';
  }

  @override
  String added2(Object name) {
    return '$name aggiunto';
  }

  @override
  String get dragToAdd => 'Trascina per aggiungere';

  @override
  String get languageAutomatic => 'Automatico';

  @override
  String dateAtTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String connectingTo(Object server) {
    return 'Connessione a $server…';
  }

  @override
  String get yourServerLower => 'tuo server';

  @override
  String noServerFoundAt(Object address) {
    return 'Nessun server Jellyfin, Emby o Plex trovato su $address.';
  }

  @override
  String captionsValue(Object name) {
    return 'Sottotitoli: $name';
  }

  @override
  String channelOverrides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali hanno la propria impostazione (Canali e icone).',
      one: '$count canale ha la propria impostazione (Canali e icone).',
    );
    return '$_temp0';
  }

  @override
  String noShowLogosOn(Object kind) {
    return 'Nessuna delle tue serie ha un\'immagine del logo sul tuo server $kind.';
  }

  @override
  String fileChosen(Object name) {
    return 'File: $name';
  }

  @override
  String get theOneChosenBefore => 'quello scelto prima';

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
          'Streaming dei canali $channels a $viewers spettatore/i. $running di $limit flussi in uso.',
      one:
          'Streaming del canale $channels a $viewers spettatore/i. $running di $limit flussi in uso.',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name: esporta questo palinsesto';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name (bambino): esporta questo palinsesto';
  }

  @override
  String encoderInUse(Object encoder) {
    return 'Codificatore in uso: $encoder';
  }

  @override
  String get checking => 'verifica…';

  @override
  String countShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie',
      one: '$count serie',
    );
    return '$_temp0';
  }

  @override
  String countEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodi',
      one: '$count episodio',
    );
    return '$_temp0';
  }

  @override
  String countMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count film',
      one: '$count film',
    );
    return '$_temp0';
  }

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '$count brano',
    );
    return '$_temp0';
  }

  @override
  String countMusicVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video musicali',
      one: '$count video musicale',
    );
    return '$_temp0';
  }

  @override
  String countHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nascosti',
      one: '$count nascosto',
    );
    return '$_temp0';
  }

  @override
  String countOnTheAir(int count) {
    return '$count in onda';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocchi di programmazione',
      one: '$count blocco di programmazione',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name: $stats';
  }

  @override
  String get yourServerHasNothingNew =>
      'Il tuo server non ha novità dall\'ultimo aggiornamento. I nuovi file compaiono qui dopo la scansione del server: se ne hai appena aggiunti, esegui prima la scansione della libreria sul server, poi aggiorna di nuovo.';

  @override
  String serverHasNothingNew(Object server) {
    return '$server non ha novità dall\'ultimo aggiornamento. I nuovi file compaiono qui dopo la scansione del server: se ne hai appena aggiunti, esegui prima la scansione della libreria sul server, poi aggiorna di nuovo.';
  }

  @override
  String get updateWatchStatusOnYourServer =>
      'Aggiorna lo stato di visione sul tuo server';

  @override
  String get updateWatchStatusOnYourServers =>
      'Aggiorna lo stato di visione sui tuoi server';

  @override
  String updateWatchStatusOn(Object name) {
    return 'Aggiorna lo stato di visione su $name';
  }

  @override
  String get poolFoldersBumpers =>
      'Ogni video in queste cartelle (e nelle sottocartelle) apre e chiude le pause, e non va mai in onda come programma.';

  @override
  String get poolFoldersCommercials =>
      'Ogni video in queste cartelle (e nelle sottocartelle) riempie le pause, e non va mai in onda come programma.';

  @override
  String get newPin => 'Nuovo PIN';

  @override
  String namedPin(Object name) {
    return 'PIN di $name';
  }

  @override
  String get qualitySameAsProfile => 'Qualità: come il profilo';

  @override
  String qualityValue(Object limit) {
    return 'Qualità: $limit';
  }

  @override
  String onChannel(Object channel) {
    return 'su $channel';
  }

  @override
  String get aChannelThatIsGone => 'un canale che non esiste più';

  @override
  String liveFrom(Object source) {
    return 'In diretta da $source';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'Logo $mode · Prime visioni $premieres';
  }

  @override
  String get offLower => 'disattivato';

  @override
  String streamingNow(Object count) {
    return 'Streaming in corso: $count.';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return 'Streaming in corso: $count · codifica con $encoder.';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · Canali: $chosen di $channels';
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
    return 'Del $when ($device): $profiles. Canali: $channels, blocchi di programmazione: $blocks, loghi: $logos.';
  }

  @override
  String get backupSavedFirst =>
      'Prima viene salvato un backup di ciò che c\'è qui ora.';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuove serie',
      one: '$count nuova serie',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi episodi',
      one: '$count nuovo episodio',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi film',
      one: '$count nuovo film',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi brani',
      one: '$count nuovo brano',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return 'Trasmette $list.';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi canali',
      one: '$count nuovo canale',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => 'Bambini piccoli';

  @override
  String get kidRatingYoungDescription => 'TV-Y e TV-Y7';

  @override
  String get kidRatingKids => 'Bambini';

  @override
  String get kidRatingKidsDescription => 'Fino a TV-G e G';

  @override
  String get kidRatingOlder => 'Bambini più grandi';

  @override
  String get kidRatingOlderDescription => 'Fino a TV-PG e PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profili',
      one: '$count profilo',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali',
      one: '$count canale',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocchi',
      one: '$count blocco',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fasce',
      one: '$count fascia',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video nelle sue cartelle',
      one: '$count video nelle sue cartelle',
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
  String get liveLabel => 'Diretta';

  @override
  String get aMidRollOpens =>
      'Un mid-roll si apre e si chiude con uno stacco, un post-roll si apre con uno e un pre-roll si chiude con uno. Le pubblicità riempiono il resto.';

  @override
  String get programsPlayBack =>
      'I programmi vanno in onda uno dopo l\'altro, senza pause.';

  @override
  String get everyShowFills =>
      'Ogni serie riempie una fascia di mezz\'ora (un\'ora o più per quelle lunghe), così la guida resta in orario.';

  @override
  String get chooseHowLong =>
      'Scegli la durata di ogni pausa, quanto spesso interrompere le serie e da quale gruppo prende ogni pausa.';

  @override
  String get kindSentenceAutomatic => 'automatico';

  @override
  String get kindSentenceBeforeRestore => 'prima del ripristino';

  @override
  String get kindSentenceBeforeReset => 'prima del ripristino iniziale';

  @override
  String get kindSentenceBeforeDeletingAProfile =>
      'prima di eliminare un profilo';

  @override
  String kindSentenceBeforeDeleting(Object subject) {
    return 'prima di eliminare $subject';
  }

  @override
  String get kindSentenceBeforeUpdate => 'prima dell\'aggiornamento';

  @override
  String get kindSentenceBeforeLineupCleanup =>
      'prima della pulizia del palinsesto';

  @override
  String get kindSentenceFromAFile => 'da un file';

  @override
  String get kindSentenceMovingToOfficial => 'trasferimento a Nightingale TV';

  @override
  String get kindSentenceMovingToOwnBuild =>
      'trasferimento a Nightingale TV (versione personale)';

  @override
  String get kindSentenceFromOfficial => 'da Nightingale TV';

  @override
  String get kindSentenceFromOwnBuild =>
      'da Nightingale TV (versione personale)';

  @override
  String get kindSentenceMadeByYou => 'creato da te';

  @override
  String get copyAction => 'Copia';

  @override
  String get channelKidsZone => 'Zona Bimbi';

  @override
  String get channelToonTv => 'Toon TV';

  @override
  String get channelLaughTrack => 'Risate Registrate';

  @override
  String get channelFamilyRoom => 'Salotto di Famiglia';

  @override
  String get channelAdventureTv => 'Avventura TV';

  @override
  String get channelSciFiFantasy => 'Fantascienza e Fantasy';

  @override
  String get channelMysteryTv => 'Mistero TV';

  @override
  String get channelDramaCentral => 'Drama Centrale';

  @override
  String get channelCrimeJustice => 'Crimine e Giustizia';

  @override
  String get channelThrillTv => 'Brividi TV';

  @override
  String get channelFrightNight => 'Notte da Paura';

  @override
  String get channelRomanceTv => 'Romance TV';

  @override
  String get channelDiscoveryZone => 'Zona Scoperta';

  @override
  String get channelMusicTv => 'Musica TV';

  @override
  String get channelRealityTv => 'Reality TV';

  @override
  String get channelGameShowTv => 'Quiz TV';

  @override
  String get channelFrontierTv => 'Frontiera TV';

  @override
  String get channelHistoryTv => 'Storia TV';

  @override
  String get channelSportsTv => 'Sport TV';

  @override
  String get channelNewsTv => 'Notizie TV';

  @override
  String get channelAllShows => 'Tutte le serie';

  @override
  String get channelMovieChannel => 'Canale Film';

  @override
  String get channelMusicVideos => 'Video musicali';

  @override
  String get channelMusicRadio => 'Radio Musica';

  @override
  String get genreActionAdventure => 'Azione e avventura';

  @override
  String get genreSciFiFantasy => 'Fantascienza e fantasy';

  @override
  String get genreKids => 'Bambini';

  @override
  String get genreAnimation => 'Animazione';

  @override
  String get genreComedy => 'Commedia';

  @override
  String get genreFamily => 'Famiglia';

  @override
  String get genreDrama => 'Drammatico';

  @override
  String get genreCrime => 'Crimine';

  @override
  String get genreMystery => 'Mistero';

  @override
  String get genreThriller => 'Thriller';

  @override
  String get genreHorror => 'Horror';

  @override
  String get genreRomance => 'Sentimentale';

  @override
  String get genreDocumentary => 'Documentario';

  @override
  String get genreMusic => 'Musica';

  @override
  String get genreReality => 'Reality';

  @override
  String get genreGameShows => 'Quiz';

  @override
  String get genreWestern => 'Western';

  @override
  String get genreWar => 'Guerra';

  @override
  String get genreHistory => 'Storia';

  @override
  String get genreNews => 'Notizie';

  @override
  String get genreTalk => 'Talk show';

  @override
  String get genreSoap => 'Soap opera';

  @override
  String get genreSports => 'Sport';

  @override
  String get genreClassical => 'Classica';

  @override
  String get genreElectronic => 'Elettronica';

  @override
  String get genreCountry => 'Country';

  @override
  String get genreLatin => 'Latina';

  @override
  String get genreSoundtrack => 'Colonne sonore';

  @override
  String get genreOldies => 'Successi del passato';

  @override
  String get genreDance => 'Dance';

  @override
  String get genreFolk => 'Folk';

  @override
  String get genreAlternative => 'Alternativa';

  @override
  String get blockDaytime => 'Giorno';

  @override
  String get blockMovieNight => 'Serata Cinema';

  @override
  String get blockNewEpisodes => 'Nuovi episodi';

  @override
  String get kindShow => 'Serie';

  @override
  String get kindShows => 'Serie';

  @override
  String get kindMovies => 'Film';

  @override
  String get kindMusicVideos => 'Video musicali';

  @override
  String get kindRadio => 'Radio';

  @override
  String genreMovies(Object genre) {
    return 'Film $genre';
  }

  @override
  String genreMusicVideos(Object genre) {
    return 'Video musicali $genre';
  }

  @override
  String genreRadio(Object genre) {
    return 'Radio $genre';
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
  String get lateNightTitle => 'Notte fonda';

  @override
  String get languageTitle => 'Lingua';

  @override
  String get stillWatchingOff => 'Disattivato';

  @override
  String afterHours(int hours) {
    return 'Dopo $hours ore';
  }

  @override
  String get bitrateOriginal => 'Originale (senza limiti)';

  @override
  String get bitrate40 => '40 Mbps · 4K';

  @override
  String get bitrate20 => '20 Mbps · 1080p alta';

  @override
  String get bitrate12 => '12 Mbps · 1080p';

  @override
  String get bitrate8 => '8 Mbps · 1080p';

  @override
  String get bitrate4 => '4 Mbps · 720p';

  @override
  String get noSuchLanguage => 'Lingua inesistente.';

  @override
  String get languageField => 'Lingua';

  @override
  String get remotePageTitle => 'Telecomando Nightingale TV';

  @override
  String get remotePairTitle => 'Associa alla TV';

  @override
  String get remotePairHelp =>
      'Scansiona il codice sulla TV (Menu → Telecomando sul telefono), o inserisci il codice a 6 cifre mostrato lì.';

  @override
  String get remotePairingCode => 'Codice di associazione';

  @override
  String get remotePair => 'Associa';

  @override
  String get remoteConnecting => 'Connessione…';

  @override
  String get remoteTabRemote => 'Telecomando';

  @override
  String get remoteUp => 'Su';

  @override
  String get remoteLeft => 'Sinistra';

  @override
  String get remoteRight => 'Destra';

  @override
  String get remoteDown => 'Giù';

  @override
  String get remoteInfo => 'Info';

  @override
  String get remoteLastCh => 'Ultimo';

  @override
  String get remoteCc => 'SUB';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => 'Invio';

  @override
  String get remoteRemovedFromTv =>
      'Questo telefono è stato rimosso dalla TV. Scansiona il codice per associarlo di nuovo.';

  @override
  String get remoteCouldntPair => 'Impossibile associare. Riprova.';

  @override
  String get remoteCantReachWifi =>
      'Impossibile raggiungere la TV. Questo telefono è sullo stesso Wi-Fi?';

  @override
  String get remoteEnterDigits => 'Inserisci le 6 cifre mostrate sulla TV.';

  @override
  String get remoteCantReachTv => 'Impossibile raggiungere la TV';

  @override
  String get remotePickProfile => 'Scegli un profilo con le frecce e OK.';

  @override
  String remoteWatching(Object name) {
    return 'Sta guardando: $name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name (bambino)';
  }

  @override
  String get transferPageTitle => 'Backup di Nightingale TV';

  @override
  String get transferIntro =>
      'Sposta un backup tra questa TV e questo dispositivo. Tieni aperta la finestra sulla TV nel frattempo.';

  @override
  String get transferDownload => 'Scarica backup';

  @override
  String get transferDownloadHelp =>
      'Un backup della configurazione attuale della TV: profili, canali, blocchi e impostazioni.';

  @override
  String get transferRestoreTitle => 'Ripristina da un file';

  @override
  String transferRestoreHelp(Object file) {
    return 'Invia un file $file alla TV. Non cambia nulla finché non confermi sulla TV.';
  }

  @override
  String get transferChoose => 'Scegli un file di backup…';

  @override
  String get transferFoot =>
      'Solo i dispositivi sulla tua rete domestica possono aprire questa pagina.';

  @override
  String transferSending(Object name) {
    return 'Invio di $name…';
  }

  @override
  String get transferCheckTv => 'Controlla la TV per terminare.';

  @override
  String get transferClosed =>
      'La TV ha chiuso questa pagina. Riaprila da Backup e ripristino.';

  @override
  String get transferCouldntTake => 'La TV non ha potuto accettare quel file.';

  @override
  String get transferCouldntReach =>
      'Impossibile raggiungere la TV. Mostra ancora il codice?';

  @override
  String get includeShows => 'Includi serie';

  @override
  String get everyShow2 => 'ogni serie';

  @override
  String get decades => 'Decenni';

  @override
  String get decadesHeading => 'DECENNI';

  @override
  String get channelActionTv => 'Azione TV';

  @override
  String get channelSciFiTv => 'Fantascienza TV';

  @override
  String get channelFantasyTv => 'Fantasy TV';

  @override
  String get channelMysteryThrills => 'Mistero e Brividi';

  @override
  String get genreAction => 'Azione';

  @override
  String get genreAdventure => 'Avventura';

  @override
  String get genreSciFi => 'Fantascienza';

  @override
  String get genreFantasy => 'Fantasy';

  @override
  String get genreThrillerMystery => 'Thriller e mistero';

  @override
  String decadeTv(Object decade) {
    return '$decade TV';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$genre TV $decade';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return 'Film $genre $decade';
  }

  @override
  String get errorReports => 'Segnalazioni di errori';

  @override
  String get sendErrorReportsFrom =>
      'Invia segnalazioni di errori da questo dispositivo';

  @override
  String get errorReportsExplain =>
      'Quando qualcosa va storto, Nightingale TV invia allo sviluppatore una breve segnalazione: l\'errore, la versione dell\'app, il tipo di dispositivo e le ultime schermate e i numeri dei canali. Indirizzi dei server, password e chiavi, nomi e percorsi dei file vengono tolti prima dell\'invio. I titoli e ciò che guardi non vengono mai inviati.';

  @override
  String get errorReportsOff =>
      'Se lo disattivi, da questo dispositivo non viene inviato nulla; le segnalazioni in attesa vengono eliminate.';

  @override
  String get sendATestReport => 'Invia una segnalazione di prova';

  @override
  String lastReportId(String id) {
    return 'ID dell\'ultima segnalazione: $id';
  }

  @override
  String get noReportSentYet =>
      'Nessuna segnalazione ancora inviata da questo dispositivo.';

  @override
  String get quoteReportId =>
      'Indica questo ID quando segnali un problema allo sviluppatore.';

  @override
  String testReportSent(String id) {
    return 'Segnalazione di prova inviata: $id';
  }

  @override
  String get testReportNotSent =>
      'Impossibile inviare la segnalazione di prova. Riprova tra un momento.';

  @override
  String get reportsNotInBuild =>
      'Le segnalazioni di errori non fanno parte di questa build di Nightingale TV, quindi non viene mai inviato nulla.';

  @override
  String get sendAVideoReport => 'Invia una segnalazione video';

  @override
  String get videoReportHelp =>
      'Se l\'immagine sembra sbagliata, premi qui e torna a un canale. Dopo 10 secondi di immagine, la segnalazione viene inviata e il suo ID compare sullo schermo TV.';

  @override
  String get videoReportArmed =>
      'Torna ora a un canale. La segnalazione video viene inviata dopo 10 secondi di immagine.';

  @override
  String get videoReportTooSoon =>
      'Una segnalazione video è stata inviata meno di un minuto fa. Riprova tra un attimo.';

  @override
  String videoReportSent(String id) {
    return 'Segnalazione video inviata: $id';
  }

  @override
  String get videoReportsExplain =>
      'Una segnalazione video invia dati sul dispositivo, sul video e sul suo decoder, griglie di colore approssimative dell\'immagine e le ultime righe del registro dell\'app; mai un\'immagine di ciò che guardi. Ne viene inviata una dopo ogni aggiornamento dell\'app, quando un canale è stato riprodotto per 10 secondi.';
}
