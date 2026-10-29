import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.1 `Badge` (20px solid sticker, 22px soft / outline chips) and `Avatar` (square stickers 19 / 27 /
// 35 / 51 / 99, initials, presence badge).
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

/// `border-[1.5px]` floored to whole device pixels at the test binding's 3.0 device ratio.
const _border = 4 / 3;

/// Blink composites a translucent token with a truncated 8-bit blend; Flutter with floats: one level apart.
void _expectNear(Color actual, Color expected) {
  for (final (a, e) in [
    (actual.r, expected.r),
    (actual.g, expected.g),
    (actual.b, expected.b),
  ]) {
    expect((a - e).abs() * 255, lessThanOrEqualTo(1.01));
  }
}

RaftCssBox _firstBox(WidgetTester tester, Finder within) =>
    tester.widget<RaftCssBox>(
      find.descendant(of: within, matching: find.byType(RaftCssBox)).first,
    );

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    group('badge $mode', () {
      testWidgets('solid is a 20px sticker, min 20 wide, with an ink ring', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftBadge(label: '1', variant: RaftBadgeRecipeVariant.accent),
          ),
        );
        // Test fonts are boxes wider than the real face, so the width is the label plus 6px padding each side.
        final one = tester.getSize(find.text('1')).width;
        expect(
          tester.getSize(find.byType(RaftBadge)),
          Size(one + 12 < 20 ? 20 : one + 12, 20),
        );
        final box = _firstBox(tester, find.byType(RaftBadge));
        expect(box.radius, 4);
        expect(box.fill, ui.attention);
        expect(box.insetRingWidth, 1.5);
        expect(box.insetRingColor, ui.stickerInk);
        expect(box.rings.single.spread, 1.5);
        // The count is mono, bold and ink.
        final style = tester.widget<Text>(find.text('1')).style!;
        expect(style.fontFamily, contains('SpaceMono'));
        expect(style.fontWeight, FontWeight.w700);
        expect(style.color, ui.stickerInk);

        await tester.pumpWidget(
          _app(
            dark,
            const RaftBadge(
              label: '12',
              variant: RaftBadgeRecipeVariant.accent,
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftBadge)).height, 20);
        expect(tester.getSize(find.byType(RaftBadge)).width, greaterThan(20));
      });

      testWidgets('the @ marker is a glyph in a primary solid badge', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftBadge(
              glyph: RaftGlyph.atSign,
              variant: RaftBadgeRecipeVariant.primary,
              semanticLabel: 'Mentions you',
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftBadge)), const Size(25, 20));
        expect(tester.getSize(find.byType(RaftIcon)), const Size.square(13));
        expect(_firstBox(tester, find.byType(RaftBadge)).fill, ui.brand);
        expect(find.bySemanticsLabel('Mentions you'), findsOneWidget);
      });

      testWidgets('soft and outline are 22px chips with the chip radius', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftBadge(
              label: 'danger',
              appearance: RaftBadgeRecipeAppearance.soft,
              variant: RaftBadgeRecipeVariant.danger,
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftBadge)).height, 22);
        var box = _firstBox(tester, find.byType(RaftBadge));
        expect(box.radius, 6);
        expect(box.insetRingWidth, 0);
        _expectNear(
          Color.alphaBlend(box.fill!, ui.layerCanvas),
          Color.alphaBlend(ui['danger-soft'], ui.layerCanvas),
        );
        expect(
          tester.widget<Text>(find.text('danger')).style!.fontWeight,
          FontWeight.w600,
        );

        await tester.pumpWidget(
          _app(
            dark,
            const RaftBadge(
              label: 'danger',
              appearance: RaftBadgeRecipeAppearance.outline,
              variant: RaftBadgeRecipeVariant.danger,
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftBadge)).height, 22);
        box = _firstBox(tester, find.byType(RaftBadge));
        expect(box.fill!.a, 0);
        expect(box.insetRingWidth, 1);
        final style = tester.widget<Text>(find.text('danger')).style!;
        expect(style.fontFamily, contains('SpaceMono'));
        expect(style.fontWeight, FontWeight.w400);
      });

      testWidgets('hover lays the pressed overlay over a button badge', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftBadge(
              label: 'x',
              appearance: RaftBadgeRecipeAppearance.soft,
              onPressed: () {},
            ),
          ),
        );
        final resting = _firstBox(tester, find.byType(RaftBadge)).fill;
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.byType(RaftBadge)));
        await tester.pump();
        expect(_firstBox(tester, find.byType(RaftBadge)).fill, isNot(resting));
        await gesture.removePointer();
      });
    });

    group('avatar $mode', () {
      testWidgets('sticker sizes are 19 / 27 / 35 / 51 / 99 squares', (
        tester,
      ) async {
        for (final (size, extent) in [
          (RaftAvatarSize.xs, 19.0),
          (RaftAvatarSize.sm, 27.0),
          (RaftAvatarSize.md, 35.0),
          (RaftAvatarSize.lg, 51.0),
          (RaftAvatarSize.xl, 99.0),
        ]) {
          await tester.pumpWidget(
            _app(dark, RaftAvatar(name: 'Mia Chen', uiSize: size)),
          );
          expect(tester.getSize(find.byType(RaftAvatar)), Size.square(extent));
          final box = _firstBox(tester, find.byType(RaftAvatar));
          // Square sticker: 4px radius, ink border, die-cut ring; not a circle.
          expect(box.radius, 4);
          expect(box.borderColor, ui.stickerInk);
          expect(box.width, extent);
          expect(box.rings.single.spread, 1.5);
        }
      });

      testWidgets('people are lavender with initials, agents stone', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftAvatar(name: 'Mia Chen', uiSize: RaftAvatarSize.lg),
          ),
        );
        expect(
          _firstBox(tester, find.byType(RaftAvatar)).fill,
          ui['palette-lavender-400'],
        );
        expect(find.text('MC'), findsOneWidget);
        final style = tester.widget<Text>(find.text('MC')).style!;
        expect(style.fontSize, 22);
        expect(style.height, 1);
        expect(style.fontWeight, FontWeight.w700);
        expect(style.color, ui.stickerInk);

        await tester.pumpWidget(
          _app(
            dark,
            const RaftAvatar(
              name: 'Wug',
              kind: RaftAvatarKind.agent,
              uiSize: RaftAvatarSize.lg,
            ),
          ),
        );
        expect(_firstBox(tester, find.byType(RaftAvatar)).fill, ui.inactive);
        expect(find.text('W'), findsOneWidget);

        // A person without a name shows the placeholder icon.
        await tester.pumpWidget(
          _app(dark, const RaftAvatar(name: '', uiSize: RaftAvatarSize.lg)),
        );
        expect(find.byType(RaftAvatarPlaceholder), findsOneWidget);
        expect(
          tester.getSize(
            find.descendant(
              of: find.byType(RaftAvatarPlaceholder),
              matching: find.byType(CustomPaint),
            ),
          ),
          const Size.square(24),
        );
      });

      testWidgets('the 99px sticker casts the 4px ink elevation', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftAvatar(name: 'Mia Chen', uiSize: RaftAvatarSize.xl),
          ),
        );
        final shadow = find.descendant(
          of: find.byType(RaftAvatar),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    (dark ? const Color(0xff000000) : ui.stickerInk),
          ),
        );
        expect(shadow, findsOneWidget);
        expect(
          tester.getTopLeft(shadow) -
              tester.getTopLeft(find.byType(RaftAvatar)),
          const Offset(4, 4),
        );
      });

      testWidgets(
        'a free size keeps its extent and borrows the nearest size class',
        (tester) async {
          await tester.pumpWidget(
            _app(dark, const RaftAvatar(name: 'Mia Chen', size: 44)),
          );
          expect(
            tester.getSize(find.byType(RaftAvatar)),
            const Size.square(44),
          );
          expect(tester.widget<Text>(find.text('MC')).style!.fontSize, 22);
        },
      );

      testWidgets('presence badge colours per mode and offsets', (
        tester,
      ) async {
        for (final (presence, name) in [
          (RaftPresence.online, 'online'),
          (RaftPresence.busy, 'busy'),
          (RaftPresence.error, 'error'),
          (RaftPresence.offline, 'offline'),
          (RaftPresence.external, 'external'),
        ]) {
          await tester.pumpWidget(
            _app(
              dark,
              RaftStickerAvatar(
                size: RaftAvatarSize.md,
                presence: presence,
                child: const SizedBox.shrink(),
              ),
            ),
          );
          final badge = find.byType(RaftAvatarBadge);
          expect(tester.getSize(badge), const Size.square(11));
          // `-right-1 -bottom-1` of the padding box: 35 - 1 border + 4 - 11.
          expect(
            tester.getTopLeft(badge) -
                tester.getTopLeft(find.byType(RaftStickerAvatar)),
            const Offset(35 - _border + 4 - 11, 35 - _border + 4 - 11),
          );
          final dot = _firstBox(tester, badge);
          expect(dot.fill, ui.presence(name));
          expect(dot.radius, 2);
          expect(dot.rings.single.spread, 2);
          expect(dot.rings.single.color, ui.layerCanvas);
        }
      });

      testWidgets(
        'an agent RaftAvatar admits presence, a deactivated one does not',
        (tester) async {
          const busy = RaftAvatarPresence(activity: RaftAvatarActivity.working);
          await tester.pumpWidget(
            _app(
              dark,
              const RaftAvatar(
                name: 'Wug',
                kind: RaftAvatarKind.agent,
                uiSize: RaftAvatarSize.md,
                presence: busy,
              ),
            ),
          );
          expect(
            _firstBox(tester, find.byType(RaftAvatarBadge)).fill,
            ui.presence('busy'),
          );
          await tester.pumpWidget(
            _app(
              dark,
              const RaftAvatar(
                name: 'Wug',
                kind: RaftAvatarKind.agent,
                uiSize: RaftAvatarSize.md,
                presence: busy,
                deactivated: true,
              ),
            ),
          );
          expect(find.byType(RaftAvatarBadge), findsNothing);
        },
      );

      testWidgets('agent pixel faces fill the padding box', (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftAvatar(
              name: 'robot',
              kind: RaftAvatarKind.agent,
              uiSize: RaftAvatarSize.lg,
              content: RaftAvatarContent(
                name: 'robot',
                kind: RaftAvatarContentKind.agent,
                pixelKey: 'robot',
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(RaftPixelAvatar)).width,
          closeTo(51 - 2 * _border, 1e-9),
        );
      });
    });
  }
}
