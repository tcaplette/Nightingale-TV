// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get onlyChannelsYou =>
      'Seules les chaînes que vous avez ajoutées peuvent être supprimées. Masquez plutôt celle-ci.';

  @override
  String get music => 'Musique';

  @override
  String get nothingInThe => 'Rien dans la bibliothèque ne correspond.';

  @override
  String get chooseSongsOr => 'Choisissez des morceaux ou des clips.';

  @override
  String get blockChannel => 'Chaîne de blocs';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return 'Cela chevauche « $title » ($clash) sur la même chaîne.';
  }

  @override
  String get chooseSomeShows =>
      'Choisissez des séries ou des films à diffuser dans le bloc.';

  @override
  String nothingInThis(Object shortLabel) {
    return 'Rien dans ce mélange n\'est classé $shortLabel ou plus. Choisissez une classification plus basse ou d\'autres séries.';
  }

  @override
  String get theLineupsShows =>
      'Les séries de la grille n\'ont aucun épisode. Choisissez d\'autres séries.';

  @override
  String get addAShow => 'Ajoutez une série à la grille.';

  @override
  String get chooseAChannel => 'Choisissez une chaîne.';

  @override
  String get theBlockHas =>
      'Le bloc doit se terminer à une autre heure que son début.';

  @override
  String get pickAtLeast => 'Choisissez au moins un jour.';

  @override
  String get giveTheBlock => 'Donnez un titre au bloc.';

  @override
  String get thisChannelDoesnt => 'Cette chaîne n\'a pas de créneaux.';

  @override
  String get onlyShuffledChannels =>
      'Seules les chaînes en lecture aléatoire peuvent être remélangées.';

  @override
  String get chooseSomethingFor => 'Choisissez ce que la chaîne doit diffuser.';

  @override
  String get onlyChannelsYouAdded =>
      'Seules les chaînes que vous avez ajoutées peuvent changer de programme.';

  @override
  String get myChannel => 'Ma chaîne';

  @override
  String get noneOfYour => 'Aucun de vos serveurs n\'a pu être joint.';

  @override
  String scanning(Object where) {
    return 'Analyse de $where…';
  }

  @override
  String get buildingChannels => 'Création des chaînes…';

  @override
  String get notSignedIn => 'Non connecté.';

  @override
  String isAlreadyIn(Object name) {
    return '$name est déjà dans ce profil';
  }

  @override
  String get thatServerIs => 'Ce serveur n\'est plus dans ce profil';

  @override
  String get yourSessionExpired =>
      'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get m3uPlaylist => 'Liste de lecture M3U';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName n\'a aucune chaîne en direct';
  }

  @override
  String couldntReach(Object serverName) {
    return 'Impossible de joindre $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return 'TV en direct $serverName';
  }

  @override
  String liveTvIs(Object serverName) {
    return 'La TV en direct $serverName est déjà une source';
  }

  @override
  String get notSignedIn2 => 'Non connecté';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get thisBackupIs =>
      'Cette sauvegarde est endommagée : un de ses logos de chaîne est illisible.';

  @override
  String get thisBackupIsDamaged =>
      'Cette sauvegarde est endommagée : ses réglages d\'export TV en direct sont illisibles.';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'Cette sauvegarde est endommagée : $what de $name est illisible.';
  }

  @override
  String get liveTvSources => 'Sources TV en direct';

  @override
  String thisBackupCant(Object problem) {
    return 'Cette sauvegarde ne peut pas être restaurée. $problem';
  }

  @override
  String get thisBackupIsDamagedIts =>
      'Cette sauvegarde est endommagée : ses profils sont illisibles.';

  @override
  String get thisFileIs =>
      'Ce fichier est trop volumineux pour être une sauvegarde Nightingale TV.';

  @override
  String get thisBackupWas =>
      'Cette sauvegarde a été créée par une version plus récente de Nightingale TV.';

  @override
  String get thisFileIsnt =>
      'Ce fichier n\'est pas une sauvegarde Nightingale TV ou il est endommagé.';

  @override
  String restoredTheBackup(Object toLocal) {
    return 'Sauvegarde du $toLocal restaurée.';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'Impossible de restaurer la sauvegarde : $e';
  }

  @override
  String couldntSaveA(Object e) {
    return 'Impossible d\'enregistrer d\'abord une sauvegarde : $e';
  }

  @override
  String get madeByYou => 'Créée par vous';

  @override
  String get fromNightingaleTv => 'Depuis Nightingale TV (version personnelle)';

  @override
  String get fromNightingaleTv2 => 'Depuis Nightingale TV';

  @override
  String get movingToNightingale =>
      'Transfert vers Nightingale TV (version personnelle)';

  @override
  String get movingToNightingaleTv => 'Transfert vers Nightingale TV';

  @override
  String get fromAFile => 'Depuis un fichier';

  @override
  String get beforeLineupCleanup => 'Avant le nettoyage de la grille';

  @override
  String get beforeUpdate => 'Avant la mise à jour';

  @override
  String beforeDeleting(Object subject) {
    return 'Avant la suppression de $subject';
  }

  @override
  String get beforeDeletingA => 'Avant la suppression d\'un profil';

  @override
  String get beforeReset => 'Avant la réinitialisation';

  @override
  String get beforeRestore => 'Avant la restauration';

  @override
  String get automatic => 'Automatique';

  @override
  String get nc1718 => 'NC-17 / 18 et plus';

  @override
  String get tvMaR => 'TV-MA / R et plus';

  @override
  String get tv14Pg => 'TV-14 / PG-13 et plus';

  @override
  String get off => 'Désactivé';

  @override
  String get nowAndThen => 'De temps en temps';

  @override
  String get always => 'Toujours';

  @override
  String get truncate => 'Couper';

  @override
  String get offlineImage => 'Image hors antenne';

  @override
  String get filler => 'Bouche-trou';

  @override
  String get leastWatchedFirst => 'Les moins vus d\'abord';

  @override
  String get shuffled => 'Aléatoire';

  @override
  String get inOrderShows => 'Dans l\'ordre (les séries alternent)';

  @override
  String get channelsWhereEverything =>
      'Chaînes dont tout le contenu, blocs compris, est classé TV-Y, TV-Y7, TV-G ou G.';

  @override
  String get musicVideoAnd => 'Chaînes de clips et de radio.';

  @override
  String get channelsThatPlay =>
      'Chaînes qui diffusent des films, sans épisodes ni musique.';

  @override
  String get channelsFromYour => 'Chaînes issues de vos sources TV en direct.';

  @override
  String get channelsYouMarked =>
      'Chaînes que vous avez marquées comme favorites.';

  @override
  String get everyChannel => 'Toutes les chaînes.';

  @override
  String get kids => 'Enfants';

  @override
  String get movies => 'Films';

  @override
  String get liveTv2 => 'TV en direct';

  @override
  String get favorites => 'Favoris';

  @override
  String get all => 'Tout';

  @override
  String get theAccentsAre =>
      'Les accents sont un thème, avec « theme » ou « channel » pour chacun.';

  @override
  String get thoseArentRetro => 'Ce ne sont pas des réglages rétro.';

  @override
  String get theOverlayTheme =>
      'Le thème d\'incrustation est standard, vcr, cableBox ou stationIdent.';

  @override
  String get theCrtEffect =>
      'L\'effet CRT est off, softTube, livingRoom, arcade, studioMonitor ou custom.';

  @override
  String get theSurroundImage => 'L\'image d\'entourage est un nom de fichier.';

  @override
  String get theSurroundIs =>
      'L\'entourage est black, charcoal, channel ou image.';

  @override
  String get thePictureShape =>
      'La forme de l\'image est original, fill43 ou fit43.';

  @override
  String get channelColor => 'Couleur de la chaîne';

  @override
  String get theme => 'Thème';

  @override
  String get stationIdent => 'Habillage de chaîne';

  @override
  String get cableBox => 'Décodeur';

  @override
  String get vcr => 'Magnétoscope';

  @override
  String get standard => 'Standard';

  @override
  String get custom => 'Personnalisé';

  @override
  String get studioMonitor => 'Moniteur de studio';

  @override
  String get arcade => 'Arcade';

  @override
  String get livingRoom => 'Salon';

  @override
  String get softTube => 'Tube doux';

  @override
  String get customColorIs =>
      'La couleur personnalisée est natural, warm, faded ou vivid.';

  @override
  String get customLinesIs => 'Les lignes personnalisées sont 240 ou 480.';

  @override
  String customIsOff(Object key) {
    return '$key personnalisé est off, low, medium ou high.';
  }

  @override
  String get thatIsntA => 'Ce n\'est pas un style personnalisé.';

  @override
  String get vivid => 'Vive';

  @override
  String get faded => 'Délavée';

  @override
  String get warm => 'Chaude';

  @override
  String get natural => 'Naturelle';

  @override
  String get high => 'Élevé';

  @override
  String get medium => 'Moyen';

  @override
  String get low => 'Faible';

  @override
  String get image => 'Image';

  @override
  String get charcoal => 'Anthracite';

  @override
  String get black => 'Noir';

  @override
  String get n43Fit => '4:3 ajusté';

  @override
  String get n43Fill => '4:3 rempli';

  @override
  String get original => 'Original';

  @override
  String get thisChannelIs => 'Cette chaîne n\'est pas à l\'antenne';

  @override
  String get offAir => 'Hors antenne';

  @override
  String get tail => 'Remplissage';

  @override
  String get postRoll => 'Post-roll';

  @override
  String get midRoll => 'Mid-roll';

  @override
  String get preRoll => 'Pré-roll';

  @override
  String get commercials => 'Publicités';

  @override
  String get bumpers => 'Jingles';

  @override
  String get pleaseStandBy => 'VEUILLEZ PATIENTER';

  @override
  String get offTheAir => 'HORS ANTENNE';

  @override
  String get wellBeRight => 'Nous revenons tout de suite';

  @override
  String upNextAt(Object at) {
    return 'À suivre à $at';
  }

  @override
  String backOnThe(Object next, Object title) {
    return 'De retour à l\'antenne $next avec $title';
  }

  @override
  String get processor => 'Processeur';

  @override
  String get graphicsCardNvenc => 'Carte graphique (NVENC)';

  @override
  String get graphicsCardVaapi => 'Carte graphique (VAAPI)';

  @override
  String get signInTo =>
      'Connectez ce profil sur la TV pour exporter ses chaînes.';

  @override
  String get signInToThis =>
      'Connectez ce profil ici pour exporter ses chaînes.';

  @override
  String portIsIn(Object port) {
    return 'Le port $port est utilisé par un autre programme. Choisissez un autre port, puis mettez-le à jour dans Plex ou Jellyfin.';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'Un autre profil utilise déjà le port $port.';
  }

  @override
  String get pickAPort => 'Choisissez un port entre 1024 et 65535.';

  @override
  String get movie => 'Film';

  @override
  String backOnTheAir(Object start, Object title) {
    return 'De retour à l\'antenne $start avec $title.';
  }

  @override
  String get images => 'Images';

  @override
  String get couldNotRead =>
      'Impossible de lire cette image. Essayez PNG, JPG, WebP ou SVG.';

  @override
  String get thatFileIs => 'Ce fichier n\'est pas un SVG valide.';

  @override
  String get thatImageIs =>
      'Cette image dépasse 20 Mo. Veuillez en choisir une plus petite.';

  @override
  String get other => 'Autres';

  @override
  String get seasonsHolidays => 'Saisons et fêtes';

  @override
  String get newsWeather => 'Actualités et météo';

  @override
  String get sports => 'Sport';

  @override
  String get genres => 'Genres';

  @override
  String get kidsFamily => 'Enfants et famille';

  @override
  String get tvMovies => 'TV et films';

  @override
  String get theServerWould => 'Le serveur n\'a pas converti cet élément.';

  @override
  String get theServerHas =>
      'Le serveur n\'a aucune version lisible de cet élément.';

  @override
  String get externalLabel => 'Externes';

  @override
  String get scanningChannelSources => 'Analyse des sources de chaînes…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl n\'a pas répondu comme un serveur Jellyfin.';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return 'Aucun serveur Jellyfin trouvé à $serverUrl. $message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return 'Erreur serveur $statusCode sur $path.';
  }

  @override
  String get wrongUsernameOr =>
      'Nom d\'utilisateur ou mot de passe incorrect, ou session expirée.';

  @override
  String couldNotReach(Object e) {
    return 'Impossible de joindre le serveur ($e).';
  }

  @override
  String get theServerTook => 'Le serveur a mis trop de temps à répondre.';

  @override
  String get theServerWouldNot => 'Le serveur n\'a pas converti cette chaîne.';

  @override
  String get musicVideo => 'Clip musical';

  @override
  String movie2(Object year) {
    return 'Film · $year';
  }

  @override
  String get commercial => 'Publicité';

  @override
  String couldntReachThe(Object what) {
    return '$what : impossible de joindre';
  }

  @override
  String theIsToo(Object what) {
    return '$what : trop volumineux';
  }

  @override
  String theSAddress(Object what) {
    return '$what : l\'adresse n\'est pas une adresse web';
  }

  @override
  String get noGuideInformation => 'Aucune information de programme';

  @override
  String get serverLiveTv => 'TV en direct du serveur';

  @override
  String get theChannelHas => 'La chaîne n\'a pas d\'adresse de flux.';

  @override
  String get couldntReadThe => 'Impossible de lire le guide';

  @override
  String get couldntReachTheGuide => 'Impossible de joindre le guide';

  @override
  String get theSourceHas => 'La source n\'a pas de liste de lecture';

  @override
  String get couldntReachThePlaylist =>
      'Impossible de joindre la liste de lecture';

  @override
  String get couldntReadThePlaylist =>
      'Impossible de lire le fichier de liste de lecture';

  @override
  String couldntRefresh(Object name) {
    return 'Impossible d\'actualiser $name';
  }

  @override
  String get thePlaylistHas => 'La liste de lecture n\'a aucune chaîne';

  @override
  String get thatIsntAn => 'Ce n\'est pas une liste de lecture M3U';

  @override
  String get thatIsntAnXmltv => 'Ce n\'est pas un guide XMLTV';

  @override
  String get theGuideIs => 'Le guide est trop volumineux (plus de 1 Go)';

  @override
  String get nightingaleTvBackups => 'Sauvegardes Nightingale TV';

  @override
  String get uninstallingThisApp =>
      'Désinstaller cette appli supprime ses profils, chaînes et réglages, sauf si vous les sauvegardez ou les transférez d\'abord.';

  @override
  String theStoreVersion(Object officialName) {
    return 'La version de la boutique s\'installe à côté de celle-ci comme appli distincte, « $officialName », avec sa propre configuration. L\'acheter soutient le projet. Une fois installée, votre configuration peut y être transférée d\'ici.';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Les mises à jour de Google Play et les APK officiels de Nightingale TV s\'installent par-dessus celle-ci et conservent votre configuration. Une version personnelle s\'installe comme appli distincte, « $ownBuildName », et votre configuration peut y être transférée d\'ici.';
  }

  @override
  String get yourOwnBuild => 'Votre version personnelle';

  @override
  String get officialNightingaleTv => 'APK officiel de Nightingale TV';

  @override
  String get installedFromGoogle => 'Installé depuis Google Play';

  @override
  String get nightingaleTvOwn => 'Nightingale TV (version personnelle)';

  @override
  String get sleepTimerOff => 'Minuteur de veille désactivé';

  @override
  String get sleepAtEnd => 'Veille à la fin du programme';

  @override
  String sleepInMin(Object minutes) {
    return 'Veille dans $minutes min';
  }

  @override
  String get forced => 'Forcés';

  @override
  String get unknownLanguage => 'Langue inconnue';

  @override
  String didntStart(Object name) {
    return '$name n\'a pas démarré';
  }

  @override
  String get thisDeviceCant =>
      'Cet appareil ne peut pas lire la vidéo de cette chaîne';

  @override
  String get thisChannelsStream =>
      'Le type de flux de cette chaîne n\'est pas pris en charge sur cet appareil';

  @override
  String refusedTheStream(Object name) {
    return '$name a refusé le flux. Il est peut-être lu sur un autre appareil.';
  }

  @override
  String yourAccountCant(Object server) {
    return 'Votre compte $server ne peut pas regarder cette chaîne';
  }

  @override
  String cantReach(Object name) {
    return 'Impossible de joindre $name';
  }

  @override
  String allOfS(Object server) {
    return 'Tous les tuners de $server sont occupés';
  }

  @override
  String lostTheSignal(Object name) {
    return 'Signal perdu sur $name';
  }

  @override
  String get couldntPlayThat =>
      'Impossible de lire cette partie. Retour au direct';

  @override
  String get backToLive => 'Retour au direct';

  @override
  String get theServerTookToo =>
      'Le serveur a mis trop de temps à commencer la conversion de ce programme.';

  @override
  String get nothingToPlay => 'Rien à lire sur cette chaîne';

  @override
  String captionsOn(Object shown) {
    return 'Sous-titres activés : $shown';
  }

  @override
  String get captionsOn2 => 'Sous-titres activés';

  @override
  String get captionsOnNo =>
      'Sous-titres activés : aucun sous-titre pour ce programme';

  @override
  String get captionsOff => 'Sous-titres désactivés';

  @override
  String get guest => 'Invité';

  @override
  String get thereHasTo => 'Il doit y avoir au moins un profil adulte.';

  @override
  String get switchToAnother =>
      'Passez à un autre profil avant de supprimer celui-ci.';

  @override
  String get me => 'Moi';

  @override
  String get couldntOpenA =>
      'Impossible d\'ouvrir un port réseau pour la télécommande.';

  @override
  String get notPaired => 'Non associé';

  @override
  String get phone => 'Téléphone';

  @override
  String get thatCodeDoesnt =>
      'Ce code ne correspond pas. Vérifiez le code sur la TV.';

  @override
  String get openMenuPhone =>
      'Ouvrez Menu → Télécommande sur la TV pour associer';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'Votre compte $serverName ne peut pas regarder la TV en direct';
  }

  @override
  String get enterYourServer => 'Saisissez l\'adresse de votre serveur.';

  @override
  String get needsSignIn => 'Connexion requise';

  @override
  String get cantBeReached => 'Injoignable';

  @override
  String isNotAnswering(Object name) {
    return '$name ne répond à aucune de ses adresses. Est-il allumé ?';
  }

  @override
  String get everyServerOn =>
      'Tous les serveurs de ce compte Plex sont déjà dans ce profil.';

  @override
  String get thisPlexAccount =>
      'Ce compte Plex n\'a aucun serveur. Demandez à son propriétaire de le partager avec vous.';

  @override
  String quickConnectStopped(Object message) {
    return 'Quick Connect s\'est arrêté : $message';
  }

  @override
  String get enterYourUsername => 'Saisissez votre nom d\'utilisateur.';

  @override
  String get plexDidNot => 'Plex n\'a pas changé d\'utilisateur.';

  @override
  String plexTvError(Object statusCode) {
    return 'Erreur plex.tv $statusCode.';
  }

  @override
  String get yourPlexSign => 'Votre connexion Plex a expiré.';

  @override
  String couldNotReachPlex(Object e) {
    return 'Impossible de joindre plex.tv ($e).';
  }

  @override
  String get plexTvTook => 'plex.tv a mis trop de temps à répondre.';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — Partagé par $ownerName';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'Le serveur n\'a pas converti cet élément ($transcodeDecisionText).';
  }

  @override
  String get theServerHasNo =>
      'Le serveur n\'a aucun fichier pour cet élément. Actualisez la bibliothèque.';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl n\'a pas répondu comme un serveur Plex.';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return 'Aucun serveur Plex trouvé à $serverUrl. $message';
  }

  @override
  String get thePlexSign => 'La connexion Plex a expiré.';

  @override
  String channelIsNot(Object channelId) {
    return 'La chaîne $channelId n\'est sur aucun DVR.';
  }

  @override
  String get noSuchUser => 'Utilisateur introuvable.';

  @override
  String get yourCurrentPassword => 'Votre mot de passe actuel est incorrect.';

  @override
  String get signInFirst => 'Connectez-vous d\'abord.';

  @override
  String thereIsAlready(Object name) {
    return 'Il existe déjà un utilisateur nommé $name.';
  }

  @override
  String get thisAccountIs => 'Ce compte est désactivé.';

  @override
  String get chooseAnAdmin => 'Choisissez un compte administrateur.';

  @override
  String useAtMost(Object maxNameLength) {
    return 'Utilisez au plus $maxNameLength caractères pour le nom d\'utilisateur.';
  }

  @override
  String get enterAUser => 'Saisissez un nom d\'utilisateur.';

  @override
  String useAtLeast(Object minPasswordLength) {
    return 'Utilisez au moins $minPasswordLength caractères.';
  }

  @override
  String get tooManyWrong =>
      'Trop de mots de passe incorrects. Réessayez dans une minute.';

  @override
  String get wrongUserName => 'Nom d\'utilisateur ou mot de passe incorrect.';

  @override
  String get openTheSetup =>
      'Ouvrez le lien de configuration dans le journal du serveur.';

  @override
  String get makeSomeoneElse =>
      'Nommez d\'abord quelqu\'un d\'autre administrateur.';

  @override
  String get noSuchProfile => 'Profil introuvable.';

  @override
  String get onlyAnAdmin => 'Seul un administrateur peut faire cela.';

  @override
  String get thatProfileIsnt => 'Ce profil ne vous est pas attribué.';

  @override
  String get enterAGrown =>
      'Saisissez le code PIN d\'un adulte pour modifier les réglages d\'un profil enfant.';

  @override
  String get enterThisProfiles => 'Saisissez le code PIN de ce profil.';

  @override
  String get reloadThePage => 'Rechargez la page et réessayez.';

  @override
  String somethingWentWrong(Object e) {
    return 'Une erreur s\'est produite : $e';
  }

  @override
  String get signInToThisProfile => 'Connectez-vous d\'abord à ce profil.';

  @override
  String get changedInAnother =>
      'Modifié dans une autre fenêtre. Affichage de la dernière version.';

  @override
  String get wrongPin => 'Code PIN incorrect.';

  @override
  String get tooManyWrongPins =>
      'Trop de codes PIN incorrects. Réessayez dans une minute.';

  @override
  String get theRoleIs => 'Le rôle est « admin » ou « user ».';

  @override
  String get noSuchBackup => 'Sauvegarde introuvable.';

  @override
  String get backupsAreOff => 'Les sauvegardes sont désactivées.';

  @override
  String get noSuchEncoder => 'Encodeur introuvable.';

  @override
  String get allow1To => 'Autorisez de 1 à 16 flux.';

  @override
  String get noSuchQuality => 'Qualité introuvable.';

  @override
  String get processorOnly => 'Processeur uniquement';

  @override
  String get liveTvExport => 'L\'export TV en direct n\'est pas actif.';

  @override
  String get thoseArentPremiere => 'Ce ne sont pas des réglages de premières.';

  @override
  String get theLogoMode => 'Le mode du logo est always, nowAndThen ou off.';

  @override
  String get thatIsntAPicture =>
      'Ce n\'est pas une image du dossier des logos personnalisés.';

  @override
  String couldntSaveASafety(Object e) {
    return 'Impossible d\'enregistrer d\'abord une sauvegarde de sécurité, rien n\'a donc été réinitialisé : $e';
  }

  @override
  String get theKindIs => 'Le type est « block », « music » ou « custom ».';

  @override
  String get thatIsntAPlay => 'Ce n\'est pas un ordre de lecture.';

  @override
  String get musicChannelsOnly =>
      'Les chaînes musicales sont uniquement en aléatoire.';

  @override
  String get channelNumbersStart => 'Les numéros de chaîne commencent à 1.';

  @override
  String get slotLengthsAre =>
      'Les créneaux durent 15, 30, 60, 90 ou 120 minutes.';

  @override
  String get thatIsntAChannel => 'Ce n\'est pas une chaîne.';

  @override
  String get noSuchChannel => 'Chaîne introuvable.';

  @override
  String get thatPictureIs =>
      'Cette image est trop volumineuse (5 Mo au maximum).';

  @override
  String get unknownAction => 'Action inconnue.';

  @override
  String get noSuchServer => 'Serveur introuvable.';

  @override
  String get startSigningIn => 'Commencez d\'abord la connexion.';

  @override
  String get aRestoreIs => 'Une restauration est déjà en cours.';

  @override
  String get uploadTheBackup => 'Envoyez de nouveau la sauvegarde.';

  @override
  String get discoveryIsOff =>
      'La découverte est désactivée : ajoutez le tuner par son adresse. Lancez le conteneur en réseau hôte pour l\'activer.';

  @override
  String get sendKeys => 'Envoyez « keys ».';

  @override
  String get enterThePlaylists =>
      'Saisissez l\'adresse de la liste de lecture ou choisissez un fichier';

  @override
  String get uploadTheFile => 'Envoyez de nouveau le fichier.';

  @override
  String get kidProfilesGet =>
      'Les profils enfants n\'ont pas de chaînes en direct.';

  @override
  String liveTvIsAlready(Object name) {
    return 'La TV en direct $name est déjà ajoutée';
  }

  @override
  String get noSuchSource => 'Source introuvable.';

  @override
  String get thatFileIsToo =>
      'Ce fichier est trop volumineux (32 Mo au maximum).';

  @override
  String get aPinIs => 'Un code PIN comporte 4 chiffres.';

  @override
  String get noSuchRating => 'Classification introuvable.';

  @override
  String get noSuchKind => 'Type introuvable.';

  @override
  String get onlyAnAdminCan => 'Seul un administrateur peut modifier cela.';

  @override
  String shouldBeA(Object key) {
    return '« $key » doit être une liste de textes.';
  }

  @override
  String shouldBeAn(Object key) {
    return '« $key » doit être un objet.';
  }

  @override
  String shouldBeTrue(Object key) {
    return '« $key » doit être vrai ou faux.';
  }

  @override
  String shouldBeANumber(Object key) {
    return '« $key » doit être un nombre.';
  }

  @override
  String shouldBeText(Object key) {
    return '« $key » doit être un texte.';
  }

  @override
  String get expectedAJson => 'Objet JSON attendu.';

  @override
  String get thatIsToo => 'C\'est trop à envoyer en une fois.';

  @override
  String get aQualityLimit =>
      'Une limite de qualité est d\'au moins 500 kbit/s.';

  @override
  String get orderShouldName =>
      '« order » doit nommer chaque serveur une fois.';

  @override
  String get orderIsMissing => '« order » est absent.';

  @override
  String get signOutOf =>
      'Déconnectez le profil pour changer son serveur principal.';

  @override
  String get thoseArentPool => 'Ce ne sont pas des dossiers de groupe.';

  @override
  String get sendRoots => 'Envoyez « roots ».';

  @override
  String get thatIsntAPool => 'Ce n\'est pas un type de groupe.';

  @override
  String get giveThePool => 'Donnez un nom au groupe.';

  @override
  String get liveChannelsHave => 'Les chaînes en direct n\'ont pas de pauses.';

  @override
  String get sendAPlan => 'Envoyez un plan.';

  @override
  String get thatIsntABreak => 'Ce n\'est pas un plan de pauses.';

  @override
  String get noSuchPool => 'Groupe introuvable.';

  @override
  String get thatIsntAProgramming => 'Ce n\'est pas un bloc de programmes.';

  @override
  String get noSuchBlock => 'Bloc introuvable.';

  @override
  String get sendEveryTab => 'Envoyez chaque onglet une fois.';

  @override
  String get sendChannelids => 'Envoyez « channelIds ».';

  @override
  String get giveTheGroup => 'Donnez un nom au groupe.';

  @override
  String get noSuchGroup => 'Groupe introuvable.';

  @override
  String get restoringBringsBack =>
      'La restauration rétablit vos profils, chaînes, blocs et réglages. Chaque profil se connecte une fois à son serveur.';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels chaînes',
      one: '$profiles · $channels chaîne',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup =>
      'Une sauvegarde de votre configuration se trouve sur cet appareil :';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get moveOkSelect => '◀▶ Déplacer    OK Sélectionner';

  @override
  String get startFresh => 'Repartir de zéro';

  @override
  String get restoreIt => 'La restaurer';

  @override
  String get couldntRestore => 'Restauration impossible';

  @override
  String get cancel => 'Annuler';

  @override
  String get useYourPhone => 'Utiliser votre téléphone ou ordinateur';

  @override
  String get openABackup => 'Ouvrir un fichier de sauvegarde';

  @override
  String get setUpThis =>
      'Configurez cette TV à partir d\'une sauvegarde Nightingale TV : vos profils, chaînes, blocs et réglages. Chaque profil se connecte une fois à son serveur.';

  @override
  String get restoreFromA => 'Restaurer une sauvegarde';

  @override
  String get close => 'Fermer';

  @override
  String get thereYouCan =>
      'Vous pourrez y télécharger une sauvegarde de cette TV ou en envoyer une à restaurer ici. Tout envoi est d\'abord confirmé sur cette TV. La page se ferme avec cette fenêtre.';

  @override
  String get onAPhone =>
      'Sur un téléphone, une tablette ou un ordinateur connecté au même Wi-Fi que cette TV, scannez le code ou ouvrez :';

  @override
  String get couldntOpenANetwork =>
      'Impossible d\'ouvrir un port réseau pour la page.';

  @override
  String get thePageStopped =>
      'La page s\'est arrêtée après 15 minutes d\'inactivité. Fermez ceci et rouvrez-la.';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount et $last';
  }

  @override
  String get restore => 'Restaurer';

  @override
  String get liveTvExportMoves =>
      'L\'export TV en direct passe sur cet appareil. Désactivez-le sur l\'ancien.';

  @override
  String willNeedTo(Object need) {
    return '$need devra se reconnecter à son serveur.';
  }

  @override
  String get itSetsUp => 'Cette TV sera configurée comme dans la sauvegarde.';

  @override
  String get itReplacesEverything =>
      'Tout sera remplacé sur cette TV. Votre configuration actuelle est d\'abord sauvegardée.';

  @override
  String restoreTheBackup(Object toLocal) {
    return 'Restaurer la sauvegarde du $toLocal ?';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get saveToFile => 'Enregistrer dans un fichier';

  @override
  String madeOn(Object device) {
    return 'Créée sur $device';
  }

  @override
  String get moveOkSelectEsc =>
      '▲▼◀▶ Déplacer    OK Sélectionner    ESC Retour';

  @override
  String get backupRestore => 'Sauvegarde et restauration';

  @override
  String get backups => 'SAUVEGARDES';

  @override
  String get backUpNow => 'Sauvegarder maintenant';

  @override
  String get aBackupHolds =>
      'Une sauvegarde contient chaque profil avec ses chaînes, blocs, publicités et réglages, et est créée chaque jour où quelque chose change. Les mots de passe de connexion n\'y figurent jamais.';

  @override
  String lastBackup(Object toLocal, Object kindLabel) {
    return 'Dernière sauvegarde : $toLocal ($kindLabel).';
  }

  @override
  String get noBackupsYet => 'Aucune sauvegarde pour l\'instant.';

  @override
  String itCantBe(Object toLocal, Object kindLabel) {
    return '$toLocal · $kindLabel. Elle ne pourra pas être récupérée.';
  }

  @override
  String get deleteThisBackup => 'Supprimer cette sauvegarde ?';

  @override
  String couldntSaveThe(Object e) {
    return 'Impossible d\'enregistrer la sauvegarde : $e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'Cela n\'a pas fonctionné : $e';
  }

  @override
  String get aNewChannel =>
      'Une nouvelle chaîne est hors antenne en dehors du bloc, comme une chaîne qui s\'arrête la nuit.';

  @override
  String get aNewChannelJust => 'Une nouvelle chaîne rien que pour ce bloc';

  @override
  String get moveOkChoose => '▲▼ Déplacer    OK Choisir    ESC Retour';

  @override
  String get chooseAChannel2 => 'Choisir une chaîne';

  @override
  String episodes(Object keyCount) {
    return 'Épisodes : $keyCount';
  }

  @override
  String get moveOkAdd => '▲▼ Déplacer    OK Ajouter    ESC Retour';

  @override
  String get addAShow2 => 'Ajouter une série';

  @override
  String get remove => 'Retirer';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count épisodes',
      one: '$count épisode',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ Mois';

  @override
  String get day => '+ Jour';

  @override
  String get day2 => '− Jour';

  @override
  String get month2 => '− Mois';

  @override
  String get save => 'Enregistrer';

  @override
  String get everyDay => 'Tous les jours';

  @override
  String get weekends => 'Week-ends';

  @override
  String get weekdays => 'Jours de semaine';

  @override
  String get days => 'JOURS';

  @override
  String get starts => 'Début';

  @override
  String get time => 'HEURE';

  @override
  String get premieresAreOff => 'Les premières sont désactivées';

  @override
  String get premieresAreOn => 'Les premières sont activées';

  @override
  String get onTheAir => 'À L\'ANTENNE';

  @override
  String get episodesAddedTo =>
      'Les épisodes ajoutés à votre serveur ces deux dernières semaines sont diffusés en première dans un créneau nocturne sur la chaîne de leur série : un nouvel épisode par série chaque nuit, jusqu\'à deux heures, marqué NOUVEAU. Les blocs de programmes ont la priorité.';

  @override
  String get moveOkSelectEscCancel =>
      '▲▼◀▶ Déplacer    OK Sélectionner    ESC Annuler';

  @override
  String get newEpisodePremieres => 'Premières des nouveaux épisodes';

  @override
  String get theChannelGoes =>
      'La chaîne reprend ses programmes habituels à ces heures.';

  @override
  String delete2(Object title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get addAnotherShow => 'Ajouter une autre série';

  @override
  String get missingShow => 'Série manquante';

  @override
  String runsThenStarts(Object start) {
    return 'Dure $start, puis recommence.';
  }

  @override
  String get fillsTheBlock => 'Remplit le bloc.';

  @override
  String longerThanThe(Object end, Object title) {
    return 'Plus long que le bloc : il se termine à $end et coupe $title.';
  }

  @override
  String get onTheAirNow => 'À L\'ANTENNE MAINTENANT';

  @override
  String nextAiring(Object start) {
    return 'PROCHAINE DIFFUSION · $start';
  }

  @override
  String inAll(Object runtime) {
    return '$runtime au total';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies films',
      one: '$movies film',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount séries',
      one: '$showsCount série',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose =>
      'Rien pour l\'instant. Choisissez des séries ou des films.';

  @override
  String get nothingYetAdd =>
      'Rien pour l\'instant. Ajoutez des séries à la grille.';

  @override
  String get plays => 'DIFFUSE';

  @override
  String onLabel(Object number, Object name) {
    return 'Sur $number $name';
  }

  @override
  String get noChannelChosen => 'Aucune chaîne choisie';

  @override
  String get onANew =>
      'Sur une nouvelle chaîne (hors antenne le reste du temps)';

  @override
  String get untitledBlock => 'Bloc sans titre';

  @override
  String get deleteBlock => 'Supprimer le bloc';

  @override
  String get blockIsOff => 'Le bloc est désactivé';

  @override
  String get blockIsOn => 'Le bloc est activé';

  @override
  String get onlyShowsAnd =>
      'Uniquement les séries et films classés à ce niveau ou plus. Ceux sans classification sont exclus.';

  @override
  String get anyRating => 'Toute classification';

  @override
  String get minimumRating => 'Classification minimale';

  @override
  String get chooseShowsMovies => 'Choisir des séries et des films';

  @override
  String get showsAndMovies =>
      'Les séries et films de votre choix, dans l\'ordre ou au hasard.';

  @override
  String get yourShowsIn =>
      'Vos séries dans cet ordre, chacune diffusant son épisode suivant à chaque passage. S\'il reste du temps, la grille recommence.';

  @override
  String get aLineup => 'Une grille';

  @override
  String get aMix => 'Un mélange';

  @override
  String get whatItPlays => 'CE QUI EST DIFFUSÉ';

  @override
  String get repeatsEveryYear => 'Se répète chaque année.';

  @override
  String get to => 'Au';

  @override
  String get from => 'Du';

  @override
  String get onlyBetweenDates => 'Seulement entre deux dates';

  @override
  String get allYear => 'Toute l\'année';

  @override
  String get dates => 'DATES';

  @override
  String get nextDay => ' (lendemain)';

  @override
  String get ends => 'Fin';

  @override
  String get channel => 'CHAÎNE';

  @override
  String get saturdayMorningCartoons => 'Dessins animés du samedi matin';

  @override
  String get title => 'Titre';

  @override
  String get newProgrammingBlock => 'Nouveau bloc de programmes';

  @override
  String get newLateNight => 'Nouveau bloc de fin de soirée';

  @override
  String get editProgrammingBlock => 'Modifier le bloc de programmes';

  @override
  String next(Object next, Object next2) {
    return 'Prochaine : $next $next2';
  }

  @override
  String get onTheAirNow2 => 'À l\'antenne maintenant';

  @override
  String get noUpcomingAirings => 'Aucune diffusion à venir';

  @override
  String get itsChannelIs =>
      'Sa chaîne n\'existe plus. Choisissez-en une nouvelle.';

  @override
  String get turnedOff => 'Désactivé';

  @override
  String get blocksTakeOver =>
      'Les blocs prennent le contrôle d\'une chaîne aux jours et heures de votre choix, comme les dessins animés du samedi matin. Chaque diffusion reprend là où la précédente s\'est arrêtée.';

  @override
  String get moveOkEdit => '▲▼ Déplacer    OK Modifier    ESC Retour';

  @override
  String get programmingBlocks => 'Blocs de programmes';

  @override
  String get newlyAddedEpisodes =>
      'Épisodes récemment ajoutés, sur la chaîne de leur série';

  @override
  String get onLabel2 => 'Activé';

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
  String get n100MinMovie => 'Film de 100 min';

  @override
  String get n44MinDrama => 'Drame de 44 min';

  @override
  String get n22MinSitcom => 'Sitcom de 22 min';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: ', $midCount pauses incluses',
      one: ', $midCount pause incluse',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name : aucune pause';
  }

  @override
  String get openAndClose =>
      'Ouvrent et ferment les pauses, depuis les groupes de type Jingles';

  @override
  String get bumpers2 => 'JINGLES';

  @override
  String get toTheHalf => 'À la demi-heure';

  @override
  String get toTheHour => 'À l\'heure pile';

  @override
  String get padsEachSlot =>
      'Complète chaque créneau jusqu\'à l\'heure, pour que les programmes démarrent à temps';

  @override
  String get tail2 => 'REMPLISSAGE';

  @override
  String get afterEachProgram => 'Après chaque programme';

  @override
  String get postRoll2 => 'POST-ROLL';

  @override
  String get length => 'Durée';

  @override
  String get every => 'Toutes les';

  @override
  String min(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get breaksInsideShows =>
      'Pauses dans les séries et films, aux fins d\'actes quand elles sont détectées';

  @override
  String get midRoll2 => 'MID-ROLL';

  @override
  String get beforeEachProgram => 'Avant chaque programme';

  @override
  String get preRoll2 => 'PRÉ-ROLL';

  @override
  String get onePool => 'Un groupe…';

  @override
  String get allBumperPools => 'Tous les groupes de jingles';

  @override
  String get none => 'Aucun';

  @override
  String clipsFrom(Object pool) {
    return 'Clips de : $pool';
  }

  @override
  String get allPools => 'Tous les groupes';

  @override
  String clips2(Object label) {
    return 'Clips $label';
  }

  @override
  String get leave => 'Quitter';

  @override
  String get yourChangesTo =>
      'Vos modifications des réglages de pause seront perdues.';

  @override
  String get leaveWithoutSaving => 'Quitter sans enregistrer ?';

  @override
  String get size => 'Taille';

  @override
  String get captions => 'Sous-titres';

  @override
  String get sampleCaption => 'Exemple de sous-titre';

  @override
  String get theServerDraws =>
      'Le serveur incruste ces sous-titres dans l\'image, leur taille ne peut donc pas changer ici.';

  @override
  String get findingSubtitles => 'Recherche de sous-titres…';

  @override
  String get noSubtitlesFor => 'Aucun sous-titre pour ce programme';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours h $inMinutes min';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed jours';
  }

  @override
  String get theChannelGoesAway =>
      'La chaîne disparaît, avec ses blocs de programmes et ses places dans les groupes de chaînes.';

  @override
  String remove2(Object name) {
    return 'Retirer « $name » ?';
  }

  @override
  String contentOf(Object name) {
    return 'Contenu de $name';
  }

  @override
  String get newChannel => 'Nouvelle chaîne';

  @override
  String get defaultCard => 'Carte par défaut';

  @override
  String get changeOfflineImage => 'Changer l\'image hors antenne…';

  @override
  String get offlineImage2 => 'Image hors antenne…';

  @override
  String fillerPool(Object poolName) {
    return 'Groupe de remplissage : $poolName';
  }

  @override
  String get slotLength => 'DURÉE DU CRÉNEAU';

  @override
  String get hideFromGuide => 'Masquer du guide';

  @override
  String get showInGuide => 'Afficher dans le guide';

  @override
  String get favorite => 'Favori';

  @override
  String get unfavorite => 'Retirer des favoris';

  @override
  String mainSetting(Object label) {
    return 'Réglage principal ($label)';
  }

  @override
  String get channelLogo => 'LOGO DE LA CHAÎNE';

  @override
  String breaksOn(Object name) {
    return 'Pauses sur $name';
  }

  @override
  String get custom2 => 'Personnalisé…';

  @override
  String get commercials2 => 'PUBLICITÉS';

  @override
  String get removeChannel => 'Retirer la chaîne';

  @override
  String get reshuffle => 'Remélanger';

  @override
  String get editContent => 'Modifier le contenu';

  @override
  String get number => 'Numéro +';

  @override
  String get number2 => 'Numéro −';

  @override
  String get sourcesLogo => 'Logo de la source';

  @override
  String get changeIcon => 'Changer l\'icône';

  @override
  String get rename => 'Renommer';

  @override
  String get channelName => 'Nom de la chaîne';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount blocs de programmes',
      one: '$blockCount bloc de programmes',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return 'se répète toutes les $loop';
  }

  @override
  String programs(Object playlistCount) {
    return 'Programmes : $playlistCount';
  }

  @override
  String get programmingBlocksOnly => 'Blocs de programmes uniquement';

  @override
  String channelThere(Object n) {
    return 'chaîne $n là-bas';
  }

  @override
  String channel2(Object number) {
    return 'CHAÎNE $number';
  }

  @override
  String get noChannelsYet => 'Aucune chaîne pour l\'instant';

  @override
  String get guideRange => 'PORTÉE DU GUIDE';

  @override
  String get channelsEditOk =>
      '▲▼ Chaînes    ▶ Modifier    OK Sélectionner    ESC Retour';

  @override
  String get channelsIcons => 'Chaînes et icônes';

  @override
  String get howFarAhead =>
      'Jusqu\'où le guide affiche les programmes à partir de maintenant.';

  @override
  String hours(Object hours) {
    return '$hours heures';
  }

  @override
  String get theChannelLogo =>
      'Le logo de la chaîne dans le coin de l\'image, sur la TV et dans l\'export TV en direct.';

  @override
  String get name => 'Nom';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'CHAÎNES';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String group(Object name) {
    return 'Groupe : $name';
  }

  @override
  String get deleteGroup => 'Supprimer le groupe';

  @override
  String get itsTabLeaves =>
      'Son onglet quitte le guide. Les chaînes restent dans votre grille.';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount chaînes',
      one: '$membersCount chaîne',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => 'Chaînes que vous avez choisies.';

  @override
  String get theTabsAt =>
      'Les onglets en haut du guide, dans cet ordre. Les onglets masqués et ceux sans chaîne ne sont pas affichés.';

  @override
  String get channelGroups => 'Groupes de chaînes';

  @override
  String get shown => 'Affiché';

  @override
  String get down => 'Bas';

  @override
  String get up => 'Haut';

  @override
  String get automatic2 => '· automatique';

  @override
  String channels4(Object channelIdsCount) {
    return '· Chaînes : $channelIdsCount';
  }

  @override
  String get create => 'Créer';

  @override
  String get commercialsNeverShow =>
      'Les publicités n\'apparaissent jamais dans l\'historique de votre serveur.';

  @override
  String get theSameAds =>
      'Les mêmes publicités passent pour tout le monde, à chaque fois.';

  @override
  String get bumperPoolsClips =>
      'Les clips des groupes de jingles ouvrent et ferment les pauses, et ne passent jamais comme publicités.';

  @override
  String get howBreaksWork => 'COMMENT FONCTIONNENT LES PAUSES';

  @override
  String get withATail =>
      'Avec un remplissage, les créneaux sont complétés jusqu\'à l\'heure.';

  @override
  String get adsShrinkTo =>
      'Les publicités s\'ajustent au créneau, et aucune pause ne dépasse 5 minutes.';

  @override
  String get aShortBreak =>
      'Une courte pause avant l\'émission, une pause toutes les 10 minutes pendant (12 pour les films), aux fins d\'actes quand elles sont détectées, et le reste après.';

  @override
  String get pickAutomaticFor =>
      'Choisissez Automatique pour des pauses comme à la télévision, ou Personnalisé pour les régler vous-même.';

  @override
  String workingOn(Object current) {
    return 'Traitement de $current…';
  }

  @override
  String get analysis => 'ANALYSE';

  @override
  String couldNotBe(Object failed) {
    return '$failed n\'ont pas pu être analysés (nouvel essai si le fichier change)';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'Programmes avec points de pause : $programsDone sur $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return 'Longues vidéos découpées : $reelsDone sur $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders dossiers  ·  $idCount',
      one: '$folders dossier  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$clips de $used groupes de publicités.',
      one: '$clips de $used groupe de publicités.',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'Les pauses commencent dès qu\'un groupe a des clips. Ajoutez à un groupe des dossiers contenant des vidéos.';

  @override
  String get breaksStartOnceA =>
      'Les pauses commencent dès qu\'un groupe a des clips. Ses longues vidéos sont en cours de découpage.';

  @override
  String get breaksStartOnceAPool =>
      'Les pauses commencent dès qu\'un groupe a des clips. Créez un groupe ci-dessous.';

  @override
  String breaksAreOff(Object clips) {
    return 'Les pauses sont désactivées. $clips prêts dans vos groupes.';
  }

  @override
  String get breaksAreOff2 => 'Les pauses sont désactivées.';

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
    return 'Échec de la dernière analyse : $syncError';
  }

  @override
  String get newPool => 'Nouveau groupe';

  @override
  String get pickTheFolders =>
      'Choisissez les dossiers de votre serveur qui contiennent publicités et jingles. Leurs vidéos quittent vos chaînes habituelles et remplissent les pauses. Réglez le type d\'un groupe sur Jingles pour que ses clips ouvrent et ferment les pauses.';

  @override
  String get pools => 'GROUPES';

  @override
  String get breakSettings => 'Réglages des pauses…';

  @override
  String get commercialBreaks => 'PAUSES PUBLICITAIRES';

  @override
  String get breakSettings2 => 'Réglages des pauses';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count Les points de pause tombent aussi plus naturellement avec.';
  }

  @override
  String waiting(Object waiting) {
    return ' ($waiting en attente).';
  }

  @override
  String get longCommercialVideos =>
      'Les longues vidéos publicitaires sans chapitres ne peuvent pas être découpées sur cet appareil';

  @override
  String get installFfmpegTo =>
      'Installez ffmpeg pour découper les longues vidéos publicitaires';

  @override
  String get picturesOnThis =>
      'Images de cet appareil, les plus récentes d\'abord. Les grandes sont réduites à 512 px.';

  @override
  String get noPicturesOn =>
      'Aucune image sur cet appareil. Copiez un PNG ou JPG dans son dossier Download ou sur une clé USB, puis réessayez.';

  @override
  String get lookingForPictures => 'Recherche d\'images…';

  @override
  String get couldntReadThePictures =>
      'Impossible de lire les images de cet appareil.';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV n\'est pas autorisé à voir les images de cet appareil. Autorisez « Photos et vidéos » dans Paramètres Android › Applications › Nightingale TV › Autorisations, puis réessayez.';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ Déplacer    OK Choisir    ESC Annuler';

  @override
  String get chooseAPicture => 'Choisir une image';

  @override
  String thePoolHasnt(Object error) {
    return '$error  Le groupe n\'a pas changé.';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  Rien n\'a changé.';
  }

  @override
  String get couldntReachTheServer => 'Impossible de joindre le serveur';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get nothingInside => 'Vide';

  @override
  String get noMovies => 'Aucun film';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount à l\'intérieur';
  }

  @override
  String get video => 'Vidéo';

  @override
  String collection(Object name) {
    return '$name (collection)';
  }

  @override
  String get included => 'Inclus';

  @override
  String get nothingInside2 => 'Vide.';

  @override
  String get loadingFolders => 'Chargement des dossiers…';

  @override
  String get pressOnA =>
      'Appuyez sur ▶ sur une bibliothèque pour voir son contenu.';

  @override
  String get done => 'Terminé';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount cochés';
  }

  @override
  String get nothingTickedYet =>
      'Rien de coché. Cochez une bibliothèque pour tout utiliser, ou ▶ pour choisir son contenu.';

  @override
  String get wholeLibrary => 'Bibliothèque entière';

  @override
  String get libraries => 'BIBLIOTHÈQUES';

  @override
  String get loadingLibraries => 'Chargement des bibliothèques…';

  @override
  String get moveOkTick =>
      '▲▼ Déplacer    OK Cocher    ▶ Ouvrir    ◀ Remonter    ESC Annuler';

  @override
  String foldersFor(Object poolName) {
    return 'Dossiers de $poolName';
  }

  @override
  String get chooseFolders => 'Choisir des dossiers';

  @override
  String get chooseWhatPlays => 'Choisissez ce qui passe sur cette chaîne';

  @override
  String get endsEarly => 'Se termine plus tôt';

  @override
  String get madeFromThis =>
      'Créé à partir des séries et films de cette chaîne et mis à jour avec la bibliothèque. Modifiez quoi que ce soit et il devient le vôtre.';

  @override
  String get fromTheLineup => 'De la grille';

  @override
  String yesterday(Object t) {
    return 'hier $t';
  }

  @override
  String today(Object t) {
    return 'aujourd\'hui $t';
  }

  @override
  String behind(Object d) {
    return '$d de retard';
  }

  @override
  String hr(Object h) {
    return '$h h';
  }

  @override
  String get underAMinute => 'moins d\'une minute';

  @override
  String get noProgramming => 'Aucun programme';

  @override
  String get today2 => 'AUJOURD\'HUI';

  @override
  String get tuning => 'RÉGLAGE…';

  @override
  String get offAir2 => 'HORS ANTENNE';

  @override
  String get noSignal => 'PAS DE SIGNAL';

  @override
  String left(Object now) {
    return '$now restantes';
  }

  @override
  String get nothingScheduled => 'Rien de prévu';

  @override
  String get back => 'Retour';

  @override
  String get sleep => 'Veille';

  @override
  String get menu => 'Menu';

  @override
  String get nightingaleTvGuide => 'GUIDE NIGHTINGALE TV';

  @override
  String nowPlaying(Object title) {
    return 'En cours : $title';
  }

  @override
  String get mMenu => 'M Menu';

  @override
  String get escBackTo => 'ESC Retour à la TV';

  @override
  String get channelsTabsTime =>
      '▲▼ Chaînes     ▲ Onglets     ◀▶ Heure     OK Regarder     ';

  @override
  String get color => 'Couleur';

  @override
  String get channelsUsingIt =>
      'Les chaînes qui l\'utilisent reviennent à une icône par défaut.';

  @override
  String get deleteThisIcon => 'Supprimer cette icône ?';

  @override
  String get uploadImage => 'Importer une image…';

  @override
  String get pngJpgWebp =>
      'PNG, JPG, WebP, GIF ou SVG. Les grandes images sont réduites automatiquement à 512 px.';

  @override
  String get genericBadgesOnly =>
      'Badges génériques uniquement. Importez un vrai logo de chaîne sous « Mes icônes ».';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'Utiliser ce badge';

  @override
  String get preview => 'Aperçu';

  @override
  String get shape => 'Forme';

  @override
  String get callLettersUp => 'Indicatif (jusqu\'à 5 lettres)';

  @override
  String iconFor(Object name) {
    return 'Icône de $name';
  }

  @override
  String get couldntReadThat =>
      'Impossible de lire cette image. Essayez-en une autre.';

  @override
  String get myIcons => 'Mes icônes';

  @override
  String get showLogos => 'Logos de séries';

  @override
  String get badges => 'Badges';

  @override
  String get builtIn => 'Intégrées';

  @override
  String get couldntMoveThe => 'Impossible de transférer la configuration';

  @override
  String get send => 'Envoyer';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'Vos profils, chaînes et réglages sont sauvegardés maintenant et ouverts dans $counterpartName, qui demande confirmation avant de les restaurer. Rien ne change ici.';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return 'Envoyer votre configuration à $counterpartName ?';
  }

  @override
  String get parentalControls => 'Contrôle parental';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String bringMySetup(Object counterpartName) {
    return 'Récupérer ma configuration depuis $counterpartName';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return 'Transférer ma configuration vers $counterpartName';
  }

  @override
  String get uninstallingEitherOne =>
      'Désinstaller l\'une des deux avant de transférer la configuration que vous voulez garder supprime cette configuration.';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName et $counterpartName sont des applis distinctes, chacune avec ses propres profils, chaînes et réglages.';
  }

  @override
  String get thankYouFor => 'Merci de soutenir Nightingale TV !';

  @override
  String isAlsoOn(Object counterpartName) {
    return '$counterpartName est aussi sur cet appareil';
  }

  @override
  String get aboutThisInstall => 'À PROPOS DE CETTE INSTALLATION';

  @override
  String couldntOpen(Object counterpartName) {
    return 'Impossible d\'ouvrir $counterpartName.';
  }

  @override
  String get nothingIsSet =>
      'Rien n\'est encore configuré ici, il n\'y a donc rien à transférer.';

  @override
  String yourSetupIs(Object counterpartName) {
    return 'Votre configuration est en route vers $counterpartName';
  }

  @override
  String get guide => 'GUIDE';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n sur $keysCount';
  }

  @override
  String get saving => 'Enregistrement…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$_checkedCount sur $total choisis';
  }

  @override
  String get channelOrGroup => 'Nom de chaîne ou de groupe';

  @override
  String get search => 'Rechercher';

  @override
  String get moveOkCheck => '▲▼ Déplacer    OK Cocher    ESC Retour';

  @override
  String chooseChannels(Object name) {
    return 'Choisir des chaînes : $name';
  }

  @override
  String get add => 'Ajouter';

  @override
  String get readingThePlaylist => 'Lecture de la liste…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return 'Actuel : le guide de la liste de lecture, $guideUrl';
  }

  @override
  String get leaveEmptyTo =>
      'Laissez vide pour utiliser le guide indiqué par la liste de lecture';

  @override
  String get xmltvGuideAddress => 'Adresse du guide XMLTV';

  @override
  String get guideOptional => 'GUIDE (FACULTATIF)';

  @override
  String get httpProviderExample =>
      'http://fournisseur.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'Adresse de la liste de lecture';

  @override
  String get playlist => 'LISTE DE LECTURE';

  @override
  String get myIptv => 'Mon IPTV';

  @override
  String get useAnAddress => 'Utiliser plutôt une adresse';

  @override
  String get chooseAFile => 'Choisir un fichier';

  @override
  String get chooseAnotherFile => 'Choisir un autre fichier';

  @override
  String get moveOkSelectEscBack =>
      '▲▼ Déplacer    OK Sélectionner    ESC Retour';

  @override
  String edit(Object name) {
    return 'Modifier $name';
  }

  @override
  String get addAnM3u => 'Ajouter une liste de lecture M3U';

  @override
  String get m3uPlaylists => 'Listes de lecture M3U';

  @override
  String get xmltvGuides => 'Guides XMLTV';

  @override
  String get anIptvPlaylist =>
      'Une liste de lecture IPTV (adresse web ou fichier), avec un guide XMLTV si vous en avez un.';

  @override
  String get theChannelsAnd =>
      'Les chaînes et le guide du tuner de votre serveur (antenne, décodeur ou IPTV).';

  @override
  String readingSChannels(Object server) {
    return 'Lecture des chaînes de $server…';
  }

  @override
  String checkingLiveTv(Object server) {
    return 'Vérification de la TV en direct $server…';
  }

  @override
  String get addALive => 'Ajouter une source TV en direct';

  @override
  String get itsChannelsLeave =>
      'Ses chaînes quittent le guide, leurs groupes et les favoris.';

  @override
  String get renameSource => 'Renommer la source';

  @override
  String get edit2 => 'Modifier';

  @override
  String get refreshNow => 'Actualiser maintenant';

  @override
  String get chooseChannels2 => 'Choisir des chaînes';

  @override
  String get playlistFile => 'Fichier de liste de lecture';

  @override
  String get notRefreshedYet => 'Pas encore actualisé';

  @override
  String refreshed(Object lastRefresh) {
    return 'Actualisé $lastRefresh';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return 'Échec de la dernière actualisation : $lastError';
  }

  @override
  String get refreshing => 'Actualisation…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · Chaînes : $keyCount sur $channelsCount';
  }

  @override
  String get noSourcesYet => 'Aucune source pour l\'instant.';

  @override
  String get addSource => 'Ajouter une source';

  @override
  String get realBroadcastsAnd =>
      'De vraies émissions et l\'IPTV dans votre guide : la TV en direct de votre serveur, ou une liste M3U avec un guide XMLTV. Leurs chaînes rejoignent la grille après les vôtres.';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return 'Aucune diffusion. $runningCount flux utilisés sur $streamLimit.';
  }

  @override
  String get savePort => 'Enregistrer le port';

  @override
  String get port => 'Port';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'Tuner';

  @override
  String get enterAPort => 'Saisissez un numéro de port.';

  @override
  String pinFor(Object name) {
    return 'Code PIN de $name';
  }

  @override
  String get letPlexFind => 'Laisser Plex le trouver automatiquement';

  @override
  String get discovery => 'DÉCOUVERTE';

  @override
  String get encoder => 'ENCODEUR';

  @override
  String nowAtOnce(Object streamLimit) {
    return 'Actuel : $streamLimit à la fois. Chaque chaîne regardée ailleurs compte pour un flux.';
  }

  @override
  String get streamsAtOnce => 'FLUX SIMULTANÉS';

  @override
  String get quality => 'QUALITÉ';

  @override
  String get lineups => 'GRILLES';

  @override
  String get liveTvExport2 => 'Export TV en direct';

  @override
  String get automaticDiscoveryIsnt =>
      'La découverte automatique n\'est pas disponible sur ce PC. Ajoutez le tuner dans Plex ou Jellyfin par son adresse.';

  @override
  String get anyoneOnYour =>
      'Toute personne sur votre réseau domestique peut regarder cette grille.';

  @override
  String get watchYourChannels =>
      'Regardez vos chaînes dans Plex, Jellyfin ou toute appli IPTV sur votre réseau domestique. Nightingale TV doit rester ouvert pour cela.';

  @override
  String get offline => 'Hors ligne';

  @override
  String get online => 'En ligne';

  @override
  String get added => 'Ajouté';

  @override
  String get chooseAServer => 'Choisir un serveur';

  @override
  String get whosSigningIn => 'Qui se connecte ?';

  @override
  String get openPlexTv => 'Ouvrir plex.tv/link';

  @override
  String get waitingForThe => 'En attente de l\'association du code…';

  @override
  String get goToPlex =>
      'Allez sur plex.tv/link sur votre téléphone ou ordinateur et saisissez ce code.';

  @override
  String get signInWith => 'Se connecter avec Plex';

  @override
  String get waitingForApproval => 'En attente d\'approbation…';

  @override
  String onYourPhone(Object label) {
    return 'Sur votre téléphone ou ordinateur, ouvrez $label → votre profil → Quick Connect et saisissez ce code :';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'Se connecter';

  @override
  String get password => 'Mot de passe';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String signInTo2(Object name) {
    return 'Se connecter à $name';
  }

  @override
  String get differentServer => 'Autre serveur';

  @override
  String get signInWithPassword => 'Se connecter avec un mot de passe';

  @override
  String get quickConnectUse => 'Quick Connect (avec votre téléphone)';

  @override
  String get connect => 'Connexion';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String get connectToYour => 'Connexion à votre serveur';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV transforme votre bibliothèque Jellyfin, Emby ou Plex en chaînes permanentes avec un guide des programmes. Zappez et regardez ce qui passe.';

  @override
  String get yourLibraryOn => 'Votre bibliothèque.\nÀ l\'antenne, 24 h/24.';

  @override
  String get welcomeToNightingale => 'Bienvenue sur Nightingale TV';

  @override
  String signInFor(Object name) {
    return 'Connexion pour $name';
  }

  @override
  String signInToAgain(Object name) {
    return 'Se reconnecter à $name';
  }

  @override
  String get addAServer => 'Ajouter un serveur';

  @override
  String foundNewPrograms(Object list) {
    return 'Trouvé : $list. Les nouveaux programmes passent sur leurs chaînes juste après ce qui est diffusé.';
  }

  @override
  String get libraryRefreshed => 'Bibliothèque actualisée';

  @override
  String get nothingNew => 'Rien de nouveau';

  @override
  String get yourChannelsAre => 'Vos chaînes sont à jour.';

  @override
  String get refreshFailed => 'Échec de l\'actualisation';

  @override
  String get moveOkSelectEscBackTo =>
      '▲▼ Déplacer    OK Sélectionner    ESC Retour à la TV';

  @override
  String get noPoolsYet => 'aucun groupe pour l\'instant';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return 'Mis à jour $fetchedAt à $fetchedAt2';
  }

  @override
  String get libraryLabel => 'BIBLIOTHÈQUE';

  @override
  String get account => 'COMPTE';

  @override
  String get watching => 'REGARDE';

  @override
  String get exitNightingaleTv => 'Quitter Nightingale TV';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get yourChannelLineup =>
      'Votre grille de chaînes est effacée. Les icônes personnalisées sont conservées.';

  @override
  String get signOut2 => 'Se déconnecter ?';

  @override
  String get fullScreenOn => 'Plein écran oui/non (F11)';

  @override
  String get nothingWasReset => 'Rien n\'a été réinitialisé';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get rebuildsTheDefault =>
      'Recrée les chaînes par défaut à partir de votre bibliothèque. Les noms, icônes et numéros modifiés sont réinitialisés. Les chaînes ajoutées sont conservées. Une sauvegarde est d\'abord enregistrée pour pouvoir les récupérer dans Sauvegarde et restauration.';

  @override
  String get resetChannelLineup => 'Réinitialiser la grille ?';

  @override
  String get resetChannelLineup2 => 'Réinitialiser la grille';

  @override
  String get refreshLibrary => 'Actualiser la bibliothèque';

  @override
  String get refreshingLibrary => 'Actualisation de la bibliothèque…';

  @override
  String get servers => 'Serveurs';

  @override
  String get phoneRemote => 'Télécommande';

  @override
  String get profiles => 'Profils';

  @override
  String get retroLook => 'Style rétro';

  @override
  String get playback => 'Lecture';

  @override
  String get switchProfile => 'Changer de profil';

  @override
  String get sleepTimer => 'Minuteur de veille';

  @override
  String get backToTv => 'Retour à la TV';

  @override
  String get removeAll => 'Tout retirer';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return 'associé $paired · dernière utilisation $lastUsed';
  }

  @override
  String get noPhonesPaired => 'Aucun téléphone associé pour l\'instant.';

  @override
  String get pairedPhones => 'TÉLÉPHONES ASSOCIÉS';

  @override
  String get blockedByThis => 'Bloqué par le pare-feu de cet ordinateur';

  @override
  String get someWiFi =>
      'Certains réseaux Wi-Fi isolent les appareils (isolation AP ou client). Si le téléphone ne se connecte toujours pas, désactivez ce réglage pour votre Wi-Fi.';

  @override
  String get thePhoneHas =>
      'Le téléphone doit être sur le même Wi-Fi que cette TV, pas sur un réseau invité ou des données mobiles.';

  @override
  String get ifThePhone =>
      'Si le téléphone ne se connecte pas, le pare-feu de cet ordinateur le bloque peut-être. Ouvrez un terminal sur cet ordinateur et exécutez :';

  @override
  String get checkAgain => 'Vérifier de nouveau';

  @override
  String get thenChooseCheck => 'Puis choisissez Vérifier de nouveau.';

  @override
  String get thisComputersFirewall =>
      'Le pare-feu de cet ordinateur empêche les téléphones d\'atteindre la télécommande. Pour les autoriser, ouvrez un terminal sur cet ordinateur et exécutez :';

  @override
  String get notConfirmedYet =>
      'Pas encore confirmé · aucun téléphone connecté';

  @override
  String get working => 'Fonctionne';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return 'Fonctionne · dernière utilisation par $name, $lastUsed';
  }

  @override
  String get theRemoteIs => 'La télécommande est désactivée.';

  @override
  String get orScanThe =>
      'ou scannez le code avec l\'appareil photo du téléphone.';

  @override
  String get andEnter => 'et saisissez  ';

  @override
  String get onYourPhoneOpen => 'SUR VOTRE TÉLÉPHONE, OUVREZ';

  @override
  String get useYourPhoneAs =>
      'Utilisez votre téléphone comme télécommande : ouvrez-y une page web pour changer de chaîne, afficher le guide ou toucher une chaîne pour la regarder. Rien à installer.';

  @override
  String get everyPairedPhone =>
      'Chaque téléphone associé cesse de fonctionner comme télécommande jusqu\'à ce qu\'il scanne de nouveau le code de cet écran.';

  @override
  String get removeAllPhones => 'Retirer tous les téléphones ?';

  @override
  String get thoseDidntMatch => 'Ils ne correspondent pas. Réessayez.';

  @override
  String get enterTheSame => 'Saisissez de nouveau les 4 mêmes chiffres.';

  @override
  String get choose4Digits => 'Choisissez 4 chiffres.';

  @override
  String get thatPinIsnt => 'Ce code PIN est incorrect. Réessayez.';

  @override
  String get clock => 'HORLOGE';

  @override
  String get captions2 => 'SOUS-TITRES';

  @override
  String get audio => 'AUDIO';

  @override
  String get maximumStreamingBitrate => 'DÉBIT DE DIFFUSION MAXIMAL';

  @override
  String get converting => 'CONVERSION';

  @override
  String get afterThisLong =>
      'Après ce délai sans appui sur une touche, Nightingale TV demande si quelqu\'un regarde. Sans réponse en une minute, il se met en veille : la lecture s\'arrête et votre serveur cesse la diffusion. Pas pendant un minuteur de veille.';

  @override
  String get askIfIm => 'Demander si je regarde encore';

  @override
  String get liveTvStill =>
      'La TV en direct apparaît toujours sur le tableau de bord.';

  @override
  String get offWhatYou =>
      'Désactivé : ce que vous regardez ici ne change jamais les compteurs de lecture, marques de visionnage ou points de reprise sur votre serveur, et n\'apparaît pas sur son tableau de bord.';

  @override
  String get pauseSkipAnd =>
      'Mettez en pause, sautez et relancez ce qui passe. Désactivé : chaque chaîne suit l\'horaire, comme la télévision en continu.';

  @override
  String get pauseAndRewind => 'Pause et retour en arrière';

  @override
  String get showsTheTime => 'Affiche l\'heure dans le coin de l\'image.';

  @override
  String get onScreenClock => 'Horloge à l\'écran';

  @override
  String get showACountdown =>
      'Affiche un compte à rebours avant le début des publicités et avant le retour du programme.';

  @override
  String get breakNotices => 'Annonces de pause';

  @override
  String get theSizeOf =>
      'La taille des sous-titres sur tous les programmes et chaînes.';

  @override
  String get whileItsOn =>
      'Lorsqu\'il est activé, le son surround (Dolby, DTS) est décodé par cet appareil au lieu d\'être transmis à un récepteur.';

  @override
  String get evensOutThe =>
      'Égalise le volume pendant que vous regardez : les publicités et programmes forts sont baissés, les faibles montés, sans avoir à prendre la télécommande.';

  @override
  String get volumeLeveling => 'Égalisation du volume';

  @override
  String get pickALower =>
      'Choisissez un débit plus bas si les émissions se bloquent ou saccadent en Wi-Fi ou à distance. Original n\'est jamais converti à cause du débit.';

  @override
  String get connectedThroughPlex =>
      'Connecté via Plex Relay : la qualité est limitée.';

  @override
  String get offNightingaleTv =>
      'Désactivé : Nightingale TV lit toujours vos fichiers originaux en pleine qualité et votre serveur n\'a aucun travail supplémentaire. Activé : votre serveur convertit une série ou un film uniquement s\'il dépasse le débit maximal ou si le fichier original ne se lit pas. La conversion utilise le processeur ou la carte graphique de votre serveur. Les publicités lisent toujours les fichiers originaux.';

  @override
  String get transcodeOnlyIf =>
      'Convertir seulement si nécessaire (expérimental)';

  @override
  String get longerVideosAd =>
      'Les vidéos plus longues (compilations de publicités) sont découpées en publicités, aux chapitres ou lorsque l\'image devient noire et silencieuse.';

  @override
  String get videosOf5 =>
      'Les vidéos de 5 secondes à 3 minutes forment chacune un clip.';

  @override
  String get commercialsFillBreaks =>
      'Les publicités remplissent les pauses. Réglez le type sur Jingles pour les habillages de chaîne et les clips « Nous revenons tout de suite ».';

  @override
  String get bumpersTakeAt =>
      'Les jingles occupent au plus la moitié d\'une pause, sauf en pré-roll. Un jingle trop long est ignoré.';

  @override
  String stillToSplit(Object unsplit) {
    return '$unsplit à découper';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount longues vidéos découpées en clips',
      one: '$reelsCount longue vidéo découpée en clips',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'Supprimer le groupe';

  @override
  String get addFolders => 'Ajouter des dossiers…';

  @override
  String get libraryLabel2 => 'Bibliothèque';

  @override
  String get noFoldersYet => 'Aucun dossier pour l\'instant.';

  @override
  String get folders2 => 'DOSSIERS';

  @override
  String get type => 'TYPE';

  @override
  String get poolName => 'Nom du groupe';

  @override
  String get commercialPool => 'Groupe de publicités';

  @override
  String get itsVideosGo =>
      'Ses vidéos retournent sur vos chaînes habituelles. Les pauses qui y puisaient utilisent désormais tous les groupes.';

  @override
  String get now => 'Maintenant';

  @override
  String get watch => 'Regarder';

  @override
  String get tuning2 => 'Réglage…';

  @override
  String get fullScreen => 'Plein écran';

  @override
  String get noChannels => 'Aucune chaîne';

  @override
  String get theirChannelsProgramming =>
      'Ses chaînes, blocs de programmes et réglages sont supprimés, et cette TV est déconnectée de son serveur.';

  @override
  String delete3(Object name) {
    return 'Supprimer $name ?';
  }

  @override
  String get giveTheProfile => 'Donnez un nom au profil.';

  @override
  String get deleteProfile => 'Supprimer le profil';

  @override
  String get removePin => 'Retirer le code PIN';

  @override
  String get setAPin => 'Définir un code PIN';

  @override
  String get changePin => 'Changer le code PIN';

  @override
  String get noPinAnyone =>
      'Pas de code PIN. Tout le monde peut ouvrir ce profil.';

  @override
  String get lockedThePin =>
      'Verrouillé. Le code PIN est nécessaire pour ouvrir ce profil.';

  @override
  String get pin => 'Code PIN';

  @override
  String get showsAndMoviesWith =>
      'Les séries et films sans classification sont exclus.';

  @override
  String get allowedToWatch => 'PEUT REGARDER';

  @override
  String get kid => 'Enfant';

  @override
  String get grownUp => 'Adulte';

  @override
  String get whoItsFor => 'POUR QUI';

  @override
  String get color2 => 'COULEUR';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get newProfile => 'Nouveau profil';

  @override
  String get watchingNow => 'Regarde maintenant';

  @override
  String get noPin => 'Pas de code PIN';

  @override
  String get pinLocked => 'Verrouillé par code PIN';

  @override
  String kid2(Object label, Object description) {
    return 'Enfant · $label ($description)';
  }

  @override
  String get addProfile => 'Ajouter un profil';

  @override
  String get everyoneGetsTheir =>
      'Chacun a sa propre connexion au serveur, ses chaînes et ses blocs de programmes. Les profils enfants ne voient que les séries et films adaptés à leur âge.';

  @override
  String enterSPin(Object name) {
    return 'Saisissez le code PIN de $name';
  }

  @override
  String get whosWatching => 'Qui regarde ?';

  @override
  String get moveOkChoose2 => '◀▶ Déplacer    OK Choisir';

  @override
  String get enterAGrownUps => 'Saisissez le code PIN d\'un adulte.';

  @override
  String get grownUpsOnly => 'Réservé aux adultes';

  @override
  String get yourChannelYour => 'Votre chaîne, votre style';

  @override
  String get testPattern => 'Mire de test';

  @override
  String get upNext8 => 'À SUIVRE  ·  20:00';

  @override
  String get thisDevice => 'CET APPAREIL';

  @override
  String get glow => 'LUEUR';

  @override
  String get curvature => 'COURBURE';

  @override
  String get vignette => 'VIGNETTE';

  @override
  String get mask => 'MASQUE';

  @override
  String get lines => 'LIGNES';

  @override
  String get scanlines => 'LIGNES DE BALAYAGE';

  @override
  String get customCrtStyle => 'STYLE CRT PERSONNALISÉ';

  @override
  String accent(Object label) {
    return 'ACCENT ($label)';
  }

  @override
  String get overlayTheme => 'THÈME D\'INCRUSTATION';

  @override
  String get crtEffect => 'EFFET CRT';

  @override
  String get surround => 'ENTOURAGE';

  @override
  String get pictureShape => 'FORME DE L\'IMAGE';

  @override
  String get surroundImage => 'Image d\'entourage';

  @override
  String get notAvailableOn => 'Non disponible sur cet appareil';

  @override
  String get offTurnsOff =>
      'Désactivé coupe tous les effets CRT sur cet appareil uniquement. La forme de l\'image, l\'entourage et les thèmes d\'incrustation restent inchangés.';

  @override
  String get effectsOnThis => 'Effets sur cet appareil';

  @override
  String get retroLook2 => 'STYLE RÉTRO';

  @override
  String get theseSettingsApply =>
      'Ces réglages s\'appliquent aux écrans où l\'appli est ouverte. Ils ne s\'appliquent pas à l\'export TV en direct.';

  @override
  String get sameAsThe => 'Comme le profil';

  @override
  String get streamsFromThis =>
      'Les flux de ce serveur restent en dessous. La limite du profil (Lecture) s\'applique toujours : la plus basse l\'emporte.';

  @override
  String qualityLimit(Object name) {
    return 'Limite de qualité · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbit/s';
  }

  @override
  String get itsProgramsLeave =>
      'Ses programmes quittent vos chaînes, qui gardent leurs numéros. Les sources et dossiers de publicités qu\'il contient sont indiqués comme introuvables jusqu\'à ce que vous les changiez.';

  @override
  String remove3(Object name) {
    return 'Retirer $name ?';
  }

  @override
  String get signingOutOf =>
      'Déconnecter ce profil change son serveur principal.';

  @override
  String signedInAs(Object user) {
    return 'Connecté en tant que $user';
  }

  @override
  String get mainServer => 'Serveur principal';

  @override
  String get qualityLimit2 => 'Limite de qualité';

  @override
  String get moveDown => 'Descendre';

  @override
  String get moveUp => 'Monter';

  @override
  String get signInAgain => 'Se reconnecter';

  @override
  String get programsFromEvery =>
      'Les programmes de tous les serveurs rejoignent une même grille. Un titre présent sur plusieurs serveurs est lu depuis le premier de cette liste qui répond (Lire depuis) ; s\'il ne répond plus, le suivant prend le relais.';

  @override
  String get sleepingPressAny =>
      'En veille · Appuyez sur une touche pour regarder';

  @override
  String goingToSleep(Object seconds) {
    return 'Mise en veille dans $seconds';
  }

  @override
  String get goingToSleep2 => 'Mise en veille';

  @override
  String goingToSleepIn(Object hint) {
    return 'Mise en veille dans 1 minute. $hint';
  }

  @override
  String get pressAnyButton =>
      'Appuyez sur une touche pour continuer à regarder';

  @override
  String goingToSleepIn0(Object padLeft) {
    return 'Mise en veille dans 0:$padLeft';
  }

  @override
  String get keepWatching => 'Continuer à regarder';

  @override
  String get areYouStill => 'Regardez-vous toujours ?';

  @override
  String sleepTimerMin(Object left) {
    return 'Minuteur de veille · $left min restantes';
  }

  @override
  String get whatsOnNow => 'Ce qui passe n\'a pas d\'heure de fin fixe.';

  @override
  String endOfThis(Object programEnd) {
    return 'Fin de ce programme · $programEnd';
  }

  @override
  String get endOfThisProgram => 'Fin de ce programme';

  @override
  String get moveOkToggle => '▲▼◀▶ Déplacer    OK Basculer    ESC Annuler';

  @override
  String get usedWhenNo =>
      'Utilisé quand aucune série n\'est choisie. Restreint aussi les films.';

  @override
  String get genres2 => 'GENRES';

  @override
  String get includeMovies => 'Inclure les films';

  @override
  String get add2 => 'Ajouter…';

  @override
  String get notFoundOn => 'Introuvable sur le serveur';

  @override
  String get collectionsFolders => 'COLLECTIONS ET DOSSIERS';

  @override
  String get playOrder => 'ORDRE DE LECTURE';

  @override
  String get clear => 'Effacer';

  @override
  String get shows2 => 'SÉRIES';

  @override
  String get pickSomethingTo => 'Choisissez quelque chose à diffuser.';

  @override
  String everyMovie(Object genreText) {
    return 'chaque film $genreText';
  }

  @override
  String get everyMovie2 => 'chaque film';

  @override
  String everyShow(Object genreText) {
    return 'chaque série $genreText';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount ou $last';
  }

  @override
  String get settingUpYour => 'Configuration de vos chaînes';

  @override
  String get couldntLoadYour => 'Impossible de charger votre bibliothèque';

  @override
  String upNext(Object title) {
    return 'À suivre : $title';
  }

  @override
  String backTo(Object title) {
    return 'Retour à $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return 'Reprise des programmes dans $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabel dans $left';
  }

  @override
  String startingWith(Object title) {
    return 'Commence par $title';
  }

  @override
  String upNext2(Object start) {
    return 'À SUIVRE  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return 'Ensuite $start : $title';
  }

  @override
  String backOn(Object backOnAir) {
    return 'De retour $backOnAir';
  }

  @override
  String get offTheAir2 => 'Hors antenne';

  @override
  String get commercialBreak => 'Pause publicitaire';

  @override
  String tryingAgainAt(Object end) {
    return 'Nouvel essai à $end';
  }

  @override
  String get exitFullScreen => 'Quitter le plein écran';

  @override
  String get guide2 => 'Guide';

  @override
  String thereIsNo(Object number) {
    return 'La chaîne $number n\'existe pas';
  }

  @override
  String get liveChannelsCant =>
      'Les chaînes en direct ne peuvent pas être mises en pause';

  @override
  String get curvatureAndGlow =>
      'Courbure et lueur désactivées : cet appareil ne suit pas';

  @override
  String get pressBackAgain => 'Appuyez de nouveau sur Retour pour quitter';

  @override
  String backAt(Object backAt) {
    return 'Retour à $backAt';
  }

  @override
  String get live => 'DIRECT';

  @override
  String get newLabel => 'NOUVEAU';

  @override
  String nowPlayingOn(Object name) {
    return 'EN COURS SUR $name';
  }

  @override
  String ch(Object padLeft) {
    return 'CH $padLeft';
  }

  @override
  String get paused => 'EN PAUSE';

  @override
  String get seekBar => 'Barre de lecture';

  @override
  String get live2 => 'Direct';

  @override
  String get forward30 => 'Avancer 30';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Lecture';

  @override
  String get back10 => 'Reculer 10';

  @override
  String get restart => 'Reprendre au début';

  @override
  String somethingWentWrong2(Object status) {
    return 'Une erreur s\'est produite ($status).';
  }

  @override
  String get thatIsTooBig => 'C\'est trop volumineux.';

  @override
  String get notFound => 'Introuvable.';

  @override
  String get youCantDo => 'Vous ne pouvez pas faire cela.';

  @override
  String get cantReachThe =>
      'Impossible de joindre le serveur. Vérifiez qu\'il fonctionne.';

  @override
  String signOut3(Object userName) {
    return 'Déconnecter $userName';
  }

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get users => 'Utilisateurs';

  @override
  String get backups2 => 'Sauvegardes';

  @override
  String get serverAndSign => 'Serveur et connexion';

  @override
  String get channels5 => 'Chaînes';

  @override
  String get thatProfileIsntYours =>
      'Ce profil n\'est pas le vôtre ou il n\'existe plus.';

  @override
  String get download => 'Télécharger';

  @override
  String get itReplacesThe =>
      'Cela remplace les profils, chaînes et réglages ici.';

  @override
  String get restoreThisBackup => 'Restaurer cette sauvegarde ?';

  @override
  String get backupActions => 'Actions de sauvegarde';

  @override
  String channels6(Object profiles, Object channels, Object device) {
    return '$profiles · Chaînes : $channels · $device';
  }

  @override
  String get noneYetOne =>
      'Aucune pour l\'instant. Une est enregistrée chaque jour où le foyer change.';

  @override
  String get savedOnThe => 'Enregistrées sur le serveur';

  @override
  String get restoring => 'Restauration…';

  @override
  String get restoreFromAFile => 'Restaurer depuis un fichier…';

  @override
  String get downloadABackup => 'Télécharger une sauvegarde maintenant';

  @override
  String get aBackupHoldsThe =>
      'Une sauvegarde contient les profils, chaînes, blocs, logos, réglages d\'export et comptes utilisateurs (jamais les mots de passe ni les jetons de connexion).';

  @override
  String get restoredTheBackup2 => 'Sauvegarde restaurée.';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return 'Du $whenValue ($device) : $profiles. Cela remplace les profils, chaînes et réglages ici.';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return 'Prochaine diffusion : $start $end';
  }

  @override
  String programsInIts(Object total) {
    return 'Programmes dans sa liste : $total';
  }

  @override
  String get workingOutWhat => 'Calcul du contenu…';

  @override
  String get later => 'Plus tard';

  @override
  String get earlier => 'Plus tôt';

  @override
  String get eachAiringPlays =>
      'Chaque diffusion joue dans l\'ordre les épisodes suivants de chaque place, puis recommence s\'il reste du temps.';

  @override
  String get aLineupOf => 'Une grille de séries';

  @override
  String get whatItPlays2 => 'Ce qui est diffusé';

  @override
  String get onlyPartOf => 'Seulement une partie de l\'année';

  @override
  String get runsPastMidnight => 'Continue après minuit le jour suivant.';

  @override
  String get whenLabel => 'Quand';

  @override
  String get aNewChannelFor => 'Une nouvelle chaîne pour ce bloc';

  @override
  String get channel3 => 'Chaîne';

  @override
  String get blocks => 'Blocs';

  @override
  String get newBlock => 'Nouveau bloc';

  @override
  String get programmingBlock => 'Bloc de programmes';

  @override
  String get aBlockTakes =>
      'Un bloc prend le contrôle d\'une chaîne à heures fixes : « Dessins animés du samedi matin », le samedi de 7 h à midi.';

  @override
  String get overlayTheme2 => 'Thème d\'incrustation';

  @override
  String get crtEffect2 => 'Effet CRT';

  @override
  String get chooseSurroundImage => 'Choisir une image d\'entourage…';

  @override
  String get surround2 => 'Entourage';

  @override
  String get pictureShape2 => 'Forme de l\'image';

  @override
  String get chooseOfflineImage => 'Choisir une image hors antenne…';

  @override
  String get fillerPool2 => 'Groupe de remplissage';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes minutes';
  }

  @override
  String get slotLength2 => 'Durée du créneau';

  @override
  String get everyProgramStarts =>
      'Chaque programme démarre à l\'heure. Le remplissage complète le reste de chaque créneau.';

  @override
  String get itLeavesThe => 'Elle quitte la grille.';

  @override
  String get itsProgrammingBlocks =>
      'Ses blocs de programmes sont également retirés.';

  @override
  String get removeThisChannel => 'Retirer cette chaîne';

  @override
  String get channelLogo2 => 'Logo de la chaîne';

  @override
  String get editCustomBreaks => 'Modifier les pauses personnalisées…';

  @override
  String get musicChannelsOnlyShuffle =>
      'Les chaînes musicales sont uniquement en aléatoire, jamais deux fois de suite le même artiste.';

  @override
  String get playOrder2 => 'Ordre de lecture';

  @override
  String get saveWhatIt => 'Enregistrer le contenu';

  @override
  String get canBeA =>
      'Peut être la chaîne d\'origine d\'une série pour ses derniers épisodes.';

  @override
  String get hiddenFromThe => 'Masquée du guide';

  @override
  String get chooseIcon => 'Choisir une icône…';

  @override
  String get icon => 'Icône';

  @override
  String get saveNameAnd => 'Enregistrer le nom et le numéro';

  @override
  String get aChannelAlready =>
      'Une chaîne déjà sur ce numéro échange sa place avec celle-ci.';

  @override
  String get number3 => 'Numéro';

  @override
  String get nameAndNumber => 'Nom et numéro';

  @override
  String get decadesNoneAny => 'Décennies (aucune : toutes)';

  @override
  String get genresNoneAny => 'Genres (aucun : tous)';

  @override
  String musicVideos(Object musicVideos) {
    return 'Clips ($musicVideos)';
  }

  @override
  String songs(Object songs) {
    return 'Morceaux ($songs)';
  }

  @override
  String get newMusicChannel => 'Nouvelle chaîne musicale';

  @override
  String get aNightlySlot =>
      'Un créneau nocturne pour les derniers épisodes des séries, sur la chaîne d\'origine de chacune.';

  @override
  String get mainSettings => 'Réglages principaux';

  @override
  String get glow2 => 'Lueur';

  @override
  String get curvature2 => 'Courbure';

  @override
  String get vignette2 => 'Vignette';

  @override
  String get mask2 => 'Masque';

  @override
  String get lines2 => 'Lignes';

  @override
  String get scanlines2 => 'Lignes de balayage';

  @override
  String get customCrtStyle2 => 'Style CRT personnalisé';

  @override
  String accent2(Object label) {
    return 'Accent ($label)';
  }

  @override
  String get hidden => 'Masquée';

  @override
  String get blockChannel2 => 'Chaîne de blocs';

  @override
  String live3(Object source) {
    return 'Direct · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return 'Chaînes : $shownCount sur $channelsCount';
  }

  @override
  String get searchChannels => 'Rechercher des chaînes';

  @override
  String get resetLineup => 'Réinitialiser la grille';

  @override
  String get everyChannelEdit =>
      'Toutes les modifications de chaînes sont annulées et la grille par défaut est recréée. Les chaînes ajoutées sont conservées. Une sauvegarde est d\'abord enregistrée.';

  @override
  String get musicChannel => 'Chaîne musicale';

  @override
  String get newBlockChannel => 'Nouvelle chaîne de blocs';

  @override
  String get channelsOwnPlans => 'Plans propres aux chaînes';

  @override
  String get setTypeBumpers => 'Définir le type : Jingles';

  @override
  String get setTypeCommercials => 'Définir le type : Publicités';

  @override
  String get chooseFolders2 => 'Choisir des dossiers…';

  @override
  String get plansThatDrew =>
      'Les plans qui y puisaient utilisent désormais tous les groupes, et ses vidéos retournent sur les chaînes.';

  @override
  String get renamePool => 'Renommer le groupe';

  @override
  String get poolActions => 'Actions du groupe';

  @override
  String get aPoolIs =>
      'Un groupe est un ensemble de dossiers de bibliothèque dont les vidéos remplissent les pauses au lieu d\'être diffusées. Son type indique si ses clips passent comme publicités ou comme jingles, qui ouvrent et ferment les pauses.';

  @override
  String get pools2 => 'Groupes';

  @override
  String get breaks => 'Pauses';

  @override
  String clipsInAll(Object clips) {
    return 'Clips dans tous les groupes de publicités : $clips';
  }

  @override
  String get tunerAddress => 'Adresse du tuner';

  @override
  String get changePort => 'Changer le port';

  @override
  String get exportThisProfile => 'Exporter ce profil';

  @override
  String get letsPlexAnd =>
      'Permet à Plex et à d\'autres de trouver les tuners sur le réseau.';

  @override
  String get discovery2 => 'Découverte';

  @override
  String get encoder2 => 'Encodeur';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return 'Automatique : $streamLimitInUse sur cette machine.';
  }

  @override
  String get streamsAtOnce2 => 'Flux simultanés';

  @override
  String get quality2 => 'Qualité';

  @override
  String get settings => 'Réglages';

  @override
  String get eachExportedProfile =>
      'Chaque profil exporté est un tuner pour Plex, Jellyfin ou Emby. Ajoutez-le dans leurs réglages DVR par son adresse.';

  @override
  String get channelsInThis => 'Chaînes de ce groupe';

  @override
  String get chooseChannels3 => 'Choisir des chaînes…';

  @override
  String channels7(Object channelIds) {
    return 'Chaînes : $channelIds';
  }

  @override
  String get itsChannelsStay => 'Ses chaînes restent dans la grille.';

  @override
  String get renameGroup => 'Renommer le groupe';

  @override
  String get groupActions => 'Actions du groupe';

  @override
  String get yourGroup => 'Votre groupe';

  @override
  String get theOrderOf =>
      'L\'ordre des onglets dans le guide et ceux qui sont affichés.';

  @override
  String get guideTabs => 'Onglets du guide';

  @override
  String get make => 'Créer';

  @override
  String get breaksBetweenPrograms => 'Pauses entre les programmes';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '$mids pauses incluses',
      one: '$mids pause incluse',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return 'Morceaux : $songs';
  }

  @override
  String get newEpisode => 'Nouvel épisode';

  @override
  String get noChannelsYet2 => 'Aucune chaîne pour l\'instant.';

  @override
  String get noGuide => 'Pas de guide';

  @override
  String get noneShown => 'Aucune affichée';

  @override
  String get allShown => 'Toutes affichées';

  @override
  String channels8(Object name) {
    return '$name : chaînes';
  }

  @override
  String get orChooseA => 'Ou choisir un fichier de guide…';

  @override
  String get emptyThePlaylists =>
      'Vide : le guide de la liste de lecture, si elle en indique un.';

  @override
  String get guideAddressXmltv => 'Adresse du guide (XMLTV, facultatif)';

  @override
  String get orChooseAPlaylist => 'Ou choisir un fichier de liste de lecture…';

  @override
  String get leaveEmptyToKeep =>
      'Laissez vide pour conserver le fichier de liste de lecture.';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'Fichiers';

  @override
  String get itsChannelsJoin =>
      'Ses chaînes s\'ajoutent tant que ce profil est connecté à ce serveur.';

  @override
  String guide3(Object guideFile) {
    return 'Guide : $guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'Fichier de liste de lecture : $playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return 'Actualisé $last $context';
  }

  @override
  String get itsChannelsLeaveThe =>
      'Ses chaînes quittent la grille, les groupes et les favoris.';

  @override
  String read(Object fetched, Object context) {
    return 'Lu $fetched $context.';
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
    return 'Séries : $series · Épisodes : $episodes · Films : $movies · Morceaux : $songs · Clips : $musicVideos · Vidéos publicitaires : $commercials';
  }

  @override
  String fromAs(Object server, Object user) {
    return 'Depuis $server en tant que $user.';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name : bibliothèque';
  }

  @override
  String get removeThePin => 'Retirer le code PIN';

  @override
  String get pinOptional => 'Code PIN (facultatif)';

  @override
  String get newPinLeave => 'Nouveau code PIN (laissez vide pour le conserver)';

  @override
  String colour(Object i) {
    return 'Couleur $i';
  }

  @override
  String get colour2 => 'Couleur';

  @override
  String get itsChannelsBlocks =>
      'Ses chaînes, blocs et réglages sont supprimés. Une sauvegarde est d\'abord enregistrée.';

  @override
  String get exported => 'Exporté';

  @override
  String kid3(Object label) {
    return 'Enfant · $label';
  }

  @override
  String get noProfilesAre =>
      'Aucun profil ne vous est encore attribué. Demandez à un administrateur.';

  @override
  String signIn2(Object name) {
    return 'Connecter $name';
  }

  @override
  String get theLibraryIs =>
      'La bibliothèque est relue. Les programmes du serveur rejoindront les chaînes une fois terminé.';

  @override
  String get itsLibraryIs =>
      'Sa bibliothèque est lue et ses chaînes créées. Cela prend une à deux minutes.';

  @override
  String isSignedIn(Object name) {
    return '$name est connecté.';
  }

  @override
  String get couldntDoThat => 'Cela n\'a pas fonctionné. Réessayez.';

  @override
  String get itsChannelsStayIt =>
      'Ses chaînes restent. Une connexion est nécessaire pour la lecture.';

  @override
  String signOut4(Object name) {
    return 'Déconnecter $name ?';
  }

  @override
  String get signingIn => 'Connexion…';

  @override
  String wasSignedIn(Object server, Object user) {
    return 'Était connecté à $server en tant que $user. Reconnectez-vous.';
  }

  @override
  String signedInTo(Object server, Object user) {
    return 'Connecté à $server en tant que $user.';
  }

  @override
  String get profileName => 'Nom du profil';

  @override
  String get nameAProfile =>
      'Nommez un profil, connectez-le à votre serveur multimédia, et ses chaînes sont créées et exportées.';

  @override
  String get chooseABackup => 'Choisir un fichier de sauvegarde…';

  @override
  String get moveAHousehold =>
      'Transférez ici un foyer depuis une TV ou un autre serveur : ses profils, chaînes, blocs, logos et réglages d\'export.';

  @override
  String get restoreABackup => 'Restaurer une sauvegarde';

  @override
  String get theServerIs => 'Le serveur démarre…';

  @override
  String get itsProgramsLeaveThe =>
      'Ses programmes quittent les chaînes, qui gardent leurs numéros. Les sources et dossiers de publicités qu\'il contient sont indiqués comme introuvables jusqu\'à ce que vous les changiez.';

  @override
  String addAServerTo(Object name) {
    return 'Ajouter un serveur à $name';
  }

  @override
  String servers2(Object name) {
    return '$name : serveurs';
  }

  @override
  String get makeAccountAnd => 'Créer le compte et se connecter';

  @override
  String get setPasswordAnd => 'Définir le mot de passe et se connecter';

  @override
  String get passwordAgain => 'Confirmer le mot de passe';

  @override
  String get atLeast8 => 'Au moins 8 caractères.';

  @override
  String get userName => 'Nom d\'utilisateur';

  @override
  String get adminAccount => 'Compte administrateur';

  @override
  String get makeTheFirst => 'Créez le premier compte administrateur.';

  @override
  String get setANew =>
      'Définissez un nouveau mot de passe pour un compte administrateur.';

  @override
  String get thisSetupLink =>
      'Ce lien de configuration a déjà servi ou provient d\'un démarrage antérieur. Ouvrez le plus récent dans le journal du serveur, ou connectez-vous.';

  @override
  String get thePasswordsDont => 'Les mots de passe ne correspondent pas.';

  @override
  String get newPasswordAgain => 'Confirmer le nouveau mot de passe';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get passwordChangedYour =>
      'Mot de passe changé. Vos autres navigateurs sont déconnectés.';

  @override
  String get theNewPasswords =>
      'Les nouveaux mots de passe ne correspondent pas.';

  @override
  String get theyAreSigned =>
      'Cette personne est déconnectée et ne peut plus se reconnecter.';

  @override
  String get cantSignIn => 'Connexion impossible, déconnecté partout.';

  @override
  String get usersReachOnly =>
      'Les utilisateurs n\'accèdent qu\'aux profils ci-dessous.';

  @override
  String get adminsCanDo =>
      'Les administrateurs peuvent tout faire, sur tous les profils.';

  @override
  String get admin => 'Administrateur';

  @override
  String get user => 'Utilisateur';

  @override
  String get leaveEmptyToKeepIt =>
      'Laissez vide pour le conserver. En définir un déconnecte cette personne ailleurs.';

  @override
  String get needsAPassword =>
      'A besoin d\'un mot de passe pour pouvoir se connecter.';

  @override
  String get addUser => 'Ajouter un utilisateur';

  @override
  String get needsAPassword2 => 'A besoin d\'un mot de passe';

  @override
  String get noProfiles => 'Aucun profil';

  @override
  String get pad => 'Compléter';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  Clips : $clips';
  }

  @override
  String get clipsFrom2 => 'Clips de';

  @override
  String get channelsUsingItGo =>
      'Les chaînes qui l\'utilisent reviennent à une icône intégrée.';

  @override
  String get uploading => 'Envoi…';

  @override
  String get noneOfYourShows =>
      'Aucune de vos séries n\'a d\'image de logo sur votre serveur.';

  @override
  String get chooseAnIcon => 'Choisir une icône';

  @override
  String get couldntCopySelect =>
      'Copie impossible. Sélectionnez le texte et copiez-le.';

  @override
  String copy(Object label) {
    return 'Copier $label';
  }

  @override
  String get home => 'Accueil';

  @override
  String get thereIsNoPage => 'Il n\'y a pas de page ici.';

  @override
  String get enterPin => 'Saisir le code PIN';

  @override
  String get thisIsA =>
      'C\'est un profil enfant. Modifier ses réglages nécessite le code PIN d\'un adulte.';

  @override
  String hasAPin(Object name) {
    return '$name a un code PIN.';
  }

  @override
  String get profile => 'Profil';

  @override
  String get changingAKid =>
      'Modifier les réglages d\'un profil enfant nécessite le code PIN d\'un profil adulte.';

  @override
  String get aGrownUps => 'Le code PIN d\'un adulte';

  @override
  String get thisProfile => 'ce profil';

  @override
  String movies3(Object movies) {
    return 'Films ($movies)';
  }

  @override
  String get shows3 => 'Séries';

  @override
  String remove4(Object label) {
    return 'Retirer $label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · Introuvable sur le serveur';
  }

  @override
  String get dragACollection =>
      'Faites glisser ici une collection, un dossier ou un film, ou utilisez son bouton Ajouter.';

  @override
  String get collectionsAndFolders => 'Collections et dossiers';

  @override
  String add3(Object name) {
    return 'Ajouter $name';
  }

  @override
  String added2(Object name) {
    return '$name ajouté';
  }

  @override
  String get dragToAdd => 'Faire glisser pour ajouter';

  @override
  String get languageAutomatic => 'Automatique';

  @override
  String dateAtTime(String date, String time) {
    return '$date à $time';
  }

  @override
  String connectingTo(Object server) {
    return 'Connexion à $server…';
  }

  @override
  String get yourServerLower => 'votre serveur';

  @override
  String noServerFoundAt(Object address) {
    return 'Aucun serveur Jellyfin, Emby ou Plex trouvé à $address.';
  }

  @override
  String captionsValue(Object name) {
    return 'Sous-titres : $name';
  }

  @override
  String channelOverrides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chaînes ont leur propre réglage (Chaînes et icônes).',
      one: '$count chaîne a son propre réglage (Chaînes et icônes).',
    );
    return '$_temp0';
  }

  @override
  String noShowLogosOn(Object kind) {
    return 'Aucune de vos séries n\'a d\'image de logo sur votre serveur $kind.';
  }

  @override
  String fileChosen(Object name) {
    return 'Fichier : $name';
  }

  @override
  String get theOneChosenBefore => 'celui choisi précédemment';

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
          'Diffusion des chaînes $channels vers $viewers spectateur(s). $running flux utilisés sur $limit.',
      one:
          'Diffusion de la chaîne $channels vers $viewers spectateur(s). $running flux utilisés sur $limit.',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name : exporter cette grille';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name (enfant) : exporter cette grille';
  }

  @override
  String encoderInUse(Object encoder) {
    return 'Encodeur utilisé : $encoder';
  }

  @override
  String get checking => 'vérification…';

  @override
  String countShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String countEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count épisodes',
      one: '$count épisode',
    );
    return '$_temp0';
  }

  @override
  String countMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count films',
      one: '$count film',
    );
    return '$_temp0';
  }

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String countMusicVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '$count clip',
    );
    return '$_temp0';
  }

  @override
  String countHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count masquées',
      one: '$count masquée',
    );
    return '$_temp0';
  }

  @override
  String countOnTheAir(int count) {
    return '$count à l\'antenne';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs de programmes',
      one: '$count bloc de programmes',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name : $stats';
  }

  @override
  String get yourServerHasNothingNew =>
      'Votre serveur n\'a rien de nouveau depuis la dernière actualisation. Les nouveaux fichiers apparaissent ici une fois analysés par le serveur : si vous venez d\'en ajouter, analysez d\'abord la bibliothèque sur le serveur, puis actualisez de nouveau.';

  @override
  String serverHasNothingNew(Object server) {
    return '$server n\'a rien de nouveau depuis la dernière actualisation. Les nouveaux fichiers apparaissent ici une fois analysés par le serveur : si vous venez d\'en ajouter, analysez d\'abord la bibliothèque sur le serveur, puis actualisez de nouveau.';
  }

  @override
  String get updateWatchStatusOnYourServer =>
      'Mettre à jour l\'état de visionnage sur votre serveur';

  @override
  String get updateWatchStatusOnYourServers =>
      'Mettre à jour l\'état de visionnage sur vos serveurs';

  @override
  String updateWatchStatusOn(Object name) {
    return 'Mettre à jour l\'état de visionnage sur $name';
  }

  @override
  String get poolFoldersBumpers =>
      'Chaque vidéo de ces dossiers (et de leurs sous-dossiers) ouvre et ferme les pauses, et n\'est jamais diffusée comme programme.';

  @override
  String get poolFoldersCommercials =>
      'Chaque vidéo de ces dossiers (et de leurs sous-dossiers) remplit les pauses, et n\'est jamais diffusée comme programme.';

  @override
  String get newPin => 'Nouveau code PIN';

  @override
  String namedPin(Object name) {
    return 'Code PIN de $name';
  }

  @override
  String get qualitySameAsProfile => 'Qualité : comme le profil';

  @override
  String qualityValue(Object limit) {
    return 'Qualité : $limit';
  }

  @override
  String onChannel(Object channel) {
    return 'sur $channel';
  }

  @override
  String get aChannelThatIsGone => 'une chaîne qui n\'existe plus';

  @override
  String liveFrom(Object source) {
    return 'En direct de $source';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'Logo $mode · Premières $premieres';
  }

  @override
  String get offLower => 'désactivé';

  @override
  String streamingNow(Object count) {
    return 'Flux en cours : $count.';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return 'Flux en cours : $count · encodage avec $encoder.';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · Chaînes : $chosen sur $channels';
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
    return 'Du $when ($device) : $profiles. Chaînes : $channels, blocs de programmes : $blocks, logos : $logos.';
  }

  @override
  String get backupSavedFirst =>
      'Une sauvegarde de ce qui se trouve ici est d\'abord enregistrée.';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles séries',
      one: '$count nouvelle série',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux épisodes',
      one: '$count nouvel épisode',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux films',
      one: '$count nouveau film',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux morceaux',
      one: '$count nouveau morceau',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return 'Diffuse $list.';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles chaînes',
      one: '$count nouvelle chaîne',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => 'Jeunes enfants';

  @override
  String get kidRatingYoungDescription => 'TV-Y et TV-Y7';

  @override
  String get kidRatingKids => 'Enfants';

  @override
  String get kidRatingKidsDescription => 'Jusqu\'à TV-G et G';

  @override
  String get kidRatingOlder => 'Grands enfants';

  @override
  String get kidRatingOlderDescription => 'Jusqu\'à TV-PG et PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profils',
      one: '$count profil',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chaînes',
      one: '$count chaîne',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs',
      one: '$count bloc',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créneaux',
      one: '$count créneau',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos dans ses dossiers',
      one: '$count vidéo dans ses dossiers',
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
  String get liveLabel => 'Direct';

  @override
  String get aMidRollOpens =>
      'Un mid-roll s\'ouvre et se ferme sur un jingle, un post-roll s\'ouvre sur un jingle et un pré-roll se ferme sur un jingle. Les publicités remplissent le reste.';

  @override
  String get programsPlayBack => 'Les programmes s\'enchaînent, sans pauses.';

  @override
  String get everyShowFills =>
      'Chaque série remplit un créneau d\'une demi-heure (une heure ou plus pour les longues), pour que le guide reste à l\'heure.';

  @override
  String get chooseHowLong =>
      'Choisissez la durée de chaque pause, leur fréquence et le groupe où chacune puise.';

  @override
  String get kindSentenceAutomatic => 'automatique';

  @override
  String get kindSentenceBeforeRestore => 'avant la restauration';

  @override
  String get kindSentenceBeforeReset => 'avant la réinitialisation';

  @override
  String get kindSentenceBeforeDeletingAProfile =>
      'avant la suppression d\'un profil';

  @override
  String kindSentenceBeforeDeleting(Object subject) {
    return 'avant la suppression de $subject';
  }

  @override
  String get kindSentenceBeforeUpdate => 'avant la mise à jour';

  @override
  String get kindSentenceBeforeLineupCleanup =>
      'avant le nettoyage de la grille';

  @override
  String get kindSentenceFromAFile => 'depuis un fichier';

  @override
  String get kindSentenceMovingToOfficial => 'transfert vers Nightingale TV';

  @override
  String get kindSentenceMovingToOwnBuild =>
      'transfert vers Nightingale TV (version personnelle)';

  @override
  String get kindSentenceFromOfficial => 'depuis Nightingale TV';

  @override
  String get kindSentenceFromOwnBuild =>
      'depuis Nightingale TV (version personnelle)';

  @override
  String get kindSentenceMadeByYou => 'créée par vous';

  @override
  String get copyAction => 'Copier';

  @override
  String get channelKidsZone => 'Zone Enfants';

  @override
  String get channelToonTv => 'Toon TV';

  @override
  String get channelLaughTrack => 'Rires en boîte';

  @override
  String get channelFamilyRoom => 'Salon Famille';

  @override
  String get channelAdventureTv => 'Aventure TV';

  @override
  String get channelSciFiFantasy => 'SF et Fantastique';

  @override
  String get channelMysteryTv => 'Mystère TV';

  @override
  String get channelDramaCentral => 'Drame Central';

  @override
  String get channelCrimeJustice => 'Crime et Justice';

  @override
  String get channelThrillTv => 'Frissons TV';

  @override
  String get channelFrightNight => 'Nuit d\'Épouvante';

  @override
  String get channelRomanceTv => 'Romance TV';

  @override
  String get channelDiscoveryZone => 'Zone Découverte';

  @override
  String get channelMusicTv => 'Musique TV';

  @override
  String get channelRealityTv => 'Téléréalité TV';

  @override
  String get channelGameShowTv => 'Jeux TV';

  @override
  String get channelFrontierTv => 'Far West TV';

  @override
  String get channelHistoryTv => 'Histoire TV';

  @override
  String get channelSportsTv => 'Sport TV';

  @override
  String get channelNewsTv => 'Actu TV';

  @override
  String get channelAllShows => 'Toutes les séries';

  @override
  String get channelMovieChannel => 'Chaîne Cinéma';

  @override
  String get channelMusicVideos => 'Clips musicaux';

  @override
  String get channelMusicRadio => 'Radio Musique';

  @override
  String get genreActionAdventure => 'Action et aventure';

  @override
  String get genreSciFiFantasy => 'SF et fantastique';

  @override
  String get genreKids => 'Enfants';

  @override
  String get genreAnimation => 'Animation';

  @override
  String get genreComedy => 'Comédie';

  @override
  String get genreFamily => 'Famille';

  @override
  String get genreDrama => 'Drame';

  @override
  String get genreCrime => 'Policier';

  @override
  String get genreMystery => 'Mystère';

  @override
  String get genreThriller => 'Thriller';

  @override
  String get genreHorror => 'Horreur';

  @override
  String get genreRomance => 'Romance';

  @override
  String get genreDocumentary => 'Documentaire';

  @override
  String get genreMusic => 'Musique';

  @override
  String get genreReality => 'Téléréalité';

  @override
  String get genreGameShows => 'Jeux télévisés';

  @override
  String get genreWestern => 'Western';

  @override
  String get genreWar => 'Guerre';

  @override
  String get genreHistory => 'Histoire';

  @override
  String get genreNews => 'Actualités';

  @override
  String get genreTalk => 'Talk-show';

  @override
  String get genreSoap => 'Feuilleton';

  @override
  String get genreSports => 'Sport';

  @override
  String get genreClassical => 'Classique';

  @override
  String get genreElectronic => 'Électronique';

  @override
  String get genreCountry => 'Country';

  @override
  String get genreLatin => 'Latino';

  @override
  String get genreSoundtrack => 'Bande originale';

  @override
  String get genreOldies => 'Rétro';

  @override
  String get genreDance => 'Dance';

  @override
  String get genreFolk => 'Folk';

  @override
  String get genreAlternative => 'Alternatif';

  @override
  String get blockDaytime => 'Journée';

  @override
  String get blockMovieNight => 'Soirée Cinéma';

  @override
  String get blockNewEpisodes => 'Nouveaux épisodes';

  @override
  String get kindShow => 'Série';

  @override
  String get kindShows => 'Séries';

  @override
  String get kindMovies => 'Films';

  @override
  String get kindMusicVideos => 'Clips musicaux';

  @override
  String get kindRadio => 'Radio';

  @override
  String genreMovies(Object genre) {
    return 'Films $genre';
  }

  @override
  String genreMusicVideos(Object genre) {
    return 'Clips $genre';
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
  String get lateNightTitle => 'Fin de soirée';

  @override
  String get languageTitle => 'Langue';

  @override
  String get stillWatchingOff => 'Désactivé';

  @override
  String afterHours(int hours) {
    return 'Après $hours heures';
  }

  @override
  String get bitrateOriginal => 'Original (sans limite)';

  @override
  String get bitrate40 => '40 Mbit/s · 4K';

  @override
  String get bitrate20 => '20 Mbit/s · 1080p élevé';

  @override
  String get bitrate12 => '12 Mbit/s · 1080p';

  @override
  String get bitrate8 => '8 Mbit/s · 1080p';

  @override
  String get bitrate4 => '4 Mbit/s · 720p';

  @override
  String get noSuchLanguage => 'Langue introuvable.';

  @override
  String get languageField => 'Langue';

  @override
  String get remotePageTitle => 'Télécommande Nightingale TV';

  @override
  String get remotePairTitle => 'Associer à la TV';

  @override
  String get remotePairHelp =>
      'Scannez le code sur la TV (Menu → Télécommande), ou saisissez le code à 6 chiffres qui y est affiché.';

  @override
  String get remotePairingCode => 'Code d\'association';

  @override
  String get remotePair => 'Associer';

  @override
  String get remoteConnecting => 'Connexion…';

  @override
  String get remoteTabRemote => 'Télécommande';

  @override
  String get remoteUp => 'Haut';

  @override
  String get remoteLeft => 'Gauche';

  @override
  String get remoteRight => 'Droite';

  @override
  String get remoteDown => 'Bas';

  @override
  String get remoteInfo => 'Infos';

  @override
  String get remoteLastCh => 'Préc.';

  @override
  String get remoteCc => 'ST';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => 'Entrée';

  @override
  String get remoteRemovedFromTv =>
      'Ce téléphone a été retiré de la TV. Scannez le code pour l\'associer de nouveau.';

  @override
  String get remoteCouldntPair => 'Association impossible. Réessayez.';

  @override
  String get remoteCantReachWifi =>
      'Impossible de joindre la TV. Ce téléphone est-il sur le même Wi-Fi ?';

  @override
  String get remoteEnterDigits =>
      'Saisissez les 6 chiffres affichés sur la TV.';

  @override
  String get remoteCantReachTv => 'Impossible de joindre la TV';

  @override
  String get remotePickProfile =>
      'Choisissez un profil avec les flèches et OK.';

  @override
  String remoteWatching(Object name) {
    return 'Regarde : $name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name (enfant)';
  }

  @override
  String get transferPageTitle => 'Sauvegarde Nightingale TV';

  @override
  String get transferIntro =>
      'Déplacez une sauvegarde entre cette TV et cet appareil. Gardez la fenêtre de la TV ouverte pendant ce temps.';

  @override
  String get transferDownload => 'Télécharger la sauvegarde';

  @override
  String get transferDownloadHelp =>
      'Une sauvegarde de la configuration actuelle de la TV : profils, chaînes, blocs et réglages.';

  @override
  String get transferRestoreTitle => 'Restaurer depuis un fichier';

  @override
  String transferRestoreHelp(Object file) {
    return 'Envoyez un fichier $file à la TV. Rien ne change tant que vous ne confirmez pas sur la TV.';
  }

  @override
  String get transferChoose => 'Choisir un fichier de sauvegarde…';

  @override
  String get transferFoot =>
      'Seuls les appareils de votre réseau domestique peuvent ouvrir cette page.';

  @override
  String transferSending(Object name) {
    return 'Envoi de $name…';
  }

  @override
  String get transferCheckTv => 'Regardez votre TV pour terminer.';

  @override
  String get transferClosed =>
      'La TV a fermé cette page. Rouvrez-la depuis Sauvegarde et restauration.';

  @override
  String get transferCouldntTake => 'La TV n\'a pas pu accepter ce fichier.';

  @override
  String get transferCouldntReach =>
      'Impossible de joindre la TV. Affiche-t-elle toujours le code ?';

  @override
  String get includeShows => 'Inclure les séries';

  @override
  String get everyShow2 => 'chaque série';

  @override
  String get decades => 'Décennies';

  @override
  String get decadesHeading => 'DÉCENNIES';

  @override
  String get channelActionTv => 'Action TV';

  @override
  String get channelSciFiTv => 'SF TV';

  @override
  String get channelFantasyTv => 'Fantastique TV';

  @override
  String get channelMysteryThrills => 'Mystère & Frissons';

  @override
  String get genreAction => 'Action';

  @override
  String get genreAdventure => 'Aventure';

  @override
  String get genreSciFi => 'SF';

  @override
  String get genreFantasy => 'Fantastique';

  @override
  String get genreThrillerMystery => 'Thriller et mystère';

  @override
  String decadeTv(Object decade) {
    return 'TV $decade';
  }

  @override
  String decadeGenreTv(Object decade, Object genre) {
    return '$genre TV $decade';
  }

  @override
  String decadeGenreMovies(Object decade, Object genre) {
    return 'Films $genre $decade';
  }
}
