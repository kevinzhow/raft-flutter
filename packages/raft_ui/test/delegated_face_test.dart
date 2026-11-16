import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/raft/css_box.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.95.3 message-item-delegated: a 19px face (radius sticker 4) on the
// owner's avatar, ringed in the row's current fill (1.5px light, 3px dark).
Widget host({
  bool dark = false,
  Color? fill,
  bool deleted = false,
  bool corner = true,
}) {
  Widget face = RaftDelegatedFace(
    deleted: deleted,
    agentAvatar: const SizedBox.expand(key: Key('agent')),
  );
  if (fill != null) {
    face = RaftMessageRowFillScope(color: fill, child: face);
  }
  return MaterialApp(
    theme: raftTheme(dark: dark),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: RaftAvatar(
          key: const Key('owner'),
          name: 'Ada',
          size: 35,
          corner: corner ? face : null,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('19x19 at the md badge position of the owner avatar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    final face = find.byType(RaftDelegatedFace);
    expect(tester.getSize(face), const Size.square(19));
    final avatar = tester.getRect(find.byKey(const Key('owner')));
    // `-right-1 -bottom-1` of the padding box (1.5px border): 2.5px outside.
    expect(tester.getBottomRight(face).dx - avatar.right, closeTo(2.5, .01));
    expect(tester.getBottomRight(face).dy - avatar.bottom, closeTo(2.5, .01));
  });

  testWidgets('ring is the current row fill, 1.5 light / 3 dark', (
    tester,
  ) async {
    const fill = Color(0xFFABCDEF);
    for (final (dark, width) in [(false, 1.5), (true, 3.0)]) {
      await tester.pumpWidget(host(dark: dark, fill: fill));
      await tester.pumpAndSettle();
      final box = tester.widget<RaftCssBox>(
        find.descendant(
          of: find.byType(RaftDelegatedFace),
          matching: find.byType(RaftCssBox),
        ),
      );
      final rings = [for (final r in box.rings) (r.spread, r.color)];
      expect(rings.first, (width, fill), reason: 'dark=$dark');
    }
  });

  testWidgets('deleted: grayscale, .6 opacity, hidden from semantics', (
    tester,
  ) async {
    await tester.pumpWidget(host(deleted: true));
    expect(
      find.descendant(
        of: find.byType(RaftDelegatedFace),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(RaftDelegatedFace),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      .6,
    );
    expect(
      find.descendant(
        of: find.byType(RaftDelegatedFace),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });

  testWidgets('without a corner the avatar is unchanged', (tester) async {
    await tester.pumpWidget(host(corner: false));
    expect(find.byType(RaftDelegatedFace), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('owner'))),
      const Size.square(35),
    );
  });
}
