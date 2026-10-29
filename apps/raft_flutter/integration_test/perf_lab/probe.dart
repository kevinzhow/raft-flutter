// Perf lab measurement core: per-frame FrameTiming, framework phase blocks,
// clock alignment and the handshake with the host-side sampler
// (test_driver/perf_lab_driver.dart). Nothing here touches product code.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';

/// Framework phases emitted by the pipeline in profile mode.
const phaseNames = {
  'BUILD': 'build',
  'LAYOUT': 'layout',
  'UPDATING COMPOSITING BITS': 'compositingBits',
  'PAINT': 'paint',
  'COMPOSITING': 'compositing',
  'SEMANTICS': 'semantics',
  'FINALIZE TREE': 'finalize',
  'POST_FRAME': 'postFrame',
};

String _phase(String name) => name.endsWith(' (root)') ? name.substring(0, name.length - 7) : name;

/// Records engine FrameTimings and the timeline time at which each frame's
/// pipeline ran, to align the engine clock with the Dart timeline clock that
/// CPU samples and framework blocks use.
class FrameProbe {
  FrameProbe(WidgetsBinding binding) {
    binding.addTimingsCallback(timings.addAll);
    binding.addPersistentFrameCallback((_) {
      if (recording) pipelineAt.add(developer.Timeline.now);
    });
  }
  final timings = <ui.FrameTiming>[];
  final pipelineAt = <int>[];
  var recording = false;
  void reset() {
    timings.clear();
    pipelineAt.clear();
  }
}

