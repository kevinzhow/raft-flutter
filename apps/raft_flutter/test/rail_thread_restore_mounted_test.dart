import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Map<String, dynamic> row(String channel) => {
  'id': 'message-$channel',
  'channelId': channel,
  'seq': '1',
  'senderId': 'alice',
  'senderName': 'Alice',
  'content': 'Actual conversation $channel',
  'createdAt': '2026-10-10T00:00:00Z',
};

void main() {
  for (final folded in [false, true]) {
    testWidgets('actual sidebar switch rejects late thread, fold=$folded', (
      t,
    ) async {
      final f = RootFixture();
      f.overrides['GET /channels'] = (request) => [
        for (final id in ['ca', 'cx'])
          {
            'id': id,
            'serverId': 'a',
            'name': 'general-$id',
            'type': 'channel',
            'joined': true,
            'latestSeq': '1',
          },
      ];
      f.overrides['GET /messages/channel/cx'] = (_) => {
        'messages': [row('cx')],
        'hasMore': false,
      };
      f.overrides['POST /channels/cx/read'] = (_) => {};
      f.overrides['GET /channels/cx/members'] = (_) => [];
      f.overrides['GET /channels/ca/threads/root'] = (_) => {
        'threadChannelId': 'old-thread',
      };
      f.overrides['GET /messages/context/root'] = (_) => {
        'messages': [
          {...row('ca'), 'id': 'root'},
        ],
      };
      f.overrides['GET /messages/channel/old-thread'] = (_) => {'messages': []};
      await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/channel/ca'));
      await f.flush(t);
      final w = f.workspace(t);
      // Record the real Chat rail's remembered location, then leave the mode.
      w.navigation.navigate(
        RaftLocation.parse('/s/alpha/channel/ca?thread=ca:root'),
      );
      w.notifyListeners();
      await f.flush(t);
      await t.tap(find.byKey(const Key('rail-members')));
      await f.flush(t);
      final response = Completer<Map<String, dynamic>>();
      addTearDown(() async {
        if (!response.isCompleted) response.complete({'messages': []});
        await f.close(t);
      });
      f.adapter.routes['GET /messages/channel/ca'] = (_) => response.future;
      final before = f.adapter.calls
          .where((r) => r.path == '/messages/channel/ca')
          .length;
      await t.tap(find.byKey(const Key('rail-chat')));
      await f.flush(t);
      expect(
        f.adapter.calls.where((r) => r.path == '/messages/channel/ca').length,
        greaterThan(before),
      );
      await t.tap(find.byKey(const ValueKey('sidebar-channel-cx')));
      await f.flush(t);
      expect(w.location.entityId, 'cx');
      expect(w.location.thread, isNull);
      if (folded) {
        t.view.physicalSize = const Size(412, 900);
        await f.flush(t);
        expect(find.byType(MobileWorkspacePages), findsOneWidget);
      }
      response.complete({
        'messages': [row('ca')],
        'hasMore': false,
      });
      await f.flush(t);
      await f.flush(t);
      expect(w.location.entityId, 'cx');
      expect(w.location.thread, isNull);
      expect(find.byKey(const Key('workspace-thread-header')), findsNothing);
      expect(find.byType(RaftChatView), findsOneWidget);
      expect(find.textContaining('Actual conversation cx'), findsWidgets);
      expect(find.byType(EditableText), findsWidgets);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
  for (final width in [412.0, 816.0]) {
    testWidgets(
      'cold conversation remains visible through fold/resume at $width',
      (t) async {
        final f = RootFixture();
        final response = Completer<dynamic>();
        f.holds['GET /messages/channel/ca'] = response;
        addTearDown(() async {
          if (!response.isCompleted) {
            response.complete({
              'messages': [row('ca')],
            });
          }
          await f.close(t);
        });
        await f.mount(t, 'light', width, uri: Uri.parse('/s/alpha/channel/ca'));
        await f.flush(t);
        // With no cached workspace a wide cold start can still own the
        // explicit workspace chooser/loading surface. A phone direct page
        // may already show its composer while the tail request is pending.
        if (find.byType(WorkspaceView).evaluate().isNotEmpty) {
          expect(find.byType(RaftChatView), findsOneWidget);
          expect(find.byType(EditableText), findsWidgets);
        } else {
          expect(
            find.byType(GlobalServerSelector).evaluate().isNotEmpty ||
                find.byType(RaftSpinner).evaluate().isNotEmpty,
            isTrue,
          );
        }
        response.complete({
          'messages': [row('ca')],
          'hasMore': false,
        });
        await f.flush(t);
        final w = f.workspace(t);
        expect(w.location.entityId, 'ca');
        expect(find.textContaining('Actual conversation ca'), findsWidgets);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await f.flush(t);
        for (final next in [width == 412 ? 816.0 : 412.0, width]) {
          t.view.physicalSize = Size(next, 900);
          await f.flush(t);
          expect(w.location.entityId, 'ca');
          expect(find.byType(RaftChatView), findsOneWidget);
          expect(find.textContaining('Actual conversation ca'), findsWidgets);
          expect(find.byType(EditableText), findsWidgets);
          expect(t.takeException(), isNull);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
