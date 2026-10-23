import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/thread_unread_by_parent.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'support/app_services_fixture.dart';

Map<String, dynamic> _thread(
  String id,
  String parent, {
  int unread = 1,
  bool mention = false,
  String? parentAt,
  String? lastReplyAt,
}) => {
  'threadChannelId': 't-$id',
  'parentMessageId': 'p-$id',
  'parentChannelId': parent,
  'unreadCount': unread,
  'hasMention': mention,
  'parentMessageCreatedAt': ?parentAt,
  'lastReplyAt': ?lastReplyAt,
};

/// Answers the conversation-read-all request with a refusal, like a server
/// whose `sidebar_mark_all_read_v0` is off.
class _Refusing implements HttpClientAdapter {
  _Refusing(this.inner);
  final HttpClientAdapter inner;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) {
    if (o.path.endsWith('/conversation-read-all')) {
      return Future.value(
        ResponseBody.fromString(
          jsonEncode({
            'error': 'Conversation read-all is not enabled',
            'code': 'sidebar_mark_all_read_disabled',
          }),
          404,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
    }
    return inner.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// Web v1.21.23 `thread_unread_badge_v0` and `sidebar_mark_all_read_v0`:
/// followed-thread unread rolls up onto the parent channel's sidebar row, and
/// the channel menu's "Mark All as Read" reads the channel with its threads.
void main() {
  group('roll-up of the followed threads', () {
    test('counts threads, not replies, and folds the @ mark per channel', () {
      final byParent = groupThreadUnreadByParent([
        _thread('a', 'c1', unread: 7),
        _thread('b', 'c1', mention: true),
        _thread('c', 'c2', unread: 0, mention: true),
        _thread('d', 'c2', unread: 3),
      ]);
      expect(byParent['c1'], const ParentThreadUnread(2, true));
      expect(byParent['c2'], const ParentThreadUnread(1, false));
      expect(byParent['c3'], isNull);
    });

    test('jump order is top to bottom by parent time; no mention priority', () {
      final ordered = orderParentUnreadThreadsForJump([
        _thread('late', 'c1', parentAt: '2026-10-02T00:00:00Z'),
        _thread(
          'mention',
          'c1',
          mention: true,
          parentAt: '2026-10-03T00:00:00Z',
        ),
        _thread('early', 'c1', parentAt: '2026-10-01T00:00:00Z'),
        _thread('read', 'c1', unread: 0, parentAt: '2026-09-01T00:00:00Z'),
        _thread('other', 'c2', parentAt: '2026-08-01T00:00:00Z'),
        // An older server sends no parent time: the latest reply stands in.
        _thread('legacy', 'c1', lastReplyAt: '2026-10-02T12:00:00Z'),
        _thread('undated', 'c1'),
      ], 'c1');
      expect(
        [for (final t in ordered) t['parentMessageId']],
        ['p-early', 'p-late', 'p-legacy', 'p-mention', 'p-undated'],
      );
    });
  });

  group('sidebar', () {
    late MessageAdapter api;
    late WorkspaceController w;
    var flags = <String>{};
    var threads = <Map<String, dynamic>>[];

    Future<void> setup(
      WidgetTester tester, {
      Set<String> enabled = const {},
      List<Map<String, dynamic>> followed = const [],
      bool refuse = false,
      bool stale = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      flags = {...enabled};
      threads = [...followed];
      final made = (await tester.runAsync(() => fixture('owner')))!;
      w = made.$1;
      api = made.$2;
      addTearDown(w.dispose);
      if (refuse) {
        w.client.http.httpClientAdapter = _Refusing(
          w.client.http.httpClientAdapter,
        );
      }
      w.loading = false;
      w.messageDomain.ledger.switchServer('s1');
      w.channels = [
        RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
        RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
        RaftChannel({'id': 'c3', 'name': 'away', 'joined': false}),
      ];
      w.section = 'chat';
      api.routes['GET /servers/s1/sidebar-order'] = (_) => {};
      api.routes['GET /channels/threads/followed'] = (_) => {
        'threads': threads,
      };
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          for (final key in flags) {'key': key, 'enabled': true},
        ],
      };
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      api.routes['POST /channels/c1/read-all'] = (_) => {
        'ok': true,
        'maxReadSeq': 5,
        'readStateVersion': 3,
      };
      api.routes['POST /channels/c1/conversation-read-all'] = (_) {
        // The server read the channel and its thread (a stale replica keeps
        // answering the old counts).
        if (!stale) {
          threads = [
            for (final t in threads) {...t, 'unreadCount': 0},
          ];
        }
        return {
          'ok': true,
          'serverId': 's1',
          'markedCount': 2,
          'scopes': [
            {'scopeId': 'c1', 'maxReadSeq': 5, 'readStateVersion': 3},
            {'scopeId': 't-a', 'maxReadSeq': 2, 'readStateVersion': 4},
          ],
        };
      };
      api.routes['GET /channels/unread'] = (_) => {'channels': {}};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: RaftFamily.elegant),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The flags and the followed list answer after the first frame.
      await tester.runAsync(() async {
        for (var i = 0; i < 200; i++) {
          final on = ActivityRolloutFlags.peek(w)?.threadUnreadBadge == true;
          if (enabled.isEmpty || on && w.followedThreads.settled) break;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
    }

    Finder row(String id) => find.byKey(ValueKey('sidebar-channel-$id'));
    Finder threadMark(String id) => find.descendant(
      of: row(id),
      matching: find.byKey(const ValueKey('sidebar-thread-unread')),
    );
    Finder mention(String id) => find.descendant(
      of: row(id),
      matching: find.byType(RaftSidebarMentionMarker),
    );

    Future<void> rightClick(WidgetTester tester, Finder target) async {
      await tester.tapAt(
        tester.getCenter(target),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
    }

    void sidebarTest(
      String name,
      Future<void> Function(WidgetTester tester) body,
    ) => testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
    });

    const both = {'thread_unread_badge_v0', 'sidebar_mark_all_read_v0'};

    sidebarTest('threads with new replies light the parent row and its @', (
      tester,
    ) async {
      await setup(
        tester,
        enabled: {'thread_unread_badge_v0'},
        followed: [
          _thread('a', 'c1', mention: true),
          _thread('b', 'c1'),
          _thread('x', 'c3'),
        ],
      );
      expect(threadMark('c1'), findsOneWidget);
      expect(
        find.descendant(of: threadMark('c1'), matching: find.text('2')),
        findsOneWidget,
        reason: 'two threads, not their replies',
      );
      expect(mention('c1'), findsOneWidget);
      expect(threadMark('c2'), findsNothing);
      expect(threadMark('c3'), findsNothing, reason: 'not joined');
      expect(
        find.bySemanticsLabel(RegExp('2 threads with new replies')),
        findsOneWidget,
      );
    });

    sidebarTest('the channel count and the thread count share the badge', (
      tester,
    ) async {
      await setup(
        tester,
        enabled: {'thread_unread_badge_v0'},
        followed: [_thread('a', 'c1')],
      );
      w.conversationReads.unread = {'c1': 5};
      w.notifyListeners();
      await tester.pumpAndSettle();
      final badge = find.ancestor(
        of: threadMark('c1'),
        matching: find.byType(RaftSidebarThreadUnreadCount),
      );
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: badge, matching: find.text('·')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: badge, matching: find.text('1')),
        findsOneWidget,
      );
    });

    sidebarTest('a server with the flag off keeps the plain row', (
      tester,
    ) async {
      await setup(tester, followed: [_thread('a', 'c1', mention: true)]);
      expect(threadMark('c1'), findsNothing);
      expect(mention('c1'), findsNothing);
    });

    sidebarTest('reading the thread takes the mark away again', (tester) async {
      await setup(
        tester,
        enabled: {'thread_unread_badge_v0'},
        followed: [_thread('a', 'c1', mention: true)],
      );
      expect(threadMark('c1'), findsOneWidget);
      w.followedThreads.applyReadStateHint({
        'scopeId': 't-a',
        'unreadCount': 0,
      });
      await tester.pumpAndSettle();
      expect(threadMark('c1'), findsNothing);
      expect(mention('c1'), findsNothing);
    });

    sidebarTest(
      'a followed list that still answers the old counts does not bring the '
      'mark back',
      (tester) async {
        await setup(
          tester,
          enabled: both,
          followed: [_thread('a', 'c1')],
          stale: true,
        );
        await rightClick(tester, row('c1'));
        await tester.tap(find.text('Mark All as Read'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        expect(
          api.calls.where(
            (c) => c.path == '/channels/c1/conversation-read-all',
          ),
          hasLength(1),
        );
        expect(threadMark('c1'), findsNothing);
      },
    );

    sidebarTest(
      'Mark All as Read reads the channel and its threads in one request',
      (tester) async {
        await setup(tester, enabled: both, followed: [_thread('a', 'c1')]);
        // Only the thread is unread: the plain toggle would offer Mark as Unread.
        await rightClick(tester, row('c1'));
        expect(find.text('Mark All as Read'), findsOneWidget);
        expect(find.text('Mark as Unread'), findsNothing);
        await tester.tap(find.text('Mark All as Read'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        expect(
          api.calls.where(
            (c) =>
                c.method == 'POST' &&
                c.path == '/channels/c1/conversation-read-all',
          ),
          hasLength(1),
        );
        expect(
          api.calls.where((c) => c.path == '/channels/c1/read-all'),
          isEmpty,
        );
        expect(threadMark('c1'), findsNothing);
        // The list was read again: the thread now counts as read.
        await rightClick(tester, row('c1'));
        expect(find.text('Mark as Unread'), findsOneWidget);
      },
    );

    sidebarTest('without the mark-all flag the menu stays Mark as Read', (
      tester,
    ) async {
      await setup(
        tester,
        enabled: {'thread_unread_badge_v0'},
        followed: [_thread('a', 'c1')],
      );
      w.conversationReads.unread = {'c1': 2};
      w.notifyListeners();
      await tester.pumpAndSettle();
      await rightClick(tester, row('c1'));
      expect(find.text('Mark as Read'), findsOneWidget);
      expect(find.text('Mark All as Read'), findsNothing);
      await tester.tap(find.text('Mark as Read'));
      await tester.pumpAndSettle();
      expect(
        api.calls.where((c) => c.path == '/channels/c1/conversation-read-all'),
        isEmpty,
      );
      expect(
        api.calls.where((c) => c.path == '/channels/c1/read-all'),
        hasLength(1),
      );
    });

    sidebarTest('a DM or a channel not joined never offers Mark All as Read', (
      tester,
    ) async {
      await setup(tester, enabled: both, followed: [_thread('a', 'c1')]);
      w.conversationReads.unread = {'c3': 1};
      w.notifyListeners();
      await tester.pumpAndSettle();
      await rightClick(tester, row('c3'));
      expect(find.text('Mark All as Read'), findsNothing);
      expect(find.text('Mark as Read'), findsOneWidget);
    });

    sidebarTest(
      '404 sidebar_mark_all_read_disabled falls back to the plain read',
      (tester) async {
        await setup(
          tester,
          enabled: both,
          followed: [_thread('a', 'c1')],
          refuse: true,
        );
        final evaluations = api.calls
            .where((c) => c.path == '/feature-flags/evaluate')
            .length;
        // The server turned the flag off since this client evaluated it.
        flags = {};
        await rightClick(tester, row('c1'));
        await tester.tap(find.text('Mark All as Read'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        expect(
          api.calls.where((c) => c.path == '/channels/c1/read-all'),
          hasLength(1),
        );
        expect(
          api.calls.where((c) => c.path == '/feature-flags/evaluate').length,
          greaterThan(evaluations),
          reason: 'the flags are evaluated again',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        expect(threadMark('c1'), findsNothing, reason: 'flag now off');
      },
    );
  });
}
