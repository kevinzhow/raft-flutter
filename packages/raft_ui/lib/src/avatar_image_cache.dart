import 'dart:async';
import 'dart:collection';
import 'dart:io' show HttpClient, HttpClientResponse, HttpHeaders, HttpStatus;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'sized_image.dart' show RaftSizedImageKey;

/// Avatar and icon pictures (people, agents, servers, apps) are small, shown
/// everywhere and reused constantly, so they get a cache of their own instead
/// of sharing the 100 MB decoded-bitmap LRU with message attachments.
///
/// Layers, outermost first:
///
/// 1. decoded bitmap, held by [RaftHotImages] (an LRU of keep-alive handles
///    that the shared `ImageCache` cannot evict) so a remount paints in the
///    same frame;
/// 2. encoded bytes in memory, keyed by [raftStableImageKey] (not by display
///    size, so 20 / 36 / 64 dp surfaces share one download);
/// 3. encoded bytes in a persistent [RaftImageByteStore] when the host
///    installs one (the app does; survives restarts and background trims);
/// 4. the network, once per key at a time, with failures remembered briefly so
///    a 404 avatar is not requested again by every row that shows it.
///
/// Entries the server marked `no-cache` (external avatars: the picture can
/// change under the same URL) or whose freshness ran out are kept with their
/// `ETag` / `Last-Modified` and revalidated stale-while-revalidate: the kept
/// bytes are shown at once and one conditional request (at most once per key
/// per [RaftImageBytes.revalidateInterval]) either renews them (304: nothing
/// is transferred or decoded again) or replaces them (200: on-screen avatars
/// swap to the new picture).
///
/// Query parameters that only sign or time-limit a URL never take part in the
/// key; the request still uses the full URL it was given.

/// Query parameters (case-insensitive) that change per request without
/// changing the picture: URL signatures, expiry and tokens.
bool _volatileParameter(String name) {
  final n = name.toLowerCase();
  return n.startsWith('x-amz-') ||
      n.startsWith('x-goog-') ||
      n.startsWith('x-ms-') ||
      const {
        'signature',
        'sig',
        'expires',
        'expiry',
        'exp',
        'token',
        'access_token',
        'policy',
        'key-pair-id',
        'se',
        'sp',
        'sv',
        'sr',
        'skoid',
        'sktid',
        'st',
        'ske',
        'sks',
        'skv',
      }.contains(n);
}

/// The cache identity of [url]: lower-cased scheme and host, no fragment, no
/// signing or expiry parameters, remaining parameters sorted. Content
/// identifying parameters (`v`, `s`, `size`, ...) stay.
String raftStableImageKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  final kept =
      [
        for (final e in uri.queryParametersAll.entries)
          if (!_volatileParameter(e.key))
            for (final v in e.value) MapEntry(e.key, v),
      ]..sort(
        (a, b) => a.key == b.key
            ? a.value.compareTo(b.value)
            : a.key.compareTo(b.key),
      );
  final query = kept.map(
    (e) =>
        '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
  );
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    userInfo: uri.userInfo,
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    query: query.isEmpty ? null : query.join('&'),
  ).toString();
}

/// The decode extent (physical px) for an avatar box of [extent] px: rounded
/// up to a multiple of 12 (48 above 144). The exact common sizes (36 dp at
/// 1x / 2x / 3x = 36 / 72 / 108, 20 dp at 3x = 60) are unchanged, while the
/// fractional-ratio sizes that differ by a few pixels (2.5x and 2.625x phones)
/// share one decoded bitmap instead of one each.
int raftBucketExtent(int extent) {
  final step = extent <= 144 ? 12 : 48;
  return (extent + step - 1) ~/ step * step;
}

/// An entry of a [RaftImageByteStore]: the bytes, when the server's freshness
/// ends and the validators that make a conditional request possible.
class RaftStoredImage {
  const RaftStoredImage(
    this.bytes, {
    required this.expires,
    this.etag,
    this.lastModified,
  });
  final Uint8List bytes;
  final DateTime expires;
  final String? etag, lastModified;

  bool get canRevalidate => etag != null || lastModified != null;
}

/// Persistent encoded-bytes storage behind [RaftImageBytes] (disk in the app).
/// Implementations must be safe to call concurrently and may throw; a failing
/// store only costs a network request.
abstract interface class RaftImageByteStore {
  /// The entry for [key], also when its freshness ran out as long as it can
  /// be revalidated; null when there is none (or it is expired and cannot).
  Future<RaftStoredImage?> readEntry(String key);

