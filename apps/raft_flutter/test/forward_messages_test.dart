import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/forward_messages_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

ForwardAttempt _attempt() => ForwardAttempt(
  requestId: 'stable',
  sources: ['m1'],
  destinations: ['c1', 'c2'],
  note: '  中文 日本語  ',
);
Map<String, dynamic> _success(String id) => {
  'destinationChannelId': id,
  'status': 'success',
  'message': {'id': 'forward-$id'},
};

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
    } else if (o.path == '/messages/forward/targets/search') {
      value = {
        'targets': [
          for (final id in ['c1', 'c2'])
            {
              'id': id,
              'channelId': id,
              'type': 'channel',
              'title': '#$id',
              'canForwardNow': true,
            },
        ],
      };
    } else if (o.path == '/messages/forward') {
      writes.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(o.data))));
      value = {
        'results': [
          _success('c1'),
          if (writes.length > 1)
            _success('c2')
          else
            {
              'destinationChannelId': 'c2',
              'status': 'failed',
              'error': 'Unavailable',
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

void main() {
  test('partial receipts keep successes and immutable exact retry payload', () {
    final sources = ['m1'], destinations = ['c1', 'c2'];
    final a = ForwardAttempt(
      requestId: 'stable',
      sources: sources,
      destinations: destinations,
      note: '  中文 日本語  ',
    );
    sources.add('changed');
    destinations.clear();
    expect(a.payload['sourceMessageIds'], ['m1']);
    expect(a.destinations, ['c1', 'c2']);
    expect(a.payload['note'], '中文 日本語');
    a.apply({
      'results': [
        _success('c1'),
        {
          'destinationChannelId': 'c2',
          'status': 'failed',
          'error': 'Unavailable',
        },
      ],
    });
    expect(a.completed, false);
    expect(a.outcomes, {'c1': 'success', 'c2': 'failed'});
    a.apply({
      'results': [_success('c1'), _success('c2')],
    });
    expect(a.completed, true);
    expect(() => a.payload['requestId'] = 'changed', throwsUnsupportedError);
  });
  test('missing duplicate and uncorrelated receipts never become success', () {
    final a = _attempt();
    a.apply({
      'results': [_success('c1'), _success('c1'), _success('other')],
    });
    expect(a.completed, false);
    expect(a.outcomes.values, everyElement('unknown'));
    a.apply({
      'results': [
        {'destinationChannelId': 'c1', 'status': 'success'},
        _success('c2'),
      ],
    });
    expect(a.outcomes['c1'], 'unknown');
    expect(a.outcomes['c2'], 'success');
  });
  test('a later incomplete response cannot erase an accepted success', () {
    final a = _attempt();
    a.apply({
      'results': [_success('c1'), _success('c2')],
    });
    a.apply({'results': []});
    expect(a.completed, true);
    expect(() => a.apply({}), throwsA(isA<RaftApiException>()));
  });
  testWidgets(
    'partial batch stays visible and retry reuses request and exact destinations',
    (tester) async {
      final t = _Transport();
      final client = (await tester.runAsync(() async {
        final c = RaftClient(
          origin: 'https://example.invalid',
          sessionStore: MemorySessionStore(),
          transport: Dio()..httpClientAdapter = t,
        );
        await c.login('fixture', 'fixture');
        return c;
      }))!;
      client.selectServer('s1');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(w.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => forwardMessages(context, w, [
                  RaftMessage({
                    'id': 'm1',
                    'messageType': 'chat',
                    'channelId': 'source',
                  }),
                ]),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search channels or people'),
        'c',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('#c1'));
      await tester.pump();
      await tester.tap(find.text('#c2'));
      await tester.pump();
      await tester.tap(find.widgetWithText(RaftButton, 'Forward'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ForwardMessagesDialog), findsOneWidget);
      expect(find.text('Forwarded'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Search channels or people'),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(RaftButton, 'Retry'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(t.writes.length, 2);
      expect(t.writes[1], t.writes[0]);
      expect(find.byType(ForwardMessagesDialog), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets(
    'same-generation role loss closes retained forward callback before mutation',
    (tester) async {
      final t = _Transport();
      final client = (await tester.runAsync(() async {
        final c = RaftClient(
          origin: 'https://example.invalid',
          sessionStore: MemorySessionStore(),
          transport: Dio()..httpClientAdapter = t,
        );
        await c.login('fixture', 'fixture');
        return c;
      }))!;
      client.selectServer('s1');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(w.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => forwardMessages(context, w, [
                  RaftMessage({'id': 'm1', 'messageType': 'chat'}),
                ]),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search channels or people'),
        'c',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('#c1'));
      await tester.pump();
      final submit = tester
          .widget<RaftButton>(find.widgetWithText(RaftButton, 'Forward'))
          .onPressed!;
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      w.notifyListeners();
      submit();
      await tester.pumpAndSettle();
      expect(t.writes, isEmpty);
      expect(find.byType(ForwardMessagesDialog), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    },
  );
}
