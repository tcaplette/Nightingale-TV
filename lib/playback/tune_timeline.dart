/// One open's way from "tune" to its first picture, stage by stage, for the
/// playback diagnostics: what the app waited for before opening, how long
/// the server took to answer, how much of the file mpv read before it could
/// start (an index at the end of an MP4 is read in full first), the seek to
/// the join point, and the first decoded frame. It also counts what else
/// used the network meanwhile (the app's own requests, the analyzer).
///
/// Times are from the diagnostics clock; mpv's milestones come from its
/// verbose log ([mpvLine]), so they need a diagnostics build.
class TuneTimeline {
  TuneTimeline(this.trigger, this.what, this.startedAt);

  /// Why it's opening: launch, channel, segment, retune, resume, fallback.
  final String trigger;

  /// The channel (and what's on), for the log.
  final String what;
  final Duration startedAt;

  /// The kind of open (direct, direct-commercial, transcode@…), once known.
  String kind = '-';

  // ---- Before the open ------------------------------------------------------

  /// Things the tuner awaited before calling open, in order: (name, took).
  final waits = <(String, Duration)>[];

  Duration? openCalled;
  Duration? openReturned;

  // ---- mpv milestones -------------------------------------------------------

  /// mpv started the HTTP request for the media.
  Duration? requested;

  /// The first response headers came back (mpv logs the MIME type).
  Duration? firstResponse;

  /// The container is recognized and its header (and index) read.
  Duration? formatDetected;
  String? format;

  /// Bytes the probe read (mpv logs it for streams like MPEG-TS).
  int? probeBytes;

  /// mpv started playback (tracks chosen) and, when joining, seeked.
  Duration? playbackStarted;
  Duration? firstVideoDecoded;
  Duration? firstFrameShown;
  Duration? restartComplete;

  /// The tuner saw the picture move: the open is done.
  Duration? picture;

  /// Every HTTP range request mpv made (a new connection each): when, from
  /// and to which byte, and whether it was before the format was known.
  final seeks = <({Duration at, int from, int to, bool beforeFormat})>[];

  /// Bytes read from the end of the file before playback could start: an
  /// MP4 whose index (moov) comes after the media.
  int? indexAtEndBytes;
  Duration? indexAtEndTook;

  // ---- Network used by others meanwhile ------------------------------------

  /// The app's own HTTP requests that overlapped the open: (path, took, bytes).
  final appRequests = <(String, Duration, int)>[];
  int analyzerBytes = 0;

  // ---- The playback proxy -----------------------------------------------------

  /// Opened through the playback proxy (null: not known).
  bool? proxy;

  /// Each request the proxy sent upstream for mpv: on a warm connection or
  /// a new one.
  final upstream = <bool>[];

  /// How the index cache served the open: hit, saved (learned), stale.
  final cacheUse = <String>{};

  void upstreamRequest(bool warm) {
    if (!done) upstream.add(warm);
  }

  void cache(String what) {
    if (!done) cacheUse.add(what);
  }

  /// How it ended: null while open; "picture", "failed: …", "superseded".
  String? outcome;
  Duration? endedAt;

  bool get done => outcome != null;

  /// Records something the tuner waited for before it could open.
  void waited(String name, Duration took) => waits.add((name, took));

  static final _seek = RegExp(r'stream level seek from (\d+) to (\d+)');
  static final _probe = RegExp(r'find_stream_info\(\) finished after (\d+) bytes');
  /// The media's format (mpv's own demuxers, like Matroska's, or
  /// libavformat's); media_kit's playlist file comes first, as "txt".
  static final _format = RegExp(r'demux: Detected file format: (?!txt )(.+)$');

  /// One mpv log line, as "level prefix: text" (see `TunerPlayer.logStream`).
  void mpvLine(String line, Duration at) {
    if (done) return;
    final text = line.trim();
    if (requested == null && text.contains('ffmpeg: Opening http')) {
      requested = at;
    } else if (firstResponse == null && text.contains('ffmpeg: Mime-type:')) {
      firstResponse = at;
    } else if (_seek.firstMatch(text) case final m?) {
      final from = int.parse(m.group(1)!), to = int.parse(m.group(2)!);
      final before = formatDetected == null;
      // The bytes read since the last seek ended (an index at the end of
      // the file is read between the jump there and the jump back).
      final last = seeks.lastOrNull;
      if (last != null && last.beforeFormat && last.to > last.from && from >= last.to) {
        indexAtEndBytes = from - last.to;
        indexAtEndTook = at - last.at;
      }
      seeks.add((at: at, from: from, to: to, beforeFormat: before));
    } else if (_probe.firstMatch(text) case final m?) {
      probeBytes = int.parse(m.group(1)!);
    } else if (formatDetected == null && _format.firstMatch(text) != null) {
      formatDetected = at;
      format = _format.firstMatch(text)!.group(1)!.replaceAll(' (libavformat)', '');
      // Jumped forward before the format was known, and never back: the
      // whole tail was read, which is the index-at-end case too.
      final last = seeks.lastOrNull;
      if (indexAtEndBytes == null && last != null && last.beforeFormat && last.to > last.from) {
        indexAtEndTook = at - last.at;
      }
    } else if (playbackStarted == null && text.contains('cplayer: Starting playback')) {
      playbackStarted = at;
    } else if (firstVideoDecoded == null && (text.contains('vd: Decoder format:') || text.contains('vd: Using '))) {
      firstVideoDecoded = at;
    } else if (firstFrameShown == null && text.contains('first video frame after restart shown')) {
      firstFrameShown = at;
    } else if (restartComplete == null && text.contains('playback restart complete')) {
      restartComplete = at;
    }
  }