/// Estimates the timeline-minus-engine clock offset (microseconds). The
/// lab's persistent frame callback runs after the engine's build span ends
/// (scene submission) and before the next frame starts, so for the right
/// offset every callback lands in [buildFinish, nextBuildStart). Periodic
/// frames make offsets a whole period apart fit too; the smallest-magnitude
/// offset with (near) maximal support wins, refined to the smallest residual.
({int offset, double matched}) alignClocks(List<ui.FrameTiming> frames, List<int> pipeline) {
  if (frames.isEmpty || pipeline.isEmpty) return (offset: 0, matched: 0);
  final sorted = [...frames]..sort((a, b) => a.timestampInMicroseconds(ui.FramePhase.buildStart).compareTo(b.timestampInMicroseconds(ui.FramePhase.buildStart)));
  final finish = [for (final f in sorted) f.timestampInMicroseconds(ui.FramePhase.buildFinish)];
  final next = [
    for (var i = 0; i < sorted.length; i++)
      i + 1 < sorted.length ? sorted[i + 1].timestampInMicroseconds(ui.FramePhase.buildStart) : finish[i] + 50000,
  ];
  final calls = [...pipeline]..sort();
  int firstAtOrAfter(int t) {
    var lo = 0, hi = calls.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (calls[mid] < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  List<int> residuals(int d) {
    final out = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      final k = firstAtOrAfter(finish[i] + d - 300);
      if (k < calls.length && calls[k] < next[i] + d) out.add(calls[k] - finish[i]);
    }
    return out;
  }

  final candidates = <int>{0, for (final f in finish.take(8)) for (final c in calls.take(16)) c - f};
  final support = {for (final d in candidates) d: residuals(d).length};
  final most = support.values.fold<int>(0, math.max);
  final best = (support.entries.where((e) => e.value >= most * .95).toList()..sort((a, b) => a.key.abs().compareTo(b.key.abs()))).first.key;
  final r = residuals(best)..sort();
  if (r.isEmpty) return (offset: 0, matched: 0);
  return (offset: r.first, matched: r.length / sorted.length);
}

/// Host sampler handshake over the VM service: the app posts `raft.lab`
/// extension events and waits for the driver to call `ext.raft.lab.ack`.
class LabSampler {
  LabSampler() {
    if (standaloneOut != null) {
      // Self-driving build (no `flutter drive` host): write what the driver
      // would write, without CPU/timeline attribution.
      Directory(standaloneOut!).createSync(recursive: true);
      attached = true;
      return;
    }
    developer.registerExtension('ext.raft.lab.ack', (method, args) async {
      if (args['cpuProfiling'] case final value?) cpuSamplingEnabled = value == 'true';
      _pending.remove(args['token'])?.complete(args['note'] ?? '');
      return developer.ServiceExtensionResponse.result('{}');
    });
  }
  final _pending = <String, Completer<String>>{};
  var _token = 0;
  var attached = false;
  bool? cpuSamplingEnabled;

  /// `RAFT_LAB_STANDALONE_OUT=<dir>`: results are written here by the app
  /// itself and the process exits when the lab finishes.
  static final String? standaloneOut = () {
    final dir = Platform.environment['RAFT_LAB_STANDALONE_OUT'];
    return dir == null || dir.isEmpty ? null : dir;
  }();

  void _writeStandalone(String kind, Map<String, Object?> data) {
    final out = standaloneOut!;
    String json(Object? o) => const JsonEncoder.withIndent(' ').convert(o);
    switch (kind) {
      case 'hello':
        File('$out/lab-hello.json').writeAsStringSync(json(data));
      case 'result':
        final record = jsonDecode(data['record'] as String) as Map<String, dynamic>;
        File('$out/${record['theme']}-${record['scenario']}.json').writeAsStringSync(jsonEncode(record));
      case 'note':
        File('$out/lab-notes.jsonl').writeAsStringSync('${jsonEncode(data)}\n', mode: FileMode.append);
      case 'done':
        File('$out/lab-done.json').writeAsStringSync(json(data));
    }
  }

  Future<bool> send(String kind, Map<String, Object?> data, {Duration timeout = const Duration(seconds: 60)}) async {
    if (standaloneOut != null) {
      _writeStandalone(kind, data);
      return true;
    }
    final token = '${++_token}';
    final done = Completer<String>();
    _pending[token] = done;
    developer.postEvent('raft.lab', {'kind': kind, 'token': token, ...data});
    try {
      await done.future.timeout(attached || kind == 'hello' ? timeout : const Duration(milliseconds: 10));
      return true;
    } on TimeoutException {
      _pending.remove(token);
      return false;
    }
  }

  /// The driver subscribes to extension events after it connects; repeat
  /// the greeting until it answers (or give up and run unattributed).
  Future<void> hello(Map<String, Object?> data) async {
    if (standaloneOut != null) {
      _writeStandalone('hello', data);
      return;
    }
    for (var i = 0; i < 60 && !attached; i++) {
      attached = await send('hello', data, timeout: const Duration(seconds: 1));
    }
  }
}

int? cpuTicks() {
  if (!Platform.isLinux) return null;
  final raw = File('/proc/self/stat').readAsStringSync();
  final fields = raw.substring(raw.lastIndexOf(')') + 2).split(' ');
  return int.parse(fields[11]) + int.parse(fields[12]);
}

/// On-CPU time of the calling thread (the Dart UI isolate's thread), in
/// seconds: unlike wall time it does not grow when the host is busy.
double? threadCpuSeconds() {
  if (!Platform.isLinux) return null;
  try {
    final raw = File('/proc/thread-self/schedstat').readAsStringSync();
    return int.parse(raw.split(' ').first) / 1e9;
  } catch (_) {
    return null;
  }
}

/// The main timeline's scroll position, found by widget type rather than by
/// any private state of the chat implementation: the vertical [Scrollable]
/// under the [RaftChatView] (main or thread) with the most scrollable
/// content, then the largest viewport.
ScrollableState timelineScrollable(WidgetTester t, {bool thread = false}) {
  final chat = find.byWidgetPredicate((w) => w is RaftChatView && w.thread == thread);
  final candidates = find.descendant(of: chat, matching: find.byType(Scrollable)).evaluate()
      .map((e) => (e as StatefulElement).state as ScrollableState)
      .where((s) => s.position.axis == Axis.vertical && s.position.hasViewportDimension)
      .toList();
  if (candidates.isEmpty) throw StateError('No vertical scrollable under RaftChatView(thread: $thread)');
  double extent(ScrollableState s) => s.position.hasContentDimensions ? s.position.maxScrollExtent - s.position.minScrollExtent : 0;
  candidates.sort((a, b) {
    final byExtent = extent(b).compareTo(extent(a));
    return byExtent != 0 ? byExtent : b.position.viewportDimension.compareTo(a.position.viewportDimension);
  });
  return candidates.first;
}

/// Offset delta that moves toward older history for either list orientation.
double olderSign(ScrollPosition p) => p.axisDirection == AxisDirection.up ? 1 : -1;
double latestOffset(ScrollPosition p) => p.axisDirection == AxisDirection.up ? p.minScrollExtent : p.maxScrollExtent;

/// Finds a mounted message row by the product's stable key.
Finder messageRow(String id) => find.byKey(ValueKey('message-$id'));
Finder visibleText(String id) => find.descendant(of: messageRow(id), matching: find.byType(RichText)).hitTestable();

/// The painted, on-screen render box of message [id] (a list may also hold
/// offstage or measuring copies of a row).
RenderBox? visibleRowBox(String id, Rect viewport) {
  for (final element in messageRow(id).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.overlaps(viewport)) return box;
  }
  return null;
}

