import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart' show RaftLinkScope;

import '../data/local_error_diagnostics.dart';
import '../features/custom_protocol_link.dart';

import 'app_update.dart';
import 'local_network_access.dart';

/// Stable application services. Account and server state have their own owners.
@immutable
class AppServices {
  const AppServices.withUpdates(
    AppUpdateService update, {
    this.localNetwork = const LocalNetworkAccess(),
  }) : appUpdate = update;

  /// Explicit opt-out for isolated component tests and previews.
  const AppServices.updatesDisabledForTestOrPreview({
    this.localNetwork = const LocalNetworkAccess(),
  }) : appUpdate = null;

  final AppUpdateService? appUpdate;
  final LocalNetworkAccess localNetwork;
}

/// Place above Navigator so routes, dialogs and overlays share the same values.
/// Service state is observed by its consumers, not by this inherited widget.
class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });
  final AppServices services;

  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServicesScope>()?.services;

  /// Reads stable services in initState and callbacks without subscribing.
  static AppServices? maybeReadOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppServicesScope>()?.services;

  static AppServices of(BuildContext context) {
    final services = maybeOf(context);
    if (services == null) {
      throw FlutterError(
        'AppServicesScope is missing. Install it above Navigator; '
        'tests and previews must explicitly declare disabled updates.',
      );
    }
    return services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      !identical(services.appUpdate, oldWidget.services.appUpdate) ||
      !identical(services.localNetwork, oldWidget.services.localNetwork);
}

/// The root may own the update service; borrowed roots and pages never release it.
class AppServicesHost extends StatefulWidget {
  const AppServicesHost({
    super.key,
    required this.services,
    this.ownsAppUpdate = false,
    required this.child,
  });
  final AppServices services;
  final bool ownsAppUpdate;
  final Widget child;

  @override
  State<AppServicesHost> createState() => _AppServicesHostState();
}

class _AppServicesHostState extends State<AppServicesHost>
    with WidgetsBindingObserver {
  final _retired = <AppUpdateService>{};

  @override
  void initState() {
    super.initState();
    LocalErrorDiagnostics.shared
      ..platform = defaultTargetPlatform.name
      ..lifecycle(WidgetsBinding.instance.lifecycleState?.name ?? 'resumed');
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      LocalErrorDiagnostics.shared.lifecycle(state.name);

  @override
  void didUpdateWidget(AppServicesHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.services.appUpdate;
    if (oldWidget.ownsAppUpdate &&
        previous != null &&
        !identical(previous, widget.services.appUpdate)) {
      _retired.add(previous);
      // Descendant consumers release their old listeners during this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _releaseRetired());
    }
    _retired.remove(widget.services.appUpdate);
  }

  void _releaseRetired({bool keepCurrent = true}) {
    if (keepCurrent && mounted) _retired.remove(widget.services.appUpdate);
    final retired = _retired.toList();
    _retired.clear();
    for (final service in retired) {
      service.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => AppServicesScope(
    services: widget.services,
    // Every markdown host without a link handler of its own opens links the
    // way a message does (Web `MarkdownLink`).
    child: RaftLinkScope(open: openMessageLink, child: widget.child),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.ownsAppUpdate && widget.services.appUpdate != null) {
      _retired.add(widget.services.appUpdate!);
    }
    _releaseRetired(keepCurrent: false);
    super.dispose();
  }
}
