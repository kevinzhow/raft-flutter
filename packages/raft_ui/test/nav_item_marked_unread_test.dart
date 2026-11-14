import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 channelUnreadIndicator.ts `showMarkedUnreadDot` / `unreadTone`
/// and `getDmUnreadIndicatorState`: a conversation marked unread with nothing
/// countable shows the quiet dot and no number; a joined, unmuted channel (an
/// unmuted DM) also takes the unread title weight.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: child),
      ),
    ),
  );

  RaftNavItem row({
    RaftConversationNavKind kind = RaftConversationNavKind.channel,
    bool joined = true,
    bool muted = false,
    bool marked = true,
    bool quietNew = false,
    int unread = 0,
    int threads = 0,
  }) => RaftNavItem(
    label: 'general',
    glyph: RaftGlyph.hash,
    conversationKind: kind,
    joined: joined,
    activityMuted: muted,
    markedUnread: marked,
    quietNew: quietNew,
    unread: unread,
    threadUnread: threads,
    threadUnreadLabel: 'threads with new replies',
    onTap: () {},
  );

  final dot = find.byKey(const ValueKey('sidebar-marked-unread-dot'));
  FontWeight? weight(WidgetTester t) {
    final text = t.widget<RichText>(
      find.descendant(
        of: find.byType(RaftNavItem),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'general',
        ),
      ),
    );
    return text.text.style?.fontWeight;
  }

  testWidgets('a marked channel shows the quiet dot and the unread title', (
    t,
  ) async {
    await t.pumpWidget(host(row(marked: false)));
    expect(dot, findsNothing);
    final plain = weight(t);
    await t.pumpWidget(host(row()));
    expect(dot, findsOneWidget);
    expect(
      t.getSize(
        find.descendant(
          of: dot,
          matching: find.byKey(const ValueKey('sidebar-quiet-new-dot')),
        ),
      ),
      const Size.square(6),
    );
    expect(weight(t), isNot(plain));
    expect(find.bySemanticsLabel(RegExp('Marked as unread')), findsWidgets);
  });

  testWidgets('a count, a thread segment or the new dot takes its place', (
    t,
  ) async {
    await t.pumpWidget(host(row(unread: 2)));
    expect(dot, findsNothing);
    await t.pumpWidget(host(row(threads: 1)));
    expect(dot, findsNothing);
    await t.pumpWidget(host(row(joined: false, quietNew: true)));
    expect(dot, findsNothing);
    expect(find.byKey(const ValueKey('sidebar-quiet-new-dot')), findsOneWidget);
  });

  testWidgets('muted rows keep the dot without the unread title', (t) async {
    await t.pumpWidget(host(row(muted: true, marked: false)));
    final plain = weight(t);
    await t.pumpWidget(host(row(muted: true)));
    expect(dot, findsOneWidget);
    expect(weight(t), plain);
    await t.pumpWidget(
      host(row(kind: RaftConversationNavKind.directMessage, muted: true)),
    );
    expect(dot, findsOneWidget);
    await t.pumpWidget(host(row(kind: RaftConversationNavKind.directMessage)));
    expect(dot, findsOneWidget);
  });
}
