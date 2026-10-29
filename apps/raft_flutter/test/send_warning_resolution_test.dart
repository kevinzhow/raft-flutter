import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_ui/raft_ui.dart';

/// The "Not notified" / "agent is stopped" warnings a send leaves above the
/// composer: dismissing one ends it for good (also after leaving and coming
/// back to the conversation), and neither shows where it does not apply.

const _unresolved =
    'Not notified: ghost, nobody. Select a person or agent from the mention picker and try again if needed.';
const _stopped =
    'Message sent, but this agent is stopped and was not notified.';

RaftChannel _channel(String id, {String type = 'channel'}) =>
    RaftChannel({'id': id, 'name': id, 'type': type});

/// Answers every request at once with an empty list: the composer accessory
/// now also reads the channel's unfinished uploads
/// (`GET /attachments/upload-sessions/:channelId/active`).
class _EmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'uploads': <Object>[]}),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late WorkspaceController w;

  /// Lets the unfinished-uploads read started by the last channel change
  /// finish before the test ends.
  Future<void> settle(WidgetTester t) async {
    // Dio's request chain hops through several zero-length timers.
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> mount(WidgetTester t) async {
    final client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = _EmptyAdapter(),
    )..user = RaftRecord({'id': 'u'});
    client.selectServer('s');
    w = WorkspaceController(client)..channel = _channel('c1');
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: w,
            builder: (context, _) =>
                raftComposerAccessory(context, w) ?? const SizedBox(),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester t, RaftChannel channel) async {
    w.channel = channel;
    w.notifyListeners();
    await t.pump();
  }

  testWidgets('dismissing the unnotified-mention warning ends it for good', (
    t,
  ) async {
    await mount(t);
    expect(find.text(_unresolved), findsNothing);
    w.sendWarnings['c1'] = (
      unresolved: ['ghost', 'nobody'],
      agentStopped: false,
    );
    w.notifyListeners();
    await t.pump();
    expect(find.text(_unresolved), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Dismiss Unnotified Mention Warning'));
    await t.pump();
    expect(find.text(_unresolved), findsNothing);
    expect(w.sendWarningsFor().unresolved, isEmpty);
    await open(t, _channel('c2'));
    await open(t, _channel('c1'));
    expect(find.text(_unresolved), findsNothing);
    await settle(t);
  });

  testWidgets('dismissing the stopped-agent warning in a DM ends it for good', (
    t,
  ) async {
    await mount(t);
    await open(t, _channel('d1', type: 'dm'));
    w.sendWarnings['d1'] = (unresolved: [], agentStopped: true);
    w.notifyListeners();
    await t.pump();
    expect(find.text(_stopped), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Dismiss Delivery Warning'));
    await t.pump();
    expect(find.text(_stopped), findsNothing);
    await open(t, _channel('c1'));
    await open(t, _channel('d1', type: 'dm'));
    expect(find.text(_stopped), findsNothing);
    await settle(t);
  });

  testWidgets('a warning only shows in the conversation it belongs to', (
    t,
  ) async {
    await mount(t);
    w.sendWarnings['c1'] = (unresolved: ['ghost'], agentStopped: false);
    w.notifyListeners();
    await t.pump();
    expect(find.textContaining('Not notified: ghost'), findsOneWidget);
    await open(t, _channel('c2'));
    expect(find.textContaining('Not notified'), findsNothing);
    // The stopped-agent warning is for a DM; a channel never shows it, and a
    // DM never lists unresolved handles.
    w.sendWarnings['c2'] = (unresolved: [], agentStopped: true);
    w.notifyListeners();
    await t.pump();
    expect(find.text(_stopped), findsNothing);
    await open(t, _channel('d2', type: 'dm'));
    w.sendWarnings['d2'] = (unresolved: ['ghost'], agentStopped: false);
    w.notifyListeners();
    await t.pump();
    expect(find.textContaining('Not notified'), findsNothing);
    await settle(t);
  });
}
