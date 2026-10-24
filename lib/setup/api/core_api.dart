part of '../setup_server.dart';

/// The docker-server-core endpoints: status, restore, start fresh, signing
/// profiles in and out, per-profile export and the backup download.
extension _CoreApi on SetupServer {
  List<ApiRoute> get _coreRoutes => [
        ApiRoute('GET', 'status', Access.signedIn, (r) => _status(r)),
        ApiRoute('POST', 'restore', Access.admin, _receiveBackup),
        ApiRoute('POST', 'restore/{upload}/confirm', Access.admin, (r) => _restoreUpload(r, r['upload'])),
        ApiRoute('GET', 'profiles/{id}/sign-in', Access.profile, (r) async => _signInJson(r['id']),
            revision: Revision.none),
        ApiRoute('POST', 'profiles/{id}/sign-in', Access.profile, _signInStep, revision: Revision.none),
        ApiRoute('DELETE', 'profiles/{id}/session', Access.profile, _signOutProfile,
            revision: Revision.none, checkIfMatch: false),
        ApiRoute('PUT', 'profiles/{id}/export', Access.admin, _setExport, revision: Revision.household),
        ApiRoute('GET', 'backup', Access.admin, _download),
      ];

  // ---- Status -----------------------------------------------------------------

  /// The host shown in URLs: `NTV_LAN_HOST`, else the one the browser used.
  String _hostFor(HttpRequest request) {
    if (lanHost case final host? when host.isNotEmpty) return host;
    final host = request.requestedUri.host;
    return host.isEmpty ? (household.export?.lanHost ?? 'localhost') : host;
  }

  /// The household's state, with the profiles [r]'s account may use.
  Future<Map<String, Object?>> _status(ApiRequest r) async {
    final export = household.export;
    final host = _hostFor(r.http);
    final profiles = <Map<String, Object?>>[];
    var anySignedIn = false;
    for (final p in household.profiles) {
      final signIn = await _signInState(p);
      if (signIn.signedIn) anySignedIn = true;
      if (r.account?.mayUse(p.id) != true) continue;
      final settings = export?.settings.profiles[p.id];
      final exported = settings?.exported ?? false;
      final port = export?.serverOf(p.id)?.port ?? settings?.port;
      final base = port == null ? null : 'http://${SetupServer._urlHost(host)}:$port';
      profiles.add({
        'id': p.id,
        'name': p.name,
        'kid': p.isKid,
        'hasPin': p.hasPin,
        'signedIn': signIn.signedIn,
        'server': signIn.server,
        'user': signIn.user,
        'kind': signIn.kind,
        'hint': signIn.hint,
        'signingIn': _signIns[p.id]?.flow.finished == false,
        'exported': exported,
        'port': port,
        if (exported && base != null) ...{
          'url': base,
          'm3u': '$base/lineup.m3u',
          'xmltv': '$base/xmltv.xml',
        },
        'problem': exported
            ? (export?.problemText(p.id) ?? (signIn.signedIn ? null : 'Sign in to this profile here to export its channels.'))
            : null,
      });
    }
    final running = export?.streams.running ?? const [];
    return {
      'started': household.started && !_restoring,
      'device': PlatformInfo.deviceName,
      'host': host,
      'profiles': profiles,
      'canStartFresh': !anySignedIn,
      'encoder': export?.encoderInUse?.label,
      'streams': running.length,
      'streamLimit': export?.streamLimit,
      'discovery': export == null || !export.discoveryUnavailable,
      'discoveryMessage': export != null && export.discoveryUnavailable
          ? 'Discovery is off, so add the tuner by address. Run the container with host networking to turn it on.'
          : null,
    };
  }

