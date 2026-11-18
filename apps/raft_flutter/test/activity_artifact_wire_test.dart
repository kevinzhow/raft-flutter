import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityWorkspace, channelRow, skeleton;
import 'support/artifact_fake_client.dart';
import 'support/activity_list_harness.dart'
    show ListEnv, desktop, foldA, foldB, phoneMouse;

// Captured from the mounted API and Activity emitter at
// 1d689caf34442247cab70580d7feac1b8c302d60 using an isolated synthetic account.
dynamic _wire(String name) => jsonDecode(
  File('test/fixtures/activity_artifact_328/$name.json').readAsStringSync(),
);

Map<String, dynamic> _object(Map<String, dynamic> window) =>
    (window['items'] as List).whereType<Map<String, dynamic>>().singleWhere(
      (row) => row['kind'] == 'object' && row['objectKind'] == 'artifact',
    );

class _WireWorkspace extends ActivityWorkspace {
  _WireWorkspace(super.client);

  Map<String, dynamic> all = _wire('comment');
  Map<String, dynamic> scoped = _wire('scoped');
  final List summary = _wire('summary');

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/unread-summary') return summary;
    if (path != '/channels/inbox') return super.query(path, query: query);
    inboxQueries.add({...?query});
    await hold?.future;
    return query?['scope'] == 'artifacts' ? scoped : all;
  }
}

