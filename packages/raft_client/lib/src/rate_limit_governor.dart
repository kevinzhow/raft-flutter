import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'server_rate_limits.dart';

/// Who is asking. Background work (prefetch, hover warming, periodic polls,
/// post-reconnect refreshes) yields to the user's own actions.
enum RequestPriority { foreground, background }

/// The server said "later" and the client will not ask again yet.
class RateLimitedException implements Exception {
  const RateLimitedException(this.retryAfter, {this.limit});
  final Duration retryAfter;
  final String? limit;
  @override
  String toString() => 'Too many requests. Try again in a moment.';
}

/// The caller cancelled while its request waited for the limiter.
class RateLimitWaitCancelled implements Exception {
  const RateLimitWaitCancelled();
}

/// `Retry-After` (delta-seconds or HTTP-date), else `RateLimit-Reset`
/// (delta-seconds; the express-rate-limit draft-6 shape) as a duration.
Duration? retryAfterOf(Headers? headers, DateTime now) {
  if (headers == null) return null;
  final retry = headers.value('retry-after')?.trim();
  if (retry != null && retry.isNotEmpty) {
    final seconds = int.tryParse(retry);
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      final at = DateTime.parse(_httpDate(retry));
      final wait = at.difference(now);
      return wait.isNegative ? Duration.zero : wait;
    } catch (_) {}
  }
  final reset = int.tryParse(headers.value('ratelimit-reset')?.trim() ?? '');
  if (reset != null) return Duration(seconds: reset < 0 ? 0 : reset);
  return null;
}

String _httpDate(String value) {
  // "Wed, 21 Oct 2026 07:28:00 GMT" -> ISO-8601.
  const months = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'may': '05',
    'jun': '06', 'jul': '07', 'aug': '08', 'sep': '09', 'oct': '10',
    'nov': '11', 'dec': '12', //
  };
  final m = RegExp(
    r'^(?:\w{3}, )?(\d{1,2}) (\w{3}) (\d{4}) (\d{2}:\d{2}:\d{2}) GMT$',
  ).firstMatch(value);
  if (m == null) return value;
  return '${m[3]}-${months[m[2]!.toLowerCase()]}-${m[1]!.padLeft(2, '0')}T${m[4]}Z';
}

/// Exponential backoff with full jitter. [hint] (the server's own Retry-After)
/// is a floor: the client never asks earlier than the server said, and adds
/// jitter on top so a crowd released by the same reset does not arrive in one
/// burst.
Duration backoffDelay(
  int attempt, {
  Duration? hint,
  Duration base = const Duration(seconds: 1),
  Duration cap = const Duration(seconds: 60),
  math.Random? random,
}) {
  final rng = random ?? math.Random();
  if (hint != null) {
    final spread = math.min(
      5000,
      math.max(250, (hint.inMilliseconds * 0.25).round()),
    );
    return hint + Duration(milliseconds: rng.nextInt(spread + 1));
  }
  final exponent = math.min(attempt, 16);
  final ceiling = math.min(
    cap.inMilliseconds,
    base.inMilliseconds * (1 << exponent),
  );
  return Duration(milliseconds: 250 + rng.nextInt(math.max(1, ceiling)));
}

/// Client-side admission for the server's rate-limited routes.
///
/// * Paces: counts what this client sent per limiter inside the limiter's own
///   window and holds a request back when sending it would use more than its
///   class's share of the limit (foreground [foregroundShare], background
///   [backgroundShare]). The remainder is headroom for the user's other
///   clients, which count against the same per-user bucket.
/// * Learns: `RateLimit-Remaining` / `RateLimit-Reset` on any response tell it
///   how much of the bucket the *server* sees used; when little is left,
///   background requests wait for the reset.
/// * Obeys: a 429 closes the bucket until `Retry-After`; nothing for that
///   bucket is sent before then.
///
/// A foreground request waits (bounded by [maxWait]); a background request that
/// would have to wait is refused at once with [RateLimitedException], so
/// prefetch queues stay short instead of piling up.
class RateLimitGovernor {
  RateLimitGovernor({
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
    math.Random? random,
    this.foregroundShare = 0.75,
    this.backgroundShare = 0.4,
    this.maxWait = const Duration(seconds: 30),
    this.pacedLimits = const {'attachments', 'translation', 'auth'},
  }) : _now = now ?? DateTime.now,
       _sleep = sleep ?? ((d) => Future<void>.delayed(d)),
       random = random ?? math.Random();

  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  final math.Random random;
  final double foregroundShare, backgroundShare;
  final Duration maxWait;

