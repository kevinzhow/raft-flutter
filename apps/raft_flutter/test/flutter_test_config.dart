import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show imageCache;
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart'
    show VideoFrameProbe;
import 'package:raft_flutter/data/source_time_formatter.dart'
    show initializeSourceTimeFormatting;
import 'package:raft_ui/raft_ui.dart' show RaftHotImages, RaftImageBytes;

/// Wraps the codecs `PaintingBinding.instantiateImageCodecWithSize` hands to
/// every `ImageProvider` (Image widgets, `precacheImage`, `MemoryImage` ...).
///
/// Flutter's `MultiFrameImageStreamCompleter` disposes its codec when the last
/// listener goes away; a `getNextFrame()` still in flight then completes into a
/// completer that returns without disposing the frame (`_codec == null`), so a
/// widget removed while its image decodes leaks one `ui.Image`. Whether the
/// decode lands before or after the removal depends on machine load, which made
/// the leak report flaky (and it was attributed to whichever test was running
/// when the frame arrived). A frame that arrives after the codec was disposed
/// has no owner, so the wrapper disposes it.
class OwnedFrameCodec implements ui.Codec {
  /// [inner] is the codec the engine produced (a fake in the unit test).
  OwnedFrameCodec(ui.Codec inner) : _inner = inner;
  final ui.Codec _inner;
  bool _disposed = false;

  @override
  int get frameCount => _inner.frameCount;

  @override
  int get repetitionCount => _inner.repetitionCount;

  @override
  Future<ui.FrameInfo> getNextFrame() async {
    final frame = await _inner.getNextFrame();
    if (_disposed) frame.image.dispose();
    return frame;
  }

  @override
  void dispose() {
    _disposed = true;
    _inner.dispose();
  }
}

/// The binding every test in this directory runs on.
///
/// `flutter_test` hands `package:test` an explicit 10 minute timeout for each
/// `testWidgets`, which overrides `dart_test.yaml`, so the bound has to be set
/// on the binding before any test is declared. A hanging test then fails after
/// 60 seconds (`RAFT_TEST_TIMEOUT_SECONDS` overrides) instead of stalling the
/// gate. A test that legitimately needs longer passes its own `timeout:`.
///
/// Every test file now has a test binding, which installs flutter_test's mock
/// `HttpClient` (always 400). A plain `test()` that talks to a real loopback
/// server must set `HttpOverrides.global = null;` first.
///
/// Because this binding exists before a test file's `main` runs, a test file
/// cannot construct its own binding subclass; the two hooks below cover the
/// cases that needed one.
class RaftTestBinding extends AutomatedTestWidgetsFlutterBinding {
  /// Call in `main` to paint real (blurred) shadows, like a device does.
  static void showShadows() {
    _visibleShadows = true;
    debugDisableShadows = false;
  }

  static bool _visibleShadows = false;

  /// Set in `main` to observe the semantics updates each frame sends.
  static ui.SemanticsUpdateBuilder Function()? semanticsBuilderFactory;

  @override
  bool get disableShadows => !_visibleShadows;

  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) async => OwnedFrameCodec(
    await super.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: getTargetSize,
    ),
  );

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      semanticsBuilderFactory?.call() ?? super.createSemanticsUpdateBuilder();
}

/// Leak tracking (`leak_tracker`) runs in every `testWidgets`: an object that
/// reaches the garbage collector without `dispose()` fails its test file
/// ("notDisposed"). `RAFT_LEAK_TRACKING=0` turns it off for a local run.
///
/// Every ignored class below is created once for the life of the process or
/// is held by an [Expando] on a controller/client and reclaimed by GC, so it
/// has no dispose point. Do not add a class that has an owner: fix the owner.
void _enableLeakTracking() {
  if (Platform.environment['RAFT_LEAK_TRACKING'] == '0') return;
  LeakTesting.enable();
  // The shared image cache keeps decoded images (and their handles) after a
  // test ends; they are not leaks of the test, so empty it before the report.
  tearDown(() {
    // Avatars are held by RaftHotImages beyond the widget tree (that is its
    // job); release them with the cache.
    RaftHotImages.instance.releaseAll();
    RaftImageBytes.instance = RaftImageBytes();
    RaftImageBytes.resetClient();
    imageCache
      ..clear()
      ..clearLiveImages();
  });
  // `RAFT_LEAK_STACKS=1` adds the creation stack to every report.
  if (Platform.environment['RAFT_LEAK_STACKS'] == '1') {
    LeakTesting.settings = LeakTesting.settings.withCreationStackTrace();
  }
  // Not-GC'ed tracking stays off (the default; stated so a newer leak_tracker
  // default cannot turn it on): it forces GC cycles in the end-of-file report,
  // which is slow and load-dependent. Only 'notDisposed' is reported.
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    allNotGCed: true,
    classes: const [
      // Process-wide singletons (static `shared` / `instance`).
      '_RaftFocusVisible',
      'NativeSystemFonts',
      'NativeAppIcon',
      'AppUpdater',
      'InviteRequests',
      // Expando-attached caches: live exactly as long as their controller or
      // client and are released with it by GC.
      '_ComposerShared',
      'SavedCountStore',
      'MessageTaskCache',
      '_SetupSignal',
      // Process-wide notifier behind the full-bleed overlay hold.
      '_HoldCount',
    ],
  );
}

/// A test file that still leaks calls this first thing in `main` with the
/// classes it leaks (and a comment saying why). It is the per-file debt ledger:
/// the file stays tracked for everything else, and deleting the line is how the
/// debt is paid. New leaks in a clean file fail it.
void leakDebt(List<String> classes) {
  if (!LeakTesting.enabled) return;
  LeakTesting.settings = LeakTesting.settings.withIgnored(classes: classes);
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  _enableLeakTracking();
  // No test reaches a real platform probe (a native channel or libmpv); a test
  // that wants one passes its own to the card.
  VideoFrameProbe.debugOverride = () => null;
  final binding = RaftTestBinding();
  // An unmocked native call can outlive a widget's fake clock and leave the
  // send's timeout pending. Ordinary fixtures have no device timezone; tests
  // of the native boundary install their own success/failure/stalled handler.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (call) async {
      if (call.method == 'getLocalTimezone') return 'Etc/Unknown';
      throw MissingPluginException(
        'Unexpected timezone method: ${call.method}',
      );
    },
  );
  final seconds =
      int.tryParse(Platform.environment['RAFT_TEST_TIMEOUT_SECONDS'] ?? '') ??
      60;
  binding.defaultTestTimeout = Timeout(Duration(seconds: seconds));
  // Keep this process-wide Future out of any widget's disposable fake clock.
  // Later runAsync calls must never depend on a previous test pumping again.
  await initializeSourceTimeFormatting();
  await testMain();
}
