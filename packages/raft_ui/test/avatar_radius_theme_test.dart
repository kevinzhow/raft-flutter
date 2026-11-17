import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Avatar shape comes from the theme.
///
/// The reference is the official raft-ui specimen.
RaftTokens _tokens(String id) => RaftTokens.theme(pack: packForThemeId(id));

Widget _host(String id, Widget child) => MaterialApp(
  theme: raftTheme(pack: packForThemeId(id)),
  home: Scaffold(body: Center(child: child)),
);

/// Paints one avatar in its own tree and reads back the outer and inner radii.
///
/// Each call gets a fresh widget, because reusing one across themes leaves the
/// previous theme's values in the element.
Future<(double, double)> _paintedRadii(WidgetTester tester, String id) async {
  await tester.pumpWidget(
    _host(
      id,
      RaftStickerAvatar(
        size: RaftAvatarSize.md,
        child: const SizedBox.expand(),
      ),
    ),
  );
  await tester.pump();
  final box = tester.widgetList<RaftCssBox>(find.byType(RaftCssBox)).first;
  final clip = tester.widgetList<ClipRRect>(find.byType(ClipRRect)).first;
  return (box.radius, (clip.borderRadius as BorderRadius).topLeft.x);
}

void main() {
  group('avatar radii follow the theme', () {
    test('Raft keeps the official 4px sticker with a 2px inner', () {
      // raft-ui 0.7.1: outer `rounded-sticker` (4px), content `rounded-[2px]`.
      final t = _tokens(raftThemePackId);
      expect(t.size('radius.avatar', fallback: 4), 4);
      expect(t.size('radius.avatarInner', fallback: 2), 2);
    });

    test('the inner radius is its own token, not outer minus inset', () {
      // The official specimen insets the image by 1px per side and still rounds
      // it to 2, so outer - inset would give 3. Pinned so nobody "simplifies"
      // the second token away.
      final t = _tokens(raftThemePackId);
      final outer = t.size('radius.avatar', fallback: 4);
      expect(outer - 1, isNot(t.size('radius.avatarInner', fallback: 2)));
    });

    testWidgets('Raft paints 4 outside and 2 inside', (tester) async {
      // Raft must be byte-identical to before this change, so its two radii are
      // pinned explicitly rather than only compared across themes.
      final radii = await _paintedRadii(tester, raftThemePackId);
      expect(radii, (4.0, 2.0));
    });
  });
}
