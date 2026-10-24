part of '../setup_server.dart';

/// Export settings and the server's saved backups (admin-api), admin-only.
extension _AdminApi on SetupServer {
  List<ApiRoute> get _adminRoutes => [
        ApiRoute('GET', 'export', Access.admin, (r) async => _exportJson(), revision: Revision.household),
        ApiRoute('PUT', 'export', Access.admin, _setExportSettings, revision: Revision.household),
        ApiRoute('GET', 'backups', Access.admin, (r) => _backups()),
        ApiRoute('GET', 'backups/{name}', Access.admin, _downloadSaved),
        ApiRoute('DELETE', 'backups/{name}', Access.admin, _deleteSaved, checkIfMatch: false),
        ApiRoute('POST', 'backups/{name}/restore', Access.admin, _restoreSaved),
      ];

  ExportService get _export =>
      household.export ?? (throw ApiError(HttpStatus.notFound, 'Live TV export isn\'t running.'));

  Map<String, Object?> _exportJson() {
    final export = _export;
    final s = export.settings;
    return {
      'quality': s.quality.label,
      'qualities': [for (final q in ExportQuality.values) q.label],
      'streamLimit': s.streamLimit,
      'streamLimitInUse': export.streamLimit,
      'encoder': s.encoder.name,
      'encoders': [
        for (final e in ExportEncoderChoice.values)
          {'id': e.name, 'label': e == ExportEncoderChoice.automatic ? 'Automatic' : 'Processor only'},
      ],
      'encoderInUse': export.encoderInUse?.label,
      'discovery': s.discovery,
      'discoveryUnavailable': export.discoveryUnavailable,
      'streams': export.streams.running.length,
    };
  }

  /// Quality, stream limit (`null`: automatic), encoder and discovery,
  /// through ExportService.
  Future<Object?> _setExportSettings(ApiRequest r) async {
    final export = _export;
    final body = await r.body();
    if (body.string('quality') case final label?) {
      final q = ExportQuality.values.where((q) => q.label == label).firstOrNull ??
          (throw ApiError(HttpStatus.badRequest, 'No such quality.'));
      if (q != export.settings.quality) await export.setQuality(q);
    }
    if (body.containsKey('streamLimit')) {
      final limit = body.integer('streamLimit');
      if (limit != null && (limit < 1 || limit > 16)) throw ApiError(HttpStatus.badRequest, 'Allow 1 to 16 streams.');
      if (limit != export.settings.streamLimit) await export.setStreamLimit(limit);
    }
    if (body.string('encoder') case final name?) {
      final e = ExportEncoderChoice.values.asNameMap()[name] ?? (throw ApiError(HttpStatus.badRequest, 'No such encoder.'));
      if (e != export.settings.encoder) await export.setEncoder(e);
    }
    if (body.boolean('discovery') case final on? when on != export.settings.discovery) await export.setDiscovery(on);
    return _exportJson();
  }

  // ---- Saved backups ---------------------------------------------------------------

  BackupStore get _store => household.backups?.store ?? (throw ApiError(HttpStatus.notFound, 'Backups are off.'));

  Future<StoredBackup> _saved(String name) async =>
      (await _store.list()).where((b) => b.name == name).firstOrNull ??
      (throw ApiError(HttpStatus.notFound, 'No such backup.'));

  Future<Object?> _backups() async => {
        'backups': [
          for (final b in await _store.list())
            {
              'name': b.name,
              'createdAt': b.createdAt.toUtc().toIso8601String(),
              'when': formatMoment(b.createdAt.toLocal()),
              'kind': b.kindLabel,
              'device': b.archive.device,
              'size': b.size,
              'profiles': b.summary.profiles,
              'channels': b.summary.channels,
              'blocks': b.summary.blocks,
            },
        ],
      };

  Future<Object?> _downloadSaved(ApiRequest r) async {
    final b = await _saved(r['name']);
    final bytes = await _store.read(b);
    r.response.headers
      ..contentType = ContentType('application', 'octet-stream')
      ..set('Content-Disposition', 'attachment; filename="${TransferServer.fileName(b.createdAt)}"')
      ..contentLength = bytes.length;
    r.response.add(bytes);
    return ApiRequest.handled;
  }

  Future<Object?> _deleteSaved(ApiRequest r) async {
    await _store.delete(await _saved(r['name']));
    return _backups();
  }

  /// Restores a saved backup through the core restore path.
  Future<Object?> _restoreSaved(ApiRequest r) async {
    final b = await _saved(r['name']);
    await _restoreBytes(await _store.read(b), by: r.account);
    return _status(r);
  }
}