void main() {
  late ArtifactFakeClient client;
  late _WireWorkspace workspace;
  late SourceActivityUnreadStore store;
  late String serverId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    final nextEvent = _wire('event') as Map;
    serverId = (nextEvent['payload'] as Map)['serverId'] as String;
    client = ArtifactFakeClient()..selectServer(serverId);
    workspace = _WireWorkspace(client)
      ..server = RaftRecord({'id': serverId, 'role': 'owner', 'slug': 'demo'})
      ..channels = [
        RaftChannel({'id': 'ch1', 'name': 'Channel 1', 'joined': true}),
      ];
    store = workspace.activityUnread;
    client.answers['POST /objects/activity/read'] = (_) => {'ok': true};
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  Future<void> mount(WidgetTester tester, {ListEnv env = desktop}) async {
    tester.view.physicalSize = env.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SourceActivityUnreadStore.clock = tester.binding.clock.now;
    addTearDown(() => SourceActivityUnreadStore.clock = DateTime.now);
    store.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: env.platform),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'activity',
            onMessage: (_, _) async {},
            onActivityWindowAccepted: (window, {firstPage = false}) {
              if (window != null) {
                store.acceptWindow(
                  window,
                  scope: store.scope,
                  firstPage: firstPage,
                );
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Finder rowOf(Map row) =>
      find.byKey(ValueKey('activity-object-${row['objectId']}'));

  testWidgets('the Activity badge counts an unread object row once', (_) async {
    expect(workspace.all['totalUnreadCount'], 0);
    expect(workspace.all['objectUnreadCount'], 1);
    expect(_object(workspace.all)['unreadCount'], greaterThan(1));
    await store.refresh();
    expect(store.hasAttention, isTrue);
    expect(store.totalUnreadCount, 1);
    workspace.all = {
      ...workspace.all,
      'totalUnreadCount': 3,
      'items': [...workspace.all['items'] as List, channelRow(1, unread: 3)],
    };
    await store.refresh();
    expect(store.totalUnreadCount, 4);
  });

  testWidgets('server summary joins its separate Artifact count', (
    tester,
  ) async {
    final summary = SourceServerUnreadStore(workspace);
    addTearDown(summary.dispose);
    final raw = workspace.summary.cast<Map>().singleWhere(
      (entry) => entry['serverId'] == serverId,
    );
    expect(raw['activityObjectUnreadCount'], 1);
    await tester.runAsync(summary.refresh);
    expect(
      summary[serverId]?.activityUnreadCount,
      (raw['activityUnreadCount'] as int) + 1,
    );
  });

  testWidgets(
    'a future kind stays out of the list while its neighbors render',
    (tester) async {
      final row = _object(workspace.all);
      final unknown = {
        ...row,
        'objectKind': 'future-kind',
        'objectId': 'future-1',
      };
      workspace.all = {
        ...workspace.all,
        'items': [row, unknown, channelRow(1, unread: 3)],
      };
      await mount(tester);
      expect(rowOf(row), findsOneWidget);
      expect(rowOf(unknown), findsNothing);
      expect(
        find.textContaining('Channel 1', findRichText: true),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'an object read event updates the loaded Artifacts filter in place',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artifacts'));
      await tester.pumpAndSettle();
      final row = rowOf(_object(workspace.scoped));
      final unread = find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('conversation-card-new-badge')),
      );
      expect(row, findsOneWidget);
      expect(unread, findsOneWidget);

      workspace.inboxQueries.clear();
      final frame = _wire('event') as Map<String, dynamic>;
      final eventName = frame['name'] as String;
      final payload = frame['payload'] as Map<String, dynamic>;
      workspace.scoped = _wire('scoped-read');
      workspace.all = _wire('all-read');
      final pending = workspace.hold = Completer<void>();
      client.ingress.add(RaftEvent(eventName, payload));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        workspace.inboxQueries.where((q) => q['scope'] == 'artifacts'),
        hasLength(1),
      );
      expect(row, findsOneWidget);
      expect(unread, findsOneWidget);
      expect(skeleton, findsNothing);

      pending.complete();
      workspace.hold = null;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(unread, findsNothing);
      expect(store.totalUnreadCount, workspace.all['totalUnreadCount']);

      workspace.inboxQueries.clear();
      client.ingress.add(
        RaftEvent(eventName, {...payload, 'serverId': 'elsewhere'}),
      );
      client.ingress.add(
        RaftEvent(eventName, {...payload, 'source': 'future'}),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(workspace.inboxQueries, isEmpty);
    },
  );

  for (final (event, env) in [
    ('comment', foldA),
    ('review', foldB),
    ('version', phoneMouse),
  ]) {
    testWidgets(
      '${env.name} opens the served $event target and reads its frontier',
      (tester) async {
        workspace.all = _wire(event);
        final row = _object(workspace.all);
        final id = row['objectId'] as String;
        final summary = row['summary'] as Map<String, dynamic>;
        final target = row['target'] as Map<String, dynamic>;
        final version = target['version'] as int;
        final pinned = version != summary['latestVersion'];
        final path = 'GET /artifacts/$id${pinned ? '?version=$version' : ''}';
        client.answers[path] = (_) => artifactViewerJson(
          card: {...summary, 'version': version, 'pinned': pinned},
        );
        final reviewId = (target['review'] as Map?)?['id'] as String?;
        final commentId = target['comment'] as String?;
        final commentsPath = Uri(
          path: '/artifacts/$id/comments',
          queryParameters: reviewId == null ? null : {'review': reviewId},
        ).toString();
        const commentText = 'Comment from the Activity target';
        const reviewText = 'Review summary from the Activity target';
        client.answers['GET $commentsPath'] = (_) => {
          'comments': [
            if (commentId != null && reviewId == null)
              {
                'id': commentId,
                'version': version,
                'author': artifactActor(),
                'target': {'scope': 'artifact'},
                'body': [
                  {'type': 'text', 'text': commentText},
                ],
              },
          ],
          if (reviewId != null)
            'review': {
              'id': reviewId,
              'body': [
                {'type': 'text', 'text': reviewText},
              ],
            },
        };
        final launches = <Uri>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        const launcher = MethodChannel('plugins.flutter.io/url_launcher');
        messenger.setMockMethodCallHandler(launcher, (call) async {
          if (call.method == 'launch') {
            launches.add(Uri.parse((call.arguments as Map)['url'] as String));
          }
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));

        await mount(tester, env: env);
        await tester.tap(rowOf(row));
        await tester.pumpAndSettle();
        expect(find.byType(ArtifactWorkspaceViewer), findsOneWidget);
        expect(client.requests, contains(path));
        expect(client.bodies['POST /objects/activity/read'], {
          'kind': 'artifact',
          'objectId': id,
          'throughSeq': row['doneFrontierSeq'],
        });
        if (commentId != null || reviewId != null) {
          expect(
            find.byKey(const ValueKey('artifact-comments-panel')),
            findsOneWidget,
          );
          expect(
            find.text(reviewId == null ? commentText : reviewText),
            findsOneWidget,
          );
          expect(client.requests, contains('GET $commentsPath'));
          expect(launches, isEmpty);

          await tester.tap(
            find.byKey(const ValueKey('artifact-viewer-menu-trigger')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey('artifact-viewer-menu-surface'),
                  ),
                  matching: find.text('Open in browser'),
                )
                .hitTestable(),
          );
          await tester.pumpAndSettle();
          expect(launches, hasLength(1));
          final browserUrl = launches.single;
          final shortId = artifactLinkId(id);
          if (reviewId == null) {
            expect(browserUrl.path, '/artifacts/$shortId/v/$version');
            expect(browserUrl.queryParameters, {
              'panel': 'comments',
              'comment': commentId,
            });
          } else {
            expect(browserUrl.path, '/s/demo/activity');
            expect(browserUrl.queryParameters, {
              'artifact': shortId,
              'version': '$version',
              'review': reviewId,
            });
          }
        }
      },
    );
  }
}