/// Message ids currently mounted under a chat view, restricted to [known].
Set<String> mountedIds(Set<String> known) {
  final out = <String>{};
  void visit(Element e) {
    final key = e.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('message-')) {
      final id = key.value.substring(8);
      if (known.contains(id)) out.add(id);
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return out;
}

/// One measured scenario run.
class Measurement {
  Measurement(this.theme, this.scenario);
  final String theme, scenario;
  late int startUs, endUs;
  Map<String, Object?> extras = {};
}

class LabRecorder {
  LabRecorder(this.binding, this.sampler, {required this.phases, required this.semantics, this.detection = false,
    this.bindingAutoFramesSuppressed = false});
  final WidgetsBinding binding;
  final LabSampler sampler;
  final bool phases, semantics;
  final bool detection;
  final bool bindingAutoFramesSuppressed;
  late final probe = FrameProbe(binding);
  final results = <Map<String, Object?>>[];
  int? ticksPerSecond;

  /// Lets earlier frames' timings arrive and the UI go idle.
  Future<void> settle(WidgetTester t, {Duration time = const Duration(milliseconds: 400)}) async {
    await nextFrame();
    await idle(time);
  }

  Future<Map<String, Object?>> measure(
    WidgetTester t,
    String theme,
    String scenario,
    Future<Map<String, Object?>?> Function() action, {
    String kind = 'continuous',
    bool warmup = false,
    Map<String, Object?> Function(Map<String, Object?> extras)? evidence,
  }) async {
    await settle(t);
    probe.reset();
    await sampler.send('start', {'theme': theme, 'scenario': scenario, 'warmup': warmup});
    if (phases) {
      FlutterTimeline.debugCollectionEnabled = true;
      FlutterTimeline.debugReset();
    }
    final rssBefore = ProcessInfo.currentRss;
    final ticks0 = cpuTicks();
    final threadCpu0 = threadCpuSeconds();
    final rowBuildsBefore = RaftMessageTimeline.debugRowBuilds;
    probe.recording = true;
    final start = developer.Timeline.now;
    final clock = Stopwatch()..start();
    Map<String, Object?>? extras;
    Object? failure;
    try {
      extras = await action();
    } catch (e, s) {
      failure = '$e\n$s';
    }
    final end = developer.Timeline.now;
    clock.stop();
    final ticks1 = cpuTicks();
    final threadCpu1 = threadCpuSeconds();
    final rowBuilds = RaftMessageTimeline.debugRowBuilds - rowBuildsBefore;
    // The host reads /proc here, before timeline collection. Collection walks
    // every build, layout and paint on the UI thread and is not part of the scene.
    await sampler.send('cpu', {'theme': theme, 'scenario': scenario});
    // Read UI witnesses after the measured clock stopped. Walking the tree
    // must not become part of a slow frame or the action's CPU sample.
    final proof = evidence?.call(extras ?? const {}) ?? const <String, Object?>{};
    final blocks = phases ? FlutterTimeline.debugCollect().timedBlocks : const <TimedBlock>[];
    if (phases) FlutterTimeline.debugCollectionEnabled = false;
    // Engine timings are delivered in batches; wait for the tail.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    probe.recording = false;
    final clockAlign = alignClocks(probe.timings, probe.pipelineAt);
    int tl(ui.FrameTiming f, ui.FramePhase p) => f.timestampInMicroseconds(p) + clockAlign.offset;
    final frames = probe.timings.where((f) {
      final b = tl(f, ui.FramePhase.buildStart);
      return b >= start && b <= end;
    }).toList()
      ..sort((a, b) => a.timestampInMicroseconds(ui.FramePhase.buildStart).compareTo(b.timestampInMicroseconds(ui.FramePhase.buildStart)));

    // Top-level (non-nested) framework blocks, mapped to frames by time.
    final sortedBlocks = [...blocks]..sort((a, b) => a.start.compareTo(b.start));
    final topLevel = <TimedBlock>[];
    var openEnd = -1.0;
    final inclusive = <String, double>{}, counts = <String, int>{};
    for (final b in sortedBlocks) {
      final name = _phase(b.name);
      inclusive.update(name, (v) => v + b.duration, ifAbsent: () => b.duration);
      counts.update(name, (v) => v + 1, ifAbsent: () => 1);
      if (b.start >= openEnd) {
        topLevel.add(b);
        openEnd = b.end;
      }
    }
    var cursor = 0;
    final frameRows = <Map<String, Object?>>[];
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      final b = tl(f, ui.FramePhase.buildStart), e = tl(f, ui.FramePhase.buildFinish);
      // The engine's build span ends when the scene is submitted; semantics,
      // finalize-tree and post-frame callbacks still run on the UI thread
      // afterwards, before the next frame can start. Attribute every block up
      // to the next frame's start (or 50 ms) to this frame.
      final limit = i + 1 < frames.length ? tl(frames[i + 1], ui.FramePhase.buildStart) - 500 : e + 50000;
      final ph = <String, int>{};
      var busyEnd = e.toDouble();
      while (cursor < topLevel.length && topLevel[cursor].start < b - 500) {
        cursor++;
      }
      while (cursor < topLevel.length && topLevel[cursor].start < limit) {
        final block = topLevel[cursor];
        final key = phaseNames[_phase(block.name)] ?? 'other';
        ph.update(key, (v) => v + block.duration.round(), ifAbsent: () => block.duration.round());
        if (block.end > busyEnd) busyEnd = block.end;
        cursor++;
      }
      final work = phases ? _workCounts(blocks, b.toDouble(), limit.toDouble()) : const <String, int>{};
      frameRows.add({
        // UI thread busy time for this frame: build start to the end of its
        // last pipeline block (>= the engine build duration).
        'uit': phases ? (busyEnd - b).round() : f.buildDuration.inMicroseconds,
        if (phases) 'builds': work['builds'],
        if (phases) 'layouts': work['layouts'],
        if (phases) 'paints': work['paints'],
        'n': f.frameNumber,
        'v': tl(f, ui.FramePhase.vsyncStart),
        'b': b,
        'ui': f.buildDuration.inMicroseconds,
        'rs': tl(f, ui.FramePhase.rasterStart),
        'r': f.rasterDuration.inMicroseconds,
        'total': f.totalSpan.inMicroseconds,
        'ph': ph,
      });
    }
    List<List<int>> worst(String key, int Function(Map<String, Object?>) end) {
      final sorted = [...frameRows]..sort((a, b) => (b[key] as int).compareTo(a[key] as int));
      return [
        for (final f in sorted.take(5)) [(key == 'r' ? f['rs'] : f['b']) as int, end(f)],
      ];
    }

    final uiWindows = worst('uit', (f) => (f['b'] as int) + (f['uit'] as int));
    final rasterWindows = worst('r', (f) => (f['rs'] as int) + (f['r'] as int));
    await sampler.send('end', {
      'theme': theme, 'scenario': scenario, 'startUs': start, 'endUs': end,
      'uiWindows': uiWindows, 'rasterWindows': rasterWindows,
      // Build start, UI span, raster start, raster span. The host reads
      // timeline tdur against these clocks.
      'frames': [
        for (final f in frameRows) [f['b'], f['uit'], f['rs'], f['r']],
      ],
    });
    final view = binding.platformDispatcher.views.first;
    final record = <String, Object?>{
      'theme': theme,
      'scenario': scenario,
      'kind': kind,
      'profile': kProfileMode,
      'semanticsRequested': semantics,
      'semanticsEnabled': SemanticsBinding.instance.semanticsEnabled,
      'phasesCollected': phases,
      'samplerAttached': sampler.attached,
      'displayRefreshRate': view.display.refreshRate,
      'devicePixelRatio': view.devicePixelRatio,
      'viewWidth': view.physicalSize.width,
      'viewHeight': view.physicalSize.height,
      'startUs': start,
      'endUs': end,
      'elapsedSeconds': clock.elapsedMicroseconds / 1e6,
      'clockOffsetUs': clockAlign.offset,
      'clockMatched': clockAlign.matched,
      'cpuSeconds': ticks0 == null || ticks1 == null || ticksPerSecond == null ? null : (ticks1 - ticks0) / ticksPerSecond!,
      'uiThreadCpuSeconds': threadCpu0 == null || threadCpu1 == null ? null : threadCpu1 - threadCpu0,
      'rssBefore': rssBefore,
      'rssAfter': ProcessInfo.currentRss,
      'blockTotalsUs': {for (final e in inclusive.entries) e.key: e.value.round()},
      'blockCounts': counts,
      'frames': frameRows,
      if (detection) 'detection': {
        'framePolicy': binding is LiveTestWidgetsFlutterBinding
            ? (binding as LiveTestWidgetsFlutterBinding).framePolicy.name : 'production',
        'testerPumpsDuringAction': kind == 'idle' ? 0 : null,
        'bindingAutoFramesSuppressed': bindingAutoFramesSuppressed,
        'cpuSamplingEnabled': sampler.cpuSamplingEnabled,
        'phaseProfilingEnabled': phases || extras?['phaseProfiling'] == true,
        'renderSurfaceWidth': binding.renderViews.first.size.width,
        'renderSurfaceHeight': binding.renderViews.first.size.height,
        'nativeWindowWidth': ui.PlatformDispatcher.instance.views.first.physicalSize.width,
        'nativeWindowHeight': ui.PlatformDispatcher.instance.views.first.physicalSize.height,
        'allowedActivity': extras?['allowedActivity'] ?? const <String>[],
        'rebuilds': {
          'instancesCollected': false,
          'reason': 'The existing debugOnRebuildDirtyWidget hook is assertion-only in Flutter. Use the existing debug rebuild tests for instance attribution; this profile counter is aggregate only.',
          'timelineRowBuilds': rowBuilds,
        },
        'actions': detectionActions(scenario, start, end, extras ?? const {}),
        ...proof,
      },
      if (detection && phases) 'frameworkBlocks': [
        for (final block in blocks) {
          'name': block.name, 'ts': block.start.round(), 'dur': block.duration.round(), 'ph': 'X', 'cat': 'Flutter',
        },
      ],
      'failure': ?failure,
      ...?extras,
    };
    results.add(record);
    await sampler.send('result', {'record': jsonEncode(record)});
    return record;
  }
}

