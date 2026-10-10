import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

/// Server-side Activity rows: newest first, one per channel.
Map<String, dynamic> channelRow(int i, {int unread = 0, int? seq}) => {
  'kind': 'channel',
  'channelId': 'ch$i',
  'channelName': 'Channel $i',
  'channelType': i == 7 ? 'private' : 'channel',
  'lastMessageId': 'm$i',
  'lastMessageAt': '2026-10-10T00:00:00Z',
  'lastMessagePreview': 'Preview $i',
  'lastMessageSenderType': 'user',
  'lastMessageSenderId': 'bob',
  'lastMessageSenderName': 'Bob',
  'latestActivitySeq': '${seq ?? 1000 - i}',
  'doneFrontierSeq': '${seq ?? 1000 - i}',
  'unreadCount': unread,
  'firstUnreadMessageId': unread > 0 ? 'm$i' : null,
  'firstMentionMessageId': null,
  'hasMention': false,
};

class ActivityClient extends RaftClient {
  ActivityClient()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  final posts = <String>[];
  final bodies = <dynamic>[];
  @override
  Stream<RaftEvent> get events => ingress.stream;
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
  }) async {
    if (path == '/auth/login') {
      return {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      };
    }
    posts.add('$method $path');
    bodies.add(data);
    return <String, dynamic>{};
  }

  void emit(String name, Object? payload) => ingress.add(RaftEvent(name, payload));

  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

class ActivityWorkspace extends WorkspaceController {
  ActivityWorkspace(super.client);
  List<Map<String, dynamic>> inbox = [
    for (var i = 0; i < 60; i++) channelRow(i, unread: i == 3 ? 2 : 0),
  ];
  final inboxQueries = <Map<String, dynamic>>[];
  final savedQueries = <Map<String, dynamic>>[];
  final searchQueries = <Map<String, dynamic>>[];
  int agentQueries = 0;
  List<Map<String, dynamic>> saved = [
    for (var i = 0; i < 30; i++)
      {
        'messageId': 'saved$i',
        'channelId': 'ch${i % 10}',
        'channelName': 'Channel ${i % 10}',
        'channelType': 'channel',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': 'Saved body $i',
        'createdAt': '2026-10-10T00:00:00Z',
      },
  ];
  Completer<void>? hold;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') {
      agentQueries++;
      return [
        {'id': 'a1', 'name': 'helper', 'displayName': 'Helper'},
      ];
    }
    if (path.endsWith('/members')) return [];
    if (path == '/messages/search') {
      searchQueries.add({...?query});
      return {
        'results': [
          for (var i = 0; i < 5; i++)
            {
              'id': 'hit$i',
              'channelId': 'ch$i',
              'channelName': 'Channel $i',
              'channelType': 'channel',
              'senderId': 'bob',
              'senderType': 'user',
              'senderName': 'Bob',
              'content': 'Search body $i',
              'createdAt': '2026-10-10T00:00:00Z',
            },
        ],
        'hasMore': false,
      };
    }
    if (path == '/channels/saved') {
      final offset = query?['offset'] as int? ?? 0,
          limit = query?['limit'] as int? ?? 20;
      savedQueries.add({...?query});
      final gate = hold;
      if (gate != null) await gate.future;
      final page = saved.skip(offset).take(limit).toList();
      return {
        'saved': [for (final row in page) Map<String, dynamic>.of(row)],
        'total': saved.length,
        'hasMore': offset + page.length < saved.length,
      };
    }
    if (path != '/channels/inbox') return {'items': [], 'hasMore': false};
    final params = {...?query};
    inboxQueries.add(params);
    final gate = hold;
    if (gate != null) await gate.future;
    final offset = params['offset'] as int? ?? 0,
        limit = params['limit'] as int? ?? 30;
    final page = inbox.skip(offset).take(limit).toList();
    return {
      'items': [for (final row in page) Map<String, dynamic>.of(row)],
      'totalCount': inbox.length,
      'totalUnreadCount': inbox.fold<int>(
        0,
        (sum, row) => sum + (row['unreadCount'] as int),
      ),
      'hasMore': offset + page.length < inbox.length,
    };
  }
}

