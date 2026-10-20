import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/attachment_http.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'message_presentation_test.dart' show MessageAdapter;
import 'mobile_attachment_preview_page_test.dart'
    show backEvent, startPredictiveBack;
import 'support/app_services_fixture.dart';

/// A real 16x16 PNG, served by the stand-in storage host.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

class _Storage implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    _png,
    200,
    headers: {
      Headers.contentTypeHeader: ['image/png'],
      Headers.contentLengthHeader: ['${_png.length}'],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(MessageAdapter api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
}

Map<String, dynamic> _reply() => {
  'id': 'm5',
  'channelId': 'thread-1',
  'seq': '5',
  'senderType': 'user',
  'senderId': 'bob',
  'senderName': 'Bob',
  'content': 'A reply with a picture',
  'attachments': [
    {
      'id': 'att1',
      'filename': 'sheet.png',
      'mimeType': 'image/png',
      'width': 16,
      'height': 16,
    },
  ],
};

/// What the server returns for the thread; tests append to it.
final _served = <Map<String, dynamic>>[];

final _attachment = find.byKey(const ValueKey('attachment-att1'));

dynamic _state(WidgetTester tester) =>
    (tester.element(_attachment) as StatefulElement).state;

/// Opens the thread from Activity (a root tab, as on a phone with the
/// Activity tab on) and waits for the picture to decode.
Future<(WorkspaceController, dynamic)> _openThreadWithImage(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({
    MobileTabbarStore.preferenceKey: jsonEncode({
      'order': ['chat', 'tasks', 'activity', 'computers', 'members'],
      'enabled': ['chat', 'tasks', 'activity', 'computers'],
    }),
  });
  addTearDown(DevicePreferences.reset);
  await tester.runAsync(DevicePreferences.load);
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final storage = AttachmentHttp.shared.httpClientAdapter;
  AttachmentHttp.shared.httpClientAdapter = _Storage();
  addTearDown(() => AttachmentHttp.shared.httpClientAdapter = storage);
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final w = (await tester.runAsync(() async {
    final client = _Client(api);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    return WorkspaceController(client);
  }))!;
  addTearDown(w.dispose);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channels = [
    RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
  ];
  w.loading = false;
  w.connected = true;
  w.messageDomain.ledger.switchServer('s1');
  w.section = 'activity';
  final row = activityRow('thread', unread: 0, seq: '5');
  api.routes['GET /channels/inbox'] = (_) => {
    'items': [row],
    'totalCount': 1,
    'totalUnreadCount': 0,
    'hasMore': false,
  };
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /channels/unread'] = (_) => {'channels': {}};
  api.routes['GET /channels/c1'] = (_) => w.channels.first.json;
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['GET /channels/thread-1/followers'] = (_) => [];
  api.routes['GET /channels/c1/threads/parent'] = (_) => {
    'threadChannelId': 'thread-1',
  };
  api.routes['GET /messages/context/parent'] = (_) => {
    'messages': [
      {
        ..._reply(),
        'id': 'parent',
        'channelId': 'c1',
        'content': 'The parent message of the thread',
        'attachments': <dynamic>[],
      },
    ],
  };
  _served
    ..clear()
    ..add(_reply());
  api.routes['GET /messages/context/m5'] = (_) => {
    'messages': _served,
    'hasOlder': false,
    'hasNewer': false,
  };
  api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
  api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': _served};
  api.routes['GET /attachments/att1/url'] = (_) => {
    'url': 'https://storage.example.invalid/att1.png',
  };
  api.routes['POST /attachments/urls'] = (_) => {'urls': []};
  api.routes['POST /channels/thread-1/read'] = (_) => {
    'maxReadSeq': 5,
    'readStateVersion': 1,
  };
  api.routes['POST /channels/thread-1/read-all'] = (_) => {
    'maxReadSeq': 5,
    'readStateVersion': 1,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.brutal),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(light: RaftFamily.brutal),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('activity-thread-thread-1')));
  await tester.pumpAndSettle();
  expect(w.threadChannelId, 'thread-1');
  expect(_attachment, findsOneWidget);
  final dynamic state = _state(tester);
  for (var i = 0; i < 100 && state.imageProvider == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(state.imageProvider, isNotNull, reason: 'the picture decoded');
  expect(state.invalidated, isFalse);
  return (w, state);
}