  /// Whether [p] is signed in, and where: from its loaded state, else its
  /// saved sign-in.
  Future<({bool signedIn, String? server, String? user, String? kind, Map<String, Object?>? hint})> _signInState(
      Profile p) async {
    final app = household.appFor(p.id) ?? _signIns[p.id]?.app;
    if (app != null && app.phase != AppPhase.starting) {
      final s = app.session;
      final signedIn = app.phase != AppPhase.signedOut && s != null;
      return (
        signedIn: signedIn,
        server: s?.serverName ?? s?.serverUrl,
        user: s?.userName,
        kind: s?.kind.name,
        hint: signedIn ? null : SetupServer._hintJson(app.signInHint),
      );
    }
    final storage = AppStorage.existing(Directory('${household.root.root.path}/profiles/${p.id}'));
    final session = await storage.readRaw('session.json');
    if (session is Map<String, Object?> && session['accessToken'] is String) {
      return (
        signedIn: true,
        server: (session['serverName'] ?? session['serverUrl']) as String?,
        user: session['userName'] as String?,
        kind: session['kind'] as String? ?? 'jellyfin',
        hint: null,
      );
    }
    return (
      signedIn: false,
      server: null,
      user: null,
      kind: null,
      hint: SetupServer._hintJson(await storage.readRaw(BackupArchive.signInHintFile)),
    );
  }

  // ---- Restore and backup -----------------------------------------------------

  Future<Object?> _receiveBackup(ApiRequest r) async {
    final bytes = await r.bytes(SetupServer.maxUpload, BackupArchive.tooBig);
    final BackupArchive archive;
    try {
      archive = BackupArchive.check(bytes);
    } on BackupException catch (e) {
      throw ApiError(HttpStatus.badRequest, e.message);
    }
    final plan = await BackupRestorer(household).plan(archive);
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _upload = (id: id, bytes: bytes);
    final s = archive.summary;
    return {
      'id': id,
      'createdAt': archive.createdAt.toIso8601String(),
      'when': formatMoment(archive.createdAt.toLocal()),
      'device': archive.device,
      'profiles': s.profiles,
      'channels': s.channels,
      'blocks': s.blocks,
      'logos': s.logos,
      'backsUpFirst': plan.backsUpFirst,
      'needSignIn': plan.needPassword,
    };
  }

  Future<Object?> _restoreUpload(ApiRequest r, String id) async {
    final upload = _upload;
    if (upload == null || upload.id != id) throw ApiError(HttpStatus.notFound, 'Upload the backup again.');
    await _restoreBytes(upload.bytes, by: r.account);
    _upload = null;
    return _status(r);
  }

  /// Restores backup [bytes] (an upload or a saved backup) through the
  /// core restore path, then its accounts (design D9), keeping [by] an
  /// admin.
  Future<void> _restoreBytes(Uint8List bytes, {Account? by}) async {
    if (_restoring) throw ApiError(HttpStatus.conflict, 'A restore is already running.');
    _restoring = true;
    try {
      for (final s in _signIns.values) {
        s.flow.dispose();
      }
      _signIns.clear();
      _fresh.clear();
      _borrowed.clear();
      final archive = BackupArchive.check(bytes);
      await BackupRestorer(household).restore(bytes);
      accounts.restoreSection(archive.server, profiles: household.profiles.map((p) => p.id), keepAdmin: by?.id);
      ServerLog.info('Restored the backup from ${formatMoment(archive.createdAt.toLocal())} '
          '(${archive.device}): ${archive.summary.profiles.join(', ')}.');
    } on BackupException catch (e) {
      ServerLog.info('Couldn\'t restore the backup: ${e.message}');
      throw ApiError(HttpStatus.badRequest, e.message);
    } finally {
      _restoring = false;
      _bumpAll();
    }
    await rememberSecrets();
  }

  Future<Object?> _download(ApiRequest r) async {
    final backups = household.backups ?? (throw ApiError(HttpStatus.notFound));
    final built = await backups.build(BackupReason.manual);
    r.response.headers
      ..contentType = ContentType('application', 'octet-stream')
      ..set('Content-Disposition', 'attachment; filename="${TransferServer.fileName(built.createdAt)}"')
      ..contentLength = built.bytes.length;
    r.response.add(built.bytes);
    return ApiRequest.handled;
  }

  // ---- Profiles ---------------------------------------------------------------

  Future<Object?> _signOutProfile(ApiRequest r) async {
    final id = r['id'];
    _signIns.remove(id)?.flow.dispose();
    final app = await _app(id);
    await app.signOut();
    ServerLog.info('${household.profileById(id)?.name} was signed out.');
    return {'ok': true};
  }

