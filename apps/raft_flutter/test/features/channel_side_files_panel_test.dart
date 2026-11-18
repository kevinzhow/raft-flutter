import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/channel_side_files_artifacts.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../flutter_test_config.dart' show leakDebt;
import '../support/artifact_fake_client.dart';
import 'source_channel_files_view_test.dart' show fileRow;

/// The channel Files panel as the Files card beside the chat shows it (Web
/// v1.24 ChannelFilesPanel): the conversation's Artifacts above the files, the
/// compact row, pull to refresh on a touch screen.

String artifactIdOf(int n) => 'pt_db491d86-6156-4fe1-a742-01890ddbff0$n';

Map<String, Object?> rows(List<int> ns, [String? next]) => {
  'rows': [
    for (final n in ns)
      {
        'card': artifactCardJson(
          id: artifactIdOf(n),
          title: 'Report $n',
          version: 3,
          latest: 3,
        ),
      },
  ],
  'nextCursor': next,
};

SourceChannelFilesStore filesStore(
  Future<Map<String, dynamic>> Function(int call) answer,
) {
  var calls = 0;
  return SourceChannelFilesStore(
    channelId: 'channel',
    authority: () => 'current',
    get: (_, {query}) => answer(++calls),
  );
}

Map<String, dynamic> page(List<String> ids, [String? next]) => {
  'files': [for (final id in ids) fileRow(id)],
  'nextCursor': next,
};

ConversationArtifactsStore artifactsStore(
  Future<Object?> Function(String path) answer, {
  bool Function()? enabled,
}) => ConversationArtifactsStore(
  conversationId: 'channel',
  get: answer,
  enabled: enabled ?? () => true,
  authority: () => 'current',
);

Future<void> mount(
  WidgetTester t, {
  required SourceChannelFilesStore store,
  ConversationArtifactsStore? artifacts,
  bool compact = false,
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(390, 700),
  void Function(ArtifactCard)? onOpenArtifact,
  Future<void> Function(SourceChannelFileEntry)? onPreview,
}) async {
  await store.load();
  await artifacts?.load();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      builder: (context, child) => RaftToastHost(child: child!),
      home: Scaffold(
        body: SourceChannelFilesProjectionView(
          store: store,
          artifacts: artifacts,
          compact: compact,
          formatCreatedAt: (_) => 'Oct 8, 10:30 AM',
          formatCompactDate: (_) => 'Oct 8',
          onOpenArtifact: onOpenArtifact ?? (_) {},
          onPreview: onPreview ?? (_) async {},
          onOpenSource: (_) async {},
          onDownload: (_) async {},
        ),
      ),
    ),
  );
  await t.pump();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    store.dispose();
    artifacts?.dispose();
  });
}

Finder artifactRow(int n) =>
    find.byKey(ValueKey('conversation-artifact-${artifactIdOf(n)}'));

