import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:raft_client/system_proxy.dart';

import 'attachment_player.dart';
import 'video_cache_proxy.dart';

/// The kill switch of the on-disk video cache. `false` and every player gets
/// the signed URL directly, as before the cache existed. Tests and tools flip
/// it per run with [VideoCache.debugEnabled]; there is no build flag.
const bool kVideoCacheEnabled = true;

/// How long opening a video waits for the cache to be ready (the first video
/// of a run starts the proxy: the app's cache folder is resolved, the account
/// folder indexed, a socket bound). Past it the video plays from the network as
/// it would without a cache and the cache is there for the next one: the cache
/// never holds up a first frame.
const Duration kVideoCacheStartBudget = Duration(milliseconds: 250);

/// How much video one account may keep on this device.
const int kVideoCacheMaxBytes = 500 * 1024 * 1024;

/// Whose videos a cache holds: one signed-in user on one server origin. The
/// cache of one account is a folder of its own, never shared with another, and
/// goes away with the account (sign-out, account switch).
@immutable
class VideoCacheAccount {
  /// [origin] is the API origin the session belongs to (a trailing slash is
  /// not part of it), [principal] the user id.
  VideoCacheAccount(String origin, this.principal)
    : origin = origin.replaceFirst(RegExp(r'/$'), '');

  final String origin, principal;

  /// The folder name: a hash of both, so neither the server nor the user id
  /// shows in a file name. Same scheme as the attachment disk cache's account
  /// folders.
  String get segment => segmentOf(origin, principal);

  static String segmentOf(String origin, String principal) => sha256
      .convert(
        utf8.encode(
          jsonEncode([origin.replaceFirst(RegExp(r'/$'), ''), principal]),
        ),
      )
      .toString()
      .substring(0, 40);

  @override
  bool operator ==(Object other) =>
      other is VideoCacheAccount &&
      other.origin == origin &&
      other.principal == principal;

  @override
  int get hashCode => Object.hash(origin, principal);
}

/// The on-disk cache of streamed videos, and the one place that decides
/// whether a player is handed a cached (loopback) URL.
///
/// On by default ([kVideoCacheEnabled]). Per account: every account has its
/// own folder (`<app cache>/raft-video/<account hash>`) and its own
/// [VideoCacheProxy], started lazily when that account first plays a video, so
/// nothing is bound or scanned at app start. A source without an account (a
/// local file, a caller that does not know whose it is) is never cached.
///
/// The cache is only ever an optimisation: when it cannot start, or the disk
/// fails, playback goes on from the network.
class VideoCache {
  VideoCache._();

  /// Lets tests and tools run with the cache off or on whatever
  /// [kVideoCacheEnabled] says.
  @visibleForTesting
  static bool? debugEnabled;

  static bool get enabled => debugEnabled ?? kVideoCacheEnabled;

  /// Where the account folders live (tests and tools point it elsewhere); by
  /// default `<app cache>/raft-video`.
  @visibleForTesting
  static Directory? debugRoot;

  /// Holds the start of a proxy until it completes (tests of the start budget).
  @visibleForTesting
  static Future<void>? debugStartGate;

  /// The cap in bytes per account (tests use a small one).
  @visibleForTesting
  static int? debugMaxBytes;

  /// Builds the upstream client (tests use a plain one; the app uses its
  /// proxy-aware client).
  @visibleForTesting
  static HttpClient Function()? debugClientFactory;

  /// A timeline sink for the evidence harness.
  @visibleForTesting
  static void Function(String line)? debugTrace;

  /// The running proxy of [account], if any (nothing is started).
  @visibleForTesting
  static Future<VideoCacheProxy>? debugRunning(VideoCacheAccount account) =>
      _proxies[account.segment];

  /// How many proxies were started in this process (the cache starts nothing
  /// until a video is played).
  @visibleForTesting
  static int get debugStarted => _started;

  static int _started = 0;
  static final _proxies = <String, Future<VideoCacheProxy>>{};
  static final _sizes = <String, _CacheSize>{};

  static _CacheSize _sizeOf(VideoCacheAccount account) =>
      _sizes.putIfAbsent(account.segment, _CacheSize.new);

  /// The bytes [account]'s cache holds, kept current while anyone listens:
  /// null until measured, then updated as chunks are stored, evicted or
  /// cleared (Settings > Storage shows it live). Measuring reads the folder;
  /// it starts no proxy.
  static ValueListenable<int?> watchSize(VideoCacheAccount account) {
    final size = _sizeOf(account);
    unawaited(sizeBytes(account).then((_) {}, onError: (Object _) {}));
    return size;
  }

  static Future<Directory> _root() async =>
      debugRoot ??
      Directory(
        p.join((await getApplicationCacheDirectory()).path, 'raft-video'),
      );

  /// The folder of [account]'s cache (may not exist yet).
  static Future<Directory> directoryOf(VideoCacheAccount account) async =>
      Directory(p.join((await _root()).path, account.segment));

  /// The running proxy of [account], started on first use.
  static Future<VideoCacheProxy> proxy(VideoCacheAccount account) {
    final key = account.segment;
    return _proxies[key] ??= _start(account).catchError((Object error) {
      // A failed start is tried again by the next video.
      _proxies.remove(key);
      throw error;
    });
  }