  /// An app HTTP request that ran (at least partly) during the open.
  void appRequest(String path, Duration took, int bytes) {
    if (!done) appRequests.add((path, took, bytes));
  }

  void finish(String how, Duration at) {
    if (done) return;
    outcome = how;
    endedAt = at;
    if (how == 'picture') picture = at;
  }

  /// The stages in order, as (name, took). A stage whose end mpv didn't log
  /// folds into the next one.
  List<(String, Duration)> get stages {
    final out = <(String, Duration)>[];
    var from = startedAt;
    void stage(String name, Duration? to) {
      if (to == null || to < from) return;
      out.add((name, to - from));
      from = to;
    }

    stage('wait', openCalled);
    stage('player-setup', requested);
    stage('first-response', firstResponse);
    stage(indexAtEndBytes != null || indexAtEndTook != null ? 'header+index-at-end' : 'header', formatDetected);
    stage('start', playbackStarted);
    stage('seek+decode', firstVideoDecoded ?? firstFrameShown);
    stage('show', firstFrameShown);
    stage('picture-moving', picture ?? endedAt);
    return out;
  }

  Duration? get total => endedAt == null ? null : endedAt! - startedAt;

  /// The longest stage.
  (String, Duration)? get slowest {
    (String, Duration)? worst;
    for (final s in stages) {
      if (worst == null || s.$2 > worst.$2) worst = s;
    }
    return worst;
  }

  /// What made this open slow, each a short tag (see [summary]).
  List<String> get problems {
    final p = <String>[];
    for (final (name, took) in waits) {
      if (took > const Duration(milliseconds: 300)) p.add('waited-for-$name');
    }
    final fr = requested != null && firstResponse != null ? firstResponse! - requested! : null;
    if (fr != null && fr > const Duration(seconds: 1)) p.add('slow-first-response');
    // Reading a small index (Matroska's cues) from the end is quick.
    if ((indexAtEndBytes ?? 0) > 256 * 1024 || (indexAtEndTook ?? Duration.zero) > const Duration(milliseconds: 500)) {
      p.add('index-at-end');
    }
    // The header (an MP4's index, wherever it is) took long to read.
    final header = stages.where((s) => s.$1.startsWith('header')).firstOrNull;
    if (header != null && header.$2 > const Duration(seconds: 1)) p.add('slow-header');
    final reconnects = seeks.length;
    if (reconnects > 1) p.add('reconnects=$reconnects');
    final appBytes = appRequests.fold(0, (a, r) => a + r.$3);
    // The tune's own decision is the one request an open may wait for; the
    // stop of the transcode before it is sent first, by design, and not
    // awaited.
    if (appRequests.any((r) => !r.$1.endsWith('/PlaybackInfo') && !r.$1.endsWith('/Videos/ActiveEncodings'))) {
      p.add('app-http-during-open');
    }
    if (appBytes > 64 * 1024) p.add('app-download-during-open');
    if (analyzerBytes > 0) p.add('analyzer-download-during-open');
    if (upstream.contains(false)) p.add('cold-connection');
    return p;
  }

  static String _s(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  static String _bytes(int b) => b >= 1 << 20
      ? '${(b / (1 << 20)).toStringAsFixed(2)} MB'
      : b >= 1024
          ? '${(b / 1024).round()} KB'
          : '$b B';
  static String _rate(int bytes, Duration took) =>
      took <= Duration.zero ? '-' : '${(bytes * 8 / took.inMicroseconds).toStringAsFixed(2)} Mbps';

  /// One line for the log: the total, the slowest stage, every stage, the
  /// details that explain them, and the problems found.
  String summary() {
    final t = total;
    final worst = slowest;
    final parts = <String>[
      '$trigger $what kind=$kind outcome=${outcome ?? 'open'} total=${t == null ? '-' : _s(t)}',
      if (worst != null) 'slowest=${worst.$1} ${_s(worst.$2)}',
      'stages: ${[for (final (n, d) in stages) '$n ${_s(d)}'].join(', ')}',
      if (waits.isNotEmpty) 'waited: ${[for (final (n, d) in waits) '$n ${_s(d)}'].join(', ')}',
      if (format != null) 'format=$format',
      if (probeBytes != null) 'probe=${_bytes(probeBytes!)}',
      if (indexAtEndBytes != null)
        'index-at-end=${_bytes(indexAtEndBytes!)} in ${_s(indexAtEndTook!)} (${_rate(indexAtEndBytes!, indexAtEndTook!)})'
      else if (indexAtEndTook != null)
        'index-at-end read in ${_s(indexAtEndTook!)}',
      'range-requests=${seeks.length}',
      if (proxy != null) 'proxy=${proxy! ? 'on' : 'off'}',
      if (proxy ?? false) 'upstream=${upstream.isEmpty ? 'none' : upstream.map((w) => w ? 'warm' : 'cold').join(',')}',
      if ((proxy ?? false) && kind.startsWith('direct')) 'cache=${cacheUse.isEmpty ? 'miss' : cacheUse.join('+')}',
      'app-http=${appRequests.length}'
          '${appRequests.isEmpty ? '' : ' (${appRequests.map((r) => '${r.$1} ${_s(r.$2)} ${_bytes(r.$3)}').join('; ')})'}',
      'analyzer=${_bytes(analyzerBytes)}',
      'problems=${problems.isEmpty ? 'none' : problems.join(',')}',
    ];
    return parts.join(' | ');
  }
}