  /// Stores [bytes] for at most [maxAge] (the server's `Cache-Control`; null
  /// when it said nothing) together with the validators. A zero [maxAge]
  /// means "stale at once": kept only when there is an [etag] or
  /// [lastModified] to revalidate with, otherwise not at all.
  Future<void> write(
    String key,
    Uint8List bytes, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  });

  /// After a 304: the stored bytes stay, their freshness restarts from now
  /// ([maxAge] as in [write]) and a validator the server sent again replaces
  /// the old one.
  Future<void> touch(
    String key, {
    Duration? maxAge,
    String? etag,
    String? lastModified,
  });
}

/// What a fetch returned: the encoded picture, how long the server allows
/// keeping it ([raftCacheControlMaxAge]) and its validators. A conditional
/// request the server answered `304 Not Modified` is [notModified]: no bytes,
/// the stored ones are still good.
class RaftFetchedImage {
  const RaftFetchedImage(
    this.bytes, {
    this.maxAge,
    this.etag,
    this.lastModified,
    this.noStore = false,
  }) : notModified = false;

  RaftFetchedImage.notModified({this.maxAge, this.etag, this.lastModified})
    : bytes = Uint8List(0),
      noStore = false,
      notModified = true;

  final Uint8List bytes;
  final Duration? maxAge;
  final String? etag, lastModified;

  /// `Cache-Control: no-store`: never kept anywhere but memory.
  final bool noStore;
  final bool notModified;

  bool get canRevalidate => etag != null || lastModified != null;
}

typedef RaftImageFetcher = Future<RaftFetchedImage> Function(String url);

/// A conditional GET: `If-None-Match: [etag]` and / or `If-Modified-Since:
/// [lastModified]`. Answers [RaftFetchedImage.notModified] for a 304.
typedef RaftImageRevalidator =
    Future<RaftFetchedImage> Function(
      String url, {
      String? etag,
      String? lastModified,
    });

/// The freshness a `Cache-Control` header grants: `immutable` is unbounded
/// ([Duration] of 10 years), `max-age=N` is N seconds, `no-store` / `no-cache`
/// / `max-age=0` is zero, no usable directive is null. `s-maxage` is ignored.
Duration? raftCacheControlMaxAge(String? header) {
  if (header == null) return null;
  Duration? result;
  var immutable = false;
  for (final raw in header.split(',')) {
    final directive = raw.trim().toLowerCase();
    if (directive == 'no-store' || directive == 'no-cache') {
      return Duration.zero;
    }
    if (directive == 'immutable') immutable = true;
    if (directive.startsWith('max-age=')) {
      final seconds = int.tryParse(directive.substring(8).replaceAll('"', ''));
      if (seconds != null && seconds >= 0) result = Duration(seconds: seconds);
    }
  }
  if (result != null) return result;
  return immutable ? const Duration(days: 3650) : null;
}

/// True when a `Cache-Control` header forbids keeping the response anywhere
/// (`no-store`); `no-cache` only demands revalidation.
bool raftCacheControlNoStore(String? header) =>
    header != null &&
    header.split(',').any((d) => d.trim().toLowerCase() == 'no-store');

class RaftImageHttpError implements Exception {
  const RaftImageHttpError(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'RaftImageHttpError($statusCode)';
}

/// What [RaftImageBytes] knows about an in-memory entry's freshness.
class _Validity {
  const _Validity(this.expires, {this.etag, this.lastModified});
  final DateTime expires;
  final String? etag, lastModified;
  bool get canRevalidate => etag != null || lastModified != null;
}

/// Bytes of avatar pictures: memory, then [store], then [fetcher].
class RaftImageBytes {
  /// Encoded avatar bytes kept in memory (the app's memory budget table,
  /// `RaftMemoryBudgets`, lists it).
  static const defaultMemoryBudgetBytes = 8 * 1024 * 1024;

  RaftImageBytes({
    RaftImageFetcher? fetcher,
    RaftImageRevalidator? revalidator,
    this.store,
    this.memoryBudgetBytes = defaultMemoryBudgetBytes,
    this.maxEntryBytes = 4 * 1024 * 1024,
    this.clientErrorMemory = const Duration(minutes: 10),
    this.transientErrorMemory = const Duration(minutes: 1),
    this.revalidateInterval = const Duration(minutes: 10),
    this.freshnessCap = const Duration(days: 14),
    this.unknownFreshness = const Duration(hours: 1),
    DateTime Function()? now,
  }) : fetcher = fetcher ?? _fetchWithFlutterClient,
       revalidator =
           revalidator ??
           (fetcher == null ? _revalidateWithFlutterClient : null),
       _now = now ?? DateTime.now;

