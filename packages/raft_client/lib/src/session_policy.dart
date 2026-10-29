import 'client.dart' show RaftApiException;

/// What a failed credential check means for the stored session.
enum SessionVerdict {
  /// The server definitively said the credentials are invalid or the account
  /// is gone. The only verdict that signs out and deletes stored credentials.
  endSession,

  /// Anything else: network failure, timeout, 5xx, 429, a proxy's 4xx, an
  /// unexpected body, a 403. The session and its stored credentials stay;
  /// the caller shows a non-destructive error and retries with backoff.
  keepSession,
}

/// Why a session ended. Only these reasons clear stored credentials.
enum SessionEndReason {
  /// The user chose to log out (the only reason that revokes server-side).
  userRequested('user_requested'),

  /// `POST /auth/refresh` answered 401 with the server's JSON error: the
  /// refresh token is invalid, expired, revoked or its family is gone.
  refreshRejected('refresh_rejected'),

  /// `GET /auth/me` answered 401 with the server's JSON error after a fresh
  /// access token was issued: the account is retired or its session revoked.
  accountRejected('account_rejected'),

  /// The stored record was cleared by another owner (explicit logout in a
  /// handoff) while this client held the session.
  storeCleared('store_cleared'),

  /// The stored record now belongs to a different account.
  principalChanged('principal_changed');

  const SessionEndReason(this.code);
  final String code;
}

/// Verdict for a failed `POST /auth/refresh`, or for a `GET /auth/me` that
/// still failed after a successful refresh.
///
/// The server (packages/server routes/auth.ts) answers an invalid, expired,
/// revoked or reused refresh token with `401 {"error":"Invalid or expired
/// refresh token"}` and a revoked or retired account's access token with
/// `401 {"error":"Invalid or expired token","code":"auth_required"}`. It never
/// answers 403 on these routes; a 403 here comes from a proxy, WAF or captive
/// portal and says nothing about the credentials. A 401 without the server's
/// JSON error body (an HTML page, an empty body) is likewise not the server
/// speaking.
SessionVerdict credentialVerdict(Object error) {
  if (error is RaftApiException && error.status == 401 && error.structured) {
    return SessionVerdict.endSession;
  }
  return SessionVerdict.keepSession;
}

/// The stored session could not be turned into a usable signed-in state at
/// startup although credentials may exist. The app shows a recovery state with
/// retry, never the login form, and keeps the stored credentials.
enum SessionRestoreFailureKind {
  /// Secure storage threw (Keystore/Keychain unavailable, locked, corrupt).
  storage,

  /// The server could not be reached, timed out, or answered 5xx/429.
  network,

  /// Android withholds local network access from the app, so a saved session
  /// for a self-hosted server on a private address cannot connect at all (the
  /// system lets those connections time out). The person can grant it.
  localNetwork,

  /// The server or something in front of it answered something that is not a
  /// definitive credential rejection (403, 404, a captive portal body).
  unexpected,
}

class SessionRestoreException implements Exception {
  const SessionRestoreException(this.kind, {this.status, this.cause});
  final SessionRestoreFailureKind kind;
  final int? status;
  final Object? cause;
  @override
  String toString() => switch (kind) {
    SessionRestoreFailureKind.storage =>
      'Secure storage is not available right now.',
    SessionRestoreFailureKind.network =>
      'Cannot reach the Raft server right now.',
    SessionRestoreFailureKind.localNetwork =>
      'Local network access is not allowed for Raft.',
    SessionRestoreFailureKind.unexpected =>
      'The Raft server could not confirm the session right now.',
  };
}

/// One structured diagnostic entry. Never carries a token, a password, an
/// email address or a response body.
class SessionAuditEvent {
  SessionAuditEvent(
    this.kind,
    this.reason, {
    this.status,
    this.endpoint,
    this.detail,
    DateTime? at,
  }) : at = at ?? DateTime.now().toUtc();

  /// `session_end`, `session_kept`, `restore_failed`, `socket_auth`,
  /// `recovered`, `store_error`.
  final String kind;
  final String reason;
  final int? status;
  final String? endpoint;
  final String? detail;
  final DateTime at;

  Map<String, Object?> toJson() => {
    't': at.toIso8601String(),
    'k': kind,
    'r': reason,
    if (status != null) 's': status,
    if (endpoint != null) 'e': endpoint,
    if (detail != null) 'd': detail,
  };

  factory SessionAuditEvent.fromJson(Map<String, dynamic> json) =>
      SessionAuditEvent(
        json['k'] as String,
        json['r'] as String,
        status: json['s'] as int?,
        endpoint: json['e'] as String?,
        detail: json['d'] as String?,
        at: DateTime.tryParse(json['t'] as String? ?? ''),
      );

  @override
  String toString() =>
      '${at.toIso8601String()} $kind reason=$reason'
      '${status == null ? '' : ' status=$status'}'
      '${endpoint == null ? '' : ' endpoint=$endpoint'}'
      '${detail == null ? '' : ' detail=$detail'}';
}

/// Receives [SessionAuditEvent]s. Implementations must not throw.
abstract interface class SessionAuditSink {
  void record(SessionAuditEvent event);
}

/// Strips anything that could be a credential from free-form detail text.
String sanitizeAuditDetail(String? raw) {
  if (raw == null) return '';
  final cleaned = raw
      .replaceAll(RegExp(r'[A-Za-z0-9_\-\.=+/]{24,}'), '<redacted>')
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '<email>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
}
