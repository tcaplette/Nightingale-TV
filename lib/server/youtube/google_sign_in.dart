import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../server_log.dart';
import 'youtube_client_config.dart';

/// Where Google answers: its own hosts, or a fake one in tests.
class GoogleEndpoints {
  const GoogleEndpoints({this.oauth = 'https://oauth2.googleapis.com', this.api = 'https://www.googleapis.com'});

  /// Sign-in, token refresh and revoke.
  final String oauth;

  /// The YouTube Data API (`<api>/youtube/v3/...`).
  final String api;

  static const google = GoogleEndpoints();

  /// Tests and live checks point the app at a fake Google with
  /// `--dart-define=NTV_GOOGLE_FAKE=http://127.0.0.1:<port>`.
  static GoogleEndpoints get current {
    const fake = String.fromEnvironment('NTV_GOOGLE_FAKE');
    return override ?? (fake.isEmpty ? google : const GoogleEndpoints(oauth: fake, api: fake));
  }

  static GoogleEndpoints? override;
}

/// Read-only YouTube.
const youtubeReadonlyScope = 'https://www.googleapis.com/auth/youtube.readonly';

/// The only scopes asked for: the account's id and read-only YouTube.
const googleScopes = 'openid $youtubeReadonlyScope';

/// A code shown on the TV for google.com/device.
class DeviceCode {
  const DeviceCode({
    required this.userCode,
    required this.verificationUrl,
    required this.deviceCode,
    required this.expiresAt,
    required this.interval,
  });

  final String userCode;
  final String verificationUrl;
  final String deviceCode;
  final DateTime expiresAt;
  final Duration interval;
}

class GoogleTokens {
  const GoogleTokens(
      {required this.accessToken, required this.refreshToken, required this.expiresAt, this.idToken, this.scope});

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? idToken;

  /// What was granted, space-separated; null when Google didn't say.
  final String? scope;

  /// Read-only YouTube was granted: on Google's page each permission can be
  /// left unticked.
  bool get canReadYouTube => scope == null || scope!.split(' ').contains(youtubeReadonlyScope);

  /// The Google account's stable id, from the `openid` ID token.
  String? get subject => idToken == null ? null : subjectOf(idToken!);

  /// The `sub` claim of an ID token (its signature isn't checked: it came
  /// straight from Google over TLS, as the token endpoint's answer).
  static String? subjectOf(String idToken) {
    final parts = idToken.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map && payload['sub'] is String ? payload['sub'] as String : null;
    } on Object {
      return null;
    }
  }
}

enum GoogleSignInFailure {
  /// The user chose Deny on Google's page.
  cancelled,

  /// Nobody entered the code in time; a new one is asked for.
  expired,

  /// Google refused the client (own client of the wrong type, or deleted).
  invalidClient,

  /// The sign-in was revoked or expired (Testing-mode projects: 7 days).
  invalidGrant,

  /// Google couldn't be reached, or answered with something else.
  failed,
}

class GoogleSignInException implements Exception {
  const GoogleSignInException(this.failure, [this.detail]);
  final GoogleSignInFailure failure;
  final String? detail;

