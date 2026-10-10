import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_account_usage.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/profile_preview.dart';
import 'package:raft_flutter/features/runtime_usage_chip.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final paths = <String>[];
  final posts = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    return switch (path) {
      '/agents' => [
        {
          'id': 'a',
          'name': 'nova',
          'displayName': 'Nova',
          'description': 'Ships the release',
          'runtime': 'codex',
          'model': 'gpt-6',
          'machineId': 'c',
          'activity': 'working',
          'activityDetail': 'Running tests',
          'creatorType': 'user',
          'creatorId': 'alice',
        },
      ],
      '/servers/s/machines' => {
        'machines': [
          {
            'id': 'c',
            'name': 'build-box',
            'status': 'online',
            'runtimes': ['codex', 'claude'],
            'runtimeVersions': {'claude': '2.1.0'},
            'computerAttachedByCurrentUser': true,
          },
        ],
      },
      '/servers/s/members' => [
        {
          'userId': 'u',
          'name': 'grace',
          'displayName': 'Grace',
          'description': 'Design lead',
          'role': 'member',
        },
      ],
      '/agents/a/activity-log' => [
        {
          'timestamp': DateTime.utc(2026, 10, 10, 10).millisecondsSinceEpoch,
          'entry': {'kind': 'thinking', 'text': 'Planning the fix'},
        },
        {
          'timestamp': DateTime.utc(2026, 10, 10, 10, 1).millisecondsSinceEpoch,
          'entry': {'kind': 'tool_start', 'toolName': 'Bash'},
        },
        {
          'timestamp': DateTime.utc(2026, 10, 10, 10, 2).millisecondsSinceEpoch,
          'entry': {
            'kind': 'tool_start',
            'toolName': 'mcp__chat__send_message',
          },
        },
      ],
      _ when path.contains('/runtime-account-usage/') => {
        'state': 'fresh',
        'snapshot': {
          'provider': 'claude',
          'collectedAt': DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
          'accounts': [
            {
              'accountKey': 'k',
              'planLabel': 'Max',
              'maskedLabel': 'ali****@example.com',
              'health': 'ok',
              'windows': [
                {'id': '5h', 'label': '5h', 'status': 'ok', 'usedRatio': .42},
              ],
            },
          ],
        },
      },
      _ => <dynamic>[],
    };
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add('$method $path');
    return {'accepted': true, 'state': 'requested'};
  }
}

Future<TestGesture> _hover(WidgetTester t, Finder target) async {
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(t.getCenter(target));
  await t.pump(const Duration(milliseconds: 210));
  await t.pump(const Duration(milliseconds: 300));
  return mouse;
}

