// Perf lab: fixed scenarios that measure every frame's UI and raster cost
// in profile mode against the 8.33 ms (120 Hz) budget, gated at 16.7 ms.
// Run through `python3 tool/performance/lab.py run`; see
// docs/performance-lab.md. Rows are found by the product's stable keys
// (`message-<id>`) and the chat's vertical Scrollable, never by private
// fields, so the suite stays valid across list implementations.
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show MethodCall, StandardMethodCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/layout_hold.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raft_flutter/platform/android_performance_hint.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/keyboard.dart';
import 'perf_lab/navigation_activity.dart';
import 'perf_lab/navigation_host.dart';
import 'perf_lab/probe.dart';

const _defines = {
  'RAFT_LAB_THEMES': String.fromEnvironment('RAFT_LAB_THEMES'),
  'RAFT_LAB_SCENARIOS': String.fromEnvironment('RAFT_LAB_SCENARIOS'),
  'RAFT_LAB_SECONDS': String.fromEnvironment('RAFT_LAB_SECONDS'),
  'RAFT_LAB_SEMANTICS': String.fromEnvironment('RAFT_LAB_SEMANTICS'),
  'RAFT_LAB_PHASES': String.fromEnvironment('RAFT_LAB_PHASES'),
  'RAFT_LAB_IDLE_SECONDS': String.fromEnvironment('RAFT_LAB_IDLE_SECONDS'),
  'RAFT_LAB_ROUNDS': String.fromEnvironment('RAFT_LAB_ROUNDS'),
  'RAFT_LAB_DETECT': String.fromEnvironment('RAFT_LAB_DETECT'),
};
String _cfg(String key) {
  final define = _defines[key] ?? '';
  return define.isNotEmpty ? define : Platform.environment[key] ?? '';
}

Future<void> Function()? fontKeyReport;
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
final detection = _cfg('RAFT_LAB_DETECT') == 'true';

/// The Activity-entry scene uses bottom navigation, not the compact rail.
const detectionPhoneSize = Size(390, 700);

bool wants(String scenario) => only.isEmpty || only.contains(scenario) || only.any((o) => o.endsWith('*') && scenario.startsWith(o.substring(0, o.length - 1)));

/// Desktop split host: channel timeline plus a thread pane when one is open.
class _Host extends StatefulWidget {
  const _Host({required this.w, this.onScroll});
  final WorkspaceController w;
  final ValueChanged<ScrollNotification>? onScroll;
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
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      widget.onScroll?.call(notification);
      return false;
    },
    child: Row(
      children: [
        Expanded(child: RaftChatView(controller: widget.w)),
        if (thread) SizedBox(width: 440, child: RaftChatView(controller: widget.w, thread: true)),
      ],
    ),
  );
}

class _HintLabBinding extends IntegrationTestWidgetsFlutterBinding with AndroidPerformanceHintBinding {
  bool appRequestsOnly = false;
  bool _drawingNaturally = false;

  void _scheduleAppFrame(VoidCallback schedule) {
    final previous = framePolicy;
    // During draw, benchmark suppresses the live binding's unconditional
    // platformDispatcher.scheduleFrame(). Keep genuine app requests working.
    if (_drawingNaturally) framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
    try {
      schedule();
    } finally {
      framePolicy = previous;
    }
  }

  @override
  void scheduleFrame() => _scheduleAppFrame(super.scheduleFrame);

  @override
  void scheduleForcedFrame() => _scheduleAppFrame(super.scheduleForcedFrame);

  @override
  void handleDrawFrame() {
    if (!appRequestsOnly) {
      super.handleDrawFrame();
      return;
    }
    final previous = framePolicy;
    _drawingNaturally = true;
    framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmark;
    try {
      super.handleDrawFrame();
    } finally {
      framePolicy = previous;
      _drawingNaturally = false;
    }
  }
}

bool _activityRowShown() => find
    .byKey(const ValueKey('activity-channel-open-a'))
    .hitTestable()
    .evaluate()
    .isNotEmpty;

/// Boundary observations only. The raw timing window has already ended.
Map<String, Object?> detectionEvidence(
  WidgetTester t,
  String scene,
  Map<String, Object?> extras,
) {
  final visibleKeys = <String>[];
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        (key.value.startsWith('message-') ||
            key.value.startsWith('activity-') ||
            key.value == 'detection-control');
  }).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    var visible = rect.intersect(
      Offset.zero & t.binding.renderViews.first.size,
    );
    final Object? viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is RenderBox && viewport.hasSize) {
      visible = visible.intersect(
        viewport.localToGlobal(Offset.zero) & viewport.size,
      );
    }
    if (visible.isEmpty) continue;
    // A tall row's center can be outside the viewport while some text is
    // visible. Hit-test its clipped portion; an overlapping rect alone is
    // insufficient because a different page may cover it.
    final point = visible.center - rect.topLeft;
    final alignment = Alignment(
      2 * point.dx / rect.width - 1,
      2 * point.dy / rect.height - 1,
    );
    if (find
        .byElementPredicate((candidate) => identical(candidate, element))
        .hitTestable(at: alignment)
        .evaluate()
        .isEmpty) {
      continue;
    }
    visibleKeys.add((element.widget.key as ValueKey<String>).value);
    if (visibleKeys.length == 32) break;
  }
  final opens = extras['opens'];
  final operationFailures = <String>[
    if (opens is List)
      for (final entry in opens)
        if (entry is Map && entry['liveActivity'] is Map)
          if ((entry['liveActivity'] as Map)['failure']
              case final Object failure)
            '${entry['channel']}: $failure',
  ];
  final keyboard = extras['keyboard'];
  var arrived = visibleKeys.isNotEmpty;
  String requirement = 'A target row is actually visible after the operation.';
  if (opens is List) {
    arrived =
        opens.isNotEmpty &&
        opens.every(
          (o) =>
              o is Map && o['visibleMs'] is num && (o['visibleMs'] as num) >= 0,
        );
    requirement =
        'Every recorded transition waited for its positive target predicate.';
  } else if (scene == 'older-drag') {
    arrived =
        arrived &&
        (extras['olderPagesServed'] as num? ?? 0) > 0 &&
        (extras['rowsAfter'] as num? ?? 0) >
            (extras['rowsBefore'] as num? ?? 0);
    requirement = 'The drag completed a history request, added rows, and left a visible message target.';
  } else if (scene == 'keyboard') {
    arrived =
        keyboard is List &&
        keyboard.isNotEmpty &&
        find.byType(EditableText).hitTestable().evaluate().isNotEmpty;
    requirement = 'Inset cycles completed with an actual visible editor; simulated insets are not a native keyboard proof.';
  } else if (scene.endsWith('scroll')) {
    arrived = arrived && (extras['movedPx'] as num? ?? 0) > 0;
    requirement = 'The timeline moved and a message row is actually visible.';
  }
  return {
    'operationFailures': operationFailures,
    'arrival': {
      'arrived': arrived,
      'requirement': requirement,
      'visibleKeys': visibleKeys,
    },
    if (scene.startsWith('control-'))
      'control': switch (scene) {
        'control-ticker' => 'unexpected-ticker',
        'control-animation' => 'allowed-animation',
        _ => 'healthy-idle',
      },
  };
}

/// Deliberate diagnostic fixture; this is never part of the product scene list.
class _DetectionTicker extends StatefulWidget {
  const _DetectionTicker();
  @override
  State<_DetectionTicker> createState() => _DetectionTickerState();
}

class _DetectionTickerState extends State<_DetectionTicker>
    with SingleTickerProviderStateMixin {
  late final ticker = createTicker((_) => setState(() => ticks++));
  int ticks = 0;
  @override
  void initState() {
    super.initState();
    ticker.start();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(math.sin(ticks / 10) * 24, 0),
    child: const SizedBox(
      key: ValueKey('detection-control'),
      width: 80,
      height: 80,
      child: ColoredBox(color: Color(0xff336699)),
    ),
  );
}

