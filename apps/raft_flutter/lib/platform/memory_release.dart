import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show RaftHotImages, RaftImageBytes;

import '../data/user_activity.dart';
import 'memory_budgets.dart';

/// Why rebuildable memory is released.
enum RaftMemoryTrim {
  /// The app has been hidden for [RaftMemoryRelease.backgroundDelay].
  backgrounded,

  /// The OS asked for memory (Android `onTrimMemory`, iOS memory warning).
  pressure,
}

typedef RaftMemoryTrimmer = void Function(RaftMemoryTrim reason);

/// Releases decoded images and other rebuildable caches when the app is not
/// being looked at (owner report 2026-10-13: finished media kept hundreds of
/// MB resident). Everything released is rebuilt on demand: a page that comes
/// back may decode again, never loses data.
///
/// * Memory pressure: Flutter already clears the global `ImageCache`; the
///   registered trimmers drop what the framework does not know about (our
///   own decoded-image repository).
/// * Hidden/paused for [backgroundDelay]: the `ImageCache` is cleared and the
///   trimmers run. Images that widgets still hold stay (no frame runs while
///   hidden, so a widget could not let go of them anyway).
///
/// The delay keeps a quick app switch free of re-decoding. Avatars are the
/// exception: `RaftHotImages` (bounded to 24 MB) holds them through the
/// background clear, and memory pressure (which Android also reports when the
/// app is hidden) only shrinks them to a small floor (`trimAvatarImages`), so
/// a returning app shows its avatars at once.
class RaftMemoryRelease with WidgetsBindingObserver {
  RaftMemoryRelease({
    this.backgroundDelay = const Duration(seconds: 30),
    ImageCache Function()? imageCache,
    RaftMemoryBudgets Function()? budgets,
  }) : _imageCache = imageCache ?? (() => PaintingBinding.instance.imageCache),
       _budgets = budgets ?? (() => RaftMemoryBudgets.current);

  static final RaftMemoryRelease instance = RaftMemoryRelease();

  final Duration backgroundDelay;
  final ImageCache Function() _imageCache;
  final RaftMemoryBudgets Function() _budgets;
  VoidCallback? _restoreImageCache, _removeAvatarReporter;
  final _trimmers = <RaftMemoryTrimmer>{};
  final _reporters = <String, String Function()>{};
  Timer? _timer;
  bool _installed = false;

  /// True once the app has stayed hidden for [backgroundDelay].
  bool get backgrounded => _backgrounded;
  bool _backgrounded = false;

  /// Starts observing the app lifecycle and memory pressure, and sets the
  /// framework `ImageCache` limits of this device class (see
  /// [RaftMemoryBudgets]; the framework default is 1000 images / 100 MiB, which
  /// nothing sized). Idempotent.
  void install() {
    if (_installed) return;
    _installed = true;
    // Before the first activity query. A click during startup must still
    // count, or a desktop reader at the bottom leaves a live message unread.
    RaftUserActivity.install();
    _restoreImageCache = _budgets().applyImageCache(_imageCache());
    _removeAvatarReporter = addReporter('avatars', () {
      final hot = RaftHotImages.instance, bytes = RaftImageBytes.instance;
      return 'hot ${hot.length}/${hot.maxEntries} '
          '${hot.estimatedBytes}/${hot.maxBytes} B '
          'bytes ${bytes.memoryEntries} '
          '${bytes.memoryBytes}/${bytes.memoryBudgetBytes} B';
    });
    WidgetsBinding.instance.addObserver(this);
  }

  void uninstall() {
    if (!_installed) return;
    _installed = false;
    _restoreImageCache?.call();
    _restoreImageCache = null;
    _removeAvatarReporter?.call();
    _removeAvatarReporter = null;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _backgrounded = false;
  }

  /// Registers [trimmer]; the returned callback removes it.
  VoidCallback addTrimmer(RaftMemoryTrimmer trimmer) {
    _trimmers.add(trimmer);
    return () => _trimmers.remove(trimmer);
  }

  /// Registers a named one-line report of a memory tier (counts and bytes);
  /// [snapshot] lists them next to the framework `ImageCache`. Diagnostics
  /// only: nothing calls a reporter unless a probe or [trim] logs in a
  /// non-release build. The returned callback removes it.
  VoidCallback addReporter(String name, String Function() report) {
    _reporters[name] = report;
    return () {
      if (identical(_reporters[name], report)) _reporters.remove(name);
    };
  }

  /// One line with the framework `ImageCache` and every registered tier.
  String snapshot() {
    final cache = _imageCache();
    final parts = [
      'imageCache ${cache.currentSize}/${cache.maximumSize} images '
          '${cache.currentSizeBytes}/${cache.maximumSizeBytes} B '
          'live ${cache.liveImageCount}',
      for (final entry in _reporters.entries) '${entry.key} ${entry.value()}',
    ];
    return parts.join(' | ');
  }

  @override
  void didHaveMemoryPressure() => trim(RaftMemoryTrim.pressure);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // One-shot, positive delay; never re-armed from its own callback.
        _timer ??= Timer(backgroundDelay, _enterBackground);
      case AppLifecycleState.resumed:
        _timer?.cancel();
        _timer = null;
        _backgrounded = false;
        // The startup call can miss when no binding exists yet.
        RaftUserActivity.install();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _enterBackground() {
    _timer = null;
    _backgrounded = true;
    trim(RaftMemoryTrim.backgrounded);
  }

  /// Runs every trimmer; also clears the framework image cache when
  /// backgrounded (pressure is already handled by the binding).
  void trim(RaftMemoryTrim reason) {
    final cache = _imageCache();
    if (!kReleaseMode) {
      debugPrint('[raft-memory] ${reason.name}: ${snapshot()}');
    }
    if (reason == RaftMemoryTrim.backgrounded) cache.clear();
    for (final trimmer in List.of(_trimmers)) {
      try {
        trimmer(reason);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'raft memory release',
          ),
        );
      }
    }
  }
}