  /// Limiters this client paces proactively (the others only obey a 429).
  final Set<String> pacedLimits;

  final Map<String, List<DateTime>> _sent = {};
  final Map<String, DateTime> _blockedUntil = {};
  final Map<String, ({int remaining, DateTime resetAt, int max})> _server = {};
  int limited = 0;
  int paced = 0;

  DateTime now() => _now();

  /// Seconds-from-now the bucket is closed for, or null.
  Duration? blockedFor(String limitId) {
    final until = _blockedUntil[limitId];
    if (until == null) return null;
    final left = until.difference(_now());
    if (left <= Duration.zero) {
      _blockedUntil.remove(limitId);
      return null;
    }
    return left;
  }

  /// How long [limits] require waiting before a request of [priority].
  Duration _requiredWait(
    List<ServerRateLimit> limits,
    RequestPriority priority,
  ) {
    final t = _now();
    var wait = Duration.zero;
    for (final limit in limits) {
      final blocked = blockedFor(limit.id);
      if (blocked != null && blocked > wait) wait = blocked;
      if (!pacedLimits.contains(limit.id)) continue;
      final share = priority == RequestPriority.foreground
          ? foregroundShare
          : backgroundShare;
      final allowed = math.max(1, (limit.max * share).floor());
      final sent = _sent.putIfAbsent(limit.id, () => []);
      sent.removeWhere((x) => t.difference(x) >= limit.window);
      if (sent.length >= allowed) {
        final free = sent[sent.length - allowed].add(limit.window).difference(t);
        if (free > wait) wait = free;
      }
      if (priority == RequestPriority.background) {
        final seen = _server[limit.id];
        if (seen != null && t.isBefore(seen.resetAt)) {
          // The server counts everyone: keep the last fifth for the user.
          if (seen.remaining <= seen.max * 0.2) {
            final left = seen.resetAt.difference(t);
            if (left > wait) wait = left;
          }
        }
      }
    }
    return wait;
  }

  /// Waits until a request against [limits] may be sent and records it.
  /// Throws [RateLimitedException] when a background request would wait, or a
  /// foreground request would wait longer than [maxWait].
  ///
  /// [cancelled] completes when the caller no longer wants the request (a dio
  /// `CancelToken.whenCancel`): the wait ends at once with
  /// [RateLimitWaitCancelled] and nothing is recorded as sent, so a tile that
  /// scrolled away neither holds its place in line nor spends the budget.
  Future<void> acquire(
    List<ServerRateLimit> limits,
    RequestPriority priority, {
    Future<void>? cancelled,
  }) async {
    if (limits.isEmpty) return;
    var waited = Duration.zero;
    var gone = false;
    if (cancelled != null) {
      unawaited(cancelled.then<void>((_) => gone = true, onError: (Object _) => gone = true));
    }
    while (true) {
      if (gone) throw const RateLimitWaitCancelled();
      final wait = _requiredWait(limits, priority);
      if (wait <= Duration.zero) break;
      if (priority == RequestPriority.background ||
          waited + wait > maxWait) {
        limited++;
        throw RateLimitedException(wait, limit: limits.first.id);
      }
      paced++;
      // A little jitter so waiters released by one reset do not all fire at
      // the same instant.
      final step = wait + Duration(milliseconds: random.nextInt(400));
      waited += step;
      await (cancelled == null
          ? _sleep(step)
          : Future.any<void>([_sleep(step), cancelled.then<void>((_) {})]));
      if (gone) throw const RateLimitWaitCancelled();
    }
    final t = _now();
    for (final limit in limits) {
      _sent.putIfAbsent(limit.id, () => []).add(t);
    }
  }

