// Idle CPU / frame-rate lab (Linux desktop, profile build). A plain app, not a
// flutter_test binding: LiveTestWidgetsFlutterBinding re-schedules a frame
// after every frame, which would hide exactly the bug class measured here.
//
// Boots the real WorkspaceView against the desktop fixture client, navigates
// to each scenario with synthetic pointer taps, lets it settle, then measures
// for RAFT_IDLE_SECONDS (default 30) while nothing animates on screen:
//   * process CPU time from /proc/self/stat as a percentage of one core
//   * frames drawn per second (persistent frame callback)
//   * Priority.idle admission attempts per second (the rejected-task retry)
//   * Timer/microtask creations per second, counted through the root zone
// Settings (environment, or --dart-define on Android): RAFT_IDLE_FIXTURE (path
// of desktop-fixture.json) or RAFT_IDLE_FIXTURE_JSON (its text), RAFT_IDLE_OUT
// (json file), RAFT_IDLE_ONLY (comma list), RAFT_IDLE_SECONDS, RAFT_IDLE_LABEL.
// Run it with tool/idle-cpu/run.sh. Measurement only; nothing imports it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/desktop_screens_test.dart' show DesktopFixtureClient;

int _cpuTicks() {
  final stat = File('/proc/self/stat').readAsStringSync();
  final f = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return int.parse(f[11]) + int.parse(f[12]); // utime + stime
}

int zeroTimers = 0, timers = 0, microtasks = 0;
// Timer creations by duration and creator (first app frames of the stack).
final timerSites = <String, int>{};
bool _recording = false;

