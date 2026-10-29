import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Avatar shape comes from the theme.
///
/// Each look has its own reference: Raft from the official raft-ui specimen,
/// Elegant and Brutal from a57b9dab. (The pre-theme tree had only those two
/// looks — there was no "old Raft" — so Raft is never compared against it.)
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

    test('Elegant is circular, inside and out', () {
      // a57b9dab rounds outer and inner with the same size/2 expression.
      final t = _tokens(elegantThemePackId);
      expect(t.size('radius.avatar', fallback: 4), 999);
      expect(t.size('radius.avatarInner', fallback: 2), 999);
    }, skip: raftLookSkip(raftLookElegant));

    test('Brutal is square, inside and out', () {
      final t = _tokens(brutalThemePackId);
      expect(t.size('radius.avatar', fallback: 4), 0);
      expect(t.size('radius.avatarInner', fallback: 2), 0);
    }, skip: raftLookSkip(raftLookBrutal));

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

    testWidgets('Elegant paints a full circle outside and inside', (
      tester,
    ) async {
      expect(await _paintedRadii(tester, elegantThemePackId), (999.0, 999.0));
    }, skip: raftLookSkip(raftLookElegant));

    testWidgets('Brutal paints square outside and inside', (tester) async {
      expect(await _paintedRadii(tester, brutalThemePackId), (0.0, 0.0));
    }, skip: raftLookSkip(raftLookBrutal));
  });
}
