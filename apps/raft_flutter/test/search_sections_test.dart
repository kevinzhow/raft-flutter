import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/quick_switcher_host.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/search_text.dart';

class _Server extends WorkspaceController {
  _Server(super.client) {
    server = RaftRecord({'id': 'server', 'role': 'owner', 'plan': 'pro'});
    channels = [
      for (final number in Iterable<int>.generate(7, (index) => index + 1))
        RaftChannel({
          'id': 'project-$number',
          'name': 'project-$number',
          'type': 'channel',
          'joined': true,
        }),
    ];
    dms = [
      RaftChannel({'id': 'private-dm', 'name': 'Private peer', 'type': 'dm'}),
    ];
  }

  final requests = <Map<String, dynamic>>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path != '/messages/search') return [];
    requests.add({...?query});
    if (query?['q'] == 'broad') {
      return {'results': [], 'relaxedSkipped': 'too_broad'};
    }
    if (query?['q'] == 'rare' && query?['cursor'] == null) {
      return {
        'results': [],
        'incomplete': true,
        'nextCursor': 'older',
        'searchedThrough': '2026-11-01T10:00:00Z',
      };
    }
    return {
      'results': [
        if (query?['cursor'] == 'older')
          {
            'id': 'hit',
            'channelId': 'project-1',
            'channelName': 'project-1',
            'channelType': 'channel',
            'senderId': 'owner',
            'senderType': 'user',
            'senderName': 'Owner',
            'content': 'A rare result',
          },
      ],
      'hasMore': false,
    };
  }
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'owner', 'name': 'Owner'});
    selectServer('server');
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
}

void main() {
  late _Client client;
  late _Server workspace;
  late SearchMemoryStore memory;
  final opened = <String>[];
  final date = DateTime.utc(2026, 11, 19);

  setUp(() {
    client = _Client();
    workspace = _Server(client);
    memory = SearchMemoryStore();
    opened.clear();
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    String query = '',
    TargetPlatform platform = TargetPlatform.linux,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'search',
            initialQuery: query,
            restoreSearchState: false,
            searchMemory: memory,
            clock: () => date,
            onMessage: (id, _) async => opened.add(id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('entity expansion remembers the query and keeps one list', (
    tester,
  ) async {
    for (final size in const [Size(856, 944), Size(944, 856)]) {
      await mount(
        tester,
        query: 'project',
        platform: TargetPlatform.android,
        size: size,
      );
      expect(findSearchText('project-5'), findsOneWidget);
      expect(findSearchText('project-6'), findsNothing);
      await tester.tap(find.text('Show all 7'));
      await tester.pumpAndSettle();
      expect(findSearchText('project-6'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount(
        tester,
        query: 'project',
        platform: TargetPlatform.android,
        size: size,
      );
      expect(find.text('Show fewer'), findsOneWidget);
      await tester.tap(find.text('Show fewer'));
      await tester.pumpAndSettle();
      expect(findSearchText('project-6'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('channel-only picker excludes direct messages', (tester) async {
    await mount(tester, size: const Size(1000, 800));
    await tester.tap(find.text('Channel'));
    await tester.pumpAndSettle();
    expect(find.byType(RaftComboboxPanel), findsOneWidget);
    expect(find.textContaining('Private peer'), findsNothing);
  });

  testWidgets('arrow selection reveals and opens a result below the viewport', (
    tester,
  ) async {
    await mount(tester, query: 'project', size: const Size(390, 320));
    for (var index = 0; index < 4; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(findSearchText('project-5').hitTestable(), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(opened, ['project-5']);
  });

  testWidgets('right click opens the same channel as the row', (tester) async {
    await mount(tester, query: 'project-1');
    await tester.tap(
      findSearchText('project-1'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, ['project-1']);
  });

  testWidgets('successful empty search explains a skipped broad match', (
    tester,
  ) async {
    await mount(tester, query: 'broad');
    expect(
      find.textContaining('No message contains all of these words'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'rare');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(
      find.textContaining('No message contains all of these words'),
      findsNothing,
    );
  });

  testWidgets('free Search home and results explain the history window', (
    tester,
  ) async {
    workspace.server = RaftRecord({
      'id': 'server',
      'role': 'owner',
      'plan': 'free',
    });
    await mount(tester);
    final banner = find.textContaining('search covers only the last 30 days');
    expect(banner, findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'project');
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pumpAndSettle();
    expect(banner, findsOneWidget);
    expect(find.text('Upgrade to Pro'), findsOneWidget);
  });

  testWidgets('the overlay continues an incomplete search from its cursor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1150, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = QuickSwitcherHost(
      controller: workspace,
      actions: QuickSwitcherActions(
        openConversation: (_) async {},
        openDirectory: (_, _) {},
        openThread: ({
          required parentChannelId,
          required parentMessageId,
          required messageId,
          required threadChannelId,
        }) async {},
        openMessage: (_, _) async {},
        searchAll: (_) {},
      ),
      searchMemory: memory,
    );
    addTearDown(host.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Builder(
            builder: (context) => RaftButton(
              label: 'Show search',
              onPressed: () =>
                  host.open(context, entry: QuickSwitcherEntry.rail),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'rare');
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pumpAndSettle();
    expect(find.text('No matches yet'), findsOneWidget);
    await tester.tap(find.text('Continue searching'));
    await tester.pumpAndSettle();
    expect(workspace.requests.last['cursor'], 'older');
    expect(workspace.requests.last, isNot(contains('offset')));
    expect(findSearchText('A rare result'), findsOneWidget);
    expect(find.text('Continue searching'), findsNothing);
  });
}
