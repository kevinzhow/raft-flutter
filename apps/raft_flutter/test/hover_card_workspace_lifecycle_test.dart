import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/profile_preview.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

RootFixture fixture() => RootFixture()
  ..overrides.addAll({
    'GET /agents': (_) => [
      {
        'id': 'agent-1',
        'name': 'nova',
        'displayName': 'Nova',
        'runtime': 'codex',
        'model': 'gpt-6',
        'activity': 'working',
        'creatorType': 'user',
        'creatorId': 'alice',
      },
    ],
    'GET /messages/channel/ca': (_) => {
      'messages': [
        {
          'id': 'ma',
          'channelId': 'ca',
          'seq': '1',
          'senderId': 'agent-1',
          'senderType': 'agent',
          'senderName': 'nova',
          'senderDisplayName': 'Nova',
          'content': 'Accepted a',
          'createdAt': '2026-10-10T00:00:00Z',
        },
      ],
      'hasMore': false,
      'hasNewer': false,
    },
    'GET /agents/agent-1/activity-log': (_) => [],
    'GET /announcements/active': (_) => [],
  });

Finder get avatar => find.byWidgetPredicate(
  (widget) =>
      widget is RaftAvatarButton &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('sender-avatar-'),
);

Future<TestGesture> hoverAvatar(WidgetTester t) async {
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(t.getCenter(avatar));
  await t.pump(const Duration(milliseconds: 210));
  await t.pump(const Duration(milliseconds: 300));
  expect(find.byType(ProfilePreviewContent), findsOneWidget);
  return mouse;
}

void main() {
  setUp(() {
    final strategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
  });
  tearDownAll(() => DesktopTitleBarController.platform.state.dispose());
  testWidgets(
    'sender avatar click closes its preview through detail and back',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final f = fixture();
      TestGesture? mouse;
      try {
        await f.mount(t, 'light', 1200);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        expect(avatar, findsOneWidget);
        mouse = await hoverAvatar(t);
        await mouse.down(t.getCenter(avatar));
        await mouse.up();
        await f.flush(t);
        expect(f.workspace(t).location.uri.query, contains('profile='));
        expect(find.byType(ProfilePreviewContent), findsNothing);
        f.workspace(t).closeProfile();
        await f.flush(t);
        await t.pump(const Duration(seconds: 1));
        expect(find.byType(ProfilePreviewContent), findsNothing);
        await mouse.moveTo(const Offset(1, 1));
        await t.pump();
        await mouse.moveTo(t.getCenter(avatar));
        await t.pump(const Duration(milliseconds: 210));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(ProfilePreviewContent), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await f.close(t);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('programmatic profile navigation closes a sender preview', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final f = fixture();
    TestGesture? mouse;
    try {
      await f.mount(t, 'light', 1200);
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await f.flush(t);
      mouse = await hoverAvatar(t);
      f.workspace(t).openProfile(RaftProfileKind.agent, 'agent-1');
      await f.flush(t);
      expect(find.byType(ProfilePreviewContent), findsNothing);
      f.workspace(t).closeProfile();
      await f.flush(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(ProfilePreviewContent), findsNothing);
    } finally {
      await mouse?.removePointer();
      await f.close(t);
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets(
    'actual root route uses its scope observer through push and pop',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final f = fixture();
      TestGesture? mouse;
      try {
        await f.mount(t, 'light', 1200);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        final router = f.router(t);
        final navigator = find.byKey(router.navigatorKey);
        final controller = RaftHoverDismissScope.maybeOf(t.element(navigator))!;
        final observers = t.widget<Navigator>(navigator).observers;
        expect(observers.whereType<RaftHoverDismissController>(), [controller]);
        expect(observers, containsAll(router.observers));
        expect(observers.toSet().length, observers.length);
        expect(
          find.ancestor(of: navigator, matching: find.byType(DesktopTitleBar)),
          findsOneWidget,
        );
        expect(
          RaftHoverDismissScope.maybeOf(
            t.element(find.byType(DesktopTitleBar)),
          ),
          same(controller),
        );
        mouse = await hoverAvatar(t);
        router.navigatorKey.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Root route detail'))),
          ),
        );
        await f.flush(t);
        expect(find.text('Root route detail'), findsOneWidget);
        expect(find.byType(ProfilePreviewContent), findsNothing);
        router.navigatorKey.currentState!.pop();
        await f.flush(t);
        await t.pump(const Duration(seconds: 1));
        expect(avatar, findsOneWidget);
        expect(find.byType(ProfilePreviewContent), findsNothing);
        expect(
          RaftHoverDismissScope.maybeOf(t.element(navigator)),
          same(controller),
        );
        await mouse.moveBy(const Offset(1, 0));
        await t.pump(const Duration(milliseconds: 210));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(ProfilePreviewContent), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await f.close(t);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'pending avatar preview stays closed through page selection and return',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final f = fixture();
      TestGesture? mouse;
      try {
        await f.mount(t, 'light', 1200);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        final channel = f.workspace(t).location.uri;
        mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(t.getCenter(avatar));
        await t.pump(const Duration(milliseconds: 100));
        f.workspace(t).setSection('agents');
        await f.flush(t);
        expect(f.workspace(t).location.uri, isNot(channel));
        expect(find.byType(ProfilePreviewContent), findsNothing);
        await f.pushUri(t, channel.toString());
        await t.pump(const Duration(seconds: 1));
        expect(avatar, findsOneWidget);
        expect(find.byType(ProfilePreviewContent), findsNothing);
        await mouse.moveTo(t.getCenter(avatar) + const Offset(1, 0));
        await t.pump(const Duration(milliseconds: 210));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(ProfilePreviewContent), findsOneWidget);
      } finally {
        await mouse?.removePointer();
        await f.close(t);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
