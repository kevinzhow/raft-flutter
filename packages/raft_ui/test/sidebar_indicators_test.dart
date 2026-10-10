import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark muted and unjoined counts stay quiet', (
      t,
    ) async {
      final theme = raftTheme(family, dark: dark);
      final tokens = theme.extension<RaftTokens>()!;
      var activations = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: Column(
                  children: [
                    for (final (name, joined, muted, selected) in [
                      ('muted', true, true, false),
                      ('unjoined', false, false, false),
                      ('selected', false, false, true),
                      ('loud', true, false, false),
                    ])
                      RaftNavItem(
                        key: ValueKey(name),
                        label: name,
                        glyph: RaftGlyph.hash,
                        conversationKind: RaftConversationNavKind.channel,
                        joined: joined,
                        activityMuted: muted,
                        selected: selected,
                        unread: 104,
                        onTap: () => activations++,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(RaftSidebarQuietUnreadCount), findsNWidgets(3));
      expect(find.byType(RaftConversationUnreadCount), findsOneWidget);
      expect(find.byType(RaftSidebarMutedIcon), findsOneWidget);
      expect(find.text('99+'), findsNWidgets(4));
      for (final name in ['muted', 'unjoined', 'selected']) {
        expect(
          t.widget<Text>(find.text(name)).style!.fontWeight,
          FontWeight.w500,
        );
      }
      expect(
        t.widget<Text>(find.text('loud')).style!.fontWeight,
        FontWeight.w700,
      );
      final quiet = find.descendant(
        of: find.byType(RaftSidebarQuietUnreadCount).first,
        matching: find.byType(Text),
      );
      expect(t.widget<Text>(quiet).style!.fontSize, 10);
      expect(t.widget<Text>(quiet).style!.height, 1);
      expect(
        t.widget<Text>(quiet).style!.color,
        family == RaftFamily.brutal
            ? Colors.black.withValues(alpha: .5)
            : tokens.colors['foreground-muted'],
      );
      expect(t.getSize(find.byType(RaftSidebarMutedIcon)), const Size(16, 16));
      final semantics = t.ensureSemantics();
      try {
        expect(
          t.getSemantics(find.byType(RaftSidebarMutedIcon)).label,
          contains('Activity muted'),
        );
      } finally {
        semantics.dispose();
      }
      expect(
        t.widget<Text>(find.text('unjoined')).style!.color,
        family == RaftFamily.brutal
            ? Colors.black.withValues(alpha: .4)
            : tokens.colors['foreground-placeholder'],
      );
      final unjoinedIcon = find.descendant(
        of: find.byKey(const ValueKey('unjoined')),
        matching: find.byType(RaftIcon),
      );
      expect(
        t.widget<RaftIcon>(unjoinedIcon).color,
        t.widget<Text>(find.text('unjoined')).style!.color,
      );
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: t.getCenter(find.byKey(const ValueKey('unjoined'))),
      );
      await mouse.moveTo(t.getCenter(find.byKey(const ValueKey('unjoined'))));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.text('unjoined')).style!.color,
        family == RaftFamily.brutal
            ? Colors.black.withValues(alpha: .4)
            : tokens.colors['foreground-placeholder'],
      );
      await t.tap(find.byKey(const ValueKey('unjoined')));
      await t.pump();
      expect(activations, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(activations, 2);
      await mouse.removePointer();
      expect(t.takeException(), isNull);
    });

    testWidgets(
      '$family/$dark unread takes priority over channel and DM drafts',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: Column(
                  children: [
                    for (final kind in [
                      RaftConversationNavKind.channel,
                      RaftConversationNavKind.directMessage,
                    ])
                      for (final unread in [0, 2])
                        RaftNavItem(
                          label: '$kind/$unread',
                          glyph: RaftGlyph.hash,
                          conversationKind: kind,
                          unread: unread,
                          activityMuted: true,
                          hasDraft: true,
                          onTap: () {},
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(RaftSidebarDraftIcon), findsNWidgets(2));
        expect(find.byType(RaftSidebarQuietUnreadCount), findsOneWidget);
        expect(find.byType(RaftConversationUnreadCount), findsOneWidget);
        expect(find.byType(RaftSidebarMutedIcon), findsNWidgets(2));
        expect(t.takeException(), isNull);
      },
    );
  }
}
