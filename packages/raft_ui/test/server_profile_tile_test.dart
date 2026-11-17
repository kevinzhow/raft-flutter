import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets(
    'the server profile tile is the server avatar at lg (51), not a muted circle',
    (t) async {
      await t.pumpWidget(
        _host(RaftServerProfileTile(initial: 'W', onUpload: () {})),
      );
      final slot = find.byType(RaftAvatarSlot);
      expect(slot, findsOneWidget);
      final avatar = t.widget<RaftAvatarSlot>(slot);
      expect(avatar.server, isTrue);
      expect(t.getSize(slot), const Size(51, 51));
      final initial = t.widget<Text>(
        find.descendant(of: slot, matching: find.text('W')),
      );
      final tokens = RaftTokens.of(t.element(slot));
      expect(initial.style?.fontSize, 22);
      expect(initial.style?.fontWeight, FontWeight.w700);
      expect(
        initial.style?.color,
        tokens.colors['foreground-avatar-server'] ?? tokens.strong,
      );
    },
  );
}
