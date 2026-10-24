import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/profiles/household.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_server_mode'));
  tearDown(() async => dir.delete(recursive: true));

  /// Waits for every loaded profile to finish starting.
  Future<void> settle(Household h) async {
    for (final p in h.profiles) {
      final app = h.appFor(p.id);
      for (var i = 0; app != null && i < 200 && app.phase == AppPhase.starting; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  Future<Household> serverHousehold() async {
    final h = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    await h.start();
    return h;
  }

  test('one profile without a PIN is not put on screen', () async {
    final household = await serverHousehold();
    expect(household.started, isTrue);
    expect(household.profiles, hasLength(1));
    expect(household.profiles.single.hasPin, isFalse);
    expect(household.current, isNull);
    expect(household.app, isNull);
  });

  test('exported profiles start off-screen', () async {
    final household = await serverHousehold();
    final p = household.profiles.single;
    await (await signedInApp((await household.storageFor(p)).root, fakeLibrary())).close();
    await household.setExportedProfiles({p.id});
    final app = household.appFor(p.id)!;
    expect(app.background, isTrue);
    expect(household.app, isNull);
    for (var i = 0; i < 100 && app.phase != AppPhase.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(app.phase, AppPhase.ready);
    await household.setExportedProfiles({});
  });

  test("the setup page's temporary state closes after sign-in, or stays when exported", () async {
    final household = await serverHousehold();
    final a = household.profiles.single;
    final b = household.newProfile()..name = 'B';
    await household.saveProfile(b);

    final temp = (await household.appForSetup(a.id))!;
    expect(temp.background, isTrue);
    expect(household.appFor(a.id), isNull, reason: 'not exported');
    expect(await household.appForSetup(a.id), same(temp), reason: 'one state per profile');
    await household.releaseSetup(a.id);
    expect(await household.appForSetup(a.id), isNot(same(temp)), reason: 'closed and opened again');
    await household.releaseSetup(a.id);

    // Exported while the setup page had it open: that state is kept.
    final kept = (await household.appForSetup(b.id))!;
    await household.setExportedProfiles({b.id});
    await household.releaseSetup(b.id);
    expect(household.appFor(b.id), same(kept));
    expect(kept.phase, isNot(AppPhase.starting));
    await household.setExportedProfiles({});
  });

  group('export in server mode', () {
    ExportService exportFor(Household h) => ExportService(h, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});

    test('restored from an Android TV: everyone without a PIN is exported, Dad with his PIN is not', () async {
      final household = await serverHousehold();
      final mom = household.profiles.single..name = 'Mom';
      mom.setPin(null);
      await household.saveProfile(mom);
      final kids = household.newProfile()..name = 'Kids';
      await household.saveProfile(kids);
      final dad = household.newProfile()..name = 'Dad';
      dad.setPin('4321');
      await household.saveProfile(dad);
      // Android's export.json: off, nothing exported.
      await household.root.writeJson('export.json', ExportSettings.off.toJson());

      // 5004 and 5005 on a machine where they're free: the lowest free
      // ports from 5004, in profile order.
      final free = <int>[];
      for (var p = ExportSettings.firstPort; free.length < 3; p++) {
        if (await ExportService.portFree(p)) free.add(p);
      }
      final service = exportFor(household);
      await service.load();
      addTearDown(() async {
        await settle(household);
        await service.stop();
        await household.setExportedProfiles({});
      });
      expect(service.settings.isExported(mom.id), isTrue);
      expect(service.settings.isExported(kids.id), isTrue);
      expect(service.settings.isExported(dad.id), isFalse);
      expect(service.settings.profiles[mom.id]!.port, free[0]);
      expect(service.settings.profiles[kids.id]!.port, free[1]);
      expect(service.serverOf(mom.id)?.port, free[0]);
      expect(service.serverOf(kids.id)?.port, free[1]);
      expect(service.serverOf(dad.id), isNull);
      final saved = ExportSettings.fromJson(await household.root.readJson('export.json'));
      expect(saved.isExported(mom.id) && saved.isExported(kids.id), isTrue, reason: 'saved');
      expect(saved.enabled, isFalse, reason: "the switch isn't saved");

      // Turned on with his PIN on the setup page (the PIN is the caller's).
      await service.setProfileExported(dad.id, true);
      expect(service.serverOf(dad.id)?.port, free[2]);
    });

    test('on a bridge network discovery is off and nothing is announced', () async {
      final household = await serverHousehold();
      final sent = <List<int>>[];
      final asked = <String?>[];
      final service = ExportService(household,
          ssdp: () => SsdpResponder()..sendOverride = (d, _, _) => sent.add(d),
          bridgeNetwork: (lan) async {
            asked.add(lan);
            return true;
          });
      await service.load();
      addTearDown(() async {
        await settle(household);
        await service.stop();
        await household.setExportedProfiles({});
      });
      expect(service.serverOf(household.profiles.single.id), isNotNull);
      expect(service.discoveryUnavailable, isTrue);
      expect(sent, isEmpty);
      expect(asked, [null]);
    });

    test('bridge detection: NTV_LAN_HOST that this machine lacks, or only Docker bridge addresses', () async {
      expect(await ExportService.onBridgeNetwork('203.0.113.77'), isTrue, reason: 'not an address here');
      final mine = [for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) ...i.addresses];
      expect(await ExportService.onBridgeNetwork(mine.first.address), isFalse);
    });

    test('export.json says off with one exported profile: it is served and the file still says off', () async {
      final household = await serverHousehold();
      final p = household.profiles.single;
      var port = ExportSettings.firstPort;
      while (!await ExportService.portFree(port)) {
        port++;
      }
      await household.root.writeJson('export.json',
          ExportSettings.off.withExported(p.id, true, portFree: (x) => x == port).toJson());
      final service = exportFor(household);
      await service.load();
      addTearDown(() async {
        await settle(household);
        await service.stop();
        await household.setExportedProfiles({});
      });
      expect(service.serverOf(p.id)?.port, port);
      await service.setEnabled(false);
      expect(service.serverOf(p.id), isNotNull, reason: 'no switch in server mode');
      final saved = ExportSettings.fromJson(await household.root.readJson('export.json'));
      expect(saved.enabled, isFalse);
      expect(saved.isExported(p.id), isTrue);
      expect(household.appFor(p.id), isNotNull);
      await settle(household);
      expect(household.appFor(p.id)!.phase, AppPhase.signedOut);
      expect(service.problemText(p.id), 'Sign in to this profile here to export its channels.');
    });
  });

  test("the daily backup's first check runs after start-up, with no picture", () async {
    final household = await serverHousehold();
    final store = BackupStore(Directory('${household.root.root.path}/backups'));
    final backups = household.backups = BackupScheduler(household, store);
    // Signed in on the setup page.
    final p = household.profiles.single;
    await (await signedInApp((await household.storageFor(p)).root, fakeLibrary())).close();
    final first = BackupScheduler.firstCheck;
    BackupScheduler.firstCheck = const Duration(milliseconds: 50);
    addTearDown(() {
      BackupScheduler.firstCheck = first;
      backups.dispose();
    });
    backups.start();
    expect(household.app, isNull, reason: 'nothing on screen to wait for');
    for (var i = 0; i < 200 && await store.newest() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    final newest = await store.newest();
    expect(newest, isNotNull);
    expect(newest!.kind, 'daily');
  });
}
