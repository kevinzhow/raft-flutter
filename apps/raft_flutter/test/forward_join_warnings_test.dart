// Web ForwardComposerWarnings (v1.21.23): "Join {targets} before forwarding."
// with a Join button, Send held off until the public channels are joined, and
// the exposure warning for Joint Channel destinations.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/forward_messages_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

class _Transport implements HttpClientAdapter {
  final writes = <Map<String, dynamic>>[];
  final joins = <String>[];

  /// Channel ids whose join the server refuses.
  final refused = <String>{};
  List<Map<String, dynamic>> targets = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    dynamic value;
    var status = 200;
    if (o.path == '/auth/login') {
      value = {
        'accessToken': 'fixture',
        'refreshToken': 'fixture',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/messages/forward/targets/search') {
      value = {'targets': targets};
    } else if (o.path.endsWith('/join')) {
      final id = o.path.split('/')[2];
      joins.add(id);
      if (refused.contains(id)) {
        status = 403;
        value = {'error': 'Forbidden'};
      } else {
        value = {'id': id};
      }
    } else if (o.path == '/messages/forward') {
      final body = Map<String, dynamic>.from(jsonDecode(jsonEncode(o.data)));
      writes.add(body);
      value = {
        'results': [
          for (final id in body['destinationChannelIds'] as List)
            {
              'destinationChannelId': id,
              'status': 'success',
              'message': {'id': 'forwarded-$id'},
            },
        ],
      };
    } else {
      value = {'channels': []};
    }
    return ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _public(String id) => {
  'id': id,
  'channelId': id,
  'type': 'channel',
  'channelType': 'channel',
  'title': '#$id',
  'canForwardNow': false,
  'requiredAction': 'join_channel',
};

Map<String, dynamic> _joint(String id) => {
  'id': id,
  'channelId': id,
  'type': 'channel',
  'channelType': 'joint',
  'title': '#$id',
  'canForwardNow': true,
  'requiredAction': null,
};

Future<_Transport> _open(
  WidgetTester t, {
  required List<Map<String, dynamic>> targets,
  bool phone = false,
  Locale locale = const Locale('en'),
}) async {
  if (phone) {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }
  final transport = _Transport()..targets = targets;
  final client = (await t.runAsync(() async {
    final c = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = transport,
    );
    await c.login('fixture', 'fixture');
    return c;
  }))!;
  client.selectServer('s1');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'})
    ..channels = [
      RaftChannel({
        'id': 'src',
        'name': 'general',
        'type': 'channel',
        'joined': true,
      }),
    ];
  addTearDown(w.dispose);
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => RaftToastHost(child: child!),
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => forwardMessages(context, w, [
              RaftMessage({
                'id': 'm1',
                'messageType': 'chat',
                'channelId': 'src',
                'content': 'Release gates are green',
                'senderName': 'artin',
                'senderType': 'user',
                'createdAt': '2026-06-22T02:10:00.000Z',
              }),
            ]),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
  return transport;
}

Future<void> _search(WidgetTester t, String query) async {
  await t.enterText(find.widgetWithText(TextField, 'Search targets'), query);
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

RaftComposerAction _send(WidgetTester t) =>
    t.widget<RaftComposerAction>(find.byKey(const Key('composer-submit')));

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('desktop: a public channel not joined asks to be joined first', (
    t,
  ) async {
    final transport = await _open(t, targets: [_public('pub1')]);
    await _search(t, 'pub');
    // The row says it needs a join, like Web's "Not joined" hint.
    final notJoined = find.textContaining(
      RegExp('not joined', caseSensitive: false),
    );
    expect(notJoined, findsOneWidget);
    await t.tap(find.text('#pub1'));
    await t.pump();
    expect(find.text('Join #pub1 before forwarding.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forward-join-selected-channels')),
      findsOneWidget,
    );
    // Web: Send is held off, with the reason as its title.
    expect(_send(t).onPressed, isNull);
    expect(_send(t).tooltip, 'Join selected channels first');
    await t.tap(find.byKey(const ValueKey('forward-join-selected-channels')));
    await _settle(t);
    expect(transport.joins, ['pub1']);
    expect(find.text('Join #pub1 before forwarding.'), findsNothing);
    expect(notJoined, findsNothing);
    expect(_send(t).onPressed, isNotNull);
    expect(_send(t).tooltip, 'Send forward');
    await t.tap(find.byKey(const Key('composer-submit')));
    await _settle(t);
    // The join happened once, at the banner; sending only forwards.
    expect(transport.joins, ['pub1']);
    expect(transport.writes.single['destinationChannelIds'], ['pub1']);
    expect(find.byType(ForwardComposerPage), findsNothing);
  });

