// Perf lab: fixed scenarios that measure every frame's UI and raster cost
// in profile mode against the 8.33 ms (120 Hz) budget, gated at 16.7 ms.
// Run through `python3 tool/performance/lab.py run`; see
// docs/performance-lab.md. Rows are found by the product's stable keys
// (`message-<id>`) and the chat's vertical Scrollable, never by private
// fields, so the suite stays valid across list implementations.
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/probe.dart';

const _defines = {
  'RAFT_LAB_THEMES': String.fromEnvironment('RAFT_LAB_THEMES'),
  'RAFT_LAB_SCENARIOS': String.fromEnvironment('RAFT_LAB_SCENARIOS'),
  'RAFT_LAB_SECONDS': String.fromEnvironment('RAFT_LAB_SECONDS'),
  'RAFT_LAB_SEMANTICS': String.fromEnvironment('RAFT_LAB_SEMANTICS'),
  'RAFT_LAB_PHASES': String.fromEnvironment('RAFT_LAB_PHASES'),
};
String _cfg(String key) {
  final define = _defines[key] ?? '';
  return define.isNotEmpty ? define : Platform.environment[key] ?? '';
}

final themes = (_cfg('RAFT_LAB_THEMES').isEmpty ? 'brutal-light,elegant-light' : _cfg('RAFT_LAB_THEMES')).split(',');
final only = _cfg('RAFT_LAB_SCENARIOS').split(',').where((s) => s.isNotEmpty).toSet();
final seconds = int.tryParse(_cfg('RAFT_LAB_SECONDS')) ?? 8;
/// `platform` (default): whatever the embedder requests (the Linux GTK
/// embedder enables semantics unconditionally; macOS only with assistive
/// technology). `on`: forced on, as with VoiceOver. `off`: forced off, the
/// usual macOS condition.
final semanticsMode = switch (_cfg('RAFT_LAB_SEMANTICS')) {
  'true' || 'on' => 'on',
  'false' || 'off' => 'off',
  _ => 'platform',
};
final semantics = semanticsMode == 'on';
final phases = _cfg('RAFT_LAB_PHASES') != 'false';

bool wants(String scenario) => only.isEmpty || only.contains(scenario) || only.any((o) => o.endsWith('*') && scenario.startsWith(o.substring(0, o.length - 1)));

/// Desktop split host: channel timeline plus a thread pane when one is open.
class _Host extends StatefulWidget {
  const _Host({required this.w});
  final WorkspaceController w;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var thread = false;
  void changed() {
    final next = widget.w.threadIdentity != null;
    if (next != thread) setState(() => thread = next);
  }

  @override
  void initState() {
    super.initState();
    widget.w.addListener(changed);
  }