  Future<Object?> _setExport(ApiRequest r) async {
    final id = r['id'];
    _profile(id);
    final export = household.export ?? (throw ApiError(HttpStatus.notFound, 'Live TV export isn\'t running.'));
    final body = await r.body();
    final on = body.boolean('exported');
    if (on != null && on != export.settings.isExported(id)) {
      await export.setProfileExported(id, on);
      // The export's own state replaces a borrowed one.
      if (on) _borrowed.remove(id);
    }
    final port = body.integer('port');
    if (port != null && port != export.settings.profiles[id]?.port) {
      final problem = await export.setPort(id, port);
      if (problem != null) throw ApiError(HttpStatus.conflict, problem);
    }
    return _status(r);
  }

  // ---- Signing a profile in ---------------------------------------------------

  Map<String, Object?> _signInJson(String id) {
    final s = _signIns[id];
    if (s == null) return {'stage': null, 'finished': false};
    final step = s.flow.step;
    final hint = s.flow.hint;
    return {
      'stage': step.stage.name,
      'busy': step.busy,
      'error': step.error,
      'finished': s.flow.finished,
      'hint': hint == null ? null : {'server': hint.server, 'user': hint.user, 'plex': hint.plex},
      'server': step.info == null
          ? null
          : {'name': step.info!.name, 'kind': step.kind.label, 'version': step.info!.version, 'url': step.info!.url},
      'quickConnect': step.quickConnectAvailable,
      'quickConnectCode': step.quickConnectCode,
      'plexCode': step.plexCode,
      'homeUsers': [
        for (final u in step.homeUsers) {'id': u.id, 'title': u.title, 'protected': u.protected},
      ],
      'homeUser': step.homeUser?.title,
      'servers': [
        for (final r in step.servers ?? const []) {'id': r.clientIdentifier, 'label': r.label, 'online': r.online},
      ],
    };
  }

  Future<Object?> _signInStep(ApiRequest r) async {
    final id = r['id'];
    final body = await r.body();
    final action = body.string('action');
    var s = _signIns[id];
    if (action == 'start') {
      s?.flow.dispose();
      final app = await _app(id);
      final flow = signInFlow?.call(app) ?? SignInFlow(app);
      final signIn = s = _signIns[id] = _SignIn(app, flow);
      flow.state.addListener(() => _onSignInStep(id, signIn));
      if (flow.hint != null) await flow.startFromHint();
      return _signInJson(id);
    }
    if (s == null) throw ApiError(HttpStatus.conflict, 'Start signing in first.');
    final flow = s.flow;
    switch (action) {
      case 'connect':
        await flow.connect(body.string('address') ?? '');
      case 'choosePassword':
        flow.choosePassword();
      case 'password':
        final password = body.string('password') ?? '';
        ServerLog.secret(password);
        await flow.signInWithPassword(body.string('user') ?? '', password);
      case 'quickConnect':
        await flow.startQuickConnect();
      case 'plex':
        await flow.startPlex();
      case 'homeUser':
        final user = flow.step.homeUsers.where((u) => u.id == body['id']).firstOrNull;
        if (user == null) throw ApiError(HttpStatus.badRequest, 'No such user.');
        await flow.pickUser(user);
      case 'homePin':
        await flow.enterHomePin(body.string('pin') ?? '');
      case 'server':
        final server = (flow.step.servers ?? const []).where((r) => r.clientIdentifier == body['id']).firstOrNull;
        if (server == null) throw ApiError(HttpStatus.badRequest, 'No such server.');
        await flow.pickServer(server);
      case 'back':
        flow.back();
      case 'cancel':
        _signIns.remove(id);
        flow.dispose();
      default:
        throw ApiError(HttpStatus.badRequest, 'Unknown action.');
    }
    return _signInJson(id);
  }

  /// A sign-in finished: its tokens never reach the log, and a Start fresh
  /// profile is exported (taking over the borrowed state).
  void _onSignInStep(String id, _SignIn s) {
    if (!s.flow.finished || s.done) return;
    s.done = true;
    final session = s.app.session;
    ServerLog.secret(session?.accessToken);
    ServerLog.secret(session?.accountToken);
    ServerLog.info('${household.profileById(id)?.name} signed in to ${session?.serverName ?? session?.serverUrl} '
        'as ${session?.userName}.');
    _bumpProfile(id);
    unawaited(() async {
      final export = household.export;
      if (_fresh.remove(id) && export != null && !export.settings.isExported(id)) {
        await export.setProfileExported(id, true);
        _borrowed.remove(id);
      }
      s.flow.dispose();
    }());
  }
}