/// Reuse the scene's actual action markers; no estimated frame/action joins.
List<Map<String, Object?>> detectionActions(
  String scene,
  int start,
  int end,
  Map<String, Object?> extras,
) {
  final entries = extras['opens'] ?? extras['keyboard'];
  if (entries is List && entries.isNotEmpty) {
    return [
      for (final (index, raw) in entries.indexed)
        if (raw is Map && raw['t0'] is num && raw['t1'] is num)
          {
            'name': '${raw['channel'] ?? raw['direction'] ?? scene}-$index',
            'startUs': raw['t0'],
            'endUs': raw['t1'],
            if (raw['shownUs'] != null) 'targetShownUs': raw['shownUs'],
            if (raw['visibleMs'] != null) 'visibleMs': raw['visibleMs'],
          },
    ];
  }
  return [
    {'name': scene, 'startUs': start, 'endUs': end},
  ];
}

const _pipelineWork = {
  'BUILD': 'builds',
  'LAYOUT': 'layouts',
  'LAYOUT (root)': 'layouts',
  'PAINT': 'paints',
  'PAINT (root)': 'paints',
};

/// Builds, layouts and paints whose timeline event starts in [start, end).
///
/// The three profile switches emit one event per widget build, render-object
/// layout and render-object paint. Each event is attributed to the pipeline
/// phase that contains it (`BUILD`, `LAYOUT`, `PAINT`), so a build is not
/// counted as a layout when the names collide.
Map<String, int> _workCounts(List<TimedBlock> blocks, double start, double end) {
  final counts = {'builds': 0, 'layouts': 0, 'paints': 0};
  String? phaseAt(double t) {
    String? kind;
    var span = double.infinity;
    for (final block in blocks) {
      final name = _pipelineWork[block.name];
      if (name == null || t < block.start || t > block.end) continue;
      final width = block.end - block.start;
      if (width < span) {
        span = width;
        kind = name;
      }
    }
    return kind;
  }

  for (final block in blocks) {
    if (_pipelineWork.containsKey(block.name)) continue;
    if (block.start < start || block.start >= end) continue;
    final kind = phaseAt(block.start);
    if (kind != null) counts[kind] = counts[kind]! + 1;
  }
  return counts;
}