void main() {
  main2();
  for (final predictive in [false, true]) {
    testWidgets(
      'the picture of a thread page stays while Back slides the page away '
      '(${predictive ? 'predictive back' : 'toolbar'})',
      (tester) async {
        final (w, state) = await _openThreadWithImage(tester);
        final provider = state.imageProvider;
        final before = _chrome(tester);
        expect(before.header, contains('Thread— #test'));
        expect(before.parent && before.begin && before.count, isTrue);
        if (predictive) {
          await startPredictiveBack(tester);
          await backEvent(tester, const MethodCall('commitBackGesture'));
        } else {
          await tester.tap(find.byKey(const Key('mobile-detail-back')));
          await tester.pump();
        }
        var framesWithPage = 0;
        for (
          var frame = 0;
          frame < 40 && _attachment.evaluate().isNotEmpty;
          frame++
        ) {
          expect(
            w.threadChannelId,
            isNull,
            reason: 'the workspace left the thread at the first frame',
          );
          final dynamic now = _state(tester);
          expect(identical(now, state), isTrue, reason: 'frame $frame');
          expect(now.invalidated, isFalse, reason: 'frame $frame');
          expect(now.imageProvider, same(provider), reason: 'frame $frame');
          // The leaving page keeps its title with the channel, its parent
          // message, its reply count and its rows where they were: the picture
          // may only move with the page's own slide.
          final shown = _chrome(tester);
          expect(
            shown.header,
            contains('Thread— #test'),
            reason: 'frame $frame',
          );
          expect(shown.parent, isTrue, reason: 'parent, frame $frame');
          expect(shown.begin, isTrue, reason: 'beginning, frame $frame');
          expect(shown.count, isTrue, reason: 'count, frame $frame');
          expect(shown.none, isFalse, reason: 'empty notice, frame $frame');
          expect(
            (shown.top - before.top).abs(),
            lessThan(24),
            reason: 'picture position, frame $frame',
          );
          framesWithPage++;
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          framesWithPage,
          greaterThan(3),
          reason: 'the page was on screen while it slid away',
        );
        await tester.pumpAndSettle();
        expect(_attachment, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('the current thread page still drops its picture when the '
      'workspace stops presenting its message', (tester) async {
    final (w, state) = await _openThreadWithImage(tester);
    // Same page, same location: the thread's rows are gone from the workspace.
    w.threadChannelId = null;
    w.notifyListeners();
    await tester.pump();
    expect(state.invalidated, isTrue);
    expect(state.imageProvider, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a covered page still drops its picture when the account '
      'changes', (tester) async {
    final (w, state) = await _openThreadWithImage(tester);
    await tester.tap(find.byKey(const Key('mobile-detail-back')));
    await tester.pump();
    expect(state.invalidated, isFalse);
    w.client.user = RaftRecord({'id': 'mallory'});
    w.notifyListeners();
    await tester.pump();
    expect(state.invalidated, isTrue);
    expect(state.imageProvider, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

/// What the leaving thread page shows right now: the title row with the
/// source channel, the parent message, the reply count, the empty notice and
/// where the picture sits.
({
  List<String> header,
  bool parent,
  bool begin,
  bool count,
  bool none,
  double top,
})
_chrome(WidgetTester tester) {
  bool seen(String text) =>
      find.textContaining(text, findRichText: true).evaluate().isNotEmpty;
  return (
    header: [
      for (final e in find.byType(RichText).evaluate())
        if ((e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy < 90)
          (e.widget as RichText).text.toPlainText(includePlaceholders: false),
    ],
    parent: seen('The parent message'),
    begin: seen('Beginning of replies'),
    count: seen('1 replies'),
    none: seen('No replies yet'),
    top: tester.getTopLeft(_attachment).dy,
  );
}

void main2() {
  for (final predictive in [false, true]) {
    testWidgets(
      'going back and opening the thread again shows the current replies and '
      'a picture that stays while the second Back slides it away '
      '(${predictive ? 'predictive back' : 'toolbar'})',
      (tester) async {
        final (w, state) = await _openThreadWithImage(tester);
        await tester.tap(find.byKey(const Key('mobile-detail-back')));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(_attachment, findsNothing);
        // While the thread is closed a reply lands on the server.
        _served.add({
          ..._reply(),
          'id': 'm6',
          'seq': '6',
          'content': 'A reply that landed while the thread was closed',
          'attachments': <dynamic>[],
        });
        await tester.tap(
          find.byKey(const ValueKey('activity-thread-thread-1')),
        );
        await tester.pumpAndSettle();
        dynamic now = _state(tester);
        for (var i = 0; i < 100 && now.imageProvider == null; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(
          find.textContaining('landed while the thread was closed').evaluate(),
          isNotEmpty,
          reason: 'the second visit shows the current reply',
        );
        expect(
          find.textContaining('2 replies', findRichText: true).evaluate(),
          isNotEmpty,
          reason: 'the second visit shows the current reply count',
        );
        final provider = now.imageProvider;
        expect(provider, isNotNull);
        if (predictive) {
          await startPredictiveBack(tester);
          await backEvent(tester, const MethodCall('commitBackGesture'));
        } else {
          await tester.tap(find.byKey(const Key('mobile-detail-back')));
          await tester.pump();
        }
        var frames = 0;
        for (var f = 0; f < 40 && _attachment.evaluate().isNotEmpty; f++) {
          now = _state(tester);
          expect(now.invalidated, isFalse, reason: 'frame $f');
          expect(now.imageProvider, same(provider), reason: 'frame $f');
          expect(
            find.textContaining('Preview unavailable', skipOffstage: false),
            findsNothing,
            reason: 'the picture did not fail, frame $f',
          );
          frames++;
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(frames, greaterThan(3));
        expect(w.threadChannelId, isNull);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
