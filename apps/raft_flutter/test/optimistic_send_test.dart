import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_messages.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
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
  w.messageDomain.ledger.switchServer('s1');
  final rows = [for (var i = 1; i <= 3; i++) _row('m$i', i, 'Earlier $i')];
  w.messageDomain.ledger.ingest(rows, expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = {for (final r in rows) r['id'] as String};
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
  Locale? locale,
}) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(),
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

/// Web `handleSubmit` from the keyboard: the shortcut that reaches the
/// blocked-send notice (the disabled Send button itself does nothing).
Future<void> _keySend(WidgetTester t) async {
  await t.tap(_editor());
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.enter);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump();
}

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
        final pending = w.messageDomain.timeline().last;
        expect(WorkspaceMessages.isPendingSend(pending), isTrue);
        expect(pending.content, 'Hello optimistic');
        expect(pending.author, 'Alice');
        final key = 'message-${w.messageDomain.messageKey(pending)}';
        final rect = paintedMessage(t, w.messageDomain.messageKey(pending));
        expect(rect, isNotNull);
        expect(t.widget<TextField>(_editor()).controller!.text, isEmpty);
        final element = t.element(find.byKey(ValueKey(key)));

        void unchanged() {
          expect(paintedMessage(t, w.messageDomain.messageKey(pending)), rect);
          expect(find.byKey(ValueKey(key)), findsOneWidget);
          expect(t.element(find.byKey(ValueKey(key))), same(element));
          expect(
            w.messageDomain.timeline().where((m) => m.content == 'Hello optimistic'),
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
            () => w.messageDomain.messages.any((m) => m.id == 'sent-1'),
            unchanged,
          );
          expect(WorkspaceMessages.isPendingSend(w.messageDomain.timeline().last), false);
        }
        ack.complete((200, {'message': accepted}));
        await _frames(
          t,
          () => w.messageDomain.messages.any((m) => m.id == 'sent-1'),
          unchanged,
        );
        if (!socketFirst) {
          client.event('message:new', accepted);
          await _frames(t, () => true, unchanged);
        }
        final confirmed = w.messageDomain.timeline().last;
        expect(confirmed.id, 'sent-1');
        expect(WorkspaceMessages.isPendingSend(confirmed), isFalse);
        expect(w.messageDomain.messageKey(confirmed), w.messageDomain.messageKey(pending));
        expect(w.messageDomain.timeline().map((m) => m.id), ['m1', 'm2', 'm3', 'sent-1']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      },
    );
  }

  for (final socketFirst in [false, true]) {
    testWidgets('out-of-order confirmations paint server sequence '
        '(${socketFirst ? 'socket before HTTP' : 'HTTP before socket'})', (
      t,
    ) async {
      final (w, api, client) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final requests = <RequestOptions>[];
      final replies = <Completer<(int, dynamic)>>[];
      api.routes['POST /v2/messages'] = (request) {
        requests.add(request);
        final reply = Completer<(int, dynamic)>();
        replies.add(reply);
        return reply.future;
      };
      await _mount(t, w);
      try {
        for (final text in ['Slow A', 'Failed B', 'Fast C']) {
          await t.enterText(_editor(), text);
          await t.pump();
          await _tapSend(t);
          await t.pump();
        }
        await _frames(t, () => requests.length == 3);
        expect(requests.map((r) => r.data['content']), [
          'Slow A',
          'Failed B',
          'Fast C',
        ]);
        final pending = {
          for (final row in w.messageDomain.timeline())
            if (WorkspaceMessages.isPendingSend(row)) row.content: row,
        };
        final aKey = w.messageDomain.messageKey(pending['Slow A']!);
        final cKey = w.messageDomain.messageKey(pending['Fast C']!);
        final aElement = t.element(find.byKey(ValueKey('message-$aKey')));
        final cElement = t.element(find.byKey(ValueKey('message-$cKey')));
        await t.enterText(_editor(), 'Later draft');
        replies[1].complete((503, {'error': 'Fixture offline'}));
        await _frames(
          t,
          () => w.messageDomain.timeline().every((row) => row.content != 'Failed B'),
        );

        Future<void> accept(int index, String id, int seq) async {
          final row = {..._accepted(requests[index], id), 'seq': '$seq'};
          // The fixture client lives in runAsync. Deliver both transport
          // callbacks there before the fake-time UI frames consume them.
          Future<void> deliver(VoidCallback callback) async {
            await t.runAsync(() async {
              callback();
              await Future<void>.delayed(Duration.zero);
            });
          }

          if (socketFirst) {
            await deliver(() => client.event('message:new', row));
            await _frames(t, () => w.messageDomain.messages.any((m) => m.id == id));
          }
          await deliver(() => replies[index].complete((200, {'message': row})));
          await _frames(t, () => w.messageDomain.messages.any((m) => m.id == id));
          if (!socketFirst) {
            await deliver(() => client.event('message:new', row));
            await _frames(t, () => true);
          }
        }

        await accept(2, 'accepted-c', 4);
        await accept(0, 'accepted-a', 5);
        await _frames(
          t,
          () => t
              .widget<RaftMessageTimeline>(find.byType(RaftMessageTimeline))
              .messages
              .any((m) => m.metadata?['id'] == 'accepted-a'),
        );
        expect(w.messageDomain.timeline().map((row) => row.content), [
          'Earlier 1',
          'Earlier 2',
          'Earlier 3',
          'Fast C',
          'Slow A',
        ]);
        final aRect = paintedMessage(t, aKey);
        final cRect = paintedMessage(t, cKey);
        expect(aRect, isNotNull);
        expect(cRect, isNotNull);
        expect(
          cRect!.top,
          lessThan(aRect!.top),
          reason: 'Confirmed rows must paint in server sequence order.',
        );
        expect(
          t.element(find.byKey(ValueKey('message-$aKey'))),
          same(aElement),
        );
        expect(
          t.element(find.byKey(ValueKey('message-$cKey'))),
          same(cElement),
        );
        expect(
          t.widget<TextField>(_editor()).controller!.text,
          'Failed B\nLater draft',
        );
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }
    });
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
      final pending = w.messageDomain.timeline().last;
      expect(WorkspaceMessages.isPendingSend(pending), isTrue);
      expect(paintedMessage(t, w.messageDomain.messageKey(pending)), isNotNull);

      await _frames(t, () => w.error != null);
      // Web MessageInput: the optimistic row leaves, the text comes back.
      expect(find.byKey(ValueKey('message-${pending.id}')), findsNothing);
      expect(w.messageDomain.timeline().map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(t.widget<TextField>(_editor()).controller!.text, 'Retry me');
      expect(w.drafts['c1'], 'Retry me');
      expect(w.error, contains('Offline'));

      fail = false;
      await _tapSend(t);
      await t.pump();
      expect(paintedMessage(t, w.messageDomain.messageKey(pending)), isNotNull);
      await _frames(t, () => w.messageDomain.messages.any((m) => m.id == 'sent-2'));
      expect(requests, hasLength(2));
      expect(requests[1].data['randomId'], requests[0].data['randomId']);
      expect(w.messageDomain.timeline().map((m) => m.id), ['m1', 'm2', 'm3', 'sent-2']);
      expect(paintedMessage(t, w.messageDomain.messageKey(pending)), isNotNull);
      expect(t.widget<TextField>(_editor()).controller!.text, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'failure preserves the newer IME composition and restores the failed text once',
    (t) async {
      final (w, api, _) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final ack = Completer<(int, dynamic)>();
      api.routes['POST /v2/messages'] = (_) => ack.future;
      await _mount(t, w);
      await t.enterText(_editor(), 'Failed draft');
      await t.pump();
      await _tapSend(t);
      await t.pump();
      await t.tap(_editor());
      const composing = TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      t.testTextInput.updateEditingValue(composing);
      await t.pump();
      ack.complete((503, {'error': 'Fixture offline'}));
      await _frames(t, () => w.error != null);
      final controller = t.widget<TextField>(_editor()).controller!;
      expect(controller.value, composing);
      t.testTextInput.updateEditingValue(const TextEditingValue(
        text: '你', selection: TextSelection.collapsed(offset: 1),
      ));
      await t.pump();
      await t.pump();
      expect(controller.text, 'Failed draft\n你');
      expect(w.drafts['c1'], 'Failed draft\n你');
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
      final pending = w.messageDomain.timeline().last;
      expect(WorkspaceMessages.isPendingSend(pending), isTrue);
      expect(w.uploads(), isEmpty);
      final card = find.descendant(
        of: find.byKey(ValueKey('message-${w.messageDomain.messageKey(pending)}')),
        matching: find.byKey(const ValueKey('attachment-att-1')),
      );
      expect(card, findsOneWidget);
      final cardElement = t.element(card);
      final cardRect = t.getRect(card);
      final rowRect = paintedMessage(t, w.messageDomain.messageKey(pending));

      void cardUnchanged() {
        expect(paintedMessage(t, w.messageDomain.messageKey(pending)), rowRect);
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
        () => w.messageDomain.messages.any((m) => m.id == 'sent-3'),
        cardUnchanged,
      );
      expect(w.messageDomain.timeline().last.id, 'sent-3');
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
      w.messageDomain.state.threadParent = RaftMessage(_row('m3', 3, 'Earlier 3'));
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
      final pending = w.messageDomain.timeline(thread: true).single;
      expect(WorkspaceMessages.isPendingSend(pending), isTrue);
      final key = w.messageDomain.messageKey(pending);
      final rect = paintedMessage(t, key);
      expect(rect, isNotNull);
      expect(find.text('No replies yet'), findsNothing);
      final element = t.element(find.byKey(ValueKey('message-$key')));
      void unchanged() {
        expect(paintedMessage(t, key), rect);
        expect(t.element(find.byKey(ValueKey('message-$key'))), same(element));
        expect(w.messageDomain.timeline(thread: true), hasLength(1));
      }

      created.complete((200, {'threadChannelId': 't1'}));
      await _frames(t, () => request != null, unchanged);
      expect(w.threadChannelId, 't1');
      ack.complete((
        200,
        {'message': _accepted(request!, 'reply-1', channelId: 't1')},
      ));
      await _frames(t, () => w.replies.isNotEmpty, unchanged);
      expect(w.messageDomain.timeline(thread: true).single.id, 'reply-1');
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
      w.messageDomain.ledger.ingest(rows, expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1']!.addAll(rows.map((r) => r['id'] as String));
      final ack = Completer<(int, dynamic)>();
      RequestOptions? request;
      api.routes['POST /v2/messages'] = (o) {
        request = o;
        return ack.future;
      };
      await _mount(t, w);
      final dynamic state = t.state(find.byType(RaftChatView));
      final ScrollController viewport = state.viewport;
      viewport.jumpTo(viewport.offset - 1500);
      await t.pumpAndSettle();
      await t.enterText(_editor(), 'Sent while reading');
      await t.pump();
      await _tapSend(t);
      // The pending row is the user's own insert: the timeline returns to its
      // latest end as an own send always has.
      await t.pumpAndSettle();
      expect(state.distanceFromLatest(viewport.position), 0);
      final key = w.messageDomain.messageKey(w.messageDomain.timeline().last);
      final rect = paintedMessage(t, key);
      expect(rect, isNotNull);
      void unchanged() {
        expect(viewport.offset, viewport.position.maxScrollExtent);
        expect(paintedMessage(t, key), rect);
      }

      await _frames(t, () => request != null, unchanged);
      ack.complete((
        200,
        {
          // This case confirms at the latest end, after history through 69.
          'message': {..._accepted(request!, 'sent-4'), 'seq': '70'},
        },
      ));
      await _frames(
        t,
        () => w.messageDomain.messages.any((m) => m.id == 'sent-4'),
        unchanged,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );

  group(
    'an attachment-only send (Kevin: "Channel ID and content are required")',
    () {
      const file = {
        'id': 'att-1',
        'filename': '11606.mp4',
        'mimeType': 'video/mp4',
        'sizeBytes': 5,
      };

      Future<RequestOptions?> sendOnlyFiles(
        WidgetTester t,
        WorkspaceController w,
        _Api api, {
        int files = 1,
        Locale? locale,
      }) async {
        api.routes['POST /attachments/upload'] = (_) => (
          200,
          {
            'attachments': [
              {...file, 'id': 'att-${api.calls.length}'},
            ],
          },
        );
        RequestOptions? request;
        api.routes['POST /v2/messages'] = (o) {
          request = o;
          return (200, {'message': _accepted(o, 'sent-9')});
        };
        await _mount(t, w, locale: locale);
        for (var i = 0; i < files; i++) {
          unawaited(w.attachUpload('11606.mp4', Uint8List.fromList([1, 2, 3])));
        }
        await _frames(t, () => w.uploads().length == files && w.uploadsReady());
        await _tapSend(t);
        await t.pump();
        return request;
      }

      testWidgets(
        'sends "[1 attachment]" as the content with the attachment id',
        (t) async {
          final (w, api, _) = (await t.runAsync(_fixture))!;
          addTearDown(w.dispose);
          await sendOnlyFiles(t, w, api);
          await _frames(
            t,
            () => api.calls.any((c) => c.path == '/v2/messages'),
          );
          final request = api.calls.lastWhere((c) => c.path == '/v2/messages');
          expect(request.data['content'], '[1 attachment]');
          expect(request.data['attachmentIds'], hasLength(1));
          expect(request.data['channelId'], 'c1');
          // The optimistic row shows the same body as the server copy.
          expect(w.messageDomain.timeline().last.content, '[1 attachment]');
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        },
      );

      testWidgets('pluralises and localizes the body like Web', (t) async {
        final (w, api, _) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        await sendOnlyFiles(t, w, api, files: 2, locale: const Locale('zh'));
        await _frames(t, () => api.calls.any((c) => c.path == '/v2/messages'));
        final request = api.calls.lastWhere((c) => c.path == '/v2/messages');
        expect(request.data['content'], '[2 个附件]');
        expect(request.data['attachmentIds'], hasLength(2));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      });

      testWidgets('typed text still wins over the placeholder', (t) async {
        final (w, api, _) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        api.routes['POST /attachments/upload'] = (_) => (
          200,
          {
            'attachments': [file],
          },
        );
        api.routes['POST /v2/messages'] = (o) =>
            (200, {'message': _accepted(o, 'sent-9')});
        await _mount(t, w);
        unawaited(w.attachUpload('11606.mp4', Uint8List.fromList([1, 2, 3])));
        await _frames(t, () => w.uploads().isNotEmpty && w.uploadsReady());
        await t.enterText(_editor(), 'look');
        await t.pump();
        await _tapSend(t);
        await _frames(t, () => api.calls.any((c) => c.path == '/v2/messages'));
        expect(
          api.calls.lastWhere((c) => c.path == '/v2/messages').data['content'],
          'look',
        );
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      });

      testWidgets(
        'send while an upload runs posts nothing and shows the notice',
        (t) async {
          final (w, api, _) = (await t.runAsync(_fixture))!;
          addTearDown(w.dispose);
          final transfer = Completer<(int, dynamic)>();
          api.routes['POST /attachments/upload'] = (_) => transfer.future;
          api.routes['POST /v2/messages'] = (o) =>
              (200, {'message': _accepted(o, 'sent-9')});
          await _mount(t, w);
          unawaited(w.attachUpload('11606.mp4', Uint8List.fromList([1, 2, 3])));
          await _frames(t, () => w.uploads().isNotEmpty);
          expect(w.uploadsReady(), isFalse);
          await _tapSend(t);
          await _keySend(t);
          await t.pump(const Duration(milliseconds: 50));
          expect(api.calls.where((c) => c.path == '/v2/messages'), isEmpty);
          expect(
            w.composerErrorFor(),
            'Wait for attachments to finish uploading before sending.',
          );
          transfer.complete((
            200,
            {
              'attachments': [file],
            },
          ));
          await _frames(t, () => w.uploadsReady());
          await _tapSend(t);
          await _frames(
            t,
            () => api.calls.any((c) => c.path == '/v2/messages'),
          );
          expect(
            api.calls
                .lastWhere((c) => c.path == '/v2/messages')
                .data['content'],
            '[1 attachment]',
          );
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        },
      );

      testWidgets('send with a failed upload posts nothing and asks to retry', (
        t,
      ) async {
        final (w, api, _) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        api.routes['POST /attachments/upload'] = (_) =>
            (500, {'error': 'File storage unavailable.'});
        await _mount(t, w);
        unawaited(w.attachUpload('11606.mp4', Uint8List.fromList([1, 2, 3])));
        await _frames(t, () => w.uploads().any((u) => u.error != null));
        await _tapSend(t);
        await _keySend(t);
        await t.pump(const Duration(milliseconds: 50));
        expect(api.calls.where((c) => c.path == '/v2/messages'), isEmpty);
        expect(
          w.composerErrorFor(),
          'Remove or retry failed attachments before sending.',
        );
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      });

      testWidgets(
        'a rejected attachment-only send restores the files, not the body',
        (t) async {
          final (w, api, _) = (await t.runAsync(_fixture))!;
          addTearDown(w.dispose);
          api.routes['POST /attachments/upload'] = (_) => (
            200,
            {
              'attachments': [file],
            },
          );
          api.routes['POST /v2/messages'] = (_) =>
              (500, {'error': 'Something went wrong on the server'});
          await _mount(t, w);
          unawaited(w.attachUpload('11606.mp4', Uint8List.fromList([1, 2, 3])));
          await _frames(t, () => w.uploads().isNotEmpty && w.uploadsReady());
          await _tapSend(t);
          await _frames(t, () => w.error != null);
          expect(w.uploads(), hasLength(1));
          expect(w.drafts[w.draftScope()] ?? '', isEmpty);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        },
      );
    },
  );
}