  testWidgets('a refused join keeps the banner and says which channel failed', (
    t,
  ) async {
    final transport = await _open(t, targets: [_public('pub1')]);
    transport.refused.add('pub1');
    await _search(t, 'pub');
    await t.tap(find.text('#pub1'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('forward-join-selected-channels')));
    await _settle(t);
    expect(find.text("Couldn't join #pub1. Try again."), findsOneWidget);
    expect(find.text('Join #pub1 before forwarding.'), findsOneWidget);
    expect(_send(t).onPressed, isNull);
    expect(transport.writes, isEmpty);
  });

  testWidgets('several channels: summary, then the partial join toast', (
    t,
  ) async {
    final transport = await _open(
      t,
      targets: [_public('a1'), _public('b2'), _public('c3')],
    );
    transport.refused.add('b2');
    await _search(t, 'x');
    for (final id in ['a1', 'b2']) {
      await t.tap(find.text('#$id'));
      await t.pump();
    }
    expect(find.text('Join #a1 and 1 more before forwarding.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('forward-join-selected-channels')));
    await _settle(t);
    expect(
      find.text('Joined 1 of 2 channels. Try the remaining 1.'),
      findsOneWidget,
    );
    // Only the refused channel is still waiting.
    expect(find.text('Join #b2 before forwarding.'), findsOneWidget);
    expect(_send(t).onPressed, isNull);
    transport.refused.clear();
    await t.tap(find.byKey(const ValueKey('forward-join-selected-channels')));
    await _settle(t);
    expect(transport.joins, ['a1', 'b2', 'b2']);
    expect(find.textContaining('before forwarding.'), findsNothing);
    expect(_send(t).onPressed, isNotNull);
  });

  testWidgets('every join refused: one toast with the count', (t) async {
    final transport = await _open(t, targets: [_public('a1'), _public('b2')]);
    transport.refused.addAll(['a1', 'b2']);
    await _search(t, 'x');
    await t.tap(find.text('#a1'));
    await t.pump();
    await t.tap(find.text('#b2'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('forward-join-selected-channels')));
    await _settle(t);
    expect(find.text("Couldn't join 2 channels. Try again."), findsOneWidget);
  });

  testWidgets('a Joint Channel destination shows the exposure warning', (
    t,
  ) async {
    await _open(t, targets: [_joint('jc1'), _public('pub1')]);
    await _search(t, 'j');
    const warning =
        'Joint channel destinations may expose this forwarded snapshot to people outside this server.';
    expect(find.text(warning), findsNothing);
    await t.tap(find.text('#jc1'));
    await t.pump();
    expect(find.text(warning), findsOneWidget);
    // No join banner for a channel that needs none.
    expect(find.byKey(const ValueKey('forward-join-banner')), findsNothing);
    expect(_send(t).onPressed, isNotNull);
    await t.tap(find.text('#jc1'));
    await t.pump();
    expect(find.text(warning), findsNothing);
  });

  testWidgets('phone: the note page carries the banner and holds Send', (
    t,
  ) async {
    final transport = await _open(t, targets: [_public('pub1')], phone: true);
    await _search(t, 'pub');
    await t.tap(find.text('#pub1'));
    await t.pumpAndSettle();
    expect(find.text('Add a note'), findsWidgets);
    expect(find.text('Join #pub1 before forwarding.'), findsOneWidget);
    expect(_send(t).onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('forward-join-selected-channels')));
    await _settle(t);
    expect(find.text('Join #pub1 before forwarding.'), findsNothing);
    expect(_send(t).onPressed, isNotNull);
    await t.tap(find.byKey(const Key('composer-submit')));
    await _settle(t);
    expect(transport.joins, ['pub1']);
    expect(transport.writes.single['destinationChannelIds'], ['pub1']);
  });

  testWidgets('zh: the banner, its button and the warning are Chinese', (
    t,
  ) async {
    await _open(
      t,
      targets: [_public('pub1'), _joint('jc1')],
      locale: const Locale('zh', 'CN'),
    );
    await t.enterText(find.widgetWithText(TextField, '搜索目标'), 'p');
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('#pub1'));
    await t.tap(find.text('#jc1'));
    await t.pump();
    expect(find.text('转发前请先加入 #pub1。'), findsOneWidget);
    expect(find.text('加入'), findsOneWidget);
    expect(find.text('联合频道的目标可能会把这份转发快照暴露给本服务器之外的人。'), findsOneWidget);
  });
}
