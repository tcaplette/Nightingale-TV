// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get onlyChannelsYou =>
      'Só é possível remover os canais que você adicionou. Oculte este em vez disso.';

  @override
  String get music => 'Música';

  @override
  String get nothingInThe => 'Nada na biblioteca corresponde a isso.';

  @override
  String get chooseSongsOr => 'Escolha músicas ou videoclipes.';

  @override
  String get blockChannel => 'Canal de blocos';

  @override
  String thisOverlapsOn(Object title, Object clash) {
    return 'Isso se sobrepõe a “$title” ($clash) no mesmo canal.';
  }

  @override
  String get chooseSomeShows => 'Escolha séries ou filmes para o bloco exibir.';

  @override
  String nothingInThis(Object shortLabel) {
    return 'Nada nesta mistura tem classificação $shortLabel ou superior. Escolha uma classificação menor ou outras séries.';
  }

  @override
  String get theLineupsShows =>
      'As séries da grade não têm episódios. Escolha outras séries.';

  @override
  String get addAShow => 'Adicione uma série à grade.';

  @override
  String get chooseAChannel => 'Escolha um canal.';

  @override
  String get theBlockHas =>
      'O bloco precisa terminar em um horário diferente do início.';

  @override
  String get pickAtLeast => 'Escolha pelo menos um dia.';

  @override
  String get giveTheBlock => 'Dê um título ao bloco.';

  @override
  String get thisChannelDoesnt => 'Este canal não tem faixas.';

  @override
  String get onlyShuffledChannels =>
      'Só canais aleatórios podem ser embaralhados de novo.';

  @override
  String get chooseSomethingFor => 'Escolha algo para o canal exibir.';

  @override
  String get onlyChannelsYouAdded =>
      'Só os canais que você adicionou podem mudar o que exibem.';

  @override
  String get myChannel => 'Meu canal';

  @override
  String get noneOfYour =>
      'Não foi possível acessar nenhum dos seus servidores.';

  @override
  String scanning(Object where) {
    return 'Analisando $where…';
  }

  @override
  String get buildingChannels => 'Criando canais…';

  @override
  String get notSignedIn => 'Você não entrou.';

  @override
  String isAlreadyIn(Object name) {
    return '$name já está neste perfil';
  }

  @override
  String get thatServerIs => 'Esse servidor não está mais neste perfil';

  @override
  String get yourSessionExpired => 'Sua sessão expirou. Entre novamente.';

  @override
  String get m3uPlaylist => 'Playlist M3U';

  @override
  String hasNoLive(Object serverName) {
    return '$serverName não tem canais de TV ao vivo';
  }

  @override
  String couldntReach(Object serverName) {
    return 'Não foi possível acessar $serverName';
  }

  @override
  String liveTv(Object serverName) {
    return 'TV ao vivo de $serverName';
  }

  @override
  String liveTvIs(Object serverName) {
    return 'A TV ao vivo de $serverName já é uma fonte';
  }

  @override
  String get notSignedIn2 => 'Você não entrou';

  @override
  String get newGroup => 'Novo grupo';

  @override
  String get thisBackupIs =>
      'Este backup está danificado: não é possível ler um dos logotipos de canal.';

  @override
  String get thisBackupIsDamaged =>
      'Este backup está danificado: não é possível ler as configurações de exportação de TV ao vivo.';

  @override
  String thisBackupIsDamagedS(Object name, Object what) {
    return 'Este backup está danificado: não é possível ler $what de $name.';
  }

  @override
  String get liveTvSources => 'Fontes de TV ao vivo';

  @override
  String thisBackupCant(Object problem) {
    return 'Este backup não pode ser restaurado. $problem';
  }

  @override
  String get thisBackupIsDamagedIts =>
      'Este backup está danificado: não é possível ler os perfis.';

  @override
  String get thisFileIs =>
      'Este arquivo é grande demais para ser um backup do Nightingale TV.';

  @override
  String get thisBackupWas =>
      'Este backup foi feito por uma versão mais recente do Nightingale TV.';

  @override
  String get thisFileIsnt =>
      'Este arquivo não é um backup do Nightingale TV ou está danificado.';

  @override
  String restoredTheBackup(Object toLocal) {
    return 'Backup de $toLocal restaurado.';
  }

  @override
  String couldntRestoreThe(Object e) {
    return 'Não foi possível restaurar o backup: $e';
  }

  @override
  String couldntSaveA(Object e) {
    return 'Não foi possível salvar um backup antes: $e';
  }

  @override
  String get madeByYou => 'Feito por você';

  @override
  String get fromNightingaleTv => 'Do Nightingale TV (versão própria)';

  @override
  String get fromNightingaleTv2 => 'Do Nightingale TV';

  @override
  String get movingToNightingale =>
      'Mudança para o Nightingale TV (versão própria)';

  @override
  String get movingToNightingaleTv => 'Mudança para o Nightingale TV';

  @override
  String get fromAFile => 'De um arquivo';

  @override
  String get beforeLineupCleanup => 'Antes da limpeza da grade';

  @override
  String get beforeUpdate => 'Antes da atualização';

  @override
  String beforeDeleting(Object subject) {
    return 'Antes de excluir $subject';
  }

  @override
  String get beforeDeletingA => 'Antes de excluir um perfil';

  @override
  String get beforeReset => 'Antes de redefinir';

  @override
  String get beforeRestore => 'Antes de restaurar';

  @override
  String get automatic => 'Automático';

  @override
  String get nc1718 => 'NC-17 / 18 ou superior';

  @override
  String get tvMaR => 'TV-MA / R ou superior';

  @override
  String get tv14Pg => 'TV-14 / PG-13 ou superior';

  @override
  String get off => 'Desligado';

  @override
  String get nowAndThen => 'De vez em quando';

  @override
  String get always => 'Sempre';

  @override
  String get truncate => 'Cortar';

  @override
  String get offlineImage => 'Imagem fora do ar';

  @override
  String get filler => 'Preenchimento';

  @override
  String get leastWatchedFirst => 'Menos assistidos primeiro';

  @override
  String get shuffled => 'Aleatório';

  @override
  String get inOrderShows => 'Em ordem (as séries se revezam)';

  @override
  String get channelsWhereEverything =>
      'Canais em que tudo o que passa, inclusive blocos, tem classificação TV-Y, TV-Y7, TV-G ou G.';

  @override
  String get musicVideoAnd => 'Canais de videoclipes e rádio.';

  @override
  String get channelsThatPlay =>
      'Canais que exibem filmes, sem episódios nem música.';

  @override
  String get channelsFromYour => 'Canais das suas fontes de TV ao vivo.';

  @override
  String get channelsYouMarked => 'Canais que você marcou como favoritos.';

  @override
  String get everyChannel => 'Todos os canais.';

  @override
  String get kids => 'Crianças';

  @override
  String get movies => 'Filmes';

  @override
  String get liveTv2 => 'TV ao vivo';

  @override
  String get favorites => 'Favoritos';

  @override
  String get all => 'Todos';

  @override
  String get theAccentsAre =>
      'Os destaques são um tema e “theme” ou “channel” para cada um.';

  @override
  String get thoseArentRetro => 'Essas não são configurações retrô.';

  @override
  String get theOverlayTheme =>
      'O tema de sobreposição é standard, vcr, cableBox ou stationIdent.';

  @override
  String get theCrtEffect =>
      'O efeito CRT é off, softTube, livingRoom, arcade, studioMonitor ou custom.';

  @override
  String get theSurroundImage => 'A imagem de contorno é um nome de arquivo.';

  @override
  String get theSurroundIs => 'O contorno é black, charcoal, channel ou image.';

  @override
  String get thePictureShape =>
      'O formato da imagem é original, fill43 ou fit43.';

  @override
  String get channelColor => 'Cor do canal';

  @override
  String get theme => 'Tema';

  @override
  String get stationIdent => 'Identidade do canal';

  @override
  String get cableBox => 'Decodificador';

  @override
  String get vcr => 'Videocassete';

  @override
  String get standard => 'Padrão';

  @override
  String get custom => 'Personalizado';

  @override
  String get studioMonitor => 'Monitor de estúdio';

  @override
  String get arcade => 'Fliperama';

  @override
  String get livingRoom => 'Sala de estar';

  @override
  String get softTube => 'Tubo suave';

  @override
  String get customColorIs =>
      'A cor personalizada é natural, warm, faded ou vivid.';

  @override
  String get customLinesIs => 'As linhas personalizadas são 240 ou 480.';

  @override
  String customIsOff(Object key) {
    return '$key personalizado é off, low, medium ou high.';
  }

  @override
  String get thatIsntA => 'Esse não é um estilo personalizado.';

  @override
  String get vivid => 'Vívido';

  @override
  String get faded => 'Desbotado';

  @override
  String get warm => 'Quente';

  @override
  String get natural => 'Natural';

  @override
  String get high => 'Alto';

  @override
  String get medium => 'Médio';

  @override
  String get low => 'Baixo';

  @override
  String get image => 'Imagem';

  @override
  String get charcoal => 'Carvão';

  @override
  String get black => 'Preto';

  @override
  String get n43Fit => '4:3 ajustar';

  @override
  String get n43Fill => '4:3 preencher';

  @override
  String get original => 'Original';

  @override
  String get thisChannelIs => 'Este canal está fora do ar';

  @override
  String get offAir => 'Fora do ar';

  @override
  String get tail => 'Preenchimento';

  @override
  String get postRoll => 'Post-roll';

  @override
  String get midRoll => 'Mid-roll';

  @override
  String get preRoll => 'Pre-roll';

  @override
  String get commercials => 'Comerciais';

  @override
  String get bumpers => 'Vinhetas';

  @override
  String get pleaseStandBy => 'POR FAVOR, AGUARDE';

  @override
  String get offTheAir => 'FORA DO AR';

  @override
  String get wellBeRight => 'Já voltamos';

  @override
  String upNextAt(Object at) {
    return 'A seguir às $at';
  }

  @override
  String backOnThe(Object next, Object title) {
    return 'De volta ao ar $next com $title';
  }

  @override
  String get processor => 'Processador';

  @override
  String get graphicsCardNvenc => 'Placa de vídeo (NVENC)';

  @override
  String get graphicsCardVaapi => 'Placa de vídeo (VAAPI)';

  @override
  String get signInTo =>
      'Entre neste perfil na TV para exportar os canais dele.';

  @override
  String get signInToThis =>
      'Entre neste perfil aqui para exportar os canais dele.';

  @override
  String portIsIn(Object port) {
    return 'A porta $port está em uso por outro programa. Escolha outra porta e atualize-a no Plex ou no Jellyfin.';
  }

  @override
  String anotherProfileAlready(Object port) {
    return 'Outro perfil já usa a porta $port.';
  }

  @override
  String get pickAPort => 'Escolha uma porta entre 1024 e 65535.';

  @override
  String get movie => 'Filme';

  @override
  String backOnTheAir(Object start, Object title) {
    return 'De volta ao ar $start com $title.';
  }

  @override
  String get images => 'Imagens';

  @override
  String get couldNotRead =>
      'Não foi possível ler essa imagem. Tente PNG, JPG, WebP ou SVG.';

  @override
  String get thatFileIs => 'Esse arquivo não é um SVG válido.';

  @override
  String get thatImageIs => 'Essa imagem tem mais de 20 MB. Escolha uma menor.';

  @override
  String get other => 'Outros';

  @override
  String get seasonsHolidays => 'Estações e feriados';

  @override
  String get newsWeather => 'Notícias e clima';

  @override
  String get sports => 'Esportes';

  @override
  String get genres => 'Gêneros';

  @override
  String get kidsFamily => 'Crianças e família';

  @override
  String get tvMovies => 'TV e filmes';

  @override
  String get theServerWould => 'O servidor não converteu este item.';

  @override
  String get theServerHas =>
      'O servidor não tem uma versão reproduzível deste item.';

  @override
  String get externalLabel => 'Externas';

  @override
  String get scanningChannelSources => 'Analisando fontes de canais…';

  @override
  String didNotAnswer(Object serverUrl) {
    return '$serverUrl não respondeu como um servidor Jellyfin.';
  }

  @override
  String noJellyfinServer(Object serverUrl, Object message) {
    return 'Nenhum servidor Jellyfin encontrado em $serverUrl. $message';
  }

  @override
  String serverErrorOn(Object statusCode, Object path) {
    return 'Erro do servidor $statusCode em $path.';
  }

  @override
  String get wrongUsernameOr =>
      'Usuário ou senha incorretos, ou a sessão expirou.';

  @override
  String couldNotReach(Object e) {
    return 'Não foi possível acessar o servidor ($e).';
  }

  @override
  String get theServerTook => 'O servidor demorou demais para responder.';

  @override
  String get theServerWouldNot => 'O servidor não converteu este canal.';

  @override
  String get musicVideo => 'Videoclipe';

  @override
  String movie2(Object year) {
    return 'Filme · $year';
  }

  @override
  String get commercial => 'Comercial';

  @override
  String couldntReachThe(Object what) {
    return '$what: não foi possível acessar';
  }

  @override
  String theIsToo(Object what) {
    return '$what: grande demais';
  }

  @override
  String theSAddress(Object what) {
    return '$what: o endereço não é um endereço da web';
  }

  @override
  String get noGuideInformation => 'Sem informações de programação';

  @override
  String get serverLiveTv => 'TV ao vivo do servidor';

  @override
  String get theChannelHas => 'O canal não tem endereço de transmissão.';

  @override
  String get couldntReadThe => 'Não foi possível ler o guia';

  @override
  String get couldntReachTheGuide => 'Não foi possível acessar o guia';

  @override
  String get theSourceHas => 'A fonte não tem playlist';

  @override
  String get couldntReachThePlaylist => 'Não foi possível acessar a playlist';

  @override
  String get couldntReadThePlaylist =>
      'Não foi possível ler o arquivo da playlist';

  @override
  String couldntRefresh(Object name) {
    return 'Não foi possível atualizar $name';
  }

  @override
  String get thePlaylistHas => 'A playlist não tem canais';

  @override
  String get thatIsntAn => 'Isso não é uma playlist M3U';

  @override
  String get thatIsntAnXmltv => 'Isso não é um guia XMLTV';

  @override
  String get theGuideIs => 'O guia é grande demais (mais de 1 GB)';

  @override
  String get nightingaleTvBackups => 'Backups do Nightingale TV';

  @override
  String get uninstallingThisApp =>
      'Desinstalar este app apaga os perfis, canais e configurações dele, a menos que você faça backup ou os transfira antes.';

  @override
  String theStoreVersion(Object officialName) {
    return 'A versão da loja é instalada ao lado desta como um app separado, “$officialName”, com configuração própria. Comprá-la apoia o projeto. Depois de instalada, sua configuração pode ser transferida daqui.';
  }

  @override
  String updatesFromGoogle(Object ownBuildName) {
    return 'Atualizações do Google Play e APKs oficiais do Nightingale TV são instalados sobre este e mantêm sua configuração. Uma versão própria é instalada como app separado, “$ownBuildName”, e sua configuração pode ser transferida daqui.';
  }

  @override
  String get yourOwnBuild => 'Sua versão própria';

  @override
  String get officialNightingaleTv => 'APK oficial do Nightingale TV';

  @override
  String get installedFromGoogle => 'Instalado pelo Google Play';

  @override
  String get nightingaleTvOwn => 'Nightingale TV (versão própria)';

  @override
  String get sleepTimerOff => 'Timer de sono desligado';

  @override
  String get sleepAtEnd => 'Dormir no fim do programa';

  @override
  String sleepInMin(Object minutes) {
    return 'Dormir em $minutes min';
  }

  @override
  String get forced => 'Forçadas';

  @override
  String get unknownLanguage => 'Idioma desconhecido';

  @override
  String didntStart(Object name) {
    return '$name não iniciou';
  }

  @override
  String get thisDeviceCant =>
      'Este dispositivo não consegue reproduzir o vídeo deste canal';

  @override
  String get thisChannelsStream =>
      'O tipo de transmissão deste canal não é compatível com este dispositivo';

  @override
  String refusedTheStream(Object name) {
    return '$name recusou a transmissão. Talvez ela esteja em outro dispositivo.';
  }

  @override
  String yourAccountCant(Object server) {
    return 'Sua conta $server não pode assistir a este canal';
  }

  @override
  String cantReach(Object name) {
    return 'Não foi possível acessar $name';
  }

  @override
  String allOfS(Object server) {
    return 'Todos os sintonizadores de $server estão em uso';
  }

  @override
  String lostTheSignal(Object name) {
    return 'Sinal perdido em $name';
  }

  @override
  String get couldntPlayThat =>
      'Não foi possível reproduzir essa parte. Voltando ao vivo';

  @override
  String get backToLive => 'Voltando ao vivo';

  @override
  String get theServerTookToo =>
      'O servidor demorou demais para começar a converter este programa.';

  @override
  String get nothingToPlay => 'Nada para reproduzir neste canal';

  @override
  String captionsOn(Object shown) {
    return 'Legendas ativadas: $shown';
  }

  @override
  String get captionsOn2 => 'Legendas ativadas';

  @override
  String get captionsOnNo =>
      'Legendas ativadas: sem legendas para este programa';

  @override
  String get captionsOff => 'Legendas desativadas';

  @override
  String get guest => 'Convidado';

  @override
  String get thereHasTo => 'É preciso haver pelo menos um perfil de adulto.';

  @override
  String get switchToAnother => 'Mude para outro perfil antes de excluir este.';

  @override
  String get me => 'Eu';

  @override
  String get couldntOpenA =>
      'Não foi possível abrir uma porta de rede para o controle.';

  @override
  String get notPaired => 'Não pareado';

  @override
  String get phone => 'Celular';

  @override
  String get thatCodeDoesnt =>
      'Esse código não confere. Verifique o código na TV.';

  @override
  String get openMenuPhone =>
      'Abra Menu → Controle pelo celular na TV para parear';

  @override
  String yourAccountCantWatch(Object serverName) {
    return 'Sua conta $serverName não pode assistir à TV ao vivo';
  }

  @override
  String get enterYourServer => 'Digite o endereço do seu servidor.';

  @override
  String get needsSignIn => 'Precisa entrar';

  @override
  String get cantBeReached => 'Inacessível';

  @override
  String isNotAnswering(Object name) {
    return '$name não responde em nenhum dos endereços. Está ligado?';
  }

  @override
  String get everyServerOn =>
      'Todos os servidores desta conta Plex já estão neste perfil.';

  @override
  String get thisPlexAccount =>
      'Esta conta Plex não tem servidores. Peça ao dono do servidor para compartilhá-lo com você.';

  @override
  String quickConnectStopped(Object message) {
    return 'O Quick Connect parou: $message';
  }

  @override
  String get enterYourUsername => 'Digite seu nome de usuário.';

  @override
  String get plexDidNot => 'O Plex não trocou de usuário.';

  @override
  String plexTvError(Object statusCode) {
    return 'Erro do plex.tv $statusCode.';
  }

  @override
  String get yourPlexSign => 'Seu acesso ao Plex expirou.';

  @override
  String couldNotReachPlex(Object e) {
    return 'Não foi possível acessar o plex.tv ($e).';
  }

  @override
  String get plexTvTook => 'O plex.tv demorou demais para responder.';

  @override
  String sharedBy(Object name, Object ownerName) {
    return '$name — Compartilhado por $ownerName';
  }

  @override
  String theServerWouldNotConvert(Object transcodeDecisionText) {
    return 'O servidor não converteu este item ($transcodeDecisionText).';
  }

  @override
  String get theServerHasNo =>
      'O servidor não tem arquivo para este item. Atualize a biblioteca.';

  @override
  String didNotAnswerLike(Object serverUrl) {
    return '$serverUrl não respondeu como um servidor Plex.';
  }

  @override
  String noPlexServer(Object serverUrl, Object message) {
    return 'Nenhum servidor Plex encontrado em $serverUrl. $message';
  }

  @override
  String get thePlexSign => 'O acesso ao Plex expirou.';

  @override
  String channelIsNot(Object channelId) {
    return 'O canal $channelId não está em nenhum DVR.';
  }

  @override
  String get noSuchUser => 'Usuário inexistente.';

  @override
  String get yourCurrentPassword => 'Sua senha atual está incorreta.';

  @override
  String get signInFirst => 'Entre primeiro.';

  @override
  String thereIsAlready(Object name) {
    return 'Já existe um usuário chamado $name.';
  }

  @override
  String get thisAccountIs => 'Esta conta está desativada.';

  @override
  String get chooseAnAdmin => 'Escolha uma conta de administrador.';

  @override
  String useAtMost(Object maxNameLength) {
    return 'Use no máximo $maxNameLength caracteres no nome de usuário.';
  }

  @override
  String get enterAUser => 'Digite um nome de usuário.';

  @override
  String useAtLeast(Object minPasswordLength) {
    return 'Use pelo menos $minPasswordLength caracteres.';
  }

  @override
  String get tooManyWrong =>
      'Muitas senhas incorretas. Tente de novo em um minuto.';

  @override
  String get wrongUserName => 'Usuário ou senha incorretos.';

  @override
  String get openTheSetup => 'Abra o link de configuração no log do servidor.';

  @override
  String get makeSomeoneElse => 'Torne outra pessoa administradora primeiro.';

  @override
  String get noSuchProfile => 'Perfil inexistente.';

  @override
  String get onlyAnAdmin => 'Só um administrador pode fazer isso.';

  @override
  String get thatProfileIsnt => 'Esse perfil não foi atribuído a você.';

  @override
  String get enterAGrown =>
      'Digite o PIN de um adulto para alterar as configurações de um perfil infantil.';

  @override
  String get enterThisProfiles => 'Digite o PIN deste perfil.';

  @override
  String get reloadThePage => 'Recarregue a página e tente de novo.';

  @override
  String somethingWentWrong(Object e) {
    return 'Algo deu errado: $e';
  }

  @override
  String get signInToThisProfile => 'Entre neste perfil primeiro.';

  @override
  String get changedInAnother =>
      'Alterado em outra janela. Mostrando o mais recente.';

  @override
  String get wrongPin => 'PIN incorreto.';

  @override
  String get tooManyWrongPins =>
      'Muitos PINs incorretos. Tente de novo em um minuto.';

  @override
  String get theRoleIs => 'A função é “admin” ou “user”.';

  @override
  String get noSuchBackup => 'Backup inexistente.';

  @override
  String get backupsAreOff => 'Os backups estão desativados.';

  @override
  String get noSuchEncoder => 'Codificador inexistente.';

  @override
  String get allow1To => 'Permita de 1 a 16 transmissões.';

  @override
  String get noSuchQuality => 'Qualidade inexistente.';

  @override
  String get processorOnly => 'Somente processador';

  @override
  String get liveTvExport => 'A exportação de TV ao vivo não está em execução.';

  @override
  String get thoseArentPremiere => 'Essas não são configurações de estreias.';

  @override
  String get theLogoMode => 'O modo do logotipo é always, nowAndThen ou off.';

  @override
  String get thatIsntAPicture =>
      'Essa não é uma imagem da pasta de logotipos personalizados.';

  @override
  String couldntSaveASafety(Object e) {
    return 'Não foi possível salvar um backup de segurança antes, então nada foi redefinido: $e';
  }

  @override
  String get theKindIs => 'O tipo é “block”, “music” ou “custom”.';

  @override
  String get thatIsntAPlay => 'Essa não é uma ordem de reprodução.';

  @override
  String get musicChannelsOnly => 'Canais de música só usam ordem aleatória.';

  @override
  String get channelNumbersStart => 'Os números de canal começam em 1.';

  @override
  String get slotLengthsAre => 'As faixas duram 15, 30, 60, 90 ou 120 minutos.';

  @override
  String get thatIsntAChannel => 'Isso não é um canal.';

  @override
  String get noSuchChannel => 'Canal inexistente.';

  @override
  String get thatPictureIs => 'Essa imagem é grande demais (5 MB no máximo).';

  @override
  String get unknownAction => 'Ação desconhecida.';

  @override
  String get noSuchServer => 'Servidor inexistente.';

  @override
  String get startSigningIn => 'Comece a entrar primeiro.';

  @override
  String get aRestoreIs => 'Já há uma restauração em andamento.';

  @override
  String get uploadTheBackup => 'Envie o backup de novo.';

  @override
  String get discoveryIsOff =>
      'A descoberta está desativada, então adicione o sintonizador pelo endereço. Execute o contêiner com rede do host para ativá-la.';

  @override
  String get sendKeys => 'Envie “keys”.';

  @override
  String get enterThePlaylists =>
      'Digite o endereço da playlist ou escolha um arquivo de playlist';

  @override
  String get uploadTheFile => 'Envie o arquivo de novo.';

  @override
  String get kidProfilesGet => 'Perfis infantis não têm canais ao vivo.';

  @override
  String liveTvIsAlready(Object name) {
    return 'A TV ao vivo de $name já foi adicionada';
  }

  @override
  String get noSuchSource => 'Fonte inexistente.';

  @override
  String get thatFileIsToo => 'Esse arquivo é grande demais (32 MB no máximo).';

  @override
  String get aPinIs => 'Um PIN tem 4 dígitos.';

  @override
  String get noSuchRating => 'Classificação inexistente.';

  @override
  String get noSuchKind => 'Tipo inexistente.';

  @override
  String get onlyAnAdminCan => 'Só um administrador pode alterar isso.';

  @override
  String shouldBeA(Object key) {
    return '“$key” deve ser uma lista de texto.';
  }

  @override
  String shouldBeAn(Object key) {
    return '“$key” deve ser um objeto.';
  }

  @override
  String shouldBeTrue(Object key) {
    return '“$key” deve ser verdadeiro ou falso.';
  }

  @override
  String shouldBeANumber(Object key) {
    return '“$key” deve ser um número.';
  }

  @override
  String shouldBeText(Object key) {
    return '“$key” deve ser texto.';
  }

  @override
  String get expectedAJson => 'Esperava-se um objeto JSON.';

  @override
  String get thatIsToo => 'É coisa demais para enviar de uma vez.';

  @override
  String get aQualityLimit =>
      'Um limite de qualidade é de pelo menos 500 kbps.';

  @override
  String get orderShouldName => '“order” deve citar cada servidor uma vez.';

  @override
  String get orderIsMissing => '“order” está faltando.';

  @override
  String get signOutOf =>
      'Saia do perfil para mudar o servidor principal dele.';

  @override
  String get thoseArentPool => 'Essas não são pastas de grupo.';

  @override
  String get sendRoots => 'Envie “roots”.';

  @override
  String get thatIsntAPool => 'Esse não é um tipo de grupo.';

  @override
  String get giveThePool => 'Dê um nome ao grupo.';

  @override
  String get liveChannelsHave => 'Canais ao vivo não têm intervalos.';

  @override
  String get sendAPlan => 'Envie um plano.';

  @override
  String get thatIsntABreak => 'Esse não é um plano de intervalos.';

  @override
  String get noSuchPool => 'Grupo inexistente.';

  @override
  String get thatIsntAProgramming => 'Isso não é um bloco de programação.';

  @override
  String get noSuchBlock => 'Bloco inexistente.';

  @override
  String get sendEveryTab => 'Envie cada aba uma vez.';

  @override
  String get sendChannelids => 'Envie “channelIds”.';

  @override
  String get giveTheGroup => 'Dê um nome ao grupo.';

  @override
  String get noSuchGroup => 'Grupo inexistente.';

  @override
  String get restoringBringsBack =>
      'A restauração traz de volta seus perfis, canais, blocos e configurações. Cada perfil entra no servidor dele uma vez.';

  @override
  String channels(Object profiles, int channels) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$profiles · $channels canais',
      one: '$profiles · $channels canal',
    );
    return '$_temp0';
  }

  @override
  String get theresABackup =>
      'Há um backup da sua configuração neste dispositivo:';

  @override
  String get welcomeBack => 'Bem-vindo de volta';

  @override
  String get moveOkSelect => '◀▶ Mover    OK Selecionar';

  @override
  String get startFresh => 'Começar do zero';

  @override
  String get restoreIt => 'Restaurar';

  @override
  String get couldntRestore => 'Não foi possível restaurar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get useYourPhone => 'Usar seu celular ou computador';

  @override
  String get openABackup => 'Abrir um arquivo de backup';

  @override
  String get setUpThis =>
      'Configure esta TV a partir de um backup do Nightingale TV: seus perfis, canais, blocos e configurações. Cada perfil entra no servidor dele uma vez.';

  @override
  String get restoreFromA => 'Restaurar de um backup';

  @override
  String get close => 'Fechar';

  @override
  String get thereYouCan =>
      'Lá você pode baixar um backup desta TV ou enviar um para restaurar aqui. Tudo o que for enviado é confirmado antes nesta TV. A página fecha junto com esta janela.';

  @override
  String get onAPhone =>
      'Em um celular, tablet ou computador no mesmo Wi-Fi desta TV, escaneie o código ou abra:';

  @override
  String get couldntOpenANetwork =>
      'Não foi possível abrir uma porta de rede para a página.';

  @override
  String get thePageStopped =>
      'A página parou após 15 minutos sem atividade. Feche isto e abra de novo.';

  @override
  String and(Object namesCount, Object last) {
    return '$namesCount e $last';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String get liveTvExportMoves =>
      'A exportação de TV ao vivo passa para este dispositivo. Desative-a no antigo.';

  @override
  String willNeedTo(Object need) {
    return '$need precisará entrar no servidor de novo.';
  }

  @override
  String get itSetsUp => 'Configura esta TV como está no backup.';

  @override
  String get itReplacesEverything =>
      'Substitui tudo nesta TV. Sua configuração atual é salva em backup antes.';

  @override
  String restoreTheBackup(Object toLocal) {
    return 'Restaurar o backup de $toLocal?';
  }

  @override
  String get delete => 'Excluir';

  @override
  String get saveToFile => 'Salvar em arquivo';

  @override
  String madeOn(Object device) {
    return 'Feito em $device';
  }

  @override
  String get moveOkSelectEsc => '▲▼◀▶ Mover    OK Selecionar    ESC Voltar';

  @override
  String get backupRestore => 'Backup e restauração';

  @override
  String get backups => 'BACKUPS';

  @override
  String get backUpNow => 'Fazer backup agora';

  @override
  String get aBackupHolds =>
      'Um backup guarda cada perfil com seus canais, blocos, comerciais e configurações, e é feito todo dia em que algo muda. As senhas de acesso nunca entram nele.';

  @override
  String lastBackup(Object toLocal, Object kindLabel) {
    return 'Último backup: $toLocal ($kindLabel).';
  }

  @override
  String get noBackupsYet => 'Ainda não há backups.';

  @override
  String itCantBe(Object toLocal, Object kindLabel) {
    return '$toLocal · $kindLabel. Não será possível recuperá-lo.';
  }

  @override
  String get deleteThisBackup => 'Excluir este backup?';

  @override
  String couldntSaveThe(Object e) {
    return 'Não foi possível salvar o backup: $e';
  }

  @override
  String thatDidntWork(Object e) {
    return 'Isso não funcionou: $e';
  }

  @override
  String get aNewChannel =>
      'Um canal novo fica fora do ar fora do bloco, como um canal que sai do ar à noite.';

  @override
  String get aNewChannelJust => 'Um canal novo só para este bloco';

  @override
  String get moveOkChoose => '▲▼ Mover    OK Escolher    ESC Voltar';

  @override
  String get chooseAChannel2 => 'Escolher um canal';

  @override
  String episodes(Object keyCount) {
    return 'Episódios: $keyCount';
  }

  @override
  String get moveOkAdd => '▲▼ Mover    OK Adicionar    ESC Voltar';

  @override
  String get addAShow2 => 'Adicionar uma série';

  @override
  String get remove => 'Remover';

  @override
  String episodes2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episódios',
      one: '$count episódio',
    );
    return '$_temp0';
  }

  @override
  String get month => '+ Mês';

  @override
  String get day => '+ Dia';

  @override
  String get day2 => '− Dia';

  @override
  String get month2 => '− Mês';

  @override
  String get save => 'Salvar';

  @override
  String get everyDay => 'Todos os dias';

  @override
  String get weekends => 'Fins de semana';

  @override
  String get weekdays => 'Dias úteis';

  @override
  String get days => 'DIAS';

  @override
  String get starts => 'Início';

  @override
  String get time => 'HORÁRIO';

  @override
  String get premieresAreOff => 'As estreias estão desativadas';

  @override
  String get premieresAreOn => 'As estreias estão ativadas';

  @override
  String get onTheAir => 'NO AR';

  @override
  String get episodesAddedTo =>
      'Os episódios adicionados ao seu servidor nas últimas duas semanas estreiam em uma faixa noturna no canal da série: um episódio novo por série a cada noite, por até duas horas, marcado como NOVO. Os blocos de programação têm prioridade.';

  @override
  String get moveOkSelectEscCancel =>
      '▲▼◀▶ Mover    OK Selecionar    ESC Cancelar';

  @override
  String get newEpisodePremieres => 'Estreias de episódios novos';

  @override
  String get theChannelGoes =>
      'O canal volta à programação normal nesses horários.';

  @override
  String delete2(Object title) {
    return 'Excluir “$title”?';
  }

  @override
  String get addAnotherShow => 'Adicionar outra série';

  @override
  String get missingShow => 'Série não encontrada';

  @override
  String runsThenStarts(Object start) {
    return 'Dura $start e depois recomeça.';
  }

  @override
  String get fillsTheBlock => 'Preenche o bloco.';

  @override
  String longerThanThe(Object end, Object title) {
    return 'Maior que o bloco: termina às $end, cortando $title.';
  }

  @override
  String get onTheAirNow => 'NO AR AGORA';

  @override
  String nextAiring(Object start) {
    return 'PRÓXIMA EXIBIÇÃO · $start';
  }

  @override
  String inAll(Object runtime) {
    return '$runtime no total';
  }

  @override
  String movies2(int movies) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies filmes',
      one: '$movies filme',
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
  String get nothingYetChoose => 'Nada ainda. Escolha séries ou filmes.';

  @override
  String get nothingYetAdd => 'Nada ainda. Adicione séries à grade.';

  @override
  String get plays => 'EXIBE';

  @override
  String onLabel(Object number, Object name) {
    return 'No $number $name';
  }

  @override
  String get noChannelChosen => 'Nenhum canal escolhido';

  @override
  String get onANew => 'Em um canal novo (fora do ar nos outros horários)';

  @override
  String get untitledBlock => 'Bloco sem título';

  @override
  String get deleteBlock => 'Excluir bloco';

  @override
  String get blockIsOff => 'O bloco está desligado';

  @override
  String get blockIsOn => 'O bloco está ligado';

  @override
  String get onlyShowsAnd =>
      'Somente séries e filmes com esta classificação ou superior. Os sem classificação ficam de fora.';

  @override
  String get anyRating => 'Qualquer classificação';

  @override
  String get minimumRating => 'Classificação mínima';

  @override
  String get chooseShowsMovies => 'Escolher séries e filmes';

  @override
  String get showsAndMovies =>
      'Séries e filmes que você escolher, em ordem ou aleatórios.';

  @override
  String get yourShowsIn =>
      'Suas séries nesta ordem, cada uma exibindo o próximo episódio a cada exibição. Se sobrar tempo, a grade recomeça.';

  @override
  String get aLineup => 'Uma grade';

  @override
  String get aMix => 'Uma mistura';

  @override
  String get whatItPlays => 'O QUE EXIBE';

  @override
  String get repeatsEveryYear => 'Repete todo ano.';

  @override
  String get to => 'Até';

  @override
  String get from => 'De';

  @override
  String get onlyBetweenDates => 'Só entre datas';

  @override
  String get allYear => 'O ano todo';

  @override
  String get dates => 'DATAS';

  @override
  String get nextDay => ' (dia seguinte)';

  @override
  String get ends => 'Fim';

  @override
  String get channel => 'CANAL';

  @override
  String get saturdayMorningCartoons => 'Desenhos de sábado de manhã';

  @override
  String get title => 'Título';

  @override
  String get newProgrammingBlock => 'Novo bloco de programação';

  @override
  String get newLateNight => 'Novo bloco da madrugada';

  @override
  String get editProgrammingBlock => 'Editar bloco de programação';

  @override
  String next(Object next, Object next2) {
    return 'Próxima: $next $next2';
  }

  @override
  String get onTheAirNow2 => 'No ar agora';

  @override
  String get noUpcomingAirings => 'Nenhuma exibição futura';

  @override
  String get itsChannelIs => 'O canal dele não existe mais. Escolha um novo.';

  @override
  String get turnedOff => 'Desativado';

  @override
  String get blocksTakeOver =>
      'Os blocos assumem um canal nos dias e horários que você escolher, como os desenhos de sábado de manhã. Cada exibição continua de onde a última parou.';

  @override
  String get moveOkEdit => '▲▼ Mover    OK Editar    ESC Voltar';

  @override
  String get programmingBlocks => 'Blocos de programação';

  @override
  String get newlyAddedEpisodes =>
      'Episódios adicionados recentemente, no canal da série';

  @override
  String get onLabel2 => 'Ligado';

  @override
  String clips(Object name, int clips) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$name  ·  $clips clipes',
      one: '$name  ·  $clips clipe',
    );
    return '$_temp0';
  }

  @override
  String get n100MinMovie => 'Filme de 100 min';

  @override
  String get n44MinDrama => 'Drama de 44 min';

  @override
  String get n22MinSitcom => 'Comédia de 22 min';

  @override
  String breaksInside(int midCount) {
    String _temp0 = intl.Intl.pluralLogic(
      midCount,
      locale: localeName,
      other: ', $midCount intervalos dentro',
      one: ', $midCount intervalo dentro',
    );
    return '$_temp0';
  }

  @override
  String noBreaks(Object name) {
    return '$name: sem intervalos';
  }

  @override
  String get openAndClose =>
      'Abrem e fecham intervalos, de grupos definidos como Vinhetas';

  @override
  String get bumpers2 => 'VINHETAS';

  @override
  String get toTheHalf => 'Até a meia hora';

  @override
  String get toTheHour => 'Até a hora cheia';

  @override
  String get padsEachSlot =>
      'Completa cada faixa até o horário, para os programas começarem na hora';

  @override
  String get tail2 => 'PREENCHIMENTO';

  @override
  String get afterEachProgram => 'Depois de cada programa';

  @override
  String get postRoll2 => 'POST-ROLL';

  @override
  String get length => 'Duração';

  @override
  String get every => 'A cada';

  @override
  String min(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get breaksInsideShows =>
      'Intervalos dentro de séries e filmes, em fins de ato quando encontrados';

  @override
  String get midRoll2 => 'MID-ROLL';

  @override
  String get beforeEachProgram => 'Antes de cada programa';

  @override
  String get preRoll2 => 'PRE-ROLL';

  @override
  String get onePool => 'Um grupo…';

  @override
  String get allBumperPools => 'Todos os grupos de vinhetas';

  @override
  String get none => 'Nenhum';

  @override
  String clipsFrom(Object pool) {
    return 'Clipes de: $pool';
  }

  @override
  String get allPools => 'Todos os grupos';

  @override
  String clips2(Object label) {
    return 'Clipes de $label';
  }

  @override
  String get leave => 'Sair';

  @override
  String get yourChangesTo =>
      'Suas alterações nas configurações de intervalo serão perdidas.';

  @override
  String get leaveWithoutSaving => 'Sair sem salvar?';

  @override
  String get size => 'Tamanho';

  @override
  String get captions => 'Legendas';

  @override
  String get sampleCaption => 'Exemplo de legenda';

  @override
  String get theServerDraws =>
      'O servidor desenha estas legendas na imagem, então o tamanho delas não pode mudar aqui.';

  @override
  String get findingSubtitles => 'Buscando legendas…';

  @override
  String get noSubtitlesFor => 'Sem legendas para este programa';

  @override
  String hrMin(Object inHours, Object inMinutes) {
    return '$inHours h $inMinutes min';
  }

  @override
  String days2(Object toStringAsFixed) {
    return '$toStringAsFixed dias';
  }

  @override
  String get theChannelGoesAway =>
      'O canal é removido, junto com seus blocos de programação e seus lugares nos grupos de canais.';

  @override
  String remove2(Object name) {
    return 'Remover “$name”?';
  }

  @override
  String contentOf(Object name) {
    return 'Conteúdo de $name';
  }

  @override
  String get newChannel => 'Novo canal';

  @override
  String get defaultCard => 'Cartão padrão';

  @override
  String get changeOfflineImage => 'Alterar imagem fora do ar…';

  @override
  String get offlineImage2 => 'Imagem fora do ar…';

  @override
  String fillerPool(Object poolName) {
    return 'Grupo de preenchimento: $poolName';
  }

  @override
  String get slotLength => 'DURAÇÃO DA FAIXA';

  @override
  String get hideFromGuide => 'Ocultar do guia';

  @override
  String get showInGuide => 'Mostrar no guia';

  @override
  String get favorite => 'Favoritar';

  @override
  String get unfavorite => 'Desfavoritar';

  @override
  String mainSetting(Object label) {
    return 'Configuração principal ($label)';
  }

  @override
  String get channelLogo => 'LOGOTIPO DO CANAL';

  @override
  String breaksOn(Object name) {
    return 'Intervalos em $name';
  }

  @override
  String get custom2 => 'Personalizado…';

  @override
  String get commercials2 => 'COMERCIAIS';

  @override
  String get removeChannel => 'Remover canal';

  @override
  String get reshuffle => 'Embaralhar de novo';

  @override
  String get editContent => 'Editar conteúdo';

  @override
  String get number => 'Número +';

  @override
  String get number2 => 'Número −';

  @override
  String get sourcesLogo => 'Logotipo da fonte';

  @override
  String get changeIcon => 'Alterar ícone';

  @override
  String get rename => 'Renomear';

  @override
  String get channelName => 'Nome do canal';

  @override
  String programmingBlocks2(int blockCount) {
    String _temp0 = intl.Intl.pluralLogic(
      blockCount,
      locale: localeName,
      other: '$blockCount blocos de programação',
      one: '$blockCount bloco de programação',
    );
    return '$_temp0';
  }

  @override
  String repeatsEvery(Object loop) {
    return 'repete a cada $loop';
  }

  @override
  String programs(Object playlistCount) {
    return 'Programas: $playlistCount';
  }

  @override
  String get programmingBlocksOnly => 'Somente blocos de programação';

  @override
  String channelThere(Object n) {
    return 'canal $n lá';
  }

  @override
  String channel2(Object number) {
    return 'CANAL $number';
  }

  @override
  String get noChannelsYet => 'Ainda não há canais';

  @override
  String get guideRange => 'ALCANCE DO GUIA';

  @override
  String get channelsEditOk =>
      '▲▼ Canais    ▶ Editar    OK Selecionar    ESC Voltar';

  @override
  String get channelsIcons => 'Canais e ícones';

  @override
  String get howFarAhead => 'Até onde o guia mostra, a partir de agora.';

  @override
  String hours(Object hours) {
    return '$hours horas';
  }

  @override
  String get theChannelLogo =>
      'O logotipo do canal no canto da imagem, na TV e na exportação de TV ao vivo.';

  @override
  String get name => 'Nome';

  @override
  String get ok => 'OK';

  @override
  String get channels2 => 'CANAIS';

  @override
  String get groupName => 'Nome do grupo';

  @override
  String group(Object name) {
    return 'Grupo: $name';
  }

  @override
  String get deleteGroup => 'Excluir grupo';

  @override
  String get itsTabLeaves =>
      'A aba sai do guia. Os canais continuam na sua grade.';

  @override
  String channels3(int membersCount) {
    String _temp0 = intl.Intl.pluralLogic(
      membersCount,
      locale: localeName,
      other: '$membersCount canais',
      one: '$membersCount canal',
    );
    return '$_temp0';
  }

  @override
  String get channelsYouPicked => 'Canais que você escolheu.';

  @override
  String get theTabsAt =>
      'As abas no topo do guia, nesta ordem. Abas ocultas e abas sem canais não aparecem.';

  @override
  String get channelGroups => 'Grupos de canais';

  @override
  String get shown => 'Visível';

  @override
  String get down => 'Descer';

  @override
  String get up => 'Subir';

  @override
  String get automatic2 => '· automático';

  @override
  String channels4(Object channelIdsCount) {
    return '· Canais: $channelIdsCount';
  }

  @override
  String get create => 'Criar';

  @override
  String get commercialsNeverShow =>
      'Os comerciais nunca aparecem no histórico do seu servidor.';

  @override
  String get theSameAds => 'Os mesmos comerciais passam para todos, sempre.';

  @override
  String get bumperPoolsClips =>
      'Os clipes dos grupos de vinhetas abrem e fecham intervalos, e nunca passam como comerciais.';

  @override
  String get howBreaksWork => 'COMO FUNCIONAM OS INTERVALOS';

  @override
  String get withATail =>
      'Com preenchimento, as faixas são completadas até o horário.';

  @override
  String get adsShrinkTo =>
      'Os comerciais se ajustam à faixa, e nenhum intervalo passa de 5 minutos.';

  @override
  String get aShortBreak =>
      'Um intervalo curto antes do programa, um intervalo a cada 10 minutos durante (12 em filmes), em fins de ato quando encontrados, e o resto depois.';

  @override
  String get pickAutomaticFor =>
      'Escolha Automático para intervalos como na TV aberta, ou Personalizado para configurá-los você mesmo.';

  @override
  String workingOn(Object current) {
    return 'Processando $current…';
  }

  @override
  String get analysis => 'ANÁLISE';

  @override
  String couldNotBe(Object failed) {
    return '$failed não puderam ser analisados (nova tentativa se o arquivo mudar)';
  }

  @override
  String programsWithBreak(Object programsDone, Object programsTotal) {
    return 'Programas com pontos de intervalo: $programsDone de $programsTotal';
  }

  @override
  String longVideosSplit(Object reelsDone, Object reelsTotal) {
    return 'Vídeos longos divididos: $reelsDone de $reelsTotal';
  }

  @override
  String folders(int folders, Object idCount) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders pastas  ·  $idCount',
      one: '$folders pasta  ·  $idCount',
    );
    return '$_temp0';
  }

  @override
  String fromCommercialPools(Object clips, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$clips de $used grupos de comerciais.',
      one: '$clips de $used grupo de comerciais.',
    );
    return '$_temp0';
  }

  @override
  String get breaksStartOnce =>
      'Os intervalos começam quando um grupo tem clipes. Adicione pastas com vídeos a um grupo.';

  @override
  String get breaksStartOnceA =>
      'Os intervalos começam quando um grupo tem clipes. Os vídeos longos dele estão sendo divididos agora.';

  @override
  String get breaksStartOnceAPool =>
      'Os intervalos começam quando um grupo tem clipes. Crie um grupo abaixo.';

  @override
  String breaksAreOff(Object clips) {
    return 'Os intervalos estão desligados. $clips prontos nos seus grupos.';
  }

  @override
  String get breaksAreOff2 => 'Os intervalos estão desligados.';

  @override
  String clips3(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n clipes',
      one: '$n clipe',
    );
    return '$_temp0';
  }

  @override
  String lastScanFailed(Object syncError) {
    return 'A última análise falhou: $syncError';
  }

  @override
  String get newPool => 'Novo grupo';

  @override
  String get pickTheFolders =>
      'Escolha as pastas do seu servidor com comerciais e vinhetas. Os vídeos delas saem dos seus canais normais e preenchem os intervalos. Defina o tipo de um grupo como Vinhetas para que os clipes dele abram e fechem intervalos.';

  @override
  String get pools => 'GRUPOS';

  @override
  String get breakSettings => 'Configurações de intervalo…';

  @override
  String get commercialBreaks => 'INTERVALOS COMERCIAIS';

  @override
  String get breakSettings2 => 'Configurações de intervalo';

  @override
  String breakPointsAlso(Object ffmpegWarning, Object count) {
    return '$ffmpegWarning$count Os pontos de intervalo também ficam mais naturais com ele.';
  }

  @override
  String waiting(Object waiting) {
    return ' ($waiting aguardando).';
  }

  @override
  String get longCommercialVideos =>
      'Vídeos longos de comerciais sem capítulos não podem ser divididos neste dispositivo';

  @override
  String get installFfmpegTo =>
      'Instale o ffmpeg para dividir vídeos longos de comerciais';

  @override
  String get picturesOnThis =>
      'Imagens neste dispositivo, as mais novas primeiro. As grandes são reduzidas para 512 px.';

  @override
  String get noPicturesOn =>
      'Ainda não há imagens neste dispositivo. Copie um PNG ou JPG para a pasta Download ou para um pendrive e tente de novo.';

  @override
  String get lookingForPictures => 'Procurando imagens…';

  @override
  String get couldntReadThePictures =>
      'Não foi possível ler as imagens deste dispositivo.';

  @override
  String get nightingaleTvIsnt =>
      'O Nightingale TV não tem permissão para ver as imagens deste dispositivo. Permita “Fotos e vídeos” em Configurações do Android › Apps › Nightingale TV › Permissões e tente de novo.';

  @override
  String get moveOkChooseEsc => '◀▶▲▼ Mover    OK Escolher    ESC Cancelar';

  @override
  String get chooseAPicture => 'Escolher uma imagem';

  @override
  String thePoolHasnt(Object error) {
    return '$error  O grupo não mudou.';
  }

  @override
  String nothingHasChanged(Object error) {
    return '$error  Nada mudou.';
  }

  @override
  String get couldntReachTheServer => 'Não foi possível acessar o servidor';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get nothingInside => 'Vazio';

  @override
  String get noMovies => 'Sem filmes';

  @override
  String inside(Object childrenCount) {
    return '$childrenCount dentro';
  }

  @override
  String get video => 'Vídeo';

  @override
  String collection(Object name) {
    return '$name (coleção)';
  }

  @override
  String get included => 'Incluído';

  @override
  String get nothingInside2 => 'Vazio.';

  @override
  String get loadingFolders => 'Carregando pastas…';

  @override
  String get pressOnA => 'Pressione ▶ em uma biblioteca para ver o conteúdo.';

  @override
  String get done => 'Concluído';

  @override
  String ticked(Object _pickedCount) {
    return '$_pickedCount marcados';
  }

  @override
  String get nothingTickedYet =>
      'Nada marcado ainda. Marque uma biblioteca para usar tudo, ou ▶ para escolher o conteúdo.';

  @override
  String get wholeLibrary => 'Biblioteca inteira';

  @override
  String get libraries => 'BIBLIOTECAS';

  @override
  String get loadingLibraries => 'Carregando bibliotecas…';

  @override
  String get moveOkTick =>
      '▲▼ Mover    OK Marcar    ▶ Abrir    ◀ Voltar nível    ESC Cancelar';

  @override
  String foldersFor(Object poolName) {
    return 'Pastas de $poolName';
  }

  @override
  String get chooseFolders => 'Escolher pastas';

  @override
  String get chooseWhatPlays => 'Escolha o que passa neste canal';

  @override
  String get endsEarly => 'Termina antes';

  @override
  String get madeFromThis =>
      'Feito com as séries e os filmes deste canal e atualizado com a biblioteca. Altere qualquer coisa e ele passa a ser seu.';

  @override
  String get fromTheLineup => 'Da grade';

  @override
  String yesterday(Object t) {
    return 'ontem $t';
  }

  @override
  String today(Object t) {
    return 'hoje $t';
  }

  @override
  String behind(Object d) {
    return '$d de atraso';
  }

  @override
  String hr(Object h) {
    return '$h h';
  }

  @override
  String get underAMinute => 'menos de um minuto';

  @override
  String get noProgramming => 'Sem programação';

  @override
  String get today2 => 'HOJE';

  @override
  String get tuning => 'SINTONIZANDO…';

  @override
  String get offAir2 => 'FORA DO AR';

  @override
  String get noSignal => 'SEM SINAL';

  @override
  String left(Object now) {
    return 'Faltam $now';
  }

  @override
  String get nothingScheduled => 'Nada programado';

  @override
  String get back => 'Voltar';

  @override
  String get sleep => 'Dormir';

  @override
  String get menu => 'Menu';

  @override
  String get nightingaleTvGuide => 'GUIA NIGHTINGALE TV';

  @override
  String nowPlaying(Object title) {
    return 'Tocando agora: $title';
  }

  @override
  String get mMenu => 'M Menu';

  @override
  String get escBackTo => 'ESC Voltar à TV';

  @override
  String get channelsTabsTime =>
      '▲▼ Canais     ▲ Abas     ◀▶ Horário     OK Assistir     ';

  @override
  String get color => 'Cor';

  @override
  String get channelsUsingIt =>
      'Os canais que o usam voltam a um ícone padrão.';

  @override
  String get deleteThisIcon => 'Excluir este ícone?';

  @override
  String get uploadImage => 'Enviar imagem…';

  @override
  String get pngJpgWebp =>
      'PNG, JPG, WebP, GIF ou SVG. Imagens grandes são reduzidas automaticamente para 512 px.';

  @override
  String get genericBadgesOnly =>
      'Somente emblemas genéricos. Envie um logotipo real em “Meus ícones”.';

  @override
  String get tv => 'TV';

  @override
  String get useThisBadge => 'Usar este emblema';

  @override
  String get preview => 'Prévia';

  @override
  String get shape => 'Forma';

  @override
  String get callLettersUp => 'Letras de chamada (até 5)';

  @override
  String iconFor(Object name) {
    return 'Ícone de $name';
  }

  @override
  String get couldntReadThat =>
      'Não foi possível ler essa imagem. Tente outra.';

  @override
  String get myIcons => 'Meus ícones';

  @override
  String get showLogos => 'Logotipos de séries';

  @override
  String get badges => 'Emblemas';

  @override
  String get builtIn => 'Incluídos';

  @override
  String get couldntMoveThe => 'Não foi possível transferir a configuração';

  @override
  String get send => 'Enviar';

  @override
  String thisBacksUp(Object counterpartName) {
    return 'Isso faz agora um backup dos seus perfis, canais e configurações e os abre em $counterpartName, que pergunta antes de restaurar. Nada muda aqui.';
  }

  @override
  String sendYourSetup(Object counterpartName) {
    return 'Enviar sua configuração para $counterpartName?';
  }

  @override
  String get parentalControls => 'Controle dos pais';

  @override
  String get notNow => 'Agora não';

  @override
  String bringMySetup(Object counterpartName) {
    return 'Trazer minha configuração de $counterpartName';
  }

  @override
  String moveMySetup(Object counterpartName) {
    return 'Transferir minha configuração para $counterpartName';
  }

  @override
  String get uninstallingEitherOne =>
      'Desinstalar qualquer um deles antes de transferir a configuração que você quer manter apaga essa configuração.';

  @override
  String andAreSeparate(Object appName, Object counterpartName) {
    return '$appName e $counterpartName são apps separados, cada um com seus próprios perfis, canais e configurações.';
  }

  @override
  String get thankYouFor => 'Obrigado por apoiar o Nightingale TV!';

  @override
  String isAlsoOn(Object counterpartName) {
    return '$counterpartName também está neste dispositivo';
  }

  @override
  String get aboutThisInstall => 'SOBRE ESTA INSTALAÇÃO';

  @override
  String couldntOpen(Object counterpartName) {
    return 'Não foi possível abrir $counterpartName.';
  }

  @override
  String get nothingIsSet =>
      'Ainda não há nada configurado aqui, então não há configuração para transferir.';

  @override
  String yourSetupIs(Object counterpartName) {
    return 'Sua configuração está a caminho de $counterpartName';
  }

  @override
  String get guide => 'GUIA';

  @override
  String ofLabel(Object n, Object keysCount) {
    return '$n de $keysCount';
  }

  @override
  String get saving => 'Salvando…';

  @override
  String ofChosen(Object _checkedCount, Object total) {
    return '$_checkedCount de $total escolhidos';
  }

  @override
  String get channelOrGroup => 'Nome do canal ou grupo';

  @override
  String get search => 'Buscar';

  @override
  String get moveOkCheck => '▲▼ Mover    OK Marcar    ESC Voltar';

  @override
  String chooseChannels(Object name) {
    return 'Escolher canais: $name';
  }

  @override
  String get add => 'Adicionar';

  @override
  String get readingThePlaylist => 'Lendo a playlist…';

  @override
  String nowThePlaylists(Object guideUrl) {
    return 'Agora: o guia da playlist, $guideUrl';
  }

  @override
  String get leaveEmptyTo =>
      'Deixe vazio para usar o guia indicado pela playlist';

  @override
  String get xmltvGuideAddress => 'Endereço do guia XMLTV';

  @override
  String get guideOptional => 'GUIA (OPCIONAL)';

  @override
  String get httpProviderExample =>
      'http://provedor.example/get.php?username=…&type=m3u_plus';

  @override
  String get playlistAddress => 'Endereço da playlist';

  @override
  String get playlist => 'PLAYLIST';

  @override
  String get myIptv => 'Meu IPTV';

  @override
  String get useAnAddress => 'Usar um endereço em vez disso';

  @override
  String get chooseAFile => 'Escolher um arquivo';

  @override
  String get chooseAnotherFile => 'Escolher outro arquivo';

  @override
  String get moveOkSelectEscBack => '▲▼ Mover    OK Selecionar    ESC Voltar';

  @override
  String edit(Object name) {
    return 'Editar $name';
  }

  @override
  String get addAnM3u => 'Adicionar uma playlist M3U';

  @override
  String get m3uPlaylists => 'Playlists M3U';

  @override
  String get xmltvGuides => 'Guias XMLTV';

  @override
  String get anIptvPlaylist =>
      'Uma playlist IPTV (endereço da web ou arquivo), com guia XMLTV se você tiver um.';

  @override
  String get theChannelsAnd =>
      'Os canais e o guia do sintonizador do seu servidor (antena, decodificador ou IPTV).';

  @override
  String readingSChannels(Object server) {
    return 'Lendo os canais de $server…';
  }

  @override
  String checkingLiveTv(Object server) {
    return 'Verificando a TV ao vivo de $server…';
  }

  @override
  String get addALive => 'Adicionar uma fonte de TV ao vivo';

  @override
  String get itsChannelsLeave =>
      'Os canais dela saem do guia, dos grupos e dos favoritos.';

  @override
  String get renameSource => 'Renomear fonte';

  @override
  String get edit2 => 'Editar';

  @override
  String get refreshNow => 'Atualizar agora';

  @override
  String get chooseChannels2 => 'Escolher canais';

  @override
  String get playlistFile => 'Arquivo da playlist';

  @override
  String get notRefreshedYet => 'Ainda não atualizado';

  @override
  String refreshed(Object lastRefresh) {
    return 'Atualizado $lastRefresh';
  }

  @override
  String lastRefreshFailed(Object lastError) {
    return 'A última atualização falhou: $lastError';
  }

  @override
  String get refreshing => 'Atualizando…';

  @override
  String ofChannels(Object label, Object keyCount, Object channelsCount) {
    return '$label · Canais: $keyCount de $channelsCount';
  }

  @override
  String get noSourcesYet => 'Ainda não há fontes.';

  @override
  String get addSource => 'Adicionar fonte';

  @override
  String get realBroadcastsAnd =>
      'Transmissões reais e IPTV no seu guia: a TV ao vivo do seu servidor ou uma playlist M3U com guia XMLTV. Os canais entram na grade depois dos seus.';

  @override
  String notStreamingOf(Object runningCount, Object streamLimit) {
    return 'Sem transmissão. $runningCount de $streamLimit transmissões em uso.';
  }

  @override
  String get savePort => 'Salvar porta';

  @override
  String get port => 'Porta';

  @override
  String get xmltv => 'XMLTV';

  @override
  String get tuner => 'Sintonizador';

  @override
  String get enterAPort => 'Digite um número de porta.';

  @override
  String pinFor(Object name) {
    return 'PIN de $name';
  }

  @override
  String get letPlexFind => 'Deixar o Plex encontrar automaticamente';

  @override
  String get discovery => 'DESCOBERTA';

  @override
  String get encoder => 'CODIFICADOR';

  @override
  String nowAtOnce(Object streamLimit) {
    return 'Agora: $streamLimit ao mesmo tempo. Cada canal assistido em outro lugar é uma transmissão.';
  }

  @override
  String get streamsAtOnce => 'TRANSMISSÕES SIMULTÂNEAS';

  @override
  String get quality => 'QUALIDADE';

  @override
  String get lineups => 'GRADES';

  @override
  String get liveTvExport2 => 'Exportação de TV ao vivo';

  @override
  String get automaticDiscoveryIsnt =>
      'A descoberta automática não está disponível neste PC. Adicione o sintonizador no Plex ou no Jellyfin pelo endereço.';

  @override
  String get anyoneOnYour =>
      'Qualquer pessoa na sua rede doméstica pode assistir a esta grade.';

  @override
  String get watchYourChannels =>
      'Assista aos seus canais no Plex, no Jellyfin ou em qualquer app de IPTV na sua rede doméstica. O Nightingale TV precisa ficar aberto para eles funcionarem.';

  @override
  String get offline => 'Off-line';

  @override
  String get online => 'On-line';

  @override
  String get added => 'Adicionado';

  @override
  String get chooseAServer => 'Escolher um servidor';

  @override
  String get whosSigningIn => 'Quem está entrando?';

  @override
  String get openPlexTv => 'Abrir plex.tv/link';

  @override
  String get waitingForThe => 'Aguardando o código ser vinculado…';

  @override
  String get goToPlex =>
      'Acesse plex.tv/link no seu celular ou computador e digite este código.';

  @override
  String get signInWith => 'Entrar com Plex';

  @override
  String get waitingForApproval => 'Aguardando aprovação…';

  @override
  String onYourPhone(Object label) {
    return 'No seu celular ou computador, abra $label → seu perfil → Quick Connect e digite este código:';
  }

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get signIn => 'Entrar';

  @override
  String get password => 'Senha';

  @override
  String get username => 'Usuário';

  @override
  String signInTo2(Object name) {
    return 'Entrar em $name';
  }

  @override
  String get differentServer => 'Outro servidor';

  @override
  String get signInWithPassword => 'Entrar com senha';

  @override
  String get quickConnectUse => 'Quick Connect (use seu celular)';

  @override
  String get connect => 'Conectar';

  @override
  String get serverAddress => 'Endereço do servidor';

  @override
  String get connectToYour => 'Conecte-se ao seu servidor';

  @override
  String get nightingaleTvTurns =>
      'O Nightingale TV transforma sua biblioteca Jellyfin, Emby ou Plex em canais sempre no ar, com guia de programação. Troque de canal e veja o que estiver passando.';

  @override
  String get yourLibraryOn => 'Sua biblioteca.\nNo ar, 24 horas.';

  @override
  String get welcomeToNightingale => 'Bem-vindo ao Nightingale TV';

  @override
  String signInFor(Object name) {
    return 'Entrar por $name';
  }

  @override
  String signInToAgain(Object name) {
    return 'Entrar em $name de novo';
  }

  @override
  String get addAServer => 'Adicionar um servidor';

  @override
  String foundNewPrograms(Object list) {
    return 'Encontrado: $list. Os programas novos começam nos canais logo depois do que está passando.';
  }

  @override
  String get libraryRefreshed => 'Biblioteca atualizada';

  @override
  String get nothingNew => 'Nada novo';

  @override
  String get yourChannelsAre => 'Seus canais estão atualizados.';

  @override
  String get refreshFailed => 'A atualização falhou';

  @override
  String get moveOkSelectEscBackTo =>
      '▲▼ Mover    OK Selecionar    ESC Voltar à TV';

  @override
  String get noPoolsYet => 'ainda sem grupos';

  @override
  String updatedAt(Object fetchedAt, Object fetchedAt2) {
    return 'Atualizado em $fetchedAt às $fetchedAt2';
  }

  @override
  String get libraryLabel => 'BIBLIOTECA';

  @override
  String get account => 'CONTA';

  @override
  String get watching => 'ASSISTINDO';

  @override
  String get exitNightingaleTv => 'Sair do Nightingale TV';

  @override
  String get signOut => 'Sair da conta';

  @override
  String get yourChannelLineup =>
      'Sua grade de canais é apagada. Os ícones personalizados são mantidos.';

  @override
  String get signOut2 => 'Sair da conta?';

  @override
  String get fullScreenOn => 'Tela cheia sim/não (F11)';

  @override
  String get nothingWasReset => 'Nada foi redefinido';

  @override
  String get reset => 'Redefinir';

  @override
  String get rebuildsTheDefault =>
      'Recria os canais padrão a partir da sua biblioteca. Nomes, ícones e números alterados são redefinidos. Os canais que você adicionou são mantidos. Antes é salvo um backup, para você poder recuperá-los em Backup e restauração.';

  @override
  String get resetChannelLineup => 'Redefinir a grade de canais?';

  @override
  String get resetChannelLineup2 => 'Redefinir a grade de canais';

  @override
  String get refreshLibrary => 'Atualizar biblioteca';

  @override
  String get refreshingLibrary => 'Atualizando biblioteca…';

  @override
  String get servers => 'Servidores';

  @override
  String get phoneRemote => 'Controle pelo celular';

  @override
  String get profiles => 'Perfis';

  @override
  String get retroLook => 'Visual retrô';

  @override
  String get playback => 'Reprodução';

  @override
  String get switchProfile => 'Trocar de perfil';

  @override
  String get sleepTimer => 'Timer de sono';

  @override
  String get backToTv => 'Voltar à TV';

  @override
  String get removeAll => 'Remover todos';

  @override
  String pairedLastUsed(Object paired, Object lastUsed) {
    return 'pareado $paired · último uso $lastUsed';
  }

  @override
  String get noPhonesPaired => 'Nenhum celular pareado ainda.';

  @override
  String get pairedPhones => 'CELULARES PAREADOS';

  @override
  String get blockedByThis => 'Bloqueado pelo firewall deste computador';

  @override
  String get someWiFi =>
      'Algumas redes Wi-Fi mantêm os dispositivos separados (isolamento de AP ou cliente). Se o celular ainda não conectar, desative essa opção no seu Wi-Fi.';

  @override
  String get thePhoneHas =>
      'O celular precisa estar no mesmo Wi-Fi desta TV, não em uma rede de convidados nem nos dados móveis.';

  @override
  String get ifThePhone =>
      'Se o celular não conectar, talvez o firewall deste computador esteja bloqueando. Abra um terminal neste computador e execute:';

  @override
  String get checkAgain => 'Verificar de novo';

  @override
  String get thenChooseCheck => 'Depois escolha Verificar de novo.';

  @override
  String get thisComputersFirewall =>
      'O firewall deste computador impede que os celulares alcancem o controle. Para liberá-los, abra um terminal neste computador e execute:';

  @override
  String get notConfirmedYet =>
      'Ainda não confirmado · nenhum celular conectou';

  @override
  String get working => 'Funcionando';

  @override
  String workingLastUsed(Object name, Object lastUsed) {
    return 'Funcionando · último uso por $name, $lastUsed';
  }

  @override
  String get theRemoteIs => 'O controle está desligado.';

  @override
  String get orScanThe => 'ou escaneie o código com a câmera do celular.';

  @override
  String get andEnter => 'e digite  ';

  @override
  String get onYourPhoneOpen => 'NO SEU CELULAR, ABRA';

  @override
  String get useYourPhoneAs =>
      'Use seu celular como controle: abra uma página nele para trocar de canal, abrir o guia ou tocar em um canal para sintonizar. Nada para instalar.';

  @override
  String get everyPairedPhone =>
      'Cada celular pareado deixa de funcionar como controle até escanear de novo o código nesta tela.';

  @override
  String get removeAllPhones => 'Remover todos os celulares?';

  @override
  String get thoseDidntMatch => 'Não conferem. Tente de novo.';

  @override
  String get enterTheSame => 'Digite os mesmos 4 dígitos de novo.';

  @override
  String get choose4Digits => 'Escolha 4 dígitos.';

  @override
  String get thatPinIsnt => 'Esse PIN não está certo. Tente de novo.';

  @override
  String get clock => 'RELÓGIO';

  @override
  String get captions2 => 'LEGENDAS';

  @override
  String get audio => 'ÁUDIO';

  @override
  String get maximumStreamingBitrate => 'TAXA DE BITS MÁXIMA';

  @override
  String get converting => 'CONVERSÃO';

  @override
  String get afterThisLong =>
      'Depois desse tempo sem apertar nenhum botão, o Nightingale TV pergunta se tem alguém assistindo. Sem resposta em um minuto, ele dorme: a reprodução para e seu servidor deixa de transmitir. Não enquanto um timer de sono estiver ativo.';

  @override
  String get askIfIm => 'Perguntar se ainda estou assistindo';

  @override
  String get liveTvStill => 'A TV ao vivo continua aparecendo no painel.';

  @override
  String get offWhatYou =>
      'Desligado: o que você assiste aqui nunca muda contagens de reprodução, marcas de assistido ou pontos de retomada no seu servidor, e não aparece no painel dele.';

  @override
  String get pauseSkipAnd =>
      'Pause, pule e reinicie o que está passando. Desligado: todo canal segue o horário, como a TV sempre no ar.';

  @override
  String get pauseAndRewind => 'Pausar e voltar';

  @override
  String get showsTheTime => 'Mostra a hora no canto da imagem.';

  @override
  String get onScreenClock => 'Relógio na tela';

  @override
  String get showACountdown =>
      'Mostra uma contagem regressiva antes do início dos comerciais e antes da volta do programa.';

  @override
  String get breakNotices => 'Avisos de intervalo';

  @override
  String get theSizeOf =>
      'O tamanho das legendas em todos os programas e canais.';

  @override
  String get whileItsOn =>
      'Enquanto estiver ligado, o áudio surround (Dolby, DTS) é decodificado por este dispositivo em vez de ser enviado a um receiver.';

  @override
  String get evensOutThe =>
      'Equilibra o volume enquanto você assiste: comerciais e programas altos abaixam e os baixos aumentam, sem você precisar pegar o controle.';

  @override
  String get volumeLeveling => 'Nivelamento de volume';

  @override
  String get pickALower =>
      'Escolha uma taxa de bits menor se os programas travarem no Wi-Fi ou em conexão remota. Original nunca converte por causa da taxa de bits.';

  @override
  String get connectedThroughPlex =>
      'Conectado pelo Plex Relay: a qualidade é limitada.';

  @override
  String get offNightingaleTv =>
      'Desligado: o Nightingale TV sempre reproduz seus arquivos originais em qualidade total, e seu servidor não faz trabalho extra. Ligado: seu servidor converte uma série ou filme só quando passa da taxa de bits máxima ou quando o arquivo original não reproduz. A conversão usa o processador ou a placa de vídeo do seu servidor. Os comerciais sempre reproduzem os arquivos originais.';

  @override
  String get transcodeOnlyIf => 'Converter só se necessário (experimental)';

  @override
  String get longerVideosAd =>
      'Vídeos mais longos (compilações de comerciais) são divididos em seus comerciais, nos capítulos ou onde a imagem fica preta e em silêncio.';

  @override
  String get videosOf5 => 'Vídeos de 5 segundos a 3 minutos são um clipe cada.';

  @override
  String get commercialsFillBreaks =>
      'Comerciais preenchem os intervalos. Defina o tipo como Vinhetas para identidades de canal e clipes de “já voltamos”.';

  @override
  String get bumpersTakeAt =>
      'As vinhetas ocupam no máximo metade de um intervalo, exceto em um pre-roll. Uma longa demais é ignorada.';

  @override
  String stillToSplit(Object unsplit) {
    return '$unsplit para dividir';
  }

  @override
  String longOnesSplit(int reelsCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reelsCount,
      locale: localeName,
      other: '$reelsCount longos divididos em clipes',
      one: '$reelsCount longo dividido em clipes',
    );
    return '$_temp0';
  }

  @override
  String get deletePool => 'Excluir grupo';

  @override
  String get addFolders => 'Adicionar pastas…';

  @override
  String get libraryLabel2 => 'Biblioteca';

  @override
  String get noFoldersYet => 'Ainda não há pastas.';

  @override
  String get folders2 => 'PASTAS';

  @override
  String get type => 'TIPO';

  @override
  String get poolName => 'Nome do grupo';

  @override
  String get commercialPool => 'Grupo de comerciais';

  @override
  String get itsVideosGo =>
      'Os vídeos voltam aos seus canais normais. Os intervalos que usavam este grupo passam a usar todos.';

  @override
  String get now => 'Agora';

  @override
  String get watch => 'Assistir';

  @override
  String get tuning2 => 'Sintonizando…';

  @override
  String get fullScreen => 'Tela cheia';

  @override
  String get noChannels => 'Sem canais';

  @override
  String get theirChannelsProgramming =>
      'Os canais, blocos de programação e configurações são excluídos, e esta TV sai do servidor desse perfil.';

  @override
  String delete3(Object name) {
    return 'Excluir $name?';
  }

  @override
  String get giveTheProfile => 'Dê um nome ao perfil.';

  @override
  String get deleteProfile => 'Excluir perfil';

  @override
  String get removePin => 'Remover PIN';

  @override
  String get setAPin => 'Definir um PIN';

  @override
  String get changePin => 'Alterar PIN';

  @override
  String get noPinAnyone => 'Sem PIN. Qualquer pessoa pode abrir este perfil.';

  @override
  String get lockedThePin =>
      'Bloqueado. É preciso o PIN para abrir este perfil.';

  @override
  String get pin => 'PIN';

  @override
  String get showsAndMoviesWith =>
      'Séries e filmes sem classificação ficam de fora.';

  @override
  String get allowedToWatch => 'PODE ASSISTIR';

  @override
  String get kid => 'Criança';

  @override
  String get grownUp => 'Adulto';

  @override
  String get whoItsFor => 'PARA QUEM É';

  @override
  String get color2 => 'COR';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get newProfile => 'Novo perfil';

  @override
  String get watchingNow => 'Assistindo agora';

  @override
  String get noPin => 'Sem PIN';

  @override
  String get pinLocked => 'Bloqueado por PIN';

  @override
  String kid2(Object label, Object description) {
    return 'Criança · $label ($description)';
  }

  @override
  String get addProfile => 'Adicionar perfil';

  @override
  String get everyoneGetsTheir =>
      'Cada pessoa tem seu próprio acesso ao servidor, canais e blocos de programação. Perfis infantis só veem séries e filmes adequados à idade.';

  @override
  String enterSPin(Object name) {
    return 'Digite o PIN de $name';
  }

  @override
  String get whosWatching => 'Quem está assistindo?';

  @override
  String get moveOkChoose2 => '◀▶ Mover    OK Escolher';

  @override
  String get enterAGrownUps => 'Digite o PIN de um adulto.';

  @override
  String get grownUpsOnly => 'Só para adultos';

  @override
  String get yourChannelYour => 'Seu canal, seu visual';

  @override
  String get testPattern => 'Padrão de teste';

  @override
  String get upNext8 => 'A SEGUIR  ·  20:00';

  @override
  String get thisDevice => 'ESTE DISPOSITIVO';

  @override
  String get glow => 'BRILHO';

  @override
  String get curvature => 'CURVATURA';

  @override
  String get vignette => 'VINHETA';

  @override
  String get mask => 'MÁSCARA';

  @override
  String get lines => 'LINHAS';

  @override
  String get scanlines => 'LINHAS DE VARREDURA';

  @override
  String get customCrtStyle => 'ESTILO CRT PERSONALIZADO';

  @override
  String accent(Object label) {
    return 'DESTAQUE ($label)';
  }

  @override
  String get overlayTheme => 'TEMA DE SOBREPOSIÇÃO';

  @override
  String get crtEffect => 'EFEITO CRT';

  @override
  String get surround => 'CONTORNO';

  @override
  String get pictureShape => 'FORMATO DA IMAGEM';

  @override
  String get surroundImage => 'Imagem de contorno';

  @override
  String get notAvailableOn => 'Não disponível neste dispositivo';

  @override
  String get offTurnsOff =>
      'Desligado desativa todos os efeitos CRT somente neste dispositivo. O formato da imagem, o contorno e os temas de sobreposição continuam como estão.';

  @override
  String get effectsOnThis => 'Efeitos neste dispositivo';

  @override
  String get retroLook2 => 'VISUAL RETRÔ';

  @override
  String get theseSettingsApply =>
      'Estas configurações valem nas telas com o app aberto. Não valem para a exportação de TV ao vivo.';

  @override
  String get sameAsThe => 'Igual ao perfil';

  @override
  String get streamsFromThis =>
      'As transmissões deste servidor ficam abaixo disso. O limite do próprio perfil (Reprodução) continua valendo: vale o menor.';

  @override
  String qualityLimit(Object name) {
    return 'Limite de qualidade · $name';
  }

  @override
  String mbps(Object toStringAsFixed) {
    return '$toStringAsFixed Mbps';
  }

  @override
  String get itsProgramsLeave =>
      'Os programas saem dos seus canais, que mantêm os números. Fontes e pastas de comerciais nele aparecem como não encontradas até você alterá-las.';

  @override
  String remove3(Object name) {
    return 'Remover $name?';
  }

  @override
  String get signingOutOf =>
      'Sair deste perfil muda o servidor principal dele.';

  @override
  String signedInAs(Object user) {
    return 'Conectado como $user';
  }

  @override
  String get mainServer => 'Servidor principal';

  @override
  String get qualityLimit2 => 'Limite de qualidade';

  @override
  String get moveDown => 'Mover para baixo';

  @override
  String get moveUp => 'Mover para cima';

  @override
  String get signInAgain => 'Entrar de novo';

  @override
  String get programsFromEvery =>
      'Os programas de todos os servidores entram em uma só grade. Um título em vários servidores é reproduzido do primeiro desta lista que responder (Reproduzir de); se ele parar de responder, o próximo assume.';

  @override
  String get sleepingPressAny =>
      'Dormindo · Aperte qualquer botão para assistir';

  @override
  String goingToSleep(Object seconds) {
    return 'Dormindo em $seconds';
  }

  @override
  String get goingToSleep2 => 'Indo dormir';

  @override
  String goingToSleepIn(Object hint) {
    return 'Dormindo em 1 minuto. $hint';
  }

  @override
  String get pressAnyButton =>
      'Aperte qualquer botão para continuar assistindo';

  @override
  String goingToSleepIn0(Object padLeft) {
    return 'Dormindo em 0:$padLeft';
  }

  @override
  String get keepWatching => 'Continuar assistindo';

  @override
  String get areYouStill => 'Você ainda está assistindo?';

  @override
  String sleepTimerMin(Object left) {
    return 'Timer de sono · faltam $left min';
  }

  @override
  String get whatsOnNow =>
      'O que está passando não tem horário fixo de término.';

  @override
  String endOfThis(Object programEnd) {
    return 'Fim deste programa · $programEnd';
  }

  @override
  String get endOfThisProgram => 'Fim deste programa';

  @override
  String get moveOkToggle => '▲▼◀▶ Mover    OK Alternar    ESC Cancelar';

  @override
  String get usedWhenNo =>
      'Usado quando nenhuma série é escolhida. Também restringe os filmes.';

  @override
  String get genres2 => 'GÊNEROS';

  @override
  String get includeMovies => 'Incluir filmes';

  @override
  String get add2 => 'Adicionar…';

  @override
  String get notFoundOn => 'Não encontrado no servidor';

  @override
  String get collectionsFolders => 'COLEÇÕES E PASTAS';

  @override
  String get playOrder => 'ORDEM DE REPRODUÇÃO';

  @override
  String get clear => 'Limpar';

  @override
  String get shows2 => 'SÉRIES';

  @override
  String get pickSomethingTo => 'Escolha algo para exibir.';

  @override
  String everyMovie(Object genreText) {
    return 'todo filme de $genreText';
  }

  @override
  String get everyMovie2 => 'todo filme';

  @override
  String everyShow(Object genreText) {
    return 'toda série de $genreText';
  }

  @override
  String or(Object genresCount, Object last) {
    return '$genresCount ou $last';
  }

  @override
  String get settingUpYour => 'Configurando seus canais';

  @override
  String get couldntLoadYour => 'Não foi possível carregar sua biblioteca';

  @override
  String upNext(Object title) {
    return 'A seguir: $title';
  }

  @override
  String backTo(Object title) {
    return 'De volta a $title';
  }

  @override
  String programmingResumesIn(Object left) {
    return 'A programação volta em $left';
  }

  @override
  String inLabel(Object commercialBreakLabel, Object left) {
    return '$commercialBreakLabel em $left';
  }

  @override
  String startingWith(Object title) {
    return 'Começando com $title';
  }

  @override
  String upNext2(Object start) {
    return 'A SEGUIR  ·  $start';
  }

  @override
  String next2(Object start, Object title) {
    return 'Próximo às $start: $title';
  }

  @override
  String backOn(Object backOnAir) {
    return 'Volta $backOnAir';
  }

  @override
  String get offTheAir2 => 'Fora do ar';

  @override
  String get commercialBreak => 'Intervalo comercial';

  @override
  String tryingAgainAt(Object end) {
    return 'Nova tentativa às $end';
  }

  @override
  String get exitFullScreen => 'Sair da tela cheia';

  @override
  String get guide2 => 'Guia';

  @override
  String thereIsNo(Object number) {
    return 'Não existe o canal $number';
  }

  @override
  String get liveChannelsCant => 'Canais ao vivo não podem ser pausados';

  @override
  String get curvatureAndGlow =>
      'Curvatura e brilho desligados: este dispositivo não dá conta';

  @override
  String get pressBackAgain => 'Pressione Voltar de novo para sair';

  @override
  String backAt(Object backAt) {
    return 'Volta às $backAt';
  }

  @override
  String get live => 'AO VIVO';

  @override
  String get newLabel => 'NOVO';

  @override
  String nowPlayingOn(Object name) {
    return 'TOCANDO EM $name';
  }

  @override
  String ch(Object padLeft) {
    return 'CANAL $padLeft';
  }

  @override
  String get paused => 'PAUSADO';

  @override
  String get seekBar => 'Barra de progresso';

  @override
  String get live2 => 'Ao vivo';

  @override
  String get forward30 => 'Avançar 30';

  @override
  String get pause => 'Pausar';

  @override
  String get play => 'Reproduzir';

  @override
  String get back10 => 'Voltar 10';

  @override
  String get restart => 'Reiniciar';

  @override
  String somethingWentWrong2(Object status) {
    return 'Algo deu errado ($status).';
  }

  @override
  String get thatIsTooBig => 'Isso é grande demais.';

  @override
  String get notFound => 'Não encontrado.';

  @override
  String get youCantDo => 'Você não pode fazer isso.';

  @override
  String get cantReachThe =>
      'Não foi possível acessar o servidor. Verifique se ele está em execução.';

  @override
  String signOut3(Object userName) {
    return 'Desconectar $userName';
  }

  @override
  String get changePassword => 'Alterar senha';

  @override
  String get users => 'Usuários';

  @override
  String get backups2 => 'Backups';

  @override
  String get serverAndSign => 'Servidor e acesso';

  @override
  String get channels5 => 'Canais';

  @override
  String get thatProfileIsntYours =>
      'Esse perfil não é seu ou não existe mais.';

  @override
  String get download => 'Baixar';

  @override
  String get itReplacesThe =>
      'Substitui os perfis, canais e configurações daqui.';

  @override
  String get restoreThisBackup => 'Restaurar este backup?';

  @override
  String get backupActions => 'Ações do backup';

  @override
  String channels6(Object profiles, Object channels, Object device) {
    return '$profiles · Canais: $channels · $device';
  }

  @override
  String get noneYetOne =>
      'Nenhum ainda. Um é salvo em cada dia em que a casa muda.';

  @override
  String get savedOnThe => 'Salvos no servidor';

  @override
  String get restoring => 'Restaurando…';

  @override
  String get restoreFromAFile => 'Restaurar de um arquivo…';

  @override
  String get downloadABackup => 'Baixar um backup agora';

  @override
  String get aBackupHoldsThe =>
      'Um backup guarda perfis, canais, blocos, logotipos, configurações de exportação e contas de usuário (nunca senhas ou tokens de acesso).';

  @override
  String get restoredTheBackup2 => 'Backup restaurado.';

  @override
  String fromItReplaces(Object whenValue, Object device, Object profiles) {
    return 'De $whenValue ($device): $profiles. Substitui os perfis, canais e configurações daqui.';
  }

  @override
  String nextAiring2(Object start, Object end) {
    return 'Próxima exibição: $start $end';
  }

  @override
  String programsInIts(Object total) {
    return 'Programas na playlist: $total';
  }

  @override
  String get workingOutWhat => 'Calculando o que exibe…';

  @override
  String get later => 'Depois';

  @override
  String get earlier => 'Antes';

  @override
  String get eachAiringPlays =>
      'Cada exibição passa em ordem os próximos episódios de cada posição e recomeça se sobrar tempo.';

  @override
  String get aLineupOf => 'Uma grade de séries';

  @override
  String get whatItPlays2 => 'O que exibe';

  @override
  String get onlyPartOf => 'Só parte do ano';

  @override
  String get runsPastMidnight => 'Passa da meia-noite para o dia seguinte.';

  @override
  String get whenLabel => 'Quando';

  @override
  String get aNewChannelFor => 'Um canal novo para este bloco';

  @override
  String get channel3 => 'Canal';

  @override
  String get blocks => 'Blocos';

  @override
  String get newBlock => 'Novo bloco';

  @override
  String get programmingBlock => 'Bloco de programação';

  @override
  String get aBlockTakes =>
      'Um bloco assume um canal em horários fixos: “Desenhos de sábado de manhã”, aos sábados das 7h ao meio-dia.';

  @override
  String get overlayTheme2 => 'Tema de sobreposição';

  @override
  String get crtEffect2 => 'Efeito CRT';

  @override
  String get chooseSurroundImage => 'Escolher imagem de contorno…';

  @override
  String get surround2 => 'Contorno';

  @override
  String get pictureShape2 => 'Formato da imagem';

  @override
  String get chooseOfflineImage => 'Escolher imagem fora do ar…';

  @override
  String get fillerPool2 => 'Grupo de preenchimento';

  @override
  String minutes(Object inMinutes) {
    return '$inMinutes minutos';
  }

  @override
  String get slotLength2 => 'Duração da faixa';

  @override
  String get everyProgramStarts =>
      'Todo programa começa na hora. O preenchimento completa o resto de cada faixa.';

  @override
  String get itLeavesThe => 'Ele sai da grade.';

  @override
  String get itsProgrammingBlocks =>
      'Os blocos de programação dele também são removidos.';

  @override
  String get removeThisChannel => 'Remover este canal';

  @override
  String get channelLogo2 => 'Logotipo do canal';

  @override
  String get editCustomBreaks => 'Editar intervalos personalizados…';

  @override
  String get musicChannelsOnlyShuffle =>
      'Canais de música só usam ordem aleatória, nunca o mesmo artista duas vezes seguidas.';

  @override
  String get playOrder2 => 'Ordem de reprodução';

  @override
  String get saveWhatIt => 'Salvar o que exibe';

  @override
  String get canBeA =>
      'Pode ser o canal principal de uma série para os episódios mais novos.';

  @override
  String get hiddenFromThe => 'Oculto no guia';

  @override
  String get chooseIcon => 'Escolher ícone…';

  @override
  String get icon => 'Ícone';

  @override
  String get saveNameAnd => 'Salvar nome e número';

  @override
  String get aChannelAlready =>
      'Um canal que já esteja nesse número troca de lugar com este.';

  @override
  String get number3 => 'Número';

  @override
  String get nameAndNumber => 'Nome e número';

  @override
  String get decadesNoneAny => 'Décadas (nenhuma: qualquer)';

  @override
  String get genresNoneAny => 'Gêneros (nenhum: qualquer)';

  @override
  String musicVideos(Object musicVideos) {
    return 'Videoclipes ($musicVideos)';
  }

  @override
  String songs(Object songs) {
    return 'Músicas ($songs)';
  }

  @override
  String get newMusicChannel => 'Novo canal de música';

  @override
  String get aNightlySlot =>
      'Uma faixa noturna para os episódios mais novos das séries, no canal principal de cada uma.';

  @override
  String get mainSettings => 'Configurações principais';

  @override
  String get glow2 => 'Brilho';

  @override
  String get curvature2 => 'Curvatura';

  @override
  String get vignette2 => 'Vinheta';

  @override
  String get mask2 => 'Máscara';

  @override
  String get lines2 => 'Linhas';

  @override
  String get scanlines2 => 'Linhas de varredura';

  @override
  String get customCrtStyle2 => 'Estilo CRT personalizado';

  @override
  String accent2(Object label) {
    return 'Destaque ($label)';
  }

  @override
  String get hidden => 'Oculto';

  @override
  String get blockChannel2 => 'Canal de blocos';

  @override
  String live3(Object source) {
    return 'Ao vivo · $source';
  }

  @override
  String ofChannels2(Object shownCount, Object channelsCount) {
    return 'Canais: $shownCount de $channelsCount';
  }

  @override
  String get searchChannels => 'Buscar canais';

  @override
  String get resetLineup => 'Redefinir grade';

  @override
  String get everyChannelEdit =>
      'Todas as edições de canais são descartadas e a grade padrão é recriada. Os canais que você adicionou são mantidos. Antes é salvo um backup.';

  @override
  String get musicChannel => 'Canal de música';

  @override
  String get newBlockChannel => 'Novo canal de blocos';

  @override
  String get channelsOwnPlans => 'Planos próprios dos canais';

  @override
  String get setTypeBumpers => 'Definir tipo: Vinhetas';

  @override
  String get setTypeCommercials => 'Definir tipo: Comerciais';

  @override
  String get chooseFolders2 => 'Escolher pastas…';

  @override
  String get plansThatDrew =>
      'Os planos que usavam este grupo passam a usar todos, e os vídeos voltam aos canais.';

  @override
  String get renamePool => 'Renomear grupo';

  @override
  String get poolActions => 'Ações do grupo';

  @override
  String get aPoolIs =>
      'Um grupo é um conjunto de pastas da biblioteca cujos vídeos preenchem intervalos em vez de irem ao ar. O tipo indica se os clipes passam como comerciais ou como vinhetas, que abrem e fecham intervalos.';

  @override
  String get pools2 => 'Grupos';

  @override
  String get breaks => 'Intervalos';

  @override
  String clipsInAll(Object clips) {
    return 'Clipes em todos os grupos de comerciais: $clips';
  }

  @override
  String get tunerAddress => 'Endereço do sintonizador';

  @override
  String get changePort => 'Alterar porta';

  @override
  String get exportThisProfile => 'Exportar este perfil';

  @override
  String get letsPlexAnd =>
      'Permite que o Plex e outros encontrem os sintonizadores na rede.';

  @override
  String get discovery2 => 'Descoberta';

  @override
  String get encoder2 => 'Codificador';

  @override
  String automaticOnThis(Object streamLimitInUse) {
    return 'Automático: $streamLimitInUse nesta máquina.';
  }

  @override
  String get streamsAtOnce2 => 'Transmissões simultâneas';

  @override
  String get quality2 => 'Qualidade';

  @override
  String get settings => 'Configurações';

  @override
  String get eachExportedProfile =>
      'Cada perfil exportado é um sintonizador para Plex, Jellyfin ou Emby. Adicione-o nas configurações de DVR deles pelo endereço.';

  @override
  String get channelsInThis => 'Canais neste grupo';

  @override
  String get chooseChannels3 => 'Escolher canais…';

  @override
  String channels7(Object channelIds) {
    return 'Canais: $channelIds';
  }

  @override
  String get itsChannelsStay => 'Os canais continuam na grade.';

  @override
  String get renameGroup => 'Renomear grupo';

  @override
  String get groupActions => 'Ações do grupo';

  @override
  String get yourGroup => 'Seu grupo';

  @override
  String get theOrderOf => 'A ordem das abas no guia e quais aparecem.';

  @override
  String get guideTabs => 'Abas do guia';

  @override
  String get make => 'Criar';

  @override
  String get breaksBetweenPrograms => 'Intervalos entre programas';

  @override
  String breaksInside2(int mids) {
    String _temp0 = intl.Intl.pluralLogic(
      mids,
      locale: localeName,
      other: '$mids intervalos dentro',
      one: '$mids intervalo dentro',
    );
    return '$_temp0';
  }

  @override
  String songs2(Object songs) {
    return 'Músicas: $songs';
  }

  @override
  String get newEpisode => 'Episódio novo';

  @override
  String get noChannelsYet2 => 'Ainda não há canais.';

  @override
  String get noGuide => 'Sem guia';

  @override
  String get noneShown => 'Nenhum visível';

  @override
  String get allShown => 'Todos visíveis';

  @override
  String channels8(Object name) {
    return '$name: canais';
  }

  @override
  String get orChooseA => 'Ou escolha um arquivo de guia…';

  @override
  String get emptyThePlaylists =>
      'Vazio: o guia da própria playlist, se ela indicar um.';

  @override
  String get guideAddressXmltv => 'Endereço do guia (XMLTV, opcional)';

  @override
  String get orChooseAPlaylist => 'Ou escolha um arquivo de playlist…';

  @override
  String get leaveEmptyToKeep =>
      'Deixe vazio para manter o arquivo da playlist.';

  @override
  String get httpPlaylistM3u => 'http://…/playlist.m3u';

  @override
  String get files => 'Arquivos';

  @override
  String get itsChannelsJoin =>
      'Os canais entram enquanto este perfil estiver conectado a esse servidor.';

  @override
  String guide3(Object guideFile) {
    return 'Guia: $guideFile';
  }

  @override
  String playlistFile2(Object playlistFile) {
    return 'Arquivo da playlist: $playlistFile';
  }

  @override
  String refreshed2(Object last, Object context) {
    return 'Atualizado $last $context';
  }

  @override
  String get itsChannelsLeaveThe =>
      'Os canais saem da grade, dos grupos e dos favoritos.';

  @override
  String read(Object fetched, Object context) {
    return 'Lido $fetched $context.';
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
    return 'Séries: $series · Episódios: $episodes · Filmes: $movies · Músicas: $songs · Videoclipes: $musicVideos · Vídeos de comerciais: $commercials';
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
  String get removeThePin => 'Remover o PIN';

  @override
  String get pinOptional => 'PIN (opcional)';

  @override
  String get newPinLeave => 'Novo PIN (deixe vazio para manter)';

  @override
  String colour(Object i) {
    return 'Cor $i';
  }

  @override
  String get colour2 => 'Cor';

  @override
  String get itsChannelsBlocks =>
      'Os canais, blocos e configurações são excluídos. Antes é salvo um backup.';

  @override
  String get exported => 'Exportado';

  @override
  String kid3(Object label) {
    return 'Criança · $label';
  }

  @override
  String get noProfilesAre =>
      'Ainda não há perfis atribuídos a você. Peça a um administrador.';

  @override
  String signIn2(Object name) {
    return 'Conectar $name';
  }

  @override
  String get theLibraryIs =>
      'A biblioteca está sendo lida de novo. Os programas do servidor entram nos canais quando terminar.';

  @override
  String get itsLibraryIs =>
      'A biblioteca está sendo lida e os canais criados. Isso leva um ou dois minutos.';

  @override
  String isSignedIn(Object name) {
    return '$name está conectado.';
  }

  @override
  String get couldntDoThat => 'Não foi possível fazer isso. Tente de novo.';

  @override
  String get itsChannelsStayIt =>
      'Os canais ficam. É preciso entrar para reproduzir.';

  @override
  String signOut4(Object name) {
    return 'Desconectar $name?';
  }

  @override
  String get signingIn => 'Entrando…';

  @override
  String wasSignedIn(Object server, Object user) {
    return 'Estava conectado a $server como $user. Entre de novo.';
  }

  @override
  String signedInTo(Object server, Object user) {
    return 'Conectado a $server como $user.';
  }

  @override
  String get profileName => 'Nome do perfil';

  @override
  String get nameAProfile =>
      'Dê um nome a um perfil, conecte-o ao seu servidor de mídia, e os canais são criados e exportados.';

  @override
  String get chooseABackup => 'Escolher um arquivo de backup…';

  @override
  String get moveAHousehold =>
      'Traga uma casa de uma TV ou outro servidor: perfis, canais, blocos, logotipos e configurações de exportação.';

  @override
  String get restoreABackup => 'Restaurar um backup';

  @override
  String get theServerIs => 'O servidor está iniciando…';

  @override
  String get itsProgramsLeaveThe =>
      'Os programas saem dos canais, que mantêm os números. Fontes e pastas de comerciais nele aparecem como não encontradas até você alterá-las.';

  @override
  String addAServerTo(Object name) {
    return 'Adicionar um servidor a $name';
  }

  @override
  String servers2(Object name) {
    return '$name: servidores';
  }

  @override
  String get makeAccountAnd => 'Criar conta e entrar';

  @override
  String get setPasswordAnd => 'Definir senha e entrar';

  @override
  String get passwordAgain => 'Repetir senha';

  @override
  String get atLeast8 => 'Pelo menos 8 caracteres.';

  @override
  String get userName => 'Nome de usuário';

  @override
  String get adminAccount => 'Conta de administrador';

  @override
  String get makeTheFirst => 'Crie a primeira conta de administrador.';

  @override
  String get setANew =>
      'Defina uma nova senha para uma conta de administrador.';

  @override
  String get thisSetupLink =>
      'Este link de configuração já foi usado ou é de uma inicialização anterior. Abra o mais recente no log do servidor ou entre.';

  @override
  String get thePasswordsDont => 'As senhas não conferem.';

  @override
  String get newPasswordAgain => 'Repetir nova senha';

  @override
  String get newPassword => 'Nova senha';

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get passwordChangedYour =>
      'Senha alterada. Seus outros navegadores foram desconectados.';

  @override
  String get theNewPasswords => 'As novas senhas não conferem.';

  @override
  String get theyAreSigned =>
      'A pessoa é desconectada e não pode entrar de novo.';

  @override
  String get cantSignIn => 'Não pode entrar; desconectado de todos os lugares.';

  @override
  String get usersReachOnly => 'Os usuários acessam só os perfis abaixo.';

  @override
  String get adminsCanDo =>
      'Administradores podem fazer tudo, em todos os perfis.';

  @override
  String get admin => 'Administrador';

  @override
  String get user => 'Usuário';

  @override
  String get leaveEmptyToKeepIt =>
      'Deixe vazio para manter. Definir uma desconecta a pessoa de outros lugares.';

  @override
  String get needsAPassword => 'Precisa de senha antes de poder entrar.';

  @override
  String get addUser => 'Adicionar usuário';

  @override
  String get needsAPassword2 => 'Precisa de senha';

  @override
  String get noProfiles => 'Sem perfis';

  @override
  String get pad => 'Completar';

  @override
  String clips4(Object name, Object clips) {
    return '$name  ·  Clipes: $clips';
  }

  @override
  String get clipsFrom2 => 'Clipes de';

  @override
  String get channelsUsingItGo =>
      'Os canais que o usam voltam a um ícone incluído.';

  @override
  String get uploading => 'Enviando…';

  @override
  String get noneOfYourShows =>
      'Nenhuma das suas séries tem imagem de logotipo no seu servidor.';

  @override
  String get chooseAnIcon => 'Escolher um ícone';

  @override
  String get couldntCopySelect =>
      'Não foi possível copiar. Selecione o texto e copie.';

  @override
  String copy(Object label) {
    return 'Copiar $label';
  }

  @override
  String get home => 'Início';

  @override
  String get thereIsNoPage => 'Não há nenhuma página aqui.';

  @override
  String get enterPin => 'Digitar PIN';

  @override
  String get thisIsA =>
      'Este é um perfil infantil. Alterar as configurações dele exige o PIN de um adulto.';

  @override
  String hasAPin(Object name) {
    return '$name tem um PIN.';
  }

  @override
  String get profile => 'Perfil';

  @override
  String get changingAKid =>
      'Alterar as configurações de um perfil infantil exige o PIN de um perfil de adulto.';

  @override
  String get aGrownUps => 'PIN de um adulto';

  @override
  String get thisProfile => 'este perfil';

  @override
  String movies3(Object movies) {
    return 'Filmes ($movies)';
  }

  @override
  String get shows3 => 'Séries';

  @override
  String remove4(Object label) {
    return 'Remover $label';
  }

  @override
  String notFoundOnThe(Object label) {
    return '$label · Não encontrado no servidor';
  }

  @override
  String get dragACollection =>
      'Arraste uma coleção, pasta ou filme para cá, ou use o botão Adicionar dele.';

  @override
  String get collectionsAndFolders => 'Coleções e pastas';

  @override
  String add3(Object name) {
    return 'Adicionar $name';
  }

  @override
  String added2(Object name) {
    return '$name adicionado';
  }

  @override
  String get dragToAdd => 'Arraste para adicionar';

  @override
  String get languageAutomatic => 'Automático';

  @override
  String dateAtTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String connectingTo(Object server) {
    return 'Conectando a $server…';
  }

  @override
  String get yourServerLower => 'seu servidor';

  @override
  String noServerFoundAt(Object address) {
    return 'Nenhum servidor Jellyfin, Emby ou Plex encontrado em $address.';
  }

  @override
  String captionsValue(Object name) {
    return 'Legendas: $name';
  }

  @override
  String channelOverrides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canais têm configuração própria (Canais e ícones).',
      one: '$count canal tem configuração própria (Canais e ícones).',
    );
    return '$_temp0';
  }

  @override
  String noShowLogosOn(Object kind) {
    return 'Nenhuma das suas séries tem imagem de logotipo no seu servidor $kind.';
  }

  @override
  String fileChosen(Object name) {
    return 'Arquivo: $name';
  }

  @override
  String get theOneChosenBefore => 'o escolhido antes';

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
          'Transmitindo os canais $channels para $viewers espectador(es). $running de $limit transmissões em uso.',
      one:
          'Transmitindo o canal $channels para $viewers espectador(es). $running de $limit transmissões em uso.',
    );
    return '$_temp0';
  }

  @override
  String exportThisLineup(Object name) {
    return '$name: exportar esta grade';
  }

  @override
  String exportThisLineupKid(Object name) {
    return '$name (criança): exportar esta grade';
  }

  @override
  String encoderInUse(Object encoder) {
    return 'Codificador em uso: $encoder';
  }

  @override
  String get checking => 'verificando…';

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
      other: '$count episódios',
      one: '$count episódio',
    );
    return '$_temp0';
  }

  @override
  String countMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmes',
      one: '$count filme',
    );
    return '$_temp0';
  }

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '$count música',
    );
    return '$_temp0';
  }

  @override
  String countMusicVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videoclipes',
      one: '$count videoclipe',
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
    return '$count no ar';
  }

  @override
  String countProgrammingBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocos de programação',
      one: '$count bloco de programação',
    );
    return '$_temp0';
  }

  @override
  String perServerStats(Object name, Object stats) {
    return '$name: $stats';
  }

  @override
  String get yourServerHasNothingNew =>
      'Seu servidor não tem nada novo desde a última atualização. Novos arquivos aparecem aqui depois que o servidor os analisa: se você acabou de adicionar alguns, analise a biblioteca no servidor primeiro e atualize de novo.';

  @override
  String serverHasNothingNew(Object server) {
    return '$server não tem nada novo desde a última atualização. Novos arquivos aparecem aqui depois que o servidor os analisa: se você acabou de adicionar alguns, analise a biblioteca no servidor primeiro e atualize de novo.';
  }

  @override
  String get updateWatchStatusOnYourServer =>
      'Atualizar status de assistido no seu servidor';

  @override
  String get updateWatchStatusOnYourServers =>
      'Atualizar status de assistido nos seus servidores';

  @override
  String updateWatchStatusOn(Object name) {
    return 'Atualizar status de assistido em $name';
  }

  @override
  String get poolFoldersBumpers =>
      'Todo vídeo nestas pastas (e nas subpastas) abre e fecha intervalos, e nunca vai ao ar como programa.';

  @override
  String get poolFoldersCommercials =>
      'Todo vídeo nestas pastas (e nas subpastas) preenche intervalos, e nunca vai ao ar como programa.';

  @override
  String get newPin => 'Novo PIN';

  @override
  String namedPin(Object name) {
    return 'PIN de $name';
  }

  @override
  String get qualitySameAsProfile => 'Qualidade: igual ao perfil';

  @override
  String qualityValue(Object limit) {
    return 'Qualidade: $limit';
  }

  @override
  String onChannel(Object channel) {
    return 'em $channel';
  }

  @override
  String get aChannelThatIsGone => 'um canal que não existe mais';

  @override
  String liveFrom(Object source) {
    return 'Ao vivo de $source';
  }

  @override
  String logoAndPremieres(Object mode, Object premieres) {
    return 'Logotipo $mode · Estreias $premieres';
  }

  @override
  String get offLower => 'desligado';

  @override
  String streamingNow(Object count) {
    return 'Transmissões agora: $count.';
  }

  @override
  String streamingNowEncoding(Object count, Object encoder) {
    return 'Transmissões agora: $count · codificando com $encoder.';
  }

  @override
  String kindChosenChannels(Object kind, Object chosen, Object channels) {
    return '$kind · Canais: $chosen de $channels';
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
    return 'De $when ($device): $profiles. Canais: $channels, blocos de programação: $blocks, logotipos: $logos.';
  }

  @override
  String get backupSavedFirst =>
      'Antes é salvo um backup do que está aqui agora.';

  @override
  String newShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries novas',
      one: '$count série nova',
    );
    return '$_temp0';
  }

  @override
  String newEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episódios novos',
      one: '$count episódio novo',
    );
    return '$_temp0';
  }

  @override
  String newMovies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmes novos',
      one: '$count filme novo',
    );
    return '$_temp0';
  }

  @override
  String newSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas novas',
      one: '$count música nova',
    );
    return '$_temp0';
  }

  @override
  String playsList(Object list) {
    return 'Exibe $list.';
  }

  @override
  String newChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canais novos',
      one: '$count canal novo',
    );
    return '$_temp0';
  }

  @override
  String get kidRatingYoung => 'Crianças pequenas';

  @override
  String get kidRatingYoungDescription => 'TV-Y e TV-Y7';

  @override
  String get kidRatingKids => 'Crianças';

  @override
  String get kidRatingKidsDescription => 'Até TV-G e G';

  @override
  String get kidRatingOlder => 'Crianças maiores';

  @override
  String get kidRatingOlderDescription => 'Até TV-PG e PG';

  @override
  String countProfilesWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfis',
      one: '$count perfil',
    );
    return '$_temp0';
  }

  @override
  String countChannelsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canais',
      one: '$count canal',
    );
    return '$_temp0';
  }

  @override
  String countBlocksWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocos',
      one: '$count bloco',
    );
    return '$_temp0';
  }

  @override
  String countSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '$count faixa',
    );
    return '$_temp0';
  }

  @override
  String videosInFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos nas pastas',
      one: '$count vídeo nas pastas',
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
  String get liveLabel => 'Ao vivo';

  @override
  String get aMidRollOpens =>
      'Um mid-roll abre e fecha com uma vinheta, um post-roll abre com uma e um pre-roll fecha com uma. Comerciais preenchem o resto.';

  @override
  String get programsPlayBack =>
      'Os programas passam um atrás do outro, sem intervalos.';

  @override
  String get everyShowFills =>
      'Cada série preenche uma faixa de meia hora (uma hora ou mais para as longas), para o guia seguir o relógio.';

  @override
  String get chooseHowLong =>
      'Escolha quanto dura cada intervalo, com que frequência as séries param e de qual grupo vem cada intervalo.';

  @override
  String get kindSentenceAutomatic => 'automático';

  @override
  String get kindSentenceBeforeRestore => 'antes de restaurar';

  @override
  String get kindSentenceBeforeReset => 'antes de redefinir';

  @override
  String get kindSentenceBeforeDeletingAProfile => 'antes de excluir um perfil';

  @override
  String kindSentenceBeforeDeleting(Object subject) {
    return 'antes de excluir $subject';
  }

  @override
  String get kindSentenceBeforeUpdate => 'antes da atualização';

  @override
  String get kindSentenceBeforeLineupCleanup => 'antes da limpeza da grade';

  @override
  String get kindSentenceFromAFile => 'de um arquivo';

  @override
  String get kindSentenceMovingToOfficial => 'mudança para o Nightingale TV';

  @override
  String get kindSentenceMovingToOwnBuild =>
      'mudança para o Nightingale TV (versão própria)';

  @override
  String get kindSentenceFromOfficial => 'do Nightingale TV';

  @override
  String get kindSentenceFromOwnBuild => 'do Nightingale TV (versão própria)';

  @override
  String get kindSentenceMadeByYou => 'feito por você';

  @override
  String get copyAction => 'Copiar';

  @override
  String get channelKidsZone => 'Zona Kids';

  @override
  String get channelToonTv => 'Toon TV';

  @override
  String get channelLaughTrack => 'Risadas Garantidas';

  @override
  String get channelFamilyRoom => 'Sala da Família';

  @override
  String get channelAdventureTv => 'Aventura TV';

  @override
  String get channelSciFiFantasy => 'Ficção e Fantasia';

  @override
  String get channelMysteryTv => 'Mistério TV';

  @override
  String get channelDramaCentral => 'Central do Drama';

  @override
  String get channelCrimeJustice => 'Crime e Justiça';

  @override
  String get channelThrillTv => 'Suspense TV';

  @override
  String get channelFrightNight => 'Noite do Terror';

  @override
  String get channelRomanceTv => 'Romance TV';

  @override
  String get channelDiscoveryZone => 'Zona Descoberta';

  @override
  String get channelMusicTv => 'Música TV';

  @override
  String get channelRealityTv => 'Reality TV';

  @override
  String get channelGameShowTv => 'Game Show TV';

  @override
  String get channelFrontierTv => 'Faroeste TV';

  @override
  String get channelHistoryTv => 'História TV';

  @override
  String get channelSportsTv => 'Esportes TV';

  @override
  String get channelNewsTv => 'Notícias TV';

  @override
  String get channelAllShows => 'Todas as séries';

  @override
  String get channelMovieChannel => 'Canal de Filmes';

  @override
  String get channelMusicVideos => 'Videoclipes';

  @override
  String get channelMusicRadio => 'Rádio Musical';

  @override
  String get genreActionAdventure => 'Ação e aventura';

  @override
  String get genreSciFiFantasy => 'Ficção científica e fantasia';

  @override
  String get genreKids => 'Crianças';

  @override
  String get genreAnimation => 'Animação';

  @override
  String get genreComedy => 'Comédia';

  @override
  String get genreFamily => 'Família';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreCrime => 'Crime';

  @override
  String get genreMystery => 'Mistério';

  @override
  String get genreThriller => 'Suspense';

  @override
  String get genreHorror => 'Terror';

  @override
  String get genreRomance => 'Romance';

  @override
  String get genreDocumentary => 'Documentário';

  @override
  String get genreMusic => 'Música';

  @override
  String get genreReality => 'Reality show';

  @override
  String get genreGameShows => 'Game shows';

  @override
  String get genreWestern => 'Faroeste';

  @override
  String get genreWar => 'Guerra';

  @override
  String get genreHistory => 'História';

  @override
  String get genreNews => 'Notícias';

  @override
  String get genreTalk => 'Entrevistas';

  @override
  String get genreSoap => 'Novela';

  @override
  String get genreSports => 'Esportes';

  @override
  String get genreClassical => 'Clássica';

  @override
  String get genreElectronic => 'Eletrônica';

  @override
  String get genreCountry => 'Sertanejo e country';

  @override
  String get genreLatin => 'Latina';

  @override
  String get genreSoundtrack => 'Trilha sonora';

  @override
  String get genreOldies => 'Antigas';

  @override
  String get genreDance => 'Dance';

  @override
  String get genreFolk => 'Folk';

  @override
  String get genreAlternative => 'Alternativa';

  @override
  String get blockDaytime => 'Durante o dia';

  @override
  String get blockMovieNight => 'Noite de Cinema';

  @override
  String get blockNewEpisodes => 'Episódios novos';

  @override
  String get kindShow => 'Série';

  @override
  String get kindShows => 'Séries';

  @override
  String get kindMovies => 'Filmes';

  @override
  String get kindMusicVideos => 'Videoclipes';

  @override
  String get kindRadio => 'Rádio';

  @override
  String genreMovies(Object genre) {
    return 'Filmes de $genre';
  }

  @override
  String genreMusicVideos(Object genre) {
    return 'Videoclipes de $genre';
  }

  @override
  String genreRadio(Object genre) {
    return 'Rádio $genre';
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
  String get stillWatchingOff => 'Desligado';

  @override
  String afterHours(int hours) {
    return 'Depois de $hours horas';
  }

  @override
  String get bitrateOriginal => 'Original (sem limite)';

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
  String get noSuchLanguage => 'Idioma inexistente.';

  @override
  String get languageField => 'Idioma';

  @override
  String get remotePageTitle => 'Controle Nightingale TV';

  @override
  String get remotePairTitle => 'Parear com a TV';

  @override
  String get remotePairHelp =>
      'Escaneie o código na TV (Menu → Controle pelo celular) ou digite o código de 6 dígitos mostrado lá.';

  @override
  String get remotePairingCode => 'Código de pareamento';

  @override
  String get remotePair => 'Parear';

  @override
  String get remoteConnecting => 'Conectando…';

  @override
  String get remoteTabRemote => 'Controle';

  @override
  String get remoteUp => 'Cima';

  @override
  String get remoteLeft => 'Esquerda';

  @override
  String get remoteRight => 'Direita';

  @override
  String get remoteDown => 'Baixo';

  @override
  String get remoteInfo => 'Info';

  @override
  String get remoteLastCh => 'Último';

  @override
  String get remoteCc => 'LEG';

  @override
  String get remoteChUp => 'CH +';

  @override
  String get remoteChDown => 'CH −';

  @override
  String get remoteEnter => 'Confirmar';

  @override
  String get remoteRemovedFromTv =>
      'Este celular foi removido da TV. Escaneie o código para parear de novo.';

  @override
  String get remoteCouldntPair => 'Não foi possível parear. Tente de novo.';

  @override
  String get remoteCantReachWifi =>
      'Não foi possível acessar a TV. Este celular está no mesmo Wi-Fi?';

  @override
  String get remoteEnterDigits => 'Digite os 6 dígitos mostrados na TV.';

  @override
  String get remoteCantReachTv => 'Não foi possível acessar a TV';

  @override
  String get remotePickProfile => 'Escolha um perfil com as setas e OK.';

  @override
  String remoteWatching(Object name) {
    return 'Assistindo: $name';
  }

  @override
  String remoteKidName(Object name) {
    return '$name (criança)';
  }

  @override
  String get transferPageTitle => 'Backup do Nightingale TV';

  @override
  String get transferIntro =>
      'Mova um backup entre esta TV e este dispositivo. Mantenha a janela da TV aberta enquanto isso.';

  @override
  String get transferDownload => 'Baixar backup';

  @override
  String get transferDownloadHelp =>
      'Um backup da configuração atual da TV: perfis, canais, blocos e configurações.';

  @override
  String get transferRestoreTitle => 'Restaurar de um arquivo';

  @override
  String transferRestoreHelp(Object file) {
    return 'Envie um arquivo $file para a TV. Nada muda até você confirmar na TV.';
  }

  @override
  String get transferChoose => 'Escolher um arquivo de backup…';

  @override
  String get transferFoot =>
      'Só dispositivos na sua rede doméstica podem abrir esta página.';

  @override
  String transferSending(Object name) {
    return 'Enviando $name…';
  }

  @override
  String get transferCheckTv => 'Veja sua TV para concluir.';

  @override
  String get transferClosed =>
      'A TV fechou esta página. Abra de novo em Backup e restauração.';

  @override
  String get transferCouldntTake => 'A TV não conseguiu aceitar esse arquivo.';

  @override
  String get transferCouldntReach =>
      'Não foi possível acessar a TV. Ela ainda está mostrando o código?';

  @override
  String get includeShows => 'Incluir séries';

  @override
  String get everyShow2 => 'toda série';

  @override
  String get decades => 'Décadas';

  @override
  String get decadesHeading => 'DÉCADAS';

  @override
  String get channelActionTv => 'Ação TV';

  @override
  String get channelSciFiTv => 'Ficção TV';

  @override
  String get channelFantasyTv => 'Fantasia TV';

  @override
  String get channelMysteryThrills => 'Mistério e Suspense';

  @override
  String get genreAction => 'Ação';

  @override
  String get genreAdventure => 'Aventura';

  @override
  String get genreSciFi => 'Ficção científica';

  @override
  String get genreFantasy => 'Fantasia';

  @override
  String get genreThrillerMystery => 'Suspense e mistério';

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
    return 'Filmes de $genre $decade';
  }

  @override
  String get errorReports => 'Relatórios de erros';

  @override
  String get sendErrorReportsFrom =>
      'Enviar relatórios de erros deste dispositivo';

  @override
  String get errorReportsExplain =>
      'Quando algo dá errado, o Nightingale TV envia ao desenvolvedor um relatório curto: o erro, a versão do app, o tipo de dispositivo e as últimas telas e números de canal. Endereços de servidor, senhas e chaves, nomes e caminhos de arquivo são removidos antes do envio. Títulos e o que você assiste nunca são enviados.';

  @override
  String get errorReportsOff =>
      'Desative isto e nada é enviado deste dispositivo; relatórios aguardando envio são apagados.';

  @override
  String get sendATestReport => 'Enviar um relatório de teste';

  @override
  String lastReportId(String id) {
    return 'ID do último relatório: $id';
  }

  @override
  String get noReportSentYet =>
      'Nenhum relatório enviado deste dispositivo ainda.';

  @override
  String get quoteReportId =>
      'Informe este ID quando contar um problema ao desenvolvedor.';

  @override
  String testReportSent(String id) {
    return 'Relatório de teste enviado: $id';
  }

  @override
  String get testReportNotSent =>
      'Não foi possível enviar o relatório de teste. Tente de novo daqui a pouco.';

  @override
  String get reportsNotInBuild =>
      'Relatórios de erros não fazem parte desta versão do Nightingale TV, então nada é enviado.';

  @override
  String get sendAVideoReport => 'Enviar um relatório de vídeo';

  @override
  String get videoReportHelp =>
      'Se a imagem parecer errada, pressione aqui e volte a um canal. Após 10 segundos de imagem, o relatório é enviado e o ID dele aparece na tela da TV.';

  @override
  String get videoReportArmed =>
      'Volte agora a um canal. O relatório de vídeo é enviado após 10 segundos de imagem.';

  @override
  String get videoReportTooSoon =>
      'Um relatório de vídeo foi enviado há menos de um minuto. Tente de novo em instantes.';

  @override
  String videoReportSent(String id) {
    return 'Relatório de vídeo enviado: $id';
  }

  @override
  String get videoReportsExplain =>
      'Um relatório de vídeo envia dados do dispositivo, do vídeo e do decodificador, grades de cores aproximadas da imagem e as últimas linhas de registro do app; nunca uma imagem do que você assiste. Um é enviado após cada atualização do app, quando um canal toca por 10 segundos.';
}
