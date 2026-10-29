import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_follow_ack_test.dart' show thread;
import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, channelRow, shown, skeleton;

// Web v1.21.12-source.1 / a98ae003:
// ThreadsInbox's DMs view is between Saved and Done, requests scope=dms,
// includes threads under DMs, and owns its count without replacing Activity.
Map<String, dynamic> _dm(int index) => {
  ...channelRow(index, unread: index == 0 ? 2 : 0),
  'kind': 'dm',
  'channelId': 'dm$index',
  'channelName': 'Peer $index',
  'channelType': 'dm',
  'lastMessagePreview': 'Direct preview $index',
};

Map<String, dynamic> _dmThread() => {
  ...thread(unread: 1),
  'parentChannelId': 'dm0',
  'parentChannelName': 'Peer 0',
  'parentChannelType': 'dm',
  'parentContent': 'Direct thread parent',
  'latestActivityPreview': 'Direct thread reply',
};

class _Workspace extends ActivityWorkspace {
  _Workspace(super.client);

  List<Map<String, dynamic>> serverRows = [
    for (var i = 0; i < 32; i++) channelRow(i, unread: i == 0 ? 14 : 0),
    _dm(0),
    _dmThread(),
  ];
  Completer<void>? holdDms;
  Completer<void>? holdNextUnscoped;
  bool rejectNextUnscoped = false;

  List<Map<String, dynamic>> get dmQueries => [
    for (final query in inboxQueries)
      if (query['scope'] == 'dms') query,
  ];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path != '/channels/inbox') return super.query(path, query: query);
    final params = {...?query};
    inboxQueries.add(params);
    final scoped = params['scope'] == 'dms';
    var source = serverRows.where((row) {
      if (!scoped) return true;
      return row['kind'] == 'thread'
          ? row['parentChannelType'] == 'dm'
          : row['channelType'] == 'dm';
    }).toList();
    if (params['channelId'] case final String channel) {
      source = source
          .where(
            (row) =>
                (row['kind'] == 'thread'
                    ? row['parentChannelId']
                    : row['channelId']) ==
                channel,
          )
          .toList();
    }
    if (params['q'] case final String text when text.trim().isNotEmpty) {
      source = source
          .where(
            (row) => row.values.whereType<String>().any(
              (value) => value.toLowerCase().contains(text.toLowerCase()),
            ),
          )
          .toList();
    }
    if (params['sort'] == 'asc') source = source.reversed.toList();
    final offset = params['offset'] as int? ?? 0;
    final limit = params['limit'] as int? ?? 30;
    final page = source.skip(offset).take(limit).toList();
    final unread = source.fold<int>(
      0,
      (total, row) => total + (row['unreadCount'] as int? ?? 0),
    );
    final response = {
      'items': [for (final row in page) Map<String, dynamic>.of(row)],
      'totalCount': source.length,
      'allCount': source.length,
      'totalUnreadCount': unread,
      'activeUnreadCount': unread,
      'hasMore': offset + page.length < source.length,
      'groups': [
        if (!scoped && serverRows.any((row) => row['channelId'] == 'ch0'))
          {
            'channelId': 'ch0',
            'channelName': 'Channel 0',
            'channelType': 'channel',
            'count': 1,
          },
        if (serverRows.any((row) => row['channelType'] == 'dm'))
          {
            'channelId': 'dm0',
            'channelName': 'Peer 0',
            'channelType': 'dm',
            'count': 2,
          },
      ],
    };
    final gate = scoped ? holdDms : holdNextUnscoped;
    final reject = !scoped && rejectNextUnscoped;
    if (!scoped) rejectNextUnscoped = false;
    if (!scoped) holdNextUnscoped = null;
    if (gate != null) await gate.future;
    if (reject) throw const RaftApiException('Offline fixture');
    return response;
  }
}

