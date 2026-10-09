import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/platform/session_store.dart';
import 'package:raft_flutter/platform/system_bars.dart';

import 'attachment_flow.dart';
import 'management_flow.dart';
import 'notification_flow.dart';
import 'content_flow.dart';
import 'rich_content_flow.dart';
import 'runtime_review_flow.dart';
import 'sidebar_flow.dart';
import 'forward_flow.dart';
import 'message_selection_flow.dart';
import 'native_message_menu.dart';
import 'resource_flow.dart';
import 'joint_channel_flow.dart';
import 'composer_suggestions_flow.dart';
import 'action_card_flow.dart';
import 'channel_conversion_flow.dart';
import 'html_preview_flow.dart';
import 'media_preview_flow.dart';

import 'package:path/path.dart' as p;

Future<void> until(
  WidgetTester tester,
  bool Function() predicate, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds * 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (predicate()) return;
  }
  throw TestFailure('Timed out waiting for the asserted native UI state.');
}

Future<void> settingsTab(WidgetTester tester, String tab) async {
  final destination = find.byKey(ValueKey('workspace-settings-nav-$tab'));
  if (destination.evaluate().isEmpty) {
    final mobileBack = find.byKey(const Key('mobile-settings-back'));
    await tester.tap(
      mobileBack.evaluate().isNotEmpty
          ? mobileBack
          : find.byTooltip('Settings navigation'),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(destination);
  await tester.pumpAndSettle();
  await tester.tap(destination);
  await tester.pumpAndSettle();
  await until(
    tester,
    () => find.byKey(ValueKey('settings-page-$tab')).evaluate().isNotEmpty,
  );
}

const nativeReportFolder = String.fromEnvironment(
  'RAFT_TEST_REPORT',
  defaultValue: '/tmp/raft-native-e2e',
);
const nativePlatform = String.fromEnvironment(
  'RAFT_TEST_PLATFORM',
  defaultValue: 'linux',
);
late String nativeRunId;
Future<void> startNativeReport() async {
  nativeRunId = DateTime.now().toUtc().toIso8601String();
  debugPrint('Native evidence run: $nativePlatform $nativeRunId');
  final dir = Directory(nativeReportFolder);
  await dir.create(recursive: true);
  await for (final entry in dir.list()) {
    if (entry is File &&
        p.basename(entry.path).startsWith('$nativePlatform-') &&
        entry.path.endsWith('.png')) {
      await entry.delete();
    }
  }
  await File('$nativeReportFolder/native-$nativePlatform-checkpoints.tsv')
      .writeAsString('');
  await File('$nativeReportFolder/native-$nativePlatform-run.json')
      .writeAsString(
        jsonEncode({
          'runId': nativeRunId,
          'platform': nativePlatform,
          'completed': false,
          'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
        }),
      );
}

Future<void> screenshot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 300));
  final boundary =
      raftScreenshotKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = const String.fromEnvironment(
      'RAFT_TEST_REPORT',
      defaultValue: '/tmp/raft-native-e2e',
    );
    final dir = Directory(folder);
    await dir.create(recursive: true);
    final prefix = const String.fromEnvironment(
      'RAFT_TEST_PLATFORM',
      defaultValue: 'linux',
    );
    await File('$folder/${name.replaceFirst('linux', prefix)}.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    await File('$folder/native-$prefix-checkpoints.tsv').writeAsString(
      '${name.replaceFirst('linux', prefix)}\t${DateTime.now().toUtc().toIso8601String()}\t$nativeRunId\n',
      mode: FileMode.append,
    );
  } finally {
    image.dispose();
  }
}

bool mobileViewport(WidgetTester tester) =>
    tester.view.physicalSize.width / tester.view.devicePixelRatio < 768;

Future<void> mobileHome(WidgetTester tester) async {
  if (!mobileViewport(tester)) return;
  final home = find.byKey(const Key('workspace-mobile-home'));
  for (var step = 0; step < 6 && home.evaluate().isEmpty; step++) {
    final homeTab = find.byKey(const Key('mobile-tab-home'));
    final settingsBack = find.byKey(const Key('mobile-settings-back'));
    final detailBack = find.byKey(const Key('mobile-detail-back'));
    final back = homeTab.evaluate().isNotEmpty
        ? homeTab
        : settingsBack.evaluate().isNotEmpty
        ? settingsBack
        : detailBack.evaluate().isNotEmpty
        ? detailBack
        : find.byType(RaftBackButton).first;
    expect(
      back,
      findsOneWidget,
      reason: 'The real mobile route needs a back control.',
    );
    await tester.tap(back);
    await tester.pumpAndSettle();
  }
  expect(home, findsOneWidget);
  expect(find.byKey(const Key('workspace-mobile-navigation')), findsOneWidget);
  expect(find.byType(RaftComposer), findsNothing);
}

Future<void> captureMobileThemes(WidgetTester tester) async {
  final initial = tester
      .widget<WorkspaceView>(find.byType(WorkspaceView))
      .appearance;
  Future<void> choose(ThemeMode mode, RaftFamily family) async {
    await section(tester, 'settings');
    await settingsTab(tester, 'appearance');
    final modeControl = find.byKey(const Key('appearance-mode'));
    final label = raftText(tester.element(modeControl), switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    });
    final modeButton = find.descendant(
      of: modeControl,
      matching: find.text(label),
    );
    await tester.ensureVisible(modeButton);
    await tester.tap(modeButton);
    await tester.pumpAndSettle();
    if (mode != ThemeMode.dark) {
      final familyButton = find.byKey(
        ValueKey('appearance-light-theme-${family.name}'),
      );
      await tester.ensureVisible(familyButton);
      await tester.tap(familyButton);
      await tester.pumpAndSettle();
    }
    await mobileHome(tester);
  }

  try {
    for (final entry in [
      (ThemeMode.light, RaftFamily.brutal, 'brutal-light'),
      (ThemeMode.light, RaftFamily.elegant, 'elegant-light'),
      (ThemeMode.dark, RaftFamily.elegant, 'elegant-dark'),
    ]) {
      await choose(entry.$1, entry.$2);
      final t = RaftTokens.of(
        tester.element(find.byKey(const Key('workspace-mobile-home'))),
      );
      expect(t.family, entry.$2);
      expect(t.dark, entry.$1 == ThemeMode.dark);
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsOneWidget,
      );
      expect(find.byType(RaftComposer), findsNothing);
      final navGeometry = <Map<String, Object>>[];
      for (final tabId in ['home', 'tasks', 'members', 'settings']) {
        final tab = find.byKey(ValueKey('mobile-tab-$tabId'));
        if (tab.evaluate().isEmpty) {
          expect(tabId, 'members');
          continue;
        }
        final face = find.descendant(
          of: tab,
          matching: find.byType(AnimatedContainer),
        );
        final glyph = find.descendant(of: tab, matching: find.byType(RaftIcon));
        expect(face, findsOneWidget);
        expect(glyph, findsOneWidget);
        final faceRect = tester.getRect(face);
        final glyphRect = tester.getRect(glyph);
        expect(glyphRect.center.dx, closeTo(faceRect.center.dx, .1));
        if (!t.brutal) {
          expect(faceRect.size, const Size(44, 44));
          expect(glyphRect.center.dy, closeTo(faceRect.center.dy, .1));
        }
        Map<String, double> rect(Rect r) => {
          'x': r.left,
          'y': r.top,
          'width': r.width,
          'height': r.height,
        };
        navGeometry.add({
          'name': tabId,
          'visual': rect(faceRect),
          'glyph': rect(glyphRect),
          'hit': rect(tester.getRect(tab)),
        });
      }
      final logicalSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      await File(
        '$nativeReportFolder/$nativePlatform-mobile-home-${entry.$3}.geometry.json',
      ).writeAsString(
        jsonEncode({
          'runId': nativeRunId,
          'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
          'platform': nativePlatform,
          'theme': entry.$3,
          'logicalViewport': {
            'width': logicalSize.width,
            'height': logicalSize.height,
          },
          'deviceDpr': tester.view.devicePixelRatio,
          'screenshotRasterDpr': 1,
          'nav': navGeometry,
        }),
      );
      await screenshot(tester, 'linux-mobile-home-${entry.$3}');
      // The mounted Bell is a system NotificationCenter, distinct from Activity.
      final bell = find.byKey(const Key('mobile-home-notifications'));
      expect(bell, findsOneWidget);
      await tester.tap(bell);
      await until(
        tester,
        () => find.byType(RaftNotificationCenter).evaluate().isNotEmpty,
      );
      final notificationSurface = find.byKey(
        const Key('notification-center-surface'),
      );
      expect(tester.getSize(notificationSurface), const Size(320, 288));
      expect(find.byType(RaftComposer), findsNothing);
      final workspace = tester
          .widget<WorkspaceView>(find.byType(WorkspaceView))
          .controller;
      expect(workspace.section, 'home');
      await screenshot(tester, 'linux-mobile-notifications-${entry.$3}');
      // Source outside interaction dismisses without intercepting the actual tab.
      await tester.tap(find.byKey(const Key('mobile-tab-home')));
      await until(
        tester,
        () => find.byType(RaftNotificationCenter).evaluate().isEmpty,
      );
      expect(workspace.section, 'home');
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsOneWidget,
      );
    }
  } finally {
    await choose(initial.mode, initial.light);
  }
}

