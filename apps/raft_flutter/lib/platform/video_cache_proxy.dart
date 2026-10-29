import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// What a `Range` request header asks for, once resolved against the length
/// of the representation (RFC 9110 section 14).
sealed class RangeRequest {
  const RangeRequest();
}

/// No usable range: answer 200 with the whole representation. Covers a
/// missing header, another unit, several ranges and a malformed spec (all of
/// which a server may ignore).
class FullRange extends RangeRequest {
  const FullRange();
}

/// Answer 206 with bytes [start] to [end], both inclusive and inside the
/// representation.
class SliceRange extends RangeRequest {
  const SliceRange(this.start, this.end);
  final int start, end;
  int get length => end - start + 1;

  @override
  bool operator ==(Object other) =>
      other is SliceRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => 'SliceRange($start-$end)';
}

/// Answer 416 with `Content-Range: bytes */total`.
class UnsatisfiableRange extends RangeRequest {
  const UnsatisfiableRange();
}

/// Resolves [header] against a representation of [total] bytes.
RangeRequest parseRangeHeader(String? header, int total) {
  if (header == null) return const FullRange();
  final unit = RegExp(
    r'^\s*bytes\s*=\s*(.*?)\s*$',
    caseSensitive: false,
  ).firstMatch(header);
  if (unit == null) return const FullRange();
  final spec = unit.group(1)!;
  if (spec.contains(',')) return const FullRange();
  final parts = RegExp(r'^(\d*)\s*-\s*(\d*)$').firstMatch(spec);
  if (parts == null) return const FullRange();
  final first = parts.group(1)!, last = parts.group(2)!;
  if (first.isEmpty && last.isEmpty) return const FullRange();
  if (first.isEmpty) {
    // Suffix: the last N bytes. A length too large for an int is "all".
    final n = int.tryParse(last);
    if (n == 0 || total == 0) return const UnsatisfiableRange();
    if (n == null || n >= total) return SliceRange(0, total - 1);
    return SliceRange(total - n, total - 1);
  }
  final start = int.tryParse(first);
  if (start == null || start >= total) return const UnsatisfiableRange();
  if (last.isEmpty) return SliceRange(start, total - 1);
  final end = int.tryParse(last);
  if (end != null && end < start) return const FullRange();
  return SliceRange(start, end == null ? total - 1 : math.min(end, total - 1));
}

/// Thrown into a reader when the upstream answered with a status that is not
/// a success. Carries the status so the player sees the same one.
class VideoCacheUpstreamError implements Exception {
  const VideoCacheUpstreamError(this.status);
  final int status;
  @override
  String toString() => 'VideoCacheUpstreamError($status)';
}

class _Cancelled implements Exception {
  const _Cancelled();
  @override
  String toString() => 'cancelled';
}

class _Uncacheable implements Exception {
  const _Uncacheable();
}

