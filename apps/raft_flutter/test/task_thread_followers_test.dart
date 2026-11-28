import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/task_surface_controller.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' as messages;
import 'support/tasks_page_harness.dart' show pageTask, sizeWindow;
import 'thread_agent_followers_test.dart' as followers;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (size, platform) in [
    (const Size(1280, 900), TargetPlatform.linux),
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(390, 844), TargetPlatform.android),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('task followers open a profile at $size on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      final (workspace, api) = (await tester.runAsync(
        () => messages.fixture('owner'),
      ))!;
      const channel = 'conv-task1';
      final task = pageTask('task1');
      api.routes['GET /messages/channel/$channel'] = (_) => {'messages': []};
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /channels/threads/followers'] = (_) => {
        'threads': [
          {
            'threadChannelId': channel,
            'canManage': true,
            'agents': [
              followers.follower(
                'reporter',
                'Reporter',
                canRemove: false,
                current: false,
              ),
            ],
          },
        ],
      };
      final owner = TaskSurfaceController(
        parent: workspace,
        row: task,
        valid: () => true,
      );
      owner.openDiscussion(conversationId: channel);
      var closed = false;
      sizeWindow(tester, size);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(
              body: SourceTaskSurface(
                owner: owner,
                onClose: () => closed = true,
                onTask: null,
                onViewBilling: null,
              ),
            ),
          ),
        );
        await followers.settle(tester);
        final trigger = find.byKey(
          const Key('thread-followers-header-trigger'),
        );
        await tester.tap(trigger);
        await followers.settle(tester);
        final button = find.byKey(const Key('thread-follower-remove'));
        if (platform == TargetPlatform.linux && size.width == 1280) {
          final popup = tester.getRect(
            find.byKey(const Key('thread-followers-popover')),
          );
          final anchor = tester.getRect(trigger);
          final actions = tester.getRect(
            find.byKey(const Key('task-overflow-trigger')),
          );
          expect(popup.size, const Size(288, 124));
          expect(popup.right, closeTo(anchor.right, .5));
          expect(popup.top - anchor.bottom, closeTo(6, .5));
          expect(actions.left - anchor.right, 4);
        }
        const denial =
            "Only the host server's admins and this channel's admins can remove agents from other servers.";
        expect(find.bySemanticsLabel(denial), findsOneWidget);
        expect(tester.widget<RaftButton>(button).onPressed, isNull);
        if (platform == TargetPlatform.linux) {
          final pointer = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await pointer.addPointer(location: Offset.zero);
          await pointer.moveTo(tester.getCenter(button));
          await tester.pump();
          await pointer.moveBy(const Offset(1, 0));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text(denial), findsNothing);
          await pointer.removePointer();
        }
        await tester.tap(button);
        expect(api.calls.where((call) => call.method == 'DELETE'), isEmpty);
        await tester.tap(find.text('Reporter'));
        await followers.settle(tester);
        expect(workspace.location.profile, isNull);
        expect(
          find.byKey(const ValueKey('profile-agent-reporter')),
          findsOneWidget,
        );
        expect(find.byType(SourceTaskSurface), findsOneWidget);
        expect(
          api.calls.where((call) => call.path == '/agents/reporter'),
          isEmpty,
        );
        if (platform == TargetPlatform.linux) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.binding.handlePopRoute();
        }
        await followers.settle(tester);
        expect(find.byKey(const Key('profile-panel')), findsNothing);
        expect(trigger, findsOneWidget);
        expect(closed, isFalse);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        owner.dispose();
        workspace.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
