// Soft-keyboard scene for the perf lab.
//
// The chat page is the production phone shell. The scene taps the composer,
// then applies the per-frame metrics the engine delivers while the soft
// keyboard moves: a new `displayFeatures` list, a changing `viewInsets`, and
// the Android padding that shrinks as the inset grows. It holds, slides the
// inset back, and repeats. Each slide is one episode (`t0`/`t1` on the
// timeline clock) so the summary can score those frames apart from the hold.
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';
import 'navigation_host.dart';
import 'probe.dart';

const keyboardCycles = 4;
const _prose =
    '代码和相关回归检查已通过，右侧操作复用原播放器，不会另开一份播放状态。独立 Duo 原生包正在编译；设备窗口目前出现空白和绑定超时，我会保留这次失败记录。';

/// Mounts the production app on a long channel and opens that channel.
/// The returned function tears the page down.
Future<Future<void> Function()> mountKeyboardChat(
  WidgetTester t, {
  required LabImages images,
  required bool dark,
  bool useTestViewport = false,
}) async {
  final channel = LabChannel('kb', mixKinds(40));
  for (var i = 0; i < channel.rows.length; i++) {
    if (channel.kinds[i] == 'plain') {
      channel.rows[i]['content'] = List.filled(4, _prose).join('\n\n');
    }
  }
  final (seed, api, client) = await labWorkspace(
    [channel],
    images,
    mobile: true,
    ownsClient: false,
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'zh',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/kb'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
  api.routes['GET /servers/unread-summary'] = (_) => <dynamic>[];
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': dark ? 'dark' : 'light',
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-lab-keyboard-');
  final content = LabNavigationContent();
  await NativeSystemFonts.instance.initialize();
  final rootApp = app.RaftApp(
      key: const ValueKey('lab-keyboard'),
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab'),
      nativeContent: content,
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async => LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    );
  await t.pumpWidget(useTestViewport
      ? MediaQuery.fromView(view: t.view, child: rootApp) : rootApp);
  await idle(const Duration(seconds: 2));
  if (useTestViewport) {
    await waitUntil(() => find.text('lab-kb', findRichText: true).evaluate().isNotEmpty ||
        find.text('/lab', findRichText: true).hitTestable().evaluate().isNotEmpty,
        limit: const Duration(seconds: 15));
    if (find.text('lab-kb', findRichText: true).evaluate().isEmpty &&
        find.text('/lab', findRichText: true).hitTestable().evaluate().isNotEmpty) {
      await t.tap(find.text('/lab', findRichText: true));
    }
  }
  if (await waitUntil(() => find.text('lab-kb', findRichText: true).evaluate().isNotEmpty,
      limit: const Duration(seconds: 15)) < 0) {
    final root = t.element(find.byType(app.RaftApp));
    final actualView = View.of(root);
    final text = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).take(30).join(' | ');
    final media = MediaQuery.sizeOf(t.element(find.byType(Scaffold).first));
    throw StateError('keyboard channel not listed; appView=${actualView.physicalSize.width}x${actualView.physicalSize.height}; '
        'testView=${t.view.physicalSize.width}x${t.view.physicalSize.height}; media=${media.width}x${media.height}; '
        'text=$text; requests=${api.hits}; misses=${api.misses}');
  }
  await t.tap(find.text('lab-kb', findRichText: true));
  final opened = await waitUntil(
    () => find.byType(RaftComposer).evaluate().isNotEmpty,
    limit: const Duration(seconds: 15),
  );
  if (opened < 0) throw StateError('keyboard scene: lab-kb never showed its composer');
  await idle(const Duration(milliseconds: 600));
  return () async {
    await t.pumpWidget(const SizedBox());
    await idle(const Duration(milliseconds: 200));
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // The workspace cache can still be closing. The directory is temporary.
    }
  };
}

/// Tap the composer, slide the keyboard in, hold, slide it out. Repeats
/// [keyboardCycles] times. The returned `keyboard` list is the measured
/// animation windows. Each window carries the UI thread's on-CPU time.
/// Profile switches record one timeline event per build, layout and paint
/// so the summary can count them; they are restored before returning.
Future<Map<String, Object?>> keyboardOpenClose(WidgetTester t, {bool profilePhases = true}) async {
  final builds = debugProfileBuildsEnabled;
  final layouts = debugProfileLayoutsEnabled;
  final paints = debugProfilePaintsEnabled;
  debugProfileBuildsEnabled = profilePhases;
  debugProfileLayoutsEnabled = profilePhases;
  debugProfilePaintsEnabled = profilePhases;
  try {
    return {...await _keyboardOpenClose(t), 'phaseProfiling': profilePhases};
  } finally {
    debugProfileBuildsEnabled = builds;
    debugProfileLayoutsEnabled = layouts;
    debugProfilePaintsEnabled = paints;
  }
}

Future<Map<String, Object?>> _keyboardOpenClose(WidgetTester t) async {
  final chat = find.byWidgetPredicate((w) => w is RaftChatView && !w.thread);
  final field = find.descendant(
    of: find.descendant(of: chat, matching: find.byType(RaftComposer)),
    matching: find.byType(EditableText),
  );
  if (field.evaluate().isEmpty) throw StateError('keyboard scene: composer is not on screen');
  await t.tap(field);
  await idle(const Duration(milliseconds: 300));

  final view = t.view;
  final top = view.viewPadding.top;
  final gesture = view.viewPadding.bottom;
  final target = view.physicalSize.height * 0.38;
  final episodes = <Map<String, Object?>>[];
  for (var i = 0; i < keyboardCycles; i++) {
    episodes.add(await _slide(view, 'open', _steps(0, target), top, gesture));
    await idle(const Duration(milliseconds: 400));
    episodes.add(await _slide(view, 'close', _steps(target, 0), top, gesture));
    await idle(const Duration(milliseconds: 300));
  }
  view.displayFeatures = <ui.DisplayFeature>[];
  view.viewInsets = FakeViewPadding(bottom: 0);
  view.padding = FakeViewPadding(top: top, bottom: gesture);
  return {'keyboard': episodes, 'keyboardCycles': keyboardCycles};
}

List<double> _steps(double from, double to) =>
    [for (var i = 1; i <= 8; i++) from + (to - from) * i / 8];

Future<Map<String, Object?>> _slide(
  TestFlutterView view,
  String direction,
  List<double> insets,
  double top,
  double gesture,
) async {
  final t0 = developer.Timeline.now;
  final cpu0 = threadCpuSeconds();
  for (final inset in insets) {
    // A new list on every metrics update, matching the engine.
    view.displayFeatures = <ui.DisplayFeature>[];
    view.viewInsets = FakeViewPadding(bottom: inset);
    final padding = (gesture - inset).clamp(0, gesture).toDouble();
    view.padding = FakeViewPadding(top: top, bottom: padding);
    await idle(const Duration(milliseconds: 16));
  }
  final cpu1 = threadCpuSeconds();
  return {
    'direction': direction,
    't0': t0,
    't1': developer.Timeline.now,
    if (cpu0 != null && cpu1 != null) 'cpuUs': ((cpu1 - cpu0) * 1e6).round(),
  };
}
