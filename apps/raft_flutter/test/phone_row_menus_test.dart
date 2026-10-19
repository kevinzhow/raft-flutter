import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/user_error.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'support/app_services_fixture.dart';

/// Sidebar.tsx row menus on the phone Home list: a long press opens the same
/// anchored popover as Web's right click (`useLongPress`, 500 ms), and every
/// action behaves like Source - the sidebar order changes at once, the PATCH
/// follows (with `sectionsVersion` for section writes) and a failure rolls
/// the row back.
void main() {
  late WorkspaceController w;
  late MessageAdapter api;
  late List<Map<String, dynamic>> patches, posts;

  Future<void> setup(
    WidgetTester tester, {
    Map<String, dynamic> order = const {},
    Map<String, int> unread = const {},
    List<RaftChannel>? channels,
    List<RaftChannel>? dms,
    bool patchOk = true,
    Future<void>? patchGate,
    Set<String> mentions = const {},
    List<Map<String, dynamic>>? serverSummary,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final made = (await tester.runAsync(() => fixture('owner')))!;
    w = made.$1;
    api = made.$2;
    addTearDown(w.dispose);
    w.loading = false;
    w.messageDomain.ledger.switchServer('s1');
    w.channels =
        channels ??
        [
          RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
          RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
        ];
    w.dms =
        dms ??
        [
          RaftChannel({
            'id': 'd1',
            'name': 'Alice',
            'type': 'dm',
            'joined': true,
            'peerType': 'user',
            'peerId': 'u2',
            'peerName': 'alice',
            'peerDisplayName': 'Alice',
          }),
          RaftChannel({
            'id': 'd2',
            'name': 'Cindy',
            'type': 'dm',
            'joined': true,
            'peerType': 'agent',
            'peerId': 'a1',
            'peerName': 'cindy',
            'peerDisplayName': 'Cindy',
          }),
        ];
    w.unread = {...unread};
    w.mentions = {...mentions};
    if (serverSummary != null) {
      // The cross-server summary (`GET /servers/unread-summary`) the Home
      // Activity count and the other-server dot read.
      w.servers = [
        RaftRecord({'id': 's1', 'name': 'Visual', 'slug': 'visual'}),
        RaftRecord({'id': 's2', 'name': 'Other', 'slug': 'other'}),
      ];
      api.routes['GET /servers/unread-summary'] = (_) => serverSummary;
    }
    w.sidebarOrder = {'sectionsVersion': 3, 'pinnedVersion': 1, ...order};
    w.section = 'home';
    patches = [];
    posts = [];
    api.routes['GET /servers/s1/sidebar-order'] = (_) => w.sidebarOrder;
    if (patchOk) {
      api.routes['PATCH /servers/s1/sidebar-order'] = (o) async {
        patches.add(Map<String, dynamic>.from(o.data as Map));
        await patchGate;
        return {
          ...w.sidebarOrder,
          ...Map<String, dynamic>.from(o.data as Map),
          'sectionsVersion': 4,
        };
      };
    }
    for (final path in [
      '/channels/c1/read-all',
      '/channels/c1/unread',
      '/channels/d1/read-all',
    ]) {
      api.routes['POST $path'] = (o) {
        posts.add({'path': o.path});
        return {'unreadCount': 1, 'seq': '5', 'maxReadSeq': '5'};
      };
    }
    api.routes['POST /channels/c1/archive'] = (o) {
      posts.add({'path': o.path});
      return {'id': 'c1', 'archivedAt': '2026-10-12T00:00:00Z'};
    };
    api.routes['GET /channels/unread'] = (_) => {
      'channels': {'c1': 1},
    };
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        // main.dart installs the app error mapper above every route.
        builder: (_, child) =>
            RaftErrorScope(format: raftAppErrorFormatter, child: child!),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.brutal),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('sidebar-channel-$id'));

  Future<void> longPress(WidgetTester tester, Finder target) async {
    await tester.longPress(target);
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('Joint channels + opens Create Joint Channel in place, not a '
      'settings page', (tester) async {
    await setup(tester);
    api.routes['GET /agents'] = (_) => {'agents': []};
    api.routes['GET /servers/s1/members'] = (_) => {'members': []};
    expect(w.can('federateChannels'), isTrue);
    await tester.tap(find.bySemanticsLabel('Create joint channel'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateJointChannelDialog), findsOneWidget);
    expect(w.section, 'home');
    expect(w.location.settingsPath, isEmpty);
  });

  testWidgets('long press opens the anchored row menu with Web items', (
    tester,
  ) async {
    await setup(tester, unread: {'c1': 2});
    await longPress(tester, row('c1'));
    final labels = [
      'Move to section',
      'Mark as Read',
      'Pin',
      'Mute',
      'Archive',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Items in Web order, a popover (not a sheet) inside the 8px margin.
    final ys = [for (final l in labels) top(tester, find.text(l))];
    expect(ys, [...ys]..sort());
    final menu = tester.getRect(find.byType(RaftSidebarContextMenu));
    expect(menu.width, 192);
    expect(menu.left, greaterThanOrEqualTo(8));
    expect(menu.right, lessThanOrEqualTo(390 - 8));
    expect(menu.bottom, lessThanOrEqualTo(844 - 8));
  });

  testWidgets(
    'Pin moves the row to Pinned at once, PATCH has no section write',
    (tester) async {
      final gate = Completer<void>();
      await setup(tester, patchGate: gate.future);
      final channelsHeader = find.byKey(
        const ValueKey('sidebar-section-system:channels'),
      );
      expect(top(tester, row('c1')), greaterThan(top(tester, channelsHeader)));
      await longPress(tester, row('c1'));
      await tester.tap(find.text('Pin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // The request is still pending; the row already sits in Pinned.
      expect(gate.isCompleted, isFalse);
      expect(patches, [
        {
          'pinned': [
            {'kind': 'channel', 'id': 'c1'},
          ],
        },
      ]);
      expect(top(tester, row('c1')), lessThan(top(tester, channelsHeader)));
      expect(find.text('Pin'), findsNothing, reason: 'the menu closed');
      gate.complete();
      await tester.pumpAndSettle();
      expect(top(tester, row('c1')), lessThan(top(tester, channelsHeader)));
      expect((w.sidebarOrder['sectionsVersion']), 4);
    },
  );

  testWidgets('a failed Pin puts the row back', (tester) async {
    await setup(tester, patchOk: false);
    final header = find.byKey(
      const ValueKey('sidebar-section-system:channels'),
    );
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(top(tester, row('c1')), greaterThan(top(tester, header)));
    expect(w.error, isNull, reason: 'Web keeps silent');
  });

  testWidgets('pinned row offers Unpin and unpins at once', (tester) async {
    final gate = Completer<void>();
    await setup(
      tester,
      patchGate: gate.future,
      order: {
        'pinned': [
          {'kind': 'channel', 'id': 'c1'},
        ],
      },
    );
    final header = find.byKey(
      const ValueKey('sidebar-section-system:channels'),
    );
    expect(top(tester, row('c1')), lessThan(top(tester, header)));
    await longPress(tester, row('c1'));
    expect(find.text('Pin'), findsNothing);
    await tester.tap(find.text('Unpin'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(patches.single, {'pinned': <Object?>[]});
    expect(top(tester, row('c1')), greaterThan(top(tester, header)));
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Pin of a row in a custom section drops its placement with '
      'the sections version', (tester) async {
    await setup(
      tester,
      order: {
        'customSections': [
          {'id': 's9', 'name': 'Launch', 'emoji': null, 'sortMode': 'manual'},
        ],
        'sectionOrder': [
          'system:pinned',
          's9',
          'system:joint',
          'system:channels',
          'system:dms',
        ],
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's9', 'position': 0},
        ],
      },
    );
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(patches.single, {
      'pinned': [
        {'kind': 'channel', 'id': 'c1'},
      ],
      'sectionPlacements': <Object?>[],
      'sectionsVersion': 3,
    });
  });

  testWidgets('Move to section: submenu stays on screen, move is a versioned '
      'section write', (tester) async {
    await setup(
      tester,
      order: {
        'customSections': [
          {'id': 's9', 'name': 'Launch', 'emoji': null, 'sortMode': 'manual'},
        ],
        'sectionOrder': [
          'system:pinned',
          's9',
          'system:joint',
          'system:channels',
          'system:dms',
        ],
      },
    );
    await longPress(tester, row('c2'));
    await tester.tap(find.text('Move to section'));
    await tester.pumpAndSettle();
    expect(find.text('Launch'), findsWidgets);
    final sub = tester.getRect(find.text('New section…').first);
    expect(sub.left, greaterThanOrEqualTo(8));
    expect(sub.right, lessThanOrEqualTo(390 - 8));
    await tester.tap(find.text('Launch').last);
    await tester.pumpAndSettle();
    expect(patches.single, {
      'sectionPlacements': [
        {'kind': 'channel', 'id': 'c2', 'sectionId': 's9', 'position': 0},
      ],
      'pinned': <Object?>[],
      'sectionsVersion': 3,
    });
    // The row now lives under the Launch section header.
    final launch = find.byKey(const ValueKey('sidebar-section-s9'));
    final channels = find.byKey(
      const ValueKey('sidebar-section-system:channels'),
    );
    expect(top(tester, row('c2')), greaterThan(top(tester, launch)));
    expect(top(tester, row('c2')), lessThan(top(tester, channels)));
  });

  testWidgets('a 409 on a section write rolls back and reloads the order', (
    tester,
  ) async {
    await setup(
      tester,
      order: {
        'customSections': [
          {'id': 's9', 'name': 'Launch', 'emoji': null, 'sortMode': 'manual'},
        ],
        'sectionOrder': [
          'system:pinned',
          's9',
          'system:joint',
          'system:channels',
          'system:dms',
        ],
      },
      patchOk: false,
    );
    var reads = 0;
    api.routes['PATCH /servers/s1/sidebar-order'] = (o) {
      patches.add(Map<String, dynamic>.from(o.data as Map));
      throw StateError('conflict');
    };
    api.routes['GET /servers/s1/sidebar-order'] = (_) {
      reads++;
      return {...w.sidebarOrder};
    };
    await longPress(tester, row('c2'));
    await tester.tap(find.text('Move to section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launch').last);
    await tester.pumpAndSettle();
    expect(patches, hasLength(1));
    expect(
      (w.sidebarOrder['sectionPlacements'] as List?) ?? const [],
      isEmpty,
      reason: 'rolled back',
    );
    expect(reads, greaterThanOrEqualTo(0));
  });

  testWidgets('Mute is optimistic; Unmute toggles back', (tester) async {
    final gate = Completer<void>();
    await setup(tester);
    api.routes['PATCH /channels/c1/notification-settings'] = (o) async {
      posts.add({'path': o.path, 'data': o.data});
      await gate.future;
      return {'activityMuted': true, 'muteFromSeq': '9', 'prefsVersion': 2};
    };
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Mute'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(w.channelById('c1')!.flag('activityMuted'), isTrue);
    expect(posts.single['data'], {'activityMuted': true});
    gate.complete();
    await tester.pumpAndSettle();
    expect(w.channelById('c1')!.json['muteFromSeq'], '9');
    await longPress(tester, row('c1'));
    expect(find.text('Unmute'), findsOneWidget);
  });

  testWidgets('a failed Mute restores the row and shows the Web toast', (
    tester,
  ) async {
    await setup(tester);
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();
    expect(w.channelById('c1')!.flag('activityMuted'), isFalse);
    expect(
      find.text('Failed to mute Activity for this channel.'),
      findsOneWidget,
    );
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('DMs have no Mute; Mark as Read posts read-all', (tester) async {
    await setup(tester, unread: {'d1': 3});
    await longPress(tester, row('d1'));
    expect(find.text('Mute'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Close Chat'), findsOneWidget);
    await tester.tap(find.text('Mark as Read'));
    await tester.pumpAndSettle();
    expect(posts.map((p) => p['path']), contains('/channels/d1/read-all'));
    expect(w.unread['d1'] ?? 0, 0);
  });

  testWidgets('Mark as Unread shows the unread state before the reply', (
    tester,
  ) async {
    await setup(tester);
    await longPress(tester, row('c1'));
    expect(find.text('Mark as Unread'), findsOneWidget);
    await tester.tap(find.text('Mark as Unread'));
    await tester.pump();
    expect(w.unread['c1'], greaterThan(0));
    await tester.pumpAndSettle();
    expect(posts.map((p) => p['path']), contains('/channels/c1/unread'));
  });

  testWidgets('human DM Pin uses a human ref, agent DM an agent ref', (
    tester,
  ) async {
    await setup(tester);
    await longPress(tester, row('d1'));
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(patches.last['pinned'], [
      {'kind': 'human', 'id': 'u2'},
    ]);
    await longPress(tester, row('d2'));
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(patches.last['pinned'], [
      {'kind': 'human', 'id': 'u2'},
      {'kind': 'agent', 'id': 'a1'},
    ]);
  });

  testWidgets('Close Chat hides the DM at once', (tester) async {
    await setup(tester);
    expect(row('d1'), findsOneWidget);
    await longPress(tester, row('d1'));
    await tester.tap(find.text('Close Chat'));
    await tester.pump();
    expect(row('d1'), findsNothing, reason: 'hidden before the reply');
    await tester.pumpAndSettle();
    expect(patches.single, {
      'hiddenDmIds': ['d1'],
    });
  });

  testWidgets('Archive asks first, runs "Archiving…" and removes the row', (
    tester,
  ) async {
    await setup(tester);
    api.routes['GET /channels'] = (_) => [
      {'id': 'c2', 'name': 'random', 'joined': true},
    ];
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Archive Channel'), findsWidgets);
    expect(
      find.textContaining('Archive "general"? Members keep read access'),
      findsOneWidget,
    );
    expect(posts, isEmpty, reason: 'nothing before the confirmation');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Channel').last);
    await tester.pumpAndSettle();
    expect(posts.map((p) => p['path']), ['/channels/c1/archive']);
  });

  testWidgets('a failed Archive keeps the dialog open with the error', (
    tester,
  ) async {
    await setup(tester);
    api.routes.remove('POST /channels/c1/archive');
    await longPress(tester, row('c1'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Channel').last);
    await tester.pumpAndSettle();
    expect(find.text('Archive Channel'), findsWidgets);
    expect(find.text('Unexpected endpoint'), findsOneWidget);
  });

  Future<void> secondaryTapAt(WidgetTester tester, Finder target) async {
    await tester.tapAt(
      tester.getCenter(target),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
  }

  group('Home list indicators (Sidebar.tsx)', () {
    Finder activityBadge(String text) => find.descendant(
      of: find.byKey(const Key('nav-activity')),
      matching: find.text(text),
    );

    testWidgets('Activity shows the server activityUnreadCount, not the sum '
        'of the row counts', (tester) async {
      await setup(
        tester,
        unread: {'c1': 50, 'd1': 60},
        serverSummary: [
          {
            'serverId': 's1',
            'unreadCount': 110,
            'activityUnreadCount': 3,
            'serverPushMuted': false,
          },
        ],
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(activityBadge('3'), findsOneWidget);
      expect(activityBadge('99+'), findsNothing);
    });

    testWidgets('Activity caps at 99+ and hides when the count is unknown', (
      tester,
    ) async {
      await setup(
        tester,
        unread: {'c1': 5},
        serverSummary: [
          {
            'serverId': 's1',
            'unreadCount': 5,
            'activityUnreadCount': 120,
            'serverPushMuted': false,
          },
        ],
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(activityBadge('99+'), findsOneWidget);
    });

    testWidgets('Activity has no badge before the summary is known', (
      tester,
    ) async {
      await setup(tester, unread: {'c1': 5, 'd1': 7});
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(activityBadge('12'), findsNothing);
      expect(activityBadge('99+'), findsNothing);
    });

    testWidgets('the @ marker shows on a joined channel with an unread '
        'mention, before the count', (tester) async {
      await setup(tester, unread: {'c1': 2, 'c2': 1}, mentions: {'c1'});
      final marker = find.byKey(const ValueKey('sidebar-mention-marker'));
      expect(find.descendant(of: row('c1'), matching: marker), findsOneWidget);
      expect(find.descendant(of: row('c2'), matching: marker), findsNothing);
      expect(
        tester.getTopRight(marker).dx,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(of: row('c1'), matching: find.text('2')),
              )
              .dx,
        ),
      );
      expect(tester.getSize(marker), const Size(16, 16));
    });

    testWidgets('no @ marker once the channel is read or for a DM', (
      tester,
    ) async {
      await setup(tester, unread: {'d1': 2}, mentions: {'c1', 'd1'});
      expect(
        find.byKey(const ValueKey('sidebar-mention-marker')),
        findsNothing,
      );
    });

    testWidgets('a mention flag follows the unread snapshot and is cleared '
        'with the count', (tester) async {
      await setup(tester, unread: {'c1': 2});
      api.routes['GET /channels/unread'] = (_) => {
        'channels': {
          'c1': {'unreadCount': 2, 'hasMention': true},
          'c2': {'unreadCount': 1},
        },
      };
      await tester.runAsync(w.refreshUnread);
      await tester.pumpAndSettle();
      expect(w.mentions, {'c1'});
      expect(
        find.descendant(
          of: row('c1'),
          matching: find.byKey(const ValueKey('sidebar-mention-marker')),
        ),
        findsOneWidget,
      );
      // The server agrees once the read receipt lands.
      api.routes['GET /channels/unread'] = (_) => {'channels': {}};
      await longPress(tester, row('c1'));
      await tester.tap(find.text('Mark as Read'));
      await tester.pumpAndSettle();
      expect(w.mentions, isEmpty);
      expect(
        find.byKey(const ValueKey('sidebar-mention-marker')),
        findsNothing,
      );
    });

    testWidgets('a collapsed section shows an unread dot, an expanded or '
        'muted one does not', (tester) async {
      await setup(
        tester,
        unread: {'c1': 2},
        channels: [
          RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
          RaftChannel({
            'id': 'c2',
            'name': 'random',
            'joined': true,
            'activityMuted': true,
          }),
        ],
      );
      final dot = find.byKey(const ValueKey('sidebar-section-unread-dot'));
      expect(dot, findsNothing, reason: 'expanded');
      await tester.tap(
        find.byKey(const ValueKey('sidebar-disclosure-system:channels')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-section-system:channels')),
          matching: dot,
        ),
        findsOneWidget,
      );
      w.unread = {'c2': 5};
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(dot, findsNothing, reason: 'only a muted channel is unread');
      await tester.tap(
        find.byKey(const ValueKey('sidebar-disclosure-system:dms')),
      );
      await tester.pumpAndSettle();
      expect(dot, findsNothing, reason: 'collapsed DMs have no unread');
    });

    testWidgets('the Home header marks other servers with activity unread', (
      tester,
    ) async {
      await setup(
        tester,
        serverSummary: [
          {'serverId': 's1', 'unreadCount': 0, 'activityUnreadCount': 0},
          {'serverId': 's2', 'unreadCount': 4, 'activityUnreadCount': 4},
        ],
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Other servers have unread messages'),
        findsOneWidget,
      );
    });

    testWidgets('no header dot when only this server has activity unread', (
      tester,
    ) async {
      await setup(
        tester,
        serverSummary: [
          {'serverId': 's1', 'unreadCount': 3, 'activityUnreadCount': 3},
          {'serverId': 's2', 'unreadCount': 0, 'activityUnreadCount': 0},
        ],
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Other servers have unread messages'),
        findsNothing,
      );
    });
  });

  group('Close Chat on the phone', () {
    // Sidebar.tsx closeDm navigates to the server home only when the URL is
    // that DM. The phone mounts the list on the Home route alone, so the row
    // menu cannot be up while the DM is the open page; a stale selection on
    // the Home list must not send the user anywhere.
    testWidgets('closing the last-opened DM from the Home list stays on Home', (
      tester,
    ) async {
      await setup(tester);
      w.channel = w.dms.first;
      await longPress(tester, row('d1'));
      await tester.tap(find.text('Close Chat'));
      await tester.pumpAndSettle();
      expect(w.section, 'home');
      expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
      expect(row('d1'), findsNothing);
      expect(patches.single, {
        'hiddenDmIds': ['d1'],
      });
    });
  });

  group('Section and surface menus (long press on the phone, right click)', () {
    testWidgets('a long press on a section header opens its menu', (
      tester,
    ) async {
      await setup(tester);
      final header = find.byKey(
        const ValueKey('sidebar-section-system:channels'),
      );
      await tester.longPressAt(tester.getCenter(header));
      await tester.pumpAndSettle();
      expect(find.text('Hide empty sections'), findsOneWidget);
      expect(find.text('Show joined channels only'), findsOneWidget);
    });

    testWidgets('a right click on a section header opens its menu', (
      tester,
    ) async {
      await setup(tester);
      await secondaryTapAt(
        tester,
        find.byKey(const ValueKey('sidebar-section-system:channels')),
      );
      expect(find.text('Hide empty sections'), findsOneWidget);
    });

    testWidgets('a long press on the list surface opens the surface menu', (
      tester,
    ) async {
      await setup(tester);
      final list = find.byKey(const Key('workspace-sidebar'));
      await tester.longPressAt(
        tester.getBottomLeft(list) + const Offset(120, -30),
      );
      await tester.pumpAndSettle();
      expect(find.text('New section…'), findsOneWidget);
    });

    testWidgets('a right click on the list surface opens the surface menu', (
      tester,
    ) async {
      await setup(tester);
      final list = find.byKey(const Key('workspace-sidebar'));
      await tester.tapAt(
        tester.getBottomLeft(list) + const Offset(120, -30),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('New section…'), findsOneWidget);
    });

    testWidgets('a long press on a row still opens its menu', (tester) async {
      await setup(tester);
      await longPress(tester, row('c1'));
      expect(find.text('Mark as Unread'), findsOneWidget);
    });
  });
}
