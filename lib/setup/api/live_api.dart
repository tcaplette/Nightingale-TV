part of '../setup_server.dart';

/// Live TV sources (admin-api): the server's Live TV, M3U playlists and
/// XMLTV guides by URL or uploaded file, channel choice, refresh and
/// removal, over the AppState methods the TV's screens call. Playlist URLs
/// are shown masked, and stream URLs never leave the server.
extension _LiveApi on SetupServer {
  List<ApiRoute> get _liveRoutes => [
        ApiRoute('GET', 'profiles/{id}/live-sources', Access.profile, _liveSources),
        ApiRoute('POST', 'profiles/{id}/live-sources', Access.profileSettings, _addM3u),
        ApiRoute('POST', 'profiles/{id}/live-sources/server', Access.profileSettings, _addServerSource),
        ApiRoute('POST', 'profiles/{id}/live-sources/files', Access.profileSettings, _uploadLiveFile,
            revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/live-sources/{sid}', Access.profile, _liveSource),
        ApiRoute('PUT', 'profiles/{id}/live-sources/{sid}', Access.profileSettings, _editM3u),
        ApiRoute('DELETE', 'profiles/{id}/live-sources/{sid}', Access.profileSettings, _removeSource),
        ApiRoute('GET', 'profiles/{id}/live-sources/{sid}/channels', Access.profile, _sourceChannels),
        ApiRoute('PUT', 'profiles/{id}/live-sources/{sid}/channels', Access.profileSettings, _chooseChannels),
        ApiRoute('POST', 'profiles/{id}/live-sources/{sid}/refresh', Access.profileSettings, _refreshSource),
      ];

  /// The most an uploaded playlist or guide may be.
  static const maxLiveFile = 32 << 20;
  static const liveFileTooBig = 'That file is too big (32 MB at most).';

  LiveSource _sourceOf(AppState app, String id) =>
      app.live.sourceById(id) ?? (throw ApiError(HttpStatus.notFound, 'No such source.'));

  Map<String, Object?> _sourceJson(AppState app, LiveSource s) {
    final entry = app.live.entryFor(s);
    final state = entry.state;
    String iso(DateTime? t) => t == null ? '' : t.toUtc().toIso8601String();
    return {
      'id': s.id,
      'kind': s.kind.name,
      'name': s.name,
      'playlistUrl': s.playlistUrl == null ? null : maskUrl(s.playlistUrl!),
      'playlistFile': s.playlistFile,
      'guideUrl': s.guideUrl == null ? null : maskUrl(s.guideUrl!),
      'guideFile': s.guideFile,
      'guideFromPlaylist': s.guideFromPlaylist,
      'view': {
        'channels': entry.channels.length,
        'chosen': entry.channels.where((c) => s.chosen.containsKey(c.key)).length,
        'active': app.live.isActive(s),
        'refreshing': app.live.isRefreshing(s),
        'lastError': state.lastError,
        if (state.lastRefresh != null) 'lastRefresh': iso(state.lastRefresh),
      },
    };
  }

  Future<Object?> _liveSources(ApiRequest r) async {
    final app = await _app(r['id']);
    final availability = app.live.serverSource == null ? await app.liveTvAvailability() : null;
    final server = app.session?.serverName ?? 'Your server';
    return {
      'enabled': app.liveEnabled,
      if (!app.liveEnabled) 'message': 'Kid profiles get no live channels.',
      'sources': [for (final s in app.live.sources) _sourceJson(app, s)],
      'server': {
        'canAdd': availability == LiveTvAvailability.available,
        'reason': availability?.reason(server),
      },
    };
  }

  Future<Object?> _liveSource(ApiRequest r) async {
    final app = await _app(r['id']);
    return _sourceJson(app, _sourceOf(app, r['sid']));
  }

  Future<Object?> _addServerSource(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    try {
      return _sourceJson(app, await app.addServerLiveSource());
    } on LiveSourceException catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
  }

  // ---- Uploaded playlists and guides ---------------------------------------------

  /// Uploaded files waiting for the source they're for, by id. At most a
  /// few are kept.
  static final _liveUploads = <String, ({String profile, String name, Uint8List bytes})>{};

  /// A playlist or guide file (`?name=` its file name); answers its upload
  /// id for `playlistUpload` / `guideUpload`.
  Future<Object?> _uploadLiveFile(ApiRequest r) async {
    final bytes = await r.bytes(maxLiveFile, liveFileTooBig);
    final name = r.query['name'] ?? 'playlist.m3u';
    while (_liveUploads.length >= 4) {
      _liveUploads.remove(_liveUploads.keys.first);
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _liveUploads[id] = (profile: r['id'], name: name, bytes: bytes);
    return {'upload': id, 'name': name, 'size': bytes.length};
  }

  PickedLiveFile? _picked(ApiRequest r, String? uploadId) {
    if (uploadId == null) return null;
    final upload = _liveUploads.remove(uploadId);
    if (upload == null || upload.profile != r['id']) throw ApiError(HttpStatus.badRequest, 'Upload the file again.');
    return (name: upload.name, path: null, bytes: upload.bytes);
  }

  // ---- M3U sources ------------------------------------------------------------------

  /// An M3U source: `playlistUrl` or `playlistUpload`, and optionally
  /// `guideUrl` or `guideUpload`. It's added once the playlist reads.
  Future<Object?> _addM3u(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    final playlist = _picked(r, body.string('playlistUpload'));
    final url = body.string('playlistUrl')?.trim() ?? '';
    if (playlist == null && url.isEmpty) {
      throw ApiError(HttpStatus.badRequest, "Enter the playlist's address, or choose a playlist file");
    }
    try {
      final source = await app.addM3uSource(
        name: body.string('name') ?? _nameFor(url, playlist),
        playlistUrl: url,
        playlist: playlist,
        guideUrl: body.string('guideUrl'),
        guide: _picked(r, body.string('guideUpload')),
      );
      return _sourceJson(app, source);
    } on LiveSourceException catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
  }

  /// The TV's default name: the playlist's host, or its file name.
  static String _nameFor(String url, PickedLiveFile? file) {
    if (file != null) return file.name.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? 'M3U playlist' : host;
  }

  /// Changes an M3U source. A URL sent back as it was shown (masked) keeps
  /// the saved one; `clearGuide` drops the guide.
  Future<Object?> _editM3u(ApiRequest r) async {
    final app = await _app(r['id']);
    final source = _sourceOf(app, r['sid']);
    if (source.kind != LiveSourceKind.m3u) {
      final name = (await r.body()).string('name');
      if (name != null && name.trim().isNotEmpty) {
        source.name = name.trim();
        await app.live.save();
      }
      return _sourceJson(app, source);
    }
    final body = await r.body();
    String? changed(String key, String? current) {
      final sent = body.string(key);
      if (sent == null || (current != null && sent.trim() == maskUrl(current))) return null;
      return sent;
    }

    try {
      await app.editM3uSource(
        source,
        name: body.string('name'),
        playlistUrl: changed('playlistUrl', source.playlistUrl),
        playlist: _picked(r, body.string('playlistUpload')),
        guideUrl: changed('guideUrl', source.guideUrl),
        guide: _picked(r, body.string('guideUpload')),
        clearGuide: body.boolean('clearGuide') ?? false,
      );
    } on LiveSourceException catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
    return _sourceJson(app, source);
  }

  Future<Object?> _removeSource(ApiRequest r) async {
    final app = await _app(r['id']);
    await app.removeLiveSource(_sourceOf(app, r['sid']));
    return {'ok': true};
  }

  // ---- Channels ----------------------------------------------------------------------

  /// The source's channels for the picker: names, numbers, groups and
  /// whether the guide has them (never their stream URLs).
  Future<Object?> _sourceChannels(ApiRequest r) async {
    final app = await _app(r['id']);
    final source = _sourceOf(app, r['sid']);
    return {
      'source': _sourceJson(app, source),
      'channels': [
        for (final c in app.live.entryFor(source).channels)
          {
            'key': c.key,
            'name': c.name,
            'number': c.number,
            'group': c.group,
            'hasGuide': c.hasGuide,
            'hasLogo': c.logo != null,
            'chosen': source.chosen.containsKey(c.key),
          },
      ],
    };
  }

  Future<Object?> _chooseChannels(ApiRequest r) async {
    final app = await _app(r['id']);
    final source = _sourceOf(app, r['sid']);
    final keys = (await r.body()).strings('keys') ?? (throw ApiError(HttpStatus.badRequest, 'Send keys.'));
    final known = {for (final c in app.live.entryFor(source).channels) c.key};
    if (!known.containsAll(keys)) throw ApiError(HttpStatus.badRequest, 'No such channel.');
    await app.chooseLiveChannels(source, keys.toSet());
    return _sourceChannels(r);
  }

  /// "Refresh now": answers at once; the source shows it refreshing.
  Future<Object?> _refreshSource(ApiRequest r) async {
    final app = await _app(r['id']);
    final source = _sourceOf(app, r['sid']);
    unawaited(app.refreshLiveNow(source));
    await Future<void>.delayed(Duration.zero);
    return _sourceJson(app, source);
  }
}
