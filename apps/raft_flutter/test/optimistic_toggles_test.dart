import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optimistic reaction and saved toggles (Source MessageItem
/// handleToggleReaction, savedStore saveMessage / unsaveMessage): the chip,
/// the saved state and the badge change on the tap's first frame, the write
/// reconciles in place and a failure puts everything back.
class _Api implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes =
      <String, FutureOr<(int, dynamic)> Function(RequestOptions request)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final (status, body) = route == null ? (200, {}) : await route(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Api api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
  final injected = StreamController<RaftEvent>.broadcast();
  @override
  Stream<RaftEvent> get events => injected.stream;
  @override
  void connect() {}
  void event(String name, dynamic payload) =>
      injected.add(RaftEvent(name, payload));
}

Map<String, dynamic> _thumbs({bool mine = false}) => {
  'emoji': '👍',
  'count': mine ? 3 : 2,
  'reactorIds': ['bob', 'carol', if (mine) 'alice'],
  'reactorNames': ['Bob', 'Carol', if (mine) 'Alice'],
};

Map<String, dynamic> _row({List<Map<String, dynamic>>? reactions}) => {
  'id': 'm1',
  'channelId': 'c1',
  'seq': '1',
  'senderId': 'bob',
  'senderType': 'user',
  'senderName': 'Bob',
  'createdAt': '2026-10-10T08:01:00.000Z',
  'content': 'Hello',
  'reactions': reactions ?? [_thumbs()],
};

Map<String, dynamic> _viewer(int version, List<String> emojis) => {
  'serverId': 's1',
  'messageId': 'm1',
  'viewerVersion': version,
  'reactedEmojis': emojis,
};

Future<(WorkspaceController, _Api, _Client)> _fixture() async {
  final api = _Api();
  api.routes['POST /auth/login'] = (_) => (
    200,
    {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice', 'displayName': 'Alice'},
    },
  );
  final client = _Client(api);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'c1', 'name': 'general', 'joined': true});
  w.channels = [w.channel!];
  w.ledger.switchServer('s1');
  w.ledger.ingest([_row()], expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {'m1'};
  api.routes['GET /messages/m1/reactions/viewer'] = (_) =>
      (200, _viewer(1, const []));
  api.routes['GET /tasks/channel/c1'] = (_) => (200, {'tasks': []});
  return (w, api, client);
}

Future<void> _mount(WidgetTester t, WorkspaceController w) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Column(
            children: [
              SavedSidebarEntry(controller: w, onTap: () {}),
              Expanded(child: RaftChatView(controller: w)),
            ],
          ),
        ),
      ),
    ),
  );
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
  await t.pumpAndSettle();
}

Finder _chip(String emoji) => find.byKey(ValueKey('reaction-$emoji'));
RaftMountedReaction _reaction(WidgetTester t, String emoji) =>
    t.widget<RaftMountedReaction>(_chip(emoji));
