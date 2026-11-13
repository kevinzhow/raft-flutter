// Source: packages/web/src/store/rwFreshness.ts, store/rwStaleCounts.ts and
// api/overloadRetry.ts (`getRwRead`) at v1.24.0-source.1 (task #164).

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

/// The RisingWave reads whose answers may be stale: the cross-server unread
/// summary, this server's channel unread counts, the Activity list and the
/// followed threads with unread replies.
enum RwSurface { summary, unread, inbox, followed }

/// `fresh`: the last answer was a clean 200. `stale`: an `X-Raft-Stale`
/// answer. `unavailable`: the read failed (a 503 that survived the retry, a
/// 5xx, no network); whatever was shown stays.
enum RwFreshness { fresh, stale, unavailable }

@immutable
class RwSurfaceState {
  const RwSurfaceState(
    this.freshness, {
    this.confirmed = false,
    this.retryAfter,
    this.code,
  });
  static const fresh = RwSurfaceState(RwFreshness.fresh);

  final RwFreshness freshness;

  /// The server said so (not only "seeded from the saved copy").
  final bool confirmed;

  /// The server's `Retry-After` hint from the last stale or failed answer.
  final Duration? retryAfter;

  /// The RisingWave code of the last failed answer (`rw_overloaded`,
  /// `rw_unconfigured`, `rw_read_failed`), when it carried one.
  final String? code;

  bool get outOfDate => confirmed && freshness != RwFreshness.fresh;

  @override
  bool operator ==(Object other) =>
      other is RwSurfaceState &&
      other.freshness == freshness &&
      other.confirmed == confirmed &&
      other.retryAfter == retryAfter &&
      other.code == code;

  @override
  int get hashCode => Object.hash(freshness, confirmed, retryAfter, code);
}

/// Per presentation: whether each [RwSurface] is current, read from the
/// answers of the workspace's HTTP client (Web `getRwRead`), and the recovery
/// loop that reads a stale or unavailable surface again (Web
/// `startRwRecovery`): first after the server's `Retry-After` (5 s without
/// one), then 5, 10, 20, 40, 60 s with ±20 % jitter, only while the app is in
/// the foreground. A return to the foreground reads at once; a reconnect
/// (`rooms:joined`) reads the summary and followed threads within a random
/// 0–5 s. The first clean 200 marks the surface fresh and stops its timer.
///
/// The loop runs only while a surface that shows these counts is mounted
/// ([watch]; Web: "only while the page is visible"), so no timer outlives the
/// screens that need it.
class RwFreshnessStore extends ChangeNotifier {
  RwFreshnessStore(
    this.client, {
    Map<RwSurface, Future<void> Function()>? refetch,
    bool Function()? visible,
    Random? random,
  }) : visible = visible ?? _alwaysVisible,
       _random = random ?? Random() {
    if (refetch != null) _refetch.addAll(refetch);
    _serverId = client.serverId;
    _observer = InterceptorsWrapper(
      onResponse: (response, next) {
        _answered(response.requestOptions, response);
        next.next(response);
      },
      onError: (error, next) {
        _failed(error);
        next.next(error);
      },
    );
    client.http.interceptors.add(_observer);
    _events = client.events.listen(_event);
  }

  static final _owners = Expando<RwFreshnessStore>();

  /// The store of [client] (created on first use): one per client, shared by
  /// the presentations that borrow it. Owners register the re-reads.
  static RwFreshnessStore ofClient(RaftClient client) =>
      _owners[client] ??= RwFreshnessStore(client);

  /// The store of [client] when a surface already asked for it.
  static RwFreshnessStore? peek(RaftClient client) => _owners[client];

  static bool _alwaysVisible() => true;

  /// Request paths of each surface (Web `getRwRead` call sites).
  static const paths = {
    '/servers/unread-summary': RwSurface.summary,
    '/channels/unread': RwSurface.unread,
    '/channels/inbox': RwSurface.inbox,
    '/channels/threads/followed': RwSurface.followed,
  };

