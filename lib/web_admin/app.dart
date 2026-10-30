import 'package:flutter/material.dart';

import '../ui/widgets/nightingale_mark.dart';
import 'api_client.dart';
import 'pages/backups_page.dart';
import 'pages/blocks_page.dart';
import 'pages/channels_page.dart';
import 'pages/commercials_page.dart';
import 'pages/export_page.dart';
import 'pages/groups_page.dart';
import 'pages/guide_page.dart';
import 'pages/live_page.dart';
import 'pages/profiles_page.dart';
import 'pages/server_page.dart';
import 'pages/sign_in_page.dart';
import 'pages/users_page.dart';
import 'session.dart';
import 'widgets/common.dart';

/// The web admin: the session, the router and the shell around the pages.
class WebAdminApp extends StatefulWidget {
  const WebAdminApp({super.key, required this.api});

  final ApiClient api;

  @override
  State<WebAdminApp> createState() => _WebAdminAppState();
}

class _WebAdminAppState extends State<WebAdminApp> {
  late final session = Session(widget.api);
  late final router = WebRouter(session);
  final _parser = _Parser();

  @override
  void initState() {
    super.initState();
    widget.api.onSignedOut = () {
      if (session.signedIn) session.clear();
    };
  }

  @override
  Widget build(BuildContext context) => AdminScope(
        api: widget.api,
        session: session,
        router: router,
        child: MaterialApp.router(
          title: 'Nightingale TV',
          debugShowCheckedModeBanner: false,
          theme: webAdminTheme(Brightness.light),
          darkTheme: webAdminTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          routerDelegate: router,
          routeInformationParser: _parser,
        ),
      );
}

/// Material 3 with the TV's accent and its bundled Barlow, so nothing is
/// fetched from the internet.
ThemeData webAdminTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFFFFD23F),
      fontFamily: 'Barlow',
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: const InputDecorationThemeData(helperMaxLines: 3, errorMaxLines: 3),
    );

/// The API, the session and navigation, for every page.
class AdminScope extends InheritedWidget {
  const AdminScope({super.key, required this.api, required this.session, required this.router, required super.child});

  final ApiClient api;
  final Session session;
  final WebRouter router;

  // Never changes, so pages may read it in initState.
  static AdminScope of(BuildContext context) => context.getInheritedWidgetOfExactType<AdminScope>()!;

  @override
  bool updateShouldNotify(AdminScope old) => false;
}

extension AdminContext on BuildContext {
  ApiClient get api => AdminScope.of(this).api;
  Session get session => AdminScope.of(this).session;

  /// Goes to [location] (a path, with a query if any).
  void go(String location) => AdminScope.of(this).router.go(location);
}

class _Parser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async => routeInformation.uri;

  @override
  RouteInformation restoreRouteInformation(Uri configuration) => RouteInformation(uri: configuration);
}

/// Paths in the address bar, so the back button, reloads and links work
/// (`/profiles/{id}/channels/{cid}`).
class WebRouter extends RouterDelegate<Uri> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  WebRouter(this.session) {
    session.addListener(notifyListeners);
  }

  final Session session;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  Uri location = Uri(path: '/');

  /// Where to go back to after signing in.
  Uri? _afterSignIn;
  bool _checked = false;

  @override
  Uri get currentConfiguration => location;

  void go(String to) {
    location = Uri.parse(to);
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    location = configuration;
    notifyListeners();
  }

  /// The first visit: whether a session is open already.
  Future<void> _check() async {
    try {
      await session.refresh();
    } on ApiException {
      // Shown by the sign-in page.
    }
    _checked = true;
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final segments = location.pathSegments.where((s) => s.isNotEmpty).toList();
    Widget page;
    if (segments.firstOrNull == 'setup' && location.queryParameters['token'] != null) {
      page = SetupLinkPage(token: location.queryParameters['token']!);
    } else if (!_checked) {
      if (!session.signedIn) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      page = const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (session.signedIn) _checked = true;
    } else if (!session.signedIn) {
      if (segments.firstOrNull != 'sign-in') _afterSignIn = location;
      page = SignInPage(onSignedIn: () {
        final next = _afterSignIn;
        _afterSignIn = null;
        go(next == null || next.path == '/sign-in' ? '/' : next.toString());
      });
    } else {
      page = Shell(location: location, child: _pageFor(segments));
    }
    return Navigator(
      key: navigatorKey,
      pages: [MaterialPage(key: const ValueKey('page'), child: page)],
      onDidRemovePage: (_) {},
    );
  }

  /// The page at [segments], for the signed-in account.
  Widget _pageFor(List<String> segments) {
    if (segments.isEmpty || segments.first == 'sign-in') {
      // Home: a signed-in profile's channels; before any is, signing in.
      final profile = session.profile?.signedIn == true
          ? session.profile
          : session.profiles.where((p) => p.signedIn && !p.locked).firstOrNull;
      if (profile == null) return const ServerPage();
      if (session.profileId != profile.id) WidgetsBinding.instance.addPostFrameCallback((_) => session.select(profile.id));
      return ChannelsPage(key: ValueKey('channels-${profile.id}'), profileId: profile.id);
    }
    switch (segments) {
      case ['setup']:
        return const ServerPage();
      case ['profiles']:
        return const ProfilesPage();
      case ['export']:
        return const ExportPage();
      case ['backups']:
        return const BackupsPage();
      case ['users']:
        return const UsersPage();
      case ['password']:
        return const PasswordPage();
      case ['profiles', final id, ...final rest]:
        if (session.profileById(id) == null) return const NotFound(text: "That profile isn't yours, or it's gone.");
        if (session.profileId != id) WidgetsBinding.instance.addPostFrameCallback((_) => session.select(id));
        final key = ValueKey('${segments.join('/')}?${location.query}');
        return ProfileGate(
          profileId: id,
          child: switch (rest) {
            ['channels'] => ChannelsPage(key: key, profileId: id),
            ['channels', final cid] => ChannelEditorPage(key: key, profileId: id, channelId: cid),
            ['guide'] => GuidePage(key: key, profileId: id),
            ['blocks'] => BlocksPage(key: key, profileId: id),
            ['blocks', final bid] => BlockEditorPage(key: key, profileId: id, blockId: bid),
            ['groups'] => GroupsPage(key: key, profileId: id),
            ['commercials'] => CommercialsPage(key: key, profileId: id),
            ['live'] => LivePage(key: key, profileId: id),
            ['live', final sid] => LiveChannelsPage(key: key, profileId: id, sourceId: sid),
            ['library'] => LibraryPage(key: key, profileId: id),
            _ => const NotFound(),
          },
        );
    }
    return const NotFound();
  }
}

