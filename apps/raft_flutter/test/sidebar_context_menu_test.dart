import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'support/app_services_fixture.dart';

/// Sidebar.tsx context menus: channel / DM rows, section headers, the sidebar
/// surface and the section dialog, with the Source actions
/// (PATCH /servers/:id/sidebar-order, POST /channels/:id/read-all|unread).
void main() {
  Future<(WorkspaceController, MessageAdapter, List<Object?>)> setup(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    bool dark = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    w.loading = false;
    w.messageDomain.ledger.switchServer('s1');
    w.channels = [
      RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
      RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
    ];
    w.dms = [
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
    ];
    w.section = 'chat';
    final patches = <Object?>[];
    api.routes['PATCH /servers/s1/sidebar-order'] = (o) {
      patches.add(o.data);
      return {};
    };
    api.routes['GET /servers/s1/sidebar-order'] = (_) => {};
    api.routes['POST /channels/c1/unread'] = (_) => {'unreadCount': 1};
    api.routes['POST /channels/inbox/read-all'] = (_) => {};
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (w, api, patches);
  }

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tapAt(
      tester.getCenter(target),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('[WP1] channel row: menu items, pin patches the pinned list', (
    tester,
  ) async {
    final (_, _, patches) = await setup(tester);
    await rightClick(tester, find.byKey(const ValueKey('sidebar-channel-c1')));
    for (final label in [
      'Move to Section',
      'Mark as Unread',
      'Pin',
      'Mute',
      'Archive Channel',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    // Source togglePinnedRef: no section write when no placement is dropped.
    expect(patches.single, {
      'pinned': [
        {'kind': 'channel', 'id': 'c1'},
      ],
    });
    expect(find.text('Pin'), findsNothing, reason: 'the menu closed');
  });

  testWidgets('[WP1] Move to section opens its submenu on hover', (
    tester,
  ) async {
    await setup(tester);
    await rightClick(tester, find.byKey(const ValueKey('sidebar-channel-c1')));
    // The Pinned group heading is the only match until the submenu opens.
    expect(find.text('Pinned'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await mouse.addPointer(location: Offset.zero);
    } on AssertionError {
      // The right click already added the mouse device.
    }
    await mouse.moveTo(tester.getCenter(find.text('Move to Section')));
    await tester.pumpAndSettle();
    expect(find.text('Pinned'), findsNWidgets(2));
    expect(find.text('New Section…'), findsOneWidget);
  });

  testWidgets('[WP1] DM row: Close Chat hides the DM', (tester) async {
    final (_, _, patches) = await setup(tester);
    await rightClick(tester, find.byKey(const ValueKey('sidebar-channel-d1')));
    expect(find.text('Close Chat'), findsOneWidget);
    await tester.tap(find.text('Close Chat'));
    await tester.pumpAndSettle();
    expect(patches.single, {
      'hiddenDmIds': ['d1'],
    });
  });

  testWidgets('[WP1] section menu: sort radio patches the sort mode', (
    tester,
  ) async {
    final (_, _, patches) = await setup(tester);
    await rightClick(
      tester,
      find.byKey(const ValueKey('sidebar-section-system:channels')),
    );
    // Fixed Sidebar.tsx:4608 mounts the section popup with w-60.
    expect(
      tester.getSize(find.byType(RaftSidebarContextMenu)),
      const Size(240, 359),
    );
    for (final label in [
      'Create Channel',
      'Sort',
      'Manual',
      'Recent',
      'A-Z',
      'Display',
      'Show Joined Channels Only',
      'Hide Empty Sections',
      'New Section…',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(patches.single, {'channelSortMode': 'recent'});
  });

  testWidgets('[WP1] surface menu: New section dialog creates a section', (
    tester,
  ) async {
    final (_, _, patches) = await setup(tester);
    final list = find.byKey(const Key('workspace-sidebar'));
    // Below the last row: the empty surface of the list.
    await tester.tapAt(
      tester.getBottomLeft(list) + const Offset(60, -40),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('New Section…'), findsOneWidget);
    // Fixed Sidebar.tsx:4717 uses the same w-60 for the empty surface.
    expect(tester.getSize(find.byType(RaftSidebarContextMenu)).width, 240);
    await tester.tap(find.text('New Section…'));
    await tester.pumpAndSettle();
    expect(find.text('New Section'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'Launch');
    await tester.pump();
    await tester.tap(find.text('Create Section'));
    await tester.pumpAndSettle();
    final sections = (patches.single as Map)['customSections'] as List;
    expect((sections.single as Map)['name'], 'Launch');
    expect((sections.single as Map)['sortMode'], 'manual');
    expect(find.text('New Section'), findsNothing);
  });

  for (final section in [true, false]) {
    testWidgets('narrow dark sidebar ${section ? 'section' : 'surface'} '
        'menu keeps the source fixed width', (tester) async {
      await setup(tester, size: const Size(900, 900), dark: true);
      if (section) {
        await rightClick(
          tester,
          find.byKey(const ValueKey('sidebar-section-system:channels')),
        );
        expect(find.text('Sort'), findsOneWidget);
      } else {
        final list = find.byKey(const Key('workspace-sidebar'));
        await tester.tapAt(
          tester.getBottomLeft(list) + const Offset(60, -40),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('New Section…'), findsOneWidget);
      }
      final menu = tester.getRect(find.byType(RaftSidebarContextMenu));
      expect(menu.width, 240);
      if (section) expect(menu.height, 359);
      expect(menu.left, greaterThanOrEqualTo(8));
      expect(menu.right, lessThanOrEqualTo(900 - 8));
    });
  }
}
