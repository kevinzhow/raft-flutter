import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/search_text.dart';

typedef _Request = ({Map<String, dynamic> params, Completer<Object?> answer});

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};

  @override
  Future<RaftClientConfig> clientConfig() async => RaftClientConfig.fallback;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);

  final appRequests = <_Request>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/search') {
      final answer = Completer<Object?>();
      appRequests.add((params: {...?query}, answer: answer));
      return answer.future;
    }
    if (path == '/messages/search') {
      return {
        'results': [
          {
            'id': 'note',
            'channelId': 'general',
            'channelName': 'general',
            'channelType': 'channel',
            'senderId': 'owner',
            'senderType': 'user',
            'senderName': 'Owner',
            'content': 'A message about this topic',
            'createdAt': '2026-11-19T10:00:00Z',
          },
        ],
        'hasMore': false,
      };
    }
    return [];
  }
}

const _artifactId = 'pt_00000000-0000-4000-8000-000000000001';
const _secondId = 'pt_00000000-0000-4000-8000-000000000002';

Map<String, Object?> artifact(String id, String title) => {
  'card': {'id': id, 'title': title, 'kind': 'markdown'},
  'matches': [],
};

Map<String, Object?> response(Map<String, Object?> group) => {
  'groups': [
    {'app': 'unknown-app', 'items': []},
    {'app': 'artifacts', ...group},
  ],
};

void main() {
  late RaftClient client;
  late _Workspace workspace;

  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'owner', 'name': 'Owner'});
    client.selectServer('server');
    workspace = _Workspace(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'});
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  Future<void> mount(WidgetTester tester, {bool enabled = true}) async {
    ArtifactSession.of(workspace).debugSetEnabled(enabled);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'search',
            restoreSearchState: false,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pump();
  }

  Finder hit(String id) => find.byKey(ValueKey('app:artifacts:$id'));

  testWidgets('late Artifacts keep the cursor on the painted message', (
    tester,
  ) async {
    await mount(tester);
    await enter(tester, 'topic');
    expect(workspace.appRequests.single.params, {'q': 'topic'});
    expect(findSearchText('A message about this topic'), findsWidgets);
    workspace.appRequests.single.answer.complete(
      response({
        'items': [artifact(_artifactId, 'Topic notes')],
      }),
    );
    await tester.pumpAndSettle();
    expect(hit(_artifactId), findsOneWidget);
    expect(
      tester.widget<RaftSearchResultSurface>(hit(_artifactId)).selected,
      isFalse,
    );
    expect(
      tester.getTopLeft(hit(_artifactId)).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('search-message:note'))).dy,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.byType(ArtifactWorkspaceViewer), findsOneWidget);
    await tester.pumpAndSettle();

    final close = find.bySemanticsLabel('Close');
    await tester.tap(close.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactWorkspaceViewer), findsNothing);

    await tester.tap(hit(_artifactId));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactWorkspaceViewer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ArtifactWorkspaceViewer),
        matching: find.text('Topic notes'),
      ),
      findsOneWidget,
    );
    await tester.tap(close.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactWorkspaceViewer), findsNothing);
    expect(hit(_artifactId), findsOneWidget);
  });

  testWidgets('late app answers cannot replace the current query', (
    tester,
  ) async {
    await mount(tester);
    await enter(tester, 'old');
    await enter(tester, 'new');
    expect(workspace.appRequests.map((request) => request.params['q']), [
      'old',
      'new',
    ]);
    workspace.appRequests.last.answer.complete(
      response({
        'items': [artifact(_secondId, 'New document')],
      }),
    );
    workspace.appRequests.first.answer.complete(
      response({
        'items': [artifact(_artifactId, 'Old document')],
      }),
    );
    await tester.pumpAndSettle();
    expect(hit(_secondId), findsOneWidget);
    expect(hit(_artifactId), findsNothing);
  });

  testWidgets('retry and paging request only the affected app', (tester) async {
    await mount(tester);
    await enter(tester, 'topic');
    workspace.appRequests.single.answer.complete(
      response({'error': 'timeout'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Searching Artifacts took too long.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(workspace.appRequests.last.params, {
      'q': 'topic',
      'app': 'artifacts',
    });
    workspace.appRequests.last.answer.complete(
      response({
        'items': [artifact(_artifactId, 'Topic notes')],
        'nextCursor': 'next',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Searching Artifacts took too long.'), findsNothing);
    await tester.tap(find.text('Load more'));
    await tester.pump();
    expect(workspace.appRequests.last.params, {
      'q': 'topic',
      'app': 'artifacts',
      'cursor': 'next',
    });
    workspace.appRequests.last.answer.complete(
      response({
        'items': [
          artifact(_artifactId, 'Topic notes'),
          artifact(_secondId, 'More topics'),
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(hit(_artifactId), findsOneWidget);
    expect(hit(_secondId), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('an off deployment flag leaves message search available', (
    tester,
  ) async {
    await mount(tester, enabled: false);
    await enter(tester, 'topic');
    expect(workspace.appRequests, isEmpty);
    expect(find.byKey(const ValueKey('search-message:note')), findsOneWidget);
  });

  testWidgets('an IME commit with a collapsed composition searches apps', (
    tester,
  ) async {
    await mount(tester);
    await tester.showKeyboard(find.byType(TextField).first);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'topic',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 201));
    expect(workspace.appRequests, isEmpty);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'topic',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange.collapsed(5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 201));
    expect(workspace.appRequests.map((request) => request.params), [
      {'q': 'topic'},
    ]);
    workspace.appRequests.single.answer.complete(
      response({
        'items': [artifact(_artifactId, 'Topic notes')],
      }),
    );
    await tester.pumpAndSettle();
    expect(hit(_artifactId), findsOneWidget);
  });
}
