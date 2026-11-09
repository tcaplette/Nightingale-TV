// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get onlyChannelsYou =>
      'Solo se pueden quitar los canales que añadiste. Oculta este en su lugar.';

  @override
  String get music => 'Música';

  @override
  String get nothingInThe => 'Nada en la biblioteca coincide con eso.';

  @override
  String get chooseSongsOr => 'Elige canciones o videos musicales.';

  @override
  String get blockChannel => 'Canal de bloques';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return 'Esto se solapa con «$title» ($clash) en el mismo canal.';
  }

  @override
  String get chooseSomeShows =>
      'Elige series o películas para que el bloque las reproduzca.';

  @override
  String nothingInThis(Object shortLabel) {
    return 'Nada en esta mezcla tiene la clasificación $shortLabel o superior. Elige una clasificación más baja u otras series.';
  }

  @override
  String get theLineupsShows =>
      'Las series de la parrilla no tienen episodios. Elige otras series.';

  @override
  String get addAShow => 'Añade una serie a la parrilla.';

  @override
  String get chooseAChannel => 'Elige un canal.';

  @override
  String get theBlockHas =>
      'El bloque debe terminar a una hora distinta de la de inicio.';

  @override
  String get pickAtLeast => 'Elige al menos un día.';

  @override
  String get giveTheBlock => 'Ponle un título al bloque.';

  @override
  String get thisChannelDoesnt => 'Este canal no tiene franjas.';

  @override
  String get onlyShuffledChannels =>
      'Solo se pueden volver a mezclar los canales aleatorios.';

  @override
  String get chooseSomethingFor =>
      'Elige algo para que el canal lo reproduzca.';

  @override
  String get onlyChannelsYouAdded =>
      'Solo los canales que añadiste pueden cambiar lo que reproducen.';

  @override
  String get myChannel => 'Mi canal';

  @override
  String get noneOfYour => 'No se pudo acceder a ninguno de tus servidores.';

  @override
  String scanning(Object where) {
    return 'Analizando $where…';
  }

  @override
  String get buildingChannels => 'Creando canales…';

  @override
  String get notSignedIn => 'No has iniciado sesión.';

  @override
  String isAlreadyIn(Object name) {
    return '$name ya está en este perfil';
  }

  @override
  String get thatServerIs => 'Ese servidor ya no está en este perfil';

  @override
  String get yourSessionExpired =>
      'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String get m3uPlaylist => 'Lista M3U';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName no tiene canales de TV en directo';
  }

  @override
  String couldntReach(Object serverName) {
    return 'No se pudo acceder a $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return 'TV en directo de $serverName';
  }

  @override
  String liveTvIs(Object serverName) {
    return 'La TV en directo de $serverName ya es una fuente';
  }

  @override
  String get notSignedIn2 => 'No has iniciado sesión';

  @override
  String get newGroup => 'Grupo nuevo';

  @override
  String get thisBackupIs =>
      'Esta copia de seguridad está dañada: no se puede leer uno de sus logotipos de canal.';

  @override
  String get thisBackupIsDamaged =>
      'Esta copia de seguridad está dañada: no se pueden leer sus ajustes de exportación de TV en directo.';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'Esta copia de seguridad está dañada: no se puede leer $what de $name.';
  }

  @override
  String get liveTvSources => 'Fuentes de TV en directo';

  @override
  String thisBackupCant(Object problem) {
    return 'Esta copia de seguridad no se puede restaurar. $problem';
  }

  @override
  String get thisBackupIsDamagedIts =>
      'Esta copia de seguridad está dañada: no se pueden leer sus perfiles.';

  @override
  String get thisFileIs =>
      'Este archivo es demasiado grande para ser una copia de seguridad de Nightingale TV.';

  @override
  String get thisBackupWas =>
      'Esta copia de seguridad se hizo con una versión más reciente de Nightingale TV.';

  @override
  String get thisFileIsnt =>
      'Este archivo no es una copia de seguridad de Nightingale TV o está dañado.';

  @override
  String restoredTheBackup(Object toLocal) {
    return 'Se restauró la copia de seguridad del $toLocal.';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'No se pudo restaurar la copia de seguridad: $e';
  }

  @override
  String couldntSaveA(Object e) {
    return 'No se pudo guardar antes una copia de seguridad: $e';
  }

  @override
  String get madeByYou => 'Creada por ti';

  @override
  String get fromNightingaleTv => 'Desde Nightingale TV (versión propia)';

  @override
  String get fromNightingaleTv2 => 'Desde Nightingale TV';

  @override
  String get movingToNightingale =>
      'Traslado a Nightingale TV (versión propia)';

  @override
  String get movingToNightingaleTv => 'Traslado a Nightingale TV';

  @override
  String get fromAFile => 'Desde un archivo';

  @override
  String get beforeLineupCleanup => 'Antes de limpiar la parrilla';

  @override
  String get beforeUpdate => 'Antes de actualizar';

  @override
  String beforeDeleting(Object subject) {
    return 'Antes de eliminar $subject';
  }

  @override
  String get beforeDeletingA => 'Antes de eliminar un perfil';

  @override
  String get beforeReset => 'Antes de restablecer';

  @override
  String get beforeRestore => 'Antes de restaurar';

  @override
  String get automatic => 'Automático';

  @override
  String get nc1718 => 'NC-17 / 18 o superior';

  @override
  String get tvMaR => 'TV-MA / R o superior';

  @override
  String get tv14Pg => 'TV-14 / PG-13 o superior';

  @override
  String get off => 'Desactivado';

  @override
  String get nowAndThen => 'De vez en cuando';

  @override
  String get always => 'Siempre';

  @override
  String get truncate => 'Cortar';

  @override
  String get offlineImage => 'Imagen sin emisión';

  @override
  String get filler => 'Relleno';

  @override
  String get leastWatchedFirst => 'Lo menos visto primero';

  @override
  String get shuffled => 'Aleatorio';

  @override
  String get inOrderShows => 'En orden (las series se turnan)';

  @override
  String get channelsWhereEverything =>
      'Canales en los que todo lo que se emite, incluidos los bloques, tiene clasificación TV-Y, TV-Y7, TV-G o G.';

  @override
  String get musicVideoAnd => 'Canales de videos musicales y radio.';

  @override
  String get channelsThatPlay =>
      'Canales que emiten películas y no episodios ni música.';

  @override
  String get channelsFromYour => 'Canales de tus fuentes de TV en directo.';

  @override
  String get channelsYouMarked => 'Canales que marcaste como favoritos.';

  @override
  String get everyChannel => 'Todos los canales.';

  @override
  String get kids => 'Niños';

  @override
  String get movies => 'Películas';

  @override
  String get liveTv2 => 'TV en directo';

  @override
  String get favorites => 'Favoritos';

  @override
  String get all => 'Todos';

  @override
  String get theAccentsAre =>
      'Los acentos son un tema y «theme» o «channel» para cada uno.';

  @override
  String get thoseArentRetro => 'Esos no son ajustes retro.';

  @override
  String get theOverlayTheme =>
      'El tema de superposición es standard, vcr, cableBox o stationIdent.';

  @override
  String get theCrtEffect =>
      'El efecto CRT es off, softTube, livingRoom, arcade, studioMonitor o custom.';

  @override
  String get theSurroundImage =>
      'La imagen de entorno es un nombre de archivo.';

  @override
  String get theSurroundIs => 'El entorno es black, charcoal, channel o image.';

  @override
  String get thePictureShape =>
      'La forma de imagen es original, fill43 o fit43.';

  @override
  String get channelColor => 'Color del canal';

  @override
  String get theme => 'Tema';

  @override
  String get stationIdent => 'Identidad de canal';

  @override
  String get cableBox => 'Decodificador';

  @override
  String get vcr => 'Vídeo VHS';

  @override
  String get standard => 'Estándar';

  @override
  String get custom => 'Personalizado';

  @override
  String get studioMonitor => 'Monitor de estudio';

  @override
  String get arcade => 'Recreativa';

  @override
  String get livingRoom => 'Salón';

  @override
  String get softTube => 'Tubo suave';

  @override
  String get customColorIs =>
      'El color personalizado es natural, warm, faded o vivid.';

  @override
  String get customLinesIs => 'Las líneas personalizadas son 240 o 480.';

  @override
  String customIsOff(Object key) {
    return '$key personalizado es off, low, medium o high.';
  }

  @override
  String get thatIsntA => 'Ese no es un estilo personalizado.';

  @override
  String get vivid => 'Vivo';

  @override
  String get faded => 'Desvaído';

  @override
  String get warm => 'Cálido';

  @override
  String get natural => 'Natural';

  @override
  String get high => 'Alto';

  @override
  String get medium => 'Medio';

  @override
  String get low => 'Bajo';

  @override
  String get image => 'Imagen';

  @override
  String get charcoal => 'Carbón';

  @override
  String get black => 'Negro';

  @override
  String get n43Fit => '4:3 ajustar';

  @override
  String get n43Fill => '4:3 llenar';

  @override
  String get original => 'Original';

  @override
  String get thisChannelIs => 'Este canal no está en emisión';

  @override
  String get offAir => 'Sin emisión';

  @override
  String get tail => 'Relleno';

  @override
  String get postRoll => 'Post-roll';

  @override
  String get midRoll => 'Mid-roll';

  @override
  String get preRoll => 'Pre-roll';

  @override
  String get commercials => 'Anuncios';

  @override
  String get bumpers => 'Cortinillas';

  @override
  String get pleaseStandBy => 'POR FAVOR, ESPERA';

  @override
  String get offTheAir => 'FUERA DE EMISIÓN';

  @override
  String get wellBeRight => 'Volvemos enseguida';

  @override
  String upNextAt(Object at) {
    return 'A continuación a las $at';
  }

  @override
  String backOnThe(Object next, Object title) {
    return 'De vuelta en emisión $next con $title';
  }

  @override
  String get processor => 'Procesador';

  @override
  String get graphicsCardNvenc => 'Tarjeta gráfica (NVENC)';

  @override
  String get graphicsCardVaapi => 'Tarjeta gráfica (VAAPI)';

  @override
  String get signInTo =>
      'Inicia sesión con este perfil en la TV para exportar sus canales.';

  @override
  String get signInToThis =>
      'Inicia sesión con este perfil aquí para exportar sus canales.';

  @override
  String portIsIn(Object port) {
    return 'Otro programa está usando el puerto $port. Elige otro puerto y actualízalo en Plex o Jellyfin.';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'Otro perfil ya usa el puerto $port.';
  }

  @override
  String get pickAPort => 'Elige un puerto entre 1024 y 65535.';

  @override
  String get movie => 'Película';

  @override
  String backOnTheAir(Object start, Object title) {
    return 'De vuelta en emisión $start con $title.';
  }

  @override
  String get images => 'Imágenes';

  @override
  String get couldNotRead =>
      'No se pudo leer esa imagen. Prueba con PNG, JPG, WebP o SVG.';

  @override
  String get thatFileIs => 'Ese archivo no es un SVG válido.';

  @override
  String get thatImageIs =>
      'Esa imagen supera los 20 MB. Elige una más pequeña.';

  @override
  String get other => 'Otros';

  @override
  String get seasonsHolidays => 'Estaciones y festividades';

  @override
  String get newsWeather => 'Noticias y tiempo';

  @override
  String get sports => 'Deportes';

  @override
  String get genres => 'Géneros';

  @override
  String get kidsFamily => 'Niños y familia';

  @override
  String get tvMovies => 'TV y películas';

  @override
  String get theServerWould => 'El servidor no quiso convertir este elemento.';

  @override
  String get theServerHas =>
      'El servidor no tiene una versión reproducible de este elemento.';

  @override
  String get externalLabel => 'Externos';

  @override
  String get scanningChannelSources => 'Analizando fuentes de canales…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl no respondió como un servidor Jellyfin.';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return 'No se encontró ningún servidor Jellyfin en $serverUrl. $message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return 'Error del servidor $statusCode en $path.';
  }

  @override
  String get wrongUsernameOr =>
      'Usuario o contraseña incorrectos, o la sesión ha caducado.';

  @override
  String couldNotReach(Object e) {
    return 'No se pudo acceder al servidor ($e).';
  }

  @override
  String get theServerTook => 'El servidor tardó demasiado en responder.';

  @override
  String get theServerWouldNot => 'El servidor no quiso convertir este canal.';

  @override
  String get musicVideo => 'Video musical';

  @override
  String movie2(Object year) {
    return 'Película · $year';
  }

  @override
  String get commercial => 'Anuncio';

  @override
  String couldntReachThe(Object what) {
    return '$what: no se pudo acceder';
  }

  @override
  String theIsToo(Object what) {
    return '$what: demasiado grande';
  }

  @override
  String theSAddress(Object what) {
    return '$what: la dirección no es una dirección web';
  }

  @override
  String get noGuideInformation => 'Sin información de programación';

  @override
  String get serverLiveTv => 'TV en directo del servidor';

  @override
  String get theChannelHas => 'El canal no tiene dirección de emisión.';

  @override
  String get couldntReadThe => 'No se pudo leer la guía';

  @override
  String get couldntReachTheGuide => 'No se pudo acceder a la guía';

  @override
  String get theSourceHas => 'La fuente no tiene lista de reproducción';

  @override
  String get couldntReachThePlaylist =>
      'No se pudo acceder a la lista de reproducción';

  @override
  String get couldntReadThePlaylist => 'No se pudo leer el archivo de la lista';

  @override
  String couldntRefresh(Object name) {
    return 'No se pudo actualizar $name';
  }

  @override
  String get thePlaylistHas => 'La lista no tiene canales';

  @override
  String get thatIsntAn => 'Eso no es una lista M3U';

  @override
  String get thatIsntAnXmltv => 'Eso no es una guía XMLTV';

  @override
  String get theGuideIs => 'La guía es demasiado grande (más de 1 GB)';

  @override
  String get nightingaleTvBackups => 'Copias de seguridad de Nightingale TV';

  @override
  String get uninstallingThisApp =>
      'Al desinstalar esta app se eliminan sus perfiles, canales y ajustes, a menos que antes los guardes en una copia o los traslades.';

  @override
  String theStoreVersion(Object officialName) {
    return 'La versión de la tienda se instala junto a esta como una app independiente, «$officialName», con su propia configuración. Comprarla apoya el proyecto. Una vez instalada, puedes trasladar tu configuración desde aquí.';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Las actualizaciones de Google Play y los APK oficiales de Nightingale TV se instalan sobre esta y conservan tu configuración. Una versión propia se instala como app independiente, «$ownBuildName», y puedes trasladar tu configuración desde aquí.';
  }

  @override
  String get yourOwnBuild => 'Tu versión propia';

  @override
  String get officialNightingaleTv => 'APK oficial de Nightingale TV';

  @override
  String get installedFromGoogle => 'Instalada desde Google Play';

  @override
  String get nightingaleTvOwn => 'Nightingale TV (versión propia)';

  @override
  String get sleepTimerOff => 'Temporizador desactivado';

  @override
  String get sleepAtEnd => 'Dormir al final del programa';

  @override
  String sleepInMin(Object minutes) {
    return 'Dormir en $minutes min';
  }

  @override
  String get forced => 'Forzados';

  @override
  String get unknownLanguage => 'Idioma desconocido';

  @override
  String didntStart(Object name) {
    return '$name no se inició';
  }

  @override
  String get thisDeviceCant =>
      'Este dispositivo no puede reproducir el video de este canal';

  @override
  String get thisChannelsStream =>
      'El tipo de emisión de este canal no es compatible con este dispositivo';

  @override
  String refusedTheStream(Object name) {
    return '$name rechazó la emisión. Puede que se esté reproduciendo en otro dispositivo.';
  }

  @override
  String yourAccountCant(Object server) {
    return 'Tu cuenta de $server no puede ver este canal';
  }

  @override
  String cantReach(Object name) {
    return 'No se puede acceder a $name';
  }

  @override
  String allOfS(Object server) {
    return 'Todos los sintonizadores de $server están en uso';
  }

  @override
  String lostTheSignal(Object name) {
    return 'Se perdió la señal en $name';
  }

  @override
  String get couldntPlayThat =>
      'No se pudo reproducir esa parte. Volviendo al directo';

  @override
  String get backToLive => 'Volviendo al directo';

  @override
  String get theServerTookToo =>
      'El servidor tardó demasiado en empezar a convertir este programa.';

  @override
  String get nothingToPlay => 'Nada que reproducir en este canal';

  @override
  String captionsOn(Object shown) {
    return 'Subtítulos activados: $shown';
  }

  @override
  String get captionsOn2 => 'Subtítulos activados';

  @override
  String get captionsOnNo =>
      'Subtítulos activados: no hay subtítulos para este programa';

  @override
  String get captionsOff => 'Subtítulos desactivados';

  @override
  String get guest => 'Invitado';

  @override
  String get thereHasTo => 'Debe haber al menos un perfil de adulto.';

  @override
  String get switchToAnother => 'Cambia a otro perfil antes de eliminar este.';

  @override
  String get me => 'Yo';

  @override
  String get couldntOpenA => 'No se pudo abrir un puerto de red para el mando.';

  @override
  String get notPaired => 'Sin vincular';

  @override
  String get phone => 'Teléfono';

  @override
  String get thatCodeDoesnt =>
      'Ese código no coincide. Comprueba el código en la TV.';

  @override
  String get openMenuPhone =>
      'Abre Menú → Mando del teléfono en la TV para vincular';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'Tu cuenta de $serverName no puede ver TV en directo';
  }

  @override
  String get enterYourServer => 'Introduce la dirección de tu servidor.';

  @override
  String get needsSignIn => 'Hay que iniciar sesión';

  @override
  String get cantBeReached => 'Inaccesible';

  @override
  String isNotAnswering(Object name) {
    return '$name no responde en ninguna de sus direcciones. ¿Está encendido?';
  }

  @override
  String get everyServerOn =>
      'Todos los servidores de esta cuenta de Plex ya están en este perfil.';

  @override
  String get thisPlexAccount =>
      'Esta cuenta de Plex no tiene servidores. Pide a su propietario que lo comparta contigo.';

  @override
  String quickConnectStopped(Object message) {
    return 'Quick Connect se detuvo: $message';
  }

  @override
  String get enterYourUsername => 'Introduce tu nombre de usuario.';

  @override
  String get plexDidNot => 'Plex no cambió de usuario.';

  @override
  String plexTvError(Object statusCode) {
    return 'Error de plex.tv $statusCode.';
  }

  @override
  String get yourPlexSign => 'Tu inicio de sesión de Plex ha caducado.';

  @override
  String couldNotReachPlex(Object e) {
    return 'No se pudo acceder a plex.tv ($e).';
  }

  @override
  String get plexTvTook => 'plex.tv tardó demasiado en responder.';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — Compartido por $ownerName';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'El servidor no quiso convertir este elemento ($transcodeDecisionText).';
  }

  @override
  String get theServerHasNo =>
      'El servidor no tiene ningún archivo para este elemento. Actualiza la biblioteca.';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl no respondió como un servidor Plex.';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return 'No se encontró ningún servidor Plex en $serverUrl. $message';
  }

  @override
  String get thePlexSign => 'El inicio de sesión de Plex ha caducado.';

  @override
  String channelIsNot(Object channelId) {
    return 'El canal $channelId no está en ningún DVR.';
  }

  @override
  String get noSuchUser => 'Ese usuario no existe.';

  @override
  String get yourCurrentPassword => 'Tu contraseña actual es incorrecta.';

  @override
  String get signInFirst => 'Inicia sesión primero.';

  @override
  String thereIsAlready(Object name) {
    return 'Ya existe un usuario llamado $name.';
  }

  @override
  String get thisAccountIs => 'Esta cuenta está desactivada.';

  @override
  String get chooseAnAdmin => 'Elige una cuenta de administrador.';

  @override
  String useAtMost(Object maxNameLength) {
    return 'Usa como máximo $maxNameLength caracteres para el nombre de usuario.';
  }

  @override
  String get enterAUser => 'Introduce un nombre de usuario.';

  @override
  String useAtLeast(Object minPasswordLength) {
    return 'Usa al menos $minPasswordLength caracteres.';
  }

  @override
  String get tooManyWrong =>
      'Demasiadas contraseñas incorrectas. Inténtalo de nuevo en un minuto.';

  @override
  String get wrongUserName => 'Usuario o contraseña incorrectos.';

  @override
  String get openTheSetup =>
      'Abre el enlace de configuración del registro del servidor.';

  @override
  String get makeSomeoneElse => 'Haz antes administrador a otra persona.';

  @override
  String get noSuchProfile => 'Ese perfil no existe.';

  @override
  String get onlyAnAdmin => 'Solo un administrador puede hacer eso.';

  @override
  String get thatProfileIsnt => 'Ese perfil no está asignado a ti.';

  @override
  String get enterAGrown =>
      'Introduce el PIN de un adulto para cambiar los ajustes de un perfil infantil.';

  @override
  String get enterThisProfiles => 'Introduce el PIN de este perfil.';

  @override
  String get reloadThePage => 'Recarga la página e inténtalo de nuevo.';

  @override
  String somethingWentWrong(Object e) {
    return 'Algo salió mal: $e';
  }

  @override
  String get signInToThisProfile => 'Inicia sesión primero en este perfil.';

  @override
  String get changedInAnother =>
      'Cambiado en otra ventana. Mostrando lo más reciente.';

  @override
  String get wrongPin => 'PIN incorrecto.';

  @override
  String get tooManyWrongPins =>
      'Demasiados PIN incorrectos. Inténtalo de nuevo en un minuto.';

  @override
  String get theRoleIs => 'El rol es «admin» o «user».';

  @override
  String get noSuchBackup => 'Esa copia de seguridad no existe.';

  @override
  String get backupsAreOff => 'Las copias de seguridad están desactivadas.';

  @override
  String get noSuchEncoder => 'Ese codificador no existe.';

  @override
  String get allow1To => 'Permite de 1 a 16 emisiones.';

  @override
  String get noSuchQuality => 'Esa calidad no existe.';

  @override
  String get processorOnly => 'Solo procesador';

  @override
  String get liveTvExport =>
      'La exportación de TV en directo no está en marcha.';

  @override
  String get thoseArentPremiere => 'Esos no son ajustes de estrenos.';

  @override
  String get theLogoMode => 'El modo de logotipo es always, nowAndThen u off.';

  @override
  String get thatIsntAPicture =>
      'Esa no es una imagen de la carpeta de logotipos personalizados.';

  @override
  String couldntSaveASafety(Object e) {
    return 'No se pudo guardar antes una copia de seguridad, así que no se restableció nada: $e';
  }

  @override
  String get theKindIs => 'El tipo es «block», «music» o «custom».';

  @override
  String get thatIsntAPlay => 'Ese no es un orden de reproducción.';

  @override
  String get musicChannelsOnly => 'Los canales de música solo son aleatorios.';

  @override
  String get channelNumbersStart => 'Los números de canal empiezan en 1.';

  @override
  String get slotLengthsAre =>
      'Las franjas duran 15, 30, 60, 90 o 120 minutos.';

  @override
  String get thatIsntAChannel => 'Eso no es un canal.';

  @override
  String get noSuchChannel => 'Ese canal no existe.';

  @override
  String get thatPictureIs =>
      'Esa imagen es demasiado grande (5 MB como máximo).';

  @override
  String get unknownAction => 'Acción desconocida.';

  @override
  String get noSuchServer => 'Ese servidor no existe.';

  @override
  String get startSigningIn => 'Empieza primero a iniciar sesión.';

  @override
  String get aRestoreIs => 'Ya hay una restauración en marcha.';

  @override
  String get uploadTheBackup => 'Vuelve a subir la copia de seguridad.';

  @override
  String get discoveryIsOff =>
      'La detección está desactivada, así que añade el sintonizador por su dirección. Ejecuta el contenedor con red de host para activarla.';

  @override
  String get sendKeys => 'Envía «keys».';

  @override
  String get enterThePlaylists =>
      'Introduce la dirección de la lista o elige un archivo de lista';

  @override
  String get uploadTheFile => 'Vuelve a subir el archivo.';

  @override
  String get kidProfilesGet =>
      'Los perfiles infantiles no tienen canales en directo.';

  @override
  String liveTvIsAlready(Object name) {
    return 'La TV en directo de $name ya está añadida';
  }

  @override
  String get noSuchSource => 'Esa fuente no existe.';

  @override
  String get thatFileIsToo =>
      'Ese archivo es demasiado grande (32 MB como máximo).';

  @override
  String get aPinIs => 'Un PIN tiene 4 dígitos.';

  @override
  String get noSuchRating => 'Esa clasificación no existe.';

  @override
  String get noSuchKind => 'Ese tipo no existe.';

  @override
  String get onlyAnAdminCan => 'Solo un administrador puede cambiar eso.';

  @override
  String shouldBeA(Object key) {
    return '«$key» debería ser una lista de texto.';
  }

  @override
  String shouldBeAn(Object key) {
    return '«$key» debería ser un objeto.';
  }

  @override
  String shouldBeTrue(Object key) {
    return '«$key» debería ser verdadero o falso.';
  }

  @override
  String shouldBeANumber(Object key) {
    return '«$key» debería ser un número.';
  }

  @override
  String shouldBeText(Object key) {
    return '«$key» debería ser texto.';
  }

  @override
  String get expectedAJson => 'Se esperaba un objeto JSON.';

  @override
  String get thatIsToo => 'Es demasiado para enviarlo de una vez.';

  @override
  String get aQualityLimit => 'Un límite de calidad es de al menos 500 kbps.';

  @override
  String get orderShouldName =>
      '«order» debería nombrar cada servidor una vez.';

  @override
  String get orderIsMissing => 'Falta «order».';

  @override
  String get signOutOf =>
      'Cierra la sesión del perfil para cambiar su servidor principal.';

  @override
  String get thoseArentPool => 'Esas no son carpetas de grupo.';

  @override
  String get sendRoots => 'Envía «roots».';

  @override
  String get thatIsntAPool => 'Ese no es un tipo de grupo.';

  @override
  String get giveThePool => 'Ponle un nombre al grupo.';

  @override
  String get liveChannelsHave => 'Los canales en directo no tienen pausas.';

  @override
  String get sendAPlan => 'Envía un plan.';

  @override
  String get thatIsntABreak => 'Ese no es un plan de pausas.';

  @override
  String get noSuchPool => 'Ese grupo no existe.';

  @override
  String get thatIsntAProgramming => 'Ese no es un bloque de programación.';

  @override
  String get noSuchBlock => 'Ese bloque no existe.';

  @override
  String get sendEveryTab => 'Envía cada pestaña una vez.';

  @override
  String get sendChannelids => 'Envía «channelIds».';

  @override
  String get giveTheGroup => 'Ponle un nombre al grupo.';

  @override
  String get noSuchGroup => 'Ese grupo no existe.';

  @override
  String get restoringBringsBack =>
      'Al restaurar recuperas tus perfiles, canales, bloques y ajustes. Cada perfil inicia sesión una vez en su servidor.';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels canales',
      one: '$profiles · $channels canal',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup =>
      'Hay una copia de seguridad de tu configuración en este dispositivo:';

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get moveOkSelect => '◀▶ Mover    OK Seleccionar';

  @override
  String get startFresh => 'Empezar de cero';

  @override
  String get restoreIt => 'Restaurarla';

  @override
  String get couldntRestore => 'No se pudo restaurar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get useYourPhone => 'Usar tu teléfono u ordenador';

  @override
  String get openABackup => 'Abrir un archivo de copia';

  @override
  String get setUpThis =>
      'Configura esta TV con una copia de seguridad de Nightingale TV: tus perfiles, canales, bloques y ajustes. Cada perfil inicia sesión una vez en su servidor.';

  @override
  String get restoreFromA => 'Restaurar desde una copia';

  @override
  String get close => 'Cerrar';

  @override
  String get thereYouCan =>
      'Allí puedes descargar una copia de seguridad de esta TV o enviar una para restaurarla aquí. Todo lo que envíes se confirma antes en esta TV. La página se cierra con esta ventana.';

  @override
  String get onAPhone =>
      'En un teléfono, tableta u ordenador en la misma Wi-Fi que esta TV, escanea el código o abre:';

  @override
  String get couldntOpenANetwork =>
      'No se pudo abrir un puerto de red para la página.';

  @override
  String get thePageStopped =>
      'La página se detuvo tras 15 minutos de inactividad. Cierra esto y ábrela de nuevo.';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount y $last';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String get liveTvExportMoves =>
      'La exportación de TV en directo se traslada a este dispositivo. Desactívala en el anterior.';

  @override
  String willNeedTo(Object need) {
    return '$need tendrá que volver a iniciar sesión en su servidor.';
  }

  @override
  String get itSetsUp => 'Configura esta TV tal como está en la copia.';

  @override
  String get itReplacesEverything =>
      'Reemplaza todo lo que hay en esta TV. Antes se guarda una copia de tu configuración actual.';

  @override
  String restoreTheBackup(Object toLocal) {
    return '¿Restaurar la copia de seguridad del $toLocal?';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get saveToFile => 'Guardar en un archivo';

  @override
  String madeOn(Object device) {
    return 'Creada en $device';
  }

  @override
  String get moveOkSelectEsc => '▲▼◀▶ Mover    OK Seleccionar    ESC Atrás';

  @override
  String get backupRestore => 'Copia y restauración';

  @override
  String get backups => 'COPIAS DE SEGURIDAD';

  @override
  String get backUpNow => 'Hacer copia ahora';

  @override
  String get aBackupHolds =>
      'Una copia de seguridad guarda cada perfil con sus canales, bloques, anuncios y ajustes, y se crea cada día que algo cambia. Nunca incluye contraseñas de inicio de sesión.';

  @override
  String lastBackup(Object toLocal, Object kindLabel) {
    return 'Última copia: $toLocal ($kindLabel).';
  }

  @override
  String get noBackupsYet => 'Todavía no hay copias.';

  @override
  String itCantBe(Object toLocal, Object kindLabel) {
    return '$toLocal · $kindLabel. No se podrá recuperar.';
  }

  @override
  String get deleteThisBackup => '¿Eliminar esta copia de seguridad?';

  @override
  String couldntSaveThe(Object e) {
    return 'No se pudo guardar la copia de seguridad: $e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'Eso no funcionó: $e';
  }

  @override
  String get aNewChannel =>
      'Un canal nuevo no emite fuera del bloque, como un canal que cierra por la noche.';

  @override
  String get aNewChannelJust => 'Un canal nuevo solo para este bloque';

  @override
  String get moveOkChoose => '▲▼ Mover    OK Elegir    ESC Atrás';

  @override
  String get chooseAChannel2 => 'Elegir un canal';

  @override
  String episodes(Object keyCount) {
    return 'Episodios: $keyCount';
  }

  @override
  String get moveOkAdd => '▲▼ Mover    OK Añadir    ESC Atrás';

  @override
  String get addAShow2 => 'Añadir una serie';

  @override
  String get remove => 'Quitar';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodios',
      one: '$count episodio',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ Mes';

  @override
  String get day => '+ Día';

  @override
  String get day2 => '− Día';

  @override
  String get month2 => '− Mes';

  @override
  String get save => 'Guardar';

  @override
  String get everyDay => 'Todos los días';

  @override
  String get weekends => 'Fines de semana';

  @override
  String get weekdays => 'Días laborables';

  @override
  String get days => 'DÍAS';

  @override
  String get starts => 'Empieza';

  @override
  String get time => 'HORA';

  @override
  String get premieresAreOff => 'Los estrenos están desactivados';

  @override
  String get premieresAreOn => 'Los estrenos están activados';

  @override
  String get onTheAir => 'EN EMISIÓN';

  @override
  String get episodesAddedTo =>
      'Los episodios añadidos a tu servidor en las últimas dos semanas se estrenan en una franja nocturna en el canal de su serie: un episodio nuevo por serie cada noche, hasta dos horas, marcado como NUEVO. Los bloques de programación van primero.';

  @override
  String get moveOkSelectEscCancel =>
      '▲▼◀▶ Mover    OK Seleccionar    ESC Cancelar';

  @override
  String get newEpisodePremieres => 'Estrenos de episodios nuevos';

  @override
  String get theChannelGoes =>
      'El canal vuelve a su programación habitual en estos horarios.';

  @override
  String delete2(Object title) {
    return '¿Eliminar «$title»?';
  }

  @override
  String get addAnotherShow => 'Añadir otra serie';

  @override
  String get missingShow => 'Serie no encontrada';

  @override
  String runsThenStarts(Object start) {
    return 'Dura $start y luego vuelve a empezar.';
  }

  @override
  String get fillsTheBlock => 'Llena el bloque.';

  @override
  String longerThanThe(Object end, Object title) {
    return 'Más largo que el bloque: termina a las $end y corta $title.';
  }

  @override
  String get onTheAirNow => 'EN EMISIÓN AHORA';

  @override
  String nextAiring(Object start) {
    return 'PRÓXIMA EMISIÓN · $start';
  }

  @override
  String inAll(Object runtime) {
    return '$runtime en total';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies películas',
      one: '$movies película',
    );
    return '$_temp0';
  }

  @override
  String shows(int showsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      showsCount,
      locale: localeName,
      other: '$showsCount series',
      one: '$showsCount serie',
    );
    return '$_temp0';
  }

  @override
  String get nothingYetChoose => 'Nada todavía. Elige series o películas.';

  @override
  String get nothingYetAdd => 'Nada todavía. Añade series a la parrilla.';

  @override
  String get plays => 'REPRODUCE';

  @override
  String onLabel(Object number, Object name) {
    return 'En $number $name';
  }

  @override
  String get noChannelChosen => 'Ningún canal elegido';

  @override
  String get onANew => 'En un canal nuevo (sin emisión el resto del tiempo)';

  @override
  String get untitledBlock => 'Bloque sin título';

  @override
  String get deleteBlock => 'Eliminar bloque';

  @override
  String get blockIsOff => 'El bloque está desactivado';

  @override
  String get blockIsOn => 'El bloque está activado';

  @override
  String get onlyShowsAnd =>
      'Solo series y películas con esta clasificación o superior. Las que no tienen clasificación se excluyen.';

  @override
  String get anyRating => 'Cualquier clasificación';

  @override
  String get minimumRating => 'Clasificación mínima';

  @override
  String get chooseShowsMovies => 'Elegir series y películas';

  @override
  String get showsAndMovies =>
      'Series y películas que elijas, en orden o al azar.';

  @override
  String get yourShowsIn =>
      'Tus series en este orden, cada una con su siguiente episodio en cada emisión. Si sobra tiempo, la parrilla vuelve a empezar.';

  @override
  String get aLineup => 'Una parrilla';

  @override
  String get aMix => 'Una mezcla';

  @override
  String get whatItPlays => 'QUÉ REPRODUCE';

  @override
  String get repeatsEveryYear => 'Se repite cada año.';

  @override
  String get to => 'Hasta';

  @override
  String get from => 'Desde';

  @override
  String get onlyBetweenDates => 'Solo entre fechas';

  @override
  String get allYear => 'Todo el año';

  @override
  String get dates => 'FECHAS';

  @override
  String get nextDay => ' (día siguiente)';

  @override
  String get ends => 'Termina';

  @override
  String get channel => 'CANAL';

  @override
  String get saturdayMorningCartoons => 'Dibujos del sábado por la mañana';

  @override
  String get title => 'Título';

  @override
  String get newProgrammingBlock => 'Bloque de programación nuevo';

  @override
  String get newLateNight => 'Bloque nocturno nuevo';

  @override
  String get editProgrammingBlock => 'Editar bloque de programación';

  @override
  String next(Object next, Object next2) {
    return 'Siguiente: $next $next2';
  }

  @override
  String get onTheAirNow2 => 'En emisión ahora';

  @override
  String get noUpcomingAirings => 'Sin próximas emisiones';

  @override
  String get itsChannelIs => 'Su canal ya no existe. Elige uno nuevo.';

  @override
  String get turnedOff => 'Desactivado';

  @override
  String get blocksTakeOver =>
      'Los bloques toman el control de un canal los días y a las horas que elijas, como los dibujos del sábado por la mañana. Cada emisión continúa donde lo dejó la anterior.';

  @override
  String get moveOkEdit => '▲▼ Mover    OK Editar    ESC Atrás';

  @override
  String get programmingBlocks => 'Bloques de programación';

  @override
  String get newlyAddedEpisodes =>
      'Episodios añadidos recientemente, en el canal de su serie';

  @override
  String get onLabel2 => 'Activado';

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
  String get n100MinMovie => 'Película de 100 min';

  @override
  String get n44MinDrama => 'Drama de 44 min';

  @override
  String get n22MinSitcom => 'Comedia de 22 min';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: ', $midCount pausas incluidas',
      one: ', $midCount pausa incluida',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name: sin pausas';
  }

  @override
  String get openAndClose =>
      'Abren y cierran las pausas, de grupos configurados como Cortinillas';

  @override
  String get bumpers2 => 'CORTINILLAS';

  @override
  String get toTheHalf => 'A la media hora';

  @override
  String get toTheHour => 'A la hora en punto';

  @override
  String get padsEachSlot =>
      'Rellena cada franja hasta la hora, para que los programas empiecen a tiempo';

  @override
  String get tail2 => 'RELLENO';

  @override
  String get afterEachProgram => 'Después de cada programa';

  @override
  String get postRoll2 => 'POST-ROLL';

  @override
  String get length => 'Duración';

  @override
  String get every => 'Cada';

  @override
  String min(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get breaksInsideShows =>
      'Pausas dentro de series y películas, en finales de acto si se detectan';

  @override
  String get midRoll2 => 'MID-ROLL';

  @override
  String get beforeEachProgram => 'Antes de cada programa';

  @override
  String get preRoll2 => 'PRE-ROLL';

  @override
  String get onePool => 'Un grupo…';

  @override
  String get allBumperPools => 'Todos los grupos de cortinillas';

  @override
  String get none => 'Ninguno';

  @override
  String clipsFrom(Object pool) {
    return 'Clips de: $pool';
  }

  @override
  String get allPools => 'Todos los grupos';

  @override
  String clips2(Object label) {
    return 'Clips de $label';
  }

  @override
  String get leave => 'Salir';

  @override
  String get yourChangesTo =>
      'Se perderán tus cambios en los ajustes de pausas.';

  @override
  String get leaveWithoutSaving => '¿Salir sin guardar?';

  @override
  String get size => 'Tamaño';

  @override
  String get captions => 'Subtítulos';

  @override
  String get sampleCaption => 'Subtítulo de muestra';

  @override
  String get theServerDraws =>
      'El servidor dibuja estos subtítulos en la imagen, así que su tamaño no se puede cambiar aquí.';

  @override
  String get findingSubtitles => 'Buscando subtítulos…';

  @override
  String get noSubtitlesFor => 'No hay subtítulos para este programa';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours h $inMinutes min';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed días';
  }

  @override
  String get theChannelGoesAway =>
      'El canal desaparece, junto con sus bloques de programación y sus puestos en los grupos de canales.';

  @override
  String remove2(Object name) {
    return '¿Quitar «$name»?';
  }

  @override
  String contentOf(Object name) {
    return 'Contenido de $name';
  }

  @override
  String get newChannel => 'Canal nuevo';

  @override
  String get defaultCard => 'Tarjeta predeterminada';

  @override
  String get changeOfflineImage => 'Cambiar imagen sin emisión…';

  @override
  String get offlineImage2 => 'Imagen sin emisión…';

  @override
  String fillerPool(Object poolName) {
    return 'Grupo de relleno: $poolName';
  }

  @override
  String get slotLength => 'DURACIÓN DE FRANJA';

  @override
  String get hideFromGuide => 'Ocultar en la guía';

  @override
  String get showInGuide => 'Mostrar en la guía';

  @override
  String get favorite => 'Favorito';

  @override
  String get unfavorite => 'Quitar de favoritos';

  @override
  String mainSetting(Object label) {
    return 'Ajuste principal ($label)';
  }

  @override
  String get channelLogo => 'LOGOTIPO DEL CANAL';

  @override
  String breaksOn(Object name) {
    return 'Pausas en $name';
  }

  @override
  String get custom2 => 'Personalizado…';

  @override
  String get commercials2 => 'ANUNCIOS';

  @override
  String get removeChannel => 'Quitar canal';

  @override
  String get reshuffle => 'Volver a mezclar';

  @override
  String get editContent => 'Editar contenido';

  @override
  String get number => 'Número +';

  @override
  String get number2 => 'Número −';

  @override
  String get sourcesLogo => 'Logotipo de la fuente';

  @override
  String get changeIcon => 'Cambiar icono';

  @override
  String get rename => 'Renombrar';

  @override
  String get channelName => 'Nombre del canal';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount bloques de programación',
      one: '$blockCount bloque de programación',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return 'se repite cada $loop';
  }

  @override
  String programs(Object playlistCount) {
    return 'Programas: $playlistCount';
  }

  @override
  String get programmingBlocksOnly => 'Solo bloques de programación';

  @override
  String channelThere(Object n) {
    return 'canal $n allí';
  }

  @override
  String channel2(Object number) {
    return 'CANAL $number';
  }

  @override
  String get noChannelsYet => 'Todavía no hay canales';

  @override
  String get guideRange => 'ALCANCE DE LA GUÍA';

  @override
  String get channelsEditOk =>
      '▲▼ Canales    ▶ Editar    OK Seleccionar    ESC Atrás';

  @override
  String get channelsIcons => 'Canales e iconos';

  @override
  String get howFarAhead => 'Hasta dónde muestra la guía a partir de ahora.';

  @override
  String hours(Object hours) {
    return '$hours horas';
  }

  @override
  String get theChannelLogo =>
      'El logotipo del canal en la esquina de la imagen, en la TV y en la exportación de TV en directo.';

  @override
  String get name => 'Nombre';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'CANALES';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String group(Object name) {
    return 'Grupo: $name';
  }

  @override
  String get deleteGroup => 'Eliminar grupo';

  @override
  String get itsTabLeaves =>
      'Su pestaña sale de la guía. Los canales siguen en tu parrilla.';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount canales',
      one: '$membersCount canal',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => 'Canales que elegiste.';

  @override
  String get theTabsAt =>
      'Las pestañas de la parte superior de la guía, en este orden. Las pestañas ocultas y sin canales no se muestran.';

  @override
  String get channelGroups => 'Grupos de canales';

  @override
  String get shown => 'Visible';

  @override
  String get down => 'Bajar';

  @override
  String get up => 'Subir';

  @override
  String get automatic2 => '· automático';

  @override
  String channels4(Object channelIdsCount) {
    return '· Canales: $channelIdsCount';
  }

  @override
  String get create => 'Crear';

  @override
  String get commercialsNeverShow =>
      'Los anuncios nunca aparecen en el historial de tu servidor.';

  @override
  String get theSameAds => 'Los mismos anuncios se emiten para todos, siempre.';

  @override
  String get bumperPoolsClips =>
      'Los clips de los grupos de cortinillas abren y cierran las pausas, y nunca se emiten como anuncios.';

  @override
  String get howBreaksWork => 'CÓMO FUNCIONAN LAS PAUSAS';

  @override
  String get withATail =>
      'Con relleno, las franjas se completan hasta la hora.';

  @override
  String get adsShrinkTo =>
      'Los anuncios se ajustan a la franja, y ninguna pausa supera los 5 minutos.';

  @override
  String get aShortBreak =>
      'Una pausa corta antes del programa, una pausa cada 10 minutos durante él (12 en películas), en finales de acto si se detectan, y el resto al final.';

  @override
  String get pickAutomaticFor =>
      'Elige Automático para pausas como en la televisión, o Personalizado para configurarlas tú.';

  @override
  String workingOn(Object current) {
    return 'Trabajando en $current…';
  }

  @override
  String get analysis => 'ANÁLISIS';

  @override
  String couldNotBe(Object failed) {
    return '$failed no se pudieron analizar (se reintentará si el archivo cambia)';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'Programas con puntos de pausa: $programsDone de $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return 'Videos largos divididos: $reelsDone de $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders carpetas  ·  $idCount',
      one: '$folders carpeta  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$clips de $used grupos de anuncios.',
      one: '$clips de $used grupo de anuncios.',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'Las pausas empiezan cuando un grupo tiene clips. Añade a un grupo carpetas con videos.';

  @override
  String get breaksStartOnceA =>
      'Las pausas empiezan cuando un grupo tiene clips. Sus videos largos se están dividiendo ahora.';

  @override
  String get breaksStartOnceAPool =>
      'Las pausas empiezan cuando un grupo tiene clips. Crea un grupo abajo.';

  @override
  String breaksAreOff(Object clips) {
    return 'Las pausas están desactivadas. $clips listos en tus grupos.';
  }

  @override
  String get breaksAreOff2 => 'Las pausas están desactivadas.';

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
    return 'Falló el último análisis: $syncError';
  }

  @override
  String get newPool => 'Grupo nuevo';

  @override
  String get pickTheFolders =>
      'Elige las carpetas de tu servidor que contienen anuncios y cortinillas. Sus videos salen de tus canales habituales y llenan las pausas. Configura el tipo de un grupo como Cortinillas para que sus clips abran y cierren las pausas.';

  @override
  String get pools => 'GRUPOS';

  @override
  String get breakSettings => 'Ajustes de pausas…';

  @override
  String get commercialBreaks => 'PAUSAS PUBLICITARIAS';

  @override
  String get breakSettings2 => 'Ajustes de pausas';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count Los puntos de pausa también caen de forma más natural con él.';
  }

  @override
  String waiting(Object waiting) {
    return ' ($waiting en espera).';
  }

  @override
  String get longCommercialVideos =>
      'Los videos largos de anuncios sin capítulos no se pueden dividir en este dispositivo';

  @override
  String get installFfmpegTo =>
      'Instala ffmpeg para dividir videos largos de anuncios';

  @override
  String get picturesOnThis =>
      'Imágenes de este dispositivo, las más recientes primero. Las grandes se reducen a 512 px.';

  @override
  String get noPicturesOn =>
      'Todavía no hay imágenes en este dispositivo. Copia un PNG o JPG en su carpeta Download o en una memoria USB e inténtalo de nuevo.';

  @override
  String get lookingForPictures => 'Buscando imágenes…';

  @override
  String get couldntReadThePictures =>
      'No se pudieron leer las imágenes de este dispositivo.';

  @override
  String get nightingaleTvIsnt =>
      'Nightingale TV no tiene permiso para ver las imágenes de este dispositivo. Permite «Fotos y videos» en Ajustes de Android › Aplicaciones › Nightingale TV › Permisos e inténtalo de nuevo.';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ Mover    OK Elegir    ESC Cancelar';

  @override
  String get chooseAPicture => 'Elegir una imagen';

  @override
  String thePoolHasnt(Object error) {
    return '$error  El grupo no ha cambiado.';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  No ha cambiado nada.';
  }

  @override
  String get couldntReachTheServer => 'No se pudo acceder al servidor';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get nothingInside => 'Vacío';

  @override
  String get noMovies => 'Sin películas';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount dentro';
  }

  @override
  String get video => 'Video';

  @override
  String collection(Object name) {
    return '$name (colección)';
  }

  @override
  String get included => 'Incluido';

  @override
  String get nothingInside2 => 'Vacío.';

  @override
  String get loadingFolders => 'Cargando carpetas…';

  @override
  String get pressOnA => 'Pulsa ▶ en una biblioteca para ver su contenido.';

  @override
  String get done => 'Listo';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount marcados';
  }

  @override
  String get nothingTickedYet =>
      'Nada marcado todavía. Marca una biblioteca para usarla entera, o ▶ para elegir su contenido.';

  @override
  String get wholeLibrary => 'Biblioteca completa';

  @override
  String get libraries => 'BIBLIOTECAS';

  @override
  String get loadingLibraries => 'Cargando bibliotecas…';

  @override
  String get moveOkTick =>
      '▲▼ Mover    OK Marcar    ▶ Abrir    ◀ Subir    ESC Cancelar';

  @override
  String foldersFor(Object poolName) {
    return 'Carpetas de $poolName';
  }

  @override
  String get chooseFolders => 'Elegir carpetas';

  @override
  String get chooseWhatPlays => 'Elige lo que se emite en este canal';

  @override
  String get endsEarly => 'Termina antes';

  @override
  String get madeFromThis =>
      'Creado a partir de las series y películas de este canal y actualizado con la biblioteca. Cambia cualquier cosa y será tuyo.';

  @override
  String get fromTheLineup => 'De la parrilla';

  @override
  String yesterday(Object t) {
    return 'ayer $t';
  }

  @override
  String today(Object t) {
    return 'hoy $t';
  }

  @override
  String behind(Object d) {
    return '$d de retraso';
  }

  @override
  String hr(Object h) {
    return '$h h';
  }

  @override
  String get underAMinute => 'menos de un minuto';

  @override
  String get noProgramming => 'Sin programación';

  @override
  String get today2 => 'HOY';

  @override
  String get tuning => 'SINTONIZANDO…';

  @override
  String get offAir2 => 'SIN EMISIÓN';

  @override
  String get noSignal => 'SIN SEÑAL';

  @override
  String left(Object now) {
    return 'Quedan $now';
  }

  @override
  String get nothingScheduled => 'Nada programado';

  @override
  String get back => 'Atrás';

  @override
  String get sleep => 'Dormir';

  @override
  String get menu => 'Menú';

  @override
  String get nightingaleTvGuide => 'GUÍA DE NIGHTINGALE TV';

  @override
  String nowPlaying(Object title) {
    return 'Reproduciendo: $title';
  }

  @override
  String get mMenu => 'M Menú';

  @override
  String get escBackTo => 'ESC Volver a la TV';

  @override
  String get channelsTabsTime =>
      '▲▼ Canales     ▲ Pestañas     ◀▶ Hora     OK Ver     ';

  @override
  String get color => 'Color';

  @override
  String get channelsUsingIt =>
      'Los canales que lo usan vuelven a un icono predeterminado.';

  @override
  String get deleteThisIcon => '¿Eliminar este icono?';

  @override
  String get uploadImage => 'Subir imagen…';

  @override
  String get pngJpgWebp =>
      'PNG, JPG, WebP, GIF o SVG. Las imágenes grandes se reducen automáticamente a 512 px.';

  @override
  String get genericBadgesOnly =>
      'Solo insignias genéricas. Sube un logotipo real de cadena en «Mis iconos».';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'Usar esta insignia';

  @override
  String get preview => 'Vista previa';

  @override
  String get shape => 'Forma';

  @override
  String get callLettersUp => 'Siglas (hasta 5)';

  @override
  String iconFor(Object name) {
    return 'Icono de $name';
  }

  @override
  String get couldntReadThat => 'No se pudo leer esa imagen. Prueba con otra.';

  @override
  String get myIcons => 'Mis iconos';

  @override
  String get showLogos => 'Logotipos de series';

  @override
  String get badges => 'Insignias';

  @override
  String get builtIn => 'Integrados';

  @override
  String get couldntMoveThe => 'No se pudo trasladar la configuración';

  @override
  String get send => 'Enviar';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'Esto guarda ahora una copia de tus perfiles, canales y ajustes y los abre en $counterpartName, que pregunta antes de restaurarlos. Aquí no cambia nada.';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return '¿Enviar tu configuración a $counterpartName?';
  }

  @override
  String get parentalControls => 'Control parental';

  @override
  String get notNow => 'Ahora no';

  @override
  String bringMySetup(Object counterpartName) {
    return 'Traer mi configuración desde $counterpartName';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return 'Trasladar mi configuración a $counterpartName';
  }

  @override
  String get uninstallingEitherOne =>
      'Si desinstalas cualquiera de las dos antes de trasladar la configuración que quieres conservar, esa configuración se elimina.';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName y $counterpartName son apps independientes, cada una con sus propios perfiles, canales y ajustes.';
  }

  @override
  String get thankYouFor => '¡Gracias por apoyar Nightingale TV!';

  @override
  String isAlsoOn(Object counterpartName) {
    return '$counterpartName también está en este dispositivo';
  }

  @override
  String get aboutThisInstall => 'SOBRE ESTA INSTALACIÓN';

  @override
  String couldntOpen(Object counterpartName) {
    return 'No se pudo abrir $counterpartName.';
  }

  @override
  String get nothingIsSet =>
      'Todavía no hay nada configurado aquí, así que no hay configuración que trasladar.';

  @override
  String yourSetupIs(Object counterpartName) {
    return 'Tu configuración va de camino a $counterpartName';
  }

  @override
  String get guide => 'GUÍA';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n de $keysCount';
  }

  @override
  String get saving => 'Guardando…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$_checkedCount de $total elegidos';
  }

  @override
  String get channelOrGroup => 'Nombre de canal o grupo';

  @override
  String get search => 'Buscar';

  @override
  String get moveOkCheck => '▲▼ Mover    OK Marcar    ESC Atrás';

  @override
  String chooseChannels(Object name) {
    return 'Elegir canales: $name';
  }

  @override
  String get add => 'Añadir';

  @override
  String get readingThePlaylist => 'Leyendo la lista…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return 'Ahora: la guía de la lista, $guideUrl';
  }

  @override
  String get leaveEmptyTo =>
      'Déjalo vacío para usar la guía que indica la lista';

  @override
  String get xmltvGuideAddress => 'Dirección de la guía XMLTV';

  @override
  String get guideOptional => 'GUÍA (OPCIONAL)';

  @override
  String get httpProviderExample =>
      'http://proveedor.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'Dirección de la lista';

  @override
  String get playlist => 'LISTA';

  @override
  String get myIptv => 'Mi IPTV';

  @override
  String get useAnAddress => 'Usar una dirección en su lugar';

  @override
  String get chooseAFile => 'Elegir un archivo';

  @override
  String get chooseAnotherFile => 'Elegir otro archivo';

  @override
  String get moveOkSelectEscBack => '▲▼ Mover    OK Seleccionar    ESC Atrás';

  @override
  String edit(Object name) {
    return 'Editar $name';
  }

  @override
  String get addAnM3u => 'Añadir una lista M3U';

  @override
  String get m3uPlaylists => 'Listas M3U';

  @override
  String get xmltvGuides => 'Guías XMLTV';

  @override
  String get anIptvPlaylist =>
      'Una lista IPTV (dirección web o archivo), con una guía XMLTV si la tienes.';

  @override
  String get theChannelsAnd =>
      'Los canales y la guía del sintonizador de tu servidor (antena, decodificador o IPTV).';

  @override
  String readingSChannels(Object server) {
    return 'Leyendo los canales de $server…';
  }

  @override
  String checkingLiveTv(Object server) {
    return 'Comprobando la TV en directo de $server…';
  }

  @override
  String get addALive => 'Añadir una fuente de TV en directo';

  @override
  String get itsChannelsLeave =>
      'Sus canales salen de la guía, de sus grupos y de favoritos.';

  @override
  String get renameSource => 'Renombrar fuente';

  @override
  String get edit2 => 'Editar';

  @override
  String get refreshNow => 'Actualizar ahora';

  @override
  String get chooseChannels2 => 'Elegir canales';

  @override
  String get playlistFile => 'Archivo de lista';

  @override
  String get notRefreshedYet => 'Sin actualizar todavía';

  @override
  String refreshed(Object lastRefresh) {
    return 'Actualizado $lastRefresh';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return 'Falló la última actualización: $lastError';
  }

  @override
  String get refreshing => 'Actualizando…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · Canales: $keyCount de $channelsCount';
  }

  @override
  String get noSourcesYet => 'Todavía no hay fuentes.';

  @override
  String get addSource => 'Añadir fuente';

  @override
  String get realBroadcastsAnd =>
      'Emisiones reales e IPTV en tu guía: la TV en directo de tu servidor o una lista M3U con guía XMLTV. Sus canales se suman a la parrilla después de los tuyos.';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return 'Sin emitir. $runningCount de $streamLimit emisiones en uso.';
  }

  @override
  String get savePort => 'Guardar puerto';

  @override
  String get port => 'Puerto';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'Sintonizador';

  @override
  String get enterAPort => 'Introduce un número de puerto.';

  @override
  String pinFor(Object name) {
    return 'PIN de $name';
  }

  @override
  String get letPlexFind => 'Dejar que Plex lo encuentre automáticamente';

  @override
  String get discovery => 'DETECCIÓN';

  @override
  String get encoder => 'CODIFICADOR';

  @override
  String nowAtOnce(Object streamLimit) {
    return 'Ahora: $streamLimit a la vez. Cada canal que se ve en otro lugar es una emisión.';
  }

  @override
  String get streamsAtOnce => 'EMISIONES A LA VEZ';

  @override
  String get quality => 'CALIDAD';

  @override
  String get lineups => 'PARRILLAS';

  @override
  String get liveTvExport2 => 'Exportación de TV en directo';

  @override
  String get automaticDiscoveryIsnt =>
      'La detección automática no está disponible en este PC. Añade el sintonizador en Plex o Jellyfin por su dirección.';

  @override
  String get anyoneOnYour =>
      'Cualquiera en tu red doméstica puede ver esta parrilla.';

  @override
  String get watchYourChannels =>
      'Mira tus canales en Plex, Jellyfin o cualquier app IPTV en tu red doméstica. Nightingale TV tiene que seguir abierta para que se reproduzcan.';

  @override
  String get offline => 'Sin conexión';

  @override
  String get online => 'Conectado';

  @override
  String get added => 'Añadido';

  @override
  String get chooseAServer => 'Elegir un servidor';

  @override
  String get whosSigningIn => '¿Quién inicia sesión?';

  @override
  String get openPlexTv => 'Abrir plex.tv/link';

  @override
  String get waitingForThe => 'Esperando a que se vincule el código…';

  @override
  String get goToPlex =>
      'Ve a plex.tv/link en tu teléfono u ordenador e introduce este código.';

  @override
  String get signInWith => 'Iniciar sesión con Plex';

  @override
  String get waitingForApproval => 'Esperando aprobación…';

  @override
  String onYourPhone(Object label) {
    return 'En tu teléfono u ordenador, abre $label → tu perfil → Quick Connect e introduce este código:';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get password => 'Contraseña';

  @override
  String get username => 'Usuario';

  @override
  String signInTo2(Object name) {
    return 'Iniciar sesión en $name';
  }

  @override
  String get differentServer => 'Otro servidor';

  @override
  String get signInWithPassword => 'Iniciar sesión con contraseña';

  @override
  String get quickConnectUse => 'Quick Connect (con tu teléfono)';

  @override
  String get connect => 'Conectar';

  @override
  String get serverAddress => 'Dirección del servidor';

  @override
  String get connectToYour => 'Conéctate a tu servidor';

  @override
  String get nightingaleTvTurns =>
      'Nightingale TV convierte tu biblioteca de Jellyfin, Emby o Plex en canales siempre en emisión con guía de programación. Haz zapping y mira lo que haya.';

  @override
  String get yourLibraryOn => 'Tu biblioteca.\nEn emisión, 24/7.';

  @override
  String get welcomeToNightingale => 'Te damos la bienvenida a Nightingale TV';

  @override
  String signInFor(Object name) {
    return 'Iniciar sesión para $name';
  }

  @override
  String signInToAgain(Object name) {
    return 'Volver a iniciar sesión en $name';
  }

  @override
  String get addAServer => 'Añadir un servidor';

  @override
  String foundNewPrograms(Object list) {
    return 'Se encontró: $list. Los programas nuevos se emiten en sus canales justo después de lo que hay ahora.';
  }

  @override
  String get libraryRefreshed => 'Biblioteca actualizada';

  @override
  String get nothingNew => 'Nada nuevo';

  @override
  String get yourChannelsAre => 'Tus canales están al día.';

  @override
  String get refreshFailed => 'Falló la actualización';

  @override
  String get moveOkSelectEscBackTo =>
      '▲▼ Mover    OK Seleccionar    ESC Volver a la TV';

  @override
  String get noPoolsYet => 'todavía no hay grupos';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return 'Actualizado el $fetchedAt a las $fetchedAt2';
  }

  @override
  String get libraryLabel => 'BIBLIOTECA';

  @override
  String get account => 'CUENTA';

  @override
  String get watching => 'VIENDO';

  @override
  String get exitNightingaleTv => 'Salir de Nightingale TV';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get yourChannelLineup =>
      'Tu parrilla de canales se borra. Los iconos personalizados se conservan.';

  @override
  String get signOut2 => '¿Cerrar sesión?';

  @override
  String get fullScreenOn => 'Pantalla completa sí/no (F11)';

  @override
  String get nothingWasReset => 'No se restableció nada';

  @override
  String get reset => 'Restablecer';

  @override
  String get rebuildsTheDefault =>
      'Vuelve a crear los canales predeterminados a partir de tu biblioteca. Los nombres, iconos y números que cambiaste se restablecen. Los canales que añadiste se conservan. Antes se guarda una copia, para que puedas recuperarlos en Copia y restauración.';

  @override
  String get resetChannelLineup => '¿Restablecer la parrilla?';

  @override
  String get resetChannelLineup2 => 'Restablecer la parrilla';

  @override
  String get refreshLibrary => 'Actualizar biblioteca';

  @override
  String get refreshingLibrary => 'Actualizando biblioteca…';

  @override
  String get servers => 'Servidores';

  @override
  String get phoneRemote => 'Mando del teléfono';

  @override
  String get profiles => 'Perfiles';

  @override
  String get retroLook => 'Aspecto retro';

  @override
  String get playback => 'Reproducción';

  @override
  String get switchProfile => 'Cambiar de perfil';

  @override
  String get sleepTimer => 'Temporizador';

  @override
  String get backToTv => 'Volver a la TV';

  @override
  String get removeAll => 'Quitar todos';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return 'vinculado $paired · último uso $lastUsed';
  }

  @override
  String get noPhonesPaired => 'Todavía no hay teléfonos vinculados.';

  @override
  String get pairedPhones => 'TELÉFONOS VINCULADOS';

  @override
  String get blockedByThis => 'Bloqueado por el cortafuegos de este ordenador';

  @override
  String get someWiFi =>
      'Algunas redes Wi-Fi mantienen separados los dispositivos (aislamiento de AP o de clientes). Si el teléfono sigue sin conectarse, desactiva ese ajuste en tu Wi-Fi.';

  @override
  String get thePhoneHas =>
      'El teléfono tiene que estar en la misma Wi-Fi que esta TV, no en una red de invitados ni con datos móviles.';

  @override
  String get ifThePhone =>
      'Si el teléfono no se conecta, puede que el cortafuegos de este ordenador lo esté bloqueando. Abre un terminal en este ordenador y ejecuta:';

  @override
  String get checkAgain => 'Comprobar de nuevo';

  @override
  String get thenChooseCheck => 'Después elige Comprobar de nuevo.';

  @override
  String get thisComputersFirewall =>
      'El cortafuegos de este ordenador impide que los teléfonos lleguen al mando. Para permitirlos, abre un terminal en este ordenador y ejecuta:';

  @override
  String get notConfirmedYet =>
      'Sin confirmar · ningún teléfono se ha conectado';

  @override
  String get working => 'Funciona';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return 'Funciona · último uso de $name, $lastUsed';
  }

  @override
  String get theRemoteIs => 'El mando está desactivado.';

  @override
  String get orScanThe => 'o escanea el código con la cámara del teléfono.';

  @override
  String get andEnter => 'e introduce  ';

  @override
  String get onYourPhoneOpen => 'EN TU TELÉFONO, ABRE';

  @override
  String get useYourPhoneAs =>
      'Usa tu teléfono como mando: abre una página web en él para cambiar de canal, ver la guía o tocar un canal para sintonizarlo. No hay nada que instalar.';

  @override
  String get everyPairedPhone =>
      'Cada teléfono vinculado deja de funcionar como mando hasta que escanee de nuevo el código de esta pantalla.';

  @override
  String get removeAllPhones => '¿Quitar todos los teléfonos?';

  @override
  String get thoseDidntMatch => 'No coinciden. Inténtalo de nuevo.';

  @override
  String get enterTheSame => 'Introduce los mismos 4 dígitos otra vez.';

  @override
  String get choose4Digits => 'Elige 4 dígitos.';

  @override
  String get thatPinIsnt => 'Ese PIN no es correcto. Inténtalo de nuevo.';

  @override
  String get clock => 'RELOJ';

  @override
  String get captions2 => 'SUBTÍTULOS';

  @override
  String get audio => 'AUDIO';

  @override
  String get maximumStreamingBitrate => 'TASA DE BITS MÁXIMA';

  @override
  String get converting => 'CONVERSIÓN';

  @override
  String get afterThisLong =>
      'Tras este tiempo sin pulsar ningún botón, Nightingale TV pregunta si hay alguien viendo. Si nadie responde en un minuto, se duerme: la reproducción se detiene y tu servidor deja de emitir. No mientras haya un temporizador activo.';

  @override
  String get askIfIm => 'Preguntar si sigo viendo';

  @override
  String get liveTvStill => 'La TV en directo sigue apareciendo en el panel.';

  @override
  String get offWhatYou =>
      'Desactivado: lo que ves aquí nunca cambia los recuentos de reproducción, las marcas de visto ni los puntos de reanudación de tu servidor, y no aparece en su panel.';

  @override
  String get pauseSkipAnd =>
      'Pausa, salta y reinicia lo que se emite. Desactivado: cada canal sigue el horario, como la televisión continua.';

  @override
  String get pauseAndRewind => 'Pausar y rebobinar';

  @override
  String get showsTheTime => 'Muestra la hora en la esquina de la imagen.';

  @override
  String get onScreenClock => 'Reloj en pantalla';

  @override
  String get showACountdown =>
      'Muestra una cuenta atrás antes de que empiecen los anuncios y antes de que vuelva el programa.';

  @override
  String get breakNotices => 'Avisos de pausa';

  @override
  String get theSizeOf =>
      'El tamaño de los subtítulos en todos los programas y canales.';

  @override
  String get whileItsOn =>
      'Mientras esté activado, el audio envolvente (Dolby, DTS) lo decodifica este dispositivo en lugar de pasarlo a un receptor.';

  @override
  String get evensOutThe =>
      'Iguala el volumen mientras ves: los anuncios y programas fuertes bajan y los suaves suben, para que no tengas que coger el mando.';

  @override
  String get volumeLeveling => 'Nivelación de volumen';

  @override
  String get pickALower =>
      'Elige una tasa de bits más baja si los programas se cortan por Wi-Fi o en una conexión remota. Original nunca se convierte por la tasa de bits.';

  @override
  String get connectedThroughPlex =>
      'Conectado mediante Plex Relay: la calidad es limitada.';

  @override
  String get offNightingaleTv =>
      'Desactivado: Nightingale TV siempre reproduce tus archivos originales con toda su calidad y tu servidor no hace trabajo extra. Activado: tu servidor convierte una serie o película solo si supera la tasa máxima o si el archivo original no se reproduce. La conversión usa el procesador o la tarjeta gráfica de tu servidor. Los anuncios siempre reproducen los archivos originales.';

  @override
  String get transcodeOnlyIf => 'Convertir solo si hace falta (experimental)';

  @override
  String get longerVideosAd =>
      'Los videos más largos (recopilaciones de anuncios) se dividen en sus anuncios, en los capítulos o donde la imagen pasa a negro y silencio.';

  @override
  String get videosOf5 =>
      'Los videos de 5 segundos a 3 minutos son un clip cada uno.';

  @override
  String get commercialsFillBreaks =>
      'Los anuncios llenan las pausas. Configura el tipo como Cortinillas para identidades de canal y clips de «volvemos enseguida».';

  @override
  String get bumpersTakeAt =>
      'Las cortinillas ocupan como máximo la mitad de una pausa, salvo en un pre-roll. Se omite la que sea demasiado larga.';

  @override
  String stillToSplit(Object unsplit) {
    return '$unsplit por dividir';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount largos divididos en clips',
      one: '$reelsCount largo dividido en clips',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'Eliminar grupo';

  @override
  String get addFolders => 'Añadir carpetas…';

  @override
  String get libraryLabel2 => 'Biblioteca';

  @override
  String get noFoldersYet => 'Todavía no hay carpetas.';

  @override
  String get folders2 => 'CARPETAS';

  @override
  String get type => 'TIPO';

  @override
  String get poolName => 'Nombre del grupo';

  @override
  String get commercialPool => 'Grupo de anuncios';

  @override
  String get itsVideosGo =>
      'Sus videos vuelven a tus canales habituales. Las pausas que los usaban pasan a usar todos los grupos.';

  @override
  String get now => 'Ahora';

  @override
  String get watch => 'Ver';

  @override
  String get tuning2 => 'Sintonizando…';

  @override
  String get fullScreen => 'Pantalla completa';

  @override
  String get noChannels => 'Sin canales';

  @override
  String get theirChannelsProgramming =>
      'Se eliminan sus canales, bloques de programación y ajustes, y esta TV cierra la sesión de su servidor.';

  @override
  String delete3(Object name) {
    return '¿Eliminar $name?';
  }

  @override
  String get giveTheProfile => 'Ponle un nombre al perfil.';

  @override
  String get deleteProfile => 'Eliminar perfil';

  @override
  String get removePin => 'Quitar PIN';

  @override
  String get setAPin => 'Definir un PIN';

  @override
  String get changePin => 'Cambiar PIN';

  @override
  String get noPinAnyone => 'Sin PIN. Cualquiera puede abrir este perfil.';

  @override
  String get lockedThePin =>
      'Bloqueado. Se necesita el PIN para abrir este perfil.';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith =>
      'Las series y películas sin clasificación se excluyen.';

  @override
  String get allowedToWatch => 'PUEDE VER';

  @override
  String get kid => 'Niño';

  @override
  String get grownUp => 'Adulto';

  @override
  String get whoItsFor => 'PARA QUIÉN ES';

  @override
  String get color2 => 'COLOR';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get newProfile => 'Perfil nuevo';

  @override
  String get watchingNow => 'Viendo ahora';

  @override
  String get noPin => 'Sin PIN';

  @override
  String get pinLocked => 'Bloqueado con PIN';

  @override
  String kid2(Object label, Object description) {
    return 'Niño · $label ($description)';
  }

  @override
  String get addProfile => 'Añadir perfil';

  @override
  String get everyoneGetsTheir =>
      'Cada persona tiene su propio inicio de sesión, canales y bloques de programación. Los perfiles infantiles solo ven series y películas aptas para su edad.';

  @override
  String enterSPin(Object name) {
    return 'Introduce el PIN de $name';
  }

  @override
  String get whosWatching => '¿Quién está viendo?';

  @override
  String get moveOkChoose2 => '◀▶ Mover    OK Elegir';

  @override
  String get enterAGrownUps => 'Introduce el PIN de un adulto.';

  @override
  String get grownUpsOnly => 'Solo adultos';

  @override
  String get yourChannelYour => 'Tu canal, tu aspecto';

  @override
  String get testPattern => 'Carta de ajuste';

  @override
  String get upNext8 => 'A CONTINUACIÓN  ·  20:00';

  @override
  String get thisDevice => 'ESTE DISPOSITIVO';

  @override
  String get glow => 'BRILLO';

  @override
  String get curvature => 'CURVATURA';

  @override
  String get vignette => 'VIÑETA';

  @override
  String get mask => 'MÁSCARA';

  @override
  String get lines => 'LÍNEAS';

  @override
  String get scanlines => 'LÍNEAS DE ESCANEO';

  @override
  String get customCrtStyle => 'ESTILO CRT PERSONALIZADO';

  @override
  String accent(Object label) {
    return 'ACENTO ($label)';
  }

  @override
  String get overlayTheme => 'TEMA DE SUPERPOSICIÓN';

  @override
  String get crtEffect => 'EFECTO CRT';

  @override
  String get surround => 'ENTORNO';

  @override
  String get pictureShape => 'FORMA DE IMAGEN';

  @override
  String get surroundImage => 'Imagen de entorno';

  @override
  String get notAvailableOn => 'No disponible en este dispositivo';

  @override
  String get offTurnsOff =>
      'Desactivado apaga todos los efectos CRT solo en este dispositivo. La forma de imagen, el entorno y los temas de superposición no cambian.';

  @override
  String get effectsOnThis => 'Efectos en este dispositivo';

  @override
  String get retroLook2 => 'ASPECTO RETRO';

  @override
  String get theseSettingsApply =>
      'Estos ajustes se aplican en las pantallas que ejecutan la app. No se aplican a la exportación de TV en directo.';

  @override
  String get sameAsThe => 'Igual que el perfil';

  @override
  String get streamsFromThis =>
      'Las emisiones de este servidor se mantienen por debajo de esto. El límite del propio perfil (Reproducción) sigue vigente: gana el más bajo.';

  @override
  String qualityLimit(Object name) {
    return 'Límite de calidad · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      'Sus programas salen de tus canales, que conservan sus números. Las fuentes y carpetas de anuncios que estén en él aparecen como no encontradas hasta que las cambies.';

  @override
  String remove3(Object name) {
    return '¿Quitar $name?';
  }

  @override
  String get signingOutOf =>
      'Cerrar la sesión de este perfil cambia su servidor principal.';

  @override
  String signedInAs(Object user) {
    return 'Sesión iniciada como $user';
  }

  @override
  String get mainServer => 'Servidor principal';

  @override
  String get qualityLimit2 => 'Límite de calidad';

  @override
  String get moveDown => 'Bajar';

  @override
  String get moveUp => 'Subir';

  @override
  String get signInAgain => 'Volver a iniciar sesión';

  @override
  String get programsFromEvery =>
      'Los programas de todos los servidores se unen en una sola parrilla. Un título presente en varios servidores se reproduce desde el primero de esta lista que responda (Reproducir desde); si deja de responder, toma el relevo el siguiente.';

  @override
  String get sleepingPressAny => 'Durmiendo · Pulsa cualquier botón para ver';

  @override
  String goingToSleep(Object seconds) {
    return 'Durmiendo en $seconds';
  }

  @override
  String get goingToSleep2 => 'Se va a dormir';

  @override
  String goingToSleepIn(Object hint) {
    return 'Durmiendo en 1 minuto. $hint';
  }

  @override
  String get pressAnyButton => 'Pulsa cualquier botón para seguir viendo';

  @override
  String goingToSleepIn0(Object padLeft) {
    return 'Durmiendo en 0:$padLeft';
  }

  @override
  String get keepWatching => 'Seguir viendo';

  @override
  String get areYouStill => '¿Sigues viendo?';

  @override
  String sleepTimerMin(Object left) {
    return 'Temporizador · quedan $left min';
  }

  @override
  String get whatsOnNow => 'Lo que se emite ahora no tiene hora de fin fija.';

  @override
  String endOfThis(Object programEnd) {
    return 'Final de este programa · $programEnd';
  }

  @override
  String get endOfThisProgram => 'Final de este programa';

  @override
  String get moveOkToggle => '▲▼◀▶ Mover    OK Alternar    ESC Cancelar';

  @override
  String get usedWhenNo =>
      'Se usa cuando no hay series elegidas. También limita las películas.';

  @override
  String get genres2 => 'GÉNEROS';

  @override
  String get includeMovies => 'Incluir películas';

  @override
  String get add2 => 'Añadir…';

  @override
  String get notFoundOn => 'No encontrado en el servidor';

  @override
  String get collectionsFolders => 'COLECCIONES Y CARPETAS';

  @override
  String get playOrder => 'ORDEN DE REPRODUCCIÓN';

  @override
  String get clear => 'Borrar';

  @override
  String get shows2 => 'SERIES';

  @override
  String get pickSomethingTo => 'Elige algo para reproducir.';

  @override
  String everyMovie(Object genreText) {
    return 'cada película de $genreText';
  }

  @override
  String get everyMovie2 => 'cada película';

  @override
  String everyShow(Object genreText) {
    return 'cada serie de $genreText';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount o $last';
  }

  @override
  String get settingUpYour => 'Configurando tus canales';

  @override
  String get couldntLoadYour => 'No se pudo cargar tu biblioteca';

  @override
  String upNext(Object title) {
    return 'A continuación: $title';
  }

  @override
  String backTo(Object title) {
    return 'Volver a $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return 'La programación vuelve en $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabel en $left';
  }

  @override
  String startingWith(Object title) {
    return 'Empieza con $title';
  }

  @override
  String upNext2(Object start) {
    return 'A CONTINUACIÓN  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return 'Siguiente $start: $title';
  }

  @override
  String backOn(Object backOnAir) {
    return 'Vuelve $backOnAir';
  }

  @override
  String get offTheAir2 => 'Sin emisión';

  @override
  String get commercialBreak => 'Pausa publicitaria';

  @override
  String tryingAgainAt(Object end) {
    return 'Reintentando a las $end';
  }

  @override
  String get exitFullScreen => 'Salir de pantalla completa';

  @override
  String get guide2 => 'Guía';

  @override
  String thereIsNo(Object number) {
    return 'No existe el canal $number';
  }

  @override
  String get liveChannelsCant => 'Los canales en directo no se pueden pausar';

  @override
  String get curvatureAndGlow =>
      'Curvatura y brillo desactivados: este dispositivo no da abasto';

  @override
  String get pressBackAgain => 'Pulsa Atrás de nuevo para salir';

  @override
  String backAt(Object backAt) {
    return 'Vuelve a las $backAt';
  }

  @override
  String get live => 'EN DIRECTO';

  @override
  String get newLabel => 'NUEVO';

  @override
  String nowPlayingOn(Object name) {
    return 'REPRODUCIENDO EN $name';
  }

  @override
  String ch(Object padLeft) {
    return 'CANAL $padLeft';
  }

  @override
  String get paused => 'EN PAUSA';

  @override
  String get seekBar => 'Barra de reproducción';

  @override
  String get live2 => 'En directo';

  @override
  String get forward30 => 'Avanzar 30';

  @override
  String get pause => 'Pausa';

  @override
  String get play => 'Reproducir';

  @override
  String get back10 => 'Retroceder 10';

  @override
  String get restart => 'Reiniciar';

  @override
  String somethingWentWrong2(Object status) {
    return 'Algo salió mal ($status).';
  }

  @override
  String get thatIsTooBig => 'Es demasiado grande.';

  @override
  String get notFound => 'No encontrado.';

  @override
  String get youCantDo => 'No puedes hacer eso.';

  @override
  String get cantReachThe =>
      'No se puede acceder al servidor. Comprueba que esté en marcha.';

  @override
  String signOut3(Object userName) {
    return 'Cerrar sesión de $userName';
  }

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get users => 'Usuarios';

  @override
  String get backups2 => 'Copias de seguridad';

  @override
  String get serverAndSign => 'Servidor e inicio de sesión';

  @override
  String get channels5 => 'Canales';

  @override
  String get thatProfileIsntYours => 'Ese perfil no es tuyo o ya no existe.';

  @override
  String get download => 'Descargar';

  @override
  String get itReplacesThe =>
      'Reemplaza los perfiles, canales y ajustes de aquí.';

  @override
  String get restoreThisBackup => '¿Restaurar esta copia de seguridad?';

  @override
  String get backupActions => 'Acciones de copia';

  @override
  String channels6(Object profiles, Object channels, Object device) {
    return '$profiles · Canales: $channels · $device';
  }

  @override
  String get noneYetOne =>
      'Ninguna todavía. Se guarda una cada día que cambia el hogar.';

  @override
  String get savedOnThe => 'Guardadas en el servidor';

  @override
  String get restoring => 'Restaurando…';

  @override
  String get restoreFromAFile => 'Restaurar desde un archivo…';

  @override
  String get downloadABackup => 'Descargar una copia ahora';

  @override
  String get aBackupHoldsThe =>
      'Una copia de seguridad guarda los perfiles, canales, bloques, logotipos, ajustes de exportación y cuentas de usuario (nunca contraseñas ni tokens de inicio de sesión).';

  @override
  String get restoredTheBackup2 => 'Copia de seguridad restaurada.';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return 'Del $whenValue ($device): $profiles. Reemplaza los perfiles, canales y ajustes de aquí.';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return 'Próxima emisión: $start $end';
  }

  @override
  String programsInIts(Object total) {
    return 'Programas en su lista: $total';
  }

  @override
  String get workingOutWhat => 'Calculando qué reproduce…';

  @override
  String get later => 'Después';

  @override
  String get earlier => 'Antes';

  @override
  String get eachAiringPlays =>
      'Cada emisión reproduce en orden los siguientes episodios de cada puesto y vuelve a empezar si sobra tiempo.';

  @override
  String get aLineupOf => 'Una parrilla de series';

  @override
  String get whatItPlays2 => 'Qué reproduce';

  @override
  String get onlyPartOf => 'Solo parte del año';

  @override
  String get runsPastMidnight =>
      'Continúa pasada la medianoche hasta el día siguiente.';

  @override
  String get whenLabel => 'Cuándo';

  @override
  String get aNewChannelFor => 'Un canal nuevo para este bloque';

  @override
  String get channel3 => 'Canal';

  @override
  String get blocks => 'Bloques';

  @override
  String get newBlock => 'Bloque nuevo';

  @override
  String get programmingBlock => 'Bloque de programación';

  @override
  String get aBlockTakes =>
      'Un bloque toma el control de un canal a horas fijas: «Dibujos del sábado por la mañana», los sábados de 7:00 a 12:00.';

  @override
  String get overlayTheme2 => 'Tema de superposición';

  @override
  String get crtEffect2 => 'Efecto CRT';

  @override
  String get chooseSurroundImage => 'Elegir imagen de entorno…';

  @override
  String get surround2 => 'Entorno';

  @override
  String get pictureShape2 => 'Forma de imagen';

  @override
  String get chooseOfflineImage => 'Elegir imagen sin emisión…';

  @override
  String get fillerPool2 => 'Grupo de relleno';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes minutos';
  }

  @override
  String get slotLength2 => 'Duración de franja';

  @override
  String get everyProgramStarts =>
      'Cada programa empieza en punto. El relleno completa el resto de cada franja.';

  @override
  String get itLeavesThe => 'Sale de la parrilla.';

  @override
  String get itsProgrammingBlocks =>
      'También se quitan sus bloques de programación.';

  @override
  String get removeThisChannel => 'Quitar este canal';

  @override
  String get channelLogo2 => 'Logotipo del canal';

  @override
  String get editCustomBreaks => 'Editar pausas personalizadas…';

  @override
  String get musicChannelsOnlyShuffle =>
      'Los canales de música solo son aleatorios, nunca el mismo artista dos veces seguidas.';

  @override
  String get playOrder2 => 'Orden de reproducción';

  @override
  String get saveWhatIt => 'Guardar qué reproduce';

  @override
  String get canBeA =>
      'Puede ser el canal de origen de una serie para sus episodios más recientes.';

  @override
  String get hiddenFromThe => 'Oculto en la guía';

  @override
  String get chooseIcon => 'Elegir icono…';

  @override
  String get icon => 'Icono';

  @override
  String get saveNameAnd => 'Guardar nombre y número';

  @override
  String get aChannelAlready =>
      'Un canal que ya tenga ese número intercambia su puesto con este.';

  @override
  String get number3 => 'Número';

  @override
  String get nameAndNumber => 'Nombre y número';

  @override
  String get decadesNoneAny => 'Décadas (ninguna: cualquiera)';

  @override
  String get genresNoneAny => 'Géneros (ninguno: cualquiera)';

  @override
  String musicVideos(Object musicVideos) {
    return 'Videos musicales ($musicVideos)';
  }

  @override
  String songs(Object songs) {
    return 'Canciones ($songs)';
  }

  @override
  String get newMusicChannel => 'Canal de música nuevo';

  @override
  String get aNightlySlot =>
      'Una franja nocturna para los episodios más recientes de las series, en el canal de origen de cada una.';

  @override
  String get mainSettings => 'Ajustes principales';

  @override
  String get glow2 => 'Brillo';

  @override
  String get curvature2 => 'Curvatura';

  @override
  String get vignette2 => 'Viñeta';

  @override
  String get mask2 => 'Máscara';

  @override
  String get lines2 => 'Líneas';

  @override
  String get scanlines2 => 'Líneas de escaneo';

  @override
  String get customCrtStyle2 => 'Estilo CRT personalizado';

  @override
  String accent2(Object label) {
    return 'Acento ($label)';
  }

  @override
  String get hidden => 'Oculto';

  @override
  String get blockChannel2 => 'Canal de bloques';

  @override
  String live3(Object source) {
    return 'En directo · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return 'Canales: $shownCount de $channelsCount';
  }

  @override
  String get searchChannels => 'Buscar canales';

  @override
  String get resetLineup => 'Restablecer parrilla';

  @override
  String get everyChannelEdit =>
      'Se descartan todas las ediciones de canales y se vuelve a crear la parrilla predeterminada. Los canales que añadiste se conservan. Antes se guarda una copia.';

  @override
  String get musicChannel => 'Canal de música';

  @override
  String get newBlockChannel => 'Canal de bloques nuevo';

  @override
  String get channelsOwnPlans => 'Planes propios de los canales';

  @override
  String get setTypeBumpers => 'Definir tipo: Cortinillas';

  @override
  String get setTypeCommercials => 'Definir tipo: Anuncios';

  @override
  String get chooseFolders2 => 'Elegir carpetas…';

  @override
  String get plansThatDrew =>
      'Los planes que lo usaban pasan a usar todos los grupos, y sus videos vuelven a los canales.';

  @override
  String get renamePool => 'Renombrar grupo';

  @override
  String get poolActions => 'Acciones del grupo';

  @override
  String get aPoolIs =>
      'Un grupo es un conjunto de carpetas de la biblioteca cuyos videos llenan las pausas en lugar de emitirse. Su tipo indica si sus clips se emiten como anuncios o como cortinillas, que abren y cierran las pausas.';

  @override
  String get pools2 => 'Grupos';

  @override
  String get breaks => 'Pausas';

  @override
  String clipsInAll(Object clips) {
    return 'Clips en todos los grupos de anuncios: $clips';
  }

  @override
  String get tunerAddress => 'Dirección del sintonizador';

  @override
  String get changePort => 'Cambiar puerto';

  @override
  String get exportThisProfile => 'Exportar este perfil';

  @override
  String get letsPlexAnd =>
      'Permite que Plex y otros encuentren los sintonizadores en la red.';

  @override
  String get discovery2 => 'Detección';

  @override
  String get encoder2 => 'Codificador';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return 'Automático: $streamLimitInUse en este equipo.';
  }

  @override
  String get streamsAtOnce2 => 'Emisiones a la vez';

  @override
  String get quality2 => 'Calidad';

  @override
  String get settings => 'Ajustes';

  @override
  String get eachExportedProfile =>
      'Cada perfil exportado es un sintonizador para Plex, Jellyfin o Emby. Añádelo en sus ajustes de DVR por su dirección.';

  @override
  String get channelsInThis => 'Canales de este grupo';

  @override
  String get chooseChannels3 => 'Elegir canales…';

  @override
  String channels7(Object channelIds) {
    return 'Canales: $channelIds';
  }

  @override
  String get itsChannelsStay => 'Sus canales siguen en la parrilla.';

  @override
  String get renameGroup => 'Renombrar grupo';

  @override
  String get groupActions => 'Acciones del grupo';

  @override
  String get yourGroup => 'Tu grupo';

  @override
  String get theOrderOf =>
      'El orden de las pestañas de la guía y cuáles se muestran.';

  @override
  String get guideTabs => 'Pestañas de la guía';

  @override
  String get make => 'Crear';

  @override
  String get breaksBetweenPrograms => 'Pausas entre programas';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '$mids pausas incluidas',
      one: '$mids pausa incluida',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return 'Canciones: $songs';
  }

  @override
  String get newEpisode => 'Episodio nuevo';

  @override
  String get noChannelsYet2 => 'Todavía no hay canales.';

  @override
  String get noGuide => 'Sin guía';

  @override
  String get noneShown => 'Ninguno visible';

  @override
  String get allShown => 'Todos visibles';

  @override
  String channels8(Object name) {
    return '$name: canales';
  }

  @override
  String get orChooseA => 'O elige un archivo de guía…';

  @override
  String get emptyThePlaylists =>
      'Vacío: la guía propia de la lista, si indica una.';

  @override
  String get guideAddressXmltv => 'Dirección de la guía (XMLTV, opcional)';

  @override
  String get orChooseAPlaylist => 'O elige un archivo de lista…';

  @override
  String get leaveEmptyToKeep =>
      'Déjalo vacío para conservar el archivo de lista.';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'Archivos';

  @override
  String get itsChannelsJoin =>
      'Sus canales se suman mientras este perfil tenga la sesión iniciada en ese servidor.';

  @override
  String guide3(Object guideFile) {
    return 'Guía: $guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'Archivo de lista: $playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return 'Actualizado $last $context';
  }

  @override
  String get itsChannelsLeaveThe =>
      'Sus canales salen de la parrilla, los grupos y favoritos.';

  @override
  String read(Object fetched, Object context) {
    return 'Leído $fetched $context.';
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
    return 'Series: $series · Episodios: $episodes · Películas: $movies · Canciones: $songs · Videos musicales: $musicVideos · Videos de anuncios: $commercials';
  }

  @override
  String fromAs(Object server, Object user) {
    return 'De $server como $user.';
  }

  @override
  String libraryLabel3(Object name) {
    return '$name: biblioteca';
  }

  @override
  String get removeThePin => 'Quitar el PIN';

  @override
  String get pinOptional => 'PIN (opcional)';

  @override
  String get newPinLeave => 'PIN nuevo (déjalo vacío para conservarlo)';

  @override
  String colour(Object i) {
    return 'Color $i';
  }

  @override
  String get colour2 => 'Color';

  @override
  String get itsChannelsBlocks =>
      'Se eliminan sus canales, bloques y ajustes. Antes se guarda una copia.';

  @override
  String get exported => 'Exportado';

  @override
  String kid3(Object label) {
    return 'Niño · $label';
  }

  @override
  String get noProfilesAre =>
      'Todavía no tienes perfiles asignados. Pregunta a un administrador.';

  @override
  String signIn2(Object name) {
    return 'Iniciar sesión con $name';
  }

  @override
  String get theLibraryIs =>
      'La biblioteca se está leyendo de nuevo. Los programas del servidor se sumarán a los canales cuando termine.';

  @override
  String get itsLibraryIs =>
      'Se está leyendo su biblioteca y creando sus canales. Tarda uno o dos minutos.';

  @override
  String isSignedIn(Object name) {
    return '$name ha iniciado sesión.';
  }

  @override
  String get couldntDoThat => 'No se pudo hacer. Inténtalo de nuevo.';

  @override
  String get itsChannelsStayIt =>
      'Sus canales se quedan. Necesita iniciar sesión para reproducir.';

  @override
  String signOut4(Object name) {
    return '¿Cerrar la sesión de $name?';
  }

  @override
  String get signingIn => 'Iniciando sesión…';

  @override
  String wasSignedIn(Object server, Object user) {
    return 'Tenía la sesión iniciada en $server como $user. Vuelve a iniciar sesión.';
  }

  @override
  String signedInTo(Object server, Object user) {
    return 'Sesión iniciada en $server como $user.';
  }

  @override
  String get profileName => 'Nombre del perfil';

  @override
  String get nameAProfile =>
      'Ponle nombre a un perfil, inicia sesión en tu servidor multimedia y sus canales se crean y exportan.';

  @override
  String get chooseABackup => 'Elegir un archivo de copia…';

  @override
  String get moveAHousehold =>
      'Trae aquí un hogar desde una TV u otro servidor: sus perfiles, canales, bloques, logotipos y ajustes de exportación.';

  @override
  String get restoreABackup => 'Restaurar una copia';

  @override
  String get theServerIs => 'El servidor está arrancando…';

  @override
  String get itsProgramsLeaveThe =>
      'Sus programas salen de los canales, que conservan sus números. Las fuentes y carpetas de anuncios que estén en él aparecen como no encontradas hasta que las cambies.';

  @override
  String addAServerTo(Object name) {
    return 'Añadir un servidor a $name';
  }

  @override
  String servers2(Object name) {
    return '$name: servidores';
  }

  @override
  String get makeAccountAnd => 'Crear cuenta e iniciar sesión';

  @override
  String get setPasswordAnd => 'Definir contraseña e iniciar sesión';

  @override
  String get passwordAgain => 'Repetir contraseña';

  @override
  String get atLeast8 => 'Al menos 8 caracteres.';

  @override
  String get userName => 'Nombre de usuario';

  @override
  String get adminAccount => 'Cuenta de administrador';

  @override
  String get makeTheFirst => 'Crea la primera cuenta de administrador.';

  @override
  String get setANew =>
      'Define una contraseña nueva para una cuenta de administrador.';

  @override
  String get thisSetupLink =>
      'Este enlace de configuración ya se usó o es de un inicio anterior. Abre el más reciente del registro del servidor o inicia sesión.';

  @override
  String get thePasswordsDont => 'Las contraseñas no coinciden.';

  @override
  String get newPasswordAgain => 'Repetir contraseña nueva';

  @override
  String get newPassword => 'Contraseña nueva';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get passwordChangedYour =>
      'Contraseña cambiada. Tus otros navegadores han cerrado sesión.';

  @override
  String get theNewPasswords => 'Las contraseñas nuevas no coinciden.';

  @override
  String get theyAreSigned =>
      'Se cierra su sesión y no podrá volver a iniciarla.';

  @override
  String get cantSignIn =>
      'No puede iniciar sesión; sesión cerrada en todas partes.';

  @override
  String get usersReachOnly =>
      'Los usuarios solo acceden a los perfiles de abajo.';

  @override
  String get adminsCanDo =>
      'Los administradores pueden hacer de todo, en cualquier perfil.';

  @override
  String get admin => 'Administrador';

  @override
  String get user => 'Usuario';

  @override
  String get leaveEmptyToKeepIt =>
      'Déjalo vacío para conservarla. Definir una cierra su sesión en otros lugares.';

  @override
  String get needsAPassword =>
      'Necesita una contraseña para poder iniciar sesión.';

  @override
  String get addUser => 'Añadir usuario';

  @override
  String get needsAPassword2 => 'Necesita una contraseña';

  @override
  String get noProfiles => 'Sin perfiles';

  @override
  String get pad => 'Rellenar';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  Clips: $clips';
  }

  @override
  String get clipsFrom2 => 'Clips de';

  @override
  String get channelsUsingItGo =>
      'Los canales que lo usan vuelven a un icono integrado.';

  @override
  String get uploading => 'Subiendo…';

  @override
  String get noneOfYourShows =>
      'Ninguna de tus series tiene imagen de logotipo en tu servidor.';

  @override
  String get chooseAnIcon => 'Elegir un icono';

  @override
  String get couldntCopySelect =>
      'No se pudo copiar. Selecciona el texto y cópialo.';

  @override
  String copy(Object label) {
    return 'Copiar $label';
  }

  @override
  String get home => 'Inicio';

  @override
  String get thereIsNoPage => 'Aquí no hay ninguna página.';

  @override
  String get enterPin => 'Introducir PIN';

  @override
  String get thisIsA =>
      'Este es un perfil infantil. Para cambiar sus ajustes se necesita el PIN de un adulto.';

  @override
  String hasAPin(Object name) {
    return '$name tiene un PIN.';
  }

  @override
  String get profile => 'Perfil';

  @override
  String get changingAKid =>
      'Para cambiar los ajustes de un perfil infantil se necesita el PIN de un perfil de adulto.';

  @override
  String get aGrownUps => 'PIN de un adulto';

  @override
  String get thisProfile => 'este perfil';

  @override
  String movies3(Object movies) {
    return 'Películas ($movies)';
  }

  @override
  String get shows3 => 'Series';

  @override
  String remove4(Object label) {
    return 'Quitar $label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · No encontrado en el servidor';
  }

  @override
  String get dragACollection =>
      'Arrastra aquí una colección, carpeta o película, o usa su botón Añadir.';

  @override
  String get collectionsAndFolders => 'Colecciones y carpetas';

  @override
  String add3(Object name) {
    return 'Añadir $name';
  }

  @override
  String added2(Object name) {
    return '$name añadido';
  }

  @override
  String get dragToAdd => 'Arrastra para añadir';

  @override
  String get languageAutomatic => 'Automático';

  @override
  String dateAtTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String connectingTo(Object server) {
    return 'Conectando con $server…';
  }

  @override
  String get yourServerLower => 'tu servidor';

  @override
  String noServerFoundAt(Object address) {
    return 'No se encontró ningún servidor Jellyfin, Emby o Plex en $address.';
  }

  @override
  String captionsValue(Object name) {
    return 'Subtítulos: $name';
  }

  @override
  String channelOverrides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales tienen su propio ajuste (Canales e iconos).',
      one: '$count canal tiene su propio ajuste (Canales e iconos).',
    );
    return '$_temp0';
  }

  @override
  String noShowLogosOn(Object kind) {
    return 'Ninguna de tus series tiene imagen de logotipo en tu servidor $kind.';
  }

  @override
  String fileChosen(Object name) {
    return 'Archivo: $name';
  }

  @override
  String get theOneChosenBefore => 'el elegido antes';

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
          'Emitiendo los canales $channels a $viewers espectador(es). $running de $limit emisiones en uso.',
      one:
          'Emitiendo el canal $channels a $viewers espectador(es). $running de $limit emisiones en uso.',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name: exportar esta parrilla';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name (niño): exportar esta parrilla';
  }

  @override
  String encoderInUse(Object encoder) {
    return 'Codificador en uso: $encoder';
  }

  @override
  String get checking => 'comprobando…';

  @override
  String countShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '$count serie',
    );
    return '$_temp0';
  }

  @override
  String countEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodios',
      one: '$count episodio',
    );
    return '$_temp0';
  }

  @override
  String countMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count películas',
      one: '$count película',
    );
    return '$_temp0';
  }

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return '$_temp0';
  }

  @override
  String countMusicVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos musicales',
      one: '$count video musical',
    );
    return '$_temp0';
  }

  @override
  String countHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ocultos',
      one: '$count oculto',
    );
    return '$_temp0';
  }

  @override
  String countOnTheAir(int count) {
    return '$count en emisión';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloques de programación',
      one: '$count bloque de programación',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name: $stats';
  }

  @override
  String get yourServerHasNothingNew =>
      'Tu servidor no tiene nada nuevo desde la última actualización. Los archivos nuevos aparecen aquí cuando el servidor los ha analizado: si acabas de añadir alguno, analiza primero la biblioteca en el servidor y luego actualiza de nuevo.';

  @override
  String serverHasNothingNew(Object server) {
    return '$server no tiene nada nuevo desde la última actualización. Los archivos nuevos aparecen aquí cuando el servidor los ha analizado: si acabas de añadir alguno, analiza primero la biblioteca en el servidor y luego actualiza de nuevo.';
  }

  @override
  String get updateWatchStatusOnYourServer =>
      'Actualizar el estado de visto en tu servidor';

  @override
  String get updateWatchStatusOnYourServers =>
      'Actualizar el estado de visto en tus servidores';

  @override
  String updateWatchStatusOn(Object name) {
    return 'Actualizar el estado de visto en $name';
  }

  @override
  String get poolFoldersBumpers =>
      'Cada video de estas carpetas (y sus subcarpetas) abre y cierra las pausas, y nunca se emite como programa.';

  @override
  String get poolFoldersCommercials =>
      'Cada video de estas carpetas (y sus subcarpetas) llena las pausas, y nunca se emite como programa.';

  @override
  String get newPin => 'PIN nuevo';

  @override
  String namedPin(Object name) {
    return 'PIN de $name';
  }

  @override
  String get qualitySameAsProfile => 'Calidad: igual que el perfil';

  @override
  String qualityValue(Object limit) {
    return 'Calidad: $limit';
  }

  @override
  String onChannel(Object channel) {
    return 'en $channel';
  }

  @override
  String get aChannelThatIsGone => 'un canal que ya no existe';

  @override
  String liveFrom(Object source) {
    return 'En directo desde $source';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'Logotipo $mode · Estrenos $premieres';
  }

  @override
  String get offLower => 'desactivado';

  @override
  String streamingNow(Object count) {
    return 'Emisiones ahora: $count.';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return 'Emisiones ahora: $count · codificando con $encoder.';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · Canales: $chosen de $channels';
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
    return 'Del $when ($device): $profiles. Canales: $channels, bloques de programación: $blocks, logotipos: $logos.';
  }

  @override
  String get backupSavedFirst =>
      'Antes se guarda una copia de lo que hay aquí ahora.';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series nuevas',
      one: '$count serie nueva',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodios nuevos',
      one: '$count episodio nuevo',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count películas nuevas',
      one: '$count película nueva',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones nuevas',
      one: '$count canción nueva',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return 'Reproduce $list.';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales nuevos',
      one: '$count canal nuevo',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => 'Niños pequeños';

  @override
  String get kidRatingYoungDescription => 'TV-Y y TV-Y7';

  @override
  String get kidRatingKids => 'Niños';

  @override
  String get kidRatingKidsDescription => 'Hasta TV-G y G';

  @override
  String get kidRatingOlder => 'Niños mayores';

  @override
  String get kidRatingOlderDescription => 'Hasta TV-PG y PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles',
      one: '$count perfil',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales',
      one: '$count canal',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloques',
      one: '$count bloque',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count franjas',
      one: '$count franja',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos en sus carpetas',
      one: '$count video en sus carpetas',
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
  String get liveLabel => 'En directo';

  @override
  String get aMidRollOpens =>
      'Un mid-roll abre y cierra con una cortinilla, un post-roll abre con una y un pre-roll cierra con una. Los anuncios llenan el resto.';

  @override
  String get programsPlayBack => 'Los programas se suceden sin pausas.';

  @override
  String get everyShowFills =>
      'Cada serie llena una franja de media hora (una hora o más las largas), para que la guía siga en punto.';

  @override
  String get chooseHowLong =>
      'Elige cuánto dura cada pausa, cada cuánto se interrumpen las series y de qué grupo sale cada pausa.';

  @override
  String get kindSentenceAutomatic => 'automática';

  @override
  String get kindSentenceBeforeRestore => 'antes de restaurar';

  @override
  String get kindSentenceBeforeReset => 'antes de restablecer';

  @override
  String get kindSentenceBeforeDeletingAProfile =>
      'antes de eliminar un perfil';

  @override
  String kindSentenceBeforeDeleting(Object subject) {
    return 'antes de eliminar $subject';
  }

  @override
  String get kindSentenceBeforeUpdate => 'antes de actualizar';

  @override
  String get kindSentenceBeforeLineupCleanup => 'antes de limpiar la parrilla';

  @override
  String get kindSentenceFromAFile => 'desde un archivo';

  @override
  String get kindSentenceMovingToOfficial => 'traslado a Nightingale TV';

  @override
  String get kindSentenceMovingToOwnBuild =>
      'traslado a Nightingale TV (versión propia)';

  @override
  String get kindSentenceFromOfficial => 'desde Nightingale TV';

  @override
  String get kindSentenceFromOwnBuild =>
      'desde Nightingale TV (versión propia)';

  @override
  String get kindSentenceMadeByYou => 'creada por ti';

  @override
  String get copyAction => 'Copiar';

  @override
  String get channelKidsZone => 'Zona Infantil';

  @override
  String get channelToonTv => 'Toon TV';

  @override
  String get channelLaughTrack => 'Risas Enlatadas';

  @override
  String get channelFamilyRoom => 'Sala Familiar';

  @override
  String get channelAdventureTv => 'Aventura TV';

  @override
  String get channelSciFiFantasy => 'Ciencia Ficción y Fantasía';

  @override
  String get channelMysteryTv => 'Misterio TV';

  @override
  String get channelDramaCentral => 'Central del Drama';

  @override
  String get channelCrimeJustice => 'Crimen y Justicia';

  @override
  String get channelThrillTv => 'Suspense TV';

  @override
  String get channelFrightNight => 'Noche de Terror';

  @override
  String get channelRomanceTv => 'Romance TV';

  @override
  String get channelDiscoveryZone => 'Zona Descubrimiento';

  @override
  String get channelMusicTv => 'Música TV';

  @override
  String get channelRealityTv => 'Telerrealidad TV';

  @override
  String get channelGameShowTv => 'Concursos TV';

  @override
  String get channelFrontierTv => 'Frontera TV';

  @override
  String get channelHistoryTv => 'Historia TV';

  @override
  String get channelSportsTv => 'Deportes TV';

  @override
  String get channelNewsTv => 'Noticias TV';

  @override
  String get channelAllShows => 'Todas las series';

  @override
  String get channelMovieChannel => 'Canal de Cine';

  @override
  String get channelMusicVideos => 'Videos musicales';

  @override
  String get channelMusicRadio => 'Radio Musical';

  @override
  String get genreActionAdventure => 'Acción y aventura';

  @override
  String get genreSciFiFantasy => 'Ciencia ficción y fantasía';

  @override
  String get genreKids => 'Niños';

  @override
  String get genreAnimation => 'Animación';

  @override
  String get genreComedy => 'Comedia';

  @override
  String get genreFamily => 'Familia';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreCrime => 'Crimen';

  @override
  String get genreMystery => 'Misterio';

  @override
  String get genreThriller => 'Suspense';

  @override
  String get genreHorror => 'Terror';

  @override
  String get genreRomance => 'Romance';

  @override
  String get genreDocumentary => 'Documental';

  @override
  String get genreMusic => 'Música';

  @override
  String get genreReality => 'Telerrealidad';

  @override
  String get genreGameShows => 'Concursos';

  @override
  String get genreWestern => 'Wéstern';

  @override
  String get genreWar => 'Bélico';

  @override
  String get genreHistory => 'Historia';

  @override
  String get genreNews => 'Noticias';

  @override
  String get genreTalk => 'Entrevistas';

  @override
  String get genreSoap => 'Telenovela';

  @override
  String get genreSports => 'Deportes';

  @override
  String get genreClassical => 'Clásica';

  @override
  String get genreElectronic => 'Electrónica';

  @override
  String get genreCountry => 'Country';

  @override
  String get genreLatin => 'Latina';

  @override
  String get genreSoundtrack => 'Bandas sonoras';

  @override
  String get genreOldies => 'Clásicos';

  @override
  String get genreDance => 'Dance';

  @override
  String get genreFolk => 'Folk';

  @override
  String get genreAlternative => 'Alternativa';

  @override
  String get blockDaytime => 'Horario diurno';

  @override
  String get blockMovieNight => 'Noche de Cine';

  @override
  String get blockNewEpisodes => 'Episodios nuevos';

  @override
  String get kindShow => 'Serie';

  @override
  String get kindShows => 'Series';

  @override
  String get kindMovies => 'Películas';

  @override
  String get kindMusicVideos => 'Videos musicales';

  @override
  String get kindRadio => 'Radio';

  @override
  String genreMovies(Object genre) {
    return 'Películas de $genre';
  }

  @override
  String genreMusicVideos(Object genre) {
    return 'Videos musicales de $genre';
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
  String get lateNightTitle => 'Madrugada';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get stillWatchingOff => 'Desactivado';

  @override
  String afterHours(int hours) {
    return 'Tras $hours horas';
  }

  @override
  String get bitrateOriginal => 'Original (sin límite)';

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
  String get noSuchLanguage => 'Ese idioma no existe.';

  @override
  String get languageField => 'Idioma';

  @override
  String get remotePageTitle => 'Mando de Nightingale TV';

  @override
  String get remotePairTitle => 'Vincular con la TV';

  @override
  String get remotePairHelp =>
      'Escanea el código de la TV (Menú → Mando del teléfono) o introduce el código de 6 dígitos que aparece allí.';

  @override
  String get remotePairingCode => 'Código de vinculación';

  @override
  String get remotePair => 'Vincular';

  @override
  String get remoteConnecting => 'Conectando…';

  @override
  String get remoteTabRemote => 'Mando';

  @override
  String get remoteUp => 'Arriba';

  @override
  String get remoteLeft => 'Izquierda';

  @override
  String get remoteRight => 'Derecha';

  @override
  String get remoteDown => 'Abajo';

  @override
  String get remoteInfo => 'Info';

  @override
  String get remoteLastCh => 'Último';

  @override
  String get remoteCc => 'SUB';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => 'Intro';

  @override
  String get remoteRemovedFromTv =>
      'Este teléfono se quitó de la TV. Escanea el código para vincularlo de nuevo.';

  @override
  String get remoteCouldntPair => 'No se pudo vincular. Inténtalo de nuevo.';

  @override
  String get remoteCantReachWifi =>
      'No se puede acceder a la TV. ¿Está este teléfono en la misma Wi-Fi?';

  @override
  String get remoteEnterDigits =>
      'Introduce los 6 dígitos que aparecen en la TV.';

  @override
  String get remoteCantReachTv => 'No se puede acceder a la TV';

  @override
  String get remotePickProfile => 'Elige un perfil con las flechas y OK.';

  @override
  String remoteWatching(Object name) {
    return 'Viendo: $name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name (niño)';
  }

  @override
  String get transferPageTitle => 'Copia de seguridad de Nightingale TV';

  @override
  String get transferIntro =>
      'Mueve una copia de seguridad entre esta TV y este dispositivo. Mantén abierta la ventana de la TV mientras tanto.';

  @override
  String get transferDownload => 'Descargar copia';

  @override
  String get transferDownloadHelp =>
      'Una copia de la configuración actual de la TV: perfiles, canales, bloques y ajustes.';

  @override
  String get transferRestoreTitle => 'Restaurar desde un archivo';

  @override
  String transferRestoreHelp(Object file) {
    return 'Envía un archivo $file a la TV. No cambia nada hasta que lo confirmes en la TV.';
  }

  @override
  String get transferChoose => 'Elegir un archivo de copia…';

  @override
  String get transferFoot =>
      'Solo los dispositivos de tu red doméstica pueden abrir esta página.';

  @override
  String transferSending(Object name) {
    return 'Enviando $name…';
  }

  @override
  String get transferCheckTv => 'Mira tu TV para terminar.';

  @override
  String get transferClosed =>
      'La TV cerró esta página. Ábrela de nuevo desde Copia y restauración.';

  @override
  String get transferCouldntTake => 'La TV no pudo aceptar ese archivo.';

  @override
  String get transferCouldntReach =>
      'No se pudo acceder a la TV. ¿Sigue mostrando el código?';

  @override
  String get includeShows => 'Incluir series';

  @override
  String get everyShow2 => 'cada serie';

  @override
  String get decades => 'Décadas';

  @override
  String get decadesHeading => 'DÉCADAS';

  @override
  String get channelActionTv => 'Acción TV';

  @override
  String get channelSciFiTv => 'Ciencia Ficción TV';

  @override
  String get channelFantasyTv => 'Fantasía TV';

  @override
  String get channelMysteryThrills => 'Misterio y Suspense';

  @override
  String get genreAction => 'Acción';

  @override
  String get genreAdventure => 'Aventura';

  @override
  String get genreSciFi => 'Ciencia ficción';

  @override
  String get genreFantasy => 'Fantasía';

  @override
  String get genreThrillerMystery => 'Suspense y misterio';

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
    return 'Películas de $genre $decade';
  }

  @override
  String get errorReports => 'Informes de errores';

  @override
  String get sendErrorReportsFrom =>
      'Enviar informes de errores desde este dispositivo';

  @override
  String get errorReportsExplain =>
      'Cuando algo falla, Nightingale TV envía a su desarrollador un informe breve: el error, la versión de la app, el tipo de dispositivo y las últimas pantallas y números de canal. Las direcciones de servidor, contraseñas y claves, nombres y rutas de archivo se quitan antes de enviarlo. Los títulos y lo que ves nunca se envían.';

  @override
  String get errorReportsOff =>
      'Si lo desactivas, no se envía nada desde este dispositivo; los informes pendientes se borran.';

  @override
  String get sendATestReport => 'Enviar un informe de prueba';

  @override
  String lastReportId(String id) {
    return 'ID del último informe: $id';
  }

  @override
  String get noReportSentYet =>
      'Aún no se ha enviado ningún informe desde este dispositivo.';

  @override
  String get quoteReportId =>
      'Indica este ID cuando le cuentes un problema al desarrollador.';

  @override
  String testReportSent(String id) {
    return 'Informe de prueba enviado: $id';
  }

  @override
  String get testReportNotSent =>
      'No se pudo enviar el informe de prueba. Inténtalo de nuevo en un momento.';

  @override
  String get reportsNotInBuild =>
      'Los informes de errores no forman parte de esta versión de Nightingale TV, así que nunca se envía nada.';
}
