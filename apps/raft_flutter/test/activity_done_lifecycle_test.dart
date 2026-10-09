import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_follow_ack_test.dart' show Client, Workspace, thread;

Map<String, dynamic> doneThread({String authoritySeq = '12'}) => {
  ...thread(),
  'doneFrontierSeq': '12',
  'latestActivitySeq': '999',
  'readState': {
    'kind': 'present',
    'maxReadSeq': '0',
    'readStateVersion': 1,
    'latestActivity': {'messageId': 'reply', 'seq': authoritySeq},
  },
};

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    late Client client;
    late Workspace workspace;
    setUp(() {
      client = Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s');
      workspace = Workspace(client)
        ..row = doneThread()
        ..server = RaftRecord({'id': 's', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'channel', 'name': 'General', 'joined': true}),
        ];
    });
    tearDown(() async {
      workspace.dispose();
      await client.dispose();
    });
    Future<dynamic> mount(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(theme.$1, dark: theme.$2),
          home: Scaffold(
            body: ResourceView(
              controller: workspace,
              section: 'activity',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state(find.byType(ResourceView));
    }

    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} held pre-intent read cannot restore the row after newer ACK reconciliation',
      (tester) async {
        final dynamic state = await mount(tester);
        final stale = Completer<dynamic>();
        // Source-owned page still retains its active row while a background read is in flight.
        workspace.inbox = stale;
        final Future<void> oldRead = state.load(append: true);
        await tester.pump();
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        workspace.inbox = null;
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        stale.complete({
          'items': [doneThread()],
          'totalCount': 1,
          'totalUnreadCount': 3,
        });
        await oldRead;
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} failed ACK refresh shows the actual error and retires its bridge before retry',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        final failed = Completer<dynamic>();
        workspace.inbox = failed;
        client.pending.single.complete({});
        await tester.pump();
        failed.completeError(
          const RaftApiException('Refresh failed', status: 500),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Refresh failed'), findsOneWidget);
        workspace.inbox = null;
        await state.load();
        await tester.pumpAndSettle();
        expect(state.rows, hasLength(1));
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} first owned refresh stays armed until acceptance then retires suppression',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        final held = Completer<dynamic>();
        workspace.inbox = held;
        client.pending.single.complete({});
        await tester.pump();
        expect(state.rows, isEmpty);
        held.complete({
          'items': [doneThread()],
          'totalCount': 1,
          'totalUnreadCount': 3,
        });
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        workspace.inbox = null;
        await state.load();
        await tester.pumpAndSettle();
        expect(
          state.rows,
          hasLength(1),
          reason: 'Source retires the bridge after its owned refresh; it is not a permanent fabricated Done fact.',
        );
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} newer authority activity bypasses suppression while POST is pending and after ACK',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        workspace.row = doneThread(authoritySeq: '13');
        await state.load();
        await tester.pumpAndSettle();
        expect(state.rows, hasLength(1));
        expect((state.rows.single as Map)['latestActivitySeq'], '999');
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect(state.rows, hasLength(1));
        expect(state.totalUnreadCount, 3);
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} failed persistence restores canonical row and unread through reconciliation',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        client.pending.single.completeError(
          const RaftApiException('Persistence failed', status: 500),
        );
        await tester.pumpAndSettle();
        expect(state.rows, hasLength(1));
        expect(state.totalUnreadCount, 3);
        expect(find.byType(RaftConversationCard), findsOneWidget);
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} principal change rejects late success and old refresh effects',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        client.user = RaftRecord({'id': 'bob'});
        workspace.notifyListeners();
        await tester.pumpAndSettle();
        final before = workspace.inboxRequests;
        expect(state.rows, hasLength(1));
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect(workspace.inboxRequests, before);
        expect(state.rows, hasLength(1));
        expect(state.totalUnreadCount, 3);
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} denied persistence retires rows and never accepts optimistic success',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        client.pending.single.completeError(
          const RaftApiException('Denied', status: 403),
        );
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        expect(state.totalUnreadCount, isNull);
        expect(find.textContaining('Denied'), findsOneWidget);
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} old success cannot clear the newer Done generation or drive its refresh',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        workspace.row = {
          ...doneThread(authoritySeq: '13'),
          'doneFrontierSeq': '13',
        };
        await state.load();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        final before = workspace.inboxRequests;
        client.pending[0].complete({});
        await tester.pumpAndSettle();
        expect(workspace.inboxRequests, before);
        expect(state.rows, isEmpty);
        expect(client.posts[1].data, {
          'threadChannelId': 'thread',
          'throughActivitySeq': '13',
          'frontierSpace': 'storage',
        });
        client.pending[1].complete({});
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        expect(workspace.inboxRequests, before + 1);
      },
    );
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} legacy server omits sequence and never sends display units',
      (tester) async {
        workspace.row.remove('doneFrontierSeq');
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        expect(client.posts.single.data, {'threadChannelId': 'thread'});
        expect(state.rows, isEmpty);
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
      },
    );
    for (final kind in ['channel', 'dm']) {
      testWidgets(
        '[Activity Done] ${theme.$1}/${theme.$2} $kind uses inbox Done with their accepted storage frontier',
        (tester) async {
          workspace.row = {
            ...doneThread(),
            'kind': kind,
            'channelId': 'channel',
          };
          final dynamic state = await mount(tester);
          await tester.tap(find.byTooltip('Mark conversation done'));
          await tester.pumpAndSettle();
          expect(client.posts.single.path, '/channels/inbox/done');
          expect(client.posts.single.data, {
            'channelId': 'channel',
            'throughActivitySeq': '12',
            'frontierSpace': 'storage',
          });
          expect(workspace.unread['channel'], 0);
          client.pending.single.complete({});
          await tester.pumpAndSettle();
          expect(state.rows, isEmpty);
        },
      );
    }
    testWidgets(
      '[Activity Done] ${theme.$1}/${theme.$2} intent removes exact row before POST and stale ACK refresh stays removed',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(find.byTooltip('Mark conversation done'));
        await tester.pumpAndSettle();
        expect(client.posts.single.path, '/channels/threads/done');
        expect(client.posts.single.data, {
          'threadChannelId': 'thread',
          'throughActivitySeq': '12',
          'frontierSpace': 'storage',
        });
        expect(
          state.rows,
          isEmpty,
          reason:
              'Source removes the accepted row at intent, before persistence.',
        );
        expect(state.totalUnreadCount, 0);
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect(workspace.inboxRequests, 2);
        expect(
          state.rows,
          isEmpty,
          reason: 'The first ACK refresh is projected while its exact authority marker remains armed.',
        );
        expect(find.byType(RaftConversationCard), findsNothing);
      },
    );
  }
}
