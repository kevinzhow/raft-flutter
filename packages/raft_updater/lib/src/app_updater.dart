import 'dart:io' show File, Platform;
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'appimage/appimage_environment.dart';
import 'appimage/appimage_http.dart';
import 'appimage/appimage_updater.dart';
import 'appimage/ed25519.dart';

/// Compile-time and runtime inputs of the updater.
///
/// Release CI passes `--dart-define=RAFT_AUTO_UPDATE=true` (and, on Windows and
/// for the Linux AppImage, `RAFT_SPARKLE_ED_PUBLIC_KEY`) only when the
/// `SPARKLE_ED_PUBLIC_KEY` repository variable is set. Without it the updater is disabled and every
/// call falls back to opening the release page.
@immutable
class AppUpdaterConfig {
  const AppUpdaterConfig({
    this.enabled = false,
    this.feedUrl = '',
    this.publicKey = '',
    this.buildNumber = '',
    this.version = '',
  });

  /// Reads the `RAFT_*` defines supplied by `tool/release.py`.
  const AppUpdaterConfig.fromEnvironment()
    : enabled = const bool.fromEnvironment('RAFT_AUTO_UPDATE'),
      feedUrl = const String.fromEnvironment('RAFT_UPDATE_FEED_URL'),
      publicKey = const String.fromEnvironment('RAFT_SPARKLE_ED_PUBLIC_KEY'),
      buildNumber = const String.fromEnvironment('RAFT_BUILD_NUMBER'),
      version = const String.fromEnvironment('RAFT_APP_VERSION');

  final bool enabled;

  /// Overrides the default `releases/latest/download/appcast-<platform>.xml`.
  final String feedUrl;

  /// Base64 Ed25519 public key (the Sparkle key). Windows and the Linux
  /// AppImage; macOS reads `SUPublicEDKey` from Info.plist.
  final String publicKey;

  /// The running build's number; must be comparable with `sparkle:version`.
  final String buildNumber;
  final String version;
}

enum AppUpdateOutcome {
  /// The native updater took over: it shows its own check/download/install UI
  /// and restarts the app after installing.
  started,

  /// In-app updating is unavailable here; the release page was opened.
  openedReleasePage,

  /// Neither the native updater nor the browser fallback could be started.
  failed,
}

/// Facade over the native Sparkle (macOS) and WinSparkle (Windows) updaters.
///
/// This is separate from the lightweight "update available" check: that
/// decides when to show the red dot, this performs the update behind the
/// dot's button.
class AppUpdater {
  AppUpdater({
    MethodChannel? channel,
    this._config = const AppUpdaterConfig.fromEnvironment(),
    this._platform,
    bool Function()? isInstalledBuild,
    Future<bool> Function(Uri url)? openUrl,
    Map<String, String>? environment,
    AppImageSupport Function(Map<String, String> environment)? detectAppImage,
  }) : _environment = environment ?? Platform.environment,
       _detectAppImage = detectAppImage ?? AppImageSupport.detect,
       _channel = channel ?? const MethodChannel('app.raft/updater'),
       _isInstalledBuild = isInstalledBuild ?? _defaultIsInstalledBuild,
       _openUrl = openUrl ?? _defaultOpenUrl {
    // ignore: raft_lints/avoid_unreleased_resource -- Owned by the app-wide AppUpdater, which is never torn down.
    _available = ValueNotifier<bool>(_computeStaticAvailability());
  }

  static final AppUpdater instance = AppUpdater();

  static const String repository = 'kevinzhow/raft-flutter';
  static final Uri releasePage = Uri.https(
    'github.com',
    '/$repository/releases/latest',
  );

  final MethodChannel _channel;
  final AppUpdaterConfig _config;
  final TargetPlatform? _platform;
  final bool Function() _isInstalledBuild;
  final Future<bool> Function(Uri url) _openUrl;
  final Map<String, String> _environment;
  final AppImageSupport Function(Map<String, String> environment)
  _detectAppImage;

  late final ValueNotifier<bool> _available;
  AppImageHttpClientFactory? _httpClientFactory;
  Uri? _updateOrigin;
  AppImageUpdater? _appImage;
  Future<bool>? _configured;
  String? _unavailableReason;

  TargetPlatform get _target => _platform ?? defaultTargetPlatform;

  /// True when this build can update in place: macOS or Windows with a build
  /// made with an update key (an installed, not portable, Windows copy, and no
  /// native initialisation failure so far); or, on Linux, an AppImage whose
  /// folder is writable and that carries update information (see [appImage]).
  bool get available => _available.value;

  /// Notifies when [available] changes (for example after a failed native
  /// initialisation).
  ValueListenable<bool> get availability => _available;

  /// Why [available] is false, for diagnostics; null while available.
  String? get unavailableReason => _unavailableReason;

  /// The appcast the native updater polls.
  String get feedUrl {
    if (_config.feedUrl.isNotEmpty) return _config.feedUrl;
    final name = _target == TargetPlatform.macOS ? 'macos' : 'windows';
    return 'https://github.com/$repository/releases/latest/download/appcast-$name.xml';
  }

  /// Linux AppImage in-place updater; null elsewhere and whenever [available]
  /// is false. Its status drives the Updates card while an update runs.
  AppImageUpdater? get appImage => available ? _appImage : null;