  @override
  void dispose() {
    widget.w.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: RaftChatView(controller: widget.w)),
      if (thread) SizedBox(width: 440, child: RaftChatView(controller: widget.w, thread: true)),
    ],
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final sampler = LabSampler();
  testWidgets('perf lab', (t) async {
    expect(kProfileMode, true, reason: 'Only profile-mode timings are meaningful.');
    final platformSemantics = binding.platformDispatcher.semanticsEnabled;
    if (semanticsMode == 'off') binding.platformDispatcher.semanticsEnabledTestValue = false;
    addTearDown(binding.platformDispatcher.clearSemanticsEnabledTestValue);
    final lab = LabRecorder(binding, sampler, phases: phases, semantics: semantics);
    if (Platform.isLinux) {
      lab.ticksPerSecond = int.tryParse((await Process.run('getconf', ['CLK_TCK'])).stdout.toString().trim());
    }
    final view = binding.platformDispatcher.views.first;
    await sampler.hello({
      'pid': pid,
      'fixtureVersion': fixtureVersion,
      'themes': themes,
      'scenarios': only.toList(),
      'seconds': seconds,
      'semantics': semanticsMode,
      'platformSemanticsEnabled': platformSemantics,
      'phases': phases,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'displayRefreshRate': view.display.refreshRate,
      'devicePixelRatio': view.devicePixelRatio,
      'viewWidth': view.physicalSize.width,
      'viewHeight': view.physicalSize.height,
      'dartVersion': Platform.version,
    });
    final images = await LabImages.start();
    addTearDown(() => images.server.close(force: true));
    final failures = <String>[];

    for (final name in themes) {
      final (family, dark) = switch (name) {
        'brutal-light' => (RaftFamily.brutal, false),
        'brutal-dark' => (RaftFamily.brutal, true),
        'elegant-light' => (RaftFamily.elegant, false),
        'elegant-dark' => (RaftFamily.elegant, true),
        _ => throw ArgumentError('Unknown theme $name'),
      };
      SharedPreferences.setMockInitialValues({});
      final mix = LabChannel('mix', mixKinds(600), pageDelay: const Duration(milliseconds: 150));
      final openA = LabChannel('open-a', mixKinds(80), pageDelay: const Duration(milliseconds: 150));
      final openB = LabChannel('open-b', [for (final k in mixKinds(100).reversed) k], pageDelay: const Duration(milliseconds: 150));
      final img = LabChannel('img', [for (var i = 0; i < 240; i++) i % 5 == 4 ? 'plain' : 'image']);
      final hist = LabChannel('hist', mixKinds(300), pageDelay: const Duration(milliseconds: 250), firstPage: 50);
      final mounts = {for (final k in rowKinds) k: LabChannel('mount-$k', List.filled(120, k))};
      final parent = mix.rows.lastWhere((r) => mix.summaries.containsKey(r['id']));
      final threadId = 'thread-${parent['id']}';
      final thread = LabChannel(threadId, [for (final k in mixKinds(40)) k == 'thread-summary' || k == 'task' ? 'plain' : k], pageDelay: const Duration(milliseconds: 150));
      final channels = [mix, openA, openB, img, hist, thread, ...mounts.values];
      final (w, api, client) = await labWorkspace(channels, images);
      api.routes['GET /channels/mix/threads/${parent['id']}'] = (_) => {'threadChannelId': threadId};
      w.channel = mix.record;
      await w.selectChannel(mix.record);
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: raftTheme(family, dark: dark),
        home: Scaffold(body: _Host(w: w)),
      ));
      String newest(LabChannel c) => c.rows.last['id'] as String;
      final shown = await waitUntil(() => visibleText(newest(mix)).evaluate().isNotEmpty, limit: const Duration(seconds: 20));
      if (shown < 0) failures.add('$name: mix channel never published its newest row');

      ScrollPosition position({bool thread = false}) => timelineScrollable(t, thread: thread).position;
      Future<void> toLatest() async {
        final p = position();
        p.jumpTo(latestOffset(p));
        await lab.settle(t, time: const Duration(milliseconds: 600));
      }

      /// Selects [c] (if needed) and waits for its newest row.
      Future<void> show(LabChannel c, {bool latest = false}) async {
        if (w.channel?.id == c.id) {
          if (latest) await toLatest();
          return;
        }
        unawaited(w.selectChannel(c.record));
        if (await waitUntil(() => visibleText(newest(c)).evaluate().isNotEmpty, limit: const Duration(seconds: 15)) < 0) {
          failures.add('$name: ${c.id} never showed its newest row');
        }
        await lab.settle(t, time: const Duration(milliseconds: 600));
      }

      Future<Map<String, Object?>> openSeries(List<LabChannel> targets, Duration dwell) async {
        final opens = <Map<String, Object?>>[];
        for (final c in targets) {
          final t0 = developer.Timeline.now;
          unawaited(w.selectChannel(c.record));
          final ms = await waitUntil(() => visibleText(newest(c)).evaluate().isNotEmpty);
          final shownAt = developer.Timeline.now;
          await idle(dwell);
          opens.add({'channel': c.id, 'visibleMs': ms, 't0': t0, 'shownUs': shownAt, 't1': developer.Timeline.now});
          if (ms < 0) failures.add('$name: ${c.id} never became visible');
        }
        return {'opens': opens};
      }

      Future<void> steady(ScrollPosition p, double pxPerSecond, int secs) async {
        final target = (p.pixels + olderSign(p) * pxPerSecond * secs).clamp(p.minScrollExtent, p.maxScrollExtent);
        await p.animateTo(target, duration: Duration(seconds: secs), curve: Curves.linear);
      }

      Map<String, Object?> moved(ScrollPosition p, double from) => {
        'startOffset': from, 'endOffset': p.pixels, 'movedPx': (p.pixels - from).abs(),
        'axisDirection': p.axisDirection.name, 'minScrollExtent': p.minScrollExtent, 'maxScrollExtent': p.maxScrollExtent,
        'viewportDimension': p.viewportDimension,
      };

      Future<void> run(String scenario, Future<Map<String, Object?>?> Function() action, {String kind = 'continuous', Future<void> Function()? prepare}) async {
        if (!wants(scenario)) return;
        await prepare?.call();
        final record = await lab.measure(t, name, scenario, action, kind: kind);
        if (record['failure'] != null) failures.add('$name/$scenario: ${record['failure']}');
        final exception = t.takeException();
        if (exception != null) failures.add('$name/$scenario: $exception');
      }

      // Continuous reading: 1200 px/s toward older history from the latest row.
      await run('steady-scroll', prepare: () => show(mix, latest: true), () async {
        final p = position(), from = p.pixels;
        await steady(p, 1200, seconds);
        return {...moved(p, from), 'pxPerSecond': 1200};
      });

      // Six ballistic flings at 6000 px/s through the list's own physics.
      await run('fling', prepare: () => show(mix, latest: true), () async {
        final p = position(), from = p.pixels;
        final flings = <Map<String, Object?>>[];
        for (var i = 0; i < 6; i++) {
          final before = p.pixels;
          final sign = olderSign(p) * (i % 3 == 2 ? -1 : 1);
          if (p is ScrollPositionWithSingleContext) {
            p.goBallistic(sign * 6000);
          } else {
            await t.flingFrom(t.getCenter(find.byType(RaftChatView).first), Offset(0, sign * -300), 6000);
          }
          final clock = Stopwatch()..start();
          await nextFrame();
          while (clock.elapsed < const Duration(milliseconds: 2500) && p.isScrollingNotifier.value) {
            await nextFrame();
          }
          flings.add({'travelPx': (p.pixels - before).abs(), 'ms': clock.elapsedMilliseconds});
          await idle(const Duration(milliseconds: 200));
        }
        return {...moved(p, from), 'flings': flings, 'velocity': 6000};
      }, kind: 'fling');

      // A photo-heavy channel: 1-3 large PNG attachments per row.
      await run('image-scroll', prepare: () async {
        await show(img, latest: true);
        await idle(const Duration(milliseconds: 1500));
      }, () async {
        final reads = images.reads;
        final p = position(), from = p.pixels;
        await steady(p, 1200, seconds);
        return {...moved(p, from), 'pxPerSecond': 1200, 'imageReads': images.reads - reads};
      });

      // Drag (finger held) toward older history across the end of the first
      // page; the next page arrives 250 ms after the request, mid-drag.
      await run('older-drag', prepare: () => show(hist, latest: true), () async {
        final p = position(), from = p.pixels, rowsBefore = w.messages.length;
        final servedBefore = hist.olderPagesServed;
        final gesture = await t.startGesture(t.getCenter(find.byType(RaftChatView).first), kind: PointerDeviceKind.touch);
        final clock = Stopwatch()..start();
        var last = 0;
        while (clock.elapsedMilliseconds < seconds * 1000) {
          await nextFrame();
          final now = clock.elapsedMicroseconds;
          // Finger moves down: content follows, revealing older rows. Event
          // timestamps follow real time so velocity tracking is realistic.
          await gesture.moveBy(Offset(0, 1800 * (now - last) / 1e6), timeStamp: Duration(microseconds: now));
          last = now;
        }
        await gesture.up(timeStamp: Duration(microseconds: clock.elapsedMicroseconds));
        await idle(const Duration(milliseconds: 300));
        return {...moved(p, from), 'pxPerSecond': 1800, 'olderPagesServed': hist.olderPagesServed - servedBefore, 'rowsBefore': rowsBefore, 'rowsAfter': w.messages.length};
      });

      // Four live arrivals per second while the reader is 2500 px up the
      // history; the row being read must not move.
      await run('arrival-scrolled-up', prepare: () async {
        await show(mix, latest: true);
        final p = position();
        p.jumpTo(p.pixels + olderSign(p) * 2500);
        await lab.settle(t);
      }, () async {
        final known = {for (final r in mix.rows) r['id'] as String};
        final viewportBox = timelineScrollable(t).context.findRenderObject() as RenderBox;
        final center = viewportBox.localToGlobal(viewportBox.size.center(Offset.zero)).dy;
        RenderBox? anchorBox;
        String? anchor;
        var best = double.infinity;
        for (final id in mountedIds(known)) {
          final box = messageRow(id).evaluate().firstOrNull?.renderObject;
          if (box is! RenderBox || !box.hasSize || !box.attached) continue;
          final d = (box.localToGlobal(Offset.zero).dy - center).abs();
          if (d < best) {
            best = d;
            anchor = id;
            anchorBox = box;
          }
        }
        final y0 = anchorBox?.localToGlobal(Offset.zero).dy;
        var drift = 0.0, lost = 0, sampled = 0, remounts = 0;
        var active = true;
        void sample(Duration _) {
          if (!active) return;
          if (anchor != null && !(anchorBox?.attached ?? false)) {
            // The read row's render object was replaced (row remounted).
            remounts++;
            final found = messageRow(anchor).evaluate().firstOrNull?.renderObject;
            anchorBox = found is RenderBox && found.attached ? found : null;
          }
          final box = anchorBox;
          if (box == null || !box.hasSize || y0 == null) {
            lost++;
          } else {
            final d = (box.localToGlobal(Offset.zero).dy - y0).abs();
            if (d > drift) drift = d;
            sampled++;
          }
          SchedulerBinding.instance.addPostFrameCallback(sample);
        }

        SchedulerBinding.instance.addPostFrameCallback(sample);
        final count = seconds * 4;
        for (var k = 0; k < count; k++) {
          client.emit('message:new', labRow('mix', mixCycle[k % mixCycle.length], 600 + k));
          await idle(const Duration(milliseconds: 250));
        }
        active = false;
        return {'arrivals': count, 'anchor': anchor, 'anchorDriftPx': drift, 'anchorLostFrames': lost, 'anchorSampledFrames': sampled, 'anchorRemounts': remounts};
      }, kind: 'events');

      // Drive the engine view's size every frame (relayout cost only; the
      // native window/compositor resize is platform specific).
      await run('resize', prepare: () => show(mix, latest: true), () async {
        final base = t.view.physicalSize, ratio = t.view.devicePixelRatio;
        final clock = Stopwatch()..start();
        var step = 0;
        while (clock.elapsedMilliseconds < seconds * 1000) {
          final phase = step % 40;
          final width = 700 + 240 * (phase < 20 ? phase : 40 - phase) / 20;
          t.view.physicalSize = Size(width * ratio, base.height - (phase % 10) * 4 * ratio);
          await nextFrame();
          step++;
        }
        t.view.resetPhysicalSize();
        await nextFrame();
        return {'resizeSteps': step};
      });

      // Thread pane: cold open (150 ms network) then four cached reopens.
      await run('thread-open', prepare: () => show(mix, latest: true), () async {
        final parentMessage = w.messages.firstWhere((m) => m.id == parent['id']);
        final last = thread.rows.last['id'] as String;
        final threadView = find.byWidgetPredicate((x) => x is RaftChatView && x.thread);
        final opens = <Map<String, Object?>>[];
        for (var i = 0; i < 5; i++) {
          final t0 = developer.Timeline.now;
          unawaited(w.openThread(parentMessage));
          final ms = await waitUntil(() => find.descendant(of: threadView, matching: visibleText(last)).evaluate().isNotEmpty);
          final shownAt = developer.Timeline.now;
          await idle(const Duration(milliseconds: 500));
          opens.add({'channel': i == 0 ? 'cold' : 'warm', 'visibleMs': ms, 't0': t0, 'shownUs': shownAt, 't1': developer.Timeline.now});
          if (ms < 0) failures.add('$name: thread open $i never showed its newest reply');
          w.closeThread();
          await waitUntil(() => threadView.evaluate().isEmpty);
          await idle(const Duration(milliseconds: 300));
        }
        return {'opens': opens};
      }, kind: 'transitions');

      // First visits (150 ms network page), revisits, then rapid switching.
      await run('open-cold', () => openSeries([openA, openB], const Duration(milliseconds: 700)), kind: 'transitions');
      await run('open-warm', prepare: () => show(openB), () => openSeries([mix, openA, mix], const Duration(milliseconds: 700)), kind: 'transitions');
      await run('channel-switch', prepare: () async {
        await show(openA);
        await show(openB);
      }, () => openSeries([for (var i = 0; i < 10; i++) i.isEven ? openA : openB], const Duration(milliseconds: 300)), kind: 'transitions');

      // Per row kind: jump 0.9 viewport per step so every step mounts fresh
      // rows of one kind; cost per row = that frame's UI time / rows mounted.
      for (final kind in rowKinds) {
        final c = mounts[kind]!;
        await run('mount-$kind', prepare: () => show(c, latest: true), () async {
          final known = {for (final r in c.rows) r['id'] as String};
          final seen = mountedIds(known);
          final p = position();
          final steps = <Map<String, Object?>>[];
          for (var i = 0; i < 24; i++) {
            final target = (p.pixels + olderSign(p) * p.viewportDimension * .9).clamp(p.minScrollExtent, p.maxScrollExtent);
            if ((target - p.pixels).abs() < 1) break;
            final t0 = developer.Timeline.now;
            p.jumpTo(target);
            await nextFrame();
            final ids = mountedIds(known);
            final fresh = ids.difference(seen);
            seen.addAll(ids);
            await idle(const Duration(milliseconds: 120));
            steps.add({'t0': t0, 't1': developer.Timeline.now, 'newRows': fresh.length, 'mounted': ids.length});
          }
          return {'rowKind': kind, 'steps': steps};
        }, kind: 'mount');
      }

      if (api.misses.isNotEmpty) {
        await sampler.send('note', {'theme': name, 'unmatchedRoutes': api.misses.entries.map((e) => '${e.key} x${e.value}').toList()});
      }
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await t.pump();
    }
    binding.reportData = {'perfLab': {'scenarios': lab.results.length, 'failures': failures, 'samplerAttached': sampler.attached}};
    await sampler.send('done', {'failures': failures});
    expect(failures, isEmpty);
  }, semanticsEnabled: semantics);
}
