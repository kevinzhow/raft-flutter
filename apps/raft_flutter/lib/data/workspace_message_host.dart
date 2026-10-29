import 'workspace_messages.dart';

export 'conversation_window.dart' show MessageContextLoadError;
export 'thread_search.dart' show WorkspaceThreadIdentity;

/// Compatibility entry for existing history consumers. The resolved domain
/// owns the message operations; the host is never retained as a controller.
abstract interface class WorkspaceMessageHost {
  WorkspaceMessages get messageDomain;
}
