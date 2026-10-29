import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

// The one error -> message mapper. It mirrors Web's rule for every failed
// request: show the server's own `response.data.error` text when the server
// sent one, otherwise the call site's localized fallback message. Anything
// else a catch block sees (FormatException, DioException, a socket error, a
// StateError, a stack trace, a URL) is logged here and never shown.
//
// The result is an English *source* string (Web en catalog); the display layer
// localizes it with raftText / RaftBanner / the toast. Call sites without a
// BuildContext (controllers) store this string and the view localizes it.

/// Longest server message shown inline; Web wraps, but a megabyte HTML body
/// from a proxy must not.
const _maxServerMessage = 300;

final _secret = RegExp(
  r'(bearer\s+[A-Za-z0-9._~+/-]+=*)|'
  r'((access_token|refresh_token|id_token|token|secret|password|code|key|'
  r'authorization|signature|sig)=[^&\s"]+)',
  caseSensitive: false,
);
final _url = RegExp(r'https?://[^\s"]+', caseSensitive: false);

/// Strips credentials and query strings from [text] for logs.
String redactErrorText(String text) =>
    text.replaceAll(_secret, '[redacted]').replaceAllMapped(_url, (m) {
      final raw = m[0]!;
      final cut = raw.indexOf('?');
      return cut < 0 ? raw : '${raw.substring(0, cut)}?[redacted]';
    });

/// Whether [message] may be shown to a user as the server's words: a single
/// readable sentence, not markup, a dump or a URL carrying a query.
bool isDisplayableServerMessage(String message) {
  final text = message.trim();
  if (text.isEmpty || text.length > _maxServerMessage) return false;
  if (text.contains('\n') && text.split('\n').length > 3) return false;
  if (text.contains('<') && text.contains('>')) return false;
  if (RegExp(r'^\s*[{\[]').hasMatch(text)) return false;
  if (RegExp(
    r'(Exception|Error)\b.*:|\bat .*\.dart|#\d+\s',
  ).hasMatch(text.split('\n').first)) {
    return false;
  }
  if (_secret.hasMatch(text)) return false;
  if (RegExp(r'https?://\S*\?', caseSensitive: false).hasMatch(text)) {
    return false;
  }
  return true;
}

/// English source text to show for [error].
///
/// [fallback] is the call site's Web fallback message (its en catalog string);
/// it is shown whenever the error carries no displayable server text.
/// [codeText] maps a server `code` (`details['code']`) to catalog copy, and
/// [statusText] an HTTP status to catalog copy; use them only where Web has
/// the same per-surface mapping (invite 404/429, public server 404, ...).
/// [where] names the surface in the diagnostic log.
String userErrorText(
  Object? error, {
  String? fallback,
  Map<String, String> codeText = const {},
  Map<int, String> statusText = const {},
  String? where,
}) {
  final shown = fallback ?? raftGenericErrorText;
  if (error == null) return shown;
  if (error is RaftUserError && isDisplayableServerMessage(error.message)) {
    return error.message.trim();
  }
  if (error is RaftApiException) {
    final code = error.details['code'];
    final byCode = code is String ? codeText[code] : null;
    if (byCode != null) return byCode;
    final byStatus = statusText[error.status];
    if (byStatus != null) return byStatus;
    final message = error.message.trim();
    // `structured` = the body was the Raft server's JSON error object. Client
    // generated sentences ("Cannot connect to the Raft server.") are shown
    // only where the Web catalog carries them.
    if ((error.structured || raftChinese.containsKey(message)) &&
        isDisplayableServerMessage(message)) {
      return message;
    }
  }
  logUserError(error, where: where);
  return shown;
}

/// Writes the detail the user does not see. Never prints a token or a URL query.
void logUserError(Object? error, {StackTrace? stack, String? where}) {
  final buffer = StringBuffer('[error]');
  if (where != null) buffer.write(' $where');
  buffer.write(' ${error.runtimeType}');
  if (error is RaftApiException && error.status != null) {
    buffer.write(' status=${error.status}');
  }
  if (error != null) buffer.write(': ${redactErrorText('$error')}');
  debugPrint(buffer.toString());
  if (stack != null) debugPrint(redactErrorText('$stack'));
}

/// The formatter [RaftErrorScope] installs for raft_ui dialogs.
String raftAppErrorFormatter(Object error, {String? fallback}) =>
    userErrorText(error, fallback: fallback);
