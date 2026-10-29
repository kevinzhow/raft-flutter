import 'dart:async';
import 'dart:collection';

import 'package:raft_client/raft_client.dart' show RaftApiException;

/// Memory-only cache of signed attachment URLs.
///
/// A signed URL is a short-lived capability: it is held here only in memory,
/// is never logged or written to disk, and is dropped when its lifetime ends,
/// when its identity scope changes (account, server, role, sign-out), when its
/// channel is revoked, or when a transfer proves it stale. Callers keep their
/// own authority checks; a cache hit never replaces them.
///
/// Concurrent requests for the same attachment share one fetch (like Web's
/// `inlineAttachmentUrlCache`): a shared request outlives any single caller,
/// and each caller drops the result itself when it is gone.
///
/// Nothing is signed speculatively. A URL is requested only when something
/// needs it now (an open, a download, a share, a player, an image without a
/// server thumbnail); the cache only reuses what such a request already
/// signed. Callers that need many URLs in the same frame are gathered into one
/// batch request ([resolveCoalesced]).
class AttachmentUrlCache {
  AttachmentUrlCache({
    DateTime Function()? now,
    this.maxEntries = 256,
    this.maxLifetime = const Duration(minutes: 4),
    this.safetyMargin = const Duration(seconds: 45),
    this.unknownExpiryLifetime = const Duration(seconds: 150),
    this.batchSize = 50,
    this.coalesceDelay = Duration.zero,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final int maxEntries;

  /// Never trust a URL for longer than this, whatever the server says. The
  /// server signs for 300 s; staying under that bounds clock skew.
  final Duration maxLifetime;

  /// A URL with less validity left than this is not reused: a transfer that
  /// starts now must outlive request latency and a redirect.
  final Duration safetyMargin;

  /// Lifetime when neither the response nor the URL states an expiry (a URL
  /// the server itself streams, with the bearer token in its query). With the
  /// [safetyMargin] it is reused for about 105 s; a transfer that finds it
  /// stale (401/403) signs once more. A shorter guess made every card that
  /// came back into view after 15 s ask again.
  final Duration unknownExpiryLifetime;

  /// The batch route accepts 1..50 ids.
  final int batchSize;

  /// Callers of [resolveCoalesced] gather for this long (zero: the
  /// tiles built in one frame share an event-loop turn), then one
  /// batch request answers them all.
  final Duration coalesceDelay;

  final LinkedHashMap<_Key, _Entry> _entries = LinkedHashMap();
  final Map<_Key, Future<String>> _inFlight = {};
  final Set<_Key> _batched = {};
  Object? _scope;
  int _epoch = 0;

  /// In-flight keys whose answer must not be stored (a transfer rejected the
  /// URL while the request was out). Per key: one rejected URL does not make
  /// every other answer on its way worthless.
  final Set<_Key> _stale = {};
  final Map<_Key, _Urgent> _urgent = {};
  Timer? _urgentTimer;
  bool _urgentScheduled = false;
  int batchRequests = 0;

  /// Number of cached URLs (diagnostics and tests; never their values).
  int get length => _entries.length;
  int get inFlightCount => _inFlight.length;

  /// The unexpired URL for [id], or null. Never starts a request.
  String? peek(String id, {String disposition = 'inline', Object? scope}) {
    _enter(scope);
    final key = _Key(id, disposition);
    final entry = _entries[key];
    if (entry == null) return null;
    if (!entry.usable(_now(), safetyMargin)) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  /// Resolves [id]: a fresh cached URL, a request already in flight, or a new
  /// [fetch]. [fetch] returns the decoded `GET /attachments/<id>/url` body.
  /// [scope] is the caller's identity; a different scope drops everything held.
  Future<String> resolve(
    String id, {
    String disposition = 'inline',
    Object? scope,
    String? channelId,
    required Future<dynamic> Function() fetch,
  }) {
    final hit = peek(id, disposition: disposition, scope: scope);
    if (hit != null) return Future<String>.value(hit);
    final key = _Key(id, disposition);
    final pending = _inFlight[key];
    if (pending != null) {
      if (!_batched.contains(key)) return pending;
      // A batch may omit an id it was not allowed to resolve; ask singly.
      return pending.catchError(
        (Object _) => resolve(
          id,
          disposition: disposition,
          scope: scope,
          channelId: channelId,
          fetch: fetch,
        ),
      );
    }
    final epoch = _epoch;
    late final Future<String> request;
    request = () async {
      final body = await fetch();
      final url = body is Map ? body['url'] : null;
      if (url is! String || url.isEmpty) {
        throw const FormatException('Invalid attachment response.');
      }
      // A revocation or scope change while the request was out means this
      // answer is not stored; the awaiting caller still applies its own check.
      if (epoch == _epoch && !_stale.remove(key)) {
        _store(key, url, body['expiresAt'], channelId);
      }
      return url;
    }();
    _inFlight[key] = request;
    unawaited(
      request
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .whenComplete(() {
            if (identical(_inFlight[key], request)) _inFlight.remove(key);
          }),
    );
    return request;
  }

  /// Resolves [id] for a caller that needs it now, together with every other
  /// caller asking within [coalesceDelay]: one batch request instead of one
  /// request per attachment. [fetchMany] returns the decoded
  /// `POST /attachments/urls` body (`{urls: [{id, url, expiresAt}]}`). An id
  /// the batch does not answer (the server leaves out what it cannot sign)
  /// falls back to [fetch], the single route.
  Future<String> resolveCoalesced(
    String id, {
    Object? scope,
    String? channelId,
    required Future<dynamic> Function(List<String> ids) fetchMany,
    required Future<dynamic> Function() fetch,
  }) {
    const disposition = 'inline';
    final key = _Key(id, disposition);
    final hit = peek(id, disposition: disposition, scope: scope);
    if (hit != null) return Future<String>.value(hit);
    final pending = _inFlight[key];
    if (pending != null) {
      if (!_batched.contains(key)) return pending;
      return pending.catchError(
        (Object _) => resolve(
          id,
          disposition: disposition,
          scope: scope,
          channelId: channelId,
          fetch: fetch,
        ),
      );
    }
    final epoch = _epoch;
    final completer = Completer<String>();
    _inFlight[key] = completer.future;
    _batched.add(key);
    unawaited(completer.future.then<void>((_) {}, onError: (Object _) {}));
    _urgent[key] = _Urgent(
      key,
      channelId,
      fetchMany,
      fetch,
      epoch,
      completer,
      scope,
    );
    if (coalesceDelay == Duration.zero) {
      // Every tile built in this frame asks before any microtask runs, so one
      // microtask gathers them all without waiting for a timer.
      if (!_urgentScheduled) {
        _urgentScheduled = true;
        unawaited(
          // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot microtask gathering every tile built in this frame into one flush; the callback does not schedule another.
          Future<void>.microtask(() {
            _urgentScheduled = false;
            return _flushUrgent();
          }),
        );
      }
    } else {
      _urgentTimer ??= Timer(coalesceDelay, () {
        _urgentTimer = null;
        unawaited(_flushUrgent());
      });
    }
    return completer.future;
  }

  Future<void> _flushUrgent() async {
    final all = _urgent.values.toList();
    _urgent.clear();
    for (var start = 0; start < all.length; start += batchSize) {
      final batch = all.skip(start).take(batchSize).toList();
      unawaited(_sendUrgent(batch));
    }
  }

  Future<void> _sendUrgent(List<_Urgent> batch) async {
    batchRequests++;
    Map<String, Map> byId = {};
    try {
      final body = await batch.first.fetchMany([
        for (final item in batch) item.key.id,
      ]);
      final urls = body is Map ? body['urls'] : null;
      byId = {
        if (urls is List)
          for (final entry in urls)
            if (entry is Map && entry['id'] is String && entry['url'] is String)
              entry['id'] as String: entry,
      };
    } catch (error) {
      // The batch route failed as a whole; the singles below would meet the
      // same limiter, so a rate-limited answer is passed on, not retried.
      if (error is RaftApiException && error.rateLimited) {
        for (final item in batch) {
          _finish(item.key);
          item.completer.completeError(error);
        }
        return;
      }
    }
    for (final item in batch) {
      final entry = byId[item.key.id];
      if (entry != null) {
        if (item.epoch == _epoch && !_stale.remove(item.key)) {
          _store(
            item.key,
            entry['url'] as String,
            entry['expiresAt'],
            item.channelId,
          );
        }
        _finish(item.key);
        item.completer.complete(entry['url'] as String);
        continue;
      }
      // Not answered: ask for this one alone.
      _inFlight.remove(item.key);
      _batched.remove(item.key);
      try {
        final url = await resolve(
          item.key.id,
          disposition: item.key.disposition,
          scope: item.scope,
          channelId: item.channelId,
          fetch: item.fetch,
        );
        item.completer.complete(url);
      } catch (error, trace) {
        item.completer.completeError(error, trace);
      }
    }
  }

  void _finish(_Key key) {
    _inFlight.remove(key);
    _batched.remove(key);
  }

  /// Drops a URL a transfer rejected (expired or revoked).
  void invalidate(String id, {String? disposition}) {
    bool matches(_Key key) =>
        key.id == id && (disposition == null || key.disposition == disposition);
    _entries.removeWhere((key, _) => matches(key));
    // Only this attachment's request on its way is now suspect; answers for
    // every other id stay valid and are stored.
    for (final key in _inFlight.keys) {
      if (matches(key)) _stale.add(key);
    }
  }

  /// Revocation: nothing resolved for [channelId] survives, in flight included.
  void invalidateChannel(String channelId) {
    _entries.removeWhere((_, entry) => entry.channelId == channelId);
    _dropUrgent((item) => item.channelId == channelId);
    _epoch++;
  }

  /// Forgets the signed URLs already resolved ("Clear cache"); requests in
  /// flight and callers waiting for a batch are untouched, so a preview that
  /// is loading right now still gets its answer. The next use signs again.
  void dropResolved() => _entries.clear();

  void clear() {
    _entries.clear();
    _dropUrgent((_) => true);
    _stale.clear();
    _epoch++;
  }

  /// Callers still gathering for the next coalesced batch are released with
  /// an error (their scope changed or was revoked); they ask again if needed.
  void _dropUrgent(bool Function(_Urgent item) where) {
    for (final item in _urgent.values.where(where).toList()) {
      _urgent.remove(item.key);
      _finish(item.key);
      item.completer.completeError(
        const FormatException('Attachment url request withdrawn.'),
      );
    }
  }

  void dispose() {
    clear();
    _urgentTimer?.cancel();
    _urgentTimer = null;
  }

  /// Drops everything held for another identity (account, server, role,
  /// sign-out). Called with the owner's current scope on every state change.
  void synchronize(Object? scope) => _enter(scope);

  void _enter(Object? scope) {
    if (scope != _scope) {
      _scope = scope;
      clear();
    }
  }

  void _store(_Key key, String url, Object? expiresAt, String? channelId) {
    final now = _now();
    var lifetime = _lifetime(url, expiresAt, now);
    if (lifetime <= safetyMargin) return;
    if (lifetime > maxLifetime) lifetime = maxLifetime;
    _entries.remove(key);
    _entries[key] = _Entry(url, now.add(lifetime), channelId);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Remaining validity from the response, else from the URL's own signature
  /// (`X-Amz-Date` + `X-Amz-Expires`), else [unknownExpiryLifetime]. A URL that
  /// embeds a bearer token in its query (server-streamed storage) is short
  /// lived by the same default.
  Duration _lifetime(String url, Object? expiresAt, DateTime now) {
    if (expiresAt is String) {
      final at = DateTime.tryParse(expiresAt);
      if (at != null) return at.difference(now);
    }
    final query = Uri.tryParse(url)?.queryParameters ?? const {};
    String? param(String name) {
      for (final entry in query.entries) {
        if (entry.key.toLowerCase() == name) return entry.value;
      }
      return null;
    }

    final signedAt = param('x-amz-date') ?? param('x-goog-date'),
        seconds = param('x-amz-expires') ?? param('x-goog-expires');
    final span = int.tryParse(seconds ?? '');
    if (signedAt != null && span != null && signedAt.length == 16) {
      final start = DateTime.tryParse(
        '${signedAt.substring(0, 4)}-${signedAt.substring(4, 6)}-'
        '${signedAt.substring(6, 8)}T${signedAt.substring(9, 11)}:'
        '${signedAt.substring(11, 13)}:${signedAt.substring(13, 15)}Z',
      );
      if (start != null) {
        return start.add(Duration(seconds: span)).difference(now);
      }
    }
    return unknownExpiryLifetime;
  }
}

class _Key {
  const _Key(this.id, this.disposition);
  final String id, disposition;
  @override
  bool operator ==(Object other) =>
      other is _Key && other.id == id && other.disposition == disposition;
  @override
  int get hashCode => Object.hash(id, disposition);
}

class _Entry {
  _Entry(this.url, this.expires, this.channelId);
  final String url;
  final DateTime expires;
  final String? channelId;
  bool usable(DateTime now, Duration margin) =>
      expires.difference(now) > margin;
}

class _Urgent {
  _Urgent(
    this.key,
    this.channelId,
    this.fetchMany,
    this.fetch,
    this.epoch,
    this.completer,
    this.scope,
  );
  final Object? scope;
  final _Key key;
  final String? channelId;
  final Future<dynamic> Function(List<String>) fetchMany;
  final Future<dynamic> Function() fetch;
  final int epoch;
  final Completer<String> completer;
}
