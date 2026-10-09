import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_done_lifecycle_test.dart' show doneThread;
import 'message_presentation_test.dart' show fixture, MessageAdapter;

Future<void> _dispatch(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(Duration.zero);
  }
}

class _MountedDone {
  _MountedDone(this.workspace, this.api)
    : attention = SourceActivityUnreadStore(workspace);
  final WorkspaceController workspace;
  final MessageAdapter api;
  final SourceActivityUnreadStore attention;
  final done = Completer<dynamic>(), read = Completer<dynamic>();
  List<RequestOptions> get writes =>
      api.calls.where((r) => r.path == '/channels/thread/read-all').toList();
  int get inboxCalls =>
      api.calls.where((r) => r.path == '/channels/inbox').length;
  dynamic get state => viewKey.currentState;
  final viewKey = GlobalKey();

  static Future<_MountedDone> mount(
    WidgetTester tester,
    RaftFamily family,
    bool dark, {
    Map<String, dynamic>? row,
  }) async {
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    final result = _MountedDone(w, api);
    final initial = {
      'items': [row ?? doneThread()],
      'totalCount': 1,
      'totalUnreadCount': 3,
      'hasMore': false,
    };
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/unread'] = (_) => {'channels': <String, int>{}};
    api.routes['GET /channels/inbox'] = (_) => initial;
    api.routes['POST /channels/threads/done'] = (_) => result.done.future;
    api.routes['POST /channels/thread/read-all'] = (_) => result.read.future;
    final scope = result.attention.scope;
    final epoch = result.attention.authorityEpoch;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(
          body: ResourceView(
            key: result.viewKey,
            controller: w,
            section: 'activity',
            onMessage: (_, _) async {},
            onActivityWindowAccepted: (window) {
              if (window != null) {
                result.attention.acceptWindow(
                  window,
                  scope: scope,
                  authorityEpoch: epoch,
                );
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> close(WidgetTester tester) async {
    // Dispose the explicitly mounted data owner before the widget test checks
    // pending timers, including when an assertion fails in this test body.
    attention.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    workspace.dispose();
  }

  Future<void> click(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Mark conversation done'));
    await _dispatch(tester);
  }

  DioException failure(int status) {
    final request = RequestOptions(path: '/fixture-failure');
    return DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: status,
        data: {'error': 'Fixture failure'},
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[Activity thread Done persisted read] $family/$dark ACK starts bodyless read-all independently of one owned inbox refresh',
      (tester) async {
        final page = await _MountedDone.mount(tester, family, dark);
        try {
          expect(find.byType(RaftConversationCard), findsOneWidget);
          expect(page.attention.totalUnreadCount, 3);
          final refreshed = Completer<dynamic>();
          page.api.routes['GET /channels/inbox'] = (_) => refreshed.future;
          await page.click(tester);
          expect(find.byType(RaftConversationCard), findsNothing);
          expect(page.writes, isEmpty);
          final before = page.inboxCalls;
          page.done.complete({});
          await _dispatch(tester);
          expect(page.writes, hasLength(1));
          final request = page.writes.single;
          expect(request.method, 'POST');
          expect(request.data, isNull);
          expect(request.queryParameters, isEmpty);
          expect(request.headers['X-Server-Id'], 's1');
          expect(request.headers.containsKey('Authorization'), isTrue);
          // The real write stays held while the owned refresh is in flight.
          expect(page.inboxCalls, before + 1);
          page.workspace.unread['thread'] = 1;
          page.workspace.notifyListeners();
          refreshed.complete({
            'items': [],
            'totalCount': 0,
            'totalUnreadCount': 0,
          });
          await _dispatch(tester);
          page.read.complete({});
          await _dispatch(tester);
          // Persisted success never blindly clears a newly arrived reply and
          // never starts a second background inbox GET.
          expect(page.workspace.unread['thread'], 1);
          expect(page.inboxCalls, before + 1);
          expect(find.byType(RaftConversationCard), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await page.close(tester);
        }
      },
    );
    testWidgets(
      '[Activity thread Done persisted read] $family/$dark write failure preserves Done and emits no second refresh',
      (tester) async {
        final page = await _MountedDone.mount(tester, family, dark);
        try {
          await page.click(tester);
          page.done.complete({});
          await _dispatch(tester);
          expect(page.writes, hasLength(1));
          final before = page.inboxCalls;
          page.read.completeError(page.failure(500));
          await _dispatch(tester);
          expect(page.inboxCalls, before);
          expect(find.byType(RaftConversationCard), findsNothing);
          expect(page.state.error, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await page.close(tester);
        }
      },
    );
    testWidgets(
      '[Activity thread Done persisted read] $family/$dark failed Done does not persist a successful read',
      (tester) async {
        final page = await _MountedDone.mount(tester, family, dark);
        try {
          await page.click(tester);
          page.done.completeError(page.failure(500));
          await _dispatch(tester);
          expect(page.writes, isEmpty);
          expect(find.byType(RaftConversationCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await page.close(tester);
        }
      },
    );
    for (final authority in [
      'principal',
      'server',
      'permission',
      'Done generation',
    ]) {
      testWidgets(
        '[Activity thread Done persisted read] $family/$dark obsolete $authority Done ACK cannot write read-all in the new authority',
        (tester) async {
          final page = await _MountedDone.mount(tester, family, dark);
          try {
            await page.click(tester);
            switch (authority) {
              case 'principal':
                page.workspace.client.user = RaftRecord({'id': 'bob'});
              case 'server':
                page.workspace.client.selectServer('s2');
                page.workspace.server = RaftRecord({
                  'id': 's2',
                  'role': 'owner',
                });
              case 'permission':
                page.workspace.server = RaftRecord({
                  'id': 's1',
                  'role': 'guest',
                });
              case 'Done generation':
                final next = {
                  ...doneThread(authoritySeq: '13'),
                  'doneFrontierSeq': '13',
                };
                page.api.routes['GET /channels/inbox'] = (_) => {
                  'items': [next],
                  'totalUnreadCount': 3,
                  'totalCount': 1,
                };
                final Future<void> reloading = page.state.load();
                await _dispatch(tester);
                await reloading;
                final newer = Completer<dynamic>();
                page.api.routes['POST /channels/threads/done'] = (_) =>
                    newer.future;
                await page.click(tester);
            }
            page.workspace.notifyListeners();
            await _dispatch(tester);
            final before = page.inboxCalls;
            page.done.complete({});
            await _dispatch(tester);
            expect(page.writes, isEmpty);
            expect(page.inboxCalls, before);
            expect(tester.takeException(), isNull);
          } finally {
            await page.close(tester);
          }
        },
      );
    }
    testWidgets(
      '[Activity thread Done persisted read] $family/$dark late persisted response cannot clear or refresh the new server',
      (tester) async {
        final page = await _MountedDone.mount(tester, family, dark);
        try {
          await page.click(tester);
          page.done.complete({});
          await _dispatch(tester);
          expect(page.writes, hasLength(1));
          page.workspace.client.selectServer('s2');
          page.workspace.server = RaftRecord({'id': 's2', 'role': 'owner'});
          page.workspace.unread['thread'] = 7;
          page.workspace.notifyListeners();
          await _dispatch(tester);
          final before = page.inboxCalls;
          page.read.complete({});
          await _dispatch(tester);
          expect(page.workspace.unread['thread'], 7);
          expect(page.inboxCalls, before);
          expect(tester.takeException(), isNull);
        } finally {
          await page.close(tester);
        }
      },
    );
    testWidgets(
      '[Activity thread Done persisted read] $family/$dark channel Done keeps its own exact storage RPC without a thread read-all',
      (tester) async {
        final page = await _MountedDone.mount(
          tester,
          family,
          dark,
          row: {
            'kind': 'channel',
            'channelId': 'c1',
            'channelName': 'test',
            'lastMessagePreview': 'Actual channel',
            'unreadCount': 3,
            'doneFrontierSeq': '12',
          },
        );
        try {
          page.api.routes['POST /channels/inbox/done'] = (_) =>
              page.done.future;
          await page.click(tester);
          final writes = page.api.calls.where(
            (r) => r.method == 'POST' && r.path.endsWith('/done'),
          );
          expect(writes, hasLength(1));
          expect(writes.single.path, '/channels/inbox/done');
          expect(writes.single.data, {
            'channelId': 'c1',
            'throughActivitySeq': '12',
            'frontierSpace': 'storage',
          });
          page.done.complete({});
          await _dispatch(tester);
          expect(
            page.api.calls.where((r) => r.path.endsWith('/read-all')),
            isEmpty,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await page.close(tester);
        }
      },
    );
  }
}
