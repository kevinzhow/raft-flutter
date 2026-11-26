import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_inbox_row.dart';
import 'package:raft_flutter/features/activity_object_row.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/text_scale_audit.dart';
import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart' show pageFixture;
import 'support/activity_row_harness.dart';
import 'support/app_services_fixture.dart';

void main() {
  final auditModes =
      [
        AuditMode.base,
        AuditMode.x13,
        AuditMode('1.5x', textScale: 1.5),
        AuditMode.x2,
        if (const bool.fromEnvironment('RAFT_TEXT_SCALE_DISPLAY_LOCALES'))
          const AuditMode('en-3.1x', textScale: 3.1, locale: Locale('en')),
        const AuditMode('zh-1.3x', textScale: 1.3, locale: Locale('zh', 'CN')),
        if (const bool.fromEnvironment('RAFT_TEXT_SCALE_DISPLAY_LOCALES'))
          for (final entry in raftDisplayLanguages.entries)
            if (entry.key != 'en' && entry.key != 'zh-cn')
              for (final scale in [1.0, 1.3, 2.0, 3.1])
                AuditMode(
                  '${entry.key}-${scale}x',
                  locale: entry.value.$1,
                  textScale: scale,
                ),
      ].where((mode) {
        const locale = String.fromEnvironment('RAFT_AUDIT_LOCALE');
        final maxScale = double.parse(
          const String.fromEnvironment(
            'RAFT_AUDIT_MAX_SCALE',
            defaultValue: '3.1',
          ),
        );
        return mode.textScale <= maxScale &&
            (locale.isEmpty ||
                raftDisplayLanguageId(mode.locale ?? const Locale('en')) ==
                    locale);
      }).toList();

  List<Map<String, dynamic>> makeMessages() => [
    for (var i = 1; i <= 6; i++)
      {
        ...row('m$i', 'c1', i),
        'createdAt': '2026-10-08T00:${i.toString().padLeft(2, '0')}:00Z',
        'senderId': i.isEven ? 'u1' : 'bob',
        'senderType': 'user',
        'senderName': i.isEven ? 'Cindy' : 'Gypsy',
        'content': switch (i) {
          5 => 'Captured the previous visual baseline with gjpqy descenders and 测试吞字笔画高度裁剪 [@Cindy](raft-ref://mention/user/cindy) in [#android-artifacts](raft-ref://channel/c2).',
          6 => 'Long message checking gjpqy descenders and 中文笔画高度裁剪\n\n```ts\nconst reply = "gjpqy 测试";\n```',
          _ => 'Channel message $i with gjpqy and 中文预览.',
        },
        if (i == 5)
          'reactions': [
            {
              'emoji': '\u{1F44D}',
              'count': 2,
              'reactorIds': ['u2', 'u3'],
              'reactorNames': ['Dana', 'Eve'],
            },
          ],
      },
  ];

  Future<AuditReport> auditWorkspaceSurface(
    WidgetTester tester, {
    required String name,
    required Size size,
    required AuditMode mode,
    required Map<String, bool> truncation,
    TargetPlatform platform = TargetPlatform.linux,
    RaftRoute route = RaftRoute.channel,
    String? entityId = 'c1',
    bool mobileHome = false,
    Future<void> Function(WidgetTester)? verifyMounted,
  }) async {
    await loadAuditFonts(tester, AuditFonts.real);
    final messages = makeMessages();
    final (baseW, api) = await pageFixture(tester);
    final w = mobileHome
        ? WorkspaceController(baseW.client, mobileNavigation: true)
        : baseW;
    if (mobileHome) {
      w
        ..servers = baseW.servers
        ..server = baseW.server
        ..loading = false;
      w.messageDomain.ledger.switchServer(w.server!.id);
      addTearDown(w.dispose);
    }
    w.channels = [
      RaftChannel({'id': 'c1', 'name': 'android-artifacts', 'joined': true}),
      RaftChannel({'id': 'c2', 'name': 'design-gjpqy-测试频道', 'joined': true}),
    ];
    w.dms = [
      RaftChannel({
        'id': 'dm1',
        'name': 'Cindy',
        'type': 'dm',
        'peerId': 'agent-cindy',
        'peerType': 'agent',
        'peerName': 'Cindy',
        'peerDisplayName': 'Cindy',
        'joined': true,
      }),
    ];
    w.channel = w.channels.first;
    w.conversationReads.unread = {'c1': 1, 'c2': 12};
    w.conversationReads.mentions = {'c2'};
    w.messageDomain.ledger.ingest(
      messages,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final m in messages) m['id'] as String,
    };
    api.routes['GET /agents'] = (_) => [
      {
        'id': 'agent-cindy',
        'name': 'Cindy',
        'handle': 'cindy',
        'status': 'online',
      },
    ];
    api.routes['GET /servers/s1/members'] = (_) => [
      {'id': 'bob', 'name': 'Gypsy', 'handle': 'gypsy', 'role': 'member'},
      {'id': 'u1', 'name': 'Cindy', 'handle': 'cindy', 'role': 'owner'},
    ];
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [
        {
          'kind': 'channel',
          'channelId': 'c1',
          'channelName': 'android-artifacts',
          'channelType': 'channel',
          'lastMessagePreview': 'Captured the previous visual baseline before leaving the workspace.',
          'lastMessageSenderType': 'agent',
          'lastMessageSenderId': 'agent-cindy',
          'lastMessageSenderName': 'Cindy',
          'lastMessageAt': '2026-10-08T00:05:00Z',
          'unreadCount': 1,
          'firstUnreadMessageId': 'm5',
          'lastMessageId': 'm6',
        },
        {
          'kind': 'channel',
          'channelId': 'c2',
          'channelName': 'design-gjpqy-测试频道',
          'channelType': 'channel',
          'lastMessagePreview': '测试吞字笔画高度裁剪 gjpqy 骨直令预览文字',
          'lastMessageSenderType': 'user',
          'lastMessageSenderId': 'bob',
          'lastMessageSenderName': 'Gypsy',
          'lastMessageAt': '2026-10-08T00:04:00Z',
          'unreadCount': 3,
          'firstUnreadMessageId': 'm5',
          'lastMessageId': 'm6',
        },
        {
          'kind': 'object',
          'objectKind': 'artifact',
          'objectId': 'art-1',
          'title': 'Typography gjpqy 骨直令报告',
          'lastActivityAt': '2026-10-08T00:03:00Z',
          'unreadCount': 1,
          'hasMention': false,
          'channelName': 'android-artifacts',
          'latestEvent': {
            'type': 'comment_created',
            'actor': {'id': 'agent-cindy', 'type': 'agent', 'name': 'Cindy'},
          },
          'latestComment': {
            'text': 'Captured the previous gjpqy 吞字笔画高度裁剪',
            'author': {'id': 'agent-cindy', 'type': 'agent', 'name': 'Cindy'},
          },
        },
      ],
    };
    api.routes['GET /messages/search'] = (_) => {
      'results': [
        {
          ...messages[4],
          'channelName': 'android-artifacts',
          'channelType': 'channel',
        },
      ],
      'hasMore': false,
    };
    api.routes['GET /tasks/server'] = (_) => {
      'tasks': [
        {
          'id': 'task-1',
          'number': 1,
          'title': 'Verify gjpqy glyph clipping 测试吞字笔画高度裁剪',
          'status': 'in_progress',
          'channelId': 'c1',
          'channelName': 'android-artifacts',
          'createdAt': '2026-10-08T00:00:00Z',
          'updatedAt': '2026-10-08T00:00:00Z',
        },
      ],
      'nextCursor': null,
    };
    api.routes['GET /tasks/channel/c1'] = api.routes['GET /tasks/server']!;
    api.routes['GET /messages/saved'] = (_) => {
      'messages': [messages[4]],
      'hasMore': false,
    };
    api.routes['GET /computers'] = (_) => [];
    api.routes['GET /apps'] = (_) => [];
    api.routes['GET /integrations'] = (_) => [];
    api.routes['GET /servers/s1/billing'] = (_) => {};

    if (mobileHome) {
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: w.location.serverSlug,
          route: RaftRoute.home,
        ),
      );
    } else if (route != RaftRoute.channel) {
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: w.location.serverSlug,
          route: route,
          entityId: entityId,
        ),
      );
    }

    final report = await auditSurface(
      tester,
      surface: name,
      build: () => withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
      theme: raftTheme(
        platform: platform,
        textLocale: raftDisplayLanguageId(mode.locale) == 'zh-cn'
            ? null
            : mode.locale,
      ),
      platform: platform,
      mode: mode,
      size: size,
      truncationBaseline: truncation,
      settle: const Duration(milliseconds: 250),
      after: verifyMounted,
      screenshotDir: Platform.environment['RAFT_TEXT_SCALE_OUT'],
    );
    return report;
  }

  testWidgets(
    'ActivityInboxRow & ActivityObjectRow: no glyph clipping across scales',
    (tester) async {
      await loadAuditFonts(tester, AuditFonts.real);
      useFixedClock();
      final fixture = RowFixture(
        channels: [
          channelRecord('channel-android', 'android-artifacts'),
          channelRecord('channel-zh', 'design-gjpqy-测试频道'),
        ],
        agents: [
          {'id': 'agent-cindy', 'name': 'Cindy', 'handle': 'cindy'},
        ],
      );
      addTearDown(fixture.dispose);

      final enRow = {
        'kind': 'channel',
        'channelId': 'channel-android',
        'channelName': 'android-artifacts',
        'channelType': 'channel',
        'lastMessageId': 'msg-1',
        'firstUnreadMessageId': 'msg-1',
        'lastMessageAt': fixedNow
            .subtract(const Duration(minutes: 6))
            .toIso8601String(),
        'lastMessagePreview': 'Captured the previous visual baseline before leaving the workspace.',
        'lastMessageSenderType': 'agent',
        'lastMessageSenderId': 'agent-cindy',
        'lastMessageSenderName': 'Cindy',
        'unreadCount': 1,
        'hasMention': false,
      };
      final zhRow = {
        'kind': 'channel',
        'channelId': 'channel-zh',
        'channelName': 'design-gjpqy-测试频道',
        'channelType': 'channel',
        'lastMessageId': 'msg-2',
        'firstUnreadMessageId': 'msg-2',
        'lastMessageAt': fixedNow
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
        'lastMessagePreview': '测试吞字笔画高度裁剪 gjpqy 骨直令预览文字',
        'lastMessageSenderType': 'agent',
        'lastMessageSenderId': 'agent-cindy',
        'lastMessageSenderName': 'Cindy',
        'unreadCount': 3,
        'hasMention': false,
      };
      final objRow = {
        'kind': 'object',
        'objectKind': 'artifact',
        'objectId': 'art-1',
        'title': 'Typography gjpqy 测试报告',
        'lastActivityAt': fixedNow
            .subtract(const Duration(minutes: 4))
            .toIso8601String(),
        'unreadCount': 1,
        'hasMention': false,
        'channelName': 'android-artifacts',
        'latestEvent': {
          'type': 'comment_created',
          'actor': {'id': 'agent-cindy', 'type': 'agent', 'name': 'Cindy'},
        },
        'latestComment': {
          'text': 'Captured the previous gjpqy 测试吞字笔画高度裁剪',
          'author': {'id': 'agent-cindy', 'type': 'agent', 'name': 'Cindy'},
        },
      };

      final truncation = <String, bool>{};
      final problems = <String>[];
      for (final mode in auditModes) {
        final report = await auditSurface(
          tester,
          surface: 'activity-inbox-rows',
          build: () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActivityInboxRow(
                row: enRow,
                host: fixture.host(phoneTouch: true),
              ),
              ActivityInboxRow(
                row: zhRow,
                host: fixture.host(phoneTouch: true),
              ),
              ActivityObjectRow(
                row: objRow,
                host: fixture.host(phoneTouch: true),
              ),
            ],
          ),
          theme: raftTheme(platform: TargetPlatform.android),
          platform: TargetPlatform.android,
          mode: mode,
          size: const Size(390, 500),
          truncationBaseline: truncation,
          screenshotDir: Platform.environment['RAFT_TEXT_SCALE_OUT'],
        );
        if (!report.ok) {
          problems.add('${mode.name}:\n  ${report.failures.join('\n  ')}');
        }
      }
      await tester.pump(const Duration(seconds: 3));
      expect(problems, isEmpty, reason: problems.join('\n'));
    },
  );

  for (final spec in [
    (
      'mobile-home-channels',
      const Size(390, 844),
      TargetPlatform.android,
      RaftRoute.home,
      null,
      true,
    ),
    (
      'mobile-activity',
      const Size(390, 844),
      TargetPlatform.android,
      RaftRoute.activity,
      null,
      false,
    ),
    (
      'mobile-channel',
      const Size(390, 844),
      TargetPlatform.android,
      RaftRoute.channel,
      'c1',
      false,
    ),
    (
      'mobile-tasks',
      const Size(390, 844),
      TargetPlatform.android,
      RaftRoute.tasks,
      null,
      false,
    ),
    (
      'mobile-settings',
      const Size(390, 844),
      TargetPlatform.android,
      RaftRoute.settings,
      null,
      false,
    ),
    (
      'desktop-channel',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.channel,
      'c1',
      false,
    ),
    (
      'desktop-activity',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.activity,
      null,
      false,
    ),
    (
      'desktop-search',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.search,
      null,
      false,
    ),
    (
      'desktop-tasks',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.tasks,
      null,
      false,
    ),
    (
      'desktop-saved',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.saved,
      null,
      false,
    ),
    (
      'desktop-drafts',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.drafts,
      null,
      false,
    ),
    (
      'desktop-settings',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.settings,
      null,
      false,
    ),
    (
      'desktop-members',
      const Size(1280, 900),
      TargetPlatform.linux,
      RaftRoute.members,
      null,
      false,
    ),
  ]) {
    testWidgets('audit ${spec.$1}: no glyph clipping across scales', (
      tester,
    ) async {
      final truncation = <String, bool>{};
      final problems = <String>[];
      for (final mode in auditModes) {
        final report = await auditWorkspaceSurface(
          tester,
          name: spec.$1,
          size: spec.$2,
          platform: spec.$3,
          route: spec.$4,
          entityId: spec.$5,
          mobileHome: spec.$6,
          mode: mode,
          truncation: truncation,
          verifyMounted: spec.$6
              ? (t) async {
                  expect(
                    find.byKey(const ValueKey('sidebar-channel-c1')),
                    findsOneWidget,
                  );
                }
              : null,
        );
        if (!report.ok) {
          problems.add('${mode.name}:\n  ${report.failures.join('\n  ')}');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