  static Future<VideoCacheProxy> _start(VideoCacheAccount account) async {
    await debugStartGate;
    final proxy = VideoCacheProxy(
      directory: await directoryOf(account),
      maxBytes: debugMaxBytes ?? kVideoCacheMaxBytes,
      clientFactory:
          debugClientFactory ?? () => SystemProxy.instance.createHttpClient(),
    );
    proxy.trace = debugTrace;
    final size = _sizeOf(account);
    proxy.onSizeChanged = (bytes) => size.value = bytes;
    await proxy.start();
    _started++;
    return proxy;
  }

  /// [source] as the player is to open it: through [source]'s account's cache
  /// when the cache is on and the source is a streamed attachment that knows
  /// its account, otherwise the very same object. A failure to start the cache
  /// falls back to the direct URL.
  static Future<AttachmentSource> route(AttachmentSource source) async {
    final url = source.url;
    final account = source.cacheAccount;
    if (!enabled ||
        account == null ||
        url == null ||
        !url.scheme.startsWith('http')) {
      return source;
    }
    try {
      // Never longer than [kVideoCacheStartBudget]: a slow first start (the
      // work goes on in the background) plays this video from the network.
      final local = await _ready(
        account,
        source,
        url,
      ).timeout(kVideoCacheStartBudget);
      return AttachmentSource.network(local, start: source.start);
    } on Object catch (error) {
      debugPrint('raft.media: video cache unavailable ($error)');
      return source;
    }
  }

  static Future<Uri> _ready(
    VideoCacheAccount account,
    AttachmentSource source,
    Uri url,
  ) async {
    final proxy = await VideoCache.proxy(account);
    await SystemProxy.instance.ready(url);
    return proxy.register(
      source.cacheKey ?? _derivedKey(url),
      url,
      headers: source.headers,
    );
  }

  /// A key for a source nobody named: its URL without the query (the
  /// signature), which is stable across re-signing for path-style hosts.
  static String _derivedKey(Uri url) => '${url.host}${url.path}';

  /// Bytes of [account]'s cache on disk. Reads the folder when the proxy has
  /// not started (nothing is started for it).
  static Future<int> sizeBytes(VideoCacheAccount account) async {
    final running = _proxies[account.segment];
    if (running != null) {
      try {
        final bytes = (await running).totalBytes;
        _sizeOf(account).value = bytes;
        return bytes;
      } on Object {
        // Not running after all: count the folder.
      }
    }
    final bytes = await _folderSize(await directoryOf(account));
    _sizeOf(account).value = bytes;
    return bytes;
  }

  /// Deletes [account]'s cached videos but keeps the account (the Settings
  /// button).
  static Future<void> clear(VideoCacheAccount account) async {
    final running = _proxies[account.segment];
    if (running != null) {
      try {
        await (await running).clear();
        return;
      } on Object {
        // Not running after all: delete the folder.
      }
    }
    await _deleteFolder(await directoryOf(account));
    _sizeOf(account).value = 0;
  }

  /// Removes everything cached for [account]: stops its proxy (a player of
  /// that account in flight fails; they are closing anyway) and deletes the
  /// folder. Sign-out, a rejected session and an account switch call this.
  static Future<void> purgeAccount(String origin, String principal) async {
    final account = VideoCacheAccount(origin, principal);
    final running = _proxies.remove(account.segment);
    if (running != null) {
      try {
        await (await running).close();
      } on Object {
        // It never started; the folder is deleted below.
      }
    }
    await _deleteFolder(await directoryOf(account));
    _sizeOf(account).value = 0;
  }

  /// Removes the folders of accounts that are not in [keep]: what a sign-out
  /// or a removed session left behind while the app was not running. Never
  /// starts a proxy. Returns the number of folders removed.
  static Future<int> removeOrphanAccounts(
    Iterable<(String origin, String principal)> keep,
  ) async {
    final names = {
      for (final (origin, principal) in keep)
        VideoCacheAccount.segmentOf(origin, principal),
    };
    final root = await _root();
    if (!await root.exists()) return 0;
    var removed = 0;
    try {
      await for (final entity in root.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (names.contains(name) || _proxies.containsKey(name)) continue;
        await _deleteFolder(Directory(entity.path));
        removed++;
      }
    } on FileSystemException {
      // Housekeeping; the next start tries again.
    }
    return removed;
  }

  static Future<int> _folderSize(Directory folder) async {
    var total = 0;
    try {
      if (!await folder.exists()) return 0;
      await for (final entity in folder.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.endsWith('.chunk')) {
          total += await entity.length();
        }
      }
    } on FileSystemException {
      // Whatever was counted.
    }
    return total;
  }

  static Future<void> _deleteFolder(Directory folder) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await folder.exists()) await folder.delete(recursive: true);
        return;
      } on FileSystemException {
        // Held open for a moment (Windows): try again.
        await Future<void>.delayed(Duration(milliseconds: 50 << attempt));
      }
    }
  }

  /// Forgets every running proxy, closing them (tests; nothing in the app).
  @visibleForTesting
  static Future<void> debugReset() async {
    final running = List.of(_proxies.values);
    _proxies.clear();
    _sizes.clear();
    for (final proxy in running) {
      try {
        await (await proxy).close();
      } on Object {
        // Never started.
      }
    }
    _started = 0;
    debugStartGate = null;
  }
}

/// The bytes one account's cache holds, for a widget to listen to. Process
/// long (one per account), so it is not a `ChangeNotifier`, which is meant to
/// be disposed.
class _CacheSize implements ValueListenable<int?> {
  int? _value;
  final _listeners = <VoidCallback>[];

  @override
  int? get value => _value;

  set value(int? next) {
    if (next == _value) return;
    _value = next;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}
