import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'user_error.dart';

/// Runs [action]; a failure is rethrown as a [RaftUserError] carrying the text
/// Web would show for this surface: the server's own `error` text, else
/// [fallback] (the surface's `...Failed` catalog message). With
/// [serverText] false the server text is ignored, for the Web surfaces that
/// show a fixed message (provider connections).
///
/// 401 / 403 pass through untouched so the page-level authority handling
/// (`invalidateDeniedMutation`) still sees the original [RaftApiException].
Future<T> withWebError<T>(
  String fallback,
  Future<T> Function() action, {
  bool serverText = true,
  String? where,
}) async {
  try {
    return await action();
  } on RaftUserError {
    rethrow;
  } on RaftApiException catch (e) {
    if (const [401, 403].contains(e.status)) rethrow;
    throw RaftUserError(
      serverText
          ? userErrorText(e, fallback: fallback, where: where)
          : _log(e, fallback, where),
    );
  } catch (e) {
    throw RaftUserError(
      serverText
          ? userErrorText(e, fallback: fallback, where: where)
          : _log(e, fallback, where),
    );
  }
}

String _log(Object e, String fallback, String? where) {
  logUserError(e, where: where);
  return fallback;
}
