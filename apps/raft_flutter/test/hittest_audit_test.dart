import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/hittest_audit.dart';
import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart' show pageFixture, pageFrames;
import 'support/app_services_fixture.dart';

void main() {
  const sampleCode =
      'const value = "long code line with horizontal overflow to exercise code block hit tests";';

  List<Map<String, dynamic>> makeRichChannelMessages() => [
    for (var i = 1; i <= 12; i++)
      {
        ...row('m$i', 'c1', i),
        'createdAt': '2026-10-08T00:${i.toString().padLeft(2, '0')}:00Z',
        'senderId': i.isEven ? 'u1' : 'bob',
        'senderType': 'user',
        'senderName': i.isEven ? 'Alice' : 'Bob',
        'content': switch (i) {
          11 =>
            'Hello [@Alice](raft-ref://mention/user/alice) see [#random](raft-ref://channel/c2)\n\n```ts\n$sampleCode\n```\n\nAfter code.',
          12 =>
            'Diagram check\n\n```mermaid\ngraph TD\n  A[Start] --> B[End]\n```',
          _ => 'Channel filler message $i with enough text to scroll.',
        },
        if (i == 11)
          'reactions': [
            {
              'emoji': '\u{1F44D}',
              'count': 2,
              'reactorIds': ['u2', 'u3'],
              'reactorNames': ['Dana', 'Eve'],
            },
          ],
        if (i == 11)
          'attachments': [
            {
              'id': 'file-1',
              'filename': 'report.md',
              'mimeType': 'text/markdown',
              'size': 256,
            },
          ],
      },
  ];

  List<Map<String, dynamic>> makeRichThreadMessages() => [
    for (var i = 1; i <= 18; i++)
      {
        ...row('r$i', 't1', i),
        'createdAt': '2026-10-08T00:${i.toString().padLeft(2, '0')}:00Z',
        'senderId': i.isEven ? 'u1' : 'bob',
        'senderType': 'user',
        'senderName': i.isEven ? 'Alice' : 'Bob',
        'content': i == 18
            ? 'Thread reply with code\n\n```ts\n$sampleCode\n```\n\nTail text.'
            : 'Thread reply $i to populate outline ticks and scroll.',
      },
  ];

  Future<WorkspaceController> mountSurface(
    WidgetTester tester, {
    required Size size,
    TargetPlatform platform = TargetPlatform.linux,
    RaftRoute route = RaftRoute.channel,
    String? entityId = 'c1',
    bool openThread = false,
    bool openProfile = false,
    bool openChannelSettings = false,
  }) async {
    final channelMessages = makeRichChannelMessages();
    final threadMessages = makeRichThreadMessages();
    final (w, api) = await pageFixture(tester);
    w.channels = [
      RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
      RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
    ];
    w.channel = w.channels.first;
    w.messageDomain.ledger.ingest(
      channelMessages,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final m in channelMessages) m['id'] as String,
    };
    w.messageDomain.threadSummaries = {
      'm11': {'replyCount': threadMessages.length},
    };
    api.routes['GET /agents'] = (_) => [
      {
        'id': 'agent-1',
        'name': 'Helper Bot',
        'handle': 'helper',
        'status': 'online',
      },
    ];
    api.routes['GET /servers/s1/members'] = (_) => [
      {'id': 'bob', 'name': 'Bob', 'handle': 'bob', 'role': 'member'},
      {'id': 'u1', 'name': 'Alice', 'handle': 'alice', 'role': 'owner'},
    ];
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /channels/c1/threads/m11'] = (_) => {
      'threadChannelId': 't1',
    };
    api.routes['GET /messages/channel/t1'] = (_) => {
      'messages': threadMessages,
    };
    api.routes['GET /messages/channel/t1/human-outline'] = (_) => {
      'items': [
        for (var i = 0; i < threadMessages.length; i++)
          {
            'id': threadMessages[i]['id'],
            'senderId': threadMessages[i]['senderId'],
            'senderType': 'user',
            'senderName': threadMessages[i]['senderName'],
            'content': 'Human message $i',
            'createdAt': threadMessages[i]['createdAt'],
            'seq': threadMessages[i]['seq'],
          },
      ],
      'hasMore': false,
    };
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [
        {
          'kind': 'channel',
          'channelId': 'c1',
          'channelName': 'general',
          'lastMessagePreview': 'Hello world',
          'unreadCount': 2,
          'firstUnreadMessageId': 'm11',
          'lastMessageId': 'm12',
        },
      ],
    };
    api.routes['GET /messages/search'] = (_) => {
      'results': [
        {
          ...channelMessages[10],
          'channelName': 'general',
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
          'title': 'Audit hit tests',
          'status': 'in_progress',
          'channelId': 'c1',
          'channelName': 'general',
          'createdAt': '2026-10-08T00:00:00Z',
          'updatedAt': '2026-10-08T00:00:00Z',
        },
      ],
      'nextCursor': null,
    };
    api.routes['GET /tasks/channel/c1'] = (_) => {
      'tasks': [
        {
          'id': 'task-1',
          'number': 1,
          'title': 'Audit hit tests',
          'status': 'in_progress',
          'channelId': 'c1',
          'channelName': 'general',
          'createdAt': '2026-10-08T00:00:00Z',
          'updatedAt': '2026-10-08T00:00:00Z',
        },
      ],
      'nextCursor': null,
    };
    api.routes['GET /messages/saved'] = (_) => {
      'messages': [channelMessages[10]],
      'hasMore': false,
    };
    api.routes['GET /computers'] = (_) => [];
    api.routes['GET /apps'] = (_) => [];
    api.routes['GET /integrations'] = (_) => [];
    api.routes['GET /servers/s1/billing'] = (_) => {};

    if (route != RaftRoute.channel) {
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: w.location.serverSlug,
          route: route,
          entityId: entityId,
        ),
      );
    }

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(platform: platform).copyWith(platform: platform),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (openThread) {
      await tester.tap(find.byKey(const ValueKey('thread-replies-badge-m11')));
      await tester.runAsync(() async {
        for (var i = 0; i < 40 && w.messageDomain.state.threadLoading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await pageFrames(tester, () {});
    }
    if (openProfile) {
      w.openProfile(RaftProfileKind.human, 'bob');
      await pageFrames(tester, () {});
    }
    if (openChannelSettings) {
      w.navigation.navigate(
        w.location.withQuery({'channelPage': 'settings:c1'}),
      );
      await pageFrames(tester, () {});
    }

    return w;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> scrollVisibleTimelines(WidgetTester tester) async {
    for (final list in find.byType(CustomScrollView).evaluate()) {
      final box = list.renderObject;
      if (box is! RenderBox || !box.hasSize || box.size.height < 200) continue;
      final center = box.localToGlobal(box.size.center(Offset.zero));
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 12)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -12)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  bool ignoreOutlineTickHoverPreviewOverlay(
    DiscoveredControl control,
    String probe,
  ) =>
      probe.startsWith('hover-') &&
      (control.keyDescription?.contains('thread-outline-tick-') ?? false);

  Future<void> runAudit(
    WidgetTester tester,
    String surface, {
    bool touch = false,
  }) async {
    final report = await auditHitTests(
      tester,
      surface: surface,
      options: HitTestAuditOptions(
        probeHoverStability: !touch,
        ignoreProbe: ignoreOutlineTickHoverPreviewOverlay,
      ),
    );
    expect(
      report.probedControls,
      greaterThan(0),
      reason: 'must probe controls',
    );
    expect(report.findings, isEmpty, reason: report.formatFailure());
  }

  testWidgets('audit: desktop channel timeline (1280x900, scrolled)', (
    tester,
  ) async {
    await mountSurface(tester, size: const Size(1280, 900));
    await scrollVisibleTimelines(tester);
    await runAudit(tester, 'desktop-channel-1280');
    await finish(tester);
  });

  testWidgets('audit: desktop thread + outline ticks (1280x900, scrolled)', (
    tester,
  ) async {
    await mountSurface(tester, size: const Size(1280, 900), openThread: true);
    await scrollVisibleTimelines(tester);
    await runAudit(tester, 'desktop-thread-1280');
    await finish(tester);
  });

  testWidgets('audit: split-pane thread + outline ticks (900x800, scrolled)', (
    tester,
  ) async {
    await mountSurface(tester, size: const Size(900, 800), openThread: true);
    await scrollVisibleTimelines(tester);
    await runAudit(tester, 'split-thread-900');
    await finish(tester);
  });

  testWidgets('audit: profile side panel over/beside conversation (1280x900)', (
    tester,
  ) async {
    await mountSurface(tester, size: const Size(1280, 900), openProfile: true);
    await runAudit(tester, 'desktop-profile-1280');
    await finish(tester);
  });

  testWidgets('audit: mobile channel settings page (390x844, Android)', (
    tester,
  ) async {
    await mountSurface(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      openChannelSettings: true,
    );
    await runAudit(tester, 'mobile-channel-settings-390', touch: true);
    await finish(tester);
  });

  testWidgets('audit: activity surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.activity,
      entityId: null,
    );
    await runAudit(tester, 'desktop-activity-1280');
    await finish(tester);
  });

  testWidgets('audit: search surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.search,
      entityId: null,
    );
    await runAudit(tester, 'desktop-search-1280');
    await finish(tester);
  });

  testWidgets('audit: tasks surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.tasks,
      entityId: null,
    );
    await runAudit(tester, 'desktop-tasks-1280');
    await finish(tester);
  });

  testWidgets('audit: settings surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.settings,
      entityId: null,
    );
    await runAudit(tester, 'desktop-settings-1280');
    await finish(tester);
  });

  testWidgets('audit: apps surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.apps,
      entityId: null,
    );
    await runAudit(tester, 'desktop-apps-1280');
    await finish(tester);
  });

  testWidgets('audit: computers surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.computers,
      entityId: null,
    );
    await runAudit(tester, 'desktop-computers-1280');
    await finish(tester);
  });

  testWidgets('audit: members surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.members,
      entityId: null,
    );
    await runAudit(tester, 'desktop-members-1280');
    await finish(tester);
  });

  testWidgets('audit: saved surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.saved,
      entityId: null,
    );
    await runAudit(tester, 'desktop-saved-1280');
    await finish(tester);
  });

  testWidgets('audit: mobile channel (390x844, Android)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    await runAudit(tester, 'mobile-channel-390', touch: true);
    await finish(tester);
  });

  testWidgets('audit: mobile tasks (390x844, Android)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      route: RaftRoute.tasks,
      entityId: null,
    );
    await runAudit(tester, 'mobile-tasks-390', touch: true);
    await finish(tester);
  });

  testWidgets('audit: mobile settings (390x844, Android)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      route: RaftRoute.settings,
      entityId: null,
    );
    await runAudit(tester, 'mobile-settings-390', touch: true);
    await finish(tester);
  });

  testWidgets(
    'audit: desktop channel with message hover toolbar open (1280x900)',
    (tester) async {
      await mountSurface(tester, size: const Size(1280, 900));
      await scrollVisibleTimelines(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final rowFinder = find.byKey(const ValueKey('message-m12'));
      await mouse.moveTo(tester.getTopLeft(rowFinder) + const Offset(60, 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RaftMessageToolbar), findsOneWidget);
      final report = await auditHitTests(
        tester,
        surface: 'desktop-hover-toolbar-1280',
        options: HitTestAuditOptions(
          root: find.byType(RaftMessageToolbar),
          mouse: mouse,
          probeHoverStability: true,
        ),
      );
      expect(report.probedControls, greaterThanOrEqualTo(3));
      expect(report.findings, isEmpty, reason: report.formatFailure());
      await finish(tester);
    },
  );

  testWidgets('audit: drafts surface (1280x900)', (tester) async {
    await mountSurface(
      tester,
      size: const Size(1280, 900),
      route: RaftRoute.drafts,
      entityId: null,
    );
    await runAudit(tester, 'desktop-drafts-1280');
    await finish(tester);
  });

  testWidgets('audit: message context menu popover (1280x900)', (tester) async {
    await mountSurface(tester, size: const Size(1280, 900));
    final rowFinder = find.byKey(const ValueKey('message-m12'));
    final target = tester.getCenter(rowFinder);
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.addPointer(location: target);
    addTearDown(mouse.removePointer);
    await mouse.down(target);
    await mouse.up();
    await tester.pumpAndSettle();

    final popover = find.byType(RaftPopoverSurface);
    expect(popover, findsOneWidget);
    final report = await auditHitTests(
      tester,
      surface: 'desktop-message-context-menu-1280',
      options: HitTestAuditOptions(
        root: popover,
        mouse: mouse,
        probeHoverStability: true,
      ),
    );
    expect(report.probedControls, greaterThanOrEqualTo(3));
    expect(report.findings, isEmpty, reason: report.formatFailure());
    await finish(tester);
  });

  testWidgets('audit: mobile search & activity (390x844, Android)', (
    tester,
  ) async {
    await mountSurface(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      route: RaftRoute.activity,
      entityId: null,
    );
    await runAudit(tester, 'mobile-activity-390', touch: true);
    await finish(tester);
  });

  testWidgets('audit: narrow desktop channel (600x800, scrolled)', (
    tester,
  ) async {
    await mountSurface(tester, size: const Size(600, 800));
    await scrollVisibleTimelines(tester);
    await runAudit(tester, 'narrow-desktop-channel-600');
    await finish(tester);
  });

  testWidgets('audit: scrollable dialog card with footer actions (1280x900)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: RaftModalBackdrop(
            child: RaftDialog.card(
              title: 'Dialog Audit',
              onClose: () {},
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  RaftButton(label: 'Cancel', onPressed: () {}),
                  RaftButton(label: 'Confirm', onPressed: () {}),
                ],
              ),
              child: const SizedBox(height: 900, child: Text('Long body')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await runAudit(tester, 'dialog-card-1280');
    await finish(tester);
  });
}