void main() {
  late _Client client;
  late _Workspace w;
  Future<void> setUpWorkspace({String role = 'member'}) async {
    client = _Client();
    w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': role});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await w.entityDirectory.preload();
  }

  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  Future<void> finish(WidgetTester t, TestGesture mouse) async {
    await mouse.removePointer();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('agent avatar card: presence, computer, runtime, model, '
      'description and the creator\'s recent activity', (t) async {
    await setUpWorkspace();
    final message = RaftMessage({
      'id': 'm1',
      'senderId': 'a',
      'senderType': 'agent',
      'senderName': 'nova',
      'senderDisplayName': 'Nova',
    });
    await t.pumpWidget(
      host(
        senderProfileHoverCard(
          controller: w,
          message: message,
          content: const RaftAvatarContent(
            name: 'Nova',
            kind: RaftAvatarContentKind.agent,
          ),
          child: const SizedBox.square(key: ValueKey('avatar'), dimension: 36),
        ),
      ),
    );
    final mouse = await _hover(t, find.byKey(const ValueKey('avatar')));
    await t.pump(const Duration(milliseconds: 50));
    for (final text in [
      'Nova',
      '@nova',
      'Running tests',
      'Computer',
      'build-box',
      'Runtime',
      'Codex CLI',
      'Model',
      'Reasoning',
      'Default',
      'Ships the release',
      'Recent activity'.toUpperCase(),
      'Planning the fix',
      'Running command',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // send_message tool starts are hidden from the preview.
    expect(find.text('Sending message'), findsNothing);
    expect(w.paths, contains('/agents/a/activity-log'));
    await finish(t, mouse);
  });

  testWidgets('member mention card and an unknown mention', (t) async {
    await setUpWorkspace();
    final message = RaftMessage({
      'id': 'm2',
      'channelId': 'ch',
      'senderId': 'alice',
      'senderType': 'user',
      'content': 'hi @grace and @ghost',
      'mentions': [
        {'type': 'user', 'id': 'u', 'name': 'grace'},
        {'type': 'agent', 'id': 'gone', 'name': 'ghost'},
      ],
    });
    await t.pumpWidget(
      host(
        SizedBox(
          width: 500,
          child: MessagePresentation(
            controller: w,
            message: message,
            onExternalLink: (_) {},
          ),
        ),
      ),
    );
    final mouse = await _hover(t, find.text('@grace'));
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Design lead'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-preview-facts')), findsNothing);
    await mouse.moveTo(const Offset(700, 500));
    await t.pump(const Duration(milliseconds: 130));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Grace'), findsNothing);
    await mouse.moveTo(t.getCenter(find.text('@ghost')));
    await t.pump(const Duration(milliseconds: 210));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Profile unavailable'), findsOneWidget);
    await finish(t, mouse);
  });

  testWidgets('external sender: provider, workspace and identity note', (
    t,
  ) async {
    await setUpWorkspace();
    final message = RaftMessage({
      'id': 'm3',
      'senderType': 'external_projection',
      'senderDisplayName': 'Lin',
      'externalAuthor': {
        'displayName': 'Lin',
        'provider': 'slack',
        'workspaceName': 'Acme',
        'actorKind': 'guest',
      },
    });
    await t.pumpWidget(
      host(
        senderProfileHoverCard(
          controller: w,
          message: message,
          content: const RaftAvatarContent(
            name: 'Lin',
            kind: RaftAvatarContentKind.app,
          ),
          child: const SizedBox.square(key: ValueKey('ext'), dimension: 36),
        ),
      ),
    );
    final mouse = await _hover(t, find.byKey(const ValueKey('ext')));
    expect(find.text('Slack · Guest'), findsOneWidget);
    expect(find.text('From Acme'), findsOneWidget);
    expect(find.text('External identity'), findsOneWidget);
    await finish(t, mouse);
  });

  testWidgets('runtime usage chip reads the snapshot and opens on hover', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await setUpWorkspace();
    final machine = w.entityDirectory.computer('c');
    expect(canViewRuntimeUsage(w, machine), isTrue);
    await t.pumpWidget(
      host(
        Wrap(
          children: [
            runtimeUsageGateChip(
              controller: w,
              enabled: canViewRuntimeUsage(w, machine),
              runtimeId: 'claude',
              machineId: 'c',
              label: 'Claude Code',
              runtimeVersion: '2.1.0',
              chip: (status) => RaftRuntimeChip(
                label: 'Claude Code',
                detected: true,
                trailing: status,
              ),
            ),
            // Runtimes without a usage provider stay plain chips.
            runtimeUsageGateChip(
              controller: w,
              enabled: true,
              runtimeId: 'builtin',
              machineId: 'c',
              label: 'Built-in Pi',
              chip: (status) => RaftRuntimeChip(
                label: 'Built-in Pi',
                detected: true,
                trailing: status,
              ),
            ),
          ],
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(
      w.paths,
      contains('/servers/s/machines/c/runtime-account-usage/claude'),
    );
    expect(find.byType(RaftRuntimeUsageStatus), findsOneWidget);
    expect(find.byType(RaftRuntimeUsageChip), findsOneWidget);
    final mouse = await _hover(t, find.text('Claude Code'));
    expect(find.text('Claude usage'), findsOneWidget);
    expect(find.text('VERSION 2.1.0'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
    expect(find.text('ali****@example.com'), findsOneWidget);
    expect(find.text('Account-wide · updated 5 minutes ago'), findsOneWidget);
    // Manual refresh posts once and starts the cooldown countdown.
    await t.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
    await t.pump();
    expect(w.posts, [
      'POST /servers/s/machines/c/runtime-account-usage/claude/refresh',
    ]);
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Refresh requested'), findsOneWidget);
    await finish(t, mouse);
  });

  test(
    'usage client caches reads for 60s and refuses refreshes for 120s',
    () async {
      var now = DateTime(2026, 10, 10, 10);
      var gets = 0, posts = 0;
      final c = RuntimeAccountUsageClient(
        get: (_) async {
          gets++;
          return {'state': 'missing', 'snapshot': null};
        },
        post: (_, _) async {
          posts++;
          return {'accepted': true, 'state': 'requested'};
        },
        now: () => now,
      );
      await c.read('s', 'c', 'claude');
      await c.read('s', 'c', 'claude');
      expect(gets, 1);
      now = now.add(const Duration(seconds: 61));
      await c.read('s', 'c', 'claude');
      expect(gets, 2);
      expect(
        (await c.refresh('s', 'c', 'claude', 'manual')).state,
        'requested',
      );
      expect((await c.refresh('s', 'c', 'claude', 'manual')).state, 'cooldown');
      expect(posts, 1);
      expect(c.cooldownRemaining('s', 'c', 'claude').inSeconds, 120);
      now = now.add(const Duration(seconds: 121));
      expect(c.cooldownRemaining('s', 'c', 'claude'), Duration.zero);
      expect(runtimeUsageProvider('kimi-sdk'), 'kimi');
      expect(runtimeUsageProvider('builtin'), isNull);
    },
  );
}