  /// Learns the server's view from a response's `RateLimit-*` headers.
  void observe(List<ServerRateLimit> limits, Headers? headers) {
    if (headers == null || limits.isEmpty) return;
    final remaining = int.tryParse(headers.value('ratelimit-remaining') ?? '');
    final max = int.tryParse(headers.value('ratelimit-limit') ?? '');
    final reset = int.tryParse(headers.value('ratelimit-reset') ?? '');
    if (remaining == null || max == null || reset == null) return;
    // Several limiters can answer one request; the header is the last one's.
    // Attribute it to the limiter with the same maximum.
    for (final limit in limits) {
      if (limit.max == max) {
        _server[limit.id] = (
          remaining: remaining,
          resetAt: _now().add(Duration(seconds: reset)),
          max: max,
        );
      }
    }
  }

  /// Forgets everything learned and counted. A test seam: the app's governor
  /// is process-wide, so a test that closes a bucket must open it again for
  /// the tests that run after it (`limitedBy(..., Duration.zero)` cannot: it
  /// only ever extends a block).
  void reset() {
    _sent.clear();
    _blockedUntil.clear();
    _server.clear();
    limited = 0;
    paced = 0;
  }

  /// A 429 arrived: close the buckets until [retryAfter] has passed.
  void limitedBy(List<ServerRateLimit> limits, Duration retryAfter) {
    final until = _now().add(retryAfter);
    for (final limit in limits) {
      final current = _blockedUntil[limit.id];
      if (current == null || until.isAfter(current)) {
        _blockedUntil[limit.id] = until;
      }
    }
  }
}

/// Applies a [RateLimitGovernor] to a plain [Dio] that talks to the Raft
/// server without going through [RaftClient] (the attachment transfer client:
/// when the server streams the bytes itself, `GET /api/attachments/<id>` is
/// counted by the same per-user limiter as every other attachment request).
///
/// Only requests whose path is under a rate-limited `/api` route are touched;
/// signed storage URLs on other hosts pass through unchanged.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this.governor, this.dio, {this.retries = 2});
  final RateLimitGovernor governor;
  final Dio dio;
  final int retries;
  static const _attempt = 'raft.rateLimitAttempt';

  static List<ServerRateLimit> _limits(RequestOptions o) {
    final path = o.uri.path;
    if (!path.startsWith('/api/')) return const [];
    return ServerRateLimits.forRequest(o.method, path.substring(4));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final limits = _limits(options);
    if (limits.isNotEmpty) {
      try {
        await governor.acquire(
          limits,
          RequestPriority.foreground,
          cancelled: options.cancelToken?.whenCancel,
        );
      } on RateLimitWaitCancelled {
        // Not sent, not counted: the transfer was cancelled while it queued.
        return handler.reject(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled while waiting for the rate limiter',
          ),
          true,
        );
      } on RateLimitedException catch (limited) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 429,
              headers: Headers.fromMap({
                'retry-after': ['${limited.retryAfter.inSeconds + 1}'],
              }),
            ),
            error: limited,
          ),
          true,
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    governor.observe(_limits(response.requestOptions), response.headers);
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final limits = _limits(options);
    if (err.response?.statusCode != 429 || limits.isEmpty) {
      return handler.next(err);
    }
    final wait =
        retryAfterOf(err.response?.headers, governor.now()) ??
        const Duration(seconds: 5);
    if (err.error is! RateLimitedException) governor.limitedBy(limits, wait);
    final attempt = (options.extra[_attempt] as int?) ?? 0;
    if (attempt >= retries ||
        wait > governor.maxWait ||
        CancelToken.isCancel(err) ||
        options.cancelToken?.isCancelled == true) {
      return handler.next(err);
    }
    options.extra[_attempt] = attempt + 1;
    await Future<void>.delayed(
      backoffDelay(attempt, hint: wait, random: governor.random),
    );
    if (options.cancelToken?.isCancelled == true) return handler.next(err);
    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (again) {
      handler.next(again);
    }
  }
}
