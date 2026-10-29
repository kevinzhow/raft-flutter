import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/system_proxy.dart';

import '../data/search_memory.dart';
import 'client_release_notes.dart';

/// The GitHub release that CI published for one platform (one entry of that
/// platform's `build-manifest-<platform>-<arch>.json`, see tool/release.py).
@immutable
class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.releaseTag,
    required this.artifact,
    this.sha256 = '',
    this.bytes = 0,
    this.edSignature = '',
  });

  /// The compiled app version, e.g. `0.1.0`.
  final String version;

  /// The CI build number (`GITHUB_RUN_NUMBER`): what the newer-than test
  /// compares. Release builds pass it as `--build-number` and as the
  /// `RAFT_BUILD_NUMBER` define.
  final int buildNumber;

  /// The full release tag, e.g. `v0.1.0+5`.
  final String releaseTag;

  /// The platform asset name, e.g. `raft-flutter-0.1.0+5-android-arm64.apk`.
  final String artifact;

  /// Lowercase hex SHA-256 and size of [artifact] as the publisher verified
  /// them; empty / 0 when the manifest lacks them. The Linux in-place update
  /// refuses to install without them.
  final String sha256;
  final int bytes;

  /// Base64 Ed25519 signature of [artifact]'s bytes (the manifest's
  /// `edSignature`, same key as Sparkle); empty when the manifest lacks it.
  /// The Linux in-place update refuses to install without it.
  final String edSignature;

  static const repository = 'https://github.com/kevinzhow/raft-flutter';

  /// The human release page.
  Uri get releasePage => Uri.parse('$repository/releases/tag/$releaseTag');

  /// The direct asset download (used on Android, where the browser hands the
  /// APK to the installer).
  Uri get downloadUrl =>
      Uri.parse('$repository/releases/download/$releaseTag/$artifact');

  Map<String, Object?> toJson() => {
    'version': version,
    'buildNumber': buildNumber,
    'releaseTag': releaseTag,
    'artifact': artifact,
    if (sha256.isNotEmpty) 'sha256': sha256,
    if (bytes > 0) 'bytes': bytes,
    if (edSignature.isNotEmpty) 'edSignature': edSignature,
  };

  /// Null unless every field is present and well formed. The tag and asset
  /// name end up in a URL, so only plain path-safe characters are accepted.
  static AppRelease? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    final tag = raw['releaseTag'];
    final artifact = raw['artifact'];
    final build = switch (raw['buildNumber']) {
      final int n => n,
      final String s => int.tryParse(s.trim()),
      _ => null,
    };
    final safe = RegExp(r'^[A-Za-z0-9._+\-]+$');
    if (version is! String ||
        version.trim().isEmpty ||
        tag is! String ||
        !tag.startsWith('v') ||
        !safe.hasMatch(tag) ||
        artifact is! String ||
        !safe.hasMatch(artifact) ||
        build == null ||
        build < 1) {
      return null;
    }
    final digest = raw['sha256'];
    final size = raw['bytes'];
    final signature = raw['edSignature'];
    return AppRelease(
      version: version.trim(),
      buildNumber: build,
      releaseTag: tag,
      artifact: artifact,
      sha256: digest is String && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)
          ? digest.toLowerCase()
          : '',
      bytes: size is int && size > 0 ? size : 0,
      edSignature: signature is String && _signatureText.hasMatch(signature)
          ? signature
          : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppRelease &&
      other.version == version &&
      other.buildNumber == buildNumber &&
      other.releaseTag == releaseTag &&
      other.artifact == artifact &&
      other.sha256 == sha256 &&
      other.bytes == bytes &&
      other.edSignature == edSignature;

  @override
  int get hashCode => Object.hash(
    version,
    buildNumber,
    releaseTag,
    artifact,
    sha256,
    bytes,
    edSignature,
  );

  /// 64 bytes of base64 (88 characters with padding).
  static final _signatureText = RegExp(r'^[A-Za-z0-9+/]{86}==$');
}

/// Parses a build manifest body: a JSON array of receipts (a single object is
/// tolerated). Returns the entry for [platformKey] (`<platform>-<arch>`) with
/// the highest build number, or null when the body is not a valid manifest or
/// has no usable entry.
AppRelease? parseBuildManifest(String body, String platformKey) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  final rows = decoded is List ? decoded : [decoded];
  AppRelease? best;
  for (final row in rows) {
    if (row is! Map) continue;
    if ('${row['platform']}-${row['arch']}' != platformKey) continue;
    final release = AppRelease.fromJson(row);
    if (release != null &&
        (best == null || release.buildNumber > best.buildNumber)) {
      best = release;
    }
  }
  return best;
}

