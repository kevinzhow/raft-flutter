import 'package:raft_client/raft_client.dart';

/// Web reads `err.response.data.error` as a machine code in a few places
/// (`agreement_required`, `agreement_changed`, `code`). This is that read: a
/// comparison only, the value is never shown.
bool serverErrorIs(Object? error, String code) =>
    error is RaftApiException && error.message == code;

/// The server `code` receipt (`response.data.code`), or null.
String? serverErrorCode(Object? error) {
  if (error is! RaftApiException) return null;
  final code = error.details['code'];
  return code is String ? code : null;
}
