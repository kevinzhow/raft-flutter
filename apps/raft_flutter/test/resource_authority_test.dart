import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final statuses = <String, int>{};
  final routes = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    return ResponseBody.fromString(
      jsonEncode(
        route == null ? {'error': 'Unexpected request'} : await route(o),
      ),
      route == null ? 404 : statuses['${o.method} ${o.path}'] ?? 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _EventsClient extends RaftClient {
  _EventsClient({
    required super.origin,
    required super.sessionStore,
    required super.transport,
  });
  final forwarded = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => forwarded.stream;
  @override
  Future<void> dispose() async {
    await forwarded.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  int refreshes = 0;
  @override
  Future<void> refreshUnread() async {
    refreshes++;
  }
}

Future<(_Workspace, _Adapter)> _fixture() async {
  final adapter = _Adapter();
  adapter.routes['POST /auth/login'] = (_) => {
    'accessToken': '_fixture',
    'refreshToken': '_fixture',
    'user': {'id': 'alice'},
  };
  final client = _EventsClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = adapter,
  );
  await client.login('_fixture', '_fixture');
  client.selectServer('s1');
  final w = _Workspace(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channels = [
    RaftChannel({
      'id': 'c1',
      'name': 'Private channel',
      'joined': true,
      'isPrivate': true,
    }),
  ];
  return (w, adapter);
}

Widget _host(
  _Workspace w,
  String section, {
  String? channelId,
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: ResourceView(
      controller: w,
      section: section,
      channelId: channelId,
      onMessage: (_, _) async {},
    ),
  ),
);
void _role(_Workspace w, String next) {
  w.server = RaftRecord({'id': 's1', 'role': next});
  w.notifyListeners();
}

final task = <String, dynamic>{
  'id': 't1',
  'taskNumber': 1,
  'title': 'Private task',
  'description': 'Private details',
  'channelId': 'c1',
  'channelName': 'Private channel',
  'status': 'todo',
  'createdById': 'alice',
  'createdByType': 'user',
  'createdByName': 'Alice',
};
void _taskRoutes(_Workspace w, _Adapter a) {
  a.routes['GET /servers/s1/members'] = (_) => <dynamic>[];
  a.routes['GET /agents'] = (_) => <dynamic>[];
  a.routes['GET /tasks/server'] = (request) => {
    'tasks':
        w.server?.string('role') == 'guest' ||
            w.channels.isEmpty ||
            request.queryParameters['status'] != null &&
                request.queryParameters['status'] != task['status']
        ? <dynamic>[]
        : [task],
    'next_cursor': null,
  };
  a.routes['GET /tasks/channel/c1/number/1'] = (_) => {'task': task};
  a.routes['GET /tasks/t1/history'] = (_) => {'events': <dynamic>[]};
}

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K10a] immediate task dialog while both requests are held ${theme.$1}/${theme.$2}',
      (tester) async {
        final (w, a) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        _taskRoutes(w, a);
        final details = Completer<dynamic>(), history = Completer<dynamic>();
        a.routes['GET /tasks/channel/c1/number/1'] = (_) => details.future;
        a.routes['GET /tasks/t1/history'] = (_) => history.future;
        await tester.pumpWidget(
          _host(w, 'tasks', family: theme.$1, dark: theme.$2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private task'));
        await tester.pump();
        final dialog = find.byKey(const ValueKey('task-details-loading'));
        expect(dialog, findsOneWidget);
        final bones = find.descendant(
          of: dialog,
          matching: find.byType(RaftSkeleton),
        );
        expect(bones, findsNWidgets(3));
        final sizes = bones
            .evaluate()
            .map((e) => tester.getSize(find.byWidget(e.widget)))
            .toList();
        expect(sizes.map((s) => s.height), [24, 16, 16]);
        expect(sizes[0].width, closeTo(sizes[1].width * 2 / 3, .1));
        expect(sizes[2].width, closeTo(sizes[1].width * .8, .1));
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Private details'),
          ),
          findsNothing,
        );
        expect(find.text('History'), findsNothing);
        details.complete({'task': task});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(dialog, findsOneWidget);
        expect(find.text('History'), findsNothing);
        history.complete({
          'events': [
            {'eventType': 'created', 'actorName': 'Alice'},
          ],
        });
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Private details'),
          ),
          findsOneWidget,
        );
        expect(find.text('History'), findsOneWidget);
        expect(find.text('created · Alice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '[K10c] closing a pending task rejects late details ${theme.$1}/${theme.$2}',
      (tester) async {
        final (w, a) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        _taskRoutes(w, a);
        final details = Completer<dynamic>();
        a.routes['GET /tasks/channel/c1/number/1'] = (_) => details.future;
        await tester.pumpWidget(
          _host(w, 'tasks', family: theme.$1, dark: theme.$2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private task'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('task-details-loading')),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await tester.pumpAndSettle();
        details.complete({'task': task});
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Private details'),
          ),
          findsNothing,
        );
        expect(a.calls.where((o) => o.path.endsWith('/history')), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '[K10c] revocation closes a pending task before late lookup ${theme.$1}/${theme.$2}',
      (tester) async {
        final (w, a) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        _taskRoutes(w, a);
        final details = Completer<dynamic>();
        a.routes['GET /tasks/channel/c1/number/1'] = (_) => details.future;
        await tester.pumpWidget(
          _host(w, 'tasks', family: theme.$1, dark: theme.$2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private task'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('task-details-loading')),
          findsOneWidget,
        );
        w.channels = [];
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        details.complete({'task': task});
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Private details'),
          ),
          findsNothing,
        );
        expect(a.calls.where((o) => o.path.endsWith('/history')), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'pending task history failure remains an error ${theme.$1}/${theme.$2}',
      (tester) async {
        final (w, a) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        _taskRoutes(w, a);
        final history = Completer<dynamic>();
        a.routes['GET /tasks/t1/history'] = (_) => history.future;
        a.statuses['GET /tasks/t1/history'] = 500;
        await tester.pumpWidget(
          _host(w, 'tasks', family: theme.$1, dark: theme.$2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          find.byKey(const ValueKey('task-details-loading')),
          findsOneWidget,
        );
        history.complete({'error': 'History failed'});
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('task-details-error')),
          findsOneWidget,
        );
        expect(find.text('History'), findsNothing);
        expect(
          (tester.state(find.byType(ResourceView)) as dynamic).error,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'closed task discards late history failure ${theme.$1}/${theme.$2}',
      (tester) async {
        final (w, a) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        _taskRoutes(w, a);
        final history = Completer<dynamic>();
        a.routes['GET /tasks/t1/history'] = (_) => history.future;
        a.statuses['GET /tasks/t1/history'] = 500;
        await tester.pumpWidget(
          _host(w, 'tasks', family: theme.$1, dark: theme.$2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await tester.pumpAndSettle();
        history.complete({'error': 'Late history failed'});
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          (tester.state(find.byType(ResourceView)) as dynamic).error,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'authority changes close private task filter menus and reject a stale Activity action',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _taskRoutes(w, a);
      await tester.pumpWidget(_host(w, 'tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter tasks by creator'));
      await tester.pumpAndSettle();
      expect(find.text('Created by me'), findsOneWidget);
      _role(w, 'guest');
      await tester.pumpAndSettle();
      expect(find.text('Created by me'), findsNothing);
      a.routes['GET /channels/inbox'] = (_) => {
        'items': <dynamic>[],
        'hasMore': false,
      };
      _role(w, 'owner');
      await tester.pumpWidget(_host(w, 'activity'));
      await tester.pumpAndSettle();
      final action = tester.widget<RaftInteractive>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RaftInteractive &&
              widget.semanticLabel == 'Mark all read',
        ),
      );
      _role(w, 'member');
      await tester.pumpAndSettle();
      action.onPressed!();
      await tester.pumpAndSettle();
      expect(
        a.calls.where((o) => o.path == '/channels/inbox/read-all'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'canonical task creator fields preserve member delete authorization',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _role(w, 'member');
      _taskRoutes(w, a);
      await tester.pumpWidget(_host(w, 'tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private task'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
    },
  );

  testWidgets(
    'a mounted channel membership event clears private rows before authorization refresh completes',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final replacement = Completer<dynamic>(), channels = Completer<dynamic>();
      var first = true;
      a.routes['GET /channels/saved'] = (_) {
        if (first) {
          first = false;
          return {
            'saved': [
              {
                'messageId': 'm1',
                'channelId': 'c1',
                'content': 'Private saved body',
              },
            ],
            'hasMore': false,
          };
        }
        return replacement.future;
      };
      a.routes['GET /channels'] = (_) => channels.future;
      a.routes['GET /channels/dm'] = (_) => channels.future;
      await tester.pumpWidget(_host(w, 'saved'));
      await tester.pumpAndSettle();
      (w.client as _EventsClient).forwarded.add(
        const RaftEvent('channel:members-updated', {'channelId': 'c1'}),
      );
      await tester.pump();
      expect(find.text('Private saved body'), findsNothing);
      replacement.complete({'saved': <dynamic>[], 'hasMore': false});
      channels.complete(<dynamic>[]);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'late task board lane pagination cannot repopulate revoked rows',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _taskRoutes(w, a);
      final page = Completer<dynamic>();
      a.routes['GET /tasks/server'] = (o) {
        if (o.queryParameters['cursor'] != null) return page.future;
        final visible =
            w.server?.string('role') == 'owner' &&
            (o.queryParameters['status'] == null ||
                o.queryParameters['status'] == 'todo');
        return {
          'tasks': visible ? [task] : <dynamic>[],
          'next_cursor': visible && o.queryParameters['status'] != null
              ? 'next'
              : null,
        };
      };
      await tester.pumpWidget(_host(w, 'tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more Todo'));
      await tester.pump();
      _role(w, 'guest');
      await tester.pumpAndSettle();
      page.complete({
        'tasks': [
          {...task, 'id': 't2', 'title': 'Late board private task'},
        ],
        'next_cursor': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Late board private task'), findsNothing);
      expect(find.text('Private task'), findsNothing);
    },
  );

  testWidgets(
    'same-generation role change clears saved rows and rejects late pagination',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final page = Completer<dynamic>(), replacement = Completer<dynamic>();
      a.routes['GET /channels/saved'] = (o) =>
          w.server?.string('role') != 'owner'
          ? replacement.future
          : o.queryParameters['offset'] == 0
          ? {
              'saved': [
                {
                  'messageId': 'm1',
                  'channelId': 'c1',
                  'content': 'Private saved body',
                },
              ],
              'hasMore': true,
            }
          : page.future;
      await tester.pumpWidget(_host(w, 'saved'));
      await tester.pumpAndSettle();
      expect(find.text('Private saved body'), findsOneWidget);
      // SavedPanel pages by infinite scroll: the sentinel already requested
      // the next page.
      final generation = w.client.generation;
      _role(w, 'member');
      await tester.pump();
      expect(w.client.generation, generation);
      expect(find.text('Private saved body'), findsNothing);
      page.complete({
        'saved': [
          {'messageId': 'm2', 'content': 'Late private body'},
        ],
        'hasMore': false,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Late private body'), findsNothing);
      replacement.complete({'saved': <dynamic>[], 'hasMore': false});
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'channel revocation rejects late task details before history lookup or modal',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _taskRoutes(w, a);
      final details = Completer<dynamic>();
      a.routes['GET /tasks/channel/c1/number/1'] = (_) => details.future;
      await tester.pumpWidget(_host(w, 'tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private task'));
      await tester.pump();
      w.channels = [];
      w.notifyListeners();
      await tester.pumpAndSettle();
      details.complete({'task': task});
      await tester.pumpAndSettle();
      expect(find.text('Private task'), findsNothing);
      expect(find.text('Private details'), findsNothing);
      expect(a.calls.where((o) => o.path.endsWith('/history')), isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'late task assignee lookup cannot open private people under downgraded role',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _taskRoutes(w, a);
      final people = Completer<dynamic>();
      a.routes['GET /channels/c1/members'] = (_) => people.future;
      await tester.pumpWidget(_host(w, 'tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign'));
      await tester.pump();
      _role(w, 'guest');
      await tester.pumpAndSettle();
      people.complete({
        'humans': [
          {'id': 'private-person', 'displayName': 'Private colleague'},
        ],
        'agents': <dynamic>[],
      });
      await tester.pumpAndSettle();
      expect(find.text('Private colleague'), findsNothing);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(a.calls.where((o) => o.method == 'PATCH'), isEmpty);
    },
  );
  testWidgets(
    'task creation form closes on channel authority change and retained submit cannot mutate',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _taskRoutes(w, a);
      await tester.pumpWidget(_host(w, 'tasks', channelId: 'c1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Task'));
      await tester.pumpAndSettle();
      final submit = tester
          .widget<RaftFormDialog>(find.byType(RaftFormDialog))
          .onSubmit;
      w.channels = [
        RaftChannel({
          'id': 'c1',
          'name': 'Private channel',
          'joined': false,
          'isPrivate': true,
        }),
      ];
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormDialog), findsNothing);
      await expectLater(
        submit({'channel': 'c1', 'title': 'Old form', 'description': ''}),
        throwsA(isA<RaftApiException>()),
      );
      expect(
        a.calls.where(
          (o) => o.method == 'POST' && o.path.startsWith('/tasks/'),
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'old accepted mutation cannot refresh or reload the next authority',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final mutation = Completer<dynamic>();
      a.routes['GET /channels/saved'] = (_) => {
        'saved': w.server?.string('role') == 'owner'
            ? [
                {
                  'messageId': 'm1',
                  'channelId': 'c1',
                  'content': 'Private saved body',
                },
              ]
            : <dynamic>[],
        'hasMore': false,
      };
      a.routes['DELETE /channels/saved/m1'] = (_) => mutation.future;
      await tester.pumpWidget(_host(w, 'saved'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RaftSavedToggle));
      await tester.pump();
      _role(w, 'member');
      await tester.pumpAndSettle();
      mutation.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(w.refreshes, 0);
      expect(a.calls.where((o) => o.path == '/channels/saved'), hasLength(2));
      expect(find.text('Private saved body'), findsNothing);
    },
  );
  testWidgets(
    'empty search clears previous results and channel revocation clears an open task modal',
    (tester) async {
      final (w, a) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /messages/search'] = (_) => {
        'results': [
          {'id': 'm1', 'channelId': 'c1', 'content': 'Private search match'},
        ],
        'hasMore': false,
      };
      await tester.pumpWidget(_host(w, 'search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'private');
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pumpAndSettle();
      expect(find.text('Private search match'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pumpAndSettle();
      expect(find.text('Private search match'), findsNothing);
      _taskRoutes(w, a);
      await tester.pumpWidget(_host(w, 'tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private task'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Private details'),
        ),
        findsOneWidget,
      );
      w.channels = [];
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Private details'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