void _testActivityWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Dispose the mounted view and picker even when a contract assertion
      // fails, so the red baseline reports the missing feature without leaks.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  for (final width in [390.0, 1200.0]) {
    final compact = width >= 768;
    late ActivityClient client;
    late _Workspace workspace;
    late List<int?> acceptedUnread;
    late List<Map?> acceptedWindows;

    setUp(() {
      client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      workspace = _Workspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          for (var i = 0; i < 32; i++)
            RaftChannel({
              'id': 'ch$i',
              'name': 'Channel $i',
              'type': 'channel',
              'joined': true,
            }),
        ]
        ..dms = [
          RaftChannel({
            'id': 'dm0',
            'name': 'Peer 0',
            'type': 'dm',
            'peerId': 'peer0',
            'peerType': 'user',
            'peerName': 'Peer 0',
            'joined': true,
          }),
        ];
      acceptedUnread = [];
      acceptedWindows = [];
    });
    tearDown(() async {
      workspace.dispose();
      await client.dispose();
    });

    Future<dynamic> mount(WidgetTester tester, {String language = 'en'}) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: ResourceView(
              controller: workspace,
              section: 'activity',
              activitySidebarEnabled: true,
              compactActivitySidebar: compact,
              onActivityUnreadAccepted: acceptedUnread.add,
              onActivityWindowAccepted: (value, {bool firstPage = false}) =>
                  acceptedWindows.add(value),
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state(find.byType(ResourceView));
    }

    Future<void> openViews(WidgetTester tester) async {
      if (compact &&
          find
              .byKey(const ValueKey('activity-switcher-dialog'))
              .evaluate()
              .isEmpty) {
        await tester.tap(find.byKey(const ValueKey('activity-scope-switcher')));
        // Wait only for route layout/animation: a held first list read has a
        // repeating loading animation and deliberately cannot settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Finder view(String value) => find.byKey(
      ValueKey('activity-${compact ? 'switcher-nav' : 'view'}-$value'),
    );

    Future<void> select(
      WidgetTester tester,
      String value, {
      bool settle = true,
    }) async {
      await openViews(tester);
      expect(
        view(value),
        findsOneWidget,
        reason: 'The $value view is available',
      );
      await tester.ensureVisible(view(value));
      await tester.tap(view(value));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        // Finish the picker's exit transition while the network gate stays
        // held; a closing route is still findable but cannot receive taps.
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    _testActivityWidgets(
      '$width DMs is between Saved and Done and owns its scoped rows/count',
      (tester) async {
        final dynamic state = await mount(tester);
        expect(workspace.dmQueries, isEmpty);
        await openViews(tester);
        expect(view('dms'), findsOneWidget);
        final saved = tester.getTopLeft(view('saved'));
        final dms = tester.getTopLeft(view('dms'));
        final done = tester.getTopLeft(view('done'));
        expect(compact ? saved.dy < dms.dy : saved.dx < dms.dx, isTrue);
        expect(compact ? dms.dy < done.dy : dms.dx < done.dx, isTrue);
        await select(tester, 'dms');
        expect(workspace.dmQueries.single, containsPair('filter', 'all'));
        expect(workspace.dmQueries.single, containsPair('sort', 'desc'));
        expect(workspace.dmQueries.single, containsPair('offset', 0));
        expect(shown('Direct preview 0'), findsOneWidget);
        expect(shown('Direct thread reply'), findsOneWidget);
        expect(shown('Preview 0'), findsNothing);
        expect(state.rows, hasLength(2));
        expect(find.text('Mark all read'), findsNothing);
        expect(acceptedUnread.whereType<int>().toSet(), {17});
        if (compact) {
          await openViews(tester);
          expect(
            find.descendant(of: view('dms'), matching: find.text('2')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('activity-switcher-group-ch0')),
            findsOneWidget,
            reason: 'The unscoped channel/source facets are retained',
          );
        }
        await select(tester, 'all');
        expect(shown('Preview 0'), findsOneWidget);
        expect(shown('Direct preview 0'), findsNothing);
        expect(acceptedUnread.last, 17);
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['en', 'zh']) {
      _testActivityWidgets('$width/$language DMs has the Web empty copy', (
        tester,
      ) async {
        workspace.serverRows.removeWhere(
          (row) =>
              row['channelType'] == 'dm' || row['parentChannelType'] == 'dm',
        );
        await mount(tester, language: language);
        await select(tester, 'dms');
        expect(
          find.text(language == 'en' ? 'No DM activity' : '没有私信动态'),
          findsOneWidget,
        );
        expect(
          find.text(
            language == 'en'
                ? 'DMs and threads in DMs show up here when they have new activity.'
                : '私信和私信里的消息列有新动态时会显示在这里。',
          ),
          findsOneWidget,
        );
        expect(find.text('Mark all read'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    _testActivityWidgets(
      '$width DMs pagination keeps scope and removes Load more at the end',
      (tester) async {
        workspace.serverRows = [
          for (var i = 0; i < 32; i++) channelRow(i),
          for (var i = 0; i < 31; i++) _dm(i),
          _dmThread(),
        ];
        workspace.dms = [
          for (var i = 0; i < 31; i++)
            RaftChannel({
              'id': 'dm$i',
              'name': 'Peer $i',
              'type': 'dm',
              'peerId': 'peer$i',
              'peerType': 'user',
              'joined': true,
            }),
        ];
        final dynamic state = await mount(tester);
        await select(tester, 'dms');
        expect(state.rows, hasLength(30));
        await tester.scrollUntilVisible(
          find.text('Load More'),
          500,
          maxScrolls: 30,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Load More'), findsOneWidget);
        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();
        expect(workspace.dmQueries.last, containsPair('offset', 30));
        expect(workspace.dmQueries.last, containsPair('filter', 'all'));
        expect(state.rows, hasLength(32));
        expect(find.text('Load More'), findsNothing);
        expect(
          state.rows.any((dynamic row) => row['parentChannelType'] == 'dm'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    _testActivityWidgets(
      '$width one socket burst refreshes DMs without replacing rows with loading',
      (tester) async {
        await mount(tester);
        await select(tester, 'dms');
        final before = workspace.dmQueries.length;
        final held = Completer<void>();
        workspace.holdDms = held;
        try {
          for (var i = 0; i < 3; i++) {
            client.emit('message:updated', {
              'id': 'room-$i',
              'channelId': 'ch0',
              'content': 'Room burst $i',
            });
          }
          await tester.pump(const Duration(seconds: 1));
          expect(workspace.dmQueries, hasLength(before + 1));
          expect(shown('Direct preview 0'), findsOneWidget);
          expect(find.textContaining('Room burst'), findsNothing);
          expect(skeleton, findsNothing);
        } finally {
          held.complete();
          workspace.holdDms = null;
          await tester.pumpAndSettle();
        }
        expect(workspace.dmQueries, hasLength(before + 1));
        expect(shown('Direct thread reply'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    _testActivityWidgets(
      '$width a late DMs response cannot replace All or its badge',
      (tester) async {
        final dynamic state = await mount(tester);
        final held = Completer<void>();
        workspace.holdDms = held;
        try {
          await select(tester, 'dms', settle: false);
          expect(workspace.dmQueries, hasLength(1));
          expect(state.directMessagesTotal, 0);
          await select(tester, 'all');
          expect(shown('Preview 0'), findsOneWidget);
        } finally {
          held.complete();
          workspace.holdDms = null;
          await tester.pumpAndSettle();
        }
        expect(state.filter, 'all');
        expect(shown('Preview 0'), findsOneWidget);
        expect(shown('Direct preview 0'), findsNothing);
        expect(acceptedUnread.whereType<int>().toSet(), {17});
        expect(tester.takeException(), isNull);
      },
    );

    _testActivityWidgets(
      '$width returning to DMs paints its cached window before revalidation',
      (tester) async {
        final dynamic state = await mount(tester);
        await select(tester, 'dms');
        await select(tester, 'all');
        expect(state.directMessagesTotal, 2);
        final held = Completer<void>();
        workspace.holdDms = held;
        try {
          await select(tester, 'dms', settle: false);
          expect(shown('Direct preview 0'), findsOneWidget);
          expect(shown('Direct thread reply'), findsOneWidget);
          expect(skeleton, findsNothing);
          expect(state.totalUnreadCount, 17);
        } finally {
          held.complete();
          workspace.holdDms = null;
          await tester.pumpAndSettle();
        }
        expect(state.directMessagesTotal, 2);
        // Only the unscoped facets may be published to the shared store.
        expect(acceptedWindows.whereType<Map>(), isNotEmpty);
        expect(
          acceptedWindows.whereType<Map>().every(
            (value) =>
                value['totalCount'] == 34 &&
                (value['groups'] as List).any(
                  (dynamic group) => group['channelId'] == 'ch0',
                ),
          ),
          isTrue,
        );
      },
    );

    _testActivityWidgets(
      '$width a role change retires DMs rows, counts and an older response',
      (tester) async {
        final dynamic state = await mount(tester);
        await select(tester, 'dms');
        final held = Completer<void>();
        workspace.holdDms = held;
        client.emit('message:updated', {'id': 'stale', 'channelId': 'dm0'});
        await tester.pump(const Duration(seconds: 1));
        workspace.serverRows = [];
        workspace.server = RaftRecord({'id': 's1', 'role': 'member'});
        workspace.notifyListeners();
        await tester.pump();
        expect(shown('Direct preview 0'), findsNothing);
        held.complete();
        workspace.holdDms = null;
        await tester.pumpAndSettle();
        expect(state.rows, isEmpty);
        expect(state.directMessagesTotal, 0);
        expect(state.activityGroups, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    if (compact) {
      _testActivityWidgets(
        '$width DMs keeps source filters and clearing a channel restores its rows',
        (tester) async {
          final dynamic state = await mount(tester);
          await select(tester, 'dms');
          await openViews(tester);
          await tester.tap(
            find.byKey(const ValueKey('activity-switcher-group-ch0')),
          );
          await tester.pumpAndSettle();
          expect(state.rows, isEmpty);
          expect(workspace.dmQueries.last, containsPair('channelId', 'ch0'));
          expect(workspace.dmQueries.last, containsPair('scope', 'dms'));
          expect(find.text('No activity in Channel 0'), findsOneWidget);
          await openViews(tester);
          expect(
            find.byKey(const ValueKey('activity-switcher-group-dm0')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const ValueKey('activity-clear-channel-filter')),
          );
          await tester.pumpAndSettle();
          expect(workspace.dmQueries.last.containsKey('channelId'), isFalse);
          expect(shown('Direct preview 0'), findsOneWidget);
          expect(find.text('No activity in Channel 0'), findsNothing);
        },
      );
    }

    for (final reject in [false, true]) {
      _testActivityWidgets(
        '$width old background facets (failure=$reject) cannot replace a newer All response',
        (tester) async {
          final dynamic state = await mount(tester);
          final held = Completer<void>();
          workspace.holdNextUnscoped = held;
          workspace.rejectNextUnscoped = reject;
          await select(tester, 'dms');
          workspace.serverRows = [channelRow(0, unread: 9)];
          await select(tester, 'all');
          expect(state.totalCount, 1);
          expect(state.totalUnreadCount, 9);
          final published = acceptedWindows.length;
          held.complete();
          await tester.pumpAndSettle();
          expect(state.totalCount, 1);
          expect(state.totalUnreadCount, 9);
          expect(acceptedWindows.length, published);
          expect(state.error, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }

    _testActivityWidgets(
      '$width control: All has its full count and never loads DMs eagerly',
      (tester) async {
        final dynamic state = await mount(tester);
        expect(shown('Preview 0'), findsOneWidget);
        expect(shown('Direct preview 0'), findsNothing);
        expect(workspace.dmQueries, isEmpty);
        expect(state.rows, hasLength(30));
        expect(acceptedUnread.last, 17);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
