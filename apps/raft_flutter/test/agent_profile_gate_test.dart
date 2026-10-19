import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_profile_rules.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import '../../../tool/testing/system_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('agent profile access', () {
    const viewer = 'alice';
    const here = 's1';

    Map<String, dynamic> agent({
      String? serverId,
      String? projection,
      String? creatorId,
    }) => {
      'id': 'bajie',
      'serverId': ?serverId,
      'profileProjection': ?projection,
      'creatorType': 'user',
      'creatorId': creatorId ?? 'someone',
    };

    test('a remote or channel_summary agent is public for every role', () {
      for (final role in ['guest', 'member', 'owner', 'admin']) {
        for (final row in [
          agent(serverId: 'other'),
          agent(projection: 'channel_summary', creatorId: viewer),
          agent(serverId: 'other', projection: 'channel_summary'),
        ]) {
          final access = agentProfileAccess(
            agent: row,
            currentServerId: here,
            currentUserId: viewer,
            editAgents: role == 'owner' || role == 'admin',
            controlAgentRuntime: role == 'member' || role == 'owner',
            external: false,
          );
          expect(access.boundedPublic, isTrue, reason: role);
          expect(access.canManage, isFalse, reason: role);
          expect(access.canViewPrivate, isFalse, reason: role);
          expect(access.canControlRuntime, isFalse, reason: role);
        }
      }
    });

    test(
      'the creator on this server keeps private pages without editAgents',
      () {
        final access = agentProfileAccess(
          agent: agent(serverId: here, creatorId: viewer),
          currentServerId: here,
          currentUserId: viewer,
          editAgents: false,
          controlAgentRuntime: true,
          external: false,
        );
        expect(access.boundedPublic, isFalse);
        expect(access.canManage, isTrue);
        expect(access.canViewPrivate, isTrue);
        expect(access.canControlRuntime, isTrue);
        expect(access.sourceServerLabel, isNull);
      },
    );

    test('a local member who did not create the agent cannot manage it', () {
      final access = agentProfileAccess(
        agent: agent(serverId: here),
        currentServerId: here,
        currentUserId: viewer,
        editAgents: false,
        controlAgentRuntime: true,
        external: false,
      );
      expect(access.canManage, isFalse);
      expect(access.canViewPrivate, isFalse);
      expect(access.canControlRuntime, isTrue);
    });

    test('From uses the server name, then the slug, only when remote', () {
      expect(
        agentSourceServerLabel({
          'serverId': 'other',
          'serverName': 'Swift 工作流',
          'serverSlug': 'swift',
        }, here),
        'Swift 工作流',
      );
      expect(
        agentSourceServerLabel({
          'serverId': 'other',
          'serverSlug': 'swift',
        }, here),
        'swift',
      );
      expect(
        agentSourceServerLabel({
          'serverId': here,
          'serverName': 'Home',
          'profileProjection': 'channel_summary',
        }, here),
        isNull,
      );
    });
  });

  group('agent profile panel', () {
    for (final role in ['guest', 'member', 'owner']) {
      testWidgets('$role sees only the public profile of another server', (
        tester,
      ) async {
        await openFleet(
          tester,
          role: role,
          agent: remoteAgent(creatorId: 'alice'),
        );
        expectPublicProfile(tester, from: 'Swift 工作流');
      });

      testWidgets('$role sees only the public profile of a channel summary', (
        tester,
      ) async {
        await openFleet(
          tester,
          role: role,
          agent: {
            ...localAgent(creatorId: 'alice'),
            'profileProjection': 'channel_summary',
            'serverName': 'Home',
          },
        );
        expectPublicProfile(tester, from: null);
      });
    }

    testWidgets('a member who created the agent gets the private pages', (
      tester,
    ) async {
      await openFleet(
        tester,
        role: 'member',
        agent: localAgent(creatorId: 'alice'),
      );
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Copy Diagnostic Info'), findsOneWidget);
      expect(find.text('Delete Agent'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-profile-inline-start-stop')),
        findsOneWidget,
      );
      expect(find.text('No computer assigned'), findsOneWidget);
      expect(find.text('FROM'), findsNothing);
    });

    testWidgets('a member who did not create the agent does not manage it', (
      tester,
    ) async {
      await openFleet(
        tester,
        role: 'member',
        agent: localAgent(creatorId: 'bob'),
      );
      expect(find.text('Activity'), findsNothing);
      expect(find.text('Copy Diagnostic Info'), findsNothing);
      expect(find.text('Delete Agent'), findsNothing);
      expect(
        find.byKey(const Key('agent-profile-inline-start-stop')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('agent-profile-inline-restart-reset')),
        findsOneWidget,
      );
      expect(find.text('No computer assigned'), findsOneWidget);
      expect(find.textContaining('CREATED AGENTS'), findsOneWidget);
    });

    testWidgets(
      'a guest on this server sees operational info and no controls',
      (tester) async {
        await openFleet(
          tester,
          role: 'guest',
          agent: localAgent(creatorId: 'bob'),
        );
        expect(find.text('Activity'), findsNothing);
        expect(find.text('No computer assigned'), findsOneWidget);
        expect(find.textContaining('CREATED AGENTS'), findsOneWidget);
        expect(
          find.byKey(const Key('agent-profile-inline-start-stop')),
          findsNothing,
        );
        expect(find.text('Stop Agent'), findsNothing);
        expect(find.text('Start Agent'), findsNothing);
        expect(find.text('Delete Agent'), findsNothing);
        expect(find.text('Copy Diagnostic Info'), findsNothing);
      },
    );

    testWidgets('an owner on this server still manages a local agent', (
      tester,
    ) async {
      await openFleet(
        tester,
        role: 'owner',
        agent: localAgent(creatorId: 'bob'),
      );
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Delete Agent'), findsOneWidget);
      expect(find.textContaining('RUNTIME CONFIG'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-profile-inline-start-stop')),
        findsOneWidget,
      );
    });

    testWidgets('elevated flags still cannot open a remote agent', (
      tester,
    ) async {
      final (workspace, _) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(workspace.dispose);
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: AgentDetailPanel(
              controller: workspace,
              agent: remoteAgent(creatorId: 'alice'),
              machines: const [],
              canManage: true,
              canViewPrivate: true,
              canControlRuntime: true,
              actions: AgentDetailActions(
                onStartStop: () {},
                onRestartReset: () {},
                onDelete: () {},
                onMessage: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expectPublicProfile(tester, from: 'Swift 工作流');
    });
  });

  group('external projection task menu', () {
    for (final role in ['guest', 'member', 'owner']) {
      testWidgets('$role does not convert an external projection', (
        tester,
      ) async {
        await openMenu(tester, role: role, senderType: 'external_projection');
        expect(find.text('Copy Link'), findsOneWidget);
        expect(find.text('Convert to Task'), findsNothing);
        expect(find.text('Reopen Task'), findsNothing);
        expect(find.text('Mark as Done'), findsNothing);
      });

      testWidgets('$role can still convert an ordinary message', (
        tester,
      ) async {
        await openMenu(tester, role: role, senderType: 'user');
        expect(find.text('Convert to Task'), findsOneWidget);
      });
    }
  });

  testWidgets('fixed remote profile renders the public page in Chinese', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    tester.view.physicalSize = const Size(420, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shot = Platform.environment['RAFT_PROFILE_SHOT'];
    if (shot != null && shot.isNotEmpty) {
      // Header title is Inter with fallback [sans-serif] only. Ahem covers
      // 八, and the parity emoji face registered as sans-serif does not, so
      // this capture registers Noto CJK as that one fallback family.
      final missing = missingTestFontReason(cjkTestFonts());
      if (missing != null) throw StateError(missing);
      await tester.runAsync(loadProfileShotFonts);
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('profile-shot'),
            child: AgentDetailPanel(
              controller: workspace,
              agent: {
                ...remoteAgent(creatorId: 'someone'),
                'displayName': '八戒',
                'name': 'bajie',
                'description': '',
              },
              machines: const [],
              canManage: true,
              canViewPrivate: true,
              canControlRuntime: true,
              actions: AgentDetailActions(
                onStartStop: () {},
                onRestartReset: () {},
                onDelete: () {},
                onMessage: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('资料'), findsOneWidget);
    expect(find.text('来自'), findsOneWidget);
    expect(find.text('Swift 工作流'), findsOneWidget);
    expect(find.text('八戒'), findsWidgets);
    expect(find.text('停止 Agent'), findsNothing);
    expect(find.text('重启 / 重置'), findsNothing);
    expect(find.text('删除 Agent'), findsNothing);
    expect(find.text('复制诊断信息'), findsNothing);
    expect(find.text('未分配计算机'), findsNothing);
    expect(find.text('未分配创建者'), findsNothing);
    expect(find.text('动态'), findsNothing);
    expect(find.text('已创建的 Agent'), findsNothing);
    if (shot != null && shot.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('profile-shot')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(shot).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Product faces plus Noto CJK as `sans-serif`, the header title's only
/// fallback. Keeps the emoji face off that family so 八 is not NO GLYPH.
Future<void> loadProfileShotFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final fonts = (entry['fonts'] as List).cast<Map<String, dynamic>>();
    final loader = FontLoader(family);
    for (final font in fonts) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    if (family.startsWith('packages/')) {
      final alias = FontLoader(family.split('/').last);
      for (final font in fonts) {
        alias.addFont(rootBundle.load(font['asset'] as String));
      }
      await alias.load();
    }
  }
  final regular = ByteData.sublistView(
    await systemTestFont('opentype/noto/NotoSansCJK-Regular.ttc').readAsBytes(),
  );
  final bold = ByteData.sublistView(
    await systemTestFont('opentype/noto/NotoSansCJK-Bold.ttc').readAsBytes(),
  );
  for (final family in const [
    'sans-serif',
    'Noto Sans CJK SC',
    'Noto Sans CJK JP',
  ]) {
    await (FontLoader(family)
          ..addFont(Future.value(regular))
          ..addFont(Future.value(bold)))
        .load();
  }
}

Map<String, dynamic> remoteAgent({required String creatorId}) => {
  'id': 'bajie',
  'name': 'bajie',
  'displayName': '八戒',
  'description': 'Joint agent',
  'status': 'active',
  'runtime': 'claude',
  'model': 'opus',
  'activity': 'offline',
  'serverId': 'other',
  'serverName': 'Swift 工作流',
  'avatarUrl': null,
  'creatorType': 'user',
  'creatorId': creatorId,
  'createdAt': '2026-10-13T08:00:00.000Z',
};

Map<String, dynamic> localAgent({required String creatorId}) => {
  'id': 'bajie',
  'name': 'bajie',
  'displayName': '八戒',
  'description': 'Local agent',
  'status': 'active',
  'runtime': 'claude',
  'model': 'opus',
  'activity': 'offline',
  'serverId': 's1',
  'serverName': 'Home',
  'avatarUrl': null,
  'creatorType': 'user',
  'creatorId': creatorId,
  'createdAt': '2026-10-13T08:00:00.000Z',
};

void expectPublicProfile(WidgetTester tester, {required String? from}) {
  expect(find.text('Profile'), findsOneWidget);
  expect(find.text('八戒'), findsWidgets);
  expect(find.text('Activity'), findsNothing);
  expect(find.text('Chat'), findsNothing);
  expect(find.text('Reminders'), findsNothing);
  expect(find.text('Workspace'), findsNothing);
  expect(find.text('Apps'), findsNothing);
  expect(
    find.byKey(const Key('agent-profile-inline-start-stop')),
    findsNothing,
  );
  expect(
    find.byKey(const Key('agent-profile-inline-restart-reset')),
    findsNothing,
  );
  expect(find.byKey(const Key('agent-profile-overflow-trigger')), findsNothing);
  expect(find.text('Stop Agent'), findsNothing);
  expect(find.text('Start Agent'), findsNothing);
  expect(find.text('Restart / Reset'), findsNothing);
  expect(find.text('Delete Agent'), findsNothing);
  expect(find.text('Copy Diagnostic Info'), findsNothing);
  expect(find.text('Direct Message'), findsNothing);
  expect(find.text('No computer assigned'), findsNothing);
  expect(find.text('No creator assigned'), findsNothing);
  expect(find.textContaining('RUNTIME CONFIG'), findsNothing);
  expect(find.textContaining('CREATED AGENTS'), findsNothing);
  expect(find.text('Computer'), findsNothing);
  expect(find.text('Creator'), findsNothing);
  if (from == null) {
    expect(find.text('FROM'), findsNothing);
  } else {
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text(from), findsOneWidget);
  }
}

Future<void> openFleet(
  WidgetTester tester, {
  required String role,
  required Map<String, dynamic> agent,
}) async {
  final (workspace, api) = (await tester.runAsync(() => fixture(role)))!;
  addTearDown(workspace.dispose);
  final id = agent['id'];
  api.routes['GET /agents'] = (_) => [agent];
  api.routes['GET /agents/$id'] = (_) => agent;
  api.routes['GET /agents/$id/skills'] = (_) => {
    'global': <Map<String, dynamic>>[],
    'workspace': <Map<String, dynamic>>[],
  };
  api.routes['GET /servers/s1/machines'] = (_) => {'machines': <Map>[]};
  await tester.runAsync(initializeSourceTimeFormatting);
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: FleetDetail(
          controller: workspace,
          computers: false,
          initial: agent,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<void> openMenu(
  WidgetTester tester, {
  required String role,
  required String senderType,
}) async {
  final (workspace, _) = (await tester.runAsync(() => fixture(role)))!;
  addTearDown(workspace.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  workspace.messageDomain.ledger.switchServer('s1');
  workspace.messageDomain.ledger.ingest([
    {
      'id': 'm',
      'channelId': 'c1',
      'seq': '1',
      'messageType': 'chat',
      'content': 'Outside',
      'senderName': '八戒',
      'senderType': senderType,
    },
  ], expectedGeneration: workspace.messageDomain.ledger.generation);
  workspace.messageDomain.visibleIds['c1'] = {'m'};
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: RaftChatView(controller: workspace)),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  tester.widget<RaftMessageTile>(find.byType(RaftMessageTile)).onActions!();
  await tester.pump(const Duration(milliseconds: 400));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
}
