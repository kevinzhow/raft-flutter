import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> thread({bool following = true, int unread = 3}) => {
  'kind': 'thread',
  'threadChannelId': 'thread',
  'parentChannelId': 'channel',
  'parentChannelName': 'General',
  'parentMessageId': 'parent',
  'parentContent': 'Retained parent',
  'parentSenderName': 'Alice',
  'parentSenderType': 'user',
  'parentSenderId': 'alice',
  'latestActivityMessageId': 'reply',
  'latestActivitySeq': '10',
  'latestActivityPreview': 'Retained reply',
  'latestActivitySenderType': 'user',
  'latestActivitySenderId': 'alice',
  'latestActivitySenderName': 'Alice',
  'lastReplyAt': '2026-10-10T01:00:00Z',
  'replyCount': 2,
  'unreadCount': unread,
  'firstUnreadMessageId': unread > 0 ? 'reply' : null,
  'hasMention': unread > 0,
  'isFollowing': following,
};

class Client extends RaftClient {
  Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final posts = <({String path, dynamic data})>[];
  final pending = <Completer<dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) {
    posts.add((path: path, data: data));
    final response = Completer<dynamic>();
    pending.add(response);
    return response.future;
  }
}

class Workspace extends WorkspaceController {
  Workspace(super.client);
  Map<String, dynamic> row = thread();
  Completer<dynamic>? inbox;
  int inboxRequests = 0;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents' || path.endsWith('/members')) return [];
    inboxRequests++;
    return inbox?.future ??
        {
          'items': [Map<String, dynamic>.of(row)],
          'totalCount': 1,
          'totalUnreadCount': row['unreadCount'],
          'hasMore': false,
        };
  }
}

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    late Client client;
    late Workspace workspace;
    final acceptedWindows = <Map?>[];
    setUp(() {
      acceptedWindows.clear();
      client = Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s');
      workspace = Workspace(client)
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
              onActivityWindowAccepted: acceptedWindows.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state(find.byType(ResourceView));
    }

    Future<void> action(WidgetTester tester, String label) async {
      await tester.tap(
        find.byType(RaftConversationCard),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RaftMenuItem, label));
      await tester.pumpAndSettle();
    }

    testWidgets(
      '[N24g] ${theme.$1}/${theme.$2} Unfollow ACK fences a held prior read and overlays a later stale read until convergence',
      (tester) async {
        final dynamic state = await mount(tester);
        await action(tester, 'Unfollow');
        final held = Completer<dynamic>();
        workspace.inbox = held;
        final Future<void> oldRead = state.load();
        await tester.pump();
        expect(find.byType(RaftConversationCard), findsOneWidget);
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], false);
        held.complete({
          'items': [thread()],
          'totalUnreadCount': 3,
          'hasMore': false,
        });
        await oldRead;
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], false);
        expect(state.totalUnreadCount, 0);
        workspace.inbox = null;
        await state.load();
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], false);
        expect((state.rows.single as Map)['unreadCount'], 0);
        workspace.row = thread(following: false, unread: 0);
        await state.load();
        await tester.pumpAndSettle();
        // A later authoritative refollow is accepted after convergence.
        workspace.row = thread(following: true, unread: 0);
        await state.load();
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], true);
      },
    );
    testWidgets(
      '[N24g] ${theme.$1}/${theme.$2} Follow ACK exposes Unfollow without resurrecting cleared unread from a stale response',
      (tester) async {
        final dynamic state = await mount(tester);
        await action(tester, 'Unfollow');
        client.pending[0].complete({});
        await tester.pumpAndSettle();
        await action(tester, 'Follow');
        expect(client.posts[1].path, '/channels/threads/follow');
        expect(client.posts[1].data, {'parentMessageId': 'parent'});
        client.pending[1].complete({});
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], true);
        expect((state.rows.single as Map)['unreadCount'], 0);
        workspace.row = thread(following: false);
        await state.load();
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], true);
        expect((state.rows.single as Map)['unreadCount'], 0);
        await tester.tap(
          find.byType(RaftConversationCard),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(RaftMenuItem, 'Unfollow'), findsOneWidget);
      },
    );
    testWidgets(
      '[N24g] ${theme.$1}/${theme.$2} failed Unfollow preserves canonical state and reconciles instead of accepting success',
      (tester) async {
        final dynamic state = await mount(tester);
        await action(tester, 'Unfollow');
        client.pending.single.completeError(
          const RaftApiException('Failed', status: 500),
        );
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], true);
        expect((state.rows.single as Map)['unreadCount'], 3);
        expect(workspace.inboxRequests, 2);
      },
    );
    testWidgets(
      '[N24g] ${theme.$1}/${theme.$2} principal change retires late ACK and the old menu handler',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(
          find.byType(RaftConversationCard),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        final oldHandler = tester
            .widget<RaftMenuItem>(find.widgetWithText(RaftMenuItem, 'Unfollow'))
            .onPressed;
        await tester.tap(find.widgetWithText(RaftMenuItem, 'Unfollow'));
        await tester.pumpAndSettle();
        client.user = RaftRecord({'id': 'bob'});
        workspace.notifyListeners();
        await tester.pumpAndSettle();
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], true);
        expect((state.rows.single as Map)['unreadCount'], 3);
        oldHandler!();
        await tester.pumpAndSettle();
        expect(client.posts, hasLength(1));
      },
    );
    testWidgets(
      '[N24g] ${theme.$1}/${theme.$2} denied Unfollow retires accepted Activity rows',
      (tester) async {
        final dynamic state = await mount(tester);
        await action(tester, 'Unfollow');
        client.pending.single.completeError(
          const RaftApiException('Denied', status: 403),
        );
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        expect(find.byType(RaftConversationCard), findsNothing);
        expect(find.textContaining('Denied'), findsOneWidget);
      },
    );
    testWidgets(
      '[N24g] ${theme.$1}/${theme.$2} Unfollow ACK retains row and exposes Follow before stale inbox read',
      (tester) async {
        final dynamic state = await mount(tester);
        await action(tester, 'Unfollow');
        expect(client.posts.single.path, '/channels/threads/unfollow');
        expect(
          (state.rows.single as Map)['isFollowing'],
          true,
          reason: 'No success before POST acknowledgement.',
        );
        client.pending.single.complete({});
        await tester.pumpAndSettle();
        expect((state.rows.single as Map)['isFollowing'], false);
        expect((state.rows.single as Map)['unreadCount'], 0);
        expect(state.totalUnreadCount, 0);
        expect(acceptedWindows.last?['totalUnreadCount'], 0);
        expect(
          ((acceptedWindows.last?['items'] as List).single
              as Map)['isFollowing'],
          false,
        );
        expect(
          workspace.inboxRequests,
          1,
          reason: 'Source success preserves the acknowledged row without an immediate stale reload.',
        );
        await tester.tap(
          find.byType(RaftConversationCard),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(RaftMenuItem, 'Follow'), findsOneWidget);
        expect(find.widgetWithText(RaftMenuItem, 'Unfollow'), findsNothing);
      },
    );
  }
}
