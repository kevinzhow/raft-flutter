import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final requests =
      <({String text, String? channelId, Completer<dynamic> response})>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') {
      final response = Completer<dynamic>();
      requests.add((
        text: query!['q'] as String,
        channelId: query['channelId'] as String?,
        response: response,
      ));
      return response.future;
    }
    if (path.endsWith('/members')) {
      return [
        {'userId': 'private-human', 'name': 'secret-person'},
      ];
    }
    if (path == '/agents') return [];
    if (path.endsWith('/machines')) return [];
    return {};
  }
}

void main() {
  late RaftClient client;
  late _Workspace w;
  setUp(() {
    client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'owner', 'name': 'Owner'});
    client.selectServer('s');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c', 'name': 'secret-channel', 'joined': true}),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'explicit channel entry sends channel filter and drops revoked results',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'search',
              initialSearchChannelId: 'c',
              restoreSearchState: false,
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(w.requests, hasLength(1));
      expect(w.requests.single.text, '');
      expect(w.requests.single.channelId, 'c');
      w.channels = [];
      w.notifyListeners();
      await tester.pump();
      w.requests.single.response.complete({
        'results': [
          {'id': 'old', 'channelId': 'c', 'content': 'Revoked private result'},
        ],
        'hasMore': false,
      });
      await tester.pumpAndSettle();
      expect(w.requests, hasLength(1));
      expect(find.textContaining('Revoked private result'), findsNothing);
    },
  );
  testWidgets('unavailable explicit channel never falls back to global query', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            initialQuery: 'secret',
            initialSearchChannelId: 'unavailable',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(w.requests, isEmpty);
    expect(find.text('This channel is no longer available.'), findsOneWidget);
  });
  testWidgets('debounced query drops late previous-query response', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump(const Duration(milliseconds: 210));
    expect(w.requests.single.text, 'first');
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump(const Duration(milliseconds: 210));
    expect(w.requests.last.text, 'second');
    w.requests.last.response.complete({
      'results': [
        {'id': 'second', 'channelId': 'c', 'content': 'Accepted second result'},
      ],
      'hasMore': false,
    });
    await tester.pumpAndSettle();
    w.requests.first.response.complete({
      'results': [
        {
          'id': 'first',
          'channelId': 'c',
          'content': 'Stale private first result',
        },
      ],
      'hasMore': false,
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Accepted second result'), findsOneWidget);
    expect(find.textContaining('Stale private first result'), findsNothing);
  });
  testWidgets('IME composition waits for commit before querying', (
    tester,
  ) async {
    await mount(tester);
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 210));
    expect(w.requests, isEmpty);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '你',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 210));
    expect(w.requests.single.text, '你');
    w.requests.single.response.complete({'results': [], 'hasMore': false});
    await tester.pumpAndSettle();
  });
  testWidgets(
    'same-controller guest transition clears directory and fences retained entity opener',
    (tester) async {
      await mount(tester);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.pump(const Duration(milliseconds: 210));
      w.requests.single.response.complete({'results': [], 'hasMore': false});
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ResourceView));
      final oldScope = state.authority as String;
      final entity = (state.currentSearchEntities as List).first;
      expect(find.text('secret-person'), findsOneWidget);
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.channels = [];
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('secret-person'), findsNothing);
      expect(find.text('secret-channel'), findsNothing);
      await state.openSearchEntity(entity, oldScope);
      expect(state.selectedSearchKey, isNull);
    },
  );
}
