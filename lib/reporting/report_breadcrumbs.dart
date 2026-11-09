import 'package:flutter/widgets.dart';

import '../server/media_server.dart';
import 'error_reports.dart';

/// The error reports' trail of screens (error-reporting D4): each screen's
/// widget type as it opens and closes. Screens are pushed without route
/// names, so the name is read from the route's page once it's built.
class ReportRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _record('open', route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      ErrorReports.breadcrumb('navigation', 'Closed ${_names[route] ?? _routeName(route)}');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record('replace', newRoute);
  }

  final _names = Expando<String>();

  void _record(String how, Route<dynamic> route) {
    if (!ErrorReports.running) return;
    // The page exists after the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = _names[route] = screenName(route);
      ErrorReports.breadcrumb('navigation', how == 'open' ? 'Opened $name' : 'Replaced with $name');
    });
  }

  /// The route's page widget type ("ServersScreen"), or the route's name.
  static String screenName(Route<dynamic> route) {
    if (route is ModalRoute) {
      final context = route.subtreeContext;
      if (context != null) {
        String? found;
        var depth = 0;
        void visit(Element e) {
          if (found != null || depth > 60) return;
          final type = e.widget.runtimeType.toString();
          if (_isPage(type)) {
            found = type;
            return;
          }
          depth++;
          e.visitChildElements(visit);
          depth--;
        }

        context.visitChildElements(visit);
        if (found != null) return found!;
      }
    }
    return _routeName(route);
  }

  static bool _isPage(String type) =>
      type.endsWith('Screen') || type.endsWith('Picker') || type.endsWith('Page') || type.endsWith('Dialog');

  static String _routeName(Route<dynamic> route) => route.settings.name ?? route.runtimeType.toString();
}

/// A server result on the trail: what was done ([action]: "sign-in",
/// "library"), the server kind and how it went. Never the server's name or
/// address.
void reportServerResult(String action, ServerKind? kind, [Object? error]) {
  final result = switch (error) {
    null => 'ok',
    final ServerException e when e.unreachable => 'unreachable',
    final ServerException e when e.statusCode == 401 || e.statusCode == 403 => 'refused',
    final ServerException e => 'error ${e.statusCode}',
    _ => 'error ${error.runtimeType}',
  };
  ErrorReports.breadcrumb('server', '$action: $result', data: {'kind': kind?.name ?? 'unknown', 'result': result});
}
