// Genre and decade channels on a real profile (genre-decade-channels 6.2,
// 6.3): the one-time update of a saved lineup, Reset channel lineup's
// order, and a decade channel and a decade + genre channel really playing.
//
// Run it on a COPY of a signed-in profile's data folder, never the real one:
//
//   cp -a ~/.local/share/com.coffeehauslabs.nightingale_tv /tmp/x/data
//   GD_DATA=/tmp/x/data NIGHTINGALE_TV_DEBUG_PLAYBACK=1 \
//     flutter test integration_test/genre_decade_live_test.dart -d linux
//
// On Android, GD_DATA is the app's own data folder (the default when unset)
// and the variables come from --dart-define.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

final _env = <String, String?>{
  ...Platform.environment,
  for (final (k, v) in const [
    ('GD_DATA', String.fromEnvironment('GD_DATA')),
    ('SNAP_DIR', String.fromEnvironment('SNAP_DIR')),
  ])
    if (v != '') k: v,
};

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} GDTEST $s');

/// Where [c] belongs in the D5 order.
int rank(Channel c) {
  final id = c.id;
  if (c.isLive || !c.auto) return 99;
  if (id == 'auto:all-shows') return 0;
  if (id.startsWith('auto:genre:')) return 1;
  if (id.startsWith('auto:decade:')) return ChannelGenerator.isPairChannel(c) ? 3 : 2;
  if (id.startsWith('auto:show:')) return 4;
  if (id == 'auto:movies') return 5;
  if (id.startsWith('auto:movies:decade:')) return ChannelGenerator.isPairChannel(c) ? 8 : 7;
  if (id.startsWith('auto:movies:')) return 6;
  return 9;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('genre and decade channels on a copied profile', (tester) async {
    final data = _env['GD_DATA'];
    if (data == null && !Platform.isAndroid) {
      markTestSkipped('Set GD_DATA to a copy of a signed-in data folder.');
      return;
    }
    if (!Platform.isAndroid) MediaKit.ensureInitialized();
    final storage = data == null ? await AppStorage.open() : await AppStorage.at(Directory(data));
    final household = Household(storage, runAnalysis: false);
    final store = BackupStore(Directory('${storage.root.path}/backups'));
    household.backups = BackupScheduler(household, store);
    final backupsBefore = (await store.list()).length;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> snap(String name) async {
      final snapDir = _env['SNAP_DIR'];
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    // Each profile's saved lineup, before the update.
    final saved = <String, List<Map<String, Object?>>>{};
    final profiles = Directory('${storage.root.path}/profiles');
    if (profiles.existsSync()) {
      for (final d in profiles.listSync().whereType<Directory>()) {
        final f = File('${d.path}/channels.json');
        if (f.existsSync()) {
          saved[d.uri.pathSegments.where((s) => s.isNotEmpty).last] =
              (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, Object?>>();
        }
      }
    }
    await tester.runAsync(household.start);
    final app = household.app!;
    final old = saved[household.current!.id] ?? const [];
    _say('profile ${household.current!.name}: saved lineup '
        '${[for (final c in old) '${c['number']} ${c['name']} (${c['id']})'].join(' | ')}');
    expect(app.settings.lineupVersion, AppSettings.currentLineupVersion);
    final kinds = [for (final b in await tester.runAsync(store.list) ?? <StoredBackup>[]) b.kind];
    _say('backups ${kinds.length} (was $backupsBefore): $kinds');
    expect(kinds.length, greaterThan(backupsBefore));
    expect(kinds, contains('before-lineup-cleanup'));
    // Old genre channels became the major genres', numbers and favorites kept.
    const becomes = {
      'auto:genre:Action & Adventure': ['auto:genre:Action', 'auto:genre:Adventure'],
      'auto:genre:Sci-Fi & Fantasy': ['auto:genre:Sci-Fi', 'auto:genre:Fantasy'],
      'auto:genre:Mystery': ['auto:genre:Thriller & Mystery'],
      'auto:genre:Thriller': ['auto:genre:Thriller & Mystery'],
    };
    var converted = 0;
    for (final c in old) {
      final targets = becomes[c['id']] ?? becomes[(c['id'] as String).replaceFirst('auto:movies:', 'auto:genre:')]
          ?.map((t) => t.replaceFirst('auto:genre:', 'auto:movies:'));
      if (!(c['id'] as String).startsWith('auto:genre:') && !(c['id'] as String).startsWith('auto:movies:')) continue;
      if (targets == null) continue;
      final now = [for (final t in targets) ?app.channelById(t)].firstOrNull;
      _say('${c['number']} ${c['name']} → ${now == null ? 'retired' : '${now.number} ${now.name} (${now.id})'}');
      if (now == null) continue;
      converted++;
      expect(now.number, lessThanOrEqualTo(c['number'] as int), reason: '${c['name']} keeps its number');
      if (c['favorite'] == true) expect(now.favorite, isTrue, reason: '${c['name']} was a favorite');
    }
    expect(converted, greaterThan(0), reason: 'the saved lineup had old genre channels');
    final before = {for (final c in app.allChannels) if (c.auto && !c.isLive) c.id};
    _say('updated lineup: ${[for (final c in app.allChannels) '${c.number} ${c.name} (${c.id})'].join(' | ')}');
    for (final old in ['auto:genre:Action & Adventure', 'auto:genre:Sci-Fi & Fantasy', 'auto:genre:Mystery', 'auto:genre:Thriller']) {
      expect(app.channelById(old), isNull, reason: old);
    }
    expect(app.allChannels.where((c) => c.auto && c.id.startsWith('auto:decade:')), isNotEmpty);

    // Reset channel lineup: the D5 order.
    await tester.runAsync(app.resetChannels);
    final generated = [for (final c in app.allChannels) if (c.auto && !c.isLive) c]..sort((a, b) => a.number.compareTo(b.number));
    _say('reset lineup: ${[for (final c in generated) '${c.number} ${c.name} (${c.playlist.length})'].join(' | ')}');
    final ranks = [for (final c in generated) rank(c)];
    expect(ranks, [...ranks]..sort(), reason: 'D5 order');
    expect(generated.map((c) => c.number), [for (var i = 1; i <= generated.length; i++) i]);

    // A decade channel and a decade + genre channel play.
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    final decade = generated.firstWhere((c) => c.id.startsWith('auto:decade:') && !ChannelGenerator.isPairChannel(c));
    final pair = generated.where((c) => ChannelGenerator.isPairChannel(c)).firstOrNull;
    for (final c in [decade, ?pair]) {
      await tester.runAsync(() => tuner.tune(c));
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (DateTime.now().isBefore(end) && tuner.status != TunerStatus.playing) {
        await wait(const Duration(milliseconds: 500));
      }
      await wait(const Duration(seconds: 5));
      _say('${c.name}: ${tuner.status} ${tuner.program?.item?.guideTitle} (${tuner.program?.item?.year})');
      await snap('gd-${c.number}');
      expect(tuner.status, TunerStatus.playing, reason: '${c.name}: ${tuner.error}');
      final item = tuner.program!.item!;
      expect(itemDecade(app.library, item), c.source.decades.single, reason: '${c.name} plays ${item.guideTitle}');
    }
    _say('done; ${before.length} generated channels before the reset');
    await tester.runAsync(() async {
      await tuner.stop();
      await household.closeAll();
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
