// Player interaction suite for the system player (video_player: ExoPlayer on
// Android, AVPlayer on Apple): real taps through the gesture arena, real route
// transitions, real network from a range server that counts what it sends.
// Nothing here uses a fake player. Run it with `tool/player-interactions`
// (docs/media-playback.md, "Interaction suite"); the host runner adds what a
// test on the device cannot do itself: Android's back key and back swipe, the
// screen recording of the close animation, the system save dialog.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raft_flutter/features/attachment_view.dart' show AttachmentView;
import 'package:raft_flutter/features/computer_detail_view.dart' show computerFileSize;
import 'package:raft_flutter/features/media_browser.dart';
import 'package:raft_flutter/features/media_image_page.dart' show AttachmentLightboxImage, AttachmentLightboxImageState;
import 'package:raft_flutter/features/media_video_page.dart';
import 'package:raft_flutter/platform/attachment_player.dart' show AttachmentPlayback, kLoopingVideoMaxDuration;
import 'package:raft_flutter/platform/video_cache.dart';
import 'package:raft_flutter/platform/video_frame_scheduler.dart';
import 'package:raft_flutter/platform/video_player_attachment_player.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/player_lab.dart';
import 'support/video_fixture.dart';

const _base = String.fromEnvironment('VP_BASE', defaultValue: 'http://127.0.0.1:8791');
const _hostDriven = bool.fromEnvironment('VP_HOST');
const _only = String.fromEnvironment('VP_ONLY');

/// The background scenarios take the app out of the foreground (another app in
/// front, then back), which a test on the device cannot do itself: they need
/// the host runner and `--define VP_BACKGROUND=true`.
const _background = bool.fromEnvironment('VP_BACKGROUND');

const _portrait = VideoClip('vp-portrait', 'portrait.mp4', 'portrait.mp4', size: 5416578);
const _long = VideoClip('vp-long', 'long.mp4', 'long.mp4', size: 16383818);
const _slow4k = VideoClip('vp-4k', 'hevc4k.mp4', 'hevc4k.mp4', size: 41607413, rate: 2000000);
const _corrupt = VideoClip('vp-corrupt', 'corrupt.mp4', 'broken.mp4', size: 200000);
const _hlg = VideoClip('vp-hlg', 'portrait-hlg.mp4', 'hlg.mp4', size: 5416578);
const _big4k = VideoClip('vp-big4k', 'hevc4k.mp4', 'hevc4k.mp4', size: 41607413);
const _stall = VideoClip('vp-stall', 'portrait.mp4', 'stall.mp4', size: 5416578, rate: 600);
const _choke = VideoClip('vp-choke', 'portrait.mp4', 'choke.mp4', size: 5416578, rate: 90000);
const _longHlg = VideoClip('vp-long-hlg', 'long-hlg.mp4', 'long-hlg.mp4', size: 16385074);
// The media browser's message: videos and images of ONE message, in this order.
const _bA = VideoClip(
  'vp-b-a',
  'portrait.mp4',
  'a.mp4',
  size: 5416578,
  group: 'g',
);
const _bP1 = VideoClip(
  'vp-b-p1',
  'photo1.jpg',
  'p1.jpg',
  size: 55318,
  mime: 'image/jpeg',
  group: 'g',
);
const _bC = VideoClip(
  'vp-b-c',
  'landscape.mp4',
  'c.mp4',
  size: 4846435,
  group: 'g',
);
const _bP2 = VideoClip(
  'vp-b-p2',
  'photo2.jpg',
  'p2.jpg',
  size: 48907,
  mime: 'image/jpeg',
  group: 'g',
);
const _bD = VideoClip(
  'vp-b-d',
  'long.mp4',
  'd.mp4',
  size: 16383818,
  group: 'g',
);
const _bHlg = VideoClip('vp-b-hlg', 'portrait-hlg.mp4', 'h.mp4', size: 5416578, group: 'g');
const _bBad = VideoClip('vp-b-bad', 'corrupt.mp4', 'bad.mp4', size: 200000, group: 'g');

/// [count] items of one message alternating image / video (video first when
/// [videoFirst]); images are photo1..12.jpg, videos cycle the short clips.
List<VideoClip> mixedMessage(int count, {bool videoFirst = false}) {
  const files = [
    ('portrait.mp4', 5416578),
    ('landscape.mp4', 4846435),
    ('hevc1080.mp4', 3762953),
  ];
  var photo = 0, video = 0;
  return [
    for (var i = 0; i < count; i++)
      if ((i.isEven) == videoFirst)
        VideoClip('vp-m$i', files[video % 3].$1, 'm$i.mp4', size: files[video++ % 3].$2, group: 'g')
      else
        VideoClip('vp-m$i', 'photo${++photo}.jpg', 'm$i.jpg', size: 50000, mime: 'image/jpeg', group: 'g'),
  ];
}

/// Photos only: [count] items of one message.
List<VideoClip> photoMessage(int count) => [
  for (var i = 0; i < count; i++)
    VideoClip('vp-q$i', 'photo${i + 1}.jpg', 'q$i.jpg', size: 50000, mime: 'image/jpeg', group: 'g'),
];

/// Every file of the media directory that any scenario asks the range server for.
Set<String> get _requiredMedia => {
  for (final clip in [
    _portrait, _long, _slow4k, _corrupt, _hlg, _big4k, _stall, _choke, _longHlg, //
    _bA, _bP1, _bC, _bP2, _bD, _bHlg, _bBad, _tone,
    ...mixedMessage(12), ...mixedMessage(12, videoFirst: true), ...photoMessage(12),
  ])
    clip.file,
};

/// When each page was the nearest one: how long a passed page was on screen
/// decides whether it may prepare a player (the 250 ms rest).
class PageDwell {
  PageDwell(this.state) {
    state.pages.addListener(_tick);
    _tick();
  }
  final MediaBrowserState state;
  final _clock = Stopwatch()..start();
  final visits = <(int, Duration, Duration?)>[];
  int? _page;

  void _tick() {
    final p = state.pages.page?.round();
    if (p == null || p == _page) return;
    if (visits.isNotEmpty) {
      final last = visits.removeLast();
      visits.add((last.$1, last.$2, _clock.elapsed));
    }
    _page = p;
    visits.add((p, _clock.elapsed, null));
  }

  void stop() => state.pages.removeListener(_tick);

  /// Milliseconds each completed visit lasted, per page, in order.
  Map<String, int> get report => {
    for (final (i, v) in visits.indexed)
      if (v.$3 != null) 'v$i-page${v.$1}': (v.$3! - v.$2).inMilliseconds,
  };
}

const _tone = VideoClip('vp-tone', 'tone.wav', 'tone.wav', size: 264678, mime: 'audio/wav');

late final PlayerLab lab;
bool _mediaChecked = false;

/// No scenario takes longer than this; a stuck one fails (and is cancelled, see
/// [ScenarioToken]) instead of holding the suite.
const _scenarioTimeout = Timeout(Duration(minutes: 4));

/// A scenario; `--dart-define=VP_ONLY=<part of the name>` runs a subset.
///
/// Each scenario is isolated from the ones before it: it starts from a clean
/// slate ([startScenario]) and, when it ends however it ends, its helpers stop
/// ([runAsScenario]), so a failure cannot leak into the next scenario.
void scenario(String name, Future<void> Function(WidgetTester) body) => testWidgets(
  name,
  (tester) => runAsScenario(ScenarioToken(), () async {
    await startScenario(tester);
    await body(tester);
  }),
  skip: _only.isNotEmpty && !_only.split('|').any(name.contains),
  timeout: _scenarioTimeout,
);

/// The state every scenario starts from, whatever ran before: no guarded call
/// of an earlier scenario still in flight, no app tree, no player left alive,
/// the host runner idle (no recording, no dialog, the app in front), the range
/// server's counters, failures and commands cleared.
Future<void> startScenario(WidgetTester tester) async {
  if (!_mediaChecked && _only.isEmpty) {
    // A full run needs the complete media directory: say which files are
    // missing in one place (the runner checks too). Not a test of its own: an
    // extra first test that never pumps a widget changes how the Android back
    // key reaches the app in the scenarios after it.
    _mediaChecked = true;
    try {
      await lab.requireFiles(_requiredMedia);
    } on TestFailure catch (error) {
      report('media-incomplete', {'message': '${error.message}'});
    }
  }
  await waitForBindingIdle();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 500));
  await lab.cleanSlate();
  try {
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'players of the earlier scenario to be released',
        timeout: const Duration(seconds: 15));
  } on TestFailure {
    // A player that outlived its scenario and its tree is that scenario's
    // leak: say so, and count from here so the failure stays with it.
    report('scenario-start-leak', {'live': VideoPlayerAttachmentPlayer.debugLive});
    VideoPlayerAttachmentPlayer.debugLive = 0;
  }
  // Playback only starts in the viewer; layout overrides still exercise responsive chrome.
  MediaBrowserFlags.phoneLayout = false;
}

Finder card(String filename) => posterCard(filename);
Finder posterCard(String filename) => find.byWidgetPredicate((w) => w is RaftVideoPosterCard && w.filename == filename);
RaftVideoPosterCard posterOf(WidgetTester t, String filename) => t.widget<RaftVideoPosterCard>(posterCard(filename));
Finder get viewer => find.byType(RaftVideoViewer);
RaftVideoViewer viewerOf(WidgetTester t) => t.widget<RaftVideoViewer>(viewer);

Future<VideoFixture> launch(WidgetTester tester, List<VideoClip> clips,
    {String mode = 'light', String theme = 'brutal', Future<void> Function()? prepare, String? awaitFile}) async {
  await lab.requireFiles([for (final clip in clips) clip.file]);
  await lab.reset();
  await prepare?.call();
  final fixture = await buildVideoFixture(
    base: _base,
    mobile: true,
    clips: clips,
    location: '/s/lab',
    mode: mode,
    theme: theme,
  );
  await tester.pumpWidget(fixture.app);
  // Deep-linking the channel route opens it empty (see video_parity_main.dart):
  // start from the workspace list and open the channel the way a user does.
  await until(tester, () => find.text('lab-vp').evaluate().isNotEmpty, 'the channel list');
  await tester.tap(find.text('lab-vp').first);
  final first = awaitFile ?? clips.first.filename;
  await until(
      tester,
      () =>
          card(first).evaluate().isNotEmpty ||
          posterCard(first).evaluate().isNotEmpty ||
          find.byTooltip('Preview $first').evaluate().isNotEmpty ||
          find.byKey(const Key('audio-play-toggle')).evaluate().isNotEmpty,
      'the channel with $first');
  return fixture;
}

Future<void> shutdown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 500));
}

bool ready(WidgetTester t, String filename) =>
    posterCard(filename).evaluate().isNotEmpty;

Future<void> openViewer(WidgetTester tester, String filename) async {
  if (viewer.evaluate().isNotEmpty) return;
  await tapCentre(tester, find.descendant(of: card(filename), matching: find.byKey(const Key('inline-video-poster-card'))));
  await until(tester, () => viewer.evaluate().isNotEmpty && viewerOf(tester).duration > Duration.zero, 'the viewer to open $filename');
}

Finder get viewerPlay => find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-play')));

Future<void> playInViewer(WidgetTester tester) async {
  await until(tester, () => viewerPlay.evaluate().isNotEmpty, 'the viewer play button');
  await tapCentre(tester, viewerPlay);
  await until(tester, () => viewerOf(tester).playing && viewerOf(tester).position > const Duration(milliseconds: 800), 'the viewer position to advance');
}

/// Closes the viewer the way [how] says and checks nothing of it is left.
Future<void> closeViewer(WidgetTester tester, String how, String name) async {
  await lab.host(tester, 'record-start:$name');
  await tester.pump(const Duration(milliseconds: 700));
  switch (how) {
    case 'button':
      await tapCentre(tester, find.byTooltip('Close Preview'));
    case 'key':
      final host = await lab.host(tester, 'back');
      if (host == null) await tester.binding.handlePopRoute();
    case 'swipe':
      final host = await lab.host(tester, 'swipe-back');
      if (host == null) await tester.binding.handlePopRoute();
  }
  await until(tester, () => viewer.evaluate().isEmpty, 'the viewer to close ($how)');
  await tester.pump(const Duration(milliseconds: 600));
  await lab.host(tester, 'record-stop');
  expect(find.byType(PlatformViewLink), findsNothing, reason: 'a native video view survived the viewer ($how)');
}

void report(String what, Map<String, Object?> data) => debugPrint('PS-REPORT $what ${jsonEncode(data)}');

/// A report too long for one logcat line: numbered parts, joined by the reader.
void reportParts(String what, Map<String, Object?> data) {
  final text = jsonEncode(data);
  const size = 850;
  final parts = (text.length / size).ceil();
  for (var i = 0; i < parts; i++) {
    debugPrint('PS-REPORT-PART $what $i/$parts ${text.substring(i * size, (i + 1) * size > text.length ? text.length : (i + 1) * size)}');
  }
}

/// Logs the Hero flight frame by frame (the framework's own numbers, one row
/// per rendered frame while something moves): the shuttle's clip rect and
/// corner radius, the bitmap inside it, the scrim, the chrome and the stage
/// picture. `PS-REPORT` lines carry them to the host (docs/media-playback.md).
class HeroLog {
  HeroLog(this.tester, {required this.stage, required this.chrome});
  final WidgetTester tester;
  final Finder stage;
  final double Function() chrome;
  final rows = <List<Object?>>[];
  bool _on = false;
  List<Object?>? _last;

  // Inside a frame callback the guarded `tester.getRect` / `tester.widget` would clash with the
  // test's own `pump`: read the elements and render objects directly.
  Element? _one(Finder f) {
    final found = f.evaluate();
    return found.isEmpty ? null : found.first;
  }

  List<double>? _rect(Finder f) {
    final box = _one(f)?.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final r = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    double v(double x) => double.parse(x.toStringAsFixed(1));
    return [v(r.left), v(r.top), v(r.right), v(r.bottom)];
  }

  /// Per frame: [build ms, raster ms, total ms] from the engine's frame timings (jank check).
  final timings = <List<double>>[];