/// The upstream stopped short of what it promised.
class _TransientUpstream implements Exception {
  const _TransientUpstream(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Meta {
  _Meta({
    required this.total,
    required this.contentType,
    this.etag,
    required this.ranges,
  });
  final int total;
  final String contentType;
  final String? etag;

  /// The upstream honoured a `Range` request (206). When it did not, a chunk
  /// can only be had by reading the body from its start.
  final bool ranges;

  Map<String, Object?> toJson() => {
    'total': total,
    'contentType': contentType,
    'etag': etag,
    'ranges': ranges,
  };
  static _Meta? fromJson(Object? json) {
    if (json is! Map) return null;
    final total = json['total'], type = json['contentType'];
    if (total is! int || total < 0 || type is! String) return null;
    final etag = json['etag'];
    return _Meta(
      total: total,
      contentType: type,
      etag: etag is String ? etag : null,
      ranges: json['ranges'] != false,
    );
  }
}

/// One chunk being downloaded: filled front to back, readable while it fills.
class _Download {
  _Download(this.index, this.length);
  final int index, length;
  Uint8List? _buffer;
  int filled = 0;
  Object? error;
  final _waiters = <Completer<void>>[];

  bool get complete => filled == length;
  bool get settled => complete || error != null;

  Uint8List view(int from, int to) => Uint8List.sublistView(_buffer!, from, to);

  void write(int at, Uint8List data, int from, int count) {
    final buffer = _buffer ??= Uint8List(length);
    buffer.setRange(at, at + count, data, from);
    filled = at + count;
    _wake();
  }

  void fail(Object cause) {
    if (settled) return;
    error = cause;
    _wake();
  }

  Future<void> changed() {
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _wake() {
    final waiting = List.of(_waiters);
    _waiters.clear();
    for (final waiter in waiting) {
      waiter.complete();
    }
  }
}

class _Chunk {
  _Chunk(this.hash, this.index, this.size);
  final String hash;
  final int index, size;
  int pins = 0;
  DateTime touched = DateTime.now();
}

class _Reader {
  int position = 0;

  /// A byte of the body was handed to the response: the status line is out
  /// and can no longer carry an upstream failure.
  bool wrote = false;
}

class _Entry {
  _Entry(this.key, this.hash, this.name, this.upstream, this.headers);
  final String key, hash, name;
  Uri upstream;
  Map<String, String> headers;
  _Meta? meta;
  Future<_Meta>? metaLoad;
  bool uncacheable = false;
  final inflight = <int, _Download>{};
  final sessions = <_Session>{};
  final readers = <_Reader>{};
}

/// One upstream request: a range of consecutive chunks.
class _Session {
  _Session(this.entry, this.first, this.last, this.probe);
  final _Entry entry;
  final int first;
  int last;

  /// The first request of an entry: its response tells the length, so the
  /// chunk list is only known once it arrived.
  final bool probe;
  final plan = <int, _Download>{};
  StreamSubscription<List<int>>? _subscription;
  HttpClientRequest? _request;
  bool cancelled = false;
  final finished = Completer<void>();
}

/// A loopback HTTP server that sits between a video player and the signed
/// URL of a video: the player is given `http://127.0.0.1:PORT/TOKEN/NAME` and
/// reads that exactly as it would read the real file (Range, 206, 200, HEAD),
/// while the bytes are fetched from upstream once, in fixed-size chunks, and
/// kept on disk under a size cap (least recently used chunk goes first).
///
/// Properties the design relies on:
///  * It binds 127.0.0.1 only and every path carries a random per-process
///    token; a request without it learns nothing (404).
///  * The real URL and its headers live in memory only ([register]). The cache
///    key is the caller's (the attachment id), so a re-signed URL keeps
///    its cache.
///  * A chunk reaches the disk only complete (temp file, then rename), so a
///    killed app never leaves a chunk that is read as whole.
///  * Upstream is asked for what the player asks plus at most [windowChunks]
///    of one open-ended request, and the request is dropped as soon as no
///    connected player still needs it.
///  * An upstream failure before the first byte reaches the player as the
///    same status (a 403 stays 403, so the player's own re-sign logic runs);
///    after the first byte the connection is cut, which every player reads
///    as an error. A transient failure (the connection drops, a timeout, a
///    5xx or 429 answer) is retried first, resuming where the bytes stopped.
///  * The disk is an optimisation, never a dependency: when a chunk cannot be
///    written (disk full, folder gone, no permission) it is served from memory
///    anyway, and after [maxWriteFailures] failures in a row the proxy stops
///    writing (and keeps streaming through) until [clear] or a restart.
class VideoCacheProxy {
  VideoCacheProxy({
    required this.directory,
    required this.clientFactory,
    this.maxBytes = defaultMaxBytes,
    this.chunkSize = defaultChunkSize,
    this.windowChunks = 4,
    this.readAheadChunks = 2,
    this.urlHost = '127.0.0.1',
    this.stallTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryBackoff = const Duration(milliseconds: 250),
    this.maxWriteFailures = 3,
    @visibleForTesting this.writeFile,
    @visibleForTesting this.deleteFile,
  }) : assert(chunkSize > 0 && windowChunks > 0 && readAheadChunks > 0);

  /// What the upstream sees as the client (a request made for a player, not
  /// the app's own downloads, which carry the Dart default).
  static const userAgent = 'RaftVideoCache/1';

  static const defaultMaxBytes = 500 * 1024 * 1024;
  static const defaultChunkSize = 1024 * 1024;

  final Directory directory;

  /// Builds the client for upstream requests (the app's proxy-aware one).
  final HttpClient Function() clientFactory;
  int maxBytes;
  final int chunkSize;

  /// The most chunks one upstream request covers.
  final int windowChunks;

  /// How many chunks past the one being read are kept requested: the next
  /// upstream request starts while the previous one still has this many
  /// chunks left, so the player does not wait for a round trip at every
  /// window boundary, and nothing further is fetched than the player will
  /// soon need.
  final int readAheadChunks;

  /// How often a transient upstream failure is retried (the delay doubles
  /// from [retryBackoff], plus jitter) before the request fails.
  final int maxRetries;
  final Duration retryBackoff;

  /// Consecutive failed chunk writes after which caching is suspended.
  final int maxWriteFailures;

  /// Test hooks standing in for the file system: writing a chunk's temporary
  /// file and deleting a file (to simulate a full disk or a locked file).
  final Future<void> Function(File file, Uint8List bytes)? writeFile;
  final Future<void> Function(File file)? deleteFile;

  /// The host name players are given. The socket is always bound to
  /// 127.0.0.1; `localhost` exists for platforms whose transport policy
  /// treats the name differently from the IP literal (Apple's ATS).
  final String urlHost;
  final Duration stallTimeout;

  HttpServer? _server;
  late final String _token = _newToken();
  HttpClient? _client;
  final _entries = <String, _Entry>{};
  final _byName = <String, _Entry>{};

  /// Chunks on disk, least recently used first.
  final _index = <String, _Chunk>{};
  final _perEntry = <String, int>{};
  int _bytes = 0;
  int _epoch = 0;
  final _commits = <Future<void>>{};

  /// Files that could not be deleted (held open: Windows, a virus scanner):
  /// no longer indexed, so never read, but still on disk; deleted again on
  /// the next eviction or [clear], or by the next start-up scan.
  final _undeleted = <String, int>{};
  int _writeFailures = 0;
  bool _suspended = false;

  /// What the proxy has taken from upstream and given to players, for tools
  /// and tests (the fake upstream's own counters are the proof).
  int upstreamBytes = 0, upstreamRequests = 0, servedBytes = 0;

  /// Optional timeline of requests (diagnostics for tools; never carries a
  /// URL or a token).
  void Function(String line)? trace;
  final _clock = Stopwatch()..start();
  void _trace(String text) =>
      trace?.call('${_clock.elapsedMilliseconds}ms $text');

  int get port => _server!.port;
  String get token => _token;
  bool get running => _server != null;

  /// Bytes of chunks on disk (including files waiting to be deleted).
  int get totalBytes =>
      _bytes + _undeleted.values.fold<int>(0, (sum, size) => sum + size);

  /// Called with [totalBytes] whenever it changed (a chunk stored, evicted or
  /// cleared): Settings > Storage shows the size live from it.
  void Function(int bytes)? onSizeChanged;
  int _notifiedSize = -1;
  void _notifySize() {
    final now = totalBytes;
    if (now == _notifiedSize) return;
    _notifiedSize = now;
    onSizeChanged?.call(now);
  }

  /// True once the disk stopped taking chunks (see [maxWriteFailures]) or the
  /// folder could not be opened: playback streams through, nothing is stored.
  bool get cachingSuspended => _suspended;

  /// No player is being served and no upstream request is under way (a
  /// reader ends when its player hangs up, and then its requests are
  /// cancelled).
  @visibleForTesting
  bool get isIdle =>
      _entries.values.every((e) => e.readers.isEmpty && e.sessions.isEmpty);

  static String _newToken() {
    final random = math.Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _hash(String key) =>
      sha256.convert(utf8.encode(key)).toString().substring(0, 32);

  /// Binds the socket and indexes the chunks already on disk.
  Future<void> start() async {
    if (_server != null) return;
    try {
      await directory.create(recursive: true);
      await _scan();
    } on FileSystemException {
      // No usable folder: the proxy still serves, it just does not store.
      _suspended = true;
    }
    _notifySize();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      (request) => unawaited(_serve(request)),
      onError: (Object _) {},
    );
  }

  Future<void> _scan() async {
    final found = <(DateTime, _Chunk)>[];
    await for (final folder in directory.list(followLinks: false)) {
      if (folder is! Directory) continue;
      final hash = folder.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      await for (final file in folder.list(followLinks: false)) {
        if (file is! File) continue;
        final name = file.uri.pathSegments.last;
        if (name.endsWith('.tmp')) {
          await _delete(file, 0);
          continue;
        }
        if (!name.endsWith('.chunk')) continue;
        final index = int.tryParse(name.substring(0, name.length - 6));
        if (index == null) continue;
        final stat = await file.stat();
        found.add((stat.modified, _Chunk(hash, index, stat.size)));
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (modified, chunk) in found) {
      chunk.touched = modified;
      _index['${chunk.hash}/${chunk.index}'] = chunk;
      _bytes += chunk.size;
      _perEntry[chunk.hash] = (_perEntry[chunk.hash] ?? 0) + 1;
    }
    await _evict();
  }

  /// Registers (or re-registers, with a freshly signed URL) a video and
  /// returns the URL the player is to open. [cacheKey] identifies the content
  /// and must not change when the signature does.
  Uri register(
    String cacheKey,
    Uri upstream, {
    Map<String, String> headers = const {},
  }) {
    final server = _server;
    if (server == null) throw StateError('VideoCacheProxy.start() not called');
    final existing = _entries[cacheKey];
    if (existing != null) {
      existing
        ..upstream = upstream
        ..headers = Map.of(headers);
      return _urlFor(existing);
    }
    final dot = upstream.path.lastIndexOf('.');
    final extension = dot >= 0 && upstream.path.length - dot <= 6
        ? upstream.path.substring(dot).toLowerCase()
        : '';
    final hash = _hash(cacheKey);
    final entry = _Entry(
      cacheKey,
      hash,
      '${hash.substring(0, 16)}${RegExp(r'^\.[a-z0-9]+$').hasMatch(extension) ? extension : ''}',
      upstream,
      Map.of(headers),
    );
    _entries[cacheKey] = entry;
    _byName[entry.name] = entry;
    return _urlFor(entry);
  }

  Uri _urlFor(_Entry entry) => Uri(
    scheme: 'http',
    host: urlHost,
    port: _server!.port,
    pathSegments: [_token, entry.name],
  );

  /// Forgets the registration of [cacheKey] (its chunks stay cached).
  void unregister(String cacheKey) {
    final entry = _entries.remove(cacheKey);
    if (entry == null) return;
    _byName.remove(entry.name);
    for (final session in List.of(entry.sessions)) {
      _cancel(session);
    }
  }

  /// Deletes every cached chunk and drops what is in flight (sign-out,
  /// account switch, the Settings button).
  Future<void> clear() async {
    _epoch++;
    for (final entry in _entries.values) {
      for (final session in List.of(entry.sessions)) {
        _cancel(session);
      }
      entry.meta = null;
      entry.metaLoad = null;
      entry.uncacheable = false;
    }
    await Future.wait(List.of(_commits));
    _index.clear();
    _perEntry.clear();
    _bytes = 0;
    _undeleted.clear();
    // Whatever stopped the disk may be gone now (the user freed space): the
    // next chunk tries again.
    _writeFailures = 0;
    _suspended = false;
    if (await directory.exists()) {
      await for (final item in directory.list(followLinks: false)) {
        await _deleteTree(item);
      }
    }
    _notifySize();
  }

  /// Deletes [item] (a chunk folder), trying again when something holds a
  /// file open for a moment. What stays is remembered in [_undeleted] (and
  /// counted in [totalBytes]) and is tried again later.
  Future<void> _deleteTree(FileSystemEntity item) async {
    for (var attempt = 0; attempt < _deleteAttempts; attempt++) {
      try {
        await item.delete(recursive: true);
        return;
      } on PathNotFoundException {
        return;
      } on FileSystemException {
        await Future<void>.delayed(_deleteDelay * (1 << attempt));
      }
    }
    try {
      await for (final file in Directory(item.path).list(recursive: true)) {
        if (file is File) _undeleted[file.path] = await file.length();
      }
    } on FileSystemException {
      // Unreadable too: the start-up scan sorts it out.
    }
  }

  static const _deleteAttempts = 3;
  static const _deleteDelay = Duration(milliseconds: 40);

  /// Completes when the chunks received so far are on disk and accounted
  /// for (they are written after they were served).
  Future<void> flushWrites() async {
    while (_commits.isNotEmpty) {
      await Future.wait(List.of(_commits));
    }
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    for (final entry in _entries.values) {
      for (final session in List.of(entry.sessions)) {
        _cancel(session);
      }
    }
    await server?.close(force: true);
    _client?.close(force: true);
    _client = null;
    await Future.wait(List.of(_commits));
  }

  // --- serving ---------------------------------------------------------

  bool _tokenMatches(String given) {
    final a = utf8.encode(given), b = utf8.encode(_token);
    var diff = a.length ^ b.length;
    for (var i = 0; i < b.length; i++) {
      diff |= (i < a.length ? a[i] : 0) ^ b[i];
    }
    return diff == 0;
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    final reader = _Reader();
    try {
      final segments = request.uri.pathSegments;
      if (segments.length != 2 || !_tokenMatches(segments[0])) {
        return await _reply(response, HttpStatus.notFound);
      }
      final entry = _byName[segments[1]];
      if (entry == null) return await _reply(response, HttpStatus.notFound);
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        return await _reply(response, HttpStatus.methodNotAllowed);
      }
      _trace(
        '${request.method} ${entry.name} '
        'range=${request.headers.value(HttpHeaders.rangeHeader)}',
      );
      if (entry.uncacheable) return await _passThrough(entry, request);
      final _Meta meta;
      try {
        meta = await _ensureMeta(entry);
      } on _Uncacheable {
        entry.uncacheable = true;
        return await _passThrough(entry, request);
      } on VideoCacheUpstreamError catch (error) {
        return await _reply(response, _playerStatus(error.status));
      } on Object {
        return await _reply(response, HttpStatus.badGateway);
      }
      _trace('  meta ready total=${meta.total}');
      final range = parseRangeHeader(
        request.headers.value(HttpHeaders.rangeHeader),
        meta.total,
      );
      response.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader, meta.contentType);
      if (range is UnsatisfiableRange) {
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${meta.total}',
        );
        return await _reply(response, HttpStatus.requestedRangeNotSatisfiable);
      }
      final (start, end) = switch (range) {
        SliceRange(:final start, :final end) => (start, end),
        _ => (0, meta.total - 1),
      };
      final length = meta.total == 0 ? 0 : end - start + 1;
      if (range is SliceRange) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${meta.total}',
        );
      }
      response.contentLength = length;
      if (request.method == 'HEAD' || length == 0) {
        await response.close();
        return;
      }
      await _stream(entry, meta, request, reader, start, end);
    } on Object catch (error) {
      if (!reader.wrote) {
        // Nothing is out yet: the player gets the upstream's own status (a
        // 403 stays a 403) or a 502.
        try {
          response.headers.clear();
          await _reply(
            response,
            error is VideoCacheUpstreamError
                ? _playerStatus(error.status)
                : HttpStatus.badGateway,
          );
          return;
        } on Object {
          // Fall through to cutting the connection.
        }
      }
      // The body could not be completed: cut the connection so a half body is
      // never taken for a whole one.
      // Closing with fewer bytes than the Content-Length makes dart:io drop
      // the connection (the one way left once the headers are out).
      try {
        await response.close();
      } on Object {
        // Dropped, as intended.
      }
    }
  }

  static int _playerStatus(int upstream) =>
      upstream >= 400 && upstream < 500 && upstream != 416
      ? upstream
      : HttpStatus.badGateway;

  Future<void> _reply(HttpResponse response, int status) async {
    response.statusCode = status;
    response.contentLength = 0;
    await response.close();
  }

  Future<void> _stream(
    _Entry entry,
    _Meta meta,
    HttpRequest request,
    _Reader reader,
    int start,
    int end,
  ) async {
    final response = request.response;
    entry.readers.add(reader);
    var gone = false;
    unawaited(
      response.done
          .then((_) {}, onError: (Object _) {})
          .whenComplete(() => gone = true),
    );
    // `response.done` is not enough: when the player hangs up, dart:io
    // destroys the socket, and `done` then completes only if a write was in
    // flight at that moment; later writes to the dead socket succeed without
    // an error. The reader would go on serving nobody, and the upstream
    // sessions behind it (the whole file for an open-ended Range) would run
    // on. A destroyed socket has no [HttpResponse.connectionInfo]; the first
    // write after the hang-up is what destroys it, so this is checked
    // wherever the reader writes.
    bool hungUp() => gone || response.connectionInfo == null;
    final firstChunk = start ~/ chunkSize, lastChunk = end ~/ chunkSize;
    final chunks = (meta.total + chunkSize - 1) ~/ chunkSize;
    try {
      for (var i = firstChunk; i <= lastChunk; i++) {
        if (hungUp()) throw const _Cancelled();
        reader.position = i;
        _reap(entry);
        final chunkStart = i * chunkSize;
        final length = math.min(chunkSize, meta.total - chunkStart);
        final from = math.max(start, chunkStart) - chunkStart;
        final to = math.min(end, chunkStart + length - 1) - chunkStart;
        // This chunk first: a request for it covers the following chunks too,
        // and the read-ahead below must not cut that window short.
        if (!_onDisk(entry, i) && !entry.inflight.containsKey(i)) {
          _download(entry, meta, i, lastChunk, chunks);
        }
        // Read-ahead: the next [readAheadChunks] chunks are kept requested
        // while this one is consumed, so a window boundary costs the player
        // no round trip (never past what the player asked for).
        final ahead = math.min(i + readAheadChunks, lastChunk);
        for (var c = i + 1; c <= ahead; c++) {
          if (entry.inflight.containsKey(c) || _onDisk(entry, c)) continue;
          _download(entry, meta, c, lastChunk, chunks);
          break;
        }
        var at = from;
        if (_onDisk(entry, i)) {
          at = await _sendFromDisk(
            entry,
            i,
            length,
            from,
            to,
            response,
            reader,
          );
          if (at > to) continue;
        }
        final download =
            entry.inflight[i] ?? _download(entry, meta, i, lastChunk, chunks);
        while (at <= to) {
          if (hungUp()) throw const _Cancelled();
          final error = download.error;
          if (error != null) throw error;
          final available = math.min(download.filled, to + 1);
          if (available > at) {
            reader.wrote = true;
            response.add(download.view(at, available));
            servedBytes += available - at;
            at = available;
            await _flush(response);
          } else {
            await download.changed().timeout(stallTimeout);
          }
        }
      }
      await response.close();
    } finally {
      entry.readers.remove(reader);
      _reap(entry);
    }
  }

  /// `response.flush()`, ended by [_Cancelled] when the player hangs up
  /// meanwhile: dart:io then never completes a flush that was waiting for the
  /// player to read (nor fails it). The socket is destroyed at once, which
  /// [HttpResponse.connectionInfo] shows.
  static Future<void> _flush(HttpResponse response) async {
    final flushed = response.flush();
    while (true) {
      try {
        await flushed.timeout(const Duration(milliseconds: 250));
        return;
      } on TimeoutException {
        if (response.connectionInfo == null) throw const _Cancelled();
      }
    }
  }

  bool _onDisk(_Entry entry, int index) =>
      _index.containsKey('${entry.hash}/$index');

  File _file(String hash, int index) =>
      File('${directory.path}/$hash/$index.chunk');

  /// Writes bytes [from] to [to] (inclusive) of chunk [index] from disk.
  /// Returns the offset in the chunk the rest must come from the network from:
  /// `to + 1` when everything was sent, [from] when the chunk is not (or no
  /// longer) there, and in between when the file stopped being readable
  /// part-way (the bytes already sent are not sent twice).
  Future<int> _sendFromDisk(
    _Entry entry,
    int index,
    int length,
    int from,
    int to,
    HttpResponse response,
    _Reader reader,
  ) async {
    final key = '${entry.hash}/$index';
    final chunk = _index[key];
    if (chunk == null) return from;
    chunk.pins++;
    RandomAccessFile? file;
    var at = from;
    try {
      try {
        file = await _file(entry.hash, index).open();
        if (await file.length() != length) {
          await file.close();
          file = null;
          await _drop(key);
          return from;
        }
      } on FileSystemException {
        await _drop(key);
        return from;
      }
      _touch(key, chunk);
      await file.setPosition(from);
      while (at <= to) {
        final List<int> piece;
        try {
          piece = await file.read(math.min(to - at + 1, 256 * 1024));
          if (piece.isEmpty) throw const FileSystemException('short chunk');
        } on FileSystemException {
          // The file went bad under us: forget it, the network has the rest.
          await _drop(key);
          return at;
        }
        if (response.connectionInfo == null) throw const _Cancelled();
        reader.wrote = true;
        response.add(piece);
        servedBytes += piece.length;
        at += piece.length;
        await _flush(response);
      }
      return at;
    } finally {
      chunk.pins--;
      await file?.close();
    }
  }

  void _touch(String key, _Chunk chunk) {
    _index
      ..remove(key)
      ..[key] = chunk;
    final now = DateTime.now();
    // The order lives in memory; the file time is only what the next start-up
    // scan sorts by, so it is refreshed rarely.
    if (now.difference(chunk.touched) > const Duration(minutes: 5)) {
      chunk.touched = now;
      unawaited(
        _file(
          chunk.hash,
          chunk.index,
        ).setLastModified(now).then((_) {}, onError: (Object _) {}),
      );
    }
  }

  // --- metadata --------------------------------------------------------

  Future<_Meta> _ensureMeta(_Entry entry) {
    final known = entry.meta;
    if (known != null) return Future.value(known);
    return entry.metaLoad ??= _loadMeta(entry)
        .whenComplete(() => entry.metaLoad = null);
  }

  File _metaFile(String hash) => File('${directory.path}/$hash/meta.json');

  Future<_Meta> _loadMeta(_Entry entry) async {
    // A previous run's length, used only when some chunk of it is still here,
    // so a vanished cache does not keep a stale length.
    if ((_perEntry[entry.hash] ?? 0) > 0) {
      try {
        final text = await _metaFile(entry.hash).readAsString();
        final meta = _Meta.fromJson(jsonDecode(text));
        if (meta != null) return entry.meta = meta;
      } on Object {
        // Probe again below.
      }
    }
    final session = _Session(entry, 0, 0, true);
    entry.sessions.add(session);
    unawaited(_run(session));
    await session.finished.future;
    return entry.meta!;
  }

  Future<void> _storeMeta(_Entry entry, _Meta meta) async {
    if (_suspended) return;
    final epoch = _epoch;
    try {
      final folder = Directory('${directory.path}/${entry.hash}');
      await folder.create(recursive: true);
      if (epoch != _epoch) return;
      await _metaFile(entry.hash).writeAsString(jsonEncode(meta.toJson()));
    } on Object {
      // Memory still has it.
    }
  }

  // --- downloading -----------------------------------------------------

  /// The download of chunk [index] (starting an upstream request for it and
  /// up to [windowChunks] - 1 chunks after it, never past [limit], never over
  /// a chunk that is already here or on its way).
  _Download _download(
    _Entry entry,
    _Meta meta,
    int index,
    int limit,
    int chunks,
  ) {
    var last = math.min(math.min(index + windowChunks - 1, limit), chunks - 1);
    for (var c = index + 1; c <= last; c++) {
      if (entry.inflight.containsKey(c) || _onDisk(entry, c)) {
        last = c - 1;
        break;
      }
    }
    final session = _Session(entry, index, last, false);
    for (var c = index; c <= last; c++) {
      final length = math.min(chunkSize, meta.total - c * chunkSize);
      final download = _Download(c, length);
      session.plan[c] = download;
      entry.inflight[c] = download;
    }
    entry.sessions.add(session);
    unawaited(_run(session));
    return session.plan[index]!;
  }

  /// A session no connected player will reach is dropped.
  void _reap(_Entry entry) {
    if (entry.meta == null) return;
    for (final session in List.of(entry.sessions)) {
      final wanted = entry.readers.any((r) => r.position <= session.last);
      if (!wanted) _cancel(session);
    }
  }

  void _cancel(_Session session) {
    if (session.cancelled) return;
    session.cancelled = true;
    unawaited(session._subscription?.cancel());
    session._request?.abort();
    _settle(session, const _Cancelled());
  }

  /// Ends [session]: [error] null means it delivered everything it planned.
  void _settle(_Session session, Object? error) {
    final entry = session.entry;
    for (final download in session.plan.values) {
      if (!download.complete) {
        download.fail(
          error ?? const FormatException('upstream body too short'),
        );
        if (identical(entry.inflight[download.index], download)) {
          entry.inflight.remove(download.index);
        }
      }
    }
    entry.sessions.remove(session);
    if (session.finished.isCompleted) return;
    // Only the probe has a waiter; its failure is the caller's failure.
    if (session.probe && error != null) {
      session.finished.completeError(error);
    } else {
      session.finished.complete();
    }
  }

  HttpClient get _http {
    final client = _client ??= clientFactory();
    return client;
  }

  /// Runs [session] to its end. A transient failure (see [_transient]) is
  /// retried with a growing pause, resuming at the first byte that is still
  /// missing, so a flaky network costs the player a short wait instead of an
  /// error. Any other failure, and running out of retries, ends the session
  /// with that error.
  Future<void> _run(_Session session) async {
    final epoch = _epoch;
    for (var attempt = 0; ; attempt++) {
      try {
        await _attempt(session, epoch);
        return;
      } on Object catch (error) {
        if (session.cancelled) {
          _settle(session, const _Cancelled());
          return;
        }
        if (attempt >= maxRetries || !_transient(error)) {
          _settle(session, error);
          return;
        }
        _trace('  upstream retry ${attempt + 1} after ${error.runtimeType}');
        final base = retryBackoff.inMilliseconds * (1 << attempt);
        await Future<void>.delayed(
          Duration(milliseconds: base + _jitter.nextInt(base ~/ 4 + 1)),
        );
        if (session.cancelled) {
          _settle(session, const _Cancelled());
          return;
        }
      }
    }
  }

  final _jitter = math.Random();

  /// Failures worth another try: the connection or the body broke, the server
  /// timed out, was busy or briefly broken. A 4xx answer (an expired
  /// signature above all) is final and goes to the player at once.
  static bool _transient(Object error) => switch (error) {
    _TransientUpstream() ||
    SocketException() ||
    HttpException() ||
    TimeoutException() => true,
    VideoCacheUpstreamError(:final status) =>
      status == 408 || status == 429 || (status >= 500 && status <= 504),
    _ => false,
  };

  /// One request to the upstream for what [session] still lacks.
  Future<void> _attempt(_Session session, int epoch) async {
    final entry = session.entry;
    upstreamRequests++;
    final meta = entry.meta;
    final request = await _http.getUrl(entry.upstream).timeout(stallTimeout);
    session._request = request;
    if (session.cancelled) {
      request.abort();
      return;
    }
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    entry.headers.forEach(request.headers.set);
    if (meta == null) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${chunkSize - 1}');
    } else if (meta.ranges) {
      // From the first byte not yet received (the start of the session
      // unless an earlier attempt of it got part-way).
      var from = session.first * chunkSize;
      for (final download in session.plan.values) {
        if (!download.complete) {
          from = download.index * chunkSize + download.filled;
          break;
        }
      }
      final to = math.min((session.last + 1) * chunkSize, meta.total) - 1;
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-$to');
    }
    _trace('  upstream GET ${request.headers.value(HttpHeaders.rangeHeader)}');
    final response = await request.close().timeout(stallTimeout);
    _trace('  upstream answered ${response.statusCode}');
    if (session.cancelled) {
      unawaited(response.listen((_) {}).cancel());
      return;
    }
    final status = response.statusCode;
    if (meta == null &&
        status == HttpStatus.requestedRangeNotSatisfiable &&
        session.probe) {
      // An empty file: nothing satisfies bytes=0-.
      final empty = RegExp(
        r'^bytes\s+\*/0$',
      ).hasMatch(response.headers.value(HttpHeaders.contentRangeHeader) ?? '');
      unawaited(response.drain<void>().then((_) {}, onError: (Object _) {}));
      if (empty) {
        final known = _newMeta(response, 0, true);
        entry.meta = known;
        unawaited(_storeMeta(entry, known));
        _settle(session, null);
        return;
      }
    }
    if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
      unawaited(response.drain<void>().then((_) {}, onError: (Object _) {}));
      throw VideoCacheUpstreamError(status);
    }
    var offset = 0;
    var known = meta;
    if (status == HttpStatus.partialContent) {
      final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+)$').firstMatch(
        response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
      );
      if (match == null) throw const FormatException('bad Content-Range');
      offset = int.parse(match.group(1)!);
      known ??= _newMeta(response, int.parse(match.group(3)!), true);
    } else {
      // The upstream ignored Range: the body is the whole file.
      if (response.contentLength < 0) {
        if (meta == null) throw const _Uncacheable();
        throw const FormatException('unsized body');
      }
      known ??= _newMeta(response, response.contentLength, false);
    }
    final etag = response.headers.value(HttpHeaders.etagHeader);
    if (meta != null &&
        (meta.total != known.total ||
            (meta.etag != null && etag != null && meta.etag != etag))) {
      // The content under this key changed: nothing cached is valid.
      await _purge(entry);
      throw const FormatException('content changed');
    }
    if (meta == null) {
      entry.meta = known;
      unawaited(_storeMeta(entry, known));
      if (session.probe) {
        // The probe's own chunk is created now that the length is known.
        final chunks = (known.total + chunkSize - 1) ~/ chunkSize;
        if (chunks > 0 &&
            !_onDisk(entry, 0) &&
            !entry.inflight.containsKey(0)) {
          final download = _Download(0, math.min(chunkSize, known.total));
          session.plan[0] = download;
          entry.inflight[0] = download;
        }
      }
    }
    if (session.plan.isEmpty) {
      unawaited(response.listen((_) {}).cancel());
      _settle(session, null);
      return;
    }
    await _consume(session, response, offset, known, epoch);
    _settle(session, null);
  }

  _Meta _newMeta(HttpClientResponse response, int total, bool ranges) {
    final type = response.headers.contentType?.toString();
    return _Meta(
      total: total,
      contentType: type == null || type.isEmpty
          ? 'application/octet-stream'
          : type,
      etag: response.headers.value(HttpHeaders.etagHeader),
      ranges: ranges,
    );
  }

  Future<void> _consume(
    _Session session,
    HttpClientResponse response,
    int offsetStart,
    _Meta meta,
    int epoch,
  ) {
    final entry = session.entry;
    final done = Completer<void>();
    var offset = offsetStart;
    var remaining = session.plan.values.where((d) => !d.complete).length;
    late final StreamSubscription<List<int>> subscription;
    subscription = response
        .timeout(stallTimeout)
        .listen(
          (data) {
            final bytes = data is Uint8List ? data : Uint8List.fromList(data);
            if (upstreamBytes == 0 || offset == offsetStart) {
              _trace('  upstream first bytes of session at $offset');
            }
            upstreamBytes += bytes.length;
            var at = 0;
            while (at < bytes.length) {
              final c = offset ~/ chunkSize;
              final chunkStart = c * chunkSize;
              final length = math.min(chunkSize, meta.total - chunkStart);
              if (length <= 0) break;
              final within = offset - chunkStart;
              final take = math.min(bytes.length - at, length - within);
              final download = session.plan[c];
              if (download != null &&
                  !download.complete &&
                  download.error == null) {
                download.write(within, bytes, at, take);
                if (download.complete) {
                  remaining--;
                  _commit(entry, download, epoch);
                }
              }
              offset += take;
              at += take;
            }
            if (remaining <= 0 && !done.isCompleted) {
              // Everything asked for is here; the rest of the body (a server that
              // ignored the range) is not read.
              unawaited(subscription.cancel());
              done.complete();
            }
          },
          onError: (Object error) {
            if (!done.isCompleted) done.completeError(error);
          },
          onDone: () {
            if (done.isCompleted) return;
            if (remaining > 0) {
              done.completeError(
                const _TransientUpstream('upstream body too short'),
              );
            } else {
              done.complete();
            }
          },
          cancelOnError: true,
        );
    session._subscription = subscription;
    return done.future;
  }

  /// Chunks are written one at a time, in the order they completed: the disk
  /// is slower than the network only when something is wrong with it, and a
  /// run of failures must be noticed before more writes are started.
  Future<void> _writeTail = Future.value();

  void _commit(_Entry entry, _Download download, int epoch) {
    final write = _writeTail.then((_) => _writeChunk(entry, download, epoch));
    _writeTail = write;
    _commits.add(write);
    unawaited(
      write.whenComplete(() {
        _commits.remove(write);
        if (identical(entry.inflight[download.index], download)) {
          entry.inflight.remove(download.index);
        }
      }),
    );
  }

  Future<void> _writeChunk(_Entry entry, _Download download, int epoch) async {
    if (_suspended) return;
    final key = '${entry.hash}/${download.index}';
    final target = _file(entry.hash, download.index);
    final temporary = File('${target.path}.tmp');
    try {
      final folder = Directory('${directory.path}/${entry.hash}');
      if (!await folder.exists()) await folder.create(recursive: true);
      final bytes = download.view(0, download.length);
      await (writeFile?.call(temporary, bytes) ??
          temporary.writeAsBytes(bytes, flush: false));
      if (epoch != _epoch) {
        await _delete(temporary, 0);
        return;
      }
      _undeleted.remove(target.path);
      await temporary.rename(target.path);
    } on Object {
      // The disk did not take the chunk (full, folder gone, no permission):
      // it was served from memory this time and playback is not affected.
      // After several failures in a row the proxy stops trying.
      await _delete(temporary, 0);
      if (++_writeFailures >= maxWriteFailures) _suspended = true;
      return;
    }
    _writeFailures = 0;
    final previous = _index.remove(key);
    if (previous != null) _bytes -= previous.size;
    _index[key] = _Chunk(entry.hash, download.index, download.length);
    _bytes += download.length;
    _perEntry[entry.hash] =
        (_perEntry[entry.hash] ?? 0) + (previous == null ? 1 : 0);
    try {
      await _evict();
    } on Object {
      // Eviction is housekeeping; the next chunk tries again.
    }
    _notifySize();
  }

  Future<void> _purge(_Entry entry) async {
    _epoch++;
    entry.meta = null;
    final keys = _index.keys
        .where((k) => k.startsWith('${entry.hash}/'))
        .toList();
    for (final key in keys) {
      await _drop(key);
    }
    await _delete(_metaFile(entry.hash), 0);
  }

  Future<void> _evict() async {
    await _retryUndeleted();
    if (totalBytes <= maxBytes) return;
    for (final key in _index.keys.toList()) {
      if (totalBytes <= maxBytes) break;
      final chunk = _index[key]!;
      if (chunk.pins > 0) continue;
      await _drop(key);
    }
  }

  Future<void> _retryUndeleted() async {
    for (final path in _undeleted.keys.toList()) {
      await _delete(File(path), _undeleted[path] ?? 0);
    }
  }

  Future<void> _drop(String key) async {
    final chunk = _index.remove(key);
    if (chunk == null) return;
    _bytes -= chunk.size;
    await _delete(_file(chunk.hash, chunk.index), chunk.size);
    final left = (_perEntry[chunk.hash] ?? 1) - 1;
    if (left <= 0) {
      _perEntry.remove(chunk.hash);
      try {
        await Directory('${directory.path}/${chunk.hash}')
            .delete(recursive: true);
      } on FileSystemException {
        // Something is still being written there, or a file waits in
        // [_undeleted].
      }
    } else {
      _perEntry[chunk.hash] = left;
    }
    _notifySize();
  }

  /// Deletes [file] (of [size] bytes), trying again for a moment when it is
  /// held open. A file that stays is kept in [_undeleted]: out of the index so
  /// nobody reads it, in [totalBytes] because it still takes space.
  Future<void> _delete(File file, int size) async {
    for (var attempt = 0; attempt < _deleteAttempts; attempt++) {
      try {
        await (deleteFile?.call(file) ?? file.delete());
        _undeleted.remove(file.path);
        return;
      } on PathNotFoundException {
        _undeleted.remove(file.path);
        return;
      } on FileSystemException {
        if (attempt + 1 < _deleteAttempts) {
          await Future<void>.delayed(_deleteDelay * (1 << attempt));
        }
      }
    }
    _undeleted[file.path] = size;
  }

  // --- uncacheable upstream -------------------------------------------

  /// An upstream that ignores Range and gives no length cannot be cached by
  /// chunks: the request is forwarded as it is.
  Future<void> _passThrough(_Entry entry, HttpRequest request) async {
    final response = request.response;
    final upstream = await _http.getUrl(entry.upstream);
    upstream.headers.set(HttpHeaders.userAgentHeader, userAgent);
    entry.headers.forEach(upstream.headers.set);
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) upstream.headers.set(HttpHeaders.rangeHeader, range);
    final answer = await upstream.close();
    response.statusCode = answer.statusCode;
    for (final name in [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
    ]) {
      final value = answer.headers.value(name);
      if (value != null) response.headers.set(name, value);
    }
    if (request.method == 'HEAD') {
      await answer.drain<void>();
      await response.close();
      return;
    }
    await response.addStream(answer);
    await response.close();
  }
}