  @override
  String toString() => 'GoogleSignInException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Google's sign-in for TVs and limited-input devices (youtube-subscriptions
/// D3): a code entered at google.com/device, then tokens by polling.
class GoogleDeviceSignIn {
  GoogleDeviceSignIn(this.client,
      {http.Client? httpClient,
      GoogleEndpoints? endpoints,
      DateTime Function()? now,
      Future<void> Function(Duration wait)? delay})
      : _http = httpClient ?? http.Client(),
        _endpoints = endpoints ?? GoogleEndpoints.current,
        _now = now ?? DateTime.now,
        _delay = delay ?? ((wait) => Future<void>.delayed(wait));

  final GoogleClient client;
  final http.Client _http;
  final GoogleEndpoints _endpoints;
  final DateTime Function() _now;
  final Future<void> Function(Duration wait) _delay;

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, Object?>> _post(String path, Map<String, String> body) async {
    final http.Response response;
    try {
      response = await _http.post(Uri.parse('${_endpoints.oauth}$path'), body: body).timeout(_timeout);
    } on Object catch (e) {
      throw GoogleSignInException(GoogleSignInFailure.failed, e.runtimeType.toString());
    }
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    final map = json is Map<String, Object?> ? json : <String, Object?>{};
    if (response.statusCode >= 200 && response.statusCode < 300) return map;
    final error = map['error'] as String?;
    throw _PollAnswer(error ?? 'http_${response.statusCode}');
  }

  /// A new code for the user to enter.
  Future<DeviceCode> requestCode() async {
    final Map<String, Object?> json;
    try {
      json = await _post('/device/code', {'client_id': client.id, 'scope': googleScopes});
    } on _PollAnswer catch (a) {
      throw _failureOf(a.error);
    }
    return DeviceCode(
      userCode: json['user_code'] as String,
      verificationUrl: json['verification_url'] as String? ?? 'https://www.google.com/device',
      deviceCode: json['device_code'] as String,
      expiresAt: _now().add(Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 1800)),
      interval: Duration(seconds: (json['interval'] as num?)?.toInt() ?? 5),
    );
  }

  /// Polls until [code] is entered and allowed. Throws
  /// [GoogleSignInFailure.cancelled] on Deny, [GoogleSignInFailure.expired]
  /// when the code ran out, and stops quietly (null) once [cancelled] says
  /// so (Back or Cancel).
  Future<GoogleTokens?> waitForTokens(DeviceCode code, {bool Function()? cancelled}) async {
    var interval = code.interval;
    while (true) {
      await _delay(interval);
      if (cancelled?.call() ?? false) return null;
      if (_now().isAfter(code.expiresAt)) throw const GoogleSignInException(GoogleSignInFailure.expired);
      try {
        final json = await _post('/token', {
          'client_id': client.id,
          'client_secret': client.secret,
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        });
        if (cancelled?.call() ?? false) return null;
        return _tokens(json, null);
      } on _PollAnswer catch (a) {
        switch (a.error) {
          case 'authorization_pending':
            continue;
          case 'slow_down':
            interval += const Duration(seconds: 5);
            continue;
          default:
            throw _failureOf(a.error);
        }
      } on GoogleSignInException catch (e) {
        // A network hiccup while waiting: keep waiting.
        if (e.failure == GoogleSignInFailure.failed) continue;
        rethrow;
      }
    }
  }

  /// A fresh access token for [refreshToken]. Throws
  /// [GoogleSignInFailure.invalidGrant] when the sign-in is gone.
  Future<GoogleTokens> refresh(String refreshToken) async {
    try {
      final json = await _post('/token', {
        'client_id': client.id,
        'client_secret': client.secret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      });
      return _tokens(json, refreshToken);
    } on _PollAnswer catch (a) {
      throw _failureOf(a.error);
    }
  }

  /// Ends the sign-in on Google's side. Never throws: a failed revoke
  /// doesn't keep anything (D12).
  Future<bool> revoke(String token) async {
    try {
      await _post('/revoke', {'token': token});
      return true;
    } on Object catch (e) {
      ServerLog.info('YouTube revoke failed: ${e is _PollAnswer ? e.error : e.runtimeType}');
      return false;
    }
  }

  GoogleTokens _tokens(Map<String, Object?> json, String? refreshToken) {
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String? ?? refreshToken;
    if (refresh == null) throw const GoogleSignInException(GoogleSignInFailure.failed, 'no refresh token');
    ServerLog.secret(access);
    ServerLog.secret(refresh);
    return GoogleTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: _now().add(Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600)),
      idToken: json['id_token'] as String?,
      scope: json['scope'] as String?,
    );
  }

  static GoogleSignInException _failureOf(String error) => GoogleSignInException(switch (error) {
        'access_denied' => GoogleSignInFailure.cancelled,
        'expired_token' => GoogleSignInFailure.expired,
        'invalid_client' || 'unauthorized_client' => GoogleSignInFailure.invalidClient,
        'invalid_grant' => GoogleSignInFailure.invalidGrant,
        _ => GoogleSignInFailure.failed,
      }, error);

  void close() => _http.close();
}

class _PollAnswer implements Exception {
  const _PollAnswer(this.error);
  final String error;
}

/// A signed-in Google account's tokens, refreshed 60 s before they expire
/// (D3). [onRefreshed] keeps a rotated refresh token.
class GoogleAuth {
  GoogleAuth(this.signIn, GoogleTokens tokens, {DateTime Function()? now, this.onRefreshed})
      : _tokens = tokens,
        _now = now ?? DateTime.now;

  final GoogleDeviceSignIn signIn;
  GoogleTokens _tokens;
  final DateTime Function() _now;
  final void Function(GoogleTokens tokens)? onRefreshed;
  Future<GoogleTokens>? _refreshing;

  String get refreshToken => _tokens.refreshToken;

  /// When the access token was last refreshed (the daily authorization
  /// check, D11).
  DateTime? lastRefresh;

  /// A valid access token. Throws [GoogleSignInException] with
  /// [GoogleSignInFailure.invalidGrant] when the sign-in is gone.
  Future<String> accessToken({bool force = false}) async {
    if (force || !_now().isBefore(_tokens.expiresAt.subtract(const Duration(seconds: 60)))) {
      _tokens = await (_refreshing ??= signIn.refresh(_tokens.refreshToken).whenComplete(() => _refreshing = null));
      lastRefresh = _now();
      onRefreshed?.call(_tokens);
    }
    return _tokens.accessToken;
  }
}