void main() {
  // The controller keeps its channel files stores for the session.
  leakDebt(const ['SourceChannelFilesStore']);
  group('conversation Artifacts above the files', () {
    testWidgets('rows render above the files and a tap opens the artifact', (
      t,
    ) async {
      final opened = <String>[];
      await mount(
        t,
        store: filesStore((_) async => page(['a'])),
        artifacts: artifactsStore((_) async => rows([1, 2])),
        onOpenArtifact: (card) => opened.add(card.id),
      );
      expect(find.text('Report 1'), findsOneWidget);
      expect(find.text('v3'), findsWidgets);
      expect(
        t.getTopLeft(artifactRow(2)).dy,
        lessThan(t.getTopLeft(find.byKey(const ValueKey('channel-file-a'))).dy),
      );
      await t.tap(artifactRow(2));
      await t.pump();
      expect(opened, [artifactIdOf(2)]);
    });

    testWidgets('Artifacts off for the server: only the files', (t) async {
      await mount(
        t,
        store: filesStore((_) async => page(['a'])),
        artifacts: artifactsStore((_) async => rows([1]), enabled: () => false),
      );
      expect(artifactRow(1), findsNothing);
      expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
    });

    testWidgets('a failed read says so, Try again loads the rows', (t) async {
      var fail = true;
      await mount(
        t,
        store: filesStore((_) async => page(['a'])),
        artifacts: artifactsStore((_) async {
          if (fail) throw const RaftApiException('network');
          return rows([1]);
        }),
      );
      expect(
        find.text("Couldn't load this conversation's Artifacts."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(
        find.text("Couldn't load this conversation's Artifacts."),
        findsNothing,
      );
      expect(artifactRow(1), findsOneWidget);
    });

    testWidgets('Show more appends; a failed page says so and keeps the rows', (
      t,
    ) async {
      var failMore = true;
      await mount(
        t,
        store: filesStore((_) async => page(['a'])),
        artifacts: artifactsStore((path) async {
          if (!path.contains('cursor=c2')) return rows([1], 'c2');
          if (failMore) throw const RaftApiException('network');
          return rows([2]);
        }),
      );
      await t.tap(find.text('Show more Artifacts'));
      await t.pumpAndSettle();
      expect(find.text("Couldn't load more Artifacts."), findsOneWidget);
      expect(artifactRow(1), findsOneWidget);
      failMore = false;
      await t.tap(find.text('Show more Artifacts'));
      await t.pumpAndSettle();
      expect(find.text("Couldn't load more Artifacts."), findsNothing);
      expect(artifactRow(2), findsOneWidget);
      expect(find.text('Show more Artifacts'), findsNothing);
    });

    testWidgets('no files but Artifacts: the list, not the empty state', (
      t,
    ) async {
      await mount(
        t,
        store: filesStore((_) async => page([])),
        artifacts: artifactsStore((_) async => rows([1])),
      );
      expect(artifactRow(1), findsOneWidget);
      expect(find.text('No files yet'), findsNothing);
    });

    testWidgets('no files and a failed Artifacts read: the error, not empty', (
      t,
    ) async {
      await mount(
        t,
        store: filesStore((_) async => page([])),
        artifacts: artifactsStore(
          (_) async => throw const RaftApiException('x'),
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('No files yet'), findsNothing);
    });

    testWidgets('no files and no Artifacts: the empty state', (t) async {
      await mount(
        t,
        store: filesStore((_) async => page([])),
        artifacts: artifactsStore((_) async => rows([])),
      );
      expect(find.text('No files yet'), findsOneWidget);
    });
  });

  group('ConversationArtifactsStore', () {
    RaftApiException coded(String code, int status) =>
        RaftApiException.response(
          code,
          status: status,
          body: {'error': code, 'code': code},
        );

    test(
      'a conversation the reader cannot see is empty, not an error',
      () async {
        final store = artifactsStore(
          (_) async => throw coded('TARGET_NOT_FOUND', 404),
        );
        await store.load();
        expect(store.status, ConversationArtifactsStatus.ready);
        expect(store.cards, isEmpty);
      },
    );

    test('ARTIFACTS_NOT_ENABLED hides the section', () async {
      final store = artifactsStore(
        (_) async => throw coded('ARTIFACTS_NOT_ENABLED', 403),
      );
      await store.load();
      expect(store.status, ConversationArtifactsStatus.hidden);
    });

    test(
      'a reload keeps the rows on screen and replaces them in place',
      () async {
        var round = 0;
        final store = artifactsStore(
          (_) async => rows(++round == 1 ? [1, 2] : [2, 3]),
        );
        await store.load();
        final seen = <ConversationArtifactsStatus>[];
        store.addListener(() => seen.add(store.status));
        await store.load();
        expect(
          seen.every((s) => s == ConversationArtifactsStatus.ready),
          isTrue,
        );
        expect(
          [for (final c in store.cards) c.id],
          [artifactIdOf(2), artifactIdOf(3)],
        );
      },
    );

    test('a failed background reload keeps the rows', () async {
      var round = 0;
      final store = artifactsStore((_) async {
        if (++round == 2) throw const RaftApiException('x');
        return rows([1]);
      });
      await store.load();
      await store.load();
      expect(store.status, ConversationArtifactsStatus.ready);
      expect(store.cards, hasLength(1));
    });
  });

  group('pull to refresh', () {
    Future<void> pull(WidgetTester t) async {
      await t.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await t.pumpAndSettle();
    }

    testWidgets('a touch pull reloads page 1 and swaps it in', (t) async {
      var round = 0;
      await mount(
        t,
        store: filesStore((_) async => page(++round == 1 ? ['a'] : ['b'])),
      );
      expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
      await pull(t);
      expect(find.byKey(const ValueKey('channel-file-a')), findsNothing);
      expect(find.byKey(const ValueKey('channel-file-b')), findsOneWidget);
      expect(round, 2);
    });

    testWidgets('a failed pull keeps the rows and toasts', (t) async {
      var round = 0;
      await mount(
        t,
        store: filesStore((_) async {
          if (++round == 2) throw const RaftApiException('x');
          return page(['a']);
        }),
      );
      await pull(t);
      expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
      expect(find.text('Could not load files.'), findsOneWidget);
    });

    testWidgets('an unfolded phone is still a finger: it pulls', (t) async {
      var round = 0;
      await mount(
        t,
        size: const Size(856, 944),
        store: filesStore((_) async => page(++round == 1 ? ['a'] : ['b'])),
      );
      await pull(t);
      expect(find.byKey(const ValueKey('channel-file-b')), findsOneWidget);
    });

    testWidgets('a mouse window never pulls', (t) async {
      var round = 0;
      await mount(
        t,
        platform: TargetPlatform.linux,
        store: filesStore((_) async => page(++round == 1 ? ['a'] : ['b'])),
      );
      await pull(t);
      expect(round, 1);
      expect(
        t
            .widgetList<RaftPullToRefresh>(find.byType(RaftPullToRefresh))
            .any((refresh) => refresh.enabled),
        isFalse,
      );
    });

    testWidgets('the empty state pulls too', (t) async {
      var round = 0;
      await mount(
        t,
        store: filesStore((_) async => page(++round == 1 ? [] : ['b'])),
      );
      expect(find.text('No files yet'), findsOneWidget);
      await pull(t);
      expect(find.byKey(const ValueKey('channel-file-b')), findsOneWidget);
    });
  });

  group('compact rows (the Files card)', () {
    testWidgets('one line: name with its size, the compact date, one menu', (
      t,
    ) async {
      final previewed = <String>[];
      await mount(
        t,
        compact: true,
        store: filesStore((_) async => page(['a'])),
        onPreview: (file) async => previewed.add(file.id),
      );
      final row = find.byKey(const ValueKey('channel-file-a'));
      expect(t.getSize(row).height, lessThanOrEqualTo(60));
      expect(find.text('Public 中文.txt'), findsOneWidget);
      expect(find.text('1.0 KB'), findsOneWidget);
      expect(
        t.getCenter(find.text('1.0 KB')).dy,
        closeTo(t.getCenter(find.text('Public 中文.txt')).dy, 2),
      );
      expect(find.text('Oct 8'), findsOneWidget);
      expect(find.text('Oct 8, 10:30 AM'), findsNothing);
      expect(
        find.byKey(const ValueKey('channel-file-overflow-a')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('channel-file-jump-a')), findsNothing);
      await t.tap(find.byKey(const ValueKey('channel-file-preview-a')));
      await t.pump();
      expect(previewed, ['a']);
      await t.tap(find.byKey(const ValueKey('channel-file-overflow-a')));
      await t.pumpAndSettle();
      expect(find.text('Jump to original message'), findsOneWidget);
      expect(find.text('Download file'), findsOneWidget);
    });

    testWidgets('a mouse is a shorter row than a finger', (t) async {
      double height(WidgetTester t) =>
          t.getSize(find.byKey(const ValueKey('channel-file-a'))).height;
      await mount(
        t,
        compact: true,
        platform: TargetPlatform.linux,
        size: const Size(390, 844),
        store: filesStore((_) async => page(['a'])),
      );
      final mouse = height(t);
      await t.pumpWidget(const SizedBox());
      await mount(
        t,
        compact: true,
        size: const Size(856, 944),
        store: filesStore((_) async => page(['a'])),
      );
      expect(height(t), greaterThan(mouse));
    });

    testWidgets('an Artifact row is the same row', (t) async {
      final opened = <String>[];
      await mount(
        t,
        compact: true,
        store: filesStore((_) async => page(['a'])),
        artifacts: artifactsStore((_) async => rows([1])),
        onOpenArtifact: (card) => opened.add(card.id),
      );
      final row = artifactRow(1);
      expect(find.text('Report 1'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
      expect(
        t.getSize(row).height,
        closeTo(
          t.getSize(find.byKey(const ValueKey('channel-file-a'))).height,
          1,
        ),
      );
      await t.tap(row);
      expect(opened, [artifactIdOf(1)]);
    });

    testWidgets('the card list has no card chrome around a row', (t) async {
      await mount(
        t,
        compact: true,
        store: filesStore((_) async => page(['a', 'b'])),
      );
      final a = t.getRect(find.byKey(const ValueKey('channel-file-a')));
      final b = t.getRect(find.byKey(const ValueKey('channel-file-b')));
      expect(b.top, closeTo(a.bottom, 1));
      expect(a.width, 390);
    });
  });

  group('SourceChannelFilesView with the workspace flag', () {
    late ArtifactFakeClient client;
    late WorkspaceController w;
    final routes = <String>[];
    setUp(() {
      routes.clear();
      client = ArtifactFakeClient();
      client.answers['GET /channels/c1/files'] = (_) => {
        'files': [
          {
            ...fileRow('a'),
            'channelId': 'c1',
            'source': {
              'type': 'channel',
              'channelId': 'c1',
              'parentMessageId': null,
            },
          },
        ],
        'nextCursor': null,
      };
      client.answers['GET /artifacts/conversations/c1'] = (_) => rows([1]);
      w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'})
        ..channel = RaftChannel({
          'id': 'c1',
          'name': 'general',
          'joined': true,
        });
    });
    tearDown(() => w.dispose());

    Future<void> show(WidgetTester t, {bool settle = true}) async {
      t.view.physicalSize = const Size(390, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          navigatorObservers: [_Routes(routes)],
          home: Scaffold(
            body: SourceChannelFilesView(
              controller: w,
              channelId: 'c1',
              formatCreatedAt: (_) => 'Oct 8, 10:30 AM',
            ),
          ),
        ),
      );
      if (!settle) return;
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
    }

    testWidgets(
      'the flag on: Artifacts above the files; a row opens the viewer',
      (t) async {
        await show(t);
        expect(artifactRow(1), findsOneWidget);
        expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
        await t.tap(artifactRow(1));
        await t.pump();
        expect(routes, contains('/workspace-artifact'));
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('the flag off: the files only and no Artifacts request', (
      t,
    ) async {
      client.enabled = false;
      await show(t);
      expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
      expect(artifactRow(1), findsNothing);
      expect(
        client.requests,
        isNot(contains('GET /artifacts/conversations/c1')),
      );
    });

    testWidgets('a revisit shows the rows it held while it reads again', (
      t,
    ) async {
      await show(t);
      expect(artifactRow(1), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      client.answers['GET /artifacts/conversations/c1'] = (_) => rows([2]);
      await show(t, settle: false);
      // First frame of the revisit: the last list, no loading line.
      expect(find.text('Loading Artifacts…'), findsNothing);
      expect(artifactRow(1), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      // The read behind it replaced the rows in place.
      expect(artifactRow(2), findsOneWidget);
      expect(artifactRow(1), findsNothing);
    });
  });
}

class _Routes extends NavigatorObserver {
  _Routes(this.names);
  final List<String> names;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) =>
      names.add(route.settings.name ?? '');
}