  void _timed(List<FrameTiming> frames) {
    for (final t in frames) {
      double ms(Duration d) => double.parse((d.inMicroseconds / 1000).toStringAsFixed(1));
      timings.add([ms(t.buildDuration), ms(t.rasterDuration), ms(t.totalSpan)]);
    }
  }

  void start() {
    _on = true;
    SchedulerBinding.instance.addTimingsCallback(_timed);
    SchedulerBinding.instance.addPostFrameCallback(_tick);
    SchedulerBinding.instance.scheduleFrame();
  }

  List<List<Object?>> stop() {
    _on = false;
    return rows;
  }

  /// Stops listening to the engine's frame timings (they arrive a little after the frames).
  void dispose() => SchedulerBinding.instance.removeTimingsCallback(_timed);

  void _tick(Duration stamp) {
    if (!_on) return;
    final binding = SchedulerBinding.instance;
    final shuttle = find.byKey(const ValueKey('media-hero-shuttle'));
    double? radius;
    final clip = _one(shuttle)?.widget;
    if (clip is ClipRRect) {
      final r = clip.borderRadius;
      radius = r is BorderRadius ? double.parse(r.topLeft.x.toStringAsFixed(1)) : null;
    }
    final scrim = _one(find.byKey(const ValueKey('media-scrim')))?.widget;
    final row = <Object?>[
      double.parse((stamp.inMicroseconds / 1000).toStringAsFixed(1)),
      _rect(shuttle),
      radius,
      _rect(find.byKey(const ValueKey('media-hero-shuttle-picture'))),
      scrim is ColoredBox ? double.parse(scrim.color.a.toStringAsFixed(3)) : null,
      double.parse(chrome().toStringAsFixed(2)),
      _rect(stage),
    ];
    final same = _last != null && '${_last!.sublist(1)}' == '${row.sublist(1)}';
    if (!same) rows.add(row);
    _last = row;
    binding.addPostFrameCallback(_tick);
    binding.scheduleFrame();
  }
}

