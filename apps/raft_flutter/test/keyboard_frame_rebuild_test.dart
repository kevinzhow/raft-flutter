// Keyboard animation frame guard (widget level, production app root).
//
// Every frame of the soft-keyboard animation changes `viewInsets` (and, for
// the first frames, `padding`) and the engine hands over a new
// `displayFeatures` list. Only the widgets that spend the inset may rebuild:
// the message rows, the timeline and the page shell must not. The device cost
// of this regression (frame times of the animation) is measured by
// `tool/performance/android_keyboard.py`.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/perf_lab/fixtures.dart';
import '../integration_test/perf_lab/navigation_host.dart';
import 'flutter_test_config.dart' show leakDebt;

const _prose =
    '代码和相关回归检查已通过，右侧操作复用原播放器，不会另开一份播放状态。独立 Duo 原生包正在编译；设备窗口目前出现空白和绑定超时，我会保留这次失败记录。';

/// Widget types that must not rebuild on a keyboard frame once the system bar
/// padding has settled (only `viewInsets` changes).
const _mustStayQuiet = [
  'WorkspaceView',
  '_MobileWorkspaceContent',
  'RaftMessageTimeline',
  'RaftMessageTile',
  'RaftMessageRow',
  '_RaftMarkdown',
  'RaftConversationTabs',
  'ConversationPanel',
];

void main() {
  leakDebt(const ['_NativePicture']);
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final thread in [false, true]) {
    testWidgets(
      'keyboard frames do not rebuild the ${thread ? 'thread' : 'channel'} page',
      (tester) async {
        // A 2.6x phone with a gesture bar, like the Android reference device.
        tester.view.devicePixelRatio = 2.6;
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.padding = const FakeViewPadding(top: 120, bottom: 63);
        tester.view.viewPadding = const FakeViewPadding(top: 120, bottom: 63);
        addTearDown(tester.view.reset);
        final images = await tester.runAsync(LabImages.start);
        addTearDown(() => images!.server.close(force: true));
        final channel = LabChannel('kb', mixKinds(40));
        final parent = channel.rows.lastWhere(
          (r) => channel.summaries.containsKey(r['id']),
        );
        final threadId = 'thread-${parent['id']}';
        final replies = LabChannel(threadId, [
          for (var i = 0; i < 30; i++) i.isEven ? 'plain' : 'markdown',
        ]);
        for (final c in [channel, replies]) {
          for (var i = 0; i < c.rows.length; i++) {
            if (c.kinds[i] == 'plain') {
              c.rows[i]['content'] = List.filled(4, _prose).join('\n\n');
            }
          }
        }
        final (seed, api, client) = (await tester.runAsync(
          () => labWorkspace(
            [channel, replies],
            images!,
            mobile: true,
            ownsClient: false,
          ),
        ))!;
        seed.dispose();
        api.routes['GET /auth/me'] = (_) => {
          'id': 'alice',
          'name': 'Alice Zhang',
          'email': 'alice@example.invalid',
          'emailVerified': true,
        };
        api.routes['GET /servers'] = (_) => [
          {'id': 's1', 'slug': 'lab', 'name': 'Lab', 'role': 'owner'},
        ];
        api.routes['GET /channels/kb'] = (_) => channel.record.json;
        api.routes['GET /channels/$threadId'] = (_) => replies.record.json;
        api.routes['GET /channels/kb/threads/${parent['id']}'] = (_) => {
          'threadChannelId': threadId,
        };
        api.routes['GET /channels/inbox'] = (_) => {'items': []};
        api.routes['GET /channels/public'] = (_) => [];
        api.routes['GET /announcements/active'] = (_) => {'announcements': []};
        api.routes['GET /servers/unread-summary'] = (_) => [];
        api.routes['GET /product-feedback/tickets'] = (_) => {
          'unread_total': 0,
          'tickets': [],
        };
        SharedPreferences.setMockInitialValues({
          'raft.origin': client.origin,
          'raft.mode': 'light',
        });
        final content = LabNavigationContent();
        await tester.pumpWidget(
          app.RaftApp(
            services: const AppServices.updatesDisabledForTestOrPreview(),
            sessionStore: client.sessionStore,
            createClient: (_, _, _) => client,
            initialLocation: Uri(path: '/s/lab'),
            nativeContent: content,
            nativeSharing: NativeSharing(supported: false),
            openWorkspaceCache: () async => null,
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 2)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
        }

        await settle();
        final WorkspaceController w = content.workspace!;
        await tester.tap(find.text('lab-kb', findRichText: true));
        await settle();
        if (thread) {
          await tester.runAsync(
            () => w.openThreadIdentity(
              parentChannelId: 'kb',
              parentMessageId: '${parent['id']}',
              initialThreadChannelId: threadId,
            ),
          );
          await settle();
        }
        final chat = find.byWidgetPredicate(
          (x) => x is RaftChatView && x.thread == thread,
        );
        final field = find.descendant(
          of: find.descendant(of: chat, matching: find.byType(RaftComposer)),
          matching: find.byType(EditableText),
        );
        expect(field, findsOneWidget);
        expect(
          find.byKey(ValueKey('chat-list-${thread ? 'thread' : 'channel'}')),
          findsOneWidget,
        );
        // Focus the composer like a tap, and give the rows their first frames.
        await tester.tap(field);
        await settle();

        final counts = <String, int>{};
        debugOnRebuildDirtyWidget = (element, builtOnce) => counts.update(
          '${element.widget.runtimeType}',
          (v) => v + 1,
          ifAbsent: () => 1,
        );
        addTearDown(() => debugOnRebuildDirtyWidget = null);
        final report = <String>[];
        var shown = 0;
        var previousPadding = 63.0;
        for (final inset in [30.0, 200.0, 500.0, 700.0, 800.0, 850.0, 860.0]) {
          counts.clear();
          // The engine decodes a new (empty) displayFeatures list on every
          // metrics update; the test view keeps one list unless told so.
          tester.view.displayFeatures = <ui.DisplayFeature>[];
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          // Android: padding = max(0, viewPadding - viewInsets).
          final padding = (63 - inset).clamp(0, 63).toDouble();
          tester.view.padding = FakeViewPadding(top: 120, bottom: padding);
          await tester.pump(const Duration(milliseconds: 16));
          final total = counts.values.fold<int>(0, (a, b) => a + b);
          report.add('inset=$inset padding=$padding rebuilt=$total $counts');
          final settled = padding == 0 && previousPadding == 0;
          previousPadding = padding;
          if (!settled) {
            continue;
          }
          // Only `viewInsets` changed: the shell and the messages stay put.
          shown++;
          for (final type in _mustStayQuiet) {
            expect(
              counts[type] ?? 0,
              0,
              reason: '$type rebuilt at inset $inset\n${report.join('\n')}',
            );
          }
          expect(
            total,
            lessThan(160),
            reason: 'widgets rebuilt at inset $inset\n${report.join('\n')}',
          );
        }
        expect(shown, greaterThan(3));
        debugPrint(report.join('\n'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