(ActivityClient, ActivityWorkspace) activityFixture() {
  final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
  client.selectServer('s1');
  final w = ActivityWorkspace(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'})
    ..channels = [
      for (var i = 0; i < 60; i++)
        RaftChannel({
          'id': 'ch$i',
          'name': 'Channel $i',
          'joined': true,
          if (i == 7) 'isPrivate': true,
        }),
    ];
  return (client, w);
}

/// Activity titles and previews are rich text after an inline icon/sender.
Finder shown(String text) => find.textContaining(
  RegExp('${RegExp.escape(text)}\$'),
  findRichText: true,
);

Finder get skeleton => find.byWidgetPredicate(
  (widget) =>
      widget is RaftActivityLoadingList || widget is CircularProgressIndicator,
);

ScrollableState activityScroll(WidgetTester tester) => tester.state(
  find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first,
);

void main() {
  for (final enabled in [false, true]) {
    final label = enabled ? 'sidebar' : 'legacy';
    late ActivityClient client;
    late ActivityWorkspace w;
    setUp(() => (client, w) = activityFixture());
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<dynamic> mount(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'activity',
              activitySidebarEnabled: enabled,
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state(find.byType(ResourceView));
    }

    testWidgets(
      '[$label] socket refresh keeps populated rows on screen while the reconcile is pending',
      (tester) async {
        final dynamic state = await mount(tester);
        expect(shown('Channel 0'), findsOneWidget);
        final before = w.inboxQueries.length;
        w.hold = Completer<void>();
        client.emit('message:updated', {'id': 'mX', 'channelId': 'ch40'});
        await tester.pump(const Duration(milliseconds: 149));
        expect(w.inboxQueries, hasLength(before));
        await tester.pump(const Duration(milliseconds: 1));
        expect(w.inboxQueries, hasLength(before + 1));
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(skeleton, findsNothing);
          expect(shown('Channel 0'), findsOneWidget);
          expect(state.loading, isFalse);
        }
        w.inbox[0] = {...w.inbox[0], 'lastMessagePreview': 'Edited 0'};
        w.hold!.complete();
        w.hold = null;
        await tester.pump();
        await tester.pump();
        expect(skeleton, findsNothing);
        expect(shown('Edited 0'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '[$label] loaded pages and scroll position survive a socket reconcile',
      (tester) async {
        final dynamic state = await mount(tester);
        expect(state.rows, hasLength(30));
        await state.load(append: true);
        await tester.pumpAndSettle();
        expect(state.rows, hasLength(60));
        final scroll = activityScroll(tester);
        scroll.position.jumpTo(1500);
        await tester.pump();
        final offset = scroll.position.pixels;
        expect(offset, 1500);
        final unchanged = state.rows[20];
        client.emit('thread:updated', {'threadChannelId': 'elsewhere'});
        await tester.pump(const Duration(milliseconds: 150));
        // Source requestLimit spans the loaded window, not the first page.
        expect(w.inboxQueries.last['limit'], 60);
        expect(w.inboxQueries.last['offset'], 0);
        await tester.pumpAndSettle();
        expect(state.rows, hasLength(60));
        expect(identical(activityScroll(tester), scroll), isTrue);
        expect(scroll.position.pixels, offset);
        expect(identical(state.rows[20], unchanged), isTrue);
        expect(state.hasMore, isFalse);
      },
    );

    testWidgets(
      '[$label] live message advances its row in place before the reconcile and reconcile keeps it',
      (tester) async {
        final dynamic state = await mount(tester);
        final untouched = state.rows[1];
        w.hold = Completer<void>();
        client.emit('message:new', {
          'id': 'live',
          'channelId': 'ch5',
          'seq': 2000,
          'content': 'Live preview',
          'senderId': 'carol',
          'senderType': 'user',
          'senderName': 'Carol',
          'createdAt': '2026-10-10T01:00:00Z',
        });
        await tester.pump();
        // Patched synchronously: the conversation moved to the top.
        expect(state.rows.first['channelId'], 'ch5');
        expect(state.rows.first['lastMessagePreview'], 'Live preview');
        expect(shown('Live preview'), findsOneWidget);
        expect(identical(state.rows[2], untouched), isTrue);
        await tester.pump(const Duration(milliseconds: 150));
        // A response that predates the live message cannot regress the row.
        w.hold!.complete();
        w.hold = null;
        await tester.pumpAndSettle();
        expect(state.rows.first['channelId'], 'ch5');
        expect(state.rows.first['lastMessagePreview'], 'Live preview');
        expect(
          state.rows.where((r) => r['channelId'] == 'ch5'),
          hasLength(1),
        );
        expect(identical(state.rows[2], untouched), isTrue);
        // Once the server catches up its row is accepted.
        w.inbox
          ..removeAt(5)
          ..insert(0, {
            ...channelRow(5, seq: 2000),
            'lastMessagePreview': 'Server preview',
          });
        client.emit('message:updated', {'id': 'live', 'channelId': 'ch5'});
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(state.rows.first['lastMessagePreview'], 'Server preview');
      },
    );

    testWidgets('[$label] read state clears a fully read row locally', (
      tester,
    ) async {
      final dynamic state = await mount(tester);
      expect(state.rows[3]['unreadCount'], 2);
      expect(state.totalUnreadCount, 2);
      w.hold = Completer<void>();
      client.emit('read_state:updated', {
        'serverId': 's1',
        'scopeId': 'ch3',
        'maxReadSeq': 997,
        'readStateVersion': 1,
      });
      await tester.pump();
      expect(state.rows[3]['unreadCount'], 0);
      expect(state.totalUnreadCount, 0);
      await tester.pump(const Duration(milliseconds: 150));
      // A lagging server window cannot resurrect the read unread count.
      w.hold!.complete();
      w.hold = null;
      await tester.pumpAndSettle();
      expect(state.rows[3]['unreadCount'], 0);
      expect(state.totalUnreadCount, 0);
    });

    testWidgets(
      '[$label] a context menu opened before a row update still acts on that conversation',
      (tester) async {
        final dynamic state = await mount(tester);
        await tester.tap(
          find.ancestor(of: shown('Channel 1'), matching: find.byType(RaftConversationCard)),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        client.emit('message:new', {
          'id': 'live',
          'channelId': 'ch1',
          'seq': 3000,
          'content': 'Newer',
          'senderId': 'bob',
          'senderType': 'user',
        });
        await tester.pump();
        expect(state.rows.first['lastMessagePreview'], 'Newer');
        await tester.tap(find.widgetWithText(RaftMenuItem, 'Done'));
        await tester.pumpAndSettle();
        final done = client.posts.indexOf('POST /channels/inbox/done');
        expect(done, isNot(-1));
        expect(client.bodies[done]['channelId'], 'ch1');
      },
    );

    testWidgets(
      '[$label] permission loss removes only that channel; benign updates keep rows',
      (tester) async {
        final dynamic state = await mount(tester);
        final scroll = activityScroll(tester);
        scroll.position.jumpTo(200);
        await tester.pump();
        final kept = state.rows[0];
        w.hold = Completer<void>();
        client.emit('channel:updated', {'id': 'ch2'});
        await tester.pump();
        expect(state.rows, hasLength(30));
        expect(skeleton, findsNothing);
        client.emit('channel:members-updated', {'channelId': 'ch7'});
        await tester.pump();
        // Private conversation fails closed before the directory refresh.
        expect(state.rows.where((r) => r['channelId'] == 'ch7'), isEmpty);
        expect(state.rows, hasLength(29));
        expect(identical(state.rows[0], kept), isTrue);
        expect(skeleton, findsNothing);
        expect(scroll.position.pixels, 200);
        // A public channel's membership change cannot hide other rows.
        client.emit('channel:members-updated', {'channelId': 'ch8'});
        await tester.pump();
        expect(state.rows.where((r) => r['channelId'] == 'ch8'), hasLength(1));
        // Directory loss of a public channel removes its row as well.
        w.channels = w.channels.where((c) => c.id != 'ch9').toList();
        w.notifyListeners();
        await tester.pump();
        expect(state.rows.where((r) => r['channelId'] == 'ch9'), isEmpty);
        w.inbox.removeWhere((r) => ['ch7', 'ch9'].contains(r['channelId']));
        w.hold!.complete();
        w.hold = null;
        await tester.pumpAndSettle();
        expect(state.rows.where((r) => r['channelId'] == 'ch7'), isEmpty);
        expect(identical(state.rows[0], kept), isTrue);
        // A principal/role change still retires every accepted row.
        w.hold = Completer<void>();
        w.inbox = [];
        w.server = RaftRecord({
          'id': 's1',
          'role': 'member',
        });
        w.notifyListeners();
        await tester.pump();
        expect(state.rows, isEmpty);
        w.hold!.complete();
        await tester.pumpAndSettle();
      },
    );
  }
}
