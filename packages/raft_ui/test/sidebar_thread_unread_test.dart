import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Sidebar.tsx `ChannelUnreadSegments`: `5 · [thread] 1` in the loud badge or
/// as quiet text; only the thread segment when the channel itself is read.
void main() {
  for (final (family, dark) in raftThemeMatrix([
    (raftThemePackId, false),
    (raftThemePackId, true),
    (brutalThemePackId, false),
    (elegantThemePackId, false),
    (elegantThemePackId, true),
  ], look: (v) => raftLookOf(v.$1))) {
    testWidgets('$family/$dark thread unread joins the badge', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(family), dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: Column(
                  children: [
                    for (final (name, joined, muted, unread, threads) in [
                      ('both', true, false, 5, 2),
                      ('threads-only', true, false, 0, 120),
                      ('muted', true, true, 3, 1),
                      ('away', false, false, 0, 1),
                      ('none', true, false, 4, 0),
                    ])
                      RaftNavItem(
                        key: ValueKey(name),
                        label: name,
                        glyph: RaftGlyph.hash,
                        conversationKind: RaftConversationNavKind.channel,
                        joined: joined,
                        activityMuted: muted,
                        unread: unread,
                        threadUnread: threads,
                        threadUnreadLabel: 'threads with new replies',
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Finder badge(String name) => find.descendant(
        of: find.byKey(ValueKey(name)),
        matching: find.byType(RaftSidebarThreadUnreadCount),
      );
      Finder text(String name, String value) =>
          find.descendant(of: badge(name), matching: find.text(value));
      // Own count, the dot, then the thread icon with its number.
      expect(badge('both'), findsOneWidget);
      expect(text('both', '5'), findsOneWidget);
      expect(text('both', '·'), findsOneWidget);
      expect(text('both', '2'), findsOneWidget);
      // Only threads: no own count and no separator; capped like the count.
      expect(text('threads-only', '99+'), findsOneWidget);
      expect(text('threads-only', '·'), findsNothing);
      expect(
        find.descendant(
          of: badge('threads-only'),
          matching: find.byType(RaftThreadIcon),
        ),
        findsOneWidget,
      );
      // A muted channel keeps the quiet number; a channel not joined shows no
      // thread segment (the roll-up needs a joined channel).
      expect(badge('muted'), findsOneWidget);
      expect(badge('away'), findsNothing);
      expect(badge('none'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('none')),
          matching: find.byType(RaftConversationUnreadCount),
        ),
        findsOneWidget,
      );
      // The loud badge is the accent pill; the muted one is bare text.
      final loud = t.widget<RaftSidebarThreadUnreadCount>(badge('both'));
      final muted = t.widget<RaftSidebarThreadUnreadCount>(badge('muted'));
      expect(loud.loud, isTrue);
      expect(muted.loud, isFalse);
      expect(
        find.descendant(of: badge('both'), matching: find.byType(Container)),
        findsWidgets,
      );
      // A thread-only channel is a loud unread row: bold name.
      expect(
        t.widget<Text>(find.text('threads-only')).style!.fontWeight,
        FontWeight.w700,
      );
      expect(
        t.widget<Text>(find.text('away')).style!.fontWeight,
        FontWeight.w500,
      );
    });

    testWidgets('$family/$dark the screen reader hears the thread count', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(family), dark: dark),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: RaftNavItem(
                label: 'general',
                glyph: RaftGlyph.hash,
                conversationKind: RaftConversationNavKind.channel,
                unread: 5,
                threadUnread: 2,
                threadUnreadLabel: 'threads with new replies',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp('general, 5 unread, 2 threads with new replies'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  }
}