/// `<platform>-<arch>` of the manifest this build updates from, or null when
/// the platform is not distributed on GitHub releases: iOS, web, and Linux
/// outside an AppImage (`APPIMAGE` is exported by the AppImage runtime).
String? appUpdatePlatformKey({
  bool web = kIsWeb,
  TargetPlatform? target,
  Map<String, String>? environment,
}) {
  if (web) return null;
  return switch (target ?? defaultTargetPlatform) {
    TargetPlatform.android => 'android-arm64',
    TargetPlatform.macOS => 'macos-arm64',
    TargetPlatform.windows => 'windows-x64',
    TargetPlatform.linux =>
      (environment ?? Platform.environment)['APPIMAGE']?.isNotEmpty == true
          ? 'appimage-x64'
          : null,
    _ => null,
  };
}

/// Another origin in place of `https://github.com` for the manifest and the
/// AppImage delta files, for update tests against a local fake GitHub
/// (`RAFT_UPDATE_ORIGIN=http://127.0.0.1:PORT`, see tool/appimage-update-smoke.py).
///
/// Honoured only by isolated Linux test builds (`RAFT_APPLICATION_ID_SUFFIX`)
/// and non-release (debug/profile) builds; a release build ignores the
/// variable, so a user's environment can never redirect where an official
/// build fetches updates from.
Uri? updateOriginOverride({
  Map<String, String>? environment,
  bool? releaseBuild,
  String isolatedSuffix = const String.fromEnvironment(
    'RAFT_LINUX_APPLICATION_ID_SUFFIX',
  ),
}) {
  if (kIsWeb) return null;
  if ((releaseBuild ?? kReleaseMode) && isolatedSuffix.isEmpty) return null;
  final value = (environment ?? Platform.environment)['RAFT_UPDATE_ORIGIN'];
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return uri;
}

/// Fetches the manifest body at [url]; null when the release has no such
/// file (404). Any other failure throws.
typedef AppUpdateFetcher = Future<String?> Function(Uri url);

/// The production fetcher: plain GET through the app's proxy-aware HTTP stack
/// (Settings > Network), following GitHub's download redirect. It carries no
/// credentials and does not use the rate-limited GitHub REST API.
Future<String?> fetchManifestOverHttp(Uri url) async {
  final dio = createProxiedDio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
      maxRedirects: 5,
      validateStatus: (status) => status == 200 || status == 404,
    ),
  );
  try {
    final response = await dio.getUri<String>(url);
    return response.statusCode == 200 ? response.data : null;
  } finally {
    dio.close(force: true);
  }
}

/// What the About page shows in its Updates card.
enum AppUpdateStatus {
  /// This build does not take part in update checks; see
  /// [AppUpdateService.unsupported].
  unsupported,

  /// Supported, but no check has finished or started yet (first frames).
  idle,
  checking,

  /// A newer release is published.
  available,

  /// The last check failed and no newer release is known.
  failed,

  /// The last check succeeded and found nothing newer.
  upToDate,
}

/// Why a build cannot check for updates.
enum AppUpdateUnsupported {
  /// iOS: not distributed through GitHub releases.
  ios,

  /// Linux outside an AppImage (a distro package updates through its package
  /// manager).
  linuxPackage,

  /// Web and any other platform without a release asset.
  platform,

  /// A local or dev build: no CI build number or a `-dev` version.
  development,
}

