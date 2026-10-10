import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;

/// Routes answer `(status, body)`; a route may hold its answer on a Completer.
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

/// A client whose socket events the test injects.
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

Map<String, dynamic> _row(String id, int seq, String content, {String? by}) => {
  'id': id,
  'channelId': 'c1',
  'seq': '$seq',
  'senderId': by ?? 'bob',
  'senderType': 'user',
  'senderName': by == null ? 'Bob' : 'Alice',
  'createdAt': '2026-10-10T08:0$seq:00.000Z',
  'content': content,
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
  final rows = [for (var i = 1; i <= 3; i++) _row('m$i', i, 'Earlier $i')];
  w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {for (final r in rows) r['id'] as String};
  return (w, api, client);
}

/// The server copy of a send: the request's own randomId and content.
Map<String, dynamic> _accepted(
  RequestOptions request,
  String id, {
  String channelId = 'c1',
  List<Map<String, dynamic>>? attachments,
}) => {
  'id': id,
  'channelId': channelId,
  'seq': '50',
  'senderId': 'alice',
  'senderType': 'user',
  'senderName': 'Alice',
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'content': request.data['content'],
  'randomId': request.data['randomId'],
  'attachments': ?attachments,
};

Future<void> _mount(
  WidgetTester t,
  WorkspaceController w, {
  bool thread = false,
}) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftChatView(controller: w, thread: thread),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Finder _editor() => find.descendant(
  of: find.byType(RaftComposer),
  matching: find.byType(TextField),
);

Future<void> _tapSend(WidgetTester t) => t.tap(
  find.byWidgetPredicate(
    (widget) => widget is RaftComposerAction && widget.glyph == RaftGlyph.send,
  ),
);

