import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_ui/raft_ui.dart';

/// Acting on a pending-mention row (Add / Notify / Ignore / Add all) must end
/// the condition: the row leaves the strip, the strip leaves the composer, and
/// neither returns when the composer is left and re-entered.

RaftClient _client() {
  final client = RaftClient(
    origin: 'https://fixture.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'u'});
  client.selectServer('s');
  return client;
}

Map<String, dynamic> _row(String id, String handle) => {
  'resolutionId': id,
  'targetType': 'user',
  'targetHandle': handle,
  'availableActions': ['add', 'notify'],
};

RaftChannel _channel(String id) =>
    RaftChannel({'id': id, 'name': id, 'type': 'channel'});

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  // The status the server answers per resolution id; default is success.
  final answers = <String, String>{};
  final requests = <String>[];
  @override
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  ) async {
    requests.add('$action:${resolutionIds.join(',')}');
    return {
      for (final id in resolutionIds)
        id: {
          'resolutionId': id,
          'status': answers[id] ?? (action == 'notify' ? 'queued' : 'delivered'),
        },
    };
  }
}

void main() {
  late _Workspace w;

  Future<void> mount(WidgetTester t) async {
    final client = _client();
    w = _Workspace(client)
      ..channel = _channel('c1')
      ..pendingMentionActions['c1'] = [_row('r1', 'ann'), _row('r2', 'bob')]
      ..pendingMentionActions['c2'] = [_row('r9', 'cy')];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: PendingMentionActions(controller: w)),
      ),
    );
  }

  Future<void> switchChannel(WidgetTester t, String id) async {
    w.channel = _channel(id);
    w.notifyListeners();
    await t.pump();
  }

  // The Web fades a settled row at 450ms and removes it at 750ms.
  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
  }

  testWidgets('Notify success removes only that row and it does not return', (
    t,
  ) async {
    await mount(t);
    expect(find.text('@ann'), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
    await t.tap(find.text('Notify').first);
    await settle(t);
    expect(w.requests, ['notify:r1']);
    expect(find.text('@ann'), findsNothing);
    expect(find.text('@bob'), findsOneWidget);
    expect(w.pendingMentionsFor().map((r) => r['resolutionId']), ['r2']);
    // Leaving and re-entering the composer must not bring the row back.
    await switchChannel(t, 'c2');
    await switchChannel(t, 'c1');
    expect(find.text('@ann'), findsNothing);
    expect(find.text('@bob'), findsOneWidget);
  });

  testWidgets('Add success on the last row removes the whole strip', (t) async {
    await mount(t);
    await t.tap(find.text('Ignore').first);
    await t.pump();
    expect(find.text('@bob'), findsOneWidget);
    await t.tap(find.text('Add').first);
    await settle(t);
    expect(w.requests, ['add:r2']);
    expect(w.pendingMentionsFor(), isEmpty);
    expect(find.text('Add'), findsNothing);
    expect(find.text('Notify'), findsNothing);
    expect(find.text('Ignore'), findsNothing);
    await switchChannel(t, 'c2');
    await switchChannel(t, 'c1');
    expect(find.text('Notify'), findsNothing);
  });

  testWidgets('Ignore removes the row at once and sends nothing', (t) async {
    await mount(t);
    await t.tap(find.text('Ignore').first);
    await t.pump();
    expect(find.text('@ann'), findsNothing);
    expect(w.requests, isEmpty);
    await switchChannel(t, 'c2');
    await switchChannel(t, 'c1');
    expect(find.text('@ann'), findsNothing);
    expect(find.text('@bob'), findsOneWidget);
  });

  testWidgets('Add all: added rows leave, the row that failed stays', (
    t,
  ) async {
    await mount(t);
    w.answers['r2'] = 'dropped';
    await t.tap(find.text('Add All'));
    await settle(t);
    expect(w.requests, ['add:r1,r2']);
    expect(find.text('@ann'), findsNothing);
    expect(find.text('@bob'), findsOneWidget);
    expect(find.textContaining('Added 1 of 2.'), findsOneWidget);
    // Dismissing the row that could not be applied ends the strip and notice.
    await t.tap(find.text('Ignore').first);
    await t.pump();
    expect(w.pendingMentionsFor(), isEmpty);
    expect(find.textContaining('Added 1 of 2.'), findsNothing);
    expect(find.text('Ignore'), findsNothing);
  });

  testWidgets('another channel\'s pending rows are not shown here', (t) async {
    await mount(t);
    expect(find.text('@cy'), findsNothing);
    await switchChannel(t, 'c2');
    expect(find.text('@cy'), findsOneWidget);
    expect(find.text('@ann'), findsNothing);
    await switchChannel(t, 'c3');
    expect(find.byType(RaftPendingMentionActionStrip), findsNothing);
  });
}