  /// The process-wide service used by [RaftAvatarImageProvider].
  static RaftImageBytes instance = RaftImageBytes();

  RaftImageFetcher fetcher;

  /// Sends the conditional request for an entry that is stale but carries an
  /// `ETag` / `Last-Modified`. Without one a stale entry is just served.
  RaftImageRevalidator? revalidator;
  RaftImageByteStore? store;
  final int memoryBudgetBytes, maxEntryBytes;

  /// How long a 4xx answer (no such avatar) is remembered without asking
  /// again, and the same for a network failure or 5xx.
  final Duration clientErrorMemory, transientErrorMemory;

  /// A key is revalidated at most once per interval and process, whatever
  /// the answer (a list of rows showing one avatar sends one request).
  final Duration revalidateInterval;

  /// The longest freshness honoured, and the one assumed when the server did
  /// not say.
  final Duration freshnessCap, unknownFreshness;
  final DateTime Function() _now;

  final _memory = LinkedHashMap<String, Uint8List>();
  final _validity = <String, _Validity>{};
  var _memoryBytes = 0;
  final _inFlight = <String, Future<Uint8List>>{};
  final _failures = <String, ({DateTime until, Object error})>{};
  final _revalidating = <String>{};
  final _writes = <Future<void>>{};
  final _lastRevalidation = <String, DateTime>{};
  final _revisions = <String, int>{};
  final _changeListeners = <void Function(String key)>[];

  /// Requests that reached [fetcher] (tests and diagnostics).
  int fetchCount = 0;

  /// Conditional requests sent through [revalidator] (tests and diagnostics).
  int revalidationCount = 0;

  int get memoryEntries => _memory.length;
  int get memoryBytes => _memoryBytes;

