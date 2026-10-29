import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' show Display, FlutterView;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../src/third_party/performance_hint.g.dart';
import '../src/third_party/unistd.g.dart';
import 'route_frame_diagnostics.dart';

const androidPerformanceHintsEnabled = bool.fromEnvironment(
  'RAFT_ANDROID_PERFORMANCE_HINT',
  defaultValue: true,
);

/// The backend runs synchronously on the same thread as the Flutter UI isolate.
abstract interface class PerformanceHintBackend {
  bool open(int targetNanos);
  int updateTarget(int targetNanos);
  int report(int actualNanos);
  int reset();
  void close();
}

class _AndroidHintBackend implements PerformanceHintBackend {
  _AndroidHintBackend(this.canReset);
  final bool canReset;
  Pointer<APerformanceHintSession> session = nullptr;
  int? uiThreadId;

  static PerformanceHintBackend? load() {
    if (!androidPerformanceHintsEnabled || !Platform.isAndroid || kDebugMode) {
      return null;
    }
    try {
      DynamicLibrary.open('libandroid.so');
      final library = DynamicLibrary.process();
      for (final symbol in [
        'APerformanceHint_getManager',
        'APerformanceHint_createSession',
        'APerformanceHint_closeSession',
        'APerformanceHint_updateTargetWorkDuration',
        'APerformanceHint_reportActualWorkDuration',
      ]) {
        if (!library.providesSymbol(symbol)) return null;
      }
      if (!library.providesSymbol('gettid')) return null;
      return _AndroidHintBackend(
        library.providesSymbol('APerformanceHint_notifyWorkloadReset'),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool open(int targetNanos) {
    final manager = APerformanceHint_getManager();
    if (manager == nullptr) return false;
    final tids = calloc<Int32>();
    try {
      // Never infer the UI thread from thread names or engine configuration.
      tids.value = gettid();
      uiThreadId = tids.value;
      session = APerformanceHint_createSession(manager, tids, 1, targetNanos);
      return session != nullptr;
    } finally {
      calloc.free(tids);
    }
  }

  @override
  int updateTarget(int targetNanos) =>
      APerformanceHint_updateTargetWorkDuration(session, targetNanos);
  @override
  int report(int actualNanos) {
    // A future engine thread migration must not leave us hinting the old thread.
    if (gettid() != uiThreadId) return 32;
    return APerformanceHint_reportActualWorkDuration(session, actualNanos);
  }

  @override
  int reset() {
    if (!canReset) return 0;
    final identifier = 'raft-ui-frame-burst'.toNativeUtf8();
    try {
      return APerformanceHint_notifyWorkloadReset(
        session,
        true,
        false,
        identifier.cast(),
      );
    } finally {
      calloc.free(identifier);
    }
  }

  @override
  void close() {
    if (session != nullptr) {
      APerformanceHint_closeSession(session);
      session = nullptr;
    }
  }
}

/// Owns one short-lived CPU session; unsupported devices and service failures
/// permanently fall back to ordinary scheduling for this binding's lifetime.
/// The refresh rate of the display the first of [views] is on, 60 when there
/// is none to ask: a view has no display while the computer sleeps or a
/// screen is being unplugged (`FlutterView.display` then throws), and frames
/// are still scheduled then.
@visibleForTesting
double displayRefreshRateOf(
  Iterable<FlutterView> views,
  Iterable<Display> displays,
) {
  if (views.isEmpty || displays.isEmpty) return 60;
  double sane(double rate) => rate > 0 ? rate : 60;
  try {
    // ignore: raft_lints/avoid_view_display -- the one guarded read: a view without a display throws, caught below.
    return sane(views.first.display.refreshRate);
    // ignore: avoid_catching_errors -- FlutterView.display has no nullable form; a view without a display (sleep, unplugged screen) throws a null-check error, and a frame must never fail on it.
  } on Error {
    return sane(displays.first.refreshRate);
  }
}

class PerformanceHintController {
  PerformanceHintController(this.backend);
  final PerformanceHintBackend? backend;
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _idleTimer;
  int _lastWorkMicros = 0;
  int _target = 0;
  bool _active = false;
  bool _foreground = true;
  bool _failed = false;
  int sessionsOpened = 0;
  int reports = 0;
  int resets = 0;
  int errors = 0;

  bool get active => _active;
  Map<String, Object> get diagnostics => {
    'enabled': androidPerformanceHintsEnabled,
    'backendAvailable': backend != null,
    'active': active,
    'sessionsOpened': sessionsOpened,
    'reports': reports,
    'resets': resets,
    'errors': errors,
    'scope': 'Dart UI CPU; excludes raster/GPU',
    if (backend is _AndroidHintBackend) ...{
      'uiThreadId': (backend as _AndroidHintBackend).uiThreadId ?? 0,
      'advanceResetAvailable': (backend as _AndroidHintBackend).canReset,
    },
  };

  static int targetForRefreshRate(double refreshRate) {
    final hz = refreshRate.isFinite && refreshRate >= 1 ? refreshRate : 60.0;
    return (1000000000 / hz).round().clamp(1, 1000000000);
  }

  void begin(double refreshRate) {
    if (backend == null || !_foreground || _failed) return;
    _lastWorkMicros = _clock.elapsedMicroseconds;
    final target = targetForRefreshRate(refreshRate);
    try {
      if (!_active) {
        if (!backend!.open(target)) {
          _failed = true;
          return;
        }
        _active = true;
        _target = target;
        sessionsOpened++;
        final result = backend!.reset();
        // EBUSY means the optional advance hint was rate limited.
        if (result != 0 && result != 16) {
          _fail();
          return;
        }
        resets++;
        _idleTimer = Timer(const Duration(milliseconds: 400), _expire);
      } else if (_target != target) {
        if (backend!.updateTarget(target) != 0) {
          _fail();
          return;
        }
        _target = target;
      }
    } catch (_) {
      _fail();
    }
  }

  void report(int durationNanos) {
    if (!_active || durationNanos <= 0) return;
    _lastWorkMicros = _clock.elapsedMicroseconds;
    try {
      if (backend!.report(durationNanos) != 0) {
        _fail();
      } else {
        reports++;
      }
    } catch (_) {
      _fail();
    }
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) close();
  }

  void _expire() {
    _idleTimer = null;
    final remaining = 400000 - (_clock.elapsedMicroseconds - _lastWorkMicros);
    if (remaining > 0 && _active) {
      _idleTimer = Timer(Duration(microseconds: remaining), _expire);
    } else {
      close();
    }
  }

  void _fail() {
    errors++;
    _failed = true;
    close();
  }

  void close() {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_active) {
      _active = false;
      try {
        backend!.close();
      } catch (_) {
        errors++;
      }
    }
  }
}

/// Measures the synchronous frame cycle (including animations and microtasks),
/// before timing batches reach addTimingsCallback. No raster/GPU timing is used.
mixin AndroidPerformanceHintBinding on WidgetsBinding {
  PerformanceHintController? _hints;
  Stopwatch? _frameClock;
  Map<String, Object>? get performanceHintDiagnostics => _hints?.diagnostics;

  @override
  PipelineOwner createRootPipelineOwner() => RouteFrameDiagnostics.enabled
      ? RouteFramePipelineOwner()
      : super.createRootPipelineOwner();

  @override
  void drawFrame() {
    if (RouteFrameDiagnostics.enabled) {
      RouteFrameDiagnostics.drawStarted = RouteFrameDiagnostics.now();
    }
    super.drawFrame();
  }

  @override
  void initInstances() {
    super.initInstances();
    if (RouteFrameDiagnostics.enabled) RouteFrameDiagnostics.initialize(this);
    _hints = PerformanceHintController(_AndroidHintBackend.load());
    _hints!.setForeground(
      lifecycleState == null || lifecycleState == AppLifecycleState.resumed,
    );
  }

  double get _displayRefreshRate => displayRefreshRateOf(
    platformDispatcher.views,
    platformDispatcher.displays,
  );

  /// Starts the hint session for a frame. Only where hints are on (Android):
  /// elsewhere the display is not asked at all.
  void _beginHint() {
    final hints = _hints;
    if (hints == null || hints.backend == null) return;
    hints.begin(_displayRefreshRate);
  }

  @override
  void scheduleFrame() {
    _beginHint();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Binding override that observes scheduleFrame to open a performance-hint session; it forwards to super and requests none.
    super.scheduleFrame();
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    if (RouteFrameDiagnostics.enabled) RouteFrameDiagnostics.begin();
    _beginHint();
    if (_hints?.active == true) _frameClock = Stopwatch()..start();
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    try {
      super.handleDrawFrame();
    } finally {
      if (RouteFrameDiagnostics.enabled) RouteFrameDiagnostics.end();
      final clock = _frameClock;
      _frameClock = null;
      if (clock != null) {
        clock.stop();
        _hints?.report(
          (clock.elapsedTicks * 1000000000 / clock.frequency).round(),
        );
      }
    }
  }

  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    _hints?.setForeground(state == AppLifecycleState.resumed);
    super.handleAppLifecycleStateChanged(state);
  }
}

class RaftWidgetsFlutterBinding extends WidgetsFlutterBinding
    with AndroidPerformanceHintBinding {
  static WidgetsBinding ensureInitialized() {
    try {
      return WidgetsBinding.instance;
    } on Error {
      return RaftWidgetsFlutterBinding();
    }
  }
}