/// Waits real time without requesting a tester frame. Natural idle collection
/// also requires the lab binding's automatic-frame suppression; merely
/// selecting benchmarkLive still makes this pinned SDK schedule extra frames.
Future<void> idle(Duration d) => Future<void>.delayed(d);

/// Completes after the next frame (scheduling one only if none is pending).
Future<void> nextFrame() => SchedulerBinding.instance.endOfFrame;

/// Completes after the next frame the app produces by itself, or [cap].
Future<void> naturalFrame({Duration cap = const Duration(milliseconds: 50)}) {
  final done = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!done.isCompleted) done.complete();
  });
  return Future.any([done.future, Future<void>.delayed(cap)]);
}

/// Polls [ready] after each natural frame; returns elapsed ms or -1.
Future<double> waitUntil(bool Function() ready, {Duration limit = const Duration(seconds: 6)}) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < limit) {
    if (ready()) return clock.elapsedMicroseconds / 1000;
    await naturalFrame();
  }
  return ready() ? clock.elapsedMicroseconds / 1000 : -1;
}

double percentile(List<num> values, double q) {
  if (values.isEmpty) return 0;
  final s = [...values]..sort();
  return s[math.min(s.length - 1, ((s.length - 1) * q).ceil())].toDouble();
}

/// The timeline scrollbar's thumb rect (global), found through its painter's
/// own hit test, so it works for any scrollbar built on [ScrollbarPainter].
Rect? scrollbarThumb(WidgetTester t) {
  final view = timelineScrollable(t).context.findRenderObject()! as RenderBox;
  final viewport = view.localToGlobal(Offset.zero) & view.size;
  for (final e in find.byType(CustomPaint).evaluate()) {
    final painter = (e.widget as CustomPaint).foregroundPainter;
    final box = e.renderObject;
    if (painter is! ScrollbarPainter || box is! RenderBox || !box.attached) continue;
    final origin = box.localToGlobal(Offset.zero);
    if (!(origin & box.size).contains(viewport.center)) continue;
    double? top, bottom;
    for (var y = 0.0; y < box.size.height; y += 1) {
      if (painter.hitTestOnlyThumbInteractive(Offset(box.size.width - 4, y), ui.PointerDeviceKind.mouse)) {
        top ??= y;
        bottom = y;
      }
    }
    if (top == null) continue;
    return Rect.fromLTRB(origin.dx + box.size.width - 8, origin.dy + top, origin.dx + box.size.width, origin.dy + bottom! + 1);
  }
  return null;
}
