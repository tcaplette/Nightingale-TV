part of '../setup_server.dart';

/// SMB shares, conversion for other TVs and guide colours in the API
/// (smb-sources, admin-api "Shares in the API"). A share is signed in
/// through the same sign-in endpoints as a media server, with its own
/// actions; nothing here ever returns a password, a helper key or a file's
/// address.
extension _SharesApi on SetupServer {
  List<ApiRoute> get _shareRoutes => [
        ApiRoute('GET', 'profiles/{id}/servers/{key}/share', Access.profile, _shareJson, revision: Revision.none),
        ApiRoute('PUT', 'profiles/{id}/servers/{key}/share', Access.profileSettings, _editShare),
        ApiRoute('GET', 'profiles/{id}/servers/{key}/share/folders', Access.profileSettings, _shareFolders,
            revision: Revision.none),
        ApiRoute('POST', 'profiles/{id}/servers/{key}/share/check-again', Access.profileSettings, _checkAgain,
            revision: Revision.none),
        ApiRoute('GET', 'profiles/{id}/colors', Access.profile, (r) async => _colorsJson(await _app(r['id'])),
            revision: Revision.none),
        ApiRoute('PUT', 'profiles/{id}/colors', Access.profileSettings, _editColors),
        ApiRoute('GET', 'convert-helper', Access.admin, (r) async => _helperJson(), revision: Revision.none),
        ApiRoute('PUT', 'convert-helper', Access.admin, _editHelper, revision: Revision.none),
        ApiRoute('DELETE', 'convert-helper/tvs/{tv}', Access.admin, _removeTv, revision: Revision.none),
      ];

  Future<SmbServer> _shareOf(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final c = app.servers.byKey(r['key'])?.client;
    if (c is! SmbServer) throw ApiError(HttpStatus.notFound, tr.noSuchServer);
    return c;
  }

  static String _reason(CantPlayReason reason) => switch (reason) {
        CantPlayReason.damaged => tr.smbReasonDamaged,
        CantPlayReason.noVideo => tr.smbReasonNoVideo,
        CantPlayReason.tooMuch => tr.smbReasonTooMuch,
      };

  /// A share's settings: its folders, history, version, files still being
  /// read and Can't play list (names and folders in the share only).
  Future<Object?> _shareJson(ApiRequest r) async {
    final s = await _shareOf(r);
    return {
      'name': s.session.serverName,
      'smb1': s.smb1,
      'folders': [for (final m in s.config.mappings) m.toJson()],
      'historyName': s.historyName,
      'keepLocal': s.config.keepLocal,
      'historyPlace': (s.config.keepLocal ? HistoryPlace.device : s.historyPlace.value ?? HistoryPlace.share).name,
      'filesLeft': s.filesLeft.value,
      'cantPlay': [
        for (final e in s.cantPlay.entries) {'name': e.key.name, 'folder': e.key.folder, 'reason': e.value.name, 'label': _reason(e.value)}
      ],
    };
  }

  /// `{"name"?, "folders"?: [{"path", "type"}], "historyName"?, "keepLocal"?}`.
  Future<Object?> _editShare(ApiRequest r) async {
    final app = await _app(r['id'], library: true);
    final body = await r.body();
    if (body.string('name') case final name? when name.trim().isNotEmpty) await app.renameServer(r['key'], name);
    if (body.containsKey('historyName') || body.containsKey('keepLocal')) {
      final name = body.string('historyName');
      await app.setSmbHistory(r['key'],
          name: body.containsKey('historyName') ? () => name == null || name == app.smb.profileName ? null : name : null,
          keepLocal: body.boolean('keepLocal'));
    }
    if (body['folders'] case final List<Object?> folders) {
      final mappings = [for (final f in folders) ?SmbMapping.fromJson(f)];
      if (mappings.isEmpty) throw ApiError(HttpStatus.badRequest, tr.smbMapOne);
      await app.setSmbMappings(r['key'], mappings);
    }
    return _shareJson(r);
  }

  /// The share's folders at `?path=`, with the type each would be
  /// suggested as.
  Future<Object?> _shareFolders(ApiRequest r) async {
    final s = await _shareOf(r);
    final path = r.query['path'] ?? '';
    try {
      return {
        'path': path,
        'folders': [
          for (final f in await s.foldersAt(path))
            {'name': f, 'path': smbJoin(path, f), 'suggested': SmbFolderType.suggested(f)?.name}
        ],
      };
    } on ServerException catch (e) {
      throw ApiError(e.unreachable ? HttpStatus.serviceUnavailable : HttpStatus.badGateway, e.message);
    }
  }

  Future<Object?> _checkAgain(ApiRequest r) async {
    final s = await _shareOf(r);
    await s.checkAgain();
    return _shareJson(r);
  }

  Map<String, Object?> _colorsJson(AppState app) => {
        'on': app.settings.guideServerColors,
        'shown': app.guideColorsOn,
        'sources': [
          for (final s in app.colorSources)
            {'key': s.key, 'name': s.name, 'color': app.serverColors[s.key]?.name, 'hex': _hex(app.serverColors[s.key]?.cell)}
        ],
        'palette': [for (final c in ServerColor.palette) {'name': c.name, 'label': c.label, 'hex': _hex(c.cell), 'alternate': _hex(c.alternate)}],
      };

  static String? _hex(Color? c) => c == null ? null : '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// `{"on"?: bool, "colors"?: {"<key>": "<name>"}}`.
  Future<Object?> _editColors(ApiRequest r) async {
    final app = await _app(r['id']);
    final body = await r.body();
    if (body.boolean('on') case final on?) await app.setGuideServerColors(on);
    if (body['colors'] case final Map<String, Object?> colors) {
      for (final e in colors.entries) {
        if (ServerColor.byName('${e.value}') == null || !app.colorSources.any((s) => s.key == e.key)) {
          throw ApiError(HttpStatus.badRequest, tr.unknownAction);
        }
        await app.setServerColor(e.key, '${e.value}');
      }
    }
    return _colorsJson(app);
  }

  Map<String, Object?> _helperJson() {
    final h = household.convertHelper;
    return {
      'available': h != null,
      'on': h?.on ?? false,
      'port': h?.port,
      'code': h?.on == true ? h?.code : null,
      'tvs': [
        for (final p in h?.pairings ?? const <HelperPairing>[]) {'id': p.id, 'name': p.name, 'paired': p.paired.toIso8601String()}
      ],
    };
  }

  Future<Object?> _editHelper(ApiRequest r) async {
    final h = household.convertHelper ?? (throw ApiError(HttpStatus.notFound, tr.unknownAction));
    if ((await r.body()).boolean('on') case final on?) await h.setOn(on);
    return _helperJson();
  }

  Future<Object?> _removeTv(ApiRequest r) async {
    final h = household.convertHelper ?? (throw ApiError(HttpStatus.notFound, tr.unknownAction));
    await h.removePairing(r['tv']);
    return _helperJson();
  }
}
