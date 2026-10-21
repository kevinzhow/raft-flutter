import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/closed_dm_reopen.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/sidebar_disclosure.dart';
import 'package:raft_flutter/features/sidebar_drop.dart' show reopenOpenedDm;
import 'package:raft_flutter/features/sidebar_projection.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

RaftChannel _dm(String id, String name) => RaftChannel({
  'id': id,
  'name': name,
  'type': 'dm',
  'joined': true,
  'peerType': 'user',
  'peerId': 'u-$id',
  'peerDisplayName': name,
});

/// Sidebar.tsx rows and sections: the quiet "new" dot, the Slack chip, the
/// per-server "joined channels only" choice and closed DMs.
void main() {
  group('channel rows', () {
    testWidgets('a non-joined channel with new messages shows the quiet dot; '
        'a count, a joined channel or no flag shows none', (t) async {
      final (w, _) = await pageFixture(t);
      w.channels.addAll([
        RaftChannel({'id': 'fresh', 'name': 'Fresh', 'joined': false}),
        RaftChannel({'id': 'counted', 'name': 'Counted', 'joined': false}),
        RaftChannel({'id': 'mine', 'name': 'Mine', 'joined': true}),
        RaftChannel({'id': 'old', 'name': 'Old', 'joined': false}),
      ]);
      await mountPage(t, w, RaftFamily.elegant, false);
      // The unread summary the page loads on mount replaces both.
      w.conversationReads
        ..newFlags = {'fresh', 'counted', 'mine'}
        ..unread.addAll({'counted': 4});
      w.notifyListeners();
      await t.pumpAndSettle();
      Finder dot(String id) => find.descendant(
        of: find.byKey(ValueKey('sidebar-channel-$id')),
        matching: find.byKey(const ValueKey('sidebar-quiet-new-dot')),
      );
      expect(dot('fresh'), findsOneWidget);
      expect(dot('counted'), findsNothing);
      expect(find.byType(RaftSidebarQuietUnreadCount), findsOneWidget);
      expect(dot('mine'), findsNothing);
      expect(dot('old'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('New messages')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a Slack-bridged channel carries the Slack chip', (t) async {
      final (w, _) = await pageFixture(t);
      w.channels.addAll([
        RaftChannel({
          'id': 'bridged',
          'name': 'Bridged',
          'joined': true,
          'bridge': {
            'provider': 'slack',
            'providerConversationId': 'C1',
            'state': 'active',
          },
        }),
        RaftChannel({'id': 'plain', 'name': 'Plain', 'joined': true}),
      ]);
      await mountPage(t, w, RaftFamily.elegant, false);
      Finder chip(String id) => find.descendant(
        of: find.byKey(ValueKey('sidebar-channel-$id')),
        matching: find.byType(RaftBadge),
      );
      expect(chip('bridged'), findsOneWidget);
      expect(t.widget<RaftBadge>(chip('bridged')).label, 'Slack');
      expect(chip('plain'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('joined channels only', () {
    Future<void> bind(SidebarDisclosureStore s, String server) => s.bind(
      origin: 'https://fixture.invalid',
      principal: 'alice',
      server: server,
      scope: server,
    );

    test('is remembered per server', () async {
      final storage = _Storage();
      final first = SidebarDisclosureStore(storage: storage);
      await bind(first, 's1');
      expect(first.joinedChannelsOnly, isFalse);
      expect(first.setJoinedChannelsOnly('s1', true), isTrue);
      await first.writes;
      first.dispose();

      final later = SidebarDisclosureStore(storage: storage);
      await bind(later, 's1');
      expect(later.joinedChannelsOnly, isTrue);
      await bind(later, 's2');
      expect(later.joinedChannelsOnly, isFalse);
      await bind(later, 's1');
      expect(later.joinedChannelsOnly, isTrue);
      // Section disclosure keeps working beside it.
      later.setExpanded('s1', 'system:dms', false);
      expect(later.collapsed['system:dms'], isTrue);
      expect(later.joinedChannelsOnly, isTrue);
      later.dispose();
    });

    testWidgets('the Channels section lists joined channels only', (t) async {
      final (w, _) = await pageFixture(t);
      w.channels.addAll([
        RaftChannel({'id': 'in', 'name': 'Inside', 'joined': true}),
        RaftChannel({'id': 'out', 'name': 'Outside', 'joined': false}),
      ]);
      await mountPage(t, w, RaftFamily.elegant, false);
      expect(find.text('Outside'), findsOneWidget);
      await t.tapAt(
        t.getCenter(
          find.byKey(const ValueKey('sidebar-section-system:channels')),
        ),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Show joined channels only'));
      await t.pumpAndSettle();
      expect(find.text('Outside'), findsNothing);
      expect(find.text('Inside'), findsOneWidget);
      expect(find.text('No joined channels'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('an emptied Channels section says no channel is joined', (
      t,
    ) async {
      final (w, _) = await pageFixture(t);
      w.channels = [
        RaftChannel({'id': 'out', 'name': 'Outside'}),
      ];
      await mountPage(t, w, RaftFamily.elegant, false);
      await t.tapAt(
        t.getCenter(
          find.byKey(const ValueKey('sidebar-section-system:channels')),
        ),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Show joined channels only'));
      await t.pumpAndSettle();
      expect(find.text('Outside'), findsNothing);
      expect(find.text('No joined channels'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('closed DMs', () {
    List<String> direct(Map<String, int> unread) => [
      for (final e in projectSidebar(
        channels: const [],
        dms: [_dm('d1', 'Alice'), _dm('d2', 'Bob')],
        preferences: {
          'hiddenDmIds': ['d1', 'd2'],
        },
        unread: unread,
      ).singleWhere((g) => g.id == 'system:dms').entries)
        e.label,
    ];

    test('a closed DM reappears while it has unread messages', () {
      expect(direct({}), isEmpty);
      expect(direct({'d2': 3}), ['Bob']);
      expect(direct({'d1': 1, 'd2': 1, 'other': 9}), ['Alice', 'Bob']);
    });

    testWidgets('opening a closed DM takes it out of the closed list', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final patches = <Object?>[];
      api.routes['PATCH /servers/s1/sidebar-order'] = (o) {
        patches.add(o.data);
        return {};
      };
      w.dms = [_dm('d1', 'Alice'), _dm('d2', 'Bob')];
      w.section = 'chat';
      w.sidebarOrder = {
        'hiddenDmIds': ['d1', 'd2'],
      };
      final reopen = ClosedDmReopen();
      // The page open when the sidebar mounts is a restored one: it stays.
      w.channel = w.dms.first;
      reopenOpenedDm(w, reopen);
      await t.pump();
      expect(patches, isEmpty);
      // Another conversation, then a closed DM opened by the user.
      w.channel = RaftChannel({'id': 'c1', 'name': 'general', 'joined': true});
      reopenOpenedDm(w, reopen);
      w.channel = w.dms.last;
      reopenOpenedDm(w, reopen);
      await t.pumpAndSettle();
      expect(patches.single, {
        'hiddenDmIds': ['d1'],
      });
      // The same page again is not a new visit.
      reopenOpenedDm(w, reopen);
      await t.pumpAndSettle();
      expect(patches, hasLength(1));
    });
  });
}