  /// Runs before a required Linux AppImage exit.
  ///
  /// A required exit does not ask the application whether it may leave, so the
  /// app uses this to finish closing the background database. Null keeps the
  /// required exit as it is.
  Future<void> Function()? beforeQuit;

  /// Application hook read by [quitAfterHook] when [beforeQuit] is null.
  ///
  /// Assigning it does not construct [instance]. The app sets it at startup so
  /// a required exit can close the background database.
  static Future<void> Function()? requiredExitHook;

  /// Runs [beforeQuit], or else [requiredExitHook], then requests a required
  /// exit.
  ///
  /// A throw from the hook does not cancel the exit.
  Future<void> quitAfterHook() async {
    final hook = beforeQuit ?? requiredExitHook;
    if (hook != null) {
      try {
        await hook();
      } on Object {
        // The required exit still proceeds.
      }
    }
    await performRequiredExit();
  }

  /// The required exit [quitAfterHook] performs. Tests replace this because
  /// the test binding rejects a required exit.
  @visibleForTesting
  Future<void> Function() performRequiredExit = _performRequiredExit;

  static Future<void> _performRequiredExit() {
    return ServicesBinding.instance
        .exitApplication(AppExitType.required)
        .then((_) {});
  }

  /// Supplies the app's proxy-aware HTTP client (the package builds none of
  /// its own) and, for isolated test builds only, another origin in place of
  /// `https://github.com`. Linux AppImage updates stay unavailable until this
  /// is called.
  void configureAppImage({
    required AppImageHttpClientFactory httpClientFactory,
    Uri? origin,
  }) {
    _httpClientFactory = httpClientFactory;
    _updateOrigin = origin;
    _appImage = null;
    _unavailableReason = null;
    _available.value = _computeStaticAvailability();
  }

  bool _computeLinuxAvailability() {
    final factory = _httpClientFactory;
    if (factory == null) {
      _unavailableReason = 'The AppImage updater has no network client yet.';
      return false;
    }
    final support = _detectAppImage(_environment);
    if (!support.available) {
      _unavailableReason = support.reason;
      return false;
    }
    // Updates are installed only when signed by the publisher, so a build
    // without the public key cannot update in place (the release page opens).
    if (!Ed25519Verifier.isPublicKey(_config.publicKey)) {
      _unavailableReason = 'This build has no update signing key.';
      return false;
    }
    _appImage = AppImageUpdater(
      path: support.path!,
      information: support.information!,
      http: AppImageHttp(factory),
      publicKey: _config.publicKey.trim(),
      origin: _updateOrigin,
      environment: _environment,
      quit: quitAfterHook,
    );
    return true;
  }

  bool _computeStaticAvailability() {
    if (!kIsWeb && _target == TargetPlatform.linux) {
      return _computeLinuxAvailability();
    }
    if (kIsWeb ||
        (_target != TargetPlatform.macOS &&
            _target != TargetPlatform.windows)) {
      _unavailableReason = 'In-app updates are not supported on this platform.';
      return false;
    }
    if (!_config.enabled) {
      _unavailableReason = 'This build has no update signing key.';
      return false;
    }
    if (_target == TargetPlatform.windows &&
        (_config.publicKey.isEmpty || _config.buildNumber.isEmpty)) {
      _unavailableReason = 'This build lacks the update key or build number.';
      return false;
    }
    if (_target == TargetPlatform.windows && !_isInstalledBuild()) {
      _unavailableReason =
          'Portable Windows builds update by installing the setup program.';
      return false;
    }
    return true;
  }

  void _disable(String reason) {
    _unavailableReason = reason;
    _available.value = false;
  }

  Future<bool> _configure() => _configured ??= _configureNative();

  Future<bool> _configureNative() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'configure',
        <String, Object?>{
          'feedUrl': feedUrl,
          'publicKey': _config.publicKey,
          'buildNumber': _config.buildNumber,
          'version': _config.version,
        },
      );
      if (result?['available'] == true) return true;
      _disable(
        (result?['reason'] as String?) ?? 'The native updater is unavailable.',
      );
    } on MissingPluginException {
      _disable('The native updater is not part of this build.');
    } on PlatformException catch (error) {
      _disable(error.message ?? error.code);
    }
    return false;
  }

  /// Checks for an update and, with the user's consent in the native dialog,
  /// downloads, verifies, installs and relaunches. Where in-place updating is
  /// unavailable, opens the release page instead.
  Future<AppUpdateOutcome> checkAndInstall() async {
    if (_target != TargetPlatform.linux && available && await _configure()) {
      try {
        final started = await _channel.invokeMethod<bool>('checkForUpdates');
        if (started ?? false) return AppUpdateOutcome.started;
      } on PlatformException {
        // Fall through to the release page.
      } on MissingPluginException {
        _disable('The native updater is not part of this build.');
      }
    }
    return await _openUrl(releasePage)
        ? AppUpdateOutcome.openedReleasePage
        : AppUpdateOutcome.failed;
  }

  static bool _defaultIsInstalledBuild() {
    try {
      // Inno Setup places its uninstaller next to the executable.
      final folder = File(Platform.resolvedExecutable).parent.path;
      final separator = Platform.pathSeparator;
      return File('$folder${separator}unins000.exe').existsSync();
    } on Object {
      return false;
    }
  }

  static Future<bool> _defaultOpenUrl(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}