String _site(Duration d) {
  final frames = StackTrace.current
      .toString()
      .split('\n')
      .where((l) => l.contains('package:raft') || l.contains('package:flutter/'))
      .take(3)
      .map((l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').trim());
  return '${d.inMilliseconds}ms ${frames.join(' < ')}';
}

void main() {
  runZoned(_main, zoneSpecification: ZoneSpecification(
    createTimer: (self, parent, zone, d, f) {
      timers++;
      if (d <= Duration.zero) zeroTimers++;
      if (_recording) {
        final site = _site(d);
        timerSites[site] = (timerSites[site] ?? 0) + 1;
      }
      return parent.createTimer(zone, d, f);
    },
    scheduleMicrotask: (self, parent, zone, f) {
      microtasks++;
      parent.scheduleMicrotask(zone, f);
    },
  ));
}

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Desktop reads the environment; Android has none, so the same settings can
  // be compiled in with --dart-define / --dart-define-from-file
  // (RAFT_IDLE_FIXTURE_JSON carries the fixture itself).
  // String.fromEnvironment only works with a const name in AOT builds.
  const defines = <String, String>{
    'RAFT_IDLE_FIXTURE_JSON': String.fromEnvironment('RAFT_IDLE_FIXTURE_JSON'),
    'RAFT_IDLE_SECONDS': String.fromEnvironment('RAFT_IDLE_SECONDS'),
    'RAFT_IDLE_ONLY': String.fromEnvironment('RAFT_IDLE_ONLY'),
    'RAFT_IDLE_LABEL': String.fromEnvironment('RAFT_IDLE_LABEL'),
    'RAFT_IDLE_OUT': String.fromEnvironment('RAFT_IDLE_OUT'),
  };
  String setting(String name, String fallback) {
    final v = Platform.environment[name] ?? defines[name] ?? '';
    return v.isEmpty ? fallback : v;
  }
  final fixtureText = setting('RAFT_IDLE_FIXTURE_JSON', '');
  final fixture = jsonDecode(
    fixtureText.isNotEmpty
        ? fixtureText
        : File(setting('RAFT_IDLE_FIXTURE', '')).readAsStringSync(),
  ) as Map<String, dynamic>;
  final seconds = int.parse(setting('RAFT_IDLE_SECONDS', '30'));
  final only = setting('RAFT_IDLE_ONLY', '').split(',').where((s) => s.isNotEmpty);
  final label = setting('RAFT_IDLE_LABEL', 'run');
  final out = setting('RAFT_IDLE_OUT', '');
  final hz = int.parse(
    ((await Process.run('getconf', ['CLK_TCK'])).stdout as String).trim(),
  );
  final binding = WidgetsBinding.instance;
  var drawn = 0, idleAdmissions = 0;
  binding.addPersistentFrameCallback((_) => drawn++);
  final defaultStrategy = binding.schedulingStrategy;
  binding.schedulingStrategy = ({required priority, required scheduler}) {
    if (priority == Priority.idle.value) idleAdmissions++;
    return defaultStrategy(priority: priority, scheduler: scheduler);
  };

  final scenarios = [
    'home', 'channel', 'channel-agent-activity', 'channel-spinner', 'activity',
    'search', 'settings', 'dialog', 'thread', 'tasks', 'members', 'computers',
    'channel-unfocused', 'channel-hidden', 'channel-paused',
  ].where((s) => only.isEmpty || only.contains(s)).toList();

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final results = <Map<String, dynamic>>[];
  final host = GlobalKey<_HostState>();
  runApp(_Host(key: host));
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  await wait(1500);

  Element? find(Key key) {
    Element? hit;
    void visit(Element e) {
      if (hit != null) return;
      if (e.widget.key == key) {
        hit = e;
        return;
      }
      e.visitChildren(visit);
    }
    binding.rootElement?.visitChildren(visit);
    return hit;
  }

  Future<bool> until(bool Function() check, [int ms = 10000]) async {
    for (var t = 0; t < ms && !check(); t += 50) {
      await wait(50);
    }
    return check();
  }

  var pointer = 100;
  Future<void> tap(Key key) async {
    if (!await until(() => find(key) != null)) {
      throw StateError('timeout waiting for $key');
    }
    final box = find(key)!.renderObject! as RenderBox;
    final p = box.localToGlobal(box.size.center(Offset.zero));
    final g = GestureBinding.instance;
    final id = ++pointer;
    g.handlePointerEvent(PointerAddedEvent(position: p, kind: PointerDeviceKind.mouse, device: 1));
    g.handlePointerEvent(PointerDownEvent(position: p, kind: PointerDeviceKind.mouse, device: 1, pointer: id, buttons: kPrimaryButton));
    g.handlePointerEvent(PointerUpEvent(position: p, kind: PointerDeviceKind.mouse, device: 1, pointer: id));
    await wait(600);
  }

  Future<void> lifecycle(AppLifecycleState s) async {
    binding.handleAppLifecycleStateChanged(s);
    await wait(300);
  }

  for (final scenario in scenarios) {
    host.currentState!.reset(scenario, fixture);
    await wait(500);
    final ready = await until(
      () => find(const ValueKey('message-msg-agent-reply')) != null,
      20000,
    );
    var note = ready ? '' : 'channel messages never appeared';
    await wait(1500);
    if (!scenario.startsWith('channel-') || scenario == 'channel-agent-activity' || scenario == 'channel-spinner') {
      await lifecycle(AppLifecycleState.resumed);
    }
    final w = host.currentState!.controller!;
    switch (scenario) {
      case 'home':
        await tap(const ValueKey('rail-tasks'));
        await tap(const ValueKey('rail-chat'));
      case 'channel-agent-activity':
        host.currentState!.client!.stream.add(RaftEvent('agent:activity', {
          'agentId': 'agent-cindy',
          'serverId': w.server?.id,
          'activity': 'working',
          'detail': 'Running tests',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
        await wait(800);
        note = 'summary: ${find(const ValueKey('working-agents-summary')) != null}';
      case 'activity':
        await tap(const ValueKey('rail-activity'));
      case 'search':
        await tap(const ValueKey('rail-search'));
      case 'settings':
        await tap(const Key('rail-settings'));
        await tap(const ValueKey('workspace-settings-nav-appearance'));
      case 'dialog':
        await tap(const ValueKey('rail-members'));
        await tap(const ValueKey('desktop-directory-invite-human'));
        note = 'dialog: ${find(const Key('invite-dialog')) != null}';
      case 'thread':
        await tap(const ValueKey('inline-thread-msg-agent-reply'));
        await until(() => w.messageDomain.state.threadParent != null && !w.messageDomain.state.threadLoading);
      case 'tasks':
        await tap(const ValueKey('rail-tasks'));
      case 'members':
        await tap(const ValueKey('rail-members'));
      case 'computers':
        await tap(const ValueKey('rail-computers'));
      case 'channel-unfocused':
        await lifecycle(AppLifecycleState.inactive);
      case 'channel-hidden':
        await lifecycle(AppLifecycleState.inactive);
        await lifecycle(AppLifecycleState.hidden);
      case 'channel-paused':
        await lifecycle(AppLifecycleState.inactive);
        await lifecycle(AppLifecycleState.hidden);
        await lifecycle(AppLifecycleState.paused);
      default:
        break;
    }
    // Let post-navigation work (image decode, preparation, debounce) finish.
    await wait(6000);
    final startDrawn = drawn, startIdle = idleAdmissions;
    final t0 = timers, z0 = zeroTimers, m0 = microtasks;
    final c0 = _cpuTicks();
    timerSites.clear();
    _recording = true;
    final watch = Stopwatch()..start();
    var scheduledSamples = 0, samples = 0, maxTransient = 0;
    while (watch.elapsed < Duration(seconds: seconds)) {
      await wait(100);
      samples++;
      if (binding.hasScheduledFrame) scheduledSamples++;
      if (binding.transientCallbackCount > maxTransient) {
        maxTransient = binding.transientCallbackCount;
      }
      if (samples % 100 == 0) {
        // Progress line (also proves frames/CPU while the app is backgrounded).
        // ignore: avoid_print
        print('IDLEPROGRESS $scenario t=${watch.elapsed.inSeconds}s '
            'frames=${drawn - startDrawn} '
            'cpuTicks=${_cpuTicks() - c0} lifecycle=${binding.lifecycleState}');
      }
    }
    final secs = watch.elapsedMicroseconds / 1e6;
    final c1 = _cpuTicks();
    _recording = false;
    final topSites = (timerSites.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .where((e) => !e.key.trim().endsWith('ms') && e.value >= secs * 0.5)
        .take(4)
        .map((e) => '${(e.value / secs).toStringAsFixed(1)}/s ${e.key}')
        .toList();
    String f(double v, [int d = 2]) => v.toStringAsFixed(d);
    final result = <String, dynamic>{
      'scenario': scenario,
      'label': label,
      'seconds': double.parse(f(secs, 1)),
      'cpuPercent': double.parse(f((c1 - c0) / hz / secs * 100)),
      'framesDrawn': drawn - startDrawn,
      'fps': double.parse(f((drawn - startDrawn) / secs)),
      'idleAdmissionsPerSec': double.parse(f((idleAdmissions - startIdle) / secs, 1)),
      // The 100 ms sampler itself creates 10 timers per second and 10 more
      // microtasks; subtract nothing, compare scenarios against each other.
      'timersPerSec': double.parse(f((timers - t0) / secs, 1)),
      'zeroTimersPerSec': double.parse(f((zeroTimers - z0) / secs, 1)),
      'microtasksPerSec': double.parse(f((microtasks - m0) / secs, 1)),
      'transientMax': maxTransient,
      'scheduledSamplePct': double.parse(f(scheduledSamples * 100 / samples, 1)),
      'lifecycle': '${binding.lifecycleState}'.replaceFirst('AppLifecycleState.', ''),
      'note': note,
      // ignore: invalid_use_of_visible_for_testing_member
      'warmUpPending': RaftFontWarmUp.pending,
      'timerSites': topSites,
    };
    results.add(result);
    // ignore: avoid_print
    print('IDLELAB ${jsonEncode(result)}');
    if (scenario.startsWith('channel-')) {
      await lifecycle(AppLifecycleState.resumed);
    }
    host.currentState!.clear();
    await wait(400);
  }
  if (out.isNotEmpty) {
    File(out).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  }
  // ignore: avoid_print
  print('IDLELAB DONE');
  exit(0);
}

class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? scenario;
  DesktopFixtureClient? client;
  WorkspaceController? controller;
  final presentation = PersonalPresentationStore(desktop: false);
  final notifications = NativeNotificationService();
  int generation = 0;

  void reset(String next, Map<String, dynamic> fixture) {
    final c = DesktopFixtureClient(jsonDecode(jsonEncode(fixture)) as Map<String, dynamic>);
    setState(() {
      scenario = next;
      client = c;
      controller = WorkspaceController(c);
      generation++;
    });
    unawaited(controller!.bootstrap());
  }

  void clear() => setState(() {
    scenario = null;
    controller = null;
    client = null;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: raftTheme(),
    builder: (context, child) => RaftTooltipProvider(
      delay: const Duration(milliseconds: 600),
      child: RaftViewportBreakpointScope(
        child: RaftFontWarmUpScope(
          child: scenario == 'channel-spinner'
              ? Stack(children: [
                  child!,
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: IgnorePointer(child: RaftSpinner(size: 16)),
                  ),
                ])
              : child!,
        ),
      ),
    ),
    home: controller == null
        ? const SizedBox()
        : WorkspaceView(
            key: ValueKey(generation),
            controller: controller!,
            presentation: presentation,
            appearance: const RaftAppearance(mode: ThemeMode.light),
            onAppearance: (_) async {},
            onLogout: () async {},
            notifications: notifications,
          ),
  );
}