Future<void> captureDesktopNotificationThemes(WidgetTester tester) async {
  final workspace = tester.widget<WorkspaceView>(find.byType(WorkspaceView));
  final initial = workspace.appearance;
  final controller = workspace.controller;
  final channelId = controller.channel?.id;
  Future<void> choose(ThemeMode mode, RaftFamily family) async {
    await openAccountSettings(tester);
    await settingsTab(tester, 'appearance');
    final modeControl = find.byKey(const Key('appearance-mode'));
    final label = raftText(tester.element(modeControl), switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    });
    final modeButton = find.descendant(
      of: modeControl,
      matching: find.text(label),
    );
    await tester.ensureVisible(modeButton);
    await tester.tap(modeButton);
    await tester.pumpAndSettle();
    if (mode != ThemeMode.dark) {
      final familyButton = find.byKey(
        ValueKey('appearance-light-theme-${family.name}'),
      );
      await tester.ensureVisible(familyButton);
      await tester.tap(familyButton);
      await tester.pumpAndSettle();
    }
    await section(tester, 'chat');
  }

  final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  try {
    for (final entry in [
      (ThemeMode.light, RaftFamily.brutal, 'brutal-light'),
      (ThemeMode.light, RaftFamily.elegant, 'elegant-light'),
      (ThemeMode.dark, RaftFamily.elegant, 'elegant-dark'),
    ]) {
      await choose(entry.$1, entry.$2);
      final bell = find.byWidgetPredicate(
        (widget) => widget is SystemNotificationBell && !widget.mobile,
      );
      expect(bell, findsOneWidget);
      final tokens = RaftTokens.of(tester.element(bell));
      expect(tokens.family, entry.$2);
      expect(tokens.dark, entry.$1 == ThemeMode.dark);
      await mouse.moveTo(tester.getCenter(bell));
      await until(
        tester,
        () => find.byType(RaftNotificationCenter).evaluate().isNotEmpty,
      );
      final popupRect = tester.getRect(
        find.byKey(const Key('notification-center-surface')),
      );
      expect(popupRect.size, const Size(320, 288));
      final logicalSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      await File(
        '$nativeReportFolder/$nativePlatform-desktop-notifications-${entry.$3}.geometry.json',
      ).writeAsString(
        jsonEncode({
          'runId': nativeRunId,
          'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
          'platform': nativePlatform,
          'theme': entry.$3,
          'logicalViewport': {
            'width': logicalSize.width,
            'height': logicalSize.height,
          },
          'deviceDpr': tester.view.devicePixelRatio,
          'screenshotRasterDpr': 1,
          'popup': {
            'x': popupRect.left,
            'y': popupRect.top,
            'width': popupRect.width,
            'height': popupRect.height,
          },
          'interaction':
              'mouse hover opens; Escape without manual focus closes',
        }),
      );
      expect(controller.section, 'chat');
      expect(controller.channel?.id, channelId);
      await screenshot(tester, 'linux-desktop-notifications-${entry.$3}');
      // Real hover opening must support Escape without a manual focus transfer.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await until(
        tester,
        () => find.byType(RaftNotificationCenter).evaluate().isEmpty,
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 150));
    }
  } finally {
    await mouse.removePointer();
    await choose(initial.mode, initial.light);
  }
}

