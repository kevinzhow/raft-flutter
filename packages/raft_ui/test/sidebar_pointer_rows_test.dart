import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Source row extras: the mouse double-click of member rows and the Activity
/// entries, the quiet "new" dot of a non-joined channel, the bridge chip.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: child),
      ),
    ),
  );

  var clock = Duration.zero;

  /// Clicks [at] [times] times, [gap] apart on the event clock.
  Future<void> click(
    WidgetTester t,
    Finder at, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
    int times = 2,
    Duration gap = const Duration(milliseconds: 80),
  }) async {
    final position = t.getCenter(at);
    final pointer = TestPointer(1, kind);
    for (var i = 0; i < times; i++) {
      await t.sendEventToBinding(pointer.down(position, timeStamp: clock));
      await t.sendEventToBinding(pointer.up(timeStamp: clock));
      clock += gap;
      await t.pump(gap);
    }
  }

  group('double click', () {
    for (final (name, build)
        in <(String, Widget Function(VoidCallback tap, VoidCallback dbl))>[
          (
            'directory row',
            (tap, dbl) => RaftNavItem(
              label: 'Alice',
              glyph: RaftGlyph.user,
              conversationKind: RaftConversationNavKind.directory,
              onTap: tap,
              onDoubleClick: dbl,
            ),
          ),
          (
            'Activity entry',
            (tap, dbl) => RaftNavItem(
              label: 'Activity',
              glyph: RaftGlyph.activity,
              role: RaftNavItemRole.activity,
              onTap: tap,
              onDoubleClick: dbl,
            ),
          ),
        ]) {
      testWidgets('$name: two mouse clicks fire it once, after both taps', (
        t,
      ) async {
        final log = <String>[];
        await t.pumpWidget(
          host(build(() => log.add('tap'), () => log.add('double'))),
        );
        await click(t, find.byType(RaftNavItem), times: 1);
        // The first click is never held back for a possible second one.
        expect(log, ['tap']);
        await click(t, find.byType(RaftNavItem), times: 1);
        await t.pump();
        expect(log, ['tap', 'tap', 'double']);
        // A third click starts a new count.
        await click(t, find.byType(RaftNavItem), times: 1);
        await t.pump();
        expect(log, ['tap', 'tap', 'double', 'tap']);
      });

      testWidgets('$name: touch taps and slow clicks never fire it', (t) async {
        final log = <String>[];
        await t.pumpWidget(
          host(build(() => log.add('tap'), () => log.add('double'))),
        );
        await click(t, find.byType(RaftNavItem), kind: PointerDeviceKind.touch);
        await t.pump();
        expect(log, ['tap', 'tap']);
        log.clear();
        await click(
          t,
          find.byType(RaftNavItem),
          gap: const Duration(seconds: 1),
        );
        await t.pump();
        expect(log, ['tap', 'tap']);
      });
    }

    testWidgets('a rail destination fires it for the mouse only', (t) async {
      final log = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(
              width: 64,
              child: RaftWorkspaceRail(
                destinations: [
                  const RaftRailDestination(
                    id: 'chat',
                    label: 'Chat',
                    icon: Icons.chat,
                  ),
                  RaftRailDestination(
                    id: 'activity',
                    label: 'Activity',
                    icon: Icons.inbox,
                    onDoubleClick: () => log.add('double'),
                  ),
                ],
                selected: 'chat',
                onSelected: (id) => log.add(id),
                workspaceName: 'Raft',
                onWorkspace: () {},
              ),
            ),
          ),
        ),
      );
      final activity = find.byKey(const ValueKey('rail-activity'));
      await click(t, activity, kind: PointerDeviceKind.touch);
      expect(log, ['activity', 'activity']);
      log.clear();
      await click(t, activity);
      await t.pump();
      expect(log, ['activity', 'activity', 'double']);
      await click(t, find.byKey(const ValueKey('rail-chat')));
      await t.pump();
      expect(log.where((e) => e == 'double'), hasLength(1));
    });
  });

  group('channel row extras', () {
    RaftNavItem channel({
      bool joined = true,
      bool quietNew = false,
      int unread = 0,
      bool draft = false,
      String? badge,
    }) => RaftNavItem(
      label: 'general',
      glyph: RaftGlyph.hash,
      conversationKind: RaftConversationNavKind.channel,
      joined: joined,
      quietNew: quietNew,
      unread: unread,
      hasDraft: draft,
      providerBadge: badge,
      onTap: () {},
    );

    testWidgets('the quiet dot lights only a non-joined row without a count', (
      t,
    ) async {
      final dot = find.byKey(const ValueKey('sidebar-quiet-new-dot'));
      await t.pumpWidget(host(channel(joined: false, quietNew: true)));
      expect(dot, findsOneWidget);
      expect(t.getSize(dot), const Size.square(6));
      // A count wins, a joined channel has none, a draft pencil yields to it.
      await t.pumpWidget(
        host(channel(joined: false, quietNew: true, unread: 3)),
      );
      expect(dot, findsNothing);
      expect(find.byType(RaftSidebarQuietUnreadCount), findsOneWidget);
      await t.pumpWidget(host(channel(quietNew: true)));
      expect(dot, findsNothing);
      await t.pumpWidget(
        host(channel(joined: false, quietNew: true, draft: true)),
      );
      expect(dot, findsOneWidget);
      expect(find.byType(RaftSidebarDraftIcon), findsNothing);
    });

    testWidgets('the provider chip follows the name, upper-cased', (t) async {
      await t.pumpWidget(host(channel(badge: 'Slack')));
      final chip = find.byType(RaftBadge);
      expect(chip, findsOneWidget);
      expect(t.widget<RaftBadge>(chip).uppercase, isTrue);
      expect(
        t.getTopLeft(chip).dx,
        greaterThan(t.getTopRight(find.text('general')).dx),
      );
      await t.pumpWidget(host(channel()));
      expect(find.byType(RaftBadge), findsNothing);
    });
  });
}