/// Pumps frames (the mocked HTTP layer runs on fake time) until [done],
/// running [eachFrame] after every painted frame.
Future<void> _frames(
  WidgetTester t,
  bool Function() done, [
  void Function()? eachFrame,
]) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 16));
    eachFrame?.call();
  }
  expect(done(), isTrue);
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 16));
    eachFrame?.call();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final socketFirst in [false, true]) {
    testWidgets(
      'pending row paints on the first frame and the server copy replaces it '
      'in place (${socketFirst ? 'socket before HTTP' : 'HTTP before socket'})',
      (t) async {
        final (w, api, client) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        final ack = Completer<(int, dynamic)>();
        RequestOptions? request;
        api.routes['POST /v2/messages'] = (o) {
          request = o;
          return ack.future;
        };
        await _mount(t, w);
        await t.enterText(_editor(), 'Hello optimistic');
        await t.pump();
        await _tapSend(t);
        await t.pump();

        // First frame: the row, authored by the current user, and an empty editor.
        final pending = w.timeline().last;
        expect(WorkspaceController.isPendingSend(pending), isTrue);
        expect(pending.content, 'Hello optimistic');
        expect(pending.author, 'Alice');
        final key = 'message-${w.messageKey(pending)}';
        final rect = paintedMessage(t, w.messageKey(pending));
        expect(rect, isNotNull);
        expect(t.widget<TextField>(_editor()).controller!.text, isEmpty);
        final element = t.element(find.byKey(ValueKey(key)));

        void unchanged() {
          expect(paintedMessage(t, w.messageKey(pending)), rect);
          expect(find.byKey(ValueKey(key)), findsOneWidget);
          expect(t.element(find.byKey(ValueKey(key))), same(element));
          expect(
            w.timeline().where((m) => m.content == 'Hello optimistic'),
            hasLength(1),
          );
          expect(find.byKey(const ValueKey('message-sent-1')), findsNothing);
        }

        await _frames(t, () => request != null, unchanged);
        final accepted = _accepted(request!, 'sent-1');
        if (socketFirst) {
          client.event('message:new', accepted);
          await _frames(
            t,
            () => w.messages.any((m) => m.id == 'sent-1'),
            unchanged,
          );
          expect(WorkspaceController.isPendingSend(w.timeline().last), false);
        }
        ack.complete((200, {'message': accepted}));
        await _frames(
          t,
          () => w.messages.any((m) => m.id == 'sent-1'),
          unchanged,
        );
        if (!socketFirst) {
          client.event('message:new', accepted);
          await _frames(t, () => true, unchanged);
        }
        final confirmed = w.timeline().last;
        expect(confirmed.id, 'sent-1');
        expect(WorkspaceController.isPendingSend(confirmed), isFalse);
        expect(w.messageKey(confirmed), w.messageKey(pending));
        expect(w.timeline().map((m) => m.id), ['m1', 'm2', 'm3', 'sent-1']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      },
    );
  }

  testWidgets(
    'a failed send removes its row and restores the draft; retry reuses the identity',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final requests = <RequestOptions>[];
      var fail = true;
      api.routes['POST /v2/messages'] = (o) {
        requests.add(o);
        return fail
            ? (503, {'error': 'Offline'})
            : (200, {'message': _accepted(o, 'sent-2')});
      };
      await _mount(t, w);
      await t.enterText(_editor(), 'Retry me');
      await t.pump();
      await _tapSend(t);
      await t.pump();
      final pending = w.timeline().last;
      expect(WorkspaceController.isPendingSend(pending), isTrue);
      expect(paintedMessage(t, w.messageKey(pending)), isNotNull);

      await _frames(t, () => w.error != null);
      // Web MessageInput: the optimistic row leaves, the text comes back.
      expect(find.byKey(ValueKey('message-${pending.id}')), findsNothing);
      expect(w.timeline().map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(t.widget<TextField>(_editor()).controller!.text, 'Retry me');
      expect(w.drafts['c1'], 'Retry me');
      expect(w.error, contains('Offline'));

      fail = false;
      await _tapSend(t);
      await t.pump();
      expect(paintedMessage(t, w.messageKey(pending)), isNotNull);
      await _frames(t, () => w.messages.any((m) => m.id == 'sent-2'));
      expect(requests, hasLength(2));
      expect(requests[1].data['randomId'], requests[0].data['randomId']);
      expect(w.timeline().map((m) => m.id), ['m1', 'm2', 'm3', 'sent-2']);
      expect(paintedMessage(t, w.messageKey(pending)), isNotNull);
      expect(t.widget<TextField>(_editor()).controller!.text, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'an uploaded attachment sends with the row and keeps its card on confirmation',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      const file = {
        'id': 'att-1',
        'filename': 'notes.txt',
        'mimeType': 'text/plain',
        'sizeBytes': 5,
      };
      api.routes['POST /attachments/upload'] = (_) => (
        200,
        {
          'attachments': [file],
        },
      );
      final ack = Completer<(int, dynamic)>();
      RequestOptions? request;
      api.routes['POST /v2/messages'] = (o) {
        request = o;
        return ack.future;
      };
      await _mount(t, w);
      unawaited(
        w.attachUpload('notes.txt', Uint8List.fromList([1, 2, 3, 4, 5])),
      );
      await _frames(t, () => w.uploads().isNotEmpty && w.uploadsReady());
      await t.enterText(_editor(), 'With a file');
      await t.pump();
      await _tapSend(t);
      await t.pump();
      final pending = w.timeline().last;
      expect(WorkspaceController.isPendingSend(pending), isTrue);
      expect(w.uploads(), isEmpty);
      final card = find.descendant(
        of: find.byKey(ValueKey('message-${w.messageKey(pending)}')),
        matching: find.byKey(const ValueKey('attachment-att-1')),
      );
      expect(card, findsOneWidget);
      final cardElement = t.element(card);
      final cardRect = t.getRect(card);
      final rowRect = paintedMessage(t, w.messageKey(pending));

      void cardUnchanged() {
        expect(paintedMessage(t, w.messageKey(pending)), rowRect);
        expect(t.element(card), same(cardElement));
        expect(t.getRect(card), cardRect);
      }

      await _frames(t, () => request != null, cardUnchanged);
      expect(request!.data['attachmentIds'], ['att-1']);
      ack.complete((
        200,
        {
          'message': _accepted(request!, 'sent-3', attachments: [file]),
        },
      ));
      await _frames(
        t,
        () => w.messages.any((m) => m.id == 'sent-3'),
        cardUnchanged,
      );
      expect(w.timeline().last.id, 'sent-3');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'the first reply creates its thread under a pending row that stays in place',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      w.threadParent = RaftMessage(_row('m3', 3, 'Earlier 3'));
      final created = Completer<(int, dynamic)>();
      final ack = Completer<(int, dynamic)>();
      RequestOptions? request;
      api.routes['POST /channels/c1/threads'] = (_) => created.future;
      api.routes['POST /v2/messages'] = (o) {
        request = o;
        return ack.future;
      };
      await _mount(t, w, thread: true);
      expect(find.text('No replies yet'), findsOneWidget);
      await t.enterText(_editor(), 'First reply');
      await t.pump();
      await _tapSend(t);
      await t.pump();
      final pending = w.timeline(thread: true).single;
      expect(WorkspaceController.isPendingSend(pending), isTrue);
      final key = w.messageKey(pending);
      final rect = paintedMessage(t, key);
      expect(rect, isNotNull);
      expect(find.text('No replies yet'), findsNothing);
      final element = t.element(find.byKey(ValueKey('message-$key')));
      void unchanged() {
        expect(paintedMessage(t, key), rect);
        expect(t.element(find.byKey(ValueKey('message-$key'))), same(element));
        expect(w.timeline(thread: true), hasLength(1));
      }

      created.complete((200, {'threadChannelId': 't1'}));
      await _frames(t, () => request != null, unchanged);
      expect(w.threadChannelId, 't1');
      ack.complete((
        200,
        {'message': _accepted(request!, 'reply-1', channelId: 't1')},
      ));
      await _frames(t, () => w.replies.isNotEmpty, unchanged);
      expect(w.timeline(thread: true).single.id, 'reply-1');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'sending while scrolled up returns to latest at once; confirmation does not move',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final rows = [
        for (var i = 10; i < 70; i++)
          {
            ..._row('r$i', i, List.filled(i % 3 + 1, 'Row $i').join('\n')),
            'createdAt': '2026-10-10T08:00:00.000Z',
          },
      ];
      w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1']!.addAll(rows.map((r) => r['id'] as String));
      final ack = Completer<(int, dynamic)>();
      RequestOptions? request;
      api.routes['POST /v2/messages'] = (o) {
        request = o;
        return ack.future;
      };
      await _mount(t, w);
      final dynamic state = t.state(find.byType(RaftChatView));
      final ScrollController viewport = state.viewport;
      viewport.jumpTo(viewport.offset + 1500);
      await t.pumpAndSettle();
      await t.enterText(_editor(), 'Sent while reading');
      await t.pump();
      await _tapSend(t);
      // The pending row is the user's own insert: the timeline returns to its
      // latest end as an own send always has.
      await t.pumpAndSettle();
      expect(state.distanceFromLatest(viewport.position), 0);
      final key = w.messageKey(w.timeline().last);
      final rect = paintedMessage(t, key);
      expect(rect, isNotNull);
      void unchanged() {
        expect(viewport.offset, viewport.position.minScrollExtent);
        expect(paintedMessage(t, key), rect);
      }

      await _frames(t, () => request != null, unchanged);
      ack.complete((200, {'message': _accepted(request!, 'sent-4')}));
      await _frames(
        t,
        () => w.messages.any((m) => m.id == 'sent-4'),
        unchanged,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );
}
