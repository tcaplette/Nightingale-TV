import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/firewall_check.dart';
import 'package:nightingale_tv/remote/remote_control.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/phone_remote_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The remote's state set by hand: no server, no firewall commands.
class _FakeRemote extends RemoteControl {
  _FakeRemote(super.household) : super(firewallCheck: FirewallCheck(linux: false));

  int checks = 0;
  final phones = <RemotePairing>[];

  @override
  int? get port => url?.port;

  @override
  List<RemotePairing> get pairings => [...phones]..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

  @override
  Future<void> checkFirewall() async => checks++;

  @override
  Future<void> removePairing(String id) async {
    phones.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  @override
  Future<void> removeAllPairings() async {
    phones.clear();
    notifyListeners();
  }

  void on({FirewallState? firewall, bool working = false}) {
    enabled = true;
    url = Uri(scheme: 'http', host: '192.168.1.20', port: 8642);
    this.firewall = firewall;
    confirmed = working ? (address: '192.168.1.20', port: 8642) : null;
    notifyListeners();
  }
}

RemotePairing _phone(String name, {required int minutesAgo}) {
  final t = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return RemotePairing(id: name, name: name, keyHash: '0' * 64, paired: t, lastUsed: t);
}

const _firewalldClosed = FirewallState(kind: FirewallKind.firewalld, open: false, zone: 'public');

void main() {
  late Directory dir;
  late _FakeRemote remote;

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(3200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_phone_remote');
    });
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final household = Household(AppStorage.existing(dir));
    remote = _FakeRemote(household);
    household.remote = remote;
    await tester.pumpWidget(HouseholdScope(
      household: household,
      child: MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              autofocus: true,
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PhoneRemoteScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

  /// Every text on screen, joined.
  String allText(WidgetTester tester) => [
        for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? t.textSpan?.toPlainText() ?? '',
      ].join('\n');

  double opacityOf(WidgetTester tester, Finder f) =>
      tester.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity;

  testWidgets('Not confirmed yet: address, grouped code, QR with the code, Wi-Fi tips', (tester) async {
    await show(tester);
    expect(remote.checks, 1, reason: 'opening the screen checks the firewall');
    remote.on();
    await tester.pump();
    final code = remote.pairingCode!;
    expect(find.textContaining('Not confirmed yet'), findsOneWidget);
    expect(find.text('http://192.168.1.20:8642'), findsOneWidget);
    expect(find.textContaining('${code.substring(0, 3)} ${code.substring(3)}'), findsOneWidget);
    expect(find.byKey(ValueKey('http://192.168.1.20:8642/#pair=$code')), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(find.textContaining('guest network'), findsOneWidget);
    expect(find.textContaining('AP or client isolation'), findsOneWidget);
    expect(find.textContaining('sudo'), findsNothing, reason: 'no firewall, no command');
    expect(opacityOf(tester, find.byType(QrImageView)), 1);
    expect(allText(tester).toLowerCase(), isNot(contains('router')));
    expect(find.text('No phones paired yet.'), findsOneWidget);
  });

  testWidgets('ufw on: the ufw command is the first step', (tester) async {
    await show(tester);
    remote.on(firewall: const FirewallState(kind: FirewallKind.ufw));
    await tester.pump();
    expect(find.textContaining('Not confirmed yet'), findsOneWidget);
    expect(find.text('sudo ufw allow 8642/tcp'), findsOneWidget);
    expect(allText(tester).toLowerCase(), isNot(contains('router')));
  });

  testWidgets('Blocked: greyed address and QR, the fix, Check again by ▼ and OK and by a click', (tester) async {
    await show(tester);
    remote.on(firewall: _firewalldClosed);
    await tester.pump();
    expect(find.textContaining('Blocked by this computer\'s firewall'), findsNWidgets(2));
    expect(opacityOf(tester, find.byType(QrImageView)), 0.3);
    expect(opacityOf(tester, find.text('http://192.168.1.20:8642')), 0.3);
    expect(find.text('sudo firewall-cmd --permanent --add-port=8642/tcp && sudo firewall-cmd --reload'), findsOneWidget);
    expect(allText(tester).toLowerCase(), isNot(contains('router')));

    expect(remote.checks, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(), 'Check again');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(remote.checks, 2);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(remote.checks, 3);

    // ▼ goes on from Check again to the paired phones.
    remote.phones.addAll([_phone('iPad', minutesAgo: 9), _phone('iPhone · Safari', minutesAgo: 1)]);
    remote.on(firewall: _firewalldClosed);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(), 'Remove');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(), 'Remove all');

    // After the fix, Check again finds the port open.
    remote.on(firewall: const FirewallState(kind: FirewallKind.firewalld, open: true, zone: 'public'));
    await tester.pump();
    expect(find.textContaining('Not confirmed yet'), findsOneWidget);
    expect(opacityOf(tester, find.byType(QrImageView)), 1);
    expect(find.text('Check again'), findsNothing);
  });

  testWidgets('Working names the phone last used', (tester) async {
    await show(tester);
    remote.phones.addAll([_phone('iPad', minutesAgo: 90), _phone('iPhone · Safari', minutesAgo: 2)]);
    remote.on(working: true);
    await tester.pump();
    expect(find.textContaining('Working · last used by iPhone · Safari'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsNothing);
  });

  testWidgets('paired phones: newest use first, Remove and Remove all by D-pad and click', (tester) async {
    await show(tester);
    remote.phones.addAll([
      _phone('iPad', minutesAgo: 90),
      _phone('iPhone · Safari', minutesAgo: 2),
      _phone('Android phone · Chrome', minutesAgo: 30),
    ]);
    remote.on();
    await tester.pump();
    final names = ['iPhone · Safari', 'Android phone · Chrome', 'iPad'];
    final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
    expect(ys, orderedEquals([...ys]..sort()), reason: 'most recently used first');
    expect(find.textContaining('paired '), findsNWidgets(3));
    expect(find.textContaining('last used today'), findsNWidgets(3));

    // ▼ from On reaches the first Remove; OK removes that phone.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(), 'Remove');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(remote.phones.map((p) => p.name), isNot(contains('iPhone · Safari')));

    // A click removes another.
    await tester.tap(find.widgetWithText(TvButton, 'Remove').first);
    await tester.pumpAndSettle();
    expect(remote.phones.map((p) => p.name), ['iPad']);

    // Remove all asks first; Cancel keeps the phone.
    await tester.tap(find.widgetWithText(TvButton, 'Remove all'));
    await tester.pumpAndSettle();
    expect(find.text('Remove all phones?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(remote.phones, hasLength(1));

    // With the D-pad: ▼ to Remove all, OK, then ▶ and OK in the dialog.
    for (var i = 0; i < 4 && focused() != 'Remove all'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(focused(), 'Remove all');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(focused(), 'Cancel');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(remote.phones, isEmpty);
    expect(find.text('No phones paired yet.'), findsOneWidget);
  });

  testWidgets('a long list scrolls to keep focus in view', (tester) async {
    await show(tester);
    tester.view.physicalSize = const Size(3200, 1400);
    remote.phones.addAll([for (var i = 0; i < 12; i++) _phone('Phone $i', minutesAgo: i)]);
    remote.on(working: true);
    await tester.pumpAndSettle();
    for (var i = 0; i < 20 && focused() != 'Remove all'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(focused(), 'Remove all');
    final button = tester.getRect(find.widgetWithText(TvButton, 'Remove all'));
    expect(button.bottom, lessThanOrEqualTo(1400));
  });

  testWidgets('closing the screen closes the pairing window', (tester) async {
    await show(tester);
    remote.on();
    await tester.pump();
    expect(remote.pairingCode, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneRemoteScreen), findsNothing);
    expect(remote.pairingCode, isNull);
  });
}
