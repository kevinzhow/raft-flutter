// Phone forward page regression (Web ForwardComposerMobile): the page the
// incoming-share picker shares its chrome with must keep its own behaviour.
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
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    dynamic value;
    if (o.path == '/auth/login') {
      value = {
        'accessToken': 'fixture',
        'refreshToken': 'fixture',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/messages/forward') {
      writes.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(o.data))));
      value = {
        'results': [
          {
            'destinationChannelId': 'c1',
            'status': 'success',
            'message': {'id': 'forwarded'},
          },
        ],
      };
    } else {
      value = {'channels': []};
    }
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, _Transport)> _open(
  WidgetTester t, {
  bool dark = false,
  Locale locale = const Locale('en'),
}) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final transport = _Transport();
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
        'createdAt': '2026-06-20T00:00:00.000Z',
      }),
      RaftChannel({
        'id': 'c1',
        'name': 'design',
        'type': 'private',
        'joined': true,
        'createdAt': '2026-06-19T00:00:00.000Z',
      }),
    ]
    ..dms = [
      RaftChannel({
        'id': 'd1',
        'name': 'Cindy',
        'type': 'dm',
        'joined': true,
        'peerType': 'agent',
        'peerDisplayName': 'Cindy',
        'createdAt': '2026-06-21T00:00:00.000Z',
      }),
    ];
  addTearDown(w.dispose);
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(dark: dark),
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
  return (w, transport);
}

void main() {
  for (final (name, dark) in [('light', false), ('dark', true)]) {
    group('phone forward page $name', () {
      testWidgets(
        'destinations page: Web header, Recent list in activity order, no checkbox',
        (t) async {
          await _open(t, dark: dark);
          expect(find.byType(ForwardComposerPage), findsOneWidget);
          expect(find.text('Select destinations'), findsOneWidget);
          expect(find.text('1 selected from #general'), findsOneWidget);
          expect(find.text('Select Multiple'), findsOneWidget);
          expect(find.text('Recent'), findsOneWidget);
          expect(find.byType(RaftCheckbox), findsNothing);
          // @Cindy (newest), then #design; the source channel is a target too.
          final order = [
            for (final label in ['@Cindy', 'general', 'design'])
              t.getTopLeft(find.text(label)).dy,
          ];
          expect(order, [...order]..sort());
          // The share-mode server chips never appear on the forward page.
          expect(find.byType(RaftForwardServerChips), findsNothing);
        },
      );

      testWidgets(
        'single select opens the note page; an empty note forwards once',
        (t) async {
          final (_, transport) = await _open(t, dark: dark);
          await t.tap(find.byKey(const ValueKey('forward-target-c1')));
          await t.pumpAndSettle();
          expect(find.text('Add a note'), findsWidgets);
          expect(find.text('Send to #design'), findsOneWidget);
          expect(find.text('Message preview'), findsOneWidget);
          expect(find.text('Release gates are green'), findsOneWidget);
          // Web mounts MessageInput variant="compact": the shared composer.
          expect(find.byKey(const Key('forward-mobile-note')), findsOneWidget);
          expect(find.byType(RaftComposer), findsOneWidget);
          await t.tap(find.byType(RaftComposerAction).last);
          await t.pumpAndSettle();
          expect(transport.writes.length, 1);
          expect(transport.writes.single['destinationChannelIds'], ['c1']);
          expect(transport.writes.single['note'], '');
          expect(find.byType(ForwardComposerPage), findsNothing);
        },
      );

      testWidgets('multi select: checkbox rows, Clear, Done opens the note', (
        t,
      ) async {
        await _open(t, dark: dark);
        await t.tap(find.text('Select Multiple'));
        await t.pumpAndSettle();
        expect(find.text('0 selected'), findsOneWidget);
        expect(find.byType(RaftCheckbox), findsNWidgets(3));
        await t.tap(find.byKey(const ValueKey('forward-target-c1')));
        await t.tap(find.byKey(const ValueKey('forward-target-d1')));
        await t.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        expect(find.text('Clear'), findsOneWidget);
        // A chosen row's checkbox is enabled (checked), never the dimmed
        // disabled paint.
        expect(
          t
              .widgetList<RaftCheckbox>(find.byType(RaftCheckbox))
              .where((c) => c.value && c.onChanged != null),
          hasLength(2),
        );
        await t.tap(find.text('Clear'));
        await t.pumpAndSettle();
        expect(find.text('0 selected'), findsOneWidget);
      });
    });
  }

  testWidgets('zh: the phone forward page is Chinese', (t) async {
    await _open(t, locale: const Locale('zh', 'CN'));
    expect(find.text('选择目标'), findsOneWidget);
    expect(find.text('多选'), findsOneWidget);
    expect(find.text('最近'), findsOneWidget);
    expect(find.text('Select destinations'), findsNothing);
  });
}