int? _badge(WidgetTester t) =>
    t.widget<RaftNavItem>(find.byType(RaftNavItem)).count;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'tapping a chip changes count and own state on the first frame; the '
    'confirmation keeps the same element and rect',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final write = Completer<(int, dynamic)>();
      api.routes['POST /messages/m1/reactions'] = (_) => write.future;
      await _mount(t, w);
      expect(_reaction(t, '👍').count, 2);
      expect(_reaction(t, '👍').reacted, isFalse);
      final element = t.element(_chip('👍'));
      final rect = t.getRect(_chip('👍'));

      await t.tap(_chip('👍'));
      await t.pump();
      // First frame after the tap, the write still held.
      expect(_reaction(t, '👍').count, 3);
      expect(_reaction(t, '👍').reacted, isTrue);
      expect(t.element(_chip('👍')), same(element));
      expect(t.getRect(_chip('👍')).topLeft, rect.topLeft);

      // A second tap while the write is held is ignored (Web pending set).
      await t.tap(_chip('👍'));
      await t.pump();
      expect(_reaction(t, '👍').count, 3);

      write.complete((
        200,
        {
          ..._row(reactions: [_thumbs(mine: true)]),
          'reactionViewer': _viewer(2, ['👍']),
        },
      ));
      await _settle(t);
      expect(api.calls.where((o) => o.path == '/messages/m1/reactions'), [
        isA<RequestOptions>().having((o) => o.method, 'method', 'POST'),
      ]);
      expect(_reaction(t, '👍').count, 3);
      expect(_reaction(t, '👍').reacted, isTrue);
      expect(t.element(_chip('👍')), same(element));
      expect(t.getRect(_chip('👍')).topLeft, rect.topLeft);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a new emoji inserts its chip once and removing the last reaction drops '
    'it once; neither moves the other chips',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final add = Completer<(int, dynamic)>(),
          remove = Completer<(int, dynamic)>();
      api.routes['POST /messages/m1/reactions'] = (_) => add.future;
      api.routes['DELETE /messages/m1/reactions'] = (_) => remove.future;
      await _mount(t, w);
      final thumbs = t.element(_chip('👍'));
      final thumbsRect = t.getRect(_chip('👍'));
      expect(_chip('🔥'), findsNothing);

      unawaited(w.toggleReaction(w.messages.single, '🔥'));
      await t.pump();
      expect(_chip('🔥'), findsOneWidget);
      expect(_reaction(t, '🔥').count, 1);
      expect(_reaction(t, '🔥').reacted, isTrue);
      final fire = t.element(_chip('🔥'));
      expect(t.element(_chip('👍')), same(thumbs));
      expect(t.getRect(_chip('👍')), thumbsRect);

      add.complete((
        200,
        {
          ..._row(
            reactions: [
              _thumbs(),
              {
                'emoji': '🔥',
                'count': 1,
                'reactorIds': ['alice'],
                'reactorNames': ['Alice'],
              },
            ],
          ),
          'reactionViewer': _viewer(2, ['🔥']),
        },
      ));
      await _settle(t);
      expect(_chip('🔥'), findsOneWidget);
      expect(t.element(_chip('🔥')), same(fire));

      await t.tap(_chip('🔥'));
      await t.pump();
      expect(_chip('🔥'), findsNothing);
      expect(t.element(_chip('👍')), same(thumbs));
      expect(t.getRect(_chip('👍')), thumbsRect);
      remove.complete((
        200,
        {..._row(), 'reactionViewer': _viewer(3, const [])},
      ));
      await _settle(t);
      expect(_chip('🔥'), findsNothing);
      expect(_reaction(t, '👍').count, 2);
      expect(t.element(_chip('👍')), same(thumbs));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a failed write puts the chip back and flashes it', (t) async {
    final (w, api, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    final write = Completer<(int, dynamic)>();
    api.routes['POST /messages/m1/reactions'] = (_) => write.future;
    await _mount(t, w);
    final element = t.element(_chip('👍'));
    final rect = t.getRect(_chip('👍'));
    await t.tap(_chip('👍'));
    await t.pump();
    expect(_reaction(t, '👍').count, 3);

    write.complete((500, {'error': 'Server error'}));
    await _settle(t);
    expect(_reaction(t, '👍').count, 2);
    expect(_reaction(t, '👍').reacted, isFalse);
    expect(w.messages.single.json['reactions'], [_thumbs()]);
    expect(t.element(_chip('👍')), same(element));
    expect(t.getRect(_chip('👍')), rect);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a failed first reaction removes the chip it inserted', (
    t,
  ) async {
    final (w, api, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    final write = Completer<(int, dynamic)>();
    api.routes['POST /messages/m1/reactions'] = (_) => write.future;
    await _mount(t, w);
    final result = w.toggleReaction(w.messages.single, '🔥');
    unawaited(result.catchError((_) {}));
    await t.pump();
    expect(_chip('🔥'), findsOneWidget);
    write.complete((403, {'error': 'Forbidden'}));
    await _settle(t);
    expect(_chip('🔥'), findsNothing);
    expect(w.messages.single.json['reactions'], [_thumbs()]);
    await expectLater(result, throwsA(anything));
  });

  testWidgets(
    'a socket row that predates the write does not undo the optimistic chip',
    (t) async {
      final (w, api, client) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final write = Completer<(int, dynamic)>();
      api.routes['POST /messages/m1/reactions'] = (_) => write.future;
      await _mount(t, w);
      final element = t.element(_chip('👍'));
      await t.tap(_chip('👍'));
      await t.pump();
      client.event('message:updated', _row());
      await t.pump();
      await t.pump();
      expect(_reaction(t, '👍').count, 3);
      expect(_reaction(t, '👍').reacted, isTrue);
      expect(t.element(_chip('👍')), same(element));
      write.complete((
        200,
        {
          ..._row(reactions: [_thumbs(mine: true)]),
          'reactionViewer': _viewer(2, ['👍']),
        },
      ));
      await _settle(t);
      expect(_reaction(t, '👍').count, 3);
      expect(_reaction(t, '👍').reacted, isTrue);
    },
  );

  testWidgets(
    'save: the menu label, state and Saved badge change on the first frame; '
    'a failure restores them',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      var total = 4;
      api.routes['GET /channels/saved'] = (_) =>
          (200, {'globalTotal': total, 'total': total, 'saved': []});
      final write = Completer<(int, dynamic)>();
      api.routes['POST /channels/saved'] = (_) => write.future;
      await _mount(t, w);
      expect(_badge(t), 4);
      final store = SavedCountStore.of(w);
      expect(store.isSaved('m1'), isFalse);

      final saving = store.setSaved('m1', true);
      unawaited(saving.catchError((_) {}));
      await t.pump();
      expect(store.isSaved('m1'), isTrue);
      expect(_badge(t), 5);

      write.complete((500, {'error': 'Server error'}));
      await _settle(t);
      await expectLater(saving, throwsA(anything));
      expect(store.isSaved('m1'), isFalse);
      expect(_badge(t), 4);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('save confirmed: the badge keeps the optimistic count and the '
      'revalidated total replaces it in place', (t) async {
    final (w, api, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    var total = 4;
    api.routes['GET /channels/saved'] = (_) =>
        (200, {'globalTotal': total, 'total': total, 'saved': []});
    final write = Completer<(int, dynamic)>();
    api.routes['POST /channels/saved'] = (_) => write.future;
    await _mount(t, w);
    final store = SavedCountStore.of(w);
    unawaited(store.setSaved('m1', true));
    await t.pump();
    expect(_badge(t), 5);
    total = 5;
    write.complete((200, {'ok': true}));
    await _settle(t);
    expect(store.isSaved('m1'), isTrue);
    expect(_badge(t), 5);
  });

  testWidgets('a message saved earlier shows "Remove from Saved" without '
      'visiting the Saved page (first Saved page loaded on connect)', (
    t,
  ) async {
    final (w, api, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    var saved = [
      {'messageId': 'm1', 'channelId': 'c1'},
    ];
    api.routes['GET /channels/saved'] = (_) => (
      200,
      {'globalTotal': saved.length, 'total': saved.length, 'saved': saved},
    );
    api.routes['DELETE /channels/saved/m1'] = (_) {
      saved = [];
      return (200, {'ok': true});
    };
    await _mount(t, w);
    expect(SavedCountStore.of(w).isSaved('m1'), isTrue);
    final rect = t.getRect(find.byType(RaftMessageRow));
    await t.longPressAt(Offset(rect.left + 2, rect.center.dy));
    await t.pumpAndSettle();
    expect(find.text('Remove from Saved'), findsOneWidget);
    expect(find.text('Save Message'), findsNothing);
    // Unsaving moves the id and the badge; the menu then offers Save again.
    await t.tap(find.text('Remove from Saved'));
    await _settle(t);
    expect(SavedCountStore.of(w).isSaved('m1'), isFalse);
    expect(_badge(t), 0);
  });

  testWidgets('the hover toolbar shows the saved state', (t) async {
    final (w, api, _) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    api.routes['GET /channels/saved'] = (_) =>
        (200, {'globalTotal': 1, 'total': 1, 'saved': []});
    final write = Completer<(int, dynamic)>();
    api.routes['POST /channels/saved'] = (_) => write.future;
    await _mount(t, w);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byType(RaftMessageRow)));
    await t.pump(const Duration(milliseconds: 200));
    final save = find.byKey(const ValueKey('message-save-m1'));
    expect(t.widget<RaftMessageToolbarAction>(save).active, isFalse);
    await t.tap(save);
    await t.pump();
    await mouse.moveTo(t.getCenter(find.byType(RaftMessageRow)));
    await t.pump();
    expect(t.widget<RaftMessageToolbarAction>(save).active, isTrue);
    expect(t.widget<RaftMessageToolbarAction>(save).label, 'Remove from Saved');
    write.complete((200, {'ok': true}));
    await _settle(t);
    await mouse.removePointer();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  group('Saved page remove', () {
    Map<String, dynamic> saved(String id) => {
      'messageId': id,
      'channelId': 'c1',
      'channelName': 'general',
      'channelType': 'channel',
      'content': 'Saved body $id',
      'senderType': 'user',
      'senderId': 'bob',
      'senderName': 'Bob',
      'createdAt': '2026-10-10T08:01:00.000Z',
      'savedAt': '2026-10-10T09:00:00.000Z',
    };

    Future<void> mountPage(WidgetTester t, WorkspaceController w) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftDensityScope(
              density: RaftDensity.desktop,
              child: Column(
                children: [
                  SavedSidebarEntry(controller: w, onTap: () {}),
                  Expanded(
                    child: ResourceView(
                      controller: w,
                      section: 'saved',
                      onMessage: (_, _) async {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settle(t);
    }

    for (final fail in [false, true]) {
      testWidgets(
        fail
            ? 'a failed remove puts the row, the count and the badge back'
            : 'remove drops the row and moves the badge on the first frame',
        (t) async {
          final (w, api, _) = (await t.runAsync(_fixture))!;
          addTearDown(w.dispose);
          var rows = [saved('m1'), saved('m2')];
          api.routes['GET /channels/saved'] = (_) => (
            200,
            {
              'saved': rows,
              'total': rows.length,
              'globalTotal': rows.length,
              'hasMore': false,
            },
          );
          final write = Completer<(int, dynamic)>();
          api.routes['DELETE /channels/saved/m1'] = (_) => write.future;
          await mountPage(t, w);
          expect(find.text('Saved body m1'), findsOneWidget);
          expect(find.text('Saved body m2'), findsOneWidget);
          expect(_badge(t), 2);
          final second = t.getRect(find.byKey(const ValueKey('saved-m2')));

          await t.tap(find.byType(RaftSavedToggle).first);
          await t.pump();
          // First frame, the DELETE still held.
          expect(find.text('Saved body m1'), findsNothing);
          expect(find.text('Saved body m2'), findsOneWidget);
          expect(_badge(t), 1);
          expect(
            t.getRect(find.byKey(const ValueKey('saved-m2'))).left,
            second.left,
          );

          if (fail) {
            write.complete((500, {'error': 'Server error'}));
          } else {
            rows = [saved('m2')];
            write.complete((200, {'ok': true}));
          }
          await _settle(t);
          expect(
            find.text('Saved body m1'),
            fail ? findsOneWidget : findsNothing,
          );
          expect(find.text('Saved body m2'), findsOneWidget);
          expect(_badge(t), fail ? 2 : 1);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        },
      );
    }
  });
}
