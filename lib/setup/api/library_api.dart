part of '../setup_server.dart';

/// A profile's library (admin-api): its summary, a refresh in the
/// background, folder browsing like the TV's folder picker, and server
/// pictures fetched with the profile's sign-in, so the media server's
/// token never reaches the browser.
extension _LibraryApi on SetupServer {
  List<ApiRoute> get _libraryRoutes => [
        ApiRoute('GET', 'profiles/{id}/library', Access.profile, (r) async => _librarySummary(await _app(r['id']))),
        ApiRoute('POST', 'profiles/{id}/library/refresh', Access.profileSettings, _refreshLibrary,
            revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/library/browse', Access.profile, _browse, revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/library/catalog', Access.profile, (r) async => _catalog(await _app(r['id'])),
            revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/art/{itemId}', Access.profile, _art, revision: Revision.none),
      ];

  /// The most a server picture may be.
  static const maxPicture = 10 << 20;

  Map<String, Object?> _librarySummary(AppState app) {
    final library = app.library;
    final s = app.session;
    return {
      'signedIn': app.phase != AppPhase.signedOut && s != null,
      'server': s?.serverName ?? s?.serverUrl,
      'user': s?.userName,
      'syncing': app.phase == AppPhase.syncing || app.phase == AppPhase.starting || app.isRefreshingLibrary,
      'status': app.syncStatus,
      'error': app.syncError,
      'fetchedAt': library.fetchedAt.year < 2000 ? null : library.fetchedAt.toUtc().toIso8601String(),
      'series': library.series.length,
      'episodes': library.episodes.length,
      'movies': library.movies.length,
      'songs': library.songs.length,
      'musicVideos': library.musicVideos.length,
      'commercials': library.commercials.length,
      // A line per server (multi-server).
      if (app.servers.multiple) 'servers': _serversJson(app)['servers'],
    };
  }

  /// What the block and music channel editors pick from, as the TV's
  /// content pickers list it: shows, genres, and music genres and decades.
  Map<String, Object?> _catalog(AppState app) {
    final library = app.library;
    final series = [...library.series]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final music = [...library.songs, ...library.musicVideos];
    return {
      'shows': [
        for (final s in series)
          {
            'key': s.key,
            'id': s.id,
            'name': s.name,
            'episodes': library.episodesBySeries[s.key]?.length ?? 0,
            if (s.hasLogo) 'hasLogo': true,
          },
      ],
      'genres': ({
        for (final s in library.series) ...titleGenres(s.genres),
        for (final m in library.movies) ...titleGenres(m.genres),
      }.toList()
        ..sort()),
      // The decades of every movie and episode (an episode without a year
      // goes by its show's), for the shows-and-movies Decades chips.
      'videoDecades': ({
        for (final m in library.movies) ?decadeOf(m.year),
        for (final e in library.episodes) ?itemDecade(library, e),
      }.toList()
        ..sort()),
      'movies': library.movies.length,
      'songs': library.songs.length,
      'musicVideos': library.musicVideos.length,
      'musicGenres': ({for (final m in music) ...m.genres.map(normalizeMusicGenre)}.toList()..sort()),
      'decades': ({for (final m in music) ?decadeOf(m.year)}.toList()..sort()),
    };
  }

  /// Starts a refresh and answers at once; the summary shows its progress.
  Future<Object?> _refreshLibrary(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    unawaited(app.refreshLibrary(background: true));
    // Let it set its first status.
    await Future<void>.delayed(Duration.zero);
    return _librarySummary(app);
  }

  /// Without `library`: the video libraries. With it: that library's
  /// folders as a tree (folders, shows, seasons and collections).
  Future<Object?> _browse(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    if (app.client == null) throw ApiError(HttpStatus.serviceUnavailable, SetupServer.signedOutText);
    try {
      final library = r.query['library'];
      if (library == null || library.isEmpty) {
        // Every server's (multi-server), named after their server when
        // there are several.
        return [
          for (final l in await app.allLibraries())
            if (l.isVideo || l.isCollections) {'id': l.id, 'name': l.name, 'type': l.collectionType},
        ];
      }
      final client = app.clientOf(library) ?? (throw ApiError(HttpStatus.serviceUnavailable, SetupServer.signedOutText));
      Map<String, Object?> node(FolderNode n) =>
          {'id': n.id, 'name': n.name, 'type': n.type, 'children': [for (final c in n.children) node(c)]};
      return [for (final n in await client.folderTree(library)) node(n)];
    } on ServerException catch (e) {
      throw ApiError(HttpStatus.badGateway, e.message);
    }
  }

  /// A server picture of item `{itemId}` (`?kind=logo|primary`, `&h=`),
  /// fetched with the profile's sign-in.
  Future<Object?> _art(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    // From the server the item is on (multi-server).
    final client =
        app.clientOf(r['itemId']) ?? (throw ApiError(HttpStatus.serviceUnavailable, SetupServer.signedOutText));
    final kind = r.query['kind'] == 'primary' ? ImageKind.primary : ImageKind.logo;
    final height = (int.tryParse(r.query['h'] ?? '') ?? 160).clamp(16, 1080);
    await _sendPicture(r, client.imageUri(r['itemId'], kind, maxHeight: height), client.authHeaders);
    return ApiRequest.handled;
  }

  /// Fetches the picture at [uri] (with [headers]) and sends it on; 404
  /// when the server has none.
  Future<void> _sendPicture(ApiRequest r, Uri uri, Map<String, String>? headers) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await http.getUrl(uri).timeout(const Duration(seconds: 15));
      headers?.forEach(request.headers.set);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final type = response.headers.contentType;
      if (response.statusCode != HttpStatus.ok || type == null || type.primaryType != 'image') {
        await response.drain<void>();
        throw ApiError(HttpStatus.notFound);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        if (bytes.length > maxPicture) throw ApiError(HttpStatus.notFound);
      }
      r.response.headers
        ..contentType = type
        ..set('Cache-Control', 'private, max-age=3600')
        ..set('X-Content-Type-Options', 'nosniff');
      r.response.add(bytes.takeBytes());
    } on ApiError {
      rethrow;
    } on Object {
      throw ApiError(HttpStatus.notFound);
    } finally {
      http.close(force: true);
    }
  }
}
