import 'workspace_controller.dart';

/// A failed external message landing belongs to the entry and authority
/// which produced it. No target information is exposed by the failure.
class MessageLinkLanding {
  MessageLinkLanding._(WorkspaceController workspace, this.onBack)
    : authority = workspace.navigationAuthority,
      revision = workspace.navigationRevision;

  static final _failures = Expando<MessageLinkLanding>();
  final String authority;
  final int revision;
  final void Function() onBack;

  static MessageLinkLanding? failureOf(WorkspaceController workspace) {
    final failure = _failures[workspace];
    return failure != null &&
            failure.authority == workspace.navigationAuthority &&
            failure.revision == workspace.navigationRevision
        ? failure
        : null;
  }

  static void showFailure(
    WorkspaceController workspace, {
    required void Function() onBack,
  }) {
    _failures[workspace] = MessageLinkLanding._(workspace, onBack);
    workspace.notifyListeners();
  }

  static void clear(WorkspaceController workspace) {
    if (_failures[workspace] == null) return;
    _failures[workspace] = null;
    workspace.notifyListeners();
  }
}
