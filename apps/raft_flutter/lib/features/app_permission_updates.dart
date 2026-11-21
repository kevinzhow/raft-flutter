import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

typedef AppPermissionUpdateSummary = ({int count, bool needsAdminReview});

final _stores = Expando<AppPermissionUpdates>();

class AppPermissionUpdates extends ChangeNotifier {
  AppPermissionUpdates(this.workspace);

  static AppPermissionUpdates of(WorkspaceController workspace) {
    return _stores[workspace] ??= _attach(workspace);
  }

  static AppPermissionUpdates _attach(WorkspaceController workspace) {
    final store = AppPermissionUpdates(workspace);
    workspace.services.disposeWithSession(store.dispose);
    return store;
  }

  final WorkspaceController workspace;
  String? _authority;
  AppPermissionUpdateSummary _summary = (count: 0, needsAdminReview: false);
  int _ticket = 0;
  bool _disposed = false, _again = false;
  bool _refreshOwed = false;
  int _consumers = 0;
  Future<void>? _inFlight;
  StreamSubscription<RaftEvent>? _events;
  RaftForegroundPeriodic? _poll;
  AppLifecycleListener? _lifecycle;

  bool get allowed =>
      workspace.client.user != null &&
      workspace.server != null &&
      workspace.can('manageIntegrations');
  AppPermissionUpdateSummary get summary =>
      allowed && _authority == pageIdentity(workspace)
      ? _summary
      : (count: 0, needsAdminReview: false);

  VoidCallback retain() {
    if (_consumers++ == 0) _watch();
    return () {
      if (!_disposed && --_consumers == 0) _unwatch();
    };
  }

  void _watch() {
    workspace.addListener(_authorityChanged);
    _events = workspace.client.events.listen((event) {
      final payload = event.payload;
      if (event.name == 'connected' ||
          (event.name == 'permission-updates:changed' &&
              payload is Map &&
              payload['serverId'] == workspace.client.serverId)) {
        _refreshWhileVisible(changed: true);
      }
    });
    _poll = RaftForegroundPeriodic(
      const Duration(minutes: 5),
      _refreshWhileVisible,
    );
    _lifecycle = AppLifecycleListener(
      onShow: () {
        if (_refreshOwed) _refreshWhileVisible(changed: true);
      },
    );
    _refreshWhileVisible();
  }

  void _unwatch() {
    workspace.removeListener(_authorityChanged);
    unawaited(_events?.cancel());
    _events = null;
    _poll?.dispose();
    _poll = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _authorityChanged() {
    if (!allowed) {
      if (_authority != null) unawaited(refresh());
    } else if (_authority != pageIdentity(workspace)) {
      _refreshWhileVisible();
    }
  }

  void _refreshWhileVisible({bool changed = false}) {
    if (_poll?.isRunning != true) {
      _refreshOwed = allowed;
      return;
    }
    _refreshOwed = false;
    unawaited(refresh(changed: changed));
  }

  Future<void> refresh({bool changed = false}) {
    if (_disposed) return Future.value();
    if (!allowed) {
      final hadReview = _summary.count > 0 || _summary.needsAdminReview;
      _authority = null;
      _summary = (count: 0, needsAdminReview: false);
      _ticket++;
      _inFlight = null;
      if (hadReview) notifyListeners();
      return Future.value();
    }
    final authority = pageIdentity(workspace);
    final running = _inFlight;
    if (authority == _authority && running != null) {
      _again |= changed;
      return running;
    }
    if (authority != _authority) {
      _authority = authority;
      _summary = (count: 0, needsAdminReview: false);
    }
    return _inFlight = _read(authority, ++_ticket);
  }

  Future<void> _read(String authority, int ticket) async {
    bool current() =>
        !_disposed &&
        allowed &&
        ticket == _ticket &&
        authority == pageIdentity(workspace);
    AppPermissionUpdateSummary next = (count: 0, needsAdminReview: false);
    do {
      _again = false;
      try {
        final raw = await Future.sync(
          () => workspace.client.get('/integrations/permission-updates'),
        );
        next = switch (raw) {
          {'count': final int count, 'needsAdminReview': final review}
              when count >= 0 =>
            (count: count, needsAdminReview: review == true),
          {'count': final int count} when count >= 0 => (
            count: count,
            needsAdminReview: false,
          ),
          _ => (count: 0, needsAdminReview: false),
        };
      } catch (_) {
        next = _summary;
      }
      if (!current()) return;
    } while (_again);
    _inFlight = null;
    if (next == _summary) return;
    _summary = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_consumers > 0) _unwatch();
    super.dispose();
  }
}

class AppPermissionUpdatesHost extends StatefulWidget {
  const AppPermissionUpdatesHost({
    super.key,
    required this.workspace,
    required this.child,
  });

  final WorkspaceController workspace;
  final Widget child;

  @override
  State<AppPermissionUpdatesHost> createState() =>
      _AppPermissionUpdatesHostState();
}

class _AppPermissionUpdatesHostState extends State<AppPermissionUpdatesHost> {
  late VoidCallback release;

  @override
  void initState() {
    super.initState();
    release = AppPermissionUpdates.of(widget.workspace).retain();
  }

  @override
  void didUpdateWidget(AppPermissionUpdatesHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      release();
      release = AppPermissionUpdates.of(widget.workspace).retain();
    }
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