Future<void> revealSidebar(WidgetTester tester, Finder target) async {
  final sidebarScroll = find
      .descendant(
        of: find.byKey(const Key('workspace-sidebar')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(sidebarScroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 160, scrollable: sidebarScroll);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<WorkspaceController> openNativeChat(
  WidgetTester tester, {
  bool general = false,
  bool verifyRoots = false,
}) async {
  await until(tester, () => find.byType(WorkspaceView).evaluate().isNotEmpty);
  final w = tester
      .widget<WorkspaceView>(find.byType(WorkspaceView).first)
      .controller;
  await until(tester, () => !w.loading && w.channels.isNotEmpty);
  if (mobileViewport(tester)) {
    await mobileHome(tester);
    if (verifyRoots) {
      final membersAllowed =
          w.server?.string('role') != 'guest' && w.can('viewMembers');
      expect(find.byKey(const Key('mobile-tab-home')), findsOneWidget);
      expect(find.byKey(const Key('mobile-tab-tasks')), findsOneWidget);
      expect(find.byKey(const Key('mobile-tab-settings')), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-tab-members')),
        membersAllowed ? findsOneWidget : findsNothing,
      );
      await screenshot(tester, 'linux-mobile-home');
      await captureMobileThemes(tester);
      for (final root in ['tasks', if (membersAllowed) 'members', 'settings']) {
        await section(tester, root);
        expect(w.section, root);
        expect(find.byType(RaftComposer), findsNothing);
        await screenshot(tester, 'linux-mobile-root-$root');
      }
      await mobileHome(tester);
      expect(w.section, 'home');
    }
    final channel = general
        ? w.channels.firstWhere((c) => c.name == 'general')
        : w.channel ?? w.channels.firstWhere((c) => c.name == 'general');
    final target = find.byKey(ValueKey('sidebar-channel-${channel.id}'));
    await revealSidebar(tester, target);
    await tester.tap(target);
    await until(
      tester,
      () =>
          find.byType(RaftChatView).evaluate().isNotEmpty &&
          w.channel?.id == channel.id &&
          !w.channelLoading,
    );
    expect(find.byKey(const Key('workspace-mobile-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-detail-back')), findsOneWidget);
    if (verifyRoots) {
      await screenshot(tester, 'linux-mobile-channel-detail');
      await mobileHome(tester);
      expect(w.section, 'home');
      expect(w.channel?.id, channel.id);
      await revealSidebar(tester, target);
      await tester.tap(target);
      await until(
        tester,
        () =>
            w.section == 'chat' &&
            !w.channelLoading &&
            find.byType(RaftChatView).evaluate().isNotEmpty,
      );
    }
  } else {
    await until(tester, () => find.byType(RaftChatView).evaluate().isNotEmpty);
    if (verifyRoots) {
      await captureDesktopNotificationThemes(tester);
    }
  }
  return w;
}

Future<void> section(WidgetTester tester, String name) async {
  if (mobileViewport(tester)) {
    await mobileHome(tester);
    if (name == 'home') return;
    if (name == 'chat') {
      await openNativeChat(tester);
      return;
    }
    if (const ['tasks', 'members', 'settings'].contains(name)) {
      final tab = find.byKey(Key('mobile-tab-$name'));
      expect(tab, findsOneWidget);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsOneWidget,
      );
      return;
    }
  } else if (const [
    'chat',
    'home',
    'tasks',
    'members',
    'computers',
    'settings',
  ].contains(name)) {
    final target = find.byKey(
      ValueKey('rail-${name == 'home' ? 'chat' : name}'),
    );
    expect(target, findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
    return;
  }
  final target = find.byKey(Key('nav-$name'));
  await revealSidebar(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openAccountSettings(WidgetTester tester) async {
  if (mobileViewport(tester)) {
    await section(tester, 'settings');
  } else {
    await tester.tap(find.byKey(const Key('account-navigation')));
    await tester.pumpAndSettle();
  }
  await settingsTab(tester, 'account');
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
  matching: find.byType(TextField),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('native login, history, send, thread, appearance and secure session', (
    tester,
  ) async {
    await startNativeReport();
    final fixtureFile = File(const String.fromEnvironment('RAFT_TEST_CONFIG'));
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!await fixtureFile.exists()) {
        if (DateTime.now().isAfter(deadline)) {
          throw TestFailure('Private test fixture was not installed.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });
    final fixture = jsonDecode(fixtureFile.readAsStringSync());
    final storage = SecureSessionStore();
    await storage.write(
      'test-native-session',
      Session(accessToken: 'test-only', refreshToken: 'test-only'),
    );
    expect(
      (await storage.read('test-native-session'))?.accessToken,
      'test-only',
    );
    await storage.write('test-native-session', null);
    await storage.write(fixture['origin'], null);
    await tester.pumpWidget(RaftApp(sessionStore: storage));
    await until(
      tester,
      () => find.byKey(const Key('login-email')).evaluate().isNotEmpty,
    );
    if (Platform.isAndroid) {
      final view = tester.view;
      final logical = view.physicalSize / view.devicePixelRatio;
      expect(
        tester.getRect(find.byKey(raftScreenshotKey)),
        Rect.fromLTWH(0, 0, logical.width, logical.height),
        reason: 'The actual Android canvas must extend underneath system bars.',
      );
      expect(view.viewPadding.top, greaterThan(0));
      final field = tester.getRect(find.byKey(const Key('login-email')));
      expect(
        field.top,
        greaterThanOrEqualTo(view.viewPadding.top / view.devicePixelRatio),
      );
      expect(
        field.bottom,
        lessThanOrEqualTo(
          logical.height - view.viewPadding.bottom / view.devicePixelRatio,
        ),
      );
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(RaftSystemBars),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.statusBarColor, Colors.transparent);
      expect(overlay.value.systemNavigationBarColor, Colors.transparent);
      await screenshot(tester, 'linux-edge-to-edge-login');
    }
    await tester.tap(find.byKey(const Key('login-server')));
    await tester.pumpAndSettle();
    await tester.enterText(field('Server URL'), fixture['origin']);
    await tester.tap(find.widgetWithText(RaftButton, 'Save'));
    await until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      fixture['email'],
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      fixture['password'],
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    var w = await openNativeChat(tester, general: true, verifyRoots: true);
    if (!mobileViewport(tester)) {
      await w.selectChannel(w.channels.firstWhere((c) => c.name == 'general'));
    }
    await until(
      tester,
      () => w.messages.isNotEmpty && !w.channelLoading && !w.loading,
    );
    expect(w.client.user, isNotNull);
    final initialComposer = find.descendant(
      of: find.byType(RaftComposer).first,
      matching: find.byType(TextField),
    );
    await tester.enterText(initialComposer, 'Restored draft 中文 日本語');
    await tester.pump(const Duration(milliseconds: 200));
    await w.flushCache();
    final principal = w.client.user!.id;
    expect(await storage.read(fixture['origin']), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      RaftApp(key: const Key('restored-app'), sessionStore: storage),
    );
    w = await openNativeChat(tester);
    await until(
      tester,
      () => w.messages.isNotEmpty && !w.channelLoading && !w.loading,
    );
    expect(w.client.user!.id, principal);
    final restoredComposer = find.descendant(
      of: find.byType(RaftComposer).first,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(restoredComposer).controller!.text,
      'Restored draft 中文 日本語',
    );
    await tester.enterText(restoredComposer, '');
    await w.flushCache();
    final owned = <String, Map<String, dynamic>>{};
    w.client.http.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final path = response.requestOptions.path,
              method = response.requestOptions.method,
              body = response.data;
          if (method == 'POST' &&
              (path == '/channels' ||
                  path == '/servers' ||
                  path == '/agents') &&
              body is Map &&
              body['id'] is String) {
            owned[body['id']] = {
              'kind': path == '/servers'
                  ? 'server'
                  : path == '/agents'
                  ? 'agent'
                  : 'channel',
              'server': response.requestOptions.headers['X-Server-Id'],
            };
          }
          if (method == 'POST' &&
              path.startsWith('/tasks/channel/') &&
              body is Map &&
              body['tasks'] is List) {
            for (final task in body['tasks'] as List) {
              if (task is Map && task['id'] is String) {
                owned[task['id']] = {
                  'kind': 'task',
                  'server': response.requestOptions.headers['X-Server-Id'],
                };
              }
            }
          }
          if (method == 'DELETE') {
            final removed = path.split('/').last, entry = owned.remove(removed);
            if (entry?['kind'] == 'server') {
              owned.removeWhere((_, entry) => entry['server'] == removed);
            }
          }
          handler.next(response);
        },
      ),
    );
    addTearDown(() async {
      if (owned.isEmpty) return;
      final cleanup = RaftClient(
        origin: fixture['origin'],
        sessionStore: MemorySessionStore(),
      );
      try {
        await cleanup.login(fixture['email'], fixture['password']);
        final resources = owned.entries.toList()
          ..sort(
            (a, b) => a.value['kind'] == 'server'
                ? 1
                : b.value['kind'] == 'server'
                ? -1
                : 0,
          );
        for (final resource in resources) {
          cleanup.selectServer(
            resource.value['kind'] == 'server'
                ? resource.key
                : resource.value['server'],
          );
          try {
            if (resource.value['kind'] == 'server') {
              await cleanup.exitServer(resource.key, delete: true);
            } else if (resource.value['kind'] == 'task') {
              await cleanup.delete('/tasks/${resource.key}');
            } else if (resource.value['kind'] == 'agent') {
              await cleanup.delete('/agents/${resource.key}');
            } else {
              await cleanup.delete('/channels/${resource.key}');
            }
          } on RaftApiException catch (e) {
            if (e.status != 404) rethrow;
          }
        }
      } finally {
        await cleanup.logout();
        await cleanup.dispose();
      }
    });
    var droppedRefresh = false;
    final refreshBindings = <Map<String, dynamic>>[];
    final refreshFault = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/auth/refresh') {
          refreshBindings.add(Map.from(options.headers));
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (!droppedRefresh &&
            response.requestOptions.path == '/auth/refresh') {
          droppedRefresh = true;
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.receiveTimeout,
            ),
          );
        } else {
          handler.next(response);
        }
      },
    );
    w.client.http.interceptors.add(refreshFault);
    await expectLater(w.client.refresh(), throwsA(isA<RaftApiException>()));
    expect(w.client.signedIn, true);
    expect(
      (await storage.read(fixture['origin']))?.refreshAttemptId,
      isNotNull,
    );
    await w.client.refresh();
    expect(refreshBindings, hasLength(2));
    expect(
      refreshBindings.first['X-Slock-Auth-Refresh-Attempt-Id'],
      refreshBindings.last['X-Slock-Auth-Refresh-Attempt-Id'],
    );
    expect((await storage.read(fixture['origin']))?.refreshAttemptId, isNull);
    expect((await w.client.get('/auth/me'))['id'], principal);
    w.client.http.interceptors.remove(refreshFault);

    expect(w.channels, isNotEmpty);
    final general = w.channels.where((c) => c.name == 'general').first;
    await mobileHome(tester);
    final generalNavigation = find.byKey(
      ValueKey('sidebar-channel-${general.id}'),
    );
    await revealSidebar(tester, generalNavigation);
    await tester.tap(generalNavigation);
    await until(tester, () => w.channel?.id == general.id && !w.channelLoading);
    expect(w.messages.length, greaterThanOrEqualTo(50));
    await screenshot(tester, 'linux-chat-history');
    final composer = find.descendant(
      of: find.byType(RaftComposer).first,
      matching: find.byType(TextField),
    );
    final retryText =
        'Lost response retry ${DateTime.now().millisecondsSinceEpoch}';
    var lost = false;
    final attempts = <String>[];
    final fault = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/v2/messages' &&
            options.data['content'] == retryText) {
          attempts.add(options.data['randomId']);
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (!lost &&
            response.requestOptions.path == '/v2/messages' &&
            response.requestOptions.data['content'] == retryText) {
          lost = true;
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.receiveTimeout,
            ),
          );
        } else {
          handler.next(response);
        }
      },
    );
    w.client.http.interceptors.add(fault);
    await tester.tap(composer);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(composer, retryText);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is RaftComposerAction && widget.submit,
          )
          .first,
    );
    await until(tester, () => lost && w.error != null);
    expect(tester.widget<TextField>(composer).controller!.text, retryText);
    final beforeRetry = await w.client.messagePage(general.id);
    expect(
      (beforeRetry['messages'] as List).where((m) => m['content'] == retryText),
      hasLength(1),
    );
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is RaftComposerAction && widget.submit,
          )
          .first,
    );
    await until(
      tester,
      () => tester.widget<TextField>(composer).controller!.text.isEmpty,
    );
    final afterRetry = await w.client.messagePage(general.id);
    expect(
      (afterRetry['messages'] as List).where((m) => m['content'] == retryText),
      hasLength(1),
    );
    expect(attempts, hasLength(2));
    expect(attempts.first, attempts.last);
    w.client.http.interceptors.remove(fault);
    await tester.pump(const Duration(milliseconds: 300));
    await until(
      tester,
      () => tester.widget<TextField>(composer).enabled == true,
    );
    final text =
        'Native Flutter E2E ${DateTime.now().millisecondsSinceEpoch} · 中文 日本語';
    await tester.tap(composer);
    await tester.pump(const Duration(milliseconds: 500));
    final composeState = tester.state(find.byType(RaftComposer).first);
    await tester.enterText(composer, text);
    expect(tester.widget<TextField>(composer).controller!.text, text);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.state(find.byType(RaftComposer).first), same(composeState));
    expect(tester.widget<TextField>(composer).controller!.text, text);
    await screenshot(tester, 'linux-composer-before-send');
    final sendAction = find
        .byWidgetPredicate(
          (widget) => widget is RaftComposerAction && widget.submit,
        )
        .first;
    final hit = HitTestResult();
    tester.binding.hitTestInView(
      hit,
      tester.getCenter(sendAction),
      tester.view.viewId,
    );
    await File(
      '$nativeReportFolder/$nativePlatform-composer-hit-test.txt',
    ).writeAsString(
      hit.path
          .map(
            (entry) =>
                '${entry.target}: ${entry.target is RenderObject ? (entry.target as RenderObject).debugCreator : ''}',
          )
          .join('\n'),
    );
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is RaftComposerAction && widget.submit,
          )
          .first,
    );
    await until(
      tester,
      () => w.messages.any((m) => m.content == text) || w.error != null,
    );
    expect(w.error, isNull);
    expect(w.messages.where((m) => m.content == text), hasLength(1));
    final sent = w.messages.firstWhere((m) => m.content == text);
    final messageRow = find.byKey(ValueKey('message-${sent.id}'));
    final replyButton = find.byKey(const ValueKey('message-menu-thread'));
    await openNativeMessageMenu(tester, messageRow, entry: replyButton);
    await tester.tap(replyButton);
    await until(
      tester,
      () => w.threadParent?.id == sent.id && !w.threadLoading,
    );
    expect(w.threadParent?.id, sent.id);
    final replyText =
        'Thread from Flutter 中文 日本語 ${DateTime.now().millisecondsSinceEpoch}';
    final threadComposer = find.byType(RaftComposer).last;
    await tester.enterText(
      find.descendant(of: threadComposer, matching: find.byType(TextField)),
      replyText,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(
      find.descendant(
        of: threadComposer,
        matching: find.byWidgetPredicate(
          (widget) => widget is RaftComposerAction && widget.submit,
        ),
      ),
    );
    await until(tester, () => w.replies.any((m) => m.content == replyText));
    expect(w.replies.where((m) => m.content == replyText), hasLength(1));
    final verifiedThreadId = w.threadChannelId!;
    final page = await w.client.messagePage(verifiedThreadId);
    expect(
      (page['messages'] as List).where((m) => m['content'] == replyText),
      hasLength(1),
    );
    final followEntry = find.byKey(const Key('thread-follow-menu-item'));
    Future<void> openFollowEntry({String? expected}) async {
      await tester.tap(find.byKey(const Key('thread-options')));
      await until(tester, () {
        if (followEntry.evaluate().isEmpty) return false;
        final item = tester.widget<RaftMenuItem>(followEntry);
        return item.onPressed != null &&
            (expected == null || item.label == expected);
      });
    }

    Future<void> toggleFollow() async {
      await tester.tap(followEntry);
      await until(tester, () => followEntry.evaluate().isEmpty);
    }

    await openFollowEntry();
    final initiallyFollowing =
        tester.widget<RaftMenuItem>(followEntry).label == 'Unfollow thread';
    await toggleFollow();
    await openFollowEntry(
      expected: initiallyFollowing ? 'Follow thread' : 'Unfollow thread',
    );
    await toggleFollow();
    await openFollowEntry(
      expected: initiallyFollowing ? 'Unfollow thread' : 'Follow thread',
    );
    // Keep this test-created parent followed for actual projection readback.
    if (!initiallyFollowing) {
      await toggleFollow();
      await openFollowEntry(expected: 'Unfollow thread');
    }
    await tester.tap(find.byKey(const Key('thread-options')));
    await until(tester, () => followEntry.evaluate().isEmpty);
    bool projectedFollow = false;
    for (var attempt = 0; attempt < 50 && !projectedFollow; attempt++) {
      final followedRows = await w.query('/channels/threads/followed');
      projectedFollow = (followedRows['threads'] as List).any(
        (r) => r['parentMessageId'] == sent.id,
      );
      if (!projectedFollow) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
    expect(
      projectedFollow,
      true,
      reason: 'Acknowledged follow must reach the actual Activity projection.',
    );
    await screenshot(tester, 'linux-thread');
    final nativeReply = w.replies.singleWhere((m) => m.content == replyText);
    await tester.tap(find.byTooltip('Close thread'));
    await until(tester, () => w.threadParent == null);
    final inlineReply = find.byKey(ValueKey('inline-reply-${nativeReply.id}'));
    await until(tester, () => inlineReply.evaluate().isNotEmpty);
    await tester.ensureVisible(inlineReply);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: inlineReply, matching: find.text(replyText)),
      findsOneWidget,
    );
    await screenshot(tester, 'linux-thread-inline-preview');
    // Source InlineThreadReplies is one parent-thread button. Its unread
    // projection selects the target; an individual preview is not a route.
    final liveSummary = w.threadSummaries[sent.id];
    final expectedUnread = liveSummary is Map
        ? liveSummary['firstUnreadMessageId'] as String?
        : null;
    await tester.tap(inlineReply);
    await until(
      tester,
      () =>
          w.threadParent?.id == sent.id &&
          !w.threadLoading &&
          w.highlightedMessageId == expectedUnread &&
          find
              .byKey(ValueKey('message-${nativeReply.id}'))
              .evaluate()
              .isNotEmpty,
    );
    await screenshot(tester, 'linux-thread-inline-reply-navigation');
    await w.toggleReaction(sent, '👍');
    await tester.pump(const Duration(milliseconds: 300));
    expect(w.reactionViewer.reacted(sent.id), contains('👍'));
    final ownViewer = await w.client.get(
      '/messages/${sent.id}/reactions/viewer',
    );
    expect(ownViewer['reactedEmojis'], contains('👍'));
    await w.toggleReaction(sent, '👍');
    final removedViewer = await w.client.get(
      '/messages/${sent.id}/reactions/viewer',
    );
    expect(removedViewer['reactedEmojis'], isNot(contains('👍')));
    expect(
      removedViewer['viewerVersion'],
      greaterThan(ownViewer['viewerVersion']),
    );
    final second = RaftClient(
      origin: fixture['origin'],
      sessionStore: MemorySessionStore(),
    );
    await second.login(fixture['email'], fixture['password']);
    second.selectServer(w.server!.id);
    final isolated = await w.client.request(
      'POST',
      '/channels',
      data: {
        'name': 'native-sync-${DateTime.now().millisecondsSinceEpoch}',
        'type': 'channel',
      },
    );
    final syncChannel = RaftChannel(Map<String, dynamic>.from(isolated));
    w.closeThread();
    await w.refreshChannels();
    await w.selectChannel(syncChannel);
    await until(tester, () => w.connected);
    w.client.suspendConnection();
    await until(tester, () => !w.connected);
    final author = RaftClient(
      origin: fixture['origin'],
      sessionStore: MemorySessionStore(),
    );
    await author.login(fixture['otherEmail'], fixture['otherPassword']);
    author.selectServer(w.server!.id);
    await author.request('POST', '/channels/${syncChannel.id}/join');
    final offlineText =
        'Reconnect native ${DateTime.now().millisecondsSinceEpoch}';
    await author.send(syncChannel.id, offlineText);
    expect(w.messages.where((m) => m.content == offlineText), isEmpty);
    w.client.recoverConnection(w.ledger.watermark);
    await until(
      tester,
      () => w.connected && w.messages.any((m) => m.content == offlineText),
    );
    expect(w.messages.where((m) => m.content == offlineText), hasLength(1));
    w.closeThread();
    await w.markRead(syncChannel.id);
    final backgroundRead = w.readState.state(
      w.server!.id,
      principal,
      syncChannel.id,
    )!['maxReadSeq'];
    w.setForeground(false);
    final backgroundText =
        'Background unread ${DateTime.now().millisecondsSinceEpoch}';
    await author.send(syncChannel.id, backgroundText);
    await until(
      tester,
      () => w.messages.any((m) => m.content == backgroundText),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      w.readState.state(w.server!.id, principal, syncChannel.id)!['maxReadSeq'],
      backgroundRead,
    );
    w.setForeground(true);
    await until(
      tester,
      () =>
          w.readState.state(
            w.server!.id,
            principal,
            syncChannel.id,
          )!['maxReadSeq'] >
          backgroundRead,
    );
    await author.logout();
    await author.dispose();
    await w.markRead(syncChannel.id);
    await tester.pump(const Duration(milliseconds: 500));
    final beforeRead = w.readState.state(
      w.server!.id,
      principal,
      syncChannel.id,
    );
    final unreadResult = await second.request(
      'POST',
      '/channels/${syncChannel.id}/unread',
    );
    await until(
      tester,
      () =>
          (w.readState.state(
                w.server!.id,
                principal,
                syncChannel.id,
              )?['readStateVersion'] ??
              -1) >=
          unreadResult['readStateVersion'],
    );
    final markedUnread = w.readState.state(
      w.server!.id,
      principal,
      syncChannel.id,
    )!;
    expect(markedUnread['maxReadSeq'], unreadResult['maxReadSeq']);
    if (beforeRead != null) {
      expect(
        markedUnread['readStateVersion'],
        greaterThan(beforeRead['readStateVersion']),
      );
    }
    await w.markRead(syncChannel.id);
    await w.client.request('DELETE', '/channels/${syncChannel.id}');
    await w.refreshChannels();
    await w.selectChannel(general);
    await second.logout();
    await second.dispose();
    await section(tester, 'tasks');
    expect(find.byType(ResourceView), findsOneWidget);
    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();
    final taskTitle = 'Native task ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(field('Title'), taskTitle);
    await tester.enterText(
      field('Description (Markdown)'),
      'Created, claimed, reviewed and deleted by the native UI.',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(RaftButton, 'Create'));
    await until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(taskTitle),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ResourceView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    var taskCard = find.widgetWithText(RaftTaskCard, taskTitle);
    await tester.ensureVisible(taskCard);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: taskCard, matching: find.text(taskTitle)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Claim'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(taskTitle),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ResourceView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await until(
      tester,
      () =>
          find.widgetWithText(RaftTaskCard, taskTitle).evaluate().isNotEmpty &&
          tester
                  .widget<RaftTaskCard>(
                    find.widgetWithText(RaftTaskCard, taskTitle),
                  )
                  .assignee !=
              null,
    );
    taskCard = find.widgetWithText(RaftTaskCard, taskTitle);
    await tester.ensureVisible(taskCard);
    await tester.pumpAndSettle();
    final statusPopup = find.descendant(
      of: taskCard,
      matching: find.byTooltip('Task status'),
    );
    await tester.tap(statusPopup);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('In Review'),
      ),
    );
    await until(
      tester,
      () =>
          find.widgetWithText(RaftTaskCard, taskTitle).evaluate().isNotEmpty &&
          tester
                  .widget<RaftTaskCard>(
                    find.widgetWithText(RaftTaskCard, taskTitle),
                  )
                  .status ==
              'in_review',
    );
    final taskRows =
        (tester.state(find.byType(ResourceView)) as dynamic).rows as List;
    final createdTaskId =
        taskRows.singleWhere((row) => row['title'] == taskTitle)['id']
            as String;
    await verifyAdvancedTaskFilters(
      tester,
      w,
      taskId: createdTaskId,
      channelName: general.name,
      capture: (name) =>
          screenshot(tester, name.replaceFirst('native-', 'linux-')),
    );
    await section(tester, 'tasks');
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    await until(
      tester,
      () =>
          (tester.state(find.byType(ResourceView)) as dynamic).loading == false,
    );
    dynamic board() => tester.state(find.byType(ResourceView));
    expect(board().error, isNull);
    final reviewHeader = find.widgetWithText(RaftTaskStatus, 'In Review').first;
    await tester.ensureVisible(reviewHeader);
    await tester.pumpAndSettle();
    final reviewLane = find.byKey(const ValueKey('task-drop-in_review'));
    final reviewScroll = find
        .descendant(of: reviewLane, matching: find.byType(Scrollable))
        .first;
    for (
      var page = 0;
      page < 20 &&
          !(board().lanes['in_review'] as List).any(
            (row) => row['id'] == createdTaskId,
          ) &&
          board().laneCursors['in_review'] != null;
      page++
    ) {
      final more = find.widgetWithText(RaftTextButton, 'Load more In Review');
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await until(tester, () => !board().laneBusy.contains('in_review'));
      expect(board().error, isNull);
    }
    expect(
      (board().lanes['in_review'] as List).any(
        (row) => row['id'] == createdTaskId,
      ),
      true,
      reason: 'The real paged In Review lane must contain this run\'s task.',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(RaftTaskCard, taskTitle),
      250,
      scrollable: reviewScroll,
      maxScrolls: 150,
    );
    await tester.ensureVisible(find.widgetWithText(RaftTaskCard, taskTitle));
    await tester.pumpAndSettle();
    await screenshot(tester, 'linux-task-board');
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(taskTitle),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ResourceView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    taskCard = find.widgetWithText(RaftTaskCard, taskTitle);
    await tester.ensureVisible(taskCard);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: taskCard, matching: find.text(taskTitle)),
    );
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    await screenshot(tester, 'linux-task-history');
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RaftButton, 'Delete'));
    await until(
      tester,
      () => find.widgetWithText(RaftTaskCard, taskTitle).evaluate().isEmpty,
    );
    await section(tester, 'search');
    final searchInput = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Search messages',
    );
    await tester.enterText(searchInput, text);
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pumpAndSettle();
    final searchResult = find.descendant(
      of: find.byType(ResourceSearchResults),
      matching: find.byWidgetPredicate(
        (widget) => widget is SearchHighlight && widget.text == text,
      ),
    );
    await until(tester, () => searchResult.evaluate().isNotEmpty);
    await screenshot(tester, 'linux-search');
    debugPrint('Native Search: tap actual result');
    await tester.tap(searchResult.first);
    await until(
      tester,
      () =>
          w.section == 'chat' &&
          w.highlightedMessageId == sent.id &&
          !w.channelLoading,
    );
    debugPrint(
      'Native Search: accepted context; awaiting actual viewport receipt',
    );
    final jumped = find.byKey(ValueKey('message-${sent.id}'));
    final mainChat = find.byWidgetPredicate(
      (widget) => widget is RaftChatView && !widget.thread,
    );
    await until(
      tester,
      () =>
          jumped.evaluate().isNotEmpty &&
          mainChat.evaluate().length == 1 &&
          (tester.state(mainChat) as dynamic).scrolledHighlight == sent.id &&
          (tester.state(mainChat) as dynamic).scrolledWindow ==
              w.channelGeneration &&
          (tester.state(mainChat) as dynamic).focusReceiptVisible(sent.id) ==
              true,
    );
    expect(jumped, findsOneWidget);
    debugPrint('Native Search: target attached and intersects real viewport');
    // Open the real channel header entry after a previous global query.
    // This exercises production routing and excludes restored global state.
    await tester.tap(find.bySemanticsLabel('Search this channel'));
    await tester.pumpAndSettle();
    final channelSearch = tester.widget<ResourceView>(
      find.byType(ResourceView),
    );
    expect(channelSearch.initialSearchChannelId, general.id);
    expect(channelSearch.initialSearchDeferUntilQuery, isTrue);
    expect(channelSearch.restoreSearchState, isFalse);
    expect(tester.widget<TextField>(searchInput).controller!.text, isEmpty);
    expect(find.byType(ResourceSearchResults), findsNothing);
    await screenshot(tester, 'linux-channel-search-empty');
    await tester.enterText(searchInput, text);
    await tester.pump(const Duration(milliseconds: 210));
    await until(tester, () => searchResult.evaluate().isNotEmpty);
    await screenshot(tester, 'linux-channel-search-results');
    await tester.tap(searchResult.first);
    await until(
      tester,
      () =>
          w.section == 'chat' &&
          w.channel?.id == general.id &&
          w.highlightedMessageId == sent.id &&
          mainChat.evaluate().length == 1 &&
          (tester.state(mainChat) as dynamic).focusReceiptVisible(sent.id) ==
              true,
    );
    expect(jumped, findsOneWidget);
    final saveEntry = find.byKey(const ValueKey('message-menu-save'));
    await openNativeMessageMenu(tester, jumped, entry: saveEntry);
    await tester.tap(saveEntry);
    await until(tester, () => saveEntry.evaluate().isEmpty);
    await section(tester, 'saved');
    await until(tester, () => find.text(text).evaluate().isNotEmpty);
    await screenshot(tester, 'linux-saved');
    await tester.tap(find.text(text).first);
    await until(
      tester,
      () => w.section == 'chat' && w.highlightedMessageId == sent.id,
    );
    await verifyAdvancedResources(
      tester,
      w,
      channelId: general.id,
      channelName: general.name,
      messageId: sent.id,
      query: text,
      capture: (name) =>
          screenshot(tester, name.replaceFirst('native-', 'linux-')),
    );
    await verifyActivityThreadLifecycle(
      tester,
      w,
      threadId: verifiedThreadId,
      parentId: sent.id,
      capture: (name) => screenshot(tester, 'linux-$name'),
    );

    // Each native run owns its channel; never change seeded workspace data.
    await w.selectChannel(general);
    await tester.pumpAndSettle();
    await mobileHome(tester);
    await revealSidebar(tester, find.byTooltip('Create channel'));
    await tester.tap(find.byTooltip('Create channel'));
    await tester.pumpAndSettle();
    final createdName = 'native-ui-${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(field('Channel name'), createdName);
    await tester.enterText(
      field('Description'),
      'Native channel settings verification',
    );
    await tester.tap(find.widgetWithText(RaftButton, 'Create'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          w.channel?.name == createdName &&
          !w.channelLoading,
    );
    await tester.pumpAndSettle();
    final createdId = w.channel!.id;
    await verifyAttachmentFlow(tester, w, (name) => screenshot(tester, name));
    Future<void> openSettings() async {
      await tester.tap(find.byTooltip('Channel settings'));
      await tester.pumpAndSettle();
      await until(
        tester,
        () => find.text('Pin conversation').evaluate().isNotEmpty,
      );
    }

    Future<void> setting(String title) async {
      final scroll = find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scroll);
      state.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(title),
        150,
        scrollable: scroll,
      );
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, title);
      if (toggle.evaluate().isNotEmpty) {
        await until(
          tester,
          () => tester.widget<SwitchListTile>(toggle).onChanged != null,
        );
      }
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      if (toggle.evaluate().isNotEmpty) {
        await until(
          tester,
          () => tester.widget<SwitchListTile>(toggle).onChanged != null,
        );
      }
    }

    await openSettings();
    await setting('Pin conversation');
    await until(
      tester,
      () => (w.sidebarOrder['pinned'] as List? ?? []).any(
        (p) => p['id'] == createdId,
      ),
    );
    await setting('Mute activity');
    expect(
      (await w.query(
        '/channels/$createdId/notification-settings',
      ))['activityMuted'],
      true,
    );
    await setting('Collapse long messages');
    expect(
      (await w.query(
        '/channels/$createdId/message-display-settings',
      ))['collapseLongMessages'],
      false,
    );
    await setting('Edit channel');
    await tester.enterText(
      field('Description'),
      'Updated from native UI 中文 日本語',
    );
    await tester.tap(find.widgetWithText(RaftButton, 'Save'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          w.channel?.description == 'Updated from native UI 中文 日本語',
    );
    await tester.pumpAndSettle();
    await screenshot(tester, 'linux-channel-settings');
    await setting('Archive channel');
    await tester.tap(find.widgetWithText(RaftButton, 'Confirm'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          w.channel?.archived == true,
    );
    await tester.pumpAndSettle();
    if (find.byTooltip('Close channel settings').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Close channel settings'));
    }
    await tester.pumpAndSettle();
    expect(
      tester.widget<RaftComposer>(find.byType(RaftComposer)).enabled,
      false,
    );
    await openSettings();
    await setting('Unarchive channel');
    await tester.tap(find.widgetWithText(RaftButton, 'Confirm'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          w.channel?.archived == false,
    );
    await tester.pumpAndSettle();
    await setting('Delete channel');
    await tester.tap(find.widgetWithText(RaftButton, 'Delete'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          !w.channels.any((c) => c.id == createdId),
    );
    await tester.pumpAndSettle();
    expect(w.channel, isNull);
    await w.selectChannel(general);
    await tester.pumpAndSettle();

    final originalServer = w.server!;
    await mobileHome(tester);
    final switcher = mobileViewport(tester)
        ? find.byKey(const Key('mobile-server-selector'))
        : find.byTooltip('Switch workspace').last;
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();
    final workspaceName =
        'native-workspace-${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(field('Workspace name'), workspaceName);
    await tester.enterText(field('Workspace address'), workspaceName);
    await tester.tap(find.widgetWithText(RaftButton, 'Create'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          w.server?.name == workspaceName,
    );
    await tester.pumpAndSettle();
    final ownServerId = w.server!.id;
    await section(tester, 'workspace-settings');
    await until(
      tester,
      () => find.text('Edit workspace').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Edit workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Workspace name'), '$workspaceName edited');
    await tester.tap(find.widgetWithText(RaftButton, 'Save'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          w.server!.name == '$workspaceName edited',
    );
    await tester.pumpAndSettle();
    final notificationChoice = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(notificationChoice);
    await tester.tap(notificationChoice);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mentions only').last);
    await tester.pumpAndSettle();
    expect(
      (await w.query(
        '/servers/$ownServerId/notification-settings',
      ))['serverPushMode'],
      'mentions',
    );
    await tester.ensureVisible(find.text('Create invitation link'));
    await tester.tap(find.text('Create invitation link'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Maximum uses'), '1');
    await tester.tap(find.widgetWithText(RaftButton, 'Create link'));
    await until(
      tester,
      () => find.text('Invitation link').evaluate().isNotEmpty,
    );
    final link = tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;
    final inviteToken = Uri.parse(link).pathSegments.last;
    final invited = RaftClient(
      origin: fixture['origin'],
      sessionStore: MemorySessionStore(),
    );
    await invited.login(fixture['otherEmail'], fixture['otherPassword']);
    final otherId = invited.user!.id, otherName = invited.user!.name;
    await invited.post('/auth/accept-invite', data: {'token': inviteToken});
    invited.selectServer(ownServerId);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'linux-workspace-settings');
    await section(tester, 'members');
    await until(
      tester,
      () => find.widgetWithText(ListTile, otherName).evaluate().isNotEmpty,
    );
    final memberTile = find.widgetWithText(ListTile, otherName);
    await tester.ensureVisible(memberTile);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: memberTile,
        matching: find.byTooltip('Member actions'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RaftButton, 'Confirm'));
    await until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    expect(
      (await w.query('/servers/$ownServerId/members') as List).firstWhere(
        (m) => m['userId'] == otherId,
      )['role'],
      'admin',
    );
    await tester.pumpAndSettle();
    await screenshot(tester, 'linux-workspace-members');
    await invited.logout();
    await invited.dispose();
    // Create, inspect, edit and delete only resources in this run's workspace.
    Future<void> fleetFlow(bool computers) async {
      await section(tester, computers ? 'computers' : 'agents');
      final name =
          'native-${computers ? 'computer' : 'agent'}-${DateTime.now().millisecondsSinceEpoch}';
      await until(
        tester,
        () => find
            .widgetWithText(
              RaftButton,
              computers ? 'Register computer' : 'Create agent',
            )
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.widgetWithText(
          RaftButton,
          computers ? 'Register computer' : 'Create agent',
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Name'), name);
      await tester.tap(
        find.widgetWithText(RaftButton, computers ? 'Register' : 'Create'),
      );
      await until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
      if (computers) {
        await until(
          tester,
          () => find.text('Credential hidden').evaluate().isNotEmpty,
        );
        expect(find.text('Reveal credential'), findsOneWidget);
        // Do not reveal/copy the real key during automated tests.
        await tester.tap(find.text('Close'));
      }
      await until(
        tester,
        () => find
            .descendant(
              of: find.byKey(const Key('fleet-directory')),
              matching: find.widgetWithText(ListTile, name),
            )
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('fleet-directory')),
          matching: find.widgetWithText(ListTile, name),
        ),
      );
      await tester.pumpAndSettle();
      final detailScroll = find
          .descendant(
            of: find.byKey(const Key('fleet-detail')),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> detailAction(String title) async {
        final action = find.descendant(
          of: find.byKey(const Key('fleet-detail')),
          matching: find.widgetWithText(ListTile, title),
        );
        tester.state<ScrollableState>(detailScroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(action, 160, scrollable: detailScroll);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
      }

      await detailAction(computers ? 'Edit computer' : 'Edit agent');
      await tester.enterText(field('Display name'), '$name edited');
      await tester.enterText(
        field('Description'),
        'Native managed resource 中文 日本語',
      );
      await tester.tap(find.widgetWithText(RaftButton, 'Save'));
      await until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
      await tester.pumpAndSettle();
      final freshResources = await w.query(
        computers ? '/servers/$ownServerId/machines' : '/agents',
      );
      final editedRows = computers
          ? freshResources['machines'] as List
          : freshResources as List;
      final edited = editedRows.singleWhere(
        (r) => r['name'] == name || r['name'] == '$name edited',
      );
      expect(edited['description'], 'Native managed resource 中文 日本語');
      tester.state<ScrollableState>(detailScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Native managed resource 中文 日本語'), findsOneWidget);
      await screenshot(
        tester,
        computers ? 'linux-computer-details' : 'linux-agent-details',
      );
      if (!computers) {
        await detailAction('Agent permissions');
        await until(
          tester,
          () => find.byKey(const Key('agent-scope-list')).evaluate().isNotEmpty,
        );
        final scopeScroll = find
            .descendant(
              of: find.byKey(const Key('agent-scope-list')),
              matching: find.byType(Scrollable),
            )
            .first;
        final permissions = find.byKey(const ValueKey('scope-message:send'));
        await tester.scrollUntilVisible(
          permissions,
          180,
          scrollable: scopeScroll,
        );
        await tester.ensureVisible(permissions);
        await tester.pumpAndSettle();
        await tester.tap(permissions);
        await tester.scrollUntilVisible(
          find.widgetWithText(RaftButton, 'Save permissions'),
          180,
          scrollable: scopeScroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(RaftButton, 'Save permissions'));
        await until(
          tester,
          () => find.text('Agent permissions saved').evaluate().isNotEmpty,
        );
        final agent = (await w.query('/agents') as List).singleWhere(
          (a) => a['name'] == name,
        );
        final savedScopes = await w.query('/agents/${agent['id']}/scopes');
        expect(savedScopes['mode'], 'custom');
        expect(
          (savedScopes['granted'] as List).contains('message:send'),
          false,
        );
        // Dismiss the real success toast before clicking the bottom action.
        final dismissToast = find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byIcon(Icons.close),
            )
            .hitTestable();
        await until(tester, () => dismissToast.evaluate().isNotEmpty);
        await tester.tap(dismissToast);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Restore default permissions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restore default permissions'));
        tester.state<ScrollableState>(scopeScroll).position.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 500));
        await until(
          tester,
          () => find.text('Default permissions').evaluate().isNotEmpty,
        );
        expect(
          (await w.query('/agents/${agent['id']}/scopes'))['mode'],
          'default',
        );
        await until(tester, () => dismissToast.evaluate().isNotEmpty);
        await tester.tap(dismissToast);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await detailAction('Activity log');
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('Activity log'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      await detailAction(computers ? 'Delete computer' : 'Delete agent');
      await tester.tap(find.widgetWithText(RaftButton, 'Delete'));
      await until(
        tester,
        () => find.byKey(const Key('fleet-detail')).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      final result = await w.query(
        computers ? '/servers/$ownServerId/machines' : '/agents',
      );
      final resources = computers ? result['machines'] : result;
      expect(
        (resources as List).any(
          (r) =>
              (computers || r['deletedAt'] == null) &&
              (r['name'] == name || r['name'] == '$name edited'),
        ),
        false,
      );
    }

    await fleetFlow(false);
    await fleetFlow(true);
    await section(tester, 'workspace-settings');
    await until(
      tester,
      () => find.text('Delete workspace').evaluate().isNotEmpty,
    );
    await tester.ensureVisible(find.text('Delete workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(
      field('Type workspace name'),
      '$workspaceName edited',
    );
    await tester.tap(find.widgetWithText(RaftButton, 'Delete'));
    await until(
      tester,
      () =>
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          !w.servers.any((s) => s.id == ownServerId),
    );
    await w.selectServer(originalServer);
    await w.selectChannel(general);
    await tester.pumpAndSettle();
    if (fixture['runtimeProbe'] is Map) {
      await verifyRuntimeReview(
        tester,
        w,
        fixture['runtimeProbe'],
        section: (name) => section(tester, name),
        capture: (name) => screenshot(tester, name),
      );
    }
    w.setSection('chat');
    await tester.pumpAndSettle();
    await verifyPreparedActionCard(
      tester,
      w,
      (name) => screenshot(tester, name),
    );
    await verifyComposerSuggestions(
      tester,
      w,
      (name) => screenshot(tester, name),
    );
    await verifyRichContent(tester, w, (name) => screenshot(tester, name));
    await verifyHtmlPreview(tester, w, (name) => screenshot(tester, name));
    await verifyNativeMediaPreviewFlow(
      tester,
      w,
      (name) => screenshot(tester, 'linux-$name'),
    );
    await verifyMessageSelection(tester, w, (name) => screenshot(tester, name));
    await verifyForwardFlow(
      tester,
      w,
      capture: (name) => screenshot(tester, name),
    );
    await verifyContentNavigation(
      tester,
      w,
      (name) => screenshot(tester, name),
    );
    await verifyNativeNotificationFlow(
      tester,
      w,
      otherEmail: fixture['otherEmail'],
      otherPassword: fixture['otherPassword'],
      reportFolder: nativeReportFolder,
      capture: (name) => screenshot(tester, name),
    );
    await verifyManagementFlow(
      tester,
      w,
      section: (name) => section(tester, name),
      capture: (name) => screenshot(tester, name),
    );
    await verifyChannelConversionFlow(
      tester,
      w,
      capture: (name) => screenshot(tester, 'linux-$name'),
    );
    await verifyJointChannelFlow(
      tester,
      w,
      section: (name) => section(tester, name),
      capture: (name) => screenshot(tester, 'linux-$name'),
      fixtureEmailDisabled: true,
    );
    await w.selectChannel(general);
    await tester.pumpAndSettle();
    if (w.dms.isEmpty) {
      await w.command('POST', '/channels/dm', data: {'userId': otherId});
      await w.refreshChannels();
    }
    await verifySidebarFlow(
      tester,
      w,
      section: (name) => section(tester, name),
      capture: (name) => screenshot(tester, 'linux-$name'),
    );
    await w.selectChannel(general);
    await tester.pumpAndSettle();

    if (find.byTooltip('Close thread').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Close thread').first);
    }
    await tester.pump();
    await openAccountSettings(tester);
    final oldReading = {
      for (final key in ['preferredTimeFormat', 'preferredMessageBodyFontSize'])
        key: w.client.user!.json[key],
    };
    try {
      await tester.ensureVisible(find.text('Reading preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reading preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('field-preferredTimeFormat')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12-hour').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('field-preferredMessageBodyFontSize')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large · 16 px').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RaftButton, 'Save'));
      await until(
        tester,
        () =>
            find.byType(RaftFormDialog).evaluate().isEmpty &&
            w.client.user!.string('preferredMessageBodyFontSize') == 'lg',
      );
      await w.selectChannel(general);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RaftMessageTile>(find.byType(RaftMessageTile).first)
            .bodyFontSize,
        16,
      );
      expect(
        tester
            .widget<RaftMessageTile>(find.byType(RaftMessageTile).first)
            .timestamp,
        contains(RegExp('AM|PM')),
      );
      await screenshot(tester, 'linux-reading-preferences');
    } finally {
      await w.client.patch('/auth/me', data: oldReading);
      await w.client.reloadUser();
    }
    await openAccountSettings(tester);
    final oldLanguage = w.client.user!.json['displayLanguage'];
    try {
      await settingsTab(tester, 'language');
      await tester.tap(find.byKey(const ValueKey('setting-displayLanguage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('简体中文').last);
      await until(
        tester,
        () => w.client.user!.string('displayLanguage') == 'zh-cn',
      );
      await tester.pumpAndSettle();
      final accountScroll = find
          .descendant(
            of: find.byKey(const ValueKey('settings-page-language')),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        Localizations.localeOf(tester.element(accountScroll)).languageCode,
        'zh',
      );
      tester.state<ScrollableState>(accountScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('setting-displayLanguage')),
        findsOneWidget,
      );
      await screenshot(tester, 'linux-display-language');
    } finally {
      await w.client.patch('/auth/me', data: {'displayLanguage': oldLanguage});
      await w.client.reloadUser();
      await tester.pumpAndSettle();
    }
    await settingsTab(tester, 'appearance');
    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      RaftTokens.of(tester.element(find.byKey(const Key('appearance-mode'))))
          .dark,
      true,
    );
    await screenshot(tester, 'linux-elegant-dark');
    await tester.tap(find.text('Light'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(
      find.byKey(const ValueKey('appearance-light-theme-elegant')),
    );
    await tester.tap(
      find.byKey(const ValueKey('appearance-light-theme-elegant')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      RaftTokens.of(tester.element(find.byKey(const Key('appearance-mode'))))
          .family,
      RaftFamily.elegant,
    );
    await screenshot(tester, 'linux-elegant-light');
    await settingsTab(tester, 'account');
    final accountScroll = find
        .descendant(
          of: find.byKey(const ValueKey('settings-page-account')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      250,
      scrollable: accountScroll,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'linux-session-sign-out');
    await tester.tap(find.text('Sign out'));
    await until(
      tester,
      () => find.byKey(const Key('login-email')).evaluate().isNotEmpty,
    );
    expect(await storage.read(fixture['origin']), isNull);
    await File('$nativeReportFolder/native-$nativePlatform-run.json')
        .writeAsString(
          jsonEncode({
            'runId': nativeRunId,
            'platform': nativePlatform,
            'completed': true,
            'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
          }),
        );
    if (nativePlatform == 'android') {
      final wait = Stopwatch()..start();
      var collected = false;
      final receipt = File('$nativeReportFolder/native-android-collected.json');
      while (!collected && wait.elapsed < const Duration(seconds: 30)) {
        await tester.pump(const Duration(milliseconds: 200));
        try {
          if (!await receipt.exists()) continue;
          final value = jsonDecode(await receipt.readAsString());
          collected =
              value is Map &&
              value['collected'] == true &&
              value['runId'] == nativeRunId &&
              value['sourceHash'] ==
                  const String.fromEnvironment('RAFT_TEST_SOURCE_HASH');
        } on FormatException {
          // A stale or partial receipt never acknowledges this run.
        } on FileSystemException {
          // The host may still be copying the final checkpoint.
        }
      }
      expect(
        collected,
        true,
        reason: 'Android evidence was not collected for the current run.',
      );
    }
  });
}
