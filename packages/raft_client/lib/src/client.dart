import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'rate_limit_governor.dart';
import 'request_meter.dart';
import 'server_rate_limits.dart';
import 'proxy/transport_stub.dart'
    if (dart.library.io) 'proxy/transport_io.dart';
import 'session_policy.dart';

part 'channel_read_dispatch.dart';

abstract interface class SessionStore {
  Future<Session?> read(String origin);
  Future<void> write(String origin, Session? session);
}

class MemorySessionStore implements SessionStore {
  final Map<String, Session> _sessions = {};
  @override
  Future<Session?> read(String origin) async => _sessions[origin];
  @override
  Future<void> write(String origin, Session? session) async {
    if (session == null) {
      _sessions.remove(origin);
    } else {
      _sessions[origin] = session;
    }
  }
}

class RaftApiException implements Exception {
  const RaftApiException(this.message, {this.status, this.retryAfter})
    : details = const {},
      structured = false,
      staleScope = false;

  /// The request was fenced because the account or workspace it was started
  /// under changed (a server switch, a deletion, a sign-out) before it
  /// finished. It did not fail: its result is simply no longer wanted, so no
  /// surface should present it as an error.
  const RaftApiException.staleScope([
    this.message = 'The account or workspace changed.',
  ]) : status = null,
       retryAfter = null,
       details = const {},
       structured = false,
       staleScope = true;
  RaftApiException.response(
    this.message, {
    this.status,
    Map? body,
    this.retryAfter,
  }) : details = _errorDetails(body),
       structured = body != null && body['error'] is String,
       staleScope = false;

  final bool staleScope;

  /// The server (or this client's own pacing) answered 429: the request was
  /// not processed and may be repeated after [retryAfter].
  bool get rateLimited => status == 429;

  /// How long the server asked to wait (`Retry-After` / `RateLimit-Reset`).
  final Duration? retryAfter;

  /// The response carried the Raft server's JSON error object. A status with
  /// no such body (an HTML page, an empty reply) came from a proxy, a WAF or a
  /// captive portal, not from the server's auth layer.
  final bool structured;

  /// Allow-listed structured receipts; never part of the printable error.
  final Map<String, dynamic> details;
  final String message;
  final int? status;
  @override
  String toString() => message;
}

Map<String, dynamic> _errorDetails(Map? body) {
  const keys = {
    'code',
    'retryable',
    'conversionJob',
    'conversionCommand',
    'uploadScope',
    'uploadCount',
    'archivedChannelId',
    'archivedChannelName',
    'archivedChannelType',
    'canUnarchiveArchivedChannel',
    // agreement_required / agreement_changed: the community agreement the
    // caller must accept before joining (a public guest join, a community
    // server or an invite); public text, not a credential.
    'agreement',
    // Form-validation issues (`[{code, pointer}]`); the pointer names the
    // field that failed (runtime form v2 create / edit).
    'issues',
    // Agent migration start refusals: which computer lacks which runtime
    // (COMPUTER_CAPABILITY_INSUFFICIENT) or needs a Raft Computer update
    // (MIGRATION_RESUMABLE_CAPABILITY_REQUIRED); the view validates the shape.
    'details',
  };
  dynamic freeze(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable({
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: freeze(entry.value),
      });
    }
    if (value is List) return List<dynamic>.unmodifiable(value.map(freeze));
    return value;
  }

  Map<String, dynamic> receipt(dynamic value, Set<String> receiptKeys) =>
      value is Map
      ? {
          for (final key in receiptKeys)
            if (value.containsKey(key)) key: value[key],
        }
      : {};
  dynamic selected(String key) {
    final value = body![key];
    if (key == 'uploadScope')
      return receipt(value, {
        'sessionIds',
        'transferIntentIds',
        'reservationIds',
      });
    if (key == 'issues') {
      return [
        if (value is List)
          for (final issue in value)
            if (issue is Map) receipt(issue, {'code', 'pointer'}),
      ];
    }
    if (key == 'agreement') {
      return receipt(value, {'id', 'title', 'bodyMarkdown', 'version'});
    }
    if (key == 'conversionCommand')
      return receipt(value, {
        'id',
        'kind',
        'status',
        'jobId',
        'error',
        'createdAt',
      });
    if (key == 'conversionJob') {
      final job = receipt(value, {
        'id',
        'status',
        'phase',
        'canCancel',
        'progress',
        'error',
      });
      if (job['progress'] is Map)
        job['progress'] = receipt(job['progress'], {
          'rollbackState',
          'retryState',
          'errorCode',
          'failedAt',
          'relockedAt',
          'canonicalCopyStarted',
          'audienceCutoverAt',
          'uploadCount',
          'uploadScope',
        });
      final progress = job['progress'];
      if (progress is Map && progress['uploadScope'] is Map)
        progress['uploadScope'] = receipt(progress['uploadScope'], {
          'sessionIds',
          'transferIntentIds',
          'reservationIds',
        });
      return job;
    }
    return value;
  }

  return Map<String, dynamic>.unmodifiable({
    for (final key in keys)
      if (body?.containsKey(key) == true) key: freeze(selected(key)),
  });
}

class UploadCancellation {
  final CancelToken _token = CancelToken();
  bool get cancelled => _token.isCancelled;
  void cancel() => _token.cancel('User cancelled upload');
}

class RaftEvent {
  const RaftEvent(this.name, this.payload);
  final String name;
  final dynamic payload;
}