/// Detects a newer CI release and remembers what the user has already seen.
///
/// One manifest request at start (after the first frame) and at most one per
/// [interval] afterwards, triggered by [checkIfDue] on app resume plus one
/// one-shot timer re-armed after each check (no periodic timer). [checkNow] is
/// the user's "Check for updates" button and ignores that throttle. A failure
/// is logged once per run and kept in [failure] until the next successful
/// check, which clears it (the About card derives its error text from it, so
/// nothing can outlive its cause).
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    required this.currentVersion,
    required this.currentBuild,
    required this.platformKey,
    required this.fetch,
    this.currentTag = '',
    this.target,
    SearchMemoryStorage? storage,
    DateTime Function()? clock,
    this.interval = const Duration(hours: 6),
    this.retryAfterFailure = const Duration(minutes: 30),
    this.scheduleTimer = true,
    this.releaseNotes,
    this.manifestRoot = AppUpdateService.manifestBase,
    void Function(String message)? log,
  }) : storage = storage ?? PreferencesSearchMemoryStorage(),
       _clock = clock ?? DateTime.now,
       _log = log ?? debugPrint;

  /// The service for this running build. Dev/local builds (version with
  /// `-dev`, or no CI build number) and platforms without a GitHub release
  /// asset get a disabled service.
  factory AppUpdateService.forThisBuild({
    String version = const String.fromEnvironment('RAFT_APP_VERSION'),
    String buildNumber = const String.fromEnvironment('RAFT_BUILD_NUMBER'),
    String tag = const String.fromEnvironment('RAFT_RELEASE_TAG'),
    String? platformKey,
    AppUpdateFetcher fetch = fetchManifestOverHttp,
    SearchMemoryStorage? storage,
    TargetPlatform? target,
    Uri? origin,
  }) => AppUpdateService(
    manifestRoot: origin == null
        ? manifestBase
        : '${origin.toString().replaceFirst(RegExp(r'/+$'), '')}'
              '/${AppRelease.repository.substring('https://github.com/'.length)}'
              '/releases/latest/download',
    target: target,
    releaseNotes: ClientReleaseNotes(
      fetch: fetch,
      storage: storage,
      appBuild: int.tryParse(buildNumber),
    ),
    currentVersion: version,
    currentBuild: int.tryParse(buildNumber),
    currentTag: tag,
    platformKey: platformKey ?? appUpdatePlatformKey(),
    fetch: fetch,
    storage: storage,
  );

  static const storageKey = 'raft:app-update:v1';
  static const manifestBase =
      '${AppRelease.repository}/releases/latest/download';

  /// Where `build-manifest-<platform>.json` is fetched from: [manifestBase],
  /// unless a test override ([updateOriginOverride]) replaced the origin.
  final String manifestRoot;

  final String currentVersion;
  final int? currentBuild;

  /// The release tag this build was published under (`v0.1.0+5`), compiled in
  /// by the release build as `RAFT_RELEASE_TAG`; empty for builds made before
  /// that and for local builds. The update prompt uses it to list exactly the
  /// releases between this one and the offered one.
  final String currentTag;
  final String? platformKey;

  /// The platform this build runs on; only used to explain [unsupported].
  /// Defaults to [defaultTargetPlatform].
  final TargetPlatform? target;

  /// The client's release notes (Settings > Release Notes); independent of
  /// whether update checks are enabled for this build.
  final ClientReleaseNotes? releaseNotes;
  final AppUpdateFetcher fetch;
  final SearchMemoryStorage storage;
  final DateTime Function() _clock;
  final Duration interval, retryAfterFailure;
  final bool scheduleTimer;
  final void Function(String message) _log;

  AppRelease? _remote;

  /// CI build number -> release tag of every release the manifest has shown,
  /// newest last (a few remembered). Builds made before [currentTag] existed
  /// learn their own tag here once a check sees their release as the latest.
  final _tags = <int, String>{};
  int _seen = 0;
  DateTime? _checkedAt, _attemptedAt;
  bool _failedLast = false, _loaded = false, _checking = false;
  Object? _lastFailure;
  // ignore: raft_lints/avoid_imperative_notice_state -- _loggedFailure only de-duplicates a log line (never shown in the UI); _disposed is lifecycle state.
  bool _loggedFailure = false, _disposed = false;
  Timer? _timer;
  Future<void>? _loading;

  /// Whether this build takes part in update checks at all.
  bool get enabled =>
      platformKey != null &&
      (currentBuild ?? 0) > 0 &&
      currentVersion.isNotEmpty &&
      !currentVersion.contains('-dev');

  /// Why this build cannot check for updates; null when it can.
  AppUpdateUnsupported? get unsupported {
    if (enabled) return null;
    if (platformKey == null) {
      if (kIsWeb) return AppUpdateUnsupported.platform;
      return switch (target ?? defaultTargetPlatform) {
        TargetPlatform.iOS => AppUpdateUnsupported.ios,
        TargetPlatform.linux => AppUpdateUnsupported.linuxPackage,
        _ => AppUpdateUnsupported.platform,
      };
    }
    return AppUpdateUnsupported.development;
  }

  /// A check is running right now.
  bool get checking => _checking;

  /// When the last successful check finished (also remembered across runs).
  DateTime? get lastChecked => _checkedAt;

  /// The error of the last check; null after any successful check.
  Object? get failure => _failedLast ? _lastFailure : null;

  /// What the Updates card shows.
  AppUpdateStatus get status {
    if (!enabled) return AppUpdateStatus.unsupported;
    if (_checking) return AppUpdateStatus.checking;
    if (available != null) return AppUpdateStatus.available;
    if (_failedLast) return AppUpdateStatus.failed;
    return _checkedAt == null ? AppUpdateStatus.idle : AppUpdateStatus.upToDate;
  }

  /// The newest published release, when it is newer than the running build.
  AppRelease? get available {
    final remote = _remote, build = currentBuild;
    if (!enabled || remote == null || build == null) return null;
    return remote.buildNumber > build ? remote : null;
  }

  /// The release tag of the running build: the compiled-in [currentTag], else
  /// the one a manifest paired with [currentBuild]; empty when unknown.
  String get installedTag {
    if (currentTag.isNotEmpty) return currentTag;
    final build = currentBuild;
    return build == null ? '' : _tags[build] ?? '';
  }

  void _learn(AppRelease release) {
    _tags
      ..remove(release.buildNumber)
      ..[release.buildNumber] = release.releaseTag;
    while (_tags.length > 20) {
      _tags.remove(_tags.keys.first);
    }
  }

  /// The red dot: a newer release the user has not looked at yet.
  bool get hasUnseen {
    final release = available;
    return release != null && release.buildNumber > _seen;
  }

  Uri get manifestUrl =>
      Uri.parse('$manifestRoot/build-manifest-$platformKey.json');

  /// Reads the remembered state, then checks if one is due. Safe to call
  /// repeatedly.
  Future<void> start() async {
    if (!enabled || _disposed) return;
    await _load();
    await checkIfDue();
  }

  /// Checks unless the last check is recent. Called on resume and by the
  /// one-shot timer.
  Future<void> checkIfDue() async {
    if (!enabled || _disposed || _checking) return;
    await _load();
    final now = _clock();
    final wait = _failedLast ? retryAfterFailure : interval;
    final last = _failedLast ? _attemptedAt : _checkedAt;
    // A clock set back counts as due rather than waiting out the difference.
    if (last != null && !now.isBefore(last) && now.difference(last) < wait) {
      _arm(wait - now.difference(last));
      return;
    }
    await _check();
  }

  /// The user asked: checks now, whatever the throttle says. Taps while a
  /// check is running are ignored.
  Future<void> checkNow() async {
    if (!enabled || _disposed || _checking) return;
    await _load();
    if (_disposed || _checking) return;
    await _check();
  }

  Future<void> _check() async {
    _checking = true;
    notifyListeners();
    final key = platformKey!;
    try {
      _attemptedAt = _clock();
      final body = await fetch(manifestUrl);
      if (_disposed) return;
      final release = body == null ? null : parseBuildManifest(body, key);
      _failedLast = false;
      _lastFailure = null;
      _checkedAt = _attemptedAt;
      // A release without this platform's manifest (or an unusable one) is
      // not an update; keep what was known before.
      if (release != null) {
        _remote = release;
        _learn(release);
      }
      await _save();
    } catch (error) {
      _failedLast = true;
      _lastFailure = error;
      if (!_loggedFailure) {
        _loggedFailure = true;
        _log('Update check failed (${error.runtimeType})');
      }
    } finally {
      _checking = false;
      if (!_disposed) {
        _arm(_failedLast ? retryAfterFailure : interval);
        notifyListeners();
      }
    }
  }

  /// Marks the newest known release as seen: the dot goes away until a newer
  /// build is published. The About row stays available.
  void markSeen() {
    final release = available;
    if (_disposed || release == null || release.buildNumber <= _seen) return;
    _seen = release.buildNumber;
    unawaited(_save());
    notifyListeners();
  }

  void _arm(Duration after) {
    if (!scheduleTimer || _disposed) return;
    _timer?.cancel();
    _timer = Timer(after, () => unawaited(checkIfDue()));
  }

  Future<void> _load() => _loading ??= () async {
    try {
      final raw = await storage.read(storageKey);
      final data = raw == null ? null : jsonDecode(raw);
      if (data is Map) {
        _remote = AppRelease.fromJson(data['remote']);
        final remembered = data['tags'];
        if (remembered is Map) {
          for (final MapEntry(:key, :value) in remembered.entries) {
            final build = int.tryParse('$key');
            if (build != null && value is String) _tags[build] = value;
          }
        }
        final remote = _remote;
        if (remote != null) _learn(remote);
        final seen = data['seen'];
        if (seen is int && seen > 0) _seen = seen;
        final at = data['checkedAt'];
        if (at is int) {
          _checkedAt = DateTime.fromMillisecondsSinceEpoch(at);
        }
      }
    } catch (_) {
      // Unreadable memory behaves like a first run.
    }
    _loaded = true;
    if (!_disposed && (_remote != null || _seen > 0)) notifyListeners();
  }();

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      await storage.write(
        storageKey,
        jsonEncode({
          'checkedAt': _checkedAt?.millisecondsSinceEpoch,
          'remote': _remote?.toJson(),
          'tags': {for (final e in _tags.entries) '${e.key}': e.value},
          'seen': _seen,
        }),
      );
    } catch (_) {
      // The current run still remembers it.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