void main() {
  // The host runner's `adb input tap` reaches the app as device pointer events,
  // which the test binding drops unless told otherwise.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().shouldPropagateDevicePointerEvents = _hostDriven;
  lab = PlayerLab(_base, hostDriven: _hostDriven);

  Future<void> playFromPoster(WidgetTester tester, String name, {Duration past = const Duration(seconds: 2)}) async {
    await openViewer(tester, name);
    if (!viewerOf(tester).playing) await playInViewer(tester);
    await until(tester, () => viewerOf(tester).playing && viewerOf(tester).position > past, 'viewer playback past $past');
  }

  // ---- video cards (phone): the poster only, read from the file --------------

  /// The box of a phone card as laid out.
  Size boxOfCard(WidgetTester t, String filename) =>
      t.getSize(find.descendant(of: posterCard(filename), matching: find.byKey(const Key('inline-video'))));

  scenario('video cards V1: no thumbnail, no size: first frame at the real aspect from a few ranged bytes; a tap plays in the viewer', (tester) async {
    MediaBrowserFlags.phoneLayout = true;
    const portrait = VideoClip('vp-c-p', 'portrait.mp4', 'cp.mp4', size: 5416578);
    const landscape = VideoClip('vp-c-l', 'landscape.mp4', 'cl.mp4', size: 4846435);
    const big = VideoClip('vp-c-4k', 'hevc4k.mp4', 'c4k.mp4', size: 41607413);
    await launch(tester, [portrait, landscape, big]);
    expect(find.byType(RaftInlineVideo), findsNothing, reason: 'a phone card has no inline player');
    final firstBoxes = {for (final name in ['cp.mp4', 'cl.mp4', 'c4k.mp4']) name: boxOfCard(tester, name)};
    // The newest message sits at the bottom of the anchored timeline: when its
    // card changes shape, its bottom edge must not move.
    final bottomBefore = tester.getRect(posterCard('c4k.mp4')).bottom;
    for (final name in ['cp.mp4', 'cl.mp4', 'c4k.mp4']) {
      // 16:9 until the file says otherwise.
      expect(firstBoxes[name]!.width / firstBoxes[name]!.height, closeTo(16 / 9, .05), reason: '$name before its frame');
    }
    final started = Stopwatch()..start();
    final shown = <String, int>{};
    await until(tester, () {
      for (final name in ['cp.mp4', 'cl.mp4', 'c4k.mp4']) {
        if (posterCard(name).evaluate().isNotEmpty && posterOf(tester, name).poster != null) {
          shown.putIfAbsent(name, () => started.elapsedMilliseconds);
        }
      }
      return shown.length == 3;
    }, 'the three posters', timeout: const Duration(seconds: 40));
    await tester.pump(const Duration(milliseconds: 300));
    final bottomAfter = tester.getRect(posterCard('c4k.mp4')).bottom;
    final aspects = {
      for (final name in ['cp.mp4', 'cl.mp4', 'c4k.mp4']) name: boxOfCard(tester, name).width / boxOfCard(tester, name).height,
    };
    final stats = await lab.stats();
    report('video-cards-v1', {
      'shownAtMs': shown,
      'aspect': aspects,
      'bytes': {for (final f in ['portrait.mp4', 'landscape.mp4', 'hevc4k.mp4']) f: stats.bytes(f)},
      'requests': {for (final f in ['portrait.mp4', 'landscape.mp4', 'hevc4k.mp4']) f: stats.requests(f)},
      'players': VideoPlayerAttachmentPlayer.debugLive,
      'newestCardBottom': [bottomBefore, bottomAfter],
    });
    expect(bottomAfter, closeTo(bottomBefore, 1.5), reason: 'the anchored timeline keeps the newest row in place');
    expect(aspects['cp.mp4'], closeTo(720 / 1280, .02), reason: 'portrait');
    expect(aspects['cl.mp4'], closeTo(1280 / 720, .02), reason: 'landscape');
    expect(stats.bytes('hevc4k.mp4'), lessThan(41607413 ~/ 10), reason: 'ranged reads, never the file');
    for (final (file, size) in [('portrait.mp4', 5416578), ('landscape.mp4', 4846435)]) {
      expect(stats.bytes(file), lessThan(size ~/ 4), reason: '$file: only what the first frame needs');
    }
    expect(VideoPlayerAttachmentPlayer.debugLive, 0, reason: 'no player session for a card');
    expect(stats.dart('portrait.mp4'), 0, reason: 'the platform probe reads it, not a Dart download');

    // A real tap on the portrait card: the viewer opens and plays at once.
    final shuttle = find.byKey(const ValueKey('media-hero-shuttle'));
    var flew = false;
    // The portrait card is the oldest message: bring it fully into view first.
    await tester.ensureVisible(posterCard('cp.mp4'));
    await tester.pump(const Duration(milliseconds: 300));
    final at = tester.getCenter(posterCard('cp.mp4'));
    final dpr = tester.view.devicePixelRatio;
    // A touch through Android's input stack when the host runner is attached.
    final touched = await lab.host(tester, 'tap:${(at.dx * dpr).round()},${(at.dy * dpr).round()}');
    if (touched == null) await tester.tapAt(at);
    for (var i = 0; i < 400 && !(viewer.evaluate().isNotEmpty && viewerOf(tester).playing && viewerOf(tester).position > const Duration(milliseconds: 800)); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (shuttle.evaluate().isNotEmpty) flew = true;
    }
    expect(viewer.evaluate().isNotEmpty, true, reason: 'the viewer opened');
    expect(viewerOf(tester).playing, true, reason: 'the viewer autoplays');
    expect(viewerOf(tester).position, greaterThan(const Duration(milliseconds: 800)));
    report('video-cards-v1-open', {'heroFlew': flew, 'players': VideoPlayerAttachmentPlayer.debugLive});
    expect(flew, true, reason: 'the poster flew from the card');
    expect(VideoPlayerAttachmentPlayer.debugLive, 1, reason: 'the viewer made the only player');
    await closeViewer(tester, 'key', 'vc1-close');
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'the decoder to be freed with the viewer');
    await shutdown(tester);
  });

  scenario('video cards V2: a list of 10 such videos scrolls with no player session and at most two reads at a time', (tester) async {
    MediaBrowserFlags.phoneLayout = true;
    const files = [('portrait.mp4', 5416578), ('landscape.mp4', 4846435), ('hevc1080.mp4', 3762953)];
    final clips = [
      for (var i = 0; i < 10; i++) VideoClip('vp-c-$i', files[i % 3].$1, 'list$i.mp4', size: files[i % 3].$2),
    ];
    await launch(tester, clips, awaitFile: 'list9.mp4');
    final timings = <int>[];
    void onTimings(List<FrameTiming> frames) {
      for (final f in frames) {
        timings.add(f.totalSpan.inMicroseconds);
      }
    }
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    final list = find.byType(Scrollable).first;
    var maxLive = 0;
    // Fling to the start of the history and back, a few screens each way.
    for (var pass = 0; pass < 4; pass++) {
      await tester.fling(list, Offset(0, pass.isEven ? 700 : -700), 1800);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (VideoPlayerAttachmentPlayer.debugLive > maxLive) maxLive = VideoPlayerAttachmentPlayer.debugLive;
      }
    }
    await tester.pump(const Duration(seconds: 2));
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    final stats = await lab.stats();
    timings.sort();
    final p95 = timings.isEmpty ? 0 : timings[(timings.length * .95).floor().clamp(0, timings.length - 1)];
    final peak = VideoFrameScheduler.shared.peak;
    report('video-cards-v2', {
      'maxLivePlayers': maxLive,
      'frames': timings.length,
      'frameTotalP95Us': p95,
      'frameTotalMaxUs': timings.isEmpty ? 0 : timings.last,
      'over32ms': timings.where((t) => t > 32000).length,
      'bytes': {for (final f in ['portrait.mp4', 'landscape.mp4', 'hevc1080.mp4']) f: stats.bytes(f)},
      'requestsByFile': {for (final f in ['portrait.mp4', 'landscape.mp4', 'hevc1080.mp4']) f: stats.requests(f)},
      'maxSimultaneousFrameReads': peak,
    });
    expect(peak, lessThanOrEqualTo(2), reason: 'the scheduler never runs more than two frame reads');
    expect(maxLive, 0, reason: 'scrolling a list of video cards creates no player session');
    expect(VideoPlayerAttachmentPlayer.debugLive, 0);
    expect(stats.dart('portrait.mp4'), 0);
    await shutdown(tester);
  });


  // ---- image cards: no size in the message ----------------------------------

  scenario('image cards I1: a portrait picture without a size takes its shape after the decode, no letterbox', (tester) async {
    MediaBrowserFlags.phoneLayout = true;
    const nodims = VideoClip('vp-c-img', 'tall.jpg', 'nodims.jpg', size: 152291, mime: 'image/jpeg');
    const dims = VideoClip('vp-c-img2', 'photo1.jpg', 'dims.jpg', size: 55318, mime: 'image/jpeg', width: 1600, height: 1067);
    await launch(tester, [dims, nodims]);
    final card = find.ancestor(of: find.byTooltip('Preview nodims.jpg'), matching: find.byType(AttachmentView));
    final sizes = <List<Object?>>[];
    final watch = Stopwatch()..start();
    Size? last;
    while (watch.elapsed < const Duration(seconds: 6)) {
      if (card.evaluate().isNotEmpty) {
        final size = tester.getSize(card);
        if (size != last) {
          sizes.add([watch.elapsedMilliseconds, double.parse(size.width.toStringAsFixed(1)), double.parse(size.height.toStringAsFixed(1))]);
          last = size;
        }
      }
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 400));
    final box = tester.getSize(card);
    final picture = tester.getSize(find.descendant(of: card, matching: find.byType(Image)).first);
    final withDims = tester.getSize(find.ancestor(of: find.byTooltip('Preview dims.jpg'), matching: find.byType(AttachmentView)));
    report('image-cards-i1', {'cardSizes': sizes, 'box': [box.width, box.height], 'picture': [picture.width, picture.height], 'withDimsBox': [withDims.width, withDims.height]});
    await lab.host(tester, 'shot:image-nodims-after');
    expect(box.width / box.height, closeTo(1080 / 2400, .03), reason: 'the card has the picture\'s portrait shape');
    expect((picture.width - box.width).abs() < 2 && (picture.height - box.height).abs() < 2, true, reason: 'the picture fills its card: no letterbox');
    await shutdown(tester);
  });

  // ---- poster-only timeline and viewer playback ---------------------------
  scenario('timeline: cards create no playback sessions; a click opens the viewer and closing frees it', (tester) async {
    await launch(tester, [_portrait]);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(RaftInlineVideo), findsNothing);
    expect(VideoPlayerAttachmentPlayer.debugLive, 0);
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 800));
    expect(VideoPlayerAttachmentPlayer.debugLive, 1);
    await closeViewer(tester, 'button', 'poster-viewer-close');
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'viewer decoder disposal');
    expect(posterCard('portrait.mp4'), findsOneWidget);
    await shutdown(tester);
  });

  scenario('streaming: a clip starts in the viewer before the whole file arrives', (tester) async {
    await launch(tester, [_slow4k]);
    await playFromPoster(tester, 'hevc4k.mp4', past: const Duration(milliseconds: 500));
    final stats = await lab.stats();
    report('stream-first-frame', {'bytes': stats.bytes('hevc4k.mp4'), 'size': 41607413, 'requests': stats.requests('hevc4k.mp4')});
    expect(stats.player('hevc4k.mp4'), greaterThan(0));
    expect(stats.bytes('hevc4k.mp4'), lessThan(41607413 * .6), reason: 'playback must start before the whole file is read');
    await shutdown(tester);
  });

  Future<void> viewerRoundTrip(WidgetTester tester, String how) async {
    await launch(tester, [_portrait]);
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 500));
    await openViewer(tester, 'portrait.mp4');
    expect(viewerOf(tester).playing, true);
    await closeViewer(tester, how, 'viewer-close-$how');
    expect(card('portrait.mp4'), findsOneWidget);
    await shutdown(tester);
  }

  scenario('viewer: the close button returns', (tester) => viewerRoundTrip(tester, 'button'));
  scenario('viewer: Android back key returns', (tester) => viewerRoundTrip(tester, 'key'));
  scenario('viewer: back swipe returns', (tester) => viewerRoundTrip(tester, 'swipe'));

  scenario('viewer: a cancelled open leaves no playback decoder', (tester) async {
    await launch(tester, [_portrait]);
    await tapCentre(tester, find.descendant(of: card('portrait.mp4'), matching: find.byKey(const Key('inline-video-poster-card'))));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.binding.handlePopRoute();
    await until(tester, () => viewer.evaluate().isEmpty && VideoPlayerAttachmentPlayer.debugLive == 0, 'cancelled viewer disposal');
    expect(posterCard('portrait.mp4'), findsOneWidget);
    await shutdown(tester);
  });

  scenario('viewer: reopening streams again and disposes on each close', (tester) async {
    await launch(tester, [_long]);
    for (var i = 0; i < 3; i++) {
      await playFromPoster(tester, 'long.mp4', past: const Duration(milliseconds: 500));
      expect(VideoPlayerAttachmentPlayer.debugLive, 1);
      await closeViewer(tester, 'button', 'viewer-reopen-$i');
      await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'closed viewer disposal');
    }
    await shutdown(tester);
  });

  Future<void> hdrViewer(WidgetTester tester, VideoClip clip, {double seekTo = 0}) async {
    await launch(tester, [clip]);
    await playFromPoster(tester, clip.filename);
    await until(tester, () => find.byType(PlatformViewLink).evaluate().isNotEmpty, 'HDR native view');
    if (seekTo > 0) {
      final rail = tester.getRect(find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-seek'))));
      final total = viewerOf(tester).duration;
      await tester.tapAt(Offset(rail.left + rail.width * seekTo, rail.center.dy));
      await until(tester, () => viewerOf(tester).position > total * (seekTo - .02), 'HDR seek');
    }
    expect(viewerOf(tester).playing, true);
    await closeViewer(tester, 'button', 'hdr-close-${clip.id}');
    expect(find.byType(PlatformViewLink), findsNothing);
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'HDR decoder disposal');
    await shutdown(tester);
  }
  scenario('HDR: a poster opens the native video view', (tester) => hdrViewer(tester, _hlg));
  scenario('HDR: seeking deep into a long clip', (tester) => hdrViewer(tester, _longHlg, seekTo: .4));

  scenario('viewer: Download saves the whole file (system save dialog)', (tester) async {
    await launch(tester, [_portrait]);
    await openViewer(tester, 'portrait.mp4');
    await tapCentre(tester, find.byKey(const ValueKey('attachment-preview-download')));
    final saved = await lab.host(tester, 'save-dialog:portrait.mp4');
    if (saved == null) {
      markTestSkipped('needs the host runner for the system save dialog');
    } else {
      expect(saved, 'saved:5416578');
      expect((await lab.stats()).bytes('portrait.mp4'), greaterThanOrEqualTo(5416578));
    }
    await shutdown(tester);
  });

  scenario('streaming: an expired signed URL is signed again once', (tester) async {
    final fixture = await launch(tester, [_portrait], prepare: () => lab.failNext('portrait.mp4', status: 403, count: 1));
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 500));
    expect(fixture.urlRequests('vp-portrait'), 2, reason: 'one signature for the 403, one fresh one');
    await shutdown(tester);
  });

  scenario('streaming: a clip the system cannot decode offers download in the viewer', (tester) async {
    await launch(tester, [_corrupt]);
    await tapCentre(tester, find.descendant(of: card('broken.mp4'), matching: find.byKey(const Key('inline-video-poster-card'))));
    await until(tester, () => find.byType(RaftLoadError).evaluate().isNotEmpty, 'the viewer failure state');
    expect(find.byKey(const Key('viewer-download')), findsOneWidget);
    await shutdown(tester);
  });

  scenario('inline audio: a tap plays and the position advances', (tester) async {
    await launch(tester, [_tone]);
    final toggle = find.byKey(const Key('audio-play-toggle'));
    await until(tester, () => toggle.evaluate().isNotEmpty, 'the audio card');
    await tapCentre(tester, toggle);
    await tester.pump(const Duration(seconds: 2));
    final stats = await lab.stats();
    expect(stats.dart('tone.wav'), 0);
    expect(stats.player('tone.wav'), greaterThan(0));
    await shutdown(tester);
  });

  // ---- the viewer's black stage: every state legible in every theme -----------

  scenario('viewer stage: connecting, buffering and failed are legible in every theme', (tester) async {
    for (final (mode, theme) in const [('light', 'brutal'), ('light', 'elegant'), ('dark', 'elegant')]) {
      final tag = '$theme-$mode';
      // Connecting: the host answers a byte a second, so the player has not
      // opened yet when the viewer is on screen.
      await launch(tester, [_stall], mode: mode, theme: theme);
      await tester.pump(const Duration(seconds: 1));
      await tapCentre(tester, find.descendant(of: card('stall.mp4'), matching: find.byKey(const Key('inline-video-poster-card'))));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(viewer, findsNothing, reason: 'the viewer shows the spinner on its stage, not the player yet');
      expect(find.byType(RaftSpinner), findsWidgets);
      expect(find.byType(RaftFileTransferPanel), findsNothing, reason: 'no download panel on the video stage');
      await lab.host(tester, 'shot:stage-connecting-$tag');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await shutdown(tester);
      // Buffering: the host is slower than the clip plays.
      await launch(tester, [_choke], mode: mode, theme: theme);
      await openViewer(tester, 'choke.mp4');
      await tapCentre(tester, viewerPlay);
      await until(tester, () => viewerOf(tester).buffering, 'the viewer to show buffering', timeout: const Duration(seconds: 60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-buffering'))), findsOneWidget);
      await lab.host(tester, 'shot:stage-buffering-$tag');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await shutdown(tester);
      // Failed: a file the system cannot play.
      await launch(tester, [_corrupt], mode: mode, theme: theme);
      await lab.host(tester, 'shot:stage-card-failed-$tag');
      await tapCentre(tester, find.descendant(of: card('broken.mp4'), matching: find.byKey(const Key('inline-video-poster-card'))));
      await until(tester, () => find.byType(RaftLoadError).evaluate().isNotEmpty, 'the viewer failure message');
      await tester.pump(const Duration(milliseconds: 400));
      await lab.host(tester, 'shot:stage-failed-$tag');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await shutdown(tester);
    }
  });

  scenario('memory: browsing video posters retains no playback decoders', (tester) async {
    await launch(tester, [_big4k]);
    await tester.pump(const Duration(seconds: 5));
    expect(VideoPlayerAttachmentPlayer.debugLive, 0);
    await playFromPoster(tester, 'hevc4k.mp4', past: const Duration(seconds: 1));
    expect(VideoPlayerAttachmentPlayer.debugLive, 1);
    await closeViewer(tester, 'button', 'memory-poster-close');
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'viewer release');
    await shutdown(tester);
  });

  // ---- media browser (RAFT_MEDIA_BROWSER_VIDEO) ------------------------------

  MediaBrowserState browserOf(WidgetTester t) =>
      t.state<MediaBrowserState>(find.byType(MediaBrowser));
  MediaVideoStage stageOf(WidgetTester t, int i) => browserOf(t).stageFor(i);
  final browser = find.byType(MediaBrowser);

  /// A finger flick to the next (or previous) page, through the gesture arena.
  Future<void> flick(
    WidgetTester t, {
    bool next = true,
    double velocity = 1800,
  }) async {
    final size = t.getSize(browser);
    await t.flingFrom(
      Offset(size.width / 2, size.height * .4),
      Offset(next ? -size.width * .55 : size.width * .55, 0),
      velocity,
    );
    await t.pump();
  }

  Future<void> onPage(WidgetTester t, int index) => until(
    t,
    () =>
        browser.evaluate().isNotEmpty &&
        browserOf(t).index == index &&
        !browserOf(t).pages.position.isScrollingNotifier.value,
    'page $index at rest',
  );

  Future<void> browserLaunch(WidgetTester t, List<VideoClip> clips) async {
    await launch(t, clips);
  }

  /// Opens the browser from the eye of the video card [name].
  Future<void> openBrowserFromCard(WidgetTester t, String name) async {
    if (browser.evaluate().isNotEmpty) return;
    await tapCentre(
      t,
      find.descendant(
        of: card(name),
        matching: find.byKey(const Key('inline-video-poster-card')),
      ),
    );
    await until(
      t,
      () =>
          browser.evaluate().isNotEmpty &&
          viewer.evaluate().isNotEmpty &&
          viewerOf(t).duration > Duration.zero,
      'the browser to show $name',
    );
  }

  scenario(
    'browser R1+R2: poster opens one player; paging away pauses, back inside 3 s needs no stream',
    (tester) async {
      await browserLaunch(tester, [_bA, _bP1, _bC]);
      expect(VideoPlayerAttachmentPlayer.debugLive, 0);
      await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
      expect(VideoPlayerAttachmentPlayer.debugLive, 1);
      expect(find.byType(PlatformViewLink), findsNothing);
      final playerBefore = (await lab.stats()).player('portrait.mp4');
      // R2: swipe to the image: paused within 200 ms, frozen afterwards.
      await flick(tester);
      await onPage(tester, 1);
      final stage = stageOf(tester, 0);
      await tester.pump(const Duration(milliseconds: 200));
      final frozen = stage.player!.playback.position;
      expect(
        stage.player!.playback.playing,
        false,
        reason: 'the video kept playing after the page was left',
      );
      await tester.pump(const Duration(milliseconds: 1000));
      expect(
        stage.player!.playback.position,
        frozen,
        reason: 'position moved after the page was left',
      );
      // Back inside the 3 s grace: the same player, paused at the same place, no request.
      await flick(tester, next: false);
      await onPage(tester, 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(stage.player!.playback.position, frozen);
      expect(stage.player!.playback.playing, false);
      final back = await lab.stats();
      report('browser-r2', {
        'frozenMs': frozen.inMilliseconds,
        'requestsAfterReturn': back.player('portrait.mp4'),
        'live': VideoPlayerAttachmentPlayer.debugLive,
      });
      expect(
        back.player('portrait.mp4'),
        playerBefore,
        reason: 'returning inside the grace opened a stream',
      );
      // After the grace the browser holds nothing; the card's own rules (it is
      // covered by the route) decide whether its one decoder lives on.
      await flick(tester);
      await onPage(tester, 1);
      await tester.pump(const Duration(seconds: 4));
      report('browser-r2-grace', {
        'live': VideoPlayerAttachmentPlayer.debugLive,
      });
      expect(
        VideoPlayerAttachmentPlayer.debugLive,
        0,
        reason: 'a decoder stayed after leaving the video page',
      );
      expect((await lab.stats()).player('portrait.mp4'), playerBefore);
      await shutdown(tester);
    },
  );

  scenario(
    'browser R5: closing a playing video returns to its poster and disposes playback',
    (tester) async {
      await browserLaunch(tester, [_bA, _bP1, _bC]);
      await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
      await openBrowserFromCard(tester, 'a.mp4');
      await until(
        tester,
        () => viewerOf(tester).position > const Duration(seconds: 2),
        'the browser to play',
      );
      final stats = await lab.stats();
      final playerBefore = stats.player('portrait.mp4');
      final last = viewerOf(tester).position;
      await lab.host(tester, 'record-start:browser-r5-close');
      await tester.pump(const Duration(milliseconds: 500));
      final viewerAt = viewerOf(tester).position;
      await tester.binding.handlePopRoute();
      await until(
        tester,
        () => browser.evaluate().isEmpty,
        'the browser to close',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await lab.host(tester, 'record-stop');
      await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'closed browser decoder disposal');
      expect(posterCard('a.mp4'), findsOneWidget);
      final after = await lab.stats();
      report('browser-r5', {
        'lastViewerMs': last.inMilliseconds,
        'viewerAtCloseMs': viewerAt.inMilliseconds,
        'newRequests': after.player('portrait.mp4') - playerBefore,
      });
      expect(after.player('portrait.mp4'), playerBefore);
      await shutdown(tester);
    },
  );

  scenario(
    'browser R7: a short drag down springs back with no interruption, a long one closes like R5',
    (tester) async {
      await browserLaunch(tester, [_bA, _bP1, _bC]);
      await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
      await openBrowserFromCard(tester, 'a.mp4');
      await until(
        tester,
        () => viewerOf(tester).position > const Duration(seconds: 1),
        'the browser to play',
      );
      final playerBefore = (await lab.stats()).player('portrait.mp4');
      final size = tester.getSize(browser);
      final from = Offset(size.width / 2, size.height * .35);
      // Short and slow: nothing closes, nothing stops, no request.
      // Every playback event during the drag: a pause that is not buffering
      // would be an interruption.
      final pauses = <AttachmentPlayback>[];
      final watch = stageOf(tester, 0).player!.changes.listen((e) {
        if (!e.playing && !e.buffering) pauses.add(e);
      });
      await lab.host(tester, 'record-start:browser-r7-short');
      await tester.flingFrom(from, const Offset(0, 70), 200);
      await tester.pump(const Duration(milliseconds: 400));
      expect(browser, findsOneWidget);
      expect(pauses, isEmpty, reason: 'the short drag paused the video');
      final pos = viewerOf(tester).position;
      await tester.pump(const Duration(milliseconds: 600));
      expect(viewerOf(tester).position, greaterThan(pos));
      await watch.cancel();
      await lab.host(tester, 'record-stop');
      expect((await lab.stats()).player('portrait.mp4'), playerBefore);
      // Past the threshold: the browser closes and the card continues.
      await lab.host(tester, 'record-start:browser-r7-long');
      await tester.flingFrom(from, const Offset(0, 320), 1600);
      await until(
        tester,
        () => browser.evaluate().isEmpty,
        'the drag to close the browser',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await lab.host(tester, 'record-stop');
      await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'drag-close decoder disposal');
      expect(posterCard('a.mp4'), findsOneWidget);
      expect((await lab.stats()).player('portrait.mp4'), playerBefore);
      await shutdown(tester);
    },
  );

  /// A fast horizontal swipe in four quick steps (a thumb flick), through the
  /// gesture arena. Returns when the finger is up.
  final swipeClock = Stopwatch()..start();

  Future<void> swipe(WidgetTester t, {bool next = true, int stepMs = 8}) async {
    final size = t.getSize(browser);
    final y = size.height * .4;
    final dx = size.width * .9 * (next ? -1 : 1);
    final gesture = await t.createGesture();
    await gesture.down(
      Offset(size.width * (next ? .95 : .05), y),
      timeStamp: swipeClock.elapsed,
    );
    for (var i = 0; i < 4; i++) {
      await t.pump(Duration(milliseconds: stepMs));
      await gesture.moveBy(Offset(dx / 4, 0), timeStamp: swipeClock.elapsed);
    }
    await gesture.up(timeStamp: swipeClock.elapsed);
    await t.pump();
  }

  /// Opens the browser on the image [tooltip] of a message whose video cards are
  /// covered, waits until they gave their players back, and starts the counters
  /// from zero: no card holds a player.
  Future<void> openFromImageWithNoCards(WidgetTester t, List<VideoClip> clips, String tooltip, int index) async {
    await browserLaunch(t, clips);
    final image = find.byTooltip(tooltip);
    await until(t, () => image.evaluate().isNotEmpty, 'the image card');
    await t.ensureVisible(image);
    await t.pump(const Duration(milliseconds: 300));
    await tapCentre(t, image);
    await until(t, () => browser.evaluate().isNotEmpty && browserOf(t).index == index, 'the browser on $tooltip');
    await t.pump(const Duration(seconds: 6));
    await until(t, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'the covered cards to release their players',
        timeout: const Duration(seconds: 20));
    await lab.reset();
  }

  Future<void> landOn(WidgetTester t, int page, {bool next = true}) async {
    await flick(t, next: next);
    await onPage(t, page);
  }

  scenario('browser R3+R4: resting prepares one stream, a flick past opens none, the grace frees the decoder', (tester) async {
    await openFromImageWithNoCards(tester, [_bA, _bP1, _bC, _bD, _bP2], 'Preview p1.jpg', 1);
    final idle = await lab.host(tester, 'meminfo:r3-idle');
    final state = browserOf(tester);
    final createdBase = state.w.attachmentMedia.playerSessions.created;
    final dwell = PageDwell(state);
    // R4: three flicks in a row, 1 -> 4: the two videos are only passed.
    for (var i = 0; i < 3; i++) {
      await swipe(tester);
    }
    try {
      await onPage(tester, 4);
    } on TestFailure {
      report('browser-r4-stuck', {'index': state.index, 'dwellMs': dwell.report});
      rethrow;
    }
    dwell.stop();
    await tester.pump(const Duration(milliseconds: 100));
    final flicked = await lab.stats();
    final created = state.w.attachmentMedia.playerSessions.created - createdBase;
    report('browser-r4', {
      'dwellMs': dwell.report,
      'landscapeRequests': flicked.player('landscape.mp4'),
      'longRequests': flicked.player('long.mp4'),
      'portraitRequests': flicked.player('portrait.mp4'),
      'playersCreated': created,
      'live': VideoPlayerAttachmentPlayer.debugLive,
    });
    final passed = {for (final v in dwell.visits) if (v.$3 != null) v.$1: v.$3! - v.$2};
    for (final page in [2, 3]) {
      expect(passed[page], isNotNull, reason: 'page $page was never shown');
      expect(passed[page], lessThan(const Duration(milliseconds: 250)),
          reason: 'page $page stayed ${passed[page]?.inMilliseconds} ms: this device cannot page faster than the settle time');
    }
    expect(flicked.player('landscape.mp4') + flicked.player('long.mp4') + flicked.player('portrait.mp4'), 0, reason: 'a skipped page opened a stream');
    expect(created, 0, reason: 'a skipped page created a player');
    expect(VideoPlayerAttachmentPlayer.debugLive, 0);
    // R3: rest on the long video: one stream after the 250 ms rest, paused.
    await lab.reset();
    // Mid-flick (the page is about to become the current one): nothing yet.
    await flick(tester, next: false);
    await tester.pump(const Duration(milliseconds: 40));
    expect((await lab.stats()).player('long.mp4'), 0, reason: 'prepared before the page rested');
    await onPage(tester, 3);
    await tester.pump(const Duration(milliseconds: 1500));
    final rested = await lab.stats();
    final streams = rested.player('long.mp4');
    final mem = await lab.host(tester, 'meminfo:r3-resting');
    report('browser-r3-rest', {'longRequests': streams, 'ranged': rested.ranged('long.mp4'), 'live': VideoPlayerAttachmentPlayer.debugLive, 'created': state.w.attachmentMedia.playerSessions.created - createdBase});
    expect(streams, greaterThan(0), reason: 'resting did not prepare the page');
    expect(state.w.attachmentMedia.playerSessions.created - createdBase, 1, reason: 'one player for the rested page');
    expect(stageOf(tester, 3).player?.playback.playing, false, reason: 'paging started playback');
    expect(VideoPlayerAttachmentPlayer.debugLive, 1);
    // Away and back inside the grace: the same player, no request.
    await landOn(tester, 4);
    await tester.pump(const Duration(milliseconds: 1200));
    await landOn(tester, 3, next: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect((await lab.stats()).player('long.mp4'), streams, reason: 'returning inside the grace opened a stream');
    expect(VideoPlayerAttachmentPlayer.debugLive, 1);
    // After the grace (no card holds it) the decoder is gone.
    await landOn(tester, 4);
    await tester.pump(const Duration(seconds: 4));
    final after = await lab.host(tester, 'meminfo:r3-after-grace');
    final live = VideoPlayerAttachmentPlayer.debugLive;
    report('browser-r3', {'streams': streams, 'liveAfterGrace': live, 'meminfoIdle': idle, 'meminfoResting': mem, 'meminfoAfterGrace': after});
    expect(live, 0, reason: 'the decoder survived the grace');
    await shutdown(tester);
  });

  scenario('browser R6: paging to another video then closing returns to posters and frees decoders', (tester) async {
    await browserLaunch(tester, [_bA, _bP1, _bC]);
    await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
    await openBrowserFromCard(tester, 'a.mp4');
    await until(tester, () => viewerOf(tester).position > const Duration(seconds: 2), 'the browser to play');
    await landOn(tester, 1);
    await landOn(tester, 2);
    final a = stageOf(tester, 0).player!.playback.position;
    // Play the landscape clip in the browser.
    await until(tester, () => stageOf(tester, 2).player != null && !stageOf(tester, 2).opening, 'the landscape page to be ready');
    await tapCentre(tester, viewerPlay);
    await until(tester, () => viewerOf(tester).playing && viewerOf(tester).position > const Duration(seconds: 1), 'the landscape clip to play');
    final before = await lab.stats();
    final c = viewerOf(tester).position;
    await tester.binding.handlePopRoute();
    await until(tester, () => browser.evaluate().isEmpty, 'the browser to close');
    await tester.pump(const Duration(milliseconds: 800));
    final after = await lab.stats();
    report('browser-r6', {'leftAtMs': a.inMilliseconds, 'viewerAtCloseMs': c.inMilliseconds, 'live': VideoPlayerAttachmentPlayer.debugLive});
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'all browser decoders disposed');
    expect(posterCard('a.mp4'), findsOneWidget);
    expect(posterCard('c.mp4'), findsOneWidget);
    expect(after.player('landscape.mp4') + after.player('portrait.mp4'), before.player('landscape.mp4') + before.player('portrait.mp4'), reason: 'closing opened a stream');
    await shutdown(tester);
  });

  scenario('browser R6b: a browser with no card for the visible video frees its decoder at once on close', (tester) async {
    await openFromImageWithNoCards(tester, [_bA, _bP1, _bC, _bD, _bP2], 'Preview p1.jpg', 1);
    await landOn(tester, 2);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(VideoPlayerAttachmentPlayer.debugLive, 1);
    await tester.binding.handlePopRoute();
    await until(tester, () => browser.evaluate().isEmpty, 'the browser to close');
    final watch = Stopwatch()..start();
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'the decoder to be freed', timeout: const Duration(seconds: 5));
    report('browser-r6b', {'freedAfterMs': watch.elapsedMilliseconds});
    await shutdown(tester);
  });

  scenario('browser R8: the HDR native view only after the page rests, gone at the first moment of a drag, the colour probe is not repeated', (tester) async {
    await openFromImageWithNoCards(tester, [_bA, _bP1, _bHlg, _bP2], 'Preview p1.jpg', 1);
    await flick(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PlatformViewLink), findsNothing, reason: 'a native view while the page was still arriving');
    await onPage(tester, 2);
    await until(tester, () => find.byType(PlatformViewLink).evaluate().isNotEmpty, 'the native view after the rest', timeout: const Duration(seconds: 20));
    final probes = (await lab.stats()).log.where((e) => e['file'] == 'portrait-hlg.mp4' && '${e['ua']}'.startsWith('Dart')).length;
    // A drag begins: the native view is gone at once.
    final size = tester.getSize(browser);
    final finger = await tester.startGesture(Offset(size.width * .8, size.height * .4));
    await finger.moveBy(const Offset(-40, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    report('browser-r8-drag', {'moving': stageOf(tester, 2).moving, 'hdrHold': stageOf(tester, 2).hdrHold != null, 'native': find.byType(PlatformViewLink).evaluate().length});
    expect(find.byType(PlatformViewLink), findsNothing, reason: 'the native view survived the first frames of a swipe');
    await finger.moveBy(const Offset(40, 0));
    await finger.up();
    await until(tester, () => find.byType(PlatformViewLink).evaluate().isNotEmpty, 'the native view to return at rest', timeout: const Duration(seconds: 20));
    // Away and back: no new probe.
    await landOn(tester, 3);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PlatformViewLink), findsNothing, reason: 'the native view stayed on another page');
    await landOn(tester, 2, next: false);
    await until(tester, () => find.byType(PlatformViewLink).evaluate().isNotEmpty, 'the native view after returning', timeout: const Duration(seconds: 20));
    final probesAfter = (await lab.stats()).log.where((e) => e['file'] == 'portrait-hlg.mp4' && '${e['ua']}'.startsWith('Dart')).length;
    report('browser-r8', {'probeRequestsFirst': probes, 'probeRequestsAfterReturn': probesAfter});
    expect(probesAfter, probes, reason: 'the colour probe ran again');
    // A pop removes it at the first frames.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(PlatformViewLink), findsNothing, reason: 'the native view was there when the exit began');
    await until(tester, () => browser.evaluate().isEmpty, 'the browser to close');
    await shutdown(tester);
  });

  scenario('browser R9: one 403 signs again once; an undecodable page fails, re-entry makes no request', (tester) async {
    await openFromImageWithNoCards(tester, [_bA, _bP1, _bC, _bBad], 'Preview p1.jpg', 1);
    // One 403 on the landscape clip: ExoPlayer's open fails once, the app signs again.
    await lab.failNext('landscape.mp4', status: 403, count: 1);
    await landOn(tester, 2);
    await until(tester, () => stageOf(tester, 2).player != null && !stageOf(tester, 2).opening, 'the page to recover from the 403', timeout: const Duration(seconds: 25));
    final stats = await lab.stats();
    report('browser-r9-403', {'failure': '${stageOf(tester, 2).failure}', 'landscapeRequests': stats.player('landscape.mp4'), 'statuses': [for (final e in stats.log.where((e) => e['file'] == 'landscape.mp4')) e['status']]});
    expect(stageOf(tester, 2).failure, isNull, reason: 'a single 403 must not fail the page');
    // The undecodable file.
    await landOn(tester, 3);
    await until(tester, () => stageOf(tester, 3).failure != null, 'the failure of the corrupt clip', timeout: const Duration(seconds: 25));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RaftLoadError), findsOneWidget);
    final first = await lab.stats();
    final requests = first.player('corrupt.mp4');
    // Away (past the grace) and back: the failure again, no request.
    await landOn(tester, 2, next: false);
    await tester.pump(const Duration(seconds: 4));
    await landOn(tester, 3);
    await tester.pump(const Duration(seconds: 2));
    final again = await lab.stats();
    report('browser-r9-bad', {'class': '${stageOf(tester, 3).failure?.kind}', 'requestsFirst': requests, 'requestsAfterReentry': again.player('corrupt.mp4')});
    expect(find.byType(RaftLoadError), findsOneWidget, reason: 'the failure was not shown again');
    expect(again.player('corrupt.mp4'), requests, reason: 're-entry made a request');
    await shutdown(tester);
  });

  scenario('browser R9b: a network-class failure: re-entry makes no request, Retry opens a new stream', (tester) async {
    await openFromImageWithNoCards(tester, [_bA, _bP1, _bD], 'Preview p1.jpg', 1);
    // Five 500s: ExoPlayer gives up (and the one re-sign fails too).
    await lab.failNext('long.mp4', status: 500, count: 5);
    await landOn(tester, 2);
    await until(tester, () => stageOf(tester, 2).failure != null, 'the failure', timeout: const Duration(seconds: 40));
    await tester.pump(const Duration(milliseconds: 500));
    final first = await lab.stats();
    final retry = find.text('Retry');
    expect(retry, findsOneWidget);
    await landOn(tester, 1, next: false);
    await tester.pump(const Duration(seconds: 4));
    await landOn(tester, 2);
    await tester.pump(const Duration(seconds: 2));
    final again = await lab.stats();
    expect(again.player('long.mp4'), first.player('long.mp4'), reason: 're-entry made a request');
    await tapCentre(tester, retry);
    await until(tester, () => stageOf(tester, 2).failure == null && stageOf(tester, 2).player != null && !stageOf(tester, 2).opening, 'the retry to open', timeout: const Duration(seconds: 40));
    final after = await lab.stats();
    report('browser-r9b', {'requestsFirst': first.player('long.mp4'), 'requestsAfterReentry': again.player('long.mp4'), 'requestsAfterRetry': after.player('long.mp4'), 'retryRequests': after.player('long.mp4') - again.player('long.mp4')});
    expect(after.player('long.mp4'), greaterThan(again.player('long.mp4')));
    await shutdown(tester);
  });

  scenario('browser R10: swiping through 12 items (6 videos) resting briefly opens at most one stream per settled video', (tester) async {
    final clips = mixedMessage(12);
    await openFromImageWithNoCards(tester, clips, 'Preview m0.jpg', 0);
    final state = browserOf(tester);
    final createdBase = state.w.attachmentMedia.playerSessions.created;
    final dwell = PageDwell(state);
    for (var page = 1; page < 12; page++) {
      await landOn(tester, page);
      await tester.pump(const Duration(milliseconds: 450));
    }
    dwell.stop();
    await tester.pump(const Duration(milliseconds: 500));
    final stats = await lab.stats();
    final videos = clips.where((c) => c.mime.startsWith('video')).length;
    final opens = state.w.attachmentMedia.playerSessions.created - createdBase;
    final refused = stats.log.where((e) => e['status'] == 429).length;
    report('browser-r10', {'videoPages': videos, 'playersCreated': opens, 'playerRequests': stats.log.where((e) => !'${e['ua']}'.startsWith('Dart') && '${e['file']}'.endsWith('.mp4')).length, 'refused429': refused, 'dwellMs': dwell.report});
    expect(opens, lessThanOrEqualTo(videos), reason: 'more players than settled videos');
    expect(refused, 0);
    await shutdown(tester);
  });

  scenario('browser R11: 12 images: how many originals are decoded and requested while paging', (tester) async {
    final clips = photoMessage(12);
    await browserLaunch(tester, clips);
    final image = find.byTooltip('Preview q0.jpg');
    await until(tester, () => image.evaluate().isNotEmpty, 'the image card');
    await tester.ensureVisible(image);
    await tester.pump(const Duration(milliseconds: 300));
    await tapCentre(tester, image);
    await until(tester, () => browser.evaluate().isNotEmpty && browserOf(tester).index == 0, 'the browser');
    await tester.pump(const Duration(seconds: 3));
    final cache = PaintingBinding.instance.imageCache;
    final live = <int>[];
    final seen = <String>{};
    await lab.reset();
    for (var page = 0; page < 12; page++) {
      if (page > 0) await landOn(tester, page);
      await tester.pump(const Duration(milliseconds: 900));
      live.add(cache.liveImageCount);
      final stats = await lab.stats();
      final requested = {for (final e in stats.log) if ('${e['file']}'.startsWith('photo')) '${e['file']}'};
      seen.addAll(requested);
      // Which originals were asked for so far: the current one and its neighbours.
      final far = [for (final f in requested) int.parse(f.replaceAll(RegExp(r'[^0-9]'), '')) - 1].where((n) => n > page + 1).toList();
      expect(far, isEmpty, reason: 'on page $page originals beyond the next one were requested: $far');
    }
    report('browser-r11', {'liveImagesPerPage': live, 'originalsRequested': seen.length, 'maxLive': live.reduce((a, b) => a > b ? a : b)});
    // The design keeps PR #22's rule (current plus one neighbour each side):
    // at most three decoded originals plus the strip's thumbnails.
    expect(live.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(16));
    await shutdown(tester);
  });

  scenario('browser R12: flick reliability over image and video pages, and a drag on the seek rail seeks without paging', (tester) async {
    final clips = mixedMessage(8);
    await openFromImageWithNoCards(tester, clips, 'Preview m0.jpg', 0);
    var page = 0, hits = 0;
    final dwell = PageDwell(browserOf(tester));
    const plan = [true, true, true, true, true, true, false, false, false, false, false, false];
    for (final next in plan) {
      final target = next ? page + 1 : page - 1;
      await swipe(tester, next: next);
      try {
        await until(tester, () => browserOf(tester).index == target && !browserOf(tester).pages.position.isScrollingNotifier.value, 'page $target', timeout: const Duration(seconds: 4));
        hits++;
        page = target;
      } on TestFailure {
        page = browserOf(tester).index;
      }
      await tester.pump(const Duration(milliseconds: 120));
    }
    dwell.stop();
    report('browser-r12-flicks', {'paged': hits, 'of': plan.length, 'dwellMs': dwell.report});
    expect(hits, plan.length, reason: 'a flick did not page');
    // A drag along the seek rail of a video page (paused: the bar is shown).
    await landOn(tester, 1);
    await until(tester, () => stageOf(tester, 1).player != null && !stageOf(tester, 1).opening && stageOf(tester, 1).player!.playback.duration > Duration.zero, 'the video page to be ready', timeout: const Duration(seconds: 20));
    final rail = find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-seek')));
    await until(tester, () => rail.evaluate().isNotEmpty, 'the seek rail');
    final box = tester.getRect(rail);
    final total = stageOf(tester, 1).player!.playback.duration;
    await tester.timedDragFrom(Offset(box.left + box.width * .15, box.center.dy), Offset(box.width * .6, 0), const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    final at = stageOf(tester, 1).player!.playback.position;
    report('browser-r12-rail', {'positionMs': at.inMilliseconds, 'totalMs': total.inMilliseconds, 'page': browserOf(tester).index});
    expect(browserOf(tester).index, 1, reason: 'a rail drag paged');
    expect(at, greaterThan(total * .5), reason: 'a rail drag did not seek');
    await shutdown(tester);
  });

  scenario('browser R13: no audible player is left after paging off a playing video', (tester) async {
    await browserLaunch(tester, [_bA, _bP1, _bC]);
    await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
    await openBrowserFromCard(tester, 'a.mp4');
    await until(tester, () => viewerOf(tester).position > const Duration(seconds: 2), 'the browser to play');
    final playing = await lab.host(tester, 'audio');
    await landOn(tester, 1);
    await tester.pump(const Duration(milliseconds: 600));
    final off = await lab.host(tester, 'audio');
    report('browser-r13', {'whilePlaying': playing, 'afterPaging': off});
    if (playing != null) {
      expect(playing, startsWith('started=1'), reason: 'the audio session was not visible while playing: $playing');
      expect(off, startsWith('started=0'), reason: 'audio still started after paging off: $off');
    }
    await shutdown(tester);
  });

  // ---- phone browser: taps on the stage (viewer-bugs) ------------------------
  // Real touches through Android's input stack (the host runner's `adb input`),
  // not the binding's pointer injection, so the platform's own tap and
  // double-tap handling is in the loop. Without a host runner they fall back to
  // injected pointers.

  /// A touch at [at] (logical pixels); [twice] makes it a double tap. Returns
  /// after the single-tap window has passed.
  Future<void> realTap(WidgetTester t, Offset at, {bool twice = false}) async {
    final ratio = t.view.devicePixelRatio;
    final command = '${twice ? 'double-tap' : 'tap'}:${(at.dx * ratio).round()},${(at.dy * ratio).round()}';
    final done = await lab.host(t, command);
    if (done == null) {
      await t.tapAt(at);
      if (twice) {
        await t.pump(const Duration(milliseconds: 80));
        await t.tapAt(at);
      }
    }
    await t.pump(const Duration(milliseconds: 600));
  }

  Offset stagePoint(WidgetTester t, {double down = .45}) {
    final rect = t.getRect(find.byKey(const ValueKey('viewer-stage')));
    return Offset(rect.center.dx, rect.top + rect.height * down);
  }

  /// Top bar and bottom band opacities summed: 2 shown, 0 hidden.
  double chromeShown(WidgetTester t) => t
      .widgetList<AnimatedOpacity>(find.descendant(
        of: find.byType(RaftMediaImmersiveShell),
        matching: find.byType(AnimatedOpacity),
      ))
      // The video controls fade too; the two bands are what is counted.
      .where((o) => find.descendant(of: find.byType(RaftVideoViewer), matching: find.byWidget(o)).evaluate().isEmpty)
      .map((o) => o.opacity)
      .fold(0.0, (a, b) => a + b);

  Future<void> expectChrome(WidgetTester t, bool shown, String state) async {
    await t.pump(const Duration(milliseconds: 300));
    expect(browserOf(t).chrome.value, shown, reason: '$state: chrome state');
    expect(chromeShown(t), shown ? 2 : 0, reason: '$state: top bar and bottom band');
  }

  // ---- the on-disk video cache (docs/media-playback.md, "Video cache") --------

  /// Polls the range server until [file] has sent at least [bytes] (the proxy
  /// fetches in windows, behind the player), pumping frames meanwhile.
  Future<ServerStats> waitForBytes(WidgetTester tester, String file, int bytes) async {
    for (var i = 0; i < 100; i++) {
      final stats = await lab.stats();
      if (stats.bytes(file) >= bytes) return stats;
      await tester.pump(const Duration(milliseconds: 200));
    }
    return lab.stats();
  }

  /// What the proxy (the cache) asked the range server for, and what anything
  /// else did (the HDR colour probe reads a few KB itself): (requests, bytes).
  ({int requests, int bytes}) viaProxy(ServerStats stats, String file, {bool proxy = true}) {
    final entries = stats.log.where((e) => e['file'] == file && '${e['ua']}'.startsWith('RaftVideoCache') == proxy);
    return (requests: entries.length, bytes: entries.fold(0, (sum, e) => sum + (e['length'] as int)));
  }

  /// Bytes the app's video cache holds on the device (every account folder).
  Future<int> cachedVideoBytes() async {
    final root = Directory('${(await getApplicationCacheDirectory()).path}/raft-video');
    if (!root.existsSync()) return 0;
    var total = 0;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.chunk')) total += entity.lengthSync();
    }
    return total;
  }

  /// No video cache from an earlier scenario or run: players closed, folders gone.
  Future<void> freshVideoCache() async {
    await VideoCache.debugReset();
    final root = Directory('${(await getApplicationCacheDirectory()).path}/raft-video');
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  /// A playing viewer hides its chrome (and the seek rail with it) after a few seconds; a real tap on the stage brings it back.
  Future<void> showChrome(WidgetTester tester) async {
    final rail = find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-seek')));
    if (rail.evaluate().isNotEmpty) return;
    await realTap(tester, stagePoint(tester, down: .3));
    await until(tester, () => rail.evaluate().isNotEmpty, 'the viewer chrome');
  }

  Future<void> seekOnRail(WidgetTester tester, double at) async {
    await showChrome(tester);
    final rail = tester.getRect(find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-seek'))));
    final total = viewerOf(tester).duration;
    await tester.tapAt(Offset(rail.left + rail.width * at, rail.center.dy));
    await tester.pump(const Duration(milliseconds: 100));
    await until(tester, () => (viewerOf(tester).position - total * at).abs() < const Duration(seconds: 4), 'the seek to ${(at * 100).round()} %');
  }

  scenario('video cache: a video seen once opens again with no upstream bytes (play, seek, close, reopen)', (tester) async {
    await freshVideoCache();
    await launch(tester, [_portrait]);
    // First view: a real tap on the poster opens the viewer; play, then seek with a tap on the rail.
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 1500));
    await seekOnRail(tester, .6);
    // The proxy fetches ahead of the player: wait for the whole file to have come from upstream once.
    final first = await waitForBytes(tester, 'portrait.mp4', 5416578);
    final cached = await cachedVideoBytes();
    final proxied = viaProxy(first, 'portrait.mp4'), others = viaProxy(first, 'portrait.mp4', proxy: false);
    report('video-cache-first', {'proxyRequests': proxied.requests, 'proxyBytes': proxied.bytes, 'otherRequests': others.requests, 'otherBytes': others.bytes, 'cachedOnDisk': cached});
    expect(proxied.bytes, greaterThanOrEqualTo(5416578), reason: 'the whole clip came through the proxy');
    expect(others.bytes, lessThan(1024 * 1024), reason: 'only a small probe read the server itself, never a download');
    expect(cached, greaterThanOrEqualTo(5416578), reason: 'the chunks are on disk');
    await closeViewer(tester, 'key', 'video-cache-first-close');
    await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'the closed viewer to free its player');

    // Reopen the same video (a new player each time): nothing is fetched. Recorded.
    for (var i = 1; i <= 2; i++) {
      await lab.host(tester, 'record-start:video-cache-reopen-$i');
      await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 1500));
      await seekOnRail(tester, .3 + .3 * i);
      await lab.host(tester, 'record-stop');
      final again = await lab.stats();
      final now = viaProxy(again, 'portrait.mp4');
      report('video-cache-reopen-$i', {'proxyRequests': now.requests, 'proxyBytes': now.bytes, 'serverBytes': again.bytes('portrait.mp4')});
      expect(now.bytes, proxied.bytes, reason: 'reopen $i fetched bytes again');
      expect(now.requests, proxied.requests, reason: 'reopen $i made a request');
      await closeViewer(tester, 'key', 'video-cache-reopen-$i-close');
      await until(tester, () => VideoPlayerAttachmentPlayer.debugLive == 0, 'the closed viewer to free its player');
    }
    await shutdown(tester);
  });

  scenario('video loop: a clip of 60 seconds or less repeats by itself; the repeat costs the server nothing', (tester) async {
    await freshVideoCache();
    await launch(tester, [_portrait]);
    await lab.host(tester, 'record-start:video-loop-short');
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 1000));
    final total = viewerOf(tester).duration;
    expect(total, lessThanOrEqualTo(kLoopingVideoMaxDuration));
    // Watch two wraps worth of time: the position climbs to the end, falls back near the start and the clip is still playing.
    var late = false, wrapped = 0, stopped = 0;
    var last = viewerOf(tester).position;
    final started = Stopwatch()..start();
    while (started.elapsed < total * 2 + const Duration(seconds: 4) && wrapped < 2) {
      await tester.pump(const Duration(milliseconds: 100));
      final now = viewerOf(tester);
      if (!now.playing) stopped++;
      if (now.position > total - const Duration(seconds: 4)) late = true;
      if (late && now.position < last - total * .5) {
        wrapped++;
        late = false;
        expect(now.playing, true, reason: 'the clip stopped at its end instead of repeating');
      }
      last = now.position;
    }
    await lab.host(tester, 'record-stop');
    final stats = await lab.stats();
    report('video-loop-short', {'totalMs': total.inMilliseconds, 'wraps': wrapped, 'samplesNotPlaying': stopped, 'proxyBytes': viaProxy(stats, 'portrait.mp4').bytes});
    expect(wrapped, greaterThanOrEqualTo(2), reason: 'the position must wrap from the end back to the start, twice');
    expect(stopped, lessThan(5), reason: 'it keeps playing through the repeat');
    expect(viaProxy(stats, 'portrait.mp4').bytes, lessThanOrEqualTo(5416578), reason: 'repeating read nothing again');
    await closeViewer(tester, 'key', 'video-loop-short-close');
    await shutdown(tester);
  });

  scenario('video loop: a clip over 60 seconds stops at its end and stays there', (tester) async {
    await freshVideoCache();
    await launch(tester, [_long]);
    await playFromPoster(tester, 'long.mp4', past: const Duration(milliseconds: 1000));
    final total = viewerOf(tester).duration;
    expect(total, greaterThan(kLoopingVideoMaxDuration));
    await lab.host(tester, 'record-start:video-loop-long-end');
    await seekOnRail(tester, .985);
    await until(tester, () => !viewerOf(tester).playing && viewerOf(tester).position >= total - const Duration(milliseconds: 1500), 'the long clip to stop at its end', timeout: const Duration(seconds: 40));
    final ended = viewerOf(tester).position;
    await tester.pump(const Duration(seconds: 5));
    await lab.host(tester, 'record-stop');
    report('video-loop-long', {'totalMs': total.inMilliseconds, 'endedAtMs': ended.inMilliseconds, 'after5sMs': viewerOf(tester).position.inMilliseconds, 'playing': viewerOf(tester).playing});
    expect(viewerOf(tester).playing, false, reason: 'a long clip must not repeat');
    expect(viewerOf(tester).position, greaterThanOrEqualTo(total - const Duration(milliseconds: 1500)), reason: 'it stayed at the end');
    await closeViewer(tester, 'key', 'video-loop-long-close');
    await shutdown(tester);
  });

  /// From a channel to Settings > [destination] with real taps (the Back key leaves the channel).
  Future<void> openSettings(WidgetTester tester, String destination) async {
    final tab = find.byKey(const Key('mobile-tab-settings'));
    for (var i = 0; i < 3 && tab.evaluate().isEmpty; i++) {
      await lab.host(tester, 'back');
      await tester.pump(const Duration(milliseconds: 700));
    }
    await realTap(tester, tester.getCenter(tab));
    final item = find.byKey(ValueKey('workspace-settings-nav-$destination'));
    await until(tester, () => item.evaluate().isNotEmpty, 'the Settings list');
    await tester.ensureVisible(item);
    await tester.pump(const Duration(milliseconds: 300));
    await realTap(tester, tester.getCenter(item));
    await until(tester, () => find.byKey(ValueKey('settings-page-$destination')).evaluate().isNotEmpty || find.byKey(const Key('storage-video-size')).evaluate().isNotEmpty || find.byKey(const Key('account-logout')).evaluate().isNotEmpty, 'the $destination page');
  }

  String videoCacheLine(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: find.byKey(const Key('storage-video-size')), matching: find.byType(Text)))
      .data!;

  scenario('video cache: Settings > Storage shows the size, and Clear empties it', (tester) async {
    await freshVideoCache();
    await launch(tester, [_portrait]);
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 1500));
    await waitForBytes(tester, 'portrait.mp4', 5416578);
    final onDisk = await cachedVideoBytes();
    expect(onDisk, greaterThanOrEqualTo(5416578));
    await closeViewer(tester, 'key', 'video-cache-settings-close');
    await lab.host(tester, 'record-start:video-cache-settings');
    await openSettings(tester, 'storage');
    final block = find.byKey(const Key('storage-video-size'));
    await tester.ensureVisible(block);
    await until(tester, () => !videoCacheLine(tester).contains('Calculating'), 'the size to be measured');
    await lab.host(tester, 'shot:video-cache-settings-size');
    expect(videoCacheLine(tester), 'Video cache: ${computerFileSize(onDisk)}');
    final clear = find.byKey(const Key('storage-video-clear'));
    await tester.ensureVisible(clear);
    await tester.pump(const Duration(milliseconds: 300));
    await realTap(tester, tester.getCenter(clear));
    await until(tester, () => videoCacheLine(tester) == 'Video cache: 0 B', 'the size to read 0 B after Clear');
    await lab.host(tester, 'shot:video-cache-settings-cleared');
    await lab.host(tester, 'record-stop');
    final after = await cachedVideoBytes();
    report('video-cache-clear', {'beforeBytes': onDisk, 'afterBytes': after, 'line': videoCacheLine(tester)});
    expect(after, 0, reason: 'Clear emptied the folder on disk');
    expect(tester.widget<RaftSettingsRecipeButton>(clear).onPressed, isNull, reason: 'nothing left to clear');
    await shutdown(tester);
  });

  scenario('video cache: logging out deletes the account\'s cached videos', (tester) async {
    await freshVideoCache();
    await launch(tester, [_portrait]);
    await playFromPoster(tester, 'portrait.mp4', past: const Duration(milliseconds: 1500));
    await waitForBytes(tester, 'portrait.mp4', 5416578);
    await closeViewer(tester, 'key', 'video-cache-logout-close');
    final root = Directory('${(await getApplicationCacheDirectory()).path}/raft-video');
    final folders = root.listSync().whereType<Directory>().toList();
    expect(folders, hasLength(1), reason: 'one account, one folder');
    expect(await cachedVideoBytes(), greaterThanOrEqualTo(5416578));
    await openSettings(tester, 'account');
    final logout = find.byKey(const Key('account-logout'));
    await tester.ensureVisible(logout);
    await tester.pump(const Duration(milliseconds: 300));
    await realTap(tester, tester.getCenter(logout));
    final confirm = find.byKey(const Key('account-logout-confirm-button'));
    await until(tester, () => confirm.evaluate().isNotEmpty, 'the log-out confirmation');
    await realTap(tester, tester.getCenter(confirm));
    // Signed out: the sign-in screen is up and the account's folder is gone.
    for (var i = 0; i < 100 && folders.first.existsSync(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    report('video-cache-logout', {'folderExists': folders.first.existsSync(), 'bytes': await cachedVideoBytes()});
    expect(folders.first.existsSync(), isFalse, reason: 'the account folder is deleted at log-out');
    expect(await cachedVideoBytes(), 0);
    await lab.host(tester, 'shot:video-cache-logout');
    await shutdown(tester);
  });

  scenario('browser V1: a real tap on a playing video page shows and hides its controls with the chrome; pause and seek work', (tester) async {
    await browserLaunch(tester, [_bA, _bP1]);
    await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
    await openBrowserFromCard(tester, 'a.mp4');
    final bar = find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-bar')));
    final toggle = find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-toggle')));
    await until(tester, () => viewerOf(tester).playing && viewerOf(tester).position > const Duration(seconds: 1), 'the page to play');
    await lab.host(tester, 'record-start:viewer-bugs-video');
    await lab.host(tester, 'shot:viewer-bugs-video-1-playing');
    if (!browserOf(tester).chrome.value) {
      // The page played for 3 s while the test waited: it went immersive by itself.
      await realTap(tester, stagePoint(tester, down: .3));
      await expectChrome(tester, true, 're-shown after the auto-hide');
    }
    expect(browserOf(tester).chrome.value, true);
    expect(bar, findsOneWidget, reason: 'playing, chrome shown: the controls are there');
    await realTap(tester, stagePoint(tester, down: .3));
    await expectChrome(tester, false, 'tap 1');
    expect(bar, findsNothing, reason: 'the controls go with the chrome');
    await lab.host(tester, 'shot:viewer-bugs-video-2-hidden');
    await realTap(tester, stagePoint(tester, down: .3));
    await expectChrome(tester, true, 'tap 2');
    expect(bar, findsOneWidget, reason: 'a tap brings the controls back');
    // Playing under visible chrome: it leaves by itself after 3 s.
    await tester.pump(const Duration(milliseconds: 4200));
    expect(browserOf(tester).chrome.value, false, reason: 'auto-hide after 3 s');
    await tester.pump(const Duration(milliseconds: 400));
    expect(bar, findsNothing, reason: 'the controls went with the chrome');
    await realTap(tester, stagePoint(tester, down: .3));
    await expectChrome(tester, true, 'tap 3');
    // Pause with a real touch on the bar's button.
    await realTap(tester, tester.getCenter(toggle));
    await until(tester, () => !viewerOf(tester).playing, 'the bar button to pause');
    final frozen = viewerOf(tester).position;
    await tester.pump(const Duration(milliseconds: 800));
    expect(viewerOf(tester).position, frozen, reason: 'paused: the position holds');
    expect(bar, findsOneWidget, reason: 'paused never hides the controls');
    await lab.host(tester, 'shot:viewer-bugs-video-3-paused');
    // Seek with a real touch on the rail.
    final rail = tester.getRect(find.descendant(of: viewer, matching: find.byKey(const Key('inline-video-seek'))));
    final total = viewerOf(tester).duration;
    await realTap(tester, Offset(rail.left + rail.width * .8, rail.center.dy));
    await until(tester, () => viewerOf(tester).position > total * .6, 'the rail tap to seek');
    final seeked = viewerOf(tester).position;
    report('viewer-bugs-video', {'frozenMs': frozen.inMilliseconds, 'seekedMs': seeked.inMilliseconds, 'totalMs': total.inMilliseconds});
    // Play again from the bar, then pause once more.
    await realTap(tester, tester.getCenter(toggle));
    await until(tester, () => viewerOf(tester).playing && viewerOf(tester).position > seeked + const Duration(milliseconds: 600), 'playing again');
    await lab.host(tester, 'record-stop');
    await shutdown(tester);
  });

  const slowPhoto = VideoClip('vp-slow', 'photo1.jpg', 's0.jpg', size: 55318, mime: 'image/jpeg', group: 'g', rate: 4500, width: 1600, height: 1067, text: 'A slow original with a caption under it');
  const otherPhoto = VideoClip('vp-slow2', 'photo2.jpg', 's1.jpg', size: 48907, mime: 'image/jpeg', group: 'g');

  scenario('browser I1: real tap, double tap and pinch on the thumbnail stand-in while the original downloads; the zoom carries over', (tester) async {
    await browserLaunch(tester, [slowPhoto, otherPhoto]);
    final card = find.byTooltip('Preview s0.jpg');
    await until(tester, () => card.evaluate().isNotEmpty, 'the image card');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    await tapCentre(tester, card);
    await until(tester, () => browser.evaluate().isNotEmpty && browserOf(tester).index == 0, 'the browser');
    AttachmentLightboxImageState page() => tester.state<AttachmentLightboxImageState>(find.byType(AttachmentLightboxImage).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(page().full, isNull, reason: 'the original must still be downloading for this scenario');
    await lab.host(tester, 'record-start:viewer-bugs-standin');
    await lab.host(tester, 'shot:viewer-bugs-standin-1-open');
    // Single tap toggles the chrome (top bar and bottom band together).
    await realTap(tester, stagePoint(tester, down: .3));
    await expectChrome(tester, false, 'stand-in tap 1');
    await lab.host(tester, 'shot:viewer-bugs-standin-2-hidden');
    await realTap(tester, stagePoint(tester, down: .3));
    await expectChrome(tester, true, 'stand-in tap 2');
    // Double tap zooms the stand-in.
    await realTap(tester, stagePoint(tester), twice: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(page().full, isNull, reason: 'still the stand-in');
    expect(browserOf(tester).zoomed, true, reason: 'double tap zoomed the stand-in');
    await lab.host(tester, 'shot:viewer-bugs-standin-3-zoomed');
    // Pinch (two injected pointers) zooms further.
    final before = browserOf(tester).zoomFor(0).value.getMaxScaleOnAxis();
    final centre = stagePoint(tester);
    final a = await tester.startGesture(centre - const Offset(30, 0), pointer: 21);
    final b = await tester.startGesture(centre + const Offset(30, 0), pointer: 22);
    for (var i = 0; i < 8; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 300));
    final zoomedStandIn = browserOf(tester).zoomFor(0).value.clone();
    expect(zoomedStandIn.getMaxScaleOnAxis(), greaterThan(before), reason: 'pinch zoomed the stand-in further');
    // The original arrives: the zoom stays.
    await until(tester, () => page().full != null, 'the original to arrive', timeout: const Duration(seconds: 60));
    await tester.pump(const Duration(milliseconds: 600));
    expect(browserOf(tester).zoomFor(0).value, zoomedStandIn, reason: 'the zoom jumped when the original arrived');
    await lab.host(tester, 'shot:viewer-bugs-standin-4-original');
    await lab.host(tester, 'record-stop');
    report('viewer-bugs-standin', {'scaleBefore': before, 'scaleStandIn': zoomedStandIn.getMaxScaleOnAxis()});
    await shutdown(tester);
  });

  const bandA = VideoClip('vp-band-a', 'photo3.jpg', 'b0.jpg', size: 50000, mime: 'image/jpeg', group: 'g', text: 'Hall walkthrough, second floor, with a caption long enough to need more than two lines on a phone screen so that it can be expanded by a tap.');
  const bandB = VideoClip('vp-band-b', 'photo4.jpg', 'b1.jpg', size: 50000, mime: 'image/jpeg', group: 'g');
  const bandC = VideoClip('vp-band-c', 'photo5.jpg', 'b2.jpg', size: 50000, mime: 'image/jpeg', group: 'g');

  Rect? openedFrom;

  Future<void> openBandBrowser(WidgetTester tester, List<VideoClip> clips, String tooltip) async {
    await browserLaunch(tester, clips);
    final card = find.byTooltip(tooltip);
    await until(tester, () => card.evaluate().isNotEmpty, 'the image card');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    openedFrom = tester.getRect(card);
    await tapCentre(tester, card);
    await until(tester, () => browser.evaluate().isNotEmpty && browserOf(tester).index == 0, 'the browser');
    await until(tester, () => tester.state<AttachmentLightboxImageState>(find.byType(AttachmentLightboxImage).first).full != null, 'the original');
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// A point in the bottom band's backdrop: just above its first content.
  Offset bandBackdrop(WidgetTester t) {
    final caption = find.byKey(const ValueKey('media-caption'));
    final strip = find.byKey(const ValueKey('lightbox-thumbnails'));
    if (caption.evaluate().isNotEmpty) return Offset(t.getCenter(caption).dx, t.getTopLeft(caption).dy - 6);
    if (strip.evaluate().isNotEmpty) return Offset(t.getCenter(strip).dx, t.getTopLeft(strip).dy - 6);
    final size = t.getSize(browser);
    return Offset(size.width / 2, size.height - 4);
  }

  // Two real fingers (kernel-level multi-touch injected by the host runner, MT
  // protocol B), at fit scale on the first of three pictures: the pinch must zoom
  // and the pager must stay on the page, whatever the timing of the fingers.
  scenario(
    'browser P1: a real two-finger pinch at fit scale zooms and never pages (simultaneous, late second finger with drift, asymmetric, vertical)',
    (tester) async {
      await openBandBrowser(tester, [bandA, bandB, bandC], 'Preview b0.jpg');
      final results = <String, List<Map<String, Object?>>>{};
      final failures = <String>[];
      for (final variant in [
        'simultaneous',
        'late-drift',
        'asymmetric',
        'vertical',
      ]) {
        for (var trial = 0; trial < 3; trial++) {
          final b = browserOf(tester);
          b.zoomFor(0).value = Matrix4.identity();
          if (b.index != 0) b.goTo(0);
          await tester.pump(const Duration(milliseconds: 900));
          final centre = tester.getCenter(
            find.byKey(const ValueKey('viewer-stage')),
          );
          final ratio = tester.view.devicePixelRatio;
          // The farthest the pager left the page while the fingers were down: a
          // swipe that won shows here even when it springs back afterwards.
          var peak = 0.0;
          void watch() => peak = math.max(peak, (b.pages.page ?? 0).abs());
          b.pages.position.addListener(watch);
          await lab.host(
            tester,
            'pinch:$variant:${(centre.dx * ratio).round()},${(centre.dy * ratio).round()},$ratio',
          );
          await tester.pump(const Duration(milliseconds: 700));
          b.pages.position.removeListener(watch);
          final scale = b.zoomFor(0).value.getMaxScaleOnAxis();
          final row = <String, Object?>{
            'scale': scale,
            'index': b.index,
            'page': b.pages.page,
            'peakPageOffset': double.parse(peak.toStringAsFixed(3)),
            'zoomed': b.zoomed,
          };
          results.putIfAbsent(variant, () => []).add(row);
          report('pinch-$variant-$trial', row);
          if (!(b.zoomed && scale > 1.2 && b.pages.page == 0.0)) {
            failures.add('$variant#$trial');
          }
          await lab.host(tester, 'shot:pinch-$variant-$trial');
        }
      }
      // The committed swipe: the first finger moved past the touch slop alone, so
      // the pager keeps the gesture. It must settle on a page and not stay stuck.
      for (var trial = 0; trial < 2; trial++) {
        final b = browserOf(tester);
        b.zoomFor(0).value = Matrix4.identity();
        if (b.index != 0) b.goTo(0);
        await tester.pump(const Duration(milliseconds: 900));
        final centre = tester.getCenter(
          find.byKey(const ValueKey('viewer-stage')),
        );
        final ratio = tester.view.devicePixelRatio;
        await lab.host(
          tester,
          'pinch:late-committed:${(centre.dx * ratio).round()},${(centre.dy * ratio).round()},$ratio',
        );
        await tester.pump(const Duration(milliseconds: 900));
        final page = b.pages.page!;
        report('pinch-late-committed-$trial', {
          'scale': b.zoomFor(0).value.getMaxScaleOnAxis(),
          'index': b.index,
          'page': page,
          'zoomed': b.zoomed,
        });
        expect(
          page,
          page.roundToDouble(),
          reason: 'late-committed#$trial: the pager settled on a page',
        );
      }
      final slop = tester.view.gestureSettings.physicalTouchSlop;
      report('pinch-device-slop', {
        'physicalTouchSlop': slop,
        'dpr': tester.view.devicePixelRatio,
      });

      // Controls (one finger, real `input swipe`): unchanged by the fix.
      Future<void> swipe(
        double x1,
        double y1,
        double x2,
        double y2,
        int ms,
      ) async {
        final ratio = tester.view.devicePixelRatio;
        String px(double v) => '${(v * ratio).round()}';
        await lab.host(
          tester,
          'swipe:${px(x1)},${px(y1)},${px(x2)},${px(y2)},$ms',
        );
        await tester.pump(const Duration(milliseconds: 900));
      }

      final rect = tester.getRect(find.byKey(const ValueKey('viewer-stage')));
      final b = browserOf(tester);
      b.zoomFor(0).value = Matrix4.identity();
      if (b.index != 0) b.goTo(0);
      await tester.pump(const Duration(milliseconds: 900));
      await swipe(
        rect.width * .8,
        rect.center.dy,
        rect.width * .2,
        rect.center.dy,
        200,
      );
      report('control-swipe-at-fit', {'index': b.index, 'zoomed': b.zoomed});
      expect(b.index, 1, reason: 'one finger at fit scale still pages');
      b.goTo(0);
      await tester.pump(const Duration(milliseconds: 900));
      // Zoomed by a real pinch; then one finger pans the picture.
      final pinchAt = tester.getCenter(
        find.byKey(const ValueKey('viewer-stage')),
      );
      final dpr = tester.view.devicePixelRatio;
      await lab.host(
        tester,
        'pinch:simultaneous:${(pinchAt.dx * dpr).round()},${(pinchAt.dy * dpr).round()},$dpr',
      );
      await tester.pump(const Duration(milliseconds: 900));
      final tx = b.zoomFor(0).value.storage[12];
      await swipe(
        rect.width * .8,
        rect.center.dy,
        rect.width * .4,
        rect.center.dy,
        300,
      );
      report('control-pan-zoomed', {
        'index': b.index,
        'zoomed': b.zoomed,
        'scale': b.zoomFor(0).value.getMaxScaleOnAxis(),
        'txBefore': tx,
        'txAfter': b.zoomFor(0).value.storage[12],
      });
      expect(b.index, 0, reason: 'zoomed, one finger pans instead of paging');
      expect(
        b.zoomFor(0).value.storage[12],
        isNot(tx),
        reason: 'the picture panned',
      );
      b.zoomFor(0).value = Matrix4.identity();
      await tester.pump(const Duration(milliseconds: 900));
      await swipe(
        rect.center.dx,
        rect.top + rect.height * .3,
        rect.center.dx + 10,
        rect.top + rect.height * .8,
        200,
      );
      report('control-dismiss', {'closed': browser.evaluate().isEmpty});
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        browser.evaluate(),
        isEmpty,
        reason: 'one finger down closes the viewer',
      );
      expect(
        failures,
        isEmpty,
        reason: 'pinches that did not zoom, or paged: $failures',
      );
      await shutdown(tester);
    },
  );

  scenario('browser B1: every real tap on the stage hides and shows the top bar and the bottom band: picture, backdrop, caption expanded, after paging and zoom', (tester) async {
    await openBandBrowser(tester, [bandA, bandB, bandC], 'Preview b0.jpg');
    await lab.host(tester, 'record-start:viewer-bugs-band');
    await lab.host(tester, 'shot:viewer-bugs-band-1-shown');
    await expectChrome(tester, true, 'start');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, false, 'picture tap hides');
    await lab.host(tester, 'shot:viewer-bugs-band-2-hidden');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, true, 'picture tap shows');
    // The band's own backdrop (above the caption) is part of the stage.
    await realTap(tester, bandBackdrop(tester));
    await expectChrome(tester, false, 'backdrop tap hides');
    await realTap(tester, stagePoint(tester, down: .2));
    await expectChrome(tester, true, 'letterbox tap shows');
    // The caption expands; the stage tap still hides the whole band.
    final caption = find.byKey(const ValueKey('media-caption'));
    final collapsed = tester.getSize(caption).height;
    await realTap(tester, tester.getCenter(caption));
    await tester.pump(const Duration(milliseconds: 300));
    await lab.host(tester, 'shot:viewer-bugs-band-3-expanded');
    report('viewer-bugs-caption', {'collapsed': collapsed, 'after': tester.getSize(caption).height});
    expect(tester.getSize(caption).height, greaterThan(collapsed), reason: 'the caption expanded');
    await expectChrome(tester, true, 'caption tap keeps the chrome');
    await realTap(tester, stagePoint(tester, down: .2));
    await expectChrome(tester, false, 'tap hides with the caption expanded');
    await realTap(tester, stagePoint(tester, down: .2));
    await expectChrome(tester, true, 'tap shows with the caption expanded');
    // After paging.
    await flick(tester);
    await onPage(tester, 1);
    await tester.pump(const Duration(seconds: 1));
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, false, 'after paging, tap hides');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, true, 'after paging, tap shows');
    // Zoom (hides the chrome), come back from it.
    await realTap(tester, stagePoint(tester), twice: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(browserOf(tester).zoomed, true);
    await expectChrome(tester, false, 'zoomed: chrome out of the way');
    await realTap(tester, stagePoint(tester, down: .2));
    await expectChrome(tester, true, 'zoomed, tap brings the bars back');
    await realTap(tester, bandBackdrop(tester));
    await expectChrome(tester, false, 'zoomed, backdrop tap hides');
    await realTap(tester, stagePoint(tester), twice: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(browserOf(tester).zoomed, false, reason: 'double tap returns to fit');
    await lab.host(tester, 'record-stop');
    await shutdown(tester);
  });

  scenario('browser B2: a single image has the same chrome toggle; so does landscape', (tester) async {
    await openBandBrowser(tester, [const VideoClip('vp-band-one', 'photo6.jpg', 'one.jpg', size: 50000, mime: 'image/jpeg', group: 'g')], 'Preview one.jpg');
    await lab.host(tester, 'record-start:viewer-bugs-band-single');
    await expectChrome(tester, true, 'single start');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, false, 'single: picture tap hides');
    await lab.host(tester, 'shot:viewer-bugs-band-single-hidden');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, true, 'single: picture tap shows');
    await realTap(tester, bandBackdrop(tester));
    await expectChrome(tester, false, 'single: backdrop tap hides');
    await realTap(tester, stagePoint(tester, down: .2));
    await expectChrome(tester, true, 'single: tap shows');
    await lab.host(tester, 'record-stop');
    await shutdown(tester);
  });

  scenario('browser B4: a tall image fits between the bars; the whole stage once the chrome is hidden', (tester) async {
    await openBandBrowser(
      tester,
      [
        const VideoClip('vp-band-tall', 'tall.jpg', 'tall.jpg', size: 100000, mime: 'image/jpeg', group: 'g', width: 1080, height: 2400, text: 'A tall picture with a caption'),
        bandB,
      ],
      'Preview tall.jpg',
    );
    final image = find.byKey(const ValueKey('attachment-image-vp-band-tall'));
    final strip = find.byKey(const ValueKey('lightbox-thumbnails'));
    await lab.host(tester, 'record-start:viewer-bugs-tall');
    await tester.pump(const Duration(milliseconds: 400));
    final shown = tester.getRect(image);
    final stripTop = tester.getTopLeft(strip).dy;
    await lab.host(tester, 'shot:viewer-bugs-tall-1-shown');
    report('viewer-bugs-tall', {'shown': '$shown', 'stripTop': stripTop});
    expect(shown.top, greaterThan(80), reason: 'the top bar covers the picture');
    expect(shown.bottom, lessThanOrEqualTo(stripTop + 1), reason: 'the band covers the picture');
    await realTap(tester, bandBackdrop(tester));
    await expectChrome(tester, false, 'tall: backdrop tap hides');
    await tester.pump(const Duration(milliseconds: 400));
    final hidden = tester.getRect(image);
    await lab.host(tester, 'shot:viewer-bugs-tall-2-hidden');
    report('viewer-bugs-tall-hidden', {'hidden': '$hidden'});
    expect(hidden.height, greaterThan(shown.height), reason: 'hidden chrome: the picture grows to the stage');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, true, 'tall: tap shows');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(image).height, closeTo(shown.height, 1), reason: 'back between the bars');
    await lab.host(tester, 'record-stop');
    await shutdown(tester);
  });

  /// What the host runner reads from `dumpsys window displays`: the status and the
  /// navigation bar. The viewer never touches them: they are visible at every step.
  Future<void> expectBars(WidgetTester t, String state) async {
    final got = await lab.host(t, 'bars');
    report('bars', {'state': state, 'got': got});
    if (got == null) return;
    expect(got, 'bars:status=shown,nav=shown', reason: '$state: system bars stay');
  }

  double scaleOf(WidgetTester t) {
    final state = browserOf(t);
    return state.zoomFor(state.index).value.getMaxScaleOnAxis();
  }

  scenario(
    'browser E2 immersive image: a real tap hides the chrome (system bars stay), the next brings it back; closing shifts nothing below',
    (tester) async {
      await openBandBrowser(tester, [bandA, bandB, bandC], 'Preview b0.jpg');
      final below = openedFrom!;
      await lab.host(tester, 'record-start:viewer-immersive-image');
      await expectChrome(tester, true, 'start');
      await expectBars(tester, 'start');
      await lab.host(tester, 'shot:viewer-immersive-image-1-shown');
      await realTap(tester, stagePoint(tester));
      await expectChrome(tester, false, 'tap hides');
      await expectBars(tester, 'tap hides');
      await lab.host(tester, 'shot:viewer-immersive-image-2-immersive');
      final hiddenPicture = tester.getRect(
        find.byKey(const ValueKey('attachment-image-vp-band-a')),
      );
      report('viewer-immersive-image', {
        'pictureTop': hiddenPicture.top,
        'pictureHeight': hiddenPicture.height,
        'screenHeight': tester.view.physicalSize.height / tester.view.devicePixelRatio,
      });
      await realTap(tester, stagePoint(tester));
      await expectChrome(tester, true, 'tap shows');
      await expectBars(tester, 'tap shows');
      await lab.host(tester, 'shot:viewer-immersive-image-3-restored');
      // A zoom enters immersive; the double tap target is a fixed 2x.
      await realTap(tester, stagePoint(tester), twice: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(browserOf(tester).zoomed, true);
      expect(scaleOf(tester), closeTo(2, .02), reason: 'fixed 2x');
      await expectChrome(tester, false, 'double tap zoom enters immersive');
      await expectBars(tester, 'double tap zoom');
      await realTap(tester, stagePoint(tester), twice: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        browserOf(tester).zoomed,
        false,
        reason: 'double tap returns to fit',
      );
      await expectChrome(tester, false, 'back to fit keeps immersive');
      await expectBars(tester, 'back to fit keeps immersive');
      await lab.host(
        tester,
        'shot:viewer-immersive-image-4-fit-still-immersive',
      );
      // Close from immersive with the back key.
      await lab.host(tester, 'back');
      await expectBars(tester, 'back key started the close');
      await until(
        tester,
        () => browser.evaluate().isEmpty,
        'the browser to close',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await lab.host(tester, 'record-stop');
      await expectBars(tester, 'closed');
      final card = find.byTooltip('Preview b0.jpg');
      String box(Rect r) => '${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)},${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}';
      report('viewer-immersive-below', {'before': box(below), 'after': box(tester.getRect(card))});
      expect(
        (tester.getRect(card).topLeft - below.topLeft).distance,
        lessThan(1),
        reason: 'the page below did not shift',
      );
      await shutdown(tester);
    },
  );

  scenario(
    'browser E2 immersive image: the close button and a drag down close with the system bars untouched',
    (tester) async {
      await openBandBrowser(tester, [bandA, bandB, bandC], 'Preview b0.jpg');
      await realTap(tester, stagePoint(tester));
      await expectBars(tester, 'hidden');
      await realTap(tester, stagePoint(tester));
      await expectBars(tester, 'shown');
      await tapCentre(tester, find.byType(RaftMediaChromeButton).first);
      await until(
        tester,
        () => browser.evaluate().isEmpty,
        'the Back button to close',
      );
      await expectBars(tester, 'closed with Back');
      // Again, dismissed by dragging the picture down from immersive.
      await tapCentre(tester, find.byTooltip('Preview b0.jpg'));
      await until(
        tester,
        () => browser.evaluate().isNotEmpty && browserOf(tester).index == 0,
        'the browser',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await realTap(tester, stagePoint(tester));
      await expectBars(tester, 'hidden again');
      await tester.flingFrom(
        stagePoint(tester, down: .3),
        const Offset(0, 300),
        1500,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectBars(tester, 'drag released');
      await until(
        tester,
        () => browser.evaluate().isEmpty,
        'the drag to close',
      );
      await expectBars(tester, 'closed by dragging');
      await shutdown(tester);
    },
  );

  scenario(
    'browser E2 immersive video: playing under visible chrome it hides by itself after 3 s; never while paused; a tap; the app returning',
    (tester) async {
      await browserLaunch(tester, [_bA, _bP1]);
      await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
      await openBrowserFromCard(tester, 'a.mp4');
      final bar = find.descendant(
        of: viewer,
        matching: find.byKey(const Key('inline-video-bar')),
      );
      final toggle = find.descendant(
        of: viewer,
        matching: find.byKey(const Key('inline-video-toggle')),
      );
      await until(tester, () => viewerOf(tester).playing, 'the page to play');
      final clock = Stopwatch()..start();
      await lab.host(tester, 'record-start:viewer-immersive-video');
      await expectBars(tester, 'playing, chrome shown');
      await lab.host(tester, 'shot:viewer-immersive-video-1-playing');
      expect(bar, findsOneWidget);
      await until(
        tester,
        () => !browserOf(tester).chrome.value,
        'the 3 s auto-hide',
        timeout: const Duration(seconds: 8),
      );
      final hiddenAt = clock.elapsedMilliseconds;
      report('viewer-immersive-video', {'autoHideAfterMs': hiddenAt});
      expect(hiddenAt, inInclusiveRange(2500, 6500));
      await tester.pump(const Duration(milliseconds: 400));
      expect(bar, findsNothing);
      await expectBars(tester, 'auto-hidden');
      await lab.host(tester, 'shot:viewer-immersive-video-2-auto-hidden');
      expect(viewerOf(tester).playing, true, reason: 'hiding never pauses');
      // A real tap brings controls, chrome and bars back, 3 s later they go again.
      await realTap(tester, stagePoint(tester, down: .3));
      await expectChrome(tester, true, 'tap shows');
      expect(bar, findsOneWidget);
      await expectBars(tester, 'tap shows');
      // Pausing from the bar: it stays for good.
      await realTap(tester, tester.getCenter(toggle));
      await until(
        tester,
        () => !viewerOf(tester).playing,
        'the bar button to pause',
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        browserOf(tester).chrome.value,
        true,
        reason: 'paused never auto-hides',
      );
      expect(bar, findsOneWidget);
      await expectBars(tester, 'paused');
      // Paused, a tap still hides everything (controls included).
      await realTap(tester, stagePoint(tester, down: .3));
      await expectChrome(tester, false, 'paused tap hides');
      expect(bar, findsNothing);
      await expectBars(tester, 'paused tap hides');
      await lab.host(tester, 'shot:viewer-immersive-video-3-paused-hidden');
      // The app goes away and comes back: immersive again, not stuck, not lost.
      await lab.hostQuiet('background:2');
      await tester.pump(const Duration(seconds: 1));
      await expectBars(tester, 'after the app returned');
      await lab.host(tester, 'shot:viewer-immersive-video-4-returned');
      await lab.host(tester, 'record-stop');
      await lab.host(tester, 'back');
      await until(
        tester,
        () => browser.evaluate().isEmpty,
        'the browser to close',
      );
      await expectBars(tester, 'closed');
      await shutdown(tester);
    },
  );

  scenario('browser B3: landscape', (tester) async {
    addTearDown(() => lab.hostQuiet('rotate:0'));
    await openBandBrowser(tester, [bandA, bandB, bandC], 'Preview b0.jpg');
    if (await lab.hostQuiet('rotate:1') == null) return markTestSkipped('needs the host runner');
    await tester.pump(const Duration(seconds: 2));
    await lab.host(tester, 'record-start:viewer-bugs-band-landscape');
    await expectChrome(tester, true, 'landscape start');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, false, 'landscape: picture tap hides');
    await lab.host(tester, 'shot:viewer-bugs-band-landscape-hidden');
    await realTap(tester, stagePoint(tester));
    await expectChrome(tester, true, 'landscape: picture tap shows');
    await realTap(tester, Offset(tester.getSize(browser).width / 2, tester.getSize(browser).height - 4));
    await expectChrome(tester, false, 'landscape: bottom edge tap hides');
    await lab.host(tester, 'record-stop');
    await lab.hostQuiet('rotate:0');
    await shutdown(tester);
  });

  scenario('background: timeline posters create no decoder before or after returning', (tester) async {
    if (!_background) return markTestSkipped('run with --define VP_BACKGROUND=true');
    await launch(tester, [_portrait]);
    expect(VideoPlayerAttachmentPlayer.debugLive, 0);
    final result = await lab.hostQuiet('background:4');
    if (result == null) { markTestSkipped('needs the host runner'); return; }
    await tester.pump(const Duration(milliseconds: 800));
    expect(VideoPlayerAttachmentPlayer.debugLive, 0);
    expect(posterCard('portrait.mp4'), findsOneWidget);
    await shutdown(tester);
  });

  scenario('background R14: backgrounding the app with the browser on a playing video pauses; returning does not resume', (tester) async {
    if (!_background) return markTestSkipped('R14: run with --dart-define=VP_BACKGROUND=true (see _background)');
    await browserLaunch(tester, [_bA, _bP1, _bC]);
    await playFromPoster(tester, 'a.mp4', past: const Duration(seconds: 1));
    await openBrowserFromCard(tester, 'a.mp4');
    await until(tester, () => viewerOf(tester).position > const Duration(seconds: 2), 'the browser to play');
    final result = await lab.hostQuiet('background:4');
    if (result == null) {
      markTestSkipped('needs the host runner');
      return;
    }
    await tester.pump(const Duration(milliseconds: 800));
    final p1 = stageOf(tester, 0).player!.playback;
    await tester.pump(const Duration(seconds: 2));
    final p2 = stageOf(tester, 0).player!.playback;
    report('browser-r14', {'playingAfterReturn': p2.playing, 'positionAfterReturnMs': p1.position.inMilliseconds, 'positionLaterMs': p2.position.inMilliseconds});
    expect(p2.playing, false, reason: 'returning resumed playback');
    expect(p2.position, p1.position, reason: 'the position moved while paused');
    await shutdown(tester);
  });


  // ---- E3: the open / close Hero flight, frame by frame ---------------------

  /// Top bar and bottom band opacity AS DRAWN (the animated value, not the target), summed: 2 when both
  /// are fully visible. Read without the guarded tester methods (it runs inside frame callbacks).
  double heroChrome() {
    var sum = 0.0;
    for (final layer in find.descendant(of: find.byType(RaftMediaImmersiveShell), matching: find.byType(AnimatedOpacity)).evaluate()) {
      FadeTransition? fade;
      void visit(Element e) {
        if (fade != null) return;
        final w = e.widget;
        if (w is FadeTransition) {
          fade = w;
          return;
        }
        e.visitChildren(visit);
      }

      layer.visitChildren(visit);
      sum += fade?.opacity.value ?? 0;
    }
    return sum;
  }

  String box(Rect r) => '${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)},${r.right.toStringAsFixed(1)},${r.bottom.toStringAsFixed(1)}';

  /// One flight round: a real tap on the card opens the browser, [close] closes it
  /// ('key' Back key, 'button' the top-left Back, 'drag' a real swipe down, with
  /// [zoom] a real double tap first). The framework's frame log of both flights
  /// goes to the host as PS-REPORT hero-<label>-open / -close.
  Future<void> heroRound(WidgetTester tester, String label, VideoClip clip, {String close = 'key', bool zoom = false}) async {
    // The default frame policy ignores the engine's frame requests (a frame only when the test pumps: ~15 fps
    // here); a flight needs the display's own cadence.
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    final policy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    addTearDown(() => binding.framePolicy = policy);
    await browserLaunch(tester, [clip]);
    final card = find.byTooltip('Preview ${clip.filename}');
    await until(tester, () => card.evaluate().isNotEmpty, 'the image card');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 500));
    final cardImages = find.descendant(of: card, matching: find.byType(Image));
    await until(tester, () => cardImages.evaluate().isNotEmpty, 'the card picture', timeout: const Duration(seconds: 30));
    final cardImage = cardImages.first;
    final cardRect = tester.getRect(cardImage);
    final stageImage = find.byKey(ValueKey('attachment-image-${clip.id}'));
    final log = HeroLog(tester, stage: stageImage, chrome: () => heroChrome());
    await lab.host(tester, 'record-start:hero-$label');
    log.start();
    await realTap(tester, tester.getCenter(card));
    await until(tester, () => browser.evaluate().isNotEmpty && browserOf(tester).index == 0, 'the browser');
    await until(tester, () => tester.state<AttachmentLightboxImageState>(find.byType(AttachmentLightboxImage).first).full != null, 'the original',
        timeout: const Duration(seconds: 40));
    await tester.pump(const Duration(milliseconds: 1200));
    final open = log.stop();
    await tester.pump(const Duration(milliseconds: 400));
    log.dispose();
    final settled = tester.getRect(stageImage);
    reportParts('hero-$label-open', {'card': box(cardRect), 'settled': box(settled), 'dpr': tester.view.devicePixelRatio, 'timings': log.timings, 'rows': open});
    // Close.
    if (zoom) {
      await realTap(tester, stagePoint(tester), twice: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(browserOf(tester).zoomed, true);
    }
    final before = tester.getRect(stageImage);
    final closing = HeroLog(tester, stage: stageImage, chrome: () => heroChrome())..start();
    switch (close) {
      case 'key':
        final host = await lab.host(tester, 'back');
        if (host == null) await tester.binding.handlePopRoute();
      case 'button':
        await realTap(tester, tester.getCenter(find.byType(RaftMediaChromeButton).first));
      case 'drag':
        final ratio = tester.view.devicePixelRatio;
        final from = stagePoint(tester);
        final dy = tester.getSize(browser).height * .5;
        await lab.host(tester, 'swipe:${(from.dx * ratio).round()},${(from.dy * ratio).round()},${(from.dx * ratio).round()},${((from.dy + dy) * ratio).round()},260');
    }
    await until(tester, () => browser.evaluate().isEmpty, 'the browser to close');
    await tester.pump(const Duration(milliseconds: 900));
    final rows = closing.stop();
    await tester.pump(const Duration(milliseconds: 400));
    closing.dispose();
    await lab.host(tester, 'record-stop');
    reportParts('hero-$label-close', {'before': box(before), 'cardAfter': box(tester.getRect(cardImage)), 'card': box(cardRect), 'timings': closing.timings, 'rows': rows});
    await shutdown(tester);
  }

  const heroLandscape = VideoClip('vp-hero-l', 'photo1.jpg', 'hero-l.jpg', size: 55318, mime: 'image/jpeg', group: 'g', width: 1600, height: 1067);
  const heroLandscapeNoMeta = VideoClip('vp-hero-n', 'photo1.jpg', 'hero-n.jpg', size: 55318, mime: 'image/jpeg', group: 'g', rate: 9000);
  const heroLandscapeWrongMeta = VideoClip('vp-hero-w', 'photo1.jpg', 'hero-w.jpg', size: 55318, mime: 'image/jpeg', group: 'g', rate: 9000, width: 1067, height: 1600);
  const heroTall = VideoClip('vp-hero-t', 'tall.jpg', 'hero-t.jpg', size: 152291, mime: 'image/jpeg', group: 'g', width: 1080, height: 2400);

  scenario('hero H1: open by a real tap and close with the Back key (metadata right)', (tester) => heroRound(tester, 'h1-landscape', heroLandscape));
  scenario('hero H2: metadata missing, the original arrives late', (tester) => heroRound(tester, 'h2-nometa-slow', heroLandscapeNoMeta));
  scenario('hero H3: portrait metadata on a landscape picture, the original arrives late', (tester) => heroRound(tester, 'h3-wrongmeta-slow', heroLandscapeWrongMeta));
  scenario('hero H4: a tall picture', (tester) => heroRound(tester, 'h4-tall', heroTall));
  scenario('hero H5: close from a 2x zoom', (tester) => heroRound(tester, 'h5-zoom', heroLandscape, zoom: true));
  scenario('hero H6: close with a real drag down', (tester) => heroRound(tester, 'h6-drag', heroLandscape, close: 'drag'));
  scenario('hero H7: close with the top-left Back button', (tester) => heroRound(tester, 'h7-button', heroLandscape, close: 'button'));


}