/// Human API transport; refresh rotation is shared by HTTP and socket recovery.
class RaftClient {
  RaftClient({
    required String origin,
    required this.sessionStore,
    this.clientKind = 'web',
    Dio? transport,
    this.auditSink,
    this.allowSessionEnd = true,
    this.recoveryBackoff = defaultRecoveryBackoff,
    RateLimitGovernor? governor,
    Future<void> Function(Duration)? sleep,
  }) : governor = governor ?? RateLimitGovernor(),
       _sleep = sleep ?? ((d) => Future<void>.delayed(d)),
       origin = origin.replaceFirst(RegExp(r'/$'), ''),
       http =
           transport ??
           createProxiedDio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    http.options.baseUrl = '${this.origin}/api';
    // Every Dio interceptor costs the request an event-loop turn, so the
    // counter is attached only when a tool or test asked for it before the
    // client was built.
    if (RequestMeter.instance.enabled) {
      http.interceptors.add(RequestMeter.instance.interceptor());
    }
  }

  /// Waits between background attempts to confirm a session the server could
  /// not be asked about (network down, 5xx, a proxy's 4xx). The last entry
  /// repeats. An empty list disables automatic retries.
  static const defaultRecoveryBackoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  static const _refreshCooldown = Duration(seconds: 3);

  /// 429 answers a request waits out (honouring `Retry-After`) before the
  /// caller sees the error.
  static const rateLimitRetries = 2;

  /// Reads served from RisingWave that Web retries once when the server
  /// answers 503 `rw_overloaded` (Web `getWithRwOverloadRetry`).
  static const rwOverloadRetriedPaths = {
    '/channels/unread',
    '/channels/inbox',
    '/servers/unread-summary',
  };
  static const rwOverloadDefaultRetryAfter = Duration(seconds: 2);
  static const rwOverloadMaxRetryAfter = Duration(seconds: 10);
  final Map<String, ({Future<dynamic> flight, DateTime at})> _singleFlight = {};

  /// A read already in flight is joined only while it is this young: one that
  /// has stalled longer is not shared with a fresh attempt (a retry must not
  /// wait on the stall it is retrying).
  Duration singleFlightWindow = const Duration(seconds: 4);

  /// Admission control for the server's rate-limited routes.
  final RateLimitGovernor governor;
  final Future<void> Function(Duration) _sleep;

  /// GETs answered from an identical request already in flight.
  int singleFlightJoins = 0;
  int rateLimitRetriesSent = 0;
  static const _proactiveRefreshSpacing = Duration(seconds: 60);

  final String origin;
  final String clientKind;
  final SessionStore sessionStore;

  /// Receives a structured, token-free record of every sign-out and every
  /// credential failure that kept the session.
  final SessionAuditSink? auditSink;

  /// A background guest must never sign the account out: when the server
  /// rejects its credentials it only stops; the foreground meets the same
  /// rejection on its own and ends the session with the user in front of it.
  final bool allowSessionEnd;
  final List<Duration> recoveryBackoff;
  final Dio http;
  Session? _session;
  RaftRecord? user;
  String? serverId;
  int _generation = 0;
  int _authenticationGeneration = 0;
  int get generation => _generation;
  bool get signedIn => _session != null;
  io.Socket? _socket;
  Future<void>? _refreshing;
  Timer? _authRetry;
  Future<void> _persistence = Future<void>.value();
  // Session writes queued or running. [dispose] waits for them only while this
  // is non-zero: awaiting an already completed [_persistence] adds nothing in
  // production, but in a widget test (client created in the FakeAsync zone) the
  // continuation is a microtask of that zone and a tear-down that awaits
  // `dispose()` would never resume.
  int _persisting = 0;
  Future<void>? _credentialsReady;
  Future<void>? _disposing;
  bool _closed = false;
  final _events = StreamController<RaftEvent>.broadcast();
  Stream<RaftEvent> get events => _events.stream;
  bool get connected => _socket?.connected ?? false;
  bool restoredOffline = false;

  /// The session is kept but the server has not confirmed it recently
  /// (transient refresh/account-check failure). Cleared when it does.
  bool sessionDegraded = false;

  /// Why the last session ended, or null if none ended since [restore].
  SessionEndReason? lastEndReason;
  Timer? _recoveryTimer;
  Duration? _recoveryHint;
  int _recoveryAttempt = 0;
  int _socketRetries = 0;
  DateTime? _lastRotatedAt;
  ({DateTime at, RaftApiException error})? _refreshFailure;

  void _audit(
    String kind,
    String reason, {
    int? status,
    String? endpoint,
    String? detail,
  }) {
    try {
      auditSink?.record(
        SessionAuditEvent(
          kind,
          reason,
          status: status,
          endpoint: endpoint,
          detail: detail == null ? null : sanitizeAuditDetail(detail),
        ),
      );
    } catch (_) {
      // Diagnostics must never affect authentication.
    }
  }

  void _emit(RaftEvent event) {
    if (!_closed) _events.add(event);
  }

  Future<void> _persist(Session? expected) {
    _persisting++;
    final pending = _persistence.catchError((Object _) {}).then((_) async {
      try {
        if (_credentialsReady != null) await _credentialsReady;
        if (!_closed && _session == expected) {
          await sessionStore.write(origin, expected);
        }
      } finally {
        _persisting--;
      }
    });
    _persistence = pending;
    return pending;
  }

  /// Settles when the stored session restored by [restore] has been checked
  /// against `/auth/me` (accepted, offline, or ended).
  Future<void> get sessionValidated => _sessionValidated;
  Future<void> _sessionValidated = Future<void>.value();

  /// Restores the stored session. With [cachedFirst] and a session that
  /// carries the last accepted account record, [user] is that record at once
  /// so the app can paint its local cache without a network round trip; the
  /// account is then revalidated in the background. A changed record emits
  /// `account:updated` (the app fences a different principal), a rejected
  /// session ends with `session:ended`, and an unreachable server leaves the
  /// session in [restoredOffline].
  ///
  /// [credentialsReady] settles when a background guest holding the session
  /// has stopped (it never throws and is bounded by the caller). Display,
  /// requests and the socket do not wait for it. Credential rotation and
  /// stored-session writes do, and then continue from the latest stored record.
  /// [onLocalSession] reports whether an accepted local account is available,
  /// before waiting for ownership or the network.
  Future<bool> restore({
    bool cachedFirst = false,
    Future<void>? credentialsReady,
    void Function(bool cached)? onLocalSession,
  }) async {
    final authentication = ++_authenticationGeneration;
    _generation++;
    lastEndReason = null;
    final Session? stored;
    try {
      stored = await sessionStore.read(origin);
    } catch (e) {
      // Not "no stored credentials": the Keystore/Keychain failed or the
      // record is unreadable. Nothing is deleted; the caller retries.
      _audit(
        'restore_failed',
        'storage_read',
        detail: e.runtimeType.toString(),
      );
      throw SessionRestoreException(
        SessionRestoreFailureKind.storage,
        cause: e,
      );
    }
    if (authentication != _authenticationGeneration || _closed) return false;
    _session = stored;
    _credentialsReady = credentialsReady == null
        ? null
        : _reloadOwnedCredentials(credentialsReady, authentication, stored);
    final cached = cachedFirst && _session?.cachedUser != null;
    onLocalSession?.call(cached);
    if (cached) {
      user = RaftRecord(Map<String, dynamic>.from(_session!.cachedUser!));
      _sessionValidated = _validateRestoredSession(authentication);
      return true;
    }
    if (authentication != _authenticationGeneration ||
        _closed ||
        _session == null) {
      return false;
    }
    try {
      user = RaftRecord(Map<String, dynamic>.from(await get('/auth/me')));
      // A guest handoff may have replaced or removed the stored session.
      final s = _session;
      if (s == null || _closed || authentication != _authenticationGeneration) {
        return false;
      }
      _session = Session(
        accessToken: s.accessToken,
        refreshToken: s.refreshToken,
        installationId: s.installationId,
        refreshAttemptId: s.refreshAttemptId,
        cachedUser: user!.json,
      );
      // The credentials are accepted; a failed write only loses the cached
      // account record, never the session.
      final saved = _persist(_session).catchError((Object e) {
        _audit('store_error', 'write_failed', detail: e.runtimeType.toString());
      });
      if (_credentialsReady == null) {
        await saved;
      } else {
        // The write waits for the guest to stop; restore must not.
        unawaited(saved);
      }
    } catch (e) {
      final s = _session;
      if (s == null || _closed || authentication != _authenticationGeneration) {
        // Ended (a definitive rejection already signed out) or superseded.
        return false;
      }
      if (e is RaftApiException &&
          credentialVerdict(e) == SessionVerdict.endSession) {
        await _endSession(
          SessionEndReason.accountRejected,
          e,
          endpoint: '/auth/me',
        );
        return false;
      }
      final status = e is RaftApiException ? e.status : null;
      _audit(
        'restore_failed',
        'account_check_failed',
        status: status,
        endpoint: '/auth/me',
        detail: e is RaftApiException ? null : e.runtimeType.toString(),
      );
      if (s.cachedUser != null) {
        user = RaftRecord(Map<String, dynamic>.from(s.cachedUser!));
        restoredOffline = true;
        _markDegraded();
        _scheduleRecovery();
        return true;
      }
      throw SessionRestoreException(
        e is RaftApiException &&
                (status == null ||
                    status >= 500 ||
                    status == 408 ||
                    status == 429)
            ? SessionRestoreFailureKind.network
            : SessionRestoreFailureKind.unexpected,
        status: status,
        cause: e,
      );
    }
    return true;
  }

  // A background guest may rotate or reject the stored session while the UI
  // paints its cache and sends requests. Never rotate credentials or write the
  // initial snapshot until the guest has stopped and the latest complete
  // credential record is read.
  Future<void> _reloadOwnedCredentials(
    Future<void> ready,
    int authentication,
    Session? snapshot,
  ) async {
    try {
      await ready;
    } catch (_) {
      // A failed handoff signal must not poison the session: carry on from
      // the stored record, which the fenced guest can no longer change.
    }
    if (_closed || authentication != _authenticationGeneration) return;
    final latest = await sessionStore.read(origin);
    if (_closed || authentication != _authenticationGeneration) return;
    final principal = snapshot?.cachedUser?['id'];
    if (latest == null && snapshot != null ||
        principal != null &&
            latest != null &&
            latest.cachedUser != null &&
            latest.cachedUser!['id'] != principal) {
      _session = null;
      user = null;
      serverId = null;
      _authenticationGeneration++;
      _generation++;
      _socket?.dispose();
      _socket = null;
      final reason = latest == null
          ? SessionEndReason.storeCleared
          : SessionEndReason.principalChanged;
      lastEndReason = reason;
      _audit('session_end', reason.code, endpoint: 'handoff');
      // Do not overwrite a different principal's newly stored session.
      _emit(const RaftEvent('session:ended', null));
      return;
    }
    _session = latest;
    _credentialsReady = null;
  }

  Future<void> _validateRestoredSession(int authentication) async {
    await _validateOnce(authentication);
  }

  /// One `/auth/me` check of the held session. True when the question is
  /// settled (accepted, or definitively rejected and signed out); false when
  /// the server could not answer, in which case the session is kept and a
  /// retry is scheduled.
  Future<bool> _validateOnce(int authentication) async {
    bool current() => !_closed && authentication == _authenticationGeneration;
    try {
      if (!current() || _session == null) return true;
      final next = RaftRecord(
        Map<String, dynamic>.from(await _accountRequest('GET', '/auth/me')),
      );
      final s = _session;
      if (!current() || s == null) return true;
      final changed = jsonEncode(next.json) != jsonEncode(user?.json);
      user = next;
      final recovered = restoredOffline || sessionDegraded;
      restoredOffline = false;
      _markHealthy();
      _session = Session(
        accessToken: s.accessToken,
        refreshToken: s.refreshToken,
        installationId: s.installationId,
        refreshAttemptId: s.refreshAttemptId,
        cachedUser: next.json,
      );
      // Validation (and what waits on it) must not wait for a guest to stop:
      // the write is applied once the handoff has settled.
      final saved = _persist(_session).catchError((Object _) {});
      if (_credentialsReady == null) await saved;
      if (changed && current()) {
        _emit(const RaftEvent('account:updated', null));
      }
      if (recovered && current()) {
        _audit('recovered', 'account_confirmed');
        _emit(const RaftEvent('session:recovered', null));
      }
      return true;
    } catch (e) {
      if (!current() || _session == null) return true;
      if (e is RaftApiException &&
          credentialVerdict(e) == SessionVerdict.endSession) {
        // The server said the account or session is gone (a failed refresh
        // already signed out above).
        await _endSession(
          SessionEndReason.accountRejected,
          e,
          endpoint: '/auth/me',
        );
        return true;
      }
      // Offline, 5xx, 429, a proxy's 4xx, a body that is not an account:
      // keep the cached account and its credentials, try again later.
      _audit(
        'session_kept',
        'account_check_failed',
        status: e is RaftApiException ? e.status : null,
        endpoint: '/auth/me',
        detail: e is RaftApiException ? null : e.runtimeType.toString(),
      );
      restoredOffline = true;
      _markDegraded();
      if (e is RaftApiException && e.rateLimited) _recoveryHint = e.retryAfter;
      _scheduleRecovery();
      return false;
    }
  }

  void _markDegraded() {
    if (sessionDegraded) return;
    sessionDegraded = true;
    _emit(const RaftEvent('session:degraded', null));
  }

  void _markHealthy() {
    sessionDegraded = false;
    _recoveryAttempt = 0;
    _refreshFailure = null;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  void _scheduleRecovery() {
    if (_closed ||
        _session == null ||
        recoveryBackoff.isEmpty ||
        _recoveryTimer != null) {
      return;
    }
    var delay =
        recoveryBackoff[math.min(_recoveryAttempt, recoveryBackoff.length - 1)];
    // Many devices that lost the network together must not return together:
    // spread each wait by +-20 %. A server that said how long to wait
    // (Retry-After on a 429) is not asked earlier than that.
    delay = Duration(
      milliseconds:
          (delay.inMilliseconds * (0.8 + 0.4 * governor.random.nextDouble()))
              .round(),
    );
    final hint = _recoveryHint;
    _recoveryHint = null;
    if (hint != null && hint > delay) delay = hint;
    _recoveryAttempt++;
    final authentication = _authenticationGeneration;
    _recoveryTimer = Timer(delay, () {
      _recoveryTimer = null;
      if (_closed || authentication != _authenticationGeneration) return;
      unawaited(_validateOnce(authentication));
    });
  }

  /// Asks the server about a kept-but-unconfirmed session now (the app calls
  /// this on resume and from a manual retry). Settles true when confirmed or
  /// definitively rejected, false when the server still cannot answer.
  Future<bool> retrySession() async {
    if (_closed || _session == null) return true;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _refreshFailure = null;
    return _validateOnce(_authenticationGeneration);
  }

  Future<void> login(String email, String password) async {
    final authGeneration = ++_authenticationGeneration;
    final result = await request(
      'POST',
      '/auth/login',
      data: {'email': email, 'password': password},
      authorized: false,
    );
    if (_closed || authGeneration != _authenticationGeneration) {
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    }
    _session = Session.fromJson(Map<String, dynamic>.from(result));
    user = RaftRecord(Map<String, dynamic>.from(result['user']));
    _generation++;
    await _persist(_session);
  }

  /// Registration requires the caller to collect explicit agreement first.
  Future<void> register(
    String email,
    String password, {
    required bool acceptTerms,
    String legalAcceptanceSource = 'signup',
  }) async {
    if (!acceptTerms)
      throw const RaftApiException(
        'Accept the terms and privacy policy to create an account.',
      );
    final authGeneration = ++_authenticationGeneration;
    final result = await request(
      'POST',
      '/auth/register',
      authorized: false,
      data: {
        'email': email,
        'password': password,
        'acceptTerms': true,
        'termsVersion': '2026-05-12',
        'privacyVersion': '2026-05-12',
        'legalAcceptanceSource': legalAcceptanceSource,
      },
    );
    if (_closed || authGeneration != _authenticationGeneration)
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    _session = Session.fromJson(Map<String, dynamic>.from(result));
    user = RaftRecord(Map<String, dynamic>.from(result['user']));
    _generation++;
    await _persist(_session);
  }

  Future<void> completeMobileOAuth(
    String code,
    String codeVerifier, {
    bool acceptTerms = false,
  }) async {
    final authGeneration = ++_authenticationGeneration;
    final result = await request(
      'POST',
      '/auth/mobile/oauth/complete',
      authorized: false,
      data: {
        'code': code,
        'codeVerifier': codeVerifier,
        if (acceptTerms) 'acceptTerms': true,
        if (acceptTerms) 'termsVersion': '2026-05-12',
        if (acceptTerms) 'privacyVersion': '2026-05-12',
        if (acceptTerms) 'legalAcceptanceSource': 'oauth',
      },
    );
    if (_closed || authGeneration != _authenticationGeneration)
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    _session = Session.fromJson(Map<String, dynamic>.from(result));
    user = RaftRecord(Map<String, dynamic>.from(result['user']));
    _generation++;
    await _persist(_session);
  }

  /// Signs out on the user's behalf and revokes the refresh token on the
  /// server. Involuntary sign-outs go through [_endSession] instead and never
  /// revoke: the server already said the credentials are dead, and revoking
  /// with a stale token would revoke the family a newer owner is using.
  Future<void> logout({
    Future<Session?>? revocationSession,
    SessionEndReason reason = SessionEndReason.userRequested,
  }) {
    lastEndReason = reason;
    _audit('session_end', reason.code);
    return _signOut(revocationSession: revocationSession, revoke: true);
  }

  Future<void> _endSession(
    SessionEndReason reason,
    Object? cause, {
    String? endpoint,
  }) async {
    final status = cause is RaftApiException ? cause.status : null;
    if (!allowSessionEnd) {
      _audit(
        'session_end_suppressed',
        reason.code,
        status: status,
        endpoint: endpoint,
      );
      return;
    }
    lastEndReason = reason;
    _audit('session_end', reason.code, status: status, endpoint: endpoint);
    await _signOut(revoke: false);
  }

  Future<void> _signOut({
    Future<Session?>? revocationSession,
    required bool revoke,
  }) async {
    final old = _session;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _authRetry?.cancel();
    sessionDegraded = false;
    restoredOffline = false;
    _recoveryAttempt = 0;
    _refreshFailure = null;
    _authenticationGeneration++;
    _session = null;
    user = null;
    serverId = null;
    _generation++;
    _socket?.dispose();
    _socket = null;
    Session? revoked = old;
    if (revocationSession == null) {
      if (revoke) {
        await _persist(null);
      } else {
        // The credentials are already dead; a storage failure must not keep
        // the signed-out state from reaching the app.
        await _persist(null).catchError((Object e) {
          _audit(
            'store_error',
            'clear_failed',
            detail: e.runtimeType.toString(),
          );
        });
      }
    } else {
      // Attach both waits immediately: a failed handoff must not leave an
      // unobserved persistence or revocation-record failure.
      revoked = (await Future.wait<Session?>([
        revocationSession,
        _persist(null).then((_) => null),
      ])).first;
    }
    Future<dynamic>? revocation;
    if (revoke && revoked != null) {
      revocation = request(
        'POST',
        '/auth/logout',
        data: {'refreshToken': revoked.refreshToken},
        authorized: false,
      );
    }
    _emit(const RaftEvent('session:ended', null));
    if (revocation != null) {
      try {
        await revocation;
      } catch (_) {
        /* Local logout remains effective offline. */
      }
    }
  }

  void selectServer(String? id) {
    if (serverId == id) return;
    _generation++;
    serverId = id;
    _socket?.dispose();
    _socket = null;
  }

  /// A successful server exit can itself revoke its socket membership before
  /// the HTTP response arrives. Accept that acknowledgement for this exact
  /// server, while retaining the authentication-generation fence.
  Future<dynamic> exitServer(String id, {bool delete = false}) => request(
    delete ? 'DELETE' : 'POST',
    '/servers/$id${delete ? '' : '/leave'}',
    acceptServerExit: true,
  );
  Future<void> reloadUser() async {
    final next = RaftRecord(Map<String, dynamic>.from(await get('/auth/me')));
    final s = _session;
    if (s == null) return;
    user = next;
    _session = Session(
      accessToken: s.accessToken,
      refreshToken: s.refreshToken,
      installationId: s.installationId,
      refreshAttemptId: s.refreshAttemptId,
      cachedUser: next.json,
    );
    await _persist(_session);
    _emit(const RaftEvent('account:updated', null));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      request('GET', path, query: query);

  /// Read a picker directory without changing the active workspace. Authentication
  /// changes still fence the response and refresh/retry preserves this server.
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) => _request(
    'GET',
    path,
    query: query,
    workspaceScoped: false,
    headers: {'X-Server-Id': server},
  );
  Future<dynamic> post(String path, {dynamic data}) =>
      request('POST', path, data: data);
  Future<dynamic> patch(String path, {dynamic data}) =>
      request('PATCH', path, data: data);
  Future<dynamic> delete(String path, {dynamic data}) =>
      request('DELETE', path, data: data);
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) => _request(
    method,
    path,
    data: data,
    query: query,
    authorized: authorized,
    retried: retried,
    cancellation: cancellation,
    onSendProgress: onSendProgress,
    headers: headers,
    acceptServerExit: acceptServerExit,
    receiveTimeout: receiveTimeout,
  );

  /// An account-level read: fenced by the authentication generation only,
  /// so a concurrent server switch does not retire it.
  Future<dynamic> _accountRequest(String method, String path) =>
      _request(method, path, workspaceScoped: false);

  static const _priorityKey = #raftRequestPriority;

  /// The priority requests started in this zone carry (foreground unless
  /// inside [runBackground]).
  static RequestPriority get currentPriority =>
      Zone.current[_priorityKey] as RequestPriority? ??
      RequestPriority.foreground;

  static const _sharedKey = #raftSharedReads;

  /// Runs [body] so that identical GETs started inside it while one is in
  /// flight (same path, query, server, principal and credentials, started
  /// less than [singleFlightWindow] ago) share one HTTP request. For reads
  /// that do not depend on anything the caller fences on; a write sent in
  /// between ends the sharing (read-after-write).
  static T runShared<T>(T Function() body) =>
      runZoned(body, zoneValues: {_sharedKey: true});

  /// Runs [body] so that every request it starts is background work:
  /// prefetch, warming, periodic polls and post-reconnect refreshes. They
  /// yield to the user's own requests when a rate limit is near and are never
  /// retried after a 429. Subclasses and fakes of the client need no change.
  static T runBackground<T>(T Function() body) =>
      runZoned(body, zoneValues: {_priorityKey: RequestPriority.background});

  /// Admission, single-flight and the 429 wait around [_send].
  ///
  /// * Identical GETs in flight at the same moment (same path, query, server
  ///   and credentials) share one HTTP request; every extra caller receives
  ///   its own copy of the decoded body.
  /// * The server's rate-limited routes are paced by [governor]; a background
  ///   request that would have to wait is refused at once.
  /// * A 429 is answered by waiting `Retry-After` (plus jitter) and asking
  ///   again, at most [rateLimitRetries] times and never longer than the
  ///   governor's `maxWait`; after that the caller sees a
  ///   [RaftApiException] with `rateLimited` and `retryAfter`. A 429 never
  ///   ends a session.
  Future<dynamic> _request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
    bool workspaceScoped = true,
    RequestPriority? priority,
  }) {
    final level = priority ?? RaftClient.currentPriority;
    Future<dynamic> send() => _sendPaced(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
      workspaceScoped: workspaceScoped,
      priority: level,
    );
    // Identical reads share one request only where the caller says it is
    // safe ([runShared]): the client cannot see the caller's authority (role,
    // channel membership, ...), and a read started after such a change must
    // not be answered by one started before it.
    final shared =
        method == 'GET' &&
        cancellation == null &&
        onSendProgress == null &&
        !retried &&
        Zone.current[_sharedKey] == true;
    if (!shared) {
      if (method == 'GET') return send();
      // Read-after-write: a read started once a write has been sent must not
      // join a read that began before it (it would return the old state).
      _singleFlight.clear();
      return send().whenComplete(_singleFlight.clear);
    }
    final query_ = query == null || query.isEmpty
        ? ''
        : (query.entries.map((e) => '${e.key}=${e.value}').toList()..sort())
              .join('&');
    final key = [
      workspaceScoped ? _generation : 0,
      _authenticationGeneration,
      user?.id,
      authorized,
      workspaceScoped ? serverId : headers?['X-Server-Id'],
      path,
      query_,
    ].join('|');
    final pending = _singleFlight[key];
    if (pending != null &&
        governor.now().difference(pending.at) < singleFlightWindow) {
      singleFlightJoins++;
      return pending.flight.then(_cloneJson);
    }
    late final Future<dynamic> flight;
    flight = send();
    _singleFlight[key] = (flight: flight, at: governor.now());
    // Whoever started it observes the error; joiners get their own copy of it
    // through [pending.then] above, so the entry must never go unhandled.
    flight
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_singleFlight[key]?.flight, flight)) {
            _singleFlight.remove(key);
          }
        });
    return flight;
  }

  Future<dynamic> _sendPaced(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
    bool workspaceScoped = true,
    RequestPriority priority = RequestPriority.foreground,
  }) async {
    final limits = ServerRateLimits.forRequest(method, path);
    final authentication = _authenticationGeneration;
    final workspace = workspaceScoped ? _generation : 0;
    // Credential and session endpoints are answered at once (the person typing
    // decides to retry; the session check has its own recovery timer, which
    // honours Retry-After); nothing else waits behind a closed account bucket.
    final waits = authorized && !path.startsWith('/auth/');
    var overloadRetried = false;
    for (var attempt = 0; ; attempt++) {
      try {
        if (limits.isNotEmpty) {
          try {
            await governor.acquire(
              limits,
              waits ? priority : RequestPriority.background,
            );
          } on RateLimitedException catch (limited) {
            throw RaftApiException(
              limited.toString(),
              status: 429,
              retryAfter: limited.retryAfter,
            );
          }
          if (authorized &&
              (_closed ||
                  authentication != _authenticationGeneration ||
                  workspace != (workspaceScoped ? _generation : 0))) {
            throw const RaftApiException.staleScope();
          }
        }
        return await _send(
          method,
          path,
          data: data is FormData ? data.clone() : data,
          query: query,
          authorized: authorized,
          retried: retried,
          cancellation: cancellation,
          onSendProgress: onSendProgress,
          headers: headers,
          acceptServerExit: acceptServerExit,
          receiveTimeout: receiveTimeout,
          workspaceScoped: workspaceScoped,
        );
      } on RaftApiException catch (e) {
        final wait = e.retryAfter;
        if (!overloadRetried &&
            e.status == 503 &&
            wait != null &&
            method == 'GET' &&
            rwOverloadRetriedPaths.contains(path) &&
            cancellation?.cancelled != true) {
          // Web getWithRwOverloadRetry: these reads come from RisingWave. A
          // first load after a saturated pool has nothing to keep, so retry
          // once after the server's hint; more would add load while it is behind.
          overloadRetried = true;
          await _sleep(wait);
          if (_closed ||
              authentication != _authenticationGeneration ||
              workspace != (workspaceScoped ? _generation : 0)) {
            throw const RaftApiException.staleScope();
          }
          continue;
        }
        if (e.status != 429 ||
            !waits ||
            wait == null ||
            attempt >= rateLimitRetries ||
            priority == RequestPriority.background ||
            wait > governor.maxWait ||
            cancellation?.cancelled == true) {
          rethrow;
        }
        rateLimitRetriesSent++;
        await _sleep(
          backoffDelay(attempt, hint: wait, random: governor.random),
        );
        if (_closed ||
            authentication != _authenticationGeneration ||
            workspace != (workspaceScoped ? _generation : 0)) {
          throw const RaftApiException.staleScope();
        }
      }
    }
  }

  static dynamic _cloneJson(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) '${e.key}': _cloneJson(e.value),
      };
    }
    if (value is List) return [for (final e in value) _cloneJson(e)];
    return value;
  }

  /// One HTTP exchange: the credential fence, the access-token refresh and a
  /// single retry after it. Rate-limit admission, single-flight and the 429
  /// wait live in [_request], around this.
  Future<dynamic> _send(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
    bool workspaceScoped = true,
  }) async {
    final authentication = _authenticationGeneration;
    int generation() => workspaceScoped ? _generation : 0;
    final requestGeneration = generation();
    final exit =
        acceptServerExit &&
        serverId != null &&
        (method == 'DELETE' && path == '/servers/$serverId' ||
            method == 'POST' && path == '/servers/$serverId/leave');
    if (authorized) {
      // Never waits for another engine: the foreground owns the session. A
      // guest handoff only gates credential rotation (see [refresh]).
      if (_closed ||
          authentication != _authenticationGeneration ||
          requestGeneration != generation()) {
        throw const RaftApiException.staleScope();
      }
    }
    final sentAccessToken = authorized ? _session?.accessToken : null;
    final requestHeaders = <String, dynamic>{
      ...?headers,
      if (authorized && _session != null)
        'Authorization': 'Bearer ${_session!.accessToken}',
      if (authorized && workspaceScoped && serverId != null)
        'X-Server-Id': serverId,
    };
    try {
      // Evaluating this call hands a channel read to the adapter before the
      // await yields. Other requests keep Dio's own chain.
      final Response<dynamic> response =
          _channelReadStaysOnThisTurn(
            http,
            method,
            path,
            data: data,
            onSendProgress: onSendProgress,
          )
          ? await _dispatchChannelRead(
              http,
              method: method,
              path: path,
              data: data,
              query: query,
              headers: requestHeaders,
              receiveTimeout: receiveTimeout,
              cancelToken: cancellation?._token,
            )
          : await http.request<dynamic>(
              path,
              data: data,
              queryParameters: query,
              cancelToken: cancellation?._token,
              onSendProgress: onSendProgress,
              options: Options(
                method: method,
                receiveTimeout: receiveTimeout,
                headers: requestHeaders,
              ),
            );
      governor.observe(
        ServerRateLimits.forRequest(method, path),
        response.headers,
      );
      if (authorized &&
          (authentication != _authenticationGeneration ||
              requestGeneration != generation() && !exit))
        throw const RaftApiException.staleScope(
          'The account or workspace changed. Please retry.',
        );
      return response.data;
    } on DioException catch (e) {
      if (authorized &&
          (authentication != _authenticationGeneration ||
              requestGeneration != generation() && !exit)) {
        throw const RaftApiException.staleScope(
          'The account or workspace changed. Please retry.',
        );
      }
      if (e.response?.statusCode == 401 &&
          authorized &&
          !retried &&
          (!path.startsWith('/auth/') || path == '/auth/me') &&
          _session != null) {
        if (requestGeneration != generation() ||
            authentication != _authenticationGeneration) {
          throw const RaftApiException.staleScope();
        }
        // Another caller may already have rotated the credentials while this
        // request was in flight: retry with them instead of rotating again.
        if (_session?.accessToken == sentAccessToken) {
          final recent = _refreshFailure;
          if (recent != null &&
              DateTime.now().difference(recent.at) < _refreshCooldown) {
            // The server just failed to answer a refresh: do not hammer it
            // with every request that meets an expired access token.
            throw recent.error;
          }
          await refresh();
        }
        if (requestGeneration != generation() ||
            authentication != _authenticationGeneration)
          throw const RaftApiException.staleScope();
        return _send(
          method,
          path,
          data: data is FormData ? data.clone() : data,
          query: query,
          retried: true,
          cancellation: cancellation,
          onSendProgress: onSendProgress,
          headers: headers,
          acceptServerExit: acceptServerExit,
          receiveTimeout: receiveTimeout,
          workspaceScoped: workspaceScoped,
        );
      }
      final body = e.response?.data;
      final status = e.response?.statusCode;
      Duration? retryAfter;
      if (status == 429) {
        // Every client request that meets a 429 closes that limiter for the
        // wait the server asked for, whoever sent it.
        retryAfter =
            retryAfterOf(e.response?.headers, governor.now()) ??
            const Duration(seconds: 5);
        governor.limitedBy(
          ServerRateLimits.forRequest(method, path),
          retryAfter,
        );
      } else {
        governor.observe(
          ServerRateLimits.forRequest(method, path),
          e.response?.headers,
        );
        if (status == 503 &&
            body is Map &&
            body['code'] == 'rw_overloaded' &&
            body['retryable'] == true) {
          // Web overloadRetry.rwOverloadRetryDelayMs: the server's hint, 2 s
          // when it sent none, never more than 10 s.
          final hint = retryAfterOf(e.response?.headers, governor.now());
          retryAfter = hint == null
              ? rwOverloadDefaultRetryAfter
              : hint > rwOverloadMaxRetryAfter
              ? rwOverloadMaxRetryAfter
              : hint;
        }
      }
      throw RaftApiException.response(
        body is Map
            ? (body['error'] ?? body['message'] ?? 'Request failed').toString()
            : e.type == DioExceptionType.connectionError
            ? 'Cannot connect to the Raft server.'
            : 'Request failed. Please retry.',
        status: status,
        body: body is Map ? body : null,
        retryAfter: retryAfter,
      );
    }
  }

  Future<void> refresh() async {
    final authentication = _authenticationGeneration;
    final before = _session;
    // Rotation is the only step that must not overlap a guest's rotation:
    // wait (bounded by the owner) until the guest has stopped, then continue
    // from the latest stored credentials and its pending refresh attempt.
    if (_credentialsReady != null) await _credentialsReady;
    if (_closed || authentication != _authenticationGeneration) {
      throw const RaftApiException('The account changed.');
    }
    final adopted = _session;
    if (before != null &&
        adopted != null &&
        adopted.accessToken != before.accessToken &&
        adopted.refreshAttemptId == null &&
        !_accessNeedsRefresh) {
      // The guest already rotated; the caller retries with its credentials.
      return;
    }
    await (_refreshing ??= _rotate().whenComplete(() => _refreshing = null));
  }

  Future<void> _rotate() async {
    var old = _session;
    if (old == null) {
      throw const RaftApiException('Please sign in again.', status: 401);
    }
    try {
      if (old.refreshAttemptId == null) {
        old = old.withAttempt(
          'arf_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}',
        );
        _session = old;
        await _persist(old);
      }
      if (_session != old) return;
      final value = await request(
        'POST',
        '/auth/refresh',
        data: {'refreshToken': old.refreshToken},
        authorized: false,
        headers: {
          'X-Slock-Auth-Refresh-Attempt-Id': old.refreshAttemptId,
          'X-Slock-Auth-Installation-Id': old.installationId,
        },
      );
      if (_session != old) return;
      final access = value is Map ? value['accessToken'] : null;
      final refresh = value is Map ? value['refreshToken'] : null;
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty) {
        // A 200 that is not a token pair (captive portal, proxy page).
        throw const RaftApiException(
          'The refresh response was not recognized.',
        );
      }
      final refreshed = Session(
        accessToken: access,
        refreshToken: refresh,
        installationId: old.installationId,
        cachedUser: old.cachedUser,
      );
      _session = refreshed;
      _lastRotatedAt = DateTime.now();
      _refreshFailure = null;
      if (sessionDegraded && !restoredOffline) _markHealthy();
      await _persist(refreshed);
      if (_session == refreshed && !_closed) {
        _socket?.auth = _authenticateSocket;
        // Consumers may re-read accepted credentials only after rotation.
        // The event deliberately contains neither access nor refresh tokens.
        if (refreshed.accessToken != old.accessToken) {
          _emit(const RaftEvent('session:credentials-updated', null));
        }
      }
    } on RaftApiException catch (e) {
      if (_session != old) rethrow;
      if (credentialVerdict(e) == SessionVerdict.endSession) {
        // Another owner may have rotated the token first (single-use
        // rotation): adopt its record instead of treating that as rejection.
        if (await _adoptRotatedElsewhere(old!)) return;
        await _endSession(
          SessionEndReason.refreshRejected,
          e,
          endpoint: '/auth/refresh',
        );
      } else {
        _refreshFailure = (at: DateTime.now(), error: e);
        _audit(
          'session_kept',
          'refresh_failed',
          status: e.status,
          endpoint: '/auth/refresh',
          detail: e.status == null ? e.message : null,
        );
        _markDegraded();
        _scheduleRecovery();
      }
      rethrow;
    } catch (e) {
      // Storage or decoding failures while rotating never sign out.
      _audit(
        'session_kept',
        'refresh_local_error',
        endpoint: '/auth/refresh',
        detail: e.runtimeType.toString(),
      );
      rethrow;
    }
  }

  Future<bool> _adoptRotatedElsewhere(Session old) async {
    final Session? latest;
    try {
      latest = await sessionStore.read(origin);
    } catch (_) {
      return false;
    }
    if (_closed || _session != old) return false;
    if (latest == null || latest.refreshToken == old.refreshToken) {
      return false;
    }
    final principal = old.cachedUser?['id'];
    final stored = latest.cachedUser?['id'];
    if (principal != null && stored != null && principal != stored) {
      return false;
    }
    _session = latest;
    _audit(
      'session_kept',
      'adopted_rotated_credentials',
      endpoint: '/auth/refresh',
    );
    _emit(const RaftEvent('session:credentials-updated', null));
    return true;
  }

  Map<String, dynamic> get _socketAuth => {
    'token': _session?.accessToken,
    'serverId': serverId,
    'clientKind': clientKind,
  };
  bool get _accessNeedsRefresh {
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(_session!.accessToken.split('.')[1]),
          ),
        ),
      );
      final exp = payload['exp'];
      return exp is num &&
          exp <= DateTime.now().millisecondsSinceEpoch / 1000 + 30;
    } catch (_) {
      return false;
    }
  }

  void _authenticateSocket(void Function(Map) callback) async {
    final generation = _generation;
    try {
      // A device clock that is ahead makes every token look expired: do not
      // rotate on each socket handshake because of it.
      final last = _lastRotatedAt;
      final recentlyRotated =
          last != null &&
          DateTime.now().difference(last) < _proactiveRefreshSpacing;
      if (_accessNeedsRefresh && !recentlyRotated) await refresh();
    } catch (_) {
      /* Retry policy keeps transient failures distinct from logout. */
    }
    if (_session != null && generation == _generation) callback(_socketAuth);
  }

  void connect() => _connectOwned();

  void _connectOwned() {
    if (_closed || _session == null || serverId == null) return;
    _socket?.dispose();
    final epoch = _generation;
    // ignore: raft_lints/avoid_unproxied_network_client -- The socket.io client; applyProxyTransport() wires it through the proxy hook (proxy_hook_guard_test).
    final socket = io.io(
      origin,
      applyProxyTransport(io.OptionBuilder().setTransports(['websocket']))
          .disableAutoConnect()
          .enableForceNew()
          .setAuthFn(_authenticateSocket)
          .build(),
    );
    _socket = socket;
    socket.onAny((String event, [dynamic payload]) {
      if (epoch == _generation) _emit(RaftEvent(event, payload));
    });
    socket.onConnect((_) {
      if (epoch != _generation) return;
      _socketRetries = 0;
      _emit(const RaftEvent('connected', null));
    });
    socket.onDisconnect((reason) {
      if (epoch != _generation) return;
      _emit(const RaftEvent('disconnected', null));
      // The server ended the connection (sign-out elsewhere, membership
      // change, restart): socket.io does not reconnect by itself. Connect
      // again; a revoked session is then told apart by the handshake, which
      // asks the refresh endpoint, not by this event.
      if (reason == 'io server disconnect' && _session != null) {
        _scheduleSocketRetry(
          socket,
          epoch,
          delay: serverDisconnectReconnectDelay(),
        );
      }
    });
    socket.onConnectError((error) async {
      if (epoch != _generation) return;
      final text = error.toString();
      _emit(
        RaftEvent('connection:error', {
          'notServerMember': text.contains('Not a member of this server'),
        }),
      );
      final lower = text.toLowerCase();
      if (lower.contains('token')) {
        // "Invalid or expired token" / "Invalid token type": ask the refresh
        // endpoint. Only its definitive answer can end the session.
        _audit('socket_auth', 'token_rejected', detail: text);
        try {
          await refresh();
          if (epoch == _generation && _session != null) {
            socket.auth = _authenticateSocket;
            if (_socketRetries == 0) {
              _socketRetries++;
              socket.connect();
            } else {
              _scheduleSocketRetry(socket, epoch);
            }
          }
        } catch (_) {
          if (_session != null && epoch == _generation) {
            _scheduleSocketRetry(socket, epoch);
          }
        }
      } else if (lower.contains('authentication')) {
        // "Authentication changed; reconnect required" / "Authentication
        // required": a reconnect re-reads the credentials.
        _audit('socket_auth', 'reconnect_required', detail: text);
        if (_session != null) _scheduleSocketRetry(socket, epoch);
      }
    });
    socket.io.on('reconnect_attempt', (_) {
      socket.auth = _authenticateSocket;
    });
    socket.connect();
  }

  /// Web `scheduleServerDisconnectReconnect`: a deploy drains every socket at
  /// once, so the first reconnect after a server-initiated disconnect is
  /// spread over 1-5 s (0.5x to 2.5x the first backoff step) instead of every
  /// client returning at the same instant.
  Duration serverDisconnectReconnectDelay() {
    final base = recoveryBackoff.isEmpty
        ? const Duration(seconds: 2)
        : recoveryBackoff.first;
    return Duration(
      microseconds:
          (base.inMicroseconds * (0.5 + 2 * governor.random.nextDouble()))
              .round(),
    );
  }

  void _scheduleSocketRetry(io.Socket socket, int epoch, {Duration? delay}) {
    _authRetry?.cancel();
    delay ??= recoveryBackoff.isEmpty
        ? const Duration(seconds: 2)
        : recoveryBackoff[math.min(_socketRetries, recoveryBackoff.length - 1)];
    _socketRetries++;
    _authRetry = Timer(delay, () {
      if (_closed || epoch != _generation || _session == null) return;
      socket.auth = _authenticateSocket;
      socket.connect();
    });
  }

  void resume(BigInt seq) {
    _socket?.emit('sync:resume', {'lastSeq': seq.toInt()});
  }

  /// Pause the live transport while preserving credentials and history.
  void suspendConnection() {
    _authRetry?.cancel();
    _socket?.disconnect();
  }

  void recoverConnection(BigInt seq) {
    if (connected) {
      resume(seq);
    } else {
      connect();
    }
  }

  void joinChannel(String channelId) =>
      _socket?.emit('join:channel', channelId);
  Future<List<RaftRecord>> servers() async => (await get('/servers') as List)
      .map((e) => RaftRecord(Map<String, dynamic>.from(e)))
      .toList();

  /// The account's server directory read as an account-level fact: a
  /// concurrent server switch does not retire it (authentication still does).
  Future<List<RaftRecord>> accountServers() async =>
      (await _accountRequest('GET', '/servers') as List)
          .map((e) => RaftRecord(Map<String, dynamic>.from(e)))
          .toList();

  Future<List<RaftChannel>> channels({bool dm = false}) async => (await get(
    dm ? '/channels/dm' : '/channels',
    query: dm ? null : {'archived': 'include'},
  ) as List).map((e) => RaftChannel(Map<String, dynamic>.from(e))).toList();
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async => Map<String, dynamic>.from(
    await get(
      '/messages/channel/$id',
      query: {
        'limit': limit,
        if (before != null) 'before': before.toString(),
        if (after != null) 'after': after.toString(),
      },
    ),
  );
  String newRandomId() => const Uuid().v4();

  /// The Content-Type of an upload's file part: what a browser sends for the
  /// picked file (Web's `FormData` carries `File.type`); without it dio says
  /// `application/octet-stream`, and the server cannot tell it is a picture.
  static DioMediaType? _partType(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) return null;
    try {
      return DioMediaType.parse(mimeType);
    } on Object {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async {
    final form = FormData.fromMap({
      'channelId': channelId,
      'files': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: _partType(mimeType),
      ),
    });
    final result = await request(
      'POST',
      '/attachments/upload',
      data: form,
      cancellation: cancellation,
      onSendProgress: onProgress,
    );
    return (result['attachments'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// A new stream is opened for each attempt, including an auth refresh retry.
  /// Platform files remain in private storage rather than being copied to bytes.
  Future<List<Map<String, dynamic>>> uploadStream(
    String channelId,
    Stream<List<int>> Function() openRead,
    int length,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async {
    final result = await request(
      'POST',
      '/attachments/upload',
      data: FormData.fromMap({
        'channelId': channelId,
        'files': MultipartFile.fromStream(
          openRead,
          length,
          filename: filename,
          contentType: _partType(mimeType),
        ),
      }),
      cancellation: cancellation,
      onSendProgress: onProgress,
    );
    return (result['attachments'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<RaftMessage> send(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) async => (await sendWithReceipt(
    channelId,
    content,
    attachments: attachments,
    mentions: mentions,
    randomId: randomId,
    asTask: asTask,
    timezone: timezone,
  )).message;

  /// [send] plus the wrapped receipt fields of `POST /v2/messages`
  /// (`pendingMentionActions`, `unresolvedMentionHandles`,
  /// `deliveryWarnings`); an unwrapped body yields an empty receipt.
  Future<({RaftMessage message, Map<String, dynamic> receipt})> sendWithReceipt(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) async {
    final value = await post(
      '/v2/messages',
      data: {
        'channelId': channelId,
        'content': content,
        if (timezone != null) 'timezone': timezone,
        if (asTask) 'asTask': true,
        'randomId': randomId ?? const Uuid().v4(),
        if (attachments != null) 'attachmentIds': attachments,
        if (mentions != null)
          'mentions': [
            for (final mention in mentions) Map<String, dynamic>.from(mention),
          ],
      },
    );
    final wrapped = value is Map && value['message'] is Map;
    return (
      message: RaftMessage(
        Map<String, dynamic>.from(value['message'] ?? value),
      ),
      receipt: wrapped
          ? Map<String, dynamic>.from(value)
          : const <String, dynamic>{},
    );
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    _generation++;
    _authenticationGeneration++;
    _session = null;
    user = null;
    _authRetry?.cancel();
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _socket?.dispose();
    http.close(force: true);
    if (_persisting > 0) await _persistence.catchError((Object _) {});
    await _events.close();
  }
}