  static const backoff = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
    Duration(seconds: 60),
  ];
  static const maxDelay = Duration(seconds: 60);
  static const reconnectSpread = Duration(seconds: 5);
  static const _nudgeCoalesce = Duration(seconds: 2);
  static const _unavailableCodes = {
    'rw_overloaded',
    'rw_unconfigured',
    'rw_read_failed',
  };

  /// The wait before the [attempt]-th re-read (0-based), before jitter.
  static Duration recoveryDelay(int attempt, Duration? retryAfter) {
    if (attempt == 0) {
      final first = retryAfter ?? backoff.first;
      return first > maxDelay ? maxDelay : first;
    }
    return backoff[min(attempt - 1, backoff.length - 1)];
  }

  final RaftClient client;

  /// Whether the app is in the foreground (the timer waits otherwise).
  bool Function() visible;
  final Random _random;
  final _refetch = <RwSurface, Future<void> Function()>{};
  late final Interceptor _observer;
  StreamSubscription<RaftEvent>? _events;
  String? _serverId;
  bool _disposed = false;
  DateTime? _lastNudge;
  Timer? _reconnect;
  final _surfaces = <RwSurface, RwSurfaceState>{
    for (final s in RwSurface.values) s: RwSurfaceState.fresh,
  };
  final _attempts = <RwSurface, int>{};
  final _timers = <RwSurface, Timer>{};
  final _inFlight = <RwSurface>{};
  int _watchers = 0;

  /// A notice that shows these counts is mounted: run the recovery loop.
  void watch() {
    if (_disposed || _watchers++ > 0) return;
    for (final s in RwSurface.values) {
      _schedule(s);
    }
  }

  /// The last such notice went away: stop every timer.
  void unwatch() {
    if (_disposed || --_watchers > 0) return;
    _watchers = 0;
    _reconnect?.cancel();
    _reconnect = null;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// First 503 `rw_overloaded` answers the client retries once by itself
  /// (`rwOverloadRetriedPaths`): the retry decides, not this answer.
  final _retrying = <RwSurface>{};

  RwSurfaceState operator [](RwSurface surface) => _surfaces[surface]!;

  /// The notice shows: one of [of] was said stale or failed.
  bool outOfDate(Iterable<RwSurface> of) => of.any((s) => this[s].outOfDate);

  /// One of [of] failed because RisingWave is not configured: that read will
  /// not catch up on its own.
  bool unconfigured(Iterable<RwSurface> of) => of.any(
    (s) =>
        this[s].freshness == RwFreshness.unavailable &&
        this[s].code == 'rw_unconfigured',
  );

  /// Sets the surface's re-read (the summary's owner lives in the shell).
  void register(RwSurface surface, Future<void> Function() refetch) =>
      _refetch[surface] = refetch;

  void unregister(RwSurface surface, Future<void> Function() refetch) {
    if (_refetch[surface] == refetch) _refetch.remove(surface);
  }

  static RwSurface? surfaceOf(RequestOptions request) =>
      request.method == 'GET' ? paths[request.path] : null;

  bool _current(RequestOptions request) {
    final surface = surfaceOf(request);
    if (surface == null || surface == RwSurface.summary) return true;
    final server = request.headers['X-Server-Id'];
    return server == null || server == client.serverId;
  }

  void _answered(RequestOptions request, Response response) {
    final surface = surfaceOf(request);
    if (_disposed || surface == null || !_current(request)) return;
    _syncServer();
    _retrying.remove(surface);
    final stale = response.headers.value('x-raft-stale');
    _set(
      surface,
      stale != null && stale.isNotEmpty
          ? RwSurfaceState(
              RwFreshness.stale,
              confirmed: true,
              retryAfter: retryAfterOf(response.headers, DateTime.now()),
            )
          : const RwSurfaceState(RwFreshness.fresh, confirmed: true),
    );
  }

  void _failed(DioException error) {
    final request = error.requestOptions;
    final surface = surfaceOf(request);
    if (_disposed || surface == null || !_current(request)) return;
    if (error.type == DioExceptionType.cancel) return;
    _syncServer();
    final response = error.response;
    final status = response?.statusCode;
    final body = response?.data;
    final code = body is Map && _unavailableCodes.contains(body['code'])
        ? body['code'] as String
        : null;
    if (status == 503 &&
        code == 'rw_overloaded' &&
        body is Map &&
        body['retryable'] == true &&
        RaftClient.rwOverloadRetriedPaths.contains(request.path) &&
        _retrying.add(surface)) {
      return;
    }
    _retrying.remove(surface);
    final unavailable = status == null
        ? error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout
        : status >= 500;
    if (!unavailable) return;
    _set(
      surface,
      RwSurfaceState(
        RwFreshness.unavailable,
        confirmed: true,
        retryAfter: retryAfterOf(response?.headers, DateTime.now()),
        code: code,
      ),
    );
  }

  /// A server switch: the server-scoped reads start over.
  void _syncServer() {
    if (_serverId == client.serverId) return;
    _serverId = client.serverId;
    var changed = false;
    for (final s in const [
      RwSurface.unread,
      RwSurface.inbox,
      RwSurface.followed,
    ]) {
      _cancel(s);
      _retrying.remove(s);
      if (_surfaces[s] != RwSurfaceState.fresh) {
        _surfaces[s] = RwSurfaceState.fresh;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _set(RwSurface surface, RwSurfaceState next) {
    if (_surfaces[surface] == next) {
      _schedule(surface);
      return;
    }
    _surfaces[surface] = next;
    _schedule(surface);
    notifyListeners();
  }

  void _event(RaftEvent event) {
    if (_disposed || _watchers == 0 || event.name != 'rooms:joined') return;
    // A deploy reconnects every client at once: spread the reconnect reads
    // (the unread counts and Activity are re-read by rooms:joined already).
    _reconnect ??= Timer(
      Duration(
        milliseconds: (_random.nextDouble() * reconnectSpread.inMilliseconds)
            .round()
            .clamp(1, reconnectSpread.inMilliseconds),
      ),
      () {
        _reconnect = null;
        nudge(const [RwSurface.summary, RwSurface.followed]);
      },
    );
  }

  /// The app came back or the socket reconnected: read what is out of date
  /// now (a visible + focus pair reads once).
  void nudge([Iterable<RwSurface> surfaces = RwSurface.values]) {
    if (_disposed) return;
    final now = DateTime.now();
    final last = _lastNudge;
    if (last != null && now.difference(last) < _nudgeCoalesce) return;
    _lastNudge = now;
    for (final s in surfaces) {
      if (this[s].outOfDate) _run(s);
    }
  }

  void _schedule(RwSurface surface) {
    if (_disposed) return;
    if (!this[surface].outOfDate) {
      _cancel(surface);
      return;
    }
    if (_watchers == 0 ||
        _timers.containsKey(surface) ||
        _inFlight.contains(surface)) {
      return;
    }
    final attempt = _attempts[surface] ?? 0;
    final base = recoveryDelay(attempt, this[surface].retryAfter);
    final jittered = Duration(
      milliseconds: min(
        maxDelay.inMilliseconds,
        (base.inMilliseconds * (0.8 + 0.4 * _random.nextDouble())).round(),
      ),
    );
    _timers[surface] = Timer(
      jittered < const Duration(milliseconds: 1)
          ? const Duration(milliseconds: 1)
          : jittered,
      () {
        _timers.remove(surface);
        // In the background: wait; the return to the foreground reads.
        if (!visible()) return;
        _run(surface);
      },
    );
  }

  void _run(RwSurface surface) {
    _timers.remove(surface)?.cancel();
    if (_inFlight.contains(surface)) return;
    final refetch = _refetch[surface];
    if (refetch == null) return;
    _inFlight.add(surface);
    _attempts[surface] = (_attempts[surface] ?? 0) + 1;
    unawaited(
      Future<void>.sync(refetch).catchError((_) {}).whenComplete(() {
        _inFlight.remove(surface);
        // Still out of date (no state change notified): the next one.
        _schedule(surface);
      }),
    );
  }

  void _cancel(RwSurface surface) {
    _timers.remove(surface)?.cancel();
    _attempts.remove(surface);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    client.http.interceptors.remove(_observer);
    unawaited(_events?.cancel());
    _reconnect?.cancel();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
