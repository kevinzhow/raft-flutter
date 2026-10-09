import 'package:flutter/material.dart';

/// The account root owns `/` and `/servers`; WorkspaceNavigation continues to
/// own only authorized `/s/:slug` surfaces. No placeholder server is invented.
class RaftAppRouter extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  RaftAppRouter({
    required this.home,
    required this.onLocation,
    required this.onRootBack,
    required this.observers,
  });
  final Widget Function(BuildContext) home;
  final Future<void> Function(Uri) onLocation;
  final Future<bool> Function() onRootBack;
  final List<NavigatorObserver> observers;
  Uri _location = Uri(path: '/');
  bool _replaceNextReport = false;
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  Uri get currentConfiguration => _location;

  void publish(Uri location, {bool replace = false}) {
    if (_location == location) return;
    _location = location;
    _replaceNextReport = replace;
    notifyListeners();
  }

  bool consumeReplacement() {
    final replace = _replaceNextReport;
    _replaceNextReport = false;
    return replace;
  }

  void refresh() => notifyListeners();

  @override
  Future<void> setNewRoutePath(Uri configuration) => onLocation(configuration);

  @override
  Future<bool> popRoute() async {
    if (await navigatorKey.currentState?.maybePop() ?? false) return true;
    return onRootBack();
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    observers: observers,
    pages: [
      MaterialPage<void>(
        key: const ValueKey('raft-app-root'),
        child: home(context),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}

class RaftAppRouteParser extends RouteInformationParser<Uri> {
  const RaftAppRouteParser();
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri;
  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

/// Carries Source's global root replacement through the actual engine route
/// channel. A changed URI alone would otherwise manufacture a history entry.
class RaftAppRouteInformationProvider extends PlatformRouteInformationProvider {
  RaftAppRouteInformationProvider({
    required super.initialRouteInformation,
    required this.consumeReplacement,
  });
  final bool Function() consumeReplacement;
  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) => super.routerReportsNewRouteInformation(
    routeInformation,
    type: consumeReplacement() ? RouteInformationReportingType.neglect : type,
  );
}