void registerRebuildCounterControlTest() {
  testWidgets(
    'existing rebuild hook distinguishes a stable instance from repeated rebuilds',
    (t) async {
      late StateSetter update;
      final counts = <int, int>{};
      final key = const ValueKey('message-rebuild-control');
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            key: key,
            builder: (_, setter) {
              update = setter;
              return const SizedBox();
            },
          ),
        ),
      );
      final instance = t.element(find.byKey(key));
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtBefore) {
        previous?.call(element, builtBefore);
        if (element.widget.key == key) {
          counts.update(
            identityHashCode(element),
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
      };
      try {
        await t.pump();
        expect(counts, isEmpty);
        for (var i = 0; i < 3; i++) {
          update(() {});
          await t.pump();
        }
        expect(counts, {identityHashCode(instance): 3});
        expect(t.element(find.byKey(key)), same(instance));
      } finally {
        debugOnRebuildDirtyWidget = previous;
        await t.pumpWidget(const SizedBox());
      }
    },
  );
}

void registerActivityArrivalTest() {
  testWidgets('Activity arrival requires a visible target row', (t) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Saved'))));
    expect(_activityRowShown(), false);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    expect(
      _activityRowShown(),
      false,
      reason: 'Home disappearing does not prove Activity arrived.',
    );
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Offstage(
            child: Text(
              'Activity item',
              key: ValueKey('activity-channel-open-a'),
            ),
          ),
        ),
      ),
    );
    expect(
      _activityRowShown(),
      false,
      reason: 'An offstage target is not visible.',
    );
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Activity item', key: ValueKey('activity-channel-open-a')),
        ),
      ),
    );
    expect(_activityRowShown(), true);
  });
}