/// Where the shell's navigation goes.
class _Destination {
  const _Destination(this.label, this.icon, this.path, {this.profile = false, this.admin = false});
  final String label;
  final IconData icon;

  /// Under `/profiles/{id}` when [profile].
  final String path;
  final bool profile;
  final bool admin;
}

const _destinations = [
  _Destination('Channels', Icons.live_tv, 'channels', profile: true),
  _Destination('Guide', Icons.view_timeline_outlined, 'guide', profile: true),
  _Destination('Programming blocks', Icons.event_note_outlined, 'blocks', profile: true),
  _Destination('Channel groups', Icons.folder_outlined, 'groups', profile: true),
  _Destination('Commercials', Icons.campaign_outlined, 'commercials', profile: true),
  _Destination('Live TV sources', Icons.settings_input_antenna, 'live', profile: true),
  _Destination('Library', Icons.video_library_outlined, 'library', profile: true),
  _Destination('Profiles', Icons.people_outline, '/profiles'),
  _Destination('Server and sign-in', Icons.dns_outlined, '/setup'),
  _Destination('Live TV export', Icons.cast_outlined, '/export', admin: true),
  _Destination('Backups', Icons.backup_outlined, '/backups', admin: true),
  _Destination('Users', Icons.manage_accounts_outlined, '/users', admin: true),
  _Destination('Change password', Icons.password, '/password'),
];

/// The frame around every signed-in page: side navigation on wide
/// screens, a menu on phones, the profile switcher, content at most 960 px
/// wide.
class Shell extends StatelessWidget {
  const Shell({super.key, required this.location, required this.child});

  final Uri location;
  final Widget child;

  static const wide = 840.0;

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final shown = [for (final d in _destinations) if (!d.admin || session.isAdmin) if (!d.profile || session.profileId != null) d];
        final segments = location.pathSegments;
        final selected = shown.indexWhere((d) => d.profile
            ? segments.length >= 3 && segments[0] == 'profiles' && segments[2] == d.path
            : location.path == d.path);
        void open(int i) {
          final d = shown[i];
          context.go(d.profile ? '/profiles/${session.profileId}/${d.path}' : d.path);
        }

        final scheme = Theme.of(context).colorScheme;
        // List tiles, not NavigationDrawerDestination: their labels wrap
        // under browser zoom and large text instead of overflowing.
        final nav = Drawer(
          width: 300,
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(children: [
                  NightingaleMark(height: 24, color: scheme.primary),
                  const SizedBox(width: 12),
                  Flexible(child: Text('Nightingale TV', style: Theme.of(context).textTheme.titleLarge)),
                ]),
              ),
              const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 8), child: ProfileSwitcher()),
              for (final (i, d) in shown.indexed) ...[
                if (i > 0 && shown[i - 1].profile && !d.profile) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(d.icon),
                  title: Text(d.label),
                  selected: i == selected,
                  selectedColor: scheme.onSecondaryContainer,
                  selectedTileColor: scheme.secondaryContainer,
                  shape: const StadiumBorder(),
                  onTap: () {
                    if (MediaQuery.sizeOf(context).width < wide) Navigator.of(context).maybePop();
                    open(i);
                  },
                ),
              ],
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text('Sign out ${session.userName}'),
                shape: const StadiumBorder(),
                onTap: () async {
                  await session.signOut();
                  if (context.mounted) context.go('/');
                },
              ),
              const SizedBox(height: 16),
            ]),
          ),
        );
        return LayoutBuilder(builder: (context, size) {
          final content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: child),
          );
          if (size.maxWidth >= wide) {
            return Scaffold(
              body: Row(children: [
                nav,
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ]),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(selected < 0 ? 'Nightingale TV' : shown[selected].label),
              actions: const [Padding(padding: EdgeInsets.only(right: 8), child: ProfileSwitcher(compact: true))],
            ),
            drawer: nav,
            body: content,
          );
        });
      },
    );
  }
}
