import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show fixture, MessageAdapter;
import 'workspace_activity_activation_test.dart'
    show threadRow, channelRow, message;

Future<void> _dispatch(WidgetTester tester, {VoidCallback? afterFrame}) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(Duration.zero);
    afterFrame?.call();
  }
}

class _MountedActivity {
  _MountedActivity(this.workspace, this.api, this.main);
  final WorkspaceController workspace;
  final MessageAdapter api;
  final RaftChannel main;
  final parent = Completer<dynamic>(), replies = Completer<dynamic>();
  final observed = <RaftLocation>[];
  void _observe() => observed.add(workspace.location);
  int get oldReads =>
      api.calls.where((r) => r.path == '/channels/thread-1/read').length;

  static Future<_MountedActivity> mount(
    WidgetTester tester,
    RaftFamily family,
    bool dark,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('member')))!;
    final main = RaftChannel({
      'id': 'unrelated',
      'name': 'Retained main',
      'joined': true,
    });
    w.channels = [w.channel!, main];
    w.channel = main;
    w.ledger.switchServer('s1');
    w.ledger.ingest([
      message('old-main', main.id),
    ], expectedGeneration: w.ledger.generation);
    w.visibleIds[main.id] = {'old-main'};
    w.loading = false;
    w.setSection('activity');
    final page = _MountedActivity(w, api, main);
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [threadRow, channelRow],
    };
    api.routes['GET /messages/context/parent'] = (_) => page.parent.future;
    api.routes['GET /messages/context/reply'] = (_) => page.replies.future;
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 'thread-1',
    };
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/unread'] = (_) => {'channels': <String, int>{}};
    api.routes['POST /channels/thread-1/read'] = (_) => {
      'maxReadSeq': '1',
      'readStateVersion': '1',
    };
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('activity-thread-thread-1')),
      findsOneWidget,
    );
    w.addListener(page._observe);
    return page;
  }

  void assertThreadFirstFrame(WidgetTester tester) {
    expect(workspace.location.route, RaftRoute.activity);
    expect(workspace.location.content?.kind, RaftContentKind.thread);
    expect(workspace.location.content?.id, 'thread-1');
    expect(workspace.location.thread?.channelId, 'c1');
    expect(workspace.location.thread?.itemId, 'parent');
    expect(workspace.threadIdentity?.parentMessageId, 'parent');
    expect(workspace.presentedThreadParent, isNull);
    expect(workspace.channel?.id, main.id);
    expect(workspace.messages.map((row) => row.id), ['old-main']);
    expect(find.byType(RaftThreadHeader), findsOneWidget);
    expect(
      tester
          .widget<RaftThreadHeader>(find.byType(RaftThreadHeader))
          .parentLabel,
      '#test',
    );
    expect(find.byType(RaftChatView), findsOneWidget);
    expect(tester.widget<RaftChatView>(find.byType(RaftChatView)).thread, true);
    expect(find.byKey(const Key('workspace-channel-header')), findsNothing);
    expect(paintedMessage(tester, 'old-main'), isNull);
    assertNoChannelDetour();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('activity-thread-thread-1')));
  }

  Future<void> reachFirstThreadFrame(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 219));
    expect(workspace.location.content, isNull);
    expect(workspace.threadIdentity, isNull);
    expect(
      api.calls.where((r) => r.path.startsWith('/messages/context/')),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 1));
    // Assert the actual 220ms timer frame itself, before another dispatch or
    // 16ms frame can conceal a transient parent-channel presentation.
    assertThreadFirstFrame(tester);
    await _dispatch(tester);
    for (final pair in [
      ('/messages/context/parent', 'c1'),
      ('/messages/context/reply', 'thread-1'),
    ]) {
      final request = api.calls.where((r) => r.path == pair.$1).single;
      expect(request.queryParameters['channelId'], pair.$2);
    }
    expect(
      api.calls.where((r) => r.path == '/channels/c1/threads/parent'),
      isEmpty,
    );
  }

  void retire(String authority) {
    api.routes['GET /channels/inbox'] = (_) => {'items': []};
    if (authority == 'principal') {
      // Accepted identity-state replacement, not a simulated login/logout
      // workflow. The actual mounted page and real pending transport remain.
      workspace.client.user = RaftRecord({'id': 'bob'});
    } else {
      workspace.client.selectServer('s2');
      workspace.server = RaftRecord({'id': 's2', 'role': 'member'});
    }
    workspace.notifyListeners();
  }

  void assertNoPrivatePaint(WidgetTester tester) {
    expect(paintedMessage(tester, 'reply'), isNull);
    expect(find.byKey(const ValueKey('message-parent')), findsNothing);
    expect(find.text('Private late parent'), findsNothing);
    expect(workspace.presentedThreadParent, isNull);
    expect(workspace.threadIdentity, isNull);
    expect(
      tester
          .widgetList<RaftChatView>(find.byType(RaftChatView))
          .every((view) => view.thread),
      true,
    );
    assertNoChannelDetour();
  }

  void assertNoChannelDetour() {
    expect(
      observed.every(
        (location) =>
            !{RaftRoute.channel, RaftRoute.dm}.contains(location.route),
      ),
      true,
    );
    expect(
      observed.every(
        (location) =>
            location.content == null ||
            (location.content?.kind == RaftContentKind.thread &&
                location.content?.id == 'thread-1'),
      ),
      true,
    );
  }

  Future<void> close(WidgetTester tester) async {
    workspace.removeListener(_observe);
    await tester.pumpWidget(const SizedBox.shrink());
    workspace.dispose();
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final authority in ['principal', 'server']) {
      for (final pending in [false, true]) {
        testWidgets(
          '[K07] $family/$dark actual row input retires $authority ${pending ? 'after the 220ms first thread frame' : 'before the 220ms activation'} without private late paint',
          (tester) async {
            final page = await _MountedActivity.mount(tester, family, dark);
            try {
              await page.open(tester);
              if (pending) {
                await page.reachFirstThreadFrame(tester);
                for (var frame = 0; frame < 4; frame++) {
                  await tester.pump(const Duration(milliseconds: 16));
                  page.assertThreadFirstFrame(tester);
                }
              } else {
                await tester.pump(const Duration(milliseconds: 120));
                expect(page.workspace.location.content, isNull);
              }
              page.retire(authority);
              await _dispatch(
                tester,
                afterFrame: () => page.assertNoPrivatePaint(tester),
              );
              final reads = page.oldReads;
              if (pending) {
                page.replies.complete({
                  'messages': [message('reply', 'thread-1')],
                });
                page.parent.complete({
                  'messages': [
                    {
                      ...message('parent', 'c1'),
                      'content': 'Private late parent',
                    },
                  ],
                });
              }
              for (var frame = 0; frame < 16; frame++) {
                await tester.pump(const Duration(milliseconds: 16));
                page.assertNoPrivatePaint(tester);
                expect(page.oldReads, reads);
              }
              if (!pending) {
                // Timer expiry in the retired authority must not launch either
                // old context request, even though the original input was real.
                expect(
                  page.api.calls.where(
                    (r) => r.path.startsWith('/messages/context/'),
                  ),
                  isEmpty,
                );
                expect(find.byType(RaftThreadHeader), findsNothing);
              }
              expect(tester.takeException(), isNull);
            } finally {
              await page.close(tester);
            }
          },
        );
      }
    }
    testWidgets(
      '[K07] $family/$dark actual thread row and painted reply retire on accepted parent-channel revocation while parent HTTP waits',
      (tester) async {
        final page = await _MountedActivity.mount(tester, family, dark);
        try {
          await page.open(tester);
          await page.reachFirstThreadFrame(tester);
          page.replies.complete({
            'messages': [message('reply', 'thread-1')],
          });
          await _dispatch(tester);
          for (
            var frame = 0;
            frame < 20 && paintedMessage(tester, 'reply') == null;
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(paintedMessage(tester, 'reply'), isNotNull);
          expect(page.workspace.threadParentLoading, true);
          expect(page.workspace.presentedThreadParent, isNull);
          final reads = page.oldReads;
          page.api.routes['GET /channels'] = (_) => [page.main.json];
          page.api.routes['GET /channels/dm'] = (_) => [];
          page.api.routes['GET /channels/inbox'] = (_) => {'items': []};
          final refreshed = page.workspace.refreshChannels();
          await _dispatch(
            tester,
            afterFrame: () {
              // Frames before the held list is accepted still belong to the old
              // authority. From its actual acceptance frame, none may paint it.
              if (!page.workspace.channels.any((row) => row.id == 'c1')) {
                page.assertNoPrivatePaint(tester);
                expect(page.oldReads, reads);
              }
            },
          );
          await refreshed;
          await tester.pump();
          page.assertNoPrivatePaint(tester);
          expect(page.workspace.channel?.id, page.main.id);
          expect(page.workspace.messages.map((row) => row.id), ['old-main']);
          expect(page.workspace.ledger.messages('thread-1'), isEmpty);
          page.parent.complete({
            'messages': [
              {...message('parent', 'c1'), 'content': 'Private late parent'},
            ],
          });
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            page.assertNoPrivatePaint(tester);
            expect(page.oldReads, reads);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await page.close(tester);
        }
      },
    );
  }
}
