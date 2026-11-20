import 'package:flutter/foundation.dart';

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
  Future<void>? _inFlight;

  bool get allowed =>
      workspace.client.user != null &&
      workspace.server != null &&
      workspace.can('manageIntegrations');
  AppPermissionUpdateSummary get summary =>
      allowed && _authority == pageIdentity(workspace)
      ? _summary
      : (count: 0, needsAdminReview: false);

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
    super.dispose();
  }
}