  /// Completes when no revalidation is in flight and every write to the
  /// [store] has finished (tests; nothing else needs to wait for them).
  @visibleForTesting
  Future<void> settled() async {
    while (_revalidating.isNotEmpty || _writes.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Counts the pictures that replaced different bytes under [stableKey]
  /// after a revalidation; part of the decode key so the new picture is not
  /// answered from the decoded copy of the old one.
  int revisionOf(String stableKey) => _revisions[stableKey] ?? 0;

  /// Calls [listener] with the stable key whenever a revalidation brought
  /// different bytes (the 304 case is silent).
  void addChangeListener(void Function(String key) listener) =>
      _changeListeners.add(listener);
  void removeChangeListener(void Function(String key) listener) =>
      _changeListeners.remove(listener);

  /// The encoded bytes for [url], which is requested as given while the cache
  /// identity is [raftStableImageKey] of it. Stale bytes with validators are
  /// returned at once and revalidated in the background.
  Future<Uint8List> load(String url) {
    final key = raftStableImageKey(url);
    final hit = _memory.remove(key);
    if (hit != null) {
      _memory[key] = hit; // most recent last
      _revalidateIfStale(key, url);
      return SynchronousFuture(hit);
    }
    final failure = _failures[key];
    if (failure != null) {
      if (_now().isBefore(failure.until)) {
        return Future<Uint8List>.error(failure.error);
      }
      _failures.remove(key);
    }
    return _inFlight[key] ??= _fill(key, url).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Called whenever an avatar is shown, also when its decoded bitmap answers
  /// and [load] is not reached: starts the (rate limited) revalidation of a
  /// stale entry. Cheap when nothing is stale.
  void noteUse(String url) {
    final key = raftStableImageKey(url);
    if (_validity.containsKey(key)) _revalidateIfStale(key, url);
  }

  DateTime _freshUntil(Duration? maxAge) {
    final granted = maxAge ?? unknownFreshness;
    return _now().add(granted < freshnessCap ? granted : freshnessCap);
  }

  Future<Uint8List> _fill(String key, String url) async {
    final persisted = store;
    if (persisted != null) {
      try {
        final stored = await persisted.readEntry(key);
        if (stored != null && stored.bytes.isNotEmpty) {
          _remember(
            key,
            stored.bytes,
            _Validity(
              stored.expires,
              etag: stored.etag,
              lastModified: stored.lastModified,
            ),
          );
          _revalidateIfStale(key, url);
          return stored.bytes;
        }
      } catch (_) {
        // A broken store is a miss.
      }
    }
    try {
      fetchCount++;
      final fetched = await fetcher(url);
      final bytes = fetched.bytes;
      // A full download is as good as a validation: the picture is current.
      _lastRevalidation[key] = _now();
      _remember(key, bytes, _validityOf(fetched));
      _persist(key, fetched);
      return bytes;
    } catch (error) {
      final client =
          error is RaftImageHttpError &&
          error.statusCode >= 400 &&
          error.statusCode < 500 &&
          error.statusCode != HttpStatus.requestTimeout &&
          error.statusCode != HttpStatus.tooManyRequests;
      _failures[key] = (
        until: _now().add(client ? clientErrorMemory : transientErrorMemory),
        error: error,
      );
      rethrow;
    }
  }

  _Validity _validityOf(RaftFetchedImage fetched) => _Validity(
    _freshUntil(fetched.maxAge),
    etag: fetched.etag,
    lastModified: fetched.lastModified,
  );

  void _persist(String key, RaftFetchedImage fetched) {
    final persisted = store;
    if (persisted == null || fetched.noStore) return;
    if (fetched.maxAge == Duration.zero && !fetched.canRevalidate) return;
    // Fire and forget, and never an error: a store that fails only costs a
    // later request. Tracked so tests can wait for it ([settled]).
    late final Future<void> write;
    write = Future<void>.sync(
      () => persisted.write(
        key,
        fetched.bytes,
        maxAge: fetched.maxAge,
        etag: fetched.etag,
        lastModified: fetched.lastModified,
      ),
    ).catchError((Object _) {}).whenComplete(() => _writes.remove(write));
    _writes.add(write);
  }

  /// Stale-while-revalidate: when the in-memory entry for [key] ran out of
  /// freshness and has validators, sends one conditional request (rate
  /// limited per key); the caller already has the stored bytes.
  void _revalidateIfStale(String key, String url) {
    final validity = _validity[key];
    final send = revalidator;
    if (send == null ||
        validity == null ||
        !validity.canRevalidate ||
        _revalidating.contains(key)) {
      return;
    }
    final now = _now();
    if (now.isBefore(validity.expires)) return;
    final last = _lastRevalidation[key];
    if (last != null && now.difference(last) < revalidateInterval) return;
    if (_lastRevalidation.length > 512) {
      _lastRevalidation.removeWhere(
        (_, at) => now.difference(at) >= revalidateInterval,
      );
    }
    _lastRevalidation[key] = now;
    _revalidating.add(key);
    unawaited(
      _revalidate(key, url, send, validity).whenComplete(() {
        _revalidating.remove(key);
      }),
    );
  }

  Future<void> _revalidate(
    String key,
    String url,
    RaftImageRevalidator send,
    _Validity was,
  ) async {
    try {
      revalidationCount++;
      final answer = await send(
        url,
        etag: was.etag,
        lastModified: was.lastModified,
      );
      if (answer.notModified) {
        // The bytes (and any decoded copy of them) stay as they are.
        final expires = _freshUntil(answer.maxAge);
        final etag = answer.etag ?? was.etag;
        final lastModified = answer.lastModified ?? was.lastModified;
        if (_validity.containsKey(key)) {
          _validity[key] = _Validity(
            expires,
            etag: etag,
            lastModified: lastModified,
          );
        }
        final persisted = store;
        if (persisted != null && !answer.noStore) {
          await persisted.touch(
            key,
            maxAge: answer.maxAge,
            etag: answer.etag,
            lastModified: answer.lastModified,
          );
        }
        return;
      }
      final old = _memory[key];
      final same = old != null && listEquals(old, answer.bytes);
      _remember(key, answer.bytes, _validityOf(answer));
      _persist(key, answer);
      if (!same) {
        final revision = _revisions[key] = revisionOf(key) + 1;
        // The decoded copies of the old picture go; widgets still showing it
        // keep it until they swap (see RaftSizedImage).
        RaftHotImages.instance.releaseWhere((held) {
          if (held is! RaftSizedImageKey) return false;
          final source = held.source;
          return source is RaftAvatarImageKey &&
              source.stable == key &&
              source.revision != revision;
        });
        for (final listener in List.of(_changeListeners)) {
          listener(key);
        }
      }
    } catch (_) {
      // Offline or an error answer: the stored picture stays in use.
    }
  }

  void _remember(String key, Uint8List bytes, _Validity validity) {
    if (bytes.length > maxEntryBytes) return;
    final old = _memory.remove(key);
    if (old != null) _memoryBytes -= old.length;
    _memory[key] = bytes;
    _validity[key] = validity;
    _memoryBytes += bytes.length;
    while (_memoryBytes > memoryBudgetBytes && _memory.length > 1) {
      _dropOldest();
    }
  }

  void _dropOldest() {
    final oldest = _memory.keys.first;
    _memoryBytes -= _memory.remove(oldest)!.length;
    _validity.remove(oldest);
  }

  /// Forgets remembered failures (for example after the network changed).
  void forgetFailures() => _failures.clear();

  /// Drops the in-memory copies and with them what was known about their
  /// freshness (validators, when each was last revalidated); the [store] and
  /// the network still serve. "Clear cache" calls this together with emptying
  /// the store, so the next use is a plain first fetch.
  void clearMemory() {
    trimMemory(0);
    _lastRevalidation.clear();
  }

  /// Drops the oldest in-memory copies until at most [maxBytes] remain.
  void trimMemory(int maxBytes) {
    while (_memoryBytes > maxBytes && _memory.isNotEmpty) {
      _dropOldest();
    }
  }

  // One client for every avatar so connections are reused, like the framework's
  // own NetworkImage client.
  static HttpClient? _client;

  /// Forgets the shared client (tests that change `HttpOverrides`).
  @visibleForTesting
  static void resetClient() {
    _client?.close(force: true);
    _client = null;
  }

  static Future<RaftFetchedImage> _fetchWithFlutterClient(String url) =>
      _revalidateWithFlutterClient(url);

  static Future<RaftFetchedImage> _revalidateWithFlutterClient(
    String url, {
    String? etag,
    String? lastModified,
  }) async {
    // Same client NetworkImage uses: it follows `HttpOverrides.global`, which
    // the app points at the shared proxy decision (docs/system-proxy.md); the
    // app also installs its own fetcher on [RaftImageBytes.instance].
    // ignore: raft_lints/avoid_unproxied_network_client -- Resolves through HttpOverrides.global (SystemProxy.installGlobally), exactly like Flutter's NetworkImage; the app replaces it with SystemProxy.createHttpClient.
    final client = _client ??= HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    if (etag != null) request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
    if (lastModified != null) {
      request.headers.set(HttpHeaders.ifModifiedSinceHeader, lastModified);
    }
    final HttpClientResponse response = await request.close();
    final cacheControl = response.headers.value(HttpHeaders.cacheControlHeader);
    final tag = response.headers.value(HttpHeaders.etagHeader);
    final modified = response.headers.value(HttpHeaders.lastModifiedHeader);
    if (response.statusCode == HttpStatus.notModified) {
      await response.drain<void>();
      return RaftFetchedImage.notModified(
        maxAge: raftCacheControlMaxAge(cacheControl),
        etag: tag,
        lastModified: modified,
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw RaftImageHttpError(response.statusCode);
    }
    return RaftFetchedImage(
      await consolidateHttpClientResponseBytes(response),
      maxAge: raftCacheControlMaxAge(cacheControl),
      etag: tag,
      lastModified: modified,
      noStore: raftCacheControlNoStore(cacheControl),
    );
  }
}

/// Keeps decoded avatar bitmaps alive across the shared `ImageCache`'s LRU.
///
/// A bitmap whose widget unmounts moves to the 100 MB LRU, where a few screens
/// of attachments push it out; the avatar then reloads and flickers on the
/// next visit. This is an LRU of owned completers (bounded by count and by the
/// estimated decoded size): while one is held, the sized provider hands it back
/// from `loadImage`, so a remount after an `ImageCache` eviction is answered
/// synchronously with the already decoded image and no new request or decode.
class RaftHotImages {
  RaftHotImages({
    this.maxEntries = defaultMaxEntries,
    this.maxBytes = defaultMaxBytes,
  });

  /// Decoded avatar bitmaps held: count and estimated size (the app's memory
  /// budget table, `RaftMemoryBudgets`, lists them).
  static const defaultMaxEntries = 384;
  static const defaultMaxBytes = 24 * 1024 * 1024;

  static final RaftHotImages instance = RaftHotImages();

  final int maxEntries, maxBytes;
  final _held =
      LinkedHashMap<
        Object,
        ({
          ImageStreamCompleter completer,
          ImageStreamCompleterHandle handle,
          int bytes,
        })
      >();
  var _bytes = 0;

  int get length => _held.length;
  int get estimatedBytes => _bytes;
  bool holds(Object key) => _held.containsKey(key);

  /// The held completer for [key], marked most recently used.
  ImageStreamCompleter? completerFor(Object key) {
    final entry = _held.remove(key);
    if (entry == null) return null;
    _held[key] = entry;
    return entry.completer;
  }

  /// Marks [key] most recently used when it is held.
  void touch(Object key) => completerFor(key);

  /// Holds [completer] under [key].
  void hold(Object key, ImageStreamCompleter completer, int estimatedBytes) {
    release(key);
    _held[key] = (
      completer: completer,
      handle: completer.keepAlive(),
      bytes: estimatedBytes,
    );
    _bytes += estimatedBytes;
    while (_held.length > maxEntries ||
        (_bytes > maxBytes && _held.length > 1)) {
      release(_held.keys.first);
    }
  }

  /// Lets go of every held image whose key satisfies [test] and evicts it from
  /// the shared `ImageCache` (a picture that changed under its URL).
  void releaseWhere(bool Function(Object key) test) {
    final cache = PaintingBinding.instance.imageCache;
    for (final key in _held.keys.where(test).toList()) {
      cache.evict(key, includeLive: false);
      release(key);
    }
  }

  /// Lets go of [key] (evicted by the LRU, or its image failed to load).
  void release(Object key) {
    final entry = _held.remove(key);
    if (entry == null) return;
    _bytes -= entry.bytes;
    entry.handle.dispose();
  }

  /// Memory pressure: keep only the [maxEntries] most recently used avatars
  /// (and at most [maxBytes]); a handful of 36 dp bitmaps is a few hundred KB.
  /// Android reports the app going to the background as memory pressure, and
  /// dropping every avatar then is what makes them reload on return.
  void trimTo({int maxEntries = 64, int maxBytes = 4 * 1024 * 1024}) {
    while (_held.length > maxEntries ||
        (_bytes > maxBytes && _held.length > 1)) {
      release(_held.keys.first);
    }
  }

  /// "Clear cache": lets go of everything held and also evicts those images
  /// from the shared `ImageCache` (live entries too), so the next mount
  /// resolves again from [RaftImageBytes]. Avatars an on-screen widget shows
  /// stay until it unmounts.
  void evictAll() {
    final cache = PaintingBinding.instance.imageCache;
    for (final key in _held.keys.toList()) {
      cache.evict(key, includeLive: true);
    }
    releaseAll();
  }

  /// Lets go of everything; images that are on screen stay alive through
  /// their own listeners.
  void releaseAll() {
    for (final entry in _held.values) {
      entry.handle.dispose();
    }
    _held.clear();
    _bytes = 0;
  }
}

@immutable
class RaftAvatarImageKey {
  const RaftAvatarImageKey(this.stable, [this.revision = 0]);
  final String stable;

  /// [RaftImageBytes.revisionOf]: a picture that changed under the same URL
  /// is another decode, the old one is never shown for it.
  final int revision;
  @override
  bool operator ==(Object other) =>
      other is RaftAvatarImageKey &&
      other.stable == stable &&
      other.revision == revision;
  @override
  int get hashCode => Object.hash(stable, revision);
}

/// The one provider for avatar / icon URLs. Wrap it with [raftSizedImage]
/// (or use `RaftSizedImage.avatar`) so the decode is display-sized.
@immutable
class RaftAvatarImageProvider extends ImageProvider<RaftAvatarImageKey> {
  RaftAvatarImageProvider(this.url, {RaftImageBytes? bytes})
    : _bytes = bytes,
      stable = raftStableImageKey(url);

  /// Fetched exactly as given (it may be signed); not part of the identity.
  final String url;

  /// The cache identity ([raftStableImageKey]).
  final String stable;
  final RaftImageBytes? _bytes;

  /// The byte service this provider loads through.
  RaftImageBytes get service => _bytes ?? RaftImageBytes.instance;

  @override
  Future<RaftAvatarImageKey> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(RaftAvatarImageKey(stable, service.revisionOf(stable)));

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    RaftAvatarImageKey key,
    ImageErrorListener handleError,
  ) {
    super.resolveStreamForKey(configuration, stream, key, handleError);
    service.noteUse(url);
  }

  @override
  ImageStreamCompleter loadImage(
    RaftAvatarImageKey key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _codec(decode),
    scale: 1.0,
    debugLabel: 'avatar ${key.stable}',
  );

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async {
    final bytes = await service.load(url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is RaftAvatarImageProvider && other.stable == stable;
  @override
  int get hashCode => stable.hashCode;
  @override
  String toString() => 'RaftAvatarImageProvider($stable)';
}
