
part of '../setup_server.dart';

/// Export settings and the server's backups (admin-api), admin-only: when
/// the automatic backup was written, and the undo point (backup-simplify
/// D9). Any other backup name is not found.
extension _AdminApi on SetupServer {
  List<ApiRoute> get _adminRoutes => [
        ApiRoute('GET', 'export', Access.admin, (r) async => _exportJson(), revision: Revision.household),
        ApiRoute('PUT', 'export', Access.admin, _setExportSettings, revision: Revision.household),
        ApiRoute('GET', 'backups', Access.admin, (r) => _backups()),
        ApiRoute('GET', 'backups/{name}', Access.admin, _downloadUndo),
        ApiRoute('DELETE', 'backups/{name}', Access.admin, (r) async => throw ApiError(HttpStatus.notFound, tr.noSuchBackup),
            checkIfMatch: false),
        ApiRoute('POST', 'backups/{name}/restore', Access.admin, _restoreUndo),
      ];

  ExportService get _export =>
      household.export ?? (throw ApiError(HttpStatus.notFound, tr.liveTvExport));

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
          {'id': e.name, 'label': e == ExportEncoderChoice.automatic ? tr.automatic : tr.processorOnly},
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
          (throw ApiError(HttpStatus.badRequest, tr.noSuchQuality));
      if (q != export.settings.quality) await export.setQuality(q);
    }
    if (body.containsKey('streamLimit')) {
      final limit = body.integer('streamLimit');
      if (limit != null && (limit < 1 || limit > 16)) throw ApiError(HttpStatus.badRequest, tr.allow1To);
      if (limit != export.settings.streamLimit) await export.setStreamLimit(limit);
    }
    if (body.string('encoder') case final name?) {
      final e = ExportEncoderChoice.values.asNameMap()[name] ?? (throw ApiError(HttpStatus.badRequest, tr.noSuchEncoder));
      if (e != export.settings.encoder) await export.setEncoder(e);
    }
    if (body.boolean('discovery') case final on? when on != export.settings.discovery) await export.setDiscovery(on);
    return _exportJson();
  }

  // ---- Backups ---------------------------------------------------------------

  BackupStore get _store => household.backups?.store ?? (throw ApiError(HttpStatus.notFound, tr.backupsAreOff));

  /// The undo point, by its one name; any other name is not found.
  Future<StoredBackup> _undoPoint(String name) async =>
      (name == 'undo' ? await _store.undo() : null) ?? (throw ApiError(HttpStatus.notFound, tr.noSuchBackup));

  static Map<String, Object?> _summaryJson(StoredBackup b) => {
        'createdAt': b.createdAt.toUtc().toIso8601String(),
        'when': formatMoment(b.createdAt.toLocal()),
        'device': b.archive.device,
        'profiles': b.summary.profiles,
        'channels': b.summary.channels,
        'blocks': b.summary.blocks,
      };

  Future<Object?> _backups() async {
    final latest = await _store.latest();
    final undo = await _store.undo();
    return {
      'latest': latest == null ? null : _summaryJson(latest),
      'undo': undo == null
          ? null
          : {
              ..._summaryJson(undo),
              'reason': undo.reason,
              'subject': undo.archive.subject,
              'label': undo.undoLabel,
            },
    };
  }

  Future<Object?> _downloadUndo(ApiRequest r) async {
    final b = await _undoPoint(r['name']);
    final bytes = await _store.read(b);
    r.response.headers
      ..contentType = ContentType('application', 'octet-stream')
      ..set('Content-Disposition', 'attachment; filename="${TransferServer.fileName(b.createdAt)}"')
      ..contentLength = bytes.length;
    r.response.add(bytes);
    return ApiRequest.handled;
  }

  /// Restores the undo point through the core restore path, which saves
  /// the setup here as the new undo point first.
  Future<Object?> _restoreUndo(ApiRequest r) async {
    final b = await _undoPoint(r['name']);
    await _restoreBytes(await _store.read(b), by: r.account);
    return _status(r);
  }
}