void main() {
  final binding = _HintLabBinding();
  binding.appRequestsOnly = detection;
  binding.framePolicy = detection
      ? LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive
      : LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  tearDownAll(() {
    // fullyLive otherwise keeps requesting idle frames after the driver exits.
    // Stop that loop so the UI hint session can expire while the APK remains.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmark;
  });
  // Run the control in debug/widget tests. Do not prime framework caches
  // with a separate widget test before a profile workload.
  if (!kProfileMode) {
    registerActivityArrivalTest();
    registerRebuildCounterControlTest();
    return;
  }
  final sampler = LabSampler();
  testWidgets('perf lab', (t) async {
    expect(kProfileMode, true, reason: 'Only profile-mode timings are meaningful.');
    if (detection && phases) {
      debugProfileBuildsEnabled = true;
      debugProfileLayoutsEnabled = true;
      debugProfilePaintsEnabled = true;
      addTearDown(() {
        debugProfileBuildsEnabled = false;
        debugProfileLayoutsEnabled = false;
        debugProfilePaintsEnabled = false;
      });
    }
    final platformSemantics = binding.platformDispatcher.semanticsEnabled;
    if (semanticsMode == 'off') binding.platformDispatcher.semanticsEnabledTestValue = false;
    addTearDown(binding.platformDispatcher.clearSemanticsEnabledTestValue);
    final lab = LabRecorder(binding, sampler, phases: phases, semantics: semantics, detection: detection,
      bindingAutoFramesSuppressed: binding.appRequestsOnly);
    if (Platform.isLinux) {
      lab.ticksPerSecond = int.tryParse((await Process.run('getconf', ['CLK_TCK'])).stdout.toString().trim());
    }
    final view = binding.platformDispatcher.views.first;
    await sampler.hello({
      'pid': pid,
      'fixtureVersion': '$fixtureVersion-m7',
      'fixturePagination': 'requested-limit-v1',
      'linuxApplicationIdSuffix': const String.fromEnvironment('RAFT_LINUX_APPLICATION_ID_SUFFIX'),
      'themes': themes,
      'scenarios': only.toList(),
      'seconds': seconds,
      'semantics': semanticsMode,
      'platformSemanticsEnabled': platformSemantics,
      'phases': phases,
      'detection': detection,
      'framePolicy': binding.framePolicy.name,
      'bindingAutoFramesSuppressed': binding.appRequestsOnly,
      'runtimeDisplay': Platform.environment['DISPLAY'],
      'runtimeGdkBackend': Platform.environment['GDK_BACKEND'],
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'displayRefreshRate': view.display.refreshRate,
      'devicePixelRatio': view.devicePixelRatio,
      'viewWidth': view.physicalSize.width,
      'viewHeight': view.physicalSize.height,
      'dartVersion': Platform.version,
      'performanceHint': binding.performanceHintDiagnostics,
    });
    final images = await LabImages.start();
    addTearDown(() => images.server.close(force: true));
    final failures = <String>[];
    Future<void> independentGroup(String label, Future<void> Function() action) async {
      if (!detection) return action();
      try {
        await action();
      } catch (error, stack) {
        failures.add('$label: $error');
        await sampler.send('note', {'group': label, 'failure': '$error', 'stack': '$stack'});
      }
    }
    Future<void> phoneViewport() async {
      if (!detection) return;
      // Keep the simulated phone surface inside the native 720px buffer.
      // Width drives the product breakpoint; this is not a physical phone.
      t.view.physicalSize = detectionPhoneSize * t.view.devicePixelRatio;
      await binding.setSurfaceSize(detectionPhoneSize);
      await nextFrame();
    }
    if (detection) {
      addTearDown(() async {
        t.view.resetPhysicalSize();
        await binding.setSurfaceSize(null);
      });
    }

    Future<void> runControls(String name) async {
      for (final control in ['control-idle', 'control-ticker', 'control-animation']) {
        if (!only.contains(control)) continue;
        await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(
          child: control == 'control-idle'
              ? const SizedBox(key: ValueKey('detection-control'), width: 80, height: 80,
                  child: ColoredBox(color: Color(0xff336699)))
              : const _DetectionTicker(),
        ))));
        await lab.measure(t, name, control, () async {
          await idle(const Duration(seconds: 10));
          return {'idleSeconds': 10, 'allowedActivity': control == 'control-animation' ? ['fixture animation'] : <String>[]};
        }, kind: 'idle', evidence: (extras) => detectionEvidence(t, control, extras));
      }
    }

    for (final name in themes) {
      if (detection) {
        t.view.resetPhysicalSize();
        await binding.setSurfaceSize(null);
      }
      if (detection && only.isNotEmpty && only.every((scene) => scene.startsWith('control-'))) {
        await runControls(name);
        continue;
      }
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
      final tagged = LabChannel('section-tags', [
        ...mixKinds(560),
        for (var i = 0; i < 40; i++) i % 6 == 0 ? 'image' : 'task',
      ]);
      tagged.tasks.clear();
      const statuses = ['todo', 'in_progress', 'in_review', 'done', 'closed'];
      for (final (i, row) in tagged.rows.indexed) {
        final status = statuses[i % statuses.length];
        row.addAll({
          'taskNumber': i + 1, 'taskStatus': status,
          'taskTitle': 'Tagged section task ${i + 1}',
          'taskId': 'tag-task-$i',
        });
        tagged.tasks.add({
          'id': row['taskId'], 'messageId': row['id'],
          'channelId': tagged.id, 'taskNumber': i + 1,
          'title': row['taskTitle'], 'status': status,
          'claimedByName': 'Bob Li',
        });
      }
      final mounts = {for (final k in rowKinds) k: LabChannel('mount-$k', List.filled(120, k))};
      final parent = mix.rows.lastWhere((r) => mix.summaries.containsKey(r['id']));
      final threadId = 'thread-${parent['id']}';
      final thread = LabChannel(threadId, [for (final k in mixKinds(40)) k == 'thread-summary' || k == 'task' ? 'plain' : k], pageDelay: const Duration(milliseconds: 150));
      final channels = [mix, openA, openB, img, hist, tagged, thread, ...mounts.values];
      final (w, api, client) = await labWorkspace(channels, images);
      ValueChanged<ScrollNotification>? observeScroll;
      final sectionFiles = [
        for (var i = 0; i < 240; i++) {
          'id': 'section-image-$i', 'messageId': tagged.rows[i]['id'],
          'channelId': tagged.id, 'filename': 'Section image $i.png',
          'mimeType': 'image/png', 'sizeBytes': images.pngs[i % 4].$3.length,
          'width': LabImages.sizes[i % 4].$1,
          'height': LabImages.sizes[i % 4].$2,
          'thumbnailUrl': images.url(i % 4, 'section-file-$i'),
          'createdAt': tagged.rows[i]['createdAt'],
          'source': {'type': 'channel', 'channelId': tagged.id},
        },
      ];
      api.routes['GET /channels/${tagged.id}/files'] = (_) => {
        'files': sectionFiles, 'nextCursor': null,
      };
      api.routes['GET /channels/mix/threads/${parent['id']}'] = (_) => {'threadChannelId': threadId};
      w.channel = mix.record;
      await w.selectChannel(mix.record);
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: raftTheme(family, dark: dark),
        home: Scaffold(body: _Host(w: w, onScroll: (notification) => observeScroll?.call(notification))),
      ));
      String newest(LabChannel c) => c.rows.last['id'] as String;
      final shown = await waitUntil(() => visibleText(newest(mix)).evaluate().isNotEmpty, limit: const Duration(seconds: 20));
      if (shown < 0) {
        failures.add('$name: mix channel never published its newest row');
        if (detection) {
          await sampler.send('note', {'theme': name, 'initialArrivalFailure': {
            'channel': w.channel?.id, 'expectedMessage': newest(mix), 'acceptedRows': w.messageDomain.messages.length,
            'loading': w.messageDomain.state.channelLoading, 'error': w.error?.toString(),
            'mountedTargetRows': messageRow(newest(mix)).evaluate().length,
            'fixtureHits': api.hits, 'fixtureMisses': api.misses,
          }});
        }
      }
      // RAFT_LAB_WARM_FONTS=1: let the idle font warm-up finish before any
      // scenario, so first-use system-font fallback stalls (fontconfig) are not
      // mixed into the measured frames; the time it took is recorded.
      if (_cfg('RAFT_LAB_WARM_FONTS') == '1') {
        final warming = Stopwatch()..start();
        final pendingAtStart = RaftFontWarmUp.pending;
        final warmed = await waitUntil(() => RaftFontWarmUp.pending == 0, limit: const Duration(seconds: 120));
        await idle(const Duration(milliseconds: 800));
        await sampler.send('note', {'theme': name, 'fontWarmUp': {'pendingAtStart': pendingAtStart, 'drainedAfterMs': warmed, 'totalMs': warming.elapsedMilliseconds}});
      }

      // RAFT_LAB_FONT_KEYS=1: after every frame, walk the render tree for text
      // and note each (family, fallback list, weight, slant, variations, locale)
      // combination the engine has not resolved before, with the scenario time
      // and whether the idle font warm-up covers it. Combinations the warm-up
      // misses are the ones whose first use stalls a frame.
      if (_cfg('RAFT_LAB_FONT_KEYS') == '1') {
        final warm = <String>{};
        String fontKey(TextStyle st) => '${st.fontFamily}|${st.fontFamilyFallback}|${st.fontWeight?.value}|${st.fontStyle?.name}|${st.fontVariations?.map((v) => '${v.axis}=${v.value}').join(',')}|${st.locale}';
        final themeNow = Theme.of(t.element(find.byType(Scaffold).first));
        for (final st in raftFontWarmUpStyles(themeNow)) {
          warm.add(fontKey(st));
        }
        final known = <String>{...warm};
        final cold = <Map<String, Object?>>[];
        final clock = Stopwatch()..start();
        void scan(Duration _) {
          void visit(RenderObject r) {
            if (r is RenderParagraph) {
              void span(InlineSpan sp, TextStyle? parent) {
                final eff = sp.style == null ? parent : (parent?.merge(sp.style) ?? sp.style);
                if (sp is TextSpan && (sp.text?.isNotEmpty ?? false) && eff != null) {
                  final key = fontKey(eff);
                  if (known.add(key)) {
                    cold.add({'atMs': clock.elapsedMilliseconds, 'key': key, 'sample': '${sp.text!.substring(0, math.min(14, sp.text!.length))} @${eff.fontSize}', 'warmUpCovered': warm.contains(key)});
                  }
                }
                if (sp is TextSpan) {
                  for (final c in sp.children ?? const <InlineSpan>[]) {
                    span(c, eff);
                  }
                }
              }
              span(r.text, null);
            }
            r.visitChildren(visit);
          }
          for (final view in t.binding.renderViews) {
            visit(view);
          }
        }
        SchedulerBinding.instance.addPersistentFrameCallback(scan);
        fontKeyReport = () async {
          await sampler.send('note', {'theme': name, 'fontKeys': List.of(cold)});
          cold.clear();
        };
      }

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

      /// Drags the timeline by [dy] px toward older history over [time] from
      /// the avatar gutter (content such as images or code may claim drags),
      /// then holds still before lifting so no fling follows.
      Future<void> userDrag(double dy, Duration time) async {
        final chat = t.getRect(find.byType(RaftChatView).first);
        final gesture = await t.startGesture(Offset(chat.left + 24, chat.center.dy), kind: PointerDeviceKind.touch);
        final clock = Stopwatch()..start();
        var done = 0.0;
        while (done < dy) {
          await nextFrame();
          final step = math.min(dy - done, dy * clock.elapsedMicroseconds / time.inMicroseconds - done);
          if (step <= 0) continue;
          await gesture.moveBy(Offset(0, step), timeStamp: Duration(microseconds: clock.elapsedMicroseconds));
          done += step;
        }
        await idle(const Duration(milliseconds: 150));
        await gesture.moveBy(Offset.zero, timeStamp: Duration(microseconds: clock.elapsedMicroseconds));
        await gesture.up(timeStamp: Duration(microseconds: clock.elapsedMicroseconds));
      }

      Map<String, Object?> moved(ScrollPosition p, double from) => {
        'startOffset': from, 'endOffset': p.pixels, 'movedPx': (p.pixels - from).abs(),
        'axisDirection': p.axisDirection.name, 'minScrollExtent': p.minScrollExtent, 'maxScrollExtent': p.maxScrollExtent,
        'viewportDimension': p.viewportDimension,
      };

      Future<void> run(String scenario, Future<Map<String, Object?>?> Function() action, {String kind = 'continuous', Future<void> Function()? prepare, bool warmup = false}) async {
        if (!wants(scenario)) return;
        await independentGroup('$name/$scenario', () async {
        await prepare?.call();
        final record = await lab.measure(t, name, scenario, action, kind: kind, warmup: warmup,
          evidence: detection ? (extras) => detectionEvidence(t, scenario, extras) : null);
        await fontKeyReport?.call();
        if (record['failure'] != null) failures.add('$name/$scenario: ${record['failure']}');
        final exception = t.takeException();
        if (exception != null) failures.add('$name/$scenario: $exception');
        });
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
        final p = position(), from = p.pixels, rowsBefore = w.messageDomain.messages.length;
        final servedBefore = hist.olderPagesServed;
        var notifications = 0, dragNotifications = 0, overscrollCount = 0;
        var overscrollMin = 0.0, overscrollMax = 0.0;
        if (detection) {
          observeScroll = (notification) {
            if (notification.metrics.axis != Axis.vertical || notification.depth != 0) return;
            notifications++;
            if (notification is ScrollUpdateNotification && notification.dragDetails != null) dragNotifications++;
            if (notification is OverscrollNotification) {
              overscrollCount++;
              overscrollMin = math.min(overscrollMin, notification.overscroll);
              overscrollMax = math.max(overscrollMax, notification.overscroll);
            }
          };
        }
        try {
        // Grab the avatar gutter, not row content: with semantics enabled a
        // drag starting on row content did not scroll (see
        // docs/performance-lab.md); images and code may claim drags too.
        final chat = t.getRect(find.byType(RaftChatView).first);
        final gesture = await t.startGesture(Offset(chat.left + 24, chat.center.dy), kind: PointerDeviceKind.touch);
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
        return {...moved(p, from), 'pxPerSecond': 1800, 'olderPagesServed': hist.olderPagesServed - servedBefore, 'rowsBefore': rowsBefore, 'rowsAfter': w.messageDomain.messages.length,
          if (detection) 'scrollNotifications': {'collected': notifications > 0, 'input': 'simulated touch drag',
            'notifications': notifications, 'dragUpdates': dragNotifications,
            'overscrollCount': overscrollCount, 'overscrollMin': overscrollMin, 'overscrollMax': overscrollMax}};
        } finally {
          observeScroll = null;
        }
      });

      // Desktop scrollbar: a mouse holds the timeline's thumb and sweeps it
      // between the latest end and the top of the track. Records how far the
      // thumb strayed from the pointer (sampled) and history pages requested.
      Future<Map<String, Object?>> thumbDrag(Duration sweep) async {
        final p = position(), from = p.pixels, served = mix.olderPagesServed;
        final center = t.getCenter(find.byType(RaftChatView).first);
        // Show the bar with a small wheel scroll, then let it fade in.
        await t.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, -4)));
        await idle(const Duration(milliseconds: 400));
        final start = scrollbarThumb(t);
        if (start == null) throw StateError('no scrollbar thumb on this platform');
        const grab = 6.0;
        final x = start.center.dx, y0 = start.top + grab, y1 = grab + 2;
        final gesture = await t.startGesture(Offset(x, y0), kind: PointerDeviceKind.mouse);
        final clock = Stopwatch()..start();
        final half = sweep.inMicroseconds.toDouble();
        var frames = 0, maxError = 0.0, sampled = 0;
        final total = seconds * 1e6;
        while (clock.elapsedMicroseconds < total) {
          await nextFrame();
          final now = clock.elapsedMicroseconds;
          // Triangle wave: up the track over [sweep], back down over [sweep].
          final phase = (now % (2 * half)) / half;
          final k = phase < 1 ? phase : 2 - phase;
          final y = y0 + (y1 - y0) * k.clamp(0.0, 1.0);
          await gesture.moveTo(Offset(x, y), timeStamp: Duration(microseconds: now));
          if (++frames % 15 == 0) {
            await nextFrame();
            final thumb = scrollbarThumb(t);
            if (thumb != null) {
              sampled++;
              maxError = math.max(maxError, (thumb.top + grab - y).abs());
            }
          }
        }
        await gesture.up(timeStamp: Duration(microseconds: clock.elapsedMicroseconds));
        await idle(const Duration(milliseconds: 300));
        return {...moved(p, from), 'thumbErrorMaxPx': maxError, 'thumbSamples': sampled, 'trackPx': y0 - y1,
          'sweepMs': sweep.inMilliseconds, 'olderPagesServed': mix.olderPagesServed - served};
      }

      // Reading pace: one sweep up the track and one back, each over half the
      // scenario. Fast: full-track sweeps of 500 ms each way (jumps of
      // several screens per frame).
      await run('scrollbar-drag', prepare: () => show(mix, latest: true),
          () => thumbDrag(Duration(microseconds: seconds * 500000)));
      await run('scrollbar-sweep', prepare: () => show(mix, latest: true),
          () => thumbDrag(const Duration(milliseconds: 500)));

      // Four live arrivals per second while the reader is 2500 px up the
      // history; the row being read must not move.
      await run('arrival-scrolled-up', prepare: () async {
        await show(mix, latest: true);
        // A real user drag (not jumpTo): the product decides whether the
        // reader left the bottom from user scroll notifications.
        await userDrag(2500, const Duration(milliseconds: 1500));
        await lab.settle(t, time: const Duration(milliseconds: 800));
      }, () async {
        final known = {for (final r in mix.rows) r['id'] as String};
        final viewportBox = timelineScrollable(t).context.findRenderObject() as RenderBox;
        final viewport = viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
        RenderBox? anchorBox;
        String? anchor;
        var best = double.infinity;
        for (final id in mountedIds(known)) {
          final box = visibleRowBox(id, viewport);
          if (box == null) continue;
          final d = (box.localToGlobal(Offset.zero).dy - viewport.center.dy).abs();
          if (d < best) {
            best = d;
            anchor = id;
            anchorBox = box;
          }
        }
        final y0 = anchorBox?.localToGlobal(Offset.zero).dy;
        final offsetBefore = position().pixels;
        var drift = 0.0, lost = 0, sampled = 0, remounts = 0, frame = 0;
        var active = true;
        void sample(Duration _) {
          if (!active) return;
          frame++;
          // A replaced render object means the read row was remounted; look
          // it up again (rarely: the lookup walks the tree).
          if (anchor != null && !(anchorBox?.attached ?? false) && (anchorBox != null || frame % 8 == 0)) {
            if (anchorBox != null) remounts++;
            anchorBox = visibleRowBox(anchor, viewport);
          }
          final box = anchorBox;
          if (box == null || !box.attached || y0 == null) {
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
          client.emit('message:new', labRow('mix', mixCycle[k % mixCycle.length], 600 + k, others: true));
          await idle(const Duration(milliseconds: 250));
        }
        active = false;
        final visibleAfter = [for (final id in mountedIds({...known, for (var k = 0; k < count; k++) 'mix-${600 + k}'})) if (visibleRowBox(id, viewport) != null) id]..sort();
        return {'arrivals': count, 'anchor': anchor, 'offsetBefore': offsetBefore, 'offsetAfter': position().pixels, 'visibleAfter': visibleAfter, 'anchorDriftPx': drift, 'anchorLostFrames': lost, 'anchorSampledFrames': sampled, 'anchorRemounts': remounts};
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
        final parentMessage = w.messageDomain.messages.firstWhere((m) => m.id == parent['id']);
        final last = thread.rows.last['id'] as String;
        final threadView = find.byWidgetPredicate((x) => x is RaftChatView && x.thread);
        final opens = <Map<String, Object?>>[];
        for (var i = 0; i < 5; i++) {
          final t0 = developer.Timeline.now;
          unawaited(w.messageDomain.threads.openThread(parentMessage));
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

      // Hold one touch throughout: repeatedly expose a neighboring section
      // without accepting it. This isolates drag layout/paint from the work
      // performed when a section is selected after release.
      // These are opt-in mobile scenarios; the default desktop suite has no
      // horizontal section pager.
      if (only.isNotEmpty && (wants('section-drag') || wants('section-back-drag') || wants('section-cycle'))) {
        await independentGroup('$name/sections', () async {
        await phoneViewport();
        await show(tagged, latest: true);
        await t.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: raftTheme(family, dark: dark),
          home: Scaffold(body: ConversationPanel(controller: w)),
        ));
        await lab.settle(t, time: const Duration(seconds: 2));
        // Visit the real Tasks adapter first. A never-visited neighbor is only
        // a placeholder, which cannot establish populated-page performance.
        expect(tagged.tasks, hasLength(600));
        await t.tap(find.byKey(const ValueKey('panel-tab-tasks')));
        final taskShown = await waitUntil(
          () => find.byType(RaftTaskCard).evaluate().isNotEmpty,
          limit: const Duration(seconds: 15),
        );
        expect(taskShown, greaterThanOrEqualTo(0));
        await lab.settle(t, time: const Duration(seconds: 2));
        expect(find.text('No tasks'), findsNothing);
        await t.tap(find.byKey(const ValueKey('panel-tab-files')));
        final filesShown = await waitUntil(
          () => w.channelFilesStore(tagged.id).files.length == sectionFiles.length &&
              find.descendant(of: find.byType(SourceChannelFilesView),
                matching: find.byWidgetPredicate((v) => v is RawImage && v.image != null)).evaluate().length >= 5,
          limit: const Duration(seconds: 20),
        );
        expect(filesShown, greaterThanOrEqualTo(0));
        expect(find.text('No files yet'), findsNothing);
        await lab.settle(t, time: const Duration(seconds: 2));
        await t.tap(find.byKey(const ValueKey('panel-tab-chat')));
        await lab.settle(t, time: const Duration(seconds: 2));
        expect(find.byType(RaftTaskCard, skipOffstage: false), findsWidgets);
        final pager = find.byType(PageView).first;
        final bounds = t.getRect(pager);
        final visibleTags = find.byType(RaftMountedMessageTaskChip).evaluate()
            .where((e) => t.getRect(find.byWidget(e.widget)).overlaps(bounds)).length;
        // The five-tag requirement belongs to the held-drag color replay.
        // Detection's shorter viewport still visits the populated Tasks/Files
        // pages above; its cycle records and checks each accepted section.
        if (!detection || wants('section-drag') || wants('section-back-drag')) {
          expect(visibleTags, greaterThanOrEqualTo(5));
        }
        expect(t.getSize(pager).width, lessThan(RaftLayoutMetrics.desktopBreakpoint));
        if (wants('section-drag') || (!detection && wants('section-cycle'))) {
        // Native screenshots are read by a host-side capture watcher during
        // these holds, outside the measured intervals. Keep task IDs and exact
        // on-screen geometry so colors can be compared after translation.
        Future<void> captureTags(String label) async {
          final tags = <Map<String, Object?>>[];
          for (final e in find.byType(RaftMountedMessageTaskChip).evaluate()) {
            final rect = t.getRect(find.byWidget(e.widget));
            if (!rect.overlaps(bounds)) continue;
            tags.add({'number': (e.widget as RaftMountedMessageTaskChip).number,
              'rect': [rect.left, rect.top, rect.right, rect.bottom]});
          }
          await sampler.send('note', {'theme': name, 'capture': label,
            'dpr': view.devicePixelRatio, 'tags': tags});
          await idle(const Duration(seconds: 2));
        }
        await captureTags('idle');
        final colorDrag = await t.startGesture(Offset(bounds.right - 24, bounds.top + 80), kind: PointerDeviceKind.touch);
        await colorDrag.moveBy(const Offset(-20, 0));
        await nextFrame();
        await colorDrag.moveBy(Offset(-bounds.width * .3, 0));
        await idle(const Duration(milliseconds: 300));
        await captureTags('held');
        await colorDrag.moveBy(Offset(bounds.width * .3 + 20, 0));
        await colorDrag.up();
        await lab.settle(t, time: const Duration(milliseconds: 500));
        await captureTags('returned');
        // Reproduction reported on device: fully leave Chat, then keep a
        // finger down while exposing it from Tasks. Record this separately
        // from timings so screen recording cannot inflate the benchmark.
        final videoClock = Stopwatch()..start();
        await sampler.send('note', {'theme': name, 'capture': 'video-start',
          'videoSeconds': 30});
        await idle(const Duration(seconds: 2));
        final forwardOrigin = Offset(bounds.right - 24, bounds.top + 80);
        final forwardDrag = await t.startGesture(forwardOrigin, kind: PointerDeviceKind.touch);
        final forwardClock = Stopwatch()..start();
        while (forwardClock.elapsedMilliseconds < 400) {
          await forwardDrag.moveTo(forwardOrigin -
            Offset(bounds.width * .8 * forwardClock.elapsedMilliseconds / 400, 0));
          await nextFrame();
        }
        await forwardDrag.up();
        final fullyTasks = await waitUntil(() => w.location.chatTab == 'tasks',
          limit: const Duration(seconds: 2));
        expect(fullyTasks, greaterThanOrEqualTo(0));
        await lab.settle(t, time: const Duration(seconds: 1));
        final backDrag = await t.startGesture(
          Offset(bounds.left + 24, bounds.top + 80), kind: PointerDeviceKind.touch);
        await backDrag.moveBy(const Offset(20, 0));
        await nextFrame();
        var backFraction = 0.0;
        for (final fraction in [.15, .4, .65, .85]) {
          await backDrag.moveBy(Offset(bounds.width * (fraction - backFraction), 0));
          backFraction = fraction;
          await idle(const Duration(milliseconds: 300));
          await captureTags('back-${(fraction * 100).round()}');
        }
        await backDrag.up();
        await lab.settle(t, time: const Duration(seconds: 1));
        expect(w.location.chatTab ?? 'chat', 'chat');
        await captureTags('back-returned');
        // The host records for 30 seconds. Leave additional setup headroom,
        // then start frame measurement only after the recorder has stopped.
        while (videoClock.elapsed < const Duration(seconds: 35)) {
          await idle(const Duration(milliseconds: 200));
        }
        }
        await run('section-drag', () async {
          final bounds = t.getRect(pager);
          final origin = Offset(bounds.left + bounds.width * .85, bounds.top + bounds.height * .3);
          final gesture = await t.startGesture(origin, kind: PointerDeviceKind.touch);
          final clock = Stopwatch()..start();
          var moves = 0;
          while (clock.elapsedMilliseconds < seconds * 1000) {
            final phase = (clock.elapsedMilliseconds % 1200) / 600;
            final fraction = phase <= 1 ? phase : 2 - phase;
            await gesture.moveTo(origin - Offset(bounds.width * .65 * fraction, 0));
            await nextFrame();
            moves++;
          }
          await gesture.moveTo(origin);
          await gesture.up();
          return {
            'touchMoves': moves,
            'acceptedSection': w.location.chatTab ?? 'chat',
            'taskRows': tagged.tasks.length,
            'visibleChatTags': visibleTags,
            'fileRows': w.channelFilesStore(tagged.id).files.length,
            'decodedFileThumbnails': find.descendant(of: find.byType(SourceChannelFilesView, skipOffstage: false),
              matching: find.byWidgetPredicate((v) => v is RawImage && v.image != null, skipOffstage: false)).evaluate().length,
            'retainedTaskCards': find.byType(RaftTaskCard, skipOffstage: false).evaluate().length,
            'chatRows': w.messageDomain.timeline().length,
          };
        });
        await lab.settle(t, time: const Duration(seconds: 1));
        if (wants('section-back-drag')) {
          final forwardOrigin = Offset(bounds.right - 24, bounds.top + 80);
          final forward = await t.startGesture(forwardOrigin, kind: PointerDeviceKind.touch);
          final forwardClock = Stopwatch()..start();
          while (forwardClock.elapsedMilliseconds < 400) {
            await forward.moveTo(forwardOrigin - Offset(bounds.width * .8 * forwardClock.elapsedMilliseconds / 400, 0));
            await nextFrame();
          }
          await forward.up();
          expect(await waitUntil(() => w.location.chatTab == 'tasks',
            limit: const Duration(seconds: 2)), greaterThanOrEqualTo(0));
          await lab.settle(t, time: const Duration(seconds: 1));
          await run('section-back-drag', () async {
            final origin = Offset(bounds.left + bounds.width * .15, bounds.top + bounds.height * .3);
            final gesture = await t.startGesture(origin, kind: PointerDeviceKind.touch);
            final clock = Stopwatch()..start();
            var moves = 0;
            while (clock.elapsedMilliseconds < seconds * 1000) {
              final phase = (clock.elapsedMilliseconds % 1200) / 600;
              final fraction = phase <= 1 ? phase : 2 - phase;
              await gesture.moveTo(origin + Offset(bounds.width * .65 * fraction, 0));
              await nextFrame();
              moves++;
              expect(w.location.chatTab, 'tasks');
            }
            await gesture.moveTo(origin);
            await gesture.up();
            return {'touchMoves': moves, 'acceptedSection': w.location.chatTab,
              'taskRows': tagged.tasks.length, 'visibleChatTags': visibleTags,
              'fileRows': w.channelFilesStore(tagged.id).files.length,
              'retainedTaskCards': find.byType(RaftTaskCard, skipOffstage: false).evaluate().length,
              'chatRows': w.messageDomain.timeline().length};
          });
          await t.tap(find.byKey(const ValueKey('panel-tab-chat')));
          await lab.settle(t, time: const Duration(seconds: 1));
        }
        await run('section-cycle', () async {
          final steps = <String>[];
          final clock = Stopwatch()..start();
          while (clock.elapsedMilliseconds < seconds * 1000) {
            for (final (target, direction) in [('tasks', -1), ('files', -1), ('tasks', 1), ('chat', 1)]) {
              final rect = t.getRect(pager);
              final origin = Offset(rect.left + rect.width * (direction < 0 ? .85 : .15), rect.top + rect.height * .3);
              final gesture = await t.startGesture(origin, kind: PointerDeviceKind.touch);
              final dragClock = Stopwatch()..start();
              while (dragClock.elapsedMilliseconds < 400) {
                await gesture.moveTo(origin + Offset(direction * rect.width * .7 * dragClock.elapsedMilliseconds / 400, 0));
                await nextFrame();
              }
              await gesture.up();
              final accepted = await waitUntil(() => (w.location.chatTab ?? 'chat') == target,
                limit: const Duration(seconds: 2));
              expect(accepted, greaterThanOrEqualTo(0));
              steps.add(target);
              await lab.settle(t, time: const Duration(milliseconds: 200));
            }
          }
          return {'sectionVisits': steps, 'taskRows': tagged.tasks.length,
            'fileRows': w.channelFilesStore(tagged.id).files.length, 'taggedChatRows': tagged.rows.length};
        }, kind: 'transitions');
        });
      }

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
            final cpu0 = threadCpuSeconds();
            p.jumpTo(target);
            await nextFrame();
            final cpu1 = threadCpuSeconds();
            final ids = mountedIds(known);
            final fresh = ids.difference(seen);
            seen.addAll(ids);
            await idle(const Duration(milliseconds: 120));
            steps.add({
              't0': t0, 't1': developer.Timeline.now, 'newRows': fresh.length, 'mounted': ids.length,
              // On-CPU time of the UI thread for the jump and its frame: stable on a busy host.
              if (cpu0 != null && cpu1 != null) 'cpuUs': ((cpu1 - cpu0) * 1e6).round(),
            });
          }
          return {'rowKind': kind, 'steps': steps};
        }, kind: 'mount');
      }


      // Opt-in mobile navigation scenarios (`nav-*`): the production RaftApp on
      // a phone-sized view with populated Agents/Members/channels. Each scenario
      // repeats forward/back transitions; every transition is an `opens` entry
      // so the summary reports the worst UI/raster frame inside it.
      var navMisses = <String, int>{};
      if (only.any((o) => o.startsWith('nav-'))) {
        await independentGroup('$name/navigation', () async {
        await phoneViewport();
        final (seed, napi, nclient) = await labWorkspace(channels, images, mobile: true, ownsClient: false);
        seed.dispose();
        navMisses = napi.misses;
        // Real entry work overlaps navigation: async reads, PNG completion and
        // accepted socket CRUD. Keep this deterministic for revision comparisons.
        napi.responseDelay = const Duration(milliseconds: 80);
        images.responseDelay = const Duration(milliseconds: 120);
        final navAgents = <Map<String, dynamic>>[
          for (final (i, a) in const [
            ('Cindy', 'Engineering operator: turns your ideas into working software'),
            ('Codex', '全栈开发者，帮我搞定产品的端到端交付'),
            ('Grok', '全栈开发者'),
            ('CodexGame', '全栈开发者兼金牌游戏制作人'),
            ('CodexMac', '全栈开发者'),
          ].indexed)
            {
              'id': 'agent-$i', 'name': a.$1.toLowerCase(), 'displayName': a.$1, 'description': a.$2,
              'status': 'active', 'runtime': 'codex', 'model': 'gpt-6', 'machineId': i < 4 ? 'k8s-plus' : 'macbook-pro',
              'avatarUrl': images.url(i % 4, 'agent-avatar-$i'), 'activity': 'online', 'createdAt': '2026-10-01T00:00:00Z',
            },
        ];
        napi.routes['GET /agents'] = (_) => navAgents;
        final navMachines = [
          {'id': 'k8s-plus', 'name': 'K8+', 'status': 'online', 'isComputer': true,
            'userId': 'alice', 'hostname': 'fixture-k8', 'computerVersion': '1.0.44',
            'runtimes': ['codex']},
          {'id': 'macbook-pro', 'name': 'macbook-pro', 'status': 'online'},
        ];
        napi.routes['GET /servers/s1/machines'] = (_) => {'machines': navMachines};
        napi.routes['GET /servers/s1/members'] = (_) => [
          {'userId': 'alice', 'id': 'alice', 'name': 'Alice Zhang', 'displayName': 'Alice Zhang', 'role': 'owner'},
        ];
        napi.patterns.add((
          (o) => o.method == 'GET' && RegExp(r'^/agents/agent-\d+$').hasMatch(o.path),
          (o) => navAgents.firstWhere((a) => a['id'] == o.path.split('/').last),
        ));
        // Every read the nav scenarios trigger is answered here, before the first
        // frame; anything unmatched fails the run (see `navMisses` below).
        final navChannels = [openA, openB, mix, img, hist, tagged];
        napi.routes['GET /channels/inbox'] = (_) => {
          'items': [
            for (final c in navChannels)
              {
                'kind': 'channel', 'channelId': c.id, 'channelName': 'lab-${c.id}',
                'lastMessagePreview': 'Latest in lab-${c.id}', 'unreadCount': 0,
                'lastMessageId': newest(c),
              },
          ],
        };
        napi.patterns.add((
          (o) => o.method == 'GET' && o.path.startsWith('/messages/context/'),
          (o) {
            final id = o.path.split('/').last;
            for (final c in [...navChannels, thread]) {
              final at = c.rows.indexWhere((r) => r['id'] == id);
              if (at >= 0) {
                return {
                  'messages': c.rows.sublist(math.max(0, at - 25), math.min(c.rows.length, at + 25)),
                  'threadSummariesByParentMessageId': c.summaries,
                };
              }
            }
            return {'messages': <dynamic>[]};
          },
        ));
        napi.routes['GET /channels/saved'] = (_) => {'globalTotal': 0, 'saved': <dynamic>[]};
        napi.routes['GET /channels/threads/followed'] = (_) => {'threads': <dynamic>[]};
        napi.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
        napi.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0, 'tickets': <dynamic>[]};
        napi.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
        napi.patterns.add((
          (o) => o.method == 'GET' && RegExp(r'^/agents/[^/]+/skills$').hasMatch(o.path),
          (_) => {'global': <dynamic>[], 'workspace': <dynamic>[]},
        ));
        napi.patterns.add((
          (o) => o.path.contains('/runtime-account-usage/'),
          (_) => {'state': 'unavailable'},
        ));
        napi.routes['GET /channels/mix/threads/${parent['id']}'] = (_) => {'threadChannelId': threadId};
        const navTabs = MobileTabbarSettings(
          order: MobileTabs.configurable,
          enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
        );
        napi.routes['GET /auth/me'] = (_) => {
          'id': 'alice', 'name': 'Alice Zhang', 'email': 'alice@example.invalid', 'emailVerified': true, 'displayLanguage': 'en',
        };
        napi.routes['GET /servers'] = (_) => [
          {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
        ];
        napi.routes['GET /channels/public'] = (_) => <dynamic>[];
        for (final c in channels) {
          napi.routes['GET /channels/${c.id}'] = (_) => c.record.json;
        }
        SharedPreferences.setMockInitialValues({
          'raft.origin': nclient.origin,
          'raft.mode': dark ? 'dark' : 'light', 'raft.light': family.name,
          MobileTabbarStore.preferenceKey: navTabs.encode(),
        });
        final cacheDirectory = await Directory.systemTemp.createTemp('raft-live-navigation-');
        final navCache = LabNavigationCache(File('${cacheDirectory.path}/workspace.sqlite'));
        addTearDown(() async {
          await navCache.close();
          await cacheDirectory.delete(recursive: true);
        });
        final content = LabNavigationContent();
        await NativeSystemFonts.instance.initialize();
        final navigationApp = app.RaftApp(
          services: const AppServices.updatesDisabledForTestOrPreview(),
          sessionStore: nclient.sessionStore,
          createClient: (_, _, _) => nclient,
          initialLocation: Uri(path: '/s/lab'),
          nativeContent: content, nativeSharing: NativeSharing(supported: false),
          openWorkspaceCache: () async => navCache,
        );
        await t.pumpWidget(detection
            ? MediaQuery.fromView(view: t.view, child: navigationApp) : navigationApp);
        await lab.settle(t, time: const Duration(seconds: 2));
        if (await waitUntil(() => content.workspace?.server != null, limit: const Duration(seconds: 10)) < 0) {
          throw StateError('Production app root did not restore the lab workspace; requests=${napi.hits}; misses=${napi.misses}');
        }
        final nw = content.workspace!;
        if (detection) {
          final appView = View.of(t.element(find.byType(app.RaftApp)));
          final media = MediaQuery.sizeOf(t.element(find.byType(Scaffold).first));
          await sampler.send('note', {'theme': name, 'navigationView': {
            'appWidth': appView.physicalSize.width, 'appHeight': appView.physicalSize.height,
            'testWidth': t.view.physicalSize.width, 'testHeight': t.view.physicalSize.height,
            'mobileNavigation': nw.mobileNavigation, 'rootTab': nw.navigation.mobileRootTab,
            'mediaWidth': media.width, 'mediaHeight': media.height,
            'layoutHeld': LayoutHold.held,
            'mobilePages': find.byType(MobileWorkspacePages).evaluate().length,
            'mobileBars': find.byKey(const Key('workspace-mobile-navigation')).evaluate().length,
            'adaptiveLayouts': [
              for (final element in find.byType(RaftAdaptiveWorkspace).evaluate())
                {
                  'navigation': (element.widget as RaftAdaptiveWorkspace).mobileNavigation?.runtimeType.toString(),
                  'rail': (element.widget as RaftAdaptiveWorkspace).mobileRail?.runtimeType.toString(),
                  'constraints': [
                    (element.renderObject as RenderBox?)?.constraints.minWidth,
                    (element.renderObject as RenderBox?)?.constraints.maxWidth,
                    (element.renderObject as RenderBox?)?.constraints.minHeight,
                    (element.renderObject as RenderBox?)?.constraints.maxHeight,
                  ],
                  'renderWidth': (element.renderObject as RenderBox?)?.size.width,
                },
            ],
            'workspaces': [
              for (final element in find.byWidgetPredicate((widget) => widget is WorkspaceView).evaluate())
                {
                  'widget': element.widget.runtimeType.toString(),
                  'routePage': (element.widget as WorkspaceView).mobileRoutePage,
                  'server': (element.widget as WorkspaceView).controller.server?.id,
                  'location': (element.widget as WorkspaceView).controller.location.uri.toString(),
                  'rootTab': (element.widget as WorkspaceView).controller.navigation.mobileRootTab,
                  'phoneRail': RaftAdaptiveWorkspace.phoneRailOf(element),
                  'constraints': [
                    (element.renderObject as RenderBox?)?.constraints.minWidth,
                    (element.renderObject as RenderBox?)?.constraints.maxWidth,
                    (element.renderObject as RenderBox?)?.constraints.minHeight,
                    (element.renderObject as RenderBox?)?.constraints.maxHeight,
                  ],
                  'mediaWidth': MediaQuery.sizeOf(element).width,
                  'mediaHeight': MediaQuery.sizeOf(element).height,
                  'compact': RaftAdaptiveWorkspace.compactOf(element),
                  'renderWidth': (element.renderObject as RenderBox?)?.size.width,
                  'renderHeight': (element.renderObject as RenderBox?)?.size.height,
                },
            ],
          }});
          expect(media.width, lessThan(RaftLayoutMetrics.desktopBreakpoint),
              reason: 'Phone navigation must actually receive the compact MediaQuery.');
          expect(RaftAdaptiveWorkspace.phoneRailOf(t.element(find.byType(Scaffold).first)), isFalse,
              reason: 'Activity-entry actions require bottom navigation; choose a taller phone viewport.');
          expect(find.byKey(const Key('mobile-tab-home')), findsOneWidget,
              reason: 'The phone Home entry must mount before navigation is measured.');
        }
        final navActivity = LabNavigationActivity(
          workspace: nw, client: nclient,
          channels: [openA, openB, mix, thread], agents: navAgents, machines: navMachines,
        );
        if (const bool.fromEnvironment('RAFT_LAB_DEBUG_HOLD')) await idle(const Duration(seconds: 25));
        // A root tab has nothing to pop; popping it would exit the activity.
        var predictiveBacks = 0;
        Future<void> back() async {
          if (nw.navigation.mobileRootTab != null) return;
          if (Platform.isAndroid) {
            final size = view.physicalSize / view.devicePixelRatio;
            Future<Object?> gesture(String method, [double? progress]) {
              const codec = StandardMethodCodec();
              final reply = Completer<Object?>();
              binding.channelBuffers.push('flutter/backgesture', codec.encodeMethodCall(MethodCall(
                method, progress == null ? null : {
                  'touchOffset': [16 + progress * size.width, size.height / 2],
                  'progress': progress, 'swipeEdge': 0,
                },
              )), (data) {
                try { reply.complete(data == null ? null : codec.decodeEnvelope(data)); }
                catch (e, stack) { reply.completeError(e, stack); }
              });
              return reply.future;
            }
            if (await gesture('startBackGesture', 0) == true) {
              predictiveBacks++;
              for (var i = 1; i <= 24; i++) {
                await nextFrame();
                await gesture('updateBackGestureProgress', i / 28);
                // A held gesture must still process background updates. This
                // exercises the gap where no animation ticker is running.
                if (i == 12) await idle(const Duration(milliseconds: 100));
              }
              await gesture('commitBackGesture');
              return;
            }
            failures.add('$name: predictive back was not accepted by the live route');
          }
          await binding.handlePopRoute();
        }
        String screenText() => [
          for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
        ].where((x) => x.isNotEmpty).take(30).join(' | ');

        /// One measured transition: [act], wait for [arrived], then dwell so
        /// the route animation and follow-up work finish inside the interval.
        Future<void> step(List<Map<String, Object?>> opens, String label, Future<void> Function() act, bool Function() arrived, {LabChannel? foreground}) async {
          final t0 = developer.Timeline.now;
          final hits = Map.of(napi.hits), completed = Map.of(napi.completedHits);
          final imageReads = images.reads;
          final backCount = predictiveBacks;
          final cacheReads = navCache.reads, cacheWrites = navCache.writesCompleted;
          final activity = navActivity.transition(foreground: foreground).catchError((Object e) {
            failures.add('$name/$label: live activity failed: $e');
            return <String, Object?>{'failure': e.toString()};
          });
          await act();
          final ms = await waitUntil(arrived, limit: const Duration(seconds: 6));
          await idle(const Duration(milliseconds: 900));
          final live = await activity;
          opens.add({
            'channel': label, 'visibleMs': ms, 't0': t0, 't1': developer.Timeline.now,
            'liveActivity': live, 'imageResponsesStarted': images.reads - imageReads,
            'predictiveBackGestures': predictiveBacks - backCount,
            'cacheReads': navCache.reads - cacheReads,
            'cacheWritesCompleted': navCache.writesCompleted - cacheWrites,
            'requests': {for (final e in napi.hits.entries) if (e.value != (hits[e.key] ?? 0)) e.key: e.value - (hits[e.key] ?? 0)},
            'responses': {for (final e in napi.completedHits.entries) if (e.value != (completed[e.key] ?? 0)) e.key: e.value - (completed[e.key] ?? 0)},
          });
          if (ms < 0) failures.add('$name: nav step $label never arrived');
        }

        Future<void> tabTo(String id) async {
          final tab = find.byKey(Key('mobile-tab-${id == 'chat' ? 'home' : id}'));
          if (await waitUntil(() => tab.evaluate().isNotEmpty, limit: const Duration(seconds: 10)) < 0) {
            final rootView = View.of(t.element(find.byType(app.RaftApp)));
            failures.add('$name: tab $id never mounted; appView=${rootView.physicalSize}; '
                'testView=${t.view.physicalSize}; screen=${screenText()}');
            return;
          }
          await t.tap(tab);
        }

        Future<void> goRoot(String id) async {
          for (var pops = 0; pops < 3 && find.byKey(const Key('mobile-tab-home')).evaluate().isEmpty; pops++) {
            await back();
            await lab.settle(t, time: const Duration(milliseconds: 700));
          }
          await tabTo(id);
          await lab.settle(t, time: const Duration(milliseconds: 1500));
        }

        bool agentOpen() => find.byKey(const Key('agent-profile-overflow-trigger')).evaluate().isNotEmpty ||
            find.byKey(const ValueKey('agent-edit-role')).evaluate().isNotEmpty ||
            find.byKey(const Key('desktop-directory-list')).evaluate().isEmpty;
        bool membersShown() => find.byKey(const ValueKey('desktop-directory-agent-agent-0')).evaluate().isNotEmpty;

        bool computerListShown() => find
            .byKey(const ValueKey('fleet-k8s-plus'))
            .hitTestable()
            .evaluate()
            .isNotEmpty;
        bool computerDetailShown() => find
            .byKey(const Key('computer-mobile-back'))
            .hitTestable()
            .evaluate()
            .isNotEmpty;
        await run(
          'nav-computer-detail',
          prepare: () async {
            await goRoot('computers');
            if (await waitUntil(
                  computerListShown,
                  limit: const Duration(seconds: 10),
                ) <
                0) {
              failures.add('$name: K8+ never listed; screen=${screenText()}');
            }
          },
          () async {
            final opens = <Map<String, Object?>>[];
            final reads = napi.requests;
            final hits = Map.of(napi.hits);
            for (var i = 0; i < 10; i++) {
              await step(
                opens,
                'open-computer-$i',
                () => t.tap(find.byKey(const ValueKey('fleet-k8s-plus'))),
                computerDetailShown,
              );
              await step(opens, 'back-computer-$i', back, computerListShown);
            }
            return {
              'opens': opens,
              'requestsDuringNavigation': napi.requests - reads,
              'requestHits': {
                for (final e in napi.hits.entries)
                  if (e.value != (hits[e.key] ?? 0))
                    e.key: e.value - (hits[e.key] ?? 0),
              },
            };
          },
          kind: 'transitions',
        );

        await run('nav-members-agent', prepare: () async {
          await goRoot('members');
          if (await waitUntil(membersShown, limit: const Duration(seconds: 10)) < 0) failures.add('$name: members never listed; misses=${napi.misses}; hits=${napi.hits}; screen=${screenText()}; section=${nw.section}');
            if (Platform.environment['RAFT_LAB_DEBUG_HOLD'] != null || const bool.fromEnvironment('RAFT_LAB_DEBUG_HOLD')) await idle(const Duration(seconds: 40));
        }, () async {
          final opens = <Map<String, Object?>>[];
          for (var i = 0; i < 3; i++) {
            final id = 'agent-${i % 3}';
            await step(opens, 'open-agent-$i', () => t.tap(find.byKey(ValueKey('desktop-directory-agent-$id'))), agentOpen);
            await step(opens, 'back-agent-$i', back, membersShown);
          }
          return {'opens': opens};
        }, kind: 'transitions');

        bool chatShown(LabChannel c, {bool thread = false}) {
          final chat = find.byWidgetPredicate((widget) => widget is RaftChatView &&
              widget.thread == thread && (thread ? widget.controller.threadChannelId : widget.controller.channel?.id) == c.id &&
              (thread ? widget.controller.replies : widget.controller.messageDomain.messages).isNotEmpty);
          return find.descendant(of: chat, matching: find.byWidgetPredicate((widget) =>
              widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('message-')))
              .hitTestable().evaluate().isNotEmpty;
        }
        // Live arrivals deliberately preserve the reading position. Requiring
        // the ever-changing last message would falsely fail a populated cached
        // page and would encourage resetting the user's scroll to make it pass.
        bool channelShown(LabChannel c) => chatShown(c);
        bool homeShown() => find.text('lab-open-a', findRichText: true).evaluate().isNotEmpty;
        await run('nav-home-channel', prepare: () async {
          await goRoot('home');
          if (await waitUntil(homeShown, limit: const Duration(seconds: 10)) < 0) failures.add('$name: home never listed channels');
        }, () async {
          final opens = <Map<String, Object?>>[];
          for (var i = 0; i < 3; i++) {
            final target = i.isEven ? openA : openB;
            await step(opens, 'open-channel-$i', () => t.tap(find.text('lab-${target.id}', findRichText: true)), () => channelShown(target), foreground: target);
            await step(opens, 'back-channel-$i', back, homeShown, foreground: target);
          }
          return {'opens': opens};
        }, kind: 'transitions');

        bool homeListShown() => find.text('Saved', findRichText: true).evaluate().isNotEmpty;
        await run('nav-home-activity', prepare: () async {
          await goRoot('home');
          if (await waitUntil(homeListShown, limit: const Duration(seconds: 10)) < 0) failures.add('$name: home list never shown');
        }, () async {
          final opens = <Map<String, Object?>>[];
          for (var i = 0; i < 3; i++) {
            await step(opens, 'open-activity-$i', () => t.tap(find.text('Activity', findRichText: true).first), _activityRowShown);
            await step(opens, 'back-activity-$i', back, homeListShown);
          }
          return {'opens': opens};
        }, kind: 'transitions');

        bool threadShown() => nw.threadIdentity != null && chatShown(thread, thread: true);
        await run('nav-channel-thread', prepare: () async {
          await goRoot('home');
          await t.tap(find.text('lab-mix', findRichText: true));
          if (await waitUntil(() => channelShown(mix), limit: const Duration(seconds: 10)) < 0) failures.add('$name: mix never shown');
          await lab.settle(t, time: const Duration(seconds: 1));
        }, () async {
          final opens = <Map<String, Object?>>[];
          for (var i = 0; i < 3; i++) {
            // Same call the thread-summary tap makes (RaftChatView.onOpenThread).
            await step(opens, 'open-thread-$i', () => nw.openThreadIdentity(parentChannelId: mix.id, parentMessageId: '${parent['id']}', initialThreadChannelId: threadId), threadShown, foreground: thread);
            await step(opens, 'back-thread-$i', back, () => nw.threadIdentity == null && channelShown(mix), foreground: mix);
          }
          return {'opens': opens};
        }, kind: 'transitions');

        Finder activityEntry() => find.byKey(const ValueKey('activity-channel-open-a'));
        await run('nav-activity-item', prepare: () async {
          await goRoot('home');
          await t.tap(find.text('Activity', findRichText: true).first);
          if (await waitUntil(_activityRowShown, limit: const Duration(seconds: 10)) < 0) failures.add('$name: activity entries never listed');
          await lab.settle(t, time: const Duration(seconds: 1));
        }, () async {
          final opens = <Map<String, Object?>>[];
          for (var i = 0; i < 3; i++) {
            await step(opens, 'open-activity-item-$i', () => t.tap(activityEntry()), () => channelShown(openA));
            await step(opens, 'back-activity-item-$i', back, _activityRowShown);
          }
          return {'opens': opens};
        }, kind: 'transitions');

        await run('nav-tabs', prepare: () => goRoot('home'), () async {
          final opens = <Map<String, Object?>>[];
          for (final id in ['tasks', 'members', 'settings', 'chat', 'members', 'tasks', 'chat']) {
            await step(opens, 'tab-$id', () => tabTo(id), () => nw.navigation.mobileRootTab == id);
          }
          return {'opens': opens};
        }, kind: 'transitions');

        await run('nav-settings-sub', prepare: () => goRoot('settings'), () async {
          final opens = <Map<String, Object?>>[];
          for (var i = 0; i < 2; i++) {
            await step(opens, 'open-appearance-$i', () => t.tap(find.text('Appearance', findRichText: true).first), () => nw.navigation.mobileRootTab == null);
            await step(opens, 'back-appearance-$i', back, () => nw.navigation.mobileRootTab == 'settings');
          }
          return {'opens': opens};
        }, kind: 'transitions');
        });
      }

      // RAFT_LAB_SCENARIOS=...,idle-final: after the last theme's scenarios the
      // window stays visible with no input; the record's cpuSeconds, frames
      // (FrameTimings: none expected) and the embedder's vsync lines in the log
      // show what an untouched window costs. RAFT_LAB_IDLE_SECONDS (default 30).
      // The test binding re-schedules a frame after every frame, so this is not
      // an idle proof; tool/idle-cpu/run.sh measures idle with a plain binding.
      if (name == themes.last && only.contains('idle-final')) {
        final idleSeconds = int.tryParse(_cfg('RAFT_LAB_IDLE_SECONDS')) ?? 30;
        if (detection) {
          FocusManager.instance.primaryFocus?.unfocus();
          await idle(const Duration(seconds: 1));
        }
        await run('idle-final', () async {
          await idle(Duration(seconds: idleSeconds));
          return {'idleSeconds': idleSeconds};
        }, kind: 'idle');
      }

      await runControls(name);

      // Soft keyboard. An unfiltered Android run includes it. Any other host
      // includes it only when it is named: it replaces this theme's tree with
      // the production phone app. Measured windows are the inset slides.
      if (wants('keyboard') && (only.isNotEmpty || Platform.isAndroid)) {
        await independentGroup('$name/keyboard', () async {
        await phoneViewport();
        final closeKeyboard = await mountKeyboardChat(t, images: images, family: family, dark: dark,
            useTestViewport: detection);
        final keyboardRounds = int.tryParse(_cfg('RAFT_LAB_ROUNDS')) ?? 1;
        try {
          // One recorded warmup. Later rounds share this process cache, so
          // they are one batch, not independent samples.
          await run('keyboard', () => keyboardOpenClose(t, profilePhases: !detection || phases), kind: 'keyboard', warmup: true);
          for (var i = 0; i < keyboardRounds; i++) {
            await run('keyboard', () => keyboardOpenClose(t, profilePhases: !detection || phases), kind: 'keyboard');
          }
        } finally {
          await closeKeyboard();
        }
        });
      }

      if (only.any((o) => o.startsWith('nav-'))) {
        // The nav workspace owns its own adapter; report what it still misses.
        if (navMisses.isNotEmpty) {
          final list = navMisses.entries.map((e) => '${e.key} x${e.value}').toList();
          await sampler.send('note', {'theme': name, 'unmatchedRoutes': list});
          failures.add('$name: nav scenarios made unmatched fixture requests (add routes in perf_lab_test.dart): ${list.join(', ')}');
        }
      }
      if (api.misses.isNotEmpty) {
        await sampler.send('note', {'theme': name, 'unmatchedRoutes': api.misses.entries.map((e) => '${e.key} x${e.value}').toList()});
      }
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await t.pump();
    }
    binding.reportData = {'perfLab': {'scenarios': lab.results.length, 'failures': failures, 'samplerAttached': sampler.attached}};
    await sampler.send('done', {'failures': failures, 'performanceHint': binding.performanceHintDiagnostics});
    expect(failures, isEmpty);
    if (LabSampler.standaloneOut != null) {
      // Self-driving build: nothing else will end the process.
      exit(failures.isEmpty ? 0 : 1);
    }
  }, semanticsEnabled: semantics);
}
